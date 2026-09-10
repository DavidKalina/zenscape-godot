class_name FireMaterial
extends RefCounted
## Explicit fire inputs keep bird animation's INSTANCE_CUSTOM channels intact.
## Physical copies use a uniform because ordinary MeshInstances have no per-item
## MultiMesh custom data. Callers already duplicate their owned materials.
static func supported(material: Material) -> bool:
	return material is ShaderMaterial and material.shader != null and material.shader.resource_path in ["res://shaders/reference_surface.gdshader","res://shaders/layered_canopy_surface.gdshader"]

static func enable_instances(material: Material) -> void:
	if supported(material): material.set_shader_parameter("instance_fire_enabled",true)

static func apply(material: Material, value: Vector2) -> void:
	if not supported(material): return
	material.set_shader_parameter("instance_fire_enabled",false)
	material.set_shader_parameter("object_fire",value)
