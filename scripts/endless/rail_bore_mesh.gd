extends RefCounted
## The railroad tunnels' meshes (rail_bore.gd places and frees them): a
## piece of a bore's lining with its ribs, refuges, drains and the members
## stood in it, and the portals, all from the layout (rail_bore_plan.gd)
## and the cross-section (rail_bore_shape.gd). Surfaces carry the lining
## shader's UVs (shaders/rail_bore_lining.gdshader): UV along and round in
## m, UV2 the surface kind (K_*) and its soot.
##
## The visible surface never stands proud of what the plan answers for:
## rough rock is pushed out of the bore, a rock's pillar or spur pulled into
## its box, a heap's stones under its top.

const BoreShape = preload("res://scripts/endless/rail_bore_shape.gd")
const Plan = preload("res://scripts/endless/rail_bore_plan.gd")

## Surface kinds (the shader's).
const K_ASHLAR := 0.0
const K_BRICK := 1.0
const K_ROCK := 2.0
const K_TIMBER := 3.0
const K_FLOOR := 4.0
const K_DRAIN := 5.0
const K_DRESSED := 6.0
const K_IRON := 7.0
## Base tints.
const C_ASHLAR := Color(0.66,0.61,0.53)
const C_BRICK := Color(0.56,0.34,0.25)
const C_ROCK := Color(0.40,0.37,0.34)
const C_PORTAL_ROCK := Color(0.36,0.32,0.29)
const C_RUBBLE := Color(0.47,0.44,0.40)
const C_TIMBER := Color(0.46,0.33,0.22)
const C_FLOOR := Color(0.30,0.28,0.26)
const C_DRAIN := Color(0.16,0.15,0.14)
const C_DRESSED := Color(0.80,0.75,0.66)
const C_DRESSED_DARK := Color(0.52,0.46,0.39)
const C_IRON := Color(0.13,0.12,0.12)
const C_WASH := Color(0.80,0.78,0.72)
const SOOT_C := Color(0.08,0.07,0.065)
## Rings every RING m at most; the vault in VAULT_SEGS segments.
const RING := 3.0
## The lining's floor lies this far under the bed (the track's ballast on it).
const FLOOR_UNDER := 0.06
const VAULT_SEGS := 16
## The shader's scale for the height over the bed in the vertex alpha (m).
const HEIGHT_SCALE := 40.0
const INV_HEIGHT_SCALE := 1.0/HEIGHT_SCALE
## Rough rock: pushed out up to ROUGH_OUT m.
const ROUGH_OUT := 1.3
## Soot along the crown of a lined bore (the share of the vault's rise it
## covers, and how dark at the crown).
const CROWN_SOOT := 0.5
const SOOT_MOST := 0.55

## A mesh in the making: flat-shaded triangles, colours, both UVs.
class M:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	## Soot in the vertex colour (for a material that doesn't read UV2).
	var soot_in_color := false
	## The bed's height under this mesh's surfaces (NAN: not given); each
	## vertex's height over it goes in the vertex colour's alpha for the
	## shader's wear (dirt at a wall's foot, damp higher up).
	var base_y := NAN

	## The quad p[0..3] (in order round it), facing `face`'s side, its
	## corners' UVs `u`, kind `k`, soot per corner `soot`.
	func quad(p: Array, face: Vector3, col: Color, u: Array, k: float, soot := Vector4.ZERO) -> void:
		var a: Vector3 = p[0]
		var b: Vector3 = p[1]
		var cc: Vector3 = p[2]
		var d: Vector3 = p[3]
		var ua: Vector2 = u[0]
		var ub: Vector2 = u[1]
		var uc: Vector2 = u[2]
		var ud: Vector2 = u[3]
		var sa := soot.x
		var sb := soot.y
		var sc := soot.z
		var sd := soot.w
		var g := (b-a).cross(cc-a)+(cc-a).cross(d-a)
		if g.length_squared() < 1e-8: return
		if g.dot(face) > 0.0:
			var t := b
			b = d
			d = t
			var tu := ub
			ub = ud
			ud = tu
			var ts := sb
			sb = sd
			sd = ts
			g = -g
		var nn := -g.normalized()
		var pts := [a,b,cc,a,cc,d]
		var uvs := [ua,ub,uc,ua,uc,ud]
		var ss := [sa,sb,sc,sa,sc,sd]
		var tall := not is_nan(base_y)
		for i in 6:
			var pt: Vector3 = pts[i]
			v.append(pt)
			n.append(nn)
			var cc2 := col
			# (the colour's alpha saturates at 0..1 on its way into the mesh)
			if tall: cc2 = Color(col.r,col.g,col.b,(pt.y-base_y)*INV_HEIGHT_SCALE)
			if soot_in_color and ss[i] > 0.0:
				var sk := cc2.lerp(SOOT_C,clampf(float(ss[i]),0.0,1.0))
				sk.a = cc2.a
				c.append(sk)
			else: c.append(cc2)
			uv.append(uvs[i])
			uv2.append(Vector2(k,ss[i]))

	## A box from 8 corners (bottom 4 then top 4, each round in order),
	## its faces out from `mid`, UVs in m along `along` and up.
	func hull8(p: Array, mid: Vector3, col: Color, k: float, along: Vector3, cap_bottom := false) -> void:
		for i in 4:
			var j := (i+1)%4
			var q := [p[i],p[j],p[j+4],p[i+4]]
			var f: Vector3 = ((q[0]+q[1]+q[2]+q[3])*0.25)-mid
			quad(q,f,col,_uvs(q,along),k)
		var top := [p[4],p[5],p[6],p[7]]
		quad(top,Vector3.UP,col,_uvs(top,along),k)
		if cap_bottom:
			var bot := [p[0],p[1],p[2],p[3]]
			quad(bot,Vector3.DOWN,col,_uvs(bot,along),k)

	static func _uvs(q: Array, along: Vector3) -> Array:
		var out := []
		var o: Vector3 = q[0]
		for x: Vector3 in q: out.append(Vector2((x-o).dot(along)+o.dot(along),x.y))
		return out

	func empty() -> bool:
		return v.is_empty()

	func add_to(mesh: ArrayMesh, mat: Material) -> void:
		if v.is_empty(): return
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = v
		arrays[Mesh.ARRAY_NORMAL] = n
		arrays[Mesh.ARRAY_COLOR] = c
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		mesh.surface_set_material(mesh.get_surface_count()-1,mat)

	func instance(mat: Material) -> MeshInstance3D:
		var mesh := ArrayMesh.new()
		add_to(mesh,mat)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return mi

var plan: RefCounted
var line: RefCounted

func _init(bore_plan: RefCounted, rail_line: RefCounted) -> void:
	plan = bore_plan
	line = rail_line

## The world point at (s, d, y): y over the bed, d across (level).
func at(s: float, d: float, y: float) -> Vector3:
	var c: Vector3 = line.centre(s)
	var tg: Vector3 = line.tangent(s)
	var r := Vector3(-tg.z,0.0,tg.x).normalized()
	return c+r*d+Vector3.UP*y

func _right(s: float) -> Vector3:
	var tg: Vector3 = line.tangent(s)
	return Vector3(-tg.z,0.0,tg.x).normalized()

static func _h(a: int, b: int) -> float:
	return float(posmod(a*73856093^b*19349663,10007))/10007.0

## Smooth noise along s for point k of the ring (0..1).
static func _ns(s: float, k: int) -> float:
	var u := s/RING
	var i := floori(u)
	var t := u-i
	t = t*t*(3.0-2.0*t)
	return lerpf(_h(i,k),_h(i+1,k),t)

# --- The lining --------------------------------------------------------------------------

## The ring's profile at s with a rib's `inset`: Vector2(d, y) round from
## the left wall's foot, up, over the vault, down the right wall, across
## the floor (the right drain's edge, the left's) back to the start; and
## each point's outward way. WALL_N points before the vault.
func profile(s: float, inset: float) -> Array:
	var sc: Vector3 = plan.section(s)
	var h := sc.x-inset
	var sp := sc.y
	var r := sc.z-inset
	var pts := PackedVector2Array([Vector2(-h,0.0),Vector2(-h,Plan.REFUGE_H),Vector2(-h,sp)])
	var outs := PackedVector2Array([Vector2(-1,0),Vector2(-1,0),Vector2(-1,0)])
	for k in range(1,VAULT_SEGS):
		var th := PI*(1.0-float(k)/VAULT_SEGS)
		pts.append(Vector2(h*cos(th),sp+r*sin(th)))
		outs.append(Vector2(cos(th)*r,sin(th)*h).normalized())
	pts.append_array([Vector2(h,sp),Vector2(h,Plan.REFUGE_H),Vector2(h,0.0)])
	outs.append_array([Vector2(1,0),Vector2(1,0),Vector2(1,0)])
	var dr := minf(Plan.DRAIN,h*0.2)
	pts.append_array([Vector2(h-dr,0.0),Vector2(-h+dr,0.0)])
	outs.append_array([Vector2.ZERO,Vector2.ZERO])
	return [pts,outs]

## The ring at s: world points, and each one's distance round (UV y).
func ring(s: float, inset: float) -> Array:
	var prof: Array = profile(s,inset)
	var pts: PackedVector2Array = prof[0]
	var outs: PackedVector2Array = prof[1]
	var rough: float = plan.rough(s)
	var c: Vector3 = line.centre(s)+Vector3.DOWN*FLOOR_UNDER
	var r := _right(s)
	var w := PackedVector3Array()
	var round := PackedFloat32Array()
	var run := 0.0
	for k in pts.size():
		var p := pts[k]
		if k > 0: run += p.distance_to(pts[k-1])
		round.append(run)
		if rough > 0.0 and outs[k] != Vector2.ZERO:
			var o := outs[k]*rough*ROUGH_OUT*_ns(s,k)
			if p.y <= 0.01: o.y = 0.0
			p += o
		w.append(c+r*p.x+Vector3.UP*p.y)
	return [w,round,pts]

## The lining's look at s: [kind, tint] of the wall, and of a rib.
func _look(s: float, rib: bool) -> Array:
	match int(plan.lining(s)):
		Plan.ASHLAR: return [K_DRESSED,C_DRESSED] if rib else [K_ASHLAR,C_ASHLAR]
		Plan.BRICK: return [K_DRESSED,C_DRESSED_DARK] if rib else [K_BRICK,C_BRICK]
		Plan.TIMBER: return [K_TIMBER,C_TIMBER] if rib else [K_ROCK,C_ROCK]
	return [K_ROCK,C_ROCK]

func _soot(s: float, y: float) -> float:
	var kd := int(plan.lining(s))
	var sc: Vector3 = plan.section(s)
	var from := sc.y+sc.z*(1.0-CROWN_SOOT)
	var most := SOOT_MOST if kd in [Plan.ASHLAR,Plan.BRICK] else SOOT_MOST*0.6
	return smoothstep(from,sc.y+sc.z,y)*most

## A piece of lining s0..s1: {day: M, under: M, members: [{m: M, day}],
## lamps: [Vector3], heads: M (day), heads_under: M}. `day_in`: the first
## m from each face in the day.
func piece(s0: float, s1: float, day_in: float, ti: int) -> Dictionary:
	var out := {"day":M.new(),"under":M.new(),"members":[],"heads":M.new(),"heads_under":M.new()}
	var t: Dictionary = plan.tunnels[ti]
	var ts0 := float(t.s0)
	var ts1 := float(t.s1)
	# The rings' places: every RING m, and every break.
	var at_s := PackedFloat32Array([s0,s1])
	var n := maxi(1,ceili((s1-s0)/RING))
	for k in range(1,n): at_s.append(lerpf(s0,s1,float(k)/n))
	at_s.append_array(plan.breaks(s0,s1))
	at_s.sort()
	var pos := PackedFloat32Array()
	for s: float in at_s:
		if pos.is_empty() or s-pos[pos.size()-1] > 0.05: pos.append(s)
	var last_inset := NAN
	var last_ring: Array = []
	for k in pos.size()-1:
		var a := pos[k]
		var b := pos[k+1]
		var mid := (a+b)*0.5
		var ins: float = plan.inset(mid)
		var into := Plan.into_of(mid,ts0,ts1)
		var m: M = out.day if into < day_in else out.under
		var ra := last_ring if last_inset == ins else ring(a,ins)
		var rb := ring(b,ins)
		# A rib's side, where the inset steps.
		if is_nan(last_inset):
			var before: float = plan.inset(a-0.02)
			if before != ins: _step_face(m,ring(a,before),ra,a,before,ins)
		elif last_inset != ins:
			_step_face(m,last_ring,ra,a,last_inset,ins)
		last_inset = ins
		last_ring = rb
		_segment(m,ra,rb,a,b,ins > 0.0)
		# Refuges.
		for side: float in [-1.0,1.0]:
			var ri: int = plan.refuge_at(mid,side)
			if ri >= 0: _refuge_bay(m,a,b,side,ins)
	# Refuges' ends.
	for i in plan.refuge_s.size():
		var rs: float = plan.refuge_s[i]
		var side: float = plan.refuge_side[i]
		for e: float in [rs-Plan.REFUGE_W*0.5,rs+Plan.REFUGE_W*0.5]:
			if e < s0-0.01 or e > s1+0.01: continue
			var m: M = out.day if Plan.into_of(e,ts0,ts1) < day_in else out.under
			_refuge_end(m,e,side,1.0 if e < rs else -1.0)
	# The members whose middle is in this piece.
	for i: int in plan.members_near((s0+s1)*0.5,(s1-s0)*0.5+1.0):
		var c := (float(plan.ms0[i])+float(plan.ms1[i]))*0.5
		if c < s0 or c >= s1 or int(plan.mt[i]) != ti: continue
		var mm := M.new()
		_member(mm,i)
		out.members.append({"m":mm,"day":Plan.into_of(c,ts0,ts1) < day_in,"i":i})
	# The lamps' heads.
	var lamps: Array[Vector3] = []
	for i in plan.lamp_s.size():
		var s: float = plan.lamp_s[i]
		if s < s0 or s >= s1: continue
		var hm: M = out.heads if Plan.into_of(s,ts0,ts1) < day_in else out.heads_under
		var p := at(s,float(plan.lamp_d[i]),float(plan.lamp_y[i]))
		_lamp_head(hm,s,p)
		lamps.append(p)
	out["lamps"] = lamps
	return out

func _segment(m: M, ra: Array, rb: Array, sa: float, sb: float, rib: bool) -> void:
	var wa: PackedVector3Array = ra[0]
	var wb: PackedVector3Array = rb[0]
	var ua: PackedFloat32Array = ra[1]
	var ub: PackedFloat32Array = rb[1]
	var pa: PackedVector2Array = ra[2]
	var np := wa.size()
	var look: Array = _look((sa+sb)*0.5,rib)
	m.base_y = line.centre((sa+sb)*0.5).y
	var axis_a: Vector3 = line.centre(sa)+Vector3.UP*4.0
	var axis_b: Vector3 = line.centre(sb)+Vector3.UP*4.0
	var mid := (sa+sb)*0.5
	var pb: PackedVector2Array = rb[2]
	var kd := int(plan.lining(mid))
	var sc: Vector3 = plan.section(mid)
	var soot_from := sc.y+sc.z*(1.0-CROWN_SOOT)
	var soot_to := sc.y+sc.z
	var soot_most := SOOT_MOST if kd in [Plan.ASHLAR,Plan.BRICK] else SOOT_MOST*0.6
	var side_l: bool = plan.refuge_at(mid,-1.0) >= 0
	var side_r: bool = plan.refuge_at(mid,1.0) >= 0
	for q in np:
		var q1 := (q+1)%np
		# The wall's lower part over a refuge is open.
		if q == 0 and side_l: continue
		if q == np-5+1 and side_r: continue
		var kind: float = look[0]
		var col: Color = look[1]
		var floor_q := q >= np-3
		if floor_q:
			var drain := q != np-2
			kind = K_DRAIN if drain else K_FLOOR
			col = C_DRAIN if drain else C_FLOOR
		var p := [wa[q],wb[q],wb[q1],wa[q1]]
		var face: Vector3 = (axis_a+axis_b)*0.5-(wa[q]+wb[q1])*0.5
		var vq1 := ua[q1] if q1 > 0 else ua[np-1]+pa[np-1].distance_to(pa[0])
		var uvs := [Vector2(sa,ua[q]),Vector2(sb,ub[q]),Vector2(sb,vq1),Vector2(sa,vq1)]
		if floor_q: uvs = [Vector2(sa,pa[q].x),Vector2(sb,pa[q].x),Vector2(sb,pa[q1].x),Vector2(sa,pa[q1].x)]
		var soot := Vector4.ZERO
		if not floor_q:
			soot = Vector4(smoothstep(soot_from,soot_to,pa[q].y),smoothstep(soot_from,soot_to,pb[q].y),smoothstep(soot_from,soot_to,pb[q1].y),smoothstep(soot_from,soot_to,pa[q1].y))*soot_most
		m.quad(p,face,col,uvs,kind,soot)

## The rib's side where the inset steps from `i0` to `i1` at s: between
## the two rings, facing the shallower side.
func _step_face(m: M, r0: Array, r1: Array, s: float, i0: float, i1: float) -> void:
	m.base_y = line.centre(s).y
	var w0: PackedVector3Array = r0[0]
	var w1: PackedVector3Array = r1[0]
	var tg: Vector3 = line.tangent(s)
	var face := -tg if i1 > i0 else tg
	var look: Array = _look(s+(0.05 if i1 > i0 else -0.05),true)
	var np := w0.size()
	for q in np-3:
		var q1 := q+1
		var p := [w0[q],w1[q],w1[q1],w0[q1]]
		var uvs := [Vector2(s,0),Vector2(s+0.5,0),Vector2(s+0.5,1),Vector2(s,1)]
		m.quad(p,face,look[1],uvs,look[0])

## The recess of a refuge on `side` over a..b: its back, top and floor.
func _refuge_bay(m: M, a: float, b: float, side: float, ins: float) -> void:
	m.base_y = line.centre((a+b)*0.5).y
	var ha: float = (plan.section(a) as Vector3).x-ins
	var hb: float = (plan.section(b) as Vector3).x-ins
	var deep := Plan.REFUGE_DEEP+ins
	var top := Plan.REFUGE_H
	var back := [at(a,side*(ha+deep),0.0),at(b,side*(hb+deep),0.0),at(b,side*(hb+deep),top),at(a,side*(ha+deep),top)]
	var inward := -_right((a+b)*0.5)*side
	m.quad(back,inward,C_WASH,[Vector2(a,0),Vector2(b,0),Vector2(b,top),Vector2(a,top)],K_ASHLAR)
	var roof := [at(a,side*ha,top),at(b,side*hb,top),at(b,side*(hb+deep),top),at(a,side*(ha+deep),top)]
	m.quad(roof,Vector3.DOWN,C_WASH,[Vector2(a,0),Vector2(b,0),Vector2(b,deep),Vector2(a,deep)],K_DRESSED)
	var flo := [at(a,side*ha,0.0),at(b,side*hb,0.0),at(b,side*(hb+deep),0.0),at(a,side*(ha+deep),0.0)]
	m.quad(flo,Vector3.UP,C_FLOOR,[Vector2(a,0),Vector2(b,0),Vector2(b,deep),Vector2(a,deep)],K_FLOOR)

func _refuge_end(m: M, s: float, side: float, way: float) -> void:
	m.base_y = line.centre(s).y
	var h: float = (plan.section(s) as Vector3).x
	var deep := Plan.REFUGE_DEEP+0.5
	var top := Plan.REFUGE_H
	var p := [at(s,side*(h-0.5),0.0),at(s,side*(h+deep),0.0),at(s,side*(h+deep),top),at(s,side*(h-0.5),top)]
	var tg: Vector3 = line.tangent(s)
	m.quad(p,tg*way,C_WASH,[Vector2(0,0),Vector2(deep,0),Vector2(deep,top),Vector2(0,top)],K_ASHLAR)

func _lamp_head(m: M, s: float, p: Vector3) -> void:
	var r := _right(s)*0.28
	var f := Vector3(line.tangent(s).x,0.0,line.tangent(s).z).normalized()*0.28
	var u := Vector3.UP*0.32
	var pts := [p-r-f-u,p+r-f-u,p+r+f-u,p-r+f-u,p-r-f+u,p+r-f+u,p+r+f+u,p-r+f+u]
	m.hull8(pts,p,Color(1.0,0.85,0.6),0.0,f.normalized(),true)

# --- Members --------------------------------------------------------------------------

func _member(m: M, i: int) -> void:
	m.base_y = line.centre((float(plan.ms0[i])+float(plan.ms1[i]))*0.5).y
	var s0: float = plan.ms0[i]
	var s1: float = plan.ms1[i]
	var d0: float = plan.md0[i]
	var d1: float = plan.md1[i]
	var y0: float = plan.my0[i]
	var y1: float = plan.my1[i]
	match int(plan.mk[i]):
		Plan.M_BOX:
			if int(plan.ml[i]) == Plan.L_IRON: _iron(m,s0,s1,d0,d1,y0,y1)
			else: _rock(m,i,s0,s1,d0,d1,y0,y1)
		Plan.M_PILE: _pile(m,i)
		Plan.M_ARCADE: _arcade(m,i)

func _iron(m: M, s0: float, s1: float, d0: float, d1: float, y0: float, y1: float) -> void:
	var s := (s0+s1)*0.5
	var mid := at(s,(d0+d1)*0.5,(y0+y1)*0.5)
	# An arm and a stay under it, inside the bracket's box.
	var arm := [at(s0,d0,y1-0.25),at(s1,d0,y1-0.25),at(s1,d1,y1-0.25),at(s0,d1,y1-0.25),at(s0,d0,y1),at(s1,d0,y1),at(s1,d1,y1),at(s0,d1,y1)]
	m.hull8(arm,mid,C_IRON,K_IRON,_right(s),true)

## A rock pillar or spur: an eight-sided mass in its box, its corners cut
## and its faces pulled in by its own noise, up in four courses.
func _rock(m: M, i: int, s0: float, s1: float, d0: float, d1: float, y0: float, y1: float) -> void:
	var lv := 4
	var sc: Vector3 = plan.section((s0+s1)*0.5)
	# Up into the vault: the pillar's top under the roof over its far side.
	var top := y1
	var roof_in: float = plan.roof_over((s0+s1)*0.5,minf(absf(d0),absf(d1)))
	if not is_nan(roof_in): top = minf(y1,roof_in+1.5)
	var ch := minf(0.9,minf(s1-s0,d1-d0)*0.25)
	var prev := PackedVector3Array()
	var mid := at((s0+s1)*0.5,(d0+d1)*0.5,(y0+top)*0.5)
	var ups := PackedFloat32Array()
	for l in lv: ups.append(lerpf(y0,top,float(l)/(lv-1)))
	var rings: Array[PackedVector3Array] = []
	for l in lv:
		var y := ups[l]
		var corners := [Vector2(s0+ch,d0),Vector2(s1-ch,d0),Vector2(s1,d0+ch),Vector2(s1,d1-ch),Vector2(s1-ch,d1),Vector2(s0+ch,d1),Vector2(s0,d1-ch),Vector2(s0,d0+ch)]
		var cs := Vector2((s0+s1)*0.5,(d0+d1)*0.5)
		var w := PackedVector3Array()
		for k in 8:
			var p: Vector2 = corners[k]
			var pull := 0.15+0.45*_h(i*31+l,k)
			p = p.lerp(cs,pull/maxf((p-cs).length(),0.1))
			w.append(at(p.x,p.y,y))
		rings.append(w)
	for l in lv-1:
		var a: PackedVector3Array = rings[l]
		var b: PackedVector3Array = rings[l+1]
		for k in 8:
			var k1 := (k+1)%8
			var q := [a[k],a[k1],b[k1],b[k]]
			var f: Vector3 = (a[k]+b[k1])*0.5-Vector3(mid.x,(a[k].y+b[k1].y)*0.5,mid.z)
			var ru := [Vector2(0,ups[l]),Vector2(1.5,ups[l]),Vector2(1.5,ups[l+1]),Vector2(0,ups[l+1])]
			for j in 4: ru[j] = Vector2(ru[j].x+k*1.5+i*3.0,ru[j].y)
			m.quad(q,f,C_ROCK*(0.9+0.2*_h(i,k+l*8)),ru,K_ROCK)
	var t: PackedVector3Array = rings[lv-1]
	var tc := Vector3.ZERO
	for p: Vector3 in t: tc += p/8.0
	for k in 8:
		var k1 := (k+1)%8
		m.quad([t[k],t[k1],tc,tc],Vector3.UP,C_ROCK,[Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)],K_ROCK)

## A rock fall: its top as the plan has it, each stone a little under.
func _pile(m: M, i: int) -> void:
	var s0: float = plan.ms0[i]
	var s1: float = plan.ms1[i]
	var d0: float = plan.md0[i]
	var d1: float = plan.md1[i]
	var ns := maxi(2,ceili((s1-s0)/1.4))
	var nd := maxi(2,ceili((d1-d0)/0.9))
	var grid: Array[PackedVector3Array] = []
	for a in ns+1:
		var s := lerpf(s0,s1,float(a)/ns)
		var row := PackedVector3Array()
		for b in nd+1:
			var d := lerpf(d0,d1,float(b)/nd)
			var y: float = plan.pile_top(i,s,d,0.0)
			y = maxf(y-Plan.PILE_JIT*2.0*_h(a+i*101,b),0.0)
			row.append(at(s,d,y))
		grid.append(row)
	for a in ns:
		for b in nd:
			var q := [grid[a][b],grid[a+1][b],grid[a+1][b+1],grid[a][b+1]]
			var col := C_RUBBLE*(0.82+0.3*_h(a*7+i,b*13))
			col.a = 1.0
			m.quad(q,Vector3.UP,col,[Vector2(q[0].x,q[0].z),Vector2(q[1].x,q[1].z),Vector2(q[2].x,q[2].z),Vector2(q[3].x,q[3].z)],K_ROCK)

## The arcade between the tracks: piers, arches, and the wall over them up
## into the vault.
func _arcade(m: M, i: int) -> void:
	var s0: float = plan.ms0[i]
	var s1: float = plan.ms1[i]
	var w := Plan.ARC_HALF
	var stops := PackedFloat32Array()
	var s := s0
	while s < s1-0.01:
		stops.append(s)
		var u := fposmod(s-s0,Plan.ARC_EVERY)
		if u < Plan.ARC_PIER-0.01: s = minf(s-u+Plan.ARC_PIER,s1)
		else: s = minf(minf(s+1.0,s-u+Plan.ARC_EVERY),s1)
	stops.append(s1)
	for k in stops.size()-1:
		var a := stops[k]
		var b := stops[k+1]
		var mid := (a+b)*0.5
		var under_a: float = plan.arch_under(i,a+0.0005)
		var under_b: float = plan.arch_under(i,b-0.0005)
		var under_m: float = plan.arch_under(i,mid)
		if under_m <= 0.0:
			under_a = 0.0
			under_b = 0.0
		var top_a: float = plan.roof_over(a,w)+0.4
		var top_b: float = plan.roof_over(b,w)+0.4
		for side: float in [-1.0,1.0]:
			var r := _right(mid)*side
			var p := [at(a,side*w,under_a),at(b,side*w,under_b),at(b,side*w,top_b),at(a,side*w,top_a)]
			var kind := K_ASHLAR
			var col := C_ASHLAR
			m.quad(p,r,col,[Vector2(a,under_a),Vector2(b,under_b),Vector2(b,top_b),Vector2(a,top_a)],kind)
			# The arch's ring: a dressed band round the opening.
			if under_m > 0.0:
				var ring_a := minf(under_a+1.1,top_a)
				var ring_b := minf(under_b+1.1,top_b)
				var o := r*0.02
				var pr := [at(a,side*w,under_a)+o,at(b,side*w,under_b)+o,at(b,side*w,ring_b)+o,at(a,side*w,ring_a)+o]
				var tone := C_DRESSED if int(floor(mid*1.2))%2 == 0 else C_DRESSED_DARK
				m.quad(pr,r,tone,[Vector2(a,0),Vector2(b,0),Vector2(b,1),Vector2(a,1)],K_DRESSED)
		if under_m > 0.0:
			# The soffit.
			var p := [at(a,-w,under_a),at(b,-w,under_b),at(b,w,under_b),at(a,w,under_a)]
			m.quad(p,Vector3.DOWN,C_DRESSED_DARK,[Vector2(a,-w),Vector2(b,-w),Vector2(b,w),Vector2(a,w)],K_DRESSED)
		# A pier's end, where the arch springs from it.
		var was: float = plan.arch_under(i,a-0.0005) if k > 0 else 0.0
		if k > 0 and (was > 0.0) != (under_m > 0.0):
			var hi := maxf(was,under_a) if under_m > 0.0 else was
			var face: Vector3 = line.tangent(a)*(1.0 if under_m > 0.0 else -1.0)
			var e := [at(a,-w,0.0),at(a,w,0.0),at(a,w,hi),at(a,-w,hi)]
			m.quad(e,face,C_ASHLAR,[Vector2(-w,0),Vector2(w,0),Vector2(w,hi),Vector2(-w,hi)],K_ASHLAR)
	# The ends against the portals' lining.
	for e: float in [s0,s1]:
		var face: Vector3 = line.tangent(e)*(-1.0 if e == s0 else 1.0)
		var top: float = plan.roof_over(e,w)+0.4
		var p := [at(e,-w,0.0),at(e,w,0.0),at(e,w,top),at(e,-w,top)]
		m.quad(p,face,C_ASHLAR,[Vector2(-w,0),Vector2(w,0),Vector2(w,top),Vector2(-w,top)],K_ASHLAR)

# --- Portals --------------------------------------------------------------------------

## The arch's outline (the bore's vault at the face): (d, y) from the left
## spring over to the right.
func _arch(s: float, n: int) -> PackedVector2Array:
	var sc: Vector3 = plan.section(s)
	var out := PackedVector2Array()
	for k in n+1:
		var th := PI*(1.0-float(k)/n)
		out.append(Vector2(sc.x*cos(th),sc.y+sc.z*sin(th)))
	return out

## A portal at the face `s` (the tunnel's first metre), the tunnel running
## `dir` along s from it, of kind `kind` (Plan P_*): {m: M, wings: [{a, b
## (XZ), half, foot, top_a, top_b}]}. The block's box (the answers') is
## BoreShape's: FACE_OUT in front of s to BLOCK_IN in, face_half either
## side, to block_top; the arch ring, keystone and courses stand PROJECT m
## proud of its face at most.
const PROJECT := 0.9
const VOUSSOIRS := 19
const RING_DEEP := 1.7
const WING_LEN := 18.0
const WING_HALF := 0.7
const WING_ANGLE := 0.6
const SINK := 3.0

func portal(s: float, dir: float, kind: int) -> Dictionary:
	var m := M.new()
	var tg: Vector3 = line.tangent(s)
	var fwd := Vector3(tg.x,0.0,tg.z).normalized()*dir
	var r := Vector3(-fwd.z,0.0,fwd.x)
	var c: Vector3 = line.centre(s)
	var front := c-fwd*BoreShape.FACE_OUT
	m.base_y = c.y
	var back := c+fwd*BoreShape.BLOCK_IN
	var up := Vector3.UP
	var face := BoreShape.face_half()
	var top := BoreShape.block_top()
	var sc: Vector3 = plan.section(s)
	var half := sc.x
	var spring := sc.y
	var crown := sc.y+sc.z
	var low := -SINK
	var rock := kind == Plan.P_ROCKCUT
	var wall_k := K_ROCK if rock else K_ASHLAR
	var wall_c := C_PORTAL_ROCK if rock else C_ASHLAR
	wall_c.a = 1.0
	var arch := _arch(s,24)
	var soot_at := func(x: float, y: float) -> float:
		if y < spring: return 0.0
		var spread := 7.0+maxf(y-crown,0.0)*0.7
		var a := clampf(1.0-absf(x)/spread,0.0,1.0)
		var up_fade := 1.0-clampf((y-crown)/(top-crown+2.0),0.0,1.0) if y > crown else 1.0
		return sqrt(a)*up_fade*0.9
	# The face: the piers and the wall over the arch, in strips.
	var o := front
	var face_uv := func(p: Vector3) -> Vector2: return Vector2((p-o).dot(r),p.y-c.y)
	var face_quad := func(pts: Array, col: Color, k: float, jit: bool) -> void:
		if jit:
			for j in pts.size():
				var p: Vector3 = pts[j]
				var l := face_uv.call(p) as Vector2
				var edge := absf(absf(l.x)-face) < 0.05 or l.y > top-0.05 or l.y < low+0.05
				var on_arch := (l.y < spring+0.01 and absf(absf(l.x)-half) < 0.05) or (l.y >= spring and absf(l.x) <= half+0.01 and absf(l.y-(spring+sc.z*sqrt(maxf(1.0-(l.x/half)*(l.x/half),0.0)))) < 0.05)
				if not edge and not on_arch: pts[j] = p+fwd*(0.2+1.0*_ns(l.x*1.3,int(l.y*0.4)+3))
		var uvs := []
		var soots := Vector4.ZERO
		for j in 4:
			var l: Vector2 = face_uv.call(pts[j])
			uvs.append(l)
			soots[j] = float(soot_at.call(l.x,l.y))
		m.quad(pts,-fwd,col,uvs,k,soots)
	# Piers, in courses (rows) so the rock-cut face can be broken.
	var rows := 8
	for sg: float in [-1.0,1.0]:
		var cols := 3
		for i in cols:
			var x0 := lerpf(half,face,float(i)/cols)*sg
			var x1 := lerpf(half,face,float(i+1)/cols)*sg
			for j in rows:
				var y0 := lerpf(low,top,float(j)/rows)
				var y1 := lerpf(low,top,float(j+1)/rows)
				face_quad.call([o+r*x0+up*y0,o+r*x1+up*y0,o+r*x1+up*y1,o+r*x0+up*y1],wall_c,wall_k,rock)
	# Over the arch: strips from the arch's outline up to the top.
	for k in arch.size()-1:
		var a := arch[k]
		var b := arch[k+1]
		var steps := 4
		for j in steps:
			var ya0 := lerpf(a.y,top,float(j)/steps)
			var ya1 := lerpf(a.y,top,float(j+1)/steps)
			var yb0 := lerpf(b.y,top,float(j)/steps)
			var yb1 := lerpf(b.y,top,float(j+1)/steps)
			face_quad.call([o+r*a.x+up*ya0,o+r*b.x+up*yb0,o+r*b.x+up*yb1,o+r*a.x+up*ya1],wall_c,wall_k,rock)
	# The top, sides and back of the block.
	var top_c := wall_c*0.9
	top_c.a = 1.0
	m.quad([front-r*face+up*top,front+r*face+up*top,back+r*face+up*top,back-r*face+up*top],up,top_c,[Vector2(-face,0),Vector2(face,0),Vector2(face,12),Vector2(-face,12)],wall_k)
	for sg: float in [-1.0,1.0]:
		m.quad([front+r*sg*face+up*low,back+r*sg*face+up*low,back+r*sg*face+up*top,front+r*sg*face+up*top],r*sg,wall_c,[Vector2(0,low),Vector2(12,low),Vector2(12,top),Vector2(0,top)],wall_k)
	# The arch ring: voussoirs round the opening, alternating tones, standing
	# proud; the keystone bigger and prouder.
	var proud := front-fwd*0.45
	var vo := _arch(s,VOUSSOIRS)
	for k in VOUSSOIRS:
		var a := vo[k]
		var b := vo[k+1]
		var key := k == VOUSSOIRS/2
		var na := _arch_out(a,half,spring,sc.z)
		var nb := _arch_out(b,half,spring,sc.z)
		var deep := RING_DEEP*(1.6 if key else 1.0)
		var shift := (proud-fwd*0.4) if key else proud
		var a2 := a+na*deep
		var b2 := b+nb*deep
		var gap := 0.06
		var ai := a.lerp(b,gap)
		var bi := b.lerp(a,gap)
		var ao := a2.lerp(b2,gap)
		var bo := b2.lerp(a2,gap)
		var col := (C_DRESSED if k%2 == 0 else C_DRESSED_DARK)
		if key: col = C_DRESSED*1.05
		col.a = 1.0
		var p := [shift+r*ai.x+up*ai.y,shift+r*bi.x+up*bi.y,shift+r*bo.x+up*bo.y,shift+r*ao.x+up*ao.y]
		var bk := [front+r*ai.x+up*ai.y,front+r*bi.x+up*bi.y,front+r*bo.x+up*bo.y,front+r*ao.x+up*ao.y]
		var sm := Vector4(float(soot_at.call(ai.x,ai.y)),float(soot_at.call(bi.x,bi.y)),float(soot_at.call(bo.x,bo.y)),float(soot_at.call(ao.x,ao.y)))
		m.quad(p,-fwd,col,[ai,bi,bo,ao],K_DRESSED,sm*0.8)
		# Its sides back to the face.
		for e in 4:
			var e1 := (e+1)%4
			var mid: Vector3 = (p[e]+p[e1])*0.5
			var cen: Vector3 = (p[0]+p[1]+p[2]+p[3])*0.25
			m.quad([p[e],p[e1],bk[e1],bk[e]],mid-cen,col*0.85,[Vector2(0,0),Vector2(1,0),Vector2(1,0.5),Vector2(0,0.5)],K_DRESSED)
	# Quoins up the jambs: long and short stones, alternating.
	var qn := 5
	for sg: float in [-1.0,1.0]:
		for j in qn:
			var y0 := lerpf(0.0,spring,float(j)/qn)+0.04
			var y1 := lerpf(0.0,spring,float(j+1)/qn)-0.04
			var wq := 1.9 if j%2 == 0 else 1.2
			var x0 := sg*(half+0.02)
			var x1 := sg*(half+wq)
			var col := C_DRESSED if j%2 == 0 else C_DRESSED_DARK
			_proud_box(m,front,r,up,fwd,x0,x1,y0,y1,0.9,col)
	if not rock:
		# Pilasters at the block's edges, a string course, the parapet's
		# cornice and coping.
		var court := top-BoreShape.PARAPET
		for sg: float in [-1.0,1.0]:
			_proud_box(m,front,r,up,fwd,sg*(face-0.05),sg*(face-3.2),low,court-1.0,0.5,C_DRESSED_DARK)
		_proud_box(m,front,r,up,fwd,-face-0.3,face+0.3,court-1.0,court-0.2,PROJECT,C_DRESSED)
		_proud_box(m,front,r,up,fwd,-face-0.3,face+0.3,top-0.55,top,0.6,C_DRESSED)
		# A date stone over the keystone.
		_proud_box(m,front,r,up,fwd,-2.2,2.2,crown+RING_DEEP*1.6+0.3,crown+RING_DEEP*1.6+1.5,0.25,C_DRESSED_DARK)
	else:
		# A rough hood of rock over the ring.
		_proud_box(m,front,r,up,fwd,-half-2.5,half+2.5,crown+RING_DEEP+0.4,crown+RING_DEEP+1.4,0.5,C_ROCK)
	# The wing walls, out from the face's corners into the hillside.
	var wings: Array = []
	for sg: float in [-1.0,1.0]:
		var root := front+r*sg*(face-0.1)
		var way := (-fwd*cos(WING_ANGLE)+r*sg*sin(WING_ANGLE)).normalized()
		var tip := root+way*WING_LEN
		var top_a := top-BoreShape.PARAPET-0.5
		var top_b := 3.0
		var side := Vector3(-way.z,0.0,way.x)*WING_HALF
		var foot := c.y+low
		var pts := [root-side+up*(foot-c.y),root+side+up*(foot-c.y),tip+side+up*(foot-c.y),tip-side+up*(foot-c.y),root-side+up*top_a,root+side+up*top_a,tip+side+up*top_b,tip-side+up*top_b]
		var mid: Vector3 = (root+tip)*0.5+up*(top_a+top_b)*0.25
		var wcol := C_ROCK if rock else C_ASHLAR
		if rock:
			for j in range(4,8): pts[j] = (pts[j] as Vector3)-Vector3.UP*(0.5+1.5*_h(j,int(sg+2.0)))
		m.hull8(pts,mid,wcol,wall_k,way)
		# A coping along its top.
		if not rock:
			var cp := [pts[4]-side*0.35,pts[5]+side*0.35,pts[6]+side*0.35,pts[7]-side*0.35]
			var cp2 := [cp[0]+up*0.45,cp[1]+up*0.45,cp[2]+up*0.45,cp[3]+up*0.45]
			m.hull8(cp+cp2,mid+up*30.0,C_DRESSED,K_DRESSED,way,true)
		wings.append({"a":Vector2(root.x,root.z),"b":Vector2(tip.x,tip.z),"half":WING_HALF+(0.35 if not rock else 0.0),"foot":foot,"top_a":c.y+top_a+(0.45 if not rock else 0.0),"top_b":c.y+top_b+(0.45 if not rock else 0.0)})
	return {"m":m,"wings":wings}

## The outward way off the arch's ellipse at a point on it.
static func _arch_out(p: Vector2, half: float, spring: float, rise: float) -> Vector2:
	var y := p.y-spring
	return Vector2(p.x/(half*half),y/(rise*rise)).normalized()

## A block standing `deep` m proud of the face plane at `o` (r across, up),
## x0..x1 across, y0..y1 up.
func _proud_box(m: M, o: Vector3, r: Vector3, up: Vector3, fwd: Vector3, x0: float, x1: float, y0: float, y1: float, deep: float, col: Color) -> void:
	var a := minf(x0,x1)
	var b := maxf(x0,x1)
	var f := o-fwd*deep
	var pts := [o+r*a+up*y0,o+r*b+up*y0,f+r*b+up*y0,f+r*a+up*y0,o+r*a+up*y1,o+r*b+up*y1,f+r*b+up*y1,f+r*a+up*y1]
	var mid := (o+f)*0.5+r*(a+b)*0.5+up*(y0+y1)*0.5
	col.a = 1.0
	m.hull8(pts,mid,col,K_DRESSED,r,true)
