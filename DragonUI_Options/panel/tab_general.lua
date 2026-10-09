-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

--[[
================================================================================
DragonUI Options Panel - General Tab
================================================================================
Editor Mode, KeyBind Mode, and general settings.
================================================================================
]]

local addon = DragonUI
if not addon then return end

local C = addon.PanelControls
local Panel = addon.OptionsPanel
local LO = addon.LO

-- ============================================================================
-- GENERAL TAB BUILDER
-- ============================================================================

local function BuildGeneralTab(scroll)
    -- ====================================================================
    -- ABOUT
    -- ====================================================================
    local about = C:AddSection(scroll, LO["About"])

    C:AddLabel(about, "|cff" .. C.Theme.accentHex .. LO["DragonUI"] .. " v" .. (addon.RELEASE_VERSION or "?") .. "|r")
    C:AddDescription(about, LO["Bringing the retail WoW look to 3.3.5a, inspired by Dragonflight UI."])
    C:AddSpacer(about)
    C:AddDescription(about, LO["This Fork is maintained by PentSec for Conquest of Azeroth, based on the original work by NeticSoul."])
    C:AddSpacer(about)
    C:AddDescription(about, LO["Created and maintained by NeticSoul, with community contributions."])
    C:AddSpacer(about)
    C:AddDescription(about, LO["Use the tabs on the left to configure modules, action bars, unit frames, minimap, and more."])
    C:AddSpacer(about)
    C:AddDescription(about, LO["Commands: /dragonui, /dui, /pi — /dragonui edit (editor) — /dragonui help"])
    C:AddSpacer(about)
    C:AddDescription(about, LO["Help me on GitHub (select and Ctrl+C to copy):"])
    C:AddCopyableText(about, "https://github.com/PentSec/DragonUI-CoA")

    C:AddSpacer(scroll)

    -- ====================================================================
    -- LANGUAGE
    -- ====================================================================
    local language = C:AddSection(scroll, LO["Language"])

    C:AddDescription(language, LO["Choose the language used by the DragonUI interface."])

    local localeNames = {
        enUS = "English",
        esES = "Spanish",
        esMX = "Spanish (Mexico)",
        ptBR = "Portuguese (Brazil)",
        deDE = "German",
        frFR = "French",
        ruRU = "Russian",
        zhCN = "Chinese (Simplified)",
        zhTW = "Chinese (Traditional)",
        koKR = "Korean",
    }

    local localeValues = { auto = LO["Follow the client language"] }
    for code, name in pairs(localeNames) do
        localeValues[code] = name
    end

    C:AddDropdown(language, {
        label = LO["Language"],
        desc  = LO["Choose the language used by the DragonUI interface."],
        values = localeValues,
        getFunc = function()
            return (addon.db and addon.db.global and addon.db.global.locale) or "auto"
        end,
        setFunc = function(value)
            if addon.db and addon.db.global then
                addon.db.global.locale = value
            end
        end,
        callback = function()
            StaticPopup_Show("DRAGONUI_RELOAD_UI")
        end,
        width = 200,
    })

    C:AddSpacer(scroll)

    -- ====================================================================
    -- QUICK ACCESS
    -- ====================================================================
    local actions = C:AddSection(scroll, LO["Quick Actions"])

    C:AddDescription(actions, LO["Jump to popular settings sections."])

    C:AddButton(actions, {
        label = LO["Dark Mode"],
        desc = LO["Configure dark tinting for all UI chrome."],
        width = 200,
        callback = function() Panel:SelectTab("enhancements", { label = LO["Enable Dark Mode"] }) end,
    })

    C:AddButton(actions, {
        label = LO["Fat Health Bar"],
        desc = LO["Full-width health bar that fills the entire player frame."],
        width = 200,
        callback = function()
            Panel:SelectTab("unitframes", { subTab = "player", dbPath = "unitframe.player.fat_healthbar" })
        end,
    })

    C:AddButton(actions, {
        label = LO["Dragon Decoration"],
        desc = LO["Add a decorative dragon to your player frame."],
        width = 200,
        callback = function()
            Panel:SelectTab("unitframes", { subTab = "player", dbPath = "unitframe.player.dragon_decoration" })
        end,
    })

    C:AddButton(actions, {
        label = LO["Unit Frame Layers"],
        desc = LO["Heal prediction, absorb shields and animated health loss."],
        width = 200,
        callback = function() Panel:SelectTab("enhancements", { label = LO["Enable Unit Frame Layers"] }) end,
    })

    C:AddButton(actions, {
        label = LO["Action Bar Layout"],
        desc = LO["Change columns, rows, and buttons shown per action bar."],
        width = 200,
        callback = function()
            Panel:SelectTab("actionbars", { subTab = "layout", dbPath = "mainbars.player.columns" })
        end,
    })

    C:AddButton(actions, {
        label = LO["Grayscale Icons"],
        desc = LO["Switch micro menu icons between colored and grayscale style."],
        width = 200,
        callback = function() Panel:SelectTab("micromenu", { dbPath = "micromenu.grayscale_icons" }) end,
    })

    C:AddSpacer(scroll)

    -- ====================================================================
    -- LAYOUT PRESETS
    -- ====================================================================
    local presets = C:AddSection(scroll, LO["Layout Presets"])

    C:AddDescription(presets, LO["Save and restore complete UI layouts. Each preset captures all positions, scales, and settings."])

    C:AddSpacer(presets)

    -- Collect sorted preset names
    local presetData = GetPresets()
    local presetNames = {}
    for name in pairs(presetData) do
        presetNames[#presetNames + 1] = name
    end
    table.sort(presetNames)

    if #presetNames == 0 then
        C:AddLabel(presets, "|cff888888" .. LO["No presets saved yet."] .. "|r")
        C:AddSpacer(presets)
    else
        -- Preset list: clickable labels that trigger load on click
        for _, name in ipairs(presetNames) do
            local entry = presetData[name]
            local dateStr = entry.date or ""

            local row = AceGUI:Create("SimpleGroup")
            row:SetFullWidth(true)
            row:SetLayout("Flow")
            presets:AddChild(row)

            local btn = AceGUI:Create("InteractiveLabel")
            btn:SetWidth(350)
            btn:SetText("  |cffFFFFFF" .. name .. "|r  |cff666666" .. dateStr .. "|r")
            if btn.label then
                btn.label:SetFont(C.Theme.font, 12, "")
            end

            -- Hover highlight frame (visual feedback only)
            local hlFrame = CreateFrame("Frame", nil, btn.frame)
            hlFrame:SetAllPoints(btn.frame)
            hlFrame:SetFrameLevel(btn.frame:GetFrameLevel())
            local hlTex = hlFrame:CreateTexture(nil, "BACKGROUND")
            hlTex:SetAllPoints()
            hlTex:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
            local accent = C.Theme.accent
            hlTex:SetVertexColor(accent[1], accent[2], accent[3], 0)

            btn:SetCallback("OnClick", function()
                local dialog = StaticPopup_Show("DRAGONUI_PRESET_LOAD", name)
                if dialog then dialog.data = name end
            end)
            btn:SetCallback("OnEnter", function()
                hlTex:SetVertexColor(accent[1], accent[2], accent[3], 0.12)
            end)
            btn:SetCallback("OnLeave", function()
                hlTex:SetVertexColor(accent[1], accent[2], accent[3], 0)
            end)

            row:AddChild(btn)
        end

        C:AddSpacer(presets)
    end

    -- Action buttons row
    local btnRow = C:AddRow(presets)

    -- SAVE NEW
    C:AddButton(btnRow, {
        label = LO["Save New Preset"],
        width = 140,
        desc = LO["Save your current UI layout as a new preset."],
        callback = function()
            local defaultName = UniquePresetName(LO["Preset"] or "Preset")
            local dialog = StaticPopup_Show("DRAGONUI_PRESET_NAME")
            if dialog then dialog.data = defaultName end
        end,
    })

    -- LOAD (enabled only when a preset can be selected)
    if #presetNames > 0 then
        -- Build dropdown values
        local ddValues = {}
        for _, name in ipairs(presetNames) do
            ddValues[name] = name
        end

        C:AddDropdown(btnRow, {
            label = LO["Load Preset"],
            values = ddValues,
            width = 180,
            setFunc = function(value)
                if value then
                    local dialog = StaticPopup_Show("DRAGONUI_PRESET_LOAD", value)
                    if dialog then dialog.data = value end
                end
            end,
        })

        C:AddDropdown(btnRow, {
            label = LO["Delete Preset"],
            values = ddValues,
            width = 180,
            setFunc = function(value)
                if value then
                    local dialog = StaticPopup_Show("DRAGONUI_PRESET_DELETE", value)
                    if dialog then dialog.data = value end
                end
            end,
        })

        C:AddDropdown(btnRow, {
            label = LO["Duplicate Preset"],
            values = ddValues,
            width = 180,
            setFunc = function(value)
                if value and presetData[value] then
                    local newName = UniquePresetName(value)
                    presetData[newName] = {
                        data = addon.DeepCopy(presetData[value].data),
                        date = date("%Y-%m-%d %H:%M"),
                    }
                    addon:Print((LO["Preset duplicated: "] or "Preset duplicated: ") .. newName)
                    Panel:SelectTab("general")
                end
            end,
        })

        C:AddDropdown(btnRow, {
            label = LO["Export Preset"],
            values = ddValues,
            width = 180,
            setFunc = function(value)
                if value and presetData[value] then
                    local exportStr = ExportPresetToString(presetData[value])
                    if exportStr then
                        ShowExportFrame(value, exportStr)
                    else
                        addon:Error(LO["Failed to export preset."] or "Failed to export preset.")
                    end
                end
            end,
        })
    end

    -- Import button (always available, even with no presets)
    C:AddButton(btnRow, {
        label = LO["Import Preset"],
        width = 140,
        desc = LO["Import a preset from a text string shared by another player."],
        callback = function()
            ShowImportFrame()
        end,
    })

    C:AddSpacer(scroll)

    -- ====================================================================
    -- SETTINGS WINDOW
    -- ====================================================================
    local window = C:AddSection(scroll, LO["Settings Window"])

    C:AddSlider(window, {
        label = LO["Scale"],
        desc = LO["Size of this window on top of your UI scale; 1.0 matches the other panels. It never grows past the screen."],
        min = 0.75,
        max = 2,
        step = 0.05,
        width = 200,
        getFunc = function() return Panel:GetScale() end,
        setFunc = function(val) Panel:SetScale(val) end,
    })
end

-- Register the tab
Panel:RegisterTab("general", LO["General"], BuildGeneralTab, 1)
