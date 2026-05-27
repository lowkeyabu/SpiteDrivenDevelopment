local Button = require("src.ui.components.button")

describe("Button", function()
  it("hit returns true for a point inside its bounds", function()
    local b = Button.new({ x = 10, y = 20, w = 100, h = 40, label = "ok" })
    assert.is_true(b:hit(50, 30))
    assert.is_true(b:hit(10, 20))            -- top-left corner
    assert.is_true(b:hit(109, 59))           -- bottom-right inside corner
  end)

  it("hit returns false for points outside", function()
    local b = Button.new({ x = 10, y = 20, w = 100, h = 40, label = "ok" })
    assert.is_false(b:hit(0, 0))
    assert.is_false(b:hit(120, 30))
    assert.is_false(b:hit(50, 5))
    assert.is_false(b:hit(50, 80))
    assert.is_false(b:hit(110, 60))         -- one past bottom-right
  end)

  it("invokes the click handler when clicked inside", function()
    local clicked = false
    local b = Button.new({
      x = 0, y = 0, w = 50, h = 50,
      label = "ok",
      on_click = function() clicked = true end,
    })
    b:click(10, 10)
    assert.is_true(clicked)
  end)

  it("does not invoke the handler when clicked outside", function()
    local clicked = false
    local b = Button.new({
      x = 0, y = 0, w = 50, h = 50,
      label = "ok",
      on_click = function() clicked = true end,
    })
    b:click(99, 99)
    assert.is_false(clicked)
  end)

  it("defaults label to an empty string and on_click to a no-op", function()
    local b = Button.new({ x = 0, y = 0, w = 10, h = 10 })
    assert.is_equal("", b.label)
    assert.has_no.errors(function() b:click(5, 5) end)
  end)
end)
