# Tower shell, round 1

A new ruin-kit piece: the broken shell of a square tower with a wall-kick
chimney inside. It is the fast way up. The turret's winding stair stays the
safe, slow one.

Branch `feature/ruin-tower-shell` (from `roguelike` e076a219). Not merged.

## Run it

    ./run-tower-shell.command                       # the study: tower on flat ground
    ./run-tower-shell.command --tower-height=16 --tower-weathered=1
    ./run-tower-shell.command --tower-open          # the back wall torn away
    ./run-ruin-kit.command --family=tower           # the gallery (F4 frames the tower family)

In the study, walk in at the door and turn to a side wall (east or west).
Jump at it, then press Space each time you touch a wall. He kicks across
the shaft and up. The stick doesn't matter on the way across (see below),
so you can let it go. At the top he lands on the rim or catches its lip
(Space climbs). Keys: R or 1 the doorway, 2 the shaft's foot, 3 the rim,
F1 numbers, F2 feel.

Study knobs: `--tower-height=` (12), `--tower-weathered=` (0..1, 0.5 in the
study), `--tower-seed=` (1), `--tower-open`.

## Interface (agreed with the crossing)

`RuinKitTower.tower_shell(seed_value: int, weathered := 0.0, height := 12.0, open_side := false) -> Node3D`
(scripts/ruin_kit_tower.gd; also `RuinKit.piece("tower_shell", seed, weathered)`).

- Foot on y 0, round the origin. The front (door) faces +Z. It has "Mesh" and "Body", as every kit piece does.
- Outer footprint: 4.78 (x) by 5.40 (z) m. The plinth and string course stand 0.14 m further out. Rubble and drifts stay inside about 3.9 m of the origin. `RuinKitTower.half_extents()` gives (2.39, 2.70).
- Doorway: centred on x 0 in the front wall, from z 1.3 (the shaft's face) to z 2.7 (the outer face). It is 1.3 m clear wide, springs at 2.0 m and peaks at 2.6 m. The threshold and the shaft floor are true slabs, top at y 0.
- Shaft: x ±0.99, z ±1.3. The kick walls are its east and west faces.
- Top: the two kick walls always stand whole to `height`. Their heads form a 1.4 m wide walkable rim at y = `height`, at x from ±0.99 to ±2.39 and z ±1.3. The inner edges (x = ±0.99, y = height) are the lips the last kick catches. The front and back walls' heads are walkable wherever they stand whole. Weathered, they are ragged and lower.
- Meta: `shaft` (AABB), `kick_gap`, `kick_gain`, `rim`, `lips` ([[from, to], ...]), `door` (foot of the door on the front face, (0, 0, 2.7)), `door_size`, `footprint`, `breaches` ([AABB, ...]).

## Shaft spacing: how it was derived

A kick (`PilotMotor._kick_off`) sends him up at sqrt(2·GRAVITY·WALL_JUMP)
= 8.53 m/s and out at WALL_KICK = 5.2 m/s. The rise is uncut, and the
stick is ignored for WALL_LOCK = 0.28 s. He leaves the near wall with his
body radius plus the slide's skin between him and it (0.29 m, from
`PhysicsGround.RADIUS`·wanderer + SKIN). He feels the far wall when his
feet are WALL_PROBE (0.45 m) from it.

The kick should reach the far wall at ARRIVE = 0.85 of WALL_LOCK, which is
0.238 s:

    KICK_GAP = WALL_KICK·0.238 + WALL_PROBE + body = 1.24 + 0.45 + 0.29 = 1.98 m

At that moment he is still rising at 2.34 m/s and has gained 1.29 m
(KICK_GAIN). A press held to the kick's top gains WALL_JUMP (1.4 m).
Because he arrives inside the lock, the stick never matters on the way
across, and the motor takes hold of the wall as a kick's.

Everything is computed from the motor's and the wanderer's constants
(static vars), so the gap follows if any of them change. The motor
header's 2.8 m example shaft gains about 1 m a kick, but there he arrives
after the lock and the stick has to be let go or turned round.

The kick walls collide on clean, true slabs, not on their drawn stones.
Worn, chipped or settled faces would send a kick off at an angle, and a
ray through a joint would miss the wall. The stair treads walk on true
boxes for the same reason. Each wall's stone hulls are dropped and
replaced by 0.25 m strips: one flat inner face, nothing to snag. Slits are
drawn in them, but the slab is solid across them. The front and back walls
keep their stones' hulls, with true tops on their heads, the breach sills
and the threshold.

## Breaches and the open side

The number of breaches is round(weathered·4). They alternate between the
front and back walls, between 3.2 m and (height − 2.2) m. Each is
1.5–2.6 m tall and 1.0–1.7 m wide (it grows with weathering), with a
nearly flat sill (a true slab you can stand on) and a ragged point at its
head. They are a way out mid-climb, or a place to fall out. Kicks never
cross them, because the kicks run east–west.

`open_side` tears the back wall down to a ragged 1–4 m line, so the shaft
becomes a U open behind, and all breaches go to the front. Wall-running
the open edge was not tried.

## Verified headless

`tests/test_tower_shell_climb.gd` (about 3 s) drives the study through its
scripted input path (stick and Jump, `tick`) with the real motor and
physics ground. In each case he walks in at the door, takes a run-up, jumps
at the east wall and presses Jump on each wall touch, until he stands on
the rim.

| Case | Kicks | Climb time | Least gain per kick |
|---|---|---|---|
| 12 m, weathered 0 | 8 | 2.8 s | 1.32 m |
| 12 m, weathered 0.5 | 8 | 2.8 s | 1.32 m |
| 12 m, weathered 1, open side | 8 | 2.8 s | 1.32 m |
| 16 m, weathered 0.8 | 11 | 3.6 s | 1.32 m |
| 12 m, weathered 0.5, every press 0.1 s late | 8 | 3.5 s | 1.39 m |

In every case the last kick catches the rim's lip and he climbs onto it.
The test also checks the interface: kick timing and rise, footprint
≤ 8 x 8, the foot round the origin, the rim at the full height, and the
door on +Z.

Also run: the import, and headless loads of the study (`--tower-open`) and
the gallery (`--family=tower`), with no errors. One windowed gallery
capture shows the intact and weathered pair.

## Not verified

- The full suite was not run. `tower_shell` is now in `RuinKit.ALL_PIECES`, so `tests/test_ruin_kit.gd` and `tools/ruin_stone_dump.gd` will build it too. It was written to their checks (real hull volumes, a flat top, stone and growth only, size), but those tests haven't been run on it.
- Hand feel in the windowed study (camera in a 2 m shaft, timing by eye) has not been played.
- Falling out through a breach, stepping out onto a sill mid-climb, wall-running the open side, and the twirl back to a wall: none of these were driven.

## Notes for playing

- The camera is tight in a 2 m chimney. It pulls in to the near limit. Breaches and `--tower-open` help you see.
- If the last kick comes up over the rim instead of under its lip, he can carry across the 1.4 m rim with the kick's 5.2 m/s. With the stick let go he brakes or catches the far edge. Pull back if he runs on.
- Press only at a wall. A press in mid-shaft, or above where the wall still counts (the head within 1.2 m of the feet), pops the pocket sail.
