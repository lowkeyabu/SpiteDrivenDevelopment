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
