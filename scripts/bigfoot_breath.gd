extends Node3D
## Small, deterministic mist puffs; driven by the actor clock, never wall time.
## Only the mouth at emission follows the rig. Exhaled air stays in world space.
const LIFETIME := 1.65
const INTERVAL := 0.13
const CAPACITY := 14
var puffs: Array[Dictionary] = []
var emitted := 0
var _cursor := 0
var _until_puff := 0.0
func _ready() -> void:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	for i in range(CAPACITY):
		var mesh := MeshInstance3D.new()
		mesh.mesh = quad
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.extra_cull_margin = 1.0
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/bigfoot_breath.gdshader")
		material.set_shader_parameter("seed",float(i)*1.71)
		mesh.material_override = material
		add_child(mesh)
		mesh.top_level = true
		mesh.hide()
		puffs.append({"mesh":mesh,"material":material,"age":LIFETIME,"origin":Vector3.ZERO,"velocity":Vector3.ZERO})
func clear() -> void:
	_until_puff = 0.0
	for puff in puffs:
		puff.age = LIFETIME
		puff.mesh.hide()
func advance(delta: float, mouth: Transform3D, phase: float, idle: bool, wind := Vector3.ZERO) -> void:
	if delta<=0.0: return
	for puff in puffs:
		puff.age += delta
		puff.mesh.visible = puff.age<LIFETIME
		if not puff.mesh.visible: continue
		puff.mesh.global_position = puff.origin+puff.velocity*puff.age+Vector3.UP*0.025*puff.age*puff.age
		puff.material.set_shader_parameter("age",puff.age)
		puff.material.set_shader_parameter("diameter",0.09+0.25*puff.age)
	# Peak inhalation is 40% into the 5.2-second authored Idle clip.
	if not idle or phase<0.4 or phase>=0.66:
		_until_puff = 0.0
		return
	_until_puff -= delta
	if _until_puff>0.0: return
	_until_puff += INTERVAL
	var puff: Dictionary = puffs[_cursor]
	_cursor = (_cursor+1)%CAPACITY
	var forward := mouth.basis.z.normalized()
	puff.age = 0.0
	puff.origin = mouth.origin+forward*0.035
	puff.velocity = forward*0.26+Vector3.UP*0.045+wind.limit_length(4.0)*0.015
	puff.mesh.global_position = puff.origin
	puff.material.set_shader_parameter("age",0.0)
	puff.material.set_shader_parameter("diameter",0.09)
	puff.mesh.show()
	emitted += 1
