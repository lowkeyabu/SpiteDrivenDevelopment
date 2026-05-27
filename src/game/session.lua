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
      color = i,
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
