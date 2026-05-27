-- Horizontal row of color swatches. Click a swatch to select; value
-- is the 1-based index into the palette.

local ColorPicker = {}
ColorPicker.__index = ColorPicker

local function noop() end

local function new(opts)
  local palette = opts.palette
  assert(type(palette) == "table" and #palette >= 1,
    "ColorPicker requires a non-empty palette")
  local swatch = opts.swatch_size or 32
  local gap = opts.gap or 8
  local value = opts.value or 1
  assert(value >= 1 and value <= #palette,
    "ColorPicker value out of range")
  return setmetatable({
    x = opts.x or 0,
    y = opts.y or 0,
    swatch_size = swatch,
    gap = gap,
    palette = palette,
    value = value,
    on_change = opts.on_change or noop,
    _press_idx = nil,
  }, ColorPicker)
end

function ColorPicker:get_value()
  return self.value
end

function ColorPicker:set_value(idx)
  assert(idx >= 1 and idx <= #self.palette,
    "ColorPicker:set_value out of range: " .. tostring(idx))
  if idx ~= self.value then
    self.value = idx
    self.on_change(self.value)
  end
end

function ColorPicker:width()
  local n = #self.palette
  return n * self.swatch_size + (n - 1) * self.gap
end

function ColorPicker:_swatch_at(px, py)
  if py < self.y or py >= self.y + self.swatch_size then return nil end
  local rel = px - self.x
  if rel < 0 then return nil end
  local stride = self.swatch_size + self.gap
  local idx = math.floor(rel / stride) + 1
  if idx < 1 or idx > #self.palette then return nil end
  local within = rel - (idx - 1) * stride
  if within >= self.swatch_size then return nil end
  return idx
end

function ColorPicker:mousepressed(x, y, btn)
  if btn ~= 1 then return end
  self._press_idx = self:_swatch_at(x, y)
end

function ColorPicker:mousereleased(x, y, btn)
  if btn ~= 1 then return end
  local release_idx = self:_swatch_at(x, y)
  if self._press_idx and self._press_idx == release_idx then
    self:set_value(release_idx)
  end
  self._press_idx = nil
end

function ColorPicker:mousemoved(x, y) end

function ColorPicker:draw()
  if not (love and love.graphics) then return end
  local stride = self.swatch_size + self.gap
  for i, rgb in ipairs(self.palette) do
    local sx = self.x + (i - 1) * stride
    love.graphics.setColor(rgb[1], rgb[2], rgb[3])
    love.graphics.rectangle("fill", sx, self.y, self.swatch_size, self.swatch_size)
    if i == self.value then
      love.graphics.setColor(0.1, 0.1, 0.1)
      love.graphics.setLineWidth(3)
    else
      love.graphics.setColor(0.1, 0.1, 0.1)
      love.graphics.setLineWidth(1)
    end
    love.graphics.rectangle("line", sx, self.y, self.swatch_size, self.swatch_size)
  end
end

return {
  new = new,
}
