extends Node3D
## The tell before a spur (docs/design/endless-flight/spec-burrower-chase.md): where the
## burrower has passed the rock blisters and cracks, the cracks glow and throw light, grit
## falls, and after the hold the spur snaps through (scripts/endless/bore_spurs.gd owns the
## timing and calls `light`). The cracked blister stays round the spur's root, cold, for as
## long as the spur does.
##
## A crack is a pooled patch laid on the bore's real rock, ROWS by ACROSS, built ahead of
## him a few rows a frame (`lay`, `work`) and hidden till he passes. Its shader raises the
## blister and draws the cracks from `now` less `lit_at`, so a frame only sets `now`.
## The grit is one mesh of quads the shader throws (burrower_bore_grit.gdshader), a few
## nodes of it in turn, one light to each. Nothing touches the bore's mesh or collision.

const Tunnels = preload("res://scripts/endless/tunnel_sites.gd")
const LandTunnels = preload("res://scripts/endless/land_tunnels.gd")
const BoreLine = preload("res://scripts/endless/bore_line.gd")
const CRACK_SHADER = preload("res://shaders/burrower_bore_crack.gdshader")
const GRIT_SHADER = preload("res://shaders/burrower_bore_grit.gdshader")

## The blister's radius: this many of the spur's girths, the most and least (m). How tall
## (a share of the radius), and the least (m): it has to stand clear of the ridge there.
const CRACK_GIRTHS := 2.6
const CRACK_R := Vector2(6.0,10.0)
const TALL_SHARE := 0.38
const TALL_LEAST := 3.2
## The patch: rows along the path, points across, rows laid a frame.
const ROWS := 7
const ACROSS := 9
const ROWS_A_FRAME := 1
## The burst's quads, how many bursts can run at once, and how long one lasts past the snap.
const BITS := 150
const BURSTS := 4
const BURST_AFTER_S := 1.8
## The light: what it starts at, reaches by the snap, jumps to at the snap, how fast it
## then dies (s), its range, and how far off the rock it stands (m).
const LIGHT_FROM := 3.0
const LIGHT_TO := 16.0
const LIGHT_SNAP := 28.0
const LIGHT_DIE_S := 0.3
const LIGHT_RANGE := 42.0
const LIGHT_OFF := 5.0
const LIGHT_TINT := Color(1.0,0.56,0.28)

## A patch being laid.
class Job:
	var site: Tunnels.Site
	var grain: FastNoiseLite
	var sp: RefCounted
	var r := 0.0
	var share := 0.0
	var row := 0
	var rng := RandomNumberGenerator.new()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var box := AABB()

## A burst of grit and its light.
class Burst:
	var node: MeshInstance3D
	var light: OmniLight3D
	var left := 0.0
	var clock := 0.0

## The clock the shaders read.
var now := 0.0
var _hold := 0.0
var _snap := 0.0
var _jobs: Array[Job] = []
var _spare: Array[MeshInstance3D] = []
var _bursts: Array[Burst] = []
var _next := 0
var _index := PackedInt32Array()
var _crack_mat: ShaderMaterial
var _grit_mat: ShaderMaterial
var _rng := RandomNumberGenerator.new()
## For drivers: the worst frame's work (us).
var stats := {"worst_us": 0}

func _init() -> void:
	name = "BoreTell"

## `hold`, `snap`: BoreSpurs' times from him passing to the snap, and the snap's.
func setup(hold: float, snap: float) -> void:
	_hold = hold
	_snap = snap
	_rng.seed = hash("bore tell")
	_crack_mat = ShaderMaterial.new()
	_crack_mat.shader = CRACK_SHADER
	_crack_mat.set_shader_parameter("hold",hold)
	_grit_mat = ShaderMaterial.new()
	_grit_mat.shader = GRIT_SHADER
	_grit_mat.set_shader_parameter("hold",hold)
	_index = _strip_index()
	var bits := _bits()
	for i in BURSTS:
		var b := Burst.new()
		b.node = MeshInstance3D.new()
		b.node.mesh = bits
		b.node.material_override = _grit_mat
		b.node.layers = LandTunnels.UNDER_LAYER
		b.node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		b.node.visible = false
		add_child(b.node)
		b.light = OmniLight3D.new()
		b.light.omni_range = LIGHT_RANGE
		b.light.light_color = LIGHT_TINT
		b.light.light_cull_mask = LandTunnels.UNDER_LAYER
		b.light.shadow_enabled = false
		b.light.light_specular = 0.2
		b.light.visible = false
		add_child(b.light)
		_bursts.append(b)

## Spur `sp`'s patch, to be laid a few rows a frame.
func lay(t: Tunnels.Site, grain: FastNoiseLite, sp: RefCounted) -> void:
	_jobs.append(_job(t,grain,sp))

func _job(t: Tunnels.Site, grain: FastNoiseLite, sp: RefCounted) -> Job:
	var job := Job.new()
	job.site = t
	job.grain = grain
	job.sp = sp
	job.r = clampf(float(sp.girth)*CRACK_GIRTHS,CRACK_R.x,CRACK_R.y)
	job.share = fposmod(BoreLine.angle_at(t,sp.s)/TAU,1.0)
	job.rng.seed = hash([t.seed,"bore crack",sp.s])
	return job

## This frame's rows.
func work() -> void:
	if _jobs.is_empty(): return
	var began := Time.get_ticks_usec()
	for i in ROWS_A_FRAME:
		if _jobs.is_empty(): break
		var job: Job = _jobs[0]
		_row(job)
		if job.row >= ROWS:
			_jobs.pop_front()
			_finish(job)
	stats.worst_us = maxi(int(stats.worst_us),Time.get_ticks_usec()-began)

## He's just passed `sp`: the crack opens and the grit starts, wherever its patch had got to.
func light(t: Tunnels.Site, grain: FastNoiseLite, sp: RefCounted) -> void:
	var job: Job = null
	for j: Job in _jobs:
		if j.sp == sp: job = j
	if job != null: _jobs.erase(job)
	elif sp.crack == null: job = _job(t,grain,sp)
	if job != null:
		while job.row < ROWS: _row(job)
		_finish(job)
	var crack: MeshInstance3D = sp.crack
	crack.set_instance_shader_parameter("lit_at",now)
	crack.visible = true
	var b: Burst = _bursts[_next]
	_next = (_next+1)%BURSTS
	var up: Vector3 = (BoreLine.middle(t,sp.s)-sp.root).normalized()
	b.node.position = sp.root
	b.node.set_instance_shader_parameter("lit_at",now)
	b.node.set_instance_shader_parameter("up",up)
	b.node.set_instance_shader_parameter("wide",float(crack.get_meta("r")))
	b.node.set_instance_shader_parameter("tall",float(crack.get_meta("tall")))
	b.node.visible = true
	b.light.position = sp.root+up*LIGHT_OFF
	b.light.light_energy = LIGHT_FROM
	b.light.visible = true
	b.clock = 0.0
	b.left = _hold+_snap+BURST_AFTER_S

## One frame.
func step(delta: float) -> void:
	now += delta
	_crack_mat.set_shader_parameter("now",now)
	_grit_mat.set_shader_parameter("now",now)
	for b: Burst in _bursts:
		if b.left <= 0.0: continue
		b.left -= delta
		b.clock += delta
		if b.left <= 0.0:
			b.node.visible = false
			b.light.visible = false
			continue
		b.light.light_energy = _light_at(b.clock)

## The light `t` s after he passed.
func _light_at(t: float) -> float:
	if t < _hold: return lerpf(LIGHT_FROM,LIGHT_TO,t/_hold)*(0.8+0.2*sin(t*53.0)*sin(t*31.0))
	return LIGHT_SNAP*exp(-(t-_hold)/LIGHT_DIE_S)

## `sp`'s tunnel is gone.
func drop(sp: RefCounted) -> void:
	for j: Job in _jobs:
		if j.sp == sp:
			_jobs.erase(j)
			break
	if sp.crack == null: return
	sp.crack.visible = false
	_spare.append(sp.crack)
	sp.crack = null

## One row of the patch, on the rock's real ring.
func _row(job: Job) -> void:
	var t := job.site
	var q := -1.0+2.0*job.row/(ROWS-1)
	var at := clampf(float(job.sp.s)+q*job.r,0.0,t.length)
	var ring := BoreLine.ring(t,job.grain,at)
	var metres := BoreLine.round_m(ring)
	var u0 := job.share*metres[metres.size()-1]
	var mid := BoreLine.middle(t,at)
	if job.row == 0: job.box = AABB(ring[0],Vector3.ZERO)
	for j in ACROSS:
		var u := -1.0+2.0*j/(ACROSS-1)
		var v := BoreLine.on_ring(ring,metres,u0+u*job.r)
		var whole := 0.0 if Tunnels.shaft_at(t,v.x,v.z,Tunnels.SHAFT_R-LandTunnels.SHAFT_CUT) >= 0 else 1.0
		if job.verts.is_empty(): job.box = AABB(v,Vector3.ZERO)
		job.verts.append(v)
		job.normals.append((mid-v).normalized())
		job.uv.append(Vector2(u,q))
		job.uv2.append(Vector2(whole,job.rng.randf()))
		job.box = job.box.expand(v)
	job.row += 1

## The rows into a mesh of the pool, hidden.
func _finish(job: Job) -> void:
	var node := _take()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = job.verts
	arrays[Mesh.ARRAY_NORMAL] = job.normals
	arrays[Mesh.ARRAY_TEX_UV] = job.uv
	arrays[Mesh.ARRAY_TEX_UV2] = job.uv2
	arrays[Mesh.ARRAY_INDEX] = _index
	var mesh: ArrayMesh = node.mesh
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var tall := maxf(job.r*TALL_SHARE,TALL_LEAST)
	mesh.custom_aabb = job.box.grow(tall+1.0)
	node.set_instance_shader_parameter("tall",tall)
	node.set_instance_shader_parameter("wide",job.r)
	node.set_instance_shader_parameter("seed",job.rng.randf()*100.0)
	node.set_meta("r",job.r)
	node.set_meta("tall",tall)
	job.sp.crack = node

func _take() -> MeshInstance3D:
	if not _spare.is_empty(): return _spare.pop_back()
	var node := MeshInstance3D.new()
	node.mesh = ArrayMesh.new()
	node.material_override = _crack_mat
	node.layers = LandTunnels.UNDER_LAYER
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visible = false
	add_child(node)
	return node

## The patch's triangles.
func _strip_index() -> PackedInt32Array:
	var out := PackedInt32Array()
	for r in ROWS-1:
		for c in ACROSS-1:
			var a := r*ACROSS+c
			var b := a+ACROSS
			out.append_array(PackedInt32Array([a,b,a+1,a+1,b,b+1]))
	return out

## The burst's quads: UV the corner, COLOR and NORMAL's unit vector each bit's draws. The
## shader places them all.
func _bits() -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var colors := PackedColorArray()
	var index := PackedInt32Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("bore grit")
	for i in BITS:
		var c := Color(rng.randf(),rng.randf(),rng.randf(),rng.randf())
		var n := Vector3(rng.randf_range(-1.0,1.0),rng.randf_range(-1.0,1.0),rng.randf_range(-1.0,1.0)).normalized()
		var at := verts.size()
		for corner: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
			verts.append(Vector3.ZERO)
			normals.append(n)
			uv.append(corner)
			colors.append(c)
		index.append_array(PackedInt32Array([at,at+1,at+2,at,at+2,at+3]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.custom_aabb = AABB(Vector3(-40.0,-40.0,-40.0),Vector3(80.0,80.0,80.0))
	return mesh
