# Inhaler head, round 1 (prototype)

> Round 2 (`inhaler-head-round2-scoot.md`) put it on the ground: it heaves
> itself along, and the drift, hover and many knobs below are gone.

A colossal carved stone head that floats over the isle and breathes in. It
pulls the wanderer toward its mouth, swallows him, then blows him out hard.
The face is Olmec in spirit, built as squared ruin-kit masonry.

## Play it

    ./run-inhaler-head.command
    godot --path . res://studies/inhaler_isle.tscn -- --no-title [--head-at=x,z] [--head-knob=pull=9 ...]

This is the aqueduct isle without the dragon, the lodestone or the hall
chain. The head drifts over the open turf east of the aqueduct and out past
the east rim. Kit cover stands around: two clustered piers, a wall, a carved
chest, a fallen pier, and the isle's own heel stone. You start on the south
turf, out of its sight. **R** sends you back to the start and the head back
to its round. **F1** shows the head's state, its draw and its pull on you.

## What it does

`scripts/enemies/inhaler_head.gd` is built on `enemy.gd`. It is spawned
through an `EnemyField`, the same way as the ram.

- **drift**: it drifts its round slowly and heavily, with a bob and a lean.
  Its chin hovers about 1.2 m over the turf. Out over the void it keeps the
  last turf's height.
- **notice**: once it sees you (14.5 m, 63° either side, mouth-to-chest line
  of sight), it stops and grinds round to face you. Stone dust comes off it
  as it turns.
- **tell** (1.4 s): the jaw grinds open, the eyes light and it sinks until
  its mouth is at your chest. Dust, leaves and wind wisps start streaming in.
  A weak pull starts.
- **inhale** (up to 4.5 s): the full pull. Its face tracks you slowly
  (0.45 rad/s).
- **gulp**: reaching the mouth swallows you (motor `seize`, figure hidden).
  The jaw slams shut and it holds you for 1 s while it shudders and dust
  jets from its ear flaps.
- **blast**: the jaw flies open and you are knocked out along its face
  (about 27 m, then laid down 1 s). It recoils. This mirrors the dragon's
  air blast, with knockback only and no damage.
- **after** (3 s): the jaw closes, the eyes go dark and it rises back up.

**The pull goes through the motor.** On the ground it moves you with
`PilotMotor.carry`, sliding along walls with `PhysicsGround.slide`. That
adds on top of your own running, so a lip in the way is a lip you go over.
In the air it adds to your velocity. On a rim hang your grip slips, and
after about 1.6 s at full pull you are torn off toward the mouth. Close in,
where the pull beats 92 % of your run for 0.45 s, it knocks you off your
feet toward the mouth. Crouching braces you to 55 % of the pull. Stone
between its mouth and your chest blocks the pull completely. Standing on
the head's helmet puts you out of its air, and you ride it. Its air is also
added to the pocket sail's wind (`motor.air`) and the plane's
(`plane_air`). Neither of those has been felt in play yet.

**Visuals** (`inhaler_head_air.gd`):
- Wind wisps (the wind tool's `gust_trail` shader) curl in and slide toward
  the mouth.
- Dust and leaves lift off the turf in the cone and are drawn in.
- Dust puffs mark the grinding, the gulp and the blast.
- The grass bends toward the mouth through five `zs_local_gust_*` slots
  along the cone floor.
- The blast runs a `zs_blow_0` lane out across the grass.

## Feel, from the play loop

These runs used real `Input.action_press` through the study's `tick`, with
the head facing the wanderer when it starts. They were throwaway checks and
are not committed.

| Case | Result |
|---|---|
| Stand about 5 m from the mouth | Dragged in about 1 s into the inhale, gulped, blasted off the south rim |
| Run straight away from 4 m | Escapes. Net pace is 1.6 m/s at first, then 3.7 m/s as the pull fades |
| Run from 7 m | Escapes easily |
| Run across its face from 5 m | Gets out of the cone and escapes |
| Walk away (half stick) from 4 m | Loses: dragged, gulped, blasted |
| Crouch at 4 m | Dragged more slowly (pull 2.7 vs 4.9), still gulped |
| Step behind a pier during the inhale | Pull drops to 0, no gulp |
| By the east rim, head out over the void | Dragged over the lip, catches the rim, torn off after about 1.6 s, gulped, blasted back onto the isle |

## Tuning knobs

Pass these with `--head-knob=<name>=<value>`. Defaults are scaled by your
height (unit 1.12 m), run speed (4.8 m/s) and walk speed (2.4 m/s).

| Knob | Default | What it sets |
|---|---|---|
| `size` | 3.0 | Height, in your heights (3.4 m) |
| `hover` | unit × 1.1 | Chin height while drifting |
| `hover_low` | unit × 0.28 | Chin height while inhaling |
| `drift_speed` | walk × 0.45 | Drift speed |
| `turn` | 0.55 | Turn rate while drifting (rad/s) |
| `lock_turn` | 0.9 | Turn rate while noticing (rad/s) |
| `track_turn` | 0.45 | Turn rate while telling and inhaling (rad/s) |
| `sight` | unit × 13 | Sight range |
| `sight_half` | 1.1 rad | Sight half-angle |
| `lose` | 1.5 s | How long out of sight before it gives up |
| `tell` | 1.4 s | Tell length |
| `tell_draw` | 0.2 | Share of the pull during the tell |
| `inhale` | 4.5 s | Inhale length |
| `reach` | unit × 12 | Reach of the pull |
| `cone` / `cone_near` | 0.5 / 1.35 rad | Cone half-angle, far and near |
| `pull` | run × 1.3 | Pull strength. Pull at distance d is `pull / (1 + (d / pull_d0)²)` |
| `pull_d0` | unit × 4 | Falloff distance in that formula |
| `air_pull` | 2.6 | Pull multiplier in the air |
| `brace` | 0.55 | Share of the pull while crouched |
| `trip` / `trip_pull` | 0.45 s / run × 0.92 | Off your feet after this long at this pull |
| `yank` | run × 1.5 | Speed of the knock toward the mouth |
| `grip` | 1.6 | Seconds your rim grip lasts at full pull |
| `gulp_reach` | unit × 1.15 | Gulp distance (height counts half) |
| `hold` | 1.0 s | How long it holds you |
| `blast_out` / `blast_up` / `blast_down` | unit × 24 / unit × 2.4 / 1 s | Blast distance, height and lay-down time |
| `after` | 3.0 s | Recovery time |
| `sail_wind` / `plane_wind` | 2.2 / 3.0 | Pull multipliers on the sail's and the plane's wind |

## Open question: what happens at the mouth?

You didn't specify this. For now it gulps, holds a beat, then blows you out
hard along its face, with knockback and no damage. Whether that throws you
off the isle depends on which way it faces. Other options:

- It spits you somewhere fixed, such as the void side or a secret ledge, as
  a "secret route" mouth.
- It holds you longer (you mash to escape) and drops you below.
- Its blast is aimable by you while you are inside it, which would make it
  a cannon.
- It swallows loot or kegs as well.

## The model

- **Source**: `art/blender/inhaler_head/inhaler_head_build.py`. Run it with
  `/opt/homebrew/bin/blender -b --python art/blender/inhaler_head/inhaler_head_build.py [-- --render=still.png --open=0.3 --blend]`.
- **Output**: `assets/models/inhaler_head.glb`, about 66k triangles.
- **Objects**: Head, Jaw (hinged), Eyes, Maw, and a Mouth empty.
- **Construction**: rounded boxes laid in courses with visible joints, a
  five-block band, ear flaps with square spools, a furrowed brow,
  heavy-lidded eyes, a broad nose and full downturned lips. It has noise
  weathering and a few corners broken off as flat facets.
- **Shading**: occlusion is baked into COLOR_0.
  `scripts/enemies/inhaler_head_look.gd` dresses it in the kit's stone
  material, coloured per vertex by `RuinStoneStyle.shade`, darkened by the
  baked occlusion, with moss on the tops. The eyes are polished stone that
  lights amber when it locks on. The maw is near black.

## Rough edges

- The face still reads slightly clay-soft and toy-like, more so in direct
  light. The nostril wings look like knobs. Next pass: crisper planes,
  deeper eye sockets, a broader nose.
- The head sits dark in its own shadow when backlit.
- Sounds are placeholder synth: a grind, a hiss, a gulp and a whoosh.
- The wisps are drawn whenever it draws air, even when stone blocks you.
  They show its air, not whether you are pulled.
- The aqueduct isle's heel stone stands in its arena. It is good cover.
- It doesn't steer round obstacles. A blocked leg just skips to the next
  route point, and it can hover over the carved chest, which lifts it about
  1 m.
- The sail and plane pull is wired but has not been felt in play.
- Not wired into the run generator.

## Captures

Saved in `docs/design/roguelike/inhaler-head/`. These are gitignored, so
they stay local.

- `head_idle_hover.jpg`
- `head_tell.jpg`
- `head_inhale_airflow.jpg`
- `head_gulp.jpg`
- `head_blast_out.jpg`
- `head_face_close.jpg`

## Checks

- Headless import is clean.
- `studies/inhaler_isle.tscn` ran headless for 900 frames with no script
  errors.
- `tests/test_world_scale_guard.gd` passes.
- The play-loop runs in the table above were throwaway and are not
  committed.
- Only new files were added, so no existing test should break. The full
  suite was not run.
