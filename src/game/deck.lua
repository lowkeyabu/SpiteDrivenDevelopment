-- Generic deck: a flat list of cards with shuffle / draw / draw_n /
-- peek / remaining. "Top" is index 1 (so draw removes index 1 and
-- shifts the rest).

local Deck = {}
Deck.__index = Deck

local function new(cards)
  local copy = {}
  for i, c in ipairs(cards or {}) do copy[i] = c end
  return setmetatable({ _cards = copy }, Deck)
end

function Deck:remaining()
  return #self._cards
end

function Deck:peek()
  return self._cards[1]
end

function Deck:draw()
  if #self._cards == 0 then return nil end
  return table.remove(self._cards, 1)
end

function Deck:draw_n(n)
  local out = {}
  for _ = 1, n do
    local c = self:draw()
    if c == nil then break end
    table.insert(out, c)
  end
  return out
end

function Deck:shuffle(rng)
  rng:shuffle(self._cards)
end

return {
  new = new,
}
