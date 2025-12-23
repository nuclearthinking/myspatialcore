local SpatialSackServer = {}

-- Zombie death handler - add magical cores as drops
local function onZombieDead(zombie)
    if not zombie then return end
    
    -- 30% chance to drop magical core (adjust for balance)
    if ZombRand(100) < 30 then
        zombie:getInventory():AddItem("Base.MagicalCore")
        
        if getDebug() then
            print("[SpatialSack] Zombie dropped Strange Zombie Core")
        end
    end
end

-- Register zombie death event
Events.OnZombieDead.Add(onZombieDead)

return SpatialSackServer
