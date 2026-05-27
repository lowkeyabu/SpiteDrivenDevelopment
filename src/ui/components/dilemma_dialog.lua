-- Modal dialog showing a Dilemma card: setup + two large option
-- buttons (A / B). Clicking either fires on_choose(dilemma, choice).
-- No escape — once opened, the actor must choose.

local Button = require("src.ui.components.button")
local typography = require("src.ui.typography")

local DilemmaDialog = {}
DilemmaDialog.__index = DilemmaDialog

local CARD_W = 720

local function new(opts)
  return setmetatable({
    on_choose = opts.on_choose or function() end,
    visible = false,
    dilemma = nil,
    button_a = nil,
    button_b = nil,
  }, DilemmaDialog)
end

local function build_buttons(self, w, h)
  if not self.dilemma then return end
  local btn_w = 320
  local btn_h = 96
  local total_w = 2 * btn_w + 24
  local bx = (w - total_w) / 2
  local by = h - btn_h - 80
  local d = self.dilemma
  self.button_a = Button.new({
    x = bx, y = by, w = btn_w, h = btn_h,
    label = "A: " .. d.option_a.pitch,
    on_click = function() self:choose("a") end,
  })
  self.button_b = Button.new({
    x = bx + btn_w + 24, y = by, w = btn_w, h = btn_h,
    label = "B: " .. d.option_b.pitch,
    on_click = function() self:choose("b") end,
  })
end

function DilemmaDialog:open(dilemma, w, h)
  self.dilemma = dilemma
  self.visible = true
  build_buttons(self, w, h)
end

function DilemmaDialog:choose(choice)
  local d = self.dilemma
  self.visible = false
  local cb = self.on_choose
  self.dilemma = nil
  cb(d, choice)
end

function DilemmaDialog:resize(w, h)
  if self.visible then build_buttons(self, w, h) end
end

function DilemmaDialog:draw()
  if not self.visible or not self.dilemma then return end
  if not (love and love.graphics) then return end
  local w = love.graphics.getWidth()
  local h = love.graphics.getHeight()
  local d = self.dilemma

  love.graphics.setColor(0, 0, 0, 0.65)
  love.graphics.rectangle("fill", 0, 0, w, h)

  local cx = (w - CARD_W) / 2
  local cy = 80
  local card_h = h - 240
  love.graphics.setColor(0.97, 0.94, 0.85)
  love.graphics.rectangle("fill", cx, cy, CARD_W, card_h)
  love.graphics.setColor(0.1, 0.1, 0.1)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", cx, cy, CARD_W, card_h)

  typography.with("xl", function()
    love.graphics.setColor(0.1, 0.1, 0.1)
    local font = love.graphics.getFont()
    local tw = font:getWidth(d.title)
    love.graphics.print(d.title, cx + (CARD_W - tw) / 2, cy + 24)
  end)

  typography.with("md", function()
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.printf(d.setup, cx + 32, cy + 96, CARD_W - 64, "center")
  end)

  if self.button_a then self.button_a:draw() end
  if self.button_b then self.button_b:draw() end
end

function DilemmaDialog:mousemoved(x, y)
  if not self.visible then return end
  if self.button_a then self.button_a:mousemoved(x, y) end
  if self.button_b then self.button_b:mousemoved(x, y) end
end

function DilemmaDialog:mousepressed(x, y, btn)
  if not self.visible then return end
  if self.button_a then self.button_a:mousepressed(x, y, btn) end
  if self.button_b then self.button_b:mousepressed(x, y, btn) end
end

function DilemmaDialog:mousereleased(x, y, btn)
  if not self.visible then return end
  if self.button_a then self.button_a:mousereleased(x, y, btn) end
  if self.button_b then self.button_b:mousereleased(x, y, btn) end
end

function DilemmaDialog:keypressed(key) end

return {
  new = new,
}
