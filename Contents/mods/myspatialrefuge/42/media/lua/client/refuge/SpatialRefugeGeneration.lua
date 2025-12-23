-- Spatial Refuge Generation Module
-- Handles programmatic world generation for refuge spaces

-- Assume SpatialRefuge and SpatialRefugeConfig are already loaded
SpatialRefuge = SpatialRefuge or {}
SpatialRefugeConfig = SpatialRefugeConfig or {}

-- Create a floor tile at specific coordinates
-- Returns: true if successful, false otherwise
function SpatialRefuge.CreateFloorTile(x, y, z, sprite)
    -- Safety check for game API
    if not getCell then
        if getDebug() then
            print("[SpatialRefuge] ERROR: getCell() function not available")
        end
        return false
    end
    
    local cell = getCell()
    if not cell then
        if getDebug() then
            print("[SpatialRefuge] ERROR: getCell() returned nil")
        end
        return false
    end
    
    local square = cell:getOrCreateGridSquare(x, y, z)
    if not square then
        if getDebug() then
            print("[SpatialRefuge] Failed to get/create grid square at (" .. x .. ", " .. y .. ", " .. z .. ")")
        end
        return false
    end
    
    -- Check if floor already exists
    if square:getFloor() then
        return true  -- Already has floor
    end
    
    -- Add grass/dirt floor
    local floorSprite = sprite or SpatialRefugeConfig.SPRITES.FLOOR
    local floor = nil
    local ok = pcall(function()
        floor = IsoObject.new(square, floorSprite)
    end)
    if not ok or not floor then
        floor = IsoObject.getNew(square, floorSprite, nil, false)
    end
    if not floor then
        print("[SpatialRefuge] Failed to create floor object at (" .. x .. ", " .. y .. ")")
        return false
    end
    local success, err = pcall(function()
        square:AddTileObject(floor)
        square:RecalcAllWithNeighbours(true)
    end)
    if not success then
        print("[SpatialRefuge] Failed to add floor at (" .. x .. ", " .. y .. "): " .. tostring(err))
        return false
    end
    
    return true
end

-- Ensure a solid floor area exists for the refuge size
-- Returns: number of tiles attempted (for debug)
function SpatialRefuge.EnsureRefugeFloor(centerX, centerY, z, radius)
    local attempted = 0
    for dx = -radius, radius do
        for dy = -radius, radius do
            SpatialRefuge.CreateFloorTile(centerX + dx, centerY + dy, z)
            attempted = attempted + 1
        end
    end
    return attempted
end

-- Create the Sacred Relic at refuge center
-- Returns: IsoThumpable object or nil
local function resolveRelicSprite()
    local spriteName = SpatialRefugeConfig.SPRITES.SACRED_RELIC
    if getSprite and getSprite(spriteName) then
        return spriteName
    end
    local digits = spriteName:match("_(%d+)$")
    if digits then
        local padded2 = spriteName:gsub("_(%d+)$", "_0" .. digits)
        if getSprite and getSprite(padded2) then
            return padded2
        end
        local padded3 = spriteName:gsub("_(%d+)$", "_00" .. digits)
        if getSprite and getSprite(padded3) then
            return padded3
        end
    end
    print("[SpatialRefuge] Warning: Relic sprite not found: " .. tostring(spriteName))
    return nil
end

local function getObjectClassName(obj)
    if not obj or not obj.getClass then return "unknown" end
    local ok, classObj = pcall(function()
        return obj:getClass()
    end)
    if not ok or not classObj or not classObj.getName then
        return "unknown"
    end
    local okName, name = pcall(function()
        return classObj:getName()
    end)
    if not okName or not name then
        return "unknown"
    end
    return name
end

local function getObjectSpriteName(obj)
    if not obj or not obj.getSprite then return "nil" end
    local ok, sprite = pcall(function()
        return obj:getSprite()
    end)
    if not ok or not sprite or not sprite.getName then
        return "nil"
    end
    local okName, name = pcall(function()
        return sprite:getName()
    end)
    if not okName or not name then
        return "nil"
    end
    return name
end

local function getObjectName(obj)
    if not obj then return nil end
    if obj.getObjectName then
        local ok, name = pcall(function()
            return obj:getObjectName()
        end)
        if ok and name then
            return name
        end
    end
    if obj.getName then
        local ok, name = pcall(function()
            return obj:getName()
        end)
        if ok and name then
            return name
        end
    end
    return nil
end

local function getObjectModFlags(obj)
    if not obj or not obj.getModData then return nil end
    local md = obj:getModData()
    if not md then return nil end
    local flags = {}
    if md.isSacredRelic then table.insert(flags, "isSacredRelic") end
    if md.refugeId ~= nil then table.insert(flags, "refugeId=" .. tostring(md.refugeId)) end
    if md.isRefugeBoundary then table.insert(flags, "isRefugeBoundary") end
    if md.refugeInvisibleWall then table.insert(flags, "refugeInvisibleWall") end
    if #flags == 0 then return nil end
    return table.concat(flags, ",")
end

local function getItemModFlags(item)
    if not item or not item.getModData then return nil end
    local md = item:getModData()
    if not md then return nil end
    local flags = {}
    if md.isSacredRelic then table.insert(flags, "isSacredRelic") end
    if md.refugeId ~= nil then table.insert(flags, "refugeId=" .. tostring(md.refugeId)) end
    if #flags == 0 then return nil end
    return table.concat(flags, ",")
end

local function ensureObjectSprite(obj, spriteName)
    if not obj then return false, "no-object" end
    if obj.getSprite and obj:getSprite() then
        return true, "existing"
    end
    if obj.setSpriteFromName then
        local ok = pcall(function()
            obj:setSpriteFromName(spriteName)
        end)
        if ok and obj.getSprite and obj:getSprite() then
            obj.tile = spriteName
            obj.spriteName = spriteName
            return true, "setSpriteFromName"
        end
    end
    if obj.setSprite then
        local ok = pcall(function()
            obj:setSprite(spriteName)
        end)
        if ok and obj.getSprite and obj:getSprite() then
            obj.tile = spriteName
            obj.spriteName = spriteName
            return true, "setSprite"
        end
    end
    if IsoSprite and IsoSpriteManager then
        local created = IsoSprite.CreateSprite(IsoSpriteManager.instance)
        local spriteOk = pcall(function()
            created:LoadFramesNoDirPageSimple(spriteName)
        end)
        if spriteOk then
            if obj.setClosedSprite then
                local ok = pcall(function()
                    obj:setClosedSprite(created)
                end)
                if ok and obj.getSprite and obj:getSprite() then
                    obj.tile = spriteName
                    obj.spriteName = spriteName
                    return true, "setClosedSprite"
                end
            end
            if obj.setSprite then
                local ok = pcall(function()
                    obj:setSprite(created)
                end)
                if ok and obj.getSprite and obj:getSprite() then
                    obj.tile = spriteName
                    obj.spriteName = spriteName
                    return true, "setSpriteObject"
                end
            end
        end
    end
    return false, "failed"
end

local function describeObject(obj)
    local className = getObjectClassName(obj)
    local spriteName = getObjectSpriteName(obj)
    local objName = getObjectName(obj)
    local modFlags = getObjectModFlags(obj)
    local details = "class=" .. tostring(className) .. " sprite=" .. tostring(spriteName)
    if objName then
        details = details .. " name=" .. tostring(objName)
    end
    if modFlags then
        details = details .. " md[" .. modFlags .. "]"
    end
    if obj and obj.getItem then
        local item = obj:getItem()
        if item then
            local itemType = item.getFullType and item:getFullType() or "unknown"
            details = details .. " item=" .. tostring(itemType)
            local itemFlags = getItemModFlags(item)
            if itemFlags then
                details = details .. " itemmd[" .. itemFlags .. "]"
            end
        end
    end
    return details
end

local function dumpSquareContents(square, label)
    if not square then
        print("[SpatialRefuge] " .. tostring(label or "Square") .. " contents: square=nil")
        return
    end
    local x = square.getX and square:getX() or "?"
    local y = square.getY and square:getY() or "?"
    local z = square.getZ and square:getZ() or "?"
    local objects = square:getObjects()
    local count = objects and objects:size() or 0
    print("[SpatialRefuge] " .. tostring(label or "Square") .. " contents at (" .. x .. ", " .. y .. ", " .. z .. ") objects=" .. tostring(count))
    if objects then
        for i = 0, objects:size() - 1 do
            local obj = objects:get(i)
            if obj then
                print("[SpatialRefuge]   obj[" .. i .. "] " .. describeObject(obj))
            end
        end
    end
    if square.getSpecialObjects then
        local special = square:getSpecialObjects()
        local scount = special and special:size() or 0
        if scount > 0 then
            for i = 0, scount - 1 do
                local obj = special:get(i)
                if obj then
                    print("[SpatialRefuge]   special[" .. i .. "] " .. describeObject(obj))
                end
            end
        else
            print("[SpatialRefuge]   specialObjects=0")
        end
    end
    if square.getWorldObjects then
        local worldObjects = square:getWorldObjects()
        local wcount = worldObjects and worldObjects:size() or 0
        if wcount > 0 then
            for i = 0, wcount - 1 do
                local obj = worldObjects:get(i)
                if obj then
                    print("[SpatialRefuge]   worldObj[" .. i .. "] " .. describeObject(obj))
                end
            end
        else
            print("[SpatialRefuge]   worldObjects=0")
        end
    end
    if square.getFloor then
        local floor = square:getFloor()
        local floorSprite = getObjectSpriteName(floor)
        print("[SpatialRefuge]   floorSprite=" .. tostring(floorSprite))
    end
end

local function findRelicOnSquare(square, refugeId)
    if not square then return nil end
    local objects = square:getObjects()
    if objects then
        for i = 0, objects:size() - 1 do
            local obj = objects:get(i)
            if obj then
                local md = obj:getModData()
                if md and md.isSacredRelic and md.refugeId == refugeId then
                    return obj
                end
            end
        end
    end
    if square.getWorldObjects then
        local worldObjects = square:getWorldObjects()
        if worldObjects then
            for i = 0, worldObjects:size() - 1 do
                local obj = worldObjects:get(i)
                if obj then
                    local md = obj.getModData and obj:getModData()
                    if md and md.isSacredRelic and md.refugeId == refugeId then
                        return obj
                    end
                    if obj.getItem then
                        local item = obj:getItem()
                        local imd = item and item.getModData and item:getModData()
                        if imd and imd.isSacredRelic and imd.refugeId == refugeId then
                            return obj
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function createRelicWorldItem(square, refugeId)
    local itemType = SpatialRefugeConfig.SACRED_RELIC_ITEM or "Base.WoodenBox"
    local function spawnWorldItem(typeName)
        local spawned = nil
        local ok, err = pcall(function()
            if square.SpawnWorldInventoryItem then
                spawned = square:SpawnWorldInventoryItem(typeName, 0.5, 0.5, 0)
            elseif square.AddWorldInventoryItem then
                spawned = square:AddWorldInventoryItem(typeName, 0.5, 0.5, 0, true, true)
            end
        end)
        if not ok then
            print("[SpatialRefuge] Failed to spawn world item (" .. tostring(typeName) .. "): " .. tostring(err))
        end
        return spawned
    end

    local item = spawnWorldItem(itemType)
    if not item then
        local fallbackTypes = { "Base.MagicalCore", "Base.Plank", "Base.Book" }
        for _, fallback in ipairs(fallbackTypes) do
            item = spawnWorldItem(fallback)
            if item then
                print("[SpatialRefuge] Sacred Relic item fallback used: " .. tostring(fallback))
                itemType = fallback
                break
            end
        end
    end
    if not item then
        print("[SpatialRefuge] Failed to spawn Sacred Relic item: " .. tostring(itemType))
        return nil
    end

    local worldObj = item.getWorldItem and item:getWorldItem() or nil
    if worldObj then
        if worldObj.updateSprite then worldObj:updateSprite() end
        if worldObj.addToWorld then worldObj:addToWorld() end
    end
    local imd = item:getModData()
    imd.isSacredRelic = true
    imd.refugeId = refugeId
    imd.relicItemType = itemType
    if worldObj and worldObj.getModData then
        local wmd = worldObj:getModData()
        wmd.isSacredRelic = true
        wmd.refugeId = refugeId
        wmd.relicItemType = itemType
    end
    if not worldObj then
        print("[SpatialRefuge] Warning: Sacred Relic world item has no world object (item=" .. tostring(itemType) .. ")")
        return nil
    end
    return worldObj, itemType
end

function SpatialRefuge.CreateSacredRelic(x, y, z, refugeId)
    local cell = getCell()
    if not cell then
        print("[SpatialRefuge] Cannot create Sacred Relic - cell not available")
        return nil
    end
    
    -- Try to get or create the square (same approach as walls)
    local square = cell:getGridSquare(x, y, z)
    if not square then
        square = cell:getOrCreateGridSquare(x, y, z)
    end
    
    if not square then
        print("[SpatialRefuge] Cannot create Sacred Relic - square unavailable at (" .. x .. ", " .. y .. ")")
        return nil
    end
    
    -- Note: Don't check square.chunk - walls work without it, so relic should too
    if not square.chunk then
        print("[SpatialRefuge] Warning: Chunk is null for Sacred Relic, attempting creation anyway...")
    end
    
    -- Check if relic already exists on this square (objects or world items)
    local existing = findRelicOnSquare(square, refugeId)
    if existing then
        if getDebug() then
            print("[SpatialRefuge] Sacred Relic already exists at this location")
        end
        return existing
    end
    
    -- Avoid placing on player's exact square (can hide object)
    if getPlayer then
        local player = getPlayer()
        if player and player:getX() == x and player:getY() == y and player:getZ() == z then
            x = x + 1
            y = y + 1
            square = cell:getGridSquare(x, y, z) or cell:getOrCreateGridSquare(x, y, z)
        end
    end

    local spriteName = nil
    local relic, relicItemType = createRelicWorldItem(square, refugeId)
    if relic then
        print("[SpatialRefuge] Created Sacred Relic world item at (" .. x .. ", " .. y .. ") using " .. tostring(relicItemType))
    end
    if not relic then
        spriteName = resolveRelicSprite()
        if not spriteName then
            print("[SpatialRefuge] Sacred Relic creation aborted - sprite not found")
            return nil
        end
        local isThumpable = false
        local ok = false
        if IsoThumpable then
            ok = pcall(function()
                relic = IsoThumpable.new(cell, square, spriteName, false)
            end)
            if ok and relic then
                isThumpable = true
            end
        end
        if not relic then
            ok = pcall(function()
                relic = IsoObject.new(square, spriteName, "SacredRelic", true)
            end)
        end
        if not ok or not relic then
            ok = pcall(function()
                relic = IsoObject.new(square, spriteName)
            end)
        end
        if not ok or not relic then
            relic = IsoObject.getNew(square, spriteName, "SacredRelic", true)
        end
        if not relic then
            print("[SpatialRefuge] Failed to create Sacred Relic object for sprite: " .. tostring(spriteName))
            return nil
        end

        local spriteOk, spriteSource = ensureObjectSprite(relic, spriteName)
        if not spriteOk then
            print("[SpatialRefuge] Warning: Sacred Relic sprite still nil after ensure (" .. tostring(spriteSource) .. ")")
        end
        
        -- Configure relic properties when supported
        if relic.setSpecialTooltip then relic:setSpecialTooltip(true) end
        if relic.setCanBarricade then relic:setCanBarricade(false) end
        if relic.setIsThumpable then relic:setIsThumpable(false) end
        if relic.setBreakSound then relic:setBreakSound("none") end
        if relic.setMaxHealth then relic:setMaxHealth(999999) end
        if relic.setHealth then relic:setHealth(999999) end
        
        -- Store metadata
        local md = relic:getModData()
        md.isSacredRelic = true
        md.refugeId = refugeId
        
        -- Add to square (wrap in pcall to catch chunk errors, same as walls)
        local success, err = pcall(function()
            if isThumpable and square.AddSpecialObject then
                square:AddSpecialObject(relic)
            elseif square.transmitAddObjectToSquare then
                square:transmitAddObjectToSquare(relic, -1)
            else
                square:AddTileObject(relic)
            end
            square:RecalcAllWithNeighbours(true)
        end)
        
        if not success then
            print("[SpatialRefuge] Failed to add Sacred Relic to square at (" .. x .. ", " .. y .. "): " .. tostring(err))
            return nil
        end
    end
    
    -- World item is already added to square, other relics are added above.
    
    local confirmed = findRelicOnSquare(square, refugeId)
    local relicSpriteName = relic.getSprite and relic:getSprite() and relic:getSprite():getName() or "nil"
    local sourceLabel = spriteName or relicItemType or SpatialRefugeConfig.SACRED_RELIC_ITEM or "unknown"
    print("[SpatialRefuge] Created Sacred Relic at (" .. x .. ", " .. y .. ") using " .. tostring(sourceLabel) .. ", confirmed=" .. tostring(confirmed ~= nil) .. ", sprite=" .. tostring(relicSpriteName))
    dumpSquareContents(square, "Relic square")
    
    return relic
end

-- Create an invisible boundary wall (blocks movement)
-- Returns: IsoThumpable object or nil
local function addBoundarySprite(square, spriteName)
    local wallObj = IsoObject.getNew(square, spriteName, nil, false)
    local md = wallObj:getModData()
    md.isRefugeBoundary = true
    md.refugeBoundarySprite = spriteName
    local success, err = pcall(function()
        square:AddTileObject(wallObj)
        square:RecalcAllWithNeighbours(true)
    end)
    if not success then
        print("[SpatialRefuge] Failed to add wall sprite " .. tostring(spriteName) .. ": " .. tostring(err))
        return false
    end
    return true
end

function SpatialRefuge.CreateVisibleWall(x, y, z, addNorth, addWest, cornerSprite)
    if not getCell then return nil end
    local cell = getCell()
    if not cell then return nil end

    local square = cell:getGridSquare(x, y, z)
    if not square then
        square = cell:getOrCreateGridSquare(x, y, z)
    end
    if not square then
        print("[SpatialRefuge] Cannot create visible wall - square unavailable at (" .. x .. ", " .. y .. ")")
        return nil
    end

    local created = false
    if addNorth then
        created = addBoundarySprite(square, SpatialRefugeConfig.SPRITES.WALL_NORTH) or created
    end
    if addWest then
        created = addBoundarySprite(square, SpatialRefugeConfig.SPRITES.WALL_WEST) or created
    end
    if cornerSprite then
        created = addBoundarySprite(square, cornerSprite) or created
    end

    if created then
        print("[SpatialRefuge] Created boundary wall at (" .. x .. ", " .. y .. ")")
    end
    return created and square or nil
end

function SpatialRefuge.CreateInvisibleWall(x, y, z, isNorthWall)
    if not getCell then return nil end
    
    local cell = getCell()
    if not cell then return nil end
    
    -- Try to get or create the square
    local square = cell:getGridSquare(x, y, z)
    if not square then
        -- Try getOrCreateGridSquare to force square creation
        square = cell:getOrCreateGridSquare(x, y, z)
    end
    
    if not square then
        print("[SpatialRefuge] Cannot create wall - square unavailable at (" .. x .. ", " .. y .. ")")
        return nil
    end
    
    -- Note: We'll try to create the wall even if chunk is null
    -- Some areas might not have chunks but still allow object creation
    if not square.chunk then
        print("[SpatialRefuge] Warning: Chunk is null at (" .. x .. ", " .. y .. "), attempting wall creation anyway...")
    end
    
    local useVisible = SpatialRefugeConfig.BOUNDARY_VISIBLE == true
    if useVisible then
        return SpatialRefuge.CreateVisibleWall(x, y, z, isNorthWall, not isNorthWall, false)
    end

    -- Use a very small, nearly invisible sprite
    local spriteName = "location_community_cemetery_01_35"
    
    -- Create wall using IsoThumpable
    local wall = IsoThumpable.new(
        cell,
        square,
        spriteName,
        isNorthWall,
        {}
    )
    
    if not wall then return nil end
    
    -- Make it indestructible and collision-only
    wall:setMaxHealth(999999)
    wall:setHealth(999999)
    wall:setCanBarricade(false)
    wall:setIsThumpable(false)
    wall:setBreakSound("none")
    wall:setSpecialTooltip(false)
    
    if not useVisible then
        wall:setAlpha(0.0)
    end
    
    -- Mark as boundary wall for identification
    local md = wall:getModData()
    md.isRefugeBoundary = true
    md.refugeInvisibleWall = true
    
    -- Add to square (wrap in pcall to catch chunk errors)
    local success, err = pcall(function()
        square:AddSpecialObject(wall)
        square:RecalcAllWithNeighbours(true)
    end)
    
    if not success then
        print("[SpatialRefuge] Failed to add wall to square at (" .. x .. ", " .. y .. "): " .. tostring(err))
        return nil
    end
    
    print("[SpatialRefuge] Created invisible wall at (" .. x .. ", " .. y .. ")")
    
    return wall
end

-- Create invisible boundary walls around a refuge area
-- Returns: number of walls created
function SpatialRefuge.CreateBoundaryWalls(centerX, centerY, z, radius)
    local wallsCreated = 0

    -- Ensure wall squares have floors so wall sprites render correctly
    SpatialRefuge.EnsureRefugeFloor(centerX, centerY, z, radius + 1)
    local useVisible = SpatialRefugeConfig.BOUNDARY_VISIBLE == true

    local minX = centerX - radius
    local maxX = centerX + radius
    local minY = centerY - radius
    local maxY = centerY + radius

    if useVisible then
        -- Match .tbx wall placement: top (N) at y=minY, left (W) at x=minX
        -- Bottom/right edges are offset by +1 to reuse the same wall sprites.
        for x = minX, maxX do
            if SpatialRefuge.CreateVisibleWall(x, minY, z, true, false, nil) then
                wallsCreated = wallsCreated + 1
            end
            if SpatialRefuge.CreateVisibleWall(x, maxY + 1, z, true, false, nil) then
                wallsCreated = wallsCreated + 1
            end
        end

        for y = minY, maxY do
            if SpatialRefuge.CreateVisibleWall(minX, y, z, false, true, nil) then
                wallsCreated = wallsCreated + 1
            end
            if SpatialRefuge.CreateVisibleWall(maxX + 1, y, z, false, true, nil) then
                wallsCreated = wallsCreated + 1
            end
        end

        -- Corner overlays (only NW and SE exist in this tileset)
        SpatialRefuge.CreateVisibleWall(minX, minY, z, false, false, SpatialRefugeConfig.SPRITES.WALL_CORNER_NW)
        SpatialRefuge.CreateVisibleWall(maxX + 1, maxY + 1, z, false, false, SpatialRefugeConfig.SPRITES.WALL_CORNER_SE)

        print("[SpatialRefuge] Created " .. wallsCreated .. " boundary walls around (" .. centerX .. ", " .. centerY .. ")")
        return wallsCreated
    end

    -- Invisible collision walls (original behavior)
    for x = -radius-1, radius+1 do
        local wall = SpatialRefuge.CreateInvisibleWall(centerX + x, centerY - radius - 1, z, true)
        if wall then wallsCreated = wallsCreated + 1 end
        wall = SpatialRefuge.CreateInvisibleWall(centerX + x, centerY + radius + 1, z, true)
        if wall then wallsCreated = wallsCreated + 1 end
    end

    for y = -radius, radius do
        local wall = SpatialRefuge.CreateInvisibleWall(centerX - radius - 1, centerY + y, z, false)
        if wall then wallsCreated = wallsCreated + 1 end
        wall = SpatialRefuge.CreateInvisibleWall(centerX + radius + 1, centerY + y, z, false)
        if wall then wallsCreated = wallsCreated + 1 end
    end

    print("[SpatialRefuge] Created " .. wallsCreated .. " invisible boundary walls around (" .. centerX .. ", " .. centerY .. ")")
    return wallsCreated
end

-- Remove boundary walls (for expansion)
function SpatialRefuge.RemoveBoundaryWalls(centerX, centerY, z, radius)
    local wallsRemoved = 0
    
    -- Remove walls in perimeter area (slightly larger to catch all)
    for x = -radius-2, radius+2 do
        for y = -radius-2, radius+2 do
            local square = getCell():getGridSquare(centerX + x, centerY + y, z)
            if square then
                local objects = square:getObjects()
                for i = objects:size()-1, 0, -1 do
                    local obj = objects:get(i)
                    if obj and obj:getModData().isRefugeBoundary then
                        square:transmitRemoveItemFromSquare(obj)
                        wallsRemoved = wallsRemoved + 1
                    end
                end
            end
        end
    end
    
    if getDebug() then
        print("[SpatialRefuge] Removed " .. wallsRemoved .. " boundary walls")
    end
end

-- Generate a new refuge for a player
-- NOTE: We don't actually generate world tiles - we use existing map areas
-- This is a simpler approach that just allocates coordinates and creates the Sacred Relic
function SpatialRefuge.GenerateNewRefuge(player)
    if not player then return nil end
    
    -- Check if world is ready
    if not SpatialRefuge.worldReady then
        if getDebug() then
            print("[SpatialRefuge] World not ready yet, cannot generate refuge")
        end
        return nil
    end
    
    -- Get or create refuge data (allocates coordinates)
    local refugeData = SpatialRefuge.GetOrCreateRefugeData(player)
    if not refugeData then return nil end
    
    local centerX = refugeData.centerX
    local centerY = refugeData.centerY
    local centerZ = refugeData.centerZ
    
    if getDebug() then
        print("[SpatialRefuge] Initializing refuge for " .. player:getUsername() .. " at (" .. centerX .. ", " .. centerY .. ")")
    end
    
    -- Note: Sacred Relic creation moved to post-teleport (see SpatialRefugeTeleport.lua)
    -- This ensures the chunk is fully loaded before creating objects
    
    -- Note: Boundary walls disabled - causing chunk loading errors
    -- Using position monitoring system instead (see SpatialRefugeBoundary.lua)
    
    player:Say("Spatial Refuge initializing...")
    
    return refugeData
end

-- Create visible markers at corners so players can see boundaries
function SpatialRefuge.CreateCornerMarkers(centerX, centerY, z, radius)
    if not getCell then return end
    
    local cell = getCell()
    if not cell then return end
    
    local corners = {
        {x = centerX - radius, y = centerY - radius},  -- Top-left
        {x = centerX + radius, y = centerY - radius},  -- Top-right
        {x = centerX - radius, y = centerY + radius},  -- Bottom-left
        {x = centerX + radius, y = centerY + radius}   -- Bottom-right
    }
    
    for _, corner in ipairs(corners) do
        local square = cell:getGridSquare(corner.x, corner.y, z)
        if square then
            -- Use gravestone as visible marker
            local marker = IsoThumpable.new(
                cell,
                square,
                "location_community_cemetery_01_35",  -- Small gravestone
                false,
                {}
            )
            
            if marker then
                marker:setMaxHealth(999999)
                marker:setHealth(999999)
                marker:setCanBarricade(false)
                marker:setIsThumpable(false)
                
                marker:getModData().refugeBoundaryMarker = true
                
                square:AddSpecialObject(marker)
            end
        end
    end
    
    if getDebug() then
        print("[SpatialRefuge] Created corner markers")
    end
end

-- Expand an existing refuge to a new tier
function SpatialRefuge.ExpandRefuge(refugeData, newTier)
    if not refugeData then return false end
    
    local tierConfig = SpatialRefugeConfig.TIERS[newTier]
    if not tierConfig then return false end
    
    local centerX = refugeData.centerX
    local centerY = refugeData.centerY
    local centerZ = refugeData.centerZ
    local oldRadius = refugeData.radius
    local newRadius = tierConfig.radius
    
    if getDebug() then
        print("[SpatialRefuge] Expanding refuge from radius " .. oldRadius .. " to " .. newRadius)
    end
    
    -- Remove old boundary walls and markers
    SpatialRefuge.RemoveBoundaryWalls(centerX, centerY, centerZ, oldRadius)
    SpatialRefuge.RemoveCornerMarkers(centerX, centerY, centerZ, oldRadius)

    -- Ensure floor exists for the new size (include wall perimeter)
    SpatialRefuge.EnsureRefugeFloor(centerX, centerY, centerZ, newRadius + 1)

    -- Create new boundary walls at new radius
    SpatialRefuge.CreateBoundaryWalls(centerX, centerY, centerZ, newRadius)
    
    -- Create new corner markers
    SpatialRefuge.CreateCornerMarkers(centerX, centerY, centerZ, newRadius)
    
    -- Update refuge data
    refugeData.tier = newTier
    refugeData.radius = newRadius
    refugeData.lastExpanded = getTimestamp()
    SpatialRefuge.SaveRefugeData(refugeData)
    
    if getDebug() then
        print("[SpatialRefuge] Expansion complete - new radius: " .. newRadius)
    end
    
    return true
end

-- Remove corner markers
function SpatialRefuge.RemoveCornerMarkers(centerX, centerY, z, radius)
    if not getCell then return end
    
    local cell = getCell()
    if not cell then return end
    
    -- Remove markers in slightly larger area
    for x = -radius-2, radius+2 do
        for y = -radius-2, radius+2 do
            local square = cell:getGridSquare(centerX + x, centerY + y, z)
            if square then
                local objects = square:getObjects()
                for i = objects:size()-1, 0, -1 do
                    local obj = objects:get(i)
                    if obj and obj:getModData().refugeBoundaryMarker then
                        square:transmitRemoveItemFromSquare(obj)
                    end
                end
            end
        end
    end
end

-- Delete a refuge completely (for death penalty)
function SpatialRefuge.DeleteRefuge(player)
    local refugeData = SpatialRefuge.GetRefugeData(player)
    if not refugeData then return end
    
    local centerX = refugeData.centerX
    local centerY = refugeData.centerY
    local centerZ = refugeData.centerZ
    local radius = refugeData.radius
    
    if getDebug() then
        print("[SpatialRefuge] Deleting refuge for " .. player:getUsername())
    end
    
    -- Remove all world objects in refuge area (including buffer zone)
    local objectsRemoved = 0
    for x = -radius-2, radius+2 do
        for y = -radius-2, radius+2 do
            local square = getCell():getGridSquare(centerX + x, centerY + y, centerZ)
            if square then
                local objects = square:getObjects()
                for i = objects:size()-1, 0, -1 do
                    local obj = objects:get(i)
                    if obj then
                        square:transmitRemoveItemFromSquare(obj)
                        objectsRemoved = objectsRemoved + 1
                    end
                end
            end
        end
    end
    
    if getDebug() then
        print("[SpatialRefuge] Removed " .. objectsRemoved .. " objects")
    end
    
    -- Remove from ModData
    SpatialRefuge.DeleteRefugeData(player)
end

return SpatialRefuge
