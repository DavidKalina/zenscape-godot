class_name KitWater
extends RefCounted
## The kit isles' water (docs/scenic/kit-isle-water.md): the edit chunks'
## own water on a hand-built isle. The plate's live water (scripts/
## water_flow_view.gd, ZenScapeWaterFlow `surface`) is a fine sheet, a vertex
## every CELL m, through the plate's pond material (assets/zen_reference/
## geometry.scn `mesh-30`, shaders/lake_reference_water.gdshader): its chop
## lifts each vertex and the shader lights the moved faces as they stand,
## which is the low-poly water; its colour deepens with depth over the bed,
## a lap of foam keeps to the bank, the sky sheens on it and the sun glints
## off it, all moving with the wind and its gusts. A coarse fan has no
## vertices to stand that chop on, and the material's maps read nothing off
## a sheet without its data, which is why the islets' pond water and the
## plate's material on a fan read flat or milky.
##
## `still` lays the same sheet over an isle's ground function: one vertex a
## cell centre over a box, a quad drawn where any corner is wet; a dry corner
## of a drawn quad stands at the level or, where its ground is barely over
## it, just under the ground, so the drawn bank hides the water's edge. Each
## vertex carries what the material reads (as the live water's do): the
## depth palette in COLOR, its run to dry ground in UV.x (the shore foam),
## its depth in UV2.x, its open water in eight directions in CUSTOM0/1 (the
## chop's fetch). Where the water leaves the land (`inside` false: a lip
## over a fall) its vertices stand on the brink, so the sheet runs to the
## lip and the fall's curtain takes it over.
##
## The material is the live still water's, with what ties it to the plate
## let go as the sky islets' ponds let it go (scripts/sky_islets.gd
## `_pond_material`): no planar mirror (its plane is the plate's), no tea map
## over the plate's grid, no algae film. In the planar view's stead the bed
## is read per pixel from the depth buffer (`depth_read`, as the lower
## world's ocean reads it), so the colour deepens, the bed shows through the
## shallows and the lap follows the true bank, pixel by pixel. The sky's
## sheen is the sky's, not the land's; in a bowl of land, `surround` darkens
## what it mirrors low down, as the walls round it would. `tea` steeps it
## all over: a dark slate-blue tarn (scripts/lake_tea.gd).
##
## Only the still sheet is drawn, to the brink of a fall too. The live
## water's moving sheet (the plate's stream material, `mesh-38`, over water
## running faster than 0.22 m/s) was tried down the isles' outflows and the
## aqueduct's channel: it keeps Godot's own sky specular, so out here it
## showed the sky's clouds as white blotches, and over the channel's
## hand-deep film it read as a pale teal slab. The still sheet's chop runs
## with the wind, and a fall's churn whitens its brink.
##
## --old-water draws the isles' water as before (the islets' pond water on
## coarse fans; the aqueduct's channel shader), for A/B.

const WaterFlowView = preload("res://scripts/water_flow_view.gd")

## The sheet's cell (m): the live water's grid (scripts/water_flow.gd CELL).
const CELL := 0.25
## A cell is wet where its ground stands this far under the level (the live
## water's `wet`), and its sheet stands LIFT over the water.
const WET := 0.012
const LIFT := 0.012
## A dry corner of a drawn quad stands this far under its own ground when
## that is under the level.
const DIP := 0.02
## How far past the brink a lip's vertex stands (m), under the fall's top.
const BRINK := 0.04
## The run of open water the chop reads, at most (m; the live water's).
const FETCH := 9.0
## The depth palette's scale (the live water's `depth_scale`); its ends are
## the live water's tint (WaterFlowView TINT).
const DEPTH_SCALE := 0.45
## Steeped water's ends (the shader's `tea_shallow`, `tea_deep`, sRGB) and
## the most of the clear colour that gives way (its TEA_TAKE), for the
## vertex palette, which the depth tint stands in for but the shader's
## fallbacks read.
const TEA_SHALLOW := Color(0.23,0.20,0.14)
const TEA_DEEP := Color(0.063,0.09,0.118)
const TEA_TAKE := 0.85
## The mesh's channels: two float vec4s of fetch.
const FORMAT := WaterFlowView.FORMAT

static var _base: ShaderMaterial
static var _base_props: Array = []

## True with --old-water: the isles' water as it was, for A/B.
static func old_water() -> bool:
	return "--old-water" in preload("res://scripts/launch_args.gd").user_args()

## A still water's sheet over `spec` (a MeshInstance3D). `spec`:
##   level     the water's top (world y);
##   ground    Callable(x, z) -> the bed's height (world y);
##   rect      the box (world x, z) the sheet is laid over;
##   inside    optional Callable(Vector2) -> bool: where water may stand
##             (the land); a wet cell by one outside stands on the brink;
##   cell      the grid's cell (m), CELL unless given;
##   tea       0 clear (the plate's teal) to 1 a dark tarn steeped all over;
##   clear     how deep the shallows stay clear (m; the shader's
##             `shallow_clear`, the live water's SHALLOW_CLEAR unless given);
##   surround  optional Vector4: in a bowl of land, the rim's elevation (w,
##             its sine) and how dark its walls mirror (rgb, a share of the
##             sky's light; the shader's `surround`);
##   falls     optional [Vector4(x, z, radius, strength)]: churn where a fall
##             lands in the water (the shader's `fall_foam`; the plate's edge
##             falls put none on their lip, nor do the isles');
##   jitter    optional: each vertex off the brink stands up to this share
##             of a cell off its grid (a hash of its cell), so the chop's
##             faces don't line up into a weave seen from above;
##   name      the node's name.
## Lay it in the world's frame (or one only moved, never turned): the chop
## and its fetch read world axes. Its meta: "cells" (wet cells), "vertices",
## "triangles"; with nothing wet its mesh is null.
static func still(spec: Dictionary) -> MeshInstance3D:
	var sheet := MeshInstance3D.new()
	sheet.name = str(spec.get("name","Water"))
	var built := arrays(spec)
	var data: Array = built.arrays
	if not data.is_empty():
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,data,[],{},FORMAT)
		sheet.mesh = mesh
	sheet.material_override = material(spec)
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# A planar view (none here yet) would not show the water itself.
	sheet.set_meta("skip_reflection",true)
	sheet.set_meta("cells",built.cells)
	sheet.set_meta("vertices",built.vertices)
	sheet.set_meta("triangles",0 if data.is_empty() else (data[Mesh.ARRAY_INDEX] as PackedInt32Array).size()/3)
	return sheet

## The sheet's mesh arrays (`still`): {"arrays" (an ArrayMesh's arrays,
## indexed, or [] when nothing is wet), "cells" (wet cells), "vertices"}.
static func arrays(spec: Dictionary) -> Dictionary:
	var level := float(spec.level)
	var ground: Callable = spec.ground
	var rect: Rect2 = spec.rect
	var inside: Callable = spec.get("inside",Callable())
	var cell := float(spec.get("cell",CELL))
	var jitter := float(spec.get("jitter",0.0))
	var w := maxi(2,ceili(rect.size.x/cell))
	var h := maxi(2,ceili(rect.size.y/cell))
	var n := w*h
	var at := func(c: int) -> Vector2: return rect.position+Vector2(float(c%w)+0.5,float(c/w)+0.5)*cell
	# Each cell: outside the land, or its ground; wet where that stands under
	# the level.
	var bed := PackedFloat32Array()
	bed.resize(n)
	var out := PackedByteArray()
	out.resize(n)
	var state := PackedByteArray()
	state.resize(n)
	var top := PackedFloat32Array()
	top.resize(n)
	var cells := 0
	for c in range(n):
		var p: Vector2 = at.call(c)
		if inside.is_valid() and not bool(inside.call(p)):
			out[c] = 1
			continue
		bed[c] = float(ground.call(p.x,p.y))
		if bed[c] < level-WET:
			state[c] = 1
			top[c] = level
			cells += 1
	if cells == 0: return {"arrays":[],"cells":0,"vertices":0}
	# A dry cell by a wet one is a bank corner: at the level, or just under
	# its own ground where that is lower.
	for c in range(n):
		if state[c] != 0 or out[c]: continue
		var i := c%w
		var j := c/w
		var found := false
		for dj in range(-1,2):
			for di in range(-1,2):
				var a := i+di
				var b := j+dj
				if a < 0 or b < 0 or a >= w or b >= h: continue
				if state[b*w+a] == 1: found = true
		if not found: continue
		state[c] = 2
		top[c] = minf(level,bed[c]-DIP)
	# Each wet cell's run to dry ground (m), by a chamfer distance; the land's
	# edge and the box's count as dry.
	var shore := PackedFloat32Array()
	shore.resize(n)
	var diagonal := cell*sqrt(2.0)
	for c in range(n):
		if state[c] == 1: shore[c] = 1.0e6
	for pass_index in range(2):
		var c := 0 if pass_index == 0 else n-1
		var to := n if pass_index == 0 else -1
		var step := 1 if pass_index == 0 else -1
		while c != to:
			if state[c] == 1:
				var i := c%w
				var j := c/w
				var best := shore[c]
				for dj in range(-1,2):
					for di in range(-1,2):
						if di == 0 and dj == 0: continue
						var d := diagonal if di != 0 and dj != 0 else cell
						var a := i+di
						var b := j+dj
						if a < 0 or b < 0 or a >= w or b >= h:
							best = minf(best,d)
							continue
						var m := b*w+a
						best = minf(best,(shore[m] if state[m] == 1 else 0.0)+d)
				shore[c] = best
			c += step
	# The fetch: each wet cell's run of open water eight ways (+x, +x+z, +z,
	# -x+z, then the opposites; the chop's zsFetch order), FETCH at most,
	# swept from the far side so each reads its neighbour's.
	var dirs: Array[Vector2i] = [Vector2i(1,0),Vector2i(1,1),Vector2i(0,1),Vector2i(-1,1),Vector2i(-1,0),Vector2i(-1,-1),Vector2i(0,-1),Vector2i(1,-1)]
	var runs: Array[PackedFloat32Array] = []
	for d: Vector2i in dirs:
		var run := PackedFloat32Array()
		run.resize(n)
		var length := cell*Vector2(d).length()
		for jj in range(h):
			var j := h-1-jj if d.y > 0 else jj
			var nj := j+d.y
			if nj < 0 or nj >= h: continue
			for ii in range(w):
				var i := w-1-ii if d.x > 0 else ii
				var ni := i+d.x
				if ni < 0 or ni >= w: continue
				var next := nj*w+ni
				if state[j*w+i] == 1 and state[next] == 1: run[j*w+i] = minf(length+run[next],FETCH)
		runs.append(run)
	# Where a wet cell meets the land's edge, its vertex stands on the brink:
	# found along each side the edge lies on, a little past it.
	var place := PackedVector2Array()
	place.resize(n)
	for c in range(n):
		var p: Vector2 = at.call(c)
		place[c] = p
		if jitter > 0.0:
			var hx := float(hash(Vector2i(c,17)) % 10007)/10007.0-0.5
			var hz := float(hash(Vector2i(c,59)) % 10007)/10007.0-0.5
			place[c] = p+Vector2(hx,hz)*2.0*jitter*cell
		if state[c] != 1 or not inside.is_valid(): continue
		var i := c%w
		var j := c/w
		var shift := Vector2.ZERO
		for d: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var a := i+d.x
			var b := j+d.y
			if a < 0 or b < 0 or a >= w or b >= h or not out[b*w+a]: continue
			var lo := 0.0
			var hi := cell
			for k in range(8):
				var mid := (lo+hi)*0.5
				if bool(inside.call(p+Vector2(d)*mid)): lo = mid
				else: hi = mid
			shift += Vector2(d)*(lo+BRINK)
		place[c] = p+shift
	# The quads drawn: every corner banked or wet, one wet at least; their
	# corners numbered as they are first used.
	var quads := PackedInt32Array()
	var slot := PackedInt32Array()
	slot.resize(n)
	slot.fill(-1)
	var used := PackedInt32Array()
	for j in range(h-1):
		for i in range(w-1):
			var a := j*w+i
			if not state[a] or not state[a+1] or not state[a+w] or not state[a+w+1]: continue
			if state[a] != 1 and state[a+1] != 1 and state[a+w] != 1 and state[a+w+1] != 1: continue
			quads.append(a)
			for k: int in [a,a+1,a+w,a+w+1]:
				if slot[k] < 0:
					slot[k] = used.size()
					used.append(k)
	var shallow := WaterFlowView.TINT.shallow.srgb_to_linear()
	var deep := WaterFlowView.TINT.deep.srgb_to_linear()
	var tea := float(spec.get("tea",0.0))*TEA_TAKE
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var custom0 := PackedFloat32Array()
	var custom1 := PackedFloat32Array()
	for c: int in used:
		var p := place[c]
		var depth := maxf(0.0,top[c]-bed[c])
		vertices.append(Vector3(p.x,top[c]+LIFT,p.y))
		normals.append(Vector3.UP)
		var color := shallow.lerp(deep,1.0-exp(-depth/DEPTH_SCALE))
		if tea > 0.0: color = color.lerp(TEA_SHALLOW.srgb_to_linear().lerp(TEA_DEEP.srgb_to_linear(),smoothstep(0.0,1.2,depth)),tea)
		colors.append(color)
		uv.append(Vector2(shore[c],0.0))
		uv2.append(Vector2(depth,0.0))
		for k in range(4): custom0.append(runs[k][c])
		for k in range(4,8): custom1.append(runs[k][c])
	var indices := PackedInt32Array()
	for a: int in quads:
		var va := slot[a]
		var vb := slot[a+1]
		var vc := slot[a+w]
		var vd := slot[a+w+1]
		# Split along the lower diagonal (the live water's), so a dip into the
		# bank reads as a slope, not a fold.
		if absf(top[a]-top[a+w+1]) <= absf(top[a+1]-top[a+w]): indices.append_array([va,vb,vd,va,vd,vc])
		else: indices.append_array([va,vb,vc,vb,vd,vc])
	var data := []
	data.resize(Mesh.ARRAY_MAX)
	data[Mesh.ARRAY_VERTEX] = vertices
	data[Mesh.ARRAY_NORMAL] = normals
	data[Mesh.ARRAY_COLOR] = colors
	data[Mesh.ARRAY_TEX_UV] = uv
	data[Mesh.ARRAY_TEX_UV2] = uv2
	data[Mesh.ARRAY_CUSTOM0] = custom0
	data[Mesh.ARRAY_CUSTOM1] = custom1
	data[Mesh.ARRAY_INDEX] = indices
	return {"arrays":data,"cells":cells,"vertices":used.size()}

# --- The material ---------------------------------------------------------------------

## The water's material for `spec` (`still`'s: tea, clear, surround,
## falls): the live still water's (WaterFlowView `setup`), let go of the
## plate (SkyIslets `_pond_material`), reading its bed per pixel.
static func material(spec := {}) -> ShaderMaterial:
	if _base == null:
		var source: Node = preload("res://assets/zen_reference/geometry.scn").instantiate()
		_base = source.get_node("mesh-30").mesh.surface_get_material(0).duplicate()
		source.free()
		# Its stored properties in order, read once (here, on the main
		# thread: KitMotif `warm`): what `duplicate` sets on its copy.
		for p: Dictionary in _base.get_property_list():
			if int(p.usage) & PROPERTY_USAGE_STORAGE and p.name != "script": _base_props.append([p.name,_base.get(p.name)])
	# A copy of the base as `duplicate` makes it (each stored property set in
	# turn), without asking the renderer for the shader's parameters, which
	# on a worker waits a frame for each.
	var water := ShaderMaterial.new()
	for prop: Array in _base_props: water.set(prop[0],prop[1])
	# The live still water's own settings.
	water.set_shader_parameter("hide_pool_surface",false)
	water.set_shader_parameter("planar_levels",Vector2(-1000000.0,-1000000.0))
	water.set_shader_parameter("shore_distance",true)
	water.set_shader_parameter("live_level",true)
	water.set_shader_parameter("bed_absorb",WaterFlowView.BED_ABSORB)
	water.set_shader_parameter("depth_tint",true)
	water.set_shader_parameter("tint_shallow",WaterFlowView.TINT.shallow)
	water.set_shader_parameter("tint_mid",WaterFlowView.TINT.mid)
	water.set_shader_parameter("tint_deep",WaterFlowView.TINT.deep)
	water.set_shader_parameter("shallow_clear",float(spec.get("clear",WaterFlowView.SHALLOW_CLEAR)))
	# Off the plate: no mirror, no algae film laid by world position.
	water.set_shader_parameter("planar_enabled",false)
	water.set_shader_parameter("lake_algae_amount",0.0)
	# The bed behind each pixel, from the depth buffer; the walls round it.
	water.set_shader_parameter("depth_read",true)
	water.set_shader_parameter("surround",spec.get("surround",Vector4.ZERO))
	# Steeped all over: one cell of tea over everything.
	var tea := float(spec.get("tea",0.0))
	if tea > 0.0:
		var image := Image.create(1,1,false,Image.FORMAT_L8)
		image.set_pixel(0,0,Color(tea,tea,tea))
		water.set_shader_parameter("tea_map",ImageTexture.create_from_image(image))
		water.set_shader_parameter("tea_rect",Vector4(-100000.0,-100000.0,200000.0,200000.0))
	else: water.set_shader_parameter("tea_rect",Vector4.ZERO)
	# The churn of up to eight falls landing in it (x, z, radius, strength).
	var falls: Array = spec.get("falls",[])
	var foam := PackedVector4Array()
	for f in falls.slice(0,8): foam.append(f as Vector4)
	foam.resize(8)
	water.set_shader_parameter("fall_foam",foam)
	water.set_shader_parameter("fall_foam_count",mini(falls.size(),8))
	return water
