# Rival race polish (handoff)

The rival race (`rival-race-handoff.md`) now has three new cues. A count marks the start. The rival's route is drawn in the world. A pass from the side or above counts, and the tag says why the lead dropped when it does. Results show big, with a sound and a rumble. The rival still flies the new canyon kinds; they needed no fix. This is a prototype round: smoke checks, a throwaway driver and stills. No tests were committed.

## Play it

```
.\run-endless-flight.cmd --race-near-start                       # Windows
./run-endless-flight.command --race-near-start                   # Mac
.\run-endless-flight.cmd --race-near-start --split-near-start --split-kind=gorge   # a canyon right ahead
```

Hold Tab (pad: R3) on the bracketed plane, as before.

## What changed

**The start beat.** On the accept, the rival takes its head start through a count of 3, 2, 1 (0.7 s each), then GO. Each number pops in, in gilt, with a small struck bell and a tap of rumble. GO gets a brighter bell over a rising breath and a firmer rumble. During the count the words read "head start". From GO, "pass it, then hold the lead" shows for 4.5 s. The 120 s clock now starts at GO.

**The race tag.** It hangs up and to the right of the plane on screen, mirroring the near-miss tag on the left. It has the same tilt (-0.12), the same fonts (Newsreader words, Barlow 800 italic numbers) and the same 2560 x 1440 design sizing. It shows:
- a line of words after a small faceted diamond;
- the gap in big numbers: cream "128 m" while behind, gilt "+9 m" once ahead;
- once you are ahead and on its line, a gold bar under the gap that fills over the hold.

The words say what to do now:

| words | when |
|---|---|
| pass it, then hold the lead | the first 4.5 s after GO |
| catch it | behind |
| level · get clear of its nose | ahead of it by less than 6 m |
| ahead · hold it | holding: the bar fills |
| too wide · close on its line (coral) | ahead, but more than 150 m off its line |
| it got back by · pass again (coral) | for 2 s after the rival retakes the lead |
| it's getting away (coral) | it is past the 550 m lose gap |
| `· 0:12` appended | the last 20 s |

A bell pitched up and a light rumble mark the moment the hold starts. The wedge over the rival stays, but it drops its gap text once you lead (the tag carries it). The old lead bar under the wedge is gone.

**Where it's going** (`scripts/endless/rival_marks.gd`, new). Both marks are drawn in the 3D world, so the land hides them; nothing shows through a hill.
- **The trail.** Small bone-white motes, 22 m apart, drift along the route the rival will fly for the next 6 s (at least 250 m). They fade in past the rival and fade out ahead. Down an open valley with no opening picked, the trail is shorter and fainter.
- **The gate.** Four corner ticks frame the mouth of the opening the rival has picked: an arch's span, a hall's or tunnel's mouth, or 110 m into a split canyon, past the mouth's flare, where the walls have closed in. The ticks warm toward gold over the last 250 m and go once the rival is in. When it ducks the opening (its skill knob), the gate vanishes as it peels away.

`rival_line.gd` gained `intent(ahead)`, which returns the trail points and the gate. Every candidate opening now carries a `mouth` index. The race reads the intent every 0.1 s.

**The result.** Big tilted gilt words in the tag's place pop in and hold for 3.5 s:
- **RIVAL BEATEN**, "passed in 0:34": a rising four-note bell and a strong rumble.
- **IT GOT AWAY**, "it was 562 m clear" (coral): two falling, duller notes and a low rumble.
- **OUT OF TIME**, "18 m short" (cream): the same sound as a loss.
- **RACE OFF** (smaller): no sound.

**Sound and rumble.** There are four new baked takes: `race-count`, `race-go`, `race-win` and `race-lose`. They come from `race_cues()` in `tools/generate_kit_audio.py` (`python tools/generate_kit_audio.py race_cues`), in `assets/audio/kit/`, and are loaded in `flight_sound.gd`. `flight_rumble.gd` gained `knock(v)` for knocks from outside the landing. The race calls it for each beat, and the next rumble step plays it.

## The new win rule, in numbers

| | before | now |
|---|---|---|
| ahead of its nose, along its heading | 12 m | **6 m** |
| off its line | 45 m aside (level only) | **150 m**, aside and above together (3D, square to its heading) |
| held | 2.5 s | **1.5 s** |
| the hold, when not passing | drained at 2x | drains at **1x**, and the tag says why |
| counts from | the accept | **GO** (after the 2.1 s count) |

The lose and call-off rules are unchanged: 550 m for 5 s, the 120 s clock (now from GO), the second press, turning away, 1400 m, or the ground.

The likely cause of "I passed one and it didn't do anything": a pass more than 45 m to the side counted for nothing, and so did a lead under 12 m or one held under 2.5 s. Nothing on screen said so.

## Proof

- **Smoke** (`tools/smoke.py`): passes three ways, each with 0 errors: the default, `--race-near-start`, and `--race-near-start --world=regions`.
- **Throwaway driver** `scratch/race_pass.gd` (uncommitted; a copy is in the session notes folder). It goes through the real input path: the stick, Boost and `fly_challenge`. It chases the rival and passes it offset by `--pass=side|above|line --off=M`. It logs the tag's words, the hold, and what the old rule would have said alongside.
  - **Seeds 1 to 6, 90 m aside and 90 m above** (`--rival-pace=0.8`, so the bot can catch it): all 12 won, 15 to 27 s in. The old rule had not won any of them by then. The aside passes would never have counted under the old rule.
  ```
  python tools/sweep.py scratch/race_pass.gd --seed 1..6 --arg pass=side,above -j 6 -- --off=90 --scene-args --race-near-start --rival-pace=0.8
  ```
  - **Sounds** in a won race: `race-count` 4 (3 beats and the lead), `race-go` 1, `race-win` 1.
- **New canyon kinds.** Slot, winding, gorge and grand on seeds 1 to 3 (12 runs, the rival placed just ahead at the mouth, `--rival-skill=10` so it doesn't duck): it threaded every split within 0.1 to 1.9 m of the centre line, with 0 clips. `SplitSites.point` follows the bends, and `s[5]` is still the floor's half width. **No fix was needed.**
  ```
  python tools/sweep.py scratch/race_pass.gd --set split-kind=slot,winding,gorge,grand --seed 1..3 -j 6 -- --pass=line --watch=40 --place=40 --scene-args --race-near-start --split-near-start --rival-skill=10 --rival-pace=0.6
  ```
- **Stills** (rendered, `-- --no-title`, git-ignored, in `captures/race_polish/`):
  - `gorge/count.png`: "2" and "head start".
  - `go.png`: GO and the rule.
  - `gorge/marks.png`: the gate ticks at the gorge's mouth over the rival, and the gap tag.
  - `gorge/marks_side.png`: a framed view of the gate round the rival and the trail running up the gorge.
  - `hold.png`: "+9 m" with the gold bar filling.
  - `result.png`: "RIVAL BEATEN · passed in 0:33".

## Judge by hand

- **The count.** Does 2.1 s feel like a beat or a wait? The rival is already flying, because it is its head start. `COUNT` and `COUNT_BEAT` are in `rival_race.gd`.
- **The tag's place.** It hangs right of the plane. With the chase camera, the rival is often just above the plane, and the gate is around it. Check that the tag doesn't cover the line you are flying.
- **The marks' strength.** The motes are faint (alpha 0.55) and a few pixels across far off. The gate is thin. The rival's own smoke trail is still the loudest thing. The knobs are at the top of `rival_marks.gd`. In the chase view, the gate is often right behind your own plane when you follow the rival's line exactly.
- **The win rule.** 150 m off its line is generous, on purpose. If passes high overhead feel cheap, lower `PASS_OFF`.
- **The sounds.** They are synthesized bells baked like the rest of the kit. If they don't sit with the flight sound, change `race_cues()` and re-bake.

## Known

- With you close behind it, the rival's "never into you" push can nudge it off its line into an arch. One run in an earlier sweep logged 44 clip frames (`endless/arch/4_5/0`) while the bot tailed it at 20 to 30 m. This round didn't change that behaviour, and the canyon runs clipped nothing.
- The headless import on this Windows PC rewrites many `.import` files (line endings only). They are not committed.

## Tests

- Ran and passed: `test_world_scale_guard`, `test_flight_study`, `test_glide_camera` and `test_sky_plane`.
- None break. No test covers the race, its HUD, the traffic or the rumble. The full suite was not run.
