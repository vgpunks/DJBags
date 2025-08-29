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
        local purchasedIDs = C_Bank.FetchPurchasedBankTabIDs(Enum.BankType.Character)
        local purchased = false
        if purchasedIDs then
            for _, id in ipairs(purchasedIDs) do
                if id == tabIndex or id == slot then
                    purchased = true
                    break
                end
            end
        end

        if not purchased then
            self:Hide()
            self.buy = nil
            return
        end

        self:Show()

        -- Tab is purchased, fetch its icon from the bank data.  The icon
        -- chosen for a bank tab is not tied to the inventory item placed in
        -- the slot, so prefer the information returned by the C_Bank API and
        -- only fall back to the inventory texture as a last resort.
        local icon

        if C_Bank then
            -- Newer API builds may expose tab data directly via a helper
            -- function.  Attempt to use it first.
            if C_Bank.GetBankTabInfo then
                local info = C_Bank.GetBankTabInfo(Enum.BankType.Character, tabIndex)
                if info then
                    icon = info.icon or info.iconFileID or info.iconTexture
                end
            end

            -- If the direct call was unavailable or returned nothing, fall
            -- back to iterating the purchased tab data.
            if not icon and C_Bank.FetchPurchasedBankTabData then
                local tabData = C_Bank.FetchPurchasedBankTabData(Enum.BankType.Character)
                if tabData then
                    local info = tabData[tabIndex] or tabData[slot]
                    if not info then
                        for _, data in ipairs(tabData) do
                            local infoID = data.ID or data.bankTabID
                            if infoID == tabIndex or infoID == slot then
                                info = data
                                break
                            end
                        end
                    end
                    if info then
                        icon = info.icon or info.iconFileID or info.iconTexture
                    end
                end
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
