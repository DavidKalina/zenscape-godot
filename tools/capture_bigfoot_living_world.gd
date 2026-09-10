extends SceneTree
## Reproducible native renders of the sparse home, earned improvements and meal.
const OUTPUT := "/private/tmp/bigfoot-living-tests/"
const DT := 1.0 / 60.0
var scene: Node
var entrance := Vector3.ZERO

func _initialize() -> void: run.call_deferred()

func tick(seconds: float, until: Callable = Callable()) -> bool:
	for frame in range(ceili(seconds / DT)):
		if until.is_valid() and until.call(): return true
		scene.routine._next_action = INF
		scene._process(DT)
	return until.is_valid() and until.call()

func idle() -> bool:
	return scene.routine.living.current.is_empty() and scene.routine.cave.phase.is_empty() and scene.routine.active.is_empty()

func action(kind: String) -> bool:
	scene.routine.cancel("capture fixture")
	scene.creature.reset_at(entrance)
	return scene.routine.living.request(kind) and tick(100.0, idle)

func capture(name: String) -> void:
	scene._process(0)
	await process_frame
	await process_frame
	RenderingServer.force_draw(false)
	var error := root.get_texture().get_image().save_png(OUTPUT + name + ".png")
	print("CAPTURE ", name, ": ", error)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.size = Vector2i(1600, 1100)
	scene = load("res://studies/bigfoot_living_world.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene._paused = false
	scene._growth.terrain = 1.0
	scene._growth.foliage = 1.0
	scene._growth.water = 1.0
	scene._growth.replaying = false
	scene._growth.publish()
	scene._precipitation.set_weather(0, true)
	scene.routine.living.enabled = false
	var route: Dictionary = scene.routine.cave.plan(scene._chunk_editor.data.tunnels[0])
	if route.is_empty():
		push_error("Capture requires a reachable cave")
		quit(1)
		return
	entrance = route.entrance
	scene._focus_stack()
	await capture("living-overview")
	scene._mind_panel.show()
	scene.routine.living.scores = scene.routine.living.mind.ranked(scene.routine.living._context())
	scene._mind_timer = 0.0
	await capture("living-thoughts")
	# These are real performed improvements; fixture supplies avoid a long wait
	# for foraging and keep before/after screenshots deterministic.
	for layer in scene.find_children("*", "CanvasLayer", true, false): layer.hide()
	scene._ui.hide()
	scene._focus_lair()
	await capture("living-home-before")
	scene.lair.restore_stash(["leaves", "leaves", "branch", "fish"])
	for iteration in range(3):
		if not action("tend") or not action("play"):
			push_error("Capture activity did not complete")
			quit(1)
			return
	scene.creature.reset_at(entrance)
	scene.routine.living.mind.hunger = 0.9
	if not scene.routine.living.request("eat") or not tick(80.0, func() -> bool: return is_instance_valid(scene.routine.living._food_visual)):
		push_error("Meal capture did not reach its visible bite")
		quit(1)
		return
	scene._focus_lair()
	await capture("living-home-meal")
	scene.target = scene.lair.bed.global_position + Vector3(0, 1.1, 0)
	scene.distance = 22.0
	scene.yaw = -0.20
	scene.polar = 1.40
	scene._update_camera()
	await capture("living-home-detail")
	scene.routine.cancel("capture complete")
	scene.queue_free()
	await process_frame
	quit()
