extends "res://studies/crag_reach.gd"
## The heist level (docs/design/heist-level/spec-heist-level.md): a
## standalone greybox place built on the crag reach's code (its crag units,
## bridges, pillars, ruins, Olmec and greed run), with its own land. West
## to east, about 300 m: the landing mass with the parked plane; the way in
## along the north side (a terrace to rappel down to, a ledge, a gate mass
## to climb, a spur); the vault, a sunken court ringed by three higher rims; the
## way out along the south side (a rim to throw the bag up, a swing round
## vault_s's south-west corner on an arm out of a rock spire onto vault_sw,
## a fallen pillar from there to slide down to the south mass, the ford mass, a chain of two swings
## over stack_1 to stack_2, a rope bridge home to landing_s that snaps
## behind him once the isle is awake, a ramp up onto the landing).
## Every piece is named `heist/<name>` (scripts/layout_overrides.gd,
## layouts/heist.json), moved in the world view (F4) by that name.
##   godot --path . res://studies/heist_level.tscn -- --no-title
## The season is held at summer (never winter here) unless --season= asks.
## The run starts at home (studies/heist_home.gd): a landmass far out in
## the same sky, the heist isle hidden from it in the haze; the loot is
## banked by landing it home (`greed_banked`). Its flags: --home-far=,
## --hunt-seed=, --haze=, --no-haze, --cue-far=; --no-home the heist alone
## (the run starts on its landing, banked by flying clear).

## The masses: [name, the top unit's middle (x, height off TOP, z), its
## spec, its parts [part, offset (x, dy, z), spec]] (crag_reach.gd MASSES).
## No grass: greybox turf and rock.
const HEIST_MASSES := [
	["landing",Vector3(0.0,0.0,0.0),{"seed":41,"size":34.0,"shape":0.62,"flat":0.95,"landmark":0,"growth":0.72,"weather":0.5,"lopsided":0.6},[
		["terrace_n",Vector3(23.0,-11.0,-29.0),{"seed":42,"size":12.0,"shape":0.3,"flat":0.6}],
	]],
	["ledge",Vector3(59.0,-9.0,-48.0),{"seed":81,"size":20.0,"shape":0.4,"flat":0.7,"landmark":0},[]],
	["gate",Vector3(92.0,1.0,-42.0),{"seed":82,"size":20.0,"shape":0.55,"flat":0.6,"landmark":0},[]],
	["spur",Vector3(143.0,-3.0,-37.0),{"seed":83,"size":28.0,"shape":0.5,"flat":0.7,"landmark":0},[]],
	["vault_court",Vector3(190.0,-6.0,2.0),{"seed":91,"size":20.0,"shape":0.2,"flat":0.95,"landmark":0},[]],
	["vault_n",Vector3(185.0,4.0,-28.0),{"seed":92,"size":14.0,"shape":0.6,"flat":0.6,"landmark":0},[]],
	["vault_e",Vector3(222.0,6.0,4.0),{"seed":93,"size":15.0,"shape":0.7,"flat":0.6,"landmark":0},[]],
	["vault_s",Vector3(186.0,4.0,34.0),{"seed":94,"size":14.0,"shape":0.5,"flat":0.6,"landmark":0},[]],
	# Round the corner: off vault_s's south-west corner a rock spire (too
	# tall to climb) with an arm out of it (swing_02) over the gap to
	# vault_sw, a lower terrace tucked round the corner, where the pillar
	# down to south starts.
	["vault_sw",Vector3(164.5,1.5,57.5),{"seed":100,"size":9.0,"shape":0.4,"flat":0.8,"landmark":0},[]],
	["vault_spire",Vector3(176.2,13.0,54.2),{"seed":101,"size":4.0,"shape":0.5,"flat":0.6,"landmark":0},[]],
	["south",Vector3(125.0,-10.0,64.0),{"seed":95,"size":20.0,"shape":0.45,"flat":0.7,"landmark":0},[]],
	["ford",Vector3(82.0,-8.8,52.0),{"seed":96,"size":16.0,"shape":0.5,"flat":0.7,"landmark":0},[]],
	# The chain's stacks (the way home): ford -> stack_1 -> stack_2, each
	# crown a little under the last (21.9, 21.2, 20.9), so each swing (swing_05,
	# swing_06) lands level or down.
	["stack_1",Vector3(55.0,-9.0,42.0),{"seed":97,"size":7.0,"shape":0.4,"flat":0.8,"landmark":0},[]],
	["stack_2",Vector3(39.5,-9.2,30.0),{"seed":98,"size":9.0,"shape":0.4,"flat":0.8,"landmark":0},[]],
	# The bridge home's far end: a terrace off the landing's south face,
	# its crown 6 m under the landing's, a stone ramp (home_ramp) up from it.
	["landing_s",Vector3(14.0,-6.2,56.0),{"seed":99,"size":8.0,"shape":0.4,"flat":0.8,"landmark":0},[]],
]
const HEIST_BASE := {"grass":0.0}

## The way out's fallen pillar (crag_reach.gd PILLARS rows: name, from the
## high mass, to the low, seed): a colossus column lying from vault_sw's
## crown rim (round the corner from vault_s) down onto south's crown, one long slope to boot-surf with the
## bag on (crouch at a run).
const HEIST_PILLARS := [
	["pillar_out","vault_sw","south",211],
]

## The vault's marks (crag_reach.gd RUINS rows): a ring of stones round the
## court's middle with the treasure's chest in it, a colonnade along the
## north rim and a tower shell on the east rim, so the vault reads from the
## landing as the goal.
const HEIST_RUINS := [
	["vault_ring","vault_court",Vector2(0.0,0.0),"stone_circle",0.0,301,0.4,{}],
	["vault_chest","vault_court",Vector2(0.0,0.0),"tomb_chest",90.0,302,0.3,{}],
	["vault_colonnade","vault_n",Vector2(0.0,2.0),"colonnade",0.0,303,0.4,{"count":4,"step":6.0}],
	["vault_tower","vault_e",Vector2(2.0,0.0),"tower_shell",270.0,304,0.4,{}],
]

## The way in (task 2), along the north side, calm: the rope's three
## moves. From the landing crown a post (post_01) over terrace_n, 9 m down:
## rappel. terrace_n to the ledge, a 10 m gap under a rock arch (swing_01,
## 7 m over the terrace): swing. The ledge to the gate, an 11 m wall (wall_01),
## and the spur to vault_n, a 6 m face: hook the lip (any bare top is a solid hold,
## `rope_ground_hold`) and climb. The gate steps 4 m down onto the spur.
## From vault_n's rim a post (post_02) over the court, 10 m down: rappel
## in. Light loot on the way (loot_NN). Rows as crag_reach_greed.gd's: the
## loot [id, kind, kg, spot (world; its height aims the settle's ray), yaw
## deg, where]; the posts [id, foot, what it's over].
const HEIST_LOOT := [
	["loot_01","coins",2.0,Vector3(30.0,20.5,-34.0),20.0,"terrace_n, under the rappel"],
	["loot_02","chalice",1.5,Vector3(62.0,21.5,-50.0),80.0,"the ledge, past the swing"],
	["loot_03","gem",0.5,Vector3(96.0,31.5,-40.0),0.0,"the gate, over the face"],
	["loot_04","idol",3.0,Vector3(150.0,27.5,-36.0),200.0,"the spur, under vault_n"],
]
## The vault (task 4): the main treasure, a dragon egg on the tomb chest
## in the court's middle, and loot round it, heavier than the way in's.
## Kept apart from HEIST_LOOT so the greed marks (greed_marks) are the way
## in's sum: the vault's take wakes the isle. With the way in's 7 kg, the
## egg alone makes 15 kg: past the ledge bar (9), under HEIST_THROW_KG and
## the rope's bar (17). All of it is 25.5 kg, past the bag's 18 worn: he
## chooses.
const HEIST_VAULT_LOOT := [
	["treasure","egg",8.0,Vector3(190.0,26.5,2.0),90.0,"the court, on the tomb chest: the main treasure"],
	["loot_05","urn",6.0,Vector3(180.0,25.5,-3.0),300.0,"the court, west"],
	["loot_06","bar",4.0,Vector3(200.0,25.5,9.0),35.0,"the court, east by the ring"],
	["loot_07","gem",0.5,Vector3(190.5,30.5,16.5),0.0,"the stair's landing, on the way up"],
]
## The bag throws up to this (kg) here (loot_bag.gd `throw_kg`, THROW_KG 8
## elsewhere): a bag too heavy to climb a ledge with (9) still goes up one
## thrown, so the vault's ledges are thrown up, then climbed light.
const HEIST_THROW_KG := 16.0
## The wake (task 5): the burrows the brood come up out of, in the court
## round the chest (off the ring, the ramp and the steps) and on vault_s's
## crown, where the way out runs. Rows as crag_reach_greed.gd BURROWS: [id,
## mouth (world; its height aims the settle's ray), where]. The three
## nearest the bag deal the wake (WAKE_HOLES).
const HEIST_BURROWS := [
	["burrow_01",Vector3(177.0,25.0,9.0),"the court, west by the drop"],
	["burrow_02",Vector3(202.0,25.0,-5.0),"the court, north-east"],
	["burrow_03",Vector3(201.0,25.0,13.0),"the court, south-east"],
	["burrow_04",Vector3(184.0,34.5,31.0),"vault_s's crown, over the steps"],
	["burrow_05",Vector3(179.0,34.5,40.0),"vault_s's crown, west, the way out"],
]
## The Olmec's staged cliff (heist/olmec_up): the court's own west face,
## out over the drop, some 17 m from the chest, on the face of a stone
## block set against it (HEIST_WALLS olmec_wall). Its spot is the lip (the
## real one found by BodySpawner.fit), its z the way out of the face.
## He comes up it HEIST_OLMEC_DELAY s after the egg is bagged, in view.
const HEIST_OLMEC_UP := [Vector3(171.3,24.3,2.07),Vector2(-0.863,-0.505)]
const HEIST_OLMEC_DELAY := 3.0
var _olmec_up: Node3D = null
## The staged drop where you just were (heist/olmec_perch, heist/olmec_drop,
## tokens F4 moves): once the isle is awake, as he boot-surfs the pillar
## and comes within HEIST_DROP_CUE m (flat) of its foot, the Olmec, unless
## he's already down there near him, stands up on the perch (vault_sw's
## crown behind the pillar's top, out of view behind him; set there if he
## isn't) and throws himself off it (headless_body `stage_drop`), aimed at
## the pillar's foot, then, as his windup ends, beside him where the camera
## sees it (below). The cue: his time to the foot
## at his speed toward it under HEIST_DROP_LEAD s (his windup and flight,
## ~2.7 s, less the beat he lands after him), within HEIST_DROP_CUE m
## (flat), off the perch's crown. Boot-surfing that's ~13 m out, walking
## ~6. The perch's z the way it faces.
const HEIST_OLMEC_PERCH := [Vector3(161.5,31.7,58.0),Vector2(-0.987,0.162)]
const HEIST_OLMEC_DROP := Vector3(137.5,20.9,61.5)
const HEIST_DROP_CUE := 24.0
const HEIST_DROP_LEAD := 3.4
## Already on south this near him (m): no staging; he got there himself.
const HEIST_DROP_THERE := 15.0
## In view (main's `down_show`): the drop lands where the play camera will
## see his feet and shins as he comes down, aimed as his windup ends
## (`_aim_drop`): HEIST_DROP_FLIGHT s on (his flight), beside where he'll
## be (`_drop_spots`, HEIST_DROP_BAND), on the foot's floor (within
## HEIST_DROP_RISE m of its height); none there: the foot itself.
const HEIST_DROP_FLIGHT := 1.6
const HEIST_DROP_RISE := 2.5
## [back from, to, out from, to] (m) round where he'll be (back < 0:
## ahead). The play camera, some 7 m behind and 5 up him at a slide's speed
## and pitched well down, frames his feet and shins (`_lands_seen`,
## 1440x900) only from ~3 m behind him to ~2 ahead, out ~4 m at 2 m behind
## and ~6 at 2 ahead; a landing on top of him is no near miss (main's
## `down_show` keeps 5.5 m off). So the drop comes down beside him, about
## level, 4.5-6 m out. (He ends up ~1 m further on than foreseen.)
const HEIST_DROP_BAND := [-2.0,-1.0,4.5,6.0]
var drop_seen := false
## His landing wave there scaled by this (headless_body `staged_shock`):
## at full strength, 4.5 m off, it throws him 6-12 m off the way, bent
## toward the rim (void_push); a near miss rocks him and he runs on.
const HEIST_DROP_SHOCK := 0.3
## Aimed this long (s) before his windup ends (the pounce's lock).
const HEIST_DROP_AIM := 0.15
var _drop_body: Node3D = null
var _olmec_perch: Node3D = null
var _olmec_drop: Node3D = null
var _drop_armed := false
var _drop_done := false

## The swing out from under him (swing_03): once the drop's done, him on
## gap_near (within HEIST_SWING_NEAR m of its lip, on its side, on his
## feet) with the rope in hand or out at swing_03, the Olmec holds his
## pounce and suck (a pounce winding up checks) (he stalks on; a swat still
## catches) for up to HEIST_SWING_GRACE s all told: the throw, the
## hook's flight, the tug and the seat take 4-6 s, and a pounce in them
## lands on you. Past that, he's on you (stall = caught). The frame you
## swing off, he leaps for where you left (headless_body `stage_drop`,
## within HEIST_SWING_REACH m), its wave HEIST_SWING_SHOCK: his windup
## and flight (~2.5 s) bring him down on the lip as you come down on
## gap_far. Once a wake.
const HEIST_SWING_NEAR := 9.0
const HEIST_SWING_GRACE := 8.0
const HEIST_SWING_REACH := 30.0
const HEIST_SWING_SHOCK := 0.3
var _swing_hold_t := 0.0
var _swing_from := Vector3.INF
var _swing_done := false
## The chain's rigging holds (swing_05, swing_06), the same hold without the
## leap: once the drop's done, him on his feet within HEIST_RIG_NEAR m
## (flat) of the swing point, rope in hand or out at it, the Olmec holds
## his pounce and suck for up to HEIST_SWING_GRACE s at each. A rig takes
## 4-6 s standing (throw, the hook's flight, tug, seat); with him on ford
## behind you a pounce or suck always lands in it, so a player who keeps
## moving was caught at every throw. Past the grace (a stall), he comes.
const HEIST_RIGS := ["swing_05","swing_06"]
const HEIST_RIG_NEAR := 11.0
const HEIST_RIG_SHOCK := 20.0
var _rig_hold := {}

## The takeoff beat (heist/olmec_turf, a token F4 moves): the frame you
## board the plane with the isle awake, the Olmec, if he's on his feet
## within HEIST_TURF_REACH m of it, leaps (headless_body `stage_drop`)
## for the turf beside it, off the takeoff run, where the chase camera
## behind the plane sees him land as you taxi (tried for HEIST_TURF_WAIT s
## while he closes). Further back: no leap (he makes for the plane on
## foot, as flying always had him). Once a wake.
## One simple staged moment (spec: no chase tuning here).
const HEIST_OLMEC_TURF := Vector3(-6.0,30.4,-8.0)
const HEIST_TURF_REACH := 40.0
const HEIST_TURF_SHOCK := 0.3
var _olmec_turf: Node3D = null
var _turf_done := false
## Off his feet or out of reach as you board, the leap is tried each
## frame this long (s) while you taxi.
const HEIST_TURF_WAIT := 3.0
var _turf_t := 0.0

const HEIST_POSTS := [
	["post_01",Vector3(21.6,30.4,-26.9),"landing crown over terrace_n (rappel)"],
	["post_02",Vector3(187.0,34.6,-15.6),"vault_n rim over the court (rappel in)"],
]
## The swing points (scripts/rope/swing_point.gd): shapes out of the rock
## that carry the rope's hook line. [id, kind, the line's top middle
## (world), along (x, z: the line runs across the swing), length, drop (how
## far its footing reaches under the line), what it's for]. swing_01 is the
## way in's (it was the gantry beam beam_01); the rest are first guesses
## where the way out will run (step 6 fits them to the land it builds).
## The chain's arches are rings (the optional 8th field: SwingPoint.build's
## `ring`): a throw anywhere along one hooks its middle, so a throw on the
## move, or one his suck's wind drags along the arch, swings the same way
## every time. Hooked 1.3 m off the middle, swing_05 carried you past
## stack_1; hooked 1 m off toward stack_2, swing_06 struck its rim face or
## set you on its north-east tip. From the middle each swing heads for the
## stack's middle.
const HEIST_RING := true
const HEIST_SWINGS := [
	["swing_01","arch",Vector3(38.5,27.5,-37.2),Vector2(0.467,0.884),10.0,24.0,"a rock arch over the gap terrace_n -> ledge (the way in)"],
	["swing_02","arm",Vector3(171.0,41.3,49.0),Vector2(-0.707,-0.707),5.5,6.0,"an arm out of vault_spire over the gap off vault_s's south-west corner: swing round the corner onto vault_sw"],
	# The swing out from under him: a broken lintel standing on gap_far's
	# north corner by its lip, sticking out south over the gap's side, its
	# line over gap_far's lip, 10.7 m over its top: run off gap_near's lip
	# on its south half and the swing dips over the far lip (gap_far lies
	# HEIST_GAP_DROP under the near, so his feet clear it) and sets him
	# down on gap_far by gap_ramp's foot, bag and all. (Ford's rim rock
	# covers gap_far's north half west of x 99.5 at 21.9: a heavy bag's
	# ledge, so the swing and the ramp keep south of it.)
	["swing_03","lintel",Vector3(102.4,30.0,59.6),Vector2(0.0,1.0),6.0,10.7,"a broken lintel on gap_far by its lip, out over the gap south -> ford (its south side): the swing out from under the Olmec"],
	["swing_04","branch",Vector3(98.2,28.9,47.0),Vector2(0.6,0.8),7.0,7.0,"a dead tree on ford's east rim, its branch over the gap south -> ford (spare: not on the route now)"],
	# The chain (the way home): two rock rings out of the clouds, one over
	# each gap ford -> stack_1 -> stack_2, each line 7 m over the far crown
	# across the way. Each swing lands on a stack before the next throw.
	["swing_05","arch",Vector3(64.5,28.6,45.0),Vector2(0.0,1.0),9.0,22.0,"a rock arch over the gap ford -> stack_1: the chain's first",HEIST_RING],
	["swing_06","arch",Vector3(48.0,28.2,36.6),Vector2(0.613,-0.79),8.0,18.0,"a rock arch over the gap stack_1 -> stack_2: the chain's second",HEIST_RING],
]
## The way out of the court, built for the bag: a ramp of stone up from the
## court floor along vault_s's north foot to a landing, then three ledges
## up to vault_s's crown, each a SET_OFF (RuinKit, the walker's catch with
## a margin) above the last. With 9 kg or under he climbs them with the bag
## on; heavier, he throws it up each ledge, climbs after it and shoulders
## it again; past HEIST_THROW_KG, the rope up vault_s's face. Ramp rows: [id,
## the low end's top middle, the high end's top middle, width, thickness].
## Step rows: [id, middle (x, z), depth (z), rises over the landing (0 the
## landing itself)]; each a stone block down to STEP_FOOT, its face looking
## north, the top the crown (HEIST_CROWN_S) less its rises to go.
## A high end's height 0.0 is the vault's landing (`step_top`).
const HEIST_RAMPS := [
	["vault_ramp",Vector3(176.0,24.3,17.25),Vector3(188.0,0.0,17.25),4.5,1.0],
	# The way home's last climb: from landing_s's north rim up the landing's
	# south face onto its crown, 6 m up (any bag walks it).
	["home_ramp",Vector3(8.2,23.5,52.5),Vector3(5.0,30.4,37.0),4.5,1.0],
	# Off gap_far's back half up onto ford's crown, 2.6 m up, on its south
	# strip (ford's rim rock covers the north half).
	["gap_ramp",Vector3(100.5,19.3,60.2),Vector3(95.0,21.6,60.2),4.6,1.0],
]
const HEIST_STEPS := [
	["vault_landing",Vector2(190.5,17.25),4.5,0],
	["vault_step_01",Vector2(190.5,20.5),2.0,1],
	["vault_step_02",Vector2(190.5,22.5),2.0,2],
	["vault_step_03",Vector2(190.5,24.75),2.5,3],
]
const HEIST_CROWN_S := 34.5
## The rope bridge home (crag_reach.gd BRIDGES rows: name, from, to, seed):
## stack_2 -> landing_s, about 19 m, rising 3 m. It bears a load
## (scripts/bridge_load.gd): strained from HEIST_BRIDGE_STRAIN kg, so he
## (60) with a bag creaks it and a heavy one pops planks and frays it; it
## snaps past SNAP_KG (96) held. Once the isle is awake it is staged to go
## behind him: off its far end (past HEIST_SNAP_PAST of the way) onto
## landing_s, it parts at HEIST_SNAP_AT HEIST_SNAP_DELAY s later. Falling
## as it goes, he catches the hanging half (scripts/bridge_climb.gd).
const HEIST_BRIDGES := [
	["bridge_home","stack_2","landing_s",221],
]
const HEIST_BRIDGE_STRAIN := 62.0
const HEIST_SNAP_PAST := 0.8
const HEIST_SNAP_AT := 0.45
const HEIST_SNAP_DELAY := 0.35
var bridge_load: Node = null
var bridge_climb: RefCounted = null
## The staged snap: armed at the wake; his furthest way along the deck
## (0 at stack_2, 1 at landing_s) while on it; the countdown once off it.
var _snap_armed := false
var _deck_t := -1.0
var _snap_due := -1.0
## The way out's gap (heist/gap_near, heist/gap_far), south -> ford: two
## stone blocks, the near one lying on south's west rim out over the void,
## its lip (the top middle of its far face) HEIST_GAP_AT; then a gap of
## HEIST_GAP_JUMP (times the wanderer) along HEIST_GAP_WAY; the far one
## against ford's east rim, its top HEIST_GAP_DROP under the near one's
## (it was a SET_OFF over: no swing on swing_03 climbs that, a run-up and
## the release's pop gain under a metre, less with a heavy bag, and the
## swing dips under the lip at the plumb), a stone ramp (gap_ramp) up from
## it onto ford's crown. Light he runs and jumps it; heavier the heavy bag
## cuts his jump and pace: he throws the bag across and jumps after it,
## or swings over on swing_03 with it on. Rows: [id, length along the
## way, width, which (0 near, 1 far)].
const HEIST_GAP_AT := Vector3(106.0,20.3,58.0)
const HEIST_GAP_WAY := Vector2(-1.0,0.0)
const HEIST_GAP_JUMP := 3.0
## The far block's top under the near one's (m).
const HEIST_GAP_DROP := 1.0
const HEIST_GAP_BLOCKS := [
	["gap_near",9.0,5.0,0],
	["gap_far",6.0,9.0,1],
]
const GAP_DEPTH := 12.0
const STEP_WIDTH := 5.0
const STEP_FOOT := 20.0
## The climbing walls: [id, middle of its top (world), out (x, z: the way
## its climbed face looks), width, depth, height]. A plain stone block
## standing on the lower mass with its top flush with the higher crown:
## a crag unit's face is undercut under its crown's lip, so a rope hung
## from it swings in under the overhang and he finds his feet on the slope
## below before the lip (the gate's did). The block gives a sheer face.
const HEIST_WALLS := [
	["wall_01",Vector3(71.8,33.0,-45.7),Vector2(-0.984,-0.179),8.0,4.0,14.0],
	# The Olmec's staged cliff (heist/olmec_up): the court's west face is
	# a floating unit's, undercut down its keel; he hung on it and walked
	# in under the court. The block gives him a sheer 18 m face to climb.
	["olmec_wall",Vector3(172.6,24.3,2.83),Vector2(-0.863,-0.505),8.0,4.0,18.0],
]

func greed_root() -> String:
	return "heist"

func greed_loot() -> Array:
	return HEIST_LOOT+HEIST_VAULT_LOOT

func greed_posts() -> Array:
	return HEIST_POSTS

func greed_burrows() -> Array:
	return HEIST_BURROWS

## The wake's trigger: bagging the main treasure wakes the brood and the
## Olmec at once (greed_meter.gd `wake_on`).
func greed_wake_on() -> Array:
	return ["treasure"]

## The meter's marks (brood, Olmec): one past everything but the main
## treasure, so only the treasure wakes the isle (`greed_wake_on`): the
## way in and the vault's other pieces add greed and darken the light,
## but stay calm. --greed-brood= / --greed-olmec= still win.
func greed_marks() -> Vector2i:
	var w := 0
	for row: Array in greed_loot():
		if str(row[0]) in greed_wake_on(): continue
		w += int(VaultHost.VALUES.get(str(row[1]),0))
	return Vector2i(w+1,w+1)

## The meter's marks: the brood wake at once (the crag's); the Olmec's
## grinding comes HEIST_OLMEC_DELAY s on, up his staged cliff
## (`olmec_cliff_pick`).
func greed_woke(what: String) -> void:
	super.greed_woke(what)
	_snap_armed = true
	if what == "olmec": _drop_armed = true
	if what == "olmec" and olmec_spawns == 0: _olmec_due = HEIST_OLMEC_DELAY

## His first entrance up the staged cliff (heist/olmec_up, fitted to the
## real face); after that (fallen, stuck, gone), the crag's pick.
func olmec_cliff_pick() -> Dictionary:
	if olmec_spawns > 0 or _olmec_up == null or not is_instance_valid(_olmec_up): return super.olmec_cliff_pick()
	var xf := _olmec_up.global_transform
	var way := Vector2(xf.basis.z.x,xf.basis.z.z).normalized()
	var fitted: Array = _spawner.fit(xf.origin,way)
	if fitted.is_empty():
		push_warning("heist: heist/olmec_up fits no face (%s); the crag's pick" % _spawner.fit_why)
		return super.olmec_cliff_pick()
	var lip: Vector3 = fitted[0]
	var out: Vector2 = fitted[1]
	var below: float = _spawner.face_below(lip,out,OLMEC_BELOW)
	var clean := _face_clean(get_world_3d().direct_space_state,lip,out,below)
	if not clean: push_warning("heist: heist/olmec_up's face isn't clean at %s: he may haul out under the lip" % lip)
	var d := Vector2(lip.x-motor.feet.x,lip.z-motor.feet.z).length()
	return {"lip":lip,"out":out,"crown":"olmec_up","seen":_spawner.in_view(lip),"far":d,"below":below,"clean":clean,"score":0.0}

## The heist's chase pace, over the crag's OLMEC_KNOBS (headless_body
## knobs), none yet: the run_up pace plays as the crag's. (suck_max 5.5
## was tried: his suck still starts at ~23 m, and it's the head's draw that
## trips a walker, so the tune is HEIST_HEAD_K.)
const HEIST_OLMEC_KNOBS := {}
## His head's worn draw, scaled (inhaler_head knobs x these). worn_pull_d0
## (unit x20): its pull P/(1+(d/d0)^2) tripped a walker inside ~0.86 d0
## (17 m), and planted 18-20 m behind a 15 kg walker (3.4 m/s) it drew him
## in and tripped him: keep moving was caught. x0.7: trips inside ~12 m,
## at 20 m a walker still gains ~1.4 m/s; a stalled one is drawn in.
const HEIST_HEAD_K := {"worn_pull_d0":0.7}

func tune_olmec(_b: Node3D, h: Node3D) -> void:
	for k: String in HEIST_HEAD_K:
		h.knobs[k] = float(h.knobs[k])*float(HEIST_HEAD_K[k])

## The end screen's name for the place.
func greed_place() -> String:
	return "the vault's isle"

func _ready() -> void:
	# The greed run's bag, rope and loot are always on here.
	greed_on = true
	if not LaunchArgs.user_args().has("--no-home"):
		home = HeistHome.new()
		home.read_flags()
		add_child(home)
	super._ready()
	# The haze that hides each isle from the other (HeistHome `apply_haze`).
	if home != null: home.apply_haze(_environment)
	# Never winter here: the year held at summer (the settings' Season row,
	# kit_weather.gd SEASON_CHOICES); a --season= flag keeps its own. Snapped:
	# gliding there from the date's season (autumn in October) walked the
	# plants through autumn's gold and winter for the first ~90 s.
	if weather != null: weather.choose_season(2,true)
	# The day turns at the settings' slow pace (1440 s, kit_weather.gd
	# DAY_SECONDS[1]): a whole heist (~6 min) is a few hours of light, not
	# dusk and night by the escape; a --day-length= flag keeps its own.
	if weather != null: weather.choose_day(1)
	# The chase's pace (HEIST_OLMEC_KNOBS) over OLMEC_KNOBS; a --body-knob= keeps its own.
	for k: String in HEIST_OLMEC_KNOBS:
		if not _body_knobs.has(k): _body_knobs[k] = HEIST_OLMEC_KNOBS[k]

func place_root() -> String:
	return "heist"

func bridge_list() -> Array:
	return HEIST_BRIDGES

func pillar_list() -> Array:
	return HEIST_PILLARS

func ruin_list() -> Array:
	return HEIST_RUINS

## The heist's own start, on its landing (--no-home's start; its plane's
## spot is the strip the ruins and loot keep off, `place_strip`).
const HEIST_START := Vector3(-6.0,TOP+1.5,4.0)

func _load_pack() -> void:
	super._load_pack()
	start = HEIST_START
	start_face = Vector2(1.0,0.0)
	_last_stood = start

# --- Home (studies/heist_home.gd) ----------------------------------------------

const HeistHome = preload("res://studies/heist_home.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const HeistSky = preload("res://studies/heist_level_sky.gd")
## Home, null with --no-home.
var home: Node3D = null
var _heist_strip := Vector4.INF

## Home's turf bodies, as the crag units' (`_stand`): the plane and the
## walker's turf.
func home_turf(body: StaticBody3D) -> void:
	body.collision_layer |= TURF_LAYER
	_turf_rids.append(body.get_rid())
	_turf.append(body)

## At home the plane stands parked at the end of home's strip.
func plane_home() -> Vector4:
	if home == null or home.land == null: return super.plane_home()
	if _home == Vector4.INF: _home = home.plane_spot()
	return _home

## The heist landing's own plane spot (found from HEIST_START as
## `plane_home` finds one), which its ruins, loot and burrows keep off
## wherever the run starts.
func place_strip() -> Vector4:
	if home == null: return plane_home()
	if _heist_strip != Vector4.INF: return _heist_strip
	var keep_start := start
	var keep_home := _home
	start = HEIST_START
	_home = Vector4.INF
	_heist_strip = super.plane_home()
	start = keep_start
	_home = keep_home
	return _heist_strip

## Home, as the sky's places (the clouds keep their towers off it and drift
## their puffs round it): [id, middle, reach].
func home_places() -> Array:
	if home == null or home.land == null: return []
	var c: Vector3 = home.circle
	return [["home",Vector3(c.x,TOP,c.y),c.z]]

func sky_script() -> Script:
	return HeistSky

## Banked when the loot is home (scripts/greed/greed_run.gd's hook): the
## plane stopped on home's turf, or him on his feet there, with loot in
## the bag (hitched or worn) or in the plane's keep. "" till then.
func greed_banked() -> String:
	if home == null or run == null: return ""
	var at := Vector3.INF
	if flying:
		if takeoff != null or hand_landing.flying() or not hand_landing.can_exit(): return ""
		at = plane.position
	elif motor.grounded and not off_edge:
		at = motor.feet
	if at == Vector3.INF or not home.over(at): return ""
	var aboard := not (run.keep as Array).is_empty()
	if bag != null and is_instance_valid(bag) and not bool(bag.buried) and str(bag.state) in ["hitched","worn"] and not (bag.items as Array).is_empty(): aboard = true
	return "You brought it home from %s." % greed_place() if aboard else ""

func isle_name() -> String:
	return "heist"

func capture_look() -> Vector3:
	return Vector3(190.0,TOP-8.0,2.0)

func isle_circle() -> Vector3:
	return Vector3(120.0,-20.0,700.0)

func _build_art() -> void:
	art = Node3D.new()
	art.name = "Art"
	add_child(art)
	Layout.begin("heist")
	var began := Time.get_ticks_msec()
	# Home first: the plane's spot (`plane_home`) is on its strip, and he
	# starts beside it.
	if home != null:
		home.build(self,TOP)
		if home.land != null:
			var st: Array = home.start_spot()
			start = st[0]
			start_face = st[1]
			_last_stood = start
	for m: Array in HEIST_MASSES:
		var mname: String = m[0]
		var mid: Vector3 = m[1]
		var top_at := Vector3(mid.x,TOP+mid.y,mid.z)
		var spec: Dictionary = MASS_BASE.merged(m[2],true).merged(HEIST_BASE,true)
		var n := _stand("heist/%s" % mname,Transform3D(Basis(),top_at),spec)
		if n != null:
			mass_tops[mname] = n
			named[mname] = n
		for part: Array in m[3]:
			var off: Vector3 = part[1]
			var ps: Dictionary = PART_BASE.merged(part[2],true).merged(HEIST_BASE,true)
			var turn := Basis(Vector3.UP,float(int(ps.seed)%7)*0.9)
			named["%s_%s" % [mname,part[0]]] = _stand("heist/%s_%s" % [mname,part[0]],Transform3D(turn,top_at+off),ps)
	_bridges()
	_load_bridge()
	_pillars()
	_ruins()
	var tris := 0
	for u: Node3D in units:
		tris += int((u.unit.get_meta("stats") as Dictionary).get("triangles",0))
	print("heist: %d units, %d triangles, built in %d ms" % [units.size(),tris,Time.get_ticks_msec()-began])

## The greed run, as the crag's (crag_reach_greed.gd `build_all`): the
## bag, the loot, the rope and its posts, the greed meter, the run's keep,
## clock, end screen and restart, the burrows and brood, the hands hint;
## then the swing points, the climbing walls, the court's way out and the
## Olmec's staged cliff.
func _add_life() -> void:
	Greed.build_all(self)
	if bag != null: bag.throw_kg = HEIST_THROW_KG
	_build_swings()
	_build_walls()
	_build_vault_way()
	_build_gap()
	_build_olmec_up()
	_build_olmec_drop()
	_build_hands_hint()
	# Past the haze, no land drawn (HeistHome `range_out`).
	if home != null:
		var ranged: int = home.range_out([art,home,get_node_or_null("Swings"),get_node_or_null("Walls"),get_node_or_null("VaultWay"),get_node_or_null("Gap"),get_node_or_null("Loot")])
		print("heist: %d meshes drawn to the haze's end" % ranged)

## The swing points, each named heist/<id>: a move or turn in the world
## view carries its hook line along.
func _build_swings() -> void:
	var holder := Node3D.new()
	holder.name = "Swings"
	add_child(holder)
	for row: Array in HEIST_SWINGS:
		var id := str(row[0])
		var called := "heist/%s" % id
		if Layout.deleted(called): continue
		var body := SwingPoint.build(str(row[1]),id,float(row[4]),float(row[5]),bool(row[7]) if row.size() > 7 else false)
		if body == null: continue
		var coded := SwingPoint.frame(row[2],row[3])
		body.transform = Layout.xform(called,coded)
		holder.add_child(body)
		Layout.track(called,body,"piece",coded)

func _build_walls() -> void:
	var holder := Node3D.new()
	holder.name = "Walls"
	add_child(holder)
	var stone := SwingPoint._mat(Color(0.55,0.52,0.47))
	for row: Array in HEIST_WALLS:
		var id := str(row[0])
		var called := "heist/%s" % id
		if Layout.deleted(called): continue
		var top: Vector3 = row[1]
		var out: Vector2 = (row[2] as Vector2).normalized()
		var size := Vector3(float(row[3]),float(row[5]),float(row[4]))
		# The body's z looks out of the climbed face; its origin the block's middle.
		var zb := Vector3(out.x,0.0,out.y)
		var coded := Transform3D(Basis(Vector3.UP.cross(zb),Vector3.UP,zb),top+Vector3.DOWN*size.y*0.5)
		var body := StaticBody3D.new()
		body.name = id
		body.transform = Layout.xform(called,coded)
		var box := BoxShape3D.new()
		box.size = size
		var col := CollisionShape3D.new()
		col.shape = box
		body.add_child(col)
		var drawn := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		drawn.mesh = bm
		drawn.material_override = stone
		body.add_child(drawn)
		holder.add_child(body)
		Layout.track(called,body,"piece",coded)

## The Olmec's staged cliff, a token named heist/olmec_up (F4 moves and
## turns it; its z the way out of the face).
func _build_olmec_up() -> void:
	var called := "heist/olmec_up"
	if Layout.deleted(called): return
	var out: Vector2 = (HEIST_OLMEC_UP[1] as Vector2).normalized()
	var zb := Vector3(out.x,0.0,out.y)
	var coded := Transform3D(Basis(Vector3.UP.cross(zb),Vector3.UP,zb),HEIST_OLMEC_UP[0])
	_olmec_up = Node3D.new()
	_olmec_up.name = "OlmecUp"
	_olmec_up.transform = Layout.xform(called,coded)
	add_child(_olmec_up)
	Layout.track(called,_olmec_up,"token",coded)

## The staged drop's two tokens: heist/olmec_perch (where he throws
## himself from; z the way he faces) and heist/olmec_drop (where he lands).
func _build_olmec_drop() -> void:
	var out: Vector2 = (HEIST_OLMEC_PERCH[1] as Vector2).normalized()
	var zb := Vector3(out.x,0.0,out.y)
	for row: Array in [["olmec_perch",Transform3D(Basis(Vector3.UP.cross(zb),Vector3.UP,zb),HEIST_OLMEC_PERCH[0])],
			["olmec_drop",Transform3D(Basis(),HEIST_OLMEC_DROP)],
			["olmec_turf",Transform3D(Basis(),HEIST_OLMEC_TURF)]]:
		var called := "heist/%s" % row[0]
		if Layout.deleted(called): continue
		var n := Node3D.new()
		n.name = str(row[0]).to_pascal_case()
		n.transform = Layout.xform(called,row[1])
		add_child(n)
		Layout.track(called,n,"token",row[1])
		if row[0] == "olmec_perch": _olmec_perch = n
		elif row[0] == "olmec_turf": _olmec_turf = n
		else: _olmec_drop = n

## The staged drop (HEIST_OLMEC_PERCH): cued by him coming down the pillar
## toward its foot, once a wake.
func _stage_drop() -> void:
	if not _drop_armed or _drop_done or enemies == null or _olmec_perch == null or _olmec_drop == null: return
	var to := _olmec_drop.global_position
	var perch := _olmec_perch.global_position
	if not motor.grounded or motor.feet.y > perch.y-1.5: return
	var off := Vector2(to.x-motor.feet.x,to.z-motor.feet.z)
	if off.length() > HEIST_DROP_CUE: return
	var toward := maxf(Vector2(motor.velocity.x,motor.velocity.z).dot(off.normalized()),1.0)
	if off.length() > 1.5 and off.length()/toward > HEIST_DROP_LEAD: return
	_drop_done = true
	_olmec_due = -1.0
	var b := olmec()
	if b != null and b.global_position.y < perch.y-4.0 and b.global_position.distance_to(motor.feet) < HEIST_DROP_THERE:
		print("heist: the Olmec's already down on south, %.1f m off him: no staged drop" % b.global_position.distance_to(motor.feet))
		return
	var stand := _olmec_stand(perch,Vector2(_olmec_perch.global_transform.basis.z.x,_olmec_perch.global_transform.basis.z.z))
	if stand == null: return
	drop_seen = false
	var ok: bool = stand.stage_drop(to)
	if ok:
		_drop_body = stand
		stand.staged_shock = HEIST_DROP_SHOCK
	print("heist: the Olmec's staged drop from %s onto the foot %s, him %.1f m off it at %.1f m/s: %s" % [stand.position,to.round(),off.length(),Vector2(motor.velocity.x,motor.velocity.z).length(),"winding up" if ok else "no go (%s)" % stand.down_why])

## As he winds up (till HEIST_DROP_AIM s before he goes), the drop's
## landing aimed where the camera will see it (`_drop_spots`), else the
## foot.
func _aim_drop() -> void:
	if _drop_body == null: return
	var b := _drop_body
	if not is_instance_valid(b) or str(b.state) != "windup" or str(b.leap_kind) != "drop":
		if is_instance_valid(b) and str(b.state) == "leap": print("heist: the staged drop goes for %s (%s)" % [(b._leap_to as Vector3).round(),"in view" if drop_seen else "the foot"])
		_drop_body = null
		return
	if float(b.state_t) < b._windup_s()-HEIST_DROP_AIM: return
	var to := _olmec_drop.global_position
	var spots := _drop_spots(b,to)
	for at: Vector3 in spots:
		if b.aim_drop(at):
			drop_seen = true
			_drop_body = null
			print("heist: the staged drop aimed in view at %s, %.1f m off the foot; him at %s going %s" % [at.round(),at.distance_to(to),motor.feet.round(),motor.velocity])
			return
	_drop_body = null

## The drop's landings the camera will see, best first: round where he'll
## be in HEIST_DROP_FLIGHT s (at his speed now, along the way: the pillar,
## then toward the gap), in HEIST_DROP_BAND, on the foot's floor with room
## for the bulk; the furthest back along his run (where he just was) first,
## then the nearest him, the side away from the gap first. (A band, not
## `_lands_seen` on the camera moved along: the play camera trails him
## further as the slide speeds up, 5 m back at the windup and 7 by the
## landing, so the camera then isn't the camera now.)
func _drop_spots(b: Node3D, to: Vector3) -> Array:
	# Where he'll be: on down the pillar to its foot at his speed, then on
	# toward the gap (the way on; off the pillar he bends to it).
	var go := maxf(Vector2(motor.velocity.x,motor.velocity.z).length(),2.0)*HEIST_DROP_FLIGHT
	var feet := Vector2(motor.feet.x,motor.feet.z)
	var foot := Vector2(to.x,to.z)
	var on := Vector2(HEIST_GAP_AT.x-foot.x,HEIST_GAP_AT.z-foot.y).normalized()
	var way := on
	var w2 := foot+on*(go-feet.distance_to(foot))
	if go < feet.distance_to(foot):
		way = (foot-feet).normalized()
		w2 = feet+way*go
	var will := Vector3(w2.x,to.y,w2.y)
	var side := Vector2(-way.y,way.x)
	# The side away from the way on (the gap): he bends toward it off the
	# pillar, and not into the drop.
	if side.dot(Vector2(HEIST_GAP_AT.x-will.x,HEIST_GAP_AT.z-will.z)) > 0.0: side = -side
	var found := []
	var space := get_world_3d().direct_space_state
	var back := float(HEIST_DROP_BAND[1])
	while back >= float(HEIST_DROP_BAND[0])-0.01:
		var out := float(HEIST_DROP_BAND[2])
		while out <= float(HEIST_DROP_BAND[3])+0.01:
			for sgn: float in [1.0,-1.0]:
				var q := Vector2(will.x,will.z)-way*back+side*out*sgn
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(q.x,to.y+HEIST_DROP_RISE+2.0,q.y),Vector3(q.x,to.y-HEIST_DROP_RISE,q.y)))
				if hit.is_empty() or (hit.normal as Vector3).y < 0.7: continue
				var at: Vector3 = hit.position
				if absf(at.y-to.y) > HEIST_DROP_RISE or not b._room_at(at): continue
				found.append(at)
			out += 0.5
		back -= 1.0
	return found

## Till the staged drop, an Olmec stuck under him (in the court, as he
## gets out over vault_s) isn't sent up another cliff by the crag's pick (it
## found vault_sw's own face, beside him): the drop brings him.
func _olmec_stuck(b: Node3D, delta: float) -> bool:
	if _drop_armed and not _drop_done: return false
	return super._olmec_stuck(b,delta)

## Main's never-stuck watch (dive off, back up a cliff near you) also
## waits for the drop, for the same reason.
func _never_stuck(b: Node3D, delta: float) -> bool:
	if _drop_armed and not _drop_done: return false
	return super._never_stuck(b,delta)

## Him on gap_near's top, within HEIST_SWING_NEAR m of its lip (the
## coded lip; the block may be moved in F4, the lip goes with the code).
func _on_gap_near(at: Vector3) -> bool:
	var way := HEIST_GAP_WAY.normalized()
	var off := Vector2(at.x-HEIST_GAP_AT.x,at.z-HEIST_GAP_AT.z)
	return off.dot(way) <= 0.5 and off.length() < HEIST_SWING_NEAR and absf(at.y-HEIST_GAP_AT.y) < 1.5

## The rope out at `id` (swing_03 by default): aimed at it, or thrown and on it.
func _rope_at_swing(id := "swing_03") -> bool:
	if rope == null: return false
	var st := str(rope.state)
	if st == "coiled": return false
	if st == "aim": return str(rope.aim_piece) == id
	return str(rope.piece) == id

## The chain's rigging holds (HEIST_RIGS).
func _stage_rigs(delta: float) -> void:
	if not _drop_done or rope == null or not motor.grounded: return
	var b := olmec()
	if b == null or not bool(b.hunting): return
	for id: String in HEIST_RIGS:
		var top := _swing_top(id)
		if Vector2(top.x-motor.feet.x,top.z-motor.feet.z).length() > HEIST_RIG_NEAR: continue
		if not (_rope_at_swing(id) or (str(hands) == "rope" and str(rope.state) == "coiled")): continue
		var t := float(_rig_hold.get(id,0.0))
		if t >= HEIST_SWING_GRACE: return
		if t == 0.0:
			print("heist: rigging %s, rope in hand: the Olmec holds his pounce, %.1f m off (%s)" % [id,b.global_position.distance_to(motor.feet),str(b.state)])
		# A suck already drawing (its wind drags the thrown hook along the
		# arch, and a hook 1.3 m off its middle swings you past the stack)
		# gives out.
		if str(b.state) == "plant" or str(b.state) == "suck":
			print("heist: rigging %s: his suck at %.1f m gives out" % [id,b.global_position.distance_to(motor.feet)])
			b._go("spent")
		# A pounce, or any leap coming down within HEIST_RIG_SHOCK m (its
		# landing wave throws you off the rope), checks while you rig.
		if str(b.state) == "windup" and (str(b.leap_kind) == "pounce" or (b._leap_to as Vector3).distance_to(motor.feet) < HEIST_RIG_SHOCK):
			if not _rig_hold.has(id+"/checked"): print("heist: rigging %s: his %s at %.1f m checks" % [id,str(b.leap_kind),(b._leap_to as Vector3).distance_to(motor.feet)])
			_rig_hold[id+"/checked"] = true
			b._go(b._resume())
		t += delta
		_rig_hold[id] = t
		b._pounce_ready = maxf(float(b._pounce_ready),float(b._clock)+0.3)
		b._suck_ready = maxf(float(b._suck_ready),float(b._clock)+0.3)
		if t >= HEIST_SWING_GRACE: print("heist: the hold at %s is up: he comes for you" % id)
		return

## Swing point `id`'s line middle as built (moved in F4, it goes along).
func _swing_top(id: String) -> Vector3:
	var n := get_node_or_null("Swings/%s" % id) as Node3D
	if n != null: return n.global_position
	for row: Array in HEIST_SWINGS: if row[0] == id: return row[2]
	return Vector3.INF

## The staged swing out from under him (HEIST_SWING_*).
func _stage_swing(delta: float) -> void:
	if not _drop_done or _swing_done or rope == null: return
	var b := olmec()
	if b == null or not bool(b.hunting): return
	if motor.grounded and _on_gap_near(motor.feet):
		_swing_from = motor.feet
		if (_rope_at_swing() or str(hands) == "rope") and _swing_hold_t < HEIST_SWING_GRACE:
			if _swing_hold_t == 0.0:
				print("heist: on gap_near, rope in hand: the Olmec holds his pounce, %.1f m off (%s)" % [b.global_position.distance_to(motor.feet),str(b.state)])
				# A pounce winding up checks.
				if str(b.state) == "windup" and str(b.leap_kind) == "pounce": b._go(b._resume())
			_swing_hold_t += delta
			b._pounce_ready = maxf(float(b._pounce_ready),float(b._clock)+0.3)
			b._suck_ready = maxf(float(b._suck_ready),float(b._clock)+0.3)
			if _swing_hold_t >= HEIST_SWING_GRACE: print("heist: the hold's up: he comes for you")
		return
	if not bool(rope.swinging) or _swing_from == Vector3.INF: return
	_swing_done = true
	var d: float = b.global_position.distance_to(_swing_from)
	if d > HEIST_SWING_REACH:
		print("heist: you swing off swing_03; the Olmec's %.1f m back: no leap" % d)
		return
	var ok: bool = b.stage_drop(_swing_from)
	if ok: b.staged_shock = HEIST_SWING_SHOCK
	print("heist: you swing off swing_03 from %s; the Olmec, %.1f m off (%s), leaps for it: %s" % [_swing_from.round(),d,str(b.state),"winding up" if ok else "no go (%s)" % b.down_why])

## The Olmec standing on the floor under `at` facing `face` (x, z), on the
## hunt; the one there was cleared (unless he already stands there).
func _olmec_stand(at: Vector3, face: Vector2) -> Node3D:
	var b := olmec()
	if b != null and bool(b.grounded) and b.global_position.distance_to(at) < 4.0: return b
	var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*4.0,at+Vector3.DOWN*8.0))
	if hit.is_empty():
		push_warning("heist: no floor under heist/olmec_perch at %s" % at)
		return null
	_olmec_clear()
	var knobs: Dictionary = OLMEC_KNOBS.duplicate()
	knobs.merge(_body_knobs,true)
	var p: Vector3 = hit.position
	b = enemies.add(OlmecTarget,p,face.normalized(),knobs)
	var h: Node3D = enemies.add(InhalerHead,p,face.normalized(),{})
	b.make_whole(h)
	tune_olmec(b,h)
	if breakables != null: b.breaker = breakables
	b.body.force_update_transform()
	b.hunting = true
	b.seen_at = motor.feet
	olmec_spawns += 1
	olmec_cliff = {}
	_gone_t = -1.0
	return b

## The landing's top: the crown less three ledges' rises.
static func step_top(rises_left: int) -> float:
	return HEIST_CROWN_S-float(rises_left)*RuinKit.SET_OFF*WorldScale.wanderer

## A grey stone box: a StaticBody3D named `id` with its collider and mesh.
static func _stone_box(id: String, size: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = id
	var box := BoxShape3D.new()
	box.size = size
	var col := CollisionShape3D.new()
	col.shape = box
	body.add_child(col)
	var drawn := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	drawn.mesh = bm
	drawn.material_override = mat
	body.add_child(drawn)
	return body

## The court's way out (HEIST_RAMPS, HEIST_STEPS), each named heist/<id>.
func _build_vault_way() -> void:
	var holder := Node3D.new()
	holder.name = "VaultWay"
	add_child(holder)
	var stone := SwingPoint._mat(Color(0.6,0.57,0.52))
	var steps := HEIST_STEPS.size()-1
	for row: Array in HEIST_RAMPS:
		var id := str(row[0])
		var called := "heist/%s" % id
		if Layout.deleted(called): continue
		var lo: Vector3 = row[1]
		var hi: Vector3 = row[2]
		if hi.y == 0.0: hi.y = step_top(steps)
		var along := hi-lo
		var xb := along.normalized()
		var zb := xb.cross(Vector3.UP).normalized()
		var yb := zb.cross(xb)
		var thick := float(row[4])
		var coded := Transform3D(Basis(xb,yb,zb),(lo+hi)*0.5-yb*thick*0.5)
		var body := _stone_box(id,Vector3(along.length(),thick,float(row[3])),stone)
		body.transform = Layout.xform(called,coded)
		holder.add_child(body)
		Layout.track(called,body,"piece",coded)
	for row: Array in HEIST_STEPS:
		var id := str(row[0])
		var called := "heist/%s" % id
		if Layout.deleted(called): continue
		var mid: Vector2 = row[1]
		var top := step_top(steps-int(row[3]))
		var size := Vector3(STEP_WIDTH,top-STEP_FOOT,float(row[2]))
		var coded := Transform3D(Basis(),Vector3(mid.x,(top+STEP_FOOT)*0.5,mid.y))
		var body := _stone_box(id,size,stone)
		body.transform = Layout.xform(called,coded)
		holder.add_child(body)
		Layout.track(called,body,"piece",coded)

## The far side's lip (the top middle of gap_far's near face), as coded.
static func gap_far_lip() -> Vector3:
	var way := Vector3(HEIST_GAP_WAY.x,0.0,HEIST_GAP_WAY.y).normalized()
	return HEIST_GAP_AT+way*HEIST_GAP_JUMP*WorldScale.wanderer+Vector3.DOWN*HEIST_GAP_DROP

## The way out's gap (HEIST_GAP_BLOCKS), each named heist/<id>: a stone
## block GAP_DEPTH deep, its x along the way.
func _build_gap() -> void:
	var holder := Node3D.new()
	holder.name = "Gap"
	add_child(holder)
	var stone := SwingPoint._mat(Color(0.6,0.57,0.52))
	var way := Vector3(HEIST_GAP_WAY.x,0.0,HEIST_GAP_WAY.y).normalized()
	var basis := Basis(way,Vector3.UP,way.cross(Vector3.UP))
	for row: Array in HEIST_GAP_BLOCKS:
		var id := str(row[0])
		var called := "heist/%s" % id
		if Layout.deleted(called): continue
		var long := float(row[1])
		var far := int(row[3]) == 1
		# The near block lies behind its lip; the far one starts past the gap.
		var lip: Vector3 = gap_far_lip() if far else HEIST_GAP_AT
		var mid := lip+way*(long*0.5 if far else -long*0.5)+Vector3.DOWN*GAP_DEPTH*0.5
		var coded := Transform3D(basis,mid)
		var body := _stone_box(id,Vector3(long,GAP_DEPTH,float(row[2])),stone)
		body.transform = Layout.xform(called,coded)
		holder.add_child(body)
		Layout.track(called,body,"piece",coded)

## The bridge home bears a load and snaps (BridgeLoad), and he can catch
## and climb its hanging halves (BridgeClimb).
func _load_bridge() -> void:
	if bridges.is_empty(): return
	var live: MeshInstance3D = bridges[0]
	bridge_load = BridgeLoad.on(live,"bridge home",int(HEIST_BRIDGES[0][3]))
	bridge_load.strain_kg = HEIST_BRIDGE_STRAIN
	bridge_load.lip = RIM_BACK
	bridge_climb = BridgeClimb.new(bridge_load,BridgeLoad.WANDERER_KG)

## The staged snap behind him: where he is on the deck, and once he steps
## off its far end with the isle awake, the countdown to the break.
func _stage_snap(delta: float) -> void:
	if bridge_load == null or bool(bridge_load.broken) or not _snap_armed: return
	if _snap_due >= 0.0:
		_snap_due -= delta
		if _snap_due < 0.0:
			print("heist: bridge_home snaps behind him at %s" % motor.feet)
			bridge_load.snap(HEIST_SNAP_AT)
		return
	var on: Vector3 = bridge_load.deck_spot(motor.feet)
	if on != Vector3.INF:
		_deck_t = maxf(_deck_t,on.x)
	elif _deck_t >= HEIST_SNAP_PAST and motor.grounded:
		_snap_due = HEIST_SNAP_DELAY
	elif motor.grounded:
		_deck_t = -1.0

## Each frame he and his bag tell the bridge their weight (BridgeLoad
## `bear_at`; his own already sinks the deck by its tread).
func _bear_bridge() -> void:
	if bridge_load == null: return
	BridgeLoad.bear_at(motor.feet,BridgeLoad.WANDERER_KG,motor,false)
	if bag != null and float(bag.kg) > 0.0:
		var loose: Node3D = bag.loose
		var at: Vector3 = motor.feet if bag.state == "worn" or loose == null or not is_instance_valid(loose) else loose.global_position
		BridgeLoad.bear_at(at,float(bag.kg),bag)

## The takeoff beat (HEIST_OLMEC_TURF): on boarding, awake, once.
func _stage_turf(delta: float) -> void:
	_turf_t += delta
	if _turf_done or not _drop_armed or _olmec_turf == null: return
	_turf_done = true
	var b := olmec()
	if b == null or not bool(b.hunting):
		print("heist: you board; no Olmec on the hunt: no takeoff leap")
		return
	var to := _olmec_turf.global_position
	var d: float = b.global_position.distance_to(to)
	if d > HEIST_TURF_REACH:
		if _turf_t < HEIST_TURF_WAIT:
			_turf_done = false
			return
		print("heist: you board; the Olmec's %.1f m off the turf: no takeoff leap" % d)
		return
	var ok: bool = b.stage_drop(to)
	if not ok and _turf_t < HEIST_TURF_WAIT:
		# Mid-leap or climbing: tried again next frame, for a beat.
		_turf_done = false
		return
	if ok: b.staged_shock = HEIST_TURF_SHOCK
	print("heist: you board; the Olmec, %.1f m off (%s), leaps for the turf by the plane %s: %s" % [d,str(b.state),to.round(),"winding up" if ok else "no go (%s)" % b.down_why])

## Flying (no foot tick then): the takeoff beat.
func _process(delta: float) -> void:
	super._process(delta)
	if home != null: home.tint_haze(_environment,_celestial)
	if flying and delta > 0.0: _stage_turf(delta)

func tick(delta: float) -> void:
	super.tick(delta)
	if not flying:
		_stage_drop()
		_aim_drop()
		_stage_swing(delta)
		_stage_rigs(delta)
	if bridge_load == null or flying: return
	_bear_bridge()
	_stage_snap(delta)
	if motor.rider == null: bridge_climb.catch(motor,delta)

## Placed anywhere (a fall, a restart), off any hanging half and the
## bridge whole again, its staged snap reset (armed again by the next wake).
func place(at: Vector3, face: Vector2) -> void:
	if bridge_climb != null and bridge_climb.holding():
		if motor.rider == bridge_climb: motor.release(bridge_climb)
		bridge_climb._free(motor)
	super.place(at,face)
	if bridge_load != null and bool(bridge_load.broken): bridge_load.mend()
	_deck_t = -1.0
	_snap_due = -1.0
	_swing_hold_t = 0.0
	_swing_from = Vector3.INF
	_rig_hold = {}
	_turf_done = false
	_turf_t = 0.0

const BridgeLoad = preload("res://scripts/bridge_load.gd")
const BridgeClimb = preload("res://scripts/bridge_climb.gd")
const SwingPoint = preload("res://scripts/rope/swing_point.gd")
const VaultHost = preload("res://scripts/home/vault_host.gd")
