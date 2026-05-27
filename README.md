# Spite Driven Development

A parody boardgame about modern tech work. Local hotseat for 2–8 players. Hand-drawn stick-figure art. Built in Lua with Love2D.

## Status

Pre-alpha. Currently only the project skeleton and main menu navigation are implemented. See `docs/superpowers/specs/2026-04-21-spite-driven-development-design.md` for the full design.

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
- `docs/superpowers/` — design specs and implementation plans

## Credits

- abu — primary author
- nilpointerr — co-designer (Dilemma cards, LinkedIn Score concept)
- hotdogflavoredwater — collaborator
