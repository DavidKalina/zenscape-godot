extends Node3D
## Spindrift: snow blowing off the crown's tips and the massif's high ridges, a
## long thin veil streaming one way on the land's wind (spec-crown.md, lane
## flags). One mesh of ribbons, one draw, one shader
## (shaders/peak_spindrift.gdshader), which does all the moving and turns the
## veils with zs_wind_direction, so past the build the only CPU is a look at the
## sky's haze twice a second. No collision: it is air. --spindrift=0 none.
##
## Where it starts comes off the land as it stands, not from a table of tips: the
## towers' axes and tops, and the highest sharp ridges a scan of the massif's own
## height finds, so a change in the rock moves the veils with it.

const SHADER := preload("res://shaders/peak_spindrift.gdshader")
const CumulusNoise := preload("res://scripts/cumulus_noise.gd")
const LaunchArgs := preload("res://scripts/launch_args.gd")

## Over the cloud sheet (EndlessClouds.RENDER_PRIORITY), under the spirals.
const PRIORITY := 7
## The ridge scan: the massif's (a, v) box, the grid (m), the least height over
## the sea and the least a top must stand over the grid round it (m), how many
## roots, and how far apart.
const SCAN_A := Vector2(-760.0,2240.0)
const SCAN_V := Vector2(-1060.0,860.0)
const SCAN_STEP := 40.0
const SCAN_LEAST := 760.0
const SCAN_STAND := 8.0
const RIDGES := 13
const RIDGE_APART := 210.0
## Sampled along a ridge to find which way it runs (m).
const RIDGE_FEEL := 70.0
## Ribbons at a ridge root, spread along the ridge (m apart).
const RIDGE_RIBBONS := 3
const RIDGE_SPREAD := 34.0
## A ribbon: length, and its half width at the root and at the tail (m).
const TIP_LONG := Vector2(520.0,900.0)
const TIP_WIDE := Vector2(5.0,44.0)
const RIDGE_LONG := Vector2(300.0,620.0)
const RIDGE_WIDE := Vector2(5.0,38.0)
## Ribbons at a tip.
const TIP_RIBBONS := 3
## Segments of a ribbon.
const SEGMENTS := 14
## How often the sky's haze is read (s).
const HAZE_EVERY := 0.5

## What the scan found, for stills: [{at, ridge}].
var roots: Array = []
var stats := {"roots":0, "ribbons":0, "verts":0, "tris":0, "build_ms":0.0}

var _host: Node
var _mat: ShaderMaterial
var _wait := 0.0
var _v := PackedVector3Array()
var _uv := PackedVector2Array()
var _c0 := PackedFloat32Array()
var _c1 := PackedFloat32Array()
var _ix := PackedInt32Array()
var _box := AABB()
var _rng := RandomNumberGenerator.new()

static func wanted() -> bool:
	return not "--spindrift=0" in LaunchArgs.user_args()

## `host` is the study (its look gives the haze); `towers` may be null.
func setup(host: Node, peak: RefCounted, ground: Callable, towers: Node3D, seed_value: int, sea_y: float) -> void:
	name = "PeakSpindrift"
	_host = host
	_rng.seed = hash([seed_value,"peak/spindrift"])
	var t0 := Time.get_ticks_usec()
	if towers != null:
		for ax: Dictionary in towers.axes(): _tip(ax,towers)
	for r: Dictionary in _scan(peak,ground,sea_y): _ridge(r)
	_commit()
	stats.roots = roots.size()
	stats.build_ms = (Time.get_ticks_usec()-t0)/1000.0
	_read_look()

## The highest sharp ridges in the massif: local tops over the grid, each with
## the way its ridge lies across (a unit XZ, the way a wind blows off it).
func _scan(peak: RefCounted, ground: Callable, sea_y: float) -> Array:
	var cols := int((SCAN_A.y-SCAN_A.x)/SCAN_STEP)+1
	var rows := int((SCAN_V.y-SCAN_V.x)/SCAN_STEP)+1
	var h := PackedFloat32Array()
	h.resize(cols*rows)
	for i in cols:
		for j in rows:
			var w: Vector2 = peak.world(SCAN_A.x+i*SCAN_STEP,SCAN_V.x+j*SCAN_STEP)
			h[i*rows+j] = float(ground.call(w.x,w.y))
	var found: Array = []
	for i in range(1,cols-1):
		for j in range(1,rows-1):
			var y := h[i*rows+j]
			if y-sea_y < SCAN_LEAST: continue
			var top := true
			var ring := 0.0
			for di in range(-1,2):
				for dj in range(-1,2):
					var o := h[(i+di)*rows+j+dj]
					if o > y: top = false
					ring += o
			if not top: continue
			if y-(ring-y)/8.0 < SCAN_STAND: continue
			var w: Vector2 = peak.world(SCAN_A.x+i*SCAN_STEP,SCAN_V.x+j*SCAN_STEP)
			found.append({"at":Vector3(w.x,y,w.y)})
	found.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p.at.y) > float(q.at.y))
	var out: Array = []
	for f: Dictionary in found:
		if out.size() >= RIDGES: break
		var at: Vector3 = f.at
		var near := false
		for o: Dictionary in out:
			if Vector2(at.x,at.z).distance_to(Vector2(o.at.x,o.at.z)) < RIDGE_APART: near = true
		if near: continue
		# It runs where the ground falls least to both sides.
		var best := -INF
		var run := Vector2.RIGHT
		for b in 8:
			var d := Vector2.from_angle(PI*b/8.0)
			var s := float(ground.call(at.x+d.x*RIDGE_FEEL,at.z+d.y*RIDGE_FEEL))+float(ground.call(at.x-d.x*RIDGE_FEEL,at.z-d.y*RIDGE_FEEL))
			if s > best:
				best = s
				run = d
		out.append({"at":at,"ridge":Vector2(-run.y,run.x),"run":run})
	return out

## Ribbons off a tower's top, always on: a tip has no lee of its own.
func _tip(ax: Dictionary, towers: Node3D) -> void:
	var tip: Vector3 = ax.tip
	var y: float = towers.top_near(tip,14.0)
	if y < tip.y-90.0 or y > tip.y+10.0: y = tip.y-30.0
	var at := Vector3(tip.x,y-2.0,tip.z)
	roots.append({"at":at,"ridge":Vector2.ZERO})
	for i in TIP_RIBBONS:
		var off := Vector3(_rng.randf_range(-10.0,10.0),_rng.randf_range(-16.0,2.0),_rng.randf_range(-10.0,10.0))
		_ribbon(at+off,_rng.randf_range(TIP_LONG.x,TIP_LONG.y),TIP_WIDE*_rng.randf_range(0.7,1.2),Vector2.ZERO,_rng.randf_range(0.03,0.09),_rng.randf_range(0.8,1.0))

## Ribbons side by side along a ridge, seen only with the wind across it.
func _ridge(r: Dictionary) -> void:
	roots.append(r)
	var at: Vector3 = r.at
	var run: Vector2 = r.run
	for i in RIDGE_RIBBONS:
		var along := (i-(RIDGE_RIBBONS-1)*0.5)*RIDGE_SPREAD+_rng.randf_range(-9.0,9.0)
		var p := at+Vector3(run.x*along,_rng.randf_range(-4.0,5.0),run.y*along)
		_ribbon(p,_rng.randf_range(RIDGE_LONG.x,RIDGE_LONG.y),RIDGE_WIDE*_rng.randf_range(0.7,1.25),r.ridge,_rng.randf_range(0.02,0.1),_rng.randf_range(1.0,1.35))

## One ribbon from `root`: `wide` its half widths, `ridge` the way across its
## ridge (ZERO: none), `rise` its climb per metre downwind.
func _ribbon(root: Vector3, length: float, wide: Vector2, ridge: Vector2, rise: float, power: float) -> void:
	var seed01 := _rng.randf()
	var first := _v.size()
	for k in SEGMENTS+1:
		# Closer together near the root, where it bends the most.
		var s := pow(float(k)/SEGMENTS,1.4)
		for side: float in [-1.0,1.0]:
			_v.append(root)
			_uv.append(Vector2(s,side))
			for x: float in [length,wide.x,wide.y,seed01]: _c0.append(x)
			for x: float in [ridge.x,ridge.y,rise,power]: _c1.append(x)
		if k > 0:
			var i := first+(k-1)*2
			for q: int in [i,i+1,i+3,i,i+3,i+2]: _ix.append(q)
	var reach := length*1.15+wide.y+40.0
	var b := AABB(root-Vector3(reach,reach*0.3,reach),Vector3(reach*2.0,reach*0.6,reach*2.0))
	_box = b if _box.size == Vector3.ZERO else _box.merge(b)
	stats.ribbons = int(stats.ribbons)+1

func _commit() -> void:
	if _ix.is_empty(): return
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _v
	arrays[Mesh.ARRAY_TEX_UV] = _uv
	arrays[Mesh.ARRAY_CUSTOM0] = _c0
	arrays[Mesh.ARRAY_CUSTOM1] = _c1
	arrays[Mesh.ARRAY_INDEX] = _ix
	var format := (Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT)|(Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},format)
	mesh.custom_aabb = _box
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.render_priority = PRIORITY
	var inst := MeshInstance3D.new()
	inst.name = "Veils"
	inst.mesh = mesh
	inst.material_override = _mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(inst)
	stats.verts = _v.size()
	stats.tris = _ix.size()/3

func _process(delta: float) -> void:
	_wait -= delta
	if _wait <= 0.0:
		_wait = HAZE_EVERY
		_read_look()

## The noise, once made, and the haze the cloud sheet draws with, for the veils
## to sit in the same air (as PeakSpirals does).
func _read_look() -> void:
	if _mat == null: return
	var noise: Texture = CumulusNoise.request()
	if noise != null: _mat.set_shader_parameter("noise",noise)
	var inst := get_child(0) as MeshInstance3D
	if inst != null: inst.visible = noise != null
	if _host == null or _host.get("look") == null or _host.look.clouds == null: return
	var sheet: ShaderMaterial = _host.look.clouds.material
	var shape: Texture2D = _host.look.clouds.effect.resolved_b
	if shape != null: _mat.set_shader_parameter("cloud_shape",shape)
	if sheet != null:
		for k: String in ["haze","haze_height","sea_y","sun_scatter"]:
			var v: Variant = sheet.get_shader_parameter(k)
			if v != null: _mat.set_shader_parameter(k,v)
