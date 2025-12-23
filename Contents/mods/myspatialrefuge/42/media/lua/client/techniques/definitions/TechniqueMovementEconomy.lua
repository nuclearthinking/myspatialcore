-- TechniqueMovementEconomy.lua
-- "Perpetual Breath" (循环呼吸术) Technique
-- Reduces endurance drain through advanced breathing efficiency

local TechniqueRegistry = require "techniques/TechniqueRegistry"

--[[
    TECHNIQUE: Perpetual Breath
    
    Description:
    A paradoxical breathing method where inhale and exhale occur as one
    continuous cycle. The practitioner learns to extract maximum oxygen
    while expelling waste in a seamless flow, as if breathing never stops.
    Each breath becomes two, then three, multiplying efficiency with mastery.
    
    The body learns to move in harmony with this perpetual rhythm, making
    every action cost less while achieving more.
    
    Stage Progression:
    Initiate: Basic continuous breathing, slight energy savings
    Adept: Breath cycles overlap, noticeable efficiency
    Accomplished: Seamless perpetual flow, significant stamina gain
    Perfected: Each breath multiplies into several cycles
    Transcendent: Breathing becomes effortless, nearly infinite endurance
    
    Advancement Requirements (OnSustainedActivity):
    - Endurance must stay ABOVE 90% (very efficient movement)
    - Player must be physically active (moving, running, fighting)
    - NOT counted when: in vehicle, sleeping, sitting, resting, reading
    - Counter resets if any condition fails
    
    Advancement (OnZombieKill):
    - Gains XP for killing zombies in melee
    - Bonus XP for efficient multi-kills
    
    Effects (scale with stage 1-5):
    - enduranceDrainReduction: Additional % reduction on top of body level
    - stiffnessReduction: Additional % reduction on muscle strain
    - attackEnduranceReduction: Reduced stamina cost for attacks
]]

local STAGES = TechniqueRegistry.STAGES

local technique = {
    id = "movement_economy",
    name = "Perpetual Breath",
    description = "Master continuous breathing where inhale and exhale flow as one, multiplying stamina efficiency.",
    
    -- Requirements
    requirements = {
        minBodyLevel = 4,  -- Requires Body level 4 (intermediate)
        item = "TechniqueManuscript_Movement",
    },
    
    -- Stage configuration
    maxStage = 5,
    baseXP = 120,  -- Harder to advance than Absorption
    
    xpPerStage = function(stage)
        -- Stage 1→2: 120 XP, Stage 4→5: 360 XP
        local multipliers = { 1.0, 1.5, 2.0, 3.0 }
        return 120 * (multipliers[stage] or 1.0)
    end,
    
    -- Leveling conditions
    levelingConditions = {
        -- Primary: Sustained activity without exhaustion
        {
            event = "OnSustainedActivity",
            xpGain = function(player, data, stage)
                -- More XP for longer sustained activity
                local baseXP = 2.0
                local sustainedBonus = math.min(data.sustainedMinutes / 15, 3.0)
                return baseXP + sustainedBonus
            end,
        },
        
        -- Secondary: Combat practice (learning efficient attacks)
        {
            event = "OnZombieKill",
            xpGain = function(player, data, stage)
                -- XP per kill, bonus for efficient clearing
                local baseXP = 0.8
                local multiKillBonus = math.min(data.killsThisMinute / 4, 1.5)
                return baseXP + multiKillBonus
            end,
        },
        
        -- Negative: Loses potential XP when exhausted (punishes inefficiency)
        -- This is handled by NOT gaining XP from OnSustainedActivity when exhausted
    },
    
    -- Effect calculation based on stage (1-5)
    getEffects = function(stage)
        if stage <= 0 then
            return {
                enduranceDrainReduction = 0,
                stiffnessReduction = 0,
                attackEnduranceReduction = 0,
            }
        end
        
        -- Get stage multiplier from registry
        local stageData = TechniqueRegistry.STAGE_DATA[stage]
        local mult = stageData and stageData.effectMultiplier or 0.20
        
        -- Max bonus reduction at 极境: 25%
        -- This stacks with base Body cultivation effects
        local bonusReduction = mult * 0.25  -- 5% at stage 1, 25% at stage 5
        
        return {
            enduranceDrainReduction = bonusReduction,
            stiffnessReduction = bonusReduction * 0.8,  -- Slightly less for stiffness
            attackEnduranceReduction = bonusReduction * 1.2,  -- More for attacks
        }
    end,
    
    onLearn = function(player)
        print("[Technique] " .. player:getUsername() .. " has begun learning Perpetual Breath")
    end,
    
    onStageUp = function(player, newStage)
        local stageData = TechniqueRegistry.STAGE_DATA[newStage]
        local stageName = stageData and stageData.name or tostring(newStage)
        
        if newStage == STAGES.GREAT_ACHIEVEMENT then
            HaloTextHelper.addText(player, string.format("[col=180,220,255]Perpetual Breath: %s[/]", stageName))
            HaloTextHelper.addText(player, "[col=180,220,255]Your breath flows in an endless cycle[/]")
        elseif newStage == STAGES.ULTIMATE then
            HaloTextHelper.addText(player, string.format("[col=255,215,0]Perpetual Breath: %s[/]", stageName))
            HaloTextHelper.addText(player, "[col=255,215,0]Breathing becomes effortless. Stamina seems infinite.[/]")
        else
            HaloTextHelper.addText(player, string.format("[col=180,220,255]Perpetual Breath: %s[/]", stageName))
        end
    end,
    
    -- Legacy compatibility
    onLevelUp = function(player, newLevel)
        local technique = TechniqueRegistry.get("movement_economy")
        if technique.onStageUp then
            technique.onStageUp(player, newLevel)
        end
    end,
}

TechniqueRegistry.register(technique)

return technique

