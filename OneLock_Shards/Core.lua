-- ============================================================================
-- OneLock_Shards - Core Scaffold & Configuration
-- Client: WoW Forever Beta (v1.60.1 / Interface 16001)
-- ============================================================================

local addonName, ns = ...
_G.OneLock_Shards = ns

ns.addonName = addonName
ns.version = "0.1.11"

local defaultDB = {
    version = 2,
    maxShards = 24,
    autoDeleteExcess = false,
    showSoulstoneBar = true,
    enableSoulstoneAlerts = true,
    announceSoulstone = true,
    locked = false,                     -- Movable by default
    soulstoneWidth = 180,
    soulstoneScale = 1.0,
    position = {
        point = "BOTTOMLEFT",
        relativePoint = "BOTTOMLEFT",
        x = 250,
        y = 200,
    },
}

local function GetOneAddonChatFrame()
    local targetName = "OneAddon"
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local name = GetChatWindowInfo(i)
        if name == targetName or name == "OneAddons" then
            local cf = _G["ChatFrame" .. i]
            if cf then
                local tab = _G["ChatFrame" .. i .. "Tab"]
                if tab then
                    tab:Show()
                    if PanelTemplates_TabResize then
                        pcall(PanelTemplates_TabResize, tab, 0)
                    end
                end
                return cf
            end
        end
    end
    if FCF_OpenNewWindow then
        local frame = FCF_OpenNewWindow(targetName)
        if frame then
            if FCF_DockFrame and GENERAL_CHAT_DOCK then
                local docked = (FCFDock_GetChatFrames and FCFDock_GetChatFrames(GENERAL_CHAT_DOCK)) or (GENERAL_CHAT_DOCK and GENERAL_CHAT_DOCK.DOCKED_CHAT_FRAMES) or {}
                pcall(FCF_DockFrame, frame, #docked + 1, false)
            end
            if ChatFrame_RemoveAllMessageGroups then pcall(ChatFrame_RemoveAllMessageGroups, frame) end
            if ChatFrame_RemoveAllChannels then pcall(ChatFrame_RemoveAllChannels, frame) end
            if FCF_DockUpdate then pcall(FCF_DockUpdate) end
            local id = frame.GetID and frame:GetID()
            if id then
                local tab = _G["ChatFrame" .. id .. "Tab"]
                if tab then
                    tab:Show()
                    if PanelTemplates_TabResize then pcall(PanelTemplates_TabResize, tab, 0) end
                end
            end
            if FCF_SelectDockFrame and DEFAULT_CHAT_FRAME then pcall(FCF_SelectDockFrame, DEFAULT_CHAT_FRAME) end
            return frame
        end
    end
    return DEFAULT_CHAT_FRAME or ChatFrame1
end

function ns:Print(msg)
    local frame = GetOneAddonChatFrame()
    local prefix = "|cff9966ff[OneLock:Shards]|r "
    local text = prefix .. tostring(msg)
    if frame and frame.AddMessage then
        frame:AddMessage(text)
    elseif DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(text)
    else
        print(text)
    end
end

function ns:Log(level, category, message, extraData)
    if _G.OneSwatter and _G.OneSwatter.Log then
        _G.OneSwatter:Log(addonName, level, category, message, extraData)
    end
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

    if cmd == "" or cmd == "options" or cmd == "config" or cmd == "gui" then
        if _G.OneLock_Timers and _G.OneLock_Timers.ToggleOptionsUI then
            _G.OneLock_Timers.ToggleOptionsUI()
        end
    elseif cmd == "count" then
        if ns.ShardManager and ns.ShardManager.GetShardCount then
            local count = ns.ShardManager:GetShardCount()
            ns:Print(string.format("Soul Shards in inventory: |cffffd100%d|r (Cap: %d)", count, ns.db.maxShards))
            ns:Log("INFO", "Commands", "Shard count query: " .. tostring(count))
        end
    elseif cmd == "cap" then
        local num = tonumber(arg)
        if num and num >= 1 and num <= 32 then
            ns.db.maxShards = num
            ns:Print(string.format("Soul Shard maximum cap set to |cffffd100%d|r.", num))
            ns:Log("INFO", "Settings", "Soul Shard cap set to " .. tostring(num))
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
        ns:Log("INFO", "Settings", "Auto-delete toggled: " .. tostring(ns.db.autoDeleteExcess))
    elseif cmd == "cleanup" then
        if ns.ShardManager and ns.ShardManager.CleanupExcessShards then
            ns.ShardManager:CleanupExcessShards()
        end
    elseif cmd == "move" or cmd == "lock" or cmd == "unlock" then
        if ns.SoulstoneTracker and ns.SoulstoneTracker.ToggleLock then
            local isLocked = ns.SoulstoneTracker:ToggleLock()
            ns:Print("Soulstone HUD " .. (isLocked and "|cffff4444LOCKED (Hidden)|r." or "|cff44ff44UNLOCKED (Move Purple Box)|r."))
        end
    elseif cmd == "reset" then
        if ns.SoulstoneTracker and ns.SoulstoneTracker.ResetPosition then
            ns.SoulstoneTracker:ResetPosition()
            ns:Print("Reset Soulstone HUD position to default.")
        end
    elseif cmd == "test" then
        if ns.SoulstoneTracker and ns.SoulstoneTracker.ToggleTestMode then
            local active = ns.SoulstoneTracker:ToggleTestMode()
            ns:Print("Simulated Soulstone bar " .. (active and "|cff44ff44ENABLED|r." or "|cffff4444DISABLED|r."))
        end
    elseif cmd == "clear" then
        if ns.SoulstoneTracker and ns.SoulstoneTracker.ClearSoulstone then
            ns.SoulstoneTracker:ClearSoulstone()
        end
    else
        ns:Print("OneLock Shards commands:")
        print("  |cffffd100/olshards move|r — Toggle purple edit-mode box to position Soulstone HUD")
        print("  |cffffd100/olshards test|r — Toggle simulated Soulstone bar preview")
        print("  |cffffd100/olshards clear|r — Clear active Soulstone tracking bar")
        print("  |cffffd100/olshards reset|r — Reset Soulstone HUD position")
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
        ns:Log("INFO", "Core", "OneLock_Shards v" .. ns.version .. " initialized.")
    elseif event == "PLAYER_LOGIN" then
        ns:Print("Loaded v" .. ns.version .. ". Type |cffffd100/olshards|r for options.")
    end
end)

SLASH_ONELOCKSHARDS1 = "/olshards"
SlashCmdList["ONELOCKSHARDS"] = HandleSlashCommand
