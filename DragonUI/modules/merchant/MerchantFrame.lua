<<<<<<< HEAD
-- DragonUI/modules/merchant/MerchantFrame.lua — modern (Dragonflight) chrome on the
-- client's own vendor window.
--
-- DOWNPORT of NewEra/MerchantFrame/MerchantFrame.lua (Classic 1.15), adapted for DragonUI.
-- This is a RESKIN, not a replacement: FrameXML keeps MerchantFrame_Update /
-- _UpdateMerchantInfo / _UpdateBuybackInfo and all of the buy/sell/repair behaviour;
-- we re-dress the frame it paints on and hook the updater to keep our pieces in sync.
--
-- Key 3.3.5a differences from the 1.15 source (see NewEra PORT_NOTES.md for full details):
--   * The frame is a 384x512 classic wooden panel, not ButtonFrameTemplate
--   * MERCHANT_ITEMS_PER_PAGE is 10, not 12
--   * MerchantFrameItem_UpdateQuality does not exist
--   * SetShown does not exist — Show/Hide throughout
--   * No MerchantMoneyInset — player money floats on classic bottom art
--
-- Infrastructure: uses DragonUIWorldMapHost (vendored NewEra core libs via worldmap module)
-- for PanelChrome, NineSlice, Portrait, Tex, FrameUtil.
=======
-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.
-- Retail-style chrome on Blizzard's vendor window. FrameXML keeps buy/sell/repair;
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)

local addon = select(2, ...)
if not addon then return end

<<<<<<< HEAD
local NE = DragonUIWorldMapHost
if not NE then return end

local L = addon.L
=======
local L = addon.L
local DIR = addon._dir
local ROCK = DIR .. "UI\\ui-background-rock"
local REDBUTTON = DIR .. "UI\\redbutton2x"
local LABEL_PLATE = DIR .. "Merchant\\labelslots"
local PAGE_BG = DIR .. "Merchant\\pagebutton-background"
local PAGE_HILITE = DIR .. "Merchant\\pagebutton-hover"
local QUICKSLOT_BG = DIR .. "UI\\ui-quickslot2"
local TAB_TEX = DIR .. "UI\\uiframetabs"
local PAGE_BTN_TEX = {
    MerchantPrevPageButton = {
        up = DIR .. "Merchant\\pagebutton-prev-normal",
        down = DIR .. "Merchant\\pagebutton-prev-pressed",
        disabled = DIR .. "Merchant\\pagebutton-prev-disabled",
    },
    MerchantNextPageButton = {
        up = DIR .. "Merchant\\pagebutton-next-normal",
        down = DIR .. "Merchant\\pagebutton-next-pressed",
        disabled = DIR .. "Merchant\\pagebutton-next-disabled",
    },
}
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)

-- ============================================================================
-- MODULE REGISTRATION
-- ============================================================================

local MerchantModule = {
    initialized = false,
    applied = false,
    hooks = {},
    frames = {},
}

if addon.RegisterModule then
    addon:RegisterModule("merchant", MerchantModule,
        (L and L["Merchant"]) or "Merchant",
<<<<<<< HEAD
        (L and L["Retail-style vendor window chrome"]) or "Retail-style vendor window chrome")
=======
        (L and L["Retail-style vendor window chrome"]) or "Retail-style vendor window chrome",
        { lifecyclePrefix = "Merchant", loadOnce = true })
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
end

-- ============================================================================
-- CONFIG HELPERS
-- ============================================================================

local function GetModuleConfig()
    return addon:GetModuleConfig("merchant")
end

local function IsModuleEnabled()
    return addon:IsModuleEnabled("merchant")
end

-- ============================================================================
<<<<<<< HEAD
-- INLINE HELPERS (replaces NewEra's NE.itembtn and NE.itemgrid)
-- ============================================================================

-- Quality text color — reads ITEM_QUALITY_COLORS (the brighter table with .hex).
-- Equivalent to NE.itembtn.TextColor in NewEra.
=======
-- INLINE HELPERS
-- ============================================================================

>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
local function TextColor(quality)
    return quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] or nil
end

<<<<<<< HEAD
-- Quest-starter detection via tooltip scan (3.3.5a has no direct API).
-- Scans for ITEM_SPELL_STARTS_QUEST in the item's tooltip lines.
=======
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
local _questScanTooltip
local function ItemStartsQuestByLink(link)
    if not link then return false end
    if not _questScanTooltip then
        _questScanTooltip = CreateFrame("GameTooltip", "DragonUI_MerchantQuestScan", nil, "GameTooltipTemplate")
        _questScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end
    _questScanTooltip:ClearLines()
    _questScanTooltip:SetHyperlink(link)
    for i = 1, _questScanTooltip:NumLines() do
        local text = _G["DragonUI_MerchantQuestScanTextLeft" .. i] and _G["DragonUI_MerchantQuestScanTextLeft" .. i]:GetText()
        if text and text == ITEM_SPELL_STARTS_QUEST then
            return true
        end
    end
    return false
end

-- ============================================================================
<<<<<<< HEAD
-- LOCAL UPVALUES
-- ============================================================================

local PC = NE.panelchrome
local PCKeep = PC and PC.Keep
local PCHideClassicChrome = PC and PC.HideClassicChrome
local PCApplyModernChrome = PC and PC.ApplyModernChrome
local PCEnsureTitle = PC and PC.EnsureTitle
local PCModernizeCloseButton = PC and PC.ModernizeCloseButton
local PCSetTitle = PC and PC.SetTitle

local texSetAtlas = NE.tex and NE.tex.SetAtlas
local texLocal = NE.tex and NE.tex.Local
local texAtlasEntry = NE.tex and NE.tex._atlasEntry

local ForEachRegion = NE.FrameUtil and NE.FrameUtil.ForEachRegion
local FindRegion = NE.FrameUtil and NE.FrameUtil.FindRegion

local ninesliceAttachInset = NE.nineslice and NE.nineslice.AttachInset
local ninesliceApplyLayout = NE.nineslice and NE.nineslice.ApplyLayout

local portraitApplyCutout = NE.portrait and NE.portrait.ApplyCutout
=======
-- LOCAL HELPERS
-- ============================================================================

local function setAtlas(tex, name, useSize)
    if not tex or not name or not addon.atlasinfo or not addon.atlasinfo[name] then
        return false
    end
    tex:set_atlas(name, useSize and true or false)
    return true
end

local function ForEachRegion(frame, kind, layer, fn)
    if not (frame and frame.GetNumRegions) then return end
    local n = frame:GetNumRegions()
    for i = 1, n do
        local r = select(i, frame:GetRegions())
        if r and r.GetObjectType and r:GetObjectType() == kind then
            if not layer or (r.GetDrawLayer and r:GetDrawLayer() == layer) then
                fn(r)
            end
        end
    end
end

local function FindRegion(frame, kind, predicate)
    if not (frame and frame.GetNumRegions) then return nil end
    local n = frame:GetNumRegions()
    for i = 1, n do
        local r = select(i, frame:GetRegions())
        if r and r.GetObjectType and r:GetObjectType() == kind and predicate(r) then
            return r
        end
    end
    return nil
end

local function keep(f, obj)
    if not (f and obj) then return end
    f._duiKeep = f._duiKeep or {}
    f._duiKeep[obj] = true
end

local function applyNineSlice(container, layoutName)
    if not (container and NineSliceUtils and NineSliceUtils.GetLayout) then return false end
    local layout = NineSliceUtils.GetLayout(layoutName)
    if not layout then return false end
    NineSliceUtils.ApplyLayout(container, layout)
    return true
end

local function attachInset(parent, tlx, tly, brx, bry)
    if not parent then return nil end
    local inset = CreateFrame("Frame", nil, parent)
    inset:EnableMouse(false)
    inset:SetPoint("TOPLEFT", parent, "TOPLEFT", tlx, tly)
    inset:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", brx, bry)
    applyNineSlice(inset, "InsetFrameTemplate")
    return inset
end

local function applyPortraitCutout(tex, parent)
    if not tex or not parent or tex._duiCutout then return end
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", parent, "TOPLEFT", -5, 8)
    tex:SetSize(60, 60)
    tex:SetDrawLayer("ARTWORK")
    tex._duiCutout = true
end

local function ensureTitle(f, text)
    if not f then return nil end
    local fs = f.Title
    if not fs then
        fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.Title = fs
        fs:SetPoint("TOP", f, "TOP", 0, -5)
        fs:SetPoint("LEFT", f, "LEFT", 60, 0)
        fs:SetPoint("RIGHT", f, "RIGHT", -24, 0)
        fs:SetJustifyH("CENTER")
        fs:SetHeight(16)
    end
    if text then fs:SetText(text) end
    return fs
end

local function dressCloseButton(cb, owner)
    if not cb or cb._duiModernized then return end
    cb._duiModernized = true
    cb:SetSize(24, 24)
    cb:ClearAllPoints()
    cb:SetPoint("TOPRIGHT", owner, "TOPRIGHT", 1, 0)
    local base = (owner.GetFrameLevel and owner:GetFrameLevel()) or 0
    cb:SetFrameLevel(base + 20)

    local function dress(getter, l, r, t, b, blend)
        local tex = cb[getter] and cb[getter](cb)
        if not tex then return end
        tex:SetTexture(REDBUTTON)
        tex:SetTexCoord(l, r, t, b)
        if blend then tex:SetBlendMode(blend) end
    end

    dress("GetNormalTexture", 39/256, 75/256, 1/128, 39/128)
    dress("GetPushedTexture", 39/256, 75/256, 81/128, 119/128)
    dress("GetDisabledTexture", 39/256, 75/256, 41/128, 79/128)
    dress("GetHighlightTexture", 115/256, 151/256, 1/128, 39/128, "ADD")
end

local updateMerchantTabHighlight
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)

-- ============================================================================
-- LAYOUT CONSTANTS
-- ============================================================================

local ITEMS_PER_PAGE   = MERCHANT_ITEMS_PER_PAGE or 10
local BUYBACK_PER_PAGE = BUYBACK_ITEMS_PER_PAGE or 12
<<<<<<< HEAD

local EMPTY_SLOT_FDID  = 130766   -- UI-EmptySlot
local SLOT_RING_FDID   = 130841   -- UI-Quickslot2
local LABEL_PLATE_FDID = 136423   -- UI-Merchant-LabelSlots

local PANEL_W, PANEL_H = 368, 494
local GRID_X, GRID_Y   = 26, -76
local PANEL_X_NUDGE    = 6

local INSET_TL_X, INSET_TL_Y = 10, -59
local INSET_BR_X, INSET_BR_Y = -10, 101
local INSET_BR_Y_BUYBACK = 27
local ROW_GAP_MERCHANT, ROW_GAP_BUYBACK = -8, -22

local PAGENAV_Y  = 145
local PAGENAV_X  = 34

local BAND_Y     = 36
local BAND_INSET = 6
local BUTTON_Y   = 45
local BUTTON_GAP = 6
local TILE_BLEED = 4
local BAR_X      = 20
local BUYBACK_X  = 228
local MONEY_Y    = 9

-- ============================================================================
-- DIAGNOSTICS (optional /dragonui merchant slash command)
-- ============================================================================

local stats = { update = 0, merchantInfo = 0, buybackInfo = 0, repair = 0, tabClick = 0,
                onShow = 0, onHide = 0, evShow = 0, evClosed = 0, tab = 0, tabTrace = {} }

local function trace(what)
    local f = _G.MerchantFrame
    local t = stats.tabTrace
    t[#t + 1] = what .. "=" .. tostring(f and f.selectedTab)
    while #t > 12 do table.remove(t, 1) end
end
=======
local PANEL_W, PANEL_H = 336, 444
local GRID_X, GRID_Y   = 11, -69
local PANEL_X_NUDGE    = 6
local INSET_TL_X, INSET_TL_Y = 2, -59
local INSET_BR_X, INSET_BR_Y = -6, 26
local INSET_BR_Y_BUYBACK = 27
local ROW_GAP_MERCHANT, ROW_GAP_BUYBACK = -8, -15
local BAND_Y     = 26
local BAND_INSET = 1
local TILE_BLEED = 14
local MONEY_X, MONEY_Y = -10, 8
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)

-- ============================================================================
-- CLASSIC ART DETECTION (must be defined before diagnose and hideClassicChrome)
-- ============================================================================

local CLASSIC_PATHS = { "ui%-merchant%-top", "ui%-merchant%-bot", "ui%-buyback%-" }

local function isClassicArt(r)
    local p = r.GetTexture and r:GetTexture()
    if type(p) ~= "string" then return false end
    p = p:lower()
    for _, pat in ipairs(CLASSIC_PATHS) do
        if p:find(pat) then return true end
    end
    return false
end

<<<<<<< HEAD
local function diagnose()
    local say = function(fmt, ...)
        local msg = select("#", ...) > 0 and fmt:format(...) or fmt
        DEFAULT_CHAT_FRAME:AddMessage("|cff1784d1DragonUI Merchant|r " .. msg)
    end
    local shortPath = function(p)
        if type(p) ~= "string" then return tostring(p) end
        return p:match("([^\\/]+)$") or p
    end

    say("---- state ----")
    say("hooks fired: Update=%d MerchantInfo=%d BuybackInfo=%d Repair=%d TabClick=%d lastTab=%s",
        stats.update, stats.merchantInfo, stats.buybackInfo, stats.repair, stats.tabClick, tostring(stats.tab))
    say("window: OnShow=%d OnHide=%d evSHOW=%d evCLOSED=%d", stats.onShow, stats.onHide, stats.evShow, stats.evClosed)
    if #stats.tabTrace > 0 then
        say("trace: %s", table.concat(stats.tabTrace, "  "))
    end

    -- NE.tex diagnostics
    local NE = DragonUIWorldMapHost
    local texOk = NE and NE.tex and NE.tex.RegisterLocal
    say("NE.tex available: %s", tostring(texOk))
    if texOk then
        local rockPath = NE.tex.localFiles and NE.tex.localFiles[374155]
        say("rock (374155): %s", rockPath and shortPath(rockPath) or "|cffff4040MISSING|r")
        local merchPath = NE.tex.localFiles and NE.tex.localFiles[5222222]
        say("merchant pack (5222222): %s", merchPath and shortPath(merchPath) or "|cffff4040MISSING|r")
        -- Check atlas resolution
        local atlases = { "spellicon-256x256-repair", "spellicon-256x256-repairall",
            "spellicon-256x256-selljunk", "ui-merchant-botframe", "common-icon-undo" }
        for _, name in ipairs(atlases) do
            local entry = NE.tex._atlasEntry and NE.tex._atlasEntry(name)
            if not entry then
                say("atlas %s: |cffff4040MISSING|r", name)
            else
                local src = NE.tex.localFiles and NE.tex.localFiles[entry.file]
                say("atlas %s: %s fdid=%s", name, src and "ok" or "|cffff4040NO-LOCAL|r", tostring(entry.file))
            end
        end
    end

    -- PanelChrome diagnostics
    local pcOk = NE and NE.panelchrome and NE.panelchrome.ApplyModernChrome
    say("PanelChrome: %s", tostring(pcOk))
    local nsOk = NE and NE.nineslice and NE.nineslice.ApplyLayout
    say("NineSlice: %s", tostring(nsOk))

    local f = _G.MerchantFrame
    if f then
        say("selectedTab=%s  _neBuilt=%s  width=%.0f height=%.0f",
            tostring(f.selectedTab), tostring(f._neBuilt), f:GetWidth() or 0, f:GetHeight() or 0)
        -- f.Bg check
        local bg = f.Bg
        if bg then
            say("f.Bg: shown=%s tex=%s", tostring(bg:IsShown()), shortPath(bg:GetTexture()))
            local r, g, b = bg:GetVertexColor()
            say("  vertexcolor %.2f/%.2f/%.2f  size %.0fx%.0f", r or 0, g or 0, b or 0, bg:GetWidth() or 0, bg:GetHeight() or 0)
        else
            say("|cffff4040f.Bg: MISSING|r")
        end
        -- NineSlice check
        local ns = f.NineSlice
        if ns then
            say("NineSlice: shown=%s  level=%s", tostring(ns:IsShown()), tostring(ns:GetFrameLevel()))
        else
            say("|cffff4040f.NineSlice: MISSING|r")
        end
        -- Classic art check
        local classicCount = 0
        if ForEachRegion then
            ForEachRegion(f, "Texture", "BORDER", function(r)
                if isClassicArt(r) then classicCount = classicCount + 1 end
            end)
        end
        say("classic art on BORDER: %d remaining", classicCount)
        -- Bottom band check
        say("botFrame=%s  gridInset=%s  moneyInset=%s",
            tostring(f._neBotFrame ~= nil), tostring(f._neGridInset ~= nil), tostring(f._neMoneyInset ~= nil))
        -- Grid inset fill check
        local giBg = f._neGridInsetBg
        if giBg then
            say("gridInsetBg: shown=%s level=%s/%s tex=%s",
                tostring(giBg:IsShown()), tostring(giBg:GetDrawLayer()), tostring(giBg:GetTexture()),
                shortPath(giBg:GetTexture()))
            local r, g, b = giBg:GetVertexColor()
            say("  vertexcolor %.2f/%.2f/%.2f  w=%.0f h=%.0f", r or 0, g or 0, b or 0, giBg:GetWidth() or 0, giBg:GetHeight() or 0)
        else
            say("|cffff4040gridInsetBg: MISSING|r")
        end
        -- PanelKeep check
        local pk = f._nePanelKeep
        local pkCount = 0
        if pk then for _ in pairs(pk) do pkCount = pkCount + 1 end end
        say("panelKeep entries: %d (bg=%s giBg=%s miBg=%s)", pkCount,
            tostring(pk and pk[f.Bg]), tostring(pk and pk[f._neGridInsetBg]), tostring(pk and pk[f._neMoneyInsetBg]))
        -- Title check
        say("title=%q  nameText=%q",
            (f.Title and f.Title:GetText()) or "<none>",
            (_G.MerchantNameText and _G.MerchantNameText:GetText()) or "<none>")
    else
        say("|cffff4040MerchantFrame: MISSING|r")
    end
    say("---- end ----")
end

=======
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
-- ============================================================================
-- OUTER CHROME — classic art suppression + modern chrome
-- ============================================================================

local function hideClassicChrome()
    local f = _G.MerchantFrame
    if not f then return end

<<<<<<< HEAD
    if _G.MerchantFramePortrait and PCKeep then PCKeep(f, _G.MerchantFramePortrait) end
    if PCHideClassicChrome then PCHideClassicChrome(f) end

    -- BORDER and ARTWORK layers (PanelChrome walk only covers BACKGROUND)
    if ForEachRegion then
        ForEachRegion(f, "Texture", "BORDER", function(r)
            if r ~= f._neTopTileStreaks and isClassicArt(r) then r:Hide() end
        end)
        ForEachRegion(f, "Texture", "ARTWORK", function(r)
            if r ~= f._neTopTileStreaks and isClassicArt(r) then r:Hide() end
        end)
    end

    -- BACKGROUND walk: hide everything except f.Bg and the panel-keep list
    -- (grid inset fill, money inset fill). f._nePanelKeep is populated by PC.Keep();
    -- for safety we also hard-code the two keys so the fills survive the walk.
    local keep = (f._nePanelKeep or {})
    if f.Bg then keep[f.Bg] = true end
    if f._neGridInsetBg then keep[f._neGridInsetBg] = true end
    if f._neMoneyInsetBg then keep[f._neMoneyInsetBg] = true end
    if ForEachRegion then
        ForEachRegion(f, "Texture", "BACKGROUND", function(r)
            if not keep[r] then r:Hide() end
        end)
    end
=======
    if _G.MerchantFramePortrait then keep(f, _G.MerchantFramePortrait) end

    ForEachRegion(f, "Texture", "BORDER", function(r)
        if r ~= f._duiStreaks and isClassicArt(r) then r:Hide() end
    end)
    ForEachRegion(f, "Texture", "ARTWORK", function(r)
        if r ~= f._duiStreaks and isClassicArt(r) then r:Hide() end
    end)

    local kept = f._duiKeep or {}
    if f.Bg then kept[f.Bg] = true end
    if f._duiGridInsetBg then kept[f._duiGridInsetBg] = true end
    if f._duiMoneyInsetBg then kept[f._duiMoneyInsetBg] = true end
    ForEachRegion(f, "Texture", "BACKGROUND", function(r)
        if not kept[r] then r:Hide() end
    end)
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)

    if _G.MerchantNameText then _G.MerchantNameText:Hide() end

    for _, name in ipairs({
        "MerchantRepairText", "MerchantFrameBottomLeftBorder", "MerchantFrameBottomRightBorder",
        "BuybackFrameTopLeft", "BuybackFrameTopRight", "BuybackFrameBotLeft", "BuybackFrameBotRight",
    }) do
        local t = _G[name]
        if t and t.Hide then t:Hide() end
    end
end

-- ============================================================================
-- BODY FILL
-- ============================================================================

<<<<<<< HEAD
local ROCK_FDID = 374155

local function paintBody(f)
    local bg = f.Bg
    if not bg then
        bg = f:CreateTexture(nil, "BACKGROUND")
        f.Bg = bg
    end
    local rockPath = texLocal and texLocal(ROCK_FDID)
    bg:SetTexture(rockPath or ROCK_FDID, "REPEAT", "REPEAT")
=======
local function paintBody(f)
    local bg = f.Bg
    if not bg then
        bg = f:CreateTexture(nil, "BACKGROUND", nil, -6)
        f.Bg = bg
    end
    bg:SetTexture(ROCK, "REPEAT", "REPEAT")
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
    bg:SetHorizTile(true)
    bg:SetVertTile(true)
    bg:SetTexCoord(0, 1, 0, 1)
    bg:SetVertexColor(1, 1, 1)
    bg:ClearAllPoints()
<<<<<<< HEAD
    -- Full frame — same as every other window in the set (inspect, guild, auction house).
    -- The title band sits on top via OVERLAY; this stone runs behind it.
    bg:SetPoint("TOPLEFT",     f, "TOPLEFT",     0, -21)
    bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0,   0)
    bg:Show()
end

local function applyModernChrome()
    local f = _G.MerchantFrame
    if not f then return end
    if PCApplyModernChrome then PCApplyModernChrome(f) end
    paintBody(f)
=======
    bg:SetPoint("TOPLEFT",     f, "TOPLEFT",     2, -21)
    bg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2,  2)
    bg:Show()
end

local function applyStreaks(f)
    if f._duiStreaks then return end
    local streaks = f:CreateTexture(nil, "BORDER")
    streaks:set_atlas("_UI-Frame-TopTileStreaks")
    streaks:SetHorizTile(true)
    streaks:SetHeight(43)
    streaks:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -21)
    streaks:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -21)
    f._duiStreaks = streaks
end

local function applyModernChrome()
    local f = _G.MerchantFrame
    if not f then return end
    if not f._duiNineSlice then
        applyNineSlice(f, "PortraitFrameTemplate")
        f._duiNineSlice = true
    end
    paintBody(f)
    applyStreaks(f)
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
end

-- ============================================================================
-- BOTTOM BAND
-- ============================================================================

local function buildBottomBand()
    local f = _G.MerchantFrame
<<<<<<< HEAD
    if not f or f._neBotFrame then return end
    local t = f:CreateTexture(nil, "OVERLAY")
    if not texSetAtlas or not texSetAtlas(t, "ui-merchant-botframe", false) then return end
    t:SetHeight(61)
    t:SetPoint("BOTTOMLEFT",  f, "BOTTOMLEFT",   BAND_INSET, BAND_Y)
    t:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -BAND_INSET, BAND_Y)
    f._neBotFrame = t
=======
    if not f or f._duiBotFrame then return end
    local band = CreateFrame("Frame", nil, f)
    band:SetHeight(61)
    band:SetPoint("BOTTOMLEFT",  f, "BOTTOMLEFT",   BAND_INSET, BAND_Y)
    band:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -BAND_INSET, BAND_Y)
    local t = band:CreateTexture(nil, "ARTWORK")
    if not setAtlas(t, "ui-merchant-botframe", false) then
        band:Hide()
        return
    end
    t:SetAllPoints()
    band:SetFrameLevel((f:GetFrameLevel() or 1) + 1)
    f._duiBotFrame = band
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
end

-- ============================================================================
-- ROWS — slot reskin, quest bang, name clamping
-- ============================================================================

<<<<<<< HEAD
local function localTex(fdid)
    return texLocal and texLocal(fdid) or nil
end

=======
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
local function rowTexture(row, prefix, suffix, pathPattern)
    local t = _G[prefix .. suffix]
    if t then return t end
    if not row then return nil end
<<<<<<< HEAD
    if not FindRegion then return nil end
=======
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
    return FindRegion(row, "Texture", function(r)
        local p = r.GetTexture and r:GetTexture()
        return type(p) == "string" and p:lower():find(pathPattern) ~= nil
    end)
end

local function reskinSlot(prefix, showLabel)
    local row = _G[prefix]
    local slot = rowTexture(row, prefix, "SlotTexture", "ui%-emptyslot")
<<<<<<< HEAD
    local recess = localTex(EMPTY_SLOT_FDID)
    if slot then
        if recess then slot:SetTexture(recess) end
=======
    if slot then
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
        slot:Show()
    end

    local ib  = _G[prefix .. "ItemButton"]
    local nrm = (ib and ib.GetNormalTexture and ib:GetNormalTexture())
                or _G[prefix .. "ItemButtonNormalTexture"]
<<<<<<< HEAD
    local ring = localTex(SLOT_RING_FDID)
    if nrm and ring then
        nrm:SetTexture(ring)
=======
    if nrm then
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
        nrm:ClearAllPoints()
        nrm:SetSize(64, 64)
        nrm:SetPoint("CENTER", ib, "CENTER", 0, -1)
    end

    local nameFrame = rowTexture(row, prefix, "NameFrame", "ui%-merchant%-labelslots")
    if nameFrame then
        if showLabel then
<<<<<<< HEAD
            local plate = localTex(LABEL_PLATE_FDID)
            if plate then nameFrame:SetTexture(plate) end
=======
            nameFrame:SetTexture(LABEL_PLATE)
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
            nameFrame:SetVertexColor(0.5, 0.5, 0.5, 1)
            nameFrame:Show()
        else
            nameFrame:Hide()
        end
    end
end

local function fitBuybackIcon()
    local ib = _G.MerchantBuyBackItemItemButton
    if not ib then return end
    local icon = _G.MerchantBuyBackItemItemButtonIconTexture or ib.icon
    if not icon then return end
    icon:ClearAllPoints()
    icon:SetAllPoints(ib)
end

local function fitBuybackQualityGlow()
    local ib = _G.MerchantBuyBackItemItemButton
    local glow = ib and ib.__DragonUI_QualityOverlay
    if not glow then return end
    local n = (ib:GetWidth() or 37) * 1.7
    if math.abs((glow:GetWidth() or 0) - n) < 0.5 then return end
    glow:SetSize(n, n)
end

local BUYBACK_BTN = 37
<<<<<<< HEAD
local BUYBACK_Y   = 44
=======
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)

local function fitBuybackToBar()
    local ib = _G.MerchantBuyBackItemItemButton
    if not ib then return end
    ib:SetSize(BUYBACK_BTN, BUYBACK_BTN)
    local row = _G.MerchantBuyBackItem
    if row then row:SetSize(BUYBACK_BTN, BUYBACK_BTN) end
    fitBuybackIcon()
    local slot = _G.MerchantBuyBackItemSlotTexture
    if slot then slot:Show() end
    local nrm = ib.GetNormalTexture and ib:GetNormalTexture()
    if nrm then nrm:Show() end
end

local function reskinAllSlots()
    for i = 1, BUYBACK_PER_PAGE do
        if _G["MerchantItem" .. i] then reskinSlot("MerchantItem" .. i, true) end
    end
    if _G.MerchantBuyBackItem then reskinSlot("MerchantBuyBackItem", false) end
end

local QUEST_BANG_TEX = TEXTURE_ITEM_QUEST_BANG or "Interface\\ContainerFrame\\QuestBang"
local function addQuestBang(prefix)
    local ib = _G[prefix .. "ItemButton"]
    if not ib or ib.IconQuestTexture then return end
    local t = ib:CreateTexture(nil, "OVERLAY")
    t:SetTexture(QUEST_BANG_TEX)
    t:SetSize(37, 38)
    t:SetPoint("TOP", ib, "TOP", 0, 0)
    t:Hide()
    ib.IconQuestTexture = t
end

local function addQuestBangs()
    for i = 1, BUYBACK_PER_PAGE do
        if _G["MerchantItem" .. i] then addQuestBang("MerchantItem" .. i) end
    end
end

local function clampName(nm, width)
    if not nm then return end
    if nm.SetWordWrap then nm:SetWordWrap(false) end
    if nm.SetMaxLines then nm:SetMaxLines(1) end
    if width then nm:SetWidth(width) end
end

-- ============================================================================
-- REPAIR ICONS
-- ============================================================================

local REPAIR_ICONS = {
    { button = "MerchantRepairAllButton",       icon = "MerchantRepairAllIcon",            atlas = "spellicon-256x256-repairall"      },
    { button = "MerchantRepairItemButton",      icon = nil,                                atlas = "spellicon-256x256-repair"         },
    { button = "MerchantGuildBankRepairButton", icon = "MerchantGuildBankRepairButtonIcon", atlas = "spellicon-256x256-repairallguild", size = 36 },
}

local function repairIconRegion(btn, globalName)
    if globalName and _G[globalName] then return _G[globalName] end
<<<<<<< HEAD
    if not FindRegion then return nil end
=======
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
    return FindRegion(btn, "Texture", function(r)
        local p = r.GetTexture and r:GetTexture()
        return type(p) == "string" and p:lower():find("ui%-merchant%-repairicons") ~= nil
    end)
end

local function reskinRepairIcons()
    for _, spec in ipairs(REPAIR_ICONS) do
        local btn = _G[spec.button]
        if btn and spec.size then btn:SetSize(spec.size, spec.size) end
        local icon = btn and repairIconRegion(btn, spec.icon)
<<<<<<< HEAD
        if icon and texSetAtlas and texSetAtlas(icon, spec.atlas, false) then
            icon:ClearAllPoints()
            icon:SetAllPoints(btn)
            btn._neIcon = icon
=======
        if icon and setAtlas(icon, spec.atlas, false) then
            icon:ClearAllPoints()
            icon:SetAllPoints(btn)
            btn._duiIcon = icon
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
        end
    end
end

local function addRetailSlotBg(buttonName)
    local btn = _G[buttonName]
<<<<<<< HEAD
    if not btn or btn._neSlotBg then return end
    local path = localTex(EMPTY_SLOT_FDID)
    if not path then return end
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(path)
    bg:SetPoint("TOPLEFT",     btn, "TOPLEFT",     -TILE_BLEED,  TILE_BLEED)
    bg:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT",  TILE_BLEED, -TILE_BLEED)
    btn._neSlotBg = bg
=======
    if not btn then return end
    if not btn._duiSlotBg then
        local bg = btn:CreateTexture(nil, "OVERLAY", nil, -2)
        bg:SetTexture(QUICKSLOT_BG)
        bg:SetPoint("TOPLEFT",     btn, "TOPLEFT",     -(TILE_BLEED + 3) + 1,  (TILE_BLEED + 3) - 1)
        bg:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT",  (TILE_BLEED + 3) + 1, -(TILE_BLEED + 3) - 1)
        bg:SetVertexColor(1, 0.82, 0.32, 1)
        btn._duiSlotBg = bg
        bg:Show()
        local highlight = btn:GetHighlightTexture()
        if highlight then
            highlight:SetBlendMode("ADD")
        end
    end
end

local function syncSlotBg(buttonName, shown)
    local btn = _G[buttonName]
    local bg = btn and btn._duiSlotBg
    if not bg then return end
    if shown then bg:Show() else bg:Hide() end
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
end

local function addRetailSlotBgs()
    addRetailSlotBg("MerchantRepairAllButton")
    addRetailSlotBg("MerchantRepairItemButton")
    addRetailSlotBg("MerchantGuildBankRepairButton")
    addRetailSlotBg("DragonUI_MerchantSellAllJunkButton")
end

-- ============================================================================
-- BOTTOM BUTTON CLUSTER
-- ============================================================================

local function postRepairButtons()
    local f = _G.MerchantFrame
    if not f or f.selectedTab ~= 1 then return end
<<<<<<< HEAD
    stats.repair = stats.repair + 1

    local sell    = _G.DragonUI_MerchantSellAllJunkButton
    local buyback = _G.MerchantBuyBackItem

    if buyback then
        buyback:ClearAllPoints()
        buyback:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", BUYBACK_X, BUYBACK_Y)
    end

    local last
    if CanMerchantRepair and CanMerchantRepair() then
        local repAll  = _G.MerchantRepairAllButton
        local repItem = _G.MerchantRepairItemButton
        if not (repAll and repItem) then return end
        local guild = CanGuildBankRepair and CanGuildBankRepair()

        local w = (repItem:GetWidth() or 36) + BUTTON_GAP
        repAll:ClearAllPoints()
        repAll:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", BAR_X + w, BUTTON_Y)
        repItem:ClearAllPoints()
        repItem:SetPoint("RIGHT", repAll, "LEFT", -BUTTON_GAP, 0)
        last = repAll

        if guild then
            local gb = _G.MerchantGuildBankRepairButton
            if gb then
                gb:ClearAllPoints()
                gb:SetPoint("LEFT", repAll, "RIGHT", BUTTON_GAP, 0)
                last = gb
            end
        end

        if sell then
            sell:ClearAllPoints()
            sell:SetPoint("LEFT", last, "RIGHT", BUTTON_GAP, 0)
            last = sell
        end
    elseif sell then
        sell:ClearAllPoints()
        sell:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", BAR_X, BUTTON_Y)
        last = sell
=======

    addRetailSlotBgs()

    local sell    = _G.DragonUI_MerchantSellAllJunkButton
    local repAll  = _G.MerchantRepairAllButton
    local repItem = _G.MerchantRepairItemButton
    local gb      = _G.MerchantGuildBankRepairButton

    if CanMerchantRepair and CanMerchantRepair() then
        local guild = CanGuildBankRepair and CanGuildBankRepair()

        if repAll then
            repAll:ClearAllPoints()
            if guild then
                repAll:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", 96, 33)
            else
                repAll:SetPoint("BOTTOMRIGHT", f, "BOTTOMLEFT", 118, 33)
            end
            repAll:Show()
        end
        syncSlotBg("MerchantRepairAllButton", true)

        if repItem then
            repItem:ClearAllPoints()
            repItem:SetPoint("RIGHT", repAll, "LEFT", guild and -9 or -8, 0)
            repItem:Show()
        end
        syncSlotBg("MerchantRepairItemButton", true)

        if sell then
            sell:ClearAllPoints()
            sell:SetPoint("RIGHT", repAll, "LEFT", guild and 128 or 80, 0)
        end
        syncSlotBg("DragonUI_MerchantSellAllJunkButton", true)

        if gb then
            if guild then
                gb:ClearAllPoints()
                gb:SetPoint("LEFT", repAll, "RIGHT", 8, 0)
                gb:Show()
            else
                gb:Hide()
            end
        end
        syncSlotBg("MerchantGuildBankRepairButton", guild and true or false)
    else
        if repAll then repAll:Hide() end
        syncSlotBg("MerchantRepairAllButton", false)

        if repItem then repItem:Hide() end
        syncSlotBg("MerchantRepairItemButton", false)

        if gb then gb:Hide() end
        syncSlotBg("MerchantGuildBankRepairButton", false)

        if sell then
            sell:ClearAllPoints()
            sell:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -148, 33)
        end
        syncSlotBg("DragonUI_MerchantSellAllJunkButton", true)
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
    end
end

-- ============================================================================
-- INSETS, PAGE NAV, CLOSE BUTTON
-- ============================================================================

local INSET_TONE          = { 0.22, 0.22, 0.23 }
<<<<<<< HEAD
local INSET_TONE_BUYBACK  = { 0.85, 0.85, 0.87 }
=======
local INSET_TONE_BUYBACK  = { 0.22, 0.22, 0.23 }
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)

local function insetFill(f, key, rect, tone)
    if f[key] then return f[key] end
    local t = f:CreateTexture(nil, "ARTWORK", nil, -8)
    t:SetPoint("TOPLEFT",     rect, "TOPLEFT",     0, 0)
    t:SetPoint("BOTTOMRIGHT", rect, "BOTTOMRIGHT", 0, 0)
<<<<<<< HEAD
    local rockPath = texLocal and texLocal(ROCK_FDID)
    if rockPath then
        t:SetTexture(rockPath, "REPEAT", "REPEAT")
        t:SetHorizTile(true)
        t:SetVertTile(true)
        t:SetVertexColor(tone[1], tone[2], tone[3])
    else
        t:SetTexture(0.05, 0.05, 0.06, 0.92)
    end
    if PCKeep then PCKeep(f, t) end
=======
    t:SetTexture(ROCK, "REPEAT", "REPEAT")
    t:SetHorizTile(true)
    t:SetVertTile(true)
    t:SetVertexColor(tone[1], tone[2], tone[3])
    keep(f, t)
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
    f[key] = t
    return t
end

local function buildGridInset()
    local f = _G.MerchantFrame
<<<<<<< HEAD
    if not f or f._neGridInset then return end
    local inset = ninesliceAttachInset(f, INSET_TL_X, INSET_TL_Y, INSET_BR_X, INSET_BR_Y)
    if not inset then return end
    inset:SetFrameLevel((f:GetFrameLevel() or 1) + 1)
    f._neGridInset = inset
    insetFill(f, "_neGridInsetBg", inset, INSET_TONE)
end

-- DOWNPORT: there is no MerchantMoneyInset on this client (that is an Era/retail frame) — the
-- player's money simply floats on the classic bottom art. Build retail's recess for it instead.
local function buildMoneyInset()
    local f = _G.MerchantFrame
    local money = _G.MerchantMoneyFrame
    if not (f and money) or f._neMoneyInset then return end
    local inset = CreateFrame("Frame", nil, f)
    inset:SetPoint("TOPLEFT",     money, "TOPLEFT",     -8, 6)
    inset:SetPoint("BOTTOMRIGHT", money, "BOTTOMRIGHT",   6, -6)
    inset:EnableMouse(false)
    ninesliceApplyLayout(inset, "InsetFrameTemplate")
    inset:SetFrameLevel((f:GetFrameLevel() or 1) + 1)
    f._neMoneyInset = inset
    -- Fill as a child of the INSET frame (not f) so it renders above the
    -- bottom band (which lives on f's OVERLAY layer).
    local t = inset:CreateTexture(nil, "BACKGROUND", nil, -1)
    t:SetAllPoints()
    local rockPath = texLocal and texLocal(ROCK_FDID)
    if rockPath then
        t:SetTexture(rockPath, "REPEAT", "REPEAT")
        t:SetHorizTile(true)
        t:SetVertTile(true)
        t:SetVertexColor(INSET_TONE[1], INSET_TONE[2], INSET_TONE[3])
    else
        t:SetTexture(0.05, 0.05, 0.06, 0.92)
    end
    if PCKeep then PCKeep(f, t) end
    f._neMoneyInsetBg = t
=======
    if not f or f._duiGridInset then return end
    local inset = attachInset(f, INSET_TL_X, INSET_TL_Y, INSET_BR_X, INSET_BR_Y)
    if not inset then return end
    inset:SetFrameLevel((f:GetFrameLevel() or 1) + 1)
    f._duiGridInset = inset
    insetFill(f, "_duiGridInsetBg", inset, INSET_TONE)
    local ov = f:CreateTexture(nil, "ARTWORK", nil, -7)
    ov:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    ov:SetVertexColor(1, 1, 1)
    ov:SetAlpha(0.2)
    ov:SetPoint("TOPLEFT",     inset, "TOPLEFT",     0, 0)
    ov:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", 0, 0)
    ov:Hide()
    keep(f, ov)
    f._duiBuybackOverlay = ov
end

local function buildMoneyInset()
    local f = _G.MerchantFrame
    local money = _G.MerchantMoneyFrame
    if not (f and money) or f._duiMoneyInset then return end
    if money.SetWidth then
        money:SetWidth(160)
    end
    if not money._duiWidthHooked and hooksecurefunc then
        local moneyName = money:GetName()
        hooksecurefunc("MoneyFrame_Update", function(name)
            if name == moneyName and money.GetWidth and money:GetWidth() > 160 then
                money:SetWidth(160)
            end
        end)
        money._duiWidthHooked = true
    end

    local inset = CreateFrame("Frame", nil, f)
    inset:SetPoint("TOPLEFT",     money, "TOPLEFT",     -8, 6)
    inset:SetPoint("BOTTOMRIGHT", money, "BOTTOMRIGHT",  6, -6)
    inset:EnableMouse(false)
    applyNineSlice(inset, "InsetFrameTemplate")
    inset:SetFrameLevel((f:GetFrameLevel() or 1) + 4)
    f._duiMoneyInset = inset
    if inset.SetBackdrop then
        local box = CreateFrame("Frame", nil, inset)
        box:SetPoint("TOPLEFT",     inset, "TOPLEFT",      3, -2)
        box:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT",  0,  2)
        box:SetFrameLevel((inset:GetFrameLevel() or 0) + 2)
        box:SetBackdrop({
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 14,
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
            bgFile = nil,
        })
        box:SetBackdropBorderColor(1, 0.82, 0.32, 1)
        keep(f, box)
        f._duiMoneyTooltipBorder = box
    end

    local bg = inset:CreateTexture(nil, "BACKGROUND", nil, -1)
    bg:SetAllPoints()
    bg:SetTexture(ROCK, "REPEAT", "REPEAT")
    bg:SetHorizTile(true)
    bg:SetVertTile(true)
    bg:SetVertexColor(INSET_TONE[1], INSET_TONE[2], INSET_TONE[3])
    keep(f, bg)
    f._duiMoneyInsetBg = bg
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
end

local function applyPanelLayout(f)
    if not f.SetAttribute then return end
    if f:GetAttribute("UIPanelLayout-xoffset") == PANEL_X_NUDGE then return end
    f:SetAttribute("UIPanelLayout-area",     "left")
    f:SetAttribute("UIPanelLayout-pushable", 0)
    f:SetAttribute("UIPanelLayout-xoffset",  PANEL_X_NUDGE)
    f:SetAttribute("UIPanelLayout-enabled",  true)
    f:SetAttribute("UIPanelLayout-defined",  true)
    if f:IsShown() and UpdateUIPanelPositions then UpdateUIPanelPositions(f) end
end

local function applyLayout()
    local f = _G.MerchantFrame
    if not f then return end

    f:SetSize(PANEL_W, PANEL_H)
    applyPanelLayout(f)
    if f.SetHitRectInsets then f:SetHitRectInsets(0, 0, 0, 0) end

    local row1 = _G.MerchantItem1
    if row1 then
        row1:ClearAllPoints()
        row1:SetPoint("TOPLEFT", f, "TOPLEFT", GRID_X, GRID_Y)
    end

    local prev, nxt = _G.MerchantPrevPageButton, _G.MerchantNextPageButton
    if prev then
        prev:ClearAllPoints()
<<<<<<< HEAD
        prev:SetPoint("CENTER", f, "BOTTOMLEFT", PAGENAV_X, PAGENAV_Y)
    end
    if nxt then
        nxt:ClearAllPoints()
        nxt:SetPoint("CENTER", f, "BOTTOMRIGHT", -PAGENAV_X, PAGENAV_Y)
    end
    local pageText = _G.MerchantPageText
    if pageText then
        -- FontStrings lack SetFrameLevel; parent to a Frame we can lift above the inset background.
=======
        prev:SetPoint("CENTER", f, "BOTTOMLEFT", 25, 96)
    end
    if nxt then
        nxt:ClearAllPoints()
        nxt:SetPoint("CENTER", f, "BOTTOMLEFT", 310, 96)
    end
    local pageText = _G.MerchantPageText
    if pageText then
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
        local pw = pageText._duiWrapper
        if not pw then
            pw = CreateFrame("Frame", nil, f)
            pageText:SetParent(pw)
            pageText._duiWrapper = pw
        end
        pw:ClearAllPoints()
<<<<<<< HEAD
        pw:SetPoint("CENTER", f, "BOTTOMLEFT", PANEL_W / 2, PAGENAV_Y)
        pw:SetSize(140, 20)
        pageText:ClearAllPoints()
        pageText:SetPoint("CENTER", pw, "CENTER", 0, 0)
        pageText:SetWidth(140)
=======
        pw:SetPoint("BOTTOM", f, "BOTTOM", 0, 86)
        pw:SetSize(104, 20)
        pageText:ClearAllPoints()
        pageText:SetPoint("BOTTOM", pw, "BOTTOM", 0, 0)
        pageText:SetWidth(104)
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
        pageText:SetJustifyH("CENTER")
    end

    local money = _G.MerchantMoneyFrame
    if money then
        money:ClearAllPoints()
<<<<<<< HEAD
        money:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, MONEY_Y)
=======
        money:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", MONEY_X, MONEY_Y)
    end

    local buyback = _G.MerchantBuyBackItem
    if buyback then
        buyback:ClearAllPoints()
        buyback:SetPoint("TOPLEFT", _G.MerchantItem10, "BOTTOMLEFT", 30, -53)
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
    end

    local sellJunk = _G.MerchantFrameSellJunkFrame
    if sellJunk then
        sellJunk:ClearAllPoints()
        sellJunk:SetPoint("BOTTOMRIGHT", money, "BOTTOMLEFT", -4, 0)
    end

    local repairSettings = _G.MerchantRepairSettingsButton
    if repairSettings then
        repairSettings:ClearAllPoints()
        repairSettings:SetPoint("BOTTOMRIGHT", sellJunk, "BOTTOMLEFT", -4, 0)
    end

    local above = (f:GetFrameLevel() or 1) + 4
    for i = 1, BUYBACK_PER_PAGE do
        local row = _G["MerchantItem" .. i]
        if row then row:SetFrameLevel(above) end
    end
    if _G.MerchantBuyBackItem then _G.MerchantBuyBackItem:SetFrameLevel(above) end
    if prev then prev:SetFrameLevel(above) end
    if nxt  then nxt:SetFrameLevel(above)  end
    if pageText and pageText._duiWrapper then pageText._duiWrapper:SetFrameLevel(above) end
    if money then money:SetFrameLevel(above) end
<<<<<<< HEAD
end

-- Page nav textures
local PAGE_BTN_TEX = {
    MerchantPrevPageButton = { up = 130869, down = 130868, disabled = 130867 },
    MerchantNextPageButton = { up = 130866, down = 130865, disabled = 130864 },
}
local PAGE_BG_FDID     = 130822
local PAGE_HILITE_FDID = 130757

=======
    for _, name in ipairs({
        "MerchantRepairAllButton", "MerchantRepairItemButton", "MerchantGuildBankRepairButton",
        "DragonUI_MerchantSellAllJunkButton"
    }) do
        local b = _G[name]
        if b then b:SetFrameLevel(above) end
    end
end

>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
local function reskinPageNav(btnName)
    local btn = _G[btnName]
    local set = PAGE_BTN_TEX[btnName]
    if not (btn and set) then return end

<<<<<<< HEAD
    local function retexture(getter, fdid, blend)
        local path = localTex(fdid)
=======
    local function retexture(getter, path, blend)
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
        local t = path and btn[getter] and btn[getter](btn)
        if not t then return end
        t:SetTexture(path)
        if blend then t:SetBlendMode(blend) end
    end

    retexture("GetNormalTexture",    set.up)
    retexture("GetPushedTexture",    set.down)
    retexture("GetDisabledTexture",  set.disabled)
<<<<<<< HEAD
    retexture("GetHighlightTexture", PAGE_HILITE_FDID, "ADD")

    local bgPath = localTex(PAGE_BG_FDID)
    if bgPath and ForEachRegion then
        ForEachRegion(btn, "Texture", "BACKGROUND", function(r)
            r:SetTexture(bgPath)
            r:Show()
        end)
    end
=======
    retexture("GetHighlightTexture", PAGE_HILITE, "ADD")

    ForEachRegion(btn, "Texture", "BACKGROUND", function(r)
        r:SetTexture(PAGE_BG)
        r:Show()
    end)
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
end

local function reskinPageNavButtons()
    reskinPageNav("MerchantPrevPageButton")
    reskinPageNav("MerchantNextPageButton")
end

local function findCloseButton(f)
    if _G.MerchantFrameCloseButton then return _G.MerchantFrameCloseButton end
    for _, child in ipairs({ f:GetChildren() }) do
        if child.GetObjectType and child:GetObjectType() == "Button" and child.GetNormalTexture then
            local t = child:GetNormalTexture()
            local p = t and t.GetTexture and t:GetTexture()
            if type(p) == "string" and p:lower():find("ui%-panel%-minimizebutton") then return child end
        end
    end
    return nil
end

local function modernizeCloseButton()
    local f = _G.MerchantFrame
    if not f then return end
    f.CloseButton = f.CloseButton or findCloseButton(f)
    if not f.CloseButton then return end
<<<<<<< HEAD
    if PCModernizeCloseButton then PCModernizeCloseButton(f, { frameLevelBump = 20 }) end
=======
    dressCloseButton(f.CloseButton, f)
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
end

-- ============================================================================
-- PER-UPDATE SYNC
-- ============================================================================

local function setRowPitch(gap)
    local prev = _G.MerchantItem1
    for _, i in ipairs({ 3, 5, 7, 9 }) do
        local row = _G["MerchantItem" .. i]
        if not (row and prev) then return end
        row:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, gap)
        prev = row
    end
    local row11, row9 = _G.MerchantItem11, _G.MerchantItem9
    if row11 and row9 then
        row11:ClearAllPoints()
        row11:SetPoint("TOPLEFT", row9, "BOTTOMLEFT", 0, gap)
    end
end

local function setInsetForTab(f)
<<<<<<< HEAD
    local inset = f._neGridInset
    if not inset then return end
    local buyback = (f.selectedTab == 2)
    local y = buyback and INSET_BR_Y_BUYBACK or INSET_BR_Y
    if inset._neBottom == y then return end
    inset._neBottom = y
    inset:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", INSET_BR_X, y)
    local tone = buyback and INSET_TONE_BUYBACK or INSET_TONE
    local bg = f._neGridInsetBg
=======
    local inset = f._duiGridInset
    if not inset then return end
    local buyback = (f.selectedTab == 2)

    if f._duiBuybackOverlay then
        if buyback then f._duiBuybackOverlay:Show() else f._duiBuybackOverlay:Hide() end
    end

    local y = buyback and INSET_BR_Y_BUYBACK or INSET_BR_Y
    if inset._duiBottom == y then return end
    inset._duiBottom = y
    inset:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", INSET_BR_X, y)
    local tone = buyback and INSET_TONE_BUYBACK or INSET_TONE
    local bg = f._duiGridInsetBg
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
    if bg then bg:SetVertexColor(tone[1], tone[2], tone[3]) end
end

local function postMerchantUpdate()
    local f = _G.MerchantFrame
<<<<<<< HEAD
    if not f or not f._neBuilt then return end
    stats.update = stats.update + 1
    stats.tab = f.selectedTab

    hideClassicChrome()
    setInsetForTab(f)
=======
    if not f or not f._duiBuilt then return end

    hideClassicChrome()
    setInsetForTab(f)
    updateMerchantTabHighlight(f)
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
    if f.Bg then f.Bg:Show() end

    if f.Title and _G.MerchantNameText then
        f.Title:SetText(_G.MerchantNameText:GetText() or "")
    end

    local p = _G.MerchantFramePortrait
    if p then
        p:Show()
        if f.selectedTab == 2 then
            p:SetTexture("Interface\\MerchantFrame\\UI-BuyBack-Icon")
            p:SetTexCoord(0, 1, 0, 1)
        elseif SetPortraitTexture then
            SetPortraitTexture(p, "NPC")
        end
    end

    local onMerchant = (f.selectedTab == 1)

<<<<<<< HEAD
    if f._neBotFrame then
        if onMerchant then f._neBotFrame:Show() else f._neBotFrame:Hide() end
=======
    if f._duiBotFrame then
        if onMerchant then f._duiBotFrame:Show() else f._duiBotFrame:Hide() end
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
    end
    local sell = _G.DragonUI_MerchantSellAllJunkButton
    if sell then
        if onMerchant then sell:Show() else sell:Hide() end
    end

    local buyback = _G.MerchantBuyBackItem
    if buyback then
        if onMerchant then buyback:Show() else buyback:Hide() end
    end
    if not onMerchant then
        for _, name in ipairs({
            "MerchantGuildBankRepairButton", "MerchantRepairAllButton", "MerchantRepairItemButton",
        }) do
            local b = _G[name]
            if b then b:Hide() end
        end
    end

    for i = 1, BUYBACK_PER_PAGE do
        clampName(_G["MerchantItem" .. i .. "Name"], 84)
    end
    if _G.MerchantBuyBackItemName then _G.MerchantBuyBackItemName:Hide() end
    if _G.MerchantBuyBackItemMoneyFrame then _G.MerchantBuyBackItemMoneyFrame:Hide() end
    fitBuybackIcon()
    fitBuybackToBar()
    fitBuybackQualityGlow()

    postRepairButtons()
end

local function colourRow(prefix, link)
    if not _G[prefix] then return end
    local quality = link and select(3, GetItemInfo(link)) or nil

    local nm = _G[prefix .. "Name"]
    if nm then
        local c = TextColor(quality)
        if c then
            nm:SetTextColor(c.r, c.g, c.b)
        else
            nm:SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
        end
    end

    local ib = _G[prefix .. "ItemButton"]
    local bang = ib and ib.IconQuestTexture
    if bang then
        if link and ItemStartsQuestByLink(link) then bang:Show() else bang:Hide() end
    end
end

local function postUpdateMerchantInfo()
    local f = _G.MerchantFrame
<<<<<<< HEAD
    if not f or not f._neBuilt then return end
    stats.merchantInfo = stats.merchantInfo + 1
    stats.tab = f.selectedTab
=======
    if not f or not f._duiBuilt then return end
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
    setRowPitch(ROW_GAP_MERCHANT)
    local page = f.page or 1
    for i = 1, ITEMS_PER_PAGE do
        local index = ((page - 1) * ITEMS_PER_PAGE) + i
        colourRow("MerchantItem" .. i, GetMerchantItemLink and GetMerchantItemLink(index))
    end
    local n = (GetNumBuybackItems and GetNumBuybackItems()) or 0
    colourRow("MerchantBuyBackItem",
              (n > 0 and GetBuybackItemLink) and GetBuybackItemLink(n) or nil)
end

local function postUpdateBuybackInfo()
    local f = _G.MerchantFrame
<<<<<<< HEAD
    if not f or not f._neBuilt then return end
    stats.buybackInfo = stats.buybackInfo + 1
    stats.tab = f.selectedTab
=======
    if not f or not f._duiBuilt then return end
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
    setRowPitch(ROW_GAP_BUYBACK)
    for i = 1, BUYBACK_PER_PAGE do
        colourRow("MerchantItem" .. i, GetBuybackItemLink and GetBuybackItemLink(i))
        local ib = _G["MerchantItem" .. i .. "ItemButton"]
        if ib and ib.IconQuestTexture then ib.IconQuestTexture:Hide() end
    end
end

<<<<<<< HEAD
-- Timer-based sync (safe even if FrameXML updaters throw)
-- On first MERCHANT_SHOW, build the modern chrome before syncing.
-- ============================================================================
-- TAB RESKIN — inline version of NE.tabs.ReskinClassicTab + SizeAndAnchorTabs
-- Replaces classic wooden tabs with retail atlas art and repositions them below
-- the frame edge (inside the nineslice border).
-- ============================================================================

local TAB_ATLAS = {
    Left           = "uiframe-tab-left",
    Right          = "uiframe-tab-right",
    Middle         = "_uiframe-tab-center",
    LeftDisabled   = "uiframe-activetab-left",
    RightDisabled  = "uiframe-activetab-right",
    MiddleDisabled = "_uiframe-activetab-center",
}
local TAB_SIZE = {
    Left           = { w = 35, h = 36 },
    Right          = { w = 37, h = 36 },
    Middle         = { h = 36 },
    LeftDisabled   = { w = 35, h = 42 },
    RightDisabled  = { w = 37, h = 42 },
    MiddleDisabled = { h = 42 },
}
=======

-- ============================================================================
-- TAB RESKIN
-- ============================================================================

local CAP_OVERHANG = 5
local ACTIVE_OVERHANG_L, ACTIVE_OVERHANG_R = 4, 6
local HL_ALPHA, HL_H = 0.4, 30
local HL_LEFT_TC   = { 0.015625, 0.5625, 0.816406, 0.933594 }
local HL_RIGHT_TC  = { 0.015625, 0.59375, 0.667969, 0.785156 }
local HL_MIDDLE_TC = { 0, 0.015625, 0.175781, 0.292969 }
local TEXT_ACTIVE_DROP, TEXT_NUDGE_X = -7, -2
local TAB_GAP = 1

>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)

local function reskinSingleTab(tabName)
    local tab = _G[tabName]
    if not tab or tab._duiTabReskinned then return end

<<<<<<< HEAD
    local texSet = texSetAtlas
    if not texSet then return end

    -- Replace the 6 texture pieces with retail atlas art
    for suffix, atlas in pairs(TAB_ATLAS) do
        local tex = _G[tabName .. suffix]
        if tex then
            texSet(tex, atlas, false)
            local sz = TAB_SIZE[suffix]
            if sz then
                if sz.w then tex:SetWidth(sz.w) end
                if sz.h then tex:SetHeight(sz.h) end
            end
        end
    end

    -- Reposition the pieces relative to the tab button
=======
    tab:SetFrameLevel(tab:GetFrameLevel() + 4)
    tab:SetNormalFontObject(GameFontNormalSmall)
    tab:SetHighlightFontObject(GameFontHighlightSmall)


>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
    local left   = _G[tabName .. "Left"]
    local right  = _G[tabName .. "Right"]
    local middle = _G[tabName .. "Middle"]
    local leftD  = _G[tabName .. "LeftDisabled"]
    local rightD = _G[tabName .. "RightDisabled"]
    local midD   = _G[tabName .. "MiddleDisabled"]

<<<<<<< HEAD
    if left   then left:ClearAllPoints();   left:SetPoint("TOPLEFT",  tab, "TOPLEFT",  0, 0) end
    if right  then right:ClearAllPoints();  right:SetPoint("TOPRIGHT", tab, "TOPRIGHT",  0, 0) end
    if leftD  then leftD:ClearAllPoints();  leftD:SetPoint("TOPLEFT",  tab, "TOPLEFT",  0, 0) end
    if rightD then rightD:ClearAllPoints(); rightD:SetPoint("TOPRIGHT", tab, "TOPRIGHT",  0, 0) end

    if middle and left and right then
        middle:ClearAllPoints()
        middle:SetPoint("TOPLEFT",  left,  "TOPRIGHT", 0, 0)
        middle:SetPoint("TOPRIGHT", right, "TOPLEFT",  0, 0)
        middle:SetHorizTile(true)
    end
    if midD and leftD and rightD then
        midD:ClearAllPoints()
        midD:SetPoint("TOPLEFT",  leftD,  "TOPRIGHT", 0, 0)
        midD:SetPoint("TOPRIGHT", rightD, "TOPLEFT",  0, 0)
        midD:SetHorizTile(true)
    end

    -- Font and selection offsets
    tab:SetNormalFontObject(GameFontNormalSmall)
    tab:SetHighlightFontObject(GameFontHighlightSmall)
    tab:SetDisabledFontObject(GameFontNormalSmall)
    tab.selectedTextY   = -3
    tab.deselectedTextY =  2
=======
    if left then
        left:ClearAllPoints()
        left:SetSize(35, 36)
        left:SetTexture(TAB_TEX)
        left:SetTexCoord(0.015625, 0.5625, 0.816406, 0.957031)
        left:SetPoint("TOPLEFT", tab, "TOPLEFT", -CAP_OVERHANG, 0)
    end
    if right then
        right:ClearAllPoints()
        right:SetSize(37, 36)
        right:SetTexture(TAB_TEX)
        right:SetTexCoord(0.015625, 0.59375, 0.667969, 0.808594)
        right:SetPoint("TOPRIGHT", tab, "TOPRIGHT", CAP_OVERHANG, 0)
    end
    if middle and left and right then
        middle:ClearAllPoints()
        middle:SetSize(1, 36)
        middle:SetTexture(TAB_TEX)
        middle:SetTexCoord(0, 0.015625, 0.175781, 0.316406)
        middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
        middle:SetPoint("TOPRIGHT", right, "TOPLEFT")
    end

    if leftD then
        leftD:ClearAllPoints()
        leftD:SetSize(35, 42)
        leftD:SetTexture(TAB_TEX)
        leftD:SetTexCoord(0.015625, 0.5625, 0.496094, 0.660156)
        leftD:SetPoint("TOPLEFT", tab, "TOPLEFT", -ACTIVE_OVERHANG_L, 0)
    end
    if rightD then
        rightD:ClearAllPoints()
        rightD:SetSize(37, 42)
        rightD:SetTexture(TAB_TEX)
        rightD:SetTexCoord(0.015625, 0.59375, 0.324219, 0.488281)
        rightD:SetPoint("TOPRIGHT", tab, "TOPRIGHT", ACTIVE_OVERHANG_R, 0)
    end
    if midD and leftD and rightD then
        midD:ClearAllPoints()
        midD:SetSize(1, 42)
        midD:SetTexture(TAB_TEX)
        midD:SetTexCoord(0, 0.015625, 0.00390625, 0.167969)
        midD:SetPoint("TOPLEFT", leftD, "TOPRIGHT")
        midD:SetPoint("TOPRIGHT", rightD, "TOPLEFT")
    end

    local stock = tab:GetHighlightTexture()
    if stock then stock:SetTexture(nil) end

    local function glow(tc, w, anchor)
        local t = tab:CreateTexture(nil, "HIGHLIGHT")
        t:SetTexture(TAB_TEX)
        t:SetTexCoord(unpack(tc))
        t:SetSize(w, HL_H)
        t:SetPoint("TOPLEFT", anchor, "TOPLEFT")
        t:SetBlendMode("ADD")
        t:SetAlpha(HL_ALPHA)
        return t
    end

    local hlLeft  = left  and glow(HL_LEFT_TC,   35, left)
    local hlRight = right and glow(HL_RIGHT_TC,  37, right)
    local hlMid   = middle and (function()
        local t = tab:CreateTexture(nil, "HIGHLIGHT")
        t:SetTexture(TAB_TEX)
        t:SetTexCoord(unpack(HL_MIDDLE_TC))
        t:SetHeight(HL_H)
        t:SetPoint("TOPLEFT", hlLeft, "TOPRIGHT")
        t:SetPoint("TOPRIGHT", hlRight, "TOPLEFT")
        t:SetBlendMode("ADD")
        t:SetAlpha(HL_ALPHA)
        return t
    end)()

    tab._duiHighlight = { hlLeft, hlRight, hlMid }

    local w = tab:GetTextWidth() + 24
    if w < 64 then w = 64 end
    tab._duiWidth = w
    tab:SetWidth(w)
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)

    tab._duiTabReskinned = true
end

local function reskinMerchantTabs(f)
    reskinSingleTab("MerchantFrameTab1")
    reskinSingleTab("MerchantFrameTab2")

<<<<<<< HEAD
    -- Position tabs along the frame's BOTTOMLEFT edge, inside the nineslice border.
    -- Retail hangs them off the bottom; classic sits them at BOTTOMLEFT+(11,46) which
    -- is inside the nineslice overlay layer and reads as crowded.
=======
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
    local prev
    for _, name in ipairs({ "MerchantFrameTab1", "MerchantFrameTab2" }) do
        local tab = _G[name]
        if tab and tab:IsShown() then
            tab:ClearAllPoints()
            if prev then
<<<<<<< HEAD
                tab:SetPoint("TOPLEFT", prev, "TOPRIGHT", -10, 0)
=======
                tab:SetPoint("TOPLEFT", prev, "TOPRIGHT", TAB_GAP, 0)
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
            else
                tab:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 11, 2)
            end
            prev = tab
        end
    end
end

-- ============================================================================
<<<<<<< HEAD
=======
-- TAB LABEL STATE —
-- ============================================================================

updateMerchantTabHighlight = function(f)
    if not f then return end
    for i = 1, 2 do
        local tab = _G["MerchantFrameTab" .. i]
        if tab then
            local active = (i == f.selectedTab)
            tab:SetNormalFontObject(GameFontNormalSmall)
            tab:SetHighlightFontObject(GameFontHighlightSmall)
            tab:SetDisabledFontObject(active and GameFontHighlightSmall or GameFontNormalSmall)
            if tab._duiWidth then tab:SetWidth(tab._duiWidth) end

            local text = _G[tab:GetName() .. "Text"]
            if text then
                text:ClearAllPoints()
                local offsetY = active and TEXT_ACTIVE_DROP or 0
                text:SetPoint("CENTER", tab, "CENTER", TEXT_NUDGE_X, offsetY)
            end

            for _, piece in ipairs(tab._duiHighlight or {}) do
                piece:SetAlpha(active and 0 or HL_ALPHA)
            end
        end
    end
end

-- ============================================================================
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
-- BUILD — deferred from login to first MERCHANT_SHOW
-- ============================================================================

local built = false

local function buildModernChrome()
    if built then return end
    local f = _G.MerchantFrame
    if not f then return end
    built = true

<<<<<<< HEAD
    applyModernChrome()

    if PCEnsureTitle then
        PCEnsureTitle(f, (_G.MerchantNameText and _G.MerchantNameText:GetText()) or "")
    end

    if _G.MerchantFramePortrait and portraitApplyCutout then
        portraitApplyCutout(_G.MerchantFramePortrait, f)
    end

    buildGridInset()
    buildBottomBand()
    reskinAllSlots()
    fitBuybackToBar()
    addQuestBangs()
    reskinRepairIcons()
    buildMoneyInset()
    modernizeCloseButton()
    reskinPageNavButtons()

    -- Tab reskinning: replace classic wooden tabs with retail atlas art
    reskinMerchantTabs(f)

    for i = 1, BUYBACK_PER_PAGE do clampName(_G["MerchantItem" .. i .. "Name"], 84) end

    -- Sibling modules (SellAllJunk, BuybackUndo) build their buttons here
    if addon.MerchantSellAllJunkBuild then addon.MerchantSellAllJunkBuild() end
    if addon.MerchantBuybackUndoBuild then addon.MerchantBuybackUndoBuild() end

    addRetailSlotBgs()

    f._neBuilt = true
=======
    local function _doBuild()
        applyModernChrome()
        ensureTitle(f, (_G.MerchantNameText and _G.MerchantNameText:GetText()) or "")
        if _G.MerchantFramePortrait then
            applyPortraitCutout(_G.MerchantFramePortrait, f)
        end

        buildGridInset()
        buildBottomBand()
        reskinAllSlots()
        fitBuybackToBar()
        addQuestBangs()
        reskinRepairIcons()
        buildMoneyInset()
        modernizeCloseButton()
        reskinPageNavButtons()
        reskinMerchantTabs(f)

        for i = 1, BUYBACK_PER_PAGE do clampName(_G["MerchantItem" .. i .. "Name"], 84) end

        if addon.MerchantSellAllJunkBuild then addon.MerchantSellAllJunkBuild() end
        if addon.MerchantBuybackUndoBuild then addon.MerchantBuybackUndoBuild() end

        addRetailSlotBgs()
    end

    local ok, err = xpcall(_doBuild, function(e) return tostring(e) end)
    if not ok then
        DEFAULT_CHAT_FRAME:AddMessage("|cff1784d1DragonUI|r Merchant build error: " .. tostring(err))
        return
    end

    f._duiBuilt = true
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)

    if f:IsShown() and _G.MerchantFrame_Update then
        MerchantFrame_Update()
    else
        postMerchantUpdate()
    end
end

<<<<<<< HEAD
-- Timer-based sync (safe even if FrameXML updaters throw)
-- On first MERCHANT_SHOW, build the modern chrome before syncing.
=======
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
local syncPending
local function syncSoon()
    local f = _G.MerchantFrame
    if not f or syncPending then return end
    syncPending = true
<<<<<<< HEAD
    C_Timer.After(0, function()
        syncPending = false
        local frame = _G.MerchantFrame
        if not frame or not frame:IsShown() then return end
        -- First show: build the modern chrome (deferred from login to MERCHANT_SHOW).
        if not built then
            buildModernChrome()
        end
        if not frame._neBuilt then return end
=======
    addon:After(0, function()
        syncPending = false
        local frame = _G.MerchantFrame
        if not frame or not frame:IsShown() then return end
        if not built then
            buildModernChrome()
        end
        if not frame._duiBuilt then return end
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
        postMerchantUpdate()
        if frame.selectedTab == 2 then postUpdateBuybackInfo() else postUpdateMerchantInfo() end
    end)
end

-- ============================================================================
-- ARM — called once at login to set up hooks and suppression
-- ============================================================================

local function ArmMerchant()
    if MerchantModule.applied then return end

    hideClassicChrome()
    applyLayout()

    -- Hook FrameXML updaters
    if _G.MerchantFrame_Update and not MerchantModule.hooks["MerchantFrame_Update"] then
        hooksecurefunc("MerchantFrame_Update", postMerchantUpdate)
        MerchantModule.hooks["MerchantFrame_Update"] = true
    end
    if _G.MerchantFrame_UpdateMerchantInfo and not MerchantModule.hooks["MerchantFrame_UpdateMerchantInfo"] then
        hooksecurefunc("MerchantFrame_UpdateMerchantInfo", postUpdateMerchantInfo)
        MerchantModule.hooks["MerchantFrame_UpdateMerchantInfo"] = true
    end
    if _G.MerchantFrame_UpdateBuybackInfo and not MerchantModule.hooks["MerchantFrame_UpdateBuybackInfo"] then
        hooksecurefunc("MerchantFrame_UpdateBuybackInfo", postUpdateBuybackInfo)
        MerchantModule.hooks["MerchantFrame_UpdateBuybackInfo"] = true
    end
    if _G.MerchantFrame_UpdateRepairButtons and not MerchantModule.hooks["MerchantFrame_UpdateRepairButtons"] then
        hooksecurefunc("MerchantFrame_UpdateRepairButtons", postRepairButtons)
        MerchantModule.hooks["MerchantFrame_UpdateRepairButtons"] = true
    end

<<<<<<< HEAD
    -- Tab button click hooks (belt on top of FrameXML hooks)
=======
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
    for _, tabName in ipairs({ "MerchantFrameTab1", "MerchantFrameTab2" }) do
        local tab = _G[tabName]
        if tab and tab.HookScript and not MerchantModule.hooks["tab_" .. tabName] then
            tab:HookScript("OnClick", function()
<<<<<<< HEAD
                stats.tabClick = stats.tabClick + 1
=======
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
                syncSoon()
            end)
            MerchantModule.hooks["tab_" .. tabName] = true
        end
    end

<<<<<<< HEAD
    -- Event-driven sync
=======
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
    local syncFrame = CreateFrame("Frame")
    syncFrame:RegisterEvent("MERCHANT_SHOW")
    syncFrame:RegisterEvent("MERCHANT_UPDATE")
    syncFrame:RegisterEvent("MERCHANT_CLOSED")
<<<<<<< HEAD
    syncFrame:SetScript("OnEvent", function(_, event)
        if event == "MERCHANT_SHOW" then
            stats.evShow = stats.evShow + 1;  trace("evSHOW")
        elseif event == "MERCHANT_CLOSED" then
            stats.evClosed = stats.evClosed + 1;  trace("evCLOSED")
        end
=======
    syncFrame:SetScript("OnEvent", function()
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
        syncSoon()
    end)
    MerchantModule.frames.syncFrame = syncFrame

<<<<<<< HEAD
    -- OnShow/OnHide trace hooks
    local mf = _G.MerchantFrame
    if mf and mf.HookScript then
        mf:HookScript("OnShow", function() stats.onShow = stats.onShow + 1; trace("OnShow") end)
        mf:HookScript("OnHide", function() stats.onHide = stats.onHide + 1; trace("OnHide") end)
    end

    -- GET_ITEM_INFO_RECEIVED for uncached item quality + quest bang
=======
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("GET_ITEM_INFO_RECEIVED")
    watcher:SetScript("OnEvent", function()
        local f = _G.MerchantFrame
<<<<<<< HEAD
        if not (f and f._neBuilt and f:IsShown()) then return end
=======
        if not (f and f._duiBuilt and f:IsShown()) then return end
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
        if f.selectedTab == 2 then postUpdateBuybackInfo() else postUpdateMerchantInfo() end
    end)
    MerchantModule.frames.watcher = watcher

    MerchantModule.applied = true
end

-- ============================================================================
-- LIFECYCLE: Apply / Restore / Refresh
-- ============================================================================

local function ApplyMerchant(force)
    if MerchantModule.applied and not force then return end
    if not IsModuleEnabled() then return end
    if MerchantModule.applied then
        RestoreMerchant(false)
        MerchantModule.applied = false
    end
    ArmMerchant()
end

local function RestoreMerchant(resetDeps)
    if not MerchantModule.applied then return end
<<<<<<< HEAD
    -- NOTE: hooksecurefunc are permanent for the session — we cannot un-hook them.
    -- This module is effectively load-once. Restore just tears down the visual chrome.
=======
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
    MerchantModule.applied = false
end

local function RefreshMerchant(forceSync)
    if MerchantModule.applied then
        RestoreMerchant(false)
    end
    if IsModuleEnabled() then
        ApplyMerchant(forceSync == true)
    end
end

-- ============================================================================
-- EXPOSE ON ADDON NAMESPACE
-- ============================================================================

function addon.ApplyMerchantSystem() ApplyMerchant() end
function addon.RestoreMerchantSystem() RestoreMerchant() end
function addon.RefreshMerchantSystem() RefreshMerchant() end

-- ============================================================================
-- PROFILE CHANGE HANDLER
-- ============================================================================

local function OnProfileChanged()
    if IsModuleEnabled() then
        RefreshMerchant()
    else
        if (addon.ShouldDeferModuleDisable and addon:ShouldDeferModuleDisable("merchant", MerchantModule)) then
            return
        end
        RestoreMerchant()
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "DragonUI" then
        if not IsModuleEnabled() then return end
        addon:After(0.5, function()
            if addon.db and addon.db.RegisterCallback then
                addon.db.RegisterCallback(addon, "OnProfileChanged", OnProfileChanged)
                addon.db.RegisterCallback(addon, "OnProfileCopied", OnProfileChanged)
                addon.db.RegisterCallback(addon, "OnProfileReset", OnProfileChanged)
            end
        end)
        MerchantModule.initialized = true
    elseif event == "PLAYER_ENTERING_WORLD" then
        if not IsModuleEnabled() then return end
        ApplyMerchant()
        addon:After(0.5, function()
            if not IsModuleEnabled() then return end
<<<<<<< HEAD
            -- First MERCHANT_SHOW builds the chrome; arm hooks early so they exist
            -- before the first MerchantFrame_Update.
=======
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
            ArmMerchant()
        end)
    end
end)

<<<<<<< HEAD
-- ============================================================================
-- SLASH COMMAND — /dragonui merchant
-- ============================================================================

SLASH_DRAGONUI_MERCHANT1 = "/dragonui-merchant"
SlashCmdList["DRAGONUI_MERCHANT"] = function() diagnose() end
=======
>>>>>>> 71963e6 (feat(merchant): retail-style vendor window chrome)
