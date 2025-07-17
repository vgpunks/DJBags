local ADDON_NAME, ADDON = ...

local bank = {}
bank.__index = bank

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

function DJBagsRegisterWarbandBagContainer(self)
    local bags = GetWarbandContainers()
    DJBagsRegisterBaseBagContainer(self, bags)

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
    for _, bag in ipairs(self.bags) do
        self:BAG_UPDATE(bag)
    end
end

