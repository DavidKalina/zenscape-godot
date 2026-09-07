class_name GardenWeather
extends MultiMeshInstance3D
## Light precipitation whose endpoints track the edited ground.
var data: GardenData
var _clock := 0.0
var _seeds: Array[Vector3] = []
var _material := StandardMaterial3D.new()

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 62517
	for i in range(450):
		_seeds.append(Vector3(rng.randf_range(-12, 12), rng.randf(), rng.randf_range(-12, 12)))
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var drop := SphereMesh.new()
	drop.radius = 0.035
	drop.height = 0.07
	drop.radial_segments = 4
	drop.rings = 2
	multimesh.mesh = drop
	multimesh.instance_count = _seeds.size()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _process(delta: float) -> void:
	visible = data.weather in ["Rain", "Snow"]
	if not visible:
		return
	_clock += delta
	var snow := data.weather == "Snow"
	_material.albedo_color = Color("ecf6f7") if snow else Color("a6c5cf")
	for i in range(_seeds.size()):
		var seed_point := _seeds[i]
		var p := Vector2(seed_point.x, seed_point.z)
		var floor_height := data.height_at(p)
		var phase := fposmod(seed_point.y - _clock * (0.13 if snow else 1.3), 1.0)
		var position := Vector3(p.x, floor_height + phase * 9.0 + 0.04, p.y)
		if snow:
			position.x += sin(_clock + i) * 0.10
		var size := Vector3.ONE if snow else Vector3(0.3, 6.0, 0.3)
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(size), position))
