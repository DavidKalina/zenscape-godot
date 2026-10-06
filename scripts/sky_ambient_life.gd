extends Node3D
## The other islands' life, seen from the air (scripts/sky_islands.gd): only
## the plate is live, and its creatures (LandLife's gulls, the songbirds in
## its trees, the wind's chaff on its meadow) live on it alone. Every island
## near the glide gets a light stand-in of them, so flying among the islands
## each looks lived on:
##
## - the gulls, two to five, ride thermals over its trees and its middle as
##   LandLife's do over the plate (in the same columns, as high), wheeling
##   wider and climbing when the glide comes close;
## - a songbird flock sits unseen in its biggest crown and bursts out of it
##   as the glide passes, wheels over the grove in the bounding flap-and-
##   glide of small birds and drops back in;
## - chaff lifts off its meadow and drifts away downwind.
##
## Each is the real creature's own mesh and material (the Fidelity gull,
## flapping in its shader on its custom data; the songbird's carved body,
## spread and folded; the chaff blade), drawn as MultiMesh batches, four
## draws an island. Nothing here thinks: every position is a closed form of
## the island's clock (a circle, a wheel, a drift), worked out for the few
## dozen instances once a frame. At most CAP islands within RADIUS of the
## glide have it, the nearest; an island coming in is stood up within the
## sky's frame share (scripts/sky_commits.gd).
##
## At a claim (SkyIslands `claim`) the life hands over without a jump: the
## island left takes the plate's gulls where they were flying (`leave`), and
## eases them into its own circles; the island claimed keeps its stand-ins
## through the swap, now over the plate, and lets each gull go, up and away,
## as LandLife's own come in (`handover`), its chaff as the plate's own lies
## there already.

const SkyCommits = preload("res://scripts/sky_commits.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const Songbird = preload("res://scripts/songbird_body.gd")
const Chaff = preload("res://scripts/wind_grass_chaff.gd")
const LeafMesh = preload("res://scripts/leaf_litter_mesh.gd")

## Islands within this of the glide (m, to their middle) have life, at most
## CAP of them, the nearest.
const RADIUS := 300.0
const CAP := 3
## Past this an island's life is let go at once (its share of RADIUS is
## hysteresis, so one at the edge does not come and go).
const RELEASE := 340.0
## Seconds an island's life takes to come in or go.
const FADE := 1.5
## Gulls: how many (two, plus one per GULL_TREES trees, at most GULLS_MAX),
## their size (the source flock's), speed (m/s), circle radius (m), and how
## high over the ground under the column they ride (m), as LandLife's.
const GULLS_MIN := 2
const GULLS_MAX := 5
const GULL_TREES := 2
const GULL_SIZE := Vector2(0.28,0.34)
const GULL_SPEED := Vector2(3.6,4.6)
const GULL_RADIUS := Vector2(3.2,6.5)
const GULL_HIGH := Vector2(9.0,13.0)
## The glide this near a column (m) stirs its gulls: wider and higher.
const STIR_NEAR := 45.0
const STIR_WIDE := 0.9
const STIR_CLIMB := 6.0
## The songbird flock: how many, their size (the real ones', SIZE), the
## glide this near the grove (m) flushes it, and it is ready to again once
## the glide is this far off; seconds out (bursting, wheeling, settling).
const FLOCK := 8
const FLUSH_NEAR := 38.0
const REARM := 90.0
const BURST := 1.2
const WHEEL := 7.0
const SETTLE := 1.6
## Bounding flight: wingbeat bursts a second and the share of each spent
## with the wings out.
const BOUNDS := 1.7
const BOUND_OUT := 0.62
## Chaff: blades an island, their size (the real chaff's), seconds each
## drifts, and how far and high it is carried at full wind (m).
const CHAFF := 18
const CHAFF_LIFE := Vector2(5.0,9.0)
const CHAFF_RUN := Vector2(2.0,7.0)
const CHAFF_RISE := Vector2(0.8,2.6)
## Small things are drawn only this near (m), fading over the margin.
const FLOCK_FAR := 120.0
const CHAFF_FAR := 75.0
const FAR_MARGIN := 20.0
## Each island's batches' box round its middle (m): wide and tall enough
## for every creature on it.
const BOX := Vector3(70.0,50.0,70.0)
## At a claim: the plate's gulls handed to the island left ease from where
## they flew into their circles over this long (s); the claimed island's
## gulls go as LandLife's come in, or after HANDOVER_MOST s, each over
## GULL_LEAVE s.
const LEAVE_BLEND := 4.0
const HANDOVER_MOST := 6.0
const GULL_LEAVE := 2.5

var islands: Node3D
## RADIUS, RELEASE and CAP, for probes and tests to widen.
var radius := RADIUS
var release := RELEASE
var cap := CAP
## Each island's life, by its home key: a Host.
var hosts := {}
## Microseconds the last `advance` took, and the worst so far.
var last_usec := 0
var worst_usec := 0
var _clock := 0.0
var _gull_mesh: Mesh
static var _flock_meshes := {}

## One island's life: its batches and what moves on them.
class Host extends Node3D:
	var home := Vector3.ZERO
	var key := ""
	## 0..1, and where it is easing to.
	var fade := 0.0
	var fade_to := 1.0
	## Handing over at a claim: seconds since the swap (-1 not).
	var handing := -1.0
	var gulls: Array[Dictionary] = []
	var columns: Array[Vector3] = []
	var stir := 0.0
	## The grove's crown middle and radius (plate space), and the flock.
	var grove := Vector3.INF
	var crown := 2.0
	var flock: Array[Dictionary] = []
	var flushed := -1.0
	var armed := true
	var chaff: Array[Dictionary] = []
	var gull_batch: MultiMesh
	var spread_batch: MultiMesh
	var folded_batch: MultiMesh
	var chaff_batch: MultiMesh
	## The plate-space middle of its land.
	var middle := Vector3.ZERO
	## For probes and tests: each gull's, bird's and blade's last position
	## (plate space) and scale, as drawn.
	var shown: Dictionary = {"gulls":[],"flock":[],"chaff":[]}

func setup(owner: Node3D) -> void:
	islands = owner
	name = "AmbientLife"
	# The flocks' and the chaff's meshes made as the world opens, never mid-glide.
	for species: String in Songbird.SPECIES:
		for out in [true,false]: flock_mesh(species,out)
	_chaff_mesh()
	# And the songbird's material drawn once, out of sight: the first island
	# whose flock stood up held a frame for 5 ms making it.
	var warm := MultiMeshInstance3D.new()
	warm.name = "Warm"
	warm.multimesh = MultiMesh.new()
	warm.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	warm.multimesh.mesh = flock_mesh(Songbird.SPECIES.keys()[0],true)
	warm.multimesh.instance_count = 1
	warm.multimesh.set_instance_transform(0,Transform3D(Basis.from_scale(Vector3.ONE*0.00001),Vector3(0,-500,0)))
	warm.material_override = Songbird.material()
	warm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(warm)

## The gull mesh, from LandLife's flock (the Fidelity source gull, its
## material flapping on custom data), or none without LandLife.
func _gulls_source() -> Mesh:
	if _gull_mesh != null: return _gull_mesh
	var life: Variant = islands.scene.get("land_life")
	if life == null: return null
	var node: Variant = life.get("_bird_node")
	if node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh != null: _gull_mesh = (node as MultiMeshInstance3D).multimesh.mesh
	return _gull_mesh

## A songbird species' body, head and wings in one mesh, its wings spread
## (`out`) or folded, at the real bird's own size and shape.
static func flock_mesh(species: String, out: bool) -> Mesh:
	var key := "%s %s" % [species,out]
	if _flock_meshes.has(key): return _flock_meshes[key]
	var parts: Dictionary = Songbird.meshes_for(species)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.append_from(parts.body,0,Transform3D.IDENTITY)
	tool.append_from(parts.head,0,Transform3D(Basis.IDENTITY,Songbird.HEAD_AT))
	var wings: Array = parts.spread if out else parts.folded
	for i in range(2):
		var side := -1.0 if i == 0 else 1.0
		tool.append_from(wings[i],0,Transform3D(Basis.IDENTITY,Vector3(Songbird.SHOULDER.x*side,Songbird.SHOULDER.y,Songbird.SHOULDER.z)))
	var mesh := tool.commit()
	_flock_meshes[key] = mesh
	return mesh

## Each frame of the glide, from SkyIslands `advance`: which islands have
## life, and every creature on them moved.
func advance(delta: float, eye: Vector3) -> void:
	var began := Time.get_ticks_usec()
	_clock += delta
	_choose(eye)
	var air := _air()
	var daylight := _daylight()
	for key: String in hosts.keys():
		var host: Host = hosts[key]
		if not is_instance_valid(host):
			hosts.erase(key)
			continue
		var rate := delta/FADE
		host.fade = minf(host.fade+rate,host.fade_to) if host.fade < host.fade_to else maxf(host.fade-rate,host.fade_to)
		if host.handing >= 0.0: host.handing += delta
		if (host.handing < 0.0 and host.fade <= 0.0 and host.fade_to <= 0.0) or host.handing > HANDOVER_MOST+GULL_LEAVE+1.0:
			_release(key)
			continue
		_move(host,delta,eye,air,daylight)
	last_usec = Time.get_ticks_usec()-began
	worst_usec = maxi(worst_usec,last_usec)
	SkyCommits.note("ambient",last_usec)

## The islands that should have life now: risen and baked, within RADIUS,
## the CAP nearest; the rest let go (fading, or at once past RELEASE). One
## new island stood up a frame, while the frame has room.
func _choose(eye: Vector3) -> void:
	var near: Array = []
	var wanted := {}
	for i in range(islands.copy_count()):
		if islands.lands[i] == null or islands._rise[i] != Vector3.ZERO: continue
		# The island just left, standing on the plate's spot till the swap,
		# takes its life from the plate (`leave`), never before.
		if (islands.offsets[i] as Vector3).length() < 1.0:
			var left: String = islands._key(islands.homes[i])
			if hosts.has(left): wanted[left] = i
			continue
		var island: Node3D = islands._copies[i]
		if not island.has_meta("far"): continue
		var d := _middle_of(i).distance_to(eye)
		if d <= release: near.append([d,i])
	near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for pick: Array in near:
		if wanted.size() >= cap: break
		var key: String = islands._key(islands.homes[pick[1]])
		if pick[0] > radius and not hosts.has(key): continue
		wanted[key] = pick[1]
	for key: String in hosts.keys():
		var host: Host = hosts[key]
		if host.handing >= 0.0: continue
		if not wanted.has(key):
			var at: int = islands.homes.find(host.home)
			if at < 0 or _middle_of(at).distance_to(eye) > release: _release(key)
			else: host.fade_to = 0.0
		else:
			host.fade_to = 1.0
	for key: String in wanted:
		if hosts.has(key): continue
		if not SkyCommits.open(): return
		var began := Time.get_ticks_usec()
		_stand(wanted[key])
		SkyCommits.spend("ambient:stand",Time.get_ticks_usec()-began)
		return

func _middle_of(index: int) -> Vector3:
	var land: NativeTerrainData = islands.lands[index]
	var c := land.land_rect().get_center()
	var island: Node3D = islands._copies[index]
	return island.global_transform*(islands.editor.terrain.global_transform*Vector3(c.x,0.0,c.y))

## An island's life, stood up: its batches under its copy, its gulls'
## columns, its grove and its chaff read from what its worker laid out.
func _stand(index: int, from_birds: Array = []) -> Host:
	var island: Node3D = islands._copies[index]
	var home: Vector3 = islands.homes[index]
	var host := Host.new()
	host.name = "Life"
	host.home = home
	host.key = islands._key(home)
	island.add_child(host)
	hosts[host.key] = host
	# Where its life goes, worked out on its worker as it baked (`layout`).
	var plan: Dictionary = island.get_meta("life",{})
	if plan.is_empty():
		var catalog: Dictionary = SkyIslets.catalog(islands.editor.content)
		plan = layout(islands.lands[index],(island.get_meta("far",{}) as Dictionary).get("flora",{}),catalog.roles,(catalog.get("data",{}) as Dictionary).get("boxes",{}),
			islands.editor.terrain.global_transform,islands.editor.content.global_transform)
	var seed_value: int = islands.seed_of(home)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	host.middle = plan.middle
	host.columns.assign(plan.columns)
	var trees: Array = plan.trees
	var count := clampi(GULLS_MIN+trees.size()/GULL_TREES,GULLS_MIN,GULLS_MAX)
	for k in range(maxi(count,from_birds.size())):
		var g := {"col":k%host.columns.size(),"r":rng.randf_range(GULL_RADIUS.x,GULL_RADIUS.y),"high":rng.randf_range(GULL_HIGH.x,GULL_HIGH.y),
			"speed":rng.randf_range(GULL_SPEED.x,GULL_SPEED.y),"spin":-1.0 if rng.randf() < 0.5 else 1.0,"a":rng.randf()*TAU,
			"size":rng.randf_range(GULL_SIZE.x,GULL_SIZE.y),"ph":rng.randf()*TAU,"phase":rng.randf()*TAU,"flap":0.2,"gone":-1.0,
			"from":Vector3.INF,"from_yaw":0.0}
		if k < from_birds.size():
			g.from = from_birds[k].p
			g.from_yaw = float(from_birds[k].yaw)
			g.size = clampf(float(from_birds[k].size),GULL_SIZE.x*0.8,GULL_SIZE.y*1.2)
		host.gulls.append(g)
	var gull_mesh := _gulls_source()
	if gull_mesh != null:
		host.gull_batch = _batch(host,"Gulls",gull_mesh,host.gulls.size(),true,null)
		for k in range(host.gulls.size()): host.gull_batch.set_instance_color(k,Color.WHITE)
	# The flock in the tallest crown.
	if not trees.is_empty():
		var top: Vector4 = trees[0]
		host.crown = maxf(top.w,1.0)
		host.grove = Vector3(top.x,top.y-host.crown*0.6,top.z)
		var species: String = Songbird.SPECIES.keys()[absi(seed_value)%Songbird.SPECIES.size()]
		for j in range(FLOCK):
			var inside := Vector3(rng.randf_range(-1,1),rng.randf_range(-0.4,0.6),rng.randf_range(-1,1))*host.crown*0.6
			host.flock.append({"in":inside,"a":TAU*j/FLOCK+rng.randf_range(-0.3,0.3),"r":rng.randf_range(0.0,1.6),"h":rng.randf_range(-0.6,0.9),
				"ph":rng.randf(),"wobble":rng.randf()*TAU,"late":rng.randf_range(0.0,0.35)})
		host.spread_batch = _batch(host,"FlockOut",flock_mesh(species,true),FLOCK,false,Songbird.material(),FLOCK_FAR)
		host.folded_batch = _batch(host,"FlockIn",flock_mesh(species,false),FLOCK,false,Songbird.material(),FLOCK_FAR)
		host.spread_batch.visible_instance_count = 0
		host.folded_batch.visible_instance_count = 0
	for at: Vector3 in plan.chaff:
		host.chaff.append({"at":at,"life":rng.randf_range(CHAFF_LIFE.x,CHAFF_LIFE.y),"ph":rng.randf(),
			"size":rng.randf_range(Chaff.SIZE.x,Chaff.SIZE.y),"side":rng.randf_range(-1.0,1.0),"rise":rng.randf_range(CHAFF_RISE.x,CHAFF_RISE.y),
			"axis":Vector3(rng.randf_range(-1,1),rng.randf_range(-0.3,0.3),rng.randf_range(-1,1)).normalized(),"spin":rng.randf_range(2.0,5.0)})
	if not host.chaff.is_empty():
		host.chaff_batch = _batch(host,"Chaff",_chaff_mesh(),host.chaff.size(),true,LeafMesh.material(),CHAFF_FAR)
		for k in range(host.chaff.size()):
			host.chaff_batch.set_instance_color(k,Color(Chaff.COLORS[k%Chaff.COLORS.size()]).srgb_to_linear())
	return host

static var _chaff: Mesh

## The plate's chaff blade (WindGrassChaff), made once.
static func _chaff_mesh() -> Mesh:
	if _chaff == null: _chaff = Chaff._chaff_mesh()
	return _chaff

## On an island's worker as it bakes (SkyIslands `_bake`): where its life
## goes, plate space. `plain` is the island's land; `flora` what it draws
## (SkyIslands `far_flora`), read through the garden catalog's `roles` and
## `boxes` (SkyIslets `catalog`); `plate` the plate's terrain transform and
## `place` its garden's. Returns {middle: its land's middle on the ground,
## trees: Array of Vector4 (crown x, top, z, radius), tallest first,
## columns: the gulls' (over the two tallest trees and the middle, on the
## ground), chaff: the blades' resting spots on open grass}.
static func layout(plain: NativeTerrainData, flora: Dictionary, roles: Dictionary, boxes: Dictionary, plate: Transform3D, place: Transform3D) -> Dictionary:
	var rect := plain.land_rect()
	var mid := rect.get_center()
	var middle := plate*Vector3(mid.x,_ground(plain,mid),mid.y)
	var trees := _trees(flora,roles,boxes,place)
	trees.sort_custom(func(a: Vector4, b: Vector4) -> bool: return a.y > b.y)
	var columns: Array[Vector3] = []
	var anchors: Array[Vector3] = []
	for t: Vector4 in trees.slice(0,2): anchors.append(Vector3(t.x,t.y,t.z))
	anchors.append(middle)
	for a: Vector3 in anchors:
		var ground := _ground(plain,_plate_to_land(plate,a))
		columns.append(Vector3(a.x,(plate*Vector3(0,ground,0)).y,a.z))
	var on_land := func(p: Vector2) -> float: return plain.ground_coverage(p) if plain.has_land(p) else 0.0
	var chaff: Array[Vector3] = []
	for spot: Vector2 in Chaff.anchors_on(on_land,CHAFF,rect.grow(-1.0)): chaff.append(plate*Vector3(spot.x,_ground(plain,spot),spot.y))
	return {"middle":middle,"trees":trees,"columns":columns,"chaff":chaff}

## A batch on `host`: `count` instances of `mesh`, in the island's box.
func _batch(host: Host, label: String, mesh: Mesh, count: int, custom: bool, material: Material, far := 0.0) -> MultiMesh:
	var node := MultiMeshInstance3D.new()
	node.name = label
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = custom
	multimesh.instance_count = count
	multimesh.mesh = mesh
	multimesh.custom_aabb = AABB(host.middle-Vector3(BOX.x*0.5,10.0,BOX.z*0.5),BOX)
	node.multimesh = multimesh
	if material != null: node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.set_meta("skip_reflection",true)
	if far > 0.0:
		node.visibility_range_end = far
		node.visibility_range_end_margin = FAR_MARGIN
		node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	host.add_child(node)
	return multimesh

## The trees in `flora` (its tree parts, through `roles`): each crown's
## middle (x, z), top (y) and radius (w), plate space (`place` the garden's
## transform, `boxes` each part's bounds).
static func _trees(flora: Dictionary, roles: Dictionary, boxes: Dictionary, place: Transform3D) -> Array[Vector4]:
	var out: Array[Vector4] = []
	var seen := {}
	for key: String in flora:
		if roles.get(key,"") != "tree" or not boxes.has(key): continue
		var box: AABB = boxes[key]
		var buffer: PackedFloat32Array = flora[key].buffer
		for i in range(int(flora[key].count)):
			var o := i*20
			if o+11 >= buffer.size(): break
			var t := Transform3D(Vector3(buffer[o],buffer[o+4],buffer[o+8]),Vector3(buffer[o+1],buffer[o+5],buffer[o+9]),Vector3(buffer[o+2],buffer[o+6],buffer[o+10]),Vector3(buffer[o+3],buffer[o+7],buffer[o+11]))
			var drawn := place*t*box
			# A tree is several parts (trunk, crown): one per spot, its top.
			var spot := "%d,%d" % [roundi(drawn.get_center().x*2.0),roundi(drawn.get_center().z*2.0)]
			var tree := Vector4(drawn.get_center().x,drawn.end.y,drawn.get_center().z,maxf(drawn.size.x,drawn.size.z)*0.5)
			if seen.has(spot):
				var was: Vector4 = out[seen[spot]]
				out[seen[spot]] = Vector4(was.x,maxf(was.y,tree.y),was.z,maxf(was.w,tree.w))
			else:
				seen[spot] = out.size()
				out.append(tree)
	return out

static func _plate_to_land(plate: Transform3D, p: Vector3) -> Vector2:
	var local := plate.affine_inverse()*p
	return Vector2(local.x,local.z)

static func _ground(land: NativeTerrainData, p: Vector2) -> float:
	var h: Variant = land.height_at(p.x,p.y)
	return float(h) if h != null else 0.3

## The wind, as the plate's air blows: Vector3(direction x, z, strength).
func _air() -> Vector3:
	var air: Variant = islands.scene.get("_atmosphere")
	if air == null: return Vector3(1.0,0.0,0.5)
	var angle := float(air.get("_air_angle"))
	return Vector3(cos(angle),sin(angle),float(air.get("_air_strength")))

func _daylight() -> float:
	var sky: Variant = islands.scene.get("_celestial")
	return float(sky.state.get("zs_daylight",1.0)) if sky != null else 1.0

## Every creature on `host`, for its clock now.
func _move(host: Host, delta: float, eye: Vector3, air: Vector3, daylight: float) -> void:
	var t := _clock
	var to_eye := host.global_transform.affine_inverse()*eye
	var day := smoothstep(0.15,0.4,daylight)
	# The glide near a column stirs the gulls; they calm slowly after.
	var nearest := INF
	for c: Vector3 in host.columns: nearest = minf(nearest,(c+Vector3.UP*11.0).distance_to(to_eye))
	var stir_to := 1.0-smoothstep(STIR_NEAR*0.5,STIR_NEAR,nearest)
	host.stir = lerpf(host.stir,stir_to,1.0-exp(-(2.0 if stir_to > host.stir else 0.3)*delta))
	_move_gulls(host,delta,t,day)
	_move_flock(host,delta,to_eye,day)
	_move_chaff(host,t,air)

func _move_gulls(host: Host, delta: float, t: float, day: float) -> void:
	if host.gull_batch == null: return
	var life := _life()
	var real := _real_gulls(life) if host.handing >= 0.0 else 0
	var out: Array = []
	var yaws: Array = []
	for k in range(host.gulls.size()):
		var g: Dictionary = host.gulls[k]
		var c: Vector3 = host.columns[int(g.col)]
		# The column drifts a little, so each loop lands somewhere new.
		var cx := c.x+2.0*sin(t*0.07+float(g.ph))
		var cz := c.z+2.0*cos(t*0.05+float(g.ph)*1.3)
		var r := float(g.r)*(1.0+0.22*sin(t*0.13+float(g.ph)*2.0))*(1.0+STIR_WIDE*host.stir)
		var w := float(g.speed)/r*float(g.spin)
		g.a = float(g.a)+w*delta
		var a := float(g.a)
		var y := c.y+float(g.high)+1.1*sin(t*0.21+float(g.ph))+STIR_CLIMB*host.stir*(0.6+0.4*sin(float(g.ph)))
		var pos := Vector3(cx+r*cos(a),y,cz+r*sin(a))
		var velocity := Vector3(-sin(a),0.0,cos(a))*r*w
		var yaw := atan2(velocity.x,velocity.z)
		# Banked into the turn, as BirdFlight banks its own (its yaw turns at -w).
		var roll := clampf(w*0.42,-1.15,1.15)
		# Handed over at a claim: each lets go as LandLife's gulls come in,
		# climbing away wider.
		if host.handing >= 0.0 and float(g.gone) < 0.0 and (real > k or host.handing >= HANDOVER_MOST): g.gone = host.handing
		var going := clampf((host.handing-float(g.gone))/GULL_LEAVE,0.0,1.0) if float(g.gone) >= 0.0 else 0.0
		if going > 0.0:
			var away := Vector3(cos(a),0.0,sin(a))*(8.0+25.0*going)*going
			pos += away+Vector3.UP*12.0*going*going
		# Taken from the plate at a claim: eased from where it flew.
		var from: Vector3 = g.from
		if from != Vector3.INF:
			if not g.has("born"): g.born = _clock
			var blend := smoothstep(0.0,LEAVE_BLEND,_clock-float(g.born))
			pos = from.lerp(pos,blend)
			yaw = lerp_angle(float(g.from_yaw),yaw,blend)
			if blend >= 1.0: g.from = Vector3.INF
		# Mostly gliding, now and then a few beats; stirred or leaving, harder.
		var work := 0.08+0.5*smoothstep(0.72,1.0,sin(t*0.35+float(g.ph)*3.0))+0.4*host.stir+0.8*going
		g.flap = lerpf(float(g.flap),clampf(work,0.0,1.0),1.0-exp(-2.5*delta))
		g.phase = fposmod(float(g.phase)+delta*(4.5+float(g.flap)*7.0),TAU)
		# Coming in or going one by one; handed over, each by its own leaving.
		var stagger := 1.0 if host.handing >= 0.0 else clampf(host.fade*float(host.gulls.size())-float(k),0.0,1.0)
		var scale := float(g.size)*stagger*day*(1.0-smoothstep(0.75,1.0,going))
		var pitch := -0.05+0.15*going
		var basis := Basis.from_euler(Vector3(pitch,yaw,roll),EULER_ORDER_YXZ).scaled(Vector3.ONE*maxf(scale,0.00001))
		host.gull_batch.set_instance_transform(k,Transform3D(basis,pos))
		host.gull_batch.set_instance_custom_data(k,Color(float(g.flap),float(g.phase),0,1))
		out.append(Vector4(pos.x,pos.y,pos.z,scale))
		yaws.append(yaw)
	host.shown.gulls = out
	host.shown.gull_yaws = yaws

## LandLife's gulls showing now.
static func _real_gulls(life: Node) -> int:
	if life == null: return 0
	var flight: Variant = life.get("_birds")
	if flight == null: return 0
	var n := 0
	for bird: Dictionary in flight.birds:
		if float(bird.get("out",0.0)) > 0.5: n += 1
	return n

func _life() -> Node:
	return islands.scene.get("land_life")

func _move_flock(host: Host, delta: float, to_eye: Vector3, day: float) -> void:
	if host.spread_batch == null: return
	var reach := Vector2(to_eye.x-host.grove.x,to_eye.z-host.grove.z).length()
	var close := to_eye.distance_to(host.grove)
	if host.flushed < 0.0 and host.armed and close < FLUSH_NEAR and day > 0.5 and host.fade > 0.5 and host.handing < 0.0:
		host.flushed = 0.0
		host.armed = false
	if reach > REARM: host.armed = true
	if host.flushed < 0.0:
		host.shown.flock = []
		return
	host.flushed += delta
	var s := host.flushed
	if s > BURST+WHEEL+SETTLE+0.5:
		host.flushed = -1.0
		host.spread_batch.visible_instance_count = 0
		host.folded_batch.visible_instance_count = 0
		host.shown.flock = []
		return
	host.spread_batch.visible_instance_count = FLOCK
	host.folded_batch.visible_instance_count = FLOCK
	var hidden := Transform3D(Basis.from_scale(Vector3.ONE*0.00001),host.grove)
	var out: Array = []
	for j in range(host.flock.size()):
		var b: Dictionary = host.flock[j]
		var u := s-float(b.late)
		var pos := _flock_at(host,b,u)
		var ahead := _flock_at(host,b,u+0.05)
		var way := ahead-pos
		var yaw := atan2(-way.x,-way.z)
		var climb := atan2(way.y,maxf(Vector2(way.x,way.z).length(),0.0001))
		var scale := Songbird.SIZE*smoothstep(-0.05,0.25,u)*(1.0-smoothstep(BURST+WHEEL+SETTLE*0.6,BURST+WHEEL+SETTLE,u))
		var turn := Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,climb*0.6)*Basis(Vector3(0,0,1),0.35*sin(u*1.3+float(b.wobble)))
		var body := Transform3D(turn.scaled(Vector3.ONE*maxf(scale,0.00001)),pos)
		var wings_out := fposmod(u*BOUNDS+float(b.ph),1.0) < BOUND_OUT or u < BURST
		host.spread_batch.set_instance_transform(j,body if wings_out else hidden)
		host.folded_batch.set_instance_transform(j,hidden if wings_out else body)
		out.append(Vector4(pos.x,pos.y,pos.z,scale))
	host.shown.flock = out

## Where flock bird `b` is `u` seconds after the flush: out of the crown,
## wheeling wide over the grove together, and back into the crown.
func _flock_at(host: Host, b: Dictionary, u: float) -> Vector3:
	var inside: Vector3 = host.grove+(b["in"] as Vector3)
	var a := float(b.a)+u*1.15
	var r := host.crown+2.5+float(b.r)+1.2*sin(u*0.9+float(b.wobble))
	var wheel := host.grove+Vector3(r*cos(a),host.crown*0.9+2.5+float(b.h)+0.5*sin(u*2.1+float(b.wobble))+1.5*smoothstep(0.0,2.0,u),r*sin(a))
	var out := smoothstep(0.0,BURST,u)
	var back := smoothstep(BURST+WHEEL,BURST+WHEEL+SETTLE,u)
	return inside.lerp(wheel,out*(1.0-back))

func _move_chaff(host: Host, t: float, air: Vector3) -> void:
	if host.chaff_batch == null: return
	var way := Vector3(air.x,0.0,air.y)
	var side := Vector3(-air.y,0.0,air.x)
	var strength := clampf(air.z,0.25,1.2)
	var out: Array = []
	for k in range(host.chaff.size()):
		var c: Dictionary = host.chaff[k]
		var life := float(c.life)
		var u := fposmod(t/life+float(c.ph),1.0)
		var at: Vector3 = c.at
		var run := lerpf(CHAFF_RUN.x,CHAFF_RUN.y,strength)*u
		var pos := at+way*run+side*float(c.side)*0.8*sin(u*6.0+float(c.ph)*TAU)
		pos.y += 0.05+float(c.rise)*strength*pow(sin(PI*u),0.8)+0.25*sin(u*11.0+float(c.ph)*TAU)
		var scale := float(c.size)*smoothstep(0.0,0.12,u)*(1.0-smoothstep(0.85,1.0,u))*host.fade
		var basis := Basis(c.axis,u*life*float(c.spin)).scaled(Vector3.ONE*maxf(scale,0.00001))
		host.chaff_batch.set_instance_transform(k,Transform3D(basis,pos))
		out.append(Vector4(pos.x,pos.y,pos.z,scale))
	host.shown.chaff = out

## Lets an island's life go, at once.
func _release(key: String) -> void:
	var host: Host = hosts.get(key)
	hosts.erase(key)
	if host != null and is_instance_valid(host): host.queue_free()

## Every island's life let go (a new sky, a world closed).
func clear() -> void:
	for key: String in hosts.keys(): _release(key)

## At a claim, as the plate hides (SkyIslands `claim`): the island left
## (copy `index`, standing where the plate stood) takes life at once, its
## gulls starting where the plate's own were flying.
func leave(index: int) -> void:
	var key: String = islands._key(islands.homes[index])
	if hosts.has(key): _release(key)
	var birds: Array = []
	# Into the island's own space (the plate's, where it stands).
	var into: Transform3D = (islands._copies[index] as Node3D).global_transform.affine_inverse()
	var life := _life()
	var flight: Variant = life.get("_birds") if life != null else null
	if flight != null:
		var node: Node3D = life.get("_bird_node")
		for bird: Dictionary in flight.birds:
			if float(bird.get("out",0.0)) <= 0.5: continue
			var p: Vector3 = node.global_transform*Vector3(float(bird.x),float(bird.y),float(bird.z)) if node != null else Vector3(float(bird.x),float(bird.y),float(bird.z))
			birds.append({"p":into*p,"yaw":float(bird.yaw),"size":float(bird.get("s",GULL_SIZE.x))})
	# A stand-in still over the plate from the last claim goes with the
	# island too, its gulls where they fly.
	for k: String in hosts.keys():
		var was: Host = hosts[k]
		if was.handing < 0.0: continue
		var yaws: Array = was.shown.get("gull_yaws",[])
		for n in range((was.shown.gulls as Array).size()):
			var g: Vector4 = was.shown.gulls[n]
			if g.w > 0.01: birds.append({"p":into*(was.global_transform*Vector3(g.x,g.y,g.z)),"yaw":float(yaws[n]) if n < yaws.size() else 0.0,"size":g.w})
		_release(k)
	var host := _stand(index,birds)
	# Its life shows at once where it takes the plate's flying gulls; else it
	# comes in, as on any island.
	host.fade = 1.0 if not birds.is_empty() else 0.0
	host.fade_to = 1.0

## At a claim's swap (SkyIslands `claim`), before the claimed copy is let
## go: its life stays, now over the plate, and goes as LandLife's comes in.
func handover(index: int) -> void:
	var key: String = islands._key(islands.homes[index])
	var host: Host = hosts.get(key)
	if host == null or not is_instance_valid(host): return
	host.reparent(self,false)
	# The island's own space is the plate's: over the plate it stands at the
	# plate's place.
	host.global_transform = Transform3D.IDENTITY
	host.handing = 0.0
	host.fade_to = 0.0
	host.armed = false
	hosts.erase(key)
	hosts["handover:"+key] = host

## For probes and tests: the host of the island at `home`, or null.
func host_at(home: Vector3) -> Host:
	return hosts.get(islands._key(home))

## Instances drawn now, all islands (gulls, flock birds, blades).
func drawn() -> int:
	var n := 0
	for host: Host in hosts.values():
		if not is_instance_valid(host): continue
		n += (host.shown.gulls as Array).size()+(host.shown.flock as Array).size()+(host.shown.chaff as Array).size()
	return n
