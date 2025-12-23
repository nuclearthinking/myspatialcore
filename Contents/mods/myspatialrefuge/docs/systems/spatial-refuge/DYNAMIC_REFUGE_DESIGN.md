# Dynamic Spatial Refuge - Technical Design

## Current Implementation (Match Code)

- Entry: `H` key triggers a timed action, then teleport.
- Exit: right-click Sacred Relic and choose "Exit Refuge".
- One refuge per player, keyed by username in `ModData`.
- Coordinates allocated from `SpatialRefugeConfig.REFUGE_BASE_X/Y/Z` with `REFUGE_SPACING`.
- Floors and boundary walls are created after teleport once squares exist.
- Walls follow isometric offsets using `walls_exterior_house_01_0/1/2/3`.
- Generation is client-side; MP sync still TBD.

## Coordinate Rules (Current)

Let `centerX/centerY` be the refuge center, `radius` from tier.

```
minX = centerX - radius
maxX = centerX + radius
minY = centerY - radius
maxY = centerY + radius

Top edge:    y = minY     using WALL_NORTH
Bottom edge: y = maxY + 1 using WALL_NORTH (offset)
Left edge:   x = minX     using WALL_WEST
Right edge:  x = maxX + 1 using WALL_WEST (offset)

Corners:
- NW overlay at (minX, minY)
- SE overlay at (maxX + 1, maxY + 1)
```

Only NW and SE corner overlays exist in the chosen tileset.

## Generation Sequence

1. Teleport player to center.
2. Wait a short delay for squares to exist.
3. Create floors for radius + wall ring.
4. Create Sacred Relic.
5. Create boundary walls.

## Known Gaps / Issues

- No radial menu entry yet (design originally said Q menu).
- MP sync for walls/floors not implemented.
- Only two corner overlay sprites available for walls.

