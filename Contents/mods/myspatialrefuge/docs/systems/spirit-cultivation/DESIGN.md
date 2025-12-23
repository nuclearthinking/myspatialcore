# Spirit Cultivation - System Design

## Core Mechanics

### XP Acquisition

**Source**: Experiencing and enduring negative mental states

**Method**: Continuous passive gain based on current suffering intensity

**Sampling**: Every game minute, suffering levels are evaluated and XP awarded

### XP Sources

| Hardship | Threshold | XP Rate | Notes |
|----------|-----------|---------|-------|
| Stress | > 0.3 | 0-7 XP/min | Scales with intensity |
| Panic | > 0.5 | 0-10 XP/min | High rate (intense) |
| Pain | > 0.2 | 0-12 XP/min | Physical suffering counts |
| Fatigue | > 0.7 | 0-2.4 XP/min | Only extreme fatigue |
| Injury | < 80% health | 0-4 XP/min | Being wounded |
| Boredom/Unhappiness | > 0.6 | 1 XP/min | Minor contribution |

### Recovery Bonuses

Additional XP awarded when overcoming hardships:

| Recovery Event | XP Bonus | Trigger |
|----------------|----------|---------|
| Panic → Calm | 20-50 XP | Panic drops from >0.7 to <0.3 |
| Stress Relief | 10-30 XP | Major stress reduction |
| Near-Death Survival | 100 XP | Health <20% then recover to >50% |

---

## Progression Comparison

Spirit Cultivation progresses faster than Body Cultivation due to continuous XP gain:

### Conservative Playstyle
- Average 3 XP/min during hardships
- ~360 XP/day
- Level 10 in ~111 days

### Aggressive Playstyle
- Average 10 XP/min during hardships
- ~1,200 XP/day
- Level 10 in ~34 days

### Balancing

A global multiplier can adjust Spirit XP rates:
- 1.0x: Spirit levels ~2x faster than Body
- 0.5x: Spirit and Body level at similar rates
- 0.25x: Spirit becomes prestigious/difficult

---

## Effect Implementation

### Panic Reduction

**Approach**: Direct stat manipulation

When panic increases, system reduces the increase proportionally:
- Level 1-3: 20-30% reduction
- Level 4-6: 50% reduction
- Level 7-9: 80% reduction
- Level 10: 100% immunity (panic clamped to 0)

### Stress Recovery

**Approach**: Passive reduction over time

Spirit level grants continuous stress reduction:
- Applied every minute
- Higher levels = faster reduction
- Works even during dangerous situations at high levels

### Sleep Quality

**Approach**: Fatigue reduction while sleeping

When player is asleep, fatigue decreases faster:
- Level 1-3: +10% speed
- Level 4-6: +25% speed
- Level 7-9: +50% speed
- Level 10: +75% speed

### Comfort Tolerance

**Approach**: Reduced impact from negative moodles

Environmental discomfort (wet, cold, etc.) has reduced effect:
- Scales from 10% reduction to 60% reduction
- Applied to moodle severity

---

## Event Hooks

### XP Sampling
`EveryOneMinute` - Sample negative stats and award XP

**Operations**:
1. Check each hardship source
2. Calculate XP based on intensity
3. Apply global multiplier
4. Award to Spirit perk

### Recovery Detection
`EveryOneMinute` - Track stat changes for recovery bonuses

**Operations**:
1. Compare current stats to previous values
2. Detect significant reductions
3. Award bonus XP for recovery
4. Update tracking data

### Effect Application
`EveryOneMinute` - Apply passive Spirit effects

**Operations**:
1. Get player's Spirit level
2. Apply panic reduction
3. Apply stress recovery
4. Check sleep state for quality bonus

---

## Balance Considerations

### Self-Regulating Dynamic

Spirit Cultivation has built-in diminishing returns:
- High Spirit → Less panic/stress → Less XP gain
- Creates natural progression curve
- Encourages risk-taking at high levels

### Comparison to Body

| Aspect | Body | Spirit |
|--------|------|--------|
| XP Source | Active (kills) | Passive (suffering) |
| Player Control | High (choose to fight) | Low (suffering happens) |
| Progression Speed | Slower (~200 days) | Faster (~60-100 days) |
| Self-Regulation | None | Yes (effects reduce sources) |

### Design Intent

- Spirit should reach max before Body
- Encourages aggressive playstyle (more danger = more Spirit XP)
- High Spirit players can push harder for Body XP

---

## Tracking System

### Per-Player State

The system tracks previous stat values to detect recovery:

```
playerTracking[username] = {
    lastPanic: float,
    lastStress: float,
    lastHealth: float,
}
```

### Cleanup

Tracking data is cleared:
- On player death
- On game load (fresh start)

---

## Technical Notes

### Performance
- Sampling once per game minute (negligible impact)
- Simple arithmetic calculations
- No per-frame overhead

### Persistence
- Spirit level stored in vanilla perk system
- Tracking data is ephemeral (not saved)
- Recovery bonuses reset on load

### Edge Cases
- Player dying resets tracking
- Extreme stat values are clamped
- Negative XP is prevented






