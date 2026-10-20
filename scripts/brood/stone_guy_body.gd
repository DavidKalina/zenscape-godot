extends Node3D
## The stone guy's real body (docs/design/brood/body-contract.md): the
## Blender model (art/blender/brood/brood_build.py, assets/models/
## brood_stone_guy.glb) and its clips behind the contract's API. The mind
## (scripts/brood/stone_guy.gd) picks the clip and the time; this plays it.
## `--brood-greybox` keeps the old procedural block body instead.
##
## - **The API:** `setup(tall)`, `play(clip)`, `seek(clip, t)` (one-shots
##   the mind times itself), `advance(dt)` (s of the clip: the mind turns
##   distance into it for strides), signal `beat_reached(clip, beat)`,
##   `socket(name) -> Node3D`, `set_effect(name, on)`.
## - **Clips and beats** come from assets/models/brood_clips.json (written by
##   the build from the same table as the clips), so lengths and beats never
##   drift from the glb. A one-shot with a `then` goes on to it at its end.
## - **Cheap in a crowd:** one shared material, the AnimationPlayer stepped by
##   hand (no process callback of its own), beats only checked while
##   someone listens, and a guy far off steps every FAR_EVERY frames.
## - **Effects:** `daze` (his head lolls, round and round, a procedural layer
##   over the clip).

signal beat_reached(clip: String, beat: String)

const K = preload("res://scripts/brood/brood_knobs.gd")
const MODEL := "res://assets/models/brood_stone_guy.glb"
const TABLE := "res://assets/models/brood_clips.json"
## The cross-fade between clips (s of clip time).
const BLEND := 0.07
## Past FAR (m from the camera) he steps once every FAR_EVERY frames.
const FAR := 22.0
const FAR_EVERY := 3
## Of the greybox's GLOW: the baked stone is darker in its crevices, so a
## little more of its own light to read as well in shade.
const GLOW_MORE := 2.2
## The daze's loll: how far (rad) and how fast (rad/s).
const DAZE_LOLL := 0.35
const DAZE_RATE := 9.0

static var _scene: PackedScene = null
static var _table: Dictionary = {}
static var _mat: StandardMaterial3D = null
static var _frame := 0

var tall := 0.5
var clip := ""
var player: AnimationPlayer
var skel: Skeleton3D
var effects := {"daze": false}
var _len := 1.0
var _loop := false
var _beats := {}
var _then := ""
var _sockets := {}
var _head := -1
var _wait := 0.0
var _daze_t := 0.0
var _slot := 0

## True when the glb is there (else the greybox stays).
static func available() -> bool:
	return ResourceLoader.exists(MODEL) and FileAccess.file_exists(TABLE)

static func table() -> Dictionary:
	if _table.is_empty():
		var f := FileAccess.open(TABLE,FileAccess.READ)
		if f != null:
			var d: Variant = JSON.parse_string(f.get_as_text())
			if d is Dictionary: _table = d
	return _table

static func _load() -> void:
	if _scene != null: return
	_scene = load(MODEL) as PackedScene
	table()

func setup(h: float) -> void:
	_load()
	tall = h
	name = "Body"
	var model := _scene.instantiate() as Node3D
	model.scale = Vector3.ONE*h
	add_child(model)
	player = model.find_child("AnimationPlayer",true,false) as AnimationPlayer
	skel = model.find_child("Skeleton3D",true,false) as Skeleton3D
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_head = skel.find_bone("head")
	_slot = randi()%FAR_EVERY
	var clips: Dictionary = _table.get("clips",{})
	for c: String in clips:
		if not player.has_animation(c): continue
		var a := player.get_animation(c)
		var lm := Animation.LOOP_LINEAR if bool((clips[c] as Dictionary).get("loop",false)) else Animation.LOOP_NONE
		if a.loop_mode != lm: a.loop_mode = lm
	for mi: Node in model.find_children("*","MeshInstance3D",true,false):
		(mi as MeshInstance3D).material_override = _material((mi as MeshInstance3D).mesh.surface_get_material(0))
	play("idle",0.0)

## The one stone, shared by every guy: the bake's colour and normal, rough,
## with a little of its own light so he reads on a face in shade (the
## greybox's GLOW).
static func _material(from: Material) -> StandardMaterial3D:
	if _mat != null: return _mat
	_mat = StandardMaterial3D.new()
	var src := from as StandardMaterial3D
	if src != null:
		_mat.albedo_texture = src.albedo_texture
		_mat.normal_enabled = src.normal_texture != null
		_mat.normal_texture = src.normal_texture
		_mat.normal_scale = 1.0
	_mat.roughness = 0.95
	_mat.emission_enabled = true
	# (ADD, the default, adds the texture whole: he'd glow white.)
	_mat.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	_mat.emission = Color.WHITE
	_mat.emission_texture = _mat.albedo_texture
	_mat.emission_energy_multiplier = K.GLOW*GLOW_MORE
	return _mat

func clip_info(c: String) -> Dictionary:
	return (_table.get("clips",{}) as Dictionary).get(c,{})

## Plays `c` from its start, cross-faded from what he was doing.
func play(c: String, blend := BLEND) -> void:
	if c == clip: return
	clip = c
	var info := clip_info(c)
	_len = float(info.get("length",1.0))
	_loop = bool(info.get("loop",false))
	_beats = info.get("beats",{})
	_then = str(info.get("then",""))
	if player.has_animation(c): player.play(c,blend)

## `c` at time `t` (s) of it: the mind's own clock for a timed one-shot.
func seek(c: String, t: float, dt: float) -> void:
	play(c)
	var at := player.current_animation_position if player.is_playing() else 0.0
	advance(maxf(t-at,0.0),dt)

## Moves the clip on `d` s (negative: backwards, a loop only). `dt`: the
## frame's real time, for the far guys' skipping and the effects.
func advance(d: float, dt: float) -> void:
	_wait += d
	_daze_t += dt
	if not _due(): return
	d = _wait
	_wait = 0.0
	var before := player.current_animation_position
	player.advance(d)
	if not _beats.is_empty() and beat_reached.has_connections(): _send(before,player.current_animation_position,d)
	if not _loop and _then != "" and before+d >= _len-0.0001:
		play(_then)
	if effects.daze and _head >= 0: _loll()

func _due() -> bool:
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	if cam == null: return true
	if cam.global_position.distance_squared_to(global_position) < FAR*FAR: return true
	return (Engine.get_process_frames()+_slot)%FAR_EVERY == 0

func _send(before: float, now: float, d: float) -> void:
	for b: String in _beats:
		for t: float in _beats[b]:
			var hit := false
			if d >= 0.0:
				hit = (t > before and t <= now) or (now < before and (t > before or t <= now))
				if before == 0.0 and t == 0.0 and d > 0.0: hit = true
			else:
				hit = (t < before and t >= now) or (now > before and (t < before or t >= now))
			if hit: beat_reached.emit(clip,b)

## The head lolling round (over the clip's pose this frame).
func _loll() -> void:
	var a := _daze_t*DAZE_RATE
	var q := Quaternion(Vector3(cos(a),0.0,sin(a)).normalized(),DAZE_LOLL)
	skel.set_bone_pose_rotation(_head,skel.get_bone_pose_rotation(_head)*q)

func set_effect(n: String, on: bool) -> void:
	effects[n] = on

## A named attach point (hand_l, hand_r, head, eyes, load), made the first
## time it's asked for: a node on its bone.
func socket(n: String) -> Node3D:
	if _sockets.has(n): return _sockets[n]
	var s: Dictionary = (_table.get("sockets",{}) as Dictionary).get(n,{})
	if s.is_empty(): return null
	var bone := skel.find_bone(str(s.bone))
	var at: Array = s.at
	# Blender's model space (+z up, +y front) to the glb's (+y up, -z front).
	var p := Vector3(float(at[0]),float(at[2]),-float(at[1]))
	var att := BoneAttachment3D.new()
	att.name = "socket_"+n
	att.bone_idx = bone
	skel.add_child(att)
	var mark := Node3D.new()
	mark.name = n
	mark.position = skel.get_bone_global_rest(bone).affine_inverse()*p
	att.add_child(mark)
	_sockets[n] = mark
	return mark
