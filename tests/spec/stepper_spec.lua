local Stepper = require("src.ui.components.stepper")

describe("Stepper", function()
  it("starts at the provided value and reports it via get_value", function()
    local s = Stepper.new({ x = 0, y = 0, w = 240, h = 40, value = 3, min = 1, max = 5 })
    assert.is_equal(3, s:get_value())
  end)

  it("set_value clamps to [min, max]", function()
    local s = Stepper.new({ x = 0, y = 0, w = 240, h = 40, value = 3, min = 1, max = 5 })
    s:set_value(10)
    assert.is_equal(5, s:get_value())
    s:set_value(-3)
    assert.is_equal(1, s:get_value())
    s:set_value(4)
    assert.is_equal(4, s:get_value())
  end)

  it("press-then-release inside the plus plate increments and fires on_change", function()
    local last
    local s = Stepper.new({
      x = 0, y = 0, w = 240, h = 40, value = 3, min = 1, max = 5,
      on_change = function(v) last = v end,
    })
    s:mousepressed(220, 20, 1)
    s:mousereleased(220, 20, 1)
    assert.is_equal(4, s:get_value())
    assert.is_equal(4, last)
  end)

  it("press-then-release inside the minus plate decrements and fires on_change", function()
    local last
    local s = Stepper.new({
      x = 0, y = 0, w = 240, h = 40, value = 3, min = 1, max = 5,
      on_change = function(v) last = v end,
    })
    s:mousepressed(10, 20, 1)
    s:mousereleased(10, 20, 1)
    assert.is_equal(2, s:get_value())
    assert.is_equal(2, last)
  end)

  it("does not go below min on -", function()
    local s = Stepper.new({ x = 0, y = 0, w = 240, h = 40, value = 1, min = 1, max = 5 })
    s:mousepressed(10, 20, 1)
    s:mousereleased(10, 20, 1)
    assert.is_equal(1, s:get_value())
  end)

  it("does not go above max on +", function()
    local s = Stepper.new({ x = 0, y = 0, w = 240, h = 40, value = 5, min = 1, max = 5 })
    s:mousepressed(220, 20, 1)
    s:mousereleased(220, 20, 1)
    assert.is_equal(5, s:get_value())
  end)

  it("press inside plus then release outside does not increment", function()
    local s = Stepper.new({ x = 0, y = 0, w = 240, h = 40, value = 3, min = 1, max = 5 })
    s:mousepressed(220, 20, 1)
    s:mousereleased(120, 20, 1)
    assert.is_equal(3, s:get_value())
  end)

  it("non-primary mouse buttons do not change the value", function()
    local s = Stepper.new({ x = 0, y = 0, w = 240, h = 40, value = 3, min = 1, max = 5 })
    s:mousepressed(220, 20, 2)
    s:mousereleased(220, 20, 2)
    assert.is_equal(3, s:get_value())
  end)

  it("defaults: min=0, max=10, step=1, value=0, on_change=no-op", function()
    local s = Stepper.new({ x = 0, y = 0, w = 240, h = 40 })
    assert.is_equal(0, s:get_value())
    assert.has_no.errors(function()
      s:mousepressed(220, 20, 1)
      s:mousereleased(220, 20, 1)
    end)
    assert.is_equal(1, s:get_value())
  end)
end)
