# Meetings + Dilemmas Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Direct-to-main; subagents commit, controller pushes.

**Goal:** Add the Clout-earning + LinkedIn-Score-feeding half of the loop. After this plan, a Meeting action (1 AP) grants +2 Clout AND draws a Dilemma card. Each Dilemma presents a binary corporate choice (option A / option B) with prewritten humble-brag posts that get logged on the player's hidden LinkedIn profile. Six seed dilemmas from spec §9.5.

**Architecture:** `data/dilemmas.lua` enumerates 6 seed cards. `src/game/dilemmas.lua` provides `all()`, `draw(rng, exclude_ids)`, `resolve(gs, dilemma, choice)`. Each dilemma has `id, title, setup, option_a, option_b`; each option has `pitch, effect (fn), ls_delta, humble_brag (string|nil)`. GameSession grows a `humble_brag_log` per player (list of strings) and an `dilemmas_drawn` set. A new `DilemmaDialog` modal renders the setup + two option buttons. Game state grows a Meeting button.

**Tech Stack:** Lua 5.1+, Love2D 11.x, busted.

**Scope:** Plan 8 of 9. Builds on Plan 7. Plan 9 capstones + end-screen render the humble-brag log.

**Spec reference:** §9 (Dilemma Cards).

---

## File Map

```
.
├── data/
│   └── dilemmas.lua                    (new — 6 seed dilemma cards)
├── src/
│   ├── game/
│   │   ├── dilemmas.lua                (new — engine)
│   │   └── game_session.lua            (modified — humble_brag_log, dilemmas_drawn, meeting helper)
│   ├── states/
│   │   └── game.lua                    (modified — Meeting button + dilemma dialog integration)
│   └── ui/
│       └── components/
│           └── dilemma_dialog.lua      (new — modal)
└── tests/
    └── spec/
        ├── dilemmas_spec.lua           (new — engine tests)
        └── game_session_spec.lua       (extended — humble_brag_log + dilemmas_drawn tests)
```

---

### Task 1: Dilemma data + engine + GameSession integration

**Files:**
- Create: `data/dilemmas.lua`
- Create: `src/game/dilemmas.lua`
- Modify: `src/game/game_session.lua` (add `humble_brag_log` and `dilemmas_drawn` per player + `do_meeting` helper)
- Create: `tests/spec/dilemmas_spec.lua`
- Modify: `tests/spec/game_session_spec.lua` (test humble_brag_log)

Spec defines 6 cards (Friday Deploy, Layoff List, PR Review at 11pm, AI Training Data, RTO Snitch Bonus, Intern's Feature). Each card's `option_a` is the LS-heavy "compromise" choice with a prewritten humble-brag; `option_b` is usually no-effect/no-LS.

Effects: A's effect mutates resources (credit, clout, tech_debt) per the spec's flavor lines; B is usually a no-op or small trade.

`GameSession:do_meeting(rng)`:
- Asserts turns phase + AP > 0
- Spends 1 AP
- Grants +2 Clout to actor
- Returns the drawn Dilemma (or nil if all drawn). Caller then calls `resolve_dilemma(gs, dilemma, choice)` once user picks.

`GameSession:resolve_dilemma(dilemma, choice)`:
- choice = "a" or "b"
- Applies the option's effect, ls_delta, and logs the humble_brag (if non-nil) to `players[current_actor].humble_brag_log`
- Marks `dilemmas_drawn[dilemma.id] = true`

For tests:
- `Dilemmas.all()` returns 6 cards
- `Dilemmas.draw(rng, exclude)` returns a card not in exclude
- `Dilemmas.resolve` applies effect/ls/log
- `GameSession:do_meeting` spends AP and grants Clout

Implementation details:

`data/dilemmas.lua`:

```lua
-- Spec §9.5 seed deck. 6 cards. Each option's effect(gs, actor_idx)
-- mutates the game session. humble_brag is nil for "clean" options.

return {
  {
    id = "friday_deploy",
    title = "Friday Deploy",
    setup = "It's 4:55 PM Friday. The feature is 90% ready. Push it now or wait until Monday.",
    option_a = {
      pitch = "Push it now. Ship it.",
      effect = function(gs, idx)
        local p = gs.players[idx]
        p.credit = p.credit + 2
        p.tech_debt = p.tech_debt + 3
      end,
      ls_delta = 2,
      humble_brag = '"Shipped late Friday because that\'s what shipping feels like. No safety net, just vibes. Grateful for a team that trusts me to make the call."',
    },
    option_b = {
      pitch = "Wait until Monday. Proper rollout.",
      effect = function(gs, idx) end,
      ls_delta = 0,
      humble_brag = nil,
    },
  },
  {
    id = "layoff_list",
    title = "The Layoff List",
    setup = "VP asks for names for the next RIF. You have: 1 senior friend, 5 quiet juniors.",
    option_a = {
      pitch = "Name the juniors. Numbers, not names.",
      effect = function(gs, idx)
        local p = gs.players[idx]
        p.credit = p.credit + 1
        p.clout = p.clout + 2
      end,
      ls_delta = 5,
      humble_brag = '"Had to make some difficult but necessary decisions this week. Grateful to the team members whose contributions helped us get here. Wishing them the best in their next chapter."',
    },
    option_b = {
      pitch = 'Refuse. "Not my job."',
      effect = function(gs, idx)
        gs.players[idx].clout = math.max(0, gs.players[idx].clout - 2)
      end,
      ls_delta = 0,
      humble_brag = nil,
    },
  },
  {
    id = "pr_review_11pm",
    title = "PR Review at 11 PM",
    setup = "Your friend's PR has a subtle bug. Their promo decision is in 12 hours.",
    option_a = {
      pitch = "Approve it. They'd do the same for me.",
      effect = function(gs, idx)
        local p = gs.players[idx]
        p.clout = p.clout + 1
        p.tech_debt = p.tech_debt + 2
      end,
      ls_delta = 3,
      humble_brag = '"Reminder: trust is the ultimate leverage. Approved a teammate\'s PR today without ceremony. Relationships > gatekeeping."',
    },
    option_b = {
      pitch = "Request changes. Standards matter.",
      effect = function(gs, idx) end,
      ls_delta = 2,
      humble_brag = '"Defended code quality by requesting changes on a teammate\'s PR this week. Excellence isn\'t built by lowering the bar."',
    },
  },
  {
    id = "ai_training_data",
    title = "AI Training Data",
    setup = "The new AI feature is scraping customer data without consent. You found out. Launch is tomorrow.",
    option_a = {
      pitch = "Ship anyway. Iterate and apologize later.",
      effect = function(gs, idx)
        gs.players[idx].credit = gs.players[idx].credit + 4
      end,
      ls_delta = 5,
      humble_brag = '"Shipping thoughtfully and iterating is how innovation gets done. Proud of the team for launching our AI-powered personalization feature today!"',
    },
    option_b = {
      pitch = "Flag to legal. Compliance first.",
      effect = function(gs, idx)
        gs.players[idx].credit = math.max(0, gs.players[idx].credit - 2)
      end,
      ls_delta = 0,
      humble_brag = nil,
    },
  },
  {
    id = "rto_snitch",
    title = "RTO Snitch Bonus",
    setup = "Slack shows your WFH-full-time coworker at a cafe. Management's offering bonuses for \"culture reports.\"",
    option_a = {
      pitch = "Report them. Accountability is teamwork.",
      effect = function(gs, idx)
        gs.players[idx].clout = gs.players[idx].clout + 3
      end,
      ls_delta = 4,
      humble_brag = '"Culture is built, not assumed. Proud of our in-person collaboration and the shared responsibility we all hold."',
    },
    option_b = {
      pitch = "Stay silent. Not your business.",
      effect = function(gs, idx) end,
      ls_delta = 0,
      humble_brag = nil,
    },
  },
  {
    id = "intern_feature",
    title = "The Intern's Feature",
    setup = "Your intern wrote 80% of the feature. Demo is at All-Hands tomorrow.",
    option_a = {
      pitch = "Present it as yours. Mentorship includes storytelling.",
      effect = function(gs, idx)
        gs.players[idx].credit = gs.players[idx].credit + 3
      end,
      ls_delta = 3,
      humble_brag = '"Incredibly proud of the work my team has done this quarter. Innovation happens when leaders empower their reports — and tell their story well."',
    },
    option_b = {
      pitch = "Credit the intern publicly.",
      effect = function(gs, idx)
        gs.players[idx].clout = gs.players[idx].clout + 1
      end,
      ls_delta = 0,
      humble_brag = nil,
    },
  },
}
```

`src/game/dilemmas.lua`:

```lua
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

-- Draw a card not present in exclude (table: id -> true). Returns nil
-- if all are exhausted.
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
```

Modify `src/game/game_session.lua`:
- In `INITIAL_STATS`, add `humble_brag_log = {}` (note: shallow-shared bug — need to init per-player). Use a fresh `{}` per player in `init_players`:

Replace the `init_players` function:

```lua
local function init_players(session)
  local players = {}
  local ap = session.config.ap_per_turn
  for i, p in ipairs(session.players) do
    local rec = { idx = i, name = p.name, color = p.color, ap = ap }
    for k, v in pairs(INITIAL_STATS) do rec[k] = v end
    rec.humble_brag_log = {}  -- fresh table per player
    table.insert(players, rec)
  end
  return players
end
```

Also in `GameSession.new`, add `dilemmas_drawn = {}` to the returned table.

Add the `do_meeting` method (after `submit_for_review` or wherever convenient):

```lua
function GameSession:do_meeting()
  require_turns_phase(self); require_ap(self)
  self.players[self.current_actor].clout =
    self.players[self.current_actor].clout + 2
  spend_ap(self)
end
```

`tests/spec/dilemmas_spec.lua`:

```lua
local Dilemmas = require("src.game.dilemmas")
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

describe("Dilemmas", function()
  it("loads 6 seed cards", function()
    assert.is_equal(6, #Dilemmas.all())
  end)

  it("each card has the required shape", function()
    for _, c in ipairs(Dilemmas.all()) do
      assert.is_string(c.id)
      assert.is_string(c.title)
      assert.is_string(c.setup)
      assert.is_table(c.option_a)
      assert.is_table(c.option_b)
      assert.is_function(c.option_a.effect)
      assert.is_function(c.option_b.effect)
    end
  end)

  it("draw returns a card not in exclude", function()
    local card = Dilemmas.draw(RNG.new(1), { friday_deploy = true })
    assert.is_not_equal("friday_deploy", card.id)
  end)

  it("draw returns nil when all excluded", function()
    local all_excluded = {}
    for _, c in ipairs(Dilemmas.all()) do all_excluded[c.id] = true end
    assert.is_nil(Dilemmas.draw(RNG.new(1), all_excluded))
  end)

  it("resolve applies the chosen option's effect, ls_delta, and humble_brag", function()
    local g = fresh()
    local card = Dilemmas.find("friday_deploy")
    local before_credit = g.players[1].credit
    local before_ls = g.players[1].linkedin_score
    Dilemmas.resolve(g, card, "a")
    assert.is_equal(before_credit + 2, g.players[1].credit)
    assert.is_equal(before_ls + 2, g.players[1].linkedin_score)
    assert.is_equal(1, #g.players[1].humble_brag_log)
    assert.is_true(g.dilemmas_drawn[card.id])
  end)

  it("resolve b on a card with nil humble_brag does not log", function()
    local g = fresh()
    local card = Dilemmas.find("friday_deploy")
    Dilemmas.resolve(g, card, "b")
    assert.is_equal(0, #g.players[1].humble_brag_log)
    assert.is_equal(0, g.players[1].linkedin_score)
  end)

  it("resolve rejects bad choice values", function()
    local g = fresh()
    local card = Dilemmas.find("friday_deploy")
    assert.has_error(function() Dilemmas.resolve(g, card, "c") end)
  end)

  it("GameSession do_meeting grants 2 Clout and spends 1 AP", function()
    local g = fresh()
    local before_clout = g.players[1].clout
    local before_ap = g.players[1].ap
    g:do_meeting()
    assert.is_equal(before_clout + 2, g.players[1].clout)
    assert.is_equal(before_ap - 1, g.players[1].ap)
  end)

  it("humble_brag_log is per-player (not shared)", function()
    local g = fresh()
    Dilemmas.resolve(g, Dilemmas.find("friday_deploy"), "a")
    assert.is_equal(1, #g.players[1].humble_brag_log)
    assert.is_equal(0, #g.players[2].humble_brag_log)
  end)
end)
```

Workflow:
1. Write `data/dilemmas.lua`, `src/game/dilemmas.lua`.
2. Modify `src/game/game_session.lua` (init_players + dilemmas_drawn + do_meeting).
3. Write `tests/spec/dilemmas_spec.lua`.
4. `busted` → expect 161 successes (152 + 9 new).
5. Commit (HEREDOC + trailer):

```
Add Dilemma cards: 6 seed cards + engine + Meeting helper

data/dilemmas.lua holds the 6 seed dilemma cards from spec §9.5.
Each card has a setup and two options; each option has a pitch,
effect function, ls_delta, and optional humble_brag string.
src/game/dilemmas.lua exposes all/find/draw (excludes drawn ids)/
resolve (applies effect + ls + appends humble_brag to player's log).
GameSession grows dilemmas_drawn set + per-player humble_brag_log,
plus a do_meeting(self) helper that spends 1 AP and grants +2 Clout.
```

---

### Task 2: Dilemma dialog UI

**Files:**
- Create: `src/ui/components/dilemma_dialog.lua`

Modal showing setup + two large option buttons. Click A or B to resolve.

```lua
local Button = require("src.ui.components.button")
local typography = require("src.ui.typography")

local DilemmaDialog = {}
DilemmaDialog.__index = DilemmaDialog

local CARD_W = 720

local function new(opts)
  return setmetatable({
    on_choose = opts.on_choose or function() end,
    visible = false,
    dilemma = nil,
    button_a = nil,
    button_b = nil,
  }, DilemmaDialog)
end

local function build_buttons(self, w, h)
  if not self.dilemma then return end
  local btn_w = 320
  local btn_h = 96
  local total_w = 2 * btn_w + 24
  local bx = (w - total_w) / 2
  local by = h - btn_h - 80
  local d = self.dilemma
  self.button_a = Button.new({
    x = bx, y = by, w = btn_w, h = btn_h,
    label = "A: " .. d.option_a.pitch,
    on_click = function() self:choose("a") end,
  })
  self.button_b = Button.new({
    x = bx + btn_w + 24, y = by, w = btn_w, h = btn_h,
    label = "B: " .. d.option_b.pitch,
    on_click = function() self:choose("b") end,
  })
end

function DilemmaDialog:open(dilemma, w, h)
  self.dilemma = dilemma
  self.visible = true
  build_buttons(self, w, h)
end

function DilemmaDialog:choose(choice)
  local d = self.dilemma
  self.visible = false
  local cb = self.on_choose
  self.dilemma = nil
  cb(d, choice)
end

function DilemmaDialog:resize(w, h)
  if self.visible then build_buttons(self, w, h) end
end

function DilemmaDialog:draw()
  if not self.visible or not self.dilemma then return end
  if not (love and love.graphics) then return end
  local w = love.graphics.getWidth()
  local h = love.graphics.getHeight()
  local d = self.dilemma

  love.graphics.setColor(0, 0, 0, 0.65)
  love.graphics.rectangle("fill", 0, 0, w, h)

  -- Dialog card
  local cx = (w - CARD_W) / 2
  local cy = 80
  local card_h = h - 240
  love.graphics.setColor(0.97, 0.94, 0.85)
  love.graphics.rectangle("fill", cx, cy, CARD_W, card_h)
  love.graphics.setColor(0.1, 0.1, 0.1)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", cx, cy, CARD_W, card_h)

  typography.with("xl", function()
    love.graphics.setColor(0.1, 0.1, 0.1)
    local font = love.graphics.getFont()
    local tw = font:getWidth(d.title)
    love.graphics.print(d.title, cx + (CARD_W - tw) / 2, cy + 24)
  end)

  typography.with("md", function()
    love.graphics.setColor(0.2, 0.2, 0.2)
    love.graphics.printf(d.setup, cx + 32, cy + 96, CARD_W - 64, "center")
  end)

  if self.button_a then self.button_a:draw() end
  if self.button_b then self.button_b:draw() end
end

function DilemmaDialog:mousemoved(x, y)
  if not self.visible then return end
  if self.button_a then self.button_a:mousemoved(x, y) end
  if self.button_b then self.button_b:mousemoved(x, y) end
end

function DilemmaDialog:mousepressed(x, y, btn)
  if not self.visible then return end
  if self.button_a then self.button_a:mousepressed(x, y, btn) end
  if self.button_b then self.button_b:mousepressed(x, y, btn) end
end

function DilemmaDialog:mousereleased(x, y, btn)
  if not self.visible then return end
  if self.button_a then self.button_a:mousereleased(x, y, btn) end
  if self.button_b then self.button_b:mousereleased(x, y, btn) end
end

function DilemmaDialog:keypressed(key) end -- no esc-to-cancel; must choose

return {
  new = new,
}
```

Commit:

```
Add DilemmaDialog modal for binary corporate choices

Renders a paper-colored dialog card showing the dilemma's title and
setup; two large option buttons (A / B) below. Clicking either fires
the on_choose callback with the dilemma and the chosen letter. No
escape-to-cancel — once opened, the actor must choose. The game state
will wire the on_choose callback to Dilemmas.resolve.
```

---

### Task 3: Wire Meeting button + dialog into game state

**Files:**
- Modify: `src/states/game.lua`

Add:
- Require Dilemmas, DilemmaDialog, RNG (already required).
- In `build_layout` after sabotage_menu construction, build a dilemma_dialog and a per-state RNG seeded by something stable.
- The Meeting button: `add("Meeting", function() ... end, function() return actor_has_ap() end)`. Callback:
  - `gs:do_meeting()` (spends AP + grants Clout)
  - `local card = Dilemmas.draw(self._dilemma_rng or RNG.new(), gs.dilemmas_drawn)`
  - if card then `self.dilemma_dialog:open(card, w, h)`
  - else nothing further (no dilemmas left)
- DilemmaDialog `on_choose` callback: `Dilemmas.resolve(gs, dilemma, choice)` then `if gs.ended then fsm:transition("end_screen") end`.

Layout: now 9 buttons (was 8). Update `local total = 9 * btn_w + 8 * 8`.

Also route input through dilemma_dialog FIRST (before sabotage_menu, before kanban): if dialog visible, send to dialog only.

In draw: render dialog AFTER sabotage_menu (so on top of everything).

Commit:

```
Wire Meeting button + Dilemma dialog into game state

Meeting (1 AP) calls gs:do_meeting() (which grants +2 Clout), then
draws a Dilemma card (excluding already-drawn ids). If one exists,
opens the DilemmaDialog. Clicking option A or B resolves the dilemma
through Dilemmas.resolve, which applies the effect, the LS delta, and
appends the prewritten humble-brag string to the player's hidden log.

Button bar grows to 9 buttons.
```

---

### Task 4: Smoke + final review

- Run `love .`, walk: Meeting → Dilemma dialog appears → pick A → resources update, LS quietly increments, humble_brag logged.
- Push.

---

## Done

Plan 9 (capstones + end-screen LinkedIn roast) is the finale.
