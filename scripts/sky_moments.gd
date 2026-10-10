extends Node3D
## The moments set pieces in the sky (--moments): the flight study's five
## greybox stations (scripts/flight_pack_moments.gd, docs/design/
## flight-study-moments.md) littered through the open sky between the
## islands, where the world's layout lays them (scripts/sky_world.gd
## `_moments`: a dozen or so, the five turned and mirrored), each as the
## study has it (scripts/sky_moments_plan.gd): plain grid-grey stone that
## carries a natural line, three free collectibles (gold balls), and a
## starter (a magenta hoop) that brings out three challenge collectibles
## (orange-red diamonds) for one pass.
##
## Found by flying about: every set piece's starter hoop, its beacon (a
## tall magenta column over it) and its leads (small magenta markers out
## along its line's way in) stand from the start, far off, so one is seen
## from a fair way and the leads point the way in; the stone and the
## collectibles stream in near (VIEW).
##
## The starter: flown through toward the entry (and only that way: it faces
## along the line), it starts the challenge, so whoever comes in from
## wherever lines up with the line by taking it. Its challenge collectibles
## come out (all at once, or one after another with --challenge-mode=chain)
## and the HUD (scripts/moments_hud.gd) counts them; the challenge ends
## when all are taken (complete), when the plane leaves the set piece's area
## (the box round it, Plan AREA past it), when the plane is gone (landed,
## ejected) or, with --challenge-time=<s>, when its time is up. Never a
## penalty: what is left goes away and the hoop stands again once the plane
## is REARM m off it, for another try (and again after a complete one, its
## core gold: done before).
##
## The free collectibles are always there till taken, and once taken stay
## taken: kept with the world (`save_state`, in SkyIslands' state) with each
## set piece's tries, best and completions. Taken as the study takes them:
## the plane's path since its last frame passes within the moment's own
## reach (FlightCourse REACH times its ease).
##
## Solid: each set piece's stone is one static body of the study's own
## boxes and cylinders on the ruins' layer (scripts/ruin_bump.gd LAYER), so
## the plane bumps off it exactly as in the study (bump and recover, a share
## of its speed lost), and one mesh (a surface each for boxes, cylinders and
## the plinth), made on a worker within VIEW of the eye, one at a time,
## nearest first, stood up in one commit within the sky's frame budget
## (scripts/sky_commits.gd), and let go past FORGET.
##
## Debug: `hop` and `list` (the wanderer's N in the plane, `--moments-at=N`)
## put the plane on a set piece's way in, HOP_OUT m out, flying its line.

const Plan = preload("res://scripts/sky_moments_plan.gd")
const Course = preload("res://scripts/flight_course.gd")
const RuinBump = preload("res://scripts/ruin_bump.gd")
const SkyWorld = preload("res://scripts/sky_world.gd")
const SkyCells = preload("res://scripts/sky_cells.gd")
const SkyCommits = preload("res://scripts/sky_commits.gd")
const Hud = preload("res://scripts/moments_hud.gd")
const GRID := preload("res://shaders/character_study_grid.gdshader")

## Stone and collectibles stand within VIEW of the eye (m, plate plane),
## go past FORGET; looked over every CHECK s.
const VIEW := 1300.0
const FORGET := 1550.0
const CHECK := 0.5
## Cylinders drawn with this many sides (the colliders are true cylinders).
const SIDES := 16
## The study's greybox tints (studies/flight_study.gd COLOURS) and its
## collectibles' (FREE, STARTER, CHALLENGE).
const TINTS := {"floor":Color(0.64,0.64,0.62),"box":Color(0.55,0.57,0.6),"cyl":Color(0.6,0.58,0.55)}
const FREE := Color(1.0,0.82,0.3)
const STARTER := Color(0.95,0.25,0.85)
const CHALLENGE := Color(1.0,0.38,0.18)
const DONE := Color(1.0,0.82,0.3)
## The diamonds' spin (rad/s).
const SPIN := 2.0
## A hoop stands again once the plane is this far off it (m).
const REARM := 20.0
## The challenge ends this long (s) after the plane last touched (it
## landed, the pilot ejected or walks).
const LOST := 1.0
## A move further than this in a frame (a hop, a claim) starts the path
## afresh.
const JUMP := 30.0
## Hops put the plane this far out along the way in (m) at the line's
## height, flying the line.
const HOP_OUT := 200.0
## The leads' size (m across).
const LEAD := 1.8
## The hoop, its core and the leads draw within this (m); the beacon's
## column draws as far as the sky does, one draw a set piece far off.
const NEAR_BEACON := 1400.0

static func enabled() -> bool:
	SkyWorld.read_flags()
	return SkyWorld.moments

## --challenge-time=<s> and --challenge-mode=all|chain: every set piece's
## challenge as the study's variants fly it ({} as the stations have it).
static func override() -> Dictionary:
	var out := {}
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--challenge-time=") and a.trim_prefix("--challenge-time=").is_valid_float(): out.time = float(a.trim_prefix("--challenge-time="))
		if a.begins_with("--challenge-mode="): out.mode = a.trim_prefix("--challenge-mode=")
	return out

## The scene (to keep the world after a pickup) and the cells (home
## coordinates).
var scene: Node
var cells: SkyCells
## The set pieces laid out (SkyWorld `moment_spots`), in the layout's order.
var placements: Array = []
## Set pieces made or standing, by key: {p, task, out, node, nodes (moment
## index -> MeshInstance3D)}.
var stations := {}
## Each set piece's hoop, beacon and leads, by key: {node, ring, core}.
var beacons := {}
## Free collectibles taken ("<key>:<index>" -> true) and each set piece's
## record ({tries, best, done}), kept with the world.
var collected := {}
var record := {}
## The challenge on: {key, layout, from (s), got, live (moment indices
## out), taken (index -> true), rules}, or empty.
var challenge := {}
## Each set piece's hoop: false while its challenge is on or till the
## plane has gone REARM off it.
var armed := {}
## The world seed the set pieces were laid for.
var seed_value := 0
## The last hop's index (`hop_next`).
var hopped := -1
var rules_override := {}
var hud: CanvasLayer
## For the record: the stone's sizes and costs, by key ({solids, verts,
## make_usec, stand_usec}), and the last frame's survey and stand cost (µs).
var stats := {}
var spent := {}
var _clock := 0.0
var _touched := -INF
var _last := Vector3.INF
var _since := CHECK
var _materials := {}

func _init() -> void:
	name = "SkyMoments"
	rules_override = override()

func _ready() -> void:
	hud = Hud.new()
	add_child(hud)

func _exit_tree() -> void:
	_wait_all()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE: _wait_all()

func _wait_all() -> void:
	for key in stations:
		var s: Dictionary = stations[key]
		if int(s.get("task",-1)) >= 0:
			WorkerThreadPool.wait_for_task_completion(s.task)
			s.task = -1

## Lets every set piece go; what was collected stays.
func clear() -> void:
	_wait_all()
	for key in stations.keys(): _forget(key)
	stations.clear()
	for key in beacons: (beacons[key].node as Node).queue_free()
	beacons.clear()
	if not challenge.is_empty(): _end("over")
	placements = []

## Starts over on fresh cells: every set piece's hoop, beacon and leads
## stood at once; the stone streams in.
func reset(new_cells: SkyCells) -> void:
	clear()
	cells = new_cells
	seed_value = SkyWorld.seed
	position = cells.origin
	Plan.prepare()
	_material("box")
	placements = SkyWorld.moment_spots().duplicate()
	for p: Dictionary in placements:
		armed[p.key] = true
		_beacon(p)
	_since = CHECK

# --- Each frame -----------------------------------------------------------------------

## Each frame of the glide (the eye in the islands' frame): follow the
## origin, make the near, stand what is made, let the far go; the challenge
## ended if the plane has gone; the diamonds turned.
func advance(delta: float, eye: Vector3) -> void:
	if cells == null: return
	position = cells.origin
	_clock += delta
	_since += delta
	if _since >= CHECK:
		_since = 0.0
		var began := Time.get_ticks_usec()
		_survey(eye-cells.origin)
		spent.survey = Time.get_ticks_usec()-began
	_stand_some()
	if not challenge.is_empty() and _clock-_touched > LOST: _end("left")
	if not challenge.is_empty():
		var s: Dictionary = stations.get(challenge.key,{})
		for i: int in challenge.live:
			var n: Variant = (s.get("nodes",{}) as Dictionary).get(i)
			if n is Node3D and is_instance_valid(n): (n as Node3D).rotate_y(SPIN*delta)
		_show_status()

func _survey(home: Vector3) -> void:
	for key in stations.keys():
		if _flat_box(stations[key].p,home) > FORGET: _forget(key)
	for key in stations:
		if int(stations[key].get("task",-1)) >= 0: return
	var nearest: Variant = null
	var best := INF
	for p: Dictionary in placements:
		if stations.has(p.key): continue
		var d := _flat_box(p,home)
		if d < VIEW and d < best:
			best = d
			nearest = p
	if nearest != null: _make(nearest)

## A set piece made on a worker: its stone's mesh and body, off the tree.
func _make(p: Dictionary) -> void:
	var out := {}
	var mats := {"box":_material("box"),"cyl":_material("cyl"),"floor":_material("floor")}
	var task := WorkerThreadPool.add_task(func() -> void: build(p,mats,out),true,"Moments set piece")
	stations[p.key] = {"p":p,"task":task,"out":out,"node":null,"nodes":{}}

func _stand_some() -> void:
	for key in stations:
		var s: Dictionary = stations[key]
		if int(s.task) < 0 or not WorkerThreadPool.is_task_completed(s.task): continue
		if not SkyCommits.open(): return
		WorkerThreadPool.wait_for_task_completion(s.task)
		s.task = -1
		var began := Time.get_ticks_usec()
		_stand(s)
		var usec := Time.get_ticks_usec()-began
		SkyCommits.spend("moments",usec)
		spent.stand = usec
		(stats.get(key,{}) as Dictionary).stand_usec = usec
		return

## Stands every set piece being made, whole, now (tests, probes, captures).
func flush() -> void:
	for key in stations:
		var s: Dictionary = stations[key]
		if int(s.task) < 0: continue
		WorkerThreadPool.wait_for_task_completion(s.task)
		s.task = -1
		var began := Time.get_ticks_usec()
		_stand(s)
		(stats.get(key,{}) as Dictionary).stand_usec = Time.get_ticks_usec()-began

## Makes and stands the set piece at `key` now, on this thread.
func make_now(key: String) -> void:
	for p: Dictionary in placements:
		if p.key != key or stations.has(key): continue
		var out := {}
		build(p,{"box":_material("box"),"cyl":_material("cyl"),"floor":_material("floor")},out)
		stations[key] = {"p":p,"task":-1,"out":out,"node":null,"nodes":{}}
		var began := Time.get_ticks_usec()
		_stand(stations[key])
		(stats.get(key,{}) as Dictionary).stand_usec = Time.get_ticks_usec()-began

func _stand(s: Dictionary) -> void:
	var out: Dictionary = s.out
	var node: Node3D = out.node
	add_child(node)
	s.node = node
	stats[s.p.key] = out.stats
	_stand_moments(s)

func _forget(key: String) -> void:
	var s: Dictionary = stations[key]
	if int(s.get("task",-1)) >= 0: WorkerThreadPool.wait_for_task_completion(s.task)
	var node: Variant = s.get("node")
	if node is Node and is_instance_valid(node): (node as Node).queue_free()
	elif s.out.get("node") is Node and is_instance_valid(s.out.node): (s.out.node as Node).free()
	stations.erase(key)

## The clouds part round each standing set piece (SkyClouds `keep_off`):
## Vector4(x, z, 0, radius) in the islands' frame, round its footprint.
func keep_spots(_eye := Vector3.ZERO) -> Array:
	var out := []
	for key in stations:
		var s: Dictionary = stations[key]
		if s.get("node") == null: continue
		var at: Vector3 = position+(s.p.box_at as Vector3)
		out.append(Vector4(at.x,at.z,0.0,(s.p.half as Vector2).length()+30.0))
	return out

## The standing set pieces, by key (tests).
func standing() -> Dictionary:
	var out := {}
	for key in stations:
		if stations[key].get("node") != null: out[key] = stations[key]
	return out

# --- Making one -------------------------------------------------------------------------

## A set piece's stone, safe on a worker once the materials are made: one
## Node3D at its entry (home) holding a mesh (boxes, cylinders and plinth a
## surface each) and a static body on the ruins' layer with a shape a solid,
## the study's own. out: {node, stats}.
static func build(p: Dictionary, mats: Dictionary, out: Dictionary) -> void:
	var began := Time.get_ticks_usec()
	var at: Vector3 = p.at
	var turn := float(p.turn)
	var mirror := bool(p.mirror)
	var root := Node3D.new()
	root.name = "Moments_%s" % str(p.key).replace(",","_").replace("@","_").replace("-","m")
	root.position = at
	var body := StaticBody3D.new()
	body.name = "Stone"
	body.collision_layer = RuinBump.LAYER
	body.collision_mask = 0
	root.add_child(body)
	var surfaces := {"box":[PackedVector3Array(),PackedVector3Array()],"cyl":[PackedVector3Array(),PackedVector3Array()],"floor":[PackedVector3Array(),PackedVector3Array()]}
	var frame := Plan.frame(turn,mirror)
	var solids := Plan.local_solids(int(p.layout))
	for q: Dictionary in solids:
		var middle: Vector3 = frame*(q.middle as Vector3)
		var shape := CollisionShape3D.new()
		if q.kind == "box":
			var b := Plan.solid_basis(q.basis,turn,mirror)
			var box := BoxShape3D.new()
			box.size = q.size
			shape.shape = box
			shape.transform = Transform3D(b,middle)
			var surface: Array = surfaces["floor" if q.get("plinth",false) else "box"]
			_box(surface[0],surface[1],middle,b,(q.size as Vector3)*0.5)
		else:
			var cyl := CylinderShape3D.new()
			cyl.radius = q.radius
			cyl.height = q.height
			shape.shape = cyl
			shape.position = middle
			var surface: Array = surfaces.cyl
			_cylinder(surface[0],surface[1],middle,float(q.radius),float(q.height))
		body.add_child(shape)
	var mesh := ArrayMesh.new()
	var verts := 0
	for kind: String in ["box","cyl","floor"]:
		var v: PackedVector3Array = surfaces[kind][0]
		if v.is_empty(): continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = surfaces[kind][1]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		mesh.surface_set_material(mesh.get_surface_count()-1,mats[kind])
		verts += v.size()
	var drawn := MeshInstance3D.new()
	drawn.name = "Greybox"
	drawn.mesh = mesh
	drawn.visibility_range_end = FORGET
	drawn.set_meta("skip_reflection",true)
	root.add_child(drawn)
	out.node = root
	out.stats = {"solids":solids.size(),"verts":verts,"make_usec":Time.get_ticks_usec()-began}

## A box's faces (triangles, flat normals) into `v` and `n`: middle `c`,
## turned by `b`, half extents `h`; wound to face out (Godot's clockwise
## front).
static func _box(v: PackedVector3Array, n: PackedVector3Array, c: Vector3, b: Basis, h: Vector3) -> void:
	var axes := [b.x*h.x,b.y*h.y,b.z*h.z]
	for a in range(3):
		var u: Vector3 = axes[(a+1)%3]
		var w: Vector3 = axes[(a+2)%3]
		for side: float in [-1.0,1.0]:
			var out: Vector3 = axes[a]*side
			var normal := out.normalized()
			_quad(v,n,c+out-u-w,c+out+u-w,c+out+u+w,c+out-u+w,normal)

## An upright cylinder's side (smooth) and caps into `v` and `n`.
static func _cylinder(v: PackedVector3Array, n: PackedVector3Array, c: Vector3, r: float, height: float) -> void:
	var up := Vector3.UP*height*0.5
	for k in range(SIDES):
		var a0 := TAU*k/SIDES
		var a1 := TAU*(k+1)/SIDES
		var d0 := Vector3(cos(a0),0.0,sin(a0))
		var d1 := Vector3(cos(a1),0.0,sin(a1))
		var p0 := c+d0*r
		var p1 := c+d1*r
		_tri(v,n,[p0-up,p1-up,p1+up],[d0,d1,d1],(d0+d1).normalized())
		_tri(v,n,[p0-up,p1+up,p0+up],[d0,d1,d0],(d0+d1).normalized())
		_tri(v,n,[c+up,p0+up,p1+up],[Vector3.UP,Vector3.UP,Vector3.UP],Vector3.UP)
		_tri(v,n,[c-up,p1-up,p0-up],[Vector3.DOWN,Vector3.DOWN,Vector3.DOWN],Vector3.DOWN)

static func _quad(v: PackedVector3Array, n: PackedVector3Array, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3) -> void:
	_tri(v,n,[a,b,c],[normal,normal,normal],normal)
	_tri(v,n,[a,c,d],[normal,normal,normal],normal)

## One triangle, wound so its front (clockwise, as Godot draws) faces `out`.
static func _tri(v: PackedVector3Array, n: PackedVector3Array, p: Array, normals: Array, out: Vector3) -> void:
	var a: Vector3 = p[0]
	var b: Vector3 = p[1]
	var c: Vector3 = p[2]
	if (b-a).cross(c-a).dot(out) > 0.0:
		v.append_array([a,c,b])
		n.append_array([normals[0],normals[2],normals[1]])
	else:
		v.append_array([a,b,c])
		n.append_array([normals[0],normals[1],normals[2]])

func _material(kind: String) -> Material:
	if not _materials.has(kind):
		var m := ShaderMaterial.new()
		m.shader = GRID
		m.set_shader_parameter("tint",TINTS.get(kind,TINTS.box))
		_materials[kind] = m
	return _materials[kind]

func _glow(colour: Color, unshaded := false) -> StandardMaterial3D:
	var key := "glow:%s:%s" % [colour.to_html(),unshaded]
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = colour
		m.emission_enabled = true
		m.emission = colour
		m.emission_energy_multiplier = 0.8
		if unshaded: m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_materials[key] = m
	return _materials[key]

# --- The collectibles, the hoop and the beacon --------------------------------------------

## A set piece's free and challenge collectibles, as the study draws them
## (a size that follows the reach): the free ones not yet taken, the
## challenge ones hidden unless its challenge is on.
func _stand_moments(s: Dictionary) -> void:
	var p: Dictionary = s.p
	for m: Dictionary in Plan.moments(int(p.layout)):
		if m.role == "starter": continue
		if m.role == "free" and collected.has(_id(p,m)): continue
		var size := Course.TOKEN_SIZE*clampf(float(m.reach)/Course.REACH,0.6,1.4)
		var node := MeshInstance3D.new()
		if m.role == "challenge":
			var diamond := SphereMesh.new()
			diamond.radius = size*0.55
			diamond.height = size*1.3
			diamond.radial_segments = 4
			diamond.rings = 1
			node.mesh = diamond
			node.material_override = _glow(CHALLENGE)
			node.visible = not challenge.is_empty() and challenge.key == p.key and int(m.index) in (challenge.live as Array)
		else:
			var ball := SphereMesh.new()
			ball.radius = size*0.5
			ball.height = size
			ball.radial_segments = 16
			ball.rings = 8
			node.mesh = ball
			node.material_override = _glow(FREE)
		# Under the stone's node (at the entry, unturned), so it goes with it.
		node.position = Plan.place(p,m.at)-(p.at as Vector3)
		node.set_meta("moment",_id(p,m))
		(s.node as Node3D).add_child(node)
		s.nodes[int(m.index)] = node

## A set piece's hoop (facing along its line, on its way in), its beacon
## standing over it and its leads out along the same line: always standing.
func _beacon(p: Dictionary) -> void:
	var root := Node3D.new()
	root.name = "Beacon_%s" % str(p.key).replace(",","_").replace("@","_").replace("-","m")
	add_child(root)
	var at := Plan.place(p,Plan.starter())
	var face := Basis(Vector3.UP,float(p.turn))*Basis(Vector3.RIGHT,PI*0.5)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = Plan.RING_R-0.35
	torus.outer_radius = Plan.RING_R+0.35
	torus.rings = 32
	torus.ring_segments = 8
	ring.mesh = torus
	ring.material_override = _glow(STARTER)
	ring.transform = Transform3D(face,at)
	ring.visibility_range_end = NEAR_BEACON
	root.add_child(ring)
	var core := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.5
	ball.height = 1.0
	core.mesh = ball
	core.material_override = _glow(DONE if _done(p) else STARTER)
	core.position = at
	core.visibility_range_end = NEAR_BEACON
	root.add_child(core)
	var column := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = Plan.BEACON.y*0.4
	cyl.bottom_radius = Plan.BEACON.y
	cyl.height = Plan.BEACON.x
	cyl.radial_segments = 8
	cyl.rings = 1
	column.mesh = cyl
	column.material_override = _glow(STARTER,true)
	column.position = at+Vector3.UP*(Plan.RING_R+1.5+Plan.BEACON.x*0.5)
	column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(column)
	for out: float in Plan.LEADS:
		var lead := MeshInstance3D.new()
		var diamond := SphereMesh.new()
		diamond.radius = LEAD*0.5
		diamond.height = LEAD*1.4
		diamond.radial_segments = 4
		diamond.rings = 1
		lead.mesh = diamond
		lead.material_override = _glow(STARTER,true)
		lead.position = Plan.place(p,Vector3(0.0,0.0,out))
		lead.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lead.visibility_range_end = NEAR_BEACON
		root.add_child(lead)
	beacons[p.key] = {"node":root,"ring":ring,"core":core,"column":column}
	_show_armed(p.key)

func _show_armed(key: String) -> void:
	var b: Dictionary = beacons.get(key,{})
	if b.is_empty(): return
	var on: bool = armed.get(key,true)
	(b.ring as Node3D).visible = on
	(b.core as Node3D).visible = on
	var p := _placement(key)
	(b.core as MeshInstance3D).material_override = _glow(DONE if _done(p) else STARTER)
	# The column dims while its challenge is on (it stands for "go here").
	(b.column as MeshInstance3D).transparency = 0.0 if on else 0.75

# --- Taking them ------------------------------------------------------------------------

## The plane (global) this frame: free collectibles and live challenge ones
## within their reach of its path since the last frame are taken; flown
## through a hoop toward its entry, the challenge starts; out of the area or
## past its time, it ends.
func touch_plane(point: Vector3) -> void:
	if cells == null: return
	var home := to_local(point)
	var from := _last if _last != Vector3.INF and _last.distance_to(home) <= JUMP else home
	_last = home
	_touched = _clock
	# A hoop stands again once the plane is REARM off it.
	for p: Dictionary in placements:
		if armed.get(p.key,true) or (not challenge.is_empty() and challenge.key == p.key): continue
		if Plan.place(p,Plan.starter()).distance_to(home) > REARM:
			armed[p.key] = true
			_show_armed(p.key)
	for p: Dictionary in placements:
		if _flat_box(p,home) > 60.0: continue
		var a := Plan.unplace(p,from)
		var b := Plan.unplace(p,home)
		for m: Dictionary in Plan.moments(int(p.layout)):
			match str(m.role):
				"free":
					if collected.has(_id(p,m)): continue
					if _near(m.at,a,b) < float(m.reach): _take_free(p,m)
				"challenge":
					if challenge.is_empty() or challenge.key != p.key or (challenge.taken as Dictionary).has(m.index): continue
					if not int(m.index) in (challenge.live as Array): continue
					if _near(m.at,a,b) < float(m.reach): _take_challenge(p,m)
				"starter":
					if challenge.is_empty() and armed.get(p.key,true) and _through(a,b): _start(p)
	if challenge.is_empty(): return
	var on := _placement(challenge.key)
	var rules: Dictionary = challenge.rules
	if float(rules.time) > 0.0 and _clock-float(challenge.from) >= float(rules.time): _end("timeout")
	elif not Plan.in_area(int(on.layout),Plan.unplace(on,home)): _end("left")

static func _near(at: Vector3, a: Vector3, b: Vector3) -> float:
	return Geometry3D.get_closest_point_to_segment(at,a,b).distance_to(at)

## True if a path (its own metres) crossed the hoop toward the entry,
## within its radius.
static func _through(a: Vector3, b: Vector3) -> bool:
	var s := Plan.starter()
	if not (a.z >= s.z and b.z < s.z): return false
	var t := (a.z-s.z)/maxf(a.z-b.z,0.0001)
	var cross := a.lerp(b,t)
	return Vector2(cross.x-s.x,cross.y-s.y).length() <= Plan.RING_R

func _take_free(p: Dictionary, m: Dictionary) -> void:
	collected[_id(p,m)] = true
	_vanish(p,int(m.index))
	var got := 0
	var of := 0
	for q: Dictionary in Plan.moments(int(p.layout)):
		if q.role != "free": continue
		of += 1
		if collected.has(_id(p,q)): got += 1
	if hud != null:
		hud.pop("%s  ·  free %d/%d" % [Plan.footprint(int(p.layout)).name,got,of])
		hud.blip(got-1)
	_kept()

func _take_challenge(p: Dictionary, m: Dictionary) -> void:
	challenge.taken[m.index] = true
	challenge.got = int(challenge.got)+1
	_vanish(p,int(m.index))
	var r := _record(p.key)
	r.best = maxi(int(r.best),int(challenge.got))
	if hud != null: hud.blip(int(challenge.got)+2)
	var next := _challenge_next()
	if next < 0:
		_end("complete")
		return
	if str(challenge.rules.mode) == "chain":
		challenge.live = [next]
		_show_challenge()
	_show_status()

## The first challenge collectible of the challenge on not yet taken, or -1.
func _challenge_next() -> int:
	for m: Dictionary in Plan.moments(int(challenge.layout)):
		if m.role == "challenge" and not (challenge.taken as Dictionary).has(m.index): return int(m.index)
	return -1

func _start(p: Dictionary) -> void:
	var rules := Plan.challenge(int(p.layout))
	rules.merge(rules_override,true)
	challenge = {"key":p.key,"layout":int(p.layout),"from":_clock,"got":0,"live":[],"taken":{},"rules":rules}
	var live: Array = []
	for m: Dictionary in Plan.moments(int(p.layout)):
		if m.role == "challenge": live.append(int(m.index))
	challenge.live = live if str(rules.mode) != "chain" else live.slice(0,1)
	armed[p.key] = false
	_show_armed(p.key)
	var r := _record(p.key)
	r.tries = int(r.tries)+1
	_show_challenge()
	if hud != null:
		hud.pop("Challenge  ·  %s" % Plan.footprint(int(p.layout)).name)
		hud.blip(2)
	_show_status()

## The challenge over (`why`: complete, left, timeout, over): what is left
## goes away; the hoop stands again once the plane is off it.
func _end(why: String) -> void:
	var key: String = challenge.key
	var got := int(challenge.got)
	var of := 0
	for m: Dictionary in Plan.moments(int(challenge.layout)):
		if m.role == "challenge": of += 1
	challenge.live = []
	_show_challenge()
	challenge = {}
	if why == "complete":
		var r := _record(key)
		r.done = int(r.done)+1
		_kept()
	if hud != null and why != "over":
		match why:
			"complete":
				hud.pop("Challenge complete  ·  %d/%d" % [got,of],3.0)
				hud.flourish()
			"timeout": hud.pop("Challenge ended  ·  time up  ·  %d/%d" % [got,of])
			_: hud.pop("Challenge ended  ·  left the area  ·  %d/%d" % [got,of])
		hud.status("")
	_show_armed(key)

## The challenge collectibles of the set piece whose challenge is on (or
## was) shown as they are live.
func _show_challenge() -> void:
	var s: Dictionary = stations.get(challenge.get("key",""),{})
	for i: int in (s.get("nodes",{}) as Dictionary):
		var n: Variant = s.nodes[i]
		if not n is Node3D or not is_instance_valid(n): continue
		var m: Dictionary = Plan.moments(int(s.p.layout))[i]
		if m.role != "challenge": continue
		(n as Node3D).visible = i in (challenge.live as Array) and not (challenge.taken as Dictionary).has(i)

func _show_status() -> void:
	if hud == null or challenge.is_empty(): return
	var of := 0
	for m: Dictionary in Plan.moments(int(challenge.layout)):
		if m.role == "challenge": of += 1
	var text := "challenge %d/%d" % [int(challenge.got),of]
	var limit := float(challenge.rules.time)
	if limit > 0.0: text += "  ·  %d s" % ceili(maxf(0.0,limit-(_clock-float(challenge.from))))
	if text != hud.last_status: hud.status(text)

func _vanish(p: Dictionary, index: int) -> void:
	var s: Dictionary = stations.get(p.key,{})
	var n: Variant = (s.get("nodes",{}) as Dictionary).get(index)
	if not n is Node3D or not is_instance_valid(n): return
	var tween := (n as Node3D).create_tween()
	tween.tween_property(n,"scale",Vector3.ONE*0.01,0.22).set_ease(Tween.EASE_IN)
	if (Plan.moments(int(p.layout))[index] as Dictionary).role == "free":
		s.nodes.erase(index)
		tween.tween_callback((n as Node).queue_free)
	else:
		tween.tween_callback(func() -> void:
			if is_instance_valid(n):
				(n as Node3D).visible = false
				(n as Node3D).scale = Vector3.ONE)

static func _id(p: Dictionary, m: Dictionary) -> String:
	return "%s:%d" % [p.key,int(m.index)]

func _record(key: String) -> Dictionary:
	if not record.has(key): record[key] = {"tries":0,"best":0,"done":0}
	return record[key]

func _done(p: Dictionary) -> bool:
	return not p.is_empty() and int((record.get(p.key,{}) as Dictionary).get("done",0)) > 0

func _placement(key: String) -> Dictionary:
	for p: Dictionary in placements:
		if p.key == key: return p
	return {}

## The world kept soon after (as the tokens do).
func _kept() -> void:
	var session: Variant = scene.get("world_session") if scene != null else null
	if session is Node and session.has_method("edited"): session.edited()

# --- Keeping --------------------------------------------------------------------------

## What the world's save keeps: the free collectibles taken, each set
## piece's record, and the seed they were laid for.
func save_state() -> Dictionary:
	return {"seed":seed_value if cells != null else SkyWorld.seed,"free":collected.keys(),"record":record.duplicate(true)}

## Takes a world's saved set pieces (`save_state`), or none for a new world;
## kept for another seed, they are left out.
func load_state(state: Dictionary) -> void:
	collected = {}
	record = {}
	if int(state.get("seed",SkyWorld.seed)) != SkyWorld.seed: return
	for id: Variant in state.get("free",[]): collected[str(id)] = true
	var saved: Variant = state.get("record",{})
	if saved is Dictionary:
		for key: Variant in saved:
			var r: Variant = saved[key]
			if r is Dictionary: record[str(key)] = {"tries":int(r.get("tries",0)),"best":int(r.get("best",0)),"done":int(r.get("done",0))}
	for key in stations:
		var s: Dictionary = stations[key]
		for i: int in (s.nodes as Dictionary).keys():
			var n: Variant = s.nodes[i]
			if collected.has("%s:%d" % [key,i]) and n is Node and is_instance_valid(n):
				(n as Node).queue_free()
				s.nodes.erase(i)
	for key in beacons: _show_armed(key)

# --- Finding them (debug) ----------------------------------------------------------------

## Every set piece with its distance from `eye` (islands' frame): [{index,
## key, name, mirror, turn, distance (m), done, free (taken), of}].
func list(eye: Vector3) -> Array:
	var out := []
	var home := eye-(cells.origin if cells != null else Vector3.ZERO)
	for k in range(placements.size()):
		var p: Dictionary = placements[k]
		var got := 0
		var of := 0
		for m: Dictionary in Plan.moments(int(p.layout)):
			if m.role != "free": continue
			of += 1
			if collected.has(_id(p,m)): got += 1
		out.append({"index":k,"key":p.key,"name":Plan.footprint(int(p.layout)).name,"mirror":p.mirror,"turn":p.turn,
			"distance":Vector2(p.box_at.x-home.x,p.box_at.z-home.z).length(),"done":int(_record(p.key).done),"free":got,"of":of})
	return out

## Where a hop to set piece `k` puts the plane: {position (islands'
## frame), heading}: HOP_OUT out along its way in, at its line's height,
## flying its line; empty if there is none.
func hop(k: int) -> Dictionary:
	if placements.is_empty(): return {}
	var p: Dictionary = placements[posmod(k,placements.size())]
	hopped = posmod(k,placements.size())
	var home := Plan.place(p,Vector3(0.0,0.0,HOP_OUT))
	_last = Vector3.INF
	return {"position":home+(cells.origin if cells != null else Vector3.ZERO),"heading":Plan.heading(p),"key":p.key}

## The next hop's set piece (`step` 1 the next, -1 the one before), its
## hop and a line saying where it is; the whole list printed.
func hop_next(eye: Vector3, step := 1) -> Dictionary:
	if placements.is_empty(): return {}
	var rows := list(eye)
	print("Moments set pieces (%d):" % rows.size())
	for r: Dictionary in rows:
		print("  %2d  %-16s  %5.0f m  free %d/%d  done %d  %s%s" % [r.index,r.name,r.distance,r.free,r.of,r.done,r.key," (mirrored)" if r.mirror else ""])
	var k := posmod(hopped+step,placements.size())
	var row: Dictionary = rows[k]
	var out := hop(k)
	if hud != null: hud.pop("Set piece %d/%d  ·  %s  ·  %.1f km" % [k+1,placements.size(),row.name,float(row.distance)/1000.0],2.5)
	return out

static func _flat_box(p: Dictionary, home: Vector3) -> float:
	return SkyWorld.box_distance(p,Vector2(home.x,home.z))
