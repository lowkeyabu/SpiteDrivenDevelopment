-- Renders the four-column Kanban board. Tracks one selected ticket id
-- (or nil). The screen reads selected_id to decide which actions are
-- available.

local TicketCard = require("src.ui.components.ticket_card")

local KanbanView = {}
KanbanView.__index = KanbanView

local COLUMNS = { "backlog", "in_progress", "review", "done" }
local COLUMN_LABELS = {
  backlog     = "Backlog",
  in_progress = "In Progress",
  review      = "Review",
  done        = "Done",
}

local CARD_H = 88
local CARD_GAP = 8
local COLUMN_HEADER_H = 36
local COLUMN_PADDING = 10

local function new(opts)
  return setmetatable({
    x = opts.x or 0,
    y = opts.y or 0,
    w = opts.w or 1280,
    h = opts.h or 600,
    game_session = opts.game_session,
    selected_id = nil,
  }, KanbanView)
end

function KanbanView:column_rect(idx)
  local col_w = self.w / 4
  local col_x = self.x + (idx - 1) * col_w
  return col_x, self.y, col_w, self.h
end

function KanbanView:get_selected()
  if self.selected_id == nil then return nil end
  return self.game_session:find(self.selected_id)
end

function KanbanView:_card_rects()
  local rects = {}
  for col_idx, col in ipairs(COLUMNS) do
    local col_x, col_y, col_w, col_h = self:column_rect(col_idx)
    local card_x = col_x + COLUMN_PADDING
    local card_y = col_y + COLUMN_HEADER_H + COLUMN_PADDING
    local card_w = col_w - 2 * COLUMN_PADDING
    for _, ticket in ipairs(self.game_session[col]) do
      table.insert(rects, {
        ticket = ticket, column = col,
        x = card_x, y = card_y, w = card_w, h = CARD_H,
      })
      card_y = card_y + CARD_H + CARD_GAP
    end
  end
  return rects
end

function KanbanView:mousepressed(x, y, btn)
  if btn ~= 1 then return end
  for _, rect in ipairs(self:_card_rects()) do
    if x >= rect.x and y >= rect.y
       and x < rect.x + rect.w and y < rect.y + rect.h then
      self.selected_id = rect.ticket.id
      return
    end
  end
  self.selected_id = nil
end

function KanbanView:mousereleased(x, y, btn) end
function KanbanView:mousemoved(x, y) end

function KanbanView:draw()
  if not (love and love.graphics) then return end
  local typography = require("src.ui.typography")
  local actor = self.game_session.current_actor

  for col_idx, col in ipairs(COLUMNS) do
    local col_x, col_y, col_w, col_h = self:column_rect(col_idx)

    love.graphics.setColor(0.88, 0.86, 0.78)
    love.graphics.rectangle("fill", col_x, col_y, col_w, COLUMN_HEADER_H)
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", col_x, col_y, col_w, COLUMN_HEADER_H)
    typography.with("md", function()
      love.graphics.setColor(0.1, 0.1, 0.1)
      local font = love.graphics.getFont()
      local label = COLUMN_LABELS[col]
      local tw = font:getWidth(label)
      love.graphics.print(label,
        col_x + (col_w - tw) / 2,
        col_y + (COLUMN_HEADER_H - font:getHeight()) / 2)
    end)

    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.rectangle("line",
      col_x, col_y + COLUMN_HEADER_H,
      col_w, col_h - COLUMN_HEADER_H)
  end

  for _, rect in ipairs(self:_card_rects()) do
    TicketCard.draw(rect.ticket, rect.x, rect.y, rect.w, rect.h, {
      selected = (rect.ticket.id == self.selected_id),
      actor_owns = (rect.ticket.owner == actor),
    })
  end
end

return {
  new = new,
}
