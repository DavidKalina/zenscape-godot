# Port: the dragon's sight, his air blast, and the stun, from `roguelike` to `main`

Branch `port/dragon-stun`, off `main` at 8630491e (the merge base with
`roguelike`). Three features that suit any version of the game, brought over
without the roguelike's traps, enemies, run layer or motifs.

## What came over, in order

| on this branch | from `roguelike` | what |
|---|---|---|
| 030a60a8 | b8572d6e (merge, `-m 1`) | **dependency:** the dragon's downwash. The air blast sizes itself from `DragonDownwash.MODEL_SPAN`, and the vision greybox and `sky_dragon.gd` read `dragon.downwash`. |
| d46c5a55 | 824f3e33 (merge) | **the dragon's sight:** cone, awareness, tells, the overlay, the vision greybox (`studies/dragon_vision_study.tscn`, `run-dragon-vision.command`), in the scene catalog |
| 06ac2fe2 | 3e593d28 (merge) | **dependency:** the cyclone. The air blast borrows its streak mesh, and the greybox keeps it behind `--attack=cyclone` / K. |
| 6b15aaba | 02097a08 (merge) | **the air blast**, his default attack in the greybox |
| 81045c51 | 926f4151 | **stun, the motor:** fall stun, the roll, poise, the tech, stun locks |
| 964b37b6 | 65c45c49 | **stun, the figure:** the procedural ragdoll and the dizzy (adapted, below) |
| 2e966762 | d659907b | the air blast a hard hit, the dragon naming himself as the source |
| e48ffd2b | 020b976d, 7787a469 (reduced) | the stun yard (reduced) and its test; the stun handoff moved to `docs/design/stun/round1.md` |

All the merges and commits picked cleanly except the figure. Not needed:
the dragon spine (c3025f18): the air blast and the stun build, run and pass
without it. Not needed: the wind blaster knock (77fd2ec7), which is all
`scripts/traps/trap_wind.gd`.

## Adapted

- **The figure (65c45c49).** `main`'s `pilot_figure.gd` predates the
  wanderer look (ca325962 is on `roguelike` only), so it has no face, no
  hat or cape springs, and no `PilotPaint.GLOW`. The ragdoll's code came over
  unchanged. The gather's `express("squint")` is dropped, and the dizzy uses a
  local `DIZZY_GLOW` (the sheet's `5fe6e6`).
- **The stun yard.** On `roguelike` it is built on the trap contract and the
  Plinth Ram. Here it keeps the drop ladder (1-8) and replaces the Ram, the
  blaster and the kicker / Sky Ray / seesaw chain with **9, the blast post**:
  a `DragonAirBlast` fired from a fixed post at its deck while you stand on
  it, a hard hit onto a floor one stun fall below. T toggles the tech, and
  `--knob=` sets the motor's knobs. Its test covers the ladder (0.75x a
  landing, 1.25x down then up, the roll at 1.6x), the post (knocked off, no
  sail, laid down below) and T. `stun_kicker.gd` is dropped.
- **c07b913e** (enemies and traps naming themselves as the source, the Sky
  Ray carrying a downed body) is dropped whole: every file it touches is
  roguelike-only.

## Left on `roguelike`

`scripts/traps/`, the trap yard, `scripts/roguelike/`, `studies/run_layer*`,
`data/layer/`, the motif families and gallery, the cannon, the Plinth Ram and
`scripts/enemies/`, the seesaw, the roguelike design docs (including the
shortlist edit in 020b976d), the dragon spine and the dragon grip (e076a219),
the wanderer look, and the Sky Ray / tumble / bridge rounds.

## Behaviour on main beyond the features

- The **downwash** (a dependency) is on for the sky dragon and the roost
  dragon's wake flight: the plane and the pocket sail feel his wingbeats, and
  the aqueduct isle's dragon pushes air.
- The **stun** is on everywhere the wanderer walks. Falls past 4 pumps
  (`fall_stun_pumps`) lay him down, and `tumble_immune` is 0 (was 0.8). A
  tossed stunned body stays stunned. The sky dragon's knocks name him as the
  source.
- The sight, the cyclone and the air blast only fire where a host sets
  `blast_on` / `cyclone_on`, which today is only the vision greybox. The
  game's dragons don't shoot.

## Tests (headless)

- Import: clean. `studies/zenscape.tscn` `--quit-after 300`: loads, no
  errors. The vision greybox loads.
- Pass: test_pilot_stun, test_stun_yard, test_dragon_sight,
  test_dragon_air_blast, test_dragon_cyclone, test_dragon_downwash,
  test_dragon_wake, every test_pilot_* and test_character_* except the two
  below, test_pocket_sail, test_pocket_sail_study, test_slam,
  test_world_scale_guard, test_world_scale_fit, test_kit_audio,
  test_aqueduct_isle, test_aqueduct_isle_sail and test_aqueduct_isle_sky.
- Fail, already on `main` before the port: test_pilot_tricks ("Twirling low,
  Jump pressed again neither opens the sail nor flies"), and three runs of
  test_character_recordings ("Tech. Fun, fluid, movement", "village 1",
  "village 5").
- Fails because of the port: test_character_recordings "Fluid Gameplay 2"
  strays at 30.23 s, after a landing at 30.20 s. That is the fall stun, the
  same as on `roguelike`. It is not re-recorded and not in known_failures:
  that is the user's call.
- The full suite was not run.

## Unverified

Everything visual needs a windowed look: the ragdoll on main's older
wanderer (its bone turns were tuned against the restyled one), the dizzy, the
roll, the sight overlay, and the blast's look. See `docs/design/stun/round1.md`
and the dragon docs' own unverified lists.
