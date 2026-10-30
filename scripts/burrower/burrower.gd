extends Node3D
## The burrower (docs/design/endless-flight/spec-burrower.md): something
## unseen moving under the turf. It is never drawn itself; what shows is the
## ground it heaves:
##
##   ridge  a strip laid on the ground along its path (shaders/
##          burrower_ridge.gdshader), each sample heaved by its age: a bow
##          rising ahead, the peak as it passes, a ring of follow-through,
##          then a low cracked scar that settles over SCAR_LIFE s. Built in
##          chunks of CHUNK samples; only the live one is rebuilt.
##   grass  GrassReact stamps along the path: parted out either side and
##          pressed, springing back after GRASS_HOLD.
##   clods  sod clods and pebbles kicked up from the head, falling back,
##          bouncing once, lying a moment and sinking (a MultiMesh).
##   dust   soft puffs that hang behind the head and thin out.
##
## On the pond the same thing is a wake with no boat (shaders/
## burrower_pond.gdshader): a bulge over the head, rings dropped from it
## every WAKE_DT s that add up to a V, froth on its track, spray thrown off
## the bulge and a mist; the ridge ends at the water's edge and starts again
## where it comes out.
##
## It moves with intent: a heading that turns smoothly (turn rate eased),
## a speed that surges and slows (SURGE), steering round the land's rocks,
## ruins and knoll (looked for ahead; the pond it crosses) and keeping to the meadow,
## passing beside trees (their trunks a small reach; roaming, it often makes
## for a tree's side) and shuddering them (scripts/burrower/tree_shudder.gd).
## Two ways to move: `lead(plane)` runs ahead of the plane to one side,
## sometimes drawing level as if racing; `roam()` wanders the meadow alone
## (the watch camera's). `dive()` sinks it away.

const Land = preload("res://scripts/burrower/burrower_land.gd")
const GrassReact = preload("res://scripts/endless/grass_react.gd")
const RIDGE_SHADER = preload("res://shaders/burrower_ridge.gdshader")
const DUST_SHADER = preload("res://shaders/burrower_dust.gdshader")
const TreeShudder = preload("res://scripts/burrower/tree_shudder.gd")

## The ridge: a sample every SAMPLE m, ACROSS vertices across HALF_W m each
## side, CHUNK samples to a mesh, the bow drawn NOSE samples ahead; the scar
## lasts SCAR_LIFE s (the shader's `life`).
const SAMPLE := 0.6
const ACROSS := 11
const HALF_W := 2.3
const CHUNK := 32
const NOSE := 6
const BOW := 0.24
const SCAR_LIFE := 26.0
## Lies this far over the ground mesh (no z-fight at its rest).
const LIFT := 0.03
## Moving: base speeds (m/s) roaming, the most it turns (rad/s) and how fast
## its turning changes (rad/sÂ²), its speed's ease (m/sÂ²), how far ahead it
## looks for things to steer round (s of travel, at least m), the margin it
## keeps from them (m).
const ROAM_SPEED := 17.0
const MAX_TURN := 1.1
const TURN_EASE := 2.2
const ACCEL := 14.0
const LOOK_S := 0.9
const LOOK_M := 10.0
const MARGIN := 6.0
## A trunk's reach: kept small, so it passes beside a tree (the shudder's
## reach is 15 m), and how often a roam goal is a tree's side.
const TRUNK := 0.5
const TREE_GOAL := 0.55
## A trunk is pushed off only close in: within TRUNK_MARGIN+TRUNK_RAMP m.
const TRUNK_MARGIN := 2.5
const TRUNK_RAMP := 4.0
## Its surge: speed times 1 + SURGE * a slow noise, and now and then a burst.
const SURGE := 0.28
## Leading the plane: how far ahead (m, a slow noise between) and to the side.
const LEAD_AHEAD := Vector2(10.0,62.0)
const LEAD_SIDE := Vector2(7.0,16.0)
## Grass: a stamp every GRASS_STEP m, its reach (m), push and hold (s).
const GRASS_STEP := 1.5
const GRASS_REACH := 3.4
const GRASS_PUSH := 2.6
const GRASS_HOLD := 2.2
## Clods: at most CLODS alive, kicked at CLOD_RATE a second at full speed.
const CLODS := 360
const CLOD_RATE := 34.0
const GRAVITY := 14.0
## Dust: at most DUSTS puffs, DUST_RATE a second, living DUST_LIFE s.
const DUSTS := 160
const DUST_RATE := 9.0
const DUST_LIFE := 2.8

const SOD := Color("4c5a2c")
const SOIL := Color("4a3826")
const PEBBLE := Color("8e877a")
const DUST := Color(0.36,0.31,0.24)
## Water: wet where the bed lies WET_DEEP m under the water; a wake point
## every WAKE_DT s (the shader holds WAKES); spray, at most SPRAYS drops,
## SPRAY_RATE a second at full speed, a burst of SPLASH going in.
const WET_DEEP := 0.15
const WAKES := 64
const WAKE_DT := 0.07
const SPRAYS := 420
const SPRAY_RATE := 90.0
const SPLASH := 70
const SPRAY := Color(0.86,0.92,0.95,0.85)
const MIST := Color(0.80,0.85,0.87)
## How often a roam goal is the pond's far side.
const POND_GOAL := 0.3

var land: Land
var react: GrassReact
var time := 0.0
## Under way (moving and heaving), and how hard: 0 sunk, 1 at the turf.
var active := false
var strength := 0.0
var pos := Vector2.ZERO
var heading := 0.0
var speed := 0.0
var mode := &"roam"
var stats := {"samples": 0, "chunks": 0, "clods": 0, "dust": 0, "stamps": 0, "nearest": INF,
	"wakes": 0, "spray": 0, "splashes": 0, "wet_time": 0.0}
## In the water now, and the wake's ease in (0 on land, 1 in the water).
var wet := false
var wet_k := 0.0

var _plane: Object
var _turn := 0.0
var _goal := Vector2.ZERO
var _side := 1.0
var _diving := false
var _run := 0.0
var _noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _obstacles: Array = []
var shudder: TreeShudder
var _samples: Array = []
var _since_sample := 0.0
var _since_stamp := 0.0
var _chunks: Array = []
var _live: MeshInstance3D
var _ridge_mat := ShaderMaterial.new()
var _clods: Array = []
var _clod_mm := MultiMesh.new()
var _clod_carry := 0.0
var _dusts: Array = []
var _dust_mm := MultiMesh.new()
var _dust_carry := 0.0
var _wake := PackedVector4Array()
var _wake_i := 0
var _since_wake := 0.0
var _sprays: Array = []
var _spray_mm := MultiMesh.new()
var _spray_carry := 0.0

func _init() -> void:
	name = "Burrower"

func setup(the_land: Land, the_react: GrassReact) -> void:
	land = the_land
	react = the_react
	_noise.seed = 5
	_noise.frequency = 0.35
	_rng.seed = 41
	for r: Dictionary in land.rocks + land.ruins:
		_obstacles.append({"at": r.at, "reach": float(r.reach)})
	_obstacles.append({"at": Land.KNOLL, "reach": Land.KNOLL_R*0.85})
	for tree: Node3D in land.trees:
		_obstacles.append({"at": Vector2(tree.position.x,tree.position.z), "reach": TRUNK, "margin": TRUNK_MARGIN, "ramp": TRUNK_RAMP, "tree": true})
	shudder = TreeShudder.new()
	shudder.setup(land)
	add_child(shudder)
	_ridge_mat.shader = RIDGE_SHADER
	_ridge_mat.set_shader_parameter("life",SCAR_LIFE)
	_ridge_mat.set_shader_parameter("bow",BOW)
	_live = MeshInstance3D.new()
	_live.name = "RidgeLive"
	_live.material_override = _ridge_mat
	add_child(_live)
	var lump := SphereMesh.new()
	lump.radius = 0.5
	lump.height = 0.8
	lump.radial_segments = 6
	lump.rings = 3
	var clod_m := StandardMaterial3D.new()
	clod_m.vertex_color_use_as_albedo = true
	clod_m.vertex_color_is_srgb = true
	clod_m.roughness = 1.0
	lump.material = clod_m
	_clod_mm.transform_format = MultiMesh.TRANSFORM_3D
	_clod_mm.use_colors = true
	_clod_mm.mesh = lump
	_clod_mm.instance_count = CLODS
	_clod_mm.visible_instance_count = 0
	var clods := MultiMeshInstance3D.new()
	clods.name = "Clods"
	clods.multimesh = _clod_mm
	add_child(clods)
	var quad := QuadMesh.new()
	var dust_m := ShaderMaterial.new()
	dust_m.shader = DUST_SHADER
	quad.material = dust_m
	_dust_mm.transform_format = MultiMesh.TRANSFORM_3D
	_dust_mm.use_custom_data = true
	_dust_mm.mesh = quad
	_dust_mm.instance_count = DUSTS
	_dust_mm.visible_instance_count = 0
	var dusts := MultiMeshInstance3D.new()
	dusts.name = "Dust"
	dusts.multimesh = _dust_mm
	dusts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dusts)
	var drop := SphereMesh.new()
	drop.radius = 0.5
	drop.height = 1.0
	drop.radial_segments = 6
	drop.rings = 3
	var drop_m := StandardMaterial3D.new()
	drop_m.vertex_color_use_as_albedo = true
	drop_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop.material = drop_m
	_spray_mm.transform_format = MultiMesh.TRANSFORM_3D
	_spray_mm.use_colors = true
	_spray_mm.mesh = drop
	_spray_mm.instance_count = SPRAYS
	_spray_mm.visible_instance_count = 0
	var sprays := MultiMeshInstance3D.new()
	sprays.name = "Spray"
	sprays.multimesh = _spray_mm
	sprays.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprays)
	_wake.resize(WAKES)
	_wake.fill(Vector4.ZERO)

## Up under the turf at `at` heading `way` (rad, 0 along +x), leading `plane`
## (null: roaming the meadow).
func wake(at: Vector2, way: float, plane: Object = null) -> void:
	_finish_live()
	pos = at
	heading = way
	_turn = 0.0
	_plane = plane
	mode = &"lead" if plane != null else &"roam"
	_side = -1.0 if _rng.randf() < 0.5 else 1.0
	speed = _plane_speed() if plane != null else ROAM_SPEED
	strength = 0.0
	active = true
	_diving = false
	_run = 0.0
	_goal = _roam_goal()
	_since_sample = SAMPLE
	wet = _wet_at(pos)

## Up a little ahead of `plane` to one side, leading it.
func lead(plane: Object) -> void:
	var p: Vector3 = plane.position
	var f: Vector3 = plane.forward()
	var fwd := Vector2(f.x,f.z).normalized()
	if fwd == Vector2.ZERO: fwd = Vector2(0,-1)
	var side := Vector2(-fwd.y,fwd.x)*(-1.0 if _rng.randf() < 0.5 else 1.0)
	var at := Vector2(p.x,p.z)+fwd*42.0+side*11.0
	wake(at,fwd.angle(),plane)
	_side = signf(side.dot(Vector2(-fwd.y,fwd.x)))

## On its own from here: wandering the meadow, the plane left be.
func roam() -> void:
	mode = &"roam"
	_plane = null
	_goal = _roam_goal()

## Sinks away: the head eases down, the trail settles on.
func dive() -> void:
	if active: _diving = true

## Sinking away (dive() called, not yet down).
func diving() -> bool:
	return active and _diving

func forward() -> Vector2:
	return Vector2(cos(heading),sin(heading))

## The head on the ground (world).
func head() -> Vector3:
	return Vector3(pos.x,land.height(pos.x,pos.y),pos.y)

func _plane_speed() -> float:
	if _plane == null: return ROAM_SPEED
	var v: Vector3 = _plane.velocity
	return maxf(Vector2(v.x,v.z).length(),8.0)

func _wet_at(p: Vector2) -> bool:
	return land.height(p.x,p.y) < Land.WATER_Y-WET_DEEP

func _roam_goal() -> Vector2:
	# Now and then across the pond: a point past its far side, in the meadow.
	if _rng.randf() < POND_GOAL and pos.distance_to(Land.POND) > Land.POND_R+15.0:
		var across := (Land.POND-pos).normalized()
		for i in 6:
			var g := Land.POND+across.rotated(_rng.randf_range(-0.7,0.7))*(Land.POND_R+_rng.randf_range(12.0,24.0))
			if g.length() < Land.MEADOW_R-35.0: return g
	# Often past a tree's side: a point beside it, so the way runs by it.
	if not land.trees.is_empty() and _rng.randf() < TREE_GOAL:
		for i in 8:
			var tree: Node3D = land.trees[_rng.randi() % land.trees.size()]
			var at := Vector2(tree.position.x,tree.position.z)
			if at.distance_to(pos) < 45.0: continue
			var side := (at-pos).normalized().orthogonal()*(-1.0 if _rng.randf() < 0.5 else 1.0)
			var g := at+side*_rng.randf_range(7.0,10.0)+(at-pos).normalized()*18.0
			if g.length() < Land.MEADOW_R-35.0: return g
	for i in 20:
		var g := Vector2(_rng.randf_range(-140.0,140.0),_rng.randf_range(-140.0,140.0))
		if g.length() > 150.0 or g.distance_to(pos) < 50.0: continue
		var clear := true
		for o: Dictionary in _obstacles:
			if not o.has("tree") and g.distance_to(o.at) < float(o.reach)+MARGIN*2.0: clear = false
		if clear: return g
	return -pos.normalized()*60.0

func tick(delta: float) -> void:
	time += delta
	_ridge_mat.set_shader_parameter("now",time)
	if active: _move(delta)
	_step_clods(delta)
	_step_dust(delta)
	_step_spray(delta)
	shudder.tick(delta,pos,strength if active and not wet else 0.0)
	wet_k = move_toward(wet_k,1.0 if active and wet else 0.0,delta/0.25)
	_feed_pond()
	_drop_old_chunks()
	if active or not _samples.is_empty(): _rebuild_live()

func _move(delta: float) -> void:
	_run += delta
	var target := 0.0 if _diving else 1.0
	strength = move_toward(strength,target,delta/(1.1 if _diving else 0.5))
	if _diving and strength <= 0.0:
		active = false
		_finish_live()
		return
	var surge := 1.0+SURGE*_noise.get_noise_1d(time)
	# A burst now and then: the noise's peaks pushed harder.
	surge += 0.35*maxf(_noise.get_noise_1d(time*0.6+300.0)-0.25,0.0)/0.75
	var want_speed := ROAM_SPEED*surge
	if mode == &"lead" and _plane != null:
		var p: Vector3 = _plane.position
		var f: Vector3 = _plane.forward()
		var fwd := Vector2(f.x,f.z).normalized()
		var side := Vector2(-fwd.y,fwd.x)
		var ahead := lerpf(LEAD_AHEAD.x,LEAD_AHEAD.y,clampf(0.5+1.1*_noise.get_noise_1d(time*0.45+100.0),0.0,1.0))
		var off := lerpf(LEAD_SIDE.x,LEAD_SIDE.y,clampf(0.5+1.0*_noise.get_noise_1d(time*0.3+200.0),0.0,1.0))
		# Its slot by the plane sets the speed; it steers for a point on
		# along the plane's way from there (else it would turn back for a
		# slot it had overrun).
		var slot := Vector2(p.x,p.z)+fwd*ahead+side*_side*off
		var behind := (slot-pos).dot(fwd)
		var vp := _plane_speed()
		want_speed = clampf(vp*surge+behind*1.1,vp*0.5,vp*1.8)
		_goal = slot+fwd*maxf(speed*0.9,20.0)
	elif pos.distance_to(_goal) < 18.0:
		_goal = _roam_goal()
	var dir := (_goal-pos).normalized()
	# Steering round what lies ahead and keeping to the meadow.
	var look := maxf(LOOK_M,speed*LOOK_S)
	var ahead_at := pos+forward()*look
	var nearest := INF
	for o: Dictionary in _obstacles:
		var r := float(o.reach)+float(o.get("margin",MARGIN))
		var ramp := float(o.get("ramp",12.0))
		for probe: Vector2 in [pos,pos+forward()*look*0.5,ahead_at]:
			var d := probe.distance_to(o.at)
			nearest = minf(nearest,pos.distance_to(o.at)-float(o.reach))
			if d < r+ramp:
				var away := (probe-(o.at as Vector2)).normalized()
				# Round the side it is already going.
				var tang := Vector2(-away.y,away.x)
				if tang.dot(forward()) < 0.0: tang = -tang
				var w := clampf(1.0-(d-r)/ramp,0.0,1.6)
				dir += (away*0.9+tang*0.6)*w*1.8
	stats.nearest = minf(float(stats.nearest),nearest)
	var rim := Land.MEADOW_R-28.0
	if pos.length() > rim: dir += -pos.normalized()*clampf((pos.length()-rim)/12.0,0.0,2.0)*2.0
	var want := angle_difference(heading,dir.angle())
	var rate := clampf(want*2.4,-MAX_TURN,MAX_TURN)
	_turn = move_toward(_turn,rate,TURN_EASE*delta)
	heading = wrapf(heading+_turn*delta,-PI,PI)
	speed = move_toward(speed,want_speed,ACCEL*delta)
	var step := speed*delta
	pos += forward()*step
	var now_wet := _wet_at(pos)
	if now_wet != wet:
		wet = now_wet
		# The ridge ends at the water and starts again where it comes out.
		_finish_live()
		_since_sample = SAMPLE
		_splash(SPLASH if wet else SPLASH/2)
	_since_sample += step
	_since_stamp += step
	if wet:
		stats.wet_time = float(stats.wet_time)+delta
		_since_wake += delta
		if _since_wake >= WAKE_DT:
			_since_wake = 0.0
			_drop_wake(pos,strength*clampf(speed/ROAM_SPEED,0.7,1.4))
	else:
		if _since_sample >= SAMPLE:
			_since_sample = 0.0
			# A surge heaves harder.
			_add_sample(pos,strength*clampf(1.0+0.7*(surge-1.0),0.7,1.35))
		if _since_stamp >= GRASS_STEP:
			_since_stamp = 0.0
			_stamp_grass()
	_kick(delta)

# --- The ridge -------------------------------------------------------------------

func _add_sample(at: Vector2, k: float) -> void:
	stats.samples = int(stats.samples)+1
	_samples.append(_sample(at,forward(),time,k))
	if _samples.size() > CHUNK:
		var mesh := _strip(_samples,[])
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.material_override = _ridge_mat
		node.set_meta("dies",time+SCAR_LIFE+1.0)
		add_child(node)
		_chunks.append(node)
		stats.chunks = _chunks.size()
		_samples = [_samples.back()]

func _sample(at: Vector2, way: Vector2, born: float, k: float) -> Dictionary:
	var side := Vector2(-way.y,way.x)
	var hw := HALF_W*(0.85+0.3*k)
	var ys := PackedFloat32Array()
	var cols := PackedColorArray()
	var nms := PackedVector3Array()
	for c in ACROSS:
		var u := -1.0+2.0*c/(ACROSS-1)
		var p := at+side*u*hw
		var nm := land.normal(p.x,p.y)
		var y := land.mesh_height(p.x,p.y)
		ys.append(y+LIFT)
		nms.append(nm)
		cols.append(land.colour(p.x,p.y,land.height(p.x,p.y),nm))
	return {"at": at, "side": side, "born": born, "k": k, "hw": hw, "ys": ys, "cols": cols, "nms": nms}

## The live chunk: the samples since the last whole chunk, the head and the
## bow ahead of it (born in the future, rising).
func _rebuild_live() -> void:
	var extra: Array = []
	if active and strength > 0.0 and not wet:
		extra.append(_sample(pos,forward(),time,strength))
		var bow_len := BOW*maxf(speed,4.0)
		for i in range(1,NOSE+1):
			var d := bow_len*float(i)/NOSE
			var at := pos+forward()*d
			# The bow stops at the water's edge.
			if _wet_at(at): break
			extra.append(_sample(at,forward(),time+d/maxf(speed,4.0),strength))
	if _samples.size()+extra.size() < 2:
		_live.mesh = null
		return
	_live.mesh = _strip(_samples,extra)

func _finish_live() -> void:
	if _samples.size() >= 2:
		var node := MeshInstance3D.new()
		node.mesh = _strip(_samples,[])
		node.material_override = _ridge_mat
		node.set_meta("dies",time+SCAR_LIFE+1.0)
		add_child(node)
		_chunks.append(node)
	_samples = []
	_live.mesh = null

func _drop_old_chunks() -> void:
	while not _chunks.is_empty() and time > float((_chunks[0] as Node).get_meta("dies")):
		(_chunks.pop_front() as Node).queue_free()
	stats.chunks = _chunks.size()

func _strip(a: Array, b: Array) -> ArrayMesh:
	var rows: Array = a+b
	var n := rows.size()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var colours := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	for s: Dictionary in rows:
		var at: Vector2 = s.at
		var side: Vector2 = s.side
		var hw: float = s.hw
		var ys: PackedFloat32Array = s.ys
		for c in ACROSS:
			var u := -1.0+2.0*c/(ACROSS-1)
			var p := at+side*u*hw
			verts.append(Vector3(p.x,ys[c],p.y))
			normals.append(s.nms[c])
			tangents.append_array([side.x,0.0,side.y,1.0])
			colours.append(s.cols[c])
			uv.append(Vector2(u,hw))
			uv2.append(Vector2(float(s.born),float(s.k)))
	var index := PackedInt32Array()
	for r in n-1:
		for c in ACROSS-1:
			var i0 := r*ACROSS+c
			var i1 := i0+ACROSS
			# Clockwise from above (Godot's front face, as the ground's).
			index.append_array([i0,i1,i0+1,i0+1,i1,i1+1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	# The heave lifts it past the ground's box: room for it.
	mesh.custom_aabb = _box(verts).grow(1.5)
	return mesh

func _box(verts: PackedVector3Array) -> AABB:
	var box := AABB(verts[0],Vector3.ZERO)
	for v in verts: box = box.expand(v)
	return box

# --- The grass -------------------------------------------------------------------

func _stamp_grass() -> void:
	if react == null or strength <= 0.05: return
	var overlap := maxf(2.0*GRASS_REACH/GRASS_STEP,1.0)
	stats.stamps = int(stats.stamps)+1
	react._add({"at": pos, "way": forward()*0.25, "strength": GRASS_PUSH*strength*2.2/overlap*3.0,
		"swirl": 0.0, "reach": GRASS_REACH*(0.85+0.3*strength), "front": 0.0, "hold": GRASS_HOLD, "press": 1.0})

# --- Clods and pebbles -----------------------------------------------------------

func _kick(delta: float) -> void:
	var pace := clampf(speed/ROAM_SPEED,0.4,1.6)
	if wet:
		_spray_carry += SPRAY_RATE*strength*pace*delta
		while _spray_carry >= 1.0:
			_spray_carry -= 1.0
			_spawn_drop(false)
	else:
		_clod_carry += CLOD_RATE*strength*pace*delta
		while _clod_carry >= 1.0:
			_clod_carry -= 1.0
			_spawn_clod()
	_dust_carry += DUST_RATE*strength*clampf(speed/ROAM_SPEED,0.5,1.4)*delta*(1.6 if wet else 1.0)
	while _dust_carry >= 1.0:
		_dust_carry -= 1.0
		_spawn_dust()

func _spawn_clod() -> void:
	if _clods.size() >= CLODS: _clods.pop_front()
	var side := Vector2(-forward().y,forward().x)
	var u := _rng.randf_range(-1.0,1.0)
	var at := pos-forward()*_rng.randf_range(0.0,2.5)+side*u*1.2
	var kind := _rng.randf()
	var colour := SOD if kind < 0.45 else (SOIL if kind < 0.8 else PEBBLE)
	colour = colour.lerp(Color.BLACK,_rng.randf()*0.25)
	var size := _rng.randf_range(0.14,0.42)*(0.6 if kind >= 0.8 else 1.0)*(0.7+0.5*strength)
	var out := side*signf(u if u != 0.0 else 1.0)*_rng.randf_range(1.5,4.5)
	var fwd := forward()*speed*_rng.randf_range(0.05,0.3)
	var v := Vector3(out.x+fwd.x,_rng.randf_range(3.0,7.5)*strength,out.y+fwd.y)
	_clods.append({"p": Vector3(at.x,land.height(at.x,at.y)+0.3,at.y), "v": v,
		"spin": Vector3(_rng.randf_range(-1,1),_rng.randf_range(-1,1),_rng.randf_range(-1,1)).normalized(),
		"rate": _rng.randf_range(4.0,14.0), "turn": 0.0, "size": size, "colour": colour,
		"bounced": false, "rest": -1.0, "squash": Vector3(_rng.randf_range(0.8,1.3),_rng.randf_range(0.6,1.0),_rng.randf_range(0.8,1.2))})

func _step_clods(delta: float) -> void:
	var i := 0
	while i < _clods.size():
		var c: Dictionary = _clods[i]
		var p: Vector3 = c.p
		var ground := land.height(p.x,p.z)
		if float(c.rest) < 0.0:
			var v: Vector3 = c.v
			v.y -= GRAVITY*delta
			v *= 1.0-0.3*delta
			p += v*delta
			c.turn = float(c.turn)+float(c.rate)*delta
			if p.y < ground+float(c.size)*0.3 and v.y < 0.0:
				p.y = ground+float(c.size)*0.3
				if not c.bounced and v.y < -2.0:
					c.bounced = true
					v = Vector3(v.x*0.45,-v.y*0.3,v.z*0.45)
					c.rate = float(c.rate)*0.5
				else:
					c.rest = 0.0
					v = Vector3.ZERO
			c.v = v
		else:
			c.rest = float(c.rest)+delta
			# Lying a moment, then sinking into the grass.
			if float(c.rest) > 1.6: p.y -= delta*0.35
			if float(c.rest) > 3.2:
				_clods.remove_at(i)
				continue
		c.p = p
		i += 1
	var n := _clods.size()
	_clod_mm.visible_instance_count = n
	for k in n:
		var c: Dictionary = _clods[k]
		var b := Basis(c.spin,float(c.turn)).scaled(Vector3(c.squash)*float(c.size)*2.0)
		_clod_mm.set_instance_transform(k,Transform3D(b,c.p))
		_clod_mm.set_instance_color(k,c.colour)
	stats.clods = n

# --- Dust ------------------------------------------------------------------------

func _spawn_dust() -> void:
	if _dusts.size() >= DUSTS: _dusts.pop_front()
	var side := Vector2(-forward().y,forward().x)
	var at := pos-forward()*_rng.randf_range(0.5,3.0)+side*_rng.randf_range(-1.0,1.0)
	var drift := forward()*speed*0.12+side*_rng.randf_range(-1.2,1.2)
	var y := Land.WATER_Y+0.5 if wet else land.height(at.x,at.y)+0.4
	_dusts.append({"p": Vector3(at.x,y,at.y), "v": Vector3(drift.x,_rng.randf_range(0.6,1.4)*(1.5 if wet else 1.0),drift.y),
		"age": 0.0, "life": DUST_LIFE*_rng.randf_range(0.7,1.3)*(0.7 if wet else 1.0), "size": _rng.randf_range(0.6,1.1)*(1.3 if wet else 1.0),
		"shade": _rng.randf_range(0.85,1.1), "colour": MIST if wet else DUST, "most": 0.22 if wet else 0.2})

func _step_dust(delta: float) -> void:
	var i := 0
	while i < _dusts.size():
		var d: Dictionary = _dusts[i]
		d.age = float(d.age)+delta
		if float(d.age) >= float(d.life):
			_dusts.remove_at(i)
			continue
		var v: Vector3 = d.v
		v *= 1.0-1.6*delta
		v.y = maxf(v.y,0.15)
		d.v = v
		d.p = Vector3(d.p)+v*delta
		i += 1
	var n := _dusts.size()
	_dust_mm.visible_instance_count = n
	for k in n:
		var d: Dictionary = _dusts[k]
		var t := float(d.age)/float(d.life)
		var s := float(d.size)*(1.0+2.6*sqrt(t))
		_dust_mm.set_instance_transform(k,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*s),d.p))
		var a := smoothstep(0.0,0.08,t)*(1.0-smoothstep(0.2,1.0,t))*float(d.most)
		var c: Color = (d.colour as Color)*float(d.shade)
		_dust_mm.set_instance_custom_data(k,Color(c.r,c.g,c.b,a))
	stats.dust = n

# --- The wake --------------------------------------------------------------------

func _drop_wake(at: Vector2, k: float) -> void:
	_wake[_wake_i] = Vector4(at.x,at.y,time,k)
	_wake_i = (_wake_i+1) % WAKES
	stats.wakes = int(stats.wakes)+1

## Going in or coming out: a ring and a burst of spray.
func _splash(n: int) -> void:
	stats.splashes = int(stats.splashes)+1
	_drop_wake(pos,1.6*maxf(strength,0.5))
	for i in n: _spawn_drop(true)

func _feed_pond() -> void:
	var m := land.pond_material
	if m == null: return
	m.set_shader_parameter("now",time)
	m.set_shader_parameter("wake",_wake)
	m.set_shader_parameter("head",Vector4(pos.x,pos.y,strength*wet_k,speed))
	m.set_shader_parameter("head_way",forward())

## A drop thrown off the bulge: most out to the sides and up, some in a
## plume left behind the head; `burst` a splash's, flung every way.
func _spawn_drop(burst: bool) -> void:
	if _sprays.size() >= SPRAYS: _sprays.pop_front()
	var fwd := forward()
	var side := Vector2(-fwd.y,fwd.x)
	var at: Vector2
	var v: Vector3
	if burst:
		var a := _rng.randf()*TAU
		var out := Vector2(cos(a),sin(a))
		at = pos+out*_rng.randf_range(0.3,2.0)
		var h := out*_rng.randf_range(1.0,5.0)+fwd*speed*0.25
		v = Vector3(h.x,_rng.randf_range(4.0,10.0),h.y)
	elif _rng.randf() < 0.3:
		at = pos-fwd*_rng.randf_range(1.5,4.5)+side*_rng.randf_range(-0.6,0.6)
		var h := fwd*speed*_rng.randf_range(0.1,0.3)+side*_rng.randf_range(-0.8,0.8)
		v = Vector3(h.x,_rng.randf_range(5.0,10.0)*strength,h.y)
	else:
		var u := _rng.randf_range(-1.0,1.0)
		var sgn := signf(u) if u != 0.0 else 1.0
		at = pos+fwd*_rng.randf_range(-1.5,1.5)+side*(sgn*1.2+u)
		var h := side*sgn*_rng.randf_range(2.0,6.0)+fwd*speed*_rng.randf_range(0.2,0.55)
		v = Vector3(h.x,_rng.randf_range(2.5,7.0)*strength,h.y)
	_sprays.append({"p": Vector3(at.x,Land.WATER_Y+0.3,at.y), "v": v, "size": _rng.randf_range(0.05,0.14)})

func _step_spray(delta: float) -> void:
	var i := 0
	while i < _sprays.size():
		var d: Dictionary = _sprays[i]
		var v: Vector3 = d.v
		v.y -= GRAVITY*delta
		v *= 1.0-0.9*delta
		var p: Vector3 = (d.p as Vector3)+v*delta
		if p.y < Land.WATER_Y and v.y < 0.0:
			_sprays.remove_at(i)
			continue
		d.v = v
		d.p = p
		i += 1
	var n := _sprays.size()
	_spray_mm.visible_instance_count = n
	for k in n:
		var d: Dictionary = _sprays[k]
		var v: Vector3 = d.v
		var size := float(d.size)
		# Drawn as a streak along its flight.
		var up := v.normalized() if v.length() > 0.1 else Vector3.UP
		var x := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
		var z := x.cross(up)
		var stretch := 1.0+v.length()*0.12
		_spray_mm.set_instance_transform(k,Transform3D(Basis(x*size,up*size*stretch,z*size),d.p))
		_spray_mm.set_instance_color(k,SPRAY)
	stats.spray = n
