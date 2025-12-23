-- Spatial Refuge Keybind (Main Entry Method)
-- Press H key to enter refuge (H for "Home")

-- Assume dependencies are already loaded
SpatialRefuge = SpatialRefuge or {}
SpatialRefugeConfig = SpatialRefugeConfig or {}

-- Keybind handler
local function OnKeyPressed(key)
    if key == Keyboard.KEY_H then
        local player = getPlayer()
        if player then
            if getDebug() then
                print("[SpatialRefuge] H key pressed - attempting refuge entry")
            end
            
            local canEnter, reason = SpatialRefuge.CanEnterRefuge(player)
            if canEnter then
                SpatialRefuge.BeginTeleportCast(player)
            else
                player:Say(reason or "Cannot enter refuge")
                if getDebug() then
                    print("[SpatialRefuge] Cannot enter: " .. tostring(reason))
                end
            end
        end
    end
end

-- Register keybind
Events.OnKeyPressed.Add(OnKeyPressed)

print("[SpatialRefuge] Keybind registered: Press H to enter refuge")

return SpatialRefuge

