local ADDON_NAME, ADDON = ...

local guild = {}
guild.__index = guild

local MAX_SLOTS = MAX_GUILDBANK_SLOTS_PER_TAB or 98

local function GetTabList()
    local tabs = GetNumGuildBankTabs() or (MAX_GUILDBANK_TABS or 0)
    local list = {}
    for i = 1, tabs do
        table.insert(list, i)
    end
    if #list == 0 then
        list[1] = 1
    end
    return list
end

local function CreateContainers(self)
    for _, tab in ipairs(self.bags) do
        if not self.containers[tab] then
            self.containers[tab] = CreateFrame("Frame", "DJBagsGuildBankContainer_" .. tab, self)
            self.containers[tab]:SetAllPoints()
            self.containers[tab]:SetID(50 + tab)
            self.containers[tab].items = {}
        end
    end
end

function DJBagsRegisterGuildBankBagContainer(self, tabs)
    tabs = tabs or GetTabList()
    DJBagsRegisterBaseBagContainer(self, tabs)

    for k, v in pairs(guild) do
        self[k] = v
    end

    CreateContainers(self)

    ADDON.eventManager:Add('GUILDBANKFRAME_OPENED', self)
    ADDON.eventManager:Add('GUILDBANKFRAME_CLOSED', self)
    ADDON.eventManager:Add('GUILDBANKBAGSLOTS_CHANGED', self)
    ADDON.eventManager:Add('GUILDBANK_UPDATE_TABS', self)

    if GuildBankFrame_LoadUI then
        GuildBankFrame_LoadUI()
    end
    if GuildBankFrame then
        GuildBankFrame:UnregisterAllEvents()
        GuildBankFrame:SetScript('OnShow', nil)
    end
end

local function CreateTitleContainer(self, item)
    if not self.titleContainers[item.type] then
        self.titleContainers[item.type] = CreateFrame('Frame', string.format('DJBagsTitleContainer_%s_%s', self:GetName(), item.type), self, 'DJBagsTitleContainerTemplate')
        self.titleContainers[item.type].name:SetText(item.type)
        self.titleContainers[item.type].name.text = item.type
    end
end

local function GetAllItems(self, tabs)
    local update = false
    for _, tab in ipairs(tabs) do
        local container = self.containers[tab]
        for slot = 1, MAX_SLOTS do
            if not container.items[slot] then
                container.items[slot] = ADDON:NewItem(container, slot, 'GuildBankItemButtonTemplate', tab)
                table.insert(self.items, container.items[slot])
            end
            local item = container.items[slot]
            local idBefore = item.id
            item:Update()
            item.type = ADDON.categoryManager:GetTitle(item, self.settings.filters)
            CreateTitleContainer(self, item)
            if idBefore ~= item.id and item.id ~= nil then
                update = true
            end
        end
    end
    if update then
        self:Format()
    end
    return update
end

function guild:Refresh()
    if not GetAllItems(self, self.bags) then
        self:Format()
    end
end

function guild:GUILDBANKFRAME_OPENED()
    if not QueryGuildBankTab and GuildBankFrame_LoadUI then
        GuildBankFrame_LoadUI()
    end

    for i = 1, GetNumGuildBankTabs() do
        QueryGuildBankTab(i)
    end
    self:Show()
end

function guild:GUILDBANKFRAME_CLOSED()
    self:Hide()
end

function guild:GUILDBANKBAGSLOTS_CHANGED()
    self:Refresh()
end

function guild:GUILDBANK_UPDATE_TABS()
    self.bags = GetTabList()
    self.bagsByKey = {}
    for _, tab in ipairs(self.bags) do
        self.bagsByKey[tab] = true
    end
    CreateContainers(self)
    self:Refresh()
end
