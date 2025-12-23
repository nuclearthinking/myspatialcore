# Spatial Sack Progression System - Reference Document

**Status:** ✅ **FULLY IMPLEMENTED**

This document serves as a reference for the completed progression system and a guide for future improvements.

---

## 🎯 System Overview

The Spatial Sack features a 5-tier progression system where players collect Strange Zombie Cores from zombies to craft and upgrade a magical storage container with zero-weight items and anti-spoilage properties.

### Core Features (All Implemented)
- ✅ **Zombie Core Drops** - 30% drop rate per zombie kill
- ✅ **Recipe Learning System** - Research cores to unlock crafting
- ✅ **Crafting System** - Recipe-based initial creation (learnable)
- ✅ **State-Based Upgrades** - No item recreation, preserves contents
- ✅ **Dynamic Capacity** - Upgrades from 10 to 50 units
- ✅ **Zero Weight Storage** - Items inside weigh nothing
- ✅ **Anti-Spoilage** - Food never rots inside
- ✅ **Visual Notifications** - Green text system (like skill level-ups)
- ✅ **ModData Persistence** - Tier/state saves with item

---

## 📊 Progression Tiers

| Tier | Cores Needed | Capacity | Total Cores | Est. Kills (30% rate) |
|------|--------------|----------|-------------|-----------------------|
| **Learn** | 1 (research) | - | 1 | ~3 zombies |
| **0** | 5 (craft) | 10 | 6 | ~20 zombies |
| **1** | 3 | 20 | 9 | ~30 zombies |
| **2** | 5 | 30 | 14 | ~47 zombies |
| **3** | 8 | 40 | 22 | ~73 zombies |
| **4** | 10 | 50 | **32** | **~107 zombies** |

**Max Tier Benefits:**
- 50-unit capacity (hardcap maximum)
- Infinite weight storage (items weigh 0)
- Perfect preservation (no spoilage)
- ~107 total zombie kills to reach max (including 1 for recipe learning)

---

## 🎮 Player Experience

### Discovery Phase
1. Kill zombies → 30% chance to drop Strange Zombie Core
2. Right-click first core → "Read Strange Zombie Core"
3. Learn recipe (core consumed) → Notification: "Learned recipe for Craft Spatial Sack"
4. Collect 5 more cores (6 total needed)
5. Craft Spatial Sack (Tier 0) → Green notification: "Crafted Spatial Sack! Tier 0 - Capacity: 10"

### Progression Phase
1. Right-click Spatial Sack
2. Select "Enchant Spatial Sack (Tier X → Y)"
3. Tooltip shows: cores needed, capacity increase
4. Consume cores → Upgrade tier
5. Green notifications: "Spatial Sack Enchanted! ↑Tier X ↑Capacity Y"

### End Game
- Tier 4 reached
- Context menu shows: "Max Enchantment Reached"
- 50-unit capacity with infinite weight = ultimate storage

---

## 🔧 Technical Implementation

### 1. Strange Zombie Core Item
**File:** `media/scripts/item_MagicalCore.txt`

```txt
module Base
{
    item MagicalCore
    {
        DisplayName = Strange Zombie Core,
        DisplayCategory = Material,
        ItemType = base:normal,
        Weight = 0.2,
        Icon = Clay,
        StaticModel = Clay,
        WorldStaticModel = Clay,
        Researchablerecipes = Craft_Spatial_Sack
    }
}
```

**Properties:**
- `DisplayCategory = Material` - Shows in Material category, not equippable
- `ItemType = base:normal` - Normal item type (not weapon)
- `Icon = Clay` - Uses clay texture (brown/earthy appearance)
- `Researchablerecipes = Craft Spatial Sack` - **Native recipe learning system**
- No weapon/tool properties - prevents "Equip Primary/Secondary" options

**How it works:**
- Right-click core → "Read Strange Zombie Core"
- Core is consumed → Recipe is learned
- Uses vanilla game's research system (same as books/magazines)

### 2. Zombie Drop System
**File:** `media/lua/server/SpatialSackServer.lua`

```lua
local function onZombieDead(zombie)
    if not zombie then return end
    
    -- 30% chance to drop magical core
    if ZombRand(100) < 30 then
        zombie:getInventory():AddItem("Base.MagicalCore")
        
        if getDebug() then
            print("[SpatialSack] Zombie dropped Strange Zombie Core")
        end
    end
end

Events.OnZombieDead.Add(onZombieDead)
```

### 3. Crafting Recipe
**File:** `media/scripts/recipe_SpatialSack.txt`

```txt
module Base
{
    craftRecipe Craft_Spatial_Sack
    {
        Time = 200.0,
        category = Survivalist,
        NeedToBeLearn = True,
        OnCreate = OnCreateSpatialSack,
        
        inputs
        {
            item 5 [Base.MagicalCore],
            item 1 [Base.Needle] mode:keep,
            item 2 [Base.Thread],
            item 1 [Base.Sheet],
        }
        
        outputs
        {
            item 1 [Base.SpatialSack],
        }
    }
}
```

**Properties:**
- `craftRecipe` - Modern recipe format (new in recent updates)
- `NeedToBeLearn = True` - Recipe hidden until learned via core research
- `mode:keep` on Needle - Tool is not consumed during crafting
- Requires reading a Strange Zombie Core first (uses `Researchablerecipes`)
- Uses common materials + 5 cores

### 4. Crafting Handler with Notifications
**File:** `media/lua/shared/SpatialSackRecipe.lua`

```lua
function OnCreateSpatialSack(items, result, player)
    if not result then return end
    
    -- Set initial tier data
    local modData = result:getModData()
    modData.tier = 0
    modData.enchantLevel = 0
    modData.createdBy = player:getUsername()
    modData.creationTime = os.time()
    
    -- Set starting capacity (10 units)
    local container = result:getItemContainer()
    if container then
        container:setCapacity(10)
    end
    
    -- Show green notification
    if player then
        HaloTextHelper.addGoodText(player, "Crafted Spatial Sack!")
        HaloTextHelper.addText(player, "Tier 0 - Capacity: 10")
    end
end
```

### 5. Enchantment System
**File:** `media/lua/client/SpatialSackEnchant.lua`

**Key Features:**
- Tier configuration table (cores needed, capacity per tier)
- Core counting and consumption functions
- State-based upgrade (modifies existing item)
- Green text notifications with arrows
- Context menu with tooltips
- Validation (enough cores, max tier check)

```lua
-- Enchantment tier configuration
local ENCHANT_TIERS = {
    [0] = {cores = 5, capacity = 10},  -- Base (from craft)
    [1] = {cores = 3, capacity = 20},  -- Tier 1 upgrade
    [2] = {cores = 5, capacity = 30},  -- Tier 2 upgrade
    [3] = {cores = 8, capacity = 40},  -- Tier 3 upgrade
    [4] = {cores = 10, capacity = 50}, -- Tier 4 MAX
}

-- Perform enchantment
local function doEnchant(player, sack)
    local modData = sack:getModData()
    local currentTier = modData.enchantLevel or 0
    local nextTier = currentTier + 1
    
    local tierInfo = ENCHANT_TIERS[nextTier]
    if not tierInfo then
        HaloTextHelper.addBadText(player, "Maximum enchantment reached!")
        return
    end
    
    local inventory = player:getInventory()
    local coresNeeded = tierInfo.cores
    local coresAvailable = countCores(inventory)
    
    if coresAvailable < coresNeeded then
        HaloTextHelper.addBadText(player, "Need " .. coresNeeded .. " cores (have " .. coresAvailable .. ")")
        return
    end
    
    -- Consume cores and upgrade
    if consumeCores(inventory, coresNeeded) then
        modData.enchantLevel = nextTier
        
        local container = sack:getItemContainer()
        if container then
            container:setCapacity(tierInfo.capacity)
        end
        
        -- Show success with green text and arrows
        HaloTextHelper.addGoodText(player, "Spatial Sack Enchanted!")
        HaloTextHelper.addTextWithArrow(player, "Tier " .. nextTier, true, HaloTextHelper.getColorGreen())
        HaloTextHelper.addTextWithArrow(player, "Capacity " .. tierInfo.capacity, true, HaloTextHelper.getColorGreen())
    else
        HaloTextHelper.addBadText(player, "Enchantment failed!")
    end
end

-- Register context menu
Events.OnFillInventoryObjectContextMenu.Add(createEnchantMenu)
```

### 6. Integration with Main Module
**File:** `media/lua/client/SpatialSackMain.lua`

```lua
-- Load enchantment system
require "SpatialSackEnchant"
```

**Note:** Recipe learning is handled natively via `Researchablerecipes` in the item script, no custom Lua needed!

---

## 💾 ModData Structure

Items store persistent upgrade data in ModData:

```lua
item:getModData() = {
    tier = 0,                    -- Visual tier for display (0-4)
    enchantLevel = 0,            -- Actual enchantment level (0-4)
    createdBy = "PlayerName",    -- Who crafted it
    creationTime = 1234567890,   -- Unix timestamp
}
```

**Persistence:**
- ✅ Saves with item across game sessions
- ✅ Preserved when item is dropped/picked up
- ✅ Maintained when item is traded
- ✅ Survives server restarts (multiplayer)

---

## 🎨 Notification System

Uses `HaloTextHelper` - the same green text system as skill level-ups:

```lua
-- Success messages (green)
HaloTextHelper.addGoodText(player, "Enchanted!")

-- Error messages (red)
HaloTextHelper.addBadText(player, "Not enough cores!")

-- Arrows for stat changes
HaloTextHelper.addTextWithArrow(player, "Tier 2", true, HaloTextHelper.getColorGreen())
```

**Benefits:**
- Professional look consistent with game UI
- Automatic queueing of multiple messages
- ~2-3 second display duration
- Arrow indicators for increases/decreases

---

## ⚙️ Balance & Configuration

### Drop Rate Tuning
**Current:** 30% per zombie (in `SpatialSackServer.lua` line 8)

```lua
if ZombRand(100) < 30 then  -- Change 30 to adjust drop rate
```

**Balance Chart:**

| Drop Rate | Kills/Core | Kills to Max | Time (estimate) |
|-----------|------------|--------------|-----------------|
| 10% | ~10 | ~310 | Long-term goal |
| 20% | ~5 | ~155 | Mid-term goal |
| **30%** | **~3** | **~103** | **Current** |
| 50% | ~2 | ~62 | Fast progression |

### Tier Costs Tuning
Edit `ENCHANT_TIERS` table in `SpatialSackEnchant.lua`:

```lua
local ENCHANT_TIERS = {
    [0] = {cores = 5, capacity = 10},   -- Adjust cores or capacity
    [1] = {cores = 3, capacity = 20},
    -- ...
}
```

---

## 🔒 Limitations & Workarounds

### Known Limitations

1. **50-Unit Capacity Hardcap**
   - **Cause:** `Math.min(capacity, 50)` in `ItemContainer.java`
   - **Impact:** Display capacity capped at 50
   - **Workaround:** ✅ Weight override = infinite effective storage

2. **Transfer Speed**
   - **Cause:** Java→Java internal calls in `Transaction.java`
   - **Impact:** Cannot speed up item transfer via Lua
   - **Workaround:** ❌ None available (Lua limitation)

3. **Trait Modification**
   - **Cause:** Traits locked at character creation
   - **Impact:** Cannot add/remove traits for bonuses
   - **Workaround:** ✅ Check traits, apply conditional effects

### What Works Perfectly

- ✅ **State-based upgrades** - No item recreation needed
- ✅ **Content preservation** - Items inside safe during upgrade
- ✅ **Zero weight** - `getWeight()` override works flawlessly
- ✅ **Anti-spoilage** - `setAge(0)` prevents rot
- ✅ **Persistence** - ModData saves correctly
- ✅ **Notifications** - HaloTextHelper integration

---

## 🚀 Future Enhancement Ideas

### Tier-Based Visual Effects
```lua
-- Display tier in item name/tooltip
function InventoryItem.getDisplayName(self)
    if self:getType() == "SpatialSack" then
        local tier = self:getModData().enchantLevel or 0
        return "Spatial Sack [Tier " .. tier .. "]"
    end
end
```

### Specialized Enchantments
- **Food Preservation Branch** - Extra anti-spoilage features
- **Tool Durability Branch** - Auto-repair items inside
- **Organization Branch** - Auto-sort by item type

### Multiple Sack Types
- **Spatial Pouch** - Smaller, easier to craft
- **Spatial Chest** - Stationary, larger capacity
- **Spatial Ring** - Wearable accessory version

### Enchantment Requirements
- Add skill requirements (Tailoring 5 for Tier 3+)
- Require workbench for higher tiers
- Add time-based enchantment (ritual takes 10 minutes)

### Visual Polish
- Different sprites per tier
- Glow effect on max tier
- Particle effects during enchantment

### Multiplayer Features
- Sack ownership tracking
- Trade restrictions for high-tier sacks
- Guild/clan shared storage

---

## 📋 Complete File List

**Item Scripts:**
- `media/scripts/item_MagicalCore.txt` ✅
- `media/scripts/item_SpatialSack.txt` ✅
- `media/scripts/recipe_SpatialSack.txt` ✅

**Lua Scripts:**
- `media/lua/client/SpatialSackMain.lua` ✅
- `media/lua/client/SpatialSackWeight.lua` ✅
- `media/lua/client/SpatialSackEnchant.lua` ✅
- `media/lua/server/SpatialSackServer.lua` ✅
- `media/lua/shared/SpatialSackLoot.lua` ✅
- `media/lua/shared/SpatialSackRecipe.lua` ✅

---

## 🧪 Testing Checklist

### Basic Functionality
- [x] Mod loads without errors
- [x] Strange Zombie Cores drop from zombies
- [x] Crafting recipe works
- [x] Initial capacity is 10 units
- [x] Items weigh 0 inside sack
- [x] Food doesn't spoil inside

### Progression System
- [x] Tier 0 → 1 enchantment works
- [x] Tier 1 → 2 enchantment works
- [x] Tier 2 → 3 enchantment works
- [x] Tier 3 → 4 enchantment works
- [x] Max tier shows "Max Enchantment Reached"
- [x] Items inside preserved during upgrade
- [x] Capacity increases correctly

### Notifications
- [x] Crafting shows green text
- [x] Enchanting shows green text with arrows
- [x] Failure shows red text
- [x] Tooltip shows core count

### Edge Cases
- [x] Cannot enchant without cores
- [x] Cannot enchant beyond tier 4
- [x] ModData persists across saves
- [x] Debug mode logging works

---

## 🎯 Summary

The Spatial Sack Progression System is a complete, polished implementation that:

1. **Provides meaningful progression** - 5 tiers over ~103 zombie kills
2. **Maintains game balance** - Gradual capacity increase
3. **Uses state-based upgrades** - No item recreation bugs
4. **Preserves player investment** - Items safe during upgrades
5. **Professional feedback** - Green text like skill level-ups
6. **Fully persistent** - ModData saves correctly
7. **Easily tunable** - Drop rates and costs configurable

**This system maximizes what's possible within Project Zomboid's Lua modding capabilities while maintaining professional quality and game balance.**

---

*Last Updated: After full implementation with HaloTextHelper integration and 30% drop rate*
*Ready for: Further feature additions, balance tuning, visual polish*
