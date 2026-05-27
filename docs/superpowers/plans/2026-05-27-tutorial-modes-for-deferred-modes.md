# Tutorial Modes for Deferred Game Modes — Plan Stub

> **For agentic workers:** This document is a placeholder plan. Each section below is a partial plan that should be FILLED IN when its underlying mode (Floor / Ladder / Hybrid / Story) is actually implemented. The structure mirrors Plan 11 (Sprint Tutorial). Do not begin implementing any tutorial here until the parent mode itself is built.

**Status:** STUB. No code changes accompany this document. Its purpose is to keep the tutorial design decisions made in Plan 11 documented for future application to the four deferred modes.

**Why a stub:** Tutorial mode for each game mode is best designed AFTER the mode's mechanics stabilize. Writing a detailed tutorial plan before the underlying mode exists would waste effort (the steps would need rewriting based on what actually got built).

---

## Shared Pattern from Plan 11

Plan 11 (Sprint Tutorial) established a reusable pattern. Future mode tutorials should follow it:

1. **A new MODES entry.** Each tutorial gets its own selectable `id`/`label` (`floor_tutorial`, `ladder_tutorial`, `hybrid_tutorial`, `story_tutorial`).
2. **Tutorial mode flag.** `session.config.tutorial_mode` already exists; set it during mode-select short-circuit.
3. **Skip config/player_setup.** Tutorials configure their own sane defaults (1 player, generous AP, deterministic deck, etc.). Mode-select transitions straight to the relevant game state.
4. **Per-mode tutorial module.** `src/game/tutorial_<mode>.lua` mirroring `src/game/tutorial.lua` — list of steps with `text` + `advance_condition` + `manual_advance`.
5. **Reuse the overlay.** `src/ui/components/tutorial_overlay.lua` is mode-agnostic; constructor takes the tutorial state. New tutorial modules construct compatible state objects.
6. **Per-mode game state hooks.** The state for each mode (when built) instantiates the right tutorial + overlay, sets per-action flags as the user clicks, and calls `Tutorial.advance(state, gs)` after each click.
7. **Tests.** Each tutorial's spec follows `tests/spec/tutorial_spec.lua`: starts at step 1, manual_advance bumps, advance walks past auto-advance steps when conditions are true, is_complete works.

---

## Section A — The Floor (Monopoly-style office loop) Tutorial

**Prerequisite:** Floor mode itself must exist (game mode in `Session.MODES` with `available = true`, real game state implementing roll-and-move on a tile loop).

**Anticipated steps (draft):**

1. Welcome + this is the office floor (32 tiles around an open-plan board).
2. Each turn you roll a d6 and move that many tiles. Watch your token.
3. Click Roll to roll the die.
4. You landed on a Desk tile. The first time you land on an unclaimed desk, you can claim it for 1 AP.
5. When others land on your desk, they pay you "focus tax" (Credit/Clout). That's how you make money on the Floor.
6. Some tiles are special: Kitchen (draws a Watercooler Gossip card), Conference Room (action menu), HR Office (Chance card).
7. Reach the elevator to advance a sprint level.
8. Try the Sabotage menu — same as Sprint, you can hurt other players.
9. End Turn to pass the dice.
10. Tutorial complete. Try a real game.

**Open questions to resolve when Floor lands:** What does "winning" look like in Floor specifically? How do promotions interact with movement?

---

## Section B — The Ladder (Per-player promotion tracks) Tutorial

**Prerequisite:** Ladder mode exists with per-player vertical tracks, no spatial board, pure action-point spending.

**Anticipated steps (draft):**

1. Welcome. This is your career ladder. Each rung is a Title.
2. On your turn you spend AP on actions: Ship Project, Schedule Meeting, 1-on-1, Sabotage.
3. Ship Project: takes 2 AP, advances you one rung (or earns Credit toward the next rung — TBD when Ladder is built).
4. Schedule Meeting: 1 AP, +2 Clout, +1 Dilemma draw.
5. 1-on-1: 1 AP, targets a specific player — drains their AP or builds an alliance (mechanics TBD).
6. Sabotage: same as Sprint, but higher impact since there's no board to hide on.
7. End Turn.
8. Try a Ship Project to advance your rung.
9. Reach C-suite to win — or rack up the most LinkedIn Score and try to "lose with style."
10. Tutorial complete.

**Open questions:** How does the Ladder map back to the shared end-trigger system? Does Credit still exist or is rung the only currency?

---

## Section C — Hybrid (Floor + Ladder) Tutorial

**Prerequisite:** Hybrid mode exists. By spec it's the union of Floor (central spatial board) + Ladder (per-player career track on the sides).

**Anticipated steps (draft):**

1. Welcome. Hybrid combines Floor's office loop with Ladder's career tracks.
2. Your turn: roll-and-move on the Floor, then at the end of the turn convert any Credit earned to ladder rungs.
3. Sprint cycles (planning → turns → retro & promo) still apply.
4. Some Floor tiles (e.g., the CEO corner) directly grant rung advancement.
5. Sabotage and Meetings work as in Sprint/Floor.
6. End Turn to pass the dice.
7. Tutorial complete.

**Open questions:** This is the most complex mode. Worth more steps. Maybe 18-20 in the final tutorial.

---

## Section D — Story Mode (single-player narrative) Tutorial

**Prerequisite:** Story Mode exists with NPC cast (HR, CEO, colleagues), multi-choice scenes, relationship stats.

**Anticipated steps (draft):**

1. Welcome to MegaCorp. You're a new IC; the rest of the cast is the team you'll navigate.
2. The HR Director, the CEO, your manager, and your colleagues have relationship meters with you.
3. Each scene presents 3-4 multi-choice options. Your choice affects: relationship meters, your LinkedIn Score, the story path.
4. Try the first scene: "Your manager Slack-DMs you about a missed deadline." Pick option A.
5. See how your manager's meter shifted? Some choices have hidden tradeoffs.
6. Career advances through career-level milestones (IC1 → IC2 → ...), one chapter per level.
7. There's no AP / sabotage / Kanban in Story Mode — pure narrative.
8. Reach the final chapter to see your full LinkedIn profile retrospective.
9. Tutorial complete.

**Open questions:** Story Mode is a much larger writing project than the other tutorials. Its tutorial is probably less needed (the multi-choice UI is self-explanatory) — could ship as a 3-step "welcome / pick / see consequence" demo.

---

## When This Plan Becomes Real

For each section above, when the parent mode ships:

1. Copy the section into a new plan doc dated when work begins (e.g., `2026-XX-XX-floor-tutorial-mode.md`).
2. Refine the step list based on what the mode actually does (the drafts above are best-guess).
3. Write `src/game/tutorial_<mode>.lua` mirroring `src/game/tutorial.lua`.
4. Wire it into the new mode's game state (mirror Plan 11 Task 3).
5. Add to `Session.MODES` and `mode_select` short-circuit (mirror Plan 11 Task 1).
6. Test it (mirror `tests/spec/tutorial_spec.lua`).

---

## Why Stub Instead of Detail

Each deferred mode's tutorial will be 8-15 step lines plus the same boilerplate that Plan 11 already established. Writing 4 sets of speculative steps now would produce text that has to be substantially rewritten when the parent mode lands. This stub captures the design pattern, flags the open questions, and reserves slots for future plans without spending implementation budget on guesses.
