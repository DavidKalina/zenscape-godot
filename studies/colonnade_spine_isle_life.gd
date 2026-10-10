extends "res://studies/aqueduct_isle_life.gd"
## Life on the colonnade spine (studies/colonnade_spine_isle.gd): the
## aqueduct isle's (studies/aqueduct_isle_life.gd: undergrowth, butterflies,
## fireflies, songbirds on the stones, the wind made visible, on-foot
## tokens), its stone perches, its chaff's meadow, its leaves' anchors and
## its tokens this isle's. The same flags.
const Spine = preload("res://studies/colonnade_spine_isle_art.gd")
const FootTokens = preload("res://studies/aqueduct_isle_tokens.gd")

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
		undergrowth = Undergrowth.grow(UNDERGROWTH_SEED,space,scene._turf,scene._outlines)
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
		birds = SpineBirds.new()
		add_child(birds)
		birds.setup(scene,ground_at)
		timings.birds = Time.get_ticks_msec()-t
	if flags.tokens:
		tokens = SpineTokens.new()
		add_child(tokens)
		tokens.setup(scene)

## The wind made visible, as the aqueduct isle's, the chaff on the plaza
## and the low terrace (the isle's open turf).
func _wind() -> void:
	var atmosphere: Node = scene._atmosphere
	var ride := func(p: Vector2) -> Variant:
		var h: Variant = ground_at(p)
		return h if h != null else Spine.TOP
	atmosphere.setup_wind_trails(ride,false)
	var trails: Node = atmosphere.wind_trails
	if trails.has_method("set_canopy"): trails.set_canopy(func(p: Vector2) -> float: return 0.6 if standing_at(p) else 0.0)
	var box := AABB(Vector3(_origin.x,Spine.TOP-6.0,_origin.y),Vector3(_w*CELL,40.0,_h*CELL))
	leaf_litter = LeafLitter.new()
	leaf_litter.custom_aabb = box
	add_child(leaf_litter)
	leaf_litter.seed_from(_leaf_anchors(),ground_at)
	grass_chaff = GrassChaff.new()
	grass_chaff.custom_aabb = box
	add_child(grass_chaff)
	var anchors: Array = []
	for meadow: Rect2 in [Rect2(46.0,Spine.zc(58.0)-6.0,24.0,12.0),Rect2(116.0,Spine.zc(124.0)-6.0,16.0,12.0)]:
		anchors.append_array(GrassChaff.anchors_on(grass_at,GrassChaff.count_for(meadow.get_area()*0.4),meadow))
	grass_chaff.seed_from(anchors,ground_at)
	kicked_blades = KickedBlades.new()
	kicked_blades.custom_aabb = box
	add_child(kicked_blades)
	kicked_blades.setup(ground_at,grass_at)

## Leaves gather at the piers' feet, the stairs' and the gate's, by the
## undergrowth's shrubs and logs.
func _leaf_anchors() -> Array:
	var anchors: Array = []
	for i in range(0,Spine.LINES.size(),2):
		var x: float = Spine.LINES[i][0]
		anchors.append(Spine.at(x+0.9,-Spine.ROW+0.8))
	anchors.append(Spine.at(Spine.GATE_X+1.6,1.5))
	anchors.append(Spine.at(Spine.STEP_L3+5.0,1.8))
	if undergrowth != null:
		var rng := RandomNumberGenerator.new()
		rng.seed = 233
		var picks: Array = []
		for item: Dictionary in undergrowth.get_meta("records"):
			if item.asset in ["shrub","log","leaf_bed"]: picks.append(Vector2(float(item.x),float(item.z)))
		while anchors.size() < LEAF_ANCHORS and not picks.is_empty():
			anchors.append(picks.pop_at(rng.randi_range(0,picks.size()-1)))
	return anchors

# --- Songbirds on the colonnade --------------------------------------------------------

## The aqueduct isle's songbirds, their perches the colonnade's: the upper
## terraces' lintels by the temple, the low terraces' lintels, the snapped
## piers' stubs, the tail's stones and the bridges' anchor posts.
class SpineBirds extends "res://studies/aqueduct_isle_birds.gd":
	const HOMES := [["sparrow",5,"upper"],["goldfinch",4,"lower"],["robin",2,"stubs"],["sparrow",3,"tail"]]

	func setup(owner_scene: Node3D, ground_at: Callable) -> void:
		scene = owner_scene
		ground = ground_at
		name = "Songbirds"
		top_level = true
		_rng.seed = 4021
		groups = spine_groups(scene.get_world_3d().direct_space_state,scene,ground_at)
		for spec: Array in HOMES:
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

	static func spine_groups(space: PhysicsDirectSpaceState3D, isle: Node3D, ground_at: Callable) -> Dictionary:
		var spots := {"upper":[],"lower":[],"stubs":[],"tail":[]}
		for l: Dictionary in Spine.lintels():
			var a: Vector3 = l.a
			var b: Vector3 = l.b
			var key := "upper" if a.x < Spine.STEP_L2 else "lower"
			var n := int(a.distance_to(b)/1.1)
			for k in range(n+1):
				var p := a.lerp(b,(k+0.5)/(n+1))
				(spots[key] as Array).append(Vector2(p.x,p.z))
		var colonnade: Node3D = isle.get("colonnade")
		if colonnade != null:
			for s: Dictionary in colonnade.get_meta("stubs"): (spots.stubs as Array).append(Vector2((s.at as Vector3).x,(s.at as Vector3).z))
		for p: Dictionary in Spine.platforms(): (spots.tail as Array).append(Vector2((p.at as Vector3).x+0.3,(p.at as Vector3).z-0.2))
		return perches_from(space,spots,ground_at)

	## The perch groups from candidate points (as the aqueduct isle's
	## `find_groups` lays them; its own here, so it reads any isle's spots).
	static func perches_from(space: PhysicsDirectSpaceState3D, spots: Dictionary, ground_at: Callable) -> Dictionary:
		var out := {}
		var ray := PhysicsRayQueryParameters3D.new()
		var ball := SphereShape3D.new()
		ball.radius = ROOM
		var room := PhysicsShapeQueryParameters3D.new()
		room.shape = ball
		for group: String in spots:
			var perches: Array = []
			var middle := Vector3.ZERO
			for p: Vector2 in spots[group]:
				ray.from = Vector3(p.x,Spine.TOP+40.0,p.y)
				ray.to = Vector3(p.x,Spine.TOP-20.0,p.y)
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
			out[group] = {"name":group,"middle":middle,"perches":perches,"forage":forage}
		return out

# --- On-foot tokens --------------------------------------------------------------------

## The aqueduct isle's on-foot tokens, set where this isle asks for a move.
class SpineTokens extends "res://studies/aqueduct_isle_tokens.gd":
	func setup(isle: Node3D) -> void:
		name = "Tokens"
		tokens = spine_spots(isle)
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

	## Where each stands and the move it asks for.
	static func spine_spots(isle: Node3D) -> Array[Dictionary]:
		var out: Array[Dictionary] = []
		var colonnade: Node3D = isle.get("colonnade") if isle != null else null
		for l: Dictionary in Spine.lintels():
			if float(l.side) != 0.0: continue
			var mid: Vector3 = ((l.a as Vector3)+(l.b as Vector3))*0.5
			var low := mid.x > Spine.STEP_L2
			out.append({"name":"cross_low" if low else "cross_high","at":mid+Vector3.UP*0.85,
				"move":"Climb onto the lintels (the drum and the stub by the start) and cross between the rows" if low else "From the plaza's edge, catch the next terrace's lintels and cross between the rows"})
		if colonnade != null:
			var w: Array = colonnade.get_meta("wedged")
			out.append({"name":"cleft","at":((w[0] as Vector3)+(w[1] as Vector3))*0.5+Vector3.UP*1.0,
				"move":"Hop down the drums wedged in the cleft"})
		for name: String in ["south_3","pulpit"]:
			var s := Spine.slab(name)
			var c := Spine.slab_at(s)
			out.append({"name":name,"at":Vector3(c.x,Spine.TOP+float(s[4])+0.85,c.y),
				"move":"Up the shelves jutting from the south flank" if name == "south_3" else "Drop off the podium onto the pulpit hanging over the sky"})
		var ends: Array = Spine.bridge_ends()[0]
		var a: Vector3 = ends[0]
		var b: Vector3 = ends[1]
		var span := Vector2(b.x-a.x,b.z-a.z).length()
		out.append({"name":"bridge","at":a.lerp(b,0.5)+Vector3.UP*(Spine.Footbridge.lift(span,0.5)+0.75),
			"move":"Cross the rope bridge in the tail's curl"})
		return out
