-- EffectSystemInit.lua
-- Initializes the unified effect system and registers all providers
-- This replaces the old CultivationEffects system

local EffectSystem = require "effects/EffectSystem"
local EffectHooks = require "effects/EffectHooks"
local BodyCultivationProvider = require "BodyCultivationProvider"
local TechniqueEffectProvider = require "techniques/TechniqueEffectProvider"

local EffectSystemInit = {}

-- Cache debug mode
local isDebug = getDebug()

-- Initialization flag to prevent multiple runs
local initialized = false

--==============================================================================
-- INITIALIZATION
--==============================================================================

local function initializeEffectSystem()
    -- Prevent multiple initialization
    if initialized then
        if isDebug then
            print("[EffectSystemInit] Already initialized, skipping")
        end
        return
    end
    
    print("[EffectSystemInit] Initializing unified effect system...")
    
    -- Register Body Cultivation provider
    EffectSystem.registerProvider(BodyCultivationProvider)
    print("[EffectSystemInit] Registered Body Cultivation provider")
    
    -- Register Technique provider
    EffectSystem.registerProvider(TechniqueEffectProvider.provider)
    print("[EffectSystemInit] Registered Technique provider")
    
    -- Initialize effect hooks for combat, XP, and zombie perception
    EffectHooks.init()
    print("[EffectSystemInit] Registered effect event hooks")
    
    -- Hook into level-up events to trigger effect recalculation
    Events.LevelPerk.Add(function(player, perk, level, isPerk)
        if not player then return end
        
        -- If Body level changed, mark effects dirty
        if perk == Perks.Body then
            EffectSystem.markDirty(player)
            if isDebug then
                print(string.format("[EffectSystemInit] Body level changed to %d for %s, marked dirty", 
                    level, player:getUsername()))
            end
        end
        
        -- If Fitness or Strength changed, might affect catchup XP
        if perk == Perks.Fitness or perk == Perks.Strength then
            EffectSystem.markDirty(player)
        end
    end)
    
    initialized = true
    
    print("[EffectSystemInit] Unified effect system initialized successfully")
    print("[EffectSystemInit] Old CultivationEffects.lua is now DEPRECATED")
end

-- Initialize on game start (fires once per game session)
Events.OnGameStart.Add(initializeEffectSystem)

return EffectSystemInit

