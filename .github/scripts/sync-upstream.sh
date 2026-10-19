#!/usr/bin/env bash
#
# sync-upstream.sh
#
# Cherry-picks new upstream commits into ONE accumulating PR (branch sync/upstream).
#
#  - The branch is rebuilt from the default branch on every run:
#        default branch + every upstream commit that is not applied yet
#    so it never drifts and never produces duplicate PRs.
#  - "Already applied" = the commit's SHA appears in a "(cherry picked from commit <sha>)"
#    trailer on the default branch (that is what `git cherry-pick -x` writes),
#    or it is <= .upstream-baseline, or it is listed in .upstream-ignore.
#  - A commit that conflicts / breaks Lua syntax / touches .github/workflows is SKIPPED,
#    gets one issue (label upstream-conflict) and the run continues with the rest.
#  - A commit that conflicts also gets a branch conflict/<sha7> (its conflicted state committed, which
#    does not always carry conflict markers: a delete/modify conflict has none)
#    and a DRAFT PR, so it can be resolved right there. Drafts can't be merged by accident.
#  - Once a skipped commit is applied (trailer) or ignored, its issue and draft PR close themselves.
#  - Every run ALSO re-checks commits whose issue is still open: when several commits touch the same
#    file, resolving the last one often absorbs the earlier ones without leaving their trailer, so
#    their issue would stay open (and masked) forever. If such a commit is now superseded (its
#    change is already on the default branch), its issue and draft PR are closed. If it no longer
#    conflicts, its draft PR retires and the commit is retried right away; its issue is closed only
#    once the change is really in the sync PR. Only branches still exactly as the bot pushed them
#    are deleted; a branch with any human work on it is never closed, never force-pushed, only logged.
#  - Discord gets ONE message per run, and only when something actually changed.
#
set -Eeuo pipefail
export LC_ALL=C

UPSTREAM_URL="${UPSTREAM_URL:-https://github.com/NeticSoul/DragonUI.git}"
UPSTREAM_BRANCH="${UPSTREAM_BRANCH:-main}"
DEFAULT_BRANCH="${DEFAULT_BRANCH:-main}"
SYNC_BRANCH="${SYNC_BRANCH:-sync/upstream}"
MAX_ISSUES="${MAX_ISSUES:-10}"        # max new "skipped" issues per run (avoids floods)
MAX_OPEN_CONFLICT_PRS="${MAX_OPEN_CONFLICT_PRS:-10}"   # max draft conflict PRs open at once
DRY_RUN="${DRY_RUN:-false}"           # true = no push, no PR, no issues, no Discord
RETRY_SHA="${RETRY_SHA:-}"            # SHA/prefix of a skipped commit to try again
REPO="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
OWNER="${GITHUB_REPOSITORY_OWNER:-}"
RUN_URL="${GITHUB_SERVER_URL:-https://github.com}/${REPO}/actions/runs/${GITHUB_RUN_ID:-0}"
UP_WEB="${UPSTREAM_URL%.git}"
BT='`'
FENCE='```'

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# ---------------------------------------------------------------- helpers ---
log()    { echo "[sync] $*" >&2; }
die()    { echo "::error::$*"; exit 1; }
is_dry() { [ "$DRY_RUN" = "true" ]; }

retry() {
  local n=1
  until "$@"; do
    if [ "$n" -ge 3 ]; then return 1; fi
    log "retry $n/3: $*"
    sleep $((n * 5))
    n=$((n + 1))
  done
}

notify() {
  local msg="$1"
  if is_dry; then log "(dry-run) Discord message:"; echo "$msg"; return 0; fi
  if [ -z "${DISCORD_WEBHOOK:-}" ]; then log "DISCORD_WEBHOOK not set; skipping notification"; return 0; fi
  jq -n --arg c "${msg:0:1900}" '{content: $c, allowed_mentions: {parse: []}}' \
    | curl -fsS --retry 3 -H "Content-Type: application/json" -d @- "$DISCORD_WEBHOOK" >/dev/null \
    || log "warning: Discord notification failed"
}

is_ignored() {
  local p
  while read -r p; do
    if [ -n "$p" ] && [[ "$1" == "$p"* ]]; then return 0; fi
  done < "$TMP/ignored"
  return 1
}

known_skipped() { grep -qF -- "${1:0:7}" "$TMP/issue_titles"; }

# Prints one line per file listed in a .toc that does not exist on disk.
check_toc() {
  local toc dir line f
  while IFS= read -r toc; do
    dir="$(dirname "$toc")"
    while IFS= read -r line || [ -n "$line" ]; do
      line="${line%$'\r'}"
      if [[ -z "$line" || "$line" == \#* ]]; then continue; fi
      f="${line//\\//}"
      if [ ! -e "${dir}/${f}" ]; then printf -- '- %s -> %s\n' "$toc" "$f"; fi
    done < "$toc"
  done < <(git ls-files '*.toc')
}

SKIPPED=()
ISSUES=0
DEFERRED=0
OPEN_CONFLICT_PRS=0
REEVALUATED=0

# Is this 7-char prefix already applied on the default branch, or listed in .upstream-ignore?
sha7_resolved() {
  local s="$1" p
  if grep -q "^${s}" "$TMP/applied"; then return 0; fi
  while read -r p; do
    if [ -n "$p" ] && { [[ "$s" == "$p"* ]] || [[ "$p" == "$s"* ]]; }; then return 0; fi
  done < "$TMP/ignored"
  return 1
}

# Instructions to finish a conflict branch (used in the draft PR and in the issue)
branch_steps() {
  local c="$1" s7="${1:0:7}"
  cat <<EOF
${FENCE}bash
git fetch origin && git checkout conflict/${s7}
# 1) edit the files and remove every <<<<<<< ======= >>>>>>> marker
git add <files>
# 2) REQUIRED trailer: it is how the sync knows this commit is applied
git commit --amend -m "\$(git log -1 --format=%B)" -m "(cherry picked from commit ${c})"
git push --force-with-lease origin conflict/${s7}
${FENCE}
Then click **Ready for review** and merge (*Rebase and merge* or merge commit, NOT *Squash*).
EOF
}

# make_conflict_pr <sha> <conflicting files>   -> prints the draft PR url (or nothing)
make_conflict_pr() {
  local c="$1" files="$2" s7="${1:0:7}" br="conflict/${1:0:7}" wt url subject err br_exists=0
  wt="$TMP/wt-${s7}"
  if is_dry; then log "(dry-run) would open a draft PR from ${br}"; return 0; fi
  if [ "$OPEN_CONFLICT_PRS" -ge "$MAX_OPEN_CONFLICT_PRS" ]; then
    log "already ${OPEN_CONFLICT_PRS} open conflict PRs; issue only for ${s7}"; return 0
  fi
  subject="$(git log -1 --format=%s "$c")"

  if git ls-remote --exit-code --heads origin "$br" >/dev/null 2>&1; then br_exists=1; fi

  # The branch already exists: by default it is left exactly as it is (a human may be resolving it).
  # Only an explicit retry_sha rebuilds it, and only while it is intact -- so a retry no longer needs
  # the branch to be deleted first (which is what closed its PR and orphaned a brand new one).
  if [ "$br_exists" = 1 ] && [ -n "$RETRY_SHA" ] && [[ "$c" == "$RETRY_SHA"* ]]; then
    if ! rebuild_conflict_branch "$c"; then
      return 0   # it no longer conflicts: branch and draft PR were retired, nothing to hand out
    fi
  fi

  if [ "$br_exists" = 0 ]; then
    git worktree add -q -B "$br" "$wt" "origin/${DEFAULT_BRANCH}" >/dev/null 2>&1 || return 0
    if git -C "$wt" cherry-pick "$c" >/dev/null 2>&1 \
       || [ -z "$(git -C "$wt" diff --name-only --diff-filter=U)" ]; then
      # Applies cleanly on top of the default branch alone (it only conflicts with commits
      # still pending in the sync PR) or is empty: there are no markers to show.
      git -C "$wt" cherry-pick --abort >/dev/null 2>&1 || true
      git worktree remove --force "$wt" >/dev/null 2>&1 || true
      git branch -q -D "$br" >/dev/null 2>&1 || true
      log "${s7} does not conflict against ${DEFAULT_BRANCH} alone; no draft PR"
      return 0
    fi
    git -C "$wt" add -A
    git -C "$wt" commit -q --no-verify -C "$c"      # original message + author, NO trailer on purpose
    if ! git -C "$wt" push -q origin "$br" >/dev/null 2>&1; then log "could not push ${br}"; fi
    git worktree remove --force "$wt" >/dev/null 2>&1 || true
    git branch -q -D "$br" >/dev/null 2>&1 || true
  fi

  url="$(gh pr list -R "$REPO" --head "$br" --state open --json url --jq '.[0].url // empty' 2>/dev/null || true)"
  if [ -z "$url" ]; then
    {
      echo "> ⚠️ **DRAFT — this branch is an unresolved conflict.** Don't merge until it is resolved."
      echo "> A delete/modify conflict (the default branch does not have a file the commit touches) leaves no markers, so having none is not proof that it is resolved."
      echo
      echo "Upstream commit: [${BT}${s7}${BT}](${UP_WEB}/commit/${c}) — ${subject}"
      echo
      echo "Conflicting files:"
      echo "${FENCE}"
      echo "${files}"
      echo "${FENCE}"
      echo
      echo "### Resolve"
      branch_steps "$c"
    } > "$TMP/conflict_body.md"
    url="$(gh pr create -R "$REPO" --draft --base "$DEFAULT_BRANCH" --head "$br" \
             --title "[CONFLICT] ${s7} ${subject}" --body-file "$TMP/conflict_body.md" \
             --label upstream-conflict 2>"$TMP/pr_err" | tail -n 1)" || {
      err="$(sed -n '1,2p' "$TMP/pr_err" | tr -d '\r' | tr '\n' ' ')" || err=""
      [ -n "$err" ] || err="(gh pr create failed without printing a reason)"
      err="${err:0:400}"
      log "gh pr create failed for ${br}: ${err}"
      echo "::error::Draft PR for ${br} was NOT created: ${err}"
      url=""
    }
    if [ -n "$url" ]; then OPEN_CONFLICT_PRS=$((OPEN_CONFLICT_PRS + 1)); fi
  fi
  printf '%s' "$url"
}

# Close issues / draft PRs whose commit is now applied (trailer on default branch) or ignored.
cleanup_resolved() {
  local n b line title s
  if is_dry; then return 0; fi

  while read -r n b; do
    if [ -z "$n" ] || [[ "$b" != conflict/* ]]; then continue; fi
    OPEN_CONFLICT_PRS=$((OPEN_CONFLICT_PRS + 1))
    s="${b#conflict/}"
    if sha7_resolved "$s"; then
      gh pr close "$n" -R "$REPO" --delete-branch \
        --comment "Resolved: ${s} is now applied on ${DEFAULT_BRANCH} (or ignored). Closing." >/dev/null 2>&1 || true
      OPEN_CONFLICT_PRS=$((OPEN_CONFLICT_PRS - 1))
    fi
  done < <(gh pr list -R "$REPO" --label upstream-conflict --state open --json number,headRefName \
             --jq '.[] | "\(.number) \(.headRefName)"' 2>/dev/null || true)

  while IFS= read -r line; do
    n="${line%% *}"; title="${line#* }"
    if [[ "$title" =~ Upstream\ skipped:\ ([0-9a-f]{7}) ]]; then
      s="${BASH_REMATCH[1]}"
      if sha7_resolved "$s"; then
        gh issue close "$n" -R "$REPO" --reason completed \
          --comment "Resolved: ${s} is now applied on ${DEFAULT_BRANCH} (or ignored). Closing." >/dev/null 2>&1 || true
      fi
    fi
  done < <(gh issue list -R "$REPO" --label upstream-conflict --state open --limit 200 --json number,title \
             --jq '.[] | "\(.number) \(.title)"' 2>/dev/null || true)
}

# --------------------------------------------------------- re-evaluation ---
# An open issue masks its commit (known_skipped), so the sync never looks at it again. That is how
# commits whose change was absorbed by a later commit's resolution used to linger forever: open
# issue, conflict branch frozen with stale markers, draft PR nobody can merge. The helpers below
# re-examine those commits on every run and retire only what is provably obsolete.
#
# NOTE: every check below deliberately avoids `cmd | grep -q`. Under `set -o pipefail` grep exiting
# early kills the producer with SIGPIPE and the pipeline reports 141, which would silently turn a
# matching check into a non-matching one. Redirections and loop-reads only.

# "Intact" = the branch is still exactly what make_conflict_pr() pushed: over the default branch it
# holds exactly ONE commit, with the picked commit's message untouched (so no "cherry picked from"
# trailer) and a diff that is only what `git add -A` leaves on the pick's leftovers. That diff has
# two shapes:
#   - conflict markers, on the paths git could merge textually; or
#   - a path resolved verbatim to the picked commit's own version. This is the delete/modify
#     conflict, where the default branch does not have a file the commit touches: git writes NO
#     markers for it and staging cannot annotate it, so testing for markers alone called the bot's
#     own branch "manual work" for ever and kept its commit masked by the open issue.
# If any check fails, the branch carries human work: never deleted, never force-pushed, never closed.
branch_intact() {
  local ref="$1" s7 c n f path changed
  if ! git rev-parse -q --verify "$ref" >/dev/null 2>&1; then return 1; fi
  n="$(git rev-list --count "origin/${DEFAULT_BRANCH}..${ref}" 2>/dev/null || echo 0)"
  if [ "$n" != "1" ]; then return 1; fi

  # The upstream commit the branch was picked from, named by the branch itself: conflict/<sha7>.
  s7="${ref##*/}"
  c="$(git rev-parse -q --verify "${s7}" 2>/dev/null || true)"
  if [ -z "$c" ] || ! git merge-base --is-ancestor "$c" "upstream/${UPSTREAM_BRANCH}" 2>/dev/null; then
    return 1
  fi

  f="$TMP/intact.log"
  git log -1 --format=%B "$ref" > "$f" 2>/dev/null || true
  if grep -qF 'cherry picked from commit' "$f"; then return 1; fi
  # `git commit -C <picked>` copies the message verbatim; a human resolution rewrites it.
  if [ "$(cat "$f")" != "$(git log -1 --format=%B "$c")" ]; then return 1; fi

  changed="$(git diff-tree --no-commit-id --name-only -r "$ref" 2>/dev/null || true)"
  [ -n "$changed" ] || return 1

  git show --format= --unified=0 "$ref" > "$f" 2>/dev/null || true
  if grep -q '^+<<<<<<<' "$f"; then return 0; fi

  # No markers at all: every path it touched must be the picked commit's version, byte for byte.
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    if [ "$(git rev-parse -q --verify "$ref:$path" 2>/dev/null || true)" \
         != "$(git rev-parse -q --verify "$c:$path" 2>/dev/null || true)" ]; then
      return 1
    fi
  done <<< "$changed"
  return 0
}

# Cherry-picks <sha> onto a throwaway worktree of origin/<DEFAULT_BRANCH> -- never on the sync
# branch, never on the main working tree -- and always removes it again. Prints exactly one of:
#   empty    = changes nothing: the change is already on the default branch
#   clean    = applies with no conflict
#   conflict = still conflicts
#   error    = the probe could not run
probe_pick() {
  local c="$1" s7="${1:0:7}" wt="$TMP/probe-${1:0:7}" st logf
  logf="$TMP/probe-${s7}.log"
  git worktree remove --force "$wt" >/dev/null 2>&1 || true
  rm -rf "$wt"
  if ! git worktree add -q --detach "$wt" "origin/${DEFAULT_BRANCH}" >/dev/null 2>&1; then
    git worktree prune >/dev/null 2>&1 || true
    echo error
    return 0
  fi
  if git -C "$wt" cherry-pick "$c" > "$logf" 2>&1; then
    st=clean
  elif [ -n "$(git -C "$wt" diff --name-only --diff-filter=U || true)" ]; then
    st=conflict
  elif grep -qi 'empty' "$logf"; then
    st=empty
  else
    st=error
  fi
  git -C "$wt" cherry-pick --abort >/dev/null 2>&1 || true
  git worktree remove --force "$wt" >/dev/null 2>&1 || true
  rm -rf "$wt"
  git worktree prune >/dev/null 2>&1 || true
  echo "$st"
}

# Same as probe_pick(), but the verdict is remembered for the rest of the run: a commit is probed at
# most ONCE per run, whichever code path asks about it.
#
# The verdict is written with a redirection, never through a `probe_pick | tee` pipeline: that would
# put the producer in a subshell and let a partial file become the cached verdict. The key is the
# full sha, so two commits sharing a 7-char prefix cannot read each other's verdict. Any unexpected
# failure degrades to "error", which every caller treats as "leave it alone".
probe_cached() {
  local c="$1" f="$TMP/verdict-${1}" st
  if [ -f "$f" ]; then cat "$f"; return 0; fi
  st="$(probe_pick "$c")" || st=error
  printf '%s\n' "$st" > "$f"
  printf '%s\n' "$st"
  return 0
}

# Stops treating a commit as "already skipped" for the remainder of this run, so the candidate loop
# reconsiders it right away (used right after its obsolete issue was closed).
remove_known_skipped() {
  local s="${1:0:7}"
  : > "$TMP/issue_titles.tmp"
  grep -vF -- "$s" "$TMP/issue_titles" > "$TMP/issue_titles.tmp" 2>/dev/null || true
  mv "$TMP/issue_titles.tmp" "$TMP/issue_titles"
}

# Closes the open draft PR of conflict/<sha7> and deletes the branch -- but ONLY while the branch is
# intact. Returns 0 when there is nothing left to protect or the branch was retired, 1 when it was
# left alone because it carries manual work.
close_conflict_if_intact() {
  local s7="$1" comment="$2" br="conflict/${1:0:7}" pr=""
  if ! git rev-parse -q --verify "origin/${br}" >/dev/null 2>&1; then return 0; fi
  if ! branch_intact "origin/${br}"; then
    log "${br}: branch has manual work, leaving as is"
    return 1
  fi
  if is_dry; then
    log "(dry-run) would close the draft PR for ${br} and delete the branch"
    return 0
  fi
  pr="$(gh pr list -R "$REPO" --head "$br" --state open --json number --jq '.[0].number // empty' 2>/dev/null || true)"
  if [ -n "$pr" ]; then
    gh pr close "$pr" -R "$REPO" --delete-branch --comment "$comment" >/dev/null 2>&1 || true
    OPEN_CONFLICT_PRS=$((OPEN_CONFLICT_PRS - 1))
  else
    git push -q origin --delete "$br" >/dev/null 2>&1 || true
  fi
  return 0
}

# Explicit retry_sha only: rebuilds an EXISTING conflict/<sha7> against the current default branch,
# and only while that branch is intact. When the commit now applies cleanly (or is empty), the branch
# and its draft PR are retired instead. Returns 1 when the branch was retired, 0 otherwise.
rebuild_conflict_branch() {
  local c="$1" s7="${1:0:7}" br="conflict/${1:0:7}" wt="$TMP/rebuild-${1:0:7}" st expected
  expected="$(git ls-remote --heads origin "refs/heads/${br}" 2>/dev/null || true)"
  expected="${expected%%$'\n'*}"
  expected="${expected%%$'\t'*}"
  if [ -z "$expected" ]; then return 0; fi
  if ! branch_intact "origin/${br}"; then
    log "${br}: branch has manual work, leaving as is"
    return 0
  fi

  st="$(probe_cached "$c")"
  case "$st" in
    clean|empty)
      log "${s7} no longer conflicts against ${DEFAULT_BRANCH} (${st}); retiring ${br}"
      close_conflict_if_intact "$s7" "No longer conflicts against ${DEFAULT_BRANCH}; it will be picked up by the sync PR." || true
      return 1
      ;;
    conflict) : ;;
    *)
      log "${br}: could not re-check it against ${DEFAULT_BRANCH}; leaving as is"
      return 0
      ;;
  esac

  if is_dry; then log "(dry-run) would rebuild ${br} against ${DEFAULT_BRANCH}"; return 0; fi

  git worktree remove --force "$wt" >/dev/null 2>&1 || true
  rm -rf "$wt"
  if ! git worktree add -q --detach "$wt" "origin/${DEFAULT_BRANCH}" >/dev/null 2>&1; then
    log "could not create a worktree to rebuild ${br}"
    git worktree prune >/dev/null 2>&1 || true
    return 0
  fi
  # The pick below re-materializes the conflict: it is a rebuild, not another probe (the verdict
  # comes from probe_cached, so this commit was tested at most once).
  if ! git -C "$wt" cherry-pick "$c" > "$TMP/rebuild-${s7}.log" 2>&1; then
    git -C "$wt" add -A
    git -C "$wt" commit -q --no-verify -C "$c" || true
    if git -C "$wt" push -q --force-with-lease="refs/heads/${br}:${expected}" origin "HEAD:refs/heads/${br}" >/dev/null 2>&1; then
      log "rebuilt ${br} against ${DEFAULT_BRANCH} (was ${expected:0:7})"
    else
      log "could not rebuild ${br} (pushed to in the meantime?); leaving as is"
    fi
  fi
  git -C "$wt" cherry-pick --abort >/dev/null 2>&1 || true
  git worktree remove --force "$wt" >/dev/null 2>&1 || true
  rm -rf "$wt"
  git worktree prune >/dev/null 2>&1 || true
  return 0
}

# Re-examines every commit that still has an OPEN "skipped" issue and retires what no longer needs a
# human: the change already reached the default branch (superseded), or it no longer conflicts and can
# be handed back to the candidate loop. A commit that still conflicts, or whose branch a human already
# touched, is left completely alone. "No longer conflicts" only un-masks the commit here: its issue is
# closed later, and only once the commit really made it into the sync PR.
reevaluate_open_issues() {
  local line n title s7 c st note
  git rev-list "upstream/${UPSTREAM_BRANCH}" > "$TMP/upstream_shas" 2>/dev/null || true

  while IFS= read -r line; do
    [ -n "$line" ] || continue
    n="${line%% *}"; title="${line#* }"
    if [[ ! "$title" =~ Upstream\ skipped:\ ([0-9a-f]{7}) ]]; then continue; fi
    s7="${BASH_REMATCH[1]}"
    # Applied (trailer) or ignored is cleanup_resolved()'s job: don't duplicate that logic here.
    if sha7_resolved "$s7"; then continue; fi

    c="$(grep -m1 "^${s7}" "$TMP/upstream_shas" 2>/dev/null || true)"
    if [ -z "$c" ]; then
      log "issue #${n}: ${s7} is no longer in upstream/${UPSTREAM_BRANCH}; leaving as is"
      continue
    fi

    REEVALUATED=$((REEVALUATED + 1))
    st="$(probe_cached "$c")"
    case "$st" in
      empty)
        note="Superseded: its changes are already on ${DEFAULT_BRANCH}."
        log "issue #${n}: ${s7} is superseded, its changes are already on ${DEFAULT_BRANCH}"
        if ! close_conflict_if_intact "$s7" "$note"; then
          log "issue #${n} left open as well: conflict/${s7} carries manual work"
          continue
        fi
        if is_dry; then
          log "(dry-run) would close issue #${n}"
        elif ! gh issue close "$n" -R "$REPO" --reason completed --comment "$note" >/dev/null 2>&1; then
          log "warning: could not close issue #${n}"
        fi
        # No longer masked for this run, so the candidate loop reconsiders the commit right now.
        remove_known_skipped "$c"
        ;;
      clean)
        # "Applies cleanly against the default branch" is not the same as "will enter the sync PR":
        # the candidate loop stacks the picks on top of each other, so this commit can still collide
        # with the ones already pending in the PR. Closing the issue here un-masked the commit, the
        # pick then conflicted on the sync branch, skip_commit found no dedup entry and opened a fresh
        # issue for it -- every run, forever. So the issue stays open: the commit is only retried right
        # away, and the issue is closed further down, and only if it really made it into the PR.
        if ! close_conflict_if_intact "$s7" "No longer conflicts against ${DEFAULT_BRANCH}; retrying it."; then
          log "issue #${n} left open as well: conflict/${s7} carries manual work"
          continue
        fi
        log "issue #${n}: ${s7} no longer conflicts against ${DEFAULT_BRANCH}; retrying it in this run"
        printf '%s\n' "$c" >> "$TMP/force_retry"
        printf '%s %s\n' "$n" "$s7" >> "$TMP/reeval_clean"
        ;;
      conflict)
        log "issue #${n}: ${s7} still conflicts against ${DEFAULT_BRANCH}; leaving as is"
        ;;
      *)
        log "issue #${n}: could not re-check ${s7} against ${DEFAULT_BRANCH}; leaving as is"
        ;;
    esac
  done < <(gh issue list -R "$REPO" --label upstream-conflict --state open --limit 1000 \
             --json number,title --jq '.[] | "\(.number) \(.title)"' 2>/dev/null || true)
}

# skip_commit <sha> <reason> [details]
skip_commit() {
  local c="$1" reason="$2" details="${3:-}" s7 subject title body pr_url="" line reuse=false
  s7="${c:0:7}"
  subject="$(git log -1 --format=%s "$c")"
  line="${BT}${s7}${BT} ${subject} — ${reason%%$'\n'*}"

  # One open issue per commit, ever: a retry_sha run walks over the same commit again, and the issue
  # is already the durable record for it. Reuse that one instead of opening a duplicate.
  if known_skipped "$c"; then reuse=true; fi

  # Quiet path. A commit whose issue is already open only gets here when the bot itself re-tried it
  # (reevaluate_open_issues found it clean against the default branch, so it is picked again on top
  # of the pending commits and may collide with one of them). That is the SAME situation as in the
  # previous run: the issue is already the record of it, so do not list it as "skipped" again --
  # that would repeat the Discord message and the PR-body line every 30 minutes. An explicit
  # retry_sha is a manual run: it still reports.
  if [ "$reuse" = true ] && ! { [ -n "$RETRY_SHA" ] && [[ "$c" == "$RETRY_SHA"* ]]; }; then
    KNOWN=$((KNOWN + 1))
    log "issue for ${s7} is already open; reusing it, not reporting it again (${reason%%$'\n'*})"
    return 0
  fi

  if [ "$ISSUES" -ge "$MAX_ISSUES" ]; then
    DEFERRED=$((DEFERRED + 1)); SKIPPED+=("$line"); return 0
  fi

  if [ "$reason" = "merge conflict" ]; then
    pr_url="$(make_conflict_pr "$c" "$details" || true)"
    if [ -n "$pr_url" ]; then line="${line} — [draft PR](${pr_url})"; fi
  fi
  SKIPPED+=("$line")

  local pr_section="" manual_heading="### Resolve it"
  if [ -n "$pr_url" ]; then
    pr_section="### Resolve it — draft PR
${pr_url}

$(branch_steps "$c")

"
    manual_heading="### Or resolve it by hand on ${DEFAULT_BRANCH}"
  fi

  title="⏭️ Upstream skipped: ${s7} ${subject}"
  body="$(cat <<EOF
**Commit:** [${BT}${s7}${BT}](${UP_WEB}/commit/${c}) — ${subject}
**Reason:** ${reason}

${details:+**Details:**
${FENCE}
${details:0:1500}
${FENCE}
}
The sync skipped it and carried on with the rest. Later commits that depend on this one may be skipped too.
This issue closes itself once the commit is applied (with the ${BT}cherry picked from${BT} trailer) or ignored.

${pr_section}${manual_heading}
${FENCE}bash
git checkout ${DEFAULT_BRANCH} && git pull
git remote add upstream ${UPSTREAM_URL}   # only if you don't have it
git fetch upstream
git cherry-pick -x ${c}                   # -x is REQUIRED: it is how the sync knows it's applied
# fix what is needed (conflicts / syntax), then:
git add <files> && git cherry-pick --continue
git push
${FENCE}

### Discard it
Add ${BT}${s7}${BT} to ${BT}.upstream-ignore${BT} on ${BT}${DEFAULT_BRANCH}${BT}.

### Retry it later
Actions → *Sync upstream* → *Run workflow* → ${BT}retry_sha${BT} = ${BT}${s7}${BT}
EOF
)"

  if is_dry; then
    if [ "$reuse" = true ]; then
      log "(dry-run) issue for ${s7} is already open; would not open a duplicate"
    else
      log "(dry-run) would open issue: $title"
    fi
    return 0
  fi
  if [ "$reuse" = true ]; then
    log "issue for ${s7} is already open; reusing it instead of opening a duplicate"
    return 0
  fi
  if gh issue create -R "$REPO" --label upstream-conflict --assignee "${OWNER:-$REPO}" \
        --title "$title" --body "$body" >/dev/null 2>&1 \
     || gh issue create -R "$REPO" --label upstream-conflict \
        --title "$title" --body "$body" >/dev/null 2>&1; then
    ISSUES=$((ISSUES + 1))
  else
    log "warning: could not open an issue for ${s7}"
  fi
}

# ------------------------------------------------------------------ setup ---
git config user.name  "${GIT_USER_NAME:-github-actions[bot]}"
git config user.email "${GIT_USER_EMAIL:-41898282+github-actions[bot]@users.noreply.github.com}"
if ! git remote get-url upstream >/dev/null 2>&1; then git remote add upstream "$UPSTREAM_URL"; fi

retry git fetch -q --no-tags upstream "+refs/heads/${UPSTREAM_BRANCH}:refs/remotes/upstream/${UPSTREAM_BRANCH}" \
  || die "Could not fetch ${UPSTREAM_URL} (${UPSTREAM_BRANCH}). Renamed, deleted or private?"
retry git fetch -q --no-tags origin "+refs/heads/*:refs/remotes/origin/*" \
  || die "Could not fetch origin"

BASELINE="$(git show "origin/${DEFAULT_BRANCH}:.upstream-baseline" 2>/dev/null | tr -d '[:space:]' || true)"
[ -n "$BASELINE" ] || die ".upstream-baseline is missing on ${DEFAULT_BRANCH}"
if ! git merge-base --is-ancestor "$BASELINE" "upstream/${UPSTREAM_BRANCH}" 2>/dev/null; then
  die "Baseline ${BASELINE:0:7} is not in upstream/${UPSTREAM_BRANCH} any more (upstream rewrote history?). Update .upstream-baseline."
fi

if ! is_dry; then
  gh label create upstream-sync     -R "$REPO" --color 0E8A16 --description "Automated upstream sync"        >/dev/null 2>&1 || true
  gh label create upstream-conflict -R "$REPO" --color D93F0B --description "Upstream commit skipped by sync" >/dev/null 2>&1 || true
fi

# Already applied on the default branch (SHAs from "cherry picked from commit" trailers)
git log "origin/${DEFAULT_BRANCH}" --format=%B \
  | grep -oE 'cherry picked from commit [0-9a-f]{40}' | awk '{print $NF}' | sort -u > "$TMP/applied" || true

# Manually ignored commits
git show "origin/${DEFAULT_BRANCH}:.upstream-ignore" 2>/dev/null \
  | sed 's/#.*//' | awk 'NF {print $1}' > "$TMP/ignored" || true

# Commits that already have an OPEN "skipped" issue.
#
# Open only, deliberately. A closed issue is not proof the commit landed: cleanup_resolved()
# closes the issue once the trailer reaches the default branch, but a squash merge drops that
# trailer, and closing the issue by hand hides the commit for good. With `--state all` such a
# commit is masked forever and the sync silently stops retrying it. That is how e00daaa stayed
# half-applied on main for so long: PR #18 was squash-merged, which landed literal conflict
# markers and lost the trailer, a follow-up commit stripped the marker lines without resolving
# the conflicts, and the closed issue #19 meant no run ever retried it.
# Genuinely applied commits are unaffected: the candidate loop checks the `applied` trailer
# list before known_skipped(), so it short-circuits them regardless of issue state. To skip a
# commit permanently, list it in .upstream-ignore, which is checked by is_ignored() and states
# the intent explicitly.
gh issue list -R "$REPO" --label upstream-conflict --state open --limit 1000 \
  --json title --jq '.[].title' > "$TMP/issue_titles" 2>/dev/null || : > "$TMP/issue_titles"

# Close issues / draft PRs that were resolved since the last run
cleanup_resolved

# Re-check the commits that still have an open issue: some of them no longer need a human at all.
reevaluate_open_issues

# Build the branch from the default branch
git checkout -q -f -B "$SYNC_BRANCH" "origin/${DEFAULT_BRANCH}"
check_toc > "$TMP/toc_before" || true

# ------------------------------------------------------------ cherry-pick ---
mapfile -t CANDIDATES < <(git rev-list --reverse --no-merges "${BASELINE}..upstream/${UPSTREAM_BRANCH}")
log "candidates after baseline: ${#CANDIDATES[@]}"

PICKED=()
KNOWN=0
ALREADY=0
# sha7 of every commit that entered the sync branch this run (picked, or found applied by the pick):
# only those can resolve a re-evaluated issue. See the closing block after the PR bookkeeping.
: > "$TMP/entered"

for c in "${CANDIDATES[@]}"; do
  if grep -qx "$c" "$TMP/applied"; then ALREADY=$((ALREADY + 1)); continue; fi
  if is_ignored "$c"; then continue; fi

  retrying=false
  if [ -n "$RETRY_SHA" ] && [[ "$c" == "$RETRY_SHA"* ]]; then retrying=true; fi
  # A commit re-evaluated as "clean" this run is retried right away even though its issue is still
  # open (see reevaluate_open_issues): skipping it here would throw the whole re-check away.
  forced=false
  if [ -s "$TMP/force_retry" ] && grep -qxF -- "$c" "$TMP/force_retry"; then forced=true; fi
  if [ "$retrying" = false ] && [ "$forced" = false ] && known_skipped "$c"; then KNOWN=$((KNOWN + 1)); continue; fi

  changed_files="$(git diff-tree --no-commit-id --name-only -r "$c")"
  if grep -q '^\.github/workflows/' <<< "$changed_files"; then
    skip_commit "$c" "touches ${BT}.github/workflows/${BT} (GITHUB_TOKEN cannot push workflow changes)"
    continue
  fi

  if git cherry-pick -x "$c" > "$TMP/pick.log" 2>&1; then
    bad=""
    while IFS= read -r f; do
      if [ ! -f "$f" ]; then continue; fi
      # luac5.1 rejects a UTF-8 BOM, and several files in this repo legitimately start
      # with one (tab_minimap, minimap, castbar, the LibKeyBound locales, ...). Parsing
      # them raw reports a bogus "Lua syntax error" and skips a perfectly good commit.
      # Parse a BOM-stripped copy in that case, and map the copy's path back to the real
      # file in the message so the skip-issue still names something actionable.
      if [ "$(head -c3 "$f" | od -An -tx1 | tr -d ' \n')" = "efbbbf" ]; then
        luac_src="$TMP/luacheck.lua"; sed '1s/^\xEF\xBB\xBF//' "$f" > "$luac_src"
        if ! err="$(luac5.1 -p "$luac_src" 2>&1)"; then bad+="${err//$luac_src/$f}"$'\n'; fi
      elif ! err="$(luac5.1 -p "$f" 2>&1)"; then bad+="${err}"$'\n'; fi
    done < <(git diff-tree --no-commit-id --name-only -r --diff-filter=AM HEAD -- '*.lua')
    if [ -n "$bad" ]; then
      git reset -q --hard HEAD~1
      skip_commit "$c" "Lua syntax error after applying it" "$bad"
      continue
    fi
    PICKED+=("$c")
    printf '%s\n' "${c:0:7}" >> "$TMP/entered"
  else
    unmerged="$(git diff --name-only --diff-filter=U || true)"
    tail_log="$(tail -n 5 "$TMP/pick.log")"
    git cherry-pick --abort >/dev/null 2>&1 || true
    git reset -q --hard HEAD
    if [ -n "$unmerged" ]; then
      skip_commit "$c" "merge conflict" "$unmerged"
    elif grep -qi 'empty' "$TMP/pick.log"; then
      log "already applied (empty cherry-pick): ${c:0:7}"
      printf '%s\n' "${c:0:7}" >> "$TMP/entered"
      ALREADY=$((ALREADY + 1))
    else
      skip_commit "$c" "cherry-pick failed" "$tail_log"
    fi
  fi
done

log "picked=${#PICKED[@]} skipped_now=${#SKIPPED[@]} skipped_before=${KNOWN} already_applied=${ALREADY} reevaluated=${REEVALUATED}"

# ------------------------------------------------------- PR bookkeeping ---
PR_NUM="$(gh pr list -R "$REPO" --head "$SYNC_BRANCH" --state open --json number --jq '.[0].number // empty' 2>/dev/null || true)"
OLD_SHA="$(git rev-parse -q --verify "refs/remotes/origin/${SYNC_BRANCH}" || true)"
MSGS=()
PR_URL=""

if [ "${#PICKED[@]}" -eq 0 ]; then
  # Nothing pending: clean up any stale PR/branch, no duplicates, no noise.
  if [ -n "$PR_NUM" ]; then
    if is_dry; then
      log "(dry-run) would close PR #${PR_NUM}"
    else
      gh pr close "$PR_NUM" -R "$REPO" --delete-branch \
        --comment "No pending upstream commits remain (applied, ignored or skipped). Closing." >/dev/null || true
      MSGS+=("ℹ️ **DragonUI sync** — nothing pending any more, PR #${PR_NUM} closed.")
    fi
  elif [ -n "$OLD_SHA" ] && ! is_dry; then
    git push -q origin --delete "$SYNC_BRANCH" || true
  fi
else
  NEW_TREE="$(git rev-parse 'HEAD^{tree}')"
  OLD_TREE=""
  : > "$TMP/old_set"
  if [ -n "$OLD_SHA" ]; then
    OLD_TREE="$(git rev-parse "${OLD_SHA}^{tree}")"
    git log "origin/${DEFAULT_BRANCH}..${OLD_SHA}" --format=%B \
      | grep -oE 'cherry picked from commit [0-9a-f]{40}' | awk '{print $NF}' | sort -u > "$TMP/old_set" || true
  fi
  # Commits NEW to the PR (not in the previous branch), in upstream order
  : > "$TMP/added"
  for c in "${PICKED[@]}"; do
    if ! grep -qx "$c" "$TMP/old_set"; then echo "$c" >> "$TMP/added"; fi
  done

  check_toc > "$TMP/toc_after" || true
  NEW_MISSING="$(comm -13 <(sort "$TMP/toc_before") <(sort "$TMP/toc_after") || true)"

  CHANGED=false
  if [ "$NEW_TREE" != "$OLD_TREE" ]; then CHANGED=true; fi

  TITLE="Sync upstream: ${#PICKED[@]} pending commit(s)"
  BODY="$TMP/pr_body.md"
  {
    echo "Automatic sync from [${UP_WEB#https://github.com/}](${UP_WEB}). **Review and merge manually.**"
    echo
    echo "> Merge with **Rebase and merge** or a **merge commit**, NOT *Squash*: the ${BT}(cherry picked from commit …)${BT} trailers are how the sync knows what is already applied."
    echo "> Don't push to this branch: it is rebuilt on every run. Fix conflicts on ${BT}${DEFAULT_BRANCH}${BT} instead."
    echo
    echo "### Commits (${#PICKED[@]})"
    for c in "${PICKED[@]}"; do
      mark=""
      if grep -qx "$c" "$TMP/added"; then mark=" 🆕"; fi
      echo "- [${BT}${c:0:7}${BT}](${UP_WEB}/commit/${c}) $(git log -1 --format=%s "$c")${mark}"
    done
    if [ "${#SKIPPED[@]}" -gt 0 ]; then
      echo
      echo "### Skipped in this run (${#SKIPPED[@]}) — see issues labelled ${BT}upstream-conflict${BT}"
      printf -- '- %s\n' "${SKIPPED[@]}"
    fi
    if [ "$KNOWN" -gt 0 ]; then
      echo
      echo "_${KNOWN} commit(s) skipped earlier are still pending in open issues._"
    fi
    if [ -n "$NEW_MISSING" ]; then
      echo
      echo "### ⚠️ ${BT}.toc${BT} references files that do not exist"
      echo "$NEW_MISSING"
    fi
  } > "$BODY"

  PR_NEW=false
  if is_dry; then
    log "(dry-run) would push ${SYNC_BRANCH} and create/update the PR:"
    cat "$BODY"
  else
    if [ "$CHANGED" = true ]; then
      git push -q --force-with-lease="refs/heads/${SYNC_BRANCH}:${OLD_SHA}" origin "HEAD:refs/heads/${SYNC_BRANCH}"
    fi
    if [ -z "$PR_NUM" ]; then
      PR_URL="$(gh pr create -R "$REPO" --base "$DEFAULT_BRANCH" --head "$SYNC_BRANCH" \
                  --title "$TITLE" --body-file "$BODY" --label upstream-sync)"
      PR_NEW=true
      if [ -n "$OWNER" ]; then gh pr edit "$PR_URL" --add-assignee "$OWNER" >/dev/null 2>&1 || true; fi
    else
      PR_URL="$(gh pr view "$PR_NUM" -R "$REPO" --json url --jq .url)"
      if [ "$CHANGED" = true ]; then
        gh pr edit "$PR_NUM" -R "$REPO" --title "$TITLE" --body-file "$BODY" >/dev/null
      fi
    fi
  fi

  # Only speak up when there is something new for the PR
  if [ "$PR_NEW" = true ] || [ -s "$TMP/added" ]; then
    n_added="$(wc -l < "$TMP/added" | tr -d ' ')"
    verb="updated"; if [ "$PR_NEW" = true ]; then verb="opened"; fi
    MSGS+=("🟢 **DragonUI sync** — PR ${verb}: ${#PICKED[@]} pending, ${n_added} new")
    while IFS= read -r c; do
      MSGS+=("$(git log -1 --format='- `%h` %s' "$c")")
    done < <(head -n 8 "$TMP/added")
    if [ "$n_added" -gt 8 ]; then MSGS+=("- …and $((n_added - 8)) more"); fi
    MSGS+=("${PR_URL:-(dry-run)}")
  fi
  if [ -n "$NEW_MISSING" ]; then
    MSGS+=("⚠️ The new commits leave ${BT}.toc${BT} pointing at missing files:")
    MSGS+=("$(echo "$NEW_MISSING" | head -n 5)")
  fi
fi

# A commit re-evaluated as "clean" that actually entered the sync PR this run (or turned out to be
# applied already) is genuinely resolved: close the issue that was waiting on it. A commit that
# collided with a pending pick is NOT in $TMP/entered, so its issue stays open, and the next run
# reuses it instead of opening a duplicate.
if [ -s "$TMP/reeval_clean" ] && [ -s "$TMP/entered" ]; then
  while read -r n s7; do
    [ -n "$s7" ] || continue
    if ! grep -qxF -- "$s7" "$TMP/entered"; then continue; fi
    if is_dry; then
      log "(dry-run) would close issue #${n} (${s7} is now in the sync PR)"
    elif gh issue close "$n" -R "$REPO" --reason completed \
           --comment "No longer conflicts against ${DEFAULT_BRANCH}; its change is now in the sync PR." >/dev/null 2>&1; then
      log "issue #${n} closed: ${s7} is now in the sync PR"
    else
      log "warning: could not close issue #${n}"
    fi
  done < "$TMP/reeval_clean"
fi

if [ "${#SKIPPED[@]}" -gt 0 ]; then
  MSGS+=("⏭️ **${#SKIPPED[@]} commit(s) skipped** (one open issue per commit):")
  for s in "${SKIPPED[@]:0:8}"; do MSGS+=("- ${s}"); done
  if [ "$DEFERRED" -gt 0 ]; then
    MSGS+=("(${DEFERRED} without an issue yet: cap of ${MAX_ISSUES} per run, the rest come next run)")
  fi
  MSGS+=("${GITHUB_SERVER_URL:-https://github.com}/${REPO}/issues?q=is%3Aopen+label%3Aupstream-conflict")
fi

if [ "${#MSGS[@]}" -gt 0 ]; then notify "$(printf '%s\n' "${MSGS[@]}")"; fi

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  {
    echo "### Sync upstream"
    echo "- picked (in PR): ${#PICKED[@]}"
    echo "- skipped now: ${#SKIPPED[@]}  |  skipped earlier: ${KNOWN}  |  already applied: ${ALREADY}"
    echo "- open issues re-evaluated: ${REEVALUATED}"
    if [ -n "$PR_URL" ]; then echo "- PR: ${PR_URL}"; fi
    echo "- run: ${RUN_URL}"
  } >> "$GITHUB_STEP_SUMMARY"
fi

log "done"
