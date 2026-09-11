extends Node3D
## One resident per campsite record. Terrain owns camp/inventory persistence;
## this controller owns interruptible outings and temporary movement state.
##
## Everything it needs from the ground comes through a `CampsiteWorld`, so the
## same controller runs on the editor's chunk (`setup`) and on a generated
## island (`bind` with `CampsiteWorld.for_island`). Camper positions are in
## the world's document-local frame; parent this node so that frame is its own.
##
## One thing reaches off this ground: `crossing`, a `CrossingRoute` to a shore
## across a bridge. See "the crossing" at the foot of the file.
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

# ------------------------------------------------------------- the crossing
## How fast the deck is walked, in metres per second. Quicker than a camp
## stroll (0.7) and slower than a flight (1.8): a rope deck over a fifty metre
## drop is not somewhere to dawdle, and a minute of it is already a long shot.
const CROSS_SPEED := 1.1
const BIGFOOT_CROSS_SPEED := 0.95
## Seconds a visitor stays on the far shore before turning round.
const CAMPER_STAY := 12.0
const BIGFOOT_STAY := 6.0
## Nobody sets out again inside this many seconds of a crossing ending.
const CROSS_COOLDOWN := 30.0
## Frames of no progress on the deck before the crossing is given up, in
## seconds. A walker whose next board has been blown out of reach would
## otherwise stand there forever.
const CROSS_STALL := 8.0

## The link to the other shore, when a bridge makes one; null means this ground
## is the whole world, which is every other study and the old behaviour exactly.
var crossing: CrossingRoute
## A camp across the link has Bigfoot's legs. `fidelity_life` asks only the
## controller on the ground he lives on whether a camp owns him, so that one has
## to be told when a camp he does not live on takes him.
var borrowed := false
## Bigfoot part-way across, and the shore he set out from. `bigfoot_home` stays
## set for as long as he is a visitor here: it is what keeps his own ground's
## brain off his legs and what puts him back on the bridge afterwards.
var bigfoot_walk: CrossingWalk
var bigfoot_home: CampsiteWorld
var bigfoot_scene: Node
var bigfoot_probe := Callable()
var bigfoot_return := Vector3.ZERO
## True for the one stride between the bridgehead and the first grid node, which
## is off the navigation grid by construction (the rim is where `_safe_grounded`
## starts refusing points) and must not be motion-checked against it.
var bigfoot_offgrid := false
var bigfoot_stall := 0.0
var stay_left := 0.0
var crossings := 0
var camper_crossings := 0

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
	if bigfoot_walk != null or bigfoot_home != null: _abandon_crossing()
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
		# A camper on the deck or on the far shore is nowhere near this grid.
		# Their absence from it is not a reason to send them home.
		if _away(entry): continue
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
		bigfoot_route = world.navigation.path(world.resident_point(),bigfoot_route[-1])
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
	return {"actor":actor,"flash":flash,"flash_time":0.0,"photo_view":0.0,"last_photo":-1,"last_scare":-1,"variant":variant,"lamp":lamp,"mark":mark,"carried":carried,"glow":glow,"pose":pose,"size":0.0,"initialized":false,"home":null,"record":{},"state":"rest","wait":2.0,"route":PackedVector3Array(),"waypoint":1,"branch":-1,"suspicion":0.0,"search":0.0,"last_seen":Vector3.ZERO,"outings":0,"visible":0.0,"latched":false,"last_visit":-1,"last_search":-1,"walk":null,"shore":null,"away":0.0,"last_cross":-1,"job":""}

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
	# The pile is full and every branch within reach is on it: there is nothing
	# left to fetch and the far shore is the only thing left to look at. The
	# bridge is a reason to go somewhere, so it earns an outing of its own.
	if _crossable() and int(entry.record.get("wood",0))>=8 and entry.last_cross != entry.outings and entry.outings%3 == 0 and _begin_camper_crossing(entry):
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
	if entry.job != "":
		_advance_builder(entry,dt)
		return
	if _away(entry):
		_advance_visitor(entry,dt)
		return
	entry.flash_time = maxf(0,entry.flash_time-dt)
	entry.flash.visible = entry.flash_time>0
	entry.actor.pose(dt,not entry.route.is_empty(),entry.state,entry.record.get("carrying",false),1.8 if entry.state == "flee" else 0.7)
	entry.lamp.visible = world.night.call()
	entry.glow.visible = entry.lamp.visible
	entry.carried.visible = entry.record.get("carrying",false)
	entry.search = maxf(0,entry.search-dt)
	if not world.resident_active(): entry.visible = 0.0
	if sense and world.resident_active():
		entry.visible = sight.exposure(entry.lamp,world.resident_point(),2.8*world.resident.creature.actor.scale.y,true,world.night.call())
	entry.suspicion = clampf(entry.suspicion+dt*(entry.visible*1.6 if entry.visible>0 else -0.7),0,1)
	if entry.suspicion<0.1: entry.latched = false
	if entry.state not in ["photo","flee"] and entry.suspicion>=1 and entry.search<=0 and not entry.latched and entry.last_search != entry.outings:
		entry.last_search = entry.outings
		entry.latched = true
		entry.last_seen = world.resident_point()
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
	if entry.visible>0 and world.resident_active() and entry.state != "photo" and entry.last_scare != entry.outings and entry.actor.position.distance_to(world.resident_point())<2.6:
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
			var visible_now: float = sight.exposure(entry.lamp,world.resident_point(),2.8*world.resident.creature.actor.scale.y,true,world.night.call()) if world.resident_active() else 0.0
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
	# Another camp across the link has him. Nothing here may issue a walk.
	if borrowed:
		if not bigfoot_activity.is_empty(): _cancel_bigfoot()
		return false
	if bigfoot_walk != null: return _cross_step(dt)
	# No resident of its own, but the bridge reaches one.
	if world.resident == null: return _consider_crossing(dt)
	if not world.resident_active(): _cancel_bigfoot(); return false
	# Player ownership wins even when a carried/thrown resident briefly becomes
	# idle. Camps must never issue walk commands alongside world-play handling.
	if world.resident_owned():
		if bigfoot_home != null: _abandon_crossing()
		else: _cancel_bigfoot()
		return false
	# A visitor with nothing left to do here goes back the way he came.
	if bigfoot_home != null and bigfoot_activity.is_empty():
		stay_left -= dt
		if stay_left <= 0.0: return _begin_return()
		return true
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
			best.sort_custom(func(a: Vector3,b: Vector3) -> bool: return a.distance_squared_to(world.resident_point())<b.distance_squared_to(world.resident_point()))
			for point in best.slice(0,5):
				var path: PackedVector3Array = world.navigation.path(world.resident_point(),point)
				if not path.is_empty(): _take_bigfoot(path,"hiding",id); break
			break
	if not bigfoot_activity.is_empty():
		if not world.resident.creature.can_roam(): _cancel_bigfoot(); return false
		if bigfoot_waypoint<bigfoot_route.size():
			if not bigfoot_offgrid and not world.navigation.motion_safe(world.resident_point(),bigfoot_route[bigfoot_waypoint],world.resident.creature.walking_speed(1.35)*dt):
				_cancel_bigfoot()
				return false
			if world.resident.creature.walk_step(world.to_world(bigfoot_route[bigfoot_waypoint]),1.35 if bigfoot_activity == "hiding" else 0.75,dt):
				bigfoot_waypoint += 1
				bigfoot_offgrid = false
		else:
			world.resident.creature.stop_walking()
			bigfoot_wait += dt
			if camps.has(bigfoot_camp): world.resident.creature.notice(world.to_world(camps[bigfoot_camp].pose.origin+Vector3.UP))
			if bigfoot_activity == "visiting camp" and camps.has(bigfoot_camp):
				var entry: Dictionary = camps[bigfoot_camp]
				# The camper came home; the tent is not unattended any more, so the
				# visit is off -- unless he walked a bridge to get here. A
				# hundred metres of rope deck is too far to come to be put off by
				# somebody sitting outside, and the encounter is the interesting
				# half of the crossing anyway.
				if entry.actor.position.distance_to(entry.home)<3 and bigfoot_home == null:
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
				# A visitor has what he came for; the bridge is the way back.
				if bigfoot_home != null: stay_left = BIGFOOT_STAY
		return true
	if visit_in>0 or not world.resident.creature.can_roam() or not world.resident.routine.active.is_empty(): return false
	visit_in = 8
	for id in camps:
		var entry: Dictionary = camps[id]
		if entry.home == null or entry.actor.position.distance_to(entry.home)<3: continue
		# Alternate opportunities instead of commandeering every outing.
		if int(entry.outings)%2 == 0 or entry.last_visit == entry.outings: continue
		var path: PackedVector3Array = world.navigation.path(world.resident_point(),entry.home)
		if path.is_empty(): continue
		entry.last_visit = entry.outings
		visits += 1
		_take_bigfoot(path,"visiting camp",id)
		return true
	return false

## True while this controller -- an outing or a crossing -- owns Bigfoot's legs.
func owns_bigfoot() -> bool:
	return bigfoot_walk != null or bigfoot_home != null or not bigfoot_activity.is_empty()

## One frame. True while Bigfoot's legs are spoken for: by this camp, or by a
## camp across the link that borrowed him through this one.
func advance(delta: float) -> bool:
	if world == null or world.paused.call(): return owns_bigfoot() or borrowed
	if world.busy.call(): return owns_bigfoot() or borrowed
	if dirty: _sync()
	var dt := minf(delta,0.05)
	if dt<=0: return owns_bigfoot() or borrowed
	clock += dt
	sense_in -= dt
	var sense := sense_in<=0
	if sense: sense_in = 0.15
	for entry in camps.values(): _advance_camper(entry,dt,sense)
	if not dirty: _bigfoot(dt,sense)
	return owns_bigfoot() or borrowed

# ============================================================== the crossing
## A camp on an island is a camp with a horizon. When a bridge joins its ground
## to another (`crossing_route.gd`), three things become possible that were not:
## a camper can go and look at the other side, Bigfoot can come over from a
## ground he does not live on, and while he is here this world has a resident,
## so every encounter, photograph and scare works with no further change.
##
## Nothing below is scheduled. The motive for the crossing is the same one the
## camp already had -- an unattended tent is worth a look, a full wood pile
## leaves a camper with nothing to fetch -- and when the reason is absent the
## bridge stands empty.

## True while this camper is on the deck or standing on the other shore.
func _away(entry: Dictionary) -> bool:
	return entry.walk != null or entry.job != "" or (entry.shore != null and entry.shore != world)

## Is there a way over today? A link whose bridge is still being planked is a
## link, and the campers can walk out onto what there is of it, but it is not a
## crossing and nothing here may plan one.
func _crossable() -> bool:
	if crossing == null: return false
	if not crossing.crossable(): return false
	_last_refusal = ""
	return true

## Say, once, why nobody went. Only on the explicit calls -- the motives ask
## every few seconds and would fill the log.
func _refuse() -> void:
	if crossing == null: return
	var reason: String = crossing.closed_reason
	if _last_refusal != reason:
		_last_refusal = reason
		_event("nobody crosses: %s" % reason)

# ------------------------------------------------------------- the campers

## Send a camper over the link. Public for the study's key and for tests;
## `_outing` calls it on its own once the pile is full.
func send_camper_across(camp_id := -1) -> bool:
	if not _crossable():
		_refuse()
		return false
	for id in camps:
		if camp_id >= 0 and id != camp_id: continue
		var entry: Dictionary = camps[id]
		if entry.home == null or _away(entry): continue
		if _begin_camper_crossing(entry): return true
	return false

## Somewhere to stand on the far side: the far bridgehead's own ground, which is
## as far as a sightseer with a camp to keep is willing to go.
func _begin_camper_crossing(entry: Dictionary) -> bool:
	var shore := crossing.other(world) if crossing != null else null
	if shore == null: return false
	var head: Variant = shore.navigation.nearest_safe(shore.to_local(crossing.anchor_on(shore)))
	if not head is Vector3: return false
	var walk := CrossingWalk.along(crossing,crossing.plan(world,entry.actor.global_position,shore,shore.to_world(head)))
	if walk == null: return false
	entry.route = PackedVector3Array()
	entry.walk = walk
	entry.state = "cross"
	entry.last_cross = entry.outings
	_event("camper sets out across the bridge")
	return true

func _cross_camper_home(entry: Dictionary) -> bool:
	var walk: CrossingWalk = null
	if crossing != null and entry.shore != null:
		walk = CrossingWalk.along(crossing,crossing.plan(entry.shore,entry.actor.global_position,world,world.to_world(entry.home)))
	if walk == null:
		entry.away = 4.0  ## The deck is gone or the grid moved; try again shortly.
		return false
	entry.walk = walk
	entry.state = "cross"
	_event("the camper starts back across the bridge")
	return true

## A camper who is not on their own ground. There is no wood of theirs over
## there and no tent of theirs to keep, so a visitor walks, looks, and comes
## back; that is the whole of it, deliberately.
func _advance_visitor(entry: Dictionary, dt: float) -> void:
	entry.lamp.visible = world.night.call()
	entry.glow.visible = entry.lamp.visible
	entry.carried.visible = false
	entry.mark.text = ""
	if entry.walk != null:
		var at: Vector3 = entry.actor.global_position
		var moved: Vector3 = entry.walk.carry(at,CROSS_SPEED,dt)
		var stride := moved-at
		entry.actor.global_position = moved
		if Vector2(stride.x,stride.z).length()>0.0001:
			entry.actor.global_rotation.y = lerp_angle(entry.actor.global_rotation.y,atan2(stride.x,stride.z),1-exp(-6*dt))
		entry.actor.pose(dt,true,"cross",false,CROSS_SPEED)
		if entry.walk.finished(): _land_camper(entry)
		return
	entry.actor.pose(dt,false,"look",false,CROSS_SPEED)
	entry.away -= dt
	if entry.away<=0: _cross_camper_home(entry)

## Stepping off the boards is where one frame stops being enough. The model
## keeps its parent -- and so its document-local frame -- for the whole
## crossing, and only its world position moves; here the shore it has arrived on
## is asked, in its own frame, for the nearest foothold, and the model is put
## there through both `global_transform`s at once.
func _land_camper(entry: Dictionary) -> void:
	var arrived: CampsiteWorld = entry.walk.destination_shore()
	entry.walk = null
	if arrived != null:
		var safe: Variant = arrived.navigation.nearest_safe(arrived.to_local(entry.actor.global_position))
		if safe is Vector3: entry.actor.global_position = arrived.to_world(safe)
	entry.shore = arrived
	camper_crossings += 1
	if arrived == world:
		entry.route = PackedVector3Array()
		entry.state = "return"
		entry.wait = 1.0
		_event("the camper is home from the far shore")
		return
	entry.away = CAMPER_STAY
	_event("the camper crosses the bridge and looks around")

# ------------------------------------------------------- laying the planks

## The bridge is built by the people who live beside it. `BridgeConstruction`
## owns the pacing and asks here for a pair of hands; this answers yes only when
## there is a camper free, a board's worth of wood on the pile, and a walk out
## to the frontier that can actually be planned. Anything else is a no, and the
## driver lays the plank on its own time -- the pacing is the knob, the camper
## is the picture.
##
## One plank costs one wood. What refills the pile, and whether it should have
## to, is not decided: see "Built over time" in `docs/campsite-life/README.md`.
const PLANK_WOOD := 1
## Seconds a camper stands at the frontier nailing the board down.
const PLANK_WORK := 1.6

## The build this camp is working on, or null. Set by whoever owns both.
var construction: BridgeConstruction
var planks_laid := 0
var _last_refusal := ""

## `BridgeConstruction.builder`. True means a camper has it in hand.
func take_plank() -> bool:
	if construction == null or crossing == null or world == null: return false
	var bridge: SuspensionBridge = construction.bridge
	if bridge == null or bridge.is_complete(): return false
	for id in camps:
		var entry: Dictionary = camps[id]
		if entry.home == null or _away(entry) or not entry.route.is_empty(): continue
		if entry.state not in ["rest","look","return"]: continue
		if int(entry.record.get("wood",0))<PLANK_WOOD: continue
		var plan := crossing.plan_to_deck(world,entry.actor.global_position,bridge.built_extent())
		var walk := CrossingWalk.along(crossing,plan)
		if walk == null: continue
		_update_inventory(entry,{"wood":maxi(0,int(entry.record.get("wood",0))-PLANK_WOOD)})
		dirty = true
		entry.route = PackedVector3Array()
		entry.walk = walk
		entry.job = "out"
		entry.state = "build"
		_event("camper carries a plank out to the bridge")
		return true
	return false

## A camper part way through a board. Their own little state machine: out along
## what is built, a moment's work at the end of it, and back to the tent.
func _advance_builder(entry: Dictionary, dt: float) -> void:
	entry.lamp.visible = world.night.call()
	entry.glow.visible = entry.lamp.visible
	entry.carried.visible = entry.job == "out"
	entry.mark.text = ""
	if entry.walk != null:
		var at: Vector3 = entry.actor.global_position
		var moved: Vector3 = entry.walk.carry(at,CROSS_SPEED,dt)
		var stride := moved-at
		entry.actor.global_position = moved
		if Vector2(stride.x,stride.z).length()>0.0001:
			entry.actor.global_rotation.y = lerp_angle(entry.actor.global_rotation.y,atan2(stride.x,stride.z),1-exp(-6*dt))
		entry.actor.pose(dt,true,"cross",entry.job == "out",CROSS_SPEED)
		if entry.walk.finished():
			entry.walk = null
			entry.wait = PLANK_WORK if entry.job == "out" else 0.0
		return
	entry.wait -= dt
	if entry.wait>0:
		# "collect" is the leaning-over pose; nailing a board is that shape.
		entry.actor.pose(dt,false,"collect",entry.job == "out",CROSS_SPEED)
		return
	if entry.job == "out":
		# The board goes down where the deck ran out. If the driver has given up
		# on this camper in the meantime the plank is already there; either way
		# the walk home is the same.
		if construction != null and construction.lay(): planks_laid += 1
		_event("camper nails a plank onto the bridge")
		entry.job = "back"
		var home: Vector3 = world.to_world(entry.home) if entry.home != null else entry.actor.global_position
		var back := crossing.plan_from_deck(crossing.edge_of(world),world,home) if crossing != null else ([] as Array[Dictionary])
		entry.walk = CrossingWalk.along(crossing,back)
		if entry.walk == null: _end_build(entry)
		return
	_end_build(entry)

func _end_build(entry: Dictionary) -> void:
	entry.walk = null
	entry.job = ""
	var safe: Variant = world.navigation.nearest_safe(world.to_local(entry.actor.global_position))
	if safe is Vector3: entry.actor.global_position = world.to_world(safe)
	entry.route = PackedVector3Array()
	entry.state = "rest"
	entry.wait = 2.0

# -------------------------------------------------------------- Bigfoot

## No Bigfoot lives on this ground, but the bridge reaches one. The motive is
## the camp's own and unchanged: an unattended tent is worth the walk. The only
## new thing is how long the walk is.
func _consider_crossing(dt: float) -> bool:
	visit_in -= dt
	if not _crossable() or visit_in>0: return false
	visit_in = 8.0
	for id in camps:
		var entry: Dictionary = camps[id]
		if entry.home == null or _away(entry): continue
		if entry.actor.position.distance_to(entry.home)<3: continue
		if entry.last_visit == entry.outings: continue
		if not _send_bigfoot(id): continue
		entry.last_visit = entry.outings
		return true
	return false

## Fetch Bigfoot from across the link, bound for `camp_id`'s tent. Public for
## the study's key and for tests; `_consider_crossing` calls it on its own.
func send_bigfoot_across(camp_id := -1) -> bool:
	if not _crossable():
		_refuse()
		return false
	if camp_id<0:
		for id in camps:
			camp_id = id
			break
	return _send_bigfoot(camp_id)

func _send_bigfoot(camp_id: int) -> bool:
	if not _crossable():
		_refuse()
		return false
	if world.resident != null or not camps.has(camp_id): return false
	var home := crossing.other(world)
	if home == null or not home.resident_active() or home.resident_owned(): return false
	var scene: Node = home.resident
	if scene.creature == null or not scene.creature.can_roam(): return false
	if scene.routine != null and not scene.routine.active.is_empty(): return false
	var entry: Dictionary = camps[camp_id]
	if entry.home == null: return false
	var from_at: Vector3 = scene.creature.global_position
	var walk := CrossingWalk.along(crossing,crossing.plan(home,from_at,world,world.to_world(entry.home)))
	if walk == null: return false
	if scene.routine != null: scene.routine.cancel("crossing the bridge")
	if scene.brain != null: scene.brain.reset_behavior()
	scene.creature.stop_walking()
	bigfoot_scene = scene
	bigfoot_home = home
	bigfoot_probe = scene.creature._ground_probe
	bigfoot_return = from_at
	bigfoot_walk = walk
	bigfoot_stall = 0.0
	bigfoot_camp = camp_id
	visits += 1
	_event("Bigfoot starts across the bridge")
	return true

## One frame on the deck. The boards move under him, so both the place he is
## walking to and the ground beneath his feet are re-read every frame --
## `crossing_walk.gd` owns that -- and the probe swap is the same one
## `bigfoot_cave.gd` makes when he steps into the cave.
func _cross_step(dt: float) -> bool:
	if bigfoot_scene == null or not is_instance_valid(bigfoot_scene) or bigfoot_scene.creature == null:
		_abandon_crossing()
		return false
	var creature = bigfoot_scene.creature
	if not creature.can_roam():
		# A stumble, a splash, an animation that owns him for a moment: wait,
		# rather than stranding him on the boards. The stall timer still decides.
		bigfoot_stall += dt
		if bigfoot_stall>CROSS_STALL: _abandon_crossing()
		return true
	var before: Vector3 = creature.global_position
	creature._ground_probe = bigfoot_walk.probe()
	if creature.walk_step(bigfoot_walk.target(),BIGFOOT_CROSS_SPEED,dt):
		if bigfoot_walk.advance():
			_land_bigfoot()
			return true
	# Progress is measured in metres, not in waypoints: a straightened grid leg
	# can be twenty metres long and a deck board is two.
	bigfoot_stall = 0.0 if creature.global_position.distance_to(before)>0.001 else bigfoot_stall+dt
	if bigfoot_stall>CROSS_STALL: _abandon_crossing()
	return true

## He steps off the boards. Arriving here, this ground has a resident for as
## long as he stays, which is all `resident_active()` needs for the campers to
## start seeing him: the encounters, the photograph and the scare are unchanged.
func _land_bigfoot() -> void:
	var arrived: CampsiteWorld = bigfoot_walk.destination_shore()
	bigfoot_walk = null
	bigfoot_stall = 0.0
	var creature = bigfoot_scene.creature
	creature.stop_walking()
	if arrived != world:
		world.resident = null
		if bigfoot_probe.is_valid(): creature._ground_probe = bigfoot_probe
		bigfoot_home = null
		bigfoot_camp = -1
		visit_in = CROSS_COOLDOWN
		crossings += 1
		_event("Bigfoot is back across the bridge")
		return
	world.resident = bigfoot_scene
	creature._ground_probe = world.ground_probe()
	crossings += 1
	dirty = true
	stay_left = BIGFOOT_STAY
	_event("Bigfoot steps off the bridge onto the far shore")
	if not camps.has(bigfoot_camp): return
	# The bridgehead is at the rim, off the end of the grid by construction, so
	# the first stride is his own and the route starts where he is standing.
	var landing: Variant = world.navigation.nearest_safe(world.resident_point())
	if not landing is Vector3: return
	var path: PackedVector3Array = world.navigation.path(landing,camps[bigfoot_camp].home)
	if path.is_empty(): return
	var route := PackedVector3Array([world.resident_point()])
	route.append_array(path)
	_take_bigfoot(route,"visiting camp",bigfoot_camp)
	bigfoot_offgrid = true

## Home again: the same link, the other way, back to where he set out from.
func _begin_return() -> bool:
	if crossing == null or bigfoot_home == null or bigfoot_scene == null or bigfoot_scene.creature == null:
		_abandon_crossing()
		return false
	_cancel_bigfoot()
	var walk := CrossingWalk.along(crossing,crossing.plan(world,bigfoot_scene.creature.global_position,bigfoot_home,bigfoot_return))
	if walk == null:
		_abandon_crossing()
		return false
	bigfoot_walk = walk
	bigfoot_stall = 0.0
	_event("Bigfoot heads back across the bridge")
	return true

## The crossing cannot go on: he was picked up, stopped, or the ground moved
## under the plan. He is given back to whichever shore he is standing on -- there
## is no honest teleport home from the middle of a rope bridge.
func _abandon_crossing() -> void:
	var where := "before it began"
	if bigfoot_walk != null:
		var at: Vector3 = bigfoot_scene.creature.global_position if bigfoot_scene != null and is_instance_valid(bigfoot_scene) and bigfoot_scene.creature != null else Vector3.ZERO
		where = "%d%% across, on the %s, %.2f m off his waypoint%s" % [
			roundi(bigfoot_walk.progress() * 100.0), "deck" if bigfoot_walk.on_deck() else "ground",
			at.distance_to(bigfoot_walk.target()), "" if bigfoot_walk.probe().call(at) is Vector3 else ", no ground under him"]
		if bigfoot_scene != null and is_instance_valid(bigfoot_scene) and bigfoot_scene.creature != null:
			where += " (state %d, roam %s)" % [bigfoot_scene.creature.state, bigfoot_scene.creature.can_roam()]
	if bigfoot_scene != null and is_instance_valid(bigfoot_scene) and bigfoot_scene.creature != null:
		if bigfoot_probe.is_valid(): bigfoot_scene.creature._ground_probe = bigfoot_probe
		bigfoot_scene.creature.stop_walking()
	bigfoot_walk = null
	bigfoot_home = null
	bigfoot_offgrid = false
	bigfoot_stall = 0.0
	world.resident = null
	bigfoot_camp = -1
	bigfoot_activity = ""
	bigfoot_route.clear()
	visit_in = CROSS_COOLDOWN
	_event("Bigfoot gives up the crossing %s" % where)
