extends Node3D
## What flies off when the plane meets the land or nearly does (scripts/
## endless/near_miss.gd, flight_contact.gd): small one-shot bursts of
## particles, each kind a pair of CPU emitters taken in turn.
## - dust: earth kicked up by a scrape on the land or a crash.
## - sparks: off stone (an arch, a hall, a bore's rock).
## - leaves: off a tree grazed or scraped, or knocked down (and where it lands).
## - needles: shed off a knocked tree's crown as it snaps and whips (from
##   a ball `sphere` m round, not a point; faded out `near` the eye).
## - wood: chips off a trunk the plane knocks down (scripts/endless/tree_knock.gd).
## - spray: off the water, as a burst on a scrape, and a running trail
##   (`spray`) while it skims the water low and fast.

const BodyDust = preload("res://scripts/breaks/body_dust.gd")
const CUTOUT = preload("res://shaders/flight_debris_cutout.gdshader")

## `soft`: the painted puff, not a flat square. `near` (m): gone, whole.
## `shape`: a drawn cut-out (leaf, sprig, chip), lit by the sun, in one of
## `tints`, spun up to `spin` deg/s; `flutter` flips it edge-on as it falls.
const KINDS := {
	"dust":{"color":Color(0.55,0.47,0.36),"amount":28,"size":0.55,"speed":Vector2(3.0,8.0),"gravity":-6.0,"life":1.1,"spread":55.0,"damp":2.0,"soft":true,"near":Vector2(2.0,7.0)},
	"sparks":{"color":Color(1.0,0.78,0.42),"amount":24,"size":0.12,"speed":Vector2(8.0,16.0),"gravity":-9.8,"life":0.45,"spread":70.0,"damp":0.5,"soft":true,"near":Vector2(1.5,5.0)},
	"leaves":{"amount":36,"size":0.34,"speed":Vector2(2.0,7.0),"gravity":-2.2,"life":2.2,"spread":80.0,"damp":2.6,"shape":"leaf","spin":220.0,"flutter":true,"near":Vector2(2.0,7.0),
		"tints":[Color(0.28,0.45,0.15),Color(0.36,0.55,0.18),Color(0.45,0.62,0.2),Color(0.32,0.5,0.16),Color(0.55,0.64,0.22),Color(0.66,0.6,0.26)]},
	"needles":{"amount":56,"size":0.32,"speed":Vector2(2.0,6.0),"gravity":-3.5,"life":2.0,"spread":80.0,"damp":1.8,"sphere":1.5,"pool":4,"shape":"sprig","spin":300.0,"flutter":true,"near":Vector2(2.0,7.0),
		"tints":[Color(0.18,0.3,0.12),Color(0.23,0.37,0.14),Color(0.28,0.42,0.15),Color(0.2,0.33,0.15),Color(0.36,0.4,0.18)]},
	"wood":{"amount":20,"size":0.26,"speed":Vector2(4.0,10.0),"gravity":-9.8,"life":1.4,"spread":60.0,"damp":1.0,"shape":"chip","spin":540.0,"near":Vector2(1.5,5.0),
		"tints":[Color(0.86,0.74,0.52),Color(0.78,0.64,0.42),Color(0.66,0.52,0.33),Color(0.42,0.3,0.2),Color(0.33,0.24,0.17)]},
	"spray":{"color":Color(0.88,0.94,0.97),"amount":30,"size":0.45,"speed":Vector2(3.0,9.0),"gravity":-9.0,"life":0.9,"spread":40.0,"damp":1.0,"soft":true,"near":Vector2(1.5,5.0)},
}
## A crash's burst is this many times a scrape's in size and speed.
const CRASH := 2.2

static var _cutouts := {}

var _pools := {}
var _turn := {}
var _trail: CPUParticles3D

func _ready() -> void:
	for kind: String in KINDS:
		var pool: Array = []
		for i in int((KINDS[kind] as Dictionary).get("pool",2)): pool.append(_emitter(KINDS[kind],true))
		_pools[kind] = pool
		_turn[kind] = 0
	_trail = _emitter(KINDS.spray,false)
	_trail.amount = 40
	_trail.lifetime = 0.7
	_trail.explosiveness = 0.0

func _emitter(k: Dictionary, one_shot: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.one_shot = one_shot
	p.emitting = false
	p.amount = int(k.amount)
	p.lifetime = float(k.life)
	p.explosiveness = 0.985
	p.local_coords = false
	p.direction = Vector3.UP
	p.spread = float(k.spread)
	if k.has("sphere"):
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = float(k.sphere)
	p.initial_velocity_min = (k.speed as Vector2).x
	p.initial_velocity_max = (k.speed as Vector2).y
	p.gravity = Vector3(0.0,float(k.gravity),0.0)
	p.damping_min = float(k.damp)
	p.damping_max = float(k.damp)*1.5
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.3
	p.angle_min = 0.0
	p.angle_max = 360.0
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE*float(k.size)
	quad.material = _cut_out(p,k) if k.has("shape") else _puff(p,k)
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(p)
	return p

## A painted puff or flat square, unlit, faded over its life.
func _puff(p: CPUParticles3D, k: Dictionary) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var fade := Gradient.new()
	fade.set_color(0,Color(1,1,1,1))
	fade.set_color(1,Color(1,1,1,0))
	p.color_ramp = fade
	p.color = k.color
	if k.has("soft"):
		m.albedo_texture = BodyDust._blob_texture()
	if k.has("near"):
		# Faded out this near the eye (m: gone, whole), so the camera flying
		# through a burst isn't filled with it.
		m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
		m.distance_fade_min_distance = (k.near as Vector2).x
		m.distance_fade_max_distance = (k.near as Vector2).y
	return m

## A lit cut-out: its picture, a tint each, a tumble, a flutter (flipped
## edge-on and back as it falls) and a shrink at the end instead of a fade.
func _cut_out(p: CPUParticles3D, k: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = CUTOUT
	m.set_shader_parameter("cutout",_cutout(str(k.shape)))
	# Sun through a leaf (a sprig less) when it's behind it; a chip is opaque.
	var through := {"leaf":Color(0.3,0.4,0.12),"sprig":Color(0.14,0.22,0.06)}
	m.set_shader_parameter("backlight_colour",through.get(str(k.shape),Color.BLACK))
	if k.has("near"): m.set_shader_parameter("near",k.near)
	p.color = Color.WHITE
	var tints := Gradient.new()
	tints.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var cols: Array = k.tints
	var offs := PackedFloat32Array()
	var pcs := PackedColorArray()
	for i in cols.size():
		offs.append(float(i)/cols.size())
		pcs.append(cols[i])
	tints.offsets = offs
	tints.colors = pcs
	p.color_initial_ramp = tints
	p.angular_velocity_min = -float(k.spin)
	p.angular_velocity_max = float(k.spin)
	p.lifetime_randomness = 0.45
	var end := Curve.new()
	end.add_point(Vector2(0.0,0.7))
	end.add_point(Vector2(0.08,1.0))
	end.add_point(Vector2(0.75,1.0))
	end.add_point(Vector2(1.0,0.0))
	if k.has("flutter"):
		var flip := Curve.new()
		var n := 24
		for i in n+1:
			var t := float(i)/n
			flip.add_point(Vector2(t,(0.15+0.85*absf(cos(t*TAU*2.5)))*end.sample(t)))
		p.split_scale = true
		p.scale_curve_x = flip
		p.scale_curve_y = end
		p.scale_curve_z = end
	else:
		p.scale_amount_curve = end
	return m

## The picture for a cut-out `shape`, white on clear (the tint colours it),
## drawn once.
static func _cutout(shape: String) -> Texture2D:
	if _cutouts.has(shape): return _cutouts[shape]
	var size := 64
	var noise := FastNoiseLite.new()
	noise.seed = 11
	noise.frequency = 0.08
	var img := Image.create(size,size,false,Image.FORMAT_RGBA8)
	for y in range(size):
		for x in range(size):
			# u: -1..1, y up.
			var u := (Vector2(x,size-1-y)+Vector2(0.5,0.5))/float(size)*2.0-Vector2.ONE
			var n := noise.get_noise_2d(x,y)
			var a := 0.0
			var tone := 1.0
			match shape:
				"leaf": # a pointed oval on a slant, with its midrib and a stalk
					var r := u.rotated(-0.5)
					var t := clampf((r.y+0.78)/1.68,0.0,1.0)
					var w := 0.44*pow(sin(t*PI),0.85)*(1.0-0.25*t)
					var inside := w-absf(r.x)
					if r.y < -0.78 or r.y > 0.9: inside = -1.0
					a = smoothstep(-0.02,0.03,inside)
					tone = 0.82+0.18*signf(r.x)*0.5+n*0.12
					tone *= lerpf(1.0,0.72,smoothstep(0.035,0.0,absf(r.x)))
					tone *= lerpf(0.8,1.0,smoothstep(0.0,0.1,inside))
					if r.y < -0.78 and r.y > -0.98 and absf(r.x) < 0.035:
						a = 1.0
						tone = 0.6
				"sprig": # a stalk with needles both sides, angled to the tip
					var sp := u.rotated(0.4)
					var d := _seg(sp,Vector2(0,-0.9),Vector2(0,0.85))
					for i in 8:
						var at := Vector2(0,-0.7+i*0.2)
						var len := 0.42*(1.0-i*0.06)
						d = minf(d,_seg(sp,at,at+Vector2(len,len*0.9)))
						d = minf(d,_seg(sp,at,at+Vector2(-len,len*0.9)))
					a = smoothstep(0.06,0.03,d)
					tone = 0.85+n*0.25
				"chip": # a splintered shard along its grain
					var c := u.rotated(0.6)
					var t := clampf((c.y+0.9)/1.8,0.0,1.0)
					var w := 0.26*pow(sin(t*PI),0.6)+n*0.07
					var inside := w-absf(c.x+0.05*sin(c.y*5.0))
					if absf(c.y) > 0.9: inside = -1.0
					a = smoothstep(-0.02,0.03,inside)
					tone = 0.82+0.18*sin(c.x*38.0+n*6.0)
			img.set_pixel(x,y,Color(tone,tone,tone,a))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cutouts[shape] = tex
	return tex

## Distance from `p` to the segment `a`-`b`.
static func _seg(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b-a
	var h := clampf((p-a).dot(ab)/ab.dot(ab),0.0,1.0)
	return (p-a-ab*h).length()

## A burst of `kind` at `at` thrown out along `normal`; `crash` a big one.
func burst(kind: String, at: Vector3, normal: Vector3, crash := false) -> void:
	if not _pools.has(kind): return
	var pool: Array = _pools[kind]
	var i: int = _turn[kind]
	_turn[kind] = (i+1)%pool.size()
	var p: CPUParticles3D = pool[i]
	var k: Dictionary = KINDS[kind]
	var big := CRASH if crash else 1.0
	p.initial_velocity_min = (k.speed as Vector2).x*big
	p.initial_velocity_max = (k.speed as Vector2).y*big
	p.scale_amount_max = 1.3*big
	p.global_position = at
	p.direction = normal if normal.length() > 0.1 else Vector3.UP
	p.restart()
	p.emitting = true

## The burst for a surface (land, water, tree, stone): dust, spray, leaves
## (and dust), sparks (and dust).
func hit(what: String, at: Vector3, normal: Vector3, crash := false) -> void:
	match what:
		"water": burst("spray",at,normal,crash)
		"tree":
			burst("leaves",at,normal,crash)
			if crash: burst("dust",at,normal,true)
		"stone":
			burst("sparks",at,normal,crash)
			burst("dust",at,normal,crash)
		_: burst("dust",at,normal,crash)

## The running spray at `at` (on the water under the plane), `on` or off.
func spray(on: bool, at: Vector3, way: Vector3) -> void:
	_trail.emitting = on
	if not on: return
	_trail.global_position = at
	_trail.direction = (Vector3.UP*1.5-way.normalized()).normalized()
