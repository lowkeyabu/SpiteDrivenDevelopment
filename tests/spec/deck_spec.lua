local Deck = require("src.game.deck")
local RNG = require("src.util.rng")

describe("Deck", function()
  it("starts with the cards in insertion order", function()
    local d = Deck.new({ "a", "b", "c" })
    assert.is_equal("a", d:peek())
    assert.is_equal(3, d:remaining())
  end)

  it("draw returns the top card and decreases remaining", function()
    local d = Deck.new({ "a", "b", "c" })
    assert.is_equal("a", d:draw())
    assert.is_equal(2, d:remaining())
    assert.is_equal("b", d:draw())
    assert.is_equal("c", d:draw())
    assert.is_equal(0, d:remaining())
  end)

  it("draw returns nil when empty", function()
    local d = Deck.new({})
    assert.is_nil(d:draw())
    assert.is_nil(d:peek())
  end)

  it("shuffle reorders deterministically given a seeded RNG", function()
    local a = Deck.new({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 })
    local b = Deck.new({ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 })
    a:shuffle(RNG.new(99))
    b:shuffle(RNG.new(99))
    while a:remaining() > 0 do
      assert.is_equal(a:draw(), b:draw())
    end
  end)

  it("shuffle preserves the set of cards", function()
    local d = Deck.new({ "x", "y", "z", "w" })
    d:shuffle(RNG.new(42))
    local out = {}
    while d:remaining() > 0 do table.insert(out, d:draw()) end
    table.sort(out)
    assert.are.same({ "w", "x", "y", "z" }, out)
  end)

  it("draw_n returns at most n cards from the top", function()
    local d = Deck.new({ "a", "b", "c", "d", "e" })
    local taken = d:draw_n(3)
    assert.are.same({ "a", "b", "c" }, taken)
    assert.is_equal(2, d:remaining())
  end)

  it("draw_n caps at the deck size", function()
    local d = Deck.new({ "a", "b" })
    local taken = d:draw_n(5)
    assert.are.same({ "a", "b" }, taken)
    assert.is_equal(0, d:remaining())
  end)
end)
