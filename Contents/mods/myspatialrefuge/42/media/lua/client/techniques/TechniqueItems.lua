-- TechniqueItems.lua
-- Handles item interactions for technique manuscripts
-- Adds context menu options to learn techniques from items

local TechniqueSystem = require "techniques/TechniqueSystem"

local TechniqueItems = {}

-- Mapping of item types to technique IDs
local MANUSCRIPT_MAPPINGS = {
    ["TechniqueManuscript_Absorption"] = "camels_hump",  -- Legacy: Fat absorption/metabolism
    ["TechniqueManuscript_Metabolism"] = "camels_hump",  -- Camel's Hump (驼峰蓄能术)
    ["TechniqueManuscript_Movement"] = "movement_economy",
    ["TechniqueManuscript_Stabilization"] = "energy_stabilization",
}

-- Check if an item is a technique manuscript
---@param item InventoryItem
---@return string|nil techniqueId
local function getManuscriptTechnique(item)
    if not item then return nil end
    local itemType = item:getType()
    return MANUSCRIPT_MAPPINGS[itemType]
end

-- Called when player tries to learn from a manuscript
---@param player IsoPlayer
---@param item InventoryItem
local function onLearnTechnique(player, item)
    local techniqueId = getManuscriptTechnique(item)
    if not techniqueId then
        player:Say("This manuscript is unreadable...")
        return
    end
    
    local technique = TechniqueSystem.Registry.get(techniqueId)
    if not technique then
        print("[TechniqueItems] ERROR: Unknown technique: " .. techniqueId)
        return
    end
    
    -- Check if already learned
    if TechniqueSystem.hasTechnique(player, techniqueId) then
        player:Say("I already know this technique.")
        return
    end
    
    -- Check requirements (except item, since we're using it)
    local req = technique.requirements or {}
    
    -- Check Body level
    if req.minBodyLevel and req.minBodyLevel > 0 then
        local bodyLevel = player:getPerkLevel(Perks.Body)
        if bodyLevel < req.minBodyLevel then
            player:Say("I need more cultivation to understand this... (Body Level " .. req.minBodyLevel .. " required)")
            return
        end
    end
    
    -- Learn the technique
    local success, message = TechniqueSystem.learn(player, techniqueId, false)
    
    if success then
        -- Remove the manuscript after learning
        local inventory = player:getInventory()
        inventory:Remove(item)
        
        -- Play learning sound/animation
        player:playSound("PageFlip")
        
        -- Show flavor text
        player:Say("I understand now...")
    else
        player:Say(message or "I cannot learn this technique.")
    end
end

-- Add context menu option for manuscripts
---@param player number Player index
---@param context ISContextMenu
---@param items table Selected items
local function onFillInventoryObjectContextMenu(player, context, items)
    local playerObj = getSpecificPlayer(player)
    if not playerObj then return end
    
    -- Check each selected item
    for _, itemData in ipairs(items) do
        local item = itemData
        
        -- Handle item stacks
        if type(itemData) == "table" then
            item = itemData.items and itemData.items[1] or itemData
        end
        
        if item and item.getType then
            local techniqueId = getManuscriptTechnique(item)
            
            if techniqueId then
                local technique = TechniqueSystem.Registry.get(techniqueId)
                local displayName = technique and technique.name or techniqueId
                
                -- Check if already learned
                if TechniqueSystem.hasTechnique(playerObj, techniqueId) then
                    local option = context:addOption("Already Learned: " .. displayName, nil, nil)
                    option.notAvailable = true
                else
                    -- Check requirements for tooltip
                    local canLearn, reason = TechniqueSystem.Registry.canLearn(playerObj, techniqueId)
                    
                    if canLearn then
                        context:addOption("Study: " .. displayName, playerObj, onLearnTechnique, item)
                    else
                        local option = context:addOption("Study: " .. displayName .. " (" .. reason .. ")", nil, nil)
                        option.notAvailable = true
                    end
                end
            end
        end
    end
end

-- Initialize
local function initialize()
    Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryObjectContextMenu)
    print("[TechniqueItems] Item context menus initialized")
end

Events.OnGameBoot.Add(initialize)

return TechniqueItems


