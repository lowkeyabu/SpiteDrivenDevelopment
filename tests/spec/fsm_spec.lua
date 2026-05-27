local FSM = require("src.util.fsm")

describe("FSM", function()
  it("starts in the registered initial state", function()
    local entered
    local fsm = FSM.new()
    fsm:register("menu", { enter = function() entered = "menu" end })
    fsm:start("menu")
    assert.is_equal("menu", entered)
  end)

  it("transitions between states, calling leave then enter", function()
    local trace = {}
    local fsm = FSM.new()
    fsm:register("a", {
      enter = function() table.insert(trace, "a:enter") end,
      leave = function() table.insert(trace, "a:leave") end,
    })
    fsm:register("b", {
      enter = function() table.insert(trace, "b:enter") end,
    })
    fsm:start("a")
    fsm:transition("b")
    assert.are.same({ "a:enter", "a:leave", "b:enter" }, trace)
  end)

  it("returns the current state name", function()
    local fsm = FSM.new()
    fsm:register("menu", {})
    fsm:register("game", {})
    fsm:start("menu")
    assert.is_equal("menu", fsm:current())
    fsm:transition("game")
    assert.is_equal("game", fsm:current())
  end)

  it("dispatches arbitrary callbacks to the current state with arguments", function()
    local received
    local fsm = FSM.new()
    fsm:register("a", {
      keypressed = function(_, key) received = key end,
    })
    fsm:start("a")
    fsm:dispatch("keypressed", "space")
    assert.is_equal("space", received)
  end)

  it("ignores callbacks the state does not implement", function()
    local fsm = FSM.new()
    fsm:register("a", {})
    fsm:start("a")
    assert.has_no.errors(function() fsm:dispatch("keypressed", "x") end)
  end)

  it("raises when starting an unregistered state", function()
    local fsm = FSM.new()
    assert.has_error(function() fsm:start("missing") end)
  end)

  it("raises when transitioning to an unregistered state", function()
    local fsm = FSM.new()
    fsm:register("a", {})
    fsm:start("a")
    assert.has_error(function() fsm:transition("missing") end)
  end)

  it("raises if a state's enter or leave calls transition on the same fsm", function()
    local fsm = FSM.new()
    fsm:register("a", {
      enter = function(self)
        fsm:transition("b")
      end,
    })
    fsm:register("b", {})
    assert.has_error(function() fsm:start("a") end)
  end)

  it("clears the transition flag when a state's enter raises", function()
    local fsm = FSM.new()
    fsm:register("a", {
      enter = function() error("boom") end,
    })
    fsm:register("b", { enter = function(self) self.entered = true end })
    pcall(function() fsm:start("a") end)
    -- After the raise, the fsm must not be wedged. Starting b should succeed.
    assert.has_no.errors(function() fsm:start("b") end)
    assert.is_equal("b", fsm:current())
  end)
end)
