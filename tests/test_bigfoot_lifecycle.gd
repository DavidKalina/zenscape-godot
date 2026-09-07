extends SceneTree
var failures := 0
var reservations := 0
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	var encounter = scene._bigfoot
	encounter.random_value = func(): return 0.0
	encounter.now_msec = func(): return 1000000
	encounter.reserve = func(next_at, now):
		reservations += 1
		check(next_at - now == 604800000, "Reservation spans source seven-day cooldown")
		return true
	var camera: Camera3D = scene.camera
	camera.global_position = encounter._frame.to_global(Vector3(0.08,2.45,5.75))
	camera.look_at(encounter._frame.to_global(Vector3(0,1.85,-0.65)))
	encounter._pose(0.0, camera.global_position)
	check(encounter.concealed(camera), "Source admission pose is concealed behind the actual trunk")
	encounter.check_in = 0.05
	encounter.advance(0.1,true,camera.global_position,camera)
	check(not encounter.active and reservations == 0, "Pause does not admit encounters")
	encounter.advance(0.1,false,camera.global_position,camera,0.98)
	check(not encounter.active and reservations == 0, "Incomplete growth excludes encounters")
	encounter.advance(0.1,false,camera.global_position,camera)
	check(encounter.active and not encounter.forced and reservations == 1, "Concealed encounter reserves before admission")
	var age: float = encounter.age
	encounter.advance(1.0,true,camera.global_position,camera)
	check(encounter.age == age, "Pause holds automatic pose clock")
	encounter.advance(1.0,false,camera.global_position,camera)
	check(absf(encounter.age - age - 0.1) < 0.00001, "Source step clamp prevents encounter skipping on stalls")
	var front := camera.global_transform
	camera.global_position = encounter._frame.to_global(Vector3(0,2.0,-6.0))
	camera.look_at(encounter._frame.to_global(Vector3(0,1.5,-0.65)))
	encounter.age = 13.2
	encounter.check_in = 0
	encounter.advance(0.1,false,camera.global_position,camera)
	check(encounter.active, "Exposed actor is retained after the peek instead of popping away")
	camera.global_transform = front
	encounter.check_in = 0
	encounter.advance(0.1,false,camera.global_position,camera)
	check(not encounter.active, "Concealed actor can retire safely")
	encounter.summon()
	encounter.advance(0.1,false,camera.global_position,camera,0.5)
	check(not encounter.active and not encounter.rig.visible, "Growth replay clears actor")
	encounter.check_in = 0
	encounter.advance(0.1,false,camera.global_position,camera)
	check(not encounter.active and reservations == 1, "Automatic encounter only plays once per session")
	encounter.summon()
	check(encounter.active and encounter.forced and reservations == 1, "Manual preview bypasses cooldown reservation")
	encounter.advance(17.0,false,camera.global_position)
	check(not encounter.active, "Manual sandbox preview retains its bounded duration")
	encounter.summon(true)
	check(encounter.silhouette and encounter.rig.position.is_equal_approx(Vector3(1.05,0,1.05)), "Fog preview uses source standing stance")
	check(encounter.rig.coat.get_shader_parameter("base_color") == Color("626762"), "Fog silhouette uses original material multiplier")
	check(reservations == 1, "Fog preview does not consume cooldown")
	encounter.summon()
	check(not encounter.silhouette and encounter.rig.coat.get_shader_parameter("base_color") == Color.WHITE, "Normal preview restores authored vertex colors")
	encounter.advance(17.0,false,camera.global_position)
	encounter.played = false
	encounter.reserve = func(_next_at, _now): return false
	encounter.check_in = 0
	encounter.advance(0.1,false,camera.global_position,camera)
	check(not encounter.active and not encounter.rig.visible, "Failed reservation leaves no visible actor")
	var path := "/private/tmp/zenscape-bigfoot-test-" + str(Time.get_ticks_usec()) + ".cfg"
	var store = load("res://studies/bigfoot_encounter.gd").new()
	store.cooldown_path = path
	check(store._reserve(2000,1000), "First reservation is persisted")
	store.free()
	store = load("res://studies/bigfoot_encounter.gd").new()
	store.cooldown_path = path
	check(not store._reserve(3000,1500), "New session honors saved cooldown")
	check(store._reserve(4000,2000), "Reservation is allowed once cooldown expires")
	store.free()
	DirAccess.remove_absolute(path)
	scene.queue_free()
	await process_frame
	print("PASS: Bigfoot concealment, admission, reservation, pause, growth and manual preview" if failures == 0 else "FAIL: Bigfoot lifecycle")
	quit(1 if failures else 0)
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
