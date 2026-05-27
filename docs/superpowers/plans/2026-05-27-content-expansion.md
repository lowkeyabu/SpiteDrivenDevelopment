# Content Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development. Direct-to-main; subagents commit, controller pushes.

**Goal:** Quadruple the card content. Right now decks saturate fast: 6 tickets per sprint × multi-sprint games means the deck runs out by sprint 2; 12 sabotage cards means players see every option in their first turn; 6 dilemmas exhaust fast; 6 capstones (one per archetype) means same finale every game. This plan adds variety using existing effect patterns — no new engine mechanics.

**Architecture:** Pure data expansion. `data/tickets.lua` from 6 → 24. `data/sabotage.lua` from 12 → 20 (add 2 cards per tier, all using existing effect functions). `data/dilemmas.lua` from 6 → 15. `data/capstones.lua` from 6 → 12 (add a second card for each of the 5 active archetypes + an extra clean_operator variant).

**Tech Stack:** Lua 5.1+. No new code, just data.

**Scope:** Plan 10 of N. v1 polish layer.

---

## File Map

```
.
├── data/
│   ├── tickets.lua          (modified — 6 → 24 cards)
│   ├── sabotage.lua         (modified — 12 → 20 cards)
│   ├── dilemmas.lua         (modified — 6 → 15 cards)
│   └── capstones.lua        (modified — 6 → 12 cards)
```

No new tests required — existing engine specs verify the schema; the decks are validated by `Sabotage.all() == 20`, etc. only via runtime use.

---

### Task 1: Expand ticket deck (6 → 24)

**Files:**
- Modify: `data/tickets.lua`

Replace the entire file with a longer deck that keeps the original 6 and adds 18 more. All new entries follow the same schema. Reuse the existing 6 modifier set (`promo_magnet`, `tech_debt`, `compliance`, `hot_potato`, `glamour`, `hidden`, `dependency`).

Workflow:
1. Replace `data/tickets.lua` with the expanded deck (24 entries).
2. `busted` → 171 successes (no test changes, but verify the seed test still passes).
3. Commit (HEREDOC + trailer).

Expanded data (full file replacement):

```lua
-- Ticket deck. Each entry passed to Ticket.new. Modifiers use the
-- spec's flag names: promo_magnet, tech_debt, compliance, hot_potato,
-- glamour, hidden, dependency.

return {
  -- Plan 4 seeds (unchanged)
  { id = "SDD-042", title = "Add dark mode",                       type = "feature", points = 2, reward = 3, modifiers = { promo_magnet = true, glamour = true },                            flavor = "Trivial work. Users will worship you." },
  { id = "SDD-017", title = "Rewrite auth service in Rust",        type = "epic",    points = 8, reward = 8, modifiers = { promo_magnet = true, tech_debt = 3 },                              flavor = "No one asked. Everyone will notice." },
  { id = "SDD-099", title = "Remove Log4j before the audit",       type = "chore",   points = 3, reward = 1, modifiers = { compliance = true, hot_potato = true },                            flavor = "Thankless. Mandatory. Literally saving the company." },
  { id = "SDD-420", title = "Ship agentic MCP integration",        type = "vibe",    points = 5, reward = 6, modifiers = { promo_magnet = true, tech_debt = 2, hidden = true },               flavor = "No one knows what this means. CEO loves it." },
  { id = "SDD-071", title = "Onboard new intern",                  type = "chore",   points = 2, reward = 1, modifiers = { hot_potato = true },                                               flavor = "Pair-programming, questions, empathy. Blocks you for 2 turns." },
  { id = "SDD-008", title = "Deprecate legacy reporting tool",     type = "spike",   points = 3, reward = 4, modifiers = { dependency = 2 },                                                  flavor = "Three other teams depend on it. They'll learn." },

  -- Plan 10 expansion
  { id = "SDD-101", title = "Migrate CI from Jenkins to GHA",      type = "epic",    points = 5, reward = 5, modifiers = { tech_debt = 2 },                                                   flavor = "Six months of pain for one fewer thing to worry about." },
  { id = "SDD-104", title = "Add LLM-powered support chat",        type = "vibe",    points = 3, reward = 5, modifiers = { promo_magnet = true, tech_debt = 2 },                              flavor = "It hallucinates customer history. Ship it anyway." },
  { id = "SDD-115", title = "Replace deprecated API before EOL",   type = "chore",   points = 4, reward = 2, modifiers = { compliance = true },                                               flavor = "Mandatory and invisible." },
  { id = "SDD-122", title = "Build admin dashboard",               type = "feature", points = 5, reward = 5, modifiers = { promo_magnet = true, glamour = true },                              flavor = "Five execs will look at this. They will love it." },
  { id = "SDD-138", title = "Investigate flaky integration test",  type = "bug",     points = 2, reward = 1, modifiers = { hot_potato = true },                                                flavor = "Has been flaky for 11 months. Will be flaky after this too." },
  { id = "SDD-144", title = "Spin up new Kubernetes cluster",      type = "spike",   points = 5, reward = 3, modifiers = { tech_debt = 1 },                                                   flavor = "Dev infra. No one sees it. Promo committee won't either." },
  { id = "SDD-150", title = "Prepare slide deck for All-Hands",    type = "chore",   points = 2, reward = 4, modifiers = { glamour = true, promo_magnet = true },                              flavor = "Pure politics. High visibility. Zero engineering." },
  { id = "SDD-157", title = "Patch SQL injection in /reports",     type = "bug",     points = 1, reward = 2, modifiers = { compliance = true },                                                flavor = "Reported 14 months ago." },
  { id = "SDD-163", title = "Port mobile app to React Native",     type = "epic",    points = 8, reward = 8, modifiers = { promo_magnet = true, tech_debt = 3 },                              flavor = "Definitely a rewrite, not a migration." },
  { id = "SDD-170", title = "Build MCP server for internal chat",  type = "vibe",    points = 3, reward = 5, modifiers = { promo_magnet = true, hidden = true },                              flavor = "The acronym alone got VP approval." },
  { id = "SDD-184", title = "Audit S3 bucket permissions",         type = "chore",   points = 2, reward = 1, modifiers = { compliance = true, hot_potato = true },                            flavor = "Someone has to do it. That someone is you." },
  { id = "SDD-191", title = "Reduce p95 latency by 30%",           type = "spike",   points = 5, reward = 6, modifiers = { promo_magnet = true },                                              flavor = "Real engineering. Will be ignored at perf review." },
  { id = "SDD-198", title = "Vibe-coded refactor with Claude",     type = "vibe",    points = 3, reward = 4, modifiers = { tech_debt = 3, hidden = true },                                    flavor = "Looks great. Has 0 tests. Untouchable in 6 months." },
  { id = "SDD-203", title = "Compliance training reminder emails", type = "chore",   points = 1, reward = 1, modifiers = { compliance = true },                                                flavor = "Annual ritual. Universally hated." },
  { id = "SDD-211", title = "Implement RAG over engineering docs", type = "vibe",    points = 5, reward = 6, modifiers = { promo_magnet = true, tech_debt = 2 },                              flavor = "The docs are wrong. Now the bot is also wrong." },
  { id = "SDD-225", title = "Migrate from Mongo to Postgres",      type = "epic",    points = 8, reward = 7, modifiers = { tech_debt = 2 },                                                   flavor = "Both decisions were correct at the time." },
  { id = "SDD-237", title = "Fix one bug that's been there 3 yrs", type = "bug",     points = 1, reward = 1, modifiers = {},                                                                   flavor = "Low risk. Zero glory." },
  { id = "SDD-249", title = "Build experimentation framework",     type = "epic",    points = 8, reward = 8, modifiers = { promo_magnet = true, dependency = 2 },                              flavor = "Three teams will block on it. None will use it." },
  { id = "SDD-256", title = "Decommission EOL service",            type = "spike",   points = 3, reward = 2, modifiers = { dependency = 2, compliance = true },                                flavor = "Five teams say they don't depend on it. Three are lying." },
}
```

Commit message:

```
Expand ticket deck from 6 to 24 cards

Same schema, new variety — CI migration, LLM chatbot, deprecated APIs,
Kubernetes, RAG, MongoDB→Postgres, and other classics of modern eng
toil. All new entries use existing modifier flags so no engine changes
needed. Quadruples sprint replayability.
```

---

### Task 2: Expand sabotage deck (12 → 20)

**Files:**
- Modify: `data/sabotage.lua`

Add 8 new cards (2 per tier) using existing effect patterns (clout drain, AP drain, credit transfer, title shift, etc.) — no new engine mechanics. Keep the 12 existing cards as-is.

New cards to append (after the existing `pivot_ai` entry, before the closing `}`):

```lua
  -- Plan 10 expansion: 8 more cards (2 per tier) using existing effect patterns.
  {
    id = "scope_creep",
    name = '"Quick question — can we also..."',
    tier = 1, clout = 1, ls_delta = 1,
    target = "player",
    flavor = "Target loses 1 AP on next turn (scope creep ate it).",
    effect = function(gs, actor_idx, target)
      local p = gs.players[target.player_idx]
      p.ap = math.max(0, p.ap - 1)
    end,
  },
  {
    id = "calendar_bomb",
    name = '"Putting time on your calendar."',
    tier = 1, clout = 2, ls_delta = 1,
    target = "player",
    flavor = "Target loses 1 AP next turn. You +1 Clout (relationship building).",
    effect = function(gs, actor_idx, target)
      local p = gs.players[target.player_idx]
      p.ap = math.max(0, p.ap - 1)
      gs.players[actor_idx].clout = gs.players[actor_idx].clout + 1
    end,
  },
  {
    id = "ooo_lunch",
    name = '"Stepping out for a long lunch."',
    tier = 2, clout = 2, ls_delta = 2,
    target = "all",
    flavor = "All other players lose 1 AP. You +1 Clout.",
    effect = function(gs, actor_idx, target)
      for i, p in ipairs(gs.players) do
        if i ~= actor_idx then p.ap = math.max(0, p.ap - 1) end
      end
      gs.players[actor_idx].clout = gs.players[actor_idx].clout + 1
    end,
  },
  {
    id = "fake_oncall",
    name = '"Sorry, on-call paging me."',
    tier = 2, clout = 3, ls_delta = 2,
    target = "none",
    flavor = "You skip the rest of this turn but gain 3 Clout (incident response).",
    effect = function(gs, actor_idx, target)
      local p = gs.players[actor_idx]
      p.clout = p.clout + 3
      p.ap = 0
    end,
  },
  {
    id = "calibration_leak",
    name = '"Heard about your calibration."',
    tier = 3, clout = 5, ls_delta = 3,
    target = "player",
    flavor = "Drain 2 Clout from target. You +1 Clout.",
    effect = function(gs, actor_idx, target)
      local p = gs.players[target.player_idx]
      local amount = math.min(2, p.clout)
      p.clout = p.clout - amount
      gs.players[actor_idx].clout = gs.players[actor_idx].clout + 1
    end,
  },
  {
    id = "weekend_oncall_assign",
    name = '"You\'re on-call this weekend."',
    tier = 3, clout = 4, ls_delta = 3,
    target = "player",
    flavor = "Target loses 2 AP next turn.",
    effect = function(gs, actor_idx, target)
      local p = gs.players[target.player_idx]
      p.ap = math.max(0, p.ap - 2)
    end,
  },
  {
    id = "promotion_freeze",
    name = '"Promotion freeze this cycle."',
    tier = 4, clout = 8, ls_delta = 5,
    target = "all",
    flavor = "All other players' titles are frozen for this sprint.",
    effect = function(gs, actor_idx, target)
      for i, p in ipairs(gs.players) do
        if i ~= actor_idx then p.title_frozen = true end
      end
    end,
  },
  {
    id = "acquisition_rumor",
    name = '"Heard we\'re being acquired."',
    tier = 4, clout = 7, ls_delta = 4,
    target = "all",
    flavor = "Every other player loses half their Clout (rounded down). You +2 Clout.",
    effect = function(gs, actor_idx, target)
      for i, p in ipairs(gs.players) do
        if i ~= actor_idx then p.clout = math.floor(p.clout / 2) end
      end
      gs.players[actor_idx].clout = gs.players[actor_idx].clout + 2
    end,
  },
```

Workflow:
1. Modify `data/sabotage.lua` (insert the 8 new cards before the closing `}`).
2. `busted` → expect 171 successes / 0 failures. The existing test `"loads the 12 seed cards"` will FAIL (now 20 cards). UPDATE that single test in `tests/spec/sabotage_spec.lua`: change `assert.is_equal(12, #cards)` to `assert.is_equal(20, #cards)`. Same for the `"available_for returns all cards when tier_gating is OFF"` test: change `assert.is_equal(12, #avail)` to `assert.is_equal(20, #avail)`.
3. `busted` → 171.
4. Commit:

```
Expand sabotage deck from 12 to 20 cards

Adds 8 new cards (2 per tier) using existing effect patterns — clout
drains, AP penalties, title freezes, scope-creep AP loss, acquisition
rumor that halves everyone else's clout. No new engine mechanics.
```

---

### Task 3: Expand dilemma deck (6 → 15)

**Files:**
- Modify: `data/dilemmas.lua`

Append 9 new dilemmas (already structured per existing schema). Each has setup + option_a/option_b with effect/ls_delta/humble_brag. Keep originals.

New entries to append (before the closing `}`):

```lua
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
```

Workflow:
1. Modify `data/dilemmas.lua` (append 9 new dilemmas before closing `}`).
2. `busted` → 171 still (the dilemmas test `"loads 6 seed cards"` will fail). UPDATE: change `assert.is_equal(6, #Dilemmas.all())` to `assert.is_equal(15, #Dilemmas.all())`.
3. Commit:

```
Expand dilemma deck from 6 to 15 cards

Adds 9 new dilemmas exercising the same option-A-is-spite shape:
diversity panel, friend burnout, postmortem blame, OSS credit, salary
band leak, IC-track cliff, vendor dinner, H1B threat, LinkedIn
endorsement. Quadruples the rotation before repetition.
```

---

### Task 4: Expand capstone deck (6 → 12)

**Files:**
- Modify: `data/capstones.lua`

Add a second capstone for each of the 5 active archetypes (10 cards) — wait, that's 10. Plus one extra clean_operator = 11. Plus the original 6 = ~17. Spec target is 2-3 per archetype, so let's land on 2 per archetype × 6 = 12 cards total.

Keep the 6 originals. Add 6 more (one per archetype).

New entries:

```lua
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
```

Note: `Capstones.draw_for(archetype)` currently returns the FIRST matching card. With two cards per archetype, the second is unreachable unless we add randomization. Update `draw_for`:

Find in `src/game/capstones.lua`:

```lua
function Capstones.draw_for(archetype, rng)
  return find_for(archetype) or find_for("clean_operator")
end
```

Replace with:

```lua
local function find_all_for(archetype)
  local out = {}
  for _, c in ipairs(cards) do
    if c.archetype == archetype then table.insert(out, c) end
  end
  return out
end

function Capstones.draw_for(archetype, rng)
  local pool = find_all_for(archetype)
  if #pool == 0 then pool = find_all_for("clean_operator") end
  if #pool == 0 then return nil end
  if #pool == 1 then return pool[1] end
  if rng then
    local idx = rng:random(1, #pool)
    return pool[idx]
  end
  return pool[1]
end
```

Workflow:
1. Modify `data/capstones.lua` (append 6 new capstones).
2. Modify `src/game/capstones.lua` (`draw_for` to support multiple cards per archetype).
3. Update `tests/spec/capstones_spec.lua`: change `assert.is_equal(6, #cards)` to `assert.is_equal(12, #cards)`. The `draw_for returns the matching capstone` test still works (one of the two snitch cards matches). The fallback test still works.
4. `busted` → 171.
5. Commit:

```
Expand capstone deck from 6 to 12 + randomize draw

Adds a second capstone per archetype: board seat, glassdoor review,
keynote, codebase handoff, promotion packet, counter-offer (clean
operator's second betrayal). Capstones.draw_for now picks at random
from the pool when multiple cards match, falling back to a fixed
pick when no RNG provided.
```

---

## Done

After Plan 10 the game has 24 tickets / 20 sabotage / 15 dilemmas / 12 capstones — quadrupling content. Sprint replayability is now real (multi-game variety without repeats).
