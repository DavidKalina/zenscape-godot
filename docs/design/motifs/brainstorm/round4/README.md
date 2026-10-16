# Round 4: spread (motifs and kit)

No seed. The lenses were rolled toward the coverage table's empty cells:
the verbs chase, carry, stay hidden, defend and descend; the moods playful
and wrong; the shapes spread wide, a line and a tight cluster; and the
underground Olmec city as a world. There were five motif agents (Sonnet,
current kit only, kit asks allowed) and five kit agents (Opus, four pieces
each, none repeating round 2's twenty). Maps: `index.html`.

## Motif cards

| Card | Lenses | One line | Cost |
|---|---|---|---|
| m1 The Runaway Wheel | chase, playful, spread wide, sky | lead a millstone beetle to the lip and jump its wheel loose; below, a grand beetle's wheel jams in a cut too wide to jump and becomes the bridge | low-med |
| m2 The Ewer Road | carry, intimate, quiet, a line, sky | fill a stone ewer at the spring by the plane and walk it along five small isles to a dry cistern; hard moves spill it | med (needs a carry state) |
| m3 Five Wicks | stay hidden, oppressive, tight cluster, under | a headless body walks a court lit by four cressets; douse your torch, keep to the dark faces of the spires, and lure him to knock the fires over | low-med |
| m4 The Wick | defend, sacred, colossal, sky | a chapel-sized censer (a Beacon) draws headless bodies and an Olmec down three aqueducts; get them off with horns, a slammed voussoir and a down-charge, and ring the bell to relight it | med |
| m5 The Same Floor | descend, wrong, fragment, sky | a tower slice cut open like a dollhouse: three identical rooms stacked, the hole moved each floor, the third floor ending over cloud, so you glide to the tower's foot | med |

## Kit pieces

| Piece (id, family) | Theme | One line | Cost |
|---|---|---|---|
| `aqueduct_spouts` (aqueduct) | k1 grab/climb | overflow wall of spout heads gushing in a wave; climb the dry gaps, slip to the head below | med |
| `fives_court` (gothic) | k1 | three-walled ball court: wall-kick the front corner, surf the sloping coping off the end, go round | low |
| `cloister_pergola` (cloister) | k1 | beams just under GRAB_TOP, rafter rails above, sprung loose ends, fallen beams to surf | low-med |
| `works_scaffold` (new `works`) | k1 | mason's scaffold, levels a double jump apart, braces to surf, hoist rope at the top; underground the Olmec's landing brings a bay down | med |
| `orrery_arm` (relic) | k2 moving | colossal armillary arm docking at a ring of isles; in `wrong` mode it turns back with you on it | med |
| `relic_rolling_head` (relic) | k2 | colossal head rolling after you round a ring gutter, always facing you; you can lure it into a gate pier | high |
| `aqueduct_unmade` (aqueduct) | k2 | long span whose stones lift and clap back in a wave; race it, or ride the rising slabs to a higher route | med |
| `hall_flown_capital` (hall) | k2 | a column capital flies between far roosts; chase it by plane, drop on it, ride it home to its column | high |
| `relic_turnstile` (relic) | k3 launch/carry | spin a gate-turn's arms into enemies; the defend piece (ram turned, inhaler head broken off its inhale) | low-med |
| `belfry_sally` (belfry) | k3 | bell hung under the isle above; ring it up by its rope to rise one storey, and the ring calls the headless body | med |
| `horn_pipes` (horn) | k3 | five stone pipes sounding in turn, each tossing whatever stands on it up a storey; `lean` aims the throw | med |
| `relic_keystone` (relic) | k3 | carried relic set in a broken arch's crown; the missing stones rise and mend the span | med-high |
| `aqueduct_float_well` + `aqueduct_headgate` (aqueduct) | k4 state-change | slam a gate on one isle; a far well fills and floats you up, flooding the doorway at its foot | med |
| `relic_heliostat` + `relic_sun_eye` (relic) | k4 | turn a sun mirror one notch per slam; at the right hours it lights an eye on another isle and a drum stair rises | med-high |
| `tower_vane` (tower) | k4 | walkable stone weather vane; at some headings it bridges to a rim; push it with the updraft or the plane, pin it with a slam | med |
| `gothic_shored_spire` (gothic) | k4 | break one of the two shores and the spire falls into a bridge to that side, closing the other for good | med |
| `city_copal` (city) | k5 hide/dark | brazier smoke fills a sunk court; it dims the Olmec's sight and masks your scent | med |
| `city_echo_maws` (city) | k5 | noise made in a walker-only alcove comes out of a serpent maw elsewhere and pulls the hunt there | low-med |
| `city_flarepan` (city) | k5 | resin dish and reflector; one cone of glare dazzles the Olmec 3-4 s and cancels its tell | med |
| `city_mat_screen` (city) | k5 | woven mats across a bay block sight, not movement; they rustle, lift on the inhale, burn | low-med |

## Kit-ask tally

Each card's "Kit asks", grouped and matched to this round's pieces:

1. **Fires you can put out and light again (2 cards: m3, m4).** m3 wants
   `maker_snuffcap`, a lid slammed shut on a cresset; m4 wants a hung censer
   bowl that is the Beacon, dims a notch at a time and takes a relight. Of
   the pieces, k5's `city_copal`, `city_flarepan` and `city_mat_screen` all
   work light. None is the snuffcap or the bowl, but `city_flarepan`'s cone
   and the cresset share the light code m3 needs.
2. **Authored cuts (2 cards: m1, m5).** m1 wants a cut in a floor-slab lane
   with its width and approach length as parameters; m5 wants an open
   "section" face on `tower_shell` or `wall`, with a sawn edge. Both are
   about masonry cuts, not KitLand. `scripts/kit_isle/masonry_cuts.gd` may
   already cover part of this (unchecked).
3. **Carrying something (1 card: m2; 1 piece: `relic_keystone`).**
   `carried_ewer` with a fill level, `spring_well`, `dry_cistern`. A hover
   carry exists already (`scripts/carried_follow.gd`, used by the cannon's
   kegs and the plane parts), but nothing yet limits his moves while
   carrying. m2 and the keystone both want that laden state; one build
   serves both.
4. **Signals between pieces (1 card: m4; 4 pieces).** m4's bell has to
   relight a Beacon. `belfry_sally`'s "rung" signal,
   `aqueduct_headgate` to `aqueduct_float_well`, and `aqueduct_spouts`
   reading the sluice's flood are all the same need. It is round 2's gap 5,
   still open.
5. Singles: m5's stamp-a-room-down-a-column helper (a loop in the greybox
   will do).

## Spread pick: the three that differ most

- **m5 The Same Floor:** sky, downward, no threat, one vertical slice; it
  is the only card that is about the place being wrong. The building is
  stamped from pieces that already exist, plus one open-face cut.
- **m3 Five Wicks:** underground, hidden, tight, with a hunter. The kit it
  needs mostly exists (the cressets, the hush, the wick spires, the NoiseBus).
- **m1 The Runaway Wheel:** sky, playful, spread wide, and the plane flies
  between isles. An enemy's own prop becomes the bridge; it uses the
  existing millstone beetle and only one new cut.

m2, the Ewer Road, is the quietest and most different in feel, but it needs
the laden state first. Building that state would also open the keystone.

For pieces, the ones that reach furthest and cost least are
`relic_turnstile` (the first piece that fends enemies off; it fits m4
directly), `fives_court` (low, procedural, no new mechanics) and
`city_echo_maws` (the cheapest way to mislead the Olmec).

## Overlaps and duplicates

- m3 and m4 both turn on fire and the headless body (m3 hides from the
  fires' light, m4 defends a fire as a Beacon). They share the
  fire-control ask.
- k5's `city_copal` smoke and m3's dark do the same job: whichever is built,
  the other can use it.
- k2's `aqueduct_unmade` and k1's `aqueduct_spouts` both put a timed wave on
  the aqueduct; k4's headgate/float well is the aqueduct's third
  state-change.
- k4's `relic_heliostat` and the city's existing sun-mirror share an idea,
  but they work differently (one reads the real sun across isles, the other
  is a city prop).
- k2's `relic_rolling_head` and the tumble traps both roll at you; the head
  differs because it chases and can be lured.

## Engine gaps that keep pieces from combining

1. **Signals and saved state between pieces and isles** (m4; k1 spouts;
   k3 sally; all four k4 pieces). The bell sends no signal, nothing is
   saved per world, and the motif contract has one footprint, so a piece
   whose parts sit on several isles has no socket.
2. **The Olmec can't be shaken off** (all of k5; m3 leans on lures). A
   hunting Olmec hears nothing, and after 4 s lost it takes the pilot's
   scent whatever happens. There is no smoke volume, no light with a
   direction or occlusion, and no dazzle state.
3. **A rider on moving ground** (k2's orrery, capital and unmade span).
   This is round 2's gap 2: a bank under a rider, and pace turned into
   height, are both untested.
4. **The motif editor places only static pieces.** Nearly every moving or
   state piece here is blocked from it, as in round 2.
5. **Enemy hooks for being thrown** (k3: `swept` and `launched(v)` on
   `enemy.gd`; m4 never checked whether the horns gust headless bodies off).
6. **A laden state on the motor** (m2, `relic_keystone`).
7. Singles: catching the lip below after a slip (k1 spouts), a thin pole
   firing a stray wall kick (k1), a hinged bob spring (k1), lightning rods
   and the wind's heading on kit isles (k4), and water a piece owns that the
   pilot can swim in (k4).

## Unchecked numbers the next stage must verify

- m1: the grand beetle's wheel at `wheel` 6 is assumed to be about 4.8 m
  across (0.8 m × knob), and the 4.5 m cut to be past the long jump's
  ~4.2 m.
- m4: whether wind_horn gusts and traps act on headless bodies.
- m5: the fall off floor B (~22 m), and how hard a fall hurts.
- m3: whether the pilot can tip a cresset himself.
