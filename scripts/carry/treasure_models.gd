extends RefCounted
## The treasures' models (docs/design/carry/spec-carry.md), built from
## primitives merged into one mesh a material: small, with clear
## silhouettes. `build(kind)` gives the figure (a Node3D, its foot at its
## origin, facing -z) and its measures:
##   {"node", "height" (m), "grip" (the hands' half span across it, m),
##    "radius" (a ball round it for its rest and its tumble)}
## Kinds: "idol" (a squat jade figure with a gold crown, light).

const KINDS := ["idol"]

static func build(kind: String) -> Dictionary:
	match kind:
		_: return _idol()

# --- The idol ----------------------------------------------------------------------

## A seated jade figure on a gold plinth: a round head under a stepped gold
## crown, the arms folded over the belly, two red gem eyes. Drawn 0.46 m
## tall, stood IDOL_SIZE of that (the wanderer is about 1 m).
const IDOL_SIZE := 0.7
static func _idol() -> Dictionary:
	var jade := _Parts.new()
	var gold := _Parts.new()
	var gem := _Parts.new()
	# Plinth, two steps.
	gold.box(Vector3(0.26,0.05,0.22),Vector3(0.0,0.025,0.0))
	gold.box(Vector3(0.21,0.035,0.18),Vector3(0.0,0.0675,0.0))
	# Body: a pear, wider at the seat.
	jade.cyl(0.1,0.12,0.16,Vector3(0.0,0.165,0.0),10)
	# Folded arms, a band over the belly.
	jade.box(Vector3(0.22,0.05,0.07),Vector3(0.0,0.2,-0.07))
	# Crossed legs: two flattened capsules in front.
	jade.cyl(0.045,0.045,0.2,Vector3(0.0,0.105,-0.075),8,Vector3(0.0,0.0,PI*0.5))
	# Head.
	jade.ball(0.085,Vector3(0.0,0.31,0.0),Vector3(1.0,0.95,1.0))
	# Ears, big lobes.
	jade.ball(0.03,Vector3(-0.085,0.3,0.0),Vector3(0.6,1.3,0.8))
	jade.ball(0.03,Vector3(0.085,0.3,0.0),Vector3(0.6,1.3,0.8))
	# Crown: a band and a stepped point.
	gold.cyl(0.08,0.088,0.035,Vector3(0.0,0.37,0.0),10)
	gold.cyl(0.04,0.07,0.04,Vector3(0.0,0.405,0.0),8)
	gold.cyl(0.0,0.035,0.035,Vector3(0.0,0.4425,0.0),6)
	# Eyes.
	gem.ball(0.016,Vector3(-0.032,0.32,-0.075))
	gem.ball(0.016,Vector3(0.032,0.32,-0.075))
	var mesh := ArrayMesh.new()
	jade.commit(mesh,_mat(Color(0.32,0.62,0.46),0.45,0.0))
	gold.commit(mesh,_mat(Color(0.95,0.72,0.28),0.3,0.9))
	gem.commit(mesh,_mat(Color(0.85,0.1,0.12),0.15,0.0,Color(0.9,0.12,0.1)*0.6))
	var node := MeshInstance3D.new()
	node.name = "Figure"
	node.mesh = mesh
	node.scale = Vector3.ONE*IDOL_SIZE
	return {"node":node,"height":0.46*IDOL_SIZE,"grip":0.13*IDOL_SIZE,"radius":0.2*IDOL_SIZE}

static func _mat(albedo: Color, rough: float, metal: float, glow := Color.BLACK) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = rough
	m.metallic = metal
	if glow != Color.BLACK:
		m.emission_enabled = true
		m.emission = glow
	return m

## Primitives gathered for one surface.
class _Parts:
	var st := SurfaceTool.new()
	var any := false

	func _init() -> void:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	func _add(prim: PrimitiveMesh, at: Transform3D) -> void:
		st.append_from(prim,0,at)
		any = true

	func box(size: Vector3, at: Vector3, turn := Vector3.ZERO) -> void:
		var b := BoxMesh.new()
		b.size = size
		_add(b,Transform3D(Basis.from_euler(turn),at))

	func cyl(top: float, bottom: float, height: float, at: Vector3, sides := 10, turn := Vector3.ZERO) -> void:
		var c := CylinderMesh.new()
		c.top_radius = top
		c.bottom_radius = bottom
		c.height = height
		c.radial_segments = sides
		c.rings = 1
		_add(c,Transform3D(Basis.from_euler(turn),at))

	func ball(radius: float, at: Vector3, stretch := Vector3.ONE) -> void:
		var s := SphereMesh.new()
		s.radius = radius
		s.height = radius*2.0
		s.radial_segments = 10
		s.rings = 6
		_add(s,Transform3D(Basis.from_scale(stretch),at))

	func commit(mesh: ArrayMesh, mat: Material) -> void:
		if not any: return
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count()-1,mat)
