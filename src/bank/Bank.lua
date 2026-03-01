local ADDON_NAME, ADDON = ...

local bank = {}
bank.__index = bank

--
-- Midnight+: Avoid bank-related taint that can break protected item actions
-- (eg. right-clicking mounts/pets to learn) after visiting the bank.
--
-- Root cause: aggressively altering Blizzard's BankFrame (unregistering
-- events, replacing scripts, moving/scaling offscreen) can leave tainted
-- state in BankFrame/BankPanel that later affects container item clicks.
--

local function DJBagsSafeHideBankPanel()
    if not BankFrame or not BankFrame.BankPanel or not BankFrame.BankPanel.Hide then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        ADDON._djbagsNeedsHideBankPanel = true
        if ADDON.eventManager and not ADDON._djbagsHideBankPanelCombatHook then
            ADDON._djbagsHideBankPanelCombatHook = true
            ADDON.eventManager:Add('PLAYER_REGEN_ENABLED', ADDON)
        end
        return
    end

    BankFrame.BankPanel:Hide()
end

function ADDON:PLAYER_REGEN_ENABLED()
    if self._djbagsNeedsHideBankPanel then
        self._djbagsNeedsHideBankPanel = nil
        DJBagsSafeHideBankPanel()
    end

    if not self._djbagsNeedsHideBankPanel and self.eventManager and self._djbagsHideBankPanelCombatHook then
        self._djbagsHideBankPanelCombatHook = nil
        self.eventManager:Remove('PLAYER_REGEN_ENABLED', self)
    end
end

function DJBagsHideBlizzardBank()
    if not BankFrame then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        return
    end

    -- Keep Blizzard's bank frame functional (events/scripts) to avoid taint and
    -- protected-action blocks after leaving the bank. Just make it invisible and non-interactive.
    BankFrame:SetAlpha(0)
    BankFrame:EnableMouse(false)
end

local function DJBagsRestoreBlizzardBank()
    if not BankFrame then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        return
    end

    BankFrame:SetAlpha(1)
    BankFrame:EnableMouse(true)
end

local function DJBagsEnsureBankFrameHooks()
    if not BankFrame or BankFrame._djbagsHooked then
        return
    end
    BankFrame._djbagsHooked = true

    if BankFrame.HookScript then
        BankFrame:HookScript('OnShow', function()
            DJBagsHideBlizzardBank()
        end)

        BankFrame:HookScript('OnHide', function()
            DJBagsRestoreBlizzardBank()
            DJBagsSafeHideBankPanel()
        end)
    end
end

function DJBagsRegisterBankBagContainer(self, bags, bankType)
    DJBagsRegisterBaseBagContainer(self, bags)

    -- Save the original BAG_UPDATE implementation so we can gate updates
    -- while the other bank type is active.
    self.baseBAG_UPDATE = self.BAG_UPDATE

    for k, v in pairs(bank) do
        self[k] = v
    end

    -- Track which bank type this container represents and if it's active.
    local characterType = (Enum and Enum.BankType and Enum.BankType.Character) or 0
    self.bankType = bankType or characterType
    self.isActive = self.bankType == characterType

    ADDON.eventManager:Add('BANKFRAME_OPENED', self)
    ADDON.eventManager:Add('BANKFRAME_CLOSED', self)
    ADDON.eventManager:Add('PLAYERBANKSLOTS_CHANGED', self)
    ADDON.eventManager:Add('PLAYERBANKBAGSLOTS_CHANGED', self)
    -- Warband bank tabs use separate events when purchased. Ensure we listen
    -- for those so newly unlocked tabs become visible without a reload.
    ADDON.eventManager:Add('ACCOUNT_BANK_TAB_PURCHASED', self)
    ADDON.eventManager:Add('ACCOUNT_BANK_SLOTS_CHANGED', self)
    ADDON.eventManager:Add('PLAYERACCOUNTBANKSLOTS_CHANGED', self)

    -- IMPORTANT: Do NOT unregister BankFrame events or replace its scripts.
    -- Just keep it invisible so Blizzard can cleanly manage bank state.
    DJBagsEnsureBankFrameHooks()
    DJBagsHideBlizzardBank()

    -- Keep the warband and character bank frames aligned when moved directly.
    self:HookScript('OnDragStop', function(frame)
        if DJBagsSyncBankFramePositions then
            DJBagsSyncBankFramePositions(frame)
        end
    end)

    -- Attach the vertical tab strip (All + per-tab filter + purchase tab)
    -- on the right-hand side of the active bank frame.
    if ADDON.AttachBankTabStrip then
        ADDON:AttachBankTabStrip(self, self.bankType)
    end
end

function bank:BANKFRAME_OPENED()
    local bankType = BankFrame and BankFrame.GetActiveBankType and BankFrame:GetActiveBankType()
    if not bankType then
        bankType = (Enum and Enum.BankType and Enum.BankType.Character) or 0
    end

    self.isActive = bankType == self.bankType
    if self.isActive then
        self:Show()
    else
        self:Hide()
    end

    -- Keep Blizzard's bank UI invisible even if it shows briefly.
    DJBagsHideBlizzardBank()
end

function bank:BANKFRAME_CLOSED()
    self:Hide()
    DJBagsSafeHideBankPanel()
end

function bank:BAG_UPDATE(bag)
    if self.isActive then
        self:baseBAG_UPDATE(bag)
    end
end

function bank:PLAYERBANKSLOTS_CHANGED()
    if self.isActive then
        self:Refresh()
        if self._djbagsTabStrip and self._djbagsTabStrip.Refresh then
            self._djbagsTabStrip:Refresh()
        end
    end
end

function bank:PLAYERBANKBAGSLOTS_CHANGED()
    if self.isActive then
        self:Refresh()
        if self._djbagsTabStrip and self._djbagsTabStrip.Refresh then
            self._djbagsTabStrip:Refresh()
        end
    end
end

function bank:ACCOUNT_BANK_TAB_PURCHASED()
    if self.isActive then
        self:Refresh()
        if self._djbagsTabStrip and self._djbagsTabStrip.Refresh then
            self._djbagsTabStrip:Refresh()
        end
    end
end

function bank:ACCOUNT_BANK_SLOTS_CHANGED()
    if self.isActive then
        self:Refresh()
        if self._djbagsTabStrip and self._djbagsTabStrip.Refresh then
            self._djbagsTabStrip:Refresh()
        end
    end
end

bank.PLAYERACCOUNTBANKSLOTS_CHANGED = bank.ACCOUNT_BANK_SLOTS_CHANGED

-- Override the bag hover event to prevent highlighting items when hovering
-- over bank tabs. Tab selection already filters the visible items.
function bank:DJBAGS_BAG_HOVER()
end
