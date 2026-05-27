-- Spec §9.5 seed deck. 6 cards. Each option's effect(gs, actor_idx)
-- mutates the game session. humble_brag is nil for "clean" options.

return {
  {
    id = "friday_deploy",
    title = "Friday Deploy",
    setup = "It's 4:55 PM Friday. The feature is 90% ready. Push it now or wait until Monday.",
    option_a = {
      pitch = "Push it now. Ship it.",
      effect = function(gs, idx)
        local p = gs.players[idx]
        p.credit = p.credit + 2
        p.tech_debt = p.tech_debt + 3
      end,
      ls_delta = 2,
      humble_brag = '"Shipped late Friday because that\'s what shipping feels like. No safety net, just vibes. Grateful for a team that trusts me to make the call."',
    },
    option_b = {
      pitch = "Wait until Monday. Proper rollout.",
      effect = function(gs, idx) end,
      ls_delta = 0,
      humble_brag = nil,
    },
  },
  {
    id = "layoff_list",
    title = "The Layoff List",
    setup = "VP asks for names for the next RIF. You have: 1 senior friend, 5 quiet juniors.",
    option_a = {
      pitch = "Name the juniors. Numbers, not names.",
      effect = function(gs, idx)
        local p = gs.players[idx]
        p.credit = p.credit + 1
        p.clout = p.clout + 2
      end,
      ls_delta = 5,
      humble_brag = '"Had to make some difficult but necessary decisions this week. Grateful to the team members whose contributions helped us get here. Wishing them the best in their next chapter."',
    },
    option_b = {
      pitch = 'Refuse. "Not my job."',
      effect = function(gs, idx)
        gs.players[idx].clout = math.max(0, gs.players[idx].clout - 2)
      end,
      ls_delta = 0,
      humble_brag = nil,
    },
  },
  {
    id = "pr_review_11pm",
    title = "PR Review at 11 PM",
    setup = "Your friend's PR has a subtle bug. Their promo decision is in 12 hours.",
    option_a = {
      pitch = "Approve it. They'd do the same for me.",
      effect = function(gs, idx)
        local p = gs.players[idx]
        p.clout = p.clout + 1
        p.tech_debt = p.tech_debt + 2
      end,
      ls_delta = 3,
      humble_brag = '"Reminder: trust is the ultimate leverage. Approved a teammate\'s PR today without ceremony. Relationships > gatekeeping."',
    },
    option_b = {
      pitch = "Request changes. Standards matter.",
      effect = function(gs, idx) end,
      ls_delta = 2,
      humble_brag = '"Defended code quality by requesting changes on a teammate\'s PR this week. Excellence isn\'t built by lowering the bar."',
    },
  },
  {
    id = "ai_training_data",
    title = "AI Training Data",
    setup = "The new AI feature is scraping customer data without consent. You found out. Launch is tomorrow.",
    option_a = {
      pitch = "Ship anyway. Iterate and apologize later.",
      effect = function(gs, idx)
        gs.players[idx].credit = gs.players[idx].credit + 4
      end,
      ls_delta = 5,
      humble_brag = '"Shipping thoughtfully and iterating is how innovation gets done. Proud of the team for launching our AI-powered personalization feature today!"',
    },
    option_b = {
      pitch = "Flag to legal. Compliance first.",
      effect = function(gs, idx)
        gs.players[idx].credit = math.max(0, gs.players[idx].credit - 2)
      end,
      ls_delta = 0,
      humble_brag = nil,
    },
  },
  {
    id = "rto_snitch",
    title = "RTO Snitch Bonus",
    setup = "Slack shows your WFH-full-time coworker at a cafe. Management's offering bonuses for \"culture reports.\"",
    option_a = {
      pitch = "Report them. Accountability is teamwork.",
      effect = function(gs, idx)
        gs.players[idx].clout = gs.players[idx].clout + 3
      end,
      ls_delta = 4,
      humble_brag = '"Culture is built, not assumed. Proud of our in-person collaboration and the shared responsibility we all hold."',
    },
    option_b = {
      pitch = "Stay silent. Not your business.",
      effect = function(gs, idx) end,
      ls_delta = 0,
      humble_brag = nil,
    },
  },
  {
    id = "intern_feature",
    title = "The Intern's Feature",
    setup = "Your intern wrote 80% of the feature. Demo is at All-Hands tomorrow.",
    option_a = {
      pitch = "Present it as yours. Mentorship includes storytelling.",
      effect = function(gs, idx)
        gs.players[idx].credit = gs.players[idx].credit + 3
      end,
      ls_delta = 3,
      humble_brag = '"Incredibly proud of the work my team has done this quarter. Innovation happens when leaders empower their reports — and tell their story well."',
    },
    option_b = {
      pitch = "Credit the intern publicly.",
      effect = function(gs, idx)
        gs.players[idx].clout = gs.players[idx].clout + 1
      end,
      ls_delta = 0,
      humble_brag = nil,
    },
  },
}
