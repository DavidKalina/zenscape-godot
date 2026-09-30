extends SceneTree
## Headless probe: where a live waterfall attaches on its mountain
## (scripts/flow_falls.gd, docs/scenic/water-flow.md "Waterfalls").
##
## Opens the cozy worlds scene for its terrain mesh, shapes the heights
## directly into a mountain, drops a spring ball on it as the sky's ball does
## (WaterFlow.drop) and runs the water in fixed steps. Then reads what the
## waterfalls read (WaterFlow.cascades with FlowFalls.DETECT), shapes each fall
## as FlowFalls does (_shape, _rings) and prints, in metres of height:
##   summit   the mountain's top
##   spring   the ground where the spring wells
##   water    the highest water running down from it (wet, faster than 0.3 m/s)
##   brink    the high ground's break of slope the water leaves over: the first
##            place down the spring's course where the ground falls 1 m per
##            metre or more (the spring itself when it wells on the face)
##   lip      the tallest fall's lip, as detected
##   top      the curtain's visible top (its first ring at least half as thick
##            and wide as the curtain gets)
##   end      the curtain's last ring, and the water level under it
## Shapes: a pinched horn, a rounded dome, a mesa with a cliff.
## With --live the falls also stand in the scene (FlowFalls under it, drawn by
## the dummy renderer) for a few seconds, to run their per-frame code.
##   godot --headless --path . -s res://tools/probe_fall_attach.gd -- --no-title [--shape horn] [--course] [--live]
var scene: Node3D
var data: NativeTerrainData
const WaterFlow := preload("res://scripts/water_flow.gd")
const FlowFalls := preload("res://scripts/flow_falls.gd")
const CENTER := Vector2(-4.0,0.0)

func _initialize() -> void: run.call_deferred()

static func bump(p: Vector2, center: Vector2, radius: float, rise: float) -> float:
	var t := p.distance_squared_to(center)/(radius*radius)
	return rise*(1.0-t)*(1.0-t) if t < 1.0 else 0.0

## The pinch's horn (scripts/land_clay.gd `_horn`, without its arêtes and
## noise): (1 - t)^1.9 over the pinch's radius at that lift.
static func horn(p: Vector2, lift: float) -> float:
	var radius := minf(2.2+0.45*lift,5.6)
	var t := p.distance_to(CENTER)/radius
	return lift*pow(1.0-t,1.9) if t < 1.0 else 0.0

static func mesa(p: Vector2) -> float:
	var t := p.distance_to(CENTER)
	return 3.0*(1.0-smoothstep(3.0,4.4,t))+0.25*(1.0-smoothstep(0.0,3.0,t))

func shape_of(name: String) -> Callable:
	match name:
		"horn": return func(p: Vector2) -> float: return horn(p,6.0)
		"low_horn": return func(p: Vector2) -> float: return horn(p,3.5)
		"dome": return func(p: Vector2) -> float: return bump(p,CENTER,6.0,4.0)
		"mesa": return func(p: Vector2) -> float: return mesa(p)
	return func(_p: Vector2) -> float: return 0.0

func run() -> void:
	create_timer(300).timeout.connect(func() -> void: push_error("Fall attach probe timed out"); quit(2))
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-fall-attach-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready: await process_frame
	var editor: NativeChunkEditor = scene._chunk_editor
	editor.set_process(false)
	data = editor.data
	var args := OS.get_cmdline_user_args()
	var shapes := ["horn","low_horn","dome","mesa"]
	var at := args.find("--shape")
	if at >= 0 and at+1 < args.size(): shapes = [args[at+1]]
	var falls: Node3D = FlowFalls.new()
	for name: String in shapes:
		var flow: RefCounted = WaterFlow.new(data,true)
		await flow.setup()
		var height := shape_of(name)
		for i in range(data.points.size()): data.heights[i] = height.call(data.points[i])
		var drop_at := CENTER+(Vector2(2.4,0.0) if name == "mesa" else Vector2.ZERO)
		var kind: String = flow.drop(drop_at,6.0)
		var spring := Vector2(flow.springs[-1].x,flow.springs[-1].z) if not flow.springs.is_empty() else drop_at
		var summit := -INF
		for h in data.heights: summit = maxf(summit,h)
		var brink := _brink(spring)
		var elapsed := 0.0
		for t in [6.0,25.0]:
			flow.run(roundi((t-elapsed)/flow.dt))
			elapsed = t
			if "--course" in args: _print_course(flow,spring)
			var found: Array = flow.cascades(FlowFalls.DETECT)
			var line := "%-8s t=%2ds %s summit %.2f spring %.2f water %.2f brink %.2f" % [name,int(t),kind,summit,float(data.ground_height(spring)),_highest_running(flow,spring),brink]
			if found.is_empty():
				print(line+" | no fall")
				continue
			var best: Dictionary = found[0]
			for answer: Dictionary in found:
				if float(answer.lip.y) > float(best.lip.y): best = answer
			var shaped: Dictionary = falls._shape(best)
			var rings: Dictionary = falls._rings(shaped,1.0,falls._strength(float(best.flux)))
			var top := _visible_top(rings)
			var centers: PackedVector4Array = rings.centers
			var last := centers[FlowFalls.RINGS-1]
			var under: float = _level(flow,Vector2(last.x,last.z))
			print(line+" | falls %d lip %.2f top %.2f end %.2f (water under it %.2f) drop %.2f flux %.3f  gap spring-top %.2f brink-top %.2f" % [found.size(),float(best.lip.y),top,last.y,under,float(best.drop),float(best.flux),float(data.ground_height(spring))-top,brink-top])
		if "--live" in args: await _live(flow)
		flow.springs.clear()
		flow.bursts.clear()
		flow.drain(Vector2.ZERO,40.0)
	falls.free()
	quit(0)

## Water surface at a plate point.
func _level(flow: RefCounted, p: Vector2) -> float:
	var c: int = flow.cell_at(p)
	return flow.grounds()[c]+flow.depths()[c] if c >= 0 else NAN

## The highest wet, running cell within 3 m of the spring.
func _highest_running(flow: RefCounted, spring: Vector2) -> float:
	var depth: PackedFloat32Array = flow.depths()
	var ground: PackedFloat32Array = flow.grounds()
	var velocity: PackedVector2Array = flow.kernel.get_velocity()
	var best := -INF
	for j in range(flow.height):
		for i in range(flow.width):
			var c: int = j*flow.width+i
			if depth[c] <= 0.01 or velocity[c].length() <= 0.3: continue
			if (flow.origin+Vector2(i+0.5,j+0.5)*flow.cell).distance_to(spring) > 3.0: continue
			best = maxf(best,ground[c]+depth[c])
	return best

## The ground's break of slope below the spring: down its steepest descent,
## the first 0.5 m step falling at least 1 m per metre.
func _brink(spring: Vector2) -> float:
	var course: PackedVector3Array = WaterFlow.descent(data,spring).points
	for k in range(1,course.size()):
		var run := Vector2(course[k].x-course[k-1].x,course[k].z-course[k-1].z).length()
		if course[k-1].y-course[k].y >= run*1.0: return course[k-1].y
	return course[0].y if not course.is_empty() else NAN

## The curtain's first ring at least half as thick and wide as it gets.
static func _visible_top(rings: Dictionary) -> float:
	var centers: PackedVector4Array = rings.centers
	var across: PackedVector4Array = rings.across
	var outward: PackedVector4Array = rings.outward
	var widest := 0.0
	var thickest := 0.0
	for r in range(FlowFalls.RINGS):
		widest = maxf(widest,across[r].w)
		thickest = maxf(thickest,outward[r].w)
	for r in range(FlowFalls.RINGS):
		if across[r].w >= 0.5*widest and outward[r].w >= 0.5*thickest: return centers[r].y
	return centers[0].y

## With --course: the water down the spring's course, every 0.25 m.
func _print_course(flow: RefCounted, spring: Vector2) -> void:
	var course: PackedVector3Array = WaterFlow.descent(data,spring).points
	var depth: PackedFloat32Array = flow.depths()
	var ground: PackedFloat32Array = flow.grounds()
	var velocity: PackedVector2Array = flow.kernel.get_velocity()
	var out := []
	for k in range(mini(course.size(),12)):
		var c: int = flow.cell_at(Vector2(course[k].x,course[k].z))
		if c < 0: continue
		var v: Vector2 = velocity[c]
		var ahead: int = flow.cell_at(Vector2(course[k].x,course[k].z)+(v.normalized()*0.5 if v.length() > 0.0001 else Vector2.ZERO))
		var slope: float = (ground[c]+depth[c]-ground[ahead]-depth[ahead])/0.5 if ahead >= 0 else 0.0
		out.append("y%.2f d%.3f v%.2f s%.2f" % [ground[c]+depth[c],depth[c],v.length(),slope])
	print("   course ",out)

## Stands the falls in the scene for 3 s of frames while the water runs.
func _live(flow: RefCounted) -> void:
	var live: Node3D = FlowFalls.new()
	scene.add_child(live)
	live.setup(flow,[])
	for i in range(180):
		flow.run(1)
		await process_frame
	var shown: Array = live.describe()
	print("   live: %d standing %s, update %d us (worst %d)" % [live.shown_count(),str(shown.map(func(f: Dictionary) -> String: return "lip %.2f presence %.2f" % [f.lip.y,f.presence])),live.last_update_usec,live.worst_update_usec])
	live.queue_free()
	await process_frame
