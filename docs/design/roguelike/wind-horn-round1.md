# Wind-horn, round 1

A stone wind-horn for the ruin kit: the launch point for the crossing yard's
gust arrows (the dragon's air blast). Old ruin-builders' device, still blowing
at anything that moves. Art, structure and the head's runtime only; nothing is
wired into the crossing.

## See it

- `./run-wind-horn.command` (windowed, `--no-title` already passed). The head
  tracks the pilot and loops tell (0.8 s) -> fired -> rest. **P** knocks it out
  for 4 s. Keys 1 front, 2 30 m out, 3 on the pedestal. Flags
  `--horn-weathered=0..1 --horn-seed=n`.
- Gallery: `./run-ruin-kit.command --family=horn`, or **F5** (family "horn").
- Captures: `docs/captures/wind-horn/{near,far}_{rest,tell,fired,disabled}.png`
  (`tools/capture_wind_horn.gd`; far = about 30 m).
- Test: `tests/test_wind_horn.gd`.

## Interface

`RuinKitHorn.wind_horn(seed_value: int, weathered := 0.0) -> Node3D`
(`scripts/ruin_kit_horn.gd`). Foot on y 0 round the origin, front +Z. Also
`RuinKit.piece("wind_horn", ...)`, `RuinKit.HORN_PIECES`, and it is in
`ALL_PIECES`.

Nodes:
- `Mesh`, `Body`: the pedestal (octagonal courses, 1.2 m high, apothem 1.6).
- `Head` (Node3D, at the pedestal top): the pivot. Yaws about +Y, pitches a
  little. Own `Mesh`, `Body` (chest hull) and:
- `Head/Mouth` (Marker3D): at the horn's mouth, **pointing along the head's
  +Z** (`mouth.global_transform.basis.z`). Clear radius
  `RuinKitHorn.mouth_radius()` = `DragonAirBlast.ball_radius() * 1.3`; also in
  meta `mouth_radius`.
- `Rig` (`scripts/wind_horn.gd`, added by the builder; get it with
  `RuinKitHorn.rig(horn)`):
  - `aim_at(world_point, delta)`: turns the head toward the point at
    `TURN_RATE` 0.9 rad/s (pitch `PITCH_RATE` 0.5, within +-`PITCH_MAX` 0.22).
    A little dust off the turntable while it grinds round. Call every frame.
  - `tell(share)`: share 0..1 through the wind-up; dust and leaves are drawn
    into the mouth, the head shudders. `tell(-1)` (what `windup_share()` gives
    out of a wind-up) or not calling for 0.15 s ends it.
  - `fired()`: recoil kick of the head plus a puff from the mouth.
  - `disabled(seconds)`: head slumps (mouth tips down 0.6 rad, sags, drops),
    dust ring and a procedural crack/thump; it grinds back up over the last
    35 % of the time with a judder and a puff. `aim_at`, `tell`, `fired` do
    nothing while disabled.
  - `is_disabled() -> bool`.
- Meta: `top` (standable cap height, 2.83 m at defaults), `top_radius` 1.1,
  `ped_height` 1.2, `mouth_radius`.

## Standable top (for the slam)

Cap of the head's chest: a flat octagon, apothem 1.1 m, at 2.83 m over the
foot (`PED_H + GRAB_TOP - 0.25`), clean collision hull in `Head/Body`. It
rises and falls with the head's pitch/droop only by a few cm (the chest is
under the pivot's yaw). Reach: jump onto the pedestal (1.2 m, under
`CHAIN_TOP`; its top ring is 0.4 m wide), then catch the cap (1.63 m above, under
`GRAB_TOP`); or drop onto it from a ledge. The horn's bell has no collision, so
the Mouth's ball never starts inside a hull.

## Swap into the crossing (not done)

In `_arrows()` of `studies/crossings/crossing_viaduct.gd`, per perch:
1. Replace the dark `column(...)` with
   `var horn := RuinKitHorn.wind_horn(seed, 0.3)`; add it as a child at the
   perch's foot (position x/z of the column, y at the perch floor), and
   rotate `horn.rotation.y` to taste (the head turns itself).
2. Use `horn.get_node("Head/Mouth").global_position` as the `mouth` for
   `arrows.add_launcher(mouth, zone)` (the head moves slightly: if the
   launcher caches the mouth, re-read it each frame or pass the node).
3. Each frame from the launcher's blast (`DragonAirBlast`):
   `rig.aim_at(pilot_chest, delta)`; `rig.tell(blast.windup_share())`; when
   `blast.shots` increases, `rig.fired()`.
4. The blast's aim along the head: fire from the Mouth toward the pilot as now
   (the head is just a cosmetic follower, turning at 0.9 rad/s, so a fast
   pilot can outrun its facing: that is the point of the "heavy" turn).
5. Knock-out: when the slam is detected on the cap (standing on `top`), call
   `rig.disabled(secs)` and pause the launcher while `rig.is_disabled()`.
6. Mind the footprint: pedestal apothem 1.6, the mouth reaches 3 m out.

## Verified

- Headless import clean; `tests/test_wind_horn.gd` passes (3 seeds x 0/1
  weathered: nodes, mouth fits the ball, jump/catch heights, hull top equals
  `top`, head turns slowly and ends facing a point, disabled/aim/wears off).
- Windowed capture run of the stand-in scene (see captures). Tell, fire and slump
  all read; the horn is readable as "points and blows" near, and as a stone
  tube at ~30 m.
- Not run: the full suite, the study windowed with live input, `test_ruin_kit.gd`
  (see below if run).

## Notes

- No glow: the motes and puffs are plain alpha meshes (dust, leaf green).
- Look is the kit's faceted stone; the bluish cast in the captures is the
  capture rig's plain light, not the look pass.
