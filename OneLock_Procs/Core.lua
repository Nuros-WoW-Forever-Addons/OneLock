-- ============================================================================
-- OneLock_Procs - Core Scaffold & Configuration
-- Client: WoW Forever Beta (v1.60.1 / Interface 16001)
-- ============================================================================

local addonName, ns = ...
_G.OneLock_Procs = ns

ns.addonName = addonName
ns.version = "0.1.0"

local defaultDB = {
    version = 1,
    enableNightfall = true,
    enableBacklash = true,
    enableImmunityAlert = true,
    playAudio = true,
    alertScale = 1.2,
}

function ns:Print(msg)
    local prefix = "|cff9966ff[OneLock:Procs]|r "
    print(prefix .. tostring(msg))
end

local function InitDB()
    if not OneLockProcsDB then
        OneLockProcsDB = {}
    end

    for k, v in pairs(defaultDB) do
        if OneLockProcsDB[k] == nil then
            if type(v) == "table" then
                local copy = {}
                for subK, subV in pairs(v) do
                    copy[subK] = subV
                end
                OneLockProcsDB[k] = copy
            else
                OneLockProcsDB[k] = v
            end
        end
    end

    ns.db = OneLockProcsDB
end

local function HandleSlashCommand(msg)
    msg = msg and msg:trim() or ""
    local cmd, arg = msg:match("^(%S+)%s*(.-)$")
    cmd = cmd and cmd:lower() or ""

    if cmd == "test" then
        if ns.Alerts and ns.Alerts.TriggerTestAlert then
            ns.Alerts:TriggerTestAlert()
            ns:Print("Triggered test proc alert.")
        end
    elseif cmd == "sound" then
        ns.db.playAudio = not ns.db.playAudio
        if ns.db.playAudio then
            ns:Print("Proc audio alerts |cff44ff44ENABLED|r.")
        else
            ns:Print("Proc audio alerts |cffff4444DISABLED|r.")
        end
    elseif cmd == "nightfall" then
        ns.db.enableNightfall = not ns.db.enableNightfall
        ns:Print("Nightfall alerts: " .. (ns.db.enableNightfall and "|cff44ff44ON|r" or "|cffff4444OFF|r"))
    elseif cmd == "backlash" then
        ns.db.enableBacklash = not ns.db.enableBacklash
        ns:Print("Backlash alerts: " .. (ns.db.enableBacklash and "|cff44ff44ON|r" or "|cffff4444OFF|r"))
    elseif cmd == "immunity" then
        ns.db.enableImmunityAlert = not ns.db.enableImmunityAlert
        ns:Print("Immunity alerts: " .. (ns.db.enableImmunityAlert and "|cff44ff44ON|r" or "|cffff4444OFF|r"))
    else
        ns:Print("OneLock Procs commands:")
        print("  |cffffd100/olprocs test|r — Trigger a test proc alert banner")
        print("  |cffffd100/olprocs sound|r — Toggle alert sound effects")
        print("  |cffffd100/olprocs nightfall|r — Toggle Shadow Trance alerts")
        print("  |cffffd100/olprocs backlash|r — Toggle Backlash alerts")
        print("  |cffffd100/olprocs immunity|r — Toggle CC immunity alerts")
    end
end

local eventFrame = CreateFrame("Frame", "OneLock_Procs_EventFrame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        InitDB()
        if ns.Alerts and ns.Alerts.Initialize then
            ns.Alerts:Initialize()
        end
    elseif event == "PLAYER_LOGIN" then
        ns:Print("Loaded v" .. ns.version .. ". Type |cffffd100/olprocs|r for options.")
    end
end)

SLASH_ONELOCKPROCS1 = "/olprocs"
SlashCmdList["ONELOCKPROCS"] = HandleSlashCommand
