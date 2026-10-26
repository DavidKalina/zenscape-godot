extends Node3D
## Where the rival is going, in the world (scripts/endless/rival_race.gd
## shows it; rival_line.gd `intent` says it):
## - the trail: small bone-white motes along where it will fly the next few
##   seconds, drifting the way it goes, faint near it and fading out ahead;
##   fainter still down an open valley with no opening picked.
## - the gate: four corner ticks round the mouth of the opening it has
##   picked (an arch, a canyon, a hall or a tunnel), brightening as it
##   nears, gone once it is in.
## Drawn in the world, so the land hides them, never through it. They keep
## at least a few pixels on screen however far they are.

const BONE := Color(0.93,0.87,0.72)
const GOLD := Color("ffd36b")
## The motes: spacing (m), drift (m/s), size (m, and at least this share of
## their distance: a few px), alpha, fading in over FADE_IN m from the rival
## and out over the last FADE_OUT share; down an open valley OPEN_ALPHA.
const MOTE_STEP := 22.0
const DRIFT := 30.0
const MOTE_M := 0.55
const MOTE_FAR := 0.0035
const MOTE_ALPHA := 0.55
const OPEN_ALPHA := 0.3
const FADE_IN := 35.0
const FADE_OUT := 0.35
## The gate: its ticks' share of the side, their width (m, and at least this
## share of the distance), alpha far and near (NEAR_AT m to go).
const TICK := 0.32
const TICK_M := 0.35
const TICK_FAR := 0.0032
const GATE_ALPHA := Vector2(0.45,0.85)
const NEAR_AT := 250.0

var _mesh := ImmediateMesh.new()
var _clock := 0.0
## For checks: motes and gate ticks drawn the last frame.
var motes := 0
var gate_shown := false

func _init() -> void:
	name = "RivalMarks"
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.disable_fog = true
	mi.material_override = mat
	# Its box is wherever the race is: never culled.
	mi.extra_cull_margin = 16384.0
	add_child(mi)

## One frame: `intent` rival_line.gd's ({} none), `alpha` the whole (0..1).
func step(delta: float, camera: Camera3D, intent: Dictionary, alpha: float) -> void:
	_clock += delta
	_mesh.clear_surfaces()
	motes = 0
	gate_shown = false
	if camera == null or intent.is_empty() or alpha <= 0.0: return
	var eye := camera.global_position
	var right := camera.global_basis.x
	var up := camera.global_basis.y
	var began := false
	var trail: PackedVector3Array = intent.get("trail",PackedVector3Array())
	if trail.size() >= 2:
		var lens := PackedFloat32Array([0.0])
		for i in range(1,trail.size()): lens.append(lens[i-1]+trail[i].distance_to(trail[i-1]))
		var total := lens[lens.size()-1]
		var a0 := (OPEN_ALPHA if bool(intent.get("open",false)) else MOTE_ALPHA)*alpha
		var s := fmod(_clock*DRIFT,MOTE_STEP)
		var j := 0
		while s < total:
			while j < lens.size()-2 and lens[j+1] < s: j += 1
			var u := (s-lens[j])/maxf(lens[j+1]-lens[j],0.001)
			var c := trail[j].lerp(trail[j+1],u)
			var a := a0*smoothstep(0.0,FADE_IN,s)*(1.0-smoothstep(total*(1.0-FADE_OUT),total,s))
			if a > 0.01:
				if not began:
					_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
					began = true
				var r := maxf(MOTE_M,eye.distance_to(c)*MOTE_FAR)
				_diamond(c,right*r,up*r*1.4,Color(BONE.r,BONE.g,BONE.b,a))
				motes += 1
			s += MOTE_STEP
	var gate: Dictionary = intent.get("gate",{})
	if not gate.is_empty():
		if not began:
			_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			began = true
		_gate(gate,eye,alpha)
		gate_shown = true
	if began: _mesh.surface_end()

## A mote: a small diamond facing the eye.
func _diamond(c: Vector3, x: Vector3, y: Vector3, col: Color) -> void:
	_tri(c+y,c+x,c-y,col)
	_tri(c-y,c-x,c+y,col)

## The gate's four corner ticks, in the mouth's plane (across its way).
func _gate(g: Dictionary, eye: Vector3, alpha: float) -> void:
	var c: Vector3 = g.p
	var dir: Vector3 = g.dir
	var across := dir.cross(Vector3.UP).normalized()
	if across.length() < 0.5: across = Vector3.RIGHT
	var hw := float(g.half_w)
	var hh := float(g.half_h)
	var near := 1.0-smoothstep(0.0,NEAR_AT,float(g.left))
	var col := BONE.lerp(GOLD,near*0.6)
	col.a = lerpf(GATE_ALPHA.x,GATE_ALPHA.y,near)*alpha*(0.85+0.15*sin(_clock*TAU*0.8))
	var w := maxf(TICK_M,eye.distance_to(c)*TICK_FAR)
	var t := minf(hw,hh)*TICK*2.0
	for sx: float in [-1.0,1.0]:
		for sy: float in [-1.0,1.0]:
			var corner := c+across*hw*sx+Vector3.UP*hh*sy
			_bar(corner,corner-across*sx*t,Vector3.UP*w*0.5,col)
			_bar(corner+across*sx*w*0.5,corner-Vector3.UP*sy*t,across*w*0.5,col)

## A flat bar from `a` to `b`, `half` its half width.
func _bar(a: Vector3, b: Vector3, half: Vector3, col: Color) -> void:
	_tri(a-half,a+half,b+half,col)
	_tri(b+half,b-half,a-half,col)

func _tri(a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	for v: Vector3 in [a,b,c]:
		_mesh.surface_set_color(col)
		_mesh.surface_add_vertex(v)
