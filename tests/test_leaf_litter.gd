extends SceneTree
## Fallen leaves: real shapes, varied colour, a drift gathered near trees, a
## small triangle budget.
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	var Mesh_ := load("res://scripts/leaf_litter_mesh.gd")
	var Litter := load("res://scripts/wind_leaf_litter.gd")
	# Shapes: four, distinct, each pointed, folded and tiny.
	check(Mesh_.ORDER.size() >= 3 and Mesh_.ORDER.size() <= 4,"Three or four leaf shapes")
	var counts := {}
	var widths := {}
	for shape: String in Mesh_.ORDER:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		Mesh_.add_leaf(surface,shape,Transform3D.IDENTITY,Color.WHITE,0.0)
		var mesh := surface.commit()
		var arrays := mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		counts[shape] = verts.size()/3
		check(verts.size()/3 == Mesh_.triangles(shape),"Triangle count matches the shape "+shape)
		check(verts.size()/3 <= 20,"Each leaf stays tiny: "+shape)
		var box := mesh.get_aabb()
		widths[shape] = box.size.x/box.size.z
		var tip := 0.0
		var raised := false
		for v in verts:
			tip = minf(tip,v.z)
			if v.y > 0.01: raised = true
		check(tip < -0.55,"Leaf has a pointed tip: "+shape)
		check(raised,"Leaf is folded along its midrib: "+shape)
	check(absf(float(widths.willow)-float(widths.broad)) > 0.25,"Willow is slender next to the broad leaf")
	check(counts.lobed != counts.willow,"Lobed and willow differ in build")
	# Instanced mesh stacks the shapes under their ids.
	var stacked: ArrayMesh = Mesh_.instanced_mesh()
	var uvs: PackedVector2Array = stacked.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	var ids := {}
	for uv in uvs: ids[uv.x] = true
	check(ids.size() == Mesh_.ORDER.size(),"Instanced mesh carries every shape id")
	# Colour variety: warm, with spread, a few faded green-yellow.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var hues: Array[float] = []
	var greens := 0
	var values: Array[float] = []
	for i in range(300):
		var c: Color = Mesh_.leaf_color(rng).linear_to_srgb()
		hues.append(c.h)
		values.append(c.v)
		if c.h > 0.14 and c.r > c.b: greens += 1
		check(c.r >= c.g*0.9 and c.r > c.b,"Leaf colours are warm")
	check(hues.max()-hues.min() > 0.06,"Hue varies across leaves")
	check(values.max()-values.min() > 0.25,"Brightness varies across leaves")
	check(greens > 3 and greens < 90,"A few faded green-yellow leaves")
	# Scatter: gathered near the trees, thin in open meadow.
	var litter = Litter.new()
	root.add_child(litter)
	var anchors: Array = []
	for i in range(8): anchors.append(Vector2(i*20.0,0.0))
	litter.seed_from(anchors,func(_p): return 0.0)
	check(litter.leaves.size() > 8 and litter.leaves.size() <= litter.CAPACITY,"Leaves seeded within capacity")
	var near := 0
	var far := 0
	var sizes: Array[float] = []
	var variants := {}
	var nearest_sum := 0.0
	for leaf in litter.leaves:
		var d := 999.0
		for a: Vector2 in anchors: d = minf(d,Vector2(leaf.position.x,leaf.position.z).distance_to(a))
		if d < 1.5: near += 1
		elif d > 2.0: far += 1
		sizes.append(leaf.size)
		variants[leaf.variant] = true
	# Equal-area test: the annulus 2-3.4 m is 3.5x the area of the 1.5 m disc,
	# so an even sprinkle would leave about 0.3 inside for every 1 outside.
	check(float(near) > float(far)*2.5,"Leaves gather near the trunk, sparse in the open (%d near, %d far)" % [near,far])
	check(variants.size() >= 3,"Several shapes among the leaves")
	check(sizes.max()/sizes.min() > 1.8,"Leaf sizes vary")
	var layered := false
	for leaf in litter.leaves: layered = layered or float(leaf.lift) > 0.0
	check(layered,"Some leaves rest on others")
	var curled := false
	for leaf in litter.leaves: curled = curled or float(leaf.curl) > 0.2
	check(curled,"Some leaves are curled")
	# Hollows pull leaves in.
	var bowl := func(p: Vector2) -> Variant: return 0.3*(p-Vector2(4,0)).length()*0.5
	var pulled := 0
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 9
	for i in range(200):
		var p: Vector2 = Mesh_.drift_point(rng2,Vector2(0,0),0.0,bowl)
		if p.x > 0.7: pulled += 1
	var flat_pulled := 0
	rng2.seed = 9
	for i in range(200):
		var p: Vector2 = Mesh_.drift_point(rng2,Vector2(0,0),0.0,func(_q): return 0.0)
		if p.x > 0.7: flat_pulled += 1
	check(pulled > flat_pulled,"Hollows collect more leaves than flat ground")
	# Budget: instanced draw is the shapes stacked, one multimesh.
	var total := 0
	for shape: String in Mesh_.ORDER: total += Mesh_.triangles(shape)
	check(total <= 60,"Stacked instancing mesh stays small (%d triangles)" % total)
	check(stacked.get_faces().size()/3 == total,"Stacked mesh triangle count")
	var bed: ArrayMesh = load("res://scripts/leaf_bed.gd").mesh()
	check(bed.get_faces().size()/3 <= 600,"Leaf bed stays under budget")
	litter.free()
	print("LEAF LITTER: ",failures," failures; per-leaf triangles ",counts)
	quit(1 if failures else 0)
