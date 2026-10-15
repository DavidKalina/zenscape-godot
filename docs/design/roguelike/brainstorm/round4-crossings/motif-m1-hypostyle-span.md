# The Hypostyle Span — "They roofed the road so the procession would never see the gulf. The gulf came in anyway."
Lenses: LITERAL (the Sundered Hall as the user said it) · time a crossing / chase · colossal · half-collapsed · shape: a line, two shores · twist: the threat is the only company on the way across
Slug: `hypostyle_span`

Pitch: You come out of the haze onto a cliff shelf and the far isle is a smudge
of lamp-smoke a long way off. Between you runs one thing, a colonnade the
length of a town, its pillars marching out over nothing, the roof half gone,
and on the roof, small and still against the haze, the Olmec bodies are
sitting. You will cross under them, between them, or over them.

Place: Two isles at the ends of a gulf that is the subject: the span is
`SPAN_BAYS` 14 bays of `city_hall`'s bay (BAY 1.5 CELL, 6.6 m), about 90 m
end to end, with no ground under it at all: the haze, then black. **The near
shore** (arrival) is a turf shelf cut square into a basalt cliff, the hall's
first bay standing on a stepped foundation off its edge like a wharf: two
ranks of square pillars (PILLAR 0.5 CELL, 2.2 m), a raised nave between them
(the Olmec's lane, 8.8 m, NAVE_CLEAR over it) and a narrow aisle outside each
rank, 1.8 m, under the aisle roof. **The far shore** is the same shelf
mirrored but higher: the hall climbs a quarter-degree of grade toward it
(a rise of three or four set-offs over the whole length), so the far end is
seen slightly from below, like a procession approach. **Stone** is the city's
weathered basalt, glyph-grooved on the pillar faces that look in at the nave,
rain-streaked on the faces that look out; lichen on the weather side; ropes
of root hanging from the fallen ends of the architraves into the void. **How
it broke:** unevenly, not in a rhythm. The roof is whole for the first two
bays (a tunnel mouth that frames the view), then a run of bare architraves
with the roof slabs gone, then a collapsed stretch about a third of the way
along where whole roof slabs lie across the nave as a wall of rubble (the
aisles open behind it), then a long open stretch of pillars only, the
architrave beams broken to stubs, then the roof again for the last three bays,
dark inside, with the far lamp at the mouth. At two places a rank of pillars
has leaned out and stands against nothing, one pillar short of the next. **The
view on arrival:** from the shelf's lip, low and central: the hall's near
mouth in the foreground, the whole length receding with the broken roofline
like a snaggle of teeth, the far lamp (`maker_cresset`) a pinprick, three or
four small dark shapes on the architraves between. Wind in the gulf, the
colonnade humming.

Top (1 char ≈ 4 m; north up; arrival at the bottom) and Side:
```
        1 far shore (lit cresset @)
       [@]
        ######  roofed last 3 bays
        #""##
        ##  ##     <- open pillars, stubs
        #P  P#
        ##  ##
        ### o#     o a body climbing the outer face
        #CCCC#     rubble across the nave (roof slabs)
        ## ~ ##
        #P  o#     P perch on architrave
        #""##
        ######  roofed first 2 bays
       [  0  ]
        arrival

Side (looking along the span, east; 1 char ≈ 4 m wide, 3 m high):
 far shore                                                   near shore
  ___                                                          ____
 |   |  __|_|_|_|_|__  ___|_|_|_|_|___|_|_|_|_|___   __|_|_|_|_|__ |    |
 |   |==|P|  |  |P|==|    |  |  |  |  |    |  |  |==|  |  |P|  |==|    |
 | 1 |  | |  |  | |  |    |  |  |  |  |    |  |  |  |  |  | |  |  | 0  |
 |___|  ~  ~  ~  ~  ~  ~  ~  ~  ~  ~  ~  ~  ~  ~  ~  ~  ~  ~  ~  |____|
       (nothing under any of it; the haze, then dark)
```

Play: the hall has three levels and each is a way across. The nave is the
Olmec's road and the wide fast way; the aisles are a slot the wanderer fits
and the Olmec does not; the roof is the platforming.

1. **The nave dash (fast, loud, exposed).** Sprint the raised nave down the
   middle. It is flat, wide and straight, the quickest way across: ~90 m at
   RUN pace is a short time, but every perched body on the architraves has the
   whole nave in sight. The pounces come down from `pounce_min`-`pounce_max`
   (1.6-4.5 head heights) of the nave edge, so the nave's *edge* is the
   dangerous strip; the *middle* of an 8.8 m lane is the farthest from both
   rows. Slide under a pounce's landing shock (`pounce_shock`), keep your pace,
   do not stop to turn. The rubble wall across the nave breaks the line:
   vault it (the rubble is a step-up and a long-jump lip), or break stride and
   take an aisle.
2. **The aisle crawl (quiet, slow, tight).** Between the outer pillars and
   the aisle wall, a 1.8 m slot behind the walker-only screens (`WalkerOnly`
   layer, as `city_hall`'s side aisles already do): out of the Olmec's sight
   and path, so a body on the nave cannot hit you, but you are seen from the
   roof only through the gaps between pillars, and the climbers coming up the
   outer faces arrive *at* the aisle. Every bay a pillar's inner face steps
   out; crouch-slide under the low architrave sags; the kick chimney where a
   slab has slid (inner and outer pillar facing across the aisle) lifts you
   to the aisle roof.
3. **The roof run (skill, the viaduct's cousin).** Wall-kick up a pillar's
   inner face to an architrave top, then run the beam: an architrave is a
   narrow lip (a hand-width less than a pillar's face) a bay long. Where the
   roof slabs are gone the beams are all there is; where a beam is down, the
   gap is the previous crossing's number: a **fallen architrave** with a gap
   of one bay's span (6.6 m, inside a plain running long jump, 7.6 m/s) with
   a 0.5 m drop is a plain-jump; two missing beams in a row (13.2 m, past
   even a chain of three, 10.4 m/s) are not a jump but a descent to the aisle
   or a lean pillar to wall-run across. The roof is the only place you see the
   whole span, and the only place everything sees you.
4. **The choice.** The nave is the speed, the aisles are the hide, the roof
   is the view and the skill. Each bay changes who owns it: a bay with a
   bored body perched over the nave makes the aisle the answer; a bay where a
   body is climbing the outer face of the aisle makes the nave the answer; a
   bay with both is the roof's. You will switch levels at least twice. The
   rubble pile at bay 5 and the lean-out pillars at bays 8 and 11 are the
   *places* levels join (walk up the rubble to the roof, kick up a leaning
   pillar to the roof, drop through the architrave gap to the aisle).

Threat: **The bodies are the hall's congregation.** Three working kinds, all
the existing headless body (`scripts/enemies/headless_body.gd`) on its
existing verbs, only placed to the hall's geometry:
- **Climbers** (`climb`, `climb_max` 20 units): spawned off the bottom of the
  pillars' outer faces *out of the haze* (the `cling` knob: a body set down
  on a cliff face, climbing, out of sight). They come up the outer face hand
  over hand and mantle over the pillar's capital onto the architrave; you see
  a stone hand come over the edge of the aisle roof before the shoulders. The
  stone is the same stone as the pillar: the first hand reads as a chip, then
  a finger.
- **Perchers** (placement plus the existing `pounce`; `perch` is not a body verb, so "perched" means a body set down seated on an
  architrave, a spawn mode, see Kit asks) above the nave, still, head-stump down, that wakes on hearing
  (noise-stealth-round1) and hunts by sound; when you are within
  `pounce_min`-`pounce_max` it winds up (`pounce_windup` 0.8 s, aimed to
  `pounce_lock`) and drops, a ballistic arc, a shock on landing (`pounce_shock`),
  a catch if you stay in `pounce_hit`. After a pounce it rests (`pounce_rest`
  3 s) and cannot go back up quickly: it must walk to a pillar and climb.
- **Walkers** on the nave like the existing city bodies: slow, heavy, lured
  by noise.
Every danger is a tool: a perched body that pounces and misses lands on the
nave at its own weight, and its landing shock (`_shock`) stuns or knocks
anything near; the climbing body *is* a staircase (stand where it mantles,
and the pillar it came up is now one it has left a handhold on); a body that
leaps across a fallen architrave is the proof the gap is jumpable. The roof
slabs are `breaks`: step on the overhang, and a body's pounce landing drops
the slab (see Could combo).

Could combo: a pounce lands on a roof slab already weakened by a climber's
mantle, and the slab and the body both go down through the aisle roof onto
whoever was crouching there (knock, stun, 1.2 s restun gap holds); the
perched body above a bay drops and misses, its landing shock `knock`s a
climber's hand off the lip, and the climber falls past you. The wanderer, thrown
(`knock`) from the nave by a landing, may fly across the aisle onto the
outer pillar's face and wall-kick up to the roof instead of falling: a
shortcut a skilled player can choose. **Ports:** catches a body thrown from
either shore's cliff (it lands on the first bay's nave); throws bodies out
the sides into the void (the death), and out of the far mouth onto the far
shore, tumbling.

Mystery: A procession road. The pillars' inner faces carry the same glyph
band all the way (a count of something: sixteen steps, sixteen days), and
stop at bay 11, where the pillar is blank and a ledge is cut at head height,
holding an offering bowl the size of a man's torso, empty. The far shore's
lamp is the only maintained thing in the city. Why the Olmec bodies sit on the
roof rather than walk the road is for the player to guess; they look at the
far lamp, not at you, until they hear you.

Kit used (verified in code):
- `city_hall` (scripts/city_kit_landmarks.gd `hall()`): the unit; its
  pillars, nave, aisles, walker-only screens, kick chimney, crack and fallen
  slab are the span's bay. The span is 14 bays of it, or a new long variant.
- `city_causeway` (scripts/city_kit.gd `causeway()`): the shore wharf, the
  approach, and the optional "bay" that drops in four slabs.
- `city_pillar`, `maker_corbel`, `maker_chock` (city_kit_breaks2.gd): the
  leaning pillars and the chocked slabs.
- `city_riser`, `city_lip`, `city_wrap` (city_kit_climb.gd): the shore-side
  steps up to the hall and the exit.
- `city_mouserun`, `city_slotwall`, `city_niches` (city_kit_refuges.gd): the
  aisle's hides.
- `maker_cresset` (city_kit_fires.gd): the far lamp, and a pair at the
  near mouth, unlit.
- `WalkerOnly` (scripts/walker_only.gd), `KitLand.island` for the shores.
- Enemies: `headless_body` (`climb`, `leap`, `pounce`, `cling` already).

Kit asks:
- `city_hall_long` (or `opts.bays` on `city_hall`): one hall of N bays with
  per-bay roof state (whole / slabs gone / beams down / pillars only), so the
  span is data, not a copy of the sundered hall.
- `city_architrave` (city kit): a walkable beam piece a bay long (a "lip"
  roughly a hand narrower than a pillar), walkable top, the roof run's
  platform. If the hall's roof slab cannot be made to walk as a beam.
- A body spawner mode "perched" (a body placed seated on an architrave,
  dormant until it hears) and "climb up from haze" at the pillar foot: both
  are placement (the body already pounces and `cling`s); the dormant seated
  start is new but small, the AI is not.

Family knobs:
- `bays` 10-18 (the gulf's width; a short span reads as a bridge, a long one
  as a journey), values in multiples of BAY.
- `roof` pattern seed: which bays are whole, slabs-gone, beams-down,
  pillars-only (always whole for the first and last two).
- `grade` 0-4 set-offs of rise over the length (flat to uphill).
- `congregation` 4-9 bodies and the mix of perchers : climbers : walkers.
- `lean` 0-3 leaning pillars (the stand-alone pillars against nothing).

Sockets: rims at both ends (arrival south on the near shelf's lip, out north
on the far shelf); arena: the open stretch of pillars in the middle (bays
6-9) as the fight's centre; cover: the rubble wall, the aisle screens, the
pillar bases; perches: every architrave, with the best at bays 3, 8 and 12.

Generator fit: a **motif with its own two shores**, role a crossing/
through-isle; footprint about 14 bays x (nave 8.8 + 2 pillar ranks 2.2 + 2
aisles 1.8) = ~92 m x 25 m plus a shelf at each end (~30 m x 40 m); height span: 6-10 m
across the whole length (the roof 12-15 m over the nave), rim in at the
near shelf and rim out at the far shelf, a few set-offs higher. Suits the
layer's *line* shape: put it between two places the generator keeps far
apart, and replace the plain column-top stones of the `city_crossings.gd`
edge between them with this when the pair is further apart than a causeway
beam reaches (or beyond the plan's single-bridge cap).

Distinct from: **serpent_crossing** (a void crossed by a ride on a moving
serpent; no stone spans it) and **felled_colonnade** (a gap crossed by
toppling a column; ruined at the edge, not a span the length of the gulf).
The Hypostyle Span is the one where the stone does span, and the crossing is
walked, not ridden or built. It is also not **`city_hall`** as a landmark
(a hall on an isle, 3 bays, a crack across it): this is that hall's
lengthening into a bridge, with the crack multiplied.
