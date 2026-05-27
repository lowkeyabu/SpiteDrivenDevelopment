# Kanban + Ticket Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Single-player Kanban walkthrough. After this plan, the GAME state shows a real Kanban board with Backlog / In Progress / Review / Done columns. Player 1 (the only player who acts in Plan 4) can Claim a Backlog ticket, Work on it (decrement points), Submit it to Review, then Approve it into Done — earning Credit on each ship. No sabotage, no dilemmas, no turn rotation, no sprint phases yet. Just the ticket-flow foundation.

**Architecture:** Three new game-domain modules — `Ticket` (one ticket's data + ops), `Deck` (generic shuffleable card pile), and `GameSession` (the per-game runtime state: board columns, per-player gameplay stats, current actor). One new data file (`data/tickets.lua`) holds the 6 seed tickets from the spec. Two new UI components — `TicketCard` (renders one ticket) and `KanbanView` (renders the four columns and the cards in them). The `game` state factory wires them together and provides action buttons that operate on the selected ticket.

**Tech Stack:** Lua 5.1+ (Love2D embed), Love2D 11.x runtime, busted for tests.

**Scope:** Plan 4 of 9. Plan 5 adds multiplayer turn rotation + resource HUD; Plan 6 adds sprint phases + promotions; Plan 7 adds sabotage; Plan 8 adds meetings + dilemmas; Plan 9 adds capstones + end-screen roast; final polish in a follow-up. This plan stays narrowly focused on getting a ticket from Backlog to Done for a single player.

**Spec reference:** `docs/superpowers/specs/2026-04-21-spite-driven-development-design.md`, §6 (Core Loop), §7 (Resources & Career Ladder).

---

## File Map

```
.
├── data/
│   └── tickets.lua                      (new — 6 seed tickets)
├── src/
│   ├── game/
│   │   ├── deck.lua                     (new — generic shuffleable deck)
│   │   ├── game_session.lua             (new — per-game runtime state)
│   │   ├── session.lua                  (modified — game_session getter)
│   │   └── ticket.lua                   (new — ticket struct + ops)
│   ├── states/
│   │   └── game.lua                     (replaced — real game screen)
│   └── ui/
│       └── components/
│           ├── kanban_view.lua          (new)
│           └── ticket_card.lua          (new)
└── tests/
    └── spec/
        ├── deck_spec.lua                (new)
        ├── game_session_spec.lua        (new)
        └── ticket_spec.lua              (new)
```

---

## Conventions

Same as prior plans: 2-space indent, snake_case, modules return tables, widgets follow Button shape, `Co-Authored-By` trailer on commits (HEREDOC), atomic commits.

**Pushing:** This plan lands directly on `main` (no feature branch, no PR — per the workflow preference set on 2026-05-27).

---

### Task 1: Ticket module (TDD)

**Files:**
- Create: `tests/spec/ticket_spec.lua`
- Create: `src/game/ticket.lua`

A `Ticket` is plain data plus a few mutating operations: claim (set owner, set column to "in_progress"), work (decrement points, never below 0), submit_for_review (require points == 0, set column to "review"), approve (set column to "done", record reviewer), reject (set column back to "in_progress", reset points to original).

- [ ] **Step 1: Write the spec**

```lua
local Ticket = require("src.game.ticket")

describe("Ticket", function()
  local function fixture()
    return Ticket.new({
      id = "SDD-042",
      title = "Add dark mode",
      type = "feature",
      points = 2,
      reward = 3,
      modifiers = { promo_magnet = true, glamour = true },
    })
  end

  it("starts in the backlog with all points remaining and no owner", function()
    local t = fixture()
    assert.is_equal("backlog", t.column)
    assert.is_equal(2, t.points_remaining)
    assert.is_nil(t.owner)
    assert.is_nil(t.reviewer)
  end)

  it("claim assigns the owner and moves to in_progress", function()
    local t = fixture()
    t:claim(1)
    assert.is_equal("in_progress", t.column)
    assert.is_equal(1, t.owner)
  end)

  it("claim rejects a non-backlog ticket", function()
    local t = fixture()
    t:claim(1)
    assert.has_error(function() t:claim(2) end)
  end)

  it("work decrements points_remaining (clamped at 0)", function()
    local t = fixture()
    t:claim(1)
    t:work()
    assert.is_equal(1, t.points_remaining)
    t:work()
    assert.is_equal(0, t.points_remaining)
    t:work() -- no-op
    assert.is_equal(0, t.points_remaining)
  end)

  it("work rejects a ticket not in in_progress", function()
    local t = fixture()
    assert.has_error(function() t:work() end)
  end)

  it("submit_for_review requires points_remaining == 0", function()
    local t = fixture()
    t:claim(1)
    assert.has_error(function() t:submit_for_review() end)
    t:work(); t:work()
    t:submit_for_review()
    assert.is_equal("review", t.column)
  end)

  it("submit_for_review rejects a ticket not in in_progress", function()
    local t = fixture()
    assert.has_error(function() t:submit_for_review() end)
  end)

  it("approve moves a review ticket to done and records the reviewer", function()
    local t = fixture()
    t:claim(1); t:work(); t:work(); t:submit_for_review()
    t:approve(2)
    assert.is_equal("done", t.column)
    assert.is_equal(2, t.reviewer)
  end)

  it("approve rejects a ticket not in review", function()
    local t = fixture()
    assert.has_error(function() t:approve(2) end)
  end)

  it("reject bounces a review ticket back to in_progress with points reset", function()
    local t = fixture()
    t:claim(1); t:work(); t:work(); t:submit_for_review()
    t:reject()
    assert.is_equal("in_progress", t.column)
    assert.is_equal(2, t.points_remaining) -- full reset
    assert.is_nil(t.reviewer)
  end)

  it("reject rejects a ticket not in review", function()
    local t = fixture()
    assert.has_error(function() t:reject() end)
  end)

  it("has_modifier returns true/false based on the modifiers table", function()
    local t = fixture()
    assert.is_true(t:has_modifier("promo_magnet"))
    assert.is_true(t:has_modifier("glamour"))
    assert.is_false(t:has_modifier("tech_debt"))
  end)
end)
```

- [ ] **Step 2: Run the spec to see it fail**

Run: `busted tests/spec/ticket_spec.lua -v`

Expected: `module 'src.game.ticket' not found`.

- [ ] **Step 3: Implement `src/game/ticket.lua`**

```lua
-- A Ticket is one card in the JIRA Kanban. Plain data (id, title, type,
-- points, reward, modifiers, hidden_trait) plus column state and the
-- five operations that move it across the board: claim, work,
-- submit_for_review, approve, reject.

local Ticket = {}
Ticket.__index = Ticket

local function new(opts)
  return setmetatable({
    id = opts.id,
    title = opts.title,
    type = opts.type or "feature",
    points = opts.points or 1,
    reward = opts.reward or 1,
    modifiers = opts.modifiers or {},
    hidden_trait = opts.hidden_trait,
    column = "backlog",
    points_remaining = opts.points or 1,
    owner = nil,
    reviewer = nil,
  }, Ticket)
end

function Ticket:has_modifier(name)
  return self.modifiers[name] == true
end

function Ticket:claim(player_idx)
  assert(self.column == "backlog",
    "claim requires backlog; current column: " .. self.column)
  self.owner = player_idx
  self.column = "in_progress"
end

function Ticket:work()
  assert(self.column == "in_progress",
    "work requires in_progress; current column: " .. self.column)
  if self.points_remaining > 0 then
    self.points_remaining = self.points_remaining - 1
  end
end

function Ticket:submit_for_review()
  assert(self.column == "in_progress",
    "submit_for_review requires in_progress; current column: " .. self.column)
  assert(self.points_remaining == 0,
    "submit_for_review requires points_remaining == 0; got " .. tostring(self.points_remaining))
  self.column = "review"
end

function Ticket:approve(reviewer_idx)
  assert(self.column == "review",
    "approve requires review; current column: " .. self.column)
  self.column = "done"
  self.reviewer = reviewer_idx
end

function Ticket:reject()
  assert(self.column == "review",
    "reject requires review; current column: " .. self.column)
  self.column = "in_progress"
  self.points_remaining = self.points
  self.reviewer = nil
end

return {
  new = new,
}
```

- [ ] **Step 4: Run the spec to confirm it passes**

Run: `busted tests/spec/ticket_spec.lua -v`

Expected: 12 successes / 0 failures.

- [ ] **Step 5: Full suite**

Run: `busted`

Expected: 98 successes / 0 failures (86 prior + 12 Ticket).

- [ ] **Step 6: Commit**

```bash
git add src/game/ticket.lua tests/spec/ticket_spec.lua
git commit -m "$(cat <<'EOF'
Add Ticket module for one Kanban card

Ticket holds plain data (id, title, type, points, reward, modifiers,
hidden_trait) plus column state. Five operations move it: claim, work,
submit_for_review, approve, reject. Each operation asserts the legal
source column. Used by the GameSession to drive the Sprint board.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Deck module (TDD)

**Files:**
- Create: `tests/spec/deck_spec.lua`
- Create: `src/game/deck.lua`

`Deck` wraps a flat list of cards (any value: tickets, sabotage cards, dilemmas, etc.). Supports shuffle (via an `RNG`), draw (pop from top), peek (read without popping), and remaining count.

- [ ] **Step 1: Write the spec**

```lua
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
```

- [ ] **Step 2: Run to see it fail**

Run: `busted tests/spec/deck_spec.lua -v`

Expected: `module 'src.game.deck' not found`.

- [ ] **Step 3: Implement `src/game/deck.lua`**

```lua
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
```

- [ ] **Step 4: Run to confirm pass**

Run: `busted tests/spec/deck_spec.lua -v`

Expected: 7 successes / 0 failures.

- [ ] **Step 5: Full suite**

Run: `busted`

Expected: 105 successes / 0 failures.

- [ ] **Step 6: Commit**

```bash
git add src/game/deck.lua tests/spec/deck_spec.lua
git commit -m "$(cat <<'EOF'
Add generic Deck module (shuffle/draw/peek)

Flat list of cards wrapped with shuffle (delegates to RNG:shuffle),
draw (pop from index 1), draw_n (n or fewer), peek, and remaining.
Used by tickets, sabotage, dilemmas, and capstones in later plans.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Seed ticket data file

**Files:**
- Create: `data/tickets.lua`

The 6 seed cards from the spec, ready to load. Plan 6+ will add more.

- [ ] **Step 1: Write `data/tickets.lua`**

```lua
-- Seed ticket deck. Each entry is the table passed to Ticket.new.
-- The {COMPANY} placeholder is substituted at render time from
-- session.config.company_name. None of these tickets actually use it
-- yet — future tickets will.

return {
  {
    id = "SDD-042",
    title = "Add dark mode",
    type = "feature",
    points = 2,
    reward = 3,
    modifiers = { promo_magnet = true, glamour = true },
    flavor = "Trivial work. Users will worship you.",
  },
  {
    id = "SDD-017",
    title = "Rewrite auth service in Rust",
    type = "epic",
    points = 8,
    reward = 8,
    modifiers = { promo_magnet = true, tech_debt = 3 },
    flavor = "No one asked. Everyone will notice.",
  },
  {
    id = "SDD-099",
    title = "Remove Log4j before the audit",
    type = "chore",
    points = 3,
    reward = 1,
    modifiers = { compliance = true, hot_potato = true },
    flavor = "Thankless. Mandatory. Literally saving the company.",
  },
  {
    id = "SDD-420",
    title = "Ship agentic MCP integration",
    type = "vibe",
    points = 5,
    reward = 6,
    modifiers = { promo_magnet = true, tech_debt = 2, hidden = true },
    flavor = "No one knows what this means. CEO loves it.",
  },
  {
    id = "SDD-071",
    title = "Onboard new intern",
    type = "chore",
    points = 2,
    reward = 1,
    modifiers = { hot_potato = true },
    flavor = "Pair-programming, questions, empathy. Blocks you for 2 turns.",
  },
  {
    id = "SDD-008",
    title = "Deprecate legacy reporting tool",
    type = "spike",
    points = 3,
    reward = 4,
    modifiers = { dependency = 2 },
    flavor = "Three other teams depend on it. They'll learn.",
  },
}
```

- [ ] **Step 2: Commit**

```bash
git add data/tickets.lua
git commit -m "$(cat <<'EOF'
Add seed ticket data (6 cards from the spec)

Plain table loaded by the GameSession at start. Each entry is a Ticket
constructor opts table. Plan 6+ will add more cards.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: GameSession module (TDD)

**Files:**
- Create: `tests/spec/game_session_spec.lua`
- Create: `src/game/game_session.lua`
- Modify: `src/game/session.lua` (add `set_game_session` and `get_game_session` accessors so the game state can stash one without it being a hidden global)

The `GameSession` is the runtime-only state of an in-progress game: the deck, the ticket pool indexed by column, the per-player gameplay stats, and the current actor. It's constructed from a `Session` (which carries the pre-game config + players) plus a ticket deck plus an RNG. The Plan 4 game state only uses player 1; turn rotation is Plan 5.

- [ ] **Step 1: Write `tests/spec/game_session_spec.lua`**

```lua
local GameSession = require("src.game.game_session")
local RNG = require("src.util.rng")
local Session = require("src.game.session")
local Ticket = require("src.game.ticket")

local function ticket_defs()
  return {
    { id = "T1", title = "first",  type = "feature", points = 1, reward = 1 },
    { id = "T2", title = "second", type = "feature", points = 2, reward = 2 },
    { id = "T3", title = "third",  type = "chore",   points = 3, reward = 3 },
  }
end

local function fresh()
  local s = Session.new()
  s:set_mode("sprint")
  s:set_player_count(2)
  return GameSession.new({
    session = s,
    ticket_defs = ticket_defs(),
    rng = RNG.new(123),
  })
end

describe("GameSession", function()
  it("populates the backlog from the ticket defs and seeds per-player stats", function()
    local g = fresh()
    assert.is_equal(3, #g.backlog)
    assert.is_equal(0, #g.in_progress)
    assert.is_equal(0, #g.review)
    assert.is_equal(0, #g.done)
    assert.is_equal(2, #g.players)
    for _, p in ipairs(g.players) do
      assert.is_equal(0, p.credit)
      assert.is_equal(0, p.clout)
      assert.is_equal(0, p.tech_debt)
      assert.is_equal(0, p.linkedin_score)
      assert.is_equal("IC1", p.title)
    end
  end)

  it("current_actor defaults to player 1 (Plan 4 single-player)", function()
    local g = fresh()
    assert.is_equal(1, g.current_actor)
  end)
end)

describe("GameSession (focused)", function()
  it("claim removes the ticket from backlog and pushes it onto in_progress", function()
    local g = fresh()
    local t1 = g.backlog[1]
    g:claim(t1.id)
    assert.is_equal(2, #g.backlog)
    assert.is_equal(1, #g.in_progress)
    assert.is_equal(t1.id, g.in_progress[1].id)
    assert.is_equal("in_progress", g.in_progress[1].column)
    assert.is_equal(1, g.in_progress[1].owner)
  end)

  it("claim raises when the id is not in the backlog", function()
    local g = fresh()
    assert.has_error(function() g:claim("MISSING") end)
  end)

  it("work decrements points_remaining on a ticket the actor owns", function()
    local g = fresh()
    g:claim("T2") -- 2 points
    g:work("T2")
    assert.is_equal(1, g.in_progress[1].points_remaining)
    g:work("T2")
    assert.is_equal(0, g.in_progress[1].points_remaining)
  end)

  it("work raises when the ticket is not owned by the actor", function()
    local g = fresh()
    g:claim("T1")
    -- Pretend player 2 tries to work on T1
    g.current_actor = 2
    assert.has_error(function() g:work("T1") end)
  end)

  it("submit_for_review moves a 0-point in_progress ticket to review", function()
    local g = fresh()
    g:claim("T1") -- 1 point
    g:work("T1")
    g:submit_for_review("T1")
    assert.is_equal(0, #g.in_progress)
    assert.is_equal(1, #g.review)
    assert.is_equal("T1", g.review[1].id)
  end)

  it("approve moves a review ticket to done and credits the owner", function()
    local g = fresh()
    g:claim("T2")
    g:work("T2"); g:work("T2")
    g:submit_for_review("T2")
    g:approve("T2")
    assert.is_equal(0, #g.review)
    assert.is_equal(1, #g.done)
    assert.is_equal("T2", g.done[1].id)
    assert.is_equal(2, g.players[1].credit) -- reward = 2
    -- reviewer credit is +1 per spec, but in single-player the actor reviews
    -- their own ticket: we credit the owner only (avoid double credit).
  end)

  it("reject sends the ticket back to in_progress with points reset", function()
    local g = fresh()
    g:claim("T2")
    g:work("T2"); g:work("T2")
    g:submit_for_review("T2")
    g:reject("T2")
    assert.is_equal(0, #g.review)
    assert.is_equal(1, #g.in_progress)
    assert.is_equal("T2", g.in_progress[1].id)
    assert.is_equal(2, g.in_progress[1].points_remaining)
  end)

  it("find finds a ticket by id across all columns", function()
    local g = fresh()
    local t = g:find("T3")
    assert.is_not_nil(t)
    assert.is_equal("T3", t.id)
    g:claim("T3")
    t = g:find("T3")
    assert.is_equal("in_progress", t.column)
  end)

  it("returns nil when finding an unknown id", function()
    local g = fresh()
    assert.is_nil(g:find("MISSING"))
  end)

  it("shipped_count returns the number of tickets in done", function()
    local g = fresh()
    assert.is_equal(0, g:shipped_count())
    g:claim("T1"); g:work("T1"); g:submit_for_review("T1"); g:approve("T1")
    assert.is_equal(1, g:shipped_count())
  end)
end)
```

(The two `describe` blocks split happy-path setup checks from operation tests. busted runs both.)

- [ ] **Step 2: Run to see failures**

Run: `busted tests/spec/game_session_spec.lua -v`

Expected: `module 'src.game.game_session' not found`.

- [ ] **Step 3: Implement `src/game/game_session.lua`**

```lua
-- Per-game runtime state. Wraps the pre-game Session (config + players)
-- with the live board columns, per-player gameplay stats, and the
-- current actor. Constructed once when entering the game state; never
-- persisted across game restarts.

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
  for i, p in ipairs(session.players) do
    local rec = {
      idx = i,
      name = p.name,
      color = p.color,
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
  -- Optional shuffle: only if an RNG is provided (most callers do).
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
    current_actor = 1, -- Plan 4: single-player flow uses player 1 only
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

function GameSession:claim(ticket_id)
  local t = remove_by_id(self.backlog, ticket_id)
  assert(t, "no such ticket in backlog: " .. tostring(ticket_id))
  t:claim(self.current_actor)
  table.insert(self.in_progress, t)
end

function GameSession:work(ticket_id)
  local t = find_in(self.in_progress, ticket_id)
  assert(t, "no such ticket in in_progress: " .. tostring(ticket_id))
  assert(t.owner == self.current_actor,
    "actor " .. tostring(self.current_actor) ..
    " cannot work on ticket owned by " .. tostring(t.owner))
  t:work()
end

function GameSession:submit_for_review(ticket_id)
  local t = remove_by_id(self.in_progress, ticket_id)
  assert(t, "no such ticket in in_progress: " .. tostring(ticket_id))
  t:submit_for_review()
  table.insert(self.review, t)
end

function GameSession:approve(ticket_id)
  local t = remove_by_id(self.review, ticket_id)
  assert(t, "no such ticket in review: " .. tostring(ticket_id))
  t:approve(self.current_actor)
  local owner = self.players[t.owner]
  owner.credit = owner.credit + t.reward
  table.insert(self.done, t)
end

function GameSession:reject(ticket_id)
  local t = remove_by_id(self.review, ticket_id)
  assert(t, "no such ticket in review: " .. tostring(ticket_id))
  t:reject()
  table.insert(self.in_progress, t)
end

function GameSession:shipped_count()
  return #self.done
end

return {
  new = new,
}
```

- [ ] **Step 4: Modify `src/game/session.lua` to add `game_session` accessors**

Insert after `Session:set_player_color` and before `return { ... }`:

```lua
function Session:attach_game_session(gs)
  self._game_session = gs
end

function Session:get_game_session()
  return self._game_session
end
```

- [ ] **Step 5: Run the spec to confirm pass**

Run: `busted tests/spec/game_session_spec.lua -v`

Expected: 12 successes / 0 failures (the two `describe` blocks combined; the first has 2 tests, the second has 10).

- [ ] **Step 6: Full suite**

Run: `busted`

Expected: 117 successes / 0 failures (86 prior + 12 Ticket + 7 Deck + 12 GameSession).

- [ ] **Step 7: Commit**

```bash
git add src/game/game_session.lua src/game/session.lua tests/spec/game_session_spec.lua
git commit -m "$(cat <<'EOF'
Add GameSession for per-game runtime state

GameSession wraps a Session with live board columns (backlog / in_progress
/ review / done), per-player gameplay stats (credit / clout / tech_debt /
linkedin_score / title), and a current_actor. Provides claim / work /
submit_for_review / approve / reject operations that mutate ticket
column state and credit the owner on ship. Plan 4 uses player 1 as
the sole actor; Plan 5 will rotate.

Session also gains attach_game_session / get_game_session so the game
state can stash one without reaching for a hidden global.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: TicketCard UI component

**Files:**
- Create: `src/ui/components/ticket_card.lua`

A small renderable card. No interaction logic of its own (the parent KanbanView handles hit-testing and selection); just a `:draw(x, y, w, h, opts)` method where opts can pass `selected`, `actor_is_owner`, etc. Pure presentation.

(No spec — pure render code. We rely on the smoke test for verification.)

- [ ] **Step 1: Write `src/ui/components/ticket_card.lua`**

```lua
-- Renders one ticket card. Stateless — the caller provides position,
-- size, and presentation hints via opts each frame.
--
-- opts:
--   selected     - boolean, draws an outline highlight
--   actor_owns   - boolean, slightly different fill to distinguish your tickets

local TicketCard = {}

local TYPE_BADGE = {
  feature = { 0.30, 0.55, 0.90 },
  bug     = { 0.85, 0.30, 0.30 },
  chore   = { 0.60, 0.60, 0.60 },
  epic    = { 0.65, 0.35, 0.85 },
  spike   = { 0.95, 0.55, 0.25 },
  vibe    = { 0.30, 0.75, 0.85 },
}

local function badge_color(ttype)
  return TYPE_BADGE[ttype] or { 0.5, 0.5, 0.5 }
end

local function draw(ticket, x, y, w, h, opts)
  if not (love and love.graphics) then return end
  opts = opts or {}
  local typography = require("src.ui.typography")

  -- Background
  local fill = { 1, 0.97, 0.79 } -- sticky-note yellow
  if opts.actor_owns then
    fill = { 0.95, 0.99, 0.85 } -- subtle tint for owner
  end
  love.graphics.setColor(fill[1], fill[2], fill[3])
  love.graphics.rectangle("fill", x, y, w, h)

  -- Border
  if opts.selected then
    love.graphics.setColor(0.1, 0.4, 0.7)
    love.graphics.setLineWidth(3)
  else
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.setLineWidth(1)
  end
  love.graphics.rectangle("line", x, y, w, h)

  -- Type badge (left top), id (right top)
  local bcol = badge_color(ticket.type)
  love.graphics.setColor(bcol[1], bcol[2], bcol[3])
  love.graphics.rectangle("fill", x + 6, y + 6, 64, 14)
  typography.with("xs", function()
    love.graphics.setColor(1, 1, 1)
    local font = love.graphics.getFont()
    local label = ticket.type:upper()
    local tw = font:getWidth(label)
    love.graphics.print(label, x + 6 + (64 - tw) / 2, y + 7)
  end)

  typography.with("xs", function()
    love.graphics.setColor(0.4, 0.4, 0.4)
    local font = love.graphics.getFont()
    local label = ticket.id
    local tw = font:getWidth(label)
    love.graphics.print(label, x + w - tw - 6, y + 7)
  end)

  -- Title
  typography.with("sm", function()
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.print(ticket.title, x + 6, y + 26)
  end)

  -- Points pill bottom-left
  love.graphics.setColor(0.1, 0.1, 0.1)
  love.graphics.rectangle("fill", x + 6, y + h - 22, 26, 16)
  typography.with("xs", function()
    love.graphics.setColor(1, 0.97, 0.79)
    local font = love.graphics.getFont()
    local label = (ticket.points_remaining or ticket.points) .. "/" .. ticket.points
    local tw = font:getWidth(label)
    love.graphics.print(label, x + 6 + (26 - tw) / 2, y + h - 21)
  end)

  -- Reward pill bottom-right
  love.graphics.setColor(0.2, 0.5, 0.3)
  love.graphics.rectangle("fill", x + w - 56, y + h - 22, 50, 16)
  typography.with("xs", function()
    love.graphics.setColor(1, 1, 1)
    local font = love.graphics.getFont()
    local label = "+" .. ticket.reward .. " cr"
    local tw = font:getWidth(label)
    love.graphics.print(label, x + w - 56 + (50 - tw) / 2, y + h - 21)
  end)
end

return {
  draw = draw,
  TYPE_BADGE = TYPE_BADGE,
}
```

- [ ] **Step 2: Commit**

```bash
git add src/ui/components/ticket_card.lua
git commit -m "$(cat <<'EOF'
Add TicketCard renderer

Stateless: caller passes position, size, and hint opts (selected,
actor_owns) each frame. Renders sticky-note background, type badge,
id, title, points pill (remaining/total), and reward pill. No
interaction logic — KanbanView handles selection.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: KanbanView UI component

**Files:**
- Create: `src/ui/components/kanban_view.lua`

KanbanView renders the four columns and the cards in them. Each column gets a fixed slice of the available width. Cards are stacked vertically within each column. The view tracks the currently-selected ticket id and provides a `:mousepressed` that updates it on click. Selection is the screen's single source of truth for which ticket the action buttons operate on.

(No unit tests — rendering-only logic that depends on Love runtime, plus very simple hit-test math that's verified in the smoke test.)

- [ ] **Step 1: Write `src/ui/components/kanban_view.lua`**

```lua
-- Renders the four-column Kanban board. Tracks one selected ticket id
-- (or nil). The screen reads selected_id to decide which actions are
-- available.

local TicketCard = require("src.ui.components.ticket_card")

local KanbanView = {}
KanbanView.__index = KanbanView

local COLUMNS = { "backlog", "in_progress", "review", "done" }
local COLUMN_LABELS = {
  backlog     = "Backlog",
  in_progress = "In Progress",
  review      = "Review",
  done        = "Done",
}

local CARD_H = 88
local CARD_GAP = 8
local COLUMN_HEADER_H = 36
local COLUMN_PADDING = 10

local function new(opts)
  return setmetatable({
    x = opts.x or 0,
    y = opts.y or 0,
    w = opts.w or 1280,
    h = opts.h or 600,
    game_session = opts.game_session,
    selected_id = nil,
  }, KanbanView)
end

function KanbanView:column_rect(idx)
  local col_w = self.w / 4
  local col_x = self.x + (idx - 1) * col_w
  return col_x, self.y, col_w, self.h
end

function KanbanView:get_selected()
  if self.selected_id == nil then return nil end
  return self.game_session:find(self.selected_id)
end

function KanbanView:_card_rects()
  -- Returns a list of { ticket = t, x = x, y = y, w = w, h = h, column = col }.
  local rects = {}
  for col_idx, col in ipairs(COLUMNS) do
    local col_x, col_y, col_w, col_h = self:column_rect(col_idx)
    local card_x = col_x + COLUMN_PADDING
    local card_y = col_y + COLUMN_HEADER_H + COLUMN_PADDING
    local card_w = col_w - 2 * COLUMN_PADDING
    for _, ticket in ipairs(self.game_session[col]) do
      table.insert(rects, {
        ticket = ticket, column = col,
        x = card_x, y = card_y, w = card_w, h = CARD_H,
      })
      card_y = card_y + CARD_H + CARD_GAP
    end
  end
  return rects
end

function KanbanView:mousepressed(x, y, btn)
  if btn ~= 1 then return end
  for _, rect in ipairs(self:_card_rects()) do
    if x >= rect.x and y >= rect.y
       and x < rect.x + rect.w and y < rect.y + rect.h then
      self.selected_id = rect.ticket.id
      return
    end
  end
  -- Clicked outside any card: clear selection
  self.selected_id = nil
end

function KanbanView:mousereleased(x, y, btn) end
function KanbanView:mousemoved(x, y) end

function KanbanView:draw()
  if not (love and love.graphics) then return end
  local typography = require("src.ui.typography")
  local actor = self.game_session.current_actor

  for col_idx, col in ipairs(COLUMNS) do
    local col_x, col_y, col_w, col_h = self:column_rect(col_idx)

    -- Column header
    love.graphics.setColor(0.88, 0.86, 0.78)
    love.graphics.rectangle("fill", col_x, col_y, col_w, COLUMN_HEADER_H)
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", col_x, col_y, col_w, COLUMN_HEADER_H)
    typography.with("md", function()
      love.graphics.setColor(0.1, 0.1, 0.1)
      local font = love.graphics.getFont()
      local label = COLUMN_LABELS[col]
      local tw = font:getWidth(label)
      love.graphics.print(label,
        col_x + (col_w - tw) / 2,
        col_y + (COLUMN_HEADER_H - font:getHeight()) / 2)
    end)

    -- Column body outline
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.rectangle("line",
      col_x, col_y + COLUMN_HEADER_H,
      col_w, col_h - COLUMN_HEADER_H)
  end

  for _, rect in ipairs(self:_card_rects()) do
    TicketCard.draw(rect.ticket, rect.x, rect.y, rect.w, rect.h, {
      selected = (rect.ticket.id == self.selected_id),
      actor_owns = (rect.ticket.owner == actor),
    })
  end
end

return {
  new = new,
}
```

- [ ] **Step 2: Commit**

```bash
git add src/ui/components/kanban_view.lua
git commit -m "$(cat <<'EOF'
Add KanbanView renderer with single-selection click model

Four equal-width columns (Backlog / In Progress / Review / Done),
cards stacked vertically within each. Tracks one selected ticket id;
clicks select; clicks outside any card clear. get_selected returns
the live Ticket. Used by the game state to decide which actions are
available.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Real game state — wires KanbanView + action buttons + GameSession

**Files:**
- Modify: `src/states/game.lua` (replace placeholder)

The game state, on `enter`:
1. Reads the seed ticket defs from `data/tickets.lua`.
2. Constructs a `GameSession` from the pre-game `Session`, ticket defs, and a fresh seeded RNG.
3. Attaches the GameSession to the Session (so end_screen can read it later).
4. Builds the KanbanView and a row of action buttons at the bottom.

The action buttons read the KanbanView's selected ticket each frame and decide enable/disable. For Plan 4 single-player, the current actor is always player 1, so we don't need a "current actor" indicator yet.

Buttons:
- **Claim** — enabled when the selected ticket is in `backlog`
- **Work** — enabled when the selected ticket is in `in_progress`, owned by current actor, points_remaining > 0
- **Submit** — enabled when the selected ticket is in `in_progress`, owned by current actor, points_remaining == 0
- **Approve** — enabled when the selected ticket is in `review`
- **Reject** — enabled when the selected ticket is in `review`
- **End Game** — always enabled; transitions to end_screen

The placeholder behavior (SPACE advances) goes away — the player drives the screen with mouse clicks.

- [ ] **Step 1: Replace `src/states/game.lua`**

```lua
local Button = require("src.ui.components.button")
local GameSession = require("src.game.game_session")
local KanbanView = require("src.ui.components.kanban_view")
local RNG = require("src.util.rng")
local typography = require("src.ui.typography")

local M = {}
M.__index = M

local BUTTON_BAR_H = 80
local TOP_BAR_H = 48

local function action_button(label, x, y, w, h, on_click)
  return Button.new({
    x = x, y = y, w = w, h = h,
    label = label,
    on_click = on_click,
  })
end

local function build_layout(self, w, h)
  local gs = self.game_session
  self.kanban = KanbanView.new({
    x = 16, y = TOP_BAR_H + 8,
    w = w - 32, h = h - TOP_BAR_H - BUTTON_BAR_H - 16,
    game_session = gs,
  })

  local fsm = self.fsm
  local kanban = self.kanban

  local function selected() return kanban:get_selected() end

  local btn_w, btn_h = 120, 40
  local total = 6 * btn_w + 5 * 8
  local bar_y = h - BUTTON_BAR_H + (BUTTON_BAR_H - btn_h) / 2
  local bx = (w - total) / 2

  self.action_buttons = {}

  local function add(label, on_click, predicate)
    local b = action_button(label, bx, bar_y, btn_w, btn_h, function()
      local t = selected()
      if not t then return end
      if predicate and not predicate(t) then return end
      on_click(t)
    end)
    b._predicate = predicate
    table.insert(self.action_buttons, b)
    bx = bx + btn_w + 8
  end

  add("Claim", function(t) gs:claim(t.id) end,
    function(t) return t.column == "backlog" end)

  add("Work", function(t) gs:work(t.id) end,
    function(t)
      return t.column == "in_progress"
         and t.owner == gs.current_actor
         and t.points_remaining > 0
    end)

  add("Submit", function(t) gs:submit_for_review(t.id) end,
    function(t)
      return t.column == "in_progress"
         and t.owner == gs.current_actor
         and t.points_remaining == 0
    end)

  add("Approve", function(t) gs:approve(t.id) end,
    function(t) return t.column == "review" end)

  add("Reject", function(t) gs:reject(t.id) end,
    function(t) return t.column == "review" end)

  add("End Game", function() fsm:transition("end_screen") end,
    function() return true end)
end

local function load_ticket_defs()
  return require("data.tickets")
end

local function new(deps)
  return setmetatable({
    fsm = deps.fsm,
    session = deps.session,
  }, M)
end

function M:enter()
  local existing = self.session:get_game_session()
  if existing then
    self.game_session = existing
  else
    self.game_session = GameSession.new({
      session = self.session,
      ticket_defs = load_ticket_defs(),
      rng = RNG.new(),
    })
    self.session:attach_game_session(self.game_session)
  end
  build_layout(self, love.graphics.getWidth(), love.graphics.getHeight())
end

function M:resize(w, h)
  build_layout(self, w, h)
end

function M:draw()
  local w = love.graphics.getWidth()
  local h = love.graphics.getHeight()

  -- Top bar: company name + shipped counter + credit
  love.graphics.setColor(0.92, 0.90, 0.82)
  love.graphics.rectangle("fill", 0, 0, w, TOP_BAR_H)
  love.graphics.setColor(0.1, 0.1, 0.1)
  love.graphics.setLineWidth(1)
  love.graphics.line(0, TOP_BAR_H, w, TOP_BAR_H)

  typography.with("md", function()
    love.graphics.setColor(0.1, 0.1, 0.1)
    local font = love.graphics.getFont()
    local company = self.session.config.company_name
    love.graphics.print(company, 16, (TOP_BAR_H - font:getHeight()) / 2)

    local p1 = self.game_session.players[1]
    local right = string.format("Shipped: %d  /  Credit: %d  /  %s",
      self.game_session:shipped_count(),
      p1.credit,
      p1.name)
    local rw = font:getWidth(right)
    love.graphics.print(right, w - rw - 16, (TOP_BAR_H - font:getHeight()) / 2)
  end)

  self.kanban:draw()

  -- Action button bar background
  love.graphics.setColor(0.92, 0.90, 0.82)
  love.graphics.rectangle("fill", 0, h - BUTTON_BAR_H, w, BUTTON_BAR_H)
  love.graphics.setColor(0.1, 0.1, 0.1)
  love.graphics.line(0, h - BUTTON_BAR_H, w, h - BUTTON_BAR_H)

  for _, b in ipairs(self.action_buttons) do
    -- Dim disabled buttons by overriding their hover state when predicate fails.
    local selected_t = self.kanban:get_selected()
    local enabled = b._predicate == nil
      or (selected_t and b._predicate(selected_t))
    if enabled then
      b:draw()
    else
      -- Render a flat disabled-looking plate at the same coords.
      love.graphics.setColor(0.88, 0.86, 0.78)
      love.graphics.rectangle("fill", b.x, b.y, b.w, b.h)
      love.graphics.setColor(0.6, 0.6, 0.6)
      love.graphics.setLineWidth(1)
      love.graphics.rectangle("line", b.x, b.y, b.w, b.h)
      typography.with("md", function()
        love.graphics.setColor(0.55, 0.55, 0.55)
        local font = love.graphics.getFont()
        local tw = font:getWidth(b.label)
        local th = font:getHeight()
        love.graphics.print(b.label,
          b.x + (b.w - tw) / 2,
          b.y + (b.h - th) / 2)
      end)
    end
  end
end

function M:mousemoved(x, y)
  self.kanban:mousemoved(x, y)
  for _, b in ipairs(self.action_buttons) do b:mousemoved(x, y) end
end

function M:mousepressed(x, y, btn)
  -- Only let the Kanban consume the click if it's in the kanban region;
  -- buttons get all clicks.
  self.kanban:mousepressed(x, y, btn)
  for _, b in ipairs(self.action_buttons) do
    -- Disabled buttons don't receive presses.
    local selected_t = self.kanban:get_selected()
    local enabled = b._predicate == nil
      or (selected_t and b._predicate(selected_t))
    if enabled then b:mousepressed(x, y, btn) end
  end
end

function M:mousereleased(x, y, btn)
  self.kanban:mousereleased(x, y, btn)
  for _, b in ipairs(self.action_buttons) do b:mousereleased(x, y, btn) end
end

function M:keypressed(key)
  if key == "escape" then
    self.fsm:transition("menu")
  end
end

return {
  new = new,
}
```

- [ ] **Step 2: Run the full test suite**

Run: `busted`

Expected: 119 successes / 0 failures (no test changes; verifying no regression).

- [ ] **Step 3: Boot Love to verify**

Run: `timeout 5 love . 2>&1 | head -20`

Expected: no error output. Exit 124 or 143.

- [ ] **Step 4: Commit**

```bash
git add src/states/game.lua
git commit -m "$(cat <<'EOF'
Replace game placeholder with real Kanban + ticket flow screen

The game state now:
- Constructs a GameSession from the pre-game Session + seed tickets +
  a fresh seeded RNG on first entry; reuses the attached one on
  re-entry.
- Renders a top bar (company name / shipped / credit / current actor
  name) and a four-column Kanban.
- Provides a bottom action bar with Claim / Work / Submit / Approve /
  Reject / End Game. Buttons are enabled only when the selected
  ticket is in a legal column / state for the action; disabled ones
  render as a flat grey plate and ignore clicks.

Plan 4 deliverable: player 1 can claim a backlog ticket, work it down
to 0 points, submit it, approve it, and ship it — gaining the
ticket's reward credit. Esc returns to the menu.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Smoke test

**Files:** none

- [ ] **Step 1: Run the game and walk a full ticket through the board**

Run: `love .`

1. From the menu, click "New Game" → mode_select → click "The Sprint" → config (real) → set player count to 2 → Continue → player_setup → Start Game → **GAME**.
2. Top bar shows the configured company name on the left, "Shipped: 0 / Credit: 0 / Player 1" on the right.
3. Kanban has 4 columns; Backlog has 6 ticket cards stacked.
4. Click a small ticket (e.g., "Add dark mode" at 2 points) — its border highlights blue.
5. Claim button becomes interactive (others stay grey). Click Claim. Ticket moves to In Progress column with a "2/2" remaining badge.
6. Click the same ticket in In Progress. Work becomes interactive. Click Work once — points show "1/2". Click Work again — "0/2".
7. Submit becomes interactive (Work greys out). Click Submit — ticket moves to Review.
8. Approve and Reject become interactive. Click Approve — ticket moves to Done. Top bar updates to "Shipped: 1 / Credit: 3".
9. Repeat with another ticket of different points to verify the loop is robust.
10. Try Reject on a ticket in Review — it bounces back to In Progress with full points restored.
11. Click off any card — selection clears, all action buttons grey.
12. Click End Game — advances to end_screen placeholder. SPACE → menu.
13. Resize the window — Kanban + buttons re-center.

If any step fails, debug before continuing.

- [ ] **Step 2: Full test suite one more time**

Run: `busted`

Expected: 117 successes / 0 failures (86 prior + 12 Ticket + 7 Deck + 12 GameSession).

- [ ] **Step 3: No commit (verification only)**

---

### Task 9: Final review + push

**Files:** none

- [ ] **Step 1: Confirm working tree clean**

Run: `git status`

Expected: nothing to commit apart from pre-existing untracked `.claude/`.

- [ ] **Step 2: Confirm Plan 4 commit chain**

Run: `git log --oneline -10`

Expected: ~8 atomic commits on top of the Plan 3 merge.

- [ ] **Step 3: Run busted one more time**

Run: `busted`

Expected: 117 successes / 0 failures (86 prior + 12 Ticket + 7 Deck + 12 GameSession).

- [ ] **Step 4: Push to main**

Run: `git push origin main`

If the harness blocks the push, ask the user to add a `Bash(git push:*)` rule to their permission settings or to push themselves with `! git push origin main`.

---

## Done

When all 9 tasks are checked off, Plan 4 is complete. Plan 5 (multiplayer turn rotation + resources HUD) will reuse the GameSession and KanbanView, swap `current_actor = 1` for a rotating player index, and add a per-player HUD showing each player's stats.
