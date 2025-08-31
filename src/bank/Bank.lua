local ADDON_NAME, ADDON = ...

local bank = {}
bank.__index = bank

-- Helper to load the "all" tab button which displays contents from all
-- character bank tabs.
function DJBagsBankAllTab_OnLoad(self)
    SetItemButtonTexture(self, "Interface/Icons/INV_Misc_Bag_08")
    self:SetScript("OnClick", function()
        if DJBagsBankBar and DJBagsBankBar.bankBag and DJBagsBankBar.bankBag.SelectTab then
            DJBagsBankBar.bankBag:SelectTab(0)
        end
    end)
end

-- Helper to initialize a bank tab button for a specific tab index.
function DJBagsBankTabButton_OnLoad(self, tabIndex)
    local slot = Enum.BagIndex and Enum.BagIndex.CharacterBankTab_1 and (Enum.BagIndex.CharacterBankTab_1 + tabIndex - 1)
    if slot then
        local id = C_Container and C_Container.ContainerIDToInventoryID and C_Container.ContainerIDToInventoryID(slot)
        DJBagsBagItemLoad(self, slot, id)
    end

    -- Disable drag interactions; tabs are for selection only.
    self:SetScript('OnDragStart', nil)
    self:SetScript('OnReceiveDrag', nil)

    self:SetScript("OnClick", function(btn, which)
        if which == "RightButton" then
            local menu = ADDON:GetBankTabSettingsMenu()
            menu:Open(Enum.BankType and Enum.BankType.Character, tabIndex)
            PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        else
            if DJBagsBankBar and DJBagsBankBar.bankBag and DJBagsBankBar.bankBag.SelectTab then
                DJBagsBankBar.bankBag:SelectTab(tabIndex)
            end
        end
    end)
end

function DJBagsHideBlizzardBank()
    BankFrame:SetAlpha(0)
    BankFrame:EnableMouse(false)
    BankFrame:SetScale(0.0001)
    BankFrame:ClearAllPoints()
    BankFrame:SetPoint('TOPLEFT', UIParent, 'TOPLEFT', -9999, -9999)
end

function DJBagsRegisterBankBagContainer(self, bags, bankType)
    DJBagsRegisterBaseBagContainer(self, bags)

    -- Track the full list of bags so we can toggle individual tabs.
    self.allBags = bags
    self.selectedTab = 0

    -- Save the original BAG_UPDATE implementation so we can gate updates
    -- while the other bank type is active.
    self.baseBAG_UPDATE = self.BAG_UPDATE

    for k, v in pairs(bank) do
        self[k] = v
    end

    -- Track which bank type this container represents and if it's active.
    self.bankType = bankType or Enum.BankType and Enum.BankType.Character or 0
    self.isActive = self.bankType == (Enum.BankType and Enum.BankType.Character or 0)

    ADDON.eventManager:Add('BANKFRAME_OPENED', self)
    ADDON.eventManager:Add('BANKFRAME_CLOSED', self)
    ADDON.eventManager:Add('PLAYERBANKSLOTS_CHANGED', self)
    ADDON.eventManager:Add('PLAYERBANKBAGSLOTS_CHANGED', self)

    BankFrame:UnregisterAllEvents()
    BankFrame:SetScript('OnShow', DJBagsHideBlizzardBank)
    DJBagsHideBlizzardBank()

    -- Keep the warband and character bank frames aligned when moved directly.
    self:HookScript('OnDragStop', function(frame)
        if DJBagsSyncBankFramePositions then
            DJBagsSyncBankFramePositions(frame)
        end
    end)
end

function bank:BANKFRAME_OPENED()
    local bankType = BankFrame.GetActiveBankType and BankFrame:GetActiveBankType()
    if not bankType then
        bankType = Enum.BankType and Enum.BankType.Character or 0
    end

    self.isActive = bankType == self.bankType
    if self.isActive then
        self:Show()
    else
        self:Hide()
    end
end

function bank:BANKFRAME_CLOSED()
	self:Hide()
end

function bank:BAG_UPDATE(bag)
    if self.isActive then
        self:baseBAG_UPDATE(bag)
    end
end

function bank:PLAYERBANKSLOTS_CHANGED()
    if self.isActive then
        self:BAG_UPDATE_DELAYED()
    end
end

function bank:SelectTab(tabIndex)
    self.selectedTab = tabIndex or 0
    if self.selectedTab == 0 then
        self.bags = self.allBags
    else
        local bagID = self.allBags[self.selectedTab]
        if bagID then
            self.bags = { bagID }
        else
            self.bags = self.allBags
            self.selectedTab = 0
        end
    end

    self.bagsByKey = {}
    for _, bag in ipairs(self.bags) do
        self.bagsByKey[bag] = true
    end

    -- Reset the item cache and hide items from inactive tabs so the display
    -- only contains slots from the selected tab. Ensure items from the
    -- active tab are retained in the cache so the bag doesn't appear empty
    -- after switching tabs.
    self.items = {}
    if self.containers then
        for bagID, container in pairs(self.containers) do
            if self.bagsByKey[bagID] then
                for _, item in pairs(container.items) do
                    table.insert(self.items, item)
                end
            else
                for _, item in pairs(container.items) do
                    item.id = nil
                    item:Hide()
                end
            end
        end
    end

    self:Refresh()
    self:BAG_UPDATE_DELAYED()

    if DJBagsBankBar and DJBagsBankBar.UpdateTabSelection then
        DJBagsBankBar:UpdateTabSelection(self.selectedTab)
    end
end

function bank:BAG_UPDATE_DELAYED()
    if not self.isActive then
        return
    end

    local prefix = self.bankType == Enum.BankType.Account and 'accountBag' or 'bag'

    -- Update tab icons
    for i = 1, 6 do
        local barItem = DJBagsBankBar[prefix .. i]
        if barItem then
            barItem:Update()
        end
    end

    -- Position the tab buttons vertically and include the "all" tab for
    -- character banks. Tabs are anchored to the active bank container rather
    -- than the outer bank bar so they move with the bag frame itself.
    local prev
    if prefix == 'bag' and DJBagsBankBar.allTab then
        DJBagsBankBar.allTab:ClearAllPoints()
        DJBagsBankBar.allTab:SetPoint('TOPLEFT', self, 'TOPRIGHT', 5, -5)
        prev = DJBagsBankBar.allTab
    end

    for i = 1, 6 do
        local barItem = DJBagsBankBar[prefix .. i]
        if barItem and barItem:IsShown() then
            barItem:ClearAllPoints()
            if prev then
                barItem:SetPoint('TOPLEFT', prev, 'BOTTOMLEFT', 0, -5)
            else
                barItem:SetPoint('TOPLEFT', self, 'TOPRIGHT', 5, prefix == 'bag' and -5 or 0)
            end
            prev = barItem
        end
    end
end

function bank:PLAYERBANKBAGSLOTS_CHANGED()
    if self.isActive then
        self:BAG_UPDATE_DELAYED()
    end
end

-- Override the bag hover event to prevent highlighting items when hovering
-- over bank tabs.  Tab selection already filters the visible items.
function bank:DJBAGS_BAG_HOVER()
end
