# Project Skeleton & Main Menu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bootstrap a Love2D project with a working finite-state-machine, a real main menu, and navigable placeholder states for every screen the spec calls out (mode select, config, player setup, game, end screen). End state: `love .` launches the game, you can click "New Game" and step through every placeholder screen back to the menu.

**Architecture:** A small FSM (`src/util/fsm.lua`) holds the current state and dispatches all Love2D callbacks (`update`, `draw`, `keypressed`, `mousepressed`, `mousereleased`) to that state. Each state is a Lua module under `src/states/` exposing `enter`, `update`, `draw`, `leave`, and input handlers. Shared UI primitives (`Button`, typography) live under `src/ui/`. Pure logic (FSM, RNG) is unit-tested with `busted`; rendering is verified manually with `love .`.

**Tech Stack:** Lua 5.1+ (Love2D embed), Love2D 11.x+ runtime, `busted` for testing, `luarocks` for installing busted.

**Scope:** This is Plan 1 of 9 (see the spec's milestone list). Plans 2–9 build mode selection, pre-game configuration, the Kanban board, ticket flow, resources, sprint phases, sabotage, dilemmas, capstones, and polish on top of this foundation. Nothing in this plan touches game mechanics — it's purely scaffolding.

**Spec reference:** `docs/superpowers/specs/2026-04-21-spite-driven-development-design.md`, §12 (Love2D Architecture).

---

## File Map

Files created or modified by this plan:

```
.
├── conf.lua                            (new)
├── main.lua                            (new)
├── .busted                             (new — busted runner config)
├── README.md                           (new — how to run + test)
├── src/
│   ├── states/
│   │   ├── menu.lua                    (new)
│   │   ├── mode_select.lua             (new — placeholder)
│   │   ├── config.lua                  (new — placeholder)
│   │   ├── player_setup.lua            (new — placeholder)
│   │   ├── game.lua                    (new — placeholder)
│   │   └── end_screen.lua              (new — placeholder)
│   ├── ui/
│   │   ├── components/
│   │   │   └── button.lua              (new)
│   │   └── typography.lua              (new)
│   └── util/
│       ├── fsm.lua                     (new)
│       └── rng.lua                     (new)
└── tests/
    └── spec/
        ├── fsm_spec.lua                (new)
        ├── rng_spec.lua                (new)
        └── button_spec.lua             (new)
```

Each module has one responsibility. The state interface is documented at the top of `src/util/fsm.lua` so any state module can be skimmed without reading another file first.

---

## Conventions

- 2-space indent.
- `snake_case` for module functions and locals.
- Each module returns a table; functions are declared `local` and listed in the return table.
- Lua module files end with a final newline.
- Commit after each task. Commits are atomic (one task = one commit).
- Test files live under `tests/spec/` and end in `_spec.lua` — the busted default.

---

### Task 1: Verify Love2D installation

**Files:** none (sanity check only)

- [ ] **Step 1: Confirm `love` is on PATH**

  Run: `which love && love --version`

  Expected: a path to the binary and a version string like `LOVE 11.5 (Mysterious Mysteries)`. If `love` is not found, install it before continuing:

  - Linux (apt): `sudo apt install love`
  - macOS (homebrew): `brew install love`
  - Windows: download from `https://love2d.org/`

  Stop here and ask the user to install Love2D if missing. Do not proceed without a working `love` command.

---

### Task 2: Create `conf.lua`

**Files:**
- Create: `conf.lua`

- [ ] **Step 1: Write `conf.lua`**

```lua
function love.conf(t)
  t.identity = "spite-driven-development"
  t.version = "11.5"
  t.console = false

  t.window.title = "Spite Driven Development"
  t.window.width = 1280
  t.window.height = 800
  t.window.resizable = true
  t.window.minwidth = 960
  t.window.minheight = 600
  t.window.vsync = 1
  t.window.msaa = 0

  -- Disable modules we don't need yet to shave startup time.
  t.modules.joystick = false
  t.modules.physics = false
  t.modules.video = false
  t.modules.touch = false
end
```

- [ ] **Step 2: Commit**

```bash
git add conf.lua
git commit -m "Add Love2D window configuration"
```

---

### Task 3: Minimal `main.lua` that opens a window

**Files:**
- Create: `main.lua`

- [ ] **Step 1: Write a stub `main.lua`**

```lua
function love.load()
  love.graphics.setBackgroundColor(0.96, 0.94, 0.86) -- paper tone
end

function love.draw()
  love.graphics.setColor(0.1, 0.1, 0.1)
  love.graphics.print("Spite Driven Development", 40, 40)
end

function love.keypressed(key)
  if key == "escape" then
    love.event.quit()
  end
end
```

- [ ] **Step 2: Run the game and confirm the window opens**

```bash
love .
```

Expected: a 1280×800 window with paper-tone background and the text "Spite Driven Development" in the top-left. Press Esc to quit.

- [ ] **Step 3: Commit**

```bash
git add main.lua
git commit -m "Add Love2D entry stub that opens a window"
```

---

### Task 4: Install and configure busted for testing

**Files:**
- Create: `.busted`

- [ ] **Step 1: Install busted via luarocks**

```bash
sudo apt install -y luarocks
sudo luarocks install busted
```

If `luarocks` is unavailable, install per platform: macOS `brew install luarocks`, Windows via `chocolatey install lua` then `luarocks install busted`.

Verify:

```bash
busted --version
```

Expected: a version string like `2.2.0`.

- [ ] **Step 2: Create the `.busted` runner config**

```lua
return {
  default = {
    ROOT = { "tests/spec" },
    pattern = "_spec",
    verbose = true,
  },
}
```

- [ ] **Step 3: Run busted with no tests yet**

```bash
busted
```

Expected: `0 successes / 0 failures` (or similar — busted exits cleanly when there are no specs).

- [ ] **Step 4: Commit**

```bash
git add .busted
git commit -m "Configure busted test runner"
```

---

### Task 5: Write failing tests for the FSM utility

**Files:**
- Create: `tests/spec/fsm_spec.lua`

- [ ] **Step 1: Write the failing spec**

```lua
local FSM = require("src.util.fsm")

describe("FSM", function()
  it("starts in the registered initial state", function()
    local entered
    local fsm = FSM.new()
    fsm:register("menu", { enter = function() entered = "menu" end })
    fsm:start("menu")
    assert.is_equal("menu", entered)
  end)

  it("transitions between states, calling leave then enter", function()
    local trace = {}
    local fsm = FSM.new()
    fsm:register("a", {
      enter = function() table.insert(trace, "a:enter") end,
      leave = function() table.insert(trace, "a:leave") end,
    })
    fsm:register("b", {
      enter = function() table.insert(trace, "b:enter") end,
    })
    fsm:start("a")
    fsm:transition("b")
    assert.are.same({ "a:enter", "a:leave", "b:enter" }, trace)
  end)

  it("returns the current state name", function()
    local fsm = FSM.new()
    fsm:register("menu", {})
    fsm:register("game", {})
    fsm:start("menu")
    assert.is_equal("menu", fsm:current())
    fsm:transition("game")
    assert.is_equal("game", fsm:current())
  end)

  it("dispatches arbitrary callbacks to the current state with arguments", function()
    local received
    local fsm = FSM.new()
    fsm:register("a", {
      keypressed = function(_, key) received = key end,
    })
    fsm:start("a")
    fsm:dispatch("keypressed", "space")
    assert.is_equal("space", received)
  end)

  it("ignores callbacks the state does not implement", function()
    local fsm = FSM.new()
    fsm:register("a", {})
    fsm:start("a")
    assert.has_no.errors(function() fsm:dispatch("keypressed", "x") end)
  end)

  it("raises when starting an unregistered state", function()
    local fsm = FSM.new()
    assert.has_error(function() fsm:start("missing") end)
  end)

  it("raises when transitioning to an unregistered state", function()
    local fsm = FSM.new()
    fsm:register("a", {})
    fsm:start("a")
    assert.has_error(function() fsm:transition("missing") end)
  end)
end)
```

- [ ] **Step 2: Run and confirm the spec fails because `src.util.fsm` does not exist**

```bash
busted tests/spec/fsm_spec.lua
```

Expected: failure with a message like `module 'src.util.fsm' not found`.

- [ ] **Step 3: Commit the failing test**

```bash
git add tests/spec/fsm_spec.lua
git commit -m "Add failing FSM tests"
```

---

### Task 6: Implement the FSM utility

**Files:**
- Create: `src/util/fsm.lua`

- [ ] **Step 1: Implement `src/util/fsm.lua`**

```lua
-- Finite state machine for screen-level states (menu, config, game, etc.).
--
-- State contract:
--   A state is a table that may implement any of these methods. Methods are
--   called with the state as `self` and Love2D-style positional arguments:
--     enter()                    -- called when entering the state
--     leave()                    -- called when leaving the state
--     update(dt)                 -- per-frame update
--     draw()                     -- per-frame render
--     keypressed(key, scancode, isrepeat)
--     keyreleased(key, scancode)
--     mousepressed(x, y, button, istouch, presses)
--     mousereleased(x, y, button, istouch, presses)
--     mousemoved(x, y, dx, dy, istouch)
--     wheelmoved(dx, dy)
--     textinput(text)
--     resize(w, h)
--
-- Any method not implemented on a state is silently skipped when dispatched.

local FSM = {}
FSM.__index = FSM

local function new()
  return setmetatable({
    states = {},
    current_name = nil,
  }, FSM)
end

function FSM:register(name, state)
  assert(type(name) == "string" and #name > 0, "state name must be a non-empty string")
  assert(type(state) == "table", "state must be a table")
  self.states[name] = state
end

function FSM:start(name)
  local state = self.states[name]
  assert(state, "no such state: " .. tostring(name))
  self.current_name = name
  if state.enter then state:enter() end
end

function FSM:transition(name)
  local next_state = self.states[name]
  assert(next_state, "no such state: " .. tostring(name))
  local prev = self.states[self.current_name]
  if prev and prev.leave then prev:leave() end
  self.current_name = name
  if next_state.enter then next_state:enter() end
end

function FSM:current()
  return self.current_name
end

function FSM:dispatch(method, ...)
  local state = self.states[self.current_name]
  if state and state[method] then
    state[method](state, ...)
  end
end

return {
  new = new,
}
```

- [ ] **Step 2: Run the spec and confirm it passes**

```bash
busted tests/spec/fsm_spec.lua
```

Expected: `7 successes / 0 failures`.

- [ ] **Step 3: Commit**

```bash
git add src/util/fsm.lua
git commit -m "Implement FSM utility"
```

---

### Task 7: Write failing tests for the seedable RNG utility

**Files:**
- Create: `tests/spec/rng_spec.lua`

- [ ] **Step 1: Write the failing spec**

```lua
local RNG = require("src.util.rng")

describe("RNG", function()
  it("produces the same sequence from the same seed", function()
    local a = RNG.new(42)
    local b = RNG.new(42)
    for _ = 1, 100 do
      assert.is_equal(a:random(), b:random())
    end
  end)

  it("produces different sequences from different seeds", function()
    local a = RNG.new(1)
    local b = RNG.new(2)
    local same = true
    for _ = 1, 100 do
      if a:random() ~= b:random() then same = false; break end
    end
    assert.is_false(same)
  end)

  it("returns integers within an inclusive range via random(min, max)", function()
    local rng = RNG.new(7)
    for _ = 1, 1000 do
      local n = rng:random(1, 6)
      assert.is_true(n >= 1 and n <= 6)
      assert.is_equal(math.floor(n), n)
    end
  end)

  it("shuffles a list deterministically given a seed", function()
    local function copy(t) local r = {}; for i, v in ipairs(t) do r[i] = v end; return r end
    local input = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
    local rng_a = RNG.new(123)
    local rng_b = RNG.new(123)
    local a = rng_a:shuffle(copy(input))
    local b = rng_b:shuffle(copy(input))
    assert.are.same(a, b)
  end)

  it("shuffle preserves elements", function()
    local rng = RNG.new(99)
    local input = { "x", "y", "z", "w" }
    local out = rng:shuffle({ "x", "y", "z", "w" })
    table.sort(input)
    table.sort(out)
    assert.are.same(input, out)
  end)
end)
```

- [ ] **Step 2: Run the spec and confirm it fails**

```bash
busted tests/spec/rng_spec.lua
```

Expected: failure with `module 'src.util.rng' not found`.

- [ ] **Step 3: Commit**

```bash
git add tests/spec/rng_spec.lua
git commit -m "Add failing RNG tests"
```

---

### Task 8: Implement the seedable RNG utility

**Files:**
- Create: `src/util/rng.lua`

- [ ] **Step 1: Implement `src/util/rng.lua`**

Use Love2D's `love.math.newRandomGenerator(seed)` when Love is loaded (in-game), and fall back to Lua's `math` API when running under busted (no Love runtime).

```lua
-- Seedable RNG. Uses Love2D's RandomGenerator at runtime (good distribution,
-- per-instance state) and falls back to a small Lua-only generator under
-- busted so tests can run without a Love runtime.

local RNG = {}
RNG.__index = RNG

local has_love = type(love) == "table" and love.math and love.math.newRandomGenerator

local function lua_generator(seed)
  -- Linear congruential generator. Good enough for shuffles, not for crypto.
  -- Constants from Numerical Recipes.
  local state = seed % 2147483647
  if state == 0 then state = 1 end
  return {
    random = function()
      state = (state * 1103515245 + 12345) % 2147483648
      return state / 2147483648
    end,
  }
end

local function new(seed)
  seed = seed or os.time()
  local backend
  if has_love then
    backend = love.math.newRandomGenerator(seed)
  else
    backend = lua_generator(seed)
  end
  return setmetatable({ _backend = backend }, RNG)
end

-- random()             -> float in [0, 1)
-- random(max)          -> integer in [1, max]
-- random(min, max)     -> integer in [min, max]
function RNG:random(a, b)
  local r = self._backend:random()
  if a == nil then return r end
  if b == nil then
    return math.floor(r * a) + 1
  end
  return math.floor(r * (b - a + 1)) + a
end

function RNG:shuffle(list)
  -- Fisher-Yates, in place, returns the same list for chaining.
  for i = #list, 2, -1 do
    local j = self:random(1, i)
    list[i], list[j] = list[j], list[i]
  end
  return list
end

return {
  new = new,
}
```

- [ ] **Step 2: Run the spec and confirm it passes**

```bash
busted tests/spec/rng_spec.lua
```

Expected: `5 successes / 0 failures`.

- [ ] **Step 3: Commit**

```bash
git add src/util/rng.lua
git commit -m "Implement seedable RNG utility"
```

---

### Task 9: Implement the typography module

**Files:**
- Create: `src/ui/typography.lua`

The typography module exposes named font sizes so screens don't sprinkle magic numbers. It must be loaded inside `love.load` (Love2D forbids creating fonts before then). We delay font construction with a lazy initializer.

- [ ] **Step 1: Write `src/ui/typography.lua`**

```lua
-- Named font sizes. Call typography.init() inside love.load() before drawing.
-- After init, typography.font(name) returns a love.graphics.Font.

local SIZES = {
  xs = 12,
  sm = 14,
  md = 18,
  lg = 24,
  xl = 36,
  display = 56,
}

local fonts = nil

local function init()
  fonts = {}
  for name, size in pairs(SIZES) do
    fonts[name] = love.graphics.newFont(size)
  end
end

local function font(name)
  assert(fonts, "typography.init() must be called inside love.load() before use")
  local f = fonts[name]
  assert(f, "unknown font size: " .. tostring(name))
  return f
end

-- Convenience: temporarily set the active font, run draw_fn, then restore.
local function with(name, draw_fn)
  local prev = love.graphics.getFont()
  love.graphics.setFont(font(name))
  draw_fn()
  love.graphics.setFont(prev)
end

return {
  init = init,
  font = font,
  with = with,
  SIZES = SIZES,
}
```

- [ ] **Step 2: Commit**

```bash
git add src/ui/typography.lua
git commit -m "Add typography module with named font sizes"
```

---

### Task 10: Write failing test for the Button hit-detect

**Files:**
- Create: `tests/spec/button_spec.lua`

Buttons hold their geometry and a click handler. Hit detection is pure math (point-in-rect) so we can unit-test it without a Love runtime. We expose a `hit(x, y)` method that the spec exercises directly; rendering and Love-side click registration live in the module but are verified manually in Task 16.

- [ ] **Step 1: Write the failing spec**

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
    assert.is_false(b:hit(110, 60))         -- one past bottom-right
  end)

  it("invokes the click handler when clicked inside", function()
    local clicked = false
    local b = Button.new({
      x = 0, y = 0, w = 50, h = 50,
      label = "ok",
      on_click = function() clicked = true end,
    })
    b:click(10, 10)
    assert.is_true(clicked)
  end)

  it("does not invoke the handler when clicked outside", function()
    local clicked = false
    local b = Button.new({
      x = 0, y = 0, w = 50, h = 50,
      label = "ok",
      on_click = function() clicked = true end,
    })
    b:click(99, 99)
    assert.is_false(clicked)
  end)

  it("defaults label to an empty string and on_click to a no-op", function()
    local b = Button.new({ x = 0, y = 0, w = 10, h = 10 })
    assert.is_equal("", b.label)
    assert.has_no.errors(function() b:click(5, 5) end)
  end)
end)
```

- [ ] **Step 2: Run the spec and confirm it fails**

```bash
busted tests/spec/button_spec.lua
```

Expected: failure with `module 'src.ui.components.button' not found`.

- [ ] **Step 3: Commit**

```bash
git add tests/spec/button_spec.lua
git commit -m "Add failing Button hit-detect tests"
```

---

### Task 11: Implement the Button component

**Files:**
- Create: `src/ui/components/button.lua`

- [ ] **Step 1: Implement `src/ui/components/button.lua`**

```lua
-- Rectangular button with paper-card styling. Hit detection and click handling
-- are pure logic (testable with busted). Rendering uses love.graphics and is
-- verified manually.

local typography_ok, typography = pcall(require, "src.ui.typography")

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

function Button:click(px, py)
  if self:hit(px, py) then
    self.on_click()
  end
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
  if btn == 1 then
    if self.pressed and self:hit(x, y) then
      self.on_click()
    end
    self.pressed = false
  end
end

function Button:draw()
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
  if typography_ok then
    typography.with("md", function()
      love.graphics.setColor(0.1, 0.1, 0.1)
      local font = love.graphics.getFont()
      local tw = font:getWidth(self.label)
      local th = font:getHeight()
      love.graphics.print(self.label,
        self.x + (self.w - tw) / 2,
        self.y + (self.h - th) / 2)
    end)
  end
end

return {
  new = new,
}
```

- [ ] **Step 2: Run the spec and confirm it passes**

```bash
busted tests/spec/button_spec.lua
```

Expected: `5 successes / 0 failures`.

- [ ] **Step 3: Run all specs to make sure nothing regressed**

```bash
busted
```

Expected: 17 successes / 0 failures (7 FSM + 5 RNG + 5 Button).

- [ ] **Step 4: Commit**

```bash
git add src/ui/components/button.lua
git commit -m "Implement Button UI component"
```

---

### Task 12: Create the placeholder state for the main menu

**Files:**
- Create: `src/states/menu.lua`

The menu state in this task is intentionally minimal — just enough to verify the FSM dispatcher works. Task 16 replaces this with the real menu after the other placeholders exist.

- [ ] **Step 1: Write `src/states/menu.lua` (placeholder version)**

```lua
-- Main menu state. Placeholder for Task 12; replaced with the real menu in Task 16.

local M = {}

function M:enter()
  self.message = "MENU — press SPACE to advance to mode_select"
end

function M:draw()
  love.graphics.setColor(0.1, 0.1, 0.1)
  love.graphics.print(self.message, 40, 40)
end

function M:keypressed(key)
  if key == "space" then
    self.fsm:transition("mode_select")
  elseif key == "escape" then
    love.event.quit()
  end
end

return M
```

The state expects `self.fsm` to be assigned by `main.lua` after construction. We'll wire that up in Task 14.

- [ ] **Step 2: Commit**

```bash
git add src/states/menu.lua
git commit -m "Add placeholder menu state"
```

---

### Task 13: Create placeholder states for every other screen

**Files:**
- Create: `src/states/mode_select.lua`
- Create: `src/states/config.lua`
- Create: `src/states/player_setup.lua`
- Create: `src/states/game.lua`
- Create: `src/states/end_screen.lua`

Each placeholder has the same shape: shows its name, advances to the next screen on SPACE. The chain is:

`menu → mode_select → config → player_setup → game → end_screen → menu`

- [ ] **Step 1: Write `src/states/mode_select.lua`**

```lua
local M = {}

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

return M
```

- [ ] **Step 2: Write `src/states/config.lua`**

```lua
local M = {}

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

return M
```

- [ ] **Step 3: Write `src/states/player_setup.lua`**

```lua
local M = {}

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

return M
```

- [ ] **Step 4: Write `src/states/game.lua`**

```lua
local M = {}

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

return M
```

- [ ] **Step 5: Write `src/states/end_screen.lua`**

```lua
local M = {}

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

return M
```

- [ ] **Step 6: Commit**

```bash
git add src/states/mode_select.lua src/states/config.lua src/states/player_setup.lua src/states/game.lua src/states/end_screen.lua
git commit -m "Add placeholder states for the full screen chain"
```

---

### Task 14: Wire the FSM into `main.lua`

**Files:**
- Modify: `main.lua` (replace its contents)

- [ ] **Step 1: Replace `main.lua` with the FSM-driven entry**

```lua
local FSM = require("src.util.fsm")
local typography = require("src.ui.typography")

local fsm

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
  for _, name in ipairs(STATES) do
    local mod = require("src.states." .. name)
    mod.fsm = fsm
    fsm:register(name, mod)
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

- [ ] **Step 2: Run the game and step through every placeholder**

```bash
love .
```

Expected sequence (press SPACE between each):
- Window shows "MENU — press SPACE to advance to mode_select"
- → "MODE_SELECT — press SPACE to advance to config"
- → "CONFIG — press SPACE to advance to player_setup"
- → "PLAYER_SETUP — press SPACE to advance to game"
- → "GAME — press SPACE to advance to end_screen"
- → "END_SCREEN — press SPACE to return to menu"
- → back to MENU

Press Esc from any placeholder (except menu) and you should bounce back to MENU. Esc from MENU should quit.

- [ ] **Step 3: Commit**

```bash
git add main.lua
git commit -m "Wire FSM into Love2D entry"
```

---

### Task 15: Build the real main menu

**Files:**
- Modify: `src/states/menu.lua` (full replacement)

The real menu has a centered title and two buttons stacked vertically: "New Game" → mode_select, "Quit" → quits the app. It uses the typography and Button modules.

- [ ] **Step 1: Replace `src/states/menu.lua`**

```lua
local Button = require("src.ui.components.button")
local typography = require("src.ui.typography")

local M = {}

local function build_buttons(self, w, h)
  local btn_w, btn_h = 320, 56
  local cx = (w - btn_w) / 2
  local cy = h / 2 + 20

  self.buttons = {
    Button.new({
      x = cx, y = cy, w = btn_w, h = btn_h,
      label = "New Game",
      on_click = function() self.fsm:transition("mode_select") end,
    }),
    Button.new({
      x = cx, y = cy + btn_h + 16, w = btn_w, h = btn_h,
      label = "Quit",
      on_click = function() love.event.quit() end,
    }),
  }
end

function M:enter()
  build_buttons(self, love.graphics.getWidth(), love.graphics.getHeight())
end

function M:resize(w, h)
  build_buttons(self, w, h)
end

function M:draw()
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()

  -- Title
  typography.with("display", function()
    love.graphics.setColor(0.1, 0.1, 0.1)
    local font = love.graphics.getFont()
    local title = "Spite Driven Development"
    local tw = font:getWidth(title)
    love.graphics.print(title, (w - tw) / 2, h / 4)
  end)

  -- Subtitle
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

return M
```

- [ ] **Step 2: Run the game and verify the menu**

```bash
love .
```

Expected:
- Title "Spite Driven Development" centered, large.
- Subtitle "a parody boardgame" beneath it.
- Two buttons centered lower: "New Game" and "Quit".
- Hovering a button lightens its fill; pressing darkens it.
- Clicking "New Game" → MODE_SELECT screen.
- Clicking "Quit" → window closes.
- Pressing Return from the menu → MODE_SELECT.
- Resizing the window keeps everything centered.

- [ ] **Step 3: Run all specs to confirm no regression**

```bash
busted
```

Expected: 17 successes / 0 failures.

- [ ] **Step 4: Commit**

```bash
git add src/states/menu.lua
git commit -m "Build real main menu with title and buttons"
```

---

### Task 16: End-to-end manual smoke test

**Files:** none

- [ ] **Step 1: Smoke-test the full navigation flow**

Run: `love .`

Walk through every transition:

1. Main menu shows title + "New Game" + "Quit".
2. Click "New Game" → MODE_SELECT.
3. Press SPACE → CONFIG.
4. Press SPACE → PLAYER_SETUP.
5. Press SPACE → GAME.
6. Press SPACE → END_SCREEN.
7. Press SPACE → back to main menu.
8. From any non-menu placeholder, press Esc → returns to main menu.
9. From the main menu, press Esc OR click "Quit" → window closes.
10. Restart the game, resize the window. The title and buttons should re-center.

If any of these fail, stop and debug before moving on.

- [ ] **Step 2: No commit (verification only)**

---

### Task 17: Write the README

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write the README**

````markdown
# Spite Driven Development

A parody boardgame about modern tech work. Local hotseat for 2–8 players. Hand-drawn stick-figure art. Built in Lua with Love2D.

## Status

Pre-alpha. Currently only the project skeleton and main menu navigation are implemented. See `docs/superpowers/specs/2026-04-21-spite-driven-development-design.md` for the full design.

## Run

Requires Love2D 11.x. From the project root:

```
love .
```

Press SPACE to walk through the placeholder screens. Esc returns to the menu (or quits from the menu).

## Test

Requires busted (`luarocks install busted`):

```
busted
```

Runs all unit tests under `tests/spec/`.

## Layout

- `main.lua` / `conf.lua` — Love2D entry and window config
- `src/states/` — one Lua module per screen
- `src/ui/` — shared UI primitives (typography, button)
- `src/util/` — pure-logic utilities (fsm, rng)
- `tests/spec/` — busted unit tests
- `docs/superpowers/` — design specs and implementation plans

## Credits

- abu — primary author
- nilpointerr — co-designer (Dilemma cards, LinkedIn Score concept)
- hotdogflavoredwater — collaborator
````

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "Add README with run + test instructions"
```

---

### Task 18: Final review

**Files:** none

- [ ] **Step 1: Confirm directory layout matches the file map**

Run: `find . -type f -not -path './.git/*' -not -path './.superpowers/*' -not -path './assets/*' -not -path './docs/*' | sort`

Expected (paths only, no extra files):

```
./.busted
./.gitignore
./LICENSE
./README.md
./conf.lua
./main.lua
./src/states/config.lua
./src/states/end_screen.lua
./src/states/game.lua
./src/states/menu.lua
./src/states/mode_select.lua
./src/states/player_setup.lua
./src/ui/components/button.lua
./src/ui/typography.lua
./src/util/fsm.lua
./src/util/rng.lua
./tests/spec/button_spec.lua
./tests/spec/fsm_spec.lua
./tests/spec/rng_spec.lua
```

If anything is missing or unexpected, address it before declaring the plan complete.

- [ ] **Step 2: Run all tests one more time**

Run: `busted`

Expected: `17 successes / 0 failures`.

- [ ] **Step 3: Verify `love .` still works end-to-end**

Run: `love .` — confirm menu loads, navigation works, Esc quits from the menu.

- [ ] **Step 4: Confirm clean commit history**

Run: `git log --oneline`

Expected: a steady sequence of small commits — one per task — with descriptive messages. No "WIP" or "fix" cleanup commits.

---

## Done

When all 18 tasks are checked off, this plan is complete. Plan 2 (mode select + pre-game config + player setup) builds on this foundation.
