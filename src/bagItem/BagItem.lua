local NAME, ADDON = ...

local item = {}

local function DJBagsGetNumBankSlots()
    if GetNumBankSlots then
        return GetNumBankSlots()
    elseif C_Bank and C_Bank.GetNumBankSlots then
        return C_Bank.GetNumBankSlots()
    end
    return 0, true
end

local function DJBagsGetBankSlotCost(slot)
    if GetBankSlotCost then
        return GetBankSlotCost(slot)
    elseif C_Bank and C_Bank.GetBankSlotCost then
        return C_Bank.GetBankSlotCost(slot)
    end
    return -1
end

function DJBagsContainerIDToInventoryID(bagID)
    if C_Container and C_Container.ContainerIDToInventoryID then
        return C_Container.ContainerIDToInventoryID(bagID)
    elseif ContainerIDToInventoryID then
        return ContainerIDToInventoryID(bagID)
    elseif BankButtonIDToInvSlotID then
        return BankButtonIDToInvSlotID(bagID)
    end
    return bagID
end

function DJBagsBagItemLoad(button, slot, id)
    for k, v in pairs(item) do
        button[k] = v
    end

    button:Init(id, slot)
end

function item:Init(id, slot)
    self:SetID(id)
    self.slot = slot

    self:SetScript('OnDragStart', self.DragItem)
    self:SetScript('OnReceiveDrag', self.PlaceOrPickup)
    self:SetScript('OnClick', function (self, ...)
        if self.buy then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
            StaticPopup_Show("CONFIRM_BUY_BANK_SLOT")
        else
            self:PlaceOrPickup(...)
        end
    end)
    self:SetScript('OnEnter', self.OnEnter)
    self:SetScript('OnLeave', self.OnLeave)
end

function item:Update()
    local numBankSlots = DJBagsGetNumBankSlots()
    if self.slot ~= REAGENTBAG_CONTAINER and self.slot - NUM_BAG_SLOTS > numBankSlots then
        local cost = DJBagsGetBankSlotCost(self.slot - 1)
        self:SetCost(cost)
        return
    end
    PaperDollItemSlotButton_Update(self)
    local slotcount = C_Container.GetContainerNumSlots(self.slot)
    if slotcount > 0 then
        self.Count:SetText(tostring(slotcount))
        self.Count:Show()
    else
        self.Count:Hide()
    end
    self.buy = nil
end

function item:UpdateLock()
    PaperDollItemSlotButton_UpdateLock(self)
end

function item:PlaceOrPickup()
    local placed = PutItemInBag(self:GetID())
    if not placed then
        PickupBagFromSlot(self:GetID())
    end
end

function item:OnEnter()
    if self:GetRight() >= (GetScreenWidth() / 2) then
        GameTooltip:SetOwner(self, 'ANCHOR_LEFT')
    else
        GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
    end

    local hasItem, hasCooldown, repairCost, speciesID, level, breedQuality, maxHealth, power, speed, name = GameTooltip:SetInventoryItem("player", self:GetID())
    if(speciesID and speciesID > 0) then
        BattlePetToolTip_Show(speciesID, level, breedQuality, maxHealth, power, speed, name)
        CursorUpdate(self)
        return;
    end

    if (not IsInventoryItemProfessionBag("player", self:GetID())) then
        local start = _G.LE_BAG_FILTER_FLAG_EQUIPMENT or 1
        local finish = _G.NUM_LE_BAG_FILTER_FLAGS or (#BAG_FILTER_LABELS or 0)

        for i = start, finish do
            if (GetBankBagSlotFlag(self:GetID(), i)) then
                local label = BAG_FILTER_LABELS[i] or BAG_FILTER_LABELS[i - start + 1]
                if label then
                    GameTooltip:AddLine(BAG_FILTER_ASSIGNED_TO:format(label))
                end
                break;
            end
        end
    end

    GameTooltip:Show()
    CursorUpdate(self)

    ADDON.eventManager:Fire('DJBAGS_BAG_HOVER', self.slot, true)
end

function item:SetCost(cost)
    if cost > -1 then
        self.IconBorder:Show()
        self.IconBorder:SetVertexColor(1, 0, 0, 1)
        self.Count:Show()
        self.Count:SetText(cost/10000 .. "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t")
        BankFrame.nextSlotCost = cost
        self.buy = true
    end
end

function item:OnLeave()
    GameTooltip_Hide()
    ResetCursor()
    
    ADDON.eventManager:Fire('DJBAGS_BAG_HOVER', self.slot, false)
end
