-- Boolean Toggle: click anywhere inside the widget to flip the value.
-- Label on the left, ON/OFF indicator on the right.

local Toggle = {}
Toggle.__index = Toggle

local function noop() end

local function new(opts)
  return setmetatable({
    x = opts.x or 0,
    y = opts.y or 0,
    w = opts.w or 240,
    h = opts.h or 40,
    value = opts.value or false,
    label = opts.label or "",
    on_change = opts.on_change or noop,
    _pressed = false,
  }, Toggle)
end

function Toggle:get_value()
  return self.value
end

function Toggle:set_value(v)
  v = v and true or false
  if v ~= self.value then
    self.value = v
    self.on_change(self.value)
  end
end

function Toggle:hit(px, py)
  return px >= self.x and py >= self.y
     and px < self.x + self.w and py < self.y + self.h
end

function Toggle:mousepressed(x, y, btn)
  if btn ~= 1 then return end
  if self:hit(x, y) then self._pressed = true end
end

function Toggle:mousereleased(x, y, btn)
  if btn ~= 1 then return end
  if self._pressed and self:hit(x, y) then
    self:set_value(not self.value)
  end
  self._pressed = false
end

function Toggle:mousemoved(x, y) end

function Toggle:draw()
  if not (love and love.graphics) then return end
  local typography = require("src.ui.typography")

  love.graphics.setColor(1, 1, 1)
  love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
  love.graphics.setColor(0.1, 0.1, 0.1)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", self.x, self.y, self.w, self.h)

  typography.with("md", function()
    love.graphics.setColor(0.1, 0.1, 0.1)
    local fh = love.graphics.getFont():getHeight()
    love.graphics.print(self.label, self.x + 12, self.y + (self.h - fh) / 2)
  end)

  local indicator_w = 64
  local ix = self.x + self.w - indicator_w - 8
  local iy = self.y + 6
  local ih = self.h - 12
  if self.value then
    love.graphics.setColor(0.2, 0.6, 0.3)
  else
    love.graphics.setColor(0.6, 0.6, 0.6)
  end
  love.graphics.rectangle("fill", ix, iy, indicator_w, ih)
  love.graphics.setColor(0.1, 0.1, 0.1)
  love.graphics.rectangle("line", ix, iy, indicator_w, ih)

  typography.with("sm", function()
    love.graphics.setColor(1, 1, 1)
    local font = love.graphics.getFont()
    local text = self.value and "ON" or "OFF"
    local tw = font:getWidth(text)
    local fh = font:getHeight()
    love.graphics.print(text,
      ix + (indicator_w - tw) / 2,
      iy + (ih - fh) / 2)
  end)
end

return {
  new = new,
}
