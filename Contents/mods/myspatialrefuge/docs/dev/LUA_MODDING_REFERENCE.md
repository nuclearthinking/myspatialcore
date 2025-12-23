# Project Zomboid - Lua Modding Possibilities

*A comprehensive guide to what's possible from Lua mods*

> **Note:** This is a development reference document, not mod documentation. It covers general PZ Lua modding capabilities.

---

## 🎮 Player & Character System

### IsoPlayer / IsoGameCharacter

#### **Core Access**
- `getPlayer()` - Get player instance (global function)
- `getSpecificPlayer(num)` - Get player by number (multiplayer)
- `getInventory()` - Access player's inventory container
- `getBodyDamage()` - Access health/injury system
- `getStats()` - Access Stats object (hunger, thirst, fatigue, etc.)
- `getMoodles()` - Access status indicators

#### **Traits & Skills**
- `getTraits()` - Get TraitCollection (read-only)
- `HasTrait(name)` - Check if player has trait
- `getXp()` - Get XP object for skill levels
- `getPerkLevel(perk)` - Get skill level

#### **State Queries**
- `isAsleep()` - Check sleep state
- `getVehicle()` - Get vehicle if in one
- `isRunning()` - Check if running
- `isSprinting()` - Check if sprinting
- `isAiming()` - Check if aiming weapon

#### **Equipment**
- `getPrimaryHandItem()` - Get equipped weapon/tool
- `getSecondaryHandItem()` - Get off-hand item
- `getWornItems()` - Get all clothing list
- `isEquipped(item)` - Check if item equipped
- `setWornItem(item, location)` - Equip item
- `removeWornItem(item)` - Unequip item

---

## 📦 Inventory & Items System

### InventoryItem (Base Item Class)

#### **Weight & Properties** ⚡ OVERRIDABLE
- `getWeight()` - Get item weight (**OVERRIDE TO MAKE WEIGHTLESS**)
- `getActualWeight()` - Get base weight (used in some calculations)
- `setWeight(float)` - Set item weight (not persistent)
- `getType()` - Get item type string (e.g., "Apple", "Axe")
- `getFullType()` - Get full type (e.g., "Base.Apple")
- `getDisplayName()` - Get localized display name

#### **Container Detection** 🔍 KEY FOR MAGIC
- `getContainer()` - Get parent container (**DETECT WHERE ITEM IS**)
- `getItemContainer()` - Get internal container (for bags)
- `getWorldItem()` - Get IsoWorldInventoryObject if on ground
- `getID()` - Get unique item instance ID

#### **Item State & Condition**
- `getAge()` - Get spoilage age (**MODIFIABLE**)
- `setAge(float)` - Reset spoilage (**ANTI-SPOIL MECHANIC**)
- `getCondition()` - Get durability (0-100)
- `setCondition(float)` - Set durability (**AUTO-REPAIR**)

#### **Custom Data** 💾 PERSISTENT STORAGE
- `getModData()` - Get KahluaTable for custom data
- Store ANY custom data: `item:getModData().myValue = 123`
- Persists in save games!

### ItemContainer

#### **Container Management**
- `getItems()` - Get ArrayList of items
- `getCapacity()` - Get max capacity (hardcap 50 for bags)
- `setCapacity(int)` - Set capacity (respects hardcaps)
- `getContentsWeight()` - Calculate total item weight

#### **Item Operations**
- `AddItem(item)` - Add item to container
- `Remove(item)` - Remove item
- `contains(item)` - Check if contains specific item
- `containsType(type)` - Check if contains item type

#### **Container Properties**
- `getContainingItem()` - Get parent item (**KEY FOR NESTED DETECTION**)
- `isInCharacterInventory(player)` - Check if in player's possession

---

## ⏱️ Time & Events

### Event System

#### **Timed Events**
- `Events.EveryOneMinute.Add(func)` - Every in-game minute
- `Events.EveryTenMinutes.Add(func)` - Every 10 minutes (**GOOD FOR BACKGROUND TASKS**)
- `Events.EveryHours.Add(func)` - Every hour
- `Events.OnPlayerUpdate.Add(func)` - Every frame (use sparingly!)

#### **Game State Events**
- `Events.OnGameBoot.Add(func)` - Game starts (**INIT OVERRIDES HERE**)
- `Events.OnLoad.Add(func)` - Save loaded (**REINIT OVERRIDES**)
- `Events.OnSave.Add(func)` - Before save

---

## 💬 Player Notifications & Messages

### HaloTextHelper (Green Text System)

The same system used for skill level-ups! Shows floating text above player's head.

#### **Basic Messages**
- `HaloTextHelper.addGoodText(player, "Success!")` - Green text (like level-ups)
- `HaloTextHelper.addBadText(player, "Failed!")` - Red text (errors)
- `HaloTextHelper.addText(player, "Info")` - White text (neutral)

#### **Messages with Arrows** (Stat Changes)
```lua
-- Up arrow (increase)
HaloTextHelper.addTextWithArrow(player, "Capacity 20", true, HaloTextHelper.getColorGreen())

-- Down arrow (decrease)
HaloTextHelper.addTextWithArrow(player, "Weight -5", false, HaloTextHelper.getColorRed())
```

---

## 💪 Stats & Character Modification

### Stats Class

#### **Needs**
- `getHunger()` / `setHunger(float)` - Hunger level (0-1)
- `getThirst()` / `setThirst(float)` - Thirst level
- `getFatigue()` / `setFatigue(float)` - Tiredness
- `getStress()` / `setStress(float)` - Stress level
- `getBoredom()` / `setBoredom(float)` - Boredom
- `getUnhappiness()` / `setUnhappiness(float)` - Mood

#### **Status**
- `getPain()` / `setPain(float)` - Pain level
- `getPanic()` / `setPanic(float)` - Panic state
- `getEndurance()` / `setEndurance(float)` - Stamina

### BodyDamage Class

#### **Health Management**
- `getHealth()` / `setHealth(float)` - Overall health
- `getBodyPart(type)` - Get specific body part
- `RestoreToFullHealth()` - Full heal

---

## 🔄 Method Override Patterns

### What You CAN Override ✅

```lua
-- Pattern: Store original, override with custom logic
local originalGetWeight = InventoryItem.getWeight

InventoryItem.getWeight = function(self)
    if self:getType() == "MagicStone" then
        return 0  -- Weightless
    end
    return originalGetWeight(self)  -- Normal for others
end

-- Initialize on both boot AND load
Events.OnGameBoot.Add(initializeOverrides)
Events.OnLoad.Add(initializeOverrides)
```

### What You CANNOT Override

❌ **Java-to-Java internal calls** (transfer time, capacity checks, etc.)
❌ **Methods without @LuaMethod annotation**
❌ **Private Java fields directly**
❌ **Trait modification at runtime**

---

## ⚠️ Critical Limitations & Workarounds

### ❌ Transfer Speed (IMPOSSIBLE)
**Problem:** Transaction time calculated in Java internally
**Workaround:** None available.

### ❌ Capacity Hardcap (50 for bags)
**Problem:** `Math.min(this.Capacity, 50)` hardcoded
**Workaround:** ✅ **Make items weigh 0** = infinite effective storage within limit

### ❌ Trait Modification (NO RUNTIME ADD/REMOVE)
**Problem:** `TraitCollection.add()` not exposed to Lua
**Workaround:** Check traits conditionally, simulate trait effects

---

## ⚡ Quick Reference - Most Powerful APIs

### Top 10 Methods for Magical Mods

| Method | Use Case |
|--------|----------|
| `item:setAge(0)` | Prevent spoilage |
| `item:getWeight()` override | Zero weight items |
| `item:getModData()` | Persistent data |
| `item:getContainer()` | Context detection |
| `item:setCondition(100)` | Auto-repair |
| `stats:setHunger(0)` | Remove hunger |
| `bodyDamage:RestoreToFullHealth()` | Instant heal |
| `drainable:setUsedDelta(1.0)` | Refill liquid |
| `container:AddItem(type)` | Spawn items |
| `container:getContainingItem()` | Nested detection |

### Event Frequency Guide

| Event | Frequency | Best For |
|-------|-----------|----------|
| `OnPlayerUpdate` | Every frame | ❌ Avoid heavy logic |
| `EveryOneMinute` | 1/min in-game | Active effects |
| `EveryTenMinutes` | 10/min in-game | ✅ Background tasks |
| `EveryHours` | 1/hour in-game | Slow effects |
| `OnGameBoot` | Once at startup | ✅ Initialize overrides |
| `OnLoad` | Each save load | ✅ Reinitialize overrides |

---

*Generated from Project Zomboid Build 42 decompiled source*






