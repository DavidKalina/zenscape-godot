# The Pillar Viaduct — "A road on legs. The legs are all that kept their promise."
Lenses: LITERAL · time a crossing / platform · half-collapsed · colossal · shape: a line · twist: the ruin still doing its old job (carrying people over)
Slug: `pillar_viaduct`

Pitch: The sundered hall stripped to its bones: no roof, no aisles, a high
deck on a file of enormous square legs, arcading into the haze, and the
bodies come over its sides. It is a platform crossing first, a pursuit second:
the pure-skill run-up and long-jump chains of the Broken Viaduct, on the
city's black stone, with the Olmec for the wind.

Place: Two city places a long way apart. The viaduct leaves the near place from
a **gate bastion**, a thick wall pierced by one tall arch, and walks out over
the gulf on **16 piers** (PILLAR 0.5 CELL at the head, battered, shaft going
down 48 m into the haze: `city_causeway`'s PIER_DROP), the span between piers
SPAN (26.4 m) in the causeway, or half (13.2 m, a two-bay opening) here so
the legs stand close enough to be seen as a file. The deck is `city_causeway`'s
deck, 11 m (DECK 2.5 CELL) wide with a curb a set-off tall: wide enough that
the Olmec can walk it but narrow enough that the sides are an arm's length.
**The view on arrival**: the gate arch frames a line of tiny dark squares
dwindling to a pale rectangle in the haze (the far gate); below the near
deck, the first four legs are visible going down and down; wind makes the
hanging root-ropes at the broken deck ends sway. **How it broke**: the
deck is whole near each end, gapped in the middle: three broken stretches,
each a different problem (a missing deck bay, a missing pier with the deck
sagged into a ramp, a pier toppled over with its deck fallen and laid
across the aisle below). The stone is the city's basalt, cracked along
the sagging spans, lichen in the lee; fallen deck slabs hang from the
piers by root mats and sway.

Top (1 char ≈ 4 m; the span runs up the page; arrival at the bottom) and Side:
```
   [ far gate ]                1
      ||||
      |  |     gap C: drop-and-chain
      |oo|
      |  |
      ####     gap B: missing pier, deck sagged
      |  |
      |o |
      #  #     gap A: deck gone, pier stub: long jump to stub then jump
      |  |
      |__|
   [near gate]                 0

Side (1 char ≈ 6 m long, 3 m high; arrival left):
    ____                                               ____
 __|    |__ __ _____ __ _ __ ___                ______|    |__
|  gate  ' ' '     ' ' ' ' '  \_ A      B  __/ C    '    gate |
|        | | |     | | | | |    | |      | |   | |    |  |      |
 ~~~~~~~~| |~|     | | | | |    | |      | |   | |    |  |~~~~~
          (the legs go down into the haze)
```

Play: the crossing contract in the city.
1. **Run-up (the straight).** The first 4 piers are whole: a 11 m wide deck.
   Run, learn the pace, hear the Olmec on the wall behind you. Slide the
   gentle grade down from the gate (the deck dips two set-offs after the
   gate, the Broken Viaduct's `RUN_DEG`).
2. **Gap A: the plain-jump gap.** One bay of deck is gone: a gap of
   `fall_gap` = the plain running long jump's furthest catch at the drop
   (7.6 m/s) plus a margin (0.5 m), the far deck `FALL_DROP` 0.5 m lower. Slide
   to the lip, Space, twirl at the peak to save, or chain.
3. **Gap B: the sagged deck.** The deck beyond a lost pier has sagged into a
   ramp. Slide it (momentum for gap C), or walk down the curb and wall-kick
   up the next pier's face: the pier is a clean box wall, a kick-chimney
   needs two faces (the inner faces of the legs of a paired pier), so the
   viaduct's legs are doubled pairs here and there.
4. **Gap C: the chain.** Two bays gone, the far deck a set-off lower: a chain
   of two (9.0 m/s) catches the lip, a chain of three (10.4) lands; or fall to the
   leg-pair below (a pier-head 6 m lower on the other side, a platform with
   its own jump back up via the kick). Fall = the "turn below": a second
   catch deck, not the void, 6 m lower, with a walk back via the
   `city_riser` giant steps built into the pier.
5. **The sides.** All the way, an Olmec body hauls itself up over the
   curb from below. The first appears behind you near the near gate, hand
   over the lip; the next is ahead, on the deck's edge at a gap, standing
   up. They do not shove you on the deck (they are slow); they stand in the
   way, and the deck is 11 m wide, so you pass them at arm's length, or the
   pounce lands where you were.

Threat: **The climbers and the leaper.** (a) *Climbers*: bodies spawned
(`cling`) on the piers' outer faces, climbing; they mantle onto the deck
edge, rise, and walk toward the noise. (b) *The leaper* (the body's `leap`
verb, with `leap_far` at `leap_fall` m a m down): on the high far gate or
the sagged deck, a body takes a running leap across a gap at you (a body
that crossed the gap proves the gap is jumpable; one that crosses it and
lands beyond you is now the problem on the other side). A tool: a climbing
body's hand on the curb is a handhold; the leaped-down body's landing shock
knocks you across the next gap if you time it (a boost you didn't ask for);
the sagged deck is the Olmec's staircase down to the leg-pair.

Could combo: an Olmec leaps a gap behind you, lands on the sagged deck, the
shock `knock`s you (stunned, thrown ahead) across the gap you'd have missed;
a climber on a pier mantles under you as you chain, you land on its shoulders
(a body is a platform: `standing` on a body is a catch) and it tosses you
forward. **Ports:** catches whoever is thrown from either gate; throws out
the sides (the void), or from the far gate through the arch onto the next
place.

Mystery: The deck's curb is carved with a repeating figure of a walking
person with a load on their back, always walking *toward the near gate*,
never away: this was the road *in*, from the far isle to the city. The far
gate's arch is closed with a thin stone slab on the wanderer's side only.

Kit used (verified in code): `city_causeway` (scripts/city_kit.gd;
`spans`, `drop`, `end_piers`, `bay` opts), `city_pillar` (the doubled
pier-pair, kick faces), `city_hall` (the bay and the kick chimney between
paired pillars), `city_riser` and `city_wedge` (city_kit_climb.gd: the
giant steps back up from the leg-pair), `maker_corbel` (city_kit_breaks2.gd:
the sagging corbels), `maker_cresset` (the far gate's lamp), `KitLand.island`.
Enemies: `headless_body` (`cling`, `climb`, `leap`).

Kit asks:
- `city_causeway` option `legs`: pairs of piers with a kick gap between
  (the doubled leg), and per-span state (whole / gone / sagged / fallen).
- A deck-edge "haul-up" mount: where a climbing body's mantle comes over
  the curb (existing `climb` ray logic should find the curb; this is a mark
  for the spawner, "cling at pier N").

Family knobs:
- `piers` 10-20 (the gulf), `pier_span` (one or two bays),
- `gaps` 2-4 with each one's kind (lost bay, sagged, fallen, missing pier),
  sized from the motor for the walker (`fall_gap` etc.), never copied,
- `climbers` 2-6, `leapers` 0-2,
- `rise` (the grade up or down).

Sockets: rim in at the near gate's arch (south), rim out at the far gate
(north); arenas: at gap B's sagged deck (the open stretch); cover: pier
faces and the curb; perches: the pier heads, the gate walls.

Generator fit: a **crossing between two places** (an edge, the crossing
contract: `lay_out`, `build`, `entry`, `exit`, `exit_reached`), replacing a
`city_crossings.gd` bridge when the pair is far apart; length 15-20 piers
(~130-200 m at a two-bay pier span, or about 90 m at one bay), height drop
-10..+10 m between gates. The deck carries a body, so a pair of such edges can
cross.

Distinct from: **the Hypostyle Span** (this is bare, fast and skill; that is
a hall, wider and slower, with the roof as a level) and from the sky's
**Broken Viaduct** (an aqueduct, a pure-skill with no enemies; this is the
same beats in black basalt with a pursuer on the sides).
