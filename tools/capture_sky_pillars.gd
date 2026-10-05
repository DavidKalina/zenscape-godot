extends SceneTree
## The pillar forest, rendered (scripts/sky_pillars.gd, scripts/
## sky_pillar.gd): the wanderer steps off into the glide, the forest in sight
## of the plate is made, and the eye is set at a row of spots round it for
## stills, the clock held at noon and at golden hour:
##   distant: from far off past the plate, the forest pale in the haze;
##   approach: from out toward it, the forest across the sky;
##   slalom: among the pillars at glide height, looking down a lane;
##   slot: at the thread's mouth, looking into the slot;
##   bridge: past the slot, looking at the natural bridge;
##   top: beside a tall pillar's top, its grass and spruces;
##   down: over a gap, looking down into the mist between the feet;
##   glider: the chase view behind the glider, heading for the slot.
## The eye is held still at each spot (the glide's own stepping is paused),
## and the sky, the haze and the islands are advanced as the glide would.
## Rendered only when asked for (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/capture_sky_pillars.gd \
##     -- --no-title --out=/private/tmp/zs-pillars
## Options: --out=DIR, --noon=HOUR, --golden=HOUR (by default the clock's
## noon and the hour the setting sun stands GOLDEN_SUN high),
## --only=approach,slot,...
const GOLDEN_SUN := 0.1
var scene: Node3D
var eye: Node
var out := "/private/tmp/zs-pillars"
var noon := WorldClock.hour_for_phase(0.5)
var golden := WorldClock.hour_for_phase(0.75-asin(clampf(GOLDEN_SUN/WorldClock.elevation_for_phase(0.5),-1.0,1.0))/TAU)
var only: Array = []

func _initialize() -> void:
	run.call_deferred()

func frames(count: int) -> void:
	for i in range(count): await process_frame

func still(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.get_size() != Vector2i(1280,720): image.resize(1280,720,Image.INTERPOLATE_LANCZOS)
	var path := out.path_join(label+".png")
	image.save_png(path)
	print("PILLARS still ",path)

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--out="): out = argument.trim_prefix("--out=")
		elif argument.begins_with("--noon="): noon = float(argument.trim_prefix("--noon="))
		elif argument.begins_with("--golden="): golden = float(argument.trim_prefix("--golden="))
		elif argument.begins_with("--only="): only = Array(argument.trim_prefix("--only=").split(","))
	DirAccess.make_dir_recursive_absolute(out)
	create_timer(600).timeout.connect(func() -> void: push_error("sky pillars capture timed out"); quit(2))
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.set_meta("no_title",true)
	scene.places_path = out.path_join("places-%d/places.json" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(scene.places_path.get_base_dir())
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await create_timer(1.0).timeout
	scene.world_clock.running = false
	eye = scene.wanderer
	eye.place(Vector3(eye.PLATE_REACH-0.6,0.0,0.0))
	eye.enter()
	await frames(5)
	eye._launch(6.0,false)
	eye.set_process(false)
	eye._layer.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var islands: Node3D = eye.islands
	for i in range(900):
		if not islands.lands.has(null): break
		await frames(1)
	islands.peaks.advance(0.6,Vector3.ZERO)
	islands.peaks.flush()
	var pillars: Node3D = islands.peaks.kinds[0]
	if pillars.forest_count() == 0:
		push_error("no pillar forest was made")
		quit(1)
		return
	var b: Dictionary = pillars.built.values()[0]
	var shape: RefCounted = b.shape
	print("PILLARS forest at %s turn %.2f, %d pillars, top %.0f m, slot %.1f m, %d wraps, %d spruces, %d faces" % [b.home,b.turn,shape.pillars.size(),shape.top,shape.slot.gap,shape.wraps.size(),shape.trees.size(),(b.node.get_node("Body").mesh as ArrayMesh).surface_get_array_len(0)/3])
	var shots := _shots(pillars,b)
	for hour: float in [noon,golden]:
		var tag := "noon" if hour == noon else "golden"
		for shot: Dictionary in shots:
			if not only.is_empty() and shot.label not in only: continue
			if hour == golden and not shot.get("golden",true): continue
			await _hold(shot,hour,90 if shot == shots[0] else 50)
			await still("%s-%s" % [shot.label,tag])
	print("PILLARS done")
	quit(0)

## The spots, from the forest's own shape (in its frame, then global).
func _shots(pillars: Node3D, b: Dictionary) -> Array:
	var shape: RefCounted = b.shape
	var g := func(local: Vector3) -> Vector3: return pillars.global_of(b,local)
	var middle: Vector3 = g.call(Vector3(0.0,60.0,0.0))
	var plate := Vector3(0.0,25.0,0.0)
	var toward := Vector3(middle.x-plate.x,0.0,middle.z-plate.z).normalized()
	var shots := []
	shots.append({"label":"distant","eye":plate-toward*420.0+Vector3.UP*30.0,"look":middle})
	shots.append({"label":"approach","eye":g.call(Vector3(-60.0,25.0,620.0)),"look":g.call(Vector3(0.0,40.0,0.0))})
	# Among the pillars: the open spot at glide height nearest a third of the
	# way in, looking down the longest clear lane from it.
	var best := _open(shape,Vector3(-130.0,15.0,170.0))
	shots.append({"label":"slalom","eye":g.call(best[0]),"look":g.call(best[1])})
	var z1: float = shape.slot.z1
	shots.append({"label":"slot","eye":g.call(Vector3(shape.slot_x(12.0),12.0,z1+55.0)),"look":g.call(Vector3(shape.slot_x(8.0),8.0,z1-120.0))})
	var bz := (shape.bridge.from as Vector2).lerp(shape.bridge.to,0.5).y
	shots.append({"label":"bridge","eye":g.call(Vector3(6.0,10.0,bz+75.0)),"look":g.call(Vector3(0.0,30.0,bz))})
	# The tallest pillar's top on the near side, from a little over and out.
	var top_i := -1
	for i in range(shape.pillars.size()):
		var p: Dictionary = shape.pillars[i]
		if float(p.top) < 120.0 or float(p.top) > 200.0: continue
		if top_i < 0 or (shape.axis(p,float(p.top)) as Vector2).y > (shape.axis(shape.pillars[top_i],float(shape.pillars[top_i].top)) as Vector2).y: top_i = i
	var tp: Dictionary = shape.pillars[top_i]
	var tc: Vector2 = shape.axis(tp,float(tp.top))
	shots.append({"label":"top","eye":g.call(Vector3(tc.x+22.0,float(tp.top)+16.0,tc.y+40.0)),"look":g.call(Vector3(tc.x,float(tp.top)+2.0,tc.y))})
	shots.append({"label":"down","eye":g.call(Vector3(40.0,120.0,40.0)),"look":g.call(Vector3(-10.0,-105.0,-30.0))})
	shots.append({"label":"glider","eye":g.call(Vector3(shape.slot_x(10.0),12.0,z1+90.0)),"look":g.call(Vector3(shape.slot_x(8.0),8.0,z1-60.0)),"chase":true,"golden":false})
	return shots

## An open spot near `near` (at glide height, well clear of rock) and a look
## down the longest clear lane from it.
func _open(shape: RefCounted, near: Vector3) -> Array:
	var best_eye := near
	for r in range(0,200,6):
		var found := false
		for k in range(16):
			var p := near+Vector3(cos(TAU*k/16.0),0.0,sin(TAU*k/16.0))*r
			if _clear(shape,p,12.0):
				best_eye = p
				found = true
				break
		if found: break
	var best_look := best_eye+Vector3(0.0,0.0,-100.0)
	var longest := 0.0
	# Into the forest: within 50 degrees of its middle, clear a while.
	var inward := Vector3(-best_eye.x,0.0,-best_eye.z).normalized()
	for k in range(48):
		var way := Vector3(cos(TAU*k/48.0),0.0,sin(TAU*k/48.0))
		if way.dot(inward) < 0.64: continue
		var d := 0.0
		while d < 500.0 and _clear(shape,best_eye+way*d,6.0): d += 5.0
		if d > longest:
			longest = d
			best_look = best_eye+way*120.0+Vector3.UP*15.0
	return [best_eye,best_look]

func _clear(shape: RefCounted, p: Vector3, room: float) -> bool:
	for k in range(8):
		var o := Vector3(cos(TAU*k/8.0),0.0,sin(TAU*k/8.0))*room
		if shape.solid_at(p+o) != null: return false
	return shape.solid_at(p) == null

## Holds the eye at a shot for `count` frames at `hour`, advancing the sky,
## the haze and the islands as the glide would.
func _hold(shot: Dictionary, hour: float, count: int) -> void:
	var at: Vector3 = shot.eye
	var look: Vector3 = shot.look
	var way := (look-at).normalized()
	var glide: RefCounted = eye.glide
	glide.position = at
	glide.heading = atan2(-way.x,-way.z)
	glide.pitch = asin(clampf(way.y,-1.0,1.0))
	glide.bank = 0.0
	glide.speed = 8.0
	glide.velocity = glide.forward()*8.0
	var chase: bool = shot.get("chase",false)
	eye.glider.visible = chase
	if chase:
		eye.chase.first_person = false
		eye.chase.reset(glide,at-way*6.0+Vector3.UP*2.0)
	for i in range(count):
		scene.world_clock.running = false
		scene.world_clock.set_time(scene.world_clock.day,hour)
		var delta := 1.0/60.0
		var view_eye := at
		var view_look := look
		if chase:
			eye.chase.step(delta,glide,0.0)
			eye.glider.update(delta,glide,0.0,eye._fly_ground,false)
			view_eye = eye.chase.eye
			view_look = eye.chase.look
		eye.sky.advance(delta,view_eye,0.0)
		eye.islands.advance(delta,at,glide.heading,0.0)
		var o := view_eye-view_look
		scene.target = view_look
		scene.distance = maxf(o.length(),0.01)
		var dir: Vector3 = o/maxf(o.length(),0.01)
		scene.yaw = atan2(dir.x,dir.z)
		scene.polar = clampf(acos(clampf(dir.y,-1.0,1.0)),0.05,PI-0.05)
		scene.camera_roll = 0.0
		scene._auto_orbit = false
		scene._update_camera()
		eye.camera.fov = 70.0 if chase else 64.0
		await process_frame
