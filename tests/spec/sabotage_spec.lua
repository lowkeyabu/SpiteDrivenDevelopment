local Sabotage = require("src.game.sabotage")
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

describe("Sabotage", function()
  it("loads the 12 seed cards", function()
    local cards = Sabotage.all()
    assert.is_equal(12, #cards)
    for _, c in ipairs(cards) do
      assert.is_string(c.id)
      assert.is_string(c.name)
      assert.is_number(c.tier)
      assert.is_number(c.clout)
      assert.is_number(c.ls_delta)
      assert.is_string(c.target)
      assert.is_function(c.effect)
    end
  end)

  it("available_for filters by tier when tier_gating is ON", function()
    local g = fresh()
    g.session.config.tier_gating = true
    g.players[1].title = "IC1"
    local avail = Sabotage.available_for(g)
    for _, c in ipairs(avail) do
      assert.is_equal(1, c.tier)
    end
  end)

  it("available_for returns all cards when tier_gating is OFF", function()
    local g = fresh()
    g.session.config.tier_gating = false
    local avail = Sabotage.available_for(g)
    assert.is_equal(12, #avail)
  end)

  it("can_afford checks Clout balance", function()
    local g = fresh()
    local cheap = Sabotage.find("ic_concerns")
    g.players[1].clout = 0
    assert.is_false(Sabotage.can_afford(g, cheap))
    g.players[1].clout = 10
    assert.is_true(Sabotage.can_afford(g, cheap))
  end)

  it("play deducts Clout and adds LS to actor", function()
    local g = fresh()
    g:claim("T1"); g:work("T1"); g:submit_for_review("T1")
    g:end_turn()
    g.players[2].clout = 5
    local before_clout = g.players[2].clout
    local before_ls = g.players[2].linkedin_score
    local card = Sabotage.find("ic_concerns")
    Sabotage.play(g, card.id, { ticket_id = "T1" })
    assert.is_equal(before_clout - card.clout, g.players[2].clout)
    assert.is_equal(before_ls + card.ls_delta, g.players[2].linkedin_score)
  end)

  it("play raises when actor cannot afford", function()
    local g = fresh()
    g:claim("T1"); g:work("T1"); g:submit_for_review("T1")
    g:end_turn()
    g.players[2].clout = 0
    local card = Sabotage.find("ic_concerns")
    assert.has_error(function()
      Sabotage.play(g, card.id, { ticket_id = "T1" })
    end)
  end)

  it("ic_concerns effect rejects the target ticket back to in_progress", function()
    local g = fresh()
    g:claim("T1"); g:work("T1"); g:submit_for_review("T1")
    g:end_turn()
    g.players[2].clout = 5
    Sabotage.play(g, "ic_concerns", { ticket_id = "T1" })
    assert.is_equal(0, #g.review)
    assert.is_equal(1, #g.in_progress)
    assert.is_equal("T1", g.in_progress[1].id)
  end)

  it("quick_sync effect drains 1 AP from the target player", function()
    local g = fresh()
    g.players[1].clout = 5
    local before_ap = g.players[2].ap
    Sabotage.play(g, "quick_sync", { player_idx = 2 })
    assert.is_equal(before_ap - 1, g.players[2].ap)
  end)

  it("sev1_all_hands drains 2 AP from every other player", function()
    local g = fresh()
    g.players[1].clout = 10
    local before_ap_2 = g.players[2].ap
    Sabotage.play(g, "sev1_all_hands", {})
    assert.is_equal(before_ap_2 - 2, g.players[2].ap)
  end)

  it("pip freezes the target's title (sets a frozen flag)", function()
    local g = fresh()
    g.players[1].clout = 10
    Sabotage.play(g, "pip", { player_idx = 2 })
    assert.is_true(g.players[2].title_frozen)
  end)

  it("fire drops the target's title by 2 rungs", function()
    local g = fresh()
    g.players[1].clout = 20
    g.players[2].title = "Director"
    Sabotage.play(g, "fire", { player_idx = 2 })
    assert.is_equal("Manager", g.players[2].title)
  end)

  it("fire clamps at IC1", function()
    local g = fresh()
    g.players[1].clout = 20
    g.players[2].title = "IC1"
    Sabotage.play(g, "fire", { player_idx = 2 })
    assert.is_equal("IC1", g.players[2].title)
  end)
end)
