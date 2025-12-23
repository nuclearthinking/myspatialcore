-- TechniqueManager.lua
-- Manages player technique state: learned techniques, XP, stages
-- Implements wuxia-style stage progression (功法境界)

local TechniqueRegistry = require "techniques/TechniqueRegistry"

local TechniqueManager = {}

-- Per-player technique data storage
-- Structure: playerData[username] = { techniques = { [id] = { stage, xp, learned } } }
local playerData = {}

-- Cache debug mode
local isDebug = getDebug()

-- Mod data key for saving
local MOD_DATA_KEY = "CultivationTechniques"

--[[
    Player Technique Data Structure:
    {
        techniques = {
            ["technique_id"] = {
                learned = true,         -- Has the technique been learned?
                stage = 1,              -- Current stage (1-5, 入门 to 极境)
                xp = 0,                 -- Current XP towards next stage
                totalXP = 0,            -- Total XP earned (for stats)
            },
        },
    }
    
    Note: 'level' field is kept for backwards compatibility with saves
]]

--- Get or initialize player data
---@param player IsoPlayer
---@return table playerTechData
local function getPlayerData(player)
    local username = player:getUsername()
    if not playerData[username] then
        playerData[username] = {
            techniques = {},
        }
    end
    return playerData[username]
end

--- Get technique data for a player
---@param player IsoPlayer
---@param techniqueId string
---@return table|nil techData
function TechniqueManager.getTechniqueData(player, techniqueId)
    local data = getPlayerData(player)
    return data.techniques[techniqueId]
end

--- Check if player has learned a technique
---@param player IsoPlayer
---@param techniqueId string
---@return boolean
function TechniqueManager.hasLearned(player, techniqueId)
    local techData = TechniqueManager.getTechniqueData(player, techniqueId)
    return techData and techData.learned == true
end

--- Get technique stage for a player (0 if not learned)
---@param player IsoPlayer
---@param techniqueId string
---@return number stage (0-5)
function TechniqueManager.getStage(player, techniqueId)
    local techData = TechniqueManager.getTechniqueData(player, techniqueId)
    if not techData or not techData.learned then
        return 0
    end
    -- Support both 'stage' and legacy 'level' field, clamp to valid range
    local stage = techData.stage or techData.level or 1
    return math.max(1, math.min(5, stage))
end

--- Legacy compatibility: getLevel maps to getStage
---@param player IsoPlayer
---@param techniqueId string
---@return number level/stage
function TechniqueManager.getLevel(player, techniqueId)
    return TechniqueManager.getStage(player, techniqueId)
end

--- Get technique effects for a player
---@param player IsoPlayer
---@param techniqueId string
---@return table effects (empty if not learned)
function TechniqueManager.getEffects(player, techniqueId)
    local stage = TechniqueManager.getStage(player, techniqueId)
    if stage == 0 then
        return {}
    end
    
    local technique = TechniqueRegistry.get(techniqueId)
    if not technique then
        return {}
    end
    
    return technique.getEffects(stage)
end

--- Learn a technique (if requirements are met)
---@param player IsoPlayer
---@param techniqueId string
---@param consumeItem boolean Whether to consume required item
---@return boolean success
---@return string|nil message
function TechniqueManager.learn(player, techniqueId, consumeItem)
    -- Check if already learned
    if TechniqueManager.hasLearned(player, techniqueId) then
        return false, "Already learned"
    end
    
    -- Check requirements
    local canLearn, reason = TechniqueRegistry.canLearn(player, techniqueId)
    if not canLearn then
        return false, reason
    end
    
    local technique = TechniqueRegistry.get(techniqueId)
    if not technique then
        return false, "Technique not found"
    end
    
    -- Consume item if required
    if consumeItem and technique.requirements.item then
        local inventory = player:getInventory()
        local item = inventory:getFirstTypeRecurse(technique.requirements.item)
        if item then
            inventory:Remove(item)
        end
    end
    
    -- Initialize technique data at stage 1 (入门)
    local data = getPlayerData(player)
    data.techniques[techniqueId] = {
        learned = true,
        stage = 1,  -- Start at 入门 (Entry)
        xp = 0,
        totalXP = 0,
    }
    
    -- Call onLearn callback
    if technique.onLearn then
        technique.onLearn(player)
    end
    
    -- Notify player with stage name
    local displayName = technique.name or techniqueId
    local stageData = TechniqueRegistry.STAGE_DATA[1]
    local stageName = stageData and stageData.name or "Initiate"
    
    HaloTextHelper.addText(player, string.format("[col=200,180,255]Technique Learned: %s[/]", displayName))
    HaloTextHelper.addText(player, string.format("[col=180,180,200]Stage: %s[/]", stageName))
    player:playSound("cultivation_absorb")
    
    if isDebug then
        print("[TechniqueManager] " .. player:getUsername() .. " learned technique: " .. techniqueId)
    end
    
    -- Save data
    TechniqueManager.savePlayerData(player)
    
    -- Notify effect system
    local success, EffectSystem = pcall(require, "effects/EffectSystem")
    if success and EffectSystem then
        EffectSystem.markDirty(player)
    end
    
    -- Invalidate levelable cache (new technique can be leveled)
    local success2, TechniqueEvents = pcall(require, "techniques/TechniqueEvents")
    if success2 and TechniqueEvents and TechniqueEvents.invalidateLevelableCache then
        TechniqueEvents.invalidateLevelableCache(player)
    end
    
    return true, "Learned " .. displayName
end

--- Award XP to a technique
---@param player IsoPlayer
---@param techniqueId string
---@param xpAmount number
---@return boolean stagedUp
function TechniqueManager.addXP(player, techniqueId, xpAmount)
    if not TechniqueManager.hasLearned(player, techniqueId) then
        return false
    end
    
    local technique = TechniqueRegistry.get(techniqueId)
    if not technique then
        return false
    end
    
    local data = getPlayerData(player)
    local techData = data.techniques[techniqueId]
    
    -- Ensure stage field exists (migrate from level if needed)
    if not techData.stage and techData.level then
        techData.stage = math.max(1, math.min(5, techData.level))
    end
    techData.stage = math.max(1, math.min(5, techData.stage or 1))
    
    -- Check if already at max stage
    local maxStage = technique.maxStage or 5
    if techData.stage >= maxStage then
        return false
    end
    
    -- Add XP
    techData.xp = techData.xp + xpAmount
    techData.totalXP = techData.totalXP + xpAmount
    
    -- Check for stage advancement
    local stagedUp = false
    local xpRequired = TechniqueRegistry.getXPForStage(technique, techData.stage)
    
    -- Safety: prevent infinite loop if xpRequired is invalid
    if xpRequired <= 0 then
        xpRequired = 100  -- Fallback to default
        print("[TechniqueManager] WARNING: Invalid XP requirement for " .. techniqueId .. ", using fallback")
    end
    
    while techData.xp >= xpRequired and techData.stage < maxStage do
        techData.xp = techData.xp - xpRequired
        techData.stage = techData.stage + 1
        stagedUp = true
        
        -- Get stage display info
        local stageData = TechniqueRegistry.STAGE_DATA[techData.stage]
        local stageName = stageData and stageData.name or tostring(techData.stage)
        local displayName = technique.name or techniqueId
        
        -- Notify player with atmospheric message
        HaloTextHelper.addText(player, string.format(
            "[col=255,215,0]%s → %s[/]", 
            displayName, stageName
        ))
        -- Play skill level-up sound on stage breakthrough
        player:getEmitter():playSound("GainExperienceLevel")
        
        -- Call onStageUp callback (preferred)
        if technique.onStageUp then
            technique.onStageUp(player, techData.stage)
        -- Fallback to legacy onLevelUp
        elseif technique.onLevelUp then
            technique.onLevelUp(player, techData.stage)
        end
        
        if isDebug then
            print(string.format("[TechniqueManager] %s advanced %s to stage %d (%s)", 
                player:getUsername(), techniqueId, techData.stage, stageName))
        end
        
        -- Get XP for next stage (with safety check)
        xpRequired = TechniqueRegistry.getXPForStage(technique, techData.stage)
        if xpRequired <= 0 or xpRequired == math.huge then
            break  -- At max stage or invalid
        end
    end
    
    -- Keep legacy 'level' field in sync for save compatibility
    techData.level = techData.stage
    
    -- Notify effect system if technique staged up
    if stagedUp then
        -- Lazy load to avoid circular dependencies
        local success, EffectSystem = pcall(require, "effects/EffectSystem")
        if success and EffectSystem then
            EffectSystem.markDirty(player)
        end
        
        -- Invalidate levelable cache (technique may now be maxed)
        local success2, TechniqueEvents = pcall(require, "techniques/TechniqueEvents")
        if success2 and TechniqueEvents and TechniqueEvents.invalidateLevelableCache then
            TechniqueEvents.invalidateLevelableCache(player)
        end
    end
    
    return stagedUp
end

--- Process an event for technique XP
--- Called by TechniqueEvents when game events occur
---@param player IsoPlayer
---@param eventName string
---@param eventData table
function TechniqueManager.processEvent(player, eventName, eventData)
    local mappings = TechniqueRegistry.getTechniquesForEvent(eventName)
    
    for _, mapping in ipairs(mappings) do
        local techniqueId = mapping.techniqueId
        
        -- Check if player has learned this technique
        if TechniqueManager.hasLearned(player, techniqueId) then
            -- OPTIMIZATION: Skip if technique is already at max level
            local shouldProcess = true
            local technique = TechniqueRegistry.get(techniqueId)
            if technique then
                local techData = TechniqueManager.getTechniqueData(player, techniqueId)
                local maxStage = technique.maxStage or 5
                
                if techData and techData.stage >= maxStage then
                    -- Already at max level, skip all processing for this technique
                    shouldProcess = false
                end
            end
            
            if shouldProcess then
                local stage = TechniqueManager.getStage(player, techniqueId)
                
                -- Check condition (if any)
                local conditionMet = true
                if mapping.condition then
                    conditionMet = mapping.condition(player, eventData)
                end
                
                if conditionMet then
                    -- Calculate XP gain (pass stage instead of level)
                    local xpGain = 0
                    if type(mapping.xpGain) == "function" then
                        xpGain = mapping.xpGain(player, eventData, stage)
                    else
                        xpGain = mapping.xpGain or 1
                    end
                    
                    if xpGain > 0 then
                        TechniqueManager.addXP(player, techniqueId, xpGain)
                        
                        if isDebug then
                            print(string.format("[TechniqueManager] %s: +%.2f XP to %s (event: %s)",
                                player:getUsername(), xpGain, techniqueId, eventName))
                        end
                    end
                end
            end
        end
    end
end

--- Get all learned techniques for a player
---@param player IsoPlayer
---@return table Array of {id, stage, xp, technique}
function TechniqueManager.getLearnedTechniques(player)
    local data = getPlayerData(player)
    local learned = {}
    
    for id, techData in pairs(data.techniques) do
        if techData.learned then
            local technique = TechniqueRegistry.get(id)
            -- Support both stage and legacy level
            local stage = techData.stage or techData.level or 1
            table.insert(learned, {
                id = id,
                stage = stage,
                level = stage,  -- Legacy compatibility
                xp = techData.xp,
                totalXP = techData.totalXP,
                technique = technique,
            })
        end
    end
    
    return learned
end

--- Save player technique data to mod data
---@param player IsoPlayer
function TechniqueManager.savePlayerData(player)
    local modData = player:getModData()
    local data = getPlayerData(player)
    
    -- Ensure stage/level sync before saving
    for _, techData in pairs(data.techniques) do
        if techData.stage then
            techData.level = techData.stage  -- Keep legacy field
        elseif techData.level then
            techData.stage = techData.level  -- Migrate legacy saves
        end
    end
    
    modData[MOD_DATA_KEY] = data
end

--- Migrate old 10-level system to new 5-stage system
--- Maps level 1-10 to stage 1-5 proportionally
---@param oldLevel number Level from old save (1-10)
---@return number newStage Stage in new system (1-5)
local function migrateLevel(oldLevel)
    if not oldLevel or oldLevel <= 0 then
        return 1
    end
    
    -- Map old levels 1-10 to new stages 1-5:
    -- Level 1-2 → Stage 1 (Initiate)
    -- Level 3-4 → Stage 2 (Adept)
    -- Level 5-6 → Stage 3 (Accomplished)
    -- Level 7-8 → Stage 4 (Perfected)
    -- Level 9-10 → Stage 5 (Transcendent)
    local newStage = math.ceil(oldLevel / 2)
    
    -- Clamp to valid range 1-5
    return math.max(1, math.min(5, newStage))
end

--- Load player technique data from mod data
---@param player IsoPlayer
function TechniqueManager.loadPlayerData(player)
    local modData = player:getModData()
    local savedData = modData[MOD_DATA_KEY]
    
    if savedData then
        local username = player:getUsername()
        local migrated = false
        
        -- Migrate legacy saves from 10-level to 5-stage system
        if savedData.techniques then
            for techId, techData in pairs(savedData.techniques) do
                -- Check if this needs migration (has level but no stage, or stage > 5)
                local needsMigration = false
                local oldLevel = techData.level or techData.stage or 1
                
                if not techData.stage and techData.level then
                    -- Old save with only 'level' field
                    needsMigration = true
                elseif techData.stage and techData.stage > 5 then
                    -- Somehow has invalid stage (shouldn't happen, but safety)
                    needsMigration = true
                    oldLevel = techData.stage
                end
                
                if needsMigration then
                    local newStage = migrateLevel(oldLevel)
                    techData.stage = newStage
                    techData.level = newStage  -- Keep in sync
                    techData.xp = 0  -- Reset XP (fairest approach)
                    migrated = true
                    
                    print(string.format("[TechniqueManager] Migrated %s: level %d → stage %d", 
                        techId, oldLevel, newStage))
                end
            end
        end
        
        playerData[username] = savedData
        
        -- Save immediately if migrated to persist changes
        if migrated then
            modData[MOD_DATA_KEY] = savedData
            print("[TechniqueManager] Save migrated from 10-level to 5-stage system")
        end
        
        if isDebug then
            local count = 0
            for _ in pairs(savedData.techniques or {}) do
                count = count + 1
            end
            print("[TechniqueManager] Loaded " .. count .. " techniques for " .. username)
        end
    end
end

--- Clear player data (for testing)
---@param player IsoPlayer
function TechniqueManager.clearPlayerData(player)
    local username = player:getUsername()
    playerData[username] = nil
    
    local modData = player:getModData()
    modData[MOD_DATA_KEY] = nil
end

--- Debug: Print player technique status
---@param player IsoPlayer
function TechniqueManager.printStatus(player)
    print("=== [TechniqueManager] Player Technique Status ===")
    print("Player: " .. player:getUsername())
    
    local learned = TechniqueManager.getLearnedTechniques(player)
    if #learned == 0 then
        print("  No techniques learned")
    else
        for _, data in ipairs(learned) do
            local technique = data.technique
            local maxStage = technique and technique.maxStage or 5
            local xpRequired = technique and TechniqueRegistry.getXPForStage(technique, data.stage) or 100
            local stageData = TechniqueRegistry.STAGE_DATA[data.stage]
            local stageName = stageData and stageData.name or tostring(data.stage)
            
            print(string.format("  %s: %s (%d/%d) - XP: %.1f/%.1f",
                data.id, stageName, data.stage, maxStage, data.xp, xpRequired))
        end
    end
    print("================================================")
end

return TechniqueManager

