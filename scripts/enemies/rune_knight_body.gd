extends Node3D
## The rune knight's real body (docs/design/rune-knight/spec-rune-knight-body.md,
## task 6): the Blender model in the Olmec's stone (scripts/enemies/
## rune_knight_look.gd, assets/models/rune_knight.glb) behind the same API as
## the stand-in (scripts/enemies/rune_knight_body_standin.gd), so the mind
## (scripts/enemies/rune_knight.gd) drives either. The mind picks this one;
## `--rune-body=standin` picks the stand-in.
##
## - **The API:** `setup(height)`, `shape()`, `play(clip, form)`, signal
##   `beat_reached(clip, beat)`, `socket(name)`, `set_effect(name, on, form)`.
##   CLIPS (lengths and beats) are the stand-in's, so the mind's timing holds.
## - **Clips:** each plays the glb's animation "clip-form" if there is one,
##   else "clip", blended from the pose he was in (BLEND s); a one-shot whose
##   glb length is a frame off CLIPS' is sped to fit (reel 1.267 s -> 1.25).
##   Beats are sent at CLIPS' times, `end` at the length. `walk` and `turn`
##   are authored in place at the mind's pace: `plant` is sent as the loop
##   passes each footfall (PLANTS).
## - **The leap:** `leap-<form>` (crouch, launch, held in the drop pose);
##   `crouch`/`launch` at LEAP's times, `apex` when his root stops rising,
##   `land` when it has dropped and stops, which crosses to `leap-land`
##   (sped to fit LEAP.land_len), `end` land_len after.
## - **fall** loops; `land` once his root, having dropped, stops.
## - **kneel**: dust off the right knee as it meets the deck (KNEEL_DOWN)
##   and a breath of dust off his chest.
## - **crumble** plays the glb's shudder, then at CRUMBLE_HOLD his pieces
##   come loose and slump into a heap (scripts/enemies/rune_knight_breakup.gd);
##   **shatter** throws them apart from whatever pose he is in.
## - **skid** and **teeter** are authored with the push at his face: the
##   model turns (not his root) so his back is to the way he slides.
## - **gone** hides him.
## - **Effects:** `rune_glow` (his runes lit), `wind_gather` (streaks drawn
##   in to hands_mid, or the right fist with the blade), `wind_blade` (a
##   blade of air along the right forearm, the `blade` socket in it),
##   `rune_crack` form chest/hand_l/hand_r (flare, flicker, dark for good),
##   `rune_spill` form a rune (its shards burst out, scripts/enemies/
##   rune_spill.gd), `eye_glow` (the visor's eye lit; lit at `notice`, dim
##   again when he walks, dark when he breaks).
## - **hands_mid** follows the midpoint of his fists.
## - For the mind's drivers it names the stand-in's internals: `clip`,
##   `clip_form`, `clip_time`, `_sent`, `_flying` (the break-up's pieces,
##   [node, ...]), `blocks_at_rest()`, `feet`, `effects`, `crack_t`,
##   `spills`, `broken`, `_root_v`.
const Look = preload("res://scripts/enemies/rune_knight_look.gd")
const Breakup = preload("res://scripts/enemies/rune_knight_breakup.gd")
const BodyDust = preload("res://scripts/enemies/body_dust.gd")
const RuneSpill = preload("res://scripts/enemies/rune_spill.gd")
const DragonCyclone = preload("res://scripts/dragon_cyclone.gd")
const Standin = preload("res://scripts/enemies/rune_knight_body_standin.gd")

signal beat_reached(clip: String, beat: String)

## The stand-in's contract tables, shared so the two bodies time alike.
const CLIPS: Dictionary = Standin.CLIPS
const LEAP: Dictionary = Standin.LEAP
const SOCKETS: Array = Standin.SOCKETS
## The walk's and turn's footfalls in their glb loops (s).
const PLANTS := {"walk": [0.0,0.95], "turn": [0.0,0.8]}
## Clips the glb names otherwise (the stand-in's old `stagger` is the reel).
const ANIM_OF := {"stagger": "reel"}
const BLEND := 0.14
## A one-shot's glb length within this share of CLIPS' is sped to fit.
const FIT := 0.15
const CRUMBLE_HOLD := Standin.CRUMBLE_HOLD
const KNEEL_DOWN := Standin.KNEEL_DOWN
## His room, reach and stride (shares of tall), the stand-in's.
const ROOM := Standin.ROOM
const REACH := Standin.REACH
const STRIDE := Standin.STRIDE
## Rune light: lit share over rest (the look's RUNE_LIT / RUNE_REST), easing.
const RUNE_EASE := Standin.RUNE_EASE
const CRACK_FLARE := Standin.CRACK_FLARE
const CRACK_FLICKER := Standin.CRACK_FLICKER
const RUNE := Standin.RUNE
## A rune further out from his middle than this (share of tall) spills
## back in toward him.
const SPILL_WIDE := 0.25
## The eye's ease (share a second).
const EYE_EASE := 4.0
## The model's turn to the push in a skid (rad a second).
const PUSH_TURN := 14.0
## The streaks (the stand-in's).
const GATHER_STREAKS := Standin.GATHER_STREAKS
const GATHER_REACH := Standin.GATHER_REACH
const GATHER_RATE := Standin.GATHER_RATE
const GATHER_WIDTH := Standin.GATHER_WIDTH
const BLADE_STREAKS := Standin.BLADE_STREAKS
const BLADE_REACH := Standin.BLADE_REACH
const BLADE_WIDTH := Standin.BLADE_WIDTH
const BLADE_TINT := Standin.BLADE_TINT
const BLADE_GROW := Standin.BLADE_GROW
const SKID_DUST := Standin.SKID_DUST
const SKID_DUST_GAP := Standin.SKID_DUST_GAP

var tall := 1.9
var clip := "idle"
var clip_form := ""
var clip_time := 0.0
var effects := {"rune_glow": false, "wind_gather": false, "wind_blade": false, "eye_glow": false}
var glow := 0.0
var eye := Look.EYE_REST
var crack_t: Dictionary = {"chest": -1.0, "hand_l": -1.0, "hand_r": -1.0}
var spills := 0
var broken := false
## The feet (world), 0 left, 1 right: where the foot bones are.
var feet: Array[Vector3] = [Vector3.ZERO,Vector3.ZERO]
var _sent: Dictionary = {}
var _flying: Array = []
var _root_last := Vector3.ZERO
var _root_v := Vector3.ZERO
var _fall_vy := 0.0
var _fell := false
var _land_t := -1.0
var _leap_drop := false
var _anim := ""
var _anim_last := 0.0
var _skid_dir := Vector3.BACK
var _dust_t := 0.0
var _clock := 0.0
var _rng := RandomNumberGenerator.new()

var look: Look
var _skel: Skeleton3D
var _bone := {}
var _sockets := {}
var _breakup: Node3D
var _gather_fade := 0.0
var _gather_dirs: Array[Vector3] = []
var _gather_phase: Array[float] = []
var _gather_mm: MultiMeshInstance3D
var _blade_fade := 0.0
var _blade_mm: MultiMeshInstance3D

func _init() -> void:
	name = "Body"

## Built `height` m tall; call once it is in the tree under his root.
func setup(height: float) -> void:
	tall = height
	look = Look.new()
	look.name = "Look"
	add_child(look)
	look.build(height)
	_skel = look.model.find_child("Skeleton3D",true,false) as Skeleton3D
	if _skel == null:
		for n in look.model.find_children("*","Skeleton3D",true,false):
			_skel = n
			break
	for b in ["foot_l","foot_r","shin_r","forearm_r","hand_r","hand_l"]:
		_bone[b] = _skel.find_bone(b) if _skel != null else -1
	for s: String in SOCKETS: _sockets[s] = look.socket(s)
	_root_last = global_position
	_build_gather()
	_build_blade()
	_play_anim("idle",0.0,1.0)
	_feet_now()

## His shape (m, s), the stand-in's: room radius and height, eye height,
## reach, the feet's stride and a walking step's time, and their pace.
func shape() -> Dictionary:
	var step: float = CLIPS.walk.length
	var stride := STRIDE*tall
	var eye_y := 0.9*tall
	var e: Node3D = _sockets.get("eye")
	if e != null and e.is_inside_tree():
		var y := to_local(e.global_position).y
		if y > 0.75*tall and y < 0.98*tall: eye_y = y
	return {"radius":ROOM*tall,"height":tall,"eye":eye_y,
		"reach":REACH*tall,"stride":stride,"step_time":step,"pace":stride/step}

# --- The API ------------------------------------------------------------------------

func play(name_: String, form := "") -> void:
	if not CLIPS.has(name_):
		push_warning("rune knight body: no clip %s" % name_)
		return
	if name_ == clip and CLIPS[name_].loop: return
	clip = name_
	clip_form = form
	clip_time = 0.0
	_sent = {}
	_land_t = -1.0
	_leap_drop = false
	if name_ == "gone":
		visible = false
		return
	if name_ == "notice": effects.eye_glow = true
	elif name_ == "walk": effects.eye_glow = false
	if name_ == "shatter": return
	if name_ == "leap":
		_play_anim("leap-"+(form if form != "" else "up"),BLEND,1.0)
		return
	var anim := String(ANIM_OF.get(name_,name_))
	if form != "" and look.player.has_animation(anim+"-"+form): anim = anim+"-"+form
	var speed := 1.0
	if look.player.has_animation(anim) and not CLIPS[name_].loop:
		var have := look.player.get_animation(anim).length
		var want: float = CLIPS[name_].length
		if absf(have/want-1.0) <= FIT: speed = have/want
	_play_anim(anim,BLEND,speed)
	if name_ == "reel":
		# The wind torn out of his chest: a burst of air off the rune.
		var at: Node3D = _sockets.get("chest_rune")
		if at != null and is_inside_tree(): BodyDust.puff(_host(),at.global_position,0.16*tall,-global_transform.basis.z)

func socket(name_: String) -> Node3D:
	return _sockets.get(name_)

func set_effect(name_: String, on: bool, form := "") -> void:
	if name_ == "rune_crack":
		if not crack_t.has(form):
			push_warning("rune knight body: no rune %s" % form)
			return
		crack_t[form] = 0.0 if on else -1.0
		if on: _crack_burst(form)
		return
	if name_ == "rune_spill":
		if on: _spill(form)
		return
	effects[name_] = on

## How many pieces have come to rest (for the drivers), and how many flew.
func blocks_at_rest() -> Vector2i:
	return _breakup.at_rest() if _breakup != null else Vector2i.ZERO

# --- The frame ----------------------------------------------------------------------

func _process(delta: float) -> void:
	if delta <= 0.0 or look == null: return
	var now := global_position
	_fall_vy = (now.y-_root_last.y)/delta
	_root_v = _root_v.lerp((now-_root_last)/delta,clampf(delta*8.0,0.0,1.0))
	_root_last = now
	clip_time += delta
	_clock += delta
	var c: Dictionary = CLIPS[clip]
	for beat: String in c.beats:
		var at: float = c.beats[beat]
		if at >= 0.0 and clip_time >= at and not _sent.has(beat):
			_sent[beat] = true
			beat_reached.emit(clip,beat)
	if clip == "walk" or clip == "turn": _plants()
	if not c.loop and clip_time >= float(c.length) and not _sent.has("_end"):
		_sent["_end"] = true
		beat_reached.emit(clip,"end")
	if clip == "leap": _leap_beats()
	if clip == "fall":
		if _fall_vy < -3.0: _fell = true
		elif _fell and _fall_vy > -0.5 and not _sent.has("land"):
			_sent["land"] = true
			beat_reached.emit(clip,"land")
	if clip == "kneel" and clip_time >= KNEEL_DOWN and not _sent.has("_knee"):
		_sent["_knee"] = true
		_knee_dust()
	for r: String in crack_t:
		if crack_t[r] >= 0.0: crack_t[r] += delta
	if (clip == "crumble" and clip_time >= CRUMBLE_HOLD) or clip == "shatter":
		if not broken: _come_apart(clip == "shatter")
	if broken:
		_draw_off()
		return
	_gather_fade = move_toward(_gather_fade,1.0 if effects.wind_gather else 0.0,delta*(3.0 if effects.wind_gather else 4.0))
	glow = move_toward(glow,1.0 if effects.rune_glow else 0.0,delta*RUNE_EASE*0.5)
	_blade_fade = move_toward(_blade_fade,1.0 if effects.wind_blade else 0.0,delta/(BLADE_GROW if effects.wind_blade else 0.12))
	var dead_eye := clip == "kneel" and clip_time > 0.65
	eye = move_toward(eye,0.0 if dead_eye else (1.0 if effects.eye_glow else Look.EYE_REST),delta*EYE_EASE)
	look.eye_glow(eye)
	var flat_v := Vector3(_root_v.x,0.0,_root_v.z)
	if flat_v.length() > 0.8 and clip == "skid": _skid_dir = flat_v.normalized()
	_turn_to_push(delta)
	_feet_now()
	_skid_dust(delta,flat_v.length())
	var hl: Node3D = _sockets.get("hand_l")
	var hr: Node3D = _sockets.get("hand_r")
	var mid: Node3D = _sockets.get("hands_mid")
	if hl != null and hr != null and mid != null: mid.global_position = (hl.global_position+hr.global_position)*0.5
	_light_runes()
	_draw_gather()
	_draw_blade()

func _play_anim(anim: String, blend: float, speed: float) -> void:
	var p: AnimationPlayer = look.player
	if p == null or not p.has_animation(anim):
		push_warning("rune knight body: no animation %s" % anim)
		return
	if p.current_animation == anim and p.get_animation(anim).loop_mode == Animation.LOOP_NONE:
		p.stop(true)
	p.play(anim,blend,speed)
	_anim = anim
	_anim_last = 0.0

## `plant` as the walk's or turn's loop passes a footfall.
func _plants() -> void:
	var p: AnimationPlayer = look.player
	if p == null or p.current_animation != _anim: return
	var t := p.current_animation_position
	var marks: Array = PLANTS.get(_anim,[])
	for m: float in marks:
		var crossed := (t >= m and _anim_last < m) if t >= _anim_last else (m > _anim_last or m <= t)
		if crossed and clip_time > 0.05: beat_reached.emit(clip,"plant")
	_anim_last = t

## The leap's beats (the stand-in's): `crouch`, `launch` at LEAP's times;
## `apex` when his root stops rising; `land` (to `leap-land`) when it has
## dropped and stops; `end` land_len on.
func _leap_beats() -> void:
	var L: Dictionary = LEAP.get(clip_form,LEAP.up)
	for b: String in ["crouch","launch"]:
		if clip_time >= float(L[b]) and not _sent.has(b):
			_sent[b] = true
			beat_reached.emit(clip,b)
	if not _sent.has("launch"): return
	if not _sent.has("apex") and clip_time > float(L.launch)+0.05 and _fall_vy <= 0.0:
		_sent["apex"] = true
		beat_reached.emit(clip,"apex")
	if _sent.has("apex") and _fall_vy < -1.0: _leap_drop = true
	if _leap_drop and _land_t < 0.0 and absf(_fall_vy) < 0.3:
		_land_t = clip_time
		_sent["land"] = true
		var p: AnimationPlayer = look.player
		var have := p.get_animation("leap-land").length if p.has_animation("leap-land") else 0.9
		_play_anim("leap-land",0.06,have/float(L.land_len))
		beat_reached.emit(clip,"land")
	if _land_t >= 0.0 and clip_time-_land_t >= float(L.land_len) and not _sent.has("_end"):
		_sent["_end"] = true
		beat_reached.emit(clip,"end")

## In a skid or a teeter his back turns to the way he slides (the clips
## have the push at his face); otherwise he faces his root's way.
func _turn_to_push(delta: float) -> void:
	var want := 0.0
	if clip == "skid" or clip == "teeter":
		var d := global_transform.basis.inverse()*_skid_dir
		d.y = 0.0
		if d.length() > 0.01: want = atan2(d.x,d.z)
	look.rotation.y = lerp_angle(look.rotation.y,want,clampf(delta*PUSH_TURN,0.0,1.0))

func _feet_now() -> void:
	if _skel == null: return
	for i in range(2):
		var b: int = _bone["foot_l" if i == 0 else "foot_r"]
		if b >= 0: feet[i] = (_skel.global_transform*_skel.get_bone_global_pose(b)).origin

func _bone_at(b: String) -> Transform3D:
	var i: int = _bone.get(b,-1)
	if _skel == null or i < 0: return global_transform
	return _skel.global_transform*_skel.get_bone_global_pose(i)

func _host() -> Node:
	return get_parent().get_parent() if get_parent() != null and get_parent().get_parent() != null else self

# --- Coming apart -------------------------------------------------------------------

func _come_apart(thrown: bool) -> void:
	broken = true
	effects.wind_gather = false
	effects.wind_blade = false
	_breakup = Breakup.new()
	_breakup.name = "RuneKnightBreakup"
	_host().add_child(_breakup)
	_breakup.start(look,tall,thrown,_rng.randi())
	_flying = _breakup.flying

func _draw_off() -> void:
	if _gather_mm != null: _gather_mm.multimesh.visible_instance_count = 0
	if _blade_mm != null: _blade_mm.multimesh.visible_instance_count = 0

# --- Dust ---------------------------------------------------------------------------

func _knee_dust() -> void:
	var g := global_transform
	var fwd := -g.basis.z.normalized()
	var knee := _bone_at("shin_r").origin
	knee.y = g.origin.y
	BodyDust.plume(_host(),knee+fwd*0.02*tall,0.22*tall)
	var chest: Node3D = _sockets.get("chest_rune")
	if chest != null: BodyDust.puff(_host(),chest.global_position,0.16*tall,fwd*1.5+Vector3.UP)
	effects.wind_gather = false

func _skid_dust(delta: float, speed: float) -> void:
	if clip != "skid" or speed < SKID_DUST:
		_dust_t = 0.0
		return
	_dust_t -= delta
	if _dust_t > 0.0: return
	_dust_t = SKID_DUST_GAP
	for i in range(2):
		BodyDust.puff(_host(),feet[i]+Vector3.UP*0.12*tall,clampf(speed*0.07,0.2,0.5)*tall*0.6,-_skid_dir*0.6+Vector3.UP*1.3)
	if not _sent.has("_dug"):
		_sent["_dug"] = true
		BodyDust.plume(_host(),(feet[0]+feet[1])*0.5+Vector3.UP*0.12*tall,0.3*tall)

# --- Runes --------------------------------------------------------------------------

## Each rune's light (shares of its rest light): lit by `rune_glow` while
## whole (flickering while he teeters, flaring and guttering in the reel);
## a cracked one flares, flickers and goes dark for good.
func _light_runes() -> void:
	var lit_share: float = Look.RUNE_LIT/Look.RUNE_REST
	var lit := lerpf(1.0,lit_share,glow)
	if clip == "teeter": lit *= 1.0 if sin(clip_time*47.0)+sin(clip_time*29.0) > -0.3 else 0.35
	if clip == "reel":
		var flare := maxf(1.0-clip_time/0.35,0.0)
		lit = lit_share*(1.0+1.4*flare) if clip_time < 0.35 else lerpf(1.0,lit_share,0.8)*(1.0 if sin(clip_time*53.0)+sin(clip_time*31.0) > 0.2 else 0.25)
	for key: String in crack_t:
		var t: float = crack_t[key]
		var e := lit
		if t >= 0.0:
			if t < CRACK_FLARE: e = lit_share*1.8
			elif t < CRACK_FLARE+CRACK_FLICKER:
				var fade := 1.0-(t-CRACK_FLARE)/CRACK_FLICKER
				e = lit_share*fade if _rng.randf() < 0.45 else 0.03
			else: e = 0.0
		look.rune_energy(key,e)

func _rune_at(group: String) -> Node3D:
	return _sockets.get("chest_rune" if group == "chest" else group)

func _crack_burst(group: String) -> void:
	var at := _rune_at(group)
	if at != null and is_inside_tree(): BodyDust.puff(_host(),at.global_position,0.12*tall,-global_transform.basis.z)

func _spill(group: String) -> void:
	if not crack_t.has(group): group = "chest"
	var at := _rune_at(group)
	if at == null or not is_inside_tree(): return
	var s: Node3D = RuneSpill.new()
	s.set("tint",RUNE)
	s.set("tall",tall)
	# Out his front; a gauntlet flung wide (the reel) sprays back in round
	# him, so its shards come down by him, not off the deck's side.
	var way := -global_transform.basis.z
	var off := at.global_position-global_position
	off.y = 0.0
	var from := at.global_position
	if off.length() > SPILL_WIDE*tall:
		way = (way-off.normalized()*1.6).normalized()
		from -= off.normalized()*(off.length()-SPILL_WIDE*tall)*0.5
	s.set("out_way",way)
	_host().add_child(s)
	s.global_position = from
	spills += 1
	BodyDust.puff(_host(),at.global_position,0.2*tall,-global_transform.basis.z*1.5+Vector3.UP)

# --- Wind ---------------------------------------------------------------------------

func _streaks(label: String, count: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.use_colors = true
	mm.mesh = DragonCyclone._streak_mesh()
	mm.instance_count = count
	mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.name = label
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.extra_cull_margin = 50.0
	mi.top_level = true
	add_child(mi)
	mi.global_transform = Transform3D.IDENTITY
	return mi

func _build_blade() -> void:
	_blade_mm = _streaks("WindBlade",BLADE_STREAKS)

func _build_gather() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(GATHER_STREAKS):
		var a := float(i)/float(GATHER_STREAKS)*TAU+rng.randf_range(-0.2,0.2)
		_gather_dirs.append(Vector3(cos(a),rng.randf_range(-0.35,0.9),sin(a)).normalized())
		_gather_phase.append(rng.randf())
	_gather_mm = _streaks("WindGather",GATHER_STREAKS)

## The gather's streaks (the stand-in's): each runs in from round him to
## hands_mid (the right fist with the blade) and starts again.
func _draw_gather() -> void:
	var mm := _gather_mm.multimesh
	if _gather_fade <= 0.001:
		mm.visible_instance_count = 0
		return
	var cam := get_viewport().get_camera_3d()
	var into: Node3D = _sockets.hand_r if effects.wind_blade else _sockets.hands_mid
	var mid: Vector3 = into.global_position
	var eye_at := cam.global_position if cam != null else mid+Vector3(0,0,10)
	var reach := GATHER_REACH*tall
	for i in range(GATHER_STREAKS):
		var u := fposmod(_clock*GATHER_RATE+_gather_phase[i],1.0)
		var d: Vector3 = _gather_dirs[i]
		var head := mid+d*reach*pow(1.0-u,1.3)
		var long := reach*0.45*(1.0-u*0.6)
		var along := -d*long
		var way := along.normalized()
		var across := way.cross((eye_at-head).normalized())
		if across.length() < 0.01: across = Vector3.UP.cross(way)
		across = across.normalized()
		var w := GATHER_WIDTH*tall*(1.0-u*0.5)*(0.6 if effects.wind_blade else 1.0)
		mm.set_instance_transform(i,Transform3D(Basis(along,across*w,way.cross(across).normalized()),head-along*0.5))
		mm.set_instance_custom_data(i,Color(_gather_fade*sin(u*PI)*(0.6 if effects.wind_blade else 0.95),0,0,0))
		mm.set_instance_color(i,Color(0.86,0.95,1.0))
	mm.visible_instance_count = GATHER_STREAKS

## The blade of air (the stand-in's) along the right forearm, elbow to past
## the fist, the `blade` socket in its middle.
func _draw_blade() -> void:
	var elbow := _bone_at("forearm_r")
	var wrist := _bone_at("hand_r").origin
	var root := elbow.origin
	var way := (wrist-root).normalized() if wrist.distance_to(root) > 0.01 else Vector3.DOWN
	var edge := (elbow.basis*Vector3.FORWARD).normalized()
	edge = (edge-way*edge.dot(way)).normalized() if absf(edge.dot(way)) < 0.99 else way.cross(Vector3.UP).normalized()
	var grow := 1.0-pow(1.0-_blade_fade,2.0)
	var reach := tall*lerpf(0.2,BLADE_REACH,grow)
	var blade: Node3D = _sockets.get("blade")
	if blade != null: blade.global_position = root+way*(0.05*tall+reach*0.55)
	var mm := _blade_mm.multimesh
	if _blade_fade <= 0.001:
		mm.visible_instance_count = 0
		return
	var cam := get_viewport().get_camera_3d()
	var eye_at := cam.global_position if cam != null else root+Vector3(0,0,10)
	for i in range(BLADE_STREAKS):
		var lane := float(i%3)
		var seg := float(i/3)
		var segs := ceilf(float(BLADE_STREAKS)/3.0)
		var u0 := seg/segs
		var u1 := (seg+1.0)/segs
		var wob := sin(_clock*(23.0+lane*7.0)+float(i)*1.7)*0.012*tall
		var off := edge*(lane-1.0)*0.025*tall+edge*wob
		var a := root+way*(0.05*tall+reach*u0)+off
		var b := root+way*(0.05*tall+reach*u1*1.08)+off
		var along := b-a
		var w := BLADE_WIDTH*tall*(1.0-u0*0.55)*(1.25 if lane == 1.0 else 0.7)
		var dir := along.normalized()
		var across := dir.cross((eye_at-a).normalized())
		if across.length() < 0.01: across = Vector3.UP.cross(dir)
		across = across.normalized()
		mm.set_instance_transform(i,Transform3D(Basis(along,across*w,dir.cross(across).normalized()),(a+b)*0.5))
		mm.set_instance_custom_data(i,Color(_blade_fade*(1.0 if lane == 1.0 else 0.6),0,0,0))
		mm.set_instance_color(i,Color(0.92,0.98,1.0) if lane == 1.0 else BLADE_TINT)
	mm.visible_instance_count = BLADE_STREAKS
