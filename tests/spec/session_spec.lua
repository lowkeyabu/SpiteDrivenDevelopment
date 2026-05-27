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
end)
