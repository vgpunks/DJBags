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

-- Bank API hooks
ADDON.closingBankFrame = false

hooksecurefunc('OpenBankFrame', function(...)
    if BankFrame and BankFrame:IsShown() then
        BankFrame:Hide()
    end
    if DJBagsBankBar and DJBagsBankBar.BANKFRAME_OPENED then
        DJBagsBankBar:BANKFRAME_OPENED()
    end
end)

hooksecurefunc('CloseBankFrame', function(...)
    if DJBagsBankBar and DJBagsBankBar.BANKFRAME_CLOSED then
        DJBagsBankBar:BANKFRAME_CLOSED()
    end
end)

-- When the bank is closed by the game (e.g. walking away from the banker),
-- ensure the default API runs so the bank can reopen without reloading.
local bankEvents = CreateFrame('Frame')
bankEvents:RegisterEvent('BANKFRAME_CLOSED')
bankEvents:RegisterEvent('PLAYER_INTERACTION_MANAGER_FRAME_SHOW')
bankEvents:RegisterEvent('PLAYER_INTERACTION_MANAGER_FRAME_HIDE')

local bankerInteractions = {
    Enum.PlayerInteractionType and Enum.PlayerInteractionType.Banker,
    Enum.PlayerInteractionType and Enum.PlayerInteractionType.AccountBanker,
    Enum.PlayerInteractionType and Enum.PlayerInteractionType.WarbandBanker,
}

local function IsBankerInteraction(interactionType)
    for _, v in ipairs(bankerInteractions) do
        if v and interactionType == v then
            return true
        end
    end
end

bankEvents:SetScript('OnEvent', function(_, event, ...)
    if event == 'PLAYER_INTERACTION_MANAGER_FRAME_SHOW' then
        local interactionType = ...
        if IsBankerInteraction(interactionType) then
            OpenBankFrame()
        end
    elseif event == 'PLAYER_INTERACTION_MANAGER_FRAME_HIDE' then
        local interactionType = ...
        if IsBankerInteraction(interactionType) and not ADDON.closingBankFrame then
            ADDON.closingBankFrame = true
            CloseBankFrame()
            ADDON.closingBankFrame = false
        end
    elseif event == 'BANKFRAME_CLOSED' then
        if not ADDON.closingBankFrame then
            ADDON.closingBankFrame = true
            CloseBankFrame()
            ADDON.closingBankFrame = false
        end
    end
end)

SLASH_DJBAGS1, SLASH_DJBAGS2, SLASH_DJBAGS3, SLASH_DJBAGS4 = '/djb', '/dj', '/djbags', '/db';
function SlashCmdList.DJBAGS(msg, editbox)
    DJBagsBag:Show()
end

SLASH_RL1 = '/rl';
function SlashCmdList.RL(msg, editbox)
    ReloadUI()
end
