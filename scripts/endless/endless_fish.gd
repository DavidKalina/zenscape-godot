extends Node3D
## Fish leaping in the endless land's ponds (scripts/endless/land_ponds.gd;
## docs/design/endless-flight/ponds-handoff.md). Pass low over a pond, or
## stand at its edge, and now and then a fish leaps: the water boils where
## it is about to break, it bursts out tail beating, arcs with its body
## bent, flicks and goes back in with a splash, a crown of drops, a puff of
## spray and rings spreading out, and a plop when you are near.
##
## Nothing here touches the land: the ponds come from the field
## (`LandField.ponds_in`), the fish are life_models.gd's, bent by
## shaders/endless_fish.gdshader, the splashes two MultiMeshes of quads
## (shaders/endless_splash.gdshader) simulated here.
##
## The fish the plane itself flings up, and those in the lakes, are
## scripts/endless/wake_fish.gd's.
##
## --fish=0 none (and none without ponds, --ponds=0).

const Models = preload("res://scripts/life_models.gd")
const WakeFish = preload("res://scripts/endless/wake_fish.gd")

## Fish at once in the air, sprays and rings at most.
const MAX_LEAPS := 4
const MAX_SPRAY := 320
const MAX_RINGS := 48
## Kinds and how often each leaps: [kind, weight, length (m) drawn].
const KINDS := [["carp",1.0,Vector2(0.62,0.9)],["rudd",0.7,Vector2(0.42,0.55)],["tench",0.45,Vector2(0.55,0.75)],["perch",0.55,Vector2(0.45,0.6)]]
## The water boils this long (s) before the fish breaks it.
const BOIL := 0.42
## Peak over the water (m) and run along it (m), for a fish of 0.6 m.
const PEAK := Vector2(0.65,1.25)
const RUN := Vector2(1.1,2.3)
const GRAVITY := 9.8
## Watched: the eye in the air within REACH_AIR m past a pond's edge and
## under ABOVE_AIR m over it, or on foot within REACH_FOOT m of its edge.
const REACH_AIR := 240.0
const ABOVE_AIR := 90.0
const REACH_FOOT := 45.0
## Seconds to the first leap once watched, then between leaps (in the air,
## on foot); a pond seen from further (SEEN m) leaps now and then too.
const FIRST := Vector2(0.15,0.6)
const AGAIN_AIR := Vector2(0.9,2.2)
const AGAIN_FOOT := Vector2(1.8,4.5)
const SEEN := 700.0
const AGAIN_SEEN := Vector2(3.0,7.0)
## The plop: heard within HEAR m.
const HEAR := 140.0

var _field: RefCounted
var _rng := RandomNumberGenerator.new()
var _clock := 0.0
var _look_again := 0.0
var _ponds := {}            # Vector2 centre -> {p, next, watched}
var _leaps: Array = []      # {at, dir, t, boil, air, v0, vh, mesh, len, scale, side, flop, roll, phase, out, in}
var _fish: Array = []       # MeshInstance3D pool
var _meshes: Array = []     # [kind, mesh, length]
# The spray: drops and puffs (position, velocity, age, life, size, a puff
# or a drop, the water's level under it).
var _s_pos := PackedVector3Array()
var _s_vel := PackedVector3Array()
var _s_age := PackedFloat32Array()
var _s_life := PackedFloat32Array()
var _s_size := PackedFloat32Array()
var _s_mist := PackedByteArray()
var _s_floor := PackedFloat32Array()
# The rings (`_ring`).
var _r_pos := PackedVector3Array()
var _r_age := PackedFloat32Array()
var _r_life := PackedFloat32Array()
var _r_reach := PackedFloat32Array()
var _r_band := PackedFloat32Array()
var _r_strength := PackedFloat32Array()
var _spray_mm: MultiMesh
var _ring_mm: MultiMesh
var _ring_trough := PackedFloat32Array()
var _plops: Array = []
var _plop_streams: Array = []
## The fish that answer the plane (scripts/endless/wake_fish.gd), or null.
var wake: Node3D
## For the numbers: leaps begun, ponds known, ms this frame and its mean.
var leaps_total := 0
var ms := 0.0
var ms_avg := 0.0

## --fish=0 none.
static func wanted() -> bool:
	return bool(preload("res://scripts/endless/world/world_profile.gd").current().layer("fish",true)) and not ("--fish=0" in preload("res://scripts/launch_args.gd").user_args())

func setup(land_seed: int, field: RefCounted) -> void:
	_field = field
	_rng.seed = hash([land_seed,"fish"])
	var shader: Shader = load("res://shaders/endless_fish.gdshader")
	for k: Array in KINDS:
		var spec: Dictionary = Models.FISH_KINDS[k[0]]
		var length := float(spec.length)
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("fish_length",length)
		mat.set_shader_parameter("nose_z",length*0.42)
		_meshes.append([k[0],Models.fish(mat,k[0],0),length])
	for i in MAX_LEAPS:
		var f := MeshInstance3D.new()
		f.name = "Fish%d" % i
		f.visible = false
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(f)
		_fish.append(f)
	_spray_mm = _multimesh("Spray",MAX_SPRAY,false)
	_ring_mm = _multimesh("Rings",MAX_RINGS,true)
	for path: String in ["res://assets/audio/fish-plop-1.wav","res://assets/audio/fish-plop-2.wav"]:
		var s: AudioStream = load(path)
		if s != null: _plop_streams.append(s)
	for i in 3:
		var a := AudioStreamPlayer3D.new()
		a.unit_size = 10.0
		a.max_distance = HEAR
		a.volume_db = -4.0
		a.panning_strength = 0.6
		add_child(a)
		_plops.append(a)
	if WakeFish.wanted():
		wake = WakeFish.new()
		wake.name = "Wake"
		add_child(wake)
		wake.setup(land_seed,field)

func _multimesh(n: String, count: int, ring: bool) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0,2.0)
	if ring: quad.orientation = PlaneMesh.FACE_Y
	mm.mesh = quad
	mm.instance_count = count
	mm.visible_instance_count = 0
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/endless_splash.gdshader")
	mat.set_shader_parameter("ring",ring)
	var node := MultiMeshInstance3D.new()
	node.name = n
	node.multimesh = mm
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# The splash moves round the world: never culled by a stale box.
	node.custom_aabb = AABB(Vector3(-1e5,-1e3,-1e5),Vector3(2e5,2e3,2e5))
	add_child(node)
	return mm

## One frame. `eye` the camera, `at` the plane or his feet and `vel` its
## velocity, `walking` whether he is on foot.
func step(delta: float, eye: Vector3, at: Vector3, vel: Vector3, walking: bool) -> void:
	var began := Time.get_ticks_usec()
	_clock += delta
	_look_again -= delta
	if _look_again <= 0.0:
		_look_again = 0.5
		_find_ponds(eye)
	_trigger(at,vel,walking)
	_step_leaps(delta,eye)
	_step_spray(delta)
	_step_rings(delta)
	ms = (Time.get_ticks_usec()-began)/1000.0
	ms_avg = lerpf(ms_avg,ms,0.05)

## The ponds round the eye (their timers kept).
func _find_ponds(eye: Vector3) -> void:
	var r := SEEN+60.0
	var got: Array = _field.ponds_in(eye.x-r,eye.z-r,eye.x+r,eye.z+r)
	var keep := {}
	for p: PackedFloat32Array in got:
		var key := Vector2(p[0],p[1])
		keep[key] = _ponds[key] if _ponds.has(key) else {"p":p,"next":_clock+_rng.randf_range(AGAIN_SEEN.x,AGAIN_SEEN.y),"watched":false}
	_ponds = keep

func _trigger(at: Vector3, vel: Vector3, walking: bool) -> void:
	for key: Vector2 in _ponds:
		var d: Dictionary = _ponds[key]
		var p: PackedFloat32Array = d.p
		var to := key-Vector2(at.x,at.z)
		var dist := to.length()
		var past := dist-p[11]
		var watched := false
		if walking: watched = past < REACH_FOOT
		else:
			var coming := Vector2(vel.x,vel.z).dot(to) > 0.0 or past < 30.0
			watched = past < REACH_AIR and at.y-p[3] < ABOVE_AIR and coming
		if watched and not d.watched: d.next = minf(d.next,_clock+_rng.randf_range(FIRST.x,FIRST.y))
		d.watched = watched
		if _clock < d.next: continue
		if not watched and dist > SEEN:
			d.next = _clock+_rng.randf_range(AGAIN_SEEN.x,AGAIN_SEEN.y)
			continue
		if _leaps.size() >= MAX_LEAPS:
			d.next = _clock+0.3
			continue
		var again := AGAIN_FOOT if walking else AGAIN_AIR
		if not watched: again = AGAIN_SEEN
		d.next = _clock+_rng.randf_range(again.x,again.y)
		# Side on to the one watching, more often than not, so the arc reads.
		var across := Vector2(-to.y,to.x).normalized() if dist > 0.5 else Vector2.RIGHT
		if not walking and Vector2(vel.x,vel.z).length() > 2.0: across = Vector2(-vel.z,vel.x).normalized()
		var dir := across.rotated(_rng.randf_range(-0.7,0.7)) if _rng.randf() < 0.7 else Vector2.RIGHT.rotated(_rng.randf()*TAU)
		if _rng.randf() < 0.5: dir = -dir
		leap(p,dir)

## A fish leaps from pond `p` along `dir` (from `spot`, else a spot well in
## from its edge).
func leap(p: PackedFloat32Array, dir: Vector2, spot := Vector2.INF) -> void:
	var free: MeshInstance3D = null
	for f: MeshInstance3D in _fish:
		if not f.visible and not _busy(f): free = f
	if free == null: return
	var a := _rng.randf()*TAU
	var r := sqrt(_rng.randf())*0.45*p[2]
	var start := Vector2(p[0],p[1])+Vector2(cos(a),sin(a))*r-dir*0.5*RUN.y
	if spot != Vector2.INF: start = spot
	var k := _pick_kind()
	var spec: Array = KINDS[k]
	var span: Vector2 = spec[2]
	var long := _rng.randf_range(span.x,span.y)
	var size := long/0.6
	var peak := _rng.randf_range(PEAK.x,PEAK.y)*lerpf(0.8,1.15,clampf(size-0.7,0.0,1.0))
	var run := _rng.randf_range(RUN.x,RUN.y)*size
	# Breaking the water: the centre starts a little under it, and comes
	# back down as far under.
	var sink := long*0.3
	var v0 := sqrt(2.0*GRAVITY*(peak+sink))
	var air := 2.0*v0/GRAVITY
	var m: Array = _meshes[k]
	free.mesh = m[1]
	_leaps.append({"fish":free,"k":long/float(m[2]),"mesh_len":float(m[2]),"level":p[3],"at":Vector3(start.x,p[3]-sink,start.y),"dir":dir,"t":-BOIL,"air":air,"v0":v0,"vh":run/air,
		"len":long,"side":1.0 if _rng.randf() < 0.5 else -1.0,"flop":_rng.randf() < 0.35,"roll":_rng.randf_range(-0.3,0.3),
		"phase":_rng.randf()*TAU,"out":false,"in":false})
	leaps_total += 1
	# The boil: the water bulging and turning where it will break.
	_ring(Vector3(start.x,p[3]+0.02,start.y),0.9*size,BOIL+0.25,0.55,0.6,0.5)

func _busy(f: MeshInstance3D) -> bool:
	for l: Dictionary in _leaps:
		if l.fish == f: return true
	return false

func _pick_kind() -> int:
	var total := 0.0
	for k: Array in KINDS: total += float(k[1])
	var roll := _rng.randf()*total
	for i in KINDS.size():
		roll -= float(KINDS[i][1])
		if roll <= 0.0: return i
	return 0

func _step_leaps(delta: float, eye: Vector3) -> void:
	var done: Array = []
	for l: Dictionary in _leaps:
		l.t = float(l.t)+delta
		var t := float(l.t)
		var f: MeshInstance3D = l.fish
		var level := float(l.level)
		var start: Vector3 = l.at
		var dir: Vector2 = l.dir
		var air := float(l.air)
		var long := float(l.len)
		if t < 0.0:
			# Under, gathering in the boil.
			f.visible = false
			continue
		var tau := t
		var vh := float(l.vh)
		var v0 := float(l.v0)
		var pos := Vector3(start.x+dir.x*vh*tau,start.y+v0*tau-0.5*GRAVITY*tau*tau,start.z+dir.y*vh*tau)
		var vel := Vector3(dir.x*vh,v0-GRAVITY*tau,dir.y*vh)
		if not l.out and pos.y > level-long*0.1:
			l.out = true
			_splash(Vector3(pos.x,level,pos.z),Vector3(dir.x,0,dir.y)*vh,0.55*long/0.6,false)
		if not l.in and l.out and vel.y < 0.0 and pos.y < level:
			l.in = true
			_splash(Vector3(pos.x,level,pos.z),Vector3(dir.x,0,dir.y)*vh,long/0.6*(1.3 if l.flop else 1.0),true)
			_plop(Vector3(pos.x,level,pos.z),eye)
		if l.in and pos.y < level-long*0.9:
			f.visible = false
			done.append(l)
			continue
		f.visible = true
		var u := clampf(tau/air,0.0,1.0)
		# Nose along the flight; the roll grows into a flop on its side.
		var fwd := vel.normalized()
		var b := Basis.looking_at(fwd,Vector3.UP,true)
		var roll := float(l.roll)*sin(u*PI)
		if l.flop: roll += float(l.side)*1.45*smoothstep(0.35,0.95,u)
		b = Basis(fwd,roll)*b
		# Stretched bursting out, squashed a touch going in.
		var sz := 1.0+0.14*(1.0-smoothstep(0.0,0.3,u))-0.06*smoothstep(0.85,1.0,u)
		var sxy := 1.0/sqrt(sz)
		f.global_transform = Transform3D(b*Basis.from_scale(Vector3(sxy,sxy,sz)*float(l.k)),pos)
		# The body: a hard tail beat as it breaks out, an arch held over the
		# top, a last flick going in.
		var beat := 0.2*(1.0-smoothstep(0.0,0.4,u))+0.13*smoothstep(0.7,0.92,u)*(1.0-smoothstep(0.98,1.2,u))
		l.phase = float(l.phase)+delta*TAU*lerpf(9.0,6.0,u)
		var arch := float(l.side)*1.6*pow(sin(clampf(u,0.0,1.0)*PI),1.5)
		# (The beat in the mesh's own metres.)
		f.set_instance_shader_parameter("leap",Vector4(arch,beat*float(l.mesh_len),float(l.phase),1.0-0.4*u))
	for l in done: _leaps.erase(l)

## Drops, spray and rings where a fish breaks the water (`entering`: the
## bigger crown going back in), `drift` its run along the water, `size`
## about 1 for a 0.6 m fish.
func _splash(at: Vector3, drift: Vector3, size: float, entering: bool) -> void:
	var drops := int((22 if entering else 9)*clampf(size,0.6,1.6))
	for i in drops:
		var a := _rng.randf()*TAU
		var out := _rng.randf_range(0.9,2.6)*(1.0 if entering else 0.7)*sqrt(size)
		var up := _rng.randf_range(1.6,3.6)*(1.0 if entering else 0.75)*sqrt(size)
		var v := Vector3(cos(a)*out,up,sin(a)*out)+drift*0.25
		_spray_add(at+Vector3(cos(a),0,sin(a))*0.12*size,v,_rng.randf_range(0.5,1.0),_rng.randf_range(0.03,0.06)*sqrt(size),false,at.y)
	var puffs := 3 if entering else 1
	for i in puffs:
		var a := _rng.randf()*TAU
		var v := Vector3(cos(a)*0.4,_rng.randf_range(0.6,1.4),sin(a)*0.4)
		_spray_add(at+Vector3(0,0.15,0),v,_rng.randf_range(0.55,0.9),_rng.randf_range(0.28,0.45)*size,true,at.y)
	if entering:
		# A burst of foam where it went in, then rings running out.
		_ring(at+Vector3(0,0.03,0),0.7*size,0.7,0.95,1.0,0.0)
		for i in 3:
			_ring(at+Vector3(0,0.025,0),(3.4+i*1.1)*size,2.2+i*0.35,0.16,0.75-i*0.15,0.8,i*0.28)
	else:
		_ring(at+Vector3(0,0.025,0),2.0*size,1.5,0.18,0.5,0.7)

func _spray_add(p: Vector3, v: Vector3, life: float, size: float, mist: bool, floor_y: float) -> void:
	if _s_pos.size() >= MAX_SPRAY: return
	_s_pos.append(p)
	_s_vel.append(v)
	_s_age.append(0.0)
	_s_life.append(life)
	_s_size.append(size)
	_s_mist.append(1 if mist else 0)
	_s_floor.append(floor_y)

## A ring at `at` running out to `reach` m over `life` s; `band` its width
## as a share of the radius, `strength` its opacity, `trough` the dark
## inside it, `delay` s before it starts (its age starts negative).
func _ring(at: Vector3, reach: float, life: float, band: float, strength: float, trough: float, delay := 0.0) -> void:
	if _r_pos.size() >= MAX_RINGS: return
	_r_pos.append(at)
	_r_age.append(-delay)
	_r_life.append(life)
	_r_reach.append(reach)
	_r_band.append(band)
	_r_strength.append(strength)
	_ring_trough.append(trough)

func _step_spray(delta: float) -> void:
	var i := 0
	while i < _s_pos.size():
		_s_age[i] += delta
		var gone := _s_age[i] >= _s_life[i]
		if _s_mist[i] == 1:
			_s_vel[i] *= exp(-2.5*delta)
		else:
			_s_vel[i] += Vector3(0,-GRAVITY,0)*delta
			if _s_pos[i].y < _s_floor[i]-0.05 and _s_vel[i].y < 0.0: gone = true
		_s_pos[i] += _s_vel[i]*delta
		if gone:
			var last := _s_pos.size()-1
			_s_pos[i] = _s_pos[last]; _s_vel[i] = _s_vel[last]; _s_age[i] = _s_age[last]; _s_life[i] = _s_life[last]
			_s_size[i] = _s_size[last]; _s_mist[i] = _s_mist[last]; _s_floor[i] = _s_floor[last]
			_s_pos.resize(last); _s_vel.resize(last); _s_age.resize(last); _s_life.resize(last)
			_s_size.resize(last); _s_mist.resize(last); _s_floor.resize(last)
			continue
		var k := _s_age[i]/_s_life[i]
		var s := _s_size[i]
		var alpha := 0.0
		var soft := 0.0
		if _s_mist[i] == 1:
			s *= lerpf(0.6,1.8,sqrt(k))
			alpha = 0.32*(1.0-k)*(1.0-k)*smoothstep(0.0,0.1,k)
			soft = 0.9
		else:
			alpha = 0.95*(1.0-smoothstep(0.6,1.0,k))
			soft = 0.45
		_spray_mm.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ONE*s),_s_pos[i]))
		_spray_mm.set_instance_custom_data(i,Color(alpha,soft,0.0,0.0))
		i += 1
	_spray_mm.visible_instance_count = _s_pos.size()

func _step_rings(delta: float) -> void:
	var i := 0
	while i < _r_pos.size():
		_r_age[i] += delta
		if _r_age[i] >= _r_life[i]:
			var last := _r_pos.size()-1
			_r_pos[i] = _r_pos[last]; _r_age[i] = _r_age[last]; _r_life[i] = _r_life[last]; _r_reach[i] = _r_reach[last]
			_r_band[i] = _r_band[last]; _r_strength[i] = _r_strength[last]; _ring_trough[i] = _ring_trough[last]
			_r_pos.resize(last); _r_age.resize(last); _r_life.resize(last); _r_reach.resize(last)
			_r_band.resize(last); _r_strength.resize(last); _ring_trough.resize(last)
			continue
		i += 1
	# Drawn: those started (a delayed one waits with its age under 0).
	var shown := 0
	for j in _r_pos.size():
		if _r_age[j] < 0.0: continue
		var k := _r_age[j]/_r_life[j]
		# Out fast, then slowing; fading as it widens.
		var r := maxf(_r_reach[j]*(1.0-pow(1.0-k,2.2)),0.05)
		var a := _r_strength[j]*(1.0-k)*smoothstep(0.0,0.06,k)
		_ring_mm.set_instance_transform(shown,Transform3D(Basis.from_scale(Vector3(r,1.0,r)),_r_pos[j]))
		_ring_mm.set_instance_custom_data(shown,Color(a,_r_band[j]*lerpf(1.0,0.6,k),_ring_trough[j],float(j%7)/7.0))
		shown += 1
	_ring_mm.visible_instance_count = shown

func _plop(at: Vector3, eye: Vector3) -> void:
	if _plop_streams.is_empty() or at.distance_to(eye) > HEAR: return
	for a: AudioStreamPlayer3D in _plops:
		if a.playing: continue
		a.stream = _plop_streams[_rng.randi()%_plop_streams.size()]
		a.global_position = at
		a.pitch_scale = _rng.randf_range(0.85,1.08)
		a.play()
		return

## The numbers' line (--numbers).
func note() -> String:
	var air := 0
	for l: Dictionary in _leaps:
		if float(l.t) >= 0.0: air += 1
	return "\nfish: %d ponds, leaping %d, leaps %d, spray %d, rings %d  %.2f ms (%.2f)" % [_ponds.size(),air,leaps_total,_s_pos.size(),_r_pos.size(),ms,ms_avg]+(wake.note() if wake != null else "")
