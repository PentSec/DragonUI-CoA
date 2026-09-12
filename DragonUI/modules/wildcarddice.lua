local addon = select(2, ...)
local L = addon.L

-- ============================================================================
-- WildCardDice movability widget
-- ============================================================================
-- Ascension creates `_G.WildCardDice` (256x128, default TOP UIParent TOP 0 -32).
-- It only shows during Draft / WildCard rolls. This widget lets the user
-- reposition it via DragonUI Editor Mode and persists the position per profile
-- in `addon.db.profile.widgets.wildcarddice`.
--
-- No styling, no module toggle: pure movability (see docs/Guide_NewWidget.md).

local Module = {
    applied = false,
}
addon.WildCardDiceModule = Module

-- ============================================================================
-- HELPERS
-- ============================================================================

local function IsEditorActive()
    return addon.EditorMode and addon.EditorMode.IsActive and addon.EditorMode:IsActive()
end

local function IsModuleEnabled()
    -- Widget-only: always enabled (no module toggle). Guard kept for parity.
    return true
end

local function GetBlizzFrame()
    return _G["WildCardDice"]
end

-- ============================================================================
-- DEFAULTS (mirrored in database.lua widgets.wildcarddice)
-- ============================================================================

local DEFAULT_ANCHOR = "TOP"
local DEFAULT_X = 0
local DEFAULT_Y = -32
local FRAME_W = 256
local FRAME_H = 128

-- ============================================================================
-- STATE
-- ============================================================================

local anchor
local deferredUpdate = false
local original_SetPoint
local movingWidget = false
local wasVisibleForTest = false

-- ============================================================================
-- POSITION FUNCTIONS (idempotent)
-- ============================================================================

local function ApplyAnchorPosition()
    if not anchor then return end
    if InCombatLockdown() then
        deferredUpdate = true
        return
    end

    local cfg = addon.db and addon.db.profile and addon.db.profile.widgets
        and addon.db.profile.widgets.wildcarddice
    if not cfg then return end

    anchor:ClearAllPoints()
    anchor:SetPoint(cfg.anchor or DEFAULT_ANCHOR, UIParent,
        cfg.anchor or DEFAULT_ANCHOR,
        cfg.posX or DEFAULT_X, cfg.posY or DEFAULT_Y)
end

local function ApplyFramePosition()
    if InCombatLockdown() then
        deferredUpdate = true
        return
    end

    local blizz = GetBlizzFrame()
    if not blizz or not anchor then return end

    movingWidget = true
    blizz:ClearAllPoints()
    blizz:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    movingWidget = false
end

-- ============================================================================
-- APPLY / RESTORE (idempotent)
-- ============================================================================

function addon.ApplyWildCardDiceSystem()
    if Module.applied then return end
    local blizz = GetBlizzFrame()
    if not blizz then return end

    Module.applied = true

    -- Create anchor (CreateUIFrame inherits editor nineslice + drag handling)
    anchor = addon.CreateUIFrame(FRAME_W, FRAME_H, "WildCardDice")

    -- Hook SetPoint: always redirect to our anchor when custom_position is set,
    -- even outside editor mode (Ascension re-sets position on each draft show)
    original_SetPoint = blizz.SetPoint
    blizz.SetPoint = function(self, ...)
        if movingWidget then
            return original_SetPoint(self, ...)
        end

        local cfg = addon.db and addon.db.profile and addon.db.profile.widgets
            and addon.db.profile.widgets.wildcarddice

        if cfg and cfg.custom_position and anchor then
            ApplyFramePosition()
            return
        end

        if IsEditorActive() then return end
        return original_SetPoint(self, ...)
    end

    -- Register editable frame (registration first — textures are cosmetic, here none)
    addon:RegisterEditableFrame({
        name = "wildcarddice",
        frame = anchor,
        blizzardFrame = blizz,
        configPath = { "widgets", "wildcarddice" },
        editorVisible = function() return true end,
        showTest = function()
            -- Force the Ascension frame visible so the user can see what they move
            anchor:Show()
            local blizz = GetBlizzFrame()
            if blizz then
                wasVisibleForTest = blizz:IsShown()
                blizz:Show()
                ApplyFramePosition()
            end
        end,
        onHide = function()
            local w = addon.db.profile.widgets.wildcarddice
            if w then
                local isDefault = w.anchor == DEFAULT_ANCHOR
                    and math.abs((w.posX or 0) - DEFAULT_X) <= 5
                    and math.abs((w.posY or 0) - DEFAULT_Y) <= 5
                w.custom_position = not isDefault
            end
            -- Restore original visibility after editor closes
            local blizz = GetBlizzFrame()
            if blizz and not wasVisibleForTest then
                blizz:Hide()
            end
            wasVisibleForTest = false
            ApplyAnchorPosition()
            ApplyFramePosition()
        end,
        module = Module,
    })

    -- Combat regen handler: apply deferred position changes after combat
    local f = CreateFrame("Frame")
    f:RegisterEvent("PLAYER_REGEN_ENABLED")
    f:SetScript("OnEvent", function(self, event)
        if deferredUpdate then
            deferredUpdate = false
            ApplyAnchorPosition()
            ApplyFramePosition()
        end
    end)

    -- Initial positioning
    ApplyAnchorPosition()
    ApplyFramePosition()
end

function addon.RestoreWildCardDiceSystem()
    if not Module.applied then return end

    Module.applied = false

    if anchor then anchor:Hide() end

    local blizz = GetBlizzFrame()
    if blizz then
        -- Restore original SetPoint
        if original_SetPoint then
            blizz.SetPoint = original_SetPoint
            original_SetPoint = nil
        end

        -- Return to the Ascension default position
        if not InCombatLockdown() then
            blizz:ClearAllPoints()
            blizz:SetPoint(DEFAULT_ANCHOR, UIParent, DEFAULT_ANCHOR, DEFAULT_X, DEFAULT_Y)
        end
    end
end

-- ============================================================================
-- SELF-INITIALIZATION (event-driven pattern, see Guia_NewModules.md)
-- ============================================================================

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "DragonUI" then
        addon:After(0.5, function()
            if addon.db and addon.db.RegisterCallback then
                addon.db.RegisterCallback(addon, "OnProfileChanged", function()
                    if IsModuleEnabled() then
                        addon.ApplyWildCardDiceSystem()
                    else
                        addon.RestoreWildCardDiceSystem()
                    end
                end)
            end
        end)

    elseif event == "PLAYER_ENTERING_WORLD" then
        if not IsModuleEnabled() then return end
        -- Ascension frame may not exist on first PEW; retry once shortly after
        addon.ApplyWildCardDiceSystem()
        addon:After(1.0, function()
            if not addon.WildCardDiceModule.applied then
                addon.ApplyWildCardDiceSystem()
            end
        end)
    end
end)
