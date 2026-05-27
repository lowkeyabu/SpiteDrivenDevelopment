local ColorPicker = require("src.ui.components.color_picker")

local function fixture()
  return ColorPicker.new({
    x = 0, y = 0,
    swatch_size = 32,
    gap = 8,
    palette = {
      { 1, 0, 0 },
      { 0, 1, 0 },
      { 0, 0, 1 },
      { 1, 1, 0 },
    },
    value = 1,
  })
end

describe("ColorPicker", function()
  it("starts at the provided value", function()
    local c = fixture()
    assert.is_equal(1, c:get_value())
  end)

  it("defaults value to 1 when none given", function()
    local c = ColorPicker.new({
      x = 0, y = 0, swatch_size = 32, gap = 8,
      palette = { { 1, 0, 0 }, { 0, 1, 0 } },
    })
    assert.is_equal(1, c:get_value())
  end)

  it("set_value updates and fires on_change only on actual change", function()
    local last
    local c = ColorPicker.new({
      x = 0, y = 0, swatch_size = 32, gap = 8,
      palette = { { 1, 0, 0 }, { 0, 1, 0 } },
      value = 1,
      on_change = function(v) last = v end,
    })
    c:set_value(1)
    assert.is_nil(last)
    c:set_value(2)
    assert.is_equal(2, last)
  end)

  it("set_value rejects out-of-range indices", function()
    local c = fixture()
    assert.has_error(function() c:set_value(0) end)
    assert.has_error(function() c:set_value(5) end)
  end)

  it("press-then-release on swatch 3 selects index 3", function()
    local c = fixture()
    c:mousepressed(90, 16, 1)
    c:mousereleased(90, 16, 1)
    assert.is_equal(3, c:get_value())
  end)

  it("press inside one swatch then release on another does not change value", function()
    local c = fixture()
    c:mousepressed(10, 16, 1)
    c:mousereleased(50, 16, 1)
    assert.is_equal(1, c:get_value())
  end)

  it("press in the gap between swatches is a no-op", function()
    local c = fixture()
    c:mousepressed(35, 16, 1)
    c:mousereleased(35, 16, 1)
    assert.is_equal(1, c:get_value())
  end)

  it("non-primary mouse button does not select", function()
    local c = fixture()
    c:mousepressed(90, 16, 2)
    c:mousereleased(90, 16, 2)
    assert.is_equal(1, c:get_value())
  end)

  it("width() reports the total horizontal footprint", function()
    local c = fixture()
    -- 4 swatches of 32px + 3 gaps of 8px = 128 + 24 = 152
    assert.is_equal(152, c:width())
  end)
end)
