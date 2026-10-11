extends SceneTree
## The kit isles' water (scripts/kit_isle/kit_water.gd), headless: a round
## bowl a metre deep spilling over a lip at x 3 is laid as the edit chunks'
## still water. The sheet is fine (a vertex every CELL m) and carries what
## the plate's pond material reads: its depth over the bed in UV2.x, the
## depth palette in COLOR, its run to the bank in UV.x and the fetch eight
## ways in CUSTOM0/1 as float vec4s; its edge dips under the bank, and at
## the lip it runs to the brink. Its material is the plate's pond material
## with the live still water's settings, reading its bed per pixel, steeped
## and walled round when asked; a bowl with nothing under the level draws
## nothing.
##   godot --headless --path . --script tests/test_kit_water.gd
const LEVEL := 9.0
const LIP := 3.0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

## The bowl: a metre under the level in the middle, rising to it 3 m out,
## where a flat bank stands a centimetre over it.
static func bowl(x: float, z: float) -> float:
	var r := Vector2(x,z).length()
	return LEVEL-1.0+0.99*r*r/9.0 if r < 3.0 else LEVEL+0.01

func run() -> void:
	var spec := {"level":LEVEL,"ground":func(x: float, z: float) -> float: return bowl(x,z),
		"rect":Rect2(-6.0,-6.0,12.0,12.0),"inside":func(p: Vector2) -> bool: return p.x < LIP}
	var sheet := KitWater.still(spec)
	check(sheet.mesh != null and sheet.mesh.get_surface_count() == 1,"The bowl's water draws one surface")
	var arrays: Array = sheet.mesh.surface_get_arrays(0)
	var format: int = sheet.mesh.surface_get_format(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var custom0: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
	var custom1: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM1]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var floats := Mesh.ARRAY_CUSTOM_RGBA_FLOAT
	check((format >> Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) & Mesh.ARRAY_FORMAT_CUSTOM_MASK == floats and (format >> Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT) & Mesh.ARRAY_FORMAT_CUSTOM_MASK == floats,"Its fetch is two float vec4s (the plate's pond format)")
	var n := vertices.size()
	check(n > 400 and colors.size() == n and uv.size() == n and uv2.size() == n and custom0.size() == n*4 and custom1.size() == n*4 and indices.size() > 0,"Every vertex carries colour, UV, UV2 and fetch (%d vertices, %d triangles)" % [n,indices.size()/3])
	check(int(sheet.get_meta("triangles")) == indices.size()/3 and int(sheet.get_meta("vertices")) == n,"Its counts are kept on it")
	# The grid: neighbours a CELL apart.
	var steps := {}
	for i in range(0,indices.size(),3):
		var a := Vector2(vertices[indices[i]].x,vertices[indices[i]].z)
		var b := Vector2(vertices[indices[i+1]].x,vertices[indices[i+1]].z)
		steps[snappedf(a.distance_to(b),0.01)] = true
	check(steps.has(snappedf(KitWater.CELL,0.01)),"The sheet is the live water's grid, a vertex every %.2f m" % KitWater.CELL)
	# Depth in UV2.x, over the bed (the sheet stands LIFT over the water; a
	# vertex on the brink keeps its cell's depth); the palette deepens with it.
	var deepest := 0
	var worst := 0.0
	var dipped := 0
	for i in range(n):
		var v := vertices[i]
		if uv2[i].x > uv2[deepest].x: deepest = i
		if v.x > LIP-KitWater.CELL: continue
		var top := v.y-KitWater.LIFT
		var bed := bowl(v.x,v.z)
		if top > LEVEL-0.0001:
			worst = maxf(worst,absf(uv2[i].x-maxf(0.0,LEVEL-bed)))
		else:
			# A bank corner barely over the level: just under its ground, dry.
			dipped += 1
			worst = maxf(worst,absf(uv2[i].x))
			if top > bed: worst = maxf(worst,top-bed)
	check(worst < 0.002,"UV2.x is the water's depth over the bed (worst %.4f m off)" % worst)
	check(absf(uv2[deepest].x-1.0) < 0.05,"The middle reads a metre deep (%.2f m)" % uv2[deepest].x)
	check(dipped > 0,"Where the bank is barely over the level the sheet's edge dips under it (%d vertices)" % dipped)
	var shallow := 0
	for i in range(n):
		if uv2[i].x > 0.0 and uv2[i].x < 0.1: shallow = i
	check(colors[deepest].get_luminance() < colors[shallow].get_luminance(),"Its colour deepens with depth (the live water's palette)")
	# The run to the bank in UV.x: none on the bank, metres in the middle.
	var bank_run := INF
	for i in range(n):
		if uv2[i].x <= 0.0: bank_run = minf(bank_run,uv[i].x)
	check(bank_run == 0.0 and uv[deepest].x > 2.0,"UV.x runs from 0 on the bank to %.1f m in the middle" % uv[deepest].x)
	# The fetch: open water every way from the middle, at most FETCH.
	var fetch := PackedFloat32Array()
	for k in range(4): fetch.append(custom0[deepest*4+k])
	for k in range(4): fetch.append(custom1[deepest*4+k])
	var most := 0.0
	for f in fetch: most = maxf(most,f)
	check(fetch[0] > 2.0 and fetch[4] > 2.0 and fetch[2] > 2.0 and fetch[6] > 2.0 and most <= KitWater.FETCH,"The middle has open water all eight ways (+x %.1f, -x %.1f m), FETCH at most" % [fetch[0],fetch[4]])
	# The lip: past x 3 is off the land; the sheet runs to its brink.
	var reach := -INF
	for v in vertices: reach = maxf(reach,v.x)
	check(absf(reach-(LIP+KitWater.BRINK)) < 0.02,"At the lip the sheet runs to the brink (x %.3f, the lip %.1f)" % [reach,LIP])
	# The material: the plate's pond material, the live still water's way.
	var material := sheet.material_override as ShaderMaterial
	check(material != null and material.shader != null and material.shader.resource_path == "res://shaders/lake_reference_water.gdshader","Its material is the plate's pond material (lake_reference_water)")
	if material != null:
		check(material.get_shader_parameter("depth_tint") == true and material.get_shader_parameter("shore_distance") == true and material.get_shader_parameter("depth_read") == true,"It tints by depth, keeps its lap to the bank and reads its bed per pixel")
		check(material.get_shader_parameter("planar_enabled") == false and float(material.get_shader_parameter("lake_algae_amount")) == 0.0,"Off the plate: no planar mirror, no algae film")
		check((material.get_shader_parameter("tea_rect") as Vector4).z <= 0.0,"Clear water carries no tea")
	check(sheet.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"It casts no shadow")
	# Steeped, walled round, and a bowl over the level.
	var tarn := KitWater.still(spec.merged({"tea":0.9,"surround":Vector4(0.2,0.2,0.2,0.4)}))
	var steeped := tarn.material_override as ShaderMaterial
	check((steeped.get_shader_parameter("tea_rect") as Vector4).z > 0.0 and steeped.get_shader_parameter("tea_map") is Texture2D,"Steeped, its tea lies over all of it")
	check(steeped.get_shader_parameter("surround") == Vector4(0.2,0.2,0.2,0.4),"Its walls darken what it mirrors low down (surround)")
	var dry := KitWater.still({"level":LEVEL-2.0,"ground":func(x: float, z: float) -> float: return bowl(x,z),"rect":Rect2(-6.0,-6.0,12.0,12.0)})
	check(dry.mesh == null and int(dry.get_meta("cells")) == 0,"A bowl with nothing under the level draws nothing")
	for node: Node in [sheet,tarn,dry]: node.free()
	print("PASS: kit water" if failures == 0 else "FAIL: kit water (%d)" % failures)
	quit(1 if failures else 0)
