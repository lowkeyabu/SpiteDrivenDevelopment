# Spite Driven Development — Design Spec

**Date:** 2026-04-21
**Status:** Draft (v1) — awaiting review
**Authors:** abu, nilpointerr, hotdogflavoredwater

---

## 1. Overview

Spite Driven Development is a local-hotseat, turn-based board game for 2–8 players, built in Lua with the love2d framework. It is a satirical parody of modern IT / corporate tech life. Players are employees at a single fictional Big Tech company, competing to climb the career ladder by any means necessary — shipping tickets, sandbagging each other's reviews, and answering corporate dilemmas that feed a hidden "LinkedIn Score."

The game has a **dual-track win condition**:

1. A single **declared winner** — the player with the highest corporate success (title + comp) at game end.
2. A **parallel moral exposé** — every player's hidden LinkedIn Score is revealed on the end screen as their cringey fake LinkedIn profile, with each in-game sin translated into a humble-brag post.

The running joke: the winner is almost always also the most LinkedIn-poisoned person at the table.

---

## 2. Goals & Non-Goals

**Goals**

- A tonally consistent cutthroat-PvP satire of modern tech work.
- Clean support for 2–8 players in hotseat on a single machine; expected use is screen-share.
- A mode-selection scaffold so additional game modes can be added later.
- All card content (tickets, sabotage, dilemmas, capstones) authored as data, not code.
- Tuning variables surfaced through a pre-game settings screen.

**Non-Goals**

- Online multiplayer, matchmaking, lobbies, or any networking.
- Single-player vs AI bots. Not in v1; not even deferred — SDD is human-vs-human by design.
- Save/load mid-game. Sessions are single-sitting.
- Localization in v1 (English only).
- Pixel-perfect polish for v1 — the art style is deliberately hand-drawn stick figures; the visual reference is `docs/trainquestion.png`.

---

## 3. Players & Setup

- **Player count:** 2 min, 8 max.
- **Model:** single-machine hotseat. Turns pass around a physical or virtual "table" (screen share).
- **Per-player customization on the setup screen:**
  - Character name (free text, ≤ 20 chars).
  - Stick-figure color (pick from palette).
- **Turn order:** fixed clockwise once set, randomized at game start.

---

## 4. Game Modes

SDD is architected around selectable game modes. Only one is being built for v1. The mode-select screen and the shared subsystems must exist from day one so later modes plug in cleanly.

**v1 (build):**

- **The Sprint** — shared JIRA Kanban, ticket cards flow across columns, sprint-end promotions drive the career ladder. All mechanics in this spec describe Sprint mode unless stated otherwise.

**Deferred modes (scaffold only, document for later):**

- **The Floor** *(multiplayer PvP)* — Monopoly-style office loop with dice + rent mechanics on owned desks/rooms.
- **The Ladder** *(multiplayer PvP)* — per-player vertical promotion tracks, action-point-only (no spatial board).
- **Hybrid** *(multiplayer PvP)* — central Floor board plus per-player ladder tracks on the sides.
- **Story Mode** *(single-player narrative — concept by nilpointerr)* — the player takes the role of one IC at the company; the rest of the cast is NPCs (HR, CEO, manager, colleagues, each with personality + relationship stat). Gameplay is multi-choice decision scenes (3–4 options) that branch the story across career levels. Shares the Dilemma framework (extended to multi-choice), LinkedIn Score, end-screen roast, capstone framework, art direction, and company-name templating with the multiplayer modes. Does NOT share player-rotation / hotseat / PvP-targeting / sabotage infrastructure. Larger authoring burden than mechanical scope suggests (~50–100+ scenarios for a satisfying campaign vs ~30–40 cards per multiplayer mode). Seed scenario from nilpointerr: "A colleague leaks company credentials. Choices: report to HR (HR credibility), help them rotate keys (peer trust), …".

Wireframe reference for the multiplayer deferred modes lives at `.superpowers/brainstorm/*/content/board-concepts.html`. Story Mode does not yet have a wireframe; UI shape (dialogue + portrait + choice list) to be designed when that mode is activated.

---

## 5. Pre-Game Configuration

Before a game starts, the host configures:

| Setting | Default | Range / Options |
|---|---|---|
| Game mode | The Sprint | The Sprint (v1); others as implemented |
| Company name | MegaCorp | Preset list (below) + free text (≤ 24 chars) |
| Player count | — | 2–8 |
| Action points per turn | 3 | 1–5 |
| End trigger | First to C-suite OR 5 sprints | First to C-suite \| Fixed N sprints (3/5/7) \| First to Comp target |
| Comp target (if trigger = "First to Comp target") | 30 Credit | 10–100 |
| Per-sprint turn cap | 8 | 4–20 — prevents infinite sprints if Backlog stalls |
| Sabotage tier-gating | ON | ON / OFF |
| Starting resources | 0 Credit, 0 Clout, 0 Tech Debt, Title = IC1 | fixed |

**Preset company names:** MegaCorp, Axiom Inc., Hypercorp, Globodyne Synthetics, Latent, Prompt Industries, NullPointer Inc., Agentic, VibeStack. The selected name is exposed as `{COMPANY}` and substituted into all card and UI text at render time.

---

## 6. Core Loop (Sprint Mode)

### 6.1 Sprint phases

Each "sprint" is one full cycle consisting of three phases:

1. **Sprint Planning (automatic)** — draw N ticket cards from the Ticket deck into the Backlog column. N scales with player count (e.g., 2P→4, 4P→8, 8P→12). Exact scaling is tunable.
2. **Player Turns (loop)** — go clockwise. Each player spends their Action Points on turn actions. Continues until one of: (a) the Backlog is exhausted *and* no tickets remain in In Progress / Review; (b) the configurable per-sprint turn cap is hit; (c) a Compliance-flagged ticket has shipped (see §8.4 for ship-forcing effects).
3. **Retro & Promo** — tally Credit shipped by each player this sprint. Top shipper earns a Promotion Point. Accrued Tech Debt rolls over; if it crosses a threshold, trigger a shared-pain event (e.g., all players -1 AP next sprint).

### 6.2 A single turn

On your turn you have `AP` Action Points (default 3, configurable). Each action costs 1 AP; you may spend them in any combination.

| Action | Cost | Effect |
|---|---|---|
| **Claim** | 1 AP | Move a ticket from Backlog into your personal In Progress lane. Hidden traits, if any, are revealed to you only. |
| **Work** | 1 AP | Advance one of your In Progress tickets by 1 point. When points remaining = 0, the ticket moves to Review. |
| **Review** | 1 AP | Inspect a ticket in Review belonging to another player. **Approve** → ticket moves to Done; reviewer gains +1 Credit. **Reject** → ticket bounces back to the owner's In Progress at full points remaining. |
| **Sabotage** | 1 AP + Clout cost on card | Play a sabotage card from the open menu. See §8. |
| **Meeting** | 1 AP | Gain +2 Clout and draw + resolve one Dilemma card. See §9. |

### 6.3 End triggers

The game ends when one of the pre-configured end triggers fires (see §5). When triggered:

1. Finish the current sprint's Retro & Promo phase (for fairness).
2. Transition to the Capstone + Reveal sequence (§10).

---

## 7. Resources & Career Ladder

**Per-player resources:**

- `AP` — action points for the current turn (default 3). Refreshes at turn start.
- `Credit` — earned by shipping tickets and approved reviews. Converts to Promotion Points at sprint-end.
- `Clout` — political capital. Earned from meetings and selected dilemma choices; spent on sabotage cards.
- `Tech Debt` — shared game-wide counter. Some tickets add debt on ship. At threshold, triggers table-wide penalty events.
- `LinkedIn Score (LS)` — hidden per-player. Accumulated from sabotage plays and dilemma choices. Revealed only on the end screen.
- `Title / Level` — the visible scoreboard. Career ladder (see below).

**Career ladder (10 rungs, tunable):**

IC1 → IC2 → Senior → Staff → Principal → Manager → Sr Manager → Director → VP → C-suite.

- Players advance one rung per Promotion Point earned (sprint-end).
- Promotion threshold values (credit required per promotion) are placeholders in v1 and expected to be tuned during playtesting.
- Tier-gated sabotage unlocks are keyed to these rungs (see §8.3).

---

## 8. Sabotage Cards

### 8.1 Acquisition & targeting

- Open, shared menu of sabotage moves. No hand management, no draw pile. Every player sees the same options.
- A play targets another specific player, a specific ticket, or the whole table (per card).
- Trigger: **on your own turn only** in v1. Reactive / out-of-turn play is deferred.

### 8.2 Cost model

Every sabotage play costs `1 AP` plus the `Clout` cost printed on the card. No card may be played for free. Max three sabotages in a single turn (only if all AP is spent on sabotage, sacrificing everything else).

Every play also applies `+N LS` to the attacker.

### 8.3 Tier-gating (toggleable)

When `sabotage_tier_gating` is `ON`, sabotage cards are unlocked by the attacker's current Title level:

- **Tier I — IC1 to Senior:** cheap, low-impact moves.
- **Tier II — Staff to Principal:** credit-stealing, tech-debt transfer, mid-cost disruption.
- **Tier III — Manager to Director:** PIPs, reorgs, scheduling attacks.
- **Tier IV — VP to C-suite:** firings, RTO mandates, pivots.

When tier-gating is `OFF`, all sabotage moves are available to every player regardless of Title.

### 8.4 Seed deck (v1)

12 cards across 4 tiers:

| Tier | Name | Cost | Effect | LS |
|---|---|---|---|---|
| I | "I have some concerns." | 1 AP + 1 Clout | Reject a ticket in Review; bounces to owner's In Progress. | +1 |
| I | "Just a quick sync?" | 1 AP + 1 Clout | Target loses 1 AP on their next turn. | +1 |
| I | "Slack DM to manager." | 1 AP + 1 Clout | Snitch. Target reveals hidden trait on any one ticket. | +1 |
| II | "Credit where credit is due." | 1 AP + 3 Clout | Steal 2 Credit from any ticket you **approved** this sprint. | +2 |
| II | "Legacy auth is your problem now." | 1 AP + 2 Clout | Move 2 Tech Debt from your ticket onto a target's ticket. | +2 |
| II | "Sev-1 — all hands." | 1 AP + 4 Clout | All other players lose 2 AP next turn. You +1 Credit. | +2 |
| III | "I'd like to put you on a PIP." | 1 AP + 5 Clout | Target's Title is frozen — no promotion this sprint. | +3 |
| III | "We're going through a reorg." | 1 AP + 4 Clout | Shuffle Backlog. Tickets claimed this turn go back. | +2 |
| III | "Let's schedule a skip-level." | 1 AP + 5 Clout | Target loses their entire next turn (0 AP). | +3 |
| IV | "Difficult but necessary decision." | 1 AP + 8 Clout | Fire target — they drop 2 Title levels. | +5 |
| IV | "RTO effective Monday." | 1 AP + 7 Clout | All Hot Potato holders lose 1 Credit; repeat next sprint. | +4 |
| IV | "Pivot. We're an AI company now." | 1 AP + 9 Clout | Discard all In Progress tickets of one Type. | +5 |

This deck is v1. Cards will be authored iteratively as data (see §13).

---

## 9. Dilemma Cards

### 9.1 Trigger

Dilemmas are drawn **only via the Meeting action**. Meeting costs 1 AP, gains the actor +2 Clout automatically, and forces drawing and resolving one Dilemma card. No other trigger path in v1.

### 9.2 Anatomy

```
id          e.g. "SDD-D-001"
title       short, evocative
setup       1–2 sentences of corporate narrative
option_a    { pitch, effect, ls_delta, humble_brag }
option_b    { pitch, effect, ls_delta, humble_brag }
illustration trolley-style: character + two diverging paths
```

Each option has:

- `pitch` — player-facing one-liner.
- `effect` — in-game state deltas (`+credit`, `+clout`, `+tech_debt`, `+2 ls`, etc.).
- `ls_delta` — LinkedIn Score change.
- `humble_brag` — the prewritten LinkedIn-post string added to the player's end-screen profile if they chose this option. A `null` value means "no post generated" for zero-LS choices.

### 9.3 Asymmetry (deliberate)

Most dilemma pairs follow this shape: Option A trades LS for a material gain; Option B is near-neutral (sometimes with a small trade, often no effect at all). The tension is whether the player is willing to pay real LS damage for real game-state gain — knowing the LinkedIn post will surface on the end screen.

### 9.4 Universality

Dilemma draws are **not tier-gated**. Every player can face every dilemma. Dilemmas represent the universal corporate experience.

### 9.5 Seed deck (v1)

6 seed cards: Friday Deploy · The Layoff List · PR Review at 11 PM · AI Training Data · RTO Snitch Bonus · The Intern's Feature. Full content lives in `data/dilemmas.lua`. More cards authored iteratively.

---

## 10. End Game — Capstones, LinkedIn Score, and the Reveal

### 10.1 Capstone framework

Every action during the game tags **archetype counters** on the player. At game end, each player is classified by `primary_archetype = argmax(counters)` with a fallback to the **Clean Operator** archetype when no counter dominates.

**Archetypes (v1, 6 types):**

- **Ladder Climber** — many Mgr/Exec-tier sabotage plays (PIP, reorg, fire).
- **Snitch** — heavy "Slack DM to manager" / "RTO Snitch" usage.
- **Credit Thief** — many credit-steal plays; high total stolen Credit.
- **Debt Dumper** — many "Legacy auth is your problem now" plays; high Tech Debt pushed.
- **Meeting Farmer** — disproportionate Meeting usage.
- **Clean Operator** — fallback: no dominant profile OR lowest LS total.

Each archetype maps to a deck of 2–3 tailored capstone Dilemma variants. At game end, each player draws one capstone from their archetype's deck.

### 10.2 Play order

**Public** — every capstone is played in front of the whole table. Order: ascending by corporate-success metric, so the **declared winner plays last** for maximum dramatic buildup.

### 10.3 Capstone stakes

Capstone LS deltas are 2–3× the regular Dilemma range. Capstone humble-brags are the loudest posts on each player's end-screen profile.

The **Clean Operator capstone** is the narrative payoff: the quiet player is tempted into one final spite move. If taken, it generates their first humble-brag — a career-defining betrayal of their whole game persona.

### 10.4 The reveal

After all capstones are resolved:

1. End-screen sequence renders each player's fake LinkedIn profile, staggered one player at a time.
2. Each profile includes: stick-figure avatar (colored to player), character name, Title, final LinkedIn Score, and the accumulated humble-brag posts in chronological order.
3. Order matches capstone order (ascending corporate success; winner last).
4. Declared winner is crowned last — their roast is the most generous (and most cringey).
5. No hidden state remains; the game is over.

---

## 11. Art Direction

- **Style:** hand-drawn stick figures, monochrome with minimal color, dry-humor aesthetic. Hand-drawn / pen-and-paper feel.
- **Visual reference:** `docs/trainquestion.png` anchors the style — the Dilemma / capstone cards in particular should echo its trolley composition (character + two diverging paths).
- **Public copy rule:** never use "xkcd" in any user-facing text, UI copy, tweets, marketing, README, or commit messages. Internal inspiration only.
- **Stick figures drawn procedurally in Love2D** wherever feasible (player avatars, card illustrations) using `love.graphics.line` / `circle`. Handcrafted art can be dropped in as PNGs for special cards.

---

## 12. Love2D Architecture (initial proposal)

This section proposes an implementation architecture. The specifics (module boundaries, exact file names) can be refined during the plan phase.

### 12.1 State machine

The game is a top-level finite state machine. States:

```
MENU → MODE_SELECT → CONFIG → PLAYER_SETUP → GAME → END_SCREEN → MENU
```

Each state is a Lua module exposing `enter`, `update`, `draw`, `leave`, and input handlers. A lightweight FSM helper (`src/util/fsm.lua`) owns the current state and dispatches Love2D callbacks to it.

### 12.2 Proposed module layout

```
main.lua                 Love2D entry, FSM bootstrap
conf.lua                 window config
src/
  states/
    menu.lua
    mode_select.lua
    config.lua
    player_setup.lua
    game.lua
    end_screen.lua
  game/
    session.lua          session config + players + mode
    modes/
      sprint.lua         v1 mode
    board/
      kanban.lua         columns, ticket placement
      ticket.lua
    cards/
      deck.lua           generic deck utility
      ticket_deck.lua
      sabotage_deck.lua
      dilemma_deck.lua
      capstone_deck.lua
    players/
      player.lua         state + archetype counters
      archetype.lua      classification at end
    actions/
      claim.lua
      work.lua
      review.lua
      sabotage.lua
      meeting.lua
    resources/
      resources.lua
    end_game/
      triggers.lua
      capstone.lua
      linkedin_post.lua  humble-brag rendering
  ui/
    components/
      button.lua
      card_render.lua
      stick_figure.lua
      pill.lua
    screens/
      kanban_view.lua
      hand_view.lua
      resource_bar.lua
    dialog.lua
    modal.lua
    typography.lua
  util/
    fsm.lua
    event_bus.lua
    rng.lua              seedable for tests
data/
  tickets.lua
  sabotage.lua
  dilemmas.lua
  capstones.lua
  companies.lua
  settings_defaults.lua
assets/
  fonts/
  images/
tests/
  (unit tests for classification, resource math, deck ops)
```

### 12.3 Rendering & input

- Per-frame rendering through `love.draw`. No layout engine; positions are handcrafted.
- Input via `love.mousepressed` / `love.keypressed`; UI components expose hit regions.
- Minimal animation in v1: simple tweens for card movement between Kanban columns and fade transitions between states. Polish deferred.

### 12.4 Data files

All card content is Lua data, loaded at game start. Example shape (`data/dilemmas.lua`):

```lua
return {
  {
    id = "SDD-D-001",
    title = "Friday Deploy",
    setup = "It's 4:55 PM Friday. The feature is 90% ready...",
    option_a = {
      pitch = "Push it now. Ship it.",
      effect = { credit = 2, tech_debt = 3 },
      ls_delta = 2,
      humble_brag = "Shipped late Friday 🚀 ...",
    },
    option_b = {
      pitch = "Wait until Monday. Proper rollout.",
      effect = {},
      ls_delta = 0,
      humble_brag = nil,
    },
  },
  -- ...
}
```

The `{COMPANY}` placeholder is substituted at render time from `session.config.company_name`.

### 12.5 Testing

- Use `busted` (or equivalent) for unit tests focused on deterministic logic: archetype classification, resource math, end-trigger detection, deck operations.
- UI / rendering is tested manually in v1.

---

## 13. Authoring Workflow for Card Content

- All decks (tickets, sabotage, dilemmas, capstones) live under `data/*.lua`.
- Any collaborator can add a card without touching engine code.
- Each deck file is a flat Lua table. Schema is fixed per deck type (see §12.4 for dilemma shape; tickets, sabotage, capstones follow analogous shapes).
- Seed content committed in v1 is the minimum playable set; iteration continues after launch.

---

## 14. Open Questions (tracked; not blocking v1)

- **Promotion threshold numbers.** Exact Credit required per Title rung is a placeholder in v1 and needs playtesting.
- **Ticket-backlog scaling.** Exact N draws per sprint for each player count needs tuning.
- **Tech Debt thresholds.** Specific threshold values and penalty events need tuning.
- **Clout accrual rate outside of Meetings.** Whether other actions should yield Clout, and at what rate.
- **Sabotage reactive/out-of-turn play.** Deferred to post-v1; revisit after playtesting on-turn-only.
- **Save/load.** Not in v1; may add later if sessions routinely need pausing.
- **Tie-breakers** for: archetype counter ties, declared-winner ties (corporate-success equal).

---

## 15. Non-Functional Notes

- **Target platform:** desktop (Linux / macOS / Windows) via Love2D 11.x+.
- **Distribution:** `love` file or platform-native packaged binaries.
- **Accessibility:** default font size ≥ 16px equivalent; color-blind-safe player palette (avoid red-green pairings).
- **Performance:** no frame-rate concerns given scope; target 60 fps.

---

## 16. Credits

- **abu** — primary author and engineer.
- **nilpointerr** — co-designer. Originator of the Dilemma card archetype (visual: `docs/trainquestion.png`) and the LinkedIn Score exposé concept.
- **hotdogflavoredwater** — collaborator.

---

## 17. Change Log

- `2026-04-20` — initial brainstorming session: stack, scope, tone, frame, board structure, win condition, trolley mechanic, game modes locked.
- `2026-04-21` — resume session: core loop approved (3 AP/turn configurable, selectable end triggers), ethics counter renamed to **LinkedIn Score**, ticket schema and seed deck approved, sabotage model and seed deck approved (cost = 1 AP + Clout), Dilemma model and seed deck approved, capstone framework approved (personalized archetypes, public play), company name config approved (selectable + `{COMPANY}` template). Spec drafted.
- `2026-05-27` — nilpointerr proposed a single-player narrative direction; user filed it as a 4th deferred mode ("Story Mode") rather than pivoting the v1 build. No changes to v1 scope. §4 (Game Modes) updated to include Story Mode in the deferred list.
