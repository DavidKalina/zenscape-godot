# Dragon grip, round 1: the isle grip at 1.5

Branch `feature/dragon-grip-1.5`, made from `look/dragon-roost-2`. That branch made the dragon 1.5 (`SkyDragon.SIZE`), flying and asleep alike. The cling geometry already scaled with size, so at 1.5 the chin lands about 22 m in from the lip rather than 13 m. The grip's planning, though, still sampled the isle at its 0.85-era distances. This round fixes the grip and the choice of target. It doesn't touch the roost (`scripts/dragon_roost.gd`, `scripts/kit_isle/motif_dragon_roost.gd`), the gale or the breath.

## The room rule

The dragon attacks only isles with room for its grip, and never the aqueduct isle.

- **The aqueduct isle is never a target.** It is the starter isle, and the player shouldn't have to mind the dragon there. The host (`studies/aqueduct_isle.gd` `_build_sky_dragon`) lists only the motif isles, and `_attackable` in `scripts/sky_dragon.gd` turns away anything listed within 60 m of the aqueduct isle's middle, plus `dragon_roost`. Both places say so in comments.
- **Room** (`_has_room`): an isle needs at least one way round it, among `_best_turn`'s 48, that meets all three conditions below. Each way is checked on the isle's sampled shape once it stands, and the answer is kept on the target.
  - **The rim is at least `ROOM` out from the isle's middle.** `ROOM` is 20 m at `TUNED_SIZE` and scales by k = size/0.85, so it is 35 m at 1.5. The chin lies 13·k m in from the lip, so a rim this far out puts the chin short of the middle, with the isle running on past it.
  - **Both wrists find a lip of their own.** Neither may be `_rim_line`'s fallback, which puts a claw in open air.
  - **The chin's band is open.** At least `ROOM_OPEN` (75%) of it is open turf, with at most `ROOM_TALL` (2) samples standing tall.
- **Before an isle stands**, the listed radius is checked against `ROOM`·k instead. If an isle is picked that way and turns out to have no room once it stands, the dragon turns away (`_turned_away`) and circles round instead.
- **Ways without room** lose `NO_ROOM` (100) in `_best_turn`. So a forced `--dragon-target` still grips such an isle, on its least bad way.
- **With no isle that has room**, `_add_attack` flies a circuit and tries again later.
- **Tuning:** I tried a rim-only gate first. At 26.5 m (15·k) it let in bell_spires, cloister_tarn and stair_clouds at 1.5, and all three were still poor. The open-turf condition drops them. Raising `ROOM` to 20·k then stopped bell_spires at 0.85 from falling back to a cramped 17.5 m rim among the bells. At 23 m it now grips well there.

## What changed (`scripts/sky_dragon.gd`)

- **`_best_turn` samples scale by k** (`_k()`):
  - the chin's open-turf band (d 3 to 16, sides ±3), its `open_at` radius and its rise band (d ≤ 11)
  - the tall check (d 4 to 13, sides ±6)
  - the under-body check (d 4 to 55, sides ±12)
  - the wrists' 6 m slack, and the rim limits (`r < 10`, `r > 34`)
- **`_rim_line` reports its fallback** in `_rim_fell`. A way where either wrist falls back has no room.
- **Three constants scale by k at their use:** `BODY_MOST` (6 m becomes 10.6 m at 1.5), `NECK_DEEP` and `THUMB_IN`.
- **Unchanged:** the gale and the breath stay in absolute metres, and the sag's slam and pull tip are left alone.
- **Target choice:** `_choose_target`, the ride's pick and `_ride_next` all skip isles without room. `_choose_target` returns -1 when none has room. `--dragon-attack` handles that case.

## Measurement

`tools/measure_dragon_grip.gd` forces the grip on every motif isle, whether targetable or not, and holds it 24 s of the grip's own clock. It samples the rest (chin down) and the blow. Run it after a headless import:

```
godot --headless --path . -s tools/measure_dragon_grip.gd -- --dragon-size=1.5
```

It prints one `V` line per isle. Each run takes about 4 minutes.

In the table, "lift" is the body's most lift (rest / blow). "Deepest" is the deepest any head or neck probe sits under the turf or rock (rest / blow; one frame's worst). "Ruin" is the share of blow frames with the head inside a ruin.

### At 1.5

| isle | before | after |
|---|---|---|
| bell_spires | Targeted. Rim 38.5 m. The left wrist is on the fallback, 10.7 m off land, and its claw was off land every frame. Head over turf 37% at rest, chin front 11 m up. Lift 4.0 / 5.8. Ruin 21%. Deepest -4.2 / -4.8 | **Not targetable.** Best way 38% open, 5 tall |
| cloister_tarn | Targeted. Rim 30 m. Chin on the cloister ruin: head over turf 8% at rest, 8.2 m up. Lift 5.9 / 6.0, at the 6 m cap. Ruin 13% | **Not targetable.** Best way 62% open |
| sundered_gorge | Targeted. Rim 24.5 m. Hands on land. Chin front 8.0 m up, over the gorge. Lift 2.1 / 1.2. Deepest -0.5 / -1.6 | Targeted. Rim 42.5 m. Hands on land. Head over turf 100% / 100%, chin front 0.7 m up. Lift 1.8 / 1.7. Ruin 0%. Deepest -0.1 / -1.6 |
| colonnade_spine | Targeted. Rim 24.5 m. One claw 0.5 m in the turf. Chin 2.3 m up. Lift 0.5 / 5.8. Ruin 5%. Deepest -0.3 / -4.4 | Targeted. Rim 73.5 m. Hands on land, claws within 0.2 m of the turf. Head over turf 100% / 100%, chin 2.1 m up. Lift 0.9 / 2.2. Ruin 0%. Deepest -1.2 / -2.0 |
| broken_ring | Targeted. Rim 12.5 m. A 30 m hand span on a 28 m isle: both wrists on the fallback. Lift 5.6. Ruin 17% | **Not targetable.** Rim 13.5 m |
| drowned_nave | Targeted. Rim 49 m. Good. Chin 1.1 m. Lift 0.7 / 1.1. Deepest -0.2 / -0.9 | Targeted. Rim 54 m. Hands on land. Head over turf 100% / 100%, chin 1.1 m. Lift 0.7 / 1.3. Ruin 0%. Deepest -0.1 / -1.4 |
| stair_clouds | Targeted. Rim 29.5 m. Chin front 33 m up. Head over turf 82% / 54%. Ruin 9%. Deepest -8 / -22 | **Not targetable.** Best way 57% open, 3 tall |
| hollow_keel | Targeted. Rim 40.5 m. Hands on land. Chin 0.9 m. Lift 3.4 / 1.0. Deepest -5.0 / -0.8 | Targeted. Rim 49.5 m. Hands on land. Head over turf 100% / 100%, chin 0.8 m. Lift 1.2 / 1.0. Ruin 0%. Deepest -0.1 / -0.7 |

Every isle he can still target at 1.5 has:

- both planned wrists and both thumb claws on land in every frame
- the head over open turf in every frame, with the chin's front a median 0.7 to 2.1 m over it at rest
- the head never inside a ruin
- a body lift of no more than 2.2 m

### At 0.85

At 0.85, k = 1, so every sample distance is as before.

- **Unchanged:** cloister_tarn, sundered_gorge, colonnade_spine, drowned_nave and hollow_keel pick the same rims and measure the same, within run-to-run noise.
- **bell_spires is better.** Its old way (rim 42 m, among 8 tall samples) had the chin hanging over the bells: head over turf 1% at rest, lift at the 6 m cap. That way now has no room. It grips a 23 m rim instead, with the head over turf 100% at rest and 81% in the blow, chin 0.5 m, lift 0.9 / 1.2, and no ruin.
- **broken_ring is no longer targetable** (rim 12 m < 20 m). Its old grip had the head over a ruin for most of the rest.
- **stair_clouds is unchanged and still broken** (see below).

## Checks

All headless.

- **Import:** clean.
- **Load checks:** `res://studies/zenscape.tscn --quit-after 300` with `-- --no-title`, `-- --no-title --dragon` and `-- --no-title --dragon-roost` all exit 0 with no errors. The roost run sometimes warns about leaked ObjectDB instances at exit. The base branch does the same (17 there).
- **Tests:** `python3 tools/run_tests.py --tests test_kit_audio.gd --tests test_world_scale_guard.gd --tests test_world_scale_fit.gd` passes 3/3. There are no dragon tests; `test_kit_audio` is the only one that builds the sky dragon.
- **Attack runs:** `--dragon --dragon-attack --motifs-now` attacks colonnade_spine. With `--dragon-target=broken_ring` it still grips broken_ring.

## Still weak

- **The hind feet hang in open air:** 5 to 8 m outside the isle's outline at 1.5 (3 to 4 m at 0.85). Their reach is planned on the lip, but the legs don't get there.
- **Wing fingers under the turf in the blow.** The sampler doesn't measure the wings. Its `report()` has a wing and tail check that nothing calls yet.
- **Neck probes graze the turf in the blow.** At 1.5 they sit up to 1.4 to 2.0 m under it in the worst frame, and 0.5 to 1.6 m at the 5th percentile. At 0.85 the figures are 0.4 to 2.8 m. Colonnade_spine's neck also sits 1.2 m into the turf at rest. The blow's dip and the clearance rates (`CLEAR_RATE`, `NECK_RATE`) are in absolute units.
- **The before/after "deepest" figures differ slightly in what they count.** `NECK_DEEP` now scales, so after the change, neck probes 3 to 5.3 m under the lip's overhang no longer count as in the isle.
- **stair_clouds at 0.85 stays broken.** Its neck probes read the floating stair overhead as floor, giving gaps of -20 m, and the body sits at its lift cap. At 1.5 the room rule drops it.
- **Only four isles** (sundered_gorge, colonnade_spine, drowned_nave, hollow_keel) are targets at 1.5. A dragon of 1.7 would need re-measuring, and could lose sundered_gorge.
- **Not checked:** the flight routes, threads and attack clearances at 1.5 (see dragon-roost round 2). Anything visual: the claws on the lip, the head's look on the turf. Headless can't judge those.
