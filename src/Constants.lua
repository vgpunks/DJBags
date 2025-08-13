local ADDON_NAME, ADDON = ...

if not BankButtonIDToInvSlotID then
        local bagOffset = (NUM_BAG_SLOTS or 0) + (NUM_REAGENTBAG_SLOTS or 0)
        if C_Container and C_Container.ContainerIDToInventoryID then
                function BankButtonIDToInvSlotID(buttonID)
                        return C_Container.ContainerIDToInventoryID(bagOffset + buttonID)
                end
        elseif ContainerIDToInventoryID then
                function BankButtonIDToInvSlotID(buttonID)
                        return ContainerIDToInventoryID(bagOffset + buttonID)
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
