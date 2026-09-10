class_name IslandBuilder
extends Node3D
## A second (third, fourth) 28 m island in the first chunk's exact art style,
## built without a second chunk editor.
##
## The whole-world generators -- `native_landscape_presets.gd` for the eight
## curated formations and `inland_landscape.gd` for the fifteen inland
## compositions -- take a `NativeTerrainData` and nothing else. So does
## `NativeTerrainData.build_mesh_budgeted`, so does `GardenView.rebuild`, so do
## `NativeGardenLandmarks.rebuild` and `NativeGardenFalls.rebuild`. Only
## `NativeChunkEditor` is welded to the live scene -- it reaches for
## `scene._precipitation`, `scene._growth`, `Reference/skirt` and the rest -- and
## the editor contributes no geometry of its own. This class therefore drives the
## same pipeline against a private `NativeTerrainData` and hangs the results
## under itself, so an island is one detached, self-contained `Node3D`.
##
## Everything visual is shared with the first chunk rather than copied: the
## source ArrayMesh and all three `reference_surface.gdshader` materials come out
## of `res://assets/zen_reference/geometry.scn`, whose sub-resources are shared
## across instantiations. The island's ground, earth sides, trunks, canopies,
## grass and water are therefore literally the same material objects the first
## chunk draws with, and cannot drift from it -- including the palette roles
## `SceneLook.source_roles` writes and every growth/fog uniform the scene pushes.
##
## What it does not carry, on purpose:
##   * no collision, no picking, no terrain document, no undo history
##   * no birds (one global animated flock, see `prototype_twin_chunks.gd`)
##   * no per-frame animation: `GardenView._process` and `NativeGardenFalls._process`
##     read `get_parent()` as the fidelity scene and would crash under an island,
##     so both are disabled. Pond and stream surfaces are static meshes and still
##     render; waterfall foam and spray do not animate. Presets place no
##     `waterfall` records, so in practice nothing is lost.
##
## usage
##   var island: Node3D = await IslandBuilder.build(self, {"seed": 11, "preset": "valley"})
##   island.transform = Transform3D(Basis(Vector3.UP, PI), Vector3(50, 0, 0))
##   add_child(island)
##   var y: Variant = island.ground_height_at(Vector2(48.0, 1.0))

## Every setting `build()` reads, with the value used when it is absent.
##
##   seed         Any integer. Drives the formation variation (`seed % 1000`) and
##                the inland genome seed, so it chooses the whole landscape.
##   preset       One of `native_landscape_presets.gd`'s PRESETS: redwood_grove, valley,
##                plateau, cone, ridgeback, horn, canyon, terraced_pools.
##                Ignored when `composition` is set.
##   biome        Override the preset's habitat: one of `NativeFormationShape.BIOMES`
##                (alpine, woodland, meadow, wetland, arid, redwood). "" keeps
##                the preset's own.
##   water        "connected" routes the preset's streams between its pools,
##                "quiet" leaves them still.
##   composition  Non-empty switches to the inland genome instead of a preset:
##                one of `InlandGenome.COMPOSITIONS` (valley, basin, foothills,
##                plateau, meadow, marsh, mountain, massif, dunes, ...).
##   archetype    Inland only, one of `InlandGenome.ARCHETYPES`.
##   landform     Inland only, one of `InlandGenome.LANDFORMS`.
##   habitat      Inland only, one of `InlandGenome.HABITATS`.
##   relief       Inland only, 0.5 .. 1.8 vertical exaggeration.
##   breadth      Inland only, 0.6 .. 1.5 horizontal spread.
##   live         true spreads the build over frames through the scene's
##                `SceneTree` (needs `scene` to be in the tree); false builds
##                synchronously in one blocking call.
const DEFAULTS := {
	"seed": 0,
	"preset": "valley",
	"biome": "",
	"water": "connected",
	"composition": "",
	"archetype": "range",
	"landform": "original",
	"habitat": "meadow",
	"relief": 1.0,
	"breadth": 1.0,
	"live": false,
}

## `native_landscape_presets.gd` declares no class_name.
const Presets = preload("res://scripts/native_landscape_presets.gd")
const Inland = preload("res://scripts/inland_landscape.gd")

## The chunk's half extent in terrain-local XZ, as `native_terrain_data.gd` clamps it.
const HALF := 14.0
## `NativeTerrainRecipe.valid` caps a formation variation at 999, and
## `another_landscape` walks the same 1,000-variant period.
const VARIATIONS := 1000

## The settings this island was built from, defaults filled in.
var settings := {}
## Chosen by `settings.seed`; the landscape is a pure function of it plus the
## recipe choice, so two islands with the same seed are identical.
var seed: int = 0
## This island's own terrain. Nothing else shares it -- not the first chunk's.
var data: NativeTerrainData
var terrain: MeshInstance3D
var skirt: MeshInstance3D
var content: GardenView
var landmarks: NativeGardenLandmarks
var falls: NativeGardenFalls
## Wall-clock microseconds the whole build took, and the same split by stage.
var build_usec := 0
var build_stage_usec := {}

## Build one island and return it detached, with no parent, ready to be placed
## and added wherever the caller wants it.
##
## `scene` is borrowed only to reach a `SceneTree`: the island is parented to it
## for the duration of the build, because `GardenView` and `NativeGardenLandmarks`
## load their meshes in `_ready`, and is removed again before returning. The
## first chunk -- its heights, records, recipe, mesh and undo history -- is never
## read and never touched.
static func build(scene: Node3D, settings: Dictionary = {}) -> Node3D:
	var island := IslandBuilder.new()
	island.name = settings.get("name", "Island")
	island.settings = DEFAULTS.duplicate()
	island.settings.merge(settings, true)
	island.seed = int(island.settings.seed)
	scene.add_child(island)
	await island._form(scene)
	scene.remove_child(island)
	return island

## World-space Y of this island's ground under a world-space XZ point, or null
## when the point is not over the island. Matches `NativeTerrainData.ground_height`
## exactly -- barycentric over the same triangulation -- so a bridge anchor
## search reads the same surface the mesh draws.
func ground_height_at(world_xz: Vector2) -> Variant:
	if data == null:
		return null
	var pose := global_transform if is_inside_tree() else transform
	var local := pose.affine_inverse() * Vector3(world_xz.x, 0.0, world_xz.y)
	var height: Variant = data.ground_height(Vector2(local.x, local.z))
	if height == null:
		return null
	return (pose * Vector3(local.x, float(height), local.z)).y

## True where a pond or a stream floods this island's ground, in island-local XZ.
## The same predicate the planting rules and the bridge anchor search use.
func flooded_at(local_xz: Vector2) -> bool:
	if data == null:
		return false
	for pond: Dictionary in data.ponds:
		if GardenWater.covers(data.pond_surface(pond), local_xz):
			return true
	return false

## A one-line description of the landscape this island actually grew, for stills
## captions, test output and window titles.
func describe() -> String:
	if settings.composition != "":
		return "%s · %s/%s, seed %d" % [settings.composition, settings.archetype, settings.habitat, seed]
	var preset: Dictionary = Presets.PRESETS.get(settings.preset, {})
	var biome: String = settings.biome if settings.biome != "" else preset.get("biome", "")
	return "%s · %s, variation %d" % [preset.get("title", settings.preset), biome, seed % VARIATIONS]

# ----------------------------------------------------------------- the build

func _form(scene: Node3D) -> void:
	var began := Time.get_ticks_usec()
	var frame_tree: SceneTree = scene.get_tree() if bool(settings.live) and scene.is_inside_tree() else null
	var style := _style()
	var stage := Time.get_ticks_usec()
	data = NativeTerrainData.new()
	data.setup(style.source_mesh)
	build_stage_usec["setup"] = Time.get_ticks_usec() - stage

	stage = Time.get_ticks_usec()
	await _grow(frame_tree)
	build_stage_usec["landscape"] = Time.get_ticks_usec() - stage

	stage = Time.get_ticks_usec()
	terrain = MeshInstance3D.new()
	# Named as in `Reference`, so anything that walks a chunk by node name -- the
	# study's framing search, `SceneLook.source_roles` -- recognises it.
	terrain.name = "terrain"
	add_child(terrain)
	var built: ArrayMesh = await data.build_mesh_budgeted(false, frame_tree)
	# `build_mesh` carries `source_mesh`'s own surface material across, so the
	# island's ground is drawn by the first chunk's ShaderMaterial, not a copy.
	terrain.mesh = data.play_mesh(built)
	build_stage_usec["mesh"] = Time.get_ticks_usec() - stage

	stage = Time.get_ticks_usec()
	_raise_skirt(style)
	build_stage_usec["skirt"] = Time.get_ticks_usec() - stage

	stage = Time.get_ticks_usec()
	content = GardenView.new()
	content.name = "Content"
	content.data = data
	# `GardenView._process` animates waterfall foam and mist off `get_parent()`,
	# which it assumes is the fidelity scene. Under an island it is the island.
	content.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(content)
	await content.rebuild(true, frame_tree)
	build_stage_usec["content"] = Time.get_ticks_usec() - stage

	stage = Time.get_ticks_usec()
	landmarks = NativeGardenLandmarks.new()
	landmarks.name = "Landmarks"
	add_child(landmarks)
	landmarks.rebuild(data)
	falls = NativeGardenFalls.new()
	falls.name = "Falls"
	# Same reason as GardenView: `_process` reads the scene off `get_parent()`.
	falls.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(falls)
	falls.rebuild(data)
	build_stage_usec["props"] = Time.get_ticks_usec() - stage

	build_usec = Time.get_ticks_usec() - began

## Heights, water, cover and every plant and prop record, from whichever of the
## two whole-world generators the settings chose. Both write only into `data`.
func _grow(frame_tree: SceneTree) -> void:
	if settings.composition != "":
		var genome := {
			"kind": "inland", "version": 3,
			"composition": settings.composition,
			"archetype": settings.archetype,
			"landform": settings.landform,
			"biome": settings.habitat,
			"seed": posmod(seed, 1000000),
			"relief": clampf(float(settings.relief), 0.5, 1.8),
			"breadth": clampf(float(settings.breadth), 0.6, 1.5),
		}
		if not NativeTerrainRecipe.valid(genome):
			push_error("island builder: invalid inland genome %s" % genome)
			return
		await Inland.new().form(data, genome, frame_tree)
		return
	if not Presets.PRESETS.has(settings.preset):
		push_error("island builder: unknown preset '%s'" % settings.preset)
		return
	await Presets.form(data, settings.preset, settings.biome, frame_tree,
		posmod(seed, VARIATIONS), settings.water)

## The faceted earth sides, deformed to meet this island's rim exactly as
## `NativeChunkEditor._rebuild_skirt` deforms the first chunk's: the base of the
## captured sides stays put and their top rides the sculpt, so the two islands'
## sides are the same strata at the same height.
func _raise_skirt(style: Dictionary) -> void:
	var source: ArrayMesh = style.skirt_mesh
	skirt = MeshInstance3D.new()
	skirt.name = "skirt"
	skirt.transform = style.skirt_pose
	add_child(skirt)
	var arrays := source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var low := source.get_aabb().position.y
	var high := source.get_aabb().end.y
	for i in range(vertices.size()):
		# The captured rim reaches 0.2 beyond the terrain's edge, so clamp into
		# the chunk before sampling, exactly as the editor does.
		var local := skirt.transform * vertices[i]
		var point := Vector2(local.x, local.z).clamp(Vector2(-HALF, -HALF), Vector2(HALF, HALF))
		vertices[i].y += data.delta_at(point) * clampf((vertices[i].y - low) / (high - low), 0.0, 1.0)
	for i in range(0, vertices.size(), 3):
		var normal := (vertices[i + 2] - vertices[i]).cross(vertices[i + 1] - vertices[i]).normalized()
		for j in range(3):
			normals[i + j] = normal
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, source.surface_get_material(0))
	skirt.mesh = mesh

## The pristine chunk: its source ArrayMesh and its earth sides, straight out of
## the reference scene. Cached, because every island wants the identical
## resources and a PackedScene shares its sub-resources between instantiations --
## which is exactly why these match the first chunk rather than resembling it.
static var _style_cache := {}
static func _style() -> Dictionary:
	if not _style_cache.is_empty():
		return _style_cache
	var source: Node3D = preload("res://assets/zen_reference/geometry.scn").instantiate()
	var ground: MeshInstance3D = source.get_node("terrain")
	var sides: MeshInstance3D = source.get_node("skirt")
	_style_cache = {
		"source_mesh": ground.mesh,
		"skirt_mesh": sides.mesh,
		"skirt_pose": sides.transform,
	}
	source.free()
	return _style_cache
