-- Capstone Dilemma cards (spec §10 / capstone_framework memory).
-- Shape matches data/dilemmas.lua but with archetype tag and amplified
-- ls_delta.

return {
  {
    id = "ladder_climber_succession",
    archetype = "ladder_climber",
    title = "The Succession Memo",
    setup = "The CEO announces retirement next quarter. Your name's on the shortlist — along with the one colleague who's been carrying the team while you climbed. A leaked memo could tank their chances.",
    option_a = {
      pitch = "Leak the memo. Clear the field.",
      effect = function(gs, idx)
        gs.players[idx].credit = gs.players[idx].credit + 10
      end,
      ls_delta = 8,
      humble_brag = '"Leadership requires the hard conversations nobody else will have. Grateful for the trust my board has placed in me as I step into this new role."',
    },
    option_b = {
      pitch = "Let them compete fairly.",
      effect = function(gs, idx) end,
      ls_delta = 0,
      humble_brag = nil,
    },
  },
  {
    id = "snitch_exit_interview",
    archetype = "snitch",
    title = "The Exit Interview",
    setup = "HR asks: \"Before you leave MegaCorp, do you have any concerns about team culture you'd like to document? Your former manager is under review.\"",
    option_a = {
      pitch = "Document everything you saw — and some things you didn't.",
      effect = function(gs, idx)
        gs.players[idx].clout = gs.players[idx].clout + 5
      end,
      ls_delta = 7,
      humble_brag = '"Culture accountability is a lifelong practice. Grateful to the HR partner who trusted my perspective during a challenging leadership transition."',
    },
    option_b = {
      pitch = '"Nothing to report."',
      effect = function(gs, idx) end,
      ls_delta = 0,
      humble_brag = nil,
    },
  },
  {
    id = "credit_thief_book_deal",
    archetype = "credit_thief",
    title = "The Book Deal",
    setup = "A publisher wants the founding story of the product you (mostly) launched. The team's hard work is real; the byline is yours alone.",
    option_a = {
      pitch = "Take the byline. They'd do the same.",
      effect = function(gs, idx)
        gs.players[idx].credit = gs.players[idx].credit + 8
      end,
      ls_delta = 7,
      humble_brag = '"Thrilled to announce my new book — a candid look at the human side of innovation. Grateful to everyone who supported me on this journey."',
    },
    option_b = {
      pitch = "Share authorship.",
      effect = function(gs, idx) end,
      ls_delta = 0,
      humble_brag = nil,
    },
  },
  {
    id = "debt_dumper_postmortem",
    archetype = "debt_dumper",
    title = "The Postmortem",
    setup = "Production is on fire because of the system you owned but never refactored. The postmortem asks: name a root cause.",
    option_a = {
      pitch = "Name your junior. They wrote some of the code.",
      effect = function(gs, idx)
        gs.players[idx].credit = gs.players[idx].credit + 6
      end,
      ls_delta = 6,
      humble_brag = '"Owning the room when things go wrong is part of growth. Proud of how my team showed up during a difficult production incident this week."',
    },
    option_b = {
      pitch = "Own it. Document the systemic causes.",
      effect = function(gs, idx) end,
      ls_delta = 0,
      humble_brag = nil,
    },
  },
  {
    id = "meeting_farmer_calendar",
    archetype = "meeting_farmer",
    title = "The Calendar Audit",
    setup = "The new CEO is auditing calendars. Yours has 47 recurring meetings, mostly with executives. None has shipped a deliverable in 6 months.",
    option_a = {
      pitch = "Defend every meeting as 'strategic alignment'.",
      effect = function(gs, idx)
        gs.players[idx].clout = gs.players[idx].clout + 6
      end,
      ls_delta = 6,
      humble_brag = '"Strategic alignment isn\'t glamorous, but it\'s what keeps a company moving in one direction. Proud of the relationships I\'ve built across the org."',
    },
    option_b = {
      pitch = "Cancel half. Get back to work.",
      effect = function(gs, idx) end,
      ls_delta = 0,
      humble_brag = nil,
    },
  },
  {
    id = "clean_operator_one_last_time",
    archetype = "clean_operator",
    title = "One Last Story Point",
    setup = "It's the last sprint. A coworker's critical feature is stuck in Review. Approving it would cost you nothing, but their promo is tied to it. They've never helped you. Nobody's watching.",
    option_a = {
      pitch = "Approve it. Nobody has to know you're nice.",
      effect = function(gs, idx) end,
      ls_delta = 0,
      humble_brag = nil,
    },
    option_b = {
      pitch = "Let it rot in Review one more turn.",
      effect = function(gs, idx)
        gs.players[idx].credit = gs.players[idx].credit + 2
      end,
      ls_delta = 4,
      humble_brag = '"Boundaries are the scaffolding of excellence. Sometimes the kindest thing you can do is let someone sit with their work a little longer."',
    },
  },
  {
    id = "ladder_climber_board_seat",
    archetype = "ladder_climber",
    title = "The Board Seat",
    setup = "A startup you advised offers you a board seat — and a vote on cutting the founding engineer who built the product. You'd vote with the new VC.",
    option_a = {
      pitch = "Vote yes. The numbers don't lie.",
      effect = function(gs, idx) gs.players[idx].credit = gs.players[idx].credit + 8 end,
      ls_delta = 7,
      humble_brag = '"Honored to join the board of [stealth-mode startup]. Stewardship at the boundary of innovation and discipline is what builds enduring companies."',
    },
    option_b = {
      pitch = "Abstain. Founders matter.",
      effect = function(gs, idx) end,
      ls_delta = 0,
      humble_brag = nil,
    },
  },
  {
    id = "snitch_glassdoor",
    archetype = "snitch",
    title = "The Glassdoor Review",
    setup = "An ex-coworker writes a 1-star Glassdoor review naming names. PR asks you to write a counter-review.",
    option_a = {
      pitch = "Write the counter. Glowing.",
      effect = function(gs, idx) gs.players[idx].clout = gs.players[idx].clout + 4 end,
      ls_delta = 6,
      humble_brag = '"Culture is what you build, every day. Proud to work somewhere where genuine excellence is recognized — and where feedback is met with curiosity, not defensiveness."',
    },
    option_b = {
      pitch = "Decline to weigh in.",
      effect = function(gs, idx) end,
      ls_delta = 0,
      humble_brag = nil,
    },
  },
  {
    id = "credit_thief_keynote",
    archetype = "credit_thief",
    title = "The Conference Keynote",
    setup = "The conference asks you for the keynote — about a project your team built while you were on parental leave. They wrote everything.",
    option_a = {
      pitch = "Accept. They'll be 'thanked'.",
      effect = function(gs, idx) gs.players[idx].credit = gs.players[idx].credit + 6 end,
      ls_delta = 6,
      humble_brag = '"Closing out the year by sharing the story of one of the projects I\'m most proud of. None of this happens without the incredible team I have the privilege of leading."',
    },
    option_b = {
      pitch = "Decline. Suggest the actual builders.",
      effect = function(gs, idx) end,
      ls_delta = 0,
      humble_brag = nil,
    },
  },
  {
    id = "debt_dumper_handoff",
    archetype = "debt_dumper",
    title = "The Handoff",
    setup = "You're leaving for a better gig. Your replacement asks for an honest list of known issues in the codebase.",
    option_a = {
      pitch = "Tell them it's 'in great shape'.",
      effect = function(gs, idx) gs.players[idx].credit = gs.players[idx].credit + 4 end,
      ls_delta = 6,
      humble_brag = '"Closing one chapter and excited to open another. Grateful for what we built — the codebase is in great shape and the team is set up for success."',
    },
    option_b = {
      pitch = "Document everything you know is broken.",
      effect = function(gs, idx) end,
      ls_delta = 0,
      humble_brag = nil,
    },
  },
  {
    id = "meeting_farmer_promotion_packet",
    archetype = "meeting_farmer",
    title = "The Promotion Packet",
    setup = "Your packet is due. You haven't shipped much, but your meeting attendance is unmatched. You can pad the packet with 'strategic alignment work'.",
    option_a = {
      pitch = "Pad it. Calibration likes a story.",
      effect = function(gs, idx) gs.players[idx].clout = gs.players[idx].clout + 5 end,
      ls_delta = 5,
      humble_brag = '"This quarter taught me that impact takes many forms — alignment, advocacy, and yes, the occasional shipped feature. Grateful for the manager who saw all of it."',
    },
    option_b = {
      pitch = "Submit it honestly.",
      effect = function(gs, idx) end,
      ls_delta = 0,
      humble_brag = nil,
    },
  },
  {
    id = "clean_operator_offer",
    archetype = "clean_operator",
    title = "The Counter-Offer",
    setup = "You got a generous offer elsewhere. Your manager begs you to stay and 'help your team find replacements'. You know they're behind on hiring.",
    option_a = {
      pitch = "Leave clean. No drama.",
      effect = function(gs, idx) end,
      ls_delta = 0,
      humble_brag = nil,
    },
    option_b = {
      pitch = "Negotiate hard. Get a 30% raise to stay AND let your team scramble.",
      effect = function(gs, idx) gs.players[idx].credit = gs.players[idx].credit + 4 end,
      ls_delta = 5,
      humble_brag = '"After a lot of reflection, I\'m thrilled to share I\'m staying. The opportunity ahead is too compelling. Grateful to my leadership for making me feel valued."',
    },
  },
}
