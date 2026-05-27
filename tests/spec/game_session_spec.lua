local GameSession = require("src.game.game_session")
local RNG = require("src.util.rng")
local Session = require("src.game.session")
local Ticket = require("src.game.ticket")

local function ticket_defs()
  return {
    { id = "T1", title = "first",  type = "feature", points = 1, reward = 1 },
    { id = "T2", title = "second", type = "feature", points = 2, reward = 2 },
    { id = "T3", title = "third",  type = "chore",   points = 3, reward = 3 },
    { id = "T4", title = "fourth", type = "chore",   points = 1, reward = 1 },
  }
end

local function fresh()
  local s = Session.new()
  s:set_mode("sprint")
  s:set_player_count(2)
  return GameSession.new({
    session = s,
    ticket_defs = ticket_defs(),
    rng = RNG.new(123),
  })
end

describe("GameSession", function()
  it("populates the backlog from the ticket defs and seeds per-player stats", function()
    local g = fresh()
    g:plan_sprint()
    assert.is_equal(4, #g.backlog)
    assert.is_equal(0, #g.in_progress)
    assert.is_equal(0, #g.review)
    assert.is_equal(0, #g.done)
    assert.is_equal(2, #g.players)
    for _, p in ipairs(g.players) do
      assert.is_equal(0, p.credit)
      assert.is_equal(0, p.clout)
      assert.is_equal(0, p.tech_debt)
      assert.is_equal(0, p.linkedin_score)
      assert.is_equal("IC1", p.title)
    end
  end)

  it("current_actor defaults to player 1 (Plan 4 single-player)", function()
    local g = fresh()
    assert.is_equal(1, g.current_actor)
  end)
end)

describe("GameSession (focused)", function()
  it("claim removes the ticket from backlog and pushes it onto in_progress", function()
    local g = fresh()
    g:plan_sprint()
    local t1 = g.backlog[1]
    g:claim(t1.id)
    assert.is_equal(3, #g.backlog)
    assert.is_equal(1, #g.in_progress)
    assert.is_equal(t1.id, g.in_progress[1].id)
    assert.is_equal("in_progress", g.in_progress[1].column)
    assert.is_equal(1, g.in_progress[1].owner)
  end)

  it("claim raises when the id is not in the backlog", function()
    local g = fresh()
    g:plan_sprint()
    assert.has_error(function() g:claim("MISSING") end)
  end)

  it("work decrements points_remaining on a ticket the actor owns", function()
    local g = fresh()
    g:plan_sprint()
    g:claim("T2")
    g:work("T2")
    assert.is_equal(1, g.in_progress[1].points_remaining)
    g:work("T2")
    assert.is_equal(0, g.in_progress[1].points_remaining)
  end)

  it("work raises when the ticket is not owned by the actor", function()
    local g = fresh()
    g:plan_sprint()
    g:claim("T1")
    g.current_actor = 2
    assert.has_error(function() g:work("T1") end)
  end)

  it("submit_for_review moves a 0-point in_progress ticket to review", function()
    local g = fresh()
    g:plan_sprint()
    g:claim("T1")
    g:work("T1")
    g:submit_for_review("T1")
    assert.is_equal(0, #g.in_progress)
    assert.is_equal(1, #g.review)
    assert.is_equal("T1", g.review[1].id)
  end)

  it("approve moves a review ticket to done and credits owner + reviewer", function()
    local g = fresh()
    g:plan_sprint()
    g:claim("T2")
    g:work("T2"); g:work("T2") -- p1 out of AP
    g:end_turn() -- p2 idle (no AP for p1 ticket)
    g:end_turn() -- p1 again, AP refreshed
    g:submit_for_review("T2")
    g:end_turn() -- player 2 reviews
    g:approve("T2")
    assert.is_equal(0, #g.review)
    assert.is_equal(1, #g.done)
    assert.is_equal("T2", g.done[1].id)
    assert.is_equal(2, g.players[1].credit) -- owner reward
    assert.is_equal(1, g.players[2].credit) -- reviewer +1
  end)

  it("reject sends the ticket back to in_progress with points reset", function()
    local g = fresh()
    g:plan_sprint()
    g:claim("T2")
    g:work("T2"); g:work("T2") -- p1 out of AP
    g:end_turn() -- p2 idle
    g:end_turn() -- p1 again, AP refreshed
    g:submit_for_review("T2")
    g:end_turn()
    g:reject("T2")
    assert.is_equal(0, #g.review)
    assert.is_equal(1, #g.in_progress)
    assert.is_equal("T2", g.in_progress[1].id)
    assert.is_equal(2, g.in_progress[1].points_remaining)
  end)

  it("find finds a ticket by id across all columns", function()
    local g = fresh()
    g:plan_sprint()
    local t = g:find("T3")
    assert.is_not_nil(t)
    assert.is_equal("T3", t.id)
    g:claim("T3")
    t = g:find("T3")
    assert.is_equal("in_progress", t.column)
  end)

  it("returns nil when finding an unknown id", function()
    local g = fresh()
    assert.is_nil(g:find("MISSING"))
  end)

  it("shipped_count returns the number of tickets in done", function()
    local g = fresh()
    g:plan_sprint()
    assert.is_equal(0, g:shipped_count())
    g:claim("T1"); g:work("T1"); g:submit_for_review("T1")
    g:end_turn()
    g:approve("T1")
    assert.is_equal(1, g:shipped_count())
  end)

  it("seeds each player with config.ap_per_turn AP", function()
    local g = fresh()
    assert.is_equal(3, g.players[1].ap)
    assert.is_equal(3, g.players[2].ap)
    assert.is_equal(1, g.turn_count)
  end)

  it("claim decrements the actor's AP by 1", function()
    local g = fresh()
    g:plan_sprint()
    assert.is_equal(3, g.players[1].ap)
    g:claim("T1")
    assert.is_equal(2, g.players[1].ap)
  end)

  it("work decrements AP by 1 per call", function()
    local g = fresh()
    g:plan_sprint()
    g:claim("T2")
    g:work("T2")
    g:work("T2")
    assert.is_equal(0, g.players[1].ap)
  end)

  it("action raises when actor has no AP", function()
    local g = fresh()
    g:plan_sprint()
    g:claim("T1")
    g:work("T1")
    g:submit_for_review("T1")
    assert.has_error(function() g:claim("T2") end)
  end)

  it("end_turn advances current_actor and refreshes the new actor's AP", function()
    local g = fresh()
    g:plan_sprint()
    g:claim("T1")
    g:end_turn()
    assert.is_equal(2, g.current_actor)
    assert.is_equal(3, g.players[2].ap)
    assert.is_equal(2, g.turn_count)
  end)

  it("end_turn wraps around at the last player", function()
    local g = fresh()
    g:plan_sprint()
    g:end_turn()
    g:end_turn()
    assert.is_equal(1, g.current_actor)
    assert.is_equal(3, g.turn_count)
  end)

  it("end_turn refreshes the new actor's AP even if it was nonzero", function()
    local g = fresh()
    g:plan_sprint()
    g:claim("T1")
    g.players[2].ap = 1
    g:end_turn()
    assert.is_equal(3, g.players[2].ap)
  end)

  it("approve requires reviewer != ticket owner", function()
    local g = fresh()
    g:plan_sprint()
    g:claim("T1")
    g:work("T1")
    g:submit_for_review("T1")
    assert.has_error(function() g:approve("T1") end)
    g:end_turn()
    g:approve("T1")
    assert.is_equal(1, g.players[1].credit)
    assert.is_equal(1, g.players[2].credit)
  end)

  it("reject requires reviewer != ticket owner", function()
    local g = fresh()
    g:plan_sprint()
    g:claim("T2")
    g:work("T2"); g:work("T2") -- p1 out of AP
    g:end_turn() -- p2 idle
    g:end_turn() -- p1 again, AP refreshed
    g:submit_for_review("T2")
    assert.has_error(function() g:reject("T2") end)
    g:end_turn()
    g:reject("T2")
    assert.is_equal(1, #g.in_progress)
  end)

  it("starts in planning phase with sprint_number = 1 and empty backlog", function()
    local g = fresh()
    assert.is_equal("planning", g.sprint_phase)
    assert.is_equal(1, g.sprint_number)
    assert.is_equal(0, #g.backlog)
  end)

  it("plan_sprint draws 2 * player_count tickets into the backlog", function()
    local g = fresh()
    g:plan_sprint()
    assert.is_equal(4, #g.backlog)
    assert.is_equal("turns", g.sprint_phase)
  end)

  it("actions raise outside the turns phase", function()
    local g = fresh()
    assert.has_error(function() g:claim("anything") end)
  end)

  it("end_turn transitions to retro when sprint_should_end", function()
    local g = fresh()
    g:plan_sprint()
    g.sprint_turn_count = g.session.config.turn_cap
    g:end_turn()
    assert.is_equal("retro", g.sprint_phase)
  end)

  it("retro_and_promote advances the top shipper's title", function()
    local g = fresh()
    g:plan_sprint()
    g.players[1].sprint_shipped = 3
    g.players[2].sprint_shipped = 1
    g.sprint_phase = "retro"
    g:retro_and_promote()
    assert.is_equal("IC2", g.players[1].title)
    assert.is_equal("IC1", g.players[2].title)
  end)

  it("retro_and_promote with no shipped players does not promote", function()
    local g = fresh()
    g:plan_sprint()
    g.sprint_phase = "retro"
    g:retro_and_promote()
    assert.is_equal("IC1", g.players[1].title)
  end)

  it("end_trigger_fired detects fixed_5_sprints after 5 sprints", function()
    local g = fresh()
    g.session.config.end_trigger = "fixed_n_sprints_5"
    g.sprint_number = 5
    local fired = g:end_trigger_fired()
    assert.is_true(fired)
  end)

  it("end_trigger_fired detects first_to_comp_target", function()
    local g = fresh()
    g.session.config.end_trigger = "first_to_comp_target"
    g.session.config.comp_target = 10
    g.players[1].credit = 12
    local fired = g:end_trigger_fired()
    assert.is_true(fired)
  end)

  it("end_trigger_fired detects first_to_csuite_or_5_sprints by csuite", function()
    local g = fresh()
    g.players[1].title = "C-suite"
    local fired = g:end_trigger_fired()
    assert.is_true(fired)
  end)

  it("advance_phase from planning runs plan_sprint", function()
    local g = fresh()
    g:advance_phase()
    assert.is_equal("turns", g.sprint_phase)
    assert.is_equal(4, #g.backlog)
  end)

  it("advance_phase from retro promotes, increments sprint_number, replans or ends", function()
    local g = fresh()
    g:plan_sprint()
    g.players[1].sprint_shipped = 1
    g.sprint_phase = "retro"
    g:advance_phase()
    assert.is_equal("IC2", g.players[1].title)
    assert.is_equal(2, g.sprint_number)
    -- Fixture has only 4 tickets, plan_sprint drew them all, so deck is empty.
    assert.is_true(g.ended)
  end)
end)
