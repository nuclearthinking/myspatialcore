-- TechniqueSystem.lua
-- Main entry point for the Technique System
-- Implements wuxia-style stage progression (功法境界)
-- Loads all components and technique definitions

local TechniqueSystem = {}

-- Export core modules for external access
TechniqueSystem.Registry = require "techniques/TechniqueRegistry"
TechniqueSystem.Manager = require "techniques/TechniqueManager"
TechniqueSystem.Events = require "techniques/TechniqueEvents"

-- Re-export stage constants for convenience
TechniqueSystem.STAGES = TechniqueSystem.Registry.STAGES

-- Load all technique definitions
local function loadTechniqueDefinitions()
    print("[TechniqueSystem] Loading technique definitions...")
    
    -- Load each technique definition file
    -- Add new techniques here as they are created
    require "techniques/definitions/TechniqueDevouringElephant"  -- Metabolism technique (吞象之术)
    require "techniques/definitions/TechniqueMovementEconomy"
    require "techniques/definitions/TechniqueEnergyStabilization"
    
    -- Print loaded techniques
    local ids = TechniqueSystem.Registry.getAllIds()
    print("[TechniqueSystem] Loaded " .. #ids .. " techniques:")
    for _, id in ipairs(ids) do
        local tech = TechniqueSystem.Registry.get(id)
        print("  - " .. id .. " (" .. (tech.name or "unnamed") .. ")")
    end
end

--==============================================================================
-- PUBLIC API
--==============================================================================

--- Check if a player has a specific technique
---@param player IsoPlayer
---@param techniqueId string
---@return boolean
function TechniqueSystem.hasTechnique(player, techniqueId)
    return TechniqueSystem.Manager.hasLearned(player, techniqueId)
end

--- Get technique stage for a player (wuxia-style 1-5)
---@param player IsoPlayer
---@param techniqueId string
---@return number stage (0 if not learned, 1-5 otherwise)
function TechniqueSystem.getStage(player, techniqueId)
    return TechniqueSystem.Manager.getStage(player, techniqueId)
end

--- Get technique level for a player (legacy alias for getStage)
---@param player IsoPlayer
---@param techniqueId string
---@return number level (0 if not learned)
function TechniqueSystem.getLevel(player, techniqueId)
    return TechniqueSystem.Manager.getLevel(player, techniqueId)
end

--- Get stage display name (Chinese + English)
---@param stage number Stage number (1-5)
---@return string displayName
function TechniqueSystem.getStageName(stage)
    return TechniqueSystem.Registry.getStageDisplayName(stage)
end

--- Get technique effects for a player
---@param player IsoPlayer
---@param techniqueId string
---@return table effects
function TechniqueSystem.getEffects(player, techniqueId)
    return TechniqueSystem.Manager.getEffects(player, techniqueId)
end

--- Get a specific effect value from a technique
---@param player IsoPlayer
---@param techniqueId string
---@param effectName string
---@param default number Default value if not found
---@return number
function TechniqueSystem.getEffect(player, techniqueId, effectName, default)
    local effects = TechniqueSystem.getEffects(player, techniqueId)
    return effects[effectName] or default or 0
end

--- Learn a technique (usually called from item use or event)
---@param player IsoPlayer
---@param techniqueId string
---@param consumeItem boolean
---@return boolean success
---@return string|nil message
function TechniqueSystem.learn(player, techniqueId, consumeItem)
    return TechniqueSystem.Manager.learn(player, techniqueId, consumeItem)
end

--- Debug: Force learn a technique (for testing)
---@param player IsoPlayer
---@param techniqueId string
function TechniqueSystem.debugLearn(player, techniqueId)
    local technique = TechniqueSystem.Registry.get(techniqueId)
    if not technique then
        print("[TechniqueSystem] ERROR: Unknown technique: " .. techniqueId)
        return
    end
    
    -- Bypass requirements for debug
    local modData = player:getModData()
    local key = "CultivationTechniques"
    if not modData[key] then
        modData[key] = { techniques = {} }
    end
    
    modData[key].techniques[techniqueId] = {
        learned = true,
        stage = 1,  -- Start at Initiate
        level = 1,  -- Legacy compatibility
        xp = 0,
        totalXP = 0,
    }
    
    -- Reload into manager
    TechniqueSystem.Manager.loadPlayerData(player)
    
    local stageData = TechniqueSystem.Registry.STAGE_DATA[1]
    local stageName = stageData and stageData.name or "Initiate"
    
    print("[TechniqueSystem] Debug: Force learned " .. techniqueId .. " at stage 1 (" .. stageName .. ")")
    HaloTextHelper.addText(player, "[col=255,100,100][DEBUG] Learned: " .. techniqueId .. " - " .. stageName .. "[/]")
end

--- Debug: Set technique stage (for testing)
---@param player IsoPlayer
---@param techniqueId string
---@param stage number (1-5)
function TechniqueSystem.debugSetStage(player, techniqueId, stage)
    local modData = player:getModData()
    local key = "CultivationTechniques"
    
    -- Clamp stage to valid range
    stage = math.max(1, math.min(5, stage))
    
    if modData[key] and modData[key].techniques[techniqueId] then
        modData[key].techniques[techniqueId].stage = stage
        modData[key].techniques[techniqueId].level = stage  -- Legacy
        modData[key].techniques[techniqueId].xp = 0
        TechniqueSystem.Manager.loadPlayerData(player)
        
        local stageData = TechniqueSystem.Registry.STAGE_DATA[stage]
        local stageName = stageData and stageData.name or tostring(stage)
        
        print("[TechniqueSystem] Debug: Set " .. techniqueId .. " to stage " .. stage .. " (" .. stageName .. ")")
        HaloTextHelper.addText(player, "[col=255,100,100][DEBUG] " .. techniqueId .. " → " .. stageName .. "[/]")
    else
        print("[TechniqueSystem] ERROR: Technique not learned: " .. techniqueId)
    end
end

--- Legacy: Set technique level (alias for debugSetStage)
---@param player IsoPlayer
---@param techniqueId string
---@param level number
function TechniqueSystem.debugSetLevel(player, techniqueId, level)
    TechniqueSystem.debugSetStage(player, techniqueId, level)
end

--- Debug: Print all technique status
---@param player IsoPlayer
function TechniqueSystem.debugStatus(player)
    TechniqueSystem.Manager.printStatus(player)
end

--- Debug: Advance a technique to next stage
---@param player IsoPlayer
---@param techniqueId string
function TechniqueSystem.debugAdvanceStage(player, techniqueId)
    local currentStage = TechniqueSystem.getStage(player, techniqueId)
    if currentStage == 0 then
        print("[TechniqueSystem] ERROR: Technique not learned: " .. techniqueId)
        return
    end
    
    local technique = TechniqueSystem.Registry.get(techniqueId)
    local maxStage = technique and technique.maxStage or 5
    
    if currentStage >= maxStage then
        local stageData = TechniqueSystem.Registry.STAGE_DATA[currentStage]
        print("[TechniqueSystem] Already at max stage: " .. (stageData and stageData.name or "Transcendent"))
        return
    end
    
    TechniqueSystem.debugSetStage(player, techniqueId, currentStage + 1)
end

--- Debug: Reset a specific technique to stage 1 (Initiate)
---@param player IsoPlayer
---@param techniqueId string
function TechniqueSystem.debugResetTechnique(player, techniqueId)
    local modData = player:getModData()
    local key = "CultivationTechniques"
    
    if not modData[key] or not modData[key].techniques[techniqueId] then
        print("[TechniqueSystem] ERROR: Technique not learned: " .. techniqueId)
        return
    end
    
    modData[key].techniques[techniqueId].stage = 1
    modData[key].techniques[techniqueId].level = 1
    modData[key].techniques[techniqueId].xp = 0
    modData[key].techniques[techniqueId].totalXP = 0
    
    TechniqueSystem.Manager.loadPlayerData(player)
    
    print("[TechniqueSystem] Debug: Reset " .. techniqueId .. " to stage 1 (Initiate)")
    HaloTextHelper.addText(player, "[col=255,100,100][DEBUG] Reset: " .. techniqueId .. " → Initiate[/]")
end

--- Debug: Reset ALL techniques for a player to stage 1
---@param player IsoPlayer
function TechniqueSystem.debugResetAllTechniques(player)
    local modData = player:getModData()
    local key = "CultivationTechniques"
    
    if not modData[key] or not modData[key].techniques then
        print("[TechniqueSystem] No techniques to reset for " .. player:getUsername())
        return
    end
    
    local count = 0
    for techId, techData in pairs(modData[key].techniques) do
        if techData.learned then
            techData.stage = 1
            techData.level = 1
            techData.xp = 0
            techData.totalXP = 0
            count = count + 1
            print("[TechniqueSystem] Debug: Reset " .. techId .. " to stage 1")
        end
    end
    
    TechniqueSystem.Manager.loadPlayerData(player)
    
    print("[TechniqueSystem] Debug: Reset " .. count .. " techniques for " .. player:getUsername())
    HaloTextHelper.addText(player, "[col=255,100,100][DEBUG] Reset " .. count .. " techniques to Initiate[/]")
end

--- Debug: Forget (unlearn) a specific technique
---@param player IsoPlayer
---@param techniqueId string
function TechniqueSystem.debugForgetTechnique(player, techniqueId)
    local modData = player:getModData()
    local key = "CultivationTechniques"
    
    if not modData[key] or not modData[key].techniques[techniqueId] then
        print("[TechniqueSystem] ERROR: Technique not learned: " .. techniqueId)
        return
    end
    
    modData[key].techniques[techniqueId] = nil
    TechniqueSystem.Manager.loadPlayerData(player)
    
    print("[TechniqueSystem] Debug: Forgot technique " .. techniqueId)
    HaloTextHelper.addText(player, "[col=255,100,100][DEBUG] Forgot: " .. techniqueId .. "[/]")
end

--- Debug: Forget ALL techniques for a player
---@param player IsoPlayer
function TechniqueSystem.debugForgetAllTechniques(player)
    local modData = player:getModData()
    local key = "CultivationTechniques"
    
    if modData[key] then
        modData[key].techniques = {}
    end
    
    TechniqueSystem.Manager.loadPlayerData(player)
    
    print("[TechniqueSystem] Debug: Forgot all techniques for " .. player:getUsername())
    HaloTextHelper.addText(player, "[col=255,100,100][DEBUG] Forgot all techniques[/]")
end

--- Debug: Learn ALL techniques at stage 1
---@param player IsoPlayer
function TechniqueSystem.debugLearnAll(player)
    local modData = player:getModData()
    local key = "CultivationTechniques"
    
    if not modData[key] then
        modData[key] = { techniques = {} }
    end
    
    local allIds = TechniqueSystem.Registry.getAllIds()
    local count = 0
    
    for _, techId in ipairs(allIds) do
        modData[key].techniques[techId] = {
            learned = true,
            stage = 1,
            level = 1,
            xp = 0,
            totalXP = 0,
        }
        count = count + 1
        print("[TechniqueSystem] Debug: Learned " .. techId)
    end
    
    TechniqueSystem.Manager.loadPlayerData(player)
    
    print("[TechniqueSystem] Debug: Learned " .. count .. " techniques for " .. player:getUsername())
    HaloTextHelper.addText(player, "[col=255,100,100][DEBUG] Learned " .. count .. " techniques at Initiate[/]")
end

--- Debug: Max out ALL techniques to stage 5 (Transcendent)
---@param player IsoPlayer
function TechniqueSystem.debugMaxAllTechniques(player)
    local modData = player:getModData()
    local key = "CultivationTechniques"
    
    if not modData[key] then
        modData[key] = { techniques = {} }
    end
    
    local allIds = TechniqueSystem.Registry.getAllIds()
    local count = 0
    
    for _, techId in ipairs(allIds) do
        modData[key].techniques[techId] = {
            learned = true,
            stage = 5,
            level = 5,
            xp = 0,
            totalXP = 9999,
        }
        count = count + 1
        print("[TechniqueSystem] Debug: Maxed " .. techId .. " to Transcendent")
    end
    
    TechniqueSystem.Manager.loadPlayerData(player)
    
    print("[TechniqueSystem] Debug: Maxed " .. count .. " techniques for " .. player:getUsername())
    HaloTextHelper.addText(player, "[col=255,100,100][DEBUG] Maxed " .. count .. " techniques to Transcendent[/]")
end

--==============================================================================
-- GLOBAL DEBUG FUNCTIONS (callable from Lua debug console)
--==============================================================================

-- These are exposed globally for easy console access
-- Usage from debug console: TechDebug.resetAll() or TechDebug.status()

_G.TechDebug = {
    --- Get the local player (convenience for console)
    getPlayer = function()
        return getPlayer()
    end,
    
    --- Print technique status for local player
    status = function()
        local player = getPlayer()
        if player then
            TechniqueSystem.debugStatus(player)
        else
            print("[TechDebug] No local player found")
        end
    end,
    
    --- Reset a specific technique for local player
    --- Usage: TechDebug.reset("movement_economy")
    reset = function(techniqueId)
        local player = getPlayer()
        if player then
            TechniqueSystem.debugResetTechnique(player, techniqueId)
        else
            print("[TechDebug] No local player found")
        end
    end,
    
    --- Reset ALL techniques for local player to stage 1
    --- Usage: TechDebug.resetAll()
    resetAll = function()
        local player = getPlayer()
        if player then
            TechniqueSystem.debugResetAllTechniques(player)
        else
            print("[TechDebug] No local player found")
        end
    end,
    
    --- Forget a specific technique
    --- Usage: TechDebug.forget("movement_economy")
    forget = function(techniqueId)
        local player = getPlayer()
        if player then
            TechniqueSystem.debugForgetTechnique(player, techniqueId)
        else
            print("[TechDebug] No local player found")
        end
    end,
    
    --- Forget ALL techniques
    --- Usage: TechDebug.forgetAll()
    forgetAll = function()
        local player = getPlayer()
        if player then
            TechniqueSystem.debugForgetAllTechniques(player)
        else
            print("[TechDebug] No local player found")
        end
    end,
    
    --- Learn a specific technique at stage 1
    --- Usage: TechDebug.learn("movement_economy")
    learn = function(techniqueId)
        local player = getPlayer()
        if player then
            TechniqueSystem.debugLearn(player, techniqueId)
        else
            print("[TechDebug] No local player found")
        end
    end,
    
    --- Learn ALL techniques at stage 1
    --- Usage: TechDebug.learnAll()
    learnAll = function()
        local player = getPlayer()
        if player then
            TechniqueSystem.debugLearnAll(player)
        else
            print("[TechDebug] No local player found")
        end
    end,
    
    --- Set technique to specific stage
    --- Usage: TechDebug.setStage("movement_economy", 3)
    setStage = function(techniqueId, stage)
        local player = getPlayer()
        if player then
            TechniqueSystem.debugSetStage(player, techniqueId, stage)
        else
            print("[TechDebug] No local player found")
        end
    end,
    
    --- Advance technique to next stage
    --- Usage: TechDebug.advance("movement_economy")
    advance = function(techniqueId)
        local player = getPlayer()
        if player then
            TechniqueSystem.debugAdvanceStage(player, techniqueId)
        else
            print("[TechDebug] No local player found")
        end
    end,
    
    --- Max out ALL techniques to Transcendent
    --- Usage: TechDebug.maxAll()
    maxAll = function()
        local player = getPlayer()
        if player then
            TechniqueSystem.debugMaxAllTechniques(player)
        else
            print("[TechDebug] No local player found")
        end
    end,
    
    --- List all registered technique IDs
    --- Usage: TechDebug.list()
    list = function()
        local ids = TechniqueSystem.Registry.getAllIds()
        print("[TechDebug] Registered techniques:")
        for _, id in ipairs(ids) do
            local tech = TechniqueSystem.Registry.get(id)
            print("  - " .. id .. " (" .. (tech.name or "unnamed") .. ")")
        end
    end,
    
    --- Print help
    --- Usage: TechDebug.help()
    help = function()
        print("=== TechDebug Console Commands ===")
        print("TechDebug.status()              - Show technique status")
        print("TechDebug.list()                - List all technique IDs")
        print("TechDebug.reset('id')           - Reset specific technique to stage 1")
        print("TechDebug.resetAll()            - Reset ALL techniques to stage 1")
        print("TechDebug.forget('id')          - Forget specific technique")
        print("TechDebug.forgetAll()           - Forget ALL techniques")
        print("TechDebug.learn('id')           - Learn specific technique")
        print("TechDebug.learnAll()            - Learn ALL techniques")
        print("TechDebug.setStage('id', 3)     - Set technique to stage 1-5")
        print("TechDebug.advance('id')         - Advance technique to next stage")
        print("TechDebug.maxAll()              - Max ALL techniques to Transcendent")
        print("===================================")
    end,
}

print("[TechniqueSystem] Debug console commands available: TechDebug.help()")

--==============================================================================
-- INITIALIZATION
--==============================================================================

local function initialize()
    loadTechniqueDefinitions()
    print("[TechniqueSystem] Cultivation Technique System initialized")
    print("[TechniqueSystem] Stage progression: Initiate → Adept → Accomplished → Perfected → Transcendent")
end

-- Initialize on game boot
Events.OnGameBoot.Add(initialize)

return TechniqueSystem

