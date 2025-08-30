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

    PanelTemplates_SetNumTabs(self, 2)

    -- Defer selecting the initial tab until the next frame so that the
    -- child tab buttons have finished running their own OnLoad scripts and
    -- created the textures expected by PanelTemplates_SelectTab.
    C_Timer.After(0, function()
        PanelTemplates_SetTab(self, 1)
    end)

    -- Update our visibility when the bank switches between character and account tabs.
    hooksecurefunc(BankFrame, "SetTab", function()
        self:UpdateBankType()
    end)
end

function bankFrame:UpdateBankType()
    local bankType = BankFrame.GetActiveBankType and BankFrame:GetActiveBankType()
    local isCharacterBank = not bankType or bankType == Enum.BankType.Character

    if self.bankBag then
        self.bankBag.isActive = isCharacterBank
    end
    if self.warbandBankBag then
        self.warbandBankBag.isActive = not isCharacterBank
    end

    if isCharacterBank then
        if self.bankBag then self.bankBag:Show() end
        if self.warbandBankBag then self.warbandBankBag:Hide() end
        if self.allTab then self.allTab:Show() end
        for i = 1, 6 do
            local bag = self['bag' .. i]
            local acc = self['accountBag' .. i]
            if bag then bag:Show() end
            if acc then acc:Hide() end
        end
    else
        if self.bankBag then self.bankBag:Hide() end
        if self.warbandBankBag then self.warbandBankBag:Show() end
        if self.allTab then self.allTab:Hide() end
        for i = 1, 6 do
            local bag = self['bag' .. i]
            local acc = self['accountBag' .. i]
            if bag then bag:Hide() end
            if acc then acc:Show() end
        end
    end

    if self.bankSettingsMenu then
        self.bankSettingsMenu.bag = isCharacterBank and self.bankBag or self.warbandBankBag
    end

    local activeBag = isCharacterBank and self.bankBag or self.warbandBankBag
    if activeBag and self.characterTab then
        self.characterTab:ClearAllPoints()
        self.characterTab:SetPoint("TOPLEFT", activeBag, "BOTTOMLEFT", 2, 2)
    end

    PanelTemplates_SetTab(self, isCharacterBank and 1 or 2)
    local maxWidth = (activeBag and activeBag:GetWidth()) or self:GetWidth()
    PanelTemplates_ResizeTabsToFit(self, maxWidth)

    if isCharacterBank and self.bankBag and self.bankBag.selectedTab then
        self:UpdateTabSelection(self.bankBag.selectedTab)
    end

    self:Show()
end

function bankFrame:BANKFRAME_OPENED()
    if BankFrame and BankFrame.GetActiveBankType and not BankFrame:GetActiveBankType() then
        BankFrame:SetTab(1, Enum.BankType and Enum.BankType.Character)
    end
    self:UpdateBankType()
    DJBagsBag:Show()
end

function bankFrame:BANKFRAME_CLOSED()
    self:Hide()
end

function bankFrame:UpdateTabSelection(selected)
    if self.allTab then
        self.allTab:SetAlpha(selected == 0 and 1 or 0.4)
    end
    for i = 1, 6 do
        local btn = self['bag' .. i]
        if btn then
            btn:SetAlpha(selected == i and 1 or 0.4)
        end
    end
end
