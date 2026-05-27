-- Per-game runtime state. Wraps the pre-game Session (config + players)
-- with the live board columns, per-player gameplay stats (incl. AP),
-- and the current actor + turn counter. Constructed once when
-- entering the game state; never persisted across game restarts.

local Ticket = require("src.game.ticket")

local GameSession = {}
GameSession.__index = GameSession

local INITIAL_STATS = {
  credit = 0,
  clout = 0,
  tech_debt = 0,
  linkedin_score = 0,
  title = "IC1",
}

local function init_players(session)
  local players = {}
  local ap = session.config.ap_per_turn
  for i, p in ipairs(session.players) do
    local rec = {
      idx = i,
      name = p.name,
      color = p.color,
      ap = ap,
    }
    for k, v in pairs(INITIAL_STATS) do rec[k] = v end
    table.insert(players, rec)
  end
  return players
end

local function build_backlog(ticket_defs)
  local out = {}
  for _, def in ipairs(ticket_defs) do
    table.insert(out, Ticket.new(def))
  end
  return out
end

local function new(opts)
  local session = opts.session
  local rng = opts.rng
  local backlog = build_backlog(opts.ticket_defs)
  if rng then
    rng:shuffle(backlog)
  end
  return setmetatable({
    session = session,
    rng = rng,
    backlog = backlog,
    in_progress = {},
    review = {},
    done = {},
    players = init_players(session),
    current_actor = 1,
    turn_count = 1,
  }, GameSession)
end

local function remove_by_id(list, id)
  for i, t in ipairs(list) do
    if t.id == id then return table.remove(list, i) end
  end
  return nil
end

local function find_in(list, id)
  for _, t in ipairs(list) do
    if t.id == id then return t end
  end
  return nil
end

function GameSession:find(id)
  return find_in(self.backlog, id)
      or find_in(self.in_progress, id)
      or find_in(self.review, id)
      or find_in(self.done, id)
end

local function require_ap(self)
  local actor = self.players[self.current_actor]
  assert(actor.ap > 0, "actor " .. tostring(self.current_actor) .. " has no AP")
end

local function spend_ap(self)
  local actor = self.players[self.current_actor]
  actor.ap = actor.ap - 1
end

function GameSession:claim(ticket_id)
  require_ap(self)
  local t = remove_by_id(self.backlog, ticket_id)
  assert(t, "no such ticket in backlog: " .. tostring(ticket_id))
  t:claim(self.current_actor)
  table.insert(self.in_progress, t)
  spend_ap(self)
end

function GameSession:work(ticket_id)
  require_ap(self)
  local t = find_in(self.in_progress, ticket_id)
  assert(t, "no such ticket in in_progress: " .. tostring(ticket_id))
  assert(t.owner == self.current_actor,
    "actor " .. tostring(self.current_actor) ..
    " cannot work on ticket owned by " .. tostring(t.owner))
  t:work()
  spend_ap(self)
end

function GameSession:submit_for_review(ticket_id)
  require_ap(self)
  local t = remove_by_id(self.in_progress, ticket_id)
  assert(t, "no such ticket in in_progress: " .. tostring(ticket_id))
  t:submit_for_review()
  table.insert(self.review, t)
  spend_ap(self)
end

function GameSession:approve(ticket_id)
  require_ap(self)
  local t = find_in(self.review, ticket_id)
  assert(t, "no such ticket in review: " .. tostring(ticket_id))
  assert(self.current_actor ~= t.owner,
    "actor cannot approve own ticket")
  remove_by_id(self.review, ticket_id)
  t:approve(self.current_actor)
  local owner = self.players[t.owner]
  owner.credit = owner.credit + t.reward
  local reviewer = self.players[self.current_actor]
  reviewer.credit = reviewer.credit + 1
  table.insert(self.done, t)
  spend_ap(self)
end

function GameSession:reject(ticket_id)
  require_ap(self)
  local t = find_in(self.review, ticket_id)
  assert(t, "no such ticket in review: " .. tostring(ticket_id))
  assert(self.current_actor ~= t.owner,
    "actor cannot reject own ticket")
  remove_by_id(self.review, ticket_id)
  t:reject()
  table.insert(self.in_progress, t)
  spend_ap(self)
end

function GameSession:end_turn()
  local n = #self.players
  self.current_actor = (self.current_actor % n) + 1
  self.players[self.current_actor].ap = self.session.config.ap_per_turn
  self.turn_count = self.turn_count + 1
end

function GameSession:shipped_count()
  return #self.done
end

return {
  new = new,
}
