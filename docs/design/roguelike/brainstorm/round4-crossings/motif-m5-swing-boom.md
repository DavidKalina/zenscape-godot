# The Swing Boom — "A beam longer than the quarry was deep. It is still turning to find its stone."
Lenses: ride/carry · mechanism+quarry · colossal · a ring (isles round a pivot) · intact and still working · sacred, then oppressive
Slug: `swing_boom`

Pitch: Three isles stand round a black gulf, each a long jump too far from the
next, and in the middle of the gulf one pillar holds up a stone beam the length of
a river barge, turning so slowly that you only see it has turned when you
look away. You wait on your shore for an end of it to come round.

Place: A **ring gulf**, a 40 m radius. At its centre the **pivot**: a tall
basalt pillar-isle (`city_pillar`, 18 m) with a capstan drum round its
head. Across it, a great stone **boom**, 76 m end to end (two arms of 38 m,
one long, one short and loaded), which turns on the pillar's head. On the long arm's
tip a **chain** hangs, and from the chain a quarry block the size of a
cottage swings 6 m under the beam. The short arm carries the counterweight:
a heap of stacked stone drums (`colossus_drum`), and on it the makers' hoist
room. Round the gulf, three shores on a ring: **Arrival isle S** (a quarry
bench, the cut face stepped, a dressed block on rollers), **the stockyard X** (a
grassy terrace stacked with squared blocks, the exit), and a **dry dock D**
(rare optional, a small ruin with a shrine of the quarry's tally; loot).
Their lips are 36 m from the pivot, so each lip is 2 m inside the long arm's
sweep. The gulf floor is a pale haze 60 m below.

Boom length is 76 m: the long arm reaches 38 m; the lips are at 36 m (the
beam passes 2 m over the ledge's lip when level, and a gap of 0 when it
aligns: a hand's width of gap, no more).

View on arrival (from S's lip): the pivot pillar centered in the gulf, the
boom as a long dark bar across it with its far end swung away behind the
pillar; on the left, the stockyard's grass lip; the hanging block swinging
very slowly. The pawl clunks and the hanging block steadies. The eye goes
boom, block, pivot, then the lip you want.

Top (1 char ≈ 4 m; the gulf ring ~20 chars across):
```
              XXXXXXXX              X stockyard (exit)
             XXX"""XXXX             
             XXXX^XXXXX
                 .
        o--------o----------O       --- the boom, now pointing at X's side
   . . .      (  P  )               P pivot pillar, ( ) its capstan ring
 SSSS                 . . .  DDDD    S arrival isle, D dry dock
SSS^SSS    ~~~~~~~~~~~~~~     DD^DD
SSSSSSS      gulf           
 SSS                          O hanging quarry block (pendulum)
```
Side (arm level with S's lip, from the south; each char 4 m):
```
 S 0m ###|   _______________________ boom (2 m over the lip)
      ###|  /                P pivot 18 m          O (block, 6 m under tip)
      ###| [__|__ stack]     ##                     |
      ###|                   ##                     o
            ~~~ void, 60 m to the haze floor ~~~
```

Play:
- **Route 1, the ride.** Wait on S for the long arm to come round (full turn
  in about 95 s; tip speed 2.5 m/s, a slow turn: 2*pi*38/95). At the alignment a pawl clunks and the
  boom dwells 6 s (the dwell is the tell). Walk onto the beam (a deck 4 m wide
  with a low kerb) and ride it round. It carries you: `motor.carry(by, turn)` takes
  a transform and a turn, so the pilot turns with it. At the next shore's
  alignment, walk off. About 100 degrees of arc per hop: 40 s of riding.
  On the beam, a walk to the pivot head gets you onto the short arm and its hoist
  room (loot and a view) for a second hop later.
- **Route 2, the leap (platforming).** Don't wait: when the boom *passes* S
  in the sweep (no dwell) its tip moves 2.5 m/s past the lip; a running jump
  (7.6 m/s) from a run-up on S's cut bench onto the passing beam at the right
  moment. Mis-time it: the gap grows by tip speed; after 3 s the gap is
  7.5 m, the length of a long jump, so the window is about 3 s. The skilled
  line also skips the dwell. A twirl (TWIRL_TOP 9) reaches the beam late.
- **Route 3, the block.** The pendulum block hangs from the long arm's tip.
  Grab the chain (a ledge-grab on the stone links) and climb down it to ride
  the block, then swing off at the swing's end onto X's lip, flung from the
  tip: 38 m radius arm plus the swing is a long throw. Fast, risky, only for
  those who want it.
- **Choice:** wait and ride (safe, slow, in sight of the Olmecs), leap on the
  sweep (fast), ride the block (a flight).

Threat: **Olmec quarrymen who never stopped working.** Headless bodies stand
on the boom's deck, trudging along it, and at the alignments some climb off
the pivot's capstan to ride the arm. As the boom dwells they walk off toward
you: a crowd that arrives at the shore with the beam. One body, as in
`headless_body.gd`, swats with its `reach` and `pounce`. On the beam it is on a
strip 4 m wide with a drop on both sides: the fight is always at the edge. And
the **block**: at the end of each turn the swinging block overshoots and
sweeps the shore's bench (a `knock` along the swing, source
`boom_block`), a slow giant hammer you read three seconds ahead from the
chain's angle. As a tool: stand under the hanging block with an Olmec beside
you, or let the body come to you down the beam and sidestep to let the
stone take it.

Could combo:
- A stunned pilot, flung (`knock`) by the block while the boom is turning, lands
  on the beam moving under: caught, riding. (catches: tumbling.)
- A headless body that leaps for the pilot from the beam (pounce) across the
  closing gap lands short when the boom has already turned: it falls, and the
  turn is the weapon.
- The fender-less pivot pillar's capstan ring is a walkable collar; a slid
  pilot on the beam's kerb is thrown off at its end with a toss (rail slide).
- Ports: catches a body thrown from S's rim (a cannon, a head's spit); the
  beam's end throws a rider off at an alignment with a low `toss`.

Mystery: A quarry that cut stone for a city that stood at the pivot's foot, now
only a pillar. The boom's carved rune line counts blocks lifted; the last
block hung from the tip is not stone but a dressed *head*, face down, still on
its chain: the makers' last commission, never set. The hoist room has seats
for four (headless) operators.

Kit used (verified): `city_pillar`, `city_causeway` (CityKit.PIECES);
`colossus_drum`, `maker_felled` (`city_kit_breaks.gd`); `hall_beam`,
`hall_column`, `hall_slab` (RuinKit hall family); `city_lip` (Hauling lip,
`city_kit_climb.gd`); `kukul_dais` (`city_kit_serpent.gd`, the capstan seat
of the pivot, as a balcony); `tower_shell` (the pivot head, hoist room, kick walls);
the pilot's `PilotMotor.carry` and `knock` (already used by `trap_logs.gd`);
`scripts/rope_bridge.gd` (as the chain's reference sim); `plinth_ram.gd`
(as the model of a charge that homes).

Kit asks:
- `boom_beam` (a rotating walkable beam on a pivot, with dwell at alignments and a visible tell: pawl and stone chocks; carries riders with `carry(by, turn)`).
- `boom_chain_block` (a chain of ledge-grabbable links and a pendulum quarry block as a `knock` source).
- Headless-body ask: standing and walking on a rotating deck (must read the moving body's frame).

Family knobs:
- `arms`: 1 or 2 (a second boom crossing the first at a lower height; the gulf gets a stack).
- `turn`: 70 to 130 s per revolution (tip speed 1.8 to 3.4 m/s).
- `shores`: 2 or 3 (D optional) and `radius`: 30 to 46 m.
- `block`: hanging, or "empty chain" (no pendulum, a tamer one).

Sockets: rim in on S (facing the pivot), rim out on X, optional rim on D,
arena on the beam's deck (moving), perch on the capstan ring and the
hoist room, cover in the counterweight stack.

Generator fit: a motif with its own shores: S as the entry, X as the exit,
D optional. Footprint is a disc 100 m across, falling 0 to 6 m between
shores (they're level; the boom is the stair). It suits the "ring" and
"tight cluster" layer shapes, and a wide pause between two plain isles of a
sprawl. Isles are far apart (36 m of void at least from lip to pivot).

Distinct from: **the Serpent Crossing** (a living animal on a loop with a
line, not a mechanical beam turning on a pillar with three shores), and
**the Haul-Way** (a straight line, one direction): this is a ring, a rotation,
and the timing is the alignment. Not the Face or Stacked Court: no ascent here.
