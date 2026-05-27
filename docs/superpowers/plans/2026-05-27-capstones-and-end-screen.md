# Capstones + End-Screen LinkedIn Roast Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Direct-to-main; subagents commit, controller pushes.

**Goal:** The game's signature moment. After this plan, hitting the end-trigger transitions to the real end_screen, where: (1) players go through capstones one at a time in ascending corp-success order (winner last) — each gets a personalized trolley-style dilemma drawn from a deck tailored to their archetype; (2) once all capstones resolve, the screen renders each player's cringey fake LinkedIn profile with every humble-brag they accumulated, building to the winner's "crown + most humble-brag posts" reveal.

**Architecture:** GameSession grows archetype counters incremented by gameplay actions (sabotage plays bump Ladder Climber / Snitch / Credit Thief / Debt Dumper as appropriate; Meeting bumps Meeting Farmer). A new `src/game/capstones.lua` provides `classify(player)` → archetype string, `draw_for(archetype, rng)` → capstone, `resolve(gs, capstone, choice)`. Capstones share the Dilemma shape but live in `data/capstones.lua` (one per archetype, 6 cards total in v1). End-screen state replaces the placeholder with a state machine: capstone phase iterates players in ascending corp-success order, displays each capstone via the existing DilemmaDialog; reveal phase scrolls through each player's fake LinkedIn profile.

**Tech Stack:** Lua 5.1+, Love2D 11.x, busted.

**Scope:** Plan 9 of 9. Wraps up v1.

**Spec reference:** §10 (End Game), spec memory `capstone_framework.md`, `trolley_mechanic.md`.

---

## File Map

```
.
├── data/
│   └── capstones.lua                   (new — 6 capstone cards, one per archetype)
├── src/
│   ├── game/
│   │   ├── capstones.lua               (new — engine, classification)
│   │   └── game_session.lua            (modified — archetype_counters + hooks)
│   └── states/
│       └── end_screen.lua              (replaced — real capstone + roast flow)
└── tests/
    └── spec/
        └── capstones_spec.lua          (new — classification + resolve tests)
```

---

### Task 1: Archetype counters + Capstones engine + data

**Files:**
- Modify: `src/game/game_session.lua` (archetype counters per player)
- Modify: `src/game/sabotage.lua` (bump archetype on play)
- Modify: `src/game/dilemmas.lua` (no change needed — dilemmas don't bump archetype counters in v1)
- Create: `data/capstones.lua`
- Create: `src/game/capstones.lua`
- Create: `tests/spec/capstones_spec.lua`

### Archetypes (v1)

Track counters per player:
- `saboteur` — incremented on any sabotage play
- `ladder_climber` — incremented on tier-3+ sabotage plays (pip, reorg, skip_level, fire, rto_mandate, pivot_ai)
- `snitch` — incremented on slack_dm_manager OR on choosing "Report them" on RTO Snitch Bonus dilemma
- `credit_thief` — incremented on credit_steal sabotage play
- `debt_dumper` — incremented on legacy_auth sabotage play
- `meeting_farmer` — incremented on Meeting action

Classification: `argmax(counters)` with tiebreak by higher LinkedIn Score; fallback to `clean_operator` when all counters are zero.

### `data/capstones.lua` (NEW)

```lua
-- Capstone Dilemma cards. Shape matches data/dilemmas.lua but with
-- amplified ls_delta (2-3x normal) and an "archetype" key linking
-- each card to the player archetype it's drawn for.

return {
  {
    id = "ladder_climber_succession",
    archetype = "ladder_climber",
    title = "The Succession Memo",
    setup = "The CEO announces retirement next quarter. Your name's on the shortlist — along with the one colleague who's been carrying the team while you climbed. A leaked memo could tank their chances.",
    option_a = {
      pitch = "Leak the memo. Clear the field.",
      effect = function(gs, idx)
        gs.players[idx].credit = gs.players[idx].credit + 10
      end,
      ls_delta = 8,
      humble_brag = '"Leadership requires the hard conversations nobody else will have. Grateful for the trust my board has placed in me as I step into this new role."',
    },
    option_b = {
      pitch = "Let them compete fairly.",
      effect = function(gs, idx) end,
      ls_delta = 0,
      humble_brag = nil,
    },
  },
  {
    id = "snitch_exit_interview",
    archetype = "snitch",
    title = "The Exit Interview",
    setup = "HR asks: \"Before you leave MegaCorp, do you have any concerns about team culture you'd like to document? Your former manager is under review.\"",
    option_a = {
      pitch = "Document everything you saw — and some things you didn't.",
      effect = function(gs, idx)
        gs.players[idx].clout = gs.players[idx].clout + 5
      end,
      ls_delta = 7,
      humble_brag = '"Culture accountability is a lifelong practice. Grateful to the HR partner who trusted my perspective during a challenging leadership transition."',
    },
    option_b = {
      pitch = '"Nothing to report."',
      effect = function(gs, idx) end,
      ls_delta = 0,
      humble_brag = nil,
    },
  },
  {
    id = "credit_thief_book_deal",
    archetype = "credit_thief",
    title = "The Book Deal",
    setup = "A publisher wants the founding story of the product you (mostly) launched. The team's hard work is real; the byline is yours alone.",
    option_a = {
      pitch = "Take the byline. They'd do the same.",
      effect = function(gs, idx)
        gs.players[idx].credit = gs.players[idx].credit + 8
      end,
      ls_delta = 7,
      humble_brag = '"Thrilled to announce my new book — a candid look at the human side of innovation. Grateful to everyone who supported me on this journey."',
    },
    option_b = {
      pitch = "Share authorship.",
      effect = function(gs, idx) end,
      ls_delta = 0,
      humble_brag = nil,
    },
  },
  {
    id = "debt_dumper_postmortem",
    archetype = "debt_dumper",
    title = "The Postmortem",
    setup = "Production is on fire because of the system you owned but never refactored. The postmortem asks: name a root cause.",
    option_a = {
      pitch = "Name your junior. They wrote some of the code.",
      effect = function(gs, idx)
        gs.players[idx].credit = gs.players[idx].credit + 6
      end,
      ls_delta = 6,
      humble_brag = '"Owning the room when things go wrong is part of growth. Proud of how my team showed up during a difficult production incident this week."',
    },
    option_b = {
      pitch = "Own it. Document the systemic causes.",
      effect = function(gs, idx) end,
      ls_delta = 0,
      humble_brag = nil,
    },
  },
  {
    id = "meeting_farmer_calendar",
    archetype = "meeting_farmer",
    title = "The Calendar Audit",
    setup = "The new CEO is auditing calendars. Yours has 47 recurring meetings, mostly with executives. None has shipped a deliverable in 6 months.",
    option_a = {
      pitch = "Defend every meeting as 'strategic alignment'.",
      effect = function(gs, idx)
        gs.players[idx].clout = gs.players[idx].clout + 6
      end,
      ls_delta = 6,
      humble_brag = '"Strategic alignment isn\'t glamorous, but it\'s what keeps a company moving in one direction. Proud of the relationships I\'ve built across the org."',
    },
    option_b = {
      pitch = "Cancel half. Get back to work.",
      effect = function(gs, idx) end,
      ls_delta = 0,
      humble_brag = nil,
    },
  },
  {
    id = "clean_operator_one_last_time",
    archetype = "clean_operator",
    title = "One Last Story Point",
    setup = "It's the last sprint. A coworker's critical feature is stuck in Review. Approving it would cost you nothing, but their promo is tied to it. They've never helped you. Nobody's watching.",
    option_a = {
      pitch = "Approve it. Nobody has to know you're nice.",
      effect = function(gs, idx) end,
      ls_delta = 0,
      humble_brag = nil,
    },
    option_b = {
      pitch = "Let it rot in Review one more turn.",
      effect = function(gs, idx)
        gs.players[idx].credit = gs.players[idx].credit + 2
      end,
      ls_delta = 4,
      humble_brag = '"Boundaries are the scaffolding of excellence. Sometimes the kindest thing you can do is let someone sit with their work a little longer."',
    },
  },
}
```

Note the inversion on `clean_operator_one_last_time`: option **A** is the virtuous choice (no LS), option **B** is the spite move (the betrayal).

### `src/game/capstones.lua` (NEW)

```lua
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
      -- tie-break: lexicographic on archetype (stable)
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
  -- Capstones impact the player whose turn it is in the capstone phase,
  -- not gs.current_actor (which tracks the in-game actor).
  opt.effect(gs, player_idx)
  local p = gs.players[player_idx]
  p.linkedin_score = p.linkedin_score + (opt.ls_delta or 0)
  if opt.humble_brag then
    table.insert(p.humble_brag_log, opt.humble_brag)
  end
  p.capstone_done = true
end

return Capstones
```

### `src/game/game_session.lua` — MODIFY

- Add `archetype_counters = {}` to each player record in `init_players` (as a fresh table per player).
- Add a `capstone_done` field defaulting to false (also per player).

In `init_players`, after the existing `rec.humble_brag_log = {}`, add:

```lua
    rec.archetype_counters = { saboteur = 0, ladder_climber = 0, snitch = 0,
                                credit_thief = 0, debt_dumper = 0, meeting_farmer = 0 }
    rec.capstone_done = false
```

Modify `GameSession:do_meeting`: add a counter increment for `meeting_farmer`:

```lua
function GameSession:do_meeting()
  require_turns_phase(self); require_ap(self)
  self.players[self.current_actor].clout =
    self.players[self.current_actor].clout + 2
  self.players[self.current_actor].archetype_counters.meeting_farmer =
    (self.players[self.current_actor].archetype_counters.meeting_farmer or 0) + 1
  spend_ap(self)
end
```

### `src/game/sabotage.lua` — MODIFY

In `Sabotage.play`, after the existing `actor.linkedin_score = actor.linkedin_score + card.ls_delta` line and BEFORE the `card.effect(...)` call, insert:

```lua
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
```

### `tests/spec/capstones_spec.lua` (NEW)

```lua
local Capstones = require("src.game.capstones")
local GameSession = require("src.game.game_session")
local RNG = require("src.util.rng")
local Session = require("src.game.session")

local function ticket_defs()
  return {
    { id = "T1", title = "first", type = "feature", points = 1, reward = 1 },
    { id = "T2", title = "second", type = "feature", points = 2, reward = 2 },
    { id = "T3", title = "third", type = "chore", points = 3, reward = 3 },
    { id = "T4", title = "fourth", type = "chore", points = 1, reward = 1 },
  }
end

local function fresh()
  local s = Session.new()
  s:set_mode("sprint")
  s:set_player_count(2)
  local g = GameSession.new({
    session = s,
    ticket_defs = ticket_defs(),
    rng = RNG.new(42),
  })
  g:plan_sprint()
  return g
end

describe("Capstones", function()
  it("loads one card per archetype (6 total)", function()
    local cards = Capstones.all()
    assert.is_equal(6, #cards)
    local by_arch = {}
    for _, c in ipairs(cards) do by_arch[c.archetype] = c end
    assert.is_not_nil(by_arch.ladder_climber)
    assert.is_not_nil(by_arch.snitch)
    assert.is_not_nil(by_arch.credit_thief)
    assert.is_not_nil(by_arch.debt_dumper)
    assert.is_not_nil(by_arch.meeting_farmer)
    assert.is_not_nil(by_arch.clean_operator)
  end)

  it("classify returns clean_operator when all counters are zero", function()
    local p = { archetype_counters = {}, linkedin_score = 0 }
    assert.is_equal("clean_operator", Capstones.classify(p))
  end)

  it("classify returns the dominant archetype", function()
    local p = { archetype_counters = { ladder_climber = 5, snitch = 2 }, linkedin_score = 0 }
    assert.is_equal("ladder_climber", Capstones.classify(p))
  end)

  it("draw_for returns the matching capstone", function()
    local c = Capstones.draw_for("snitch")
    assert.is_equal("snitch", c.archetype)
  end)

  it("draw_for falls back to clean_operator for unknown archetype", function()
    local c = Capstones.draw_for("invented_archetype")
    assert.is_equal("clean_operator", c.archetype)
  end)

  it("resolve applies effect, ls_delta, humble_brag, and marks capstone_done", function()
    local g = fresh()
    local card = Capstones.draw_for("ladder_climber")
    local before_credit = g.players[1].credit
    local before_ls = g.players[1].linkedin_score
    Capstones.resolve(g, 1, card, "a")
    assert.is_equal(before_credit + 10, g.players[1].credit)
    assert.is_equal(before_ls + 8, g.players[1].linkedin_score)
    assert.is_equal(1, #g.players[1].humble_brag_log)
    assert.is_true(g.players[1].capstone_done)
  end)

  it("clean_operator capstone has option_b as the spite move", function()
    local g = fresh()
    local card = Capstones.draw_for("clean_operator")
    Capstones.resolve(g, 1, card, "b") -- the spite option
    assert.is_equal(4, g.players[1].linkedin_score)
    assert.is_equal(1, #g.players[1].humble_brag_log)
  end)

  it("clean_operator capstone option_a (virtuous) generates no log", function()
    local g = fresh()
    local card = Capstones.draw_for("clean_operator")
    Capstones.resolve(g, 1, card, "a")
    assert.is_equal(0, g.players[1].linkedin_score)
    assert.is_equal(0, #g.players[1].humble_brag_log)
  end)

  it("sabotage plays bump archetype counters", function()
    local g = fresh()
    g.players[1].clout = 20
    local Sabotage = require("src.game.sabotage")
    Sabotage.play(g, "credit_steal", { ticket_id = "T1" })
    assert.is_equal(1, g.players[1].archetype_counters.saboteur)
    assert.is_equal(1, g.players[1].archetype_counters.credit_thief)
  end)

  it("meeting bumps the meeting_farmer counter", function()
    local g = fresh()
    g:do_meeting()
    assert.is_equal(1, g.players[1].archetype_counters.meeting_farmer)
  end)
end)
```

Workflow:
1. Modify `src/game/game_session.lua` (init_players + do_meeting).
2. Modify `src/game/sabotage.lua` (counter bumps).
3. Create `data/capstones.lua`.
4. Create `src/game/capstones.lua`.
5. Create `tests/spec/capstones_spec.lua`.
6. `busted` → expect 171 successes (161 + 10 new).

Note: some existing sabotage_spec tests may now also write to archetype_counters (positive side effect). They shouldn't fail because they only assert specific fields, but verify.

7. Commit (HEREDOC + trailer):

```
Add archetype counters, Capstones engine + 6 seed capstones

GameSession tracks archetype_counters per player (saboteur/ladder
climber/snitch/credit_thief/debt_dumper/meeting_farmer); incremented
by sabotage plays and meetings. Capstones.classify(player) returns
the dominant archetype (clean_operator fallback). draw_for(archetype)
returns the matching capstone from the 6-card deck. resolve applies
effect/ls/humble_brag and marks capstone_done. 10 tests.
```

---

### Task 2: Real end_screen — capstone phase + LinkedIn roast phase

**Files:**
- Modify: `src/states/end_screen.lua` (replace placeholder)

The state runs in two phases:
1. **Capstones phase** — iterate players in ascending corp-success order (highest credit last). For each, classify, draw a capstone, present via DilemmaDialog. After all done, proceed to phase 2.
2. **Roast phase** — render each player's fake LinkedIn profile: stick-figure avatar (colored), name, title, final LS, humble-brag posts as a scrollable list. After all profiles shown (manually advance with Space), highlight the winner.

Replace `src/states/end_screen.lua` with:

```lua
local Capstones = require("src.game.capstones")
local DilemmaDialog = require("src.ui.components.dilemma_dialog")
local Session = require("src.game.session")
local typography = require("src.ui.typography")

local M = {}
M.__index = M

local function new(deps)
  return setmetatable({
    fsm = deps.fsm,
    session = deps.session,
  }, M)
end

local function ascending_by_credit(players)
  local order = {}
  for i, p in ipairs(players) do
    table.insert(order, { idx = i, credit = p.credit })
  end
  table.sort(order, function(a, b) return a.credit < b.credit end)
  return order
end

function M:enter()
  self.gs = self.session:get_game_session()
  if not self.gs then
    -- No game state — go back to menu.
    self.fsm:transition("menu")
    return
  end
  self.order = ascending_by_credit(self.gs.players)
  self.capstone_idx = 1
  self.phase = "capstones"  -- "capstones" then "roast"
  self.dialog = DilemmaDialog.new({
    on_choose = function(card, choice)
      local entry = self.order[self.capstone_idx]
      Capstones.resolve(self.gs, entry.idx, card, choice)
      self.capstone_idx = self.capstone_idx + 1
      self:advance_capstone()
    end,
  })
  self:advance_capstone()
end

function M:advance_capstone()
  while self.capstone_idx <= #self.order do
    local entry = self.order[self.capstone_idx]
    local p = self.gs.players[entry.idx]
    if not p.capstone_done then
      local archetype = Capstones.classify(p)
      local card = Capstones.draw_for(archetype)
      self.dialog:open(card, love.graphics.getWidth(), love.graphics.getHeight())
      return
    end
    self.capstone_idx = self.capstone_idx + 1
  end
  -- All capstones resolved.
  self.phase = "roast"
  self.roast_idx = 1
end

function M:resize(w, h)
  if self.dialog then self.dialog:resize(w, h) end
end

local function draw_profile(self, player, x, y, w, h)
  -- Avatar
  local rgb = Session.PLAYER_PALETTE[player.color] or { 0.5, 0.5, 0.5 }
  love.graphics.setColor(rgb[1], rgb[2], rgb[3])
  love.graphics.rectangle("fill", x, y, 64, 64)
  love.graphics.setColor(0.1, 0.1, 0.1)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", x, y, 64, 64)

  -- Name and title
  typography.with("xl", function()
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.print(player.name, x + 80, y)
  end)
  typography.with("md", function()
    love.graphics.setColor(0.35, 0.35, 0.35)
    love.graphics.print(player.title, x + 80, y + 36)
  end)

  -- LinkedIn Score
  typography.with("lg", function()
    love.graphics.setColor(0.6, 0.2, 0.2)
    local label = "LinkedIn Score: " .. tostring(player.linkedin_score)
    local font = love.graphics.getFont()
    local tw = font:getWidth(label)
    love.graphics.print(label, x + w - tw, y + 8)
  end)

  -- Humble-brag posts
  local post_y = y + 96
  typography.with("sm", function()
    love.graphics.setColor(0.2, 0.2, 0.2)
    local font = love.graphics.getFont()
    for _, post in ipairs(player.humble_brag_log) do
      love.graphics.setColor(0.85, 0.85, 0.78)
      love.graphics.rectangle("fill", x, post_y, w, 60)
      love.graphics.setColor(0.1, 0.1, 0.1)
      love.graphics.setLineWidth(1)
      love.graphics.rectangle("line", x, post_y, w, 60)
      love.graphics.setColor(0.2, 0.2, 0.2)
      love.graphics.printf(post, x + 12, post_y + 8, w - 24, "left")
      post_y = post_y + 70
      if post_y > y + h - 60 then break end
    end
    if #player.humble_brag_log == 0 then
      love.graphics.setColor(0.5, 0.5, 0.5)
      love.graphics.print("(no posts this quarter)", x, post_y)
    end
  end)
end

function M:draw()
  if not self.gs then return end
  local w = love.graphics.getWidth()
  local h = love.graphics.getHeight()

  if self.phase == "capstones" then
    -- Background card behind the modal
    typography.with("xl", function()
      love.graphics.setColor(0.1, 0.1, 0.1)
      local font = love.graphics.getFont()
      local title = "Capstone: " .. self.gs.players[self.order[self.capstone_idx] and self.order[self.capstone_idx].idx or 1].name
      local tw = font:getWidth(title)
      love.graphics.print(title, (w - tw) / 2, 24)
    end)
    self.dialog:draw()
    return
  end

  -- Roast phase
  typography.with("xl", function()
    love.graphics.setColor(0.1, 0.1, 0.1)
    local font = love.graphics.getFont()
    local title = "The Reveal"
    local tw = font:getWidth(title)
    love.graphics.print(title, (w - tw) / 2, 24)
  end)

  local entry = self.order[self.roast_idx]
  if entry then
    local p = self.gs.players[entry.idx]
    draw_profile(self, p, 64, 88, w - 128, h - 180)

    typography.with("md", function()
      love.graphics.setColor(0.4, 0.4, 0.4)
      local prog = string.format("Player %d of %d  /  Press SPACE to continue",
        self.roast_idx, #self.order)
      local font = love.graphics.getFont()
      local tw = font:getWidth(prog)
      love.graphics.print(prog, (w - tw) / 2, h - 56)
    end)
  else
    -- Final summary: winner.
    local winner_entry = self.order[#self.order] -- highest credit
    local winner = self.gs.players[winner_entry.idx]
    typography.with("display", function()
      love.graphics.setColor(0.6, 0.2, 0.2)
      local font = love.graphics.getFont()
      local title = "🏆 " .. winner.name .. " wins!"
      local tw = font:getWidth(title)
      love.graphics.print(title, (w - tw) / 2, h / 2 - 40)
    end)
    typography.with("md", function()
      love.graphics.setColor(0.3, 0.3, 0.3)
      local font = love.graphics.getFont()
      local sub = string.format(
        "Corporate success: %d Credit.  LinkedIn Score: %d.",
        winner.credit, winner.linkedin_score)
      local tw = font:getWidth(sub)
      love.graphics.print(sub, (w - tw) / 2, h / 2 + 24)

      local hint = "Press SPACE to return to the menu."
      tw = font:getWidth(hint)
      love.graphics.print(hint, (w - tw) / 2, h / 2 + 64)
    end)
  end
end

function M:mousemoved(x, y)
  if self.phase == "capstones" and self.dialog then
    self.dialog:mousemoved(x, y)
  end
end

function M:mousepressed(x, y, btn)
  if self.phase == "capstones" and self.dialog then
    self.dialog:mousepressed(x, y, btn)
  end
end

function M:mousereleased(x, y, btn)
  if self.phase == "capstones" and self.dialog then
    self.dialog:mousereleased(x, y, btn)
  end
end

function M:keypressed(key)
  if self.phase == "capstones" then return end
  if key == "space" then
    if self.roast_idx <= #self.order then
      self.roast_idx = self.roast_idx + 1
    else
      -- Clear session game_session so next New Game starts fresh.
      self.session:attach_game_session(nil)
      self.fsm:transition("menu")
    end
  elseif key == "escape" then
    self.session:attach_game_session(nil)
    self.fsm:transition("menu")
  end
end

return {
  new = new,
}
```

Workflow:
1. Replace `src/states/end_screen.lua`.
2. `busted` → expect 171 (no test changes here).
3. `timeout 5 love .` → no errors.
4. Commit:

```
Add real end_screen with capstone phase + LinkedIn roast reveal

State runs two phases. Capstones: iterates players ascending by Credit
(winner last), classifies each via Capstones.classify, draws a tailored
capstone, presents via the DilemmaDialog, applies the resolved effect
and humble-brag. Roast: scrolls through each player's fake LinkedIn
profile (avatar / name / title / final LS / humble-brag posts) on Space
press; finishes with the winner crown.

Esc or Space-past-the-end clears the attached game_session and returns
to the menu, so the next New Game starts fresh.
```

---

### Task 3: Smoke + final

- `love .` — play through a short game (1-2 sprints), gain Clout via Meetings, play a sabotage, end the game. Confirm capstones appear in ascending-Credit order, LinkedIn roasts render, winner is crowned.
- Push from controller.

---

## Done

When all tasks check, Plan 9 closes out v1. The game ships.
