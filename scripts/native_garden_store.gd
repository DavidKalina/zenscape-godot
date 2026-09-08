class_name NativeGardenStore
extends RefCounted
## Explicit scalar/vector state only. Never deserialize objects or scripts.
const FIELDS := {
	"scene":["target","distance","yaw","polar","_motion_time","_paused","_auto_orbit"],
	"_celestial":["phase","cycling","night_fill","aurora_strength","rainbow_strength","_rainbow_growth","_target"],
	"_atmosphere":["strength","direction_angle","_air_strength","_air_angle","_travel","_cloud_drift","_gust_distance","_wind_time","fog_amount","_fog_target","haze_amount","_haze_target","shroud","loosen","summit_mist","ray_strength"],
	"_precipitation":["preset_index","state","target","cloud_override","cold_override"],
	"surface_weather":["autumn","target_autumn","cold","target_cold","ice","snow_cover","ground_wet","air_wet","foliage_wet","flow_time","snow_phase"],
	"_growth":["terrain","foliage","water"],
	"_ambient_audio":["volume","muted"],
	"_thunder_audio":["volume","muted"]
}

static func capture(scene: Node3D) -> Dictionary:
	var result := {"quality":scene._quality.selected,"look":scene._celestial.look.document()}
	for group: String in FIELDS:
		var object: Object = _object(scene,group)
		var values := {}
		for field: String in FIELDS[group]:
			values[field] = _encode(object.get(field))
		result[group] = values
	if scene.has_method("capture_life_state"): result["bigfoot_habits"] = scene.capture_life_state()
	if scene.has_method("capture_diorama_state"): result["diorama"] = scene.capture_diorama_state()
	return result

static func valid(scene: Node3D, state: Variant) -> bool:
	if not state is Dictionary or not GardenData._integer(state.get("quality")) or int(state.quality) not in [0,1]:
		return false
	for group: String in FIELDS:
		if not state.get(group) is Dictionary:
			return false
		var object := _object(scene,group)
		for field: String in FIELDS[group]:
			var value: Variant = state[group].get(field)
			var sample: Variant = _encode(object.get(field))
			if sample is bool:
				if not value is bool: return false
			elif sample is String:
				if not value is String or value.length() != 16: return false
				for character in value:
					if character not in "0123456789abcdef": return false
				if not GardenData._number(_float(value),-1e9,1e9): return false
			elif sample is Array:
				if not value is Array or value.size() != sample.size(): return false
				for number: Variant in value:
					if not GardenData._number(number,-1e9,1e9): return false
			elif not GardenData._number(value,-1e9,1e9):
				return false
	if not GardenData._number(_float(state.scene.distance),0.5,10000) or not GardenData._number(_float(state.scene.polar),0.05,PI-0.05):
		return false
	if not GardenData._integer(state._precipitation.preset_index) or state._precipitation.preset_index > 7:
		return false
	for value: Variant in state._growth.values():
		if not GardenData._number(_float(value),0,1): return false
	if state.has("look") and not preload("res://scripts/scene_look.gd").valid(state.look): return false
	if state.has("bigfoot_habits") and not preload("res://scripts/bigfoot_habits.gd").valid(state.bigfoot_habits): return false
	if state.has("diorama"):
		var extra: Variant = state.diorama
		if not extra is Dictionary or not extra.get("resident") is bool: return false
		if not extra.get("position") is Array or extra.position.size() != 3: return false
		for number in extra.position:
			if not GardenData._number(number,-1000,1000): return false
	return true

static func restore(scene: Node3D, state: Dictionary) -> void:
	scene._celestial.look.restore(state.get("look",preload("res://scripts/scene_look.gd").new().document()))
	for group: String in FIELDS:
		var object := _object(scene,group)
		for field: String in FIELDS[group]:
			var value: Variant = state[group][field]
			match typeof(object.get(field)):
				TYPE_VECTOR2: value = Vector2(value[0],value[1])
				TYPE_VECTOR3: value = Vector3(value[0],value[1],value[2])
				TYPE_VECTOR4: value = Vector4(value[0],value[1],value[2],value[3])
				TYPE_INT: value = int(value)
				TYPE_FLOAT: value = _float(value)
			object.set(field,value)
	scene._atmosphere.set_rays(scene._atmosphere.ray_strength)
	scene._growth.replaying = false
	scene._growth.publish()
	scene._set_quality(int(state.quality))
	scene._quality.select(int(state.quality))
	scene._celestial.update_rig()
	RenderingServer.global_shader_parameter_set("zs_motion_time",scene._motion_time)
	if scene.has_method("restore_life_state"): scene.restore_life_state(state.get("bigfoot_habits",{}))
	if scene.has_method("restore_diorama_state"): scene.restore_diorama_state(state.get("diorama",{}))
	scene._process(0.0)
	scene._sync_saved_controls()
	if scene._landscape_editor != null: scene._landscape_editor.hide()
	if scene._look_editor != null:
		scene._look_editor.reset_history()
		scene._look_editor.hide()

static func _object(scene: Node3D, group: String) -> Object:
	return scene if group == "scene" else scene._precipitation.surface_weather if group == "surface_weather" else scene.get(group)

static func _encode(value: Variant) -> Variant:
	match typeof(value):
		TYPE_FLOAT: return PackedFloat64Array([value]).to_byte_array().hex_encode()
		TYPE_VECTOR2: return [value.x,value.y]
		TYPE_VECTOR3: return [value.x,value.y,value.z]
		TYPE_VECTOR4: return [value.x,value.y,value.z,value.w]
	return value

static func _float(value: String) -> float:
	# JSON's decimal parser can round the last bit of a double. Keep exact IEEE
	# bytes for scalar simulation state; vectors already use 32-bit components.
	return value.hex_decode().to_float64_array()[0]
