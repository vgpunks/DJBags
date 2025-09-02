local NAME, ADDON = ...

--[[
    Create a simple bank tab settings frame from scratch.

    The default Blizzard implementation is tightly coupled to the
    BankFrame's internal layout and expects to be parented to it.
    Replicating the Blizzard menu introduced a number of issues for
    character bank tabs where only an empty background frame would be
    created.  To avoid those problems we construct a lightweight menu
    ourselves using the generic IconSelectorPopupFrameTemplate.

    The menu allows the user to rename a tab, choose a new icon and adjust
    deposit behavior.  It provides a functional frame that reliably edits
    character bank tabs across different client versions.
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

    -- Some API variants return a table with the data instead of multiple
    -- discrete values.  Normalize the results so callers always receive
    -- name, icon, and deposit flag fields.
    if type(name) == "table" then
        local info = name
        name = info.name
        icon = info.icon or info.iconFileID or info.iconTexture
        depositFlags = info.depositFlags or info.flags or info.depositFlag
    end

    if not name then
        name, icon, depositFlags = Try(C_Bank.GetBankTabInfo, bankType, tabIndex)
            or Try(C_Bank.GetBankTabInfo, tabIndex, bankType)
            or Try(C_Bank.GetBankTabInfo, tabIndex)

        if type(name) == "table" then
            local info = name
            name = info.name
            icon = info.icon or info.iconFileID or info.iconTexture
            depositFlags = info.depositFlags or info.flags or info.depositFlag
        end
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

    if type(name) == "table" then
        local info = name
        name = info.name
        icon = info.icon or info.iconFileID or info.iconTexture
        depositFlags = info.depositFlags or info.flags or info.depositFlag
    end

    return name, icon, depositFlags
end

-- Fallback flags for clients that do not provide the enumeration table.  The
-- numeric values mirror the retail constants so UpdateBankTabSettings receives
-- the expected bitfield regardless of game version.
local BankTabSettingFlags = Enum.BankTabSettingFlags or {
    AllowAutoDeposit = 1,
    DisableAutoStore = 2,
    IsPublic = 4,
}

-- Helper to update a bank tab's settings across differing API versions.  Try
-- multiple call signatures so both modern and legacy clients handle the
-- request.  The call order mirrors FetchTabInfo's approach but omits nil
-- arguments for builds that do not support deposit flags.
local function UpdateTabSettings(bankType, tabIndex, name, icon, depositFlags)
    if not C_Bank or not C_Bank.UpdateBankTabSettings then
        return
    end

    local function Try(func, ...)
        if not func then return end
        local ok = pcall(func, ...)
        if ok then return true end
    end

    return Try(C_Bank.UpdateBankTabSettings, bankType, tabIndex, name, icon, depositFlags)
        or Try(C_Bank.UpdateBankTabSettings, tabIndex, bankType, name, icon, depositFlags)
        or Try(C_Bank.UpdateBankTabSettings, tabIndex, name, icon, depositFlags)
        or Try(C_Bank.UpdateBankTabSettings, bankType, tabIndex, name, icon)
        or Try(C_Bank.UpdateBankTabSettings, tabIndex, bankType, name, icon)
        or Try(C_Bank.UpdateBankTabSettings, tabIndex, name, icon)
        or Try(C_Bank.UpdateBankTabSettings, bankType, tabIndex, name)
        or Try(C_Bank.UpdateBankTabSettings, tabIndex, bankType, name)
        or Try(C_Bank.UpdateBankTabSettings, tabIndex, name)
end

local function CreateSettingsMenu()
    -- Ensure the Blizzard icon selector UI is loaded before creating the frame.
    if C_AddOns and C_AddOns.LoadAddOn then
        -- Retail clients expose the loader via C_AddOns.
        pcall(C_AddOns.LoadAddOn, "Blizzard-IconSelector")
        pcall(C_AddOns.LoadAddOn, "Blizzard_IconSelector")
        pcall(C_AddOns.LoadAddOn, "Blizzard_IconSelectorUI")
        pcall(C_AddOns.LoadAddOn, "Blizzard-IconSelectorUI")
    elseif LoadAddOn then
        -- Fallback for older clients with the global loader.
        pcall(LoadAddOn, "Blizzard-IconSelector")
        pcall(LoadAddOn, "Blizzard_IconSelector")
        pcall(LoadAddOn, "Blizzard_IconSelectorUI")
        pcall(LoadAddOn, "Blizzard-IconSelectorUI")
    elseif UIParentLoadAddOn then
        -- Final fallback in case UIParentLoadAddOn is available instead.
        pcall(UIParentLoadAddOn, "Blizzard-IconSelector")
        pcall(UIParentLoadAddOn, "Blizzard_IconSelector")
        pcall(UIParentLoadAddOn, "Blizzard_IconSelectorUI")
        pcall(UIParentLoadAddOn, "Blizzard-IconSelectorUI")
    end

    -- Use the generic icon selector template which provides a name edit
    -- box and icon picker.
    local frame = CreateFrame("Frame", "DJBagsBankTabSettingsMenu", UIParent, "IconSelectorPopupFrameTemplate")
    frame:Hide()
    -- Ensure the popup consumes mouse input so underlying bag slots do not
    -- display tooltips while the settings menu is open.
    frame:EnableMouse(true)
    frame:SetToplevel(true)
    frame:SetScript("OnEnter", GameTooltip_Hide)

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
        if frame.IconSelector.iconDataProvider and frame.IconSelector.iconDataProvider.GenerateIconList then
            pcall(frame.IconSelector.iconDataProvider.GenerateIconList, frame.IconSelector.iconDataProvider)
        end
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

    if frame.BorderBox and frame.BorderBox.EnableMouse then
        frame.BorderBox:EnableMouse(true)
    end

    -- Darken the background so the menu overlays the bank frame similar to
    -- Blizzard's implementation.
    frame.BG = frame:CreateTexture(nil, "BACKGROUND")
    frame.BG:SetAllPoints(frame)
    frame.BG:SetColorTexture(0, 0, 0, 0.6)

    -- Some game versions parent the icon selector outside the BorderBox.
    -- Reanchor the grid so it always appears beneath the name field.
    if frame.IconSelector and frame.BorderBox then
        frame.IconSelector:SetParent(frame.BorderBox)
        frame.IconSelector:ClearAllPoints()
        frame.IconSelector:SetPoint("TOPLEFT", frame.BorderBox.SelectedIconArea, "BOTTOMLEFT", 0, -10)
        frame.IconSelector:SetPoint("BOTTOMRIGHT", frame.BorderBox, "BOTTOMRIGHT", -5, 40)
    end

    -- Track the currently selected icon.
    frame.selectedIcon = QUESTION_MARK_ICON

    frame.IconSelector:SetSelectedCallback(function(_, icon)
        frame.selectedIcon = icon
        frame.BorderBox.SelectedIconArea.SelectedIconButton:SetIconTexture(icon)
        frame.BorderBox.SelectedIconArea.SelectedIconText.SelectedIconDescription:SetText(ICON_SELECTION_CLICK)
        frame.BorderBox.SelectedIconArea.SelectedIconText.SelectedIconDescription:SetFontObject(GameFontHighlightSmall)
    end)

    -- Container for optional deposit setting checkboxes mirroring the
    -- Blizzard menu.  The options are grouped in a dedicated menu so they can
    -- be positioned consistently regardless of client version.
    frame.DepositSettingsMenu = CreateFrame("Frame", nil, frame)
    frame.DepositSettingsMenu:SetPoint("TOPLEFT", frame.BorderBox.IconSelectorEditBox, "BOTTOMLEFT", 0, -8)
    frame.DepositSettingsMenu:SetPoint("RIGHT", frame.BorderBox, "RIGHT", 0, 0)
    frame.DepositSettingsMenu:SetHeight(1)
    frame.DepositSettingsMenu:Hide()
    frame.DepositSettingsMenu:SetFrameLevel((frame.BorderBox and frame.BorderBox:GetFrameLevel() or 1) + 1)

    frame.depositChecks = {}
    local function AddDepositOption(flag, label)
        -- Some clients do not provide the InterfaceOptionsSmallCheckButtonTemplate
        -- used by the retail UI.  Attempt to create the checkbox using that
        -- template and gracefully fall back to more common alternatives so the
        -- settings menu works across different game versions.
        local check
        local ok, result = pcall(CreateFrame, "CheckButton", nil, frame.DepositSettingsMenu, "InterfaceOptionsSmallCheckButtonTemplate")
        if ok and result then
            check = result
        else
            ok, result = pcall(CreateFrame, "CheckButton", nil, frame.DepositSettingsMenu, "UICheckButtonTemplate")
            if ok and result then
                check = result
            else
                check = CreateFrame("CheckButton", nil, frame.DepositSettingsMenu)
                local text = check:CreateFontString(nil, "ARTWORK", "GameFontNormal")
                text:SetPoint("LEFT", check, "RIGHT", 0, 1)
                check.Text = text
            end
        end

        local index = #frame.depositChecks
        check:SetPoint("TOPLEFT", frame.DepositSettingsMenu, "TOPLEFT", 0, -index * 22)
        if check.Text then
            check.Text:SetText(label)
        end
        check:SetScript("OnClick", function(self)
            if self:GetChecked() then
                frame.depositFlags = bit.bor(frame.depositFlags or 0, flag)
            else
                frame.depositFlags = bit.band(frame.depositFlags or 0, bit.bnot(flag))
            end
        end)
        table.insert(frame.depositChecks, {button = check, flag = flag})
        frame.DepositSettingsMenu:SetHeight((index + 1) * 22)
    end

    if BankTabSettingFlags then
        -- Known flag providing auto deposit control.
        if BankTabSettingFlags.AllowAutoDeposit then
            AddDepositOption(BankTabSettingFlags.AllowAutoDeposit, BANK_TAB_ALLOW_AUTO_DEPOSIT or "Allow Auto-Deposit")
        elseif BankTabSettingFlags.DisableAutoStore then
            AddDepositOption(BankTabSettingFlags.DisableAutoStore, BANK_TAB_ALLOW_AUTO_DEPOSIT or "Allow Auto-Deposit")
        end

        -- Flag to control public visibility if available.
        if BankTabSettingFlags.IsPublic then
            AddDepositOption(BankTabSettingFlags.IsPublic, BANK_TAB_PUBLIC or "Public Tab")
        end
    end

    -- If deposit checkboxes were added, shift the icon selector below their
    -- container so the layout matches Blizzard's frame stack.
    if frame.IconSelector and frame.BorderBox and #frame.depositChecks > 0 then
        frame.DepositSettingsMenu:Show()
        frame.IconSelector:ClearAllPoints()
        frame.IconSelector:SetPoint("TOPLEFT", frame.DepositSettingsMenu, "BOTTOMLEFT", 0, -10)
        frame.IconSelector:SetPoint("BOTTOMRIGHT", frame.BorderBox, "BOTTOMRIGHT", -5, 40)
    end

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
            if self.iconDataProvider and self.iconDataProvider.GenerateIconList then
                pcall(self.iconDataProvider.GenerateIconList, self.iconDataProvider)
            end
        end

        local name, icon, depositFlags = FetchTabInfo(bankType, tabIndex)

        self.BorderBox.IconSelectorEditBox:SetText(name or "")
        self.selectedIcon = icon or QUESTION_MARK_ICON
        self.depositFlags = depositFlags or 0
        self.BorderBox.SelectedIconArea.SelectedIconButton:SetIconTexture(self.selectedIcon)

        if self.depositChecks then
            local showDeposit = #self.depositChecks > 0
            self.DepositSettingsMenu:SetShown(showDeposit)
            for _, data in ipairs(self.depositChecks) do
                data.button:SetShown(showDeposit)
                if showDeposit then
                    local checked = bit.band(self.depositFlags or 0, data.flag) ~= 0
                    data.button:SetChecked(checked)
                end
            end

            if self.IconSelector and self.BorderBox then
                self.IconSelector:ClearAllPoints()
                if showDeposit and self.DepositSettingsMenu:IsShown() then
                    self.IconSelector:SetPoint("TOPLEFT", self.DepositSettingsMenu, "BOTTOMLEFT", 0, -10)
                else
                    self.IconSelector:SetPoint("TOPLEFT", self.BorderBox.IconSelectorEditBox, "BOTTOMLEFT", 0, -10)
                end
                self.IconSelector:SetPoint("BOTTOMRIGHT", self.BorderBox, "BOTTOMRIGHT", -5, 40)
            end
        end

        -- Ensure the icon selector has data and displays the selected icon.
        if self.IconSelector then
            -- Reinitialize the selector when the provider was cleared on hide.
            if not self.IconSelector.iconDataProvider and self.IconSelector.OnLoad then
                self.IconSelector:OnLoad()
            end

            -- Some clients require the OnShow handler to run before icons are
            -- generated. Explicitly invoke it so the grid is populated even
            -- when the frame was constructed manually.
            if self.IconSelector.OnShow then
                self.IconSelector:OnShow()
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
                if self.iconDataProvider and self.iconDataProvider.GetNumIcons then
                    local ok, count = pcall(self.iconDataProvider.GetNumIcons, self.iconDataProvider)
                    if ok and count == 0 and self.iconDataProvider.GenerateIconList then
                        pcall(self.iconDataProvider.GenerateIconList, self.iconDataProvider)
                        if self.IconSelector.RefreshIcons then
                            self.IconSelector:RefreshIcons()
                        end
                    end
                end
            end
        end

        self.BorderBox.IconSelectorEditBox:HighlightText()
    end

    -- Resolve the okay and cancel buttons across differing template versions.
    local okayButton = (frame.BorderBox and frame.BorderBox.OkayButton) or frame.OkayButton or frame.AcceptButton
    local cancelButton = (frame.BorderBox and frame.BorderBox.CancelButton) or frame.CancelButton

    -- Reposition the action buttons beneath the icon grid if they're not already anchored.
    if okayButton and cancelButton and okayButton.ClearAllPoints and cancelButton.ClearAllPoints then
        cancelButton:ClearAllPoints()
        okayButton:ClearAllPoints()
        cancelButton:SetPoint("BOTTOMRIGHT", frame.BorderBox or frame, "BOTTOMRIGHT", -90, 5)
        okayButton:SetPoint("LEFT", cancelButton, "RIGHT", 4, 0)
    end

    if okayButton then
        -- Commit any changes to the tab when the user accepts the dialog.
        okayButton:Show()
        okayButton:SetScript("OnClick", function()
            local newName = frame.BorderBox.IconSelectorEditBox:GetText()
            UpdateTabSettings(frame.bankType, frame.tabIndex, newName, frame.selectedIcon, frame.depositFlags or 0)
            frame:Hide()
            PlaySound(SOUNDKIT.GS_TITLE_OPTION_OK)
        end)
    end

    if cancelButton then
        -- Simply hide the frame when cancelled.
        cancelButton:Show()
        cancelButton:SetScript("OnClick", function()
            frame:Hide()
            PlaySound(SOUNDKIT.GS_TITLE_OPTION_OK)
        end)
    end

    -- Helper to open the menu for a given tab.
    function frame:Open(bankType, tabIndex)
        self:Load(bankType, tabIndex)
        self:SetFrameStrata("FULLSCREEN_DIALOG")
        local anchor = BankFrame
        if Enum.BankType and bankType == Enum.BankType.Account then
            anchor = DJBagsWarbandBank or anchor
        else
            anchor = DJBagsBank or anchor
        end
        if self.SetParent then
            self:SetParent(anchor)
        end
        if self.ClearAllPoints then
            self:ClearAllPoints()
        end
        self:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
        self:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0)
        self:Show()
    end

    return frame
end

function ADDON:GetBankTabSettingsMenu(bankType)
    local menu

    -- Prefer our custom settings menu for character bank tabs so the
    -- icon selector is always initialized correctly.  Fall back to the
    -- Blizzard implementation only for account banks so features like
    -- deposit restrictions remain available.
    local useCustom = true
    if bankType and Enum.BankType and bankType == Enum.BankType.Account then
        useCustom = false
    end

    if not useCustom and BankPanel and BankPanel.TabSettingsMenu then
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
        function menu:Open(...)
            local bankType, tabIndex
            if select('#', ...) >= 2 then
                bankType, tabIndex = ...
            else
                tabIndex = ...
            end
            if baseOpen then
                baseOpen(self, bankType, tabIndex)
            end
            local anchor = BankFrame
            if Enum.BankType and bankType == Enum.BankType.Account then
                anchor = DJBagsWarbandBank or anchor
            else
                anchor = DJBagsBank or anchor
            end
            if self.SetParent then
                self:SetParent(anchor)
            end
            if self.SetFrameStrata then
                self:SetFrameStrata("FULLSCREEN_DIALOG")
            end
            if self.ClearAllPoints then
                self:ClearAllPoints()
            end
            if self.SetPoint then
                self:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
                self:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0)
            end
            if self.Show then
                self:Show()
            end
        end
        menu.DJBagsWrappedOpen = true
    end

    return menu
end

