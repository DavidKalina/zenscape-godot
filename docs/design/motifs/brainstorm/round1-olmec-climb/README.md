# Round 1: the Olmec climb (variations)

Seed: the colonnade spine as a mini level, a few real islands stitched
together above and past the temple end, each higher than the last, joined
by rope bridges, stairs and floating stones, each with its own set piece
and turf. The Olmec climbs after you once he has his head. City kit pieces
come up in ruin style (no runes or frets, overgrown). His climb and his tilt
get real use. The spine stands where round 1 put it (docs/design/olmec-isle/round1.md).

Maps: `index.html` in this folder (`python3 tools/motif_cards_html.py
docs/design/motifs/brainstorm/round1-olmec-climb`).

## Cards

| Card | Lenses | One line | Cost |
|---|---|---|---|
| m1 [The Stepped Reliquary](motif-m1-stepped-reliquary.md) | literal | Three islands step up west of the temple (+21, +33, +47 m), each with a ruin-style city set piece: city_pit, city_wrap on a hung slab that tips, city_terrace; he climbs and leaps after you. | high |
| m2 [The Hanging Stair](motif-m2-hanging-stair.md) | contrarian: a hanging underside | Three islands hang under the temple (-14, -34, -58 m). He climbs up them to his head, then drops down them after you, landing on every tier. | high |
| m3 [The Hushed Reaches](motif-m3-hushed-reaches.md) | stay hidden, oppressive, spread wide | Five wide islands strewn west, each gulf too wide for his leap but not your ropes: hide in safe rooms, wait him out, cross while he climbs the wrong cliff. | high |
| m4 [The Felling Road](motif-m4-felling-road.md) | solve (lure him), colossal, a line | Four isles in a line, each join shut until his weight opens it: a felled column bridge, a slab court that launches you, piers toppled into steps, a stone that leans a lip into reach. | high |
| m5 [The Teeter Stack](motif-m5-teeter-stack.md) | fall then climb, playful, a tall stack | Five small plates stacked past the tail, every one light enough to tip: his haul lifts the far rim into a grab or lurches you down to a resting cradle. | med |
| m6 [The Processional Ring](motif-m6-processional-ring.md) | time a crossing, sacred, a ring | Five islands spiral up 62 m round the temple end: he takes the inner cliffs, you take the outer ropes and causeways, each crossing timed against his climb. | high |

## Kit-ask tally

| Ask | Cards | Notes |
|---|---|---|
| Ruin-stone mode for the city kit: the ruin kit's stone and overgrowth, no rune grooves (shader) or frets (geometry), shape, lanes, safe rooms and collision unchanged | all 6 | One option on `CityKit.piece` (m1, m2, m6 propose the same switch in `city_kit_stone.gd`). Every card depends on it: build it first. |
| A small tippable isle (a "plate"): a KitLand island under olmec_tilt's TIP_MOST, its own node, a convex solid for his rays | m1, m2, m4, m5 | Round 1's crags, generalized from three fixed sizes (m5). m2 tips whole tiers (36 and 52 m). |
| Ruin variants of the breaks: maker_felled, colossus_drum | m2, m4, m5, m6 | Folds into the ruin-stone mode. |
| A rope bridge on moving ends: anchors on a tipping slab, or slung steeply rim to rim and shaken loose by a tilt | m1, m2, m6 | Needs the rope sim to read moving anchors; m6 gives a fallback. |
| A smaller city_pyramid (two tiers, about 40 x 40 m) as a top-isle set piece | m4, m6 | |
| A rubble heap preset and a breakable "pier row" | m4 | |
| A pew stone (a grab height only while tipped) | m5 | |
| Steering him: switch off `relentless` past the temple; bias which cliff he climbs (a beacon lure) | m3 | Enemy logic, not kit. |

## Spread pick

The three that differ most:

- **m2, the Hanging Stair.** The only one that goes down. The same tiers serve his climb up to the head and the chase back down.
- **m5, the Teeter Stack.** Small and cheap (the only "med"), and the tilt is the whole level.
- **m6, the Processional Ring.** Big, wraps the temple, two lanes side by side, and every crossing is timing.

Against the literal baseline (m1): m4 and m6 keep its shape (islands rising west) and add a rule that makes the chase a puzzle (lure him to break the way; time crossings against his climb). Both beat it on play; m1 stays the plainest build. m5 beats it on cost and on using the tilt. The contrarian m2 found something: it plays the beat in both directions on one set of tiers, and lands the plane on the only tier too big to tip.

## Overlaps

- m1, m3, m4 and m6 all run islands up and away west of the temple; m1 and m6 even share set pieces (city_pit, city_wrap, city_terrace). A pick from these can borrow the others' rules.
- m3 and m6 both lean on the climb pieces' safe rooms (the terrace undercroft, the wrap's cell).
- m4's felled column bridge also appears in m2 and m6.

## Gaps to check before a grey box

- **Rope bridges and his routes.** m1, m5 and m6 assume he never walks a live rope bridge; none checked his route planner (scripts/enemies/body_routes.gd). If he can, the ropes are his too and their timing changes.
- **City pieces sized for the city.** His lane is CityKit.LANE (8.8 m) and the pieces' spans assume the underground's layout; on an open isle some will need trimming.
- **Not piece ids.** The city ways' spans are builder functions (m6), and `bridge_anchor` is a RuinKit function (m1), so the motif editor can't place either as a piece.
- **The sky.** m4 and m6 grow the isle toward the bell spires (354 m clearance from round 1); m2 makes it 76 m taller. Recheck motif_sky.gd PLACES and the landing run.
- **His numbers.** Some cards derived his sight, leap and climb from knob defaults; the grey box should read them from headless_body.gd.

Next: pick one or more for `/motif-greybox`, then `/motif-turf`.
