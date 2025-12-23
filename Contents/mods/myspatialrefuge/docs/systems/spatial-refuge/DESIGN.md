# Spatial Refuge - System Design

## Goals

- Personal refuge per player.
- Expandable outdoor space.
- Timed teleport entry and relic exit.
- Runtime generation without custom map files.

## Data Model

Stored in `ModData.getOrCreate("MySpatialRefuge").Refuges` keyed by username:

```
{
  refugeId = "refuge_" .. username,
  username = username,
  centerX = number,
  centerY = number,
  centerZ = number,
  tier = 0..MAX_TIER,
  radius = number,
  createdTime = timestamp,
  lastExpanded = timestamp
}
```

Return position is stored in `player:getModData().spatialRefuge_return`.

## Entry / Exit

Entry:
- Press `H` to begin a timed action.
- Teleport to refuge center on completion.

Exit:
- Right-click Sacred Relic and choose "Exit Refuge".
- Teleport back to saved return position.

## Generation

- Floors are created for `radius + 1` to include the wall ring.
- Walls are placed with isometric offsets using `walls_exterior_house_01_0/1/2/3`.
- Sacred Relic placed at the center square.

## Upgrades

- Sacred Relic context menu triggers upgrades.
- Upgrade consumes cores and expands floors/walls.

## Current Limitations

- Generation is client-side; MP sync is not implemented.
- Only NW and SE corner overlays exist in the selected wall tileset.

