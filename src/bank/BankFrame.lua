local ADDON_NAME, ADDON = ...

local bankFrame = {}
bankFrame.__index = bankFrame

-- Keep bank frames aligned so both open at the same location.
function DJBagsSyncBankFramePositions(moved)
    if not DJBagsBank or not DJBagsWarbandBank then
        return
    end
    local source = moved or DJBagsBank
    local target = source == DJBagsBank and DJBagsWarbandBank or DJBagsBank
    local point, relTo, relPoint, x, y = source:GetPoint()
    target:ClearAllPoints()
    target:SetPoint(point, relTo or UIParent, relPoint, x, y)
    if target.ClampToScreen then
        target:ClampToScreen()
    end
end

function DJBagsRegisterBankFrame(self, bags)
        for k, v in pairs(bankFrame) do
                self[k] = v
        end

    ADDON.eventManager:Add('BANKFRAME_OPENED', self)
    ADDON.eventManager:Add('BANKFRAME_CLOSED', self)

    table.insert(UISpecialFrames, self:GetName())
    self:RegisterForDrag("LeftButton")
    -- Attach dragging to the active bank frame so the bar cannot move on its own.
    self:SetMovable(false)
    self:SetClampedToScreen(true)
    self:SetScript("OnDragStart", function(self, ...)
        local bag = self.bankBag
        if self.warbandBankBag and self.warbandBankBag:IsShown() then
            bag = self.warbandBankBag
        end
        if bag and bag.StartMoving then
            bag:StartMoving(...)
        end
    end)
    self:SetScript("OnDragStop", function(self, ...)
        local bag = self.bankBag
        if self.warbandBankBag and self.warbandBankBag:IsShown() then
            bag = self.warbandBankBag
        end
        if bag and bag.StopMovingOrSizing then
            bag:StopMovingOrSizing(...)
            DJBagsSyncBankFramePositions(bag)
        end
    end)
    -- Only clear the user placement flag if the frame supports being moved or resized.
    -- Calling SetUserPlaced on non-movable frames triggers an error starting in 11.0.2.
    if self:IsMovable() or self:IsResizable() then
        self:SetUserPlaced(false)
    end

    -- Update our visibility when the bank switches between character and account tabs.
    hooksecurefunc(BankFrame, "SetTab", function()
        self:UpdateBankType()
    end)

    DJBagsSyncBankFramePositions(self.bankBag)
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
            if bag then
                if bag.Update then
                    bag:Update()
                else
                    bag:Show()
                end
            end
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
            if acc then
                if acc.Update then
                    acc:Update()
                else
                    acc:Show()
                end
            end
        end
    end

    if self.bankSettingsMenu then
        self.bankSettingsMenu.bag = isCharacterBank and self.bankBag or self.warbandBankBag
    end

    local activeBag = isCharacterBank and self.bankBag or self.warbandBankBag
    if activeBag then
        self:ClearAllPoints()
        self:SetPoint("TOPRIGHT", activeBag, "BOTTOMRIGHT", 0, -5)

        if self.settingsBtn and self.restackButton and self.search then
            local padding = 18
            local spacing = 3

            -- Minimum width should accommodate the search box.
            local width = self.settingsBtn:GetWidth() + self.restackButton:GetWidth() + self.search:GetWidth() + padding + spacing * 2

            -- Height only needs to fit the search box.
            local height = self.search:GetHeight() + padding

            self:SetSize(width, height)
        end
    end

    local activeContainer = isCharacterBank and self.bankBag or self.warbandBankBag
    if activeContainer and activeContainer.selectedTab then
        self:UpdateTabSelection(activeContainer.selectedTab)
    end

    if self.bankBag then
        self.bankBag:BAG_UPDATE_DELAYED()
    end
    if self.warbandBankBag then
        self.warbandBankBag:BAG_UPDATE_DELAYED()
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
    local bankType = BankFrame.GetActiveBankType and BankFrame:GetActiveBankType()
    local isCharacterBank = not bankType or bankType == Enum.BankType.Character

    if self.allTab then
        self.allTab:SetAlpha(isCharacterBank and selected == 0 and 1 or 0.4)
    end

    for i = 1, 6 do
        local key = (isCharacterBank and 'bag' or 'accountBag') .. i
        local btn = self[key]
        if btn then
            btn:SetAlpha(selected == i and 1 or 0.4)
        end
    end
end
