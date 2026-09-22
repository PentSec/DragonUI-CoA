-- DragonUI/modules/merchant/SellAllJunk.lua — retail's one-click sell-all-junk button.
--
-- DOWNPORT of NewEra/MerchantFrame/SellAllJunk.lua, adapted for DragonUI.
-- Retail's MerchantSellAllJunkButton calls C_MerchantFrame.SellAllJunkItems; neither exists
-- on 3.3.5a, so this is a bag walk using GetContainerItemLink + GetItemInfo.
--
-- Changes from NewEra:
--   * Uses DragonUI_MerchantSellAllJunkButton global name (not NE_MerchantSellAllJunkButton)
--   * No containerframe bag-exclusion support (DragonUI doesn't have it yet)
--   * Simplified: skips quest items, sells only poor-quality vendorable items

local addon = select(2, ...)

local L = addon.L

local POPUP = "DRAGONUI_SELL_ALL_JUNK"
local POOR_LINK_COLOR = "|cff9d9d9d"

-- Quality comes from the link colour because GetItemInfo is nil until the item is cached.
local function junkAt(bag, slot)
    local link = GetContainerItemLink(bag, slot)
    if not link or link:sub(1, 10) ~= POOR_LINK_COLOR then return false end
    local sellPrice = select(11, GetItemInfo(link))
    return sellPrice ~= 0
end

local function forEachBagSlot(fn)
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, GetContainerNumSlots(bag) or 0 do
            fn(bag, slot)
        end
    end
end

local function countJunkItems()
    local n = 0
    forEachBagSlot(function(bag, slot)
        if junkAt(bag, slot) then n = n + 1 end
    end)
    return n
end

local function sellAllJunk()
    if not MerchantFrame or not MerchantFrame:IsShown() then return end
    if MerchantFrame.selectedTab ~= 1 then return end

    local sold = 0
    forEachBagSlot(function(bag, slot)
        if junkAt(bag, slot) and pcall(UseContainerItem, bag, slot) then
            sold = sold + 1
        end
    end)

    if sold > 0 then
        addon:Print(string.format(L["Sold %d junk item(s)."], sold))
    end
end

-- ============================================================================
-- Button
-- ============================================================================

local refreshPending
local function refreshState()
    local btn = _G.DragonUI_MerchantSellAllJunkButton
    if not btn or not btn:IsVisible() or refreshPending then return end
    refreshPending = true
    C_Timer.After(0, function()
        refreshPending = false
        if not btn:IsVisible() then return end
        local has = countJunkItems() > 0
        SetDesaturation(btn.Icon, not has)
        if has then btn:Enable() else btn:Disable() end
    end)
end

local function onClick()
    GameTooltip:Hide()
    StaticPopup_Show(POPUP)
end

local function onEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(L["Sell all junk items"])
    GameTooltip:Show()
end

function addon.MerchantSellAllJunkBuild()
    if _G.DragonUI_MerchantSellAllJunkButton or not _G.MerchantFrame then return end

    StaticPopupDialogs[POPUP] = StaticPopupDialogs[POPUP] or {
        text         = L["Sell all of your junk (gray) items?"],
        button1      = YES,
        button2      = NO,
        OnAccept     = sellAllJunk,
        timeout      = 0,
        whileDead    = 1,
        hideOnEscape = 1,
    }

    local btn = CreateFrame("Button", "DragonUI_MerchantSellAllJunkButton", _G.MerchantFrame)
    btn:SetSize(36, 36)
    btn:SetPoint("BOTTOMRIGHT", _G.MerchantFrame, "BOTTOMLEFT", 160, 33)

<<<<<<< HEAD
    local NE = DragonUIWorldMapHost
    local icon = btn:CreateTexture(nil, "BORDER")
    if NE and NE.tex and NE.tex.SetAtlas then
        NE.tex.SetAtlas(icon, "spellicon-256x256-selljunk", false)
    end
=======
    local icon = btn:CreateTexture(nil, "BORDER")
    icon:set_atlas("spellicon-256x256-selljunk", false)
>>>>>>> 816de23 (fix(merchant): retail-accurate vendor window on top of #459)
    icon:SetAllPoints(btn)
    btn.Icon = icon

    btn:SetPushedTexture("Interface\\Buttons\\UI-Quickslot-Depress")
    local hl = btn:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
    hl:SetBlendMode("ADD")
    hl:SetAllPoints(btn)
    btn:SetHighlightTexture(hl)

    btn:SetScript("OnClick", onClick)
    btn:SetScript("OnEnter", onEnter)
    btn:SetScript("OnLeave", GameTooltip_Hide)

    btn:RegisterEvent("MERCHANT_SHOW")
    btn:RegisterEvent("MERCHANT_UPDATE")
    btn:RegisterEvent("BAG_UPDATE")
    btn:SetScript("OnEvent", refreshState)
    btn:SetScript("OnShow", refreshState)
    refreshState()
end
