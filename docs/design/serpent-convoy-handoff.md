# Serpent convoy handoff (short)

Branch `study/serpent-convoy`, from `study/slide-carve` (3546ff9d). Not merged, not pushed.

    ./run-serpent-convoy.command          # --convoy --carve
    godot --path . res://studies/serpent_ride.tscn -- --no-title --convoy --carve

Scenes picker: On-foot greyboxes, "Serpent convoy". Single-serpent mode is unchanged without `--convoy`.

- **The line.** N serpents (`--convoy=N`, default 5) fly one loop nose to tail, `--gap=` m (default 2) from each snout to the tail tip ahead. Each one behind the lead holds the lead's pace, nudged to keep its place, so the gaps stay within about 0.25 m (`rune_serpent.gd` `pace_hold`). The loop has two straight 1.2 km descents at `--descent=` degrees (default 20), each with one gentle S, joined by climbing half turns (about 22°). On a climb the downhill runs toward the tails.
- **Defaults chosen by a bot** (`tools/serpent_convoy_bot.gd`). Girth 2 for the line (`--girth=1.5` to compare). At 1.5 the last 10 m of a tail is a rope, and the bot landed 51% of leaps; at 2 it landed 85%. 20° beats 15° (44%) and 18° (76%); 22-25° landed about 90% but weren't adopted.
- **The leap.** Carve to the head, jump off its flat top, twirl, and land crouched on the next tail about 78-80 m from its snout. Pace is held across each gap (took off 11.9, landed 11.9 m/s). Peak about 13.3 m/s on the back and 27 m/s over the ground.
- **Speed cap.** Neither `SLIDE_TOP` (20) nor `LONG_TOP` (12) bites. The slope's own top (`SLIDE_AIR` drag) holds the surf near 12-13 m/s at 20°, so no `--slide-top` flag was added. Building speed across gaps would need landings down a slope to keep some of the fall as pace. That's a motor change, not made.
- **Falls.** Lost 8 m under the line (the take-off carried down the line's slope), with a quick fade. He's set back on the spine of the back he leapt from, where he was 1.5 s before take-off, at his pace then. **T** / pad **Y** retries the last gap at will. F1 counts falls, gaps, the string, the best string and its peak.
- **Keys.** 1-3 neck/mid/tail of the one you're on, 4 the last one's tail, 5 the top of a descent on the last one, R the start (counts cleared).
- **Perf.** Only the serpent you're on and any within 30 m have hulls in the world (`serpent_back.gd` `set_live`). With 5 serpents and 1 live: about 1.7 ms a headless frame in all, 1.6 ms for the line (hulls 0.8). F1 shows it live.

## Known issues / not done

- Nothing was played by hand. There are no rendered captures, and only scripted bots. No new test file: `tests/test_serpent_ride.gd` was not extended or re-run, and neither was `test_slide_carve.gd`. Only the import check and one headless convoy load (`--quit-after 300`, clean) were run.
- The leap only works with a twirl at ~12 m/s: from the head's top it's ~12 m plus the gap to a landable tail. Heads that glance back mid-leap still spoil some leaps.
- The bot only goes down the line. Jumping back down the line on climbs is untested.
- Next ideas: serpents side by side or at staggered heights for jumps across; let landings down a slope keep some fall as pace, so a string builds speed.
