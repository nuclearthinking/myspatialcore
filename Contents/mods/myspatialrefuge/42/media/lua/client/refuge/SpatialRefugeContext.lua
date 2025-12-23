-- Spatial Refuge Context Menu
-- Adds right-click menu options for Sacred Relic (exit and upgrade)

-- Assume dependencies are already loaded
SpatialRefuge = SpatialRefuge or {}
SpatialRefugeConfig = SpatialRefugeConfig or {}

-- Count how many cores player has in inventory
function SpatialRefuge.CountCores(player)
    if not player then return 0 end
    
    local inv = player:getInventory()
    if not inv then return 0 end
    
    return inv:getCountType(SpatialRefugeConfig.CORE_ITEM)
end

-- Consume cores from player inventory
-- Returns: true if successful, false otherwise
function SpatialRefuge.ConsumeCores(player, amount)
    if not player then return false end
    
    local inv = player:getInventory()
    if not inv then return false end
    
    local coreCount = SpatialRefuge.CountCores(player)
    if coreCount < amount then
        return false
    end
    
    -- Remove cores
    local removed = 0
    local items = inv:getItems()
    for i = items:size()-1, 0, -1 do
        if removed >= amount then break end
        
        local item = items:get(i)
        if item and item:getFullType() == SpatialRefugeConfig.CORE_ITEM then
            inv:Remove(item)
            removed = removed + 1
        end
    end
    
    if getDebug() then
        print("[SpatialRefuge] Consumed " .. removed .. " cores")
    end
    
    return removed == amount
end

-- Add context menu for Sacred Relic
local function OnFillWorldObjectContextMenu(player, context, worldObjects, test)
    if not context then return end

    local playerObj = player
    if type(player) == "number" then
        playerObj = getSpecificPlayer(player)
    end
    if not playerObj then return end
    
    -- Check if any of the world objects is a Sacred Relic
    local sacredRelic = nil
    for i = 1, #worldObjects do
        local obj = worldObjects[i]
        if obj then
            local md = obj.getModData and obj:getModData()
            if md and md.isSacredRelic then
                sacredRelic = obj
                break
            end
            if obj.getItem then
                local item = obj:getItem()
                local imd = item and item.getModData and item:getModData()
                if imd and imd.isSacredRelic then
                    sacredRelic = obj
                    break
                end
            end
        end
    end
    
    if not sacredRelic then return end
    
    -- Always show exit option (with cast time)
    context:addOption("Exit Refuge", playerObj, SpatialRefuge.BeginExitCast, sacredRelic)
    
    -- Get player's refuge data
    local refugeData = SpatialRefuge.GetRefugeData and SpatialRefuge.GetRefugeData(playerObj)
    if not refugeData then return end
    
    -- Show upgrade option if not at max tier
    if refugeData.tier < SpatialRefugeConfig.MAX_TIER then
        local currentTier = refugeData.tier
        local nextTier = currentTier + 1
        local tierConfig = SpatialRefugeConfig.TIERS[nextTier]
        local coreCost = tierConfig.cores
        local coreCount = SpatialRefuge.CountCores(playerObj)
        
        local optionText = "Upgrade Refuge (Tier " .. currentTier .. " → " .. nextTier .. ")"
        local option = context:addOption(optionText, player, SpatialRefuge.OnUpgradeRefuge)
        
        -- Disable if not enough cores
        if coreCount < coreCost then
            option.notAvailable = true
            local tooltip = ISInventoryPaneContextMenu.addToolTip()
            tooltip:setName("Need " .. coreCost .. " cores (have " .. coreCount .. ")")
            option.toolTip = tooltip
        else
            -- Show info tooltip
            local tooltip = ISInventoryPaneContextMenu.addToolTip()
            tooltip:setName("Costs " .. coreCost .. " cores")
            tooltip:setDescription("New size: " .. tierConfig.displayName)
            option.toolTip = tooltip
        end
    else
        -- At max tier
        local option = context:addOption("Max Tier Reached", player, nil)
        option.notAvailable = true
    end
end

-- Callback for upgrade option (fallback if upgrade module isn't loaded)
if not SpatialRefuge.OnUpgradeRefuge then
    function SpatialRefuge.OnUpgradeRefuge(player)
        local playerObj = player
        if type(player) == "number" then
            playerObj = getSpecificPlayer(player)
        end
        if not playerObj then return end
        
        local refugeData = SpatialRefuge.GetRefugeData and SpatialRefuge.GetRefugeData(playerObj)
        if not refugeData then
            playerObj:Say("Refuge data not found!")
            return
        end
        
        local currentTier = refugeData.tier
        local nextTier = currentTier + 1
        
        if nextTier > SpatialRefugeConfig.MAX_TIER then
            playerObj:Say("Already at max tier!")
            return
        end
        
        local tierConfig = SpatialRefugeConfig.TIERS[nextTier]
        local coreCost = tierConfig.cores
        
        -- Check if player has enough cores
        if SpatialRefuge.CountCores(playerObj) < coreCost then
            playerObj:Say("Not enough cores!")
            return
        end
        
        -- Consume cores
        if not SpatialRefuge.ConsumeCores(playerObj, coreCost) then
            playerObj:Say("Failed to consume cores!")
            return
        end
        
        -- Expand refuge (handled in upgrade mechanics module)
        -- This is a placeholder - will be implemented in upgrade mechanics
        playerObj:Say("Upgrade triggered - see upgrade mechanics module")
    end
end

-- Register context menu hook
Events.OnFillWorldObjectContextMenu.Add(OnFillWorldObjectContextMenu)

if getDebug() then
    print("[SpatialRefuge] Context menu integration initialized")
end

return SpatialRefuge

