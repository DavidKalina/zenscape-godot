extends Node3D
## One resident per campsite record. Terrain owns camp/inventory persistence;
## this controller owns interruptible outings and temporary movement state.
##
## Everything it needs from the ground comes through a `CampsiteWorld`, so the
## same controller runs on the editor's chunk (`setup`) and on a generated
## island (`bind` with `CampsiteWorld.for_island`). Camper positions are in
## the world's document-local frame; parent this node so that frame is its own.
signal story_event(message: String)
const Model = preload("res://scripts/campsite_model.gd")
var world: CampsiteWorld
var camps := {}
var sight = preload("res://scripts/forest_visibility.gd").new()
var dirty := true
var clock := 0.0
var sense_in := 0.0
var bigfoot_route := PackedVector3Array()
var bigfoot_waypoint := 0
var bigfoot_activity := ""
var bigfoot_camp := -1
var bigfoot_wait := 0.0
var visit_in := 8.0
var completed_visits := 0
var visits := 0
var react_in := 0.0
var events: Array[String] = []
var stolen_food := 0
var photographs := 0
var scares := 0

## The playable chunk: the fidelity scene's editor, navigation and resident.
func setup(owner_scene: Node) -> void:
	bind(CampsiteWorld.for_scene(owner_scene))
	owner_scene._chunk_editor.play_geometry_changed.connect(func() -> void: dirty = true)

## Any ground at all. Campers already standing are sent home to the new one.
func bind(camp_world: CampsiteWorld) -> void:
	if world != null: reset()
	world = camp_world
	dirty = true

func reset() -> void:
	for entry in camps.values(): entry.actor.free(); entry.glow.free()
	camps.clear()
	_cancel_bigfoot()
	dirty = true

func _event(message: String) -> void:
	events.append("%.1f %s" % [clock,message])
	story_event.emit(message)
	if events.size()>100: events.pop_front()

func _sync() -> void:
	var present := {}
	for record in world.data.objects:
		if record.asset != "campsite": continue
		var id := int(record.id)
		present[id] = true
		var pose := Transform3D(Basis(Vector3.UP,float(record.angle)),world.data.object_position(record))
		if not camps.has(id): camps[id] = _create(id,pose,str(record.get("camper","photographer")))
		var entry: Dictionary = camps[id]
		if entry.pose != pose or entry.size != float(record.scale):
			entry.pose = pose
			entry.size = float(record.scale)
			entry.initialized = false
			if bigfoot_camp == id: _cancel_bigfoot()
		entry.record = record.duplicate(true)
		var entrance: Variant = world.navigation.nearest_safe(pose*Vector3(0,0,2.25*float(record.scale)))
		entry.home = entrance
		entry.glow.position = pose*Vector3(1.55*float(record.scale),0.6,1.15*float(record.scale))
		entry.actor.visible = entrance != null
		if entrance == null: continue
		if not entry.initialized or not world.navigation.is_safe(entry.actor.position):
			entry.actor.position = entrance
			entry.initialized = true
			entry.route = PackedVector3Array()
			entry.state = "return" if record.get("carrying",false) else "rest"
			entry.wait = 2.0
		elif not entry.route.is_empty():
			var destination: Vector3 = entry.route[-1]
			if not _route(entry,destination,entry.state):
				entry.route = PackedVector3Array()
				entry.state = "return"
	for id in camps.keys():
		if present.has(id): continue
		camps[id].actor.free()
		camps[id].glow.free()
		camps.erase(id)
		if bigfoot_camp == id: _cancel_bigfoot()
	if not bigfoot_activity.is_empty() and not bigfoot_route.is_empty():
		bigfoot_route = world.navigation.path(world.resident.creature.position,bigfoot_route[-1])
		bigfoot_waypoint = 1
		if bigfoot_route.is_empty(): _cancel_bigfoot()
	if camps.is_empty():
		sight.parts.clear()
		sight.faces_by_mesh.clear()
	else: sight.refresh(world)
	dirty = false

func _create(id: int, pose: Transform3D, variant: String) -> Dictionary:
	var actor := Model.human(variant)
	actor.name = "Camper_%d" % id
	add_child(actor)
	var lamp := SpotLight3D.new()
	actor.add_child(lamp)
	lamp.position = Vector3(0.22,1.40,0.30)
	lamp.rotation.y = PI
	lamp.spot_range = 16
	lamp.spot_angle = 18
	lamp.light_color = Color("fff0d2")
	lamp.light_energy = 18
	lamp.shadow_enabled = true
	lamp.light_volumetric_fog_energy = 4
	var mark := Label3D.new()
	actor.add_child(mark)
	mark.position.y = 2.25
	mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mark.font_size = 40
	var flash := OmniLight3D.new()
	actor.add_child(flash)
	flash.position = Vector3(0,1.6,0.38)
	flash.light_energy = 6
	flash.omni_range = 6
	flash.visible = false
	var carried := Model.branch()
	actor.add_child(carried)
	carried.position = Vector3(0,1.1,0.48)
	carried.scale *= 0.7
	carried.visible = false
	var glow := OmniLight3D.new()
	add_child(glow)
	glow.light_color = Color("ffbf7d")
	glow.light_energy = 1.3
	glow.omni_range = 4
	return {"actor":actor,"flash":flash,"flash_time":0.0,"photo_view":0.0,"last_photo":-1,"last_scare":-1,"variant":variant,"lamp":lamp,"mark":mark,"carried":carried,"glow":glow,"pose":pose,"size":0.0,"initialized":false,"home":null,"record":{},"state":"rest","wait":2.0,"route":PackedVector3Array(),"waypoint":1,"branch":-1,"suspicion":0.0,"search":0.0,"last_seen":Vector3.ZERO,"outings":0,"visible":0.0,"latched":false,"last_visit":-1,"last_search":-1}

func _route(entry: Dictionary, destination: Vector3, state: String) -> bool:
	var path: PackedVector3Array = world.navigation.path(entry.actor.position,destination)
	if path.is_empty(): return false
	entry.route = path
	entry.waypoint = 1
	entry.state = state
	return true

func _outing(entry: Dictionary) -> void:
	entry.outings += 1
	entry.branch = -1
	if int(entry.record.get("wood",0))<8:
		var branches: Array = []
		for item in world.data.objects:
			if item.asset == "fallen_branch": branches.append(item)
		branches.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return world.data.object_position(a).distance_squared_to(entry.home)<world.data.object_position(b).distance_squared_to(entry.home))
		for item in branches:
			var point: Variant = world.navigation.nearest_safe(world.data.object_position(item))
			if point == null or point.distance_to(entry.home)>11 or point.distance_to(world.data.object_position(item))>1.2: continue
			if _route(entry,point,"gather"):
				entry.branch = int(item.id)
				_event("camper leaves to gather wood")
				return
	var angle := float(entry.outings)*2.4+float(entry.record.id)
	for attempt in range(8):
		var point: Variant = world.navigation.nearest_safe(entry.home+Vector3(sin(angle+attempt),0,cos(angle+attempt))*6)
		if point != null and point.distance_to(entry.home)>3 and _route(entry,point,"explore"):
			_event("camper explores the forest")
			return
	entry.state = "rest"
	entry.wait = 8.0

func _gather(entry: Dictionary) -> void:
	var data: NativeTerrainData = world.data
	var branch := data.object_by_id(entry.branch)
	if branch.is_empty() or branch.asset != "fallen_branch" or entry.actor.position.distance_to(data.object_position(branch))>1.2: return
	data.begin_stroke()
	data.remove_object(entry.branch)
	data.update_object(int(entry.record.id),{"carrying":true})
	data.end_stroke()
	world.refresh.call()
	# `entry.record` is a copy; take the new one before the walk home decides
	# whether there is anything to deliver. (The editor's own refresh also
	# raises `dirty`, on ground that has an editor.)
	dirty = true
	_event("camper picks up a fallen branch")

func _deliver(entry: Dictionary) -> void:
	if not entry.record.get("carrying",false): return
	var data: NativeTerrainData = world.data
	data.begin_stroke()
	data.update_object(int(entry.record.id),{"carrying":false,"wood":mini(8,int(entry.record.get("wood",0))+1)})
	data.end_stroke()
	world.refresh.call()
	dirty = true
	_event("camper adds wood to the camp pile")

func _walk(entry: Dictionary, dt: float) -> bool:
	if entry.waypoint>=entry.route.size(): return true
	var next: Vector3 = entry.route[entry.waypoint]
	var delta: Vector3 = next-entry.actor.position
	var step := minf(delta.length(),dt*(1.8 if entry.state == "flee" else 0.7))
	if delta.length()>0.001:
		if not world.navigation.motion_safe(entry.actor.position,next,step):
			entry.route = PackedVector3Array()
			entry.state = "return"
			return false
		var feet: Vector3 = entry.actor.position+delta.normalized()*step
		var grounded: Variant = world.navigation._ground(feet)
		if grounded == null: entry.route = PackedVector3Array(); entry.state = "return"; return false
		entry.actor.position = grounded
		entry.actor.rotation.y = lerp_angle(entry.actor.rotation.y,atan2(delta.x,delta.z),1-exp(-8*dt))

	if entry.actor.position.distance_to(next)<0.02: entry.waypoint += 1
	return entry.waypoint>=entry.route.size()

func _advance_camper(entry: Dictionary,dt: float, sense: bool) -> void:
	if entry.home == null: return
	entry.flash_time = maxf(0,entry.flash_time-dt)
	entry.flash.visible = entry.flash_time>0
	entry.actor.pose(dt,not entry.route.is_empty(),entry.state,entry.record.get("carrying",false),1.8 if entry.state == "flee" else 0.7)
	entry.lamp.visible = world.night.call()
	entry.glow.visible = entry.lamp.visible
	entry.carried.visible = entry.record.get("carrying",false)
	entry.search = maxf(0,entry.search-dt)
	if not world.resident_active(): entry.visible = 0.0
	if sense and world.resident_active():
		entry.visible = sight.exposure(entry.lamp,world.resident.creature.position,2.8*world.resident.creature.actor.scale.y,true,world.night.call())
	entry.suspicion = clampf(entry.suspicion+dt*(entry.visible*1.6 if entry.visible>0 else -0.7),0,1)
	if entry.suspicion<0.1: entry.latched = false
	if entry.state not in ["photo","flee"] and entry.suspicion>=1 and entry.search<=0 and not entry.latched and entry.last_search != entry.outings:
		entry.last_search = entry.outings
		entry.latched = true
		entry.last_seen = world.resident.creature.position
		entry.search = 9.0
		entry.route = PackedVector3Array()
		entry.state = "search"
		entry.wait = 3.0
		_event("camper investigates a glimpse")
	# A photo needs a fresh, sustained view after the initial glimpse. Occlusion
	# immediately resets it, so there is no photograph through a tree or tent.
	entry.photo_view = entry.photo_view+dt if entry.visible>=0.66 and entry.search>0 else 0.0
	if entry.variant == "photographer" and entry.photo_view>=0.65 and entry.last_photo != entry.outings and entry.state not in ["photo","flee"]:
		entry.last_photo = entry.outings
		entry.route = PackedVector3Array()
		entry.state = "photo"
		entry.wait = 0.65
		_event("camper raises the camera")
	if entry.visible>0 and world.resident_active() and entry.state != "photo" and entry.last_scare != entry.outings and entry.actor.position.distance_to(world.resident.creature.position)<2.6:
		entry.last_scare = entry.outings
		entry.search = 6.0
		if _route(entry,entry.home,"flee"):
			scares += 1
			_event("startled camper runs back to the tent")
	entry.mark.text = "!" if entry.state == "flee" else "?" if entry.search>0 else ""
	if not entry.route.is_empty():
		if _walk(entry,dt):
			entry.route = PackedVector3Array()
			if entry.state == "gather": entry.state = "collect"; entry.wait = 1.7
			elif entry.state in ["return","flee"]: _deliver(entry); entry.state = "rest"; entry.wait = 10
			else: entry.state = "look"; entry.wait = 3
		return
	var facing: Vector3 = entry.last_seen-entry.actor.position if entry.search>0 else entry.pose.basis.z
	entry.actor.rotation.y = lerp_angle(entry.actor.rotation.y,atan2(facing.x,facing.z)+sin(clock*0.45)*0.55,1-exp(-2*dt))
	entry.wait -= dt
	if entry.wait>0: return
	match entry.state:
		"photo":
			# Recheck line of sight at shutter time, not only when the camera rises.
			var visible_now: float = sight.exposure(entry.lamp,world.resident.creature.position,2.8*world.resident.creature.actor.scale.y,true,world.night.call()) if world.resident_active() else 0.0
			if visible_now>=0.66:
				var photos := mini(999,int(entry.record.get("photos",0))+1)
				_update_inventory(entry,{"photos":photos})
				entry.flash_time = 0.15
				photographs += 1
				_event("camper photographs Bigfoot")
			else: _event("Bigfoot vanishes before the shutter")
			entry.state = "return"
		"rest": _outing(entry)
		"collect": _gather(entry); entry.state = "return"
		"search":
			var point: Variant = world.navigation.nearest_safe(entry.last_seen)
			if point == null or not _route(entry,point,"investigate"): entry.state = "return"
		"look": entry.state = "return"
		"return":
			if not _route(entry,entry.home,"return"): entry.wait = 3

func _update_inventory(entry: Dictionary, changes: Dictionary) -> void:
	var data: NativeTerrainData = world.data
	if data.update_object(int(entry.record.id),changes):
		entry.record.merge(changes,true)
		world.refresh.call()

func _cancel_bigfoot() -> void:
	if not bigfoot_activity.is_empty() and world.resident != null and world.resident.creature != null: world.resident.creature.stop_walking()
	bigfoot_activity = ""
	bigfoot_route.clear()
	bigfoot_camp = -1

func _take_bigfoot(path: PackedVector3Array, activity: String, camp_id: int) -> void:
	world.resident.routine.cancel("campsite encounter")
	world.resident.brain.reset_behavior()
	bigfoot_route = path
	bigfoot_waypoint = 1
	bigfoot_activity = activity
	bigfoot_camp = camp_id
	bigfoot_wait = 0
	react_in = 8
	_event("Bigfoot "+activity)

func _bigfoot(dt: float,sense: bool) -> bool:
	if not world.resident_active(): _cancel_bigfoot(); return false
	# Player ownership wins even when a carried/thrown resident briefly becomes
	# idle. Camps must never issue walk commands alongside world-play handling.
	if world.resident_owned():
		_cancel_bigfoot()
		return false
	visit_in -= dt
	react_in = maxf(0,react_in-dt)
	if sense and react_in<=0 and world.resident.creature.can_roam() and bigfoot_activity != "hiding":
		for id in camps:
			var entry: Dictionary = camps[id]
			if entry.visible<=0 or entry.suspicion<0.45: continue
			var best: Array = []
			for x in range(-12,13,3):
				for z in range(-12,13,3):
					var point: Variant = world.navigation._ground(Vector3(x,0,z))
					if point == null or not world.navigation.is_safe(point) or sight.exposure(entry.lamp,point,2.8*world.resident.creature.actor.scale.y,false)>0: continue
					best.append(point)
			best.sort_custom(func(a: Vector3,b: Vector3) -> bool: return a.distance_squared_to(world.resident.creature.position)<b.distance_squared_to(world.resident.creature.position))
			for point in best.slice(0,5):
				var path: PackedVector3Array = world.navigation.path(world.resident.creature.position,point)
				if not path.is_empty(): _take_bigfoot(path,"hiding",id); break
			break
	if not bigfoot_activity.is_empty():
		if not world.resident.creature.can_roam(): _cancel_bigfoot(); return false
		if bigfoot_waypoint<bigfoot_route.size():
			if not world.navigation.motion_safe(world.resident.creature.position,bigfoot_route[bigfoot_waypoint],world.resident.creature.walking_speed(1.35)*dt):
				_cancel_bigfoot()
				return false
			if world.resident.creature.walk_step(bigfoot_route[bigfoot_waypoint],1.35 if bigfoot_activity == "hiding" else 0.75,dt): bigfoot_waypoint += 1
		else:
			world.resident.creature.stop_walking()
			bigfoot_wait += dt
			if camps.has(bigfoot_camp): world.resident.creature.notice(camps[bigfoot_camp].pose.origin+Vector3.UP)
			if bigfoot_activity == "visiting camp" and camps.has(bigfoot_camp):
				var entry: Dictionary = camps[bigfoot_camp]
				if entry.actor.position.distance_to(entry.home)<3:
					_cancel_bigfoot()
					visit_in = 8
					return false
			if bigfoot_wait>3:
				if bigfoot_activity == "visiting camp":
					completed_visits += 1
					_event("Bigfoot finishes inspecting camp")
					if camps.has(bigfoot_camp):
						var entry: Dictionary = camps[bigfoot_camp]
						var food := int(entry.record.get("food",3))
						if food>0:
							_update_inventory(entry,{"food":food-1})
							stolen_food += 1
							_event("Bigfoot steals a snack from camp")
				_cancel_bigfoot()
				visit_in = 18
		return true
	if visit_in>0 or not world.resident.creature.can_roam() or not world.resident.routine.active.is_empty(): return false
	visit_in = 8
	for id in camps:
		var entry: Dictionary = camps[id]
		if entry.home == null or entry.actor.position.distance_to(entry.home)<3: continue
		# Alternate opportunities instead of commandeering every outing.
		if int(entry.outings)%2 == 0 or entry.last_visit == entry.outings: continue
		var path: PackedVector3Array = world.navigation.path(world.resident.creature.position,entry.home)
		if path.is_empty(): continue
		entry.last_visit = entry.outings
		visits += 1
		_take_bigfoot(path,"visiting camp",id)
		return true
	return false

## One frame. True while a camp outing owns Bigfoot's legs.
func advance(delta: float) -> bool:
	if world == null or world.paused.call(): return not bigfoot_activity.is_empty()
	if world.busy.call(): return not bigfoot_activity.is_empty()
	if dirty: _sync()
	var dt := minf(delta,0.05)
	if dt<=0: return not bigfoot_activity.is_empty()
	clock += dt
	sense_in -= dt
	var sense := sense_in<=0
	if sense: sense_in = 0.15
	for entry in camps.values(): _advance_camper(entry,dt,sense)
	return not bigfoot_activity.is_empty() if dirty else _bigfoot(dt,sense)
