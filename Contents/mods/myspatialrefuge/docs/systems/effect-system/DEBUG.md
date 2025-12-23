# Effect System - Debugging Guide

## Console Commands

All debug commands are available through the `EffectDebug` global object.

### Quick Status

```lua
EffectDebug.status()
```

**Output**:
```
========================================
=== [EffectSystem] Debug Info ===
========================================
=== [EffectRegistry] PhilOates ===
  hunger_reduction: 0.6000 (multiplicative)
    - BodyCultivation: 0.6000 (priority: 10) [level=5]
  endurance_reduction: 0.7175 (multiplicative)
    - BodyCultivation: 0.6500 (priority: 10) [level=5]
    - TechniqueSystem: 0.1500 (priority: 5) [technique=movement_economy]
  ...
==========================================
=== [EffectApplicator] Session Stats ===
  Effects Applied: 45 times
  --- Active Effects ---
    hunger_reduction: 60.0%
    endurance_reduction: 71.8%
  --- Cumulative Benefits ---
    Hunger reduced: 0.254321
    Endurance drain reduced: 1.876543
==========================================
=== Registered Providers ===
  1. BodyCultivation (active: true, priority: 10)
  2. TechniqueSystem (active: true, priority: 5)
========================================
```

---

### Effect Breakdown

```lua
EffectDebug.breakdown("hunger_reduction")
```

**Output**:
```
=== Effect Breakdown: hunger_reduction ===
Total: 0.6000 (multiplicative)
Sources:
  - BodyCultivation: 0.6000 (priority: 10) [level=5]
```

**With Stacking**:
```lua
EffectDebug.breakdown("endurance_reduction")
```

**Output**:
```
=== Effect Breakdown: endurance_reduction ===
Total: 0.7175 (multiplicative)
Sources:
  - BodyCultivation: 0.6500 (priority: 10) [level=5]
  - TechniqueSystem: 0.1500 (priority: 5) [technique=movement_economy, stage=3]
```

**Calculation**:
```
1 - (1 - 0.65) * (1 - 0.15)
= 1 - (0.35 * 0.85)
= 1 - 0.2975
= 0.7175
```

---

### List Providers

```lua
EffectDebug.providers()
```

**Output**:
```
=== Registered Effect Providers ===
1. BodyCultivation (priority: 10)
2. TechniqueSystem (priority: 5)
```

---

### Force Update

```lua
EffectDebug.update()
```

Forces immediate recalculation of all effects. Useful after manually changing player state with debug commands.

**Output**:
```
[EffectDebug] Force updated effects for PhilOates
```

---

### Reset Effects

```lua
EffectDebug.reset()
```

Clears all effects and session statistics for the player. Use for testing fresh state.

**Output**:
```
[EffectSystem] Reset effects for PhilOates
```

---

### Help

```lua
EffectDebug.help()
```

**Output**:
```
=== EffectDebug Console Commands ===
EffectDebug.status()              - Show detailed effect info
EffectDebug.update()              - Force update effects
EffectDebug.reset()               - Reset all effects
EffectDebug.breakdown('effect')   - Show effect source breakdown
EffectDebug.providers()           - List all providers
===================================
```

---

## Debug Window

### Open/Close

```lua
ShowEffectDebug()   -- Open
HideEffectDebug()   -- Close
ToggleEffectDebug() -- Toggle
```

### Window Contents

```
╔════════════════════════════════════════════════════════════╗
║ Effect System Debug                    [Refresh] [Close]   ║
╠════════════════════════════════════════════════════════════╣
║ Player: PhilOates                                          ║
║ Body Level: 5                                              ║
║ Fitness: 5 | Strength: 5                                   ║
║                                                            ║
║ Active Effects: 9                                          ║
║                                                            ║
║ > hunger_reduction: 60.0% (multiplicative)                 ║
║     - BodyCultivation: 60.0% (priority: 10) [level=5]     ║
║                                                            ║
║ > endurance_reduction: 71.8% (multiplicative)              ║
║     - BodyCultivation: 65.0% (priority: 10) [level=5]     ║
║     - TechniqueSystem: 15.0% (priority: 5) [stage=3]      ║
║                                                            ║
║ =========================                                  ║
║ Registered Providers:                                      ║
║   1. BodyCultivation (priority: 10) - ACTIVE              ║
║   2. TechniqueSystem (priority: 5) - ACTIVE               ║
╚════════════════════════════════════════════════════════════╝
```

**Features**:
- Auto-refreshes every 1 second
- Manual refresh button
- Shows all active effects with values
- Source breakdown for each effect
- Provider status (active/inactive)
- Stacking rule display

---

## Common Debugging Scenarios

### Effects Not Applying

**Symptom**: Effects show in debug but stats don't change

**Debug Steps**:
1. Check provider is active:
   ```lua
   EffectDebug.providers()
   ```
   Look for "ACTIVE" status

2. Check effect is registered:
   ```lua
   EffectDebug.breakdown("hunger_reduction")
   ```
   Should show non-zero value

3. Force update:
   ```lua
   EffectDebug.update()
   ```
   
4. Wait one minute for application
   Effects apply in EveryOneMinute event

5. Check debug output:
   ```lua
   setDebug(true)  -- Enable verbose logging
   ```
   Look for `[EffectApplicator]` messages

---

### Effects Wrong Value

**Symptom**: Effect value doesn't match expectations

**Debug Steps**:
1. Check stacking calculation:
   ```lua
   EffectDebug.breakdown("endurance_reduction")
   ```
   
2. Verify stacking rule:
   - Multiplicative: `1 - (1-a) * (1-b)`
   - Additive: `a + b`
   - Maximum: `max(a, b)`

3. Check source priorities:
   Higher priority doesn't always mean higher value—it affects order of evaluation for REPLACE rule only

4. Verify effect type matches usage:
   - Reductions: 0.0 to 1.0 (percentage)
   - Regeneration: Flat amounts per minute
   - Multipliers: Usually around 1.0 (can be < 1.0 for penalties)

---

### Provider Not Registering Effects

**Symptom**: Provider shows as active but no effects

**Debug Steps**:
1. Check `shouldApply()` returns true:
   ```lua
   EffectDebug.providers()  -- Look for ACTIVE
   ```

2. Check `calculateEffects()` returns effects:
   Enable debug mode and look for provider log messages

3. Verify effect names are valid:
   ```lua
   -- Valid: "hunger_reduction"
   -- Invalid: "hunger" (will be rejected)
   ```

4. Force update after changing player state:
   ```lua
   EffectDebug.update()
   ```

---

### Technique Not Providing Effects

**Symptom**: Learned technique but no bonus effects

**Debug Steps**:
1. Check technique stage:
   ```lua
   TechDebug.status()  -- Must be stage 1+ 
   ```

2. Check TechniqueEffectProvider mapping:
   Look in `TechniqueEffectProvider.lua` for technique ID

3. Verify technique effects defined:
   ```lua
   -- In technique definition
   getEffects = function(stage)
       return { enduranceReduction = 0.15 }
   end
   ```

4. Check effect name mapping:
   `enduranceReduction` → `endurance_reduction` (camelCase → snake_case)

---

### Performance Issues

**Symptom**: Game stutters when effects update

**Debug Steps**:
1. Check update frequency:
   ```lua
   EffectDebug.status()
   ```
   Look for "lastUpdated" timestamp

2. Check provider count:
   ```lua
   EffectDebug.providers()
   ```
   Too many providers (>10) may need optimization

3. Check technique max level optimization:
   ```lua
   -- All techniques maxed?
   TechDebug.status()
   ```
   Should see zero XP processing in logs

4. Enable performance logging:
   ```lua
   setDebug(true)
   ```
   Look for timing messages

---

## Debug Configuration

### Enable Debug Mode

```lua
setDebug(true)   -- Enable verbose logging
setDebug(false)  -- Disable (default for production)
```

**What Changes**:
- Detailed `[EffectRegistry]` messages
- `[EffectApplicator]` stat change logs
- `[EffectSystem]` update messages
- `[TechniqueManager]` XP gain logs
- `[TechniqueEvents]` activity tracking logs

### Recommended Debug Workflow

```lua
-- 1. Enable debug mode
setDebug(true)

-- 2. Check current state
EffectDebug.status()

-- 3. Trigger state change
debugLevelPerk Body 6  -- Level up Body

-- 4. Check update triggered
-- Should see "[EffectSystem] Updating effects..." in logs

-- 5. Verify new effects
EffectDebug.breakdown("hunger_reduction")

-- 6. Disable debug mode
setDebug(false)
```

---

## Testing Helpers

### Body Level Testing

```lua
-- Set Body level
debugLevelPerk Body 5

-- Force effect update
EffectDebug.update()

-- Check results
EffectDebug.status()
```

### Technique Testing

```lua
-- Learn technique
TechDebug.learn("movement_economy")

-- Set stage
TechDebug.setStage("movement_economy", 3)

-- Check effects
EffectDebug.breakdown("endurance_reduction")
```

### Combination Testing

```lua
-- Body + Technique
debugLevelPerk Body 5
TechDebug.learn("movement_economy")
TechDebug.setStage("movement_economy", 3)

-- Check stacking
EffectDebug.breakdown("endurance_reduction")
-- Should show both sources
```

---

## Log Messages Reference

### Normal Operation

```
[EffectRegistry] Effect registry system initialized
[EffectProvider] Effect provider interface initialized
[EffectApplicator] Effect applicator initialized
[EffectSystem] Effect system initialized
[EffectSystemInit] Registered Body Cultivation provider
[EffectSystemInit] Registered Technique provider
[EffectSystemInit] Unified effect system initialized successfully
[EffectHooks] Effect event hooks registered
```

### Effect Updates

```
[EffectSystem] Updating effects for PhilOates (2 providers)
[EffectRegistry] PhilOates: Recalculated 9 effects
[EffectSystem] Effects updated for PhilOates
```

### Effect Application

```
[EffectApplicator] Thirst: 0.0234 -> 0.0245 (saved: 0.000165, 45.0%)
[EffectApplicator] Fatigue: 0.4288 -> 0.4293 (saved: 0.000221, 30.0%)
[EffectApplicator] Endurance: 0.8765 -> 0.8769 (saved drain: 0.001234, 65.0%)
[EffectApplicator] Health regen: 98.20 -> 98.40 (+0.20)
```

### Errors

```
[EffectRegistry] ERROR: Unknown effect type 'invalid_effect' from source 'MyProvider'
[EffectRegistry] ERROR: Effect value must be a number, got string
[EffectRegistry] ERROR: Effect value is NaN or Infinity
[EffectApplicator] ERROR: Failed to get player registry
```

---

## Known Limitations

### Attack Endurance Reduction
- **Issue**: Cost is estimated, not measured
- **Workaround**: Tuning BASE_SWING_COST constant
- **Status**: Functional approximation

### Zombie Perception
- **Issue**: Placeholder implementation
- **Workaround**: Registers effect but doesn't fully apply
- **Status**: Needs PZ API research

### Multiplayer Sync
- **Issue**: Effects are client-side only
- **Workaround**: Each client calculates independently
- **Status**: Works but no server authority

---

## Troubleshooting Checklist

- [ ] Mod loaded without errors?
- [ ] Debug commands available? (`EffectDebug.help()`)
- [ ] Providers registered? (`EffectDebug.providers()`)
- [ ] Effects showing? (`EffectDebug.status()`)
- [ ] Values correct? (`EffectDebug.breakdown(...)`)
- [ ] Updates triggering? (Level up Body → check logs)
- [ ] Application working? (Wait 1 minute → check stats)

If all checks pass but still broken: Check console for Lua errors!

---

*For system architecture, see [DESIGN.md](./DESIGN.md)*

