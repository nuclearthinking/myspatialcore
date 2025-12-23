-- TechniqueKeybinds.lua
-- Registers keybinds for the Technique System

local function registerKeybinds()
    -- Create keybind category if it doesn't exist
    local keyBinding = {
        name = "Toggle Technique Panel",
        key = Keyboard.KEY_K,  -- Default: K key
    }
    
    -- Only add if not already registered
    if not getCore():getKey(keyBinding.name) then
        getCore():addKeyBinding(keyBinding.name, keyBinding.key)
    end
    
    print("[TechniqueKeybinds] Keybinds registered")
end

-- Register on game start
Events.OnGameStart.Add(registerKeybinds)

return {}






