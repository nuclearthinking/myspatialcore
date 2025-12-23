# Technique System Integration Status

## Overview

This document describes which parts of the Technique system have been integrated into the unified Effect System and which parts remain separate.

---

## ✅ **Fully Integrated into Effect System**

### Future Techniques (Placeholder)
- **Movement Economy** - Will provide endurance reduction effects
- **Energy Stabilization** - Will provide fatigue reduction effects

**Status**: Effect mappings exist in `TechniqueEffectProvider.lua` but techniques need to be fully implemented.

---

## 🔄 **Partially Integrated**

### Technique Infrastructure
- **TechniqueManager**: Integrated - calls `EffectSystem.markDirty()` when techniques are learned or staged up
- **TechniqueRegistry**: Independent - manages technique definitions and stage progression
- **TechniqueEvents**: Independent - handles XP gain events
- **TechniqueEffectProvider**: Created but mostly empty - waiting for technique effects to be defined

**Integration Points**:
- Learning a technique → `EffectSystem.markDirty(player)` called (line 171 in TechniqueManager.lua)
- Staging up → `EffectSystem.markDirty(player)` called (line 267 in TechniqueManager.lua)

---

## 🔄 **Hybrid Integration**

### Camel's Hump Technique (驼峰蓄能术)

**What's Integrated** ✅:
- **HP Regeneration** (Stage 2+) - Registered as `health_regen` effect
  - Stacks with Body Cultivation's health regen (Level 7+)
  - Visible in EffectDebug UI
  - Value: 0.15-1.20 HP/min (increases with stage and Body level)
- **Stiffness Decay** - Registered as `stiffness_decay` effect
  - Stacks with Body Cultivation's stiffness decay
  - Visible in EffectDebug UI
  - Value: 5-50/min (increases with stage and Body level)
- **Metabolism Efficiency** - Registered as `metabolism_efficiency` multiplier
  - Actually applied to wound healing power
  - Allows equipment/buffs to modify technique healing

**What's Separate** 🔧:
- Complex conditional wound healing (only applies when wounded)
- Custom calorie consumption and weight conversion
- Multi-phase operation (assess → heal → consume energy)
- Infection healing mechanics
- Body part direct healing

**Reason for Hybrid**:
- Simple passive effects benefit from unified system (stacking, debugging)
- Complex active abilities maintain full control and technique-specific logic
- Best of both worlds: integration where useful, separation where necessary

**Location**: `techniques/definitions/TechniqueCamelsHump.lua`

**Effect Types**:
- Wound healing (scratches, cuts, bites, burns, fractures)
- Stiffness healing
- HP regeneration (stage 2+)
- Calorie consumption
- Weight-to-calorie conversion (stage 3+)

---

## 📝 **Why Some Techniques Aren't Integrated**

### Complex vs Simple Effects

**Simple Effects** (Good fit for unified system):
```lua
-- Movement Economy: -20% endurance drain
-- Energy Stabilization: -15% fatigue gain
-- These are passive multipliers that can stack with Body Cultivation
```

**Complex Effects** (Keep separate):
```lua
-- Devouring Elephant: Conditional healing based on wounds/hunger/weight
-- Too many variables and conditions to fit into simple effect model
```

---

## 🔮 **Future Integration Path**

### Option 1: Keep Complex Techniques Separate (Current Approach)
**Pros**:
- Preserves existing logic
- No risk of breaking working features
- Simpler to maintain

**Cons**:
- Effects don't show in debug UI
- Can't stack with unified effects
- Duplication of some code

### Option 2: Gradual Migration
**Steps**:
1. Extract passive parts (e.g., stiffness reduction) → Unified system
2. Keep active parts (e.g., wound healing) → Separate
3. Use hybrid approach

### Option 3: Conditional Effects in Unified System
**Add to EffectRegistry**:
```lua
CONDITIONAL_HEALING = {
    name = "conditional_healing",
    type = "conditional",
    condition = function(player)
        -- Check if player is wounded
        return hasWounds(player)
    end,
    apply = function(player, value)
        -- Complex healing logic here
    end
}
```

**Pros**: Everything in one system  
**Cons**: Makes unified system more complex

---

## 🎯 **Recommendation**

**Keep current hybrid approach** for now:

1. **Simple Passive Effects** → Unified Effect System
   - Movement Economy endurance reduction
   - Energy Stabilization fatigue reduction
   - Equipment bonuses (future)
   - Spirit Cultivation effects (future)

2. **Complex Active Abilities** → Separate Systems
   - Devouring Elephant metabolism
   - Combat techniques (future)
   - Ritual techniques (future)

**Benefits**:
- Clear separation of concerns
- Simple effects stack cleanly
- Complex effects maintain full control
- Easy to debug both systems

---

## 📊 **Current Integration Map**

```
Body Cultivation System
  └─> BodyCultivationProvider
       └─> EffectRegistry
            └─> EffectApplicator
                 └─> Character Stats ✅

Technique System
  ├─> Simple Techniques (future)
  │    └─> TechniqueEffectProvider
  │         └─> EffectRegistry
  │              └─> EffectApplicator
  │                   └─> Character Stats ✅
  │
  └─> Complex Techniques (current)
       └─> TechniqueEvents
            └─> Technique.applyEffect()
                 └─> Character Stats directly ⚠️
```

---

## 🔧 **Adding New Techniques**

### For Simple Passive Effects

**Step 1**: Define technique in TechniqueRegistry
```lua
-- In techniques/definitions/TechniqueMyEffect.lua
local technique = {
    id = "my_effect",
    name = "My Effect Technique",
    getEffects = function(stage)
        return {
            enduranceReduction = 0.1 + (stage * 0.05)
        }
    end
}
TechniqueRegistry.register(technique)
```

**Step 2**: Add mapping in TechniqueEffectProvider
```lua
-- In TechniqueEffectProvider.lua mapTechniqueEffects()
if technique.id == "my_effect" then
    if techniqueEffects.enduranceReduction then
        table.insert(effects, {
            name = "endurance_reduction",
            value = techniqueEffects.enduranceReduction,
            metadata = {technique = technique.id, stage = stage},
            priority = 5,
        })
    end
end
```

**Done!** Effects now stack with Body Cultivation and show in debug UI.

### For Complex Active Abilities

**Step 1**: Define technique with custom `applyEffect` function
```lua
local function applyMyComplexEffect(player, stage)
    -- Complex logic here
    if someCondition then
        -- Do something
    end
end

local technique = {
    id = "my_complex",
    applyEffect = applyMyComplexEffect,
    -- ...
}
```

**Step 2**: Hook into TechniqueEvents
```lua
-- In TechniqueEvents.lua applyTechniqueEffects()
-- Already done! Automatically calls applyEffect if defined
```

---

## 🐛 **Known Limitations**

1. **Devouring Elephant effects not visible in EffectDebug UI**
   - Workaround: Add manual debug prints in the technique

2. **Can't stack Devouring Elephant with unified hunger reduction**
   - This is by design - metabolism is separate from passive effects

3. **TechniqueEffectProvider is mostly empty**
   - Waiting for techniques to be implemented
   - Not a bug, just incomplete

---

## ✅ **Testing Checklist**

When adding new techniques:

- [ ] Technique learns correctly
- [ ] Technique stages up
- [ ] `EffectSystem.markDirty()` called on changes
- [ ] Effects show in `EffectDebug.status()` (for unified effects)
- [ ] Effects stack correctly with Body Cultivation
- [ ] Technique-specific logic works (for complex effects)
- [ ] No errors in console

---

**Last Updated**: December 2024  
**Status**: Hybrid approach working as intended  
**Next Steps**: Implement Movement Economy and Energy Stabilization techniques

