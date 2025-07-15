local ADDON_NAME, ADDON = ...

local bank = {}
bank.__index = bank

-- Compatibility for new Warband bank container constant
WARDBANK_CONTAINER = WARDBANK_CONTAINER
    or (Enum.BagIndex and (Enum.BagIndex.WarbandBank or Enum.BagIndex.AccountBank))
    or 13

function DJBagsRegisterWarbandBagContainer(self, bags)
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
        self:BAG_UPDATE(WARDBANK_CONTAINER)
end

