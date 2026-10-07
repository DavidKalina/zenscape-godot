extends SceneTree
## The sky's currents drawn as ribbons (scripts/sky_currents.gd, shaders/
## sky_jet_ribbon.gdshader): one draw of strips, a stroke per stretch of jet
## spread evenly along it and a handful up each thermal, painted with the
## breeze ribbons' brush (shaders/breeze_ribbon_paint.gdshaderinc), and the
## air they show unchanged by how it is drawn.
const SkyCurrents = preload("res://scripts/sky_currents.gd")
const SkyIslands = preload("res://scripts/sky_islands.gd")
var failures := 0

func _initialize() -> void:
	var currents := SkyCurrents.new()
	var slots := [Vector3.ZERO]
	slots.append_array(SkyIslands.OFFSETS)
	currents.build(slots)
	var mi: MultiMeshInstance3D = currents.get_node("Wisps")
	var mm := mi.multimesh
	var material := currents.wisp_material()
	check(material.shader.resource_path == "res://shaders/sky_jet_ribbon.gdshader","Drawn with the jet ribbon shader")
	check(material.shader.code.contains("breeze_ribbon_paint.gdshaderinc"),"Painted with the breeze ribbons' brush")
	check(load("res://shaders/breeze_ribbon.gdshader").code.contains("breeze_ribbon_paint.gdshaderinc"),"The breeze ribbons share that brush")
	# The strip: RIBBON_SEGMENTS long, two across, x 0..1 along, y 0..1 across.
	var arrays := mm.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var lo := Vector3.ONE*INF
	var hi := -Vector3.ONE*INF
	for v in vertices:
		lo = lo.min(v)
		hi = hi.max(v)
	check(vertices.size() == (SkyCurrents.RIBBON_SEGMENTS+1)*2 and indices.size() == SkyCurrents.RIBBON_SEGMENTS*6,"A ribbon is a strip of %d segments (%d vertices)" % [SkyCurrents.RIBBON_SEGMENTS,vertices.size()])
	check(lo.is_equal_approx(Vector3.ZERO) and hi.is_equal_approx(Vector3(1.0,1.0,0.0)),"The strip runs 0..1 along and across")
	# Strokes per current, and spread evenly along each.
	var per_row := {}
	check(mm.instance_count == currents.stroke_data.size(),"One instance a stroke (%d)" % mm.instance_count)
	for c: Color in currents.stroke_data:
		var row := int(c.r*currents.currents.size())
		if not per_row.has(row): per_row[row] = []
		per_row[row].append(c)
	var all_drawn := true
	var even := true
	var counted := true
	for row in range(currents.currents.size()):
		var current: Dictionary = currents.currents[row]
		var strokes: Array = per_row.get(row,[])
		if strokes.is_empty():
			all_drawn = false
			continue
		var want: int = maxi(3,roundi(float(current.length)*SkyCurrents.JET_RIBBONS)) if current.kind == "jet" else SkyCurrents.THERMAL_RIBBONS
		if strokes.size() != want: counted = false
		for k in range(strokes.size()):
			var c: Color = strokes[k]
			# Its share sits in its own slot of the current's strokes, and
			# it knows how many share the current.
			if c.g < float(k)/strokes.size() or c.g > float(k+1)/strokes.size(): even = false
			if not is_equal_approx(c.a*64.0,float(strokes.size())): counted = false
	check(all_drawn,"Every current has its strokes")
	check(counted,"A stroke per %.0f m of jet (3 at least), %d up a thermal" % [1.0/SkyCurrents.JET_RIBBONS,SkyCurrents.THERMAL_RIBBONS])
	check(even,"Each current's strokes are spread evenly along it")
	var jets := currents.currents.filter(func(c: Dictionary) -> bool: return c.kind == "jet")
	var jet_strokes := 0
	for row in range(currents.currents.size()):
		if currents.currents[row].kind == "jet": jet_strokes += (per_row.get(row,[]) as Array).size()
	check(jet_strokes < 200,"Few enough strokes down the jets to stay legible (%d over %d loops)" % [jet_strokes,jets.size()])
	check(mi.custom_aabb.size.length() > 1e5,"The strokes are placed in the shader, never culled")
	# A later current brings its strokes, once, at the frame's end.
	var before := currents.wisp_count()
	currents.add_thermal(Vector3(900.0,0.0,0.0),"later")
	check(currents.wisp_count() == before+SkyCurrents.THERMAL_RIBBONS,"A later thermal brings its strokes (%d to %d)" % [before,currents.wisp_count()])
	# The air is the same however it is drawn.
	check(currents.air_at(currents.currents[0].points[10]).jet > 0.99,"Riding a jet's core is still full in the jet")
	currents.free()
	print("Jet ribbons: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	print(("PASS " if ok else "FAIL ")+label)
	if not ok: failures += 1
