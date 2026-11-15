# Hot air balloons: the lantern glow at night (prototype round, 2026-11-14)

Follows `handoff-balloons-field.md`. Branch `claude/hot-air-balloon-pricing-1ab577`.

## Try it

```
.\run-endless-flight.cmd --balloon-field-now --hour=0      # a field in the blue hour (the game's night)
.\run-endless-flight.cmd --balloon-field-now --hour=18     # sunset: the glow most of the way in
.\run-endless-flight.cmd --balloon-field-now --hour=18.6   # dusk
.\run-endless-flight.cmd --balloons-now --hour=0           # three low ones near the start
.\run-endless-flight.cmd --balloon-field-now --hour=0 --balloon-glow=0    # A/B: the old night look
.\run-endless-flight.cmd --balloon-field-now --hour=0 --balloon-lamps=0   # A/B: no real lights
.\run-endless-flight.cmd --balloon-field-now --hour=0 --night=1           # the full night under the horizon
```

With no `--hour` the day runs on its 20 minute clock; `T` sweeps to the next
stop (dusk, blue hour). On seed 1 the field is off the start's heading: look
around for it.

## What was built

`shaders/balloon_canvas.gdshader`, `shaders/balloon_gear.gdshader`,
`scripts/endless/endless_balloons.gd`. No model change, nothing shared touched
(the environment's bloom is as it was).

- **Darkness** comes from the celestial's `daylight` (the global
  `zs_daylight` in the shaders, `look.celestial.daylight` in the script):
  none above 0.62 (about 17.3 h and 6.7 h), all below 0.04 (about 18.05 h).
  No hours are written in. By day the lantern term is skipped.
- **The cloth** (near and far model, one shader): in the dark the burner's
  light comes through as emission. Strongest low by the mouth, thinning to
  the crown; deep red far from the flame, orange nearer, paler over the
  flame while it fires. The colour is the dye's (the pattern before
  sun-fade and dirt); dark dyes pass little. Tapes, panel seams, patches,
  stains, soot and the scoop are darker in it; each panel has its own
  weight. The inside of the envelope is lifted too.
- **Burn and ember**: a new instance uniform `glow` follows the burn, eased
  in the script every frame for every live balloon (up in 0.2 s, back over
  1.3 s), with the burn's flicker while it fires. Between burns an ember
  (0.3 of the burn, breathing slowly) stays on low down.
- **Far off**: where a balloon is a few pixels the gradient is evened and
  the light lifted (3x, the ember 2.4x over that), and the tapes stop
  striping it, so a field reads as lit dots at 1 km and more.
- **The gondola**: the flame's light on basket, ropes and frame is lifted
  2.5x in the dark, and a little stays between burns.
- **Two real lights** (`OmniLight3D`, no shadows): on the two balloons
  nearest the eye within 420 m, at the mouth, onto the land, grass, trees
  and the plane. Each fades toward 420 m and as the third nearest draws
  level, so a light is dark when it changes balloons. The cloth ignores
  them (its `light()` takes only the sun); the gondola takes them.

## Knobs

| Where | Name | Now | |
|---|---|---|---|
| canvas | `lantern` | 1.9 | the light through the cloth at a full burn |
| canvas | `ember` | 0.3 | share of it between burns |
| canvas | `lantern_crown`, `lantern_fall` | 0.12, 2.3 | what reaches the crown, how fast it thins going up |
| canvas | `lantern_far`, `ember_far` | 3.0, 2.4 | the lift far off |
| canvas | `lantern_inside` | 0.4 | the inside's lift over the day's glow |
| canvas | `lantern_deep`, `lantern_hot`, `flame_colour` | | far from the flame, over it, between |
| canvas, gear | `dark_from` | (0.62, 0.04) | set from the script's `DARK_FROM` |
| gear | `lantern`, `ember` | 1.5, 0.07 | the gondola's lift in the dark, its share between burns |
| script | `GLOW_UP`, `GLOW_BACK` | 5 /s, 1.3 s | the cloth's glow after the burn |
| script | `LAMPS`, `LAMP_NEAR`, `LAMP_REACH`, `LAMP_ENERGY`, `LAMP_FALL`, `LAMP_EMBER`, `LAMP_COLOUR` | 2, 420 m, 40 m x scale, 3.2, 0.55, 0.12 | the real lights |

Flags: `--balloon-glow=X` (the lantern's strength, 0 none), `--balloon-lamps=N`
(the real lights, 0 none).

## Cost

`scratch/glow_bench.gd`, rendered 1440x900, hour 0, 20 balloons 90 to 1300 m
ahead of a held eye, half burning, 400 frames a config, the list twice a run,
the run twice. GPU ms (median), four readings each:

| | GPU ms |
|---|---|
| glow off | 7.21, 7.34, 7.21, 7.34 |
| glow on, no real lights | 7.14, 7.39, 7.15, 7.41 |
| glow on, two lights | 7.31, 7.52, 7.36, 7.53 |

The shader term is within the noise. The two lights cost 0.10 to 0.19 ms.
Render-thread CPU 0.87 to 0.92 ms in every config. The script's running
mean moved between 0.08 and 0.15 ms across configs without a pattern; the
added work is one eased uniform on two meshes per balloon while its glow
changes, and one pass over the pool for the lights.

Not measured: a weaker GPU, the Mac, a view with the lit ground filling the
screen.

## Proof

- `python tools/smoke.py studies/endless_flight.tscn -- --balloon-field-now`,
  `-- --balloon-field-now --hour=0`, and
  `-- --balloons-now --hour=18.6 --balloon-glow=0 --balloon-lamps=0`: PASS, 0 errors.
- Noon: `noon_near_after.png` is pixel for pixel `noon_near_before.png`
  (last round's still). `noon_skim_*` differ in 1.5 % of pixels, all in one
  patch of land near the camera (a land chunk), none on a balloon.
- Stills in `scratch/shots/` (git-ignored), made with `scratch/glow_shots.gd`
  (a bench fan, every third burning) and `scratch/balloon_shots.gd` (a real
  `--balloon-field-now` field):
  - Night, before and after, hour 0: `glow_{field,far,beside,under,basket,ember}_before_h0.png`
    and `..._after_h0.png`; `glow_ground_after_h0.png` (two on the grass).
    `field` is 90 to 1300 m, `far` 600 to 1800 m, `ember` none burning.
  - A real field at night: `field_{skim,takeoff,wide,near}_night.png`.
  - Dusk: `glow_{field,beside,ember}_dusk_h18.png` (hour 18.0),
    `field_{skim,wide}_dusk.png` (18.6).
  - Noon: `noon_{near,skim}_{before,after}.png`.

## Not verified, known gaps

- Nobody has flown it by hand; the swell and ease-back were judged from
  stills, not watched moving.
- The blue hour is bright in this game, so the glow sits against a lit land.
  `--night=1` (full night) was not captured.
- A balloon past 320 m steps its burner by turns (about every 7 frames in a
  field of 20), so a far burn starts up to 0.1 s late; the glow itself is
  eased every frame.
- At hour 17.5 the glow is a fifth in while the sun is still on the cloth.
- The real lights tint green grass yellow under a low balloon; with
  `--balloon-lamps=0` only the balloons themselves glow.
- No halo was added: the environment's bloom (threshold 1.8, intensity
  0.12) gives only a little round a burning balloon.

## Existing tests

None run (prototype round). The manager adds two `OmniLight3D` children
(`BalloonLamp0/1`): a test that counts lights or the study's nodes would see
them.

## Harness

No tool was missing. A headless `tools/drive.py` run piped through
`grep | head` held the pipe until the 270 s timeout once; without `head` it
returns at once.
