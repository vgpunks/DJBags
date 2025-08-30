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

    BankFrame:UnregisterAllEvents()
    BankFrame:SetScript('OnShow', DJBagsHideBlizzardBank)
    DJBagsHideBlizzardBank()
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
        self:BAG_UPDATE_DELAYED()
    end
end

function bank:BAG_UPDATE_DELAYED()
    if not self.isActive then
        return
    end
    local prefix = self.bankType == Enum.BankType.Account and 'accountBag' or 'bag'
    for i = 1, 6 do
        local barItem = DJBagsBankBar[prefix .. i]
        if barItem then
            barItem:Update()
        end
    end

    local prev
    for i = 1, 6 do
        local barItem = DJBagsBankBar[prefix .. i]
        if barItem and barItem:IsShown() then
            barItem:ClearAllPoints()
            if prev then
                barItem:SetPoint('TOPLEFT', prev, 'BOTTOMLEFT', 0, -5)
            else
                barItem:SetPoint('TOPLEFT', self, 'TOPRIGHT', 5, 0)
            end
            prev = barItem
        end
    end
end

function bank:PLAYERBANKBAGSLOTS_CHANGED()
    if self.isActive then
        self:BAG_UPDATE_DELAYED()
    end
end
