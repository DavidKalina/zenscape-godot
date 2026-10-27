extends "res://scripts/cloud_volume_effect.gd"
## The endless flight's clouds on the camera's compositor: the isles'
## cloud volume passes (scripts/cloud_volume_effect.gd: weather, ceiling,
## shade, march, then the temporal resolve) with the endless field's march
## (shaders/endless_cloud_march.glsl) compiled in place of the isles'. The
## bindings and parameter block are the same, so nothing else changes.

const MARCH := preload("res://shaders/cloud_volume_march.glsl")
const ENDLESS_MARCH := preload("res://shaders/endless_cloud_march.glsl")

const RESOLVE := preload("res://shaders/cloud_volume_resolve.glsl")
const ENDLESS_RESOLVE := preload("res://shaders/endless_cloud_resolve.glsl")

## The march's cost view (endless_clouds.gd --cloud-cost-view): its own
## version of the march, which counts what each pixel costs; play's
## doesn't (the counters cost ~.25 ms with the storm's towers).
var cost_view := false

func _compile(file: RDShaderFile, version: StringName = &"") -> RID:
	if file == RESOLVE: return super._compile(ENDLESS_RESOLVE, version)
	if file == MARCH: return super._compile(ENDLESS_MARCH, &"cost" if cost_view else &"play")
	return super._compile(file, version)
