extends SceneTree
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
func run() -> void:
	var scene = load("res://studies/open_meadow.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene._paused = false
	var editor = scene._chunk_editor
	scene.creature.walk_step(scene.creature.position+Vector3(0.5,0,0),0.85,1.0/60.0)
	var maximum := 0
	for i in range(12):
		editor.data.brush(Vector2(-3,2),2.0,0.02,"raise",0.0)
		editor.refresh()
		var before: Vector3 = scene.creature.position
		var time := Time.get_ticks_usec()
		scene._process(1.0/60.0)
		maximum = maxi(maximum,Time.get_ticks_usec()-time)
		check(scene.navigation.rebuilding,"Edit yields before completing the navigation scan")
		check(scene.creature.position==before,"Actor cannot move onto a partially rebuilt map")
	check(scene.creature.player.current_animation_position>0.1,"Repeated edits keep the idle animation advancing")
	while scene.navigation.rebuilding: scene._refresh_habitat(true)
	var expected := CreatureNavigation.new()
	expected.rebuild(scene.habitat,scene.habitat.clear_at,0.35,0.3)
	check(scene.navigation._nodes==expected._nodes,"Latest edited terrain matches synchronous map")
	check(scene.navigation.is_safe(scene.creature.position),"Actor is reconciled to safe ground")
	print("LIVE EDIT NAVIGATION failures=",failures," maximum_slice_ms=",maximum/1000.0)
	scene.free()
	quit(1 if failures else 0)
