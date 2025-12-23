# Technique System - Debug Commands

Debug commands for testing and development of the cultivation technique system.
All commands are accessible from the **Lua Debug Console** (press `~` in debug mode).

## Quick Reference

| Command | Description |
|---------|-------------|
| `TechDebug.help()` | Show all available commands |
| `TechDebug.status()` | Show current technique status |
| `TechDebug.list()` | List all registered technique IDs |

---

## Available Techniques

Use these IDs with debug commands:

| Technique ID | Display Name | Description |
|--------------|--------------|-------------|
| `efficient_absorption` | Efficient Energy Absorption | Converts calories into healing and recovery |
| `movement_economy` | Movement Economy | Reduces endurance drain and muscle stiffness |
| `energy_stabilization` | Energy Stabilization | Stabilizes energy levels and reduces zombie attraction |

---

## Stage System

Techniques use a 5-stage progression system:

| Stage | Name | Effect Multiplier |
|-------|------|-------------------|
| 1 | Initiate | 0.2x (20%) |
| 2 | Adept | 0.4x (40%) |
| 3 | Accomplished | 0.6x (60%) |
| 4 | Perfected | 0.8x (80%) |
| 5 | Transcendent | 1.0x (100%) |

---

## Debug Commands

### Information Commands

#### `TechDebug.status()`
Print the current status of all learned techniques for the local player.

```lua
TechDebug.status()
```

Output:
```
=== [TechniqueManager] Player Technique Status ===
Player: admin
  movement_economy: Adept (2/5) - XP: 45.0/180.0
  efficient_absorption: Initiate (1/5) - XP: 12.0/100.0
================================================
```

---

#### `TechDebug.list()`
List all registered technique IDs in the system.

```lua
TechDebug.list()
```

Output:
```
[TechDebug] Registered techniques:
  - efficient_absorption (Efficient Energy Absorption)
  - movement_economy (Movement Economy)
  - energy_stabilization (Energy Stabilization)
```

---

### Learning Commands

#### `TechDebug.learn(techniqueId)`
Force-learn a specific technique at Stage 1 (Initiate), bypassing all requirements.

```lua
TechDebug.learn("movement_economy")
TechDebug.learn("efficient_absorption")
TechDebug.learn("energy_stabilization")
```

---

#### `TechDebug.learnAll()`
Learn ALL registered techniques at Stage 1.

```lua
TechDebug.learnAll()
```

---

### Stage Manipulation

#### `TechDebug.setStage(techniqueId, stage)`
Set a technique to a specific stage (1-5).

```lua
TechDebug.setStage("movement_economy", 3)    -- Set to Accomplished
TechDebug.setStage("movement_economy", 5)    -- Set to Transcendent
```

Stage values:
- `1` = Initiate
- `2` = Adept
- `3` = Accomplished
- `4` = Perfected
- `5` = Transcendent

---

#### `TechDebug.advance(techniqueId)`
Advance a technique to the next stage.

```lua
TechDebug.advance("movement_economy")
```

If already at Transcendent (stage 5), prints an error message.

---

#### `TechDebug.maxAll()`
Set ALL techniques to Stage 5 (Transcendent) immediately.

```lua
TechDebug.maxAll()
```

---

### Reset Commands

#### `TechDebug.reset(techniqueId)`
Reset a specific technique to Stage 1 (Initiate) with 0 XP.

```lua
TechDebug.reset("movement_economy")
```

---

#### `TechDebug.resetAll()`
Reset ALL learned techniques to Stage 1 with 0 XP.

```lua
TechDebug.resetAll()
```

---

### Forget Commands

#### `TechDebug.forget(techniqueId)`
Completely remove (unlearn) a specific technique from the player.

```lua
TechDebug.forget("movement_economy")
```

---

#### `TechDebug.forgetAll()`
Completely remove ALL techniques from the player.

```lua
TechDebug.forgetAll()
```

---

## Example Workflows

### Testing a New Technique
```lua
-- 1. Learn the technique
TechDebug.learn("movement_economy")

-- 2. Check status
TechDebug.status()

-- 3. Advance through stages to test effects
TechDebug.setStage("movement_economy", 3)

-- 4. Test at max stage
TechDebug.setStage("movement_economy", 5)

-- 5. Reset for more testing
TechDebug.reset("movement_economy")
```

### Quick Full Test Setup
```lua
-- Learn and max everything instantly
TechDebug.maxAll()

-- Check what we have
TechDebug.status()
```

### Clean Slate
```lua
-- Remove all techniques and start fresh
TechDebug.forgetAll()
TechDebug.status()
```

---

## Notes

- All debug commands show feedback both in the console and as floating text above the player
- Debug commands only work for the local player (player 1)
- These commands bypass all normal requirements (manuscripts, cultivation levels, etc.)
- XP is reset to 0 when using `setStage`, `reset`, or `resetAll`
- The `TechDebug` global is only available when the mod is loaded

