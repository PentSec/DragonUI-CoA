-- Profession tab for the DragonUI spellbook.
-- GetSpellBookIndex). Learned professions become normal spellbook cards built from their
-- crafting spell (cast, drag, tooltip, cooldown); the rest are grey cards.
local addon = select(2, ...)
local Book = addon.SpellbookModule

local tr = addon.L

-- Same order as Conquest of Azeroth tab; Jewelcrafting / Inscription only where the expansion has them.
local function professionOrder()
    local P = Enum and Enum.Profession
    if not P then return {} end
    local order = {
        P.Blacksmithing, P.Alchemy, P.Enchanting, P.Engineering,
        P.Leatherworking, P.Tailoring, P.Woodworking,
        P.Herbalism, P.Mining, P.Skinning, P.Woodcutting,
        P.Cooking, P.FirstAid, P.Fishing, P.Bushcraft,
    }
    local expansion = GetExpansionLevel and GetExpansionLevel() or 0
    if Enum.Expansion and expansion >= Enum.Expansion.TBC and P.Jewelcrafting then
        tinsert(order, 5, P.Jewelcrafting)
    end
    if Enum.Expansion and expansion >= Enum.Expansion.WoTLK and P.Inscription then
        tinsert(order, 8, P.Inscription)
    end
    return order
end

local QUESTION_MARK = "Interface\\Icons\\INV_Misc_QuestionMark"

-- Every profession in Conquest of Azeroth order: learned ones first (live cards), then the rest as
-- grey cards. A grey card carries no cast, so it never gets a secure slot and cannot be
-- clicked or dragged; it only shows a tooltip with where to learn it.
local function allProfessions()
    local learned, unlearned = {}, {}
    if not (ProfessionUtil and ProfessionUtil.GetProfessionByID and GetSpellBookIndex) then
        return learned, unlearned
    end
    for _, skillID in ipairs(professionOrder()) do
        local name, rankText, icon, rank, modifier, maxRank, craftingSpellID, _, _, description =
            ProfessionUtil.GetProfessionByID(skillID)
        local known = rank ~= nil and maxRank ~= nil
        -- Same as Conquest of Azeroth tab: Bushcraft only shows once it is available.
        local hidden = skillID == Enum.Profession.Bushcraft and not known
        if name and not hidden then
            local entry
            if known and craftingSpellID then
                local index = GetSpellBookIndex(craftingSpellID, BOOKTYPE_SPELL or "spell")
                entry = index and Book.ReadSlot(index, "spell")
            end
            if entry then
                entry.name = name
                entry.icon = icon or entry.icon
                entry.sub = (rank + (modifier or 0)) .. "/" .. maxRank
                entry.key = "prof:" .. skillID
                entry.prof, entry.skillID = true, skillID
                learned[#learned + 1] = entry
            else
                unlearned[#unlearned + 1] = {
                    grey = true,
                    prof = true,
                    skillID = skillID,
                    learned = known,
                    name = name,
                    icon = icon or QUESTION_MARK,
                    description = description,
                    spellID = craftingSpellID,
                    -- Shared code formats these for trainer cards; they only need to be valid.
                    level = 1,
                    cost = 0,
                    state = "profession",
                    profSub = known and ((rank + (modifier or 0)) .. "/" .. maxRank)
                        or (tr["Not learned"] or "Not learned"),
                    key = "prof:" .. skillID,
                }
            end
        end
    end
    return learned, unlearned
end

function Book.ProfessionExists()
    local learned, unlearned = allProfessions()
    return #learned + #unlearned > 0
end

function Book.ProfessionLabel()
    return tr["Professions"] or PROFESSIONS_BUTTON or "Professions"
end

function Book.ProfessionSections(filters)
    local learned, unlearned = allProfessions()
    local list = {}
    local function add(entries)
        for _, entry in ipairs(entries) do
            if not filters or Book.NameMatches(entry.name, filters.query) then
                list[#list + 1] = entry
            end
        end
    end
    add(learned)
    if not (filters and filters.hideUnlearned) then add(unlearned) end
    if #list == 0 then return {} end
    return { { title = Book.ProfessionLabel(), entries = list } }
end

-- Hook the catalog so the PROFESSION category uses our builders.
local _CategoryExists = Book.CategoryExists
function Book.CategoryExists(cat)
    if cat == Book.PROFESSION then return Book.ProfessionExists() end
    return _CategoryExists(cat)
end

local _BuildSections = Book.BuildSections
function Book.BuildSections(cat, filters)
    if cat == Book.PROFESSION then return Book.ProfessionSections(filters) end
    return _BuildSections(cat, filters)
end

local _CategoryLabel = Book.CategoryLabel
function Book.CategoryLabel(cat)
    if cat == Book.PROFESSION then return Book.ProfessionLabel() end
    return _CategoryLabel(cat)
end

-- Grey profession cards: the shared paint / tooltip / link code speaks trainer data, so those
-- three entry points get a small branch and everything else passes straight through.
local _PaintCard = Book.PaintCard
function Book.PaintCard(card, entry)
    _PaintCard(card, entry)
    if entry and entry.prof and entry.grey then
        card.sub:SetText(entry.profSub or "")
    end
end

local _CardEnter = Book.CardEnter
function Book.CardEnter(card)
    local entry = card and card.entry
    if not (entry and entry.prof and entry.grey) then return _CardEnter(card) end
    Book.SetCardPointer(card, true, card.pressed)
    GameTooltip:SetOwner(card, "ANCHOR_RIGHT")
    GameTooltip:AddLine(entry.name, 1, 1, 1)
    if entry.description then GameTooltip:AddLine(entry.description, 1, 0.82, 0, true) end
    if not entry.learned and PROFESSION_WHERE_TO_LEARN then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(PROFESSION_WHERE_TO_LEARN:format(entry.name), 1, 0.82, 0, true)
    end
    card.UpdateTooltip = nil
    GameTooltip:Show()
end

local _InsertLink = Book.InsertLink
function Book.InsertLink(entry)
    if entry and entry.prof and entry.grey and not entry.spellID then return end
    return _InsertLink(entry)
end

-- Learning a profession or a skill-up does not always fire SPELLS_CHANGED.
Book.On("SKILL_LINES_CHANGED", function() Book.MarkDirty(Book.PROFESSION) end)