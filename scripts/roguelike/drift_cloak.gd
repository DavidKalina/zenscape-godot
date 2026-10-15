extends Node3D
## [items_move] The Drift Cloak drawn: a short felted wool shoulder cape on
## his back (scripts/roguelike/items_move.gd). Worn, it hangs and stirs
## with his run; spread (`update` open), it flares out behind and to the
## sides like a kite's skin, its hem riding up and rippling, so a drift
## reads from the high camera at a glance. Hung under the figure's lean
## (PilotFigure `_tilt`), in the clip's units.
##
## A small grid rebuilt each frame (COLS x ROWS quads): sun-faded slate
## wool, darker and dustier toward the frayed hem, per-facet tone jitter.

const COLS := 6
const ROWS := 5
## The collar's height and its stand-off behind the back; half widths at
## the collar and the hem; its length hung.
const TOP_Y := 0.86
const BACK := 0.13
const HALF_TOP := 0.13
const HALF_HEM := 0.24
const LONG := 0.62
## Spread: the hem's lift (radians from hanging), the width's growth.
const SPREAD_LIFT := 1.35
const SPREAD_WIDE := 3.2
## How fast it spreads and folds (s).
const OPEN_EASE := 0.07
const FOLD_EASE := 0.18
const WOOL := Color("7d7a6c")
const HEM := Color("9a7f5c")

var _mesh := ImmediateMesh.new()
var _inst: MeshInstance3D
var _open := 0.0
var _t := 0.0
var _jitter: PackedFloat32Array = []

func _init() -> void:
	name = "DriftCloak"

func _ready() -> void:
	_inst = MeshInstance3D.new()
	_inst.mesh = _mesh
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_inst.material_override = m
	add_child(_inst)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5150
	_jitter.resize(COLS*ROWS)
	for i in range(COLS*ROWS): _jitter[i] = rng.randf_range(0.0,0.14)

func update(delta: float, open: bool, motor: RefCounted) -> void:
	_t += delta
	var goal := 1.0 if open else 0.0
	_open = lerpf(_open,goal,1.0-exp(-delta/(OPEN_EASE if open else FOLD_EASE)))
	var pace := 0.0
	var fall := 0.0
	if motor != null:
		var v: Vector3 = motor.get("velocity")
		pace = Vector2(v.x,v.z).length()
		fall = -v.y
	_build(pace,fall)

func _build(pace: float, fall: float) -> void:
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var o := smoothstep(0.0,1.0,_open)
	# Hanging it streams back with his run a little; spread, it lifts up
	# and out, rippling.
	var stream := clampf(pace*0.06,0.0,0.45)+clampf(fall*0.05,0.0,0.3)*(1.0-o)
	var grid: Array = []
	for j in range(ROWS+1):
		var v := float(j)/ROWS
		var row: Array = []
		var lift := lerpf(stream*v,SPREAD_LIFT*pow(v,0.8),o)
		for i in range(COLS+1):
			var u := float(i)/COLS*2.0-1.0
			var half := lerpf(HALF_TOP,HALF_HEM,v)*lerpf(1.0,SPREAD_WIDE,o*v)
			var x := u*half
			var ripple := sin(_t*(9.0+3.0*o)+u*2.4+v*4.0)*0.02*v*(0.3+o*1.6)
			var flare := o*v*absf(u)*0.12
			var down := v*LONG
			var y := TOP_Y-down*cos(lift)+flare
			var z := BACK+down*sin(lift)+ripple+absf(u)*0.03*(1.0-o)
			if j == ROWS: y -= (0.03 if i%2 == 1 else 0.0)
			row.append(Vector3(x,y,z))
		grid.append(row)
	for j in range(ROWS):
		for i in range(COLS):
			var a: Vector3 = grid[j][i]
			var b: Vector3 = grid[j][i+1]
			var c: Vector3 = grid[j+1][i+1]
			var d: Vector3 = grid[j+1][i]
			var tone := WOOL.lerp(HEM,pow(float(j)/ROWS,1.5)*0.7).darkened(_jitter[j*COLS+i])
			for tri: Array in [[a,b,c],[a,c,d]]:
				var n: Vector3 = ((tri[1]-tri[0]) as Vector3).cross(tri[2]-tri[0]).normalized()
				for p: Vector3 in tri:
					_mesh.surface_set_color(tone)
					_mesh.surface_set_normal(n)
					_mesh.surface_add_vertex(p)
	_mesh.surface_end()
