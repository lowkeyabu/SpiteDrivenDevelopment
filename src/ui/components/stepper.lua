-- Integer Stepper: minus plate on the left, value display in the middle,
-- plus plate on the right. Each plate is the full height of the widget
-- and 40px wide.

local Stepper = {}
Stepper.__index = Stepper

local PLATE_W = 40

local function noop() end

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function new(opts)
  local min = opts.min or 0
  local max = opts.max or 10
  return setmetatable({
    x = opts.x or 0,
    y = opts.y or 0,
    w = opts.w or 240,
    h = opts.h or 40,
    min = min,
    max = max,
    value = clamp(opts.value or 0, min, max),
    label = opts.label or "",
    on_change = opts.on_change or noop,
    _press_zone = nil,
  }, Stepper)
end

function Stepper:get_value()
  return self.value
end

function Stepper:set_value(v)
  local clamped = clamp(v, self.min, self.max)
  if clamped ~= self.value then
    self.value = clamped
    self.on_change(self.value)
  else
    self.value = clamped
  end
end

local function in_rect(px, py, x, y, w, h)
  return px >= x and py >= y and px < x + w and py < y + h
end

function Stepper:_zone_at(px, py)
  if not in_rect(px, py, self.x, self.y, self.w, self.h) then return nil end
  if px < self.x + PLATE_W then return "minus" end
  if px >= self.x + self.w - PLATE_W then return "plus" end
  return nil
end

function Stepper:mousepressed(x, y, btn)
  if btn ~= 1 then return end
  self._press_zone = self:_zone_at(x, y)
end

function Stepper:mousereleased(x, y, btn)
  if btn ~= 1 then return end
  local release_zone = self:_zone_at(x, y)
  if self._press_zone and self._press_zone == release_zone then
    if release_zone == "minus" then
      self:set_value(self.value - 1)
    else
      self:set_value(self.value + 1)
    end
  end
  self._press_zone = nil
end

function Stepper:mousemoved(x, y) end

function Stepper:draw()
  if not (love and love.graphics) then return end
  local typography = require("src.ui.typography")

  love.graphics.setColor(1, 1, 1)
  love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
  love.graphics.setColor(0.1, 0.1, 0.1)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", self.x, self.y, self.w, self.h)

  love.graphics.line(self.x + PLATE_W, self.y,
                     self.x + PLATE_W, self.y + self.h)
  love.graphics.line(self.x + self.w - PLATE_W, self.y,
                     self.x + self.w - PLATE_W, self.y + self.h)

  typography.with("lg", function()
    love.graphics.setColor(0.1, 0.1, 0.1)
    local font = love.graphics.getFont()
    local minus, plus = "-", "+"
    local mw = font:getWidth(minus)
    local pw = font:getWidth(plus)
    local fh = font:getHeight()
    love.graphics.print(minus,
      self.x + (PLATE_W - mw) / 2,
      self.y + (self.h - fh) / 2)
    love.graphics.print(plus,
      self.x + self.w - PLATE_W + (PLATE_W - pw) / 2,
      self.y + (self.h - fh) / 2)
  end)

  typography.with("md", function()
    love.graphics.setColor(0.2, 0.2, 0.2)
    local font = love.graphics.getFont()
    local v = tostring(self.value)
    local vw = font:getWidth(v)
    local fh = font:getHeight()
    love.graphics.print(v,
      self.x + (self.w - vw) / 2,
      self.y + (self.h - fh) / 2)
  end)
end

return {
  new = new,
}
