# Movement items, round 1 (`items_move`, 2026-10-15)

Three verb items from the items contract (`items-contract.md`). Each one
changes how a gap or a wall reads. They are catalog entries whose effects are
read live from `RunState.holds(id)` every tick, so an item picked up partway
through a layer works at once and death takes it away. The feature is on by
default. `--no-items_move` or `--loot=off` turns it off.

## Play it

```sh
/Users/davidkalina/Applications/Godot.app/Contents/MacOS/Godot --path . res://studies/run_layer.tscn -- --no-title --shape=sprawl --seed=11 --give=grapnel,cloak,picks
```

Give them one at a time (`--give=picks`) to feel each on its own.

| id | name | how |
|---|---|---|
| `grapnel` | Grapnel | **V** (pad **RT**) throws a hook up and ahead. It bites a lip (a wall whose top is within 1.2 m of the hit) or the underside of an arch or beam. You then swing on the line as on a swing rope: the stick pumps and steers, Jump lets go with the timed boost, crouch drops. **Hold V** to haul up the line. Hauled up to a lip, you climb onto it with the motor's own ledge climb. You get one throw per airtime; the ground, a ledge, a wall or the water gives it back. |
| `cloak` | Drift Cloak | **Hold Jump while falling** and the felt cape spreads. The fall is caught to 2.3 m/s, air steering is 1.8x, and the landing is never a fall (no stun, no hearts). Let go of Jump and you drop. Pressing Jump again still opens the sail. |
| `picks` | Rock Picks | On a wall slide (jump into a wall, stick held into it), the picks bite every 0.3 s and pull you up. You get 4 pulls per airtime, then you slide. Once the wall's top is past your hands, you are handed to the lip and climb on. |

## What each opens

The sizes come from the rig check below and use the wanderer at size 1.

- **Picks**: walls up to about 4.5 m. Without them the top is a pump jump
  plus your hands, about 2.7 m. With them a 3.6 m wall is a run, a jump, two
  or three bites and a climb, about 1 s.
- **Grapnel**: lips and soffits up to 9 m away (`REACH`), above you by at
  least 1.3 m. Hauling up a 5.5 m wall from 4 m back takes 1.6 s from the
  press. A run, a jump, a throw at a 5 m beam and a timed release carried
  you 14.5 m; a plain jump carries 4.2 m. It only works where something
  above can take the hook. Open sky over the void has nothing to bite, so
  the best use on a gulf is to hook the far isle's lip and haul up its face.
- **Cloak**: a 12 m drop is 6.7 s of drift and lands unhurt. Without the
  cloak, the same drop stuns and costs a heart. Across the ground it covers
  about 2:1, against the sail's 3.7:1, so it never crosses a gap the sail
  can't. It is the sail's opposite: slow, straight down and placed. It also
  works where the sail is barred: by walls, in shafts, and after a kick.

## A design note: the sail already glides

The pocket sail (`scripts/pocket_sail.gd`) is a base move in the run, so a
"glide cloak" that glides further would only make the sail redundant, or
trivialise the void. The cloak is a Spelunky-cape float instead. It catches
your fall straight away, keeps the platformer's air control and makes landings
safe. If the user wanted a glide upgrade, the knob is `CLOAK_FALL`, or the
cloak could change the sail's own numbers instead.

## Knobs (`scripts/roguelike/items_move.gd`, `grapnel_rope.gd`, `drift_cloak.gd`)

| knob | default | what |
|---|---|---|
| `REACH` | 9 m | the hook's reach |
| `PITCHES`, `TURNS` | 12 x 9 rays | the throw's aim fan, round your facing |
| `LIP_BITE` / `HOOK_OVER` | 1.2 / 1.3 m | what counts as a lip / how far above you |
| `HAUL` / `TAUT` | 4.2 / 14 m/s | the haul up; slack taken up so the swing clears the ground |
| `CLOAK_FALL` / `CLOAK_CATCH` / `CLOAK_STEER` / `CLOAK_AFTER` | 2.3 m/s, 55 m/s², 1.8x, 0.08 s | the cloak |
| `PICKS` / `PICK_UP` / `PICK_EVERY` | 4, 3.8 m/s, 0.3 s | the picks |
| catalog `price` / `rarity` | 12/3, 8/2, 10/2 | for merchants and altars |

## Code

- New files: `scripts/roguelike/items_move.gd` (the controller around the
  study's tick), `grapnel_rope.gd` (extends `swing_rope.gd` and adds the
  haul, the taut line, keeping the body out of solids, and the handoff to the
  ledge), `drift_cloak.gd` (the cape mesh, hung under the figure's `_tilt`).
- Hooks marked `# [items_move]`: `item_catalog.gd` (3 entries) and
  `run_loop.gd` (4 lines: created in `setup`, `before(delta)` in play,
  `after(delta)` in `after_tick`).
- `pilot_motor.gd` is untouched. The controller nudges the motor between
  steps: the cloak caps `velocity.y` and resets `_fall_top`, and the picks
  set `velocity.y` on a bite. It calls the motor's private `_hang_on` and
  `_climb` for the pull-overs, so a rename there breaks these items.
- The grapnel's input action `item_grapnel` is added at runtime (V and the
  pad's RT), not in `pad.gd`'s table.

## Checks (headless, uncommitted, `scratch/items_rig.gd`)

The real run loop, with `--give=` and input pressed as actions. A rig of boxes
was built 60 m over seed 11's start; the found terrain sites were too
irregular to compare like for like.

- Picks: the 3.6 m wall climbed onto in about 1 s. Without the picks, he
  slid down.
- Grapnel: hauled up the 5.5 m wall and stood on top at frame 96. Without the
  item, V does nothing. The air throw and swing above went 14.5 m.
- Cloak: drifted down 12 m at 2.68 m/s at most, not stunned. Without it:
  18 m/s, stunned.
- The same checks passed in a rendered window. Smoke: run_layer sprawl
  seed 11 (900 frames, with all three items) and `--loot=off`, 0 errors.

## Rough

- The cape is a stand-in: a CPU-built felt grid with no cloth sim. It reads
  as a spread wing behind him from the play camera, but the hat hides its
  top. It needs a proper look pass, judged on the painted turf.
- The grapnel has no throw pose. The hook (iron tines) and line fly out
  from his hands, with a whip sound and a puff where it bites. On the line he
  takes the swing rope's hang pose, and the slack hangs below him as the
  rope's tail.
- The picks have no visible picks in his hands. Each bite is a stone-chip
  puff and a tick. The climb uses the wall-slide pose.
- The aim is automatic, round your facing. There is no reticle or tell for
  "something to bite" before you throw, and a miss flies out and drops back.
- The hook bites any collider, including a rope bridge's or a serpent's. It
  hasn't been tried on moving ground.
- Only proved on the rig and on seed 11's real walls (the haul, earlier). It
  hasn't been run across real gulfs or tuned against real motif routes.
- A pre-existing `_update_card` "hoods" script error shows in rendered runs
  of run_layer; it isn't from this round.

## Tests it may touch

No test was run (prototype round). Nothing in the motor or swing rope
changed. While a run doesn't carry the items they do nothing, so the existing
pilot and rope tests should be unaffected. A test that asserts the catalog
holds only `wallrun` would break.
