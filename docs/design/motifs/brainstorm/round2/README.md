# Round 2: ruin-kit pieces (spread)

Kit pieces only, no motif cards, no seed. Five agents, one theme each, with
lenses rolled apart. Cards are in the `kit-k*.md` files.

## Every piece

| Piece (id, family) | Theme / lenses | One line | Cost |
|---|---|---|---|
| Prayer Lintel (`relic_torana`, relic) | k1 climb · colossal, sacred | broken gate lintel tilting over the gulf, hung with knotted prayer ropes you chain swing releases up | low-med |
| Censer Well (`relic_censer`, relic) | k1 | giant three-legged censer whose smoke is a breathing thermal; sail up past corbel rings, slam the coals to stoke | med |
| Bowing Votary (`relic_votary`, relic) | k1 | kneeling colossus that bows on a cycle; grab its diadem low, ride it up a step past CHAIN_TOP | high |
| Broken Nimbus (`relic_nimbus`, relic) | k1 | colossal halo on edge, broken at the crown: shimmy the rim, surf the trough, plane flies through | med |
| Noria (`noria`, aqueduct) | k2 ride · human, playful, a line | water wheel lifting you pool to deck in level cradles; the top cradle pours you out as a surf | med |
| Channel Float (`channel_float`, aqueduct) | k2 | hollow log carried down the channel; dodge, then jump the break with its pace or ride the spill | low-med |
| Arch Swing (`arch_swing`, aqueduct) | k2 | stone board on chains under each arch, pumped with crouch; arch to arch on the high points | low-med |
| Rolling Drum (`hall_drum_roll`, hall) | k2 | fallen column drum rolled by running on it; leave it as a step or let a kerb throw you on | med |
| Well Sweep (`well_sweep`, carry) | k3 launch/carry · intimate, quiet, spread wide | stone shadoof you hang from and pump round across ~3 long jumps of gulf, tossed off at the peg | med |
| Haul Ferry (`haul_ferry`, carry) | k3 | floating deck hauled hand over hand on a rope between far isles | med |
| Bearing Stone (`bearing_stone` + `bearing_cradle`, carry) | k3 | carried stone ball you set or lob; ballast for the seesaw, the sweep and the flue cap | med |
| Flue Well (`flue_well`, carry) | k3 | well-head breathing a thermal for the sail and the plane; cap it to move the breath to a twin | low-med |
| Keel Counterweight (`keel_counterweight`, keel) | k4 solve · fragment, wrong, hanging underside | pan of a vanished lift that rises under you (inverted); slam the pan to launch the leaf | med |
| Hung Stair (`keel_hung_stair`, keel) | k4 | stair flight hanging upside down under a keel: a slide; slam or updraft flips it walkable for a while | med |
| Keel Oculus (`keel_oculus`, keel) | k4 | stone iris in a hung curtain wall; slam the keystone to open it for the plane; "wary" mode tracks the plane | med-high |
| Colossus Hand (`keel_hand`, keel) | k4 | colossus hand curled over a find; slam a knuckle to open a finger-bridge that curls back | high |
| Pent Hood (`pent_hood`, cloister) | k5 hide/descend · intimate, oppressive, tall stack | lean-to roof over a parapet gallery: cover underneath, boot-surf off the eaves on top | low |
| Corbel Shaft (`corbel_shaft`, tower) | k5 | roofed shaft through an isle and out its keel; wall-slide down ledge to ledge, hidden throughout | med |
| Catch Net (`catch_net`, cloister) | k5 | sagging net under a rim: a fall lands with no stun, holes drop you a tier | med |
| Hung Screen (`keel_screen`, gothic) | k5 | lancet wall hung from a keel: the plane threads the window, on foot you hang from the sill unseen | low-med |

## Engine-gap tally (in place of kit asks)

There are no motif cards in this round, so nothing asks for these pieces
yet. What the pieces need from the engine is ranked here by how many want
it:

1. **The editor can place only static pieces** (every moving and state
   piece, and `relic_torana`'s ropes). It has no live piece kind, no per-piece settings,
   no linked handles (leaf, boss, keystone) and no saved cycle phases.
   Raised by k1, k2 and k4. This blocks most of the round from the motif
   editor.
2. **A rider on moving ground** (noria, drum, sweep, ferry, votary,
   counterweight). `motor.carry` and the motor's `mover` are separate
   paths. RISE_KEEP lives only in foot_pieces. Carry may be yaw-only.
   Riding a slope on a tilting collider, or a ledge rotating about 60°, is
   untested. Raised by k1, k2 and k3.
3. **A placed thermal for the walker's sail** (`relic_censer`,
   `flue_well`). Only `layer_hazards.gd` wires one, and SkyCurrents' lift
   is fixed, so it can't breathe. Raised by k1 and k3. These two pieces
   share one build.
4. **Weight sensing** (counterweight, well sweep, bearing stone). Only the
   seesaw reads `loads`, and stunned bodies and tumble stones don't report
   that they're standing on something. Raised by k3 and k4.
5. **Triggers between pieces** (k4). The bell sends no signal when rung.
   The updraft's push reaches only things level with the pilot. The "plane
   passed near" check lives only in bell_spires. No world state is saved.
6. **Stealth** (k5). Crouching doesn't lower the sight points. Cover is
   one ray straight up. A soft landing isn't muffled.
7. Single asks:
   - KitLand can't cut a hole through an isle (`corbel_shaft`).
   - There is no carried-object hold and no interact button
     (`bearing_stone`).
   - Nothing reads crouch for pumping a swing (`arch_swing`).
   - Channel water has no current (`channel_float`).
   - The plane can't pass a thin line without a bump (`haul_ferry`).

## Spread pick: the three that differ most

- **Pent Hood (`pent_hood`):** static cover and a surf off the eaves. It's
  the cheapest piece in the round and needs no engine work. It also
  touches the stealth gaps, so it doubles as a test of them.
- **Noria (`noria`):** a clockwork ride that lifts you and pours you out.
  It's the clearest "ride" piece, and it fits the aqueduct isle (the game)
  directly.
- **Hung Stair (`keel_hung_stair`):** state change on an isle's
  underside. It reuses the `stairs` mesh and trap_flip's logic, and it
  opens the hanging-underside shape, which no motif has yet.

The cheapest playable set: `pent_hood`, `keel_screen`, `arch_swing`,
`channel_float` and `flue_well`.

## Overlaps and clashes

- **Thermals:** `relic_censer` and `flue_well` are the same mechanic in
  two looks. Build the thermal once.
- **Counterweights:** `keel_counterweight` and `well_sweep` both extend
  the seesaw's spring and loads. `bearing_stone` feeds both.
- **Swinging:** `relic_torana` (SwingRope), `arch_swing`, `well_sweep`
  and `keel_screen`'s `sway` are four takes on a pendulum. `arch_swing`
  and `well_sweep` could share one script.
- **Colossus hand:** `keel_hand` overlaps the Sunken Giant greybox's
  stand-in hand. k1 avoided a hand for that reason.
- **Slam turned into height** clashes with the motor rule that no pace
  turns into height. These pieces do it: `keel_counterweight`'s leaf
  launch, `catch_net`'s `spring` (k5 kept it off by default), and
  `relic_censer`'s stoke and `flue_well`'s tidal toss (indirectly). The
  user should rule on it before any of them is built.

## Page

`tools/motif_cards_html.py` draws only motif cards (`motif-*.md` with a
Layout block), so this round has no map page. The cards are text.
