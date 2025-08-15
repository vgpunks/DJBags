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

    -- Move the default Blizzard bank tab bar to our bank frame.
    if BankFrame.BankPanel and BankFrame.BankPanel.TabBar then
        local tabBar = BankFrame.BankPanel.TabBar
        tabBar:SetParent(self.bankBag)
        tabBar:ClearAllPoints()
        tabBar:SetPoint("TOPLEFT", self.bankBag, "TOPRIGHT", 5, -20)
        tabBar:SetPoint("BOTTOMLEFT", self.bankBag, "BOTTOMRIGHT", 5, 20)
        tabBar:SetScale(1)
        tabBar:SetAlpha(1)
        tabBar:Show()
        self.tabBar = tabBar
    end
end

function bankFrame:UpdateBankType()
    local bankType = BankFrame.GetActiveBankType and BankFrame:GetActiveBankType()
    local isCharacterBank = not bankType or bankType == Enum.BankType.Character
    self.bankBag.isCharacterBank = isCharacterBank

    if isCharacterBank then
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
