extends Node3D
## The parry (docs/design/endless-flight/parry-handoff.md): the roll button's roll
## (the clean roll or the surge roll, as it flies already) opens a short window
## at its start, and a shot that will pass within PARRY_REACH m of the plane's
## touch inside it is knocked back at whoever sent it. Hard hit-stop, a beat of
## slow motion, the view punched, the streaks on, a ring and a low hit; the ball
## goes home glowing, and light flies from it into the meter, which takes a big
## chunk (more for each parry chained inside CHAIN_S, more for a perfect one).
## A roll that parries nothing while a shot was closing locks the roll out
## WHIFF_LOCK s after it ends. Nothing else: no damage anywhere.
##
## The tell: a whistle rises as the shot that will come nearest soonest closes.
## (Its on-screen rings and the PARRY / MISS words are off; the user cut them.)
##
## Anything that throws shots opts in by joining the group `parry_source` with
## these (pirate_ship.gd is the first):
##   parry_shots() -> Array            its live shots: Dictionaries with `at`, `v`
##                                     (world, m/s), `node` (Node3D), and `parry`
##                                     true on each that can be parried
##   parry_take(shot) -> void          the shot is the parry's now: out of the
##                                     source's own flight and hit tests
##   parry_aim(shot) -> Vector3        where it goes back to (world), each frame
##   parry_inside(p) -> bool           true once a point is in the sender's body
##   parry_moved(shot, a, b) -> void   the returning shot moved a -> b (its trail)
##   parry_landed(shot, at, hit)       its end: on the sender (hit) or not; the
##                                     node is the source's again

const WorldScale = preload("res://scripts/world_scale.gd")

const GROUP := &"parry_source"

## --- The tuning ----------------------------------------------------------------
## The window from the roll's start (s of game time), and the inner perfect band:
## the ball's nearest pass this soon after the press.
const WINDOW := 0.1
const PERFECT_S := 0.045
## How far past a touch of the plane (WorldScale.span*0.5 off its middle, plus
## the shot's own radius) a pass is still parried (m).
const PARRY_REACH := 4.0
## The shot's radius when it doesn't say (`r`), m.
const SHOT_R := 1.5
## A whiff: a shot was closing to pass within WHIFF_REACH m of the touch inside
## WHIFF_S s when the roll began; the roll then locks out this long after it ends.
const WHIFF_REACH := 18.0
const WHIFF_S := 1.0
const WHIFF_LOCK := 0.5
## The hit: frames held near frozen (and their time scale), then the slow motion
## (its scale, real seconds), a perfect's extra frames. The view's shake (rad)
## and punch (degrees); the streaks' lift and how fast it dies (real s).
const STOP_FRAMES := 4
const PERFECT_FRAMES := 1
const STOP_SCALE := 0.02
const SLOW_SCALE := 0.3
const SLOW_S := 0.25
const KICK := Vector2(0.045,14.0)
## The screen's white flash: how long it takes to fade (real s).
const WHITE_S := 0.14
const STREAK_S := 0.7
## The meter: a parry's share of it; each chained parry within CHAIN_S s (game)
## of the last pays CHAIN_STEP more again; a perfect pays PERFECT_PAY times.
## The light reaches the meter LIGHT_S real s after the hit, and pays then.
const METER_CHUNK := 0.25
const CHAIN_STEP := 0.35
const CHAIN_S := 3.2
const PERFECT_PAY := 1.4
const LIGHT_S := 0.55
const MOTES := 14
## The way home: m/s, how hard it turns onto its mark (1/s), the most it's out (s).
const RETURN_SPEED := 175.0
const RETURN_TURN := 5.0
const RETURN_LIFE := 6.0
## The tell: from how soon (s) it shows; its ring's size off the ball (rad of the
## view across, far and closed on); the ball's own glow when sent home (m).
const TELL_S := 1.1
const TELL_ANGLE := Vector2(0.09,0.016)
## The screen ring round the plane: px across at 900 high, far and closed on.
const TELL_RING := Vector2(230.0,70.0)
const HOME_GLOW := 4.0
const WHISTLE := "res://assets/audio/kit/air-whistle-loop.wav"
const WHISTLE_PITCH := Vector2(0.8,2.6)
const WHISTLE_GAIN := 0.5

const RING_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, depth_test_disabled, cull_disabled, shadows_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform float width = 0.12;
uniform float fill = 0.0;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz),0,0,0), vec4(0,length(MODEL_MATRIX[1].xyz),0,0), vec4(0,0,1,0), vec4(0,0,0,1));
}
void fragment() {
	float d = length(UV*2.0-1.0);
	float ring = 1.0-smoothstep(0.0, width, abs(d-(1.0-width)));
	float disc = pow(clamp(1.0-d, 0.0, 1.0), 2.0);
	float a = mix(ring, disc, fill);
	ALBEDO = tint.rgb*a*tint.a;
	ALPHA = clamp(a*tint.a, 0.0, 1.0);
}
"""

var game: Node3D
## Counted, for the drivers and the handoff.
var rolls := 0
var parries := 0
var perfects := 0
var whiffs := 0
var home_hits := 0
var home_misses := 0
var chain := 0
var last := {}
## 0 to 1: the streaks' lift (endless_flight `_streak_step` reads it).
var streak := 0.0
## The roll locked out (s left once the roll is over).
var locked := 0.0

var _open := -1.0
var _threat := false
var _parried_this := 0
var _chain_until := -INF
var _now := 0.0
var _was_rolling := false
var _asked := false
var _smash_rolls := 0
## The meter when the open window's roll began, and whether that roll was the
## surge roll: a parry never spends the gauge, so it hands it back.
var _meter_at_roll := 0.0
var _roll_surged := false
var _stop := 0
var _slow_until := 0
var _returning: Array[Dictionary] = []
var _pay: Array[Dictionary] = []
var _shader: Shader
var _tell: MeshInstance3D
var _tell_mat: ShaderMaterial
var _fx: Array[Dictionary] = []
var _whistle: AudioStreamPlayer
var _players: Array[AudioStreamPlayer] = []
var _overlay: Control
var _motes: Array[Dictionary] = []
var _words := {}
var _drawn := false
## The shot the tell is on now: {shot, k (1 far to 0 on the window), now, col}.
var _tell_on := {}
## The screen's white flash at the hit (0 to 1, real time).
var _white := 0.0
var _clock := 0.0

func _init() -> void:
	name = "Parry"

func setup(g: Node3D) -> void:
	game = g
	_shader = Shader.new()
	_shader.code = RING_SHADER
	_tell_mat = _material(Color(1.0,0.9,0.6,0.0),0.1,0.0)
	_tell = _quad(_tell_mat)
	_tell.visible = false
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_overlay = Control.new()
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_overlay)
	layer.add_child(_overlay)

## Before the surge's and the plane's: a locked roll asked for is dropped; a
## roll asked for is noted (it opens the window once it's under way, `opened`).
func before(input: Dictionary) -> void:
	_was_rolling = bool(game.plane.rolling)
	_smash_rolls = int(game.smash.rolls) if game.smash != null else 0
	_asked = float(input.get("roll",0.0)) != 0.0
	if _asked and locked > 0.0:
		input["roll"] = 0.0
		_asked = false
		_play("clunk",0.5,1.3)

## After the plane's move and before the shots': the window opened by a roll
## that just began, shots in it parried, the tell, the shots sent home.
func step(delta: float) -> void:
	_now += delta
	var plane = game.plane
	var flying: bool = plane.weighted and bool(game.hand_landing.flying())
	var surged: bool = game.smash != null and int(game.smash.rolls) != _smash_rolls
	if flying and bool(plane.rolling) and ((_asked and not _was_rolling) or surged):
		_begin(surged)
	_asked = false
	if locked > 0.0 and not bool(plane.rolling): locked = maxf(locked-delta,0.0)
	var shots := _shots()
	if _open >= 0.0:
		var tau := _now-_open
		if tau <= WINDOW+0.0001 and flying:
			for s: Dictionary in shots:
				var hit := _closest(s.shot,WINDOW-tau+delta)
				if float(hit.gap) <= _reach(s.shot)+PARRY_REACH:
					_parry(s,tau+float(hit.t) <= PERFECT_S)
		else:
			_close()
	_tell_step(shots if flying else [],delta)
	_home_step(delta)

## A roll just began: the window's open; was anything coming?
func _begin(surged: bool = false) -> void:
	rolls += 1
	_open = _now
	_meter_at_roll = float(game.near.meter)
	_roll_surged = surged
	_parried_this = 0
	_threat = false
	for s: Dictionary in _shots():
		var hit := _closest(s.shot,WHIFF_S)
		if float(hit.gap) <= _reach(s.shot)+WHIFF_REACH and float(hit.t) > 0.0:
			_threat = true
			break

func _close() -> void:
	if _parried_this == 0 and _threat:
		whiffs += 1
		locked = WHIFF_LOCK
		_play("clunk",0.8,0.9)
	_open = -1.0
	_threat = false

## Every live shot that opts in: [{shot, source}].
func _shots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for src: Node in get_tree().get_nodes_in_group(GROUP):
		if not src.has_method("parry_shots"): continue
		for s: Dictionary in src.parry_shots():
			if bool(s.get("parry",false)) and not bool(s.get("done",false)): out.append({"shot":s,"source":src})
	return out

func _reach(shot: Dictionary) -> float:
	return WorldScale.span*0.5+float(shot.get("r",SHOT_R))

## The nearest the shot comes to the plane within `horizon` s, both holding
## their way: {gap (m), t (s from now)}.
func _closest(shot: Dictionary, horizon: float) -> Dictionary:
	var r: Vector3 = (shot.at as Vector3)-(game.plane.position as Vector3)
	var w: Vector3 = (shot.v as Vector3)-(game.plane.velocity as Vector3)
	var t := clampf(-r.dot(w)/maxf(w.length_squared(),0.0001),0.0,maxf(horizon,0.0))
	return {"gap":(r+w*t).length(),"t":t}

# --- The hit ------------------------------------------------------------------

func _parry(s: Dictionary, perfect: bool) -> void:
	var shot: Dictionary = s.shot
	var src: Node = s.source
	src.parry_take(shot)
	shot["done"] = true
	parries += 1
	_parried_this += 1
	# A parry never spends the gauge: a surge roll that parried is called off
	# and the meter it had drained goes back.
	if _roll_surged:
		_roll_surged = false
		if game.smash != null: game.smash.call_off()
		game.near.meter = maxf(float(game.near.meter),_meter_at_roll)
	if perfect: perfects += 1
	chain = chain+1 if _now <= _chain_until else 0
	_chain_until = _now+CHAIN_S
	var gain := METER_CHUNK*(1.0+CHAIN_STEP*chain)*(PERFECT_PAY if perfect else 1.0)
	var at: Vector3 = shot.at
	var aim: Vector3 = src.parry_aim(shot)
	var home := (aim-at).normalized()
	shot["v"] = home*RETURN_SPEED+Vector3.UP*6.0
	var glow := _quad(_material(Color(1.0,0.75,0.35,0.9),0.1,1.0),shot.node)
	glow.scale = Vector3.ONE*HOME_GLOW
	_returning.append({"shot":shot,"source":src,"age":0.0,"glow":glow})
	last = {"at":at,"perfect":perfect,"chain":chain,"gain":gain,"meter_was":float(game.near.meter)}
	# The freeze, then the slow motion (real time), then back.
	_stop = STOP_FRAMES+(PERFECT_FRAMES if perfect else 0)+1
	Engine.time_scale = STOP_SCALE
	game.feel_hit(KICK.x*(1.3 if perfect else 1.0),KICK.y*(1.3 if perfect else 1.0))
	streak = 1.0
	_play("ring",1.0,1.12 if perfect else 1.0)
	_play("boom",1.0,1.0)
	_play("ring",0.45,1.5+0.12*chain)
	_flash(at,Color(1.0,0.97,0.88,1.0),1.0,16.0 if perfect else 12.0,0.3)
	_white = 0.45 if perfect else 0.32
	_flash(at,Color(1.0,0.85,0.5,1.0),0.0,14.0 if perfect else 11.0,0.22)
	# The light flies to the meter; the meter takes it when it lands.
	var from := _screen(at)
	var to := _meter_point()
	for i in MOTES:
		var side := Vector2(randf_range(-1.0,1.0),randf_range(-1.0,0.4))*randf_range(60.0,220.0)
		_motes.append({"a":from,"b":to,"c":from.lerp(to,0.35)+side,"t":-float(i)*0.012,"life":LIGHT_S*randf_range(0.8,1.0),"r":randf_range(3.0,7.0)})
	_pay.append({"t":LIGHT_S,"gain":gain})

## Where `p` is on the screen (the middle if behind the eye).
func _screen(p: Vector3) -> Vector2:
	var cam: Camera3D = game.camera
	var view := get_viewport().get_visible_rect().size
	if cam == null or cam.is_position_behind(p): return view*0.5
	return cam.unproject_position(p)

func _meter_point() -> Vector2:
	var hud: Variant = game.get("_near_hud")
	if hud != null and (hud as Object).has_method("meter_point"): return (hud as Object).call("meter_point")
	var view := get_viewport().get_visible_rect().size
	return Vector2(view.x-220.0,view.y-90.0)

## The shots sent home: they turn onto their mark and land on it.
func _home_step(delta: float) -> void:
	for i in range(_returning.size()-1,-1,-1):
		var r: Dictionary = _returning[i]
		var shot: Dictionary = r.shot
		var src: Node = r.source
		r.age = float(r.age)+delta
		var a: Vector3 = shot.at
		var aim: Vector3 = src.parry_aim(shot)
		var v: Vector3 = shot.v
		var want := (aim-a).normalized()*RETURN_SPEED
		v = v.lerp(want,clampf(RETURN_TURN*delta,0.0,1.0))
		var n := a+v*delta
		shot.v = v
		shot.at = n
		(shot.node as Node3D).position = n
		src.parry_moved(shot,a,n)
		var hit := false
		for k in 4:
			if src.parry_inside(a.lerp(n,float(k+1)/4.0)):
				hit = true
				n = a.lerp(n,float(k+1)/4.0)
				break
		if hit or float(r.age) > RETURN_LIFE:
			if hit: home_hits += 1
			else: home_misses += 1
			(r.glow as Node).queue_free()
			if hit:
				_flash(n,Color(1.0,0.7,0.35,1.0),1.0,maxf(16.0,game.camera.global_position.distance_to(n)*0.06),0.45)
				game.feel_hit(0.015,4.0)
			src.parry_landed(shot,n,hit)
			_returning.remove_at(i)

# --- The tell -----------------------------------------------------------------

func _tell_step(shots: Array, delta: float) -> void:
	var best: Dictionary = {}
	var soon := TELL_S
	for s: Dictionary in shots:
		var hit := _closest(s.shot,TELL_S)
		if float(hit.gap) > _reach(s.shot)+PARRY_REACH or float(hit.t) <= 0.0: continue
		if float(hit.t) < soon:
			soon = float(hit.t)
			best = s.shot
	_tell_on = {}
	if best.is_empty():
		_tell.visible = false
		if _whistle != null and _whistle.playing: _whistle.stop()
		return
	var at: Vector3 = best.at
	var cam: Camera3D = game.camera
	var dist := cam.global_position.distance_to(at) if cam != null else 50.0
	# Closing from far to on the ball as the window would open on it.
	var k := clampf((soon-WINDOW*0.5)/(TELL_S-WINDOW*0.5),0.0,1.0)
	var size := maxf(dist*lerpf(TELL_ANGLE.y,TELL_ANGLE.x,k),float(best.get("r",SHOT_R))*1.7)
	var now := soon <= WINDOW
	var col := Color(0.6,0.62,0.66) if locked > 0.0 else (Color(1.0,1.0,0.85) if now else Color(1.0,0.82,0.45))
	_tell_mat.set_shader_parameter("tint",Color(col,(1.0 if now else lerpf(0.9,0.3,k))))
	_tell_mat.set_shader_parameter("width",0.22 if now else 0.1)
	_tell.global_position = at
	_tell.scale = Vector3.ONE*size
	_tell.visible = false  # the ring is off; the whistle is the tell
	_tell_on = {"shot":best,"k":k,"now":now,"col":col}
	if not bool(game.sound.audible): return
	if _whistle == null:
		var stream := (load(WHISTLE) as AudioStreamWAV).duplicate() as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = roundi(stream.get_length()*stream.mix_rate)
		_whistle = AudioStreamPlayer.new()
		_whistle.stream = stream
		_whistle.bus = &"SFX"
		add_child(_whistle)
	_whistle.pitch_scale = lerpf(WHISTLE_PITCH.y,WHISTLE_PITCH.x,k)
	_whistle.volume_db = linear_to_db(WHISTLE_GAIN*(1.0-k*0.8)+0.001)
	if not _whistle.playing: _whistle.play()

# --- Look and sound -------------------------------------------------------------

func _material(c: Color, width: float, fill: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("tint",c)
	m.set_shader_parameter("width",width)
	m.set_shader_parameter("fill",fill)
	return m

func _quad(mat: Material, parent: Node = self) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(2.0,2.0)
	var n := MeshInstance3D.new()
	n.mesh = q
	n.material_override = mat
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.extra_cull_margin = 40.0
	n.top_level = parent == self
	parent.add_child(n)
	return n

## A flash at `at`: a disc (`fill` 1) or a ring (0) growing to `size` m over
## `life` real s, fading.
func _flash(at: Vector3, c: Color, fill: float, size: float, life: float) -> void:
	var m := _material(c,0.08,fill)
	var n := _quad(m)
	n.global_position = at
	n.scale = Vector3.ONE*0.5
	_fx.append({"node":n,"mat":m,"t":0.0,"life":life,"size":size,"c":c,"fill":fill})

func _process(delta: float) -> void:
	# Real time: the hit's own clock runs through the freeze.
	var real := delta/maxf(Engine.time_scale,0.001)
	# At most a 30th a frame: a hitch (or a still being taken) shows the hit, not skips it.
	real = minf(real,1.0/30.0)
	_clock += real
	if _stop > 0:
		_stop -= 1
		if _stop == 0:
			Engine.time_scale = SLOW_SCALE
			_slow_until = Time.get_ticks_msec()+int(SLOW_S*1000.0)
	elif _slow_until > 0 and Time.get_ticks_msec() >= _slow_until:
		_slow_until = 0
		if is_equal_approx(Engine.time_scale,SLOW_SCALE): Engine.time_scale = 1.0
	streak = maxf(streak-real/STREAK_S,0.0)
	_white = maxf(_white-real/WHITE_S,0.0)
	for i in range(_fx.size()-1,-1,-1):
		var f: Dictionary = _fx[i]
		f.t = float(f.t)+real
		var u := clampf(float(f.t)/float(f.life),0.0,1.0)
		var n: MeshInstance3D = f.node
		n.scale = Vector3.ONE*float(f.size)*(0.25+0.75*(1.0-pow(1.0-u,3.0)))
		(f.mat as ShaderMaterial).set_shader_parameter("tint",Color(f.c as Color,(1.0-u)*(1.0-u)))
		if u >= 1.0:
			n.queue_free()
			_fx.remove_at(i)
	for i in range(_pay.size()-1,-1,-1):
		var p: Dictionary = _pay[i]
		p.t = float(p.t)-real
		if float(p.t) <= 0.0:
			game.near.meter = minf(1.0,float(game.near.meter)+float(p.gain))
			_play("ring",0.3,2.2)
			_pay.remove_at(i)
	for i in range(_motes.size()-1,-1,-1):
		var m: Dictionary = _motes[i]
		m.t = float(m.t)+real
		if float(m.t) > float(m.life): _motes.remove_at(i)
	if not _words.is_empty():
		_words.t = float(_words.t)+real
		if float(_words.t) > 1.1: _words = {}
	# The tell sits where the ball is drawn: the shots move after the parry's step.
	if not _tell_on.is_empty(): _tell.global_position = (_tell_on.shot as Dictionary).at
	# Only while it has something on it (the flash or the light to the meter), and once after to clear.
	var busy := _white > 0.0 or not _motes.is_empty()
	if _overlay != null and (busy or _drawn): _overlay.queue_redraw()
	_drawn = busy

func _exit_tree() -> void:
	if _stop > 0 or _slow_until > 0: Engine.time_scale = 1.0

func _draw_overlay() -> void:
	if _white > 0.0: _overlay.draw_rect(Rect2(Vector2.ZERO,_overlay.size),Color(1.0,0.97,0.9,_white*_white*2.0))
	for m: Dictionary in _motes:
		var u := clampf(float(m.t)/float(m.life),0.0,1.0)
		if float(m.t) < 0.0: continue
		var e := u*u*(3.0-2.0*u)
		var a: Vector2 = m.a
		var b: Vector2 = m.b
		var c: Vector2 = m.c
		var p := a.lerp(c,e).lerp(c.lerp(b,e),e)
		var r := float(m.r)*(1.0-0.5*u)
		_overlay.draw_circle(p,r*2.6,Color(1.0,0.7,0.3,0.25))
		_overlay.draw_circle(p,r,Color(1.0,0.95,0.75,0.95))
	if _words.is_empty(): return
	var font := ThemeDB.fallback_font
	var view := _overlay.size
	var t := float(_words.t)
	var px := int(view.y*0.06*(1.0+0.35*exp(-t*14.0)))
	var a2 := 1.0-smoothstep(0.75,1.1,t)
	var text := str(_words.text)
	var w := font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x
	var at := Vector2(view.x*0.5-w*0.5,view.y*0.3)
	_overlay.draw_string_outline(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,px,int(px*0.18),Color(0.1,0.06,0.02,0.8*a2))
	_overlay.draw_string(font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,px,Color(_words.color as Color,a2))

## The tell round the plane on the screen, so a ball off the edge reads too: a
## ring closing from TELL_RING.x to .y px as the ball comes on, a pip on it the
## way the ball comes from, white and thick while a roll now would parry it.
func _draw_tell() -> void:
	if _tell_on.is_empty() or game.camera == null: return
	var cam: Camera3D = game.camera
	var plane: Vector3 = game.plane.position
	if cam.is_position_behind(plane): return
	var c := cam.unproject_position(plane)
	var k := float(_tell_on.k)
	var now := bool(_tell_on.now)
	var col: Color = _tell_on.col
	var px := _overlay.size.y/900.0
	var r := lerpf(TELL_RING.y,TELL_RING.x,k)*px
	var a := 1.0 if now else lerpf(0.85,0.25,k)
	_overlay.draw_arc(c,r,0.0,TAU,64,Color(col,a*0.9),(5.0 if now else 2.0)*px,true)
	var rel: Vector3 = ((_tell_on.shot as Dictionary).at as Vector3)-plane
	var b := cam.global_transform.basis
	var way := Vector2(rel.dot(b.x),-rel.dot(b.y))
	if way.length() < 0.001: return
	way = way.normalized()
	_overlay.draw_circle(c+way*r,(9.0 if now else 6.0)*px,Color(col,a))

func _play(kind: String, gain: float, pitch: float) -> void:
	if not bool(game.sound.audible): return
	var p: AudioStreamPlayer = null
	for q: AudioStreamPlayer in _players:
		if not q.playing:
			p = q
			break
	if p == null:
		if _players.size() >= 6: p = _players[0]
		else:
			p = AudioStreamPlayer.new()
			p.bus = &"SFX"
			add_child(p)
			_players.append(p)
	p.stream = _sound(kind)
	p.volume_db = linear_to_db(gain)
	p.pitch_scale = pitch
	p.play()

## Placeholder sounds, baked once from the old in-code makers to
## assets/audio/parry/ (making them on the first parry hitched ~40 ms).
const SOUNDS := {
	"ring": preload("res://assets/audio/parry/ring.wav"),
	"boom": preload("res://assets/audio/parry/boom.wav"),
	"clunk": preload("res://assets/audio/parry/clunk.wav"),
}

static func _sound(kind: String) -> AudioStream:
	return SOUNDS[kind]
