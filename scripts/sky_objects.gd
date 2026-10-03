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
## The few brilliant stars, placed: direction, temperature (star_tint in
## shaders/sky_stars.gdshader), HDR power, twinkle seed.
const HEROES := [
	[Vector3(-0.32, 0.55, 0.77), 0.2, 1.4, 0.13],
	[Vector3(0.61, 0.35, 0.71), 0.66, 1.1, 0.41],
	[Vector3(0.12, 0.82, -0.56), 0.35, 1.2, 0.77],
	[Vector3(-0.83, 0.12, -0.54), 0.9, 0.9, 0.29],
	[Vector3(0.9, -0.1, 0.42), 0.08, 1.0, 0.93],
	[Vector3(-0.4, -0.15, -0.9), 0.6, 0.8, 0.57],
]
## The mystical part, kept rare: a few stars that slowly breathe a cool colour,
## teal or violet, far slower than any twinkle. Direction, hue (0 teal, 1
## violet), brightness, seed.
const BREATHERS := [
	[Vector3(-0.55, -0.32, 0.77), 0.0, 0.9, 0.21],
	[Vector3(-0.98, -0.28, -0.05), 1.0, 0.8, 0.64],
	[Vector3(0.2, 0.3, 0.93), 0.3, 0.7, 0.86],
]
## Field stars by tier: count, brightness range (display units), and how
## much of the tier crowds into the Milky Way's band. Most are a faint dust
## that only reads as texture; the bright ones are few.
const TIERS := [
	[11000, Vector2(0.03, 0.14), 0.75],
	[2200, Vector2(0.14, 0.5), 0.4],
	[180, Vector2(0.5, 1.3), 0.15],
]
## Tight clusters, the spots the eye settles on: centre, radius (radians),
## count, temperature.
const CLUSTERS := [
	[Vector3(-0.62, -0.08, 0.78), 0.022, 34, 0.12],
	[Vector3(-0.9, -0.35, 0.25), 0.035, 40, 0.45],
	[Vector3(0.35, 0.15, 0.92), 0.018, 22, 0.2],
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

## Every star as [room direction, custom data], the same each run. Custom
## data: temperature, brightness, seed, kind (0 field, 1 hero, 2 breather).
func star_entries() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x5747
	# Broad rich fields and empty reaches: field stars are kept by a slow
	# noise over the sky, so some regions crowd and others go nearly dark.
	var fields := FastNoiseLite.new()
	fields.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fields.seed = 11
	fields.frequency = 1.0
	fields.fractal_octaves = 3
	var galaxy := GALAXY_NORMAL.normalized()
	var entries: Array = []
	for tier: Array in TIERS:
		var span: Vector2 = tier[1]
		for i in int(tier[0]):
			var dir := _star_direction(rng, fields, galaxy, rng.randf() < float(tier[2]))
			# A power law within the tier: most at its faint end.
			var brightness := lerpf(span.x, span.y, pow(rng.randf(), 2.5))
			entries.append([dir, Color(rng.randf(), brightness, rng.randf(), 0.0)])
	for cluster: Array in CLUSTERS:
		var centre := (cluster[0] as Vector3).normalized()
		var side := centre.cross(Vector3.UP).normalized()
		var up := side.cross(centre)
		for i in int(cluster[2]):
			var spread := Vector2(rng.randfn(), rng.randfn()) * float(cluster[1]) * 0.5
			var dir := (centre + side * spread.x + up * spread.y).normalized()
			var brightness := lerpf(0.06, 0.7, pow(rng.randf(), 3.0))
			entries.append([dir, Color(float(cluster[3]) + rng.randf_range(-0.08, 0.08), brightness, rng.randf(), 0.0)])
	for hero: Array in HEROES:
		entries.append([(hero[0] as Vector3).normalized(), Color(float(hero[1]), float(hero[2]), float(hero[3]), 1.0)])
	for breather: Array in BREATHERS:
		entries.append([(breather[0] as Vector3).normalized(), Color(float(breather[1]), float(breather[2]), float(breather[3]), 2.0)])
	return entries

## A direction over the visible sky (the void under the slab thins them out
## anyway), kept where the rich fields are; in the band, near the Milky Way's
## plane, where it crowds regardless.
func _star_direction(rng: RandomNumberGenerator, fields: FastNoiseLite, galaxy: Vector3, in_band: bool) -> Vector3:
	while true:
		var dir := Vector3(rng.randfn(), rng.randfn(), rng.randfn()).normalized()
		if dir.y < -0.6: continue
		var rich := smoothstep(-0.35, 0.45, fields.get_noise_3dv(dir * 2.2))
		if in_band:
			var off := dir.dot(galaxy)
			rich = maxf(rich, 0.6) * exp(-off * off / 0.04)
		if rng.randf() > 0.06 + 0.94 * rich: continue
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
	# Enough segments that its outline stays round on screen.
	sphere.radial_segments = 64
	sphere.rings = 32
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
