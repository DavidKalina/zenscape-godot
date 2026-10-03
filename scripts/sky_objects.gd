extends Node3D
## The sky's real objects: the stars as points and a ringed planet, drawn as
## geometry after the dome (shaders/reference_sky.gdshader) instead of
## painted into it. Each shader places them out at the sky's distance round
## whichever camera draws them, turned with the room, so they need nothing
## from here per frame but the look pass's ridges. --shader-stars leaves the
## dome's painted stars and builds none of this.

## Room direction of the planet: up and left in the opening view, just under
## the horizon ridges, in front of the Milky Way.
const PLANET_DIRECTION := Vector3(-0.73, -0.21, 0.65)
## Angular radius, radians: about twice the moon's.
const PLANET_RADIUS := 0.05
## The pole the rings circle, in the room.
const PLANET_POLE := Vector3(0.3, 1.0, -0.25)
## The Milky Way's plane, as the dome paints it.
const GALAXY_NORMAL := Vector3(0.6, 0.25, 0.75)
## The brilliant stars the dome used to place: direction, temperature
## (star_tint in shaders/sky_stars.gdshader), HDR power, twinkle seed.
const HEROES := [
	[Vector3(-0.32, 0.55, 0.77), 0.2, 2.6, 0.13],
	[Vector3(0.61, 0.35, 0.71), 0.66, 2.0, 0.41],
	[Vector3(0.12, 0.82, -0.56), 0.35, 2.3, 0.77],
	[Vector3(-0.83, 0.12, -0.54), 0.9, 1.6, 0.29],
	[Vector3(0.9, -0.1, 0.42), 0.08, 1.8, 0.93],
	[Vector3(-0.4, -0.15, -0.9), 0.6, 1.5, 0.57],
]
## Field stars by tier, as the dome's three lattices had them: count, gain,
## brightness spread (a power law: many faint, a few brilliant), and how much
## of the tier crowds into the Milky Way's band.
const TIERS := [
	[1400, 1.3, 5.0, 0.0],
	[4200, 0.55, 4.0, 0.35],
	[9000, 0.22, 3.0, 0.6],
]

var sky_material: ShaderMaterial
var stars: MultiMeshInstance3D
var planet: Node3D
var _materials: Array[ShaderMaterial] = []
var _ridges := Vector3(-1, -1, -1)

func setup(sky: ShaderMaterial) -> void:
	sky_material = sky
	sky.set_shader_parameter("real_stars", true)
	stars = _build_stars()
	add_child(stars)
	planet = _build_planet()
	add_child(planet)
	_sync_ridges()

func _process(_delta: float) -> void:
	_sync_ridges()

## The ridges hide what lies behind them, and the look pass changes them on
## the sky material.
func _sync_ridges() -> void:
	var state := Vector3(_sky_parameter("horizon_ridges", 0.0), _sky_parameter("horizon_seed", 0.0),
		_sky_parameter("horizon_relief", 1.0))
	if state == _ridges: return
	_ridges = state
	for material in _materials:
		material.set_shader_parameter("horizon_ridges", state.x)
		material.set_shader_parameter("horizon_seed", state.y)
		material.set_shader_parameter("horizon_relief", state.z)

## A sky parameter, or the shader's default until something sets it.
func _sky_parameter(key: StringName, fallback: float) -> float:
	var value = sky_material.get_shader_parameter(key)
	return fallback if value == null else float(value)

func _material(shader: Shader, priority: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = shader
	# Ahead of everything else in the transparent pass: the sky is behind it all.
	material.render_priority = priority
	_materials.append(material)
	return material

func _sky_instance(node: GeometryInstance3D) -> void:
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.ignore_occlusion_culling = true
	# The shaders move the geometry round the camera; never cull it.
	node.custom_aabb = AABB(Vector3.ONE * -100000.0, Vector3.ONE * 200000.0)

## One quad per star. The origin carries the room direction, the custom data
## temperature, brightness, twinkle seed and whether it is a hero.
func _build_stars() -> MultiMeshInstance3D:
	var entries := star_entries()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	multimesh.mesh = quad
	multimesh.instance_count = entries.size()
	for i in entries.size():
		multimesh.set_instance_transform(i, Transform3D(Basis(), entries[i][0]))
		multimesh.set_instance_custom_data(i, entries[i][1])
	var node := MultiMeshInstance3D.new()
	node.name = "Stars"
	node.multimesh = multimesh
	node.material_override = _material(preload("res://shaders/sky_stars.gdshader"), -4)
	_sky_instance(node)
	return node

## Every star as [room direction, custom data], the same each run.
func star_entries() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x5747
	var entries: Array = []
	var galaxy := GALAXY_NORMAL.normalized()
	for tier: Array in TIERS:
		for i in int(tier[0]):
			var dir := _star_direction(rng, galaxy, rng.randf() < float(tier[3]))
			var brightness := float(tier[1]) * (0.1 + 2.0 * pow(rng.randf(), float(tier[2])))
			entries.append([dir, Color(rng.randf(), brightness, rng.randf(), 0.0)])
	for hero: Array in HEROES:
		entries.append([(hero[0] as Vector3).normalized(), Color(float(hero[1]), float(hero[2]), float(hero[3]), 1.0)])
	return entries

## A direction over the visible sky (the void under the slab thins them out
## anyway); in the band, near the Milky Way's plane.
func _star_direction(rng: RandomNumberGenerator, galaxy: Vector3, in_band: bool) -> Vector3:
	while true:
		var dir := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		if dir.y < -0.6: continue
		if in_band:
			var off := dir.dot(galaxy)
			if rng.randf() > exp(-off * off / 0.02): continue
		return dir
	return Vector3.UP

func _build_planet() -> Node3D:
	var root := Node3D.new()
	root.name = "Planet"
	var pole := PLANET_POLE.normalized()
	var side := pole.cross(PLANET_DIRECTION.normalized()).normalized()
	var frame := Basis(side, pole, side.cross(pole))
	var body := MeshInstance3D.new()
	body.name = "Body"
	var sphere := SphereMesh.new()
	# Few enough facets to read as a cut solid at its size on screen.
	sphere.radial_segments = 20
	sphere.rings = 10
	body.mesh = sphere
	body.material_override = _planet_material(preload("res://shaders/sky_planet_body.gdshader"), -3, frame)
	var glow := MeshInstance3D.new()
	glow.name = "Glow"
	var card := QuadMesh.new()
	card.size = Vector2(2.0, 2.0)
	glow.mesh = card
	glow.material_override = _planet_material(preload("res://shaders/sky_planet_glow.gdshader"), -2, frame)
	var rings := MeshInstance3D.new()
	rings.name = "Rings"
	rings.mesh = _ring_mesh(1.38, 2.3, 96)
	rings.material_override = _planet_material(preload("res://shaders/sky_planet_rings.gdshader"), -1, frame)
	for node: MeshInstance3D in [body, glow, rings]:
		_sky_instance(node)
		root.add_child(node)
	return root

func _planet_material(shader: Shader, priority: int, frame: Basis) -> ShaderMaterial:
	var material := _material(shader, priority)
	material.set_shader_parameter("planet_direction", PLANET_DIRECTION.normalized())
	material.set_shader_parameter("planet_radius", PLANET_RADIUS)
	material.set_shader_parameter("planet_frame", frame)
	return material

## A flat annulus in the xz plane, radii in planet radii.
func _ring_mesh(inner: float, outer: float, segments: int) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in segments + 1:
		var angle := TAU * float(i) / float(segments)
		var around := Vector3(cos(angle), 0.0, sin(angle))
		vertices.append(around * inner)
		vertices.append(around * outer)
		if i < segments:
			var a := i * 2
			indices.append_array([a, a + 1, a + 2, a + 1, a + 3, a + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
