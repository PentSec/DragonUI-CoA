-- =============================================================================
-- Level Up Enhance Module
-- Enhanced level-up notification with animated frame.
-- =============================================================================

local addon = select(2, ...)
local L = addon.L

<<<<<<< HEAD
=======
local LEVEL_FRAME = addon._dir .. "NewLevelUp\\levelup"
local LEVEL_FONT = addon.Fonts.PRIMARY

-- Only rows 67-188 of the 512x256 sheet carry art; the rest is transparent padding.
local ART_TOP, ART_BOTTOM = 67 / 256, 189 / 256
local WIDTH = 400
local HEIGHT = WIDTH * (189 - 67) / 512

local HOLD_TIME, FADE_TIME = 4.5, 1.5

>>>>>>> 8f804be (fix(modules): make #468's Low HP Alert and Level Up Enhance production-ready)
local LevelUpEnhance = {
    initialized = false,
    applied = false,
}

if addon.RegisterModule then
    addon:RegisterModule("levelupenhance", LevelUpEnhance,
        L["Level Up Enhance"],
        L["Enhanced level-up notification with animated frame"],
        { lifecyclePrefix = "LevelUpEnhance" })
end

local anchor, banner

local function IsEditorActive()
    return addon.EditorMode and addon.EditorMode:IsActive()
end

-- =============================================================================
-- POSITION
-- =============================================================================

local function ApplyWidgetPosition()
<<<<<<< HEAD
    if InCombatLockdown() then return end
    if addon.EditorMode and addon.EditorMode:IsActive() then return end

    local cfg = addon.db.profile.widgets.levelupenhance
    if not cfg then return end

    anchor:ClearAllPoints()
    anchor:SetPoint(cfg.anchor or DEFAULT_ANCHOR, UIParent,
        cfg.anchor or DEFAULT_ANCHOR, cfg.posX or DEFAULT_X, cfg.posY or DEFAULT_Y)

    if newLevelFrame then
        newLevelFrame:ClearAllPoints()
        newLevelFrame:SetPoint("TOP", anchor, "TOP", 0, 0)
    end
=======
    if IsEditorActive() then return end

    local widgets = addon.db.profile.widgets
    local cfg = widgets and widgets.levelupenhance or addon.defaults.profile.widgets.levelupenhance

    anchor:ClearAllPoints()
    anchor:SetPoint(cfg.anchor, UIParent, cfg.anchor, cfg.posX, cfg.posY)
>>>>>>> 8f804be (fix(modules): make #468's Low HP Alert and Level Up Enhance production-ready)
end

-- =============================================================================
-- BANNER
-- =============================================================================

<<<<<<< HEAD
local function ShowNewLevelFrame(level)
    if not newLevelFrame or not newLevelFrame.footer then return end
    newLevelFrame.footer:SetText(string.format(L and L["Level %d"] or "Level %d", level))
    newLevelFrame:ClearAllPoints()
    newLevelFrame:SetPoint("TOP", UIParent, "TOP", 0, -128)
    newLevelFrame:SetFrameStrata("HIGH")
    newLevelFrame:SetAlpha(1)
    newLevelFrame:Show()
    newLevelFrame.timeShown = 0
    local fadeInfo = { mode = "IN", fadeFunc = function() end, timeToFade = 1.5, startAlpha = 1, endAlpha = 1 }
    UIFrameFade(newLevelFrame, fadeInfo)
    local updateFrame = CreateFrame("Frame")
    updateFrame:SetScript("OnUpdate", function(self, elapsed)
        newLevelFrame.timeShown = newLevelFrame.timeShown + elapsed
        if newLevelFrame.timeShown >= 4.5 then
            UIFrameFadeOut(newLevelFrame, 1.5, 1, 0)
            self:SetScript("OnUpdate", nil)
        end
=======
local function ShowBanner(level)
    banner.footer:SetText(string.format(L["Level %d"], level))
    banner.fade:Stop()
    banner:Show()
    banner.fade:Play()
end

local function CreateBanner()
    anchor = addon.CreateUIFrame(WIDTH, HEIGHT, "LevelUpFrame")

    banner = CreateFrame("Frame", nil, UIParent)
    banner:SetFrameStrata("HIGH")
    banner:SetAllPoints(anchor)
    banner:Hide()

    local art = banner:CreateTexture(nil, "BACKGROUND")
    art:SetTexture(LEVEL_FRAME)
    art:SetTexCoord(0, 1, ART_TOP, ART_BOTTOM)
    art:SetAllPoints()

    banner.header = banner:CreateFontString(nil, "ARTWORK")
    banner.header:SetFont(LEVEL_FONT, 18)
    banner.header:SetPoint("CENTER", 0, 20)
    banner.header:SetText(L["You've Reached"])

    banner.footer = banner:CreateFontString(nil, "ARTWORK")
    banner.footer:SetFont(LEVEL_FONT, 30)
    banner.footer:SetPoint("CENTER", 0, -20)
    banner.footer:SetTextColor(207 / 255, 191 / 255, 20 / 255, 1)

    banner.fade = banner:CreateAnimationGroup()
    local fadeOut = banner.fade:CreateAnimation("Alpha")
    fadeOut:SetStartDelay(HOLD_TIME)
    fadeOut:SetDuration(FADE_TIME)
    fadeOut:SetChange(-1)
    banner.fade:SetScript("OnFinished", function()
        banner:Hide()
>>>>>>> 8f804be (fix(modules): make #468's Low HP Alert and Level Up Enhance production-ready)
    end)

    addon:RegisterEditableFrame({
        name = "levelupenhance",
        frame = anchor,
        blizzardFrame = banner,
        configPath = {"widgets", "levelupenhance"},
        editorVisible = function()
            return addon:IsModuleEnabled("levelupenhance")
        end,
        showTest = function()
            banner.fade:Stop()
            banner.footer:SetText(string.format(L["Level %d"], UnitLevel("player") + 1))
            anchor:Show()
            banner:Show()
        end,
        hideTest = function()
            banner.fade:Stop()
            banner:Hide()
        end,
        onHide = ApplyWidgetPosition,
        module = LevelUpEnhance,
    })
end

local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(_, _, level)
    if IsEditorActive() then return end
    ShowBanner(level)
end)

-- =============================================================================
-- LIFECYCLE
-- =============================================================================

function addon.ApplyLevelUpEnhanceSystem()
<<<<<<< HEAD
    if LevelUpEnhance.applied then return end

    newLevelFrame = CreateFrame("Frame", nil, UIParent)
    newLevelFrame:SetFrameStrata("MEDIUM")
    newLevelFrame:SetWidth(400)
    newLevelFrame:SetHeight(200)

    local texture = newLevelFrame:CreateTexture(nil, "BACKGROUND")
    texture:SetTexture("Interface\\AddOns\\DragonUI\\Textures\\newlevel_frame")
    texture:SetAllPoints(newLevelFrame)

    newLevelFrame.header = newLevelFrame:CreateFontString(nil, "ARTWORK")
    newLevelFrame.header:SetFont("Fonts\\FRIZQT__.TTF", 18)
    newLevelFrame.header:SetPoint("CENTER", 0, 20)
    newLevelFrame.header:SetText(L and L["You've Reached"] or "You've Reached")

    newLevelFrame.footer = newLevelFrame:CreateFontString(nil, "ARTWORK")
    newLevelFrame.footer:SetFont("Fonts\\FRIZQT__.TTF", 30)
    newLevelFrame.footer:SetPoint("CENTER", 0, -20)
    newLevelFrame.footer:SetTextColor(207 / 255, 191 / 255, 20 / 255, 1)

    newLevelFrame:Hide()

    if not anchor then
        anchor = addon.CreateUIFrame(400, 200, "LevelUpFrame")

        addon:RegisterEditableFrame({
            name = "levelupenhance",
            frame = anchor,
            blizzardFrame = newLevelFrame,
            configPath = {"widgets", "levelupenhance"},
            editorVisible = function()
                return IsModuleEnabled()
            end,
            showTest = function()
                anchor:Show()
                newLevelFrame.footer:SetText(L and L["Level %d"] or "Level %d", UnitLevel("player") + 1)
                newLevelFrame:Show()
                newLevelFrame:SetAlpha(1)
            end,
            hideTest = function()
                newLevelFrame:Hide()
            end,
            onHide = function()
                newLevelFrame:Hide()
                ApplyWidgetPosition()
            end,
            module = LevelUpEnhance,
        })
=======
    if not banner then
        CreateBanner()
>>>>>>> 8f804be (fix(modules): make #468's Low HP Alert and Level Up Enhance production-ready)
    end

    ApplyWidgetPosition()
    eventFrame:RegisterEvent("PLAYER_LEVEL_UP")

    LevelUpEnhance.initialized = true
    LevelUpEnhance.applied = true
end

function addon.RestoreLevelUpEnhanceSystem()
    eventFrame:UnregisterEvent("PLAYER_LEVEL_UP")

    if banner then
        banner.fade:Stop()
        banner:Hide()
    end

    LevelUpEnhance.applied = false
end

function addon.RefreshLevelUpEnhanceSystem()
    if addon:IsModuleEnabled("levelupenhance") then
        addon.ApplyLevelUpEnhanceSystem()
    else
        addon.RestoreLevelUpEnhanceSystem()
    end
end

-- =============================================================================
-- TEST COMMAND
-- =============================================================================

SLASH_DRAGONUI_TESTLEVEL1 = "/testlevel"
SlashCmdList["DRAGONUI_TESTLEVEL"] = function(msg)
    if not LevelUpEnhance.applied then
        addon:Print(L["Module disabled."])
        return
    end
    ShowBanner(tonumber(msg) or UnitLevel("player") + 1)
end
