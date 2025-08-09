local ADDON_NAME, ADDON = ...

local bankFrame = {}
bankFrame.__index = bankFrame
local bankInteractions = {}
if Enum and Enum.PlayerInteractionType then
	if Enum.PlayerInteractionType.Banker then
		bankInteractions[Enum.PlayerInteractionType.Banker] = true
	end
	if Enum.PlayerInteractionType.AccountBanker then
		bankInteractions[Enum.PlayerInteractionType.AccountBanker] = true
	end
end

function DJBagsRegisterBankFrame(self, bags)
	for k, v in pairs(bankFrame) do
		self[k] = v
	end

    ADDON.eventManager:Add('BANKFRAME_OPENED', self)
    ADDON.eventManager:Add('BANKFRAME_CLOSED', self)
    ADDON.eventManager:Add('PLAYER_INTERACTION_MANAGER_FRAME_SHOW', self)
    ADDON.eventManager:Add('PLAYER_INTERACTION_MANAGER_FRAME_HIDE', self)

    table.insert(UISpecialFrames, self:GetName())
    self:RegisterForDrag("LeftButton")
    self:SetScript("OnDragStart", function(self, ...)
        self:StartMoving()
    end)
    self:SetScript("OnDragStop", function(self, ...)
        self:StopMovingOrSizing(...)
    end)
    self:SetUserPlaced(true)

    self:HookScript("OnHide", function()
        if not ADDON.closingBankFrame then
            ADDON.closingBankFrame = true
            local restoreOnShow
            if BankFrame and not BankFrame:IsShown() then
                restoreOnShow = true
                BankFrame:SetScript('OnShow', nil)
                BankFrame:Show()
            end
            if type(CloseBankFrame) == 'function' then
                CloseBankFrame()
            elseif BankFrame then
                BankFrame:Hide()
            end
            if restoreOnShow then
                BankFrame:SetScript('OnShow', BankFrame.Hide)
            end
            ADDON.closingBankFrame = false
        end
    end)
end

function DJBagsBankTab_OnClick(tab)
        PanelTemplates_SetTab(DJBagsBankBar, tab.tab)
    if tab.tab == 1 then
        DJBagsBank:Show()
        if DJBagsWarband then DJBagsWarband:Hide() end
        BankFrame.selectedTab = 1
        BankFrame.activeTabIndex = 1
    else
        DJBagsBank:Hide()
        if DJBagsWarband then
            DJBagsWarband:Show()
            -- Explicitly refresh the warband bank when its tab is selected so
            -- the container and items populate immediately.
            if DJBagsWarband.BANKFRAME_OPENED then
                DJBagsWarband:BANKFRAME_OPENED()
            end
        end
        BankFrame.selectedTab = 2
        BankFrame.activeTabIndex = 2
    end
end

function bankFrame:BANKFRAME_OPENED()
    self:Show()
    if BankFrame_LoadUI then
        BankFrame_LoadUI()
    end
    DJBagsBag:Show()
    -- Select the main bank tab by default when the bank opens so that the
    -- contents are visible without requiring an additional click.  This also
    -- ensures other tabs (such as the Warband bank) start hidden and only show
    -- when explicitly selected.
    if DJBagsBankBarTab1 and DJBagsBankTab_OnClick then
        DJBagsBankTab_OnClick(DJBagsBankBarTab1)
    end
end

function bankFrame:BANKFRAME_CLOSED()
	self:Hide()
end

function bankFrame:PLAYER_INTERACTION_MANAGER_FRAME_SHOW(interactionType)
	if bankInteractions[interactionType] then
		self:BANKFRAME_OPENED()
	end
end

function bankFrame:PLAYER_INTERACTION_MANAGER_FRAME_HIDE(interactionType)
	if bankInteractions[interactionType] then
		self:BANKFRAME_CLOSED()
	end
end
