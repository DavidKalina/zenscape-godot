extends Node3D
## Dense meadow grass for the Ultra tier. One MultiMesh of three-blade clumps
## is shared by an 8x8 grid of tiles, so each tile culls on its own. The GPU
## does the placing (shaders/dense_grass.gdshader): heights come from the
## precipitation ground map the chunk editor already keeps current, and colour
## and density from a mask baked here from the terrain mesh on a worker, so
## blades stand only where the ground reads green and match it at the root.
const HALF := 14.0
const TILES := 8
const SIDE := 32
const MASK_SIZE := 128
## The ground map's span, which the mask shares texel for texel.
const MAP_SPAN := 32.0
const BLADES := 3
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
	_baked = true

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

## Three tapered blades round a shared root. x/z hold each blade's offset and
## width in metres, UV.y its height fraction, UV2 its phase and lean.
static func _clump_mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var heights := [0.0, 0.35, 0.7]
	var widths := [1.0, 0.8, 0.5]
	for blade in range(BLADES):
		var offset := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 0.05)
		var side := Vector2.from_angle(rng.randf() * TAU) * 0.011
		var extra := Vector2(float(blade) / BLADES, rng.randf_range(-1.0, 1.0))
		var rows: Array[PackedVector3Array] = []
		var uvs: Array[PackedVector2Array] = []
		for k in range(3):
			var half: Vector2 = side * float(widths[k])
			rows.append(PackedVector3Array([Vector3(offset.x - half.x, 0.0, offset.y - half.y), Vector3(offset.x + half.x, 0.0, offset.y + half.y)]))
			uvs.append(PackedVector2Array([Vector2(0.0, heights[k]), Vector2(1.0, heights[k])]))
		var tip := Vector3(offset.x, 0.0, offset.y)
		for k in range(2):
			for corner in [[k, 0], [k, 1], [k + 1, 0], [k, 1], [k + 1, 1], [k + 1, 0]]:
				surface.set_uv(uvs[corner[0]][corner[1]])
				surface.set_uv2(extra)
				surface.set_normal(Vector3.UP)
				surface.add_vertex(rows[corner[0]][corner[1]])
		for corner in [[2, 0], [2, 1]]:
			surface.set_uv(uvs[corner[0]][corner[1]])
			surface.set_uv2(extra)
			surface.set_normal(Vector3.UP)
			surface.add_vertex(rows[corner[0]][corner[1]])
		surface.set_uv(Vector2(0.5, 1.0))
		surface.set_uv2(extra)
		surface.set_normal(Vector3.UP)
		surface.add_vertex(tip)
	return surface.commit()
