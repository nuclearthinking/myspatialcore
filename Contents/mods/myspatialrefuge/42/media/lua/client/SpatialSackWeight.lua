local SpatialSackWeight = {}

local originalGetWeight = nil

-- Check if an item is inside a Spatial Sack
local function isInsideSpatialSack(item)
    if not item then return false end
    local container = item:getContainer()
    if not container then return false end
    local containingItem = container:getContainingItem()
    return containingItem and containingItem:getType() == "SpatialSack"
end

-- Override weight calculation
function SpatialSackWeight.overrideWeightCalculation()
    if not InventoryItem then return end
    
    if not originalGetWeight then
        originalGetWeight = InventoryItem.getWeight
    end
    
    InventoryItem.getWeight = function(self)
        if not self then return 0 end
        
        -- Spatial Sack itself weighs 0
        if self:getType() == "SpatialSack" then
            return 0
        end
        
        -- Items inside Spatial Sack weigh 0
        if isInsideSpatialSack(self) then
            return 0
        end
        
        -- All other items use original weight
        if originalGetWeight then
            return originalGetWeight(self)
        end
        
        return self:getActualWeight() or 0
    end
end

return SpatialSackWeight
