# The v1 game: collectibles (round handoff, 2026-10-14)

The v1 brief: runes (the coin) on every layer,
a rare collectible in hidden and hard spots, both tallied in the corner, on
the death card and in the saved record. The best haul is on the risky line.

Branch `feature/v1-collectibles` (from `roguelike` 6f57749a). Prototype
round: smoke checks and throwaway drivers in `scratch/`, no committed tests.

## See it

`run-game.command`, or
`studies/run_layer.tscn -- --shape=sprawl --world=under --seed=1`. Runes
stand along the felled colonnade's terraces right from the start; the
gallery's far end on that seed holds a rare. The motif yard shows them too:
`studies/motif_yard.tscn -- --motif=serpent_crossing`.

## What was built

| File | What |
|---|---|
| `scripts/roguelike/collectibles.gd` (new) | Lays and stands the runes, rares and chests of a layer. `lay(plan)` is static and data only (count a layer without building it). |
| `scripts/roguelike/collect_tally.gd` (new) | The corner tally on the hearts' row: a gold rune diamond and count, then the sun glyph and count. |
| `scripts/roguelike/layer_stage.gd` | Hooks marked `[collectibles]`: built in `setup`, stepped in `before/after/pose/frame/reset`. This is why the motif yard gets the pickups for free. |
| `scripts/roguelike/run_loop.gd` | Hooks marked `[collectibles]`: the signals into the run, the tally, the rare's caption, the card's lines, the WORDS for the rare. |
| `scripts/roguelike/run_state.gd` | `haul`, `rares`, `take_rune(worth)`, `take_rare()`; the record gains `most_runes`, `most_rares`, `rares_ever`. |

No generator file and no `gb_*.gd` was touched. Spots are read at run time
through each placed isle's motif (`spots()`, and `collect_spots()` when it
has one, deduped), moved by the isle's offset.

### Laying
- `rune_line` spot: 1 rune (`LINE`; the motifs already space these along
  their ways). With `LINE` > 1 they make a short line pointing at the next
  line spot.
- `rune_risk` spot: one rune on the spot, a ring of 5, one stacked over it,
  and on top a **great rune** worth 5 (bigger token). Reaching the top
  takes a jump on the exposed spot. 12 runes a spot.
- `rare` spots: 3 a layer (`RARES`), one an isle first, in a seeded order.
  With no rare spots in the layer, one goes on the greed isle's highest
  perch, else on the last stone of a hard crossing.
- A motif without rune spots (today stacked_court, the base isle and every
  sky kit motif) gets a light scatter from its sockets: arena 3, perch 2,
  cover 1.
- Crossings (plan edges), sampled along the walked line: a rune every 7 m
  on safe ones (stones, bridge, climb), every 2 m on risky ones (hard,
  voussoir trap, greed branch). 3 at the far lip of a gulf or cannon throw.
- Chests: 2 a layer (`CHESTS`) through the merged `ChestField`, at a cover
  spot (room 1.5 m or more) then a perch (2 m or more), off the start isle,
  paying 6 to 9 runes. They open with Space / A or a slam, as in the chest
  round.

### Standing
A pickup stands when he comes within 70 m. A ray in his own ground mask
finds the ground under its spot, and the pickup's middle sits 0.7 m above
it (the rare 0.85 m). A derived rune (a ring point, a crossing sample) with
no ground under it is dropped. A spot's own rune and a rare keep their
authored height. While the layer's isles are still standing up (nearest
the eye first), a miss is retried every 0.5 s instead of dropped. Motes run
only within 22 m.

### Looks (art direction)
- **Runes** reuse `GlyphPickup` "rune" in calm mode, retinted for the
  underground: tarnished gold `c79a52`, a warm glow at 0.32, a weak halo.
  The sky's cyan stays in the sky.
- **The rare** stands in as GlyphPickup's `sun` glyph, with a small warm
  lantern (OmniLight, 0.45 energy, 3.2 m).
- **The find:** the token's own spin and wisp. A warm light swells to 2.6
  and fades over 1.4 s. The sky tokens' flourish plays
  (`CollectiblesHud._flourish`). Time slows to 0.25 for 0.22 s real, then
  eases back over 0.35 s. The caption "SUN GLYPH / 1 of 3 here" comes up,
  and the tally's sun glyph swells and flashes.
- **Runes** sound the sky tokens' blip, climbing the pentatonic with a
  streak (pickups within 1.2 s).

### Tallies
- **Corner:** hearts, then ◆ runes carried, ☼ rares this run. The old
  "N RUNES" beside the height is blanked, because the tally now says it.
- **Card:** "4 runes lost / 1 sun glyph / 0:16 / / highest ... / richest
  climb: N runes, M sun glyphs", or "the richest climb yet" when this run
  beat the record.
- **Record:** `most_runes` and `most_rares` (best single climb; runes
  counted as the run's haul) and `rares_ever`.
- **Merchant room:** `runes` is the purse. `haul` is everything taken and
  never goes down, so spending later won't touch the bests.

## Counts (planned, `lay`, `--world=under`, seeds 1 to 6)

Runes by worth. "route" is the motif rune_line spots. "risk" is the
rune_risk clusters. x_safe and x_risk are crossings.

| shape | seed | route | risk | x_safe | x_risk | scatter | chest runes | rares | runes total |
|---|---|---|---|---|---|---|---|---|---|
| sprawl | 1 | 50 | 132 | 25 | 36 | 20 | 15 | 3 | 263 |
| sprawl | 2 | 16 | 60 | 11 | 0 | 0 | 18 | 3 | 87 |
| sprawl | 3 | 56 | 168 | 49 | 29 | 10 | 13 | 3 | 312 |
| sprawl | 4 | 69 | 168 | 18 | 32 | 0 | 16 | 3 | 287 |
| sprawl | 5 | 61 | 168 | 16 | 32 | 10 | 15 | 3 | 287 |
| sprawl | 6 | 48 | 192 | 29 | 36 | 27 | 15 | 3 | 332 |
| ring | 1 | 89 | 312 | 0 | 6 | 0 | 17 | 3 | 407 |
| ring | 2 | 79 | 228 | 0 | 15 | 20 | 12 | 3 | 342 |
| ring | 3 | 87 | 312 | 0 | 15 | 0 | 17 | 3 | 414 |
| ring | 4 | 56 | 168 | 0 | 19 | 29 | 14 | 3 | 272 |
| ring | 5 | 88 | 204 | 0 | 18 | 9 | 16 | 3 | 319 |
| ring | 6 | 105 | 300 | 0 | 13 | 10 | 17 | 3 | 428 |

- **Safe vs risky:** the safe line (route + safe crossings) is about 70 to
  110 a layer. The risky one (clusters + risky crossings) is 160 to 330, so
  about 2 to 3 times the safe haul (rule 0).
- **Rares:** 3 a layer on every seed. They come from the motifs' rare
  spots, e.g. seed 1: gallery_end (felled colonnade), behind_the_skin and
  gulf_stone (face).
- **What actually stands** (built layers, items within reach of the start
  area): nothing dropped near the start on sprawl 1 to 6 and ring 2 to 6.
  Headless, the far isles never report all standing, so the far items stay
  pending in that check. Measuring everything in place needs a rendered
  run.
- **Ring vs sprawl:** ring layers have no safe crossings, because every
  edge there is a risky kind.
- **Seed note:** on the run loop, sprawl seed 2 laid seed 3's layer. The
  run skips seeds it can't lay. That's the generator's behaviour, not this
  round's.

## Proven

- **Smokes:** run_layer sprawl seed 1 and ring seed 2 (under) pass with 0
  errors. `game_title.tscn` with run-game.command's flags passes, and a
  driver pressing Space there opens the run with runes standing and the
  tally made.
- **The motif yard** for the six city motifs: runes, 3 rares and 1 or 2
  chests stand for serpent_crossing, felled_colonnade, face,
  lamplighters_stair and coliseum_pit. stacked_court gets 7 scatter runes
  and 2 chests but **no rare**: it has no rare or rune spots yet.
- **The real play loop** (`scratch/coll_play.gd`, sprawl seed 1):
  - 4 route runes walked into through the stick input.
  - A rare (gallery_end) walked into: rares 1, time scale 0.25 in the beat
    and 1.0 after, the caption "SUN GLYPH / 1 of 3 here".
  - The tally matched the run (4 / 1).
  - A fall into the void gave the card "4 runes lost / 1 sun glyph /
    ... / richest climb: 4 runes, 1 sun glyph".
  - The record file held `most_runes 4, most_rares 1, rares_ever 1`. The
    driver used a scratch record path, so the user's record was left alone.
- **Rendered stills** (`captures/shots/collect_*.png`): route rune, risk
  stack with its great rune, rare in its spot, the find (a, b, c) and the
  HUD. Runes read as pale warm gold, the rare as a warm sun with a soft
  lantern, and the find as a warm bloom then the caption.

## Not proven / rough

- **Chests** stand and pay into the run through the chest field's signal,
  but no driver opened one here. The press uses Jump, as in the chest round.
- **Unreached rares:** no rare behind a break or across a hard jump was
  reached by real play. `behind_the_skin` and `corbel_heart` stand inside
  stone until the break, at the authored height (no ground ray hits from
  inside).
- **Risky crossings:** runes on the voussoir traps and hard stones sit on
  the walked line. Whether they read as tempting or just get taken in
  passing needs play.
- **Greed perch runes:** the old prize ring on the greed perch
  (`LayerStage._runes`) is still there and counts as before.
- **Tally rune icon:** drawn as a gold diamond in the tally itself, because
  the HUD's "rune" icon is cyan.
- **Rune colour:** the runes read a little cream at gameplay range. More
  tarnish or less glow is a one-constant change (`RUNE_TINT`, `RUNE_GLOW`).

## Tests this likely breaks

None found. `tests/test_run_layer.gd` checks only the greed perch's prize
runes, which are unchanged. Anything that asserts `run_loop.card_facts`'
line count, or the corner's side text ("N RUNES"), would break: the card
now has 7 lines and the side text is blank. No current test does.

## Open questions for the user

- **The rare collectible:** its name and its look. It's a "sun glyph" only
  as a stand-in (`WORDS.rare*` in run_loop.gd, the `sun` id in
  collectibles.gd).
- **The balance:** is a great rune worth 5 and 12 runes per risk spot the
  right weight? Three rares a layer?
- **What's lost on death:** should rares be lost on death like runes, or
  kept as lifetime finds (`rares_ever` already counts them)?
- **stacked_court:** it needs `rune_*` and `rare` spots from its polish
  agent.
