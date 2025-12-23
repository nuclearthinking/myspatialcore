-- TechniqueUI.lua
-- Main UI manager for the Technique System
-- Handles window management, keybinds, and integration

require "ui/TechniqueWindow"

TechniqueUI = {}
TechniqueUI.players = {}

-- Window key for tracking
local WINDOW_KEY = "TechniqueWindow"

--==============================================================================
-- WINDOW MANAGEMENT
--==============================================================================

--- Get the window instance for a player
---@param playerNum number
---@return TechniqueWindow|nil
function TechniqueUI.GetWindowInstance(playerNum)
    local playerData = TechniqueUI.players[playerNum]
    if playerData and playerData.windows and playerData.windows[WINDOW_KEY] then
        return playerData.windows[WINDOW_KEY].instance
    end
    return nil
end

--- Check if window is open for a player
---@param playerNum number
---@return boolean
function TechniqueUI.IsWindowOpen(playerNum)
    return TechniqueUI.GetWindowInstance(playerNum) ~= nil
end

--- Open the technique window
---@param player IsoPlayer
function TechniqueUI.OpenWindow(player)
    local playerNum = player:getPlayerNum()
    
    -- If already open, bring to front
    if TechniqueUI.IsWindowOpen(playerNum) then
        local existingWindow = TechniqueUI.GetWindowInstance(playerNum)
        existingWindow:setVisible(true)
        existingWindow:bringToTop()
        return
    end
    
    -- Play UI open sound
    player:playSound("UIActivateButton")
    
    -- Get saved position or default
    local x = getCore():getScreenWidth() / 2 - 190
    local y = getCore():getScreenHeight() / 2 - 225
    
    if TechniqueUI.players[playerNum] and TechniqueUI.players[playerNum].windows[WINDOW_KEY] then
        local windowData = TechniqueUI.players[playerNum].windows[WINDOW_KEY]
        if windowData.x and windowData.y then
            x = windowData.x
            y = windowData.y
        end
    else
        TechniqueUI.players[playerNum] = TechniqueUI.players[playerNum] or {}
        TechniqueUI.players[playerNum].windows = TechniqueUI.players[playerNum].windows or {}
        TechniqueUI.players[playerNum].windows[WINDOW_KEY] = {}
    end
    
    -- Create window
    local window = TechniqueWindow:new(x, y, player)
    window:initialise()
    window:instantiate()
    window:setVisible(true)
    window:addToUIManager()
    window:bringToTop()
    
    -- Store reference
    TechniqueUI.players[playerNum].windows[WINDOW_KEY].instance = window
    TechniqueUI.players[playerNum].windows[WINDOW_KEY].playerObj = player
end

--- Close the technique window
---@param playerNum number
function TechniqueUI.CloseWindow(playerNum)
    local window = TechniqueUI.GetWindowInstance(playerNum)
    if window then
        -- Play UI close sound
        local player = window.player
        if player then
            player:playSound("UIActivateButton")
        end
        window:onClose()
    end
end

--- Toggle the technique window
---@param player IsoPlayer
function TechniqueUI.ToggleWindow(player)
    local playerNum = player:getPlayerNum()
    if TechniqueUI.IsWindowOpen(playerNum) then
        TechniqueUI.CloseWindow(playerNum)
    else
        TechniqueUI.OpenWindow(player)
    end
end

--- Called when window is closed (saves position)
---@param window TechniqueWindow
function TechniqueUI.OnCloseWindow(window)
    local playerNum = window.player:getPlayerNum()
    
    if TechniqueUI.players[playerNum] and TechniqueUI.players[playerNum].windows[WINDOW_KEY] then
        local windowData = TechniqueUI.players[playerNum].windows[WINDOW_KEY]
        if windowData.instance == window then
            windowData.x = window:getX()
            windowData.y = window:getY()
            windowData.instance = nil
            windowData.playerObj = nil
        end
    end
end

--==============================================================================
-- KEYBIND INTEGRATION
--==============================================================================

-- Cache keybind (refreshed when nil or when key setting might have changed)
local cachedToggleKey = nil

local function onKeyPressed(key)
    local player = getPlayer()
    if not player then return end
    
    -- Cache keybind lookup
    if cachedToggleKey == nil then
        cachedToggleKey = getCore():getKey("Toggle Technique Panel")
    end
    
    if key == cachedToggleKey then
        TechniqueUI.ToggleWindow(player)
    end
end

-- Refresh cached key when options change
local function onOptionsChanged()
    cachedToggleKey = nil  -- Will be re-cached on next keypress
end

--==============================================================================
-- SIDEBAR INTEGRATION
--==============================================================================
-- The sidebar button popup is handled by TechniqueSidebar.lua
-- It hooks into ISEquippedItem to show a technique button when hovering over the heart icon

--==============================================================================
-- PLAYER DEATH HANDLER
--==============================================================================

local function onPlayerDeath(player)
    local playerNum = player:getPlayerNum()
    if TechniqueUI.IsWindowOpen(playerNum) then
        -- Close silently on death (no sound)
        local window = TechniqueUI.GetWindowInstance(playerNum)
        if window then
            window:onClose()
        end
    end
end

--==============================================================================
-- INITIALIZATION
--==============================================================================

local function initializeTechniqueUI()
    -- Register events
    Events.OnKeyPressed.Add(onKeyPressed)
    Events.OnPlayerDeath.Add(onPlayerDeath)
    
    -- Listen for options changes to refresh cached keybind
    if Events.OnMainMenuEnter then
        Events.OnMainMenuEnter.Add(onOptionsChanged)
    end
    
    print("[TechniqueUI] UI system initialized")
end

Events.OnGameBoot.Add(initializeTechniqueUI)

return TechniqueUI

