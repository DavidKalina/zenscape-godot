# The Pancaked Hall — "Nine floors, and the ledger has lost count of which one you are on."
Lenses: verb fall/descend · shape a tall stack, a hanging underside · decay half-collapsed mid-fall · scale colossal · mood oppressive, quiet between the drops
Pitch: Two isles sit 70 m apart in the air and the only way between them is down through the hall that fell: a nine-storey maker hall that dropped its floors one on another, caught at a slant, so that the far side is reached by dropping storey by storey through the wreck. Olmecs stand on the lips of the floors above you and step off.

Place: A city block's great hall, originally a tall stack of floors held on one colossal pillar-and-lintel frame (the `colossus_drum` family on a core). The frame gave way on one side; the floors slid and pancaked against the opposite wall, each caught on the one beneath at a different angle, so the hall is now a heap of slanted slabs hung in a stairwell of void, a hall seen from its side with its face torn off. You arrive at the roof level on the high isle, looking down into it as into a split pomegranate: slab edges stacked and fanning, the standing frame on the left (still ornamented, pillars carved with runes, a stair that goes nowhere), the fallen floors falling away to the right like a scree of stone cards. Their edges are not all straight: some have buckled, some are broken as a diagonal, some have a corbel course caught on the slab below. The low isle is a plaza at the heap's foot, with one lit cresset, tiny. The air is full of dust motes lit from the cressets on each floor's tilted face; all warm light is on the tilted undersides, and the haze thickens with depth. It must read as a heavy authored collapse by two rules: every floor is a different tilt (4 to 14 degrees) and rests on a visible contact point on the floor below (a corbel, a stump, a dropped drum), and the standing frame has the rest of the story (a lintel cracked above a column that stands, a column with no lintel, a floor still hung on one side by a lintel).
Top (1 char ≈ 4 m):
```
 ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
 ~~[1]####====~~~~~~~~~~~~~~~~~~~~
 ~~~~~####====>>>~~~~~~~~~~~~~~~~~
 ~~~~~####====>>>>>~~~~~~~~~~~~~~~
 ~~~~~####o===>>>>>>>=====~~~~~~~~
 ~~~~~####====~~~~~~~~~~~~~~~[2]~~
 #: standing frame  =: floor slab  >: slumped floors  o: Olmec perch
```
Side (the heap in cross-section, 70 m):
```
  [1] roof  ####_________
  fl 1      ##||_____.\___
  fl 2      ##||    \_____\__          lip, 5 m drop
  fl 3      ##||        \_o___\_       Olmec
  fl 4      ##||            \_____\_
  fl 5      ##||(cracked lintel)\____\_
  fl 6      ##||                  \____\_
  fl 7      ##||                       \___\__
  fl 8      ##|| (hollow below)             \___[2] plaza
```
Play:
- Route A, the stair of slabs (about 90 s). From the roof you step onto floor 1, run down its tilt (slide it, 3 to 5 m a floor), and drop off the lip onto floor 2 which lies the other way: each floor is a switchback, the slabs alternate tilt, so you cross the hall zigzag. Between floors a drop of 4 to 5.5 m (under the 6 m stun). The tilts give the pilot a slide the whole way: the descent is a flow, not a ladder. The hard bits are floors that have buckled with a ridge to hop and a 1 m crack to cross.
- Route B, the standing frame. The intact side's pillars (`city_riser`-like wall faces) take wall kicks up and across: a wall-kick chimney between a pillar and the slab edge, the ledge chain of the frame's carved bands (1.6 m, SET_OFF). Slower, safe from the Olmec drops, but it commits you to the open side where a pilot can be knocked off into 25 m of air with no slab under.
- Route C, the cut: a flow-charge slam on a lip with a heavy rubble (a dropped drum) breaks through a cracked slab (the `city_chock` model) to drop two floors in one move, into the hollow between 4 and 5. Fast, lands you in the dark, in the Olmecs' blind part.
- Mirror, the long climb home: the way back up the heap is the Olmec's own stairwell (the standing frame's stair, `city_stair` 6.6 m wide, broken at the fifth landing into a 5 m lip you must jump-and-grab).
Threat: Headless bodies on the floors above that step off the lips onto you. Every floor above you is an Olmec's perch and the place is vertical: they track you by hearing (the dust and shocks carry), come to the lip over your head and jump down (4 to 5 m is the leap he takes by design). His landing slams the floor (shock), which loosens the next lip: a slab that has been stood on twice can slip, dropping the floor a storey further in the dust (the breakable model of `maker_chock`: shock trigger, precast pieces, rubble landing on the level below). The place is a clock: the heap settles as the Olmecs come down, so the way back up the slabs gets shorter and the way down gets steeper. His own fall is also a tool: an Olmec that lands on a cracked slab goes through it.
Could combo: A pilot knocked by a landing Olmec off a lip falls onto the next floor's tilt and slides into the next Olmec's lunge; a drop onto a floor with a wind blaster at its lip (the blaster is in the exist list) can be pushed across the void onto the standing frame's ledge. An inhaler head floating in the stairwell sees the whole hall and its pull on a pilot sailing from floor 3 to floor 6 turns an escape into a capture: the head is the one threat that works in the middle air. Ports: catches a body thrown from a neighbouring isle's cannon onto the roof; throws onto the plaza (the last slab ends in a ramp that tosses a sliding body 4 m onto the plaza's grit).
Mystery: The frame did not fail by age: the lintels on the standing side are cut through with a clean line, the way the makers cut a stone to remove it, and the floors' undersides carry a ring of worn grooves where something was chained. They were not held up. They were held down. The hall was kept shut, and the top floor's door, the one you enter by, is the only one bolted from the outside.
Kit used: `colossus_drum` and `maker_felled` (scripts/city_kit_breaks.gd), `maker_chock`, `maker_corbel`, `colossus_plug` (scripts/city_kit_breaks2.gd), `city_hall` (scripts/city_kit_landmarks.gd; the hall's standing frame, if it can be cut away), `city_stair` and `city_pillar` (scripts/city_kit.gd), `city_riser` and `city_terrace` (scripts/city_kit_climb.gd; wall faces, the shelf ledges).
Kit asks:
- `city_floor_slab`: a thick tilted slab with a rubble-contact point on its low side and a rune-banded lip, tilt a parameter (4 to 14 degrees), a buckle variant. The core of the card: a floor that reads as a floor, not a plate (a joist course under it, a cracked edge).
- `city_hall_cutaway`: the half-standing frame with an exposed storey height, torn face and a sheared stair (can start as `city_hall` with a boolean cut).
- A "settle" state on the slab that shifts one storey on a shock (reuses the break model).
Family knobs: `storeys` (6 to 10, so 30 to 55 m of descent), `tilt` (how steep each floor, steeper = more slide), `frame` (how much of the standing frame survives, more = Route B easier), `hosts` (Olmecs on the floors, 1 to 3).
Sockets: rims at the roof (the near shore, facing out) and the plaza (the far shore, facing up), arenas at the middle floors' flat low sides (10 by 10 m), cover in the hollow below the cracked slab and behind the frame's pillars, perches on each floor's lip.
Generator fit: a motif with its own two shores, tall (70 m drop, 40 m across); it suits a tall stack, replaced as a whole place at a downward edge of the city layer; the near shore needs the high isle's rim. It works as a crossing between two places only if the generator can give it 70 m of vertical room; otherwise run it at 45 m with fewer storeys.
Distinct from: `stacked_court` (stacked, intact courts that you climb) and `hollow_keel` (a hall hung under a plate): here the stack is the collapse itself, and the verb is down, with a threat that falls with you. Not `plumb_well` (crossed out, a scripted combo sequence): nothing here is a line the geometry draws, the Olmecs and the slides simply meet.
