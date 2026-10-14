# Lidstack — "Each lid says: lay one more above me."
Lenses: verb = climb; scale = colossal; purpose = tomb; decay = root-bound; twist = an Olmec piece as terrain (colossus columns as the burial stack's spine).

Pitch: A necropolis built upward: terraces of burial niches stacked round a hollow colossus column, each lid a floor for the next, the whole thing strangled by oak roots hanging down the faces. You arrive at the bottom and the only way is up the throat of the thing or round its outside.

Top (1 char ~ 4 m; the footprint is small, the point is the stack):
```
    .  .  .  .  .  .  .  .  .
    .       ^"""""""^         .
    .     "# #7# #"""         .
    .   1==# [ T ] #==4       .
    .   P  C o  o  C          .
    .       ~~~~~~            .
```
T = central tower_shell chimney, [ ] the hall_column ring, 7 summit, 1 landing, 4 exit rim, == root ropes, o the live lids.

Side (a tall stack):
```
         7 summit lid (tomb_chest) ~36 m
        ###  T  ###
       #  terrace 5  #   o tumble lid
      ##  terrace 4   ##
     ### terrace 3 [ voussoir lid row ] ###
    ####  terrace 2  ####   = roots
   ##### terrace 1: landing ######
```

Play:
1. Land on terrace 1, a floor ring round the base of the central colossus column. Each terrace is a floor lid of wall and floor slabs set SET_OFF (1.6 m) above the last, so you ledge-grab from lid to lid and chain-jump the harder ones.
2. Two routes. Inside: enter the tower shell by its pointed door and wall-kick the chimney up (the fast line), leaving by side windows at terraces 3 and 5. Outside: climb the stairs and buttresses round the faces, and ride the root ropes across the corners.
3. Terrace 3's lid is a row of loose voussoirs over a gap: run, do not walk, or fall to terrace 2 (a short fall; the stack is a catch-net below).
4. On terrace 4 or 5 a tumbling lid-block turns slowly over the stair's mouth: time the crossing. At the summit are the chest and the exit rim (4): pocket sail to the next isle, or flow-charge updraft in the chimney to launch.

Threat: the voussoir row (scripts/traps/trap_voussoirs.gd) as the false lid, and the tumbling block (scripts/traps/trap_tumble.gd) as the heavy lid hung over the open gap. The voussoirs are a tool when run in order (the first only tests, per its own rule); the tumble's wall beside it is a kick line once it has passed. The roots are live ropes that cross the gaps the lids leave.

Combos (knock/toss throw a stunned body on, the trap on each lid acts on it, different sources chain, one source cannot restun for 1.2 s):
1. Accidental: the tumbling lid-block (named source) knocks you off terrace 5's stair mouth, stunned; you land on terrace 3's voussoir row, a toss that carries the downed body; the slabs drop (the row works on a stunned body, 0.375 s delay, nothing to run at), you fall to terrace 2 onto the root rope belly which sheds you to terrace 1. Three terraces lost, none of the cost in health.
2. On purpose, up: run the voussoir row, take the chimney door, kick up to the updraft vent at terrace 4's window, which launches you above the tumble block's arc; flow-charge down onto the block's top as it tips away, riding it round to the stair mouth, then step off at the top.
3. On purpose, out: a cannon on terrace 5's far corner (scripts/cannon/) fires you across the gulf toward the exit rim (4) and the next isle; arriving stunned (a tumble block knock first) still works, because the cannon's launch is a toss and keeps the stun.
Ports: catches a body thrown in at the terrace-1 landing rim (a head blast or cannon from a neighbouring isle lands on the ring floor, a wide low catch) and anything landing from above on the summit lid (the chest as a pad); throws out through the summit exit (4) over the lip along the cannon's aim, and a tumbling body falling off any face lands on the next terrace down, never the void (the stack is the catch).

Mystery: The stack was built a lid at a time, one tomb above another; whoever died last is at the top. The giant column in the middle is not a pillar but the first resident, set upright to carry the rest. The ruin-builders buried their dead above themselves.

Kit used (verified): hall_column, hall_beam, hall_slab (ruin_kit_hall.gd), tower_shell (ruin_kit_tower.gd), tomb_chest, floor, wall, stairs, grand_stair, buttress, turret, fallen_pier, stone_circle (ruin_kit.gd PIECES), aqueduct_stump and aqueduct_end (terrace posts and root-bridge heads), rope-bridge heads and slab bridge (ruin_kit_cloister.gd), swing ropes (root hangings), trap_voussoirs, trap_tumble.
Kit asks:
- A "niche wall" piece: a wall face with burial slots in rows, climbable as a ladder of handholds.
- A stepped terrace-ring piece (ring floor with an inner stepped lip) so the stack reads as terraces.
- An updraft vent piece (scripts/updraft.gd exists) set in a stone sill, for the chimney window.
- A cannon plinth for scripts/cannon/ on the summit corner.
- An Olmec basalt head or face slab for the central spine, instead of stacked hall_columns.

Family knobs:
- `terraces`: 4-7 (height).
- `core`: chimney / stair-only (whether tower_shell is the spine).
- `lid_trap`: voussoirs / tumble / both.
- `rooted`: 0-1 (how much of the facade hangs with swing ropes and cover).

Sockets: rim at the terrace 1 landing (facing out over the drop) and at the summit exit (facing out); arena on terrace 1's ring; cover in the niches behind columns on terraces 2-5; perch on terrace 3's corner.

Generator fit: role filler or hero; footprint about 28 x 28 m; height_span about 36 m; suits a tall stack and a layer that wants a strong vertical beat.

Distinct from: bell_spires (rock spires, belfry, rope bridges) and broken_ring (a spiral of islets): this is a single tight mass built outward as terraces, climbed up and inside by wall-kick, with traps that are the building's own lids.

## Greybox (Opus pass)
Run: `godot --path . res://studies/greybox/lidstack.tscn -- --no-title` (files: `studies/greybox/lidstack.gd` + `.tscn`; the whole layout is the const table at the top of the script). First build (Sonnet): the tumble lay on T4's north strip crossed across its turn, so a rider was slid off its low edge before the lurch and never truly knocked; the vent was a fixed toss zone; the cannon could not take a stunned body.

Stations (number keys): 1 T1 start . 2 T2 (up S1) . 3 T3 row A run (combo 2a) . 4 T4 south strip, west of the lid (combo 1: run east across it) . 5 T5 S4 top . 6 summit . 7 chimney door (combo 2b) . 8 T4 window onto the lid (combo 2b vent) . 9 summit cannon (combo 3) . 0 T4 far deck past the lid . - T2 pit mouth (the vent grate) . = T1, watching the catching cannon.

What moved, and why:
- **The south face is now the fall face.** The tumbling lid (real, size 4.5) moved to T4's south strip, its axis along x (yaw 0), so the route crosses it *along its axis*, west to east, from S3's top round the west strip. Its top turns toward the south (the terrace edge), so whatever is on it when it lurches is thrown south, down into the open lane under it. Crossed across its turn (the first build) a rider slides off the low edge before the lurch; crossed along its axis he stays on the face through the tip and the lurch knocks him (`motor.knock`, source the tumble, stunned "knock"). Late on the lid by up to about 1.3 s of its 5.8 s cycle = knocked; early or after the lurch = across. No tumble knob changed.
- **Row B, terrace 3's false lid, lies under the lid** (5 slabs, 4.8 m wide, run north from the south edge so the never-falling test slab is away from where bodies land). The knocked body lands on it down (0.5 s+), the slab drops at 0.375 s, and it falls 7.2 m to T2.
- **The vent grate** (STAND-IN) is T2's floor under row B, set off only by a body on it (standing or laid down), so a stunned fall always lands first and is thrown still stunned. It throws to the catching cannon's barrel along the motor's own arc (aimed from where he lies).
- **The catching cannon** (STAND-IN catch round a real `cannon.gd`): on a 4.8 m plinth before the door, out of reach on foot. A stunned body in its zone is held 0.5 s and fired by `cannon.fire()` + `motor.toss`, so it flies on stunned.
- **The exit isle** (PORT out, 8 m, top 2 m) is 46 m south; both cannons are aimed at it in code (heading, pitch and power notch solved from the motor's arc), so the turf pass can move it.
- **The T4 vent window** moved to the core's south wall, facing the lid; its vent (STAND-IN) is 2 m deep on the window side of the shaft and throws onto the lid's top. A kicker up the shaft's middle passes it and can still reach the open top.
- Row A (north gallery), S1-S3, the lid ladder and the summit are as built; S4 now rises from the south. The mass is now built as layers (each tier from the one below's top), so a roofed passage no longer fills an open cut above it (the door corridor runs under the T2 pit).

Chains, headless through `study.tick` and the real motor, 10 runs each, start ±0.5 m and timing ±0.2 s:
- **Combo 1 (accidental, down and out): 10/10.** Run east across the lid about 1 s before its lurch: knocked (thrown, stunned "knock") -> lands on row B, slab drops -> lands on the T2 grate, thrown stunned -> caught stunned by the cannon -> fired stunned -> lands on the exit isle. Every link held in every run. Stun carries: poise never returns between links.
- **Combo 2b link (T4 window vent onto the lid's top): 10/10** walked in from the window; **10/10** kicked up the chimney's window side from the door.
- **Combo 3 (summit cannon, on foot, to the exit isle): 10/10.**
- Combo 2a (row A run, then S3) and the 26-kick chimney to the top still work (single runs). Walking row B from T3 drops you and you catch its lip (no chain).

Stand-ins: the T4 window vent and the T2 grate vent (toss zones; a vent piece is a kit ask), the catching cannon (its catch and fuse), the plinth, the square tiers, lid ladder boxes, no root ropes or root belly (ropes refuse a tumbling body), no Olmec face.

Engine changes still needed:
- **The cannon catches a thrown body** (`scripts/cannon/cannon_field.gd`): a body tumbling into a cannon's mouth zone is taken in (`motor.rider`) and fired after a fuse along its aim, by `motor.toss`, so it stays stunned. The greybox's `CatchCannon` is the spec.
- **An updraft vent piece** (a toss along an aim, from `scripts/updraft.gd`'s lift or a new trap), with a "grate" mode set off only by a body lying or standing on it. The greybox aims each throw at its mark from where the body is; a real piece needs a shaped jet or a narrow grate for that.
- **Ropes take a tumbling body** (`swing_rope.gd` rejects `move == "tumble"`): needed for the root belly the card wants under row B.

Open for the user: combo 1 now ends out of the level (fail forward: a mistimed lid crossing on T4 skips the summit). The card had it shed you to T1 instead ("three terraces lost"); aim the catching cannon back at T1, or drop it and land the grate on T1, if that reads better. A deliberate fall-stun from T3 onto the plinth would also be caught.