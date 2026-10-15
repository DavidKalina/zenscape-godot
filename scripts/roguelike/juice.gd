extends Node
## [juice] Getting hurt and getting loot land (docs/design/roguelike/
## juice-round1.md). Added by the run loop (`RunFeatures.on(&"juice")`); it
## reads the run and the motor and hooks nothing else:
##
## - **A hit** (hearts fall): a hit-stop of a few frames, a small camera
##   kick the way the blow went, a muffled thud. The last heart lost: a
##   longer held beat that eases back, a heavier kick and thud.
## - **One heart left**: a slow heartbeat in step with the corner's heart
##   (sound, and a faint madder vignette pulsing).
## - **An item** (`RunState.item_taken`): time holds a moment, its glyph
##   rises from him with a soft glow and a few glints, a warm chord, a lamp
##   swelling at his feet. The rarer, the bigger (rarity 1..3). The caption
##   and the strip's swell are the run loop's and the strip's.
## - **The gate**: its light rising has a breath; arriving through it, a
##   bell and the view settling down a little.
##
## Timings are real seconds (whatever the time scale). Restraint: every
## amount is a const below.
const RunOverlay = preload("res://scripts/roguelike/run_overlay.gd")
const ItemCatalog = preload("res://scripts/roguelike/item_catalog.gd")
const Glyphs = preload("res://scripts/roguelike/item_glyphs.gd")
const Sounds = preload("res://scripts/roguelike/juice_sounds.gd")
const Audio = preload("res://scripts/genesis_audio.gd")

## Hit-stop: time scale, real s held, real s easing back; a hit, the last.
const STOP_SCALE := 0.03
const STOP_HOLD := 0.07
const STOP_EASE := 0.08
const LAST_SCALE := 0.06
const LAST_HOLD := 0.3
const LAST_EASE := 0.6
## The camera kick (view metres), its length (s), its ring (rad/s) and fall.
const KICK := 0.3
const KICK_LAST := 0.55
const KICK_LEN := 0.55
const KICK_RING := 26.0
const KICK_FALL := 8.0
## The heartbeat: the vignette's base and pulse alpha, its fade (s).
const VIG_BASE := 0.07
const VIG_PULSE := 0.2
const VIG_FADE := 0.8
const VIG_TINT := Color(0.34,0.05,0.05)
## A find: time scale, hold per rarity (s), ease (s); the glyph's rise (of
## screen height), life (s), size (design px); the lamp's peak and range.
const FIND_SCALE := 0.12
const FIND_HOLD := 0.1
const FIND_EASE := 0.3
const RISE := 0.06
const LIFE := 1.6
const SIZE := 60.0
const LAMP := Color("ffc989")
const LAMP_ENERGY := 2.0
const LAMP_RANGE := 6.5
## Gains (linear) of each sound.
const GAIN_THUD := 0.5
const GAIN_LAST := 0.65
const GAIN_BEAT := 0.35
const GAIN_CHORD := 0.28
const GAIN_GATE := 0.22
const GAIN_BELL := 0.2

var loop: Node
var study: Node3D
var run: RefCounted
var motor: Object
var overlay: CanvasLayer
var _camera: Camera3D
var _hearts := -1
var _last_harm := {}
var _kick := Vector2.ZERO
var _kick_at := -INF
var _settle_at := -INF
var _state := ""
var _vig_k := 0.0
var _beat_frac := 0.0
var _now := 0.0
var _canvas: CanvasLayer
var _vignette: TextureRect
var _marks: Control
var _finds: Array[Dictionary] = []
var _players := {}
var _owns_time := false

func setup(run_loop: Node) -> void:
	loop = run_loop
	study = run_loop.study
	run = run_loop.run
	motor = study.motor
	overlay = run_loop.overlay
	Audio.ensure_buses()
	name = "Juice"
	_canvas = CanvasLayer.new()
	_canvas.layer = 58
	add_child(_canvas)
	_vignette = TextureRect.new()
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.texture = _vignette_texture()
	_vignette.modulate = Color(1,1,1,0)
	_canvas.add_child(_vignette)
	_marks = Control.new()
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_marks.draw.connect(_draw_finds)
	_canvas.add_child(_marks)
	_now = Time.get_ticks_msec()*0.001
	if motor.has_signal(&"harmed"): motor.connect(&"harmed",_on_harm)
	run.item_taken.connect(_on_item)

func _exit_tree() -> void:
	if _owns_time: Engine.time_scale = 1.0
	if _camera != null and is_instance_valid(_camera):
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0

func _vignette_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0,Color(VIG_TINT,0.0))
	g.set_color(1,Color(VIG_TINT,1.0))
	g.add_point(0.5,Color(VIG_TINT,0.0))
	g.add_point(0.8,Color(VIG_TINT,0.5))
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5,0.5)
	tex.fill_to = Vector2(1.1,1.1)
	tex.width = 256
	tex.height = 256
	return tex

# --- What it hears -------------------------------------------------------------

func _on_harm(_amount: int, cause: String, source: Object) -> void:
	_last_harm = {"cause":cause,"source":source}

func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec()*0.001
	var dt := clampf(t-_now,0.0,0.1)
	_now = t
	if loop == null or not is_instance_valid(motor): return
	if _camera == null:
		var cam: Variant = study.get("camera")
		if cam is Camera3D: _camera = cam
	_hurt_check()
	_state_check()
	_heartbeat(dt)
	_apply_camera()
	_finds_step(dt)

func _playing() -> bool:
	return loop.state in ["play","arrive"]

func _hurt_check() -> void:
	var held: int = run.hearts_of(motor)
	if _hearts >= 0 and held < _hearts and _playing_or_dying():
		_hit(held)
	_hearts = held

func _playing_or_dying() -> bool:
	return loop.state in ["play","arrive","dying"]

func _hit(held: int) -> void:
	var last := held <= 0
	_kick = _kick_toward()*(KICK_LAST if last else KICK)
	_kick_at = _now
	_play("thud_last" if last else "thud",GAIN_LAST if last else GAIN_THUD,1.0 if last else randf_range(0.94,1.06))
	if last: _hold_time(LAST_SCALE,LAST_HOLD,LAST_EASE)
	else: _hold_time(STOP_SCALE,STOP_HOLD,STOP_EASE)

## The kick, in the view's own right and up: the way the blow went (from
## its source through him); a fall's straight down; else a small sideways.
func _kick_toward() -> Vector2:
	var cause := String(_last_harm.get("cause",""))
	if cause == "fall": return Vector2(0.0,-1.0)
	var src: Variant = _last_harm.get("source")
	if _camera != null and src is Node3D and is_instance_valid(src):
		var d: Vector3 = (motor.feet as Vector3)-(src as Node3D).global_position
		d.y = 0.0
		if d.length() > 0.05:
			d = d.normalized()
			return Vector2(d.dot(_camera.global_basis.x),-0.35).normalized()
	return Vector2(1.0 if randf() < 0.5 else -1.0,-0.4).normalized()

## Time held (a hit-stop) unless something else already slows it.
func _hold_time(scale: float, hold: float, ease_s: float) -> void:
	if Engine.time_scale < 0.95 or not is_inside_tree(): return
	Engine.time_scale = scale
	_owns_time = true
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_interval(hold)
	tw.tween_method(func(s: float) -> void: Engine.time_scale = s,scale,1.0,ease_s).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void: _owns_time = false)

func _apply_camera() -> void:
	if _camera == null: return
	var off := Vector2.ZERO
	var k := _now-_kick_at
	if k >= 0.0 and k < KICK_LEN:
		off += _kick*exp(-KICK_FALL*k)*cos(KICK_RING*k)
	var s := _now-_settle_at
	if s >= 0.0 and s < 1.2:
		off.y += 0.35*pow(1.0-s/1.2,2.0)
	_camera.h_offset = off.x
	_camera.v_offset = off.y

# --- One heart left ----------------------------------------------------------------

func _heartbeat(dt: float) -> void:
	var scared: bool = _hearts == 1 and loop.state in ["play","arrive"]
	_vig_k = move_toward(_vig_k,1.0 if scared else 0.0,dt/VIG_FADE)
	var ph: float = float(overlay.get("_beat"))*RunOverlay.BEAT_HZ
	var frac := fposmod(ph,1.0)
	if scared and _beat_frac < 0.22 and frac >= 0.22: _play("beat",GAIN_BEAT,1.0)
	_beat_frac = frac
	# The corner's heart swells at sin^6 peak; the vignette follows it, with a
	# softer second throb after.
	var lub := pow(maxf(0.0,sin(ph*TAU)),6.0)
	var dub := 0.5*pow(maxf(0.0,sin((ph-0.2)*TAU)),6.0)
	_vignette.modulate = Color(1,1,1,_vig_k*(VIG_BASE+VIG_PULSE*maxf(lub,dub)))

# --- The gate -----------------------------------------------------------------------

func _state_check() -> void:
	var now: String = loop.state
	if now != _state:
		if now == "gate": _play("gate_rise",GAIN_GATE,1.0)
		elif now == "arrive" and run.depth > 1:
			_play("gate_bell",GAIN_BELL,1.0)
			_settle_at = _now
		_state = now

# --- A find -------------------------------------------------------------------------

func _on_item(id: StringName) -> void:
	var info := ItemCatalog.info(id)
	var rarity := clampi(int(info.get("rarity",1)),1,3)
	_play("chord%d" % rarity,GAIN_CHORD,1.0)
	_hold_time(FIND_SCALE,FIND_HOLD*(1.0+float(rarity)),FIND_EASE)
	var from := _view().x*0.5
	var at := Vector2(from,_view().y*0.55)
	if _camera != null:
		var head: Vector3 = (motor.feet as Vector3)+Vector3.UP*1.9
		if not _camera.is_position_behind(head): at = _camera.unproject_position(head)
	_finds.append({"id":id,"kind":String(info.get("kind","")),"rarity":rarity,"at":at,"age":0.0})
	_lamp(rarity)

func _view() -> Vector2:
	return _marks.get_viewport_rect().size

## A warm lamp at his feet swelling and going out (ignores time scale).
func _lamp(rarity: int) -> void:
	var lamp := OmniLight3D.new()
	lamp.light_color = LAMP
	lamp.omni_range = LAMP_RANGE*(0.8+0.2*float(rarity))
	lamp.light_energy = 0.0
	lamp.shadow_enabled = false
	study.add_child(lamp)
	lamp.global_position = (motor.feet as Vector3)+Vector3.UP*1.3
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(lamp,"light_energy",LAMP_ENERGY*(0.7+0.3*float(rarity)),0.15).set_ease(Tween.EASE_OUT)
	tw.tween_property(lamp,"light_energy",0.0,1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_callback(lamp.queue_free)

func _finds_step(dt: float) -> void:
	for f in _finds: f.age = float(f.age)+dt
	_finds = _finds.filter(func(f: Dictionary) -> bool: return float(f.age) < LIFE)
	_marks.queue_redraw()

func _draw_finds() -> void:
	var px := maxf(_view().y,1.0)/1080.0
	for f in _finds:
		var age := float(f.age)
		var k := age/LIFE
		var rarity := int(f.rarity)
		var rise := _view().y*RISE*(1.0-pow(1.0-clampf(age/1.1,0.0,1.0),3.0))
		var at: Vector2 = f.at-Vector2(0.0,rise)
		var shown := smoothstep(0.0,0.08,k)*(1.0-smoothstep(0.6,1.0,k))
		var pop := 1.0+0.45*sin(clampf(age/0.35,0.0,1.0)*PI)*(1.0-clampf(age/0.35,0.0,1.0)*0.3)
		var size := SIZE*px*(0.9+0.2*float(rarity))*pop
		# A soft warm glow behind it, in a few rings.
		for i in range(5):
			var r := size*(0.55+0.22*float(i))*(1.0+0.3*k)
			draw_glow(at,r,0.07*shown*(1.0+0.15*float(rarity)))
		Glyphs.draw(_marks,f.id,String(f.kind),at,size,shown,1.3)
		# Glints: little four-point stars drifting out.
		var n := 3+rarity*2
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(str(f.id))
		for i in range(n):
			var ang := rng.randf_range(0.0,TAU)
			var dist := size*rng.randf_range(0.7,1.2)*(0.6+0.7*clampf(age/0.9,0.0,1.0))
			var delay := rng.randf_range(0.0,0.5)
			var tw := clampf((age-delay)/0.6,0.0,1.0)
			var twinkle := sin(tw*PI)
			if twinkle <= 0.0: continue
			_star(at+Vector2(cos(ang),sin(ang))*dist,size*0.12*twinkle*(0.7+0.3*float(rarity)),Color(1.0,0.93,0.72,0.85*twinkle*shown))

func draw_glow(at: Vector2, r: float, a: float) -> void:
	_marks.draw_circle(at,r,Color(1.0,0.82,0.5,a))

func _star(at: Vector2, r: float, col: Color) -> void:
	_marks.draw_line(at-Vector2(r,0.0),at+Vector2(r,0.0),col,1.5,true)
	_marks.draw_line(at-Vector2(0.0,r),at+Vector2(0.0,r),col,1.5,true)

# --- Sound -------------------------------------------------------------------------

func _play(sound: String, gain: float, pitch: float) -> void:
	var p: AudioStreamPlayer = _players.get(sound)
	if p == null:
		p = AudioStreamPlayer.new()
		p.bus = Audio.BUS
		p.max_polyphony = 3
		match sound:
			"thud": p.stream = Sounds.thud()
			"thud_last": p.stream = Sounds.thud_last()
			"beat": p.stream = Sounds.beat()
			"chord1": p.stream = Sounds.chord(1)
			"chord2": p.stream = Sounds.chord(2)
			"chord3": p.stream = Sounds.chord(3)
			"gate_rise": p.stream = Sounds.gate_rise()
			"gate_bell": p.stream = Sounds.gate_bell()
		p.volume_db = linear_to_db(gain)
		add_child(p)
		_players[sound] = p
	p.pitch_scale = pitch
	p.play()
