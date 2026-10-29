extends Node3D
## What a beat route (scripts/endless/beat_routes.gd) shows in the world:
## - a starter: a gilt ring standing over open land, a pale shaft of light
##   up out of it and a glow that keeps its size on screen, so it reads
##   from ~800 m. Flown through, it runs the route.
## - a beat: one bright orb, a thin shaft down to the land under it and a
##   glow; it flashes, faster as its time runs out (`flash`), and fades
##   when it is missed or taken.
## - the finish: an ember shaft on the strip's far end, its glow drawn over
##   the land so it stands on the horizon, and while the landing is the
##   beat, two rows of posts down the strip.
## All unshaded, additive and out of the fog: they are marks, not things.
## Built simply (a torus, spheres, cylinders and quads, a few hundred
## triangles each).

const STARTER := Color(1.0,0.86,0.5)
const BEAT := Color(1.0,0.93,0.66)
const FINISH := Color(1.0,0.52,0.24)
## The starter ring's radius (m) and its tube; the shaft's height and width.
const RING_R := 11.0
const RING_TUBE := 0.9
const SHAFT_TALL := 260.0
const SHAFT_R := 2.2
## The starter's shaft is wider than the finish's base (it is found from
## ~800 m, where 2.2 m is a hair), and a crown glow stands up it at
## CROWN_UP of its height, over the shoulders that hide the ring.
const STARTER_SHAFT_R := 4.5
const CROWN_UP := 0.85
const GLOW_CROWN := 0.065
## The beat's orb radius (m), its shaft's width.
const ORB_R := 2.2
const BEAT_SHAFT_R := 0.35
## The glow's size on screen (fixed-size quads: about a share of the view).
const GLOW_STARTER := 0.07
const GLOW_BEAT := 0.06
const GLOW_FINISH := 0.08
## In the preview pan each beat's glow is PAN_GLOW times its size, so the
## route reads from high over it.
const PAN_GLOW := 2.6
## Posts down the strip: every POST_EVERY m, POST_TALL m tall, POST_R
## wide at the foot; a glow (GLOW_POST) on each end post, so the strip's
## ends read from the final (~400 m).
const POST_EVERY := 30.0
const POST_TALL := 6.0
const POST_R := 0.4
const GLOW_POST := 0.022

var _glow_tex: Texture2D

## A starter: the ring, the shaft, the glow.
class Starter extends Node3D:
	var ring: MeshInstance3D
	var shaft: MeshInstance3D
	var glow: MeshInstance3D
	var crown: MeshInstance3D

## A beat or the finish: the orb (none for the finish), the shaft, the glow,
## and the finish's posts.
class Beat extends Node3D:
	var orb: MeshInstance3D
	var shaft: MeshInstance3D
	var glow: MeshInstance3D
	var posts: Node3D
	var mats: Array = []

func _init() -> void:
	name = "BeatMarks"
	var g := Gradient.new()
	g.set_color(0,Color(1,1,1,1))
	g.set_color(1,Color(1,1,1,0))
	g.add_point(0.18,Color(1,1,1,0.85))
	g.add_point(0.45,Color(1,1,1,0.22))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5,0.5)
	t.fill_to = Vector2(1.0,0.5)
	t.width = 64
	t.height = 64
	_glow_tex = t

static func _mat(col: Color, add := true, over := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if add: m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = col
	m.disable_fog = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = over
	return m

func _glow(col: Color, size: float, over := false) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = Vector2(size,size)
	var m := _mat(col,true,over)
	m.albedo_texture = _glow_tex
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.fixed_size = true
	if over: m.render_priority = 10
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func _shaft(col: Color, r: float, tall: float, a: float) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r*0.4
	c.bottom_radius = r
	c.height = tall
	c.radial_segments = 10
	c.rings = 1
	c.cap_top = false
	c.cap_bottom = false
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = _mat(Color(col.r,col.g,col.b,a))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## A starter at `at`, its ring facing `axis`; the land under it at `ground`.
func starter(at: Vector3, axis: Vector3, ground: float) -> Starter:
	var s := Starter.new()
	s.name = "Starter"
	add_child(s)
	s.global_position = at
	var tor := TorusMesh.new()
	tor.inner_radius = RING_R-RING_TUBE
	tor.outer_radius = RING_R+RING_TUBE
	tor.rings = 32
	tor.ring_segments = 8
	s.ring = MeshInstance3D.new()
	s.ring.mesh = tor
	s.ring.material_override = _mat(Color(STARTER.r,STARTER.g,STARTER.b,0.95),false)
	s.ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.add_child(s.ring)
	# The torus lies in XZ: stood up, facing `axis`.
	var a := Vector3(axis.x,0.0,axis.z).normalized()
	if a.length() < 0.5: a = Vector3.FORWARD
	s.ring.basis = Basis.looking_at(a,Vector3.UP)*Basis(Vector3.RIGHT,PI*0.5)
	# The shaft rises out of the land under it, through the ring.
	s.shaft = _shaft(STARTER,STARTER_SHAFT_R,SHAFT_TALL,0.26)
	s.add_child(s.shaft)
	s.shaft.position.y = ground-at.y+SHAFT_TALL*0.5
	s.glow = _glow(Color(STARTER.r,STARTER.g,STARTER.b,0.9),GLOW_STARTER)
	s.add_child(s.glow)
	s.crown = _glow(Color(STARTER.r,STARTER.g,STARTER.b,0.95),GLOW_CROWN)
	s.add_child(s.crown)
	s.crown.position.y = ground-at.y+SHAFT_TALL*CROWN_UP
	return s

## A beat at `at` over the land at `ground`.
func beat(at: Vector3, ground: float) -> Beat:
	var b := Beat.new()
	b.name = "Beat"
	add_child(b)
	b.global_position = at
	var sp := SphereMesh.new()
	sp.radius = ORB_R
	sp.height = ORB_R*2.0
	sp.radial_segments = 16
	sp.rings = 8
	b.orb = MeshInstance3D.new()
	b.orb.mesh = sp
	b.orb.material_override = _mat(Color(1.0,0.97,0.86,1.0),false)
	b.orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.add_child(b.orb)
	var tall := maxf(at.y-ground,2.0)+40.0
	b.shaft = _shaft(BEAT,BEAT_SHAFT_R,tall,0.35)
	b.add_child(b.shaft)
	b.shaft.position.y = ground-at.y+tall*0.5
	b.glow = _glow(Color(BEAT.r,BEAT.g,BEAT.b,0.95),GLOW_BEAT)
	b.add_child(b.glow)
	b.mats = [b.orb.material_override,b.shaft.material_override,b.glow.material_override]
	return b

## The finish on the strip: the shaft at `at` (on the ground), the posts
## down the lane from `from` to `to`, either side `across`, `wide` m apart.
func finish(at: Vector3, from: Vector3, to: Vector3, across: Vector3, wide: float, height: Callable) -> Beat:
	var b := Beat.new()
	b.name = "Finish"
	add_child(b)
	b.global_position = at
	b.shaft = _shaft(FINISH,SHAFT_R*1.3,SHAFT_TALL*1.25,0.22)
	b.add_child(b.shaft)
	b.shaft.position.y = SHAFT_TALL*1.25*0.5
	b.glow = _glow(Color(FINISH.r,FINISH.g,FINISH.b,0.95),GLOW_FINISH,true)
	b.add_child(b.glow)
	b.glow.position.y = 30.0
	b.mats = [b.shaft.material_override,b.glow.material_override]
	b.posts = Node3D.new()
	b.add_child(b.posts)
	var post_m := _mat(Color(FINISH.r,FINISH.g,FINISH.b,0.9),false)
	var post := CylinderMesh.new()
	post.top_radius = POST_R*0.7
	post.bottom_radius = POST_R
	post.height = POST_TALL
	post.radial_segments = 6
	post.rings = 1
	var len := from.distance_to(to)
	var way := (to-from).normalized()
	var n := maxi(int(len/POST_EVERY),1)
	for i in n+1:
		for k: float in [-0.5,0.5]:
			var p := from+way*(len*float(i)/float(n))+across*wide*k
			var mi := MeshInstance3D.new()
			mi.mesh = post
			mi.material_override = post_m
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			b.posts.add_child(mi)
			mi.global_position = Vector3(p.x,float(height.call(p.x,p.z))+POST_TALL*0.5,p.z)
			if i == 0 or i == n:
				var g := _glow(Color(FINISH.r,FINISH.g,FINISH.b,0.95),GLOW_POST)
				mi.add_child(g)
				g.position.y = POST_TALL*0.5
	b.posts.visible = false
	return b

## A beat's flash: `left` its share of time left (1 to 0), `clock` the run's
## time, `fade` from 1 to 0 as it goes. Faster and deeper as time runs out.
static func flash(b: Beat, left: float, clock: float, fade := 1.0) -> void:
	if b == null: return
	var late := 1.0-clampf(left,0.0,1.0)
	var rate := lerpf(1.0,7.0,pow(late,1.6))
	var pulse := 0.5+0.5*sin(clock*TAU*rate)
	var depth := lerpf(0.2,0.85,late)
	_alpha(b,(1.0-depth*pulse)*fade)
	if b.orb != null: b.orb.scale = Vector3.ONE*lerpf(0.9,1.2,pulse)*maxf(fade,0.05)
	b.visible = fade > 0.01

## `b`'s glow at its pan size (`on`) or its own.
static func pan_size(b: Beat, on: bool) -> void:
	if b == null or b.glow == null: return
	(b.glow.mesh as QuadMesh).size = Vector2.ONE*GLOW_BEAT*(PAN_GLOW if on else 1.0)

## All of `b`'s marks at alpha `a` (the shaft fainter); hidden at 0.
static func dim(b: Beat, a: float) -> void:
	if b == null: return
	_alpha(b,a)
	if b.orb != null: b.orb.scale = Vector3.ONE
	b.visible = a > 0.01

static func _alpha(b: Beat, a: float) -> void:
	for m: StandardMaterial3D in b.mats:
		var c: Color = m.albedo_color
		var share := 1.0
		if b.shaft != null and m == b.shaft.material_override: share = 0.3
		c.a = clampf(a,0.0,1.0)*share
		m.albedo_color = c
