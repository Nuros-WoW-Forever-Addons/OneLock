-- ============================================================================
-- OneLock_Timers - Core Engine & Configuration
-- WoW: Forever Beta (v1.60.1 / Interface 16001)
-- ============================================================================

local addonName, ns = ...
_G.OneLock_Timers = ns

ns.addonName = addonName
ns.version = "0.1.0"

-- Database Defaults
local defaultDB = {
    version = 2,
    locked = false, -- Movable by default (controlled entirely by OneLock suite)
    barWidth = 160,
    barHeight = 16,
    barScale = 1.0,
    maxVisibleTargets = 5,
    pandemicThreshold = 3.0,
    showSpellIcon = true,
    showTargetHeader = true,
    colorNormal = { r = 0.60, g = 0.20, b = 0.85, a = 0.90 },
    colorPandemic = { r = 1.00, g = 0.82, b = 0.00, a = 1.00 },
    colorTargetHeader = { r = 1.00, g = 0.82, b = 0.00, a = 1.00 },
    colorNonTargetHeader = { r = 0.70, g = 0.70, b = 0.70, a = 0.85 },
    position = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 160,
        y = 0,
    },
}

-------------------------------------------------------------------------------
-- Print & OneSwatter Logging Integration
-------------------------------------------------------------------------------
function ns:Print(msg)
    local prefix = "|cff9966ff[OneLock:Timers]|r "
    print(prefix .. tostring(msg))
end

function ns:Log(level, category, message, extraData)
    if _G.OneSwatter and _G.OneSwatter.Log then
        _G.OneSwatter:Log(addonName, level, category, message, extraData)
    end
end

-------------------------------------------------------------------------------
-- Database Initialization
-------------------------------------------------------------------------------
local function InitDB()
    if not OneLockTimersDB then
        OneLockTimersDB = {}
    end

    -- Upgrade migration to lock by default
    if not OneLockTimersDB.version or OneLockTimersDB.version < 2 then
        OneLockTimersDB.locked = true
        OneLockTimersDB.version = 2
    end

    for k, v in pairs(defaultDB) do
        if OneLockTimersDB[k] == nil then
            if type(v) == "table" then
                local copy = {}
                for subK, subV in pairs(v) do
                    copy[subK] = subV
                end
                OneLockTimersDB[k] = copy
            else
                OneLockTimersDB[k] = v
            end
        end
    end

    ns.db = OneLockTimersDB
end

-------------------------------------------------------------------------------
-- Slash Command Handler (/onelock, /ol)
-------------------------------------------------------------------------------
local function HandleSlashCommand(msg)
    msg = msg and msg:trim() or ""
    local cmd, arg = msg:match("^(%S+)%s*(.-)$")
    cmd = cmd and cmd:lower() or ""

    if cmd == "" or cmd == "options" or cmd == "config" or cmd == "gui" then
        if ns.ToggleOptionsUI then
            ns.ToggleOptionsUI()
        end
    elseif cmd == "unlock" then
        ns.db.locked = false
        if ns.Display and ns.Display.UpdateAnchorState then
            ns.Display:UpdateAnchorState()
        end
        ns:Print("Anchor |cff44ff44UNLOCKED|r. Drag the anchor frame to reposition, then type |cffffd100/ol lock|r.")
        ns:Log("INFO", "Commands", "Anchor unlocked for repositioning.")
    elseif cmd == "lock" then
        ns.db.locked = true
        if ns.Display and ns.Display.UpdateAnchorState then
            ns.Display:UpdateAnchorState()
        end
        ns:Print("Anchor |cffff4444LOCKED|r.")
        ns:Log("INFO", "Commands", "Anchor locked.")
    elseif cmd == "reset" then
        ns.db.position.point = "CENTER"
        ns.db.position.relativePoint = "CENTER"
        ns.db.position.x = 160
        ns.db.position.y = 0
        if ns.Display and ns.Display.ResetAnchorPosition then
            ns.Display:ResetAnchorPosition()
        end
        ns:Print("Anchor position reset to center.")
        ns:Log("INFO", "Commands", "Anchor position reset to default.")
    elseif cmd == "test" then
        if ns.Display and ns.Display.ToggleTestMode then
            local active = ns.Display:ToggleTestMode()
            if active then
                ns:Print("Simulated test bars |cff44ff44ENABLED|r. Type |cffffd100/ol test|r again to disable.")
            else
                ns:Print("Simulated test bars |cffff4444DISABLED|r.")
            end
            ns:Log("DEBUG", "Commands", "Test mode toggled: " .. tostring(active))
        end
    elseif cmd == "scale" then
        local num = tonumber(arg)
        if num and num >= 0.5 and num <= 2.0 then
            ns.db.barScale = num
            if ns.Display and ns.Display.ApplyDisplaySettings then
                ns.Display:ApplyDisplaySettings()
            end
            ns:Print(string.format("Bar scale set to %.2f.", num))
            ns:Log("INFO", "Settings", "Scale updated to " .. tostring(num))
        else
            ns:Print("Usage: |cffffd100/ol scale <0.5 - 2.0>|r")
        end
    elseif cmd == "width" then
        local num = tonumber(arg)
        if num and num >= 100 and num <= 300 then
            ns.db.barWidth = num
            if ns.Display and ns.Display.ApplyDisplaySettings then
                ns.Display:ApplyDisplaySettings()
            end
            ns:Print(string.format("Bar width set to %d px.", num))
            ns:Log("INFO", "Settings", "Width updated to " .. tostring(num))
        else
            ns:Print("Usage: |cffffd100/ol width <100 - 300>|r")
        end
    elseif cmd == "max" then
        local num = tonumber(arg)
        if num and num >= 1 and num <= 10 then
            ns.db.maxVisibleTargets = num
            if ns.Display and ns.Display.ApplyDisplaySettings then
                ns.Display:ApplyDisplaySettings()
            end
            ns:Print(string.format("Max visible targets set to %d.", num))
            ns:Log("INFO", "Settings", "Max visible targets updated to " .. tostring(num))
        else
            ns:Print("Usage: |cffffd100/ol max <1 - 10>|r")
        end
    else
        ns:Print("OneLock Timers commands:")
        print("  |cffffd100/ol|r        — Open graphical Options Panel")
        print("  |cffffd100/ol unlock|r — Unlock anchor to drag and move bars")
        print("  |cffffd100/ol lock|r   — Lock anchor in current position")
        print("  |cffffd100/ol reset|r  — Reset anchor to default position")
        print("  |cffffd100/ol test|r   — Toggle simulated test bars")
        print("  |cffffd100/ol scale <val>|r — Set scale (0.5 to 2.0)")
        print("  |cffffd100/ol width <val>|r — Set bar width (100 to 300)")
        print("  |cffffd100/ol max <val>|r   — Set max visible targets (1 to 10)")
    end
end

-------------------------------------------------------------------------------
-- MovableFrames Isolation & Purge
-- Guarantees OneLock elements are never managed or captured by MovableFrames
-------------------------------------------------------------------------------
local function PurgeFromMovableFrames()
    if _G.MovableFrames and _G.MovableFrames.UnmanageCustomFrame then
        pcall(_G.MovableFrames.UnmanageCustomFrame, _G.MovableFrames, "OneLockTimersAnchor")
        pcall(_G.MovableFrames.UnmanageCustomFrame, _G.MovableFrames, "OneLockTimersShadowBox")
        pcall(_G.MovableFrames.UnmanageCustomFrame, _G.MovableFrames, "OneLockProcAnchor")
        pcall(_G.MovableFrames.UnmanageCustomFrame, _G.MovableFrames, "OneLockProcShadowBox")
        pcall(_G.MovableFrames.UnmanageCustomFrame, _G.MovableFrames, "OneLockProcAlertBanner")
        pcall(_G.MovableFrames.UnmanageCustomFrame, _G.MovableFrames, "OneLockOptionsFrame")
    end

    if _G.MovableFramesDB and _G.MovableFramesDB.customFrames then
        for k in pairs(_G.MovableFramesDB.customFrames) do
            if type(k) == "string" and k:find("^OneLock") then
                _G.MovableFramesDB.customFrames[k] = nil
                if _G.MovableFramesDB.positions then
                    _G.MovableFramesDB.positions[k] = nil
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Event Dispatcher
-------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame", "OneLock_Timers_EventFrame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        InitDB()
        PurgeFromMovableFrames()
        if ns.Display and ns.Display.Initialize then
            ns.Display:Initialize()
        end
        if ns.Tracker and ns.Tracker.Initialize then
            ns.Tracker:Initialize()
        end
        ns:Log("INFO", "Core", "OneLock_Timers v" .. ns.version .. " loaded successfully.")
    elseif event == "PLAYER_LOGIN" then
        PurgeFromMovableFrames()
        ns:Print("Loaded v" .. ns.version .. ". Type |cffffd100/ol|r for options.")
        ns:Log("INFO", "Core", "PLAYER_LOGIN initialized.")
    end
end)

-- Register Slash Commands
SLASH_ONELOCK1 = "/onelock"
SLASH_ONELOCK2 = "/ol"
SlashCmdList["ONELOCK"] = HandleSlashCommand
