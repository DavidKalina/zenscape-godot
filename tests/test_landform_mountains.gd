extends SceneTree
## suite: serial
## Mountains, the lower world's landform (scripts/landform_mountains.gd,
## scripts/mountain_massif.gd): over a few seeds and sizes its recipe makes
## a sky islet (scripts/sky_islet.gd `author`) whose massif stands its main
## summit within SUMMIT over its rim, a pass between its two summits cut
## deep under the lower one, snow only over its snow line (and none under
## the treeline), conifers under the treeline, a level hut pad; the same
## seed and size make the same island; and each builds within BUDGET
## seconds, its parts' arrays (top, massif, sides) counted in triangles.
## Stood in the sky's islets (scripts/sky_islets.gd), the massif draws its
## own faces, its hut's window and halo stand, and the glide meets its
## summit as a solid.
const Landform = preload("res://scripts/landform_mountains.gd")
const SkyIslet = preload("res://scripts/sky_islet.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyCells = preload("res://scripts/sky_cells.gd")
const SEEDS := [11,2024,77001]
const SIZES := [55.0,78.0,100.0]
## Seconds the shape and its arrays may take to build on one core, headless.
const BUDGET := 4.0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func _make(seed_value: int, across: float) -> RefCounted:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return SkyIslet.author(seed_value,Landform.recipe(rng,across))

func _run() -> void:
	check(Landform.NAME == "mountains","its name")
	check(Landform.ACROSS.x >= 40.0 and Landform.ACROSS.y <= 120.0,"its width range")
	var palette := SkyIslet.plain_palette()
	for across: float in SIZES:
		for seed_value: int in SEEDS:
			var label := "seed %d, %d m" % [seed_value,across]
			var began := Time.get_ticks_usec()
			var islet: RefCounted = _make(seed_value,across)
			var shaped := (Time.get_ticks_usec()-began)/1.0e6
			var top: Array = islet.top_arrays(palette)
			var massif: RefCounted = islet.spire
			var peak: Array = massif.arrays(islet)
			var sides: Array = islet.side_arrays()
			var built := (Time.get_ticks_usec()-began)/1.0e6
			var tris := [(top[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()/3,(peak[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()/3,
				(sides[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()/3]
			print("     %s: shape %.2f s, all %.2f s; triangles top %d, massif %d, sides %d; summit %.1f m, %d objects" % [label,shaped,built,tris[0],tris[1],tris[2],
				float(massif.summit_tops(islet)[0]),islet.objects.size()])
			check(built < BUDGET,"%s builds in %.2f s (under %.1f)" % [label,built,BUDGET])
			var problems: Array = massif.problems(islet,label)
			check(problems.is_empty(),"%s has no problems %s" % [label,str(problems)])
			var tops: PackedFloat32Array = massif.summit_tops(islet)
			check(tops[0] <= Landform.SUMMIT.y+2.0 and tops[0] >= Landform.SUMMIT.x*0.85,"%s summit %.1f m within SUMMIT" % [label,tops[0]])
			var floor_y: float = massif.pass_floor(islet)
			var lower := minf(tops[0],tops[1])
			check(lower-floor_y > 8.0,"%s pass %.1f m under the lower summit" % [label,lower-floor_y])
			# Snow only high: every snowy face (UV.x under 0) over the snow line
			# less its rag and lingering, none under the treeline.
			var uv: PackedVector2Array = peak[Mesh.ARRAY_TEX_UV]
			var at: PackedVector3Array = peak[Mesh.ARRAY_VERTEX]
			var lowest_snow := INF
			var snowy := 0
			for k in range(0,uv.size(),3):
				if uv[k].x >= 0.0: continue
				snowy += 1
				lowest_snow = minf(lowest_snow,(at[k].y+at[k+1].y+at[k+2].y)/3.0)
			check(snowy > 0,"%s has snow (%d faces)" % [label,snowy])
			check(lowest_snow > float(massif.snowline)-massif.SNOW_LINGER-massif.SNOW_RAG*2.0-0.5 and lowest_snow > float(massif.treeline),
				"%s snow from %.1f m (line %.1f, treeline %.1f)" % [label,lowest_snow,massif.snowline,massif.treeline])
			# Conifers stand under the treeline (and its rag).
			var conifers := 0
			var highest := -INF
			for item: Dictionary in islet.objects:
				if not item.asset in ["tree","juniper"]: continue
				conifers += 1
				highest = maxf(highest,islet.ground_at(Vector2(item.x,item.z)))
			check(conifers >= 15,"%s has %d conifers" % [label,conifers])
			check(highest < float(massif.treeline)+massif.height*0.05,"%s conifers under the treeline (%.1f, line %.1f)" % [label,highest,massif.treeline])
			# The same seed and size make the same island.
			if across == SIZES[0]:
				var again: RefCounted = _make(seed_value,across)
				check(again.heights == islet.heights and again.objects == islet.objects,"%s made again is the same" % label)
	# Stood as the islets stand theirs: the massif draws its own faces, the
	# hut's window and halo stand by it, and the glide meets the summit.
	var cells := SkyCells.new([Vector3.ZERO,Vector3(380.0,-20.0,-160.0)])
	var islets: Node3D = SkyIslets.new()
	root.add_child(islets)
	islets.reset(cells)
	var palette_live: Dictionary = islets.prepare_authored()
	var seed_stood := 4242
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_stood
	var recipe := Landform.recipe(rng,90.0)
	recipe.massif.hut = true
	var home := Vector3(900.0,0.0,700.0)
	var made: Dictionary = SkyIslets.make(seed_stood,recipe,palette_live,home.y)
	var b: Dictionary = islets.stand("Mountain",home,made)
	b.fixed = true
	islets.built["landform:mountains"] = b
	var node: Node3D = b.node
	var faces := node.get_node_or_null("Massif") as MeshInstance3D
	check(faces != null and faces.mesh.get_surface_count() == 1 and faces.mesh.surface_get_material(0) != null,"The massif draws its own faces")
	var massif_stood: RefCounted = b.shape.spire
	if massif_stood.with_trail:
		check(node.get_node_or_null("HutWindow") != null and node.get_node_or_null("HutHalo") != null,"The hut's window and halo stand")
	var main: Vector3 = massif_stood.summits[0]
	var place: Vector3 = islets.place(b)
	var top_y: float = b.shape.ground_at(Vector2(main.x,main.y))
	var body: Variant = islets.body(place+Vector3(main.x,top_y+5.0,main.y))
	check(body is Vector2 and absf((body as Vector2).x-(place.y+top_y)) < 1.5,"The glide meets the summit as a solid (%s, summit %.1f)" % [str(body),place.y+top_y])
	islets.queue_free()
	await process_frame
	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
