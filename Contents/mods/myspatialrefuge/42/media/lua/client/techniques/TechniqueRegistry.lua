-- TechniqueRegistry.lua
-- Central registry for all cultivation techniques
-- Implements wuxia-style stage progression (功法境界)

local TechniqueRegistry = {}

-- Storage for all registered techniques
TechniqueRegistry.techniques = {}

-- Storage for event-to-technique mappings (for quick lookup)
TechniqueRegistry.eventMappings = {}

--[[
    STAGE SYSTEM (境界)
    
    Techniques progress through 5 stages following traditional Chinese cultivation:
    
    1. 入门 (Rùmén)      - Entry: Basic understanding, unreliable effects
    2. 小成 (Xiǎo Chéng) - Small Achievement: Improved but conditional
    3. 大成 (Dà Chéng)   - Great Achievement: Reliable mastery
    4. 圆满 (Yuánmǎn)    - Completeness: Near-perfect control
    5. 极境 (Jí Jìng)    - Ultimate Realm: Perfect mastery
]]

-- Stage constants for use in technique definitions
TechniqueRegistry.STAGES = {
    ENTRY = 1,              -- 入门
    SMALL_ACHIEVEMENT = 2,  -- 小成
    GREAT_ACHIEVEMENT = 3,  -- 大成
    COMPLETENESS = 4,       -- 圆满
    ULTIMATE = 5,           -- 极境
}

-- Stage display data (English adaptations of wuxia cultivation stages)
TechniqueRegistry.STAGE_DATA = {
    [1] = {
        name = "Initiate",
        description = "Basic understanding. Effects barely manifest.",
        effectMultiplier = 0.20,
    },
    [2] = {
        name = "Adept",
        description = "Improved comprehension. Effects more consistent.",
        effectMultiplier = 0.40,
    },
    [3] = {
        name = "Accomplished",
        description = "Confident mastery. Reliable in most situations.",
        effectMultiplier = 0.60,
    },
    [4] = {
        name = "Perfected",
        description = "Near-perfect control. Minimal failures.",
        effectMultiplier = 0.80,
    },
    [5] = {
        name = "Transcendent",
        description = "Perfect mastery. Technique becomes instinct.",
        effectMultiplier = 1.00,
    },
}

-- Default XP multipliers for stage advancement
-- Stage 1→2 is baseline, each subsequent stage is harder
TechniqueRegistry.DEFAULT_XP_MULTIPLIERS = {
    [1] = 1.0,   -- Entry → Small Achievement
    [2] = 1.5,   -- Small Achievement → Great Achievement
    [3] = 2.0,   -- Great Achievement → Completeness
    [4] = 3.0,   -- Completeness → Ultimate
}

--- Get stage display data
---@param stage number Stage number (1-5)
---@return table|nil stageData
function TechniqueRegistry.getStageData(stage)
    return TechniqueRegistry.STAGE_DATA[stage]
end

--- Get stage display name
---@param stage number Stage number (1-5)
---@return string displayName
function TechniqueRegistry.getStageDisplayName(stage)
    local data = TechniqueRegistry.STAGE_DATA[stage]
    if not data then
        return "Unknown"
    end
    return data.name
end

--- Get stage name (alias for getStageDisplayName)
---@param stage number Stage number (1-5)
---@return string stageName
function TechniqueRegistry.getStageName(stage)
    local data = TechniqueRegistry.STAGE_DATA[stage]
    return data and data.name or "?"
end

--[[
    Technique Definition Structure:
    {
        id = "technique_id",                    -- Unique identifier
        name = "Display Name",                  -- Localized display name
        description = "Description text",       -- Localized description
        
        -- Requirements to learn the technique
        requirements = {
            minBodyLevel = 0,                   -- Minimum Body cultivation level
            minSpiritLevel = 0,                 -- Minimum Spirit level (future)
            item = "ItemType",                  -- Item required to learn (manuscript, etc.)
        },
        
        -- Stage configuration (replaces maxLevel)
        maxStage = 5,                           -- Maximum stage (default 5 = Ultimate)
        baseXP = 100,                           -- Base XP for first stage advancement
        xpPerStage = function(stage),           -- Or custom XP function
        
        -- Leveling conditions: what triggers XP gain
        levelingConditions = {
            {
                event = "OnEventName",
                condition = function(player, data) return true end,
                xpGain = function(player, data, stage) return 1 end,
            },
        },
        
        -- Effect calculation based on stage (1-5)
        getEffects = function(stage)
            return {
                effectName = value,
            }
        end,
        
        -- Optional: Called when technique is first learned
        onLearn = function(player) end,
        
        -- Optional: Called when technique advances to new stage
        onStageUp = function(player, newStage) end,
    }
]]

--- Register a new technique
---@param technique table Technique definition table
---@return boolean success
function TechniqueRegistry.register(technique)
    -- Validate required fields
    if not technique.id then
        print("[TechniqueRegistry] ERROR: Technique missing 'id' field")
        return false
    end
    
    if TechniqueRegistry.techniques[technique.id] then
        print("[TechniqueRegistry] WARNING: Overwriting technique: " .. technique.id)
    end
    
    -- Set defaults
    technique.requirements = technique.requirements or {}
    technique.maxStage = technique.maxStage or 5  -- Default to 5 stages
    technique.baseXP = technique.baseXP or 100
    technique.levelingConditions = technique.levelingConditions or {}
    technique.getEffects = technique.getEffects or function() return {} end
    
    -- Legacy support: convert maxLevel to maxStage if present
    if technique.maxLevel and not technique.maxStage then
        technique.maxStage = 5  -- Always use 5 stages now
        print("[TechniqueRegistry] NOTE: Converted maxLevel to maxStage for " .. technique.id)
    end
    
    -- Store technique
    TechniqueRegistry.techniques[technique.id] = technique
    
    -- Build event mappings for quick lookup
    for _, condition in ipairs(technique.levelingConditions) do
        local eventName = condition.event
        if eventName then
            if not TechniqueRegistry.eventMappings[eventName] then
                TechniqueRegistry.eventMappings[eventName] = {}
            end
            table.insert(TechniqueRegistry.eventMappings[eventName], {
                techniqueId = technique.id,
                condition = condition.condition,
                xpGain = condition.xpGain,
            })
        end
    end
    
    print("[TechniqueRegistry] Registered technique: " .. technique.id)
    return true
end

--- Get a technique by ID
---@param id string Technique ID
---@return table|nil technique
function TechniqueRegistry.get(id)
    return TechniqueRegistry.techniques[id]
end

--- Get all techniques that respond to a specific event
---@param eventName string Event name
---@return table Array of {techniqueId, condition, xpGain}
function TechniqueRegistry.getTechniquesForEvent(eventName)
    return TechniqueRegistry.eventMappings[eventName] or {}
end

--- Get all registered technique IDs
---@return table Array of technique IDs
function TechniqueRegistry.getAllIds()
    local ids = {}
    for id, _ in pairs(TechniqueRegistry.techniques) do
        table.insert(ids, id)
    end
    return ids
end

--- Check if a player meets requirements to learn a technique
---@param player IsoPlayer
---@param techniqueId string
---@return boolean canLearn
---@return string|nil reason
function TechniqueRegistry.canLearn(player, techniqueId)
    local technique = TechniqueRegistry.techniques[techniqueId]
    if not technique then
        return false, "Technique not found"
    end
    
    local req = technique.requirements
    
    -- Check Body level requirement
    if req.minBodyLevel and req.minBodyLevel > 0 then
        local bodyLevel = player:getPerkLevel(Perks.Body)
        if bodyLevel < req.minBodyLevel then
            return false, "Requires Body level " .. req.minBodyLevel
        end
    end
    
    -- Check Spirit level requirement (future)
    if req.minSpiritLevel and req.minSpiritLevel > 0 then
        if Perks.Spirit then
            local spiritLevel = player:getPerkLevel(Perks.Spirit)
            if spiritLevel < req.minSpiritLevel then
                return false, "Requires Spirit level " .. req.minSpiritLevel
            end
        end
    end
    
    -- Check item requirement
    if req.item then
        local inventory = player:getInventory()
        if not inventory:contains(req.item) then
            return false, "Requires item: " .. req.item
        end
    end
    
    return true, nil
end

--- Calculate XP required to advance from a specific stage
---@param technique table Technique definition
---@param stage number Current stage (1-4, stage 5 has no next)
---@return number xpRequired
function TechniqueRegistry.getXPForStage(technique, stage)
    -- Can't advance past max stage
    if stage >= (technique.maxStage or 5) then
        return math.huge  -- Infinite XP required (can't advance)
    end
    
    -- Custom XP function
    if type(technique.xpPerStage) == "function" then
        local xp = technique.xpPerStage(stage)
        return xp > 0 and xp or 100  -- Safety fallback
    end
    
    -- Default calculation: baseXP * stage multiplier
    local baseXP = technique.baseXP or 100
    local multiplier = TechniqueRegistry.DEFAULT_XP_MULTIPLIERS[stage] or 1.0
    
    return baseXP * multiplier
end

--- Legacy compatibility: map getXPForLevel to getXPForStage
---@param technique table Technique definition
---@param level number Level/Stage number
---@return number xpRequired
function TechniqueRegistry.getXPForLevel(technique, level)
    return TechniqueRegistry.getXPForStage(technique, level)
end

--- Get effect multiplier for a stage
---@param stage number Stage number (1-5)
---@return number multiplier (0.0 to 1.0)
function TechniqueRegistry.getEffectMultiplier(stage)
    local data = TechniqueRegistry.STAGE_DATA[stage]
    return data and data.effectMultiplier or 0
end

return TechniqueRegistry

