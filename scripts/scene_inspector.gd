extends RefCounted
## What is under a screen point in the creation shell: creatures from LandLife
## (fish, frogspawn, frogs, birds, the heron, deer, the snake and a Bigfoot
## sighting), plants, stones and landmarks from the object picker (and the ones
## Look's play has picked up), and ponds. Photo mode names what a click lands
## on with it; the camera (scripts/camera_rig.gd) highlights, frames and
## follows with it.
##
## A found thing is {kind, title, detail, point, size, base}: `point` the
## centre to look at, `size` a rough radius in metres, `base` the ground under
## it. Creatures also carry what `track` needs to find them again.

var scene: Node3D
var editor: NativeChunkEditor
var camera: Camera3D
# Arrivals heard while the session ran: {kind, p (global), hour}.
var _heard: Array[Dictionary] = []
var _ground_cache := {}
var _pond_sizes := {}

func setup(owner_scene: Node3D) -> void:
	scene = owner_scene
	editor = scene._chunk_editor
	camera = scene.camera
	var life: Node = scene.get("land_life")
	if life != null:
		life.arrived.connect(func(kind: String, p: Vector3) -> void: _hear(kind,p))
		life.moment.connect(func(kind: String, p: Vector3) -> void: _hear(kind,p))
	if editor.get("emergence") != null and editor.emergence.has_signal("tree_arrived"):
		editor.emergence.tree_arrived.connect(func(p: Vector2, _born: float) -> void: _hear("plant",Vector3(p.x,0.0,p.y)))

func _hear(kind: String, p: Vector3) -> void:
	var clock: WorldClock = scene.get("world_clock")
	_heard.append({"kind":kind,"p":p,"hour":clock.hour if clock != null else 12.0})
	if _heard.size() > 600: _heard = _heard.slice(-400)

## The ground under a screen point (global), or null. Cached within a frame.
func ground_hit(point: Vector2) -> Variant:
	var key := [Engine.get_process_frames(),point,camera.global_transform]
	if _ground_cache.get("key") == key: return _ground_cache.hit
	var hit: Variant = editor.pick(point)
	if hit != null: hit = editor.terrain.to_global(hit)
	_ground_cache = {"key":key,"hit":hit}
	return hit

## Ground height under a global point, or null off the plate.
func ground_y(point: Vector3) -> Variant:
	var local := editor.terrain.to_local(point)
	var h: Variant = editor.data.ground_height(Vector2(local.x,local.z))
	if h == null: return null
	return editor.terrain.to_global(Vector3(local.x,float(h),local.z)).y

## The nearest thing under a screen point, or {}.
func inspect(point: Vector2) -> Dictionary:
	var origin := camera.project_ray_origin(point)
	var direction := camera.project_ray_normal(point)
	var ground: Variant = ground_hit(point)
	var limit := origin.distance_to(ground)+0.6 if ground != null else INF
	var best := {}
	var best_t := limit
	for candidate: Dictionary in creatures():
		var v: Vector3 = candidate.p-origin
		var t := v.dot(direction)
		if t < 0.3 or t > best_t: continue
		if (v-direction*t).length() > float(candidate.r)+t*0.01: continue
		best_t = t
		best = candidate
	var object := _object_at(point,origin)
	if not object.is_empty() and (best.is_empty() or float(object.t) < best_t):
		best = object
		best_t = float(object.t)
	if best.is_empty():
		best = _pond_at(origin,direction,ground)
		if best.is_empty(): return {}
	if not best.has("detail"): best.detail = _creature_story(best)
	if not best.has("point"): best.point = best.p
	if not best.has("size"): best.size = float(best.get("r",0.5))*1.4
	if not best.has("base"):
		var y: Variant = ground_y(best.point)
		best.base = Vector3(best.point.x,float(y) if y != null else best.point.y-float(best.size),best.point.z)
	return best

## A plant, stone or landmark: the editor's instances, or one Look's play has
## taken up (a bent tree, a thrown rock), whose instance is hidden meanwhile.
func _object_at(point: Vector2, origin: Vector3) -> Dictionary:
	var id := editor.pick_object(point)
	var bounds := AABB()
	var play: Node = scene.get("world_play")
	if id <= 0 and play != null and play.get("owner_scene") != null:
		for key: int in play._active:
			var node: Node3D = play._active[key]
			if node is PlaySpringTree and node.pick(camera,point):
				id = key
				bounds = AABB(node.global_position-Vector3(1,0,1)*node.tree_height*0.3,Vector3(0.6,1.0,0.6)*node.tree_height)
		if id <= 0:
			var body: RigidBody3D = play.loose_props.pick(point)
			if body != null and body.get("object_id") != null and int(body.object_id) > 0:
				id = int(body.object_id)
				bounds = AABB(body.global_position-Vector3.ONE*0.5,Vector3.ONE)
	if id <= 0: return {}
	var found := object_found(id,bounds)
	if not found.is_empty(): found.t = origin.distance_to(found.point)-float(found.reach)*0.5
	return found

## A plant, stone or landmark record as a found thing, sized by its drawn
## instances (or `bounds`, or failing both its scale).
func object_found(id: int, bounds := AABB()) -> Dictionary:
	var item := editor.data.object_by_id(id)
	var play: Node = scene.get("world_play")
	if item.is_empty() and play != null and play.get("owner_scene") != null: item = play._records.get(id,{})
	if item.is_empty(): return {}
	var at := editor.terrain.to_global(editor.data.object_position(item))
	if not bounds.has_volume():
		var found := false
		for part: Dictionary in editor.selection.parts(id):
			var box: AABB = part.transform*part.mesh.get_aabb()
			bounds = bounds.merge(box) if found else box
			found = true
		# Instances that are not where the record is (none drawn yet) do not count.
		var flat := AABB(Vector3(bounds.position.x,at.y,bounds.position.z),Vector3(bounds.size.x,0.01,bounds.size.z)).grow(0.5)
		if not flat.has_point(at): bounds = AABB()
	if not bounds.has_volume():
		var scale := float(item.get("scale",1.0))*editor.terrain.global_basis.get_scale().x
		var tall := 3.0 if str(item.asset) in ["tree","layered_tree","broadleaf","redwood","joshua","bigfoot_tree","snag","birch","willow","juniper"] else 0.8
		bounds = AABB(at-Vector3(tall*0.3,0.0,tall*0.3)*scale,Vector3(tall*0.6,tall,tall*0.6)*scale)
	var center := bounds.get_center()
	var base := Vector3(center.x,bounds.position.y,center.z)
	var y: Variant = ground_y(center)
	if y != null: base.y = float(y)
	var reach := maxf(bounds.size.x,bounds.size.z)*0.5
	return {"kind":"plant","title":plant_name(str(item.asset)),"detail":_plant_story(item),"point":center,"p":center,
		"size":maxf(maxf(reach,bounds.size.y*0.5),0.3),"base":base,"reach":reach,"id":id}

## A pond whose surface the ray meets before the ground.
func _pond_at(origin: Vector3, direction: Vector3, ground: Variant) -> Dictionary:
	var local_origin := editor.terrain.to_local(origin)
	var local_direction := (editor.terrain.global_basis.inverse()*direction).normalized()
	var ground_t: float = origin.distance_to(ground) if ground != null else INF
	for index in range(editor.data.ponds.size()):
		var pond: Dictionary = editor.data.ponds[index]
		var level := float(pond.level)
		var hit: Variant = Plane(Vector3.UP,level).intersects_ray(local_origin,local_direction)
		if hit == null: continue
		var global_hit := editor.terrain.to_global(hit)
		if origin.distance_to(global_hit) > ground_t+0.05: continue
		var at := Vector2(hit.x,hit.z)
		var middle := Vector2(float(pond.x),float(pond.z))
		# The same basin: the bed stays under the surface all the way to its middle.
		var wet := true
		for step in range(13):
			var h: Variant = editor.data.ground_height(at.lerp(middle,step/12.0))
			if h == null or float(h) >= level:
				wet = false
				break
		if not wet: continue
		var size := pond_size(index)
		var centre := editor.terrain.to_global(Vector3(middle.x,level,middle.y))
		return {"kind":"pond","title":"Pond","detail":"still water","point":centre+Vector3.UP*0.2,"p":centre,"size":size,"base":centre,"reach":size}
	return {}

func pond_size(index: int) -> float:
	var pond: Dictionary = editor.data.ponds[index]
	var key := var_to_bytes([pond,hash(editor.data.heights)]).hex_encode()
	if _pond_sizes.get(index,{}).get("key","") == key: return _pond_sizes[index].size
	var reach := 0.0
	for d in editor.data.pond_fetch(Vector2(float(pond.x),float(pond.z)),float(pond.level)): reach = maxf(reach,d)
	var size := maxf(reach,0.8)*editor.terrain.global_basis.get_scale().x
	_pond_sizes[index] = {"key":key,"size":size}
	return size

## Every creature on show: {kind, title, p (global), r, and how to find it again}.
func creatures() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	var life: Node = scene.get("land_life")
	if life == null or not life.get("active"): return found
	var names := {"fish":"Fish","spawn":"Frogspawn","frog":"Frog","bird":"Bird"}
	var radius := {"fish":0.35,"spawn":0.45,"frog":0.35,"bird":0.6}
	for kind: String in names:
		for site: Dictionary in life.present(kind):
			var p: Vector3 = site.get("p",Vector3.ZERO)
			if kind == "bird" and life.get("_birds") != null and int(site.get("slot",-1)) >= 0:
				var bird: Dictionary = life._birds.birds[int(site.slot)]
				p = life._bird_node.to_global(Vector3(float(bird.x),float(bird.y),float(bird.z)))
			else:
				p = life.to_global(p)
			found.append({"kind":kind,"title":str(site.get("title",names[kind])),"p":p,"r":radius[kind],"site":site})
	var snakes: Node3D = life.get("snakes")
	if snakes != null and snakes.visible and not str(snakes.showing()).is_empty():
		found.append({"kind":"snake","title":"Grass snake","p":snakes.to_global(snakes._head_pos)+Vector3.UP*0.08,"r":0.45,"node":snakes})
	var moments: Node = life.get("moments")
	if moments == null: return found
	var heron: Node3D = moments.get("_heron")
	if heron != null and heron.visible:
		found.append({"kind":"heron","title":"Grey heron","p":heron.global_position+Vector3.UP*0.55,"r":0.7,"node":heron,"lift":0.55})
	for deer: Dictionary in moments.get("_deer"):
		var root: Node3D = deer.root
		if root.visible: found.append({"kind":"deer","title":"Deer","p":root.global_position+Vector3.UP*0.8,"r":0.8,"node":root,"lift":0.8})
	var bigfoot: Node3D = moments.get("bigfoot")
	if bigfoot != null and bigfoot.showing():
		found.append({"kind":"bigfoot","title":"Something tall","p":bigfoot.global_position+Vector3.UP*1.2,"r":1.0,"detail":"gone if you look too long","node":bigfoot,"lift":1.2})
	return found

## Where a found creature is now, or null once it has gone. Plants and ponds
## stay where they are.
func track(found: Dictionary) -> Variant:
	if not str(found.get("kind","")) in ["fish","spawn","frog","bird","snake","heron","deer","bigfoot"]: return found.get("point")
	var node: Node3D = found.get("node")
	if node != null:
		if not is_instance_valid(node) or not node.is_visible_in_tree(): return null
		if found.kind == "snake": return node.to_global(node._head_pos)+Vector3.UP*0.08 if not str(node.showing()).is_empty() else null
		if found.kind == "bigfoot" and not node.showing(): return null
		return node.global_position+Vector3.UP*float(found.get("lift",0.5))
	# Sites are dictionaries LandLife keeps while the creature stays.
	for candidate: Dictionary in creatures():
		if candidate.kind == found.kind and is_same(candidate.get("site"),found.get("site")): return candidate.p
	return null

## "arrived at dawn" when this session saw it come, otherwise a quiet fallback.
func _creature_story(found: Dictionary) -> String:
	var heard := _heard_near(str(found.kind),found.p,3.0 if found.kind in ["fish","frog","spawn"] else 8.0)
	if not heard.is_empty(): return ("landed " if found.kind == "heron" else "stepped out " if found.kind == "deer" else "arrived ")+when(float(heard.hour))
	return {"heron":"fishing the shallows","deer":"at the forest edge","snake":"basking by the water"}.get(found.kind,"settled here")

## The world's hour as a word: dawn, morning, midday, afternoon, dusk, evening or night.
static func part_of_day(hour: float) -> String:
	var h := fposmod(hour,24.0)
	if h >= 4.5 and h < 7.5: return "dawn"
	if h < 11.0 and h >= 7.5: return "morning"
	if h < 14.0 and h >= 11.0: return "midday"
	if h < 17.0 and h >= 14.0: return "afternoon"
	if h < 20.0 and h >= 17.0: return "dusk"
	if h < 22.5 and h >= 20.0: return "evening"
	return "night"

## "at dawn", "in the morning", "at night".
static func when(hour: float) -> String:
	var part := part_of_day(hour)
	return ("in the " if part in ["morning","afternoon","evening"] else "at ")+part

func _heard_near(kind: String, p: Vector3, reach: float) -> Dictionary:
	var best := {}
	var best_d := reach
	for entry: Dictionary in _heard:
		if entry.kind != kind: continue
		var d: float = entry.p.distance_to(p) if kind != "plant" else Vector2(entry.p.x,entry.p.z).distance_to(Vector2(p.x,p.z))
		if d <= best_d:
			best_d = d
			best = entry
	return best

func _plant_story(item: Dictionary) -> String:
	match str(item.get("source","")):
		"emerged":
			var heard := _heard_near("plant",Vector3(float(item.x),0.0,float(item.z)),0.05)
			return "took root "+when(float(heard.hour)) if not heard.is_empty() else "grew here on its own"
		"hand": return "placed by hand"
	return "part of the land"

static func plant_name(asset: String) -> String:
	asset = asset.rstrip("_0123456789")
	const NAMES := {"tree":"Tree","layered_tree":"Pine","broadleaf":"Broadleaf","redwood":"Redwood","joshua":"Joshua tree",
		"birch":"Birch","willow":"Willow","juniper":"Juniper",
		"cactus":"Cactus","fern":"Fern","bush":"Bush","shrub":"Shrub","rock":"Rock","stone":"Stone","boulder":"Boulder",
		"log":"Fallen log","stump":"Stump","flower":"Flowers","mushroom":"Mushrooms","reed":"Reeds","arch":"Stone arch",
		"bigfoot_tree":"Old tree","snag":"Snag"}
	if NAMES.has(asset): return NAMES[asset]
	for key: String in NAMES:
		if asset.ends_with("_"+key): return asset.trim_suffix("_"+key).capitalize()+" "+str(NAMES[key]).to_lower()
	return asset.replace("_"," ").capitalize()
