-- Focus-based text input. Click inside to focus; click outside to
-- defocus. While focused, textinput(text) appends (capped at
-- max_length); keypressed("backspace") removes the last character;
-- keypressed("return") or ("escape") defocus.
--
-- Cursor is implicit (always at end) for v1. No selection, no arrow
-- keys, no copy/paste.

local TextInput = {}
TextInput.__index = TextInput

local function noop() end

local function new(opts)
  local max_length = opts.max_length or 24
  local value = opts.value or ""
  if #value > max_length then value = value:sub(1, max_length) end
  return setmetatable({
    x = opts.x or 0,
    y = opts.y or 0,
    w = opts.w or 240,
    h = opts.h or 32,
    value = value,
    max_length = max_length,
    label = opts.label or "",
    focused = false,
    on_change = opts.on_change or noop,
  }, TextInput)
end

function TextInput:get_value()
  return self.value
end

function TextInput:set_value(s)
  s = s or ""
  if #s > self.max_length then s = s:sub(1, self.max_length) end
  if s ~= self.value then
    self.value = s
    self.on_change(self.value)
  end
end

function TextInput:hit(px, py)
  return px >= self.x and py >= self.y
     and px < self.x + self.w and py < self.y + self.h
end

function TextInput:mousepressed(x, y, btn)
  if btn ~= 1 then return end
  self.focused = self:hit(x, y)
end

function TextInput:mousereleased(x, y, btn) end
function TextInput:mousemoved(x, y) end

function TextInput:textinput(text)
  if not self.focused then return end
  if #self.value >= self.max_length then return end
  local remaining = self.max_length - #self.value
  local addition = text:sub(1, remaining)
  if addition == "" then return end
  self.value = self.value .. addition
  self.on_change(self.value)
end

function TextInput:keypressed(key)
  if not self.focused then return end
  if key == "backspace" then
    if #self.value > 0 then
      self.value = self.value:sub(1, #self.value - 1)
      self.on_change(self.value)
    end
  elseif key == "return" or key == "escape" then
    self.focused = false
  end
end

function TextInput:draw()
  if not (love and love.graphics) then return end
  local typography = require("src.ui.typography")

  love.graphics.setColor(1, 1, 1)
  love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
  if self.focused then
    love.graphics.setColor(0.1, 0.4, 0.7)
    love.graphics.setLineWidth(2)
  else
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.setLineWidth(1)
  end
  love.graphics.rectangle("line", self.x, self.y, self.w, self.h)

  typography.with("md", function()
    love.graphics.setColor(0.1, 0.1, 0.1)
    local font = love.graphics.getFont()
    local fh = font:getHeight()
    local text = self.value
    love.graphics.print(text, self.x + 10, self.y + (self.h - fh) / 2)

    if self.focused then
      local tw = font:getWidth(text)
      love.graphics.setColor(0.1, 0.1, 0.1)
      love.graphics.setLineWidth(1)
      love.graphics.line(
        self.x + 10 + tw + 1, self.y + 6,
        self.x + 10 + tw + 1, self.y + self.h - 6)
    end
  end)
end

return {
  new = new,
}
