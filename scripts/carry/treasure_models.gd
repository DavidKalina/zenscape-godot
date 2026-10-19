extends RefCounted
## The treasures' models (docs/design/carry/spec-carry.md), built from
## primitives merged into one mesh a material: small, with clear
## silhouettes. `build(kind)` gives the figure (a Node3D, its foot at its
## origin, facing -z) and its measures:
##   {"node", "height" (m), "grip" (the hands' half span across it, m),
##    "radius" (a ball round it for its rest and its tumble)}
## Kinds: "idol" (a squat jade figure with a gold crown, light), "urn" (a
## two-handled painted amphora, medium), "egg" (a dragon's egg, ridged
## plates and an ember glow in its cracks, heavy), "chalice" (a gold cup
## set with gems, light).

const KINDS := ["idol","urn","egg","chalice"]

static func build(kind: String) -> Dictionary:
	match kind:
		"urn": return _urn()
		"egg": return _egg()
		"chalice": return _chalice()
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

# --- The urn ------------------------------------------------------------------------

## A painted amphora: a round belly on a short foot, a narrow neck under a
## flared lip, two loop handles from shoulder to neck, a black band with a
## gold zigzag round the belly. 0.5 m tall.
static func _urn() -> Dictionary:
	var clay := _Parts.new()
	var band := _Parts.new()
	var gold := _Parts.new()
	clay.cyl(0.07,0.09,0.05,Vector3(0.0,0.025,0.0),12)
	clay.cyl(0.06,0.07,0.04,Vector3(0.0,0.07,0.0),12)
	clay.ball(0.16,Vector3(0.0,0.22,0.0),Vector3(1.0,1.1,1.0),14)
	clay.cyl(0.065,0.11,0.07,Vector3(0.0,0.37,0.0),12)
	clay.cyl(0.055,0.06,0.07,Vector3(0.0,0.43,0.0),12)
	clay.cyl(0.09,0.06,0.04,Vector3(0.0,0.48,0.0),12)
	for sx: float in [-1.0,1.0]:
		clay.ring(0.065,0.018,Vector3(sx*0.105,0.38,0.0),Vector3(PI*0.5,0.0,0.0))
	band.cyl(0.164,0.164,0.06,Vector3(0.0,0.22,0.0),14)
	for i: int in 10:
		var a := TAU*float(i)/10.0
		gold.box(Vector3(0.05,0.012,0.012),Vector3(sin(a)*0.168,0.22,cos(a)*0.168),Vector3(0.0,a,PI*0.25*(1.0 if i % 2 == 0 else -1.0)))
	var mesh := ArrayMesh.new()
	clay.commit(mesh,_mat(Color(0.74,0.38,0.2),0.8,0.0))
	band.commit(mesh,_mat(Color(0.08,0.06,0.05),0.6,0.0))
	gold.commit(mesh,_mat(Color(0.95,0.72,0.28),0.3,0.9))
	return _made(mesh,0.5,0.17,0.18)

# --- The dragon egg ------------------------------------------------------------------

## A dragon's egg: a tall ovoid in deep teal, overlapping bronze plates in
## rings up it, ember-orange light in the seams between the lower rings,
## sat in a ring of three claw-like shell shards. 0.6 m tall.
static func _egg() -> Dictionary:
	var shell := _Parts.new()
	var plate := _Parts.new()
	var ember := _Parts.new()
	shell.ball(0.23,Vector3(0.0,0.3,0.0),Vector3(1.0,1.3,1.0),16)
	ember.ball(0.215,Vector3(0.0,0.27,0.0),Vector3(1.04,1.2,1.04),14)
	# Plates: five rings of flat scales laid on the shell like shingles
	# (their lower edge lifted), the upper ones smaller, each ring offset
	# half a step. [height, radius out, count, size].
	var rows := [[0.1,0.18,8,0.085],[0.2,0.222,9,0.09],[0.3,0.232,9,0.09],[0.4,0.215,8,0.08],[0.49,0.17,7,0.065]]
	for r: int in rows.size():
		var row: Array = rows[r]
		var n: int = row[2]
		var tilt := -0.35+0.18*float(r)
		for i: int in n:
			var a := TAU*(float(i)+0.5*float(r % 2))/float(n)
			var rad: float = row[1]
			var at := Vector3(sin(a)*rad,float(row[0]),cos(a)*rad)
			plate.ball(float(row[3]),at,Vector3(1.0,1.0,0.22),8,Basis(Vector3.UP,a)*Basis(Vector3.RIGHT,tilt))
	for i: int in 3:
		var a := TAU*float(i)/3.0+0.4
		plate.cyl(0.0,0.05,0.16,Vector3(sin(a)*0.2,0.06,cos(a)*0.2),5,Vector3(-cos(a)*0.5,0.0,sin(a)*0.5))
	var mesh := ArrayMesh.new()
	shell.commit(mesh,_mat(Color(0.12,0.3,0.32),0.5,0.1))
	plate.commit(mesh,_mat(Color(0.42,0.36,0.2),0.55,0.45))
	ember.commit(mesh,_mat(Color(1.0,0.45,0.12),0.6,0.0,Color(1.0,0.38,0.08)*1.4))
	return _made(mesh,0.6,0.24,0.26)

# --- The chalice ----------------------------------------------------------------------

## A gold chalice: a wide cup on a knotted stem and a round foot, a band of
## blue and red gems round the cup. 0.3 m tall.
static func _chalice() -> Dictionary:
	var gold := _Parts.new()
	var gem := _Parts.new()
	gold.cyl(0.07,0.08,0.02,Vector3(0.0,0.01,0.0),12)
	gold.cyl(0.02,0.06,0.04,Vector3(0.0,0.04,0.0),12)
	gold.cyl(0.015,0.02,0.1,Vector3(0.0,0.11,0.0),8)
	gold.ball(0.03,Vector3(0.0,0.12,0.0),Vector3(1.0,0.7,1.0),8)
	gold.cyl(0.1,0.02,0.11,Vector3(0.0,0.215,0.0),14)
	gold.cyl(0.105,0.1,0.015,Vector3(0.0,0.275,0.0),14)
	for i: int in 6:
		var a := TAU*float(i)/6.0
		gem.ball(0.014,Vector3(sin(a)*0.077,0.23,cos(a)*0.077))
	var mesh := ArrayMesh.new()
	gold.commit(mesh,_mat(Color(0.95,0.72,0.28),0.35,0.55))
	gem.commit(mesh,_mat(Color(0.2,0.35,0.95),0.1,0.0,Color(0.2,0.3,0.9)*0.4))
	return _made(mesh,0.285,0.1,0.12)

## The figure node for `mesh` and its measures.
static func _made(mesh: ArrayMesh, height: float, grip: float, radius: float) -> Dictionary:
	var node := MeshInstance3D.new()
	node.name = "Figure"
	node.mesh = mesh
	return {"node":node,"height":height,"grip":grip,"radius":radius}

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

	func ball(radius: float, at: Vector3, stretch := Vector3.ONE, sides := 10, turn := Basis.IDENTITY) -> void:
		var s := SphereMesh.new()
		s.radius = radius
		s.height = radius*2.0
		s.radial_segments = sides
		s.rings = maxi(6,sides/2)
		_add(s,Transform3D(turn*Basis.from_scale(stretch),at))

	## A torus `radius` round its middle, `thick` through, its hole along y.
	func ring(radius: float, thick: float, at: Vector3, turn := Vector3.ZERO) -> void:
		var t := TorusMesh.new()
		t.inner_radius = radius-thick
		t.outer_radius = radius+thick
		t.rings = 12
		t.ring_segments = 6
		_add(t,Transform3D(Basis.from_euler(turn),at))

	func commit(mesh: ArrayMesh, mat: Material) -> void:
		if not any: return
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count()-1,mat)
