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
  {
    id = "diversity_panel",
    title = "The Diversity Panel",
    setup = "VP asks you to speak on the company's all-male engineering leadership panel. The optics matter to them.",
    option_a = {
      pitch = "Accept. The exposure helps your career.",
      effect = function(gs, idx) gs.players[idx].clout = gs.players[idx].clout + 3 end,
      ls_delta = 4,
      humble_brag = '"Honored to be part of a candid conversation about engineering leadership today. Representation matters and I\'m grateful to be in the room."',
    },
    option_b = {
      pitch = "Decline. Suggest someone better suited.",
      effect = function(gs, idx) end,
      ls_delta = 0,
      humble_brag = nil,
    },
  },
  {
    id = "burnout_friend",
    title = "Your Friend's Burnout",
    setup = "A friend on your team is clearly burned out. They confide in you. Your manager asks if you have concerns about anyone's performance.",
    option_a = {
      pitch = "Mention them as 'struggling'. Cover yourself.",
      effect = function(gs, idx) gs.players[idx].clout = gs.players[idx].clout + 2 end,
      ls_delta = 4,
      humble_brag = '"Mental health is real. So is accountability. As a manager-adjacent IC, I take both seriously."',
    },
    option_b = {
      pitch = "Stay quiet. Help them through it.",
      effect = function(gs, idx) end,
      ls_delta = 0,
      humble_brag = nil,
    },
  },
  {
    id = "incident_blame",
    title = "Postmortem Blame",
    setup = "Postmortem after an outage. The actual cause was a process gap, but there's an obvious junior to blame.",
    option_a = {
      pitch = "Name the junior. Process gaps are abstract.",
      effect = function(gs, idx) gs.players[idx].credit = gs.players[idx].credit + 2 end,
      ls_delta = 5,
      humble_brag = '"Blameless postmortems are aspirational. Accountability is real. Our team is stronger today than yesterday."',
    },
    option_b = {
      pitch = "Document the process gap honestly.",
      effect = function(gs, idx) end,
      ls_delta = 0,
      humble_brag = nil,
    },
  },
  {
    id = "open_source_creds",
    title = "Open Source Credit",
    setup = "Your team's contribution to an OSS project is being recognized. The team did the work; you wrote one paragraph.",
    option_a = {
      pitch = "Accept the speaking invitation alone.",
      effect = function(gs, idx) gs.players[idx].credit = gs.players[idx].credit + 2 end,
      ls_delta = 4,
      humble_brag = '"Excited to share that I\'ll be representing my team\'s open-source contributions at next month\'s conference. Standing on the shoulders of giants."',
    },
    option_b = {
      pitch = "Bring the actual contributors with you.",
      effect = function(gs, idx) gs.players[idx].clout = gs.players[idx].clout + 1 end,
      ls_delta = 0,
      humble_brag = nil,
    },
  },
  {
    id = "salary_band_leak",
    title = "Salary Band Leak",
    setup = "Someone leaks the salary bands in a private Slack. You learn three coworkers are underpaid relative to you. HR asks who shared it.",
    option_a = {
      pitch = "Name the leaker. Restore the natural order.",
      effect = function(gs, idx) gs.players[idx].clout = gs.players[idx].clout + 2 end,
      ls_delta = 4,
      humble_brag = '"Pay transparency is a noble goal but must be approached responsibly. Grateful for HR\'s thoughtful handling of a sensitive issue."',
    },
    option_b = {
      pitch = '"No idea."',
      effect = function(gs, idx) end,
      ls_delta = 0,
      humble_brag = nil,
    },
  },
  {
    id = "ic_track_kill",
    title = "The IC Track",
    setup = "Your skip-level mentions casually that the IC track caps below where your manager-track friend will end up. You can advocate for the IC track or stay quiet.",
    option_a = {
      pitch = "Pivot to manager. Higher ceiling.",
      effect = function(gs, idx) gs.players[idx].credit = gs.players[idx].credit + 3 end,
      ls_delta = 4,
      humble_brag = '"After much reflection, I\'m thrilled to share I\'m moving into engineering management. Excited to multiply my impact through my team."',
    },
    option_b = {
      pitch = "Advocate for raising the IC ceiling.",
      effect = function(gs, idx) end,
      ls_delta = 0,
      humble_brag = nil,
    },
  },
  {
    id = "vendor_dinner",
    title = "Vendor Dinner",
    setup = "A vendor invites you and two reports to a $500/person dinner. Policy is grey; your VP would approve quietly.",
    option_a = {
      pitch = "Go. It's networking.",
      effect = function(gs, idx) gs.players[idx].clout = gs.players[idx].clout + 2 end,
      ls_delta = 3,
      humble_brag = '"Vendor relationships are partnerships. Investing in them is investing in your team. Grateful for tonight\'s deep conversation about emerging trends."',
    },
    option_b = {
      pitch = "Decline politely.",
      effect = function(gs, idx) end,
      ls_delta = 0,
      humble_brag = nil,
    },
  },
  {
    id = "h1b_threat",
    title = "Visa Threat",
    setup = "A teammate on H1B is hesitating on a promo opportunity. You know their hesitation costs you nothing and helps you stand out.",
    option_a = {
      pitch = "Don't mention the visa angle. Take the spotlight.",
      effect = function(gs, idx) gs.players[idx].credit = gs.players[idx].credit + 3 end,
      ls_delta = 5,
      humble_brag = '"Stepping up when the moment calls is what growth looks like. Honored to take on a larger scope and grateful to the leadership that trusted me."',
    },
    option_b = {
      pitch = "Acknowledge it and split the opportunity.",
      effect = function(gs, idx) end,
      ls_delta = 0,
      humble_brag = nil,
    },
  },
  {
    id = "linkedin_post",
    title = "The LinkedIn Post",
    setup = "A laid-off coworker reaches out asking for a referral. You barely worked with them. A quick LinkedIn endorsement would help.",
    option_a = {
      pitch = "Decline. You're 'in too many meetings'.",
      effect = function(gs, idx) gs.players[idx].clout = gs.players[idx].clout + 1 end,
      ls_delta = 3,
      humble_brag = '"My biggest lesson from this quarter is the importance of focus. Saying no to good opportunities so I can say yes to great ones."',
    },
    option_b = {
      pitch = "Endorse them honestly.",
      effect = function(gs, idx) end,
      ls_delta = 0,
      humble_brag = nil,
    },
  },
}
