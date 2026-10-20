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
		["terrace_n",Vector3(24.0,-11.0,-30.0),{"seed":42,"size":12.0,"shape":0.3,"flat":0.6}],
	]],
	["ledge",Vector3(58.0,-9.0,-48.0),{"seed":81,"size":16.0,"shape":0.4,"flat":0.7,"landmark":0},[]],
	["gate",Vector3(100.0,1.0,-42.0),{"seed":82,"size":20.0,"shape":0.55,"flat":0.6,"landmark":0},[]],
	["spur",Vector3(142.0,-3.0,-40.0),{"seed":83,"size":14.0,"shape":0.5,"flat":0.7,"landmark":0},[]],
	["vault_court",Vector3(190.0,-10.0,2.0),{"seed":91,"size":20.0,"shape":0.2,"flat":0.95,"landmark":0},[]],
	["vault_n",Vector3(185.0,6.0,-28.0),{"seed":92,"size":14.0,"shape":0.6,"flat":0.6,"landmark":0},[]],
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

func _ready() -> void:
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

## No life yet (the loot, rope, brood and Olmec come in later steps).
func _add_life() -> void:
	pass
