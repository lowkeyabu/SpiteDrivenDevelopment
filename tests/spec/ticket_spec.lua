local Ticket = require("src.game.ticket")

describe("Ticket", function()
  local function fixture()
    return Ticket.new({
      id = "SDD-042",
      title = "Add dark mode",
      type = "feature",
      points = 2,
      reward = 3,
      modifiers = { promo_magnet = true, glamour = true },
    })
  end

  it("starts in the backlog with all points remaining and no owner", function()
    local t = fixture()
    assert.is_equal("backlog", t.column)
    assert.is_equal(2, t.points_remaining)
    assert.is_nil(t.owner)
    assert.is_nil(t.reviewer)
  end)

  it("claim assigns the owner and moves to in_progress", function()
    local t = fixture()
    t:claim(1)
    assert.is_equal("in_progress", t.column)
    assert.is_equal(1, t.owner)
  end)

  it("claim rejects a non-backlog ticket", function()
    local t = fixture()
    t:claim(1)
    assert.has_error(function() t:claim(2) end)
  end)

  it("work decrements points_remaining (clamped at 0)", function()
    local t = fixture()
    t:claim(1)
    t:work()
    assert.is_equal(1, t.points_remaining)
    t:work()
    assert.is_equal(0, t.points_remaining)
    t:work()
    assert.is_equal(0, t.points_remaining)
  end)

  it("work rejects a ticket not in in_progress", function()
    local t = fixture()
    assert.has_error(function() t:work() end)
  end)

  it("submit_for_review requires points_remaining == 0", function()
    local t = fixture()
    t:claim(1)
    assert.has_error(function() t:submit_for_review() end)
    t:work(); t:work()
    t:submit_for_review()
    assert.is_equal("review", t.column)
  end)

  it("submit_for_review rejects a ticket not in in_progress", function()
    local t = fixture()
    assert.has_error(function() t:submit_for_review() end)
  end)

  it("approve moves a review ticket to done and records the reviewer", function()
    local t = fixture()
    t:claim(1); t:work(); t:work(); t:submit_for_review()
    t:approve(2)
    assert.is_equal("done", t.column)
    assert.is_equal(2, t.reviewer)
  end)

  it("approve rejects a ticket not in review", function()
    local t = fixture()
    assert.has_error(function() t:approve(2) end)
  end)

  it("reject bounces a review ticket back to in_progress with points reset", function()
    local t = fixture()
    t:claim(1); t:work(); t:work(); t:submit_for_review()
    t:reject()
    assert.is_equal("in_progress", t.column)
    assert.is_equal(2, t.points_remaining)
    assert.is_nil(t.reviewer)
  end)

  it("reject rejects a ticket not in review", function()
    local t = fixture()
    assert.has_error(function() t:reject() end)
  end)

  it("has_modifier returns true/false based on the modifiers table", function()
    local t = fixture()
    assert.is_true(t:has_modifier("promo_magnet"))
    assert.is_true(t:has_modifier("glamour"))
    assert.is_false(t:has_modifier("tech_debt"))
  end)
end)
