# Plane ground scale (demo)

On its wheels the plane is drawn bigger, so the pilot in the cockpit is the
wanderer's size. In flight it is exactly the old toy size. Code:
scripts/plane_ground_scale.gd, wired in studies/kit_isle.gd (the aqueduct isle
game), with `size`/`lift` on scripts/glide_camera.gd (1 and zero in flight).

- Factor 2.4 by default. Measured: the wanderer is 0.44 m from shoulders to cap
  top and the cockpit pilot is 0.185 m (2.38). Shoulder width gives 2.2.
- `--plane-ground-scale=<x>` sets it. `=1` turns it off: every change falls
  back to the old numbers.
- Driven by ground speed: full size at or under 3 m/s, flight size from 10 m/s
  (ROLL_TOP is 11). Eased over 0.22 s and capped at 1.4x the full change a
  second. Off an edge and dipping it shrinks fast (0.12 s). Flying, it is 1.0.
- Scaled about the wheel contact (PlaneStrip WHEEL_DROP/WHEEL).
- Follows the scale: chase distance, height and look point; the hop-in start
  and the hop arc; the hop-out spot (left, between the lower wing and the
  tailplane); the board reach and the walker's keep-off column; the parked
  footprint check when picking the plane's home.

Open issues:
- On the ground the wings clip trees and walls, and the roll's blocked/bump
  checks still use the flight-size plane.
- The landing mark is hidden on the kit isle, so it wasn't touched. The scarf
  doesn't scale (its width/length).
- The stone plane (`--stone-plane`) is scaled about the wooden plane's wheel
  point. Not checked.
- Rolling off an edge slowly can show a short (~0.3 s) shrink during the dip.
- Not tuned. Only the parked view was captured; the mid-roll blend hasn't
  been seen yet.

Where the cheat can show (keep these in mind for later features):
- Planes seen from on foot in the air: CPU traffic flying low past the
  wanderer, or a landing watched from the ground, reads as a model plane.
  Traffic seen from on foot may need the same cheat.
- Mid-air hand-offs: ejecting into the pocket sail or being knocked off by the
  dragon swaps the ~0.5 m cockpit pilot for the 1.19 m walker in the air.
  Each one needs something to hide the change (a puff, a tumble).
- Built spaces: anything the plane parks in (hangar, strip, dock) is sized for
  the ground scale; anything flown through is sized for flight
  (scripts/world_scale.gd `span`, `gap(room)`).
- Ask scripts/world_scale.gd (sizes) and scripts/plane_ground_scale.gd (the
  size right now) how big the plane is; don't hard-code either in new code.

## Merge with main (merge/scale-into-main)

Main's walkable pieces, lanterns and sound were placed against the old
aqueduct isle. Fix-ups:
- **Rope route** (scripts/interactables/aqueduct_foot_route.gd) is now
  laid out from Art:
  - the ropes' z: the near and far rims at ROPE_X (`near_rim`/`far_rim`
    on Art.NEAR/FAR). The gap there is 30.2 m now, 16 on main.
  - the beams lie on the east parapet (TOP+DECK). That makes the ropes
    9.3 m long, not 5.6, and a plain release reaches 26.5 m
    (measure_rope_reach). Three ropes are 17.6 m apart.
  - the ferry spans rim to rim at x 110, at main's pace (a 25 s period).
  - the --foot-at spots.

  test_foot_interactables's ferry and far-island z checks now read the
  route's values, with main's margins.
- **Balustrade floater** (audit): a baluster whose top the wear broke off
  stood on the stair's treads, which its Build couldn't see. The Build's
  `terrain` is now the treads (`floor_at`). The rail was already derived
  from the stair.
- **Drift up** (test_aqueduct_isle): main's way-in lantern (night lights)
  stood on the drift's summit landing. With the crown 4 m higher, the drift
  now comes down onto the summit and landed on the lantern. Moved to 15
  degrees (`NIGHT_WAY_IN`). The gate's two lanterns follow Art.GATE; they
  were in open sky. The moveset is unchanged.
- **Plane sound check**: main's sound round 1 voices the plane in KitAudio
  (GlideAir `voiced` off), so test_aqueduct_isle_plane now checks KitAudio's
  rush and engine goals. Main has the same stale check.
- test_stair_clouds_isle passes after the cleanup merge, and
  test_manual_landing_game passed 3 of 3 alone.

Related set (44): 41 pass. The 3 known base failures remain.

## Bell spires fit (fix/bell-spires-fit)

The south stack's bell gable and the low stack's arch (RuinKit.arch, 14.6 m toe to toe at ARCH_SPAN 8.4) hung off 6-7 m stack tops. Those two stacks now grow from `RuinKit.arch_foot()` until their tops hold the arch plus ARCH_SEAT (r 4.0/4.6 -> 10.5). PASS_ROOM went 4.0 -> 5.2 so no gap narrowed (least 10.05 m, now 10.09). The gable bridge is now 22.8 m (was ~13). The hero (r 8.2) wasn't grown.

## Scale cleanup (feature/scale-cleanup)

Closes the Open list of the section below, at ratio 1.0. Where they
disagree, this one is current.

- **Sundered overgrowth.** The hits weren't the beam spots:
  - the lane: column ivy pushed round the outer columns' bases, and the
    kit's own fringe hanging off a low tie (in the bare build too);
  - the breaches: architrave curtains over a broken arch.

  A RuinKit Build now carries `clear` boxes (`kept_clear`) and every strand
  stops at one. The Sundered dress clears the lane under `LANE_Y`'s top and
  each flyable breach's corridor (`Hall.breach_box`, taken out of `bay`).
  The beam and tie curtain spots now derive from ROW_Z and COLUMN_R.
  test_sundered_hall: lane 0, breaches 0 of 54845 (limits unchanged).
- **The fifth failing test** didn't come back. Two runs of the related set
  plus the five extras that round named (cluster_motifs, hand_landing_exit,
  island_pack_ruins_archipelago, lodestone_study, pierced_isle) failed only
  the three known base tests and, before the fix, sundered_hall. That
  round's 44 left out one name. By elimination it was isle_card_marks,
  isle_teardown or manual_landing_game; all three pass each time here.
- **Stair to the clouds** (`_collide_as_drawn`): a steep cliff prism on a
  drawn wall is cut to WALL_KEEP under the lip of its wall.
  - The wall is matched by lip height. Matched by nearness, a landing's
    step-down wall was taken for the wall rising behind it, and landing 4
    fell.
  - On a wall over LIP_WALL the prism also keeps its foot up to FOOT_KEEP
    (2 m, inside the drawn foot's kick). Without it the lawn probes by the
    summit pad found a gap.
  - Short walls keep only the lip band. A foot band there broke landing 4.
  - The heightfield trimesh is untouched: it is one shape in the audit.
  - Mesa: 1024 shapes off -> 355; a metre off: 238 -> 13 (12 prisms and
    the trimesh).
- **Drowned nave.** Its prisms aren't by the basin. They line the grand
  stair's cut to the apse (local x 117-127, z +-2.5), and their bottoms
  hung 1.5 m under the cut's turf, where the stair's bedded blocks face
  down. KitLand `island` takes `prism_drop`, and the nave asks
  PRISM_RIM_DROP. 64 -> 3 (two small arcade hulls 0.9 x 0.6 x 0.9 and one
  under 1 m).
- **Airship gondola**: `AirshipBuild.gondola_hulls()` is the drawn hull's
  half shell (stations shared with the mesh) and the cabin with its roof.
  None of it is off now. The envelope capsules are still 0.3-1 m off at
  their caps (6 shapes over the three ships).
- **Rune serpent**: still skipped by eye (shader-bent), 13 capsules.

**Audit** (tools/collision_audit.gd now also prints the metre-off count by
isle): 1504 shapes off, 353 a metre off (340 without the serpent's 13) ->
771 off, 67 a metre off (54 without the serpent). What's left, a metre off:
- colonnade 18;
- stair mesa 13;
- sundered gorge 11;
- cloister 5;
- near island cliffs 3;
- bell spires 2;
- nave 2.

**Tests** (headless): 38 of 41 in the related globs and 5 of 5 extras pass.
The three failures are the known base ones: aqueduct_isle_look (23 plants
off turf), collectibles_pickup (engine errors only), moments_world (engine
errors only).

**Open:** nothing flown by a person at 1.0 yet. The stair's lawn by the
summit pad has a drawn gap at about (85.5, 16.7) in the study: neither turf nor wall,
the skirt seen below. The foot band covers it in collision.

## Opening ratio 1.0 + collision audit (feature/opening-ratio-1)

The user flew opening-ratio-2 and said it still felt like there were
invisible hitboxes, saw a stone hanging in a broken arch, and asked for
ratio 1.0. Where this section disagrees with the ones below, it is current.

**Ratio 1.0** (scripts/world_scale.gd `RATIO := 1.0`): every flown opening is
its toy width x the plane exactly (2x at plane 2); the SNUG floor never acts
at the knobs. Widths at plane 2 (past each wingtip = (w - 2.8)/2):

| Opening | Toy | 0.95 | 1.0 |
| --- | --- | --- | --- |
| THREAD | 3.5 | 6.65 | 7.0 |
| Gothic ARCH_SPAN | 4.2 | 7.98 | 8.4 |
| Lancet WINDOW | 3.6 | 6.84 | 7.2 |
| Hall lane | 4.0 | 7.6 | 8.0 (ROW_Z 13.4, WALL_Z 16.4) |
| Hall breach corridor | 3.6 | 6.84 | 7.2 |
| Hall broken ARCH | 5.2 | 9.88 | 10.4 (crown lost, as before) |
| Hall BAY | 8 | 11.08 | 11.6 |
| Kit aqueduct CLEAR | 4.7 | 8.93 | 9.4 |
| Aqueduct isle arches | 4.0 | 7.6 (deck 9.6, END 69.2) | 8.0 (deck 10.0, END 72.0) |
| Drowned nave crossing | 4.46 | 8.47 | 8.92 |
| Colonnade portal | 6.16 | 11.7 | 12.32 |
| Token GAP_ROOM / wing box | 3.2 / 3.5 | 6.08 / 6.65 | 6.4 / 7.0 |
| Sarsen / great trilithon | 3.4 / 4.6 | 6.46 / 8.59 | 6.8 / 8.93 (trilithon capped at sarsen + TRILITHON_RISE) |
| Ring arch | | 15.0 | 15.0 (RING_MOST cap kept) |

Caps and floors kept: SNUG floors `opening` (inactive at 1.0, still acts at
smaller ratios); the ring's RING_MOST 15 m (the opening alone would be 23);
the trilithon's TRILITHON_RISE (a pumped catch over the back lintel).

**Re-anchored to the knobs** (no 0.9 numbers left as literals):
- `WorldScale.DRAWN_RATIO` (0.9) and `opening_at(toy, ratio)`.
- The aqueduct isle's outlines: `REF_CLEAR` = TOY_CLEAR x PLANE x DRAWN_RATIO,
  REF_EDGE and REF_END derived from it (37.2, 66.4 as before). FAR_SHIFT 5.6,
  NEAR_SHIFT 3.2 at 1.0.
- Sundered `ACT_BAY` = max(TOY_BAY, TOY_ARCH x PLANE x DRAWN_RATIO + 2 jambs)
  (10.56 as before).
- The drowned nave's NAVE_X, basin and props are untouched: its test passes at
  1.0 (its crossing and piers already derive from `opening`).

**Aqueduct isle routes at 1.0** (each moved in the layout, not the test):
- Castellum: the steps run evenly from the high step down to
  `CASTELLUM_FOOT` 1.4, each at most SET_OFF (1.47 m at 1.0; the old 1.6 m
  stride left a 2.2 m bottom step).
- Buttress/slot kicks: a kick rises 1.42 m, and from the turf the 10 m deck
  sent the climb out onto the castellum, not the channel. A block fallen into
  the slot (`KICK_BLOCK`, `KICK_RISE` 1.4, `kick_from()`) starts the climb.
  The test reads `Art.kick_from()` and `CASTELLUM_HIGH` (still deck + 0.2).
- Stumps: the slot's near stump keeps its length (`STUMP_SLOT_NEAR_LONG` 3.6)
  and the 1.6 m running jump (`STUMP_NEAR_GAP`); the first stump grows with
  the run instead.
- Fallen trilithon: the stub's broken corner is narrower (`STUB_CORNER` 0.2),
  so the hop's run-up is on its flat top; its steps rise up to `STUB_STEP` =
  GRAB_TOP - 0.25 (two of 1.62 at 1.0, not three packed ones).

- Colonnade spine: the south bench runs on flat to x 98 (`SHELF_S`). At 1.0
  the jump to the first south slab ran down the flank into the slab's side.

**The floating stone in the screenshot** was a lancet window's oculus. Its
ring was a fixed 0.5 m that sat in a toy window's head; in a 6.8 m window it
hung in the middle of the head with nothing under it. Broken tracery (any
lancet weathered over 0.3) also kept the oculus 30% of the time with most
of its stones gone: one curved stone in the air. The legs with no crown were
the head ring's lost crown stones with the wall torn down round them (that
part is intentional). Fixed in scripts/ruin_kit.gd:
- `_oculus(w, light)`: the ring rests on the two lights' heads and is
  OCULUS_FIT (0.7) of the widest that also touches the window's arc. 0.63 m
  out in the toy's window (as before), 1.2 m in a 7.2 m window.
- Broken tracery has no oculus, and a broken light keeps only its springers
  off the jamb (`_ring_order` `only_side`); its inner springers had stood on
  a mullion snapped below them.
- Hood moulds stop where the outer order stops (`cap`). The colonnade's
  free-standing portals have none: with no wall behind them, their hoods
  stood proud of the ring's face as loose slabs. Bedding the hoods into the
  ring instead broke the cloister tarn's heap climb (radially) and the bell
  spires' drift (in depth), so it was dropped.
- Colonnade spine: the south bench runs on flat to x 98 (`SHELF_S`). At 1.0
  the jump to the first south slab ran down the flank into the slab's side.

**The floating stone in the screenshot** was a lancet window's oculus. Its
ring was a fixed 0.5 m that sat in a toy window's head; in a 6.8 m window it
hung in the middle of the head with nothing under it. Broken tracery (any
lancet weathered over 0.3) also kept the oculus 30% of the time with most
of its stones gone: one curved stone in the air. The legs with no crown were
the head ring's lost crown stones with the wall torn down round them (that
part is intentional). Fixed in scripts/ruin_kit.gd:
- `_oculus(w, light)`: the ring rests on the two lights' heads and is
  OCULUS_FIT (0.7) of the widest that also touches the window's arc. 0.63 m
  out in the toy's window (as before), 1.2 m in a 7.2 m window.
- Broken tracery has no oculus, and a broken light keeps only its springers
  off the jamb (`_ring_order` `only_side`); its inner springers had stood on
  a mullion snapped below them.
- Hood moulds stop where the outer order stops (`cap`) and are bedded 0.1 m
  back into the ring's face (`HOOD_BED`, depth only; bedded radially too
  they broke the cloister tarn's heap climb). On the colonnade's
  free-standing portals they had hung loose.

**Floating-stone check** (RuinKit Build `check_floating`, `drop_floating`,
`drop_loose`): every drawn block is joined to the ground through blocks
touching within FLOAT_TOUCH (0.2 m); the rest float.
- Pieces whose ruin removes stones by rule drop what floats: arch,
  lancet_wall, rose_gable, buttress, wall, aqueduct_end. That covers crown-lost
  courses, gable fragments, a lost crown's hood and ragged heads.
- Isle builds drop loose stones (groups of 3 or fewer): the aqueduct (the
  "stones hung up on the springers" of the fallen span hung in the gap), the
  hill walls, the cloister's back walls and the colonnade's step walls.
- A broken crown is intentional: what is left stands on its own legs, and
  what fell lies in the drift and rubble. Nothing hangs.
- Left floating on purpose: the floating stones, the drowned nave's causeway
  stones, the half bridge's parapet (its deck is a walk hull, not a block),
  and the colonnade's fallen lintels lying in the grass.

**Collision audit** (scripts/collision_audit.gd; tools/collision_audit.gd
prints it):
- What it does: loads the game with every motif isle built and copies every
  drawn mesh onto a layer of its own as a trimesh. Then it samples each
  collision shape's surface on the plane's and walker's layers (box faces on
  a grid, hull corners, trimesh triangles). A point is exposed if no drawn
  surface is within 0.3 m and it isn't inside drawn stone (straight up, the
  first drawn face is met from behind).
- Runtime: about 30 s headless.
- Results: 2059 shapes stood off the drawn stone (454 by a metre or more) at
  0.95 before the fixes; 1504 at 1.0 after them (340 by a metre or more).
  - The aqueduct isle's own boxes (station parts, castellum, stumps, kit
    hulls) were all within a metre: only box corners stood 0.3 to 1 m off.
    The greybox station itself isn't built in the game; its parts are laid at
    the derived numbers.
  - Stone circle, by name: 74 shapes checked (both circles), 3 off by 0.3 to
    1 m, none by a metre. The tallest hull is 8.92 m = TRILITHON, so the
    hulls grew with the stones. No station circle boxes exist. The broken
    lintels' walk hulls stop at the break (they include the break plane), so
    there's no invisible bridge.
  - Worst offenders found and fixed:
    - The stair to the clouds' cliff slivers and prisms stood up to 1.6 m
      proud of the set-back, bulging rock walls drawn over them: 1075 shapes.
      The drawn walls now collide (`Sides`). The heightfield's steep
      triangles and prisms in a wall's face are gone. Lip and foot triangles
      stay (they are walked). Lip prisms on walls 4.6 m and taller hang only
      0.4 m (`_collide_as_drawn`).
    - Cliff prisms under every island rim hung 1.5 m straight down into the
      air under the lip: 650 shapes, mostly the colonnade spine. Within 2 m of
      the outline they now hang 0.3 m (kit_land `PRISM_RIM_DROP`).
    - Bell spires' stair walk hulls lean in under their treads as the corbels
      do (`WALK_LEAN`).
    - The Sundered gorge gate tower's boxes ran to -2 m under blocks drawn
      from -0.6.
    - The airship envelope was one capsule the whole teardrop long. It is now
      two capsules inside the teardrop (`envelope_solid`).
  - Plane bump body: BUMP_BODY x plane (2.8 x 0.6 x 2.4) offset by
    `middle_shift()` lies inside the drawn plane's box (2.8 x 1.76 x 3.01),
    neither offset nor oversized. The parked-plane room check now reads
    `WorldScale.span x factor`; it was the same number from TOY_SPAN x
    ground_size.
- Exempt: the rune serpent's capsules. Its body is bent in its shader, so the
  audit can't see it.

**Tests** (headless, ratio 1.0): 39 of 44 related pass (world_scale_fit and
_guard, ruin_kit, ruin_floating, collision_audit, hall_chain, hall_rise,
isle_hall_chain, sundered_gorge, hollow_keel, cloister_tarn, colonnade_spine,
drowned_nave, stair_clouds, broken_ring, bell_spires, motif_sky,
cluster_motifs, pierced_isle, collectibles_world, flight_moments,
flight_metrics, aqueduct_isle and its _life, _plane, _sail and _sky tests,
glide_camera, plane_flight, plane_landing, sky_plane, kit_isle_landing,
manual_landing, hand_landing_exit, isle_lodestone, isle_loop_played,
isle_lock, lodestone_study, island_pack_ruins_archipelago). These fail:
- Known from the base: aqueduct_isle_look, collectibles_pickup, and
  moments_world (engine error only).
- sundered_hall, new at 1.0 (it passes at `--opening-ratio=0.95`): "The
  overgrowth keeps out of the lane's low slot (25) and the breaches (57 of
  58422)". This is vine geometry, not collision:
  - in the lane, leaf mats at y 2.6 to 2.84 (the window's top is 2.9) round
    x 24 and x 70 of the shafts piece;
  - in the breach corridors, ivy at z 13.4 (the outer row's line) inside the
    7.2 m corridors.
  - `sundered_growth.gd`'s BEAM_SPOTS and the tie spots are fixed metres
    from an older hall width.
  - Open.

Test notes:
- New, headless: test_collision_audit (about 30 s: the aqueduct isle has no
  shape a metre off, the circles have none, no shape anywhere is 3 m off,
  under 400 are a metre off, nothing floats but the listed, and the bump body
  is inside the plane) and test_ruin_floating (about 25 s).
- test_world_scale_fit: at ratio 1 each opening is toy x plane; the oculus
  fits; the 0.9 references derive.
- test_ruin_kit's hall_bay size bound reads the hall's width (3 x WALL_Z). Its
  diagonal is 45.1 m at 1.0, over the old fixed 45.
- test_aqueduct_isle reads `Art.kick_from()` and `CASTELLUM_HIGH`.

**Captured** (rendered, --no-title; 6 in all):
- the far island's gate (whole, no floaters);
- the colonnade portals at 0.95 (loose hood slabs) and at 1.0 (rings
  standing, crowns lost, nothing hanging);
- the drowned nave's and the broken ring's lancet walls at 1.0. The broken
  ring's is the screenshot's shape (two legs, crown lost), with the window's
  head now empty.
- The hall's broken arch wasn't captured. The headless check covers it: hall
  bays float nothing but the fallen beams, which rest on the paving.

**Open:**
- The stair to the clouds' mesa still has about 240 cliff prisms and sliver
  triangles a metre proud of its set-back drawn walls, at lips and short
  steps. Taking them out broke landings walked along a wall's edge (landing
  4) and the lawn probes. The way on is to make the facade's set-back rows
  start under a lip band, or collide the facade only.
- About 60 of the drowned nave's cliff prisms by the basin's banks stand a
  metre off. They are mostly under water.
- The rune serpent is shader-skinned, so the audit can't see it.
- The airship gondola box is 0.3 to 1 m proud.
- Sundered overgrowth at 1.0 (above).
- The hall bay's fallen beam rests on the paving a little high (the
  floating check reports it; it's harmless); test_ruin_kit's hall_bay size
  bound now reads WALL_Z.
- Nothing has been flown by a person at 1.0.

## Opening ratio 2 (feature/opening-ratio-2): RATIO 0.95, the rest on opening()

This round finished the openings left over from the last one and, at the
user's ask, raised `RATIO` from 0.9 to 0.95. Where this section disagrees
with the ones below, this one is current.

**Widths at plane 2, ratio 0.95** (ratio 0.9 values in brackets; past each
wingtip = (width - 2.8) / 2):

| Opening | Toy | Was | Now |
| --- | --- | --- | --- |
| THREAD | 3.5 | 6.3 | 6.65 |
| Gothic ARCH_SPAN | 4.2 | 7.56 | 7.98 |
| Lancet WINDOW | 3.6 | 6.48 | 6.84 |
| Hall lane | 4.0 | 7.2 | 7.6 (ROW_Z 13.0, WALL_Z 16.0) |
| Hall breach corridor | 3.6 | 6.48 | 6.84 |
| Hall broken ARCH | 5.2 | 9.36, springing 2.75 | 9.88, springing 5.4 (the toy's), crown lost (below) |
| Hall BAY | 8 | 10.56 | 11.08 |
| Kit aqueduct CLEAR | 4.7 | 8.46 | 8.93 |
| Aqueduct isle arches | 4.0 | 7.2 (deck 9.2, END 66.4) | 7.6 (deck 9.6, END 69.2) |
| Cloister tarn water gate (TOY_GATE_PITCH 5.4 less the piers) | 4.26 | 4.26 | 8.09, piers ±4.62, round arch crown 5.9 over the walk's floor |
| Cloister tarn west gap, slot between the stubs | 2.46 | 2.46 | 4.92 (floored at SNUG), stubs ±3.03 |
| Colonnade portal, 2 x (ROW - ORDER) | 6.16 | 6.16 | 11.70 (ROW 3.4 -> 6.17) |
| Colonnade north-row bay (OUT_PITCH) | 5.55 | 5.55 | 10.54 |
| Colonnade south-row bay (IN_PITCH) | 4.38 | 4.38 | 8.32 |
| Drowned nave crossing (CROSS_CLEAR) | 4.46 | 4.46 | 8.47 (pier pitch 9.41) |
| Token air gap GAP_ROOM | 3.2 | 5.76 | 6.08 |
| Token wing box (WING both sides) | 1.6 -> 3.5 | 3.2 | 6.65 (THREAD's room, 1.93 past each tip) |
| Sarsens / great trilithon | 3.4 / 4.6 | 6.12 / 8.28 | 6.46 / 8.59 (capped, below) |

**Flown or walker-sized.**
- Flown, now on `opening()`: everything in the table.
- Walker-sized, kept on purpose:
  - every cloister arcade bay (SPRING 1.75, crown about 3.5) and the lavabo;
  - the drowned nave's other arcade bays (crown about 4) and its north gap;
  - the colonnade's other bays and the height under its lintels (PIER_H
    3.4: balance beams, about 0.9 m over the plane);
  - the colonnade's cleft and saddle knife.
- Left as is: the nave's own width (ROW_Z 5.4, about 9.8 m clear) and its
  chancel vault. Both are wide corridors.

**Hall broken arch** (scripts/ruin_kit_hall.gd):
- The arch now springs at the toy's 5.4 (`ARCH_SPRING`) at every size, so
  it keeps the toy's proportions.
- At plane 2 its head (14.3 m) would stand over the roof (11.6), so
  `arch_broken()` is true and its crown is lost:
  - The wall over it is torn down to a notch from `ARCH_BROKE` (0.7) of its
    rise. The two haunches stand, and their ring stones above the notch are
    gone (`_wall`'s `crown`).
  - The aisle roof strip over it is left out, so the breach is open to the
    sky.
  - The Sundered far block leaves no lintel over it.
- At plane 1 it is the toy's whole arch, under the roof.
- The Sundered line bot: 0 bumps (74.5 s). The hall chain: never a bump.

**Ratio 0.95 follow-through** (what a ratio change used to break):
- Aqueduct isle (studies/aqueduct_isle_art.gd):
  - The outlines are now drawn data (`NEAR_DRAWN`, `FAR_DRAWN`) plus
    `REF_EDGE` 37.2 and `REF_END` 66.4, the run they were drawn round at
    ratio 0.9.
  - `FAR_SHIFT` (END - REF_END, +2.8 at 0.95) moves the far island,
    `GATE`, `GATE_FLOOR`, its rise and the life's leaf spot.
  - `NEAR_SHIFT` moves the near island's north tip under the aqueduct. It
    fades out 8 m either side of the aqueduct and south of z -30.
  - The stumps derive: the slot's far stump keeps 3.15 m, the last two
    follow the far island, and the twirled gaps (`STUMP_JUMPS` 3.4, 3.0)
    stay the walker's. The two far stumps share the extra length.
  - `AqueductIsle.PIECES` is now `pieces()`. A static var on the scene's
    script leaked Variant pages at exit (test_isle_loop_played).
- Stone circle: the great trilithon stands at most `TRILITHON_RISE`
  (CHAIN_TOP - 0.45, 2.125 m) over the sarsens.
  - 2.28 m at 0.95 wasn't caught from the back lintel.
  - It is also capped at 0.9 now (8.25, was 8.28).
  - The fallen trilithon's stub steps rise up to 1.55 m (2 pieces, not 3),
    as the leaning stone's block does.
- Sundered: wider bays made seed 16's line 1352 m, over LENGTH's 1300.
  - `_trim_bays` takes bays off the longest pieces (never under
    `MIN_BAYS` 6) until the line is as long as drawn at `ACT_BAY` 10.56
    (ratio 0.9's bay).
  - At 0.9 nothing changes.
- Hollow keel: fewer, wider bays (7). Its breach spots past the last bay
  are skipped, and the lane tokens spread over the hall's length.
- Lancet window: its head ring is framed at the springing, so its stones
  settle about there. Settling about the ground swung a wide window's
  springers 0.01 m into THREAD.

**Token clearance** (scripts/collectible_lines.gd):
- `TOY_WING` is 1.75, a THREAD's toy 3.5 across: 6.65 m at the defaults,
  1.93 m past each tip. It was 0.2.
- Hand-laid air lines were measured from stone (level rays, turf excluded)
  on the aqueduct isle and every motif isle. Each thread or break line now
  keeps at least 3.3 m (half a THREAD), with these exceptions:
  - The knife lines (aq:knife 1.05, bs:chimney 1.22) are knife slots on
    purpose.
  - ct:gap is 2.43 at the stub slot: that is the slot's own half width. The
    slot is floored at SNUG, so a token there can't have more room.
- Moved to get there:
  - The stair clouds slot's last point is 1 m along and 3 m out (`SLOT`).
  - The colonnade tail's under-bridge point is 1 m east and 2 m south.
  - The gorge curtain token is 1 m east.
  - ct:gate flies at K + SPRING, where the gate is widest.
- The moments set pieces (`--moments`) are re-laid in the game's hall:
  - `FlightCourse.LAID` holds the stations as laid. `STATIONS` holds the
    moments pack's re-laid by `_game_hall`: bays chained BAY apart, every
    point (parts, tokens, lines, moments) carried in its bay's frame,
    stretched along the nave and widened across the lane.
  - Their pinned hashes are now of the laid stations.
  - The flight study's toy stations now draw TOY_BAY bays. They had drawn
    the game's BAY at an 8 m pitch.
- `--chain-style=halls` (hall_chain) builds the kit hall and its tokens
  from Hall's sizes. Its test passes with 0 bumps.

**Routes moved:**
- Drowned nave (fork):
  - PIERS derive (9 bays, crossing bay 5); the south gap faces a north
    great arch.
  - dn:gap and dn:bay are at `cross_mid()`.
  - The stub and walk tokens and the robins' stub perches follow.
  - Found: the south row is built mirrored, so the old dn:gap token ran
    through a standing bay.
- Cloister tarn (fork):
  - The gate's walk (`GATE_WALK` 7.0) has kit steps up from the
    neighbouring walks (`_steps_up`).
  - The heaps derive from `GAP_END`.
  - The stub-to-stub hop is gone: the stubs are 5.16 m apart. The on-foot
    loop now goes down onto the lower stub, into the gap and up the south
    heap.
- Colonnade spine (fork):
  - `WC` widens with the rows, and the south slabs move out.
  - LINES is down to 13; STUBS, FALLEN and PORTAL_LOST are re-keyed.
  - The slalom derives from LINES.
  - `_room_for_plane` keeps the parked plane out of portals and from under
    lintels.
  - This also fixes motif_sky's "open turf 14 m long" base failure.

**Assertions changed** (each encoded an old size or layout):
- test_flight_moments:
  - "keeps its source's stone and line" now compares the laid stations,
    and a new check says each stands in the game's hall.
  - The hash pins are of the laid stations.
- test_moments_world: the free collectible flown through is the one whose
  4 m run-in is clearest. The first one's run-in went through a bay line's
  beam.
- test_kit_isle_landing: the "stone ahead" spot also needs level turf
  4 m all round. At 0.95 it found one by the island's edge, and turned away
  it rolled off.
- test_world_scale_fit: the trilithon expects min(opening, sarsen +
  TRILITHON_RISE). It now covers the nave crossing, the tarn gate and stub
  slot, and the colonnade portal and both row bays.
- The forks' changes: test_cloister_tarn_isle (stub hop replaced, heap
  climbs end over the pier), test_colonnade_spine_isle (the lintel climb's
  run-up from ROW), test_drowned_nave_isle (lines at cross_mid, four lines
  through the crossing).

**Tests** (headless, ratio 0.95): 41 of 44 pass:
- world_scale_fit and world_scale_guard;
- ruin_kit, sundered_hall, hall_chain, hall_rise, isle_hall_chain,
  sundered_gorge, hollow_keel;
- cloister_tarn, colonnade_spine, drowned_nave, stair_clouds, broken_ring,
  bell_spires;
- motif_sky (passes now) and cluster_motifs;
- serpent_route, collectibles_world, flight_moments, sky_moments,
  flight_metrics, flight_study, flight_tokens, flight_lines;
- aqueduct_isle, plus its _life, _plane, _sail and _sky tests;
- glide_camera, plane_flight, plane_landing, sky_plane, kit_isle_landing;
- isle_lodestone, isle_loop_played, isle_lock, lodestone_study,
  pierced_isle, island_pack_ruins_archipelago.

Three fail as on the base:
- aqueduct_isle_look.
- collectibles_pickup.
- moments_world: all its checks pass, but the engine logs
  `!isfinite(p_size)` from cozy_worlds `_layout_shell`. The same error is
  logged on integrate/scale-camera.

test_aqueduct_isle also passes at `--opening-ratio=0.9`.

**Captured** (rendered, --no-title): the cloister tarn's water gate and
its establishing view (tools/cloister_tarn_captures.sh).

**Open:**
- Still hand-tuned to a ratio:
  - REF_EDGE/REF_END (0.9's run) and the drawn outlines' shapes;
  - Sundered ACT_BAY 10.56;
  - the aqueduct isle at `--opening-ratio=1` (plane 2) fails four routes:
    the castellum climb, the buttress kicks, the stumps and the fallen
    trilithon. Steps, kicks and jumps there are still laid for 0.9 to 0.95;
  - the drowned nave's NAVE_X, basin, fallen pier and flag;
  - the colonnade at plane 1, ratio 1 fails 2 checks: the plane parks on
    the north shelf walk.
- The gallery's hall bay capture wasn't framed well, so the broken arch
  hasn't been looked at rendered. Look at it in a Sundered capture
  (tools/capture_sundered.gd) or the gallery before tuning ARCH_BROKE.
- The cloister stubs no longer make a walker hop.
- The colonnade slalom weaves harder: about 6.2 m sideways over 9 to 14 m.
- kit_isle `_room_for_plane` sizes its box from TOY_SPAN, not
  WorldScale.span.
- Nothing has been flown by a person.

## Opening ratio (feature/opening-ratio): the current openings

The user flew world-spacing and the arches and aqueducts still felt too
small. The toy era's flight felt right, so every opening the plane flies
through now keeps its toy-era width in wingspans, at 0.9 of it. Where this
section disagrees with the ones below, this one is current.

**The knob** (scripts/world_scale.gd):
- `RATIO := 0.9`. `--opening-ratio=<x>` overrides it for a run.
- `opening(toy_width)` = max(toy x plane x ratio, min(gap(SNUG), toy x
  plane)). That is 1.8x the toy width at the defaults.
- The floor: an opening never closes under SNUG (1.2 m past each wingtip)
  at a small ratio. The floor is capped at the toy width grown with the
  plane, so it never acts at ratio 1, and a toy width that was itself under
  SNUG's room (the token wing box) floors at its own toy ratio.
- `--plane-scale=1 --opening-ratio=1` gives back every toy width exactly.
  test_world_scale_fit checks this in its second run.
- Each opening names its toy width in the file that owns it (`TOY_THREAD`,
  `TOY_CLEAR`, `TOY_LANE`, ...). Knife slots keep `knife()`. `gap(room)` stays
  for spacing with no toy width: the bell spires, unchanged.
- The temporary `--room-scale` flag is gone. The guard test now covers
  `--opening-ratio=` and checks that `--room-scale=` is not used.

**Widths, world spacing → now** (plane 2; past each wingtip in brackets):

| Opening | Toy (spans) | World spacing | Now |
| --- | --- | --- | --- |
| Kit aqueduct CLEAR (no longer THREAD) | 4.7 (3.4) | 5.2 | 8.46 (2.83); SPAN 10.16, deck 10.8 → 14.06, two-tier course 11.66, upper deck derived |
| Gothic ARCH_SPAN | 4.2 (3.0) | 6.44 | 7.56 (2.38); SPRING kept 3.2, crown 9.75 |
| Hall lane | 4.0 (2.9) | 6.16 | 7.2 (2.2); ROW_Z 12.6, WALL_Z 15.6 |
| Lancet WINDOW | 3.6 (2.6) | 5.6 | 6.48 (1.84) |
| THREAD | 3.5 (2.5) | 5.2 | 6.3 (1.75) |
| Rose glass | 3.96 | 5.25 | 7.13; gable grown 1.8x |
| Hall breach corridor | 3.6 | 5.24 | 6.48 |
| Hall broken ARCH | 5.2 | 6.2 | 9.36; springing lowered to 2.75 so its head stays under the roof |
| Hall BAY | 8 | 8 | 10.56: the broken arch and 0.6 jambs need it (8 at plane 1) |
| Ring arch | 12.3 (8.8) | 14.0 | 15.0: capped (RING_MOST); the opening alone would be 22.1 |
| Stone circle gap | 2.1 (not flown) | 5.2 | 5.2: max(gap(SNUG), opening(2.1)=4.2) |
| Token air gap GAP_ROOM | 3.2 | 5.2 | 5.76 |
| Pierced route (both sides) | 3.2 | 5.2 | 5.76 |
| Token wing box WING (both sides) | 1.6 | 5.2 | 3.2: floored at its toy ratio (0.2 m past the tip) |
| Aqueduct isle arches | 4.0 | 4.0 | 7.2 (2.2) |
| Knife slots (trilithon, stumps, hall slit) | | 1.9 / 2.11 / 1.89 | unchanged (`knife()`) |

Ring: at 15 m it keeps 0.62 of its toy ratio but leaves 6.1 m past each
tip, more than the toy's 5.45. It is a gateway in open sky, so the cap
costs nothing that matters, and its crown (about 19 m) stays the size it
was.

**Stone circle heights** (user feedback mid-round: "the stone henge are
still too short"):
- The sarsens are `opening(3.4)`, 6.12 m tall. The great trilithon is
  `opening(4.6)`, 8.28 m.
- Both are a little chunkier: sarsens 1.6 x 1.25 m (they were 1.5 x 1.1).
  The ring radius is 9.43 and the gap stays 5.2.
- Lintel thickness is kept. The ring top is 6.72 m (it was 4.0).
- Ways onto the lintels, kept walkable:
  - The fallen trilithon's stub is 1.5 m under the ring top (5.22). Its
    broken pieces are stacked as steps on the lying stone, each 1.5 m or
    less.
  - The lying partner stone is 4.0 m long. At full length it lay across the
    ring's middle and boxed the walker in against the broken ring's turret.
  - The leaning stone keeps the toy's reach (a longer one would cross the
    middle). It is steeper, 40°, still under the walker's 44°, and its head
    is at 4.72. A block wedged on its head is the step up, so the lintels
    are a jump from it.
- From the back lintel, the jump up to the trilithon is now 2.16 m, a
  pumped catch (the toy's was 1.2 m).
- At plane 1, ratio 1, all of this is the toy circle again.

**The aqueduct isle's aqueduct** (studies/aqueduct_isle_art.gd): it is now
derived, not hand-laid.
- Toy clear 4.0 → `CLEAR` 7.2. `GROW` 1.8.
- `CROWN` 4.0 x GROW = 7.2. `DECK` = crown + the toy's 2 m spandrel = 9.2.
- The pier stays 2.0 wide (stone/walker-sized). Pier pitch `PITCH_X` is
  CLEAR + PIER = 9.2.
- `arch(k)` and `pier(k)` lay 7 spans from HEAD 2: two blind, two open over
  the near island, one over the sky, the fallen one, and the last. END is
  66.4 (it was 44).
- The fallen span keeps the walker's 3 m gap (`FALL_HALF`), with longer
  stubs.
- The hanging piers' feet grow with the deck (13.8 / 16.9 / 15.3 m under).
- The rubble slope stays at 30°, so it runs from z 13.9 (`SLOPE_LOW`).
- The start (`START`) moves to the slope's foot, (100, 30, 14.5). The
  parked plane follows it.
- The drops are `DROPS` 7 of 1.2 m.
- The buttress is DECK - 0.8 = 8.4 tall. The wall run and kicks still make
  the channel.
- Castellum (`CASTELLUM`, derived):
  - The high step is deck + 0.2 (9.4) and the crown is deck + 1.8 (11.0).
  - The steps run 1.6 m apart down to 1.4, six of them.
  - The drift stones lerp to the new crown.
- Collision: `station_parts()` lays the station's boxes (ramp and fill,
  blind wall, piers, spandrels, stubs, drops, buttress) at these numbers.
  The greybox station 2 itself is unchanged; its pack test still drives it.
- At plane 1, ratio 1, it is the station's aqueduct again.

**Islands:**
- The near island's north edge grows out under the aqueduct, from z -24.4
  to -37.2, just inside the first hanging pier. Its outline is reshaped
  from x 80 to 124.
- The far island moves out and is drawn out north, from 39.8–66 to
  60.4–96, so the drops land on it.
- That leaves 23.2 m of sky under the aqueduct (it was 16). Nothing
  overhangs.
- The gate arch moves to (100, -91.3) and its paving to (94.5, -85.8). The
  far rise moves with them.
- The paths are re-laid: the slope foot is at z 15.4, and the north edge
  runs to the stumps.

**Routes moved:**
- `KNIFE_Z` is now -arch(4) = -42.4, under the sky arch between the hanging
  piers. It moved to Art; `AqueductIsle.stump_slot()` and `stumps()` stay as
  wrappers.
- The stumps are now five from the far edge (about -62.5) to the near
  (-35): three twirled jumps (2.9, 3.0, 3.4), the 2.11 knife slot (a
  running jump), 1.6 and 0.65.
- The sky tokens (`aq:knife`, `aq:break`), the on-foot tokens (slot,
  fallen span, stumps) and the birds' perches all follow Art.
- Tests: the start, the channel walk and the fallen-span jump, the drops,
  the castellum lines and crown height, the stumps (now `_stumps_back`), the
  drift's crown and the life test's lines all read Art.
- The wall-run approach walks round the longer slope first, so it doesn't
  climb the ramp.

**Assertions that encoded an old size:**
- test_aqueduct_isle `_replays`: the station's two recordings no longer
  replay true on the bigger aqueduct. The isle offers them only when
  `Art.station_sized()` (plane 1, ratio 1), and the test checks that.
- test_ruin_kit: the rose gable at 1.8x (31 m diagonal) joins the 45 m
  sane-size class.
- The hall_slab piece stays the toy bay's slab stack.
- Fixed along the way: a hall buttress buried to the roof had reported a
  foot with no stone over it. Feet now come only with a buttress.
- Hollow keel: BAYS = round(80 / BAY) (8 now) and SHAFT_BAYS are derived
  from the shaft's run.

**Tests** (headless, all pass): world_scale_fit, world_scale_guard,
ruin_kit, sundered_hall (the line bot: 0 bumps, 76 s), hall_chain,
hall_rise, isle_hall_chain, sundered_gorge_isle, hollow_keel_isle,
cloister_tarn_isle, colonnade_spine_isle, drowned_nave_isle,
stair_clouds_isle, broken_ring_isle, bell_spires_isle, cluster_motifs,
pierced_isle, collectibles_world, flight_metrics, lodestone_study,
isle_lodestone, island_pack_ruins_archipelago, isle_loop_played, isle_lock,
kit_isle_landing, manual_landing (+_game), hand_landing_exit,
plane_landing, sky_plane, pocket_sail (+_study), pilot_figure, pilot_ledge,
pilot_motor, character_climb, character_study, ruin_growth, and
aqueduct_isle (+_life, _sky, _plane, _sail).

- plane_flight failed once in the 46-test batch ("Clear of the ground 0.6
  m"). It passed alone, and it doesn't touch the kit.
- motif_sky and collectibles_pickup fail as they did on the base.
- aqueduct_isle_look was not run.

**Captured** (rendered, --no-title): the isle aqueduct from the air, from
the walker's eye under an arch, and the far island's gothic gate.

**Open:**
- The hall's broken arch springs at 2.75 m so its crown stays under the
  roof, so it is wide but squat.
- The bigger BAY makes halls 32% longer per bay. The Sundered line is
  longer, and its tests pass.
- The token wing box is 0.2 m past the tip (its toy ratio), tighter than
  world-spacing's 1.2. Raise TOY_WING if lines hug rock.
- The trilithon summit from the back lintel is a pumped catch now.
- The cloister arcades, colonnade portals and drowned nave openings are
  still not on `opening()` (walker arches / not audited). The moments hall's
  tokens are still toy-laid.
- Nothing here has been flown by a person yet.

## World spacing (feature/world-spacing): sizes before the opening ratio

The chase camera at these sizes (the plane always in view, game speed
1.15x): docs/design/flight-camera.md.

The user flew `--wanderer-scale=1 --plane-scale=2.0 --plane-ground-scale=1`
and found the walker at 0.83 "too damn small" and the openings too tight.
This round puts the walker back to his full size, keeps the bigger plane,
and spaces the world out. The sections below this one describe the round
before; where they disagree, this section is current.

**Defaults** (scripts/world_scale.gd):
- `PLANE` 2.0 (2.8 m wings) and `WANDERER` 1.0 (his clips' size, 1.19 m).
- The cockpit pilot is drawn bigger instead of the plane: `pilot_size` =
  PILOT_RATIO*wanderer/plane = 1.2 (plane_figure.gd, stone_plane_figure.gd).
  It is capped at `PILOT_MOST` 1.25; past that he stays 1 and the ground
  cheat does all of it.
- With that, the ground cheat `ground_factor()` = PILOT_RATIO*wanderer/
  (plane*pilot_size) comes out at exactly 1.0, so the cheat is off.
  `--plane-ground-scale=<x>` still overrides it. At
  `--plane-scale=1 --wanderer-scale=1` the pilot is 1 and the cheat 2.4,
  as before.
- The walker's collider: kit_isle now calls `decks.scale_body(wanderer)`.
  At 1.0 that is the full-size collider (radius 0.28, head 1.12), the same
  as the character study's. The open item from last round is closed.

**Room** (steering room past the wings, counted in toy spans, both sides
together; it does not grow with the plane):
- `WorldScale.ROOM` 2.0 is the default for a flown opening: 1.4 m past each
  wingtip.
- `WorldScale.SNUG` 2.4/1.4 = 1.714 is the least any flown opening gets:
  1.2 m past each wingtip.
- `WorldScale.knife(room)` sizes a deliberate knife-edge slot: the plane's
  height on its side (TOY_TALL*plane) plus room. `KNIFE_ROOM` is 0.3, so
  1.9 m at plane 2.
- `WorldScale.past_tip(width)` gives what an opening leaves past each tip.

**Openings, old → new at plane 2** (past each wingtip in brackets):

| Opening | Old | New |
| --- | --- | --- |
| RuinKit THREAD (SNUG) | 4.62 (0.91) | 5.2 (1.2) |
| RuinKit ARCH_SPAN (room 2.6) | 5.6 (1.4) | 6.44 (1.82), crown 8.78 |
| RuinKit WINDOW (ROOM) | 5.0 (1.1) | 5.6 (1.4); wall grows with it |
| Rose glass (ROSE_GROW off THREAD) | 4.95 | 5.25 (1.23) |
| Aqueduct CLEAR = THREAD, SPAN = CLEAR+PIER | 4.7 (0.95), SPAN 6.4 | 5.2 (1.2), SPAN 6.9 |
| Aqueduct two-tier LOWER_SPRING | 3.0 | derived, 2.76 (the lower arch crowns under the course) |
| Stone circle sarsen gap (HENGE_ROOM = SNUG) | 14 stones, ~2.1 m gaps | 8 stones, 5.2 m at their inner faces (1.2) |
| Great trilithon slot (knife) | 0.9 | 1.9 (0.21 round the plane on its wingtip) |
| Hall LANE (LANE_ROOM 2.4) | 5.4 (1.3) | 6.16 (1.68) |
| Hall breach corridor (BREACH_HALF off THREAD) | 4.66 | 5.24 (1.22) |
| Hall broken ARCH | 5.62 | 6.2 (1.7) |
| Hall knife slit | 1.89 | 1.89 (knife edge, kept) |
| Ring arch on the lodestone's line (RING_ROOM 8) | 2.2 x arch, 12.3 | gap(8) = 14.0 (5.6) |
| Aqueduct isle stumps' knife slot (knife(0.45)) | 1.9, off the line | 2.11, centred on the arch (0.32 round the plane on edge) |
| CollectibleLines GAP_ROOM (SNUG) | 3.2 | 5.2 |
| CollectibleLines WING (half gap(SNUG)) | 1.5 | 2.6 |
| Pierced isle ROUTE_CLEAR (half gap(SNUG)) | 2.3 | 2.6 |
| Bell spires: hero to the low spire | 6.2 (1.7) | 12.4 (4.8) |
| Bell spires: gable to fin_low | 7.9 | 10.4 (3.8) |
| Bell spires: other spire pairs | 8.8 to 11.7 | 11.6 to 14.2 |

**Stone circle** (ruin_kit.gd `stone_circle`; the user's #1):
- `CIRCLE_STONES` is 8 and `SARSEN` is 1.5 m wide (it was 1.7).
- `CIRCLE_RADIUS` is derived so that the gap between two sarsens at their
  inner faces is `gap(HENGE_ROOM)`. That gives 9.3 m at plane 2 (it was
  8.5) and 7.5 m at plane 1. It fits the aqueduct isle's summit (11 m at its
  narrowest) and the broken ring's 13.5 m isle.
- Fallen lintels no longer leave a whole chord missing:
  - A fallen lintel breaks in its middle. A `LINTEL_BREAK` piece (3.0 m x
    wanderer) falls into the grass, and the two ends stay on their sarsens,
    so the ring is still run round with one twirled jump.
  - A lintel whose sarsen is `missing` keeps the end on the sarsen that still
    stands.
  - The ring's lintels are walked on true hulls (`_walk_hull`). A worn chunk
    out of a 7 m lintel had taken its top for metres.
- The fallen trilithon's stub is turned end-on, so the hop from the stub
  onto the lintel starts on stone.
- `TRILITHON_AT` is derived so the summit jump from the back lintel stays
  the same 2.29 m in. The broken lintel's pieces lie at R-3.6.
- Indices changed: `LEAN_AT` 1, `STUB_AT` 4, the aqueduct isle's
  `MISSING` 6 (292.5 degrees, in the bite), and the broken ring's
  `MISSING` [3, 4].
  - The aqueduct isle's floating ring sarsen is sized off the ring, a
    twirled jump from each broken end: 4.12 x 1.1 x 2.17.
  - Its kit stair stays at 257.14 degrees, 1.3 m off sarsen 5's face.
- test_aqueduct_isle `_ring_loop` now jumps along the ring's own lintels
  (from the sarsen's top to the next). At 8 stones the old straight line,
  cut across a sarsen's corner, ran 0.85 m off the lintels' line, so it left
  the lintels.

**Sundered** (from the Sundered fork, merged; commit a4f5c5bf):
- The line was hard to fly because `Sundered.LANE_MID` was a fixed 6.0. It
  ran 0.6 m off the inner columns in the widened lane. `LANE_MID` and
  `LINE_Y` are now static vars at the lane's middle: 7.08 and 2.55.
- Turns are eased:
  - Sundered: `RADIUS` 70 → 95, `TURN` 0.55 → 0.5, `KINK` 0.14 → 0.1.
  - Sundered line (`hall_line_plan.gd`): the sidestep's `jog_gap` 120 → 140
    m, `bend` 26 → 22 degrees.
- Breaches are placed only where their corridor fits between the columns on
  a curve (`Hall.breach_fits`, `HallPath.stretch`, `fit_breaches`). Where a
  bay can't take one, its roof is broken open instead.
- The podium, bed and island half-widths come from `WALL_Z`.
- Sundered gorge: the line's second point moved to (87.6, 18.8, -47), under
  the two lower-crossing fragments; it grazed them before. 0 bumps.
- Hollow keel: `FLOOR_SINK` 0.2 under the paving (it left a 0.47 m step),
  and its lane uses the kit's lane middle.
- Flight study: its stations keep the toy plane's hall (`TOY_ROW_Z`,
  `TOY_WALL_Z`, `TOY_KNIFE`, `TOY_ARCH` in flight_course.gd), since their
  hashes are pinned and their plane is the toy.
- test_sundered_hall now checks the lane's room, the line in the lane's
  middle, the breaches and arch at least THREAD, and curves of at least 90
  m. Its bot flies the line in 61 s with 0 bumps.

**Bell isles** (from the bells fork, merged; commit 11d1d22e;
studies/bell_spires_isle_art.gd):
- Each outer spire stands off the hero by `gap(CARVE_ROOM 6.0)`. Every
  outer pair is held to `gap(PASS_ROOM 4.0)`.
- The air between two spires is measured rock to rock (`air_between`). The
  bridges, drift stones, causeway, outline and start rebuild from the new
  positions.
- The chimney stays 2.6 m on purpose: it is the walker's wall-kick climb and
  the knife-edge token line.
- The bridges are now 13.3 to 14.1 m long.
- motif_sky's `REACH` for the bells went from 34 to 41.

**Other fixes made along the way:**
- The cloister tarn's north-east arch now faces the bridge across the isle's
  middle. Set along the bridge, its wider pier had stood on the bridge's
  head.
- The rose gable's fallen hub lands to one side of the door, never across
  it. It had blocked the colonnade spine's gate walk.
- kit_isle: a plane with no take-off run parks on the nearest level spot
  with room for it, not on the walker's start. The broken ring's start had
  stood him on the parked plane's column. That failure also happened on
  850aa041.
- The stumps' knife line moved from z -29.2 to z -28 (`KNIFE_Z`), the
  middle of the aqueduct's arch, which is 4 m clear. It had run 0.06 m off
  the arch's pier on a knife edge.

**Tests** (headless; each listed below passes):
- The two world-scale tests. test_world_scale_fit now covers every opening
  in the table, the three knife slots and the cockpit pilot, at the default
  sizes and at the old ones.
- The five that failed on 850aa041: aqueduct_isle_sky, sundered_gorge_isle,
  cloister_tarn_isle, hollow_keel_isle, flight_metrics.
- All of these pass: ruin_kit, sundered_hall, hall_chain, hall_rise,
  isle_hall_chain, lodestone_study, isle_lodestone, aqueduct_isle (+_life,
  _plane, _sail), broken_ring, colonnade_spine, drowned_nave, stair_clouds,
  bell_spires, pierced_isle, collectibles_world, island_pack_ruins_archipelago,
  isle_loop_played, isle_lock, cluster_motifs, kit_isle_landing,
  manual_landing (+_game), hand_landing_exit, plane_landing, sky_plane,
  pocket_sail (+_study), pilot_figure, pilot_ledge, pilot_motor,
  character_climb and character_study. plane_flight passes with a known
  engine error.
- Two tests still fail, and both fail the same way on 850aa041:
  - motif_sky: "colonnade_spine: open turf 14 m long to land on".
  - collectibles_pickup: its checks pass, but the engine logs
    `!isfinite(p_size)` from cozy_worlds `_layout_shell`.
- test_aqueduct_isle_look was not run. It already failed before this work.
- The sarsen token in test_aqueduct_isle_life jumps along the ring's own
  lintel now, the same way the loop test does.

**Open:**
- At `--plane-scale=1` the gaps no longer return to their old numbers. The
  room is bigger now, and the hall lane, arch, circle and ring are all wider
  at plane 1 too.
- Cloister arcades (SPRING 1.75, crown 3.5) are the walker's arches and
  weren't widened. The colonnade spine's portals and the drowned nave's
  openings weren't audited one by one; their tests pass.
- Knife edges (the trilithon at 1.9, the hall slits at 1.89, the stumps at
  2.11) leave only 0.2 to 0.3 m round the plane on its wingtip. They are
  deliberate challenges.
- The moments hall (`--chain-style=halls`) uses the widened hall, but its
  tokens were laid for the toy plane and weren't re-laid.
- The hall's BAY stays 8 m, so a breach on a straight wall has 5.6 m between
  the column shafts.
- The flight study's toy plane now seats a 1.2x pilot.
- Captured (rendered, --no-title) and looked at: the stone circle from
  above and at the ring (wide gaps, broken lintel ends), the bell isles from
  afar, and the Sundered gate and nave.
  - The bell spires capture script's "thread" view (tools/
    bell_spires_captures.sh) now sits by the rock at the new spacing.
  - Not flown by a person yet.

## The game's sizes (feature/plane-wanderer-scale; superseded above)

The "meet in the middle" sizes are the default: the plane 2.0x its toy size
everywhere (2.8 m wings), the wanderer 0.83, and no ground cheat (it
derives to 1.0). The user flew these and said "seems alright".

**One file.** `scripts/world_scale.gd` holds the knobs `PLANE` (2.0) and
`WANDERER` (0.83), parses `--plane-scale=` / `--wanderer-scale=` once, and
derives `span`, `wider`, `taller`, `ground_factor()` and `gap(room)`. Nothing
else holds 2.0, 0.83 or 2.4 or parses those flags. Change one number there
and the plane, walker, moves and the flown gaps below follow. The values are
static vars that are read once when the script loads, so a scene opened from
the scene picker keeps the command line's sizes.

`--plane-scale=1 --wanderer-scale=1` gives back the old sizes, and every gap
and move below returns to its old number, with one exception: THREAD comes
back as 3.22, not 3.5 (see below). Checked with a headless probe script. In
that mode the cheat comes back at 2.4. Its code is kept.

**Gaps.** Each flown gap is `WorldScale.gap(room)`: the plane's span plus
`room` toy spans (1.4 m each) of steering room. The room doesn't grow with
the plane because the flight's speeds and turns are unchanged. Old → new,
at plane 2:

| Gap | Old | New |
| --- | --- | --- |
| ruin_kit THREAD (room 1.3) | 3.5 | 4.62 (0.91 past each wingtip) |
| ruin_kit ARCH_SPAN (room 2.0) | 4.2 | 5.6 (crown 6.8 → 8.0) |
| ruin_kit WINDOW width | 3.6 | 5.0 |
| ruin_kit WINDOW_WALL | 6.8 x 7.8 | 8.2 x 9.0 |
| ruin_kit rose glass | 3.96 | 4.95 (rose and gable grown x1.18 by ROSE_GROW; the door stays) |
| hall LANE (room 1.86) | 4.0 wide (z 4–8) | 5.4 (z 4–9.4) |
| hall ROW_Z / WALL_Z | 9.4 / 12.4 | 10.8 / 13.8 (out by the lane's growth) |
| hall TIE_LOW | 4.0 | 4.5 (`4+taller`, capped so 3.6 m stays over it under the capitals) |
| hall LANE_Y top | 3.6 | 4.1 |
| hall KNIFE slit | 1.15 x 3.3 | 1.89 x 4.7 |
| hall ARCH breach | 5.2 | 5.62 (THREAD+1) |
| hall BREACH_HALF | 1.8 | 2.33 |

THREAD's room was 1.5 at first, which gives 4.9 at plane 2. That didn't fit
between a curved hall's outer columns, nor under the aqueduct's 4.7 m
arches, so the room is 1.3: 4.62 at plane 2 and 3.22 at plane 1.

Hall details:
- A knife slit whose head doesn't fit under the screen's top (under a tie)
  now runs up open to the top, with the tie as its lintel (`_wall` slot).
- An outer nave roof strip is too narrow to fly out of alone, so it is
  gapped together with its neighbour, as one opening.
- A breach corridor wider than the room between column bases floors over
  them (`breach_floor`).
- The lane stops short of a high tie up a slope.

Other gaps:
- The aqueduct (CLEAR 4.7) was checked and left. It passes the plane with
  0.95 m past each tip at the piers and about 0.6 m a metre up into the arc.
  Its corridor keeps its old 3.5 width.
- pierced_isle ROUTE_CLEAR and hole room read `span`.
- collectible_lines: PLANE_REACH 1.1 → 1.8, WING 0.8 → 1.5, CLEAR
  +taller. Under-rock tokens hang only where rock is overhead.
- sundered_growth LANE / LANE_TOP, hall_rise_plan, sundered_build,
  hollow_keel_isle_art, lodestone_study and aqueduct_isle_chain read the
  hall/kit values (now static vars).
- The chain plane box in aqueduct_isle uses the drawn size.
- The flight study (flight_course REACH/SPAN) stays at toy size because its
  plane is the toy.

**Walker** (PilotMotor.set_size, from the study's `resize`):
- Hang geometry: HANG_DROP, HANG_OUT and CLIMB_IN x size, to match the
  scaled clips (0.825/0.22/0.3 → 0.685/0.183/0.249).
- Jumps rise by what the hands lose: `JUMPS + HANG_DROP*(1-s)`, so
  0.8/1.5 → 0.94/1.64. Every catch top (GRAB_TOP 1.875, CHAIN_TOP 2.575)
  stays.
- Walk and run go by `size^PACE_POWER`, with PACE_POWER 0.25: 2.4/4.8 →
  2.29/4.58. long_pace, skid and wall-run thresholds follow (3.0/3.4/4.0 →
  2.86/3.25/3.82). Froude's 0.5 broke the cloister tarn's 2.7 m stub jump.
  0 broke the aqueduct circle's twirled loop.
- Water depths: WATER_POWER is 0, so they are unscaled. Scaled, the walker
  swam the drowned nave's causeway.
- The gait plays by pace over size (PilotFigure.size).
- The pocket sail is scaled with him.
- The cockpit pilot already matches at plane 2 (0.185 x 2 vs 0.44 x 0.83),
  so it was left alone.
- CPU traffic is drawn at the plane size (PlaneGroundScale.grow).
- No lodestone plane miniature exists.
- Replays run at the size they were recorded at (old runs at 1). Runs
  recorded now save `size`.
- Shimmy bug fixed: it now reads the lip's way out where he hangs, because a
  rough lip stopped the first shimmy step.

**Still open** (fixed metres that won't follow, roughly by impact):
1. Kit isle body collider. The game's walker collider is still full size
   (radius 0.28, head 1.12, DeckGround). Scaling it made several scripted
   isle routes stick, and the demo the user flew had it this way. The
   character study's collider is scaled.
2. Hand-laid set pieces built for the toy plane:
   - The aqueduct isle's knife-edge stump slot (STUMPS gap 1.9 m) no longer
     fits. test_aqueduct_isle_sky fails. Widening it broke the walker's
     running jump between those stumps.
   - The sundered gorge plane line bumps 4x (test_sundered_gorge_isle).
   - Flight study "sundered_mix" tokens now sit inside the wider hall
     (test_flight_metrics).
   - aqueduct_isle_chain's ring arch (RING_SCALE 2.2) is now 12.3 m wide;
     it may want a smaller scale.
3. Hand-laid isles round widened pieces:
   - The cloister tarn's northeast bridge end is blocked, probably by the
     wider arch placed there (test_cloister_tarn_isle).
   - The hollow keel porch walk now meets a 0.46 m paving edge over the keel
     floor in the widened hall (test_hollow_keel_isle).
   - Gallery slots weren't re-spaced. The rose gable nearly touches the
     turret.
4. Kit and isle geometry is not scaled: stairs, ledges, set-offs, stumps,
   wall heights, catch tops (GRAB_TOP/CHAIN_TOP) and isle layouts. The jump
   is held to the old catch tops, not to his body. To make spacing follow
   WANDERER, these want deriving from the walker's reach next round.
5. THREAD at plane 1 is 3.22 (was 3.5).
6. The gallery's chase cam at 2x sits back inside the hall's columns.
7. Not captured: the walker on the game's stairs and doorways.
8. The scarf width, landing mark and stone plane are unchanged from before.
