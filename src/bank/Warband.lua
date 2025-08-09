local ADDON_NAME, ADDON = ...

local bank = {}
bank.__index = bank

local bankInteractions = {}
if Enum and Enum.PlayerInteractionType then
	if Enum.PlayerInteractionType.Banker then
		bankInteractions[Enum.PlayerInteractionType.Banker] = true
	end
	if Enum.PlayerInteractionType.AccountBanker then
		bankInteractions[Enum.PlayerInteractionType.AccountBanker] = true
	end
end

-- Compatibility for new Warband bank container constant
WARDBANK_CONTAINER = WARDBANK_CONTAINER
    or (Enum.BagIndex and (Enum.BagIndex.AccountBankTab1 or Enum.BagIndex.WarbandBank or Enum.BagIndex.AccountBank))
    or 13


local function FetchWarbandBank()
    -- Some clients require explicitly requesting the warband bank data
    -- before the slots become available.  Try to fetch the data whenever
    -- the container is shown so the items populate immediately.
    if C_Bank and C_Bank.FetchAccountBank then
        C_Bank.FetchAccountBank()
    end
end


local function GetWarbandContainers()
    local containers = {}

    -- Newer clients expose explicit bag index constants for each warband
    -- bank tab (e.g. Enum.BagIndex.AccountBankTab1).  Use those when
    -- available so the container list matches the actual API values rather
    -- than assuming sequential indices.  This mirrors the behaviour
    -- described on the Warcraft wiki API reference.
    if Enum and Enum.BagIndex then
        local indices = {}
        for name, value in pairs(Enum.BagIndex) do
            if type(name) == "string" and (name:find("AccountBank") or name:find("Warband")) then
                table.insert(indices, value)
            end
        end
        table.sort(indices)
        for _, bag in ipairs(indices) do
            local slots = C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag)
            if slots and slots > 0 then
                table.insert(containers, bag)
            end
        end
    end

    -- Some clients expose additional tabs as sequential containers. Iterate
    -- through all available containers until the API reports zero slots.
    if #containers == 0 then
        local bag = WARDBANK_CONTAINER
        while true do
            local slots = C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag)
            if not slots or slots == 0 then
                break
            end
            table.insert(containers, bag)
            bag = bag + 1
        end
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

        for k, v in pairs(bank) do
                self[k] = v
        end

    ADDON.eventManager:Add('BANKFRAME_OPENED', self)
    ADDON.eventManager:Add('BANKFRAME_CLOSED', self)

    -- Different game versions have used several names for the event that
    -- signals warband/account bank slot updates.  Listen for all known
    -- variants so the container refreshes regardless of which one is
    -- fired by the client.
    ADDON.eventManager:Add('PLAYERACCOUNTBANKSLOTS_CHANGED', self)
    ADDON.eventManager:Add('PLAYER_ACCOUNT_BANK_SLOTS_CHANGED', self)
    ADDON.eventManager:Add('PLAYERWARDBANKSLOTS_CHANGED', self)

    ADDON.eventManager:Add('PLAYER_INTERACTION_MANAGER_FRAME_SHOW', self)
    ADDON.eventManager:Add('PLAYER_INTERACTION_MANAGER_FRAME_HIDE', self)
end

function bank:BANKFRAME_OPENED()
    local tab = BankFrame.activeTabIndex or BankFrame.selectedTab
    -- The warband bank is represented by the second tab in the custom
    -- bank frame. The previous check against tab index 3 prevented the
    -- warband container from showing when it was the active tab,
    -- leaving the frame hidden until the user reselected the tab. Use
    -- the correct tab index so the warband bank loads reliably. When the
    -- warband tab is active on open, refresh the bag list before showing so
    -- the items populate immediately.
    if tab == 2 then
        FetchWarbandBank()
        UpdateBagList(self)
        self:Show()
    end
end

function bank:BANKFRAME_CLOSED()
        self:Hide()
end

-- Handle warband/account bank slot updates.  The same logic is used for all
-- supported event names, so define the function once and alias it for each
-- variant the game might emit.
function bank:PLAYERACCOUNTBANKSLOTS_CHANGED()
    UpdateBagList(self)
    for _, bag in ipairs(self.bags) do
        self:BAG_UPDATE(bag)
    end
end

bank.PLAYER_ACCOUNT_BANK_SLOTS_CHANGED = bank.PLAYERACCOUNTBANKSLOTS_CHANGED
bank.PLAYERWARDBANKSLOTS_CHANGED = bank.PLAYERACCOUNTBANKSLOTS_CHANGED

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
	FetchWarbandBank()
	UpdateBagList(self)
	if self.BaseOnShow then
		self:BaseOnShow()
	end
end

function bank:PLAYER_INTERACTION_MANAGER_FRAME_SHOW(interactionType)
	if bankInteractions[interactionType] then
		self:BANKFRAME_OPENED()
	end
end

function bank:PLAYER_INTERACTION_MANAGER_FRAME_HIDE(interactionType)
	if bankInteractions[interactionType] then
		self:BANKFRAME_CLOSED()
	end
end

