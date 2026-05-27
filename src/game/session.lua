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
