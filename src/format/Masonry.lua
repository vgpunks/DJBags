local ADDON_NAME, ADDON = ...

ADDON.formatter = ADDON.formatter or {}

-- Sort categories by the number of columns they occupy so wider groups
-- are placed first.  Empty slots are always displayed last.  This keeps
-- the layout compact by prioritising categories that take more space
-- instead of using alphabetical order.
local typeSorter = function(A, B)
    if A == EMPTY then
        return false
    elseif B == EMPTY then
        return true
    else
        local aSize = (ADDON.typeSizes and ADDON.typeSizes[A]) or 0
        local bSize = (ADDON.typeSizes and ADDON.typeSizes[B]) or 0
        if aSize == bSize then
            return A < B
        end
        return aSize > bSize
    end
end

local itemSorter = function(A, B)
    if A.type == B.type then
        if A.quality == B.quality then
            if A.ilevel == B.ilevel then
                if A.name == B.name then
                    return (A.count or 1) > (B.count or 1)
                end
                return (A.name or '') < (B.name or '')
            end
            return (A.ilevel or 1) > (B.ilevel or 1)
        end
        return (A.quality or 0) > (B.quality or 0)
    end
    return typeSorter(A.type, B.type)
end

ADDON.formatter[ADDON.formats.MASONRY] = function(bag)
    local padding = bag.settings.padding
    local containerSpacing = bag.settings.containerSpacing
    local itemSpacing = bag.settings.itemSpacing
    local maxCols = bag.settings.maxColumns > 0 and bag.settings.maxColumns or 1

    -- Determine how much horizontal space each category will require so we
    -- can order them by size rather than name for better packing.
    local typeSizes = {}
    for _, item in pairs(bag.items) do
        typeSizes[item.type] = (typeSizes[item.type] or 0) + 1
    end
    for t, count in pairs(typeSizes) do
        typeSizes[t] = t == EMPTY and 1 or math.min(count, maxCols)
    end
    ADDON.typeSizes = typeSizes

    table.sort(bag.items, itemSorter)
    for _, container in pairs(bag.titleContainers) do
        container:Hide()
    end

    -- Format the containers
    local containers = {}
    local cnt, x, y, currentType, container, prevItem
    for _, item in pairs(bag.items) do
        item:Hide()
        if item.type ~= currentType then
            currentType = item.type
            container = bag.titleContainers[currentType]
            cnt = 0
            x = padding
            y = padding + padding + container.name:GetHeight()
            tinsert(containers, container)
        end

        if not (item.type == EMPTY) or cnt == 0 then
            item:ClearAllPoints()
            item:SetPoint('TOPLEFT', container, 'TOPLEFT', x, -y)
            item:Show()
            if item.type == EMPTY then
                item.count = 1
            end
            prevItem = item

            x = x + itemSpacing + item:GetWidth()
            cnt = cnt + 1
            if cnt % maxCols == 0 then
                x = padding
                y = y + itemSpacing + item:GetHeight()
            end
        else
            prevItem:IncrementCount()
        end

        local cols = item.type == EMPTY and 1 or math.min(cnt, maxCols)
        local rows = item.type == EMPTY and 1 or math.ceil(cnt / maxCols)
        local width = padding * 2 + cols * item:GetWidth() + (cols - 1) * itemSpacing
        local height = padding * 3 + container.name:GetHeight() + rows * item:GetHeight() + (rows - 1) * itemSpacing
        container:SetSize(width, height)
        container.cols = cols
    end

    x = padding
    y = padding
    cnt = 0
    local prevHeight = 0
    local mW = 0
    local mH = 0
    for _, container in pairs(containers) do
        if cnt + container.cols > maxCols then
            y = y + prevHeight + containerSpacing
            x = padding
            mH = math.max(mH, y + padding - containerSpacing)
            cnt = 0
        end

        container:ClearAllPoints()
        container:SetPoint('TOPLEFT', x, -y)
        container:Show()

        x = x + container:GetWidth() + containerSpacing
        mW = math.max(mW, x + padding - containerSpacing)
        prevHeight = container:GetHeight()
        cnt = cnt + container.cols
    end
    bag:SetSize(mW, mH + prevHeight + padding + 4)
end
