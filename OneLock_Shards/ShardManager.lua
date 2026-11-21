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
local lastAlertedShardCount = 0

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

    if count <= ((ns.db and ns.db.maxShards) or 24) then
        lastAlertedShardCount = 0
    end

    -- Check if excess alert/cleanup is enabled and cap is exceeded (prevent recursive re-entry)
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
        return
    end

    isCleaningUp = true
    local maxShards = (ns.db and ns.db.maxShards) or 24
    self:ScanBags()

    pendingCleanup = false
    isCleaningUp = false

    if currentShardCount <= maxShards then
        return
    end

    local excessCount = currentShardCount - maxShards

    -- In WoW Forever (Interface 16001 / modern UI baseline), DeleteCursorItem()
    -- is a protected Blizzard API that cannot be called programmatically by addons
    -- without being blocked. We safely alert the player without triggering protected call taint.
    if currentShardCount ~= lastAlertedShardCount then
        lastAlertedShardCount = currentShardCount
        ns:Print(string.format("Soul Shard cap exceeded: |cffffd100%d/%d|r (%d excess). Use |cffffd100/click OneLockPurgeShards|r or Options button to purge.", currentShardCount, maxShards, excessCount))
        ns:Log("WARNING", "ShardManager", string.format("Shard cap exceeded (%d/%d). Automated DeleteCursorItem is protected by Blizzard.", currentShardCount, maxShards))
    end
end

-------------------------------------------------------------------------------
-- 1-Click Hardware Purge Routine & Macro Button (/click OneLockPurgeShards)
-------------------------------------------------------------------------------
function ShardManager:PurgeOneExcessShard()
    if InCombatLockdown() then
        ns:Print("Cannot purge Soul Shards in combat.")
        return false
    end

    -- If an item is already held on the cursor, delete it
    if CursorHasItem() then
        local ok, err = pcall(DeleteCursorItem)
        ClearCursor()
        self:ScanBags()
        if ok then
            ns:Print("Purged item on cursor.")
            return true
        else
            ns:Print("Blizzard engine prevented deletion: " .. tostring(err))
            return false
        end
    end

    local maxShards = (ns.db and ns.db.maxShards) or 24
    local count = self:ScanBags()
    if count <= maxShards then
        ns:Print(string.format("No excess Soul Shards to purge (|cffffd100%d/%d|r).", count, maxShards))
        return false
    end

    -- Find the last excess Soul Shard (highest bag, highest slot)
    local loc = nil
    for i = #self.shardLocations, 1, -1 do
        local candidate = self.shardLocations[i]
        local itemId = GetItemID(candidate.bag, candidate.slot)
        if itemId == SOUL_SHARD_ITEM_ID then
            loc = candidate
            break
        end
    end

    if not loc then return false end

    ClearCursor()
    PickupItem(loc.bag, loc.slot)
    if CursorHasItem() then
        local ok, err = pcall(DeleteCursorItem)
        ClearCursor()
        local newCount = self:ScanBags()
        if ok then
            ns:Print(string.format("Purged 1 excess Soul Shard. Remaining: |cffffd100%d/%d|r.", newCount, maxShards))
            return true
        else
            ns:Print("Blizzard engine prevented deletion: " .. tostring(err))
            return false
        end
    end

    return false
end

local function CreatePurgeButton()
    if _G.OneLockPurgeShards then return end
    local btn = CreateFrame("Button", "OneLockPurgeShards", UIParent, "SecureActionButtonTemplate")
    btn:RegisterForClicks("AnyUp", "AnyDown")
    btn:SetScript("OnClick", function(self)
        ShardManager:PurgeOneExcessShard()
    end)
    ShardManager.purgeButton = btn
end

-------------------------------------------------------------------------------
-- Auto-Sort Soul Shards into Designated Bag Slot
-------------------------------------------------------------------------------
local isSorting = false
local pendingSort = false

function ShardManager:SortShards(explicitTargetBag)
    if InCombatLockdown() then
        pendingSort = true
        return false
    end
    if isSorting then return false end
    if CursorHasItem() then return false end

    local targetBag = explicitTargetBag
    if targetBag == nil then
        targetBag = (ns.db and ns.db.sortTargetBag ~= nil and ns.db.sortTargetBag) or 4
    end
    targetBag = tonumber(targetBag) or 4
    if targetBag < 0 or targetBag > 4 then return false end

    local numSlots = GetNumSlots(targetBag)
    if not numSlots or numSlots == 0 then
        return false
    end

    -- 1. Identify misplaced soul shards not in targetBag
    local misplaced = {}
    for bag = 0, 4 do
        if bag ~= targetBag then
            local slots = GetNumSlots(bag)
            if slots and slots > 0 then
                for slot = 1, slots do
                    local itemId = GetItemID(bag, slot)
                    if itemId == SOUL_SHARD_ITEM_ID then
                        table.insert(misplaced, { bag = bag, slot = slot })
                    end
                end
            end
        end
    end

    if #misplaced == 0 then return false end

    -- 2. Identify empty slots in targetBag
    local emptySlots = {}
    for slot = 1, numSlots do
        local itemId = GetItemID(targetBag, slot)
        if itemId == nil then
            table.insert(emptySlots, slot)
        end
    end

    if #emptySlots == 0 then
        return false
    end

    -- 3. Move misplaced shards into empty slots
    isSorting = true
    local moved = 0
    local toMove = math.min(#misplaced, #emptySlots)

    for i = 1, toMove do
        local src = misplaced[i]
        local destSlot = emptySlots[i]
        ClearCursor()
        PickupItem(src.bag, src.slot)
        if CursorHasItem() then
            PickupItem(targetBag, destSlot)
            ClearCursor()
            moved = moved + 1
        end
    end

    isSorting = false

    if moved > 0 then
        self:ScanBags()
        local bagName = (targetBag == 0 and "Backpack") or ("Bag " .. targetBag)
        ns:Print(string.format("Sorted %d Soul Shard(s) into |cffffd100%s|r.", moved, bagName))
        ns:Log("INFO", "ShardManager", string.format("Sorted %d Soul Shards into bag %d.", moved, targetBag))
        return true
    end

    return false
end

-------------------------------------------------------------------------------
-- Event Handling
-------------------------------------------------------------------------------
function ShardManager:Initialize()
    CreatePurgeButton()

    local eventFrame = CreateFrame("Frame", "OneLock_Shards_ManagerFrame")
    eventFrame:RegisterEvent("BAG_UPDATE")
    eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

    eventFrame:SetScript("OnEvent", function(self, event)
        if event == "BAG_UPDATE" or event == "BAG_UPDATE_DELAYED" then
            ShardManager:ScanBags()
            if event == "BAG_UPDATE_DELAYED" and ns.db and ns.db.autoSortShards and not isSorting and not InCombatLockdown() and not CursorHasItem() then
                ShardManager:SortShards()
            end
        elseif event == "PLAYER_REGEN_ENABLED" then
            if pendingCleanup then
                ShardManager:CleanupExcessShards()
            end
            if pendingSort then
                pendingSort = false
                if ns.db and ns.db.autoSortShards then
                    ShardManager:SortShards()
                end
            end
        end
    end)

    ShardManager.frame = eventFrame
    ShardManager:ScanBags()
    ns:Log("INFO", "ShardManager", "ShardManager initialized with C_Container methods.")
end
