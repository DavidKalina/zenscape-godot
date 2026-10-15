extends "res://scripts/pilot_figure.gd"
## The Second Walker's body (scripts/enemies/second_walker.gd): the
## wanderer's own rig and clips (scripts/pilot_figure.gd), fired in clay.
## A hollow white-slipped figure in the Olmec "baby" way (the Las Bocas
## ceramics): a chalky slip rubbed through to the pinkish clay, a heavier
## head (HEAD) and puffier limbs (PUFF, the body widened about its middle).
## No eyes, no glow: the face is a smoother, darker slip.
##
## It is driven like the wanderer's figure, from a stand-in motor the
## footprint trail sets each frame (scripts/enemies/foot_trail.gd `pose`),
## so it plays his run, jumps, wall kicks, hangs and climbs as he did.
const SLIP := Color("d8cdb9")
const CLAY := Color("a86f55")
const FACE := Color("cfc3ad")
## The head drawn this much bigger, the body this much wider (x, z).
const HEAD := 1.28
const PUFF := 1.12

static var _clay: StandardMaterial3D

## The clay over every surface, on the model's own copy of its meshes: the
## wanderer's own paint (shaders/pilot_paint.gdshader) in slip and clay,
## its weathering laid in the body's rest pose so it rides on him.
func _dress() -> void:
	var clay := paint(false)
	var face := paint(true)
	# Bareheaded: his hat isn't fired with it (the shader's `gone`), so the
	# heavy bald head is its silhouette, not his.
	var hat := paint(false)
	hat.set_shader_parameter("gone",1.0)
	for node: MeshInstance3D in _model.find_children("*","MeshInstance3D",true,false):
		var mesh := node.mesh.duplicate() as ArrayMesh
		for i in range(mesh.get_surface_count()):
			var material := mesh.surface_get_material(i)
			var key := material.resource_name if material != null else ""
			mesh.surface_set_material(i,face if key == "pilot_face" else (hat if key in PilotPaint.HAT else clay))
		node.mesh = mesh
	_model.scale = Vector3(PUFF,1.0,PUFF)

## The slip: chalky, mottled, the clay showing where it rubbed through
## (`wear`) and rising from the feet (`dust` in the clay's colour), grime in
## the hollows. No eyes, no glow.
static func paint(face: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PilotPaint.PAINT
	m.resource_name = "walker_face" if face else "walker_clay"
	var tweaks := {"albedo":FACE if face else SLIP,"mottle":0.18,"streaks":0.1,"paint_scale":16.0,"rim":0.1,
		"felt":0.5,"dust":0.0 if face else 0.85,"dust_top":0.55,"dust_colour":CLAY,"grime":0.7,"wear":0.9,
		"fade":0.3,"bump":0.6,"eyes":0.0,"glow":0.0}
	for k: String in tweaks: m.set_shader_parameter(k,tweaks[k])
	return m

## The sherds' clay (plain boxes: no rest pose to lay the paint in).
static func clay_material() -> StandardMaterial3D:
	if _clay != null: return _clay
	var m := StandardMaterial3D.new()
	m.resource_name = "walker_sherd"
	m.albedo_color = SLIP.lerp(CLAY,0.3)
	m.roughness = 0.9
	_clay = m
	return m

## As the wanderer's, then the heavy head.
func drive(motor: RefCounted, delta: float) -> Dictionary:
	var out := super.drive(motor,delta)
	if _head >= 0: _skeleton.set_bone_pose_scale(_head,Vector3.ONE*HEAD)
	return out
