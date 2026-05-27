# Multiplayer Turn Rotation + Resources HUD Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax. The workflow is direct-to-main; subagents commit locally, the controller pushes.

**Goal:** Turn the single-player walkthrough from Plan 4 into a real multiplayer cutthroat board. After this plan: `current_actor` rotates around the table, each player has Action Points (3 by default, configurable per the pre-game settings) that refresh on turn start, every action costs 1 AP, an "End Turn" button advances the rotation, the screen shows a per-player HUD with each player's resources and a "current turn" indicator, and Review actions correctly require a different player from the ticket owner.

**Architecture:** `GameSession` grows three pieces of turn-state — `ap` per player, `turn_count`, and an `end_turn()` method that resets AP for the next actor. Each existing action (`claim` / `work` / `submit_for_review` / `approve` / `reject`) checks `current_actor`'s AP and decrements on success. A new `PlayerHUD` UI component renders one row per player. The game state adds an "End Turn" action button and wires the HUD in.

**Tech Stack:** Lua 5.1+ (Love2D embed), Love2D 11.x, busted.

**Scope:** Plan 5 of 9. Builds on Plan 4's GameSession + KanbanView + game state.

**Spec reference:** `docs/superpowers/specs/2026-04-21-spite-driven-development-design.md` §6.2 (single turn), §6.1 (sprint phases — only the inter-turn rotation matters in Plan 5).

---

## File Map

```
.
├── src/
│   ├── game/
│   │   └── game_session.lua                (modified — AP + rotation)
│   ├── states/
│   │   └── game.lua                        (modified — HUD + AP display + End Turn + owner-check predicates)
│   └── ui/
│       └── components/
│           └── player_hud.lua              (new)
└── tests/
    └── spec/
        └── game_session_spec.lua           (extended — AP + rotation tests)
```

---

### Task 1: Extend GameSession with AP + turn rotation

**Files:**
- Modify: `src/game/game_session.lua`
- Modify: `tests/spec/game_session_spec.lua`

Add to each player record: `ap = session.config.ap_per_turn` (3 by default). Add `GameSession.turn_count = 1`. Each action method now asserts `players[current_actor].ap > 0` and decrements AP after the operation succeeds. Add `GameSession:end_turn()` that advances `current_actor` (wrapping at `#players`), increments `turn_count`, and resets the new actor's AP. Also: `submit_for_review` no longer costs AP — it's the natural end of the work cycle, like in real life nothing happens (no separate cost). Wait — actually the plan IS that every action costs 1 AP. Keep it simple: every action costs 1 AP.

- [ ] **Step 1: Append new tests to `tests/spec/game_session_spec.lua`** (inside the existing `describe("GameSession (focused)", function() ... end)` block, before its closing `end)`):

```lua
  it("seeds each player with config.ap_per_turn AP", function()
    local g = fresh()
    assert.is_equal(3, g.players[1].ap)
    assert.is_equal(3, g.players[2].ap)
    assert.is_equal(1, g.turn_count)
  end)

  it("claim decrements the actor's AP by 1", function()
    local g = fresh()
    assert.is_equal(3, g.players[1].ap)
    g:claim("T1")
    assert.is_equal(2, g.players[1].ap)
  end)

  it("work decrements AP by 1 per call", function()
    local g = fresh()
    g:claim("T2")            -- ap 3 -> 2
    g:work("T2")             -- ap 2 -> 1
    g:work("T2")             -- ap 1 -> 0
    assert.is_equal(0, g.players[1].ap)
  end)

  it("action raises when actor has no AP", function()
    local g = fresh()
    g:claim("T1") -- 2 left
    g:work("T1") -- 1 left
    g:submit_for_review("T1") -- 0 left
    assert.has_error(function() g:claim("T2") end)
  end)

  it("end_turn advances current_actor and refreshes the new actor's AP", function()
    local g = fresh()
    g:claim("T1")
    g:end_turn()
    assert.is_equal(2, g.current_actor)
    assert.is_equal(3, g.players[2].ap)
    assert.is_equal(2, g.turn_count)
  end)

  it("end_turn wraps around at the last player", function()
    local g = fresh()
    g:end_turn() -- actor 1 -> 2
    g:end_turn() -- actor 2 -> 1
    assert.is_equal(1, g.current_actor)
    assert.is_equal(3, g.turn_count)
  end)

  it("end_turn refreshes the new actor's AP even if it was nonzero", function()
    local g = fresh()
    g:claim("T1") -- player 1 ap = 2
    g.players[2].ap = 1 -- pretend player 2 had only 1 ap
    g:end_turn()
    assert.is_equal(3, g.players[2].ap) -- refreshed
  end)

  it("approve requires reviewer != ticket owner", function()
    local g = fresh()
    g:claim("T1") -- player 1 owns
    g:work("T1") -- submit-ready
    g:submit_for_review("T1") -- player 1 still actor
    -- Player 1 tries to approve their own — should raise.
    assert.has_error(function() g:approve("T1") end)
    -- Hand off to player 2.
    g:end_turn()
    g:approve("T1") -- ok now
    assert.is_equal(1, g.players[1].credit)   -- ticket reward
    assert.is_equal(1, g.players[2].credit)   -- reviewer +1
  end)

  it("reject requires reviewer != ticket owner", function()
    local g = fresh()
    g:claim("T2")
    g:work("T2"); g:work("T2")
    g:submit_for_review("T2")
    assert.has_error(function() g:reject("T2") end)
    g:end_turn()
    g:reject("T2")
    assert.is_equal(1, #g.in_progress)
  end)
```

- [ ] **Step 2: Update `src/game/game_session.lua`**

Replace the entire file with:

```lua
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
  local t = remove_by_id(self.review, ticket_id)
  assert(t, "no such ticket in review: " .. tostring(ticket_id))
  assert(self.current_actor ~= t.owner,
    "actor cannot approve own ticket")
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
  local t = remove_by_id(self.review, ticket_id)
  assert(t, "no such ticket in review: " .. tostring(ticket_id))
  assert(self.current_actor ~= t.owner,
    "actor cannot reject own ticket")
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
```

- [ ] **Step 3: Update the existing approve test in game_session_spec.lua**

The existing `it("approve moves a review ticket to done and credits the owner", ...)` test approves with the same player who owns the ticket, which will now raise. Update it to end_turn first.

Replace:

```lua
  it("approve moves a review ticket to done and credits the owner", function()
    local g = fresh()
    g:claim("T2")
    g:work("T2"); g:work("T2")
    g:submit_for_review("T2")
    g:approve("T2")
    assert.is_equal(0, #g.review)
    assert.is_equal(1, #g.done)
    assert.is_equal("T2", g.done[1].id)
    assert.is_equal(2, g.players[1].credit)
  end)
```

with:

```lua
  it("approve moves a review ticket to done and credits owner + reviewer", function()
    local g = fresh()
    g:claim("T2")
    g:work("T2"); g:work("T2")
    g:submit_for_review("T2")
    g:end_turn() -- player 2 reviews
    g:approve("T2")
    assert.is_equal(0, #g.review)
    assert.is_equal(1, #g.done)
    assert.is_equal("T2", g.done[1].id)
    assert.is_equal(2, g.players[1].credit) -- owner reward
    assert.is_equal(1, g.players[2].credit) -- reviewer +1
  end)
```

Similarly, replace the existing reject test:

```lua
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
```

with:

```lua
  it("reject sends the ticket back to in_progress with points reset", function()
    local g = fresh()
    g:claim("T2")
    g:work("T2"); g:work("T2")
    g:submit_for_review("T2")
    g:end_turn()
    g:reject("T2")
    assert.is_equal(0, #g.review)
    assert.is_equal(1, #g.in_progress)
    assert.is_equal("T2", g.in_progress[1].id)
    assert.is_equal(2, g.in_progress[1].points_remaining)
  end)
```

Similarly, update `shipped_count`:

```lua
  it("shipped_count returns the number of tickets in done", function()
    local g = fresh()
    assert.is_equal(0, g:shipped_count())
    g:claim("T1"); g:work("T1"); g:submit_for_review("T1")
    g:end_turn()
    g:approve("T1")
    assert.is_equal(1, g:shipped_count())
  end)
```

- [ ] **Step 4: Run busted**

Expected: 126 successes / 0 failures (117 prior + 9 new AP/rotation tests).

If existing tests break because they no longer have AP budget, audit and fix them — they may need an `end_turn()` between actions if more than 3 actions are chained on one actor.

The test for "claim moves a backlog ticket to ...": one action, fine. "work decrements points_remaining ... 2 calls": claim + 2 work = 3 actions = 0 AP at end, OK. "submit_for_review": claim + 1 work + 1 submit = 3 actions = 0 AP at end, OK. Same for shipped_count after the update above.

- [ ] **Step 5: Commit**

```bash
git add src/game/game_session.lua tests/spec/game_session_spec.lua
git commit -m "$(cat <<'EOF'
Add AP and turn rotation to GameSession

Each player now has ap (seeded from session.config.ap_per_turn).
Every action method asserts and spends 1 AP. end_turn advances
current_actor (wrapping), increments turn_count, and refreshes the
new actor's AP. approve and reject now require reviewer != owner
(spec §6.2). approve also credits the reviewer +1.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

Do not push — controller pushes.

---

### Task 2: PlayerHUD component

**Files:**
- Create: `src/ui/components/player_hud.lua`

A vertical list of rows, one per player. Each row shows: a colored swatch (using `Session.PLAYER_PALETTE[color]`), the player name, AP (e.g., `AP: 2/3`), Credit, and Title. The row for `current_actor` is highlighted.

- [ ] **Step 1: Write `src/ui/components/player_hud.lua`**

```lua
-- Renders one HUD row per player showing color, name, AP, Credit, and
-- Title. The current actor's row is highlighted.

local Session = require("src.game.session")

local PlayerHUD = {}
PlayerHUD.__index = PlayerHUD

local ROW_H = 56
local PADDING = 8

local function new(opts)
  return setmetatable({
    x = opts.x or 0,
    y = opts.y or 0,
    w = opts.w or 260,
    game_session = opts.game_session,
  }, PlayerHUD)
end

function PlayerHUD:height()
  return #self.game_session.players * (ROW_H + PADDING) - PADDING
end

function PlayerHUD:draw()
  if not (love and love.graphics) then return end
  local typography = require("src.ui.typography")
  local gs = self.game_session
  local current = gs.current_actor

  for i, p in ipairs(gs.players) do
    local row_y = self.y + (i - 1) * (ROW_H + PADDING)
    local is_current = (i == current)

    -- Background
    if is_current then
      love.graphics.setColor(1, 0.97, 0.79)
    else
      love.graphics.setColor(0.94, 0.92, 0.84)
    end
    love.graphics.rectangle("fill", self.x, row_y, self.w, ROW_H)

    -- Border
    if is_current then
      love.graphics.setColor(0.1, 0.4, 0.7)
      love.graphics.setLineWidth(3)
    else
      love.graphics.setColor(0.1, 0.1, 0.1)
      love.graphics.setLineWidth(1)
    end
    love.graphics.rectangle("line", self.x, row_y, self.w, ROW_H)

    -- Color swatch (player color)
    local rgb = Session.PLAYER_PALETTE[p.color] or { 0.5, 0.5, 0.5 }
    love.graphics.setColor(rgb[1], rgb[2], rgb[3])
    love.graphics.rectangle("fill", self.x + 8, row_y + 12, 32, 32)
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", self.x + 8, row_y + 12, 32, 32)

    -- Name + title
    typography.with("md", function()
      love.graphics.setColor(0.1, 0.1, 0.1)
      love.graphics.print(p.name, self.x + 48, row_y + 6)
    end)
    typography.with("xs", function()
      love.graphics.setColor(0.4, 0.4, 0.4)
      love.graphics.print(p.title, self.x + 48, row_y + 28)
    end)

    -- Right-aligned: AP and Credit
    typography.with("sm", function()
      love.graphics.setColor(0.1, 0.1, 0.1)
      local font = love.graphics.getFont()
      local ap_label = "AP " .. tostring(p.ap) .. "/" .. tostring(gs.session.config.ap_per_turn)
      local credit_label = "Cr " .. tostring(p.credit)
      local apw = font:getWidth(ap_label)
      local crw = font:getWidth(credit_label)
      love.graphics.print(ap_label, self.x + self.w - apw - 12, row_y + 8)
      love.graphics.print(credit_label, self.x + self.w - crw - 12, row_y + 28)
    end)
  end
end

return {
  new = new,
}
```

- [ ] **Step 2: Commit**

```bash
git add src/ui/components/player_hud.lua
git commit -m "$(cat <<'EOF'
Add PlayerHUD component (one row per player)

Each row shows color swatch (from Session.PLAYER_PALETTE), player name,
title, AP indicator (current/max), and credit. The current actor's row
is highlighted with a blue 3px border on a paper-yellow background.
Used by the game state's left rail in Plan 5.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: Integrate HUD + AP gates + End Turn button into game state

**Files:**
- Modify: `src/states/game.lua`

Changes from Plan 4's version:
1. Build a `PlayerHUD` and place it on the left side (`x=16`, `y=top_bar + 8`).
2. Shrink the KanbanView's `x` and `w` to make room for the HUD.
3. Add an "End Turn" action button at the right end of the button bar.
4. Update the action predicates to also check `actor.ap > 0`.
5. Update approve/reject predicates to require `t.owner ~= gs.current_actor`.
6. Update top bar to show `turn_count` and `current actor name` (not always P1).

- [ ] **Step 1: Replace `src/states/game.lua`**

```lua
local Button = require("src.ui.components.button")
local GameSession = require("src.game.game_session")
local KanbanView = require("src.ui.components.kanban_view")
local PlayerHUD = require("src.ui.components.player_hud")
local RNG = require("src.util.rng")
local typography = require("src.ui.typography")

local M = {}
M.__index = M

local BUTTON_BAR_H = 80
local TOP_BAR_H = 48
local HUD_W = 260
local HUD_GAP = 16

local function action_button(label, x, y, w, h, on_click)
  return Button.new({
    x = x, y = y, w = w, h = h,
    label = label,
    on_click = on_click,
  })
end

local function build_layout(self, w, h)
  local gs = self.game_session

  self.hud = PlayerHUD.new({
    x = 16, y = TOP_BAR_H + 8,
    w = HUD_W,
    game_session = gs,
  })

  local kanban_x = 16 + HUD_W + HUD_GAP
  self.kanban = KanbanView.new({
    x = kanban_x, y = TOP_BAR_H + 8,
    w = w - kanban_x - 16,
    h = h - TOP_BAR_H - BUTTON_BAR_H - 16,
    game_session = gs,
  })

  local fsm = self.fsm
  local kanban = self.kanban

  local function selected() return kanban:get_selected() end

  local btn_w, btn_h = 110, 40
  local total = 7 * btn_w + 6 * 8
  local bar_y = h - BUTTON_BAR_H + (BUTTON_BAR_H - btn_h) / 2
  local bx = (w - total) / 2

  self.action_buttons = {}

  local function add(label, on_click, predicate)
    local b = action_button(label, bx, bar_y, btn_w, btn_h, function()
      if predicate and not predicate() then return end
      on_click()
    end)
    b._predicate = predicate
    table.insert(self.action_buttons, b)
    bx = bx + btn_w + 8
  end

  local function actor_has_ap()
    return gs.players[gs.current_actor].ap > 0
  end

  add("Claim", function()
    local t = selected(); if t then gs:claim(t.id) end
  end, function()
    local t = selected()
    return t and t.column == "backlog" and actor_has_ap()
  end)

  add("Work", function()
    local t = selected(); if t then gs:work(t.id) end
  end, function()
    local t = selected()
    return t and t.column == "in_progress"
       and t.owner == gs.current_actor
       and t.points_remaining > 0
       and actor_has_ap()
  end)

  add("Submit", function()
    local t = selected(); if t then gs:submit_for_review(t.id) end
  end, function()
    local t = selected()
    return t and t.column == "in_progress"
       and t.owner == gs.current_actor
       and t.points_remaining == 0
       and actor_has_ap()
  end)

  add("Approve", function()
    local t = selected(); if t then gs:approve(t.id) end
  end, function()
    local t = selected()
    return t and t.column == "review"
       and t.owner ~= gs.current_actor
       and actor_has_ap()
  end)

  add("Reject", function()
    local t = selected(); if t then gs:reject(t.id) end
  end, function()
    local t = selected()
    return t and t.column == "review"
       and t.owner ~= gs.current_actor
       and actor_has_ap()
  end)

  add("End Turn", function()
    gs:end_turn()
    kanban.selected_id = nil
  end, function() return true end)

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
  local prev_selected = self.kanban and self.kanban.selected_id
  build_layout(self, w, h)
  if prev_selected then self.kanban.selected_id = prev_selected end
end

function M:draw()
  local w = love.graphics.getWidth()
  local h = love.graphics.getHeight()

  -- Top bar
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

    local gs = self.game_session
    local actor = gs.players[gs.current_actor]
    local right = string.format("Turn %d  /  Shipped: %d  /  %s's turn",
      gs.turn_count, gs:shipped_count(), actor.name)
    local rw = font:getWidth(right)
    love.graphics.print(right, w - rw - 16, (TOP_BAR_H - font:getHeight()) / 2)
  end)

  self.hud:draw()
  self.kanban:draw()

  -- Action button bar background
  love.graphics.setColor(0.92, 0.90, 0.82)
  love.graphics.rectangle("fill", 0, h - BUTTON_BAR_H, w, BUTTON_BAR_H)
  love.graphics.setColor(0.1, 0.1, 0.1)
  love.graphics.line(0, h - BUTTON_BAR_H, w, h - BUTTON_BAR_H)

  for _, b in ipairs(self.action_buttons) do
    local enabled = b._predicate == nil or b._predicate()
    if enabled then
      b:draw()
    else
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
  self.kanban:mousepressed(x, y, btn)
  for _, b in ipairs(self.action_buttons) do
    local enabled = b._predicate == nil or b._predicate()
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

- [ ] **Step 2: Run busted**

Expected: 126 successes / 0 failures.

- [ ] **Step 3: Boot Love**

Run: `timeout 5 love . 2>&1 | head -20`

Expected: no error output.

- [ ] **Step 4: Commit**

```bash
git add src/states/game.lua
git commit -m "$(cat <<'EOF'
Wire turn rotation, AP gates, owner-check, and End Turn into game state

The game state now renders a left-rail PlayerHUD (one row per player
with current actor highlighted), shrinks the Kanban to make room,
adds an End Turn button, and tightens action predicates:
- All actions require actor.ap > 0
- Approve/Reject require owner ~= current_actor

Top bar shows turn count, shipped count, and "{name}'s turn".

Plan 5 deliverable: two or more players can take turns, each spending
their 3 AP on actions; clicking End Turn rotates and refreshes the
next player's AP.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Smoke + final review

- [ ] **Step 1: Manual smoke test**

Run: `love .`. Walk through:
1. New Game → mode → config (set player count to 3) → player setup → Start Game.
2. Game screen shows 3 HUD rows, P1 highlighted blue, AP 3/3 on P1, AP 3/3 on P2 and P3 (not yet refreshed but seeded).
3. Top bar: "Turn 1 / Shipped: 0 / Player 1's turn".
4. Select a 1-point ticket, click Claim → AP 2/3. Click the ticket, click Work → AP 1/3. Submit → AP 0/3. All actions now disabled except End Turn / End Game.
5. Click End Turn. P2 highlighted; AP 3/3; top bar "Turn 2 / Player 2's turn".
6. As P2, select P1's ticket (now in Review). Approve becomes interactive (different owner). Click Approve → P1 gains the reward, P2 gains +1, ticket moves to Done.
7. End Turn → P3. End Turn → wraps to P1.

- [ ] **Step 2: Final reviewer**

Run via controller (not as task step).

- [ ] **Step 3: Push to main**

Controller pushes after all tasks complete.

---

## Done

When all tasks check off, Plan 5 is complete. Plan 6 (sprint phases + promotions + end triggers) takes turn rotation and adds the sprint/retro cycle that promotes players.
