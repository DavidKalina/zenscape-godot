# Pirate ship gray box: handoff

## Model in

`assets/models/pirate_ship.glb` now sails on the moving ship. `--ship-blocks`
brings the gray box back to compare. `solids()`, flight, gun and meter tuning are
unchanged: the bot's flight trace through the corridor is the same to the digit
with either look.

- **Guns and relic:** the 12 muzzles are read off the `Gun_*` empties, and match
  the gray box's numbers exactly. `Relic` sits at the deck's middle, on the finds
  row. Flash and smoke are still the gray box's cubes.
- **The break:** a burst throws the plate's `CrackPlug_*` shards with
  `SmashBreaks`' numbers (`KEEP`, `OUT`, `UP_V`, `SPIN`): on ahead of the plane,
  out from its line. Hit from outside, they go down the gun deck, stay between its
  walls and lie on the floor. Hit from inside, they go out to sea. They are drawn
  only and stay under their plug in her frame. The reseal puts them back whole.
  Knobs: `SHARD_*` at the top of `pirate_ship.gd`.
- **Rigging:** `visibility_range_end` 450 m, set in code.
- **Sway:** a roll of 0.8 degrees over 9 s and a pitch of 0.3 degrees over 13 s,
  on the model only (`SWAY`, `SWAY_S`). So the look drifts from the solids by up
  to about 0.3 m at her ends; nothing in play reads it.
- **Proved** by a bot on real input (`fly_boost`, `fly_roll`, `scratch/ship_model.gd`,
  not committed): stern to bow, bow to stern, then stern to bow again, each after
  a reseal on its own at about 301 m. Six bursts, no crash, relic counted. Stills
  looked at: approach, burst, gun deck, bow exit, from outside.
- **Frame time** (Mac window, 1440x900, vsync off), model against blocks, median
  ms: 16.0 / 14.8 at 180 m off the stern, 21.1 / 19.9 inside, so about 1.2 ms.
  p95 inside is about 31 ms with either look. No full-screen or PC number.
- **Unproved:** hand flying, shards and sway in motion (stills only), a shard
  passing near the camera at speed. At the ship start she is off the plane's left
  wing, so she isn't in the first view.

## What was built

`scripts/endless/pirate_ship.gd`: a block ship on an oval over the deep water
west of the Horn. She replaces the moored boat. Broadside guns fire at the
plane. A surge roll breaks the crack in the stern (or the bow), and the plane
flies the 110 m gun deck, takes the relic and bursts out of the other end. Seed
1, medium weight.

## Launch

```
cd /Users/davidkalina/Documents/Projects/zenscape-godot/.claude/worktrees/pirate-ship-greybox && python3 tools/play.py --no-pull -- --no-title --fresh --ship-start --full-meter
```

Drop `--full-meter` to charge the meter yourself. `--fresh` is the throwaway
save: this branch has no `--ledger=` flag. The plane starts 240 m off her beam,
16 m up, flying her way, already under fire. Her stern is behind her direction
of travel; both ends break.

## Knobs

- `scripts/endless/pirate_ship.gd`, top of file: route (`ROUTE_AT`, `ROUTE_LEG`,
  `ROUTE_R`, `SPEED` 9 m/s), gun deck (`TOY_WIDE` 8, `TOY_HIGH` 5, `LONG` 110),
  guns (`RANGE` 60 to 520 m, `ARC` 1.05 rad off abeam, `EVERY` 1.15 s, `TELL`
  0.85 s, `REST` 3 s), balls (`BALL_SPEED` 110 m/s, `BALL_DROP`, `BALL_R`,
  `BALLS` 24), near miss reach (`PASS_REACH` 14 m), a hit (`HIT_KEEP`,
  `HIT_SHOVE`, `HIT_YAW`), skim (`SKIM_SCALE` x8 within `SKIM_NEAR` 500 m),
  `RESEAL_FAR` 300 m.
- `scripts/endless/near_miss.gd`: a ball's pass scores as a `graze` with base 200
  (`BASE`), through `shot_pass`. The bank-on-full rule is at `# The bank:`.

## What I chose where the brief left it open

- **Moving solid:** three records in `LandArches.loose` (hull, stern, bow) whose
  `pos`, `cos` and `sin` are rewritten each frame. `plane_ground`, `_blocked`,
  the camera and the surge's `_strike` all read her without new code. A StaticBody
  under the ship serves the wing rays. The plane is never carried or pushed.
- **Replay:** both plates come back when the plane is 300 m from her. Nothing is
  saved. With `--full-meter` the meter refills at that moment.
- **Which end:** both plates break, so she can be entered at either end. The
  other plate stays stone, and the surge is held hot while the plane is in the
  corridor (`keep_hot`), so it breaks on the way out.
- **Corridor:** 18 m wide by 10 m high (toy 9 by 5, against a cracked room's 14
  by 9).
- **Balls in a surge:** a ball that reaches the plane while the surge is hot does
  nothing.
- **Guns:** they fire only within about 60 degrees of abeam, so her ends are safe.
- **Bank on full:** applies everywhere in the game, not only near her. It banks
  when meter + chain x multiplier reaches full, and doesn't re-bank on a full meter.
- **`boat-deck`:** now on Light Rock's south shelf at (2225, 3330), radius 90, and
  retitled. The id is unchanged. The new row is `ship-hold`, so the table is 34 rows.
- **Sails** are drawn with no collision. The plane flies through them.
- **Removed:** the boat's model use, solids, deck and `deck_at`. `assets/models/boat.glb`
  stays.

## What's proved

Bot flying through real actions (`scratch/ship.gd`, not committed):

- Balls fire and lead, and a held line gets hit.
- A hit drops the chain and knocks the plane 0.3 rad off line. No crash; meter
  unchanged.
- Passes score. Bot dodges measured 3 m clear for about 800 points and 11 m for
  about 300. Nothing scores past 14 m clear.
- The meter banks at once mid-skim.
- `fly_roll` on a full meter breaks both plates on the moving ship: 2.25 s inside,
  relic counted, no crash.
- The burst held at offsets to x 6 m and y 5 to 11 m (y is over the waterline; the
  deck's middle is 8). Runs at y 5 scraped the floor two or three times and still
  got through.
- It also works while she turns (x 3 m, from 300 m back) and entering head on at
  the bow, out at the stern.
- The plates came back on their own at 302 m, `--full-meter` refilled, and a second
  burst flew clean.
- At 57 m/s without a surge the crack is a crash, the plate stands, and the plane
  flies on from clear of the hull.
- The moved `boat-deck` was landed on and found.
- Smoke passes with and without the flags.
- Stills of the ship, crack, corridor, tell and ball were looked at.

## What's unproved

- **Hand flying.** The bot steers perfectly. Whether a person can dodge a ball,
  swing to the end of a moving ship and hit a 18 by 10 m plate at surge speed is
  for you to judge.
- **Ball speed and tell timing:** tuned by reasoning only.
- **Wheels on the deck:** one bot run scraped once and flew on, slowly, without
  sticking. Landing there isn't built.
- **A second lap of the route** and long runs: only the first turn was flown.
- The full suite was not run. `test_world_scale_guard.gd` passes.

## Worth knowing

- **The meter fills fast.** The bot filled it from three close passes in under 8 s.
- **One moment can nearly fill it.** Dropping to skim height banked 3,654 points
  in 0.6 s. The kind wasn't logged; it was probably a pull-out. That is existing
  scoring, now banked at once.
- **The corridor pays more than a full meter:** one run scored a thread and a
  "canyon run" inside and banked 14,879 points just past the bow, against 4,000 to
  fill. The meter stood at 0.93 straight after, so a burst nearly refills itself.
- **Finds grid:** a row anchored to the ship stays in the grid cell of her start;
  it streams correctly while she keeps within about 2 km of it, and the route does.

## Existing tests

No test in `tests/` touches the near-miss code, the finds table, the boat or the
coast by name (grep). I expect none to break, but the suite wasn't run.

## Tools

The harness lacked nothing. One trap for drivers: `study._launch` makes a new
plane object, so re-read `study.plane` after it and after a crash.

## Models

All blocks with no model, so the tricks in `docs/art/model-budget.md` don't apply
yet. The Blender round should assess them; silhouette geometry and vertex-colour
grime look like the likely ones.

## Contract for the model

Her frame: metres, origin at the waterline amidships, -z bow, +z stern, +x
starboard, y up. Values are at the default sizes; `solids()` in
`pirate_ship.gd` is the source. Corridor width and height come from
`WorldScale.opening`.

**Ship:** hull 24.75 m beam by 113 m long, draught 6 m, top deck at y 15. With the
stem, about 129 m overall.

**Gun deck (corridor):** x -9 to 9, y 3 to 13, z -55 to 55. Keep it clear; visible
guns and lamps inside must stay within 1 m of the walls. Middle at y 8.

**Cracks (breakable plates):** each 18 by 10 m, filling the corridor's end.
- Stern: x -9 to 9, y 3 to 13, z 55 to 56.5.
- Bow: x -9 to 9, y 3 to 13, z -56.5 to -55.

**Relic:** at (0, 8, 0), ring opening 10 m.

**Guns:** 12, six a side at z -40, -24, -8, 8, 24, 40. Muzzle at x ±15.375, y 8. They
fire outward.

**Collision boxes (x0, y0, z0 to x1, y1, z1):**

| Part | Box |
|---|---|
| Hull below the deck | -12.375, -6, -56.5 to 12.375, 3, 56.5 |
| Port wall | -12.375, 3, -56.5 to -9, 13, 56.5 |
| Starboard wall | 9, 3, -56.5 to 12.375, 13, 56.5 |
| Deck | -12.375, 13, -56.5 to 12.375, 15, 56.5 |
| Poop | -12.375, 15, 30 to 12.375, 24, 56.5 |
| Forecastle | -12.375, 15, -56.5 to 12.375, 20, -38 |
| Stem, inner | -9, -6, -64.5 to 9, 3, -56.5 |
| Stem, outer | -4.5, -6, -72.5 to 4.5, 3, -64.5 |
| Foremast | -1, 15, -23 to 1, 55, -21 |
| Mainmast | -1, 15, 5 to 1, 59, 7 |
| Mizzen | -1, 24, 41 to 1, 51, 43 |

The stem stays below y 3 so the bow's exit is clear. Anything the model adds
outside these boxes is look only unless it is added to `solids()`.
