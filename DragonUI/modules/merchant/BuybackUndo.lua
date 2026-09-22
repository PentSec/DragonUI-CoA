<<<<<<< HEAD
-- DragonUI/modules/merchant/BuybackUndo.lua — retail's buyback undo arrow.
--
-- DOWNPORT of NewEra/MerchantFrame/BuybackUndo.lua, adapted for DragonUI.
-- Retail nests an UndoFrame inside the merchant tab's buyback slot with a
-- `common-icon-undo` arrow at CENTER, desaturated while GetNumBuybackItems() == 0.
=======
-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.
-- Buyback undo arrow on the vendor window's buyback slot.
>>>>>>> 816de23 (fix(merchant): retail-accurate vendor window on top of #459)

local addon = select(2, ...)

local arrowTex

local function refreshDesaturation()
    SetDesaturation(arrowTex, GetNumBuybackItems() == 0)
end

function addon.MerchantBuybackUndoBuild()
    local itemBtn = _G.MerchantBuyBackItemItemButton
    if not itemBtn or itemBtn.UndoFrame then return end

    local undo = CreateFrame("Frame", nil, itemBtn)
    undo:SetAllPoints(itemBtn)
    undo:SetFrameLevel(itemBtn:GetFrameLevel() + 2)

<<<<<<< HEAD
    local NE = DragonUIWorldMapHost
    local tex = undo:CreateTexture(nil, "ARTWORK")
    if NE and NE.tex and NE.tex.SetAtlas and NE.tex.SetAtlas(tex, "common-icon-undo", false) then
        tex:SetSize(20, 20)
        tex:SetPoint("CENTER", 0, -1)
        arrowTex = tex
        undo.Arrow = tex
        itemBtn.UndoFrame = undo
        itemBtn._duiUndoBuilt = true
        refreshDesaturation()
=======
    arrowTex = undo:CreateTexture(nil, "ARTWORK")
    arrowTex:set_atlas("common-icon-undo", false)
    arrowTex:SetSize(20, 20)
    arrowTex:SetPoint("CENTER", 0, -1)
    undo.Arrow = arrowTex
    itemBtn.UndoFrame = undo
>>>>>>> 816de23 (fix(merchant): retail-accurate vendor window on top of #459)

    refreshDesaturation()
    hooksecurefunc("MerchantFrame_Update", refreshDesaturation)
end
