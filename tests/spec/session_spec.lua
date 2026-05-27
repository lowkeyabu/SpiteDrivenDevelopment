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
