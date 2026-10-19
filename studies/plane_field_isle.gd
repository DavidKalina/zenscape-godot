extends "res://studies/kit_isle.gd"
## The plane field: a kit isle with nothing on it but room to fly. One big
## isle of gently rolling turf (an oval FIELD_HALF.x by FIELD_HALF.y m, no ruins, no
## cliffs) under open sky, the plane parked by the start, repaired: walk to
## it, Space climbs in, and take off along the land or off its edge (scripts/
## manual_landing.gd). A sandbox for the plane's takeoff and feel.
##   R            back to the start
##   Space (pad A) by the parked plane: climb in
##   ./run-plane-field.command
##   godot --path . res://studies/plane_field_isle.tscn -- --no-title
## The kit isles' flags hold here: --no-flora, --no-life, --no-sky, --fly,
## --look=, --capture=, --at=.
const FieldLand = preload("res://scripts/kit_isle/kit_land.gd")
const FieldLook = preload("res://scripts/kit_isle/kit_look.gd")

## The isle's half extents (m), its turf's datum and how far its rolls rise
## and fall (m), its keel's depth under it, and its seed.
const FIELD_HALF := Vector2(90.0,60.0)
const FIELD_TOP := 30.0
const ROLL := 0.6
const DEPTH := 38.0
const SEED := 41

var _rolls := FastNoiseLite.new()

func _load_pack() -> void:
	start = Vector3(0.0,FIELD_TOP,FIELD_HALF.y*0.35)
	start_face = Vector2(0.0,-1.0)
	lost = FIELD_TOP-45.0
	_last_stood = start
	stations = []

func isle_name() -> String:
	return "plane field"

func isle_top() -> float:
	return FIELD_TOP

func flora_seed() -> int:
	return SEED

## The turf: the datum, rolling a little.
func _field_y(p: Vector2) -> float:
	return FIELD_TOP+ROLL*_rolls.get_noise_2d(p.x,p.y)

func _build_art() -> void:
	art = Node3D.new()
	art.name = "Art"
	add_child(art)
	_rolls.seed = SEED
	_rolls.frequency = 0.012
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var outline: Array = []
	for k in range(28):
		var a := k*TAU/28.0
		outline.append(Vector2(cos(a)*FIELD_HALF.x,sin(a)*FIELD_HALF.y)*rng.randf_range(0.93,1.05))
	var spec := {"outline":outline,"depth":DEPTH,"seed":SEED,"top":FIELD_TOP,"name":"plane field",
		"ground":func(x: float, z: float) -> float: return _field_y(Vector2(x,z)),
		"tone":FieldLook.turf(SEED)}
	var land: Node3D = FieldLand.island(spec)
	art.add_child(land)
	add_turf(land,outline)
