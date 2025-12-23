-- EffectApplicator.lua
-- Applies combined effects from EffectRegistry to player character
-- Single pass through stats - no duplication

local EffectRegistry = require "effects/EffectRegistry"

local EffectApplicator = {}

-- Cache debug mode
local isDebug = getDebug()

-- Per-player stat tracking (for delta-based reductions)
local playerTracking = {}

-- Session statistics
local sessionStats = {}

-- Body parts that can have stiffness
local STIFFNESS_BODY_PARTS = {
    BodyPartType.ForeArm_L,
    BodyPartType.ForeArm_R,
    BodyPartType.UpperArm_L,
    BodyPartType.UpperArm_R,
    BodyPartType.Torso_Upper,
    BodyPartType.Torso_Lower,
    BodyPartType.UpperLeg_L,
    BodyPartType.UpperLeg_R,
    BodyPartType.LowerLeg_L,
    BodyPartType.LowerLeg_R,
}

--==============================================================================
-- HELPER FUNCTIONS
--==============================================================================

--- Get unique player key (prevents multiplayer collisions)
---@param player IsoPlayer
---@return string|nil
local function getPlayerKey(player)
    if not player then 
        if isDebug then
            print("[EffectApplicator] ERROR: getPlayerKey called with nil player")
        end
        return nil 
    end
    
    -- Use player's online ID if available (multiplayer safe)
    local success, onlineID = pcall(function() return player:getOnlineID() end)
    if success and onlineID and onlineID >= 0 then
        return "player_" .. tostring(onlineID)
    end
    
    -- Fallback to username for single player
    local success2, username = pcall(function() return player:getUsername() end)
    if success2 and username then
        return "player_" .. username
    end
    
    -- Last resort: use tostring
    return "player_" .. tostring(player)
end

--- Get or create player tracking data
---@param player IsoPlayer
---@return table|nil
local function getPlayerTracking(player)
    local playerKey = getPlayerKey(player)
    if not playerKey then
        if isDebug then
            print("[EffectApplicator] ERROR: Failed to get player key for tracking")
        end
        return nil
    end
    
    if not playerTracking[playerKey] then
        playerTracking[playerKey] = {
            hunger = nil,
            thirst = nil,
            fatigue = nil,
            endurance = nil,
            stiffness = {},
            lastFitnessLevel = nil,
            lastStrengthLevel = nil,
        }
    end
    return playerTracking[playerKey]
end

--- Get or create session stats
---@param player IsoPlayer
---@return table|nil
local function getSessionStats(player)
    local playerKey = getPlayerKey(player)
    if not playerKey then 
        if isDebug then
            print("[EffectApplicator] ERROR: Failed to get player key for session stats")
        end
        return nil 
    end
    
    if not sessionStats[playerKey] then
        sessionStats[playerKey] = {
            hungerReduced = 0,
            thirstReduced = 0,
            fatigueReduced = 0,
            enduranceReduced = 0,
            stiffnessReduced = 0,
            stiffnessDecayed = 0,
            healthRegenerated = 0,
            fitnessXPAdded = 0,
            strengthXPAdded = 0,
            effectsApplied = 0,
        }
    end
    return sessionStats[playerKey]  -- FIX: was sessionStats[username]
end

--==============================================================================
-- STAT REDUCTION EFFECTS (Delta-based)
--==============================================================================

--- Apply reduction effects (hunger, thirst, fatigue, endurance, stiffness)
---@param player IsoPlayer
function EffectApplicator.applyReductions(player)
    if not player or not player:isAlive() then return end
    
    local stats = player:getStats()
    if not stats then return end
    
    local tracking = getPlayerTracking(player)
    local session = getSessionStats(player)
    
    -- Safety check: if tracking or session is nil, abort
    if not tracking or not session then
        if isDebug then
            print("[EffectApplicator] ERROR: Failed to get player tracking/session data")
        end
        return
    end
    
    -- Get reduction multipliers from registry
    local hungerReduction = EffectRegistry.get(player, "hunger_reduction", 0)
    local thirstReduction = EffectRegistry.get(player, "thirst_reduction", 0)
    local fatigueReduction = EffectRegistry.get(player, "fatigue_reduction", 0)
    local enduranceReduction = EffectRegistry.get(player, "endurance_reduction", 0)
    local stiffnessReduction = EffectRegistry.get(player, "stiffness_reduction", 0)
    
    -- Debug: Show active reductions once per session
    if isDebug and session.effectsApplied == 0 then
        print(string.format("[EffectApplicator] Active reductions - Hunger:%.1f%% Thirst:%.1f%% Fatigue:%.1f%% Endurance:%.1f%% Stiffness:%.1f%%",
            hungerReduction * 100, thirstReduction * 100, fatigueReduction * 100, 
            enduranceReduction * 100, stiffnessReduction * 100))
    end
    
    -- Get current stat values
    local currentHunger = stats:get(CharacterStat.HUNGER)
    local currentThirst = stats:get(CharacterStat.THIRST)
    local currentFatigue = stats:get(CharacterStat.FATIGUE)
    local currentEndurance = stats:get(CharacterStat.ENDURANCE)
    
    -- Safety check
    if currentHunger == nil or currentThirst == nil or currentFatigue == nil or currentEndurance == nil then
        if isDebug then
            print("[EffectApplicator] WARNING: Some stats returned nil")
        end
        return
    end
    
    -- Apply HUNGER reduction
    if tracking.hunger ~= nil and hungerReduction > 0 then
        local change = currentHunger - tracking.hunger
        if change > 0.00001 then
            local reducedAmount = change * hungerReduction
            local newValue = tracking.hunger + (change - reducedAmount)
            stats:set(CharacterStat.HUNGER, newValue)
            session.hungerReduced = session.hungerReduced + reducedAmount
            currentHunger = newValue
            if isDebug then
                print(string.format("[EffectApplicator] Hunger: %.4f -> %.4f (saved: %.6f, %.1f%%)", 
                    tracking.hunger, newValue, reducedAmount, hungerReduction * 100))
            end
        elseif isDebug and change > 0 then
            -- Show when hunger increased but below threshold
            print(string.format("[EffectApplicator] Hunger: %.6f change too small (%.8f < 0.00001)", 
                currentHunger, change))
        end
    end
    tracking.hunger = currentHunger
    
    -- Apply THIRST reduction
    if tracking.thirst ~= nil and thirstReduction > 0 then
        local change = currentThirst - tracking.thirst
        if change > 0.00001 then
            local reducedAmount = change * thirstReduction
            local newValue = tracking.thirst + (change - reducedAmount)
            stats:set(CharacterStat.THIRST, newValue)
            session.thirstReduced = session.thirstReduced + reducedAmount
            currentThirst = newValue
            if isDebug then
                print(string.format("[EffectApplicator] Thirst: %.4f -> %.4f (saved: %.6f, %.1f%%)", 
                    tracking.thirst, newValue, reducedAmount, thirstReduction * 100))
            end
        end
    end
    tracking.thirst = currentThirst
    
    -- Apply FATIGUE reduction
    if tracking.fatigue ~= nil and fatigueReduction > 0 then
        local change = currentFatigue - tracking.fatigue
        if change > 0.00001 then
            local reducedAmount = change * fatigueReduction
            local newValue = tracking.fatigue + (change - reducedAmount)
            stats:set(CharacterStat.FATIGUE, newValue)
            session.fatigueReduced = session.fatigueReduced + reducedAmount
            currentFatigue = newValue
            if isDebug then
                print(string.format("[EffectApplicator] Fatigue: %.4f -> %.4f (saved: %.6f, %.1f%%)", 
                    tracking.fatigue, newValue, reducedAmount, fatigueReduction * 100))
            end
        end
    end
    tracking.fatigue = currentFatigue
    
    -- Apply ENDURANCE drain reduction
    if tracking.endurance ~= nil and enduranceReduction > 0 then
        local change = tracking.endurance - currentEndurance
        if change > 0.00001 then
            local reducedAmount = change * enduranceReduction
            local newValue = tracking.endurance - (change - reducedAmount)
            stats:set(CharacterStat.ENDURANCE, newValue)
            session.enduranceReduced = session.enduranceReduced + reducedAmount
            currentEndurance = newValue
            if isDebug then
                print(string.format("[EffectApplicator] Endurance: %.4f -> %.4f (saved drain: %.6f, %.1f%%)", 
                    tracking.endurance, newValue, reducedAmount, enduranceReduction * 100))
            end
        end
    end
    tracking.endurance = currentEndurance
    
    -- Apply STIFFNESS reduction
    local bodyDamage = player:getBodyDamage()
    if bodyDamage and stiffnessReduction > 0 then
        for _, partType in ipairs(STIFFNESS_BODY_PARTS) do
            local bodyPart = bodyDamage:getBodyPart(partType)
            if bodyPart then
                local partIndex = BodyPartType.ToIndex(partType)
                local currentStiffness = bodyPart:getStiffness()
                local trackedStiffness = tracking.stiffness[partIndex]
                
                if trackedStiffness ~= nil then
                    local change = currentStiffness - trackedStiffness
                    if change > 0.01 then
                        local reducedAmount = change * stiffnessReduction
                        local newValue = trackedStiffness + (change - reducedAmount)
                        bodyPart:setStiffness(newValue)
                        session.stiffnessReduced = session.stiffnessReduced + reducedAmount
                        currentStiffness = newValue
                        if isDebug then
                            print(string.format("[EffectApplicator] Stiffness[%d]: %.2f -> %.2f (saved: %.2f)", 
                                partIndex, trackedStiffness, newValue, reducedAmount))
                        end
                    end
                end
                
                tracking.stiffness[partIndex] = currentStiffness
            end
        end
    end
end

--==============================================================================
-- REGENERATION EFFECTS (Additive per minute)
--==============================================================================

--- Apply regeneration effects (stiffness decay, health, XP)
---@param player IsoPlayer
function EffectApplicator.applyRegeneration(player)
    if not player or not player:isAlive() then return end
    
    local session = getSessionStats(player)
    local tracking = getPlayerTracking(player)
    
    -- Safety check: if tracking or session is nil, abort
    if not tracking or not session then
        if isDebug then
            print("[EffectApplicator] ERROR: Failed to get player tracking/session data in applyRegeneration")
        end
        return
    end
    
    -- Get regeneration values from registry
    local stiffnessDecay = EffectRegistry.get(player, "stiffness_decay", 0)
    local healthRegen = EffectRegistry.get(player, "health_regen", 0)
    local fitnessXP = EffectRegistry.get(player, "fitness_xp", 0)
    local strengthXP = EffectRegistry.get(player, "strength_xp", 0)
    
    local fitnessXPMult = EffectRegistry.get(player, "fitness_xp_multiplier", 1.0)
    local strengthXPMult = EffectRegistry.get(player, "strength_xp_multiplier", 1.0)
    
    -- Apply STIFFNESS DECAY
    if stiffnessDecay > 0 then
        local bodyDamage = player:getBodyDamage()
        if bodyDamage then
            for _, partType in ipairs(STIFFNESS_BODY_PARTS) do
                local bodyPart = bodyDamage:getBodyPart(partType)
                if bodyPart then
                    local currentStiffness = bodyPart:getStiffness()
                    if currentStiffness > 0 then
                        local decayAmount = math.min(currentStiffness, stiffnessDecay)
                        bodyPart:setStiffness(currentStiffness - decayAmount)
                        session.stiffnessDecayed = session.stiffnessDecayed + decayAmount
                    end
                end
            end
        end
    end
    
    -- Apply HEALTH REGENERATION
    if healthRegen > 0 then
        local bodyDamage = player:getBodyDamage()
        if bodyDamage then
            local health = bodyDamage:getHealth()
            if health and health < 100 then
                local newHealth = math.min(100, health + healthRegen)
                bodyDamage:setHealth(newHealth)
                session.healthRegenerated = session.healthRegenerated + (newHealth - health)
                if isDebug then
                    print(string.format("[EffectApplicator] Health regen: %.2f -> %.2f (+%.2f)", 
                        health, newHealth, healthRegen))
                end
            end
        end
    end
    
    -- Apply FITNESS XP
    if fitnessXP > 0 then
        local xp = player:getXp()
        if xp then
            local totalXP = fitnessXP * fitnessXPMult
            xp:AddXP(Perks.Fitness, totalXP * 4)  -- Game uses 0.25x modifier
            session.fitnessXPAdded = session.fitnessXPAdded + totalXP
        end
    end
    
    -- Apply STRENGTH XP
    if strengthXP > 0 then
        local xp = player:getXp()
        if xp then
            local totalXP = strengthXP * strengthXPMult
            xp:AddXP(Perks.Strength, totalXP * 4)
            session.strengthXPAdded = session.strengthXPAdded + totalXP
        end
    end
    
    -- Decay protection for Fitness/Strength
    local decayProtection = EffectRegistry.get(player, "decay_protection", 0)
    
    if decayProtection > 0 then
        local bodyLevel = player:getPerkLevel(Perks.Body)
        local fitnessLevel = player:getPerkLevel(Perks.Fitness)
        local strengthLevel = player:getPerkLevel(Perks.Strength)
        
        -- Check if Fitness decayed below protected floor
        if tracking.lastFitnessLevel ~= nil and fitnessLevel < tracking.lastFitnessLevel then
            -- Protected floor is minimum of Body level and last Fitness level
            local protectedFloor = math.min(bodyLevel, tracking.lastFitnessLevel)
            if fitnessLevel < protectedFloor then
                -- Restore XP proportional to decay protection
                -- Base restore XP scales with protection level
                local xp = player:getXp()
                if xp then
                    local restoreXP = 50 * decayProtection  -- 0-50 XP based on protection
                    xp:AddXP(Perks.Fitness, restoreXP * 4)  -- Game uses 0.25x modifier
                    if isDebug then
                        print(string.format("[EffectApplicator] Fitness decay protection triggered! Restored %.1f XP (protection: %.0f%%)", 
                            restoreXP, decayProtection * 100))
                    end
                end
            end
        end
        tracking.lastFitnessLevel = fitnessLevel
        
        -- Same for Strength
        if tracking.lastStrengthLevel ~= nil and strengthLevel < tracking.lastStrengthLevel then
            local protectedFloor = math.min(bodyLevel, tracking.lastStrengthLevel)
            if strengthLevel < protectedFloor then
                local xp = player:getXp()
                if xp then
                    local restoreXP = 50 * decayProtection
                    xp:AddXP(Perks.Strength, restoreXP * 4)
                    if isDebug then
                        print(string.format("[EffectApplicator] Strength decay protection triggered! Restored %.1f XP (protection: %.0f%%)", 
                            restoreXP, decayProtection * 100))
                    end
                end
            end
        end
        tracking.lastStrengthLevel = strengthLevel
    else
        -- No decay protection, just track levels
        local fitnessLevel = player:getPerkLevel(Perks.Fitness)
        local strengthLevel = player:getPerkLevel(Perks.Strength)
        tracking.lastFitnessLevel = fitnessLevel
        tracking.lastStrengthLevel = strengthLevel
    end
end

--==============================================================================
-- MAIN APPLICATION
--==============================================================================

--==============================================================================
-- SPECIAL EFFECTS (Applied via event hooks)
--==============================================================================
-- Note: Some effects cannot be applied in the EveryOneMinute tick
-- They need to hook into specific game events:
--
-- - attack_endurance_reduction: Hook OnWeaponSwing event
-- - zombie_attraction_reduction: Hook zombie perception updates
-- - zombie_sight_reduction: Modify zombie sight range
-- - zombie_hearing_reduction: Modify zombie hearing range
-- - body_xp_multiplier: Hook OnAddXP event
-- - metabolism_efficiency: Used by Devouring Elephant technique
-- - healing_power_multiplier: Used by healing techniques
--
-- These effects are registered in the registry and can be queried
-- by external systems, but are not applied here.
--==============================================================================

--- Get an effect value (convenience for external systems)
---@param player IsoPlayer
---@param effectName string
---@return number value
function EffectApplicator.getEffect(player, effectName)
    return EffectRegistry.get(player, effectName, 0)
end

--==============================================================================
-- MAIN APPLICATION
--==============================================================================

--- Apply all effects to a player (called every minute)
---@param player IsoPlayer
function EffectApplicator.applyAll(player)
    if not player or not player:isAlive() then return end
    
    -- Apply both reduction and regeneration effects
    EffectApplicator.applyReductions(player)
    EffectApplicator.applyRegeneration(player)
    
    local session = getSessionStats(player)
    session.effectsApplied = session.effectsApplied + 1
end

--- Print session statistics
---@param player IsoPlayer
function EffectApplicator.printStats(player)
    if not player then
        print("[EffectApplicator] ERROR: Player is nil")
        return
    end
    
    local session = getSessionStats(player)
    if not session then
        print("[EffectApplicator] ERROR: Failed to get session stats")
        return
    end
    
    local allEffects = {}
    local success, result = pcall(function() return EffectRegistry.getAll(player) end)
    if success and result then
        allEffects = result
    end
    
    print("=== [EffectApplicator] Session Stats: " .. player:getUsername() .. " ===")
    print(string.format("  Effects Applied: %d times", session.effectsApplied))
    
    -- Active multipliers
    print("  --- Active Effects ---")
    for effectName, value in pairs(allEffects) do
        if value ~= 0 then
            if value >= 0 and value <= 1 then
                print(string.format("    %s: %.1f%%", effectName, value * 100))
            else
                print(string.format("    %s: %.4f", effectName, value))
            end
        end
    end
    
    -- Cumulative benefits
    print("  --- Cumulative Benefits ---")
    print(string.format("    Hunger reduced: %.6f", session.hungerReduced))
    print(string.format("    Thirst reduced: %.6f", session.thirstReduced))
    print(string.format("    Fatigue reduced: %.6f", session.fatigueReduced))
    print(string.format("    Endurance drain reduced: %.6f", session.enduranceReduced))
    print(string.format("    Stiffness increase reduced: %.2f", session.stiffnessReduced))
    print(string.format("    Stiffness decay boosted: %.2f", session.stiffnessDecayed))
    print(string.format("    Health regenerated: %.2f", session.healthRegenerated))
    print(string.format("    Fitness XP added: %.2f", session.fitnessXPAdded))
    print(string.format("    Strength XP added: %.2f", session.strengthXPAdded))
    print("==============================================")
end

--- Reset session stats
---@param player IsoPlayer
function EffectApplicator.resetStats(player)
    local playerKey = getPlayerKey(player)
    sessionStats[playerKey] = nil
end

--==============================================================================
-- EVENT HANDLERS
--==============================================================================

local function onLoad()
    playerTracking = {}
    sessionStats = {}
    print("[EffectApplicator] Player tracking reset")
end

--- Cleanup on player disconnect/death (prevent memory leaks)
---@param player IsoPlayer
local function onPlayerDisconnect(player)
    if not player then return end
    local playerKey = getPlayerKey(player)
    if playerTracking[playerKey] then
        playerTracking[playerKey] = nil
    end
    if sessionStats[playerKey] then
        sessionStats[playerKey] = nil
    end
    if isDebug then
        print("[EffectApplicator] Cleaned up tracking for disconnected player: " .. playerKey)
    end
end

Events.OnLoad.Add(onLoad)
Events.OnPlayerDeath.Add(onPlayerDisconnect)

print("[EffectApplicator] Effect applicator initialized")

return EffectApplicator

