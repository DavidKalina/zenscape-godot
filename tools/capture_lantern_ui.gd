extends SceneTree
## Stills of the Lantern Maker shell (scripts/lantern_shell.gd) in its states,
## for comparing with docs/ui/mockups/lantern-maker: the default view with the
## cursor readout, the forms wheel open, the mood orbs and veil (short and
## tuned), mid-stroke painting, a growing water ball, and a snowy, misty
## bright scene for legibility. Rendered, so a window opens (about a minute):
##   Godot --path . --script res://tools/capture_lantern_ui.gd \
##     -- --size=1600x900 --out=/private/tmp/zs-look/lantern-ui
## Saves go to a temporary places folder, never the player's.
var out := "/private/tmp/zs-look/lantern-ui"
var window := Vector2i(1600,900)
var scene: Node3D
var editor: NativeChunkEditor
var shell: Control
var cursor := Vector2.ZERO
## --retina keeps the display's content scale (the game's own 2x on a Mac);
## otherwise the window is sized in pixels at content scale 1, standing in
## for a 1600x900 or 1920x1080 monitor this laptop screen cannot show.
var retina := false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.trim_prefix("--out=")
		if arg.begins_with("--size="):
			var parts := arg.trim_prefix("--size=").split("x")
			window = Vector2i(int(parts[0]),int(parts[1]))
		if arg == "--retina": retina = true
	DirAccess.make_dir_recursive_absolute(out)
	run.call_deferred()

## Hold the window at the asked size: the scene maximizes and sets its own
## content scale (studies/fidelity.gd) as it opens.
func fix_window() -> void:
	var factor := DisplayServer.screen_get_scale() if retina else 1.0
	root.mode = Window.MODE_WINDOWED
	root.content_scale_factor = factor
	# Window sizes are in pixels here: a retina run asks for the point size.
	var pixels := window*int(factor)
	if root.size != pixels: root.size = pixels
	await frames(3)

func frames(count: int) -> void:
	for i in range(count): await process_frame

func still(name: String) -> void:
	await fix_window()
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := out.path_join("%dx%d%s-%s.png" % [window.x,window.y,"-retina" if retina else "",name])
	if image != null: image.save_png(path)
	print("LANTERN still ",path," ",image.get_size() if image != null else Vector2i.ZERO)

## A viewport point over a terrain-local ground point.
func ground(x: float, z: float) -> Vector2:
	var h: Variant = editor.data.ground_height(Vector2(x,z))
	return scene.camera.unproject_position(editor.terrain.to_global(Vector3(x,float(h) if h != null else 0.0,z)))

func point(at: Vector2, held: bool) -> void:
	cursor = at
	editor.pointer_override = at
	var event := InputEventMouseMotion.new()
	event.position = root.get_final_transform()*at
	event.global_position = event.position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	Input.parse_input_event(event)

func press(down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	event.position = root.get_final_transform()*cursor
	event.global_position = event.position
	Input.parse_input_event(event)

## Drag through ground points over `count` frames; `release` lifts at the end.
func drag(points: Array, count: int, release := true) -> void:
	await fix_window()
	point(ground(points[0].x,points[0].y),false)
	await frames(2)
	press(true)
	for i in range(1,count+1):
		var t := float(i)/count*(points.size()-1)
		var at := mini(int(t),points.size()-2)
		var xz: Vector2 = points[at].lerp(points[at+1],t-at)
		point(ground(xz.x,xz.y),true)
		await process_frame
	if release:
		press(false)
		await frames(2)

func settle() -> void:
	while scene._growth.terrain < 0.995 or scene.places.busy or editor.forming or editor.water_settling:
		await process_frame

func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = window
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = "/private/tmp/zs-lantern-capture-%d/places.json" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(scene.places_path.get_base_dir())
	scene.set_meta("movie_capture",true)
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	await fix_window()
	editor = scene._chunk_editor
	shell = scene.creation_palette
	await settle()
	await frames(60)
	print("LANTERN viewport ",root.get_texture().get_size()," visible ",root.get_visible_rect().size," window ",root.size," scale ",shell.get("ui_scale"))
	# A little to look at: a hill, a forest stand and a meadow.
	scene.select_brush("land")
	editor.select_land_form("alpine")
	await drag([Vector2(-5,-3),Vector2(-3,-1)],40)
	await settle()
	editor.select_land_form("hill")
	await drag([Vector2(4,-6),Vector2(6,-4),Vector2(5,-2),Vector2(6,-4)],90)
	await settle()
	scene.select_brush("forest")
	await drag([Vector2(2,-5),Vector2(5,-3),Vector2(6,0)],50)
	scene.select_brush("meadow")
	await drag([Vector2(-2,4),Vector2(2,5)],30)
	await settle()
	scene.select_brush("land")
	print("LANTERN painted: objects ",editor.data.objects.size()," undo ",editor.data._undo.size())
	await frames(40)
	# Default: land in hand, the cursor over open ground.
	point(ground(3.5,3.0),false)
	await frames(90)
	print("LANTERN cursor ",cursor," hit ",editor.pick(cursor)," creating ",scene._creating()," objects ",editor.data.objects.size())
	await still("default")
	# The forms wheel, alpine in hand.
	editor.select_land_form("alpine")
	shell._open_wheel(-1.0)
	await frames(40)
	await still("wheel")
	shell._close_wheel()
	editor.select_land_form("hill")
	await frames(20)
	# Mid-stroke, painting forest: the shell recedes to the brush in hand.
	scene.select_brush("forest")
	await drag([Vector2(-6,-6),Vector2(-2,-7),Vector2(0,-5)],36,false)
	await still("paint")
	press(false)
	await frames(30)
	# A water ball growing in the hand.
	scene.select_brush("water")
	point(ground(1.0,2.0),false)
	await frames(4)
	press(true)
	for i in range(75):
		point(ground(1.0+i*0.01,2.0),true)
		await process_frame
	await still("waterball")
	press(false)
	await settle()
	await frames(60)
	scene.select_brush("land")
	point(ground(3.5,3.0),false)
	# Moods: the orbs and the short veil, then tuned.
	scene.mood_look.choose("rosewater_dusk")
	scene.toggle_mood()
	await frames(100)
	await still("mood")
	var tune: Button = scene.mood_panel.tune
	tune.button_pressed = true
	tune.toggled.emit(true)
	scene.mood_panel.color_key = "grass"
	scene.mood_panel.sync()
	await frames(30)
	await still("mood-tuned")
	scene.toggle_mood()
	# Snow and mist, bright: the legibility test.
	scene.mood_look.choose("first_snow")
	scene.mood_look.pin("weather","mist")
	scene.mood_look.pin("time","midday")
	# Close in, so snow fills the frame behind the bar and the columns.
	scene.distance *= 0.42
	await frames(150)
	point(ground(3.5,3.0),false)
	await frames(20)
	await still("snow")
	scene.queue_free()
	await process_frame
	quit()
