local ADDON_NAME, ADDON = ...

local bank = {}
bank.__index = bank

function DJBagsHideBlizzardBank()
    BankFrame:SetAlpha(0)
    BankFrame:EnableMouse(false)
    BankFrame:SetScale(0.0001)
    BankFrame:ClearAllPoints()
    BankFrame:SetPoint('TOPLEFT', UIParent, 'TOPLEFT', -9999, -9999)
end

function DJBagsRegisterBankBagContainer(self, bags, bankType)
    DJBagsRegisterBaseBagContainer(self, bags)

    -- Save the original BAG_UPDATE implementation so we can gate updates
    -- while the other bank type is active.
    self.baseBAG_UPDATE = self.BAG_UPDATE

    for k, v in pairs(bank) do
        self[k] = v
    end

    -- Track which bank type this container represents and if it's active.
    self.bankType = bankType or Enum.BankType and Enum.BankType.Character or 0
    self.isActive = self.bankType == (Enum.BankType and Enum.BankType.Character or 0)

    ADDON.eventManager:Add('BANKFRAME_OPENED', self)
    ADDON.eventManager:Add('BANKFRAME_CLOSED', self)
    ADDON.eventManager:Add('PLAYERBANKSLOTS_CHANGED', self)
    ADDON.eventManager:Add('PLAYERBANKBAGSLOTS_CHANGED', self)
    -- Warband bank tabs use separate events when purchased. Ensure we listen
    -- for those so newly unlocked tabs become visible without a reload.
    ADDON.eventManager:Add('ACCOUNT_BANK_TAB_PURCHASED', self)
    ADDON.eventManager:Add('ACCOUNT_BANK_SLOTS_CHANGED', self)
    ADDON.eventManager:Add('PLAYERACCOUNTBANKSLOTS_CHANGED', self)

    BankFrame:UnregisterAllEvents()
    BankFrame:SetScript('OnShow', DJBagsHideBlizzardBank)
    DJBagsHideBlizzardBank()

    -- Keep the warband and character bank frames aligned when moved directly.
    self:HookScript('OnDragStop', function(frame)
        if DJBagsSyncBankFramePositions then
            DJBagsSyncBankFramePositions(frame)
        end
    end)
end

function bank:BANKFRAME_OPENED()
    local bankType = BankFrame.GetActiveBankType and BankFrame:GetActiveBankType()
    if not bankType then
        bankType = Enum.BankType and Enum.BankType.Character or 0
    end

    self.isActive = bankType == self.bankType
    if self.isActive then
        self:Show()
    else
        self:Hide()
    end
end

function bank:BANKFRAME_CLOSED()
	self:Hide()
end

function bank:BAG_UPDATE(bag)
    if self.isActive then
        self:baseBAG_UPDATE(bag)
    end
end

function bank:PLAYERBANKSLOTS_CHANGED()
    if self.isActive then
        self:Refresh()
    end
end

function bank:PLAYERBANKBAGSLOTS_CHANGED()
    if self.isActive then
        self:Refresh()
    end
end

function bank:ACCOUNT_BANK_TAB_PURCHASED()
    if self.isActive then
        self:Refresh()
    end
end

function bank:ACCOUNT_BANK_SLOTS_CHANGED()
    if self.isActive then
        self:Refresh()
    end
end

bank.PLAYERACCOUNTBANKSLOTS_CHANGED = bank.ACCOUNT_BANK_SLOTS_CHANGED

-- Override the bag hover event to prevent highlighting items when hovering
-- over bank tabs.  Tab selection already filters the visible items.
function bank:DJBAGS_BAG_HOVER()
end
