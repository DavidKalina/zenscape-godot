# Wilderness demo: handoff

Branch `claude/wilderness-population-80cf5c`, spec `spec-wilderness-demo.md`. Seed 1, medium
weight. Not merged to main.

## Where to play it

`.\run-endless-flight.cmd --fresh` from this worktree, or `python tools/play.py -- --fresh`.
`--fresh` plays on `user://pilot_fresh.json`, wiped once a run; `--fresh=keep` carries on from it.
`user://pilot.json` isn't touched. J opens the logbook on the Wilderness page.

The map: `site-map-seed1.png`, sites in `site-map-seed1.sites.json`.

## What's built

- **Finds:** 46 rows in `scripts/endless/finds_table.gd`: relics, landings, events and lines, in
  five areas (start meadow, south meadows, near coast, foothills, the Peak). A tally top left
  shows when it changes; the ledger has each area, blanks and some hints.
- **The pull:** a ring in the first frame, then three way towers (`way/bay`, `way/south`,
  `way/isle`) and ten rings lead to the ruin and the isles.
- **The ruin door:** `doors/amber-hall`, in an open meadow at (-1960, 3440) on stepped stone. A
  920 m hall, about 16 s on Boost, swaps worlds out of sight; a matching ruin in the Amberlands
  brings you back. The Amberlands hold their low sun while you're there.
- **Coast:** three islands, a lighthouse with a turning beam, a boat with a deck you can land on.
- **Surge roll:** on a full meter the roll button (Z, pad A, left click) breaks cracked walls and
  catches the burrower. Five cracked walls with chambers.
- **Lines:** the gorge run, round the stacks and the arch run, each with a best time and a mark to
  beat, plus the older meadow dash.

## Stood in

- "Relics" are gilt rings; the name and the look are stand-ins.
- The marks to beat are the Boost bot's times plus a little, not set by a hand.
- Way towers are lone belfry pieces, the door ruin's own. Not breakable.
- Leaves and spray are soft puffs, not leaf or droplet shapes.
- The start's spot on the map is a number in `tools/harness/site_dump.gd`, read from a title boot.

## Open

- **Not played by a hand:** all flight proofs are the bot's stick with a wobble. Whether a player
  turns left at the first ring, the marks, the arch run's S-curves, the boat's steep drop in.
- **The launcher path:** `.\run-endless-flight.cmd --fresh` itself wasn't run, because it would wipe
  the save being played. The driver went through the real title on `--fresh` in an isolated dir.
- **By ear:** no sound has been judged, the relic's and the door's included.
- **Sand spit in the bay** west of the start: a stair-stepped edge, with dark paint on the sand,
  seen on the climb out from the start (`captures/trunk/polish/stair.png`, local). It's in the land
  itself, so it wasn't touched: land outside the isles' footprints stays unchanged.
- **Aqueduct's end:** a flat white bar stands at the end of the arcades (a fall of water?),
  seen at `aqueduct-ring` and in the Amberlands.
- **Black dust:** gone from the stills, but why it happened isn't proved. It stopped when the
  particles all came out within two frames. `SmashBreaks._hit_dust` still skips the plume at the hit.
- **Frame spikes left:** `grass.step` at about (3441, 3997), `shops.step`, and the hall's swap
  (about 60 ms headless, 260 to 330 ms rendered at 1440x900, once a trip).
- **HUD key line** still runs past a 1440 window's edge; what's cut is the settings keys.
- **Find count:** the map draws 44 of the 46 rows. The two left out weren't traced.
- **Full suite not run.** `box_solid.gd` changed for every rock arch; no test known to touch it.
- Task 3's no-Boost legs after the last rings moved, and a landing on Long Isle from the trail,
  were not rerun.
