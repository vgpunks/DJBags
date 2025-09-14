local ADDON_NAME, ADDON = ...

local bag = {}
bag.__index = bag

function DJBagsRegisterBagBagContainer(self, bags)
    DJBagsRegisterBaseBagContainer(self, bags)

    -- Preserve the base OnShow implementation so we can extend it.
    self.baseOnShow = self.OnShow

    for k, v in pairs(bag) do
        self[k] = v
    end

    ADDON.eventManager:Add("NewItemCleared", self)
    ADDON.eventManager:Add("CURRENCY_DISPLAY_UPDATE", self)
    ADDON.eventManager:Add('BANKFRAME_OPENED', self)
    ADDON.eventManager:Add('BANKFRAME_CLOSED', self)

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

function bag:OnShow()
    if self.baseOnShow then
        self:baseOnShow()
    end
    self:UpdateCurrency()
end

function bag:UpdateCurrency()
    if not self.currencyBar then return end

    local text = ""
    local cnt = C_CurrencyInfo.GetCurrencyListSize()
    for i = 1, cnt do
        local info = C_CurrencyInfo.GetCurrencyListInfo(i)
        if info and info.isShowInBackpack then
            local icon = info.iconFileID or info.icon
            if text ~= "" then
                text = text .. "  "
            end
            text = text .. "|T" .. icon .. ":16|t " .. info.quantity
        end
    end

    if text ~= "" then
        if self.currencyBar.icon then
            self.currencyBar.icon:Hide()
        end
        self.currencyBar.amount:ClearAllPoints()
        self.currencyBar.amount:SetPoint("LEFT", self.currencyBar, "LEFT", 8, 0)
        self.currencyBar.amount:SetText(text)

        local padding = 16
        local gap = 5
        local width = self.currencyBar.amount:GetStringWidth() + padding
        local desiredWidth = self.mainBar:GetWidth() + width + gap
        if desiredWidth > self:GetWidth() then
            self:SetWidth(desiredWidth)
        end
        local maxWidth = self:GetWidth() - self.mainBar:GetWidth() - gap
        self.currencyBar:SetWidth(math.min(width, maxWidth))

        self.currencyBar:Show()
    else
        self.currencyBar:Hide()
    end
end

function bag:CURRENCY_DISPLAY_UPDATE()
    self:UpdateCurrency()
end

function bag:BANKFRAME_OPENED()
    self:Show()
    if self.mainBar and self.mainBar.depositButton and self.mainBar.clearButton then
        self.mainBar.depositButton:Show()
        self.mainBar.clearButton:ClearAllPoints()
        self.mainBar.clearButton:SetPoint("RIGHT", self.mainBar.depositButton, "LEFT", -3, 0)
    end
end

function bag:BANKFRAME_CLOSED()
    self:Hide()
    if self.mainBar and self.mainBar.depositButton and self.mainBar.clearButton and self.mainBar.restackButton then
        self.mainBar.depositButton:Hide()
        self.mainBar.clearButton:ClearAllPoints()
        self.mainBar.clearButton:SetPoint("RIGHT", self.mainBar.restackButton, "LEFT", -3, 0)
    end
end
