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
        return nil, nil, nil
    end

    local name, icon, depositFlags

    -- Helper to safely invoke an API method using pcall and return all results.
    local function Try(func, ...)
        if not func then return end
        local ok, r1, r2, r3, r4 = pcall(func, ...)
        if ok then return r1, r2, r3, r4 end
    end

    -- Newer API versions expect (bankType, tabIndex) while older builds
    -- only take a tab index or use the reverse ordering.  Try a variety of
    -- call signatures so tab data is located regardless of client version.
    name, icon, depositFlags = Try(C_Bank.GetBankTabDisplayInfo, bankType, tabIndex)
        or Try(C_Bank.GetBankTabDisplayInfo, tabIndex, bankType)
        or Try(C_Bank.GetBankTabDisplayInfo, tabIndex)

    if not name then
        name, icon, depositFlags = Try(C_Bank.GetBankTabInfo, bankType, tabIndex)
            or Try(C_Bank.GetBankTabInfo, tabIndex, bankType)
            or Try(C_Bank.GetBankTabInfo, tabIndex)
    end

    if not name then
        local tabData = Try(C_Bank.GetPurchasedBankTabData, bankType)
            or Try(C_Bank.FetchPurchasedBankTabData, bankType)
            or Try(C_Bank.GetPurchasedBankTabData)
            or Try(C_Bank.FetchPurchasedBankTabData)
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
                name = info.name
                icon = info.icon or info.iconFileID or info.iconTexture
                depositFlags = info.depositFlags or info.flags or info.depositFlag
            end
        end
    end

    return name, icon, depositFlags
end

local function CreateSettingsMenu()
    -- Use the generic icon selector template which provides a name edit
    -- box and icon picker.
    local frame = CreateFrame("Frame", "DJBagsBankTabSettingsMenu", UIParent, "IconSelectorPopupFrameTemplate")
    frame:Hide()

    -- Frames created via CreateFrame do not automatically execute their
    -- OnLoad handler.  Initialize the mixin so the icon selector behaves
    -- correctly.
    --
    -- The popup frame's OnLoad expects the icon selector child to have run
    -- its own initialization first so that the data provider is available.
    -- Call the child's OnLoad before the parent's and wire the data
    -- provider immediately so the parent can safely reference it when
    -- setting up filtering.
    if frame.IconSelector and frame.IconSelector.OnLoad then
        frame.IconSelector:OnLoad()
    end

    -- The popup frame mixin expects to reference the icon selector's data
    -- provider directly. Replicate the setup normally performed by the
    -- template prior to calling the parent's OnLoad so filtering works
    -- without errors.
    if frame.IconSelector then
        frame.iconDataProvider = frame.IconSelector.iconDataProvider
    end

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

    -- Ensure the data provider is always available when changing the icon filter.
    if frame.SetIconFilter then
        local originalSetIconFilter = frame.SetIconFilter
        function frame:SetIconFilter(iconFilter)
            if not self.iconDataProvider and self.IconSelector then
                if not self.IconSelector.iconDataProvider and self.IconSelector.OnLoad then
                    self.IconSelector:OnLoad()
                end
                self.iconDataProvider = self.IconSelector.iconDataProvider
            end
            originalSetIconFilter(self, iconFilter)
        end
    end

    if frame.SetIconFilterInternal then
        local originalSetIconFilterInternal = frame.SetIconFilterInternal
        function frame:SetIconFilterInternal(...)
            if not self.iconDataProvider and self.IconSelector then
                if not self.IconSelector.iconDataProvider and self.IconSelector.OnLoad then
                    self.IconSelector:OnLoad()
                end
                self.iconDataProvider = self.IconSelector.iconDataProvider
            end
            originalSetIconFilterInternal(self, ...)
        end
    end

    -- Populate the menu with data for the requested tab.
    function frame:Load(bankType, tabIndex)
        self.bankType = bankType
        self.tabIndex = tabIndex

        -- The icon selector's data provider is cleared whenever the popup
        -- frame is hidden. Reinitialize the child frame as needed and wire
        -- the provider so filtering works when the menu is reopened.
        if self.IconSelector then
            if not self.IconSelector.iconDataProvider and self.IconSelector.OnLoad then
                self.IconSelector:OnLoad()
            end
            self.iconDataProvider = self.IconSelector.iconDataProvider
        end

        local name, icon, depositFlags = FetchTabInfo(bankType, tabIndex)

        self.BorderBox.IconSelectorEditBox:SetText(name or "")
        self.selectedIcon = icon or QUESTION_MARK_ICON
        self.depositFlags = depositFlags or 0
        self.BorderBox.SelectedIconArea.SelectedIconButton:SetIconTexture(self.selectedIcon)

        -- Ensure the icon selector has data and displays the selected icon.
        if self.IconSelector then
            -- Reinitialize the selector when the provider was cleared on hide.
            if not self.IconSelector.iconDataProvider and self.IconSelector.OnLoad then
                self.IconSelector:OnLoad()
            end

            if self.IconSelector.SetSelectedIcon then
                self.IconSelector:SetSelectedIcon(self.selectedIcon)
            end

            -- Clearing any leftover search filter avoids an empty grid.
            if self.IconSelector.ClearSearchFilter then
                self.IconSelector:ClearSearchFilter()
            end

            if self.IconSelector.RefreshIcons then
                self.IconSelector:RefreshIcons()
            end
        end

        self.BorderBox.IconSelectorEditBox:HighlightText()
    end

    -- Commit any changes to the tab when the user accepts the dialog.
    frame.BorderBox.OkayButton:SetScript("OnClick", function()
        if C_Bank and C_Bank.UpdateBankTabSettings and frame.bankType and frame.tabIndex then
            local newName = frame.BorderBox.IconSelectorEditBox:GetText()
            C_Bank.UpdateBankTabSettings(frame.bankType, frame.tabIndex, newName, frame.selectedIcon, frame.depositFlags or 0)
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
        local anchor = BankFrame
        if Enum.BankType and bankType == Enum.BankType.Account then
            anchor = DJBagsWarbandBank or anchor
        else
            anchor = DJBagsBank or anchor
        end
        self:SetPoint("TOPLEFT", anchor, "TOPRIGHT")
        self:Show()
    end

    return frame
end

function ADDON:GetBankTabSettingsMenu()
    local menu

    if BankPanel and BankPanel.TabSettingsMenu then
        menu = BankPanel.TabSettingsMenu
    else
        if not self.bankTabSettingsMenu then
            self.bankTabSettingsMenu = CreateSettingsMenu()
        end
        menu = self.bankTabSettingsMenu
    end

    -- Ensure the settings menu can always be opened and anchored near our
    -- custom bank frames.  Some game versions provide a built-in menu with an
    -- existing Open method that anchors to Blizzard's BankPanel.  That frame is
    -- moved off-screen by DJBags, resulting in the menu appearing invisible.
    -- Wrap the menu's Open behavior so the menu is always positioned relative
    -- to our active bank frame and parented to a visible frame.
    if menu and not menu.DJBagsWrappedOpen then
        local baseOpen = menu.Open
        function menu:Open(bankType, tabIndex)
            if baseOpen then
                baseOpen(self, bankType, tabIndex)
            end
            if self.Load then
                self:Load(bankType, tabIndex)
            end
            if self.SetParent then
                self:SetParent(UIParent)
            end
            if self.SetFrameStrata then
                self:SetFrameStrata("FULLSCREEN_DIALOG")
            end
            if self.ClearAllPoints then
                self:ClearAllPoints()
            end
            if self.SetPoint then
                local anchor = BankFrame
                if Enum.BankType and bankType == Enum.BankType.Account then
                    anchor = DJBagsWarbandBank or anchor
                else
                    anchor = DJBagsBank or anchor
                end
                self:SetPoint("TOPLEFT", anchor, "TOPRIGHT")
            end
            if self.Show then
                self:Show()
            end
        end
        menu.DJBagsWrappedOpen = true
    end

    return menu
end

