local ADDON_NAME, ADDON = ...

-- Helper: populate the tooltip for a given bag/slot, compatible with Midnight+
-- SetBagItem was removed; use SetHyperlink with the item link from C_Container.
local function SetTooltipForSlot(self, bag, slot)
    if bag < 0 then
        -- Bank slot identified by inventory slot ID
        self:SetInventoryItem("player", BankButtonIDToInvSlotID(slot))
    else
        -- Prefer the modern C_Container path (Dragonflight / Midnight)
        if C_Container and C_Container.GetContainerItemInfo then
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local link = info and info.hyperlink
            if link then
                self:SetHyperlink(link)
                return
            end
        end
        -- Fallback: legacy SetBagItem (older clients)
        if self.SetBagItem then
            self:SetBagItem(bag, slot)
        end
    end
end

function DJBagsTooltip:GetItemLevel(bag, slot)
    self:ClearLines()
    self:SetOwner(UIParent, "ANCHOR_NONE")
    SetTooltipForSlot(self, bag, slot)

    for i = 2, self:NumLines() do
        local text = _G[self:GetName() .. "TextLeft" .. i]:GetText()
        local UPGRADE_LEVEL = gsub(ITEM_LEVEL, " %d", "")

        if text and text:find(UPGRADE_LEVEL) then
            local itemLevel = string.match(text, "%d+")

            if itemLevel then
                return tonumber(itemLevel)
            end
        end
    end
end

function DJBagsTooltip:IsItemBOE(bag, slot)
    self:ClearLines()
    self:SetOwner(UIParent, "ANCHOR_NONE")
    SetTooltipForSlot(self, bag, slot)

    for i = 2, self:NumLines() do
        local text = _G[self:GetName() .. "TextLeft" .. i]:GetText()

        if text and text:find(ITEM_BIND_ON_EQUIP) then
            return true
        end
    end

    return false
end

function DJBagsTooltip:IsItemBOA(bag, slot)
    self:ClearLines()
    self:SetOwner(UIParent, "ANCHOR_NONE")
    SetTooltipForSlot(self, bag, slot)

    for i = 2, self:NumLines() do
        local text = _G[self:GetName() .. "TextLeft" .. i]:GetText()

        if text and (text:find(ITEM_ACCOUNTBOUND) or text:find(ITEM_BIND_TO_ACCOUNT)) then
            return true
        end
    end

    return false
end

-- Extra for Bind on Battlenet account
function DJBagsTooltip:IsItemBOBA(bag, slot)
    self:ClearLines()
    self:SetOwner(UIParent, "ANCHOR_NONE")
    SetTooltipForSlot(self, bag, slot)

    for i = 2, self:NumLines() do
        local text = _G[self:GetName() .. "TextLeft" .. i]:GetText()

        if text and (text:find(ITEM_BNETACCOUNTBOUND) or text:find(ITEM_BIND_TO_BNETACCOUNT)) then
            return true
        end
    end
    return false
end
