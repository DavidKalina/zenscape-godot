extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	root.size = Vector2i(1440,960)
	create_timer(120).timeout.connect(func() -> void: quit(2))
	var scene = load("res://studies/diorama.tscn").instantiate()
	var folder := "/private/tmp/crossing-test-"+str(Time.get_ticks_usec())
	scene.library_path = folder
	scene.recent_file = folder+"/recent.cfg"
	root.add_child(scene)
	while not scene.title_loaded: await process_frame
	scene.new_diorama()
	scene.set_process(false)
	var editor: NativeChunkEditor = scene._chunk_editor
	var data: NativeTerrainData = editor.data
	for i in range(data.points.size()):
		data.heights[i] = -0.8 if absf(data.points[i].x)<0.9 else 0.0
	data.streams = [{"pts":[{"x":0.0,"z":-14.0,"h":-0.45},{"x":0.0,"z":14.0,"h":-0.45}],"width":0.65,"depth":0.2,"surface":0.05,"capHead":false,"capTail":false}]
	data.place("shrub",Vector2(3.5,1),0,1.2)
	editor.refresh()
	scene._refresh_habitat()
	scene.invite_bigfoot(Vector3(-3,0,0))
	scene.environment_life.cancel()
	scene.environment_life.arrival_pending = false
	scene.environment_life.autonomous = false
	scene.routine.living.enabled = false
	scene.routine._next_action = INF
	scene.brain.rest_min = 10000
	scene.brain.rest_max = 10000
	scene.brain.reset_behavior()
	scene._paused = false
	var wish = scene.routine.crossing_wish
	for i in range(1100):
		scene._process(1.0/60.0)
		if wish.destination != null: break
		if wish._planning: await process_frame
	check(wish.destination != null,"Bigfoot autonomously notices a scenic resting spot across the stream")
	if wish.destination == null:
		print("DISCOVERY origin=",scene.creature.position," nodes=",scene.navigation._nodes.size()," courses=",scene.navigation._courses," active=",scene.routine.active," clock=",scene.routine._clock," next=",wish._next," paused=",scene._paused," changed=",scene._habitat_changed," state=",scene.creature.state)
		scene.free()
		quit(1)
		return
	var destination: Vector3 = wish.destination
	check(scene.routine.habits.outing == null,"Noticing is not credited as a successful visit")
	check(scene.navigation.path(scene.creature.position,destination).is_empty(),"The wish initially needs a crossing")
	data.begin_stroke()
	var log_id := data.place("log",Vector2.ZERO,0,4.0,NativeObjectPose.make(Basis.from_scale(Vector3.ONE*4.0),0.45))
	data.end_stroke()
	editor.refresh()
	scene._refresh_habitat()
	check(not scene.habitat.walkways.surfaces.is_empty(),"A log placed and raised onto the banks becomes a supported crossing")
	check(not scene.navigation.path(scene.creature.position,destination).is_empty(),"The edit connects Bigfoot to his destination")
	var balanced := false
	var paused_crossing := false
	for i in range(4000):
		scene._process(1.0/60.0)
		balanced = balanced or (scene.creature.balancing and scene.creature.state==CreatureActor.State.WALKING)
		if balanced and not paused_crossing:
			var feet: Vector3 = scene.creature.position
			var clock_before: float = scene.routine._clock
			scene._paused = true
			for frame in range(30): scene._process(1.0/60.0)
			check(scene.creature.position==feet and scene.routine._clock==clock_before and scene.routine.habits.outing_visits==0,"Pause freezes the crossing without granting a visit")
			scene._paused = false
			paused_crossing = true
		if scene.routine.habits.outing_visits>0: break
		if wish._planning: await process_frame
	check(balanced,"Actual walking uses the balancing pose on the log")
	check(scene.routine.habits.outing_visits==1 and scene.routine.habits.outing==destination,"A completed rest remembers the chosen destination")
	var saved: bool = scene.save_current()
	var reopened: bool = editor.open_garden()
	check(saved and reopened,"The crossing world saves and reopens")
	check(scene.routine.habits.outing==destination and scene.routine.habits.outing_visits==1,"Favorite place and visit count survive save/load")
	# Carry him back, then let his own clock choose the remembered destination.
	scene.creature.reset_at(Vector3(-3,0,0))
	scene.environment_life.cancel()
	scene.environment_life.arrival_pending = false
	scene.routine._next_action = INF
	scene.brain.reset_behavior()
	for i in range(6000):
		scene._process(1.0/60.0)
		if scene.routine.habits.outing_visits>=2: break
		if wish._planning: await process_frame
	check(scene.routine.habits.outing_visits==2,"He autonomously returns to the saved favorite place")
	var physical_log: Node3D = scene.world_play.promote(log_id)
	check(physical_log != null and scene._habitat_changed and scene.habitat.walkways.at(Vector2.ZERO).is_empty(),"Making a bridge log physical immediately invalidates its stored footing")
	data.begin_stroke()
	data.remove_object(log_id)
	data.end_stroke()
	editor.refresh()
	scene._refresh_habitat()
	check(scene.navigation.path(Vector3(-3,0,0),destination).is_empty(),"Deleting the crossing closes its route")
	check(scene.routine.habits.preferred_outing()==destination,"An inaccessible but intact destination remains a memory")
	# Sculpt a real isolated foothold with the existing terrain brush. Walking
	# remains impossible; the same wish must plan and perform two short hops.
	data.begin_stroke()
	data.brush(Vector2.ZERO,0.6,30.0,"flatten",0.0)
	data.end_stroke()
	editor.refresh()
	scene._refresh_habitat()
	scene.creature.reset_at(Vector3(-3,0,0))
	scene.routine.cancel("testing the terrain alternative")
	wish.reset()
	scene.routine._next_action = INF
	scene.brain.reset_behavior()
	check(scene.navigation.path(scene.creature.position,destination).is_empty(),"Sculpted stone retains water gaps rather than forming a continuous path")
	var hopped := false
	for i in range(7200):
		scene._process(1.0/60.0)
		if scene.creature.state==CreatureActor.State.HOPPING and not hopped:
			var feet: Vector3 = scene.creature.position
			scene._paused = true
			for frame in range(30): scene._process(1.0/60.0)
			check(scene.creature.position==feet,"Pause freezes an airborne hop")
			scene._paused = false
			hopped = true
		if scene.routine.habits.outing_visits>=3: break
		if wish._planning or i%30==0: await process_frame
	check(hopped and scene.routine.habits.outing_visits==3,"He crosses the sculpted stepping stone and completes another remembered visit")
	# Edit the landing stone during a later hop: abandon the trip, recover safe
	# feet, and never credit the interrupted outing as a completed visit.
	scene.creature.reset_at(Vector3(-3,0,0))
	wish.reset()
	scene.routine._next_action = INF
	scene.brain.reset_behavior()
	var interrupted_hop := false
	for i in range(3600):
		scene._process(1.0/60.0)
		if scene.creature.state==CreatureActor.State.HOPPING:
			data.begin_stroke()
			data.brush(Vector2.ZERO,0.6,30.0,"flatten",-0.8)
			data.end_stroke()
			editor.refresh()
			scene._refresh_habitat()
			interrupted_hop = true
			break
		if wish._planning or i%30==0: await process_frame
	check(interrupted_hop and scene.creature.state!=CreatureActor.State.HOPPING and scene.navigation.is_safe(scene.creature.position),"Editing a landing stone during a hop restores safe footing")
	check(scene.routine.habits.outing_visits==3,"An interrupted hop grants no extra visit")
	var encoded: Dictionary = scene.routine.habits.capture()
	check(scene.routine.habits.valid(JSON.parse_string(JSON.stringify(encoded))),"JSON numeric types preserve version-three memory")
	encoded.outing_visits = 0
	check(not scene.routine.habits.valid(encoded),"A favorite with no completed visits cannot be loaded")
	data.begin_stroke()
	data.brush(Vector2(destination.x,destination.z),1.5,30.0,"flatten",-0.8)
	data.end_stroke()
	editor.refresh()
	scene._refresh_habitat()
	check(scene.routine.habits.preferred_outing()==null and scene.routine.habits.outing_visits==0,"Changing the resting surface invalidates its favorite memory")
	wish.reset()
	scene.brain.enabled = false
	scene.brain.reset_behavior()
	scene.routine.cancel("test completed")
	for frame in range(3): await process_frame
	scene.free()
	print("BIGFOOT CROSSING: failures=",failures," fixture=",folder)
	quit(1 if failures else 0)
