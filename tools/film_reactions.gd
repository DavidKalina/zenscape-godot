extends SceneTree
## Renders every reaction bubble for review, away from the heavy worlds.
##   Godot --path . --rendering-method forward_plus --script res://tools/film_reactions.gd -- [sheet|film]
## sheet: one PNG grid of every mood mid-animation -> /private/tmp/reaction-sheet.png
## film:  30 fps frames cycling every mood beside a stand-in head
##        -> /private/tmp/reaction-frames, encode with
##        ffmpeg -framerate 30 -i /private/tmp/reaction-frames/%04d.png -pix_fmt yuv420p reactions.mp4
const Bubble = preload("res://scripts/reaction_bubble.gd")
const FPS := 30.0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var mode := "sheet"
	for arg in OS.get_cmdline_user_args(): mode = arg
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("7f9a86")
	environment.ambient_light_color = Color.WHITE
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	root.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9,0.5,0)
	root.add_child(sun)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	if mode == "film": await film(camera)
	else: await sheet(camera)
	quit()

func sheet(camera: Camera3D) -> void:
	root.size = Vector2i(1800,1120)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 11.2
	camera.position = Vector3(0,0,10)
	var bubbles: Array = []
	var index := 0
	for symbol: String in Bubble.MOODS:
		var anchor := Node3D.new()
		root.add_child(anchor)
		anchor.position = Vector3(-7.9+float(index%5)*3.6,3.0-float(index/5)*2.8,0)
		var label := Label3D.new()
		label.text = symbol
		label.font_size = 40
		label.position = Vector3(0,-0.25,0)
		anchor.add_child(label)
		var bubble = Bubble.new()
		anchor.add_child(bubble)
		bubble.set_process(false)
		bubble.screen_share = 0.2
		bubbles.append(bubble)
		index += 1
	await process_frame
	for bubble in bubbles:
		bubble.show_reaction(bubble.get_parent().get_child(0).text,10.0)
		bubble._process(1.2)
	await _draw()
	root.get_texture().get_image().save_png("/private/tmp/reaction-sheet.png")
	print("Wrote /private/tmp/reaction-sheet.png")

func film(camera: Camera3D) -> void:
	root.size = Vector2i(1280,720)
	camera.position = Vector3(0,1.9,6.5)
	camera.look_at(Vector3(0,1.6,0))
	var body := MeshInstance3D.new()
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.55
	capsule.height = 2.6
	body.mesh = capsule
	var fur := StandardMaterial3D.new()
	fur.albedo_color = Color("6b4a33")
	body.material_override = fur
	body.position.y = 1.3
	root.add_child(body)
	var head := Node3D.new()
	head.position = Vector3(0,2.75,0)
	root.add_child(head)
	var bubble = Bubble.new()
	head.add_child(bubble)
	bubble.set_process(false)
	DirAccess.make_dir_recursive_absolute("/private/tmp/reaction-frames")
	for file in DirAccess.get_files_at("/private/tmp/reaction-frames"):
		DirAccess.remove_absolute("/private/tmp/reaction-frames/"+file)
	await process_frame
	var frame := 0
	for symbol: String in Bubble.MOODS:
		bubble.show_reaction(symbol)
		for step in range(int(bubble.hold*FPS)+6):
			body.rotation.y = sin(float(frame)/FPS*0.8)*0.4
			bubble._process(1.0/FPS)
			await _draw()
			root.get_texture().get_image().save_png("/private/tmp/reaction-frames/%04d.png" % frame)
			frame += 1
	print("Wrote %d frames to /private/tmp/reaction-frames" % frame)

func _draw() -> void:
	for i in range(2): await process_frame
	RenderingServer.force_draw(false)
