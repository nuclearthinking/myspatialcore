-- TechniqueSidebar.lua
-- Adds a technique button popup to the sidebar when hovering over the heart icon
-- Similar to how Project_Cook adds cooking to the crafting button

require "ISUI/ISPanel"

local TechniqueUI = require "ui/TechniqueUI"

-- Store original functions
local original_ISEquippedItem_initialise = nil
local original_ISEquippedItem_prerender = nil
local original_ISEquippedItem_removeFromUIManager = nil
local original_ISEquippedItem_checkSidebarSizeOption = nil

-- Cache game mode (doesn't change during gameplay)
local cachedIsTutorial = nil

-- Get texture width based on sidebar size setting
local function getTextureWidth()
    local size = getCore():getOptionSidebarSize()
    if size == 6 then
        size = getCore():getOptionFontSizeReal() - 1
    end
    local TEXTURE_WIDTH = 48
    if size == 2 then
        TEXTURE_WIDTH = 64
    elseif size == 3 then
        TEXTURE_WIDTH = 80
    elseif size == 4 then
        TEXTURE_WIDTH = 96
    elseif size == 5 then
        TEXTURE_WIDTH = 128
    end
    return TEXTURE_WIDTH
end

--==============================================================================
-- TECHNIQUE POPUP BUTTON
--==============================================================================

TechniquePopup = ISPanel:derive("TechniquePopup")

-- Cache tooltip text (loaded once)
local cachedTooltipText = nil

function TechniquePopup:initialise()
    ISPanel.initialise(self)
end

function TechniquePopup:new(x, y, width, height, chr)
    local TEXTURE_WIDTH = getTextureWidth()
    local TEXTURE_HEIGHT = TEXTURE_WIDTH  -- Square icons
    
    local o = ISPanel:new(x, y, TEXTURE_WIDTH, TEXTURE_HEIGHT)
    setmetatable(o, self)
    self.__index = self
    
    o.chr = chr
    o.playerNum = chr:getPlayerNum()
    o.TEXTURE_WIDTH = TEXTURE_WIDTH
    o.TEXTURE_HEIGHT = TEXTURE_HEIGHT
    o.backgroundColor = {r=0, g=0, b=0, a=0}
    o.borderColor = {r=0, g=0, b=0, a=0}
    
    -- Load technique icons based on sidebar size
    o.techniqueIcon = getTexture("media/ui/Sidebar/Techniques_off_" .. TEXTURE_WIDTH .. ".png")
    o.techniqueIconOn = getTexture("media/ui/Sidebar/Techniques_on_" .. TEXTURE_WIDTH .. ".png")
    
    -- Fallback to 48px if size not found
    if not o.techniqueIcon then
        o.techniqueIcon = getTexture("media/ui/Sidebar/Techniques_off_48.png")
    end
    if not o.techniqueIconOn then
        o.techniqueIconOn = getTexture("media/ui/Sidebar/Techniques_on_48.png")
    end
    
    return o
end

function TechniquePopup:onMouseMove(dx, dy)
    -- Use cached tooltip text to avoid getText() every mouse move
    if not cachedTooltipText then
        cachedTooltipText = getText("IGUI_TechniqueWindow_Title") or "Cultivation Techniques"
    end
    self:showTooltip(cachedTooltipText)
    return true
end

function TechniquePopup:onMouseDown(x, y)
    self:hideTooltip()
    
    -- Toggle technique window
    if TechniqueUI.IsWindowOpen(self.playerNum) then
        TechniqueUI.CloseWindow(self.playerNum)
    else
        TechniqueUI.OpenWindow(self.chr)
    end
    
    return true
end

function TechniquePopup:onMouseMoveOutside(dx, dy)
    self:hideTooltip()
    return true
end

function TechniquePopup:showTooltip(text)
    if not text then return end
    
    if not self.tooltip then
        self.tooltip = ISToolTip:new()
        self.tooltip:initialise()
        self.tooltip:instantiate()
        self.tooltip:setOwner(self)
        self.tooltip:setName(text)
    end
    
    -- Only update UI manager if not already visible
    if not self.tooltip:isVisible() then
        self.tooltip:setVisible(true)
        self.tooltip:addToUIManager()
        self.tooltip:bringToTop()
    end
end

function TechniquePopup:hideTooltip()
    if self.tooltip and self.tooltip:isVisible() then
        self.tooltip:removeFromUIManager()
        self.tooltip:setVisible(false)
    end
end

function TechniquePopup:prerender()
    ISPanel.prerender(self)
    -- Cache window open state for render() - avoids double IsWindowOpen call
    self._cachedIsOpen = TechniqueUI.IsWindowOpen(self.playerNum)
end

function TechniquePopup:render()
    -- Use cached state from prerender
    local icon = self._cachedIsOpen and self.techniqueIconOn or self.techniqueIcon
    
    if icon then
        -- Draw icon at full size (icons are already correctly sized)
        self:drawTexture(icon, 0, 0, 1, 1, 1, 1)
    else
        -- Fallback: draw a simple rectangle with text
        self:drawRect(4, 4, self.width - 8, self.height - 8, 0.8, 0.3, 0.2, 0.5)
        self:drawText("T", self.width/2 - 4, self.height/2 - 8, 1, 1, 1, 1, UIFont.Medium)
    end
end

--==============================================================================
-- SIDEBAR HOOKS
--==============================================================================

-- Helper to find the heart/health button in the sidebar
local function findHeartButton(sidebarPanel)
    -- Try different possible button names
    local possibleNames = {"heartBtn", "healthBtn", "heartButton", "healthButton"}
    
    for _, name in ipairs(possibleNames) do
        if sidebarPanel[name] then
            return sidebarPanel[name], name
        end
    end
    
    -- Try to find by iterating children
    if sidebarPanel.getChildren then
        local children = sidebarPanel:getChildren()
        if children then
            for i = 0, children:size() - 1 do
                local child = children:get(i)
                -- Look for heart-related naming or texture
                if child and child.internal and string.find(child.internal:lower(), "heart") then
                    return child, "child_" .. i
                end
            end
        end
    end
    
    return nil, nil
end

local function hookISEquippedItem()
    if not ISEquippedItem then
        print("[TechniqueSidebar] WARNING: ISEquippedItem not found, sidebar integration disabled")
        return
    end
    
    -- Store originals
    original_ISEquippedItem_initialise = ISEquippedItem.initialise
    original_ISEquippedItem_prerender = ISEquippedItem.prerender
    original_ISEquippedItem_removeFromUIManager = ISEquippedItem.removeFromUIManager
    original_ISEquippedItem_checkSidebarSizeOption = ISEquippedItem.checkSidebarSizeOption
    
    -- Override initialise
    function ISEquippedItem:initialise()
        original_ISEquippedItem_initialise(self)
        
        -- Only for player 0
        if self.chr:getPlayerNum() == 0 then
            -- Find the heart button
            local heartBtn, btnName = findHeartButton(self)
            self._techniqueHeartBtn = heartBtn
            
            if heartBtn then
                print("[TechniqueSidebar] Found heart button: " .. tostring(btnName))
                
                local TEXTURE_WIDTH = getTextureWidth()
                local TEXTURE_HEIGHT = TEXTURE_WIDTH  -- Square icons
                
                -- Position popup to the right of the heart button (center-aligned)
                local absX = self:getAbsoluteX() + heartBtn:getX() + heartBtn:getWidth()
                local btnCenterY = self:getAbsoluteY() + heartBtn:getY() + (heartBtn:getHeight() / 2)
                local absY = btnCenterY - (TEXTURE_HEIGHT / 2)
                
                self.techniquePopup = TechniquePopup:new(absX, absY, TEXTURE_WIDTH, TEXTURE_HEIGHT, self.chr)
                self.techniquePopup.owner = self
                self.techniquePopup:addToUIManager()
                self.techniquePopup:setVisible(false)
            else
                -- Fallback: use crafting button if available, position below it
                if self.craftingBtn then
                    print("[TechniqueSidebar] Heart button not found, using crafting button as anchor")
                    
                    local TEXTURE_WIDTH = getTextureWidth()
                    local TEXTURE_HEIGHT = TEXTURE_WIDTH  -- Square icons
                    
                    -- Position popup to the right of the crafting button (center-aligned)
                    local absX = self:getAbsoluteX() + self.craftingBtn:getX() + self.craftingBtn:getWidth()
                    local btnCenterY = self:getAbsoluteY() + self.craftingBtn:getY() + (self.craftingBtn:getHeight() / 2)
                    local absY = btnCenterY - (TEXTURE_HEIGHT / 2)
                    
                    self.techniquePopup = TechniquePopup:new(absX, absY, TEXTURE_WIDTH, TEXTURE_HEIGHT, self.chr)
                    self.techniquePopup.owner = self
                    self._techniqueHeartBtn = self.craftingBtn  -- Use crafting as trigger
                    self.techniquePopup:addToUIManager()
                    self.techniquePopup:setVisible(false)
                else
                    print("[TechniqueSidebar] WARNING: No suitable button found for technique popup")
                end
            end
        end
    end
    
    -- Override prerender
    function ISEquippedItem:prerender()
        original_ISEquippedItem_prerender(self)
        
        local triggerBtn = self._techniqueHeartBtn
        
        if triggerBtn and self.techniquePopup then
            local isTechniquePanelOpen = TechniqueUI.IsWindowOpen(self.chr:getPlayerNum())
            
            -- Update popup position (center-aligned with trigger button)
            local absX = self:getAbsoluteX() + triggerBtn:getX() + triggerBtn:getWidth()
            -- Center vertically: align popup center with button center
            local btnCenterY = self:getAbsoluteY() + triggerBtn:getY() + (triggerBtn:getHeight() / 2)
            local absY = btnCenterY - (self.techniquePopup:getHeight() / 2)
            self.techniquePopup:setX(absX)
            self.techniquePopup:setY(absY)
            
            -- Show/hide logic
            if triggerBtn:isMouseOver() then
                self.techniquePopup:setVisible(true)
                self.techniquePopup:bringToTop()
            elseif self.techniquePopup:isMouseOver() then
                -- Keep visible when mouse is over the popup
            elseif isTechniquePanelOpen then
                self.techniquePopup:setVisible(true)
            else
                self.techniquePopup:setVisible(false)
                if self.techniquePopup.tooltip then
                    self.techniquePopup.tooltip:setVisible(false)
                    self.techniquePopup.tooltip:removeFromUIManager()
                end
            end
            
            -- Hide in tutorial mode (cached - doesn't change during session)
            if cachedIsTutorial == nil then
                cachedIsTutorial = ("Tutorial" == getCore():getGameMode())
            end
            if cachedIsTutorial then
                self.techniquePopup:setVisible(false)
            end
        end
    end
    
    -- Override removeFromUIManager
    function ISEquippedItem:removeFromUIManager()
        if self.techniquePopup then
            self.techniquePopup:removeFromUIManager()
        end
        original_ISEquippedItem_removeFromUIManager(self)
    end
    
    -- Override checkSidebarSizeOption
    function ISEquippedItem:checkSidebarSizeOption()
        original_ISEquippedItem_checkSidebarSizeOption(self)
        
        if self.techniquePopup then
            local TEXTURE_WIDTH = getTextureWidth()
            local TEXTURE_HEIGHT = TEXTURE_WIDTH  -- Square icons
            
            self.techniquePopup.TEXTURE_WIDTH = TEXTURE_WIDTH
            self.techniquePopup.TEXTURE_HEIGHT = TEXTURE_HEIGHT
            self.techniquePopup:setWidth(TEXTURE_WIDTH)
            self.techniquePopup:setHeight(TEXTURE_HEIGHT)
            
            -- Reload icons for new size
            self.techniquePopup.techniqueIcon = getTexture("media/ui/Sidebar/Techniques_off_" .. TEXTURE_WIDTH .. ".png")
            self.techniquePopup.techniqueIconOn = getTexture("media/ui/Sidebar/Techniques_on_" .. TEXTURE_WIDTH .. ".png")
            
            -- Fallback to 48px if size not found
            if not self.techniquePopup.techniqueIcon then
                self.techniquePopup.techniqueIcon = getTexture("media/ui/Sidebar/Techniques_off_48.png")
            end
            if not self.techniquePopup.techniqueIconOn then
                self.techniquePopup.techniqueIconOn = getTexture("media/ui/Sidebar/Techniques_on_48.png")
            end
        end
    end
    
    print("[TechniqueSidebar] Sidebar hooks installed")
end

-- Initialize after game boot
Events.OnGameBoot.Add(hookISEquippedItem)

return {}

