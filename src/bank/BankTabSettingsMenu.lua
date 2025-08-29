local NAME, ADDON = ...

--[[
    Create a simple bank tab settings frame from scratch.

    The default Blizzard implementation is tightly coupled to the
    BankFrame's internal layout and expects to be parented to it.
    Replicating the Blizzard menu introduced a number of issues for
    character bank tabs where only an empty background frame would be
    created.  To avoid those problems we construct a lightweight menu
    ourselves using the generic IconSelectorPopupFrameTemplate.

    The menu allows the user to rename a tab and choose a new icon.
    Deposit setting checkboxes are intentionally omitted; the goal is
    simply to provide a functional frame that reliably edits character
    bank tabs.
]]

local function FetchTabInfo(bankType, tabIndex)
    if not C_Bank then
        return nil, nil
    end

    if C_Bank.GetBankTabInfo then
        local info = C_Bank.GetBankTabInfo(bankType, tabIndex)
        if info then
            local icon = info.icon or info.iconFileID or info.iconTexture
            return info.name, icon
        end
    end

    if C_Bank.FetchPurchasedBankTabData then
        local tabData = C_Bank.FetchPurchasedBankTabData(bankType)
        if tabData then
            local info = tabData[tabIndex]
            if not info then
                for _, data in ipairs(tabData) do
                    local id = data.ID or data.bankTabID
                    if id == tabIndex then
                        info = data
                        break
                    end
                end
            end
            if info then
                local icon = info.icon or info.iconFileID or info.iconTexture
                return info.name, icon
            end
        end
    end

    return nil, nil
end

local function CreateSettingsMenu()
    -- Use the generic icon selector template which provides a name edit
    -- box and icon picker.
    local frame = CreateFrame("Frame", "DJBagsBankTabSettingsMenu", UIParent, "IconSelectorPopupFrameTemplate")
    frame:Hide()

    -- Frames created via CreateFrame do not automatically execute their
    -- OnLoad handler.  Initialize the mixin so the icon selector behaves
    -- correctly.
    if frame.OnLoad then
        frame:OnLoad()
    end

    frame.BorderBox.IconSelectorEditBox:SetAutoFocus(false)

    -- Track the currently selected icon.
    frame.selectedIcon = QUESTION_MARK_ICON

    frame.IconSelector:SetSelectedCallback(function(_, icon)
        frame.selectedIcon = icon
        frame.BorderBox.SelectedIconArea.SelectedIconButton:SetIconTexture(icon)
        frame.BorderBox.SelectedIconArea.SelectedIconText.SelectedIconDescription:SetText(ICON_SELECTION_CLICK)
        frame.BorderBox.SelectedIconArea.SelectedIconText.SelectedIconDescription:SetFontObject(GameFontHighlightSmall)
    end)

    -- Populate the menu with data for the requested tab.
    function frame:Load(bankType, tabIndex)
        self.bankType = bankType
        self.tabIndex = tabIndex

        local name, icon = FetchTabInfo(bankType, tabIndex)

        self.BorderBox.IconSelectorEditBox:SetText(name or "")
        self.selectedIcon = icon or QUESTION_MARK_ICON
        self.BorderBox.SelectedIconArea.SelectedIconButton:SetIconTexture(self.selectedIcon)

        self.BorderBox.IconSelectorEditBox:HighlightText()
    end

    -- Commit any changes to the tab when the user accepts the dialog.
    frame.BorderBox.OkayButton:SetScript("OnClick", function()
        if C_Bank and C_Bank.UpdateBankTabSettings and frame.bankType and frame.tabIndex then
            local newName = frame.BorderBox.IconSelectorEditBox:GetText()
            C_Bank.UpdateBankTabSettings(frame.bankType, frame.tabIndex, newName, frame.selectedIcon, nil)
        end
        frame:Hide()
        PlaySound(SOUNDKIT.GS_TITLE_OPTION_OK)
    end)

    -- Simply hide the frame when cancelled.
    frame.BorderBox.CancelButton:SetScript("OnClick", function()
        frame:Hide()
        PlaySound(SOUNDKIT.GS_TITLE_OPTION_OK)
    end)

    -- Helper to open the menu for a given tab.
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
        self.bankTabSettingsMenu = CreateSettingsMenu()
    end
    return self.bankTabSettingsMenu
end

