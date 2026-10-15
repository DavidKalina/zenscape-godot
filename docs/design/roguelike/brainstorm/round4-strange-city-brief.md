# Round 4 brainstorm brief: strange inhabitants of the city (2026-10-14)

> Handoff for a cloud agent. This round produces design cards only, no
> code. The user reads the results in the morning.

## Setup

- Repo `zenscape-godot`. Check out branch `roguelike` (pushed 2026-10-14
  with everything below).
- Make a branch `brainstorm/round4-strange-city`.
- Write everything under
  `docs/design/roguelike/brainstorm/round4-strange-city/`.
- When done, commit and push that branch. Don't push to `roguelike` and
  don't merge.

## Read first

- `docs/design/roguelike/game-v1-brief.md`, all of it. It is the game.
- `AGENTS.md`, especially "Art direction" and "Subagent models".
- `docs/design/roguelike/motif-brief.md` and the `motif-brainstorm` skill in
  `.claude/skills/motif-brainstorm/`, if present. Follow its card format.
- `docs/design/roguelike/brainstorm/round3-olmec-city/README.md`: the last
  round, the Olmec city kit.
- The Olmec body: `headless-body-round1.md`, `headless-body-round2.md`.
- Light and sight: `beacons-light-sight-round1.md`.
- The `city-*-round1.md` docs, for what exists.
- `ideas-enemies.md`, `ideas-traps.md`.

## The problem

The game is an abandoned Olmec city underground: a Spelunky-like pushed
somewhere fresh, where you climb upward, and it's brutal but fair (4 hearts,
fall damage, the void kills).

Right now it's very Olmec-heavy: the headless Olmec body is nearly the whole
threat ecosystem. The user expects to cut him to one or two per layer, and
wants new inhabitants, traps and places that balance him while still
fitting the abandoned Olmec city.

## The bar

These are the user's own words, and the most important part of this brief.

The user hates cliché game mechanics. They explicitly rejected "latch on,
shake them off" and generic mob packs, such as Spelunky's snakes, bats and
spiders reskinned.

The model is **Lethal Company**: really unique enemies with unique patterns
and weird mechanics.
- The coil-head only moves when unwatched.
- The bracken backs off if stared at.
- The hoarding bug is fine until you touch its stash.

The other model is the user's own Olmec: a body hunting its head, then
insane once it has it, climbing and chasing.

Every card must have:

1. **One strange rule** the player learns, usually by dying to it once.
2. **A readable tell.**
3. Ideally **a change of state or escalation**.
4. **A hook into the game's systems**: light and the torch, sound, greed
   (runes), breakables, knock-back near edges, the Olmec himself, carrying.
5. **Rule 0**: a clever player can exploit it as a tool, at real risk.
6. **Co-op in mind**: it should make a story when two friends play.
7. **Fit**: Mesoamerican / Olmec, weathered and real per AGENTS.md "Art
   direction" (menace from material, weight and restraint; no horns,
   spikes or edgy red glows).

Cut any card that's a stock genre mechanic. If something stock is
unavoidable, say so plainly.

## Seed ideas from the user's chat

Develop, push or replace these. They are not sacred.

- **The Jade Mask** animates whatever it lands on: statues walk, pillars
  lean. Knock it off and it seeks the next host. Every statue is a
  possible enemy, and you can lure it onto something useful.
- **The Sun-Keepers** move only in light, an inverted coil-head. The torch
  wakes them, so you cross them dark, and blind, over the void.
- **The Tithe-Taker** ignores you until you carry more than N runes, then
  follows the richest player. Feeding it calms it, at the cost of the runes.
- **The Echo** is silent itself. It records your sounds and replays them
  elsewhere a few seconds later, and the Olmec goes to the noise. It's a
  danger and a decoy.
- **The Ballplayers** are ghost teams still playing the ballgame, and you're
  the ball. Through the ring is a payoff (a shortcut, a rare collectible);
  a missed pass flings you toward the edge.
- **The Sleeper**: the plaza is its back, and it breathes, so the floor rises
  and falls. Noise across the whole layer wakes it.

## Shape of the round

Spawn about 5 subagents in parallel, each with a different lens:

1. **Things that hunt you**, each with one strange rule. (Opus)
2. **Things that change the level**: movers, rebuilders, the living
   architecture. (Opus)
3. **Things you exploit**: neutral or passive inhabitants that are mostly
   tools and only sometimes threats. (Opus)
4. **Traps**, fresh ones in the Olmec idiom, not dart walls and spike pits
   unless twisted. (Sonnet)
5. **Non-Olmec places for the city**: motif cards for an underground
   Mesoamerican city that aren't about him, each with its own inhabitant or
   trap. For example a cenote, a mercury pool, steam baths, a jade mine, an
   observatory. (Sonnet)

Each subagent writes one file of 5 to 8 cards.

Then write a `README.md` with:
- one table of every card (id, lens, one line, its strange rule, rough
  build cost);
- your **top 6 picks**, the most unique, buildable and Rule-0-rich, with
  why;
- the cards you cut for being cliché, one line each.

## Finish

Push the branch. Your final message: the branch name and the top 6 picks,
one line each.
