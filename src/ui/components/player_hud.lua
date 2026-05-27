-- Renders one HUD row per player showing color, name, AP, Credit, and
-- Title. The current actor's row is highlighted.

local Session = require("src.game.session")

local PlayerHUD = {}
PlayerHUD.__index = PlayerHUD

local ROW_H = 56
local PADDING = 8

local function new(opts)
  return setmetatable({
    x = opts.x or 0,
    y = opts.y or 0,
    w = opts.w or 260,
    game_session = opts.game_session,
  }, PlayerHUD)
end

function PlayerHUD:height()
  return #self.game_session.players * (ROW_H + PADDING) - PADDING
end

function PlayerHUD:draw()
  if not (love and love.graphics) then return end
  local typography = require("src.ui.typography")
  local gs = self.game_session
  local current = gs.current_actor

  for i, p in ipairs(gs.players) do
    local row_y = self.y + (i - 1) * (ROW_H + PADDING)
    local is_current = (i == current)

    if is_current then
      love.graphics.setColor(1, 0.97, 0.79)
    else
      love.graphics.setColor(0.94, 0.92, 0.84)
    end
    love.graphics.rectangle("fill", self.x, row_y, self.w, ROW_H)

    if is_current then
      love.graphics.setColor(0.1, 0.4, 0.7)
      love.graphics.setLineWidth(3)
    else
      love.graphics.setColor(0.1, 0.1, 0.1)
      love.graphics.setLineWidth(1)
    end
    love.graphics.rectangle("line", self.x, row_y, self.w, ROW_H)

    local rgb = Session.PLAYER_PALETTE[p.color] or { 0.5, 0.5, 0.5 }
    love.graphics.setColor(rgb[1], rgb[2], rgb[3])
    love.graphics.rectangle("fill", self.x + 8, row_y + 12, 32, 32)
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", self.x + 8, row_y + 12, 32, 32)

    typography.with("md", function()
      love.graphics.setColor(0.1, 0.1, 0.1)
      love.graphics.print(p.name, self.x + 48, row_y + 6)
    end)
    typography.with("xs", function()
      love.graphics.setColor(0.4, 0.4, 0.4)
      love.graphics.print(p.title, self.x + 48, row_y + 28)
    end)

    typography.with("xs", function()
      love.graphics.setColor(0.1, 0.1, 0.1)
      local font = love.graphics.getFont()
      local ap_label = "AP " .. tostring(p.ap) .. "/" .. tostring(gs.session.config.ap_per_turn)
      local credit_label = "Cr " .. tostring(p.credit)
      local clout_label = "Clt " .. tostring(p.clout)
      local apw = font:getWidth(ap_label)
      local crw = font:getWidth(credit_label)
      local clw = font:getWidth(clout_label)
      love.graphics.print(ap_label, self.x + self.w - apw - 12, row_y + 6)
      love.graphics.print(credit_label, self.x + self.w - crw - 12, row_y + 22)
      love.graphics.print(clout_label, self.x + self.w - clw - 12, row_y + 38)
    end)
  end
end

return {
  new = new,
}
