local NAME, ADDON = ...

local item = {}

local function isBankTabSlot(slot)
    if Enum.BagIndex.CharacterBankTab_1 and Enum.BagIndex.CharacterBankTab_6 then
        if slot >= Enum.BagIndex.CharacterBankTab_1 and slot <= Enum.BagIndex.CharacterBankTab_6 then
            return true
        end
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
    -- Some game versions may not provide slot or inventory IDs for all bank
    -- tabs.  Guard against nil so SetID never receives an invalid value.
    self:SetID(id or slot or 0)
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

        -- Right-clicking a bank tab should open the settings menu
        if button == "RightButton" and BankFrame and isBankTabSlot(self.slot) then
            local tabIndex, bankType

            if Enum.BagIndex.AccountBankTab_1 and Enum.BagIndex.AccountBankTab_6
                and self.slot >= Enum.BagIndex.AccountBankTab_1
                and self.slot <= Enum.BagIndex.AccountBankTab_6
            then
                tabIndex = self.slot - Enum.BagIndex.AccountBankTab_1 + 1
                bankType = Enum.BankType and Enum.BankType.Account
            else
                tabIndex = self.slot - Enum.BagIndex.CharacterBankTab_1 + 1
                bankType = Enum.BankType and Enum.BankType.Character
            end

            local menu = ADDON:GetBankTabSettingsMenu()
            menu:Open(bankType, tabIndex)

            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
            return
        end

        self:PlaceOrPickup(button, ...)
    end)
    self:SetScript('OnEnter', self.OnEnter)
    self:SetScript('OnLeave', self.OnLeave)
end

function item:Update()
    local slot = self.slot
    if not slot then
        PaperDollItemSlotButton_Update(self)
        self.Count:Hide()
        self.buy = nil
        return
    end

    local isCharacterBankTab = false
    if Enum.BagIndex.CharacterBankTab_1 and Enum.BagIndex.CharacterBankTab_6 then
        isCharacterBankTab = slot >= Enum.BagIndex.CharacterBankTab_1 and slot <= Enum.BagIndex.CharacterBankTab_6
    end

    if C_Bank and isCharacterBankTab then
        local tabIndex = slot - Enum.BagIndex.CharacterBankTab_1 + 1

        -- Determine if this tab has been purchased
        local purchasedIDs = C_Bank.GetPurchasedBankTabIDs and C_Bank.GetPurchasedBankTabIDs(Enum.BankType.Character) or {}
        local purchased = false
        for _, id in ipairs(purchasedIDs) do
            if id == tabIndex then
                purchased = true
                break
            end
        end

        if not purchased then
            self:Hide()
            self.buy = nil
            return
        end

        self:Show()

        -- Fetch the tab icon from the bank data.  The icon chosen for a bank
        -- tab is not tied to the inventory item placed in the slot, so prefer
        -- the information returned by the C_Bank API and only fall back to the
        -- inventory texture as a last resort.
        local icon
        if C_Bank.GetBankTabSettings then
            local info = C_Bank.GetBankTabSettings(Enum.BankType.Character, tabIndex)
            if info then
                icon = info.icon
            end
        end

        -- As a final fallback, use the icon of the item placed in the bank
        -- tab slot if one exists.
        if not icon then
            icon = GetInventoryItemTexture("player", self:GetID())
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

    if not isBankTabSlot(self.slot) then
        ADDON.eventManager:Fire('DJBAGS_BAG_HOVER', self.slot, true)
    end
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

    if not isBankTabSlot(self.slot) then
        ADDON.eventManager:Fire('DJBAGS_BAG_HOVER', self.slot, false)
    end
end
