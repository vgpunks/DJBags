local ADDON_NAME, ADDON = ...

local bag = {}
bag.__index = bag

function DJBagsRegisterBagBagContainer(self, bags)
    DJBagsRegisterBaseBagContainer(self, bags)

    for k, v in pairs(bag) do
        self[k] = v
    end

    ADDON.eventManager:Add("NewItemCleared", self)
    ADDON.eventManager:Add("CURRENCY_DISPLAY_UPDATE", self)

    self:UpdateCurrency()
end

function bag:SortBags()
    ADDON.eventManager:Remove('BAG_UPDATE', self)
    if C_Container and C_Container.SortBags then
        C_Container.SortBags()
    elseif SortBags then
        SortBags()
    end
    ADDON.eventManager:Add('BAG_UPDATE', self)
end

function bag:ClearNewItems()
    DJBags_DB_Char.newItems = {}
    C_NewItems:ClearAll()
    self:Refresh()
end

function bag:NewItemCleared()
    self:Refresh()
end

function bag:BAG_UPDATE_DELAYED()
    if self.mainBar.bagBar then
        for _, bag in pairs(self.bags) do
            if bag > 0 then
                self.mainBar.bagBar['bag'..bag]:Update()
            end
        end
    end
end

function bag:UpdateCurrency()
    if not self.currencyBar then return end
    local info = C_CurrencyInfo.GetBackpackCurrencyInfo(1)
    if info then
        local icon = info.iconFileID or info.icon
        if icon then
            self.currencyBar.icon:SetTexture(icon)
        end
        self.currencyBar.amount:SetText(info.quantity)
        self.currencyBar:Show()
    else
        self.currencyBar:Hide()
    end
end

function bag:CURRENCY_DISPLAY_UPDATE()
    self:UpdateCurrency()
end
