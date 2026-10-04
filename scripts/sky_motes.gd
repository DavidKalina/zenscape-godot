extends MultiMeshInstance3D
## A few motes of light adrift in the open air round the floating plate, over
## the cloud sea: the faint mystical touch the backdrop carries by day and by
## night (shaders/sky_motes.gdshader moves and fades them; nothing here runs
## per frame). Few, small and slow, so the plate stays the focus. The look
## pass shows them with the cloud sea and sets their strength.

const COUNT := 18
## The open air they keep to: clear of the plate (a 28 m square) by a margin,
## out to `OUTER` metres, between `LOW` and `HIGH`.
const INNER := 18.0
const OUTER := 40.0
const LOW := -24.0
const HIGH := 8.0

var _material := ShaderMaterial.new()

func _init() -> void:
	name = "SkyMotes"
	visible = false
	_material.shader = preload("res://shaders/sky_motes.gdshader")
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ignore_occlusion_culling = true
	custom_aabb = AABB(Vector3(-OUTER - 6.0, LOW - 8.0, -OUTER - 6.0), Vector3(OUTER * 2.0 + 12.0, HIGH - LOW + 16.0, OUTER * 2.0 + 12.0))
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = quad
	mm.instance_count = COUNT
	var rng := RandomNumberGenerator.new()
	rng.seed = 0x6d07e5
	for i in COUNT:
		var angle := rng.randf() * TAU
		# Thinner with distance from the plate, so they gather close by.
		var reach := lerpf(INNER, OUTER, pow(rng.randf(), 1.6))
		var at := Vector3(cos(angle) * reach, lerpf(LOW, HIGH, rng.randf()), sin(angle) * reach)
		mm.set_instance_transform(i, Transform3D(Basis(), at))
		# Seed, size (m), brightness: most faint, a few a little brighter.
		mm.set_instance_custom_data(i, Color(rng.randf(), rng.randf_range(0.16, 0.3), lerpf(0.15, 0.7, pow(rng.randf(), 2.2)), 0.0))
	multimesh = mm

func set_strength(value: float) -> void:
	visible = value > 0.0
	_material.set_shader_parameter("strength", value)
