# Spatial Refuge

Personal pocket refuge reachable by teleport. A small outdoor space is created at map edges and expands with upgrades.

## Current Behavior (Implemented)

- Entry: press `H` to start a short timed action, then teleport.
- Exit: right-click the Sacred Relic and choose "Exit Refuge".
- One refuge per player, stored in `ModData` under `MySpatialRefuge.Refuges`.
- Floors and boundary walls are created dynamically after teleport.
- Boundary walls use `walls_exterior_house_01_0/1/2/3` with isometric offsets.

## Configuration

See `42/media/lua/shared/SpatialRefugeConfig.lua`:

- `REFUGE_BASE_X/Y/Z`, `REFUGE_SPACING` for placement.
- `TIERS` for size and core costs.
- `SPRITES` for floor and wall tiles.

## Notes

- Generation is client-side after teleport with a short delay to allow grid squares to exist.
- Only NW and SE corner overlays exist in this tileset.



