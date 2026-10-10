# Ruins archipelago (island pack)

Greybox platforming pack for the character study: seven floating-island
arrangements of an old city's ruins. Each station is a bit of ruin you could
believe (a temple avenue, an aqueduct, a watchtower, a cloister court, a fallen
bridge, a triumphal arch, a fallen colonnade). Each is built from a few
reusable pieces, and each has an easy route plus an expert line that uses
different moves.

- Pack: `studies/island_packs/ruins_archipelago.gd`
- Play: `./run-character-study.command --pack=ruins_archipelago`. Keys 1–7
  teleport to the stations. F6/F7 replay the saved routes.
- Proofs: `godot --headless --path . --script tests/test_island_pack_ruins_archipelago.gd`.
  Add `-- --save` to re-record the routes into `studies/character_runs/`.
- Layout: the stations stand 100 m apart along x (station k sits around
  x = 100(k−1)). Every island's top is at 30 m, with a stepped keel of rock
  under it, and LOST is at 5 m.
- Colours: grey `wall` is standing stone, `floor` is ground, orange `lip`
  marks a top made to land on or hang from, `dark` is fallen or broken stone,
  and green `pad` is moss.

## The moves, as measured in this pack

All of these were measured headless through the study (pilot_motor.gd as it is
on main 03e58609), not taken from the docs:

| move | measured |
|---|---|
| running jump | 0.8 m up, 2.24 m reach |
| running jump, twirled at its top | 1.1 m up, 5.4 m reach |
| long jump from a run | 4.18 m |
| long jump, twirled just past its top | 7.4 m (7.8 at the court's 8.9 m/s, 8.45 with a 1 m drop) |
| long jump chain, timed on each landing | hops 4.3, 5.1, 5.9, 6.7, 6.8 m at 9, 10.4, 11.8, 12, 12 m/s |
| pump | 1.5 m |
| side flip | 1.9 m up, about 1 m along. Catches lips up to 2.8 m (court rim) |
| wall kicks between facing walls | 1.0 m and 2.6 m apart both climb without limit, about +1.42 m a kick |
| wall run from a run (4.8 m/s) | 3.4 m along the wall. With its kick, 5.4 m from start to landing, peak 1.5–1.65 m over the ground |
| wall run from a long jump (7.6 m/s) | about 5 m along. Clears the colonnade's 6 m break with the kick |
| twirl back after a kick | reaches a ledge 1.9–2.0 m over the kick point (tower: kick at 5.06 m, sill at 7.0 m; arch: kick at 3.35, impost at 5.4) |
| catch reach | a jump catches a lip up to about 1.9 m over the takeoff, a pump up to about 2.5 m |
| surf | a 35° slab 2.8 m tall gives 8.9 m/s at its foot |

The 1.0 m chimney is the user's "0.44 m slot": the room's slot was 1.0 m
between the faces, which leaves the 0.56 m-wide body 0.44 m of travel.

## 1 Temple avenue: columns, a broken wall

**Intent.** This is the flow station: open ground to carve curves through a
field of columns, plus a gentle first climb.

**Layout.**
- A processional avenue 6 m wide (x ±3) runs 30 m from the spawn to the
  temple. Columns 1.2 m Ø line it every 5 m, so each gap is 3.8 m clear.
- Either side is a field of columns on a 6 m stagger, with gaps where columns
  fell. The fallen ones lie 0.9 m high, and loose drums are 1.2 × 1.0 m.
- At the end is the temple: three 0.45 m steps up to its floor, 1.35 m high.
- The cella's front wall (0.8 m thick) is broken in steps of 1.2, 2.4, 3.0
  (the lintel over a door 2 m wide and 2.4 m tall), 3.6 and 4.8 m over the
  floor.
- Porch and back colonnade: 8 m columns, a 2.4 m stump, two back columns at 6
  and 4 m, and the architrave still resting on two of them.

**Routes.**
- *Easy (proven):* walk the avenue, up the steps, jump-catch onto the 1.2 m
  wall stump, then walk the wall top. Each 1.2 m step is a jump-catch and
  each 0.6 m step a jump, up to the 4.8 m top.
- *Expert (proven):* a running long jump down the avenue, chained on every
  landing and weaving the stick ±20° between the colonnades. It took 6 hops to
  12.7 m/s and stayed within 2 m of the avenue's middle, landing on the temple
  floor up its steps (a chain lands up 0.45 m steps).
- *Open, not driven:* weaving through the side field. The 6 m back column
  (orange top), 2.3 m behind the 4.8 m wall top, is meant as a pump-catch
  perch.

**Kit pieces.**
- Column 1.2 m Ø, standing at 4, 6 and 8 m; broken stumps at 1.2, 2.4 and
  4 m (orange tops).
- Fallen column 5.4–6 m long, lying 0.9 m high. Loose drum 1.2 × 1.0 m.
- Temple steps 0.45 m rise, 0.8 m run. Stylobate 1.35 m.
- Wall 0.8 m thick, broken in 1.2 m steps. Door 2 × 2.4 m with a 0.6 m lintel.
- Architrave block 5.6 × 1.2 × 0.65 m.

## 2 Aqueduct: a fallen span, a blind wall

**Intent.** Walk along a ruin's top line across the sky. The expert line is a
wall run into a chimney.

**Layout.**
- The channel is 2.4 m wide and 6 m up, on piers 2 m thick. The arches are
  4 m wide with 4 m clear under the spandrels, which run from 4 to 6 m.
- The aqueduct's head is a blind wall 12 m long where the arches were walled
  up. A 30° rubble slope leads up to it: 10.4 m along, 2.4 m wide, stepped
  rubble under it.
- The aqueduct crosses 16 m of sky to a second island on hanging piers that
  break off below.
- One span has fallen. Its broken spandrel stubs (0.5 m) leave a 3 m gap.
- At the far end it comes down in 1.2 m rubble drops.
- East of the blind wall stands a buttress 1 m thick, 6 m long and 5.2 m
  tall, 2.6 m off the wall.

**Routes.**
- *Easy (proven):* up the rubble slope, along the channel, a running jump
  twirled over the 3 m fallen span (a long jump also clears it), then on and
  down the rubble.
- *Expert (proven):* run along the blind wall's east face and jump with the
  stick a little into it. The wall run carries him along the face, Jump kicks
  off to the buttress, and one kick off the buttress catches the channel's
  lip at 6 m. It took 2 kicks in all.
- *Open, not driven:* slaloming through the arcade's arches on the island.

**Kit pieces.**
- Aqueduct pier 2.4 × 2 m; arch opening 4 × 4 m; spandrel/channel block 2 m
  tall.
- Broken spandrel stub 0.5 m. Hanging pier, 15–17 m with a broken foot.
- Blind wall section 12 m. Buttress 1 × 6 × 5.2 m.
- Rubble slope 30°. Rubble block 2.4 m square, in heights of 1.2.

## 3 Cracked watchtower: the crack, the shaft

**Intent.** The vertical station, built round the user's best moment: kicks up
a slot, then a twirl back to a ledge.

**Layout.**
- The tower is 4.2 m square with 0.8 m walls, which leaves a 2.6 m shaft
  inside (the kicking width).
- The crown is broken: the west wall stands 10 m, the east 8.8 m, and the
  south 6 m over a door 1.4 m wide and 2.2 m tall.
- The north wall is 7 m up to a window 1.2 m wide.
- A slab split off the north face stands 1.0 m out (the crack). It is 3.2 m
  long, 0.8 m thick and 5.4 m tall.
- Fallen blocks, each 1.8 × 2.0 m and 1.2 m higher than the last (1.2, 2.4,
  3.6, 4.8 m), with 0.6 m between them, climb the east side to the south
  wall.

**Routes.**
- *Easy (proven):* up the fallen blocks (jump-catches) onto the 6 m south
  wall.
- *Expert (proven):* step into the crack and kick up it, 4 kicks at 0.8,
  2.2, 3.6 and 5.06 m over the ground. The last kick (off the tower) carries him over the
  slab's top. With the stick held back and a twirl at its top he turns back to
  the tower and catches the 7 m window sill. This is the user's
  "kicks + twirl to the 5.4 m ledge" moment, 1.6 m higher.
- *Expert (proven):* in at the door, then 6 kicks up the 2.6 m shaft onto the
  10 m crown.
- *Not proven:* going from the sill into the shaft and on up. Stepping off the
  sill inward tends to leave him hanging from its inner edge. The crown is
  proven only from the door.

**Kit pieces.**
- Tower wall 0.8 m in broken heights (6 / 7 / 8.8 / 10 m).
- Door 1.4 × 2.2 m. Window 1.2 × 1.6 m with a 7 m sill.
- Split slab 3.2 × 0.8 × 5.4 m. Fallen block 1.8 × 2.0 m in heights of 1.2
  to 4.8.

## 4 Sunken court: a fallen slab, the pool

**Intent.** Go down into a space and out again, with a surf into a long jump
over water.

**Layout.**
- A cloister garth 16 m square, sunk 2.8 m (the side flip's reach), with
  0.6 m coping round its rim.
- Rim columns 0.7 m Ø and 3.2 m tall stand round it, some broken.
- Steps of 0.4 m (0.8 m deep) go down its west side.
- In the middle is the impluvium: a pool 6 m across and 1 m deep, its water
  0.2 m under the floor. Falling in means a slow swim out, never death.
- A paving slab 3 m wide has fallen in from the north rim at 35°.
- An altar 1.6 × 2.4 m and 1.4 m tall stands 1.2 m off the east wall.

**Routes.**
- *Easy (proven):* round the rim, down the steps, across the court, up onto
  the altar (jump-catch), and from it onto the rim (jump-catch, 1.4 m).
- *Expert (proven):* run off the north rim onto the slab and crouch to surf
  it (8.9 m/s at its foot). A long jump off its foot over the pool, twirled,
  reaches 7.8 m and lands dry. Then a side flip up the 2.8 m south wall onto
  the rim. The slab is walkable back up as well (35° < 44°).
- *Note:* the 2.8 m rim is near the side flip's limit, which is about 2.97 m.

**Kit pieces.**
- Court walls 2.8 m with 0.6 m coping. Step 0.4 / 0.8 m.
- Pool 6 × 6 × 1 m. Paving slab 3 m wide (4.9 m on the slope).
- Altar 1.6 × 2.4 × 1.4 m. Cloister column 0.7 m Ø, 3.2 m (stumps 1.0–2.0).

## 5 Fallen bridge: islets, two lines

**Intent.** An islet chain with two lines side by side: a forgiving one and a
fast one.

**Layout.**
- Two islands 31 m apart.
- East line, the bridge deck's slabs:
  - 3 m square, 1.6 m apart (a running jump goes 2.2 m).
  - Each steps 0.4 m up or down from the last, with a broken column on each.
  - The last slab is a bigger piece, 4.7 m long.
- West line, the piers' caps:
  - 2.8 m wide and 1.8, 2.7, 3.7 and 4.8 m long, with gaps of 3.3, 3.3, 3.2
    and 3.0 m.
  - Then 5.1 m to the far island.
  - The caps are spaced from measured chains, so a long jump chain pressed
    anywhere from 0 to 0.1 s after each landing lands on every cap and leaves
    it before its end.
- On the far island stands a gate 6 m wide (piers 1.5 × 1.2 × 5 m), half its
  lintel fallen.

**Routes.**
- *Easy (proven):* running jumps from slab to slab, then through the gate.
- *Expert (proven):* a running long jump off the near island, chained on every
  landing (5 hops to 12 m/s), with the last hop twirled over the 5.1 m.
- *Expert, late (proven):* the same chain pressed 0.1 s after each landing
  still makes it.
- *Fails, measured:* 0.13 s and later slides off a cap. Unchained play (0.22 s
  or later) cycles about 6 m per hop, which no fixed cap spacing can serve
  along with the timed chain. This line is timing-critical by design, and the
  east line is the forgiving route.

**Kit pieces.**
- Deck slab 3 × 3 × 2 m with a rock chunk under it. Bridge pier cap 2.8 m
  wide, 1.8–4.8 m long, on a 2 m pier.
- Gate pier 1.5 × 1.2 × 5 m. Half lintel 4.5 m. Fallen lintel 4 × 0.8 m.

## 6 Arch and the stair to nowhere

**Intent.** A landmark with two very different ways up: walk, or the twirl
back.

**Layout.**
- A triumphal arch: the opening is 4 m wide and 5 m tall between piers 3 m
  square, with an attic 2 m tall over them (top at 7 m).
- The attic is set back 0.7 m from the east pier's face, which leaves the
  impost as a ledge at 5.4 m.
- West: a stair of 0.4 m steps (0.8 m deep, 2 m wide, 14 steps) that once
  reached the attic. It now stops 1.6 m short of it and 1.4 m under it.
- East: a block of the attic fallen on end, 2.4 × 3 m and 2.6 m tall, 1.4 m
  off the east pier.

**Routes.**
- *Easy (proven):* up the stair, then a running jump across the 1.6 m,
  caught on the attic's edge and climbed.
- *Expert (proven):*
  1. A side flip out of a skid onto the 2.6 m block.
  2. A run off its west edge into the pier, onto the wall at 3.35 m.
  3. Kick off, hold the stick back and twirl. He comes back to the pier and
     lands straight on the 5.4 m impost.
  4. A jump-catch up the last 1.6 m onto the attic.
- *Note:* an impost that juts out over the gap failed: it caught his head on
  the kick. The ledge has to be the top of the wall he kicks from, so the
  attic is set back from the face.

**Kit pieces.**
- Arch pier 3 × 3 × 5 m. Attic 2 m, set back 0.7 m on the impost side.
- Stair step 0.4 / 0.8 m, 2 m wide; a broken top step.
- Fallen attic block 2.4 × 3 × 2.6 m. Voussoir rubble about 1.5 × 0.8 × 1 m.

## 7 Fallen colonnade: columns over the chasm, roof slabs

**Intent.** Cross a chasm: balance along a fallen column, or wall-run a break.

**Layout.**
- Two islands 22 m apart, with two of the colonnade's big columns (1.8 m
  drums) fallen across.
- East: one whole column, lying 8° skew and 25 m long. You walk it.
- West: one column broken in two, its far half sunk 1 m. The break is 6 m:
  a twirled long jump clears it, a plain long jump (4.2 m) doesn't.
- Beside the break stands a fragment of the colonnade's back wall on its pier,
  1.8 m off the column's line, 8 m long and 6.5 m tall.
- On the far island is the pediment wall, 4 m tall and 1.2 m thick, with roof
  slabs 3 m wide fallen against it at 20° (walk up), 30°, and 50° (surfs on its
  own).

**Routes.**
- *Easy (proven):* along the whole column over the chasm, then up the 20° slab
  onto the pediment wall.
- *Expert (proven):* along the broken column, a long jump off its end with the
  stick toward the wall fragment, then a wall run along it and a kick back
  onto the far half.
  - A wall run from a plain running jump covers only 3.4 m and drops short.
  - The long jump's pace is what makes it reach.
- *Expert, alternative (proven):* a long jump off the column's end, twirled.
  It went 8.45 m with the 1 m drop.
- *Open, not driven:* surfing down the 30° and 50° slabs onto the island.

**Kit pieces.**
- Big column 1.8 m square-section drum: whole 25 m, broken 8 + 10 m.
- Wall fragment 0.8 × 8 × 6.5 m on a hanging pier.
- Pediment wall 24 × 1.2 × 4 m. Roof slab 3 m wide at 20° / 30° / 50°
  (11 / 6.9 / 3.4 m long), with rubble under it.

## Shared kit (summary for the art pass)

| piece | sizes |
|---|---|
| column | Ø 1.2 m (temple), standing 4/6/8 m, stumps 1.2/2.4/4 m; Ø 0.7 m cloister 3.2 m; 1.8 m drums fallen 8–25 m |
| drum / rubble | 1.2 × 1.0 m drum; blocks 1.8 × 2.0 m in 1.2 m heights; voussoirs about 1.5 × 0.8 × 1 m |
| wall | 0.8 m thick, broken in 1.2 m steps; door 2 × 2.4 m and 1.4 × 2.2 m; window 1.2 × 1.6 m |
| steps | 0.4–0.45 m rise, 0.8 m run |
| aqueduct | pier 2.4 × 2 m, arch 4 × 4 m, spandrel 2 m, channel 2.4 m at 6 m; buttress 1 × 6 × 5.2 m |
| tower | 4.2 m square, 0.8 m walls, 2.6 m shaft; split slab 1.0 m off |
| slabs | paving / roof slab 3 m wide at 20–35–50°; deck slab 3 × 3 m |
| arch | pier 3 × 3 × 5 m, opening 4 × 5 m, attic 2 m (set back 0.7 m) |

Key spacings: slot 1.0 m and shaft 2.6 m (wall kicks), ledges 1.2/1.4/1.6 m
(jump-catch), 2.6–2.8 m (side flip), gaps 1.6 m (running jump), 3 m (twirled
running jump or long jump), 5–6 m (twirled long jump or chain), and a wall run
needs to start within about 0.6–1.0 m of a glancing wall.

## Handoff

**Proven** by the test, headless, all 23 checks passing. Each route is also
saved as a recording, and `tests/test_character_recordings.gd` replays all 17
to within 0.01 m. That test's only failure is the known pre-existing
`20261010_005619_tech-fun-fluid-movement.json`.
- 1: the avenue walk to the 4.8 m wall top; the weaving long jump chain to the
  temple.
- 2: rubble, channel and twirl over the fallen span to the far island; wall
  run → buttress → channel.
- 3: blocks to the south wall; crack kicks + twirl back to the 7 m sill; shaft
  kicks to the 10 m crown.
- 4: steps, altar, rim; slab surf → long jump over the pool → side flip out.
- 5: slab hops; the chain + twirl; the chain pressed 0.1 s late.
- 6: stair → attic; side flip → kick → twirl back → impost → attic.
- 7: column walk → 20° slab → pediment; long jump → wall run → kick across the
  break; twirled long jump across it.

**Not proven, or needs your eyes:**
- Nothing has been seen rendered. All work was headless, so check how the
  ruins read: silhouettes, label placement, and where pieces cut into each
  other (fallen columns sink into the island edges, rubble under the ramps).
- The tower's window sill into the shaft and on to the crown isn't driven, and
  the weave through the temple's side field isn't driven.
- Also undriven: the aqueduct's arch slalom, and the 30°/50° roof-slab surfs.
- Fallen columns are square-section boxes lying flat, because `obox` only
  turns about up. A lying cylinder and a pitched or rolled box would let
  toppled columns and leaning slabs sit at real angles; the leaning slabs use
  `ramp` instead. None of this blocked a route, so the study script was left
  alone.

**Questions for you:**
1. The bridge's chain line tolerates presses 0–0.1 s after landing. Your
   re-hop timing (often 0.17–0.25 s) will slide you off its caps. Keep it as
   the precise line, with the east slabs as the forgiving one? Or lengthen the
   caps and accept smaller gaps and a less dramatic last jump?
2. The court's 2.8 m rim is right at the side flip's limit. Is that the feel
   you want ("just made it")?
3. Should the stations become one connected archipelago? Right now they are
   100 m apart in a row, reached by number keys.
4. Do the stations read as ruins, or as courses? Which pieces should the art
   kit start from? The candidates are the aqueduct span, the cracked tower and
   the arch with its set-back attic.
