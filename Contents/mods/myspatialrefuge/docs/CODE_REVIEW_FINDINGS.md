# Code Review Findings - Effect System Refactoring

## 🔴 **CRITICAL ISSUES**

### 1. **Body XP Multiplier Double Application** (EffectHooks.lua:58-78)

**Issue**: XP multiplier may be applied twice for the same XP gain!

```lua
local function onAddXP(player, perk, xpAmount)
    if perk ~= Perks.Body then return end
    
    local bodyXPMult = EffectRegistry.get(player, "body_xp_multiplier", 1.0)
    if bodyXPMult == 1.0 then return end
    
    -- Apply multiplier (negative values reduce XP)
    local bonus = xpAmount * (bodyXPMult - 1.0)
    xp:AddXP(Perks.Body, bonus)  -- ⚠️ THIS WILL TRIGGER AddXP AGAIN!
end
```

**Problem**: `AddXP` event fires when we call `xp:AddXP()`, causing recursive calls!

**Impact**: 
- Energy Stabilization penalty applied multiple times
- XP gain compounds incorrectly
- Potential infinite recursion if bonus is positive

**Fix**: Need recursion guard or different approach

---

### 2. **Attack Endurance Timing Issue** (EffectHooks.lua:23-50)

**Issue**: Hook fires DURING swing, not after, making endurance restoration imprecise.

```lua
local function onWeaponSwing(player, weapon)
    -- ...
    local swingCost = 0.5  -- ⚠️ HARDCODED ESTIMATE
    if weapon then
        swingCost = swingCost + (weapon:getWeight() * 0.1)
    end
```

**Problems**:
- Swing cost is estimated, not actual
- Hook timing may not capture the full cost
- Different attack types (shove, stomp) not handled
- Doesn't account for fatigue/exertion modifiers

**Impact**: Endurance reduction is approximate, not exact

**Fix**: Need before/after endurance snapshot or more accurate formula

---

## 🟡 **PERFORMANCE ISSUES**

### 3. **Cache Not Used Efficiently** (TechniqueEvents.lua:236-261)

**Issue**: Cache check has overhead even when all techniques maxed.

```lua
local function hasLevelableTechniques(player)
    local username = player:getUsername()
    
    if playerLevelableCache[username] ~= nil then
        return playerLevelableCache[username]  -- ✅ Good
    end
    
    -- But if cache is nil, we iterate ALL techniques every time!
    local learnedTechniques = TechniqueManager.getLearnedTechniques(player)
    -- ...
end
```

**Problem**: First call after cache invalidation is expensive.

**Impact**: Small spike when technique levels up (acceptable but could be better)

**Optimization**: Pre-populate cache on load instead of lazy evaluation

---

### 4. **Zombie Perception Runs Every 10 Minutes** (EffectHooks.lua:114-125)

**Issue**: Updates every 10 minutes even if no players have the effect!

```lua
local function onEveryTenMinutes()
    local numPlayers = getNumActivePlayers()
    for i = 0, numPlayers - 1 do
        local player = getSpecificPlayer(i)
        if player and player:isAlive() then
            applyZombiePerceptionEffects(player)  -- ⚠️ Always runs
        end
    end
end
```

**Problem**: No check if `zombie_attraction_reduction` effect is active.

**Impact**: Wasted CPU every 10 minutes for players without Energy Stabilization

**Fix**: Check if effect exists before processing:
```lua
if EffectRegistry.get(player, "zombie_attraction_reduction", 0) > 0 then
    applyZombiePerceptionEffects(player)
end
```

---

## 🟠 **LOGIC ISSUES**

### 5. **Missing Goto Label Fallback** (TechniqueManager.lua:286-343)

**Issue**: `goto continue` requires Lua 5.2+, Kahlua may not support it!

```lua
if techData and techData.stage >= maxStage then
    goto continue  -- ⚠️ May not work in Kahlua!
end
-- ...
::continue::
```

**Problem**: Kahlua (PZ's Lua version) is based on Lua 5.1, which doesn't have `goto`.

**Impact**: MOD WILL CRASH ON LOAD if Kahlua doesn't support goto!

**Fix**: Use flag-based skip instead:
```lua
local shouldProcess = true
if techData and techData.stage >= maxStage then
    shouldProcess = false
end

if shouldProcess then
    -- ... processing ...
end
```

---

### 6. **Circular Dependency Risk** (TechniqueManager.lua:170-175, 266-271)

**Issue**: Lazy loading with pcall may hide errors.

```lua
local success, EffectSystem = pcall(require, "effects/EffectSystem")
if success and EffectSystem then
    EffectSystem.markDirty(player)
end
```

**Problem**: 
- Silently fails if module has errors
- Doesn't distinguish between "module not found" vs "module has bugs"
- Makes debugging harder

**Impact**: Effects may not update after technique level up, no error shown

**Better Approach**:
```lua
local EffectSystem = require("effects/EffectSystem")  -- At module level
-- Then just call directly:
EffectSystem.markDirty(player)
```

---

## 🟢 **MINOR ISSUES**

### 7. **Inconsistent Debug Output** (Multiple files)

**Issue**: Some files check `isDebug`, some don't, inconsistent logging.

**Examples**:
- EffectRegistry: Always prints errors (good)
- EffectHooks: Only logs if isDebug (inconsistent)
- TechniqueManager: Logs important events always (good)

**Impact**: Hard to debug in production without enabling full debug mode

**Recommendation**: 
- Always log errors/warnings
- Gate verbose info behind isDebug
- Use consistent log prefixes

---

### 8. **Memory Leak Potential** (TechniqueEvents.lua:14, 18)

**Issue**: Caches never cleaned up for disconnected players in multiplayer.

```lua
local playerTracking = {}
local playerLevelableCache = {}
```

**Problem**: In multiplayer, players can connect/disconnect, leaving stale data.

**Current Cleanup**: Only on death/load, not disconnect

**Impact**: Memory slowly grows in long-running multiplayer servers

**Fix**: Already has cleanup function, just needs to be called on disconnect:
```lua
Events.OnPlayerDisconnect.Add(cleanupPlayerTracking)  -- If event exists
```

---

### 9. **Hardcoded Magic Numbers** (EffectHooks.lua:35-38)

```lua
local swingCost = 0.5  -- ⚠️ Magic number
if weapon then
    swingCost = swingCost + (weapon:getWeight() * 0.1)  -- ⚠️ Magic number
end
```

**Impact**: Hard to tune, not documented why these values were chosen

**Fix**: Move to module-level constants with comments:
```lua
local BASE_SWING_COST = 0.5  -- Base endurance cost per attack
local WEIGHT_MULTIPLIER = 0.1  -- Additional cost per kg of weapon weight
```

---

## 🔵 **EDGE CASES**

### 10. **Multiplier Edge Case** (EffectHooks.lua:66)

**Issue**: What if `bodyXPMult` is 0 or negative?

```lua
local bonus = xpAmount * (bodyXPMult - 1.0)
-- If bodyXPMult = 0, bonus = -xpAmount (removes all XP) ✅ Intended?
// If bodyXPMult = -0.5, bonus = -1.5 * xpAmount (negative XP!) ⚠️
```

**Impact**: Negative multipliers could cause weird behavior

**Fix**: Clamp multiplier to reasonable range:
```lua
local bodyXPMult = math.max(0, math.min(2.0, EffectRegistry.get(player, "body_xp_multiplier", 1.0)))
```

---

### 11. **Nil Player in Hooks** (EffectHooks.lua multiple locations)

**Issue**: Events may fire with nil player in edge cases.

**Current Protection**: Most functions check `if not player`

**Missing**: Some nested functions don't re-check after getting player

**Impact**: Potential nil reference if player dies between checks

**Status**: Mostly handled, but worth thorough testing

---

## 📋 **CODE QUALITY**

### 12. **Good Practices Found** ✅

- Comprehensive nil checks
- Safe registry access with defaults
- Cached debug mode (performance)
- Per-player data isolation (multiplayer safe)
- Clear function documentation
- Module-level constants for performance

### 13. **Areas for Improvement**

- More unit testable functions (pure functions)
- Consistent error handling patterns
- More validation of external inputs
- Better separation of concerns in large functions

---

## 🎯 **PRIORITY FIXES**

### **MUST FIX BEFORE TESTING:**

1. ⚠️ **Replace `goto` with flags** (Kahlua compatibility)
2. ⚠️ **Add recursion guard for Body XP multiplier**
3. ⚠️ **Add effect existence check for zombie perception**

### **SHOULD FIX SOON:**

4. Document/improve attack endurance estimation
5. Add better error handling for circular dependencies
6. Clean up player caches on disconnect

### **NICE TO HAVE:**

7. Consistent debug logging patterns
8. Extract magic numbers to constants
9. Add multiplier clamping
10. Pre-populate caches on load

---

## 🧪 **TESTING RECOMMENDATIONS**

### **Critical Path Testing:**
1. Test with all techniques maxed (cache works?)
2. Test technique level-up (cache invalidates?)
3. Test Energy Stabilization penalty (no infinite loop?)
4. Test attack endurance reduction (reasonable values?)
5. Test multiplayer disconnect (memory cleanup?)

### **Edge Case Testing:**
1. Learn/unlearn techniques rapidly
2. Multiple players leveling simultaneously
3. Player death during technique effect application
4. Save/load with various technique states
5. Long-running server (memory leak check)

---

**Review Date**: December 2024  
**Reviewer**: AI Code Analysis  
**Overall Assessment**: Good architecture, several fixable issues found  
**Recommendation**: Fix critical issues before in-game testing

