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
    elseif oldToggle then
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

local oldOpen = OpenBag
OpenBag = function(id)
    if id < 5 and id > -1 then
        DJBagsBag:Show()
    elseif oldOpen then
        oldOpen(id)
    end
end

local oldClose = CloseBag
CloseBag = function(id)
    if id < 5 and id > -1 then
        DJBagsBag:Hide()
    elseif oldClose then
        oldClose(id)
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

SLASH_DJBAGS1, SLASH_DJBAGS2, SLASH_DJBAGS3, SLASH_DJBAGS4 = '/djb', '/dj', '/djbags', '/db';
function SlashCmdList.DJBAGS(msg, editbox)
    DJBagsBag:Show()
end

SLASH_RL1 = '/rl';
function SlashCmdList.RL(msg, editbox)
    ReloadUI()
end

-- -----------------------------------------------------------------------
-- Loot Toast / Loot Notification click → open DJBags bag
--
-- In Midnight the loot alert system hooks use several paths depending on
-- client version:
--   1. ContainerFrame_OpenBag(bagID)  – called by older loot notification clicks
--   2. EventRegistry "LootToastFrame.OpenBag"  – Midnight AlertSystem path
--   3. LootAlertSystem / GenerateLootToastLink clicks may call OpenBackpack()
--
-- Paths 1 and 3 are already covered by our OpenBag / OpenBackpack overrides.
-- We hook path 2 via EventRegistry so any toast click that fires that event
-- also opens DJBags.
-- -----------------------------------------------------------------------
local function DJBagsSetupLootToastHooks()
    -- Hook EventRegistry loot open event (Midnight AlertSystem)
    if EventRegistry then
        EventRegistry:RegisterCallback("LootToastFrame.OpenBag", function()
            DJBagsBag:Show()
        end, "DJBagsLootToast")
    end

    -- Hook ContainerFrame_OpenBag for the bag-bar loot toast click path.
    -- In older clients this global is called directly when clicking a loot
    -- toast item to open the container it landed in.
    if ContainerFrame_OpenBag then
        local _origContainerOpenBag = ContainerFrame_OpenBag
        ContainerFrame_OpenBag = function(bagID, ...)
            if bagID and bagID >= 0 and bagID <= 4 then
                DJBagsBag:Show()
            else
                _origContainerOpenBag(bagID, ...)
            end
        end
    end

    -- Midnight: LootAlertSystem uses a click handler that may set
    -- ToggleBackpack or call C_Container.OpenBag. Secure-wrap OpenBackpack
    -- is already done above. Additionally hook the LootFrame click callback
    -- if present (harmless if not).
    if LootAlertSystem and LootAlertSystem.OnAlertFrameStackButtonClick then
        hooksecurefunc(LootAlertSystem, "OnAlertFrameStackButtonClick", function()
            DJBagsBag:Show()
        end)
    end
end

-- Run after PLAYER_LOGIN so all frames and registries are initialised.
local lootHookFrame = CreateFrame("Frame")
lootHookFrame:RegisterEvent("PLAYER_LOGIN")
lootHookFrame:SetScript("OnEvent", function(self)
    DJBagsSetupLootToastHooks()
    self:UnregisterAllEvents()
end)
