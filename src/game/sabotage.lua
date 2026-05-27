-- Sabotage engine. Loads the seed deck, exposes filter + play APIs.

local cards = require("data.sabotage")

local Sabotage = {}

local function find(id)
  for _, c in ipairs(cards) do
    if c.id == id then return c end
  end
  return nil
end

local function tier_for_title(title)
  if title == "IC1" or title == "IC2" or title == "Senior" then return 1 end
  if title == "Staff" or title == "Principal" then return 2 end
  if title == "Manager" or title == "Sr Manager" or title == "Director" then return 3 end
  return 4
end

function Sabotage.all()
  local out = {}
  for _, c in ipairs(cards) do table.insert(out, c) end
  return out
end

function Sabotage.find(id)
  return find(id)
end

function Sabotage.available_for(gs)
  if not gs.session.config.tier_gating then
    return Sabotage.all()
  end
  local actor = gs.players[gs.current_actor]
  local cap = tier_for_title(actor.title)
  local out = {}
  for _, c in ipairs(cards) do
    if c.tier <= cap then table.insert(out, c) end
  end
  return out
end

function Sabotage.can_afford(gs, card)
  local actor = gs.players[gs.current_actor]
  return actor.clout >= card.clout
end

function Sabotage.play(gs, card_id, target)
  local card = find(card_id)
  assert(card, "unknown sabotage card: " .. tostring(card_id))
  local actor_idx = gs.current_actor
  local actor = gs.players[actor_idx]
  assert(actor.clout >= card.clout,
    "insufficient clout for " .. card.id .. " (need " .. card.clout .. ", have " .. actor.clout .. ")")
  actor.clout = actor.clout - card.clout
  actor.linkedin_score = actor.linkedin_score + card.ls_delta
  actor.archetype_counters.saboteur =
    (actor.archetype_counters.saboteur or 0) + 1
  local tier3_plus = { pip = true, reorg = true, skip_level = true,
                       fire = true, rto_mandate = true, pivot_ai = true }
  if tier3_plus[card.id] then
    actor.archetype_counters.ladder_climber =
      (actor.archetype_counters.ladder_climber or 0) + 1
  end
  if card.id == "slack_dm_manager" then
    actor.archetype_counters.snitch =
      (actor.archetype_counters.snitch or 0) + 1
  end
  if card.id == "credit_steal" then
    actor.archetype_counters.credit_thief =
      (actor.archetype_counters.credit_thief or 0) + 1
  end
  if card.id == "legacy_auth" then
    actor.archetype_counters.debt_dumper =
      (actor.archetype_counters.debt_dumper or 0) + 1
  end
  card.effect(gs, actor_idx, target or {})
end

return Sabotage
