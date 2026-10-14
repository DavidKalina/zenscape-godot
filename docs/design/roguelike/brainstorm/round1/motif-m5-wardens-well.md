# The Warden's Well — "Nobody leaves. They are posted."
Lenses: verb = defend / hold ground; purpose = prison; mood = playful (the comedy of being fired from a face); decay = drowned; twist = the threat is the only way across. Scale: colossal hall, human cells. Shape in a layer: a ring.

Pitch: You drop into a flooded colossus hall: a ring of cell alcoves round a sunken well, and over the water a huge stone head that turns to look at you. The doors you want are across a void where the floor fell in, and the warden's inhale is a cannon: you stand where it must find you, brace behind a pillar until it lines up, and let it eat you.

Top (1 char ~ 4 m; `C` pillar cover, `H` the head's round, `~` void, `w` flooded floor, `A` arena, `S` entry stair):
```
          ^^^^^^^^^^^^^^^^^^
        ^^  [cell 3]  [cell 2]^^
      ^^ P     ######## ~~~~~    ^^
     ^  [cell 4] #C  C#  ~~~ [c1] ^
     ^     ~~~~ #w  H  w#  ~~~~    ^
     ^ 1  A C   #w ooo w#   C  A 2 ^
     ^     ~~~~ #wwwwwww#  ~~~~    ^
      ^^        ####S####        ^^
        ^^^^^^^^^^^^^^^^^^^^^^
```
Side (through the hall: dais, drowned floor, void, cells):
```
          cell tier ___                       ___ cell
 entry  /__________|   |                    |    |___
 dais   |  ~~ wwwwwwwwwwwwwwww  H (hover) wwwww  ~~~ void |
 [1]    |__|______ drowned floor ________|______ keel     |
```

Play:
1. Enter by the entry stair onto the first dais (`1`): a ring-shaped hall, colossus columns and architraves holding up half a roof, the central floor flooded to the knee (wading), and the ring of cells on the far side of a void where the floor broke. The head (`H`) hovers over the water, eyes dark.
2. Hold ground: it notices you (the lock turn, stone dust, the grind) and starts the tell. Run at it and you are eaten with no say in it. Behind a hall column you are cover (the pull never reaches a pilot with a pillar between), crouched you brace; wall-kick off the column and watch its face track you. The dais is yours to hold against the pull.
3. Aim: the blast sends you along its face, and the face follows you. Step out of the lee at the dais's lip so that the line head -> you points past you at the cell; grip the rim (the pull's `grip` seconds) and let it draw you into the mouth. Gulped, held, then blown across the void onto the cell's wading apron. The cone is forgiving on purpose; there is one good angle per cell.
4. Misaimed: blown into the void (soft fail, a layer down) or into the flooded moat at the ring's edge (a swim; climb out). Hide a moment and it loses you and drifts on.
5. Cell by cell: each of the 2 to 4 cells has a cache (a rune set, a chest, a caged sky-folk). The exit (`2`) is a rim on the far side, reached by one last blast, so the route chains: dais -> cell -> cell -> exit rim. Cells are skippable but the exit is always an inhale across.
6. Optional second warden (`body` knob): the headless body roams the ring floor looking for its head, shoving. Lure it over the void and it falls; the head hovers lower and its pull softens for a while. A flung pilot, a walking body and a floating head, all just physics.

Threat: the Inhaler Head (scripts/enemies/inhaler_head.gd, its gulp -> blast states) used as a cannon the place was built around; the headless body (scripts/enemies/headless_body.gd) as the second, wandering warden. The blast carries you the one way you cannot jump; the pull, the pillar cover and the body-into-void trick make an ordinary-physics puzzle of it.

Combos (the blast is a `knock` that names the head as its source, so it throws and stuns; stun-round1: different sources chain freely, one source cannot restun for 1.2 s, the cap breaks you out after 3 s; the head draws an airborne pilot at `air_pull`):
1. By accident, the loop: the headless body shoves you off the dais (its own named source) -> airborne in the head's cone, you are drawn into its mouth -> gulped -> blasted across the void, stunned -> poise returns mid-arc, you twirl -> land on a cell apron. Body, head and your own recovery, three sources, and it happened to you. (To verify: the pull on an already-stunned body in the air.)
2. On purpose, two heads (`cells` 3 or 4 gives a second, smaller head over the second void): dais -> blast #1 flies you low across the first void -> you aim the arc with a twirl so it passes through head #2's cone -> drawn in mid-air and gulped by head #2 -> blast #2 along its face to the exit rim and on. Spat from one Olmec head into another, as asked, and the skilled line skips the middle cell.
3. The enemy chain: lure the headless body to the lip of a void and slide into it: knocked off, it falls, and the head's pull weakens and sinks low; stand in the sunk head's reach and the blast is a flatter, longer shot (the head's mouth is lower, `hover_low`). The body is a tool, not only a wall.
Ports: catches (from any rim, because the hall is open on its roof side): a body thrown in by a neighbouring isle's cannon, a head or a dragon swipe, any airborne body inside the head's cone is drawn to the mouth and re-fired along its face. The hall is a re-aimer: a thrown pilot who would have missed a rim is gulped and shot at the cell. Throws: out of the exit blast, north, 24 m x the pilot unit out and 2.4 up (`blast_out`, `blast_up`), the longest throw in the layer; so the generator can aim the exit rim at the next isle's rim or at an updraft (a wind horn) within about 24 m, and the pilot arrives stunned unless he recovers in the air.

Mystery: the hall was a prison and the head its warden, posted to inhale anyone who tried to cross the well, the body the guard cut from it. The cell doors face inward. Scratches on the walls are tallies, then maps of the void, then in the last cell a tally of throws: someone found the way out once.

Kit used (verified): hall family `hall_column`, `hall_beam`, `hall_slab`, `hall_bay`; gothic `floor`, `vault`, `fallen_pier`, `stairs`, `grand_stair`, `tomb_chest`, `wall`; ruin_kit_cloister `heap`, `pavilion`, `slab_bridge` (cell aprons); tower `tower_shell` (outer wall); water: the shared KitWater (wading floor). Enemies: inhaler_head.gd (+ inhaler_head_air.gd, inhaler_head_look.gd), headless_body.gd. Foot pieces: a rope bridge (scripts/rope_bridge.gd) so a return path exists.
Kit asks:
- New behaviour, not a piece: the head reacting to the body falling (sinking low, a softer pull; combo 3), and a smaller head variant for the second void (the `size` knob may cover it).
- A barred cell-door piece (a hall_bay variant with a stone grille).
- A round well floor (a ring of `floor` / `hall_slab` with a round hole); the current floors are rectangular.
- Floor groove lines pointing at the blast target (decor).
- Olmec-style architecture for the hall itself (hall_column reads gothic-colossal, not the makers').

Family knobs: `cells` (2 / 3 / 4); `gap` (1.5 / 2.0 / 2.5 x the pilot's chained long jump, floored with WorldScale.opening; it is flown, so never under his jump); `body` (absent / present); `flood` (dry / wading / swim-deep).

Sockets: rim: the entry stair (facing south, run-up on the dais) and the exit rim (facing north). arena: the first dais (room ~8 m radius; the head's range). cover: behind each hall column, under the half roof. perch: the cell with the chest, the last cell for a trader.

Generator fit: role hero (the layer's prison), footprint about 90 x 90 m, height_span ~24 m (the head hovers high), a ring. Entry fixed south, exit north, since the generator never turns isles; it suits a layer with a stack above it.

Distinct from: hollow_keel (a fly-through undercroft the plane glides; this is a walked, flooded prison where the enemy is the route) and drowned_nave (no enemy, no launch). The Inhaler Head has only been a hazard to avoid; here it is aimed.

## Greybox (Opus pass)

The first build (Sonnet) relayed head to head only by keeping head 2 awake with study knobs (`sight` 30, `reach` 20, `tell` 0.4, `inhale` 60, `lock_angle` 3.2, `track_rest` 30, `lose` 8), with about 1 m of landing margin on the exit rim. Chain C was never completed.

Run: `godot --path . res://studies/greybox/wardens_well.tscn -- --no-title` (files: `studies/greybox/wardens_well.gd/.tscn`). The whole layout is the `LAYOUT` table at the top of the script, fed by a few constants (`Y_DAIS`, `Y_CELL`, `Y_EXIT`, `H1`, `LIP`, `H2`). R resets (heads back, body gone). B spawns or removes the headless body. F1 numbers show both heads' states, and "head 1 hears it" while the chain C stand-in is active.

**Head 2 now runs on default knobs.** Its only overrides are `size` 2.0 (the card's smaller head) and the one-point `route` that posts both heads.

### Stations

1. Start, in the flooded entry (wading).
2. The lee of lip post W. Head 1 cannot see you here. Step out east onto the lip.
3. The dais lip, on head 1's axis, 6 m from its middle. **Chain A.**
4. Cell 1, 3 m in front of head 2's mouth. **Chain B.**
5. Cell 2, reached by the plank.
6. The exit rim.
7. The lee of column E. Press B and wait. **Chain C.**

### What I rearranged, and why

**The well now steps down: dais 0 m, cell 1 -4 m, exit rim -11 m.**
- A head's blast lands only about 10 m out on the level (13.9 m/s, 2 m peak, then about 7 m of skid).
- Landing lower adds flight time, so each void can be wider.
- Head 1 to cell 1 flies about 13 m.
- Head 2 to the exit rim flies about 15 m.

**Head 2 is placed where head 1's skid ends.**
- Head 1's blast is deterministic: the pilot always lands at about (0, -8.1) on cell 1 and skids to about (0, -14.9).
- Head 2 sits 4.5 m east of that point (at z -14.9), facing west straight at it.
- It notices you as your skid ends in front of it, pivots at most once, and runs its own 1.8 s tell while you are still down (about 1 s).
- Then the inhale yanks you in, and it fires you west along the line to where you lay.
- So the "blast goes back along its line to you" rule now aims head 2 at the exit rim.

**Head 1's aim comes from where you stand, so the lip makes it hard to misaim.**
- The lip is 6 m from head 1's middle (4.4 m from its mouth). Half a metre either side of the axis stays inside head 1's no-turn band (0.6 x `lock_angle`, 0.096 rad), so it fires dead north.
- The first build's lip was 1.9 m from the mouth, where a step sideways turned the head.
- Lip post W (a 0.9 x 0.8 m pier) hides the lip's west approach, so head 1 first sees you about 0.85 m off its axis.
- Without the post, walking out from cover let head 1 lock on while you were still off to the side. Its tracking pivots are capped (0.256 rad, then a 0.55 s rest), so it gulped you before it had turned back, and the shot went north-west off cell 1. That happened 2-3 times in 10.

**Margins.**
- Void 1 is 7.5 m (dais edge z 1.2 to cell 1 at z -6.3). You land 1.6-1.9 m past its far edge, and at least 1.7 m from cell 1's sides.
- Cell 1 runs 3.5 m west of the skid lane, so a slightly west-aimed shot still lands and stops on it. Its west edge is x -3.5.
- Void 2 is 7.5 m (x -3.5 to -11). You land on the exit rim at x -12.9, which is 1.9 m in, and come to rest at about (-19.7, -13.3), more than 8 m from any edge.
- A kerb on the exit rim's south edge stops a shot that comes in south of west.
- I did not use a kerb along cell 1's west edge. Kerbs stop a tumbling skid dead: you do not slide along them, so a kerb there would leave you wherever you hit it, at an angle that misaims head 2.

**For chain C,** the body now spawns on the dais's east side (9.5, 2.4) and is after head 1. The pilot hides in column E's lee. On the west side, lip post W would block the shove's path.

### Reliability

Throwaway checks, kept out of the repo: `C:\Users\Tenut\AppData\Local\Temp\claude\greybox-checks\wardens_well-opus\probe.gd` and `runall.sh`. Each run goes through the real motor and the study's `tick`, with the start position jittered by ±0.5 m and timing by ±0.2 s. A run counts when the pilot comes to rest on the exit rim (chain C: when he reaches cell 1).

| Chain | Result | Notes |
|---|---|---|
| A, standing at the lip (station 3, no input) | **10/10**, and 10/10 on a second seed | Head 1 to cell 1, then head 2 to the exit rim, about 14 s |
| A, walked out from the lee of lip post W (station 2, stick held 0.85 ± 0.2 s, then released) | **10/10**, and 10/10 on a second seed | |
| B, standing in front of head 2 (station 4) | **10/10**, and 10/10 on a second seed | |
| C, body shoves you into head 1, real head and body | **0/10** | See below |
| C, with the two STAND-INs below | **9/10, then 8/10** on a second seed | |

Why chain C fails with the real head and body:
- The body's shove lands you in front of head 1, but head 1 never saw you, so it has not wound up.
- The body reaches its head about 2 s later and lifts it off its neck before head 1 can lock on, tell and gulp. A reunited head does not breathe.
- In an earlier try without stand-in 2, the body walked into the line of fire during the gulp and knocked the blasted pilot aside.

With the stand-ins, a successful run goes: shove at about 4.5 s, then you land 1.5-2.5 m in front of head 1's mouth, are gulped, fired north, land on cell 1, and head 2 relays you on to the exit rim. In the 3 misses out of 20, the shove landed you about 4 m from the mouth, and the body reunited before the drag reached you.

Run without any stand-in, the relay is already the card's "spat from one Olmec head into another", on stock knobs.

### Stand-ins

- **The heads are posted** with a one-point route (their own spot), so they never heave off.
- **Chain C, STAND-IN 1: head 1 "hears its body".**
  - With the body walking within 13 m (`HEAR_BODY`), head 1 goes straight into its tell along its current facing.
  - While it draws, it does not grind round after you (`track_rest` and `lose` raised only while the body is near).
  - Engine change needed: **InhalerHead hearing.** A heavy step, a shove or a slam within a `hear` knob starts the tell along the current facing, and `_track` in tell/inhale turns the head only toward a pilot it can see. This is the README's top combo blocker, "heads can't hear".
- **Chain C, STAND-IN 2: the body waits while its head eats.**
  - The body stands still while head 1 holds you and for 0.6 s after the blast.
  - Engine change needed: in **HeadlessBody._walking**, hold still while `head.swallowed` or for the first moment of the head's "after". Today `_reunite_near` only refuses while the head is swallowing, and the body keeps walking into the line of fire meanwhile.
- **Not built:**
  - The onward exit throw.
  - The round well floor, barred cell doors, groove lines and Olmec art.
  - The flood beyond the entry pool.

### Engine changes, in order of value

1. **Head hearing** (as above). It would make chain C real and let heads be primed by noise instead of by being seen first.
2. **The body holds off while its head is drawing or eating** (as above).
3. Optional: **a `post` knob for a cannon head** that keeps a fixed blast bearing whatever it tracks. Aim would then be a property of the place rather than of where you stand. The relay does not need it now, but it would free the lip from the post-and-axis arrangement.

### Still open

- **The voids are wider than a level chained long jump (about 6.7 m), but each void drops 4-7 m.** A long jump with that drop, or the sail, can probably still cross. "The threat is the only way across" holds only if the sail is taken away here. Not tested.
- **Crouching does not hold you against the pull.** It halves the pull but you are still drawn in, so the card's "hold the dais" works only behind cover.
- **Once you press B, the body ends up reuniting with head 1.** After that head 1 is gone from the route until you press R.
- **No visual or in-hand check.** Everything above is headless.
- **No existing test references this greybox, so nothing is broken.**
- Smoke (headless, 400 frames): clean, with no script or parse errors.
