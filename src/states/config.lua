local Button = require("src.ui.components.button")
local RadioGroup = require("src.ui.components.radio_group")
local Session = require("src.game.session")
local Stepper = require("src.ui.components.stepper")
local TextInput = require("src.ui.components.text_input")
local Toggle = require("src.ui.components.toggle")
local typography = require("src.ui.typography")

local M = {}
M.__index = M

local CONTENT_W = 760
local ROW_H = 56
local ROW_GAP = 12
local LABEL_W = 240

local PRESETS = {
  "MegaCorp", "Axiom Inc.", "Hypercorp", "Globodyne Synthetics",
  "Latent", "Prompt Industries", "NullPointer Inc.", "Agentic", "VibeStack",
}

local function build_layout(self, w, h)
  local config = self.session.config
  local x_label = (w - CONTENT_W) / 2
  local x_widget = x_label + LABEL_W
  local widget_w = CONTENT_W - LABEL_W
  local y = 96

  self.rows = {}
  self.widgets = {}
  self.preset_buttons = {}

  local function add_row(label, widget)
    table.insert(self.rows, { y = y, label = label })
    table.insert(self.widgets, widget)
    y = y + ROW_H + ROW_GAP
  end

  local company_input = TextInput.new({
    x = x_widget, y = y + (ROW_H - 32) / 2,
    w = widget_w, h = 32,
    value = config.company_name,
    max_length = 24,
    on_change = function(v) self.session:set_config("company_name", v) end,
  })
  self._company_input = company_input
  add_row("Company name", company_input)

  local preset_y = y
  local cx = x_widget
  for _, name in ipairs(PRESETS) do
    -- Coarse width estimate so we can lay out preset chips at construction
    -- time without measuring with love.graphics. Slightly generous; xs-font
    -- characters average ~6-8px wide, so 16 (padding) + 8 * len works.
    local btn_w = 16 + 8 * #name
    if cx + btn_w > x_widget + widget_w then
      cx = x_widget
      preset_y = preset_y + 32
    end
    local btn = Button.new({
      x = cx, y = preset_y, w = btn_w, h = 28,
      label = name,
      font_size = "xs",
      on_click = function()
        company_input:set_value(name)
      end,
    })
    table.insert(self.preset_buttons, btn)
    cx = cx + btn_w + 6
  end
  y = preset_y + 32 + ROW_GAP

  add_row("Player count", Stepper.new({
    x = x_widget, y = y + (ROW_H - 40) / 2,
    w = 240, h = 40,
    value = config.player_count, min = 2, max = 8,
    on_change = function(v) self.session:set_player_count(v) end,
  }))

  add_row("Action points per turn", Stepper.new({
    x = x_widget, y = y + (ROW_H - 40) / 2,
    w = 240, h = 40,
    value = config.ap_per_turn, min = 1, max = 5,
    on_change = function(v) self.session:set_config("ap_per_turn", v) end,
  }))

  local end_options = {}
  for _, t in ipairs(Session.END_TRIGGERS) do
    table.insert(end_options, { id = t.id, label = t.label })
  end
  local end_rg = RadioGroup.new({
    x = x_widget, y = y,
    w = widget_w,
    row_h = 28,
    options = end_options,
    value = config.end_trigger,
    on_change = function(id) self.session:set_config("end_trigger", id) end,
  })
  table.insert(self.rows, { y = y, label = "End trigger" })
  table.insert(self.widgets, end_rg)
  y = y + end_rg:height() + ROW_GAP

  add_row("Comp target (when applicable)", Stepper.new({
    x = x_widget, y = y + (ROW_H - 40) / 2,
    w = 240, h = 40,
    value = config.comp_target, min = 10, max = 100,
    on_change = function(v) self.session:set_config("comp_target", v) end,
  }))

  add_row("Per-sprint turn cap", Stepper.new({
    x = x_widget, y = y + (ROW_H - 40) / 2,
    w = 240, h = 40,
    value = config.turn_cap, min = 4, max = 20,
    on_change = function(v) self.session:set_config("turn_cap", v) end,
  }))

  add_row("Sabotage tier-gating", Toggle.new({
    x = x_widget, y = y + (ROW_H - 40) / 2,
    w = 240, h = 40,
    value = config.tier_gating,
    on_change = function(v) self.session:set_config("tier_gating", v) end,
  }))

  local fsm = self.fsm
  self.back_button = Button.new({
    x = 32, y = h - 64, w = 120, h = 40,
    label = "Back",
    on_click = function() fsm:transition("mode_select") end,
  })
  self.continue_button = Button.new({
    x = w - 32 - 200, y = h - 64, w = 200, h = 40,
    label = "Continue →",
    on_click = function()
      self.session:set_player_count(self.session.config.player_count)
      fsm:transition("player_setup")
    end,
  })
end

local function new(deps)
  return setmetatable({
    fsm = deps.fsm,
    session = deps.session,
  }, M)
end

function M:enter()
  if #self.session.players == 0 then
    self.session:set_player_count(self.session.config.player_count)
  end
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
    local title = "Configure the Game"
    local tw = font:getWidth(title)
    love.graphics.print(title, (w - tw) / 2, 36)
  end)

  typography.with("md", function()
    love.graphics.setColor(0.2, 0.2, 0.2)
    local x_label = (w - CONTENT_W) / 2
    for _, row in ipairs(self.rows) do
      love.graphics.print(row.label, x_label, row.y + 12)
    end
  end)

  for _, widget in ipairs(self.widgets) do widget:draw() end
  for _, b in ipairs(self.preset_buttons) do b:draw() end
  self.back_button:draw()
  self.continue_button:draw()
end

local function each_input(self, fn)
  for _, w in ipairs(self.widgets) do fn(w) end
  for _, b in ipairs(self.preset_buttons) do fn(b) end
  fn(self.back_button)
  fn(self.continue_button)
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
  if self._company_input then self._company_input:textinput(text) end
end

function M:keypressed(key)
  if self._company_input and self._company_input.focused then
    self._company_input:keypressed(key)
    return
  end
  if key == "escape" then
    self.fsm:transition("mode_select")
  elseif key == "return" then
    self.session:set_player_count(self.session.config.player_count)
    self.fsm:transition("player_setup")
  end
end

return {
  new = new,
}
