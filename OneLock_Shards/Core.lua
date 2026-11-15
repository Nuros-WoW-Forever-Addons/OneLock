-- ============================================================================
-- OneLock_Shards - Core Scaffold & Configuration
-- Client: WoW Forever Beta (v1.60.1 / Interface 16001)
-- ============================================================================

local addonName, ns = ...
_G.OneLock_Shards = ns

ns.addonName = addonName
ns.version = "0.1.0"

local defaultDB = {
    version = 1,
    maxShards = 24,
    autoDeleteExcess = false,
    showSoulstoneBar = true,
    soulstoneAnchor = {
        point = "BOTTOMLEFT",
        relativePoint = "BOTTOMLEFT",
        x = 250,
        y = 200,
    },
}

function ns:Print(msg)
    local prefix = "|cff9966ff[OneLock:Shards]|r "
    print(prefix .. tostring(msg))
end

local function InitDB()
    if not OneLockShardsDB then
        OneLockShardsDB = {}
    end

    for k, v in pairs(defaultDB) do
        if OneLockShardsDB[k] == nil then
            if type(v) == "table" then
                local copy = {}
                for subK, subV in pairs(v) do
                    copy[subK] = subV
                end
                OneLockShardsDB[k] = copy
            else
                OneLockShardsDB[k] = v
            end
        end
    end

    ns.db = OneLockShardsDB
end

local function HandleSlashCommand(msg)
    msg = msg and msg:trim() or ""
    local cmd, arg = msg:match("^(%S+)%s*(.-)$")
    cmd = cmd and cmd:lower() or ""

    if cmd == "count" then
        if ns.ShardManager and ns.ShardManager.GetShardCount then
            local count = ns.ShardManager:GetShardCount()
            ns:Print(string.format("Soul Shards in inventory: |cffffd100%d|r (Cap: %d)", count, ns.db.maxShards))
        end
    elseif cmd == "cap" then
        local num = tonumber(arg)
        if num and num >= 1 and num <= 32 then
            ns.db.maxShards = num
            ns:Print(string.format("Soul Shard maximum cap set to |cffffd100%d|r.", num))
        else
            ns:Print("Usage: |cffffd100/olshards cap <1 - 32>|r")
        end
    elseif cmd == "autodelete" then
        ns.db.autoDeleteExcess = not ns.db.autoDeleteExcess
        if ns.db.autoDeleteExcess then
            ns:Print("Auto-deletion of excess soul shards |cff44ff44ENABLED|r (Runs out of combat).")
        else
            ns:Print("Auto-deletion of excess soul shards |cffff4444DISABLED|r.")
        end
    elseif cmd == "cleanup" then
        if ns.ShardManager and ns.ShardManager.CleanupExcessShards then
            ns.ShardManager:CleanupExcessShards()
        end
    else
        ns:Print("OneLock Shards commands:")
        print("  |cffffd100/olshards count|r — Print current soul shard count")
        print("  |cffffd100/olshards cap <1-32>|r — Set soul shard inventory cap")
        print("  |cffffd100/olshards autodelete|r — Toggle out-of-combat auto deletion")
        print("  |cffffd100/olshards cleanup|r — Manually delete shards above cap now")
    end
end

local eventFrame = CreateFrame("Frame", "OneLock_Shards_EventFrame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        InitDB()
        if ns.ShardManager and ns.ShardManager.Initialize then
            ns.ShardManager:Initialize()
        end
        if ns.SoulstoneTracker and ns.SoulstoneTracker.Initialize then
            ns.SoulstoneTracker:Initialize()
        end
    elseif event == "PLAYER_LOGIN" then
        ns:Print("Loaded v" .. ns.version .. ". Type |cffffd100/olshards|r for options.")
    end
end)

SLASH_ONELOCKSHARDS1 = "/olshards"
SlashCmdList["ONELOCKSHARDS"] = HandleSlashCommand
