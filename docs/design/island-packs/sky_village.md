# Island pack: Sky village

Seven greybox arrangements of a little sky town, each on its own floating
island (or two), each with an easy way and an expert line that asks for
different moves. Pack: `studies/island_packs/sky_village.gd`. Proofs:
`tests/test_island_pack_sky_village.gd`. Recordings of every proven route:
`studies/character_runs/*village*.json` (F6/F7 in the study, newest first).

    ./run-character-study.command --pack=sky_village
    godot --headless --path . --script tests/test_island_pack_sky_village.gd
    godot --headless --path . --script tests/test_island_pack_sky_village.gd -- --save   (re-records)

Keys 1 to 7 teleport to the stations. Every island's ground is at 40 m; LOST
is 15 m, so a fall sets him back at the nearest station's spawn. Colours: orange
caps (lip) the tops meant to be caught or landed on; grey floor and walls;
dark roofs, lintels and accents; green cloth, planters and beds.

## The numbers used

Measured headless on flat ground with the motor as it is on main (03e58609),
and checked against the motor's constants:

| move | measured |
| --- | --- |
| running jump | 0.8 m up, 2.24 m along |
| running jump, twirled at the top | 5.39 m along |
| long jump from a run | 0.7 m up, 4.31 m along at 7.6 m/s |
| long jump, twirled past its top | 7.55 m along (the twirl pushes him to 9 m/s) |
| long jump chain (timed) | hops of 4.0, 5.1, 6.0, 6.8 m at 7.6, 9.1, 10.5, 11.9 m/s |
| side flip | 1.9 m up, about 1.35 m along (3 m/s) |
| slot kicks, 1.0 m clear | 1.45 m higher each kick |
| kick, then twirl back to the same wall | back on it about 1.6 m above the first touch |
| wall run off a long jump | 4.7 m along the wall; its kick carries him 4.4 m on |
| ledge catch | feet 0.48 to 1.08 m under the lip as he falls past it |
| step up | 0.45 m, also in the air (a landing a bit short of a top steps onto it) |

The user's slot climb (the "0.44 m slot") was the room's tower: a 1.0 m clear
gap between two walls, the 0.44 m being how far his feet moved across it.
The village's chimney is the same 1.0 m.

## 1 Market square: flow

Intent: open ground to carve curves in, with things to go through. A walled
market with a gate, a fountain in the middle, stalls round it, the town hall
and its raised terrace at the far end.

- Easy: walk through the gate, round the fountain's south side, up five
  0.4 m steps onto the terrace (2.0 m). Proven, recorded.
- Expert: from the gate, a long-jump chain round the fountain's north (hops
  4.0, 5.1, 6.0, 6.8 m, up to 11.9 m/s), run on past the covered market,
  stick back across for a skid and side-flip up onto its roof (1.8 m), then
  long-jump the 2.0 m gap onto the terrace. Proven, recorded. A plain
  running jump off the market roof also makes the terrace (measured).
- Other ways: the market wall (1.1 m) is a jump and a catch; the fountain's
  rim (0.4 m) is walked up; any stall roof (1.8 m) takes a side flip.

Numbers: island 48 x 30. Gate 4.8 m wide, 2.8 m clear. Lane between the
fountain basin and the covered market 3.0 m. Fountain to town hall 15 m of
open plaza. Covered market roof to terrace 2.0 m across, 0.2 m up.

Kit pieces:
- island slab 48 x 30 x 3 m with stepped rock under it
- market wall 1.0 m thick, 1.1 m tall; gate: two pillars 1.8 x 1.0 x 3.6 m,
  lintel 0.8 m deep over a 4.8 m opening
- fountain: basin r 3.0 m, rim 0.4 m; column r 0.5 m to 2.2 m; bowl r 1.3 m
- stall: counter 3.0 x 1.2 x 1.0 m, canopy 3.4 x 2.4 m at 1.6 to 1.8 m on
  two posts
- covered market: canopy 6 x 4 m at 1.8 m (a walkable roof) on four posts,
  counter 4 x 1 x 1 m
- town hall 8 x 18 x 6 m, roof slab overhanging 0.4 m, door; terrace 3 x 16
  x 2.0 m; steps 0.4 m rise, 0.8 m tread, 2.5 m wide

## 2 Chimney alley: vertical

Intent: the user's best moment, a slot climb to a high top, dressed as two
tall town houses with an alley between them.

- Easy: the balconies up the east house's front, five slabs zig-zag 1.2 m
  apart, each a jump and a catch, then straight up from the top one to
  catch the roof (7.2 m). Proven, recorded.
- Expert: into the alley at a run (the jump starts a short wall run up into
  it), then kicked wall to wall: kicks at 1.06, 2.51, 3.95, 5.39 m, caught
  the roof's lip on the rise after the fourth and climbed out at 7.2 m. Proven,
  recorded.
- Ways down: a 4.8 m house and a 2.4 m shed beyond.

Numbers: alley 1.0 m clear, 7 m deep, 7.2 m tall both sides. Balcony
columns 0.8 m apart across, 1.2 m up each; 2.1 m of headroom between
stacked balconies.

Kit pieces:
- tall town house 7 x 7 x 7.2 m, flat roof with a chimney stack 1 x 1 x 1.4 m
- alley 1.0 m clear between two houses (the chimney)
- balcony slab 2.6 x 1.4 x 0.3 m, stacked every 2.4 m on alternating sides
- low house 6 x 6 x 4.8 m; shed 4 x 4 x 2.4 m

## 3 Bell tower: twirl back

Intent: a church tower whose belfry is the prize; the expert way up a single
wall with the twirl back.

- Easy: ten 0.4 m steps up the nave's south side to its roof (4.0 m), then a
  jump and a catch into the belfry (5.2 m, 1.2 m over the nave roof).
  Proven, recorded.
- Expert: a jump and a pump at the porch's face catches the porch (2.4 m);
  from the porch, a jump into the tower's face (touches it 0.8 m over the
  porch), kick off, twirl back with the stick held at the tower: he rises
  past where the kick peaked and steps onto the belfry sill. Proven,
  recorded. Without the twirl the kick peaks 0.58 m under the sill (checked
  in the test).
- Other: the barrel (1.1 m) by the porch is a step to it.

Numbers: tower face over the porch 2.8 m. Twirl-back peak about 2.5 m over
the porch, 0.32 m under the sill, so the landing steps up onto it (the
step-up is 0.45 m). A sill 0.4 m higher would turn it into a catch instead,
with less room for error.

Kit pieces:
- nave 14 x 8 x 4.0 m, flat walkable roof; outside stair, 10 steps of 0.4 m,
  1.0 m tread, 1.6 m wide
- tower 5 x 5 m to a belfry floor at 5.2 m; belfry: four pillars 0.8 x 0.8 x
  2.4 m, roof slab 5.4 x 5.4 x 0.6 m, spire 1.6 x 1.6 x 1.8 m; bell r 0.7 m
  hanging 1.3 m over the floor
- lean-to porch 2.4 x 4 x 2.4 m against the tower; barrel r 0.55 x 1.1 m

## 4 Laundry lane: wall run over a gap

Intent: a lane between two rows of houses, laundry strung across, ending at
the island's edge with a gap to the next one; a long blank gallery wall
juts out over the gap.

- Easy: down the lane and over the rope bridge at the south corner. Proven,
  recorded.
- Expert: down the lane by the north houses, a long jump just before the
  edge (0.46 m off the wall), into a wall run along the gallery wall (4.7 m
  along it, 7.6 to 8.6 m/s), kick off it and land 1.2 m past the far edge.
  Proven, recorded. A plain long jump off the end falls (checked).
- Also works: a long jump and a twirl off the lane's end, no wall, lands
  0.3 m past the far edge (measured). Decide whether that should stay (a
  7 m gap would make it fall).
- The laundry: sheets' hems at 2.0 m; running jumps and long jumps pass
  under, a pump hits them.

Numbers: lane 6 m wide, 25 m long. Gap 6.5 m. Gallery wall face 17 m
continuous (6 m of it over the gap), 4.4 m tall.

Kit pieces:
- row houses 6 to 7 m wide, 7 m deep, 3.6 to 5.2 m tall, roof slab 0.4 m
  overhanging 0.2 m
- long house with a jettied gallery wall 6 x 1 x 4.4 m out over the void
- laundry line at 2.6 m with sheets 0.6 m tall (hem 2.0 m)
- rope bridge: plank deck 8 x 1.2 m, rope rails at 1.0 m, end posts 1.3 m
- well r 1.0 x 0.9 m with posts and a little roof; cottage 6 x 5 x 3.6 m

## 5 Roofline: surf into a long jump

Intent: a hillside street. The upper terrace stands 9 m over the lower
street; a barn's roof runs down from the terrace's edge; off the lower
street's edge, the garden island is 10 m out and 1 m lower.

- Easy: down the stair beside the barn, then over three hanging planters
  1 m apart with a jump (a pump) on each. Proven, recorded (one planter is
  caught and climbed in it rather than landed on).
- Expert: off the terrace onto the roof crouched, surf down it (12.3 m/s at
  the eave), hop off the eave onto the street, long-jump off the street's
  edge with the pace kept and twirl: lands 1.2 m past the garden's edge.
  Proven, recorded. Without the surf a long jump and a twirl off the street
  lands on the last planter (checked).

Numbers: roof 10 m along the ground, 9 m to 1 m (39°), 8 m wide. Lower
street 6 m deep. Gap 10 m (planters 2 m long, gaps 1 m). The stair is a
30° ramp in the greybox.

Kit pieces:
- terrace wall 14 x 16 x 9 m (the upper street's edge)
- barn 10 x 8 m with a 39° single-pitch roof from 9 m to 1 m
- outside stair 2.5 m wide down 9 m (30°, 15.6 m along)
- hanging planter 2 x 2 x 0.4 m
- garden island 14 x 14 m: pergola 5 x 4 m at 2.4 m on four posts, bed 9 x 2
  x 0.4 m

## 6 Water towers: tank to tank

Intent: a yard of water tanks on legs beside a warehouse; the big one is the
prize.

- Easy: round the big tank's catwalk, a lap and a half up six 1.2 m ramps
  (12°) with landings at the corners, then a plank onto its top (7.2 m).
  Proven, recorded.
- Expert: up the warehouse steps to its roof (3.6 m), then tank to tank:
  each a long jump from just short of a rim, 1.2 m up, catching the next
  rim (feet 0.6 m under it), climbed: 4.8, 6.0, 7.2 m. Proven, recorded. A
  running jump and a twirl also catches the next tank (measured).
- Note: a tank top 4 m across is small for a long jump's pace: landing on
  one at 7.6 m/s he slides off the far side and catches its rim. Catching
  the next rim is the natural line; the proof brakes on each top.

Numbers: rim gaps 2.5, 3.0, 2.8 m, each tank 1.2 m over the last. Catwalk
on a 5.8 m square, 1.2 m wide, rising 1.2 m a side.

Kit pieces:
- warehouse 10 x 12 x 3.6 m, flat roof; outside stair, 9 steps of 0.4 m
- water tank r 2.0 m (big r 2.2 m), body 1.2 to 1.6 m tall, on four legs
  r 0.12 m
- spiral catwalk: ramp 5.8 x 1.2 m rising 1.2 m, corner landing 1.2 x 1.2 m,
  top plank 2.4 x 1.0 m

## 7 Town gate: through and across

Intent: the town wall and its gate (go through it), a wall walk on top, and a
narrow lane inside between the wall and a guardhouse.

- Easy: ten 0.4 m steps up against the inside of the wall to the wall walk
  (4.0 m), along it over the gate. Proven, recorded.
- Expert: into the lane at a run, a jump starts a wall run along the town
  wall, kick off it across the lane to catch the guardhouse roof (2.8 m),
  climb, then a running jump back across the lane catches the wall walk.
  Proven, recorded.
- Unproven but likely: kicking up between the guardhouse and the wall (2.0
  m apart, under the 2.8 m that gains height).

Numbers: wall 2.5 m thick, 4.0 m tall; gate 3.2 x 3.2 m. Lane 2.0 m. Wall
run kicked off 1.8 m along, caught the guardhouse lip with the feet 0.6 m
under it; the jump back took off 0.15 m short of the roof's edge and caught
the wall walk with the feet 0.6 m under it.

Kit pieces:
- town wall 2.5 m thick, 4 m tall, walkable top; merlons 0.5 x 0.8 x 0.9 m
  every 1.6 m on the outer edge
- gate opening 3.2 x 3.2 m; flanking towers 3 x 3 x 6 m with roof slabs
- inside stair along the wall, 10 steps of 0.4 m, 1.0 m tread, 1.2 m wide
- guardhouse 4 x 10 x 2.8 m with a chimney; milestone 0.8 x 0.8 x 1 m

## Reusable pieces across the pack

The same few pieces recur and could be one kit: flat-roofed house blocks
(6 to 7 m wide, 3.6 to 7.2 m tall) with 0.4 m roof slabs; 0.4 m steps
(0.8 to 1.0 m tread); 1.2 m-step ledges and balconies; canopies and roofs
at 1.8 m (side-flip height); 1.0 m slots between buildings; blank walls
15 m and longer for wall runs; plank bridges and catwalks 1.2 m wide.

## Handoff

Branch `worktree-agent-a1a343e364ba15842`, from main 03e58609.

Proven by the test, headless, end to end with scripted inputs, each saved as
a recording that `tests/test_character_recordings.gd` replays: the easy way
and the expert line at all seven stations (14 routes), and that each
expert's key move matters: no twirl, no belfry; no wall run, no crossing the
lane's gap with a plain long jump; no surf, no garden.

Not proven, or needing the user's eyes:
- How it looks. Nothing was rendered; colours and proportions are untested
  on screen.
- The proofs press Jump on the right frame (the chain's hops buffered on
  each landing). The user's late re-hops (166 to 250 ms) would break the
  market chain into separate long jumps; the plaza has room for that, and
  no critical path needs a chain.
- The chimney's recording replays 7 cm from its recorded end (inside the
  test's 25 cm); the others replay exactly. Probably some state outside the
  motor's snapshot; not looked into.
- The market's weave room is modest (a 3 m lane between the fountain and the
  covered market); the plaza could grow if chains want wider curves.
- Station 4's gap also falls to a long jump and a twirl (0.3 m to spare).
- Station 6's tank tops are small for landing at a long jump's pace.

Part types: no blocker. Pitched roofs and stairs are greyboxed as `ramp`
(single pitch, 0.4 m thick); a gable needs two ramps. `obox` turns only
about up, so no tilted canopies. The rope bridge is rigid.

Open questions for the user:
- Should the bell tower's twirl back end in a catch (sill 0.4 m higher,
  tighter) or the forgiving step-up it is now?
- Laundry lane: keep the long-jump-and-twirl crossing as a second expert
  line, or widen the gap to 7 m so only the wall run makes it?
- Are 4 m water tanks right, or should tank tops be landable at speed
  (5 m or more across)?
- Which of these should become a real art kit first?
