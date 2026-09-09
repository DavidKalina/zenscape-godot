extends Node3D
## Rain accumulates on the coat; runoff leaves the animated rig in world space.
const SOAK_SECONDS := 12.0
const DRY_SECONDS := 90.0
const CAPACITY := 48
var wetness := 0.0
var rain := 0.0
var emitted := 0
var coats: Array[Dictionary] = []
var drops: Array[Dictionary] = []
var _actor: Node3D
var _rig: Skeleton3D
var _sources: Array[int] = []
var _credit := 0.0
var _cursor := 0
var _bound := false

func setup(owner_actor: Node3D, rig: Skeleton3D) -> void:
	_actor = owner_actor
	_rig = rig
	for bone in ["Head", "Hand_L", "Hand_R", "Forearm_L", "Forearm_R", "Spine"]:
		var index := rig.find_bone(bone)
		if index >= 0: _sources.append(index)
	var shape := SphereMesh.new()
	shape.radius = 0.012
	shape.height = 0.065
	shape.radial_segments = 6
	shape.rings = 2
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("a9cad2")
	material.metallic = 0.15
	material.roughness = 0.18
	for i in range(CAPACITY):
		var mesh := MeshInstance3D.new()
		mesh.mesh = shape
		mesh.material_override = material
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mesh)
		mesh.top_level = true
		mesh.hide()
		drops.append({"mesh":mesh,"age":1.0,"origin":Vector3.ZERO,"floor":0.0})

func _bind_coats() -> void:
	# Bind after the scene installs its lighting materials. Never mutate imports
	# or a material shared with another resident / the landscape.
	var copies := {}
	for mesh: MeshInstance3D in _actor.find_children("*", "MeshInstance3D", true, false):
		if "_n7_" in mesh.name or "_n8_" in mesh.name: continue
		var override := mesh.material_override
		for surface in range(1 if override != null else mesh.mesh.get_surface_count()):
			var original := mesh.get_active_material(surface)
			if original == null: continue
			if original is StandardMaterial3D and "coat" not in original.resource_name.to_lower(): continue
			if not copies.has(original):
				var copy := original.duplicate() as Material
				copies[original] = copy
				coats.append({"material":copy,"color":copy.albedo_color if copy is StandardMaterial3D else Color.WHITE,"roughness":copy.roughness if copy is StandardMaterial3D else 1.0})
			if mesh.material_override != null: mesh.material_override = copies[original]
			else: mesh.set_surface_override_material(surface,copies[original])
	_bound = true

func clear_drops() -> void:
	_credit = 0.0
	for drop in drops:
		drop.age = 1.0
		drop.mesh.hide()

func advance(delta: float) -> void:
	if delta <= 0.0: return
	if not _bound: _bind_coats()
	var intensity := clampf(rain,0.0,1.0)
	wetness = clampf(wetness+delta*(intensity/SOAK_SECONDS-(1.0-intensity)/DRY_SECONDS),0.0,1.0)
	for coat in coats:
		var material: Material = coat.material
		if material is ShaderMaterial:
			material.set_shader_parameter("coat_wetness",wetness)
		else:
			material.albedo_color = coat.color*Color(1.0-wetness*0.44,1.0-wetness*0.44,1.0-wetness*0.44,1.0)
			material.roughness = lerpf(coat.roughness,0.48,wetness)
	for drop in drops:
		drop.age += delta
		if drop.age >= 0.85: drop.mesh.hide(); continue
		var age: float = drop.age
		drop.mesh.global_position = drop.origin+Vector3.DOWN*(0.35*age+4.9*age*age)
		drop.mesh.visible = drop.mesh.global_position.y>drop.floor
	if wetness <= 0.3 or _sources.is_empty():
		_credit = 0.0
		return
	_credit += delta*24.0*pow((wetness-0.3)/0.7,2.0)
	while _credit >= 1.0:
		_credit -= 1.0
		var drop: Dictionary = drops[_cursor]
		var bone := _sources[emitted%_sources.size()]
		var pose := _rig.global_transform*_rig.get_bone_global_pose(bone)
		var angle := float(emitted)*2.39996
		drop.origin = pose*Vector3(cos(angle)*0.13,-0.07,0.15+sin(angle)*0.08)
		drop.floor = _actor.global_position.y+0.015
		drop.age = 0.0
		drop.mesh.global_position = drop.origin
		drop.mesh.show()
		_cursor = (_cursor+1)%CAPACITY
		emitted += 1
