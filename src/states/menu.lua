local Button = require("src.ui.components.button")
local typography = require("src.ui.typography")

local M = {}
M.__index = M

local function build_buttons(self, w, h)
  local btn_w, btn_h = 320, 56
  local cx = (w - btn_w) / 2
  local cy = h / 2 + 20

  local fsm = self.fsm
  self.buttons = {
    Button.new({
      x = cx, y = cy, w = btn_w, h = btn_h,
      label = "New Game",
      on_click = function() fsm:transition("mode_select") end,
    }),
    Button.new({
      x = cx, y = cy + btn_h + 16, w = btn_w, h = btn_h,
      label = "Quit",
      on_click = function() love.event.quit() end,
    }),
  }
end

local function new(deps)
  return setmetatable({
    fsm = deps.fsm,
    session = deps.session,
  }, M)
end

function M:enter()
  build_buttons(self, love.graphics.getWidth(), love.graphics.getHeight())
end

function M:resize(w, h)
  build_buttons(self, w, h)
end

function M:draw()
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()

  typography.with("display", function()
    love.graphics.setColor(0.1, 0.1, 0.1)
    local font = love.graphics.getFont()
    local title = "Spite Driven Development"
    local tw = font:getWidth(title)
    love.graphics.print(title, (w - tw) / 2, h / 4)
  end)

  typography.with("md", function()
    love.graphics.setColor(0.3, 0.3, 0.3)
    local font = love.graphics.getFont()
    local sub = "a parody boardgame"
    local sw = font:getWidth(sub)
    love.graphics.print(sub, (w - sw) / 2, h / 4 + 70)
  end)

  for _, b in ipairs(self.buttons) do b:draw() end
end

function M:mousemoved(x, y)
  for _, b in ipairs(self.buttons) do b:mousemoved(x, y) end
end

function M:mousepressed(x, y, btn)
  for _, b in ipairs(self.buttons) do b:mousepressed(x, y, btn) end
end

function M:mousereleased(x, y, btn)
  for _, b in ipairs(self.buttons) do b:mousereleased(x, y, btn) end
end

function M:keypressed(key)
  if key == "escape" then
    love.event.quit()
  elseif key == "return" then
    self.fsm:transition("mode_select")
  end
end

return {
  new = new,
}
