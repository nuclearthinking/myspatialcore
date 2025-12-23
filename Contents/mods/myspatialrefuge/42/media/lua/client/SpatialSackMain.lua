local SpatialSack = {}

-- Load weight override module
SpatialSack.weightHandler = require "SpatialSackWeight"

-- Load enchantment system
require "SpatialSackEnchant"

-- Load cultivation technique system
require "techniques/TechniqueSystem"
require "techniques/TechniqueItems"

-- Load technique UI
require "ui/TechniqueKeybinds"
require "ui/TechniqueUI"
require "ui/TechniqueSidebar"

-- Load Spatial Refuge system (order matters!)
require "shared/SpatialRefugeConfig"           -- 1. Config first
require "client/refuge/SpatialRefugeMain"      -- 2. Core module
require "client/refuge/SpatialRefugeGeneration" -- 3. World generation
require "client/refuge/SpatialRefugeTeleport"  -- 4. Teleportation

-- Load timed action classes BEFORE the cast system that uses them
require "client/refuge/ISEnterRefugeAction"    -- 5. Timed action for entry
require "client/refuge/ISExitRefugeAction"     -- 6. Timed action for exit
require "client/refuge/SpatialRefugeCast"      -- 7. Cast time system (uses timed actions)

require "client/refuge/SpatialRefugeContext"   -- 8. Context menu
require "client/refuge/SpatialRefugeUpgrade"   -- 9. Upgrades
require "client/refuge/SpatialRefugeDeath"     -- 10. Death handling
require "client/refuge/SpatialRefugeBoundary"  -- 11. Boundary enforcement
require "client/refuge/SpatialRefugeRadialMenu" -- 12. Radial menu
require "client/refuge/SpatialRefugeKeybind"   -- 13. Main keybind (H key)

-- Verify modules loaded
print("[SpatialSack] ============ Spatial Refuge Module Verification ============")
print("[SpatialSack] SpatialRefugeConfig exists: " .. tostring(SpatialRefugeConfig ~= nil))
print("[SpatialSack] SpatialRefuge exists: " .. tostring(SpatialRefuge ~= nil))
if SpatialRefuge then
    print("[SpatialSack] SpatialRefuge.CanEnterRefuge exists: " .. tostring(SpatialRefuge.CanEnterRefuge ~= nil))
    print("[SpatialSack] SpatialRefuge.IsPlayerInRefuge exists: " .. tostring(SpatialRefuge.IsPlayerInRefuge ~= nil))
    print("[SpatialSack] SpatialRefuge.GetLastTeleportTime exists: " .. tostring(SpatialRefuge.GetLastTeleportTime ~= nil))
    print("[SpatialSack] SpatialRefuge.BeginTeleportCast exists: " .. tostring(SpatialRefuge.BeginTeleportCast ~= nil))
end
print("[SpatialSack] ISEnterRefugeAction exists: " .. tostring(ISEnterRefugeAction ~= nil))
print("[SpatialSack] ISExitRefugeAction exists: " .. tostring(ISExitRefugeAction ~= nil))
print("[SpatialSack] ISTimedActionQueue exists: " .. tostring(ISTimedActionQueue ~= nil))
print("[SpatialSack] ISBaseTimedAction exists: " .. tostring(ISBaseTimedAction ~= nil))
print("[SpatialSack] ============================================================")

-- Initialize weight override on game boot
function SpatialSack.onGameBoot()
    SpatialSack.weightHandler.overrideWeightCalculation()
end

-- Re-initialize on game load
function SpatialSack.onLoad()
    SpatialSack.weightHandler.overrideWeightCalculation()
end

-- Reset age of items inside SpatialSack to prevent spoilage (runs every 10 minutes)
function SpatialSack.preventSpoilage()
    local player = getPlayer()
    if not player then return end
    
    local inv = player:getInventory()
    if not inv then return end
    
    local itemsReset = 0
    local debugMode = getDebug()
    
    -- Check all items in inventory for SpatialSack
    local items = inv:getItems()
    if items then
        for i = 0, items:size() - 1 do
            local item = items:get(i)
            if item and item:getType() == "SpatialSack" then
                -- Get the container inside the SpatialSack
                local container = item:getItemContainer()
                if container then
                    local containerItems = container:getItems()
                    if containerItems then
                        -- Reset age for all items that can age
                        for j = 0, containerItems:size() - 1 do
                            local containerItem = containerItems:get(j)
                            if containerItem then
                                local offAge = containerItem:getOffAge()
                                if offAge and offAge < 1000000000 then
                                    local oldAge = containerItem:getAge()
                                    containerItem:setAge(0)
                                    itemsReset = itemsReset + 1
                                    
                                    if debugMode and oldAge > 0 then
                                        print("[SpatialSack] Reset " .. containerItem:getDisplayName() .. " age: " .. string.format("%.2f", oldAge) .. " -> 0")
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    -- Always log when function runs (even if no items reset)
    if debugMode then
        print("[SpatialSack] Anti-spoilage check: " .. itemsReset .. " items protected")
    end
end

-- Register event hooks
Events.OnGameBoot.Add(SpatialSack.onGameBoot)
Events.OnLoad.Add(SpatialSack.onLoad)
Events.EveryTenMinutes.Add(SpatialSack.preventSpoilage)

return SpatialSack
