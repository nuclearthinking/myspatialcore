-- Spatial Refuge System Configuration
-- Defines tier progression, coordinates, and gameplay constants

-- Prevent double-loading
if SpatialRefugeConfig then
    return SpatialRefugeConfig
end

SpatialRefugeConfig = {
    -- Global refuge coordinate space (using edge of mapped world)
    -- These coordinates are in the existing game map but far from normal play areas
    -- Using far west area that has ground but no buildings
    REFUGE_BASE_X = 5983,  -- Clear area west of Muldraugh
    REFUGE_BASE_Y = 8000,  -- North area
    REFUGE_BASE_Z = 0,
    REFUGE_SPACING = 20,  -- Tiles between refuges
    
    -- Tier definitions: radius determines boundary, size is display name
    TIERS = {
        [0] = { radius = 1, size = 3, cores = 0, displayName = "3x3" },
        [1] = { radius = 2, size = 5, cores = 5, displayName = "5x5" },
        [2] = { radius = 3, size = 7, cores = 10, displayName = "7x7" },
        [3] = { radius = 4, size = 9, cores = 15, displayName = "9x9" },
        [4] = { radius = 5, size = 11, cores = 20, displayName = "11x11" },
        [5] = { radius = 7, size = 15, cores = 30, displayName = "15x15" }
    },
    
    -- Maximum tier (for validation)
    MAX_TIER = 5,
    
    -- Gameplay settings
    TELEPORT_COOLDOWN = 10,  -- seconds between teleports
    COMBAT_TELEPORT_BLOCK = 10,  -- seconds after damage before allowing teleport
    TELEPORT_CAST_TIME = 3,  -- seconds to cast teleport (interruptible)
    
    -- World generation sprites
    SPRITES = {
        FLOOR = "blends_natural_01_16",  -- Grass/dirt floor
        WALL_WEST = "walls_exterior_house_01_0",  -- West wall
        WALL_NORTH = "walls_exterior_house_01_1", -- North wall
        WALL_CORNER_NW = "walls_exterior_house_01_2",
        WALL_CORNER_SE = "walls_exterior_house_01_3",
        SACRED_RELIC = "location_community_cemetery_01_11"  -- Tomb placeholder
    },
    
    -- Sacred Relic world item (approach 2)
    SACRED_RELIC_ITEM = "MySpatialRefuge.SacredRelicBox",

    -- Boundary visibility (true uses visible wall sprites)
    BOUNDARY_VISIBLE = true,
    
    -- ModData keys
    MODDATA_KEY = "MySpatialRefuge",
    REFUGES_KEY = "Refuges",
    
    -- Core item type
    CORE_ITEM = "Base.MagicalCore"
}

return SpatialRefugeConfig
