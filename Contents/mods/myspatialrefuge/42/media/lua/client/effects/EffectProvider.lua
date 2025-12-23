-- EffectProvider.lua
-- Base interface/template for systems that provide effects
-- Systems like BodyCultivation, Techniques, Equipment should implement this interface

local EffectProvider = {}

--[[
    EFFECT PROVIDER INTERFACE
    
    Any system that wants to contribute effects to players should implement:
    
    1. calculateEffects(player) -> table
       Returns an array of effect definitions:
       {
           { name = "hunger_reduction", value = 0.40, priority = 10, metadata = {...} },
           { name = "stiffness_decay", value = 5.0, priority = 5, metadata = {...} },
           ...
       }
    
    2. getSourceName() -> string
       Returns a unique identifier for this provider (e.g., "BodyCultivation")
    
    3. shouldApply(player) -> boolean (optional)
       Returns true if this provider should calculate effects for this player
       Default: Always returns true
       
    4. onEffectsChanged(player) -> void (optional)
       Called when the provider's effects have changed (e.g., level up)
       Can be used to trigger registry recalculation
]]

--- Create a new effect provider
---@param config table Provider configuration
---@return table provider
function EffectProvider.create(config)
    local provider = {
        sourceName = config.sourceName or "UnknownProvider",
        calculateEffects = config.calculateEffects,
        shouldApply = config.shouldApply or function(player) return true end,
        onEffectsChanged = config.onEffectsChanged or function(player) end,
        priority = config.priority or 0,  -- Default priority for all effects from this provider
    }
    
    -- Validation
    if not provider.calculateEffects then
        error("[EffectProvider] Provider '" .. provider.sourceName .. "' must implement calculateEffects()")
    end
    
    if type(provider.calculateEffects) ~= "function" then
        error("[EffectProvider] calculateEffects must be a function")
    end
    
    return provider
end

--- Register effects from a provider to the registry
---@param provider table The provider instance
---@param player IsoPlayer
---@param registry table The EffectRegistry module
function EffectProvider.registerEffects(provider, player, registry)
    if not provider.shouldApply(player) then
        -- Unregister all effects from this provider
        registry.unregister(player, provider.sourceName)
        return
    end
    
    -- Calculate effects for this player
    local effects = provider.calculateEffects(player)
    
    if not effects or type(effects) ~= "table" then
        -- No effects to register
        registry.unregister(player, provider.sourceName)
        return
    end
    
    -- Unregister old effects first (clean slate)
    registry.unregister(player, provider.sourceName)
    
    -- Register each effect
    for _, effect in ipairs(effects) do
        if effect.name and effect.value ~= nil then
            local priority = effect.priority or provider.priority
            local metadata = effect.metadata or {}
            
            registry.register(
                player,
                effect.name,
                effect.value,
                provider.sourceName,
                metadata,
                priority
            )
        end
    end
end

--==============================================================================
-- HELPER UTILITIES
--==============================================================================

--- Create a simple effect definition
---@param name string Effect name (from EffectRegistry.EFFECT_TYPES)
---@param value number Effect value
---@param metadata table|nil Optional metadata
---@param priority number|nil Optional priority
---@return table
function EffectProvider.makeEffect(name, value, metadata, priority)
    return {
        name = name,
        value = value,
        metadata = metadata or {},
        priority = priority or 0,
    }
end

--- Create multiple effects at once
---@param effects table Array of {name, value, metadata, priority}
---@return table
function EffectProvider.makeEffects(effects)
    local result = {}
    for _, e in ipairs(effects) do
        table.insert(result, EffectProvider.makeEffect(e.name or e[1], e.value or e[2], e.metadata or e[3], e.priority or e[4]))
    end
    return result
end

--==============================================================================
-- EXAMPLE PROVIDER (for reference)
--==============================================================================

--[[
Example: Body Cultivation Provider

local BodyCultivationProvider = EffectProvider.create({
    sourceName = "BodyCultivation",
    priority = 10,  -- High priority
    
    shouldApply = function(player)
        local bodyLevel = player:getPerkLevel(Perks.Body)
        return bodyLevel > 0
    end,
    
    calculateEffects = function(player)
        local bodyLevel = player:getPerkLevel(Perks.Body)
        if bodyLevel == 0 then return {} end
        
        return {
            EffectProvider.makeEffect("hunger_reduction", getHungerReduction(bodyLevel), {level=bodyLevel}),
            EffectProvider.makeEffect("thirst_reduction", getThirstReduction(bodyLevel), {level=bodyLevel}),
            EffectProvider.makeEffect("fatigue_reduction", getFatigueReduction(bodyLevel), {level=bodyLevel}),
            -- ... more effects
        }
    end,
    
    onEffectsChanged = function(player)
        -- Called when Body level changes
        print("[BodyCultivation] Effects updated for " .. player:getUsername())
    end,
})

-- Usage:
local EffectRegistry = require "effects/EffectRegistry"
EffectProvider.registerEffects(BodyCultivationProvider, player, EffectRegistry)
EffectRegistry.recalculate(player)
]]

print("[EffectProvider] Effect provider interface initialized")

return EffectProvider




