# Updraft

Build flow, press Q, launch straight up. Extracted from `study/wind-store`
(`scripts/wind_store.gd`, `docs/design/wind-store.md`), which also had an aimed
gust, rolling sentinels, blocks and yards; none of those are here. No enemies.

## Input
**Q** (pad **RB**), input action `walk_wind` in `scripts/pad.gd`. A plain press,
no crouch. Q and RB were free on foot (they are used only in the plane, the
builder and the photo lens). Fires whenever charge is at least `MIN_RELEASE`:
standing, out of or during a slide, and in mid-air (jump, long jump, wall jump,
rope release, fall). The pocket sail still opens after it.

## Charge (`scripts/updraft.gd`)
Flow only, never a button. Per second: `PACE_GAIN` 0.05 per m/s over `FLOW_PACE`
(6), `MOVE_GAIN` 0.12 in slide / long / wallrun / kick / flip / twirl, on a rope,
or in the jump chain, `AIR_GAIN` 0.10 airborne above pace; starting a notable
move adds `MOVE_BUMP` 0.06. After `GRACE` 0.9 s with no gain it drains at
`DECAY` 0.4/s. No gain while the pocket sail is open. Shown as streaks orbiting
the wanderer (more and gold with charge) and a pulsing ring at full.

## Release
Spends all the charge. `toss` straight up, flat velocity kept (the motor does
not bleed it in the air: 12.6 m/s stays 12.6 over the next 0.5 s), a fall
cancelled, twirl / wall run / sail ready again. Rise from standing
`lerp(UP_RISE_MIN 1, UP_RISE_MAX 7, charge)` m. Ring blast at the feet
(`RING_*`), camera dip and rise (`DIP`), dust. The ring calls `wind_push` on
group `wind_pushable` (only the swing ropes, which swing `WIND_SWING` 9 m/s).

## Hosting
`studies/character_study.gd` creates it unless `--no-updraft` is passed, so every
kit isle and the aqueduct isle have it. Launcher: `./run-updraft.command`.
Probe: `tools/probe_updraft.gd`.

## Consts
All at the top of `scripts/updraft.gd`, plus `UNIT` (scale for a 0.83 wanderer).

## Rough
- Not flown by a human; rise numbers checked headless only.
- Ring ignores walls; no sound; no figure tuck; the look is greybox streaks.
- Charge rates carried over from the branch untouched.
