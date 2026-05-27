-- Main menu state. Placeholder for Task 12; replaced with the real menu in Task 16.

local M = {}

function M:enter()
  self.message = "MENU — press SPACE to advance to mode_select"
end

function M:draw()
  love.graphics.setColor(0.1, 0.1, 0.1)
  love.graphics.print(self.message, 40, 40)
end

function M:keypressed(key)
  if key == "space" then
    self.fsm:transition("mode_select")
  elseif key == "escape" then
    love.event.quit()
  end
end

return M
