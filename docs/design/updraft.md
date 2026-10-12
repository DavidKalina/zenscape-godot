# Updraft

Build flow, press Q, launch straight up. Extracted from `study/wind-store`
(`scripts/wind_store.gd`, `docs/design/wind-store.md`), which also had an aimed
gust, rolling sentinels, blocks and yards; none of those are here. No enemies.

## Input
**Q** (pad **RB**), input action `walk_wind` in `scripts/pad.gd`. A plain press,
crouch or not. Q and RB were free on foot (they are used only in the plane,
the builder and the photo lens). The charge is the updraft's alone; its pair
is the slam (`scripts/slam.gd`, docs/design/slam/round2.md), a fresh crouch
press up in the air that cashes the height in and spends nothing. Fires whenever charge is at least `MIN_RELEASE`:
standing, out of or during a slide, and in mid-air (jump, long jump, wall jump,
rope release, fall). The pocket sail still opens after it.

## Charge (`scripts/updraft.gd`)
Flow only, never a button. Per second: `PACE_GAIN` 0.05 per m/s over `FLOW_PACE`
(6), `MOVE_GAIN` 0.12 in slide / long / wallrun / kick / flip / twirl, on a rope,
or in the jump chain, `AIR_GAIN` 0.10 airborne above pace; starting a notable
move adds `MOVE_BUMP` 0.06. After `GRACE` 0.9 s with no gain it drains at
`DECAY` 0.4/s. No gain while the pocket sail is open. Shown as a wake of wind
behind him: up to `WAKE_STRANDS` soft strokes in the breeze ribbons' brush
(`shaders/breeze_ribbon.gdshader`, as the dragon's breath) trailing his path,
opening and rising toward the tail, joining and brightening as it builds. No
orbit, no colour change, no pulse. Standing still the wake shrinks to nothing.

## Release
Spends all the charge. `toss` straight up, flat velocity kept (the motor does
not bleed it in the air: 12.6 m/s stays 12.6 over the next 0.5 s), a fall
cancelled, twirl / wall run / sail ready again. Rise from standing
`lerp(UP_RISE_MIN 1, UP_RISE_MAX 7, charge)` m. Ring blast at the feet
(`RING_*`, drawn as `RING_RIBBONS` strokes curling out from his feet), the
wake comes away and fades, camera dip and rise (`DIP`). The ring calls `wind_push` on
group `wind_pushable` (only the swing ropes, which swing `WIND_SWING` 9 m/s).

## Directional burst
Q picks its direction from the stick (`updraft.burst`, tried before `updraft`).
Stick at least `BURST_STICK` and within `BURST_CONE` (50 deg) of his flat travel
(any way if under `BURST_SLOW`) is a forward burst: all the charge becomes
`+BURST_ADD_MIN..MAX` (5..12) m/s along stick + travel, scaled down from
`BURST_SOFT` (14) to `BURST_CAP` (28 m/s, floor `BURST_FLOOR`), with a
`BURST_COOLDOWN` 0.6 s (a forward press inside it does nothing). Grounded he
stays down and keeps sliding or running; for `BURST_RIDE` s the motor's
`slide_top` is raised to `BURST_SLIDE_TOP` and `slide_air` cut to
`BURST_AIR_DRAG`, set from the updraft, so the motor is untouched. Look: wind
the wake comes away, flares and drifts back along the burst, FOV kick
`BURST_FOV`. Only a slide takes
it: mid-air Q is always the updraft (`BURST_AIR_ON` false; true brings back
the air burst, `BURST_AIR_SHARE` of the add with no lift). Neutral
stick or stick back is the updraft, everywhere; out of a fast slide
(`UP_SLIDE_PACE`) the rise is scaled `UP_SLIDE_SCALE` and the pace is kept.
No chaining: after a burst `spent` locks all charging until the ride is over,
the slide has ended and his pace is back to what it was before the burst
(`SPENT_LEAST` 1.2 s at least, `SPENT_MOST` 5 s at most), so the burst's own
pace never refills it. Probe numbers (flat m/s at
0 / 0.25 / 0.5 / 1 s, real flat slide from 11.5): burst in slide 21.2 / 19.1 /
15.8 (no burst 9.9 / 8.6 / 6.4); two bursts 0.67 s apart, 22.9 at 1 s;
updraft out of a slide rose 9.4 m at 11.5 m/s kept.

## Hosting
`studies/character_study.gd` creates it unless `--no-updraft` is passed, so every
kit isle and the aqueduct isle have it. Launcher: `./run-updraft.command`.
Probe: `tools/probe_updraft.gd`.

## Consts
All at the top of `scripts/updraft.gd`, plus `UNIT` (scale for a 0.83 wanderer).

## Rough
- Not flown by a human; rise numbers checked headless only.
- Ring ignores walls; no sound; no figure tuck.
- Charge rates carried over from the branch untouched.
