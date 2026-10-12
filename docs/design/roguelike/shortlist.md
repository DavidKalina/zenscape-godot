# Roguelike brainstorm: the shortlist (2026-10-12)

> Synthesis of ideas-traps.md, ideas-enemies.md, ideas-dragon.md and
> ideas-runes-ledger.md, placed on aqueduct-map.md. Spitball, not decided.
> Numbers in the idea docs are reasoned from the movement table, untested.

## Threads that run through all four

1. **The aqueduct's water is region one's signature.** Sluice Flush (trap),
   Millstone Beetle and Sluice Eel (enemies), the Sluice Warden (boss) and
   Keystone Collapse all live on the channel. The channel run (head, blind
   wall, arcade, the gap, the far run) is the hero section the generator
   should get good at first.
2. **Noise is the glue.** The dragon's hidden attention rises with noise and
   time: rune chimes, ledger clears, bells (Bell Toll trap, the Great Toll,
   the Bell charm item), the plane's engine. Greed is literally loud.
3. **The dragon sets off the world.** A swipe unzips a Keystone Collapse, his
   wake turns Draft Vents wild, Cinder Crows follow him, he tips rims so a
   badly parked plane rolls (Hangar Tilt). Runes buy him off (smoke pot,
   dragon toll); a cleared card can make an isle his no-landing haven.
4. **Every danger is also a tool.** Sluice Flush is a 6 m/s conveyor, Draft
   Vents a glide boost, the beetle's wheel jams the 3 m fallen gap into a
   bridge, a toppled Weeper is a lintel to cross, Spindle's thread is a
   slackline. This is what keeps the generator's output feeling clever.
5. **The fail ladder.** Void is death-ish; a fall onto the layer below is a
   softer fail (time lost, items kept, a fresh climb). A trap over void costs
   more and needs a bigger tell.

## The shortlist

| Kind | Pick | Why |
|---|---|---|
| Trap | Sluice Flush (3) | the aqueduct's own trap; hazard and conveyor |
| Trap | Loose Voussoirs (2) | cheap, teaches "keep moving", combos with the flood |
| Trap | Keystone Collapse (5) | the set-piece chase, the boulder of this game |
| Trap | Draft Vents (2) | adds "use the wind", feeds glide and updraft |
| Trap | Seesaw Slab (3) | best physics comedy; works for the plane |
| Enemy | Millstone Beetle (2) | the deck's patroller; bowling; gap-plug bridge |
| Enemy | Weeper (3) | a camera tell only 3D can do; dread for little code |
| Enemy | Plinth Ram (3) | the cleanest knock-off duel |
| Enemy | Magpie Kite (2) | steals runes or a plane part; a grudge |
| Dragon | attention + stir, gust + cover, plane swipe + barrel roll, rim tip | the minimum viable dragon, in that order |
| Economy | rune sets, 1 trader per layer, 6 items, scouting beacon | ideas-runes-ledger.md section 8 |
| Card reward | dragon-free haven | one reward first; rolled rewards later |
| Boss | Henge Guardian (summit) | fixed arena already exists; downdraft as the finisher |

Wildcards worth keeping: the dragon's hoard holds last run's lost items (and
debt to the dragon), the Mimic Lintel, the Hungry Door, Tilt Isle, the
Courteous Statue.

## Rule bends to fix before building

- Ivy Fuse stun and Lintel Drop trapping you: no stuns or cages, shoves only.
- Hush is "run-ending": make it a shove into void with a long tell, or cut it.
- Spring boots "remove fall damage": there is none; keep the bounce only.
- Cape duplicates the pocket sail; make it something else or drop it.
- Weeper with the plane's wide camera: needs a fairness test.
- Spindle and Reliquary Hand assume the motor's seize/toss; unchecked.

## A first slice, if it gets built

One generated layer from the aqueduct kit: a channel run with Loose
Voussoirs and Sluice Flush, a Millstone Beetle on the blind wall, Weepers in
the arcade, Draft Vents on the henge; a rune set and one trader (6 items);
the dragon's attention, stirring and gust with cover; a validator that the
layer's exit is reachable bare-handed.

## Open decisions for the user

1. Adopt the fail ladder (a layer down is a soft fail)?
2. Dragon unkillable, a nemesis across runs?
3. Region one's boss: Henge Guardian, Sluice Warden or Great Toll?
4. Debt to the dragon / his hoard of your lost items: in?
