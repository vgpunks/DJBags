local NAME, ADDON = ...

function ADDON:PrintTable(tbl, lvl)
    local prefix = ''
    lvl = lvl or 0
    for _ = 1, lvl do
        prefix = prefix .. '   '
    end
    for k, v in pairs(tbl) do
        print(prefix, k, v)
        if (type(v) == 'table') then
            ADDON:PrintTable(v, lvl + 1)
        end
    end
end

ADDON.settings = {}
local settings = ADDON.settings

function settings:Init()
    self.realm = GetRealmName()
    self.player = UnitName("player")

    DJBags_DB = {}
    DJBags_DB[self.realm] = DJBags_DB[self.realm] or {}
    DJBags_DB[self.realm][self.player] = DJBags_DB[self.realm][self.player] or {}
    DJBags_DB[self.realm][self.player].userDefined = DJBags_DB[self.realm][self.player].userDefined or {}

    DJBags_DB.global = DJBags_DB.global or {}
    DJBags_DB.global.userDefined = DJBags_DB.global.userDefined or {}

    self.default = {
        [DJBags_TYPE_CONTAINER] = {
            [DJBags_SETTING_BACKGROUND_COLOR] = {0, 0, 0, 0.6},
            [DJBags_SETTING_BORDER_COLOR] = {0.3, 0.3, 0.3, 1},
            [DJBags_SETTING_PADDING] = 5,
            [DJBags_SETTING_SPACING] = 5,
            [DJBags_SETTING_SCALE] = 1,
            [DJBags_SETTING_FORMATTER] = 'massonry',
            [DJBags_SETTING_FORMATTER_VERT] = false,
            [DJBags_SETTING_FORMATTER_MAX_ITEMS] = 12,
            [DJBags_SETTING_FORMATTER_MAX_HEIGHT] = 0.5,
            [DJBags_SETTING_TRUNCATE_SUB_CLASS] = true,
        },
        [DJBags_TYPE_ITEM_CONTAINER] = {
            [DJBags_SETTING_BACKGROUND_COLOR] = {0, 0, 0, 0.6},
            [DJBags_SETTING_BORDER_COLOR] = {0.3, 0.3, 0.3, 1},
            [DJBags_SETTING_TEXT_COLOR] = {1, 1, 1, 1},
            [DJBags_SETTING_TEXT_SIZE] = 12,
            [DJBags_SETTING_PADDING] = 3,
            [DJBags_SETTING_SPACING] = 3,
        },
    }
    self.defaultSubclass = {
        [LE_ITEM_CLASS_ARMOR] = false,
        [LE_ITEM_CLASS_CONSUMABLE] = true,
        [LE_ITEM_CLASS_GEM] = false,
        [LE_ITEM_CLASS_GLYPH] = false,
        [LE_ITEM_CLASS_ITEM_ENHANCEMENT] = false,
        [LE_ITEM_CLASS_MISCELLANEOUS] = true,
        [LE_ITEM_CLASS_RECIPE] = false,
        [LE_ITEM_CLASS_TRADEGOODS] = true,
        [LE_ITEM_CLASS_WEAPON] = false,
    }

    self:Update()
end

function settings:Update(force)
    self:UpdateBag(DJBagsBagContainer, ADDON.cache.bagContainers, force)
end

function settings:UpdateBag(bag, list, force)
    bag:UpdateFromSettings()
    for _, container in pairs(list) do
        container:UpdateFromSettings()
    end

    if bag:IsVisible() and force then
        bag:Arrange(true)
    end
end

function settings:GetSettings(type)
    local settings = DJBags_DB[self.realm][self.player][type] or {}
    self:MigrateSettings(settings, DJBags_DB.global[type] or {})
    self:MigrateSettings(settings, self.default[type]or {})

    return settings
end

function settings:SetSettings(type, setting, out, force)
    DJBags_DB[self.realm][self.player][type] = DJBags_DB[self.realm][self.player][type] or {}
    DJBags_DB[self.realm][self.player][type][setting] = out

    self:Update(force)
end

function settings:GetUserDefinedList()
    return DJBags_DB[self.realm][self.player].userDefined
end

function settings:GetGlobalUserDefinedList()
    return DJBags_DB.global.userDefined
end

function settings:GetSubClassList()
    return DJBags_DB[self.realm][self.player].subClass or self.defaultSubclass
end

function settings:MigrateSettings(table, default)
    for k, v in pairs(default) do
        if table[k] ~= nil then
            if type(v) ~= type(table[k]) then
                table[k] = v
            elseif type(v) == 'table' then
                self:MigrateSettings(table[k], v)
            end
        else
            table[k] = v
        end
    end
end