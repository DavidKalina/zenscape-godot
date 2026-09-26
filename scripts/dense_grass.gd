extends Node3D
## Dense meadow grass for the Ultra tier. One MultiMesh of blade tufts is
## shared by an 8x8 grid of tiles, so each tile culls on its own. The GPU
## does the placing (shaders/dense_grass.gdshader): heights come from the
## precipitation ground map the chunk editor already keeps current, and colour
## and density from a mask baked here from the terrain mesh on a worker, so
## blades stand only where the ground reads green and match it at the root.
## The painterly look (tussocks, arcing blades, mass shading, rolling wind
## waves, seed heads and flowers) is in docs/scenic/grass-look.md.
const HALF := 14.0
const TILES := 8
const SIDE := 32
const MASK_SIZE := 128
## The ground map's span, which the mask shares texel for texel.
const MAP_SPAN := 32.0
## Blades per tuft, fanned round its root and arcing outward, like the
## source's grass tuft (foliage.js grassTuftGeometry) but curved and softer.
const BLADES := 6
## Rows up each blade below its pointed tip.
const BLADE_ROWS := [0.0, 0.3, 0.58, 0.82]
const BLADE_TAPER := [1.0, 0.92, 0.72, 0.44]
## Half-width at the root, how far from the tuft's centre blades root, and
## how far the tip leans out, as a share of the blade's height.
const BLADE_HALF_WIDTH := 0.017
const ROOT_SPREAD := Vector2(0.012, 0.065)
const LEAN := Vector2(0.18, 0.5)
## Each blade's height as a share of the tuft's.
const BLADE_SHARE := Vector2(0.55, 1.0)
## The accent stem that carries a flower or seed head, taller than the tuft.
const STEM_SHARE := 1.3
const STEM_HALF_WIDTH := 0.004
## Petals round a flower's face.
const PETALS := 5
const REBAKE_SECONDS := 0.5
var material := ShaderMaterial.new()
var mask := ImageTexture.new()
var _scene: Node3D
var _tiles: Array[MultiMeshInstance3D] = []
var _baked_mesh: Mesh
var _baked := false
var _bake_busy := false
var _since_change := 0.0

func setup(scene: Node3D) -> void:
	_scene = scene
	name = "DenseGrass"
	visible = false
	material.shader = preload("res://shaders/dense_grass.gdshader")
	material.set_shader_parameter("palette_role", 1)
	material.set_shader_parameter("grid_side", SIDE)
	var tile_size := HALF * 2.0 / TILES
	material.set_shader_parameter("spacing", tile_size / SIDE)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _clump_mesh()
	multimesh.instance_count = SIDE * SIDE
	# Identity for every clump: the shader places them.
	var identity := PackedFloat32Array()
	identity.resize(SIDE * SIDE * 12)
	for i in range(SIDE * SIDE):
		identity[i * 12] = 1.0
		identity[i * 12 + 5] = 1.0
		identity[i * 12 + 10] = 1.0
	multimesh.buffer = identity
	for z in range(TILES):
		for x in range(TILES):
			var origin := Vector2(-HALF + x * tile_size, -HALF + z * tile_size)
			var tile := MultiMeshInstance3D.new()
			tile.multimesh = multimesh
			tile.material_override = material
			tile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			tile.custom_aabb = AABB(Vector3(origin.x - 1.0, NativeTerrainData.MIN_HEIGHT - 1.0, origin.y - 1.0), Vector3(tile_size + 2.0, NativeTerrainData.MAX_HEIGHT + 3.0, tile_size + 2.0))
			tile.set_instance_shader_parameter("tile_origin", origin)
			tile.set_meta("skip_reflection", true)
			add_child(tile)
			_tiles.append(tile)
	scene.add_child(self)

## Show on Ultra with the look pass on, once a mask exists; rebake the mask a
## moment after the terrain mesh last changed, never while one is in flight.
func update(wanted: bool, delta: float) -> void:
	var editor = _scene.get("_chunk_editor")
	var terrain: MeshInstance3D = editor.terrain if editor != null else null
	visible = wanted and _baked and terrain != null
	if not wanted or terrain == null or terrain.mesh == null: return
	if terrain.mesh == _baked_mesh or _bake_busy:
		_since_change = 0.0
		return
	_since_change += delta
	if _baked and _since_change < REBAKE_SECONDS: return
	_bake(terrain.mesh, editor.data)

func _bake(mesh: Mesh, data: NativeTerrainData) -> void:
	_bake_busy = true
	_baked_mesh = mesh
	# The editor keeps the arrays it last built; reading them back from the
	# mesh would stall on the GPU. Tunnels and chasms wrap the built mesh.
	var built: Mesh = mesh
	if built == data._tunnel_mesh: built = data._tunnel_source
	if built == data._chasm_mesh: built = data._chasm_source
	var arrays: Array
	if built == data._mesh_result and not data._mesh_arrays.is_empty(): arrays = data._mesh_arrays
	elif built == data.source_mesh: arrays = data._arrays
	else: arrays = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var job = preload("res://scripts/background_work.gd").new()
	var image: Image = await job.run(bake_mask.bind(vertices, colors), get_tree())
	_bake_busy = false
	if not is_inside_tree(): return
	if _baked: mask.update(image)
	else: mask.set_image(image)
	material.set_shader_parameter("grass_mask", mask)
	material.set_shader_parameter("world_offset", world_offset(int(data._recipe_settings.get("seed", 0))))
	_baked = true

## Shifts the shader's world-scale noise per seed, so each world has its own
## tussocks, dry patches and flower drifts.
static func world_offset(seed_value: int) -> Vector2:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return Vector2(rng.randf_range(0.0, 97.0), rng.randf_range(0.0, 97.0))

## Rasterise the terrain's faces from above into the mask: rgb the face's own
## colour, alpha how green it is by the same test the ground palette uses.
## The highest face wins where the land overhangs. Pure data, worker-safe.
static func bake_mask(vertices: PackedVector3Array, colors: PackedColorArray) -> Image:
	var texels := PackedFloat32Array()
	texels.resize(MASK_SIZE * MASK_SIZE * 4)
	var top := PackedFloat32Array()
	top.resize(MASK_SIZE * MASK_SIZE)
	top.fill(-INF)
	var scale := MASK_SIZE / MAP_SPAN
	var has_colors := colors.size() == vertices.size()
	for i in range(0, vertices.size() - 2, 3):
		var a := vertices[i]
		var b := vertices[i + 1]
		var c := vertices[i + 2]
		# Texel centres sit on whole numbers in this space.
		var ax := (a.x + MAP_SPAN * 0.5) * scale - 0.5
		var az := (a.z + MAP_SPAN * 0.5) * scale - 0.5
		var bx := (b.x + MAP_SPAN * 0.5) * scale - 0.5
		var bz := (b.z + MAP_SPAN * 0.5) * scale - 0.5
		var cx := (c.x + MAP_SPAN * 0.5) * scale - 0.5
		var cz := (c.z + MAP_SPAN * 0.5) * scale - 0.5
		var area := (bx - ax) * (cz - az) - (bz - az) * (cx - ax)
		if absf(area) < 0.000001: continue
		var x0 := maxi(ceili(minf(ax, minf(bx, cx))), 0)
		var x1 := mini(floori(maxf(ax, maxf(bx, cx))), MASK_SIZE - 1)
		var z0 := maxi(ceili(minf(az, minf(bz, cz))), 0)
		var z1 := mini(floori(maxf(az, maxf(bz, cz))), MASK_SIZE - 1)
		if x0 > x1 or z0 > z1: continue
		var color := (colors[i] + colors[i + 1] + colors[i + 2]) / 3.0 if has_colors else Color(0.1, 0.2, 0.05)
		var green := smoothstep(0.005, 0.06, color.g - maxf(color.r, color.b))
		for z in range(z0, z1 + 1):
			for x in range(x0, x1 + 1):
				var w0 := ((bx - x) * (cz - z) - (bz - z) * (cx - x)) / area
				var w1 := ((cx - x) * (az - z) - (cz - z) * (ax - x)) / area
				var w2 := 1.0 - w0 - w1
				if w0 < -0.0001 or w1 < -0.0001 or w2 < -0.0001: continue
				var y := a.y * w0 + b.y * w1 + c.y * w2
				var index := z * MASK_SIZE + x
				if y <= top[index]: continue
				top[index] = y
				texels[index * 4] = color.r
				texels[index * 4 + 1] = color.g
				texels[index * 4 + 2] = color.b
				texels[index * 4 + 3] = green
	return Image.create_from_data(MASK_SIZE, MASK_SIZE, false, Image.FORMAT_RGBAF, texels.to_byte_array())

## A tuft of arcing blades round a shared root, and one accent stem with a
## flower face and a seed spike on its tip that the shader shows on a few
## tufts only. Positions are metres before the shader scales them:
## - VERTEX.xz a blade's half-width across (or a head's shape), VERTEX.y a
##   seed spike's rise;
## - UV (across, t): t the height fraction up the blade; on heads x is 0 for
##   the flower face and 1 for the seed spike;
## - CUSTOM0 (lean x, lean z, height share, flutter phase), lean in blade
##   heights;
## - CUSTOM1 (root x, root z, blade index, part), part 0 blade, 1 stem, 2 head.
static func _clump_mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
	surface.set_custom_format(1, SurfaceTool.CUSTOM_RGBA_FLOAT)
	for blade in range(BLADES):
		var angle := (float(blade) / BLADES) * TAU + rng.randf() * 0.9
		var root := Vector2.from_angle(angle) * rng.randf_range(ROOT_SPREAD.x, ROOT_SPREAD.y)
		var out := angle + rng.randf_range(-0.4, 0.4)
		var lean := Vector2.from_angle(out) * rng.randf_range(LEAN.x, LEAN.y)
		# Tallest blades first, so the far tufts keep them when they drop the rest.
		var share := lerpf(BLADE_SHARE.y, BLADE_SHARE.x, float(blade) / (BLADES - 1)) * rng.randf_range(0.9, 1.0)
		var custom0 := Color(lean.x, lean.y, share, rng.randf())
		var custom1 := Color(root.x, root.y, float(blade), 0.0)
		var side := Vector2.from_angle(out + PI * 0.5) * BLADE_HALF_WIDTH * rng.randf_range(0.85, 1.15)
		_add_blade(surface, side, BLADE_ROWS, BLADE_TAPER, true, custom0, custom1)
	# The accent stem, near the centre and nearly upright.
	var stem_lean := Vector2.from_angle(rng.randf() * TAU) * 0.08
	var stem0 := Color(stem_lean.x, stem_lean.y, STEM_SHARE, rng.randf())
	var stem1 := Color(0.0, 0.0, float(BLADES), 1.0)
	_add_blade(surface, Vector2(STEM_HALF_WIDTH, 0.0), [0.0, 0.5, 1.0], [1.0, 0.8, 0.6], false, stem0, stem1)
	var head1 := Color(0.0, 0.0, float(BLADES), 2.0)
	# The flower face: a fan of petals round an eye, lying flat.
	for k in range(PETALS):
		var p0 := Vector2.from_angle(TAU * k / PETALS)
		var p1 := Vector2.from_angle(TAU * (k + 1) / PETALS)
		for corner in [Vector2.ZERO, p0, p1]:
			_vertex(surface, Vector3(corner.x, 0.0, corner.y), Vector2(0.0, 1.0), stem0, head1)
	# The seed spike: two crossed slivers standing on the tip.
	for axis in [Vector3(1.0, 0.0, 0.0), Vector3(0.0, 0.0, 1.0)]:
		var low_a: Vector3 = -axis + Vector3(0.0, -0.1, 0.0)
		var low_b: Vector3 = axis + Vector3(0.0, -0.1, 0.0)
		var high_a: Vector3 = -axis * 0.5 + Vector3(0.0, 0.8, 0.0)
		var high_b: Vector3 = axis * 0.5 + Vector3(0.0, 0.8, 0.0)
		var top := Vector3(0.0, 1.0, 0.0)
		for corner in [low_a, low_b, high_a, low_b, high_b, high_a, high_a, high_b, top]:
			_vertex(surface, corner, Vector2(1.0, 1.0), stem0, head1)
	surface.index()
	return surface.commit()

## One blade: a strip of rows from root to tip, pointed when `pointed`.
static func _add_blade(surface: SurfaceTool, side: Vector2, rows: Array, taper: Array, pointed: bool, custom0: Color, custom1: Color) -> void:
	for k in range(rows.size() - 1):
		var a: Vector2 = side * float(taper[k])
		var b: Vector2 = side * float(taper[k + 1])
		var t0: float = rows[k]
		var t1: float = rows[k + 1]
		var quad := [[-a, 0.0, t0], [a, 1.0, t0], [-b, 0.0, t1], [a, 1.0, t0], [b, 1.0, t1], [-b, 0.0, t1]]
		for corner in quad:
			var offset: Vector2 = corner[0]
			_vertex(surface, Vector3(offset.x, 0.0, offset.y), Vector2(corner[1], corner[2]), custom0, custom1)
	if not pointed: return
	var last: Vector2 = side * float(taper[taper.size() - 1])
	var t_last: float = rows[rows.size() - 1]
	_vertex(surface, Vector3(-last.x, 0.0, -last.y), Vector2(0.0, t_last), custom0, custom1)
	_vertex(surface, Vector3(last.x, 0.0, last.y), Vector2(1.0, t_last), custom0, custom1)
	_vertex(surface, Vector3.ZERO, Vector2(0.5, 1.0), custom0, custom1)

static func _vertex(surface: SurfaceTool, point: Vector3, uv: Vector2, custom0: Color, custom1: Color) -> void:
	surface.set_uv(uv)
	surface.set_custom(0, custom0)
	surface.set_custom(1, custom1)
	surface.set_normal(Vector3.UP)
	surface.add_vertex(point)
