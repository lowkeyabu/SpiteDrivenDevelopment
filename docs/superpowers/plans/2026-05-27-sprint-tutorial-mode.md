# Sprint Tutorial Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Direct-to-main; subagents commit, controller pushes.

**Goal:** Add a guided Sprint tutorial as a selectable game mode. From the main menu → New Game → mode-select, picking "Tutorial — Sprint" skips the config and player-setup screens, drops the user into a deterministic 1-player game with a pre-seeded backlog, and overlays step-by-step instructions that advance as the user performs each expected action. After the tutorial, the user returns to the main menu.

**Architecture:** `Session.MODES` gains a new entry `sprint_tutorial`. `Session.config.tutorial_mode` is a new boolean. `mode_select` short-circuits when tutorial is picked: it calls `session:set_player_count(1)`, gives the lone player a stub name, sets `config.tutorial_mode = true`, then transitions directly to `game`. `GameSession` allows tutorial mode to skip the owner-check on approve (so a solo player can self-approve). A new `src/game/tutorial.lua` module holds the step list — each step has `text`, an optional `advance_condition(gs)` predicate, and a `manual_advance` flag. A new `src/ui/components/tutorial_overlay.lua` renders a top-center instruction bubble with an optional "Continue" button; it's drawn on top of everything in the game state and checked for advancement after every action.

**Tech Stack:** Lua 5.1+, Love2D 11.x, busted.

**Scope:** Plan 11 of N. v1 polish.

**Notes:** Tutorial mode is single-player. The sabotage/dilemma/capstone systems still function (so the user can see them) but there are no opponents to target — sabotage cards targeting "player" pick a no-op stub; dilemmas play normally.

---

## File Map

```
.
├── src/
│   ├── game/
│   │   ├── game_session.lua            (modified — bypass owner-check when tutorial_mode)
│   │   ├── session.lua                 (modified — add sprint_tutorial to MODES + tutorial_mode config)
│   │   └── tutorial.lua                (new — step list + step state)
│   ├── states/
│   │   ├── game.lua                    (modified — instantiate + draw + advance the overlay when tutorial)
│   │   └── mode_select.lua             (modified — sprint_tutorial short-circuits to game)
│   └── ui/
│       └── components/
│           └── tutorial_overlay.lua    (new — bubble UI + continue button)
└── tests/
    └── spec/
        ├── session_spec.lua            (extended — MODES includes sprint_tutorial)
        └── tutorial_spec.lua           (new — step advancement)
```

---

### Task 1: Add sprint_tutorial mode + tutorial_mode config + mode_select shortcut

**Files:**
- Modify: `src/game/session.lua`
- Modify: `src/states/mode_select.lua`
- Modify: `tests/spec/session_spec.lua`

### `src/game/session.lua`

In `Session.MODES`, after the existing `sprint` entry and before `floor`, insert:

```lua
  { id = "sprint_tutorial", label = "Tutorial — Sprint", available = true,
    blurb = "Learn the Sprint mode with a guided walkthrough." },
```

In `defaults()`, after `tier_gating = true,` add:

```lua
    tutorial_mode = false,
```

### `src/states/mode_select.lua`

Find the existing `on_click` that handles available modes — it currently calls `session:set_mode(mode.id)` then `fsm:transition("config")`. Replace that on_click for tutorial mode with a special path that skips config and player_setup.

Locate the existing block (around the `available` branch inside the for-loop):

```lua
    if mode.available then
      table.insert(self.buttons, Button.new({
        x = x, y = y, w = CARD_W, h = CARD_H,
        label = mode.label,
        font_size = "lg",
        on_click = function()
          session:set_mode(mode.id)
          fsm:transition("config")
        end,
      }))
```

Replace with:

```lua
    if mode.available then
      table.insert(self.buttons, Button.new({
        x = x, y = y, w = CARD_W, h = CARD_H,
        label = mode.label,
        font_size = "lg",
        on_click = function()
          session:set_mode(mode.id)
          if mode.id == "sprint_tutorial" then
            -- Skip config + player_setup; set up a 1-player tutorial.
            session.config.tutorial_mode = true
            session:set_player_count(1)
            session:set_player_name(1, "You")
            fsm:transition("game")
          else
            fsm:transition("config")
          end
        end,
      }))
```

Wait — `Session:set_player_count(n)` asserts `n >= 2 and n <= 8`. We need to allow `n == 1` for tutorial. Modify `Session:set_player_count`:

Find:

```lua
function Session:set_player_count(n)
  assert(n >= 2 and n <= 8, "player_count must be in [2, 8], got " .. tostring(n))
```

Replace with:

```lua
function Session:set_player_count(n)
  assert(n >= 1 and n <= 8, "player_count must be in [1, 8], got " .. tostring(n))
```

(Updating the lower bound from 2 to 1 for tutorial. Standard play still uses 2–8 via the config screen Stepper which caps at min=2; that's enforced at the UI layer, so the underlying API is just slightly more permissive.)

Also update the test in `session_spec.lua`:

Find:

```lua
  it("set_player_count rejects values outside [2, 8]", function()
    local s = Session.new()
    assert.has_error(function() s:set_player_count(1) end)
    assert.has_error(function() s:set_player_count(9) end)
    assert.has_error(function() s:set_player_count(0) end)
  end)
```

Replace with:

```lua
  it("set_player_count rejects values outside [1, 8]", function()
    local s = Session.new()
    assert.has_no.errors(function() s:set_player_count(1) end)
    assert.has_error(function() s:set_player_count(9) end)
    assert.has_error(function() s:set_player_count(0) end)
  end)
```

### Append to `tests/spec/session_spec.lua` (inside the existing describe block, before its closing `end)`):

```lua
  it("MODES includes sprint_tutorial as available", function()
    local by_id = {}
    for _, m in ipairs(Session.MODES) do by_id[m.id] = m end
    assert.is_not_nil(by_id.sprint_tutorial)
    assert.is_true(by_id.sprint_tutorial.available)
  end)

  it("config defaults tutorial_mode to false", function()
    local s = Session.new()
    assert.is_false(s.config.tutorial_mode)
  end)
```

Workflow:
1. Apply 3 edits to session.lua (MODES, defaults, set_player_count lower bound).
2. Apply edit to mode_select.lua (tutorial shortcut).
3. Update existing test + append 2 new tests in session_spec.lua.
4. `busted` → 173 successes (171 + 2 new).
5. Commit:

```
Add sprint_tutorial mode and skip config for it

Session.MODES gains a sprint_tutorial entry (available). Session.config
defaults tutorial_mode to false. set_player_count now accepts n=1
(tutorial uses 1 player; config-screen Stepper still enforces 2-8 for
real games). mode_select short-circuits sprint_tutorial: sets tutorial_mode
true, seeds a 1-player session named "You", transitions straight to game.
```

---

### Task 2: Tutorial step list + overlay component

**Files:**
- Create: `src/game/tutorial.lua`
- Create: `src/ui/components/tutorial_overlay.lua`
- Create: `tests/spec/tutorial_spec.lua`

### `src/game/tutorial.lua`

```lua
-- Sprint tutorial steps. Each step has:
--   text             - instructional string shown in the overlay bubble
--   advance_condition(gs) -> bool  optional; auto-advance when true
--   manual_advance   - true if step requires Continue button click
--
-- The overlay calls Tutorial.current(state) to get the current step,
-- and Tutorial.advance(state, gs) after every action to step forward.

local Tutorial = {}

local STEPS = {
  {
    text = "Welcome to MegaCorp. This is your JIRA Kanban board. Tickets flow Backlog → In Progress → Review → Done.",
    manual_advance = true,
  },
  {
    text = "On your turn you have AP (Action Points) shown on your HUD row. Every action costs 1 AP. Click Continue.",
    manual_advance = true,
  },
  {
    text = "Click any ticket in the Backlog column to select it.",
    advance_condition = function(gs, state)
      return state.kanban_selected_in_backlog
    end,
  },
  {
    text = "Now click the Claim button at the bottom to take ownership.",
    advance_condition = function(gs, state)
      return #gs.in_progress > 0
    end,
  },
  {
    text = "The ticket moved to In Progress. It has X/Y points remaining. Click the ticket then click Work to advance it.",
    advance_condition = function(gs, state)
      for _, t in ipairs(gs.in_progress) do
        if t.points_remaining < t.points then return true end
      end
      return false
    end,
  },
  {
    text = "Keep clicking Work until the ticket reaches 0 points remaining.",
    advance_condition = function(gs, state)
      for _, t in ipairs(gs.in_progress) do
        if t.points_remaining == 0 then return true end
      end
      return false
    end,
  },
  {
    text = "Points are 0/X. Click Submit to send it for Review.",
    advance_condition = function(gs, state)
      return #gs.review > 0
    end,
  },
  {
    text = "Now click the ticket in Review, then click Approve. (Tutorial mode lets you self-approve.)",
    advance_condition = function(gs, state)
      return #gs.done > 0
    end,
  },
  {
    text = "You shipped a ticket and earned Credit. Each ticket also counts toward promotion. Try a Meeting next (click Meeting).",
    advance_condition = function(gs, state)
      return state.meeting_done
    end,
  },
  {
    text = "Meeting gave you +2 Clout and drew a Dilemma. Pick A (the spite move) or B (the clean choice) — one of them silently bumps your LinkedIn Score.",
    advance_condition = function(gs, state)
      return state.dilemma_resolved
    end,
  },
  {
    text = "Clout lets you play Sabotage cards. Click Sabotage to see the menu, then close it (you're alone in tutorial — nobody to sabotage).",
    advance_condition = function(gs, state)
      return state.sabotage_closed
    end,
  },
  {
    text = "Click End Turn to wrap up your turn. In a real game the next player takes over here.",
    advance_condition = function(gs, state)
      return state.end_turn_done
    end,
  },
  {
    text = "Tutorial complete! Click End Game to return to the menu — or keep playing solo to explore.",
    manual_advance = true,
    is_final = true,
  },
}

function Tutorial.new()
  return {
    step_idx = 1,
    kanban_selected_in_backlog = false,
    meeting_done = false,
    dilemma_resolved = false,
    sabotage_closed = false,
    end_turn_done = false,
  }
end

function Tutorial.current(state)
  return STEPS[state.step_idx]
end

function Tutorial.is_complete(state)
  return state.step_idx > #STEPS
end

function Tutorial.advance(state, gs)
  while not Tutorial.is_complete(state) do
    local step = STEPS[state.step_idx]
    if step.manual_advance then return end -- waits for Continue button
    if step.advance_condition and step.advance_condition(gs, state) then
      state.step_idx = state.step_idx + 1
    else
      return
    end
  end
end

function Tutorial.manual_advance(state)
  local step = STEPS[state.step_idx]
  if step and step.manual_advance then
    state.step_idx = state.step_idx + 1
  end
end

Tutorial.STEPS = STEPS
return Tutorial
```

### `src/ui/components/tutorial_overlay.lua`

```lua
-- Tutorial overlay: a top-center bubble showing the current step's
-- instruction. Includes a Continue button for manual-advance steps.

local Button = require("src.ui.components.button")
local Tutorial = require("src.game.tutorial")
local typography = require("src.ui.typography")

local TutorialOverlay = {}
TutorialOverlay.__index = TutorialOverlay

local BUBBLE_W = 720
local BUBBLE_H = 120

local function new(opts)
  return setmetatable({
    state = opts.state,
    on_advance = opts.on_advance or function() end,
    continue_button = nil,
  }, TutorialOverlay)
end

function TutorialOverlay:resize(w, h) self:_rebuild_button(w) end

function TutorialOverlay:_rebuild_button(w)
  local btn_w = 140
  self.continue_button = Button.new({
    x = (w - btn_w) / 2, y = 8 + BUBBLE_H - 56, w = btn_w, h = 36,
    label = "Continue",
    on_click = function()
      Tutorial.manual_advance(self.state)
      self.on_advance()
    end,
  })
end

function TutorialOverlay:draw()
  if not (love and love.graphics) then return end
  if Tutorial.is_complete(self.state) then return end
  local step = Tutorial.current(self.state)
  if not step then return end

  local w = love.graphics.getWidth()
  if not self.continue_button then self:_rebuild_button(w) end

  local bx = (w - BUBBLE_W) / 2
  local by = 56

  -- Bubble
  love.graphics.setColor(1, 0.97, 0.79, 0.95)
  love.graphics.rectangle("fill", bx, by, BUBBLE_W, BUBBLE_H)
  love.graphics.setColor(0.1, 0.4, 0.7)
  love.graphics.setLineWidth(3)
  love.graphics.rectangle("line", bx, by, BUBBLE_W, BUBBLE_H)

  -- Step number
  typography.with("xs", function()
    love.graphics.setColor(0.4, 0.4, 0.4)
    love.graphics.print("Tutorial " .. tostring(self.state.step_idx) .. "/" .. tostring(#Tutorial.STEPS),
      bx + 12, by + 8)
  end)

  -- Text
  typography.with("md", function()
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.printf(step.text, bx + 20, by + 28, BUBBLE_W - 40, "left")
  end)

  if step.manual_advance then
    self.continue_button:draw()
  end
end

function TutorialOverlay:mousemoved(x, y)
  if Tutorial.is_complete(self.state) then return end
  local step = Tutorial.current(self.state)
  if step and step.manual_advance and self.continue_button then
    self.continue_button:mousemoved(x, y)
  end
end

function TutorialOverlay:mousepressed(x, y, btn)
  if Tutorial.is_complete(self.state) then return end
  local step = Tutorial.current(self.state)
  if step and step.manual_advance and self.continue_button then
    self.continue_button:mousepressed(x, y, btn)
  end
end

function TutorialOverlay:mousereleased(x, y, btn)
  if Tutorial.is_complete(self.state) then return end
  local step = Tutorial.current(self.state)
  if step and step.manual_advance and self.continue_button then
    self.continue_button:mousereleased(x, y, btn)
  end
end

return { new = new }
```

### `tests/spec/tutorial_spec.lua`

```lua
local Tutorial = require("src.game.tutorial")

describe("Tutorial", function()
  it("starts at step 1", function()
    local s = Tutorial.new()
    assert.is_equal(1, s.step_idx)
    assert.is_not_nil(Tutorial.current(s))
  end)

  it("manual_advance bumps step_idx", function()
    local s = Tutorial.new()
    Tutorial.manual_advance(s)
    assert.is_equal(2, s.step_idx)
  end)

  it("manual_advance is a no-op on auto-advance steps", function()
    local s = Tutorial.new()
    s.step_idx = 3  -- step 3 is "click a backlog ticket" (auto-advance)
    Tutorial.manual_advance(s)
    assert.is_equal(3, s.step_idx)
  end)

  it("advance walks through manual_advance steps when conditions met", function()
    local s = Tutorial.new()
    s.step_idx = 1  -- manual
    Tutorial.advance(s, {})  -- manual step does not auto-advance
    assert.is_equal(1, s.step_idx)
  end)

  it("advance walks past auto-advance steps when condition is true", function()
    local s = Tutorial.new()
    s.step_idx = 3  -- "click a backlog ticket"
    s.kanban_selected_in_backlog = true
    Tutorial.advance(s, { in_progress = {}, review = {}, done = {} })
    assert.is_equal(4, s.step_idx)
  end)

  it("is_complete returns true when step_idx exceeds STEPS length", function()
    local s = Tutorial.new()
    s.step_idx = #Tutorial.STEPS + 1
    assert.is_true(Tutorial.is_complete(s))
  end)
end)
```

Workflow:
1. Write `src/game/tutorial.lua`.
2. Write `src/ui/components/tutorial_overlay.lua`.
3. Write `tests/spec/tutorial_spec.lua`.
4. `busted` → 179 successes (173 after T1 + 6 new).
5. Commit:

```
Add Tutorial step list and overlay UI

src/game/tutorial.lua holds 13 hard-coded steps with text + optional
advance conditions. src/ui/components/tutorial_overlay.lua renders the
current step as a top-center bubble with a Continue button on manual-
advance steps. 6 tests cover step progression.
```

---

### Task 3: Wire tutorial overlay + tutorial-mode bypass into game state

**Files:**
- Modify: `src/game/game_session.lua` (allow self-approve in tutorial_mode)
- Modify: `src/states/game.lua`

### `src/game/game_session.lua`

Find:

```lua
function GameSession:approve(id)
  require_turns_phase(self); require_ap(self)
  local t = find_in(self.review, id)
  assert(t, "no such ticket in review: " .. tostring(id))
  assert(self.current_actor ~= t.owner, "actor cannot approve own ticket")
```

Replace the `assert(self.current_actor ...)` line with a tutorial-mode-aware version:

```lua
  if not self.session.config.tutorial_mode then
    assert(self.current_actor ~= t.owner, "actor cannot approve own ticket")
  end
```

Similarly for `reject`:

```lua
  if not self.session.config.tutorial_mode then
    assert(self.current_actor ~= t.owner, "actor cannot reject own ticket")
  end
```

### `src/states/game.lua`

Add requires (after the existing `DilemmaDialog`):

```lua
local DilemmaDialog = require("src.ui.components.dilemma_dialog")
local Dilemmas = require("src.game.dilemmas")
local Tutorial = require("src.game.tutorial")
local TutorialOverlay = require("src.ui.components.tutorial_overlay")
```

In `M:enter`, AFTER `build_layout(...)`, insert:

```lua
  if self.session.config.tutorial_mode then
    self.tutorial = Tutorial.new()
    self.tutorial_overlay = TutorialOverlay.new({
      state = self.tutorial,
      on_advance = function() end,
    })
    -- For tutorial: give the lone player generous AP to avoid getting stuck.
    self.game_session.session.config.ap_per_turn = 5
    for _, p in ipairs(self.game_session.players) do p.ap = 5 end
  end
```

Add a helper inside `build_layout` to track tutorial-trigger events. Replace the `add("Meeting", ...)` block:

```lua
  add("Meeting", function()
    gs:do_meeting()
    local card = Dilemmas.draw(gs.rng, gs.dilemmas_drawn)
    if card then
      self.dilemma_dialog:open(card, love.graphics.getWidth(), love.graphics.getHeight())
    end
    if self.tutorial then self.tutorial.meeting_done = true end
  end, function()
    return actor_has_ap()
  end)
```

Wrap the existing `dilemma_dialog.on_choose` to also set tutorial state. Find:

```lua
  self.dilemma_dialog = DilemmaDialog.new({
    on_choose = function(dilemma, choice)
      Dilemmas.resolve(gs, dilemma, choice)
      if gs.ended then fsm:transition("end_screen") end
    end,
  })
```

Replace with:

```lua
  self.dilemma_dialog = DilemmaDialog.new({
    on_choose = function(dilemma, choice)
      Dilemmas.resolve(gs, dilemma, choice)
      if self.tutorial then self.tutorial.dilemma_resolved = true end
      if gs.ended then fsm:transition("end_screen") end
    end,
  })
```

Similarly for `sabotage_menu`:

```lua
  self.sabotage_menu = SabotageMenu.new({
    game_session = gs,
    kanban = kanban,
    on_close = function()
      if self.tutorial then self.tutorial.sabotage_closed = true end
      if gs.ended then fsm:transition("end_screen") end
    end,
  })
```

Replace `add("End Turn", ...)`:

```lua
  add("End Turn", function()
    gs:end_turn()
    kanban.selected_id = nil
    while gs.sprint_phase == "retro" do
      gs:advance_phase()
    end
    if self.tutorial then self.tutorial.end_turn_done = true end
    if gs.ended then
      fsm:transition("end_screen")
    end
  end, function() return true end)
```

In `M:mousepressed`, after the call to `self.kanban:mousepressed(x, y, btn)`, also bump the tutorial's `kanban_selected_in_backlog`:

```lua
function M:mousepressed(x, y, btn)
  if self.dilemma_dialog.visible then
    self.dilemma_dialog:mousepressed(x, y, btn)
    return
  end
  if self.sabotage_menu.visible then
    self.sabotage_menu:mousepressed(x, y, btn)
    return
  end
  if self.tutorial_overlay then
    self.tutorial_overlay:mousepressed(x, y, btn)
  end
  self.kanban:mousepressed(x, y, btn)
  if self.tutorial and self.kanban.selected_id then
    local t = self.kanban:get_selected()
    if t and t.column == "backlog" then
      self.tutorial.kanban_selected_in_backlog = true
    end
  end
  for _, b in ipairs(self.action_buttons) do
    local enabled = b._predicate == nil or b._predicate()
    if enabled then b:mousepressed(x, y, btn) end
  end
  -- After any action, advance the tutorial if conditions are met.
  if self.tutorial then
    Tutorial.advance(self.tutorial, self.game_session)
  end
end
```

Also handle mousemoved/mousereleased routing to the overlay's continue button:

```lua
function M:mousemoved(x, y)
  if self.dilemma_dialog.visible then ... end
  if self.sabotage_menu.visible then ... end
  if self.tutorial_overlay then self.tutorial_overlay:mousemoved(x, y) end
  self.kanban:mousemoved(x, y)
  ...
end

function M:mousereleased(x, y, btn)
  if self.dilemma_dialog.visible then ... end
  if self.sabotage_menu.visible then ... end
  if self.tutorial_overlay then self.tutorial_overlay:mousereleased(x, y, btn) end
  self.kanban:mousereleased(x, y, btn)
  ...
end
```

(Apply these mousemoved/mousereleased changes in addition to keeping the existing logic — overlay receives input before kanban + buttons.)

In `M:draw`, after `self.dilemma_dialog:draw()`, add:

```lua
  if self.tutorial_overlay then self.tutorial_overlay:draw() end
```

Workflow:
1. Modify game_session.lua (approve/reject tutorial_mode bypass).
2. Modify game.lua (requires, M:enter tutorial setup, action callbacks tutorial flags, input routing, draw call).
3. `busted` → 179.
4. `timeout 5 love . 2>&1 | head -20` → no errors.
5. Commit:

```
Wire Sprint Tutorial overlay + flow into game state

GameSession's approve/reject skip the owner-check when
session.config.tutorial_mode is true, letting a 1-player tutorial
self-approve. Game state instantiates a Tutorial + TutorialOverlay on
enter when tutorial mode is active; the overlay renders a top-center
bubble with the current step's instruction; every action callback
flips a tutorial state flag, and Tutorial.advance() is called after
each click to walk through the 13-step script.
```

---

### Task 4: Smoke

- `love .` → menu → New Game → mode-select → click "Tutorial — Sprint" → game opens with a yellow tutorial bubble at top.
- Click Continue twice to get past the intro screens.
- Click a backlog ticket → bubble advances.
- Click Claim → bubble advances.
- Click ticket, click Work twice → bubble advances.
- Click Submit → bubble advances.
- Click ticket in Review, click Approve → bubble advances.
- Click Meeting → bubble advances → Dilemma dialog → pick a choice → bubble advances.
- Click Sabotage → menu opens → Close → bubble advances.
- Click End Turn → bubble advances (now at the final step).
- Click End Game → end_screen → menu.

---

## Done

When all tasks check, Sprint Tutorial ships. Plan 12 (deferred-mode tutorial stubs) is the next layer.
