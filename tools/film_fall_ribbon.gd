extends SceneTree
## A narrow, steep live waterfall close up, to judge its ribbon
## (scripts/flow_falls.gd, docs/scenic/water-flow.md "Waterfalls"). Shapes the
## heights directly (a horn, or a mesa with a cliff), refreshes the terrain,
## lands a spring as a ball would, lets the water run, then saves stills of
## the fall from two sides while it forms and once it stands:
## /private/tmp/zs-film/ribbon_*.png. Rendered (needs a window):
##   Godot --windowed --path . --resolution 1280x720 -s res://tools/film_fall_ribbon.gd -- --no-title [--shape mesa]
## Headless it prints the falls only.
const CENTER := Vector2(-4.0,0.0)
const OUT := "/private/tmp/zs-film"
var scene: Node3D
var editor: NativeChunkEditor
var lapse := 0

func _initialize() -> void: run.call_deferred()

func frames(count: int) -> void:
	for i in range(count):
		await process_frame
		if lapse > 0 and editor.flow != null: editor.flow.run(lapse)

func seconds(value: float) -> void:
	await frames(int(value*60.0))

static func horn(p: Vector2, lift: float) -> float:
	var radius := minf(2.2+0.45*lift,5.6)
	var t := p.distance_to(CENTER)/radius
	return lift*pow(1.0-t,1.9) if t < 1.0 else 0.0

## A 3 m mesa with a 0.8 m notch cut through its east rim.
static func mesa(p: Vector2) -> float:
	var t := p.distance_to(CENTER)
	var h := 3.0*(1.0-smoothstep(3.0,3.6,t))+0.25*(1.0-smoothstep(0.0,3.0,t))
	var d := p-CENTER
	if d.x > 1.0 and absf(d.y) < 0.4 and t < 3.4: h -= 0.35*(1.0-absf(d.y)/0.4)
	return h

## A 4 m mesa whose cliff steps out to a shelf half way down (as a wire cut
## leaves), with the same notch: two steep groups the falls must join.
static func ledge(p: Vector2) -> float:
	var t := p.distance_to(CENTER)
	var h := 2.0*(1.0-smoothstep(3.0,3.25,t))+2.0*(1.0-smoothstep(4.3,4.55,t))+0.25*(1.0-smoothstep(0.0,3.0,t))
	var d := p-CENTER
	if d.x > 1.0 and absf(d.y) < 0.4 and t < 4.7: h -= 0.35*(1.0-absf(d.y)/0.4)
	return h

func shot(name: String) -> void:
	var raw: Array = editor.flow.cascades(preload("res://scripts/flow_falls.gd").DETECT)
	print("RIBBON ",name," detected %d " % raw.size(),_falls())
	if DisplayServer.get_name() == "headless": return
	DirAccess.make_dir_recursive_absolute(OUT)
	root.get_texture().get_image().save_png("%s/ribbon_%s.png" % [OUT,name])

func _falls() -> String:
	var falls: Node = editor.flow_view.falls if editor.flow_view != null else null
	if falls == null: return "no falls node"
	var out := []
	for fall: Dictionary in falls.describe():
		out.append("%d: drop %.2f width %.2f flux %.3f presence %.2f ribbon %.2f" % [fall.id,fall.drop,fall.width,fall.flux,fall.presence,fall.ribbon])
	return str(out)

func look(at: Vector3, distance: float, yaw: float, polar: float) -> void:
	scene.target = at
	scene.distance = distance
	scene.yaw = yaw
	scene.polar = polar
	scene._update_camera()

func run() -> void:
	create_timer(200).timeout.connect(func() -> void: push_error("ribbon film timed out"); quit(2))
	root.size = Vector2i(1280,720)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = "/private/tmp/zs-film-ribbon-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	editor = scene._chunk_editor
	while scene.places.busy or editor.forming: await process_frame
	for i in range(240):
		if editor.flow != null and editor.flow.ready: break
		await process_frame
	scene.world_clock.running = false
	scene._celestial.set_phase(0.3)
	var args := OS.get_cmdline_user_args()
	var at := args.find("--shape")
	var shape_name: String = args[at+1] if at >= 0 and at+1 < args.size() else "horn"
	var mesa_shape := shape_name in ["mesa","ledge"]
	var data: NativeTerrainData = editor.data
	for i in range(data.points.size()):
		match shape_name:
			"mesa": data.heights[i] = mesa(data.points[i])
			"ledge": data.heights[i] = ledge(data.points[i])
			_: data.heights[i] = horn(data.points[i],6.0)
	await editor.refresh(self)
	await seconds(0.5)
	var drop_at := CENTER+(Vector2(1.6,0.0) if mesa_shape else Vector2.ZERO)
	editor._flow_landed(drop_at,6.0,[])
	var middle: Vector3 = editor.terrain.to_global(Vector3(CENTER.x+2.5,1.5,CENTER.y))
	look(middle,9.0,1.9,1.15)
	lapse = 2
	if DisplayServer.get_name() != "headless": Input.warp_mouse(root.get_final_transform()*Vector2(1270,700))
	# The moment a fall stands, face it and catch its pour every 0.2 s.
	for i in range(900):
		await frames(1)
		var standing: Array = editor.flow_view.falls.describe() if editor.flow_view.falls != null else []
		if standing.is_empty(): continue
		var first: Dictionary = standing[0]
		var heading := Vector2(first.plunge.x-first.lip.x,first.plunge.z-first.lip.z).normalized()
		look(editor.terrain.to_global((first.lip as Vector3).lerp(first.plunge,0.5)),8.0,atan2(heading.x,heading.y)+PI,1.2)
		for k in range(12):
			shot("pour_%02d" % k)
			await seconds(0.2)
		break
	await seconds(6.0)
	var falls: Array = editor.flow_view.falls.describe() if editor.flow_view.falls != null else []
	var best: Dictionary = {}
	for fall: Dictionary in falls:
		if float(fall.ribbon) > 0.5 and (best.is_empty() or fall.drop > best.drop): best = fall
	if best.is_empty():
		shot("none")
		quit(0)
		return
	var lip: Vector3 = best.lip
	var plunge: Vector3 = best.plunge
	var run := Vector2(plunge.x-lip.x,plunge.z-lip.z).normalized()
	var focus: Vector3 = editor.terrain.to_global(lip.lerp(plunge,0.5))
	# The brush's cursor ring follows the mouse: park it off the land.
	if DisplayServer.get_name() != "headless": Input.warp_mouse(root.get_final_transform()*Vector2(1270,700))
	for k in range(4):
		look(focus,10.0,atan2(run.x,run.y)+k*PI/2.0,1.15)
		await seconds(1.0)
		shot("standing_%d" % k)
	quit(0)
