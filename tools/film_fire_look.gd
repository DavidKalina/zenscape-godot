extends SceneTree
## Contact strip for the burnt look: green, browning, skeleton, charcoal snag,
## ash ground and regrowth, straight out of the fidelity scene under the
## Balanced preset. Stills land in docs/fire/look-*.png.
##
##   Godot --path . --rendering-method forward_plus --script res://tools/film_fire_look.gd

var scene: Node3D = null
var editor: NativeChunkEditor = null
var field: FireField = null
var look: FireLook = null
var tree_id := -1

func _initialize() -> void: run.call_deferred()

func shot(name: String, close := true) -> void:
	frame(close)
	for i in range(6):
		RenderingServer.force_draw(false)
		await process_frame
	root.get_texture().get_image().save_png("res://docs/fire/look-%s.png" % name)
	print("Saved docs/fire/look-",name,".png")

## Two framings: the tree in close-up, and the burnt clearing from further out.
func frame(close: bool) -> void:
	scene.target = Vector3(0.0,2.4,0.0) if close else Vector3(0.0,0.6,0.0)
	scene.distance = 10.0 if close else 22.0
	scene.yaw = 1.8893
	scene.polar = 1.02 if close else 1.18
	scene._update_camera()
	scene._process(0.0)

func burn(seconds: float, step := 0.5) -> void:
	for i in range(int(seconds/step)):
		field.advance(step)
		look.advance(step)

func run() -> void:
	root.size = Vector2i(1280,800)
	scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene._paused = true
	scene._ui.hide()
	scene._growth.terrain = 1.0
	scene._growth.foliage = 1.0
	scene._growth.water = 1.0
	scene._growth.publish()
	editor = scene._chunk_editor
	editor.start_flat()
	var data := editor.data
	data.grass.fill(0.9)
	data.meadow.fill(0.4)
	data.blades.fill(0.3)
	tree_id = data.place("tree",Vector2(0.0,0.0),0.0,1.3)
	for point in [Vector2(2.4,1.1),Vector2(-2.1,1.6),Vector2(1.2,-2.3),Vector2(-2.8,-1.4)]:
		data.place("grass_tuft",point,0.0,1.0)
	data.place("shrub",Vector2(3.1,-1.0),0.0,1.0)
	editor.refresh()
	await process_frame

	field = FireField.new()
	# A ring of inert cells keeps its grass but cannot catch, so the burn stops
	# at five metres and the ash has green meadow to be judged against.
	field.setup(data,Callable(),Callable(),
		func(point: Vector3) -> bool:
			var reach := Vector2(point.x,point.z).length()
			return reach > 5.0 and reach < 6.6,
		19)
	look = FireLook.new()
	look.setup(field,editor.content)
	look.ground_refresh = false

	await shot("green")
	# Hand-driven phases: the same custom data the field would push, without
	# waiting out the forty-second torch for each frame of the strip.
	editor.content.set_object_fire(tree_id,0.28,1.0)
	await shot("browning")
	editor.content.set_object_fire(tree_id,0.72,1.0)
	await shot("skeleton")
	editor.content.set_object_fire(tree_id,1.0,0.0)
	await shot("charcoal")
	editor.content.set_object_fire(tree_id,0.0,0.0)

	# Now the real thing: light the clearing and let it run to a snag and ash.
	field.ignite(Vector3(0.0,0.0,0.0),2.0,1.0)
	burn(75.0)
	look.ground_refresh = true
	look.refresh_ground()
	await shot("snag")
	await shot("ash",false)
	# Regrowth is 240 s by default; walk past it so the meadow is green again.
	burn(330.0,1.0)
	look.refresh_ground()
	await shot("regrown",false)

	scene.queue_free()
	await process_frame
	quit()
