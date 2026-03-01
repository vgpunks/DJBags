local ADDON_NAME, ADDON = ...

-- Bank Tabs (Midnight+)
--
-- Implement bank tab behavior the same way Baganator does:
--   * A vertical strip of tab buttons on the right
--   * Right-click tab settings uses Blizzard's BankPanelTabSettingsMenuTemplate
--     (icon picker + expansion dropdown + deposit filters)
--   * Purchase button uses Blizzard's secure BankPanelPurchaseButtonScriptTemplate
--     (no direct calls to C_Bank.PurchaseBankTab from addon code)
--   * Selecting a tab filters visible items to that tab

local function AddBankTabSettingsToTooltip(tooltip, depositFlags)
    -- Copied from Blizzard (same helper Baganator uses)
    if not tooltip or not depositFlags or not FlagsUtil or not Enum then
        return
    end

    if Enum.BagSlotFlags and FlagsUtil.IsSet(depositFlags, Enum.BagSlotFlags.ExpansionCurrent) then
        if BANK_TAB_EXPANSION_ASSIGNMENT and BANK_TAB_EXPANSION_FILTER_CURRENT then
            GameTooltip_AddNormalLine(tooltip, BANK_TAB_EXPANSION_ASSIGNMENT:format(BANK_TAB_EXPANSION_FILTER_CURRENT))
        end
    elseif Enum.BagSlotFlags and FlagsUtil.IsSet(depositFlags, Enum.BagSlotFlags.ExpansionLegacy) then
        if BANK_TAB_EXPANSION_ASSIGNMENT and BANK_TAB_EXPANSION_FILTER_LEGACY then
            GameTooltip_AddNormalLine(tooltip, BANK_TAB_EXPANSION_ASSIGNMENT:format(BANK_TAB_EXPANSION_FILTER_LEGACY))
        end
    end

    if ContainerFrameUtil_ConvertFilterFlagsToList then
        local filterList = ContainerFrameUtil_ConvertFilterFlagsToList(depositFlags)
        if filterList and BANK_TAB_DEPOSIT_ASSIGNMENTS then
            GameTooltip_AddNormalLine(tooltip, BANK_TAB_DEPOSIT_ASSIGNMENTS:format(filterList), true)
        end
    end
end

-- ---------- Data helpers ----------

local function GetBankTypeEnums()
    local characterType = (Enum and Enum.BankType and Enum.BankType.Character) or 0
    local accountType = (Enum and Enum.BankType and Enum.BankType.Account) or 2
    return characterType, accountType
end

local function GetDefaultTabBagIDs(bankType)
    local characterType, accountType = GetBankTypeEnums()
    local out = {}
    if Enum and Enum.BagIndex then
        if bankType == accountType then
            for i = 1, 6 do
                local key = "AccountBankTab_" .. i
                if Enum.BagIndex[key] then
                    out[#out + 1] = Enum.BagIndex[key]
                end
            end
        else
            for i = 1, 6 do
                local key = "CharacterBankTab_" .. i
                if Enum.BagIndex[key] then
                    out[#out + 1] = Enum.BagIndex[key]
                end
            end
        end
    end

    if #out == 0 then
        for i = 1, 6 do
            out[#out + 1] = i
        end
    end
    return out
end

local function GetPurchasedTabBagIDs(bankType)
    if C_Bank and C_Bank.FetchPurchasedBankTabIDs then
        local ok, ids = pcall(C_Bank.FetchPurchasedBankTabIDs, bankType)
        if ok and type(ids) == "table" and #ids > 0 then
            return ids
        end
    end
    return GetDefaultTabBagIDs(bankType)
end

local function FetchTabDataMap(bankType)
    local map = {}
    if C_Bank and C_Bank.FetchPurchasedBankTabData then
        local ok, data = pcall(C_Bank.FetchPurchasedBankTabData, bankType)
        if ok and type(data) == "table" then
            for _, entry in ipairs(data) do
                local id = entry.bagID or entry.tabID or entry.ID or entry.id or entry[1]
                if id then
                    map[id] = {
                        name = entry.name or entry.tabName or entry[2],
                        icon = entry.icon or entry.iconFileID or entry.iconTexture or entry.texture or entry[3],
                        depositFlags = entry.depositFlags or entry.flags or entry[4] or 0,
                    }
                end
            end
        end
    end
    return map
end

local function GetNameIconFlags(bagID, tabMap)
    local e = tabMap and tabMap[bagID]
    local name = e and e.name
    local icon = e and e.icon
    local flags = e and e.depositFlags

    if not name then
        name = (C_Container and C_Container.GetBagName and C_Container.GetBagName(bagID)) or ("Tab " .. tostring(bagID))
    end
    if not icon then
        icon = 134400
    end
    if not flags then
        flags = 0
    end
    return name, icon, flags
end

-- ---------- Filter predicate ----------

local function EnsureBankFilterPredicate(bankFrame)
    if not bankFrame or bankFrame._djbagsTabPredicateHooked then
        return
    end
    bankFrame._djbagsTabPredicateHooked = true

    local original = bankFrame.ShouldDisplayItem
    bankFrame.ShouldDisplayItem = function(self, item)
        if original and not original(self, item) then
            return false
        end

        local selectedBag = rawget(self, "_djbagsSelectedBankTab")
        if not selectedBag then
            return true
        end

        if not item or not item.GetParent then
            return false
        end

        local parent = item:GetParent()
        if not parent or not parent.GetID then
            return false
        end

        return parent:GetID() == selectedBag
    end
end

-- ---------- Baganator-style Blizzard wiring ----------

local function IsNewBankUIActive()
    return BankFrame and BankFrame.BankPanel and BankFrame.BankPanel.SetBankType ~= nil
end

local function SetupBlizzardFramesForTab(bankType, bagID, tabInfo, tabSettingsMenu)
    if not bagID or not tabInfo then
        return
    end

    local characterType, accountType = GetBankTypeEnums()

    -- Ensure right-clicking items uses the correct bank type/tab.
    if BankFrame and BankFrame.BankPanel and BankFrame.BankPanel.SetBankType then
        if bankType == accountType then
            pcall(BankFrame.BankPanel.SetBankType, BankFrame.BankPanel, accountType)
        else
            pcall(BankFrame.BankPanel.SetBankType, BankFrame.BankPanel, characterType)
        end
    end

    -- selectedTabID is used by Blizzard bank logic for deposits and some UI.
    local panel = _G and (_G.AccountBankPanel or _G.BankPanel)
    if panel then
        panel.selectedTabID = bagID
    end
    if BankFrame and rawget(BankFrame, "BankPanel") then
        BankFrame.BankPanel.selectedTabID = bagID
    end

    -- Workaround so Blizzard's tab edit UI shows our tab details.
    if tabSettingsMenu then
        tabSettingsMenu.GetBankFrame = function()
            return {
                GetTabData = function(_)
                    return {
                        ID = bagID,
                        icon = tabInfo.icon,
                        name = tabInfo.name,
                        depositFlags = tabInfo.depositFlags,
                        bankType = bankType,
                    }
                end,
            }
        end
        tabSettingsMenu.GetBankPanel = tabSettingsMenu.GetBankFrame

        if tabSettingsMenu.IsShown and tabSettingsMenu:IsShown() and tabSettingsMenu.OnNewBankTabSelected then
            tabSettingsMenu:OnNewBankTabSelected(bagID)
        end
    end
end

-- ---------- UI helpers ----------

local function AcquireButton(self)
    self._pool = self._pool or {}
    self._active = self._active or {}

    local btn = tremove(self._pool)
    if not btn then
        btn = CreateFrame("Button", nil, self, "DJBagsRightSideTabButtonTemplate")
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        btn.SelectedTexture:Hide()
    else
        btn:SetParent(self)
    end

    btn:Show()
    table.insert(self._active, btn)
    return btn
end

local function ReleaseAllButtons(self)
    if self._active then
        for _, btn in ipairs(self._active) do
            if self.purchaseButton and btn == self.purchaseButton then
                btn:Hide()
                btn:ClearAllPoints()
                btn:SetScript("OnEnter", nil)
                btn:SetScript("OnLeave", nil)
                btn.SelectedTexture:Hide()
                btn.Icon:SetAlpha(1)
                btn.Icon:SetDesaturated(false)
                -- Keep the purchase button instance intact; do not pool it.
            else
                btn:Hide()
                btn:SetScript("OnClick", nil)
                btn:SetScript("OnEnter", nil)
                btn:SetScript("OnLeave", nil)
                btn.bagID = nil
                btn.isAll = nil
                btn.isPurchase = nil
                btn.SelectedTexture:Hide()
                btn.Icon:SetAlpha(1)
                btn.Icon:SetDesaturated(false)
                table.insert(self._pool, btn)
            end
        end
        wipe(self._active)
    end
end

local function LayoutButtons(self)
    -- Strip is 40px wide with 3px border insets = 34px usable.
    -- Buttons are 32x32 at scale 0.8 = 25.6px actual.
    -- Center horizontally: (40 - 25.6) / 2 ≈ 7px from left edge.
    -- Start 6px below the top border (3px inset + small gap).
    -- Gap between buttons: 2px (buttons are 25.6px tall at 0.8 scale).
    local xOffset = 7
    local yStart  = -6
    local yGap    = -2   -- tight gap so all tabs stay inside the border

    local last = nil
    for i, btn in ipairs(self._active or {}) do
        btn:ClearAllPoints()
        if i == 1 then
            btn:SetPoint("TOPLEFT", self, "TOPLEFT", xOffset, yStart)
        else
            btn:SetPoint("TOP", last, "BOTTOM", 0, yGap)
        end
        last = btn
    end
end

-- ---------- Mixin ----------

DJBagsBankTabStripMixin = {}

function DJBagsBankTabStripMixin:OnLoad(bankFrame, bankType)
    self.bankFrame = bankFrame
    self.bankType = bankType
    self.selectedBagID = nil
    self.tabMap = {}

    self:SetClampedToScreen(true)
    EnsureBankFilterPredicate(self.bankFrame)

    -- Hook menu hide so icons update immediately after changing.
    if bankFrame and bankFrame.TabSettingsMenu and bankFrame.TabSettingsMenu.HookScript and not bankFrame.TabSettingsMenu._djbagsHooked then
        bankFrame.TabSettingsMenu._djbagsHooked = true
        bankFrame.TabSettingsMenu:HookScript("OnHide", function()
            if self.Refresh then
                self:Refresh()
            end
        end)
    end

    self:Refresh()
end

function DJBagsBankTabStripMixin:Refresh()
    self:Rebuild()
end

function DJBagsBankTabStripMixin:Rebuild()
    ReleaseAllButtons(self)

    local bankType = self.bankType
    self.tabMap = FetchTabDataMap(bankType)
    local purchasedIDs = GetPurchasedTabBagIDs(bankType)

    -- "All" (Everything) tab.
    do
        local btn = AcquireButton(self)
        btn.isAll = true
        btn.Icon:SetTexture(132987) -- INV_Misc_Bag_08
        btn:SetScript("OnClick", function(_, mouseButton)
            if mouseButton == "RightButton" then
                return
            end
            self:SelectTab(nil)
        end)
        btn:SetScript("OnEnter", function()
            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            GameTooltip:SetText(BAGS or "Bags")
            GameTooltip:AddLine("All Bank Tabs", 1, 1, 1)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end

    -- Purchased bank tabs.
    for _, bagID in ipairs(purchasedIDs) do
        if type(bagID) == "number" then
            local btn = AcquireButton(self)
            btn.bagID = bagID
            local _, iconInitial = GetNameIconFlags(bagID, self.tabMap)
            btn.Icon:SetTexture(iconInitial)

            btn:SetScript("OnClick", function(_, mouseButton)
                if mouseButton == "RightButton" then
                    -- Mirror Baganator: select the tab, then open Blizzard settings UI.
                    self:SelectTab(bagID)
                    local menu = self.bankFrame and self.bankFrame.TabSettingsMenu
                    if menu and menu.OnOpenTabSettingsRequested then
                        local nameNow, iconNow, flagsNow = GetNameIconFlags(bagID, self.tabMap)
                        SetupBlizzardFramesForTab(bankType, bagID, { name = nameNow, icon = iconNow, depositFlags = flagsNow }, menu)
                        menu:OnOpenTabSettingsRequested(bagID)
                    end
                else
                    self:SelectTab(bagID)
                end
            end)

            btn:SetScript("OnEnter", function()
                local nameNow, _, flagsNow = GetNameIconFlags(bagID, self.tabMap)
                GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
                GameTooltip:SetText(nameNow or "Tab")
                AddBankTabSettingsToTooltip(GameTooltip, flagsNow)
                GameTooltip:AddLine("Right-click for settings", 0.1, 1, 0.1)
                GameTooltip:Show()
            end)
            btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
    end

    -- Purchase tab (secure Blizzard purchase handler).
    local canPurchase = false
    if C_Bank and C_Bank.CanPurchaseBankTab then
        local ok, r = pcall(C_Bank.CanPurchaseBankTab, bankType)
        canPurchase = ok and r
    end
    local hasMax = false
    if C_Bank and C_Bank.HasMaxBankTabs then
        local ok, r = pcall(C_Bank.HasMaxBankTabs, bankType)
        hasMax = ok and r
    end

    if canPurchase and not hasMax then
        if not self.purchaseButton then
            if IsNewBankUIActive() then
                -- Same as Baganator on modern bank UI.
                self.purchaseButton = CreateFrame("Button", nil, self, "DJBagsRightSideTabButtonTemplate,BankPanelPurchaseButtonScriptTemplate")
                self.purchaseButton:SetAttribute("overrideBankType", bankType)
            else
                -- Fallback (older layout): click Blizzard's purchase button securely.
                self.purchaseButton = CreateFrame("Button", nil, self, "DJBagsSecureRightSideTabButtonTemplate")
                self.purchaseButton:SetAttribute("type", "click")
                local clickBtn = _G and _G.AccountBankPanel and _G.AccountBankPanel.PurchasePrompt and _G.AccountBankPanel.PurchasePrompt.TabCostFrame and _G.AccountBankPanel.PurchasePrompt.TabCostFrame.PurchaseButton
                if clickBtn then
                    self.purchaseButton:SetAttribute("clickbutton", clickBtn)
                end
                self.purchaseButton:RegisterForClicks("AnyUp", "AnyDown")
            end

            self.purchaseButton.isPurchase = true
            self.purchaseButton.Icon:SetTexture("Interface\\GuildBankFrame\\UI-GuildBankFrame-NewTab")
            self.purchaseButton.SelectedTexture:Hide()

            self.purchaseButton:HookScript("OnClick", function()
                if PlaySound and SOUNDKIT then
                    PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
                end
            end)

            self.purchaseButton:SetScript("OnEnter", function()
                local btn = self.purchaseButton
                GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
                local title = "Buy Bank Tab"
                if LINK_FONT_COLOR and LINK_FONT_COLOR.WrapTextInColorCode then
                    title = LINK_FONT_COLOR:WrapTextInColorCode(title)
                end
                GameTooltip:SetText(title)
                local cost
                if C_Bank and C_Bank.FetchNextPurchasableBankTabData then
                    local ok, data = pcall(C_Bank.FetchNextPurchasableBankTabData, bankType)
                    cost = ok and data and data.tabCost
                elseif C_Bank and C_Bank.FetchNextPurchasableBankTabCost then
                    local ok, c = pcall(C_Bank.FetchNextPurchasableBankTabCost, bankType)
                    cost = ok and c
                end
                if cost then
                    local moneyString = (GetMoneyString and GetMoneyString(cost)) or (tostring(cost) .. "c")
                    if cost > (GetMoney and GetMoney() or 0) then
                        GameTooltip:AddLine("Cost: " .. moneyString, 1, 0.2, 0.2)
                    else
                        GameTooltip:AddLine("Cost: " .. moneyString, 1, 1, 1)
                    end
                end
                GameTooltip:Show()
            end)
            self.purchaseButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end

        self.purchaseButton:SetParent(self)
        self.purchaseButton:Show()
        self.purchaseButton.Icon:SetAlpha(1)
        self.purchaseButton.SelectedTexture:Hide()
        table.insert(self._active, self.purchaseButton)
    end

    LayoutButtons(self)
    self:SelectTab(self.selectedBagID)
end

function DJBagsBankTabStripMixin:SelectTab(bagID)
    self.selectedBagID = bagID

    if self.bankFrame then
        self.bankFrame._djbagsSelectedBankTab = bagID
        if self.bankFrame.Format then
            self.bankFrame:Format()
        elseif self.bankFrame.Refresh then
            self.bankFrame:Refresh()
        end
    end

    -- Update Blizzard wiring so right-click deposit targets the active tab.
    if bagID then
        local name, icon, flags = GetNameIconFlags(bagID, self.tabMap)
        local menu = self.bankFrame and self.bankFrame.TabSettingsMenu
        SetupBlizzardFramesForTab(self.bankType, bagID, { name = name, icon = icon, depositFlags = flags }, menu)
    end

    for _, btn in ipairs(self._active or {}) do
        local selected = (bagID == nil and btn.isAll) or (btn.bagID and btn.bagID == bagID)
        if btn.SelectedTexture then
            btn.SelectedTexture:SetShown(selected)
        end
    end
end

-- ---------- Public attach API ----------

function ADDON:AttachBankTabStrip(bankFrame, bankType)
    if not bankFrame or bankFrame._djbagsTabStrip then
        return bankFrame and bankFrame._djbagsTabStrip
    end

    local strip = CreateFrame("Frame", nil, bankFrame, "BackdropTemplate")
    strip:SetSize(44, 360)
    strip:SetPoint("TOPLEFT", bankFrame, "TOPRIGHT", 2, -6)
    strip:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    strip:SetBackdropColor(0, 0, 0, 0.25)

    Mixin(strip, DJBagsBankTabStripMixin)
    strip:OnLoad(bankFrame, bankType)

    bankFrame._djbagsTabStrip = strip
    return strip
end
