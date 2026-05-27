-- Seed ticket deck. Each entry is the table passed to Ticket.new.
-- The {COMPANY} placeholder is substituted at render time from
-- session.config.company_name. None of these tickets actually use it
-- yet — future tickets will.

return {
  {
    id = "SDD-042",
    title = "Add dark mode",
    type = "feature",
    points = 2,
    reward = 3,
    modifiers = { promo_magnet = true, glamour = true },
    flavor = "Trivial work. Users will worship you.",
  },
  {
    id = "SDD-017",
    title = "Rewrite auth service in Rust",
    type = "epic",
    points = 8,
    reward = 8,
    modifiers = { promo_magnet = true, tech_debt = 3 },
    flavor = "No one asked. Everyone will notice.",
  },
  {
    id = "SDD-099",
    title = "Remove Log4j before the audit",
    type = "chore",
    points = 3,
    reward = 1,
    modifiers = { compliance = true, hot_potato = true },
    flavor = "Thankless. Mandatory. Literally saving the company.",
  },
  {
    id = "SDD-420",
    title = "Ship agentic MCP integration",
    type = "vibe",
    points = 5,
    reward = 6,
    modifiers = { promo_magnet = true, tech_debt = 2, hidden = true },
    flavor = "No one knows what this means. CEO loves it.",
  },
  {
    id = "SDD-071",
    title = "Onboard new intern",
    type = "chore",
    points = 2,
    reward = 1,
    modifiers = { hot_potato = true },
    flavor = "Pair-programming, questions, empathy. Blocks you for 2 turns.",
  },
  {
    id = "SDD-008",
    title = "Deprecate legacy reporting tool",
    type = "spike",
    points = 3,
    reward = 4,
    modifiers = { dependency = 2 },
    flavor = "Three other teams depend on it. They'll learn.",
  },
}
