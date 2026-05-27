-- Renders one ticket card. Stateless — the caller provides position,
-- size, and presentation hints via opts each frame.
--
-- opts:
--   selected     - boolean, draws an outline highlight
--   actor_owns   - boolean, slightly different fill to distinguish your tickets

local TicketCard = {}

local TYPE_BADGE = {
  feature = { 0.30, 0.55, 0.90 },
  bug     = { 0.85, 0.30, 0.30 },
  chore   = { 0.60, 0.60, 0.60 },
  epic    = { 0.65, 0.35, 0.85 },
  spike   = { 0.95, 0.55, 0.25 },
  vibe    = { 0.30, 0.75, 0.85 },
}

local function badge_color(ttype)
  return TYPE_BADGE[ttype] or { 0.5, 0.5, 0.5 }
end

local function draw(ticket, x, y, w, h, opts)
  if not (love and love.graphics) then return end
  opts = opts or {}
  local typography = require("src.ui.typography")

  local fill = { 1, 0.97, 0.79 }
  if opts.actor_owns then
    fill = { 0.95, 0.99, 0.85 }
  end
  love.graphics.setColor(fill[1], fill[2], fill[3])
  love.graphics.rectangle("fill", x, y, w, h)

  if opts.selected then
    love.graphics.setColor(0.1, 0.4, 0.7)
    love.graphics.setLineWidth(3)
  else
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.setLineWidth(1)
  end
  love.graphics.rectangle("line", x, y, w, h)

  local bcol = badge_color(ticket.type)
  love.graphics.setColor(bcol[1], bcol[2], bcol[3])
  love.graphics.rectangle("fill", x + 6, y + 6, 64, 14)
  typography.with("xs", function()
    love.graphics.setColor(1, 1, 1)
    local font = love.graphics.getFont()
    local label = ticket.type:upper()
    local tw = font:getWidth(label)
    love.graphics.print(label, x + 6 + (64 - tw) / 2, y + 7)
  end)

  typography.with("xs", function()
    love.graphics.setColor(0.4, 0.4, 0.4)
    local font = love.graphics.getFont()
    local label = ticket.id
    local tw = font:getWidth(label)
    love.graphics.print(label, x + w - tw - 6, y + 7)
  end)

  typography.with("sm", function()
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.print(ticket.title, x + 6, y + 26)
  end)

  love.graphics.setColor(0.1, 0.1, 0.1)
  love.graphics.rectangle("fill", x + 6, y + h - 22, 26, 16)
  typography.with("xs", function()
    love.graphics.setColor(1, 0.97, 0.79)
    local font = love.graphics.getFont()
    local label = (ticket.points_remaining or ticket.points) .. "/" .. ticket.points
    local tw = font:getWidth(label)
    love.graphics.print(label, x + 6 + (26 - tw) / 2, y + h - 21)
  end)

  love.graphics.setColor(0.2, 0.5, 0.3)
  love.graphics.rectangle("fill", x + w - 56, y + h - 22, 50, 16)
  typography.with("xs", function()
    love.graphics.setColor(1, 1, 1)
    local font = love.graphics.getFont()
    local label = "+" .. ticket.reward .. " cr"
    local tw = font:getWidth(label)
    love.graphics.print(label, x + w - 56 + (50 - tw) / 2, y + h - 21)
  end)
end

return {
  draw = draw,
  TYPE_BADGE = TYPE_BADGE,
}
