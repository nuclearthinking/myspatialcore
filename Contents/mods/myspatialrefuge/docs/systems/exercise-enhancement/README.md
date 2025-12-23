# Exercise Enhancement

## Concept

Physical training prepares the body to better absorb zombie energy. Survivors who exercise before combat gain temporary XP multipliers that accelerate Body Cultivation progression.

This creates a gameplay loop: prepare → hunt → repeat.

## Philosophy

**"The trained body is a better vessel. Energy flows where pathways are prepared."**

Exercise doesn't directly grant cultivation—it opens pathways for energy absorption. A body warmed up, muscles engaged, blood flowing, can capture more of the zombie's life force than a cold, unprepared one.

### The Training Loop

1. **Prepare**: Spend time exercising to activate multiplier
2. **Hunt**: Kill zombies while multiplier is active
3. **Rest**: Recover fatigue, eat to restore energy
4. **Repeat**: Begin cycle again

This mirrors real martial training philosophies: preparation, action, recovery.

## Mechanics

### Exercise Types

Different exercises provide different multipliers:

| Exercise | Multiplier | Duration per Minute | Intensity |
|----------|------------|---------------------|-----------|
| Burpees | 3.0x | 60 min buff | Very High |
| Squats | 2.5x | 45 min buff | High |
| Push-ups | 2.5x | 45 min buff | High |
| Situps | 2.0x | 30 min buff | Medium |
| Bicep Curls | 1.5x | 20 min buff | Low |
| Tricep Extensions | 1.5x | 20 min buff | Low |

### Buff Duration

Duration scales with exercise time:
- 1 minute of burpees → 60 minute buff
- 2 minutes of burpees → 120 minute buff (maximum)

Maximum buff duration is capped at 120 minutes.

### Multiplier Application

While buff is active:
- Base 10 XP per zombie becomes 10 × multiplier
- Burpees buff: 10 × 3.0 = **30 XP per kill**

## Progression Impact

### No Exercise
- 20 kills/day × 10 XP = 200 XP/day
- Level 10 in ~201 days

### Light Exercise (1-2 min daily)
- Average 1.5x multiplier
- 20 kills/day × 15 XP = 300 XP/day
- Level 10 in ~134 days (33% faster)

### Heavy Exercise (10 min daily)
- Average 2.5x multiplier
- 20 kills/day × 25 XP = 500 XP/day
- Level 10 in ~80 days (60% faster)

### Hardcore Exercise (20+ min daily)
- Sustained 3.0x multiplier
- 20 kills/day × 30 XP = 600 XP/day
- Level 10 in ~67 days (67% faster)

## Balance Considerations

### Natural Costs

Exercise has built-in costs through vanilla mechanics:

- **Time**: Can't exercise and fight simultaneously
- **Fatigue**: Exercise makes you tired (combat vulnerability)
- **Hunger/Thirst**: Exercise increases needs

These create natural limits without artificial restrictions.

### Stacking Rules

Only the highest multiplier applies:
- Multiple exercise types don't stack
- New exercise extends duration or upgrades multiplier

This prevents exploitation through exercise rotation.

## Synergies

### With Fitness Skill
- Higher Fitness = more effective exercise
- Creates reason to develop Fitness naturally

### With Body Cultivation
- Exercise multiplies Body XP specifically
- Encourages focused cultivation sessions

### With Spirit Cultivation
- Exercise fatigue contributes to Spirit XP
- Dual benefit from training sessions

---

*See [DESIGN.md](./DESIGN.md) for system design details.*






