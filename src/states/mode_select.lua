local M = {}
M.__index = M

local function new(deps)
  return setmetatable({
    fsm = deps.fsm,
    session = deps.session,
  }, M)
end

function M:enter()
  self.message = "MODE_SELECT — press SPACE to advance to config"
end

function M:draw()
  love.graphics.setColor(0.1, 0.1, 0.1)
  love.graphics.print(self.message, 40, 40)
end

function M:keypressed(key)
  if key == "space" then
    self.fsm:transition("config")
  elseif key == "escape" then
    self.fsm:transition("menu")
  end
end

return {
  new = new,
}
