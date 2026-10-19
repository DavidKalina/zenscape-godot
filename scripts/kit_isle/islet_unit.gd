class_name IsletUnit
extends RefCounted
## The islet unit (docs/design/isle-look/islet-unit-handoff.md): one floating
## rock chunk, the smallest piece an isle is composed of, in three parts.
##   Crown   dry turf over a hummocked top, grass tufts (thick along the
##           rim so the skyline breaks), now and then a rock knob through the
##           turf, a dead tree or a low shrub.
##   Lip     the turf rolled out over the rock's edge and hanging down its
##           face as a ragged hem of earth, torn grass draped under it, the
##           rock under it set back in shadow.
##   Body    rock stepping down in strata (a shelf at each bed, the beds
##           narrowing), its underside a cluster of hanging drips of varied
##           length off its middle, dead roots trailing under it.
## Every part is drawn from the spec's seed and its knobs, so siblings vary
## and read as one family. Nothing here is shared with KitLand or the isles:
## a new, opt-in builder (the existing isles and motifs build as before).
##
##   IsletUnit.build(spec)        a Node3D: Rock, Turf, Drape, Tufts, Roots,
##                                Growth (tree / shrub) and Body (collision,
##                                its turf on the isles' turf layer); its
##                                origin the turf's middle at the top
##   IsletUnit.sibling(seed, base) a spec with knobs drawn round `base`
##
## Knobs (spec keys; KNOBS gives each one's default and range):
##   seed      every draw
##   size      the top's radius (m): a hop boulder (1.5) to a landing slab (18)
##   shape     0 a wide shallow ledge .. 1 a narrow deep spire
##   lean      the body's lean off plumb under the top (0..1, up to ~22 deg)
##   drip      0 many short drips .. 1 one deep drip
##   lopsided  how far the underside's mass sits off the middle
##   growth    0 bare .. 1 overgrown: tufts, lip reach and droop, drape,
##             roots and their length, a tree or shrub
##   weather   cracks, lichen, notches bitten out of the rim

const HangingRoots = preload("res://scripts/kit_isle/hanging_roots.gd")
const ROCK_SHADER := preload("res://shaders/islet_rock.gdshader")
const TURF_SHADER := preload("res://shaders/islet_turf.gdshader")
const TUFT_SHADER := preload("res://shaders/islet_tuft.gdshader")

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
## The isles' turf layer (studies/kit_isle.gd TURF_LAYER) and their solid.
const TURF_LAYER := 1 << 11
const SOLID_LAYER := 1

## The palette (sRGB): dusty and faded.
const BARK := Color("8a7f72")
const BARK_DARK := Color("4f463d")
const ROOT_TINT := Color(1.85,1.8,1.7)
const SHRUB := Color("7d8664")
const SHRUB_DARK := Color("4b5240")
const TUFT_COLOURS := [Color("c2ad78"),Color("b39f6c"),Color("a3a77c"),Color("929a72"),Color("cbb98a")]

## A full spec from `spec`: missing knobs at their defaults, all clamped.
static func knobs_of(spec: Dictionary) -> Dictionary:
	var out := {"seed":int(spec.get("seed",1))}
	for k: String in KNOBS:
		var r: Array = KNOBS[k]
		out[k] = clampf(float(spec.get(k,r[0])),float(r[1]),float(r[2]))
	return out

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
	var u := Unit.new(k)
	return u.make()

class Unit:
	var k: Dictionary
	var seed_value: int
	var rng := RandomNumberGenerator.new()
	var R: float
	var depth: float
	var segs: int
	var radii: PackedFloat32Array = PackedFloat32Array()
	var hum: FastNoiseLite
	var lump: FastNoiseLite
	## The body's rings: [y, scale, centre (Vector2), shelf (bool)].
	var rings: Array = []
	var lean_dir := Vector2.ZERO
	var lip_reach := 0.3
	var lip_droop := 0.5
	var root_list: Array = []
	var collide := PackedVector3Array()
	var stats := {}

	func _init(knobs: Dictionary) -> void:
		k = knobs
		seed_value = int(k.seed)
		rng.seed = hash(["islet_unit",seed_value])
		R = float(k.size)
		var shape := float(k.shape)
		# A wide ledge is shallow; a spire deep. Small rocks run deeper for
		# their size (a boulder is round), big slabs shallower.
		var small := clampf(1.0-(R-1.5)/10.0,0.0,1.0)
		depth = R*(0.62+1.8*shape+0.35*small)
		segs = clampi(int(R*7.0),28,96)
		hum = IsletUnit._noise(seed_value*7+1,0.11/maxf(R/6.0,0.4))
		lump = IsletUnit._noise(seed_value*7+2,0.35/maxf(R/6.0,0.5),4)
		var a := rng.randf()*TAU
		lean_dir = Vector2(cos(a),sin(a))
		var g := float(k.growth)
		lip_reach = clampf(R*0.035,0.14,0.6)*(0.55+0.9*g)
		lip_droop = clampf(R*0.035,0.15,0.55)*(0.5+g)
		_outline()

	## The top's outline: radius a segment, lobed, stretched for a ledge,
	## bitten by weathering.
	func _outline() -> void:
		var shape := float(k.shape)
		var lobes := IsletUnit._noise(seed_value*7+3,0.9,2)
		var stretch := 1.0+rng.randf_range(0.0,0.45)*(1.0-shape)
		var turn := rng.randf()*TAU
		var bites: Array = []
		for i in rng.randi_range(1,3)+int(float(k.weather)*3.0):
			bites.append([rng.randf()*TAU,rng.randf_range(0.12,0.3),rng.randf_range(0.06,0.16)*float(k.weather)])
		radii.resize(segs)
		for j in segs:
			var a := TAU*j/segs
			var r := 1.0+0.22*IsletUnit._ring(lobes,a,1.0)+0.06*IsletUnit._ring(lobes,a,3.5,9.0)
			var c := cos(a-turn)
			r *= lerpf(1.0,stretch,c*c)/sqrt(stretch)
			for b: Array in bites:
				var d := absf(wrapf(a-float(b[0]),-PI,PI))
				if d < float(b[1]): r -= float(b[2])*(0.5+0.5*cos(PI*d/float(b[1])))
			radii[j] = R*r

	func rim(j: int) -> float:
		return radii[posmod(j,segs)]

	func dir(j: int) -> Vector2:
		var a := TAU*j/segs
		return Vector2(cos(a),sin(a))

	## The turf's height over (x, z): low hummocks, a little crown.
	func top_y(p: Vector2, u: float) -> float:
		return R*0.035*hum.get_noise_2d(p.x,p.y)+R*0.025*(1.0-u*u)

	func make() -> Node3D:
		var root := Node3D.new()
		root.name = "IsletUnit"
		root.set_meta("knobs",k.duplicate())
		_body_rings()
		var rock := _rock_mesh()
		root.add_child(rock)
		root.add_child(_turf_mesh())
		var drape := _drape_mesh()
		if drape != null: root.add_child(drape)
		_crown(root)
		_roots(root)
		var body := StaticBody3D.new()
		body.name = "Body"
		body.collision_layer = SOLID_LAYER | TURF_LAYER
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(collide)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
		root.add_child(body)
		var outline: Array = []
		for j in segs: outline.append(dir(j)*rim(j))
		root.set_meta("outline",outline)
		root.set_meta("depth",depth)
		var tris := 0
		for mi: Node in root.find_children("*","MeshInstance3D",true,false):
			var m := (mi as MeshInstance3D).mesh
			for s in m.get_surface_count(): tris += m.surface_get_array_index_len(s)/3 if m.surface_get_format(s) & Mesh.ARRAY_FORMAT_INDEX else m.surface_get_array_len(s)/3
		stats.triangles = tris
		root.set_meta("stats",stats)
		return root

	# --- Body -------------------------------------------------------------------------

	## The main mass: rings down from just under the lip (set back in its
	## shadow), then beds stacked like plates under an envelope narrowing
	## to the underside: each bed's top stands out a little past the foot
	## of the bed over it (an up-facing ledge, where lichen takes) and its
	## face cuts back under as it goes down (an undercut, in shade). Under
	## the last bed a blunt cap, off the middle (lopsided), the drips hang
	## from. Its centre leans as it goes. Ring: [y, scale, centre, kind]
	## (kind: 0 face, 1 ledge top, 2 undercut foot, 3 top band).
	func _body_rings() -> void:
		var shape := float(k.shape)
		mass = depth*lerpf(0.38,0.5,shape)
		var beds := clampi(2+int(rng.randf_range(0.0,1.6)+shape*2.0+R/9.0),2,6)
		lop_dir = Vector2.from_angle(rng.randf()*TAU)
		var lop := lop_dir*R*0.3*float(k.lopsided)
		var lean := float(k.lean)*0.4
		bottom_sc = lerpf(0.45,0.32,shape)*rng.randf_range(0.85,1.1)
		var bend := lerpf(1.7,1.0,shape)
		rings.append([-0.02,0.92,Vector2.ZERO,3,-1])
		rings.append([-lip_droop*0.85,0.88,Vector2.ZERO,3,-1])
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
			var e0 := lerpf(0.9,bottom_sc,pow(t,bend))
			var e1 := lerpf(0.9,bottom_sc,pow(t1,bend))
			var c0 := lop*t+lean_dir*lean*(-y)
			var c1 := lop*t1+lean_dir*lean*(-(y-face))
			var under := rng.randf_range(0.05,0.13)*(0.6+0.8*float(k.weather))
			if b > 0:
				# The ledge: this bed's top out past the last one's foot.
				rings.append([y-face*0.03,e0*rng.randf_range(0.99,1.03),c0,1,b])
			rings.append([y-face*0.45,lerpf(e0,e1,0.4)*rng.randf_range(0.98,1.02),c0.lerp(c1,0.45),0,b])
			y -= face
			rings.append([y,e1*(1.0-under),c1,2,b])
			bed_faces.append(face)
			t = t1
		var tip := lop+lean_dir*lean*mass
		rings.append([y-R*0.05,bottom_sc*0.55,tip.lerp(Vector2.ZERO,0.2),0,-1])
		rings.append([y-R*0.09,0.0,tip,0,-1])
		stats.beds = beds

	var mass := 1.0
	var lop_dir := Vector2.RIGHT
	var bottom_sc := 0.5
	var bed_faces: Array = []

	## The body's surface at ring `i`, segment `j` (land-local), with lumps
	## (small under the lip, so the rock stays set back under it).
	func body_point(i: int, j: int) -> Vector3:
		var ring: Array = rings[i]
		var sc := float(ring[1])
		var c: Vector2 = ring[2]
		var d := dir(j)
		var p := c+d*rim(j)*sc
		var y := float(ring[0])
		# Lopsided: under one side the mass hangs further out, deeper down.
		var deep := clampf(-y/maxf(mass,0.01),0.0,1.0)
		var lean_out := 1.0+0.55*float(k.lopsided)*d.dot(lop_dir)*deep
		p = c+d*rim(j)*sc*lean_out
		var amp := minf(R*0.07,0.7)*(0.3+0.7*sc)*(0.25 if int(ring[3]) == 3 else 1.0)
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
		var top_y0 := 0.0
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
		# The knobs through the turf faceted (flat normals: angular stone).
		var knobs := SurfaceTool.new()
		knobs.begin(Mesh.PRIMITIVE_TRIANGLES)
		if _knobs_on_top(knobs) > 0:
			knobs.generate_normals()
			knobs.commit(mesh)
		var mi := MeshInstance3D.new()
		mi.name = "Rock"
		mi.mesh = mesh
		var mat := ShaderMaterial.new()
		mat.shader = IsletUnit.ROCK_SHADER
		mat.set_shader_parameter("top_y",top_y0)
		mat.set_shader_parameter("bottom_y",minf(bottom,-depth))
		mat.set_shader_parameter("weather",float(k.weather))
		mat.set_shader_parameter("seed_off",Vector3(rng.randf_range(-50,50),rng.randf_range(-50,50),rng.randf_range(-50,50)))
		mat.set_shader_parameter("bed_scale",1.0/clampf(R*0.09,0.35,1.4))
		mi.material_override = mat
		return mi

	func _ring_ao(i: int) -> float:
		if i == 0: return 0.15
		if i == 1: return 0.4
		match int(rings[i][3]):
			1: return 1.0
			2: return 0.5
		return 0.85

	func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
		for v: Array in [[a,ca],[c,cc],[b,cb],[a,ca],[d,cd],[c,cc]]:
			st.set_color(v[1])
			st.add_vertex(v[0])
		collide.append_array(PackedVector3Array([a,c,b,a,d,c]))

	## The underside's cluster: hanging drips off the cap, one long and many
	## short (drip 1) or many alike (drip 0), each narrowing in steps, bent;
	## and a few short ones off the beds' undercut feet (fewer with drip).
	func _drips(st: SurfaceTool) -> void:
		var drip := float(k.drip)
		var foot: Array = rings[rings.size()-3]
		var foot_y := float(foot[0])
		var foot_c: Vector2 = foot[2]
		var tip: Vector2 = rings[-1][2]
		var below := depth-mass
		var count := clampi(int(round(lerpf(6.0,2.0,drip)+rng.randf_range(-1.0,1.0)+R/10.0)),1,9)
		var out := 0
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
			var bend := Vector2.from_angle(rng.randf()*TAU)*long_*rng.randf_range(0.04,0.18)+lean_dir*float(k.lean)*0.25*long_
			var top_y := foot_y+r0*0.5
			_drip(st,Vector3(at.x,top_y,at.y),r0,long_+r0*0.5,bend)
			out += 1
		# Off the beds' feet, round the sides.
		var side_n := int(rng.randf_range(0.0,4.0)*(1.1-drip)*clampf(R/6.0,0.5,1.6))
		var feet: Array = []
		for i in range(2,rings.size()-3):
			if int(rings[i][3]) == 2: feet.append(i)
		for n in side_n:
			if feet.is_empty(): break
			var ring: Array = rings[feet[rng.randi()%feet.size()]]
			var j := rng.randi()%segs
			var c: Vector2 = ring[2]
			var r0 := R*rng.randf_range(0.04,0.1)
			var at := c+dir(j)*rim(j)*float(ring[1])*0.86
			var long_ := r0*rng.randf_range(2.0,5.5)
			_drip(st,Vector3(at.x,float(ring[0])+r0*0.4,at.y),r0,long_,Vector2.from_angle(rng.randf()*TAU)*long_*0.1)
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

	## A rock knob or two through the turf (crown silhouette).
	func _knobs_on_top(st: SurfaceTool) -> int:
		var n := 0
		if rng.randf() < 0.3+0.5*float(k.weather): n += 1
		if R > 7.0 and rng.randf() < 0.5: n += 1
		for i in n:
			var a := rng.randf()*TAU
			var p := Vector2(cos(a),sin(a))*R*rng.randf_range(0.15,0.6)
			var h := clampf(R*rng.randf_range(0.04,0.09),0.25,1.0)
			var w := h*rng.randf_range(0.9,1.6)
			var base := top_y(p,p.length()/R)-0.15
			var rows: Array = []
			var sides := 7
			var prof := [[0.0,1.0],[0.45,0.92],[0.5,0.7],[0.85,0.55],[1.0,0.0]]
			for pr: Array in prof:
				var row: Array = []
				for j in sides:
					var b := TAU*j/sides
					var rr := w*float(pr[1])*(1.0+0.6*lump.get_noise_2d(p.x*5.0+cos(b)*3.0,p.y*5.0+sin(b)*3.0))
					row.append(Vector3(p.x+cos(b)*rr,base+h*float(pr[0]),p.y+sin(b)*rr*0.8))
				rows.append(row)
			for s in rows.size()-1:
				var ao := 0.5 if s == 0 else 1.0
				for j in sides:
					_quad(st,rows[s][j],rows[s+1][j],rows[s+1][(j+1)%sides],rows[s][(j+1)%sides],Color(ao,0,0),Color(1,0,0),Color(1,0,0),Color(ao,0,0))
		return n

	# --- Crown and lip ----------------------------------------------------------------

	## The turf: a polar grid over the outline, hummocked; then the lip
	## round its rim: a roll out over the edge, a ragged earth face hanging
	## down, its hem, and an under-face back in to the rock (the shadow line).
	## Vertex colour: rgb a shade, alpha how much earth (0 turf, 1 earth).
	func _turf_mesh() -> MeshInstance3D:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var us := [0.0,0.12,0.26,0.4,0.54,0.66,0.77,0.86,0.93,1.0]
		var grid: Array = []
		for u: float in us:
			var row: Array = []
			for j in segs:
				var p := dir(j)*rim(j)*u
				row.append(Vector3(p.x,top_y(p,u),p.y))
			grid.append(row)
		var turf := Color(1,1,1,0)
		for i in us.size()-1:
			for j in segs:
				var a: Vector3 = grid[i][j]
				var b: Vector3 = grid[i][(j+1)%segs]
				var c: Vector3 = grid[i+1][(j+1)%segs]
				var d: Vector3 = grid[i+1][j]
				if i == 0:
					for v: Vector3 in [a,d,c]:
						st.set_color(turf)
						st.add_vertex(v)
					collide.append_array(PackedVector3Array([a,d,c]))
				else:
					for v: Vector3 in [a,c,b,a,d,c]:
						st.set_color(turf)
						st.add_vertex(v)
					collide.append_array(PackedVector3Array([a,c,b,a,d,c]))
		# The lip: rows out from the rim and down.
		var lip_noise := IsletUnit._noise(seed_value*7+5,1.0,2)
		var lip: Array = []
		var shades: Array = []
		for j in segs:
			var d := dir(j)
			var r := rim(j)
			var a := TAU*j/segs
			var y0: float = (grid[-1][j] as Vector3).y
			var reach := lip_reach*maxf(0.15,1.0+0.9*IsletUnit._ring(lip_noise,a,2.0))
			# The hem torn: broad sags, a ragged edge, now and then a tongue.
			var droop := lip_droop*maxf(0.25,1.0+0.6*IsletUnit._ring(lip_noise,a,3.0,5.0)+0.35*rng.randf_range(-1.0,1.0))
			if rng.randf() < 0.14: droop *= rng.randf_range(1.4,2.0)
			droop = maxf(droop,0.12)
			# [radius out, y]: crest, roll, face, hem, back under, at the rock.
			var prof := [
				[r+reach*0.6,y0+0.01],
				[r+reach,y0-minf(droop*0.18,0.14)],
				[r+reach*0.92,y0-minf(droop*0.32,0.26)],
				[r+reach*0.7,y0-droop],
				[r*0.86,y0-droop*0.75],
			]
			var row: Array = [grid[-1][j]]
			for pr: Array in prof:
				var p := d*float(pr[0])
				row.append(Vector3(p.x,float(pr[1]),p.y))
			lip.append(row)
		# Shade and earth down the rows: turf over the crest, rolling darker,
		# the earth face, the hem, the black under-face.
		var tone := [Color(1,1,1,0),Color(1,1,1,0),Color(0.8,0.8,0.8,0.1),Color(0.55,0.55,0.55,0.9),Color(0.36,0.36,0.36,1.0),Color(0.18,0.18,0.18,1.0)]
		for j in segs:
			var row_a: Array = lip[j]
			var row_b: Array = lip[(j+1)%segs]
			for s in row_a.size()-1:
				var a: Vector3 = row_a[s]
				var b: Vector3 = row_b[s]
				var c: Vector3 = row_b[s+1]
				var d: Vector3 = row_a[s+1]
				for v: Array in [[a,tone[s]],[c,tone[s+1]],[b,tone[s]],[a,tone[s]],[d,tone[s+1]],[c,tone[s+1]]]:
					st.set_color(v[1])
					st.add_vertex(v[0])
				if s < 2: collide.append_array(PackedVector3Array([a,c,b,a,d,c]))
		# The drape's and roots' anchors along the hem.
		_hem = []
		for j in segs: _hem.append(lip[j][4])
		st.index()
		st.generate_normals()
		var mi := MeshInstance3D.new()
		mi.name = "Turf"
		mi.mesh = st.commit()
		var mat := ShaderMaterial.new()
		mat.shader = IsletUnit.TURF_SHADER
		mat.set_shader_parameter("seed_off",Vector3(rng.randf_range(-50,50),0.0,rng.randf_range(-50,50)))
		mat.set_shader_parameter("dry",clampf(0.65-0.4*float(k.growth)+rng.randf_range(-0.1,0.1),0.0,1.0))
		mi.material_override = mat
		return mi

	var _hem: Array = []

	## Torn grass and sod hanging under the hem: clumps of thin strands,
	## each bent out and down in two runs, the earth's tone at their roots,
	## dull straw at their tips; more and longer with growth.
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
			var n := int(rng.randf_range(2.0,9.0)*g)+1
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
		var mat := ShaderMaterial.new()
		mat.shader = IsletUnit.drape_shader()
		mat.set_shader_parameter("drape",true)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return mi

	# --- Growth -----------------------------------------------------------------------

	## Grass tufts over the turf (thicker on the rim, the skyline), a rock
	## knob's foot, a tree or a shrub.
	func _crown(root: Node3D) -> void:
		var g := float(k.growth)
		var area := 0.0
		for j in segs: area += 0.5*rim(j)*rim(j+1)*sin(TAU/segs)
		var count := int(area*lerpf(0.4,4.5,g))
		var rim_count := int(segs*lerpf(0.4,2.6,g))
		var xs: Array = []
		# In drifts: thick where the drift noise is high, bare between.
		var drift := IsletUnit._noise(seed_value*7+9,0.16/maxf(R/8.0,0.5),2)
		for i in count:
			var j := rng.randi()%segs
			var u := sqrt(rng.randf())*0.92
			var p := dir(j).rotated(rng.randf_range(0.0,TAU/segs))*rim(j)*u
			var thick := smoothstep(-0.15,0.45,drift.get_noise_2d(p.x,p.y))
			if rng.randf() > thick*0.9+0.04: continue
			xs.append([Vector3(p.x,top_y(p,u),p.y),rng.randf_range(0.6,1.1)*(0.75+0.5*thick)])
		for i in rim_count:
			var j := rng.randi()%segs
			var u := rng.randf_range(0.9,1.0)
			var p := dir(j)*rim(j)*u
			xs.append([Vector3(p.x,top_y(p,u)+0.02,p.y),rng.randf_range(0.9,1.6)])
		if not xs.is_empty():
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = IsletUnit._tuft_mesh()
			mm.instance_count = xs.size()
			var tall := clampf(R*0.035,0.2,0.42)
			for i in xs.size():
				var x: Array = xs[i]
				var s := tall*float(x[1])
				mm.set_instance_transform(i,Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(s,s*rng.randf_range(0.8,1.3),s)),x[0]))
				var col: Color = IsletUnit.TUFT_COLOURS[rng.randi()%IsletUnit.TUFT_COLOURS.size()]
				mm.set_instance_color(i,col*rng.randf_range(0.9,1.08))
			var tufts := MultiMeshInstance3D.new()
			tufts.name = "Tufts"
			tufts.multimesh = mm
			var mat := ShaderMaterial.new()
			mat.shader = IsletUnit.TUFT_SHADER
			tufts.material_override = mat
			tufts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			tufts.visibility_range_end = 220.0
			tufts.visibility_range_end_margin = 30.0
			root.add_child(tufts)
		stats.tufts = xs.size()
		# A dead tree or a shrub (or, bare, nothing).
		var growth := Node3D.new()
		growth.name = "Growth"
		var roll := rng.randf()
		if g > 0.15 and roll < 0.3+0.6*g:
			var a := rng.randf()*TAU
			var j := int(a/TAU*segs)%segs
			var p := dir(j)*rim(j)*rng.randf_range(0.35,0.75)
			var at := Vector3(p.x,top_y(p,0.5)-0.05,p.y)
			if rng.randf() < 0.55:
				growth.add_child(IsletUnit._tree(at,clampf(R*0.45,1.5,5.0)*rng.randf_range(0.8,1.15),rng.randi(),lean_dir))
				stats.tree = true
			else:
				growth.add_child(IsletUnit._shrub(at,clampf(R*0.16,0.5,1.6),rng.randi()))
				stats.shrub = true
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

static var _tuft: ArrayMesh = null

## A clump of seven blades, a unit tall, leaning out; vertex colour dark at
## the root and full at the tip (the shader sways by height).
static func _tuft_mesh() -> ArrayMesh:
	if _tuft != null: return _tuft
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for b in 17:
		var a := TAU*b/17.0+rng.randf_range(-0.3,0.3)
		var out := Vector3(cos(a),0.0,sin(a))
		var h := rng.randf_range(0.45,1.0)
		var w := rng.randf_range(0.025,0.045)
		var side := out.cross(Vector3.UP)*w
		var foot := out*rng.randf_range(0.02,0.12)
		var mid := foot+out*h*0.25+Vector3(0.0,h*0.55,0.0)
		var tip := foot+out*h*rng.randf_range(0.45,0.7)+Vector3(0.0,h,0.0)
		var dark := Color(0.5,0.5,0.5)
		var midc := Color(0.82,0.82,0.82)
		for v: Array in [[foot-side,dark],[foot+side,dark],[mid+side*0.7,midc],[foot-side,dark],[mid+side*0.7,midc],[mid-side*0.7,midc],[mid-side*0.7,midc],[mid+side*0.7,midc],[tip,Color.WHITE]]:
			st.set_color(v[1])
			st.set_normal((Vector3.UP+out*0.4).normalized())
			st.set_uv(Vector2(0.0,(v[0] as Vector3).y))
			st.add_vertex(v[0])
	_tuft = st.commit()
	return _tuft

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

## A low shrub: a few lumpy balls, sage, darker underneath.
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
