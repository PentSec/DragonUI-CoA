--[[
================================================================================
DragonUI Options Panel - Attackbar Tab
================================================================================
Swing timer configuration: main hand, off hand, ranged, enemy target,
display options (timer, info, border style, scale).
================================================================================
]]

local addon = DragonUI
if not addon then return end

local L = addon.L
local LO = addon.LO
local C = addon.PanelControls
local Panel = addon.OptionsPanel

-- ============================================================================
-- HELPERS
-- ============================================================================

local function EnsureModuleTable(moduleName)
    return C:EnsureModuleTable(moduleName)
end

local function GetModuleField(moduleName, field)
    local m = addon.db.profile.modules
    return m and m[moduleName] and m[moduleName][field]
end

local function IsEnabled(moduleName)
    return GetModuleField(moduleName, "enabled") == true
end

-- ============================================================================
-- TAB BUILDER
-- ============================================================================

local function BuildAttackbarTab(scroll)
    C:AddLabel(scroll, "|cffFFD700" .. LO["Attack Bar"] .. "|r", { color = C.Theme.textGold })
    C:AddDescription(scroll, LO["Shows swing timers for your main hand, off hand, ranged attacks, and enemy target melee swings."])
    C:AddSpacer(scroll)

    -- ====================================================================
    -- MAIN TOGGLE
    -- ====================================================================
    local mainSection = C:AddSection(scroll, LO["Attack Bar"])

    C:AddToggle(mainSection, {
        label = LO["Enable Attack Bar"],
        desc = LO["Show swing timer bars for melee and ranged attacks."],
        getFunc = function() return IsEnabled("attackbar") end,
        setFunc = function(val)
            EnsureModuleTable("attackbar").enabled = val
            if val then
                if addon.ApplyAttackbarSystem then addon.ApplyAttackbarSystem() end
            else
                if addon.RestoreAttackbarSystem then addon.RestoreAttackbarSystem() end
            end
            Panel:SelectTab("attackbar")
        end,
        requiresReload = false,
    })

    -- ====================================================================
    -- BAR VISIBILITY TOGGLES
    -- ====================================================================
    C:AddSpacer(scroll)
    local visSection = C:AddSection(scroll, LO["Bar Visibility"])

    C:AddToggle(visSection, {
        label = LO["Main Hand Bar"],
        desc = LO["Show the main hand melee swing timer."],
        getFunc = function() return GetModuleField("attackbar", "showMainHand") ~= false end,
        setFunc = function(val) EnsureModuleTable("attackbar").showMainHand = val end,
        disabled = function() return not IsEnabled("attackbar") end,
        requiresReload = false,
    })

    C:AddToggle(visSection, {
        label = LO["Off Hand Bar"],
        desc = LO["Show the off hand melee swing timer (dual-wield)."],
        getFunc = function() return GetModuleField("attackbar", "showOffHand") ~= false end,
        setFunc = function(val) EnsureModuleTable("attackbar").showOffHand = val end,
        disabled = function() return not IsEnabled("attackbar") end,
        requiresReload = false,
    })

    C:AddToggle(visSection, {
        label = LO["Ranged Bar"],
        desc = LO["Show the ranged attack timer (Hunter shots, Throw, Aimed Shot)."],
        getFunc = function() return GetModuleField("attackbar", "showRanged") ~= false end,
        setFunc = function(val) EnsureModuleTable("attackbar").showRanged = val end,
        disabled = function() return not IsEnabled("attackbar") end,
        requiresReload = false,
    })

    C:AddToggle(visSection, {
        label = LO["Enemy Bar"],
        desc = LO["Show the enemy target melee swing timer."],
        getFunc = function() return GetModuleField("attackbar", "showEnemy") ~= false end,
        setFunc = function(val) EnsureModuleTable("attackbar").showEnemy = val end,
        disabled = function() return not IsEnabled("attackbar") end,
        requiresReload = false,
    })

    -- ====================================================================
    -- DISPLAY OPTIONS
    -- ====================================================================
    C:AddSpacer(scroll)
    local dispSection = C:AddSection(scroll, LO["Display"])

    C:AddToggle(dispSection, {
        label = LO["Show Timer"],
        desc = LO["Show the countdown timer text on bars."],
        getFunc = function() return GetModuleField("attackbar", "showTimer") ~= false end,
        setFunc = function(val) EnsureModuleTable("attackbar").showTimer = val end,
        disabled = function() return not IsEnabled("attackbar") end,
    })

    C:AddToggle(dispSection, {
        label = LO["Show Info"],
        desc = LO["Show spell name, damage range, and time remaining text."],
        getFunc = function() return GetModuleField("attackbar", "showInfo") ~= false end,
        setFunc = function(val) EnsureModuleTable("attackbar").showInfo = val end,
        disabled = function() return not IsEnabled("attackbar") end,
    })

    C:AddDropdown(dispSection, {
        label = LO["Border Style"],
        desc = LO["Choose the border style for the swing timer bars."],
        values = {
            standard = LO["Standard"],
            thin = LO["Thin"],
            none = LO["None"],
        },
        getFunc = function()
            return GetModuleField("attackbar", "borderStyle") or "standard"
        end,
        setFunc = function(val)
            EnsureModuleTable("attackbar").borderStyle = val
            if addon.RefreshAttackbarSystem then addon.RefreshAttackbarSystem() end
        end,
        disabled = function() return not IsEnabled("attackbar") end,
        width = 200,
    })

    C:AddSlider(dispSection, {
        label = LO["Scale"],
        desc = LO["Scale of the swing timer bars."],
        getFunc = function()
            return GetModuleField("attackbar", "scale") or 1.0
        end,
        setFunc = function(val)
            EnsureModuleTable("attackbar").scale = val
            if addon.RefreshAttackbarSystem then addon.RefreshAttackbarSystem() end
        end,
        min = 0.5, max = 2.0, step = 0.05,
        width = 200,
        disabled = function() return not IsEnabled("attackbar") end,
    })
end

-- Register the tab (order 12 = after Enhancements, before BNet Toast)
Panel:RegisterTab("attackbar", LO["Attack Bar"], BuildAttackbarTab, 12)
