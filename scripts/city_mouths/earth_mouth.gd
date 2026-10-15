extends Node3D
## One Earth Mouth (round 4 strange city, card a5-earth-mouths): a carved
## earth-monster maw laid in the floor, after Chalcatzingo's Monument 9, the
## quatrefoil cave-mouth of the earth with its eyes over it. The throat is a
## smooth black quatrefoil; round it a low lip of stone (`LIP_H`, under the
## wanderer's step) whose four inner cusps curl into breath scrolls; north of
## it two carved almond eyes, and behind them a low altar with its numeral in
## bar-and-dot (one dot I, two II, three III), pale fresh-cut stone so it
## reads from the next terrace. It faces local +z: what it spits goes out
## that way.
##
## It doesn't think: scripts/city_mouths/earth_mouths.gd (the belly) tells it
## what to show:
##   `gape`     0 shut .. 1 open: the lip grinds open a hand's width (the
##              lip drawn wider, with a grinding shiver while it moves).
##   `fullness` how many things the shared belly holds: a mouth breathes
##              slow mist from its scrolls while the belly holds anything,
##              more the fuller (the card's "A full belly" tell).
##   `brewing`  this mouth is about to spit: the mist thickens into a
##              column (the card's "Mist" tell), seconds before it spits.
##   `burst()`  a gulp's or a spit's puff, low and outward.
## Collision: the lip (a trimesh) and the altar; the throat is the floor it
## lies on, so awake you walk in and out of it ("just a dark alcove").
const Refuges = preload("res://scripts/city_kit_refuges.gd")
const GiantStone = preload("res://scripts/kit_isle/greybox/giant_stone.gd")

## The throat: four lobes of `LOBE` m round, `LOBE_AT` m out on the axes
## (out to `throat_r()` 3.4 m: the Olmec's 4.4 m shoulders stoop into it).
const LOBE := 1.75
const LOBE_AT := 1.65
## The lip round it: `LIP` m wide, `LIP_H` m high (the wanderer steps 0.45).
const LIP := 0.9
const LIP_H := 0.3
const SEGMENTS := 64
## The altar behind the eyes: its size (its top with the cap under the
## Olmec's step, 1.23 m: he walks over it; you climb it) and how far back.
const STELE := Vector3(3.4,0.95,1.6)
const STELE_BACK := 7.6
const DOT_R := 0.4
## The tones: the throat's black (unshaded, a hole), the numeral's pale.
const THROAT := Color(0.022,0.018,0.014)
const PALE := 1.45
## The mist: pale, dim, never a glow.
const MIST := Color(0.6,0.62,0.6)
const PUFFS := 40

var numeral := 1
var gape := 0.0
var fullness := 0
var brewing := false
var _gape_shown := 0.0
var _lips: MeshInstance3D
var _throat: MeshInstance3D
var _puffs: Array = []
var _rate_debt := 0.0
var _clock := 0.0
var _rng := RandomNumberGenerator.new()
static var _mist_mat: StandardMaterial3D = null
static var _quad: QuadMesh = null

## The quatrefoil's radius at angle `a` (rad, about up from +x).
static func throat_at(a: float) -> float:
	var u := Vector2(cos(a),sin(a))
	var best := 0.0
	for c: Vector2 in [Vector2(LOBE_AT,0.0),Vector2(-LOBE_AT,0.0),Vector2(0.0,LOBE_AT),Vector2(0.0,-LOBE_AT)]:
		var b := u.dot(c)
		var disc := b*b-c.length_squared()+LOBE*LOBE
		if disc >= 0.0: best = maxf(best,b+sqrt(disc))
	return best

## Its widest reach of throat (m), and of lip.
static func throat_r() -> float:
	return LOBE_AT+LOBE

static func lip_r() -> float:
	return throat_r()+LIP

## Whether the flat point `p` (world) is in the throat, `give` m in from its edge.
func in_throat(p: Vector3, give := 0.0) -> bool:
	var l := to_local(Vector3(p.x,global_position.y,p.z))
	var d := Vector2(l.x,l.z)
	return d.length() <= throat_at(atan2(d.y,d.x))-give

## The throat's floor (world): where things go in and come out.
func throat() -> Vector3:
	return global_position

## The way it spits (world, flat).
func out() -> Vector3:
	return global_basis.z.normalized()

func build(n: int, seed_value := 1) -> void:
	numeral = n
	name = "EarthMouth%d" % n
	_rng.seed = seed_value
	var stone := Refuges.stone_material()
	# The lip: a ring of segments, each a convex quad prism.
	var m := Refuges.CityMesher.new(GiantStone.stone_colour())
	for k in SEGMENTS:
		var a0 := TAU*k/SEGMENTS
		var a1 := TAU*(k+1)/SEGMENTS
		var r0 := throat_at(a0)
		var r1 := throat_at(a1)
		var d0 := Vector3(cos(a0),0.0,sin(a0))
		var d1 := Vector3(cos(a1),0.0,sin(a1))
		var mid := (d0+d1).normalized()
		m._centre = mid*(r0+LIP*0.5)
		m._foot = 0.0
		# The inner wall, down into the dark (darker than the top).
		m._tone = 0.45
		_face(m,[d0*r0,d1*r1,d1*r1+Vector3.UP*(LIP_H-0.08),d0*r0+Vector3.UP*(LIP_H-0.08)],-mid)
		m._tone = 0.8
		_face(m,[d0*r0+Vector3.UP*(LIP_H-0.08),d1*r1+Vector3.UP*(LIP_H-0.08),d1*(r1+0.14)+Vector3.UP*LIP_H,d0*(r0+0.14)+Vector3.UP*LIP_H],(Vector3.UP-mid).normalized())
		m._tone = 1.0
		_face(m,[d0*(r0+0.14)+Vector3.UP*LIP_H,d1*(r1+0.14)+Vector3.UP*LIP_H,d1*(r1+LIP-0.3)+Vector3.UP*LIP_H,d0*(r0+LIP-0.3)+Vector3.UP*LIP_H],Vector3.UP)
		_face(m,[d0*(r0+LIP-0.3)+Vector3.UP*LIP_H,d1*(r1+LIP-0.3)+Vector3.UP*LIP_H,d1*(r1+LIP),d0*(r0+LIP)],(Vector3.UP+mid).normalized())
	# The breath scrolls at the four inner cusps: a curl (a disc, a smaller
	# one set off it, a smaller again) on the lip's top.
	for c in 4:
		var a := PI*0.25+PI*0.5*c
		var d := Vector3(cos(a),0.0,sin(a))
		var side := Vector3.UP.cross(d)
		var r := throat_at(a)+0.35
		m.cylinder(Transform3D(Basis.IDENTITY,d*r+Vector3.UP*(LIP_H+0.09)),0.55,0.18,14,0.06,0.0,0.95)
		m.cylinder(Transform3D(Basis.IDENTITY,d*(r-0.05)+side*0.16+Vector3.UP*(LIP_H+0.24)),0.34,0.14,12,0.05,0.0,1.05)
		m.cylinder(Transform3D(Basis.IDENTITY,d*(r-0.08)+side*0.26+Vector3.UP*(LIP_H+0.36)),0.16,0.12,10,0.04,0.0,1.15)
	_lips = MeshInstance3D.new()
	_lips.name = "Lips"
	_lips.mesh = m.mesh(stone,null)
	add_child(_lips)
	var lip_body := StaticBody3D.new()
	lip_body.name = "LipBody"
	var lip_shape := CollisionShape3D.new()
	lip_shape.shape = _lips.mesh.create_trimesh_shape()
	lip_body.add_child(lip_shape)
	add_child(lip_body)
	# The throat: smooth and black, a hole in the floor.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_normal(Vector3.UP)
	for k in SEGMENTS:
		var a0 := TAU*k/SEGMENTS
		var a1 := TAU*(k+1)/SEGMENTS
		st.add_vertex(Vector3(0.0,0.03,0.0))
		st.add_vertex(Vector3(cos(a1),0.0,sin(a1))*(throat_at(a1)+0.04)+Vector3.UP*0.03)
		st.add_vertex(Vector3(cos(a0),0.0,sin(a0))*(throat_at(a0)+0.04)+Vector3.UP*0.03)
	_throat = MeshInstance3D.new()
	_throat.name = "Throat"
	_throat.mesh = st.commit()
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = THROAT
	_throat.material_override = black
	_throat.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_throat)
	# The face north of it: two almond eyes, the slits lampblack; the altar
	# with its numeral behind.
	var f := Refuges.CityMesher.new(GiantStone.stone_colour())
	var eye_z := -(lip_r()+1.1)
	for s: float in [-1.0,1.0]:
		var at := Vector3(s*1.75,0.0,eye_z)
		var turn := Basis(Vector3.UP,-s*0.16)
		f.box(Transform3D(turn,at+Vector3.UP*0.09),Vector3(2.4,0.18,1.0),0.12,0.0,0.95)
		f.box(Transform3D(turn,at+Vector3.UP*0.2),Vector3(1.6,0.06,0.28),0.02,0.0,0.3)
	f.box(Transform3D(Basis.IDENTITY,Vector3(0.0,0.07,eye_z-0.2)),Vector3(0.7,0.14,1.4),0.08,0.0,0.9)
	# The altar (La Venta's Altar 4 is itself the earth-monster's cave
	# mouth): a low block under his step, so the Olmec walks over it.
	f.box(Transform3D(Basis.IDENTITY,Vector3(0.0,STELE.y*0.5,-STELE_BACK)),STELE,0.14,0.0,1.0)
	f.box(Transform3D(Basis.IDENTITY,Vector3(0.0,STELE.y+0.08,-STELE_BACK)),Vector3(STELE.x+0.3,0.16,STELE.z+0.3),0.06,0.0,0.92)
	# The numeral: n dots in a row on its front, and again on its top (read
	# from the terraces above), pale fresh-cut stone; a bar's groove under.
	var face_z := -STELE_BACK+STELE.z*0.5
	var face_turn := Basis(Vector3.RIGHT,PI*0.5)
	for i in n:
		var x := (float(i)-float(n-1)*0.5)*(DOT_R*2.0+0.24)
		f.cylinder(Transform3D(face_turn,Vector3(x,STELE.y*0.58,face_z+0.06)),DOT_R*0.8,0.14,14,0.05,NAN,PALE)
		f.cylinder(Transform3D(Basis.IDENTITY,Vector3(x,STELE.y+0.18,-STELE_BACK)),DOT_R,0.08,14,0.03,NAN,PALE)
	f.box(Transform3D(Basis.IDENTITY,Vector3(0.0,STELE.y*0.2,face_z+0.03)),Vector3(STELE.x-0.6,0.1,0.08),0.02,NAN,0.4)
	for i in n:
		var x := (float(i)-float(n-1)*0.5)*0.5
		f.cylinder(Transform3D(Basis.IDENTITY,Vector3(x,0.16,eye_z-0.2)),0.17,0.06,10,0.02,0.0,PALE)
	var face_mi := MeshInstance3D.new()
	face_mi.name = "Face"
	face_mi.mesh = f.mesh(stone,null)
	add_child(face_mi)
	var stele_body := StaticBody3D.new()
	stele_body.name = "AltarBody"
	var sc := CollisionShape3D.new()
	var sb := BoxShape3D.new()
	sb.size = STELE+Vector3(0.3,0.16,0.3)
	sc.shape = sb
	sc.position = Vector3(0.0,(STELE.y+0.16)*0.5,-STELE_BACK)
	stele_body.add_child(sc)
	add_child(stele_body)
	set_meta("tris",m.triangles()+f.triangles()+SEGMENTS)
	_build_mist()

## A convex face `pts` (local), its outside `out`.
static func _face(m: Object, pts: Array, out: Vector3) -> void:
	var mid := Vector3.ZERO
	for p: Vector3 in pts: mid += p
	mid /= pts.size()
	m._poly(Transform3D.IDENTITY,pts,mid-out)

# --- The mist --------------------------------------------------------------------------------

func _build_mist() -> void:
	if _mist_mat == null:
		var g := Gradient.new()
		g.set_color(0,Color(1.0,1.0,1.0,1.0))
		g.set_color(1,Color(1.0,1.0,1.0,0.0))
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5,0.5)
		tex.fill_to = Vector2(1.0,0.5)
		tex.width = 64
		tex.height = 64
		_mist_mat = StandardMaterial3D.new()
		_mist_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mist_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mist_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_mist_mat.billboard_keep_scale = true
		_mist_mat.albedo_texture = tex
		_mist_mat.albedo_color = MIST
		_mist_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		_quad = QuadMesh.new()
		_quad.size = Vector2.ONE
	for i in PUFFS:
		var q := MeshInstance3D.new()
		q.mesh = _quad
		q.material_override = _mist_mat
		q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		q.visible = false
		add_child(q)
		_puffs.append({"mi":q,"life":0.0,"t":0.0,"v":Vector3.ZERO,"size":1.0,"grow":1.0,"a":0.0})

## A puff from a scroll (or the middle), going `v`, `size` m, alpha `a`.
func _puff(from_scroll: bool, v: Vector3, size: float, grow: float, a: float, life: float) -> void:
	for p: Dictionary in _puffs:
		if p.t < p.life: continue
		var at := Vector3.ZERO
		if from_scroll:
			var c := _rng.randi_range(0,3)
			var ang := PI*0.25+PI*0.5*c
			at = Vector3(cos(ang),0.0,sin(ang))*(throat_at(ang)+0.2)+Vector3.UP*(LIP_H+0.4)
		else:
			var ang := _rng.randf()*TAU
			at = Vector3(cos(ang),0.0,sin(ang))*_rng.randf_range(0.0,1.8)+Vector3.UP*0.4
		var mi: MeshInstance3D = p.mi
		mi.position = at
		mi.visible = true
		p.t = 0.0
		p.life = life
		p.v = v if not from_scroll else v+at.normalized()*0.25
		p.size = size
		p.grow = grow
		p.a = a
		return

## A gulp's or a spit's puff: low, outward, all round.
func burst() -> void:
	for i in 12:
		var ang := _rng.randf()*TAU
		_puff(false,Vector3(cos(ang),0.0,sin(ang))*_rng.randf_range(1.2,2.4)+Vector3.UP*0.5,1.6,2.2,0.42,1.6)

func _process(delta: float) -> void:
	_clock += delta
	# The lip: toward its gape, a grinding shiver while it moves.
	var was := _gape_shown
	_gape_shown = move_toward(_gape_shown,gape,delta*3.0)
	var moving := absf(_gape_shown-was) > 0.0001
	var w := 1.0+0.07*_gape_shown
	_lips.scale = Vector3(w,1.0,w)
	_lips.position = Vector3(sin(_clock*53.0),0.0,sin(_clock*47.0))*(0.025 if moving or brewing else 0.0)
	_throat.scale = Vector3(w,1.0,w)
	# The mist: a slow breath while the belly holds anything; a column
	# while it is about to spit.
	var rate := 0.0
	if fullness > 0: rate += 0.35+0.35*float(fullness)
	if brewing: rate += 16.0
	_rate_debt += rate*delta
	while _rate_debt >= 1.0:
		_rate_debt -= 1.0
		if brewing: _puff(_rng.randf() < 0.5,Vector3(_rng.randf_range(-0.3,0.3),_rng.randf_range(1.6,2.6),_rng.randf_range(-0.3,0.3)),1.4,2.4,0.5,2.6)
		else: _puff(true,Vector3(0.0,0.35,0.0),0.9,1.6,0.22+0.05*float(mini(fullness,4)),3.6)
	for p: Dictionary in _puffs:
		if p.t >= p.life: continue
		p.t += delta
		var mi: MeshInstance3D = p.mi
		if p.t >= p.life:
			mi.visible = false
			continue
		var u: float = p.t/p.life
		# Curling out along the scrolls: the way turns as it rises.
		var v: Vector3 = p.v
		p.v = v.rotated(Vector3.UP,0.6*delta)*(1.0-0.25*delta)
		mi.position += v*delta
		var s: float = p.size*lerpf(1.0,p.grow,u)
		mi.scale = Vector3(s,s,s)
		mi.transparency = 1.0-float(p.a)*sin(PI*u)
