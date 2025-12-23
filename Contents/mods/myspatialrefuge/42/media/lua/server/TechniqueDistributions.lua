require 'Items/SuburbsDistributions'
require "Items/ProceduralDistributions"
require "Vehicles/VehicleDistributions"

-- Sandbox options for spawn rates (default to 1 if not set)
local sandboxVars = SandboxVars.MySpatialRefuge or {}
local DropTechnique = sandboxVars.TechniqueDropRate or 1

-- Check for OneWeekLater mod (reduces zombie drop rates significantly)
local isOneWeekLater = getActivatedMods():contains("OneWeekLater")
local zombieDropFactor = isOneWeekLater and 0.001 or 0.02  -- Very rare from zombies

-- Technique manuscripts should be rare and found in thematic locations
local TechniqueDistributions = {
    -- Efficient Absorption - Found in medical, kitchen, nutrition-related locations
    -- Most common technique - essential for new cultivators
    {
        Distributions = {
            {"MedicalClinicBooks", DropTechnique * 3},
            {"MedicalOfficeBooks", DropTechnique * 3},
            {"MedicalStorageMedicine", DropTechnique * 2},
            {"LibraryBooks", DropTechnique * 2},
            {"BookstoreMisc", DropTechnique * 3},
            {"SchoolLockers", DropTechnique * 1},
            {"GymLockers", DropTechnique * 2},
            {"RestaurantKitchenCounters", DropTechnique * 1},
            {"SurvivorCache1", DropTechnique * 5},
            {"SurvivorCache2", DropTechnique * 5},
            {"SurvivorCache3", DropTechnique * 5},
            {"SurvivorCache4", DropTechnique * 5},
            {"LootZombies", DropTechnique * zombieDropFactor * 1.5},  -- Slightly more common
        },
        Vehicles = {
            {"AmbulanceTruckBed", DropTechnique * 2},
        },
        Items = { "Base.TechniqueManuscript_Absorption" }
    },
    
    -- Movement Economy - Found in athletic, martial arts, military locations
    -- Medium rarity - for intermediate cultivators
    {
        Distributions = {
            {"GymLockers", DropTechnique * 4},
            {"GymWeights", DropTechnique * 2},
            {"LibraryBooks", DropTechnique * 1},
            {"BookstoreMisc", DropTechnique * 2},
            {"ArmyStorageOutfit", DropTechnique * 3},
            {"ArmySurplusMisc", DropTechnique * 3},
            {"ArmyBunkerStorage", DropTechnique * 4},
            {"PoliceLockers", DropTechnique * 2},
            {"FireDeptLockers", DropTechnique * 2},
            {"SurvivorCache1", DropTechnique * 4},
            {"SurvivorCache2", DropTechnique * 4},
            {"SurvivorCache3", DropTechnique * 4},
            {"SurvivorCache4", DropTechnique * 4},
            {"LootZombies", DropTechnique * zombieDropFactor},
        },
        Vehicles = {
            {"ArmyLightTruckBed", DropTechnique * 2},
            {"ArmyHeavyTruckBed", DropTechnique * 2},
        },
        Items = { "Base.TechniqueManuscript_Movement" }
    },
    
    -- Energy Stabilization - RARE, found in mysterious/occult/special locations
    -- Rarest technique - for advanced cultivators
    {
        Distributions = {
            {"LibraryBooks", DropTechnique * 0.5},   -- Very rare in libraries
            {"BookstoreMisc", DropTechnique * 0.5},
            {"Antiques", DropTechnique * 2},          -- Antique shops
            {"PawnShopBooks", DropTechnique * 1},
            {"ArmyBunkerStorage", DropTechnique * 2}, -- Secret military research
            {"SurvivorCache1", DropTechnique * 3},
            {"SurvivorCache2", DropTechnique * 3},
            {"SurvivorCache3", DropTechnique * 3},
            {"SurvivorCache4", DropTechnique * 3},
            {"SafehouseMedical", DropTechnique * 2},
            {"LootZombies", DropTechnique * zombieDropFactor * 0.5},  -- Very rare from zombies
        },
        Vehicles = {},
        Items = { "Base.TechniqueManuscript_Stabilization" }
    },
}

-- Helper function to get loot table from either Procedural or Suburbs distributions
local function getLootTable(name)
    return ProceduralDistributions.list[name] or 
           (SuburbsDistributions["all"] and SuburbsDistributions["all"][name])
end

-- Insert item into loot table
local function insertItem(tLootTable, item, weight)
    if tLootTable and tLootTable.items then
        table.insert(tLootTable.items, item)
        table.insert(tLootTable.items, weight)
    end
end

-- Insert item into vehicle distribution
local function insertVehicleItem(vehicleTable, item, weight)
    if vehicleTable and vehicleTable.items then
        table.insert(vehicleTable.items, item)
        table.insert(vehicleTable.items, weight)
    end
end

-- Main distribution merge function
local function preDistributionMerge()
    print("[MySpatialRefuge] Adding technique manuscript distributions...")
    
    local itemsAdded = 0
    
    for _, group in ipairs(TechniqueDistributions) do
        -- Add to procedural/suburbs distributions
        if group.Distributions then
            for _, dist in ipairs(group.Distributions) do
                local lootTable = getLootTable(dist[1])
                if lootTable then
                    for _, item in ipairs(group.Items) do
                        insertItem(lootTable, item, dist[2])
                        itemsAdded = itemsAdded + 1
                    end
                end
            end
        end
        
        -- Add to vehicle distributions
        if group.Vehicles then
            for _, veh in ipairs(group.Vehicles) do
                local vehicleTable = VehicleDistributions[veh[1]]
                if vehicleTable then
                    for _, item in ipairs(group.Items) do
                        insertVehicleItem(vehicleTable, item, veh[2])
                        itemsAdded = itemsAdded + 1
                    end
                end
            end
        end
    end
    
    print("[MySpatialRefuge] Added " .. itemsAdded .. " technique distribution entries")
end

-- Register the distribution merge
Events.OnPreDistributionMerge.Add(preDistributionMerge)

