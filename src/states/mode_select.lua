local Button = require("src.ui.components.button")
local Session = require("src.game.session")
local typography = require("src.ui.typography")

local M = {}
M.__index = M

local CARD_W, CARD_H, CARD_GAP = 760, 84, 16

local function build_layout(self, w, h)
  self.buttons = {}
  self.deferred_cards = {}

  local total_h = #Session.MODES * (CARD_H + CARD_GAP) - CARD_GAP
  local x = (w - CARD_W) / 2
  local y0 = (h - total_h) / 2

  local fsm, session = self.fsm, self.session

  for i, mode in ipairs(Session.MODES) do
    local y = y0 + (i - 1) * (CARD_H + CARD_GAP)
    if mode.available then
      table.insert(self.buttons, Button.new({
        x = x, y = y, w = CARD_W, h = CARD_H,
        label = mode.label,
        font_size = "lg",
        on_click = function()
          session:set_mode(mode.id)
          if mode.id == "sprint_tutorial" then
            session.config.tutorial_mode = true
            session:set_player_count(1)
            session:set_player_name(1, "You")
            fsm:transition("game")
          else
            fsm:transition("config")
          end
        end,
      }))
    else
      table.insert(self.deferred_cards, {
        x = x, y = y, w = CARD_W, h = CARD_H,
        label = mode.label,
        blurb = mode.blurb,
      })
    end
  end

  -- Back button bottom-left
  self.back_button = Button.new({
    x = 32, y = h - 64, w = 120, h = 40,
    label = "Back",
    on_click = function() fsm:transition("menu") end,
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

  typography.with("xl", function()
    love.graphics.setColor(0.1, 0.1, 0.1)
    local font = love.graphics.getFont()
    local title = "Pick a Mode"
    local tw = font:getWidth(title)
    love.graphics.print(title, (w - tw) / 2, 48)
  end)

  -- Active mode buttons
  for _, b in ipairs(self.buttons) do b:draw() end

  -- Deferred mode cards (flat plates with Coming Soon)
  for _, c in ipairs(self.deferred_cards) do
    love.graphics.setColor(0.92, 0.90, 0.82)
    love.graphics.rectangle("fill", c.x, c.y, c.w, c.h)
    love.graphics.setColor(0.55, 0.55, 0.55)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", c.x, c.y, c.w, c.h)

    typography.with("lg", function()
      love.graphics.setColor(0.4, 0.4, 0.4)
      love.graphics.print(c.label, c.x + 24, c.y + 14)
    end)
    typography.with("sm", function()
      love.graphics.setColor(0.5, 0.5, 0.5)
      love.graphics.print(c.blurb, c.x + 24, c.y + 50)
    end)
    typography.with("xs", function()
      love.graphics.setColor(0.6, 0.5, 0.3)
      local font = love.graphics.getFont()
      local label = "COMING SOON"
      local tw = font:getWidth(label)
      love.graphics.print(label, c.x + c.w - tw - 24, c.y + 14)
    end)
  end

  self.back_button:draw()
end

function M:mousemoved(x, y)
  for _, b in ipairs(self.buttons) do b:mousemoved(x, y) end
  self.back_button:mousemoved(x, y)
end

function M:mousepressed(x, y, btn)
  for _, b in ipairs(self.buttons) do b:mousepressed(x, y, btn) end
  self.back_button:mousepressed(x, y, btn)
end

function M:mousereleased(x, y, btn)
  for _, b in ipairs(self.buttons) do b:mousereleased(x, y, btn) end
  self.back_button:mousereleased(x, y, btn)
end

function M:keypressed(key)
  if key == "escape" then
    self.fsm:transition("menu")
  end
end

return {
  new = new,
}
