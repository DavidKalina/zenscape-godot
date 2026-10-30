extends Node3D
## What the burrower pushes up (docs/design/endless-flight/spec-burrower.md,
## 4): glowing orbs, for now. While it leads the plane, every GAP s it
## pushes one up at its head, a beat ahead of the plane (at least BEAT s of
## the plane's flight off, else a little ahead of the head), for the plane to
## steer for. Each rises with weight:
##
##   swell  the ground bulges over SWELL s (a dome of the ground's colour,
##          trembling, the grass pressed out round it);
##   crack  the dome tears: earth thrown out (or water, a ring and spray on
##          the pond), the dome falls to a torn mound;
##   push   the orb comes up out of it fast, stretched by its speed, sheds
##          earth as it goes, overshoots its hang height on a spring and
##          settles (squashing as it turns);
##   hang   it hangs UP m over the ground or water, bobbing, glowing;
##   sink   unhit after HANG s: a little lift, then pulled down, stretching,
##          a puff where it goes under.
##
## Flown into (the plane's middle within the orb's reach plus half a span) it
## bursts into motes and plays a chime; hits close together climb a
## pentatonic scale (NOTES), so a run plays a little tune.

const Land = preload("res://scripts/burrower/burrower_land.gd")
const HALO_SHADER = preload("res://shaders/burrower_halo.gdshader")

## Timing (s): the swell, the most it hangs, the sink; between push-ups
## (random in GAP); the beat the plane gets at least (s of its flight).
const SWELL := 0.5
const HANG := 4.5
const SINK := 0.75
const GAP := Vector2(1.5,2.8)
const BEAT := 1.3
## The most a push-up comes up ahead of the head to make the beat (m).
const AHEAD_MOST := 24.0
## Sizes (m): the orb's radius, its hang over the ground, the dome's radius
## and swell, the glow's size.
const ORB_R := 1.0
const UP := 2.1
const DOME_R := 1.7
const DOME_UP := 0.75
const HALO := 7.5
## The push: up at RISE m/s from under the dome onto a spring (stiffness,
## damping) round the hang height.
const RISE := 14.0
const SPRING := 55.0
const DAMP := 5.5
## At most this many up at once.
const MOST := 6
const MOTES := 360
const ORB := Color(1.0,0.78,0.36)
const GLOW := Color(1.0,0.55,0.12)
const MOTE := Color(1.0,0.9,0.6)
## The chimes: C6 pentatonic up two octaves; a run lapses after RUN_GAP s.
const NOTES := [1046.5,1174.7,1318.5,1568.0,1760.0,2093.0,2349.3,2637.0,3136.0,3520.0]
const RUN_GAP := 5.0

var land: Land
var burrower: Node
var time := 0.0
var orbs: Array = []
var stats := {"pushed": 0, "hits": 0, "sunk": 0, "skipped": 0, "why": {}, "notes": []}
## The next note in the run, and when the last hit was.
var note_i := 0
var _last_hit := -INF
var _wait := 1.0
var _rng := RandomNumberGenerator.new()
var _core_mesh := SphereMesh.new()
var _core_mat := StandardMaterial3D.new()
var _dome_mesh := SphereMesh.new()
var _halo_mm := MultiMesh.new()
var _motes: Array = []
var _mote_mm := MultiMesh.new()
var _chimes := {}
var _players: Array = []
var _player_i := 0

func _init() -> void:
	name = "PushUps"

func setup(the_land: Land, the_burrower: Node) -> void:
	land = the_land
	burrower = the_burrower
	_rng.seed = 77
	_core_mesh.radius = ORB_R
	_core_mesh.height = ORB_R*2.0
	_core_mesh.radial_segments = 20
	_core_mesh.rings = 10
	_core_mat.albedo_color = ORB
	_core_mat.emission_enabled = true
	_core_mat.emission = GLOW
	_core_mat.emission_energy_multiplier = 3.2
	_core_mat.roughness = 0.35
	_core_mesh.material = _core_mat
	_dome_mesh.radius = 1.0
	_dome_mesh.height = 1.0
	_dome_mesh.is_hemisphere = true
	_dome_mesh.radial_segments = 14
	_dome_mesh.rings = 5
	var quad := QuadMesh.new()
	var halo_m := ShaderMaterial.new()
	halo_m.shader = HALO_SHADER
	quad.material = halo_m
	_halo_mm.transform_format = MultiMesh.TRANSFORM_3D
	_halo_mm.use_custom_data = true
	_halo_mm.mesh = quad
	_halo_mm.instance_count = MOST*2
	_halo_mm.visible_instance_count = 0
	var halos := MultiMeshInstance3D.new()
	halos.name = "Halos"
	halos.multimesh = _halo_mm
	halos.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halos.custom_aabb = AABB(Vector3(-400,-50,-400),Vector3(800,200,800))
	add_child(halos)
	var mote := SphereMesh.new()
	mote.radius = 0.5
	mote.height = 1.0
	mote.radial_segments = 6
	mote.rings = 3
	var mote_m := StandardMaterial3D.new()
	mote_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mote_m.vertex_color_use_as_albedo = true
	mote.material = mote_m
	_mote_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mote_mm.use_colors = true
	_mote_mm.mesh = mote
	_mote_mm.instance_count = MOTES
	_mote_mm.visible_instance_count = 0
	var motes := MultiMeshInstance3D.new()
	motes.name = "Motes"
	motes.multimesh = _mote_mm
	motes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	motes.custom_aabb = AABB(Vector3(-400,-50,-400),Vector3(800,200,800))
	add_child(motes)
	for i in 4:
		var p := AudioStreamPlayer.new()
		p.volume_db = -8.0
		add_child(p)
		_players.append(p)

## One tick: push-ups due from the burrower while it leads `plane` (or roams,
## with `plane` null: the watch camera's), the orbs' motion, the plane's hits
## (its middle and half its span, m).
func tick(delta: float, plane: Object, half_span: float) -> void:
	time += delta
	if time-_last_hit > RUN_GAP: note_i = 0
	_due(delta,plane)
	var i := 0
	while i < orbs.size():
		var o: Dictionary = orbs[i]
		if _step(o,delta,plane,half_span):
			_free(o)
			orbs.remove_at(i)
			continue
		i += 1
	_draw_halos()
	_step_motes(delta)

## A push-up at `at` (x, z) now.
func push(at: Vector2) -> Dictionary:
	var ground := land.height(at.x,at.y)
	var wet := ground < Land.WATER_Y-0.15
	var base := maxf(ground,Land.WATER_Y)
	var o := {"at": at, "base": base, "wet": wet, "phase": &"swell", "t": 0.0, "y": base-ORB_R*1.4, "vy": 0.0,
		"hit": false, "spin": _rng.randf()*TAU, "bob": _rng.randf()*TAU, "glow": 0.0, "shed": 0.0}
	var dome := MeshInstance3D.new()
	dome.mesh = _dome_mesh
	var m := StandardMaterial3D.new()
	m.roughness = 1.0
	if wet:
		m.albedo_color = Color(0.32,0.42,0.42)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = 0.75
	else:
		m.albedo_color = land.colour(at.x,at.y,ground,land.normal(at.x,at.y)).lerp(Color("4a3826"),0.15)
	dome.material_override = m
	dome.position = Vector3(at.x,base-0.05,at.y)
	dome.scale = Vector3(DOME_R*0.6,0.01,DOME_R*0.6)
	add_child(dome)
	o.dome = dome
	o.dome_mat = m
	var core := MeshInstance3D.new()
	core.mesh = _core_mesh
	core.visible = false
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)
	o.core = core
	var light := OmniLight3D.new()
	light.light_color = GLOW
	light.omni_range = 7.0
	light.light_energy = 0.0
	light.shadow_enabled = false
	add_child(light)
	o.light = light
	orbs.append(o)
	stats.pushed = int(stats.pushed)+1
	# The grass pressed out round the swelling ground.
	var react: Object = burrower.react
	if react != null and not wet:
		react._add({"at": at, "way": Vector2.ZERO, "strength": 3.0, "swirl": 0.0, "reach": DOME_R*2.2,
			"front": 0.0, "hold": SWELL+0.8, "press": 0.7})
	return o

## Whether a push-up is due, and where: at the head (or a little ahead of it)
## when that gives the plane its beat.
func _due(delta: float, plane: Object) -> void:
	if not burrower.active or burrower.diving() or float(burrower.strength) < 0.8:
		burrower.want_ahead = 0.0
		_wait = maxf(_wait,0.6)
		return
	_wait -= delta
	if _wait > 0.0 or orbs.size() >= MOST: return
	var head: Vector2 = burrower.pos
	var way: Vector2 = burrower.forward()
	var at := head
	if plane != null and burrower.mode == &"lead":
		var p: Vector3 = plane.position
		var v: Vector3 = plane.velocity
		var vp := maxf(Vector2(v.x,v.z).length(),8.0)
		var fw := Vector2(v.x,v.z).normalized()
		var ahead := (head-Vector2(p.x,p.z)).dot(fw)
		var short := BEAT*vp-ahead
		# Due: it surges ahead to give the plane its beat.
		burrower.want_ahead = BEAT*vp+8.0
		if short > AHEAD_MOST: return _skip("beat")
		if short > 0.0: at = head+way*short
	# Not under a crown or into a rock.
	for tree: Node3D in land.trees:
		if at.distance_to(Vector2(tree.position.x,tree.position.z)) < 5.0: return _skip("tree")
	for r: Dictionary in land.rocks+land.ruins:
		if at.distance_to(r.at) < float(r.reach)+2.0: return _skip("rock")
	if at.length() > Land.MEADOW_R-10.0: return _skip("rim")
	push(at)
	burrower.want_ahead = 0.0
	_wait = _rng.randf_range(GAP.x,GAP.y)

func _skip(why: String) -> void:
	stats.skipped = int(stats.skipped)+1
	stats.why[why] = int(stats.why.get(why,0))+1
	_wait = 0.15

## Steps one orb; true when it is done with.
func _step(o: Dictionary, delta: float, plane: Object, half_span: float) -> bool:
	o.t = float(o.t)+delta
	var t: float = o.t
	var at: Vector2 = o.at
	var base: float = o.base
	var dome: MeshInstance3D = o.dome
	var core: MeshInstance3D = o.core
	var light: OmniLight3D = o.light
	var wet: bool = o.wet
	var stretch := 1.0
	match o.phase:
		&"swell":
			# The ground bulges, faster as it goes, trembling.
			var k := t/SWELL
			var h := DOME_UP*k*k*(1.6-0.6*k)
			var shake := 0.06*k*sin(t*70.0)
			dome.scale = Vector3(DOME_R*(0.6+0.4*k)+shake,maxf(h,0.01),DOME_R*(0.6+0.4*k)-shake)
			# Light leaking up through the grass, earth spat up: the beat's
			# warning, read from the chase camera before the dome shows.
			o.glow = 0.55*k
			if k > 0.35:
				o.shed = float(o.shed)+delta*(14.0 if not wet else 30.0)
				while float(o.shed) >= 1.0:
					o.shed = float(o.shed)-1.0
					var p := Vector3(at.x,base+0.4,at.y)
					if wet: burrower.throw_water(p,2,1.5,5.0*k)
					else: burrower.throw_earth(p,1,1.6,6.0*k,DOME_R*0.6)
			if t >= SWELL:
				o.phase = &"push"
				o.t = 0.0
				o.shed = 0.0
				o.y = base-ORB_R*0.6
				o.vy = RISE
				core.visible = true
				var top := Vector3(at.x,base+0.3,at.y)
				if wet:
					burrower.throw_water(top,70,5.0,9.0,1.8)
					burrower.puff(top,4,true)
				else:
					burrower.throw_earth(top,26,5.5,8.0,DOME_R*0.8)
					burrower.puff(top,5)
		&"push", &"hang":
			var hang := base+UP+(0.12*sin(time*2.2+float(o.bob)) if o.phase == &"hang" else 0.0)
			var y: float = o.y
			var vy: float = o.vy
			vy += (SPRING*(hang-y)-DAMP*vy)*delta
			y += vy*delta
			o.y = y
			o.vy = vy
			stretch = clampf(1.0+absf(vy)*0.035,1.0,1.5)
			# Squash as it turns at the top of its overshoot.
			if absf(vy) < 2.5 and y > hang: stretch = 1.0-0.18*(1.0-absf(vy)/2.5)*clampf((y-hang)*3.0,0.0,1.0)
			o.glow = minf(float(o.glow)+delta*3.0,1.0)
			# The dome falls in to a torn mound.
			var fall := clampf(t/0.3,0.0,1.0)
			dome.scale = Vector3(DOME_R*(1.0+0.15*fall),lerpf(DOME_UP,0.22 if not wet else 0.01,fall),DOME_R*(1.0+0.15*fall))
			if wet: dome.visible = fall < 1.0
			if not wet: (o.dome_mat as StandardMaterial3D).albedo_color = (o.dome_mat as StandardMaterial3D).albedo_color.lerp(Color("3d2e20"),delta*3.0)
			# Earth (or water) shed off it on the way up.
			if o.phase == &"push" and t < 0.45:
				o.shed = float(o.shed)+delta*22.0
				while float(o.shed) >= 1.0:
					o.shed = float(o.shed)-1.0
					var p := Vector3(at.x,y-ORB_R*0.5,at.y)
					if wet: burrower.throw_water(p,2,1.2,0.5)
					else: burrower.throw_earth(p,1,1.0,0.3,ORB_R*0.8)
			if o.phase == &"push" and t > 1.2: o.phase = &"hang"
			if t > HANG:
				o.phase = &"sink"
				o.t = 0.0
				o.top = y
		&"sink":
			# A little lift, then pulled down hard.
			var top: float = o.top
			var y: float
			if t < 0.18: y = top+0.3*sin(t/0.18*PI*0.5)
			else:
				var k := (t-0.18)/(SINK-0.18)
				y = top+0.3-(top+0.3-(base-ORB_R*1.5))*k*k
			o.vy = (y-float(o.y))/maxf(delta,0.001)
			o.y = y
			stretch = clampf(1.0+absf(float(o.vy))*0.03,1.0,1.6)
			o.glow = clampf(1.0-t/SINK,0.0,1.0)
			dome.scale.y = maxf(dome.scale.y-delta*0.3,0.01)
			if y < base and not o.has("under"):
				o.under = true
				var p := Vector3(at.x,base+0.1,at.y)
				if wet: burrower.throw_water(p,24,2.5,4.0,0.9)
				else:
					burrower.throw_earth(p,8,2.0,3.0,0.6)
					burrower.puff(p,3)
			if t >= SINK:
				stats.sunk = int(stats.sunk)+1
				return true
	var c := Vector3(at.x,float(o.y),at.y)
	if core.visible:
		var sx := 1.0/sqrt(stretch)
		o.spin = float(o.spin)+delta*1.4
		core.global_transform = Transform3D(Basis(Vector3.UP,float(o.spin)).scaled(Vector3(sx,stretch,sx)),c)
		light.position = c
		light.light_energy = 1.6*float(o.glow)
		# Flown into: motes and a chime.
		if plane != null and o.phase != &"swell" and float(o.y) > base:
			var p: Vector3 = plane.position
			if p.distance_to(c) < ORB_R+half_span:
				_burst(c,plane.velocity)
				return true
	return false

func _free(o: Dictionary) -> void:
	(o.dome as Node).queue_free()
	(o.core as Node).queue_free()
	(o.light as Node).queue_free()

func _draw_halos() -> void:
	var n := 0
	for o: Dictionary in orbs:
		if n >= _halo_mm.instance_count: break
		var g: float = o.glow
		if g <= 0.0: continue
		var pulse := 0.85+0.15*sin(time*5.0+float(o.bob))
		# Swelling, the glow sits at the dome's top, coming through the grass.
		var y := maxf(float(o.y),float(o.base)+0.6) if o.phase == &"swell" else float(o.y)
		var c := Vector3((o.at as Vector2).x,y,(o.at as Vector2).y)
		_halo_mm.set_instance_transform(n,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*HALO*(0.6+0.4*g)),c))
		_halo_mm.set_instance_custom_data(n,Color(GLOW.r,GLOW.g,GLOW.b,g*pulse))
		n += 1
	_halo_mm.visible_instance_count = n

# --- Hits ------------------------------------------------------------------------

func _burst(at: Vector3, carry: Vector3) -> void:
	stats.hits = int(stats.hits)+1
	_last_hit = time
	(stats.notes as Array).append(note_i)
	_play(note_i)
	note_i = mini(note_i+1,NOTES.size()-1)
	for i in 70:
		if _motes.size() >= MOTES: _motes.pop_front()
		var d := Vector3(_rng.randf_range(-1,1),_rng.randf_range(-0.6,1),_rng.randf_range(-1,1)).normalized()
		_motes.append({"p": at+d*ORB_R*0.6, "v": d*_rng.randf_range(4.0,13.0)+carry*_rng.randf_range(0.2,0.55),
			"age": 0.0, "life": _rng.randf_range(0.7,1.7), "size": _rng.randf_range(0.08,0.2)})

func _step_motes(delta: float) -> void:
	var i := 0
	while i < _motes.size():
		var m: Dictionary = _motes[i]
		m.age = float(m.age)+delta
		if float(m.age) >= float(m.life):
			_motes.remove_at(i)
			continue
		var v: Vector3 = m.v
		v *= 1.0-2.4*delta
		v.y += 1.2*delta
		m.v = v
		m.p = (m.p as Vector3)+v*delta
		i += 1
	var n := _motes.size()
	_mote_mm.visible_instance_count = n
	for k in n:
		var m: Dictionary = _motes[k]
		var t := float(m.age)/float(m.life)
		var s := float(m.size)*(1.0-t*t)*(0.85+0.3*sin(float(m.age)*30.0+k))
		_mote_mm.set_instance_transform(k,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*maxf(s,0.001)),m.p))
		_mote_mm.set_instance_color(k,MOTE.lerp(GLOW,t))

# --- Chimes (placeholder tones) --------------------------------------------------

func _play(i: int) -> void:
	var p: AudioStreamPlayer = _players[_player_i]
	_player_i = (_player_i+1) % _players.size()
	i = clampi(i,0,NOTES.size()-1)
	if not _chimes.has(i): _chimes[i] = _chime(NOTES[i])
	p.stream = _chimes[i]
	p.play()

## A struck chime at `hz`: the note, a bell's inharmonic partials, a fast
## strike and a long ring.
static func _chime(hz: float) -> AudioStreamWAV:
	var rate := 44100
	var n := int(rate*1.4)
	var data := PackedByteArray()
	data.resize(n*2)
	for i in n:
		var t := float(i)/rate
		var s := sin(TAU*hz*t)*exp(-t*3.2)
		s += 0.35*sin(TAU*hz*2.76*t)*exp(-t*6.0)
		s += 0.15*sin(TAU*hz*5.4*t)*exp(-t*11.0)
		s *= minf(t/0.003,1.0)*0.45
		data.encode_s16(i*2,int(clampf(s,-1.0,1.0)*32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w
