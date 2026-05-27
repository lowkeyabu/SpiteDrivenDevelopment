# Cleanup + Mode Select Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Address every foundation-hygiene finding from Plan 1's final review (I1–I3, M1, M6), introduce a `Session` data object that will carry game-wide configuration through the rest of the project, and replace the `mode_select` placeholder with a real screen that lists the five game modes (Sprint available; Floor / Ladder / Hybrid / Story marked "Coming soon"), persists the chosen mode to the session, and advances to the next placeholder.

**Architecture:** State modules become factory-style: each module exports a `new(deps)` constructor that returns a configured instance closing over `deps.fsm` and `deps.session`. `main.lua` instantiates the FSM, instantiates a `Session`, packages them as `deps`, calls each state's `.new(deps)`, and registers the resulting instance with the FSM. The FSM grows a re-entrance guard so states that auto-transition from inside `enter`/`leave` don't clobber state. RNG's default seed gains microsecond entropy. Button drops its synthetic `:click` test path in favor of `mousepressed`/`mousereleased` only, and stops swallowing real require errors.

**Tech Stack:** Lua 5.1+ (Love2D embed), Love2D 11.x runtime, busted for tests.

**Scope:** Plan 2 of 9. Builds on the skeleton from Plan 1. After this plan: every state module follows the factory pattern; a Session object flows through the FSM; the mode-select screen actually lets the user pick the Sprint mode. Pre-game config + player setup are Plan 3.

**Spec reference:** `docs/superpowers/specs/2026-04-21-spite-driven-development-design.md`, §4 (Game Modes), §5 (Pre-Game Configuration).

**Final-review findings from Plan 1 addressed by this plan:**

- **I1.** Button has two click entry points (`:click` direct + `:mousereleased` after press). Removed.
- **I2.** State modules mutate themselves with `mod.fsm = fsm`. Replaced with explicit factory-based DI.
- **I3.** FSM allows nested transitions silently. Guarded.
- **M1.** RNG default seed uses one-second-resolution `os.time()`. Mixed in sub-second entropy.
- **M6.** Button uses `pcall(require, "src.ui.typography")` which swallows real errors. Replaced with explicit Love-presence check.

---

## File Map

Files created or modified by this plan:

```
.
├── main.lua                            (modified — factory wiring + Session)
├── src/
│   ├── game/
│   │   └── session.lua                 (new — game-wide config object)
│   ├── states/
│   │   ├── menu.lua                    (modified — factory pattern)
│   │   ├── mode_select.lua             (replaced — real screen with mode list)
│   │   ├── config.lua                  (modified — factory pattern, still placeholder)
│   │   ├── player_setup.lua            (modified — factory pattern, still placeholder)
│   │   ├── game.lua                    (modified — factory pattern, still placeholder)
│   │   └── end_screen.lua              (modified — factory pattern, still placeholder)
│   ├── ui/
│   │   └── components/
│   │       └── button.lua              (modified — remove `:click`, swap pcall, font_size option)
│   └── util/
│       ├── fsm.lua                     (modified — re-entrance guard)
│       └── rng.lua                     (modified — better default seed entropy)
└── tests/
    └── spec/
        ├── button_spec.lua             (modified — drop direct `:click` tests)
        ├── fsm_spec.lua                (modified — add re-entrance test)
        ├── rng_spec.lua                (unchanged but verified)
        └── session_spec.lua            (new — default config + setters + validation)
```

---

## Conventions

- 2-space indent.
- `snake_case` for module functions and locals.
- Each module returns a table; functions are declared `local` and listed in the return table.
- State modules export `M.new(deps)` returning an instance; instance methods use `function M:method(...)` and access `self.fsm` / `self.session`.
- Lua files end with a final newline.
- Commit after each task. Commits are atomic (one task = one commit unless explicitly noted otherwise).
- Test files live under `tests/spec/` and end in `_spec.lua`.

---

### Task 1: Fix RNG default seed entropy (M1)

**Files:**
- Modify: `src/util/rng.lua`
- Modify: `tests/spec/rng_spec.lua`

Plan 1's RNG used `os.time()` as the default seed if none provided. That has 1-second resolution; two RNGs constructed in the same second get the same sequence. Mix in `os.clock()` (process-clock seconds with sub-second resolution) and a small per-call counter so default-seeded RNGs constructed back-to-back diverge.

- [ ] **Step 1: Add a failing test for default-seed divergence**

Append to `tests/spec/rng_spec.lua` (inside the existing `describe` block, before its closing `end)`):

```lua
  it("default-seeded RNGs constructed back-to-back produce different sequences", function()
    local a = RNG.new()
    local b = RNG.new()
    local same = true
    for _ = 1, 32 do
      if a:random() ~= b:random() then same = false; break end
    end
    assert.is_false(same)
  end)
```

- [ ] **Step 2: Run the test to confirm it fails**

Run: `busted tests/spec/rng_spec.lua -v`

Expected: 1 failure on `default-seeded RNGs constructed back-to-back produce different sequences` (both RNGs share the same `os.time()` second so they produce identical sequences).

- [ ] **Step 3: Replace the default-seed branch in `src/util/rng.lua`**

Replace the existing `seed = seed or os.time()` block with a richer default. Find this block (around line 22):

```lua
local function new(seed)
  seed = seed or os.time()
  local backend
```

Replace with:

```lua
local _default_seed_counter = 0

local function default_seed()
  _default_seed_counter = (_default_seed_counter + 1) % 2147483647
  -- Mix wall time (seconds), process time (sub-second), and a per-call counter.
  local wall = os.time()
  local proc = math.floor((os.clock() % 1) * 1e6)
  return (wall * 1000003 + proc * 1009 + _default_seed_counter) % 2147483647
end

local function new(seed)
  seed = seed or default_seed()
  local backend
```

(`_default_seed_counter` and `default_seed` are local-to-file; they're not exported.)

- [ ] **Step 4: Run all RNG tests to confirm pass**

Run: `busted tests/spec/rng_spec.lua -v`

Expected: 6 successes / 0 failures (the original 5 plus the new default-seed test).

- [ ] **Step 5: Commit**

```bash
git add src/util/rng.lua tests/spec/rng_spec.lua
git commit -m "$(cat <<'EOF'
Mix sub-second entropy into RNG default seed (fix M1)

Default-seeded RNGs constructed within the same second now diverge thanks
to a mix of os.clock() microseconds and a process-local call counter.
Explicit-seed RNGs are unchanged.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Clean up Button — remove dual click path (I1), fix pcall (M6), add `font_size` option (M5)

**Files:**
- Modify: `src/ui/components/button.lua`
- Modify: `tests/spec/button_spec.lua`

Button currently exposes a synthetic `:click(px, py)` method that the test suite drives directly. That's a parallel click path to the real `mousepressed` → `mousereleased` flow used at runtime, which makes the actual behavior ambiguous. Drop `:click`. Replace `pcall(require, ...)` with an explicit Love-presence check. Make the label's font size configurable via constructor opts.

- [ ] **Step 1: Replace `tests/spec/button_spec.lua` with the cleaned-up spec**

Overwrite the whole file with:

```lua
local Button = require("src.ui.components.button")

describe("Button", function()
  it("hit returns true for a point inside its bounds", function()
    local b = Button.new({ x = 10, y = 20, w = 100, h = 40, label = "ok" })
    assert.is_true(b:hit(50, 30))
    assert.is_true(b:hit(10, 20))            -- top-left corner
    assert.is_true(b:hit(109, 59))           -- bottom-right inside corner
  end)

  it("hit returns false for points outside", function()
    local b = Button.new({ x = 10, y = 20, w = 100, h = 40, label = "ok" })
    assert.is_false(b:hit(0, 0))
    assert.is_false(b:hit(120, 30))
    assert.is_false(b:hit(50, 5))
    assert.is_false(b:hit(50, 80))
    assert.is_false(b:hit(110, 60))          -- one past bottom-right
  end)

  it("press-then-release inside fires the click handler", function()
    local clicked = false
    local b = Button.new({
      x = 0, y = 0, w = 50, h = 50,
      on_click = function() clicked = true end,
    })
    b:mousepressed(10, 10, 1)
    b:mousereleased(10, 10, 1)
    assert.is_true(clicked)
  end)

  it("press inside then release outside does not fire", function()
    local clicked = false
    local b = Button.new({
      x = 0, y = 0, w = 50, h = 50,
      on_click = function() clicked = true end,
    })
    b:mousepressed(10, 10, 1)
    b:mousereleased(99, 99, 1)
    assert.is_false(clicked)
  end)

  it("press outside then release inside does not fire", function()
    local clicked = false
    local b = Button.new({
      x = 0, y = 0, w = 50, h = 50,
      on_click = function() clicked = true end,
    })
    b:mousepressed(99, 99, 1)
    b:mousereleased(10, 10, 1)
    assert.is_false(clicked)
  end)

  it("non-primary mouse buttons do not fire on_click", function()
    local clicked = false
    local b = Button.new({
      x = 0, y = 0, w = 50, h = 50,
      on_click = function() clicked = true end,
    })
    b:mousepressed(10, 10, 2)
    b:mousereleased(10, 10, 2)
    assert.is_false(clicked)
  end)

  it("defaults label to an empty string, on_click to a no-op, font_size to 'md'", function()
    local b = Button.new({ x = 0, y = 0, w = 10, h = 10 })
    assert.is_equal("", b.label)
    assert.is_equal("md", b.font_size)
    assert.has_no.errors(function()
      b:mousepressed(5, 5, 1)
      b:mousereleased(5, 5, 1)
    end)
  end)

  it("accepts a font_size override via constructor", function()
    local b = Button.new({ x = 0, y = 0, w = 10, h = 10, font_size = "lg" })
    assert.is_equal("lg", b.font_size)
  end)

  it("mousemoved updates the hover flag", function()
    local b = Button.new({ x = 0, y = 0, w = 50, h = 50 })
    assert.is_false(b.hover)
    b:mousemoved(10, 10)
    assert.is_true(b.hover)
    b:mousemoved(99, 99)
    assert.is_false(b.hover)
  end)
end)
```

- [ ] **Step 2: Run the spec to see the new tests fail**

Run: `busted tests/spec/button_spec.lua -v`

Expected: failures on the new behaviors. The existing `hit` tests should still pass, but the new mousepressed/mousereleased / non-primary / font_size / mousemoved tests will fail or error.

Specifically:
- The current Button code has a `:click` method the new spec no longer uses; that's fine.
- `font_size` defaults to `"md"` only in spec — the current Button doesn't store `font_size` on the instance.
- `mousepressed`/`mousereleased`/`mousemoved` already exist; their semantics should already pass except `font_size` defaults.

- [ ] **Step 3: Replace `src/ui/components/button.lua` with the cleaned-up implementation**

```lua
-- Rectangular button with paper-card styling. Hit detection and click
-- handling are pure logic (testable with busted). Rendering uses
-- love.graphics and is verified manually.

local Button = {}
Button.__index = Button

local function noop() end

local function new(opts)
  return setmetatable({
    x = opts.x or 0,
    y = opts.y or 0,
    w = opts.w or 120,
    h = opts.h or 40,
    label = opts.label or "",
    font_size = opts.font_size or "md",
    on_click = opts.on_click or noop,
    hover = false,
    pressed = false,
  }, Button)
end

function Button:hit(px, py)
  return px >= self.x
     and py >= self.y
     and px < self.x + self.w
     and py < self.y + self.h
end

function Button:mousemoved(x, y)
  self.hover = self:hit(x, y)
end

function Button:mousepressed(x, y, btn)
  if btn == 1 and self:hit(x, y) then
    self.pressed = true
  end
end

function Button:mousereleased(x, y, btn)
  if btn ~= 1 then return end
  if self.pressed and self:hit(x, y) then
    self.on_click()
  end
  self.pressed = false
end

function Button:draw()
  if not (love and love.graphics) then return end

  -- Paper card with a 1px dark border. Hover lightens the fill; pressed darkens.
  local fill_r, fill_g, fill_b = 1, 1, 1
  if self.pressed then
    fill_r, fill_g, fill_b = 0.86, 0.84, 0.78
  elseif self.hover then
    fill_r, fill_g, fill_b = 0.99, 0.97, 0.91
  end

  love.graphics.setColor(fill_r, fill_g, fill_b)
  love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
  love.graphics.setColor(0.1, 0.1, 0.1)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", self.x, self.y, self.w, self.h)

  -- Label
  local typography = require("src.ui.typography")
  typography.with(self.font_size, function()
    love.graphics.setColor(0.1, 0.1, 0.1)
    local font = love.graphics.getFont()
    local tw = font:getWidth(self.label)
    local th = font:getHeight()
    love.graphics.print(self.label,
      self.x + (self.w - tw) / 2,
      self.y + (self.h - th) / 2)
  end)
end

return {
  new = new,
}
```

Key changes from Plan 1's version:
- `:click(px, py)` method removed entirely.
- `:mousereleased` now early-exits for non-primary mouse buttons.
- `:draw` short-circuits when Love isn't present (so busted-side imports don't crash), then `require`s typography directly inside the draw call rather than via `pcall` at module load. Real require failures will now surface as errors at draw time, not be silently swallowed.
- Constructor stores `font_size` (default `"md"`).

- [ ] **Step 4: Run the spec to confirm pass**

Run: `busted tests/spec/button_spec.lua -v`

Expected: 9 successes / 0 failures.

- [ ] **Step 5: Run the full test suite to make sure nothing regressed**

Run: `busted -v`

Expected: 22 successes / 0 failures (7 FSM + 6 RNG + 9 Button — totals include the new tests added in Tasks 1 and 2).

- [ ] **Step 6: Commit**

```bash
git add src/ui/components/button.lua tests/spec/button_spec.lua
git commit -m "$(cat <<'EOF'
Clean up Button: drop synthetic :click, surface require errors, add font_size opt

- Removes the :click(px, py) test-only entry point; the real click path
  is press-inside-then-release-inside (fix I1).
- Replaces pcall(require, typography) with an explicit love-presence
  check at draw time, so genuine require errors aren't swallowed (fix M6).
- Stores font_size on the instance (defaults to "md") so callers can
  request a different label size (addresses M5).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: FSM — add re-entrant transition guard (I3)

**Files:**
- Modify: `src/util/fsm.lua`
- Modify: `tests/spec/fsm_spec.lua`

If a state's `enter` or `leave` calls `fsm:transition(...)`, the in-flight transition gets clobbered: the new state's `enter` fires before the outer transition finishes, and the outer state's `enter` then proceeds on stale state. Guard with a `transitioning` flag and raise loudly if a nested call occurs.

- [ ] **Step 1: Add a failing test for the guard**

Append to `tests/spec/fsm_spec.lua` (inside the existing `describe`, before its closing `end)`):

```lua
  it("raises if a state's enter or leave calls transition on the same fsm", function()
    local fsm = FSM.new()
    fsm:register("a", {
      enter = function(self)
        fsm:transition("b")
      end,
    })
    fsm:register("b", {})
    assert.has_error(function() fsm:start("a") end)
  end)
```

- [ ] **Step 2: Run the test to see it fail**

Run: `busted tests/spec/fsm_spec.lua -v`

Expected: failure on the new "raises if a state's enter or leave..." test. Without the guard, the nested `transition` silently overwrites `current_name` and the call returns normally instead of erroring.

- [ ] **Step 3: Update `src/util/fsm.lua` to add the guard**

Find the `FSM:transition` function and the `FSM:start` function. Replace them with the guarded versions:

```lua
function FSM:start(name)
  assert(not self._transitioning, "FSM:start called during a transition")
  local state = self.states[name]
  assert(state, "no such state: " .. tostring(name))
  self._transitioning = true
  self.current_name = name
  if state.enter then state:enter() end
  self._transitioning = false
end

function FSM:transition(name)
  assert(not self._transitioning, "FSM:transition called during a transition (nested)")
  local next_state = self.states[name]
  assert(next_state, "no such state: " .. tostring(name))
  self._transitioning = true
  local prev = self.states[self.current_name]
  if prev and prev.leave then prev:leave() end
  self.current_name = name
  if next_state.enter then next_state:enter() end
  self._transitioning = false
end
```

`new()` doesn't need to set `_transitioning = false` explicitly — nil is falsy.

- [ ] **Step 4: Run the spec to confirm pass**

Run: `busted tests/spec/fsm_spec.lua -v`

Expected: 8 successes / 0 failures.

- [ ] **Step 5: Run the full suite**

Run: `busted`

Expected: 23 successes / 0 failures (8 FSM + 6 RNG + 9 Button).

- [ ] **Step 6: Commit**

```bash
git add src/util/fsm.lua tests/spec/fsm_spec.lua
git commit -m "$(cat <<'EOF'
Guard FSM against re-entrant transitions (fix I3)

A state's enter or leave callback calling fsm:transition (or fsm:start)
on the same FSM now raises loudly instead of silently clobbering the
in-flight transition. Document the guard with a test.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Create the Session module

**Files:**
- Create: `src/game/session.lua`
- Create: `tests/spec/session_spec.lua`

The Session is a plain-data object carrying game-wide configuration through every state. It's set up by the config screen (Plan 3), read by the game screen (Plan 4+), and finally exposed on the end screen for the LinkedIn-roast composition (Plan 8). For Plan 2 we only need its existence, default values, and a setter for the chosen mode.

- [ ] **Step 1: Write the failing spec**

Create `tests/spec/session_spec.lua`:

```lua
local Session = require("src.game.session")

describe("Session", function()
  it("has documented defaults", function()
    local s = Session.new()
    assert.is_equal("MegaCorp", s.config.company_name)
    assert.is_equal(3, s.config.ap_per_turn)
    assert.is_equal(8, s.config.turn_cap)
    assert.is_equal(30, s.config.comp_target)
    assert.is_equal("first_to_csuite_or_5_sprints", s.config.end_trigger)
    assert.is_true(s.config.tier_gating)
    assert.is_nil(s.mode)
    assert.are.same({}, s.players)
  end)

  it("sets and reports the chosen mode", function()
    local s = Session.new()
    s:set_mode("sprint")
    assert.is_equal("sprint", s.mode)
  end)

  it("rejects an unknown mode", function()
    local s = Session.new()
    assert.has_error(function() s:set_mode("clown_mode") end)
  end)

  it("lists the known modes (Sprint available, others deferred)", function()
    local modes = Session.MODES
    assert.is_table(modes)
    -- Each entry has id, label, available (bool).
    local by_id = {}
    for _, m in ipairs(modes) do by_id[m.id] = m end
    assert.is_true(by_id.sprint.available)
    assert.is_false(by_id.floor.available)
    assert.is_false(by_id.ladder.available)
    assert.is_false(by_id.hybrid.available)
    assert.is_false(by_id.story.available)
  end)

  it("set_mode rejects modes that are not available", function()
    local s = Session.new()
    assert.has_error(function() s:set_mode("floor") end)
    assert.is_nil(s.mode)
  end)
end)
```

- [ ] **Step 2: Run the spec to see it fail**

Run: `busted tests/spec/session_spec.lua -v`

Expected: `module 'src.game.session' not found`.

- [ ] **Step 3: Create the `src/game/` directory and implement `src/game/session.lua`**

```lua
-- Game-wide configuration carried through every state from pre-game
-- through end-screen. Plan 2 establishes the shape; Plan 3 wires the
-- config UI to its setters; subsequent plans read it from gameplay code.

local Session = {}
Session.__index = Session

-- Mode catalog. Keep in one place so the mode-select screen and
-- Session:set_mode validation agree.
Session.MODES = {
  { id = "sprint", label = "The Sprint",  available = true,
    blurb = "Shared JIRA Kanban. Ticket cards flow Backlog → Done. v1." },
  { id = "floor", label = "The Floor",  available = false,
    blurb = "Monopoly-style office loop with desk rent. Coming later." },
  { id = "ladder", label = "The Ladder", available = false,
    blurb = "Per-player promotion tracks, action-point only. Coming later." },
  { id = "hybrid", label = "Hybrid",     available = false,
    blurb = "Floor board + per-player ladders. Coming later." },
  { id = "story", label = "Story Mode",  available = false,
    blurb = "Single-player narrative campaign (nilpointerr). Coming later." },
}

local function defaults()
  return {
    company_name = "MegaCorp",
    player_count = 2,
    ap_per_turn = 3,
    end_trigger = "first_to_csuite_or_5_sprints",
    comp_target = 30,
    turn_cap = 8,
    tier_gating = true,
  }
end

local function new()
  return setmetatable({
    mode = nil,
    config = defaults(),
    players = {},
  }, Session)
end

function Session:set_mode(id)
  for _, m in ipairs(Session.MODES) do
    if m.id == id then
      assert(m.available, "mode not available yet: " .. id)
      self.mode = id
      return
    end
  end
  error("unknown mode: " .. tostring(id))
end

return {
  new = new,
  MODES = Session.MODES,
}
```

- [ ] **Step 4: Run the spec to confirm pass**

Run: `busted tests/spec/session_spec.lua -v`

Expected: 5 successes / 0 failures.

- [ ] **Step 5: Full suite check**

Run: `busted`

Expected: 28 successes / 0 failures (8 FSM + 6 RNG + 9 Button + 5 Session).

- [ ] **Step 6: Commit**

```bash
git add src/game/session.lua tests/spec/session_spec.lua
git commit -m "$(cat <<'EOF'
Add Session module with config defaults and mode catalog

Session is the plain-data object carried through every screen. Plan 2
establishes the shape (config defaults, MODES catalog, set_mode with
availability gating) so the upcoming mode-select screen can persist
the user's choice. Pre-game config (Plan 3) wires its widgets to
Session.config; gameplay (Plan 4+) reads from it.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: Refactor state modules to the factory pattern (I2)

**Files:**
- Modify: `src/states/menu.lua`
- Modify: `src/states/mode_select.lua`
- Modify: `src/states/config.lua`
- Modify: `src/states/player_setup.lua`
- Modify: `src/states/game.lua`
- Modify: `src/states/end_screen.lua`
- Modify: `main.lua`

Today each state is a module-level table that `main.lua` mutates with `mod.fsm = fsm`. Switch to per-instance factories so each state gets a fresh closure over `deps = { fsm, session }`. This is a large mechanical change across seven files; the diffs are nearly identical for each state.

This is one commit (atomic refactor — the partial state would be broken).

- [ ] **Step 1: Rewrite `src/states/menu.lua` to factory form**

Overwrite the file:

```lua
local Button = require("src.ui.components.button")
local typography = require("src.ui.typography")

local M = {}
M.__index = M

local function build_buttons(self, w, h)
  local btn_w, btn_h = 320, 56
  local cx = (w - btn_w) / 2
  local cy = h / 2 + 20

  local fsm = self.fsm
  self.buttons = {
    Button.new({
      x = cx, y = cy, w = btn_w, h = btn_h,
      label = "New Game",
      on_click = function() fsm:transition("mode_select") end,
    }),
    Button.new({
      x = cx, y = cy + btn_h + 16, w = btn_w, h = btn_h,
      label = "Quit",
      on_click = function() love.event.quit() end,
    }),
  }
end

local function new(deps)
  return setmetatable({
    fsm = deps.fsm,
    session = deps.session,
  }, M)
end

function M:enter()
  build_buttons(self, love.graphics.getWidth(), love.graphics.getHeight())
end

function M:resize(w, h)
  build_buttons(self, w, h)
end

function M:draw()
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()

  typography.with("display", function()
    love.graphics.setColor(0.1, 0.1, 0.1)
    local font = love.graphics.getFont()
    local title = "Spite Driven Development"
    local tw = font:getWidth(title)
    love.graphics.print(title, (w - tw) / 2, h / 4)
  end)

  typography.with("md", function()
    love.graphics.setColor(0.3, 0.3, 0.3)
    local font = love.graphics.getFont()
    local sub = "a parody boardgame"
    local sw = font:getWidth(sub)
    love.graphics.print(sub, (w - sw) / 2, h / 4 + 70)
  end)

  for _, b in ipairs(self.buttons) do b:draw() end
end

function M:mousemoved(x, y)
  for _, b in ipairs(self.buttons) do b:mousemoved(x, y) end
end

function M:mousepressed(x, y, btn)
  for _, b in ipairs(self.buttons) do b:mousepressed(x, y, btn) end
end

function M:mousereleased(x, y, btn)
  for _, b in ipairs(self.buttons) do b:mousereleased(x, y, btn) end
end

function M:keypressed(key)
  if key == "escape" then
    love.event.quit()
  elseif key == "return" then
    self.fsm:transition("mode_select")
  end
end

return {
  new = new,
}
```

- [ ] **Step 2: Rewrite the 5 placeholder states**

Each is a near-identical factory wrapping the same `enter / draw / keypressed` shape. The only differences are the message text and the next-state name. Replace each file in full.

`src/states/mode_select.lua` (still placeholder — replaced for real in Task 6):

```lua
local M = {}
M.__index = M

local function new(deps)
  return setmetatable({
    fsm = deps.fsm,
    session = deps.session,
  }, M)
end

function M:enter()
  self.message = "MODE_SELECT — press SPACE to advance to config"
end

function M:draw()
  love.graphics.setColor(0.1, 0.1, 0.1)
  love.graphics.print(self.message, 40, 40)
end

function M:keypressed(key)
  if key == "space" then
    self.fsm:transition("config")
  elseif key == "escape" then
    self.fsm:transition("menu")
  end
end

return {
  new = new,
}
```

`src/states/config.lua`:

```lua
local M = {}
M.__index = M

local function new(deps)
  return setmetatable({
    fsm = deps.fsm,
    session = deps.session,
  }, M)
end

function M:enter()
  self.message = "CONFIG — press SPACE to advance to player_setup"
end

function M:draw()
  love.graphics.setColor(0.1, 0.1, 0.1)
  love.graphics.print(self.message, 40, 40)
end

function M:keypressed(key)
  if key == "space" then
    self.fsm:transition("player_setup")
  elseif key == "escape" then
    self.fsm:transition("menu")
  end
end

return {
  new = new,
}
```

`src/states/player_setup.lua`:

```lua
local M = {}
M.__index = M

local function new(deps)
  return setmetatable({
    fsm = deps.fsm,
    session = deps.session,
  }, M)
end

function M:enter()
  self.message = "PLAYER_SETUP — press SPACE to advance to game"
end

function M:draw()
  love.graphics.setColor(0.1, 0.1, 0.1)
  love.graphics.print(self.message, 40, 40)
end

function M:keypressed(key)
  if key == "space" then
    self.fsm:transition("game")
  elseif key == "escape" then
    self.fsm:transition("menu")
  end
end

return {
  new = new,
}
```

`src/states/game.lua`:

```lua
local M = {}
M.__index = M

local function new(deps)
  return setmetatable({
    fsm = deps.fsm,
    session = deps.session,
  }, M)
end

function M:enter()
  self.message = "GAME — press SPACE to advance to end_screen"
end

function M:draw()
  love.graphics.setColor(0.1, 0.1, 0.1)
  love.graphics.print(self.message, 40, 40)
end

function M:keypressed(key)
  if key == "space" then
    self.fsm:transition("end_screen")
  elseif key == "escape" then
    self.fsm:transition("menu")
  end
end

return {
  new = new,
}
```

`src/states/end_screen.lua`:

```lua
local M = {}
M.__index = M

local function new(deps)
  return setmetatable({
    fsm = deps.fsm,
    session = deps.session,
  }, M)
end

function M:enter()
  self.message = "END_SCREEN — press SPACE to return to menu"
end

function M:draw()
  love.graphics.setColor(0.1, 0.1, 0.1)
  love.graphics.print(self.message, 40, 40)
end

function M:keypressed(key)
  if key == "space" then
    self.fsm:transition("menu")
  elseif key == "escape" then
    self.fsm:transition("menu")
  end
end

return {
  new = new,
}
```

- [ ] **Step 3: Rewrite `main.lua` to wire the factories with deps**

```lua
local FSM = require("src.util.fsm")
local Session = require("src.game.session")
local typography = require("src.ui.typography")

local fsm
local session

local STATES = {
  "menu",
  "mode_select",
  "config",
  "player_setup",
  "game",
  "end_screen",
}

function love.load()
  love.graphics.setBackgroundColor(0.96, 0.94, 0.86) -- paper tone
  typography.init()

  fsm = FSM.new()
  session = Session.new()
  local deps = { fsm = fsm, session = session }

  for _, name in ipairs(STATES) do
    local mod = require("src.states." .. name)
    fsm:register(name, mod.new(deps))
  end
  fsm:start("menu")
end

function love.update(dt) fsm:dispatch("update", dt) end
function love.draw() fsm:dispatch("draw") end
function love.keypressed(key, scancode, isrepeat) fsm:dispatch("keypressed", key, scancode, isrepeat) end
function love.keyreleased(key, scancode) fsm:dispatch("keyreleased", key, scancode) end
function love.mousepressed(x, y, button, istouch, presses) fsm:dispatch("mousepressed", x, y, button, istouch, presses) end
function love.mousereleased(x, y, button, istouch, presses) fsm:dispatch("mousereleased", x, y, button, istouch, presses) end
function love.mousemoved(x, y, dx, dy, istouch) fsm:dispatch("mousemoved", x, y, dx, dy, istouch) end
function love.wheelmoved(dx, dy) fsm:dispatch("wheelmoved", dx, dy) end
function love.textinput(text) fsm:dispatch("textinput", text) end
function love.resize(w, h) fsm:dispatch("resize", w, h) end
```

- [ ] **Step 4: Run the full test suite — should still pass (state modules aren't unit-tested)**

Run: `busted`

Expected: 28 successes / 0 failures (8 FSM + 6 RNG + 9 Button + 5 Session).

- [ ] **Step 5: Boot Love to verify menu still renders and navigates**

Run: `timeout 4 love . 2>&1 | head -20`

Expected: no error output, exit 124 or 143 from the timeout. If Love prints a stack trace (typically containing `Error` or `Stack Traceback`), the refactor introduced a regression — fix it before committing.

If a screen environment isn't available (running in CI), this step may need to be skipped; note it in the commit message if so.

- [ ] **Step 6: Commit**

```bash
git add main.lua src/states/menu.lua src/states/mode_select.lua src/states/config.lua src/states/player_setup.lua src/states/game.lua src/states/end_screen.lua
git commit -m "$(cat <<'EOF'
Refactor states to factory pattern, inject Session via deps (fix I2)

State modules now export new(deps) and return per-game instances closing
over deps.fsm and deps.session. main.lua creates the FSM and a fresh
Session, packages them as deps, instantiates each state via its factory,
and registers the instance with the FSM. No more module-level mutation.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Real mode-select screen

**Files:**
- Modify: `src/states/mode_select.lua` (replace placeholder with the real screen)

The screen lists every entry from `Session.MODES`. Available modes render as paper-card Buttons that, on click, call `session:set_mode(id)` then transition to `config`. Deferred modes render as flat plates with a "Coming soon" label, ignoring clicks. There's also a "Back" button bottom-left that returns to `menu`.

- [ ] **Step 1: Replace `src/states/mode_select.lua`**

```lua
local Button = require("src.ui.components.button")
local Session = require("src.game.session")
local typography = require("src.ui.typography")

local M = {}
M.__index = M

local CARD_W, CARD_H, CARD_GAP = 760, 84, 16

local function build_layout(self, w, h)
  self.buttons = {}
  self.deferred_cards = {}

  local total_h = #Session.MODES * (CARD_H + CARD_GAP) - CARD_GAP
  local x = (w - CARD_W) / 2
  local y0 = (h - total_h) / 2

  local fsm, session = self.fsm, self.session

  for i, mode in ipairs(Session.MODES) do
    local y = y0 + (i - 1) * (CARD_H + CARD_GAP)
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
    else
      table.insert(self.deferred_cards, {
        x = x, y = y, w = CARD_W, h = CARD_H,
        label = mode.label,
        blurb = mode.blurb,
      })
    end
  end

  -- Back button bottom-left
  self.back_button = Button.new({
    x = 32, y = h - 64, w = 120, h = 40,
    label = "Back",
    on_click = function() fsm:transition("menu") end,
  })
end

local function new(deps)
  return setmetatable({
    fsm = deps.fsm,
    session = deps.session,
  }, M)
end

function M:enter()
  build_layout(self, love.graphics.getWidth(), love.graphics.getHeight())
end

function M:resize(w, h)
  build_layout(self, w, h)
end

function M:draw()
  local w = love.graphics.getWidth()

  typography.with("xl", function()
    love.graphics.setColor(0.1, 0.1, 0.1)
    local font = love.graphics.getFont()
    local title = "Pick a Mode"
    local tw = font:getWidth(title)
    love.graphics.print(title, (w - tw) / 2, 48)
  end)

  -- Active mode buttons
  for _, b in ipairs(self.buttons) do b:draw() end

  -- Deferred mode cards (flat plates with Coming Soon)
  for _, c in ipairs(self.deferred_cards) do
    love.graphics.setColor(0.92, 0.90, 0.82)
    love.graphics.rectangle("fill", c.x, c.y, c.w, c.h)
    love.graphics.setColor(0.55, 0.55, 0.55)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", c.x, c.y, c.w, c.h)

    typography.with("lg", function()
      love.graphics.setColor(0.4, 0.4, 0.4)
      love.graphics.print(c.label, c.x + 24, c.y + 14)
    end)
    typography.with("sm", function()
      love.graphics.setColor(0.5, 0.5, 0.5)
      love.graphics.print(c.blurb, c.x + 24, c.y + 50)
    end)
    typography.with("xs", function()
      love.graphics.setColor(0.6, 0.5, 0.3)
      local font = love.graphics.getFont()
      local label = "COMING SOON"
      local tw = font:getWidth(label)
      love.graphics.print(label, c.x + c.w - tw - 24, c.y + 14)
    end)
  end

  self.back_button:draw()
end

function M:mousemoved(x, y)
  for _, b in ipairs(self.buttons) do b:mousemoved(x, y) end
  self.back_button:mousemoved(x, y)
end

function M:mousepressed(x, y, btn)
  for _, b in ipairs(self.buttons) do b:mousepressed(x, y, btn) end
  self.back_button:mousepressed(x, y, btn)
end

function M:mousereleased(x, y, btn)
  for _, b in ipairs(self.buttons) do b:mousereleased(x, y, btn) end
  self.back_button:mousereleased(x, y, btn)
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

- [ ] **Step 2: Boot Love and verify the mode-select screen renders**

Run: `timeout 5 love . 2>&1 | head -20`

Expected: no error output. (A human follow-up will click through Plan 2's smoke test in Task 7.)

- [ ] **Step 3: Run the full test suite**

Run: `busted`

Expected: 28 successes / 0 failures (8 FSM + 6 RNG + 9 Button + 5 Session).

- [ ] **Step 4: Commit**

```bash
git add src/states/mode_select.lua
git commit -m "$(cat <<'EOF'
Replace mode-select placeholder with real screen

Lists every entry from Session.MODES. Available modes (Sprint only in
v1) render as paper-card buttons that call session:set_mode(id) and
transition to config. Deferred modes (Floor, Ladder, Hybrid, Story)
render as flat plates labeled "Coming soon" and ignore clicks. A Back
button returns to the menu.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: End-to-end manual smoke test

**Files:** none

- [ ] **Step 1: Run the game and walk the navigation flow**

Run: `love .`

Walk through:

1. Main menu shows title + "New Game" + "Quit". Verify hover/press styling on both buttons.
2. Click "New Game" → mode-select screen appears with five rows: **The Sprint** as a clickable paper card; Floor / Ladder / Hybrid / Story Mode rendered as flat plates with their blurbs and a "COMING SOON" tag.
3. Click any deferred plate — nothing happens (no click handler attached).
4. Hover the Sprint card — fill should lighten.
5. Click **The Sprint** → advance to CONFIG placeholder.
6. Press SPACE through CONFIG → PLAYER_SETUP → GAME → END_SCREEN → back to MENU.
7. From mode-select, press Esc OR click Back — return to MENU.
8. Press Esc on the MENU — window closes.
9. Restart `love .`, resize the window, navigate to mode-select. Layout should re-center on resize.
10. Restart `love .`, click "New Game", then click Sprint, then immediately press Esc from the placeholder screens — you should still bounce back to MENU cleanly.

If any of these fail, debug before continuing.

- [ ] **Step 2: Run the full test suite one more time**

Run: `busted`

Expected: 28 successes / 0 failures (8 FSM + 6 RNG + 9 Button + 5 Session).

- [ ] **Step 3: No commit (verification only)**

---

### Task 8: Final review

**Files:** none

- [ ] **Step 1: Confirm working tree is clean**

Run: `git status`

Expected: no uncommitted changes (apart from the pre-existing `.claude/` untracked directory).

- [ ] **Step 2: Review the commit log for Plan 2**

Run: `git log --oneline main..HEAD`

Expected: 6 commits on this branch with descriptive messages, one per task (Tasks 1–6). Tasks 7–8 are verification only.

- [ ] **Step 3: Confirm final test counts**

Run: `busted`

Expected: 28 successes / 0 failures (8 FSM + 6 RNG + 9 Button + 5 Session).

- [ ] **Step 4: Confirm `love .` boots cleanly**

Run: `timeout 4 love . 2>&1 | head -5`

Expected: no error output; clean termination via the timeout (exit code 124 or 143).

---

## Done

When all 8 tasks are checked off, this plan is complete. The follow-on plan (Plan 3: pre-game config + player setup) will build on the Session module and reuse the factory pattern established here.
