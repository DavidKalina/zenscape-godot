extends SceneTree
## The wind tool's visible air (scripts/wind_gust.gd, docs/scenic/wind-gust.md
## "How it looks"): thin streaks of varied lag and length rather than even
## dashes, a burst's arcs curving one way round, what the air picks up on its
## way, and the promise still sent exactly. Headless: it checks the meshes and
## state the shaders read, not how they render.
const WindGust = preload("res://scripts/wind_gust.gd")
var failures := 0
var gust: Node3D

func _initialize() -> void: _run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func step(seconds: float) -> void:
	for i in range(int(seconds*60.0)): gust._process(1.0/60.0)

func custom(mesh: ArrayMesh) -> PackedFloat32Array:
	return mesh.surface_get_arrays(0)[Mesh.ARRAY_CUSTOM0]

func _run() -> void:
	var plate := Node3D.new()
	root.add_child(plate)
	gust = WindGust.new()
	plate.add_child(gust)
	gust.set_process(false)
	gust.ground_at = func(_p: Vector2) -> Variant: return 0.0

	# A swipe: the promise is sent exactly.
	gust.press(Vector3.ZERO,3.0)
	gust._aim.heading = Vector2(1,0)
	gust._aim.power = 0.9
	gust._aim.pointer = Vector2(1.2,0)
	gust._aim.moved = 1.2
	var plan: Dictionary = gust.promise()
	var g: Dictionary = gust.release()
	for key in ["kind","origin","heading","reach","half","power"]:
		check(g[key] == plan[key],"The sent gust keeps its promised %s" % key)

	# Streaks: few, thin, each its own lag and length, laid along the lane.
	var ribbons: MeshInstance3D = g.ribbons
	var mesh := ribbons.mesh as ArrayMesh
	var data := custom(mesh)
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	check(data.size() == vertices.size()*4,"Every streak vertex carries its lag, phase and length")
	var per := vertices.size()/WindGust.STRANDS
	var lags := {}
	var lengths := {}
	for k in range(WindGust.STRANDS):
		var at := k*per*4
		lags[snappedf(data[at],0.001)] = true
		lengths[snappedf(data[at+2],0.001)] = true
		check(data[at] >= 0.0 and data[at] <= WindGust.STREAK_LAG,"A streak lags the head by at most STREAK_LAG")
		check(data[at+2] >= WindGust.STREAK_LENGTH.x*0.75-0.001 and data[at+2] <= WindGust.STREAK_LENGTH.y*1.15+0.001,"A streak's length is in range")
	var sorted: Array = lags.keys()
	sorted.sort()
	var gap := INF
	for i in range(1,sorted.size()): gap = minf(gap,float(sorted[i])-float(sorted[i-1]))
	check(sorted.size() == WindGust.STRANDS and gap > 0.05,"Strands ride at their own lags behind the head (closest %.3f m)" % gap)
	check(lengths.size() == WindGust.STRANDS,"No two streaks are the same length (not even dashes)")
	var aligned := true
	for n in normals: aligned = aligned and n.dot(Vector3.RIGHT) > 0.9
	check(aligned,"Each strand's way follows the lane's heading")
	var width: float = (ribbons.material_override as ShaderMaterial).get_shader_parameter("width")
	check(width <= WindGust.RIBBON_WIDTH.y and width < 0.08,"Streaks are hair-thin, not bands (%s m)" % width)

	# On its way the air picks up petals, fluff and glints.
	var gathered: int = gust._motes.size()
	var kinds := {}
	var soft_seen := 0
	var opacity_ok := true
	for i in range(int((WindGust.WIND_UP+float(g.run))*60.0)):
		gust._process(1.0/60.0)
		var o: float = (ribbons.material_override as ShaderMaterial).get_shader_parameter("opacity")
		opacity_ok = opacity_ok and o >= 0.0 and o <= 1.0
		soft_seen = maxi(soft_seen,gust._speck_node.multimesh.visible_instance_count)
		for mote: Dictionary in gust._motes: kinds[mote.kind] = true
	check(opacity_ok,"Streak opacity stays within 0..1")
	check(int(g.picked) > 0 and int(g.picked) <= WindGust.PICK_MAX,"The lane picked up what lay in its path (%d)" % int(g.picked))
	check(gust._motes.size() > gathered,"Picked-up motes join the press's gathering")
	check(kinds.has("fluff") or kinds.has("glint"),"Seed fluff or pollen glints ride the air")
	check(soft_seen > 0,"Fluff and glints are drawn as soft specks")
	step(0.5)
	var head: float = (ribbons.material_override as ShaderMaterial).get_shader_parameter("head")
	check(g.done and head > float(g.reach),"Spent, the streaks drift on past the lane's end rather than stop")
	step(WindGust.SETTLE+4.0)
	check(gust.gusts.is_empty(),"The gust is retired after it settles")
	check(gust._speck_node.multimesh.visible_instance_count == 0,"Fluff and glints fade once they land")

	# A burst: arcs curving out, all turning the same way.
	gust.press(Vector3.ZERO,3.0)
	step(0.8)
	var burst: Dictionary = gust.release()
	check(burst.kind == "burst","A still press bursts")
	var strands: Array = burst.strands
	check(strands.size() == WindGust.SPOKES,"A burst has SPOKES arcs")
	var signs := {}
	for style: Dictionary in strands:
		check(absf(float(style.swirl)) >= WindGust.SPOKE_SWIRL.x-0.001,"Each arc turns as it runs out")
		signs[signf(float(style.swirl))] = true
	check(signs.size() == 1,"A burst's arcs all turn the same way round")
	var bursts := custom(burst.ribbons.mesh as ArrayMesh)
	check(bursts.size() > 0,"The burst's arcs are built")
	step(WindGust.WIND_UP+float(burst.run)+WindGust.SETTLE+1.0)
	check(gust.gusts.is_empty(),"The burst is retired after it settles")

	# The Feather's wake draws the same streaks along the path it takes.
	gust.press(Vector3.ZERO,2.0,1.0,true)
	for i in range(40):
		gust.aim(Vector3(float(i)*0.25,0.0,sin(float(i)*0.2)))
		gust._process(1.0/60.0)
	var wake: Dictionary = gust.release()
	check(wake.kind == "wake","A Feather's moving press is a wake")
	var tail: MeshInstance3D = wake.tail
	var chunks: Array = wake.chunks
	var drawn: Mesh = tail.mesh if tail.mesh != null else (chunks[0].mesh if not chunks.is_empty() else null)
	check(drawn != null and custom(drawn as ArrayMesh).size() > 0,"The wake's streaks carry lag, phase and length")
	step(WindGust.WAKE_SETTLE+1.0)
	check(gust.wakes.is_empty(),"The wake dies away")

	print("Wind gust look: ",failures," failures")
	plate.free()
	quit(1 if failures else 0)
