local FSM = require("src.util.fsm")
local Session = require("src.game.session")
local typography = require("src.ui.typography")

local fsm
local session

local STATES = {
  "menu",
  "mode_select",
  "config",
  "player_setup",
  "game",
  "end_screen",
}

function love.load()
  love.graphics.setBackgroundColor(0.96, 0.94, 0.86) -- paper tone
  typography.init()

  fsm = FSM.new()
  session = Session.new()
  local deps = { fsm = fsm, session = session }

  for _, name in ipairs(STATES) do
    local mod = require("src.states." .. name)
    fsm:register(name, mod.new(deps))
  end
  fsm:start("menu")
end

function love.update(dt) fsm:dispatch("update", dt) end
function love.draw() fsm:dispatch("draw") end
function love.keypressed(key, scancode, isrepeat) fsm:dispatch("keypressed", key, scancode, isrepeat) end
function love.keyreleased(key, scancode) fsm:dispatch("keyreleased", key, scancode) end
function love.mousepressed(x, y, button, istouch, presses) fsm:dispatch("mousepressed", x, y, button, istouch, presses) end
function love.mousereleased(x, y, button, istouch, presses) fsm:dispatch("mousereleased", x, y, button, istouch, presses) end
function love.mousemoved(x, y, dx, dy, istouch) fsm:dispatch("mousemoved", x, y, dx, dy, istouch) end
function love.wheelmoved(dx, dy) fsm:dispatch("wheelmoved", dx, dy) end
function love.textinput(text) fsm:dispatch("textinput", text) end
function love.resize(w, h) fsm:dispatch("resize", w, h) end
