-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local CP = addon.CharacterPanel

local MODEL_W, MODEL_H = 231, 320
local VANILLA_W, VANILLA_H = 233, 215
local VANILLA_X, VANILLA_Y = 65, -78

-- Blizzard's own DressUpTexturePath applies this same fallback: the 3.3.5a client ships no
-- Gnome or Troll backdrop art.
local RACE_FALLBACK = { GNOME = "DWARF", TROLL = "ORC" }

-- Lifted far enough to run past the art's last row, so their bottom pair ships rebuilt to row 127.
local FLOOR = { BLOODELF = true, DRAENEI = true, NIGHTELF = true, SCOURGE = true, TAUREN = true }
local FLOOR_ART = addon._dir .. "CharacterPanel\\RaceBackground\\"

local function artRace(fileName)
    if not fileName then return "ORC" end
    local upper = strupper(fileName)
    return RACE_FALLBACK[upper] or upper
end

local function artPath(fileName, suffix)
    local race = artRace(fileName)
    if suffix >= 3 and FLOOR[race] then return FLOOR_ART .. strlower(race) .. "-floor" .. suffix end
    return "Interface\\DressUpFrame\\DressUpBackground-" .. race .. suffix
end

-- How dark retail's paperdoll shades each race's art.
local SHADE_BY_RACE = {
    BLOODELF = 0.8, SCOURGE = 0.3, WORGEN = 0.5,
    NIGHTELF = 0.6, ORC = 0.6, TROLL = 0.6, GOBLIN = 0.6,
}
local SHADE_DEFAULT = 0.7

-- Retail's viewport sits at (52, -66) of the frame and the Inset starts at (4, -60).
local FROM_INSET_X, FROM_INSET_Y = 48, -6

local function resizeViewport()
    local viewport, owner = _G.CharacterModelFrame, _G.CharacterFrame
    local inset = owner and owner.Inset
    if viewport == nil or inset == nil or viewport._duiResized then return end

    viewport._duiResized = true
    viewport:SetSize(MODEL_W, MODEL_H)
    viewport:ClearAllPoints()
    viewport:SetPoint("TOPLEFT", inset, "TOPLEFT", FROM_INSET_X, FROM_INSET_Y)
end

-- The backdrop grid is retail's 212x245 / 231x320 split; keeping the ratios lets the same art
-- scale to any model viewport (Conquest of Azeroth's) while staying continuous across the seams.
local X_SPLIT, Y_SPLIT = 212 / 231, 245 / 320

-- Cropped to the viewport: 245 + 75 = 320, the model's exact height. Retail runs the bottom pair
-- their full 128, which made the strip under the model depend on that overhang drawing.
local BOTTOM_CROP = 75 / 128
local QUARTERS = {
    { key = "TopLeft", suffix = 1, w = 212, h = 245, tc = { 0.171875, 1, 0.0392156862745098, 1 },
      point = "TOPLEFT", rel = "TOPLEFT" },
    { key = "TopRight", suffix = 2, w = 19, h = 245, tc = { 0, 0.296875, 0.0392156862745098, 1 },
      point = "TOPLEFT", rel = "TOPRIGHT" },
    { key = "BotLeft", suffix = 3, w = 212, h = 75, tc = { 0.171875, 1, 0, BOTTOM_CROP },
      point = "TOPLEFT", rel = "BOTTOMLEFT" },
    { key = "BotRight", suffix = 4, w = 19, h = 75, tc = { 0, 0.296875, 0, BOTTOM_CROP },
      point = "TOPLEFT", rel = "BOTTOMRIGHT" },
}
CP.MODEL_W, CP.MODEL_H = MODEL_W, MODEL_H

-- Down uses the top pair's 10 cropped rows; up past 0 needs a FLOOR race's rebuilt rows.
local LIFT_MIN, LIFT_MAX = -10, 53

local RACE_LIFT = {
    BLOODELFF = 25, BLOODELFM = 34, DRAENEIF = 7, DRAENEIM = 7, DWARFF = -10, DWARFM = -10,
    GNOMEF = -10, GNOMEM = -10, HUMANF = 1, HUMANM = 1, NIGHTELFF = 29, NIGHTELFM = 30,
    ORCM = 1, SCOURGEF = 13, SCOURGEM = 13, TAURENF = 21, TAURENM = 21,
}

local function shadeFor(fileName)
    return SHADE_BY_RACE[artRace(fileName)] or SHADE_DEFAULT
end

function CP.RaceLiftKey(fileName, sex)
    return strupper(fileName or "ORC") .. (sex == 3 and "F" or "M")
end

function CP.RaceBackdropLift(key)
    return math.max(LIFT_MIN, math.min(LIFT_MAX, RACE_LIFT[key] or 0))
end

-- Slides the art up `lift` px and keeps the 320 total by trading top rows for bottom ones.
-- `scale` is the viewport's height over 320, so a viewport that is not retail's keeps the same
-- proportions; the texcoords stay in the art's own pixel rows either way.
local function layoutQuarters(bySuffix, lift, scale)
    scale = scale or 1
    for _, q in ipairs(QUARTERS) do
        local piece = bySuffix[q.suffix]
        if piece then
            if q.suffix <= 2 then
                piece:SetHeight((q.h - lift) * scale)
                piece:SetTexCoord(q.tc[1], q.tc[2], q.tc[3] + lift / 256, 1)
            else
                piece:SetHeight((q.h + lift) * scale)
                piece:SetTexCoord(q.tc[1], q.tc[2], 0, (q.h + lift) / 128)
            end
        end
    end
end

-- Shared with the inspect window, which paints other units' races.
function CP.PaintRaceBackdrop(bySuffix, shade, fileName, sex, scale)
    -- Plain truth test: the pre-database config is {}, and a missing key must read as colour.
    local desaturate = CP:Config().grey_model_backdrop and true or false
    for suffix, piece in pairs(bySuffix) do
        piece:SetTexture(artPath(fileName, suffix))
        piece:SetDesaturated(desaturate)
        piece:Show()
    end
    if shade then
        shade:SetAlpha(desaturate and shadeFor(fileName) or 0)
        shade:Show()
    end
    layoutQuarters(bySuffix, CP.RaceBackdropLift(CP.RaceLiftKey(fileName, sex)), scale)
end

local function addQuarter(viewport, entry, relativeTo, w, h)
    local piece = viewport:CreateTexture(nil, "BACKGROUND")
    local coords = entry.tc
    piece:SetWidth(w)
    piece:SetHeight(h)
    piece:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    piece:SetPoint(entry.point, relativeTo, entry.rel, 0, 0)
    return piece
end

-- One column split and one row split for every quarter: the left column is the wide piece and the
-- right one takes the remainder, so the four pieces always sum to the viewport exactly.
local function quarterSize(entry, w, h, qw, qh)
    if entry.key == "TopLeft" then return qw, qh end
    if entry.key == "TopRight" then return w - qw, qh end
    if entry.key == "BotLeft" then return qw, h - qh end
    return w - qw, h - qh
end

-- Returns the quarters by file suffix, the shade and the vertical scale, for any viewport.
-- The third value is what layoutQuarters needs to keep lift and heights proportional on a viewport
-- that is not retail's 231x320 (Conquest of Azeroth's own model frames).
function CP.CreateRaceBackdrop(viewport)
    if viewport == nil then return end

    -- Every other quarter anchors to the top-left one, so it is made before the rest.
    local anchorEntry
    for _, entry in ipairs(QUARTERS) do
        if entry.key == "TopLeft" then anchorEntry = entry break end
    end
    if not anchorEntry then return end

    local w, h = viewport:GetWidth() or 0, viewport:GetHeight() or 0
    if w == 0 then w = MODEL_W end
    if h == 0 then h = MODEL_H end
    local qw, qh = math.floor(w * X_SPLIT + 0.5), math.floor(h * Y_SPLIT + 0.5)

    local bySuffix = {}
    local pw, ph = quarterSize(anchorEntry, w, h, qw, qh)
    local anchorPiece = addQuarter(viewport, anchorEntry, viewport, pw, ph)
    bySuffix[anchorEntry.suffix] = anchorPiece
    for _, entry in ipairs(QUARTERS) do
        if entry ~= anchorEntry then
            local ew, eh = quarterSize(entry, w, h, qw, qh)
            bySuffix[entry.suffix] = addQuarter(viewport, entry, anchorPiece, ew, eh)
        end
    end

    -- Held to the viewport's corner, not the art's, so the shade ends exactly where the model does.
    local shade = viewport:CreateTexture(nil, "BORDER")
    shade:SetPoint("BOTTOMRIGHT", viewport)
    shade:SetPoint("TOPLEFT", anchorPiece)
    shade:SetTexture(0, 0, 0)
    shade:SetAlpha(0)
    return bySuffix, shade, h / MODEL_H
end

local function createBackdrop()
    local viewport = _G.CharacterModelFrame
    if viewport == nil or viewport._duiRaceBg then return end
    viewport._duiRaceBg, viewport._duiRaceBgOverlay, viewport._duiRaceBgScale = CP.CreateRaceBackdrop(viewport)
end

-- The Inspect window keeps its shade on `_duiRaceBgShade`; both fields are the same texture.
local function shadeOf(viewport)
    return viewport._duiRaceBgShade or viewport._duiRaceBgOverlay
end

-- `unit` lets the Conquest of Azeroth skin paint the same backdrop on its own viewport, which shows
-- the *target* rather than the player; the character model defaults to "player" like Blizzard's.
local function paintBackdrop(unit, viewport)
    viewport = viewport or _G.CharacterModelFrame
    if not (viewport and viewport._duiRaceBg) then return end

    unit = unit or "player"
    local _, fileName = UnitRace(unit)
    CP.PaintRaceBackdrop(viewport._duiRaceBg, shadeOf(viewport), fileName, UnitSex(unit),
        viewport._duiRaceBgScale)
end

CP.ApplyModelBackdrop = paintBackdrop

-- Shared with the Conquest of Azeroth skin, which builds the backdrop on its own model viewport; the
-- Inspect passes its unit ("target") so the art reads that target's race, not the player's.
function CP.BuildModelBackdrop(viewport, unit)
    viewport = viewport or _G.CharacterModelFrame
    if viewport == nil then return end
    if not viewport._duiRaceBg then
        viewport._duiRaceBg, viewport._duiRaceBgOverlay, viewport._duiRaceBgScale =
            CP.CreateRaceBackdrop(viewport)
    end
    if not viewport._duiRaceBg then return end
    paintBackdrop(unit, viewport)
end

-- Blizzard anchors the viewport in XML only; nothing else undoes our placement without a reload.
function CP.RestoreModel()
    local model = _G.CharacterModelFrame
    if not model then return end
    model._duiResized = nil

    model:SetSize(VANILLA_W, VANILLA_H)
    model:ClearAllPoints()
    model:SetPoint("TOPLEFT", model:GetParent(), "TOPLEFT", VANILLA_X, VANILLA_Y)

    if model._duiRaceBg then
        for _, tex in pairs(model._duiRaceBg) do tex:Hide() end
    end
    if model._duiRaceBgOverlay then model._duiRaceBgOverlay:Hide() end
end

-- The art hangs off the viewport, so the viewport has to be at its final size first.
local function build()
    resizeViewport()
    createBackdrop()
    paintBackdrop()
end

CP.RefreshRaceBackground = CP.ApplyModelBackdrop

CP:RegisterBuilder("model", build)
