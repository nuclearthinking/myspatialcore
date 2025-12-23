-- TechniqueEvents.lua
-- Hooks into game events and dispatches them to the technique system
-- Provides both standard game events and custom calculated events

local TechniqueManager = require "techniques/TechniqueManager"

local TechniqueEvents = {}

-- Cache debug mode (evaluated once at load)
local isDebug = getDebug()

-- Per-player tracking data for calculated events
local playerTracking = {}

-- Per-player cache for levelable technique check
local playerLevelableCache = {}

--[[
    STANDARD EVENTS (directly from game):
    - OnZombieKill          : Player killed a zombie (melee)
    - OnPlayerWakeUp        : Player woke up
    - OnPlayerDamage        : Player took damage
    
    CUSTOM CALCULATED EVENTS (per minute):
    - OnCalorieSurplus      : Player has calorie surplus above threshold
    - OnSustainedActivity   : Player active without exhaustion for period
    - OnZombieProximity     : Many zombies nearby (high pressure)
    - OnLowEndurance        : Player endurance critically low
    - OnHealthRecovery      : Player health is regenerating
    - OnMuscleStiffness     : Player has muscle stiffness
    
    PLAYER STATE CHECKS (system-level, block XP gain):
    - In vehicle
    - Sleeping
    - Sitting/Resting
    - Reading
]]

--==============================================================================
-- CONSTANTS (avoid recreation in loops)
--==============================================================================

local CALORIE_SURPLUS_THRESHOLD = 1500
local ENDURANCE_THRESHOLD = 0.9  -- Must stay above 90% endurance
local LOW_ENDURANCE_THRESHOLD = 0.15
local ZOMBIE_PROXIMITY_RADIUS = 15
local ZOMBIE_PROXIMITY_RADIUS_SQ = ZOMBIE_PROXIMITY_RADIUS * ZOMBIE_PROXIMITY_RADIUS  -- Avoid sqrt
local ZOMBIE_COUNT_THRESHOLD = 5
local STIFFNESS_THRESHOLD = 5

-- Body parts to check for stiffness (module-level to avoid recreation)
local STIFFNESS_PARTS = {
    BodyPartType.ForeArm_L, BodyPartType.ForeArm_R,
    BodyPartType.UpperArm_L, BodyPartType.UpperArm_R,
    BodyPartType.Torso_Upper, BodyPartType.Torso_Lower,
    BodyPartType.UpperLeg_L, BodyPartType.UpperLeg_R,
}

--==============================================================================
-- SYSTEM-LEVEL PLAYER STATE CHECKS
--==============================================================================

--- Check if player is in an inactive state (no technique XP should be gained)
--- This is a system-level check that applies to activity-based events
---@param player IsoPlayer
---@return boolean isInactive True if player should NOT gain activity XP
---@return string|nil reason Debug reason string
function TechniqueEvents.isPlayerInactive(player)
    if not player then return true, "no player" end
    
    -- In vehicle (fast check first)
    if player:getVehicle() ~= nil then
        return true, "in vehicle"
    end
    
    -- Sleeping
    if player:isAsleep() then
        return true, "sleeping"
    end
    
    -- Sitting on ground
    if player:isSitOnGround() then
        return true, "sitting on ground"
    end
    
    -- Sitting on furniture (animation state check)
    local animState = player:getVariableString("SitType")
    if animState and animState ~= "" then
        return true, "sitting"
    end
    
    -- Lying down / resting
    if player:getVariableBoolean("IsLyingOnFurniture") then
        return true, "lying down"
    end
    
    -- Reading a book/magazine
    if player:isReading() then
        return true, "reading"
    end
    
    return false, nil
end

--- Check if player is in a state where activity-based XP should count
--- More restrictive than isPlayerInactive - requires actual physical activity
---@param player IsoPlayer
---@return boolean isActive True if player is actively moving/fighting
---@return string|nil reason Debug reason string
function TechniqueEvents.isPlayerPhysicallyActive(player)
    -- First check basic inactive states
    local isInactive, reason = TechniqueEvents.isPlayerInactive(player)
    if isInactive then
        return false, reason
    end
    
    -- Check for physical activity: moving, running, sprinting, or aiming
    if player:isPlayerMoving() or player:isRunning() or player:isSprinting() or player:isAiming() then
        return true, "active"
    end
    
    -- Also consider active if performing timed action (crafting, building, etc.)
    local currentAction = player:getCharacterActions()
    if currentAction and currentAction:size() > 0 then
        return true, "performing action"
    end
    
    return false, "idle"
end

--- Get or create player tracking data
---@param player IsoPlayer
---@return table
local function getTracking(player)
    local username = player:getUsername()
    if not playerTracking[username] then
        playerTracking[username] = {
            -- Activity tracking
            lastEndurance = nil,
            sustainedActivityMinutes = 0,
            
            -- Combat tracking
            zombiesKilledThisMinute = 0,
            damagesTakenThisMinute = 0,
            
            -- Calorie tracking
            calorieSurplusMinutes = 0,
        }
    end
    return playerTracking[username]
end

--==============================================================================
-- STANDARD GAME EVENT HOOKS
--==============================================================================

--- Called when a zombie dies (from any cause)
--- We filter for melee kills in the handler
function TechniqueEvents.onZombieDead(zombie)
    local killer = zombie:getAttackedBy()
    if not killer or not killer:isAlive() then return end
    
    -- Skip vehicle kills
    if killer:getVehicle() ~= nil then return end
    
    -- Get zombie HP for event data
    local zombieHP = zombie:getHealth() or 1.5
    
    -- Track kills
    local tracking = getTracking(killer)
    tracking.zombiesKilledThisMinute = tracking.zombiesKilledThisMinute + 1
    
    -- Dispatch event
    TechniqueManager.processEvent(killer, "OnZombieKill", {
        zombie = zombie,
        zombieHP = zombieHP,
        killsThisMinute = tracking.zombiesKilledThisMinute,
    })
end

--- Called when player takes damage
function TechniqueEvents.onPlayerDamage(character, damageType, damage)
    -- Filter for player characters only
    if not character or not instanceof(character, "IsoPlayer") then return end
    if not character:isAlive() then return end
    
    local tracking = getTracking(character)
    tracking.damagesTakenThisMinute = tracking.damagesTakenThisMinute + 1
    
    TechniqueManager.processEvent(character, "OnPlayerDamage", {
        damageType = damageType,
        damage = damage,
        damagesToday = tracking.damagesTakenThisMinute,
    })
end

--- Called when player wakes up from sleep
function TechniqueEvents.onPlayerWakeUp(player)
    if not player then return end
    
    local stats = player:getStats()
    TechniqueManager.processEvent(player, "OnPlayerWakeUp", {
        fatigue = stats and stats:get(CharacterStat.FATIGUE) or 0,
    })
end

--==============================================================================
-- CUSTOM CALCULATED EVENTS (per minute)
--==============================================================================

--- Check if player has any techniques that can still level up (cached)
---@param player IsoPlayer
---@return boolean hasLevelableTechniques
local function hasLevelableTechniques(player)
    local username = player:getUsername()
    
    -- Check cache first
    if playerLevelableCache[username] ~= nil then
        return playerLevelableCache[username]
    end
    
    -- Calculate and cache result
    local learnedTechniques = TechniqueManager.getLearnedTechniques(player)
    local TechniqueRegistry = require "techniques/TechniqueRegistry"
    
    local hasLevelable = false
    for _, techData in ipairs(learnedTechniques) do
        local technique = techData.technique
        if technique then
            local maxStage = technique.maxStage or 5
            if techData.stage < maxStage then
                hasLevelable = true
                break
            end
        end
    end
    
    playerLevelableCache[username] = hasLevelable
    return hasLevelable
end

--- Invalidate levelable cache for a player (call when technique levels up or is learned)
---@param player IsoPlayer
function TechniqueEvents.invalidateLevelableCache(player)
    if player then
        local username = player:getUsername()
        playerLevelableCache[username] = nil
    end
end

--- Process calculated events for a single player
---@param player IsoPlayer
local function processPlayerCalculatedEvents(player)
    if not player or not player:isAlive() then return end
    
    -- OPTIMIZATION: Skip all event processing if all techniques are maxed
    if not hasLevelableTechniques(player) then
        return
    end
    
    local tracking = getTracking(player)
    local stats = player:getStats()
    local nutrition = player:getNutrition()
    local bodyDamage = player:getBodyDamage()
    
    --==========================================================================
    -- OnCalorieSurplus: Calorie count above threshold
    -- This can trigger even when resting (passive digestion)
    --==========================================================================
    if nutrition then
        local currentCalories = nutrition:getCalories()
        if currentCalories > CALORIE_SURPLUS_THRESHOLD then
            local surplus = currentCalories - CALORIE_SURPLUS_THRESHOLD
            tracking.calorieSurplusMinutes = tracking.calorieSurplusMinutes + 1
            
            TechniqueManager.processEvent(player, "OnCalorieSurplus", {
                calories = currentCalories,
                surplus = surplus,
                sustainedMinutes = tracking.calorieSurplusMinutes,
            })
        else
            tracking.calorieSurplusMinutes = 0
        end
    end
    
    --==========================================================================
    -- OnSustainedActivity: Active without exhaustion
    -- REQUIRES: Endurance > 90%, physically active, NOT inactive state
    --==========================================================================
    if stats then
        local currentEndurance = stats:get(CharacterStat.ENDURANCE)
        
        -- Check all conditions for sustained activity
        local meetsEndurance = currentEndurance and currentEndurance > ENDURANCE_THRESHOLD
        local wasAboveThreshold = tracking.lastEndurance and tracking.lastEndurance > ENDURANCE_THRESHOLD
        
        -- Only check physical activity if endurance requirements are met (avoid extra work)
        local isPhysicallyActive = false
        local activeReason = nil
        if meetsEndurance and wasAboveThreshold then
            isPhysicallyActive, activeReason = TechniqueEvents.isPlayerPhysicallyActive(player)
        end
        
        if meetsEndurance and wasAboveThreshold and isPhysicallyActive then
            tracking.sustainedActivityMinutes = tracking.sustainedActivityMinutes + 1
            
            TechniqueManager.processEvent(player, "OnSustainedActivity", {
                endurance = currentEndurance,
                sustainedMinutes = tracking.sustainedActivityMinutes,
            })
            
            if isDebug then
                print(string.format("[TechniqueEvents] %s: OnSustainedActivity - endurance=%.0f%%, minutes=%d",
                    player:getUsername(), currentEndurance * 100, tracking.sustainedActivityMinutes))
            end
        else
            -- Reset if any condition fails
            if tracking.sustainedActivityMinutes > 0 and isDebug then
                local resetReason = "unknown"
                if not meetsEndurance then
                    resetReason = string.format("endurance too low (%.0f%% < 90%%)", (currentEndurance or 0) * 100)
                elseif not wasAboveThreshold then
                    resetReason = "endurance dropped below threshold"
                elseif not isPhysicallyActive then
                    resetReason = activeReason or "not active"
                end
                print(string.format("[TechniqueEvents] %s: SustainedActivity reset - %s",
                    player:getUsername(), resetReason))
            end
            tracking.sustainedActivityMinutes = 0
        end
        tracking.lastEndurance = currentEndurance
    end
    
    --==========================================================================
    -- OnZombieProximity: Many zombies nearby (high pressure)
    -- Can trigger even when inactive (zombies surrounding you)
    -- OPTIMIZED: Uses squared distance to avoid sqrt
    --==========================================================================
    local cell = player:getCell()
    if cell then
        local zombieList = cell:getZombieList()
        local listSize = zombieList:size()
        
        -- Early exit if not enough zombies in cell
        if listSize >= ZOMBIE_COUNT_THRESHOLD then
            local nearbyCount = 0
            local px, py = player:getX(), player:getY()
            
            for i = 0, listSize - 1 do
                local zombie = zombieList:get(i)
                if zombie then
                    local dx = zombie:getX() - px
                    local dy = zombie:getY() - py
                    local distSq = dx*dx + dy*dy  -- Squared distance (no sqrt)
                    if distSq <= ZOMBIE_PROXIMITY_RADIUS_SQ then
                        nearbyCount = nearbyCount + 1
                        -- Early exit once threshold is met (optimization)
                        if nearbyCount >= ZOMBIE_COUNT_THRESHOLD then
                            TechniqueManager.processEvent(player, "OnZombieProximity", {
                                zombieCount = nearbyCount,
                                radius = ZOMBIE_PROXIMITY_RADIUS,
                            })
                            break
                        end
                    end
                end
            end
        end
    end
    
    --==========================================================================
    -- OnLowEndurance: Endurance critically low
    -- Can trigger anytime (represents exhaustion state)
    --==========================================================================
    if stats then
        local endurance = stats:get(CharacterStat.ENDURANCE)
        if endurance and endurance < LOW_ENDURANCE_THRESHOLD then
            TechniqueManager.processEvent(player, "OnLowEndurance", {
                endurance = endurance,
            })
        end
    end
    
    --==========================================================================
    -- OnHealthRecovery: Player health below max
    -- Can trigger when resting (passive recovery)
    --==========================================================================
    if bodyDamage then
        local health = bodyDamage:getOverallBodyHealth()
        if health and health < 100 then
            TechniqueManager.processEvent(player, "OnHealthRecovery", {
                health = health,
                missing = 100 - health,
            })
        end
    end
    
    --==========================================================================
    -- OnMuscleStiffness: Player has stiffness on body parts
    -- Can trigger when resting (you still have stiffness)
    --==========================================================================
    if bodyDamage then
        local totalStiffness = 0
        
        for i = 1, #STIFFNESS_PARTS do
            local part = bodyDamage:getBodyPart(STIFFNESS_PARTS[i])
            if part then
                totalStiffness = totalStiffness + part:getStiffness()
            end
        end
        
        if totalStiffness > STIFFNESS_THRESHOLD then
            TechniqueManager.processEvent(player, "OnMuscleStiffness", {
                totalStiffness = totalStiffness,
            })
        end
    end
    
    --==========================================================================
    -- Reset per-minute counters
    --==========================================================================
    tracking.zombiesKilledThisMinute = 0
    tracking.damagesTakenThisMinute = 0
end

--- Apply technique effects for a player (passive effects that run every minute)
local function applyTechniqueEffects(player)
    local TechniqueRegistry = require "techniques/TechniqueRegistry"
    local learnedTechniques = TechniqueManager.getLearnedTechniques(player)
    
    -- learnedTechniques is an array of {id, stage, xp, technique}
    for _, techData in ipairs(learnedTechniques) do
        local technique = techData.technique
        if technique and technique.applyEffect and techData.stage > 0 then
            -- Call the technique's applyEffect function
            local stats = technique.applyEffect(player, techData.stage)
            
            -- Debug output
            if isDebug and stats and (stats.caloriesConsumed or 0) > 0 then
                print(string.format("[TechniqueEvents] %s applied %s effect", 
                    player:getUsername(), techData.id))
            end
        end
    end
end

--- Process all active players (called every game minute)
local function processAllPlayers()
    local numPlayers = getNumActivePlayers()
    for i = 0, numPlayers - 1 do
        local player = getSpecificPlayer(i)
        if player and player:isAlive() then
            processPlayerCalculatedEvents(player)
            applyTechniqueEffects(player)  -- Apply technique passive effects
        end
    end
end

--==============================================================================
-- INITIALIZATION
--==============================================================================

-- Cleanup player tracking data
local function cleanupPlayerTracking(player)
    if player then
        local username = player:getUsername()
        if username then
            if playerTracking[username] then
                playerTracking[username] = nil
            end
            if playerLevelableCache[username] then
                playerLevelableCache[username] = nil
            end
        end
    end
end

local function initializeTechniqueEvents()
    -- Load player data on game load
    Events.OnLoad.Add(function()
        playerTracking = {}
        playerLevelableCache = {}
        local numPlayers = getNumActivePlayers()
        for i = 0, numPlayers - 1 do
            local player = getSpecificPlayer(i)
            if player then
                TechniqueManager.loadPlayerData(player)
            end
        end
    end)
    
    -- Cleanup on player death
    Events.OnPlayerDeath.Add(function(player)
        if player then
            TechniqueManager.savePlayerData(player)
            cleanupPlayerTracking(player)
        end
    end)
    
    -- Save player data periodically
    Events.EveryTenMinutes.Add(function()
        local numPlayers = getNumActivePlayers()
        for i = 0, numPlayers - 1 do
            local player = getSpecificPlayer(i)
            if player then
                TechniqueManager.savePlayerData(player)
            end
        end
    end)
    
    -- Hook standard events
    if Events.OnZombieDead then
        Events.OnZombieDead.Add(TechniqueEvents.onZombieDead)
    end
    
    if Events.OnPlayerWakeUp then
        Events.OnPlayerWakeUp.Add(TechniqueEvents.onPlayerWakeUp)
    end
    
    -- Hook player damage event (was missing before!)
    if Events.OnCharacterGetDamage then
        Events.OnCharacterGetDamage.Add(TechniqueEvents.onPlayerDamage)
    end
    
    -- Process calculated events every minute
    Events.EveryOneMinute.Add(processAllPlayers)
    
    print("[TechniqueEvents] Event hooks initialized")
end

-- Initialize after game boot
Events.OnGameBoot.Add(initializeTechniqueEvents)

return TechniqueEvents

