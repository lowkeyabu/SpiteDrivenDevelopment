-- Vertical RadioGroup: each option is a row of fixed height. Click a
-- row to select the corresponding option id.

local RadioGroup = {}
RadioGroup.__index = RadioGroup

local function noop() end

local function find_index(options, id)
  for i, o in ipairs(options) do
    if o.id == id then return i end
  end
  return nil
end

local function new(opts)
  local options = opts.options
  assert(type(options) == "table" and #options >= 1,
    "RadioGroup requires at least one option")
  local value = opts.value or options[1].id
  assert(find_index(options, value), "value not in options: " .. tostring(value))
  return setmetatable({
    x = opts.x or 0,
    y = opts.y or 0,
    w = opts.w or 320,
    row_h = opts.row_h or 32,
    options = options,
    value = value,
    label = opts.label or "",
    on_change = opts.on_change or noop,
    _press_row = nil,
  }, RadioGroup)
end

function RadioGroup:get_value()
  return self.value
end

function RadioGroup:set_value(id)
  assert(find_index(self.options, id), "unknown option id: " .. tostring(id))
  if id ~= self.value then
    self.value = id
    self.on_change(self.value)
  end
end

function RadioGroup:_row_at(px, py)
  if px < self.x or px >= self.x + self.w then return nil end
  local rel_y = py - self.y
  if rel_y < 0 then return nil end
  local idx = math.floor(rel_y / self.row_h) + 1
  if idx >= 1 and idx <= #self.options then return idx end
  return nil
end

function RadioGroup:mousepressed(x, y, btn)
  if btn ~= 1 then return end
  self._press_row = self:_row_at(x, y)
end

function RadioGroup:mousereleased(x, y, btn)
  if btn ~= 1 then return end
  local release_row = self:_row_at(x, y)
  if self._press_row and self._press_row == release_row then
    self:set_value(self.options[release_row].id)
  end
  self._press_row = nil
end

function RadioGroup:mousemoved(x, y) end

function RadioGroup:height()
  return #self.options * self.row_h
end

function RadioGroup:draw()
  if not (love and love.graphics) then return end
  local typography = require("src.ui.typography")

  for i, opt in ipairs(self.options) do
    local row_y = self.y + (i - 1) * self.row_h
    local is_selected = (opt.id == self.value)

    local cx = self.x + 16
    local cy = row_y + self.row_h / 2
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", cx, cy, 8)
    if is_selected then
      love.graphics.setColor(0.1, 0.1, 0.1)
      love.graphics.circle("fill", cx, cy, 4)
    end

    typography.with("md", function()
      love.graphics.setColor(0.1, 0.1, 0.1)
      local fh = love.graphics.getFont():getHeight()
      love.graphics.print(opt.label, self.x + 34, row_y + (self.row_h - fh) / 2)
    end)
  end
end

return {
  new = new,
}
