extends RefCounted
## The Hollow Child's clay (scripts/city_hollow_child.gd; card x5-hollow in
## docs/design/roguelike/brainstorm/round4-strange-city/lens3-exploitable.md):
## an Olmec hollow "were-baby", seated, legs splayed, hands lifted to its
## chin, the head a little too big, heavy-lidded, an open dark mouth. Built
## as a signed distance field (blended ellipsoids and tapered capsules, the
## mouth, eyes and navel cut in) and meshed by surface nets on a grid, its
## normals from the field's gradient. Two meshes: the body, and the head
## (its origin the neck pivot, so it can turn).
##
## Vertex colours carry what the clay shader (shaders/hollow_child_clay.gdshader)
## paints from:
##   r  crevice: concave places (the field's Laplacian below zero) and the
##      mouth and eye slits, for grime (baked; model-budget "vertex-colour grime")
##   g  wear: convex high points (Laplacian above zero) and the knees, nose,
##      toes, knuckles and cheekbones, where the white slip is worn through
##      to the red clay
##   b  thin: the cheeks, the belly, the thigh tops, where the light inside
##      shows through like a lampshade
##   a  cavity: inside the open mouth (dark, and where the light pours out)
##
## Sizes are in the figure's own metres before its node's scale (about 1.25
## tall here; scripts/city_hollow_child.gd draws it at the wanderer's
## crouch). Slow in GDScript (a few seconds): tools/bake_hollow_child.gd
## bakes it to BODY_RES and HEAD_RES with generated LODs, and the piece
## loads those, building here only when they are missing.

const BODY_RES := "res://art/hollow_child/hollow_child_body.res"
const HEAD_RES := "res://art/hollow_child/hollow_child_head.res"
## The neck pivot, in the figure's space: the head mesh's origin.
const NECK := Vector3(0.0,0.80,0.0)
## Figure height (m, its own space), for the shader's climbing glow.
const TALL := 1.28

## Primitive kinds.
enum {ELL,CAP,SPH}

## [kind, op (+1 add, -1 cut), blend k, ...]
##   ELL: centre, radii, (rotation Euler degrees)
##   CAP: a, b, radius at a, radius at b
##   SPH: centre, radius
static func body_prims() -> Array:
	var p: Array = []
	# Seat and pelvis, the fat belly, the chest, the shoulders.
	p.append([ELL,1,0.0,Vector3(0.0,0.22,-0.05),Vector3(0.36,0.22,0.30),Vector3.ZERO])
	p.append([ELL,1,0.09,Vector3(0.0,0.42,0.03),Vector3(0.33,0.28,0.29),Vector3(-8,0,0)])
	p.append([ELL,1,0.08,Vector3(0.0,0.62,-0.04),Vector3(0.29,0.19,0.22),Vector3.ZERO])
	p.append([CAP,1,0.07,Vector3(-0.24,0.70,-0.05),Vector3(0.24,0.70,-0.05),0.11,0.11])
	# The neck stump the head sits on.
	p.append([ELL,1,0.06,Vector3(0.0,0.78,-0.02),Vector3(0.15,0.08,0.14),Vector3.ZERO])
	for s: float in [-1.0,1.0]:
		# Legs splayed in a wide V, knees a little up, shins back in to the feet.
		var hip := Vector3(0.17*s,0.17,0.02)
		var knee := Vector3(0.47*s,0.25,0.36)
		var ankle := Vector3(0.40*s,0.10,0.67)
		p.append([CAP,1,0.07,hip,knee,0.17,0.125])
		p.append([CAP,1,0.05,knee,ankle,0.12,0.08])
		p.append([ELL,1,0.04,Vector3(0.39*s,0.11,0.73),Vector3(0.08,0.075,0.12),Vector3(-25,8*s,0)])
		# Toes: a little row of bumps on the foot's front.
		for t in 3:
			p.append([SPH,1,0.015,Vector3((0.36+0.03*t)*s,0.15,0.82-0.01*t),0.03])
		# Arms: shoulder, elbow out and forward, the hands up at the chin.
		var sh := Vector3(0.27*s,0.69,-0.04)
		var el := Vector3(0.33*s,0.50,0.12)
		var wr := Vector3(0.15*s,0.67,0.25)
		p.append([CAP,1,0.05,sh,el,0.095,0.08])
		p.append([CAP,1,0.04,el,wr,0.08,0.06])
		# A fist, curled toward the mouth.
		p.append([ELL,1,0.03,Vector3(0.12*s,0.71,0.27),Vector3(0.065,0.075,0.06),Vector3(0,0,20*s)])
		# Knuckles.
		for k in 3:
			p.append([SPH,1,0.012,Vector3((0.08+0.025*k)*s,0.755-0.012*k,0.31),0.022])
	# The navel.
	p.append([SPH,-1,0.02,Vector3(0.0,0.40,0.32),0.025])
	return p

## The head, in the figure's space (the mesh is moved to NECK after).
static func head_prims() -> Array:
	var p: Array = []
	# The cranium: wide and a touch flat on top, too big for the body.
	p.append([ELL,1,0.0,Vector3(0.0,1.03,-0.01),Vector3(0.275,0.255,0.27),Vector3.ZERO])
	# The jaw and the heavy jowls; the fat cheeks.
	p.append([ELL,1,0.08,Vector3(0.0,0.89,0.06),Vector3(0.20,0.11,0.17),Vector3.ZERO])
	for s: float in [-1.0,1.0]:
		p.append([SPH,1,0.07,Vector3(0.135*s,0.925,0.13),0.115])
		# The puffed lids, over the slit.
		p.append([ELL,1,0.025,Vector3(0.10*s,1.035,0.215),Vector3(0.075,0.035,0.04),Vector3(0,0,-10*s)])
		# Ears: flat, low, set back.
		p.append([ELL,1,0.03,Vector3(0.27*s,0.98,-0.01),Vector3(0.03,0.07,0.05),Vector3(0,0,-8*s)])
	# The broad flat nose.
	p.append([ELL,1,0.03,Vector3(0.0,0.96,0.255),Vector3(0.06,0.045,0.05),Vector3.ZERO])
	# The thick down-turned upper lip and a heavy lower lip round the open mouth.
	p.append([ELL,1,0.02,Vector3(0.0,0.912,0.25),Vector3(0.085,0.026,0.035),Vector3(0,0,0)])
	p.append([ELL,1,0.02,Vector3(0.0,0.858,0.238),Vector3(0.06,0.018,0.03),Vector3.ZERO])
	# The neck that meets the body's stump.
	p.append([CAP,1,0.05,Vector3(0.0,0.78,-0.01),Vector3(0.0,0.9,0.0),0.13,0.15])
	# Cuts: the eyes (heavy-lidded slits, outer corners low), the open
	# down-turned mouth, deep into the hollow.
	for s: float in [-1.0,1.0]:
		p.append([ELL,-1,0.012,Vector3(0.10*s,1.018,0.245),Vector3(0.062,0.013,0.04),Vector3(0,0,-12*s)])
		# The mouth's down-turned corners.
		p.append([CAP,-1,0.012,Vector3(0.035*s,0.885,0.245),Vector3(0.075*s,0.866,0.22),0.02,0.012])
	p.append([ELL,-1,0.02,Vector3(0.0,0.885,0.22),Vector3(0.06,0.032,0.10),Vector3.ZERO])
	p.append([ELL,-1,0.03,Vector3(0.0,0.92,0.08),Vector3(0.10,0.07,0.14),Vector3.ZERO])
	return p

## The mouth's cut (for the cavity channel), in the figure's space.
const MOUTH := [Vector3(0.0,0.885,0.22),Vector3(0.0,0.92,0.08)]

# --- The field ----------------------------------------------------------------------------

static func _smin(a: float, b: float, k: float) -> float:
	if k <= 0.0: return minf(a,b)
	var h := clampf(0.5+0.5*(b-a)/k,0.0,1.0)
	return lerpf(b,a,h)-k*h*(1.0-h)

static func _smax(a: float, b: float, k: float) -> float:
	return -_smin(-a,-b,k)

## Prepared primitives: each its kind, op, k and what its distance needs.
static func _prep(prims: Array) -> Array:
	var out: Array = []
	for q: Array in prims:
		var kind: int = q[0]
		match kind:
			ELL:
				var rot: Vector3 = q[5]
				var b := Basis.from_euler(Vector3(deg_to_rad(rot.x),deg_to_rad(rot.y),deg_to_rad(rot.z)))
				out.append([ELL,q[1],q[2],q[3],q[4],b.inverse()])
			CAP:
				out.append([CAP,q[1],q[2],q[3],q[4],q[5],q[6]])
			SPH:
				out.append([SPH,q[1],q[2],q[3],q[4]])
	return out

static func _prim(q: Array, p: Vector3) -> float:
	match int(q[0]):
		ELL:
			var c: Vector3 = q[3]
			var r: Vector3 = q[4]
			var ib: Basis = q[5]
			var l := ib*(p-c)
			var k0 := Vector3(l.x/r.x,l.y/r.y,l.z/r.z).length()
			var k1 := Vector3(l.x/(r.x*r.x),l.y/(r.y*r.y),l.z/(r.z*r.z)).length()
			if k1 < 1e-6: return -minf(r.x,minf(r.y,r.z))
			return k0*(k0-1.0)/k1
		CAP:
			var a: Vector3 = q[3]
			var b: Vector3 = q[4]
			var ab := b-a
			var t := clampf((p-a).dot(ab)/ab.length_squared(),0.0,1.0)
			return p.distance_to(a+ab*t)-lerpf(float(q[5]),float(q[6]),t)
		SPH:
			return p.distance_to(q[3])-float(q[4])
	return INF

static func field(prep: Array, p: Vector3) -> float:
	var d := INF
	for q: Array in prep:
		var pd := _prim(q,p)
		if int(q[1]) > 0:
			d = pd if d == INF else _smin(d,pd,float(q[2]))
		else:
			d = _smax(d,-pd,float(q[2]))
	return d

static func _grad(prep: Array, p: Vector3, h := 0.004) -> Vector3:
	var g := Vector3(
		field(prep,p+Vector3(h,0,0))-field(prep,p-Vector3(h,0,0)),
		field(prep,p+Vector3(0,h,0))-field(prep,p-Vector3(0,h,0)),
		field(prep,p+Vector3(0,0,h))-field(prep,p-Vector3(0,0,h)))
	return g.normalized() if g.length() > 1e-9 else Vector3.UP

# --- Surface nets ------------------------------------------------------------------------

## The surface of `prep` inside `box` at `cell` m: {verts, normals, indices}.
static func nets(prep: Array, box: AABB, cell: float) -> Dictionary:
	var nx := int(ceil(box.size.x/cell))+1
	var ny := int(ceil(box.size.y/cell))+1
	var nz := int(ceil(box.size.z/cell))+1
	var o := box.position
	var vals := PackedFloat32Array()
	vals.resize(nx*ny*nz)
	for k in nz:
		for j in ny:
			for i in nx:
				vals[i+nx*(j+ny*k)] = field(prep,o+Vector3(i,j,k)*cell)
	var cx := nx-1
	var cy := ny-1
	var cz := nz-1
	var cell_v := PackedInt32Array()
	cell_v.resize(cx*cy*cz)
	cell_v.fill(-1)
	var verts := PackedVector3Array()
	var corners := [Vector3i(0,0,0),Vector3i(1,0,0),Vector3i(0,1,0),Vector3i(1,1,0),Vector3i(0,0,1),Vector3i(1,0,1),Vector3i(0,1,1),Vector3i(1,1,1)]
	var edges := [[0,1],[2,3],[4,5],[6,7],[0,2],[1,3],[4,6],[5,7],[0,4],[1,5],[2,6],[3,7]]
	for k in cz:
		for j in cy:
			for i in cx:
				var v8: Array[float] = []
				var neg := 0
				for c: Vector3i in corners:
					var v := vals[(i+c.x)+nx*((j+c.y)+ny*(k+c.z))]
					v8.append(v)
					if v < 0.0: neg += 1
				if neg == 0 or neg == 8: continue
				var sum := Vector3.ZERO
				var n := 0
				for e: Array in edges:
					var a: float = v8[e[0]]
					var b: float = v8[e[1]]
					if (a < 0.0) == (b < 0.0): continue
					var t := a/(a-b)
					var ca: Vector3i = corners[e[0]]
					var cb: Vector3i = corners[e[1]]
					sum += Vector3(ca).lerp(Vector3(cb),t)
					n += 1
				var p := o+(Vector3(i,j,k)+sum/n)*cell
				# Onto the surface: a Newton step or two along the gradient.
				for _s in 2:
					var d := field(prep,p)
					p -= _grad(prep,p)*d
				cell_v[i+cx*(j+cy*k)] = verts.size()
				verts.append(p)
	var idx := PackedInt32Array()
	# Each grid edge that changes sign: a quad of the four cells round it.
	for k in range(1,cz):
		for j in range(1,cy):
			for i in range(1,cx):
				var v0 := vals[i+nx*(j+ny*k)]
				for axis in 3:
					var dv := Vector3i(1,0,0) if axis == 0 else (Vector3i(0,1,0) if axis == 1 else Vector3i(0,0,1))
					var ii := i+dv.x
					var jj := j+dv.y
					var kk := k+dv.z
					if ii >= nx or jj >= ny or kk >= nz: continue
					var v1 := vals[ii+nx*(jj+ny*kk)]
					if (v0 < 0.0) == (v1 < 0.0): continue
					# The four cells sharing this edge.
					var q: Array[int] = []
					var ok := true
					var offs: Array
					if axis == 0: offs = [Vector3i(0,0,0),Vector3i(0,-1,0),Vector3i(0,-1,-1),Vector3i(0,0,-1)]
					elif axis == 1: offs = [Vector3i(0,0,0),Vector3i(0,0,-1),Vector3i(-1,0,-1),Vector3i(-1,0,0)]
					else: offs = [Vector3i(0,0,0),Vector3i(-1,0,0),Vector3i(-1,-1,0),Vector3i(0,-1,0)]
					for f: Vector3i in offs:
						var ci := i+f.x
						var cj := j+f.y
						var ck := k+f.z
						if ci < 0 or cj < 0 or ck < 0 or ci >= cx or cj >= cy or ck >= cz:
							ok = false
							break
						var vi := cell_v[ci+cx*(cj+cy*ck)]
						if vi < 0:
							ok = false
							break
						q.append(vi)
					if not ok: continue
					# Wound so the face looks out (inside to outside along the edge).
					if v0 < 0.0:
						idx.append_array([q[0],q[1],q[2],q[0],q[2],q[3]])
					else:
						idx.append_array([q[0],q[2],q[1],q[0],q[3],q[2]])
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for vi in verts.size(): normals[vi] = _grad(prep,verts[vi])
	# Godot's front faces wind clockwise: (b-a) x (c-a) points in, against
	# the field's normal. Each triangle checked against its corners' normals.
	for t in range(0,idx.size(),3):
		var a := verts[idx[t]]
		var b := verts[idx[t+1]]
		var c := verts[idx[t+2]]
		var nn := normals[idx[t]]+normals[idx[t+1]]+normals[idx[t+2]]
		if (b-a).cross(c-a).dot(nn) > 0.0:
			var s := idx[t+1]
			idx[t+1] = idx[t+2]
			idx[t+2] = s
	return {"verts":verts,"normals":normals,"indices":idx}

# --- The paint channels -------------------------------------------------------------------

## Spots worn to the red clay: [centre, radius] in the figure's space.
static func wear_spots() -> Array:
	var w: Array = []
	for s: float in [-1.0,1.0]:
		w.append([Vector3(0.49*s,0.34,0.38),0.11])   # knee
		w.append([Vector3(0.38*s,0.17,0.83),0.05])   # toes
		w.append([Vector3(0.10*s,0.76,0.32),0.04])   # knuckles
		w.append([Vector3(0.19*s,0.98,0.18),0.04])   # cheekbone
		w.append([Vector3(0.33*s,0.48,0.15),0.05])   # elbow
	w.append([Vector3(0.0,0.985,0.29),0.03])         # nose tip
	w.append([Vector3(0.0,0.47,0.33),0.08])          # belly
	w.append([Vector3(0.05,1.24,0.02),0.12])         # crown
	return w

## Where the light inside shows through: [centre, radius].
static func thin_spots() -> Array:
	var t: Array = []
	for s: float in [-1.0,1.0]:
		t.append([Vector3(0.15*s,0.93,0.18),0.14])   # cheek
		t.append([Vector3(0.3*s,0.27,0.22),0.14])    # thigh top
	t.append([Vector3(0.0,0.43,0.30),0.2])           # belly
	t.append([Vector3(0.0,0.62,0.18),0.12])          # chest
	return t

static func _spots(p: Vector3, spots: Array) -> float:
	var m := 0.0
	for s: Array in spots:
		var d := p.distance_to(s[0])/float(s[1])
		m = maxf(m,exp(-d*d*1.6))
	return m

## Vertex colours for `verts` (see the header) on the field `prep`.
static func paint(prep: Array, verts: PackedVector3Array, normals: PackedVector3Array) -> PackedColorArray:
	var cols := PackedColorArray()
	cols.resize(verts.size())
	var h := 0.03
	var mouth_prep := _prep([[ELL,1,0.0,MOUTH[0],Vector3(0.075,0.05,0.12),Vector3.ZERO],[ELL,1,0.0,MOUTH[1],Vector3(0.12,0.09,0.16),Vector3.ZERO]])
	for i in verts.size():
		var p := verts[i]
		var n := normals[i]
		# The Laplacian at the surface (curvature): + convex, - concave.
		var lap := 0.0
		for a: Vector3 in [Vector3(h,0,0),Vector3(0,h,0),Vector3(0,0,h)]:
			lap += field(prep,p+a)+field(prep,p-a)
		lap = lap/(h*h)
		# A short ambient occlusion: the field a little way out along the
		# normal, against how far out it was sampled.
		var ao := 0.0
		for s: float in [0.03,0.07]:
			ao += clampf((s-field(prep,p+n*s))/s,0.0,1.0)
		ao *= 0.5
		var crev := clampf(-lap*0.025,0.0,1.0)*0.55+ao*0.7
		var convex := clampf(lap*0.02-0.25,0.0,1.0)
		var wear := clampf(convex*0.5+_spots(p,wear_spots())*0.85,0.0,1.0)
		var thin := _spots(p,thin_spots())
		var cav := 1.0 if field(mouth_prep,p) < 0.012 and n.z < 0.9 else 0.0
		if cav > 0.0: crev = maxf(crev,0.8)
		cols[i] = Color(clampf(crev,0.0,1.0),wear,thin,cav)
	return cols

## The figure's mesh (`head` or the body), LODs generated when `lods`.
static func build(head: bool, cell := 0.022, lods := false) -> ArrayMesh:
	var prep := _prep(head_prims() if head else body_prims())
	var box := AABB(Vector3(-0.36,0.70,-0.33),Vector3(0.72,0.62,0.66)) if head else AABB(Vector3(-0.65,-0.04,-0.40),Vector3(1.30,0.92,1.30))
	var got := nets(prep,box,cell*(0.75 if head else 1.0))
	var verts: PackedVector3Array = got.verts
	var normals: PackedVector3Array = got.normals
	var cols := paint(prep,verts,normals)
	# The figure's own height in UV2.x for the shader (its feet 0 .. crown 1),
	# the head's verts moved to its pivot.
	var uv2 := PackedVector2Array()
	uv2.resize(verts.size())
	for i in verts.size():
		uv2[i] = Vector2(verts[i].y/TALL,0.0)
		if head: verts[i] -= NECK
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = got.indices
	if lods:
		var im := ImporterMesh.new()
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES,arrays)
		im.generate_lods(60.0,25.0,[])
		return im.get_mesh()
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return m

## The baked meshes [body, head], or built now (slow) when not baked.
static func meshes() -> Array:
	if ResourceLoader.exists(BODY_RES) and ResourceLoader.exists(HEAD_RES):
		return [load(BODY_RES),load(HEAD_RES)]
	push_warning("hollow child: no baked mesh (tools/bake_hollow_child.gd); building it now")
	return [build(false,0.03),build(true,0.03)]
