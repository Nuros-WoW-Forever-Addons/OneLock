-- ============================================================================
-- OneLock_Rings - Core Scaffold & Configuration
-- Client: WoW Forever Beta (v1.60.1 / Interface 16001)
-- ============================================================================

local addonName, ns = ...
_G.OneLock_Rings = ns

ns.addonName = addonName
ns.version = "0.1.13"

local defaultDB = {
    version = 1,
    locked = false,                     -- Movable by default with purple edit-mode box
    showStonesRing = true,              -- Show Warlock Stones radial ring
    showDemonsRing = true,              -- Show Demon Summoning radial ring
    stonesScale = 1.0,                  -- Scale (0.6x to 2.0x)
    demonsScale = 1.0,                  -- Scale (0.6x to 2.0x)
    radius = 50,                        -- Radius from center to satellite buttons (px)
    stonesPosition = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = -130,
        y = -100,
    },
    demonsPosition = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 130,
        y = -100,
    },
}

-------------------------------------------------------------------------------
-- Print & OneAddon Chat Frame Routing
-------------------------------------------------------------------------------
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
    local prefix = "|cff9966ff[OneLock:Rings]|r "
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

-------------------------------------------------------------------------------
-- Database Initialization
-------------------------------------------------------------------------------
local function InitDB()
    if not OneLockRingsDB then
        OneLockRingsDB = {}
    end

    for k, v in pairs(defaultDB) do
        if OneLockRingsDB[k] == nil then
            if type(v) == "table" then
                local copy = {}
                for subK, subV in pairs(v) do
                    copy[subK] = subV
                end
                OneLockRingsDB[k] = copy
            else
                OneLockRingsDB[k] = v
            end
        end
    end

    ns.db = OneLockRingsDB
end

-------------------------------------------------------------------------------
-- Slash Commands
-------------------------------------------------------------------------------
local function HandleSlashCommand(msg)
    local _, playerClass = UnitClass("player")
    if playerClass ~= "WARLOCK" then
        ns:Print(string.format("Inactive on this character (%s). OneLock is a Warlock-only suite.", tostring(playerClass)))
        return
    end

    msg = msg and msg:trim() or ""
    local cmd, arg = msg:match("^(%S+)%s*(.-)$")
    cmd = cmd and cmd:lower() or ""

    if cmd == "" or cmd == "options" or cmd == "config" or cmd == "gui" then
        if _G.OneLock_Timers and _G.OneLock_Timers.ToggleOptionsUI then
            _G.OneLock_Timers.ToggleOptionsUI()
        end
    elseif cmd == "move" or cmd == "lock" or cmd == "unlock" then
        if ns.Rings and ns.Rings.ToggleLock then
            local isLocked = ns.Rings:ToggleLock()
            ns:Print("Radial Rings " .. (isLocked and "|cffff4444LOCKED (Hidden handles)|r." or "|cff44ff44UNLOCKED (Move Purple Boxes)|r."))
        end
    elseif cmd == "reset" then
        if ns.Rings and ns.Rings.ResetPositions then
            ns.Rings:ResetPositions()
            ns:Print("Reset Radial Rings to default positions.")
        end
    elseif cmd == "stones" then
        ns.db.showStonesRing = not ns.db.showStonesRing
        if ns.Rings and ns.Rings.ApplySettings then ns.Rings:ApplySettings() end
        ns:Print("Stones Ring: " .. (ns.db.showStonesRing and "|cff44ff44ENABLED|r" or "|cffff4444DISABLED|r"))
    elseif cmd == "demons" then
        ns.db.showDemonsRing = not ns.db.showDemonsRing
        if ns.Rings and ns.Rings.ApplySettings then ns.Rings:ApplySettings() end
        ns:Print("Demons Ring: " .. (ns.db.showDemonsRing and "|cff44ff44ENABLED|r" or "|cffff4444DISABLED|r"))
    else
        ns:Print("OneLock Rings commands:")
        print("  |cffffd100/olrings move|r   — Toggle purple edit-mode boxes to move rings")
        print("  |cffffd100/olrings reset|r  — Reset ring positions to defaults")
        print("  |cffffd100/olrings stones|r — Toggle Warlock Stones radial ring")
        print("  |cffffd100/olrings demons|r — Toggle Demon Summoning radial ring")
    end
end

-------------------------------------------------------------------------------
-- Event Dispatcher
-------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame", "OneLock_Rings_EventFrame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        InitDB()

        local _, playerClass = UnitClass("player")
        if playerClass ~= "WARLOCK" then
            ns:Log("INFO", "Core", "OneLock_Rings inactive for non-Warlock character (" .. tostring(playerClass) .. ").")
            return
        end

        if ns.Rings and ns.Rings.Initialize then
            ns.Rings:Initialize()
        end
        ns:Log("INFO", "Core", "OneLock_Rings v" .. ns.version .. " initialized.")
    elseif event == "PLAYER_LOGIN" then
        local _, playerClass = UnitClass("player")
        if playerClass == "WARLOCK" then
            ns:Print("Loaded v" .. ns.version .. ". Type |cffffd100/olrings|r for options.")
        end
    end
end)

SLASH_ONELOCKRINGS1 = "/olrings"
SlashCmdList["ONELOCKRINGS"] = HandleSlashCommand
