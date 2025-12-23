# Exercise Enhancement - System Design

## Core Mechanics

### Exercise Detection

**Method**: Check player's current action each update cycle

**API**: `player:getCurrentAction()` returns action with `Type` and `exerciseType`

**Throttling**: Check once per second to minimize performance impact

### Exercise Tracking

When player exercises:
1. Detect exercise start
2. Track exercise type and start time
3. On exercise end, calculate duration
4. Apply buff based on duration and exercise type

### Buff Application

**Formula**: `buffDuration = exerciseMinutes × durationPerMinute`

**Example**: 2 minutes of burpees × 60 min/min = 120 minute buff

---

## Configuration

### Exercise Types

```
Burpees:   multiplier 3.0, duration 60 min per exercise min
Squats:    multiplier 2.5, duration 45 min
Pushups:   multiplier 2.5, duration 45 min
Situps:    multiplier 2.0, duration 30 min
Bicep:     multiplier 1.5, duration 20 min
Tricep:    multiplier 1.5, duration 20 min
```

### Limits

- Maximum buff duration: 120 minutes
- Minimum exercise for buff: 1 minute

---

## Buff Management

### Storage

Buff data stored in player ModData:
```
player.modData.cultivationExerciseBuff = {
    multiplier: current multiplier (1.0 = none),
    remainingMinutes: time until expiration,
    lastExerciseType: which exercise granted buff,
    exerciseStartTime: timestamp for tracking
}
```

### Stacking Rules

**No Stacking**: Only highest multiplier applies

When new exercise completes:
- If new multiplier > current: replace multiplier
- Duration always added (up to cap)

### Decay

Every game minute:
1. Decrement remainingMinutes
2. If reaches 0: reset multiplier to 1.0
3. Notify player of expiration

---

## Integration

### With Body Cultivation

Modified XP award function:
```
finalXP = baseXP × exerciseMultiplier
```

Exercise system provides `getMultiplier(player)` function that cultivation system calls.

### Kill Handler Flow

1. Zombie dies
2. Validate melee kill
3. Get exercise multiplier
4. Calculate final XP: base × multiplier
5. Award XP to Body perk

---

## Notifications

### On Buff Gain
"Body Tempering: 3.0x XP (60 min)"
- Shows multiplier and duration
- Green text with arrow

### On Kill with Buff
"+30 Body XP (3.0x)"
- Shows boosted XP and multiplier
- Only if multiplier > 1.0

### On Buff Expiration
"Body Tempering Expired"
- Red text with down arrow
- Reminds player to exercise again

---

## Edge Cases

### Exercise Interruption

If exercise is interrupted (zombie attack, etc.):
- Buff still applied for time exercised
- Partial minutes rounded down
- Less than 1 minute = no buff

### Death

On player death:
- All buff data cleared
- Multiplier reset to 1.0
- Encourages careful play with buff active

### Save/Load

Buff persists through save/load:
- ModData auto-saves
- Duration continues from saved value

---

## Performance

### Throttling

Exercise detection runs once per second, not every frame:
```
if currentTime - lastCheck < 1.0 then return end
```

### Minimal Overhead

- Simple flag checks per update
- No iteration over large data structures
- ModData access is fast

---

## Balance Tuning

### If Too Powerful

Reduce impact:
- Lower multiplier values (3.0 → 2.0)
- Reduce duration per minute (60 → 30)
- Add daily buff cap

### If Too Weak

Increase impact:
- Higher multiplier values
- Longer duration per minute
- Allow partial stacking

### Current Balance

Designed to cut progression time by 30-60%:
- Requires active effort (exercise time)
- Has natural costs (fatigue, hunger)
- Creates interesting gameplay loop






