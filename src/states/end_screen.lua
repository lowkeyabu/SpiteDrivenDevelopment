local Capstones = require("src.game.capstones")
local DilemmaDialog = require("src.ui.components.dilemma_dialog")
local Session = require("src.game.session")
local typography = require("src.ui.typography")

local M = {}
M.__index = M

local function new(deps)
  return setmetatable({
    fsm = deps.fsm,
    session = deps.session,
  }, M)
end

local function ascending_by_credit(players)
  local order = {}
  for i, p in ipairs(players) do
    table.insert(order, { idx = i, credit = p.credit })
  end
  table.sort(order, function(a, b) return a.credit < b.credit end)
  return order
end

function M:enter()
  self.gs = self.session:get_game_session()
  if not self.gs then
    self.fsm:transition("menu")
    return
  end
  self.order = ascending_by_credit(self.gs.players)
  self.capstone_idx = 1
  self.phase = "capstones"
  self.dialog = DilemmaDialog.new({
    on_choose = function(card, choice)
      local entry = self.order[self.capstone_idx]
      Capstones.resolve(self.gs, entry.idx, card, choice)
      self.capstone_idx = self.capstone_idx + 1
      self:advance_capstone()
    end,
  })
  self:advance_capstone()
end

function M:advance_capstone()
  while self.capstone_idx <= #self.order do
    local entry = self.order[self.capstone_idx]
    local p = self.gs.players[entry.idx]
    if not p.capstone_done then
      local archetype = Capstones.classify(p)
      local card = Capstones.draw_for(archetype)
      self.dialog:open(card, love.graphics.getWidth(), love.graphics.getHeight())
      return
    end
    self.capstone_idx = self.capstone_idx + 1
  end
  self.phase = "roast"
  self.roast_idx = 1
end

function M:resize(w, h)
  if self.dialog and self.dialog.visible then self.dialog:resize(w, h) end
end

local function draw_profile(self, player, x, y, w, h)
  local rgb = Session.PLAYER_PALETTE[player.color] or { 0.5, 0.5, 0.5 }
  love.graphics.setColor(rgb[1], rgb[2], rgb[3])
  love.graphics.rectangle("fill", x, y, 64, 64)
  love.graphics.setColor(0.1, 0.1, 0.1)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", x, y, 64, 64)

  typography.with("xl", function()
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.print(player.name, x + 80, y)
  end)
  typography.with("md", function()
    love.graphics.setColor(0.35, 0.35, 0.35)
    love.graphics.print(player.title, x + 80, y + 36)
  end)

  typography.with("lg", function()
    love.graphics.setColor(0.6, 0.2, 0.2)
    local label = "LinkedIn Score: " .. tostring(player.linkedin_score)
    local font = love.graphics.getFont()
    local tw = font:getWidth(label)
    love.graphics.print(label, x + w - tw, y + 8)
  end)

  local post_y = y + 96
  typography.with("sm", function()
    local font = love.graphics.getFont()
    for _, post in ipairs(player.humble_brag_log) do
      love.graphics.setColor(0.85, 0.85, 0.78)
      love.graphics.rectangle("fill", x, post_y, w, 60)
      love.graphics.setColor(0.1, 0.1, 0.1)
      love.graphics.setLineWidth(1)
      love.graphics.rectangle("line", x, post_y, w, 60)
      love.graphics.setColor(0.2, 0.2, 0.2)
      love.graphics.printf(post, x + 12, post_y + 8, w - 24, "left")
      post_y = post_y + 70
      if post_y > y + h - 60 then break end
    end
    if #player.humble_brag_log == 0 then
      love.graphics.setColor(0.5, 0.5, 0.5)
      love.graphics.print("(no posts this quarter)", x, post_y)
    end
  end)
end

function M:draw()
  if not self.gs then return end
  local w = love.graphics.getWidth()
  local h = love.graphics.getHeight()

  if self.phase == "capstones" then
    typography.with("xl", function()
      love.graphics.setColor(0.1, 0.1, 0.1)
      local font = love.graphics.getFont()
      local entry = self.order[self.capstone_idx]
      local name = entry and self.gs.players[entry.idx].name or ""
      local title = "Capstone: " .. name
      local tw = font:getWidth(title)
      love.graphics.print(title, (w - tw) / 2, 24)
    end)
    self.dialog:draw()
    return
  end

  typography.with("xl", function()
    love.graphics.setColor(0.1, 0.1, 0.1)
    local font = love.graphics.getFont()
    local title = "The Reveal"
    local tw = font:getWidth(title)
    love.graphics.print(title, (w - tw) / 2, 24)
  end)

  local entry = self.order[self.roast_idx]
  if entry then
    local p = self.gs.players[entry.idx]
    draw_profile(self, p, 64, 88, w - 128, h - 180)

    typography.with("md", function()
      love.graphics.setColor(0.4, 0.4, 0.4)
      local prog = string.format("Player %d of %d  /  Press SPACE to continue",
        self.roast_idx, #self.order)
      local font = love.graphics.getFont()
      local tw = font:getWidth(prog)
      love.graphics.print(prog, (w - tw) / 2, h - 56)
    end)
  else
    local winner_entry = self.order[#self.order]
    local winner = self.gs.players[winner_entry.idx]
    typography.with("display", function()
      love.graphics.setColor(0.6, 0.2, 0.2)
      local font = love.graphics.getFont()
      local title = winner.name .. " wins!"
      local tw = font:getWidth(title)
      love.graphics.print(title, (w - tw) / 2, h / 2 - 40)
    end)
    typography.with("md", function()
      love.graphics.setColor(0.3, 0.3, 0.3)
      local font = love.graphics.getFont()
      local sub = string.format(
        "Corporate success: %d Credit.  LinkedIn Score: %d.",
        winner.credit, winner.linkedin_score)
      local tw = font:getWidth(sub)
      love.graphics.print(sub, (w - tw) / 2, h / 2 + 24)

      local hint = "Press SPACE to return to the menu."
      tw = font:getWidth(hint)
      love.graphics.print(hint, (w - tw) / 2, h / 2 + 64)
    end)
  end
end

function M:mousemoved(x, y)
  if self.phase == "capstones" and self.dialog then
    self.dialog:mousemoved(x, y)
  end
end

function M:mousepressed(x, y, btn)
  if self.phase == "capstones" and self.dialog then
    self.dialog:mousepressed(x, y, btn)
  end
end

function M:mousereleased(x, y, btn)
  if self.phase == "capstones" and self.dialog then
    self.dialog:mousereleased(x, y, btn)
  end
end

function M:keypressed(key)
  if self.phase == "capstones" then return end
  if key == "space" then
    if self.roast_idx <= #self.order then
      self.roast_idx = self.roast_idx + 1
    else
      self.session:attach_game_session(nil)
      self.fsm:transition("menu")
    end
  elseif key == "escape" then
    self.session:attach_game_session(nil)
    self.fsm:transition("menu")
  end
end

return {
  new = new,
}
