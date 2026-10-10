extends "res://studies/aqueduct_isle_life.gd"
## Life on the Sundered gorge isle: the aqueduct isle's (studies/
## aqueduct_isle_life.gd: the ground grid, butterflies over the flower
## patches, fireflies at dusk, the breeze ribbons, leaves, chaff and kicked
## blades, the same --no-... flags) with this isle's undergrowth (studies/
## sundered_gorge_isle_flora.gd), its songbirds' perches (`GorgeBirds`: the
## bridge's parapets and anchors, the gate tower's steps, the chapel's
## walls, the tor's pier), its leaves' anchors, its meadow, and its on-foot
## tokens (`GorgeTokens`).
const Gorge = preload("res://studies/sundered_gorge_isle_art.gd")
const GorgeFlora = preload("res://studies/sundered_gorge_isle_flora.gd")

## The meadow the chaff lies on (world rect): the west's, round the road.
const GORGE_MEADOW := Rect2(44.0,-24.0,26.0,22.0)

func setup(isle: Node3D, args: PackedStringArray) -> void:
	scene = isle
	name = "Life"
	flags = wanted(args)
	var space := scene.get_world_3d().direct_space_state
	var t := Time.get_ticks_msec()
	_read_ground(space)
	timings.ground = Time.get_ticks_msec()-t
	if flags.undergrowth:
		t = Time.get_ticks_msec()
		undergrowth = GorgeFlora.undergrowth(UNDERGROWTH_SEED,space,scene._turf,scene._outlines)
		add_child(undergrowth)
		timings.undergrowth = Time.get_ticks_msec()-t
	if flags.butterflies and scene.flora != null: _meadows()
	if flags.fireflies: _fireflies()
	if flags.wind:
		t = Time.get_ticks_msec()
		_wind()
		timings.wind = Time.get_ticks_msec()-t
	if flags.birds:
		t = Time.get_ticks_msec()
		birds = GorgeBirds.new()
		add_child(birds)
		birds.setup(scene,ground_at)
		timings.birds = Time.get_ticks_msec()-t
	if flags.tokens:
		tokens = GorgeTokens.new()
		add_child(tokens)
		tokens.setup(scene)

## The turf's grid, its rays reaching the ledges and fragments far down.
func _read_ground(space: PhysicsDirectSpaceState3D) -> void:
	var box := Rect2()
	for i in range(scene._outlines.size()):
		var outline: PackedVector2Array = scene._outlines[i]
		var b := Rect2(outline[0],Vector2.ZERO)
		for q in outline: b = b.expand(q)
		box = b if i == 0 else box.merge(b)
	box = box.grow(1.0)
	_origin = box.position
	_w = int(ceil(box.size.x/CELL))+1
	_h = int(ceil(box.size.y/CELL))+1
	_heights.resize(_w*_h)
	_standing.resize(_w*_h)
	var span := GorgeFlora.ray_span()
	var turf := PhysicsRayQueryParameters3D.new()
	turf.collision_mask = TURF_LAYER
	var all := PhysicsRayQueryParameters3D.new()
	for j in range(_h):
		for i in range(_w):
			var p := _origin+Vector2(i,j)*CELL
			turf.from = Vector3(p.x,span.x,p.y)
			turf.to = Vector3(p.x,span.y,p.y)
			var hit := space.intersect_ray(turf)
			var k := j*_w+i
			if hit.is_empty() or (hit.normal as Vector3).y < 0.3:
				_heights[k] = NAN
				_standing[k] = 0
				continue
			var y: float = (hit.position as Vector3).y
			_heights[k] = y
			all.from = turf.from
			all.to = Vector3(p.x,y-0.05,p.y)
			var top := space.intersect_ray(all)
			_standing[k] = 1 if not top.is_empty() and (top.position as Vector3).y > y+STANDING else 0

func grass_at(p: Vector2) -> float:
	if ground_at(p) == null or standing_at(p): return 0.0
	return 1.0-smoothstep(0.1,0.5,Gorge.path_wear(p))

## The wind made visible (as the aqueduct isle's), over this isle's ground.
func _wind() -> void:
	var atmosphere: Node = scene._atmosphere
	var ride := func(p: Vector2) -> Variant:
		var h: Variant = ground_at(p)
		return h if h != null else Gorge.TOP
	atmosphere.setup_wind_trails(ride,false)
	var trails: Node = atmosphere.wind_trails
	if trails.has_method("set_canopy"): trails.set_canopy(func(p: Vector2) -> float: return 0.6 if standing_at(p) else 0.0)
	var box := AABB(Vector3(_origin.x,Gorge.TOP-16.0,_origin.y),Vector3(_w*CELL,40.0,_h*CELL))
	leaf_litter = LeafLitter.new()
	leaf_litter.custom_aabb = box
	add_child(leaf_litter)
	leaf_litter.seed_from(_leaf_anchors(),ground_at)
	grass_chaff = GrassChaff.new()
	grass_chaff.custom_aabb = box
	add_child(grass_chaff)
	var count := GrassChaff.count_for(GORGE_MEADOW.get_area()*0.8)
	grass_chaff.seed_from(GrassChaff.anchors_on(grass_at,count,GORGE_MEADOW),ground_at)
	kicked_blades = KickedBlades.new()
	kicked_blades.custom_aabb = box
	add_child(kicked_blades)
	kicked_blades.setup(ground_at,grass_at)

## Loose leaves at the gate's and the tower's feet, the chapel's door and
## nave, the tor's pier, the bridge heads; by the shrubs and logs.
func _leaf_anchors() -> Array:
	var anchors: Array = [Vector2(72.0,-12.0),Vector2(72.8,-21.0),Vector2(73.0,-26.0),Vector2(103.0,-15.5),Vector2(107.5,-13.0),
		Vector2(111.5,-17.0),Vector2(114.0,-12.5),Vector2(53.0,-31.0),Vector2(76.0,-16.8),Vector2(100.5,-13.0)]
	if undergrowth != null:
		var rng := RandomNumberGenerator.new()
		rng.seed = 233
		var picks: Array = []
		for item: Dictionary in undergrowth.get_meta("records"):
			if item.asset in ["shrub","log","leaf_bed"]: picks.append(Vector2(float(item.x),float(item.z)))
		while anchors.size() < LEAF_ANCHORS and not picks.is_empty():
			anchors.append(picks.pop_at(rng.randi_range(0,picks.size()-1)))
	return anchors

# --- Songbirds on this isle's stone ---------------------------------------------------

class GorgeBirds extends "res://studies/aqueduct_isle_birds.gd":
	const Gorge = preload("res://studies/sundered_gorge_isle_art.gd")
	## [species, birds, home group].
	const GORGE_FLOCKS := [["sparrow",5,"bridge"],["goldfinch",4,"chapel"],["robin",2,"tower"],["sparrow",3,"tor"]]

	func setup(owner_scene: Node3D, ground_at: Callable) -> void:
		scene = owner_scene
		ground = ground_at
		name = "Songbirds"
		top_level = true
		_rng.seed = 4021
		groups = gorge_groups(scene.get_world_3d().direct_space_state,ground_at)
		for spec: Array in GORGE_FLOCKS:
			if not groups.has(spec[2]) or (groups[spec[2]].perches as Array).size() < 2: continue
			var flock := {"index":flocks.size(),"species":spec[0],"home":spec[2],"group":spec[2],"state":"settled",
				"calm_until":0.0,"roam_at":_rng.randf_range(ROAM.x,ROAM.y),"home_at":INF,"wheel":{}}
			flocks.append(flock)
			for i in range(int(spec[1])):
				var bird := _new_bird(flock)
				var spot := _spot(flock,bird,false)
				if spot.is_empty(): continue
				bird.target = spot
				bird.p = spot.at
				bird.heading = spot.face
				bird.state = "perched"
				bird.timer = _rng.randf_range(0.5,SIT.y)
		Disturbance.hub().raised.connect(_raised)

	## The perch groups (as the aqueduct isle's `find_groups`, its spots
	## this isle's): the bridge's parapets either side of the break and its
	## anchors' caps, the gate tower's steps and crown, the chapel's walls
	## and gable, the tor's pier and stones, the crown stones in the gap.
	static func gorge_groups(space: PhysicsDirectSpaceState3D, ground_at: Callable) -> Dictionary:
		var spots := {}
		var bridge: Array = []
		for frame_break: Array in [[Gorge.west_bridge_frame(),Gorge.WEST_BREAK],[Gorge.east_bridge_frame(),Gorge.EAST_BREAK]]:
			var xf: Transform3D = frame_break[0]
			var x := -2.0
			while x < float(frame_break[1])-0.4:
				for s: float in [-1.0,1.0]:
					var p := xf*Vector3(x,0.0,s*(Gorge.DECK_HALF-Gorge.PARAPET.x*0.5))
					bridge.append(Vector2(p.x,p.z))
				x += 0.8
		for p: Dictionary in Gorge.platforms():
			if p.chain == "crown": bridge.append(Vector2((p.at as Vector3).x,(p.at as Vector3).z))
		spots["bridge"] = bridge
		var tower: Array = []
		for block: Array in Gorge.TOWER:
			var r: Rect2 = block[0]
			var c := Gorge.tower_frame()*Vector3(r.get_center().x,0.0,r.get_center().y)
			tower.append(Vector2(c.x,c.z))
			var e := Gorge.tower_frame()*Vector3(r.end.x-0.2,0.0,r.get_center().y+0.3)
			tower.append(Vector2(e.x,e.z))
		spots["tower"] = tower
		var chapel: Array = []
		var x := 105.8
		while x < 112.4:
			for z: float in [-18.65,-11.35]: chapel.append(Vector2(x,z))
			x += 0.7
		for z: float in [-17.8,-16.0,-14.0,-12.2]: chapel.append(Vector2(104.8,z))
		spots["chapel"] = chapel
		var tor: Array = []
		for a in range(8):
			var q: Vector2 = Gorge.TOR_PIER+Vector2.from_angle(a*TAU/8.0)*0.35
			tor.append(q)
		tor.append(Vector2(Gorge.platform("mist").at.x,Gorge.platform("mist").at.z))
		spots["tor"] = tor
		var out := {}
		var ray := PhysicsRayQueryParameters3D.new()
		var ball := SphereShape3D.new()
		ball.radius = ROOM
		var room := PhysicsShapeQueryParameters3D.new()
		room.shape = ball
		for name: String in spots:
			var perches: Array = []
			var middle := Vector3.ZERO
			for p: Vector2 in spots[name]:
				ray.from = Vector3(p.x,Gorge.TOP+40.0,p.y)
				ray.to = Vector3(p.x,Gorge.TOP-20.0,p.y)
				var hit := space.intersect_ray(ray)
				if hit.is_empty() or (hit.normal as Vector3).y < 0.75: continue
				var at: Vector3 = hit.position
				var turf: Variant = ground_at.call(p)
				if turf != null and at.y < float(turf)+OVER_TURF: continue
				room.transform = Transform3D(Basis.IDENTITY,at+Vector3.UP*(ROOM+0.05))
				if not space.intersect_shape(room,1).is_empty(): continue
				var taken := false
				for q: Dictionary in perches:
					if (q.at as Vector3).distance_to(at) < 0.35: taken = true
				if taken: continue
				perches.append({"at":at})
				middle += at
			if perches.is_empty(): continue
			middle /= perches.size()
			for q: Dictionary in perches:
				var away := Vector3((q.at as Vector3).x-middle.x,0.0,(q.at as Vector3).z-middle.z)
				if away.length() < 0.2: away = Vector3(1.0,0.0,0.3)
				q.face = away.normalized()
			var forage: Array = []
			for n in range(0,perches.size(),maxi(1,perches.size()/6)):
				var base: Vector3 = perches[n].at
				for k in range(6):
					var a := TAU*k/6.0+0.4*n
					var p := Vector2(base.x+cos(a)*(2.0+float(k%3)),base.z+sin(a)*(2.0+float(k%3)))
					var turf: Variant = ground_at.call(p)
					if turf == null: continue
					room.transform = Transform3D(Basis.IDENTITY,Vector3(p.x,float(turf)+0.45,p.y))
					if not space.intersect_shape(room,1).is_empty(): continue
					forage.append(Vector3(p.x,float(turf),p.y))
			out[name] = {"name":name,"middle":middle,"perches":perches,"forage":forage}
		return out

# --- The on-foot tokens ----------------------------------------------------------

class GorgeTokens extends "res://studies/aqueduct_isle_tokens.gd":
	const Gorge = preload("res://studies/sundered_gorge_isle_art.gd")

	## Where each token stands and the move it asks for (see the doc).
	static func gorge_spots() -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		# 1. The gate tower's crown, up its fallen quarter.
		out.append({"name":"tower","at":Gorge.tower_frame()*Vector3(-1.0,9.6+0.85,-1.6),"move":"Climb the gate tower's fallen quarter to its crown"})
		# 2. The crown stones: the expert's crossing beside the rope bridge.
		var c2: Dictionary = Gorge.platform("crown_2")
		out.append({"name":"crown_stones","at":(c2.at as Vector3)+Vector3.UP*0.85,"move":"Twirled jumps over the crown stones beside the rope bridge"})
		# 3. Up the split pillar, between its slabs (wall kicks).
		var ch: Array = Gorge.chimney()
		var slot := ((ch[0][1] as float)+(ch[1][0] as float))*0.5
		out.append({"name":"chimney","at":Vector3(slot,float(ch[2])+3.3,(Gorge.CHIMNEY_Z.x+Gorge.CHIMNEY_Z.y)*0.5),"move":"Kick up the split pillar's slot from the east landing"})
		# 4. The mist stone by the curtain, off the lower ledge.
		var mist: Dictionary = Gorge.platform("mist")
		out.append({"name":"mist","at":(mist.at as Vector3)+Vector3.UP*0.85,"move":"Off the lower ledge's north end onto the stone by the fall"})
		# 5. The fallen crown, deep under the break (drop from a snapped end).
		var f: Array = Gorge.fragment("crown")
		out.append({"name":"crown","at":Vector3((f[1] as Vector2).x,float(f[3]),(f[1] as Vector2).y)+Gorge.CROWN_TOKEN,"move":"Drop from the bridge's snapped end onto the fallen crown"})
		# 6. Over the lower crossing's gap between the fragments.
		var a: Array = Gorge.fragment("chain_1")
		var b: Array = Gorge.fragment("chain_2")
		var mid := ((a[1] as Vector2)+(b[1] as Vector2))*0.5
		out.append({"name":"gap","at":Vector3(mid.x,maxf(float(a[3]),float(b[3]))+1.15,mid.y),"move":"Jump the gap between the fragments on the lower crossing"})
		# 7. The tor's top by its broken pier.
		var tp: Vector2 = Gorge.TOR_PIER+Vector2(-1.6,1.4)
		out.append({"name":"tor","at":Vector3(tp.x,Gorge.ground_w(tp.x,tp.y)+0.9,tp.y),"move":"Up the west tor's ramp to its top"})
		return out

	func setup(isle: Node3D) -> void:
		name = "Tokens"
		tokens = gorge_spots()
		for i in range(tokens.size()):
			var t: Dictionary = tokens[i]
			var holder := GlyphPickup.make(GLYPH,SIZE,float(i)*1.3,true)
			holder.name = "Token_%s" % t.name
			holder.position = t.at
			add_child(holder)
			holder.motes_on(true)
			_holders[t.name] = holder
		hud = Hud.new()
		add_child(hud)
