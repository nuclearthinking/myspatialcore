-- Cultivation Main - XP Award System
-- Awards Body Transformation XP for melee zombie kills

local CultivationMain = {}

-- Cache debug mode status
local isDebug = getDebug()

-- Track zombie data (weapon used, initial HP for dynamic XP calculation)
local zombieTrackingData = {}

-- Base HP used for XP calculation scaling (standard zombie HP)
-- XP formula: baseXP * (zombieMaxHP / BASE_ZOMBIE_HP)
local BASE_ZOMBIE_HP = 1.5  -- Vanilla normal zombie has ~1.5 HP
local BASE_XP = 10          -- Base XP for a standard zombie

-- Called on every hit to a zombie - track the weapon and initial HP
local function onHitZombie(zombie, wielder, bodyPartType, weapon)
    if not zombie or not wielder then return end
    
    -- Initialize tracking for this zombie if not exists
    if not zombieTrackingData[zombie] then
        -- Store initial HP when first encountered (before any damage from this hit)
        -- Note: zombie:getHealth() returns current HP, we capture it on first hit
        local currentHP = zombie:getHealth()
        -- Add the damage from current hit to estimate max HP
        -- Since this fires AFTER hit, the HP we see is post-damage
        -- We'll just use current HP as a baseline (close enough for scaling)
        zombieTrackingData[zombie] = {
            initialHP = currentHP,
            weapon = weapon
        }
        if isDebug then
            print(string.format("[Cultivation DEBUG] First hit on zombie, HP captured: %.2f", currentHP))
        end
    else
        -- Update weapon on subsequent hits
        zombieTrackingData[zombie].weapon = weapon
    end
end

-- Calculate dynamic XP based on zombie HP
local function calculateZombieXP(zombieHP)
    if not zombieHP or zombieHP <= 0 then
        return BASE_XP  -- Fallback to base XP
    end
    
    -- Scale XP based on HP ratio: higher HP = more XP
    -- Formula: BASE_XP * (zombieHP / BASE_ZOMBIE_HP)
    -- Example: 1.5 HP zombie = 10 XP, 3.0 HP zombie = 20 XP, 0.5 HP zombie = 3.3 XP
    local xpMultiplier = zombieHP / BASE_ZOMBIE_HP
    local calculatedXP = BASE_XP * xpMultiplier
    
    -- Minimum XP of 2 (0.5 actual) to ensure even weak zombies give something
    return math.max(2, calculatedXP)
end

-- Award XP for melee zombie kills
local function onZombieDead(zombie)
    local killer = zombie:getAttackedBy()
    
    -- Validation
    if not killer or not killer:isAlive() then
        zombieTrackingData[zombie] = nil  -- Cleanup
        return
    end
    
    -- Get tracked data for this zombie
    local trackingData = zombieTrackingData[zombie]
    zombieTrackingData[zombie] = nil  -- Cleanup
    
    local killingWeapon = trackingData and trackingData.weapon or nil
    local zombieInitialHP = trackingData and trackingData.initialHP or nil
    
    -- Check if kill was from a vehicle (runover) - no XP for vehicle kills
    if killer:getVehicle() ~= nil then
        if isDebug then
            print("[Cultivation DEBUG] Vehicle kill detected, no XP awarded")
        end
        return  -- Vehicle kill, no XP
    end
    
    -- Check if the killing blow was ranged
    if killingWeapon and killingWeapon:isRanged() then
        if isDebug then
            print("[Cultivation DEBUG] Ranged kill detected, no XP awarded")
        end
        return  -- Ranged kill, no XP
    end
    
    -- Check for nil weapon with no tracked hit (could be environmental or other non-melee kill)
    -- Only award XP if we actually tracked a hit from this killer
    if killingWeapon == nil then
        -- Nil weapon is valid for stomp/bare hands, but only if OnHitZombie was triggered
        -- Since we track all hits, nil means either stomp OR no melee contact at all
        -- For safety, we'll allow it (stomp/push kills are valid melee)
    end
    
    -- Calculate dynamic XP based on zombie HP
    local xpToAward = calculateZombieXP(zombieInitialHP)
    
    -- Cache XP manager and perk reference (avoid repeated global lookups)
    local xpManager = killer:getXp()
    local bodyPerk = Perks.Body
    
    -- Melee kill (including stomp, bare hands) - award XP
    local xpBefore = xpManager:getXP(bodyPerk)
    xpManager:AddXP(bodyPerk, xpToAward)
    local actualXPGained = xpManager:getXP(bodyPerk) - xpBefore
    
    -- Play absorption sound effect
    killer:playSound("cultivation_absorb")
    
    -- Show XP notification with custom icon (light yellow icon, green text)
    HaloTextHelper.addText(killer, string.format("[img=media/ui/BodyCultivation.png,255,242,150] [col=137,232,148]+%.1f[/]", actualXPGained))
    
    -- Optional: Show extra debug info
    if isDebug then
        print(string.format("[Cultivation DEBUG] +%.2f Body XP (%s) | Zombie HP: %.2f | Raw XP: %.1f", 
            actualXPGained, killingWeapon and killingWeapon:getName() or "stomp/hands", zombieInitialHP or 0, xpToAward))
    end
end

-- Register event after game is fully loaded
local function initializeCultivation()
    -- Check if perk exists
    if not Perks.Body then
        print("[Cultivation] CRITICAL ERROR: Perks.Body is nil! Perk not loaded from perks.txt!")
        return
    end
    
    print("[Cultivation] Body perk ID: " .. tostring(Perks.Body))
    
    -- Register hit tracking (fires on every hit, before death)
    if Events.OnHitZombie then
        Events.OnHitZombie.Add(onHitZombie)
        print("[Cultivation] Zombie hit tracking initialized")
    else
        print("[Cultivation] WARNING: OnHitZombie event not available!")
    end
    
    -- Register death handler
    if Events.OnZombieDead then
        Events.OnZombieDead.Add(onZombieDead)
        print("[Cultivation] Body Transformation XP system initialized")
    else
        print("[Cultivation] ERROR: OnZombieDead event not available!")
    end
end

-- Wait for game to fully load before registering events
Events.OnGameBoot.Add(initializeCultivation)

return CultivationMain
