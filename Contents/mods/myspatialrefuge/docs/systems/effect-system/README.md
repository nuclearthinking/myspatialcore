# Unified Effect System

## Concept

The **Unified Effect System** is the foundational architecture that manages all character enhancements in My Spatial Refuge. It provides a clean, extensible framework for combining effects from multiple sources (Body Cultivation, Techniques, Equipment, Spirit, etc.) without code duplication or conflicts.

Think of it as the "nervous system" of the mod—it coordinates how different power sources interact and ensures they work together harmoniously.

## Philosophy

**"Power comes from many sources, but flows through one channel."**

Before this system, each cultivation path had its own effect application logic, leading to:
- Duplicated code for hunger reduction, endurance bonuses, etc.
- Conflicts when effects overlapped
- Difficulty debugging which system was affecting what
- No clear way to see total combined bonuses

The Unified Effect System solves this by separating **what** you gain power from (Body, Techniques, Equipment) from **how** that power affects your character.

## How It Works (Player Perspective)

### Effect Sources

Your character's enhancements come from multiple sources:

1. **Body Cultivation** (Base Power)
   - Hunger/thirst reduction: 15-95%
   - Endurance drain reduction: 25-85%
   - Health regeneration (level 7+)
   - Passive Fitness/Strength XP

2. **Techniques** (Specialized Skills)
   - **Movement Economy**: Extra endurance efficiency (5-25%)
   - **Energy Stabilization**: Reduced zombie attraction (14-70%)
   - **Camel's Hump**: Fat reserve metabolism for emergency healing

3. **Future Sources**
   - Equipment enchantments
   - Spirit Cultivation bonuses
   - Temporary buffs/debuffs
   - Environmental effects

### Effect Stacking

When multiple sources provide the same effect, they combine using **multiplicative stacking** (diminishing returns):

**Example**: Endurance Reduction
- Body Level 5: 65% reduction
- Movement Economy Stage 3: 15% additional reduction
- **Combined**: 71.75% (not 80%!)

Formula: `1 - (1 - 0.65) * (1 - 0.15) = 0.7175`

This prevents reaching 100% reduction easily, keeping gameplay balanced.

### Viewing Your Effects

**In-Game Debug Window**:
```lua
ShowEffectDebug()
```

Shows:
- All active effects with values
- Which sources contribute to each effect
- Stacking calculations
- Provider status (active/inactive)

**Console Commands**:
```lua
EffectDebug.status()                        -- Quick overview
EffectDebug.breakdown("endurance_reduction") -- Detailed breakdown
EffectDebug.providers()                      -- List all sources
```

## Effect Categories

### 🔽 **Reduction Effects** (0-100%)
Reduce stat consumption or drain:
- `hunger_reduction` - Food lasts longer
- `thirst_reduction` - Water lasts longer  
- `fatigue_reduction` - Tire slower
- `endurance_reduction` - Stamina drains slower
- `stiffness_reduction` - Less muscle strain
- `attack_endurance_reduction` - Combat costs less stamina

### ⬆️ **Regeneration Effects** (flat per minute)
Restore stats passively:
- `health_regen` - HP restoration per minute
- `stiffness_decay` - Muscle recovery boost
- `fitness_xp` - Passive Fitness training
- `strength_xp` - Passive Strength training

### ✖️ **Multiplier Effects** (percentage modifiers)
Scale other values:
- `fitness_xp_multiplier` - Modify Fitness XP gain
- `strength_xp_multiplier` - Modify Strength XP gain
- `body_xp_multiplier` - Modify Body XP gain (penalties)
- `metabolism_efficiency` - Healing power modifier
- `healing_power_multiplier` - General healing boost

### 🎯 **Zombie Perception** (0-100% reduction)
Reduce zombie awareness:
- `zombie_attraction_reduction` - Smaller detection radius
- `zombie_sight_reduction` - Harder to spot visually
- `zombie_hearing_reduction` - Quieter sounds

### 🔘 **Boolean Flags** (on/off)
Enable special features:
- `weight_conversion` - Burn body fat for healing
- `hp_regen_enabled` - Unlock HP regeneration

## Gameplay Impact

### Early Game (Body 1-3)
- Base reductions from Body Cultivation (15-40%)
- No techniques yet
- Effects are subtle but helpful
- Food/water last noticeably longer

### Mid Game (Body 4-6 + Techniques)
- Stacking becomes powerful (50-70% reductions)
- Techniques add specialized bonuses
- Extended expeditions become viable
- Combat efficiency improves significantly

### Late Game (Body 7-10 + Multiple Techniques)
- Near-total efficiency (80-95% reductions)
- Multiple passive XP sources
- HP regeneration active
- Weight conversion unlocked
- Focus shifts to perfecting techniques

## Synergies

### Body + Movement Economy
```
Body 5: 65% endurance reduction
+ Movement Economy Stage 3: 15% bonus
= 71.75% total endurance reduction
+ 15% attack endurance reduction (combat-specific)
```

Result: Fight longer, tire slower, recover faster

### Body + Energy Stabilization
```
Body 6+: High zombie attraction (high life energy)
+ Energy Stabilization Stage 5: 70% attraction reduction
= Nearly invisible to zombies
- BUT: 15% slower Body XP gain (cultivation penalty)
```

Result: Stealth playstyle, safer looting, slower progression

### Body + Camel's Hump
```
Body 2+: Metabolism healing unlocked
+ Camel's Hump Stage 3: Weight conversion (DANGEROUS at low mastery!)
= Survive wounds by burning body fat
+ HP regen at Stage 2+
WARNING: Novices can burn to skeletal state! Masters have control.
```

Result: Emergency survival healing, but risk malnutrition without wisdom

## Performance

The system is designed for zero gameplay impact:
- Effects update only when sources change (lazy evaluation)
- Cached calculations (< 0.5ms per update)
- Event-based application (no constant polling)
- Automatic optimization for maxed techniques

**Total Overhead**: < 5ms per minute (0.3% of a frame)

## Future Expandability

The system is designed to easily add:
- **Equipment Provider**: Enchanted gear effects
- **Spirit Provider**: Mental cultivation bonuses
- **Buff System**: Temporary power-ups
- **Environmental Effects**: Location-based modifiers
- **Perk Integration**: Trait and skill synergies

Adding a new provider is as simple as:
```lua
local MyProvider = EffectProvider.create({
    sourceName = "MySystem",
    shouldApply = function(player) ... end,
    calculateEffects = function(player) ... end,
})
EffectSystem.registerProvider(MyProvider)
```

---

## Technical Details

For implementation details, see:
- [DESIGN.md](./DESIGN.md) - Architecture and code structure
- [DEBUG.md](./DEBUG.md) - Debugging tools and commands

---

*The Unified Effect System is the backbone of character progression in My Spatial Refuge. It ensures all power sources work together seamlessly while remaining extensible for future content.*

