local ADDON_NAME, ADDON = ...

local bank = {}
bank.__index = bank

-- Utility helpers for purchasing additional warband bank tabs. These
-- attempt to use whatever API is available on the current client.
local function GetNextPurchaseCost()
    if C_WarbandBank and C_WarbandBank.GetNextPurchaseCost then
        return C_WarbandBank.GetNextPurchaseCost()
    elseif GetNextWarbandBankTabCost then
        return GetNextWarbandBankTabCost()
    end
end

local function PurchaseTab()
    if C_WarbandBank and C_WarbandBank.PurchaseTab then
        C_WarbandBank.PurchaseTab()
    elseif PurchaseWarbandBankTab then
        PurchaseWarbandBankTab()
    end
end

StaticPopupDialogs["DJBAGS_CONFIRM_BUY_WARBAND_TAB"] = {
    text = "Buy new warband bank tab for %s?",
    button1 = ACCEPT,
    button2 = CANCEL,
    OnAccept = function()
        PurchaseTab()
    end,
    whileDead = 1,
    hideOnEscape = 1,
}

function DJBagsShowWarbandTabPopup()
    local cost = GetNextPurchaseCost()
    if cost and cost >= 0 then
        StaticPopup_Show("DJBAGS_CONFIRM_BUY_WARBAND_TAB", GetCoinTextureString(cost))
    end
end

-- Compatibility for new Warband bank container constant
WARDBANK_CONTAINER = WARDBANK_CONTAINER
    or (Enum.BagIndex and (Enum.BagIndex.WarbandBank or Enum.BagIndex.AccountBank))
    or 13


local function GetWarbandContainers()
    local containers = {}
    local bag = WARDBANK_CONTAINER

    -- Some clients expose additional tabs as sequential containers. Iterate
    -- through all available containers until the API reports zero slots.
    while true do
        local slots = C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag)
        if not slots or slots == 0 then
            break
        end
        table.insert(containers, bag)
        bag = bag + 1
    end

    -- Fallback in case the API didn't return any slots for the first container
    if #containers == 0 then
        containers[1] = WARDBANK_CONTAINER
    end

    return containers
end

local function CreateContainers(self)
    for _, bag in ipairs(self.bags) do
        if not self.containers[bag] then
            self.containers[bag] = CreateFrame("Frame", "DJBagsBagContainer_" .. bag, self)
            self.containers[bag]:SetAllPoints()
            self.containers[bag]:SetID(bag)
            self.containers[bag].items = {}
        end
    end
end

local function KeyBasedBagList(bags)
    local out = {}
    for _, b in ipairs(bags) do
        out[b] = true
    end
    return out
end

local function UpdateBagList(self)
    local newBags = GetWarbandContainers()
    local changed = (#newBags ~= #self.bags)
    if not changed then
        for i, v in ipairs(newBags) do
            if self.bags[i] ~= v then
                changed = true
                break
            end
        end
    end
    if changed then
        self.bags = newBags
        self.bagsByKey = KeyBasedBagList(newBags)
        CreateContainers(self)
    end
end

function DJBagsRegisterWarbandBagContainer(self)
    local bags = GetWarbandContainers()
    DJBagsRegisterBaseBagContainer(self, bags)

    self.BaseOnShow = self.OnShow
    self.BaseOnHide = self.OnHide

        for k, v in pairs(bank) do
                self[k] = v
        end

    ADDON.eventManager:Add('BANKFRAME_OPENED', self)
    ADDON.eventManager:Add('BANKFRAME_CLOSED', self)
    ADDON.eventManager:Add('PLAYERWARDBANKSLOTS_CHANGED', self)
end

function bank:BANKFRAME_OPENED()
        if BankFrame.selectedTab == 3 then
                self:Show()
        end
end

function bank:BANKFRAME_CLOSED()
        self:Hide()
end

function bank:PLAYERWARDBANKSLOTS_CHANGED()
    UpdateBagList(self)
    for _, bag in ipairs(self.bags) do
        self:BAG_UPDATE(bag)
    end
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

function bank:OnShow()
    UpdateBagList(self)
    if self.BaseOnShow then
        self:BaseOnShow()
    end
    local btn = DJBagsBankBar and DJBagsBankBar.warbandPurchaseButton
    if btn then
        local cost = GetNextPurchaseCost()
        if cost and cost >= 0 then
            btn.cost = cost
            btn:Show()
        else
            btn:Hide()
        end
    end
    if DJBagsBankBar_UpdateButtons then
        DJBagsBankBar_UpdateButtons(3)
    end
end

function bank:OnHide()
    local btn = DJBagsBankBar and DJBagsBankBar.warbandPurchaseButton
    if btn then
        btn:Hide()
    end
    if self.BaseOnHide then
        self:BaseOnHide()
    end
end

