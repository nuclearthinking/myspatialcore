-- Spatial Refuge Radial Menu Integration
-- Hooks into Q button radial menu to add refuge entry action

-- Assume dependencies are already loaded
SpatialRefuge = SpatialRefuge or {}
SpatialRefugeConfig = SpatialRefugeConfig or {}

-- Store original function reference
if not SpatialRefuge.original_showRadialMenu then
    SpatialRefuge.original_showRadialMenu = ISVehicleMenu.showRadialMenu
end

-- Add refuge entry action to radial menu
function SpatialRefuge.AddRadialMenuAction(player)
    if not player then 
        if getDebug() then
            print("[SpatialRefuge] AddRadialMenuAction: No player")
        end
        return 
    end
    
    if getDebug() then
        print("[SpatialRefuge] AddRadialMenuAction called for player: " .. tostring(player:getUsername()))
    end
    
    -- Check if player can enter refuge
    local canEnter, reason = SpatialRefuge.CanEnterRefuge(player)
    if getDebug() then
        print("[SpatialRefuge] CanEnterRefuge result: " .. tostring(canEnter) .. ", reason: " .. tostring(reason))
    end
    
    if not canEnter then
        if getDebug() then
            print("[SpatialRefuge] Not showing radial menu option: " .. tostring(reason))
        end
        return  -- Don't show action if can't enter
    end
    
    -- Get player's radial menu
    local menu = getPlayerRadialMenu(player:getPlayerNum())
    if not menu then 
        if getDebug() then
            print("[SpatialRefuge] Failed to get radial menu for player " .. player:getPlayerNum())
        end
        return 
    end
    
    if getDebug() then
        print("[SpatialRefuge] Adding slice to radial menu")
    end
    
    -- Add refuge entry slice (with cast time)
    menu:addSlice(
        "Enter Spatial Refuge",
        nil,  -- TODO: Add custom icon texture
        SpatialRefuge.BeginTeleportCast,
        player
    )
    
    if getDebug() then
        print("[SpatialRefuge] Slice added successfully")
    end
end

-- Override showRadialMenu to inject our custom action
function ISVehicleMenu.showRadialMenu(player, ...)
    if getDebug() then
        print("[SpatialRefuge] showRadialMenu override called")
    end
    
    -- Call original function first (preserve vehicle interactions)
    SpatialRefuge.original_showRadialMenu(player, ...)
    
    -- Add our custom refuge action
    SpatialRefuge.AddRadialMenuAction(player)
end

-- Test if ISVehicleMenu exists
if getDebug() then
    print("[SpatialRefuge] Radial menu integration initialized")
    print("[SpatialRefuge] ISVehicleMenu exists: " .. tostring(ISVehicleMenu ~= nil))
    if ISVehicleMenu then
        print("[SpatialRefuge] ISVehicleMenu.showRadialMenu exists: " .. tostring(ISVehicleMenu.showRadialMenu ~= nil))
    end
    print("[SpatialRefuge] getPlayerRadialMenu exists: " .. tostring(getPlayerRadialMenu ~= nil))
end

return SpatialRefuge

