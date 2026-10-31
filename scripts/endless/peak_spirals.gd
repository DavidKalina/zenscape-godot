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
## list. `on_towers(towers.axes())` gives the axes for the crown.

const SHADER := preload("res://shaders/peak_spiral.gdshader")
const CumulusNoise := preload("res://scripts/cumulus_noise.gd")
const LaunchArgs := preload("res://scripts/launch_args.gd")

## Seconds a turn and the way round, by the axis's place in the list.
const PERIOD: Array[float] = [34.0, 54.0, 23.0]
const HAND: Array[float] = [1.0, -1.0, 1.0]
## Turns from the root to the tip.
const TURNS := 2.8
## How fast the cloud runs up its ribbon, m/s (it churns as it turns).
const FLOW := 9.0
## The flow wraps here: whole tiles of the shader's noise (430 m a tile).
const FLOW_WRAP := 6450.0
## Over the cloud sheet (EndlessClouds.RENDER_PRIORITY), which draws first.
const PRIORITY := 8
## On a tower: the root and the end of the ribbon past the tower's foot and
## tip, as shares of its height, and its radius in the tower's girths.
const ROOT := 0.1
const OVER := -0.1
const GIRTHS := 2.4
## The box's reach past the ribbon's own, as a share of the radius.
const BOX := 1.75
## How often the sky's haze is read (s).
const HAZE_EVERY := 0.5
## The ribbon's shape, as shaders/peak_spiral.gdshader has it, for `ribbon_at`.
const TAPER := 0.42
const TIGHTEN := 0.45
## Roused (`rouse`): the turn's speed at a full 1, and how far down the ribbon
## its tip is drawn in (a share of it).
const ROUSE_SPIN := 3.5
const ROUSE_TIP := 0.2

var _host: Node
var _ribbons: Array[Dictionary] = []
var _haze_wait := 0.0
var _flow := 0.0


## Whether the spirals run (not --spirals=0).
static func wanted() -> bool:
	return not "--spirals=0" in LaunchArgs.user_args()


## The ribbons' axes for the towers' `axes()`: from a little over each tower's
## foot (`floor_y`, world, the ground it rises from) to over its tip, the radius
## out past its walls.
static func on_towers(towers: Array, floor_y: float) -> Array:
	var out: Array = []
	for t: Dictionary in towers:
		var base: Vector3 = t.base
		var tip: Vector3 = t.tip
		var root := maxf(base.y,floor_y)
		var rise := tip.y-root
		var at := base.lerp(tip,(root-base.y)/(tip.y-base.y))
		out.append({"base":Vector3(at.x,root+rise*ROOT,at.z),"tip":tip+Vector3.UP*rise*OVER,"radius":float(t.radius)*GIRTHS})
	return out


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
		_ribbons.append({"box": box, "material": mat, "rate": TAU/float(axis.get("period",PERIOD[i%PERIOD.size()])), "spin": float(i)*2.1, "base": base, "tip": tip, "radius": radius, "turns": float(axis.get("turns",TURNS)), "hand": float(axis.get("hand",HAND[i%HAND.size()])), "rouse": 0.0})
	_haze_wait = 0.0
	_read_look()
	set_process(not _ribbons.is_empty())


func _process(delta: float) -> void:
	_flow = fmod(_flow+FLOW*delta,FLOW_WRAP)
	for r: Dictionary in _ribbons:
		r.spin = fmod(float(r.spin)+float(r.rate)*delta*(1.0+(ROUSE_SPIN-1.0)*float(r.rouse)),TAU)
		var mat: ShaderMaterial = r.material
		mat.set_shader_parameter("spin",r.spin)
		mat.set_shader_parameter("flow",_flow)
	_haze_wait -= delta
	if _haze_wait <= 0.0:
		_haze_wait = HAZE_EVERY
		_read_look()


## Spiral `i` roused, 0 to 1 (scripts/endless/peak_strike.gd): it turns faster
## and its tip draws in as the strike takes it. At 0 it is as it always is.
func rouse(i: int, k: float) -> void:
	if i < 0 or i >= _ribbons.size(): return
	var r: Dictionary = _ribbons[i]
	if is_equal_approx(float(r.rouse),k): return
	r.rouse = k
	(r.material as ShaderMaterial).set_shader_parameter("tip_left",1.0-ROUSE_TIP*k)


## How many ribbons stand.
func count() -> int:
	return _ribbons.size()


## The ribbon's centre line at `share` of its length, root to tip: where
## the shader has it now, its small wander left out. World.
func ribbon_at(i: int, share: float) -> Vector3:
	var r: Dictionary = _ribbons[i]
	var base: Vector3 = r.base
	var tip: Vector3 = r.tip
	var turns := float(r.turns)
	var k := share*(1.0+TIGHTEN)
	var h := (sqrt(1.0+4.0*TIGHTEN*k)-1.0)/(2.0*TIGHTEN)
	var ang := float(r.hand)*TAU*share*turns-float(r.spin)
	var out := Vector2.from_angle(ang)*float(r.radius)*lerpf(1.0,TAPER,pow(clampf(h,0.0,1.0),0.85))
	var at := base.lerp(tip,h)
	return at+Vector3(out.x,0.0,out.y)


## Spiral `i`'s way round, its turn so far (radians) and the cloud's flow.
func coil(i: int) -> Vector3:
	var r: Dictionary = _ribbons[i]
	return Vector3(float(r.hand),float(r.spin),_flow)


## Sets `mat`'s noise, cloud sheet and haze to the ribbons', for what is drawn
## in their look.
func lend_look(mat: ShaderMaterial) -> void:
	if _ribbons.is_empty(): return
	var from: ShaderMaterial = _ribbons[0].material
	for k: String in ["noise","cloud_shape","haze","haze_height","sea_y","sun_scatter"]:
		var v: Variant = from.get_shader_parameter(k)
		if v != null: mat.set_shader_parameter(k,v)


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
