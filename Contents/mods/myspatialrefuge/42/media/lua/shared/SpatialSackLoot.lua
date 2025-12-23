local SpatialSackLoot = {}

-- Add Spatial Sack to loot distribution tables
function SpatialSackLoot.addToLootTables()
    -- Check if DistributionTables exists
    if not ProceduralDistributions then
        if getDebug() then
            print("SpatialSack: ProceduralDistributions not found")
        end
        return
    end
    
    local spawnChance = 0.5 -- 0.5% spawn chance (configurable via sandbox)
    
    -- Add to safes (banks, gun stores)
    if ProceduralDistributions.list.Safe then
        table.insert(ProceduralDistributions.list.Safe.items, "Base.SpatialSack")
        table.insert(ProceduralDistributions.list.Safe.items, spawnChance)
    end
    
    -- Add to gun store safes
    if ProceduralDistributions.list.GunStoreSafe then
        table.insert(ProceduralDistributions.list.GunStoreSafe.items, "Base.SpatialSack")
        table.insert(ProceduralDistributions.list.GunStoreSafe.items, spawnChance)
    end
    
    -- Add to bank safes
    if ProceduralDistributions.list.BankSafe then
        table.insert(ProceduralDistributions.list.BankSafe.items, "Base.SpatialSack")
        table.insert(ProceduralDistributions.list.BankSafe.items, spawnChance)
    end
    
    -- Add to lockers (police, military)
    if ProceduralDistributions.list.Locker then
        table.insert(ProceduralDistributions.list.Locker.items, "Base.SpatialSack")
        table.insert(ProceduralDistributions.list.Locker.items, spawnChance * 0.5) -- Lower chance in lockers
    end
    
    -- Add to police locker
    if ProceduralDistributions.list.PoliceLocker then
        table.insert(ProceduralDistributions.list.PoliceLocker.items, "Base.SpatialSack")
        table.insert(ProceduralDistributions.list.PoliceLocker.items, spawnChance * 0.5)
    end
    
    -- Add to rare containers
    if ProceduralDistributions.list.RareContainers then
        table.insert(ProceduralDistributions.list.RareContainers.items, "Base.SpatialSack")
        table.insert(ProceduralDistributions.list.RareContainers.items, spawnChance)
    end
    
    if getDebug() then
        print("SpatialSack: Added to loot distribution tables")
    end
end

-- Initialize loot distribution
function SpatialSackLoot.onGameBoot()
    SpatialSackLoot.addToLootTables()
end

function SpatialSackLoot.onInitWorld()
    if isServer() then
        SpatialSackLoot.addToLootTables()
    end
end

-- Register events
Events.OnGameBoot.Add(SpatialSackLoot.onGameBoot)
Events.OnInitWorld.Add(SpatialSackLoot.onInitWorld)

return SpatialSackLoot
