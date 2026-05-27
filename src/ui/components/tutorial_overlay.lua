-- Tutorial overlay: top-center bubble showing the current step's
-- instruction. Includes a Continue button for manual-advance steps.

local Button = require("src.ui.components.button")
local Tutorial = require("src.game.tutorial")
local typography = require("src.ui.typography")

local TutorialOverlay = {}
TutorialOverlay.__index = TutorialOverlay

local BUBBLE_W = 720
local BUBBLE_H = 120

local function new(opts)
  return setmetatable({
    state = opts.state,
    on_advance = opts.on_advance or function() end,
    continue_button = nil,
  }, TutorialOverlay)
end

function TutorialOverlay:_rebuild_button(w)
  local btn_w = 140
  self.continue_button = Button.new({
    x = (w - btn_w) / 2, y = 56 + BUBBLE_H - 48, w = btn_w, h = 36,
    label = "Continue",
    on_click = function()
      Tutorial.manual_advance(self.state)
      self.on_advance()
    end,
  })
end

function TutorialOverlay:resize(w, h)
  self:_rebuild_button(w)
end

function TutorialOverlay:draw()
  if not (love and love.graphics) then return end
  if Tutorial.is_complete(self.state) then return end
  local step = Tutorial.current(self.state)
  if not step then return end

  local w = love.graphics.getWidth()
  if not self.continue_button then self:_rebuild_button(w) end

  local bx = (w - BUBBLE_W) / 2
  local by = 56

  love.graphics.setColor(1, 0.97, 0.79, 0.95)
  love.graphics.rectangle("fill", bx, by, BUBBLE_W, BUBBLE_H)
  love.graphics.setColor(0.1, 0.4, 0.7)
  love.graphics.setLineWidth(3)
  love.graphics.rectangle("line", bx, by, BUBBLE_W, BUBBLE_H)

  typography.with("xs", function()
    love.graphics.setColor(0.4, 0.4, 0.4)
    love.graphics.print(
      "Tutorial " .. tostring(self.state.step_idx) .. "/" .. tostring(#Tutorial.STEPS),
      bx + 12, by + 8)
  end)

  typography.with("md", function()
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.printf(step.text, bx + 20, by + 28, BUBBLE_W - 40, "left")
  end)

  if step.manual_advance then
    self.continue_button:draw()
  end
end

function TutorialOverlay:mousemoved(x, y)
  if Tutorial.is_complete(self.state) then return end
  local step = Tutorial.current(self.state)
  if step and step.manual_advance and self.continue_button then
    self.continue_button:mousemoved(x, y)
  end
end

function TutorialOverlay:mousepressed(x, y, btn)
  if Tutorial.is_complete(self.state) then return end
  local step = Tutorial.current(self.state)
  if step and step.manual_advance and self.continue_button then
    self.continue_button:mousepressed(x, y, btn)
  end
end

function TutorialOverlay:mousereleased(x, y, btn)
  if Tutorial.is_complete(self.state) then return end
  local step = Tutorial.current(self.state)
  if step and step.manual_advance and self.continue_button then
    self.continue_button:mousereleased(x, y, btn)
  end
end

return { new = new }
