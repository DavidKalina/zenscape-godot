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
	materials.select_tool("sculpt")
	materials.set_mode("raise")
	await frames(20)
	print("tool ",clay.tool_id," modes cells ",roll._mode_cells())
	await shot("03_sculpt_taken")
	roll.pointer_override = Vector2(105,300)
	await frames(30)
	await shot("03b_fan_hover")
	roll.pointer_override = Vector2(1000,450)
	var at := Vector2(-2,1)
	var spot := screen(at)
	var before := height(at)
	await hold(spot,60)
	print("RAISE rose ",snappedf(height(at)-before,0.01))
	await frames(30)
	await shot("04_raised")
	materials.set_mode("hills")
	var from := screen(Vector2(-6,4))
	reach.pointer_override = from
	clay.press(from)
	for k in range(70):
		var p := from+Vector2(6*(k+1),-1.5*(k+1))
		reach.pointer_override = p
		clay.pull(p)
		await process_frame
	clay.release(reach.pointer_override)
	await frames(40)
	await shot("05_hills")
	roll.pointer_override = Vector2(30,450)
	await frames(40)
	await shot("06_roll_hills_mode")
	for id in ["hand","paddle","chisel","wire"]:
		materials.select_tool(id)
		await frames(30)
		await shot("07_fan_"+id)
	quit(0)
