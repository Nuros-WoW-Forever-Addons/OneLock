-- ============================================================================
-- OneLock_Shards - ShardManager
-- Soul Shard inventory tracking and out-of-combat excess deletion (itemID: 6265)
-- Client: WoW Forever Beta (v1.60.1 / Interface 16001)
-- ============================================================================

local addonName, ns = ...
local ShardManager = {}
ns.ShardManager = ShardManager

local SOUL_SHARD_ITEM_ID = 6265
local currentShardCount = 0
local pendingCleanup = false

-------------------------------------------------------------------------------
-- Container API Helpers (C_Container modern engine fallback)
-------------------------------------------------------------------------------
local function GetNumSlots(bagID)
    if C_Container and C_Container.GetContainerNumSlots then
        local ok, count = pcall(C_Container.GetContainerNumSlots, bagID)
        if ok and count then return count end
    end
    if _G.GetContainerNumSlots then
        local ok, count = pcall(_G.GetContainerNumSlots, bagID)
        if ok and count then return count end
    end
    return 0
end

local function GetItemID(bagID, slotID)
    if C_Container and C_Container.GetContainerItemID then
        local ok, id = pcall(C_Container.GetContainerItemID, bagID, slotID)
        if ok and id then return id end
    end
    if _G.GetContainerItemID then
        local ok, id = pcall(_G.GetContainerItemID, bagID, slotID)
        if ok and id then return id end
    end
    return nil
end

local function PickupItem(bagID, slotID)
    if C_Container and C_Container.PickupContainerItem then
        pcall(C_Container.PickupContainerItem, bagID, slotID)
    elseif _G.PickupContainerItem then
        pcall(_G.PickupContainerItem, bagID, slotID)
    end
end

-------------------------------------------------------------------------------
-- Scan Bags for Soul Shards
-------------------------------------------------------------------------------
local isCleaningUp = false

function ShardManager:ScanBags()
    local count = 0
    local shardLocations = {} -- list of { bag = bag, slot = slot }

    -- Bags 0 (backpack) through 4
    for bag = 0, 4 do
        local numSlots = GetNumSlots(bag)
        if numSlots and numSlots > 0 then
            for slot = 1, numSlots do
                local itemId = GetItemID(bag, slot)
                if itemId == SOUL_SHARD_ITEM_ID then
                    count = count + 1
                    table.insert(shardLocations, { bag = bag, slot = slot })
                end
            end
        end
    end

    currentShardCount = count
    ShardManager.shardLocations = shardLocations

    -- Check if auto-cleanup is enabled and cap is exceeded (prevent recursive re-entry)
    local maxShards = (ns.db and ns.db.maxShards) or 24
    if not isCleaningUp and ns.db and ns.db.autoDeleteExcess and count > maxShards then
        self:QueueCleanup()
    end

    return count
end

function ShardManager:GetShardCount()
    return currentShardCount
end

-------------------------------------------------------------------------------
-- Out-of-Combat Excess Deletion Loop
-------------------------------------------------------------------------------
function ShardManager:QueueCleanup()
    if InCombatLockdown() then
        pendingCleanup = true
    else
        self:CleanupExcessShards()
    end
end

function ShardManager:CleanupExcessShards()
    if isCleaningUp then return end
    if InCombatLockdown() then
        pendingCleanup = true
        ns:Print("Cannot delete soul shards during combat. Scheduled for combat end.")
        return
    end

    isCleaningUp = true
    local maxShards = (ns.db and ns.db.maxShards) or 24
    self:ScanBags()

    if currentShardCount <= maxShards then
        pendingCleanup = false
        isCleaningUp = false
        return
    end

    local excessCount = currentShardCount - maxShards
    local deleted = 0

    -- Delete from highest bag down (secondary bags before backpack)
    for i = #ShardManager.shardLocations, 1, -1 do
        if deleted >= excessCount then break end

        local loc = ShardManager.shardLocations[i]
        local itemId = GetItemID(loc.bag, loc.slot)
        if itemId == SOUL_SHARD_ITEM_ID then
            ClearCursor()
            PickupItem(loc.bag, loc.slot)
            if CursorHasItem() then
                DeleteCursorItem()
                deleted = deleted + 1
            end
        end
    end

    pendingCleanup = false
    isCleaningUp = false
    ns:Print(string.format("Purged |cffffd100%d|r excess Soul Shard(s). Current count: %d", deleted, currentShardCount - deleted))
    ns:Log("INFO", "ShardManager", string.format("Deleted %d excess Soul Shards (Remaining: %d)", deleted, currentShardCount - deleted))
end

-------------------------------------------------------------------------------
-- Event Handling
-------------------------------------------------------------------------------
function ShardManager:Initialize()
    local eventFrame = CreateFrame("Frame", "OneLock_Shards_ManagerFrame")
    eventFrame:RegisterEvent("BAG_UPDATE")
    eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

    eventFrame:SetScript("OnEvent", function(self, event)
        if event == "BAG_UPDATE" or event == "BAG_UPDATE_DELAYED" then
            ShardManager:ScanBags()
        elseif event == "PLAYER_REGEN_ENABLED" then
            if pendingCleanup then
                ShardManager:CleanupExcessShards()
            end
        end
    end)

    ShardManager.frame = eventFrame
    ShardManager:ScanBags()
    ns:Log("INFO", "ShardManager", "ShardManager initialized with C_Container methods.")
end
