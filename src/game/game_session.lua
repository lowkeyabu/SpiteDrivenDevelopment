-- Per-game runtime state. Sprint phase machine, AP, turn rotation,
-- promotions, end-trigger detection.

local Deck = require("src.game.deck")
local Session = require("src.game.session")
local Ticket = require("src.game.ticket")

local GameSession = {}
GameSession.__index = GameSession

local INITIAL_STATS = {
  credit = 0,
  clout = 0,
  tech_debt = 0,
  linkedin_score = 0,
  title = "IC1",
  sprint_shipped = 0,
  total_shipped = 0,
}

local function init_players(session)
  local players = {}
  local ap = session.config.ap_per_turn
  for i, p in ipairs(session.players) do
    local rec = { idx = i, name = p.name, color = p.color, ap = ap }
    for k, v in pairs(INITIAL_STATS) do rec[k] = v end
    rec.humble_brag_log = {}
    table.insert(players, rec)
  end
  return players
end

local function build_ticket_deck(ticket_defs, rng)
  local cards = {}
  for _, def in ipairs(ticket_defs) do
    table.insert(cards, def)
  end
  local d = Deck.new(cards)
  if rng then d:shuffle(rng) end
  return d
end

local function new(opts)
  local self = setmetatable({
    session = opts.session,
    rng = opts.rng,
    ticket_deck = build_ticket_deck(opts.ticket_defs, opts.rng),
    backlog = {},
    in_progress = {},
    review = {},
    done = {},
    players = init_players(opts.session),
    current_actor = 1,
    turn_count = 1,
    sprint_number = 1,
    sprint_phase = "planning",
    sprint_turn_count = 0,
    dilemmas_drawn = {},
    ended = false,
    end_reason = nil,
  }, GameSession)
  return self
end

function GameSession:tickets_per_sprint()
  return 2 * #self.players
end

function GameSession:plan_sprint()
  assert(self.sprint_phase == "planning",
    "plan_sprint requires planning phase, got " .. self.sprint_phase)
  local n = self:tickets_per_sprint()
  local defs = self.ticket_deck:draw_n(n)
  for _, def in ipairs(defs) do
    table.insert(self.backlog, Ticket.new(def))
  end
  for _, p in ipairs(self.players) do
    p.sprint_shipped = 0
    p.ap = self.session.config.ap_per_turn
  end
  self.sprint_phase = "turns"
  self.sprint_turn_count = 0
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

local function require_turns_phase(self)
  assert(self.sprint_phase == "turns",
    "action requires turns phase, got " .. self.sprint_phase)
end

local function require_ap(self)
  local actor = self.players[self.current_actor]
  assert(actor.ap > 0, "actor " .. tostring(self.current_actor) .. " has no AP")
end

local function spend_ap(self)
  self.players[self.current_actor].ap =
    self.players[self.current_actor].ap - 1
end

function GameSession:claim(id)
  require_turns_phase(self); require_ap(self)
  local t = remove_by_id(self.backlog, id)
  assert(t, "no such ticket in backlog: " .. tostring(id))
  t:claim(self.current_actor)
  table.insert(self.in_progress, t)
  spend_ap(self)
end

function GameSession:work(id)
  require_turns_phase(self); require_ap(self)
  local t = find_in(self.in_progress, id)
  assert(t, "no such ticket in in_progress: " .. tostring(id))
  assert(t.owner == self.current_actor,
    "actor cannot work on someone else's ticket")
  t:work()
  spend_ap(self)
end

function GameSession:submit_for_review(id)
  require_turns_phase(self); require_ap(self)
  local t = remove_by_id(self.in_progress, id)
  assert(t, "no such ticket in in_progress: " .. tostring(id))
  t:submit_for_review()
  table.insert(self.review, t)
  spend_ap(self)
end

function GameSession:do_meeting()
  require_turns_phase(self); require_ap(self)
  self.players[self.current_actor].clout =
    self.players[self.current_actor].clout + 2
  spend_ap(self)
end

function GameSession:approve(id)
  require_turns_phase(self); require_ap(self)
  local t = find_in(self.review, id)
  assert(t, "no such ticket in review: " .. tostring(id))
  assert(self.current_actor ~= t.owner, "actor cannot approve own ticket")
  remove_by_id(self.review, id)
  t:approve(self.current_actor)
  local owner = self.players[t.owner]
  owner.credit = owner.credit + t.reward
  owner.sprint_shipped = owner.sprint_shipped + 1
  owner.total_shipped = owner.total_shipped + 1
  self.players[self.current_actor].credit =
    self.players[self.current_actor].credit + 1
  table.insert(self.done, t)
  spend_ap(self)
end

function GameSession:reject(id)
  require_turns_phase(self); require_ap(self)
  local t = find_in(self.review, id)
  assert(t, "no such ticket in review: " .. tostring(id))
  assert(self.current_actor ~= t.owner, "actor cannot reject own ticket")
  remove_by_id(self.review, id)
  t:reject()
  table.insert(self.in_progress, t)
  spend_ap(self)
end

function GameSession:sprint_should_end()
  if self.sprint_turn_count >= self.session.config.turn_cap then return true end
  if #self.backlog == 0 and #self.in_progress == 0 and #self.review == 0 then
    return true
  end
  return false
end

function GameSession:end_turn()
  if self.sprint_phase ~= "turns" then return end
  local n = #self.players
  self.current_actor = (self.current_actor % n) + 1
  self.players[self.current_actor].ap = self.session.config.ap_per_turn
  self.turn_count = self.turn_count + 1
  self.sprint_turn_count = self.sprint_turn_count + 1
  if self:sprint_should_end() then
    self.sprint_phase = "retro"
  end
end

function GameSession:retro_and_promote()
  assert(self.sprint_phase == "retro",
    "retro_and_promote requires retro phase, got " .. self.sprint_phase)
  local top_idx, top_count = nil, -1
  for i, p in ipairs(self.players) do
    if p.sprint_shipped > top_count then
      top_idx, top_count = i, p.sprint_shipped
    end
  end
  if top_idx and top_count > 0 then
    local p = self.players[top_idx]
    local next_t = Session.next_title(p.title)
    if next_t then p.title = next_t end
  end
end

function GameSession:end_trigger_fired()
  local trigger = self.session.config.end_trigger
  if trigger == "first_to_csuite_or_5_sprints" then
    for _, p in ipairs(self.players) do
      if p.title == "C-suite" then return true, "csuite" end
    end
    if self.sprint_number >= 5 then return true, "5_sprints" end
  elseif trigger == "fixed_n_sprints_3" then
    if self.sprint_number >= 3 then return true, "fixed_3" end
  elseif trigger == "fixed_n_sprints_5" then
    if self.sprint_number >= 5 then return true, "fixed_5" end
  elseif trigger == "fixed_n_sprints_7" then
    if self.sprint_number >= 7 then return true, "fixed_7" end
  elseif trigger == "first_to_comp_target" then
    local target = self.session.config.comp_target
    for _, p in ipairs(self.players) do
      if p.credit >= target then return true, "comp_target" end
    end
  end
  return false, nil
end

function GameSession:has_more_tickets()
  return self.ticket_deck:remaining() > 0
end

function GameSession:advance_phase()
  if self.sprint_phase == "planning" then
    self:plan_sprint()
  elseif self.sprint_phase == "retro" then
    self:retro_and_promote()
    local fired, reason = self:end_trigger_fired()
    self.sprint_number = self.sprint_number + 1
    if fired or not self:has_more_tickets() then
      self.ended = true
      self.end_reason = reason or "deck_exhausted"
    else
      self.sprint_phase = "planning"
    end
  end
end

function GameSession:shipped_count()
  return #self.done
end

return {
  new = new,
}
