extends Node3D
## The railroad's plain track on its bed (spec-railroad.md, lane line): two
## tracks along the line (rail_line.gd), each a ballast strip, sleepers and
## two rails, in greybox. Built only near the eye, in PIECE m lengths of
## the line: the ballast out to FAR, sleepers and rails out to NEAR,
## colliders (physics layer 1, as the arches) within COLLIDE of the plane.
##
## The rails stand in the flight like any stone: `ground` raises the land
## under the plane to the rails' tops over each track (the study's
## `plane_ground`), so the near misses read a pass low along them as a
## graze over stone (NearMiss `_standing`), and the wing rays hit the
## colliders as stone (NearMiss `_what`).
##
## The track runs the whole lap, in tunnels and over trestles and bridges
## too (their bores and spans are their own pieces); the ballast is left
## off the spans, where the sleepers lie on the deck.
##
## Seed 1's wilderness only, with the bed (LandField's `_rail`):
## `--no-railroad` leaves it out.

const RailLine = preload("res://scripts/endless/rail_line.gd")
const RailBed = preload("res://scripts/endless/rail_bed.gd")
## In a tunnel, past its first DAY_IN m, a piece is on the bore's inside
## layer (RailBore: the sun leaves it out).
const UNDER_LAYER := 1 << 14
const DAY_IN := 14.0

## Metres of the line in a piece, and between the frames it is built on.
const PIECE := 64.0
const FRAME := 4.0
## Built within these of the eye (m past a piece's bounding ball), freed
## past them by FREE_AT; colliders within COLLIDE of the plane.
const FAR := 1400.0
const NEAR := 450.0
const COLLIDE := 90.0
const FREE_AT := 1.25
## Build time a frame (ms); at least one piece is built when one is wanted.
const BUDGET_MS := 1.2

## The track, for a train oversized next to a real one (CAR_WIDTH 6 m):
## rail centre to rail centre, and each part's height over the bed's top.
const GAUGE := 3.0
const BALLAST_TOP := 0.35
const BALLAST_HALF := 2.8      # half the strip's top
const BALLAST_FOOT := 3.7      # half its foot, under the bed's top
const BALLAST_SINK := 0.3
const SLEEPER_HALF := 2.3      # half its length, across the track
const SLEEPER_WIDTH := 0.5
const SLEEPER_STEP := 1.6
const SLEEPER_BASE := 0.27
const SLEEPER_TOP := 0.49
const RAIL_WIDTH := 0.3
const RAIL_TOP := 0.84
## What `ground` stands the plane on over a track: the rails' tops, from
## this far under the bed's top (a span's sleepers have air under them).
const SLAB_UNDER := 0.5

const BALLAST_C := Color(0.43,0.40,0.36)
const BALLAST_SIDE_C := Color(0.37,0.34,0.30)
const SLEEPER_C := Color(0.27,0.19,0.13)
const STEEL_C := Color(0.46,0.45,0.44)

var line: RefCounted
var _bed: RefCounted
var _gap := 13.0
var _n := 0
var _centre := PackedVector3Array()
var _radius := PackedFloat32Array()
## Per piece: its ballast's MeshInstance3D, its rails', its StaticBody3D.
var _far: Array = []
var _near: Array = []
var _body: Array = []
var _faces: Array = []
var _under := PackedByteArray()
var _earth: StandardMaterial3D
var _steel: StandardMaterial3D
## Pieces built so far (a driver's count).
var built := 0

## The track is laid where the land has the railroad's bed.
static func wanted(field: RefCounted) -> bool:
	return field != null and field.get("_rail") != null

func setup(_field: RefCounted) -> void:
	line = RailLine.shared()
	_bed = RailBed.new()
	_gap = float(line.track_gap())
	var length: float = line.length()
	_n = ceili(length/PIECE)
	_centre.resize(_n)
	_radius.resize(_n)
	for i in _n:
		var s0 := i*PIECE
		var s1 := minf(s0+PIECE,length)
		_centre[i] = line.centre((s0+s1)*0.5)
		_radius[i] = (s1-s0)*0.5+_gap*0.5+BALLAST_FOOT
	for a: Array in [_far,_near,_body,_faces]:
		a.resize(_n)
	_under.resize(_n)
	_under.fill(0)
	for st: Array in line.stretches("tunnel"):
		for i in _n:
			if i*PIECE >= float(st[0])+DAY_IN and minf(i*PIECE+PIECE,length) <= float(st[1])-DAY_IN: _under[i] = 1
	_earth = StandardMaterial3D.new()
	_earth.vertex_color_use_as_albedo = true
	_earth.roughness = 0.95
	_steel = StandardMaterial3D.new()
	_steel.albedo_color = STEEL_C
	_steel.metallic = 0.2
	_steel.roughness = 0.45

## Each frame: pieces built near `eye` and freed far from it; colliders near
## the plane at `plane_at`.
func step(eye: Vector3, plane_at: Vector3) -> void:
	if _n == 0: return
	var t0 := Time.get_ticks_usec()
	# Wanted pieces as Vector3(distance, piece, 0 ballast / 1 rails).
	var wants: Array[Vector3] = []
	for i in _n:
		var d := eye.distance_to(_centre[i])-_radius[i]
		if _far[i] == null:
			if d < FAR: wants.append(Vector3(d,i,0))
		elif d > FAR*FREE_AT:
			_free(i)
			continue
		if _near[i] == null:
			if d < NEAR: wants.append(Vector3(d-NEAR,i,1))
		elif d > NEAR*FREE_AT:
			_near[i].queue_free()
			_near[i] = null
			_faces[i] = null
		var dp := plane_at.distance_to(_centre[i])-_radius[i]
		if _body[i] == null:
			if dp < COLLIDE and _faces[i] != null: _collide(i)
		elif dp > COLLIDE*FREE_AT:
			_body[i].queue_free()
			_body[i] = null
	if wants.is_empty(): return
	# The nearest first, a piece's rails before far ballast, in the budget.
	wants.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.x < b.x)
	for w: Vector3 in wants:
		if w.z > 0.5: _build_near(int(w.y))
		else: _build_far(int(w.y))
		if (Time.get_ticks_usec()-t0) > BUDGET_MS*1000.0: break

## Over a track (grown by `pad`), at or over its sleepers' foot: the rails'
## tops, if over `h`. As the other stone's `ground` (LandArches): `h` the
## height so far, or what it already is if not a height.
func ground(p: Vector3, h: Variant, pad := 0.0) -> Variant:
	if not h is float or _n == 0: return h
	var a: Vector3 = _bed.across(p.x,p.z)
	if is_nan(a.x): return h
	var reach := BALLAST_HALF+maxf(pad,0.0)
	if absf(absf(a.y)-_gap*0.5) > reach: return h
	if p.y < a.z-SLAB_UNDER: return h
	return maxf(h,a.z+RAIL_TOP)

func _free(i: int) -> void:
	for a: Array in [_far,_near,_body]:
		if a[i] != null:
			a[i].queue_free()
			a[i] = null
	_faces[i] = null

## The piece's frames: s, the line's centre, its right (level) and up.
func _frames(i: int) -> Dictionary:
	var length: float = line.length()
	var s0 := i*PIECE
	var s1 := minf(s0+PIECE,length)
	var steps := maxi(ceili((s1-s0)/FRAME),1)
	var ss := PackedFloat32Array()
	var cs := PackedVector3Array()
	var rs := PackedVector3Array()
	var us := PackedVector3Array()
	var span := PackedByteArray()
	for k in steps+1:
		var s := lerpf(s0,s1,float(k)/steps)
		var fwd: Vector3 = line.tangent(s)
		var up := (Vector3.UP-fwd*fwd.y).normalized()
		ss.append(s)
		cs.append(line.centre(s))
		rs.append(fwd.cross(up).normalized())
		us.append(up)
		var kind: String = line.kind(s)
		span.append(1 if kind == "trestle" or kind == "bridge" else 0)
	return {"s":ss,"c":cs,"r":rs,"u":us,"span":span}

## The ballast strips, both tracks.
func _build_far(i: int) -> void:
	var f := _frames(i)
	var m := _Mesh.new()
	var cs: PackedVector3Array = f.c
	var rs: PackedVector3Array = f.r
	var us: PackedVector3Array = f.u
	var span: PackedByteArray = f.span
	for side: float in [1.0,-1.0]:
		for k in cs.size()-1:
			if span[k] == 1 and span[k+1] == 1: continue
			var a := cs[k]+rs[k]*(side*_gap*0.5)
			var b := cs[k+1]+rs[k+1]*(side*_gap*0.5)
			var ra := rs[k]
			var rb := rs[k+1]
			var ua := us[k]
			var ub := us[k+1]
			var la0 := a-ra*BALLAST_FOOT-ua*BALLAST_SINK
			var la1 := a-ra*BALLAST_HALF+ua*BALLAST_TOP
			var ra1 := a+ra*BALLAST_HALF+ua*BALLAST_TOP
			var ra0 := a+ra*BALLAST_FOOT-ua*BALLAST_SINK
			var lb0 := b-rb*BALLAST_FOOT-ub*BALLAST_SINK
			var lb1 := b-rb*BALLAST_HALF+ub*BALLAST_TOP
			var rb1 := b+rb*BALLAST_HALF+ub*BALLAST_TOP
			var rb0 := b+rb*BALLAST_FOOT-ub*BALLAST_SINK
			m.quad(la0,lb0,lb1,la1,-ra+ua,BALLAST_SIDE_C)
			m.quad(la1,lb1,rb1,ra1,ua,BALLAST_C)
			m.quad(ra1,rb1,rb0,ra0,ra+ua,BALLAST_SIDE_C)
	var mi := m.instance(_earth)
	if _under[i] == 1: mi.layers = UNDER_LAYER
	add_child(mi)
	_far[i] = mi
	built += 1

## The sleepers and rails, both tracks; their faces kept for the collider.
func _build_near(i: int) -> void:
	var f := _frames(i)
	var earth := _Mesh.new()
	var steel := _Mesh.new()
	var ss: PackedFloat32Array = f.s
	var cs: PackedVector3Array = f.c
	var rs: PackedVector3Array = f.r
	var us: PackedVector3Array = f.u
	var nk := cs.size()
	for side: float in [1.0,-1.0]:
		var off := side*_gap*0.5
		# Sleepers every SLEEPER_STEP of s, on the frames between.
		var s := ceilf(ss[0]/SLEEPER_STEP)*SLEEPER_STEP
		var k := 0
		while s < ss[nk-1]:
			while k < nk-2 and ss[k+1] < s: k += 1
			var t := (s-ss[k])/maxf(ss[k+1]-ss[k],0.001)
			var c := cs[k].lerp(cs[k+1],t)
			var r := rs[k].lerp(rs[k+1],t).normalized()
			var u := us[k].lerp(us[k+1],t).normalized()
			var fw := u.cross(r)
			earth.box(c+r*off+u*((SLEEPER_BASE+SLEEPER_TOP)*0.5),r*SLEEPER_HALF,fw*(SLEEPER_WIDTH*0.5),u*((SLEEPER_TOP-SLEEPER_BASE)*0.5),SLEEPER_C)
			s += SLEEPER_STEP
		# The two rails, on the sleepers.
		for rail: float in [-0.5,0.5]:
			for q in nk-1:
				var a := cs[q]+rs[q]*(off+rail*GAUGE)
				var b := cs[q+1]+rs[q+1]*(off+rail*GAUGE)
				var ra := rs[q]*(RAIL_WIDTH*0.5)
				var rb := rs[q+1]*(RAIL_WIDTH*0.5)
				var a0 := us[q]*SLEEPER_TOP
				var a1 := us[q]*RAIL_TOP
				var b0 := us[q+1]*SLEEPER_TOP
				var b1 := us[q+1]*RAIL_TOP
				steel.quad(a-ra+a0,b-rb+b0,b-rb+b1,a-ra+a1,-rs[q],STEEL_C)
				steel.quad(a-ra+a1,b-rb+b1,b+rb+b1,a+ra+a1,us[q],STEEL_C)
				steel.quad(a+ra+a1,b+rb+b1,b+rb+b0,a+ra+a0,rs[q],STEEL_C)
	var mi := earth.instance(_earth)
	steel.add_to(mi.mesh as ArrayMesh,_steel)
	if _under[i] == 1: mi.layers = UNDER_LAYER
	add_child(mi)
	_near[i] = mi
	_faces[i] = steel.verts
	built += 1

func _collide(i: int) -> void:
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(_faces[i])
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	_body[i] = body

## A mesh in the making: flat-shaded triangles with vertex colours.
class _Mesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()

	## The quad a b c d (in order round it), facing `face`'s side.
	func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, face: Vector3, col: Color) -> void:
		var n := (b-a).cross(c-a)
		if n.dot(face) > 0.0:
			# Godot's front faces wind clockwise seen from outside.
			var t := b
			b = d
			d = t
			n = -n
		n = -n.normalized()
		for v: Vector3 in [a,b,c,a,c,d]:
			verts.append(v)
			normals.append(n)
			colors.append(col)

	## A box at `c` with half-axes `x`, `z` (level) and `y` (up), no floor.
	func box(c: Vector3, x: Vector3, z: Vector3, y: Vector3, col: Color) -> void:
		var top := c+y
		var bot := c-y
		quad(top-x-z,top+x-z,top+x+z,top-x+z,y,col)
		quad(bot-x-z,bot+x-z,top+x-z,top-x-z,-z,col)
		quad(bot-x+z,bot+x+z,top+x+z,top-x+z,z,col)
		quad(bot-x-z,bot-x+z,top-x+z,top-x-z,-x,col)
		quad(bot+x-z,bot+x+z,top+x+z,top+x-z,x,col)

	func add_to(mesh: ArrayMesh, mat: Material) -> void:
		if verts.is_empty(): return
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		mesh.surface_set_material(mesh.get_surface_count()-1,mat)

	func instance(mat: Material) -> MeshInstance3D:
		var mesh := ArrayMesh.new()
		add_to(mesh,mat)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return mi
