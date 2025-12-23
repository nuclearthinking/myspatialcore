-- Spatial Refuge Upgrade Mechanics
-- Handles tier upgrades with core consumption and expansion

-- Assume dependencies are already loaded
SpatialRefuge = SpatialRefuge or {}
SpatialRefugeConfig = SpatialRefugeConfig or {}

-- Ensure core modules are loaded even if file load order changes
if not SpatialRefuge.GetRefugeData then
    require "client/refuge/SpatialRefugeMain"
end
if not SpatialRefuge.ExpandRefuge then
    require "client/refuge/SpatialRefugeGeneration"
end
if not SpatialRefuge.CountCores then
    require "client/refuge/SpatialRefugeContext"
end

-- Perform refuge upgrade
-- Returns: true if successful, false otherwise
function SpatialRefuge.PerformUpgrade(player, refugeData, newTier)
    if not player or not refugeData then return false end
    
    local tierConfig = SpatialRefugeConfig.TIERS[newTier]
    if not tierConfig then
        if getDebug() then
            print("[SpatialRefuge] Invalid tier: " .. tostring(newTier))
        end
        return false
    end
    
    -- Expand the refuge (creates new floor tiles and walls)
    local success = SpatialRefuge.ExpandRefuge(refugeData, newTier)
    
    if not success then
        player:Say("Failed to expand refuge!")
        return false
    end
    
    -- Show success notification
    HaloTextHelper.addText(player, "Spatial Refuge Expanded!")
    HaloTextHelper.addText(player, "Tier " .. refugeData.tier .. " - Size: " .. tierConfig.displayName)
    
    if getDebug() then
        print("[SpatialRefuge] Upgraded refuge to tier " .. newTier)
    end
    
    return true
end

-- Override the upgrade callback from context menu
function SpatialRefuge.OnUpgradeRefuge(player)
    if not player then return end
    
    local refugeData = SpatialRefuge.GetRefugeData(player)
    if not refugeData then
        player:Say("Refuge data not found!")
        return
    end
    
    local currentTier = refugeData.tier
    local nextTier = currentTier + 1
    
    if nextTier > SpatialRefugeConfig.MAX_TIER then
        player:Say("Already at max tier!")
        return
    end
    
    local tierConfig = SpatialRefugeConfig.TIERS[nextTier]
    local coreCost = tierConfig.cores
    
    -- Check if player has enough cores
    if SpatialRefuge.CountCores(player) < coreCost then
        player:Say("Not enough cores!")
        return
    end
    
    -- Consume cores
    if not SpatialRefuge.ConsumeCores(player, coreCost) then
        player:Say("Failed to consume cores!")
        return
    end
    
    -- Perform upgrade
    if SpatialRefuge.PerformUpgrade(player, refugeData, nextTier) then
        player:Say("Refuge upgraded successfully!")
    else
        -- Refund cores if upgrade failed
        local inv = player:getInventory()
        if inv then
            for i = 1, coreCost do
                inv:AddItem(SpatialRefugeConfig.CORE_ITEM)
            end
        end
        player:Say("Upgrade failed - cores refunded")
    end
end

if getDebug() then
    print("[SpatialRefuge] Upgrade mechanics initialized")
end

return SpatialRefuge

