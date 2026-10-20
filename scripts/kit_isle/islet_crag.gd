extends IsletUnit.Unit
## The islet unit's crag style (round 3, docs/design/isle-look/islet-unit-
## handoff.md): the same knobs and five bodies as round 2's Unit, built as a
## bold, steep-sided mass of broken rock rather than stacked plates.
##   Outline  a ragged polygon from above: corners, notches bitten in, points
##            jutting, each edge broken at a column or two. The rock's columns
##            are its vertices, so the turf's rim lies on the rock's edge.
##   Cliff    tiers down the face. Each tier's columns are grouped into
##            buttresses and fins that jut, lean and step; between tiers the
##            face steps in (an up-facing ledge, mossed) or out (an overhang
##            in shade), and each buttress's tier lines sit a little higher or
##            lower than its neighbour's, so the bands break and offset.
##            Each block is smooth inside and hard at its edges (smooth groups).
##   Under    the mass narrows in ragged, faceted rings to a broken keel, and
##            angular fangs hang from it in a cluster (by body), with short
##            ones off the overhangs.
##   Top      the rock's own cap runs in under the turf from the rim and breaks
##            up through it in stretches along the edge (rock-out), so the grass
##            ends raggedly at rock; low slabs and knobs break through inside.
##            The grass (KitFlora's carpet, as round 2) grows to the cliff edge
##            where turf reaches it. No sod hem or drape: the lip is rock, a
##            notch of shadow under it.
##   Landmark one lone tree (the game's hero trees, scripts/kit_isle/
##            motif_authored.gd TREES), or a RuinKit ruin seated on the turf,
##            or nothing (spec `landmark`).
##   Debris   rock fragments round and under it (scripts/kit_isle/
##            islet_debris.gd), densest just under, some turning.
## The vertex colour: r baked shade, g green carried down the face, b the
## block's band offset (broken strata), a the topsoil skin under the rim
## (shaders/islet_crag.gdshader).

const CRAG_SHADER := preload("res://shaders/islet_crag.gdshader")
const Debris = preload("res://scripts/kit_isle/islet_debris.gd")
const HangingRoots = preload("res://scripts/kit_isle/hanging_roots.gd")

## The ruins a unit may carry (RuinKit ids), and the trees
## (motif_authored.gd TREES ids, the oak the most).
const RUINS := ["arch","wall","pier","buttress","lancet_wall","stone_circle","aqueduct_stump","rose_gable","arch","wall","turret"]
const TREES := ["tree_oak","tree_oak","tree_birch"]

## The rock's columns: angle, radius and point (land-local) each; which
## buttress each belongs to; the rim's rock-out (m over the turf, or below
## zero under it) at each.
var col_a := PackedFloat32Array()
var col_p: Array = []
var col_grp := PackedInt32Array()
var rock_out := PackedFloat32Array()
## The cap's rings (u, a share of the rim) and its height at each column.
const CAP_U := [1.0,0.965,0.92,0.86,0.78,0.68]
var cap: Array = []
## The cliff's depth and its tiers.
var cliff := 1.0
var tiers := 3
## The rows of the body: Array of Array[Vector3] over the columns, and each
## row's [ao, green, soil, kind] (kind: 0 rim, 1 lip, 2 under-lip, 3 tier
## top, 4 tier foot, 5 underside).
var rows: Array = []
var row_meta: Array = []
var row_tier: Array = []
## Per column baked shade for a row, where it differs by column (empty: the
## row's own).
var row_ao: Array = []
## The ledges: (tier, column) where the tier steps out under the one over it.
var ledge_at := {}
var under_from := 0
var bottom_pt := Vector3.ZERO
var col_count := 0

func _init(knobs: Dictionary) -> void:
	super(knobs)
	# Crags run a little shallower for their top than round 2's bodies, but
	# their cliff is most of it.
	match body:
		SLAB: depth = R*(0.6+0.35*deep_in)
		BOULDER: depth = R*(1.0+0.4*deep_in)
		CONE: depth = R*(1.35+0.6*deep_in)
		CLUSTER: depth = R*(1.5+0.8*deep_in)
		SPIRE: depth = R*(2.1+1.0*deep_in)
	lip_droop = clampf(R*0.04,0.22,0.5)

## A ragged polygon: corners round, some notched in, some jutting, each
## edge broken at a point or two; stretched for a slab or a spire, cut
## straight across on a slab. Its vertices are the rock's columns.
func _outline() -> void:
	var n := clampi(int(7.0+R*0.6),8,17)
	var stretch := 1.0+rng.randf_range(0.0,0.35)
	match body:
		SLAB: stretch = rng.randf_range(1.35,1.75)
		SPIRE: stretch = rng.randf_range(1.4,1.9)
		BOULDER: stretch = rng.randf_range(1.0,1.25)
	var turn := rng.randf()*TAU
	var w := float(k.weather)
	var corners: Array = []
	for i in n:
		var a := TAU*(i+rng.randf_range(-0.32,0.32))/n
		var r := 1.0+rng.randf_range(-0.1,0.1)
		var roll_ := rng.randf()
		if roll_ < 0.14+0.14*w: r *= rng.randf_range(0.66,0.82)
		elif roll_ > 0.86: r *= rng.randf_range(1.08,1.16)
		var c := cos(a-turn)
		r *= lerpf(1.0,stretch,c*c)/sqrt(stretch)
		corners.append(Vector2.from_angle(a)*R*r)
	if body == SLAB:
		for cut in rng.randi_range(1,2):
			var ca := rng.randf()*TAU
			var cd := rng.randf_range(0.6,0.78)*R
			var nrm := Vector2.from_angle(ca)
			for i in corners.size():
				var p: Vector2 = corners[i]
				var off := p.dot(nrm)
				if off > cd: corners[i] = p-nrm*(off-cd)
	# Each edge broken at a point or two, pushed in or out a little.
	var pts: Array = []
	for i in corners.size():
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i+1)%corners.size()]
		pts.append(a)
		var mids := clampi(int(a.distance_to(b)/maxf(R*0.28,1.0)),1,3)
		for m in mids:
			var t := (m+1.0)/(mids+1.0)+rng.randf_range(-0.12,0.12)/mids
			var q := a.lerp(b,t)
			pts.append(q*(1.0+rng.randf_range(-0.06,0.05)))
	pts.sort_custom(func(p: Vector2, q: Vector2) -> bool: return wrapf(p.angle(),0.0,TAU) < wrapf(q.angle(),0.0,TAU))
	col_count = pts.size()
	for p: Vector2 in pts:
		col_p.append(p)
		col_a.append(wrapf(p.angle(),0.0,TAU))
	# The dense rim (the turf's, the grass's) on the polygon's edges.
	radii.resize(segs)
	for j in segs:
		var d := Vector2.from_angle(TAU*j/segs)
		radii[j] = _hit(d)
	# Buttresses: runs of 1-3 columns.
	col_grp.resize(col_count)
	var g := 0
	var left := 0
	for c in col_count:
		if left <= 0:
			g += 1
			left = rng.randi_range(1,3)
		col_grp[c] = g
		left -= 1

## Where the ray from the middle along `d` leaves the polygon (its radius).
func _hit(d: Vector2) -> float:
	var a := wrapf(d.angle(),0.0,TAU)
	for i in col_count:
		var a0 := col_a[i]
		var a1 := col_a[(i+1)%col_count]
		var span := wrapf(a1-a0,0.0,TAU)
		if wrapf(a-a0,0.0,TAU) <= span:
			var p: Vector2 = col_p[i]
			var e: Vector2 = (col_p[(i+1)%col_count] as Vector2)-p
			var den := d.cross(e)
			if absf(den) < 1e-6: return p.length()
			return p.cross(e)/den
	return R

## The column wedge an angle falls in and how far across: [i, t].
func _wedge_of(a: float) -> Array:
	a = wrapf(a,0.0,TAU)
	for i in col_count:
		var a0 := col_a[i]
		var span := wrapf(col_a[(i+1)%col_count]-a0,0.0,TAU)
		var off := wrapf(a-a0,0.0,TAU)
		if off <= span: return [i,off/maxf(span,1e-5)]
	return [0,0.0]

# --- The top -------------------------------------------------------------------------

## The rock-out along the rim: stretches where the rock stands up through
## the turf at the edge (more with weather), the rest under the turf.
func _rock_out() -> void:
	var n := IsletUnit._noise(seed_value*7+11,1.3,2)
	var w := float(k.weather)
	var tall := clampf(R*0.06,0.18,0.75)
	rock_out.resize(col_count)
	for c in col_count:
		var v := IsletUnit._ring(n,col_a[c],1.0)+rng.randf_range(-0.25,0.25)
		var thresh := lerpf(0.35,-0.05,w)+float(k.get("flat",0.0))*0.5
		if v > thresh: rock_out[c] = tall*clampf((v-thresh)*3.0,0.25,1.0)*rng.randf_range(0.7,1.3)
		else: rock_out[c] = -1.0
	# The cap: its rows in from the rim, each column's height there.
	cap.clear()
	for ui in CAP_U.size():
		var u: float = CAP_U[ui]
		var row: Array = []
		for c in col_count:
			var p: Vector2 = (col_p[c] as Vector2)*u
			var ty := top_y(p,u)
			var o := rock_out[c]
			var y: float
			if o > 0.0:
				# Out: highest at the rim, sloping in and under.
				var fall: float = [1.0,0.95,0.7,0.35,-0.1,-0.6][ui]
				y = ty+o*fall-(0.0 if fall > 0.0 else 0.25)+rng.randf_range(-0.06,0.06)*o
			else:
				y = ty-(0.03 if ui == 0 else 0.3)
			row.append(Vector3(p.x,y,p.y))
		cap.append(row)

## The cap's height under p (between its rows and columns), or -INF in
## from its last row.
func cap_at(p: Vector2) -> float:
	var wt := _wedge_of(p.angle())
	var i := int(wt[0])
	var t := float(wt[1])
	var rr := rim_at(p.angle())
	var u := p.length()/maxf(rr,0.01)
	var last: float = CAP_U[-1]
	if u < last: return -INF
	for ui in CAP_U.size()-1:
		var u0: float = CAP_U[ui]
		var u1: float = CAP_U[ui+1]
		if u <= u0 and u >= u1:
			var s := (u0-u)/maxf(u0-u1,1e-4)
			var a0: Vector3 = cap[ui][i]
			var a1: Vector3 = cap[ui][(i+1)%col_count]
			var b0: Vector3 = cap[ui+1][i]
			var b1: Vector3 = cap[ui+1][(i+1)%col_count]
			return lerpf(lerpf(a0.y,a1.y,t),lerpf(b0.y,b1.y,t),s)
	return (cap[0][i] as Vector3).y

## The turf's height under p for the grass: the rim is the rock's edge;
## where the cap's rock stands up through the turf, nothing.
func ground_at(p: Vector2) -> float:
	var a := p.angle()
	var r := rim_at(a)
	var l := p.length()
	if l > r*0.995: return NAN
	var h := top_y(p,l/maxf(r,0.01))
	if cap_at(p) > h-0.06: return NAN
	return h

# --- The body ------------------------------------------------------------------------

func _envelope(t: float, bottom: float) -> float:
	match body:
		SLAB: return lerpf(1.0,0.9,t)
		BOULDER: return lerpf(1.0,0.88,t*t)
		CONE: return lerpf(1.0,0.82,t)
		CLUSTER: return lerpf(1.0,0.9,t)
		SPIRE: return lerpf(1.0,0.5,pow(t,1.2))
	return lerpf(1.0,bottom,t)

## Hashed 0..1 by keys (stable for a seed).
func _h(a: Variant, b: Variant = 0, c: Variant = 0) -> float:
	return float(hash([seed_value,a,b,c]) % 10007)/10007.0

func _body_rings() -> void:
	_rock_out()
	var w := float(k.weather)
	var share := 0.5
	match body:
		SLAB: share = 0.62
		BOULDER: share = rng.randf_range(0.66,0.78)
		CONE: share = lerpf(0.34,0.46,deep_in)
		CLUSTER: share = rng.randf_range(0.26,0.34)
		SPIRE: share = 0.82
	cliff = depth*share
	mass = cliff
	lop_dir = Vector2.from_angle(rng.randf()*TAU)
	var lop := lop_dir*R*0.25*float(k.lopsided)
	match body:
		SLAB: bottom_sc = rng.randf_range(0.3,0.45)
		BOULDER: bottom_sc = rng.randf_range(0.3,0.42)
		CLUSTER: bottom_sc = rng.randf_range(0.55,0.7)
		SPIRE: bottom_sc = rng.randf_range(0.12,0.2)
		_: bottom_sc = lerpf(0.32,0.2,deep_in)
	# The buttresses' fins (each its jut through the tiers) and leans.
	var groups := int(col_grp[col_count-1])+1
	var fin := PackedFloat32Array()
	fin.resize(groups)
	for g in groups: fin[g] = rng.randf_range(-1.0,1.0)
	var tier_h := maxf(1.1,R*0.17)*rng.randf_range(0.85,1.2)
	tiers = clampi(int(round(cliff/tier_h)),2,7)
	# The rim, the rock lip and the notch under it.
	var lip_h := clampf(R*0.04,0.22,0.5)
	var r0: Array = []
	var r1: Array = []
	var r2: Array = []
	for c in col_count:
		var p: Vector2 = col_p[c]
		var top := (cap[0][c] as Vector3).y
		r0.append(Vector3(p.x,top,p.y))
		var q := p*1.012
		var y1 := top-lip_h*rng.randf_range(0.8,1.25)-(0.15 if rock_out[c] > 0.0 else 0.0)
		r1.append(Vector3(q.x,y1,q.y))
		# The notch under the lip: deep under some buttresses, hardly there
		# under others, so it isn't one groove round the whole rim.
		var nh := _h("notch",col_grp[c])
		var s := p*(lerpf(0.86,0.93,nh/0.4) if nh < 0.4 else lerpf(0.975,0.995,nh))
		r2.append(Vector3(s.x,y1-lip_h*0.5,s.y))
	_row(r0,[1.0,1.0,1.0,0])
	_row(r1,[0.85,0.85,0.8,1])
	_row(r2,[0.28,0.4,0.25,2])
	# The tiers' lines: each buttress's own, offset from its neighbours'.
	var weights: Array = []
	var total := 0.0
	for t in tiers:
		var wt := rng.randf_range(0.6,1.4)
		weights.append(wt)
		total += wt
	var bounds: Array = []
	var y_start := 0.0
	for c in col_count: y_start += (r2[c] as Vector3).y
	y_start /= col_count
	var acc := 0.0
	for t in tiers+1:
		var base := lerpf(y_start,-cliff,acc/total)
		var line := PackedFloat32Array()
		line.resize(col_count)
		for c in col_count:
			var jit := 0.0
			if t > 0 and t < tiers: jit = (_h("line",col_grp[c],t)-0.5)*cliff/tiers*0.55
			var yb := base+jit
			if t == 0: yb = minf(yb,(r2[c] as Vector3).y-0.05)
			line[c] = yb
		bounds.append(line)
		if t < tiers: acc += float(weights[t])
	# Each column's scale carried down the tiers: at each tier line a
	# buttress runs on straight (the line only a seam the bands break at),
	# steps in (the tier over it overhangs, its foot in shade) or steps out
	# (a ledge facing up under the tier over it, where moss and grass take);
	# its face leans in or out down each tier.
	var prev := PackedFloat32Array()
	prev.resize(col_count)
	for t in tiers:
		var t0 := float(t)/tiers
		var t1 := float(t+1)/tiers
		var e0 := _envelope(t0,bottom_sc)
		var e1 := _envelope(t1,bottom_sc)
		var top_row: Array = []
		var foot_row: Array = []
		var top_ao := PackedFloat32Array()
		for c in col_count:
			var g := col_grp[c]
			var d := Vector2.from_angle(col_a[c])
			var rr := (col_p[c] as Vector2).length()
			var face_lean := lerpf(-0.07,0.045,_h("lean",g,t))
			var sa: float
			var drop := 0.0
			var ao := 0.9
			if t == 0:
				sa = 0.97*(1.0+0.07*fin[g]*(0.5+w))
			else:
				var kind_roll := _h("step",g,t)
				if kind_roll < 0.36:
					sa = prev[c]
				elif kind_roll < 0.68:
					sa = prev[c]*lerpf(0.86,0.95,_h("in",g,t))
					drop = lerpf(0.03,0.16,_h("drop",g,t))
					ao = 0.42
				else:
					sa = prev[c]*lerpf(1.04,1.1,_h("out",g,t))
					drop = lerpf(0.04,0.14,_h("drop",g,t))
					ao = 0.85
					ledge_at[Vector2i(t,c)] = true
			var sb := sa*(e1/e0)*(1.0+face_lean)
			prev[c] = sb
			var ya: float = float(bounds[t][c])-drop
			var yb: float = float(bounds[t+1][c])
			ya = _wedged(ya,d)
			yb = _wedged(yb,d)
			var deep_a := clampf(-ya/maxf(depth,0.01),0.0,1.0)
			var deep_b := clampf(-yb/maxf(depth,0.01),0.0,1.0)
			var lo_a := 1.0+0.45*float(k.lopsided)*d.dot(lop_dir)*deep_a
			var lo_b := 1.0+0.45*float(k.lopsided)*d.dot(lop_dir)*deep_b
			var ca := lop*t0+lean_dir*lean*(-ya)
			var cb := lop*t1+lean_dir*lean*(-yb)
			var pa := ca+d*rr*sa*lo_a+d*(lump.get_noise_3d(d.x*9.0,ya,d.y*9.0))*minf(R*0.025,0.25)
			var pb := cb+d*rr*sb*lo_b+d*(lump.get_noise_3d(d.x*9.0,yb,d.y*9.0))*minf(R*0.025,0.25)
			top_row.append(Vector3(pa.x,ya,pa.y))
			foot_row.append(Vector3(pb.x,yb,pb.y))
			top_ao.append(ao)
		var green := 0.15 if t == 0 else 0.0
		_row(top_row,[0.72,green,0.0,3],t,top_ao)
		# A row across the face's middle, bulged or dished a little at each
		# column, so a block's face isn't one plane.
		var mid_row: Array = []
		for c in col_count:
			var a: Vector3 = top_row[c]
			var b: Vector3 = foot_row[c]
			var m := a.lerp(b,lerpf(0.38,0.62,_h("mid_t",c,t)))
			var out := Vector3(m.x,0.0,m.z).normalized()
			m += out*(_h("mid",c,t)-0.45)*minf(R*0.06,0.6)
			mid_row.append(m)
		_row(mid_row,[0.86,green*0.5,0.0,6],t)
		_row(foot_row,[0.92,0.0,0.0,4],t)
	# The underside: ragged faceted rings narrowing to the keel.
	under_from = rows.size()
	var steps := 4 if body != SPIRE else 3
	var tip := lop+lean_dir*lean*depth
	var foot: Array = rows[-1]
	for s in range(1,steps+1):
		var f := float(s)/steps
		var row: Array = []
		var y := -cliff-(depth-cliff)*pow(f,0.85)
		var sc := lerpf(_envelope(1.0,bottom_sc),bottom_sc,pow(f,1.2))
		var c0 := lop.lerp(tip,f)+lean_dir*lean*(-y)*0.0
		for c in col_count:
			var d := Vector2.from_angle(col_a[c])
			var rr := (col_p[c] as Vector2).length()
			var ragged := 1.0+(_h("under",col_grp[c],s)-0.5)*0.5+(_h("under_c",c,s)-0.5)*0.16
			var yy := _wedged(y,d)+(_h("under_y",c,s)-0.5)*(depth-cliff)/steps*0.7
			var fp: Vector3 = foot[c]
			var p := c0+d*rr*sc*ragged
			yy = minf(yy,fp.y-0.2)
			row.append(Vector3(p.x,yy,p.y))
		_row(row,[lerpf(0.7,0.45,f),0.0,0.0,5],-1)
		foot = row
	var lowest := 0.0
	for v: Vector3 in foot: lowest = minf(lowest,v.y)
	bottom_pt = Vector3(tip.x,lowest-R*0.04,tip.y)
	stats.beds = tiers

func _wedged(y: float, d: Vector2) -> float:
	if wedge <= 0.0: return y
	return y*(1.0+wedge*d.dot(wedge_dir))

func _row(r: Array, meta: Array, tier := -1, ao := PackedFloat32Array()) -> void:
	rows.append(r)
	row_meta.append(meta)
	row_tier.append(tier)
	row_ao.append(ao)

## The rock: the cap, the rim and lip, the tiers' faces and ledges, the
## underside and its keel, the fangs; then knobs and slabs through the turf
## and a spire's shard, faceted.
func _rock_mesh() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The cap, its faces flat (broken stone).
	for ui in CAP_U.size()-1:
		for c in col_count:
			var c1 := (c+1)%col_count
			var a: Vector3 = cap[ui][c]
			var b: Vector3 = cap[ui][c1]
			var cc: Vector3 = cap[ui+1][c1]
			var d: Vector3 = cap[ui+1][c]
			var out_ := rock_out[c] > 0.0 or rock_out[c1] > 0.0
			var col := Color(0.95 if out_ else 0.6,0.6,_h("cap",c),0.0)
			_face(st,-1,a,b,cc,col,col,col)
			_face(st,-1,a,cc,d,col,col,col)
	# The body's rows.
	for i in rows.size()-1:
		var ma: Array = row_meta[i]
		var mb: Array = row_meta[i+1]
		var kind_a := int(ma[3])
		var kind_b := int(mb[3])
		for c in col_count:
			var c1 := (c+1)%col_count
			var a: Vector3 = rows[i][c]
			var b: Vector3 = rows[i][c1]
			var cc: Vector3 = rows[i+1][c1]
			var d: Vector3 = rows[i+1][c]
			var g := col_grp[c]
			# A block: a tier's face for a buttress (smooth inside, hard at
			# its edges); a ledge or a step between tiers, the lip and the
			# underside, flat.
			var group := -1
			var band := 0.5
			if (kind_a == 3 and kind_b == 6) or (kind_a == 6 and kind_b == 4):
				group = 1+(hash([g,int(row_tier[i])]) & 0xffff)
				band = _h("band",g,row_tier[i])
			elif kind_a <= 2:
				group = 70000+g
				band = 0.5
			else:
				band = _h("band",g,row_tier[i+1] if kind_b == 3 else row_tier[i])
			# Soil and green on the rim's rows only where the turf runs to
			# the edge (not on rock-out).
			var turf_a := 1.0 if rock_out[c] <= 0.0 else 0.25
			var turf_b := 1.0 if rock_out[c1] <= 0.0 else 0.25
			var aa: PackedFloat32Array = row_ao[i]
			var ab: PackedFloat32Array = row_ao[i+1]
			var ao_a0 := aa[c] if aa.size() > 0 else float(ma[0])
			var ao_a1 := aa[c1] if aa.size() > 0 else float(ma[0])
			var ao_b0 := ab[c] if ab.size() > 0 else float(mb[0])
			var ao_b1 := ab[c1] if ab.size() > 0 else float(mb[0])
			var ca := Color(ao_a0,float(ma[1])*turf_a,band,float(ma[2])*turf_a)
			var cb := Color(ao_a1,float(ma[1])*turf_b,band,float(ma[2])*turf_b)
			var cc_ := Color(ao_b1,float(mb[1])*turf_b,band,float(mb[2])*turf_b)
			var cd := Color(ao_b0,float(mb[1])*turf_a,band,float(mb[2])*turf_a)
			_face(st,group,a,cc,b,ca,cc_,cb)
			_face(st,group,a,d,cc,ca,cd,cc_)
	# The keel: the last row closed to a point.
	var last: Array = rows[-1]
	for c in col_count:
		var c1 := (c+1)%col_count
		var col := Color(0.4,0.0,_h("keel",c),0.0)
		_face(st,-1,last[c],bottom_pt,last[c1],col,Color(0.35,0,col.b,0),col)
	_fangs(st)
	st.generate_normals()
	var mesh := st.commit()
	# Knobs, slabs, a shard: faceted.
	var knobs := SurfaceTool.new()
	knobs.begin(Mesh.PRIMITIVE_TRIANGLES)
	knobs.set_smooth_group(-1)
	_knobs_on_top(knobs)
	_slabs_on_top(knobs)
	_shard(knobs)
	if not keep_out.is_empty():
		knobs.generate_normals()
		knobs.commit(mesh)
	var mi := MeshInstance3D.new()
	mi.name = "Rock"
	mi.mesh = mesh
	mi.material_override = IsletUnit.crag_material(rng,float(k.weather),R,-depth*1.15)
	return mi

## One triangle, its smooth group (-1 flat), its corners' colours; and its
## collision.
func _face(st: SurfaceTool, group: int, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	st.set_smooth_group(group if group >= 0 else -1)
	for v: Array in [[a,ca],[b,cb],[c,cc]]:
		st.set_color(v[1])
		st.add_vertex(v[0])
	collide.append_array(PackedVector3Array([a,b,c]))

## The fangs: angular, stepped, hanging in a cluster by body; short ones
## off the overhangs.
func _fangs(st: SurfaceTool) -> void:
	var drip := float(k.drip)
	var under: Array = rows[-1]
	var below := maxf(depth-cliff,R*0.3)
	var out := 0
	var spots: Array = []
	match body:
		CLUSTER:
			var n := clampi(int(round(lerpf(9.0,4.0,drip)+rng.randf_range(-0.6,0.6)+R/10.0)),4,10)
			for i in n:
				var lead := i == 0
				var r0 := R*(rng.randf_range(0.18,0.26) if lead else rng.randf_range(0.09,0.18))
				var long_ := below*(rng.randf_range(1.0,1.3) if lead else rng.randf_range(0.35,0.95)*lerpf(1.0,0.75,drip))
				spots.append([lead,r0,long_,0.15 if lead else lerpf(0.35,0.8,sqrt(float(i)/n))])
		CONE:
			spots.append([true,R*bottom_sc*lerpf(0.5,0.7,drip),below*lerpf(0.8,1.3,drip),0.0])
			for i in clampi(int(round(lerpf(8.0,4.0,drip)+R/10.0)),4,10):
				spots.append([false,R*rng.randf_range(0.07,0.15),below*rng.randf_range(0.25,0.75),rng.randf_range(0.3,0.85)])
		BOULDER:
			for i in rng.randi_range(3,6):
				spots.append([i == 0,R*rng.randf_range(0.1,0.2),below*rng.randf_range(0.35,0.85),0.1 if i == 0 else rng.randf_range(0.3,0.8)])
		SLAB:
			for i in rng.randi_range(3,5):
				spots.append([false,R*rng.randf_range(0.08,0.15),depth*rng.randf_range(0.25,0.6),-1.0])
		SPIRE:
			spots.append([true,R*bottom_sc*0.6,R*rng.randf_range(0.5,0.9),0.0])
			for i in rng.randi_range(1,3):
				spots.append([false,R*rng.randf_range(0.04,0.08),R*rng.randf_range(0.2,0.45),rng.randf_range(0.4,0.8)])
	var turn := rng.randf()*TAU
	for i in spots.size():
		var s: Array = spots[i]
		var at: Vector3
		var r0 := float(s[1])
		if float(s[3]) < 0.0:
			# Along the slab's deep edge.
			var best := 0
			var best_d := -INF
			for c in col_count:
				var dd := Vector2.from_angle(col_a[c]).dot(wedge_dir)+rng.randf_range(-0.4,0.4)
				if dd > best_d:
					best_d = dd
					best = c
			var v: Vector3 = under[best]
			at = Vector3(v.x,v.y,v.z).lerp(Vector3(bottom_pt.x,v.y,bottom_pt.z),0.45)
		elif float(s[3]) == 0.0 or bool(s[0]):
			at = bottom_pt+Vector3(rng.randf_range(-0.1,0.1),0.0,rng.randf_range(-0.1,0.1))*R
		else:
			var a := turn+i*2.39996
			var wt := _wedge_of(a)
			var v: Vector3 = under[int(wt[0])]
			var share := float(s[3])
			at = bottom_pt.lerp(v,share)
			at.y = lerpf(bottom_pt.y,v.y,share*share)
		var long_ := maxf(float(s[2]),r0*2.4)
		var bend := Vector2.from_angle(rng.randf()*TAU)*long_*rng.randf_range(0.04,0.14)+lean_dir*lean*0.5*long_
		_fang(st,at+Vector3(0.0,r0*0.9,0.0),r0,long_+r0*0.9,bend)
		out += 1
		# A small one beside a big one now and then: a crag cluster.
		if r0 > R*0.08 and rng.randf() < 0.55:
			var side := Vector3.FORWARD.rotated(Vector3.UP,rng.randf()*TAU)*r0*rng.randf_range(0.9,1.3)
			_fang(st,at+side+Vector3(0.0,r0*0.7,0.0),r0*rng.randf_range(0.35,0.55),long_*rng.randf_range(0.3,0.6),bend*0.5)
			out += 1
	# Off the overhangs: where a tier's foot stands out past the next top.
	var side_n := int(rng.randf_range(1.0,5.0)*(1.1-drip)*clampf(R/6.0,0.5,1.6))
	for n in side_n:
		var i := 5+3*rng.randi_range(0,maxi(tiers-2,0))
		if i >= under_from: continue
		var c := rng.randi()%col_count
		var p: Vector3 = rows[i][c]
		var mid := Vector3(bottom_pt.x,p.y,bottom_pt.z)
		var at := mid.lerp(p,0.9)
		var r0 := R*rng.randf_range(0.03,0.08)
		_fang(st,at+Vector3(0,r0*0.6,0),r0,r0*rng.randf_range(2.5,6.0),Vector2.from_angle(rng.randf()*TAU)*r0)
		out += 1
	stats.drips = out

## A fang: angular rings (few sides, each corner its own radius) narrowing
## to a point, stepping in now and then; flat faces.
func _fang(st: SurfaceTool, top: Vector3, r0: float, long_: float, bend: Vector2) -> void:
	var sides := 5 if r0 < R*0.12 else 6
	var steps := clampi(int(long_/maxf(r0*0.9,0.5)),3,9)
	var turn := rng.randf()*TAU
	var corner := PackedFloat32Array()
	for j in sides: corner.append(rng.randf_range(0.7,1.25))
	var band := rng.randf()
	var rings_: Array = []
	var aos: Array = []
	for s in steps+1:
		var t := float(s)/steps
		var want := r0*pow(1.0-t,0.8)
		if s > 0 and s < steps and rng.randf() < 0.3: want *= 0.8
		var c := Vector2(top.x,top.z)+bend*t*t
		var row: Array = []
		for j in sides:
			var a := turn+TAU*j/sides+(rng.randf_range(-0.15,0.15) if s > 0 else 0.0)
			var q := c+Vector2.from_angle(a)*want*corner[j]*rng.randf_range(0.9,1.1)
			row.append(Vector3(q.x,top.y-long_*t+rng.randf_range(-0.05,0.05)*long_/steps,q.y))
		rings_.append(row)
		aos.append(0.3 if s == 0 else (0.55 if s == 1 else 0.8))
	for s in rings_.size()-1:
		for j in sides:
			var a: Vector3 = rings_[s][j]
			var b: Vector3 = rings_[s][(j+1)%sides]
			var cc: Vector3 = rings_[s+1][(j+1)%sides]
			var d: Vector3 = rings_[s+1][j]
			var c0 := Color(float(aos[s]),0,band,0)
			var c1 := Color(float(aos[s+1]),0,band,0)
			_face(st,-1,a,cc,b,c0,c1,c0)
			_face(st,-1,a,d,cc,c0,c1,c1)
	if float(k.growth) > 0.25 and rng.randf() < 0.25*float(k.growth):
		var at: Vector3 = rings_[1][rng.randi()%sides]
		root_list.append(Vector4(at.x,at.y,at.z,long_*rng.randf_range(0.3,0.7)))

## The knobs', slabs' and shard's faces (Unit `_stone`): no topsoil skin,
## a little green, a band offset of their own.
func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ca: Color, cb: Color, cc: Color, cd: Color) -> void:
	var band := float(hash([a.x,a.z]) % 1000)/1000.0
	for v: Array in [[a,ca],[c,cc],[b,cb],[a,ca],[d,cd],[c,cc]]:
		var col: Color = v[1]
		st.set_color(Color(col.r,0.3,band,0.0))
		st.add_vertex(v[0])
	collide.append_array(PackedVector3Array([a,c,b,a,d,c]))

## Low slabs breaking through the turf: broad, tilted, cracked plates.
func _slabs_on_top(st: SurfaceTool) -> void:
	var n := int(rng.randf_range(0.0,1.6)+float(k.weather)*1.8+R/10.0)
	var flat := float(k.get("flat",0.0))
	for i in n:
		var p := Vector2.from_angle(rng.randf()*TAU)*R*rng.randf_range(0.25,0.75)
		# A flat crown (landing turf) keeps its slabs out at the rim.
		if flat > 0.0 and p.length() < R*lerpf(0.25,0.8,flat): continue
		var w := clampf(R*rng.randf_range(0.08,0.18),0.5,2.4)
		var h := w*rng.randf_range(0.3,0.6)
		var prof := [[0.0,1.0],[0.55,0.96],[0.75,0.8],[1.0,0.55]]
		_stone(st,p,h,w,rng.randf_range(0.4,0.75),rng.randf()*TAU,Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(0.15,0.45),prof,6)

# --- The crown, the landmark, roots ----------------------------------------------------

## The turf: a polar grid out to the rock's rim (KitLook's ground), no lip.
func _turf_mesh(root: Node3D) -> void:
	var ground := KitLook.GroundMesh.new()
	var tone: Callable = KitLook.turf(seed_value)
	var us := [0.0,0.1,0.2,0.3,0.4,0.5,0.6,0.68,0.76,0.83,0.89,0.94,0.975,1.0]
	var grid: Array = []
	for u: float in us:
		var row: Array = []
		for j in segs:
			var p := dir(j)*rim(j)*u
			row.append(Vector3(p.x,top_y(p,u),p.y))
		grid.append(row)
	for i in us.size()-1:
		for j in segs:
			var a: Vector3 = grid[i][j]
			var b: Vector3 = grid[i][(j+1)%segs]
			var c: Vector3 = grid[i+1][(j+1)%segs]
			var d: Vector3 = grid[i+1][j]
			var tris: Array = [[a,c,d]] if i == 0 else [[a,b,c],[a,c,d]]
			for t: Array in tris:
				var mid := Vector2((t[0] as Vector3).x+(t[1] as Vector3).x+(t[2] as Vector3).x,(t[0] as Vector3).z+(t[1] as Vector3).z+(t[2] as Vector3).z)/3.0
				var col: Color = tone.call(mid,Vector3.UP,rng.randf_range(-0.008,0.008),((t[0] as Vector3).y+(t[1] as Vector3).y+(t[2] as Vector3).y)/3.0)
				ground.add(t[0],t[1],t[2],col)
				collide.append_array(PackedVector3Array([t[0],t[2],t[1]]))
	_hem = []
	for j in segs: _hem.append(grid[-1][j])
	var g := ground.node("Ground")
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(g)

func _drape_mesh() -> MeshInstance3D:
	return null

## The landmark (before the grass, so the grass keeps off its foot): a
## lone tree or a ruin seated on the turf.
var landmark_node: Node3D = null
var landmark_tree := false
var landmark_yaw := 0.0

func _landmark(root: Node3D) -> void:
	var want := int(k.get("landmark",-1))
	var lr := RandomNumberGenerator.new()
	lr.seed = hash(["islet_landmark",seed_value])
	if want < 0:
		var roll_ := lr.randf()
		want = 0
		if R >= 2.5 and roll_ < 0.42: want = 1
		elif R >= 4.0 and roll_ < 0.8: want = 2
	if want == 0: return
	var authored: GDScript = load("res://scripts/kit_isle/motif_authored.gd")
	var ground := func(x: float, z: float) -> float:
		var q := Vector2(x,z)
		return top_y(q,clampf(q.length()/maxf(rim_at(q.angle()),0.01),0.0,1.0))
	for tries in 6:
		var id_name: String = TREES[lr.randi()%TREES.size()] if want == 1 else RUINS[lr.randi()%RUINS.size()]
		var piece_seed := lr.randi()
		var piece_worn := lr.randf_range(0.55,0.95)
		var piece: Node3D = authored.make(id_name,piece_seed,piece_worn)
		if piece == null: continue
		# How to build it again (a ruin broken in play: crag_reach --olmec).
		piece.set_meta("landmark_spec",[id_name,piece_seed,piece_worn])
		var box: AABB = authored.drawn_box(piece) if want == 2 else authored.piece_box(piece)
		var span := maxf(box.size.x,box.size.z)
		if want == 2 and span > R*1.25:
			piece.free()
			continue
		var turn := lr.randf_range(0.0,360.0)
		var p := shoulder_dir*R*lr.randf_range(0.05,0.3)+Vector2.from_angle(lr.randf()*TAU)*R*lr.randf_range(0.0,0.2)
		if want == 2:
			# A ruin keeps its footprint in from the rim.
			var room := minf(R*0.8-span*0.5,R*0.4)
			p = p.limit_length(maxf(room,0.0))
		if is_nan(ground_at(p)): p *= 0.4
		if want == 1:
			_light_tree(piece)
			var size := clampf(R/7.0,0.45,1.15)
			var look := piece.get_node_or_null("Look") as Node3D
			if look != null: look.scale *= size
			for b: Node in piece.find_children("*","CollisionShape3D",true,false):
				(b as CollisionShape3D).scale = Vector3.ONE*size
				(b as CollisionShape3D).position *= size
		var y := float(authored.seat(ground,piece,p.x,p.y,turn,0.15 if want == 2 else 0.1))
		piece.transform = Transform3D(Basis(Vector3.UP,deg_to_rad(turn)),Vector3(p.x,y,p.y))
		piece.name = "Landmark"
		root.add_child(piece)
		landmark_node = piece
		landmark_tree = want == 1
		landmark_yaw = deg_to_rad(turn)
		# The grass keeps off its foot: the trunk's, or the ruin's box.
		if want == 1:
			keep_out.append(Vector3(p.x,p.y,0.6))
		else:
			var basis := Basis(Vector3.UP,deg_to_rad(turn))
			var nx := maxi(1,int(box.size.x/1.2))
			var nz := maxi(1,int(box.size.z/1.2))
			for ix in nx+1:
				for iz in nz+1:
					var lp := box.position+Vector3(box.size.x*ix/nx,0.0,box.size.z*iz/nz)
					var wp := basis*lp
					keep_out.append(Vector3(p.x+wp.x,p.y+wp.z,0.75))
		stats.landmark = id_name
		return

## The tree's parts drawn in the sky's light as the rock is (the look
## rig's hemisphere fill into their shade; the scene's own ambient is off),
## their colour and tint kept.
static var _tree_sh: Shader = null
static func _light_tree(piece: Node3D) -> void:
	if _tree_sh == null:
		_tree_sh = Shader.new()
		_tree_sh.code = """shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
uniform vec3 tint : source_color = vec3(1.0);
global uniform vec3 zs_hemi_sky;
global uniform vec3 zs_hemi_ground;
global uniform float zs_hemi_energy;
void fragment() {
	if (!FRONT_FACING) NORMAL = -NORMAL;
	vec3 c = COLOR.rgb * tint;
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	ALBEDO = c;
	EMISSION = c * mix(zs_hemi_ground, zs_hemi_sky, wn.y * 0.5 + 0.5) * zs_hemi_energy / PI * 1.3;
	ROUGHNESS = 1.0;
}
"""
	for n: Node in piece.find_children("*","MeshInstance3D",true,false):
		var mi := n as MeshInstance3D
		var src := mi.mesh.surface_get_material(0) as BaseMaterial3D
		var mat := ShaderMaterial.new()
		mat.shader = _tree_sh
		var t := src.albedo_color if src != null else Color.WHITE
		mat.set_shader_parameter("tint",t)
		mi.material_override = mat

func _crown(root: Node3D) -> void:
	var g := float(k.growth)
	if g >= IsletUnit.GRASS_FROM and float(k.get("grass",1.0)) > 0.0:
		var site := KitFlora.Site.new()
		IsletUnit.flora_carpet().carpeted(site)
		site.probe = probe
		site.tufts *= lerpf(IsletUnit.GRASS_THICK.x,IsletUnit.GRASS_THICK.y,g)
		site.shag *= lerpf(IsletUnit.GRASS_SHAG.x,IsletUnit.GRASS_SHAG.y,g)
		site.rim = 0.02
		var outline := PackedVector2Array()
		for j in segs: outline.append(dir(j)*rim(j)*0.993)
		var job := KitFlora.Grow.new(hash(["islet_flora",seed_value]) & 0xffffff,null,[],[outline],site)
		while not job.step(-1): pass
		var flora: Node3D = job.node
		flora.name = "Flora"
		root.add_child(flora)
		IsletUnit.flora_carpet().calm(flora)
		stats.grass = (flora.get_meta("counts") as Dictionary).duplicate()
		stats.grass_triangles = int(flora.get_meta("triangles"))

## Grass on the ledges: the carpet's, short, over each ledge's strip
## (between the foot of the tier over it and the top of its own), probed
## on the strip's own faces.
var _ledges: Array = []

func _ledge_grass(root: Node3D) -> void:
	var g := float(k.growth)
	if g < 0.2 or float(k.get("grass",1.0)) <= 0.0: return
	var outlines: Array = []
	for key: Vector2i in ledge_at:
		var t := key.x
		var c := key.y
		var c1 := (c+1)%col_count
		if not ledge_at.has(Vector2i(t,c1)): continue
		var above: Array = rows[5+3*(t-1)]
		var own: Array = rows[3+3*t]
		var quad: Array = [above[c],above[c1],own[c1],own[c]]
		var poly := PackedVector2Array()
		for v: Vector3 in quad: poly.append(Vector2(v.x,v.z))
		if absf(KitLand.area(Array(poly))) < 0.08: continue
		_ledges.append(quad)
		outlines.append(poly)
	if outlines.is_empty(): return
	var site := KitFlora.Site.new()
	IsletUnit.flora_carpet().carpeted(site)
	site.probe = _ledge_probe
	site.tufts *= lerpf(0.5,1.0,g)
	site.shag *= 0.35
	site.rim = 0.0
	var job := KitFlora.Grow.new(hash(["islet_ledges",seed_value]) & 0xffffff,null,[],outlines,site)
	while not job.step(-1): pass
	var flora: Node3D = job.node
	flora.name = "LedgeFlora"
	root.add_child(flora)
	IsletUnit.flora_carpet().calm(flora)
	stats.ledges = _ledges.size()
	stats.ledge_grass = int((flora.get_meta("counts") as Dictionary).get("grass_tuft",0))

## The ledge's height under p (on either of its quad's two faces), or NAN.
func _ledge_probe(p: Vector2, _reach: float) -> float:
	for q: Array in _ledges:
		for tri: Array in [[q[0],q[1],q[2]],[q[0],q[2],q[3]]]:
			var a: Vector3 = tri[0]
			var b: Vector3 = tri[1]
			var c: Vector3 = tri[2]
			var bc := _bary(p,Vector2(a.x,a.z),Vector2(b.x,b.z),Vector2(c.x,c.z))
			if bc.x >= -0.01 and bc.y >= -0.01 and bc.z >= -0.01: return a.y*bc.x+b.y*bc.y+c.y*bc.z
	return NAN

static func _bary(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> Vector3:
	var v0 := b-a
	var v1 := c-a
	var v2 := p-a
	var den := v0.x*v1.y-v1.x*v0.y
	if absf(den) < 1e-8: return Vector3(-1,-1,-1)
	var v := (v2.x*v1.y-v1.x*v2.y)/den
	var w := (v0.x*v2.y-v2.x*v0.y)/den
	return Vector3(1.0-v-w,v,w)

## Roots only where the rock cracks: under the rock lip where the turf runs
## to the edge, and from the overhangs' feet.
func _roots(root: Node3D) -> void:
	var g := float(k.growth)
	if g < 0.15: return
	var n := int(col_count*0.18*g)
	for i in n:
		var c := rng.randi()%col_count
		if rock_out[c] > 0.0: continue
		var p: Vector3 = (rows[2][c] as Vector3).lerp(rows[2][(c+1)%col_count],rng.randf())
		root_list.append(Vector4(p.x*0.99,p.y+0.05,p.z*0.99,rng.randf_range(0.6,2.2)*clampf(R*0.2,0.6,2.0)*(0.6+g)))
	for i in range(5,under_from,3):
		if rng.randf() > 0.3*g: continue
		var c := rng.randi()%col_count
		var p: Vector3 = rows[i][c]
		root_list.append(Vector4(p.x,p.y,p.z,rng.randf_range(0.6,1.8)*clampf(R*0.2,0.6,2.2)*(0.5+g)))
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

func make() -> Node3D:
	var root := Node3D.new()
	root.name = "IsletUnit"
	root.set_meta("knobs",k.duplicate())
	root.set_meta("body",IsletUnit.BODIES[body])
	root.set_meta("style","crag")
	_body_rings()
	var rock := _rock_mesh()
	root.add_child(rock)
	_turf_mesh(root)
	_landmark(root)
	_crown(root)
	_ledge_grass(root)
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
	if tilt > 0.0:
		var t := Transform3D(Basis(tilt_axis,tilt),Vector3.ZERO)
		for c: Node in root.get_children():
			if c is Node3D: (c as Node3D).transform = t*(c as Node3D).transform
		# A tree stands up plumb on its foot.
		if landmark_node != null and landmark_tree:
			landmark_node.basis = Basis(Vector3.UP,landmark_yaw)
	var outline: Array = []
	for j in segs: outline.append(dir(j)*rim(j))
	root.set_meta("outline",outline)
	root.set_meta("depth",depth)
	root.set_meta("radius",R)
	var tris := 0
	for mi: Node in root.find_children("*","MeshInstance3D",true,false):
		var m := (mi as MeshInstance3D).mesh
		if m == null: continue
		for s in m.get_surface_count(): tris += m.surface_get_array_index_len(s)/3 if m.surface_get_format(s) & Mesh.ARRAY_FORMAT_INDEX else m.surface_get_array_len(s)/3
	stats.triangles = tris
	stats.body = IsletUnit.BODIES[body]
	# The debris round and under it.
	if float(k.get("debris",1.0)) > 0.0:
		var deb: Node3D = Debris.around(seed_value,R,depth,outline,float(k.get("debris",1.0)),tilt_axis,tilt)
		root.add_child(deb)
		stats.debris = int(deb.get_meta("count",0))
	root.set_meta("stats",stats)
	return root
