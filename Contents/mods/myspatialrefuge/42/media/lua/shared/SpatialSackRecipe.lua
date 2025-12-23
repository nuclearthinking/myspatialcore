-- Initialize newly crafted Spatial Sack with tier 0 stats
function OnCreateSpatialSack(items, result, player)
    if not result then return end
    
    -- Set initial tier data
    local modData = result:getModData()
    modData.tier = 0
    modData.enchantLevel = 0
    
    if player then
        modData.createdBy = player:getUsername()
    end
    modData.creationTime = os.time()
    
    -- Set starting capacity (10 units)
    local container = result:getItemContainer()
    if container then
        container:setCapacity(10)
        
        if getDebug() then
            print("[SpatialSack] Created Tier 0 sack with capacity: " .. container:getCapacity())
        end
    end
    
    if player then
        HaloTextHelper.addGoodText(player, "Crafted Spatial Sack!")
        HaloTextHelper.addText(player, "Tier 0 - Capacity: 10")
    end
end
