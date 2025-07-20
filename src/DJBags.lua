local ADDON_NAME, ADDON = ...
local eventManager = ADDON.eventManager

local core = {}

local function migrate()
    -- V 0.76 or less must reset settings
    if (DJBags_DB == nil or not DJBags_DB.VERSION or DJBags_DB.VERSION < 0.76) then
        DJBags_DB = {
            VERSION = 0.8,
            categories = {
            },
            newItems = {}
        }
    end
    if (DJBags_DB_Char == nil or not DJBags_DB_Char.VERSION or DJBags_DB_Char.VERSION < 0.76) then
        DJBags_DB_Char = {
            VERSION = 0.8,
            categories = {
            },
            newItems = {}
        }
    end
end

function core:ADDON_LOADED(name)
	if ADDON_NAME ~= name then return end

    migrate()

	eventManager:Remove('ADDON_LOADED', core)
end

eventManager:Add('ADDON_LOADED', core)

ToggleAllBags = function()
    if DJBagsBag:IsVisible() then
        DJBagsBag:Hide()
    else
        DJBagsBag:Show()
    end
end

local oldToggle = ToggleBag
ToggleBag = function(id)
    if id < 5 and id > -1 then
        if DJBagsBag:IsVisible() then
            DJBagsBag:Hide()
        else
            DJBagsBag:Show()
        end
    else
        oldToggle(id)
    end
end

ToggleBackpack = function()
    if DJBagsBag:IsVisible() then
        DJBagsBag:Hide()
    else
        DJBagsBag:Show()
    end
end

OpenAllBags = function()
    DJBagsBag:Show()
end

OpenBackpack = function()
    DJBagsBag:Show()
end

CloseAllBags = function()
    DJBagsBag:Hide()
end

CloseBackpack = function()
    DJBagsBag:Hide()
end

local oldOpenBag = OpenBag
OpenBag = function(id)
    if id < 5 and id > -1 then
        DJBagsBag:Show()
    elseif oldOpenBag then
        oldOpenBag(id)
    end
end

-- Bank API overrides
local oldOpenBankFrame = OpenBankFrame
OpenBankFrame = function(...)
    if oldOpenBankFrame then
        oldOpenBankFrame(...)
    end
    if DJBagsBankBar and DJBagsBankBar.BANKFRAME_OPENED then
        DJBagsBankBar:BANKFRAME_OPENED()
    end
end

local oldCloseBankFrame = CloseBankFrame
CloseBankFrame = function(...)
    if DJBagsBankBar and DJBagsBankBar.BANKFRAME_CLOSED then
        DJBagsBankBar:BANKFRAME_CLOSED()
    end
    if oldCloseBankFrame then
        oldCloseBankFrame(...)
    end
end

-- Guild bank API overrides
local function HookGuildBankFrame()
    if not GuildBankFrame or GuildBankFrame.DJBagsHooked then return end

    GuildBankFrame.DJBagsHooked = true

    GuildBankFrame:HookScript('OnShow', function()
        if DJBagsGuildBank and DJBagsGuildBank.GUILDBANKFRAME_OPENED then
            DJBagsGuildBank:GUILDBANKFRAME_OPENED()
        end
        GuildBankFrame:Hide()
    end)

    GuildBankFrame:HookScript('OnHide', function()
        if DJBagsGuildBank and DJBagsGuildBank.GUILDBANKFRAME_CLOSED then
            DJBagsGuildBank:GUILDBANKFRAME_CLOSED()
        end
    end)
end

if GuildBankFrame then
    HookGuildBankFrame()
else
    local loader = {}
    function loader:ADDON_LOADED(name)
        if name == 'Blizzard_GuildBankUI' then
            HookGuildBankFrame()
            eventManager:Remove('ADDON_LOADED', loader)
        end
    end

    eventManager:Add('ADDON_LOADED', loader)
end

SLASH_DJBAGS1, SLASH_DJBAGS2, SLASH_DJBAGS3, SLASH_DJBAGS4 = '/djb', '/dj', '/djbags', '/db';
function SlashCmdList.DJBAGS(msg, editbox)
    DJBagsBag:Show()
end

SLASH_RL1 = '/rl';
function SlashCmdList.RL(msg, editbox)
    ReloadUI()
end
