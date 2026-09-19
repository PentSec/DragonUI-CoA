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
#  - A commit that conflicts also gets a branch conflict/<sha7> (conflict markers committed)
#    and a DRAFT PR, so it can be resolved right there. Drafts can't be merged by accident.
#  - Once a skipped commit is applied (trailer) or ignored, its issue and draft PR close themselves.
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
  local c="$1" files="$2" s7="${1:0:7}" br="conflict/${1:0:7}" wt url subject
  wt="$TMP/wt-${s7}"
  if is_dry; then log "(dry-run) would open a draft PR from ${br}"; return 0; fi
  if [ "$OPEN_CONFLICT_PRS" -ge "$MAX_OPEN_CONFLICT_PRS" ]; then
    log "already ${OPEN_CONFLICT_PRS} open conflict PRs; issue only for ${s7}"; return 0
  fi
  subject="$(git log -1 --format=%s "$c")"

  if ! git ls-remote --exit-code --heads origin "$br" >/dev/null 2>&1; then
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
      echo "> ⚠️ **DRAFT — this branch contains conflict markers.** Don't merge until they are resolved."
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
             --label upstream-conflict 2>/dev/null | tail -n 1)" || url=""
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

# skip_commit <sha> <reason> [details]
skip_commit() {
  local c="$1" reason="$2" details="${3:-}" s7 subject title body pr_url="" line
  s7="${c:0:7}"
  subject="$(git log -1 --format=%s "$c")"
  line="${BT}${s7}${BT} ${subject} — ${reason%%$'\n'*}"

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

  if is_dry; then log "(dry-run) would open issue: $title"; return 0; fi
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
git config user.name  "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
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

# Commits that already have a "skipped" issue (open or closed)
gh issue list -R "$REPO" --label upstream-conflict --state all --limit 1000 \
  --json title --jq '.[].title' > "$TMP/issue_titles" 2>/dev/null || : > "$TMP/issue_titles"

# Close issues / draft PRs that were resolved since the last run
cleanup_resolved

# Build the branch from the default branch
git checkout -q -f -B "$SYNC_BRANCH" "origin/${DEFAULT_BRANCH}"
check_toc > "$TMP/toc_before" || true

# ------------------------------------------------------------ cherry-pick ---
mapfile -t CANDIDATES < <(git rev-list --reverse --no-merges "${BASELINE}..upstream/${UPSTREAM_BRANCH}")
log "candidates after baseline: ${#CANDIDATES[@]}"

PICKED=()
KNOWN=0
ALREADY=0

for c in "${CANDIDATES[@]}"; do
  if grep -qx "$c" "$TMP/applied"; then ALREADY=$((ALREADY + 1)); continue; fi
  if is_ignored "$c"; then continue; fi

  retrying=false
  if [ -n "$RETRY_SHA" ] && [[ "$c" == "$RETRY_SHA"* ]]; then retrying=true; fi
  if [ "$retrying" = false ] && known_skipped "$c"; then KNOWN=$((KNOWN + 1)); continue; fi

  changed_files="$(git diff-tree --no-commit-id --name-only -r "$c")"
  if grep -q '^\.github/workflows/' <<< "$changed_files"; then
    skip_commit "$c" "touches ${BT}.github/workflows/${BT} (GITHUB_TOKEN cannot push workflow changes)"
    continue
  fi

  if git cherry-pick -x "$c" > "$TMP/pick.log" 2>&1; then
    bad=""
    while IFS= read -r f; do
      if [ ! -f "$f" ]; then continue; fi
      if ! err="$(luac5.1 -p "$f" 2>&1)"; then bad+="${err}"$'\n'; fi
    done < <(git diff-tree --no-commit-id --name-only -r --diff-filter=AM HEAD -- '*.lua')
    if [ -n "$bad" ]; then
      git reset -q --hard HEAD~1
      skip_commit "$c" "Lua syntax error after applying it" "$bad"
      continue
    fi
    PICKED+=("$c")
  else
    unmerged="$(git diff --name-only --diff-filter=U || true)"
    tail_log="$(tail -n 5 "$TMP/pick.log")"
    git cherry-pick --abort >/dev/null 2>&1 || true
    git reset -q --hard HEAD
    if [ -n "$unmerged" ]; then
      skip_commit "$c" "merge conflict" "$unmerged"
    elif grep -qi 'empty' "$TMP/pick.log"; then
      log "already applied (empty cherry-pick): ${c:0:7}"
      ALREADY=$((ALREADY + 1))
    else
      skip_commit "$c" "cherry-pick failed" "$tail_log"
    fi
  fi
done

log "picked=${#PICKED[@]} skipped_now=${#SKIPPED[@]} skipped_before=${KNOWN} already_applied=${ALREADY}"

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

if [ "${#SKIPPED[@]}" -gt 0 ]; then
  MSGS+=("⏭️ **${#SKIPPED[@]} commit(s) skipped** (one issue opened for each):")
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
    if [ -n "$PR_URL" ]; then echo "- PR: ${PR_URL}"; fi
    echo "- run: ${RUN_URL}"
  } >> "$GITHUB_STEP_SUMMARY"
fi

log "done"
