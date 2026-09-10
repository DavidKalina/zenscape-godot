extends SceneTree
## A/B film: the same diorama, the same camera, the same weather and the same
## twenty seconds, once with fire and once without.
##
## Only one scene can render at a time, so the two passes run one after the
## other in this single process. Both build their world from the same literal
## numbers and advance on a fixed 1/30 s step, so frame N of the left strip and
## frame N of the right strip are the same moment. The left pass still takes the
## lightning strike — the flash and thunder are part of the shared baseline —
## but its `struck` connection is cut, so `ignite` is never called.
##
## Run it, then stack the two strips:
##   "$HOME/Applications/Godot.app/Contents/MacOS/Godot" --path . \
##     --rendering-method forward_plus --script res://tools/film_fire.gd
##   ffmpeg -y -framerate 30 -i /private/tmp/fire-film/left/%04d.jpg \
##          -framerate 30 -i /private/tmp/fire-film/right/%04d.jpg \
##          -filter_complex "[0:v]scale=900:560,setsar=1[l];[1:v]scale=900:560,setsar=1[r];\
##                           [l][r]hstack=inputs=2,fps=30" \
##          -c:v libx264 -preset slow -pix_fmt yuv420p -crf 26 docs/fire/ab-fire.mp4
##
## The burnt look and the flame effects are separate sub-projects. When they are
## absent the right strip still shows the fire through the ground: cover burns
## away and the tint goes to ash. Re-run after merging them for the full picture.
const DIRECTORY := "/private/tmp/fire-film"
const SECONDS := 20.0
const STEP := 1.0/30.0
## Frames lifted out as stills: just after the strike, the front mid-run, and
## the aftermath.
const STILLS := [15,240,570]
const FRAME := Vector2i(900,560)

var frame := 0
var scene: Node3D
var editor: NativeChunkEditor
var pass_name := ""

func _initialize() -> void: run.call_deferred()

## Everything that decides what the world looks like, so both passes agree.
func build(burns: bool) -> void:
	scene = load("res://studies/fidelity.tscn").instantiate()
	root.add_child(scene)
	for i in range(8):
		await process_frame
	# The scene raises the window's content scale to the display's; a film has
	# to pin its own pixels or a Retina Mac writes 3024-wide frames.
	root.content_scale_factor = 1.0
	root.size = FRAME
	await process_frame
	scene.set_process(false)
	scene._ui.hide()
	editor = scene._chunk_editor
	editor.set_active(false)
	editor.start_flat()
	editor.data.begin_stroke()
	editor.data.grass.fill(1.0)
	editor.data.meadow.fill(0.45)
	editor.data.blades.fill(0.35)
	editor.data.end_stroke()
	# A line of trees downwind of the ignition point, so the front runs into
	# them rather than past them.
	for spot: Vector2 in [Vector2(2.0,0.0),Vector2(3.4,2.2),Vector2(3.0,-2.4),Vector2(6.0,0.6)]:
		editor.data.place("tree",spot,0.4,1.1)
	for spot: Vector2 in [Vector2(0.2,1.6),Vector2(0.6,-1.8),Vector2(-1.6,0.8)]:
		editor.data.place("flower",spot,0.0,1.0)
	editor.data._undo.clear()
	editor.refresh()
	# Clear, dry, and a steady 4 m/s wind blowing along +x.
	scene._precipitation.set_weather(0,true)
	scene._celestial.cycling = false
	scene._celestial.set_phase(0.46)
	scene._celestial.update_rig()
	scene._atmosphere.strength = 4.0
	scene._atmosphere._air_strength = 4.0
	scene._atmosphere._air_angle = 0.0
	scene._atmosphere._publish_wind()
	scene._lightning._rng.seed = 91127
	scene.target = Vector3(1.5,1.0,0.0)
	scene.distance = 17.0
	scene.polar = deg_to_rad(64.0)
	scene.yaw = deg_to_rad(-118.0)
	scene._update_camera()
	if scene._fire_field != null:
		scene._fire_field.restore({})
	if not burns:
		for item: Dictionary in scene._lightning.struck.get_connections():
			scene._lightning.struck.disconnect(item.callable)
	weather()

func weather() -> void:
	var surface = scene._precipitation.surface_weather
	surface.ground_wet = 0.0
	surface.foliage_wet = 0.0
	surface.air_wet = 0.0
	surface.snow_cover = 0.0
	surface.cold = 0.0
	scene._precipitation.state.x = 0.0
	scene._atmosphere._air_strength = 4.0
	scene._atmosphere._air_angle = 0.0

func shoot(folder: String) -> void:
	# The window drifts back to the display size on its own during a long run,
	# so the frame is pinned again before every capture.
	if root.size != FRAME:
		root.size = FRAME
		root.content_scale_factor = 1.0
		await process_frame
		await process_frame
	RenderingServer.force_draw(false)
	await process_frame
	root.get_texture().get_image().save_jpg(DIRECTORY.path_join(folder).path_join("%04d.jpg" % frame),0.92)
	frame += 1

func film(folder: String, burns: bool) -> void:
	pass_name = folder
	DirAccess.make_dir_recursive_absolute(DIRECTORY.path_join(folder))
	await build(burns)
	frame = 0
	var struck := false
	var steps := int(SECONDS/STEP)
	for i in range(steps):
		weather()
		# Two seconds of calm first, so the strike lands inside the clip.
		if not struck and i == 60:
			struck = true
			scene._lightning.strike(Vector2(-4.0,0.0),scene.camera.global_position)
		scene._process(STEP)
		await shoot(folder)
	var field = scene._fire_field
	print(folder," pass: ",frame," frames, burning=",field.burning_cells().size() if field != null else -1,
		" intensity=%.3f" % scene._fire_intensity," objects=",editor.data.objects.size(),
		" look=",scene._fire_look != null," effects=",scene._fire_effects != null)
	scene.queue_free()
	scene = null
	await process_frame
	await process_frame

func run() -> void:
	root.size = FRAME
	await film("left",false)
	await film("right",true)
	print("Fire A/B film: ",DIRECTORY,"/left and ",DIRECTORY,"/right, 30 fps, stills at ",STILLS)
	quit()
