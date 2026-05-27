local RadioGroup = require("src.ui.components.radio_group")

local function fixture()
  return RadioGroup.new({
    x = 0, y = 0, w = 320,
    row_h = 32,
    options = {
      { id = "a", label = "Alpha" },
      { id = "b", label = "Beta" },
      { id = "c", label = "Gamma" },
    },
    value = "a",
  })
end

describe("RadioGroup", function()
  it("starts at the provided value", function()
    local r = fixture()
    assert.is_equal("a", r:get_value())
  end)

  it("defaults value to the first option's id when none given", function()
    local r = RadioGroup.new({
      x = 0, y = 0, w = 320, row_h = 32,
      options = { { id = "only", label = "Only" } },
    })
    assert.is_equal("only", r:get_value())
  end)

  it("set_value updates and fires on_change only on actual change", function()
    local last
    local r = RadioGroup.new({
      x = 0, y = 0, w = 320, row_h = 32,
      options = {
        { id = "a", label = "Alpha" },
        { id = "b", label = "Beta" },
      },
      value = "a",
      on_change = function(v) last = v end,
    })
    r:set_value("a")
    assert.is_nil(last)
    r:set_value("b")
    assert.is_equal("b", last)
    assert.is_equal("b", r:get_value())
  end)

  it("set_value rejects unknown ids", function()
    local r = fixture()
    assert.has_error(function() r:set_value("missing") end)
  end)

  it("press-then-release inside row 2 selects option B", function()
    local last
    local r = RadioGroup.new({
      x = 0, y = 0, w = 320, row_h = 32,
      options = {
        { id = "a", label = "Alpha" },
        { id = "b", label = "Beta" },
        { id = "c", label = "Gamma" },
      },
      value = "a",
      on_change = function(v) last = v end,
    })
    r:mousepressed(50, 40, 1)
    r:mousereleased(50, 40, 1)
    assert.is_equal("b", r:get_value())
    assert.is_equal("b", last)
  end)

  it("press inside one row then release on a different row does not change value", function()
    local r = fixture()
    r:mousepressed(50, 10, 1)
    r:mousereleased(50, 50, 1)
    assert.is_equal("a", r:get_value())
  end)

  it("non-primary button does not select", function()
    local r = fixture()
    r:mousepressed(50, 40, 2)
    r:mousereleased(50, 40, 2)
    assert.is_equal("a", r:get_value())
  end)

  it("height() returns row_h * number of options", function()
    local r = fixture()
    assert.is_equal(3 * 32, r:height())
  end)

  it("clicks below the last row are ignored", function()
    local r = fixture()
    r:mousepressed(50, 200, 1)
    r:mousereleased(50, 200, 1)
    assert.is_equal("a", r:get_value())
  end)
end)
