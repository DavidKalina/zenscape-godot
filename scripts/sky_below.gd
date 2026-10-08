extends Node3D
## The lower world under the cloud sea (`--below`): dived down through the
## sea, the plane comes out under the cloud's underside over an ocean thick
## with islands (scripts/sky_archipelago.gd), the mountain ranges standing
## down into it, and climbs back up through the cloud to the islands above.
##
## The two worlds never show together. Above, the sea never parts under
## --below (scripts/sky_flight.gd); the swap is made deep in the sea's
## vapour (`band`), under a full white-out, with CROSS metres of play each
## way so it never flickers at the line (`cross`). Below, the sky past the
## deck is the lower world's air (shaders/reference_sky.gdshader
## `below_world`), the ranges' rock runs on down past the sea (scripts/
## sky_peaks.gd `open_sea`), the haze is thickest by the water (scripts/
## sky_haze.gd), and the ocean (`ocean`) lies OCEAN down, the glide's
## floor just over it (SkyGlide `floor_y`, `water`).
##
## Overhead, the cloud sea is seen from beneath: the cloud volume (scripts/
## cloud_volume.gd), which marches its heaps from wherever the eye is, draws
## their undersides near, grey-blue over their hearts and lit through their
## gaps, in the deck's colours from beneath (its `from_below`); over them,
## a plane just over the swap (`ceiling`, shaders/sky_below_ceiling
## .gdshader) is what shows through the gaps, the brighter cloud lit from
## above and here and there a rift onto the open sky, and out past the
## volume's reach it paints the undersides itself, settling far out to the
## same mean as the volume's far heaps so the handover never shows. Without
## the volume (`--old-clouds`, or no RenderingDevice) the ceiling paints
## them everywhere and the old near sea is put away while below. Over it
## all lies the lower world's air (`air`, shaders/sky_below_air.gdshader):
## the far islands and ranges in layers into it, rock fading up into the
## cloud before it meets the deck, and the sun's shafts down through the
## heaps' gaps, read off the volume's shade map. The air and the deck take
## the hour: cool pearl by day, warm toward a low sun, soft blue at night
## (shaders/reference_sky_common.gdshaderinc zsBelowAir, zsBelowDeck).
##
## The ocean is the islands' own water (the plate's still water as the islet
## ponds draw it, scripts/sky_islets.gd `_pond_material`): its wind chop,
## the gusts' cat's paws, glints and the shore's foam, made a sea (its
## marine chop and ripples), its colour deepening with the true depth of the
## bed under each pixel (`depth_read`): pale and clear over an island's
## shelf, deep blue off it, and mirroring the cloud overhead (`below_sky`).
## It is one sheet kept under the eye (`_sheet`): fine near, coarser ring by
## ring out to REACH, laid on its own lattice as it moves so the water never
## swims, its chop calming with distance (the fetch it is given) so the far
## water lies glassy.
##
## OCEAN is -300: the ring's runs (most of the ranges, scripts/sky_world.gd
## `layout`) end at about BASE (-280) in their own heights and stand about
## there in the world, and its massifs reach -340, so at -300 most rock
## meets the water as it was built, a little stretched; every range's flanks
## from the sea down are drawn out so its foot lies SINK under the water
## (SkyPeaks `sunk`), the low ridges and foothills most. It leaves about 150
## clear metres between the cloud and the water to fly in.

const SkyArchipelago = preload("res://scripts/sky_archipelago.gd")
const SkyIslet = preload("res://scripts/sky_islet.gd")
const WaterFlowView = preload("res://scripts/water_flow_view.gd")

## The cloud sea's top (scripts/sky_flight.gd SEA_Y), where the swap is.
const SEA := -105.0
## The ceiling: just over the swap, so from below it hides all of the
## world above but the cloud's own heaps, whose lower bodies (from their
## feet, SkySea FLOOR, up to it) the volume draws under it.
const CEILING := -100.0
## The ocean's height, the glide's floor over it (low: the islands' rims
## stand FREEBOARD over the water, and are landed on), and how far under
## the water every range's foot is drawn down to.
const OCEAN := -300.0
const FLOOR := OCEAN+2.0
const SINK := 30.0
const FOOT := OCEAN-SINK
## The swap's play each way of SEA (m), and the vapour it is always made
## under (it snaps up to at least this as it happens).
const CROSS := 3.0
const SNAP := 0.97
## The sea's vapour round the swap: coming in from x down to y, whole to z,
## gone by w (m).
const BAND := Vector4(-65.0,-95.0,-115.0,-145.0)
## The archipelago is built from this high on a dive (m), so the islands
## are there by the time the plane comes out under the cloud.
const PREPARE := -60.0
## Half the ceiling's span (m): SkyWorld VIEW_FAR.
const REACH := 9000.0
## The air's sheet draws after the see-through pass's water and cloud.
const AIR_PRIORITY := 100
## The ocean's sheet (`_sheet`): its finest cells (m), the inner square's
## half (in those cells), and the distance over which its chop calms (m).
const SHEET_STEP := 2.0
const SHEET_CELLS := 40
const CALM := Vector2(180.0,700.0)
## The fetch an open sea gives every way (the lake chop's full, 9 m and up).
const OPEN_FETCH := 9.0
## The ocean's depth ramp (the water body's `tint_*`): sea-sized, so a
## shelf a metre deep is pale and clear and the water is deep blue by about
## TINT_DEPTHS.y and nearly black-blue by ABYSS_DEPTHS.y.
const TINT_DEPTHS := Vector3(0.9,3.2,0.9)
const ABYSS_DEPTHS := Vector2(3.5,11.0)
const TINT_SHALLOW := Color(0.36,0.72,0.66)
const TINT_ABYSS := Color(0.05,0.17,0.27)

## Whether this run has the lower world: `--below`.
static var _on := -1
static func on() -> bool:
	if _on < 0: _on = int("--below" in OS.get_cmdline_user_args())
	return _on == 1

## True while the eye is under the cloud.
var below := false
## The ranges (scripts/sky_peaks.gd), opened to the lower world while below.
var peaks: Node3D
## The sky world's islands (scripts/sky_islands.gd), whose islets lend the
## archipelago their materials, and the old near sea to put away below
## without the cloud volume.
var islands: Node3D
var near_sea: Node3D
var cloud_volume: Node3D
## The scene, whose look pass holds the near sea and the cloud volume.
var scene: Node
var ocean: MeshInstance3D
var ceiling: MeshInstance3D
## The lower world's air (shaders/sky_below_air.gdshader): a sheet over the
## screen that lays the air perspective, the rock going up into the cloud
## and the light shafts through the heaps' gaps over the scene.
var air: MeshInstance3D
var archipelago: Node3D
## The ocean's water: the islets' pond material made a sea (`_sea_water`).
var water: ShaderMaterial
var _arrived := false
var _last_eye := Vector3.INF
static var _sheet_mesh: ArrayMesh

func _init() -> void:
	name = "SkyBelow"
	ocean = MeshInstance3D.new()
	ocean.name = "Ocean"
	ocean.mesh = _sheet()
	ocean.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ocean.custom_aabb = AABB(Vector3(-REACH,-2.0,-REACH),Vector3(REACH*2.0,4.0,REACH*2.0))
	ocean.set_meta("skip_reflection",true)
	water = _sea_water(null)
	ocean.material_override = water
	add_child(ocean)
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE*REACH*2.0
	var lid := ShaderMaterial.new()
	lid.shader = preload("res://shaders/sky_below_ceiling.gdshader")
	plane.material = lid
	ceiling = MeshInstance3D.new()
	ceiling.name = "Ceiling"
	ceiling.mesh = plane
	ceiling.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ceiling.set_meta("skip_reflection",true)
	add_child(ceiling)
	air = MeshInstance3D.new()
	air.name = "Air"
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0,2.0)
	air.mesh = quad
	var haze := ShaderMaterial.new()
	haze.shader = preload("res://shaders/sky_below_air.gdshader")
	haze.render_priority = AIR_PRIORITY
	haze.set_shader_parameter("ocean",OCEAN)
	haze.set_shader_parameter("ceiling",CEILING)
	air.material_override = haze
	air.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	air.ignore_occlusion_culling = true
	# Drawn over the whole screen wherever the camera looks: never culled.
	air.custom_aabb = AABB(Vector3.ONE*-1e6,Vector3.ONE*2e6)
	air.set_meta("skip_reflection",true)
	add_child(air)
	archipelago = SkyArchipelago.new()
	archipelago.ocean = OCEAN
	_show()

## Set into the sky world: the archipelago stands in the islands' frame, as
## their islets do, and is left out of their copies (SkyIslands `skip`).
func attach(owner_islands: Node3D) -> void:
	islands = owner_islands
	peaks = islands.get("peaks")
	if archipelago.get_parent() != null: archipelago.get_parent().remove_child(archipelago)
	islands.add_child(archipelago)
	var skip: Variant = islands.get("skip")
	if skip is Array: (skip as Array).append(archipelago)
	_show()

## How white the sea's vapour is at height `y` (0 to 1).
static func band(y: float) -> float:
	return minf(smoothstep(BAND.x,BAND.y,y),smoothstep(BAND.w,BAND.z,y))

## Each frame: crosses to below under SEA-CROSS and back above over
## SEA+CROSS. True on the frame it crosses.
func cross(y: float) -> bool:
	var was := below
	if below and y > SEA+CROSS: below = false
	elif not below and y < SEA-CROSS: below = true
	if below == was: return false
	_show()
	return true

## Back above, as at the start of a glide.
func reset() -> void:
	_arrived = false
	_last_eye = Vector3.INF
	if not below: return
	below = false
	_show()

## The ocean under `eye` (global) on its own lattice, the ceiling over it,
## and the archipelago round it once the eye is on its way down; `origin`
## is the islands' swaps added up (SkyIslands `origin`), which the
## ceiling's billows and the islands' places take in.
func follow(eye: Vector3, origin: Vector3, delta := 0.0) -> void:
	var lattice := SHEET_STEP*2.0
	ocean.position = Vector3(snappedf(eye.x,lattice),OCEAN,snappedf(eye.z,lattice))
	ceiling.position = Vector3(eye.x,CEILING,eye.z)
	var lid: ShaderMaterial = (ceiling.mesh as PlaneMesh).material
	lid.set_shader_parameter("home",Vector2(origin.x,origin.z))
	lid.set_shader_parameter("volume_reach",_volume_reach())
	_take_materials()
	_take_clouds()
	# On the way down the islands are made, and the landforms asked for laid
	# ahead of where the plane comes out.
	var going := below or eye.y < PREPARE
	if going and not _arrived and _last_eye != Vector3.INF:
		_arrived = true
		archipelago.arrive(eye,Vector2(eye.x-_last_eye.x,eye.z-_last_eye.z))
	elif not going and eye.y > PREPARE+20.0:
		_arrived = false
	if going: archipelago.advance(delta,eye,origin)
	_last_eye = eye

## The lower world's solid under a global point, Vector2(top, underside):
## an island's, else a range's (its flanks drawn down under the water),
## else null. What the glide reads while below, instead of the sky's.
func body(point: Vector3) -> Variant:
	var island: Variant = archipelago.body(point)
	if island != null: return island
	return peaks.body(point) if peaks != null else null

## The archipelago's islands (their islets node, scripts/sky_islets.gd).
func islets() -> Node3D:
	return archipelago.islets

## Where F comes in to land below: the ground at the middle of the nearest
## island within `reach` (global), or INF.
func landing_spot(point: Vector3, reach: float) -> Vector3:
	var b: Dictionary = archipelago.nearest(point,reach)
	if b.is_empty(): return Vector3.INF
	var at: Vector3 = archipelago.islets.place(b)
	return at+Vector3.UP*float(b.shape.ground_at(Vector2.ZERO))

func _show() -> void:
	ocean.visible = below
	ceiling.visible = below
	air.visible = below
	archipelago.visible = below
	if peaks != null and peaks.has_method("open_sea"): peaks.open_sea(below)
	# The old near sea, seen from under its floor, is put away; the cloud
	# volume draws the heaps from below itself.
	if near_sea != null and cloud_volume == null: near_sea.visible = not below
	# The cloud volume's heaps, seen from beneath, take the deck's colours.
	if cloud_volume != null: (cloud_volume.get("material") as ShaderMaterial).set_shader_parameter("from_below",1.0 if below else 0.0)

## The cloud volume's reach (m, its near sea's), or 0 with none drawing.
func _volume_reach() -> float:
	if cloud_volume == null or not cloud_volume.get("enabled") or near_sea == null: return 0.0
	return float(near_sea.get("reach"))

## The near sea and the cloud volume, from the scene's look pass.
func _take_clouds() -> void:
	if near_sea != null or scene == null: return
	var look: Variant = scene.get("look_pass")
	if not look is Object: return
	near_sea = look.get("sea")
	cloud_volume = look.get("cloud_volume")
	_show()

## The islets' materials, once the sky is built (SkyIslands `build`): the
## archipelago's look and the ocean's water are theirs.
func _take_materials() -> void:
	if islands == null: return
	var source: Node3D = islands.get("islets")
	if source == null or source.get("ground_source") == null: return
	if not archipelago.take_materials(source): return
	water = _sea_water(source._pond_material())
	ocean.material_override = water

## The islets' pond water (`pond`, or the plate's still water's shader with
## no pond to copy) made a sea: the marine chop and ripples, the depth read
## per pixel off the bed under it, a sea's depth ramp, the shore's foam
## where it meets the bed, and the cloud overhead in its mirror.
static func _sea_water(pond: Material) -> ShaderMaterial:
	var sea: ShaderMaterial
	if pond is ShaderMaterial: sea = (pond as ShaderMaterial).duplicate()
	else:
		sea = ShaderMaterial.new()
		sea.shader = preload("res://shaders/reference_water.gdshader")
		sea.set_shader_parameter("planar_enabled",false)
		sea.set_shader_parameter("depth_tint",true)
		sea.set_shader_parameter("tint_mid",WaterFlowView.TINT.mid)
		sea.set_shader_parameter("tint_deep",WaterFlowView.TINT.deep)
	sea.set_shader_parameter("depth_read",true)
	sea.set_shader_parameter("below_sky",1.0)
	sea.set_shader_parameter("shore_distance",true)
	sea.set_shader_parameter("live_level",false)
	sea.set_shader_parameter("shallow_clear",0.0)
	sea.set_shader_parameter("lake_marine_chop",1.0)
	sea.set_shader_parameter("lake_marine_ripples",1.0)
	sea.set_shader_parameter("tint_shallow",TINT_SHALLOW)
	sea.set_shader_parameter("tint_abyss",TINT_ABYSS)
	sea.set_shader_parameter("tint_depths",TINT_DEPTHS)
	sea.set_shader_parameter("tint_abyss_depths",ABYSS_DEPTHS)
	return sea

## The ocean's sheet, made once: a square of SHEET_STEP cells SHEET_CELLS
## each way of the middle, then rings each twice as coarse and twice as
## wide as the last, out past REACH; where a ring meets the finer one
## inside it, its cells take the finer one's midpoints, so the sheet has no
## cracks. Every vertex carries what the pond water reads (SkyIslet
## `water_arrays`): a depth for the chop (UV2.x), no run to a bank (UV.x 0,
## the shore's foam then following the bed read per pixel), and the open
## sea's fetch every way, calming over CALM from the middle.
static func _sheet() -> ArrayMesh:
	if _sheet_mesh != null: return _sheet_mesh
	var vertices := PackedVector3Array()
	var fetch_a := PackedFloat32Array()
	var fetch_b := PackedFloat32Array()
	var index := {}
	var faces := PackedInt32Array()
	var unit := SHEET_STEP*0.5
	var at := func(p: Vector2) -> int:
		var key := Vector2i(roundi(p.x/unit),roundi(p.y/unit))
		if index.has(key): return index[key]
		var id := vertices.size()
		vertices.append(Vector3(p.x,0.0,p.y))
		var f := OPEN_FETCH*(1.0-smoothstep(CALM.x,CALM.y,p.length()))
		for k in range(4):
			fetch_a.append(f)
			fetch_b.append(f)
		index[key] = id
		return id
	var n := SHEET_CELLS
	var level := 0
	var size := SHEET_STEP
	while true:
		var hole := n/2 if level > 0 else 0
		for j in range(-n,n):
			for i in range(-n,n):
				if level > 0 and i >= -hole and i < hole and j >= -hole and j < hole: continue
				var corners: Array[Vector2] = [Vector2(i,j)*size,Vector2(i+1,j)*size,Vector2(i+1,j+1)*size,Vector2(i,j+1)*size]
				# Edges on the hole's border take the finer ring's midpoints.
				var ring: Array[Vector2] = []
				for e in range(4):
					ring.append(corners[e])
					if level > 0 and _on_hole(corners[e],corners[(e+1) % 4],hole*size): ring.append((corners[e]+corners[(e+1) % 4])*0.5)
				if ring.size() == 4:
					var ids := [at.call(ring[0]),at.call(ring[1]),at.call(ring[2]),at.call(ring[3])]
					faces.append_array([ids[0],ids[1],ids[2],ids[0],ids[2],ids[3]])
				else:
					var middle: int = at.call((corners[0]+corners[2])*0.5)
					for e in range(ring.size()): faces.append_array([middle,at.call(ring[e]),at.call(ring[(e+1) % ring.size()])])
		if n*size >= REACH: break
		level += 1
		size *= 2.0
	var count := vertices.size()
	var normals := PackedVector3Array()
	normals.resize(count)
	normals.fill(Vector3.UP)
	var uv := PackedVector2Array()
	uv.resize(count)
	var uv2 := PackedVector2Array()
	uv2.resize(count)
	uv2.fill(Vector2(3.0,0.0))
	var colors := PackedColorArray()
	colors.resize(count)
	colors.fill(WaterFlowView.TINT.mid.srgb_to_linear())
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_CUSTOM0] = fetch_a
	arrays[Mesh.ARRAY_CUSTOM1] = fetch_b
	arrays[Mesh.ARRAY_INDEX] = faces
	_sheet_mesh = ArrayMesh.new()
	_sheet_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},SkyIslet.WATER_FORMAT)
	return _sheet_mesh

## True if the edge from `a` to `b` lies on the border of the square hole
## `edge` m each way of the middle.
static func _on_hole(a: Vector2, b: Vector2, edge: float) -> bool:
	if is_equal_approx(a.x,b.x) and is_equal_approx(absf(a.x),edge): return absf(a.y) <= edge+0.01 and absf(b.y) <= edge+0.01
	if is_equal_approx(a.y,b.y) and is_equal_approx(absf(a.y),edge): return absf(a.x) <= edge+0.01 and absf(b.x) <= edge+0.01
	return false

## The sheet is static and would outlive the scene: let go with it.
func _exit_tree() -> void:
	_sheet_mesh = null
