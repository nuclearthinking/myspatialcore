-- TechniqueEffectProvider.lua
-- Effect provider for Technique system
-- Registers technique-based effects to the unified effect system

local EffectProvider = require "effects/EffectProvider"
local TechniqueManager = require "techniques/TechniqueManager"
local TechniqueRegistry = require "techniques/TechniqueRegistry"

local TechniqueEffectProvider = {}

-- Cache debug mode
local isDebug = getDebug()

--==============================================================================
-- TECHNIQUE EFFECT MAPPING
--==============================================================================

--- Convert technique effects to unified effect system format
--- Techniques can provide their own effect mappings
---@param technique table Technique definition
---@param stage number Current stage
---@param player IsoPlayer
---@return table effects Array of effect definitions
local function mapTechniqueEffects(technique, stage, player)
    local effects = {}
    
    if not technique or not technique.getEffects then
        return effects
    end
    
    -- Get technique's effect data
    local techniqueEffects = technique.getEffects(stage)
    
    if not techniqueEffects then
        return effects
    end
    
    -- Map technique-specific effects to unified system
    -- Each technique can define its own effect contributions
    
    -- Example: Camel's Hump provides complex metabolism healing
    if technique.id == "camels_hump" then
        -- This technique provides effects through its applyEffect function
        -- We don't duplicate them in the unified system
        -- Instead, the technique's applyEffect is called separately
        -- (This maintains backward compatibility)
        
        -- However, we can register passive effects here if needed
        -- For now, let technique handle its own complex logic
        return effects
    end
    
    -- Perpetual Breath: Endurance and stiffness reductions
    if technique.id == "movement_economy" then
        if techniqueEffects.enduranceDrainReduction then
            table.insert(effects, {
                name = "endurance_reduction",
                value = techniqueEffects.enduranceDrainReduction,
                metadata = {technique = technique.id, stage = stage},
                priority = 5,
            })
        end
        
        if techniqueEffects.stiffnessReduction then
            table.insert(effects, {
                name = "stiffness_reduction",
                value = techniqueEffects.stiffnessReduction,
                metadata = {technique = technique.id, stage = stage},
                priority = 5,
            })
        end
        
        if techniqueEffects.attackEnduranceReduction then
            table.insert(effects, {
                name = "attack_endurance_reduction",
                value = techniqueEffects.attackEnduranceReduction,
                metadata = {technique = technique.id, stage = stage},
                priority = 5,
            })
        end
    end
    
    -- Energy Stabilization: Zombie perception and cultivation penalty
    if technique.id == "energy_stabilization" then
        if techniqueEffects.zombieAttractionReduction then
            table.insert(effects, {
                name = "zombie_attraction_reduction",
                value = techniqueEffects.zombieAttractionReduction,
                metadata = {technique = technique.id, stage = stage},
                priority = 5,
            })
        end
        
        if techniqueEffects.cultivationSpeedPenalty then
            -- Convert penalty to multiplier (e.g., 15% penalty = 0.85x multiplier)
            local multiplier = 1.0 - techniqueEffects.cultivationSpeedPenalty
            table.insert(effects, {
                name = "body_xp_multiplier",
                value = multiplier,
                metadata = {technique = technique.id, stage = stage, penalty = techniqueEffects.cultivationSpeedPenalty},
                priority = 5,
            })
        end
    end
    
    -- Camel's Hump: Metabolism and healing effects
    -- Note: Camel's Hump uses its own applyMetabolism function for wound healing
    -- But we register HP regen and stiffness decay through unified system for stacking
    if technique.id == "camels_hump" then
        local bodyLevel = player:getPerkLevel(Perks.Body) or 0
        local bodyBonus = 1.0 + (bodyLevel * 0.05)  -- Up to 50% bonus at level 10
        
        if techniqueEffects.efficiency then
            table.insert(effects, {
                name = "metabolism_efficiency",
                value = techniqueEffects.efficiency,
                metadata = {technique = technique.id, stage = stage},
                priority = 5,
            })
        end
        
        -- Register actual HP regen value (stage 2+) instead of just boolean
        -- This allows stacking with Body Cultivation's health_regen
        if techniqueEffects.hpRegenEnabled and techniqueEffects.hpRegen then
            table.insert(effects, {
                name = "health_regen",
                value = techniqueEffects.hpRegen * bodyBonus,
                metadata = {technique = technique.id, stage = stage},
                priority = 5,
            })
        end
        
        -- Register actual stiffness decay value instead of handling in applyMetabolism
        -- This allows stacking with Body Cultivation's stiffness_decay
        if techniqueEffects.stiffnessHealing and techniqueEffects.efficiency then
            table.insert(effects, {
                name = "stiffness_decay",
                value = techniqueEffects.stiffnessHealing * bodyBonus * techniqueEffects.efficiency,
                metadata = {technique = technique.id, stage = stage},
                priority = 5,
            })
        end
        
        -- Register weight conversion as enabled if stage >= 3
        if techniqueEffects.weightConversionEnabled then
            table.insert(effects, {
                name = "weight_conversion",
                value = true,
                metadata = {technique = technique.id, stage = stage},
                priority = 5,
            })
        end
    end
    
    return effects
end

--==============================================================================
-- TECHNIQUE PROVIDER
--==============================================================================

--- Create a provider for a specific technique
---@param techniqueId string
---@return table provider
function TechniqueEffectProvider.createForTechnique(techniqueId)
    local technique = TechniqueRegistry.get(techniqueId)
    if not technique then
        error("[TechniqueEffectProvider] Unknown technique: " .. techniqueId)
    end
    
    return EffectProvider.create({
        sourceName = "Technique_" .. techniqueId,
        priority = 5,  -- Medium priority (techniques modify base effects)
        
        shouldApply = function(player)
            return TechniqueManager.hasLearned(player, techniqueId)
        end,
        
        calculateEffects = function(player)
            local stage = TechniqueManager.getStage(player, techniqueId)
            if stage <= 0 then return {} end
            
            return mapTechniqueEffects(technique, stage, player)
        end,
    })
end

--- Create providers for all learned techniques
---@param player IsoPlayer
---@return table providers Array of provider instances
function TechniqueEffectProvider.createForPlayer(player)
    local providers = {}
    local learnedTechniques = TechniqueManager.getLearnedTechniques(player)
    
    for _, techData in ipairs(learnedTechniques) do
        if techData.id and techData.stage > 0 then
            local provider = TechniqueEffectProvider.createForTechnique(techData.id)
            table.insert(providers, provider)
        end
    end
    
    return providers
end

--==============================================================================
-- UNIFIED TECHNIQUE PROVIDER (All techniques)
--==============================================================================

local UnifiedTechniqueProvider = EffectProvider.create({
    sourceName = "TechniqueSystem",
    priority = 5,
    
    shouldApply = function(player)
        local learned = TechniqueManager.getLearnedTechniques(player)
        return #learned > 0
    end,
    
    calculateEffects = function(player)
        local allEffects = {}
        local learnedTechniques = TechniqueManager.getLearnedTechniques(player)
        
        for _, techData in ipairs(learnedTechniques) do
            if techData.technique and techData.stage > 0 then
                local techniqueEffects = mapTechniqueEffects(techData.technique, techData.stage, player)
                
                -- Merge into allEffects
                for _, effect in ipairs(techniqueEffects) do
                    table.insert(allEffects, effect)
                end
            end
        end
        
        if isDebug and #allEffects > 0 then
            print(string.format("[TechniqueEffectProvider] Registered %d technique effects for %s",
                #allEffects, player:getUsername()))
        end
        
        return allEffects
    end,
})

-- Export the unified provider
TechniqueEffectProvider.provider = UnifiedTechniqueProvider

return TechniqueEffectProvider

