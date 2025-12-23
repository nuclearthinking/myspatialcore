-- EffectDebugWindow.lua
-- Debug UI for viewing active effects and their sources
-- Shows real-time effect breakdown for troubleshooting

local EffectSystem = require "effects/EffectSystem"
local EffectRegistry = require "effects/EffectRegistry"
local LuaCompat = require "utils/LuaCompat"

local EffectDebugWindow = ISPanel:derive("EffectDebugWindow")

-- Window dimensions
local WINDOW_WIDTH = 600
local WINDOW_HEIGHT = 500

-- Refresh rate (seconds)
local REFRESH_RATE = 1.0

function EffectDebugWindow:initialise()
    ISPanel.initialise(self)
end

function EffectDebugWindow:createChildren()
    ISPanel.createChildren(self)
    
    -- Title label
    self.titleLabel = ISLabel:new(10, 10, 20, "Effect System Debug", 1, 1, 1, 1, UIFont.Medium, true)
    self.titleLabel:initialise()
    self:addChild(self.titleLabel)
    
    -- Close button
    self.closeButton = ISButton:new(self.width - 80, 10, 70, 20, "Close", self, EffectDebugWindow.onClose)
    self.closeButton:initialise()
    self.closeButton.borderColor = {r=1, g=1, b=1, a=0.4}
    self:addChild(self.closeButton)
    
    -- Refresh button
    self.refreshButton = ISButton:new(self.width - 160, 10, 70, 20, "Refresh", self, EffectDebugWindow.onRefresh)
    self.refreshButton:initialise()
    self.refreshButton.borderColor = {r=1, g=1, b=1, a=0.4}
    self:addChild(self.refreshButton)
    
    -- Scrollable text area for effects
    self.effectsText = ISRichTextPanel:new(10, 40, self.width - 20, self.height - 50)
    self.effectsText:initialise()
    self.effectsText:setMargins(5, 5, 5, 5)
    self.effectsText.backgroundColor = {r=0, g=0, b=0, a=0.8}
    self.effectsText.borderColor = {r=0.4, g=0.4, b=0.4, a=1}
    self:addChild(self.effectsText)
    
    -- Initial update
    self:updateEffectDisplay()
    
    -- Auto-refresh timer
    self.lastRefresh = 0
end

function EffectDebugWindow:onRefresh()
    self:updateEffectDisplay()
end

function EffectDebugWindow:onClose()
    self:setVisible(false)
    self:removeFromUIManager()
end

function EffectDebugWindow:update()
    ISPanel.update(self)
    
    if not self.lastRefresh then
        self.lastRefresh = 0
    end
    
    -- Auto-refresh every REFRESH_RATE seconds (convert to milliseconds)
    local currentTime = getTimestampMs()
    if currentTime - self.lastRefresh >= (REFRESH_RATE * 1000) then
        local success = pcall(function()
            self:updateEffectDisplay()
        end)
        if not success then
            -- Silently skip update on error
        end
        self.lastRefresh = currentTime
    end
end

function EffectDebugWindow:updateEffectDisplay()
    local player = getPlayer()
    if not player then
        if self.effectsText and self.effectsText.setText then
            self.effectsText:setText("<RGB:1,0.5,0.5> No player found")
        end
        return
    end
    
    if not self.effectsText then
        return
    end
    
    local text = ""
    
    -- Header (with safety checks)
    local username = "Unknown"
    local bodyLevel = 0
    local fitnessLevel = 0
    local strengthLevel = 0
    
    local success, result = pcall(function() return player:getUsername() end)
    if success and result then username = result end
    
    success, result = pcall(function() return player:getPerkLevel(Perks.Body) end)
    if success and result then bodyLevel = result end
    
    success, result = pcall(function() return player:getPerkLevel(Perks.Fitness) end)
    if success and result then fitnessLevel = result end
    
    success, result = pcall(function() return player:getPerkLevel(Perks.Strength) end)
    if success and result then strengthLevel = result end
    
    text = text .. "<SIZE:large> <RGB:0.5,1,0.5> ★ Effect System Debug ★ </SIZE> <LINE> <LINE>"
    text = text .. "<RGB:1,1,1> Player: " .. username .. " <LINE>"
    text = text .. "<RGB:0.8,0.8,0.8> Body Level: " .. bodyLevel .. " <LINE>"
    text = text .. "<RGB:0.8,0.8,0.8> Fitness: " .. fitnessLevel .. " | Strength: " .. strengthLevel .. " <LINE>"
    text = text .. "<LINE>"
    
    -- Get all active effects (with safety check)
    local allEffects = {}
    success, result = pcall(function() return EffectRegistry.getAll(player) end)
    if success and result then
        allEffects = result
    else
        text = text .. "<RGB:1,0.5,0.5> Error getting effects: " .. tostring(result) .. " <LINE>"
    end
    
    if not LuaCompat.hasKeys(allEffects) then
        text = text .. "<RGB:1,0.5,0.5> No active effects <LINE>"
    else
        -- Count effects
        local count = LuaCompat.countKeys(allEffects)
        text = text .. "<RGB:1,1,0> Active Effects: " .. count .. " <LINE> <LINE>"
        
        -- List each effect with details
        for effectName, totalValue in pairs(allEffects) do
            local details = EffectRegistry.getDetails(player, effectName)
            
            if details then
                -- Effect header with total value
                local valueStr = ""
                if totalValue >= 0 and totalValue <= 1 then
                    valueStr = string.format("%.1f%%", totalValue * 100)
                else
                    valueStr = string.format("%.4f", totalValue)
                end
                
                text = text .. "<RGB:0.5,1,1> > " .. effectName .. ": <RGB:1,1,0.5>" .. valueStr .. " <RGB:0.7,0.7,0.7>(" .. details.stackingRule .. ") <LINE>"
                
                -- List sources
                if #details.sources > 0 then
                    for _, src in ipairs(details.sources) do
                        local srcValueStr = ""
                        if src.value >= 0 and src.value <= 1 then
                            srcValueStr = string.format("%.1f%%", src.value * 100)
                        else
                            srcValueStr = string.format("%.4f", src.value)
                        end
                        
                        -- Metadata
                        local metaStr = ""
                        if LuaCompat.hasKeys(src.metadata) then
                            local parts = {}
                            for k, v in pairs(src.metadata) do
                                table.insert(parts, string.format("%s=%s", k, tostring(v)))
                            end
                            metaStr = " [" .. table.concat(parts, ", ") .. "]"
                        end
                        
                        text = text .. "    <RGB:0.8,0.8,0.8> - " .. src.source .. ": <RGB:1,1,1>" .. srcValueStr .. " <RGB:0.6,0.6,0.6>(priority: " .. src.priority .. ")" .. metaStr .. " <LINE>"
                    end
                end
                text = text .. "<LINE>"
            end
        end
    end
    
    -- Providers info
    text = text .. "<RGB:1,1,0> ========================= <LINE>"
    text = text .. "<RGB:0.5,1,0.5> Registered Providers: <LINE>"
    
    local providers = {}
    success, result = pcall(function() return EffectSystem.getProviders() end)
    if success and result then
        providers = result
    end
    
    if #providers == 0 then
        text = text .. "  <RGB:1,0.5,0.5> No providers registered <LINE>"
    else
        for i, prov in ipairs(providers) do
            if prov and prov.sourceName then
                local active = false
                success, result = pcall(function() return prov.shouldApply(player) end)
                if success then active = result end
                
                local statusColor = active and "0.5,1,0.5" or "1,0.5,0.5"
                local statusText = active and "ACTIVE" or "INACTIVE"
                text = text .. string.format("  <RGB:%s> %d. %s (priority: %d) - %s <LINE>", 
                    statusColor, i, prov.sourceName, prov.priority or 0, statusText)
            end
        end
    end
    
    if self.effectsText and self.effectsText.setText then
        self.effectsText:setText(text)
        if self.effectsText.paginate then
            self.effectsText:paginate()
        end
    end
end

function EffectDebugWindow:new(x, y, width, height)
    local o = ISPanel:new(x, y, width or WINDOW_WIDTH, height or WINDOW_HEIGHT)
    setmetatable(o, self)
    self.__index = self
    o.borderColor = {r=0.4, g=0.4, b=0.4, a=1}
    o.backgroundColor = {r=0, g=0, b=0, a=0.9}
    o.moveWithMouse = true
    return o
end

--==============================================================================
-- GLOBAL FUNCTIONS
--==============================================================================

local windowInstance = nil

--- Show the effect debug window
function EffectDebugWindow.show()
    if windowInstance and windowInstance:isVisible() then
        -- Already visible, just bring to front
        windowInstance:bringToTop()
        return
    end
    
    -- Create new window
    local x = (getCore():getScreenWidth() - WINDOW_WIDTH) / 2
    local y = (getCore():getScreenHeight() - WINDOW_HEIGHT) / 2
    
    windowInstance = EffectDebugWindow:new(x, y, WINDOW_WIDTH, WINDOW_HEIGHT)
    windowInstance:initialise()
    windowInstance:addToUIManager()
    windowInstance:setVisible(true)
end

--- Hide the effect debug window
function EffectDebugWindow.hide()
    if windowInstance then
        windowInstance:setVisible(false)
        windowInstance:removeFromUIManager()
        windowInstance = nil
    end
end

--- Toggle the effect debug window
function EffectDebugWindow.toggle()
    if windowInstance and windowInstance:isVisible() then
        EffectDebugWindow.hide()
    else
        EffectDebugWindow.show()
    end
end

-- Add global debug command
_G.ShowEffectDebug = EffectDebugWindow.show
_G.HideEffectDebug = EffectDebugWindow.hide
_G.ToggleEffectDebug = EffectDebugWindow.toggle

print("[EffectDebugWindow] Debug UI initialized. Use ShowEffectDebug() to open.")

return EffectDebugWindow

