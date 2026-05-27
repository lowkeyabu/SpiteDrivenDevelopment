local Button = require("src.ui.components.button")
local ColorPicker = require("src.ui.components.color_picker")
local Session = require("src.game.session")
local TextInput = require("src.ui.components.text_input")
local typography = require("src.ui.typography")

local M = {}
M.__index = M

local CONTENT_W = 760
local ROW_H = 56
local ROW_GAP = 12
local NAME_LABEL_W = 80
local NAME_INPUT_W = 280

local function build_layout(self, w, h)
  local session = self.session
  local x = (w - CONTENT_W) / 2
  local y0 = 132

  self.rows = {}

  for i, player in ipairs(session.players) do
    local row_y = y0 + (i - 1) * (ROW_H + ROW_GAP)
    local input_y = row_y + (ROW_H - 32) / 2
    local picker_y = row_y + (ROW_H - 28) / 2

    local idx = i
    local name_input = TextInput.new({
      x = x + NAME_LABEL_W,
      y = input_y,
      w = NAME_INPUT_W,
      h = 32,
      value = player.name,
      max_length = 20,
      on_change = function(v) session:set_player_name(idx, v) end,
    })

    local picker = ColorPicker.new({
      x = x + NAME_LABEL_W + NAME_INPUT_W + 32,
      y = picker_y,
      swatch_size = 28,
      gap = 6,
      palette = Session.PLAYER_PALETTE,
      value = player.color,
      on_change = function(v) session:set_player_color(idx, v) end,
    })

    table.insert(self.rows, {
      player_idx = i,
      y = row_y,
      name_input = name_input,
      color_picker = picker,
    })
  end

  local fsm = self.fsm
  self.back_button = Button.new({
    x = 32, y = h - 64, w = 120, h = 40,
    label = "Back",
    on_click = function() fsm:transition("config") end,
  })
  self.start_button = Button.new({
    x = w - 32 - 200, y = h - 64, w = 200, h = 40,
    label = "Start Game →",
    on_click = function() fsm:transition("game") end,
  })
end

local function new(deps)
  return setmetatable({
    fsm = deps.fsm,
    session = deps.session,
  }, M)
end

function M:enter()
  build_layout(self, love.graphics.getWidth(), love.graphics.getHeight())
end

function M:resize(w, h)
  build_layout(self, w, h)
end

function M:draw()
  local w = love.graphics.getWidth()
  local x = (w - CONTENT_W) / 2

  typography.with("xl", function()
    love.graphics.setColor(0.1, 0.1, 0.1)
    local font = love.graphics.getFont()
    local title = "Set Up Players"
    local tw = font:getWidth(title)
    love.graphics.print(title, (w - tw) / 2, 36)
  end)

  typography.with("sm", function()
    love.graphics.setColor(0.45, 0.45, 0.45)
    local subtitle = "Pick a name and stick-figure color for each player."
    local font = love.graphics.getFont()
    local sw = font:getWidth(subtitle)
    love.graphics.print(subtitle, (w - sw) / 2, 78)
  end)

  for _, row in ipairs(self.rows) do
    typography.with("md", function()
      love.graphics.setColor(0.2, 0.2, 0.2)
      love.graphics.print("P" .. tostring(row.player_idx), x, row.y + (ROW_H - 18) / 2)
    end)
    row.name_input:draw()
    row.color_picker:draw()
  end

  self.back_button:draw()
  self.start_button:draw()
end

local function each_input(self, fn)
  for _, row in ipairs(self.rows) do
    fn(row.name_input)
    fn(row.color_picker)
  end
  fn(self.back_button)
  fn(self.start_button)
end

function M:mousemoved(x, y)
  each_input(self, function(w)
    if w.mousemoved then w:mousemoved(x, y) end
  end)
end

function M:mousepressed(x, y, btn)
  each_input(self, function(w)
    if w.mousepressed then w:mousepressed(x, y, btn) end
  end)
end

function M:mousereleased(x, y, btn)
  each_input(self, function(w)
    if w.mousereleased then w:mousereleased(x, y, btn) end
  end)
end

function M:textinput(text)
  for _, row in ipairs(self.rows) do
    if row.name_input.focused then
      row.name_input:textinput(text)
      return
    end
  end
end

function M:keypressed(key)
  for _, row in ipairs(self.rows) do
    if row.name_input.focused then
      row.name_input:keypressed(key)
      return
    end
  end
  if key == "escape" then
    self.fsm:transition("config")
  elseif key == "return" then
    self.fsm:transition("game")
  end
end

return {
  new = new,
}
