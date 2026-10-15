# Round 3: the Olmec city kit (2026-10-14)

Variations round on one seed: a new kit for the underground run, "an
abandoned Olmec city", Mesoamerican, built around the Olmec's moveset and
look (aqueducts A→B, epic staircases, the sundered hall, coliseums), on the
isles-over-a-void layout, read in a brown haze or by torchlight, never
cramped. The ruin kit stays with the dragon's sky stage. Seven Sonnet
agents (the user's call; AGENTS.md would send new kit to Opus), kit cards
only, each ending in motif hunches. Destruction
(`feature/olmec-destruction`, round 1) and the rune serpent were in every
brief.

| File | Lens |
|---|---|
| kit-k1-literal.md | literal: the pieces as the user named them |
| kit-k2-contrarian.md | contrarian: a giants' city, the wanderer the intruder; pieces that catch, pieces he uses on you |
| kit-k3-climb-lanes.md | grab/climb: lanes for two bodies (also has the two bodies' numbers side by side) |
| kit-k4-destruction.md | destruction / state change |
| kit-k5-serpent-ride.md | ride/carry: the rune serpent's city (Kukulcan) |
| kit-k6-light.md | light and dark: torch, beacons, hiding from his gaze, Mudge |
| kit-k7-vertical.md | vertical abyss: the city as isles over a void |

## Every card

| Id | Lens | One line | Cost |
|---|---|---|---|
| city_aqueduct | k1 | heavy battered-pier channel A→B; hide in pier niches, hang under the deck | med, procedural |
| city_stair | k1 | pyramid stair, 6.4 m flights, 8 m landings, serpent balustrade as rail, seams break to ramps/gaps | med, procedural + model |
| city_hall | k1 | the sundered hall in the makers' style; walker-only aisle slots, cross the crack on a fallen slab | med, procedural |
| city_court | k1 | ballcourt coliseum: sloped walls, high rings to swing from, tiers he hunts from | high |
| city_pyramid | k1 | temple pyramid: grab-chain the tablero, wall-kick tiers, walker-only summit door | med, procedural + model |
| colossus_riser | k2 | stairs cut for a god-king (2.2 m risers): his stair, your chimney behind the treads | low-med |
| colossus_mouserun | k2 | walker-only passage through a colossal wall: the escape he can't follow | low |
| colossus_drum | k2 | slab floor that hops when he lands: his shockwave throws you, or launches you on purpose | med |
| colossus_ashbowl | k2 | soft ash pit: land a fall safely, wade, drop him in | low-med |
| colossus_niche | k2 | votive niche ladder up a giant pier: perch, rest, cover from his sight | low |
| colossus_plug | k2 | plug-stone gate: lure him to break it, run through his hole | med |
| oc_relief | k3 | a cliff carved as one giant seated lord: you ledge-chain the carving, he just climbs | high, Blender |
| oc_lip | k3 | the hauling cornice, built for his hands coming over the edge in the dark | med, Blender |
| oc_pit | k3 | a gap where the jump is his and the inner cornice is yours | med |
| oc_wrap | k3 | pillar-isle with a 6 m spiral ramp (his) round a glyph-banded core (your climb); lanes cross every turn | high, Blender |
| oc_slot | k3 | thin wall, two faces two lanes; he reaches through arm slots, you climb the chimney inside | med |
| oc_proc | k3 | processional stair with a serpent flank, both bodies at different speeds | high |
| maker_felled | k4 | lure him into a drum column; which side he hits decides which way it falls (a bridge or a ramp) | med |
| maker_causeway | k4 | raised road over the abyss; spans drop to a lower road, slabs tilt and ride | med-high |
| maker_corbel | k4 | corbel vault gate/tunnel; once it falls, go over its roof | med |
| maker_skin | k4 | facing wall that peels in sheets; ride a sheet down, run the exposed earth core | low-med |
| maker_chock | k4 | slab held by a chock you slam out: lid, bridge, stair or trap on him | med |
| maker_stairfault | k4 | great-stair pier that drops a floor under his weight | med |
| kukul_balustrade | k5 | serpent cheek walls on the grand stair; the crest is a rail; runes flare as the serpent passes | med |
| kukul_dais | k5 | waiting dais with tick stones that light as the serpent nears; board it at a run | med-high |
| kukul_ring | k5 | stone ring the serpent threads; a ladder to climb, a crown to perch on | high |
| kukul_coil | k5 | colossal column with a helical ramp; the serpent's line spirals up it, so riding is climbing | med-high |
| kukul_collar | k5 | a stone saddle on the serpent's back: handholds, a lantern cage, where it shrugs you off | high (Opus) |
| maker_cresset | k6 | great fire bowl: lighting it reveals the route and calls every Olmec; breaks into burning spill | med |
| maker_mirror | k6 | turnable obsidian sun-mirror; aim the beam, stay out of its sweep | med-high |
| maker_runnel | k6 | oil channel: light the head and the fire runs the wall, showing holds; a clock | low (shader) |
| maker_hush | k6 | walker-only gallery out of his cone; a trough snuffs your torch | med |
| maker_wickspire | k6 | tall lone spire to get a light to the top; Mudge's home | med |
| ol_pillar | k7 | the isle itself: a hex basalt column out of the unseen floor, collars as a ledge chain | med-high |
| ol_drum_stair | k7 | stair wound inside a pillar's well; fall inward onto the turn below | med |
| ol_causeway | k7 | the colossal hero bridge between pillars, read from far off | high |
| ol_terrace | k7 | hanging terrace: shimmy the underside, hung balconies, an undercroft | med |
| ol_wedge | k7 | a fallen chunk jammed against a pillar: ramp, chimney, broken crown | med |
| ol_beacon | k7 | stepped tower with a cresset at the crown; layers read by their lights | low-med |

39 cards, all one new family (named city / colossus / olmec_city / makers /
kukul / ol by lens; merge to one when built).

## Kit-ask tally (engine needs, ranked by how many lenses lean on them)

Kit cards have no Kit asks field; this tallies what the cards say they need.

1. **A walker-only collision layer his rays skip** (k1, k2, k3, k6, k7). Hiding
   pockets, mouse runs, slots, galleries, summit doors: five lenses build
   the wanderer's refuge on it. Round 12 (`feature/body-ground`, walker-only
   tagging) was stopped after a worse first sweep, so it must be revived or
   redone before most of this kit works.
2. **Destruction merged plus per-piece `breaks` metadata** (k4 all, k1 stair
   seams, k3 wrap slabs, k6 cresset spill, k7 causeway bays). Today it
   lives on `feature/olmec-destruction`, colonnade only. k4 also asks the
   generator for two-level placement (a lower road for a span to fall to).
3. **Beacon / attention hook**: a lit thing registers like the head's call
   in the body's hearing (k6 cresset, wick spire; k7 beacon). Reuses existing
   code, cheap.
4. **Light-aware body sight**: a visibility term in `body_sight.gd` so shadow
   and an unlit torch hide you (k2 niche, k6 hush gallery).
5. **PilotMotor moving-platform velocity** (k5 dais and collar; k4 tilting
   slab rides). Opus work.
6. **`ports()`** on pieces (k7), already the combo lab's prerequisite.

## Overlaps (five lenses converged)

- **The epic stair** is the round's spine: city_stair, oc_proc,
  kukul_balustrade, maker_stairfault, ol_drum_stair. Merge into one stair
  family: his width (≥5 m, landings ≥6×6), serpent cheek walls whose crest is
  the rail slide and whose runes wake as the serpent passes, courses that
  fault and drop a floor, and an inside-well variant where a fall lands on
  the turn below.
- **The bridge**: city_aqueduct, maker_causeway, ol_causeway. One causeway
  family: battered piers, the far hero silhouette, bays that drop to a lower
  road.
- **The pillar with a spiral**: oc_wrap, kukul_coil, ol_pillar (+ drum
  stair). The underground isle's base shape: a basalt column whose spiral
  is his lane and the serpent's line.
- **Fire on high**: maker_cresset, ol_beacon, maker_wickspire. One cresset
  piece, sized as a bowl, a tower crown or a spire top.
- **The refuge he can't enter**: colossus_mouserun, colossus_niche,
  maker_hush, oc_slot, city_hall's slots. All need ask 1.

## Spread pick (place first, most different from each other)

1. **ol_pillar + ol_drum_stair (k7)**: the underground isle itself, a basalt
   column out of an unseen floor with a stair wound inside it. It makes the
   world: layers read at a glance, falls land on the turn below, and his
   lanes are built in. Beats the literal city_stair, which it absorbs.
2. **maker_felled (k4)**: lure him into a column and he builds your bridge.
   The threat as the only way across, on the destruction work that exists.
3. **maker_cresset (k6)**: light as solve and alarm. Every Olmec turns to a
   lit bowl; the torch-dark look becomes a game, and Mudge gets his place.

Literal baseline: its pyramid stair and aqueduct are solid but were beaten by
the merged versions above. The **contrarian found something**: the mouse run
(the refuge he can't follow) became the round's most-shared idea, and the
drum floor (his landing launches you) is the best "danger is a tool" piece.

Motif hunches worth a card next: k7's **Stacked Court** (three pillar-isles,
drum stair, causeway, beacons; you look up at the lights) and k3's **The
Face** (a cliff carved as a lord; his hands appear on the headdress).
