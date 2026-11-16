-- ============================================================================
-- OneLock - Options UI Panel
-- Embedded in Game Menu -> Options -> AddOns, plus Floating Standalone Window
-- Client: WoW Forever Beta (v1.60.1 / Interface 16001)
-- ============================================================================

local addonName, ns = ...
local OptionsUI = {}
ns.OptionsUI = OptionsUI

local standaloneWindow = nil
local blizzardCategoryPanel = nil

local backdropTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil

local function ApplyBackdrop(frame, backdropInfo)
    if BackdropTemplateMixin and not frame.SetBackdrop then
        Mixin(frame, BackdropTemplateMixin)
    end
    if frame.SetBackdrop then
        frame:SetBackdrop(backdropInfo)
    end
end

-------------------------------------------------------------------------------
-- Native Color Picker Helper
-------------------------------------------------------------------------------
local function OpenColorPicker(r, g, b, callback)
    local info = {
        r = r, g = g, b = b,
        swatchFunc = function()
            local nr, ng, nb
            if ColorPickerFrame.GetColorRGB then
                nr, ng, nb = ColorPickerFrame:GetColorRGB()
            elseif ColorPickerFrame.GetColorRGBs then
                nr, ng, nb = ColorPickerFrame:GetColorRGBs()
            else
                nr, ng, nb = ColorPickerFrame.r, ColorPickerFrame.g, ColorPickerFrame.b
            end
            callback(nr or 1, ng or 1, nb or 0)
        end,
        cancelFunc = function()
            callback(r, g, b)
        end
    }

    if ColorPickerFrame.SetupColorPickerAndShow then
        pcall(ColorPickerFrame.SetupColorPickerAndShow, ColorPickerFrame, info)
    else
        ColorPickerFrame.func = info.swatchFunc
        ColorPickerFrame.cancelFunc = info.cancelFunc
        ColorPickerFrame.r = r
        ColorPickerFrame.g = g
        ColorPickerFrame.b = b
        if ColorPickerFrame.SetColorRGB then
            pcall(ColorPickerFrame.SetColorRGB, ColorPickerFrame, r, g, b)
        end
        ColorPickerFrame:Show()
    end
end

-------------------------------------------------------------------------------
-- UI Control Builders
-------------------------------------------------------------------------------
local function CreateButton(parent, text, width, height, onClick)
    local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    btn:SetSize(width or 120, height or 24)
    btn:SetText(text or "")
    if onClick then
        btn:SetScript("OnClick", onClick)
    end
    return btn
end

local function CreateCheckbox(parent, labelText, getValue, setValue, onChange)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)

    local text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    text:SetPoint("LEFT", cb, "RIGHT", 6, 0)
    text:SetText(labelText)
    cb.text = text

    cb.Refresh = function()
        cb:SetChecked(getValue() and true or false)
    end
    cb:SetScript("OnShow", cb.Refresh)
    cb.Refresh()
    cb:SetScript("OnClick", function(self)
        local val = self:GetChecked() and true or false
        setValue(val)
        if onChange then onChange(val) end
    end)
    return cb
end

local function CreateStepper(parent, labelText, minVal, maxVal, step, getter, setter, formatStr, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(340, 26)

    local label = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", container, "LEFT", 0, 0)
    label:SetText(labelText)

    local btnMinus = CreateButton(container, "-", 24, 22, nil)
    btnMinus:SetPoint("RIGHT", container, "RIGHT", -110, 0)

    local valText = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valText:SetPoint("LEFT", btnMinus, "RIGHT", 6, 0)
    valText:SetPoint("RIGHT", container, "RIGHT", -32, 0)
    valText:SetJustifyH("CENTER")

    local btnPlus = CreateButton(container, "+", 24, 22, nil)
    btnPlus:SetPoint("RIGHT", container, "RIGHT", 0, 0)

    local function UpdateVal(newVal)
        newVal = math.max(minVal, math.min(maxVal, newVal))
        newVal = math.floor((newVal / step) + 0.5) * step
        setter(newVal)
        valText:SetText("|cffffd100" .. string.format(formatStr or "%d", newVal) .. "|r")
        if onChange then onChange(newVal) end
    end

    btnMinus:SetScript("OnClick", function()
        UpdateVal(getter() - step)
    end)

    btnPlus:SetScript("OnClick", function()
        UpdateVal(getter() + step)
    end)

    container.Refresh = function()
        valText:SetText("|cffffd100" .. string.format(formatStr or "%d", getter()) .. "|r")
    end
    container:SetScript("OnShow", container.Refresh)
    container.Refresh()

    return container
end

local function CreateColorSwatch(parent, labelText, getter, setter, onChange)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(280, 24)

    local label = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", container, "LEFT", 0, 0)
    label:SetText(labelText)

    local swatch = CreateFrame("Button", nil, container, backdropTemplate)
    swatch:SetSize(22, 22)
    swatch:SetPoint("LEFT", label, "RIGHT", 10, 0)

    ApplyBackdrop(swatch, {
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })

    local function UpdateSwatch()
        local c = getter() or { r = 1, g = 1, b = 1 }
        if swatch.SetBackdropColor then
            swatch:SetBackdropColor(c.r or 1, c.g or 1, c.b or 1, 1)
        end
    end

    swatch:SetScript("OnClick", function()
        local c = getter() or { r = 1, g = 1, b = 1 }
        OpenColorPicker(c.r or 1, c.g or 1, c.b or 1, function(nr, ng, nb)
            setter({ r = nr, g = ng, b = nb, a = c.a or 1 })
            UpdateSwatch()
            if onChange then onChange() end
        end)
    end)

    container.Refresh = UpdateSwatch
    container:SetScript("OnShow", UpdateSwatch)
    UpdateSwatch()
    return container
end

local function CreateSoundSelector(parent, labelText, getSoundList, getIndex, setIndex, onTest)
    local container = CreateFrame("Frame", nil, parent)
    container:SetSize(460, 26)

    local label = container:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    label:SetPoint("LEFT", container, "LEFT", 0, 0)
    label:SetText(labelText)

    local btnPrev = CreateButton(container, "<", 24, 22, nil)
    btnPrev:SetPoint("LEFT", container, "LEFT", 145, 0)

    local valText = container:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valText:SetPoint("LEFT", btnPrev, "RIGHT", 4, 0)
    valText:SetWidth(170)
    valText:SetJustifyH("CENTER")

    local btnNext = CreateButton(container, ">", 24, 22, nil)
    btnNext:SetPoint("LEFT", valText, "RIGHT", 4, 0)

    local btnTest = CreateButton(container, "Test Sound", 80, 22, function()
        if onTest then onTest() end
    end)
    btnTest:SetPoint("LEFT", btnNext, "RIGHT", 8, 0)

    local function UpdateIndex(newIdx)
        local list = getSoundList and getSoundList() or {}
        local count = #list
        if count == 0 then return end
        if newIdx < 1 then newIdx = count end
        if newIdx > count then newIdx = 1 end
        setIndex(newIdx)
        local item = list[newIdx]
        valText:SetText("|cffffd100" .. (item and item.name or "Unknown") .. "|r")
    end

    btnPrev:SetScript("OnClick", function()
        UpdateIndex(getIndex() - 1)
    end)

    btnNext:SetScript("OnClick", function()
        UpdateIndex(getIndex() + 1)
    end)

    container.Refresh = function()
        local list = getSoundList and getSoundList() or {}
        local idx = getIndex()
        local item = list[idx]
        valText:SetText("|cffffd100" .. (item and item.name or "Default") .. "|r")
    end
    container:SetScript("OnShow", container.Refresh)
    container.Refresh()

    return container
end

-------------------------------------------------------------------------------
-- Populate Controls on a Dedicated Content Container Frame
-------------------------------------------------------------------------------
local function PopulateControls(content, isStandalone)
    local curY = -8
    local refreshables = {}

    -- Section Header Helper
    local function AddSectionHeader(titleText)
        local bar = content:CreateTexture(nil, "ARTWORK")
        bar:SetPoint("TOPLEFT", content, "TOPLEFT", 0, curY)
        bar:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, curY)
        bar:SetHeight(24)
        if bar.SetColorTexture then
            bar:SetColorTexture(0.12, 0.08, 0.18, 0.90)
        end

        local text = content:CreateFontString(nil, "OVERLAY", "GameFontNormalMed2")
        text:SetPoint("LEFT", bar, "LEFT", 8, 0)
        text:SetText(titleText)

        curY = curY - 32
    end

    -- ========================================================================
    -- SECTION 1: DoT & CC Timers (OneLock_Timers)
    -- ========================================================================
    AddSectionHeader("|cff9966ffOneLock: Timers (Multi-Target HUD)|r")

    -- Row 1: Action buttons (Move Anchor / Edit Mode, Reset, Test)
    local btnUnlock = CreateButton(content, "Move Anchor (Edit)", 140, 24, function(self)
        if not ns.db then return end
        ns.db.locked = not ns.db.locked
        if ns.Display and ns.Display.UpdateAnchorState then
            ns.Display:UpdateAnchorState()
        end
        self:SetText(ns.db.locked and "Move Anchor (Edit)" or "Lock Anchor")
        ns:Print("Anchor " .. (ns.db.locked and "|cffff4444LOCKED (Hidden)|r." or "|cff44ff44UNLOCKED (Move Purple Box)|r."))
    end)
    btnUnlock:SetPoint("TOPLEFT", content, "TOPLEFT", 4, curY)

    btnUnlock.Refresh = function(self)
        if ns.db then
            self:SetText(ns.db.locked and "Move Anchor (Edit)" or "Lock Anchor")
        end
    end
    table.insert(refreshables, btnUnlock)

    local btnReset = CreateButton(content, "Reset Anchor", 100, 24, function()
        if ns.db then
            ns.db.position.point = "CENTER"
            ns.db.position.relativePoint = "CENTER"
            ns.db.position.x = 160
            ns.db.position.y = 0
            if ns.Display and ns.Display.ResetAnchorPosition then
                ns.Display:ResetAnchorPosition()
            end
            ns:Print("Anchor position reset to center.")
        end
    end)
    btnReset:SetPoint("LEFT", btnUnlock, "RIGHT", 8, 0)

    local btnTest = CreateButton(content, "Toggle Test Bars", 130, 24, function()
        if ns.Display and ns.Display.ToggleTestMode then
            local active = ns.Display:ToggleTestMode()
            ns:Print("Simulated test bars " .. (active and "|cff44ff44ENABLED|r." or "|cffff4444DISABLED|r."))
        end
    end)
    btnTest:SetPoint("LEFT", btnReset, "RIGHT", 8, 0)

    curY = curY - 34

    -- Steppers: Width, Height, Scale, Max Targets, Pandemic Threshold
    local stepWidth = CreateStepper(content, "Timer Bar Width:", 100, 300, 10,
        function() return (ns.db and ns.db.barWidth) or 160 end,
        function(v) if ns.db then ns.db.barWidth = v end end,
        "%d px",
        function() if ns.Display and ns.Display.ApplyDisplaySettings then ns.Display:ApplyDisplaySettings() end end
    )
    stepWidth:SetPoint("TOPLEFT", content, "TOPLEFT", 6, curY)
    table.insert(refreshables, stepWidth)
    curY = curY - 30

    local stepHeight = CreateStepper(content, "Timer Bar Height:", 12, 28, 2,
        function() return (ns.db and ns.db.barHeight) or 16 end,
        function(v) if ns.db then ns.db.barHeight = v end end,
        "%d px",
        function() if ns.Display and ns.Display.ApplyDisplaySettings then ns.Display:ApplyDisplaySettings() end end
    )
    stepHeight:SetPoint("TOPLEFT", content, "TOPLEFT", 6, curY)
    table.insert(refreshables, stepHeight)
    curY = curY - 30

    local stepScale = CreateStepper(content, "Frame Scale:", 0.5, 1.8, 0.05,
        function() return (ns.db and ns.db.barScale) or 1.0 end,
        function(v) if ns.db then ns.db.barScale = v end end,
        "%.2fx",
        function() if ns.Display and ns.Display.ApplyDisplaySettings then ns.Display:ApplyDisplaySettings() end end
    )
    stepScale:SetPoint("TOPLEFT", content, "TOPLEFT", 6, curY)
    table.insert(refreshables, stepScale)
    curY = curY - 30

    local stepMax = CreateStepper(content, "Max Visible Targets:", 1, 10, 1,
        function() return (ns.db and ns.db.maxVisibleTargets) or 5 end,
        function(v) if ns.db then ns.db.maxVisibleTargets = v end end,
        "%d",
        function() if ns.Display and ns.Display.ApplyDisplaySettings then ns.Display:ApplyDisplaySettings() end end
    )
    stepMax:SetPoint("TOPLEFT", content, "TOPLEFT", 6, curY)
    table.insert(refreshables, stepMax)
    curY = curY - 30

    local stepPan = CreateStepper(content, "Pandemic Refresh Window:", 1.0, 5.0, 0.5,
        function() return (ns.db and ns.db.pandemicThreshold) or 3.0 end,
        function(v) if ns.db then ns.db.pandemicThreshold = v end end,
        "%.1f sec",
        function() if ns.Display and ns.Display.ApplyDisplaySettings then ns.Display:ApplyDisplaySettings() end end
    )
    stepPan:SetPoint("TOPLEFT", content, "TOPLEFT", 6, curY)
    table.insert(refreshables, stepPan)
    curY = curY - 32

    -- Checkboxes: Target Header & Spell Icons
    local cbHeader = CreateCheckbox(content, "Display Target Name Header Banner",
        function() return ns.db and ns.db.showTargetHeader end,
        function(v) if ns.db then ns.db.showTargetHeader = v end end,
        function() if ns.Display and ns.Display.ApplyDisplaySettings then ns.Display:ApplyDisplaySettings() end end
    )
    cbHeader:SetPoint("TOPLEFT", content, "TOPLEFT", 6, curY)
    table.insert(refreshables, cbHeader)
    curY = curY - 26

    local cbIcon = CreateCheckbox(content, "Display Spell Icons on Bars",
        function() return ns.db and ns.db.showSpellIcon end,
        function(v) if ns.db then ns.db.showSpellIcon = v end end,
        function() if ns.Display and ns.Display.ApplyDisplaySettings then ns.Display:ApplyDisplaySettings() end end
    )
    cbIcon:SetPoint("TOPLEFT", content, "TOPLEFT", 6, curY)
    table.insert(refreshables, cbIcon)
    curY = curY - 32

    -- Color Swatches: Normal & Pandemic Color
    local swatchNormal = CreateColorSwatch(content, "Normal Bar Color:",
        function() return (ns.db and ns.db.colorNormal) or { r = 0.60, g = 0.20, b = 0.85 } end,
        function(c) if ns.db then ns.db.colorNormal = c end end,
        function() if ns.Display and ns.Display.ApplyDisplaySettings then ns.Display:ApplyDisplaySettings() end end
    )
    swatchNormal:SetPoint("TOPLEFT", content, "TOPLEFT", 6, curY)
    table.insert(refreshables, swatchNormal)
    curY = curY - 28

    local swatchPandemic = CreateColorSwatch(content, "Pandemic Color (< 3.0s):",
        function() return (ns.db and ns.db.colorPandemic) or { r = 1.00, g = 0.82, b = 0.00 } end,
        function(c) if ns.db then ns.db.colorPandemic = c end end,
        function() if ns.Display and ns.Display.ApplyDisplaySettings then ns.Display:ApplyDisplaySettings() end end
    )
    swatchPandemic:SetPoint("TOPLEFT", content, "TOPLEFT", 6, curY)
    table.insert(refreshables, swatchPandemic)
    curY = curY - 40

    -- ========================================================================
    -- SECTION 2: Soul Shards & Soulstone (OneLock_Shards)
    -- ========================================================================
    AddSectionHeader("|cff9966ffOneLock: Shards (Inventory & Soulstone)|r")

    local stepShards = CreateStepper(content, "Max Soul Shards Cap:", 1, 32, 1,
        function() return (_G.OneLockShardsDB and _G.OneLockShardsDB.maxShards) or (_G.OneLock_Shards and _G.OneLock_Shards.db and _G.OneLock_Shards.db.maxShards) or 24 end,
        function(v)
            if _G.OneLockShardsDB then _G.OneLockShardsDB.maxShards = v end
            if _G.OneLock_Shards and _G.OneLock_Shards.db then _G.OneLock_Shards.db.maxShards = v end
        end,
        "%d",
        nil
    )
    stepShards:SetPoint("TOPLEFT", content, "TOPLEFT", 6, curY)
    table.insert(refreshables, stepShards)
    curY = curY - 30

    local cbAutoDelete = CreateCheckbox(content, "Auto-delete excess Soul Shards (Runs out of combat)",
        function() return _G.OneLockShardsDB and _G.OneLockShardsDB.autoDeleteExcess end,
        function(v) if _G.OneLockShardsDB then _G.OneLockShardsDB.autoDeleteExcess = v end end,
        nil
    )
    cbAutoDelete:SetPoint("TOPLEFT", content, "TOPLEFT", 6, curY)
    table.insert(refreshables, cbAutoDelete)
    curY = curY - 30

    local btnClean = CreateButton(content, "Clean Up Excess Shards Now", 200, 24, function()
        if _G.OneLock_Shards and _G.OneLock_Shards.ShardManager then
            _G.OneLock_Shards.ShardManager:CleanupExcessShards()
        end
    end)
    btnClean:SetPoint("TOPLEFT", content, "TOPLEFT", 6, curY)
    curY = curY - 40

    -- ========================================================================
    -- SECTION 3: Procs & Alerts (OneLock_Procs)
    -- ========================================================================
    AddSectionHeader("|cff9966ffOneLock: Procs (Alerts & Immunities)|r")

    -- Move Alert Banner (Edit) / Reset Alert Position
    local btnMoveProc = CreateButton(content, (_G.OneLockProcsDB and not _G.OneLockProcsDB.locked) and "Lock Alert Banner" or "Move Alert Banner (Edit)", 170, 24, function(self)
        if _G.OneLock_Procs and _G.OneLock_Procs.Alerts and _G.OneLock_Procs.Alerts.ToggleLock then
            local isLocked = _G.OneLock_Procs.Alerts:ToggleLock()
            self:SetText(isLocked and "Move Alert Banner (Edit)" or "Lock Alert Banner")
        end
    end)
    btnMoveProc:SetPoint("TOPLEFT", content, "TOPLEFT", 6, curY)

    btnMoveProc.Refresh = function(self)
        local isUnlocked = (_G.OneLockProcsDB and _G.OneLockProcsDB.locked == false)
        self:SetText(isUnlocked and "Lock Alert Banner" or "Move Alert Banner (Edit)")
    end
    table.insert(refreshables, btnMoveProc)

    local btnResetProc = CreateButton(content, "Reset Alert Position", 140, 24, function()
        if _G.OneLock_Procs and _G.OneLock_Procs.Alerts and _G.OneLock_Procs.Alerts.ResetAnchorPosition then
            _G.OneLock_Procs.Alerts:ResetAnchorPosition()
        end
    end)
    btnResetProc:SetPoint("LEFT", btnMoveProc, "RIGHT", 10, 0)
    curY = curY - 34

    -- Steppers: Alert Banner Width & Scale
    local stepAlertWidth = CreateStepper(content, "Alert Banner Width:", 160, 360, 10,
        function() return (_G.OneLockProcsDB and _G.OneLockProcsDB.alertWidth) or 240 end,
        function(v)
            if _G.OneLockProcsDB then _G.OneLockProcsDB.alertWidth = v end
            if _G.OneLock_Procs and _G.OneLock_Procs.Alerts and _G.OneLock_Procs.Alerts.ApplyAlertSettings then
                _G.OneLock_Procs.Alerts:ApplyAlertSettings()
            end
        end,
        "%d px",
        nil
    )
    stepAlertWidth:SetPoint("TOPLEFT", content, "TOPLEFT", 6, curY)
    table.insert(refreshables, stepAlertWidth)
    curY = curY - 30

    local stepAlertScale = CreateStepper(content, "Alert Banner Scale:", 0.8, 2.0, 0.05,
        function() return (_G.OneLockProcsDB and _G.OneLockProcsDB.alertScale) or 1.2 end,
        function(v)
            if _G.OneLockProcsDB then _G.OneLockProcsDB.alertScale = v end
            if _G.OneLock_Procs and _G.OneLock_Procs.Alerts and _G.OneLock_Procs.Alerts.ApplyAlertSettings then
                _G.OneLock_Procs.Alerts:ApplyAlertSettings()
            end
        end,
        "%.2fx",
        nil
    )
    stepAlertScale:SetPoint("TOPLEFT", content, "TOPLEFT", 6, curY)
    table.insert(refreshables, stepAlertScale)
    curY = curY - 32

    local cbNightfall = CreateCheckbox(content, "Enable Shadow Trance (Nightfall) Alerts",
        function() return _G.OneLockProcsDB and _G.OneLockProcsDB.enableNightfall end,
        function(v) if _G.OneLockProcsDB then _G.OneLockProcsDB.enableNightfall = v end end,
        nil
    )
    cbNightfall:SetPoint("TOPLEFT", content, "TOPLEFT", 6, curY)
    table.insert(refreshables, cbNightfall)
    curY = curY - 26

    local cbBacklash = CreateCheckbox(content, "Enable Backlash Alerts",
        function() return _G.OneLockProcsDB and _G.OneLockProcsDB.enableBacklash end,
        function(v) if _G.OneLockProcsDB then _G.OneLockProcsDB.enableBacklash = v end end,
        nil
    )
    cbBacklash:SetPoint("TOPLEFT", content, "TOPLEFT", 6, curY)
    table.insert(refreshables, cbBacklash)
    curY = curY - 26

    local cbImmunity = CreateCheckbox(content, "Enable CC Target Immunity Alerts (Fear / Banish)",
        function() return _G.OneLockProcsDB and _G.OneLockProcsDB.enableImmunityAlert end,
        function(v) if _G.OneLockProcsDB then _G.OneLockProcsDB.enableImmunityAlert = v end end,
        nil
    )
    cbImmunity:SetPoint("TOPLEFT", content, "TOPLEFT", 6, curY)
    table.insert(refreshables, cbImmunity)
    curY = curY - 26

    local cbAudio = CreateCheckbox(content, "Play Sound Warning on Procs",
        function() return _G.OneLockProcsDB and _G.OneLockProcsDB.playAudio end,
        function(v) if _G.OneLockProcsDB then _G.OneLockProcsDB.playAudio = v end end,
        nil
    )
    cbAudio:SetPoint("TOPLEFT", content, "TOPLEFT", 6, curY)
    table.insert(refreshables, cbAudio)
    curY = curY - 30

    -- Sound Selector: Prev / Next / Test Sound
    local soundSel = CreateSoundSelector(content, "Alert Sound Effect:",
        function()
            if _G.OneLock_Procs and _G.OneLock_Procs.Alerts and _G.OneLock_Procs.Alerts.GetSoundList then
                return _G.OneLock_Procs.Alerts:GetSoundList()
            end
            return {}
        end,
        function()
            if _G.OneLock_Procs and _G.OneLock_Procs.Alerts and _G.OneLock_Procs.Alerts.GetCurrentSoundIndex then
                return _G.OneLock_Procs.Alerts:GetCurrentSoundIndex()
            end
            return 1
        end,
        function(idx)
            if _G.OneLock_Procs and _G.OneLock_Procs.Alerts and _G.OneLock_Procs.Alerts.SetSoundByIndex then
                _G.OneLock_Procs.Alerts:SetSoundByIndex(idx)
            end
        end,
        function()
            if _G.OneLock_Procs and _G.OneLock_Procs.Alerts and _G.OneLock_Procs.Alerts.PlayCurrentSound then
                _G.OneLock_Procs.Alerts:PlayCurrentSound()
            end
        end
    )
    soundSel:SetPoint("TOPLEFT", content, "TOPLEFT", 6, curY)
    table.insert(refreshables, soundSel)
    curY = curY - 34

    local btnTestProc = CreateButton(content, "Trigger Test Proc Alert Banner", 220, 24, function()
        if _G.OneLock_Procs and _G.OneLock_Procs.Alerts then
            _G.OneLock_Procs.Alerts:TriggerTestAlert()
        end
    end)
    btnTestProc:SetPoint("TOPLEFT", content, "TOPLEFT", 6, curY)
    curY = curY - 40

    content:SetHeight(math.abs(curY) + 30)

    content.RefreshAll = function()
        for _, ctrl in ipairs(refreshables) do
            if ctrl.Refresh then
                ctrl:Refresh()
            end
        end
    end

    content:SetScript("OnShow", content.RefreshAll)
    return content
end

-------------------------------------------------------------------------------
-- Standalone Floating Options Window (Completely Self-Contained)
-------------------------------------------------------------------------------
function ns.ShowStandaloneUI()
    if not standaloneWindow then
        local f = CreateFrame("Frame", "OneLockOptionsFrame", UIParent, backdropTemplate)
        f:SetSize(520, 600)
        f:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        f:SetMovable(true)
        f:EnableMouse(true)
        f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving)
        f:SetScript("OnDragStop", f.StopMovingOrSizing)
        f:SetFrameStrata("DIALOG")
        f:SetClampedToScreen(true)

        ApplyBackdrop(f, {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\DialogFrame\\UI-DialogFrame-Border",
            tile = true, tileSize = 16, edgeSize = 16,
            insets = { left = 5, right = 5, top = 5, bottom = 5 }
        })
        if f.SetBackdropColor then
            f:SetBackdropColor(0.04, 0.05, 0.08, 0.96)
            f:SetBackdropBorderColor(0.7, 0.5, 0.9, 0.95) -- Warlock Violet Accent
        end

        -- Header Bar
        local headerBar = f:CreateTexture(nil, "ARTWORK")
        headerBar:SetPoint("TOPLEFT", f, "TOPLEFT", 6, -6)
        headerBar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
        headerBar:SetHeight(30)
        if headerBar.SetColorTexture then
            headerBar:SetColorTexture(0.12, 0.07, 0.18, 0.95)
        end

        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalMed3")
        title:SetPoint("LEFT", headerBar, "LEFT", 12, 0)
        title:SetText("|cff9966ffOneLock Suite|r  |cffffd100Options & Settings|r")

        local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        closeBtn:SetPoint("RIGHT", headerBar, "RIGHT", -2, 0)
        closeBtn:SetScript("OnClick", function()
            f:Hide()
        end)

        -- Inset Scroll Container
        local inset = CreateFrame("Frame", nil, f, backdropTemplate)
        inset:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -40)
        inset:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 10)

        ApplyBackdrop(inset, {
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 16, edgeSize = 10,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        if inset.SetBackdropColor then
            inset:SetBackdropColor(0.02, 0.02, 0.05, 0.75)
            inset:SetBackdropBorderColor(0.3, 0.2, 0.4, 0.8)
        end

        local scrollFrame = CreateFrame("ScrollFrame", "OneLockStandaloneScrollFrame", inset, "UIPanelScrollFrameTemplate")
        scrollFrame:SetPoint("TOPLEFT", inset, "TOPLEFT", 6, -6)
        scrollFrame:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -26, 6)
        f.scrollFrame = scrollFrame

        -- Create dedicated content child inside standalone scroll frame
        local content = CreateFrame("Frame", "OneLockStandaloneContent", scrollFrame)
        content:SetSize(460, 720)
        PopulateControls(content, true)
        scrollFrame:SetScrollChild(content)
        content:Show()
        f.content = content

        if UISpecialFrames then
            table.insert(UISpecialFrames, "OneLockOptionsFrame")
        end

        f:SetScript("OnShow", function()
            if f.content and f.content.RefreshAll then
                f.content:RefreshAll()
            end
        end)

        standaloneWindow = f
    end

    -- Close Game Menu options if open to clear view
    if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then
        HideUIPanel(InterfaceOptionsFrame)
    end
    if SettingsPanel and SettingsPanel:IsShown() then
        HideUIPanel(SettingsPanel)
    end

    if not standaloneWindow:IsShown() then
        standaloneWindow:Show()
    end
    if standaloneWindow.content and standaloneWindow.content.RefreshAll then
        standaloneWindow.content:RefreshAll()
    end
end

function ns.ToggleOptionsUI()
    if standaloneWindow and standaloneWindow:IsShown() then
        standaloneWindow:Hide()
    else
        ns.ShowStandaloneUI()
    end
end

-------------------------------------------------------------------------------
-- Embedded Blizzard Options Panel (Settings -> AddOns -> OneLock)
-------------------------------------------------------------------------------
local function RegisterBlizzardCategory()
    if blizzardCategoryPanel then return blizzardCategoryPanel end

    local panel = CreateFrame("Frame", "OneLockBlizzardOptionsPanel", UIParent)
    panel.name = "OneLock"

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
    title:SetText("|cff9966ffOneLock Suite Options|r")

    local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetText("Modular Warlock raid utility suite for WoW: Forever (v1.60.1).")

    -- Pop-out Button to open the standalone options panel
    local btnPopOut = CreateButton(panel, "Open Standalone Window", 220, 26, function()
        ns.ShowStandaloneUI()
    end)
    btnPopOut:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -12)

    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", btnPopOut, "RIGHT", 10, 0)
    hint:SetText("(Opens movable floating window & closes Game Menu)")

    -- Dedicated Embedded ScrollFrame
    local scrollFrame = CreateFrame("ScrollFrame", "OneLockBlizzardScrollFrame", panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -88)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 10)
    panel.scrollFrame = scrollFrame

    -- Create dedicated embedded content child
    local embeddedContent = CreateFrame("Frame", "OneLockEmbeddedContent", scrollFrame)
    embeddedContent:SetSize(580, 720)
    PopulateControls(embeddedContent, false)
    scrollFrame:SetScrollChild(embeddedContent)
    embeddedContent:Show()
    panel.content = embeddedContent

    panel:SetScript("OnShow", function()
        if embeddedContent and embeddedContent.RefreshAll then
            embeddedContent:RefreshAll()
        end
    end)

    -- Register with modern Settings or legacy InterfaceOptions
    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "OneLock")
        Settings.RegisterAddOnCategory(category)
        panel.categoryID = category:GetID()
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end

    blizzardCategoryPanel = panel
    ns:Log("INFO", "OptionsUI", "Registered OneLock category in Game Menu -> Options -> AddOns.")
    return panel
end

-------------------------------------------------------------------------------
-- Initialization Hook
-------------------------------------------------------------------------------
local loader = CreateFrame("Frame")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent", function()
    RegisterBlizzardCategory()
end)
