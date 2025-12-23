-- Spatial Refuge Teleportation Module
-- Handles entry/exit teleportation with validation

-- Assume dependencies are already loaded
SpatialRefuge = SpatialRefuge or {}
SpatialRefugeConfig = SpatialRefugeConfig or {}

-- Check if player can enter refuge
-- Returns: canEnter (boolean), reason (string)
function SpatialRefuge.CanEnterRefuge(player)
    if not player then
        return false, "Invalid player"
    end
    
    if getDebug() then
        print("[SpatialRefuge] CanEnterRefuge: Starting validation checks")
    end
    
    -- Check if already in refuge
    if SpatialRefuge.IsPlayerInRefuge and SpatialRefuge.IsPlayerInRefuge(player) then
        if getDebug() then
            print("[SpatialRefuge] CanEnterRefuge: Player already in refuge")
        end
        return false, "Already in refuge"
    end
    
    -- Check if in vehicle
    if player:getVehicle() then
        if getDebug() then
            print("[SpatialRefuge] CanEnterRefuge: Player in vehicle")
        end
        return false, "Cannot enter refuge while in vehicle"
    end
    
    -- Check if climbing or falling (with safety checks)
    local isClimbing = false
    local isFalling = false
    
    if player.isClimbing then
        isClimbing = player:isClimbing()
    end
    
    if player.isFalling then
        isFalling = player:isFalling()
    end
    
    if isClimbing or isFalling then
        if getDebug() then
            print("[SpatialRefuge] CanEnterRefuge: Player climbing or falling")
        end
        return false, "Cannot enter refuge while climbing or falling"
    end
    
    -- Check cooldown (using game timestamp, not os.time())
    local lastTeleport = SpatialRefuge.GetLastTeleportTime and SpatialRefuge.GetLastTeleportTime(player) or 0
    local now = getTimestamp and getTimestamp() or 0
    local cooldown = SpatialRefugeConfig.TELEPORT_COOLDOWN or 60
    
    if getDebug() then
        print("[SpatialRefuge] CanEnterRefuge: Cooldown check - last: " .. tostring(lastTeleport) .. ", now: " .. tostring(now) .. ", diff: " .. tostring(now - lastTeleport))
    end
    
    if now - lastTeleport < cooldown then
        local remaining = cooldown - (now - lastTeleport)
        if getDebug() then
            print("[SpatialRefuge] CanEnterRefuge: Cooldown active (" .. remaining .. "s remaining)")
        end
        return false, "Refuge portal charging... (" .. remaining .. "s)"
    end
    
    -- Check combat teleport blocking (if recently damaged)
    local lastDamage = SpatialRefuge.GetLastDamageTime and SpatialRefuge.GetLastDamageTime(player) or 0
    local combatBlock = SpatialRefugeConfig.COMBAT_TELEPORT_BLOCK or 10
    
    if getDebug() then
        print("[SpatialRefuge] CanEnterRefuge: Combat check - last damage: " .. tostring(lastDamage) .. ", now: " .. tostring(now) .. ", diff: " .. tostring(now - lastDamage))
    end
    
    if now - lastDamage < combatBlock then
        if getDebug() then
            print("[SpatialRefuge] CanEnterRefuge: Combat block active")
        end
        return false, "Cannot teleport during combat!"
    end
    
    if getDebug() then
        print("[SpatialRefuge] CanEnterRefuge: All checks passed - can enter")
    end
    
    return true, nil
end

-- Teleport player to their refuge
function SpatialRefuge.EnterRefuge(player)
    if not player then return false end
    
    print("[SpatialRefuge] EnterRefuge called for player: " .. player:getUsername())
    print("[SpatialRefuge] Current position: (" .. player:getX() .. ", " .. player:getY() .. ", " .. player:getZ() .. ")")
    
    -- Validate player state
    local canEnter, reason = SpatialRefuge.CanEnterRefuge(player)
    if not canEnter then
        print("[SpatialRefuge] EnterRefuge validation failed: " .. tostring(reason))
        player:Say(reason)
        return false
    end
    
    -- Get or create refuge data
    local refugeData = SpatialRefuge.GetRefugeData(player)
    
    -- If no refuge exists, generate it first
    if not refugeData then
        player:Say("Generating Spatial Refuge...")
        refugeData = SpatialRefuge.GenerateNewRefuge(player)
        
        if not refugeData then
            player:Say("Failed to generate refuge!")
            return false
        end
    end
    
    -- Save current world position for return
    local currentX = player:getX()
    local currentY = player:getY()
    local currentZ = player:getZ()
    SpatialRefuge.SaveReturnPosition(player, currentX, currentY, currentZ)
    if getDebug() then
        print("[SpatialRefuge] Saved return position: (" .. tostring(currentX) .. ", " .. tostring(currentY) .. ", " .. tostring(currentZ) .. ")")
    end
    
    -- Teleport to refuge center - schedule on next tick to avoid timed action context issues
    print("[SpatialRefuge] Scheduling teleport from (" .. currentX .. ", " .. currentY .. ", " .. currentZ .. ") to (" .. refugeData.centerX .. ", " .. refugeData.centerY .. ", " .. refugeData.centerZ .. ")")
    
    -- Store teleport data
    local teleportX = refugeData.centerX
    local teleportY = refugeData.centerY
    local teleportZ = refugeData.centerZ
    local teleportPlayer = player
    local refugeId = refugeData.refugeId
    local tier = refugeData.tier or 0
    local tierData = SpatialRefugeConfig.TIERS[tier]
    local radius = tierData and tierData.radius or 1
    
    -- Schedule teleport on next tick (after timed action completes)
    local tickCount = 0
    local teleportDone = false
    local floorPrepared = false
    local relicCreated = false
    local wallsCreated = false
    local maxTicks = 600  -- 10 seconds max wait
    local centerSquareSeen = false
    local postTeleportWaitTicks = 20  -- ~0.33s
    
    local function doTeleport()
        tickCount = tickCount + 1
        
        -- First tick: Execute teleport
        if not teleportDone then
            print("[SpatialRefuge] Executing teleport to (" .. teleportX .. ", " .. teleportY .. ", " .. teleportZ .. ")")
            
            -- Use the native teleportTo method
            teleportPlayer:teleportTo(teleportX, teleportY, teleportZ)
            
            -- Verify the teleport worked
            local newX = teleportPlayer:getX()
            local newY = teleportPlayer:getY()
            local newZ = teleportPlayer:getZ()
            print("[SpatialRefuge] After teleport - player:getX()=" .. newX .. ", player:getY()=" .. newY .. ", player:getZ()=" .. newZ)
            
            -- Force chunk loading by rotating player view to all directions
            -- This ensures chunks in all directions are loaded
            print("[SpatialRefuge] Rotating player view to force chunk loading...")
            -- Face North (0), East (1), South (2), West (3)
            teleportPlayer:setDir(0)  -- Face North
            teleportDone = true
            return  -- Wait for next tick to continue rotation
        end
        
        -- Rotate player to force chunk loading in all directions
        if tickCount == 2 then
            teleportPlayer:setDir(1)  -- Face East
        elseif tickCount == 3 then
            teleportPlayer:setDir(2)  -- Face South
        elseif tickCount == 4 then
            teleportPlayer:setDir(3)  -- Face West
        elseif tickCount == 5 then
            teleportPlayer:setDir(0)  -- Face North again
            print("[SpatialRefuge] Chunk loading rotation complete")
        end
        
        -- Wait a bit after rotation for chunks to fully load
        if tickCount < postTeleportWaitTicks then
            return
        end
        
        -- Check if center square exists and try to create objects
        local cell = getCell()
        if not cell then
            if tickCount % 60 == 0 then
                print("[SpatialRefuge] Cell not available yet... (" .. math.floor(tickCount/60) .. "s)")
            end
            return
        end
        
        local centerSquare = cell:getGridSquare(teleportX, teleportY, teleportZ)
        local centerSquareExists = centerSquare ~= nil
        if centerSquareExists then
            centerSquareSeen = true
        end
        
        -- Ensure floor tiles exist (only once)
        if not floorPrepared then
            if centerSquareExists then
                if SpatialRefuge.EnsureRefugeFloor then
                    SpatialRefuge.EnsureRefugeFloor(teleportX, teleportY, teleportZ, radius + 1)
                    floorPrepared = true
                end
            elseif tickCount % 60 == 0 then
                print("[SpatialRefuge] Center square not found, cannot create floor... (" .. math.floor(tickCount/60) .. "s)")
            end
        end

        -- Try to create boundary walls (only once)
        if not wallsCreated then
            if centerSquareExists then
                -- Check if boundary squares exist (don't require chunk, just square existence)
                local boundarySquaresExist = true
                local missingSquares = {}
                for x = -radius-1, radius+1 do
                    for y = -radius-1, radius+1 do
                        -- Only check perimeter squares (where walls go)
                        local isPerimeter = (x == -radius-1 or x == radius+1) or (y == -radius-1 or y == radius+1)
                        if isPerimeter then
                            local square = cell:getGridSquare(teleportX + x, teleportY + y, teleportZ)
                            if not square then
                                boundarySquaresExist = false
                                table.insert(missingSquares, "(" .. (teleportX + x) .. "," .. (teleportY + y) .. ")")
                            end
                        end
                    end
                end
                
                if boundarySquaresExist then
                    if SpatialRefuge.CreateBoundaryWalls then
                        print("[SpatialRefuge] Attempting to create boundary walls (radius=" .. radius .. ")")
                        local wallsCount = SpatialRefuge.CreateBoundaryWalls(teleportX, teleportY, teleportZ, radius)
                        if wallsCount > 0 then
                            print("[SpatialRefuge] Successfully created " .. wallsCount .. " boundary walls!")
                            wallsCreated = true
                        else
                            if tickCount % 60 == 0 then
                                print("[SpatialRefuge] CreateBoundaryWalls returned 0 walls... (" .. math.floor(tickCount/60) .. "s)")
                            end
                        end
                    end
                elseif tickCount % 60 == 0 then
                    print("[SpatialRefuge] Boundary squares missing: " .. table.concat(missingSquares, ", ") .. " (" .. math.floor(tickCount/60) .. "s)")
                end
            elseif tickCount % 60 == 0 then
                print("[SpatialRefuge] Center square not found, cannot create walls... (" .. math.floor(tickCount/60) .. "s)")
            end
        end

        -- Try to create Sacred Relic (only once, after walls)
        if not relicCreated then
            if centerSquareExists then
                if SpatialRefuge.CreateSacredRelic then
                    print("[SpatialRefuge] Attempting to create Sacred Relic at (" .. teleportX .. ", " .. teleportY .. ")")
                    local relic = SpatialRefuge.CreateSacredRelic(teleportX, teleportY, teleportZ, refugeId)
                    if relic then
                        print("[SpatialRefuge] Sacred Relic created successfully!")
                        relicCreated = true
                    else
                        if tickCount % 60 == 0 then
                            print("[SpatialRefuge] Failed to create Sacred Relic (chunk check failed?)... (" .. math.floor(tickCount/60) .. "s)")
                        end
                    end
                end
            elseif tickCount % 60 == 0 then
                print("[SpatialRefuge] Center square not found, waiting... (" .. math.floor(tickCount/60) .. "s)")
            end
        end
        
        -- Stop if everything is done or max time reached
        if (floorPrepared and relicCreated and wallsCreated) or tickCount >= maxTicks then
            if tickCount >= maxTicks then
                print("[SpatialRefuge] Timeout waiting for chunks to load. Floor: " .. tostring(floorPrepared) .. ", Relic: " .. tostring(relicCreated) .. ", Walls: " .. tostring(wallsCreated))
                if not centerSquareSeen then
                    teleportPlayer:Say("Refuge area not loaded. Adjust base coordinates.")
                end
            end
            Events.OnTick.Remove(doTeleport)
        end
    end
    
    -- Schedule for next tick
    Events.OnTick.Add(doTeleport)
    
    -- Update teleport timestamp
    SpatialRefuge.UpdateTeleportTime(player)
    
    -- Visual/audio feedback
    addSound(player, refugeData.centerX, refugeData.centerY, refugeData.centerZ, 10, 1)
    player:Say("Entered Spatial Refuge")
    
    print("[SpatialRefuge] Player " .. player:getUsername() .. " teleportation complete")
    
    return true
end

-- Teleport player back to world from refuge
function SpatialRefuge.ExitRefuge(player)
    if not player then return false end
    
    -- Check if actually in refuge
    if not SpatialRefuge.IsPlayerInRefuge(player) then
        player:Say("Not in refuge")
        return false
    end
    
    -- Get return position
    local returnPos = SpatialRefuge.GetReturnPosition(player)
    if getDebug() then
        if returnPos then
            print("[SpatialRefuge] ExitRefuge return position: (" .. tostring(returnPos.x) .. ", " .. tostring(returnPos.y) .. ", " .. tostring(returnPos.z) .. ")")
        else
            print("[SpatialRefuge] ExitRefuge return position missing")
        end
    end
    
    if not returnPos then
        -- Fallback: return to spawn point
        player:Say("Warning: Return position not found!")
        
        -- Try to get a safe spawn location
        local spawnRegion = nil
        if player.getSpawnRegion then
            spawnRegion = player:getSpawnRegion()
        end
        if spawnRegion then
            player:setX(spawnRegion:getX())
            player:setY(spawnRegion:getY())
            player:setZ(0)
        else
            -- Last resort: just move away from refuge area
            player:setX(100)
            player:setY(100)
            player:setZ(0)
        end
    else
        -- Teleport back to saved position
        if player.teleportTo then
            player:teleportTo(returnPos.x, returnPos.y, returnPos.z)
        else
            player:setX(returnPos.x)
            player:setY(returnPos.y)
            player:setZ(returnPos.z)
        end
        player:setLastX(returnPos.x)
        player:setLastY(returnPos.y)
        player:setLastZ(returnPos.z)
        if getDebug() then
            print("[SpatialRefuge] ExitRefuge after teleport: (" .. tostring(player:getX()) .. ", " .. tostring(player:getY()) .. ", " .. tostring(player:getZ()) .. ")")
        end
    end
    
    -- Clear return position
    SpatialRefuge.ClearReturnPosition(player)
    
    -- Update teleport timestamp
    SpatialRefuge.UpdateTeleportTime(player)
    
    -- Visual/audio feedback
    addSound(player, player:getX(), player:getY(), player:getZ(), 10, 1)
    player:Say("Exited Spatial Refuge")
    
    if getDebug() then
        print("[SpatialRefuge] Player " .. player:getUsername() .. " exited refuge")
    end
    
    return true
end

return SpatialRefuge
