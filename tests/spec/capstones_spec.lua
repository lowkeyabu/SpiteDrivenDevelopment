local Capstones = require("src.game.capstones")
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

describe("Capstones", function()
  it("loads one card per archetype (6 total)", function()
    local cards = Capstones.all()
    assert.is_equal(6, #cards)
    local by_arch = {}
    for _, c in ipairs(cards) do by_arch[c.archetype] = c end
    assert.is_not_nil(by_arch.ladder_climber)
    assert.is_not_nil(by_arch.snitch)
    assert.is_not_nil(by_arch.credit_thief)
    assert.is_not_nil(by_arch.debt_dumper)
    assert.is_not_nil(by_arch.meeting_farmer)
    assert.is_not_nil(by_arch.clean_operator)
  end)

  it("classify returns clean_operator when all counters are zero", function()
    local p = { archetype_counters = {}, linkedin_score = 0 }
    assert.is_equal("clean_operator", Capstones.classify(p))
  end)

  it("classify returns the dominant archetype", function()
    local p = { archetype_counters = { ladder_climber = 5, snitch = 2 }, linkedin_score = 0 }
    assert.is_equal("ladder_climber", Capstones.classify(p))
  end)

  it("draw_for returns the matching capstone", function()
    local c = Capstones.draw_for("snitch")
    assert.is_equal("snitch", c.archetype)
  end)

  it("draw_for falls back to clean_operator for unknown archetype", function()
    local c = Capstones.draw_for("invented_archetype")
    assert.is_equal("clean_operator", c.archetype)
  end)

  it("resolve applies effect, ls_delta, humble_brag, and marks capstone_done", function()
    local g = fresh()
    local card = Capstones.draw_for("ladder_climber")
    local before_credit = g.players[1].credit
    local before_ls = g.players[1].linkedin_score
    Capstones.resolve(g, 1, card, "a")
    assert.is_equal(before_credit + 10, g.players[1].credit)
    assert.is_equal(before_ls + 8, g.players[1].linkedin_score)
    assert.is_equal(1, #g.players[1].humble_brag_log)
    assert.is_true(g.players[1].capstone_done)
  end)

  it("clean_operator capstone has option_b as the spite move", function()
    local g = fresh()
    local card = Capstones.draw_for("clean_operator")
    Capstones.resolve(g, 1, card, "b")
    assert.is_equal(4, g.players[1].linkedin_score)
    assert.is_equal(1, #g.players[1].humble_brag_log)
  end)

  it("clean_operator capstone option_a (virtuous) generates no log", function()
    local g = fresh()
    local card = Capstones.draw_for("clean_operator")
    Capstones.resolve(g, 1, card, "a")
    assert.is_equal(0, g.players[1].linkedin_score)
    assert.is_equal(0, #g.players[1].humble_brag_log)
  end)

  it("sabotage plays bump archetype counters", function()
    local g = fresh()
    g.players[1].clout = 20
    local t = g:find("T1"); t.owner = 2
    local Sabotage = require("src.game.sabotage")
    Sabotage.play(g, "credit_steal", { ticket_id = "T1" })
    assert.is_equal(1, g.players[1].archetype_counters.saboteur)
    assert.is_equal(1, g.players[1].archetype_counters.credit_thief)
  end)

  it("meeting bumps the meeting_farmer counter", function()
    local g = fresh()
    g:do_meeting()
    assert.is_equal(1, g.players[1].archetype_counters.meeting_farmer)
  end)
end)
