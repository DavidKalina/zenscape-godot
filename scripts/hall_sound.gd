extends Node
## The Sundered line's room sound (docs/scenic/hall-sound.md): the plane's
## sound changing with the hall it flies through (scripts/hall_line.gd).
## Built on the isle's own sound (scripts/kit_isle/kit_audio.gd): its SFX
## bus (the engine, the air, the whooshes), its engine bed and its one-shots.
##
## - The room, from the hall's own data: the Sundered planner's bay plans
##   (each piece's, `Sundered._plans`: roof whole, broken or open; each
##   wall's breach; the slit's screens; torn ends). Where the plane is along
##   a piece and across it gives the bay, blended into its neighbours, so
##   the room glides from bay to bay; out of every piece (a gap, past a torn
##   end, over the roof) it is open air. `enclosure` (0 open, 1 a whole
##   roofed bay walled both sides) and `pierce` (how much a closed shell is
##   holed: a slit's screen, arches, doors, a broken roof), each eased in
##   time.
## - In a roofed nave: on the SFX bus, early reflections (a two-tap delay),
##   a reverb and a low-pass closing in, a little gain; the engine bed
##   louder and a little lower (KitAudio `room_engine`); a whoosh as each
##   column at a bay line passes close to a wingtip (KitAudio `shot`, placed
##   at the column).
## - Pierced: a breathy, organ-like wind drone (two loops baked here once,
##   on a worker: a low pipe and a twelfth over it that comes in as the
##   piercing swells), by the airspeed.
## - Breaking out (enclosure falling away after a closed stretch): the
##   release, an envelope that thins the SFX bus (a high-pass), pulls the
##   engine back and dips everything to near quiet for a moment, then lets
##   it come back.
##
## `--hall-sound=0` turns it off. Made by the aqueduct isle with its chain
## (`attach`); it waits for the isle's KitAudio, and takes its bus effects
## off again when it leaves.

const KitAudio = preload("res://scripts/kit_isle/kit_audio.gd")
const LinePlan = preload("res://scripts/hall_line_plan.gd")
const Hall = preload("res://scripts/ruin_kit_hall.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

# --- Tuning ----------------------------------------------------------------------

## A bay's closure: the roof's share, each roof's closure, and each wall
## breach's (Hall.BREACHES by index: none, door, low, arch, collapse).
const ROOF_SHARE := 0.6
const ROOF := {"whole":1.0,"broken":0.55,"open":0.08}
const ROOF_GAP := 0.08
const WALL := [1.0,0.82,0.35,0.45,0.08]
## A screen across the nave (the slit) closes a bay more.
const SCREEN := 0.15
## How holed a bay is (the drone): a screen's slit, each breach, the roof.
const PIERCE_SCREEN := 1.0
const PIERCE_BREACH := [0.0,0.3,0.22,0.5,0.15]
const PIERCE_ROOF := {"whole":0.0,"broken":0.35,"open":0.12}
const PIERCE_GAP := 0.12
## Out of a piece's box (m) the room fades to open air over this.
const EDGE_FADE := 6.0
## The time easing (s): enclosure in and out, the piercing.
const EASE_IN := 0.35
const EASE_OUT := 0.55
const EASE_PIERCE := 0.45
## The room on the SFX bus at full enclosure: the reverb's wet and room
## size, the two early reflections (ms, dB), the low-pass (Hz), the gain
## (dB).
const WET := 0.32
const ROOM_SIZE := Vector2(0.45,0.72)
const TAPS := Vector2(17.0,29.0)
const TAP_DB := Vector2(-11.0,-14.0)
const CLOSE_CUT := 4800.0
const OPEN_CUT := 20000.0
const ROOM_DB := 2.0
## The engine in the room: gain and pitch at full enclosure.
const ENGINE_ROOM := Vector2(1.38,0.95)
## The release: how closed it must have been (the held peak), the rise,
## hold and fall (s), the high-pass at full (Hz), the dip (dB), the
## engine's gain at full, the wait before another.
const RELEASE_FROM := 0.5
const RELEASE_BELOW := 0.25
const RELEASE_TIME := Vector3(0.3,0.7,2.6)
const THIN_CUT := 380.0
const QUIET_DB := -8.0
const ENGINE_THIN := 0.5
const RELEASE_GAP := 3.0
## The wind drone: the low pipe's and the twelfth's gain at full piercing,
## the airspeeds (m/s) it starts and is full at, its pitch at the slow end
## and what speed and the swell add.
const DRONE := 0.16
const DRONE_HIGH := 0.09
const DRONE_AIR := Vector2(6.0,18.0)
const DRONE_PITCH := Vector3(0.9,0.12,0.05)
## The column whoosh: within this (m) of a wingtip a column at a bay line
## whooshes as the plane passes its line, by how close; at most this gain.
const COLUMN_REACH := 5.0
const COLUMN_GAIN := 0.2
## The drone's loops: seconds, sample rate, the low pipe's and the
## twelfth's fundamentals (Hz, rounded to whole cycles a loop), and the
## crossfade at the seam (s).
const LOOP := 4.0
const RATE := 22050
const PIPE := 65.5
const TWELFTH := 196.5
const SEAM := 0.6
## Effects added to SFX are named this (found again and taken off).
const TAG := "hall_sound"

## The isle (studies/aqueduct_isle.gd) and its line (scripts/hall_line.gd).
var isle: Node = null
var line = null
var audio = null

# State (public for probes).
## The room now (eased) and what the hall says where the plane is (raw).
var enclosure := 0.0
var enclosure_raw := 0.0
var pierce := 0.0
var pierce_raw := 0.0
## The release envelope (0 to 1) and the held peak of enclosure.
var release := 0.0
var held := 0.0
## Where the plane is: the piece's index (-1 none), the bay (fractional),
## its roof.
var at_piece := -1
var at_bay := -1.0
var at_roof := ""
## Column whooshes played, releases begun.
var whooshes := 0
var releases := 0
## The main-thread cost of a frame (us): last and running mean.
var cost_usec := 0
var cost_mean := 0.0

var _plans := {}
var _release_t := -1.0
var _release_peak := 0.0
var _release_wait := 0.0
var _last_line := {}
var _bake_task := -1
var _baked := {}
var _drone_low = null
var _drone_high = null
var _fx := {}
var _sfx := -1

## The flag.
static func wanted(args: PackedStringArray) -> bool:
	return not args.has("--hall-sound=0")

## Made under `host` for `line_node` (the Sundered line; nothing for the
## old hall chain), unless --hall-sound=0.
static func attach(host: Node, line_node: Node) -> Node:
	if not wanted(LaunchArgs.user_args()) or line_node == null or not ("halls" in line_node and "plane_s" in line_node and "route" in line_node): return null
	var me: Node = load("res://scripts/hall_sound.gd").new()
	me.isle = host
	me.line = line_node
	host.add_child(me)
	return me

func _ready() -> void:
	name = "HallSound"
	var out := _baked
	_bake_task = WorkerThreadPool.add_task(func() -> void:
		out.low = bake(PIPE,[1.0,0.55,0.34,0.14,0.1,0.05],0.32,11)
		out.high = bake(TWELFTH,[1.0,0.32,0.1],0.45,29),false,"Hall sound drone")

func _exit_tree() -> void:
	if _bake_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_bake_task)
		_bake_task = -1
	_take_effects()
	if audio != null and is_instance_valid(audio) and "room_engine" in audio: audio.room_engine = Vector2.ONE
	for bed in [_drone_low,_drone_high]:
		if bed != null and is_instance_valid(bed.player): bed.player.stop()

# --- The bus ---------------------------------------------------------------------------

## The room's effects appended to the SFX bus (after its hush low-pass):
## the thinning high-pass, the closing low-pass, the early reflections, the
## reverb, the gain. Each off while it does nothing.
func _add_effects() -> void:
	_sfx = AudioServer.get_bus_index(KitAudio.SFX)
	if _sfx < 0: return
	_take_effects()
	var hp := AudioEffectHighPassFilter.new()
	hp.cutoff_hz = 20.0
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = OPEN_CUT
	var delay := AudioEffectDelay.new()
	delay.dry = 1.0
	delay.tap1_active = true
	delay.tap1_delay_ms = TAPS.x
	delay.tap1_level_db = -60.0
	delay.tap1_pan = -0.55
	delay.tap2_active = true
	delay.tap2_delay_ms = TAPS.y
	delay.tap2_level_db = -60.0
	delay.tap2_pan = 0.55
	delay.feedback_active = false
	var reverb := AudioEffectReverb.new()
	reverb.room_size = ROOM_SIZE.x
	reverb.damping = 0.45
	reverb.predelay_msec = 22.0
	reverb.predelay_feedback = 0.3
	reverb.spread = 0.85
	reverb.hipass = 0.12
	reverb.dry = 1.0
	reverb.wet = 0.0
	var amp := AudioEffectAmplify.new()
	amp.volume_db = 0.0
	_fx = {"hp":hp,"lp":lp,"delay":delay,"reverb":reverb,"amp":amp}
	for key: String in ["hp","lp","delay","reverb","amp"]:
		var fx: AudioEffect = _fx[key]
		fx.resource_name = TAG
		AudioServer.add_bus_effect(_sfx,fx)
		_enable(fx,false)

func _take_effects() -> void:
	var bus := AudioServer.get_bus_index(KitAudio.SFX)
	if bus < 0: return
	var i := AudioServer.get_bus_effect_count(bus)-1
	while i >= 0:
		if AudioServer.get_bus_effect(bus,i).resource_name == TAG: AudioServer.remove_bus_effect(bus,i)
		i -= 1
	_fx = {}

func _enable(fx: AudioEffect, on: bool) -> void:
	for i in range(AudioServer.get_bus_effect_count(_sfx)):
		if AudioServer.get_bus_effect(_sfx,i) == fx:
			if AudioServer.is_bus_effect_enabled(_sfx,i) != on: AudioServer.set_bus_effect_enabled(_sfx,i,on)
			return

# --- Every frame ------------------------------------------------------------------------

func _process(delta: float) -> void:
	if delta <= 0.0 or isle == null or not is_instance_valid(isle): return
	var began := Time.get_ticks_usec()
	if audio == null:
		var got: Variant = isle.get("audio")
		if got == null: return
		audio = got
		_add_effects()
	# The isle quitting (KitAudio `quit`): nothing restarts a voice.
	if (audio as Node).process_mode == Node.PROCESS_MODE_DISABLED: return
	_take_drone()
	var flying := bool(isle.get("flying")) and isle.get("plane") != null
	var speed := 0.0
	var pos := Vector3.INF
	if flying:
		var plane = isle.get("plane")
		pos = plane.position
		speed = (plane.velocity as Vector3).length()
	_room(pos)
	enclosure = lerpf(enclosure,enclosure_raw,1.0-exp(-delta/(EASE_IN if enclosure_raw > enclosure else EASE_OUT)))
	pierce = lerpf(pierce,pierce_raw,1.0-exp(-delta/EASE_PIERCE))
	_release_step(delta)
	_apply(delta,speed,flying)
	if flying: _columns(pos,speed)
	else: _last_line = {}
	cost_usec = Time.get_ticks_usec()-began
	cost_mean = lerpf(cost_mean,float(cost_usec),0.02)

## The hall where the plane is: enclosure and piercing, raw.
func _room(pos: Vector3) -> void:
	enclosure_raw = 0.0
	pierce_raw = 0.0
	at_piece = -1
	at_bay = -1.0
	at_roof = ""
	if pos == Vector3.INF or line == null or not is_instance_valid(line): return
	var best := 0.0
	for h: Dictionary in line.halls:
		var plans := _plans_of(h)
		if plans.is_empty(): continue
		var local: Vector3 = LinePlan.xform(h.pose).affine_inverse()*pos
		var length := float(h.pose.length)
		var along := -local.z
		# How far out of the piece's box (along, across, up) the plane is.
		var out := maxf(maxf(-along,along-length),0.0)
		out = maxf(out,absf(local.x)-Hall.WALL_Z)
		out = maxf(out,maxf(-local.y-1.0,local.y-Hall.ROOF_TOP))
		var inside := 1.0-smoothstep(0.0,EDGE_FADE,out)
		if inside <= 0.0: continue
		# The bay, blended into the next across its middle.
		var f := clampf(along/Hall.BAY,0.0,plans.size()-0.001)-0.5
		var i0 := floori(f)
		var t := smoothstep(0.0,1.0,f-i0)
		var a: Dictionary = plans[clampi(i0,0,plans.size()-1)]
		var b: Dictionary = plans[clampi(i0+1,0,plans.size()-1)]
		var e := lerpf(closure(a),closure(b),t)*inside
		if e >= best or at_piece < 0:
			best = e
			enclosure_raw = e
			pierce_raw = lerpf(holes(a),holes(b),t)*inside
			at_piece = int(h.index)
			at_bay = clampf(along/Hall.BAY,0.0,plans.size())
			at_roof = str(plans[clampi(int(at_bay),0,plans.size()-1)].roof)

## A piece's bay plans: the real build's (Sundered's own), else drawn as
## the greybox draws them.
func _plans_of(h: Dictionary) -> Array:
	var index := int(h.index)
	if _plans.has(index): return _plans[index]
	var made: Dictionary = h.get("made",{})
	var plans: Array = []
	if made.has("hall"): plans = made.hall.plans
	else: plans = LinePlan.bays(h.pose)[1]
	_plans[index] = plans
	if _plans.size() > 16: _plans.erase(_plans.keys()[0])
	return plans

## How closed a bay is (0 open sky, 1 roofed and walled).
static func closure(p: Dictionary) -> float:
	if int(p.get("torn",0)) != 0: return 0.04
	var roof := float(ROOF.get(str(p.roof),0.5))-ROOF_GAP*(p.get("gaps",[]) as Array).size()
	var b: Vector2i = p.get("breach",Vector2i.ZERO)
	var walls := (float(WALL[clampi(b.x,0,4)])+float(WALL[clampi(b.y,0,4)]))*0.5
	var e := ROOF_SHARE*maxf(roof,0.0)+(1.0-ROOF_SHARE)*walls
	if bool(p.get("screen",false)): e += SCREEN
	return clampf(e,0.0,1.0)

## How holed a bay's shell is (the drone's swell).
static func holes(p: Dictionary) -> float:
	if int(p.get("torn",0)) != 0: return 0.0
	var b: Vector2i = p.get("breach",Vector2i.ZERO)
	var k := float(PIERCE_ROOF.get(str(p.roof),0.0))+float(PIERCE_BREACH[clampi(b.x,0,4)])+float(PIERCE_BREACH[clampi(b.y,0,4)])
	k += PIERCE_GAP*(p.get("gaps",[]) as Array).size()
	if bool(p.get("screen",false)): k += PIERCE_SCREEN
	return clampf(k,0.0,1.0)

## The release: once the room has been closed (the held peak) and falls
## away, an envelope up over RELEASE_TIME.x, held, then let go.
func _release_step(delta: float) -> void:
	held = maxf(held*exp(-delta/5.0),enclosure)
	_release_wait -= delta
	if _release_t < 0.0 and held >= RELEASE_FROM and enclosure < RELEASE_BELOW and _release_wait <= 0.0:
		_release_t = 0.0
		_release_peak = clampf((held-RELEASE_BELOW)/(1.0-RELEASE_BELOW),0.4,1.0)
		held = 0.0
		releases += 1
		_release_wait = RELEASE_GAP
	if _release_t < 0.0:
		release = 0.0
		return
	_release_t += delta
	var r := 0.0
	if _release_t < RELEASE_TIME.x: r = smoothstep(0.0,RELEASE_TIME.x,_release_t)
	elif _release_t < RELEASE_TIME.x+RELEASE_TIME.y: r = 1.0
	else:
		var k := (_release_t-RELEASE_TIME.x-RELEASE_TIME.y)/RELEASE_TIME.z
		r = 1.0-smoothstep(0.0,1.0,k)
		if k >= 1.0: _release_t = -1.0
	# Back in a room, the release gives way to it.
	release = r*_release_peak*(1.0-smoothstep(0.2,0.6,enclosure))

## The bus, the engine, the drone.
func _apply(delta: float, speed: float, flying: bool) -> void:
	var e := enclosure
	var r := release
	if not _fx.is_empty():
		var reverb: AudioEffectReverb = _fx.reverb
		reverb.wet = WET*e
		reverb.room_size = lerpf(ROOM_SIZE.x,ROOM_SIZE.y,e)
		var delay: AudioEffectDelay = _fx.delay
		delay.tap1_level_db = lerpf(-60.0,TAP_DB.x,sqrt(e))
		delay.tap2_level_db = lerpf(-60.0,TAP_DB.y,sqrt(e))
		var lp: AudioEffectLowPassFilter = _fx.lp
		lp.cutoff_hz = OPEN_CUT*pow(CLOSE_CUT/OPEN_CUT,e)
		var hp: AudioEffectHighPassFilter = _fx.hp
		hp.cutoff_hz = 20.0*pow(THIN_CUT/20.0,r)
		var amp: AudioEffectAmplify = _fx.amp
		amp.volume_db = ROOM_DB*e+QUIET_DB*r
		var room := e > 0.004
		_enable(reverb,room)
		_enable(delay,room)
		_enable(lp,room)
		_enable(hp,r > 0.004)
		_enable(amp,room or r > 0.004)
	if "room_engine" in audio:
		audio.room_engine = Vector2(lerpf(1.0,ENGINE_ROOM.x,e)*(1.0-ENGINE_THIN*r),lerpf(1.0,ENGINE_ROOM.y,e)*(1.0+0.03*r))
	var fast := smoothstep(DRONE_AIR.x,DRONE_AIR.y,speed) if flying else 0.0
	var swell := pierce*fast
	for k in range(2):
		var bed = _drone_low if k == 0 else _drone_high
		if bed == null: continue
		bed.goal = DRONE*swell if k == 0 else DRONE_HIGH*smoothstep(0.25,0.9,pierce)*fast
		bed.pitch_goal = DRONE_PITCH.x+DRONE_PITCH.y*fast+DRONE_PITCH.z*pierce
		bed.step(delta)

## A whoosh as the plane crosses a bay line with a column there close to a
## wingtip (the outer rows at every line, the inner ones where a plan has
## them; not on a torn line), at the column, by how close.
func _columns(pos: Vector3, speed: float) -> void:
	if speed < 8.0 or audio == null or line == null: return
	var tip := WorldScale.span*0.5
	var crossed := {}
	for h: Dictionary in line.halls:
		var plans := _plans_of(h)
		if plans.is_empty(): continue
		var xf := LinePlan.xform(h.pose)
		var local: Vector3 = xf.affine_inverse()*pos
		var along := -local.z
		if along < -Hall.BAY or along > float(h.pose.length)+Hall.BAY: continue
		if local.y < 0.0 or local.y > Hall.COLUMN_H or absf(local.x) > Hall.WALL_Z: continue
		var k := roundi(along/Hall.BAY)
		var was: Variant = _last_line.get(int(h.index))
		crossed[int(h.index)] = along
		if was == null or k < 0 or k > plans.size(): continue
		var line_s := k*Hall.BAY
		if not (float(was) < line_s and along >= line_s): continue
		var p: Dictionary = plans[mini(k,plans.size()-1)]
		var torn := int(p.get("torn",0))
		if (k < plans.size() and torn & 1 != 0) or (k == plans.size() and torn & 2 != 0): continue
		var xs: Array = [-Hall.ROW_Z,Hall.ROW_Z]
		if k < plans.size(): xs.append_array(p.get("inner",[]))
		for x: float in xs:
			var clear := absf(local.x-x)-Hall.COLUMN_R-tip
			if clear > COLUMN_REACH: continue
			var close := 1.0-clampf(clear/COLUMN_REACH,0.0,1.0)
			var fast := smoothstep(8.0,24.0,speed)
			var at: Vector3 = xf*Vector3(x,clampf(local.y,1.0,Hall.COLUMN_H),-line_s)
			audio.shot("whoosh",COLUMN_GAIN*close*close*(0.5+0.5*fast),0.85+0.3*fast+0.1*close,at,KitAudio.AIR,true)
			whooshes += 1
	_last_line = crossed

# --- The drone --------------------------------------------------------------------------

## Once baked, the drone's two loops as beds on SFX (in the room's reverb).
func _take_drone() -> void:
	if _drone_low != null or _bake_task < 0 or not WorkerThreadPool.is_task_completed(_bake_task): return
	WorkerThreadPool.wait_for_task_completion(_bake_task)
	_bake_task = -1
	_drone_low = _drone_bed(_baked.low)
	_drone_high = _drone_bed(_baked.high)
	_baked = {}

func _drone_bed(data: PackedByteArray):
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.stereo = true
	stream.mix_rate = RATE
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = data.size()/4
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = KitAudio.SFX
	player.volume_db = -80.0
	add_child(player)
	var bed := KitAudio.Bed.new()
	bed.player = player
	bed.attack = 2.5
	bed.release = 1.6
	return bed

## A seamless stereo loop (16-bit, RATE, LOOP s) of a breathy pipe on
## `base` Hz: its partials (`weights`) each with a slow swell of whole
## cycles a loop and a faint beating twin, breath (noise rung through
## resonators at the first partials and a soft hiss) at `breath`, the seam
## crossfaded. Safe on a worker.
static func bake(base: float, weights: Array, breath: float, seed_value: int) -> PackedByteArray:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var n := int(LOOP*RATE)
	var fade := int(SEAM*RATE)
	var total := n+fade
	var f0 := roundf(base*LOOP)/LOOP
	var dt := 1.0/RATE
	var chans: Array[PackedFloat32Array] = []
	for c in range(2):
		var buf := PackedFloat32Array()
		buf.resize(total)
		# Partials: frequency, weight, swell cycles and phase, twin offset.
		var parts: Array = []
		for k in range(weights.size()):
			parts.append([f0*(k+1),float(weights[k]),float(rng.randi_range(1,3)),rng.randf()*TAU,rng.randf()*TAU,(1.0+rng.randi_range(0,1))/LOOP])
		# Resonators (two-pole) at the first partials, rung by noise.
		var res: Array = []
		for k in range(mini(3,weights.size())):
			var fr := f0*(k+1)
			var q := 9.0
			var w := TAU*fr/RATE
			var rr := exp(-PI*fr/q/RATE)
			res.append([2.0*rr*cos(w),-rr*rr,0.0,0.0,(1.0-rr)*float(weights[k])])
		var hiss := 0.0
		var breath_phase := rng.randf()*TAU
		for i in range(total):
			var t := i*dt
			var s := 0.0
			for p: Array in parts:
				var sw := 0.75+0.25*sin(TAU*float(p[2])*t/LOOP+float(p[3]))
				s += float(p[1])*sw*(sin(TAU*float(p[0])*t+float(p[4]))+0.35*sin(TAU*(float(p[0])+float(p[5]))*t))
			var noise := rng.randf()*2.0-1.0
			var rung := 0.0
			for r: Array in res:
				var y := float(r[0])*float(r[2])+float(r[1])*float(r[3])+noise*float(r[4])
				r[3] = r[2]
				r[2] = y
				rung += y
			hiss = hiss+0.06*(noise-hiss)
			var puff := 0.65+0.35*sin(TAU*2.0*t/LOOP+breath_phase)
			buf[i] = s+breath*puff*(rung*6.0+hiss*1.5)
		chans.append(buf)
	# The seam: the tail past the loop crossfaded over its start.
	var peak := 0.0001
	for buf in chans:
		for i in range(fade):
			var u := float(i)/fade
			buf[i] = buf[i]*u+buf[n+i]*(1.0-u)
		for i in range(n): peak = maxf(peak,absf(buf[i]))
	var out := PackedByteArray()
	out.resize(n*4)
	var g := 0.8/peak
	for i in range(n):
		out.encode_s16(i*4,clampi(int(chans[0][i]*g*32767.0),-32768,32767))
		out.encode_s16(i*4+2,clampi(int(chans[1][i]*g*32767.0),-32768,32767))
	return out
