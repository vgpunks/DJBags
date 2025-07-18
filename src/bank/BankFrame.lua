local ADDON_NAME, ADDON = ...

local bankFrame = {}
bankFrame.__index = bankFrame

-- Update bank bar controls depending on the selected tab
function DJBagsBankBar_UpdateButtons(tab)
    local bar = DJBagsBankBar
    if not bar then return end

    local deposit = _G["DJBagsBankBarDepositReagent"]
    local purchase = bar.warbandPurchaseButton
    local restack = _G["DJBagsBankBarRestackButton"]
    local search = _G["DJBagsBankBarSearchBar"]
    local settings = _G["DJBagsBankBarSettingsBtn"]

    if search and restack and settings then
        search:ClearAllPoints()
        search:SetPoint("LEFT", settings, "RIGHT", 5, 0)
    end

    if tab == 3 then
        if deposit then deposit:Hide() end
        if purchase and restack then
            purchase:ClearAllPoints()
            purchase:SetPoint("RIGHT", restack, "LEFT", -3, 0)
            purchase:Show()
        end
        if search then
            local anchor = purchase or restack
            search:SetPoint("RIGHT", anchor, "LEFT", -5, 0)
        end
    elseif tab == 2 then
        if purchase then purchase:Hide() end
        if deposit and restack then
            deposit:ClearAllPoints()
            deposit:SetPoint("RIGHT", restack, "LEFT", -3, 0)
            deposit:Show()
        end
        if search then
            local anchor = deposit or restack
            search:SetPoint("RIGHT", anchor, "LEFT", -5, 0)
        end
    else
        if deposit then deposit:Hide() end
        if purchase then purchase:Hide() end
        if search and restack then
            search:SetPoint("RIGHT", restack, "LEFT", -5, 0)
        end
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
        DJBagsBankBar_UpdateButtons(1)
    elseif tab.tab == 2 then
        DJBagsBank:Hide()
        DJBagsReagents:Show()
        if DJBagsWarband then DJBagsWarband:Hide() end
        BankFrame.selectedTab = 2
        BankFrame.activeTabIndex = 2
        DJBagsBankBar_UpdateButtons(2)
    else
        DJBagsBank:Hide()
        DJBagsReagents:Hide()
        if DJBagsWarband then DJBagsWarband:Show() end
        BankFrame.selectedTab = 3
        BankFrame.activeTabIndex = 3
        DJBagsBankBar_UpdateButtons(3)
    end
end

function bankFrame:BANKFRAME_OPENED()
    self:Show()
    if BankFrame_LoadUI then
        BankFrame_LoadUI()
    end
    DJBagsBag:Show()
    DJBagsBankBar_UpdateButtons(BankFrame.selectedTab or BankFrame.activeTabIndex or 1)
end

function bankFrame:BANKFRAME_CLOSED()
    self:Hide()
end
