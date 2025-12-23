-- TechniqueEnergyStabilization.lua
-- "Energy Stabilization" (能量稳定) Technique
-- Reduces zombie attraction caused by high cultivation levels

local TechniqueRegistry = require "techniques/TechniqueRegistry"

--[[
    TECHNIQUE: Energy Stabilization (能量稳定)
    
    Description:
    At high cultivation levels, the body radiates life energy that
    attracts zombies. This technique teaches control over that energy,
    reducing the "beacon effect" of high Body levels.
    
    Tradeoff: May slow cultivation progress (suppressing energy = less absorption)
    
    Stage Progression:
    入门 (Entry): Slight awareness of own energy
    小成 (Small Achievement): Can dampen emissions in calm state
    大成 (Great Achievement): Reliable control under most conditions
    圆满 (Completeness): Near-invisible to zombies
    极境 (Ultimate): Complete energy mastery, undetectable presence
    
    Advancement:
    - Gains XP when surviving near many zombies (learning to mask energy)
    - Gains XP when endurance is low but surviving (control under pressure)
    - Gains XP when taking damage but surviving
    
    Effects (scale with stage 1-5):
    - zombieAttractionReduction: Reduces the attraction radius/strength
    - cultivationSpeedPenalty: Slightly slower Body XP gain (tradeoff)
]]

local STAGES = TechniqueRegistry.STAGES

local technique = {
    id = "energy_stabilization",
    name = "Energy Stabilization",
    description = "Control your life energy to reduce zombie attraction.",
    
    -- Requirements
    requirements = {
        minBodyLevel = 6,  -- High level requirement (advanced technique)
        item = "TechniqueManuscript_Stabilization",
    },
    
    -- Stage configuration
    maxStage = 5,
    baseXP = 180,  -- Hardest technique to advance
    
    xpPerStage = function(stage)
        -- Stage 1→2: 180 XP, Stage 4→5: 540 XP
        local multipliers = { 1.0, 1.5, 2.0, 3.0 }
        return 180 * (multipliers[stage] or 1.0)
    end,
    
    -- Leveling conditions
    levelingConditions = {
        -- Primary: Surviving with many zombies nearby
        {
            event = "OnZombieProximity",
            xpGain = function(player, data, stage)
                -- More zombies = more XP (learning under pressure)
                local baseXP = 2.5
                local zombieBonus = (data.zombieCount - 5) * 0.4
                return baseXP + math.min(zombieBonus, 4.0)
            end,
        },
        
        -- Secondary: Surviving when exhausted (control under stress)
        {
            event = "OnLowEndurance",
            xpGain = function(player, data, stage)
                return 1.5  -- Flat XP for surviving exhaustion
            end,
        },
        
        -- Tertiary: Taking damage but surviving (forced to control or die)
        {
            event = "OnPlayerDamage",
            xpGain = function(player, data, stage)
                return 1.0
            end,
        },
    },
    
    -- Effect calculation based on stage (1-5)
    getEffects = function(stage)
        if stage <= 0 then
            return {
                zombieAttractionReduction = 0,
                cultivationSpeedPenalty = 0,
            }
        end
        
        -- Get stage multiplier from registry
        local stageData = TechniqueRegistry.STAGE_DATA[stage]
        local mult = stageData and stageData.effectMultiplier or 0.20
        
        -- Stage 1: 14% attraction reduction, Stage 5: 70% reduction
        local attractionReduction = mult * 0.70
        
        -- Tradeoff: Slight cultivation slowdown (3% at stage 1, 15% at stage 5)
        -- This represents the energy being "suppressed" rather than grown
        local cultivationPenalty = mult * 0.15
        
        return {
            zombieAttractionReduction = attractionReduction,
            cultivationSpeedPenalty = cultivationPenalty,
        }
    end,
    
    onLearn = function(player)
        print("[Technique] " .. player:getUsername() .. " has begun learning Energy Stabilization")
        HaloTextHelper.addText(player, "[col=150,150,200]You begin to sense your own life energy...[/]")
    end,
    
    onStageUp = function(player, newStage)
        local stageData = TechniqueRegistry.STAGE_DATA[newStage]
        local stageName = stageData and stageData.name or tostring(newStage)
        
        if newStage == STAGES.SMALL_ACHIEVEMENT then
            HaloTextHelper.addText(player, string.format("[col=150,150,200]Energy Stabilization: %s[/]", stageName))
            HaloTextHelper.addText(player, "[col=150,150,200]The pull of the dead weakens slightly[/]")
        elseif newStage == STAGES.COMPLETENESS then
            HaloTextHelper.addText(player, string.format("[col=150,180,220]Energy Stabilization: %s[/]", stageName))
            HaloTextHelper.addText(player, "[col=150,180,220]You can now mask most of your energy[/]")
        elseif newStage == STAGES.ULTIMATE then
            HaloTextHelper.addText(player, string.format("[col=255,215,0]Energy Stabilization: %s[/]", stageName))
            HaloTextHelper.addText(player, "[col=200,200,255]The dead barely sense your presence[/]")
        else
            HaloTextHelper.addText(player, string.format("[col=150,150,200]Energy Stabilization: %s[/]", stageName))
        end
    end,
    
    -- Legacy compatibility
    onLevelUp = function(player, newLevel)
        local technique = TechniqueRegistry.get("energy_stabilization")
        if technique.onStageUp then
            technique.onStageUp(player, newLevel)
        end
    end,
}

TechniqueRegistry.register(technique)

return technique

