local cards = require("data.capstones")

local Capstones = {}

local function find_for(archetype)
  for _, c in ipairs(cards) do
    if c.archetype == archetype then return c end
  end
  return nil
end

function Capstones.all()
  local out = {}
  for _, c in ipairs(cards) do table.insert(out, c) end
  return out
end

function Capstones.classify(player)
  local counters = player.archetype_counters or {}
  local archetypes = {
    "ladder_climber", "snitch", "credit_thief",
    "debt_dumper", "meeting_farmer",
  }
  local best, best_count = nil, 0
  for _, a in ipairs(archetypes) do
    local n = counters[a] or 0
    if n > best_count then
      best, best_count = a, n
    elseif n == best_count and n > 0 then
      if best and a < best then best = a end
    end
  end
  if best == nil then return "clean_operator" end
  return best
end

function Capstones.draw_for(archetype, rng)
  return find_for(archetype) or find_for("clean_operator")
end

function Capstones.resolve(gs, player_idx, capstone, choice)
  assert(choice == "a" or choice == "b", "choice must be 'a' or 'b'")
  local opt = (choice == "a") and capstone.option_a or capstone.option_b
  opt.effect(gs, player_idx)
  local p = gs.players[player_idx]
  p.linkedin_score = p.linkedin_score + (opt.ls_delta or 0)
  if opt.humble_brag then
    table.insert(p.humble_brag_log, opt.humble_brag)
  end
  p.capstone_done = true
end

return Capstones
