local ADDON_NAME, ADDON = ...

-- Compatibility for new reagent bag container constant
REAGENTBAG_CONTAINER = REAGENTBAG_CONTAINER
    or (Enum.BagIndex and Enum.BagIndex.ReagentBag)
    or 5

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
