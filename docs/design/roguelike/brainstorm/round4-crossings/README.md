# Round 4: crossings (2026-10-15)

A variations round on one seed. The user said levels feel samey and asked for
more weight on crossings. They want islands that feel far apart, joined by a
crossing (which could be platforming) with the feel of the Broken Viaduct
(crossing-viaduct-round1.md). The seed was "a sundered hall type of section,
like a giant kind of bridge of pillars with Olmecs climbing over the edge,
over the sides, or maybe they're above you. And then they jump down at you."

Seven Sonnet agents each wrote two motif cards. The cards are set in the
underground Olmec city, where the run plays now. They were told to make the
gulf the subject.

## Every card

| File | Lens | One line | Fit | Cost |
|---|---|---|---|---|
| motif-m1-hypostyle-span.md | literal | `city_hall` stretched into a 14-bay roofed pillar bridge, about 90 m long. Three routes: nave, aisle crawl and roof. Bodies climb the faces and pounce from the architraves. | motif, two shores | med-high |
| motif-m1-pillar-viaduct.md | literal | A roofless deck on 16 legs with the viaduct's jump gaps (plain, sagged, chain of 2-3). Climbers mantle over the curb. | edge | med |
| motif-m2-procession.md | contrarian | Eleven toppled headless bodies, wedged like dominoes over 110 m. Their backs are the bridge, and the sixth is awake. | motif (7-body edge version) | med-high |
| motif-m2-underhang.md | contrarian | A whole, silent 150 m causeway. Bodies hang under it like bats and swat up through the expansion joints at noise. | edge | med |
| motif-m3-long-leat.md | time a crossing, working aqueduct | A 160 m water channel with three fallen spans. A sluice surge comes every ~30 s: jump dry, or ride the wave. | motif or edge | med |
| motif-m3-weir-stair.md | descend, working water | Seven stepped basins down a cliff, 40 m down a 65 m gulf. Rim-drop it, or surf the chute. | motif, tall | high |
| motif-m4-slumped-causeway.md | descend, mid-fall | A causeway slumped into a stepped zigzag, 130 m along and 40 m down, with two spans missing. Bodies drop from the tiers above. | motif, two shores | med |
| motif-m4-pancaked-hall.md | descend, tall stack | A nine-storey hall whose floors pancaked at slants. Drop through the wreck or wall-kick the standing frame. | motif, 45-70 m tall | med-high |
| motif-m5-haulway.md | ride, quarry machine | Two stone hawsers and a house-sized sledge on a counterweight. Ride it, rail-slide the cable, or change sledges at the relay pier. | edge | med-high |
| motif-m5-swing-boom.md | ride, colossal machine | A 76 m stone beam turning on a central pillar between three shores, with a swinging quarry block on a chain. | motif, ring | med-high |
| motif-m6-bearers-underway.md | stay hidden, processional | Bodies walk the lit deck in file. You creep a walker-only shelf under the road's lip. | edge | med |
| motif-m6-girder-tomb.md | stay hidden, tomb | A hollow girder gallery with the dead in niches. Footfalls sound overhead, and three roofless bays are exposed. | edge | med-high |
| motif-m7-unbuilt-span.md | platforming chase, dismantled | A causeway unstacked mid-work into a field of drum stacks, plus a hoist. A body chases you pier to pier, and its landings crack stacks. | edge, long | med-high |
| motif-m7-head-ford.md | platforming, fragment | A colossal toppled head lies in a ford of blocks. Go over its brow, through its ear, or round. | motif, two shores | high (model) |

## Kit-ask tally (ranked by how many cards want it)

1. **A causeway with knobs per span** (7 cards: m1 viaduct, m2 underhang,
   m3 leat, m4 slumped, m6 underway, m6 girder, m7 unbuilt). The asks are
   variations on one theme: `city_causeway` gets a per-span state (whole,
   gone, sagged, slumped, fallen), legs/pier spacing, open joints, a shelf
   under the lip, a hollow girder, and an underhang where a span broke. One
   parametric causeway would carry half this round. It is also the cheapest
   way to break up today's samey generator edges (plain column tops and
   causeway beams, `scripts/roguelike/city_crossings.gd`).
2. **New stances and spawns for the headless body** (7 cards):
   - seated or perched on an architrave, then dropping (m1 span)
   - clinging at a pier (m1 viaduct)
   - lying toppled, then rousing (m2 procession)
   - hanging from below and swatting up (m2 underhang)
   - riding a moving or turning deck (m5 haulway, m5 boom)
   - a sight-block flag for big stones (m7 head ford)

   The seed's "they jump down at you" lives here. `pounce` and `cling`
   exist; perching, hanging and lying don't.
3. **Break and settle states** (4 cards: m4 pancaked settle, m7 cracked
   stacks, m6 breakable bays, m2 breaking a slab). This is round 3's
   destruction metadata ask again (city-breaks-round*.md, `maker_chock`).
4. **Moving decks the pilot rides** (2 cards: m5 `haul_sledge` and
   `boom_beam`). They need `carry` on a moving and turning collider, plus a
   body that can stand on one.
5. **Live water** (2 cards: m3 `city_waterway`, `city_gate`, `city_weir`).
   The Weir Stair also needs a carried-slide (surf) rule in PilotMotor, which
   is Opus work.
6. **New hero models** (one card each): `maker_toppled` (a lying body,
   m2), `maker_head_fallen` (m7), and `city_hall` with a bay count and roof
   state per bay plus a walkable `city_architrave` (m1). `city_floor_slab`
   and `city_hall_cutaway` (m4) belong with these.
7. The walker-only shelf and gallery (m6) need nothing new: they use
   `scripts/walker_only.gd`.

## Spread pick (ranked on the place)

1. **The Procession** (m2). Toppled giants' backs as the only road, all
   lying the same way, with the sixth one breathing. It's the strongest
   image in the round and the most Olmec. Nothing else in the game reads
   like it.
2. **The Haul-Way** (m5). A crossing that moves: a sledge the size of a
   house on two sagging stone cables, already on its way when you arrive.
   You ride, rail-slide the cable, or change sledges mid-gulf. It's a
   different verb from every other motif.
3. **The Weir Stair** (m3). The tall one: a white zig-zag of seven
   lit basins falling into mist. It's water and descent, where the other
   two are stone and level.

Close behind: **the Slumped Causeway** (m4), the best authored collapse,
reading as a dropped chain, and **the Hypostyle Span** (m1).

**Literal vs the rest.** The Hypostyle Span is a sound baseline and the most
direct answer to "Olmecs over the sides and above you". The Procession and
the Slumped Causeway beat it on place. The Pillar Viaduct is the cheapest
route to the feel the user liked (the viaduct's jump gaps on city stone,
with climbers). **The contrarian found something:** the Procession turns
the seed inside out, with the Olmecs as the bridge rather than on it.

## Overlaps

- **Causeway variants:** five cards are skins of one causeway: the Pillar
  Viaduct, the Underhang, the Long Leat, the Bearers' Underway and the
  Girder Tomb. As generator edges they'd be one family with knobs, not five
  motifs.
- **Crossing under the deck:** the Underhang (bodies below, you on top) and
  the Underway and Girder Tomb (bodies on top, you below) are mirrors of
  each other. Pick one side.
- **Broken causeways:** the Slumped Causeway and the Unbuilt Span both read
  their collapse along the line. One is dropped in order and one was taken
  apart; they could share the per-span state.
- **Toppled giants:** the Procession and the Head Ford both use a fallen
  Olmec as terrain. They'd share the model work.

## Engine gaps and unverified numbers

- The headless body can't perch, hang under a deck, lie toppled or ride a
  moving deck (see the tally, item 2).
- No card checked `carry` on a moving or rotating collider.
- Most gap sizes were taken from the viaduct doc's reaches (plain jump
  7.6 m, chain of two 9.0 m, chain of three 10.4 m), not worked out from
  the motor. The pocket sail's range wasn't measured, and the Slumped
  Causeway's 14 m missing span and the Weir Stair's escape both lean on it.
  Measure these in the greybox (`tools/drive.py`).
- The m6 cards assume `headless_body._shock_meets` spares a hanging pilot.
  This is unconfirmed.
- The Long Leat's sluice knob names (`rides`, `beyond`) came from the trap's
  header comment, not its code.
- Several Top/Side ASCII sketches are smaller than the brief's 40x16
  template.

## Place (2026-10-15)

The three spread picks were greyboxed on the real terrain in the
underground look. Each got one review pass after I looked at its stills.
Each motif's smoke check passes. Everything is uncommitted; route drivers
are in `scratch/<slug>_routes.gd`. Each card's "Place (round 4)" section
has the full notes.

Play each with
`godot --path . res://studies/motif_yard.tscn -- --no-title --underground=haze --motif=<slug>`.

| Card | Slug and flags | Routes (walked through real input) | Threat | Stood in | My read of the stills |
|---|---|---|---|---|---|
| The Procession (m2) | `procession` (`--no-sleeper`) | Over the backs at a run: 48 s, with gaps of 2.5, 2.8 and 3.2 m. Over the backs at a quiet walk: 88 s. The old road of slumped slabs below: 77 s. The gulf is 116 m and the drop about 12 m. | A sleeper under the sixth body. A quiet walk doesn't wake it; a hard landing does. | The lying bodies are the real mesh posed and baked, drawn at 1.45x. The rise is a real headless_body asleep on a stump: awake, it only roams the stump and never climbs the backs. | The play camera on a back is strong: you're walking a giant's mossy spine. The side view reads as fallen bodies. From the arrival terrace it blurs into a rubble ridge, and some posts are still blocky. |
| The Haul-Way (m5) | `haulway` (`--no-olmec`, `--haul-at=S`) | Ride: 30 s carried, with 0.058 m of drift, and you can jump off and back on. Slide: crouch-slide a hawser at 12 m/s, then walk. Relay: switch sledges at the pier. | Fender arms on the pier that knock riders. | The sledges (14 x 8 x 3 m slabs), hawsers and fenders are built in the motif's own files. `motor.mover` is rewired the way the Serpent Crossing does it. The Olmecs wait on the pier and at B and never pounce onto a deck. | The two segmented stone hawsers sagging to the pier are a strong outline. There's less land than on the city places, and the gulf feels shorter than the card's. |
| The Weir Stair (m3) | `weir_stair` | Wet: step on the gate plate and ride the surge, 31 s. Dry: walk off 4.8 m ledges, long-jump the lost lips, then down two rock stacks in the gap, 47 s. Dry, careful: hang-drops and jump-catches, 51 s. No stuns on any route. The far isle is 51 m down across 55 m of air. | Two tenders climb over their rims; the warden head sits over the dry descent. | The surge clock (the sluice trap relayed), the tenders' cling-on-approach and the basins. The chute surf needs a carried-slide motor rule. | The low view is the best still of the round: pools on uneven legs over the void, and a sheet falling free 62 m. From the lookout it's plainer, and the basins are clean rectangles from above. |

All three are weaker on land than the Lamplighters' Stair. That's the
dressing pass's job (`/motif-turf`).

Engine asks this round made concrete:
- A headless body that rises or climbs from lying (the Procession).
- A headless body that boards and rides a moving deck (the Haul-Way).
- A carried-slide (surf) rule in PilotMotor (the Weir Stair).
- The `motor.mover` wiring for moving decks belongs in `studies/kit_isle.gd`,
  not in each motif (the Haul-Way).
