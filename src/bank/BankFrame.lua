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

    -- Panels tab templates expect certain textures to exist before
    -- selecting a tab. During the frame's OnLoad the child tabs may not
    -- have run their own OnLoad scripts yet, leaving these textures nil
    -- and causing errors when PanelTemplates_SelectTab runs. Prepare the
    -- tabs here so we can safely select the initial tab.
    local function PrepareTab(tab)
        if not tab then return end
        if not tab.Text and tab.GetFontString then
            tab.Text = tab:GetFontString()
        end
        if not tab.Left and tab.LeftDisabled then
            tab.Left = tab.LeftDisabled
            tab.Middle = tab.MiddleDisabled
            tab.Right = tab.RightDisabled
        end
        if tab.Left then
            PanelTemplates_TabResize(tab, 0)
        end
    end
    PrepareTab(self.characterTab)
    PrepareTab(self.warbandTab)
    PanelTemplates_SetTab(self, 1)

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
        for i = 1, 6 do
            local bag = self['bag' .. i]
            local acc = self['accountBag' .. i]
            if bag then bag:Show() end
            if acc then acc:Hide() end
        end
    else
        if self.bankBag then self.bankBag:Hide() end
        if self.warbandBankBag then self.warbandBankBag:Show() end
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

    PanelTemplates_SetTab(self, isCharacterBank and 1 or 2)
    self:Show()
end

function bankFrame:BANKFRAME_OPENED()
    self:UpdateBankType()
    DJBagsBag:Show()
end

function bankFrame:BANKFRAME_CLOSED()
    self:Hide()
end
