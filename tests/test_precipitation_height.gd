extends SceneTree

const Precipitation = preload("res://studies/precipitation.gd")
class FlatGround extends RefCounted:
	func height_at(_x: float, _z: float) -> float:
		return 3.0

var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var weather := Precipitation.new()
	var geometry := Node3D.new()
	weather.setup(geometry, FlatGround.new())
	for material: ShaderMaterial in weather._materials:
		check(float(material.get_shader_parameter("top")) >= 35.0, "Precipitation starts well above the ground")
	weather.set_ceiling(70.0)
	for particle_name in ["Rain", "Snow", "RainCrowns"]:
		var particles := weather.get_node(NodePath(particle_name)) as MultiMeshInstance3D
		check(float(particles.material_override.get_shader_parameter("top")) == 70.0, "Rain, snow and impacts share the updated cycle")
		check(particles.custom_aabb.end.y >= 71.0, "Visibility bounds contain the raised ceiling and streak tails")
	weather.free()
	geometry.free()
	print("Precipitation height checks: ", failures, " failures")
	quit(1 if failures else 0)
