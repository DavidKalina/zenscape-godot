extends Node3D
## Songbirds (docs/scenic/songbirds.md): small flocks that live in the trees.
##
## Each flock (3 to 6 of one species) keeps a home grove: trees within GROVE
## metres of each other. Most of its birds sit hidden inside the crowns; one or
## two sit in plain sight on the oaks' perch limbs (scripts/perch_limbs.gd),
## look about, hop along the limb, and now and then flit to another tree of
## the grove in the bounding flap-and-glide of small birds. A bird that lands
## in or leaves a crown shivers it (a small LocalWindField gust, which every
## crown shader reads) and shakes out a few leaves in the season's colour: green
## in summer, gold to copper in autumn, a puff of snow when the trees are white.
##
## A flush sends the whole flock out at once with a bigger rustle and burst:
## a gust you send reaching the grove, a poke near it, the wanderer walking
## close, or the camera coming within CAMERA_NEAR of a bird. They wheel above
## the grove together and settle in another one. A flock also moves on by
## itself every few minutes, more quietly. At night they roost unseen.
##
## A perched bird rides its limb exactly: its shader evaluates the wood's own
## wind bend at the perch (shaders/songbird.gdshader). A limb whose tree is
## moved, bent in play, burning or gone sends its bird away; nothing ever
## jumps. Everything is world space (the node is top level), worked out each
## frame from the content's transform, so a moving plate carries the birds.
## Birds are not saved; flocks settle again in a new session.
const Plate = preload("res://scripts/plate.gd")
const Body = preload("res://scripts/songbird_body.gd")
const Limbs = preload("res://scripts/perch_limbs.gd")
const Inspector = preload("res://scripts/scene_inspector.gd")
const Disturbance = preload("res://scripts/disturbance.gd")
const PondSeasons = preload("res://scripts/pond_seasons.gd")
const HeroTrees = preload("res://scripts/hero_trees.gd")

const TREES := ["broadleaf","tree","layered_tree","redwood","birch","willow","juniper"]
const CONIFERS := ["tree","redwood","juniper"]
## The oak's wood bends over this shape (its material's blow_shape).
const OAK_BEND := Vector2(0.4,2.4)
## Trees closer than this (m, crown to crown) share a grove.
const GROVE := 6.0
## One flock per TREES_PER_FLOCK trees, at most FLOCKS; each FLOCK_SIZE birds.
const TREES_PER_FLOCK := 8
const FLOCKS := 3
const FLOCK_SIZE := Vector2i(3,6)
const SPECIES := ["sparrow","goldfinch","robin"]
## Flight: cruise speed (m/s), steering (m/s²), the final approach's speed.
const SPEED := 4.0
const STEER := 10.0
const APPROACH := 1.1
## Bounding flight: seconds of wingbeats, then of wings tucked.
const BOUND := Vector2(0.34,0.22)
const BEAT := 15.0
## Seconds a hidden bird stays before it flits, and a perched bird sits.
const HIDE := Vector2(10.0,28.0)
const SIT := Vector2(7.0,18.0)
## Share of flits that land on a free perch rather than inside a crown.
const TO_PERCH := 0.55
## Seconds between a flock's own moves to another grove.
const ROAM := Vector2(100.0,220.0)
## After settling, a flock ignores flushes for this long.
const CALM := 12.0
## Flush reach (m): the camera's eye to a bird or a crown it hides in, a poke,
## the wanderer, and how much of a gust's front must reach a tree.
const CAMERA_NEAR := 1.8
const POKE_NEAR := 5.0
const FIGURE_NEAR := 4.0
const GUST_SHARE := 0.15
## Wheeling after a flush: radius, height over the grove (m), seconds.
const WHEEL := Vector2(3.2,3.8)
const WHEEL_TIME := Vector2(3.0,5.0)
## The crown shiver: a local gust (m/s), its radius (m) and seconds; a flush's.
const RUSTLE := Vector3(5.0,1.4,0.6)
const FLUSH_RUSTLE := Vector3(9.0,2.4,1.1)
## Leaves shaken out: a bird's coming or going, and a flush's per tree.
const LEAVES := 5
const FLUSH_LEAVES := 16
const LEAF_POOL := 10
## Below this daylight they roost.
const DUSK := 0.18

var life: Node3D
var scene: Node3D
var editor: Node
var inspector := Inspector.new()
## Trees by id: {id, asset, local (content-local mesh transform), crown (local
## point), reach (m), perches: [{key, at, face}] (mesh space), conifer, stand}.
var trees := {}
var groves: Array[Dictionary] = []
var flocks: Array[Dictionary] = []
var birds: Array[Dictionary] = []
## What happened, for probes: rustles, leaf bursts, flushes, landings by kind.
var counts := {}
var _held := {}
var _scan := 0.0
var _clock := 0.0
var _pending: Array = []
var _rng := RandomNumberGenerator.new()
var _leaf_pool: Array[CPUParticles3D] = []
var _flush_pool: Array[CPUParticles3D] = []
var _next_leaf := 0
var _next_flush := 0
var _rustled := {}
var _crown_cache := {}

func setup(owner: Node3D) -> void:
	life = owner
	scene = life.scene
	editor = scene._chunk_editor
	name = "Songbirds"
	top_level = true
	inspector.setup(scene)
	_rng.seed = 90127
	for i in range(LEAF_POOL):
		_leaf_pool.append(_leaf_emitter(LEAVES))
		_flush_pool.append(_leaf_emitter(FLUSH_LEAVES))
	Disturbance.hub().raised.connect(_raised)

## Send every bird away at once (a new world).
func clear() -> void:
	for bird in birds:
		var body: Node3D = bird.body
		if is_instance_valid(body): body.queue_free()
	birds.clear()
	flocks.clear()
	groves.clear()
	trees.clear()
	_held.clear()
	_pending.clear()
	_rustled.clear()
	_scan = 0.0

# --- Trees and groves ---------------------------------------------------------------

## Reads every tree: where its crown is and where its perches are, in the
## content's space; then groups them into groves.
func scan_trees() -> void:
	var data: NativeTerrainData = editor.data
	var content: GardenView = editor.content
	var oak_perches := Limbs.perches() if HeroTrees.enabled() else []
	var disturbed := _disturbed()
	var found := {}
	for item: Dictionary in data.objects:
		var asset := str(item.asset)
		if asset not in TREES: continue
		var id := int(item.id)
		var basis := NativeObjectPose.decode_basis(item.pose) if item.has("pose") else Basis(Vector3.UP,float(item.angle)).scaled(Vector3.ONE*float(item.scale))
		var local := Transform3D(basis,data.object_position(item))
		var crown := _crown(asset,item,content)
		if crown.is_empty(): continue
		var upright := basis.y.normalized().dot(Vector3.UP) > 0.9
		var perches := []
		if asset == "broadleaf" and upright and id not in disturbed:
			for i in range(oak_perches.size()):
				var perch: Dictionary = oak_perches[i]
				perches.append({"key":"%d:%d" % [id,i],"at":perch.at,"face":perch.face,"limb":perch.limb})
		found[id] = {"id":id,"asset":asset,"local":local,"crown":local*(crown.centre as Vector3),"reach":float(crown.reach)*basis.get_scale().x,
			"perches":perches,"conifer":asset in CONIFERS,"stand":float(item.get("autumn",0.5)),"calm":id not in disturbed}
	trees = found
	_group()

## The crown's middle and how far into it a bird can hide (mesh space), from
## the asset's canopy part.
func _crown(asset: String, item: Dictionary, content: GardenView) -> Dictionary:
	var key := asset
	var parts: Array = content._catalog_parts.get(asset,[])
	if asset == "tree" and content._catalog_parts.has("tree_variants"):
		key = content._catalog_parts.tree_variants[2*HeroTrees.spruce_index(item)+1]
	else:
		for part: String in parts:
			if "canop" in part:
				key = part
				break
	if _crown_cache.has(key): return _crown_cache[key]
	var crown := {}
	var mesh: Mesh = content._meshes.get(key)
	if mesh != null:
		var pose: Transform3D = content._catalog_poses.get(key,Transform3D.IDENTITY)
		var box := pose*mesh.get_aabb()
		var size := box.size
		crown = {"centre":box.get_center()+Vector3.UP*size.y*0.05,"reach":minf(size.x,size.z)*0.28}
	_crown_cache[key] = crown
	return crown

## Trees birds should leave: bent in play, held or burning.
func _disturbed() -> Array[int]:
	var out: Array[int] = []
	for tree in get_tree().get_nodes_in_group("spring_trees"):
		if not scene.is_ancestor_of(tree) or tree.get("object_id") == null: continue
		if tree.get("held") == true or (tree.get("bend") is Vector2 and (tree.bend as Vector2).length() > 0.01): out.append(int(tree.object_id))
	var content: Object = editor.content
	if content.has_method("object_fire"):
		for item: Dictionary in editor.data.objects:
			if str(item.asset) not in TREES: continue
			var fire: Vector2 = content.object_fire(int(item.id))
			if fire.y > 0.02 or fire.x > 0.6: out.append(int(item.id))
	return out

## Groves: trees whose crowns stand within GROVE of another's, by flood fill.
func _group() -> void:
	groves.clear()
	var ids := trees.keys()
	ids.sort()
	var seen := {}
	for id: int in ids:
		if seen.has(id) or not trees[id].calm: continue
		var members: Array[int] = [id]
		seen[id] = true
		var i := 0
		while i < members.size():
			var at: Vector3 = trees[members[i]].crown
			for other: int in ids:
				if seen.has(other) or not trees[other].calm: continue
				if (trees[other].crown as Vector3).distance_to(at) <= GROVE:
					seen[other] = true
					members.append(other)
			i += 1
		var centre := Vector3.ZERO
		var perches := 0
		for member in members:
			centre += trees[member].crown
			perches += (trees[member].perches as Array).size()
		groves.append({"trees":members,"centre":centre/members.size(),"perches":perches})

func _world() -> Transform3D:
	return editor.content.global_transform

func _crown_at(id: int) -> Vector3:
	return _world()*(trees[id].crown as Vector3)

## A perch's feet in world space, and its facing.
func _perch_world(id: int, perch: Dictionary) -> Array:
	var xf: Transform3D = _world()*(trees[id].local as Transform3D)
	var face: Vector3 = xf.basis*(perch.face as Vector3)
	face.y = 0.0
	return [xf*(perch.at as Vector3),face.normalized() if face.length_squared() > 0.0001 else Vector3.FORWARD]

# --- Flocks -------------------------------------------------------------------------

## Flocks as many as the trees allow, each arriving from off the plate.
func _plan_flocks() -> void:
	var count := 0
	for grove in groves: count += (grove.trees as Array).size()
	var wanted := clampi(int(round(float(count)/TREES_PER_FLOCK)),1 if count >= 2 else 0,FLOCKS)
	while flocks.size() < wanted:
		var grove := _choose_grove(-1)
		if grove < 0: break
		var flock := {"index":flocks.size(),"species":SPECIES[flocks.size()%SPECIES.size()],"grove":grove,"state":"settled",
			"calm_until":_clock+CALM,"roam_at":_clock+_rng.randf_range(ROAM.x,ROAM.y),"wheel":{}}
		flocks.append(flock)
		var size := _rng.randi_range(FLOCK_SIZE.x,FLOCK_SIZE.y)
		var edge := _arrival_point()
		for i in range(size):
			var bird := _new_bird(flock)
			bird.p = edge+Vector3(_rng.randf_range(-1.5,1.5),_rng.randf_range(-0.6,0.6),_rng.randf_range(-1.5,1.5))
			bird.v = (_world()*(groves[grove].centre as Vector3)-edge).normalized()*SPEED
			bird.delay = float(i)*0.25+_rng.randf()*0.4
			_fly_to(bird,_spot(flock,bird,true))

func _new_bird(flock: Dictionary) -> Dictionary:
	var body := Body.new()
	body.build(flock.species)
	add_child(body)
	body.visible = false
	var bird := {"flock":flock.index,"state":"flying","p":Vector3.ZERO,"v":Vector3.ZERO,"heading":Vector3.FORWARD,"body":body,"tree":-1,"perch":"",
		"target":{},"timer":0.0,"delay":0.0,"bound":_rng.randf()*0.5,"beat":_rng.randf()*TAU,"ride":0.0,"look":0.0,"look_goal":0.0,"look_at":0.0,
		"turn":0.0,"hop":{}}
	birds.append(bird)
	return bird

## A grove for a flock: bigger groves and ones with perches more often, not
## `besides`, and not one another flock lives in if there is a choice.
func _choose_grove(besides: int) -> int:
	var weights := {}
	for i in range(groves.size()):
		if i == besides: continue
		var weight := sqrt(float((groves[i].trees as Array).size()))*(1.0+0.6*minf(float(groves[i].perches),3.0))
		for flock in flocks:
			if int(flock.grove) == i: weight *= 0.25
		weights[i] = weight
	if weights.is_empty(): return besides if besides >= 0 and besides < groves.size() else -1
	var total := 0.0
	for key: int in weights: total += float(weights[key])
	var roll := _rng.randf()*total
	for key: int in weights:
		roll -= float(weights[key])
		if roll <= 0.0: return key
	return weights.keys().back()

## High a metre past the island's land (round its bounds, the plate's
## rim before it has any), where an arriving flock comes in.
func _arrival_point() -> Vector3:
	var angle := _rng.randf()*TAU
	var land := Plate.RECT
	if editor.data.has_method("land_rect"): land = editor.data.land_rect()
	var reach := land.size.length()*0.5*sqrt(0.5)+1.0
	var local := Vector3(land.get_center().x+cos(angle)*reach,0.0,land.get_center().y+sin(angle)*reach)
	var at: Vector3 = editor.terrain.to_global(local)
	var ground: Variant = inspector.ground_y(editor.terrain.to_global(Vector3.ZERO))
	at.y = (float(ground) if ground != null else at.y)+7.0
	return at

## Somewhere for `bird` to go in its flock's grove: a free perch (if
## `perch_ok` and the dice say so), else inside a crown. {kind, tree, key, at}.
func _spot(flock: Dictionary, bird: Dictionary, perch_ok: bool) -> Dictionary:
	if groves.is_empty(): return {}
	var grove: Dictionary = groves[clampi(int(flock.grove),0,groves.size()-1)]
	var members: Array = grove.trees
	if members.is_empty(): return {}
	if perch_ok and _rng.randf() < TO_PERCH and _daylight() >= DUSK:
		var free := []
		for id: int in members:
			if not trees.has(id): continue
			for perch: Dictionary in trees[id].perches:
				if not _held.has(perch.key): free.append([id,perch])
		if not free.is_empty():
			var pick: Array = free[_rng.randi()%free.size()]
			_held[pick[1].key] = bird
			return {"kind":"perch","tree":pick[0],"key":pick[1].key,"perch":pick[1]}
	var id: int = members[_rng.randi()%members.size()]
	if not trees.has(id): return {}
	var reach := float(trees[id].reach)
	var jitter := Vector3(_rng.randf_range(-1,1),_rng.randf_range(-0.5,0.5),_rng.randf_range(-1,1))*reach*0.4
	return {"kind":"hide","tree":id,"offset":jitter}

## Where a spot is now, in world space.
func _spot_at(spot: Dictionary) -> Vector3:
	var id := int(spot.get("tree",-1))
	if not trees.has(id): return Vector3.INF
	if spot.kind == "perch": return _perch_world(id,spot.perch)[0]
	return _crown_at(id)+(_world().basis*(spot.offset as Vector3))

# --- Each frame ---------------------------------------------------------------------

func advance(step: float, delta: float) -> void:
	if step <= 0.0:
		_pose_all(0.0)
		return
	_clock += step
	_scan -= step
	if _scan <= 0.0:
		_scan = 2.0
		scan_trees()
		_check_spots()
		_plan_flocks()
	_run_pending()
	_check_camera()
	for flock in flocks: _advance_flock(flock)
	for bird in birds: _advance_bird(bird,step)
	_pose_all(delta)

func _run_pending() -> void:
	var due: Array = []
	for entry: Array in _pending:
		if float(entry[0]) <= _clock: due.append(entry)
	for entry: Array in due:
		_pending.erase(entry)
		(entry[1] as Callable).call()

## Birds whose spot has gone (the tree moved, burnt, bent or removed) leave it.
func _check_spots() -> void:
	for bird in birds:
		var flock_of: Dictionary = flocks[int(bird.flock)]
		if bird.state == "gone":
			if groves.is_empty(): continue
			flock_of.grove = _choose_grove(-1)
			bird.p = _arrival_point()
			_fly_to(bird,_spot(flock_of,bird,true))
			continue
		if not bird.state in ["hidden","perched","landing"]: continue
		var spot: Dictionary = bird.target
		var id := int(spot.get("tree",-1))
		if trees.has(id) and trees[id].calm: continue
		_take_off(bird,false)
		var flock: Dictionary = flocks[int(bird.flock)]
		if int(flock.grove) >= groves.size() or not _grove_alive(int(flock.grove)): flock.grove = _choose_grove(-1)
		_fly_to(bird,_spot(flock,bird,true))

func _grove_alive(index: int) -> bool:
	for id: int in groves[index].trees:
		if trees.has(id): return true
	return false

func _advance_flock(flock: Dictionary) -> void:
	if flock.state == "wheeling":
		var wheel: Dictionary = flock.wheel
		if _clock >= float(wheel.until):
			flock.state = "settled"
			flock.calm_until = _clock+CALM
			for bird in _members(flock):
				bird.delay = _rng.randf()*0.8
				_fly_to(bird,_spot(flock,bird,true))
	elif _clock >= float(flock.roam_at) and _clock >= float(flock.calm_until) and _settled(flock):
		_flush(flock,false)

func _members(flock: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for bird in birds:
		if int(bird.flock) == int(flock.index): out.append(bird)
	return out

func _settled(flock: Dictionary) -> bool:
	for bird in _members(flock):
		if not bird.state in ["hidden","perched"]: return false
	return true

func _advance_bird(bird: Dictionary, step: float) -> void:
	if float(bird.delay) > 0.0:
		bird.delay = float(bird.delay)-step
		return
	match str(bird.state):
		"hidden":
			bird.timer = float(bird.timer)-step
			if float(bird.timer) <= 0.0 and _daylight() >= DUSK and flocks[int(bird.flock)].state == "settled":
				_take_off(bird,false)
				_fly_to(bird,_spot(flocks[int(bird.flock)],bird,true))
		"perched":
			_sit(bird,step)
		"hopping":
			_hop(bird,step)
		"flying","landing","wheeling":
			_fly(bird,step)

## On the limb: look about in quick snaps, flick the tail, and after a while
## hop along the limb or leave. At dusk it goes into the crown to roost.
func _sit(bird: Dictionary, step: float) -> void:
	bird.timer = float(bird.timer)-step
	var spot: Dictionary = bird.target
	var placed := _perch_world(int(spot.tree),spot.perch)
	# The limb moved under it (the tree was moved): off it goes, never jumping.
	if (placed[0] as Vector3).distance_to(bird.p) > 0.08:
		_take_off(bird,false)
		_fly_to(bird,_spot(flocks[int(bird.flock)],bird,true))
		return
	bird.p = placed[0]
	bird.ride = minf(float(bird.ride)+step*4.0,1.0)
	# Turn from the way it came in to face out.
	var face: Vector3 = placed[1]
	bird.heading = (bird.heading as Vector3).slerp(face,minf(step*5.0,1.0)).normalized()
	bird.look_at = float(bird.look_at)-step
	if float(bird.look_at) <= 0.0:
		bird.look_goal = _rng.randf_range(-0.9,0.9) if _rng.randf() < 0.8 else 0.0
		bird.look_at = _rng.randf_range(0.5,1.8)
	if _rng.randf() < step*0.25: (bird.body as Node3D).set("tail_flick",1.0)
	if float(bird.timer) > 0.0 and _daylight() >= DUSK: return
	# A free perch on the same limb: hop to it now and then.
	if _daylight() >= DUSK and _rng.randf() < 0.35:
		for perch: Dictionary in trees[int(spot.tree)].perches:
			if perch.key == spot.key or int(perch.limb) != int(spot.perch.limb) or _held.has(perch.key): continue
			_held.erase(spot.key)
			_held[perch.key] = bird
			var to := {"kind":"perch","tree":spot.tree,"key":perch.key,"perch":perch}
			bird.hop = {"from":bird.p,"t":0.0}
			bird.target = to
			bird.state = "hopping"
			return
	_take_off(bird,false)
	_fly_to(bird,_spot(flocks[int(bird.flock)],bird,_daylight() >= DUSK))

func _hop(bird: Dictionary, step: float) -> void:
	var hop: Dictionary = bird.hop
	hop.t = float(hop.t)+step/0.35
	var to: Vector3 = _perch_world(int(bird.target.tree),bird.target.perch)[0]
	var t := minf(float(hop.t),1.0)
	var from: Vector3 = hop.from
	var flat := Vector3(to.x-from.x,0.0,to.z-from.z)
	if flat.length_squared() > 0.0001: bird.heading = flat.normalized()
	bird.p = from.lerp(to,t)+Vector3.UP*sin(t*PI)*0.06
	if t >= 1.0:
		bird.state = "perched"
		bird.timer = _rng.randf_range(SIT.x,SIT.y)
		_count("hop")

## Steering toward the target; the last stretch to a perch comes in slow from
## its open side. Bounding flight while cruising: beats, then a tucked glide.
func _fly(bird: Dictionary, step: float) -> void:
	var goal: Vector3
	var speed := SPEED
	var arrive := 0.15
	var flock: Dictionary = flocks[int(bird.flock)]
	if bird.state == "wheeling":
		var wheel: Dictionary = flock.wheel
		var angle := float(wheel.angle0)+float(bird.slot)*TAU/maxf(float(wheel.count),1.0)+(_clock-float(wheel.since))*float(wheel.spin)
		goal = (wheel.centre as Vector3)+Vector3(cos(angle),sin(angle*1.7+float(bird.slot))*0.3,sin(angle))*float(wheel.radius)*(0.8+0.25*sin(float(bird.slot)*2.1))
		speed = SPEED*1.1
		arrive = -1.0
	else:
		var spot: Dictionary = bird.target
		goal = _spot_at(spot)
		if not goal.is_finite():
			_fly_to(bird,_spot(flock,bird,true))
			return
		if spot.kind == "perch":
			var placed := _perch_world(int(spot.tree),spot.perch)
			var front: Vector3 = goal+(placed[1] as Vector3)*0.9+Vector3.UP*0.3
			if bird.state == "flying" and (bird.p as Vector3).distance_to(front) < 0.35: bird.state = "landing"
			if bird.state == "flying": goal = front
			else:
				speed = APPROACH
				arrive = 0.03
	var to := goal-(bird.p as Vector3)
	var reach := to.length()
	if arrive > 0.0 and reach <= arrive:
		_land(bird)
		return
	var want := to/maxf(reach,0.001)*speed*clampf(reach/1.6,0.3 if bird.state != "landing" else 0.6,1.0)
	# Keep clear of the ground on the way.
	var p: Vector3 = bird.p
	var ground: Variant = inspector.ground_y(p)
	if ground != null and p.y < float(ground)+1.0 and reach > 2.0: want.y += (float(ground)+1.0-p.y)*3.0
	# Keep apart from flockmates.
	for other in birds:
		if other == bird or int(other.flock) != int(bird.flock) or not other.state in ["flying","wheeling"]: continue
		var gap := (bird.p as Vector3)-(other.p as Vector3)
		var d := gap.length()
		if d < 0.45 and d > 0.001: want += gap/d*(0.45-d)*6.0
	bird.v = (bird.v as Vector3).move_toward(want,STEER*step)
	if bird.state == "landing" and reach < 0.5: bird.ride = clampf(1.0-reach/0.5,0.0,1.0)
	p += (bird.v as Vector3)*step
	if ground != null: p.y = maxf(p.y,float(ground)+0.15)
	bird.p = p
	var v: Vector3 = bird.v
	var flat := Vector3(v.x,0.0,v.z)
	if flat.length_squared() > 0.01: bird.heading = (bird.heading as Vector3).slerp(flat.normalized(),minf(step*8.0,1.0)).normalized()
	bird.bound = fmod(float(bird.bound)+step,BOUND.x+BOUND.y)
	bird.beat = float(bird.beat)+step*BEAT

func _land(bird: Dictionary) -> void:
	var spot: Dictionary = bird.target
	bird.v = Vector3.ZERO
	if spot.kind == "perch":
		bird.state = "perched"
		bird.p = _perch_world(int(spot.tree),spot.perch)[0]
		bird.timer = _rng.randf_range(SIT.x,SIT.y)
		bird.ride = 1.0
		_rustle(int(spot.tree),RUSTLE*Vector3(0.6,1.0,1.0),LEAVES,false)
		_count("land_perch")
	else:
		bird.state = "hidden"
		bird.timer = _rng.randf_range(HIDE.x,HIDE.y)
		_rustle(int(spot.tree),RUSTLE,LEAVES,false)
		_count("land_crown")

## Leave the spot: out of the crown (seen leaving its edge) or off the limb.
func _take_off(bird: Dictionary, flushed: bool) -> void:
	var spot: Dictionary = bird.target
	var id := int(spot.get("tree",-1))
	if spot.get("kind","") == "perch": _held.erase(spot.key)
	if bird.state == "hidden" and trees.has(id):
		var out := Vector3(_rng.randf_range(-1,1),0.0,_rng.randf_range(-1,1)).normalized()
		var crown := _crown_at(id)
		bird.p = crown+out*float(trees[id].reach)*0.6
		bird.v = out*2.4+Vector3.UP*1.6
		if not flushed: _rustle(id,RUSTLE,LEAVES,false)
	elif bird.state in ["perched","hopping"]:
		var face: Vector3 = bird.heading
		bird.v = face*1.6+Vector3.UP*1.8
	bird.ride = 0.0
	bird.state = "flying"
	_count("take_off")

## Off to `spot`; with nowhere to go (no trees left) the bird leaves the plate.
func _fly_to(bird: Dictionary, spot: Dictionary) -> void:
	if spot.is_empty():
		bird.state = "gone"
		bird.target = {}
		return
	bird.target = spot
	bird.state = "flying"

# --- Flushes ------------------------------------------------------------------------

## The whole flock out at once (`startled`: with a big rustle and burst), wheeling
## over the grove, then off to settle in another.
func _flush(flock: Dictionary, startled: bool) -> void:
	if flock.state == "wheeling": return
	var shaken := {}
	var members := _members(flock)
	var centre := Vector3.ZERO
	for i in range(members.size()):
		var bird: Dictionary = members[i]
		var spot: Dictionary = bird.target
		if bird.state in ["hidden","perched","hopping"] and trees.has(int(spot.get("tree",-1))): shaken[int(spot.tree)] = true
		bird.delay = _rng.randf()*(0.35 if startled else 1.2)
		_take_off(bird,true)
		bird.state = "wheeling"
		bird.slot = i
		centre += bird.p
	for id: int in shaken:
		if startled: _rustle(id,FLUSH_RUSTLE,FLUSH_LEAVES,true)
		else: _rustle(id,RUSTLE*Vector3(1.3,1.3,1.0),LEAVES+3,false)
	var grove := int(flock.grove)
	var over: Vector3 = _world()*(groves[grove].centre as Vector3) if grove >= 0 and grove < groves.size() else centre/maxf(members.size(),1)
	flock.wheel = {"centre":over+Vector3.UP*WHEEL.y,"radius":WHEEL.x,"since":_clock,"until":_clock+_rng.randf_range(WHEEL_TIME.x,WHEEL_TIME.y),
		"spin":(1.0 if _rng.randf() < 0.5 else -1.0)*1.3,"angle0":_rng.randf()*TAU,"count":members.size()}
	flock.state = "wheeling"
	flock.grove = _choose_grove(grove)
	flock.roam_at = _clock+_rng.randf_range(ROAM.x,ROAM.y)
	_count("flush" if startled else "roam")

## The flock living at, or flying near, a point within `reach` metres: -1 for none.
func flock_near(point: Vector3, reach: float) -> int:
	for flock in flocks:
		if flock.state != "settled" or _clock < float(flock.calm_until): continue
		for bird in _members(flock):
			var at: Vector3 = bird.p
			if bird.state == "hidden" and trees.has(int(bird.target.get("tree",-1))): at = _crown_at(int(bird.target.tree))
			if at.distance_to(point) <= reach: return int(flock.index)
	return -1

## Flush a flock from code (probes, a director): the nearest settled one to `point`.
func startle(point: Vector3, reach := 6.0) -> bool:
	var index := flock_near(point,reach)
	if index < 0: return false
	_flush(flocks[index],true)
	return true

func _check_camera() -> void:
	var camera: Camera3D = scene.get("camera")
	if camera == null: return
	var index := flock_near(camera.global_position,CAMERA_NEAR)
	if index >= 0: _flush(flocks[index],true)

func _raised(point: Vector3, _radius: float, strength: float, kind: String, detail: Dictionary) -> void:
	if not is_instance_valid(life) or not life.active or flocks.is_empty(): return
	match kind:
		"poke":
			var index := flock_near(point,POKE_NEAR*maxf(strength,0.4))
			if index >= 0: _flush(flocks[index],true)
		"figure":
			var index := flock_near(point,FIGURE_NEAR)
			if index >= 0: _flush(flocks[index],true)
		"gust":
			# The breeze's own gust fronts (studies/gust_fronts.gd) only sway
			# the crowns; a sent gust flushes.
			if bool(detail.get("steady",false)): return
			for flock in flocks:
				if flock.state != "settled" or _clock < float(flock.calm_until): continue
				var hit := _gust_reach(detail,point,_world()*(groves[int(flock.grove)].centre as Vector3))
				if hit.y*strength > GUST_SHARE:
					var startled := flock
					_pending.append([_clock+hit.x,func() -> void: _flush(startled,true)])

## When (seconds) and how much (0..1) a gust's front reaches `p`: the same
## front as scripts/disturbance.gd describes and life_notice.gd `_front` reads.
func _gust_reach(front: Dictionary, origin: Vector3, p: Vector3) -> Vector2:
	var rel := Vector3(p.x-origin.x,0.0,p.z-origin.z)
	var along := rel.length()
	var across := 0.0
	var margin := 3.0
	var spread := margin
	if str(front.get("shape","")) == "lane":
		var way: Vector3 = front.get("way",Vector3.FORWARD)
		way.y = 0.0
		if way.length_squared() < 0.000001: return Vector2.ZERO
		way = way.normalized()
		along = rel.dot(way)
		across = absf(rel.dot(way.cross(Vector3.UP)))
		spread = float(front.get("across",0.0))+margin
	var from := float(front.get("from",0.0))
	var span := maxf(float(front.get("span",1.0)),0.01)
	if across > spread or along < from-margin or along > from+span+margin: return Vector2.ZERO
	var k := clampf((along-from)/span,0.0,1.0)
	# A gust front (studies/gust_fronts.gd) runs at a steady pace and keeps
	# its strength across the plate; a sent gust's head eases out and fades.
	var steady := bool(front.get("steady",false))
	var u := k if steady else 1.0-sqrt(1.0-k)
	var share := (1.0 if steady else 1.0-smoothstep(0.55,1.0,u))*(1.0-smoothstep(spread-margin,spread,across))
	return Vector2(float(front.get("wind_up",0.0))+u*float(front.get("run",0.0)),share)

# --- Rustle and leaves --------------------------------------------------------------

## Shiver a tree's crown and shake out `leaves` leaves (a flush's burst when `big`).
func _rustle(id: int, shiver: Vector3, leaves: int, big: bool) -> void:
	if not trees.has(id): return
	if _clock-float(_rustled.get(id,-10.0)) < 0.4 and not big: return
	_rustled[id] = _clock
	var crown := _crown_at(id)
	var field: Object = _field()
	if field != null:
		var way := Vector3(_rng.randf_range(-1,1),0.0,_rng.randf_range(-1,1)).normalized()
		field.emit_gust(crown,way,shiver.x,shiver.y*maxf(float(trees[id].reach)/0.6,0.8),shiver.z,true)
	_count("rustle")
	if leaves > 0: _shed(id,crown,big)

func _field() -> Object:
	var wind: Object = scene.get("_resident_wind")
	if wind == null: return null
	return wind.get("field")

func _shed(id: int, crown: Vector3, big: bool) -> void:
	var pool := _flush_pool if big else _leaf_pool
	var index := _next_flush if big else _next_leaf
	if big: _next_flush = (_next_flush+1)%pool.size()
	else: _next_leaf = (_next_leaf+1)%pool.size()
	var emitter: CPUParticles3D = pool[index]
	var colours := leaf_colours(trees[id])
	var ramp := Gradient.new()
	ramp.set_color(0,colours[0])
	ramp.set_color(1,colours[1])
	emitter.color_initial_ramp = ramp
	var snow := colours.size() > 2
	emitter.gravity = Vector3(0,-0.55 if snow else -1.0,0)+_wind_drift()
	emitter.emission_sphere_radius = float(trees[id].reach)*(0.9 if big else 0.6)
	emitter.global_position = crown
	emitter.restart()
	emitter.emitting = true
	_count("leaves_big" if big else "leaves")

## Two ends of a burst's colour: the season's leaves for this tree, or snow
## (a third entry marks it) when the trees are white.
func leaf_colours(tree: Dictionary) -> Array:
	var weather: Object = _weather()
	var autumn := float(weather.get("autumn")) if weather != null else 0.0
	var snow := float(weather.get("snow_cover")) if weather != null else 0.0
	if snow > 0.35: return [Color(0.92,0.94,0.97),Color(0.82,0.86,0.92),true]
	if tree.conifer: return [Color("3c5537").srgb_to_linear(),Color("5b6e3e").srgb_to_linear()]
	if autumn > 0.05:
		var stand := float(tree.stand)
		return [PondSeasons.leaf_color(stand,autumn,_rng.randf_range(0.3,1.0),_rng.randf_range(0.6,1.0)),PondSeasons.leaf_color(stand,autumn,_rng.randf(),_rng.randf_range(0.3,0.9))]
	return [Color("5f8a3a").srgb_to_linear(),Color("93ad55").srgb_to_linear()]

func _weather() -> Object:
	var precipitation: Object = scene.get("_precipitation")
	return precipitation.get("surface_weather") if precipitation != null else null

## The breeze's push on a falling leaf (m/s²).
func _wind_drift() -> Vector3:
	var air: Object = scene.get("_atmosphere")
	if air == null: return Vector3.ZERO
	var angle := float(air.get("_air_angle")) if air.get("_air_angle") != null else 0.0
	var strength := float(air.get("_air_strength")) if air.get("_air_strength") != null else 0.0
	return Vector3(cos(angle),0.0,sin(angle))*minf(strength,1.5)*0.5

func _leaf_emitter(amount: int) -> CPUParticles3D:
	var emitter := CPUParticles3D.new()
	emitter.one_shot = true
	emitter.emitting = false
	emitter.amount = amount
	emitter.lifetime = 2.6
	emitter.explosiveness = 0.75
	emitter.randomness = 0.6
	emitter.local_coords = false
	emitter.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	emitter.emission_sphere_radius = 0.5
	emitter.direction = Vector3.UP
	emitter.spread = 70.0
	emitter.initial_velocity_min = 0.4
	emitter.initial_velocity_max = 1.3
	emitter.damping_min = 0.8
	emitter.damping_max = 1.6
	emitter.particle_flag_rotate_y = true
	emitter.angular_velocity_min = -260.0
	emitter.angular_velocity_max = 260.0
	emitter.angle_min = -180.0
	emitter.angle_max = 180.0
	emitter.scale_amount_min = 0.7
	emitter.scale_amount_max = 1.2
	var leaf := QuadMesh.new()
	leaf.size = Vector2(0.06,0.04)
	var paint := StandardMaterial3D.new()
	paint.vertex_color_use_as_albedo = true
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	paint.roughness = 1.0
	leaf.material = paint
	emitter.mesh = leaf
	add_child(emitter)
	return emitter

# --- Posing -------------------------------------------------------------------------

func _pose_all(delta: float) -> void:
	for bird in birds:
		var body: Node3D = bird.body
		var shown: bool = not bird.state in ["hidden","gone"] and float(bird.delay) <= 0.0
		body.visible = shown
		if not shown: continue
		body.global_position = bird.p
		var heading: Vector3 = bird.heading
		var yaw := atan2(-heading.x,-heading.z)
		var pitch := 0.0
		var airborne: bool = bird.state in ["flying","landing","wheeling"]
		if airborne:
			var v: Vector3 = bird.v
			pitch = clampf(atan2(v.y,maxf(Vector2(v.x,v.z).length(),0.3))*0.6,-0.6,0.6)
		# A tail flick tips the body forward for a moment.
		if not airborne: pitch -= 0.18*float(body.tail_flick)
		body.global_basis = Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,pitch)*Basis.from_scale(Vector3.ONE*Body.SIZE)
		_pose_wings(bird,airborne)
		# The head snaps between glances; the tail flicks now and then.
		bird.look = lerpf(float(bird.look),float(bird.look_goal) if not airborne else 0.0,1.0-exp(-delta*14.0))
		body.head.rotation = Vector3(-0.12 if airborne else 0.0,float(bird.look),0.0)
		body.tail_flick = maxf(float(body.tail_flick)-delta*5.0,0.0)
		var spot: Dictionary = bird.target
		if bird.state in ["perched","landing","hopping"] and spot.get("kind","") == "perch" and trees.has(int(spot.tree)):
			body.ride(_world()*(trees[int(spot.tree)].local as Transform3D),spot.perch.at,OAK_BEND,float(bird.ride) if bird.state != "hopping" else 1.0)
		else:
			body.ride(Transform3D.IDENTITY,Vector3.ZERO,OAK_BEND,0.0)

## Bounding flight: beats, then wings tucked; a landing flares with quick
## shallow beats; perched, they stay folded.
func _pose_wings(bird: Dictionary, airborne: bool) -> void:
	var body: Node3D = bird.body
	if not airborne:
		body.spread_wings(false)
		for wing in body.wings: wing.rotation.z = 0.0
		return
	var landing: bool = bird.state == "landing"
	var beating: bool = landing or float(bird.bound) < BOUND.x or float((bird.v as Vector3).y) > 1.2 or bird.state == "wheeling" and float(bird.bound) < BOUND.x*1.4
	body.spread_wings(beating)
	for i in range(2):
		var side := -1.0 if i == 0 else 1.0
		var lift := sin(float(bird.beat))*(0.55 if landing else 0.95)+(0.5 if landing else 0.15)
		body.wings[i].rotation.z = side*lift if beating else 0.0

# --- For others ---------------------------------------------------------------------

## Birds in sight, for the inspector and watch mode: [{node, title, p}].
func visible_birds() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for bird in birds:
		var body: Node3D = bird.body
		if body.visible: out.append({"node":body,"title":Body.title(str(body.species)),"p":bird.p})
	return out

func _daylight() -> float:
	return float(life._daylight())

func _count(kind: String) -> void:
	counts[kind] = int(counts.get(kind,0))+1
