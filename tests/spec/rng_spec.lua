local RNG = require("src.util.rng")

describe("RNG", function()
  it("produces the same sequence from the same seed", function()
    local a = RNG.new(42)
    local b = RNG.new(42)
    for _ = 1, 100 do
      assert.is_equal(a:random(), b:random())
    end
  end)

  it("produces different sequences from different seeds", function()
    local a = RNG.new(1)
    local b = RNG.new(2)
    local same = true
    for _ = 1, 100 do
      if a:random() ~= b:random() then same = false; break end
    end
    assert.is_false(same)
  end)

  it("returns integers within an inclusive range via random(min, max)", function()
    local rng = RNG.new(7)
    for _ = 1, 1000 do
      local n = rng:random(1, 6)
      assert.is_true(n >= 1 and n <= 6)
      assert.is_equal(math.floor(n), n)
    end
  end)

  it("shuffles a list deterministically given a seed", function()
    local function copy(t) local r = {}; for i, v in ipairs(t) do r[i] = v end; return r end
    local input = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
    local rng_a = RNG.new(123)
    local rng_b = RNG.new(123)
    local a = rng_a:shuffle(copy(input))
    local b = rng_b:shuffle(copy(input))
    assert.are.same(a, b)
  end)

  it("shuffle preserves elements", function()
    local rng = RNG.new(99)
    local input = { "x", "y", "z", "w" }
    local out = rng:shuffle({ "x", "y", "z", "w" })
    table.sort(input)
    table.sort(out)
    assert.are.same(input, out)
  end)
end)
