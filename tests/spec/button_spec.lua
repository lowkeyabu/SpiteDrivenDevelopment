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
    assert.is_false(b:hit(110, 60))          -- one past bottom-right
  end)

  it("press-then-release inside fires the click handler", function()
    local clicked = false
    local b = Button.new({
      x = 0, y = 0, w = 50, h = 50,
      on_click = function() clicked = true end,
    })
    b:mousepressed(10, 10, 1)
    b:mousereleased(10, 10, 1)
    assert.is_true(clicked)
  end)

  it("press inside then release outside does not fire", function()
    local clicked = false
    local b = Button.new({
      x = 0, y = 0, w = 50, h = 50,
      on_click = function() clicked = true end,
    })
    b:mousepressed(10, 10, 1)
    b:mousereleased(99, 99, 1)
    assert.is_false(clicked)
  end)

  it("press outside then release inside does not fire", function()
    local clicked = false
    local b = Button.new({
      x = 0, y = 0, w = 50, h = 50,
      on_click = function() clicked = true end,
    })
    b:mousepressed(99, 99, 1)
    b:mousereleased(10, 10, 1)
    assert.is_false(clicked)
  end)

  it("non-primary mouse buttons do not fire on_click", function()
    local clicked = false
    local b = Button.new({
      x = 0, y = 0, w = 50, h = 50,
      on_click = function() clicked = true end,
    })
    b:mousepressed(10, 10, 2)
    b:mousereleased(10, 10, 2)
    assert.is_false(clicked)
  end)

  it("defaults label to an empty string, on_click to a no-op, font_size to 'md'", function()
    local b = Button.new({ x = 0, y = 0, w = 10, h = 10 })
    assert.is_equal("", b.label)
    assert.is_equal("md", b.font_size)
    assert.has_no.errors(function()
      b:mousepressed(5, 5, 1)
      b:mousereleased(5, 5, 1)
    end)
  end)

  it("accepts a font_size override via constructor", function()
    local b = Button.new({ x = 0, y = 0, w = 10, h = 10, font_size = "lg" })
    assert.is_equal("lg", b.font_size)
  end)

  it("mousemoved updates the hover flag", function()
    local b = Button.new({ x = 0, y = 0, w = 50, h = 50 })
    assert.is_false(b.hover)
    b:mousemoved(10, 10)
    assert.is_true(b.hover)
    b:mousemoved(99, 99)
    assert.is_false(b.hover)
  end)
end)
