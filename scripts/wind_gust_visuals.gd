extends Node3D
## Bounded ribbons follow the same gust IDs, ages and envelopes as the force.
const TRAIL = preload("res://shaders/gust_trail.gdshader")
var field: LocalWindField
var enabled := true
var trails := {}
var aim := MeshInstance3D.new()
var _aim_material := StandardMaterial3D.new()

func setup(wind: LocalWindField) -> void:
	field = wind
	field.updated.connect(sync)
	add_child(aim)
	aim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_aim_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_aim_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_aim_material.albedo_color = Color(0.78,0.95,0.86,0.85)
	_aim_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	aim.material_override = _aim_material

func sync() -> void:
	var alive := {}
	if field == null: return
	for gust: Dictionary in field._gusts:
		# Steered gusts (scripts/wind_gust.gd) draw their own air.
		if gust.get("steered", false): continue
		alive[gust.id] = true
		if not trails.has(gust.id): trails[gust.id] = _make_trail(gust)
		var node: MeshInstance3D = trails[gust.id]
		node.visible = enabled
		var material := node.material_override as ShaderMaterial
		material.set_shader_parameter("clock",gust.age)
		material.set_shader_parameter("opacity",LocalWindField.envelope(gust.age,gust.duration)*0.8)
	for id in trails.keys():
		if not alive.has(id):
			trails[id].queue_free()
			trails.erase(id)

func _make_trail(gust: Dictionary) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = TRAIL
	material.set_shader_parameter("width",lerpf(0.07,0.15,clampf(gust.strength/28.0,0.0,1.0)))
	material.set_shader_parameter("flow_speed",lerpf(0.4,0.85,clampf(gust.strength/28.0,0.0,1.0)))
	node.material_override = material
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for strand in range(7):
		for segment in range(32):
			for corner in [Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,0),Vector2(1,1),Vector2(0,1)]:
				var u: float = (float(segment)+corner.x)/32.0
				var lane := float(strand)-3.0
				var x: float = (u-0.5)*gust.radius*1.5
				var y := 0.2+float(strand%3)*0.6+sin(u*TAU+strand)*0.22
				var z: float = lane*gust.radius*0.12+sin(u*PI)*sin(float(strand)*2.0)*0.35
				mesh.surface_set_uv(Vector2(u,corner.y))
				mesh.surface_set_color(Color(float(strand)*0.137,0,0,1))
				mesh.surface_add_vertex(Vector3(x,y,z))
	mesh.surface_end()
	node.mesh = mesh
	add_child(node)
	var forward: Vector3 = Vector3(gust.direction.x,0,gust.direction.z).normalized()
	if forward.length_squared()<0.01: forward = Vector3.RIGHT
	node.basis = Basis(forward,Vector3.UP,forward.cross(Vector3.UP))
	node.position = gust.origin
	return node

func clear_aim() -> void:
	aim.mesh = null

func set_aim(start: Vector3, finish: Vector3, ground_probe := Callable()) -> void:
	var direction := Vector3(finish.x-start.x,0,finish.z-start.z)
	var length := minf(direction.length(),10.0)
	if length<0.05:
		clear_aim()
		return
	direction = direction.normalized()
	var side := direction.cross(Vector3.UP)
	var origin := start+Vector3.UP*0.15
	var end := origin+direction*length
	var head := minf(0.65,length*0.4)
	var neck := end-direction*head
	var half_width := 0.045
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for point: Vector3 in [origin-side*half_width,neck-side*half_width,neck+side*half_width,origin-side*half_width,neck+side*half_width,origin+side*half_width,neck-side*head*0.55,end,neck+side*head*0.55]:
		if ground_probe.is_valid():
			var ground: Variant = ground_probe.call(point)
			if ground != null: point.y = ground.y+0.15
		mesh.surface_add_vertex(point)
	mesh.surface_end()
	aim.mesh = mesh
