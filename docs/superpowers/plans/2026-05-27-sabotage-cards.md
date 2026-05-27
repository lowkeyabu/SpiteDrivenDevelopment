# Sabotage Cards Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Direct-to-main; subagents commit, controller pushes.

**Goal:** Give players the cutthroat half of the loop. After this plan, the Sabotage action opens a menu of cards (filtered by the actor's Title tier when `tier_gating` is on), the actor picks a card, the game prompts for a target (another player or another player's ticket) when needed, and the card's effect is applied — debiting Clout, crediting LinkedIn Score, spending 1 AP. 12 seed cards across 4 tiers.

**Architecture:** A new `data/sabotage.lua` enumerates the 12 cards: `{ id, name, tier, clout, ls_delta, target, flavor, effect }`. `target` is `"none"`, `"player"`, `"ticket"`, or `"all"`. `effect` is a function `(gs, actor_idx, target)` that mutates the game session. `src/game/sabotage.lua` exposes `available_for(gs)` (tier-gated filter), `can_afford(gs, card)`, and `play(gs, card_id, target)`. `src/ui/components/sabotage_menu.lua` is a modal overlay listing available cards; the game state opens it on Sabotage and renders it on top. Clout is also surfaced in the HUD.

**Tech Stack:** Lua 5.1+, Love2D 11.x, busted.

**Scope:** Plan 7 of 9. Builds on Plan 6's sprint + AP infrastructure. Plan 8 adds Dilemmas via Meetings.

**Spec reference:** §8 (Sabotage Cards), §8.4 (seed deck of 12).

---

## File Map

```
.
├── data/
│   └── sabotage.lua                       (new — 12 seed cards)
├── src/
│   ├── game/
│   │   └── sabotage.lua                   (new — engine)
│   ├── states/
│   │   └── game.lua                       (modified — Sabotage button + modal)
│   └── ui/
│       └── components/
│           ├── player_hud.lua             (modified — Clout indicator)
│           └── sabotage_menu.lua          (new)
└── tests/
    └── spec/
        └── sabotage_spec.lua              (new — engine tests)
```

---

### Task 1: Seed sabotage data + engine

**Files:**
- Create: `data/sabotage.lua`
- Create: `src/game/sabotage.lua`
- Create: `tests/spec/sabotage_spec.lua`

The 12 seed cards from spec §8.4. Each `effect(gs, actor_idx, target)` mutates the game session — for example, "I have some concerns" rejects a target ticket back to In Progress. Some cards don't need a target (Sev-1 all-hands), some need a player (PIP, Skip-Level), some need a ticket (I have some concerns, Credit where credit, Legacy auth, Bike-shed).

For Plan 7 simplicity, "target = none" covers cards that affect all-players or the global state, "player" requires picking another player, "ticket" requires a ticket in review (or in_progress for tech-debt transfer).

- [ ] **Step 1: Write `tests/spec/sabotage_spec.lua`**

```lua
local Sabotage = require("src.game.sabotage")
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

describe("Sabotage", function()
  it("loads the 12 seed cards", function()
    local cards = Sabotage.all()
    assert.is_equal(12, #cards)
    for _, c in ipairs(cards) do
      assert.is_string(c.id)
      assert.is_string(c.name)
      assert.is_number(c.tier)
      assert.is_number(c.clout)
      assert.is_number(c.ls_delta)
      assert.is_string(c.target)
      assert.is_function(c.effect)
    end
  end)

  it("available_for filters by tier when tier_gating is ON", function()
    local g = fresh()
    g.session.config.tier_gating = true
    g.players[1].title = "IC1"
    local avail = Sabotage.available_for(g)
    for _, c in ipairs(avail) do
      assert.is_equal(1, c.tier)
    end
  end)

  it("available_for returns all cards when tier_gating is OFF", function()
    local g = fresh()
    g.session.config.tier_gating = false
    local avail = Sabotage.available_for(g)
    assert.is_equal(12, #avail)
  end)

  it("can_afford checks Clout balance", function()
    local g = fresh()
    local cheap = Sabotage.find("ic_concerns")
    g.players[1].clout = 0
    assert.is_false(Sabotage.can_afford(g, cheap))
    g.players[1].clout = 10
    assert.is_true(Sabotage.can_afford(g, cheap))
  end)

  it("play deducts Clout and adds LS to actor", function()
    local g = fresh()
    -- Get a ticket into Review for player 1.
    g:claim("T1"); g:work("T1"); g:submit_for_review("T1")
    g:end_turn() -- player 2 is now actor
    g.players[2].clout = 5
    local before_clout = g.players[2].clout
    local before_ls = g.players[2].linkedin_score
    local card = Sabotage.find("ic_concerns")
    Sabotage.play(g, card.id, { ticket_id = "T1" })
    assert.is_equal(before_clout - card.clout, g.players[2].clout)
    assert.is_equal(before_ls + card.ls_delta, g.players[2].linkedin_score)
  end)

  it("play raises when actor cannot afford", function()
    local g = fresh()
    g:claim("T1"); g:work("T1"); g:submit_for_review("T1")
    g:end_turn()
    g.players[2].clout = 0
    local card = Sabotage.find("ic_concerns")
    assert.has_error(function()
      Sabotage.play(g, card.id, { ticket_id = "T1" })
    end)
  end)

  it("ic_concerns effect rejects the target ticket back to in_progress", function()
    local g = fresh()
    g:claim("T1"); g:work("T1"); g:submit_for_review("T1")
    g:end_turn()
    g.players[2].clout = 5
    Sabotage.play(g, "ic_concerns", { ticket_id = "T1" })
    assert.is_equal(0, #g.review)
    assert.is_equal(1, #g.in_progress)
    assert.is_equal("T1", g.in_progress[1].id)
  end)

  it("quick_sync effect drains 1 AP from the target player", function()
    local g = fresh()
    g.players[1].clout = 5
    local before_ap = g.players[2].ap
    Sabotage.play(g, "quick_sync", { player_idx = 2 })
    assert.is_equal(before_ap - 1, g.players[2].ap)
  end)

  it("sev1_all_hands drains 2 AP from every other player", function()
    local g = fresh()
    g.players[1].clout = 10
    local before_ap_2 = g.players[2].ap
    Sabotage.play(g, "sev1_all_hands", {})
    assert.is_equal(before_ap_2 - 2, g.players[2].ap)
  end)

  it("pip freezes the target's title (sets a frozen flag)", function()
    local g = fresh()
    g.players[1].clout = 10
    Sabotage.play(g, "pip", { player_idx = 2 })
    assert.is_true(g.players[2].title_frozen)
  end)

  it("fire drops the target's title by 2 rungs", function()
    local g = fresh()
    g.players[1].clout = 20
    g.players[2].title = "Director" -- 8th rung
    Sabotage.play(g, "fire", { player_idx = 2 })
    -- Director (8) → 2 down → Staff (4). Index 8 - 2 = 6 = "Manager".
    assert.is_equal("Manager", g.players[2].title)
  end)

  it("fire clamps at IC1", function()
    local g = fresh()
    g.players[1].clout = 20
    g.players[2].title = "IC1"
    Sabotage.play(g, "fire", { player_idx = 2 })
    assert.is_equal("IC1", g.players[2].title)
  end)
end)
```

- [ ] **Step 2: Write `data/sabotage.lua`**

```lua
-- Seed sabotage deck — 12 cards across 4 tiers per spec §8.4. Each
-- card's `effect(gs, actor_idx, target)` mutates the GameSession.
-- target shapes:
--   "none"   → target is ignored
--   "player" → target = { player_idx = N }
--   "ticket" → target = { ticket_id = "..." }
--   "all"    → target is ignored (effect applies to everyone)

local Session = require("src.game.session")

local function next_title(current)
  return Session.next_title(current)
end

local function title_index(title)
  for i, t in ipairs(Session.TITLES) do
    if t == title then return i end
  end
  return nil
end

local function shift_title(current, delta)
  local idx = title_index(current)
  if not idx then return current end
  local new_idx = idx + delta
  if new_idx < 1 then new_idx = 1 end
  if new_idx > #Session.TITLES then new_idx = #Session.TITLES end
  return Session.TITLES[new_idx]
end

return {
  {
    id = "ic_concerns",
    name = '"I have some concerns."',
    tier = 1, clout = 1, ls_delta = 1,
    target = "ticket",
    flavor = "Reject a ticket sitting in Review. Bounces back to owner's In Progress.",
    effect = function(gs, actor_idx, target)
      gs:reject(target.ticket_id)
    end,
  },
  {
    id = "quick_sync",
    name = '"Just a quick sync?"',
    tier = 1, clout = 1, ls_delta = 1,
    target = "player",
    flavor = "Target loses 1 AP on their next turn.",
    effect = function(gs, actor_idx, target)
      local p = gs.players[target.player_idx]
      p.ap = math.max(0, p.ap - 1)
    end,
  },
  {
    id = "slack_dm_manager",
    name = '"Slack DM to manager."',
    tier = 1, clout = 1, ls_delta = 1,
    target = "player",
    flavor = "Snitch. Target reveals hidden trait on any one ticket.",
    effect = function(gs, actor_idx, target)
      -- For Plan 7, this is a flavor-only effect. Real hidden-trait reveal
      -- happens when ticket modifier system grows the API.
      gs.players[target.player_idx].snitched_on = true
    end,
  },
  {
    id = "credit_steal",
    name = '"Credit where credit is due."',
    tier = 2, clout = 3, ls_delta = 2,
    target = "ticket",
    flavor = "Steal 2 Credit from any ticket you approved this sprint.",
    effect = function(gs, actor_idx, target)
      local t = gs:find(target.ticket_id)
      if not t then error("no such ticket: " .. tostring(target.ticket_id)) end
      local victim = gs.players[t.owner]
      local amount = math.min(2, victim.credit)
      victim.credit = victim.credit - amount
      gs.players[actor_idx].credit = gs.players[actor_idx].credit + amount
    end,
  },
  {
    id = "legacy_auth",
    name = '"Legacy auth is your problem now."',
    tier = 2, clout = 2, ls_delta = 2,
    target = "ticket",
    flavor = "Move 2 Tech Debt from a ticket you own onto target ticket.",
    effect = function(gs, actor_idx, target)
      local actor = gs.players[actor_idx]
      local amount = math.min(2, actor.tech_debt)
      actor.tech_debt = actor.tech_debt - amount
      local t = gs:find(target.ticket_id)
      if t then
        local victim = gs.players[t.owner]
        if victim then victim.tech_debt = victim.tech_debt + amount end
      end
    end,
  },
  {
    id = "sev1_all_hands",
    name = '"Sev-1 — all hands."',
    tier = 2, clout = 4, ls_delta = 2,
    target = "all",
    flavor = "All other players lose 2 AP. You +1 Credit (incident response).",
    effect = function(gs, actor_idx, target)
      for i, p in ipairs(gs.players) do
        if i ~= actor_idx then
          p.ap = math.max(0, p.ap - 2)
        end
      end
      gs.players[actor_idx].credit = gs.players[actor_idx].credit + 1
    end,
  },
  {
    id = "pip",
    name = '"I\'d like to put you on a PIP."',
    tier = 3, clout = 5, ls_delta = 3,
    target = "player",
    flavor = "Target's Title is frozen — no promotion this sprint.",
    effect = function(gs, actor_idx, target)
      gs.players[target.player_idx].title_frozen = true
    end,
  },
  {
    id = "reorg",
    name = '"We\'re going through a reorg."',
    tier = 3, clout = 4, ls_delta = 2,
    target = "none",
    flavor = "Shuffle Backlog. Redraw.",
    effect = function(gs, actor_idx, target)
      if gs.rng then gs.rng:shuffle(gs.backlog) end
    end,
  },
  {
    id = "skip_level",
    name = '"Let\'s schedule a skip-level."',
    tier = 3, clout = 5, ls_delta = 3,
    target = "player",
    flavor = "Force target to spend their ENTIRE next turn in meetings (0 AP).",
    effect = function(gs, actor_idx, target)
      gs.players[target.player_idx].next_turn_ap_override = 0
    end,
  },
  {
    id = "fire",
    name = '"Difficult but necessary decision."',
    tier = 4, clout = 8, ls_delta = 5,
    target = "player",
    flavor = "Fire target — they drop 2 Title levels.",
    effect = function(gs, actor_idx, target)
      local p = gs.players[target.player_idx]
      p.title = shift_title(p.title, -2)
    end,
  },
  {
    id = "rto_mandate",
    name = '"RTO effective Monday."',
    tier = 4, clout = 7, ls_delta = 4,
    target = "all",
    flavor = "Every Hot Potato holder loses 1 Credit; repeats next sprint.",
    effect = function(gs, actor_idx, target)
      gs.rto_pending = (gs.rto_pending or 0) + 2 -- apply now + next sprint
      for _, p in ipairs(gs.players) do
        local hot = false
        for _, t in ipairs(gs.in_progress) do
          if t.owner == p.idx and t:has_modifier("hot_potato") then hot = true; break end
        end
        if hot then p.credit = math.max(0, p.credit - 1) end
      end
    end,
  },
  {
    id = "pivot_ai",
    name = '"Pivot. We\'re an AI company now."',
    tier = 4, clout = 9, ls_delta = 5,
    target = "none",
    flavor = "Discard all in-progress tickets of one Type (default: bug).",
    effect = function(gs, actor_idx, target)
      local victim_type = (target and target.ticket_type) or "bug"
      local kept = {}
      for _, t in ipairs(gs.in_progress) do
        if t.type ~= victim_type then table.insert(kept, t) end
      end
      gs.in_progress = kept
    end,
  },
}
```

- [ ] **Step 3: Write `src/game/sabotage.lua`**

```lua
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
  -- IC1, IC2, Senior, Staff, Principal, Manager, Sr Manager, Director, VP, C-suite
  -- Tiers: 1 = IC1..Senior(3), 2 = Staff..Principal(4-5), 3 = Manager..Director(6-8), 4 = VP+(9-10)
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
  card.effect(gs, actor_idx, target or {})
end

return Sabotage
```

- [ ] **Step 4: Run `busted tests/spec/sabotage_spec.lua -v`** → expect 12 tests pass.

- [ ] **Step 5: Run `busted`** → expect 152 successes (140 + 12).

- [ ] **Step 6: Commit (HEREDOC + trailer)**

```
Add sabotage cards: 12 seed cards + engine

data/sabotage.lua holds the 12 cards from spec §8.4 across 4 tiers.
src/game/sabotage.lua exposes all/find/available_for (tier-gating
honors session.config.tier_gating)/can_afford/play. Each card's
effect mutates the GameSession; play debits Clout, credits LS,
and dispatches to the card's effect function.

12 tests cover loading, tier filtering, affordability, and the
behavior of representative cards (ic_concerns, quick_sync,
sev1_all_hands, pip, fire, fire-clamping).
```

DO NOT push.

---

### Task 2: Surface Clout in HUD + add Sabotage button + modal

**Files:**
- Modify: `src/ui/components/player_hud.lua` (add Clout indicator)
- Create: `src/ui/components/sabotage_menu.lua`
- Modify: `src/states/game.lua` (Sabotage button opens modal, modal play resolves with target)

The Sabotage menu is a modal overlay (covers the kanban). It lists available cards in a scrollable column, each showing name, tier, clout cost, ls delta. Clicking a card commits to it: if `target = "none"` or `"all"`, the card plays immediately and the modal closes; otherwise the modal switches to "pick a target" mode — user clicks a player in the HUD or a ticket on the kanban behind the modal.

For Plan 7 simplicity: the modal only handles "none" and "all" targets. "player" and "ticket" target cards are listed but disabled with a "(targeting in Plan 8)" subtitle, OR a simpler implementation: a `player_idx = N` / `ticket_id = '...'` text input prompt. Pragmatic choice: show all cards but only PLAY the "none"/"all" ones in v1 modal. Player/ticket targeting buttons are gated to default to "select first viable target".

Cleaner approach: for player-target cards, auto-pick the next player in rotation; for ticket-target cards, use whatever ticket is currently selected in the KanbanView.

- [ ] **Step 1: Modify `src/ui/components/player_hud.lua`** to add a Clout indicator

Locate the AP/Credit rendering block in `:draw`:

```lua
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
```

Replace with a 3-line indicator (AP / Credit / Clout):

```lua
    typography.with("xs", function()
      love.graphics.setColor(0.1, 0.1, 0.1)
      local font = love.graphics.getFont()
      local ap_label = "AP " .. tostring(p.ap) .. "/" .. tostring(gs.session.config.ap_per_turn)
      local credit_label = "Cr " .. tostring(p.credit)
      local clout_label = "Clt " .. tostring(p.clout)
      local apw = font:getWidth(ap_label)
      local crw = font:getWidth(credit_label)
      local clw = font:getWidth(clout_label)
      love.graphics.print(ap_label, self.x + self.w - apw - 12, row_y + 6)
      love.graphics.print(credit_label, self.x + self.w - crw - 12, row_y + 22)
      love.graphics.print(clout_label, self.x + self.w - clw - 12, row_y + 38)
    end)
```

- [ ] **Step 2: Write `src/ui/components/sabotage_menu.lua`**

```lua
-- Modal overlay: lists available sabotage cards. Click a card to play
-- it. For Plan 7, "player" targets default to "the next player after
-- current_actor", "ticket" targets default to the kanban's selected
-- ticket. Plan 8+ will add explicit target picking.

local Button = require("src.ui.components.button")
local Sabotage = require("src.game.sabotage")
local typography = require("src.ui.typography")

local SabotageMenu = {}
SabotageMenu.__index = SabotageMenu

local CARD_W, CARD_H, CARD_GAP = 540, 80, 8

local function default_target(gs, kanban, card)
  if card.target == "none" or card.target == "all" then return {} end
  if card.target == "player" then
    local n = #gs.players
    local nxt = (gs.current_actor % n) + 1
    return { player_idx = nxt }
  end
  if card.target == "ticket" then
    local t = kanban and kanban:get_selected()
    if t then return { ticket_id = t.id } end
    return nil -- no valid target
  end
  return {}
end

local function new(opts)
  return setmetatable({
    game_session = opts.game_session,
    kanban = opts.kanban,
    on_close = opts.on_close or function() end,
    visible = false,
    cards = {},
    card_buttons = {},
    close_button = nil,
  }, SabotageMenu)
end

local function build_buttons(self, w, h)
  self.cards = Sabotage.available_for(self.game_session)
  self.card_buttons = {}

  local cx = (w - CARD_W) / 2
  local total_h = #self.cards * (CARD_H + CARD_GAP) - CARD_GAP
  local cy = math.max(80, (h - total_h) / 2)
  self._cx, self._cy = cx, cy

  for i, card in ipairs(self.cards) do
    local y = cy + (i - 1) * (CARD_H + CARD_GAP)
    local card_ref = card
    local b = Button.new({
      x = cx, y = y, w = CARD_W, h = CARD_H,
      label = card.name,
      on_click = function()
        local target = default_target(self.game_session, self.kanban, card_ref)
        if target == nil then return end -- no valid target available
        if not Sabotage.can_afford(self.game_session, card_ref) then return end
        local ok = pcall(function()
          Sabotage.play(self.game_session, card_ref.id, target)
        end)
        if ok then
          self:close()
        end
      end,
    })
    b._card = card_ref
    table.insert(self.card_buttons, b)
  end

  self.close_button = Button.new({
    x = w - 32 - 100, y = 32, w = 100, h = 32,
    label = "Close",
    on_click = function() self:close() end,
  })
end

function SabotageMenu:open(w, h)
  self.visible = true
  build_buttons(self, w, h)
end

function SabotageMenu:close()
  self.visible = false
  self.on_close()
end

function SabotageMenu:resize(w, h)
  if self.visible then build_buttons(self, w, h) end
end

function SabotageMenu:draw()
  if not self.visible then return end
  if not (love and love.graphics) then return end
  local w = love.graphics.getWidth()
  local h = love.graphics.getHeight()

  -- Dim background
  love.graphics.setColor(0, 0, 0, 0.55)
  love.graphics.rectangle("fill", 0, 0, w, h)

  -- Title
  typography.with("xl", function()
    love.graphics.setColor(0.95, 0.95, 0.92)
    local font = love.graphics.getFont()
    local title = "Choose Your Sabotage"
    local tw = font:getWidth(title)
    love.graphics.print(title, (w - tw) / 2, 32)
  end)

  for _, b in ipairs(self.card_buttons) do
    b:draw()
    -- Tier + cost overlay (bottom-right of each card)
    local card = b._card
    local actor = self.game_session.players[self.game_session.current_actor]
    local affordable = actor.clout >= card.clout
    typography.with("xs", function()
      love.graphics.setColor(0.3, 0.3, 0.3)
      local meta = string.format("T%d  /  %d Clout  /  +%d LS  /  %s",
        card.tier, card.clout, card.ls_delta, card.target)
      love.graphics.print(meta, b.x + 10, b.y + b.h - 18)
      if not affordable then
        love.graphics.setColor(0.7, 0.2, 0.2)
        love.graphics.print("(insufficient Clout)", b.x + b.w - 140, b.y + b.h - 18)
      end
    end)
  end

  self.close_button:draw()
end

function SabotageMenu:mousemoved(x, y)
  if not self.visible then return end
  for _, b in ipairs(self.card_buttons) do b:mousemoved(x, y) end
  self.close_button:mousemoved(x, y)
end

function SabotageMenu:mousepressed(x, y, btn)
  if not self.visible then return end
  for _, b in ipairs(self.card_buttons) do b:mousepressed(x, y, btn) end
  self.close_button:mousepressed(x, y, btn)
end

function SabotageMenu:mousereleased(x, y, btn)
  if not self.visible then return end
  for _, b in ipairs(self.card_buttons) do b:mousereleased(x, y, btn) end
  self.close_button:mousereleased(x, y, btn)
end

function SabotageMenu:keypressed(key)
  if not self.visible then return end
  if key == "escape" then self:close() end
end

return {
  new = new,
}
```

- [ ] **Step 3: Modify `src/states/game.lua`** to add Sabotage button + integrate the modal

Add to top requires:
```lua
local SabotageMenu = require("src.ui.components.sabotage_menu")
```

In `build_layout`, after the kanban is built and BEFORE the `add` helper is defined, build the modal:

```lua
  self.sabotage_menu = SabotageMenu.new({
    game_session = gs,
    kanban = kanban,
  })
```

After the existing "Reject" button add, add a "Sabotage" button BEFORE "End Turn":

```lua
  add("Sabotage", function()
    self.sabotage_menu:open(love.graphics.getWidth(), love.graphics.getHeight())
  end, function()
    return actor_has_ap()
  end)
```

(That makes 8 buttons. Update the layout math: change `local total = 7 * btn_w + 6 * 8` to `local total = 8 * btn_w + 7 * 8`.)

In `M:draw`, AFTER all the existing draws (so it's on top), call:

```lua
  self.sabotage_menu:draw()
```

In `M:mousemoved`, `M:mousepressed`, `M:mousereleased`, route through the modal FIRST when visible:

```lua
function M:mousemoved(x, y)
  if self.sabotage_menu.visible then
    self.sabotage_menu:mousemoved(x, y)
    return
  end
  self.kanban:mousemoved(x, y)
  for _, b in ipairs(self.action_buttons) do b:mousemoved(x, y) end
end

function M:mousepressed(x, y, btn)
  if self.sabotage_menu.visible then
    self.sabotage_menu:mousepressed(x, y, btn)
    return
  end
  self.kanban:mousepressed(x, y, btn)
  for _, b in ipairs(self.action_buttons) do
    local enabled = b._predicate == nil or b._predicate()
    if enabled then b:mousepressed(x, y, btn) end
  end
end

function M:mousereleased(x, y, btn)
  if self.sabotage_menu.visible then
    self.sabotage_menu:mousereleased(x, y, btn)
    return
  end
  self.kanban:mousereleased(x, y, btn)
  for _, b in ipairs(self.action_buttons) do b:mousereleased(x, y, btn) end
end
```

In `M:keypressed`:

```lua
function M:keypressed(key)
  if self.sabotage_menu.visible then
    self.sabotage_menu:keypressed(key)
    return
  end
  if key == "escape" then
    self.fsm:transition("menu")
  end
end
```

Also: when the Sabotage button fires AND the play succeeds, we want to spend 1 AP on the actor. The simplest place: inside `Sabotage.play`, after the effect runs. But the engine doesn't know about turn-state semantics. Pragmatic alternative: have the modal callback spend the AP after a successful play.

In `sabotage_menu.lua`'s `on_click`, after a successful `Sabotage.play`:

```lua
        if ok then
          self.game_session.players[self.game_session.current_actor].ap =
            self.game_session.players[self.game_session.current_actor].ap - 1
          self:close()
        end
```

The on_click already calls `if not Sabotage.can_afford(...) then return end` before `Sabotage.play`. Add a pre-check that the actor has AP > 0; gate the Sabotage menu button's predicate on `actor_has_ap()` (already does).

Update the close to also re-check ended state:

Actually, simpler: after the sabotage menu closes, check `gs.ended` in the game state. Add `on_close` to the menu setup:

```lua
  self.sabotage_menu = SabotageMenu.new({
    game_session = gs,
    kanban = kanban,
    on_close = function()
      if gs.ended then fsm:transition("end_screen") end
    end,
  })
```

- [ ] **Step 4: Run `busted`** → expect 152 successes / 0 failures.

- [ ] **Step 5: Run `timeout 5 love . 2>&1 | head -20`** → no error output.

- [ ] **Step 6: Commit (HEREDOC + trailer)**

```
Surface Clout in HUD and wire Sabotage button + modal

PlayerHUD now shows AP / Credit / Clout (xs font, three rows). Game
state grows a Sabotage button that opens a modal listing available
cards (tier-filtered when tier_gating is on). Clicking a card plays
it: "none"/"all" targets fire immediately; "player" targets default
to the next player; "ticket" targets default to the kanban selection.
Successful play spends 1 AP and closes the modal.
```

DO NOT push.

---

### Task 3: Smoke + final review

- [ ] **Step 1: Manual smoke test.**

Run `love .`. Walk:
1. Configure a game with 2 players, sabotage tier-gating OFF, start.
2. Top bar shows Sprint 1 / Turn 1 / Player 1's turn.
3. HUD now shows AP/Cr/Clt rows.
4. Set Player 1's clout to a high value via dev-mode (or play through to gain some — there's no Clout source yet, that's Plan 8's Meeting action). For Plan 7 smoke, manually set `gs.players[1].clout = 20` in `M:enter` if needed for testing — but DON'T commit that.
5. Click Sabotage button → modal opens with 12 cards listed.
6. Click "Sev-1 all hands" → effect fires, modal closes, P2's AP drops by 2.
7. Click "I have some concerns" → if no ticket selected and none in Review, nothing happens. Get a ticket into Review and try again.
8. Verify the LinkedIn Score on Player 1 ticks up after each sabotage.

- [ ] **Step 2: Push.** (Controller pushes.)

---

## Done

Plan 7 complete when the sabotage menu is wired and seed cards play correctly. Plan 8 (Meetings + Dilemmas + LinkedIn Score visibility) adds the Clout-earning side of the loop.
