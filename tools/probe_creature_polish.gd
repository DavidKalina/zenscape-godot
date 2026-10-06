extends SceneTree
## Headless probe of the small-creature polish (docs/scenic/life.md "Small
## life"). Opens the product scene on the Genesis plain, plants a
## patch of meadow flowers and a pond, and checks:
## - butterflies: wingspan (from the wing mesh's AABB through the instance
##   transforms) inside SPAN for every per-fly size, and, run on the real
##   survey, that settled butterflies sit on their flower's head and fliers
##   stay between the ground and a sensible height;
## - dragonflies: the wing batch uses the translucent wing material (alpha,
##   both sides, drawn after the water) while the body stays on the shared
##   faceted life material.
## Exits 1 if a check fails. CPU only under the dummy renderer: nothing here
## says how the wings or the new size look.
##   godot --headless --path . -s res://tools/probe_creature_polish.gd
const Butterflies = preload("res://scripts/life_butterflies.gd")
const Dragonflies = preload("res://scripts/life_dragonflies.gd")
const Kit = preload("res://scripts/life_small_kit.gd")

## Target butterfly wingspan band (m).
const SPAN := Vector2(0.18, 0.26)

var scene: Node3D
var life: Node3D
var failures: Array[String] = []

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures.append(label)

## Wingspan of a flat-winged butterfly of per-fly `size`: both wings' mesh
## AABBs through their instance transforms, measured across the body.
func span(wing: Mesh, size: float) -> float:
	var body := Transform3D(Basis.from_scale(Vector3.ONE*size*Butterflies.SCALE),Vector3.ZERO)
	var pair := Kit.wing_pair(body,Vector3(0.006,0.004,0.0),0.0,0.0)
	var box: AABB = pair[0]*wing.get_aabb()
	box = box.merge(pair[1]*wing.get_aabb())
	return box.size.x

func run() -> void:
	create_timer(150).timeout.connect(func() -> void: push_error("Creature polish probe timed out"); quit(2))
	root.size = Vector2i(1280,800)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = "/private/tmp/zs-creature-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready: await process_frame
	life = scene.land_life
	var editor: NativeChunkEditor = scene._chunk_editor
	var data := editor.data
	editor.set_process_input(false)
	scene.set_process_input(false)
	scene.set_process_unhandled_input(false)
	scene._celestial.set_phase(0.5)
	await create_timer(1.0).timeout

	# --- Static model checks.
	var flies: Node3D = life.small.butterflies
	var wing_mesh: Mesh = flies._wings.mesh
	var spans := {}
	for size in [0.85,1.0,1.15]: spans[size] = snappedf(span(wing_mesh,size),0.001)
	print("CREATURE butterfly SCALE=%s spans=%s" % [Butterflies.SCALE,JSON.stringify(spans)])
	for size: float in spans: check(spans[size] >= SPAN.x and spans[size] <= SPAN.y,"butterfly wingspan %.3f m at size %.2f in %s" % [spans[size],size,SPAN])
	var body_box: AABB = flies._bodies.mesh.get_aabb()
	print("CREATURE butterfly body length %.3f m" % (body_box.size.z*Butterflies.SCALE))

	var darts: Node3D = life.small.dragonflies
	var wing_mat: Material = darts._wings.mesh.surface_get_material(0)
	var body_mat: Material = darts._bodies.mesh.surface_get_material(0)
	check(wing_mat is StandardMaterial3D and (wing_mat as StandardMaterial3D).transparency == BaseMaterial3D.TRANSPARENCY_ALPHA,"dragonfly wings use an alpha material")
	if wing_mat is StandardMaterial3D:
		var glass := wing_mat as StandardMaterial3D
		check(glass.albedo_color.a < 0.6,"dragonfly wings are see-through (alpha %.2f)" % glass.albedo_color.a)
		check(glass.cull_mode == BaseMaterial3D.CULL_DISABLED,"dragonfly wings draw both sides")
		check(glass.render_priority > 0,"dragonfly wings draw after pond water (priority %d)" % glass.render_priority)
		check(glass.vertex_color_use_as_albedo,"dragonfly wings keep their film and rim paint")
	check(darts._wings.mesh.get_surface_count() == 1 and darts._bodies.mesh.get_surface_count() == 1,"dragonfly wings and body are separate meshes")
	check(body_mat == life.material,"dragonfly body on the shared life material")
	check(body_mat is ShaderMaterial and bool((body_mat as ShaderMaterial).get_shader_parameter("flat_faces")),"shared life material has flat_faces")
	check(flies._bodies.mesh.surface_get_material(0) == life.material and flies._wings.mesh.surface_get_material(0) == life.material,"butterflies stay on the shared life material")

	# --- Butterflies on a real survey: a patch of meadow flowers and a pond.
	var tops := {}
	data.begin_stroke()
	var kinds := ["oxeye_daisy","cosmos","buttercup","poppy","lupine","sunflower"]
	for i in range(24):
		var p := Vector2(4.0,-3.0)+Vector2.from_angle(float(i)*2.4)*(0.6+0.17*float(i))
		var kind: String = kinds[i%kinds.size()]
		if data.place(kind,p,float(i),1.0) >= 0: tops[p] = preload("res://scripts/meadow_flower_mesh.gd").SPEC[kind].height
	var basin := Vector2(-5.0,3.0)
	for _pass in range(6): data.brush(basin,4.0,0.3,"lower",0.0)
	data.add_pond(basin,float(data.ground_height(basin))+0.7)
	data.end_stroke()
	await editor.refresh(self)
	var waited := 0.0
	while (life.survey == null or not life.survey.done or life.survey.flower_spots.size() < 20) and waited < 20.0:
		await process_frame
		waited += 1.0/60.0
	var survey: RefCounted = life.survey
	check(survey != null and survey.flower_spots.size() == survey.flower_tops.size() and survey.flower_spots.size() >= 20,"survey lists %d flowers with %d heights" % [survey.flower_spots.size() if survey else 0,survey.flower_tops.size() if survey else 0])
	# Run the butterflies on their own, past their arrival delays, in a
	# dry midsummer noon (the weather is random from run to run).
	life.set_process(false)
	scene.world_clock.season_override = 0.375
	scene._celestial.set_phase(0.5)
	flies._since = 0.0
	var perched := []
	var worst_low := INF
	var worst_high := -INF
	var heights: Array[float] = []
	for n in range(1800):
		scene._precipitation.state.x = 0.0
		flies.advance(0.05)
		if n < 900: continue
		for fly: Dictionary in flies.flies:
			if float(fly.fade) < 1.0: continue
			var pos: Vector3 = fly.pos
			var ground: float = survey.ground_at(Vector2(pos.x,pos.z))
			if is_nan(ground): continue
			if not bool(fly.resting): heights.append(pos.y-ground)
			worst_low = minf(worst_low,pos.y-ground)
			worst_high = maxf(worst_high,pos.y-ground)
			if bool(fly.resting) and float(fly.rest) < 0.5:
				var want := float(tops.get(fly.flower,-1.0))
				if want > 0.0: perched.append(snappedf(pos.y-ground-want,0.001))
	heights.sort()
	var median := heights[heights.size()/2] if not heights.is_empty() else -1.0
	var p95 := heights[int(heights.size()*0.95)] if not heights.is_empty() else -1.0
	print("CREATURE butterflies out=%d perched_offsets(n=%d)=%s height_over_ground min=%.2f max=%.2f flying median=%.2f p95=%.2f" % [flies.showing(),perched.size(),JSON.stringify(perched.slice(0,8)),worst_low,worst_high,median,p95])
	check(flies.showing() > 0,"butterflies come to the flowers")
	check(not perched.is_empty() and perched.all(func(d: float) -> bool: return absf(d+Butterflies.PERCH_DROP) < 0.03),"settled butterflies sit on their flower's head")
	# Over steep ground the height eases after the slope, so a brief overshoot
	# off a crest is allowed; the run as a whole stays at flower height, and a
	# settling butterfly may dip a few centimetres on a steep bank.
	check(worst_low > -0.1,"butterflies keep out of the ground (lowest %.2f m)" % worst_low)
	check(median > 0.2 and median < 1.2 and p95 < 2.2,"butterflies fly at flower height (median %.2f m, p95 %.2f m)" % [median,p95])
	print("CREATURE butterfly weather fair=%s season=%.2f daylight=%.2f" % [flies._fair(),life._season(),life._daylight()])
	life.set_process(true)

	print("CREATURE failures ",JSON.stringify(failures))
	scene.queue_free()
	for _frame in range(3): await process_frame
	quit(1 if not failures.is_empty() else 0)
