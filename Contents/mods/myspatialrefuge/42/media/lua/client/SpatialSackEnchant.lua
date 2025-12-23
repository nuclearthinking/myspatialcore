local SpatialSackEnchant = {}

-- Enchantment tier configuration
local ENCHANT_TIERS = {
    [0] = {cores = 5, capacity = 10},  -- Base (from craft)
    [1] = {cores = 3, capacity = 20},  -- Tier 1 upgrade
    [2] = {cores = 5, capacity = 30},  -- Tier 2 upgrade
    [3] = {cores = 8, capacity = 40},  -- Tier 3 upgrade
    [4] = {cores = 10, capacity = 50}, -- Tier 4 MAX
}

-- Count cores in inventory
local function countCores(inventory)
    local count = 0
    local items = inventory:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item:getType() == "MagicalCore" then
            count = count + 1
        end
    end
    return count
end

-- Remove cores from inventory
local function consumeCores(inventory, amount)
    local removed = 0
    local items = inventory:getItems()
    
    for i = items:size() - 1, 0, -1 do
        if removed >= amount then break end
        
        local item = items:get(i)
        if item:getType() == "MagicalCore" then
            inventory:Remove(item)
            removed = removed + 1
        end
    end
    
    return removed == amount
end

-- Perform enchantment
local function doEnchant(player, sack)
    local modData = sack:getModData()
    local currentTier = modData.enchantLevel or 0
    local nextTier = currentTier + 1
    
    local tierInfo = ENCHANT_TIERS[nextTier]
    if not tierInfo then
        HaloTextHelper.addBadText(player, "Maximum enhancement reached!")
        return
    end
    
    local inventory = player:getInventory()
    local coresNeeded = tierInfo.cores
    local coresAvailable = countCores(inventory)
    
    if coresAvailable < coresNeeded then
        HaloTextHelper.addBadText(player, "Need " .. coresNeeded .. " cores (have " .. coresAvailable .. ")")
        return
    end
    
    -- Consume cores
    if consumeCores(inventory, coresNeeded) then
        -- Upgrade tier
        modData.enchantLevel = nextTier
        
        -- Increase capacity
        local container = sack:getItemContainer()
        if container then
            container:setCapacity(tierInfo.capacity)
        end
        
        -- Show success message with green text
        HaloTextHelper.addGoodText(player, "Spatial Sack Enhanced!")
        HaloTextHelper.addTextWithArrow(player, "Capacity " .. tierInfo.capacity, true, HaloTextHelper.getColorGreen())
        
        if getDebug() then
            print("[SpatialSack] Enhanced to tier " .. nextTier .. ", capacity: " .. tierInfo.capacity)
        end
    else
        HaloTextHelper.addBadText(player, "Enhancement failed!")
    end
end

-- Context menu creation
local function createEnchantMenu(playerNum, context, items)
    -- Get actual player object
    local player = getSpecificPlayer(playerNum)
    if not player then return end
    
    local sack = nil
    
    -- Find spatial sack in selection
    for i = 1, #items do
        local item = items[i]
        if not instanceof(item, "InventoryItem") then
            item = item.items[1]
        end
        
        if item and item:getType() == "SpatialSack" then
            sack = item
            break
        end
    end
    
    if not sack then return end
    
    local modData = sack:getModData()
    local currentTier = modData.enchantLevel or 0
    local nextTier = currentTier + 1
    
    if currentTier >= 4 then
        context:addOption("Maximum Enhancement Reached", nil, nil)
        return
    end
    
    local tierInfo = ENCHANT_TIERS[nextTier]
    if tierInfo then
        local inventory = player:getInventory()
        local coresAvailable = countCores(inventory)
        local coresNeeded = tierInfo.cores
        
        local menuText = "Enhance Spatial Sack"
        
        local option = context:addOption(menuText, player, doEnchant, sack)
        
        -- Disable if not enough cores
        if coresAvailable < coresNeeded then
            option.notAvailable = true
            local tooltip = ISInventoryPaneContextMenu.addToolTip()
            tooltip:setName(menuText)
            tooltip.description = string.format(
                "Strange Zombie Cores: %d/%d\nNew capacity: %d units\n\nNOT ENOUGH CORES",
                coresAvailable,
                coresNeeded,
                tierInfo.capacity
            )
            option.toolTip = tooltip
        else
            local tooltip = ISInventoryPaneContextMenu.addToolTip()
            tooltip:setName(menuText)
            tooltip.description = string.format(
                "Strange Zombie Cores: %d/%d\nNew capacity: %d units\n\nItems inside remain safe",
                coresAvailable,
                coresNeeded,
                tierInfo.capacity
            )
            option.toolTip = tooltip
        end
    end
end

-- Register context menu
Events.OnFillInventoryObjectContextMenu.Add(createEnchantMenu)

return SpatialSackEnchant
