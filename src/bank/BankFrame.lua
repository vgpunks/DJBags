local ADDON_NAME, ADDON = ...

local bankFrame = {}
bankFrame.__index = bankFrame

function DJBagsRegisterBankFrame(self, bags)
	for k, v in pairs(bankFrame) do
		self[k] = v
	end

    ADDON.eventManager:Add('BANKFRAME_OPENED', self)
    ADDON.eventManager:Add('BANKFRAME_CLOSED', self)

    table.insert(UISpecialFrames, self:GetName())
    self:RegisterForDrag("LeftButton")
    self:SetScript("OnDragStart", function(self, ...)
        self:StartMoving()
    end)
    self:SetScript("OnDragStop", function(self, ...)
        self:StopMovingOrSizing(...)
    end)
    self:SetUserPlaced(true)

    -- Update our visibility when the bank switches between character and account tabs.
    hooksecurefunc(BankFrame, "SetTab", function()
        self:UpdateBankType()
    end)
end

function bankFrame:UpdateBankType()
    if BankFrame.GetActiveBankType and BankFrame:GetActiveBankType() == Enum.BankType.Character then
        self.bankBag:Show()
        self:Show()
    else
        self.bankBag:Hide()
        self:Hide()
    end
end

function bankFrame:BANKFRAME_OPENED()
    self:UpdateBankType()
    DJBagsBag:Show()
end

function bankFrame:BANKFRAME_CLOSED()
    self:Hide()
end
