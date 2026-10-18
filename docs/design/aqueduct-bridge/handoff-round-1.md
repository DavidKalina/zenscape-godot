# Aqueduct bridge: round 1 handoff

> 2026-10-18, branch `iter/aqueduct-bridge`. Scope: the near island's rim to
> crag 1 (ring-course sections 0 to 2, through the kicker).

## Play it

From the worktree:

```
./run-aqueduct-isle.command --foot-at=slabs --ledger=/tmp/bridge.json
./run-aqueduct-isle.command --foot-at=slabs --rune-knight --ledger=/tmp/bridge.json
```

The bridge is part of the isle's normal build. `--no-bridge` leaves it out.
With `--rune-knight` he patrols the bridge's walkable span.
`--rune-knight-at=aqueduct` puts him back on the aqueduct's deck.

## What's built

`studies/aqueduct_isle_bridge.gd`, called from `studies/aqueduct_isle.gd`
right after the foot pieces. It is one straight line from (119.5, -10.6) on
the near island to (182.3, -8.5), about 0.9 m short of the kicker's west edge (its snapped slab stops a little shorter).
It is built in the aqueduct's own look and module (Art's arches, piers,
spandrels, ivy, `Aqueduct._deck`/`_parapet_run`), with a wider deck (3.6 m
between the parapets' outer faces) and the Sundered hall's torn edges.
The deck's top is 2.6 m over the kicker's top (RingRoute.STEP_DOWN at the
wanderer's size), read from the layout file, so a hop off the end slams the
kicker.

| Handle | What it is |
|---|---|
| `bridge/abutment` | A coursed block on the near rim, north of the course's lane (z -7.2), with its back broken down. Its next arch's springer and deck are torn off at the rim, over the lodestone's floating stone. |
| `bridge/stump_1` | A lost pier's stump hanging under the big slab. Its top is about 2.7 m under the slab's bottom when its spring sinks it. |
| `bridge/gap_pier` | A hanging pier standing to its springing beside ring 2. The arch it carried over to span 1 is gone except its springers. |
| `bridge/span_1` | The walkable span: three arches on four hanging piers (11 to 18.5 m deep), torn at both ends. The deck runs 36.8 m, from x 145.5 to 182.3. |

- Each piece is tracked as kind `piece` through `scripts/layout_overrides.gd`,
  so F4 moves it.
- The build is registered as `bridge/line` with three knobs
  (`scripts/layout_knobs.gd`): `rise` (deck over the kicker, 2.6), `hang`
  (pier depth scale, 1.0) and `seed`.
- The flow now: rim, stone, slab, ring 1, ring 2. Then either sail over
  span 1 onto the kicker as before, or drop out of the throw onto span 1,
  walk to its east torn edge, hop off and slam the kicker.
- The deck's walking surface is one clean box (`_walk_box`). The settled
  slabs' own hulls step a few cm at each joint, and that lifted a runner off
  his feet for a frame. The stone draws and the box collides.
- **Rune knight:** no new behaviour. `rune_knight.gd`'s hard-coded aqueduct
  frame (`Art.AQ/HEAD/SNAP/DECK`) became `line_xf/line_head/line_snap/line_deck`
  plus `line_half`, defaulting to the aqueduct's. `setup(host, line)` takes
  a line, and `Bridge.knight_line()` gives span 1's line from where the piece
  stands.
- Plane: each of span 1's arches is `Art.CLEAR` wide (`WorldScale.opening(4)`,
  8.0 m at the defaults). A plane-wide way under each one, from 8 m under
  the springing up to it, is clear of colliders. The bridge stays east of
  x 117, clear of the landing strip by the parked plane (x about 107).
- No new RuinKit piece ids. Nothing changes in `ruin_kit*.gd`, KitLand or
  flora, so the motif editor is untouched.

## Piece moves

None. Every ring-course piece stands as the user saved it, and
`layouts/aqueduct_isle.json` is unchanged.

## Proof (headless unless noted)

- **Smoke** (`tools/smoke.py studies/aqueduct_isle.tscn`): PASS plain, with
  `--rune-knight`, with `--rune-knight --rune-knight-at=aqueduct`, and with
  the repo layout. `studies/zenscape.tscn` also PASS. The bridge builds in
  about 230 ms.
- **Course** (`scratch/bridge/course.gd`, extends `scratch/ring_course/course.gd`;
  run with `--real --to=3 [--land] [--plainhop] [--aim=x] [--qs2=n]` and
  scene args `--foot-at=slabs --layout=/tmp/... --ledger=/tmp/...`). Real
  input from the start spot:
  - `--land`: dropped onto span 1 out of ring 2's throw, came to rest on it,
    walked it, ran off the torn edge, hop-slammed the kicker, then the
    kicker's launch through ring 5 onto the outcrop. 13/13 checks, in 4
    variants: sail-hop or plain hop, landing aimed at x 165, 170 or 176.
  - The old line (`--qs2=0`, sail or plain hop) sails over span 1 onto the
    kicker and on to the outcrop: 9/9.
  - The crag 1 retry ring (`scratch/ring_course/retry2.gd`): 3/3.
  - With `--rune-knight`, the land run still passes 11/11.
- **Knight** (`course.gd --knight --kframes=7000`, scene args `--rune-knight`):
  he stands at the deck's height (40.25). He patrols 32.0 of the span's
  36.8 m end to end, turning at both ends, on its middle line (0.00 m off).
  He walks at the body's pace, about 0.6 m/s.
- **Handles** (`scratch/bridge/handles.gd` on a /tmp layout copy): all four
  are tracked. A move is kept across a `rise` knob rebuild, and the move
  and the knob save to the file.
- **Plane** (`scratch/bridge/opening.gd`): the three arch openings are clear.
- **Stills** (rendered, `-- --no-title`), judged by eye. From the side it
  reads as one arcade broken by a gap, not scattered pieces: the abutment,
  the gap pier with its springer beside ring 2, then span 1.
  - `scratch/bridge/final_side.png`: side, from the south
  - `scratch/bridge/final_north.png`: from the north-east, near island and gap
  - `scratch/bridge/start_v1.png`: the `--foot-at=slabs` start camera

## Tests

These were run alone, not as the suite.
- `test_kit_isle_landing.gd` failed with a pier I first stood on crag 1
  under the kicker: it took the only turf-up-to-stone spot the test finds.
  I dropped that pier, and the test passes.
- `test_aqueduct_isle.gd` (2 FAILs: "Station 2 alone ...", "East islet: off
  the meadow's east edge ...") and `test_aqueduct_isle_plane.gd` (1 FAIL:
  "R3 puts the camera back ...") fail the same with the bridge switched off.
  They come from the tree as it stands, not this round.
- These pass: `test_world_scale_fit`, `test_world_scale_guard`,
  `test_airship_ferry`, `test_serpent_route`, `test_foot_interactables`.

## Model budget (docs/art/model-budget.md)

The bridge has about 23.6k stone triangles (span 1 17.1k, abutment 3.9k,
gap pier 1.9k, stump 0.7k) and about 116k growth triangles (ivy, moss,
fringes), plus 1.36k convex collision hulls.

- **Import LODs: applies, on.** Each piece goes through `RuinLod.add_async`,
  so stone and growth thin with distance. From across the gap I'd expect
  roughly half the stone and most of the growth to drop.
- **Silhouette geometry: applies, used.** The torn ends, broken pier feet
  and ragged walling are real geometry on the outline, and flat faces carry
  no extra detail.
- **Vertex-colour grime: applies, used.** It is the kit's per-block tone and
  shelter alpha, with no textures.
- **Sculpt-and-bake, rigid parts on bones, parallax:** don't apply. The
  stone is procedural kit stone, nothing is skinned, and there are no
  textures.
- **The open saving:** growth is about 83% of the bridge's triangles.
  Thinning the moss and ivy on the deck tops and walling (fewer cushions and
  hangs) could save an estimated 60 to 80k triangles. I'd guess that is
  worth 0.1 to 0.3 ms of GPU time near the bridge; it is not measured.

## Tools the harness lacked

- A robust "run off this edge" helper. Rays slip between a deck's slab
  hulls, and a frame airborne at a joint ends the base driver's
  `run_to_edge` early. `course.gd` has `run_off` (three probes, a few
  airborne frames allowed).
- `hop_slam`/`lands_near` aim at a slab's centre, so they miss a slab that
  is landed on near its edge. `course.gd` slams once he is over the slab's
  footprint.
- The ring-course driver in the main checkout still names `added/air_ring_3`,
  which the user's last tuning removed. Its default `--qs2=1` fails on the
  current layout, with or without the bridge, because ring 2's boost is now
  9.75. `--qs2=0` passes.

## Open questions for round 2

- **The landing skid.** Dropped out of ring 2's throw, he lands about x 171
  and, with the stick let go, often skids all the way to the east torn edge
  before stopping. Should span 1 start further west or run longer, or
  should the throw be met by a covered span (the Sundered-hall dressing)?
  The knight's west half of the span is behind you when you land.
- **Crag 1 to the bell spires.** The same line could carry on from the
  kicker past the outcrop: the ring 5 and 6 throws hang in a broken arch,
  and a walkable span takes the outcrop's place.
- **The Sundered-hall covered span.** Span 1 is the natural one to roof:
  the knight's fight under a broken vault, with breaches out the side.
- **The abutment** has no way up from the island. A rubble slope like the
  aqueduct's head would make it walkable, but it would reach back toward
  the meadow, so check it against the strip first.
- **`stump_1`** must stay under the big slab's spring, so it reads as a lone
  post from some angles. Should it go, or should the slab move?
- A `rise` or `hang` knob rebuild doesn't re-line a knight already
  patrolling. He picks up the new line on the next launch.
