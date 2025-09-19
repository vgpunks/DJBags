
local ADDON_NAME, ADDON = ...

local UNPACK = table.unpack or unpack

DJBagsBankTabsMixin = {}

-- ------- Helpers -------

local function GetCharacterPurchasedTabIDs()
    if C_Bank and C_Bank.FetchPurchasedBankTabIDs and Enum and Enum.BankType then
        local ok, ids = pcall(C_Bank.FetchPurchasedBankTabIDs, Enum.BankType.Character)
        if ok and type(ids) == "table" and #ids > 0 then
            return ids
        end
    end
    return {
        (Enum.BagIndex and Enum.BagIndex.CharacterBankTab_1) or 1,
        (Enum.BagIndex and Enum.BagIndex.CharacterBankTab_2) or 2,
        (Enum.BagIndex and Enum.BagIndex.CharacterBankTab_3) or 3,
        (Enum.BagIndex and Enum.BagIndex.CharacterBankTab_4) or 4,
        (Enum.BagIndex and Enum.BagIndex.CharacterBankTab_5) or 5,
        (Enum.BagIndex and Enum.BagIndex.CharacterBankTab_6) or 6,
    }
end

local function FetchTabData(bankType)
    local map = {}
    if C_Bank and C_Bank.FetchPurchasedBankTabData then
        local ok, data = pcall(C_Bank.FetchPurchasedBankTabData, bankType)
        if ok and type(data) == "table" then
            for _, entry in ipairs(data) do
                local id = entry.bagID or entry[1]
                if id then
                    map[id] = {
                        name  = entry.name or entry[2],
                        icon  = entry.icon or entry[3],
                        flags = entry.depositFlags or entry[4],
                    }
                end
            end
        end
    end
    return map
end

local function GetTabNameAndIcon(bankType, bagID, tabMap)
    local e = tabMap and tabMap[bagID]
    if e then
        return e.name, e.icon, e.flags
    end
    local name = (C_Container and C_Container.GetBagName and C_Container.GetBagName(bagID)) or ("Tab "..tostring(bagID))
    local icon = 134400
    return name, icon, 0
end

local function MakeTabButton(parent, icon)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(32, 32)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:EnableMouse(true)
    b:SetMouseMotionEnabled(true)

    b:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    b:SetBackdropColor(0,0,0,0.6)

    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints(true)
    b.icon:SetTexture(icon or 134400)

    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
    b.hl:SetAllPoints(true)
    b.hl:SetColorTexture(1,1,1,0.08)

    b:Show()
    return b
end

local function LayoutButtons(self)
    local pad = 2
    local y = -8
    for _, b in ipairs(self.buttons or {}) do
        b:ClearAllPoints()
        b:SetPoint("TOPRIGHT", self, "TOPRIGHT", -8, y)
        y = y - (b:GetHeight() + pad)
    end
    self:SetHeight(math.max(36, -y + 8))
end

-- ------- Mixin -------

function DJBagsBankTabsMixin:OnLoad()
    self.buttons = {}
    self.selectedTab = nil
    self.bankFrame = DJBagsBank

    if self.bankFrame and self.bankFrame.bankBag and not self.bankFrame.bankBag.allBags then
        local bags = self.bankFrame.bankBag.bags
        if bags then
            self.bankFrame.bankBag.allBags = { UNPACK(bags) }
        end
    end

    if self.Refresh then self:Refresh() end
end

function DJBagsBankTabsMixin:Refresh()
    self:Rebuild()
end

function DJBagsBankTabsMixin:ClearButtons()
    if not self.buttons then return end
    for _, b in ipairs(self.buttons) do
        b:Hide()
        b:SetParent(nil)
    end
    wipe(self.buttons)
end

function DJBagsBankTabsMixin:Rebuild()
    print("DJBagsBankTabs: Rebuild()")
    self:ClearButtons()

    -- All button
    local allBtn = MakeTabButton(self, 132987) -- INV_Misc_Bag_08
    allBtn.isAll = true
    allBtn:SetScript("OnEnter", function()
        GameTooltip:SetOwner(allBtn, "ANCHOR_RIGHT")
        GameTooltip:SetText("All Tabs")
        GameTooltip:Show()
    end)
    allBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    allBtn:SetScript("OnClick", function(_, button)
        if button == "RightButton" then return end
        self:SelectTab(nil)
    end)
    table.insert(self.buttons, allBtn)

    -- Character tabs
    local ids = GetCharacterPurchasedTabIDs()
    local tabMap = FetchTabData(Enum.BankType and Enum.BankType.Character or 0)
    for _, bagID in ipairs(ids) do
        if type(bagID) == "number" and bagID > 0 then
            local name, icon = GetTabNameAndIcon(Enum.BankType.Character, bagID, tabMap)
            local b = MakeTabButton(self, icon)
            b.bagID = bagID
            b:SetScript("OnEnter", function()
                GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
                GameTooltip:SetText(name or "Tab")
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)
            b:SetScript("OnClick", function(btn, mouseButton)
                if mouseButton == "RightButton" then
                    -- EasyMenu context menu
                    local menu = {
                        { text = name or "Tab", isTitle = true, notCheckable = true },
                        { text = RENAME, notCheckable = true, func = function()
                            StaticPopupDialogs["DJBAGS_RENAME_TAB"] = {
                                text = RENAME..":",
                                button1 = ACCEPT, button2 = CANCEL,
                                hasEditBox = true, maxLetters = 20,
                                OnAccept = function(popup)
                                    local newName = popup.editBox:GetText()
                                    if C_Bank and C_Bank.UpdateBankTabSettings and Enum and Enum.BankType then
                                        C_Bank.UpdateBankTabSettings(Enum.BankType.Character, btn.bagID, newName, icon, nil)
                                    end
                                    self:Refresh()
                                end,
                                EditBoxOnEnterPressed = function(popup) popup.button1:Click() end,
                                timeout = 0, whileDead = true, hideOnEscape = true,
                            }
                            StaticPopup_Show("DJBAGS_RENAME_TAB")
                        end },
                        { text = "Change Icon", notCheckable = true, func = function()
                            if IconPickerFrame_Open then
                                IconPickerFrame_Open(function(texture)
                                    if C_Bank and C_Bank.UpdateBankTabSettings and Enum and Enum.BankType then
                                        C_Bank.UpdateBankTabSettings(Enum.BankType.Character, btn.bagID, name, texture, nil)
                                    end
                                    self:Refresh()
                                end, icon)
                            end
                        end },
                    }
                    EasyMenu(menu, CreateFrame("Frame", "DJBagsBankTabMenu", UIParent, "UIDropDownMenuTemplate"), "cursor", 0, 0, "MENU")
                else
                    self:SelectTab(btn.bagID)
                end
            end)
            table.insert(self.buttons, b)
        end
    end

    -- Purchase button
    if C_Bank and C_Bank.HasMaxBankTabs and Enum and Enum.BankType then
        local ok, hasMax = pcall(C_Bank.HasMaxBankTabs, Enum.BankType.Character)
        if ok and not hasMax then
            local buy = MakeTabButton(self, 133784) -- coin icon
            buy:SetScript("OnEnter", function()
                GameTooltip:SetOwner(buy, "ANCHOR_RIGHT")
                GameTooltip:SetText("Purchase a new bank tab")
                GameTooltip:Show()
            end)
            buy:SetScript("OnLeave", function() GameTooltip:Hide() end)
            buy:SetScript("OnClick", function()
                if C_Bank.PurchaseBankTab then
                    C_Bank.PurchaseBankTab(Enum.BankType.Character)
                end
            end)
            table.insert(self.buttons, buy)
        end
    end

    LayoutButtons(self)
    self:SelectTab(self.selectedTab) -- maintain selection
    self:Show()

    print("DJBagsBankTabs: created buttons", #self.buttons)
end

function DJBagsBankTabsMixin:ApplyFilter()
    local bag = self.bankFrame and self.bankFrame.bankBag
    if not bag then return end

    if self.selectedTab == nil then
        if bag.allBags then
            bag.bags = { UNPACK(bag.allBags) }
            bag.bagsByKey = {}
            for _, v in ipairs(bag.bags) do bag.bagsByKey[v] = true end
        end
        if bag.Refresh then bag:Refresh() end
        return
    end

    -- selecting a single tab
    bag.allBags = bag.allBags or { UNPACK(bag.bags or {}) }
    bag.bags = { self.selectedTab }
    bag.bagsByKey = { [self.selectedTab] = true }

    if bag.Refresh then bag:Refresh() end
end

function DJBagsBankTabsMixin:SelectTab(tabID)
    self.selectedTab = tabID
    self:ApplyFilter()

    for _, b in ipairs(self.buttons or {}) do
        local isSelected = (b.bagID == tabID) or (tabID == nil and b.isAll)
        if isSelected then
            b:SetBackdropBorderColor(1,0.82,0,1)
        else
            b:SetBackdropBorderColor(0.2,0.2,0.2,1)
        end
    end
end
