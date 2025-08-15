local ADDON_NAME, ADDON = ...

if not BankButtonIDToInvSlotID then
        local function GetContainerID(buttonID, bankType)
                bankType = bankType or (Enum.BankType and Enum.BankType.Character)
                if bankType == (Enum.BankType and Enum.BankType.Account) and Enum.BagIndex.AccountBankTab_1 then
                        return Enum.BagIndex.AccountBankTab_1 + buttonID - 1
                elseif Enum.BagIndex.CharacterBankTab_1 then
                        return Enum.BagIndex.CharacterBankTab_1 + buttonID - 1
                else
                        return 4 + buttonID
                end
        end

        if C_Container and C_Container.ContainerIDToInventoryID then
                function BankButtonIDToInvSlotID(buttonID, bankType)
                        return C_Container.ContainerIDToInventoryID(GetContainerID(buttonID, bankType))
                end
        elseif ContainerIDToInventoryID then
                function BankButtonIDToInvSlotID(buttonID, bankType)
                        return ContainerIDToInventoryID(GetContainerID(buttonID, bankType))
                end
        end
end

-- Formatter types
ADDON.formats = {
	MASONRY = 0,
}

-- Locale
local locale = {
	enUS = {
		ALL_CHARACTERS = 'All Characters?',
		COLUMNS = 'Columns: %d',
		SCALE = 'Scale: %.2f',
		CATEGORY_SETTINGS = "Category Settings",
		CATEGORY_SETTINGS_FOR = "%s Category Settings"
	}
}

ADDON.locale = locale[GetLocale()] or locale['enUS']

for k, v in pairs(ADDON.locale) do
	_G["DJBAGS_" .. k] = v
end
