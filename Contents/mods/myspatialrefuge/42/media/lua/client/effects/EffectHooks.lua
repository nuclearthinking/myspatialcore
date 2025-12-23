-- EffectHooks.lua
-- Event hooks for effects that cannot be applied in EveryOneMinute
-- Handles combat, XP, and zombie perception effects

local EffectRegistry = require "effects/EffectRegistry"

local EffectHooks = {}

-- Cache debug mode
local isDebug = getDebug()

-- Recursion guard for XP multipliers (prevent infinite loops)
local isApplyingXPMultiplier = false

--==============================================================================
-- CONSTANTS
--==============================================================================

-- Attack endurance costs (estimated based on testing)
local BASE_SWING_COST = 0.5  -- Base endurance cost per weapon swing
local WEIGHT_COST_MULTIPLIER = 0.1  -- Additional cost per kg of weapon weight

-- XP multiplier limits
local MIN_XP_MULTIPLIER = 0.0  -- 100% reduction (no XP gain)
local MAX_XP_MULTIPLIER = 2.0  -- 200% XP gain (double)

--==============================================================================
-- COMBAT EFFECTS
--==============================================================================

--- Hook for reducing attack endurance cost
--- Called when player swings a weapon
local function onWeaponSwing(player, weapon)
    if not player or not player:isAlive() then return end
    
    local attackReduction = EffectRegistry.get(player, "attack_endurance_reduction", 0)
    if attackReduction <= 0 then return end
    
    -- Get current endurance
    local stats = player:getStats()
    if not stats then return end
    
    local endurance = stats:get(CharacterStat.ENDURANCE)
    
    -- Calculate the endurance cost of the swing
    -- We need to measure before/after, but this is called DURING the swing
    -- So we'll apply a bonus restoration after the fact
    
    -- Estimate swing cost based on weapon weight and player stats
    -- Note: This is an approximation. True cost depends on:
    -- - Weapon type and attack animation
    -- - Player fitness/strength
    -- - Combat moodles (panicked, exhausted, etc.)
    local swingCost = BASE_SWING_COST
    if weapon then
        swingCost = swingCost + (weapon:getWeight() * WEIGHT_COST_MULTIPLIER)
    end
    
    -- Apply reduction as immediate restoration
    local restoration = swingCost * attackReduction
    if restoration > 0.01 then
        stats:set(CharacterStat.ENDURANCE, math.min(1.0, endurance + restoration))
        
        if isDebug then
            print(string.format("[EffectHooks] Attack endurance saved: %.3f (%.1f%%)", 
                restoration, attackReduction * 100))
        end
    end
end

--==============================================================================
-- XP MULTIPLIER EFFECTS
--==============================================================================

--- Hook for Body XP multiplier
--- Called when player gains XP
local function onAddXP(player, perk, xpAmount)
    if not player or not player:isAlive() then return end
    if perk ~= Perks.Body then return end
    
    -- RECURSION GUARD: Prevent infinite loop when we call AddXP below
    if isApplyingXPMultiplier then return end
    
    local bodyXPMult = EffectRegistry.get(player, "body_xp_multiplier", 1.0)
    if bodyXPMult == 1.0 then return end
    
    -- Clamp multiplier to reasonable range
    bodyXPMult = math.max(MIN_XP_MULTIPLIER, math.min(MAX_XP_MULTIPLIER, bodyXPMult))
    
    -- Apply multiplier (negative values reduce XP)
    local bonus = xpAmount * (bodyXPMult - 1.0)
    if bonus ~= 0 then
        local xp = player:getXp()
        if xp then
            -- Set recursion guard before calling AddXP
            isApplyingXPMultiplier = true
            xp:AddXP(Perks.Body, bonus)
            isApplyingXPMultiplier = false
            
            if isDebug then
                print(string.format("[EffectHooks] Body XP multiplier: %.1f%% (%+.2f XP)", 
                    bodyXPMult * 100, bonus))
            end
        end
    end
end

--==============================================================================
-- ZOMBIE PERCEPTION EFFECTS
--==============================================================================

--- Apply zombie perception reductions
--- This modifies the player's "visibility" to zombies
--- Note: This is complex and may require deeper integration with zombie AI
local function applyZombiePerceptionEffects(player)
    if not player or not player:isAlive() then return end
    
    local attractionReduction = EffectRegistry.get(player, "zombie_attraction_reduction", 0)
    local sightReduction = EffectRegistry.get(player, "zombie_sight_reduction", 0)
    local hearingReduction = EffectRegistry.get(player, "zombie_hearing_reduction", 0)
    
    -- These effects need to modify zombie perception
    -- Project Zomboid doesn't expose easy hooks for this
    -- We'll need to use the player's "invisibility" modifiers
    
    if attractionReduction > 0 or sightReduction > 0 or hearingReduction > 0 then
        -- Combine all perception reductions
        local totalReduction = math.max(attractionReduction, sightReduction, hearingReduction)
        
        -- Apply as a temporary "stealth" bonus
        -- This is a simplified implementation - may need refinement
        local bodyDamage = player:getBodyDamage()
        if bodyDamage then
            -- Reduce the player's "visibility" stat
            -- Note: This is a placeholder - actual implementation depends on PZ API
            
            if isDebug and totalReduction > 0.1 then
                print(string.format("[EffectHooks] Zombie perception reduction: %.1f%% (A:%.0f%% S:%.0f%% H:%.0f%%)",
                    totalReduction * 100, attractionReduction * 100, 
                    sightReduction * 100, hearingReduction * 100))
            end
        end
    end
end

--- Hook called every 10 seconds to update zombie perception
local function onEveryTenMinutes()
    local numPlayers = getNumActivePlayers()
    for i = 0, numPlayers - 1 do
        local player = getSpecificPlayer(i)
        if player and player:isAlive() then
            -- OPTIMIZATION: Only apply if player has any perception effects
            local hasEffects = EffectRegistry.get(player, "zombie_attraction_reduction", 0) > 0
                            or EffectRegistry.get(player, "zombie_sight_reduction", 0) > 0
                            or EffectRegistry.get(player, "zombie_hearing_reduction", 0) > 0
            
            if hasEffects then
                applyZombiePerceptionEffects(player)
            end
        end
    end
end

--==============================================================================
-- INITIALIZATION
--==============================================================================

--- Register all event hooks
function EffectHooks.init()
    -- Combat hooks
    Events.OnWeaponSwing.Add(onWeaponSwing)
    
    -- XP hooks
    Events.AddXP.Add(onAddXP)
    
    -- Zombie perception hooks (periodic update)
    Events.EveryTenMinutes.Add(onEveryTenMinutes)
    
    print("[EffectHooks] Effect event hooks registered")
end

-- Export for external systems to query effects
EffectHooks.getEffect = function(player, effectName)
    return EffectRegistry.get(player, effectName, 0)
end

return EffectHooks

