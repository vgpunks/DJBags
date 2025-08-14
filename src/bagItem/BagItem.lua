local NAME, ADDON = ...

local item = {}

local OPEN_TAB_SETTINGS_EVENT = BankPanelTabSettingsMenuMixin and BankPanelTabSettingsMenuMixin.Event.OpenTabSettingsRequested or "OpenTabSettingsRequested"
local BANK_TAB_CLICKED_EVENT = BankPanelMixin and BankPanelMixin.Event.BankTabClicked or "BankTabClicked"

local function isBankTabSlot(slot)
    if slot >= Enum.BagIndex.CharacterBankTab_1 and slot <= Enum.BagIndex.CharacterBankTab_6 then
        return true
    end
    if Enum.BagIndex.AccountBankTab_1 and Enum.BagIndex.AccountBankTab_6 then
        if slot >= Enum.BagIndex.AccountBankTab_1 and slot <= Enum.BagIndex.AccountBankTab_6 then
            return true
        end
    end
    return false
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

    -- Allow both left and right button clicks so we can open bank tab settings
    self:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    self:SetScript('OnDragStart', self.DragItem)
    self:SetScript('OnReceiveDrag', self.PlaceOrPickup)
    self:SetScript('OnClick', function (self, button, ...)
        if self.buy then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
            StaticPopup_Show("CONFIRM_BUY_BANK_SLOT")
            return
        end

        -- Right-clicking a bank tab should open the default bank tab settings menu
        if button == "RightButton" and BankFrame and BankFrame.BankPanel and BankFrame.BankPanel.TabSettingsMenu and isBankTabSlot(self.slot) then
            BankFrame.BankPanel.TabSettingsMenu:TriggerEvent(OPEN_TAB_SETTINGS_EVENT, self.slot)
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
            BankFrame.BankPanel:TriggerEvent(BANK_TAB_CLICKED_EVENT, self.slot)
            return
        end

        self:PlaceOrPickup(button, ...)
    end)
    self:SetScript('OnEnter', self.OnEnter)
    self:SetScript('OnLeave', self.OnLeave)
end

function item:Update()
    local slot = self.slot
    local isCharacterBankTab = slot >= Enum.BagIndex.CharacterBankTab_1 and slot <= Enum.BagIndex.CharacterBankTab_6

    if C_Bank and isCharacterBankTab then
        -- Determine if this tab has been purchased
        local purchasedIDs = C_Bank.FetchPurchasedBankTabIDs(Enum.BankType.Character)
        local purchased = false
        if purchasedIDs then
            for _, id in ipairs(purchasedIDs) do
                if id == slot then
                    purchased = true
                    break
                end
            end
        end

        if not purchased then
            local cost = -1
            if C_Bank.FetchNextPurchasableBankTabData then
                local data = C_Bank.FetchNextPurchasableBankTabData(Enum.BankType.Character)
                if data and data.tabCost then
                    cost = data.tabCost
                end
            end
            self:SetCost(cost)
            return
        end

        -- Tab is purchased, fetch its icon
        local icon
        if C_Bank.FetchPurchasedBankTabData then
            local tabData = C_Bank.FetchPurchasedBankTabData(Enum.BankType.Character)
            if tabData then
                for _, info in ipairs(tabData) do
                    if info.ID == slot then
                        icon = info.icon
                        break
                    end
                end
            end
        end
        if icon then
            SetItemButtonTexture(self, icon)
        end

        local slotcount = C_Container.GetContainerNumSlots(slot)
        if slotcount > 0 then
            self.Count:SetText(tostring(slotcount))
            self.Count:Show()
        else
            self.Count:Hide()
        end
        self.buy = nil
        return
    end

    -- Fallback to default behavior for non-bank tabs
    PaperDollItemSlotButton_Update(self)
    local slotcount = C_Container.GetContainerNumSlots(slot)
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
        if BAG_FILTER_LABELS then
            for i, label in ipairs(BAG_FILTER_LABELS) do
                if ( GetBankBagSlotFlag(self:GetID(), i) ) then
                    GameTooltip:AddLine(BAG_FILTER_ASSIGNED_TO:format(label))
                    break;
                end
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
