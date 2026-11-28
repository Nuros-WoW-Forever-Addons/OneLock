-- ============================================================================
-- OneLock_Rings - Radial Utility Rings (Stones & Demons)
-- Client: WoW Forever Beta (v1.60.1 / Interface 16001)
-- ============================================================================

local addonName, ns = ...
local Rings = {}
ns.Rings = Rings

local SOUL_SHARD_ITEM_ID = 6265

-- Item IDs and Spell IDs
-- Ordered by lowest rank first so fallback texture is always an obtainable/known rank
local HEALTHSTONES = { 5512, 19004, 19005, 5511, 19006, 19007, 5509, 19008, 19009, 5510, 19010, 19011, 9421, 19012, 19013, 22103 }
local SOULSTONES   = { 5232, 16892, 16893, 16895, 16896, 22116 }
local SPELLSTONES  = { 5522, 13602, 13603, 22105 }
local FIRESTONES   = { 1254, 16952, 16953, 16954, 22111 }

local SPELL_SUMMON_RITUAL    = 698    -- Ritual of Summoning
local SPELL_SUMMON_IMP       = 688    -- Summon Imp
local SPELL_SUMMON_VOIDWALKER= 697    -- Summon Voidwalker
local SPELL_SUMMON_SUCCUBUS  = 712    -- Summon Succubus
local SPELL_SUMMON_FELHUNTER = 691    -- Summon Felhunter

local backdropTemplate = BackdropTemplateMixin and "BackdropTemplate" or nil

-------------------------------------------------------------------------------
-- Secret Value Protection (WoW Forever Interface 16001 / Camelot Engine)
-------------------------------------------------------------------------------
local function IsSecret(val)
    return issecretvalue and issecretvalue(val)
end

local function SafeHasAtlas(atlasName)
    if not atlasName then return false end
    if C_Texture and C_Texture.GetAtlasInfo then
        local ok, info = pcall(C_Texture.GetAtlasInfo, atlasName)
        return ok and info ~= nil
    end
    return false
end

-------------------------------------------------------------------------------
-- Helper: Safe Item and Spell Texture Queries
-------------------------------------------------------------------------------
local function GetItemTextureSafe(itemId)
    if C_Item and C_Item.GetItemIconByID then
        local icon = C_Item.GetItemIconByID(itemId)
        if icon then return icon end
    end
    if _G.GetItemIcon then
        local icon = _G.GetItemIcon(itemId)
        if icon then return icon end
    end
    return 134400
end

local function GetSpellTextureSafe(spellId)
    if C_Spell and C_Spell.GetSpellTexture then
        local tex = C_Spell.GetSpellTexture(spellId)
        if tex then return tex end
    end
    if _G.GetSpellTexture then
        local tex = _G.GetSpellTexture(spellId)
        if tex then return tex end
    end
    return 134400
end

local function GetItemCooldownSafe(itemId)
    if C_Container and C_Container.GetItemCooldown then
        local start, dur, enable = C_Container.GetItemCooldown(itemId)
        if start and dur then return start, dur, enable end
    elseif _G.GetItemCooldown then
        local start, dur, enable = _G.GetItemCooldown(itemId)
        if start and dur then return start, dur, enable end
    end
    return 0, 0, 0
end

local function GetSpellCooldownSafe(spellId)
    if C_Spell and C_Spell.GetSpellCooldown then
        local cd = C_Spell.GetSpellCooldown(spellId)
        if cd and type(cd) == "table" and cd.startTime then
            return cd.startTime, cd.duration, cd.isEnabled and 1 or 0
        end
    elseif _G.GetSpellCooldown then
        local start, dur, enable = _G.GetSpellCooldown(spellId)
        if start and dur then return start, dur, enable end
    end
    return 0, 0, 0
end

local function IsSpellKnownSafe(spellIdOrName)
    if not spellIdOrName then return false end

    -- A. Numeric Spell ID checks
    if type(spellIdOrName) == "number" then
        local spellId = spellIdOrName

        -- 1. Native player spell check (IsPlayerSpell)
        if _G.IsPlayerSpell then
            local ok, known = pcall(_G.IsPlayerSpell, spellId)
            if ok and known ~= nil then return known end
        end

        -- 2. C_Spell.IsSpellKnown (Camelot / modern engine)
        if C_Spell and C_Spell.IsSpellKnown then
            local ok, known = pcall(C_Spell.IsSpellKnown, spellId)
            if ok and known ~= nil then return known end
        end

        -- 3. C_SpellBook.IsSpellKnown
        if C_SpellBook and C_SpellBook.IsSpellKnown then
            local ok, known = pcall(C_SpellBook.IsSpellKnown, spellId)
            if ok and known ~= nil then return known end
        end

        -- 4. C_SpellBook.FindSpellBookSlotForSpell (exclude future spells & offspec)
        if C_SpellBook and C_SpellBook.FindSpellBookSlotForSpell then
            local ok, slotIndex = pcall(C_SpellBook.FindSpellBookSlotForSpell, spellId, false, false, false, false)
            if ok then
                if slotIndex and slotIndex > 0 then
                    return true
                elseif slotIndex == nil then
                    return false
                end
            end
        end

        -- 5. Legacy global IsSpellKnown
        if _G.IsSpellKnown then
            local ok, known = pcall(_G.IsSpellKnown, spellId)
            if ok and known ~= nil then return known end
        end
    end

    -- B. Name-based resolution and spellbook scan
    local targetName = nil
    if type(spellIdOrName) == "string" then
        targetName = spellIdOrName
    elseif type(spellIdOrName) == "number" then
        if C_Spell and C_Spell.GetSpellName then
            local ok, name = pcall(C_Spell.GetSpellName, spellIdOrName)
            if ok and name then targetName = name end
        end
        if not targetName and _G.GetSpellInfo then
            local ok, name = pcall(_G.GetSpellInfo, spellIdOrName)
            if ok and name then targetName = name end
        end
    end

    if not targetName or targetName == "" then
        return false
    end

    -- Check FindSpellBookSlotForSpell by target name
    if C_SpellBook and C_SpellBook.FindSpellBookSlotForSpell then
        local ok, slotIndex = pcall(C_SpellBook.FindSpellBookSlotForSpell, targetName, false, false, false, false)
        if ok then
            if slotIndex and slotIndex > 0 then
                return true
            elseif slotIndex == nil then
                return false
            end
        end
    end

    -- Strict manual Spellbook scan (guaranteeing FutureSpell / unlearned spells are rejected)
    local bank = (Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player) or 0
    if C_SpellBook then
        for i = 1, 200 do
            local name = nil
            local itemType = nil
            local isOffSpec = false

            if C_SpellBook.GetSpellBookItemInfo then
                local ok, info = pcall(C_SpellBook.GetSpellBookItemInfo, i, bank)
                if ok and info then
                    name = info.name
                    itemType = info.itemType
                    isOffSpec = info.isOffSpec
                end
            end

            if not name and C_SpellBook.GetSpellBookItemName then
                local okN, n = pcall(C_SpellBook.GetSpellBookItemName, i, bank)
                if okN then name = n end
                if C_SpellBook.GetSpellBookItemType then
                    local okT, t = pcall(C_SpellBook.GetSpellBookItemType, i, bank)
                    if okT then itemType = t end
                end
                if C_SpellBook.IsSpellBookItemOffSpec then
                    local okO, o = pcall(C_SpellBook.IsSpellBookItemOffSpec, i, bank)
                    if okO then isOffSpec = o end
                end
            end

            if name and name == targetName then
                if isOffSpec then
                    return false
                end
                -- Strictly verify itemType:
                -- 1 / "SPELL" / Enum.SpellBookItemType.Spell is learned
                -- 2 / "FUTURESPELL" / Enum.SpellBookItemType.FutureSpell is unlearned!
                if itemType ~= nil then
                    if itemType == 1 or itemType == "SPELL" or (Enum and Enum.SpellBookItemType and itemType == Enum.SpellBookItemType.Spell) then
                        return true
                    else
                        return false
                    end
                end
            end
        end
    end

    return false
end

local function GetMaxPlayerBag()
    return (NUM_TOTAL_EQUIPPED_BAG_SLOTS and NUM_TOTAL_EQUIPPED_BAG_SLOTS > 0 and NUM_TOTAL_EQUIPPED_BAG_SLOTS)
        or (NUM_BAG_SLOTS and NUM_BAG_SLOTS > 0 and NUM_BAG_SLOTS)
        or 5
end

local function CountItemsInBags(itemIdList)
    local total = 0
    local highestFoundId = nil
    local highestFoundIdx = 0
    local maxBag = GetMaxPlayerBag()
    for bag = 0, maxBag do
        local numSlots = (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag)) or (_G.GetContainerNumSlots and _G.GetContainerNumSlots(bag)) or 0
        for slot = 1, numSlots do
            local id = (C_Container and C_Container.GetContainerItemID and C_Container.GetContainerItemID(bag, slot)) or (_G.GetContainerItemID and _G.GetContainerItemID(bag, slot))
            if id then
                for idx, targetId in ipairs(itemIdList) do
                    if id == targetId then
                        total = total + 1
                        -- Since itemIdList is ordered lowest to highest, keep the highest index found
                        if idx > highestFoundIdx then
                            highestFoundId = id
                            highestFoundIdx = idx
                        end
                        break
                    end
                end
            end
        end
    end
    return total, highestFoundId
end

local function GetSoulShardCount()
    if _G.OneLock_Shards and _G.OneLock_Shards.ShardManager and _G.OneLock_Shards.ShardManager.GetShardCount then
        return _G.OneLock_Shards.ShardManager:GetShardCount()
    end
    local count = 0
    local maxBag = GetMaxPlayerBag()
    for bag = 0, maxBag do
        local numSlots = (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag)) or (_G.GetContainerNumSlots and _G.GetContainerNumSlots(bag)) or 0
        for slot = 1, numSlots do
            local id = (C_Container and C_Container.GetContainerItemID and C_Container.GetContainerItemID(bag, slot)) or (_G.GetContainerItemID and _G.GetContainerItemID(bag, slot))
            if id == SOUL_SHARD_ITEM_ID then
                count = count + 1
            end
        end
    end
    return count
end

local MASK_TEXTURE = [[Interface\AddOns\OneLock_Rings\Textures\CircleMask.tga]]
local RING_TEXTURE = [[Interface\AddOns\OneLock_Rings\Textures\CircleRing.tga]]

-------------------------------------------------------------------------------
-- Circular Button Creation Helper
-------------------------------------------------------------------------------
local function CreateCircularSecureButton(parent, name, size, isCenter)
    local btn = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
    btn:SetSize(size, size)
    btn:RegisterForClicks("AnyUp", "AnyDown")

    -- Inset icon and contents slightly inside the outer circular metallic ring
    -- Center: 48px button with 5px inset -> 38px icon
    -- Satellite: 34px button with 3.5px inset -> 27px icon
    local inset = isCenter and 5 or 3.5

    -- Circular mask object for all button textures
    local mask = btn.CreateMaskTexture and btn:CreateMaskTexture()
    if type(mask) == "table" then
        mask:SetTexture(MASK_TEXTURE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        btn.mask = mask
    end

    -- Circular background backing
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetPoint("TOPLEFT", btn, "TOPLEFT", inset, -inset)
    bg:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -inset, inset)
    bg:SetTexture(MASK_TEXTURE)
    bg:SetVertexColor(0.08, 0.05, 0.12, 0.95)
    if mask and bg.AddMaskTexture then
        bg:AddMaskTexture(mask)
    end
    btn.bg = bg

    -- Main Icon (recessed inside the outer border ring)
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", btn, "TOPLEFT", inset, -inset)
    icon:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -inset, inset)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if mask then
        mask:SetAllPoints(icon)
        if icon.AddMaskTexture then
            icon:AddMaskTexture(mask)
        elseif icon.SetMask then
            icon:SetMask(MASK_TEXTURE)
        end
    end
    btn.icon = icon

    -- Cooldown spiral (recessed to match icon)
    local cd = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    cd:SetPoint("TOPLEFT", btn, "TOPLEFT", inset, -inset)
    cd:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -inset, inset)
    cd:SetFrameLevel(btn:GetFrameLevel() + 2)
    cd:SetDrawEdge(true)
    cd:SetSwipeColor(0, 0, 0, 0.75)
    btn.cd = cd

    -- Highlight texture on mouseover
    local highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetPoint("TOPLEFT", btn, "TOPLEFT", inset, -inset)
    highlight:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -inset, inset)
    highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Round")
    highlight:SetBlendMode("ADD")
    btn.highlight = highlight

    -- Outer border rim: clean, concentric, thin circular metallic ring
    local border = btn:CreateTexture(nil, "OVERLAY", nil, 1)
    border:SetAllPoints(btn)
    border:SetTexture(RING_TEXTURE)
    border:SetVertexColor(0.85, 0.65, 1.0, 0.9)
    btn.border = border

    -- Count Overlay Frame to guarantee fontstring is in HIGH strata above all button elements
    local overlayFrame = CreateFrame("Frame", nil, btn)
    overlayFrame:SetAllPoints(btn)
    overlayFrame:SetFrameStrata("HIGH")
    overlayFrame:SetFrameLevel(btn:GetFrameLevel() + 30)
    btn.overlayFrame = overlayFrame

    -- Count FontString (Centered on each button with high contrast outline & shadow)
    local count = overlayFrame:CreateFontString(nil, "OVERLAY")
    count:SetFontObject(isCenter and "NumberFontNormalHuge" or "NumberFontNormalLarge")
    local fontFile, fontHeight = count:GetFont()
    if fontFile then
        count:SetFont(fontFile, isCenter and 18 or 13, "OUTLINE")
    end
    count:SetPoint("CENTER", overlayFrame, "CENTER", 0, 0)
    count:SetShadowOffset(1, -1)
    count:SetShadowColor(0, 0, 0, 1)
    btn.countText = count

    return btn
end

-------------------------------------------------------------------------------
-- Ring 1: Warlock Stones & Soul Shard Core
-------------------------------------------------------------------------------
local stonesAnchor = nil
local stonesButtons = {}

local function CreateStonesRing()
    local db = ns.db
    local anchor = CreateFrame("Frame", "OneLock_StonesRingAnchor", UIParent)
    anchor:SetSize(52, 52)
    anchor:SetScale(db.stonesScale or 1.0)
    anchor:SetClampedToScreen(true)
    anchor:SetMovable(true)

    local pos = db.stonesPosition or { point = "CENTER", relativePoint = "CENTER", x = -130, y = -100 }
    anchor:ClearAllPoints()
    anchor:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.x or -130, pos.y or -100)

    -- Edit Mode Shadow Box
    local shadowBox = CreateFrame("Frame", "OneLock_StonesRingShadowBox", anchor, backdropTemplate)
    shadowBox:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    shadowBox:SetSize(160, 130)
    shadowBox:SetFrameStrata("HIGH")
    shadowBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    shadowBox:SetBackdropColor(0.20, 0.08, 0.35, 0.65)
    shadowBox:SetBackdropBorderColor(0.75, 0.35, 1.00, 0.95)

    local label = shadowBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER", shadowBox, "CENTER", 0, 40)
    label:SetText("|cffdd99ffStones Ring|r\n|cffa8a8a8(Drag to Move)|r")

    shadowBox:EnableMouse(true)
    shadowBox:RegisterForDrag("LeftButton")
    shadowBox:SetScript("OnDragStart", function(self) anchor:StartMoving() end)
    shadowBox:SetScript("OnDragStop", function(self)
        anchor:StopMovingOrSizing()
        local point, _, relPoint, x, y = anchor:GetPoint()
        db.stonesPosition = { point = point, relativePoint = relPoint, x = x, y = y }
    end)
    anchor.shadowBox = shadowBox

    -- Center Core: Soul Shard Tracker & Purge Button
    local center = CreateCircularSecureButton(anchor, "OneLock_RingStoneCenter", 48, true)
    center:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    center.icon:SetTexture(GetItemTextureSafe(SOUL_SHARD_ITEM_ID))

    -- Hardware click purge handler
    center:SetScript("OnClick", function(self, button)
        if _G.OneLock_Shards and _G.OneLock_Shards.ShardManager and _G.OneLock_Shards.ShardManager.PurgeOneExcessShard then
            _G.OneLock_Shards.ShardManager:PurgeOneExcessShard()
        end
    end)

    center:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local count = GetSoulShardCount()
        local maxShards = (_G.OneLockShardsDB and _G.OneLockShardsDB.maxShards) or 24
        GameTooltip:AddLine("|cff9966ffSoul Shard Core|r", 1, 1, 1)
        GameTooltip:AddLine(string.format("Current Inventory: |cffffd100%d / %d|r", count, maxShards), 0.9, 0.9, 0.9)
        if count > maxShards then
            GameTooltip:AddLine(string.format("|cffff4444Over Cap by %d shard(s)!|r", count - maxShards), 1, 0.3, 0.3)
            GameTooltip:AddLine("|cffffd100Click|r to destroy 1 excess Soul Shard.", 0.4, 1, 0.4)
        else
            GameTooltip:AddLine("Hold to monitor Soul Shard inventory.", 0.7, 0.7, 0.7)
        end
        GameTooltip:Show()
    end)
    center:SetScript("OnLeave", function() GameTooltip:Hide() end)
    stonesButtons.center = center

    -- Clock positioning: Radius R
    local R = db.radius or 50

    -- 9 o'clock: Firestone (x = -R, y = 0)
    local btnFire = CreateCircularSecureButton(anchor, "OneLock_RingFirestone", 34, false)
    btnFire:SetPoint("CENTER", anchor, "CENTER", -R, 0)
    btnFire.icon:SetTexture(GetItemTextureSafe(FIRESTONES[1]))
    btnFire:SetAttribute("type1", "macro")
    btnFire:SetAttribute("macrotext1", "/use Master Firestone\n/use Major Firestone\n/use Greater Firestone\n/use Firestone")
    btnFire:SetAttribute("type2", "macro")
    btnFire:SetAttribute("macrotext2", "/cast Create Firestone")
    btnFire.itemIds = FIRESTONES
    btnFire.spellId = 6366
    btnFire.spellName = "Create Firestone"
    btnFire:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("|cff9966ffFirestone|r", 1, 1, 1)
        GameTooltip:AddLine("|cffffd100Left-Click:|r Apply / Use Firestone", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("|cffffd100Right-Click:|r Cast Create Firestone", 0.9, 0.9, 0.9)
        GameTooltip:Show()
    end)
    btnFire:SetScript("OnLeave", function() GameTooltip:Hide() end)
    stonesButtons.fire = btnFire

    -- 11 o'clock: Healthstone (x = -R * 0.5, y = R * 0.866)
    local btnHealth = CreateCircularSecureButton(anchor, "OneLock_RingHealthstone", 34, false)
    btnHealth:SetPoint("CENTER", anchor, "CENTER", -R * 0.5, R * 0.866)
    btnHealth.icon:SetTexture(GetItemTextureSafe(HEALTHSTONES[1]))
    btnHealth:SetAttribute("type1", "macro")
    btnHealth:SetAttribute("macrotext1", "/use Master Healthstone\n/use Major Healthstone\n/use Greater Healthstone\n/use Healthstone\n/use Lesser Healthstone\n/use Minor Healthstone")
    btnHealth:SetAttribute("type2", "macro")
    btnHealth:SetAttribute("macrotext2", "/cast Create Healthstone")
    btnHealth.itemIds = HEALTHSTONES
    btnHealth.spellId = 620
    btnHealth.spellName = "Create Healthstone"
    btnHealth:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("|cff9966ffHealthstone|r", 1, 1, 1)
        GameTooltip:AddLine("|cffffd100Left-Click:|r Use Healthstone (highest rank in bags)", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("|cffffd100Right-Click:|r Cast Create Healthstone", 0.9, 0.9, 0.9)
        GameTooltip:Show()
    end)
    btnHealth:SetScript("OnLeave", function() GameTooltip:Hide() end)
    stonesButtons.health = btnHealth

    -- 1 o'clock: Soulstone (x = R * 0.5, y = R * 0.866)
    local btnSoul = CreateCircularSecureButton(anchor, "OneLock_RingSoulstone", 34, false)
    btnSoul:SetPoint("CENTER", anchor, "CENTER", R * 0.5, R * 0.866)
    btnSoul.icon:SetTexture(GetItemTextureSafe(SOULSTONES[1]))
    btnSoul:SetAttribute("type1", "macro")
    btnSoul:SetAttribute("macrotext1", "/use [@mouseover,help,nodead][help,nodead][@player] Master Soulstone\n/use [@mouseover,help,nodead][help,nodead][@player] Major Soulstone\n/use [@mouseover,help,nodead][help,nodead][@player] Greater Soulstone\n/use [@mouseover,help,nodead][help,nodead][@player] Soulstone\n/use [@mouseover,help,nodead][help,nodead][@player] Lesser Soulstone\n/use [@mouseover,help,nodead][help,nodead][@player] Minor Soulstone")
    btnSoul:SetAttribute("type2", "macro")
    btnSoul:SetAttribute("macrotext2", "/cast Create Soulstone")
    btnSoul.itemIds = SOULSTONES
    btnSoul.spellId = 693
    btnSoul.spellName = "Create Soulstone"
    btnSoul:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("|cff9966ffSoulstone|r", 1, 1, 1)
        GameTooltip:AddLine("|cffffd100Left-Click:|r Store Soul on Target/Self", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("|cffffd100Right-Click:|r Cast Create Soulstone", 0.9, 0.9, 0.9)
        GameTooltip:Show()
    end)
    btnSoul:SetScript("OnLeave", function() GameTooltip:Hide() end)
    stonesButtons.soul = btnSoul

    -- 3 o'clock: Spellstone (x = R, y = 0)
    local btnSpell = CreateCircularSecureButton(anchor, "OneLock_RingSpellstone", 34, false)
    btnSpell:SetPoint("CENTER", anchor, "CENTER", R, 0)
    btnSpell.icon:SetTexture(GetItemTextureSafe(SPELLSTONES[1]))
    btnSpell:SetAttribute("type1", "macro")
    btnSpell:SetAttribute("macrotext1", "/use Master Spellstone\n/use Major Spellstone\n/use Greater Spellstone\n/use Spellstone")
    btnSpell:SetAttribute("type2", "macro")
    btnSpell:SetAttribute("macrotext2", "/cast Create Spellstone")
    btnSpell.itemIds = SPELLSTONES
    btnSpell.spellId = 2362
    btnSpell.spellName = "Create Spellstone"
    btnSpell:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("|cff9966ffSpellstone|r", 1, 1, 1)
        GameTooltip:AddLine("|cffffd100Left-Click:|r Apply / Use Spellstone", 0.9, 0.9, 0.9)
        GameTooltip:AddLine("|cffffd100Right-Click:|r Cast Create Spellstone", 0.9, 0.9, 0.9)
        GameTooltip:Show()
    end)
    btnSpell:SetScript("OnLeave", function() GameTooltip:Hide() end)
    stonesButtons.spell = btnSpell

    stonesAnchor = anchor
    return anchor
end

-------------------------------------------------------------------------------
-- Ring 2: Demon Summoning Ring & Ritual of Summoning Core
-------------------------------------------------------------------------------
local demonsAnchor = nil
local demonsButtons = {}

local function CreateDemonsRing()
    local db = ns.db
    local anchor = CreateFrame("Frame", "OneLock_DemonsRingAnchor", UIParent)
    anchor:SetSize(52, 52)
    anchor:SetScale(db.demonsScale or 1.0)
    anchor:SetClampedToScreen(true)
    anchor:SetMovable(true)

    local pos = db.demonsPosition or { point = "CENTER", relativePoint = "CENTER", x = 130, y = -100 }
    anchor:ClearAllPoints()
    anchor:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.x or 130, pos.y or -100)

    -- Edit Mode Shadow Box
    local shadowBox = CreateFrame("Frame", "OneLock_DemonsRingShadowBox", anchor, backdropTemplate)
    shadowBox:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    shadowBox:SetSize(160, 130)
    shadowBox:SetFrameStrata("HIGH")
    shadowBox:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    shadowBox:SetBackdropColor(0.20, 0.08, 0.35, 0.65)
    shadowBox:SetBackdropBorderColor(0.75, 0.35, 1.00, 0.95)

    local label = shadowBox:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    label:SetPoint("CENTER", shadowBox, "CENTER", 0, 40)
    label:SetText("|cffdd99ffDemons Ring|r\n|cffa8a8a8(Drag to Move)|r")

    shadowBox:EnableMouse(true)
    shadowBox:RegisterForDrag("LeftButton")
    shadowBox:SetScript("OnDragStart", function(self) anchor:StartMoving() end)
    shadowBox:SetScript("OnDragStop", function(self)
        anchor:StopMovingOrSizing()
        local point, _, relPoint, x, y = anchor:GetPoint()
        db.demonsPosition = { point = point, relativePoint = relPoint, x = x, y = y }
    end)
    anchor.shadowBox = shadowBox

    -- Center Core: Ritual of Summoning
    local center = CreateCircularSecureButton(anchor, "OneLock_RingDemonsCenter", 48, true)
    center:SetPoint("CENTER", anchor, "CENTER", 0, 0)
    center.icon:SetTexture(GetSpellTextureSafe(SPELL_SUMMON_RITUAL))
    center:SetAttribute("type", "spell")
    center:SetAttribute("spell", "Ritual of Summoning")
    center.spellId = SPELL_SUMMON_RITUAL
    center:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("|cff9966ffRitual of Summoning|r", 1, 1, 1)
        GameTooltip:AddLine("Click to begin summoning a party or raid member.", 0.9, 0.9, 0.9)
        GameTooltip:Show()
    end)
    center:SetScript("OnLeave", function() GameTooltip:Hide() end)
    demonsButtons.center = center

    -- Clock positioning: Radius R
    local R = db.radius or 50

    -- 9 o'clock: Summon Imp (x = -R, y = 0)
    local btnImp = CreateCircularSecureButton(anchor, "OneLock_RingImp", 34, false)
    btnImp:SetPoint("CENTER", anchor, "CENTER", -R, 0)
    btnImp.icon:SetTexture(GetSpellTextureSafe(SPELL_SUMMON_IMP))
    btnImp:SetAttribute("type", "spell")
    btnImp:SetAttribute("spell", "Summon Imp")
    btnImp.spellId = SPELL_SUMMON_IMP
    btnImp:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("|cff9966ffSummon Imp|r", 1, 1, 1)
        GameTooltip:AddLine("Click to summon your Imp demon companion.", 0.9, 0.9, 0.9)
        GameTooltip:Show()
    end)
    btnImp:SetScript("OnLeave", function() GameTooltip:Hide() end)
    demonsButtons.imp = btnImp

    -- 11 o'clock: Summon Voidwalker (x = -R * 0.5, y = R * 0.866)
    local btnVW = CreateCircularSecureButton(anchor, "OneLock_RingVoidwalker", 34, false)
    btnVW:SetPoint("CENTER", anchor, "CENTER", -R * 0.5, R * 0.866)
    btnVW.icon:SetTexture(GetSpellTextureSafe(SPELL_SUMMON_VOIDWALKER))
    btnVW:SetAttribute("type", "spell")
    btnVW:SetAttribute("spell", "Summon Voidwalker")
    btnVW.spellId = SPELL_SUMMON_VOIDWALKER
    btnVW:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("|cff9966ffSummon Voidwalker|r", 1, 1, 1)
        GameTooltip:AddLine("Click to summon your Voidwalker demon companion.", 0.9, 0.9, 0.9)
        GameTooltip:Show()
    end)
    btnVW:SetScript("OnLeave", function() GameTooltip:Hide() end)
    demonsButtons.vw = btnVW

    -- 1 o'clock: Summon Succubus (x = R * 0.5, y = R * 0.866)
    local btnSucc = CreateCircularSecureButton(anchor, "OneLock_RingSuccubus", 34, false)
    btnSucc:SetPoint("CENTER", anchor, "CENTER", R * 0.5, R * 0.866)
    btnSucc.icon:SetTexture(GetSpellTextureSafe(SPELL_SUMMON_SUCCUBUS))
    btnSucc:SetAttribute("type", "spell")
    btnSucc:SetAttribute("spell", "Summon Succubus")
    btnSucc.spellId = SPELL_SUMMON_SUCCUBUS
    btnSucc:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("|cff9966ffSummon Succubus|r", 1, 1, 1)
        GameTooltip:AddLine("Click to summon your Succubus demon companion.", 0.9, 0.9, 0.9)
        GameTooltip:Show()
    end)
    btnSucc:SetScript("OnLeave", function() GameTooltip:Hide() end)
    demonsButtons.succ = btnSucc

    -- 3 o'clock: Summon Felhunter (x = R, y = 0)
    local btnFel = CreateCircularSecureButton(anchor, "OneLock_RingFelhunter", 34, false)
    btnFel:SetPoint("CENTER", anchor, "CENTER", R, 0)
    btnFel.icon:SetTexture(GetSpellTextureSafe(SPELL_SUMMON_FELHUNTER))
    btnFel:SetAttribute("type", "spell")
    btnFel:SetAttribute("spell", "Summon Felhunter")
    btnFel.spellId = SPELL_SUMMON_FELHUNTER
    btnFel:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("|cff9966ffSummon Felhunter|r", 1, 1, 1)
        GameTooltip:AddLine("Click to summon your Felhunter demon companion.", 0.9, 0.9, 0.9)
        GameTooltip:Show()
    end)
    btnFel:SetScript("OnLeave", function() GameTooltip:Hide() end)
    demonsButtons.fel = btnFel

    demonsAnchor = anchor
    return anchor
end

-------------------------------------------------------------------------------
-- Dynamic Ring Updates (Bag Counts, Desaturation, Cooldowns)
-------------------------------------------------------------------------------
function Rings:UpdateStones()
    if not stonesButtons.center then return end

    -- 1. Center: Soul Shard Count & Purge Alert
    local shardCount = GetSoulShardCount()
    local maxShards = (_G.OneLockShardsDB and _G.OneLockShardsDB.maxShards) or 24
    stonesButtons.center.countText:SetText(tostring(shardCount))

    if shardCount > maxShards then
        stonesButtons.center.countText:SetTextColor(1.0, 0.25, 0.25, 1.0) -- Alert Crimson
        stonesButtons.center.border:SetVertexColor(1.0, 0.25, 0.25, 1.0)
    else
        stonesButtons.center.countText:SetTextColor(1.0, 1.0, 1.0, 1.0) -- Normal White
        stonesButtons.center.border:SetVertexColor(0.75, 0.35, 1.00, 0.95)
    end

    -- 2. Satellite Stones: Bags & Cooldowns
    local satellites = {
        stonesButtons.fire,
        stonesButtons.health,
        stonesButtons.soul,
        stonesButtons.spell,
    }

    for _, btn in ipairs(satellites) do
        if btn and btn.itemIds then
            local count, highestId = CountItemsInBags(btn.itemIds)
            local isKnown = (count > 0)
                or (btn.spellId and IsSpellKnownSafe(btn.spellId))
                or (btn.spellName and IsSpellKnownSafe(btn.spellName))

            if not isKnown then
                btn:Hide()
            else
                btn:Show()
                local displayId = highestId or btn.itemIds[1]
                btn.icon:SetTexture(GetItemTextureSafe(displayId))

                if count > 0 then
                    btn.icon:SetDesaturated(false)
                    btn.countText:SetText(tostring(count))
                    btn.countText:SetTextColor(1.0, 1.0, 1.0, 1.0)
                    btn.countText:Show()
                    btn.border:SetVertexColor(0.85, 0.60, 1.00, 1.0)
                else
                    btn.icon:SetDesaturated(true)
                    btn.countText:SetText("0")
                    btn.countText:SetTextColor(0.70, 0.70, 0.70, 0.85)
                    btn.countText:Show()
                    btn.border:SetVertexColor(0.35, 0.30, 0.45, 0.8)
                end

                -- Item cooldown (protected against secret values in combat)
                local start, dur, enable = GetItemCooldownSafe(displayId)
                local hasCooldown = false
                if start and dur and enable then
                    if not IsSecret(dur) and not IsSecret(start) and not IsSecret(enable) then
                        if dur > 0 and (enable == 1 or enable == true) then
                            hasCooldown = true
                            if btn.cd and btn.cd.SetCooldown then
                                btn.cd:SetCooldown(start, dur)
                            end
                        end
                    else
                        -- Under secret taint, pass start and dur directly to SetCooldown without comparisons
                        hasCooldown = true
                        if btn.cd and btn.cd.SetCooldown then
                            pcall(btn.cd.SetCooldown, btn.cd, start, dur)
                        end
                    end
                end
                if not hasCooldown and btn.cd and btn.cd.Clear then
                    btn.cd:Clear()
                end
            end
        end
    end
end

function Rings:UpdateDemons()
    local spells = {
        demonsButtons.center,
        demonsButtons.imp,
        demonsButtons.vw,
        demonsButtons.succ,
        demonsButtons.fel,
    }

    for _, btn in ipairs(spells) do
        if btn and btn.spellId then
            local isKnown = IsSpellKnownSafe(btn.spellId)
            if not isKnown then
                btn:Hide()
            else
                btn:Show()
                local start, dur, enable = GetSpellCooldownSafe(btn.spellId)
                local hasCooldown = false
                if start and dur and enable then
                    if not IsSecret(dur) and not IsSecret(start) and not IsSecret(enable) then
                        if dur > 0 and (enable == 1 or enable == true) then
                            hasCooldown = true
                            if btn.cd and btn.cd.SetCooldown then
                                btn.cd:SetCooldown(start, dur)
                            end
                        end
                    else
                        -- Under secret taint, pass start and dur directly to SetCooldown without comparisons
                        hasCooldown = true
                        if btn.cd and btn.cd.SetCooldown then
                            pcall(btn.cd.SetCooldown, btn.cd, start, dur)
                        end
                    end
                end
                if not hasCooldown and btn.cd and btn.cd.Clear then
                    btn.cd:Clear()
                end
            end
        end
    end
end

-------------------------------------------------------------------------------
-- Edit Mode & Display Settings
-------------------------------------------------------------------------------
function Rings:ApplySettings()
    local db = ns.db
    if stonesAnchor then
        stonesAnchor:SetScale(db.stonesScale or 1.0)
        if db.showStonesRing then stonesAnchor:Show() else stonesAnchor:Hide() end
        if db.locked then
            stonesAnchor.shadowBox:Hide()
        else
            stonesAnchor.shadowBox:Show()
        end
    end

    if demonsAnchor then
        demonsAnchor:SetScale(db.demonsScale or 1.0)
        if db.showDemonsRing then demonsAnchor:Show() else demonsAnchor:Hide() end
        if db.locked then
            demonsAnchor.shadowBox:Hide()
        else
            demonsAnchor.shadowBox:Show()
        end
    end

    local R = db.radius or 50
    local SQRT3_OVER_2 = 0.8660254037844386
    local coords = {
        [9]  = { -R, 0 },
        [11] = { -R * 0.5, R * SQRT3_OVER_2 },
        [1]  = {  R * 0.5, R * SQRT3_OVER_2 },
        [3]  = {  R, 0 }
    }

    local hourToStone = {
        [9]  = stonesButtons.fire,
        [11] = stonesButtons.health,
        [1]  = stonesButtons.soul,
        [3]  = stonesButtons.spell,
    }
    for hour, btn in pairs(hourToStone) do
        local pt = coords[hour]
        if btn and pt and stonesAnchor then
            btn:ClearAllPoints()
            btn:SetPoint("CENTER", stonesAnchor, "CENTER", pt[1], pt[2])
        end
    end

    local hourToDemon = {
        [9]  = demonsButtons.imp,
        [11] = demonsButtons.vw,
        [1]  = demonsButtons.succ,
        [3]  = demonsButtons.fel,
    }
    for hour, btn in pairs(hourToDemon) do
        local pt = coords[hour]
        if btn and pt and demonsAnchor then
            btn:ClearAllPoints()
            btn:SetPoint("CENTER", demonsAnchor, "CENTER", pt[1], pt[2])
        end
    end
end

function Rings:ToggleLock()
    ns.db.locked = not ns.db.locked
    self:ApplySettings()
    return ns.db.locked
end

function Rings:ResetPositions()
    ns.db.stonesPosition = { point = "CENTER", relativePoint = "CENTER", x = -130, y = -100 }
    ns.db.demonsPosition = { point = "CENTER", relativePoint = "CENTER", x = 130, y = -100 }
    if stonesAnchor then
        stonesAnchor:ClearAllPoints()
        stonesAnchor:SetPoint("CENTER", UIParent, "CENTER", -130, -100)
    end
    if demonsAnchor then
        demonsAnchor:ClearAllPoints()
        demonsAnchor:SetPoint("CENTER", UIParent, "CENTER", 130, -100)
    end
end

-------------------------------------------------------------------------------
-- Engine Initialization
-------------------------------------------------------------------------------
function Rings:Initialize()
    local _, playerClass = UnitClass("player")
    if playerClass ~= "WARLOCK" then
        return
    end

    CreateStonesRing()
    CreateDemonsRing()
    self:ApplySettings()

    local eventFrame = CreateFrame("Frame", "OneLock_Rings_EventFrame")
    eventFrame:RegisterEvent("BAG_UPDATE")
    eventFrame:RegisterEvent("BAG_UPDATE_DELAYED")
    eventFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    eventFrame:RegisterEvent("SPELL_UPDATE_USABLE")
    eventFrame:RegisterEvent("SPELLS_CHANGED")
    eventFrame:RegisterEvent("LEARNED_SPELL_IN_TAB")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")

    eventFrame:SetScript("OnEvent", function(self, event)
        Rings:UpdateStones()
        Rings:UpdateDemons()
    end)

    Rings:UpdateStones()
    Rings:UpdateDemons()
    ns:Log("INFO", "Rings", "OneLock Radial Rings initialized with clock geometry.")
end
