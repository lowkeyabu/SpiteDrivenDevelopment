local Button = require("src.ui.components.button")
local GameSession = require("src.game.game_session")
local KanbanView = require("src.ui.components.kanban_view")
local PlayerHUD = require("src.ui.components.player_hud")
local RNG = require("src.util.rng")
local typography = require("src.ui.typography")

local M = {}
M.__index = M

local BUTTON_BAR_H = 80
local TOP_BAR_H = 48
local HUD_W = 260
local HUD_GAP = 16

local function action_button(label, x, y, w, h, on_click)
  return Button.new({
    x = x, y = y, w = w, h = h,
    label = label,
    on_click = on_click,
  })
end

local function build_layout(self, w, h)
  local gs = self.game_session

  self.hud = PlayerHUD.new({
    x = 16, y = TOP_BAR_H + 8,
    w = HUD_W,
    game_session = gs,
  })

  local kanban_x = 16 + HUD_W + HUD_GAP
  self.kanban = KanbanView.new({
    x = kanban_x, y = TOP_BAR_H + 8,
    w = w - kanban_x - 16,
    h = h - TOP_BAR_H - BUTTON_BAR_H - 16,
    game_session = gs,
  })

  local fsm = self.fsm
  local kanban = self.kanban

  local function selected() return kanban:get_selected() end

  local btn_w, btn_h = 110, 40
  local total = 7 * btn_w + 6 * 8
  local bar_y = h - BUTTON_BAR_H + (BUTTON_BAR_H - btn_h) / 2
  local bx = (w - total) / 2

  self.action_buttons = {}

  local function add(label, on_click, predicate)
    local b = action_button(label, bx, bar_y, btn_w, btn_h, function()
      if predicate and not predicate() then return end
      on_click()
      if gs.ended then fsm:transition("end_screen") end
    end)
    b._predicate = predicate
    table.insert(self.action_buttons, b)
    bx = bx + btn_w + 8
  end

  local function actor_has_ap()
    return gs.players[gs.current_actor].ap > 0
  end

  add("Claim", function()
    local t = selected(); if t then gs:claim(t.id) end
  end, function()
    local t = selected()
    return t and t.column == "backlog" and actor_has_ap()
  end)

  add("Work", function()
    local t = selected(); if t then gs:work(t.id) end
  end, function()
    local t = selected()
    return t and t.column == "in_progress"
       and t.owner == gs.current_actor
       and t.points_remaining > 0
       and actor_has_ap()
  end)

  add("Submit", function()
    local t = selected(); if t then gs:submit_for_review(t.id) end
  end, function()
    local t = selected()
    return t and t.column == "in_progress"
       and t.owner == gs.current_actor
       and t.points_remaining == 0
       and actor_has_ap()
  end)

  add("Approve", function()
    local t = selected(); if t then gs:approve(t.id) end
  end, function()
    local t = selected()
    return t and t.column == "review"
       and t.owner ~= gs.current_actor
       and actor_has_ap()
  end)

  add("Reject", function()
    local t = selected(); if t then gs:reject(t.id) end
  end, function()
    local t = selected()
    return t and t.column == "review"
       and t.owner ~= gs.current_actor
       and actor_has_ap()
  end)

  add("End Turn", function()
    gs:end_turn()
    kanban.selected_id = nil
    while gs.sprint_phase == "retro" do
      gs:advance_phase()
    end
    if gs.ended then
      fsm:transition("end_screen")
    end
  end, function() return true end)

  add("End Game", function() fsm:transition("end_screen") end,
    function() return true end)
end

local function load_ticket_defs()
  return require("data.tickets")
end

local function new(deps)
  return setmetatable({
    fsm = deps.fsm,
    session = deps.session,
  }, M)
end

function M:enter()
  local existing = self.session:get_game_session()
  if existing then
    self.game_session = existing
  else
    self.game_session = GameSession.new({
      session = self.session,
      ticket_defs = load_ticket_defs(),
      rng = RNG.new(),
    })
    self.session:attach_game_session(self.game_session)
  end
  -- Start the first sprint (or resume mid-sprint if re-entering).
  if self.game_session.sprint_phase == "planning" then
    self.game_session:advance_phase()
  end
  build_layout(self, love.graphics.getWidth(), love.graphics.getHeight())
end

function M:resize(w, h)
  local prev_selected = self.kanban and self.kanban.selected_id
  build_layout(self, w, h)
  if prev_selected then self.kanban.selected_id = prev_selected end
end

function M:draw()
  local w = love.graphics.getWidth()
  local h = love.graphics.getHeight()

  love.graphics.setColor(0.92, 0.90, 0.82)
  love.graphics.rectangle("fill", 0, 0, w, TOP_BAR_H)
  love.graphics.setColor(0.1, 0.1, 0.1)
  love.graphics.setLineWidth(1)
  love.graphics.line(0, TOP_BAR_H, w, TOP_BAR_H)

  typography.with("md", function()
    love.graphics.setColor(0.1, 0.1, 0.1)
    local font = love.graphics.getFont()
    local company = self.session.config.company_name
    love.graphics.print(company, 16, (TOP_BAR_H - font:getHeight()) / 2)

    local gs = self.game_session
    local actor = gs.players[gs.current_actor]
    local right = string.format("Sprint %d  /  Turn %d  /  Shipped: %d  /  %s's turn",
      gs.sprint_number, gs.turn_count, gs:shipped_count(), actor.name)
    local rw = font:getWidth(right)
    love.graphics.print(right, w - rw - 16, (TOP_BAR_H - font:getHeight()) / 2)
  end)

  self.hud:draw()
  self.kanban:draw()

  love.graphics.setColor(0.92, 0.90, 0.82)
  love.graphics.rectangle("fill", 0, h - BUTTON_BAR_H, w, BUTTON_BAR_H)
  love.graphics.setColor(0.1, 0.1, 0.1)
  love.graphics.line(0, h - BUTTON_BAR_H, w, h - BUTTON_BAR_H)

  for _, b in ipairs(self.action_buttons) do
    local enabled = b._predicate == nil or b._predicate()
    if enabled then
      b:draw()
    else
      love.graphics.setColor(0.88, 0.86, 0.78)
      love.graphics.rectangle("fill", b.x, b.y, b.w, b.h)
      love.graphics.setColor(0.6, 0.6, 0.6)
      love.graphics.setLineWidth(1)
      love.graphics.rectangle("line", b.x, b.y, b.w, b.h)
      typography.with("md", function()
        love.graphics.setColor(0.55, 0.55, 0.55)
        local font = love.graphics.getFont()
        local tw = font:getWidth(b.label)
        local th = font:getHeight()
        love.graphics.print(b.label,
          b.x + (b.w - tw) / 2,
          b.y + (b.h - th) / 2)
      end)
    end
  end
end

function M:mousemoved(x, y)
  self.kanban:mousemoved(x, y)
  for _, b in ipairs(self.action_buttons) do b:mousemoved(x, y) end
end

function M:mousepressed(x, y, btn)
  self.kanban:mousepressed(x, y, btn)
  for _, b in ipairs(self.action_buttons) do
    local enabled = b._predicate == nil or b._predicate()
    if enabled then b:mousepressed(x, y, btn) end
  end
end

function M:mousereleased(x, y, btn)
  self.kanban:mousereleased(x, y, btn)
  for _, b in ipairs(self.action_buttons) do b:mousereleased(x, y, btn) end
end

function M:keypressed(key)
  if key == "escape" then
    self.fsm:transition("menu")
  end
end

return {
  new = new,
}
