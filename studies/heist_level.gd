extends "res://studies/crag_reach.gd"
## The heist level (docs/design/heist-level/spec-heist-level.md): a
## standalone greybox place built on the crag reach's code (its crag units,
## bridges, pillars, ruins, Olmec and greed run), with its own land. West
## to east, about 300 m: the landing mass with the parked plane; the way in
## along the north side (a terrace to rappel down to, a ledge, a gate mass
## to climb, a spur); the vault, a sunken court ringed by three higher rims; the
## way out along the south side (a rim to throw the bag up, a fallen pillar
## to slide down to the south mass, the ford mass, a chain of two swings
## over stack_1 to stack_2, a rope bridge home).
## Every piece is named `heist/<name>` (scripts/layout_overrides.gd,
## layouts/heist.json), moved in the world view (F4) by that name.
##   godot --path . res://studies/heist_level.tscn -- --no-title
## The season is held at summer (never winter here) unless --season= asks.

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
	["south",Vector3(125.0,-10.0,64.0),{"seed":95,"size":20.0,"shape":0.45,"flat":0.7,"landmark":0},[]],
	["ford",Vector3(82.0,-8.8,52.0),{"seed":96,"size":16.0,"shape":0.5,"flat":0.7,"landmark":0},[]],
	# The chain's stacks (the way home): ford -> stack_1 -> stack_2, each
	# crown a little under the last (21.9, 21.2, 20.9), so each swing (swing_05,
	# swing_06) lands level or down.
	["stack_1",Vector3(55.0,-9.0,42.0),{"seed":97,"size":7.0,"shape":0.4,"flat":0.8,"landmark":0},[]],
	["stack_2",Vector3(39.5,-9.2,30.0),{"seed":98,"size":9.0,"shape":0.4,"flat":0.8,"landmark":0},[]],
]
const HEIST_BASE := {"grass":0.0}

## The way out's fallen pillar (crag_reach.gd PILLARS rows: name, from the
## high mass, to the low, seed): a colossus column lying from vault_s's
## crown rim down onto south's crown, one long slope to boot-surf with the
## bag on (crouch at a run).
const HEIST_PILLARS := [
	["pillar_out","vault_s","south",211],
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
const HEIST_SWINGS := [
	["swing_01","arch",Vector3(38.5,27.5,-37.2),Vector2(0.467,0.884),10.0,24.0,"a rock arch over the gap terrace_n -> ledge (the way in)"],
	["swing_02","arm",Vector3(177.0,34.0,48.0),Vector2(0.0,1.0),7.0,4.0,"an arm out of vault_s's south face at its west corner: swing round the corner"],
	["swing_03","lintel",Vector3(113.5,26.5,56.0),Vector2(0.0,1.0),8.0,6.0,"a broken lintel on south's west rim: the swing out from under the Olmec"],
	["swing_04","branch",Vector3(98.2,28.9,47.0),Vector2(0.6,0.8),7.0,7.0,"a dead tree on ford's east rim, its branch over the gap south -> ford (spare: not on the route now)"],
	# The chain (the way home): two rock rings out of the clouds, one over
	# each gap ford -> stack_1 -> stack_2, each line 7 m over the far crown
	# across the way. Each swing lands on a stack before the next throw.
	["swing_05","arch",Vector3(64.5,28.6,45.0),Vector2(0.0,1.0),9.0,22.0,"a rock arch over the gap ford -> stack_1: the chain's first"],
	["swing_06","arch",Vector3(48.0,28.2,36.6),Vector2(0.613,-0.79),8.0,18.0,"a rock arch over the gap stack_1 -> stack_2: the chain's second"],
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
const HEIST_RAMPS := [
	["vault_ramp",Vector3(176.0,24.3,17.25),Vector3(188.0,0.0,17.25),4.5,1.0],
]
const HEIST_STEPS := [
	["vault_landing",Vector2(190.5,17.25),4.5,0],
	["vault_step_01",Vector2(190.5,20.5),2.0,1],
	["vault_step_02",Vector2(190.5,22.5),2.0,2],
	["vault_step_03",Vector2(190.5,24.75),2.5,3],
]
const HEIST_CROWN_S := 34.5
## The way out's gap (heist/gap_near, heist/gap_far), south -> ford: two
## stone blocks, the near one lying on south's west rim out over the void,
## its lip (the top middle of its far face) HEIST_GAP_AT; then a gap of
## HEIST_GAP_JUMP (times the wanderer) along HEIST_GAP_WAY; the far one
## against ford's east rim, its top a SET_OFF over the near one's (ford's
## crown). Light (under the ledge bar, 9 kg) he runs, jumps and catches
## its lip; heavier the ledge is barred and the heavy bag cuts his jump:
## he throws the bag across, jumps, climbs and shoulders it. Rows: [id,
## length along the way, width, which (0 near, 1 far)].
const HEIST_GAP_AT := Vector3(106.0,20.3,58.0)
const HEIST_GAP_WAY := Vector2(-1.0,0.0)
const HEIST_GAP_JUMP := 3.0
const HEIST_GAP_BLOCKS := [
	["gap_near",9.0,4.0,0],
	["gap_far",6.0,5.0,1],
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

## The end screen's name for the place.
func greed_place() -> String:
	return "the vault's isle"

func _ready() -> void:
	# The greed run's bag, rope and loot are always on here.
	greed_on = true
	super._ready()
	# Never winter here: the year held at summer (the settings' Season row,
	# kit_weather.gd SEASON_CHOICES); a --season= flag keeps its own.
	if weather != null: weather.choose_season(2)

func place_root() -> String:
	return "heist"

func bridge_list() -> Array:
	return []

func pillar_list() -> Array:
	return HEIST_PILLARS

func ruin_list() -> Array:
	return HEIST_RUINS

func _load_pack() -> void:
	super._load_pack()
	start = Vector3(-6.0,TOP+1.5,4.0)
	start_face = Vector2(1.0,0.0)
	_last_stood = start

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
	_build_hands_hint()

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
		var body := SwingPoint.build(str(row[1]),id,float(row[4]),float(row[5]))
		if body == null: continue
		var coded := SwingPoint.frame(row[2],row[3])
		body.transform = Layout.xform(called,coded)
		holder.add_child(body)
		Layout.track(called,body,"piece",coded)

func _build_walls() -> void:
	var holder := Node3D.new()
	holder.name = "Walls"
	add_child(holder)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.55,0.52,0.47)
	stone.roughness = 1.0
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
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.6,0.57,0.52)
	stone.roughness = 1.0
	var steps := HEIST_STEPS.size()-1
	for row: Array in HEIST_RAMPS:
		var id := str(row[0])
		var called := "heist/%s" % id
		if Layout.deleted(called): continue
		var lo: Vector3 = row[1]
		var hi: Vector3 = row[2]
		hi.y = step_top(steps)
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
	return HEIST_GAP_AT+way*HEIST_GAP_JUMP*WorldScale.wanderer+Vector3.UP*RuinKit.SET_OFF*WorldScale.wanderer

## The way out's gap (HEIST_GAP_BLOCKS), each named heist/<id>: a stone
## block GAP_DEPTH deep, its x along the way.
func _build_gap() -> void:
	var holder := Node3D.new()
	holder.name = "Gap"
	add_child(holder)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.6,0.57,0.52)
	stone.roughness = 1.0
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

const SwingPoint = preload("res://scripts/rope/swing_point.gd")
const VaultHost = preload("res://scripts/home/vault_host.gd")
