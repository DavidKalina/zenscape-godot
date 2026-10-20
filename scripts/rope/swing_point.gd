extends RefCounted
## Swing points that grow out of the land (greybox): shapes the rope's hook
## can be thrown over and swung from (scripts/rope/hook_line.gd), each a
## StaticBody3D carrying one hook line. Kept apart from any one level so
## they can become kit pieces later.
##
## Every kind is built in the same frame: the origin is the middle of the
## hook line's top (where the rope rests), +x runs along the line, +y is up.
## The swing hangs under the line and swings across it (in the y-z plane),
## so a point that carries you over a gap runs across the gap, not along it.
## A world-view move or turn of the body carries the line along.
##
## Kinds (`build(kind, id, long, drop)`; `long` the swingable length along
## x, `drop` how far its footing reaches under the line):
##   arch    a natural rock arch: a rough span on two leaning legs that rise
##           from `drop` below (a gap's floor or two lower faces); the line
##           along the span's top. The way in's gantry, made of rock.
##   arm     a stone arm jutting out of a cliff face: its root block sunk
##           back into the rock at -x (set the body so the root sits in the
##           face), the arm reaching out along +x, a knuckle at the tip.
##           `drop` is how far the root's buttress runs down the face.
##   branch  a dead tree on a rim: the trunk at -x stands `drop` tall from
##           its roots to the fork, the branch out along +x over the drop,
##           tapering, a stub at its end.
##   lintel  a broken ruin lintel: a squared post at -x standing `drop`
##           tall, the lintel resting on it and sticking out along +x, its
##           far end snapped off.

const HookLine = preload("res://scripts/rope/hook_line.gd")

const KINDS := ["arch","arm","branch","lintel"]

## The swung bar's thickness per kind (m): the hook's clearance is half
## the larger of its depth and height (HookLine.on_box).
const BAR := {"arch":Vector2(1.4,1.1),"arm":Vector2(1.1,1.0),"branch":Vector2(0.55,0.55),"lintel":Vector2(0.9,0.8)}

## How far in from the -x end the line starts (the root, trunk or post sits
## there, so the hook doesn't snap onto it).
const ROOT_IN := {"arch":0.0,"arm":0.6,"branch":0.5,"lintel":0.6}

static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m

static var _rock: StandardMaterial3D
static var _wood: StandardMaterial3D
static var _cut: StandardMaterial3D

static func _mats() -> void:
	if _rock != null: return
	_rock = _mat(Color(0.5,0.44,0.38))
	_wood = _mat(Color(0.36,0.3,0.25))
	_cut = _mat(Color(0.68,0.65,0.58))

## A box (drawn and solid) at `at`, turned by `basis`, of `size`.
static func _box(body: Node3D, size: Vector3, at: Vector3, mat: Material, basis := Basis()) -> CollisionShape3D:
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	col.shape = box
	col.transform = Transform3D(basis,at)
	body.add_child(col)
	var drawn := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	drawn.mesh = bm
	drawn.material_override = mat
	drawn.transform = col.transform
	body.add_child(drawn)
	return col

## A tapered round post (drawn and solid) from `from` to `to`.
static func _post(body: Node3D, from: Vector3, to: Vector3, r_from: float, r_to: float, mat: Material) -> void:
	var d := to-from
	var up := d.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var basis := Basis(side,up,side.cross(up))
	var at := Transform3D(basis,(from+to)*0.5)
	var drawn := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = r_from
	cm.top_radius = r_to
	cm.height = d.length()
	cm.radial_segments = 6
	cm.rings = 1
	drawn.mesh = cm
	drawn.material_override = mat
	drawn.transform = at
	body.add_child(drawn)
	var col := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = maxf(r_from,r_to)
	cs.height = d.length()
	col.shape = cs
	col.transform = at
	body.add_child(col)

## The hook line along the top from x0 to x1, its clearance half the bar.
static func _line(body: Node3D, id: String, x0: float, x1: float, bar: Vector2, ring := false) -> Node3D:
	var line: Node3D = HookLine.new()
	line.ring = ring
	line.name = "HookLine"
	line.a = Vector3(x0,0.0,0.0)
	line.b = Vector3(x1,0.0,0.0)
	line.clearance = maxf(bar.x,bar.y)*0.5
	line.piece = id
	body.add_child(line)
	return line

## A swing point of `kind` named `id`: `long` m of line, its footing `drop`
## m under the line. `ring` (opt-in): a throw anywhere along it hooks the
## line's middle (HookLine.ring), so the swing runs the same whatever the
## aim. Null for an unknown kind.
static func build(kind: String, id: String, long: float, drop: float, ring := false) -> StaticBody3D:
	if not kind in KINDS: return null
	_mats()
	var body := StaticBody3D.new()
	body.name = id
	body.set_meta("swing_kind",kind)
	var bar: Vector2 = BAR[kind]
	var h := long*0.5
	var mid := Vector3(0.0,-bar.y*0.5,0.0)
	match kind:
		"arch":
			# The span, then a haunch at each end where it meets its leg,
			# the legs leaning out as they go down.
			# Down at `drop` the legs meet in a floating keel with a tail
			# under it, so the arch is a ring of rock like the isles.
			_box(body,Vector3(long,bar.y,bar.x),mid,_rock)
			var foot := h+1.0+drop*0.18
			for e: float in [-1.0,1.0]:
				_box(body,Vector3(3.0,2.6,bar.x*1.8),Vector3(e*(h+1.0),-1.3,0.0),_rock,Basis(Vector3.BACK,e*0.35))
				_post(body,Vector3(e*foot,-drop,0.0),Vector3(e*(h+1.2),-1.2,0.0),3.2,1.5,_rock)
			_box(body,Vector3(foot*2.0+3.0,4.0,4.2),Vector3(0.0,-drop-1.0,0.0),_rock)
			_post(body,Vector3(0.0,-drop-2.5,0.0),Vector3(0.0,-drop-2.5-drop*0.4,0.0),foot*0.55,0.3,_rock)
		"arm":
			# The root block sunk into the face behind -x, a buttress down
			# the face under it, the arm, a knuckle at the tip.
			_box(body,Vector3(long,bar.y,bar.x),mid,_rock)
			_box(body,Vector3(4.0,3.2,3.2),Vector3(-h-1.6,-1.8,0.0),_rock)
			_box(body,Vector3(1.8,drop,2.2),Vector3(-h-0.6,-drop*0.5,0.0),_rock,Basis(Vector3.BACK,-0.12))
			_box(body,Vector3(0.9,1.6,1.4),Vector3(h+0.2,0.2,0.0),_rock)
		"branch":
			# The branch (squared so the hook line rides it), the trunk at
			# -x from the roots up past the fork, a stub past the tip.
			_box(body,Vector3(long,bar.y,bar.x),mid,_wood)
			_post(body,Vector3(-h-0.2,-drop,0.0),Vector3(-h-0.2,2.5,0.0),0.8,0.35,_wood)
			_post(body,Vector3(-h-0.2,1.0,0.0),Vector3(-h-1.8,3.4,0.6),0.3,0.12,_wood)
			_post(body,Vector3(h,-0.25,0.0),Vector3(h+1.0,0.5,-0.3),0.2,0.08,_wood)
			for k in 3:
				var a := TAU*k/3.0+0.4
				_post(body,Vector3(-h-0.2,-drop+0.6,0.0),Vector3(-h-0.2+cos(a)*1.6,-drop-0.4,sin(a)*1.6),0.35,0.15,_wood)
		"lintel":
			# The post at -x, its capital, the lintel on it with a snapped
			# piece hanging off the far end.
			_box(body,Vector3(long,bar.y,bar.x),mid,_cut)
			_box(body,Vector3(1.3,drop-bar.y,1.3),Vector3(-h+0.4,-bar.y-(drop-bar.y)*0.5,0.0),_cut)
			_box(body,Vector3(1.7,0.4,1.7),Vector3(-h+0.4,-bar.y-0.2,0.0),_cut)
			_box(body,Vector3(0.8,bar.y*0.8,bar.x*0.9),Vector3(h+0.25,-bar.y*0.75,0.1),_cut,Basis(Vector3.BACK,-0.5))
	_line(body,id,-h+float(ROOT_IN[kind]),h,bar,ring)
	return body

## The body's transform for a point whose line's top middle is `top`,
## running along `along` (x, z) in the world.
static func frame(top: Vector3, along: Vector2) -> Transform3D:
	var xb := Vector3(along.x,0.0,along.y).normalized()
	return Transform3D(Basis(xb,Vector3.UP,xb.cross(Vector3.UP)),top)
