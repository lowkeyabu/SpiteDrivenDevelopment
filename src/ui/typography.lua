-- Named font sizes. Call typography.init() inside love.load() before drawing.
-- After init, typography.font(name) returns a love.graphics.Font.

local SIZES = {
  xs = 12,
  sm = 14,
  md = 18,
  lg = 24,
  xl = 36,
  display = 56,
}

local fonts = nil

local function init()
  fonts = {}
  for name, size in pairs(SIZES) do
    fonts[name] = love.graphics.newFont(size)
  end
end

local function font(name)
  assert(fonts, "typography.init() must be called inside love.load() before use")
  local f = fonts[name]
  assert(f, "unknown font size: " .. tostring(name))
  return f
end

-- Convenience: temporarily set the active font, run draw_fn, then restore.
local function with(name, draw_fn)
  local prev = love.graphics.getFont()
  love.graphics.setFont(font(name))
  draw_fn()
  love.graphics.setFont(prev)
end

return {
  init = init,
  font = font,
  with = with,
  SIZES = SIZES,
}
