# Rival race (handoff)

Any of the three traffic planes can now be challenged to a race. You fly up behind one, hold a button, and it accepts with a wing waggle and speeds off low and fast through the land's openings: arches, split mountains, and slot halls and tunnels where the world has them. You win by passing it and holding the lead for a moment. This is a prototype round: smoke checks, throwaway drivers and stills. No tests were committed.

## Play it

```
./run-endless-flight.command --race-near-start
python3 tools/play.py -- --race-near-start                     # same, any OS
.\run-endless-flight.cmd --race-near-start                     # Windows
python3 tools/play.py -- --race-near-start --rival-skill=1.5   # a sharper rival
```

`--race-near-start` skips the main menu (as `--split-near-start` does) and puts traffic plane 0 230 m ahead of the start, 18 m to the side, cruising on. It is bracketed straight away. Hold Tab to challenge it. Without the flag, any traffic plane you come up behind can be challenged the same way.

## The flow and the bindings

1. **Offer.** A traffic plane that is within 520 m, within about 26° of where the camera looks, ahead of you and in sight gets a faint bone-white bracket: four corner ticks. The bracket lets go once the plane is out past 650 m or about 37° for 1.5 s.
2. **Challenge.** Hold **Tab** (pad: **R3**) for 0.7 s. While you hold, the ticks close in and brighten, a line under them fills, and the focus pulls onto the plane: the far land past it blurs. Let go early and the hold drains away.
3. **Accept.** The plane waggles its wings and jumps ahead at 1.25 times its race pace until it is 150 m clear. That way every race starts with about the same gap to close.
4. **Race.** A small down-pointing wedge bobs over the rival, with the gap in metres under it. It turns a warm ember colour past 450 m. When the rival is off screen, the wedge sits at the screen's edge and points to it. Once you are ahead, the text reads "ahead" and a short gold line fills over the hold. The last 20 s show a countdown. The far blur stays light.
5. **End.**
   - **Won:** you are 12 m ahead of it along its heading, within 45 m of its line, for 2.5 s. The note says "rival passed · m:ss" in gold.
   - **Lost:** it stays 550 m ahead for 5 s ("the rival got away"), or 120 s run out ("out of time").
   - **Called off ("race off"):** press Tab or R3 again, turn away from it (more than 95° off it for 3 s), get 1400 m from it, or spend 2 s on the ground.

   The note uses the weight note's style and place, and is held 2.8 s. The rival waggles, turns away from you for 3 s, then goes back to ordinary traffic. That plane is not offered again for 20 s.

The new action is `fly_challenge` in `scripts/pad.gd`: Tab, and the pad's R3. R3 was free in endless flight, because `fly_camera`'s first-person view is only used on the isles. `docs/gamepad.md` and the in-game hint line list it.

## What was built

- **`scripts/endless/rival_race.gd`** (new, a Node under the study) handles picking, the hold, the race rules, the pace, the depth of field, and the flags.
- **`scripts/endless/rival_race_hud.gd`** (new) draws the bracket, the race wedge and the result line.
- **`scripts/endless/rival_line.gd`** (new) is the challenged plane's flying.
  - **Choosing an opening.** Every 1.2 s, while it has no route, it looks for the nearest threadable opening. It must be 160 to 1100 m away, within about 54° of the rival's heading, and roughly facing the way the rival is going. The candidates:
    - **Arches** from `LandArches.standing()`. The widest opening is read off the arch's solid columns (`stretches`) at three depths. It must be at least 2.6 wingspans wide and 3 wingspans tall. An arch is skipped from any side where the ground before or after it climbs above the opening's height, because the rival would come into the span from above.
    - **Split mountains** from `field.splits_in(box)` and `SplitSites.point(s, u)`, flown along the centre line 9 m over the floor. Nothing else of `split_sites.gd` is used.
    - **Slot halls** from `field.halls_in`. The height is read off the hall's built pieces every 0.4 s as the rival comes within 450 m, never lowering: above the rubble on the floor, 42% of the way up to the lowest roof.
    - **Tunnels** from `field.tunnels_in`, flown along the bore's path 7 m over its floor.
  - **Flying the route.** The route is a polyline: from where the rival is, to a lead-in 120 m out, through the middle, and 80 m out the far side. The rival follows it by pursuit.
    - On the way in, it keeps 13 m over the land and the trees' crowns, then settles onto the opening's height over the last 260 m.
    - In an opening, it holds the line's height.
    - With no opening in reach, it flies low down the valleys ahead, near its course. In the open it counts the arches' spans as ground, so it goes over them.
  - **Ducking.** At about 2 s short of an opening it can duck instead. It climbs over an arch, or veers round a ridge for 4 s.
  - **Skill knobs** (named constants, scaled by `--rival-skill=X`):
    - `WOBBLE` 3.0 m: a slow swing across its line, kept inside the opening's room and faded out within 220 m of the opening.
    - `LATE` 0.22 s: how late its heading follows the aim.
    - `DUCK` 0.25: the chance it ducks a thread.
    - `CARRY` 0.84: the share of its speed it keeps through an opening. It lifts off from 200 m before the opening until 60 m after.
    - `TURN_BLEED` 0.08: the share of its speed that a full-rate turn costs.
    - `PACE_PER_SKILL` 0.06: how much faster each step of skill flies it.

    Skill X divides `WOBBLE`, `LATE`, `DUCK`, and what it gives up to `CARRY` and `TURN_BLEED`. It multiplies its pace by `1 + 0.06 (X - 1)`.
  - **Never into you.** It is pushed off within 3 wingspans; the shy traffic keeps 55 m. It steers away when its line would pass within 7 wingspans of you in the next 1.5 s.
  - **For checks.** `history` lists each opening threaded, missed or ducked. `clips` counts the frames it spent inside land, an arch, a hall or a tree.
- **The race's pace** (`rival_race.gd`):
  - `PACE` 0.93 times your plane's Boost speed at your pace preset. Override it with `--rival-pace=X`.
  - The skill's pace multiplies that.
  - It eases off by up to `CATCH_UP` 6% while it is more than 150 m ahead, at full ease once it is 300 m further on.
  - It eases off by up to `FLOW_EASE` 7% while your near-miss chain is live. 40% of that applies as soon as there is a chain, the rest scales with its multiplier, and all of it applies while you surge. It is eased over 1 s. This is read only: `near_miss.gd` and the surge are untouched. Flying well is what makes it easier.
- **`scripts/endless/endless_traffic.gd`:**
  - A plane with a `rival` is flown by it instead of `_fly`.
  - It keeps off you by the rival's own, nearer distance, and is not recycled while it races.
  - `place(n, at, heading)` puts plane n ahead of you (`--race-near-start`).
  - The smoke trails fade out within 12 to 70 m of the eye (`TRAIL_NEAR`). Before, a rival's trail followed close filled the view like a wall. This applies to all traffic.
- **`studies/endless_flight.gd`** has 9 small edits: the preload, the var, `race.setup` after the traffic, `place_near_start` after the launch, `race.step` after `traffic.step`, the menu skip for the flag, and the hint text.

## Ported from the old lock-on, and what changed

The old lock-on is `scripts/lock_on/foot_lock.gd` at `a0d5f517`. The spec doc it names was not in that commit.

- **Picking.** Still the nearest target in range and within a view cone, scored by distance plus angle, with a sight test, and it still lets go after 1.5 s out of range or out of sight. For flight, the range is 520 m to pick and 650 m to let go (was 22 and 28 m). The cone is 26° to pick and 37° to let go (was 65°). The sight test is the study's own `_sight` march over the field and solids, not a physics ray.
- **Easing.** The same weight, 0 to 1 with `BLEND` 0.22 s, fades the lens in and out.
- **The marker.**
  - The bracket is new. It is a 2D overlay because a plane 200 to 500 m off is a speck, so a world-space wedge would vanish.
  - The down wedge (bone white, bobbing, and an ember colour when far) is kept for the race marker, drawn in 2D over the rival. It does not spin and does not pop in with an overshoot.
  - All marks are sized for a 900 px tall window and grow on taller ones. The captures came from a 3024 by 1898 retina window, where the existing HUD text is half-size; the race marks stay readable.
- **The depth of field.**
  - It still takes its own `CameraAttributesPractical` and hands back what the camera had.
  - It no longer takes the lens while the main menu's stage holds it.
  - The near blur is off, because the land close by is what you are threading.
  - The far blur is `DOF_AIM` 0.06 while holding, starting 40 m plus 30% of the distance past the rival. It lingers 1.2 s after the accept, then eases to `DOF_RACE` 0.016, starting 250 m plus 100% of the distance past the rival. With the rival at 200 m, nothing nearer than 650 m is touched.
  - Photo mode is not in endless flight; it went with the cut. The pace's FOV changes only write `camera.fov`, so they don't interact with the blur.

## Proof

- **Smoke checks** (`tools/smoke.py`) pass three ways, each with 0 errors: the default, with `--race-near-start`, and with `--race-near-start --world=regions`.
- **Throwaway driver** `scratch/race.gd` (uncommitted) flies the real loop. It holds `fly_boost`, holds `fly_challenge` on the bracket, and steers with the stick. `--pilot=tight` follows the rival's own line low and spends the surge. `--pilot=safe` chases it about 90 m up, holding Boost, with no surge. It logs the gap every second, the rival's route, and each opening threaded or ducked. Run it with:

  ```
  python3 tools/drive.py scratch/race.gd -- --pilot=tight --scene-args --seed=4
  python3 tools/sweep.py scratch/race.gd --seed 1..6 --arg pilot=tight,safe -j 6 -- --quiet
  ```

  - **Default (medium, brisk), seeds 1 to 6.** Tight won 5 of 6, between 24 and 85 s in; the sixth ran out of time 19 m behind. Safe lost all 6 on time, never nearer than 66 to 92 m.
  - **The rival.** It threads arches and split slots dead centre (0.4 to 3.5 m off the middle). It clipped nothing in any default run (`clips` 0).
  - **The regions world, seeds 1 to 4.** Tight won 3, safe won none. A hall clip there (144 frames) led to the nave re-reading above; after it, 0.
- **Calling it off** (`scratch/race_off.gd`): a second press ends it as "race off", and so does turning away.
- **Stills** (rendered, `-- --no-title` through the driver), in `captures/race/`:
  - `look_bracket.png` and `bracket.png`: the bracket on a rival at 226 m.
  - `look_focus.png` and `focus.png`: the hold nearly full, with the mountain past the rival blurred.
  - `look_race.png`: early race, with the wedge and "236 m" over the rival and the far land only slightly soft.
  - `through_1.png` (seed 4): behind the rival as it enters a rock arch, marker "73 m".
  - `seed1/through_1.png`: the rival entering an aqueduct arch, "25 m · 0:10".
  - `result.png` (seed 4): "rival passed · 1:41". `seed1/result_time.png` shows "out of time".

## Other presets

These come from the same sweep with `--set pace=` and `--set weight=` on seeds 1 to 3.

- **Paces.**
  - today: tight won 2 of 3; the third was a driver crash loop. Safe won none.
  - fast: tight won 2 of 3, safe won none.
  - The pace follows your Boost, so it scales with the preset.
- **Weights.**
  - light: tight won 3 of 3.
  - off: too easy. Tight won 3 of 3, and safe drew level (1 to 6 m ahead at best, short of the 12 m win). There are no near misses or surge there, and the unweighted plane holds Boost through turns.
  - heavy: too hard for the driver. Tight lost all 3, even at `--rival-pace=0.86`. The heavy plane's lag defeats the bot's crude stick, and it is unknown for a person. Next: a pace per weight preset, judged by hand.

## What isn't repeatable

- **Seeded:** the rival's ducks (the seed, the race's number and the opening's name), its valley legs (an RNG from the seed and the race's number), and the split, hall and tunnel sites.
- **Not seeded:**
  - **Which traffic plane is where.** Traffic spawns round the player, so it follows how he flew.
  - **The arches the rival can see.** These come from `LandArches.standing()`, which the worker threads build round the eye. Two runs of the same seed can differ in which arches have stood up when the rival looks (seen in the sweeps: seed 1 safe threaded 4 openings in one run and 0 in another). For co-op, read the arch plan (`arch_plan.gd plan()` and the build's columns) instead of the built arches.
  - **A hall's height.** It is read from the hall's built pieces, so it also depends on what has been built.
  - **The pace and the catch-up.** Both follow the player's own flying.

## Tests

- Run and passing: `test_glide_camera`, `test_sky_plane`, `test_flight_study`, `test_flight_metrics`, `test_knife_drift` and `test_world_scale_guard`.
- None break. No test covers the traffic, the endless HUD or the pad table.

## What's next

- **Difficulties.** The knobs are in place: `--rival-skill`, `--rival-pace`, `CARRY`, `DUCK` and `FLOW_EASE`. A per-weight pace table would fix off and heavy.
- **The new canyon types.** The split API in use is `field.splits_in(box)`, `SplitSites.point(s, u)` and the site's `s[4]` (half length) and `s[5]` (floor half width). If the new canyon types keep that centre line and half width, the rival flies them unchanged. A bend tighter than its 41 m turn radius at race speed (`TURN_MAX` 1.35 rad/s at about 55 m/s) needs a slower carry or more route points.
- **The bracket.** At 400 to 500 m the plane is a speck and the bracket is the only cue. Judge by hand whether the faint ticks (alpha 0.42) read well enough.
- **The result line** is in the existing HUD's size, so it is small on a retina window, as all the HUD text is there.
- **Repeatable arches** for co-op (above).
