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

	for k, v in pairs(bank) do
		self[k] = v
	end

    ADDON.eventManager:Add('BANKFRAME_OPENED', self)
    ADDON.eventManager:Add('BANKFRAME_CLOSED', self)
    ADDON.eventManager:Add('PLAYERBANKSLOTS_CHANGED', self)
    ADDON.eventManager:Add('PLAYERBANKBAGSLOTS_CHANGED', self)

    BankFrame:UnregisterAllEvents()
    BankFrame:SetScript('OnShow', DJBagsHideBlizzardBank)
    DJBagsHideBlizzardBank()
end

function bank:BANKFRAME_OPENED()
	if (BankFrame.selectedTab or 1) == 1 then
		self:Show()
	end
end

function bank:BANKFRAME_CLOSED()
	self:Hide()
end

function bank:PLAYERBANKSLOTS_CHANGED()
	self:BAG_UPDATE(BANK_CONTAINER)
end

function bank:BAG_UPDATE_DELAYED()
    for _, bag in pairs(self.bags) do
        if bag ~= BANK_CONTAINER then
            local barItem = DJBagsBankBar['bag' .. (bag - NUM_TOTAL_EQUIPPED_BAG_SLOTS)]
            if barItem then
                barItem:Update()
            end
        end
    end
end

function bank:PLAYERBANKBAGSLOTS_CHANGED()
	self:BAG_UPDATE_DELAYED()
end
