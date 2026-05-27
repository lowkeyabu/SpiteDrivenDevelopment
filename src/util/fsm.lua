-- Finite state machine for screen-level states (menu, config, game, etc.).
--
-- State contract:
--   A state is a table that may implement any of these methods. Methods are
--   called with the state as `self` and Love2D-style positional arguments:
--     enter()                    -- called when entering the state
--     leave()                    -- called when leaving the state
--     update(dt)                 -- per-frame update
--     draw()                     -- per-frame render
--     keypressed(key, scancode, isrepeat)
--     keyreleased(key, scancode)
--     mousepressed(x, y, button, istouch, presses)
--     mousereleased(x, y, button, istouch, presses)
--     mousemoved(x, y, dx, dy, istouch)
--     wheelmoved(dx, dy)
--     textinput(text)
--     resize(w, h)
--
-- Any method not implemented on a state is silently skipped when dispatched.

local FSM = {}
FSM.__index = FSM

local function new()
  return setmetatable({
    states = {},
    current_name = nil,
  }, FSM)
end

function FSM:register(name, state)
  assert(type(name) == "string" and #name > 0, "state name must be a non-empty string")
  assert(type(state) == "table", "state must be a table")
  self.states[name] = state
end

function FSM:start(name)
  local state = self.states[name]
  assert(state, "no such state: " .. tostring(name))
  self.current_name = name
  if state.enter then state:enter() end
end

function FSM:transition(name)
  local next_state = self.states[name]
  assert(next_state, "no such state: " .. tostring(name))
  local prev = self.states[self.current_name]
  if prev and prev.leave then prev:leave() end
  self.current_name = name
  if next_state.enter then next_state:enter() end
end

function FSM:current()
  return self.current_name
end

function FSM:dispatch(method, ...)
  local state = self.states[self.current_name]
  if state and state[method] then
    state[method](state, ...)
  end
end

return {
  new = new,
}
