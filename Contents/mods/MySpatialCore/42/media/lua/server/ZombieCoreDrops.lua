--[[
    ZombieCoreDrops.lua - Strange Zombie Core drop system
    
    Part of MySpatialCore library mod.
    Handles dropping Strange Zombie Core from zombies.
]]

local ZombieCoreDrops = {}

-- Configuration (exposed for other mods)
ZombieCoreDrops.ITEM_TYPE = "Base.MagicalCore"
ZombieCoreDrops.DEFAULT_DROP_CHANCE = 30

-- Cached state (set at init, never changes)
local dropChance
local alwaysDrop

---@param zombie IsoZombie
local function onZombieCreate(zombie)
    if not zombie then return end
    
    if alwaysDrop or ZombRand(100) < dropChance then
        local item = instanceItem(ZombieCoreDrops.ITEM_TYPE)
        if item then
            zombie:addItemToSpawnAtDeath(item)
        end
    end
end

-- Initialize once per session
if not _G.MySpatialCoreDropsInitialized then
    _G.MySpatialCoreDropsInitialized = true
    
    -- Only register on server/host (not pure clients)
    local isServerSide = isServer()
    local isPureClient = not isServerSide and isClient()
    
    if not isPureClient then
        -- Load drop chance from sandbox options
        local sandboxVars = SandboxVars and SandboxVars.MySpatialCore or {}
        dropChance = sandboxVars.ZombieCoreDropChance or ZombieCoreDrops.DEFAULT_DROP_CHANCE
        
        -- Clamp to valid range (min 1% to ensure cores drop for dependent mods)
        if dropChance < 1 then dropChance = 1 end
        if dropChance > 100 then dropChance = 100 end
        
        -- Cache whether we skip random rolls
        alwaysDrop = dropChance >= 100
        
        Events.OnZombieCreate.Add(onZombieCreate)
        print("[MySpatialCore] Zombie core drop system initialized (drop chance: " .. dropChance .. "%)")
    end
end

return ZombieCoreDrops
