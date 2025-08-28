local NAME, ADDON = ...

-- Lazily create a copy of the Blizzard bank tab settings menu so it can be
-- anchored and shown independently of the Blizzard bank frame.  Some client
-- builds do not fully initialize the Blizzard menu when it's re-parented, so
-- we create our own instance instead.
function ADDON:GetBankTabSettingsMenu()
    if not self.bankTabSettingsMenu then
        if BankPanelTabSettingsMenuMixin then
            self.bankTabSettingsMenu = CreateFrame("Frame", nil, UIParent, "BankPanelTabSettingsMenuTemplate")
            -- Frames created with CreateFrame do not automatically run their
            -- OnLoad handler.  The Blizzard menu relies on its OnLoad to
            -- register for events and become interactive, so manually invoke it
            -- after creation.
            if self.bankTabSettingsMenu.OnLoad then
                self.bankTabSettingsMenu:OnLoad()
            end
            if BankFrame and BankFrame.BankPanel then
                if self.bankTabSettingsMenu.SetBankPanel then
                    self.bankTabSettingsMenu:SetBankPanel(BankFrame.BankPanel)
                else
                    self.bankTabSettingsMenu.BankPanel = BankFrame.BankPanel
                end
            end
        else
            -- Fallback to a basic frame if the template is unavailable; this
            -- preserves backward compatibility even though the menu will have
            -- no functionality.
            self.bankTabSettingsMenu = CreateFrame("Frame", nil, UIParent)
        end
    end
    if BankFrame and BankFrame.BankPanel then
        if self.bankTabSettingsMenu.SetBankPanel then
            self.bankTabSettingsMenu:SetBankPanel(BankFrame.BankPanel)
        else
            self.bankTabSettingsMenu.BankPanel = BankFrame.BankPanel
        end
    end
    return self.bankTabSettingsMenu
end

