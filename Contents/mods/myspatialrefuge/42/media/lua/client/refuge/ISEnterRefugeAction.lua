-- ISEnterRefugeAction
-- Timed action for entering Spatial Refuge (with progress bar)

-- Check if ISBaseTimedAction is available
if not ISBaseTimedAction then
    print("[SpatialRefuge] ERROR: ISBaseTimedAction not available! Cannot create ISEnterRefugeAction")
    return
end

-- Create the class
ISEnterRefugeAction = ISBaseTimedAction:derive("ISEnterRefugeAction")

print("[SpatialRefuge] ISEnterRefugeAction class created successfully")

function ISEnterRefugeAction:isValid()
    -- Check if player can still enter refuge
    if not self.player then 
        if getDebug() then print("[SpatialRefuge] isValid: player is nil") end
        return false 
    end
    
    -- Don't re-check cooldown during the action (already checked before starting)
    -- This prevents the action from being cancelled mid-cast
    if SpatialRefuge and SpatialRefuge.IsPlayerInRefuge then
        local inRefuge = SpatialRefuge.IsPlayerInRefuge(self.player)
        if inRefuge then
            if getDebug() then print("[SpatialRefuge] isValid: already in refuge") end
            return false
        end
    end
    
    return true
end

function ISEnterRefugeAction:update()
    -- Optional: Add visual effects during channel
    self.character:faceThisObject(self.character)
end

function ISEnterRefugeAction:start()
    -- Set animation (praying/meditating pose)
    self:setActionAnim("Loot")  -- Can change to other animations
    self:setOverrideHandModels(nil, nil)
end

function ISEnterRefugeAction:stop()
    ISBaseTimedAction.stop(self)
end

function ISEnterRefugeAction:perform()
    -- Action completed - teleport player
    ISBaseTimedAction.perform(self)
    
    -- Use self.character (the active character reference maintained by ISBaseTimedAction)
    local player = self.character
    
    print("[SpatialRefuge] ISEnterRefugeAction:perform() called")
    print("[SpatialRefuge] Player object: " .. tostring(player))
    print("[SpatialRefuge] Player position at perform: (" .. player:getX() .. ", " .. player:getY() .. ", " .. player:getZ() .. ")")
    
    if SpatialRefuge and SpatialRefuge.EnterRefuge then
        local success = SpatialRefuge.EnterRefuge(player)
        print("[SpatialRefuge] EnterRefuge returned: " .. tostring(success))
    else
        print("[SpatialRefuge] ERROR: SpatialRefuge.EnterRefuge not available!")
    end
end

function ISEnterRefugeAction:new(player, time)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    
    o.player = player
    o.character = player
    o.stopOnWalk = true  -- Interrupt on movement
    o.stopOnRun = true   -- Interrupt on running
    o.maxTime = time     -- Duration in ticks (180 = 3 seconds)
    
    return o
end

return ISEnterRefugeAction

