local Tutorial = require("src.game.tutorial")

describe("Tutorial", function()
  it("starts at step 1", function()
    local s = Tutorial.new()
    assert.is_equal(1, s.step_idx)
    assert.is_not_nil(Tutorial.current(s))
  end)

  it("manual_advance bumps step_idx", function()
    local s = Tutorial.new()
    Tutorial.manual_advance(s)
    assert.is_equal(2, s.step_idx)
  end)

  it("manual_advance is a no-op on auto-advance steps", function()
    local s = Tutorial.new()
    s.step_idx = 3
    Tutorial.manual_advance(s)
    assert.is_equal(3, s.step_idx)
  end)

  it("advance does nothing on manual-advance step", function()
    local s = Tutorial.new()
    s.step_idx = 1
    Tutorial.advance(s, {})
    assert.is_equal(1, s.step_idx)
  end)

  it("advance walks past auto-advance steps when condition is true", function()
    local s = Tutorial.new()
    s.step_idx = 3
    s.kanban_selected_in_backlog = true
    Tutorial.advance(s, { in_progress = {}, review = {}, done = {} })
    assert.is_equal(4, s.step_idx)
  end)

  it("is_complete returns true when step_idx exceeds STEPS length", function()
    local s = Tutorial.new()
    s.step_idx = #Tutorial.STEPS + 1
    assert.is_true(Tutorial.is_complete(s))
  end)
end)
