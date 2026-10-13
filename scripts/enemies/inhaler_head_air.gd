extends Node3D
## The inhaler head's air, made visible (scripts/enemies/inhaler_head.gd):
## everything here is drawn, nothing pushes.
##   streaks   thin wind streaks (the wind tool's ribbons, shaders/
##             gust_trail.gdshader) curving in from the cone to the mouth,
##             their strokes running inward
##   motes     dust and leaves lifted off the ground in the cone and drawn
##             along into the mouth, quicker as they near it
##   puffs     soft dust: off the turf in the cone as it draws, off its
##             flanks as it grinds round, out of the ear flaps as it holds
##             what it swallowed, and the blast out of its mouth
##   grass     the shared air the meadow and the trees bend in (the
##             LocalWindField's shader slots, zs_local_gust_*, shaders/
##             reference_wind.gdshaderinc `zs_local_wind`): a chain of
##             gusts along the cone's floor, each blowing toward the mouth;
##             the blast is a lane of the wind tool's air (zs_blow_0_*,
##             `zs_blow_at`), a front running out along its line.
## `draw(share)` each frame sets how hard it draws (0 none, 1 full);
## `grind`, `swallowing`, `blast` are one-shots. `look` false builds none.

const TRAIL = preload("res://shaders/gust_trail.gdshader")
const STREAKS := 22
const SEGMENTS := 22
const MOTES := 34
const PUFFS := 40
## The grass's gusts along the cone (their count, radius in shares of the
## reach) and their strength at a full draw (m/s: 10 lays the blades half
## over, more nearly flat).
const GUSTS := 5
const GUST_R := 0.22
const GUST_STRENGTH := 26.0
const DUST := Color(0.86,0.82,0.70)
const LEAF := Color(0.36,0.5,0.24)
const LEAF_DRY := Color(0.62,0.52,0.28)
const STREAK_TINT := Color(0.86,0.93,0.9)
## The blast's lane: its run (s), how far its front goes (shares of the
## reach), its half width (m) and lean (1 a full head).
const BLAST_RUN := 1.1
const BLAST_TRAVEL := 1.6
const BLAST_HALF := 3.5
const BLAST_LEAN := 1.3

var head: Node3D
var look := true
var reach := 12.0
var cone := 0.55
var share := 0.0
var _streaks: MeshInstance3D
var _streak_mat := ShaderMaterial.new()
var _strands: Array = []
var _motes: Array = []
var _puffs: Array = []
var _clock := 0.0
var _rng := RandomNumberGenerator.new()
var _gusts_on := false
var _lane_age := -1.0
var _lane := {}
var _ground_dust := 0.0

func setup(owner_head: Node3D, reach_m: float, cone_half: float, drawn := true) -> void:
	head = owner_head
	reach = reach_m
	cone = cone_half
	look = drawn
	top_level = true
	_rng.seed = 41
	if not look: return
	_streaks = MeshInstance3D.new()
	_streaks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_streaks.extra_cull_margin = 40.0
	_streak_mat.shader = TRAIL
	_streak_mat.set_shader_parameter("width",0.06)
	_streak_mat.set_shader_parameter("flow_speed",0.9)
	_streak_mat.set_shader_parameter("tint",STREAK_TINT)
	_streaks.material_override = _streak_mat
	add_child(_streaks)
	for i in range(STREAKS): _strands.append(_strand())
	var dust_mesh := SphereMesh.new()
	dust_mesh.radius = 0.05
	dust_mesh.height = 0.1
	dust_mesh.radial_segments = 6
	dust_mesh.rings = 3
	var leaf_mesh := BoxMesh.new()
	leaf_mesh.size = Vector3(0.16,0.015,0.1)
	for i in range(MOTES):
		var leaf := i%3 == 0
		var tint := (LEAF if i%2 == 0 else LEAF_DRY) if leaf else DUST
		var m := _blob(leaf_mesh if leaf else dust_mesh,tint)
		m.visible = false
		_motes.append({"node":m,"pos":Vector3.ZERO,"vel":Vector3.ZERO,"live":false,"spin":Vector3(_rng.randf_range(-7,7),_rng.randf_range(-5,5),_rng.randf_range(-7,7)),"leaf":leaf})
	var puff_mesh := SphereMesh.new()
	puff_mesh.radius = 0.5
	puff_mesh.height = 1.0
	puff_mesh.radial_segments = 10
	puff_mesh.rings = 5
	for i in range(PUFFS):
		var p := _blob(puff_mesh,DUST,false)
		p.visible = false
		_puffs.append({"node":p,"age":1.0,"life":1.0,"pos":Vector3.ZERO,"vel":Vector3.ZERO,"s0":0.2,"s1":0.5,"a":0.4})

## A strand of the streaks: where in the cone it starts (its angle across,
## its height share, its distance share), its swirl, its stroke's phase.
func _strand() -> Dictionary:
	return {"across":_rng.randf_range(-1.0,1.0),"rise":_rng.randf_range(-0.2,1.0),"far":_rng.randf_range(0.35,1.0),
		"swirl":_rng.randf_range(-1.0,1.0),"phase":_rng.randf(),"age":_rng.randf_range(0.0,1.6),"life":_rng.randf_range(1.1,1.9),"span":_rng.randf_range(0.25,0.4)}

func _blob(mesh: Mesh, tint: Color, lit := true) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 1.0
	if not lit:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(tint.r,tint.g,tint.b,1.0)
		mat.vertex_color_use_as_albedo = false
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	return m

## How hard it draws now (0..1), stepped `delta`.
func draw(how: float, delta: float) -> void:
	share = clampf(how,0.0,1.0)
	_clock += delta
	_publish_gusts()
	_step_lane(delta)
	if not look: return
	_step_streaks(delta)
	_step_motes(delta)
	_step_puffs(delta)
	_ground_dust -= delta
	if share > 0.15 and _ground_dust <= 0.0:
		_ground_dust = lerpf(0.5,0.12,share)
		var at := _cone_point(_rng.randf_range(0.25,0.9))
		_puff(at+Vector3.UP*0.2,(head.mouth()-at).normalized()*share*2.5+Vector3.UP*0.4,0.25,1.0,_rng.randf_range(0.7,1.2),0.28*share)

## Stone dust off its flank as it grinds round, at `at`.
func grind(at: Vector3) -> void:
	if not look: return
	_puff(at,Vector3(_rng.randf_range(-0.4,0.4),-0.3,_rng.randf_range(-0.4,0.4)),0.18,0.7,0.9,0.4)

## A thud on the turf: a low skirt of dust kicked out along its chin's edge
## at `at` (the edge `span` m wide, `way` its face), `size` 1 a full heave.
func thud(at: Vector3, way: Vector3, size: float, span: float) -> void:
	if not look: return
	var side := Vector3(-way.z,0.0,way.x)
	var n := int(clampf(4.0+size*4.0,3.0,12.0))
	for i in range(n):
		var across := (float(i)/maxf(n-1,1)-0.5)*span
		var out := (way*0.8+side*signf(across)*0.6).normalized() if absf(across) > span*0.3 else way
		_puff(at+side*across+Vector3.UP*0.12,out*_rng.randf_range(1.2,2.6)*size+Vector3.UP*_rng.randf_range(0.2,0.6),0.15*size,_rng.randf_range(0.45,0.8)*sqrt(size),_rng.randf_range(0.6,1.0),0.38)

## A call: a little breath of dust out of its mouth at `at`, along `way`.
func call_out(at: Vector3, way: Vector3) -> void:
	if not look: return
	for i in range(3):
		_puff(at+way*0.2,(way+Vector3(_rng.randf_range(-0.3,0.3),_rng.randf_range(0.0,0.3),_rng.randf_range(-0.3,0.3))).normalized()*_rng.randf_range(1.0,2.0),0.1,0.4,0.7,0.22)

## Holding what it swallowed: dust jets out of its ear flaps and its seams.
func swallowing(at_left: Vector3, at_right: Vector3, out: Vector3) -> void:
	if not look: return
	for at: Vector3 in [at_left,at_right]:
		var side := (at-head.global_position)
		side.y = 0.0
		side = side.normalized()
		_puff(at,side*_rng.randf_range(1.0,2.2)+Vector3.UP*0.3+out*0.2,0.12,0.6,0.6,0.5)

## The blast out of its mouth along `way` (unit), `reach_m` far.
func blast(mouth: Vector3, way: Vector3) -> void:
	var flat := Vector3(way.x,0.0,way.z).normalized()
	var floor_at: Vector3 = Vector3(mouth.x,head.ground_y(),mouth.z)
	_lane = {"a":Vector4(floor_at.x,floor_at.z,flat.x,flat.z),"travel":reach*BLAST_TRAVEL}
	_lane_age = 0.0
	if not look: return
	for i in range(24):
		var d := (way+Vector3(_rng.randf_range(-0.3,0.3),_rng.randf_range(-0.15,0.3),_rng.randf_range(-0.3,0.3))).normalized()
		_puff(mouth+way*0.3,d*_rng.randf_range(8.0,22.0),0.2,_rng.randf_range(0.8,1.6),_rng.randf_range(0.5,1.0),0.35)
	for m: Dictionary in _motes:
		if not m.live: continue
		m.vel = (way+Vector3(_rng.randf_range(-0.5,0.5),_rng.randf_range(0.0,0.6),_rng.randf_range(-0.5,0.5))).normalized()*_rng.randf_range(8.0,16.0)
		m.live = false
		m.blown = 1.2

# --- The streaks --------------------------------------------------------------------

func _step_streaks(delta: float) -> void:
	_streak_mat.set_shader_parameter("clock",_clock)
	_streak_mat.set_shader_parameter("opacity",smoothstep(0.0,0.6,share)*0.6)
	if share <= 0.01:
		_streaks.visible = false
		return
	_streaks.visible = true
	var mouth: Vector3 = head.mouth()
	var way: Vector3 = head.face_flat()
	var side := Vector3(-way.z,0.0,way.x)
	var floor_y: float = head.ground_y()
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for s: Dictionary in _strands:
		s.age += delta
		if s.age > s.life:
			var fresh := _strand()
			fresh.age = 0.0
			s.merge(fresh,true)
		var fade: float = smoothstep(0.0,0.5,s.age)*(1.0-smoothstep(s.life-0.6,s.life,s.age))
		var far: float = reach*float(s.far)*lerpf(0.55,1.0,share)
		var start := mouth+way*far+side*far*tan(cone)*float(s.across)
		start.y = lerpf(floor_y+0.15,mouth.y+far*0.25,clampf(float(s.rise),0.0,1.0))
		var pts := PackedVector3Array()
		# A wisp: a stretch of the way in, sliding toward the mouth over its life.
		var span: float = s.span
		var w0: float = clampf(float(s.age)/float(s.life),0.0,1.0)*(1.0-span)
		for k in range(SEGMENTS+1):
			var u := w0+span*float(k)/SEGMENTS
			var e := u*u*(3.0-2.0*u)
			var p := start.lerp(mouth,1.0-pow(1.0-u,1.6))
			p += side*sin(u*PI*1.3)*float(s.swirl)*far*0.22*(1.0-e)
			p.y += sin(u*PI)*0.25*far*0.06
			pts.append(p)
		for k in range(SEGMENTS):
			var u0 := float(k)/SEGMENTS
			var u1 := float(k+1)/SEGMENTS
			var c := Color(float(s.phase),0.0,0.0,fade)
			for corner: Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
				var u := u0 if corner.x == 0.0 else u1
				mesh.surface_set_uv(Vector2(u,corner.y))
				mesh.surface_set_color(c)
				mesh.surface_add_vertex(pts[k] if corner.x == 0.0 else pts[k+1])
	mesh.surface_end()
	_streaks.mesh = mesh

# --- The motes ----------------------------------------------------------------------

## A point on the turf in the cone, `d` of the reach out.
func _cone_point(d: float) -> Vector3:
	var mouth: Vector3 = head.mouth()
	var way: Vector3 = head.face_flat()
	var side := Vector3(-way.z,0.0,way.x)
	var far := reach*d
	var p := mouth+way*far+side*far*tan(cone)*_rng.randf_range(-0.9,0.9)
	var g: float = head.ground_at(p)
	p.y = (g if g != -INF else head.ground_y())+0.06
	return p

func _step_motes(delta: float) -> void:
	var mouth: Vector3 = head.mouth()
	for m: Dictionary in _motes:
		var node := m.node as MeshInstance3D
		if m.get("blown",0.0) > 0.0:
			# Blown out: flying on, slowing, falling.
			m.blown -= delta
			m.vel *= exp(-1.5*delta)
			m.vel.y -= 4.0*delta
			m.pos += m.vel*delta
			node.position = m.pos
			node.visible = m.blown > 0.0
			continue
		if not m.live:
			# A new one lifts while it draws.
			if share > 0.1 and _rng.randf() < share*delta*3.0:
				m.live = true
				m.pos = _cone_point(_rng.randf_range(0.12,0.8))
				m.vel = Vector3.ZERO
			else:
				node.visible = false
				continue
		var to: Vector3 = mouth-m.pos
		var d := to.length()
		if d < 0.35 or share <= 0.0:
			m.live = false
			node.visible = false
			continue
		# Along the air: quicker as it nears the mouth, lifting off first.
		var want := to/d*share*(1.5+16.0/(1.0+d*0.6))
		if m.pos.y < head.ground_y()+0.4: want.y += 1.5
		m.vel = m.vel.lerp(want,1.0-exp(-4.0*delta))
		m.pos += m.vel*delta
		node.position = m.pos
		node.rotation += (m.spin as Vector3)*delta*(1.5 if m.leaf else 0.5)
		node.scale = Vector3.ONE*clampf(d*0.6,0.4,1.0)
		node.visible = true

# --- The puffs ----------------------------------------------------------------------

func _puff(at: Vector3, vel: Vector3, s0: float, s1: float, life: float, alpha: float) -> void:
	var pick: Dictionary = _puffs[0]
	for p: Dictionary in _puffs:
		if float(p.age)/float(p.life) > float(pick.age)/float(pick.life): pick = p
	pick.age = 0.0
	pick.life = life
	pick.pos = at
	pick.vel = vel
	pick.s0 = s0
	pick.s1 = s1
	pick.a = alpha

func _step_puffs(delta: float) -> void:
	for p: Dictionary in _puffs:
		var node := p.node as MeshInstance3D
		p.age += delta
		var k: float = float(p.age)/float(p.life)
		if k >= 1.0:
			node.visible = false
			continue
		p.vel *= exp(-2.2*delta)
		p.pos += p.vel*delta
		node.position = p.pos
		node.scale = Vector3.ONE*lerpf(float(p.s0),float(p.s1),1.0-pow(1.0-k,2.0))
		node.transparency = 1.0-float(p.a)*smoothstep(0.0,0.12,k)*(1.0-k)
		node.visible = true

# --- The shared air (shaders) --------------------------------------------------------

## The gusts along the cone's floor, each toward the mouth, or none.
func _publish_gusts() -> void:
	if share <= 0.005:
		if _gusts_on:
			for i in range(GUSTS): _gust(i,Vector4.ZERO,Vector4.ZERO)
			_gusts_on = false
		return
	_gusts_on = true
	var mouth: Vector3 = head.mouth()
	var way: Vector3 = head.face_flat()
	var floor_y: float = head.ground_y()
	for i in range(GUSTS):
		var d := reach*(0.12+0.8*float(i)/float(GUSTS-1))
		var at := mouth+way*d
		at.y = floor_y+0.5
		var toward := (mouth-at)
		toward.y = 0.0
		toward = toward.normalized()
		# Nearer the mouth it pulls harder and the grass lies flatter.
		var strength := GUST_STRENGTH*share*lerpf(1.3,0.45,float(i)/float(GUSTS-1))
		var r := reach*GUST_R*lerpf(0.7,1.3,float(i)/float(GUSTS-1))
		_gust(i,Vector4(at.x,at.y,at.z,r),Vector4(toward.x,toward.y,toward.z,strength))

func _gust(i: int, origin: Vector4, vector: Vector4) -> void:
	RenderingServer.global_shader_parameter_set("zs_local_gust_origin_%d" % i,origin)
	RenderingServer.global_shader_parameter_set("zs_local_gust_vector_%d" % i,vector)

## The blast's lane, its front running out, then gone.
func _step_lane(delta: float) -> void:
	if _lane_age < 0.0: return
	_lane_age += delta
	var a := Vector4.ZERO
	var b := Vector4.ZERO
	var c := Vector4.ZERO
	if _lane_age < BLAST_RUN+2.5:
		a = _lane.a
		b = Vector4(_lane_age,BLAST_RUN,1.0,float(_lane.travel))
		c = Vector4(BLAST_LEAN,BLAST_HALF,float(_lane.travel)+6.0,0.0)
	else: _lane_age = -1.0
	RenderingServer.global_shader_parameter_set("zs_blow_0_a",a)
	RenderingServer.global_shader_parameter_set("zs_blow_0_b",b)
	RenderingServer.global_shader_parameter_set("zs_blow_0_c",c)

func _exit_tree() -> void:
	if _gusts_on:
		for i in range(GUSTS): _gust(i,Vector4.ZERO,Vector4.ZERO)
	if _lane_age >= 0.0:
		for k in ["a","b","c"]: RenderingServer.global_shader_parameter_set("zs_blow_0_%s" % k,Vector4.ZERO)
