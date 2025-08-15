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

function DJBagsRegisterBankBagContainer(self, bags)
    DJBagsRegisterBaseBagContainer(self, bags)

    -- Save the original BAG_UPDATE implementation so we can gate updates
    -- while the warband bank is active.
    self.baseBAG_UPDATE = self.BAG_UPDATE

    for k, v in pairs(bank) do
        self[k] = v
    end

    -- Default to the character bank being active until told otherwise.
    self.isCharacterBank = true

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
    self.isCharacterBank = not bankType or bankType == Enum.BankType.Character
    if self.isCharacterBank then
        self:Show()
    else
        self:Hide()
    end
end

function bank:BANKFRAME_CLOSED()
	self:Hide()
end

function bank:BAG_UPDATE(bag)
    if self.isCharacterBank then
        self:baseBAG_UPDATE(bag)
    end
end

function bank:PLAYERBANKSLOTS_CHANGED()
    if self.isCharacterBank then
        self:BAG_UPDATE_DELAYED()
    end
end

function bank:BAG_UPDATE_DELAYED()
    if not self.isCharacterBank then
        return
    end
    for _, bag in pairs(self.bags) do
        local barIndex = Enum.BagIndex.CharacterBankTab_1 and (bag - Enum.BagIndex.CharacterBankTab_1 + 1) or bag
        local barItem = DJBagsBankBar['bag' .. barIndex]
        if barItem then
            barItem:Update()
        end
    end
end

function bank:PLAYERBANKBAGSLOTS_CHANGED()
    if self.isCharacterBank then
        self:BAG_UPDATE_DELAYED()
    end
end
