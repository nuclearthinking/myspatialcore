-- LuaCompat.lua
-- Compatibility layer for Kahlua (Project Zomboid's Lua environment)
-- Provides missing or limited Lua standard library functions

local LuaCompat = {}

--- Check if table has any keys (replaces standard Lua's next() function)
--- Kahlua doesn't have next() built-in, so we use pairs() iterator
---@param t table|nil Table to check
---@return boolean hasKeys True if table has at least one key
function LuaCompat.hasKeys(t)
    if not t then return false end
    for _ in pairs(t) do
        return true
    end
    return false
end

--- Count number of keys in a table
--- Useful since Kahlua doesn't have table.getn() for hash tables
---@param t table|nil Table to count
---@return number count Number of keys in table
function LuaCompat.countKeys(t)
    if not t then return 0 end
    local count = 0
    for _ in pairs(t) do
        count = count + 1
    end
    return count
end

--- Deep copy a table (handles nested tables)
--- Prevents reference sharing issues
---@param orig table|any Original value to copy
---@param copies table|nil Internal cache for circular reference handling
---@return any copy Deep copy of the original
function LuaCompat.deepCopy(orig, copies)
    copies = copies or {}
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        if copies[orig] then
            copy = copies[orig]
        else
            copy = {}
            copies[orig] = copy
            for orig_key, orig_value in pairs(orig) do
                copy[LuaCompat.deepCopy(orig_key, copies)] = LuaCompat.deepCopy(orig_value, copies)
            end
            setmetatable(copy, LuaCompat.deepCopy(getmetatable(orig), copies))
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

--- Shallow copy a table (only copies first level)
---@param t table Table to copy
---@return table copy Shallow copy of table
function LuaCompat.shallowCopy(t)
    if not t then return {} end
    local copy = {}
    for k, v in pairs(t) do
        copy[k] = v
    end
    return copy
end

--- Check if table is empty (no keys)
---@param t table|nil Table to check
---@return boolean isEmpty True if table has no keys
function LuaCompat.isEmpty(t)
    return not LuaCompat.hasKeys(t)
end

--- Safe string format that handles nil values
--- Kahlua's string.format can be finicky with nil
---@param fmt string Format string
---@param ... any Values to format
---@return string formatted Formatted string
function LuaCompat.safeFormat(fmt, ...)
    local args = {...}
    for i = 1, #args do
        if args[i] == nil then
            args[i] = "nil"
        end
    end
    return string.format(fmt, unpack(args))
end

--- Clamp a number between min and max
---@param value number Value to clamp
---@param min number Minimum value
---@param max number Maximum value
---@return number clamped Clamped value
function LuaCompat.clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

--- Round a number to specified decimal places
---@param value number Value to round
---@param decimals number|nil Number of decimal places (default: 0)
---@return number rounded Rounded value
function LuaCompat.round(value, decimals)
    decimals = decimals or 0
    local mult = 10 ^ decimals
    return math.floor(value * mult + 0.5) / mult
end

--- Check if value is NaN (Not a Number)
---@param value any Value to check
---@return boolean isNaN True if value is NaN
function LuaCompat.isNaN(value)
    return type(value) == "number" and value ~= value
end

--- Check if value is infinite
---@param value any Value to check
---@return boolean isInfinite True if value is infinite
function LuaCompat.isInfinite(value)
    return type(value) == "number" and (value == math.huge or value == -math.huge)
end

--- Safe table access with default value
--- Returns default if key doesn't exist or value is nil
---@param t table Table to access
---@param key any Key to lookup
---@param default any Default value if key not found
---@return any value Value at key or default
function LuaCompat.getOrDefault(t, key, default)
    if not t then return default end
    local value = t[key]
    if value == nil then return default end
    return value
end

--==============================================================================
-- TIMING UTILITIES (Kahlua Compatibility Notes)
--==============================================================================
-- Kahlua does NOT support standard Lua os.clock() or os.time()
-- Use Project Zomboid's built-in timing functions instead:
--
-- ✅ getTimestampMs() - Returns current timestamp in milliseconds
-- ✅ UIManager.getMillisSinceLastRender() - Milliseconds since last frame
-- ✅ Calendar.getInstance():getTimeInMillis() - Java calendar time
--
-- ❌ DO NOT USE: os.time(), os.clock(), os.date()
--
-- Example:
--   local startTime = getTimestampMs()
--   -- do work
--   local elapsed = getTimestampMs() - startTime
--   print("Took " .. elapsed .. "ms")
--==============================================================================

print("[LuaCompat] Kahlua compatibility utilities loaded")

return LuaCompat

