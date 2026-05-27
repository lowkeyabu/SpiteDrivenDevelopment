-- Modal overlay: lists available sabotage cards. Click a card to play
-- it. For Plan 7, "player" targets default to the next player;
-- "ticket" targets default to the kanban's selected ticket.

local Button = require("src.ui.components.button")
local Sabotage = require("src.game.sabotage")
local typography = require("src.ui.typography")

local SabotageMenu = {}
SabotageMenu.__index = SabotageMenu

local CARD_W, CARD_H, CARD_GAP = 540, 80, 8

local function default_target(gs, kanban, card)
  if card.target == "none" or card.target == "all" then return {} end
  if card.target == "player" then
    local n = #gs.players
    local nxt = (gs.current_actor % n) + 1
    return { player_idx = nxt }
  end
  if card.target == "ticket" then
    local t = kanban and kanban:get_selected()
    if t then return { ticket_id = t.id } end
    return nil
  end
  return {}
end

local function new(opts)
  return setmetatable({
    game_session = opts.game_session,
    kanban = opts.kanban,
    on_close = opts.on_close or function() end,
    visible = false,
    cards = {},
    card_buttons = {},
    close_button = nil,
  }, SabotageMenu)
end

local function build_buttons(self, w, h)
  self.cards = Sabotage.available_for(self.game_session)
  self.card_buttons = {}

  local cx = (w - CARD_W) / 2
  local total_h = #self.cards * (CARD_H + CARD_GAP) - CARD_GAP
  local cy = math.max(80, (h - total_h) / 2)

  for i, card in ipairs(self.cards) do
    local y = cy + (i - 1) * (CARD_H + CARD_GAP)
    local card_ref = card
    local b = Button.new({
      x = cx, y = y, w = CARD_W, h = CARD_H,
      label = card.name,
      on_click = function()
        local target = default_target(self.game_session, self.kanban, card_ref)
        if target == nil then return end
        if not Sabotage.can_afford(self.game_session, card_ref) then return end
        local ok = pcall(function()
          Sabotage.play(self.game_session, card_ref.id, target)
        end)
        if ok then
          self.game_session.players[self.game_session.current_actor].ap =
            self.game_session.players[self.game_session.current_actor].ap - 1
          self:close()
        end
      end,
    })
    b._card = card_ref
    table.insert(self.card_buttons, b)
  end

  self.close_button = Button.new({
    x = w - 32 - 100, y = 32, w = 100, h = 32,
    label = "Close",
    on_click = function() self:close() end,
  })
end

function SabotageMenu:open(w, h)
  self.visible = true
  build_buttons(self, w, h)
end

function SabotageMenu:close()
  self.visible = false
  self.on_close()
end

function SabotageMenu:resize(w, h)
  if self.visible then build_buttons(self, w, h) end
end

function SabotageMenu:draw()
  if not self.visible then return end
  if not (love and love.graphics) then return end
  local w = love.graphics.getWidth()
  local h = love.graphics.getHeight()

  love.graphics.setColor(0, 0, 0, 0.55)
  love.graphics.rectangle("fill", 0, 0, w, h)

  typography.with("xl", function()
    love.graphics.setColor(0.95, 0.95, 0.92)
    local font = love.graphics.getFont()
    local title = "Choose Your Sabotage"
    local tw = font:getWidth(title)
    love.graphics.print(title, (w - tw) / 2, 32)
  end)

  for _, b in ipairs(self.card_buttons) do
    b:draw()
    local card = b._card
    local actor = self.game_session.players[self.game_session.current_actor]
    local affordable = actor.clout >= card.clout
    typography.with("xs", function()
      love.graphics.setColor(0.3, 0.3, 0.3)
      local meta = string.format("T%d  /  %d Clout  /  +%d LS  /  %s",
        card.tier, card.clout, card.ls_delta, card.target)
      love.graphics.print(meta, b.x + 10, b.y + b.h - 18)
      if not affordable then
        love.graphics.setColor(0.7, 0.2, 0.2)
        love.graphics.print("(insufficient Clout)", b.x + b.w - 140, b.y + b.h - 18)
      end
    end)
  end

  self.close_button:draw()
end

function SabotageMenu:mousemoved(x, y)
  if not self.visible then return end
  for _, b in ipairs(self.card_buttons) do b:mousemoved(x, y) end
  self.close_button:mousemoved(x, y)
end

function SabotageMenu:mousepressed(x, y, btn)
  if not self.visible then return end
  for _, b in ipairs(self.card_buttons) do b:mousepressed(x, y, btn) end
  self.close_button:mousepressed(x, y, btn)
end

function SabotageMenu:mousereleased(x, y, btn)
  if not self.visible then return end
  for _, b in ipairs(self.card_buttons) do b:mousereleased(x, y, btn) end
  self.close_button:mousereleased(x, y, btn)
end

function SabotageMenu:keypressed(key)
  if not self.visible then return end
  if key == "escape" then self:close() end
end

return {
  new = new,
}
