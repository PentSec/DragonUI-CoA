-- =============================================================================
-- Transmog Collector Module
-- Automatically collects transmog appearances when looting new items.
-- Uses C_AppearanceCollection.CollectItemAppearance(guid) (Conquest of Azeroth API).
-- =============================================================================

local addon = select(2, ...)
local L = addon.L

local TransmogCollector = {
    applied = false,
}

if addon.RegisterModule then
    addon:RegisterModule("transmog_collector", TransmogCollector,
        "Transmog Collector",
        "Automatically collect new transmog appearances when looting items.",
        {
            lifecycle = {
                apply   = "ApplyTransmogCollectorSystem",
                restore = "RestoreTransmogCollectorSystem",
                refresh = "RefreshTransmogCollectorSystem",
            },
        })
end

-- =============================================================================
-- MODULE STATE
-- =============================================================================

local function IsModuleEnabled()
    return addon:IsModuleEnabled("transmog_collector")
end

-- =============================================================================
-- SELF-INITIALIZATION
-- =============================================================================

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "DragonUI" then
        if not IsModuleEnabled() then return end

        addon:After(0.5, function()
            if addon.db and addon.db.RegisterCallback then
                addon.db.RegisterCallback(addon, "OnProfileChanged", function()
                    addon.RefreshTransmogCollectorSystem()
                end)
            end
        end)

    elseif event == "PLAYER_ENTERING_WORLD" then
        if not IsModuleEnabled() then return end
        addon.ApplyTransmogCollectorSystem()
    end
end)

-- =============================================================================
-- INTERNAL STATE
-- =============================================================================

local eventFrame          -- BAG_UPDATE listener
local scanQueue     = {} -- {bag, slot} entries pending scan
local isScanning    = false
local knownCache    = {} -- { [guid] = true } GUIDs already resolved this session
local lastBagScan   = 0  -- timestamp of last ScanBags to throttle rapid BAG_UPDATE

-- =============================================================================
-- BAG SCANNER
-- =============================================================================

--- Localized class names of the only four item classes that can hold a
--- transmogrification: Weapon, Armor, Container and Consumable (the first four
--- entries of GetAuctionItemClasses). Built lazily on first use so the names are
--- already localized, and memoized because this runs once per bag slot.
local TRANSMOG_ITEM_CLASSES
local function GetTransmogItemClasses()
    if not TRANSMOG_ITEM_CLASSES then
        local classes = { GetAuctionItemClasses() }
        TRANSMOG_ITEM_CLASSES = {}
        for i = 1, 4 do
            local className = classes[i]
            if className then
                TRANSMOG_ITEM_CLASSES[className] = true
            end
        end
    end
    return TRANSMOG_ITEM_CLASSES
end

--- Check if an item can be transmog-collected (matches Conquest of Azeroth macro filter).
--- GetItemInfo's 3rd return is `quality` in 3.3.5a (name, link, quality, iLevel,
--- reqLevel, class, ...) — it is NOT a class id, and reading it as one silently
--- matched nearly every item in the game. Return 6 is the localized class name in
--- both 3.3.5a and retail/CoA, which makes it the only position safe to trust on
--- both clients. Same pattern as bags_usability.lua.
--- If item info isn't cached yet, still try collection.
local function IsCollectableItem(itemID)
    if not itemID then return false end
    local className = select(6, GetItemInfo(itemID))
    if not className then return true end  -- not cached, try anyway
    return GetTransmogItemClasses()[className] == true
end

--- Check if the Conquest of Azeroth collection API is available.
local function IsCollectionAvailable()
    return C_AppearanceCollection
        and type(C_AppearanceCollection.CollectItemAppearance) == "function"
end

local function ScanQueueProcessor()
    if not TransmogCollector.applied then return end
    if #scanQueue == 0 then
        isScanning = false
        return
    end

    local entry = tremove(scanQueue, 1)
    local bag = entry.bag
    local slot = entry.slot
    local guid = GetContainerItemGUID(bag, slot)

    -- Skip if no GUID or already resolved this session
    if not guid or knownCache[guid] then
        addon:After(0, ScanQueueProcessor)
        return
    end

    local itemID = GetContainerItemID(bag, slot)

    -- Only cache once the API is confirmed available. Items seen before
    -- Conquest of Azeroth's C_AppearanceCollection loads stay uncached and are retried on
    -- a later scan, rather than being marked 'processed' and skipped forever.
    if IsCollectionAvailable() then
        -- Mark BEFORE calling to prevent re-entry; API is server-idempotent.
        -- Cached even when not collectable: a false from IsCollectableItem means the
        -- item class is already known and is not one of Weapon/Armor/Container/
        -- Consumable (e.g. trade goods), so it can never become collectable. Caching
        -- it keeps ScanBags from re-queueing it every cycle.
        knownCache[guid] = true

        if IsCollectableItem(itemID) then
            C_AppearanceCollection.CollectItemAppearance(guid)
        end
    end

    -- Throttle: 0.2s between API calls to avoid freezing during bulk crafts
    addon:After(0.2, ScanQueueProcessor)
end

--- Scan all bag slots for new items and queue them for processing.
--- Uses a cooldown to prevent rapid re-scans during profession crafting.
local function ScanBags()
    if not TransmogCollector.applied then return end
    if isScanning then return end

    -- 1-second cooldown between scans to prevent thrashing during bulk crafts
    local now = GetTime()
    if now - lastBagScan < 1.0 then return end
    lastBagScan = now

    isScanning = true

    for bag = 0, NUM_BAG_SLOTS or 4 do
        local numSlots = GetContainerNumSlots(bag)
        if numSlots then
            for slot = 1, numSlots do
                local itemID = GetContainerItemID(bag, slot)
                if itemID then
                    local guid = GetContainerItemGUID(bag, slot)
                    -- Skip items already resolved this session
                    if guid and not knownCache[guid] then
                        tinsert(scanQueue, {bag = bag, slot = slot})
                    end
                end
            end
        end
    end

    if #scanQueue > 0 then
        addon:After(0.1, ScanQueueProcessor)
    else
        isScanning = false
    end
end

-- =============================================================================
-- EVENT HANDLER
-- =============================================================================

local function OnEvent(self, event, ...)
    if not IsModuleEnabled() then return end
    if event == "BAG_UPDATE" then
        -- Delay slightly to let bag settle after loot
        addon:After(0.3, ScanBags)
    end
end

-- =============================================================================
-- LIFECYCLE
-- =============================================================================

function addon.ApplyTransmogCollectorSystem()
    if TransmogCollector.applied then return end
    TransmogCollector.applied = true

    if not eventFrame then
        eventFrame = CreateFrame("Frame")
        eventFrame:SetScript("OnEvent", OnEvent)
    end
    eventFrame:RegisterEvent("BAG_UPDATE")

    -- Initial scan: process all items in bags
    if IsCollectionAvailable() then
        addon:After(0.5, ScanBags)
    end
end

function addon.RestoreTransmogCollectorSystem()
    TransmogCollector.applied = false

    if eventFrame then
        eventFrame:UnregisterEvent("BAG_UPDATE")
    end

    wipe(scanQueue)
    wipe(knownCache)
    isScanning = false
    lastBagScan = 0
end

function addon.RefreshTransmogCollectorSystem()
    if TransmogCollector.applied then
        addon.RestoreTransmogCollectorSystem()
        addon.ApplyTransmogCollectorSystem()
    elseif IsModuleEnabled() then
        addon.ApplyTransmogCollectorSystem()
    end
end
