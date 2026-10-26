extends Node3D
## Flying low over water (the sea, a river, a pond): the plane feels it and
## throws it. Under REACH wingspans of belly clearance over water, fast:
## - The cushion (`feel`, before the plane steps; SkyPlane `cushion`,
##   `cushion_drag`). Ground effect: from the top of the reach down to RIDE it
##   takes away the low zone's settling (scripts/flight_weight.gd `settle`,
##   `settle_pitch`, as deep as `low` is), so hands-off the plane eases down
##   onto a ride RIDE spans up in every preset; under the ride it pushes back
##   up, HARD m/s at the surface, and soaks up a sink (DAMP of it). A firm
##   push still gets through to the water. It drags DRAG m/s² by closeness²,
##   and shudders (SHUDDER m/s up and down and the drawn plane's roll,
##   SHAKE_ROLL rad) by closeness^1.5. Over the land nothing changes.
## - Touching the water is what it was (scripts/endless/flight_contact.gd): a
##   scrape that bounces it off (a crash steep and fast). It now throws a big
##   splash (`splash`) and douses the screen.
## - Spray, GPU particles (shaders/water_spray_process.gdshader, drawn by
##   shaders/water_spray.gdshader): a rooster tail of drops thrown up behind
##   the tail, two fans of drops out sideways from under the wings, and mist,
##   all by `spray` (closeness^SPRAY_POW times the speed's share), higher,
##   harder and denser the lower it skims. A wingtip low over the water
##   throws its own (TIP_TOUCH m and under).
## - Marks on the water (shaders/water_mark.gdshader, one MultiMesh): patches
##   of churned foam laid every FOAM_EVERY m under the tail and at either
##   arm of the wake, spreading and thinning into lace over FOAM_LIFE s;
##   ripple rings off a wingtip or the belly nearly touching, and off a
##   splash. On every water (the sea's own wake, scripts/endless/
##   endless_sea.gd, still draws as before).
## - The screen (scripts/endless/screen_wet.gd): the chase camera inside
##   the plume gets wet (WET_RATE a second at full spray), a splash douses
##   it. `douse(amount)` does it from anything else, with a splash in the
##   sound and the air muffled for a moment (FlightSound `muffle`).
## - Sound: a hiss of spray by `spray` (noise made here), a churn under it
##   (foley water-swirl-loop), tosses and splashes.
## - `hum()` (0 to 1) for the pad's rumble, and "splash" in the frame's
##   events when a wingtip first touches or it splashes.
## High up nothing runs: the emitters stop and the marks are hidden.
## `--water-contact=0` turns it all off (the old spray trail comes back).

const Field = preload("res://scripts/endless/land_field.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const SkyGlide = preload("res://scripts/sky_glide.gd")
const FlightWeight = preload("res://scripts/flight_weight.gd")
const FlightSound = preload("res://scripts/endless/flight_sound.gd")
const ScreenWet = preload("res://scripts/endless/screen_wet.gd")

## The reach and the ride (wingspans of belly clearance over the water).
const REACH := 1.0
const RIDE := 0.32
## Under the ride: up to HARD m/s at the surface (by the share of the way
## down, squared), and DAMP of a sink soaked up anywhere in the reach.
const HARD := 5.0
const DAMP := 0.5
## Drag (m/s² at the surface, by closeness²); the shudder (m/s and rad, by
## closeness^1.5 and the speed over cruise) at these frequencies (Hz).
const DRAG := 1.8
const SHUDDER := 0.45
const SHAKE_ROLL := 0.035
const SHAKE_PITCH := 0.015
const SHUDDER_HZ := Vector3(7.3,11.9,17.1)
## The spray: closeness to this power, times the speed's share from
## SPRAY_SPEED.x m/s to SPRAY_SPEED.y of cruise.
const SPRAY_POW := 1.3
const SPRAY_SPEED := Vector2(9.0,0.9)
## A wingtip this near the water (m) throws spray and rings.
const TIP_TOUCH := 1.0
## Foam: a patch every FOAM_EVERY m, living FOAM_LIFE s, at least
## FOAM_LEAST closeness; arms ARM spans out, drifting ARM_DRIFT m/s outward.
const FOAM_EVERY := 2.4
const FOAM_LIFE := 4.0
const FOAM_LEAST := 0.12
const ARM := 0.55
const ARM_DRIFT := 1.6
## Rings: living RING_LIFE s, one every RING_EVERY s off a touching
## wingtip, or the belly over RING_BELLY closeness.
const RING_LIFE := 1.7
const RING_EVERY := 0.11
const RING_BELLY := 0.72
## Marks sit this far over the water (m): the sea's heave isn't all on the CPU.
const LIFT_SEA := 0.15
const LIFT_STILL := 0.05
const MARKS := 160
## The screen: wet a second inside the plume at full spray; a splash's.
const WET_RATE := 1.1
const SPLASH_WET := 0.9
## The sound's gains (linear, SFX): the hiss and the churn at full spray.
const HISS := 0.32
const CHURN := 0.16
const TOSS := 0.45
const SPLASH := 0.6
## The pad: a flutter on the hum.
const FLUTTER := 0.35

enum { NONE, SEA, RIVER, POND }

## Read out each frame, for the HUD, the rumble and probes.
var kind := NONE
var level := -INF
var clear := INF
var close := 0.0
var spray := 0.0
var tips := Vector2.ZERO
var lift := 0.0
var drag := 0.0
var shudder := 0.0
var on := true

var _game: Node3D
var _field
var _tail: GPUParticles3D
var _fan: GPUParticles3D
var _mist: GPUParticles3D
var _tip: Array[GPUParticles3D] = []
var _bursts: Array[GPUParticles3D] = []
var _burst_mists: Array[GPUParticles3D] = []
var _burst_next := 0
var _m_at := PackedVector3Array()
var _m_vel := PackedVector3Array()
var _m_age := PackedFloat32Array()
var _m_life := PackedFloat32Array()
var _m_kind := PackedFloat32Array()
var _m_seed := PackedFloat32Array()
var _m_k := PackedFloat32Array()
var _m_from := PackedFloat32Array()
var _m_to := PackedFloat32Array()
var _m_cos := PackedFloat32Array()
var _m_sin := PackedFloat32Array()
var _m_long := PackedFloat32Array()
var _m_next := 0
var _live_marks := 0
var _was_live := false
var _multi: MultiMesh
var _mark_node: MultiMeshInstance3D
var _laid := 0.0
var _ring_wait := Vector3.ZERO
var _last := Vector3.INF
var _clock := 0.0
var _tip_was := [false,false]
var _rng := RandomNumberGenerator.new()
var screen: CanvasLayer
var _muffle := 0.0
var _hiss
var _churn
var _shots: Array[AudioStreamPlayer] = []
var _clips := {}
var _audible := false
var _hum := 0.0
var _sent := {}
var _buffer := PackedFloat32Array()

static func wanted() -> bool:
	return not ("--water-contact=0" in preload("res://scripts/launch_args.gd").user_args())

static func near_start_wanted() -> bool:
	return "--water-near-start" in preload("res://scripts/launch_args.gd").user_args()

func setup(game: Node3D) -> void:
	_game = game
	_field = game.field
	_rng.randomize()
	_tail = _emitter(1800,1.2,0,false)
	_fan = _emitter(1400,0.9,0,false)
	_mist = _emitter(700,1.8,1,false)
	for i in range(2): _tip.append(_emitter(260,0.8,0,false))
	for i in range(3):
		_bursts.append(_emitter(360,1.3,0,true))
		_burst_mists.append(_emitter(140,2.2,1,true))
	_multi = MultiMesh.new()
	_multi.transform_format = MultiMesh.TRANSFORM_3D
	_multi.use_custom_data = true
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	_multi.mesh = plane
	_multi.instance_count = MARKS
	_multi.visible_instance_count = 0
	_mark_node = MultiMeshInstance3D.new()
	_mark_node.multimesh = _multi
	_mark_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/water_mark.gdshader")
	_mark_node.material_override = m
	_mark_node.custom_aabb = AABB(Vector3(-4000,-200,-4000),Vector3(8000,400,8000))
	add_child(_mark_node)
	screen = ScreenWet.new()
	game.add_child(screen)
	var look = game.get("look")
	if look != null and look.water != null: look.water.wake_foam = 0.0
	_sound()

## A spray emitter: `amount` particles living `life` s, drops (0) or mist (1),
## a one-shot burst or running.
func _emitter(amount: int, life: float, look: int, burst: bool) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = burst
	p.explosiveness = 1.0 if burst else 0.0
	p.randomness = 0.3
	p.local_coords = false
	p.fixed_fps = 0
	p.interpolate = false
	p.emitting = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-60,-8,-60),Vector3(120,40,120))
	var process := ShaderMaterial.new()
	process.shader = preload("res://shaders/water_spray_process.gdshader")
	p.process_material = process
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var draw := ShaderMaterial.new()
	draw.shader = preload("res://shaders/water_spray.gdshader")
	draw.set_shader_parameter("kind",look)
	if look == 0: draw.set_shader_parameter("opacity",1.0)
	if look == 1:
		draw.set_shader_parameter("opacity",0.3)
		draw.set_shader_parameter("near_fade",Vector2(2.5,7.0))
		draw.set_shader_parameter("glow",0.5)
		draw.set_shader_parameter("backlight",0.85)
	quad.material = draw
	p.draw_pass_1 = quad
	add_child(p)
	return p

func _sound() -> void:
	_audible = FlightSound.wanted()
	_hiss = FlightSound.Bed.new()
	_churn = FlightSound.Bed.new()
	_hiss.attack = 9.0
	_hiss.release = 3.0
	_churn.attack = 5.0
	_churn.release = 2.0
	if not _audible: return
	_hiss.player = _loop_player(_noise_loop())
	var swirl := (load("res://assets/audio/foley/water-swirl-loop.wav") as AudioStreamWAV).duplicate() as AudioStreamWAV
	swirl.loop_mode = AudioStreamWAV.LOOP_FORWARD
	swirl.loop_begin = 0
	swirl.loop_end = roundi(swirl.get_length()*swirl.mix_rate)
	_churn.player = _loop_player(swirl)
	for i in range(3):
		var s := AudioStreamPlayer.new()
		s.bus = FlightSound.SFX
		add_child(s)
		_shots.append(s)
	_clips = {
		"toss":_takes("res://assets/audio/foley/water-toss-%d.wav",3),
		"splash":_takes("res://assets/audio/foley/water-splash-%d.wav",6),
		"pop":_takes("res://assets/audio/foley/water-pop-%d.wav",6),
	}

static func _takes(pattern: String, n: int) -> Array:
	var out := []
	for i in range(n): out.append(load(pattern % (i+1)))
	return out

func _loop_player(stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = FlightSound.SFX
	player.volume_db = -80.0
	add_child(player)
	return player

## The hiss: 1.5 s of noise, a bright fizz (white noise less a slow copy of
## itself) with a crackle of tiny drops through it, looped.
func _noise_loop() -> AudioStreamWAV:
	const RATE := 22050
	var n := int(RATE*1.5)
	var data := PackedByteArray()
	data.resize(n*2)
	var slow := 0.0
	var crackle := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(n):
		var white := rng.randf()*2.0-1.0
		slow = lerpf(slow,white,0.18)
		if rng.randf() < 0.012: crackle = rng.randf_range(0.4,1.0)*(1.0 if rng.randf() < 0.5 else -1.0)
		crackle *= 0.82
		var v := clampf((white-slow)*0.55+crackle*0.5,-1.0,1.0)
		data.encode_s16(i*2,int(v*30000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav

func _shot(kind_name: String, gain: float, pitch := 1.0) -> void:
	if not _audible or gain <= 0.0: return
	var takes: Array = _clips.get(kind_name,[])
	if takes.is_empty(): return
	var player: AudioStreamPlayer = _shots[0]
	for s in _shots:
		if not s.playing:
			player = s
			break
	player.stream = takes[_rng.randi_range(0,takes.size()-1)]
	player.volume_db = linear_to_db(gain)+_rng.randf_range(-1.5,1.5)
	player.pitch_scale = pitch*_rng.randf_range(0.93,1.07)
	player.play()

# --- The cushion ------------------------------------------------------------

## Before the plane steps: the cushion's lift, drag and shudder over water
## (SkyPlane `cushion`, `cushion_drag`).
func feel(delta: float) -> void:
	var plane = _game.plane
	plane.cushion = 0.0
	plane.cushion_drag = 0.0
	lift = 0.0
	drag = 0.0
	shudder = 0.0
	_clock += delta
	if not on or not _game.hand_landing.flying(): return
	var p: Vector3 = plane.position
	var span := WorldScale.span
	var reach := REACH*span
	var c := p.y-SkyGlide.SKIM-float(plane.water)
	if c > reach or float(_field.height(p.x,p.z)) > float(plane.water)-0.02: return
	var speed := float(plane.speed)
	var fast := smoothstep(FlightWeight.LOW_SLOW,maxf(plane.cruise()*FlightWeight.LOW_FAST,FlightWeight.LOW_SLOW+1.0),speed)
	if fast <= 0.0: return
	var ride := RIDE*span
	var g := smoothstep(reach,ride,c)
	var w: Dictionary = plane.weight
	var pace := maxf(float(plane.pace_scale),0.1)
	var settle := float(w.get("settle",0.0))+maxf(0.0,-float(w.get("settle_pitch",0.0))/pace)*speed
	var under := clampf((ride-c)/ride,0.0,1.0)
	var up := settle*float(plane.low)*g+HARD*under*under
	var vy := float(plane.velocity.y)
	if vy < 0.0: up += DAMP*-vy*g
	var k := clampf(1.0-c/reach,0.0,1.0)
	var share := clampf(speed/plane.cruise(),0.5,1.5)
	var t := _clock*TAU
	var wave := sin(t*SHUDDER_HZ.x)*0.5+sin(t*SHUDDER_HZ.y+1.1)*0.3+sin(t*SHUDDER_HZ.z+2.3)*0.2
	shudder = pow(k,1.5)*share*fast
	lift = up*fast
	drag = DRAG*k*k*fast
	plane.cushion = lift+SHUDDER*shudder*wave
	plane.cushion_drag = drag

## The drawn plane shaken by the shudder (after it is posed and scaled).
func shake_figure(figure: Node3D) -> void:
	if shudder <= 0.0: return
	var t := _clock*TAU
	figure.rotate_object_local(Vector3.FORWARD,SHAKE_ROLL*shudder*(sin(t*SHUDDER_HZ.y)*0.6+sin(t*SHUDDER_HZ.z*1.3+0.7)*0.4))
	figure.rotate_object_local(Vector3.RIGHT,SHAKE_PITCH*shudder*sin(t*SHUDDER_HZ.x*1.7+0.3))

# --- Every frame ------------------------------------------------------------

## After the plane moved: what is under it, the spray, the marks, the screen
## and the sound. `events` gets "splash" ({k}) when a wingtip first touches.
func step(delta: float, events: Dictionary) -> void:
	var plane = _game.plane
	var flying: bool = on and _game.hand_landing.flying()
	var p: Vector3 = plane.position
	var span := WorldScale.span
	var reach := REACH*span
	kind = NONE
	close = 0.0
	spray = 0.0
	tips = Vector2.ZERO
	clear = INF
	var speed := float(plane.velocity.length())
	if flying:
		level = float(plane.water)
		clear = p.y-SkyGlide.SKIM-level
		if clear < reach+span and float(_field.height(p.x,p.z)) < level-0.02:
			var river: float = _field.river_y(p.x,p.z)
			if is_nan(river) or river < Field.SEA_Y+0.05: kind = SEA
			else: kind = POND if (_field.last_river_flow as Vector2).length() < 0.3 else RIVER
		else:
			clear = INF
	var way := Vector3(plane.velocity.x,0.0,plane.velocity.z)
	var ahead: Vector3 = way.normalized() if way.length() > 0.5 else plane.forward()*Vector3(1,0,1)
	ahead = ahead.normalized() if ahead.length() > 0.01 else Vector3.FORWARD
	var right := ahead.cross(Vector3.UP).normalized()
	var fast := smoothstep(SPRAY_SPEED.x,maxf(plane.cruise()*SPRAY_SPEED.y,SPRAY_SPEED.x+1.0),speed)
	if kind != NONE:
		close = clampf(1.0-clear/reach,0.0,1.0)
		spray = pow(close,SPRAY_POW)*fast
		# The wingtips, as the near misses place them (scripts/endless/near_miss.gd BODY).
		var xf := Transform3D(Basis.from_euler(Vector3(float(plane.pitch),float(plane.heading),-(float(plane.bank)+float(plane.spin)))),p)
		for s in range(2):
			var tip: Vector3 = xf*(Vector3(-0.7 if s == 0 else 0.7,-0.1,0.0)*WorldScale.plane)
			var tc := tip.y-level
			var wet := tc < TIP_TOUCH and float(_field.height(tip.x,tip.z)) < level-0.02
			tips[s] = clampf(1.0-tc/TIP_TOUCH,0.0,1.0)*fast if wet else 0.0
			_tip_step(s,tip,ahead,right,speed)
			if tips[s] > 0.15 and not _tip_was[s]:
				events["splash"] = {"k":tips[s]*0.6}
				_shot("pop",0.25+0.3*tips[s],1.2)
			_tip_was[s] = tips[s] > 0.1
	else:
		for s in range(2):
			_tip[s].emitting = false
			_tip_was[s] = false
	var travel := p-_last if _last != Vector3.INF else Vector3.ZERO
	if travel.length() > 30.0: travel = Vector3.ZERO
	_last = p
	_spray_step(p,ahead,right,speed,travel)
	_marks_step(delta,p,ahead,right,speed,travel)
	_screen_step(delta,p,speed)
	_sound_step(delta)
	_hum = clampf(spray+maxf(tips.x,tips.y)*0.5,0.0,1.0)

## The running spray under the plane: on the water under its tail.
func _spray_step(p: Vector3, ahead: Vector3, right: Vector3, speed: float, travel: Vector3) -> void:
	var s := snappedf(spray,0.02)
	var running := spray > 0.004
	for e: GPUParticles3D in [_tail,_fan,_mist]:
		if running and not e.emitting: e.emitting = true
		elif not running and e.emitting: e.emitting = false
	if not running: return
	var span := WorldScale.span
	var foot := Vector3(p.x,level,p.z)-ahead*span*0.3
	_tail.global_position = foot
	_fan.global_position = foot+ahead*span*0.25
	_mist.global_position = foot
	var water_y := level
	var back := clampf(speed/40.0,0.4,1.6)
	_params(_tail,{"rate":clampf(s*1.3,0.0,1.0),"travel":travel,"ahead":ahead,"right":right,"plane_speed":speed,
		"carry":Vector2(0.25,0.55),"up_speed":Vector2(1.0,3.0+11.0*s*s),"side_speed":Vector2(0.0,0.6+1.6*s),
		"back_speed":Vector2(0.0,2.0*back),"strength":0.6+0.5*s,"box":Vector3(0.12+0.12*s,0.05,0.3)*span,
		"size_range":Vector2(0.012,0.035)*(0.8+0.6*s),"growth":0.3,"drag":0.4,"gravity":9.8,"buoyancy":0.0,
		"stretch":0.03,"water_y":water_y})
	var fan := smoothstep(0.15,0.8,s)
	_params(_fan,{"rate":fan,"travel":travel,"ahead":ahead,"right":right,"plane_speed":speed,
		"carry":Vector2(0.45,0.7),"up_speed":Vector2(1.0,2.0+5.0*s),"side_speed":Vector2(2.0,4.0+8.0*s),
		"back_speed":Vector2(0.0,1.5),"strength":0.6+0.5*s,"box":Vector3(0.3,0.03,0.25)*span,
		"size_range":Vector2(0.01,0.03),"growth":0.3,"drag":0.7,"gravity":9.8,"buoyancy":0.0,
		"stretch":0.03,"water_y":water_y})
	_params(_mist,{"rate":clampf(pow(s,0.8)*1.1,0.0,1.0),"travel":travel,"ahead":ahead,"right":right,"plane_speed":speed,
		"carry":Vector2(0.35,0.6),"up_speed":Vector2(0.8,2.0+5.0*s),"side_speed":Vector2(0.3,1.5+3.0*s),
		"back_speed":Vector2(0.0,1.0),"strength":1.0,"box":Vector3(0.3,0.1,0.4)*span,
		"size_range":Vector2(0.2,0.45)*(0.6+0.9*s)*span*0.5,"growth":3.5,"drag":1.2,"gravity":1.5,"buoyancy":0.9,
		"stretch":0.0,"water_y":water_y-2.0})

func _tip_step(s: int, tip: Vector3, ahead: Vector3, right: Vector3, speed: float) -> void:
	var e := _tip[s]
	var k: float = snappedf(tips[s],0.02)
	if k <= 0.01:
		e.emitting = false
		return
	e.emitting = true
	e.global_position = Vector3(tip.x,level,tip.z)
	var out := right*(-1.0 if s == 0 else 1.0)
	_params(e,{"rate":clampf(k*1.3,0.0,1.0),"travel":ahead*speed/60.0,"ahead":ahead,"right":out,"plane_speed":speed,
		"carry":Vector2(0.25,0.6),"up_speed":Vector2(1.5,3.0+7.0*k),"side_speed":Vector2(0.5,2.5+3.0*k),
		"back_speed":Vector2(0.0,2.0),"strength":0.6+0.6*k,"box":Vector3(0.25,0.02,0.25),
		"size_range":Vector2(0.012,0.035),"growth":0.3,"drag":0.6,"gravity":9.8,"buoyancy":0.0,
		"stretch":0.03,"water_y":level})

## The emitter's uniforms; only those that changed since last set (each
## set is a call into the server).
func _params(e: GPUParticles3D, values: Dictionary) -> void:
	var m := e.process_material as ShaderMaterial
	var was: Dictionary = _sent.get(e,{})
	for key: String in values:
		var v: Variant = values[key]
		if was.has(key) and was[key] == v: continue
		was[key] = v
		m.set_shader_parameter(key,v)
	_sent[e] = was

## A splash where it hit the water (a scrape, a crash): `k` 0 to 1 (more
## for a crash), drops and mist thrown up and out, rings, the screen doused
## and a splash in the sound; "splash" for the rumble.
func splash(at: Vector3, k: float, events := {}) -> void:
	if not on: return
	var plane = _game.plane
	var speed := float(plane.velocity.length()) if plane != null else 20.0
	var way: Vector3 = Vector3(plane.velocity.x,0.0,plane.velocity.z) if plane != null else Vector3.FORWARD
	var ahead: Vector3 = way.normalized() if way.length() > 0.5 else Vector3.FORWARD
	var right: Vector3 = ahead.cross(Vector3.UP).normalized()
	var y: float = _game.water_at(at)
	var foot := Vector3(at.x,y,at.z)
	var i := _burst_next
	_burst_next = (i+1)%_bursts.size()
	var big := clampf(k,0.2,1.6)
	for e: GPUParticles3D in [_bursts[i],_burst_mists[i]]:
		e.global_position = foot
		var mist := e == _burst_mists[i]
		_params(e,{"rate":1.0,"travel":Vector3.ZERO,"ahead":ahead,"right":right,"plane_speed":speed,
			"carry":Vector2(0.2,0.6) if not mist else Vector2(0.15,0.4),
			"up_speed":(Vector2(3.0,12.0) if not mist else Vector2(1.0,5.0))*big,
			"side_speed":(Vector2(1.0,8.0) if not mist else Vector2(0.5,4.0))*big,
			"back_speed":Vector2(0.0,3.0),"strength":1.0,"box":Vector3(0.6,0.05,0.8)*WorldScale.span*0.5,
			"size_range":Vector2(0.015,0.045) if not mist else Vector2(0.45,0.9)*big,"growth":0.6 if not mist else 2.5,
			"drag":0.45 if not mist else 1.3,"gravity":9.8 if not mist else 1.5,"buoyancy":0.0 if not mist else 0.8,
			"stretch":0.035 if not mist else 0.0,"water_y":y if not mist else y-2.0})
		e.restart()
		e.emitting = true
	for r in range(3): _ring(foot+Vector3(_rng.randf_range(-1,1),0,_rng.randf_range(-1,1))*0.8,0.8+0.4*big,big*(0.6+0.3*r))
	_lay_foam(foot,ahead,big,0.0,1.6)
	douse(clampf(SPLASH_WET*big,0.0,1.0) if _camera_near(foot,14.0) else 0.0)
	_shot("splash",SPLASH*clampf(0.5+0.5*big,0.0,1.0),lerpf(1.1,0.85,clampf(big,0.0,1.0)))
	events["splash"] = {"k":clampf(big,0.0,1.0)}

func _camera_near(at: Vector3, within: float) -> bool:
	var cam: Node3D = _game.get_viewport().get_camera_3d()
	return cam != null and cam.global_position.distance_to(at) < within

## Douse the screen (0 to 1; ScreenWet `wet`) with a splash in the sound
## and the air muffled a moment, the more the more it's doused. For a
## waterfall flown through, say.
func douse(amount: float) -> void:
	if amount <= 0.0 or screen == null: return
	screen.wet(amount)
	if amount > 0.2:
		_muffle = maxf(_muffle,clampf(amount,0.0,1.0))
		_shot("toss",TOSS*clampf(amount,0.3,1.0),_rng.randf_range(0.95,1.15))

# --- Marks ------------------------------------------------------------------

func _marks_step(delta: float, p: Vector3, ahead: Vector3, right: Vector3, speed: float, travel: Vector3) -> void:
	var span := WorldScale.span
	if close > FOAM_LEAST and speed > SPRAY_SPEED.x:
		_laid += travel.length()
		var k := smoothstep(FOAM_LEAST,0.9,close)*spray/maxf(pow(close,SPRAY_POW),0.001)
		while _laid >= FOAM_EVERY:
			_laid -= FOAM_EVERY
			var foot := Vector3(p.x,level,p.z)-ahead*span*0.4-travel.normalized()*_laid
			_lay_foam(foot,ahead,k,0.0,0.6+0.8*close)
			if close > 0.3:
				for side in [-1.0,1.0]:
					_lay_foam(foot+right*side*span*ARM,ahead,k*0.7,side*ARM_DRIFT*close,0.5+0.5*close,right)
	else:
		_laid = 0.0
	_ring_wait -= Vector3.ONE*delta
	if kind != NONE:
		for s in range(2):
			if tips[s] > 0.2 and _ring_wait[s] <= 0.0:
				_ring_wait[s] = RING_EVERY
				var xf := Transform3D(Basis.from_euler(Vector3(float(_game.plane.pitch),float(_game.plane.heading),-(float(_game.plane.bank)+float(_game.plane.spin)))),p)
				var tip: Vector3 = xf*(Vector3(-0.7 if s == 0 else 0.7,-0.1,0.0)*WorldScale.plane)
				_ring(Vector3(tip.x,level,tip.z),0.5,tips[s])
		if close > RING_BELLY and _ring_wait.z <= 0.0:
			_ring_wait.z = RING_EVERY
			_ring(Vector3(p.x,level,p.z)-ahead*span*0.2,0.7,smoothstep(RING_BELLY,1.0,close))
	_draw_marks(delta)

## A foam patch at `at` (on the water), `k` strong, drifting `drift` m/s
## along `out`, `size` spans across at first.
func _lay_foam(at: Vector3, ahead: Vector3, k: float, drift: float, size: float, out := Vector3.ZERO) -> void:
	if k <= 0.02: return
	_mark(at,out*drift,FOAM_LIFE*_rng.randf_range(0.8,1.2),0,k,size*WorldScale.span,size*WorldScale.span*3.2,atan2(ahead.x,ahead.z),1.6)

func _ring(at: Vector3, size: float, k: float) -> void:
	if k <= 0.02: return
	_mark(at,Vector3.ZERO,RING_LIFE,1,k,size,size+5.5,0.0,1.0)

## A mark into the next free slot (else the next in turn): MARKS slots of
## packed arrays, a slot free while its life is 0.
func _mark(at: Vector3, vel: Vector3, life: float, mark_kind: int, k: float, from: float, to: float, yaw: float, long: float) -> void:
	if _m_life.is_empty(): _slots()
	var slot := _m_next
	for i in range(MARKS):
		var j := (_m_next+i)%MARKS
		if _m_life[j] <= 0.0:
			slot = j
			break
	_m_next = (slot+1)%MARKS
	_m_at[slot] = at+Vector3.UP*(LIFT_SEA if kind == SEA or kind == NONE else LIFT_STILL)
	_m_vel[slot] = vel
	_m_age[slot] = 0.0
	_m_life[slot] = life
	_m_kind[slot] = float(mark_kind)
	_m_seed[slot] = _rng.randf()
	_m_k[slot] = clampf(k,0.0,1.0)
	_m_from[slot] = from
	_m_to[slot] = to
	_m_cos[slot] = cos(yaw)
	_m_sin[slot] = sin(yaw)
	_m_long[slot] = long

func _slots() -> void:
	for a in [_m_age,_m_life,_m_kind,_m_seed,_m_k,_m_from,_m_to,_m_cos,_m_sin,_m_long]: a.resize(MARKS)
	_m_life.fill(0.0)
	_m_at.resize(MARKS)
	_m_vel.resize(MARKS)
	_buffer.resize(MARKS*16)
	_buffer.fill(0.0)
	for j in range(MARKS): _buffer[j*16+5] = 1.0

## The marks aged and drifted, and the whole MultiMesh buffer set in one
## call (per slot a 3x4 transform by rows, then the custom data; a free slot
## scaled to nothing).
func _draw_marks(delta: float) -> void:
	if _m_life.is_empty(): _slots()
	var live := 0
	var calm := exp(-delta/1.5)
	for j in range(MARKS):
		var life := _m_life[j]
		var o := j*16
		if life <= 0.0: continue
		var age := _m_age[j]+delta
		if age >= life:
			_m_life[j] = 0.0
			_buffer[o] = 0.0
			_buffer[o+2] = 0.0
			_buffer[o+8] = 0.0
			_buffer[o+10] = 0.0
			continue
		live += 1
		_m_age[j] = age
		var vel := _m_vel[j]
		var at := _m_at[j]
		if vel != Vector3.ZERO:
			at += vel*delta
			_m_at[j] = at
			_m_vel[j] = vel*calm
		var t := age/life
		var size := lerpf(_m_from[j],_m_to[j],1.0-pow(1.0-t,2.2))
		var c := _m_cos[j]
		var sn := _m_sin[j]
		var long := size*_m_long[j]
		_buffer[o] = c*size
		_buffer[o+2] = sn*long
		_buffer[o+3] = at.x
		_buffer[o+7] = at.y
		_buffer[o+8] = -sn*size
		_buffer[o+10] = c*long
		_buffer[o+11] = at.z
		_buffer[o+12] = t
		_buffer[o+13] = _m_kind[j]
		_buffer[o+14] = _m_seed[j]
		_buffer[o+15] = _m_k[j]
	_live_marks = live
	_mark_node.visible = live > 0
	if live == 0 and not _was_live: return
	_was_live = live > 0
	_multi.buffer = _buffer
	_multi.visible_instance_count = MARKS

# --- The screen and the sound -------------------------------------------------

func _screen_step(delta: float, p: Vector3, speed: float) -> void:
	var cam: Camera3D = _game.get_viewport().get_camera_3d()
	if screen == null or cam == null: return
	# Inside the plume: the eye under the top of the thrown water, near it.
	if spray > 0.05 and kind != NONE:
		var top := level+0.6+5.0*pow(spray,1.4)
		var over := cam.global_position.y-level
		var flat := Vector2(cam.global_position.x-p.x,cam.global_position.z-p.z).length()
		var inside := (1.0-smoothstep(top*0.55,top*1.15,level+over))*(1.0-smoothstep(10.0,22.0,flat))
		var tip := maxf(tips.x,tips.y)*0.35
		var rate := (spray*inside+tip*(1.0-smoothstep(6.0,14.0,flat)))*WET_RATE*delta
		if rate > 0.0: screen.wet(rate)
	# The airflow runs out from where the plane heads on the screen.
	var ahead := cam.global_position+(_game.plane.velocity as Vector3).normalized()*50.0
	var toward := get_viewport().get_visible_rect().size*0.5
	if not cam.is_position_behind(ahead): toward = cam.unproject_position(ahead)
	screen.step(delta,toward,speed/maxf(float(_game.plane.cruise()),1.0))
	if screen.doused > 0.0:
		_muffle = maxf(_muffle,clampf(screen.doused*1.5,0.0,1.0)*0.6)
		screen.doused = 0.0

func _sound_step(delta: float) -> void:
	_muffle *= exp(-delta/0.35)
	var sound = _game.get("sound")
	if sound != null and "muffle" in sound: sound.muffle = _muffle
	_hiss.goal = HISS*pow(spray,1.1)+0.12*maxf(tips.x,tips.y)
	_hiss.pitch_goal = 0.75+0.55*spray
	_churn.goal = CHURN*smoothstep(0.35,1.0,spray)
	_churn.pitch_goal = 1.25+0.5*spray
	_hiss.step(delta)
	_churn.step(delta)

## The pad's hum over water (0 to 1), fluttering.
func hum() -> float:
	if _hum <= 0.0: return 0.0
	return _hum*(1.0-FLUTTER+FLUTTER*_rng.randf())

## One line for the F1 numbers.
func note() -> String:
	if kind == NONE: return "water: -"
	return "water: %s  clear %.2f m  close %.2f  spray %.2f  tips %.2f/%.2f  lift %.2f  drag %.2f  shudder %.2f  marks %d  drops %d" % [["-","sea","river","pond"][kind],clear,close,spray,tips.x,tips.y,lift,drag,shudder,_live_marks,screen.count() if screen != null else 0]

# --- The near start --------------------------------------------------------

## A start low over the sea off a river's mouth near `from` (--water-near-start):
## {at (x, z), heading (rad, Godot's), alt (m over the sea)}, or {} if none
## within 4 km. Rings out from `from` find the nearest river water a few
## metres over the sea, then the sea within 500 m of it; the start is
## SEA_BACK m out from there, heading back toward the river.
const SEA_BACK := 260.0
static func near_start(field, from: Vector2) -> Dictionary:
	var step := 50.0
	var r := 0.0
	while r < 4000.0:
		var n := maxi(1,int(TAU*r/step))
		for i in range(n):
			var a := TAU*float(i)/float(n)
			var p := from+Vector2(cos(a),sin(a))*r
			var river: float = field.river_y(p.x,p.y)
			if is_nan(river) or river < Field.SEA_Y+0.05 or river > Field.SEA_Y+5.0: continue
			if (field.last_river_flow as Vector2).length() < 0.3: continue
			# The sea round it: the nearest open water a little way out.
			var best := Vector2.INF
			for ring: float in [120.0,220.0,340.0,480.0]:
				for j in range(32):
					var b := TAU*float(j)/32.0
					var q := p+Vector2(cos(b),sin(b))*ring
					if float(field.height(q.x,q.y)) < Field.SEA_Y-4.0 and is_nan(float(field.river_y(q.x,q.y))):
						best = q
						break
				if best != Vector2.INF: break
			if best == Vector2.INF: continue
			var out := (best-p).normalized()
			var at := best+out*SEA_BACK
			return {"at":at,"heading":atan2(out.x,out.y),"alt":3.0,"mouth":p}
		r += step
	return {}
