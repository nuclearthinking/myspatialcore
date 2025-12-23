# Body Cultivation - System Design

## Core Mechanics

### XP Acquisition

**Source**: Melee zombie kills only

**Base XP**: 10 XP per kill (modified by exercise multiplier)

**Detection**: System validates that the killing weapon was melee (not ranged, not vehicle)

### Dynamic XP Scaling

Zombie HP varies—some are standard (1.5 HP), others are tougher (up to 300+ HP). XP scales proportionally:

```
XP = BASE_XP × (zombieHP / standardHP)
```

A 300 HP zombie awards roughly 20x more XP than a standard zombie.

### Progression Timeline

| Level | Total XP | Total Kills | Days (20 kills/day) |
|-------|----------|-------------|---------------------|
| 1 | 200 | 20 | 1 |
| 3 | 1,200 | 120 | 6 |
| 5 | 3,700 | 370 | 18 |
| 7 | 10,200 | 1,020 | 51 |
| 10 | 40,200 | 4,020 | 201 |

With exercise multipliers, progression can be 30-60% faster.

---

## Effect Implementation

### Hunger/Thirst Reduction

**Approach**: Interval compensation

Rather than modifying metabolism directly (not exposed in API), the system periodically reduces hunger/thirst gain:

1. Every minute, check current hunger/thirst levels
2. Calculate how much they've increased since last check
3. Reduce the increase by cultivation percentage
4. Apply corrected values

**Result**: Functionally identical to slower metabolism.

### Health Regeneration

**Approach**: Direct health modification

At higher levels, health slowly increases over time:
- Level 7-9: +0.01 HP per minute (during calorie surplus)
- Level 10: +0.02 HP per minute

Regeneration requires the "Efficient Absorption" technique for full effect.

### Endurance Enhancement

**Approach**: Direct stat modification

Endurance drain is reduced and recovery is boosted:
- Scale from 10% reduction at level 1 to 100% boost at level 10
- Applied through stat manipulation each update cycle

### Muscle Strain Reduction

**Approach**: Pain and stiffness reduction on body parts

The system reduces pain and stiffness on muscle groups (arms, legs, torso):
- Scales with cultivation level
- Simulates reduced muscle fatigue

---

## Event Hooks

### Primary Hook
`OnZombieDead` - Triggers when any zombie dies

**Validation checks**:
1. Killer exists and is alive
2. Killer is not in vehicle
3. Killing weapon was melee (not ranged)

### Effect Application
`EveryOneMinute` - Applies passive cultivation effects

**Operations**:
1. Calculate player's Body level
2. Apply hunger/thirst compensation
3. Apply health regeneration (if applicable)
4. Apply endurance modifications

---

## Balance Considerations

### Early Game (Levels 1-3)
- Quick progression (1-6 days)
- Noticeable but not game-changing effects
- Hooks players into the system

### Mid Game (Levels 4-7)
- Steady progression (weeks)
- Meaningful survival advantages
- Enables longer expeditions

### Late Game (Levels 8-10)
- Long-term commitment (months)
- Significant power but not invincibility
- Aspirational goals for dedicated players

### Self-Balancing Elements

1. **Zombie Attraction**: Higher cultivation increases zombie aggression (counterbalance)
2. **Time Investment**: Level 10 requires ~200 days of regular play
3. **Mortality**: Bites still kill regardless of cultivation level

---

## Fitness & Strength Cultivation

### Passive XP System

Body Cultivation grants continuous passive XP to Fitness and Strength:

**XP Formula** (per minute):
```
Level 1-3:  0.10 + (level - 1) × 0.05
Level 4-6:  0.20 + (level - 3) × 0.10
Level 7-9:  0.50 + (level - 6) × 0.15
Level 10:   1.0 XP/min
```

### Catchup Multiplier

When Fitness or Strength is below Body level, bonus XP multiplier applies:

```
gap = bodyLevel - statLevel
multiplier = min(gap × 2, 10)

Total XP = baseXP + (baseXP × multiplier)
```

This allows weak characters to catch up rapidly to match their cultivation.

### Decay Protection

Prevents Fitness/Strength from dropping below Body level:

```
Level 1-3:  level × 15%     → 15%, 30%, 45%
Level 4-6:  45% + (level-3) × 10%  → 55%, 65%, 75%
Level 7-9:  75% + (level-6) × 5%   → 80%, 85%, 90%
Level 10:   100% (complete protection)
```

When decay is detected, XP is automatically injected to restore the level.

---

## Integration Points

### Exercise Enhancement
- Fitness exercises grant temporary XP multipliers (1.5x - 3.0x)
- Creates preparation → combat gameplay loop

### Technique System
- "Efficient Absorption" enhances calorie → healing conversion
- Techniques modify how cultivation effects work

### Zombie Core Drops
- Zombies also drop physical cores (30% chance)
- Cores used for Spatial Sack crafting (separate from XP)

---

## Technical Notes

### Performance
- XP calculation happens once per zombie kill (minimal impact)
- Effect application is throttled to once per minute
- No per-frame overhead

### Persistence
- Body level stored in vanilla perk system
- Automatically saves/loads with character

### Multiplayer
- XP awarded to killing player only
- Effects apply per-player independently
- ModData syncs automatically

