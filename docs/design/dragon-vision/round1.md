# Dragon vision, round 1

An experiment on the `roguelike` branch, built as a greybox. The dragon can
see you, in the air or on an isle, so cover matters. He is deaf while
flying, so there's no hearing. On spotted he only roars this round.

## What was built

- **Sight module:** `scripts/dragon_sight.gd` (RefCounted). `SkyDragon`
  owns it as `sight` and runs it every frame he flies, on his own flight
  (`advance`) and on the roost dragon's wake circuit (`wake_fly`). Asleep,
  or with no target, he is blind and awareness drains. The host gives him
  the pilot through `dragon.sight_target`, a Callable that returns
  `{"points", "airborne"}`. `DragonSight.pilot_points` gives feet, chest and
  head on foot, and the plane's middle and both wingtips in the air.
  - **Cone:** it starts at his eye (between his eyes on the posed head
    bone) and points along his snout (`head_look`: the head bone's
    head-to-jaw-tip direction as posed). When he turns his head, the cone
    turns with it.
  - **Line of sight:** one ray per point against stone and turf
    (`MASK` = layer 1 | layer 11). A pilot who is half hidden is half seen
    (`seen_share`).
  - **Visibility** = share of points seen × distance falloff × off-centre
    falloff × (`AIR` if airborne, otherwise `GROUND`). Airborne covers the
    plane, the sail, a jump and a fall. There is no light or shade term.
  - **Awareness 0..1:** when visibility is over `NOTICE`, it fills at
    `FILL` × visibility per second. When he can't see you, it waits `GRACE`
    seconds, then drains at `DRAIN` per second. The states are unaware,
    suspicious and spotted, with hysteresis. `state_changed(now, was)`
    fires on every change.
- **Tells** (`scripts/sky_dragon.gd`):
  - Suspicious or spotted: his head and neck track the pilot, using the
    head-look-at-camera code with wider limits (`TRACK_YAW`, `TRACK_PITCH`).
  - His eyes glow brighter (`ALERT_EYE`). The eye halos also show by day
    when he is alert (`ALERT_HALO`). Both ease in and out (`ALERT_EASE`).
  - Spotted: he roars, using the existing jaw roar.
  - `idle_roars` turns off his random roars, so in the greybox a roar
    always means he has seen you. The real game keeps them.
- **Sound** (`scripts/kit_isle/kit_audio_beasts.gd`): going suspicious plays
  a short, higher dragon call (`SUSPECT`, `SUSPECT_PITCH`). Going spotted
  clears the call gap so the roar's own call always plays.
- **Overlay:** `scripts/dragon_sight_overlay.gd`, **J** toggles it. It is on
  by default in the greybox. It draws:
  - the cone (a faint fill, rim rays and a ring at `NEAR`);
  - a line from his eye to each pilot point: green seen, red blocked,
    grey out of the cone;
  - an awareness meter with tick marks at the two thresholds, plus the
    state, visibility and distance. The colour follows the state.
- **Greybox:** `studies/dragon_vision_study.tscn` (it extends the kit isle,
  so the walker, the plane, the sail and the cloud sea work as usual). It is
  in the scene picker under Ruins as "Dragon vision greybox", and launches
  with `run-dragon-vision.command`. The scene has three flat isles at the
  kit datum:
  - **home** (the start): a 26 m long wall at `RuinKit.WALL_HEIGHT`, two
    pillars, an open half and the parked plane;
  - **roof**: a roof on posts whose span and clearance are
    `WorldScale.opening` widths, so the plane can fly under it; and a block
    with a ledge to stand under (underside at `GRAB_TOP`, top at
    `CHAIN_TOP`);
  - **flat**: no cover at all.

  Walkways join home to the other two. The dragon flies a fixed loop
  (`SkyDragon.loop`, `LOOP` in the study) at `DragonWake.HOME_OVER`
  (62 m over the turf, his wake pass over the aqueduct isle).
  `--vision-low` flies it at `LOW_OVER` (28 m). Downwash is on for the
  plane and the sail.

## Tuning constants

- `scripts/dragon_sight.gd`:
  - cone: `RANGE` 320 m, `HALF_ANGLE` 1.1 rad;
  - falloff: `NEAR` 100, `FAR_SEEN` 0.2, `EDGE_SEEN` 0.5;
  - how visible: `GROUND` 0.55, `AIR` 1.0;
  - awareness: `NOTICE` 0.03, `FILL` 0.55, `GRACE` 2 s, `DRAIN` 0.12;
  - thresholds: `SUSPECT_UP`/`SUSPECT_DOWN` 0.3/0.12,
    `SPOT_UP`/`SPOT_DOWN` 0.85/0.5;
  - pilot points: `BODY`.
- `scripts/sky_dragon.gd`: `TRACK_YAW`, `TRACK_PITCH`, `ALERT_EYE`,
  `ALERT_HALO`, `ALERT_EASE`.
- `studies/dragon_vision_study.gd`: `LOOP`, `HIGH_OVER`, `LOW_OVER`, the
  isles and the cover sizes.

## Run

```
./run-dragon-vision.command            # or --vision-low, --fly
~/Applications/Godot.app/Contents/MacOS/Godot --path . res://studies/dragon_vision_study.tscn -- --no-title [--vision-low] [--vision-log]
```

- **J**: sight overlay.
- **V**: dragon camera.
- **Space** by the plane: board it.
- `--vision-log`: prints the sight once a second.
- `--no-sight-overlay`: starts with the overlay hidden.

## Tested vs judged by eye

- **Tested headless** (`tests/test_dragon_sight.gd`):
  - seen in the open inside the cone, and more visible in the air;
  - less visible farther off;
  - not seen outside the cone or past range;
  - a wall in between hides him, and a low wall leaves a third seen;
  - awareness fills to suspicious, then spotted, holds through the grace,
    drains back down, signals each change, and the hysteresis holds.
- **Headless game run** (`--vision-log`): a pilot standing at the start
  goes suspicious at about 140 m and spotted at about 75 m on the first
  pass. Out of sight it drains back to unaware, and later passes spot him
  again. No script errors.
- **Windowed captures**: the cone, the green sightline, his head turned
  down to the pilot, glowing eyes and the meter all show. This was at the
  high loop (spotted) and the low loop (suspicious).
- **Not verified**:
  - hiding behind cover in play: no capture shows the blocked red lines;
    cover only works on the side away from him;
  - how the head tracking looks over a full pass;
  - the call and roar sound;
  - the plane's wingtip points and the sail in play;
  - the feel of every number. Nobody has played it yet.

## Open questions / next steps

- **The gust ring on spotted:** the attack from range. Cover should block
  it the way it blocks sight.
- **The real scenes:** the aqueduct isle doesn't set `sight_target` for the
  roost or the sky dragon yet. It's one line each
  (`DragonSight.pilot_points` from `motor`/`plane`).
- With no hearing and a cone that turns with his head, he never sees
  straight down. Is that blind spot under him right, or should a pass
  overhead be the riskiest place?
- Should light and shade count (under the roof reads darker)? Right now
  only rays block.
- Is the 320 m range too long against a 62 m circuit height?
- Should the plane's size make it more visible than the walker?
