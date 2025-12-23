--[[
    TechniqueWindow.lua - Cultivation Techniques Display
    
    Main UI panel showing player cultivation progress:
    - Body and Spirit cultivation levels with benefits
    - Learned techniques with stage progression
    
    Stage display:
    - Normal mode: Shows stage name and description only
    - Debug mode: Also shows XP progress bar
    
    Uses CUI_Framework for scaled layout, theming, and 9-patch backgrounds.
]]

require "ISUI/ISPanel"
require "ui/framework/CUI_Framework"

local TechniqueSystem = require "techniques/TechniqueSystem"
local TechniqueRegistry = require "techniques/TechniqueRegistry"
local Config = require "ui/framework/CUI_Config"

---@class TechniqueWindow : ISPanel
TechniqueWindow = ISPanel:derive("TechniqueWindow")

-- Use Config for font heights
local FONT_HGT_SMALL = Config.fontSmall
local FONT_HGT_MEDIUM = Config.fontMedium
local FONT_HGT_LARGE = Config.fontLarge

-- Cache debug mode (checked once per session)
local isDebugMode = getDebug()

--==============================================================================
-- THEME (Using CUI_Config colors with some customizations)
--==============================================================================
local THEME = Config.colors

-- Add/override some specific colors for this window
local COLORS = {
    accentBody = {r=0.85, g=0.55, b=0.25, a=1},
    accentSpirit = {r=0.45, g=0.65, b=0.95, a=1},
    stageGold = {r=1.0, g=0.84, b=0.0, a=1},  -- For Transcendent
    stagePurple = {r=0.75, g=0.55, b=0.95, a=1},  -- For Perfected
}

--==============================================================================
-- STAGE DESCRIPTIONS (vague, atmospheric)
--==============================================================================
local STAGE_DESCRIPTIONS = {
    [1] = "Your understanding barely scratches the surface...",
    [2] = "The technique begins to respond to your will.",
    [3] = "A reliable companion in times of need.",
    [4] = "The boundary between you and the technique blurs.",
    [5] = "The technique has become part of your being.",
}

--==============================================================================
-- LAYOUT (Using CUI_Config with technique-specific overrides)
--==============================================================================
local LAYOUT = {
    windowWidth = Config.techniqueWindow.width,
    windowHeight = Config.techniqueWindow.minHeight,
    headerHeight = Config.headerHeight,
    padding = Config.padding,
    paddingSmall = Config.paddingSmall,
    
    cultivationIconSize = Config.techniqueWindow.cultivationIconSize,
    cultivationRowHeight = Config.techniqueWindow.cultivationRowHeight,
    
    techniqueSlotHeight = Config.techniqueWindow.techniqueSlotHeight,
    techniqueSlotSpacing = Config.techniqueWindow.techniqueSlotSpacing,
    techniqueSlotPadding = Config.techniqueWindow.techniqueSlotPadding or math.floor(FONT_HGT_SMALL * 0.6),
    
    sectionSpacing = Config.paddingLarge,
    dividerHeight = Config.dividerHeight,
    accentBarHeight = Config.accentBarHeight,
    closeButtonSize = Config.techniqueWindow.closeButtonSize,
    
    xpBarHeight = math.floor(FONT_HGT_SMALL * 0.7),
    lineSpacing = math.floor(FONT_HGT_SMALL * 0.25),
}

-- Data refresh interval (ticks)
local DATA_REFRESH_INTERVAL = 30

-- Cached text
local cachedWindowTitle = nil

--==============================================================================
-- CULTIVATION BENEFITS
--==============================================================================
local BODY_BENEFITS = {
    [0] = { "No cultivation yet", "Kill zombies in melee" },
    [1] = { "Minor hunger reduction", "Slight endurance boost" },
    [2] = { "Small hunger reduction", "Reduced thirst drain" },
    [3] = { "Moderate hunger reduction", "Less fatigue", "Metabolism healing" },
    [4] = { "Good hunger reduction", "Thirst reduction", "Enhanced metabolism" },
    [5] = { "Strong hunger reduction", "Muscle recovery boost" },
    [6] = { "Major hunger reduction", "Powerful metabolism" },
    [7] = { "Excellent sustenance", "Passive HP regen", "Fitness protection" },
    [8] = { "Superior sustenance", "Rapid recovery" },
    [9] = { "Near-perfect body", "Minimal needs" },
    [10] = { "Transcendent body", "No physical needs" },
}

local SPIRIT_BENEFITS = {
    [0] = { "No cultivation yet", "Endure mental hardships" },
    [1] = { "Slight panic resistance", "Minor stress relief" },
    [2] = { "Small panic reduction", "Less unhappiness" },
    [3] = { "Moderate panic control", "Better sleep quality" },
    [4] = { "Good mental fortitude", "Faster stress recovery" },
    [5] = { "Strong panic resistance", "Stress immunity grows" },
    [6] = { "Major mental stability", "Nightmare resistance" },
    [7] = { "Excellent composure", "Emotional balance" },
    [8] = { "Near panic immunity", "Deep inner peace" },
    [9] = { "Unshakeable mind", "Serene presence" },
    [10] = { "Transcendent spirit", "Mental clarity" },
}

--==============================================================================
-- CONSTRUCTOR
--==============================================================================

function TechniqueWindow:new(x, y, player)
    local o = ISPanel:new(x, y, LAYOUT.windowWidth, LAYOUT.windowHeight)
    setmetatable(o, self)
    self.__index = self
    
    o.player = player
    o.playerNum = player:getPlayerNum()
    o.moveWithMouse = true
    o.moving = false
    o.backgroundColor = THEME.bgMain
    o.borderColor = THEME.borderMain
    
    -- Data caching
    o._cachedLearnedOnly = nil
    o._lastDataRefresh = 0
    o._tickCounter = 0
    
    -- Load cultivation icons
    o.bodyIcon = getTexture("media/ui/BodyCultivation.png")
    o.spiritIcon = getTexture("media/ui/SpiritCultivation_64.png")
    
    -- Panel background texture path (for native 9-patch)
    o.panelBgPath = "media/ui/NeatUI/DefaultPanel/InnerPanel_BG.png"
    o.headerBgPath = "media/ui/NeatUI/DefaultPanel/MainTitle_BG.png"
    
    return o
end

function TechniqueWindow:initialise()
    ISPanel.initialise(self)
end

function TechniqueWindow:createChildren()
    ISPanel.createChildren(self)
    
    -- Close button using CUI_Button
    local btnSize = LAYOUT.closeButtonSize
    self.closeButton = CUI_Button:new(
        self.width - btnSize - 6, 
        (LAYOUT.headerHeight - btnSize) / 2, 
        btnSize, 
        btnSize, 
        "X", 
        self, 
        self.onClose
    )
    self.closeButton:initialise()
    self.closeButton:instantiate()
    self.closeButton.font = UIFont.Medium
    self.closeButton:setBgNormal(0.45, 0.18, 0.22, 0.85)
    self.closeButton:setBgHover(0.60, 0.22, 0.28, 0.95)
    self.closeButton:setBgPressed(0.35, 0.12, 0.15, 0.95)
    self.closeButton:setBorderColor(0.55, 0.25, 0.30, 0.6)
    self.closeButton:setTextColor(1, 1, 1, 0.9)
    self.closeButton:setCornerRadius(6)
    self:addChild(self.closeButton)
    
    -- Create scroll view for techniques section
    local scrollY = LAYOUT.headerHeight + LAYOUT.padding 
        + LAYOUT.cultivationRowHeight + LAYOUT.sectionSpacing 
        + LAYOUT.dividerHeight + LAYOUT.sectionSpacing
        + FONT_HGT_MEDIUM + 8
    local scrollHeight = LAYOUT.windowHeight - scrollY - LAYOUT.padding
    
    self.techniqueScrollView = CUI_ScrollView:new(
        LAYOUT.padding,
        scrollY,
        self.width - LAYOUT.padding * 2,
        scrollHeight
    )
    self.techniqueScrollView:initialise()
    self.techniqueScrollView:instantiate()
    self.techniqueScrollView:setAutoHideScrollbar(true)
    self:addChild(self.techniqueScrollView)
end

function TechniqueWindow:onClose()
    self:setVisible(false)
    self:removeFromUIManager()
    TechniqueUI.OnCloseWindow(self)
end

--==============================================================================
-- DATA FETCHING
--==============================================================================

function TechniqueWindow:getLearnedTechniques(forceRefresh)
    if not forceRefresh and self._cachedLearnedOnly and 
       (self._tickCounter - self._lastDataRefresh) < DATA_REFRESH_INTERVAL then
        return self._cachedLearnedOnly
    end
    
    local learnedData = {}
    local allIds = TechniqueSystem.Registry.getAllIds()
    
    for _, id in ipairs(allIds) do
        local isLearned = TechniqueSystem.hasTechnique(self.player, id)
        
        if isLearned then
            local technique = TechniqueSystem.Registry.get(id)
            local stage = TechniqueSystem.getLevel(self.player, id)
            local techData = TechniqueSystem.Manager.getTechniqueData(self.player, id)
            
            local xp = techData and techData.xp or 0
            local xpRequired = TechniqueRegistry.getXPForStage(technique, stage)
            
            table.insert(learnedData, {
                id = id,
                technique = technique,
                stage = stage,
                xp = xp,
                xpRequired = xpRequired,
                effects = TechniqueSystem.getEffects(self.player, id),
            })
        end
    end
    
    -- Sort by name
    table.sort(learnedData, function(a, b)
        return (a.technique.name or a.id) < (b.technique.name or b.id)
    end)
    
    self._cachedLearnedOnly = learnedData
    self._lastDataRefresh = self._tickCounter
    
    return learnedData
end

--==============================================================================
-- RENDERING
--==============================================================================

function TechniqueWindow:prerender()
    local bg = self.backgroundColor
    local accent = THEME.accentPrimary
    local border = self.borderColor
    local text = THEME.textPrimary
    
    -- Main background - try native 9-patch first
    if not CUI_Tools.drawPanelBackground(self, self.panelBgPath, 0, 0, self.width, self.height, bg) then
        self:drawRect(0, 0, self.width, self.height, bg.a, bg.r, bg.g, bg.b)
    end
    
    -- Header background - try native 9-patch
    local header = THEME.bgHeader
    if not CUI_Tools.drawPanelBackground(self, self.headerBgPath, 0, 0, self.width, LAYOUT.headerHeight, header) then
        self:drawRect(0, 0, self.width, LAYOUT.headerHeight, header.a, header.r, header.g, header.b)
    end
    
    -- Header accent line
    self:drawRect(0, LAYOUT.headerHeight - LAYOUT.accentBarHeight, self.width, LAYOUT.accentBarHeight, 
        accent.a, accent.r, accent.g, accent.b)
    
    -- Title
    if not cachedWindowTitle then
        cachedWindowTitle = getText("IGUI_TechniqueWindow_Title") or "Cultivation Path"
    end
    local titleX = LAYOUT.padding
    local titleY = (LAYOUT.headerHeight - FONT_HGT_MEDIUM) / 2
    self:drawText(cachedWindowTitle, titleX, titleY, text.r, text.g, text.b, text.a, UIFont.Medium)
    
    -- DEBUG: Show current calories, weight, and metabolism status
    if isDebugMode and self.player then
        local nutrition = self.player:getNutrition()
        if nutrition then
            local calories = nutrition:getCalories()
            local weight = nutrition:getWeight()
            
            -- Show calories and weight
            local debugText = string.format("Cal: %.0f | Wt: %.1fkg", calories, weight)
            local debugWidth = CUI_Tools.measureText(debugText, UIFont.Small)
            local debugX = self.width - debugWidth - LAYOUT.closeButtonSize - 16
            local debugY = (LAYOUT.headerHeight - FONT_HGT_SMALL) / 2
            
            -- Color based on status
            local debugColor
            if calories < 0 then
                debugColor = {r=1, g=0.3, b=0.3, a=0.9}  -- Red (negative calories)
            elseif weight <= 75 then
                debugColor = {r=1, g=0.5, b=0.2, a=0.9}  -- Orange (at min weight)
            elseif calories > 1500 then
                debugColor = {r=0.5, g=1, b=0.5, a=0.9}  -- Green (plenty for healing)
            else
                debugColor = {r=1, g=1, b=0.5, a=0.9}  -- Yellow (active)
            end
            
            self:drawText(debugText, debugX, debugY, 
                debugColor.r, debugColor.g, debugColor.b, debugColor.a, UIFont.Small)
        end
    end
end

function TechniqueWindow:render()
    ISPanel.render(self)
    
    local y = LAYOUT.headerHeight + LAYOUT.padding
    
    -- =========================================================================
    -- TWO-COLUMN CULTIVATION ROW (Body | Spirit)
    -- =========================================================================
    local columnWidth = (self.width - LAYOUT.padding * 3) / 2
    
    -- Body Cultivation (left column)
    self:renderCultivationColumn(LAYOUT.padding, y, columnWidth, LAYOUT.cultivationRowHeight, "body")
    
    -- Spirit Cultivation (right column)
    self:renderCultivationColumn(LAYOUT.padding * 2 + columnWidth, y, columnWidth, LAYOUT.cultivationRowHeight, "spirit")
    
    y = y + LAYOUT.cultivationRowHeight + LAYOUT.sectionSpacing
    
    -- Divider
    local divider = THEME.borderDivider
    self:drawRect(LAYOUT.padding, y, self.width - LAYOUT.padding * 2, LAYOUT.dividerHeight, 
        divider.a, divider.r, divider.g, divider.b)
    y = y + LAYOUT.dividerHeight + LAYOUT.sectionSpacing
    
    -- "Learned Techniques" header
    local text = THEME.textPrimary
    self:drawText("Learned Techniques", LAYOUT.padding, y, text.r, text.g, text.b, 0.9, UIFont.Medium)
    
    -- Techniques are rendered in the scroll view
    self:updateTechniqueScrollContent()
end

function TechniqueWindow:renderCultivationColumn(x, y, width, height, cultivationType)
    local isBody = cultivationType == "body"
    local perk = isBody and Perks.Body or Perks.Spirit
    local icon = isBody and self.bodyIcon or self.spiritIcon
    local accentColor = isBody and COLORS.accentBody or COLORS.accentSpirit
    local benefits = isBody and BODY_BENEFITS or SPIRIT_BENEFITS
    local titleKey = isBody and "IGUI_perks_Body" or "IGUI_perks_Spirit"
    
    local level = self.player:getPerkLevel(perk)
    local levelBenefits = benefits[math.min(level, 10)] or benefits[0]
    
    local bgSection = THEME.bgSection
    
    -- Section background - try native 9-patch
    if not CUI_Tools.drawPanelBackground(self, self.panelBgPath, x, y, width, height, bgSection) then
        self:drawRect(x, y, width, height, bgSection.a, bgSection.r, bgSection.g, bgSection.b)
    end
    
    -- Top accent bar
    self:drawRect(x, y, width, LAYOUT.accentBarHeight, accentColor.a, accentColor.r, accentColor.g, accentColor.b)
    
    -- Icon centered at top
    local iconSize = LAYOUT.cultivationIconSize
    local iconX = x + (width - iconSize) / 2
    local iconY = y + 8
    
    if icon then
        self:drawTextureScaled(icon, iconX, iconY, iconSize, iconSize, 1, 1, 1, 1)
    else
        self:drawRect(iconX, iconY, iconSize, iconSize, 0.3, accentColor.r, accentColor.g, accentColor.b)
    end
    
    -- Title and Level below icon
    local textY = iconY + iconSize + 6
    local title = getText(titleKey) or (isBody and "Body" or "Spirit")
    local levelText = string.format("Level %d", level)
    local titleWidth = CUI_Tools.measureText(title, UIFont.Medium)
    local levelWidth = CUI_Tools.measureText(levelText, UIFont.Small)
    
    -- Center title
    local titleX = x + (width - titleWidth - levelWidth - 8) / 2
    self:drawText(title, titleX, textY, accentColor.r, accentColor.g, accentColor.b, 1, UIFont.Medium)
    
    -- Align level text baseline with title
    local levelYOffset = FONT_HGT_MEDIUM - FONT_HGT_SMALL
    local textDim = THEME.textDim
    self:drawText(levelText, titleX + titleWidth + 8, textY + levelYOffset, textDim.r, textDim.g, textDim.b, 0.9, UIFont.Small)
    
    textY = textY + FONT_HGT_MEDIUM + 6
    
    -- Benefits list (left-aligned with padding)
    local benefitX = x + 8
    local maxBenefitWidth = width - 16
    for i, benefit in ipairs(levelBenefits) do
        if i <= 3 then
            local bulletColor = (level > 0) and THEME.textSuccess or THEME.textMuted
            local displayText = CUI_Tools.truncateText("- " .. benefit, maxBenefitWidth, UIFont.Small)
            self:drawText(displayText, benefitX, textY, bulletColor.r, bulletColor.g, bulletColor.b, 0.85, UIFont.Small)
            textY = textY + FONT_HGT_SMALL + 2
        end
    end
end

--==============================================================================
-- TECHNIQUE SCROLL CONTENT
--==============================================================================

function TechniqueWindow:updateTechniqueScrollContent()
    local techniques = self:getLearnedTechniques()
    local scrollView = self.techniqueScrollView
    
    if not scrollView then return end
    
    -- Calculate required content height
    local contentHeight
    if #techniques == 0 then
        contentHeight = 100
    else
        contentHeight = #techniques * (LAYOUT.techniqueSlotHeight + LAYOUT.techniqueSlotSpacing)
    end
    
    scrollView:setScrollHeight(contentHeight)
    
    -- Render techniques within the scroll view's coordinate space
    local yOffset = scrollView:getYScroll()
    
    if #techniques == 0 then
        self:renderNoTechniquesPlaceholder(scrollView:getY())
    else
        local y = 0
        for _, data in ipairs(techniques) do
            local screenY = scrollView:getY() + y + yOffset
            -- Only render if visible
            if screenY + LAYOUT.techniqueSlotHeight >= scrollView:getY() and 
               screenY < scrollView:getY() + scrollView:getHeight() then
                self:renderTechniqueSlot(
                    scrollView:getX(), 
                    screenY, 
                    scrollView:getWidth(), 
                    LAYOUT.techniqueSlotHeight, 
                    data
                )
            end
            y = y + LAYOUT.techniqueSlotHeight + LAYOUT.techniqueSlotSpacing
        end
    end
end

function TechniqueWindow:renderNoTechniquesPlaceholder(startY)
    local placeholderHeight = 100
    local x = self.techniqueScrollView:getX()
    local width = self.techniqueScrollView:getWidth()
    local y = startY
    
    local bgPlaceholder = THEME.bgPlaceholder
    local borderColor = THEME.borderDivider
    local textDim = THEME.textDim
    local textMuted = THEME.textMuted
    
    -- Background
    self:drawRect(x, y, width, placeholderHeight, bgPlaceholder.a, bgPlaceholder.r, bgPlaceholder.g, bgPlaceholder.b)
    
    -- Dashed border effect
    for i = 0, math.floor(width / 12) do
        self:drawRect(x + i * 12, y, 6, 1, borderColor.a, borderColor.r, borderColor.g, borderColor.b)
        self:drawRect(x + i * 12, y + placeholderHeight - 1, 6, 1, borderColor.a, borderColor.r, borderColor.g, borderColor.b)
    end
    
    local centerX = x + width / 2
    local textY = y + 20
    
    -- Question mark
    self:drawText("?", centerX - 6, textY, textMuted.r, textMuted.g, textMuted.b, 0.5, UIFont.Large)
    textY = textY + FONT_HGT_LARGE + 6
    
    -- Messages
    local msg1 = "No techniques discovered yet"
    local msg1Width = CUI_Tools.measureText(msg1, UIFont.Medium)
    self:drawText(msg1, centerX - msg1Width / 2, textY, textDim.r, textDim.g, textDim.b, 0.9, UIFont.Medium)
    textY = textY + FONT_HGT_MEDIUM + 4
    
    local msg2 = "Explore the world to find technique manuscripts"
    local msg2Width = CUI_Tools.measureText(msg2, UIFont.Small)
    self:drawText(msg2, centerX - msg2Width / 2, textY, textMuted.r, textMuted.g, textMuted.b, 0.7, UIFont.Small)
end

function TechniqueWindow:renderTechniqueSlot(x, y, width, height, data)
    local technique = data.technique
    local stage = data.stage or 1
    local maxStage = technique.maxStage or 5
    local isMaxStage = stage >= maxStage
    
    local bgSlot = THEME.bgSlot
    local textPrimary = THEME.textPrimary
    local textDim = THEME.textDim
    local bgXp = THEME.bgInput
    local accentXp = THEME.accentSuccess
    
    -- Get stage-specific accent color
    local accent = THEME.accentPrimary
    if stage == 5 then  -- Transcendent
        accent = COLORS.stageGold
    elseif stage == 4 then  -- Perfected
        accent = COLORS.stagePurple
    end
    
    -- Layout constants
    local slotPadding = LAYOUT.techniqueSlotPadding
    local lineSpacing = LAYOUT.lineSpacing
    local accentBarWidth = 4
    
    -- Slot background
    self:drawRect(x, y, width, height, bgSlot.a, bgSlot.r, bgSlot.g, bgSlot.b)
    
    -- Left accent bar (colored by stage)
    self:drawRect(x, y, accentBarWidth, height, accent.a, accent.r, accent.g, accent.b)
    
    -- Text area
    local textX = x + accentBarWidth + slotPadding + 4
    local textY = y + slotPadding
    local maxTextWidth = width - accentBarWidth - slotPadding * 2 - 8
    
    -- Technique name
    local name = technique.name or data.id
    local displayName = CUI_Tools.truncateText(name, maxTextWidth, UIFont.Medium)
    self:drawText(displayName, textX, textY, textPrimary.r, textPrimary.g, textPrimary.b, 1, UIFont.Medium)
    
    textY = textY + FONT_HGT_MEDIUM + lineSpacing
    
    -- Stage name (prominent)
    local stageData = TechniqueRegistry.STAGE_DATA[stage]
    local stageName = stageData and stageData.name or tostring(stage)
    self:drawText(stageName, textX, textY, accent.r, accent.g, accent.b, 1, UIFont.Small)
    
    textY = textY + FONT_HGT_SMALL + lineSpacing
    
    -- Stage description (vague, atmospheric)
    local stageDesc = STAGE_DESCRIPTIONS[stage] or ""
    stageDesc = CUI_Tools.truncateText(stageDesc, maxTextWidth, UIFont.Small)
    self:drawText(stageDesc, textX, textY, textDim.r, textDim.g, textDim.b, 0.7, UIFont.Small)
    
    textY = textY + FONT_HGT_SMALL + lineSpacing
    
    -- Effects (vague description)
    local effectsText = self:formatEffectsVague(data.effects, stage)
    if effectsText ~= "" then
        effectsText = CUI_Tools.truncateText(effectsText, maxTextWidth, UIFont.Small)
        self:drawText(effectsText, textX, textY, THEME.textSuccess.r, THEME.textSuccess.g, THEME.textSuccess.b, 0.75, UIFont.Small)
    end
    
    -- DEBUG ONLY: XP progress bar (positioned in top-right)
    if isDebugMode and not isMaxStage then
        local barWidth = 90
        local barHeight = LAYOUT.xpBarHeight
        local barX = x + width - barWidth - slotPadding
        local barY = y + slotPadding + 2
        
        -- XP bar background
        self:drawRect(barX, barY, barWidth, barHeight, bgXp.a, bgXp.r, bgXp.g, bgXp.b)
        
        -- XP bar fill
        local xpPercent = data.xp / math.max(data.xpRequired, 1)
        local fillWidth = barWidth * xpPercent
        self:drawRect(barX, barY, fillWidth, barHeight, accentXp.a, accentXp.r, accentXp.g, accentXp.b)
        
        -- XP bar border
        self:drawRectBorder(barX, barY, barWidth, barHeight, 0.3, 0.4, 0.4, 0.5)
        
        -- XP text
        local xpText = string.format("%.0f/%.0f", data.xp, data.xpRequired)
        local xpTextWidth = CUI_Tools.measureText(xpText, UIFont.Small)
        self:drawText(xpText, barX + (barWidth - xpTextWidth) / 2, barY, 1, 1, 1, 0.8, UIFont.Small)
    end
    
    -- Bottom separator line (inside slot, with padding from edges)
    local separatorColor = THEME.borderDivider
    self:drawRect(x + accentBarWidth + slotPadding, y + height - 1, width - accentBarWidth - slotPadding * 2, 1, 
        separatorColor.a * 0.4, separatorColor.r, separatorColor.g, separatorColor.b)
end

--- Format effects in a vague, non-numeric way
function TechniqueWindow:formatEffectsVague(effects, stage)
    local parts = {}
    
    -- Handle Devouring Elephant technique effects
    if effects.healingEnabled then
        table.insert(parts, "Devours calories for healing")
    end
    if effects.hpRegenEnabled then
        table.insert(parts, "Restores vitality")
    end
    if effects.weightConversionEnabled then
        table.insert(parts, "Burns body fat to survive")
    end
    
    -- Handle other numeric effect types
    local effectDescriptions = {
        enduranceDrainReduction = "Conserves stamina",
        stiffnessReduction = "Eases muscle tension",
        attackEnduranceReduction = "Lightens attacks",
        zombieAttractionReduction = "Masks your presence",
        cultivationSpeedPenalty = "Dampens growth",
        -- Legacy multiplier effects (if any techniques still use them)
        muscleRecoveryMultiplier = "Enhances recovery",
        healthRegenMultiplier = "Mends wounds",
        woundHealingMultiplier = "Heals injuries",
        calorieEfficiency = "Optimizes energy use",
    }
    
    for name, value in pairs(effects) do
        if type(value) == "number" and value > 0 then
            local desc = effectDescriptions[name]
            if desc then
                table.insert(parts, desc)
            end
        end
    end
    
    if #parts == 0 then
        return ""
    end
    
    -- Limit to first 2 effects
    if #parts > 2 then
        return parts[1] .. ", " .. parts[2]
    end
    
    return table.concat(parts, ", ")
end

--==============================================================================
-- MOUSE HANDLING
--==============================================================================

function TechniqueWindow:onMouseDown(x, y)
    if y < LAYOUT.headerHeight then
        self.moving = true
        self.dragX = x
        self.dragY = y
        return true
    end
    return false
end

function TechniqueWindow:onMouseUp(x, y)
    self.moving = false
    return false
end

function TechniqueWindow:onMouseUpOutside(x, y)
    self.moving = false
    return false
end

function TechniqueWindow:onMouseMove(dx, dy)
    if self.moving then
        self:setX(self.x + dx)
        self:setY(self.y + dy)
        return true
    end
    return false
end

function TechniqueWindow:onMouseMoveOutside(dx, dy)
    if self.moving then
        self:setX(self.x + dx)
        self:setY(self.y + dy)
        return true
    end
    return false
end

--==============================================================================
-- UPDATE
--==============================================================================

function TechniqueWindow:update()
    ISPanel.update(self)
    
    self._tickCounter = self._tickCounter + 1
    
    if not self._cachedScreenHeight or self._tickCounter % 120 == 0 then
        self._cachedScreenHeight = getCore():getScreenHeight()
    end
    
    -- Calculate dynamic height
    local techniques = self:getLearnedTechniques()
    local baseHeight = LAYOUT.headerHeight + LAYOUT.padding * 2 
        + LAYOUT.cultivationRowHeight + LAYOUT.sectionSpacing
        + LAYOUT.dividerHeight + LAYOUT.sectionSpacing
        + FONT_HGT_MEDIUM + 8
    
    local techniquesHeight
    if #techniques == 0 then
        techniquesHeight = 100 + LAYOUT.padding
    else
        techniquesHeight = #techniques * (LAYOUT.techniqueSlotHeight + LAYOUT.techniqueSlotSpacing) + LAYOUT.padding
    end
    
    -- Limit max techniques area height for scrolling
    local maxTechniquesHeight = 250
    techniquesHeight = math.min(techniquesHeight, maxTechniquesHeight)
    
    local contentHeight = baseHeight + techniquesHeight
    contentHeight = math.max(contentHeight, Config.techniqueWindow.minHeight)
    contentHeight = math.min(contentHeight, self._cachedScreenHeight - 80)
    
    if self.height ~= contentHeight then
        self:setHeight(contentHeight)
        
        -- Update scroll view height
        if self.techniqueScrollView then
            local scrollY = LAYOUT.headerHeight + LAYOUT.padding 
                + LAYOUT.cultivationRowHeight + LAYOUT.sectionSpacing 
                + LAYOUT.dividerHeight + LAYOUT.sectionSpacing
                + FONT_HGT_MEDIUM + 8
            local scrollHeight = contentHeight - scrollY - LAYOUT.padding
            self.techniqueScrollView:setHeight(scrollHeight)
        end
    end
    
    -- Update close button position
    if self.closeButton then
        self.closeButton:setX(self.width - LAYOUT.closeButtonSize - 6)
    end
end

return TechniqueWindow
