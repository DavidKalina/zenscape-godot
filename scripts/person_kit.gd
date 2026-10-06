extends RefCounted
## The sky folk's parts, shared by the pilot in the plane's cockpit
## (scripts/plane_pilot.gd) and the islanders standing on their land
## (scripts/islander_figure.gd), so they are one people: a leather jacket,
## the scarf wound at the neck, a faceted head in a leather cap with ear
## flaps and brass goggles on a strap, gloved hands, canvas trousers and
## boots. Faceted solids, lacquered leather and brass that catch the sun.
##
## Also how they move: springs that lag, overshoot a little and settle,
## and two-bone limbs posed from a root to a hand or foot.
##
## Sizes are the pilot's (a head about 0.14 m across); a figure is scaled
## as a whole to stand in the world.

const GliderFigure = preload("res://scripts/glider_figure.gd")
const FacetMesh = preload("res://scripts/facet_mesh.gd")
const SKIN := Color("e8c39e")
const JACKET := Color("4a2a1e")
const LEATHER := Color("5e3522")
const STRAP := Color("6b3b28")
const BRASS := Color("d6ad62")
const LENS := Color("2c4650")
const TROUSERS := Color("6b6250")
const BOOTS := Color("3a2a22")
const SCARF := Color("d9573a")
## The chest: its top (the neck) over its root, the shoulders on it, and
## the scarf's knot at the back of the neck.
const NECK := 0.15
const SHOULDER := Vector3(0.085,0.125,0.0)
const KNOT := Vector3(0.0,0.152,0.06)

## A damped spring: x chases a target at `hz`, `damping` 1 settling without
## overshoot, less bouncing past it.
class Spring:
	var x := 0.0
	var v := 0.0
	var hz := 2.0
	var damping := 0.4
	func _init(rate: float, damp: float, start := 0.0) -> void:
		hz = rate
		damping = damp
		x = start
	func step(target: float, delta: float) -> float:
		var w := TAU*hz
		var left := minf(delta,0.25)
		while left > 0.0:
			var dt := minf(left,1.0/60.0)
			v += (w*w*(target-x)-2.0*damping*w*v)*dt
			x += v*dt
			left -= dt
		return x

## The materials, keyed skin, jacket, leather, strap, brass, lens,
## trousers, boots and scarf, the scarf in `scarf`.
static func outfit(scarf := SCARF) -> Dictionary:
	return {
		"skin":_matte(SKIN,0.8),
		"jacket":_lacquer(JACKET,0.6,0.2),
		"leather":_lacquer(LEATHER,0.55,0.3),
		"strap":_lacquer(STRAP,0.4,0.5),
		"brass":_metal(BRASS,0.28),
		"lens":_metal(LENS,0.04),
		"trousers":_matte(TROUSERS,0.9),
		"boots":_lacquer(BOOTS,0.45,0.35),
		"scarf":_matte(scarf,0.95),
	}

## The chest on `parent` at its root: the jacket tapering to the
## shoulders, the scarf wound at the neck and its knot behind.
static func chest(parent: Node3D, m: Dictionary) -> void:
	part(parent,FacetMesh.hull([Vector3(0.0,0.07,0.055),Vector3(0.08,0.085,0.062),Vector3(0.125,0.092,0.058),Vector3(0.152,0.05,0.04)],8),m.jacket,Vector3.ZERO,Vector3(-PI*0.5,0.0,0.0))
	for side in [-1.0,1.0]: part(parent,GliderFigure._gem(0.036),m.jacket,Vector3(SHOULDER.x*side,SHOULDER.y+0.005,0.0),Vector3.ZERO)
	part(parent,GliderFigure._gem(0.05),m.scarf,Vector3(0.0,NECK,0.0),Vector3.ZERO,Vector3(1.3,0.55,1.2))
	part(parent,GliderFigure._gem(0.024),m.scarf,Vector3(0.0,0.152,0.05),Vector3.ZERO)

## The neck and head on `parent` (the chest), returned [neck, head], each
## a pivot to turn: the faceted head in its cap, ear flaps, strap and
## goggles, `size` against the body.
static func head(parent: Node3D, m: Dictionary, size := 0.9) -> Array:
	var neck := Node3D.new()
	neck.position = Vector3(0.0,NECK,0.0)
	parent.add_child(neck)
	part(neck,GliderFigure._frustum(0.026,0.023,0.05,6),m.skin,Vector3(0.0,0.02,0.0),Vector3.ZERO)
	var pivot := Node3D.new()
	pivot.position = Vector3(0.0,0.035,0.0)
	pivot.scale = Vector3.ONE*size
	neck.add_child(pivot)
	var mid := Vector3(0.0,0.055,0.0)
	part(pivot,FacetMesh.hull([Vector3(-0.08,0.03,0.03),Vector3(-0.05,0.064,0.064),Vector3(0.0,0.075,0.075),Vector3(0.045,0.066,0.068),Vector3(0.078,0.03,0.034)],8),m.skin,mid,Vector3(-PI*0.5,0.0,0.0))
	part(pivot,FacetMesh.hull([Vector3(-0.005,0.081,0.083),Vector3(0.04,0.073,0.076),Vector3(0.072,0.045,0.048),Vector3(0.09,0.0,0.0)],8),m.leather,mid+Vector3(0.0,0.012,0.012),Vector3(-PI*0.5,0.0,0.0))
	for side in [-1.0,1.0]: part(pivot,GliderFigure._gem(0.03),m.leather,mid+Vector3(0.078*side,-0.02,0.007),Vector3.ZERO,Vector3(0.45,1.3,0.9))
	part(pivot,GliderFigure._frustum(0.085,0.085,0.016,10),m.strap,mid+Vector3(0.0,0.012,0.01),Vector3.ZERO)
	for side in [-1.0,1.0]:
		var turn := Vector3(PI*0.5,0.35*side,0.0)
		part(pivot,GliderFigure._frustum(0.025,0.025,0.014,8),m.brass,mid+Vector3(0.03*side,0.012,-0.073),turn)
		part(pivot,GliderFigure._frustum(0.019,0.019,0.016,8),m.lens,mid+Vector3(0.031*side,0.012,-0.076),turn)
	return [neck,pivot]

## A limb on `parent`: [upper, lower, end], the two bones unit tall (posed
## by `pose`) and the end (a hand or a boot) placed at their tip.
static func limb(parent: Node3D, upper: Vector2, lower: Vector2, material: Material, end: Mesh, end_material: Material) -> Array:
	var a := part(parent,GliderFigure._frustum(upper.x,upper.y,1.0,5),material,Vector3.ZERO,Vector3.ZERO)
	var b := part(parent,GliderFigure._frustum(lower.x,lower.y,1.0,5),material,Vector3.ZERO,Vector3.ZERO)
	var c := part(parent,end,end_material,Vector3.ZERO,Vector3.ZERO)
	return [a,b,c]

## A gloved hand.
static func hand() -> Mesh:
	return GliderFigure._gem(0.021)

## A boot, toe forward (-Z), its sole at its origin's height.
static func boot() -> Mesh:
	return FacetMesh.hull([Vector3(-0.055,0.014,0.01),Vector3(-0.035,0.028,0.02),Vector3(0.015,0.027,0.024),Vector3(0.03,0.02,0.02)],6)

## Poses `limb` from `root` to `tip` (in its parent's frame), the joint
## bent towards `pole`, the bones `lengths` long. Out of reach, it points.
static func pose(limb_parts: Array, root: Vector3, tip: Vector3, lengths: Vector2, pole: Vector3) -> void:
	var to := tip-root
	var d := clampf(to.length(),0.02,lengths.x+lengths.y-0.002)
	var dir := to.normalized() if to.length() > 0.0001 else Vector3.DOWN
	tip = root+dir*d
	var along := (lengths.x*lengths.x-lengths.y*lengths.y+d*d)/(2.0*d)
	var out := sqrt(maxf(lengths.x*lengths.x-along*along,0.0))
	var bend := pole-dir*pole.dot(dir)
	bend = bend.normalized() if bend.length_squared() > 1e-8 else Vector3.FORWARD
	var joint := root+dir*along+bend*out
	bone(limb_parts[0],root,joint)
	bone(limb_parts[1],joint,tip)
	(limb_parts[2] as Node3D).position = tip

## Stretches a unit-tall bone mesh from `from` to `to`.
static func bone(node: Node3D, from: Vector3, to: Vector3) -> void:
	var y := to-from
	if y.length_squared() < 1e-8: return
	var x := y.cross(Vector3.FORWARD if absf(y.normalized().dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	node.transform = Transform3D(Basis(x,y,x.cross(y.normalized()).normalized()),(from+to)*0.5)

static func part(parent: Node3D, mesh: Mesh, material: Material, at: Vector3, turn: Vector3, size := Vector3.ONE) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	node.rotation = turn
	node.scale = size
	parent.add_child(node)
	return node

static func _matte(color: Color, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	return m

static func _lacquer(color: Color, roughness: float, coat: float) -> StandardMaterial3D:
	var m := _matte(color,roughness)
	m.clearcoat_enabled = true
	m.clearcoat = coat
	m.clearcoat_roughness = 0.12
	return m

static func _metal(color: Color, roughness: float) -> StandardMaterial3D:
	var m := _matte(color,roughness)
	m.metallic = 1.0
	return m
