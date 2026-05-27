local cards = require("data.dilemmas")

local Dilemmas = {}

function Dilemmas.all()
  local out = {}
  for _, c in ipairs(cards) do table.insert(out, c) end
  return out
end

function Dilemmas.find(id)
  for _, c in ipairs(cards) do
    if c.id == id then return c end
  end
  return nil
end

function Dilemmas.draw(rng, exclude)
  exclude = exclude or {}
  local pool = {}
  for _, c in ipairs(cards) do
    if not exclude[c.id] then table.insert(pool, c) end
  end
  if #pool == 0 then return nil end
  if rng then rng:shuffle(pool) end
  return pool[1]
end

function Dilemmas.resolve(gs, dilemma, choice)
  assert(choice == "a" or choice == "b", "choice must be 'a' or 'b'")
  local opt = (choice == "a") and dilemma.option_a or dilemma.option_b
  opt.effect(gs, gs.current_actor)
  local actor = gs.players[gs.current_actor]
  actor.linkedin_score = actor.linkedin_score + (opt.ls_delta or 0)
  if opt.humble_brag then
    table.insert(actor.humble_brag_log, opt.humble_brag)
  end
  gs.dilemmas_drawn[dilemma.id] = true
end

return Dilemmas
