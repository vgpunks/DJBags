local ADDON_NAME, ADDON = ...

local bank = {}
bank.__index = bank

function DJBagsRegisterBankBagContainer(self, bags)
	DJBagsRegisterBaseBagContainer(self, bags)

	for k, v in pairs(bank) do
		self[k] = v
	end

    ADDON.eventManager:Add('BANKFRAME_OPENED', self)
    ADDON.eventManager:Add('BANKFRAME_CLOSED', self)
    ADDON.eventManager:Add('PLAYERBANKSLOTS_CHANGED', self)
    ADDON.eventManager:Add('PLAYERBANKBAGSLOTS_CHANGED', self)

    if BankFrame_LoadUI then
        BankFrame_LoadUI()
    end
    if BankFrame then
        BankFrame:UnregisterAllEvents()
        BankFrame:SetScript('OnShow', nil)
    end
end

function bank:BANKFRAME_OPENED()
    local tab = BankFrame.activeTabIndex or BankFrame.selectedTab or 1
    if tab == 1 then
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
end

function bank:PLAYERBANKBAGSLOTS_CHANGED()
        self:BAG_UPDATE_DELAYED()
end

function bank:SortBags()
    ADDON.eventManager:Remove('BAG_UPDATE', self)
    if C_Container and C_Container.SortBankBags then
        C_Container.SortBankBags()
    elseif SortBankBags then
        SortBankBags()
    end
    ADDON.eventManager:Add('BAG_UPDATE', self)
end
