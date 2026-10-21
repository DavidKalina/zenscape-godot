extends RefCounted
## The far isles round the plane field (studies/sky_weather_field.gd): a
## handful of plain rolling kit isles (scripts/kit_isle/kit_land.gd
## `island`, the field's own land code) scattered a few hundred metres to
## about two km off, at their own heights, so weather has something to pass
## over and the plane somewhere to fly to. No ruins, no cliffs.
##
## Each isle in ISLES: its name, its middle (x, z), its turf's datum (m),
## its half extents (m), its turn (rad), how far its rolls rise and fall
## (m) and its seed. Those with `land` true are big and gentle enough to
## set the plane down on by hand (AGENTS.md, Motifs): their rolls stay low
## and wide, so the whole oval is a landing stretch; the small ones roll
## harder and are only to look at and pass over.
const KitLand = preload("res://scripts/kit_isle/kit_land.gd")
const KitLook = preload("res://scripts/kit_isle/kit_look.gd")

const ISLES := [
	{"name":"near","at":Vector2(-430.0,-240.0),"top":16.0,"half":Vector2(92.0,56.0),"turn":0.5,"roll":1.0,"seed":101,"land":true},
	{"name":"east","at":Vector2(640.0,160.0),"top":52.0,"half":Vector2(96.0,58.0),"turn":-0.3,"roll":1.2,"seed":102,"land":true},
	{"name":"spire","at":Vector2(170.0,-760.0),"top":112.0,"half":Vector2(34.0,28.0),"turn":1.1,"roll":5.0,"seed":103,"land":false},
	{"name":"north","at":Vector2(-280.0,-1260.0),"top":38.0,"half":Vector2(124.0,72.0),"turn":0.2,"roll":1.4,"seed":104,"land":true},
	{"name":"west","at":Vector2(-1480.0,-260.0),"top":72.0,"half":Vector2(140.0,88.0),"turn":-0.7,"roll":1.6,"seed":105,"land":true},
	{"name":"south","at":Vector2(380.0,1080.0),"top":24.0,"half":Vector2(48.0,36.0),"turn":0.9,"roll":4.0,"seed":106,"land":false},
	{"name":"far","at":Vector2(1380.0,-1480.0),"top":86.0,"half":Vector2(176.0,104.0),"turn":0.35,"roll":1.8,"seed":107,"land":true},
]
## The land's grid (m) near and past NEAR_CELL_OUT m from the field.
const CELL_NEAR := 2.5
const CELL_FAR := 4.0
const NEAR_CELL_OUT := 900.0
## A keel's depth per m of an isle's longer half extent (and at least).
const KEEL := 0.42
const KEEL_LEAST := 22.0

## Builds every isle under `parent` and gives back one entry each:
## {name, land (the KitLand node), outline (world (x, z)), middle
## (Vector3, y 0), radius, top, landable}.
static func build(parent: Node3D) -> Array:
	var out: Array = []
	for d: Dictionary in ISLES: out.append(_isle(parent,d))
	return out

static func _isle(parent: Node3D, d: Dictionary) -> Dictionary:
	var at: Vector2 = d.at
	var half: Vector2 = d.half
	var top: float = d.top
	var roll: float = d.roll
	var turn: float = d.turn
	var seed_value: int = d.seed
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var rolls := FastNoiseLite.new()
	rolls.seed = seed_value
	# Landable isles roll long and low; the small ones in shorter hills.
	rolls.frequency = 0.01 if bool(d.land) else 0.03
	var outline: Array = []
	var points := 28 if half.x > 60.0 else 20
	for k in range(points):
		var a := k*TAU/float(points)
		var p := Vector2(cos(a)*half.x,sin(a)*half.y)*rng.randf_range(0.9,1.06)
		outline.append(at+p.rotated(turn))
	var ground := func(x: float, z: float) -> float:
		return top+roll*rolls.get_noise_2d(x,z)
	var spec := {"outline":outline,"depth":maxf(KEEL_LEAST,KEEL*maxf(half.x,half.y)),"seed":seed_value,"top":top,
		"name":"sky isle %s" % d.name,"ground":ground,"tone":KitLook.turf(seed_value),
		"cell":CELL_NEAR if at.length() < NEAR_CELL_OUT else CELL_FAR}
	var land: Node3D = KitLand.island(spec)
	land.name = "SkyIsle_%s" % d.name
	parent.add_child(land)
	return {"name":d.name,"land":land,"outline":outline,"middle":Vector3(at.x,0.0,at.y),
		"radius":maxf(half.x,half.y),"top":top,"landable":bool(d.land)}
