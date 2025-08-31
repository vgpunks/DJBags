local NAME, ADDON = ...

--[[
    Custom frame for editing character bank tab settings in patch 11.2.

    The Blizzard menu is tightly coupled to their BankFrame so we build a
    lightweight replacement that exposes the same options:
      * rename the tab
      * choose a new icon
      * configure deposit flags

    The frame intentionally avoids any legacy API fallbacks and relies on the
    11.2 C_Bank API.
]]

local function GetTabSettings(bankType, tabIndex)
    if not C_Bank or not C_Bank.GetBankTabSettings then
        return
    end
    return C_Bank.GetBankTabSettings(bankType, tabIndex)
end

local function GetDepositOptions(bankType, tabIndex)
    if C_Bank and C_Bank.GetBankTabDepositOptions then
        return C_Bank.GetBankTabDepositOptions(bankType, tabIndex) or {}
    end
    return {}
end

local function CreateMenu()
    local frame = CreateFrame("Frame", "DJBagsBankTabSettings", UIParent, "ButtonFrameTemplate")
    frame:Hide()
    frame:SetSize(320, 420)
    frame.TitleText:SetText(BANK_TAB_SETTINGS or "Bank Tab Settings")

    -- name box
    frame.nameBox = CreateFrame("EditBox", "$parentNameBox", frame, "InputBoxTemplate")
    frame.nameBox:SetSize(220, 20)
    frame.nameBox:SetAutoFocus(false)
    frame.nameBox:SetPoint("TOP", 0, -40)

    -- icon button
    frame.iconButton = CreateFrame("Button", "$parentIconButton", frame, "ItemButtonTemplate")
    frame.iconButton:SetPoint("TOPLEFT", frame.nameBox, "BOTTOMLEFT", -4, -10)
    frame.iconButton.Icon:SetTexture(QUESTION_MARK_ICON)

    local function EnsureIconPicker()
        if frame.iconPicker then return end
        frame.iconPicker = CreateFrame("Frame", "$parentIconPicker", frame, "IconSelectorPopupFrameTemplate")
        frame.iconPicker:Hide()
        if frame.iconPicker.IconSelector and frame.iconPicker.IconSelector.OnLoad then
            frame.iconPicker.IconSelector:OnLoad()
        end
        if frame.iconPicker.OnLoad then
            frame.iconPicker:OnLoad()
        end
        if frame.iconPicker.IconSelector and frame.iconPicker.IconSelector.SetSelectedCallback then
            frame.iconPicker.IconSelector:SetSelectedCallback(function(_, icon)
                frame.iconPicker.selectedIcon = icon
            end)
        end
        frame.iconPicker.BorderBox.OkayButton:SetScript("OnClick", function()
            frame.selectedIcon = frame.iconPicker.selectedIcon or QUESTION_MARK_ICON
            frame.iconButton.Icon:SetTexture(frame.selectedIcon)
            frame.iconPicker:Hide()
        end)
        frame.iconPicker.BorderBox.CancelButton:SetScript("OnClick", function()
            frame.iconPicker:Hide()
        end)
    end

    frame.iconButton:SetScript("OnClick", function()
        EnsureIconPicker()
        frame.iconPicker.selectedIcon = frame.selectedIcon
        frame.iconPicker:SetPoint("TOPLEFT", frame, "TOPRIGHT")
        frame.iconPicker:Show()
        if frame.iconPicker.IconSelector and frame.iconPicker.IconSelector.SetSelectedIcon then
            frame.iconPicker.IconSelector:SetSelectedIcon(frame.selectedIcon)
        end
    end)

    -- deposit options
    frame.depositChecks = {}
    local function BuildDepositChecks()
        for _, check in ipairs(frame.depositChecks) do check:Hide() end
        wipe(frame.depositChecks)
        local options = GetDepositOptions(frame.bankType, frame.tabIndex)
        local prev
        for i, opt in ipairs(options) do
            local check = CreateFrame("CheckButton", "$parentDepositOption"..i, frame, "InterfaceOptionsCheckButtonTemplate")
            check.Text:SetText(opt.name or opt.text or ("Option"..i))
            check.flag = opt.flag or 0
            if prev then
                check:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -4)
            else
                check:SetPoint("TOPLEFT", frame.iconButton, "BOTTOMLEFT", 0, -16)
            end
            frame.depositChecks[i] = check
            prev = check
        end
    end

    -- accept and cancel buttons
    frame.acceptButton = CreateFrame("Button", "$parentAcceptButton", frame, "UIPanelButtonTemplate")
    frame.acceptButton:SetSize(96, 22)
    frame.acceptButton:SetPoint("BOTTOMRIGHT", -16, 16)
    frame.acceptButton:SetText(OKAY)
    frame.acceptButton:SetScript("OnClick", function()
        local name = frame.nameBox:GetText()
        local icon = frame.selectedIcon or QUESTION_MARK_ICON
        local flags = 0
        for _, check in ipairs(frame.depositChecks) do
            if check:GetChecked() then
                flags = bit.bor(flags, check.flag)
            end
        end
        if C_Bank and C_Bank.UpdateBankTabSettings then
            C_Bank.UpdateBankTabSettings(frame.bankType, frame.tabIndex, name, icon, flags)
        end
        frame:Hide()
        PlaySound(SOUNDKIT.GS_TITLE_OPTION_OK)
    end)

    frame.cancelButton = CreateFrame("Button", "$parentCancelButton", frame, "UIPanelButtonTemplate")
    frame.cancelButton:SetSize(96, 22)
    frame.cancelButton:SetPoint("BOTTOMLEFT", 16, 16)
    frame.cancelButton:SetText(CANCEL)
    frame.cancelButton:SetScript("OnClick", function()
        frame:Hide()
        PlaySound(SOUNDKIT.GS_TITLE_OPTION_OK)
    end)

    function frame:Load(bankType, tabIndex)
        self.bankType = bankType
        self.tabIndex = tabIndex
        local info = GetTabSettings(bankType, tabIndex)
        local name = info and info.name or ""
        local icon = info and info.icon or QUESTION_MARK_ICON
        local flags = info and info.depositFlags or 0
        self.nameBox:SetText(name)
        self.selectedIcon = icon
        self.iconButton.Icon:SetTexture(icon)
        BuildDepositChecks()
        for _, check in ipairs(self.depositChecks) do
            check:SetChecked(bit.band(flags, check.flag) ~= 0)
        end
        self.nameBox:HighlightText()
    end

    function frame:Open(bankType, tabIndex)
        self:Load(bankType, tabIndex)
        self:SetFrameStrata("FULLSCREEN_DIALOG")
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", BankFrame, "TOPRIGHT")
        self:Show()
    end

    return frame
end

function ADDON:GetBankTabSettingsMenu()
    if not self.bankTabSettingsMenu then
        self.bankTabSettingsMenu = CreateMenu()
    end
    return self.bankTabSettingsMenu
end

