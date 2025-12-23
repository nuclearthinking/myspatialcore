-- EffectSystem.lua
-- Main orchestrator for the unified effect system
-- Coordinates providers, registry, and applicator

local EffectRegistry = require "effects/EffectRegistry"
local EffectApplicator = require "effects/EffectApplicator"
local EffectProvider = require "effects/EffectProvider"
local LuaCompat = require "utils/LuaCompat"

local EffectSystem = {}

-- Cache debug mode
local isDebug = getDebug()

-- Registered providers
local providers = {}

-- Per-player update tracking
local playerUpdateTracking = {}

--==============================================================================
-- PROVIDER MANAGEMENT
--==============================================================================

--- Register an effect provider
---@param provider table Provider instance from EffectProvider.create()
function EffectSystem.registerProvider(provider)
    if not provider or not provider.sourceName then
        print("[EffectSystem] ERROR: Invalid provider")
        return false
    end
    
    -- Check for duplicate
    for i, p in ipairs(providers) do
        if p.sourceName == provider.sourceName then
            -- Provider already registered, skip silently (idempotent)
            if isDebug then
                print("[EffectSystem] Provider '" .. provider.sourceName .. "' already registered, skipping")
            end
            return false
        end
    end
    
    table.insert(providers, provider)
    print("[EffectSystem] Registered provider: " .. provider.sourceName)
    return true
end

--- Unregister an effect provider
---@param sourceName string Provider source name
function EffectSystem.unregisterProvider(sourceName)
    for i, provider in ipairs(providers) do
        if provider.sourceName == sourceName then
            table.remove(providers, i)
            print("[EffectSystem] Unregistered provider: " .. sourceName)
            return true
        end
    end
    return false
end

--- Get all registered providers
---@return table
function EffectSystem.getProviders()
    return providers
end

--==============================================================================
-- UPDATE LOGIC
--==============================================================================

--- Get or create player update tracking
---@param player IsoPlayer
---@return table
local function getUpdateTracking(player)
    local username = player:getUsername()
    if not playerUpdateTracking[username] then
        playerUpdateTracking[username] = {
            lastBodyLevel = nil,
            lastTechniqueStages = {},
            needsUpdate = true,
        }
    end
    return playerUpdateTracking[username]
end

--- Check if player's effects need updating
---@param player IsoPlayer
---@return boolean needsUpdate
local function checkNeedsUpdate(player)
    local tracking = getUpdateTracking(player)
    
    -- Always update if marked as dirty
    if tracking.needsUpdate then
        return true
    end
    
    -- Check if Body level changed
    local currentBodyLevel = player:getPerkLevel(Perks.Body)
    if tracking.lastBodyLevel ~= currentBodyLevel then
        tracking.lastBodyLevel = currentBodyLevel
        return true
    end
    
    -- Check if any technique stages changed
    -- (This will be called by technique system when stages change)
    
    return false
end

--- Mark player for update (call when source data changes)
---@param player IsoPlayer
function EffectSystem.markDirty(player)
    local tracking = getUpdateTracking(player)
    tracking.needsUpdate = true
    EffectRegistry.markDirty(player)
end

--- Update effects for a player (collect from all providers)
---@param player IsoPlayer
---@param forceUpdate boolean|nil Force update even if not marked dirty
function EffectSystem.updatePlayer(player, forceUpdate)
    if not player or not player:isAlive() then return end
    
    -- Check if update needed
    if not forceUpdate and not checkNeedsUpdate(player) then
        return  -- No changes, skip update
    end
    
    local tracking = getUpdateTracking(player)
    
    if isDebug then
        print(string.format("[EffectSystem] Updating effects for %s (%d providers)", 
            player:getUsername(), #providers))
    end
    
    -- Clear existing effects
    EffectRegistry.clear(player)
    
    -- Collect effects from all providers
    for _, provider in ipairs(providers) do
        EffectProvider.registerEffects(provider, player, EffectRegistry)
    end
    
    -- Recalculate combined effects
    EffectRegistry.recalculate(player)
    
    -- Mark as up-to-date
    tracking.needsUpdate = false
    
    if isDebug then
        print("[EffectSystem] Effects updated for " .. player:getUsername())
    end
end

--- Update effects for all active players
function EffectSystem.updateAllPlayers()
    local numPlayers = getNumActivePlayers()
    for i = 0, numPlayers - 1 do
        local player = getSpecificPlayer(i)
        if player and player:isAlive() then
            EffectSystem.updatePlayer(player)
        end
    end
end

--==============================================================================
-- APPLICATION
--==============================================================================

--- Apply effects to a player (called every minute)
---@param player IsoPlayer
function EffectSystem.applyEffects(player)
    if not player or not player:isAlive() then return end
    
    -- Update effects if needed (lazy update)
    EffectSystem.updatePlayer(player)
    
    -- Apply effects to character
    EffectApplicator.applyAll(player)
end

--- Apply effects to all active players (called every minute)
function EffectSystem.applyToAllPlayers()
    local numPlayers = getNumActivePlayers()
    for i = 0, numPlayers - 1 do
        local player = getSpecificPlayer(i)
        if player and player:isAlive() then
            EffectSystem.applyEffects(player)
        end
    end
end

--==============================================================================
-- DEBUG & DIAGNOSTICS
--==============================================================================

--- Print detailed effect info for a player
---@param player IsoPlayer
function EffectSystem.debugPrint(player)
    if not player then
        player = getPlayer()
    end
    
    if not player then
        print("[EffectSystem] No player found")
        return
    end
    
    print("========================================")
    print("=== [EffectSystem] Debug Info ===")
    print("========================================")
    
    -- Print registry contents (with safety)
    local success = pcall(function()
        EffectRegistry.debugPrint(player)
    end)
    if not success then
        print("[EffectSystem] ERROR: Failed to print registry")
    end
    
    -- Print session stats (with safety)
    success = pcall(function()
        EffectApplicator.printStats(player)
    end)
    if not success then
        print("[EffectSystem] ERROR: Failed to print stats")
    end
    
    -- Print provider info (with safety)
    print("=== Registered Providers ===")
    for i, provider in ipairs(providers) do
        if provider and provider.sourceName then
            local shouldApply = false
            success, shouldApply = pcall(function() return provider.shouldApply(player) end)
            if not success then shouldApply = false end
            
            print(string.format("  %d. %s (active: %s, priority: %d)", 
                i, provider.sourceName, tostring(shouldApply), provider.priority or 0))
        end
    end
    
    print("========================================")
end

--- Get effect breakdown for UI display
---@param player IsoPlayer
---@param effectName string
---@return table|nil { total, sources[] }
function EffectSystem.getEffectBreakdown(player, effectName)
    return EffectRegistry.getDetails(player, effectName)
end

--- Reset all effect data for a player
---@param player IsoPlayer
function EffectSystem.reset(player)
    EffectRegistry.clear(player)
    EffectApplicator.resetStats(player)
    EffectSystem.markDirty(player)
    print("[EffectSystem] Reset effects for " .. player:getUsername())
end

--==============================================================================
-- PUBLIC API (for external systems)
--==============================================================================

-- Re-export modules for convenience
EffectSystem.Registry = EffectRegistry
EffectSystem.Applicator = EffectApplicator
EffectSystem.Provider = EffectProvider

--- Get an effect value for a player (convenience wrapper)
---@param player IsoPlayer
---@param effectName string
---@param defaultValue number|nil
---@return number
function EffectSystem.getEffect(player, effectName, defaultValue)
    return EffectRegistry.get(player, effectName, defaultValue)
end

--- Check if an effect is active
---@param player IsoPlayer
---@param effectName string
---@return boolean
function EffectSystem.hasEffect(player, effectName)
    return EffectRegistry.hasEffect(player, effectName)
end

--==============================================================================
-- GLOBAL DEBUG COMMANDS
--==============================================================================

_G.EffectDebug = {
    --- Print effect info for local player
    status = function()
        local success, err = pcall(function()
            local player = getPlayer()
            if player then
                EffectSystem.debugPrint(player)
            else
                print("[EffectDebug] No local player found")
            end
        end)
        if not success then
            print("[EffectDebug] ERROR: " .. tostring(err))
        end
    end,
    
    --- Force update effects for local player
    update = function()
        local success, err = pcall(function()
            local player = getPlayer()
            if player then
                EffectSystem.updatePlayer(player, true)
                local username = "Unknown"
                pcall(function() username = player:getUsername() end)
                print("[EffectDebug] Force updated effects for " .. username)
            else
                print("[EffectDebug] No local player found")
            end
        end)
        if not success then
            print("[EffectDebug] ERROR: " .. tostring(err))
        end
    end,
    
    --- Reset effects for local player
    reset = function()
        local success, err = pcall(function()
            local player = getPlayer()
            if player then
                EffectSystem.reset(player)
            else
                print("[EffectDebug] No local player found")
            end
        end)
        if not success then
            print("[EffectDebug] ERROR: " .. tostring(err))
        end
    end,
    
    --- Show effect breakdown
    breakdown = function(effectName)
        local success, err = pcall(function()
            local player = getPlayer()
            if not player then
                print("[EffectDebug] No local player found")
                return
            end
            
            local breakdown = EffectSystem.getEffectBreakdown(player, effectName)
            if not breakdown then
                print("[EffectDebug] Effect not found: " .. tostring(effectName))
                return
            end
            
            print(string.format("=== Effect Breakdown: %s ===", tostring(effectName)))
            print(string.format("Total: %.4f (%s)", breakdown.total or 0, breakdown.stackingRule or "unknown"))
            print("Sources:")
            for _, src in ipairs(breakdown.sources or {}) do
                local metaStr = ""
                if src.metadata and LuaCompat.hasKeys(src.metadata) then
                    local parts = {}
                    for k, v in pairs(src.metadata) do
                        table.insert(parts, string.format("%s=%s", tostring(k), tostring(v)))
                    end
                    metaStr = " [" .. table.concat(parts, ", ") .. "]"
                end
                print(string.format("  - %s: %.4f (priority: %d)%s", 
                    src.source or "unknown", src.value or 0, src.priority or 0, metaStr))
            end
        end)
        if not success then
            print("[EffectDebug] ERROR: " .. tostring(err))
        end
    end,
    
    --- List all providers
    providers = function()
        local provs = EffectSystem.getProviders()
        print("=== Registered Effect Providers ===")
        for i, prov in ipairs(provs) do
            print(string.format("%d. %s (priority: %d)", i, prov.sourceName, prov.priority))
        end
    end,
    
    --- Help
    help = function()
        print("=== EffectDebug Console Commands ===")
        print("EffectDebug.status()              - Show detailed effect info")
        print("EffectDebug.update()              - Force update effects")
        print("EffectDebug.reset()               - Reset all effects")
        print("EffectDebug.breakdown('effect')   - Show effect source breakdown")
        print("EffectDebug.providers()           - List all providers")
        print("===================================")
    end,
}

print("[EffectSystem] Debug console commands available: EffectDebug.help()")

--==============================================================================
-- EVENT HANDLERS
--==============================================================================

-- Reset on game load
Events.OnLoad.Add(function()
    playerUpdateTracking = {}
    print("[EffectSystem] Player tracking reset")
end)

-- Apply effects every minute
Events.EveryOneMinute.Add(function()
    EffectSystem.applyToAllPlayers()
end)

-- Print stats every 10 minutes (debug)
if isDebug then
    Events.EveryTenMinutes.Add(function()
        local player = getPlayer()
        if player then
            EffectApplicator.printStats(player)
        end
    end)
end

print("[EffectSystem] Core event handlers registered")

return EffectSystem

