-- Seed sabotage deck — 12 cards across 4 tiers per spec §8.4.

local Session = require("src.game.session")

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
      gs.players[target.player_idx].snitched_on = true
    end,
  },
  {
    id = "credit_steal",
    name = '"Credit where credit is due."',
    tier = 2, clout = 3, ls_delta = 2,
    target = "ticket",
    flavor = "Steal 2 Credit from a ticket you approved this sprint.",
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
    flavor = "Move 2 Tech Debt onto target ticket's owner.",
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
      gs.rto_pending = (gs.rto_pending or 0) + 2
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
  -- Plan 10 expansion: 8 more cards (2 per tier) using existing effect patterns.
  {
    id = "scope_creep",
    name = '"Quick question — can we also..."',
    tier = 1, clout = 1, ls_delta = 1,
    target = "player",
    flavor = "Target loses 1 AP on next turn (scope creep ate it).",
    effect = function(gs, actor_idx, target)
      local p = gs.players[target.player_idx]
      p.ap = math.max(0, p.ap - 1)
    end,
  },
  {
    id = "calendar_bomb",
    name = '"Putting time on your calendar."',
    tier = 1, clout = 2, ls_delta = 1,
    target = "player",
    flavor = "Target loses 1 AP next turn. You +1 Clout (relationship building).",
    effect = function(gs, actor_idx, target)
      local p = gs.players[target.player_idx]
      p.ap = math.max(0, p.ap - 1)
      gs.players[actor_idx].clout = gs.players[actor_idx].clout + 1
    end,
  },
  {
    id = "ooo_lunch",
    name = '"Stepping out for a long lunch."',
    tier = 2, clout = 2, ls_delta = 2,
    target = "all",
    flavor = "All other players lose 1 AP. You +1 Clout.",
    effect = function(gs, actor_idx, target)
      for i, p in ipairs(gs.players) do
        if i ~= actor_idx then p.ap = math.max(0, p.ap - 1) end
      end
      gs.players[actor_idx].clout = gs.players[actor_idx].clout + 1
    end,
  },
  {
    id = "fake_oncall",
    name = '"Sorry, on-call paging me."',
    tier = 2, clout = 3, ls_delta = 2,
    target = "none",
    flavor = "You skip the rest of this turn but gain 3 Clout (incident response).",
    effect = function(gs, actor_idx, target)
      local p = gs.players[actor_idx]
      p.clout = p.clout + 3
      p.ap = 0
    end,
  },
  {
    id = "calibration_leak",
    name = '"Heard about your calibration."',
    tier = 3, clout = 5, ls_delta = 3,
    target = "player",
    flavor = "Drain 2 Clout from target. You +1 Clout.",
    effect = function(gs, actor_idx, target)
      local p = gs.players[target.player_idx]
      local amount = math.min(2, p.clout)
      p.clout = p.clout - amount
      gs.players[actor_idx].clout = gs.players[actor_idx].clout + 1
    end,
  },
  {
    id = "weekend_oncall_assign",
    name = '"You\'re on-call this weekend."',
    tier = 3, clout = 4, ls_delta = 3,
    target = "player",
    flavor = "Target loses 2 AP next turn.",
    effect = function(gs, actor_idx, target)
      local p = gs.players[target.player_idx]
      p.ap = math.max(0, p.ap - 2)
    end,
  },
  {
    id = "promotion_freeze",
    name = '"Promotion freeze this cycle."',
    tier = 4, clout = 8, ls_delta = 5,
    target = "all",
    flavor = "All other players' titles are frozen for this sprint.",
    effect = function(gs, actor_idx, target)
      for i, p in ipairs(gs.players) do
        if i ~= actor_idx then p.title_frozen = true end
      end
    end,
  },
  {
    id = "acquisition_rumor",
    name = '"Heard we\'re being acquired."',
    tier = 4, clout = 7, ls_delta = 4,
    target = "all",
    flavor = "Every other player loses half their Clout (rounded down). You +2 Clout.",
    effect = function(gs, actor_idx, target)
      for i, p in ipairs(gs.players) do
        if i ~= actor_idx then p.clout = math.floor(p.clout / 2) end
      end
      gs.players[actor_idx].clout = gs.players[actor_idx].clout + 2
    end,
  },
}
