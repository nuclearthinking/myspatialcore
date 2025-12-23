# Unified Effect System - Technical Design

## Architecture Overview

The system follows a three-layer architecture:

```
┌─────────────────────────────────────────────────────────────┐
│                    PROVIDERS (Sources)                       │
│  Calculate what effects to apply based on game state        │
└──────────────────┬──────────────────────────────────────────┘
                   │ register(effect, value, metadata)
                   ↓
┌─────────────────────────────────────────────────────────────┐
│                    REGISTRY (Combiner)                       │
│  Stores effects, applies stacking rules, provides queries   │
└──────────────────┬──────────────────────────────────────────┘
                   │ get(effectName) → combined value
                   ↓
┌─────────────────────────────────────────────────────────────┐
│               APPLICATORS (Implementation)                   │
│  Apply combined effects to character stats                  │
└─────────────────────────────────────────────────────────────┘
```

### Design Principles

1. **Separation of Concerns**: Sources don't know about application, applicators don't know about sources
2. **Lazy Evaluation**: Effects only recalculate when sources change (Body level up, Technique advance)
3. **Extensibility**: New providers register without modifying core system
4. **Type Safety**: Effect definitions validate names and types
5. **Debuggability**: Full effect breakdown available at runtime

---

## Core Components

### 1. EffectRegistry

**File**: `effects/EffectRegistry.lua`  
**Purpose**: Central storage and combination logic

**Key Features**:
- Per-player effect storage (multiplayer safe)
- 24 predefined effect types with validation
- Four stacking rules: additive, multiplicative, maximum, replace
- Effect breakdown for debugging
- Dirty flag for lazy recalculation

**Data Structure**:
```lua
playerRegistry[username] = {
    effects = {
        ["hunger_reduction"] = {
            total = 0.65,  -- Combined value
            sources = {
                {source = "BodyCultivation", value = 0.60, priority = 10, metadata = {level=5}},
                {source = "TechniqueSystem", value = 0.15, priority = 5, metadata = {technique="movement_economy"}},
            },
            stackingRule = "multiplicative",
            effectType = "reduction",
        },
    },
    isDirty = false,
    lastUpdated = timestamp,
}
```

**Stacking Rules**:
```lua
-- Additive: Sum values
0.40 + 0.25 = 0.65

-- Multiplicative: Diminishing returns
1 - (1 - 0.40) * (1 - 0.25) = 0.55

-- Maximum: Highest wins
max(0.40, 0.25) = 0.40

-- Replace: Last priority wins
priority 10 wins over priority 5
```

### 2. EffectProvider

**File**: `effects/EffectProvider.lua`  
**Purpose**: Base interface for effect sources

**Provider Contract**:
```lua
EffectProvider.create({
    sourceName = "UniqueIdentifier",  -- REQUIRED: Must be unique
    priority = 5,                      -- Default priority for effects (0-10)
    
    shouldApply = function(player)
        -- Return true if this provider has effects to register
        return player:getPerkLevel(Perks.Body) > 0
    end,
    
    calculateEffects = function(player)
        -- Return array of effect definitions
        return {
            {name = "hunger_reduction", value = 0.60, metadata = {level=5}, priority = 10},
            {name = "endurance_reduction", value = 0.65},
        }
    end,
})
```

**Registration**:
```lua
EffectSystem.registerProvider(MyProvider)
```

Provider effects are collected when:
- Player's state changes (level up, technique advance)
- Manual `markDirty()` call
- First query after state change

### 3. EffectApplicator

**File**: `effects/EffectApplicator.lua`  
**Purpose**: Apply combined effects to character stats

**Application Strategies**:

**Delta-Based Reductions** (hunger, thirst, fatigue, endurance):
```lua
-- Track previous value
tracking.hunger = 0.1234

-- Measure change
local currentHunger = stats:get(CharacterStat.HUNGER)  -- 0.1345
local change = currentHunger - tracking.hunger  -- 0.0111

-- Apply reduction
local reduction = EffectRegistry.get(player, "hunger_reduction", 0)  -- 0.60
local savedAmount = change * reduction  -- 0.00666
local newValue = tracking.hunger + (change - savedAmount)  -- 0.1278

-- Update stat
stats:set(CharacterStat.HUNGER, newValue)
tracking.hunger = newValue
```

**Regeneration** (health, stiffness, XP):
```lua
-- Flat amount per minute
local healthRegen = EffectRegistry.get(player, "health_regen", 0)  -- 0.2
if healthRegen > 0 then
    local currentHealth = bodyDamage:getHealth()
    bodyDamage:setHealth(math.min(100, currentHealth + healthRegen))
end
```

### 4. EffectHooks

**File**: `effects/EffectHooks.lua`  
**Purpose**: Event-based effects that can't run in EveryOneMinute

**Hooked Events**:

**OnWeaponSwing** - Attack endurance reduction
```lua
-- Estimate swing cost
local swingCost = BASE_SWING_COST + (weapon:getWeight() * WEIGHT_MULTIPLIER)

-- Apply reduction as immediate restoration
local reduction = EffectRegistry.get(player, "attack_endurance_reduction", 0)
local saved = swingCost * reduction
stats:set(CharacterStat.ENDURANCE, math.min(1.0, endurance + saved))
```

**AddXP** - Body XP multiplier
```lua
-- Guard against recursion
if isApplyingXPMultiplier then return end

-- Apply multiplier
local multiplier = EffectRegistry.get(player, "body_xp_multiplier", 1.0)
local bonus = xpAmount * (multiplier - 1.0)

isApplyingXPMultiplier = true
xp:AddXP(Perks.Body, bonus)
isApplyingXPMultiplier = false
```

**EveryTenMinutes** - Zombie perception (placeholder)
```lua
-- Only run if player has perception effects
if EffectRegistry.get(player, "zombie_attraction_reduction", 0) > 0 then
    applyZombiePerceptionEffects(player)
end
```

---

## Effect Flow Lifecycle

### Initialization (OnGameStart)
```
EffectSystemInit.lua:
├─ Register BodyCultivationProvider
├─ Register TechniqueEffectProvider
├─ Register EffectHooks event handlers
└─ Hook LevelPerk event for dirty marking
```

### Update Trigger (Body Level Up / Technique Advance)
```
1. Event fires (LevelPerk, TechniqueStageUp)
2. EffectSystem.markDirty(player)
3. Registry marks player as dirty
4. TechniqueEvents invalidates levelable cache
```

### Lazy Recalculation (Next Query)
```
EffectSystem.updatePlayer(player):
├─ Check if dirty flag set → YES
├─ Clear existing effects
├─ For each registered provider:
│  ├─ Check shouldApply(player)
│  ├─ Call calculateEffects(player)
│  └─ Register effects to registry
├─ Registry.recalculate(player)
│  └─ Combine sources using stacking rules
└─ Clear dirty flag
```

### Application (EveryOneMinute)
```
EffectSystem.applyEffects(player):
├─ updatePlayer(player)  ← Lazy recalc if dirty
├─ EffectApplicator.applyReductions(player)
│  ├─ Get combined values from registry
│  ├─ Apply delta-based reductions
│  └─ Update session statistics
└─ EffectApplicator.applyRegeneration(player)
   ├─ Apply flat regeneration amounts
   └─ Update session statistics
```

---

## Existing Providers

### BodyCultivationProvider

**File**: `BodyCultivationProvider.lua`

**Effects Registered** (Body Level 5):
```lua
{
    hunger_reduction: 0.60 (60%),
    thirst_reduction: 0.45 (45%),
    fatigue_reduction: 0.30 (30%),
    endurance_reduction: 0.65 (65%),
    stiffness_reduction: 0.59 (59%),
    stiffness_decay: 2.5,
    decay_protection: 0.65 (65%),
    fitness_xp: 0.40 (+ catchup multiplier),
    strength_xp: 0.40 (+ catchup multiplier),
}
```

**Trigger**: Body level changes

### TechniqueEffectProvider

**File**: `techniques/TechniqueEffectProvider.lua`

**Effects Registered** (Stage 3):
- **Movement Economy**: `endurance_reduction` (15%), `stiffness_reduction` (12%), `attack_endurance_reduction` (18%)
- **Energy Stabilization**: `zombie_attraction_reduction` (42%), `body_xp_multiplier` (0.91)
- **Camel's Hump**: `metabolism_efficiency` (0.8), `hp_regen_enabled` (true), `weight_conversion` (true at stage 3+)

**Trigger**: Technique stage changes

---

## Performance Optimizations

### 1. Lazy Evaluation
Effects only recalculate when marked dirty (level up, technique advance)

**Before**: Recalculate 60 times per hour  
**After**: Recalculate 1-2 times per hour (when state changes)  
**Savings**: ~98% reduction in calculations

### 2. Cached Debug Mode
```lua
local isDebug = getDebug()  -- Module-level, evaluated once
```

### 3. Early Exits
```lua
if techData.stage >= maxStage then
    shouldProcess = false  -- Skip all XP calculation
end
```

### 4. Per-Player Isolation
Separate data structures per player prevent cross-contamination in multiplayer

### 5. Event-Based Application
Only hook events when effects exist:
```lua
if EffectRegistry.get(player, "zombie_attraction_reduction", 0) > 0 then
    -- Process zombie perception
end
```

---

## Thread Safety & Multiplayer

### Player Isolation
```lua
local function getPlayerKey(player)
    -- Use online ID if available (multiplayer)
    local onlineID = player:getOnlineID()
    if onlineID and onlineID >= 0 then
        return "player_" .. tostring(onlineID)
    end
    
    -- Fallback to username (single player)
    return "player_" .. player:getUsername()
end
```

### Data Structures
- `playerRegistry` - Per-player effect storage
- `playerTracking` - Per-player stat tracking for deltas
- `sessionStats` - Per-player cumulative statistics

### Cleanup
```lua
Events.OnLoad.Add(function()
    playerRegistry = {}  -- Clear all on game load
    sessionStats = {}
end)

Events.OnPlayerDeath.Add(function(player)
    local key = getPlayerKey(player)
    playerRegistry[key] = nil  -- Cleanup on death
    sessionStats[key] = nil
end)
```

---

## Error Handling

### Validation
```lua
-- Effect name validation
if not getEffectDefinition(effectName) then
    print("[EffectRegistry] ERROR: Unknown effect '" .. effectName .. "'")
    print("[EffectRegistry] Valid effects: ...")
    return false
end

// Value validation
if type(value) ~= "number" or value ~= value or value == math.huge then
    print("[EffectRegistry] ERROR: Invalid value")
    return false
end
```

### Safe Calls
```lua
-- Registry access with defaults
local value = EffectRegistry.get(player, "hunger_reduction", 0)

-- Provider registration with pcall
local success, EffectSystem = pcall(require, "effects/EffectSystem")
if success and EffectSystem then
    EffectSystem.markDirty(player)
end
```

### Recursion Guards
```lua
local isApplyingXPMultiplier = false

function onAddXP(...)
    if isApplyingXPMultiplier then return end
    isApplyingXPMultiplier = true
    -- ... do work ...
    isApplyingXPMultiplier = false
end
```

---

## File Structure

```
effects/
├── EffectRegistry.lua       - Core storage and combination
├── EffectProvider.lua        - Base provider interface
├── EffectApplicator.lua      - Stat application logic
├── EffectSystem.lua          - Main orchestrator
└── EffectHooks.lua           - Event-based effects

BodyCultivationProvider.lua  - Body effects
EffectSystemInit.lua          - System initialization

techniques/
└── TechniqueEffectProvider.lua - Technique effects

utils/
└── LuaCompat.lua             - Kahlua compatibility helpers
```

---

## Code Quality

### Lua Annotations
```lua
---@param player IsoPlayer
---@param effectName string
---@return number value
function EffectRegistry.get(player, effectName, defaultValue)
```

### Constants
```lua
-- At module level
local BASE_SWING_COST = 0.5
local WEIGHT_COST_MULTIPLIER = 0.1
local MIN_XP_MULTIPLIER = 0.0
local MAX_XP_MULTIPLIER = 2.0
```

### Documentation
All major functions have header comments explaining purpose, parameters, and return values

---

## Testing Recommendations

### Unit Testing (Manual)
```lua
-- Test provider registration
EffectDebug.providers()

-- Test effect calculation
EffectDebug.breakdown("hunger_reduction")

-- Test stacking
-- 1. Level Body to 5 → Check values
// 2. Learn Movement Economy → Check stacking
// 3. Level technique → Check updates

-- Test performance
-- Max all techniques → Verify zero XP processing
```

### Integration Testing
- Save/load with various effect states
- Multiplayer with different player levels
- Rapid level-up scenarios
- Edge cases (Body 0, Techniques unlearned)

---

## Future Enhancements

### Planned Features
- Equipment effect provider
- Spirit cultivation provider
- Temporary buff/debuff system
- Effect duration support
- Effect conditions (time-based, location-based)
- Network synchronization for multiplayer

### API Expansion
- Effect listeners (notify when effect changes)
- Effect groups (enable/disable whole categories)
- Effect priority overrides
- Custom stacking rules per effect

---

*For debugging tools and commands, see [DEBUG.md](./DEBUG.md)*

