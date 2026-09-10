extends SceneTree
## Films FireEffects on the live fidelity scene: a strike catches dry grass, the
## front runs downwind, a tree torches. Eight seconds of frames land in /tmp for
## ffmpeg, three stills land beside the fire docs. Encode with
## ffmpeg -y -framerate $(cat /private/tmp/fire-effects-frames/fps.txt) \
##   -i /private/tmp/fire-effects-frames/%04d.jpg -vf "scale=1280:-2,fps=30" \
##   -c:v libx264 -pix_fmt yuv420p -crf 20 docs/fire/effects-demo.mp4
const DIRECTORY := "/private/tmp/fire-effects-frames"
const STEP := 1.0/60.0
const SECONDS := 8.0

var scene: Node
var editor: NativeChunkEditor
var field: FireField
var effects: FireEffects
var frame := 0
var clock := 0.0
var stills := {}

func _initialize() -> void: run.call_deferred()

## The fidelity scene has no resident wind field, so the mean air vector from
## the atmosphere is the wind for both the simulation and the effects.
func wind(_point: Vector3) -> Vector3:
	var angle: float = scene._atmosphere._air_angle
	return Vector3(cos(angle),0.0,sin(angle))*scene._atmosphere._air_strength*3.0

func weather() -> Dictionary:
	var surface = scene._precipitation.surface_weather
	return {"ground_wet":surface.ground_wet,"snow_cover":surface.snow_cover,"rain":scene._precipitation.state.x}

func step() -> void:
	scene._process(STEP)
	field.advance(STEP,false)
	effects.advance(STEP,false)
	clock += STEP
	await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_jpg(DIRECTORY.path_join("%04d.jpg" % frame),0.92)
	frame += 1
	for label: String in stills:
		if not stills[label][1] and clock >= stills[label][0]:
			stills[label][1] = true
			root.get_texture().get_image().save_png("res://docs/fire/effects-%s.png" % label)
			print("still %s at %.2f s: cells=%d objects=%d flames=%d smoke=%d embers=%d" % [label,clock,
				field.burning_cells().size(),field.burning_objects().size(),
				effects.get_node("Flames").multimesh.visible_instance_count,
				effects.get_node("Smoke").multimesh.visible_instance_count,
				effects.get_node("Embers").multimesh.visible_instance_count])

func run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = root.size
	scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	editor = scene._chunk_editor
	editor.set_active(true)
	editor.start_flat()
	editor.data.begin_stroke()
	editor.data.grass.fill(0.95)
	editor.data.meadow.fill(0.5)
	editor.data.end_stroke()
	editor.data.place("tree",Vector2(0.6,0.4),0.4,1.15)
	editor.data.place("tree",Vector2(2.4,-1.6),1.9,0.9)
	editor.data.place("shrub",Vector2(-1.4,1.5),0.0,1.0)
	editor.data.place("shrub",Vector2(-3.0,-1.2),0.0,1.0)
	editor.refresh()
	scene._ui.visible = false
	scene._precipitation.set_weather(0,true)
	scene._atmosphere.strength = 0.85
	scene._atmosphere._air_strength = 0.85
	# Downwind is +x with the default air angle; the strike lands upwind of both
	# trees so the front runs across the frame and into the crowns.
	scene.target = editor.terrain.to_global(Vector3(0.4,1.1,0.2))
	scene.distance = 13.5
	scene.polar = deg_to_rad(64.0)
	scene.yaw = deg_to_rad(-118.0)
	scene._update_camera()
	# Let growth finish live, then take the clock over so the clip is a fixed
	# 1/60 s per frame however long each frame takes to render and save.
	for i in range(120):
		await process_frame
	scene.set_process(false)
	field = FireField.new()
	field.setup(editor.data,wind,weather,Callable(),314)
	effects = FireEffects.new()
	scene.add_child(effects)
	effects.setup(field,scene)
	DirAccess.make_dir_recursive_absolute(DIRECTORY)
	DirAccess.make_dir_recursive_absolute("res://docs/fire")
	stills = {"ignition":[0.55,false],"front":[3.4,false],"torch":[6.4,false]}
	var started := Time.get_ticks_msec()
	field.ignite(Vector3(-4.6,0.0,0.9),1.0,1.0)
	var torched := false
	while clock < SECONDS:
		if not torched and clock >= 2.2:
			torched = true
			field.ignite(editor.data.object_position(editor.data.objects[0]),0.5,1.0)
		await step()
	var seconds := (Time.get_ticks_msec()-started)/1000.0
	# The whole scene is stepped at a fixed 1/60 s, so the clip plays at 60.
	FileAccess.open(DIRECTORY.path_join("fps.txt"),FileAccess.WRITE).store_string("60.00")
	print("Fire effects film: %d frames rendered in %.1f s; burning cells %d, objects %d" % [frame,seconds,field.burning_cells().size(),field.burning_objects().size()])
	scene.queue_free()
	await process_frame
	quit()
