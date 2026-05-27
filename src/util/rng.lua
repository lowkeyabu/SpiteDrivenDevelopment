-- Seedable RNG. Uses Love2D's RandomGenerator at runtime (good distribution,
-- per-instance state) and falls back to a small Lua-only generator under
-- busted so tests can run without a Love runtime.

local RNG = {}
RNG.__index = RNG

local has_love = type(love) == "table" and love.math and love.math.newRandomGenerator

local function lua_generator(seed)
  -- Linear congruential generator. Good enough for shuffles, not for crypto.
  -- Constants from Numerical Recipes.
  local state = seed % 2147483647
  if state == 0 then state = 1 end
  return {
    random = function()
      state = (state * 1103515245 + 12345) % 2147483648
      return state / 2147483648
    end,
  }
end

local function new(seed)
  seed = seed or os.time()
  local backend
  if has_love then
    backend = love.math.newRandomGenerator(seed)
  else
    backend = lua_generator(seed)
  end
  return setmetatable({ _backend = backend }, RNG)
end

-- random()             -> float in [0, 1)
-- random(max)          -> integer in [1, max]
-- random(min, max)     -> integer in [min, max]
function RNG:random(a, b)
  local r = self._backend:random()
  if a == nil then return r end
  if b == nil then
    return math.floor(r * a) + 1
  end
  return math.floor(r * (b - a + 1)) + a
end

function RNG:shuffle(list)
  -- Fisher-Yates, in place, returns the same list for chaining.
  for i = #list, 2, -1 do
    local j = self:random(1, i)
    list[i], list[j] = list[j], list[i]
  end
  return list
end

return {
  new = new,
}
