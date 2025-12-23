-- EffectRegistry.lua
-- Centralized registry for character effects from all sources
-- Handles effect combination, stacking rules, and source tracking

local LuaCompat = require "utils/LuaCompat"

local EffectRegistry = {}

-- Effect stacking rules
EffectRegistry.STACKING_RULES = {
    ADDITIVE = "additive",           -- Sum all values: 0.40 + 0.25 = 0.65
    MULTIPLICATIVE = "multiplicative", -- Diminishing: 1 - (1-0.40) * (1-0.25) = 0.55
    MAXIMUM = "maximum",             -- Take highest value
    REPLACE = "replace",             -- Last registered wins
}

-- Effect types (for validation and type-specific behavior)
EffectRegistry.EFFECT_TYPES = {
    -- Reduction effects (0.0 to 1.0, reduce stat gain)
    HUNGER_REDUCTION = { name = "hunger_reduction", type = "reduction", stacking = "multiplicative", default = 0 },
    THIRST_REDUCTION = { name = "thirst_reduction", type = "reduction", stacking = "multiplicative", default = 0 },
    FATIGUE_REDUCTION = { name = "fatigue_reduction", type = "reduction", stacking = "multiplicative", default = 0 },
    ENDURANCE_REDUCTION = { name = "endurance_reduction", type = "reduction", stacking = "multiplicative", default = 0 },
    STIFFNESS_REDUCTION = { name = "stiffness_reduction", type = "reduction", stacking = "multiplicative", default = 0 },
    
    -- Combat efficiency reductions
    ATTACK_ENDURANCE_REDUCTION = { name = "attack_endurance_reduction", type = "reduction", stacking = "multiplicative", default = 0 },
    
    -- Regeneration effects (flat amounts per tick)
    STIFFNESS_DECAY = { name = "stiffness_decay", type = "regen", stacking = "additive", default = 0 },
    HEALTH_REGEN = { name = "health_regen", type = "regen", stacking = "additive", default = 0 },
    FITNESS_XP = { name = "fitness_xp", type = "regen", stacking = "additive", default = 0 },
    STRENGTH_XP = { name = "strength_xp", type = "regen", stacking = "additive", default = 0 },
    
    -- Multiplier effects (modify base values)
    FITNESS_XP_MULTIPLIER = { name = "fitness_xp_multiplier", type = "multiplier", stacking = "multiplicative", default = 1.0 },
    STRENGTH_XP_MULTIPLIER = { name = "strength_xp_multiplier", type = "multiplier", stacking = "multiplicative", default = 1.0 },
    BODY_XP_MULTIPLIER = { name = "body_xp_multiplier", type = "multiplier", stacking = "multiplicative", default = 1.0 },
    
    -- Decay protection (0.0 to 1.0, percentage of decay prevented)
    DECAY_PROTECTION = { name = "decay_protection", type = "reduction", stacking = "maximum", default = 0 },
    
    -- Zombie mechanics (0.0 to 1.0, percentage reduction)
    ZOMBIE_ATTRACTION_REDUCTION = { name = "zombie_attraction_reduction", type = "reduction", stacking = "multiplicative", default = 0 },
    ZOMBIE_SIGHT_REDUCTION = { name = "zombie_sight_reduction", type = "reduction", stacking = "multiplicative", default = 0 },
    ZOMBIE_HEARING_REDUCTION = { name = "zombie_hearing_reduction", type = "reduction", stacking = "multiplicative", default = 0 },
    
    -- Technique-specific effects
    METABOLISM_EFFICIENCY = { name = "metabolism_efficiency", type = "multiplier", stacking = "multiplicative", default = 1.0 },
    HEALING_POWER_MULTIPLIER = { name = "healing_power_multiplier", type = "multiplier", stacking = "multiplicative", default = 1.0 },
    
    -- Threshold/Boolean effects (enable/disable features)
    WEIGHT_CONVERSION = { name = "weight_conversion", type = "boolean", stacking = "maximum", default = false },
    HP_REGEN_ENABLED = { name = "hp_regen_enabled", type = "boolean", stacking = "maximum", default = false },
}

-- Per-player effect storage
-- Structure: playerRegistry[username] = { effectName -> { total, sources[], isDirty } }
local playerRegistry = {}

-- Cache debug mode
local isDebug = getDebug()

--==============================================================================
-- HELPER FUNCTIONS
--==============================================================================

--- Get unique player key (prevents multiplayer collisions)
---@param player IsoPlayer
---@return string|nil
local function getPlayerKey(player)
    if not player then 
        if isDebug then
            print("[EffectRegistry] ERROR: getPlayerKey called with nil player")
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

--- Get or create player registry
---@param player IsoPlayer
---@return table|nil
local function getPlayerRegistry(player)
    local playerKey = getPlayerKey(player)
    if not playerKey then
        if isDebug then
            print("[EffectRegistry] ERROR: Failed to get player key for registry")
        end
        return nil
    end
    
    if not playerRegistry[playerKey] then
        playerRegistry[playerKey] = {
            effects = {},
            isDirty = true,  -- Needs recalculation
            lastUpdated = 0,
        }
    end
    return playerRegistry[playerKey]
end

--- Get effect definition by name
---@param effectName string
---@return table|nil
local function getEffectDefinition(effectName)
    for _, def in pairs(EffectRegistry.EFFECT_TYPES) do
        if def.name == effectName then
            return def
        end
    end
    return nil
end

--- Combine effect sources using stacking rule
---@param sources table Array of {value, source, priority, metadata}
---@param stackingRule string
---@return number combinedValue
local function combineEffects(sources, stackingRule)
    if #sources == 0 then return 0 end
    if #sources == 1 then return sources[1].value end
    
    -- Sort by priority (higher priority = processed first)
    table.sort(sources, function(a, b)
        return (a.priority or 0) > (b.priority or 0)
    end)
    
    if stackingRule == EffectRegistry.STACKING_RULES.ADDITIVE then
        local sum = 0
        for _, source in ipairs(sources) do
            sum = sum + source.value
        end
        return sum
        
    elseif stackingRule == EffectRegistry.STACKING_RULES.MULTIPLICATIVE then
        -- For reductions: 1 - (1-a) * (1-b)
        -- For multipliers: a * b
        local product = 1.0
        for _, source in ipairs(sources) do
            if source.value >= 0 and source.value <= 1 then
                -- Reduction (0-1)
                product = product * (1 - source.value)
            else
                -- Multiplier
                product = product * source.value
            end
        end
        -- If reduction, return 1 - product; else return product
        if sources[1].value >= 0 and sources[1].value <= 1 then
            return 1 - product
        else
            return product
        end
        
    elseif stackingRule == EffectRegistry.STACKING_RULES.MAXIMUM then
        local maxValue = sources[1].value
        for i = 2, #sources do
            if sources[i].value > maxValue then
                maxValue = sources[i].value
            end
        end
        return maxValue
        
    elseif stackingRule == EffectRegistry.STACKING_RULES.REPLACE then
        -- Highest priority wins
        return sources[1].value
    end
    
    return 0
end

--==============================================================================
-- PUBLIC API
--==============================================================================

--- Register an effect for a player
---@param player IsoPlayer
---@param effectName string Effect name (from EFFECT_TYPES)
---@param value number Effect value
---@param source string Source identifier (e.g., "BodyCultivation", "DevouringElephant")
---@param metadata table|nil Optional metadata (level, stage, etc.)
---@param priority number|nil Optional priority (higher = more important)
function EffectRegistry.register(player, effectName, value, source, metadata, priority)
    if not player or not effectName or value == nil or not source then
        if isDebug then
            print("[EffectRegistry] ERROR: Invalid registration - missing required parameters")
        end
        return false
    end
    
    -- Validate effect name exists in EFFECT_TYPES
    local effectDef = getEffectDefinition(effectName)
    if not effectDef then
        print("[EffectRegistry] ERROR: Unknown effect type '" .. tostring(effectName) .. "' from source '" .. tostring(source) .. "'")
        print("[EffectRegistry] Valid reduction effects: hunger_reduction, thirst_reduction, fatigue_reduction, endurance_reduction, stiffness_reduction, attack_endurance_reduction, zombie_attraction_reduction, zombie_sight_reduction, zombie_hearing_reduction")
        print("[EffectRegistry] Valid regen effects: stiffness_decay, health_regen, fitness_xp, strength_xp")
        print("[EffectRegistry] Valid multipliers: fitness_xp_multiplier, strength_xp_multiplier, body_xp_multiplier, metabolism_efficiency, healing_power_multiplier")
        print("[EffectRegistry] Valid special: decay_protection, weight_conversion, hp_regen_enabled")
        return false
    end
    
    -- Validate value is a number
    if type(value) ~= "number" then
        print("[EffectRegistry] ERROR: Effect value must be a number, got " .. type(value))
        return false
    end
    
    -- Validate value is not NaN or Infinity
    if value ~= value or value == math.huge or value == -math.huge then
        print("[EffectRegistry] ERROR: Effect value is NaN or Infinity")
        return false
    end
    
    local registry = getPlayerRegistry(player)
    if not registry then return false end
    
    -- Initialize effect entry if not exists
    if not registry.effects[effectName] then
        registry.effects[effectName] = {
            sources = {},
            total = 0,
            stackingRule = "additive",  -- Default
            effectType = "unknown",
        }
        
        -- Set stacking rule from definition
        local def = getEffectDefinition(effectName)
        if def then
            registry.effects[effectName].stackingRule = def.stacking
            registry.effects[effectName].effectType = def.type
        end
    end
    
    local effect = registry.effects[effectName]
    
    -- Find or create source entry
    local sourceEntry = nil
    for _, src in ipairs(effect.sources) do
        if src.source == source then
            sourceEntry = src
            break
        end
    end
    
    if not sourceEntry then
        sourceEntry = {
            source = source,
            value = value,
            priority = priority or 0,
            metadata = metadata or {},
        }
        table.insert(effect.sources, sourceEntry)
    else
        -- Update existing source
        sourceEntry.value = value
        sourceEntry.priority = priority or sourceEntry.priority
        sourceEntry.metadata = metadata or sourceEntry.metadata
    end
    
    -- Mark as dirty (needs recalculation)
    registry.isDirty = true
    
    return true
end

--- Unregister all effects from a specific source
---@param player IsoPlayer
---@param source string Source identifier to remove
function EffectRegistry.unregister(player, source)
    local registry = getPlayerRegistry(player)
    if not registry then return end
    
    for effectName, effect in pairs(registry.effects) do
        -- Remove source from sources list
        for i = #effect.sources, 1, -1 do
            if effect.sources[i].source == source then
                table.remove(effect.sources, i)
            end
        end
        
        -- Clean up empty effects
        if #effect.sources == 0 then
            registry.effects[effectName] = nil
        end
    end
    
    registry.isDirty = true
end

--- Clear all effects for a player
---@param player IsoPlayer
function EffectRegistry.clear(player)
    local registry = getPlayerRegistry(player)
    if not registry then return end
    registry.effects = {}
    registry.isDirty = true
end

--- Recalculate combined effects for a player (call after registrations)
---@param player IsoPlayer
function EffectRegistry.recalculate(player)
    local registry = getPlayerRegistry(player)
    if not registry then return end
    
    if not registry.isDirty then
        return  -- No changes, skip recalculation
    end
    
    local recalcCount = 0
    
    -- Recalculate totals
    for effectName, effect in pairs(registry.effects) do
        if #effect.sources > 0 then
            effect.total = combineEffects(effect.sources, effect.stackingRule)
            recalcCount = recalcCount + 1
        else
            effect.total = 0
        end
    end
    
    registry.isDirty = false
    registry.lastUpdated = getTimestampMs()
    
    if isDebug and recalcCount > 0 then
        print(string.format("[EffectRegistry] %s: Recalculated %d effects", 
            player:getUsername(), recalcCount))
    end
end

--- Get total effect value for a player
---@param player IsoPlayer
---@param effectName string
---@param defaultValue number|nil Default if effect not found
---@return number
function EffectRegistry.get(player, effectName, defaultValue)
    local registry = getPlayerRegistry(player)
    if not registry then 
        -- Return default value if registry fails
        if defaultValue ~= nil then
            return defaultValue
        end
        local def = getEffectDefinition(effectName)
        return def and def.default or 0
    end
    
    -- Auto-recalculate if dirty
    if registry.isDirty then
        EffectRegistry.recalculate(player)
    end
    
    local effect = registry.effects[effectName]
    if effect and effect.total ~= nil then
        return effect.total
    end
    
    -- Return default from definition or provided default
    if defaultValue ~= nil then
        return defaultValue
    end
    
    local def = getEffectDefinition(effectName)
    if def then
        return def.default
    end
    
    return 0
end

--- Get detailed effect info (total + sources) for debugging/UI
---@param player IsoPlayer
---@param effectName string
---@return table|nil { total, sources[], stackingRule, effectType }
function EffectRegistry.getDetails(player, effectName)
    local registry = getPlayerRegistry(player)
    if not registry then return nil end
    
    if registry.isDirty then
        EffectRegistry.recalculate(player)
    end
    
    local effect = registry.effects[effectName]
    if not effect then
        return nil
    end
    
    -- Deep copy to prevent external modification
    local details = {
        total = effect.total,
        stackingRule = effect.stackingRule,
        effectType = effect.effectType,
        sources = {},
    }
    
    for _, src in ipairs(effect.sources) do
        table.insert(details.sources, {
            source = src.source,
            value = src.value,
            priority = src.priority,
            metadata = src.metadata,
        })
    end
    
    return details
end

--- Get all active effects for a player
---@param player IsoPlayer
---@return table { effectName -> total }
function EffectRegistry.getAll(player)
    local registry = getPlayerRegistry(player)
    if not registry then return {} end
    
    if registry.isDirty then
        EffectRegistry.recalculate(player)
    end
    
    local allEffects = {}
    for effectName, effect in pairs(registry.effects) do
        allEffects[effectName] = effect.total
    end
    
    return allEffects
end

--- Check if an effect is active (has any sources)
---@param player IsoPlayer
---@param effectName string
---@return boolean
function EffectRegistry.hasEffect(player, effectName)
    local registry = getPlayerRegistry(player)
    if not registry then return false end
    local effect = registry.effects[effectName]
    return effect ~= nil and #effect.sources > 0
end

--- Print debug info for a player's effects
---@param player IsoPlayer
function EffectRegistry.debugPrint(player)
    if not player then
        print("[EffectRegistry] ERROR: Player is nil")
        return
    end
    
    local registry = getPlayerRegistry(player)
    if not registry then 
        print("[EffectRegistry] ERROR: Failed to get player registry")
        return 
    end
    
    if registry.isDirty then
        pcall(function() EffectRegistry.recalculate(player) end)
    end
    
    local username = "Unknown"
    local success, result = pcall(function() return player:getUsername() end)
    if success and result then username = result end
    
    print("=== [EffectRegistry] " .. username .. " ===")
    
    local effectCount = 0
    for effectName, effect in pairs(registry.effects or {}) do
        if #effect.sources > 0 then
            effectCount = effectCount + 1
            print(string.format("  %s: %.4f (%s)", effectName, effect.total, effect.stackingRule))
            for _, src in ipairs(effect.sources) do
                local metaStr = ""
                if src.metadata and LuaCompat.hasKeys(src.metadata) then
                    local parts = {}
                    for k, v in pairs(src.metadata) do
                        table.insert(parts, string.format("%s=%s", k, tostring(v)))
                    end
                    metaStr = " [" .. table.concat(parts, ", ") .. "]"
                end
                print(string.format("    - %s: %.4f (priority: %d)%s", 
                    src.source, src.value, src.priority, metaStr))
            end
        end
    end
    
    if effectCount == 0 then
        print("  (no active effects)")
    end
    
    print("==========================================")
end

--- Mark effect registry as dirty (force recalculation)
---@param player IsoPlayer
function EffectRegistry.markDirty(player)
    local registry = getPlayerRegistry(player)
    if not registry then return end
    registry.isDirty = true
end

--==============================================================================
-- EVENT HANDLERS
--==============================================================================

--- Cleanup on player load/death
local function onLoad()
    playerRegistry = {}
    print("[EffectRegistry] Player registries cleared")
end

--- Cleanup on player disconnect (prevent memory leaks)
---@param player IsoPlayer
local function onPlayerDisconnect(player)
    if not player then return end
    local playerKey = getPlayerKey(player)
    if playerRegistry[playerKey] then
        playerRegistry[playerKey] = nil
        if isDebug then
            print("[EffectRegistry] Cleaned up registry for disconnected player: " .. playerKey)
        end
    end
end

Events.OnLoad.Add(onLoad)
Events.OnPlayerDeath.Add(onPlayerDisconnect)

-- Note: OnPlayerDisconnect doesn't exist in PZ, cleanup happens on OnLoad
-- But we add death handler to free memory when player dies

print("[EffectRegistry] Effect registry system initialized")

return EffectRegistry

