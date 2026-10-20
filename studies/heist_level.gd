extends "res://studies/crag_reach.gd"
## The heist level (docs/design/heist-level/spec-heist-level.md): a
## standalone greybox place built on the crag reach's code (its crag units,
## bridges, pillars, ruins, Olmec and greed run), with its own land. West
## to east, about 300 m: the landing mass with the parked plane; the way in
## along the north side (a terrace to rappel down to, a ledge, a gate mass
## to climb, a spur); the vault, a sunken court ringed by three higher rims; the
## way out along the south side (a rim to throw the bag up, a fallen pillar
## to slide down to the south mass, the ford mass, a rope bridge home).
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
	["ford",Vector3(82.0,-5.0,52.0),{"seed":96,"size":16.0,"shape":0.5,"flat":0.7,"landmark":0},[]],
]
const HEIST_BASE := {"grass":0.0}

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
	["swing_04","branch",Vector3(98.2,32.7,47.0),Vector2(0.6,0.8),7.0,7.0,"a dead tree on ford's east rim, its branch over the gap: the chain's last"],
]
## The climbing walls: [id, middle of its top (world), out (x, z: the way
## its climbed face looks), width, depth, height]. A plain stone block
## standing on the lower mass with its top flush with the higher crown:
## a crag unit's face is undercut under its crown's lip, so a rope hung
## from it swings in under the overhang and he finds his feet on the slope
## below before the lip (the gate's did). The block gives a sheer face.
const HEIST_WALLS := [
	["wall_01",Vector3(71.8,33.0,-45.7),Vector2(-0.984,-0.179),8.0,4.0,14.0],
]

func greed_root() -> String:
	return "heist"

func greed_loot() -> Array:
	return HEIST_LOOT

func greed_posts() -> Array:
	return HEIST_POSTS

func greed_burrows() -> Array:
	return []

## The meter's marks (brood, Olmec): one past the way in's loot, so the
## way in stays calm however much of it he bags and the vault's take
## wakes the isle. --greed-brood= / --greed-olmec= still win.
func greed_marks() -> Vector2i:
	var w := 0
	for row: Array in HEIST_LOOT: w += int(VaultHost.VALUES.get(str(row[1]),0))
	return Vector2i(w+1,w+1)

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
	return []

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
## clock, end screen and restart, the hands hint; then the swing points and
## the climbing walls. No burrows yet (the wake, a later step).
func _add_life() -> void:
	Greed.build_all(self)
	_build_swings()
	_build_walls()
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

const SwingPoint = preload("res://scripts/rope/swing_point.gd")
const VaultHost = preload("res://scripts/home/vault_host.gd")
