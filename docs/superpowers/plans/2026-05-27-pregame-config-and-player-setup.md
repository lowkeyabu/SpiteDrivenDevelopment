# Pre-Game Config + Player Setup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the `config` and `player_setup` placeholders with real, interactive screens. The host configures the company name, player count, action points, end trigger, comp target, sprint turn cap, and tier-gating on the config screen; then each player sets a name and stick-figure color on the player setup screen. Pre-game state lands cleanly in the `Session` so Plan 4 can read it from gameplay.

**Architecture:** Five new reusable widgets (`Stepper`, `Toggle`, `RadioGroup`, `TextInput`, `ColorPicker`) live under `src/ui/components/`. Each widget exposes the same shape as `Button`: a pure-logic API (`new`, `hit`, `set_value`, `get_value`, mouse / key callbacks) testable under busted, plus a `:draw` method that short-circuits when Love isn't present. Screens orchestrate the widgets and wire each `on_change` callback into `session.config` (or `session.players` for player setup). `Session` grows player-record helpers (`add_player`, `set_player_count`, `set_player_name`, `set_player_color`) and a `PLAYER_PALETTE` constant of eight distinguishable colors.

**Tech Stack:** Lua 5.1+ (Love2D embed), Love2D 11.x runtime, busted for tests.

**Scope:** Plan 3 of 9. Builds on Plan 2's `Session`, factory-pattern states, and cleaned-up Button. After this plan: a host can walk menu → mode_select → config → player_setup → game (placeholder) with every setting saved to the Session. Plan 4 starts using those settings to drive gameplay.

**Spec reference:** `docs/superpowers/specs/2026-04-21-spite-driven-development-design.md`, §3 (Players & Setup), §5 (Pre-Game Configuration).

---

## File Map

Files created or modified by this plan:

```
.
├── src/
│   ├── game/
│   │   └── session.lua                       (modified — player helpers + palette + end_trigger taxonomy)
│   ├── states/
│   │   ├── config.lua                        (replaced — real screen)
│   │   └── player_setup.lua                  (replaced — real screen)
│   └── ui/
│       └── components/
│           ├── stepper.lua                   (new)
│           ├── toggle.lua                    (new)
│           ├── radio_group.lua               (new)
│           ├── text_input.lua                (new)
│           └── color_picker.lua              (new)
└── tests/
    └── spec/
        ├── session_spec.lua                  (extended — player helpers, end_trigger validation)
        ├── stepper_spec.lua                  (new)
        ├── toggle_spec.lua                   (new)
        ├── radio_group_spec.lua              (new)
        ├── text_input_spec.lua               (new)
        └── color_picker_spec.lua             (new)
```

The two real screens depend on every widget, so widgets land first.

---

## Conventions

- 2-space indent.
- `snake_case` for module functions and locals.
- Each module returns a table; functions are declared `local` and listed in the return table.
- Widgets follow the established Button pattern: `M = {}; M.__index = M; local function new(opts) return setmetatable({...}, M) end; ...; return { new = new }`.
- Widgets short-circuit `:draw` when `not (love and love.graphics)` so they can be loaded by busted.
- Lua files end with a final newline.
- Commit after each task. Commits are atomic (one task = one commit).

---

### Task 1: Stepper widget — integer value with `+`/`-` buttons

**Files:**
- Create: `tests/spec/stepper_spec.lua`
- Create: `src/ui/components/stepper.lua`

The Stepper holds an integer in `[min, max]`. Clicking the `-` plate decrements (clamped at `min`); clicking `+` increments (clamped at `max`). The label and current value render in the middle.

- [ ] **Step 1: Write the failing spec**

`tests/spec/stepper_spec.lua`:

```lua
local Stepper = require("src.ui.components.stepper")

describe("Stepper", function()
  it("starts at the provided value and reports it via get_value", function()
    local s = Stepper.new({ x = 0, y = 0, w = 240, h = 40, value = 3, min = 1, max = 5 })
    assert.is_equal(3, s:get_value())
  end)

  it("set_value clamps to [min, max]", function()
    local s = Stepper.new({ x = 0, y = 0, w = 240, h = 40, value = 3, min = 1, max = 5 })
    s:set_value(10)
    assert.is_equal(5, s:get_value())
    s:set_value(-3)
    assert.is_equal(1, s:get_value())
    s:set_value(4)
    assert.is_equal(4, s:get_value())
  end)

  it("press-then-release inside the plus plate increments and fires on_change", function()
    local last
    local s = Stepper.new({
      x = 0, y = 0, w = 240, h = 40, value = 3, min = 1, max = 5,
      on_change = function(v) last = v end,
    })
    -- Plus plate is the right 40px of the widget (x = 200..239).
    s:mousepressed(220, 20, 1)
    s:mousereleased(220, 20, 1)
    assert.is_equal(4, s:get_value())
    assert.is_equal(4, last)
  end)

  it("press-then-release inside the minus plate decrements and fires on_change", function()
    local last
    local s = Stepper.new({
      x = 0, y = 0, w = 240, h = 40, value = 3, min = 1, max = 5,
      on_change = function(v) last = v end,
    })
    -- Minus plate is the left 40px (x = 0..39).
    s:mousepressed(10, 20, 1)
    s:mousereleased(10, 20, 1)
    assert.is_equal(2, s:get_value())
    assert.is_equal(2, last)
  end)

  it("does not go below min on -", function()
    local s = Stepper.new({ x = 0, y = 0, w = 240, h = 40, value = 1, min = 1, max = 5 })
    s:mousepressed(10, 20, 1)
    s:mousereleased(10, 20, 1)
    assert.is_equal(1, s:get_value())
  end)

  it("does not go above max on +", function()
    local s = Stepper.new({ x = 0, y = 0, w = 240, h = 40, value = 5, min = 1, max = 5 })
    s:mousepressed(220, 20, 1)
    s:mousereleased(220, 20, 1)
    assert.is_equal(5, s:get_value())
  end)

  it("press inside plus then release outside does not increment", function()
    local s = Stepper.new({ x = 0, y = 0, w = 240, h = 40, value = 3, min = 1, max = 5 })
    s:mousepressed(220, 20, 1)
    s:mousereleased(120, 20, 1) -- centre region, not a plate
    assert.is_equal(3, s:get_value())
  end)

  it("non-primary mouse buttons do not change the value", function()
    local s = Stepper.new({ x = 0, y = 0, w = 240, h = 40, value = 3, min = 1, max = 5 })
    s:mousepressed(220, 20, 2)
    s:mousereleased(220, 20, 2)
    assert.is_equal(3, s:get_value())
  end)

  it("defaults: min=0, max=10, step=1, value=0, on_change=no-op", function()
    local s = Stepper.new({ x = 0, y = 0, w = 240, h = 40 })
    assert.is_equal(0, s:get_value())
    assert.has_no.errors(function()
      s:mousepressed(220, 20, 1)
      s:mousereleased(220, 20, 1)
    end)
    assert.is_equal(1, s:get_value())
  end)
end)
```

- [ ] **Step 2: Run the spec and confirm it fails (module missing)**

Run: `busted tests/spec/stepper_spec.lua -v`

Expected: `module 'src.ui.components.stepper' not found`.

- [ ] **Step 3: Implement `src/ui/components/stepper.lua`**

```lua
-- Integer Stepper: minus plate on the left, value display in the middle,
-- plus plate on the right. Each plate is the full height of the widget
-- and 40px wide.

local Stepper = {}
Stepper.__index = Stepper

local PLATE_W = 40

local function noop() end

local function clamp(v, lo, hi)
  if v < lo then return lo end
  if v > hi then return hi end
  return v
end

local function new(opts)
  local min = opts.min or 0
  local max = opts.max or 10
  return setmetatable({
    x = opts.x or 0,
    y = opts.y or 0,
    w = opts.w or 240,
    h = opts.h or 40,
    min = min,
    max = max,
    value = clamp(opts.value or 0, min, max),
    label = opts.label or "",
    on_change = opts.on_change or noop,
    _press_zone = nil, -- "minus", "plus", or nil
  }, Stepper)
end

function Stepper:get_value()
  return self.value
end

function Stepper:set_value(v)
  local clamped = clamp(v, self.min, self.max)
  if clamped ~= self.value then
    self.value = clamped
    self.on_change(self.value)
  else
    self.value = clamped
  end
end

local function in_rect(px, py, x, y, w, h)
  return px >= x and py >= y and px < x + w and py < y + h
end

function Stepper:_zone_at(px, py)
  if not in_rect(px, py, self.x, self.y, self.w, self.h) then return nil end
  if px < self.x + PLATE_W then return "minus" end
  if px >= self.x + self.w - PLATE_W then return "plus" end
  return nil
end

function Stepper:mousepressed(x, y, btn)
  if btn ~= 1 then return end
  self._press_zone = self:_zone_at(x, y)
end

function Stepper:mousereleased(x, y, btn)
  if btn ~= 1 then return end
  local release_zone = self:_zone_at(x, y)
  if self._press_zone and self._press_zone == release_zone then
    if release_zone == "minus" then
      self:set_value(self.value - 1)
    else
      self:set_value(self.value + 1)
    end
  end
  self._press_zone = nil
end

function Stepper:mousemoved(x, y) end -- no hover state for v1

function Stepper:draw()
  if not (love and love.graphics) then return end
  local typography = require("src.ui.typography")

  -- Outer box
  love.graphics.setColor(1, 1, 1)
  love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
  love.graphics.setColor(0.1, 0.1, 0.1)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", self.x, self.y, self.w, self.h)

  -- Plate separators
  love.graphics.line(self.x + PLATE_W, self.y,
                     self.x + PLATE_W, self.y + self.h)
  love.graphics.line(self.x + self.w - PLATE_W, self.y,
                     self.x + self.w - PLATE_W, self.y + self.h)

  -- Plate glyphs
  typography.with("lg", function()
    love.graphics.setColor(0.1, 0.1, 0.1)
    local font = love.graphics.getFont()
    local minus, plus = "-", "+"
    local mw = font:getWidth(minus)
    local pw = font:getWidth(plus)
    local fh = font:getHeight()
    love.graphics.print(minus,
      self.x + (PLATE_W - mw) / 2,
      self.y + (self.h - fh) / 2)
    love.graphics.print(plus,
      self.x + self.w - PLATE_W + (PLATE_W - pw) / 2,
      self.y + (self.h - fh) / 2)
  end)

  -- Center value + label
  typography.with("md", function()
    love.graphics.setColor(0.2, 0.2, 0.2)
    local font = love.graphics.getFont()
    local v = tostring(self.value)
    local vw = font:getWidth(v)
    local fh = font:getHeight()
    love.graphics.print(v,
      self.x + (self.w - vw) / 2,
      self.y + (self.h - fh) / 2)
  end)
end

return {
  new = new,
}
```

- [ ] **Step 4: Run the spec to confirm pass**

Run: `busted tests/spec/stepper_spec.lua -v`

Expected: 9 successes / 0 failures.

- [ ] **Step 5: Full suite**

Run: `busted`

Expected: 38 successes / 0 failures (29 from Plan 2 + 9 Stepper).

- [ ] **Step 6: Commit**

```bash
git add src/ui/components/stepper.lua tests/spec/stepper_spec.lua
git commit -m "$(cat <<'EOF'
Add Stepper widget for integer settings (clamped, with on_change)

Stepper has minus/plus plates on either side, the value displayed in
the middle, and clamped [min, max] math. on_change fires only when the
value actually changed. Used by the config screen for player count,
AP per turn, comp target, and per-sprint turn cap.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: Toggle widget — boolean on/off

**Files:**
- Create: `tests/spec/toggle_spec.lua`
- Create: `src/ui/components/toggle.lua`

The Toggle holds a boolean. Click inside the widget to flip; `on_change` fires with the new value.

- [ ] **Step 1: Write the failing spec**

`tests/spec/toggle_spec.lua`:

```lua
local Toggle = require("src.ui.components.toggle")

describe("Toggle", function()
  it("starts at the provided value", function()
    local t = Toggle.new({ x = 0, y = 0, w = 240, h = 40, value = true })
    assert.is_true(t:get_value())
    local f = Toggle.new({ x = 0, y = 0, w = 240, h = 40, value = false })
    assert.is_false(f:get_value())
  end)

  it("defaults value to false", function()
    local t = Toggle.new({ x = 0, y = 0, w = 240, h = 40 })
    assert.is_false(t:get_value())
  end)

  it("press-then-release inside flips the value and fires on_change", function()
    local last
    local t = Toggle.new({
      x = 0, y = 0, w = 240, h = 40, value = false,
      on_change = function(v) last = v end,
    })
    t:mousepressed(120, 20, 1)
    t:mousereleased(120, 20, 1)
    assert.is_true(t:get_value())
    assert.is_true(last)
    t:mousepressed(120, 20, 1)
    t:mousereleased(120, 20, 1)
    assert.is_false(t:get_value())
    assert.is_false(last)
  end)

  it("press inside then release outside does not flip", function()
    local t = Toggle.new({ x = 0, y = 0, w = 240, h = 40, value = false })
    t:mousepressed(120, 20, 1)
    t:mousereleased(500, 500, 1)
    assert.is_false(t:get_value())
  end)

  it("non-primary mouse button does not flip", function()
    local t = Toggle.new({ x = 0, y = 0, w = 240, h = 40, value = false })
    t:mousepressed(120, 20, 2)
    t:mousereleased(120, 20, 2)
    assert.is_false(t:get_value())
  end)

  it("set_value updates without firing on_change when unchanged", function()
    local fired = false
    local t = Toggle.new({
      x = 0, y = 0, w = 240, h = 40, value = false,
      on_change = function() fired = true end,
    })
    t:set_value(false)
    assert.is_false(fired)
    t:set_value(true)
    assert.is_true(fired)
  end)
end)
```

- [ ] **Step 2: Run the spec to confirm it fails**

Run: `busted tests/spec/toggle_spec.lua -v`

Expected: `module 'src.ui.components.toggle' not found`.

- [ ] **Step 3: Implement `src/ui/components/toggle.lua`**

```lua
-- Boolean Toggle: click anywhere inside the widget to flip the value.
-- Label on the left, ON/OFF indicator on the right.

local Toggle = {}
Toggle.__index = Toggle

local function noop() end

local function new(opts)
  return setmetatable({
    x = opts.x or 0,
    y = opts.y or 0,
    w = opts.w or 240,
    h = opts.h or 40,
    value = opts.value or false,
    label = opts.label or "",
    on_change = opts.on_change or noop,
    _pressed = false,
  }, Toggle)
end

function Toggle:get_value()
  return self.value
end

function Toggle:set_value(v)
  v = v and true or false
  if v ~= self.value then
    self.value = v
    self.on_change(self.value)
  end
end

function Toggle:hit(px, py)
  return px >= self.x and py >= self.y
     and px < self.x + self.w and py < self.y + self.h
end

function Toggle:mousepressed(x, y, btn)
  if btn ~= 1 then return end
  if self:hit(x, y) then self._pressed = true end
end

function Toggle:mousereleased(x, y, btn)
  if btn ~= 1 then return end
  if self._pressed and self:hit(x, y) then
    self:set_value(not self.value)
  end
  self._pressed = false
end

function Toggle:mousemoved(x, y) end

function Toggle:draw()
  if not (love and love.graphics) then return end
  local typography = require("src.ui.typography")

  love.graphics.setColor(1, 1, 1)
  love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
  love.graphics.setColor(0.1, 0.1, 0.1)
  love.graphics.setLineWidth(1)
  love.graphics.rectangle("line", self.x, self.y, self.w, self.h)

  -- Label, left-aligned
  typography.with("md", function()
    love.graphics.setColor(0.1, 0.1, 0.1)
    local fh = love.graphics.getFont():getHeight()
    love.graphics.print(self.label, self.x + 12, self.y + (self.h - fh) / 2)
  end)

  -- ON/OFF indicator, right-aligned
  local indicator_w = 64
  local ix = self.x + self.w - indicator_w - 8
  local iy = self.y + 6
  local ih = self.h - 12
  if self.value then
    love.graphics.setColor(0.2, 0.6, 0.3)
  else
    love.graphics.setColor(0.6, 0.6, 0.6)
  end
  love.graphics.rectangle("fill", ix, iy, indicator_w, ih)
  love.graphics.setColor(0.1, 0.1, 0.1)
  love.graphics.rectangle("line", ix, iy, indicator_w, ih)

  typography.with("sm", function()
    love.graphics.setColor(1, 1, 1)
    local font = love.graphics.getFont()
    local text = self.value and "ON" or "OFF"
    local tw = font:getWidth(text)
    local fh = font:getHeight()
    love.graphics.print(text,
      ix + (indicator_w - tw) / 2,
      iy + (ih - fh) / 2)
  end)
end

return {
  new = new,
}
```

- [ ] **Step 4: Run the spec to confirm pass**

Run: `busted tests/spec/toggle_spec.lua -v`

Expected: 6 successes / 0 failures.

- [ ] **Step 5: Full suite**

Run: `busted`

Expected: 44 successes / 0 failures (38 prior + 6 Toggle).

- [ ] **Step 6: Commit**

```bash
git add src/ui/components/toggle.lua tests/spec/toggle_spec.lua
git commit -m "$(cat <<'EOF'
Add Toggle widget for boolean settings

Click anywhere in the widget to flip; on_change fires only on actual
change. ON state renders as a green indicator with the label "ON";
OFF state is grey. Used by the config screen for sabotage tier-gating.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: RadioGroup widget — pick one of several options

**Files:**
- Create: `tests/spec/radio_group_spec.lua`
- Create: `src/ui/components/radio_group.lua`

The RadioGroup holds a list of `{ id, label }` options and a current `value` (an id). Each option is a vertically-stacked row of fixed height. Clicking a row selects that option and fires `on_change(new_id)`.

- [ ] **Step 1: Write the failing spec**

`tests/spec/radio_group_spec.lua`:

```lua
local RadioGroup = require("src.ui.components.radio_group")

local function fixture()
  return RadioGroup.new({
    x = 0, y = 0, w = 320,
    row_h = 32,
    options = {
      { id = "a", label = "Alpha" },
      { id = "b", label = "Beta" },
      { id = "c", label = "Gamma" },
    },
    value = "a",
  })
end

describe("RadioGroup", function()
  it("starts at the provided value", function()
    local r = fixture()
    assert.is_equal("a", r:get_value())
  end)

  it("defaults value to the first option's id when none given", function()
    local r = RadioGroup.new({
      x = 0, y = 0, w = 320, row_h = 32,
      options = { { id = "only", label = "Only" } },
    })
    assert.is_equal("only", r:get_value())
  end)

  it("set_value updates and fires on_change only on actual change", function()
    local last
    local r = RadioGroup.new({
      x = 0, y = 0, w = 320, row_h = 32,
      options = {
        { id = "a", label = "Alpha" },
        { id = "b", label = "Beta" },
      },
      value = "a",
      on_change = function(v) last = v end,
    })
    r:set_value("a")
    assert.is_nil(last)
    r:set_value("b")
    assert.is_equal("b", last)
    assert.is_equal("b", r:get_value())
  end)

  it("set_value rejects unknown ids", function()
    local r = fixture()
    assert.has_error(function() r:set_value("missing") end)
  end)

  it("press-then-release inside row 2 selects option B", function()
    local last
    local r = RadioGroup.new({
      x = 0, y = 0, w = 320, row_h = 32,
      options = {
        { id = "a", label = "Alpha" },
        { id = "b", label = "Beta" },
        { id = "c", label = "Gamma" },
      },
      value = "a",
      on_change = function(v) last = v end,
    })
    -- Row 2 occupies y = 32..63
    r:mousepressed(50, 40, 1)
    r:mousereleased(50, 40, 1)
    assert.is_equal("b", r:get_value())
    assert.is_equal("b", last)
  end)

  it("press inside one row then release on a different row does not change value", function()
    local r = fixture()
    r:mousepressed(50, 10, 1)   -- press on row 0 ("a")
    r:mousereleased(50, 50, 1)  -- release on row 1
    assert.is_equal("a", r:get_value())
  end)

  it("non-primary button does not select", function()
    local r = fixture()
    r:mousepressed(50, 40, 2)
    r:mousereleased(50, 40, 2)
    assert.is_equal("a", r:get_value())
  end)
end)
```

- [ ] **Step 2: Run the spec to confirm it fails**

Run: `busted tests/spec/radio_group_spec.lua -v`

Expected: `module 'src.ui.components.radio_group' not found`.

- [ ] **Step 3: Implement `src/ui/components/radio_group.lua`**

```lua
-- Vertical RadioGroup: each option is a row of fixed height. Click a
-- row to select the corresponding option id.

local RadioGroup = {}
RadioGroup.__index = RadioGroup

local function noop() end

local function find_index(options, id)
  for i, o in ipairs(options) do
    if o.id == id then return i end
  end
  return nil
end

local function new(opts)
  local options = opts.options
  assert(type(options) == "table" and #options >= 1,
    "RadioGroup requires at least one option")
  local value = opts.value or options[1].id
  assert(find_index(options, value), "value not in options: " .. tostring(value))
  return setmetatable({
    x = opts.x or 0,
    y = opts.y or 0,
    w = opts.w or 320,
    row_h = opts.row_h or 32,
    options = options,
    value = value,
    label = opts.label or "",
    on_change = opts.on_change or noop,
    _press_row = nil,
  }, RadioGroup)
end

function RadioGroup:get_value()
  return self.value
end

function RadioGroup:set_value(id)
  assert(find_index(self.options, id), "unknown option id: " .. tostring(id))
  if id ~= self.value then
    self.value = id
    self.on_change(self.value)
  end
end

function RadioGroup:_row_at(px, py)
  if px < self.x or px >= self.x + self.w then return nil end
  local rel_y = py - self.y
  if rel_y < 0 then return nil end
  local idx = math.floor(rel_y / self.row_h) + 1
  if idx >= 1 and idx <= #self.options then return idx end
  return nil
end

function RadioGroup:mousepressed(x, y, btn)
  if btn ~= 1 then return end
  self._press_row = self:_row_at(x, y)
end

function RadioGroup:mousereleased(x, y, btn)
  if btn ~= 1 then return end
  local release_row = self:_row_at(x, y)
  if self._press_row and self._press_row == release_row then
    self:set_value(self.options[release_row].id)
  end
  self._press_row = nil
end

function RadioGroup:mousemoved(x, y) end

function RadioGroup:height()
  return #self.options * self.row_h
end

function RadioGroup:draw()
  if not (love and love.graphics) then return end
  local typography = require("src.ui.typography")

  for i, opt in ipairs(self.options) do
    local row_y = self.y + (i - 1) * self.row_h
    local is_selected = (opt.id == self.value)

    -- Radio dot
    local cx = self.x + 16
    local cy = row_y + self.row_h / 2
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", cx, cy, 8)
    if is_selected then
      love.graphics.setColor(0.1, 0.1, 0.1)
      love.graphics.circle("fill", cx, cy, 4)
    end

    -- Label
    typography.with("md", function()
      love.graphics.setColor(0.1, 0.1, 0.1)
      local fh = love.graphics.getFont():getHeight()
      love.graphics.print(opt.label, self.x + 34, row_y + (self.row_h - fh) / 2)
    end)
  end
end

return {
  new = new,
}
```

- [ ] **Step 4: Run the spec to confirm pass**

Run: `busted tests/spec/radio_group_spec.lua -v`

Expected: 7 successes / 0 failures.

- [ ] **Step 5: Full suite**

Run: `busted`

Expected: 51 successes / 0 failures.

- [ ] **Step 6: Commit**

```bash
git add src/ui/components/radio_group.lua tests/spec/radio_group_spec.lua
git commit -m "$(cat <<'EOF'
Add RadioGroup widget for one-of-N selection

Vertical stack of rows; click a row to select that option's id.
on_change fires only on actual change. Used by the config screen for
end-trigger selection.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: TextInput widget — focus-based text editing

**Files:**
- Create: `tests/spec/text_input_spec.lua`
- Create: `src/ui/components/text_input.lua`

TextInput holds a string and a focused flag. Clicking inside focuses; clicking outside defocuses. While focused, `:textinput(text)` appends, capped at `max_length`. `:keypressed("backspace")` removes the last character. `:keypressed("return")` and `:keypressed("escape")` both defocus. Cursor is always at the end of the string for v1.

- [ ] **Step 1: Write the failing spec**

`tests/spec/text_input_spec.lua`:

```lua
local TextInput = require("src.ui.components.text_input")

describe("TextInput", function()
  it("starts at the provided value", function()
    local t = TextInput.new({ x = 0, y = 0, w = 240, h = 32, value = "hello" })
    assert.is_equal("hello", t:get_value())
  end)

  it("defaults: value='', max_length=24, focused=false", function()
    local t = TextInput.new({ x = 0, y = 0, w = 240, h = 32 })
    assert.is_equal("", t:get_value())
    assert.is_false(t.focused)
  end)

  it("clicking inside focuses the widget", function()
    local t = TextInput.new({ x = 0, y = 0, w = 240, h = 32 })
    t:mousepressed(50, 16, 1)
    assert.is_true(t.focused)
  end)

  it("clicking outside defocuses the widget", function()
    local t = TextInput.new({ x = 0, y = 0, w = 240, h = 32, value = "hi" })
    t:mousepressed(50, 16, 1)
    assert.is_true(t.focused)
    t:mousepressed(999, 999, 1)
    assert.is_false(t.focused)
  end)

  it("textinput appends only when focused", function()
    local t = TextInput.new({ x = 0, y = 0, w = 240, h = 32, value = "" })
    t:textinput("a")
    assert.is_equal("", t:get_value()) -- not focused
    t:mousepressed(50, 16, 1)
    t:textinput("a")
    t:textinput("b")
    assert.is_equal("ab", t:get_value())
  end)

  it("textinput respects max_length", function()
    local t = TextInput.new({ x = 0, y = 0, w = 240, h = 32, value = "", max_length = 3 })
    t:mousepressed(50, 16, 1)
    t:textinput("a"); t:textinput("b"); t:textinput("c"); t:textinput("d")
    assert.is_equal("abc", t:get_value())
  end)

  it("backspace removes the last character when focused", function()
    local t = TextInput.new({ x = 0, y = 0, w = 240, h = 32, value = "hello" })
    t:mousepressed(50, 16, 1)
    t:keypressed("backspace")
    assert.is_equal("hell", t:get_value())
    t:keypressed("backspace")
    t:keypressed("backspace")
    t:keypressed("backspace")
    t:keypressed("backspace")
    assert.is_equal("", t:get_value())
    -- Extra backspace on empty string is a no-op
    t:keypressed("backspace")
    assert.is_equal("", t:get_value())
  end)

  it("backspace ignored when not focused", function()
    local t = TextInput.new({ x = 0, y = 0, w = 240, h = 32, value = "hello" })
    t:keypressed("backspace")
    assert.is_equal("hello", t:get_value())
  end)

  it("return and escape defocus the widget", function()
    local t = TextInput.new({ x = 0, y = 0, w = 240, h = 32 })
    t:mousepressed(50, 16, 1)
    assert.is_true(t.focused)
    t:keypressed("return")
    assert.is_false(t.focused)
    t:mousepressed(50, 16, 1)
    assert.is_true(t.focused)
    t:keypressed("escape")
    assert.is_false(t.focused)
  end)

  it("on_change fires when value changes (textinput and backspace), not on focus changes", function()
    local last
    local fires = 0
    local t = TextInput.new({
      x = 0, y = 0, w = 240, h = 32, value = "",
      on_change = function(v) last = v; fires = fires + 1 end,
    })
    t:mousepressed(50, 16, 1)  -- focus, should not fire
    assert.is_equal(0, fires)
    t:textinput("a")
    assert.is_equal("a", last); assert.is_equal(1, fires)
    t:keypressed("backspace")
    assert.is_equal("", last); assert.is_equal(2, fires)
    t:keypressed("return")     -- defocus, should not fire
    assert.is_equal(2, fires)
  end)

  it("set_value updates and fires on_change only on actual change", function()
    local last
    local t = TextInput.new({
      x = 0, y = 0, w = 240, h = 32, value = "hi",
      on_change = function(v) last = v end,
    })
    t:set_value("hi")
    assert.is_nil(last)
    t:set_value("bye")
    assert.is_equal("bye", last)
    assert.is_equal("bye", t:get_value())
  end)

  it("set_value truncates to max_length", function()
    local t = TextInput.new({ x = 0, y = 0, w = 240, h = 32, max_length = 3 })
    t:set_value("abcdef")
    assert.is_equal("abc", t:get_value())
  end)
end)
```

- [ ] **Step 2: Run the spec to confirm it fails**

Run: `busted tests/spec/text_input_spec.lua -v`

Expected: `module 'src.ui.components.text_input' not found`.

- [ ] **Step 3: Implement `src/ui/components/text_input.lua`**

```lua
-- Focus-based text input. Click inside to focus; click outside to
-- defocus. While focused, textinput(text) appends (capped at
-- max_length); keypressed("backspace") removes the last character;
-- keypressed("return") or ("escape") defocus.
--
-- Cursor is implicit (always at end) for v1. No selection, no arrow
-- keys, no copy/paste.

local TextInput = {}
TextInput.__index = TextInput

local function noop() end

local function new(opts)
  local max_length = opts.max_length or 24
  local value = opts.value or ""
  if #value > max_length then value = value:sub(1, max_length) end
  return setmetatable({
    x = opts.x or 0,
    y = opts.y or 0,
    w = opts.w or 240,
    h = opts.h or 32,
    value = value,
    max_length = max_length,
    label = opts.label or "",
    focused = false,
    on_change = opts.on_change or noop,
  }, TextInput)
end

function TextInput:get_value()
  return self.value
end

function TextInput:set_value(s)
  s = s or ""
  if #s > self.max_length then s = s:sub(1, self.max_length) end
  if s ~= self.value then
    self.value = s
    self.on_change(self.value)
  end
end

function TextInput:hit(px, py)
  return px >= self.x and py >= self.y
     and px < self.x + self.w and py < self.y + self.h
end

function TextInput:mousepressed(x, y, btn)
  if btn ~= 1 then return end
  self.focused = self:hit(x, y)
end

function TextInput:mousereleased(x, y, btn) end
function TextInput:mousemoved(x, y) end

function TextInput:textinput(text)
  if not self.focused then return end
  if #self.value >= self.max_length then return end
  local remaining = self.max_length - #self.value
  local addition = text:sub(1, remaining)
  if addition == "" then return end
  self.value = self.value .. addition
  self.on_change(self.value)
end

function TextInput:keypressed(key)
  if not self.focused then return end
  if key == "backspace" then
    if #self.value > 0 then
      self.value = self.value:sub(1, #self.value - 1)
      self.on_change(self.value)
    end
  elseif key == "return" or key == "escape" then
    self.focused = false
  end
end

function TextInput:draw()
  if not (love and love.graphics) then return end
  local typography = require("src.ui.typography")

  -- Box
  love.graphics.setColor(1, 1, 1)
  love.graphics.rectangle("fill", self.x, self.y, self.w, self.h)
  if self.focused then
    love.graphics.setColor(0.1, 0.4, 0.7)
    love.graphics.setLineWidth(2)
  else
    love.graphics.setColor(0.1, 0.1, 0.1)
    love.graphics.setLineWidth(1)
  end
  love.graphics.rectangle("line", self.x, self.y, self.w, self.h)

  -- Value (with trailing cursor when focused)
  typography.with("md", function()
    love.graphics.setColor(0.1, 0.1, 0.1)
    local font = love.graphics.getFont()
    local fh = font:getHeight()
    local text = self.value
    love.graphics.print(text, self.x + 10, self.y + (self.h - fh) / 2)

    if self.focused then
      local tw = font:getWidth(text)
      love.graphics.setColor(0.1, 0.1, 0.1)
      love.graphics.setLineWidth(1)
      love.graphics.line(
        self.x + 10 + tw + 1, self.y + 6,
        self.x + 10 + tw + 1, self.y + self.h - 6)
    end
  end)
end

return {
  new = new,
}
```

- [ ] **Step 4: Run the spec to confirm pass**

Run: `busted tests/spec/text_input_spec.lua -v`

Expected: 12 successes / 0 failures.

- [ ] **Step 5: Full suite**

Run: `busted`

Expected: 63 successes / 0 failures.

- [ ] **Step 6: Commit**

```bash
git add src/ui/components/text_input.lua tests/spec/text_input_spec.lua
git commit -m "$(cat <<'EOF'
Add TextInput widget for focus-based text editing

Click to focus; click outside to defocus. While focused, textinput
appends (capped at max_length), backspace deletes the last char,
return/escape defocus. Used by the config screen for the company name
and by player setup for character names.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: ColorPicker widget — pick one of a palette of colors

**Files:**
- Create: `tests/spec/color_picker_spec.lua`
- Create: `src/ui/components/color_picker.lua`

The ColorPicker holds an integer `value` that's an index into a palette of `{r, g, b}` tuples. Clicking a swatch selects that index.

- [ ] **Step 1: Write the failing spec**

`tests/spec/color_picker_spec.lua`:

```lua
local ColorPicker = require("src.ui.components.color_picker")

local function fixture()
  return ColorPicker.new({
    x = 0, y = 0,
    swatch_size = 32,
    gap = 8,
    palette = {
      { 1, 0, 0 },
      { 0, 1, 0 },
      { 0, 0, 1 },
      { 1, 1, 0 },
    },
    value = 1,
  })
end

describe("ColorPicker", function()
  it("starts at the provided value", function()
    local c = fixture()
    assert.is_equal(1, c:get_value())
  end)

  it("defaults value to 1 when none given", function()
    local c = ColorPicker.new({
      x = 0, y = 0, swatch_size = 32, gap = 8,
      palette = { { 1, 0, 0 }, { 0, 1, 0 } },
    })
    assert.is_equal(1, c:get_value())
  end)

  it("set_value updates and fires on_change only on actual change", function()
    local last
    local c = ColorPicker.new({
      x = 0, y = 0, swatch_size = 32, gap = 8,
      palette = { { 1, 0, 0 }, { 0, 1, 0 } },
      value = 1,
      on_change = function(v) last = v end,
    })
    c:set_value(1)
    assert.is_nil(last)
    c:set_value(2)
    assert.is_equal(2, last)
  end)

  it("set_value rejects out-of-range indices", function()
    local c = fixture()
    assert.has_error(function() c:set_value(0) end)
    assert.has_error(function() c:set_value(5) end)
  end)

  it("press-then-release on swatch 3 selects index 3", function()
    local c = fixture()
    -- Swatches are 32px wide with 8px gap, starting at x=0.
    -- swatch 1: 0..31  swatch 2: 40..71  swatch 3: 80..111  swatch 4: 120..151
    c:mousepressed(90, 16, 1)
    c:mousereleased(90, 16, 1)
    assert.is_equal(3, c:get_value())
  end)

  it("press inside one swatch then release on another does not change value", function()
    local c = fixture()
    c:mousepressed(10, 16, 1)  -- swatch 1
    c:mousereleased(50, 16, 1) -- swatch 2
    assert.is_equal(1, c:get_value())
  end)

  it("press in the gap between swatches is a no-op", function()
    local c = fixture()
    c:mousepressed(35, 16, 1)  -- in the 32..39 gap
    c:mousereleased(35, 16, 1)
    assert.is_equal(1, c:get_value())
  end)

  it("non-primary mouse button does not select", function()
    local c = fixture()
    c:mousepressed(90, 16, 2)
    c:mousereleased(90, 16, 2)
    assert.is_equal(1, c:get_value())
  end)
end)
```

- [ ] **Step 2: Run the spec to confirm it fails**

Run: `busted tests/spec/color_picker_spec.lua -v`

Expected: `module 'src.ui.components.color_picker' not found`.

- [ ] **Step 3: Implement `src/ui/components/color_picker.lua`**

```lua
-- Horizontal row of color swatches. Click a swatch to select; value
-- is the 1-based index into the palette.

local ColorPicker = {}
ColorPicker.__index = ColorPicker

local function noop() end

local function new(opts)
  local palette = opts.palette
  assert(type(palette) == "table" and #palette >= 1,
    "ColorPicker requires a non-empty palette")
  local swatch = opts.swatch_size or 32
  local gap = opts.gap or 8
  local value = opts.value or 1
  assert(value >= 1 and value <= #palette,
    "ColorPicker value out of range")
  return setmetatable({
    x = opts.x or 0,
    y = opts.y or 0,
    swatch_size = swatch,
    gap = gap,
    palette = palette,
    value = value,
    on_change = opts.on_change or noop,
    _press_idx = nil,
  }, ColorPicker)
end

function ColorPicker:get_value()
  return self.value
end

function ColorPicker:set_value(idx)
  assert(idx >= 1 and idx <= #self.palette,
    "ColorPicker:set_value out of range: " .. tostring(idx))
  if idx ~= self.value then
    self.value = idx
    self.on_change(self.value)
  end
end

function ColorPicker:width()
  local n = #self.palette
  return n * self.swatch_size + (n - 1) * self.gap
end

function ColorPicker:_swatch_at(px, py)
  if py < self.y or py >= self.y + self.swatch_size then return nil end
  local rel = px - self.x
  if rel < 0 then return nil end
  local stride = self.swatch_size + self.gap
  local idx = math.floor(rel / stride) + 1
  if idx < 1 or idx > #self.palette then return nil end
  local within = rel - (idx - 1) * stride
  if within >= self.swatch_size then return nil end -- click in the gap
  return idx
end

function ColorPicker:mousepressed(x, y, btn)
  if btn ~= 1 then return end
  self._press_idx = self:_swatch_at(x, y)
end

function ColorPicker:mousereleased(x, y, btn)
  if btn ~= 1 then return end
  local release_idx = self:_swatch_at(x, y)
  if self._press_idx and self._press_idx == release_idx then
    self:set_value(release_idx)
  end
  self._press_idx = nil
end

function ColorPicker:mousemoved(x, y) end

function ColorPicker:draw()
  if not (love and love.graphics) then return end
  local stride = self.swatch_size + self.gap
  for i, rgb in ipairs(self.palette) do
    local sx = self.x + (i - 1) * stride
    love.graphics.setColor(rgb[1], rgb[2], rgb[3])
    love.graphics.rectangle("fill", sx, self.y, self.swatch_size, self.swatch_size)
    if i == self.value then
      love.graphics.setColor(0.1, 0.1, 0.1)
      love.graphics.setLineWidth(3)
    else
      love.graphics.setColor(0.1, 0.1, 0.1)
      love.graphics.setLineWidth(1)
    end
    love.graphics.rectangle("line", sx, self.y, self.swatch_size, self.swatch_size)
  end
end

return {
  new = new,
}
```

- [ ] **Step 4: Run the spec to confirm pass**

Run: `busted tests/spec/color_picker_spec.lua -v`

Expected: 8 successes / 0 failures.

- [ ] **Step 5: Full suite**

Run: `busted`

Expected: 71 successes / 0 failures.

- [ ] **Step 6: Commit**

```bash
git add src/ui/components/color_picker.lua tests/spec/color_picker_spec.lua
git commit -m "$(cat <<'EOF'
Add ColorPicker widget for selecting a palette index

Horizontal row of color swatches; click a swatch to select. The
selected swatch gets a thick black border. Used by the player setup
screen for each player's stick-figure color.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: Extend Session — player helpers, palette, end_trigger taxonomy

**Files:**
- Modify: `src/game/session.lua`
- Modify: `tests/spec/session_spec.lua`

Session needs:
1. A `PLAYER_PALETTE` constant — 8 distinguishable colors.
2. An `END_TRIGGERS` constant — the valid end-trigger ids.
3. Validation in `set_mode` (already exists) plus new setters: `set_player_count(n)`, `set_player_name(i, name)`, `set_player_color(i, color_idx)`, and a generic `set_config(key, value)` that validates `end_trigger` against `END_TRIGGERS`.
4. `set_player_count` adjusts `session.players` to length `n`: append default players (name `"Player <i>"`, color `i`) if growing; truncate if shrinking.

- [ ] **Step 1: Append to `tests/spec/session_spec.lua`**

Inside the existing `describe("Session", function() ... end)` block, just before the closing `end)`, append these new tests:

```lua
  it("exposes a PLAYER_PALETTE of 8 distinguishable colors", function()
    local p = Session.PLAYER_PALETTE
    assert.is_table(p)
    assert.is_equal(8, #p)
    for _, rgb in ipairs(p) do
      assert.is_equal(3, #rgb)
      for _, c in ipairs(rgb) do
        assert.is_true(c >= 0 and c <= 1)
      end
    end
  end)

  it("exposes END_TRIGGERS with the documented ids", function()
    local t = Session.END_TRIGGERS
    local by_id = {}
    for _, e in ipairs(t) do by_id[e.id] = e end
    assert.is_not_nil(by_id.first_to_csuite_or_5_sprints)
    assert.is_not_nil(by_id.fixed_n_sprints_3)
    assert.is_not_nil(by_id.fixed_n_sprints_5)
    assert.is_not_nil(by_id.fixed_n_sprints_7)
    assert.is_not_nil(by_id.first_to_comp_target)
    assert.is_equal(5, #t)
  end)

  it("set_player_count grows by appending default players", function()
    local s = Session.new()
    s:set_player_count(3)
    assert.is_equal(3, #s.players)
    assert.is_equal("Player 1", s.players[1].name)
    assert.is_equal(1, s.players[1].color)
    assert.is_equal("Player 2", s.players[2].name)
    assert.is_equal(2, s.players[2].color)
    assert.is_equal("Player 3", s.players[3].name)
    assert.is_equal(3, s.players[3].color)
    assert.is_equal(3, s.config.player_count)
  end)

  it("set_player_count shrinking truncates excess players", function()
    local s = Session.new()
    s:set_player_count(5)
    s.players[3].name = "Brenda"
    s:set_player_count(2)
    assert.is_equal(2, #s.players)
    assert.is_equal("Player 1", s.players[1].name)
    assert.is_equal("Player 2", s.players[2].name)
  end)

  it("set_player_count preserves existing player records when growing", function()
    local s = Session.new()
    s:set_player_count(3)
    s.players[2].name = "Mallory"
    s:set_player_count(5)
    assert.is_equal("Mallory", s.players[2].name)
    assert.is_equal("Player 4", s.players[4].name)
    assert.is_equal("Player 5", s.players[5].name)
  end)

  it("set_player_count rejects values outside [2, 8]", function()
    local s = Session.new()
    assert.has_error(function() s:set_player_count(1) end)
    assert.has_error(function() s:set_player_count(9) end)
    assert.has_error(function() s:set_player_count(0) end)
  end)

  it("set_player_name updates the given slot", function()
    local s = Session.new()
    s:set_player_count(3)
    s:set_player_name(2, "Brenda")
    assert.is_equal("Brenda", s.players[2].name)
  end)

  it("set_player_name rejects out-of-range slots", function()
    local s = Session.new()
    s:set_player_count(3)
    assert.has_error(function() s:set_player_name(0, "x") end)
    assert.has_error(function() s:set_player_name(4, "x") end)
  end)

  it("set_player_name truncates names longer than 20 chars", function()
    local s = Session.new()
    s:set_player_count(2)
    s:set_player_name(1, string.rep("x", 30))
    assert.is_equal(20, #s.players[1].name)
  end)

  it("set_player_color updates the slot", function()
    local s = Session.new()
    s:set_player_count(3)
    s:set_player_color(2, 5)
    assert.is_equal(5, s.players[2].color)
  end)

  it("set_player_color rejects out-of-palette indices", function()
    local s = Session.new()
    s:set_player_count(3)
    assert.has_error(function() s:set_player_color(2, 0) end)
    assert.has_error(function() s:set_player_color(2, 9) end)
  end)

  it("set_config writes through to config and validates end_trigger", function()
    local s = Session.new()
    s:set_config("ap_per_turn", 4)
    assert.is_equal(4, s.config.ap_per_turn)
    s:set_config("end_trigger", "fixed_n_sprints_5")
    assert.is_equal("fixed_n_sprints_5", s.config.end_trigger)
    assert.has_error(function() s:set_config("end_trigger", "bogus") end)
  end)
```

- [ ] **Step 2: Run the spec to see new failures**

Run: `busted tests/spec/session_spec.lua -v`

Expected: 5 existing tests pass; ~12 new ones fail (`PLAYER_PALETTE` not exported, `END_TRIGGERS` not exported, setters not defined).

- [ ] **Step 3: Update `src/game/session.lua`**

Replace the whole file:

```lua
-- Game-wide configuration carried through every state from pre-game
-- through end-screen. Plan 2 established the shape; Plan 3 adds the
-- player-record helpers and the end-trigger taxonomy.

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

-- Valid end-trigger ids. Sub-parameters (e.g., comp_target) live on
-- config and are read by the gameplay code that respects the trigger.
Session.END_TRIGGERS = {
  { id = "first_to_csuite_or_5_sprints", label = "First to C-suite OR 5 sprints" },
  { id = "fixed_n_sprints_3", label = "Fixed 3 sprints" },
  { id = "fixed_n_sprints_5", label = "Fixed 5 sprints" },
  { id = "fixed_n_sprints_7", label = "Fixed 7 sprints" },
  { id = "first_to_comp_target", label = "First to Comp target" },
}

-- Eight distinguishable colors for stick figures. Indexed 1..8.
Session.PLAYER_PALETTE = {
  { 0.85, 0.30, 0.30 }, -- red
  { 0.30, 0.50, 0.85 }, -- blue
  { 0.30, 0.70, 0.40 }, -- green
  { 0.95, 0.80, 0.30 }, -- yellow
  { 0.65, 0.35, 0.85 }, -- purple
  { 0.95, 0.55, 0.25 }, -- orange
  { 0.30, 0.75, 0.85 }, -- cyan
  { 0.95, 0.55, 0.75 }, -- pink
}

local MAX_NAME = 20

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

local function valid_end_trigger(id)
  for _, t in ipairs(Session.END_TRIGGERS) do
    if t.id == id then return true end
  end
  return false
end

function Session:set_config(key, value)
  if key == "end_trigger" then
    assert(valid_end_trigger(value), "invalid end_trigger: " .. tostring(value))
  end
  self.config[key] = value
end

function Session:set_player_count(n)
  assert(n >= 2 and n <= 8, "player_count must be in [2, 8], got " .. tostring(n))
  while #self.players < n do
    local i = #self.players + 1
    table.insert(self.players, {
      name = "Player " .. tostring(i),
      color = i, -- default: each player gets the next palette index
    })
  end
  while #self.players > n do
    table.remove(self.players)
  end
  self.config.player_count = n
end

function Session:set_player_name(i, name)
  assert(self.players[i], "no player at slot " .. tostring(i))
  name = name or ""
  if #name > MAX_NAME then name = name:sub(1, MAX_NAME) end
  self.players[i].name = name
end

function Session:set_player_color(i, color_idx)
  assert(self.players[i], "no player at slot " .. tostring(i))
  assert(color_idx >= 1 and color_idx <= #Session.PLAYER_PALETTE,
    "color index out of range: " .. tostring(color_idx))
  self.players[i].color = color_idx
end

return {
  new = new,
  MODES = Session.MODES,
  END_TRIGGERS = Session.END_TRIGGERS,
  PLAYER_PALETTE = Session.PLAYER_PALETTE,
}
```

- [ ] **Step 4: Run the spec to confirm pass**

Run: `busted tests/spec/session_spec.lua -v`

Expected: 17 successes / 0 failures (5 original + 12 new).

- [ ] **Step 5: Full suite**

Run: `busted`

Expected: 83 successes / 0 failures.

- [ ] **Step 6: Commit**

```bash
git add src/game/session.lua tests/spec/session_spec.lua
git commit -m "$(cat <<'EOF'
Extend Session with player helpers, palette, and end-trigger taxonomy

Adds:
- PLAYER_PALETTE: 8 distinguishable stick-figure colors.
- END_TRIGGERS: 5 valid end-trigger ids with labels.
- set_player_count: grow with default Player N records / truncate.
- set_player_name (truncates to 20 chars), set_player_color (validates).
- set_config(key, value) with end_trigger validation.

Backs the upcoming config and player-setup screens.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: Real config screen

**Files:**
- Modify: `src/states/config.lua` (replace placeholder)
- Modify: `main.lua` (route `textinput` to active state — needed for TextInput)

The config screen orchestrates one widget per setting. Layout: a column of rows; each row is a label + widget pair. Bottom of the screen: a "Continue" button (gated to enabled state) and a "Back" button.

The TextInput widget needs Love2D's `textinput` callback to reach the focused widget. `main.lua` already dispatches `textinput` to the active state via `fsm:dispatch("textinput", text)` (added in Plan 1). The config state will receive that and route to its TextInput.

Same for `keypressed` — the FSM already dispatches it.

- [ ] **Step 1: Verify main.lua already dispatches textinput**

Run: `grep textinput main.lua`

Expected: line `function love.textinput(text) fsm:dispatch("textinput", text) end` is present. If absent, that line must be added before proceeding.

- [ ] **Step 2: Replace `src/states/config.lua`**

```lua
local Button = require("src.ui.components.button")
local RadioGroup = require("src.ui.components.radio_group")
local Session = require("src.game.session")
local Stepper = require("src.ui.components.stepper")
local TextInput = require("src.ui.components.text_input")
local Toggle = require("src.ui.components.toggle")
local typography = require("src.ui.typography")

local M = {}
M.__index = M

local CONTENT_W = 760
local ROW_H = 56
local ROW_GAP = 12
local LABEL_W = 240

local PRESETS = {
  "MegaCorp", "Axiom Inc.", "Hypercorp", "Globodyne Synthetics",
  "Latent", "Prompt Industries", "NullPointer Inc.", "Agentic", "VibeStack",
}

local function build_layout(self, w, h)
  local config = self.session.config
  local x_label = (w - CONTENT_W) / 2
  local x_widget = x_label + LABEL_W
  local widget_w = CONTENT_W - LABEL_W
  local y = 96

  self.rows = {}            -- { y, label }
  self.widgets = {}         -- ordered list of widget objects (each with the standard interface)
  self.preset_buttons = {}  -- click-to-fill company name presets

  local function add_row(label, widget)
    table.insert(self.rows, { y = y, label = label })
    table.insert(self.widgets, widget)
    y = y + ROW_H + ROW_GAP
  end

  -- Company name (TextInput)
  local company_input = TextInput.new({
    x = x_widget, y = y + (ROW_H - 32) / 2,
    w = widget_w, h = 32,
    value = config.company_name,
    max_length = 24,
    on_change = function(v) self.session:set_config("company_name", v) end,
  })
  self._company_input = company_input
  add_row("Company name", company_input)

  -- Preset chips row beneath the company name (purely additional, not a "row" in the rows table)
  local preset_y = y
  local cx = x_widget
  for _, name in ipairs(PRESETS) do
    -- Coarse width estimate so we can lay out preset chips at construction
    -- time without measuring with love.graphics. Slightly generous; xs-font
    -- characters average ~6-8px wide, so 16 (padding) + 8 * len works.
    local btn_w = 16 + 8 * #name
    if cx + btn_w > x_widget + widget_w then
      cx = x_widget
      preset_y = preset_y + 32
    end
    local btn = Button.new({
      x = cx, y = preset_y, w = btn_w, h = 28,
      label = name,
      font_size = "xs",
      on_click = function()
        company_input:set_value(name)
      end,
    })
    table.insert(self.preset_buttons, btn)
    cx = cx + btn_w + 6
  end
  y = preset_y + 32 + ROW_GAP

  -- Player count
  add_row("Player count", Stepper.new({
    x = x_widget, y = y + (ROW_H - 40) / 2,
    w = 240, h = 40,
    value = config.player_count, min = 2, max = 8,
    on_change = function(v) self.session:set_player_count(v) end,
  }))

  -- AP per turn
  add_row("Action points per turn", Stepper.new({
    x = x_widget, y = y + (ROW_H - 40) / 2,
    w = 240, h = 40,
    value = config.ap_per_turn, min = 1, max = 5,
    on_change = function(v) self.session:set_config("ap_per_turn", v) end,
  }))

  -- End trigger (RadioGroup; ROW_H here is overridden by the group's height)
  local end_options = {}
  for _, t in ipairs(Session.END_TRIGGERS) do
    table.insert(end_options, { id = t.id, label = t.label })
  end
  local end_rg = RadioGroup.new({
    x = x_widget, y = y,
    w = widget_w,
    row_h = 28,
    options = end_options,
    value = config.end_trigger,
    on_change = function(id) self.session:set_config("end_trigger", id) end,
  })
  table.insert(self.rows, { y = y, label = "End trigger" })
  table.insert(self.widgets, end_rg)
  y = y + end_rg:height() + ROW_GAP

  -- Comp target
  add_row("Comp target (when applicable)", Stepper.new({
    x = x_widget, y = y + (ROW_H - 40) / 2,
    w = 240, h = 40,
    value = config.comp_target, min = 10, max = 100,
    on_change = function(v) self.session:set_config("comp_target", v) end,
  }))

  -- Per-sprint turn cap
  add_row("Per-sprint turn cap", Stepper.new({
    x = x_widget, y = y + (ROW_H - 40) / 2,
    w = 240, h = 40,
    value = config.turn_cap, min = 4, max = 20,
    on_change = function(v) self.session:set_config("turn_cap", v) end,
  }))

  -- Sabotage tier-gating
  add_row("Sabotage tier-gating", Toggle.new({
    x = x_widget, y = y + (ROW_H - 40) / 2,
    w = 240, h = 40,
    value = config.tier_gating,
    on_change = function(v) self.session:set_config("tier_gating", v) end,
  }))

  -- Footer buttons
  local fsm = self.fsm
  self.back_button = Button.new({
    x = 32, y = h - 64, w = 120, h = 40,
    label = "Back",
    on_click = function() fsm:transition("mode_select") end,
  })
  self.continue_button = Button.new({
    x = w - 32 - 200, y = h - 64, w = 200, h = 40,
    label = "Continue →",
    on_click = function()
      self.session:set_player_count(self.session.config.player_count)
      fsm:transition("player_setup")
    end,
  })
end

local function new(deps)
  return setmetatable({
    fsm = deps.fsm,
    session = deps.session,
  }, M)
end

function M:enter()
  -- Ensure the session has the right player_count seeded so player_setup
  -- can immediately render the right number of rows.
  if #self.session.players == 0 then
    self.session:set_player_count(self.session.config.player_count)
  end
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
    local title = "Configure the Game"
    local tw = font:getWidth(title)
    love.graphics.print(title, (w - tw) / 2, 36)
  end)

  -- Row labels
  typography.with("md", function()
    love.graphics.setColor(0.2, 0.2, 0.2)
    local x_label = (w - CONTENT_W) / 2
    for _, row in ipairs(self.rows) do
      love.graphics.print(row.label, x_label, row.y + 12)
    end
  end)

  for _, widget in ipairs(self.widgets) do widget:draw() end
  for _, b in ipairs(self.preset_buttons) do b:draw() end
  self.back_button:draw()
  self.continue_button:draw()
end

local function each_input(self, fn)
  for _, w in ipairs(self.widgets) do fn(w) end
  for _, b in ipairs(self.preset_buttons) do fn(b) end
  fn(self.back_button)
  fn(self.continue_button)
end

function M:mousemoved(x, y)
  each_input(self, function(w)
    if w.mousemoved then w:mousemoved(x, y) end
  end)
end

function M:mousepressed(x, y, btn)
  each_input(self, function(w)
    if w.mousepressed then w:mousepressed(x, y, btn) end
  end)
end

function M:mousereleased(x, y, btn)
  each_input(self, function(w)
    if w.mousereleased then w:mousereleased(x, y, btn) end
  end)
end

function M:textinput(text)
  if self._company_input then self._company_input:textinput(text) end
end

function M:keypressed(key)
  if self._company_input and self._company_input.focused then
    self._company_input:keypressed(key)
    return
  end
  if key == "escape" then
    self.fsm:transition("mode_select")
  elseif key == "return" then
    self.session:set_player_count(self.session.config.player_count)
    self.fsm:transition("player_setup")
  end
end

return {
  new = new,
}
```

- [ ] **Step 3: Run the full test suite**

Run: `busted`

Expected: 83 successes / 0 failures (no test changes — but if any widget breaks, this is when you'd find out).

- [ ] **Step 4: Boot Love to verify the config screen renders**

Run: `timeout 5 love . 2>&1 | head -20`

Expected: no error output. Exit code 124 (timeout) or 143 (SIGTERM).

If Love prints a stack trace, debug before committing. Most likely sources:
- Wrong require path (`src.ui.components.<widget>` paths must match the file paths)
- A widget missing one of the required methods (`mousepressed`, `mousereleased`, `mousemoved`, `draw`)

- [ ] **Step 5: Commit**

```bash
git add src/states/config.lua
git commit -m "$(cat <<'EOF'
Replace config placeholder with real pre-game configuration screen

Orchestrates one widget per setting from spec §5:
- TextInput for the company name, with a row of preset-fill buttons
- Stepper for player count (also seeds session.players via set_player_count)
- Stepper for action points per turn, comp target, per-sprint turn cap
- RadioGroup for end_trigger (5 options)
- Toggle for sabotage tier-gating

Continue advances to player_setup; Back returns to mode_select. Return
on the keyboard also advances; Escape returns. The company TextInput
swallows Return/Escape when focused, so the user can confirm without
accidentally leaving the screen.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: Real player setup screen

**Files:**
- Modify: `src/states/player_setup.lua` (replace placeholder)

The player setup screen renders one row per player, sized by `session.config.player_count`. Each row contains: a TextInput for the name (max 20 chars) and a ColorPicker for the stick-figure color. A "Start Game" button advances to `game`; a "Back" button returns to `config`.

Only one TextInput may be focused at a time, but that's already enforced by how `TextInput:mousepressed` works (clicking inside one focuses it; clicking outside any TextInput defocuses them all via the "focus = self:hit(x, y)" line on each).

- [ ] **Step 1: Replace `src/states/player_setup.lua`**

```lua
local Button = require("src.ui.components.button")
local ColorPicker = require("src.ui.components.color_picker")
local Session = require("src.game.session")
local TextInput = require("src.ui.components.text_input")
local typography = require("src.ui.typography")

local M = {}
M.__index = M

local CONTENT_W = 760
local ROW_H = 56
local ROW_GAP = 12
local NAME_LABEL_W = 80
local NAME_INPUT_W = 280

local function build_layout(self, w, h)
  local session = self.session
  local x = (w - CONTENT_W) / 2
  local y0 = 132

  self.rows = {} -- each row: { player_idx, y, name_input, color_picker }

  for i, player in ipairs(session.players) do
    local row_y = y0 + (i - 1) * (ROW_H + ROW_GAP)
    local input_y = row_y + (ROW_H - 32) / 2
    local picker_y = row_y + (ROW_H - 28) / 2

    local idx = i
    local name_input = TextInput.new({
      x = x + NAME_LABEL_W,
      y = input_y,
      w = NAME_INPUT_W,
      h = 32,
      value = player.name,
      max_length = 20,
      on_change = function(v) session:set_player_name(idx, v) end,
    })

    local picker = ColorPicker.new({
      x = x + NAME_LABEL_W + NAME_INPUT_W + 32,
      y = picker_y,
      swatch_size = 28,
      gap = 6,
      palette = Session.PLAYER_PALETTE,
      value = player.color,
      on_change = function(v) session:set_player_color(idx, v) end,
    })

    table.insert(self.rows, {
      player_idx = i,
      y = row_y,
      name_input = name_input,
      color_picker = picker,
    })
  end

  local fsm = self.fsm
  self.back_button = Button.new({
    x = 32, y = h - 64, w = 120, h = 40,
    label = "Back",
    on_click = function() fsm:transition("config") end,
  })
  self.start_button = Button.new({
    x = w - 32 - 200, y = h - 64, w = 200, h = 40,
    label = "Start Game →",
    on_click = function() fsm:transition("game") end,
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
  local x = (w - CONTENT_W) / 2

  typography.with("xl", function()
    love.graphics.setColor(0.1, 0.1, 0.1)
    local font = love.graphics.getFont()
    local title = "Set Up Players"
    local tw = font:getWidth(title)
    love.graphics.print(title, (w - tw) / 2, 36)
  end)

  typography.with("sm", function()
    love.graphics.setColor(0.45, 0.45, 0.45)
    local subtitle = "Pick a name and stick-figure color for each player."
    local font = love.graphics.getFont()
    local sw = font:getWidth(subtitle)
    love.graphics.print(subtitle, (w - sw) / 2, 78)
  end)

  for _, row in ipairs(self.rows) do
    typography.with("md", function()
      love.graphics.setColor(0.2, 0.2, 0.2)
      love.graphics.print("P" .. tostring(row.player_idx), x, row.y + (ROW_H - 18) / 2)
    end)
    row.name_input:draw()
    row.color_picker:draw()
  end

  self.back_button:draw()
  self.start_button:draw()
end

local function each_input(self, fn)
  for _, row in ipairs(self.rows) do
    fn(row.name_input)
    fn(row.color_picker)
  end
  fn(self.back_button)
  fn(self.start_button)
end

function M:mousemoved(x, y)
  each_input(self, function(w)
    if w.mousemoved then w:mousemoved(x, y) end
  end)
end

function M:mousepressed(x, y, btn)
  each_input(self, function(w)
    if w.mousepressed then w:mousepressed(x, y, btn) end
  end)
end

function M:mousereleased(x, y, btn)
  each_input(self, function(w)
    if w.mousereleased then w:mousereleased(x, y, btn) end
  end)
end

function M:textinput(text)
  for _, row in ipairs(self.rows) do
    if row.name_input.focused then
      row.name_input:textinput(text)
      return
    end
  end
end

function M:keypressed(key)
  for _, row in ipairs(self.rows) do
    if row.name_input.focused then
      row.name_input:keypressed(key)
      return
    end
  end
  if key == "escape" then
    self.fsm:transition("config")
  elseif key == "return" then
    self.fsm:transition("game")
  end
end

return {
  new = new,
}
```

- [ ] **Step 2: Run the full test suite**

Run: `busted`

Expected: 83 successes / 0 failures.

- [ ] **Step 3: Boot Love to verify**

Run: `timeout 5 love . 2>&1 | head -20`

Expected: no error output.

- [ ] **Step 4: Commit**

```bash
git add src/states/player_setup.lua
git commit -m "$(cat <<'EOF'
Replace player setup placeholder with real screen

One row per player (count comes from session.config.player_count, seeded
by the config screen). Each row: a TextInput for name and a ColorPicker
for stick-figure color. Start Game advances to the game placeholder;
Back returns to config. Return on the keyboard also advances.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: End-to-end manual smoke test

**Files:** none

- [ ] **Step 1: Run the game and walk the full pre-game flow**

Run: `love .`

Walk through:

1. Main menu shows. Click "New Game" → mode_select.
2. Click "The Sprint" → config (real).
3. Confirm widgets render: Company name (TextInput pre-filled "MegaCorp"), preset chip row, Player count Stepper (2), AP Stepper (3), End trigger RadioGroup with 5 options, Comp target Stepper (30), Turn cap Stepper (8), Tier gating Toggle (ON).
4. Click in the Company name field — border turns blue (focused). Type "FAANG Corp" — text appears with a blinking-style cursor. Click outside — defocuses.
5. Click any preset chip — Company name updates to that preset value.
6. Click `+` on Player count — value increments to 3.
7. Click `-` on AP — value decrements to 2.
8. Click a different end-trigger radio — dot moves.
9. Click Tier gating ON indicator — flips to OFF (grey).
10. Click "Continue →" → player_setup screen renders 3 rows (matching player count from step 6).
11. Each row shows P1 / P2 / P3 label, a TextInput pre-filled "Player 1" / "Player 2" / "Player 3", and a ColorPicker with the 8 palette swatches; the 1st / 2nd / 3rd swatch is the selected (thick-bordered) one respectively.
12. Click into P1's name field, backspace out the default, type a new name. The change persists.
13. Click a different color swatch on P2's row — bold border moves to that swatch.
14. Click "Start Game →" → advances to GAME placeholder.
15. Press SPACE → END_SCREEN, press SPACE → back to MENU.
16. From MENU, press Esc → window closes.
17. Restart `love .` and verify:
    - Backstep: go to mode_select → config → player_setup → click Back → returns to config → click Back → returns to mode_select.
    - Resize: at config or player_setup, resize the window. Layout re-centers on resize.
    - Player count change re-seeds players: set count to 5, Continue → 5 rows on player_setup.
    - Player count decrease truncates: set count to 5 in config, give P3 a custom name, set count to 2, Continue → only 2 rows; the P3 record is gone.

If any of these fail, debug before continuing.

- [ ] **Step 2: Full test suite one more time**

Run: `busted`

Expected: 83 successes / 0 failures.

- [ ] **Step 3: No commit (verification only)**

---

### Task 10: Final review

**Files:** none

- [ ] **Step 1: Confirm working tree is clean**

Run: `git status`

Expected: no uncommitted changes (apart from the pre-existing `.claude/` untracked directory).

- [ ] **Step 2: Review the commit log for Plan 3**

Run: `git log --oneline main..HEAD`

Expected: 8 commits on this branch with descriptive messages (Tasks 1–8). Tasks 9–10 are verification only.

- [ ] **Step 3: Confirm final test counts**

Run: `busted`

Expected: 83 successes / 0 failures (29 from Plan 2 baseline + 9 Stepper + 6 Toggle + 7 RadioGroup + 12 TextInput + 8 ColorPicker + 12 Session = 83).

- [ ] **Step 4: Confirm `love .` boots cleanly**

Run: `timeout 4 love . 2>&1 | head -5`

Expected: no error output; clean termination via the timeout.

---

## Done

When all 10 tasks are checked off, this plan is complete. The next plan (Plan 4: Kanban + ticket flow for single-player walkthrough) will start using `session.mode`, `session.config`, and `session.players` to drive gameplay.
