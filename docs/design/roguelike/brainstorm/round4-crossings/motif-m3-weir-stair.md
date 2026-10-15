# The Weir Stair — "Seven cisterns, one fall, and a city at the bottom that still drinks"
Lenses: verb TIME A CROSSING (and descend) · twist the ruin still doing its old job · decay intact-and-working, drowned at the foot · scale colossal · purpose aqueduct / cistern · shape a tall line, a stack

Pitch: A waterfall the makers built: seven stepped basins down a cliff face
across a gulf, the water leaping tier to tier in one shining stair, and the
whole stair is the way across. You ride the falls down in short bursts,
timing each weir's gate, to a far isle that you saw from the top as a
drowned lamp-lit terrace.

Place: A tall crossing, not a long one. The near isle (a high shelf, the
cistern head, a lip with a carved maw) looks across a 60-70 m gulf at a far
isle 36-42 m lower, and the gulf is **one cataract of seven weirs** stepping
down a battered basalt wall: each weir a broad basin 14 m deep and 26 m
across, brim to brim lip-cut for the overflow, the water a sheet 6 m wide
spilling down the face into the next. The view from the head: the spill
as a white zig-zag of seven sparkles falling into mist, each basin lit
by a dim cresset on its rim (`maker_cresset`, warm, small), the last basin
a green drowned court at the bottom with a stair of stone heads half under
water, and past it the far isle's terrace in lamplight. The stair reads in
haze by its **stepped, widening silhouette**, a ziggurat inverted (talud
under a tablero, each tier wider as it descends) with a ribbon of water
crawling down the centre. Stone: the makers' basalt, wet-black at the lips,
rune-grooved weir faces, long moss beards at each spill; water painted. It
broke unevenly: the 3rd and 5th weirs have lost their near lip, so the sheet
pours over a raw broken edge in a veil instead of a lip, and the 6th basin's
floor has slumped, tilting its water toward one corner.

Top (1 char ≈ 4 m):
```
        ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~ ~
   [1]@##\
         \W1##\           arena A: head shelf, gate G
            \W2##\        the weirs W1..W7 step down and out
              \W3## .
                 \W4##\   perches P: rim crescets, C: weir walls
                    \W5##\
                       \W6##\
                          \W7##[2]@R   far isle, drowned court
```
Side (40 m fall in seven weirs of 5-6 m each):
```
 y+40 [1]##__
             \__W1  rim 5.5
                  \__W2
                       \__W3  (lost lip: veil)
                            \__W4
                                 \__W5  (lost lip)
                                      \__W6 (slumped)
                                           \__W7__[2] y 0
```

Play: Two routes, and a gate clock on the first.
- **The stair-runner** (platforming, dry). Climb or drop? He descends. Each weir
  has a **lip wall** (a ledge around the basin 5.5 m above its floor,
  more than a plain jump) and the basins connect where the lip of one is
  within reach of the rim of the next: a **drop-jump** of ~7 m gap and 5.5 m
  fall, a long jump off a run along the rim (7.6 m/s) catches the next
  rim with a ledge-grab. Run the rim (the brim is the walkway, 1.2 m past
  the water), jump, hang, mantle, run the next rim, seven times. Weirs 3 and 5
  have lost their lips, so the next rim is a broken edge lower down:
  a drop onto a corbel (grab) then a wall kick in the broken face to come
  up. Dry, but each move is a real jump, and all seven in a row is long.
  This is the mid-skill route.
- **The shooter** (timing, wet). Stand in the sheet when the head gate opens:
  the gate (the Sluice Flush's tell: gate rattle, drain) lets a surge down
  all seven weirs; step in at W1 and ride: the sheet is a **chute** 6 m
  wide that the pilot boot-surfs (slides: crouch on a slope past `SLIDE_FROM`,
  gaining to `SLIDE_TOP` 20 m/s on a 50-degree face). At each lip, the
  chute shoots you into the air (the sluice's carry rule: a jump taken in the
  water keeps its pace), and you land in the next basin's pool and the pool
  slows you (wade) before the next chute. Steer by `SLIDE_STEER` toward the
  broken lips: they spill unevenly, and the 6th basin's slump pushes you
  to one side where the **far isle's landing** is. Ride well and you arrive in
  minutes; ride badly and the surge dumps you past W7 into the drowned
  court (a low pool: not a death, a wet start on the far isle) or, if you
  are carried wide off a lip, over the edge into the haze.
- **The cheat.** Pocket-sail (glide) off the head across the gulf: 60-70 m is more
  than a sail will cross from 40 m up (the pocket sail is a glide, not
  flight; the card sets the gap past its reach on purpose). It's only
  there as a plan B that drops you into the drowned court cold.

Threat: **The tenders and the cistern clock.** Olmec headless bodies **hang
on the weir walls** (a body that climbs: `climb_max` many times its unit, `cling` =
starts on a cliff face; `city_wrap` / `city_lip` hold the hand-holds) and
drop on those who stop on a rim: the pounce from above (windup then
leap) lands a shockwave on the rim, shaking the pilot into the pool.
They climb *with* the water, the sheet carries any body not on stone: so a
body that misses is swept down tier to tier, and a pilot who is riding the
chute may meet it coming up the face. An **inhaler head** hovers at the
head of the gulf (above the first basin) and inhales anyone mid-air over
the pool, and spits them out toward the chute. Tools: the surge is a
conveyor to the bottom; bodies that fall in it are carried the same way;
the rim walks are quiet; the chute's lip is a launch you can aim.

Could combo: head spits the pilot onto the chute; a body drops from a
weir wall into the water and is swept ahead of you, lands in the pool
you are about to land in (its landing shock knocks you onward); a stunned
body in the sheet rides the falls and arrives at the far isle before you;
a wind blaster/updraft over W4 (the mist-column) could lift a rider across a
lost lip. Ports: catches a body thrown in at the head or the first
basin (a tossed pilot lands in the sheet and rides); throws out at the far
terrace at the final lip's pace (a tumbling arc into the drowned court).

Mystery: The weirs measure: each basin's rim is carved with a count of
glyphs (the day-count), and the water's pace matches the fall of days in
the city's calendar (`trap_day_count.gd`). At the bottom the stone heads in
the drowned court are *listening*: ears carved, the mouths closed. The
makers sent their water down this to be heard by something below. The
tenders stand with their necks tilted to the sound.

Kit used: `city_pillar` (isles, CityKit.PIECES), `city_drum_stair`
(the broad curved steps used as the rims' ramps), `city_stair` ("Epic
stair"), `city_terrace` and `city_wedge` (CityKitClimb: hanging
terraces and wedged chunks as the lost-lip corbels), `city_wrap`, `city_lip`,
`city_court` (CityKitLandmarks: "Ballcourt coliseum", the drowned court at
the foot), `maker_cresset` (CityKitFires), trap `trap_sluice.gd`,
`headless_body.gd`, `inhaler_head.gd`, `trap_day_count.gd`.
Kit asks:
- `city_weir` (a basin tier: brimmed lip, spill face, a `current` vector
  and a `lost_lip` break variant; collision is clean boxes for the rim walk,
  a sloped hull for the chute).
- `city_waterway` (as in the Long Leat: live water with `motor.carry` at
  the current's pace, and the chute surf: the water as a surface that
  carries a sliding body down its slope).
- `city_gate` (the head's sluice gate as a kit piece; shared with the Long Leat).
- A PilotMotor "carried slide" rule: `carry` plus boot-surf together (the
  surf's pull plus the water's pace, capped by `SLIDE_TOP`). Opus work;
  prove it through the real play loop.
Family knobs: `weirs` (4-8), `weir_drop` (4.5-6.5 m, from SET_OFF multiples),
`broken_lips` (0-3), `surge_period` (25-60 s), `tenders` (0-3).
Sockets: rim at the head shelf (facing out across the gulf, down); arena at
the head shelf (A) and the drowned court (the exit); cover on the weir
walls; perches on the crescet rims.
Generator fit: a motif with its own two shores; or an edge between a high
isle and a low one, where the plan wants a descent: a footprint of about
70 x 50 m and a **height span of 36-42 m** (the tallest drop in the city
set). Suits a tall stack layer (isles over isles) or a hanging underside.
Distinct from: `city_stair`/`city_drum_stair` (a stair is land, walked
down; here the water is the stair and the route is a descent in bursts)
and the Long Leat (long and level; this one is tall and fast, the same
water-works as a pair, different silhouettes: a comb vs a zig-zag). Also
not `stair_clouds` (a climbed mesa), nor the Coliseum Pit (a pit one
descends into) — the weirs are a crossing you fall *down*, across a gulf.

## Place (round 4)

Built in `scripts/kit_isle/greybox/gb_weir_stair.gd` (one LAYOUT table near
the top) and `weir_stair_veil.gd` (the spill sheets, mist and moss beards),
registered in `scripts/kit_isle/greybox/registry.gd` (MOTIFS, WORLD "under").
The round was revised once on review: a real gulf, uneven legs, fewer lamps,
and a wet route that is a real choice.

**Yard command.**

    godot --path . res://studies/motif_yard.tscn -- --no-title --motif=weir_stair --underground=haze
    python3 tools/drive.py scratch/weir_stair_routes.gd -- --route=dry|hang|wet|threat [--skilled] [--wait] --scene-args --motif=weir_stair [--bodies=0]

**The place.**
- **The head** (38.4) is a turf shelf with the cistern sunk in it, its
  channel and gate. A colossal head (the inhaler head's model, eyes dead,
  jaw open) sits in the lip as the maw spouting into W1.
- **The arm** runs east along the gulf and sinks two courses. Its tip is
  **the lookout**, where you arrive, and the stair is seen in profile from
  it.
- **The rib** is a spur of the head's cliff stepping north in three
  terraces, with W1-W3 sunk in them.
- **W4-W7** are tanks on legs over the void, 12 m a tier. Eight legs, each
  its own width, depth, batter and foot (-44 to -80 m, into the haze).
  - W6's east leg has snapped off short.
  - Over it, W6's east brim sags 1.2 m, and a crack lets a sheet fall free
    62 m into the haze (facing the lookout).
- **The gulf** is 55 m of air from the rib's end to the far isle, which is
  51 m under the head.
  - W7 stands 11 m short of the far isle's edge and spills its whole width
    across the gap into the drowned court.
  - Two rock stacks stand in the gap under W7's west brim.
- **The far isle** (-12.8) has the drowned court: deep water from its south
  edge to its stair, with four stone heads at the stair's ends. Beyond are
  the terrace, the lit beacon, one lamp and the rim out.

The basins widen 2.4 m a tier (26 to 40.4 m). Their tableros carry runes
(the day count). W3 and W5 have lost their lips: the water pours over 13 m
broken edges, and the next tier's west brims are broken back 4.4 m to a
set-off stub. There are tumbled blocks, sod caps and moss beards.

**Lamps.** The seven identical cressets are gone. Now there are three lit
ones, each different:
- one on W1's east brim;
- one in a niche cut in the head's cliff over W1's west terrace (jambs,
  lintel, runes);
- one on W7's east brim.

A fourth has fallen on W5's brim, tipped on its side and cold. The far
terrace keeps one lamp and its beacon.

**Distances from the motor (wanderer 1.0).** The stun is 6.0 m from the
fall's top, and a heart 9 m.
- Every weir drops one course, **4.8 m**. Each brim sits 1.2 m further out
  than the one above, so a walk-off at a run lands on the next brim.
- A lost lip's stub is **4.4 m**. The long jump (about 8 m, falling 5.5 m)
  clears it. A plain running jump (3.8 m) lands on the stub from 7.2 m:
  stunned, no heart. Hanging off first, then dropping, is 5.6 m, and the
  brim is a 1.6 m jump-catch up.
- The dry way off W7 goes stack, stack, shelf, terrace: 4.8, 4.8, 4.8 and
  3.2 m.
- Deep water catches any fall, so the surge's last throw into the court
  (18.9 m) is safe.
- Changed from the card:
  - **pitch:** 8.5 m on the rib, 12 m on the legs (the card had 14 m
    basins);
  - **total drop:** 51 m (the card had 36-42 m);
  - the 7 m drop-jumps became walk-offs, and long jumps at the broken lips.

**Routes** (the real input, `--bodies=0`, timed in game seconds from where
they fork at the arm's root):

| Route | How it goes | Fork to rim | Notes |
|---|---|---|---|
| Wet | Off the head into W1, onto the gate plate at the channel's head (the sluice's own plate trigger), ride hands-off. | **30.9 s** | Flung off all 7 lips, the last 18.9 m into the court, then swim and climb the stair. 0 stuns. Every run. |
| Dry | West brims, walking off each end; long jumps at W3 and W5; down the stacks. | **47.4 s** | 0 stuns, drops ≤ 5.5 m. |
| Dry, careful | As dry, but hang-drop onto the stubs and jump-catch up. | **51.4 s** | 0 stuns, drops ≤ 5.73 m. |

The wet route is about 35% faster than the dry and 40% faster than the
careful one. `--wait` skips the plate and waits for the 24 s gate period.

**Real vs stand-in.**
- Real:
  - KitLand (sides collided for the climbers) and CityStone basalt;
  - CityFires cressets and the beacon;
  - the inhaler head (the warden, on the head's west lip by the dry descent)
    and headless bodies;
  - `trap_sluice.gd`, one per pool. The head gate's plate is the trap's own
    plate.
- STAND-IN for city_gate / city_waterway (`SurgeClock_STANDIN`):
  - It opens the head gate every 24 s (the plate opens it at once).
  - It lets each lower sluice go as the rider is flung off the lip above
    (an empty surge relays on the wave's front).
  - It adds a funnel the straight sluice lacks: a carried rider is drawn
    onto the channel's line at 6 m/s.
  - The surge runs at 3.2 runs. At 3.8, riders slammed into the pools'
    side walls.
- STAND-IN for "surf the chute": the sluice's carry and fling (a toss at
  each lip, or a jump to keep the pace). There's no sloped chute: each
  spill is a veil over a sheer tablero. **Missing:** a PilotMotor carried
  slide and a `city_weir` piece with a chute hull.
- STAND-IN for the tenders hanging and waiting (`Tenders_STANDIN`): each
  body is set clinging (HeadlessBody `cling`) when he comes within 26 m.
  - The rims are the rib's two cliffs and W5's east leg.
  - In the threat run, two came over and roamed the brims behind the
    walker.
- STAND-IN for `city_weir`: motif-local coursed CityStone blocks, collided
  with clean boxes.

**Stills** (`captures/shots/`, gitignored):
- After review: `ws_r5_lookout.png`, `ws_r5_three.png`, `ws_r5_low.png`.
- Before review: `ws_final_*.png`.
- The Lamplighters' reference: `ws_ref_ls_three.png`.

**My read.**
- From the lookout it reads as one built stair stepping down the cliff, the
  falls white tier to tier. The far isle lies below across air, with the
  beacon on it.
- The low view shows the gulf: the legs going into the haze, the free sheet
  off W6, the last fall across the gap, and the stacks.
- Still weak:
  - The framed three view compresses the gap (the head's keel and the arm
    fill it from that angle).
  - From above, the basins are still clean rectangles.
  - The legs read as square posts; their feet vanish in the haze, so their
    uneven heights barely show.
  - The head's keel has big plain prism faces.

**Model budget** (no new model; kit-stone blocks only):
- Measured before the review: stone 69.5k triangles and 168 shapes, land
  19.5k plus turf. The legs are now thinner and fewer.
- Applies:
  - **Silhouette geometry:** the broken lips, stubs and snapped leg are real
    breaks.
  - **Vertex-colour grime:** free; CityStone does it.
  - **Visibility ranges:** on the legs' courses below the haze (y < -30)
    and the far lamp and beacon (~0.1-0.2 ms).
  - **Drop the bevels:** on the underwater paving and the legs' hidden
    faces (about -20k triangles).
- Doesn't apply: sculpt-and-bake, parallax and bones.

**Unverified.**
- The warden's inhale on a rider.
- A tender's pounce landing.
- Bodies carried by the surge.
- The pocket-sail cheat.
- The torch preset.
- A generated layer.
- No tests were added or run.

## Polish (round 4)

A dressing pass: land, routes and threat as built. `--weirstair-grey`
draws the round-3 place (clean basins, plain posts) for A/B;
`--ws-off=ramp,dips,silt,dress,legs,hill,jag,votive` switches single parts
off (a bisecting aid).

**What changed** (`gb_weir_stair.gd`, `weir_stair_veil.gd`, new kit piece
`scripts/city_kit_hang.gd`; no shared file touched).
- **Basins.**
  - The east brims are chipped (blocks lowered, tilted or missing) and
    mossy (Mesher moss 0.55 to 0.9). Moss cushions sit on brim and wall tops.
  - Each east brim has a slumped front end (W2, W4, W7) and worn dips
    (W1, W3, W5, W7), built as lower broken stretches.
  - The front walls wear down in two steps either side of the notch.
  - The water laps the walls unevenly (`wet_edge`: a ragged dry margin of
    paving and silt, clean to the notch).
  - A turf silt mound with grass sits in two quiet corners of every pool,
    off the surge's line.
  - Algae streaks and ivy fringes hang beside each spill and down the
    tanks' east and west faces.
- **Legs.** Each course is now a battered frustum with chamfered edges
  (the talud; a ledge every third course, a lean, a hand's wobble per
  course), replacing straight brick halves. Hanging ivy from the cornice,
  roots from the undersides, and water stains and algae in bands between the
  ledges. The snapped W6 leg has askew blocks, four hanging shards and
  roots off its end (no rubble pile: nothing under it to land on).
- **Lookout.** A great cresset on the knoll behind the arrival (the one
  lamp with shadows). Four dim votives (bowl, flame and halo, no light) on
  the east brims of W2, W3, W4 and W6, so the brims glow in a row without
  seven real lamps. The three cressets, the niche's and the fallen one are
  as before.
- **Hillsides.**
  - The head's and the far isle's outlines have noses and bays (kept off
    the rim, the start and the dry way's landings).
  - Both isles have knolls, slumped bowls (two sharp ones on the head
    make benches), and lips rounded down in turf. All are held flat at
    the start, rim, cistern, court, lamps, beacon and the dry way's
    stacks and shelf.
  - Stone sunk in the turf (`stones2`) and a few blocks on the rib's terraces.
  - Roots hang off every lip into the abyss, with some ivy.
  - **The far isle had no grass before:** the flora ray stopped at -8
    while its turf is at -12.8. It now runs to -20.8.
- **Water.** Each veil lands in a mist of up to 90 particles, with spray.
  Long falls (W6's free fall) break into two mid-air plumes. Mist and spray
  are visibility-ranged at 150 m.

**Routes re-walked** (real input, yard, `--bodies=0`, fork to rim) against
the round-3 numbers.

| Route | Before | After |
|---|---|---|
| Wet | 30.9 s | 30.9 s, 0 stuns |
| Dry | 47.4 s | 47.4 s, 0 stuns |
| Careful (hang) | 51.4 s | 51.2 s, 0 stuns |

- Threat (bodies on): 2 tenders cling and the surge clock fires; 0 failures.
- Full layer, `--world=under`, seed 6 sprawl (a layer with the Lamplighters'
  Stair), dry route: 47.5 s, 0 failures.
- Two polish pieces had moved the careful route's timing, so they were
  moved off it:
  - W4's worn front wall stays as it was (the hang-drop reads it).
  - The west brims of W3-W6 are not chipped.

**Stills** (`captures/shots/wsp/`, `--underground=haze`):
- Before: `before_{lookout,top,low,court,head,far}.png`.
- After: `after_*` (the same views, `c4_*` the latest).
- Reference: `ref_ls_three.png` (the Lamplighters' Stair, same haze).

**Model budget** (docs/art/model-budget.md).
- Triangles:

| | Grey | Polished |
|---|---|---|
| Stone (one mesh) | 74.6k | 60.4k |
| Hanging growth | none | 11.9k |
| Silt mounds | none | 2.1k |
| Veils | 3.2k | 3.2k |

  Net about +0.5k. The legs' frusta (about 12 faces a course, replacing
  two beveled boxes of about 50) save the 14k.
- Collision: 196 shapes against 172 (the extra stones and shards).
- Build: stood in the yard 2.9 s against 2.6 s. The growth strands go
  through RuinGrowth (the kit's path); the motif's own GDScript is
  layout and a few small loops (the jagged outlines, the roots along the
  lips).
- Applies:
  - Silhouette geometry: chips, slumps, noses and bays, the snapped leg.
  - Vertex-colour grime: free (CityStone).
  - Hanging growth, not modelled strands: ivy through the kit's growth
    material, which sways in the shared breeze; roots and stains are flat
    quads.
  - Visibility ranges: mist and spray 150 m. The leg courses below
    y -30 are not yet ranged (about 0.1-0.2 ms if they are).
  - Drop the bevels: the frusta carry only a 0.22 m chamfer; the leg
    faces hidden by the tank cornice carry none.
- Doesn't apply: sculpt-and-bake, parallax, bones.

**Unverified.** Frame time was not measured; the particles run about
600 more CPU particles than the grey path. The great cresset's shadow
light was not costed. The warden's inhale, a tender's pounce, bodies
carried by the surge and the pocket-sail cheat are as unverified as in
round 3. The sheet's lip reads as a flat white slab from straight above,
as before. The head's relief is subtle from the high play camera: the
noses and bays read, the 2 m bowls less. No tests added or run.
