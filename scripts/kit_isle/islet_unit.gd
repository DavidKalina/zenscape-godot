class_name IsletUnit
extends RefCounted
## The islet unit (docs/design/isle-look/islet-unit-handoff.md): one floating
## rock chunk, the smallest piece an isle is composed of, in three parts.
##   Crown   the isles' own grass (KitFlora's carpet, wild at the rim, with
##           tussocks, seed heads and flowers) over the isles' own turf
##           ground (KitLook's), the top risen to a shoulder on one side and
##           a rise or two, rock knobs through it, now and then a dead tree
##           or a low shrub; a spire's shard stands up out of it.
##   Lip     the turf rolled out over the rock's edge and hanging down its
##           face as a heavy ragged hem of earth, torn grass draped under
##           it, the rock under it set back in shadow.
##   Body    one of five bodies (the shape knob): a broken tilted slab, a
##           squat boulder, a stepped cone with a lead drip, a shallow mass
##           with a cluster of deep hanging lobes, a tall leaning spire. Its
##           rock steps down in beds (a shelf at each bed), dead roots
##           trailing under it.
## Every part is drawn from the spec's seed and its knobs, so siblings vary
## and read as one family. Nothing here is shared with KitLand or the isles
## but KitFlora and KitLook, used as callers (the existing isles and motifs
## build as before).
##
##   IsletUnit.build(spec)        a Node3D: Rock, Ground (the turf top),
##                                Turf (the lip's earth), Drape, Flora,
##                                Roots, Growth (tree / shrub) and Body
##                                (collision, its turf on the isles' turf
##                                layer); its origin the turf's middle at
##                                the top
##   IsletUnit.sibling(seed, base) a spec with knobs drawn round `base`
## Round 3 (spec `style`, STYLES): the crag (scripts/kit_isle/islet_crag.gd,
## the default) builds the same knobs and bodies as broken, banded cliffs
## with a rock lip, fangs, a landmark and debris; `style` 0 is round 2's
## Unit below, unchanged.
##
## Knobs (spec keys; KNOBS gives each one's default and range):
##   seed      every draw
##   size      the top's radius (m): a hop boulder (1.5) to a landing slab (18)
##   shape     the body (BODIES, a fifth of the range each): 0 slab, 0.2
##             boulder, 0.4 cone, 0.6 cluster, 0.8..1 spire; within its
##             fifth, shallow to deep
##   lean      the body's lean off plumb under the top (a spire's most)
##   drip      0 many short drips .. 1 one deep drip (a cluster: more lobes
##             .. fewer, longer)
##   lopsided  how far the underside's mass sits off the middle
##   growth    0 bare .. 1 overgrown: the grass's thickness and how wild it
##             grows at the rim, the lip's reach and droop, drape, roots and
##             their length, a tree or shrub
##   weather   cracks, lichen, notches bitten out of the rim, rock knobs

const HangingRoots = preload("res://scripts/kit_isle/hanging_roots.gd")
const ROCK_SHADER := preload("res://shaders/islet_rock.gdshader")
const TURF_SHADER := preload("res://shaders/islet_turf.gdshader")

## Each knob: [default, least, most].
const KNOBS := {
	"size":[6.0,1.5,18.0],
	"shape":[0.45,0.0,1.0],
	"lean":[0.25,0.0,1.0],
	"drip":[0.5,0.0,1.0],
	"lopsided":[0.45,0.0,1.0],
	"growth":[0.6,0.0,1.0],
	"weather":[0.55,0.0,1.0],
}
## The bodies, in the shape knob's order.
const BODIES := ["slab","boulder","cone","cluster","spire"]
enum {SLAB,BOULDER,CONE,CLUSTER,SPIRE}
## The isles' turf layer (studies/kit_isle.gd TURF_LAYER) and their solid.
const TURF_LAYER := 1 << 11
const SOLID_LAYER := 1

## The palette (sRGB): dusty and faded.
const BARK := Color("8a7f72")
const BARK_DARK := Color("4f463d")
const ROOT_TINT := Color(1.85,1.8,1.7)
const SHRUB := Color("6f8a52")
const SHRUB_DARK := Color("3f5230")

## The grass: the aqueduct isle's carpet (studies/aqueduct_isle_flora.gd
## `carpeted`), its thickness times GRASS_THICK (bare .. overgrown) and its
## wild rim's height times GRASS_SHAG; it grows out onto the lip's roll
## (the spill) past the rim.
const GRASS_THICK := Vector2(0.3,1.0)
const GRASS_SHAG := Vector2(0.8,1.9)
## The drape's grass (sRGB): the carpet's golden tips and olive blades as
## they render under the game's sun.
const DRAPE_GOLD := Color("c99a4c")
const DRAPE_OLIVE := Color("8a8a40")
const DRAPE_DARK := Color("6b5a2e")
## Below this growth the crown is bare turf.
const GRASS_FROM := 0.06

## A full spec from `spec`: missing knobs at their defaults, all clamped.
static func knobs_of(spec: Dictionary) -> Dictionary:
	var out := {"seed":int(spec.get("seed",1))}
	for k: String in KNOBS:
		var r: Array = KNOBS[k]
		out[k] = clampf(float(spec.get(k,r[0])),float(r[1]),float(r[2]))
	# Round 3's keys (the crag style, scripts/kit_isle/islet_crag.gd): the
	# style (STYLES), the landmark (-1 drawn, 0 none, 1 tree, 2 ruin),
	# whether the grass grows (0 bare turf, for far units), the debris's
	# amount.
	out.style = clampi(int(spec.get("style",CRAG)),0,STYLES.size()-1)
	out.landmark = clampi(int(spec.get("landmark",-1)),-1,2)
	out.grass = clampf(float(spec.get("grass",1.0)),0.0,1.0)
	out.debris = clampf(float(spec.get("debris",1.0)),0.0,2.0)
	return out

## The styles: round 2's plates of rock under a sod lip, round 3's crag.
const STYLES := ["r2","crag"]
const R2 := 0
const CRAG := 1
const CRAG_SHADER := preload("res://shaders/islet_crag.gdshader")

## The crag's rock material (shaders/islet_crag.gdshader).
static func crag_material(rng: RandomNumberGenerator, weather: float, radius: float, bottom: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = CRAG_SHADER
	mat.set_shader_parameter("top_y",0.0)
	mat.set_shader_parameter("bottom_y",bottom)
	mat.set_shader_parameter("weather",weather)
	mat.set_shader_parameter("seed_off",Vector3(rng.randf_range(-50,50),rng.randf_range(-50,50),rng.randf_range(-50,50)))
	mat.set_shader_parameter("bed_scale",1.0/clampf(radius*0.09,0.35,1.4))
	mat.set_shader_parameter("band_m",clampf(radius*0.13,0.5,2.2))
	return mat

## The body a shape knob gives (SLAB .. SPIRE) and how deep within it (0..1).
static func body_of(shape: float) -> Vector2:
	var t := clampi(int(shape*5.0),0,4)
	return Vector2(t,clampf(shape*5.0-t,0.0,1.0))

## A sibling's spec: each knob drawn from `seed` round `base`'s (the
## family's middle), so siblings differ and still belong together.
static func sibling(seed_value: int, base := {}) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["islet_sibling",seed_value])
	var b := knobs_of(base)
	var out := {"seed":seed_value}
	out.size = clampf(float(b.size)*exp(rng.randf_range(-0.9,0.5)),1.5,18.0)
	for k: String in ["shape","lean","drip","lopsided","growth","weather"]:
		# Wide draws on the shape knobs: one family, varied silhouettes.
		var spread := 0.6 if k in ["shape","drip","lopsided"] else 0.4
		out[k] = clampf(float(b[k])+rng.randf_range(-spread,spread),0.0,1.0)
	return out

# --- Noise ------------------------------------------------------------------------------

static func _noise(seed_value: int, freq: float, octaves := 3) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_octaves = octaves
	return n

## A loop of noise round the circle at angle `a` (periodic).
static func _ring(n: FastNoiseLite, a: float, r: float, salt := 0.0) -> float:
	return n.get_noise_3d(cos(a)*r,sin(a)*r,salt)

# --- The build --------------------------------------------------------------------------

## The unit, its origin the middle of its turf's top.
static func build(spec: Dictionary) -> Node3D:
	var k := knobs_of(spec)
	if int(k.style) == CRAG:
		var crag: Object = load("res://scripts/kit_isle/islet_crag.gd").new(k)
		return crag.make()
	var u := Unit.new(k)
	return u.make()

class Unit:
	var k: Dictionary
	var seed_value: int
	var rng := RandomNumberGenerator.new()
	var R: float
	var depth: float
	var segs: int
	var body := CONE
	var deep_in := 0.5
	var radii: PackedFloat32Array = PackedFloat32Array()
	var hum: FastNoiseLite
	var lump: FastNoiseLite
	## The body's rings: [y, scale, centre (Vector2), kind, bed].
	var rings: Array = []
	var lean_dir := Vector2.ZERO
	var lean := 0.1
	var lip_reach := 0.3
	var lip_droop := 0.5
	var root_list: Array = []
	var collide := PackedVector3Array()
	var stats := {}
	## The crown: a shoulder risen on one side, rises, the rim's turf height
	## a segment (the body's top follows it), what keeps the grass off
	## (Vector3: x, z, radius), the lip's crest and roll a segment ([radius,
	## y] each).
	var shoulder_dir := Vector2.RIGHT
	var shoulder_h := 0.0
	var rises: Array = []
	var rim_lift: PackedFloat32Array = PackedFloat32Array()
	var keep_out: Array = []
	var crest: Array = []
	var roll: Array = []
	## The slab's wedge: its underside this much deeper toward wedge_dir.
	var wedge := 0.0
	var wedge_dir := Vector2.RIGHT
	## The whole unit's tilt (radians) about tilt_axis.
	var tilt := 0.0
	var tilt_axis := Vector3.RIGHT

	func _init(knobs: Dictionary) -> void:
		k = knobs
		seed_value = int(k.seed)
		rng.seed = hash(["islet_unit",seed_value])
		R = float(k.size)
		var bd := IsletUnit.body_of(float(k.shape))
		body = int(bd.x)
		deep_in = bd.y
		# Small rocks run deeper for their size (a boulder is round), big
		# slabs shallower.
		var small := clampf(1.0-(R-1.5)/10.0,0.0,1.0)
		match body:
			SLAB: depth = R*(0.75+0.4*deep_in+0.3*small)
			BOULDER: depth = R*(1.2+0.35*deep_in+0.2*small)
			CONE: depth = R*(1.3+0.7*deep_in+0.35*small)
			CLUSTER: depth = R*(1.7+0.9*deep_in+0.3*small)
			SPIRE: depth = R*(2.2+1.2*deep_in+0.3*small)
		segs = clampi(int(R*7.0),28,96)
		hum = IsletUnit._noise(seed_value*7+1,0.11/maxf(R/6.0,0.4))
		lump = IsletUnit._noise(seed_value*7+2,0.35/maxf(R/6.0,0.5),4)
		var a := rng.randf()*TAU
		lean_dir = Vector2(cos(a),sin(a))
		lean = float(k.lean)*(0.5 if body == SPIRE else 0.4)+(0.35 if body == SPIRE else 0.0)
		var g := float(k.growth)
		lip_reach = clampf(R*0.05,0.25,0.9)*(0.6+0.8*g)
		lip_droop = clampf(R*0.075,0.35,1.3)*(0.6+0.8*g)
		match body:
			SLAB: tilt = rng.randf_range(0.2,0.34)
			SPIRE: tilt = rng.randf_range(0.15,0.3)
			_: tilt = rng.randf_range(0.0,0.06)
		var ta := rng.randf()*TAU
		tilt_axis = Vector3(cos(ta),0.0,sin(ta))
		wedge = rng.randf_range(0.6,0.9) if body == SLAB else 0.0
		wedge_dir = Vector2.from_angle(rng.randf()*TAU)
		_outline()
		_crown_shape()

	## The top's outline: radius a segment, lobed, stretched for a slab or
	## a spire's blade, cut straight on a broken slab, bitten by weathering.
	func _outline() -> void:
		var lobes := IsletUnit._noise(seed_value*7+3,0.9,2)
		var stretch := 1.0+rng.randf_range(0.0,0.45)
		match body:
			SLAB: stretch = rng.randf_range(1.35,1.8)
			SPIRE: stretch = rng.randf_range(1.5,2.1)
			BOULDER: stretch = rng.randf_range(1.0,1.2)
		var turn := rng.randf()*TAU
		var bites: Array = []
		for i in rng.randi_range(1,3)+int(float(k.weather)*3.0):
			bites.append([rng.randf()*TAU,rng.randf_range(0.12,0.3),rng.randf_range(0.06,0.16)*float(k.weather)])
		# A broken slab: one or two straight breaks across it.
		var cuts: Array = []
		if body == SLAB:
			for c in rng.randi_range(1,2):
				cuts.append([rng.randf()*TAU,rng.randf_range(0.55,0.75)])
		radii.resize(segs)
		for j in segs:
			var a := TAU*j/segs
			var r := 1.0+0.22*IsletUnit._ring(lobes,a,1.0)+0.06*IsletUnit._ring(lobes,a,3.5,9.0)
			var c := cos(a-turn)
			r *= lerpf(1.0,stretch,c*c)/sqrt(stretch)
			for b: Array in bites:
				var d := absf(wrapf(a-float(b[0]),-PI,PI))
				if d < float(b[1]): r -= float(b[2])*(0.5+0.5*cos(PI*d/float(b[1])))
			for cut: Array in cuts:
				var off := cos(a-float(cut[0]))
				if off > 0.05: r = minf(r,float(cut[1])/off)
			radii[j] = R*r

	## The crown's shape: a shoulder risen on one side, a rise or two, and
	## the rim's turf height a segment.
	func _crown_shape() -> void:
		shoulder_dir = Vector2.from_angle(rng.randf()*TAU)
		shoulder_h = R*rng.randf_range(0.09,0.2)*(0.5 if body == SLAB else 1.0)
		for i in rng.randi_range(1,2)+(1 if R > 8.0 else 0):
			var at := Vector2.from_angle(rng.randf()*TAU)*R*rng.randf_range(0.1,0.6)
			rises.append([at,R*rng.randf_range(0.04,0.1),R*rng.randf_range(0.2,0.38)])
		rim_lift.resize(segs)
		for j in segs:
			var p := dir(j)*rim(j)
			rim_lift[j] = top_y(p,1.0)

	func rim(j: int) -> float:
		return radii[posmod(j,segs)]

	func dir(j: int) -> Vector2:
		var a := TAU*j/segs
		return Vector2(cos(a),sin(a))

	## The rim's radius at angle `a`, between segments.
	func rim_at(a: float) -> float:
		var f := wrapf(a,0.0,TAU)/TAU*segs
		var j := int(f)
		return lerpf(rim(j),rim(j+1),f-j)

	## The turf's height over (x, z): low hummocks, a little dome (a
	## boulder's more), the shoulder, the rises.
	func top_y(p: Vector2, u: float) -> float:
		var y := R*0.035*hum.get_noise_2d(p.x,p.y)+R*(0.07 if body == BOULDER else 0.03)*(1.0-u*u)
		y += shoulder_h*smoothstep(-0.25,0.9,p.dot(shoulder_dir)/R)
		for r: Array in rises:
			var d2 := p.distance_squared_to(r[0])
			y += float(r[1])*exp(-d2/(float(r[2])*float(r[2])))
		return y

	## The ground's height under (x, z) for the grass, out over the lip's
	## crest to its roll, or NAN off it.
	func ground_at(p: Vector2) -> float:
		var a := p.angle()
		var r := rim_at(a)
		var l := p.length()
		if l <= r: return top_y(p,l/maxf(r,0.01))
		var f := wrapf(a,0.0,TAU)/TAU*segs
		var j := int(f)%segs
		var t := f-int(f)
		var c0: Array = crest[j]
		var c1: Array = crest[(j+1)%segs]
		var o0: Array = roll[j]
		var o1: Array = roll[(j+1)%segs]
		var cr := lerpf(float(c0[0]),float(c1[0]),t)
		var cy := lerpf(float(c0[1]),float(c1[1]),t)
		var y0 := lerpf(rim_lift[j],rim_lift[(j+1)%segs],t)
		if l <= cr: return lerpf(y0,cy,(l-r)/maxf(cr-r,0.01))
		var orr := lerpf(float(o0[0]),float(o1[0]),t)
		var oy := lerpf(float(o0[1]),float(o1[1]),t)
		if l <= orr: return lerpf(cy,oy,(l-cr)/maxf(orr-cr,0.01))
		return NAN

	## KitFlora's probe (Site `probe`): the turf's height under p, or NAN
	## where it isn't open turf (off the lip's roll, in a knob's or the
	## shard's foot, or, in from the rim, too steep within `reach`).
	func probe(p: Vector2, reach: float) -> float:
		var h := ground_at(p)
		if is_nan(h): return NAN
		for ko: Vector3 in keep_out:
			if p.distance_to(Vector2(ko.x,ko.y)) < ko.z: return NAN
		if reach <= 0.0 or p.length() > rim_at(p.angle()): return h
		var steep: float = float(KitLook.palette().rock_slope)*KitFlora.STEEP_SHARE
		for off: Vector2 in [Vector2(reach,0.0),Vector2(-reach,0.0),Vector2(0.0,reach),Vector2(0.0,-reach)]:
			var q := ground_at(p+off)
			if is_nan(q) or absf(q-h)/reach > steep: return NAN
		return h

	func make() -> Node3D:
		var root := Node3D.new()
		root.name = "IsletUnit"
		root.set_meta("knobs",k.duplicate())
		root.set_meta("body",IsletUnit.BODIES[body])
		_body_rings()
		var rock := _rock_mesh()
		root.add_child(rock)
		_turf_mesh(root)
		var drape := _drape_mesh()
		if drape != null: root.add_child(drape)
		_crown(root)
		_roots(root)
		var b := StaticBody3D.new()
		b.name = "Body"
		b.collision_layer = SOLID_LAYER | TURF_LAYER
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(collide)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		b.add_child(cs)
		root.add_child(b)
		# The whole unit tilted (a slab's break; a little on the others).
		if tilt > 0.0:
			var t := Transform3D(Basis(tilt_axis,tilt),Vector3.ZERO)
			for c: Node in root.get_children():
				if c is Node3D: (c as Node3D).transform = t*(c as Node3D).transform
		var outline: Array = []
		for j in segs: outline.append(dir(j)*rim(j))
		root.set_meta("outline",outline)
		root.set_meta("depth",depth)
		var tris := 0
		for mi: Node in root.find_children("*","MeshInstance3D",true,false):
			var m := (mi as MeshInstance3D).mesh
			for s in m.get_surface_count(): tris += m.surface_get_array_index_len(s)/3 if m.surface_get_format(s) & Mesh.ARRAY_FORMAT_INDEX else m.surface_get_array_len(s)/3
		stats.triangles = tris
		stats.body = IsletUnit.BODIES[body]
		root.set_meta("stats",stats)
		return root

	# --- Body -------------------------------------------------------------------------

	## The envelope: the body's scale at t (0 under the lip .. 1 its foot).
	func _envelope(t: float, bottom: float) -> float:
		match body:
			SLAB: return lerpf(0.9,bottom,pow(t,2.0))
			BOULDER:
				if t < 0.4: return lerpf(0.86,1.18,sin(t/0.4*PI*0.5))
				return lerpf(1.18,bottom,pow((t-0.4)/0.6,1.8))
			CLUSTER: return lerpf(0.9,bottom,pow(t,1.3))
			SPIRE: return lerpf(0.88,bottom,pow(t,1.7))
		return lerpf(0.9,bottom,pow(t,lerpf(1.7,1.0,deep_in)))

	## The main mass: rings down from just under the lip (set back in its
	## shadow), then beds stacked like plates under the body's envelope:
	## each bed's top stands out a little past the foot of the bed over it
	## (an up-facing ledge, where lichen takes) and its face cuts back under
	## as it goes down (an undercut, in shade). Under the last bed a cap,
	## off the middle (lopsided), the drips hang from. Its centre leans as
	## it goes. Ring: [y, scale, centre, kind, bed] (kind: 0 face, 1 ledge
	## top, 2 undercut foot, 3 top band).
	func _body_rings() -> void:
		var share := 0.45
		match body:
			SLAB: share = 0.88
			BOULDER: share = 0.85
			CONE: share = lerpf(0.38,0.5,deep_in)
			CLUSTER: share = rng.randf_range(0.28,0.36)
			SPIRE: share = 0.8
		mass = depth*share
		var beds := clampi(2+int(rng.randf_range(0.0,1.6)+deep_in*2.0+R/9.0),2,6)
		if body == SPIRE: beds = clampi(beds+2,4,8)
		if body == SLAB: beds = clampi(beds-1,2,3)
		lop_dir = Vector2.from_angle(rng.randf()*TAU)
		var lop := lop_dir*R*0.3*float(k.lopsided)
		match body:
			SLAB: bottom_sc = rng.randf_range(0.35,0.5)
			BOULDER: bottom_sc = rng.randf_range(0.25,0.35)
			CLUSTER: bottom_sc = rng.randf_range(0.66,0.78)
			SPIRE: bottom_sc = rng.randf_range(0.22,0.32)
			_: bottom_sc = lerpf(0.45,0.32,deep_in)*rng.randf_range(0.85,1.1)
		rings.append([-0.02,0.9,Vector2.ZERO,3,-1])
		rings.append([-lip_droop*0.85,0.84,Vector2.ZERO,3,-1])
		var weights: Array = []
		var total := 0.0
		for b in beds:
			var w := rng.randf_range(0.5,1.6)*(1.4 if b == 0 else 1.0)
			weights.append(w)
			total += w
		var span := mass-lip_droop
		var y := -lip_droop*0.9
		var t := 0.0
		for b in beds:
			var face := span*float(weights[b])/total
			var t1 := t+float(weights[b])/total
			var e0 := _envelope(t,bottom_sc)
			var e1 := _envelope(t1,bottom_sc)
			var c0 := lop*t+lean_dir*lean*(-y)
			var c1 := lop*t1+lean_dir*lean*(-(y-face))
			var under := rng.randf_range(0.05,0.13)*(0.6+0.8*float(k.weather))
			if b > 0:
				# The ledge: this bed's top out past the last one's foot.
				rings.append([y-face*0.03,e0*rng.randf_range(0.99,1.03),c0,1,b])
			rings.append([y-face*0.45,_envelope(lerpf(t,t1,0.45),bottom_sc)*rng.randf_range(0.98,1.02),c0.lerp(c1,0.45),0,b])
			y -= face
			rings.append([y,e1*(1.0-under),c1,2,b])
			bed_faces.append(face)
			t = t1
		var tip := lop+lean_dir*lean*mass
		match body:
			SPIRE:
				rings.append([y-R*0.2,bottom_sc*0.4,tip+lean_dir*lean*R*0.2,0,-1])
				rings.append([y-R*0.35,0.0,tip+lean_dir*lean*R*0.35,0,-1])
			CLUSTER:
				# A broad, nearly flat underside the lobes hang from.
				rings.append([y-R*0.04,bottom_sc*0.7,tip.lerp(Vector2.ZERO,0.2),0,-1])
				rings.append([y-R*0.07,0.0,tip,0,-1])
			BOULDER:
				rings.append([y-R*0.08,bottom_sc*0.6,tip,0,-1])
				rings.append([y-R*0.12,0.0,tip,0,-1])
			_:
				rings.append([y-R*0.05,bottom_sc*0.55,tip.lerp(Vector2.ZERO,0.2),0,-1])
				rings.append([y-R*0.09,0.0,tip,0,-1])
		stats.beds = beds

	var mass := 1.0
	var lop_dir := Vector2.RIGHT
	var bottom_sc := 0.5
	var bed_faces: Array = []

	## How much deeper the slab's wedge runs under direction `d`.
	func _wedge(d: Vector2) -> float:
		return 1.0+wedge*d.dot(wedge_dir)

	## The body's surface at ring `i`, segment `j` (land-local), with lumps
	## (small under the lip, so the rock stays set back under it).
	func body_point(i: int, j: int) -> Vector3:
		var ring: Array = rings[i]
		var sc := float(ring[1])
		var c: Vector2 = ring[2]
		var d := dir(j)
		var y := float(ring[0])
		if int(ring[3]) != 3: y = -lip_droop*0.9+(y+lip_droop*0.9)*_wedge(d)
		# Lopsided: under one side the mass hangs further out, deeper down.
		var deep := clampf(-y/maxf(mass,0.01),0.0,1.0)
		var lean_out := 1.0+0.55*float(k.lopsided)*d.dot(lop_dir)*deep
		var p := c+d*rim(j)*sc*lean_out
		var amp := minf(R*0.07,0.7)*(0.3+0.7*minf(sc,1.0))*(0.25 if int(ring[3]) == 3 else 1.0)
		var n := lump.get_noise_3d(p.x,y*1.6,p.y)
		p += d*n*amp
		y += lump.get_noise_3d(p.x+31.0,y,p.y-17.0)*amp*0.25
		# Blocks: each bed cut round into blocks, each set in or out and its
		# ledge and foot a little up or down, so the joints step.
		var bed := int(ring[4])
		if bed >= 0:
			var blocks := 5+int(hash([seed_value,bed,"n"]))%6
			var blk := int(float(j)*blocks/segs)
			var h1 := float(hash([seed_value,bed,blk]) % 1000)/1000.0
			var h2 := float(hash([seed_value,bed,blk,"y"]) % 1000)/1000.0
			p += d*(h1*2.0-1.0)*minf(R*0.04,0.45)*(0.6+float(k.weather))
			if int(ring[3]) != 0: y += (h2-0.5)*float(bed_faces[bed])*0.22
		# The top follows the rim's turf (its shoulder, its rises), fading
		# out down the first bed.
		y += rim_lift[posmod(j,segs)]*(1.0-smoothstep(0.0,0.35,deep))
		# The top band tucks under the turf wherever its hummocks dip.
		if i == 0: y = minf(y,top_y(p,clampf(p.length()/maxf(rim(j),0.01),0.0,1.0))-0.12)
		return Vector3(p.x,y,p.y)

	func _rock_mesh() -> MeshInstance3D:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var grid: Array = []
		for i in rings.size():
			var row: Array = []
			for j in segs: row.append(body_point(i,j))
			grid.append(row)
		var bottom := float(rings[-1][0])
		for i in rings.size()-1:
			# Occlusion baked as the vertex colour's red: the band right under
			# the lip in its shadow, a shelf's under-face, the deeper the darker.
			var ao_a := _ring_ao(i)
			var ao_b := _ring_ao(i+1)
			for j in segs:
				var a: Vector3 = grid[i][j]
				var b: Vector3 = grid[i][(j+1)%segs]
				var c: Vector3 = grid[i+1][(j+1)%segs]
				var d: Vector3 = grid[i+1][j]
				_quad(st,a,b,c,d,Color(ao_a,0,0),Color(ao_a,0,0),Color(ao_b,0,0),Color(ao_b,0,0))
		_drips(st)
		st.index()
		st.generate_normals()
		var mesh := st.commit()
		# The knobs through the turf and a spire's shard, faceted (flat
		# normals: angular stone).
		var knobs := SurfaceTool.new()
		knobs.begin(Mesh.PRIMITIVE_TRIANGLES)
		var top := _knobs_on_top(knobs)
		if _shard(knobs): top = maxf(top,1.0)
		if not keep_out.is_empty():
			knobs.generate_normals()
			knobs.commit(mesh)
		var mi := MeshInstance3D.new()
		mi.name = "Rock"
		mi.mesh = mesh
		var mat := ShaderMaterial.new()
		mat.shader = IsletUnit.ROCK_SHADER
		mat.set_shader_parameter("top_y",0.0)
		mat.set_shader_parameter("bottom_y",minf(bottom*(1.0+wedge),-depth))
		mat.set_shader_parameter("weather",float(k.weather))
		mat.set_shader_parameter("seed_off",Vector3(rng.randf_range(-50,50),rng.randf_range(-50,50),rng.randf_range(-50,50)))
		mat.set_shader_parameter("bed_scale",1.0/clampf(R*0.09,0.35,1.4))
		mi.material_override = mat
		return mi

	## The highest rock over the turf (the shard's tip), for the shader's
	## value gradient.
	var top_peak := 0.0

	func _ring_ao(i: int) -> float:
		if i == 0: return 0.15
		if i == 1: return 0.35
		match int(rings[i][3]):
			1: return 1.0
			2: return 0.5
		return 0.85

	func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
		for v: Array in [[a,ca],[c,cc],[b,cb],[a,ca],[d,cd],[c,cc]]:
			st.set_color(v[1])
			st.add_vertex(v[0])
		collide.append_array(PackedVector3Array([a,c,b,a,d,c]))

	## The underside's drips by body: a cone's lead drip and short ones; a
	## cluster's several deep lobes, each its own stepped drip, of varied
	## length, spread over its broad underside; a slab's few short ones
	## along its deep edge; a boulder's stubs; a spire's fine tip. And a
	## few short ones off the beds' undercut feet (fewer with drip).
	func _drips(st: SurfaceTool) -> void:
		var drip := float(k.drip)
		var foot: Array = rings[rings.size()-3]
		var foot_y := float(foot[0])
		var foot_c: Vector2 = foot[2]
		var tip: Vector2 = rings[-1][2]
		var below := depth-mass
		var out := 0
		match body:
			CLUSTER:
				var lobes := clampi(int(round(lerpf(6.0,3.0,drip)+rng.randf_range(-0.6,0.6)+R/12.0)),3,7)
				var spots: Array = []
				var turn := rng.randf()*TAU
				for i in lobes:
					# Spread: golden-angle round the cap, the lead off the middle.
					var r_at := R*bottom_sc*(0.12 if i == 0 else lerpf(0.4,0.78,sqrt(float(i)/lobes)))
					var at := foot_c+Vector2.from_angle(turn+i*2.39996)*r_at
					spots.append(at)
					var r0 := R*(rng.randf_range(0.2,0.28) if i == 0 else rng.randf_range(0.11,0.22))
					var long_ := below*(rng.randf_range(0.9,1.15) if i == 0 else rng.randf_range(0.3,0.85)*lerpf(1.0,0.75,drip))
					long_ = maxf(long_,r0*2.2)
					var bend := Vector2.from_angle(rng.randf()*TAU)*long_*rng.randf_range(0.04,0.14)+(at-foot_c).normalized()*long_*0.12+lean_dir*lean*0.3*long_
					_drip(st,Vector3(at.x,foot_y+r0*0.6,at.y),r0,long_+r0*0.6,bend)
					out += 1
				# Small ones between the lobes.
				for i in rng.randi_range(2,4):
					var at := foot_c+Vector2.from_angle(rng.randf()*TAU)*R*bottom_sc*rng.randf_range(0.3,0.85)
					var r0 := R*rng.randf_range(0.05,0.09)
					_drip(st,Vector3(at.x,foot_y+r0*0.5,at.y),r0,below*rng.randf_range(0.12,0.3),Vector2.from_angle(rng.randf()*TAU)*r0)
					out += 1
			SLAB, BOULDER:
				var n := rng.randi_range(1,3) if body == SLAB else rng.randi_range(0,2)
				for i in n:
					var a := wedge_dir.angle()+rng.randf_range(-0.9,0.9) if body == SLAB else rng.randf()*TAU
					var at := foot_c+Vector2.from_angle(a)*R*bottom_sc*rng.randf_range(0.2,0.6)
					var r0 := R*rng.randf_range(0.08,0.16)
					var y0 := -lip_droop*0.9+(foot_y+lip_droop*0.9)*_wedge(Vector2.from_angle(a))
					var long_ := maxf(depth*rng.randf_range(0.25,0.6),r0*2.0)
					_drip(st,Vector3(at.x,y0+r0*0.5,at.y),r0,long_,Vector2.from_angle(rng.randf()*TAU)*long_*0.1)
					out += 1
			SPIRE:
				var r0 := R*bottom_sc*0.35
				var t0: Vector2 = rings[-2][2]
				_drip(st,Vector3(t0.x,float(rings[-2][0])+r0*0.5,t0.y),r0,R*rng.randf_range(0.4,0.8),lean_dir*lean*R*0.4)
				out += 1
			_:
				var count := clampi(int(round(lerpf(6.0,2.0,drip)+rng.randf_range(-1.0,1.0)+R/10.0)),1,9)
				for i in count:
					var lead := i == 0
					var at: Vector2
					var r0: float
					var long_: float
					if lead:
						at = tip+Vector2.from_angle(rng.randf()*TAU)*R*0.04
						r0 = R*bottom_sc*lerpf(0.42,0.6,drip)
						long_ = below*lerpf(0.75,1.2,drip)*rng.randf_range(0.9,1.1)
					else:
						at = foot_c+Vector2.from_angle(rng.randf()*TAU)*R*bottom_sc*rng.randf_range(0.2,0.8)
						r0 = R*rng.randf_range(0.07,0.18)*lerpf(1.2,0.8,drip)
						long_ = below*rng.randf_range(0.15,lerpf(0.85,0.35,drip))
					long_ = maxf(long_,r0*1.6)
					var bend := Vector2.from_angle(rng.randf()*TAU)*long_*rng.randf_range(0.04,0.18)+lean_dir*lean*0.6*long_
					_drip(st,Vector3(at.x,foot_y+r0*0.5,at.y),r0,long_+r0*0.5,bend)
					out += 1
		# Off the beds' feet, round the sides.
		var side_n := int(rng.randf_range(0.0,4.0)*(1.1-drip)*clampf(R/6.0,0.5,1.6))
		var feet: Array = []
		for i in range(2,rings.size()-3):
			if int(rings[i][3]) == 2: feet.append(i)
		for n in side_n:
			if feet.is_empty(): break
			var fi: int = feet[rng.randi()%feet.size()]
			var j := rng.randi()%segs
			var p := body_point(fi,j)
			var c: Vector2 = rings[fi][2]
			var at := c.lerp(Vector2(p.x,p.z),0.86)
			var r0 := R*rng.randf_range(0.04,0.1)
			var long_ := r0*rng.randf_range(2.0,5.5)
			_drip(st,Vector3(at.x,p.y+r0*0.4,at.y),r0,long_,Vector2.from_angle(rng.randf()*TAU)*long_*0.1)
			out += 1
		stats.drips = out

	## A drip: rings down from `top`, radius r0 narrowing to a point,
	## stepping in at its beds, its tip `bend` off plumb.
	func _drip(st: SurfaceTool, top: Vector3, r0: float, long_: float, bend: Vector2) -> void:
		var sides := clampi(int(r0*10.0),7,16)
		var steps := clampi(int(long_/maxf(r0*0.6,0.4)),4,14)
		var phase := rng.randf()*TAU
		var wob := rng.randf_range(0.15,0.3)
		var rows: Array = []
		var aos: Array = []
		var r := r0
		for s in steps+1:
			var t := float(s)/steps
			var want := r0*pow(1.0-t,0.85)
			# A step in now and then: a little shelf.
			if s > 0 and s < steps and rng.randf() < 0.35:
				var y0 := top.y-long_*t
				var cc := Vector2(top.x,top.z)+bend*t*t
				rows.append(_drip_ring(cc,y0,r,sides,phase,wob))
				aos.append(0.8)
				r = maxf(want*0.82,0.0)
				rows.append(_drip_ring(cc,y0-long_*0.012,r,sides,phase,wob))
				aos.append(0.95)
				continue
			r = want
			var c := Vector2(top.x,top.z)+bend*t*t
			rows.append(_drip_ring(c,top.y-long_*t,r,sides,phase,wob))
			# Where it leaves the mass: in its crease.
			aos.append(0.35 if s == 0 else (0.6 if s == 1 else 0.82))
		for s in rows.size()-1:
			for j in sides:
				var a: Vector3 = rows[s][j]
				var b: Vector3 = rows[s][(j+1)%sides]
				var c: Vector3 = rows[s+1][(j+1)%sides]
				var d: Vector3 = rows[s+1][j]
				_quad(st,a,b,c,d,Color(aos[s],0,0),Color(aos[s],0,0),Color(aos[s+1],0,0),Color(aos[s+1],0,0))
		# Roots from its shelves and its root.
		if float(k.growth) > 0.15 and rng.randf() < 0.3+0.6*float(k.growth):
			var at: Vector3 = rows[mini(1,rows.size()-1)][rng.randi()%sides]
			root_list.append(Vector4(at.x,at.y,at.z,long_*rng.randf_range(0.3,0.8)))

	func _drip_ring(c: Vector2, y: float, r: float, sides: int, phase: float, wob: float) -> Array:
		var row: Array = []
		for j in sides:
			var a := TAU*j/sides
			var p := Vector2(cos(a),sin(a))
			var w := 1.0+wob*sin(a*2.0+phase)+0.5*wob*lump.get_noise_3d(c.x+p.x*3.0,y*2.0,c.y+p.y*3.0)
			var q := c+p*r*w
			row.append(Vector3(q.x,y+lump.get_noise_2d(q.x*3.0,q.y*3.0)*r*0.12,q.y))
		return row

	## A faceted stone standing at `p`: `prof` rows of [height share, width
	## share], `h` tall, `w` wide (stretched `ratio` across), leaning `slant`
	## (m sideways per m up); its foot kept from the grass.
	func _stone(st: SurfaceTool, p: Vector2, h: float, w: float, ratio: float, turn: float, slant: Vector2, prof: Array, sides: int) -> void:
		var base := top_y(p,clampf(p.length()/maxf(rim_at(p.angle()),0.01),0.0,1.0))-0.2
		var rows: Array = []
		for pr: Array in prof:
			var row: Array = []
			var up := h*float(pr[0])
			var c := p+slant*up
			for j in sides:
				var b := TAU*j/sides
				var rr := w*float(pr[1])*(1.0+0.45*lump.get_noise_2d(p.x*5.0+cos(b)*3.0+up,p.y*5.0+sin(b)*3.0))
				var q := Vector2(cos(b)*rr,sin(b)*rr*ratio).rotated(turn)
				row.append(Vector3(c.x+q.x,base+up,c.y+q.y))
			rows.append(row)
		for s in rows.size()-1:
			var ao := 0.45 if s == 0 else 1.0
			for j in sides:
				_quad(st,rows[s][j],rows[s+1][j],rows[s+1][(j+1)%sides],rows[s][(j+1)%sides],Color(ao,0,0),Color(1,0,0),Color(1,0,0),Color(ao,0,0))
		keep_out.append(Vector3(p.x,p.y,w*1.15+0.15))
		top_peak = maxf(top_peak,base+h)

	## Rock knobs through the turf (the crown's silhouette): more with
	## weather and size, some low and broad, some upright.
	func _knobs_on_top(st: SurfaceTool) -> float:
		var n := 0
		if rng.randf() < 0.35+0.5*float(k.weather): n += 1
		if R > 5.0 and rng.randf() < 0.3+0.5*float(k.weather): n += 1
		if R > 9.0 and rng.randf() < 0.6: n += 1
		for i in n:
			var p := Vector2.from_angle(rng.randf()*TAU)*R*rng.randf_range(0.2,0.7)
			var h := clampf(R*rng.randf_range(0.05,0.14),0.3,1.8)
			var w := h*rng.randf_range(0.7,1.5)
			var prof := [[0.0,1.0],[0.4,0.92],[0.45,0.72],[0.8,0.55],[0.85,0.38],[1.0,0.05]]
			_stone(st,p,h,w,rng.randf_range(0.6,0.9),rng.randf()*TAU,Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(0.0,0.3),prof,7)
		return float(n)

	## A spire's shard: a tall stepped blade standing up out of the crown on
	## one side, leaning on along the body's line (and now and then a
	## cone's or boulder's lower stack).
	func _shard(st: SurfaceTool) -> bool:
		var want := body == SPIRE or (body in [CONE,BOULDER] and R > 3.0 and rng.randf() < 0.25)
		if not want: return false
		var tall := R*(rng.randf_range(1.2,2.0) if body == SPIRE else rng.randf_range(0.35,0.6))
		var w := R*(rng.randf_range(0.5,0.65) if body == SPIRE else rng.randf_range(0.2,0.3))
		var at := -lean_dir*R*(rng.randf_range(0.1,0.25) if body == SPIRE else rng.randf_range(0.25,0.45))
		var prof := [[0.0,1.0],[0.22,0.94],[0.24,0.8],[0.5,0.72],[0.52,0.58],[0.76,0.46],[0.78,0.34],[0.95,0.16],[1.0,0.0]]
		_stone(st,at,tall,w,rng.randf_range(0.45,0.7),lean_dir.angle()+PI*0.5,-lean_dir*lean*0.8,prof,8)
		return true

	# --- Crown and lip ----------------------------------------------------------------

	## The turf: a polar grid over the outline, hummocked and risen, drawn
	## in the isles' own ground (KitLook's ground mesh and material, the
	## plate's greens) with the lip's crest and roll; then the lip's earth
	## round its rim in the unit's turf shader: a ragged earth face hanging
	## down, its hem, and an under-face back in to the rock (the shadow
	## line). The earth's vertex colour: rgb a shade, alpha how much earth.
	func _turf_mesh(root: Node3D) -> void:
		var ground := KitLook.GroundMesh.new()
		var tone: Callable = KitLook.turf(seed_value)
		var us := [0.0,0.08,0.17,0.26,0.35,0.44,0.53,0.62,0.7,0.78,0.85,0.91,0.96,1.0]
		var grid: Array = []
		for u: float in us:
			var row: Array = []
			for j in segs:
				var p := dir(j)*rim(j)*u
				row.append(Vector3(p.x,top_y(p,u),p.y))
			grid.append(row)
		var add := func(a: Vector3, b: Vector3, c: Vector3) -> void:
			var mid := Vector2(a.x+b.x+c.x,a.z+b.z+c.z)/3.0
			var col: Color = tone.call(mid,Vector3.UP,rng.randf_range(-0.008,0.008),(a.y+b.y+c.y)/3.0)
			ground.add(a,b,c,col)
			collide.append_array(PackedVector3Array([a,c,b]))
		for i in us.size()-1:
			for j in segs:
				var a: Vector3 = grid[i][j]
				var b: Vector3 = grid[i][(j+1)%segs]
				var c: Vector3 = grid[i+1][(j+1)%segs]
				var d: Vector3 = grid[i+1][j]
				if i == 0: add.call(a,c,d)
				else:
					add.call(a,b,c)
					add.call(a,c,d)
		# The lip: rows out from the rim and down.
		var lip_noise := IsletUnit._noise(seed_value*7+5,1.0,2)
		var lip: Array = []
		crest.resize(segs)
		roll.resize(segs)
		for j in segs:
			var d := dir(j)
			var r := rim(j)
			var a := TAU*j/segs
			var y0: float = (grid[-1][j] as Vector3).y
			var reach := lip_reach*maxf(0.2,1.0+0.8*IsletUnit._ring(lip_noise,a,2.0))
			# The hem torn: broad sags, a ragged edge, tongues of sod.
			var droop := lip_droop*maxf(0.3,1.0+0.6*IsletUnit._ring(lip_noise,a,3.0,5.0)+0.35*rng.randf_range(-1.0,1.0))
			if rng.randf() < 0.2: droop *= rng.randf_range(1.5,2.4)
			droop = maxf(droop,0.2)
			# [radius out, y]: crest, roll, the face bulging, hem, back
			# under, at the rock.
			var prof := [
				[r+reach*0.55,y0+0.04],
				[r+reach,y0-minf(droop*0.2,0.35)],
				[r+reach*1.02,y0-droop*0.48],
				[r+reach*0.78,y0-droop],
				[r*0.84,y0-droop*0.8],
			]
			crest[j] = prof[0]
			roll[j] = prof[1]
			var row: Array = [grid[-1][j]]
			for pr: Array in prof:
				var p := d*float(pr[0])
				row.append(Vector3(p.x,float(pr[1]),p.y))
			lip.append(row)
		# The crest and roll in the ground; the face, hem and under-face in
		# the earth: darkening down the face to the black under-face.
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var shade := [Color(1,1,1,0),Color(1,1,1,0),Color(0.62,0.62,0.62,0.92),Color(0.48,0.48,0.48,1.0),Color(0.32,0.32,0.32,1.0),Color(0.14,0.14,0.14,1.0)]
		for j in segs:
			var row_a: Array = lip[j]
			var row_b: Array = lip[(j+1)%segs]
			for s in row_a.size()-1:
				var a: Vector3 = row_a[s]
				var b: Vector3 = row_b[s]
				var c: Vector3 = row_b[s+1]
				var d: Vector3 = row_a[s+1]
				if s < 2:
					add.call(a,b,c)
					add.call(a,c,d)
					continue
				for v: Array in [[a,shade[s]],[c,shade[s+1]],[b,shade[s]],[a,shade[s]],[d,shade[s+1]],[c,shade[s+1]]]:
					st.set_color(v[1])
					st.add_vertex(v[0])
		# The drape's and roots' anchors along the hem.
		_hem = []
		for j in segs: _hem.append(lip[j][4])
		var g := ground.node("Ground")
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		root.add_child(g)
		st.index()
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.name = "Turf"
		mi.mesh = st.commit()
		mi.material_override = IsletUnit.earth_material(rng)
		root.add_child(mi)

	var _hem: Array = []

	## Torn grass and sod hanging under the hem: clumps of thin strands,
	## each bent out and down in two runs, the earth's tone at their roots,
	## the grass's green at their tips; more and longer with growth.
	func _drape_mesh() -> MeshInstance3D:
		var g := float(k.growth)
		if g < 0.08 or _hem.is_empty(): return null
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var strands := 0
		for j in segs:
			var a: Vector3 = _hem[j]
			var b: Vector3 = _hem[(j+1)%segs]
			var out := Vector3(a.x,0.0,a.z).normalized()
			var along := (b-a).normalized()
			if rng.randf() > 0.35+0.6*g: continue
			var n := int(rng.randf_range(2.0,10.0)*g)+1
			var clump_long := lip_droop*rng.randf_range(0.5,1.8)*(0.4+g)
			for c in n:
				var p := a.lerp(b,rng.randf())+Vector3(0.0,rng.randf_range(0.0,0.1),0.0)-out*0.03
				var long_ := clump_long*rng.randf_range(0.35,1.0)
				var w := clampf(long_*0.06,0.015,0.05)
				var side := along*w*0.5
				var bow := out*long_*rng.randf_range(0.05,0.25)+along*long_*rng.randf_range(-0.2,0.2)
				var mid := p+Vector3(0.0,-long_*0.5,0.0)+bow*0.8
				var tip := p+Vector3(0.0,-long_,0.0)+bow
				var root_c := Color(0.5,0.5,0.5,1.0)
				var mid_c := Color(0.62,0.62,0.62,0.4)
				var tip_c := Color(0.78,0.78,0.78,0.0)
				for v: Array in [[p-side,root_c],[p+side,root_c],[mid+side*0.7,mid_c],[p-side,root_c],[mid+side*0.7,mid_c],[mid-side*0.7,mid_c],[mid-side*0.7,mid_c],[mid+side*0.7,mid_c],[tip,tip_c]]:
					st.set_color(v[1])
					st.set_normal(out)
					st.add_vertex(v[0])
				strands += 1
		stats.drape = strands
		if strands == 0: return null
		var mi := MeshInstance3D.new()
		mi.name = "Drape"
		mi.mesh = st.commit()
		var mat := IsletUnit.earth_material(rng,IsletUnit.drape_shader())
		mat.set_shader_parameter("drape",true)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return mi

	# --- Growth -----------------------------------------------------------------------

	## The isles' grass (KitFlora, the aqueduct isle's carpet: full cover,
	## wild and tall toward the rim and out over the lip's roll, tussocks,
	## seed heads and a few flowers), a tree or a shrub.
	func _crown(root: Node3D) -> void:
		var g := float(k.growth)
		if g >= IsletUnit.GRASS_FROM:
			var site := KitFlora.Site.new()
			IsletUnit.flora_carpet().carpeted(site)
			site.probe = probe
			site.tufts *= lerpf(IsletUnit.GRASS_THICK.x,IsletUnit.GRASS_THICK.y,g)
			site.shag *= lerpf(IsletUnit.GRASS_SHAG.x,IsletUnit.GRASS_SHAG.y,g)
			# Out onto the roll: the rim the grass keeps is the roll's.
			site.rim = 0.02
			var outline := PackedVector2Array()
			for j in segs: outline.append(dir(j)*float(roll[j][0])*0.995)
			var job := KitFlora.Grow.new(hash(["islet_flora",seed_value]) & 0xffffff,null,[],[outline],site)
			while not job.step(-1): pass
			var flora: Node3D = job.node
			flora.name = "Flora"
			root.add_child(flora)
			IsletUnit.flora_carpet().calm(flora)
			stats.grass = (flora.get_meta("counts") as Dictionary).duplicate()
			stats.grass_triangles = int(flora.get_meta("triangles"))
		# A dead tree or a shrub (or, bare, nothing).
		var growth := Node3D.new()
		growth.name = "Growth"
		var roll_ := rng.randf()
		if g > 0.15 and roll_ < 0.3+0.6*g:
			for tries in 8:
				var a := rng.randf()*TAU
				var j := int(a/TAU*segs)%segs
				var p := dir(j)*rim(j)*rng.randf_range(0.35,0.75)
				if is_nan(probe(p,0.0)): continue
				var at := Vector3(p.x,top_y(p,0.5)-0.05,p.y)
				if rng.randf() < 0.55:
					growth.add_child(IsletUnit._tree(at,clampf(R*0.45,1.5,5.0)*rng.randf_range(0.8,1.15),rng.randi(),lean_dir))
					stats.tree = true
				else:
					growth.add_child(IsletUnit._shrub(at,clampf(R*0.16,0.5,1.6),rng.randi()))
					stats.shrub = true
				break
		if growth.get_child_count() > 0: root.add_child(growth)
		else: growth.free()

	## Dead roots: from under the lip's hem, from the shelves, from the drips,
	## long and thin, grey-brown (the kit's HangingRoots strand, retinted).
	func _roots(root: Node3D) -> void:
		var g := float(k.growth)
		if g < 0.1: return
		var n := int(segs*0.12*g)+1
		for i in n:
			var j := rng.randi()%segs
			var h: Vector3 = _hem[j]
			root_list.append(Vector4(h.x*0.97,h.y+0.05,h.z*0.97,rng.randf_range(0.8,2.6)*lip_droop*(0.6+g)*(1.0 if rng.randf() < 0.7 else 2.2)))
		# From the shelves' edges.
		for i in range(2,rings.size()-1):
			if int(rings[i][3]) != 2 or rng.randf() > 0.5*g: continue
			for c in rng.randi_range(1,3):
				var p := body_point(i,rng.randi()%segs)
				root_list.append(Vector4(p.x,p.y,p.z,rng.randf_range(0.6,2.0)*clampf(R*0.25,0.8,3.0)*(0.5+g)))
		if root_list.is_empty(): return
		var mmi := HangingRoots.batch(root_list,seed_value)
		var mm := mmi.multimesh
		for i in mm.instance_count:
			var cd := mm.get_instance_custom_data(i)
			cd.g *= 0.55
			mm.set_instance_custom_data(i,cd)
		mmi.material_override = IsletUnit.root_material()
		mmi.name = "Roots"
		root.add_child(mmi)
		stats.roots = root_list.size()

## The aqueduct isle's grass settings (studies/aqueduct_isle_flora.gd),
## loaded when first asked (it is a study's script).
static var _carpet: GDScript = null
static func flora_carpet() -> GDScript:
	if _carpet == null: _carpet = load("res://studies/aqueduct_isle_flora.gd")
	return _carpet

## The lip's earth and the drape (shaders/islet_turf.gdshader), its grass
## tones the carpet's as the game draws it (DRAPE_*), so the drape's tips
## read as the grass above.
static func earth_material(rng: RandomNumberGenerator, shader: Shader = TURF_SHADER) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("sage",DRAPE_OLIVE)
	mat.set_shader_parameter("straw",DRAPE_GOLD)
	mat.set_shader_parameter("dry_dark",DRAPE_DARK)
	mat.set_shader_parameter("seed_off",Vector3(rng.randf_range(-50,50),0.0,rng.randf_range(-50,50)))
	mat.set_shader_parameter("dry",0.0)
	return mat

static var _growth_mat: ShaderMaterial = null

## The tree's and shrub's material: their vertex colour (sRGB), the sky's
## fill into their shade as the rock has it, both sides drawn.
static func growth_material() -> ShaderMaterial:
	if _growth_mat == null:
		var sh := Shader.new()
		sh.code = """shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
global uniform vec3 zs_hemi_sky;
global uniform vec3 zs_hemi_ground;
global uniform float zs_hemi_energy;
void fragment() {
	if (!FRONT_FACING) NORMAL = -NORMAL;
	vec3 c = pow(COLOR.rgb, vec3(2.2));
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	ALBEDO = c;
	EMISSION = c * mix(zs_hemi_ground, zs_hemi_sky, wn.y * 0.5 + 0.5) * zs_hemi_energy / PI;
	ROUGHNESS = 1.0;
}
"""
		_growth_mat = ShaderMaterial.new()
		_growth_mat.shader = sh
	return _growth_mat

static var _drape_sh: Shader = null

## The turf's shader drawn both sides (the drape's strands).
static func drape_shader() -> Shader:
	if _drape_sh == null:
		_drape_sh = Shader.new()
		_drape_sh.code = TURF_SHADER.code.replace("cull_back","cull_disabled")
	return _drape_sh

static var _root_mat: ShaderMaterial = null

## HangingRoots' strand shader, its bark tinted grey-brown and paler.
static func root_material() -> ShaderMaterial:
	if _root_mat == null:
		HangingRoots.warm()
		var sh := Shader.new()
		sh.code = HangingRoots.SHADER.replace("FORK_AT",str(HangingRoots.FORK_AT)).replace("ALBEDO = COLOR.rgb;","ALBEDO = COLOR.rgb * tint;\n\tEMISSION = ALBEDO * mix(zs_hemi_ground, zs_hemi_sky, 0.6) * zs_hemi_energy / PI;").replace("uniform float sway_speed","global uniform vec3 zs_hemi_sky;\nglobal uniform vec3 zs_hemi_ground;\nglobal uniform float zs_hemi_energy;\nuniform vec3 tint = vec3(1.0);\nuniform float sway_speed")
		_root_mat = ShaderMaterial.new()
		_root_mat.shader = sh
		var t := ROOT_TINT
		_root_mat.set_shader_parameter("tint",Vector3(t.r,t.g,t.b))
	return _root_mat

## A dead tree `tall` m: a bent trunk, forking twice or three times, the
## twigs thinning to nothing; bleached grey-brown.
static func _tree(at: Vector3, tall: float, seed_value: int, lean: Vector2) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk_dir := (Vector3.UP+Vector3(lean.x,0.0,lean.y)*rng.randf_range(0.1,0.45)).normalized()
	_branch(st,rng,at-Vector3(0,0.1,0),trunk_dir,tall*0.55,tall*0.045,3)
	st.index()
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "DeadTree"
	mi.mesh = st.commit()
	mi.material_override = growth_material()
	return mi

static func _branch(st: SurfaceTool, rng: RandomNumberGenerator, from: Vector3, way: Vector3, long_: float, r: float, depth_left: int) -> void:
	var sides := 5 if depth_left >= 2 else 4
	var steps := 3
	var p := from
	var d := way
	var side := d.cross(Vector3.RIGHT if absf(d.x) < 0.9 else Vector3.FORWARD).normalized()
	var prev: Array = _ring_at(p,d,side,r,sides)
	for s in steps:
		d = (d+Vector3(rng.randf_range(-0.25,0.25),rng.randf_range(-0.05,0.1),rng.randf_range(-0.25,0.25))).normalized()
		p += d*long_/steps
		var rr := r*(1.0-0.55*float(s+1)/steps)
		side = d.cross(Vector3.RIGHT if absf(d.x) < 0.9 else Vector3.FORWARD).normalized()
		var ring: Array = _ring_at(p,d,side,rr,sides)
		var ca := BARK_DARK.lerp(BARK,0.4+0.2*s) if depth_left == 3 else BARK
		for j in sides:
			for v: Vector3 in [prev[j],ring[(j+1)%sides],prev[(j+1)%sides],prev[j],ring[j],ring[(j+1)%sides]]:
				st.set_color(ca)
				st.add_vertex(v)
		prev = ring
	if depth_left <= 0 or r < 0.012:
		return
	var forks := rng.randi_range(2,3)
	for f in forks:
		var out := Vector3(rng.randf_range(-1,1),rng.randf_range(0.3,0.9),rng.randf_range(-1,1)).normalized()
		_branch(st,rng,p,(d*0.6+out).normalized(),long_*rng.randf_range(0.5,0.75),r*0.45*1.0,depth_left-1)

static func _ring_at(p: Vector3, d: Vector3, side: Vector3, r: float, sides: int) -> Array:
	var up := d.cross(side).normalized()
	var row: Array = []
	for j in sides:
		var a := TAU*j/sides
		row.append(p+(side*cos(a)+up*sin(a))*r)
	return row

## A low shrub: a few lumpy balls, green, darker underneath.
static func _shrub(at: Vector3, size: float, seed_value: int) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sphere := SphereMesh.new()
	sphere.radial_segments = 8
	sphere.rings = 5
	var arr := sphere.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	for b in rng.randi_range(4,7):
		var c := at+Vector3(rng.randf_range(-0.6,0.6)*size,rng.randf_range(0.1,0.55)*size,rng.randf_range(-0.6,0.6)*size)
		var s := size*rng.randf_range(0.45,0.75)
		for i in idx:
			var v := verts[i]
			var w := v*s*2.0*(1.0+0.18*sin(v.x*9.0+b)*cos(v.z*7.0))
			w.y *= 0.75
			var shade := SHRUB_DARK.lerp(SHRUB,clampf(v.y+0.5,0.0,1.0))
			st.set_color(shade)
			st.add_vertex(c+w)
	st.index()
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Shrub"
	mi.mesh = st.commit()
	mi.material_override = growth_material()
	return mi
