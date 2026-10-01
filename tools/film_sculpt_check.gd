extends SceneTree
## Rendered check of the Sculpt: frames saved to /private/tmp/zs-sculpt-shots.
##   godot --path . --windowed --resolution 1440x900 -s res://tools/film_sculpt_check.gd -- --no-title
const OUT := "/private/tmp/zs-sculpt-shots"
var scene: Node3D
var editor: NativeChunkEditor
var clay: Node
var materials: Node
var reach: Node

func _initialize() -> void: run.call_deferred()

func frames(count: int) -> void:
	for i in range(count): await process_frame

func shot(name: String) -> void:
	await frames(3)
	RenderingServer.force_draw(false)
	var image := root.get_texture().get_image()
	image.save_png("%s/%s.png" % [OUT,name])
	print("SHOT ",name," ",image.get_size())

func height(p: Vector2) -> float:
	return float(editor.data.sample(p,editor.data.heights))

func screen(p: Vector2) -> Vector2:
	return scene.camera.unproject_position(editor.terrain.to_global(Vector3(p.x,height(p),p.y)))

func hold(at: Vector2, count: int) -> void:
	reach.pointer_override = at
	var took: bool = clay.press(at)
	print("press took ",took," verb ",clay.verb," forming ",editor.forming," active ",editor.active," pick ",editor.pick(at))
	await frames(count)
	clay.release(at)
	await frames(20)

func run() -> void:
	create_timer(150).timeout.connect(func() -> void: print("TIMED OUT"); quit(2))
	DirAccess.make_dir_recursive_absolute(OUT)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = "/private/tmp/zs-sculpt-film-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await create_timer(1.5).timeout
	editor = scene._chunk_editor
	clay = scene.get("land_clay")
	reach = scene.hand_reach
	materials = reach.get("materials")
	print("clay ",clay != null," materials ",materials != null," roll ",materials.roll if materials != null else null)
	var roll: Control = materials.roll
	print("viewport ",root.get_visible_rect().size," roll shown ",roll.shown," visible ",roll.visible)
	await shot("01_world")
	roll.pointer_override = Vector2(30,450)
	await frames(40)
	print("roll awake ",roll.awake," rect ",roll.rect())
	await shot("02_roll_out")
	roll.pointer_override = Vector2(1000,450)
	materials.select_tool("hills")
	await frames(10)
	for row in range(3):
		var from := screen(Vector2(-8,-4+row*2.5))
		var to := screen(Vector2(4,-4+row*2.5))
		reach.pointer_override = from
		clay.press(from)
		for k in range(40):
			var p := from.lerp(to,(k+1)/40.0)
			reach.pointer_override = p
			clay.pull(p)
			await process_frame
		clay.release(to)
		await frames(10)
	await frames(30)
	await shot("10_hills")
	materials.select_tool("mountain")
	await frames(10)
	var peak_at := screen(Vector2(6,-6))
	reach.pointer_override = peak_at
	clay.press(peak_at)
	for k in range(30):
		var p := peak_at-Vector2(0,5*(k+1))
		reach.pointer_override = p
		clay.pull(p)
		await process_frame
	clay.release(reach.pointer_override)
	await frames(30)
	await shot("11_mountain")
	materials.select_tool("bowl")
	await frames(10)
	var bowl_from := screen(Vector2(-4,6))
	var bowl_to := screen(Vector2(2,6))
	reach.pointer_override = bowl_from
	clay.press(bowl_from)
	for k in range(30):
		var p := bowl_from.lerp(bowl_to,(k+1)/30.0)
		reach.pointer_override = p
		clay.pull(p)
		await process_frame
	clay.release(bowl_to)
	await frames(40)
	await shot("12_bowl")
	roll.pointer_override = Vector2(30,450)
	await frames(30)
	await shot("13_roll")
	quit(0)
