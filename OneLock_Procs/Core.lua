-- ============================================================================
-- OneLock_Procs - Core Scaffold & Configuration
-- Client: WoW Forever Beta (v1.60.1 / Interface 16001)
-- ============================================================================

local addonName, ns = ...
_G.OneLock_Procs = ns

ns.addonName = addonName
ns.version = "0.1.1"

local defaultDB = {
    version = 2,
    locked = true,                      -- Default locked (shadow box hidden until edit mode)
    enableNightfall = true,
    enableBacklash = true,
    enableImmunityAlert = true,
    playAudio = true,
    alertWidth = 240,                   -- Banner width (160 - 360)
    alertScale = 1.2,                   -- Frame scale (0.8 - 2.0)
    soundIndex = 1,                     -- Index into SOUND_OPTIONS
    soundId = 8959,                     -- SoundKit ID (Alarm Clock Warning 3)
    position = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 180,
    },
}

function ns:Print(msg)
    local prefix = "|cff9966ff[OneLock:Procs]|r "
    print(prefix .. tostring(msg))
end

function ns:Log(level, category, message, extraData)
    if _G.OneSwatter and _G.OneSwatter.Log then
        _G.OneSwatter:Log(addonName, level, category, message, extraData)
    end
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

    if cmd == "" or cmd == "options" or cmd == "config" or cmd == "gui" then
        if _G.OneLock_Timers and _G.OneLock_Timers.ToggleOptionsUI then
            _G.OneLock_Timers.ToggleOptionsUI()
        end
    elseif cmd == "test" then
        if ns.Alerts and ns.Alerts.TriggerTestAlert then
            ns.Alerts:TriggerTestAlert()
            ns:Print("Triggered test proc alert.")
            ns:Log("DEBUG", "Commands", "Triggered test alert.")
        end
    elseif cmd == "lock" or cmd == "unlock" or cmd == "move" then
        if ns.Alerts and ns.Alerts.ToggleLock then
            local isLocked = ns.Alerts:ToggleLock()
            ns:Print("Alert banner " .. (isLocked and "|cffff4444LOCKED (Hidden)|r." or "|cff44ff44UNLOCKED (Move Purple Box)|r."))
        end
    elseif cmd == "reset" then
        if ns.Alerts and ns.Alerts.ResetAnchorPosition then
            ns.Alerts:ResetAnchorPosition()
            ns:Print("Reset proc alert banner position to center.")
        end
    elseif cmd == "sound" then
        ns.db.playAudio = not ns.db.playAudio
        if ns.db.playAudio then
            ns:Print("Proc audio alerts |cff44ff44ENABLED|r.")
        else
            ns:Print("Proc audio alerts |cffff4444DISABLED|r.")
        end
        ns:Log("INFO", "Settings", "Audio alerts toggled: " .. tostring(ns.db.playAudio))
    elseif cmd == "nightfall" then
        ns.db.enableNightfall = not ns.db.enableNightfall
        ns:Print("Nightfall alerts: " .. (ns.db.enableNightfall and "|cff44ff44ON|r" or "|cffff4444OFF|r"))
        ns:Log("INFO", "Settings", "Nightfall alerts toggled: " .. tostring(ns.db.enableNightfall))
    elseif cmd == "backlash" then
        ns.db.enableBacklash = not ns.db.enableBacklash
        ns:Print("Backlash alerts: " .. (ns.db.enableBacklash and "|cff44ff44ON|r" or "|cffff4444OFF|r"))
        ns:Log("INFO", "Settings", "Backlash alerts toggled: " .. tostring(ns.db.enableBacklash))
    elseif cmd == "immunity" then
        ns.db.enableImmunityAlert = not ns.db.enableImmunityAlert
        ns:Print("Immunity alerts: " .. (ns.db.enableImmunityAlert and "|cff44ff44ON|r" or "|cffff4444OFF|r"))
        ns:Log("INFO", "Settings", "Immunity alerts toggled: " .. tostring(ns.db.enableImmunityAlert))
    else
        ns:Print("OneLock Procs commands:")
        print("  |cffffd100/olprocs move|r — Toggle purple edit-mode anchor box to move banner")
        print("  |cffffd100/olprocs reset|r — Reset banner position to screen center")
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
        ns:Log("INFO", "Core", "OneLock_Procs v" .. ns.version .. " initialized.")
    elseif event == "PLAYER_LOGIN" then
        ns:Print("Loaded v" .. ns.version .. ". Type |cffffd100/olprocs|r for options.")
    end
end)

SLASH_ONELOCKPROCS1 = "/olprocs"
SlashCmdList["ONELOCKPROCS"] = HandleSlashCommand
