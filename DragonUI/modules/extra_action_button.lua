local addon = select(2, ...)
local L = addon.L

-- ============================================================================
-- Extra Action Button movability widget
-- ============================================================================
-- Ascension/Blizzard creates `ExtraActionBarFrame` which holds the quest/zone
-- extra action button (ExtraActionButton1). This widget lets the user
-- reposition it via DragonUI Editor Mode and persists the position per profile
-- in `addon.db.profile.widgets.extraActionButton`.
--
-- UIParent manages this frame natively (UIParent_ManagedFramePositions), so
-- we set `ignoreFramePositionManager = true` when custom_position is active.
-- No styling, no module toggle: pure movability (see docs/Guide_NewWidget.md).

local Module = {
    applied = false,
}
addon.ExtraActionButtonModule = Module

-- ============================================================================
-- HELPERS
-- ============================================================================

local function IsEditorActive()
    return addon.EditorMode and addon.EditorMode.IsActive and addon.EditorMode:IsActive()
end

local function IsModuleEnabled()
    return true
end

local function GetBlizzFrame()
    return _G.ExtraActionBarFrame or _G.ExtraActionBar
end

-- ============================================================================
-- DEFAULTS (mirrored in database.lua widgets.extraActionButton)
-- ============================================================================

local DEFAULT_ANCHOR = "CENTER"
local DEFAULT_X = 0
local DEFAULT_Y = 0
local FRAME_W = 120
local FRAME_H = 120

-- ============================================================================
-- STATE
-- ============================================================================

local anchor
local deferredUpdate = false
local original_SetPoint
local movingWidget = false

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
        and addon.db.profile.widgets.extraActionButton
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

    -- UIParent manages this frame; override when custom_position is active
    local frameName = blizz:GetName()
    if UIPARENT_MANAGED_FRAME_POSITIONS and frameName
        and UIPARENT_MANAGED_FRAME_POSITIONS[frameName] then
        blizz.ignoreFramePositionManager = true
    end

    if blizz.SetUserPlaced and (blizz:IsMovable() or blizz:IsResizable()) then
        blizz:SetUserPlaced(nil)
    end

    movingWidget = true
    blizz:ClearAllPoints()
    blizz:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    movingWidget = false
end

-- ============================================================================
-- APPLY / RESTORE (idempotent)
-- ============================================================================

function addon.ApplyExtraActionButtonSystem()
    if Module.applied then return end
    local blizz = GetBlizzFrame()
    if not blizz then return end

    Module.applied = true

    -- Attempt to read real frame size; fall back to sensible defaults
    local w = blizz:GetWidth() or FRAME_W
    local h = blizz:GetHeight() or FRAME_H
    if not w or w < 10 then w = FRAME_W end
    if not h or h < 10 then h = FRAME_H end

    anchor = addon.CreateUIFrame(w, h, "ExtraActionButton")

    -- Hook SetPoint: redirect to our anchor when custom_position is set
    original_SetPoint = blizz.SetPoint
    blizz.SetPoint = function(self, ...)
        if movingWidget then
            return original_SetPoint(self, ...)
        end

        local cfg = addon.db and addon.db.profile and addon.db.profile.widgets
            and addon.db.profile.widgets.extraActionButton

        if cfg and cfg.custom_position and anchor then
            ApplyFramePosition()
            return
        end

        if IsEditorActive() then return end
        return original_SetPoint(self, ...)
    end

    -- Register editable frame (registration first)
    addon:RegisterEditableFrame({
        name = "extraActionButton",
        frame = anchor,
        blizzardFrame = blizz,
        configPath = { "widgets", "extraActionButton" },
        editorVisible = function() return true end,
        showTest = function()
            anchor:Show()
            local blizz = GetBlizzFrame()
            if blizz then
                if blizz:IsShown() and blizz:GetCenter() then
                    -- Frame is active: snap onto it
                    anchor:ClearAllPoints()
                    anchor:SetPoint("CENTER", blizz, "CENTER", 0, 0)
                else
                    -- Frame inactive: show at configured position
                    ApplyAnchorPosition()
                end
            end
        end,
        onHide = function()
            local w = addon.db.profile.widgets.extraActionButton
            if w then
                local isDefault = w.anchor == DEFAULT_ANCHOR
                    and math.abs((w.posX or 0) - DEFAULT_X) <= 5
                    and math.abs((w.posY or 0) - DEFAULT_Y) <= 5
                w.custom_position = not isDefault
            end
            ApplyAnchorPosition()
            ApplyFramePosition()
        end,
        module = Module,
    })

    -- Combat deferred: use addon.CombatQueue (already registered in core/api.lua)
    if addon.CombatQueue then
        addon.CombatQueue:Add("extraActionButton_position", function()
            ApplyAnchorPosition()
            ApplyFramePosition()
        end)
    end

    -- Hook UIParent_ManageFramePositions to re-apply our position
    if UIParent_ManageFramePositions then
        hooksecurefunc("UIParent_ManageFramePositions", function()
            ApplyFramePosition()
        end)
    end

    -- Re-apply when the frame appears (ExtraActionBar shows/hides dynamically)
    if blizz.HookScript then
        blizz:HookScript("OnShow", function()
            ApplyFramePosition()
        end)
    end

    -- Initial positioning
    ApplyAnchorPosition()
    ApplyFramePosition()
end

function addon.RestoreExtraActionButtonSystem()
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

        -- Return to the Blizzard default position (UIParent-managed center)
        if not InCombatLockdown() then
            blizz.ignoreFramePositionManager = nil
            blizz:ClearAllPoints()
            blizz:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        end
    end
end

-- Non-idempotent refresh: re-applies positions without re-creating the system.
-- Called by position presets after loading a preset.
function addon.RefreshExtraActionButtonPosition()
    if not Module.applied then return end
    ApplyAnchorPosition()
    ApplyFramePosition()
end

-- ============================================================================
-- SELF-INITIALIZATION (event-driven pattern, see Guide_NewWidget.md)
-- ============================================================================

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "DragonUI" then
        if not IsModuleEnabled() then return end

        addon:After(0.5, function()
            if addon.db and addon.db.RegisterCallback then
                addon.db.RegisterCallback(addon, "OnProfileChanged", function()
                    if IsModuleEnabled() then
                        addon.ApplyExtraActionButtonSystem()
                    else
                        addon.RestoreExtraActionButtonSystem()
                    end
                end)
            end
        end)

    elseif event == "PLAYER_ENTERING_WORLD" then
        if not IsModuleEnabled() then return end
        addon.ApplyExtraActionButtonSystem()
    end
end)
