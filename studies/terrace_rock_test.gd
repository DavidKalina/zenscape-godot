extends "res://studies/kit_isle.gd"
## The terrace rock's test shape (scripts/kit_isle/terrace_rock.gd,
## docs/design/terrace-rock/spec-terrace-rock.md): a small stepped isle of
## five tiers, built as one closed solid, in the kit isles' look with the
## pilot and the plane (studies/kit_isle.gd). The tiers cover the builder's
## cases: a tier nested in another (a ring of top round it), one nested two
## deep, one that runs out past the rim (a riser meeting the rim), one that
## straddles a lower tier's riser, and a cut up the second tier's south
## side with the kit's grand stair seated in it (its cheeks on the cut's walls).
##   godot --path . res://studies/terrace_rock_test.tscn -- --no-title
##   python tools/drive.py tools/terrace_check_run.gd -- --scene=studies/terrace_rock_test.tscn

var terrace: Node3D
var stair: Node3D

## The flight: its foot's middle on the lawn, climbing north up onto T1.
const STAIR_FOOT := Vector3(0.0,TOP,9.5)
const STAIR_FACING := Vector2(0.0,-1.0)

static func wobble(centre: Vector2, r: float, count: int, seed_value: int, amp := 0.14) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array = []
	for k in range(count):
		var a := k*TAU/count+rng.randf_range(-0.08,0.08)
		out.append(centre+Vector2(cos(a),sin(a))*r*(1.0+rng.randf_range(-amp,amp)))
	return out

## The test shape's tiers (world x, z; y).
static func tiers() -> Array:
	return [
		{"outline":wobble(Vector2(0,0),26.0,28,1),"y":TOP},
		{"outline":wobble(Vector2(5,-4),13.0,20,2),"y":TOP+TerraceRock.STAIR_RISE},
		{"outline":wobble(Vector2(-20,10),9.0,16,3),"y":TOP+2.2},
		{"outline":wobble(Vector2(8,-7),5.5,14,4),"y":TOP+8.6},
		{"outline":[Vector2(-12,-16),Vector2(-2,-16),Vector2(-2,-6),Vector2(-12,-6)],"y":TOP+6.6},
		TerraceRock.grand_stair_cut(STAIR_FOOT,STAIR_FACING,4.0),
	]

func _load_pack() -> void:
	stations = []
	start = Vector3(10.0,TOP,16.0)
	start_face = Vector2(0.0,-1.0)
	lost = TOP-30.0
	_last_stood = start

func isle_name() -> String:
	return "terrace rock test"

func _build_art() -> void:
	art = Node3D.new()
	art.name = "Art"
	add_child(art)
	terrace = TerraceRock.build({"tiers":tiers(),"seed":7})
	art.add_child(terrace)
	stair = TerraceRock.seat_grand_stair(STAIR_FOOT,STAIR_FACING,7)
	stair.name = "Flight"
	art.add_child(stair)
	add_turf(terrace,terrace.get_meta("outline"))
	print("terrace rock test: %s" % str(terrace.get_meta("stats")))
