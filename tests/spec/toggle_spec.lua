local Toggle = require("src.ui.components.toggle")

describe("Toggle", function()
  it("starts at the provided value", function()
    local t = Toggle.new({ x = 0, y = 0, w = 240, h = 40, value = true })
    assert.is_true(t:get_value())
    local f = Toggle.new({ x = 0, y = 0, w = 240, h = 40, value = false })
    assert.is_false(f:get_value())
  end)

  it("defaults value to false", function()
    local t = Toggle.new({ x = 0, y = 0, w = 240, h = 40 })
    assert.is_false(t:get_value())
  end)

  it("press-then-release inside flips the value and fires on_change", function()
    local last
    local t = Toggle.new({
      x = 0, y = 0, w = 240, h = 40, value = false,
      on_change = function(v) last = v end,
    })
    t:mousepressed(120, 20, 1)
    t:mousereleased(120, 20, 1)
    assert.is_true(t:get_value())
    assert.is_true(last)
    t:mousepressed(120, 20, 1)
    t:mousereleased(120, 20, 1)
    assert.is_false(t:get_value())
    assert.is_false(last)
  end)

  it("press inside then release outside does not flip", function()
    local t = Toggle.new({ x = 0, y = 0, w = 240, h = 40, value = false })
    t:mousepressed(120, 20, 1)
    t:mousereleased(500, 500, 1)
    assert.is_false(t:get_value())
  end)

  it("non-primary mouse button does not flip", function()
    local t = Toggle.new({ x = 0, y = 0, w = 240, h = 40, value = false })
    t:mousepressed(120, 20, 2)
    t:mousereleased(120, 20, 2)
    assert.is_false(t:get_value())
  end)

  it("set_value updates without firing on_change when unchanged", function()
    local fired = false
    local t = Toggle.new({
      x = 0, y = 0, w = 240, h = 40, value = false,
      on_change = function() fired = true end,
    })
    t:set_value(false)
    assert.is_false(fired)
    t:set_value(true)
    assert.is_true(fired)
  end)
end)
