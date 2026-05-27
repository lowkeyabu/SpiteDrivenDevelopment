local Dilemmas = require("src.game.dilemmas")
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

describe("Dilemmas", function()
  it("loads 15 seed cards", function()
    assert.is_equal(15, #Dilemmas.all())
  end)

  it("each card has the required shape", function()
    for _, c in ipairs(Dilemmas.all()) do
      assert.is_string(c.id)
      assert.is_string(c.title)
      assert.is_string(c.setup)
      assert.is_table(c.option_a)
      assert.is_table(c.option_b)
      assert.is_function(c.option_a.effect)
      assert.is_function(c.option_b.effect)
    end
  end)

  it("draw returns a card not in exclude", function()
    local card = Dilemmas.draw(RNG.new(1), { friday_deploy = true })
    assert.is_not_equal("friday_deploy", card.id)
  end)

  it("draw returns nil when all excluded", function()
    local all_excluded = {}
    for _, c in ipairs(Dilemmas.all()) do all_excluded[c.id] = true end
    assert.is_nil(Dilemmas.draw(RNG.new(1), all_excluded))
  end)

  it("resolve applies the chosen option's effect, ls_delta, and humble_brag", function()
    local g = fresh()
    local card = Dilemmas.find("friday_deploy")
    local before_credit = g.players[1].credit
    local before_ls = g.players[1].linkedin_score
    Dilemmas.resolve(g, card, "a")
    assert.is_equal(before_credit + 2, g.players[1].credit)
    assert.is_equal(before_ls + 2, g.players[1].linkedin_score)
    assert.is_equal(1, #g.players[1].humble_brag_log)
    assert.is_true(g.dilemmas_drawn[card.id])
  end)

  it("resolve b on a card with nil humble_brag does not log", function()
    local g = fresh()
    local card = Dilemmas.find("friday_deploy")
    Dilemmas.resolve(g, card, "b")
    assert.is_equal(0, #g.players[1].humble_brag_log)
    assert.is_equal(0, g.players[1].linkedin_score)
  end)

  it("resolve rejects bad choice values", function()
    local g = fresh()
    local card = Dilemmas.find("friday_deploy")
    assert.has_error(function() Dilemmas.resolve(g, card, "c") end)
  end)

  it("GameSession do_meeting grants 2 Clout and spends 1 AP", function()
    local g = fresh()
    local before_clout = g.players[1].clout
    local before_ap = g.players[1].ap
    g:do_meeting()
    assert.is_equal(before_clout + 2, g.players[1].clout)
    assert.is_equal(before_ap - 1, g.players[1].ap)
  end)

  it("humble_brag_log is per-player (not shared)", function()
    local g = fresh()
    Dilemmas.resolve(g, Dilemmas.find("friday_deploy"), "a")
    assert.is_equal(1, #g.players[1].humble_brag_log)
    assert.is_equal(0, #g.players[2].humble_brag_log)
  end)
end)
