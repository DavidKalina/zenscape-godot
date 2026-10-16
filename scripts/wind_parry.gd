extends Node3D
## The parry (docs/design/rune-knight/spec-rune-knight.md, "The parry"): the
## updraft's press (Q, pad RB) made at the right moment takes wind thrown at
## the wanderer into him. The updraft (scripts/updraft.gd) asks `try(motor)`
## first on each press; true spends the press here, false leaves it the
## updraft's, as before (so an early press is the plain updraft).
##
## - **The seam:** any node in the "wind_shot" group answering
##   `parry_eta(motor, horizon, slack) -> float` (seconds till it reaches
##   him, -1 never) and `absorb()` can be parried: today the wind shot
##   (scripts/enemies/wind_shot.gd): the rune knight's crescents, his
##   rally returns and the lob. Optional `crescent_points(at, way, n)` and
##   `form` shape the unwind.
## - **The window:** a press counts when a shot will reach him within
##   KNOBS.window s (`slack` m wider than his body). It needs no charge.
## - **Absorb:** the shot is gone quietly, its wind unwinds into streaks
##   drawn spiralling to his chest, a hit-stop and a flash sell the timing,
##   and the updraft's charge gains one segment (capped at full); the wind
##   gauge (scripts/wind_gauge.gd) pulses it in as any filled segment.
## - **The pose:** the figure's guard layer (scripts/pilot_figure.gd
##   `guard`, `guard_draw`): forearms snapped up crossed before his face,
##   then the fists drawn in to his chest as the wind arrives, eased off.
##
## Made by the aqueduct isle with --rune-knight only (studies/
## aqueduct_isle.gd); nowhere else is the updraft's `parry` set.
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const PhysicsGround = preload("res://scripts/pilot_physics_ground.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const Updraft = preload("res://scripts/updraft.gd")
const DragonAirBlast = preload("res://scripts/dragon_air_blast.gd")
const DragonCyclone = preload("res://scripts/dragon_cyclone.gd")

const GROUP := "wind_shot"
const KNOBS := {
	"window": 0.15,         # s to contact a press still parries in
	"slack": 0.25,          # m wider than his body the parry reads contact
	"cue": 0.4,             # s to contact the cue ring shows from (closing on him)
	"lockout": 0.4,         # s an empty press (no charge, no shot in the window) locks it out
	"hitstop": 0.1,         # s (real) of the hit-stop
	"hitstop_scale": 0.04,  # time's pace in it
	"punch_fov": 6.0,       # deg the camera punches in, easing back...
	"punch_time": 0.3,      # ...over this
	"punch_shake": 0.06,    # m of shake in it
	"volume_db": -6.0,
	"absorb": 0.5,          # s the wind takes to spiral in
	"spin": 1.0,            # turns it winds round him coming in
	"guard_in": 0.05,       # s the guard snaps up
	"draw_from": 0.12,      # s, the fists start drawing in...
	"draw_to": 0.42,        # ...and are in
	"guard_out": 0.3,       # s it eases off after the absorb
	"flash": 0.18,          # s the screen flash fades over
	"flash_alpha": 0.3,
}
const WISPS := 14
## Streaks along each wisp's curve, and the share of its way they trail.
const TAIL := 4
const TAIL_SPAN := 0.14
const TINT := Color(0.84,0.94,1.0)
const RUNE := Color(0.55,0.88,1.0)

var isle: Node3D
var motor: PilotMotor
var updraft: Node3D
var parries := 0
var last_eta := -1.0
## s since the last parry (INF: none yet).
var since := INF
var _wisps: Array[Dictionary] = []
var _hitstop := 0.0
var _hitstop_end := 0
## s the parry stays locked out after an empty press (no mashing).
var locked := 0.0
var lockouts := 0
## The cue: s to contact of the nearest shot in cue range (-1 none), and
## how many times one crossed into the window with the cue showing.
var cue_eta := -1.0
var cues := 0
var _cue_was := -1.0
var _cue_pop := 0.0
var _cue_at := Vector3.ZERO
var _punch := 0.0
var _fov_applied := 0.0
var _cam: Camera3D
var _sound: AudioStreamPlayer
var _ring_mesh: ImmediateMesh
var _flash := 0.0
var _streaks: MultiMeshInstance3D
var _lens: MultiMeshInstance3D
var _veil: ColorRect
var _clock := 0.0

func _init() -> void:
	name = "WindParry"

func setup(host: Node3D) -> void:
	isle = host
	motor = host.get("motor")
	updraft = host.get("updraft")
	if updraft != null: updraft.set("parry",self)
	top_level = true

func _ready() -> void:
	var sm := MultiMesh.new()
	sm.transform_format = MultiMesh.TRANSFORM_3D
	sm.use_custom_data = true
	sm.use_colors = true
	sm.mesh = DragonCyclone._streak_mesh()
	sm.instance_count = WISPS*TAIL
	sm.visible_instance_count = 0
	_streaks = MultiMeshInstance3D.new()
	_streaks.name = "ParryWisps"
	_streaks.multimesh = sm
	_streaks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_streaks.extra_cull_margin = 50.0
	add_child(_streaks)
	var lm := MultiMesh.new()
	lm.transform_format = MultiMesh.TRANSFORM_3D
	lm.use_custom_data = true
	lm.use_colors = true
	lm.mesh = DragonAirBlast._lens_mesh()
	lm.instance_count = 1
	lm.visible_instance_count = 0
	_lens = MultiMeshInstance3D.new()
	_lens.name = "ParryLens"
	_lens.multimesh = lm
	_lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lens.extra_cull_margin = 50.0
	add_child(_lens)
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_veil = ColorRect.new()
	_veil.name = "ParryFlash"
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.color = Color(RUNE.r,RUNE.g,RUNE.b,0.0)
	_veil.visible = false
	layer.add_child(_veil)
	global_transform = Transform3D.IDENTITY
	_ring_mesh = ImmediateMesh.new()
	var ring := MeshInstance3D.new()
	ring.name = "ParryCue"
	ring.mesh = _ring_mesh
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/breeze_ribbon.gdshader")
	ring.material_override = mat
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.extra_cull_margin = 50.0
	add_child(ring)
	_sound = AudioStreamPlayer.new()
	_sound.name = "ParrySound"
	_sound.stream = _make_sound()
	_sound.volume_db = float(KNOBS.volume_db)
	add_child(_sound)

## The press, asked before the updraft: true if it parried a shot.
func try(m: PilotMotor) -> bool:
	if m == null or m.recovering() or m.swimming or m.seized(): return false
	var best: Node3D = null
	var best_eta := INF
	for node: Node in get_tree().get_nodes_in_group(GROUP):
		if not node is Node3D or not node.has_method("parry_eta") or not node.has_method("absorb"): continue
		var eta: float = node.call("parry_eta",m,float(KNOBS.window),float(KNOBS.slack))
		if eta >= 0.0 and eta < best_eta:
			best_eta = eta
			best = node
	if best != null and locked <= 0.0:
		_take(best,m,best_eta)
		return true
	# No shot to take (or locked out): an empty press, one the updraft
	# can't spend either, locks the parry out a moment, so mashing fails.
	if updraft != null and not updraft.call("can_spend"):
		locked = float(KNOBS.lockout)
		lockouts += 1
	return false

func _take(shot: Node3D, m: PilotMotor, eta: float) -> void:
	parries += 1
	last_eta = eta
	since = 0.0
	var at := shot.global_position
	var way: Vector3 = shot.get("velocity") if shot.get("velocity") != null else Vector3.FORWARD
	var form = shot.get("form")
	var points: Array = []
	if form == "crescent" and shot.has_method("crescent_points"):
		points = shot.call("crescent_points",at,way,WISPS)
	else:
		var r := 0.35*_tall()
		for i in range(WISPS):
			var a := float(i)/float(WISPS)*TAU
			points.append(at+Vector3(cos(a),sin(a)*0.6,sin(a))*r)
	shot.call("absorb")
	# Its own burst puffs would read as it breaking out there: it is drawn in.
	shot.visible = false
	_wisps.clear()
	var chest := _chest(m)
	for i in range(points.size()):
		var p: Vector3 = points[i]
		var off := p-chest
		var flat := Vector2(off.x,off.z)
		_wisps.append({"r":flat.length(),"a":atan2(off.z,off.x),"y":off.y,"lag":0.08*float(i%4),"seed":float(i)*1.7,"prev":p})
	# A full segment in (or the shot's meta `parry_gain`, a share of the
	# gauge: the rune knight's last wind fills it all), capped at full; the
	# drain's lull starts afresh.
	if updraft != null:
		updraft.charge = minf(float(updraft.charge)+float(shot.get_meta("parry_gain",Updraft.SEG)),1.0)
		updraft.set("_quiet",0.0)
	print("wind parry: took a %s in, %.3f s from contact, charge now %.2f" % [form if form != null else "shot",eta,float(updraft.charge) if updraft != null else -1.0])
	_hitstop = float(KNOBS.hitstop)
	_hitstop_end = Time.get_ticks_usec()+int(float(KNOBS.hitstop)*1e6)
	Engine.time_scale = float(KNOBS.hitstop_scale)
	_flash = float(KNOBS.flash)
	_punch = float(KNOBS.punch_time)
	cue_eta = -1.0
	if _sound != null: _sound.play()

func _tall() -> float:
	return PhysicsGround.HEAD*WorldScale.wanderer

func _chest(m: PilotMotor) -> Vector3:
	return m.feet+Vector3.UP*0.6*_tall()

func _process(delta: float) -> void:
	var real := delta/maxf(Engine.time_scale,0.001)
	# The hit-stop runs on the wall clock (time's pace is down to a crawl
	# in it, and a fixed-fps run doesn't scale its delta).
	if _hitstop > 0.0:
		if Time.get_ticks_usec() >= _hitstop_end:
			_hitstop = 0.0
			Engine.time_scale = 1.0
	locked = maxf(locked-real,0.0)
	if _flash > 0.0:
		_flash = maxf(_flash-real,0.0)
	_veil.visible = _flash > 0.0
	if _veil.visible: _veil.color.a = float(KNOBS.flash_alpha)*pow(_flash/float(KNOBS.flash),1.5)
	_punch = maxf(_punch-real,0.0)
	_cue_pop = maxf(_cue_pop-real,0.0)
	_clock += delta
	if since != INF: since += delta
	_cue()
	_pose()
	_draw()

## The cue: the nearest shot that will reach him within KNOBS.cue s. As
## it crosses into the window the cue pops (a flash where it is).
func _cue() -> void:
	cue_eta = -1.0
	if motor == null or _hitstop > 0.0 or motor.recovering(): 
		_cue_was = -1.0
		return
	var best := INF
	var at := Vector3.ZERO
	for node: Node in get_tree().get_nodes_in_group(GROUP):
		if not node is Node3D or not node.has_method("parry_eta"): continue
		var eta: float = node.call("parry_eta",motor,float(KNOBS.cue),float(KNOBS.slack))
		if eta >= 0.0 and eta < best:
			best = eta
			at = (node as Node3D).global_position
	if best == INF:
		_cue_was = -1.0
		return
	cue_eta = best
	var w := float(KNOBS.window)
	if best <= w and (_cue_was < 0.0 or _cue_was > w):
		cues += 1
		_cue_pop = 0.12
		_cue_at = at
	_cue_was = best

## The camera punch after a parry (called from the updraft's apply_feel,
## after the host set the camera): a quick FOV punch in and a small shake,
## eased out over KNOBS.punch_time.
func apply_feel(camera: Camera3D) -> void:
	if camera == null: return
	if _cam == camera and _fov_applied != 0.0: camera.fov -= _fov_applied
	_cam = camera
	_fov_applied = 0.0
	if _punch <= 0.0: return
	var u := _punch/float(KNOBS.punch_time)
	var k := u*u
	_fov_applied = -float(KNOBS.punch_fov)*k
	camera.fov += _fov_applied
	var shake := float(KNOBS.punch_shake)*k
	camera.global_position += Vector3(sin(_clock*97.0),sin(_clock*83.0+1.3),sin(_clock*71.0+2.1))*shake

## The figure's guard layer from the time since the parry.
func _pose() -> void:
	var body = isle.get("body") if isle != null else null
	if body == null or body.get("guard") == null: return
	var g := 0.0
	var d := 0.0
	if since != INF:
		var end := float(KNOBS.absorb)
		if since < end: g = clampf(since/float(KNOBS.guard_in),0.0,1.0)
		else: g = clampf(1.0-(since-end)/float(KNOBS.guard_out),0.0,1.0)
		d = clampf((since-float(KNOBS.draw_from))/(float(KNOBS.draw_to)-float(KNOBS.draw_from)),0.0,1.0)
	body.set("guard",g)
	body.set("guard_draw",d)

## The wind spiralling in: each wisp winds round his chest, falling in
## slow then fast, a streak along its way; a lens flash at his chest as it
## all arrives.
func _draw() -> void:
	var sm := _streaks.multimesh
	var lm := _lens.multimesh
	if motor == null:
		sm.visible_instance_count = 0
		lm.visible_instance_count = 0
		return
	var cam := get_viewport().get_camera_3d()
	var chest := _chest(motor)
	var eye := cam.global_position if cam != null else chest+Vector3(0,0,10)
	var t := _tall()
	var si := 0
	var absorbing := since != INF and since <= float(KNOBS.absorb)+0.2
	var strokes: Array[Dictionary] = []
	if absorbing:
		for w: Dictionary in _wisps:
			var u := clampf((since-float(w.lag))/(float(KNOBS.absorb)-float(w.lag)),0.0,1.0)
			if u >= 1.0: continue
			# A short curved tail: TAIL streaks back along its way, thinning.
			for j in range(TAIL):
				var u0 := maxf(u-TAIL_SPAN*float(j)/float(TAIL),0.0)
				var u1 := maxf(u-TAIL_SPAN*float(j+1)/float(TAIL),0.0)
				var p := _wisp_at(w,chest,u0)
				var q := _wisp_at(w,chest,u1)
				if p.distance_to(q) < 0.01: continue
				var fade := 1.0-float(j)/float(TAIL)
				var width := t*0.05*lerpf(1.6,0.6,u)*lerpf(0.4,1.0,fade)
				sm.set_instance_transform(si,_streak((p+q)*0.5,(p-q)*1.15,width,eye))
				sm.set_instance_custom_data(si,Color(lerpf(1.0,0.55,u)*fade,0,0,0))
				sm.set_instance_color(si,TINT if int(w.seed) % 2 == 0 else RUNE)
				si += 1
	# The cue ring round his chest, facing the eye, closing as the shot
	# nears: wide and faint at KNOBS.cue s out, tight and rune-bright in the
	# window. Grey and faint while locked out.
	if cue_eta >= 0.0 and not absorbing:
		var k := clampf(cue_eta/float(KNOBS.cue),0.0,1.0)
		var inside := cue_eta <= float(KNOBS.window)
		var r := t*lerpf(0.42,1.1,k)
		var to_eye := (eye-chest).normalized()
		var right := to_eye.cross(Vector3.UP).normalized()
		if right.length() < 0.1: right = Vector3.RIGHT
		var up := right.cross(to_eye).normalized()
		var alpha := lerpf(0.95,0.4,k)*(0.35 if locked > 0.0 else 1.0)
		var spin := _clock*4.0
		# Three brushed arcs (the updraft ring's brush), spun round.
		for arc in range(3):
			var path := PackedVector3Array()
			for i in range(17):
				var ang := spin+float(arc)*TAU/3.0+float(i)/16.0*TAU/3.0*0.8
				path.append(chest+(right*cos(ang)+up*sin(ang))*r)
			strokes.append({"path":path,"width":t*(0.16 if inside else 0.1),"alpha":alpha,"seed":float(arc)*5.0})
	sm.visible_instance_count = si
	_ring_mesh.clear_surfaces()
	if not strokes.is_empty(): Updraft.draw_strokes(_ring_mesh,strokes,0.05)
	# The lens: a bright pop at the parry, again as the wind lands; a small
	# one at the shot as it crosses into the window (the cue's flash).
	var pop := 0.0
	var pop_at := chest
	var pop_size := 0.55
	if absorbing:
		pop = maxf(1.0-since/0.12,0.0)+maxf(1.0-absf(since-float(KNOBS.absorb)*0.9)/0.1,0.0)*0.7
	elif _cue_pop > 0.0:
		pop = _cue_pop/0.12*0.8
		pop_at = _cue_at
		pop_size = 0.4
	lm.visible_instance_count = 1 if pop > 0.01 else 0
	if pop > 0.01:
		lm.set_instance_transform(0,Transform3D(Basis.from_scale(Vector3.ONE*t*pop_size*(0.6+pop)),pop_at))
		lm.set_instance_custom_data(0,Color(minf(pop,1.0),1.0,0,0))
		lm.set_instance_color(0,TINT)

## A wisp's place at `u` (0 where the shot was, 1 at his chest): its
## distance eased in, slow then fast, wound `spin` turns round him.
func _wisp_at(w: Dictionary, chest: Vector3, u: float) -> Vector3:
	var k := u*u*(3.0-2.0*u)
	var r: float = float(w.r)*(1.0-k)
	var a: float = float(w.a)+float(KNOBS.spin)*TAU*k
	var y: float = float(w.y)*(1.0-k)+sin(u*PI)*0.15*_tall()
	return chest+Vector3(cos(a)*r,y,sin(a)*r)

static func _streak(mid: Vector3, along: Vector3, width: float, eye: Vector3) -> Transform3D:
	var way := along.normalized()
	var across := way.cross((eye-mid).normalized())
	if across.length() < 0.01: across = Vector3.UP.cross(way)
	if across.length() < 0.01: across = Vector3.RIGHT
	across = across.normalized()
	return Transform3D(Basis(along,across*width,way.cross(across).normalized()),mid)

func _exit_tree() -> void:
	if _hitstop > 0.0: Engine.time_scale = 1.0

## The parry's sound, made once: the catch (a soft low thump with a
## bright ring on top), then a breath of air drawn in (noise swelling, its
## filter opening) as the wind spirals into him.
static func _make_sound() -> AudioStreamWAV:
	var rate := 22050
	var length := 0.6
	var n := int(rate*length)
	var data := PackedByteArray()
	data.resize(n*2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var lp := 0.0
	var land := 0.45
	for i in range(n):
		var t := float(i)/float(rate)
		var v := sin(TAU*lerpf(150.0,70.0,minf(t/0.1,1.0))*t)*exp(-t*22.0)*0.8
		v += sin(TAU*1320.0*t)*exp(-t*12.0)*0.18+sin(TAU*1980.0*t)*exp(-t*16.0)*0.1
		var cut := lerpf(0.04,0.45,clampf(t/land,0.0,1.0))
		lp += (rng.randf_range(-1.0,1.0)-lp)*cut
		v += lp*smoothstep(0.02,land,t)*(1.0-smoothstep(land,land+0.1,t))*0.9
		var x := int(clampf(v,-1.0,1.0)*32000.0)
		data.encode_s16(i*2,x)
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w
