# Spite Driven Development

A parody boardgame about modern tech work. Local hotseat for 2–8 players. Built in Lua with Love2D.

## What it is

You and 2–7 coworkers are employees at the same fictional Big Tech company. The "board" is a shared JIRA Kanban — ticket cards flow through Backlog → In Progress → Review → Done. On your turn you can claim tickets, ship work, review (or sandbag) someone's pull request, attend a meeting, or sabotage someone outright.

**Sabotage is not seasoning, it's the whole point.** Reject reviews with *"I have some concerns."* Trigger a rival's PIP. Steal credit on a ticket you reviewed. Drop tech debt onto someone else's project. Higher titles unlock uglier moves — ICs can snitch; VPs can fire.

## How you win (and how you lose)

There's a **visible scoreboard** — your career ladder, IC1 to C-suite — and a **hidden one**: your **LinkedIn Score**. Every spiteful sabotage and every corporate moral compromise silently logs a humble-brag post to your fake LinkedIn profile.

The declared winner is whoever climbs highest by game end. But on the end screen, every player gets a personalized roast: their fake LinkedIn profile rendered in full, with every cringey humble-brag their gameplay earned.

> *"Had to make some difficult but necessary decisions this week 🙏 Grateful to the team members whose contributions helped us get here. Wishing them the best in their next chapter."*

The running joke: the winner is usually also the worst person at the table.

## Dilemmas and capstones

Every meeting you attend draws a **Dilemma card** — a trolley-style binary corporate choice illustrated in hand-drawn stick figures. Options like:

- Layoff 5 juniors or 1 senior?
- Approve a friend's buggy PR before their promo review?
- Ship the AI feature trained on dubious data, or delay the quarter?
- Snitch on WFH coworkers for the RTO bonus, or stay loyal?

Each option carries a prewritten humble-brag waiting to surface in the end-screen reveal.

The game ends with a personalized **capstone** drawn from your play style. Heavy saboteurs face one last ladder-climbing temptation. Meeting farmers face one last political move. Players who stayed clean all game are tempted into a single betrayal — and if they take it, they earn their first humble-brag post, which lands harder than anyone else's.

## Modes

Sprint mode (the JIRA Kanban described above) is the first mode being built. The mode-select scaffold also reserves slots for:

- **The Floor** — Monopoly-style office loop with desks and meeting-room rent.
- **The Ladder** — per-player promotion tracks, action-point only.
- **Hybrid** — both at once.
- **Story Mode** — single-player narrative campaign (concept by nilpointerr) where NPCs are the cast and decisions branch the story.

## Status

Pre-alpha. Currently only the project skeleton and main menu navigation are implemented. The full design lives in `docs/superpowers/specs/2026-04-21-spite-driven-development-design.md`; implementation milestones live in `docs/superpowers/plans/`.

## Run

Requires Love2D 11.x. From the project root:

```
love .
```

Press SPACE to walk through the placeholder screens. Esc returns to the menu (or quits from the menu).

## Test

Requires busted (`luarocks install busted`):

```
busted
```

Runs all unit tests under `tests/spec/`.

## Layout

- `main.lua` / `conf.lua` — Love2D entry and window config
- `src/states/` — one Lua module per screen
- `src/ui/` — shared UI primitives (typography, button)
- `src/util/` — pure-logic utilities (fsm, rng)
- `tests/spec/` — busted unit tests
- `docs/superpowers/specs/` — design specs
- `docs/superpowers/plans/` — implementation milestone plans
- `assets/tweets/`, `assets/instagram/` — marketing draft mockups

## Credits

- abu — primary author
- nilpointerr — co-designer (Dilemma cards, LinkedIn Score concept, Story Mode)
- hotdogflavoredwater — collaborator
