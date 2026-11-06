extends Node3D
## The elk's body (docs/design/endless-flight/spec-wild-kit-elk.md, The
## contract): the glb built by art/blender/elk/elk_build.py
## (assets/models/elk/elk.glb), behind the API the mind
## (scripts/endless/kinds/ground_escort.gd) calls, the same API as its
## stand-in (scripts/endless/kinds/escort_standin.gd).
##
## The frame: origin on the ground midway between the fore and hind hooves,
## -Z its heading. The glb is built in plane spans and scaled here by
## WorldScale.span. The clips' lengths, loops, ground and beats come from the
## build's table beside the glb (elk_clips.json; glTF carries no markers).
##
## It plays the way AnimationPlayer plays (spec, How the API plays): `play`
## of the clip already playing keeps its phase and sets the rate; a finished
## one-shot starts over; a beat at time 0 fires on `play`; every beat fires
## once per pass or cycle. The AnimationPlayer is advanced by hand in this
## node's _process, so the mind stops a sleeping body by turning its
## process_mode off, and the head's look is laid over the clip each frame
## after it.

signal beat_reached(name: String)

const WorldScale = preload("res://scripts/world_scale.gd")

const MODEL := "res://assets/models/elk/elk.glb"
const TABLE := "res://assets/models/elk/elk_clips.json"
const VARIANTS := ["bull","cow"]

## The neck's chain the look turns, root first, and each bone's share of
## the turn (yaw) and of the nod (pitch).
const LOOK_BONES := ["neck1","neck2","head"]
const LOOK_YAW_SHARE := [0.3,0.3,0.4]
const LOOK_PITCH_SHARE := [0.15,0.25,0.6]
## How far the head turns from the body's heading, and lifts or drops off
## level (rad).
const LOOK_YAW_MAX := 2.0
const LOOK_UP_MAX := 0.75
const LOOK_DOWN_MAX := 0.6

## Detail by the camera's distance, in spans (the elk scales with the span,
## so each cut falls at the same size on screen; at 1440x900 and the flight's
## field of view an elk is about 9 px tall at NEAR, 3.5 at MID, 2 at FINE,
## 1.5 at FAR). Inside NEAR the clip is posed every frame, to MID every 2nd,
## past MID or off screen every 4th (time and beats still run every frame).
## Past FINE the antlers, the mane, the dust and the shadow go; past FAR the
## whole elk (the meshes' visibility ranges). The mesh LODs come from the
## import (generate_lods) and need nothing here.
const NEAR := 40.0
const MID := 100.0
const FINE := 160.0
const FAR := 220.0
## Each mesh's visibility range, in spans.
const RANGE := {"ElkBody":FAR,"Antlers":FINE,"Mane":FINE}
## The import's LODs switched at twice the distance the engine would pick:
## its coarsest levels drop legs (the body's 82 and 40 triangles) and break
## the antlers (44), and at 2 those fall past FAR and FINE, so never show.
const LOD_BIAS := 2.0
## The sphere tested against the camera's view, in spans: round the body's
## middle, wide enough to keep its shadow (a low sun's) in.
const VIEW_RADIUS := 1.2

## The dust: puffs a body keeps (they come round in turn), their life (s),
## and their size at the start and end of it, in spans.
const PUFFS := 8
const PUFF_LIFE := 0.9
const PUFF_FROM := 0.3
const PUFF_TO := 0.9
## Which feet strike on each dust beat, the second a moment after the first
## (s), and the puff's size against the gallop's.
const DUST_BEATS := {
	"gallop.plant": [["foot_fr",0.0,1.0]],
	"sprint.plant": [["foot_fl",0.0,1.35],["foot_fr",0.0,1.15]],
	"leap.land": [["foot_fl",0.0,1.4],["foot_fr",0.015,1.3]],
}

## The table, the model and the shared materials: loaded once for every elk.
static var _table := {}
static var _scene: PackedScene
static var _coat: StandardMaterial3D
static var _puff_mesh: QuadMesh
static var _puff_mat: ShaderMaterial
## The camera's view planes, worked out once a frame for every elk.
static var _view_planes: Array[Plane] = []
static var _view_frame := -1
static var _view_cam := 0
## Spreads the far elk's posing over the frames.
static var _count := 0

var variant := "cow"
var clip := ""
var rate := 1.0
var time := 0.0

var _model: Node3D
var _ap: AnimationPlayer
var _skel: Skeleton3D
var _sockets := {}
var _meshes := {}
var _done := false
var _look_at := Vector3.ZERO
var _look_weight := 0.0
var _look_idx: Array[int] = []
var _look_rot: Array[Quaternion] = []
var _gaze_local := Vector3.FORWARD
var _eye_local := Vector3.ZERO
var _effects := {"dust":false}
var _puffs: Array[MeshInstance3D] = []
var _puff_age: Array[float] = []
var _puff_size: Array[float] = []
var _puff_next := 0
var _puff_seed := 0.0
var _pending: Array = []
## Pose every `_step`-th frame (1, 2 or 4), offset by `_phase`; the clip's
## time owed to the AnimationPlayer since it was last posed (s, and s times
## the rate).
var _step := 1
var _phase := 0
var _owed := 0.0
var _owed_play := 0.0
## The look is laid on the bones now; past FINE (no shadow, no dust).
var _looked := false
var _fine := true

func _init() -> void:
	_load_shared()
	_phase = _count
	_count += 1
	_model = _scene.instantiate() as Node3D
	_model.name = "Elk"
	_model.scale = Vector3.ONE*WorldScale.span
	add_child(_model)
	_ap = _model.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer
	_ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_skel = _model.find_children("*","Skeleton3D",true,false)[0] as Skeleton3D
	for n: Node in _model.find_children("*","MeshInstance3D",true,false):
		var mi := n as MeshInstance3D
		mi.material_override = _coat
		mi.visibility_range_end = float(RANGE.get(String(mi.name),FAR))*WorldScale.span
		mi.lod_bias = LOD_BIAS
		_meshes[String(mi.name)] = mi
	var where: Dictionary = _table.get("sockets",{})
	for key: String in where:
		var s := _model.find_child("socket_"+key,true,false) as Node3D
		if s != null: _sockets[key] = s
	for bone: String in LOOK_BONES:
		var i := _skel.find_bone(bone)
		_look_idx.append(i)
		_look_rot.append(_skel.get_bone_pose_rotation(i))
	# The head's gaze at rest is level and dead ahead (-Z in the model); held
	# in the head bone's frame, it turns with the head as the clips move it.
	var head_rest := _skel.get_bone_global_rest(_look_idx[2])
	_gaze_local = (head_rest.basis.inverse()*Vector3.FORWARD).normalized()
	var eye := _sockets.get("head") as Node3D
	if eye != null: _eye_local = eye.position
	set_variant(variant)

func _ready() -> void:
	# Posed at once, so a body put to sleep before its first frame stands in
	# its clip, not the bind pose.
	if clip != "": _advance()

func _notification(what: int) -> void:
	if what == NOTIFICATION_DISABLED:
		for mi in _puffs: mi.visible = false
		for k in range(_puff_age.size()): _puff_age[k] = PUFF_LIFE
		_pending.clear()

# --- The API -------------------------------------------------------------

## Plays `name` at `play_rate`, crossfading from the pose shown over `blend`
## s. The clip already playing keeps its phase and takes the new rate.
func play(name: String, play_rate := 1.0, blend := 0.15) -> void:
	if not _clips().has(name):
		push_warning("elk body: no clip '%s'" % name)
		return
	rate = play_rate
	_ap.speed_scale = maxf(play_rate,0.0)
	if name == clip and not _done: return
	# The clip shown caught up first, so the crossfade starts from where it is.
	if _owed > 0.0: _advance()
	# AnimationPlayer's blend runs at its speed_scale: scaled back to seconds.
	_ap.play(name,maxf(blend,0.0)*maxf(play_rate,0.01))
	clip = name
	time = 0.0
	_done = false
	_fire_beats(-1.0,0.0)
	if is_inside_tree(): _advance()

func clip_length(name: String) -> float:
	var c: Dictionary = _clips().get(name,{})
	return float(c.get("length",0.0))

func socket(name: String) -> Node3D:
	return _sockets.get(name)

## `bull` (antlers and the shaggy mane) or `cow`; set once at spawn.
func set_variant(name: String) -> void:
	if not name in VARIANTS:
		push_warning("elk body: no variant '%s'" % name)
		return
	variant = name
	var bull := name == "bull"
	for part: String in ["Antlers","Mane"]:
		var mi: MeshInstance3D = _meshes.get(part)
		if mi != null: mi.visible = bull

## `dust`: a puff of grass and dust at a foot on each gallop.plant,
## sprint.plant and leap.land while on.
func set_effect(name: String, on: bool) -> void:
	_effects[name] = on

## Turns the neck and head toward `target` (world) by `weight` (0 to 1),
## laid over the clip.
func look_at_world(target: Vector3, weight: float) -> void:
	_look_at = target
	_look_weight = clampf(weight,0.0,1.0)

# --- Time ----------------------------------------------------------------

func _process(delta: float) -> void:
	var t0 := Time.get_ticks_usec() if FrameLog.on else 0
	_tick(delta)
	if FrameLog.on: FrameLog.add(&"herd_bodies",float(Time.get_ticks_usec()-t0)/1000.0)

## One step of `delta` s: the clip, its beats, the look, the dust. The
## clip's time and beats run every step; the pose only on the frames its
## distance calls for (and when a one-shot ends).
func _tick(delta: float) -> void:
	_detail()
	if clip != "" and not _done:
		var c: Dictionary = _clips()[clip]
		var length := float(c.length)
		var was := time
		time += delta*rate
		if bool(c.loop):
			if time >= length:
				_fire_beats(was,length)
				time = fmod(time,length)
				_fire_beats(-1.0,time)
			else:
				_fire_beats(was,time)
		else:
			if time >= length:
				time = length
				_done = true
			_fire_beats(was,time)
		_owed += delta
		_owed_play += delta*maxf(rate,0.0)
		if _done or _due(): _advance()
	elif _due():
		_pose_look()
	_dust_step(delta)

func _due() -> bool:
	return _step <= 1 or (Engine.get_process_frames()+_phase)%_step == 0

## The AnimationPlayer moved on by the time owed it (at the rates the clip
## ran at over it), the clip's neck and head kept, and the look laid over
## them.
func _advance() -> void:
	if _owed > 0.0:
		_ap.speed_scale = _owed_play/_owed
		_ap.advance(_owed)
		_ap.speed_scale = maxf(rate,0.0)
	else:
		_ap.advance(0.0)
	_owed = 0.0
	_owed_play = 0.0
	for k in range(_look_idx.size()):
		_look_rot[k] = _skel.get_bone_pose_rotation(_look_idx[k])
	_looked = false
	_pose_look()

## How often to pose and what to show, from the camera's distance and view.
func _detail() -> void:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null:
		_step = 1
		return
	var s := WorldScale.span
	var mid := global_position+global_transform.basis.y.normalized()*0.4*s
	var d := cam.global_position.distance_to(mid)/s
	_step = 1 if d < NEAR else (2 if d < MID else 4)
	if _step < 4 and not _in_view(cam,mid,VIEW_RADIUS*s): _step = 4
	var fine := d < FINE
	if fine != _fine:
		_fine = fine
		var cast := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if fine else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for mi: MeshInstance3D in _meshes.values(): mi.cast_shadow = cast

## Whether a sphere is inside the camera's view (its planes face out).
static func _in_view(cam: Camera3D, at: Vector3, radius: float) -> bool:
	var frame := Engine.get_process_frames()
	if frame != _view_frame or cam.get_instance_id() != _view_cam:
		_view_frame = frame
		_view_cam = cam.get_instance_id()
		_view_planes = cam.get_frustum()
	for p: Plane in _view_planes:
		if p.distance_to(at) > radius: return false
	return true

## Each beat of the clip in (from, to].
func _fire_beats(from: float, to: float) -> void:
	var beats: Dictionary = _clips()[clip].get("beats",{})
	for beat: String in beats:
		for at: float in beats[beat]:
			if at > from and at <= to:
				_on_beat(beat)
				beat_reached.emit(beat)

func _on_beat(name: String) -> void:
	if not _effects.dust or not DUST_BEATS.has(name): return
	for strike: Array in DUST_BEATS[name]:
		if float(strike[1]) <= 0.0: _puff(str(strike[0]),float(strike[2]))
		else: _pending.append([float(strike[1]),str(strike[0]),float(strike[2])])

# --- The look ------------------------------------------------------------

## The clip's neck and head, then the look turned into them: the gaze
## (the head's level-at-rest forward) swung toward the target by the
## weight, the turn spread down the chain (yaw about the body's up, the nod
## about the gaze's own level right).
func _pose_look() -> void:
	if _look_weight <= 0.001 or not is_inside_tree():
		# Left alone when no look is laid on, so a held pose costs nothing.
		if _looked:
			for k in range(_look_idx.size()):
				_skel.set_bone_pose_rotation(_look_idx[k],_look_rot[k])
			_looked = false
		return
	for k in range(_look_idx.size()):
		_skel.set_bone_pose_rotation(_look_idx[k],_look_rot[k])
	_looked = true
	var head := _skel.get_bone_global_pose(_look_idx[2])
	var to := _skel.global_transform.affine_inverse()*_look_at-head*_eye_local
	var gaze := head.basis*_gaze_local
	var want_yaw := clampf(atan2(-to.x,-to.z),-LOOK_YAW_MAX,LOOK_YAW_MAX)
	var want_pitch := clampf(atan2(to.y,maxf(Vector2(to.x,to.z).length(),1e-4)),-LOOK_DOWN_MAX,LOOK_UP_MAX)
	var gaze_yaw := atan2(-gaze.x,-gaze.z)
	var gaze_pitch := atan2(gaze.y,maxf(Vector2(gaze.x,gaze.z).length(),1e-4))
	var turn := wrapf(want_yaw-gaze_yaw,-PI,PI)*_look_weight
	var nod := (want_pitch-gaze_pitch)*_look_weight
	var yaw := gaze_yaw
	for k in range(_look_idx.size()):
		var i := _look_idx[k]
		var parent := _skel.get_bone_global_pose(_skel.get_bone_parent(i))
		var own := _skel.get_bone_global_pose(i)
		yaw += turn*float(LOOK_YAW_SHARE[k])
		var right := Vector3(cos(yaw),0.0,-sin(yaw))
		var b := Basis(right,nod*float(LOOK_PITCH_SHARE[k]))*Basis(Vector3.UP,turn*float(LOOK_YAW_SHARE[k]))*own.basis
		_skel.set_bone_pose_rotation(i,(parent.basis.inverse()*b).get_rotation_quaternion())

# --- Dust ----------------------------------------------------------------

## A puff of grass and dust thrown up at the foot socket `foot`, `size`
## times the gallop's. Puffs live in the world (top level), so a runner
## leaves them behind.
func _puff(foot: String, size := 1.0) -> void:
	var at := socket(foot)
	if at == null or not is_inside_tree() or not _fine: return
	if _puffs.is_empty():
		for k in range(PUFFS):
			var mi := MeshInstance3D.new()
			mi.name = "Puff%d" % k
			mi.mesh = _puff_mesh
			mi.material_override = _puff_mat
			mi.top_level = true
			mi.visible = false
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end = FINE*WorldScale.span
			add_child(mi)
			_puffs.append(mi)
			_puff_age.append(PUFF_LIFE)
			_puff_size.append(1.0)
	var k := _puff_next
	_puff_next = (_puff_next+1)%PUFFS
	_puff_age[k] = 0.0
	_puff_size[k] = size
	var mi := _puffs[k]
	var s := WorldScale.span
	# Kicked up and back from the strike.
	var back := global_transform.basis.z.normalized()
	mi.global_position = at.global_position+Vector3.UP*0.12*s*size+back*0.05*s
	mi.scale = Vector3.ONE*PUFF_FROM*size*s
	mi.set_instance_shader_parameter(&"age",0.0)
	# Each puff its own lumps: a golden-ratio walk, the same on every machine.
	_puff_seed = fmod(_puff_seed+0.618034,1.0)
	mi.set_instance_shader_parameter(&"seed",_puff_seed)
	mi.visible = true

func _dust_step(delta: float) -> void:
	if not _pending.is_empty(): _strike_late(delta)
	var s := WorldScale.span
	for k in range(_puffs.size()):
		if _puff_age[k] >= PUFF_LIFE: continue
		_puff_age[k] += delta
		var u := minf(_puff_age[k]/PUFF_LIFE,1.0)
		var mi := _puffs[k]
		var grow := 1.0-(1.0-u)*(1.0-u)
		mi.scale = Vector3.ONE*lerpf(PUFF_FROM,PUFF_TO,grow)*_puff_size[k]*s
		mi.global_position.y += delta*0.25*s*(1.0-u)
		mi.set_instance_shader_parameter(&"age",u)
		if u >= 1.0: mi.visible = false

## The second foot of a strike, a moment after the first.
func _strike_late(delta: float) -> void:
	for p: Array in _pending.duplicate():
		p[0] = float(p[0])-delta
		if float(p[0]) <= 0.0:
			_pending.erase(p)
			_puff(str(p[1]),float(p[2]))

# --- Shared --------------------------------------------------------------

func _clips() -> Dictionary:
	return _table.get("clips",{})

static func _load_shared() -> void:
	if _scene != null: return
	var text := FileAccess.get_file_as_string(TABLE)
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("elk body: can't read %s" % TABLE)
		parsed = {"clips":{},"sockets":{}}
	_table = parsed
	_scene = load(MODEL) as PackedScene
	# The import makes every clip play once; the table says which loop.
	var probe := _scene.instantiate()
	var ap := probe.find_children("*","AnimationPlayer",true,false)[0] as AnimationPlayer
	for name: String in _table.clips:
		if ap.has_animation(name):
			ap.get_animation(name).loop_mode = Animation.LOOP_LINEAR if bool(_table.clips[name].loop) else Animation.LOOP_NONE
	probe.free()
	# The coat is painted in the mesh's vertex colours (no textures).
	_coat = StandardMaterial3D.new()
	_coat.vertex_color_use_as_albedo = true
	_coat.roughness = 0.9
	_coat.metallic_specular = 0.3
	_puff_mesh = QuadMesh.new()
	_puff_mesh.size = Vector2.ONE
	_puff_mat = ShaderMaterial.new()
	_puff_mat.shader = _puff_shader()

## The puff: a billboard of a few soft lumps of dust, flecked with grass,
## that spread and thin over its life (instance `age` 0 to 1, `seed`).
static func _puff_shader() -> Shader:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled, depth_draw_never, shadows_disabled, specular_disabled;

instance uniform float age = 1.0;
instance uniform float seed = 0.0;
uniform vec3 dust : source_color = vec3(0.68, 0.58, 0.42);
uniform vec3 grass : source_color = vec3(0.30, 0.42, 0.14);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y = -p.y;
	float d = 0.0;
	vec3 n = vec3(0.0);
	float wsum = 0.0;
	// Five lumps of mixed size, scattered by the seed, that drift apart and
	// up as it spreads, shaded as one soft heap (each lump a ball, their
	// normals blended where they meet); the edge eats in with age, so it
	// thins to wisps rather than fading flat.
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		vec2 h = vec2(hash(vec2(seed, fi)), hash(vec2(fi, seed + 3.1)));
		vec2 c = vec2(h.x - 0.5, (h.y - 0.5) * 0.6 - 0.1 + 0.06 * fi) * (0.75 + 0.55 * age);
		float r = mix(0.24, 0.48, hash(vec2(seed + fi, 9.7))) * (i == 0 ? 1.15 : 1.0);
		vec2 q = (p - c) / r;
		float k = 1.0 - length(q);
		d = max(d, k);
		float w = pow(max(k + 0.15, 0.0), 3.0);
		n += vec3(q, sqrt(max(1.0 - dot(q, q), 0.0))) * w;
		wsum += w;
	}
	float edge = age * 0.55;
	float body = smoothstep(edge, edge + 0.22, d);
	// Grass flecks thrown up round it.
	vec2 g = (p + 1.0) * 5.0;
	vec2 cell = floor(g);
	vec2 at = 0.5 + (vec2(hash(cell + seed * 13.0), hash(cell.yx + seed * 7.0)) - 0.5) * 0.6;
	float fleck = step(0.8, hash(cell + floor(seed * 37.0))) * step(length(fract(g) - at), 0.13);
	fleck *= step(-0.3, d) * (1.0 - smoothstep(0.25, 0.7, age)) * (1.0 - body);
	NORMAL = normalize(n / max(wsum, 1e-4) + vec3(0.0, 0.0, 0.35));
	ALBEDO = mix(dust, grass, fleck);
	ROUGHNESS = 1.0;
	ALPHA = max(body * 0.88, fleck) * (1.0 - smoothstep(0.5, 1.0, age));
}
"""
	return sh
