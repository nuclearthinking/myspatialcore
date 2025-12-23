# Cultivation Techniques - System Design

## Architecture Overview

The Technique System uses a modular, registry-based architecture:

```
TechniqueSystem (Entry Point)
├── TechniqueRegistry (Definitions + Stage System)
├── TechniqueManager (Player State)
└── TechniqueEvents (Game Hooks)
```

### Component Responsibilities

**Registry**: Stores technique definitions, validates requirements, manages stage progression

**Manager**: Tracks per-player technique data (learned, stage, XP), handles advancement logic

**Events**: Hooks game events, dispatches to techniques for XP gain

---

## Stage Progression System

The technique system uses a five-stage mastery progression inspired by traditional Chinese cultivation novels (wuxia/xianxia). The in-game interface uses English adaptations for accessibility.

### The Five Stages

| Stage | In-Game Name | Wuxia Origin | Description |
|-------|--------------|--------------|-------------|
| 1 | Initiate | 入门 (Rùmén) | Basic understanding. Technique barely manifests, works unreliably. |
| 2 | Adept | 小成 (Xiǎo Chéng) | Improved understanding. Effect appears more often, but depends on conditions. |
| 3 | Accomplished | 大成 (Dà Chéng) | Confident mastery. Technique works reliably in most situations. |
| 4 | Perfected | 圆满 (Yuánmǎn) | Near ideal mastery. Almost full control, minimal side effects. |
| 5 | Transcendent | 极境 (Jí Jìng) | Perfect mastery. Complete unity of body and technique. |

### Design Philosophy

**Understanding Over Power**: Each stage represents deepening comprehension, not just raw strength. A technique at Accomplished isn't just "stronger"—the practitioner truly understands it.

**Meaningful Milestones**: Five stages mean each advancement is significant and memorable. No grinding through ten near-identical levels.

**Wuxia Inspiration**: The underlying philosophy draws from traditional cultivation concepts while presenting them in accessible English terms.

**Narrative Potential**: Stage names appear in messages without numbers:
> "Movement Economy → Accomplished"

### Balance Considerations

**Transcendent should be:**
- Rare to achieve
- Requires significant time investment
- Possibly unattainable for all techniques in single playthrough
- Creates long-term goal and sense of accomplishment

---

## Technique Definition Structure

Each technique is defined with:

```lua
{
    id = "unique_identifier",
    name = "Display Name",
    description = "Tooltip text",
    
    requirements = {
        minBodyLevel = 0,  -- Minimum Body cultivation level
        item = "ManuscriptType",  -- Required manuscript item
    },
    
    maxStage = 5,  -- Maximum stage (default 5, use STAGES constants)
    
    -- XP required to advance from each stage
    xpPerStage = function(stage)
        -- Stage 1→2: easier, Stage 4→5: much harder
        return baseXP * stageMultiplier[stage]
    end,
    
    levelingConditions = {
        {
            event = "GameEventName",
            condition = function(player, data) return true end,
            xpGain = function(player, data, stage) return amount end,
        },
    },
    
    -- Effects scale with stage (1-5)
    getEffects = function(stage)
        return {
            effectName = value,
        }
    end,
    
    onLearn = function(player) end,
    onStageUp = function(player, newStage) end,
}
```

---

## Stage Constants

The registry provides stage constants for consistency:

```lua
TechniqueRegistry.STAGES = {
    ENTRY = 1,              -- Initiate
    SMALL_ACHIEVEMENT = 2,  -- Adept
    GREAT_ACHIEVEMENT = 3,  -- Accomplished
    COMPLETENESS = 4,       -- Perfected
    ULTIMATE = 5,           -- Transcendent
}

TechniqueRegistry.STAGE_DATA = {
    [1] = { name = "Initiate", description = "Basic understanding...", effectMultiplier = 0.20 },
    [2] = { name = "Adept", description = "Improved comprehension...", effectMultiplier = 0.40 },
    [3] = { name = "Accomplished", description = "Confident mastery...", effectMultiplier = 0.60 },
    [4] = { name = "Perfected", description = "Near-perfect control...", effectMultiplier = 0.80 },
    [5] = { name = "Transcendent", description = "Perfect mastery...", effectMultiplier = 1.00 },
}
```

---

## Event System

### Standard Events
Direct game events that trigger immediately:
- `OnZombieKill` - Player killed a zombie
- `OnPlayerWakeUp` - Player finished sleeping
- `OnPlayerEat` - Player consumed food

### Calculated Events
Custom events evaluated every game minute:
- `OnCalorieSurplus` - Calories above threshold
- `OnSustainedActivity` - Physically active with endurance > 90%
- `OnZombieProximity` - Many zombies nearby
- `OnHealthRecovery` - Health below max
- `OnMuscleStiffness` - Body parts have stiffness
- `OnLowEndurance` - Endurance critically low

### System-Level Player State Checks

Some events require the player to be in an active state. The system provides utility functions that block XP gain when player is:

- **In vehicle** - No technique XP while driving
- **Sleeping** - No activity-based XP while asleep
- **Sitting** - No activity-based XP while sitting on furniture/ground
- **Lying down** - No activity-based XP while resting on bed
- **Reading** - No activity-based XP while reading books

These checks are implemented at the system level in `TechniqueEvents` and can be used by any event:

```lua
-- Check if player is in inactive state (general)
local isInactive, reason = TechniqueEvents.isPlayerInactive(player)

-- Check if player is physically active (stricter, for movement-based techniques)
local isActive, reason = TechniqueEvents.isPlayerPhysicallyActive(player)
```

Note: Some events like `OnCalorieSurplus` and `OnHealthRecovery` can trigger during rest, as they represent passive body processes.

### Event Data

Each event provides context data:
```lua
OnCalorieSurplus = {
    calories = currentCalorieCount,
    surplus = amountAboveThreshold,
    sustainedMinutes = consecutiveMinutes,
}
```

Techniques use this data for conditional XP gain.

---

## XP and Stage Advancement

### XP Calculation

When event fires:
1. Find techniques registered for this event
2. For each technique player has learned:
   - Check condition (if any)
   - Calculate XP gain
   - Award XP via Manager

### Stage Advancement Logic

When XP is added:
1. Add XP to technique
2. Check if XP >= required for next stage
3. If yes: increment stage, reset XP, trigger callbacks
4. Display stage advancement message

### XP Scaling

Stages should feel progressively harder:

| From Stage | To Stage | Typical XP Multiplier |
|------------|----------|----------------------|
| Initiate (1) | Adept (2) | 1.0x (baseline) |
| Adept (2) | Accomplished (3) | 1.5x |
| Accomplished (3) | Perfected (4) | 2.0x |
| Perfected (4) | Transcendent (5) | 3.0x |

### Safety Checks
- XP requirements must be > 0 (prevents infinite loops)
- Stage capped at maxStage (usually 5)
- Invalid techniques are skipped

---

## Effect System

### Effect Scaling by Stage

Effects should feel meaningful at each stage:

| Stage | Effect Multiplier | Description |
|-------|-------------------|-------------|
| Initiate (1) | ~20% | Barely noticeable |
| Adept (2) | ~40% | Noticeable but unreliable |
| Accomplished (3) | ~60% | Solid, dependable |
| Perfected (4) | ~80% | Powerful |
| Transcendent (5) | 100% | Full mastery |

### Effect Retrieval

Other systems request technique effects:
```lua
TechniqueSystem.getEffect(player, "technique_id", "effectName", default)
```

### Effect Application

Effects are passive modifiers applied by cultivation systems:
- **Efficient Absorption**: Modifies healing calculations
- **Movement Economy**: Modifies endurance drain
- **Energy Stabilization**: Modifies zombie attraction

Techniques don't apply their own effects—they provide values that other systems consume.

---

## Player Data

### Storage Structure
```lua
player.modData.CultivationTechniques = {
    techniques = {
        [techniqueId] = {
            learned = true,
            stage = 1,  -- 1-5
            xp = 0,
            totalXP = 0,
        },
    },
}
```

### Persistence
- Saved via player ModData
- Auto-saves every 10 game minutes
- Saved on player death
- Loaded on game load

---

## Manuscript Items

### Item Definition
Each technique has an associated manuscript item:
- Defined in item scripts
- Appears in world loot tables
- Can drop from zombies

### Learning Flow
1. Player finds manuscript in inventory
2. Right-click → "Study: [Technique Name]"
3. Requirements checked (Body level, etc.)
4. If met: technique learned, manuscript consumed
5. Technique starts at stage 1 (Initiate), XP 0

---

## UI Integration

### Stage Display

Instead of "Level 5/10", display:
- Stage name: "Accomplished"
- Progress bar toward next stage (→ Perfected)

### Technique Window
- Displays all known techniques
- Shows current stage name
- Shows XP progress toward next stage
- Lists current effects (descriptive, no numbers shown)
- Shows locked techniques with requirements

### Stage-Up Messages

When advancing stages, show atmospheric messages:
```
"Movement Economy" → Accomplished
```

No raw numbers exposed to player.

### Keybind
- Default: K key
- Toggles technique window

---

## Extensibility

### Adding New Techniques

1. Create definition file in `definitions/`
2. Register with TechniqueRegistry
3. Create manuscript item
4. Add to distribution tables

No changes to core systems required.

### Adding New Events

1. Add event hook in TechniqueEvents
2. Document event data structure
3. Techniques can register for new event

### Adding New Effects

1. Define effect in technique's getEffects()
2. Consume effect in appropriate system
3. No registry changes needed

---

## Performance Considerations

### Event Processing
- Standard events: immediate, per-occurrence
- Calculated events: once per minute, all players

### Data Caching
- Display data cached with refresh interval
- UI updates every 0.5 seconds, not every frame

### Cleanup
- Player tracking data cleared on death
- No persistent memory leaks

---

## Error Handling

### Invalid Technique IDs
- Logged as warning
- Operations return safely

### Missing Requirements
- Clear error messages shown
- Operations blocked with feedback

### XP Calculation Errors
- Fallback to default values
- Infinite loop prevention

