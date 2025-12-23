-- TechniqueCamelsHump.lua
-- "Camel's Hump Technique" (驼峰蓄能术 / Техника Горба Верблюда)
-- Store reserves like a camel, burn fat for survival healing when needed

local TechniqueRegistry = require "techniques/TechniqueRegistry"

--[[
    TECHNIQUE: Camel's Hump Technique (驼峰蓄能术)
    Chinese: 驼峰蓄能术 (Tuófēng Xùnéng Shù) - "Art of the Camel's Reserve Storage"
    Russian: Техника Горба Верблюда
    Requires: Body Level 2
    
    DESIGN PHILOSOPHY:
    "Desert survival wisdom - the desperate fool burns everything in the first crisis
     and becomes bones in the sand. The wise camel knows when the well runs dry."
    
    A forbidden technique that grants immediate power at the cost of control.
    Novices can access weight conversion from Stage 1 but lack the wisdom to stop,
    routinely burning themselves to skeletal husks. Only masters learn restraint.
    
    CORE MECHANICS:
    
    1. CALORIE HEALING (Primary, Stage 1+)
       - Burns stored calories to heal:
         * Wounds (scratches, cuts, bleeding, bites, burns, fractures)
         * Body part damage (limb/torso health)
         * Severe muscle strain (stiffness ≥5.0)
         * Endurance deficit (≥5% missing)
         * Infections (Stage 5 ONLY - Desert King's mastery)
       - Can push calories negative (into reserves) to prioritize healing
       - Negative calorie floors: -100 to -1500 based on stage
       - Activates automatically when wounded (no manual trigger needed)
    
    2. WEIGHT CONVERSION (Emergency, Stage 1+)
       - Burns body fat into calories when calorie reserves depleted
       - Conversion rate: 1 kg = 7,700 calories (realistic metabolic value)
       - Max burn per tick: 0.07-0.11 kg (stage-dependent, prevents instant death)
       - DANGER: Minimum weight INCREASES with mastery (novices burn recklessly!)
       
    3. STAGE-BASED LIMITS (The Wisdom Progression)
       Stage 1: 50.5kg min - SUICIDAL (30kg into Very Underweight trait)
       Stage 2: 55.5kg min - RECKLESS (25kg into Very Underweight)
       Stage 3: 60.5kg min - DANGEROUS (20kg into Very Underweight)
       Stage 4: 65.5kg min - RISKY (15kg into Very Underweight)
       Stage 5: 70.5kg min - CONTROLLED (5kg into Very Underweight)
       
       Intent: Masters have discipline to stop before death. Novices don't.
       Game balance: 80kg = Underweight, 75kg = Very Underweight (-2 STR, -20% dmg)
    
    4. HEALING POWER SCALING
       - Wound healing: 0.02 → 0.25 per tick (12.5x increase, costs calories)
       - Body part healing: Scales with stage (costs calories)
       - Stiffness: 5.0 → 50.0 per tick (10x increase, costs calories for severe strain)
         * Also gets FREE passive decay from unified effect system (stackable!)
       - Endurance regen: 2% → 10% max per tick (5x increase, costs calories)
       - HP regen: 0.15 → 1.2 per minute (8x increase, Stage 2+, FREE passive)
       - Infection: Stage 5 ONLY (master's ultimate ability, costs calories)
       - All healing scales with Body level (+5% per level, up to +50%)
    
    5. XP SYSTEM (Learn by Using)
       - Calorie healing: Stage-dependent (fast at Stage 1, negligible at Stage 5)
         * Stage 1: 0.025 XP per calorie (80 XP in ~5 days normal play)
         * Stage 5: 0.002 XP per calorie (masters don't learn from basics)
       - Weight burning: 2-4 XP per kg (risk multiplier near minimum)
         * Safe distance: 2.0 XP per kg
         * <5kg from min: 3.0 XP per kg (1.5x multiplier)
         * <2kg from min: 4.0 XP per kg (2.0x multiplier - desperation teaches fast!)
       
       Intent: Novices learn quickly through normal healing. Masters must take risks.
    
    IMPLEMENTATION NOTES:
    - Three-phase processing: Assess needs → Heal → Consume energy
    - Single-pass body scan (performance optimization)
    - Early exits at each checkpoint (no healing → no energy consumption → no XP)
    - HP regen: Passive via unified effect system (free, stackable)
    - Stiffness: HYBRID approach (free passive decay + paid active healing for severe cases)
    - This function handles: wounds, body parts, infection (Stage 5), stiffness, endurance
    - Integrated with EffectRegistry for metabolism_efficiency multiplier support
]]

local STAGES = TechniqueRegistry.STAGES

--==============================================================================
-- METABOLISM CONSTANTS & HELPERS
--==============================================================================

-- Project Zomboid weight trait thresholds
local UNDERWEIGHT_THRESHOLD = 80        -- -1 STR, -10% melee damage
local VERY_UNDERWEIGHT_THRESHOLD = 75   -- -2 STR, -20% melee damage
local SAFETY_BUFFER = 0.5               -- Prevents trait flickering at boundaries

-- THE WISDOM PROGRESSION: Minimum weights by stage
-- Design: Lower stages lack self-control, higher stages have discipline
-- Result: Novices can accidentally kill themselves, masters know limits
local MIN_SAFE_WEIGHT_BY_STAGE = {
    [1] = 50.0,  -- Novice: No control, burns to near-death
    [2] = 55.0,  -- Learning: Still very dangerous
    [3] = 60.0,  -- Improving: Dangerous but survivable
    [4] = 65.0,  -- Advanced: Learning restraint
    [5] = 70.0,  -- Master: True discipline (still risky!)
}

-- Metabolic conversion rates
local CALORIES_PER_KG = 7700            -- Realistic: 1kg body fat = 7,700 calories
local WEIGHT_CONVERSION_STAGE = 1       -- Available immediately (dangerous!)

-- No artificial calorie floor - use game's natural -2200 limit
-- Weight floor is the real safety mechanism (prevents malnourished death)
local GAME_CALORIE_FLOOR = -2200  -- Game's hardcoded limit in Nutrition.java

--- Get minimum safe weight for a stage (includes safety buffer to prevent trait flickering)
local function getMinSafeWeight(stage)
    local baseWeight = MIN_SAFE_WEIGHT_BY_STAGE[stage] or MIN_SAFE_WEIGHT_BY_STAGE[1]
    return baseWeight + SAFETY_BUFFER
end

-- Healing activation thresholds (must exceed to trigger)
local MIN_WOUNDS_TO_HEAL = 0.1      -- Min wound damage to activate healing
local MIN_BODYPART_DAMAGE = 3.0     -- Min body part health loss to heal
local MIN_STIFFNESS_TO_HEAL = 5.0   -- Min muscle strain to consume calories for healing
local MIN_ENDURANCE_MISSING = 0.05  -- Min endurance deficit (5% missing) to heal

-- Healing power per stage (scales dramatically with mastery)
-- Format: { wound, stiffness, hp, endurance, calories, efficiency }
-- Note: HP regen delegated to unified effect system (passive, free)
-- Note: Stiffness gets BOTH passive decay (free) AND active healing (costs calories for severe strain)
-- Note: Endurance regeneration costs calories (rapid recovery for combat readiness)
local HEALING_POWER = {
    [1] = { wound = 0.02,  stiffness = 5.0,   hp = 0.15,  endurance = 0.02,  calories = 50,  efficiency = 0.5 },
    [2] = { wound = 0.04,  stiffness = 10.0,  hp = 0.30,  endurance = 0.04,  calories = 100, efficiency = 0.65 },
    [3] = { wound = 0.08,  stiffness = 18.0,  hp = 0.50,  endurance = 0.06,  calories = 180, efficiency = 0.8 },
    [4] = { wound = 0.15,  stiffness = 30.0,  hp = 0.80,  endurance = 0.08,  calories = 280, efficiency = 0.9 },
    [5] = { wound = 0.25,  stiffness = 50.0,  hp = 1.20,  endurance = 0.10,  calories = 400, efficiency = 1.0 },
}
-- Stage 5 is 12.5x more powerful than Stage 1 for wound healing!
-- Endurance: Stage 5 regenerates 0.10 (10% max endurance) per tick vs Stage 1's 0.02 (2%)

-- Wound type definitions (data-driven for maintainability)
-- Multipliers affect healing speed (2.0 = faster, 0.1 = slower)
-- Priority unused but kept for potential future triage logic
local WOUND_TYPES = {
    { name = "scratch",   getter = "getScratchTime",   setter = "setScratchTime",   mult = 1.0,  priority = 2 },
    { name = "deepWound", getter = "getDeepWoundTime", setter = "setDeepWoundTime", mult = 0.5,  priority = 3 },
    { name = "bleeding",  getter = "getBleedingTime",  setter = "setBleedingTime",  mult = 2.0,  priority = 1 },
    { name = "cut",       getter = "getCutTime",       setter = "setCutTime",       mult = 0.8,  priority = 2 },
    { name = "bite",      getter = "getBiteTime",      setter = "setBiteTime",      mult = 0.3,  priority = 4 },
    { name = "stitch",    getter = "getStitchTime",    setter = "setStitchTime",    mult = 0.6,  priority = 2 },
    { name = "burn",      getter = "getBurnTime",      setter = "setBurnTime",      mult = 0.2,  priority = 5 },
    { name = "fracture",  getter = "getFractureTime",  setter = "setFractureTime",  mult = 0.1,  priority = 6 },
}

-- All body parts that can receive wound damage
local WOUND_BODY_PARTS = {
    BodyPartType.Hand_L, BodyPartType.Hand_R,
    BodyPartType.ForeArm_L, BodyPartType.ForeArm_R,
    BodyPartType.UpperArm_L, BodyPartType.UpperArm_R,
    BodyPartType.Torso_Upper, BodyPartType.Torso_Lower,
    BodyPartType.Groin,
    BodyPartType.UpperLeg_L, BodyPartType.UpperLeg_R,
    BodyPartType.LowerLeg_L, BodyPartType.LowerLeg_R,
    BodyPartType.Foot_L, BodyPartType.Foot_R,
    BodyPartType.Head, BodyPartType.Neck,
}

-- Cache debug mode
local isDebug = getDebug()

--==============================================================================
-- HEALING CALCULATION HELPERS
--==============================================================================

--- Calculate healing power for current stage with Body cultivation bonus
--- @param stage number Current technique stage (1-5)
--- @param bodyLevel number Body cultivation level (0-10)
--- @return table Healing power values scaled by stage and Body level
local function getHealingPower(stage, bodyLevel)
    local base = HEALING_POWER[stage] or HEALING_POWER[1]
    local bodyBonus = 1.0 + (bodyLevel * 0.05)  -- +5% per Body level, max +50% at level 10
    
    return {
        wound = base.wound * bodyBonus,
        stiffness = base.stiffness * bodyBonus,
        hp = base.hp * bodyBonus,
        endurance = base.endurance * bodyBonus,
        calories = base.calories,           -- Not affected by Body level
        efficiency = base.efficiency,        -- Not affected by Body level
    }
end

--- Calculate emergency weight-to-calorie conversion
--- DANGER: Lower stages can burn to near-death (50kg)! Higher stages stop sooner.
--- @param nutrition Nutrition Player's nutrition object
--- @param stage number Technique stage (1-5, determines minimum safe weight)
--- @param neededCalories number Calorie deficit to fill
--- @return number caloriesFromWeight Calories that will be obtained
--- @return number weightToConvert Weight (kg) that will be burned
local function calculateWeightConversion(nutrition, stage, neededCalories)
    if stage < WEIGHT_CONVERSION_STAGE then
        return 0, 0  -- Weight conversion not unlocked
    end
    
    local currentWeight = nutrition:getWeight()
    local minSafeWeight = getMinSafeWeight(stage)  -- Stage-dependent minimum!
    
    if currentWeight <= minSafeWeight then
        return 0, 0  -- Already at minimum safe weight for this stage
    end
    
    local availableWeight = currentWeight - minSafeWeight
    
    -- Limit burn rate per tick (prevents instant death)
    -- Note: Even 0.05 kg = 385 calories due to high conversion rate
    local stageMultiplier = (stage - 1) * 0.015  -- Increases with stage
    local maxConversionPerTick = 0.05 + stageMultiplier  -- 0.05-0.11 kg per tick (385-850 cal)
    
    local weightToConvert = math.min(neededCalories / CALORIES_PER_KG, maxConversionPerTick, availableWeight)
    local caloriesFromWeight = weightToConvert * CALORIES_PER_KG
    
    return caloriesFromWeight, weightToConvert
end

--- Heal a single wound type on a body part
--- @return number healAmount How much was healed
local function healWound(bodyPart, woundType, woundHealPower)
    local currentTime = bodyPart[woundType.getter](bodyPart)
    if currentTime <= 0 then
        return 0
    end
    
    local healAmount = math.min(currentTime, woundHealPower * woundType.mult)
    bodyPart[woundType.setter](bodyPart, currentTime - healAmount)
    return healAmount
end

--- Heal wound infection on a body part
--- @return number healAmount How much was healed
local function healInfection(bodyPart, woundHealPower)
    if not bodyPart:isInfectedWound() then
        return 0
    end
    
    local infectionLevel = bodyPart:getWoundInfectionLevel()
    if infectionLevel <= 0 then
        return 0
    end
    
    -- Reduce infection level (negative values cure infection)
    local healAmount = math.min(infectionLevel + 2.0, woundHealPower * 0.1)
    local newLevel = infectionLevel - healAmount
    bodyPart:setWoundInfectionLevel(newLevel)
    
    -- If infection level goes below 0, the wound is cured
    if newLevel < 0 then
        bodyPart:setInfectedWound(false)
        if isDebug then
                    print("[Camel's Hump] WOUND INFECTION CURED!")
        end
    end
    
    return healAmount
end

--==============================================================================
-- MAIN METABOLISM FUNCTION
--==============================================================================

--- Apply Camel's Hump metabolism healing
--- Three-phase processing: Assess needs → Heal wounds → Consume energy
--- Performance: Single pass over body parts, early exits at each checkpoint
--- Integration: Dispatches XP events, queries metabolism_efficiency from EffectRegistry
--- @param player IsoPlayer The player character
--- @param stage number Current technique stage (1-5)
--- @return table stats Healing statistics (caloriesConsumed, weightConverted, woundsHealed, etc.)
local function applyMetabolism(player, stage)
    local stats = { 
        caloriesConsumed = 0, 
        weightConverted = 0,
        woundsHealed = 0, 
        bodyPartsHealed = 0,
        infectionHealed = 0,
        stiffnessHealed = 0,
        enduranceRestored = 0
    }
    
    -- Early exits for invalid state
    if not player or not player:isAlive() or stage <= 0 then
        return stats
    end
    
    local nutrition = player:getNutrition()
    local bodyDamage = player:getBodyDamage()
    if not nutrition or not bodyDamage then 
        return stats 
    end
    
    -- Load effect registry to get metabolism efficiency multiplier
    local EffectRegistry = require "effects/EffectRegistry"
    
    -- Cache frequently accessed values
    local bodyLevel = player:getPerkLevel(Perks.Body) or 0
    local currentCalories = nutrition:getCalories()
    local currentWeight = nutrition:getWeight()
    local power = getHealingPower(stage, bodyLevel)
    
    -- Get metabolism efficiency from unified effect system (allows stacking from equipment/buffs)
    local metabolismEfficiency = EffectRegistry.get(player, "metabolism_efficiency", 1.0)
    
    -- ========================================
    -- PHASE 1: Assess Healing Needs
    -- ========================================
    -- Single pass over all body parts to determine what needs healing
    -- HP regen: Handled by unified effect system (passive, free)
    -- Stiffness decay: Gets BOTH passive free decay AND active calorie-burning for severe strain
    -- This function actively heals: wounds, body part damage, infections (Stage 5), stiffness, endurance
    local totalWoundsToHeal = 0
    local totalBodyPartDamage = 0
    local totalInfectionLevel = 0
    local totalStiffness = 0
    
    -- Single pass assessment
    for _, partType in ipairs(WOUND_BODY_PARTS) do
        local bodyPart = bodyDamage:getBodyPart(partType)
        if bodyPart then
            -- Check all wound types
            for _, woundType in ipairs(WOUND_TYPES) do
                totalWoundsToHeal = totalWoundsToHeal + bodyPart[woundType.getter](bodyPart)
            end
            
            -- Wound infection healing (ONLY STAGE 5 - Desert King's mastery!)
            if stage >= 5 and bodyPart:isInfectedWound() then
                local infectionLevel = bodyPart:getWoundInfectionLevel()
                if infectionLevel > 0 then
                    totalInfectionLevel = totalInfectionLevel + infectionLevel
                end
            end
            
            -- Body part health damage
            local partHealth = bodyPart:getHealth()
            if partHealth < 100 then
                totalBodyPartDamage = totalBodyPartDamage + (100 - partHealth)
            end
            
            -- Muscle strain (stiffness) - active healing for severe cases
            local stiffness = bodyPart:getStiffness()
            if stiffness > 0 then
                totalStiffness = totalStiffness + stiffness
            end
        end
    end
    
    -- Check endurance deficit
    local playerStats = player:getStats()
    local currentEndurance = playerStats:get(CharacterStat.ENDURANCE) or 0
    local maxEndurance = 1.0  -- Endurance max is always 1.0 in PZ
    local enduranceMissing = maxEndurance - currentEndurance
    local enduranceDeficit = enduranceMissing / maxEndurance  -- 0.0 to 1.0
    
    -- Check thresholds
    local hasEnoughWounds = totalWoundsToHeal >= MIN_WOUNDS_TO_HEAL
    local hasBodyPartDamage = totalBodyPartDamage >= MIN_BODYPART_DAMAGE
    local hasWoundInfection = (stage >= 5) and (totalInfectionLevel > 0)  -- Master-only ability
    local hasSevereStiffness = totalStiffness >= MIN_STIFFNESS_TO_HEAL
    local needsEndurance = enduranceDeficit >= MIN_ENDURANCE_MISSING
    
    -- Early exit if no healing needed
    if not (hasEnoughWounds or hasBodyPartDamage or hasWoundInfection or hasSevereStiffness or needsEndurance) then
        if isDebug then
            print(string.format("[Camel's Hump] No healing needed (W:%.1f P:%.1f I:%.1f S:%.1f E:%.2f)",
                totalWoundsToHeal, totalBodyPartDamage, totalInfectionLevel, totalStiffness, enduranceDeficit))
        end
        return stats
    end
    
    -- Calculate available energy (no artificial floor - weight is the real limiter)
    local caloriesNeeded = power.calories
    
    -- Try weight conversion if calories are insufficient (Stage 1+)
    local caloriesFromWeight, weightToConvert = 0, 0
    if currentCalories < caloriesNeeded and stage >= WEIGHT_CONVERSION_STAGE then
        local deficit = caloriesNeeded - currentCalories
        caloriesFromWeight, weightToConvert = calculateWeightConversion(nutrition, stage, deficit)
    end
    
    local totalAvailableCalories = currentCalories + caloriesFromWeight
    
    -- Early exit if no energy (happens when both calories AND weight are depleted)
    if totalAvailableCalories <= 0 then
        if isDebug then
            print(string.format("[Camel's Hump] No energy (cal:%.0f wt:%.1fkg < min:%.1fkg)",
                currentCalories, currentWeight, getMinSafeWeight(stage)))
        end
        return stats
    end
    
    -- Calculate efficiency based on available energy
    local caloriesToUse = math.min(totalAvailableCalories, caloriesNeeded)
    local efficiency = (caloriesToUse / caloriesNeeded) * power.efficiency
    
    -- Pre-calculate healing powers with metabolism efficiency multiplier
    -- This allows equipment/buffs to modify technique's healing power
    local woundHealPower = power.wound * efficiency * metabolismEfficiency
    local bodyPartHealPower = power.hp * efficiency * metabolismEfficiency * 0.8
    local stiffnessHealPower = power.stiffness * efficiency * metabolismEfficiency
    local enduranceHealPower = power.endurance * efficiency * metabolismEfficiency
    
    if isDebug then
        local minSafeWeight = getMinSafeWeight(stage)
        local weightAboveMin = currentWeight - minSafeWeight
        print(string.format("[Camel's Hump] Stage %d | Cal:%.0f Wt:%.1f (%.1fkg above min) | Eff:%.0f%% MetaMult:%.0f%% | Power: W:%.3f",
            stage, currentCalories, currentWeight, weightAboveMin, efficiency * 100, metabolismEfficiency * 100, woundHealPower))
    end
    
    -- ========================================
    -- PHASE 2: Apply Healing
    -- ========================================
    -- Apply calculated healing to wounds, body parts, infections, stiffness, endurance
    -- Single pass optimization: All healing done in one iteration
    local totalWoundsHealed = 0
    local totalBodyPartHealed = 0
    local totalInfectionHealed = 0
    local totalStiffnessHealed = 0
    
    for _, partType in ipairs(WOUND_BODY_PARTS) do
        local bodyPart = bodyDamage:getBodyPart(partType)
        if bodyPart then
            -- Heal all wound types (data-driven!)
            if hasEnoughWounds then
                for _, woundType in ipairs(WOUND_TYPES) do
                    totalWoundsHealed = totalWoundsHealed + healWound(bodyPart, woundType, woundHealPower)
                end
            end
            
            -- Heal wound infection (ONLY STAGE 5+)
            if hasWoundInfection then
                totalInfectionHealed = totalInfectionHealed + healInfection(bodyPart, woundHealPower)
            end
            
            -- Heal body part health directly (works for bandaged wounds!)
            if hasBodyPartDamage then
                local partHealth = bodyPart:getHealth()
                if partHealth < 100 then
                    local healAmount = math.min(100 - partHealth, bodyPartHealPower)
                    bodyPart:AddHealth(healAmount)
                    totalBodyPartHealed = totalBodyPartHealed + healAmount
                end
            end
            
            -- Heal severe muscle strain (stiffness) - burns calories for rapid recovery
            -- Note: Also gets free passive decay from unified effect system
            if hasSevereStiffness then
                local currentStiffness = bodyPart:getStiffness()
                if currentStiffness > 0 then
                    local healAmount = math.min(currentStiffness, stiffnessHealPower)
                    bodyPart:setStiffness(currentStiffness - healAmount)
                    totalStiffnessHealed = totalStiffnessHealed + healAmount
                end
            end
        end
    end
    
    -- Heal endurance - rapid recovery for combat readiness
    local totalEnduranceRestored = 0
    if needsEndurance then
        local playerStats = player:getStats()
        local currentEndurance = playerStats:get(CharacterStat.ENDURANCE) or 0
        local maxEndurance = 1.0  -- Endurance max is always 1.0 in PZ
        local restoreAmount = math.min(maxEndurance - currentEndurance, enduranceHealPower * maxEndurance)
        if restoreAmount > 0 then
            playerStats:set(CharacterStat.ENDURANCE, math.min(1.0, currentEndurance + restoreAmount))
            totalEnduranceRestored = restoreAmount
        end
    end
    
    -- ========================================
    -- PHASE 3: Consume Energy & Dispatch XP
    -- ========================================
    -- Calculate healing ratio, consume calories/weight, trigger XP events
    local somethingHealed = totalWoundsHealed > 0 or totalBodyPartHealed > 0 or totalInfectionHealed > 0 
                            or totalStiffnessHealed > 0 or totalEnduranceRestored > 0
    
    if not somethingHealed then
        return stats
    end
    
    -- Calculate healing ratio for energy consumption
    local healingRatio = 0
    local activeTypes = 0
    
    -- Table-driven approach for cleaner code
    local healingChecks = {
        { condition = hasEnoughWounds,    healed = totalWoundsHealed,     total = totalWoundsToHeal },
        { condition = hasBodyPartDamage,  healed = totalBodyPartHealed,   total = totalBodyPartDamage },
        { condition = hasWoundInfection,  healed = totalInfectionHealed,  total = totalInfectionLevel },
        { condition = hasSevereStiffness, healed = totalStiffnessHealed,  total = totalStiffness },
        { condition = needsEndurance,     healed = totalEnduranceRestored, total = enduranceMissing },
    }
    
    for _, check in ipairs(healingChecks) do
        if check.condition and check.healed > 0 then
            healingRatio = healingRatio + math.min(1, check.healed / math.max(check.total, 0.001))
            activeTypes = activeTypes + 1
        end
    end
    
    if activeTypes > 0 then
        healingRatio = healingRatio / activeTypes
    end
    
    -- Consume calories proportionally (minimum 20% even if partial healing)
    local actualCaloriesConsumed = caloriesToUse * math.max(0.2, healingRatio)
    
    -- First try to consume from calories directly (can go negative down to -2200)
    local caloriesFromPool = math.min(actualCaloriesConsumed, currentCalories - GAME_CALORIE_FLOOR)
    local remainingToConsume = actualCaloriesConsumed - caloriesFromPool
    
    -- Then burn weight if calories can't cover it
    local actualWeightConverted = 0
    if remainingToConsume > 0 and weightToConvert > 0 then
        actualWeightConverted = math.min(remainingToConsume / CALORIES_PER_KG, weightToConvert)
        nutrition:setWeight(currentWeight - actualWeightConverted)
        
        if isDebug and actualWeightConverted > 0.01 then
            local newWeight = currentWeight - actualWeightConverted
            local minSafeWeight = getMinSafeWeight(stage)
            local warningText = ""
            if newWeight < UNDERWEIGHT_THRESHOLD then
                if newWeight < VERY_UNDERWEIGHT_THRESHOLD then
                    warningText = " [VERY UNDERWEIGHT!]"
                else
                    warningText = " [UNDERWEIGHT!]"
                end
            elseif newWeight < minSafeWeight + 2.0 then
                warningText = " [WARNING: Approaching minimum!]"
            end
            print(string.format("[Camel's Hump] WEIGHT BURN: -%.2fkg = %.0f cal (%.1f→%.1fkg)%s",
                actualWeightConverted, actualWeightConverted * CALORIES_PER_KG, 
                currentWeight, newWeight, warningText))
        end
    end
    
    -- Apply calorie consumption (can go negative down to game's -2200 limit)
    nutrition:setCalories(currentCalories - caloriesFromPool)
    
    -- Update stats
    stats.caloriesConsumed = caloriesFromPool + (actualWeightConverted * CALORIES_PER_KG)
    stats.weightConverted = actualWeightConverted
    stats.woundsHealed = totalWoundsHealed
    stats.bodyPartsHealed = totalBodyPartHealed
    stats.infectionHealed = totalInfectionHealed
    stats.stiffnessHealed = totalStiffnessHealed
    stats.enduranceRestored = totalEnduranceRestored
    
    -- XP Event Dispatch: Learn by using the technique
    local TechniqueManager = require "techniques/TechniqueManager"
    
    -- Calorie consumption: Stage-dependent XP (fast at Stage 1, slow at Stage 5)
    if caloriesFromPool > 0 then
        TechniqueManager.processEvent(player, "OnMetabolismHealing", {
            caloriesUsed = caloriesFromPool,
            healingDone = totalWoundsHealed + totalBodyPartHealed + totalStiffnessHealed + totalEnduranceRestored,
        })
    end
    
    -- Weight burning: Moderate XP with risk multiplier (desperation teaches faster)
    if actualWeightConverted > 0 then
        TechniqueManager.processEvent(player, "OnWeightBurn", {
            weightBurned = actualWeightConverted,
            currentWeight = nutrition:getWeight(),
        })
    end
    
    if isDebug then
        -- Use table.concat for efficient string building
        local debugParts = {
            string.format("Consumed %.0f cal", stats.caloriesConsumed),
            totalWoundsHealed > 0 and string.format("W:%.2f", totalWoundsHealed) or nil,
            totalBodyPartHealed > 0 and string.format("P:%.1f", totalBodyPartHealed) or nil,
            totalInfectionHealed > 0 and string.format("Inf:%.2f", totalInfectionHealed) or nil,
            totalStiffnessHealed > 0 and string.format("S:%.1f", totalStiffnessHealed) or nil,
            totalEnduranceRestored > 0 and string.format("End:%.2f", totalEnduranceRestored) or nil,
            actualWeightConverted > 0.001 and string.format("Wt:-%.2fkg", actualWeightConverted) or nil,
        }
        
        -- Filter out nils
        local filteredParts = {}
        for _, part in ipairs(debugParts) do
            if part then
                table.insert(filteredParts, part)
            end
        end
        
        print("[Camel's Hump] " .. table.concat(filteredParts, " | "))
    end
    
    return stats
end

--==============================================================================
-- TECHNIQUE DEFINITION
--==============================================================================

local technique = {
    id = "camels_hump",
    name = "Camel's Hump Technique",
    nameChinese = "驼峰蓄能术",
    nameRussian = "Техника Горба Верблюда",
    description = "Desert survival wisdom - store reserves in times of plenty, burn them in times of need.",
    descriptionLong = "Like the camel storing fat in its hump for the harsh desert, your body becomes a living reservoir. Novices burn recklessly and die hollow. Masters know when to stop.",
    
    -- Requirements
    requirements = {
        minBodyLevel = 2,
        item = "TechniqueManuscript_Metabolism",
    },
    
    -- Stage configuration
    maxStage = 5,
    baseXP = 80,
    
    xpPerStage = function(stage)
        local multipliers = { 1.0, 1.5, 2.0, 3.0 }
        return 80 * (multipliers[stage] or 1.0)
    end,
    
    -- XP SYSTEM: Learn by actually using the technique
    -- Design: Novices learn from basics (eating/healing), masters must take risks (burn fat)
    levelingConditions = {
        {
            -- Event: Calorie consumption for healing
            event = "OnMetabolismHealing",
            xpGain = function(player, data, stage)
                if not data.caloriesUsed or data.caloriesUsed <= 0 then
                    return 0
                end
                
                -- Stage multipliers: Diminishing returns as you master the basics
                local stageMultipliers = {
                    [1] = 0.025,  -- Fast: Stage 1→2 in ~5 days normal play (3200 cal)
                    [2] = 0.012,  -- Moderate: Stage 2→3 in ~20 days (10000 cal)
                    [3] = 0.008,  -- Slow: Stage 3→4 in ~40 days (20000 cal)
                    [4] = 0.005,  -- Very slow: Stage 4→5 in ~96 days (48000 cal)
                    [5] = 0.002,  -- Negligible: Masters don't learn from eating anymore
                }
                
                local multiplier = stageMultipliers[stage] or 0.002
                return data.caloriesUsed * multiplier
            end,
        },
        {
            -- Event: Weight burning (emergency fat-to-calorie conversion)
            event = "OnWeightBurn",
            xpGain = function(player, data, stage)
                if not data.weightBurned or data.weightBurned <= 0 then
                    return 0
                end
                
                -- Base: 2 XP per kg burned (constant across stages)
                local baseXP = data.weightBurned * 2.0
                
                -- Risk multiplier: Desperation accelerates learning
                -- Philosophy: "The fool at death's door learns faster than the safe scholar"
                local riskMultiplier = 1.0
                if data.currentWeight then
                    local minWeight = getMinSafeWeight(stage)
                    local distanceFromMin = data.currentWeight - minWeight
                    
                    if distanceFromMin < 2.0 then
                        riskMultiplier = 2.0  -- <2kg from death: 4 XP/kg
                    elseif distanceFromMin < 5.0 then
                        riskMultiplier = 1.5  -- <5kg from limit: 3 XP/kg
                    end
                    -- Safe distance (>5kg): 2 XP/kg (base rate)
                end
                
                return baseXP * riskMultiplier
            end,
        },
    },
    
    -- Query current technique capabilities (for UI/debug/external systems)
    getEffects = function(stage)
        if stage <= 0 then
            return {
                healingEnabled = false,
                hpRegenEnabled = false,
                weightConversionEnabled = false,
                stage = 0,
            }
        end
        
        local power = HEALING_POWER[stage] or HEALING_POWER[1]
        return {
            healingEnabled = true,                -- Always active at Stage 1+
            hpRegenEnabled = stage >= 2,          -- Unlocks at Stage 2
            weightConversionEnabled = stage >= WEIGHT_CONVERSION_STAGE,  -- Stage 1+
            woundHealing = power.wound,           -- Current wound healing power (costs calories)
            stiffnessHealing = power.stiffness,   -- Active healing for severe strain (costs calories)
            hpRegen = power.hp,                   -- Passive regen (free, via effect system)
            enduranceRegen = power.endurance,     -- Active endurance restoration (costs calories)
            calorieConsumption = power.calories,  -- Calorie cost per tick
            efficiency = power.efficiency,        -- Metabolic efficiency (0.5-1.0)
            minSafeWeight = getMinSafeWeight(stage),  -- Weight below which technique stops
            stage = stage,
        }
    end,
    
    -- Main effect application (called every tick by technique system)
    applyEffect = applyMetabolism,
    
    -- Lifecycle callbacks for player feedback
    onLearn = function(player)
        -- Initial acquisition: Warn player about danger
        print("[Technique] " .. player:getUsername() .. " has begun learning the Camel's Hump Technique")
        HaloTextHelper.addText(player, "[col=255,200,100]You have acquired the Camel's Hump Technique[/]")
        HaloTextHelper.addText(player, "[col=255,100,100]WARNING: This power can save or destroy you![/]")
        HaloTextHelper.addText(player, "[col=200,200,200]\"The desperate burn themselves to ash. The wise conserve until mastery.\"[/]")
    end,
    
    onStageUp = function(player, newStage)
        -- Stage progression: Celebrate achievement and warn about new limits
        local stageData = TechniqueRegistry.STAGE_DATA[newStage]
        local stageName = stageData and stageData.name or tostring(newStage)
        
        local minWeight = getMinSafeWeight(newStage)
        
        local messages = {
            [1] = string.format("POWER AWAKENS! You can burn flesh for survival! DANGER: Will burn to %.1fkg!", minWeight),
            [2] = string.format("HP regen unlocked! Learning control... but still reckless (min: %.1fkg).", minWeight),
            [3] = string.format("Wisdom grows slowly. You burn less recklessly now (min: %.1fkg).", minWeight),
            [4] = string.format("Desert wisdom takes root. The reserves last longer (min: %.1fkg).", minWeight),
            [5] = string.format("DESERT KING! Infection healing unlocked! True control achieved (min: %.1fkg)!", minWeight),
        }
        
        local color = newStage >= 5 and "255,215,0" or (newStage >= 4 and "200,150,255" or "180,255,180")
        HaloTextHelper.addText(player, string.format("[col=%s]Camel's Hump: %s[/]", color, stageName))
        
        local msg = messages[newStage]
        if msg then
            HaloTextHelper.addText(player, string.format("[col=%s]%s[/]", color, msg))
        end
        
        -- Warning for ALL stages (technique is always dangerous!)
        if newStage == 1 then
            HaloTextHelper.addText(player, "[col=255,0,0]EXTREME DANGER! No control! Can burn to near-death (50.5kg)![/]")
        elseif newStage == 2 then
            HaloTextHelper.addText(player, "[col=255,50,50]Still VERY RECKLESS! Will burn to 55.5kg if wounded badly![/]")
        elseif newStage == 3 then
            HaloTextHelper.addText(player, "[col=255,100,50]Learning limits... but 60.5kg minimum is still skeletal![/]")
        elseif newStage == 4 then
            HaloTextHelper.addText(player, "[col=200,150,50]Desert wisdom growing. 65.5kg minimum - safer but still risky.[/]")
        elseif newStage == 5 then
            HaloTextHelper.addText(player, "[col=100,255,100]Desert King's mastery! 70.5kg minimum + infection healing![/]")
        end
    end,
}

-- Export constants for external systems (UI, debugging, other techniques, etc.)
technique.MIN_SAFE_WEIGHT_BY_STAGE = MIN_SAFE_WEIGHT_BY_STAGE  -- Stage-based weight limits
technique.UNDERWEIGHT_THRESHOLD = UNDERWEIGHT_THRESHOLD          -- Game trait threshold (80kg)
technique.VERY_UNDERWEIGHT_THRESHOLD = VERY_UNDERWEIGHT_THRESHOLD -- Game trait threshold (75kg)
technique.SAFETY_BUFFER = SAFETY_BUFFER                          -- Prevents trait flickering (0.5kg)
technique.CALORIES_PER_KG = CALORIES_PER_KG                      -- Conversion rate (7700 cal/kg)
technique.HEALING_POWER = HEALING_POWER                          -- Stage-based healing values
technique.GAME_CALORIE_FLOOR = GAME_CALORIE_FLOOR                -- Game's hardcoded calorie limit (-2200)
technique.getMinSafeWeight = getMinSafeWeight                    -- Query minimum safe weight

-- Register with technique system
TechniqueRegistry.register(technique)

return technique
