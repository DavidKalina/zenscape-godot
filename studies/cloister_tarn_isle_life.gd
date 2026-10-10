extends "res://studies/aqueduct_isle_life.gd"
## Life on the cloister tarn (studies/cloister_tarn_isle.gd): the aqueduct
## isle's life (studies/aqueduct_isle_life.gd: undergrowth, butterflies,
## fireflies, songbirds on the stones, the wind made visible, on-foot
## tokens) on this isle's ground. The aqueduct isle's parts read its own
## art (its paths, its landmarks) by name, so the ones that do are
## parameterized copies here: the grass and flowers (`grow_flora`, the
## aqueduct isle's `Flora.grow` with this isle's bare ground: its paths,
## the water and the water's edge), the undergrowth (`grow_undergrowth`),
## the songbirds' perches (`TarnBirds`), the tokens (`TarnTokens`) and the
## sky's plane tokens (`TarnSky`). Each is an extraction candidate for a
## shared kit-isle builder (docs/scenic/cloister-tarn.md).
const TarnArt = preload("res://studies/cloister_tarn_isle_art.gd")
const Flora = preload("res://studies/aqueduct_isle_flora.gd")
const IsleUndergrowth = preload("res://studies/aqueduct_isle_undergrowth.gd")
const MeadowTypes = preload("res://scripts/meadow_types.gd")
const Samples = preload("res://scripts/garden_instance_samples.gd")
const Footbridge = preload("res://scripts/footbridge.gd")

## The meadow the chaff lies on (world): the south terrace and the garth's
## south-west.
const TARN_CHAFF := Rect2(TarnArt.C.x-8.0,TarnArt.C.y+15.5,16.0,8.0)

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
		undergrowth = grow_undergrowth(UNDERGROWTH_SEED,space,scene._turf,scene._outlines)
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
		birds = TarnBirds.new()
		add_child(birds)
		birds.setup(scene,ground_at)
		timings.birds = Time.get_ticks_msec()-t
	if flags.tokens:
		tokens = TarnTokens.new()
		add_child(tokens)
		tokens.setup(scene)

## Open grass at `p`: turf, nothing standing over it, off the paths and the
## water.
func grass_at(p: Vector2) -> float:
	if ground_at(p) == null or standing_at(p): return 0.0
	return 1.0-smoothstep(0.1,0.5,TarnArt.bare(p))

func _wind() -> void:
	var atmosphere: Node = scene._atmosphere
	var ride := func(p: Vector2) -> Variant:
		var h: Variant = ground_at(p)
		return h if h != null else TarnArt.K
	atmosphere.setup_wind_trails(ride,false)
	var trails: Node = atmosphere.wind_trails
	if trails.has_method("set_canopy"): trails.set_canopy(func(p: Vector2) -> float: return 0.6 if standing_at(p) else 0.0)
	var box := AABB(Vector3(_origin.x,TarnArt.W-6.0,_origin.y),Vector3(_w*CELL,30.0,_h*CELL))
	leaf_litter = LeafLitter.new()
	leaf_litter.custom_aabb = box
	add_child(leaf_litter)
	leaf_litter.seed_from(_leaf_anchors(),ground_at)
	grass_chaff = GrassChaff.new()
	grass_chaff.custom_aabb = box
	add_child(grass_chaff)
	var count := GrassChaff.count_for(TARN_CHAFF.get_area()*0.8)
	grass_chaff.seed_from(GrassChaff.anchors_on(grass_at,count,TARN_CHAFF),ground_at)
	kicked_blades = KickedBlades.new()
	kicked_blades.custom_aabb = box
	add_child(kicked_blades)
	kicked_blades.setup(ground_at,grass_at)

## Loose leaves at the cloister's feet (the gap's heaps, the garth's
## corners, the lavabo's isle), by the shrubs and logs.
func _leaf_anchors() -> Array:
	var c := TarnArt.C
	var anchors: Array = [c+Vector2(-14.6,4.0),c+Vector2(-14.6,-4.0),c+Vector2(-9.5,-9.5),c+Vector2(9.5,9.5),c+Vector2(-9.5,9.5),
		c+TarnArt.SHRINE+Vector2(2.6,1.4),c+Vector2(14.6,-8.0),c+Vector2(0.0,17.5)]
	if undergrowth != null:
		var rng := RandomNumberGenerator.new()
		rng.seed = 233
		var picks: Array = []
		for item: Dictionary in undergrowth.get_meta("records"):
			if item.asset in ["shrub","log","leaf_bed"]: picks.append(Vector2(float(item.x),float(item.z)))
		while anchors.size() < LEAF_ANCHORS and not picks.is_empty():
			anchors.append(picks.pop_at(rng.randi_range(0,picks.size()-1)))
	return anchors

# --- The grass, flowers and undergrowth ------------------------------------------------

## The aqueduct isle's grass and flowers (studies/aqueduct_isle_flora.gd
## `grow`: its numbers, its meadow type, its drawing), placed on this isle:
## a ray onto the turf, no steeper than the rock slope, the same round the
## root; never on the paths' middles nor under or at the water.
static func grow_flora(seed_value: int, space: PhysicsDirectSpaceState3D, turf: Array, outlines: Array) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var drift := FastNoiseLite.new()
	drift.seed = seed_value+5
	drift.frequency = Flora.DRIFT_FREQUENCY
	var meadow := MeadowTypes.new(Flora.MEADOW,seed_value+9)
	meadow.rim_band = Vector2(1.0e6,2.0e6)
	var probe := _prober(space,turf,Flora.REACH)
	var ground := Flora.Ground.new()
	var records: Array = []
	var add := func(asset: String, p: Vector2, size: float, extra := {}) -> bool:
		var h: float = probe.call(p,Flora.REACH)
		if is_nan(h) or TarnArt.wet(p): return false
		var item := {"id":records.size()+1,"asset":asset,"x":p.x,"z":p.y,"angle":rng.randf()*TAU,"scale":size}
		item.merge(extra,true)
		ground.heights[item.id] = h
		records.append(item)
		return true
	var area := _area(outlines)
	var box := _box(outlines)
	for n in range(int(box.get_area()*Flora.TUFTS)):
		var p := Vector2(rng.randf_range(box.position.x,box.end.x),rng.randf_range(box.position.y,box.end.y))
		var thick := clampf(0.6+drift.get_noise_2d(p.x,p.y)*1.3,Flora.THIN,1.0)
		var worn := TarnArt.bare(p)
		if worn > Flora.PATH_BARE or rng.randf() > thick*(1.0-smoothstep(Flora.PATH_THIN,Flora.PATH_BARE,worn)): continue
		if _edge(p,outlines) < Flora.RIM: continue
		add.call("grass_tuft",p,rng.randf_range(Flora.TUFT_SIZE.x,Flora.TUFT_SIZE.y)*lerpf(1.0,0.75,worn))
	var sizes: Dictionary = meadow.type.sizes
	for n in range(int(box.get_area()*Flora.FLOWER_TRIES)):
		var p := Vector2(rng.randf_range(box.position.x,box.end.x),rng.randf_range(box.position.y,box.end.y))
		var presence := meadow.presence(p)
		var kind := meadow.kind_at(p,rng.randf())
		var keep := pow(presence,1.2)*MeadowTypes.packing(kind)*Flora.FLOWER_SHARE
		if rng.randf() > maxf(keep,Flora.STRAY): continue
		if TarnArt.bare(p) > Flora.PATH_THIN or _edge(p,outlines) < Flora.RIM+0.3: continue
		var range_of: Array = sizes.get(kind,[0.85,1.1])
		var formed: Array = MeadowTypes.form(kind,rng.randf_range(float(range_of[0]),float(range_of[1])),rng.randf()*TAU)
		var extra := {}
		var tint := MeadowTypes.tint(kind,meadow.variant(p))
		if tint != "": extra.tint = tint
		if not (formed[1] as Dictionary).is_empty(): extra.pose = formed[1]
		add.call(MeadowTypes.asset(kind),p,float(formed[0]),extra)
	return Flora._draw(records,ground,area)

## The aqueduct isle's undergrowth (studies/aqueduct_isle_undergrowth.gd
## `grow`: its kinds and numbers) on this isle: at what stands' feet and
## under the rims, a few elsewhere; off the paths and the water.
static func grow_undergrowth(seed_value: int, space: PhysicsDirectSpaceState3D, turf: Array, outlines: Array) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var probe := _prober(space,turf,IsleUndergrowth.REACH)
	var ground := Flora.Ground.new()
	var records: Array = []
	var at_foot := func(p: Vector2) -> bool:
		for k in range(8):
			if is_nan(probe.call(p+Vector2.from_angle(k*TAU/8.0+0.2)*IsleUndergrowth.FOOT,0.0)): return true
		return false
	var add := func(asset: String, p: Vector2, size: float) -> bool:
		if TarnArt.bare(p) > 0.1: return false
		var h: float = probe.call(p,IsleUndergrowth.REACH)
		if is_nan(h) or TarnArt.wet(p): return false
		var item := {"id":records.size()+1,"asset":asset,"x":p.x,"z":p.y,"angle":rng.randf()*TAU,"scale":size}
		ground.heights[item.id] = h
		records.append(item)
		return true
	var area := _area(outlines)
	var box := _box(outlines)
	for entry: Array in IsleUndergrowth.KINDS:
		var asset: String = entry[0]
		var want := int(area*float(entry[1]))
		var sizes: Vector2 = entry[2]
		var placed := 0
		for n in range(want*14):
			if placed >= want: break
			var p := Vector2(rng.randf_range(box.position.x,box.end.x),rng.randf_range(box.position.y,box.end.y))
			var e := _edge(p,outlines)
			if e < IsleUndergrowth.RIM or TarnArt.bare(p) > 0.05: continue
			if e > IsleUndergrowth.RIM_NEAR and not at_foot.call(p) and rng.randf() > IsleUndergrowth.OPEN_KEEP: continue
			if asset == "mushroom":
				var any := false
				for k in range(rng.randi_range(3,6)):
					var q := p+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(0.12,0.5)
					any = add.call(asset,q,rng.randf_range(sizes.x,sizes.y)) or any
				if any: placed += 1
			elif add.call(asset,p,rng.randf_range(sizes.x,sizes.y)):
				placed += 1
				if asset in ["fern","shrub"] and rng.randf() < 0.45:
					add.call(asset,p+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(0.6,1.2),rng.randf_range(sizes.x,sizes.y)*0.85)
	var logs := 0
	for n in range(400):
		if logs >= IsleUndergrowth.LOGS: break
		var p := Vector2(rng.randf_range(box.position.x,box.end.x),rng.randf_range(box.position.y,box.end.y))
		if _edge(p,outlines) < 2.0 or TarnArt.bare(p) > 0.02 or not at_foot.call(p): continue
		var angle := rng.randf()*TAU
		var along := Vector2.from_angle(angle)
		if is_nan(probe.call(p+along*1.2,IsleUndergrowth.REACH)) or is_nan(probe.call(p-along*1.2,IsleUndergrowth.REACH)): continue
		if add.call("log",p,rng.randf_range(IsleUndergrowth.LOG_SIZE.x,IsleUndergrowth.LOG_SIZE.y)):
			(records[-1] as Dictionary).angle = angle
			logs += 1
			for k in range(rng.randi_range(1,2)):
				add.call("fern",p+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(0.9,1.5),rng.randf_range(0.5,0.75))
	var node: Node3D = Flora._draw(records,ground,area)
	node.name = "Undergrowth"
	return node

## The turf's height under `p` (a ray from over the isle onto an island's
## ground body, its face no steeper than the rock slope's share, the same
## `reach` round it), or NAN where it isn't open turf.
static func _prober(space: PhysicsDirectSpaceState3D, turf: Array, _reach: float) -> Callable:
	var turf_ids := {}
	for body: Object in turf: turf_ids[body.get_instance_id()] = true
	var steep: float = float(Art.palette().rock_slope)*Flora.STEEP_SHARE
	var ray := PhysicsRayQueryParameters3D.new()
	return func(p: Vector2, reach: float) -> float:
		var top := NAN
		var offsets: Array = [Vector2.ZERO] if reach <= 0.0 else [Vector2.ZERO,Vector2(reach,0.0),Vector2(-reach,0.0),Vector2(0.0,reach),Vector2(0.0,-reach)]
		for off: Vector2 in offsets:
			ray.from = Vector3(p.x+off.x,TarnArt.W+60.0,p.y+off.y)
			ray.to = Vector3(p.x+off.x,TarnArt.W-12.0,p.y+off.y)
			var hit := space.intersect_ray(ray)
			if hit.is_empty() or not turf_ids.has((hit.collider as Object).get_instance_id()): return NAN
			var normal: Vector3 = hit.normal
			if normal.y <= 0.0 or sqrt(maxf(0.0,1.0-normal.y*normal.y))/normal.y > steep: return NAN
			if off == Vector2.ZERO: top = (hit.position as Vector3).y
		return top

static func _edge(p: Vector2, outlines: Array) -> float:
	for outline: PackedVector2Array in outlines:
		if Geometry2D.is_point_in_polygon(p,outline): return Art._edge_distance(p,outline)
	return -1.0

static func _area(outlines: Array) -> float:
	var area := 0.0
	for outline: PackedVector2Array in outlines: area += absf(Art._area(Array(outline)))
	return area

static func _box(outlines: Array) -> Rect2:
	var box := Rect2()
	for i in range(outlines.size()):
		var outline: PackedVector2Array = outlines[i]
		var b := Rect2(outline[0],Vector2.ZERO)
		for q in outline: b = b.expand(q)
		box = b if i == 0 else box.merge(b)
	return box

# --- The songbirds -------------------------------------------------------------------

## The aqueduct isle's songbirds (studies/aqueduct_isle_birds.gd) perched on
## this isle's stone: the wall-walks, the lavabo, the stubs and heaps, the
## bridge heads, the floating stones.
class TarnBirds extends "res://studies/aqueduct_isle_birds.gd":
	const TARN_FLOCKS := [["sparrow",5,"north_walk"],["goldfinch",4,"lavabo"],["robin",2,"gap"],["sparrow",3,"south_walk"],["goldfinch",3,"stones"]]

	func setup(owner_scene: Node3D, ground_at: Callable) -> void:
		scene = owner_scene
		ground = ground_at
		name = "Songbirds"
		top_level = true
		_rng.seed = 4021
		groups = tarn_groups(scene.get_world_3d().direct_space_state,ground_at)
		for spec: Array in TARN_FLOCKS:
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

	## The perch groups (as the aqueduct isle's `find_groups`), from this
	## isle's candidate points.
	static func tarn_groups(space: PhysicsDirectSpaceState3D, ground_at: Callable) -> Dictionary:
		var c := TarnArt.C
		var spots := {}
		var along := func(z: float, x0: float, x1: float) -> Array:
			var out: Array = []
			var x := x0
			while x <= x1:
				out.append(c+Vector2(x,z))
				x += 1.1
			return out
		spots["north_walk"] = along.call(-TarnArt.ARC,-12.0,12.0)
		spots["south_walk"] = along.call(TarnArt.ARC,-12.0,12.0)
		var lavabo: Array = []
		for dx: float in [-1.6,-0.5,0.6,1.7]:
			for dz: float in [-1.6,0.0,1.6]: lavabo.append(c+TarnArt.SHRINE+Vector2(dx,dz))
		spots["lavabo"] = lavabo
		var gap: Array = []
		for z: float in [-1.8,1.8,-3.95,3.95,-7.0,7.0,-8.2,8.2]: gap.append(c+Vector2(-TarnArt.ARC,z))
		spots["gap"] = gap
		var stones: Array = []
		for p: Dictionary in TarnArt.platforms():
			if p.chain in ["north","northeast","west"]: stones.append(Vector2((p.at as Vector3).x+0.3,(p.at as Vector3).z-0.2))
		spots["stones"] = stones
		var out := {}
		var ray := PhysicsRayQueryParameters3D.new()
		var ball := SphereShape3D.new()
		ball.radius = ROOM
		var room := PhysicsShapeQueryParameters3D.new()
		room.shape = ball
		for group_name: String in spots:
			var perches: Array = []
			var middle := Vector3.ZERO
			for p: Vector2 in spots[group_name]:
				ray.from = Vector3(p.x,TarnArt.W+40.0,p.y)
				ray.to = Vector3(p.x,TarnArt.W-20.0,p.y)
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
					if turf == null or float(turf) < TarnArt.W+0.15: continue
					room.transform = Transform3D(Basis.IDENTITY,Vector3(p.x,float(turf)+0.45,p.y))
					if not space.intersect_shape(room,1).is_empty(): continue
					forage.append(Vector3(p.x,float(turf),p.y))
			out[group_name] = {"name":group_name,"middle":middle,"perches":perches,"forage":forage}
		return out

# --- The tokens ----------------------------------------------------------------------

## The on-foot tokens (the aqueduct isle's, studies/aqueduct_isle_tokens.gd),
## each where it asks for a move.
class TarnTokens extends "res://studies/aqueduct_isle_tokens.gd":

	static func tarn_spots() -> Array[Dictionary]:
		var c := TarnArt.C
		var out: Array[Dictionary] = []
		# 1. Over the cloister's gap, between the two snapped piers: a twirled
		# hop from one stub to the other takes it.
		out.append({"name":"stubs","at":Vector3(c.x-TarnArt.ARC,TarnArt.K+3.75,c.y),"move":"Hop the snapped piers across the cloister's gap"})
		# 2. On the lavabo's top: out over the stepping stones, up its drums.
		var sm := TarnArt.world(TarnArt.SHRINE)
		out.append({"name":"lavabo","at":Vector3(sm.x,TarnArt.SHRINE_TOP+TarnArt.WALK+0.85,sm.y),"move":"Out over the stepping stones and up the lavabo's fallen drums"})
		# 3. The crag's summit.
		var crag := TarnArt.world(TarnArt.way(126.0)*TarnArt.RIM/TarnArt.sq(TarnArt.way(126.0)))
		out.append({"name":"crag","at":Vector3(crag.x,TarnArt.K+TarnArt.CRAG_TOP+0.85,crag.y),"move":"Up the ridge and the carved stair to the crag's summit"})
		# 4. On the water gate's raised walk: round the wall-walk.
		out.append({"name":"gate","at":Vector3(c.x+TarnArt.ARC,TarnArt.K+TarnArt.GATE_WALK+0.85,c.y),"move":"Round the wall-walk to the water gate"})
		# 5. Over the north face's fourth rock tier: climbed tier by tier out
		# of the alley, a jump-catch each.
		var n := ceili((TarnArt.ground(c.x,c.y-22.6)-TarnArt.K)/TarnArt.TIER)
		var depth := (TarnArt.RIM-TarnArt.CREST_W-TarnArt.BACK)/n
		var z := c.y-(TarnArt.BACK+depth*3.5)
		out.append({"name":"tiers","at":Vector3(c.x,TarnArt.ground(c.x,z)+0.85,z),"move":"Climb the north face's rock tiers out of the alley"})
		# 6. Hung over the north-east rope bridge's middle: jump on the deck.
		for b: Dictionary in TarnArt.bridges():
			if b.name == "northeast_bridge":
				var mid: Vector3 = (b.a as Vector3).lerp(b.b,0.5)
				out.append({"name":"bridge","at":mid+Vector3.UP*(Footbridge.lift(Vector2(b.b.x-b.a.x,b.b.z-b.a.z).length(),0.5)+1.75),"move":"Jump on the swaying rope bridge"})
		# 7. Between the north chain's second and third stones.
		var s2: Dictionary = TarnArt.platform("north_2")
		var s3: Dictionary = TarnArt.platform("north_3")
		if not s2.is_empty() and not s3.is_empty():
			out.append({"name":"stones","at":((s2.at as Vector3)+(s3.at as Vector3))*0.5+Vector3.UP*1.0,"move":"Hop the floating stones from the crag to the north isle"})
		return out

	func setup(_isle: Node3D) -> void:
		name = "Tokens"
		tokens = tarn_spots()
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

# --- The sky's plane tokens -------------------------------------------------------------

## The aqueduct isle's sky round this isle, its plane tokens this isle's
## line: in over the west saddle, through the cloister's gap between the
## stubs, skimming the tarn, through the water gate, down the fall.
class TarnSky extends "res://studies/aqueduct_isle_sky.gd":

	static func tarn_tokens() -> Array:
		var c := TarnArt.C
		var lip := TarnArt.lip()
		return [
			["ct:gap","air","thread",[Vector3(c.x-TarnArt.ARC-6.0,TarnArt.K+2.2,c.y),Vector3(c.x-TarnArt.ARC,TarnArt.K+1.4,c.y)]],
			["ct:skim","air","skim",[Vector3(c.x-5.0,TarnArt.W+1.0,c.y+1.5),Vector3(c.x+4.0,TarnArt.W+1.0,c.y+1.0)]],
			["ct:gate","air","thread",[Vector3(c.x+TarnArt.ARC,TarnArt.W+1.2,c.y)]],
			["ct:fall","air","dive",[Vector3(lip.x+3.0,TarnArt.W-5.0,lip.z),Vector3(lip.x+5.0,TarnArt.W-12.0,lip.z)]],
			["ct:keel","under","keel",[Vector3(c.x,TarnArt.W-TarnArt.KEEL-4.0,c.y)]],
		]

	func _build_tokens() -> void:
		collectibles = SkyCollectibles.new()
		collectibles.cells = SkyCells.new()
		collectibles.seed_value = TOKEN_SEED
		collectibles._trails_laid = true
		add_child(collectibles)
		var lines: Array = []
		for t: Array in tarn_tokens():
			lines.append(Lines.line(t[0],t[1],t[2],PackedVector3Array(t[3]),TOKEN_SEED))
		collectibles.add_source("cloister",lines)
