# Aqueduct bridge: round 2 handoff

> 2026-10-18, branch `iter/aqueduct-bridge`. Scope: the line from crag 1 to
> the bell spires, the skid fix on span 1, a way up onto the abutment, and
> torn feet on the hanging piers.

## Play it

```
cd /Users/davidkalina/Documents/Projects/zenscape-godot/.claude/worktrees/agent-a026b4b4b3da60a2f
./run-aqueduct-isle.command --foot-at=slabs --ledger=/tmp/bridge.json
./run-aqueduct-isle.command --foot-at=slabs --rune-knight --ledger=/tmp/bridge.json
```

New `--foot-at=` spots:
- `bridge_ramp`: on the rim's turf at the foot of the abutment's ramp.
- `bridge_span2`: on span 2's upper deck, just past its west torn edge,
  facing east toward slab 3.
- The existing `ring_slide` (the perch) and `ring_far` (the far crag) still
  work for the far half.

## The course this round builds round

The user's tuning (7ee36fc5) changed the course past the kicker, so the
ring-course note's sections 3 onward are out of date. The course as it
plays now, all proved through real input:

kicker → rings 5 and 6 → a sail through the standing stair ring 4 (x 223)
→ its throw → slab 3 (x 271) → a Q and the sail onto the perch → the slide
and ring A (boost 16) → slab 2 (x 366) → the far crag → the last slab and
ring → the bell spires' turf.

## What changed

All of it is in `studies/aqueduct_isle_bridge.gd`. The bridge now runs as
six legs that bend at the gaps. The lower deck sits at 40.25 the whole way,
so from the side it reads as one line.

| Handle | What it is |
|---|---|
| `bridge/abutment_ramp` | New. A rubble ramp of fallen walling up the abutment's north face from the rim's turf. It is 35.2° (60% of the way from `PilotMotor.SLOPE_SLOW` to `SLIDE_AUTO`), 2.6 m wide (from the wanderer's size), and swings 20° west so its foot stays on the turf at about (114, -26). That is 7 m off the plane's strip at x 107 and 4 m in from the rim. One clean box gives the walk. The abutment's north parapet is open where the ramp comes up. |
| `bridge/crag_pier` | New. A lone hanging pier past crag 1, under the throw from rings 5 and 6. |
| `bridge/span_2` | New. The second walkable span, in two tiers. Its line runs from stair ring 4 through slab 3's middle. The lower arcade is 5 piers and 4 arches with its deck at 40.25, the same as span 1. The upper arcade stands on it with 3 drop arches, its deck at slab 3 + `rise_2` (48.25). Ring 4 hangs where the first upper arch fell, over that pier's broken upper stub. The east torn edge is 0.9 m short of slab 3, so a hop off it slams the slab. The pier over the outcrop stands on the outcrop's turf on a footing rather than hanging. |
| `bridge/rock_pier` | New. A lone pier past slab 3, toward the slide rock. |
| `bridge/arcade_3` | New. A broken arcade (2 piers, 1 arch) whose deck has fallen, under ring A's throw. It sits east of the catch crag. |
| `bridge/far_abutment` | New. 2 arches and a torn deck up to the far crag's west flank. |
| `bridge/spires_pier_1`, `_2` | New. Two lone piers heading south from the far crag toward the bell spires. They stop at z 34, which is 4 m or more short of the spires' turf. The ferry's track at x 386 is 27 m away. |

Round 1's handles keep their names and coded transforms.

- **Skid fix:** span 1 (and span 2's upper deck) carry a silt bed: earth
  lumps with tufts in the channel, plus a `Silt` body marked soft ground
  (`PhysicsGround.mark_soft`, keep 0.5). The engine already had this
  feature; the bridge only turns it on. The bed covers span 1 from x 156
  to x 180 and span 2's upper deck from s 12 to s 46.
  - Why not move or lengthen the span: the throw from ring 2 holds 21 m/s,
    and let go he brakes at 18 m/s², a 12 m skid. Even the earliest
    landing (a coast) comes down at about x 171, and the kicker at x 183
    fixes the east edge. So no length or shift of span 1 can make room.
  - Raising the deck to catch him earlier would also catch everyone who
    sails over span 1 to the kicker.
- **Knight:** no new behaviour. `knight_line()` now starts his patrol at
  leg-1 s 34 (x about 154) instead of the west torn edge. His 28 m patrol
  covers the stretch where the throw lands, so he is around and ahead of
  you there.
- **Torn feet** (`_torn_foot`, used on every hanging pier): the last
  courses are snapped off along a slanted ragged line up to 2.2 to 3.6 m
  deep, the darker rubble core shows in the break, and stones hang under
  it. Only the upper, settled stones of a foot collide.
- **The stump:** its foot is now torn too and goes down to the same depth
  as its neighbours' feet. Its broken head has stones still standing on its
  north half and fallen voussoirs lodged on it.
  - It still has to stay low (top at 24.3). It stands right beside the
  floating stone's run-off, and the plane's `aq:east` token thread
  (128.8, 27.5, -8.0) runs 0.5 m off its face. Raising it would block that
  thread.
- **Knobs** (`bridge/line`): `rise`, `rise_2` (new: span 2's upper deck
  over slab 3), `hang`, `silt` (new: the share of pace a landing keeps),
  `seed`.
- `aqueduct_foot_route.gd` merges `Bridge.spots()` into the `--foot-at=`
  spots.

## Piece moves

None. Every course piece stands as the user saved it. No layout file,
chunk or authored motif changed (`layouts/` is clean in the worktree). All
drivers ran on `/tmp/bridge-r2/*.json` copies.

## Proof (headless unless noted)

- **Smoke:** PASS for `studies/aqueduct_isle.tscn` plain, with
  `--rune-knight` and with `--foot-at=bridge_span2`, and for
  `studies/zenscape.tscn`. The bridge builds in about 730 ms (round 1:
  230 ms).
- **Rim to bell spires, end to end** (`scratch/bridge/course2.gd --real
  --land --land2 --qs5=0 --lead5=0 --r5=2`, scene args `--foot-at=slabs
  --layout=/tmp/... --ledger=/tmp/...`): 25/25 checks, real input from the
  start spot.
  - The route: throw from ring 2 → land on span 1 → walk it → hop-slam
    the kicker → rings 5, 6 → ring 4 → land on span 2's upper deck →
    walk it → hop-slam slab 3 → perch → slide, ring A → slab 2 → far crag
    → last slab, last ring → the bell spires' turf.
  - It also passes 25/25 with a plain hop, and with landings aimed at
    x 165 on span 1 and s 30 on span 2.
  - The sail-over line (no landings) passes 17/17, sail-hop and plain hop.
- **Skid fix:** out of ring 2's throw he lands at x 170.9.
  - Before: the stick let go, he came to rest at x 181.6, 0.7 m from the
    torn edge.
  - Now: he comes to rest at x 173.5, 8.8 m from the edge (172.8 to 173.8
    across the variants).
  - On span 2 he lands at s 38 to 39 and comes to rest 5.9 to 7.7 m from
    the edge.
  - Sailing long and folding late can still put him down past the bed, at
    s 43 to 47. Then he stops 2.5 m from the edge or skids off onto (or
    past) slab 3. My driver's sail-fold variants fail for that reason.
- **Abutment climb** (`scratch/bridge/climb.gd`): from the start, round
  the abutment to the ramp's foot, up it in 4.7 s, east along the deck to
  its torn end, and back down to the turf. 5/5.
- **Knight** (`course.gd --knight`): he stands at deck height and patrols
  24.7 m of his 28 m line on its middle, turning at both ends. 5/5.
  - With `--rune-knight`, the land run puts him 13 m west of you, walking
    toward you.
  - On the walk to the edge, his wind shot knocks you (as designed), so
    the knight run doesn't reach the kicker unless you deal with him.
- **Crag 1 retry ring** (`scratch/ring_course/retry2.gd`): 3/3.
- **Handles** (`scratch/bridge/handles.gd` on a /tmp copy): all 12 pieces
  are tracked. A move is kept across a knob rebuild, `rise_2` lifts span
  2's upper deck, and the move and the knobs save.
- **Plane openings** (`scratch/bridge/opening2.gd`): these are clear:
  span 1's 3 arches, span 2's lower arches 3 and 4, all 3 of its upper
  arches, arcade 3 and the far abutment.
  - Span 2's lower arches 1 and 2 stand over the outcrop and the ring
    route's unused stair slab. Only those course pieces block them, not
    bridge stone.
- **Tests, run alone:** `test_kit_isle_landing.gd`,
  `test_world_scale_guard.gd` and `test_world_scale_fit.gd` PASS. No test
  references the bridge or the knight's line, so I know of no test this
  breaks. The full suite was not run.

## Stills (rendered, `-- --no-title`), judged by eye

From the north and the near island, the whole line reads as one broken
aqueduct. Span 2's two tiers carry it over the outcrop. The far half is
sparser, a few arches and lone piers, but stays on the line.

- `scratch/bridge/r2_side_north.png`: rim to slab 3, from the north.
- `scratch/bridge/r2_side_far.png`: slide rock to the bell spires, from the north.
- `scratch/bridge/r2_near_island.png`: the line from the near island's start.
- `scratch/bridge/r2_span2.png`: span 2 from above, ring 4's end, the outcrop under it.
- `scratch/bridge/r2_abutment_ramp.png`: the ramp from the west.
- `scratch/bridge/r2_torn_feet.png`: span 1's torn pier feet from below.

## Model budget (docs/art/model-budget.md)

The whole bridge now has about 104k stone triangles (round 1: 23.6k) and
about 255k growth triangles (round 1: 116k). It has about 4.9k collision
shapes (round 1: 1.36k).

| Piece | Stone (k tris) | Growth (k tris) |
|---|---|---|
| span 2 | 32.0 | 38.2 |
| far abutment | 9.1 | 12.0 |
| arcade 3 | 7.6 | 15.2 |
| ramp | 3.6 | 10.6 |
| each lone pier | 2.7 to 2.9 | 9 to 11 |
| silt beds (both) | 14.8 | 21.9 |

- **Import LODs: applies, on.** Every piece goes through
  `RuinLod.add_async`. Most of the new pieces are only seen from afar, so I
  expect roughly half their stone and nearly all their growth to drop past
  100 m.
- **Thinning growth: applied.** The new pieces build at 0.35 to 0.6 of the
  kit's growth detail. Before that cut, the lone piers had about 30k growth
  triangles each; the cut saved about 150k growth triangles. The silt lumps
  mostly don't grow moss. I estimate that is worth 0.2 to 0.4 ms of GPU time
  when the far half is in view; it is not measured.
- **Silhouette geometry, vertex-colour grime: apply, used.** The torn
  ends and torn feet are real geometry, and the grime is the kit's tone.
- **Hidden-face culling (`Build.cull`): doesn't apply as is.** It treats
  everything under the piece's y 0 as buried and deleted the hanging piers.
  A version with a ground callable that returns -INF could save an
  estimated 20 to 30% of stone triangles.
- **Sculpt-and-bake, rigid parts on bones, parallax:** don't apply.
- **Still open:**
  - The silt lumps' 15k stone triangles could be a single draped strip
    (about -13k).
  - The walling's per-course hulls are most of the 4.9k shapes. Merging
    them per course run would cut physics setup.

## Tools the harness lacked

- I had no way to read a `--knob=`-style override for a layout build from
  the command line, so I wrote /tmp layout copies with a `knobs` block.
- Nothing measured a "landing room" (land x, rest x) after a throw.
  `scratch/bridge/probe_skid.gd` and the `--land`/`--land2` checks in
  `course2.gd` do it.
- The old ring-course driver's `s4` uses deleted stair rings. `course2.gd`
  holds the current course's sections 3 to 6.

## Open questions for round 3

- **Span 2's late landings.** The throw from ring 4 comes down late on
  span 2's upper deck (s 38 of 48). A long sail folded late still skids
  off onto slab 3. Is that fine as the "sail over" path, or should the
  upper deck be longer?
  - Making it longer means moving slab 3 east, which is a course piece.
- **The far half is sparse.** Should arcade 3 or the far abutment gain a
  walkable stretch? The catch crag sits right under where the line would
  run.
- **Leg 6** stops 4 m short of the bell spires' turf. Should a last
  abutment land on the spires' north rim? That means touching the motif's
  turf, which the ring route avoided.
- **The knight's wind shot** knocks you as you walk to span 1's edge.
  Should the fight decide the hop, or should his patrol stop short of the
  torn edge?
- **Build time** is 730 ms, synchronous at load. Should the far legs build
  asynchronously, or only once he passes crag 1?
- **The Sundered-hall covered span** is still for a later round. Span 1 or
  span 2's upper deck are both candidates.
