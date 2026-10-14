# Brainstorm round 1 (2026-10-13)

The brief: docs/design/roguelike/motif-brief.md. Five motif agents (current
kit only, Sonnet), five kit agents (new pieces, Opus). Mid-round the user
added the top pillar **everything chains**; every card was revised for it.
Brainstorm only: no code touched, nothing verified in Godot. Numbers in the
cards are reasoned from the motor's constants, untested.

## Motif cards (10)

| Card | Lenses | One line |
|---|---|---|
| [The Tithe Wheel](motif-m1-tithe-wheel.md) | time a crossing · calendar · wrong | a calendar henge; four spokes of out-of-step flip slabs to the hub; on the tithe beat all flip at once and throw you |
| [The Noon Weir](motif-m1-noon-weir.md) | time a crossing · mechanism · old job | a water-clock tower of three stacked aqueduct channels; climb each dry, ride the Noon Flood down |
| [The Sunken Giant](motif-m2-sunken-giant.md) | climb · colossal · tomb · Olmec as terrain | the isle is a kneeling headless giant; climb fist→arm→chest; two heads pass you between them |
| [Lidstack](motif-m2-lidstack.md) | climb · tomb · root-bound · stack | burial terraces round a colossus column; a tumbling lid-block, a voussoir row, a cannon out |
| [The Astronomer's Hush](motif-m3-the-astronomers-hush.md) | stay hidden · observatory · sacred | four islets round a henge; an inhaler head circles; pillars block its pull; its blast is the exit |
| [The Vigil of the Bellows](motif-m3-the-vigil-of-the-bellows.md) | stay hidden · observatory · cluster | a cloister garth under a star tower; the wind-horn tracks movement; tech its gust into the kick shaft |
| [Benchfall](motif-m4-benchfall.md) | fall · quarry · oppressive · stack | an open quarry pit of four benches 60 m deep; every miss lands a tier lower; a hoist back up |
| [The Plumb Well](motif-m4-plumb-well.md) | fall · quarry · oppressive · stack | a dark column of five plates with offset holes, one trap each; the head at the foot fires you out |
| [The Washing Rite](motif-m5-washing-rite.md) | defend · shrine · drowned · threat is the way | hold a refuge pier while the sluice wave passes, then ride it and jump the gulf off its back |
| [The Warden's Well](motif-m5-wardens-well.md) | defend · prison · drowned · threat is the way | a flooded prison hall; aim the head's gulp-and-blast across the void into a second head |

## Kit cards (26 pieces)

| File | Theme | Pieces (cost) |
|---|---|---|
| [kit-k1-grab](kit-k1-grab.md) | grab and climb | Sleeper's Face (high), Basalt Palisade (low), Glyph Register Wall (med), Holder's Chains (med-high), Root Curtain (med) |
| [kit-k2-moving](kit-k2-moving.md) | things that move | Rune Dial (high), Yoke Lift (med-high), Fold Stair (med), Breath Pillars (med), Calendar Drum (med-high) |
| [kit-k3-launch](kit-k3-launch.md) | launch and carry up | Breath Well (med-high), Root Sling (med), Patient Plinth (med), Gullet (low-med), Calendar Wheel (high) |
| [kit-k4-state](kit-k4-state.md) | change state | Weir Basin (med), Shy Root Lattice (med), Lit Span (low-med), Chime Door (med), Sleeping Face (high) |
| [kit-k5-makers](kit-k5-makers.md) | the makers' architecture | Stepped Tier (low-med), Column Palisade (low), Cave-mouth Throne (med), Glyph Stela (med), Sky Ballcourt (med), Buried Colossus (high) |

All five kit agents independently put their pieces in one new family in
the Olmec makers' style (called makers, maker or works). K5 set its rules: a
4.4 m cell (the gothic BAY), so it butts flush against the gothic kit;
1.6 m tiers (one jump per lip); the Olmec stone shader with a new glyph
include.

## Where agents converged (the tally)

Ranked by how many agents reached for it unprompted:

| Idea | Who | Count |
|---|---|---|
| **A colossal Olmec face as terrain that swallows and spits you, aimable** | K1 Sleeper's Face, K3 Breath Well, K4 Sleeping Face, K5 Buried Colossus; asked by M2, M5 | 4 kit + 2 asks |
| **Calendar machinery** (rings, wheels, drums, beats) | K2 Rune Dial and Calendar Drum, K3 Calendar Wheel, K1 Glyph Wall cycle; M1 both cards | 4 + M1 |
| **Root that catches a tumbling body** (curtain, cable, sling) | K1 Root Curtain, K3 Root Sling, K4 Shy Roots; asked by M2 | 3 + 1 |
| **Updraft vent / chimney** | K3 Gullet, K5 palisade vent; asked by M2 (both cards) | 2 + 2 |
| **Basalt column palisade** | K1 and K5 both, nearly identical | 2 |
| **Terraces / stepped tiers** | K5 Stepped Tier; asked by M2 (terrace ring) | 1 + 1 |
| **One shared trigger/clock language** (rune circuit, rune link, shared beat) | K4 rune logic, K2 rune link, M1 shared clock | 3 |
| **Head-to-head passing** (your example) | M2 Sunken Giant, M5 Warden's Well, K1, K4, K5 | 5 |

## What blocks combos today (engine gaps the agents found)

These sit under every chain; worth a round of their own before or with the
first kit pieces. Each one flagged by an agent reading the code:

1. **The cannon can't catch a thrown body**: you can only climb in on foot
   (K3). "Shot from a cannon while ragdolled" needs this.
2. **Ropes refuse a tumbling body**: `swing_rope.gd:192` rejects
   `move == "tumble"`, and `seize()` only ends in a `knock` (K1). Root
   catches need a hand-off from seized to riding.
3. **Does the inhaler head's pull take an already-stunned airborne body?**
   Unverified (M5). Every head-to-head chain depends on it. Can its route be
   a closed ring? (M3).
4. **Does the wind-horn's gust `knock` with its own source like the
   blaster? Can it track?** Unverified (M1, M3).
5. **Plates and triggers should count any body's weight** (enemies, blocks,
   a stunned pilot), not just the pilot (K4).
6. **A carom rule**: faces that bounce a stunned body on, still stunned
   (K5). Touches PilotMotor.
7. **A shared clock/phase** for traps in one motif (M1); folds into the rune
   circuit (K4, K2).
8. Smaller: does the sluice carry enemies (M5); deep water that floats the
   pilot (K4); is wall-kicking possible at a 2.0-2.2 m chimney width (K3).

## Spread picks

**Motifs: the three that differ most from each other and from what exists:**
- **The Plumb Well**: a true vertical stack (never built), dark, falling as
  the verb, five different trap sources in one drop, the head as the way
  out. Mostly current kit.
- **The Tithe Wheel**: flat, all timing, calendar; current kit (flip traps,
  stone circle). The cheapest to prototype.
- **The Astronomer's Hush**: stealth round a moving head, cover as the verb;
  current kit plus the inhaler head.
- Wildcard, closest to the head-to-head combo you asked for: **The Warden's
  Well**.

**Kit: the three most asked for:**
1. **The colossal face** (merge K1/K3/K4/K5 into one piece): climbable
   terrain plus an aimable swallow-and-spit. A hero piece; Blender sculpt;
   high cost but the clearest link to the Olmec and to combos.
2. **The basalt palisade** (K1 = K5): low cost, all procedural, a good first
   build to set the makers' family, shader and grid.
3. **The gullet / updraft vent** (K3, asked by M2): low-med, reuses the wind
   code, the vertical edge a stack needs.

## Greybox (2026-10-13)

All ten built in `studies/greybox/`, each a playable study with the real
pilot, traps and enemies, its layout in one data table, its notes in a
"Greybox (round 1)" section at the end of its card. One shared headless
import; all ten smoke clean (400 frames headless, no script or parse
errors). Checks were scripted headless through the real motor; nothing has
been judged by eye or felt in hand.

Run any with: `godot --path . res://studies/greybox/<slug>.tscn -- --no-title`

| Motif | Slug | Works (headless) | Stood in / broken |
|---|---|---|---|
| Tithe Wheel | tithe_wheel | bot crosses a spoke to the hub; horn chain lands the rim; tithe ride 3/4 timings; head (round 2) blasts you onto the hub only at blast_out 23 (20, 23-25 land; 21-22 fall; 27+ overshoot) | a flip tosses ~1.4 m (card said 5-8), so slabs can't pass you spoke to spoke |
| Noon Weir | noon_weir | Noon Flood chain end to end with no input (~11 s, 3 spills, 3 rides) | gates must stagger 2.9 s / 5.5 s; shared clock is a script; cannon link skipped |
| Sunken Giant | sunken_giant | the whole climb incl. a 2.2 m wall-kick chimney; chain 1 (head 1 blasts you onto the chest) | **head to head broken on head round 2**: head 2 starts pulling ~13 s after the blast; blast is level, can't throw you up |
| Lidstack | lidstack | 36 m wall-kick chimney; tumble block drops you down the terraces; cannon to the exit pad | the block slides, never truly knocks; vent is a toss zone; root ropes, face not built |
| Astronomer's Hush | astronomers_hush | cover blocks the pull; the head heaves a 10 m ring on the Circle (~3 min a lap); blast to the slab roof (narrow band) and apron | head has no hearing, so the decoy slam can't happen; hall now flush (the blast can't cross a gap) |
| Vigil of the Bellows | vigil_bellows | gust into the tower shaft; seesaw-then-gust chain | the wind horn has no gust (dressing only) and can't aim down; gust is a scripted knock |
| Benchfall | benchfall | all 15 lip walk-offs land a bench lower (stunned); the glide skip; 28 m hoist by wall-kick | chute is a ramp; slam-and-ride chain unverified |
| Plumb Well | plumb_well | hatch toss; dropper launch; slabs drop him stunned; head gulps and blasts him out rim S (blast ~15 m, rim moved in) | the head inhales too late to catch the stunned body; the five-source chain doesn't run on its own |
| Washing Rite | washing_rite | plate, wave ride, twirl-jump the 7.5 m gulf, updraft: through real input | wave carries only the pilot, not enemies; enemy chain can't fit the channel |
| Warden's Well | wardens_well | **head to head on head round 2, no input**: both heads on turf; head 1 blasts to cell 1, head 2 gulps mid-slide, blasts to the exit rim (~1 m margin); a stunned airborne body is gulped | head 2 kept awake by study knobs (tell 0.4, inhale 60); voids 8-9 m for the weaker blast |

**The branch moved mid-round:** commit ce4efa13 (inhaler head round 2) made the head ground-bound, heaving, with a weaker, slower inhale and a ~10-15 m blast. The five head greyboxes were rebuilt on it; rows above are on the new head.

**Combo rules learned:**
- A head blasts back the way you came: the catching head sits behind the
  incoming body's line, facing where it should go next.
- A head pulls (and gulps) only while drawing breath (`tell`/`inhale`,
  scripts/enemies/inhaler_head.gd `_pull`): it must see you, lock, and tell
  for 1.4 s first. A body blasted at a drifting head arrives unnoticed.
  It does pull a stunned body in the air; a stunned body lying down barely
  moves.
- A head's pull ignores you above ~0.8 of its height.
- The fall stun starts at 6 m (FALL_STUN_PUMPS); stacked tiers ~5-9 m apart
  make every miss a stunned catch, not a death.
- Wall-kick chimneys climb at 2.2 m width (Sunken Giant, Lidstack).

**Combo blockers, updated** (adds to "What blocks combos today" above):
- **Heads can't hear, and the round-2 head is slow to wind up.** Give them ears (a slam, a bell, another head's
  gulp primes them to inhale): unblocks head to head without a kept-awake
  head, and the stealth decoys. The top fix.
- The wind horn has no gust of its own and can't aim down.
- The sluice wave carries only the pilot.
- Trap throws are small (flip ~1.4 m): a chain needs launchers (heads,
  cannon, gusts), not traps, for distance.
- Still open: the cannon catching a thrown body; ropes taking a tumbling
  body.

## Opus pass (2026-10-13)

The user judged chain work to need Opus's spatial reasoning (AGENTS.md now
says so). Each greybox got an Opus pass to rearrange its layout until its
chains hold, scored by headless reliability runs through the real motor and
tick (start ±0.5 m, timing ±0.2 s; 8/10+ is a route). Sonnet versions are
in the session scratchpad. All ten smoke clean on the current branch; the
hub cycles them. Each card's "Greybox (Opus pass)" section has the detail.

| Motif | Chains (x/10 or runs) | Key rearrangement |
|---|---|---|
| Sunken Giant | accident 12/12 · **head to head 12/12** (20/20 random head phase) · chimney vent 12/12 | head 2 parked facing where head 1's blast leaves you |
| Warden's Well | **head to head 10/10** ×2 seeds, default knobs · body shove 0/10 real (9/10 stood in) | well steps down; head 2 sits where head 1's skid ends; voids 7.5 m, margin 1.6-1.9 m |
| Plumb Well | **five-source column 10/10** (20/20 spread) · threaded 10/10 · head cannon 10/10 | oculi in one line down a wall; seesaw_drop for the dropper; head under the fall |
| Lidstack | lid knock → slabs → grate → cannon → exit 10/10 · vent 10/10 ×2 · cannon 10/10 | lid crossed along its axis (a true knock); catching cannon stood in. Combo 1 now exits the level (card had it drop you back: the user's call) |
| Noon Weir | flood 10/10 ×4 entries · ram accident 10/10 · cannon chain 10/10 | gate offsets derived from the layout; a second wave 1.5 s behind; 1 m channel walls |
| Washing Rite | ram→wave 10/10 · wave jump 10/10 · body shove→wave 10/10 | the channel floor is the plate; funnelled lane; a lintel |
| Benchfall | slab cascade 12/12 · glide skip 12/12 · shoved giant 12/12 | slabs over the chute; chute through a slot; the body as a ridden block (stood in) |
| Vigil of the Bellows | 17/20 to 20/20, every chain · 0 lost over 79 points | two horns on one bellows; gust = the blaster's real knock numbers |
| Astronomer's Hush | caught→roof 10/10 · Odyssey line 10/10 · **sight decoy 10/10** (40/40) | catch terrace round the Circle; a gnomon lure the head can't pull |
| Tithe Wheel | wheel plays you 35/40 · tithe ride 23/24 · horn 35/36 · head to hub 19/20 default blast | flip is a lever (1 m centre, 7-9 m at the lip); two rows on one line; hub backstop |

**Engine changes the passes asked for** (none made; this is the link-fix
round's list, roughly by how many chains want it):
1. **Head hearing**: a step, shove, slam or another head's gulp starts its
   wind-up (Warden's Well C, Hush's original decoy, any relay not parked
   in sight). Also: the body holds still while its head gulps or blasts;
   a pause at chosen ring points; the 0.8-height pull cutoff.
2. **Cannon catches a thrown, stunned body** (`cannon_field.gd`): Lidstack,
   Noon Weir.
3. **Wind horn blows** with the blaster's knobs (a shared knock helper out
   of `trap_wind.gd` `_blast`; drop the swimmer skip), plus a wake rule and
   a `yaw_arc` on its Rig: Vigil.
4. **Sluice carries enemies** (`trap_sluice.gd` `_sweep`/`_fling`); the
   body's full-width wall rays and a shove along its walk: Washing Rite.
5. **Flip**: a `throw_yaw` knob, an optional stunning knock, a toss on the
   dropping half: Tithe Wheel.
6. **Motor quirks found** (Benchfall): on a physics ramp steeper than ~27°
   the uphill probe in `pilot_physics_ground.gd` skips it, so no auto-surf;
   `PilotMotor._careful` counts any pace as careful with the stick
   released, so he hangs at a lip after a surf.
7. Smaller: a vent piece with a grate mode; `swing_rope.gd` taking a
   tumbling body; the headless body joining the slam group.

## Notes

- K1 reported its file was reformatted between its first write and its
  revision by something other than its own edits (plainer prose and
  bullets). Content looked intact; worth knowing if a hook or another
  session touches docs/.
- Agents used different family names (makers, maker, works, growth); settle
  on one when the first piece is built.
