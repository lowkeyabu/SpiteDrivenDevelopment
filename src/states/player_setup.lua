local M = {}

function M:enter()
  self.message = "PLAYER_SETUP — press SPACE to advance to game"
end

function M:draw()
  love.graphics.setColor(0.1, 0.1, 0.1)
  love.graphics.print(self.message, 40, 40)
end

function M:keypressed(key)
  if key == "space" then
    self.fsm:transition("game")
  elseif key == "escape" then
    self.fsm:transition("menu")
  end
end

return M
