extends Node3D
## Sparse visual air parcels, driven by the weather clock rather than input.
## They depict existing wind; they never inject extra forces or gust events.
const SHADER = preload("res://shaders/gust_trail.gdshader")
const CAPACITY := 12
var enabled := true
var ground_height: Callable
var parcels: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _until_birth := 0.4
var _mesh: ImmediateMesh

func setup(probe: Callable) -> void:
	ground_height = probe
	_rng.seed = 91623
	_mesh = ImmediateMesh.new()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for lane in range(2):
		for segment in range(24):
			for corner: Vector2 in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
				var u := (float(segment)+corner.x)/24.0
				_mesh.surface_set_uv(Vector2(u,corner.y))
				_mesh.surface_set_color(Color(lane*0.23,0,0,1))
				_mesh.surface_add_vertex(Vector3((u-0.5)*6.0,sin(u*TAU)*0.14+lane*0.38,sin(u*PI)*0.4+lane*0.55))
	_mesh.surface_end()

func advance(delta: float, strength: float, angle: float) -> void:
	if delta<=0.0 or not is_finite(delta) or not ground_height.is_valid(): return
	var power := clampf(strength,0.0,3.0)
	var direction := Vector3(cos(angle),0,sin(angle))
	_until_birth -= delta
	if power>0.08 and _until_birth<=0.0:
		_until_birth = lerpf(2.8,0.5,clampf(power/1.8,0.0,1.0))
		if parcels.size()<CAPACITY: _birth(power,direction)
	for i in range(parcels.size()-1,-1,-1):
		var parcel: Dictionary = parcels[i]
		parcel.age += delta
		var node: MeshInstance3D = parcel.node
		node.visible = enabled
		# The curve stays anchored; the shader draws the stroke along it.
		var phase: float = parcel.age/parcel.duration
		var fade := smoothstep(0.0,0.18,phase)*(1.0-smoothstep(0.65,1.0,phase))
		var edge := 1.0-smoothstep(11.0,14.0,maxf(absf(node.position.x),absf(node.position.z)))
		var material := node.material_override as ShaderMaterial
		material.set_shader_parameter("clock",parcel.age)
		material.set_shader_parameter("opacity",fade*edge*smoothstep(0.03,0.35,power)*lerpf(0.30,0.55,clampf(power/2.0,0.0,1.0)))
		material.set_shader_parameter("flow_speed",0.12+power*0.16)
		if phase>=1.0 or edge<=0.0:
			node.queue_free()
			parcels.remove_at(i)

func _height(point: Vector3, direction: Vector3) -> Variant:
	var highest: Variant = null
	for offset in [-2.5,0.0,2.5]:
		var sample_point: Vector3 = point+direction*offset
		var height: Variant = ground_height.call(Vector2(sample_point.x,sample_point.z))
		if height != null: highest = float(height) if highest == null else maxf(highest,height)
	return highest

func _birth(power: float, direction: Vector3) -> void:
	var location := Vector3(_rng.randf_range(-10.0,10.0),0,_rng.randf_range(-10.0,10.0))
	var height: Variant = _height(location,direction)
	if height == null: return
	var lift := _rng.randf_range(1.0,2.8)
	location.y = float(height)+lift
	var node := MeshInstance3D.new()
	node.mesh = _mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("width",lerpf(0.06,0.11,clampf(power/2.0,0.0,1.0)))
	material.set_shader_parameter("opacity",0.0)
	material.set_shader_parameter("tint",Color(0.81,0.91,0.89))
	node.material_override = material
	add_child(node)
	node.position = location
	node.basis = Basis(direction,Vector3.UP,direction.cross(Vector3.UP))
	parcels.append({"node":node,"age":0.0,"duration":_rng.randf_range(5.0,7.0)})
