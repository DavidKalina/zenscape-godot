extends Node3D
## The crown's spirals: one continuous ribbon of cloud coiling up each tower
## (docs/design/endless-flight/spec-crown.md), thinning toward the tip, each
## turning at its own speed, one the other way. Not the cloud march: a box
## round each axis and shaders/peak_spiral.gdshader, a short march through a
## formula, so it stands anywhere in height, leans with its tower and is soft
## flown through. No collision. --spirals=0 none.
##
## The trunk calls `set_axes([{base, tip, radius}, ...])`: world points, the
## ribbon's radius at the root in m. An axis may also name `period` (seconds a
## turn), `hand` (+1 or -1, the way round), `turns` (root to tip) and `seed`;
## left out they come from PERIOD, HAND, TURNS and the axis's place in the
## list. `test_axes(peak)` is the three on today's massif.

const SHADER := preload("res://shaders/peak_spiral.gdshader")
const CumulusNoise := preload("res://scripts/cumulus_noise.gd")
const LaunchArgs := preload("res://scripts/launch_args.gd")

## Seconds a turn and the way round, by the axis's place in the list.
const PERIOD: Array[float] = [34.0, 54.0, 23.0]
const HAND: Array[float] = [1.0, -1.0, 1.0]
## Turns from the root to the tip.
const TURNS := 3.4
## How fast the cloud runs up its ribbon, m/s (it churns as it turns).
const FLOW := 9.0
## The flow wraps here: whole tiles of the shader's noise (430 m a tile).
const FLOW_WRAP := 6450.0
## Over the cloud sheet (EndlessClouds.RENDER_PRIORITY), which draws first.
const PRIORITY := 8
## The box's reach past the ribbon's own, as a share of the radius.
const BOX := 1.75
## How often the sky's haze is read (s).
const HAZE_EVERY := 0.5

var _host: Node
var _ribbons: Array[Dictionary] = []
var _haze_wait := 0.0
var _flow := 0.0


## Whether the spirals run (not --spirals=0).
static func wanted() -> bool:
	return not "--spirals=0" in LaunchArgs.user_args()


## Three test axes in a crown over today's massif: spread 350-450 m, 400 m and
## more tall, uneven, the tips leaning in. The trunk's towers replace them.
static func test_axes(peak: RefCounted) -> Array[Dictionary]:
	var table := [
		# a, v along the massif's frame; root and tip world heights; radius.
		[270.0, 40.0, 1000.0, 1520.0, 175.0],
		[-30.0, 235.0, 1080.0, 1490.0, 140.0],
		[30.0, -215.0, 1070.0, 1450.0, 150.0],
	]
	var mid := Vector2.ZERO
	for row: Array in table: mid += peak.world(row[0],row[1])
	mid /= float(table.size())
	var axes: Array[Dictionary] = []
	for row: Array in table:
		var at: Vector2 = peak.world(row[0],row[1])
		var top := at.lerp(mid,0.16)
		axes.append({"base": Vector3(at.x,row[2],at.y), "tip": Vector3(top.x,row[3],top.y), "radius": row[4]})
	return axes


## `host` is the study (its look gives the haze).
func setup(host: Node) -> void:
	_host = host


## The ribbons, one for each axis; an empty list takes them all down.
func set_axes(axes: Array) -> void:
	for r: Dictionary in _ribbons: (r.box as Node).queue_free()
	_ribbons.clear()
	var unit := BoxMesh.new()
	for i in axes.size():
		var axis: Dictionary = axes[i]
		var base: Vector3 = axis.base
		var tip: Vector3 = axis.tip
		var radius := float(axis.radius)
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.render_priority = PRIORITY
		mat.set_shader_parameter("base",base)
		mat.set_shader_parameter("tip",tip)
		mat.set_shader_parameter("radius",radius)
		mat.set_shader_parameter("turns",float(axis.get("turns",TURNS)))
		mat.set_shader_parameter("hand",float(axis.get("hand",HAND[i%HAND.size()])))
		mat.set_shader_parameter("seed",float(axis.get("seed",1.7*float(i)+0.4)))
		var box := MeshInstance3D.new()
		box.name = "Spiral%d" % i
		box.mesh = unit
		box.material_override = mat
		box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		box.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		var lo := Vector3(minf(base.x,tip.x),base.y,minf(base.z,tip.z))-Vector3(radius*BOX,40.0,radius*BOX)
		var hi := Vector3(maxf(base.x,tip.x),tip.y,maxf(base.z,tip.z))+Vector3(radius*BOX,40.0,radius*BOX)
		box.position = (lo+hi)*0.5
		box.scale = hi-lo
		add_child(box)
		_ribbons.append({"box": box, "material": mat, "rate": TAU/float(axis.get("period",PERIOD[i%PERIOD.size()])), "spin": float(i)*2.1})
	_haze_wait = 0.0
	_read_look()
	set_process(not _ribbons.is_empty())


func _process(delta: float) -> void:
	_flow = fmod(_flow+FLOW*delta,FLOW_WRAP)
	for r: Dictionary in _ribbons:
		r.spin = fmod(float(r.spin)+float(r.rate)*delta,TAU)
		var mat: ShaderMaterial = r.material
		mat.set_shader_parameter("spin",r.spin)
		mat.set_shader_parameter("flow",_flow)
	_haze_wait -= delta
	if _haze_wait <= 0.0:
		_haze_wait = HAZE_EVERY
		_read_look()


## The noise, once made, and the haze the cloud sheet draws with, for the
## spirals to sit in the same air.
func _read_look() -> void:
	var noise: Texture = CumulusNoise.request()
	var sheet: ShaderMaterial = null
	var shape: Texture2D = null
	if _host != null and _host.get("look") != null and _host.look.clouds != null:
		sheet = _host.look.clouds.material
		shape = _host.look.clouds.effect.resolved_b
	for r: Dictionary in _ribbons:
		var mat: ShaderMaterial = r.material
		(r.box as MeshInstance3D).visible = noise != null
		if noise != null: mat.set_shader_parameter("noise",noise)
		if shape != null: mat.set_shader_parameter("cloud_shape",shape)
		if sheet != null:
			for k: String in ["haze","haze_height","sea_y","sun_scatter"]:
				var v: Variant = sheet.get_shader_parameter(k)
				if v != null: mat.set_shader_parameter(k,v)
