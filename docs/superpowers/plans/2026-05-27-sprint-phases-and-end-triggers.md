# Sprint Phases + Promotions + End Triggers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Checkbox steps. Direct-to-main; subagents commit, controller pushes.

**Goal:** Wrap the per-turn ticket flow with a real sprint structure. After this plan, a game cycles through `Sprint Planning → Player Turns → Retro & Promo` until an end trigger fires; the top shipper of each sprint gets promoted; players advance through the career ladder IC1 → C-suite; reaching the configured end trigger auto-transitions to the end screen.

**Architecture:** `GameSession` grows a `ticket_deck` (the full draw pile, separate from the per-sprint `backlog`), a sprint phase state machine (`sprint_number`, `sprint_phase` in `"planning"|"turns"|"retro"`, `sprint_turn_count`), a `plan_sprint()` method that auto-draws N tickets, a `retro_and_promote()` that promotes the top shipper, an `end_trigger_fired()` predicate that consults `config.end_trigger`, and an `advance_phase()` driver. `Session` adds a `TITLES` constant. The game state shows the sprint phase in the top bar and auto-transitions on end-trigger fire.

**Tech Stack:** Lua 5.1+, Love2D 11.x, busted.

**Scope:** Plan 6 of 9. Builds on Plan 5's turn rotation + AP.

**Spec reference:** §6.1 (Sprint phases), §6.3 (End triggers), §7 (Career ladder).

---

## File Map

```
.
├── src/
│   ├── game/
│   │   ├── game_session.lua            (modified — sprint state machine + promotion + end triggers)
│   │   └── session.lua                 (modified — TITLES + tickets_per_sprint helper)
│   └── states/
│       └── game.lua                    (modified — auto-advance phases + sprint info in HUD + end-trigger auto-transition)
└── tests/
    └── spec/
        ├── game_session_spec.lua       (extended — sprint + promotion + end-trigger tests)
        └── session_spec.lua            (extended — TITLES catalog test)
```

---

## Conventions

Same as prior plans. Direct-to-main.

---

### Task 1: Add TITLES catalog + promotion helper to Session

**Files:**
- Modify: `src/game/session.lua` (add `TITLES` constant + `next_title(current)` helper)
- Modify: `tests/spec/session_spec.lua` (append tests)

- [ ] **Step 1: Append tests to `tests/spec/session_spec.lua`**

Inside the existing `describe("Session", function() ... end)` block, before its closing `end)`:

```lua
  it("exposes TITLES catalog from IC1 to C-suite", function()
    local titles = Session.TITLES
    assert.is_table(titles)
    assert.is_equal("IC1", titles[1])
    assert.is_equal("C-suite", titles[#titles])
    assert.is_equal(10, #titles)
  end)

  it("next_title returns the next rung up; nil at C-suite", function()
    assert.is_equal("IC2", Session.next_title("IC1"))
    assert.is_equal("C-suite", Session.next_title(Session.TITLES[#Session.TITLES - 1]))
    assert.is_nil(Session.next_title("C-suite"))
  end)

  it("next_title raises on unknown title", function()
    assert.has_error(function() Session.next_title("InventedTitle") end)
  end)
```

- [ ] **Step 2: Modify `src/game/session.lua`** — add the `TITLES` constant and `next_title` helper.

Find the `Session.PLAYER_PALETTE = { ... }` block. Immediately after it (before `local MAX_NAME = 20`), insert:

```lua
-- Career ladder, IC1 → C-suite. Promotions advance one rung per sprint
-- (top shipper). Reaching C-suite triggers the "first_to_csuite_or_..."
-- end trigger.
Session.TITLES = {
  "IC1", "IC2", "Senior", "Staff", "Principal",
  "Manager", "Sr Manager", "Director", "VP", "C-suite",
}

local function next_title(current)
  for i, t in ipairs(Session.TITLES) do
    if t == current then
      return Session.TITLES[i + 1]
    end
  end
  error("unknown title: " .. tostring(current))
end
```

Then in the final `return` table, add `TITLES = Session.TITLES,` and `next_title = next_title,`. The full return block becomes:

```lua
return {
  new = new,
  MODES = Session.MODES,
  END_TRIGGERS = Session.END_TRIGGERS,
  PLAYER_PALETTE = Session.PLAYER_PALETTE,
  TITLES = Session.TITLES,
  next_title = next_title,
}
```

- [ ] **Step 3:** `busted` → 129 successes (126 + 3 new).

- [ ] **Step 4: Commit**

```
Add TITLES catalog and next_title helper

Session now exposes the 10-rung career ladder (IC1 → C-suite) and a
next_title(current) helper used by GameSession's promotion logic in
Plan 6. Raises on unknown title; returns nil at C-suite to signal
"already at top".
```

---

### Task 2: Sprint phases + promotions + end-trigger detection in GameSession

**Files:**
- Modify: `src/game/game_session.lua`
- Modify: `tests/spec/game_session_spec.lua`

Big task. Adds:
- `ticket_deck` (Deck of ticket defs, separate from `backlog`)
- `sprint_number = 1`, `sprint_phase = "planning"`, `sprint_turn_count = 0`
- `plan_sprint()` — moves to `"turns"` phase; draws `tickets_per_sprint()` tickets from the deck into `backlog`; clears `sprint_shipped` counter per player
- `tickets_per_sprint()` — returns `2 * player_count`
- `sprint_should_end()` — true when (a) backlog empty AND in_progress empty AND review empty, OR (b) sprint_turn_count >= config.turn_cap
- `retro_and_promote()` — at retro phase: finds the top shipper, advances their title, increments sprint_number, resets sprint_turn_count
- `end_trigger_fired()` — returns true + reason string when the configured trigger has fired
- `advance_phase()` — the driver: planning → turns; on sprint_should_end → retro → promote → check end trigger → planning or done

Track per-sprint shipped via a counter that resets on `plan_sprint()`. Approve increments `players[t.owner].sprint_shipped` (in addition to existing total/credit).

End_turn now also increments `sprint_turn_count` and, if `sprint_should_end()`, transitions to retro phase.

- [ ] **Step 1: Read the current `src/game/game_session.lua`** to know exact structure.

- [ ] **Step 2: Replace `src/game/game_session.lua`** with this:

```lua
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
  -- Find top shipper this sprint; ties broken by lower player index.
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

-- Drives the sprint phase machine.
-- After plan(): turns. After end_turn() sets retro: caller advances.
-- After retro: promote, check end trigger, then either move to planning
-- of next sprint or set ended=true.
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

function GameSession:has_more_tickets()
  return self.ticket_deck:remaining() > 0
end

function GameSession:shipped_count()
  return #self.done
end

return {
  new = new,
}
```

- [ ] **Step 3: Append tests to `tests/spec/game_session_spec.lua`** (inside the "focused" describe block, before its closing `end)`):

```lua
  it("starts in planning phase with sprint_number = 1 and empty backlog", function()
    local g = fresh()
    assert.is_equal("planning", g.sprint_phase)
    assert.is_equal(1, g.sprint_number)
    assert.is_equal(0, #g.backlog)
  end)

  it("plan_sprint draws 2 * player_count tickets into the backlog", function()
    local g = fresh()
    g:plan_sprint()
    assert.is_equal(4, #g.backlog)  -- 2 players * 2
    assert.is_equal("turns", g.sprint_phase)
  end)

  it("actions raise outside the turns phase", function()
    local g = fresh()
    -- still in planning
    assert.has_error(function() g:claim("anything") end)
  end)

  it("end_turn transitions to retro when sprint_should_end", function()
    local g = fresh()
    g:plan_sprint()
    -- Force sprint_turn_count above turn_cap.
    g.sprint_turn_count = g.session.config.turn_cap
    g:end_turn()
    assert.is_equal("retro", g.sprint_phase)
  end)

  it("retro_and_promote advances the top shipper's title", function()
    local g = fresh()
    g:plan_sprint()
    g.players[1].sprint_shipped = 3
    g.players[2].sprint_shipped = 1
    g.sprint_phase = "retro"
    g:retro_and_promote()
    assert.is_equal("IC2", g.players[1].title)
    assert.is_equal("IC1", g.players[2].title)
  end)

  it("retro_and_promote with no shipped players does not promote", function()
    local g = fresh()
    g:plan_sprint()
    g.sprint_phase = "retro"
    g:retro_and_promote()
    assert.is_equal("IC1", g.players[1].title)
  end)

  it("end_trigger_fired detects fixed_5_sprints after 5 sprints", function()
    local g = fresh()
    g.session.config.end_trigger = "fixed_n_sprints_5"
    g.sprint_number = 5
    local fired = g:end_trigger_fired()
    assert.is_true(fired)
  end)

  it("end_trigger_fired detects first_to_comp_target", function()
    local g = fresh()
    g.session.config.end_trigger = "first_to_comp_target"
    g.session.config.comp_target = 10
    g.players[1].credit = 12
    local fired = g:end_trigger_fired()
    assert.is_true(fired)
  end)

  it("end_trigger_fired detects first_to_csuite_or_5_sprints by csuite", function()
    local g = fresh()
    g.players[1].title = "C-suite"
    local fired = g:end_trigger_fired()
    assert.is_true(fired)
  end)

  it("advance_phase from planning runs plan_sprint", function()
    local g = fresh()
    g:advance_phase()
    assert.is_equal("turns", g.sprint_phase)
    assert.is_equal(4, #g.backlog)
  end)

  it("advance_phase from retro promotes, increments sprint_number, replans or ends", function()
    local g = fresh()
    g:plan_sprint()
    g.players[1].sprint_shipped = 1
    g.sprint_phase = "retro"
    g:advance_phase()
    assert.is_equal("IC2", g.players[1].title)
    assert.is_equal(2, g.sprint_number)
    -- Default end trigger is "first_to_csuite_or_5_sprints" — neither fired,
    -- and deck has tickets remaining (originally 3 - 4 drawn = ... wait we
    -- only had 3, so backlog drew 3 and deck is empty). has_more_tickets()
    -- is false → ended = true with reason "deck_exhausted".
    assert.is_true(g.ended)
  end)
```

(Total: 11 new tests.)

Plus REPLACE existing tests that no longer work because actions require `turns` phase. Find each test that calls `g:claim(...)` directly after `fresh()` and INSERT `g:plan_sprint()` between them:

- "claim removes the ticket from backlog and pushes it onto in_progress"
- "claim raises when the id is not in the backlog"
- "work decrements points_remaining ..."
- "work raises when the ticket is not owned by the actor"
- "submit_for_review moves a 0-point in_progress ticket to review"
- "approve moves a review ticket to done and credits owner + reviewer"
- "reject sends the ticket back to in_progress with points reset"
- "find finds a ticket by id across all columns"
- "returns nil when finding an unknown id" — no action calls, leave alone
- "shipped_count returns the number of tickets in done"
- "seeds each player with config.ap_per_turn AP" — no action calls
- "claim decrements the actor's AP by 1"
- "work decrements AP by 1 per call"
- "action raises when actor has no AP"
- "end_turn advances current_actor and refreshes the new actor's AP"
- "end_turn wraps around at the last player" — calls end_turn before any action; sprint_phase is still planning so end_turn returns early. Need to plan_sprint first.
- "end_turn refreshes the new actor's AP even if it was nonzero"
- "approve requires reviewer != ticket owner"
- "reject requires reviewer != ticket owner"

For each, insert `g:plan_sprint()` between `local g = fresh()` and the first action call. For `end_turn wraps around` — also needs plan_sprint() so end_turn actually advances.

- [ ] **Step 4:** `busted` → confirm all tests pass. Target: 129 (after T1) + 11 new = 140.

If a test fails because of sprint-related counter changes, audit and fix.

- [ ] **Step 5: Commit**

```
Add sprint phases, promotions, and end-trigger detection to GameSession

GameSession now has a sprint phase machine (planning → turns → retro),
a separate ticket_deck (per-sprint backlog is drawn at plan_sprint()),
sprint_shipped + total_shipped per-player counters, retro_and_promote
(top shipper advances one title rung), end_trigger_fired (consults
config.end_trigger), and advance_phase that drives the machine.
All action methods now also require sprint_phase == "turns".
end_turn auto-transitions to retro when sprint_should_end (turn_cap
hit or all columns clear).
```

---

### Task 3: Wire sprint phase + auto-end into game state

**Files:**
- Modify: `src/states/game.lua`

Changes:
- On `enter`, after constructing the GameSession, call `advance_phase()` to enter the first sprint's `turns` phase.
- Top bar adds `Sprint <n>` indicator.
- After every action and end_turn, check `gs.ended`. If true, transition to end_screen.
- After end_turn transitions to retro: auto-call `advance_phase()` to run retro + planning + start new turns. (Single-step from user's perspective.)

- [ ] **Step 1: Read and modify `src/states/game.lua`**

Locate the `M:enter` function. After `self.session:attach_game_session(self.game_session)` and BEFORE `build_layout(self, ...)`, insert:

```lua
  -- Start the first sprint (or resume mid-sprint if a game_session was
  -- already attached and we're re-entering).
  if self.game_session.sprint_phase == "planning" then
    self.game_session:advance_phase()
  end
```

Locate the End Turn button add. Change its callback to:

```lua
  add("End Turn", function()
    gs:end_turn()
    kanban.selected_id = nil
    -- If end_turn transitioned to retro, run the retro+plan flow in one beat.
    while gs.sprint_phase == "retro" do
      gs:advance_phase()
    end
    if gs.ended then
      fsm:transition("end_screen")
    end
  end, function() return true end)
```

Add the same end-check after EVERY action — easier: wrap the action callbacks. Replace the `add(...)` helper block:

```lua
  local function add(label, on_click, predicate)
    local b = action_button(label, bx, bar_y, btn_w, btn_h, function()
      if predicate and not predicate() then return end
      on_click()
      if gs.ended then fsm:transition("end_screen") end
    end)
    b._predicate = predicate
    table.insert(self.action_buttons, b)
    bx = bx + btn_w + 8
  end
```

Locate the top bar's `right` string in `M:draw`. Change from:

```lua
    local right = string.format("Turn %d  /  Shipped: %d  /  %s's turn",
      gs.turn_count, gs:shipped_count(), actor.name)
```

To:

```lua
    local right = string.format("Sprint %d  /  Turn %d  /  Shipped: %d  /  %s's turn",
      gs.sprint_number, gs.turn_count, gs:shipped_count(), actor.name)
```

- [ ] **Step 2:** `busted` → expect 140 successes (no test changes here).

- [ ] **Step 3:** `timeout 5 love .` → expect clean boot.

- [ ] **Step 4: Commit**

```
Drive sprint phase machine from the game state

On enter, call advance_phase() to plan the first sprint's tickets
into the backlog. End Turn now also walks the retro+plan flow when
sprint ends, transitions to end_screen on game-end. Top bar adds
Sprint N indicator. Every action also checks gs.ended for end-trigger
auto-transitions.
```

---

### Task 4: Smoke + final review

- [ ] **Step 1: Run `love .`.** Walk through:
  1. Start game with 2 players, default settings.
  2. Game screen shows Sprint 1 / Turn 1, backlog has 4 tickets (2 * 2 players).
  3. Play through claiming, working, submitting, end-turning to alternate players, approving each other's tickets.
  4. After every claim/work/submit/approve, eventually all tickets ship and `sprint_should_end` fires → end_turn transitions to retro → game state auto-advances to planning for sprint 2 (with 4 new tickets drawn from the remaining 2 in the seed deck).
  5. Eventually deck exhausts → game auto-ends → end_screen.
  6. Try a "fixed_n_sprints_3" trigger from the config — game ends after sprint 3.

- [ ] **Step 2: Final reviewer dispatched by controller.**

- [ ] **Step 3: Push.**

---

## Done

When all tasks check off, Plan 6 is complete. Plan 7 (sabotage cards) gives players the cutthroat half of the loop.
