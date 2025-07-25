local ADDON_NAME, ADDON = ...

-- Convenience local for new container API
local Container = C_Container

-- WoW API version differences mean that IsContainerItemAnUpgrade might not be
-- available.  Create a local reference if possible so calls are safe.
local UpgradeCheck = _G.IsContainerItemAnUpgrade
if not UpgradeCheck and C_Item and C_Item.IsItemAnUpgrade then
    -- Use the C_Item API if present
    UpgradeCheck = function(bag, slot)
        return C_Item.IsItemAnUpgrade(ItemLocation:CreateFromBagAndSlot(bag, slot))
    end
end

local item = {}
item.__index = item

-- can I mog it config
local itemMogitFunc = nil
if CIMI_AddToFrame then
    itemMogitFunc = function(self)
        if not self or not self:GetParent() then return end
        if not CIMI_CheckOverlayIconEnabled(self) then
            self.CIMIIconTexture:SetShown(false)
            self:SetScript("OnUpdate", nil)
            return
        end
        local bag, slot = self:GetParent():GetParent():GetID(), self:GetParent():GetID()
        CIMI_SetIcon(self, itemMogitFunc, CanIMogIt:GetTooltipText(nil, bag, slot))
    end
end

local function InitItem(self, bag, slot)
	self:SetID(slot)

    self.quest = _G[self:GetName() .. "IconQuestTexture"]
    self.cooldown = _G[self:GetName() .. "Cooldown"]
    self.itemLevel = self:CreateFontString(self:GetName() .. 'ItemLevel', 'ARTWORK', 'NumberFontNormal')
    self.itemLevel:SetPoint('BOTTOMRIGHT', 2, 2)

    if MSQ then
        local myGroup = MSQ:Group(ADDON_NAME)
        myGroup:AddButton(self, {
            Button = self,
            Border = self.IconBorder,
            Icon = self.icon or _G[self:GetName() .. "IconTexture"],
        })
    end

    self:HookScript('OnClick', self.OnClick)

    -- hook into can i mog it
    if CIMI_AddToFrame then
        CIMI_AddToFrame(self, itemMogitFunc)
    end
end

function ADDON:NewItem(parent, slot)
    local bag = parent:GetID()
	assert(bag and type(bag) == 'number', 'Parent is required to be a bag with ID set the bag number')
	assert(slot and type(slot) == 'number', 'Slot required as integer value')

	local object = CreateFrame('ItemButton', string.format('DJBagsItem_%d_%d', bag, slot), parent,
		bag == BANK_CONTAINER and 'BankItemButtonGenericTemplate' or
            bag == REAGENTBANK_CONTAINER and 'ReagentBankItemButtonGenericTemplate' or
            'ContainerFrameItemButtonTemplate')

	for k, v in pairs(item) do
		object[k] = v
	end

	InitItem(object, bag, slot)

	return object
end

function item:OnClick(button)
    if self.id and IsAltKeyDown() and button == 'LeftButton' then
        DJBagsCategoryDialog:DisplayForItem(self.id, self.name)
    end
    if self.id and IsAltKeyDown() and button == 'RightButton' then
        DJBags_DB_Char.newItems[self.id] = false
        ADDON.eventManager:Fire("NewItemCleared")
    end
end

local function UpdateQuest(self, isQuestItem, questId, isActive)
    if (questId and not isActive) then
        self.quest:SetTexture(TEXTURE_ITEM_QUEST_BANG)
        self.quest:Show()
    elseif (questId or isQuestItem) then
        self.quest:SetTexture(TEXTURE_ITEM_QUEST_BORDER)
        self.quest:Show()
    else
        self.quest:Hide()
    end
end

local function UpdateNewItemAnimations(self, isNewItem, isBattlePayItem, quality)
    if (isNewItem) then
        if (isBattlePayItem) then
            self.NewItemTexture:Hide()
            self.BattlepayItemTexture:Show()
        else
            if (quality and NEW_ITEM_ATLAS_BY_QUALITY[quality]) then
                self.NewItemTexture:SetAtlas(NEW_ITEM_ATLAS_BY_QUALITY[quality]);
            else
                self.NewItemTexture:SetAtlas("bags-glow-white");
            end
            self.BattlepayItemTexture:Hide();
            self.NewItemTexture:Show();
        end
        if (not self.flashAnim:IsPlaying() and not self.newitemglowAnim:IsPlaying()) then
            self.flashAnim:Play();
            self.newitemglowAnim:Play();
        end
    else
        self.BattlepayItemTexture:Hide();
        self.NewItemTexture:Hide();
        if (self.flashAnim:IsPlaying() or self.newitemglowAnim:IsPlaying()) then
            self.flashAnim:Stop();
            self.newitemglowAnim:Stop();
        end
    end
end

local function UpdateFiltered(self, filtered)
    if (filtered) then
        self.searchOverlay:Show();
    else
        self.searchOverlay:Hide();
    end
end

local function UpdateILevel(self, equipable, quality, level)
    if equipable then
        if quality and quality >= Enum.ItemQuality.Common then
            self.itemLevel:SetVertexColor(BAG_ITEM_QUALITY_COLORS[quality].r, BAG_ITEM_QUALITY_COLORS[quality].g, BAG_ITEM_QUALITY_COLORS[quality].b)
        else
            self.itemLevel:SetVertexColor(1, 1, 1, 1)
        end
        self.itemLevel:SetText(level)
        self.itemLevel:Show()
    else
        self.itemLevel:Hide()
    end
end

local function UpdateCooldown(self)
    if not Container.GetContainerItemID(self:GetParent():GetID(), self:GetID()) then
        self.cooldown:Hide()
        return
    end

    local start, duration, enable = Container.GetContainerItemCooldown(self:GetParent():GetID(), self:GetID());
    CooldownFrame_Set(self.cooldown, start, duration, enable);
    if (duration > 0 and enable == 0) then
        SetItemButtonTextureVertexColor(self, 0.4, 0.4, 0.4)
    else
        SetItemButtonTextureVertexColor(self, 1, 1, 1)
    end
end

local function UpdateUpgrade(self)
    self.timeSinceUpgradeCheck = 0;

    if UpgradeCheck then
        local itemIsUpgrade = UpgradeCheck(self:GetParent():GetID(), self:GetID());
        if ( itemIsUpgrade == nil ) then -- nil means data wasn't ready to check.
            self.UpgradeIcon:SetShown(false);
            self:SetScript("OnUpdate", OnItemUpdate);
        else
            self.UpgradeIcon:SetShown(itemIsUpgrade);
            self:SetScript("OnUpdate", nil);
        end
    else
        -- Upgrade information not available on this client version
        self.UpgradeIcon:SetShown(false);
        self:SetScript("OnUpdate", nil);
    end
end

local ITEM_UPGRADE_CHECK_TIME = 0.5
local function OnItemUpdate(self, elapsed)
    self.timeSinceUpgradeCheck = self.timeSinceUpgradeCheck + elapsed

    if (self.timeSinceUpgradeCheck >= ITEM_UPGRADE_CHECK_TIME) then
        UpdateUpgrade(self)
    end
end

function item:Update()
    local info = Container.GetContainerItemInfo(self:GetParent():GetID(), self:GetID())
    local texture, count, locked, quality, link, filtered, id
    if info then
        texture = info.iconFileID
        count = info.stackCount
        locked = info.isLocked
        quality = info.quality
        link = info.hyperlink
        filtered = info.isFiltered
        id = info.itemID
    end
    -- Only call IsEquippableItem when we have a valid item ID
    local equipable = id and IsEquippableItem(id)

    local name, level, classId, class, subClass
    if id then
        name, _, _, level, _, class, subClass, _, _, _, _, classId = GetItemInfo(id)
    end
    local isEquipment = equipable or classId == LE_ITEM_CLASS_ARMOR or classId == LE_ITEM_CLASS_WEAPON
    local bag = self:GetParent():GetID()

    self.id = id
    self.name = name or ''
    self.quality = quality or 0
    self.ilevel = level or 0
    self.link = link
    self.classId = classId
    self.class = class
    self.subClass = subClass
    self.count = id and (count or 1) or (self.count or 1)
    self.hasItem = nil

    if isEquipment then
        level = DJBagsTooltip:GetItemLevel(bag, self:GetID()) or level
    elseif classId == LE_ITEM_CLASS_CONTAINER then
        -- TODO set count to number of slots
    end

    UpdateILevel(self, equipable, quality, level)
    if bag == BANK_CONTAINER or bag == REAGENTBANK_CONTAINER then
        BankFrameItemButton_Update(self)
    else
        local questInfo1, questInfo2, questInfo3 = Container.GetContainerItemQuestInfo(bag, self:GetID())
        local isQuestItem, questId, isActive
        if type(questInfo1) == "table" then
            isQuestItem = questInfo1.isQuestItem
            questId = questInfo1.questID
            isActive = questInfo1.isActive
        else
            isQuestItem = questInfo1
            questId = questInfo2
            isActive = questInfo3
        end
        local isNewItem = C_NewItems.IsNewItem(bag, self:GetID())
        local isBattlePayItem
        if Container and Container.IsBattlePayItem then
            isBattlePayItem = Container.IsBattlePayItem(bag, self:GetID())
        elseif IsBattlePayItem then
            isBattlePayItem = IsBattlePayItem(bag, self:GetID())
        else
            isBattlePayItem = false
        end

        self.hasItem = true

        if quality and MSQ then
            if quality >= Enum.ItemQuality.Poor and BAG_ITEM_QUALITY_COLORS[quality] then
                self.IconBorder:Show();
                self.IconBorder:SetVertexColor(BAG_ITEM_QUALITY_COLORS[quality].r, BAG_ITEM_QUALITY_COLORS[quality].g, BAG_ITEM_QUALITY_COLORS[quality].b);
            else
                self.IconBorder:Hide();
            end
        else
            self.IconBorder:Hide();
        end

        SetItemButtonTexture(self, texture)
        SetItemButtonQuality(self, quality, id)
        if quality == Enum.ItemQuality.Common then
            self.IconBorder:Show();
            self.IconBorder:SetVertexColor(1, 1, 1);
        elseif quality == Enum.ItemQuality.Poor then
            local color
            if BAG_ITEM_QUALITY_COLORS then
                color = BAG_ITEM_QUALITY_COLORS[Enum.ItemQuality.Poor]
            end
            if color then
                self.IconBorder:Show();
                self.IconBorder:SetVertexColor(color.r, color.g, color.b);
            else
                self.IconBorder:Show();
                self.IconBorder:SetVertexColor(0.62, 0.62, 0.62);
            end
        end
        SetItemButtonCount(self, count)
        SetItemButtonDesaturated(self, locked)
        UpdateQuest(self, isQuestItem, questId, isActive)
        UpdateNewItemAnimations(self, isNewItem, isBattlePayItem, quality)
        UpdateFiltered(self, filtered)
        UpdateCooldown(self)
        UpdateUpgrade(self)
        self:UpdateItemContextMatching()
    end
end

function item:UpdateCooldown()
    UpdateCooldown(self)
end

function item:UpdateSearch()
    local info = Container.GetContainerItemInfo(self:GetParent():GetID(), self:GetID())
    local filtered = info and info.isFiltered
    self:SetFiltered(filtered)
end

function item:UpdateLock(locked)
    local locked = locked
    if locked == nil then
        local info = Container.GetContainerItemInfo(self:GetParent():GetID(), self:GetID())
        locked = info and info.isLocked
    end
    SetItemButtonDesaturated(self, locked);
end

function item:SetFiltered(filtered)
    UpdateFiltered(self, filtered, self.id)
end

function item:IncrementCount(count)
    if self.count == 0 then
        self.count = 1
    end
    count = count == 0 and 1 or count or 1

    self.count = self.count + count
    SetItemButtonCount(self, self.count)
end
