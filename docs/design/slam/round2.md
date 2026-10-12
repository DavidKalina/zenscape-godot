# The slam, round 2

Round 1 was the downdraft (docs/design/downdraft/round1.md): crouch + Q in
the air spent the flow charge on a burst of wind that drove him down. The
user's feedback on it: "Pretty fun, but can we make it so that I feel like
it's more natural if it's not wind-based, it's more like a momentum or
potential energy-based. So if you updraft, you have a bunch of potential
energy, and then being able to initiate the slam from an updraft instead of
charging up the slam itself."

So the move is now **the slam**, and its power comes from height. The
updraft spends the charge and lifts him. At the top, or anywhere in the
air, he can choose to slam and turn that height into impact. The charge is
the updraft's alone.

Branch `feature/slam` (from `feature/downdraft`). Code: `scripts/slam.gd`
(was `scripts/downdraft.gd`). Test: `tests/test_slam.gd` (was
`tests/test_downdraft.gd`).

## Input

| | Keys | Pad |
|---|---|---|
| Slam | Shift or C, pressed fresh in the air, with `LOW` (1.8 m, by his size) or more of air under him | LT, the same |
| Updraft (unchanged) | Q, crouch held or not | RB |

- **Only a fresh press slams.** Crouch held from the ground (the long jump,
  the slide) carries into the air as before and never slams.
- **A press lower than `LOW` keeps its old meaning:** the slide on landing.
  "Air under him" is measured to the ground under his feet (the motor's
  `ground_y`) or, over a pool, to the water's top.
- **The slam is not available** under the sail (crouch brakes it there), on
  a ledge or a rope, in the water, or while knocked or held.
- **Out of an updraft:** the updraft clears 1.8 m within about 0.1 s, so a
  press anywhere in the rise or at the top slams. Updraft then slam in one
  airtime is the combo.
- **Q in the air with crouch held** is now simply the updraft.
- **It spends nothing and locks nothing.** The updraft's charge rules are
  untouched, except that the slam no longer spends it or locks it
  (`spend_down`, `downdrafts` and `updraft.downdraft` are gone).
- **No infinite height loop.** The sequence updraft, slam, land, updraft
  needs the charge rebuilt from flow each time: `MIN_RELEASE` 0.15 at
  least, about a second of sliding. The slam adds no charge and no flat
  pace, and an updraft never lifts him higher than its charge allows from
  where he is. So it is one big hit per updraft. The charge rules already
  prevent the loop, and no new rule was needed.
- **Twirls and other moves:** a twirl during the drive ends it with no hit,
  as before. A slam during a twirl or a wall slide is allowed.
- **Landing out of it:** crouch still held at the touch gives the slide at
  his pace. Jump pressed just before the touch is buffered and jumps out.

## The energy

The hit is measured as a drop in metres:

```
drop  = (y at the press - y at the touch) + v_down² / (2 · gravity · fall)
power = clamp((drop / size - DROP.x) / (DROP.y - DROP.x), 0, 1)
```

- `v_down` is his downward speed at the press. The fraction is the height
  that speed is worth at his falling gravity (26 × 1.5 = 39 m/s²), so
  terminal speed (18 m/s) adds about 4.2 m.
- The drop is measured at the touch, from press to touch. A slam off a
  ledge's edge into a valley counts the whole fall.
- The drive's pace is set at the press, from the drop ahead: the air
  under him plus the speed's worth, with the same mapping.
- The drop is taken against his size, so a smaller wanderer needs a
  smaller fall for the same hit.

Everything else goes by `power`, linearly between the weakest hit and the
full one:

| What | Weakest → full |
|---|---|
| `DROP` | 1.8 → 11 m |
| Ring radius `RADIUS` | 2.4 → 8.5 m (× size) |
| Push strength `STRENGTH` | 0.25 → 1.0 |
| Drive pace `SLAM_PACE` | 20 → 34 m/s down (the fall's top speed is 18). Kicked to `SLAM_KICK` 0.75 of it at once, then pulled on by the motor's `SLAM_PULL` |
| View on the way down `FOV_DRIVE` | 2° → 8° wider |
| View punched in on the touch `FOV_PUNCH` | 0 → 5° narrower, easing back over about 0.3 s |
| Camera drop `KICK` | 0.08 → 0.5 m, over `KICK_TIME` 0.3 → 0.55 s |
| Shake `SHAKE` | 0.012 → 0.12 m, dying over 0.2 → 0.6 s |
| Pad | weak motor 0.15 → 0.55, strong motor 0.25 → 1.0, 0.1 → 0.28 s |
| Clods `CLODS` | 4 → 18, thrown 1.5 → 6.5 m/s out and 2 → 7.5 m/s up |
| Scuff `SCUFF` | 0.45 → 1.4 m round |
| Cracks `CRACKS` | none under power 0.15 (`CRACK_FROM`), then 1 → 8, each 0.6 → 2.8 m long |
| Dust (`character_study.gd` `SLAM_DUST`) | 5 → 12 puff bursts, thrown 1.5 → 5.5 m/s |
| Thump (`kit_audio.gd` `SLAM_THUMP`, `SLAM_PITCH`) | gain 0.35 → 0.85, pitch 0.8 → 0.42 |
| Deep impact (`SLAM_IMPACT`, the `dragon-slam` take) | silent under power 0.2, then up to gain 0.55, pitch 1.3 → 0.9 |
| Turf and grit (`SLAM_DEBRIS`, the `rock-debris` take) | gain 0.07 → 0.22, pitch 1.5 → 1.1 |

**A decent hit.** `Slam.decent()` is the strength of a `DECENT` 4 m drop,
which comes to 0.43. Below it:
- a buried find stays shut (`buried_find.gd`);
- the jammed cowl stays put (`plane_arc.gd`, replacing `COWL_NEED` 0.3).

The bells swing in proportion to the strength from any slam. A small slam
on the belfry floor swings the bell about as much as two landings do. A
big one swings it hard.

Measured headless (`tests/test_slam.gd`):

| Slam from | Drop | Strength | Ring |
|---|---|---|---|
| 2.4 m (a hop off a step) | 2.4 m | 0.30 | 2.8 m |
| 5 m | 5.0 m | 0.51 | 4.5 m |
| 9 m | 9.0 m | 0.84 | 7.2 m |
| The top of a full updraft from flat turf | 7.0 m | 0.67 | |

More measurements:
- From 9 m the drive reaches 31 m/s.
- During the catch he falls at no more than 0.65 m/s.
- With 5 m/s of flat pace he lands still at 4.7 m/s and slides out at
  4.6 m/s.
- On the belfry floor, the bell swings at 0.28 rad/s from a 2.2 m slam
  and 0.69 rad/s from a 6 m one.

Press to touch is worked out from the numbers, not measured: about 0.2 s
from 2.4 m and about 0.3 s from 7 m.

## Motion

- **The catch (`HANG`).** It lasts 0.05 s, three frames, against round 1's
  0.11 s gather. His fall is stopped and his flat pace is held to
  `HANG_FLAT` 0.6. It is a beat at the top, not a wind-up.
- **The drive.** He is driven straight down (the motor's `slam`, which is
  unchanged). His flat pace is kept at `SLAM_KEEP` 0.94, and he isn't
  steered.

## Look: impact, not wind

These are dropped: round 1's gather spirals, its slam wind streaks, its
radial ring ribs, the gather swirl puff, the gather whoosh and the
`wind-slam` take.

What it has now:
- **On the way down,** a pale smear behind him along his fall, facing the
  camera. It shows `SMEAR_TAIL` 0.1 s of his path, up to `SMEAR_MOST`
  3.2 m. It is thick at his body and gone at its tail, with four thin speed
  lines beside it. It is flat unshaded colour, not the breeze brush.
- **The shockwave ring.** Six arcs of a circle run out flat to the radius
  in 0.16 → 0.3 s, then fade over 0.3 s. They ride `RING_HIGH` 0.16 m over
  the ground (sampled from the ground under each point) in the breeze
  ribbons' brush. They read as air pushed out along the turf rather than
  spokes of wind. The flattened-grass ring (`pilot_wake.gd`) is unchanged
  and goes with it.
- **Clods of turf** (three earth and turf colours) fly out. They come to
  rest on the ground where they fall and shrink away over 1.2 s.
- **A scuff with cracks.** A dark earth patch, darkest at its middle, is
  left where he hit, with jagged cracks running out of it on bigger hits.
  It stays `SCUFF_HOLD` 5 s, then fades over 2 s. Only the last one is
  kept.
- **Dust, the camera and the pad** as in the table above.
- **Sound.** A swish as the drive starts (his body through the air). On
  the touch, the thump, deeper and louder from higher. Under it, from a
  real height, the deep "dragon strike through the rock" impact, with turf
  and grit over it. Wood creaks under it. All of it is in
  `scripts/kit_isle/kit_audio.gd`. The takes are loaded at runtime in the
  clip table, never as a const preload.

## The push hook (renamed)

The hook works as in round 1, renamed throughout:
- The group is `Slam.GROUP` (`&"slam"`).
- Receivers have `slam(at: Vector3, radius: float, strength: float)`.
- The helpers are `Slam.blast`, `Slam.share`, `Slam.way` and
  `Slam.knock_way`.

What answers it is unchanged: the floating slabs (`SLAM_SINK`, `SLAM_TIP`,
`SLAM_SHOVE`, counted in `slammed`), the swing ropes, the bells, the loose
leaves (`SLAM_THROW`, `SLAM_LIFT`), the grass ring, buried finds and the
cowl. The bell's ear is now `BellEar` (it was `BellWind`) and its swing is
`BELL_SLAM`.

## Hosting

`studies/character_study.gd` makes the slam whether or not there is an
updraft. `--no-slam` leaves it out (it was `--no-downdraft`).

Each frame:
- `slam.update(delta, motor, ground.ground_callable())` runs after the
  updraft and before the motor, with `motor.crouch` already set. It reads
  the press edge itself.
- `events.merge(slam.after(events, motor))` runs right after the motor.
- `slam.apply_feel(camera)` runs after the updraft's.

The step's events:
- `slam_start`: the power of the drop ahead.
- `slam_drive`: the pace.
- `slam`: `{at, radius, strength, power, drop, hit}`.

## Renamed, at a glance

- `scripts/downdraft.gd` → `scripts/slam.gd`, and
  `tests/test_downdraft.gd` → `tests/test_slam.gd` (with their `.uid`s).
- The group `&"downdraft"` → `&"slam"`, and the method `downdraft(...)` →
  `slam(...)` in `buried_find.gd`, `foot_slab.gd`, `swing_rope.gd`,
  `motif_bell_spires.gd`, `pilot_wake.gd`, `wind_leaf_litter.gd` and
  `plane_arc.gd`.
- The hints:
  - `kit_isle.gd` `FOOT_HINT`: "Shift or C (LT) high in the air: the slam";
  - the character study's key line;
  - `docs/gamepad.md` (LT and RB rows);
  - `docs/design/updraft.md`;
  - the buried rune's "move" text.
- `test_aqueduct_isle_life.gd` takes the buried rune with a real slam: a
  fresh crouch press 6 m up, with no charge set.

## Checks

- Headless import: exit 0, no errors.
- Load checks, `res://studies/zenscape.tscn --quit-after 300`, both exit 0
  with no errors or warnings:
  - `-- --no-title`;
  - `-- --no-title --plane-fixed`.
- `--script res://tests/test_export_entry.gd -- --native-kernels`: exit 0,
  "PASS: packaged walk, plane and teardown".
- `python3 tools/run_tests.py --tests ...`: these all pass:
  - `test_slam.gd`, `test_plane_arc.gd`, `test_ledger.gd`,
    `test_telescope.gd`, `test_pilot_motor.gd`,
    `test_foot_interactables.gd`, `test_aqueduct_isle_life.gd`;
  - also `test_world_scale_guard.gd` and `test_pilot_wake.gd`;
  - `test_bell_spires_isle.gd` passes with the known quit-leak engine
    error.
- **`test_character_recordings.gd`** fails on the "Tech. Fun, fluid,
  movement" recording, as it does on `main`, but now earlier: at 28.09 s
  instead of 28.82 s. The recording presses crouch fresh mid-twirl 2.7 m
  over the ground at 28.07 s. Under the new input that press is a slam, so
  the replay diverges there. This follows from the rule asked for. It
  isn't added to `known_failures.txt`. Re-recording it, or accepting it, is
  the user's call.
- An earlier version of this round also slammed in that recording at
  21.19 s, over a pool, measuring the air down to the pool's bed. The air
  is now measured to the water's top, and that press no longer slams.
- The full suite was not run.

`tests/test_slam.gd` covers:
- **Input:**
  - a fresh press 5 m up slams, no charge is spent and nothing is locked;
  - Q with crouch held in the air is the updraft;
  - a press 1.1 m up doesn't slam, and he slides on landing;
  - crouch held from a long jump, lifted 4 m, never slams;
  - updraft then slam in one airtime: the updraft spends the charge, the
    slam near its top is a 7 m drop over a decent hit, and nothing is
    locked.
- **The drive:**
  - the catch;
  - the drive past the fall's pace;
  - his flat pace kept;
  - the slide out with crouch held;
  - the jump out with Jump buffered.
- **The energy:**
  - slams from 2.4, 5 and 9 m: strength and radius rise with height;
  - the drop is measured press to touch;
  - 2.4 m is under a decent hit and 5 m is over it.
- **The push:**
  - a bobbing slab sags and is shoved;
  - on the belfry floor a 2.2 m slam leaves the cowl jammed, and a 6 m
    one swings the bell harder and knocks the cowl down, where it's taken
    and stamped.
- **The buried rune:**
  - walking over it, a big slam 5.4 m off, and a 2.4 m hop's slam right
    over it all leave it buried;
  - a slam from 6 m over it breaks it open;
  - it rises, glints, and is taken and stamped.

## What's weak

- **Nothing was seen or heard rendered.** These are all unverified:
  - the smear and its speed lines;
  - the shockwave ring;
  - the grass ring;
  - the clods, the scuff and the cracks (do they z-fight or hide in the
    grass?);
  - the dust, the camera punch, kick and shake, the FOV moves and the pad;
  - the new sound mix (does the dragon-strike take read as his body, or
    as too big?).

  The numbers are first guesses tuned by reasoning and headless
  measurement. They are the first things to play.
- **No pose.** He falls in his usual air pose. A tuck, or a knee-first
  drop, would sell the weight more than any effect.
- **No hit-stop.** A couple of frames' freeze on a big hit is the classic
  sell. It wasn't added because the motor and the replays step on fixed
  ticks.
- **The scuff sits on the ground, not in it.** It is unshaded, lifted
  2–3 cm and laid over the ground's heights at its points. On stone it
  reads as a dark stain, and the clods are always turf-coloured even on
  stone (the host only knows "stone" or "water").
- **The ring follows the ground at its points only.** Over a sharp edge
  it stays at his level (anything more than 1 m off is ignored).
- **A fresh crouch press in the air can surprise.** Pressing crouch
  mid-air to get ready for a landing slide now slams if you're 1.8 m or
  more up. The recording above did exactly that. If it bites in play, add
  a falling-only rule, or a short hold, at the cost of the updraft-rise
  combo.
- **The drive pace is set from the ground straight under him at the
  press.** Driven off an edge, he hits harder than the pace suggests; the
  measured drop is right.
- **The bells swing from any slam.** Only the cowl needs a decent hit.
- **Carried over from round 1:**
  - the ring pushes everything at once and ignores walls;
  - the grass ring hides his wake for about 1.5 s;
  - the cowl's fall is timed and not saved.

## Next

- A slam pose, and a hit-stop if the fixed tick allows it.
- A surface-aware scuff and clods: stone chips on stone, a splash on water.
- Things only a big hit breaks: cracked slabs, sagging lintels, a floor
  that gives way into a crypt.
- Enemies answering `slam` with `knock_way`.
