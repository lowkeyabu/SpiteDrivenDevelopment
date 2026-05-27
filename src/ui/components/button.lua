-- Rectangular button with paper-card styling. Hit detection and click
-- handling are pure logic (testable with busted). Rendering uses
-- love.graphics and is verified manually.

local Button = {}
Button.__index = Button

local function noop() end

local function new(opts)
  return setmetatable({
    x = opts.x or 0,
    y = opts.y or 0,
    w = opts.w or 120,
    h = opts.h or 40,
    label = opts.label or "",
    font_size = opts.font_size or "md",
    on_click = opts.on_click or noop,
    hover = false,
    pressed = false,
  }, Button)
end

function Button:hit(px, py)
  return px >= self.x
     and py >= self.y
     and px < self.x + self.w
     and py < self.y + self.h
end

function Button:mousemoved(x, y)
  self.hover = self:hit(x, y)
end

function Button:mousepressed(x, y, btn)
  if btn == 1 and self:hit(x, y) then
    self.pressed = true
  end
end

function Button:mousereleased(x, y, btn)
  if btn ~= 1 then return end
  if self.pressed and self:hit(x, y) then
    self.on_click()
  end
  self.pressed = false
end

function Button:draw()
  if not (love and love.graphics) then return end

  -- Paper card with a 1px dark border. Hover lightens the fill; pressed darkens.
  local fill_r, fill_g, fill_b = 1, 1, 1
  if self.pressed then
    fill_r, fill_g, fill_b = 0.86, 0.84, 0.78
  elseif self.hover then
    fill_r, fill_g, fill_b = 0.99, 0.97, 0.91
  end

  love.graphics.setColor(fill_r, fill_g, fill_b)
  love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
  love.graphics.setColor(0.1, 0.1, 0.1)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", self.x, self.y, self.w, self.h)

  -- Label
  local typography = require("src.ui.typography")
  typography.with(self.font_size, function()
    love.graphics.setColor(0.1, 0.1, 0.1)
    local font = love.graphics.getFont()
    local tw = font:getWidth(self.label)
    local th = font:getHeight()
    love.graphics.print(self.label,
      self.x + (self.w - tw) / 2,
      self.y + (self.h - th) / 2)
  end)
end

return {
  new = new,
}
