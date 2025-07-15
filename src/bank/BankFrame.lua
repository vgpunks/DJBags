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
end

function DJBagsBankTab_OnClick(tab)
        PanelTemplates_SetTab(DJBagsBankBar, tab.tab)
    if tab.tab == 1 then
        DJBagsBank:Show()
        DJBagsReagents:Hide()
        if DJBagsWarband then DJBagsWarband:Hide() end
        BankFrame.selectedTab = 1
        BankFrame.activeTabIndex = 1
    elseif tab.tab == 2 then
        DJBagsBank:Hide()
        DJBagsReagents:Show()
        if DJBagsWarband then DJBagsWarband:Hide() end
        BankFrame.selectedTab = 2
        BankFrame.activeTabIndex = 2
    else
        DJBagsBank:Hide()
        DJBagsReagents:Hide()
        if DJBagsWarband then DJBagsWarband:Show() end
        BankFrame.selectedTab = 3
        BankFrame.activeTabIndex = 3
    end
end

function bankFrame:BANKFRAME_OPENED()
    self:Show()
    if BankFrame_LoadUI then
        BankFrame_LoadUI()
    end
    if BankFrame then
        BankFrame:UnregisterAllEvents()
        BankFrame:SetScript('OnShow', nil)
        if not self._bankFrameOrigPoint then
            local point, relativeTo, relativePoint, xOfs, yOfs = BankFrame:GetPoint()
            self._bankFrameOrigPoint = {point, relativeTo, relativePoint, xOfs, yOfs}
        end
        BankFrame:ClearAllPoints()
        BankFrame:SetPoint('TOPLEFT', UIParent, 'TOPLEFT', -10000, 10000)
    end
    DJBagsBag:Show()
end

function bankFrame:BANKFRAME_CLOSED()
        self:Hide()
        if BankFrame and self._bankFrameOrigPoint then
            BankFrame:ClearAllPoints()
            BankFrame:SetPoint(unpack(self._bankFrameOrigPoint))
        end
end
