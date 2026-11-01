extends Node3D
## The ice tunnel (scripts/endless/peak_tunnel.gd) as the flight, the camera
## and the wheels meet it, and its tube: rings of the bore's profile along
## the path, lumped outward into the rock, a flat floor, on the tinted basalt
## shader (the moss colours as ice: ice on the floor, in bands up the walls'
## feet and the joints; a cold blue fill). Built whole at setup (one tube).
##
## The land's surface stays whole over the bore, so under the vault and
## beside it the land's height is not the solid: `ground`, `land_y` and
## `inside` answer for the rock round the tube, as LandTunnels does for the
## overgrown ones. On the open stretches (PeakTunnel OPENINGS: the two mouths
## and the gully the bore crosses) the land is holed where it lies in the
## bore (PeakTunnel `hole_mask`, land_stream.gd), the tube is trimmed where it
## stands out of the land, and a snowed lip (`_flange`) lies on the land from
## the cut's edge outward over the hole's rim. The window's shaft is a short
## tube up from the chamber's crown to the land.
##
## The inside is on LandTunnels.UNDER_LAYER, which the sun and the moon
## leave out: lit by a pool of cold lights along the path, the nearest the
## eye (`step`), and a brighter one under the window. The open stretches'
## tube is in the day (layer 1). A backface trimesh collider in pieces.
##
## `--ice-tunnel=0` off (PeakTunnel `wanted`).

const PeakTunnel = preload("res://scripts/endless/peak_tunnel.gd")
const LandTunnels = preload("res://scripts/endless/land_tunnels.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const SkyGlide = preload("res://scripts/sky_glide.gd")
const BASALT = preload("res://shaders/tunnel_basalt.gdshader")

const UNDER_LAYER := LandTunnels.UNDER_LAYER
## Physics layer of the collider.
const LAYER := 1
## Ring spacing along the path (m): inside, and on the open stretches.
const RING := 3.0
const RING_OPEN := 1.5
## Segments over the vault's ring and across the floor.
const RING_SEGS := 28
const FLOOR_SEGS := 6
## The rock lumped outward by up to LUMP m (ridged noise, GRAIN m across).
const LUMP := 1.4
const GRAIN := 9.0
## The cut on an open stretch: a triangle stands while one corner is under
## the land + CUT_UP m. The lip from the cut's edge: LIP_W m out over the
## land in LIP_N steps, LIP_SINK m under its top (it shows over the hole
## only), and at the face where the land comes down over the vault.
const CUT_UP := 0.6
const LIP_W := 9.0
const LIP_N := 4
const LIP_SINK := 0.25
## The shaft up from the window: rings every SHAFT_RING m, SHAFT_SEGS round.
const SHAFT_RING := 4.0
const SHAFT_SEGS := 16
## The cold lights: one every LIGHT_EVERY m along the path, LIGHT_UP of the
## crown over the floor, LIGHT_POOL lit, the nearest the eye within
## LIGHT_REACH m; the window's brighter.
const LIGHT_EVERY := 45.0
const LIGHT_UP := 0.72
const LIGHT_POOL := 8
const LIGHT_REACH := 320.0
const LIGHT_RANGE := 50.0
const LIGHT_ENERGY := 8.0
const LIGHT_COLOR := Color(0.62,0.8,1.0)
const WINDOW_ENERGY := 9.0
const WINDOW_COLOR := Color(0.85,0.93,1.0)
## The ice: the basalt shader's growth recoloured.
const ICE_DARK := Color(0.36,0.5,0.62)
const ICE_LIT := Color(0.78,0.9,0.98)
const ICE_LOW := 5.0
const FILL := Color(0.16,0.24,0.36)
const FILL_GAIN := 0.16
const SNOW := Color(0.88,0.92,0.97)
## The collider's pieces (triangles each).
const BODY_TRIS := 6000
## The guard (`guide`, `keep`), as LandTunnels'.
const GUARD_MARGIN := LandTunnels.GUARD_MARGIN
const GUARD_PUSH := LandTunnels.GUARD_PUSH
const GUARD_LIFT := LandTunnels.GUARD_LIFT
const GUARD_LOOK := LandTunnels.GUARD_LOOK
const GUARD_ROOF := LandTunnels.GUARD_ROOF
const GUARD_FLOOR := LandTunnels.GUARD_FLOOR
const KEEP_IN := LandTunnels.KEEP_IN
## The clear room `keep` holds it in, inside the solid's own edge: KEEP_OFF m
## off the wall read KEEP_UP m higher (the vault's foot curves in).
const KEEP_OFF := 0.6
const KEEP_UP := 1.5
const SIGHT_STEP := 1.0
const SIGHT_UP := 60.0

var field: RefCounted
## The tunnel (PeakTunnel), null when off or without a massif.
var tun: RefCounted
var stats := {"tris":0,"build_ms":0.0,"faces":Vector2.ZERO}
var sight_whole := false
## Where the land comes down over the vault at each mouth (m along).
var face_a := 0.0
var face_b := 0.0
var _grow := 0.0
var _spots := PackedVector3Array()
var _spot_gain := PackedFloat32Array()
var _lights: Array[OmniLight3D] = []
var _sky_cut := false
## The tube's ends (m along) and its top y bound, for the quick outs.
var _s0 := 0.0
var _s1 := 0.0
var _top := 0.0

func setup(land_field: RefCounted) -> void:
	field = land_field
	_grow = WorldScale.span*0.5
	var got: Variant = field.get("ice_tunnel")
	tun = got if got is RefCounted else null
	if tun == null: return
	var t0 := Time.get_ticks_usec()
	_s0 = PeakTunnel.MOUTH_A-PeakTunnel.MOUTH_OUT_A
	_s1 = PeakTunnel.MOUTH_B+PeakTunnel.MOUTH_OUT_B
	face_a = _face(PeakTunnel.MOUTH_A,1.0)
	face_b = _face(PeakTunnel.MOUTH_B,-1.0)
	stats.faces = Vector2(face_a,face_b)
	_top = -INF
	var s := _s0
	while s <= _s1:
		_top = maxf(_top,tun.floor_at(s)+tun.profile(s).y)
		s += 10.0
	_build()
	_place_lights()
	stats.build_ms = (Time.get_ticks_usec()-t0)/1000.0

## The face near `s0`: where the land over the path first stands 0.7 of the
## crown over the floor, walking in (`dir`) from the tube's end.
func _face(s0: float, dir: float) -> float:
	var s := _s0 if dir > 0.0 else _s1
	var stop := s0+40.0*dir
	while (s-stop)*dir < 0.0:
		var p: Vector2 = tun.at_s(s)
		if field.height(p.x,p.y) >= tun.floor_at(s)+0.7*tun.profile(s).y: return s
		s += dir
	return s0

# --- The tube ------------------------------------------------------------------------

func _build() -> void:
	var grain := FastNoiseLite.new()
	grain.seed = 7177
	grain.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	grain.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	grain.fractal_octaves = 3
	grain.frequency = 1.0/GRAIN
	var vein := FastNoiseLite.new()
	vein.seed = 7178
	vein.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	vein.frequency = 0.03
	# The rings' distances: finer on the open stretches.
	var ss := PackedFloat32Array()
	var s := _s0
	while s < _s1:
		ss.append(s)
		s += RING_OPEN if PeakTunnel.open_at(s,6.0) else RING
	ss.append(_s1)
	var per := RING_SEGS+1+FLOOR_SEGS+1
	var pos := PackedVector3Array()
	var nrm := PackedVector3Array()
	var col := PackedColorArray()
	var under := PackedByteArray()
	for r in ss.size():
		s = ss[r]
		var c: Vector2 = tun.at_s(s)
		var tg: Vector2 = tun.tan_s(s)
		var n3 := Vector3(-tg.y,0.0,tg.x)
		var pr: Vector3 = tun.profile(s)
		var fy: float = tun.floor_at(s)
		var open := PeakTunnel.open_at(s,4.0)
		var feet: Array[Vector3] = []
		for k in RING_SEGS+1:
			var th := PI*float(k)/RING_SEGS
			var q: Vector2 = PeakTunnel.profile_point(pr,th)
			var x := q.x/pr.x
			var y := q.y/pr.y
			var g := Vector2(signf(x)*pow(absf(x),pr.z-1.0)/pr.x,pow(maxf(y,0.0),pr.z-1.0)/pr.y).normalized()
			var base := Vector3(c.x,fy,c.y)+n3*q.x+Vector3.UP*q.y
			var nz := clampf(grain.get_noise_3dv(base)*0.5+0.5,0.0,1.0)
			var out := n3*g.x+Vector3.UP*g.y
			# Less lump near the faces, so the opening reads true.
			var lump := LUMP*(0.35 if open else 1.0)
			var v := base+out*lump*nz
			if k == 0 or k == RING_SEGS: feet.append(v)
			pos.append(v)
			nrm.append(-out)
			col.append(Color(1.0-0.6*nz,_ice(vein,v,q.y),0.0,0.0))
		for k in FLOOR_SEGS+1:
			var v: Vector3 = feet[0].lerp(feet[1],float(k)/FLOOR_SEGS)
			pos.append(v)
			nrm.append(Vector3.UP)
			col.append(Color(0.7+0.3*(grain.get_noise_2d(v.x*3.0,v.z*3.0)*0.5+0.5),1.0,0.0,0.0))
		for k in per:
			var v := pos[r*per+k]
			under.append(1 if not open or v.y <= field.height(v.x,v.z)+CUT_UP else 0)
	# The triangles: the inside's, the open stretches' (in the day), the
	# trimmed left out.
	var inner := SurfaceTool.new()
	inner.begin(Mesh.PRIMITIVE_TRIANGLES)
	var day := SurfaceTool.new()
	day.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	var tris := 0
	for r in range(1,ss.size()):
		var b0 := (r-1)*per
		var b1 := r*per
		var mid := (ss[r-1]+ss[r])*0.5
		var open := PeakTunnel.open_at(mid,4.0)
		var st := day if _lit(mid) else inner
		var quads: Array = []
		for k in RING_SEGS: quads.append([b0+k,b0+k+1,b1+k+1,b1+k])
		var f := RING_SEGS+1
		for k in FLOOR_SEGS: quads.append([b0+f+k,b0+f+k+1,b1+f+k+1,b1+f+k])
		for qd: Array in quads:
			for tri: Array in [[qd[0],qd[1],qd[2]],[qd[0],qd[2],qd[3]]]:
				if open and under[tri[0]] == 0 and under[tri[1]] == 0 and under[tri[2]] == 0: continue
				tris += _tri(st,faces,pos,nrm,col,tri[0],tri[1],tri[2])
	# The lip: on each side of each open ring, from where the ring comes out
	# of the land, outward over it.
	var snow := SurfaceTool.new()
	snow.begin(Mesh.PRIMITIVE_TRIANGLES)
	tris += _lips(snow,ss,pos,per,under)
	tris += _shaft(inner,faces,grain)
	var mesh := ArrayMesh.new()
	inner.commit(mesh)
	var node := MeshInstance3D.new()
	node.name = "IceTube"
	node.mesh = mesh
	node.material_override = _ice_material()
	node.layers = UNDER_LAYER
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	var dm := ArrayMesh.new()
	day.commit(dm)
	if dm.get_surface_count() > 0:
		var dn := MeshInstance3D.new()
		dn.name = "IceTubeOpen"
		dn.mesh = dm
		dn.material_override = node.material_override
		add_child(dn)
	var sm := ArrayMesh.new()
	snow.commit(sm)
	if sm.get_surface_count() > 0:
		var sn := MeshInstance3D.new()
		sn.name = "IceLip"
		sn.mesh = sm
		sn.material_override = _snow_material()
		sn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sn)
	# The collider in pieces.
	var per_body := BODY_TRIS*3
	var i0 := 0
	while i0 < faces.size():
		var body := StaticBody3D.new()
		body.name = "IceTubeBody%d" % (i0/per_body)
		body.collision_layer = LAYER
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces.slice(i0,mini(i0+per_body,faces.size())))
		shape.backface_collision = true
		cs.shape = shape
		body.add_child(cs)
		add_child(body)
		i0 += per_body
	stats.tris = tris

## Whether the ring at `s` is in the day: on an open stretch and past its
## mouth's face (where the land over the vault comes down), so the roofed
## run up to each face stays with the inside's light, and the light changes
## at the face, not partway in under the rock.
func _lit(s: float) -> bool:
	if not PeakTunnel.open_at(s,4.0): return false
	if s < PeakTunnel.OPENINGS[0].y+4.0: return s < face_a
	if s > PeakTunnel.OPENINGS[2].x-4.0: return s > face_b
	return true

## The ice in the rock at `v` (`h` over the floor): bands up the walls.
static func _ice(vein: FastNoiseLite, v: Vector3, h: float) -> float:
	var band := absf(vein.get_noise_3d(v.x,v.y*2.2,v.z))
	return clampf(1.0-band*6.0,0.0,1.0)*0.9+0.1*(1.0-smoothstep(0.0,8.0,h))

## Triangle (a, b, c) of the rings into `st` and `faces`, wound to face in.
static func _tri(st: SurfaceTool, faces: PackedVector3Array, pos: PackedVector3Array, nrm: PackedVector3Array, col: PackedColorArray, a: int, b: int, c: int) -> int:
	var nm := nrm[a]+nrm[b]+nrm[c]
	if (pos[b]-pos[a]).cross(pos[c]-pos[a]).dot(nm) > 0.0:
		var k := b
		b = c
		c = k
	for i: int in [a,b,c]:
		st.set_normal(nrm[i])
		st.set_color(col[i])
		st.add_vertex(pos[i])
		faces.append(pos[i])
	return 1

## The snowed lip along the cut on both sides (Returns its triangles).
func _lips(st: SurfaceTool, ss: PackedFloat32Array, pos: PackedVector3Array, per: int, under: PackedByteArray) -> int:
	var tris := 0
	for side in 2:
		var prev: Array = []
		for r in ss.size():
			var row: Array = []
			if PeakTunnel.open_at(ss[r],2.0):
				var c: Vector2 = tun.at_s(ss[r])
				# Up the ring from this side's foot to its first vertex out of
				# the land; past the crown, none (the land covers this side).
				var k0 := 0 if side == 0 else RING_SEGS
				var dk := 1 if side == 0 else -1
				var hit := -1
				for i in RING_SEGS/2+1:
					var k := k0+dk*i
					if under[r*per+k] == 0:
						hit = k
						break
				if hit >= 0:
					var a := pos[r*per+(hit-dk if hit != k0 else hit)]
					var o := Vector2(a.x-c.x,a.z-c.y)
					o = o.normalized() if o.length() > 0.5 else Vector2(-tun.tan_s(ss[r]).y,tun.tan_s(ss[r]).x)*(1.0 if side == 0 else -1.0)
					for j in LIP_N+1:
						var w := LIP_W*float(j)/LIP_N
						var x := a.x+o.x*w
						var z := a.z+o.y*w
						var y := minf(a.y,field.height(x,z)-LIP_SINK) if j > 0 else a.y
						row.append(Vector3(x,y,z))
			if not row.is_empty() and not prev.is_empty():
				for j in LIP_N:
					for tri: Array in [[prev[j],prev[j+1],row[j+1]],[prev[j],row[j+1],row[j]]]:
						var p0: Vector3 = tri[0]
						var p1: Vector3 = tri[1]
						var p2: Vector3 = tri[2]
						if (p1-p0).cross(p2-p0).y > 0.0:
							var k := p1
							p1 = p2
							p2 = k
						for p: Vector3 in [p0,p1,p2]:
							st.set_normal(Vector3.UP)
							st.add_vertex(p)
						tris += 1
			prev = row
	return tris

## The window's shaft: a round tube from the chamber's crown up to the land
## (on the inside's layer, its lower half; the light comes down it).
func _shaft(st: SurfaceTool, faces: PackedVector3Array, grain: FastNoiseLite) -> int:
	var tris := 0
	for w: Dictionary in tun.windows:
		var at: Vector2 = w.at
		var y0: float = float(w.crown)-3.0
		var y1: float = field.height(at.x,at.y)+2.0
		var rings := maxi(2,ceili((y1-y0)/SHAFT_RING)+1)
		var pos := PackedVector3Array()
		var nrm := PackedVector3Array()
		var col := PackedColorArray()
		for r in rings:
			var y := lerpf(y0,y1,float(r)/(rings-1))
			for k in SHAFT_SEGS+1:
				var a := TAU*float(k)/SHAFT_SEGS
				var d := Vector3(cos(a),0.0,sin(a))
				var v := Vector3(at.x,y,at.y)+d*PeakTunnel.WINDOW_R
				v += d*0.8*clampf(grain.get_noise_3dv(v)*0.5+0.5,0.0,1.0)
				pos.append(v)
				nrm.append(-d)
				col.append(Color(0.8,0.6*(1.0-float(r)/rings),0.0,0.0))
		var n := SHAFT_SEGS+1
		for r in range(1,rings):
			for k in SHAFT_SEGS:
				var a := (r-1)*n+k
				var b := r*n+k
				tris += _tri(st,faces,pos,nrm,col,a,a+1,b+1)
				tris += _tri(st,faces,pos,nrm,col,a,b+1,b)
	return tris

func _ice_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = BASALT
	mat.set_shader_parameter("floor_y",tun.floor_at(PeakTunnel.MOUTH_A))
	mat.set_shader_parameter("moss_dark",ICE_DARK)
	mat.set_shader_parameter("moss_lit",ICE_LIT)
	mat.set_shader_parameter("moss",1.0)
	mat.set_shader_parameter("moss_low",ICE_LOW)
	mat.set_shader_parameter("rust",Color(0.16,0.17,0.19))
	mat.set_shader_parameter("silt",Color(0.55,0.62,0.7))
	mat.set_shader_parameter("basalt_lo",Color(0.07,0.075,0.085))
	mat.set_shader_parameter("basalt_hi",Color(0.2,0.21,0.23))
	mat.set_shader_parameter("fill",FILL)
	mat.set_shader_parameter("fill_gain",FILL_GAIN)
	return mat

static func _snow_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = SNOW
	mat.roughness = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat

# --- The lights ----------------------------------------------------------------------

func _place_lights() -> void:
	var s := PeakTunnel.MOUTH_A+20.0
	while s < PeakTunnel.MOUTH_B-10.0:
		if not PeakTunnel.open_at(s,10.0):
			var p: Vector2 = tun.at_s(s)
			var pr: Vector3 = tun.profile(s)
			_spots.append(Vector3(p.x,tun.floor_at(s)+pr.y*LIGHT_UP,p.y))
			_spot_gain.append(1.0)
		s += LIGHT_EVERY
	for w: Dictionary in tun.windows:
		var at: Vector2 = w.at
		_spots.append(Vector3(at.x,float(w.crown)-4.0,at.y))
		_spot_gain.append(-1.0)
	for i in LIGHT_POOL:
		var l := OmniLight3D.new()
		l.name = "IceLight%d" % i
		l.light_cull_mask = UNDER_LAYER
		l.omni_range = LIGHT_RANGE
		l.omni_attenuation = 0.8
		l.light_specular = 0.4
		l.shadow_enabled = false
		l.visible = false
		add_child(l)
		_lights.append(l)

## The pool to the spots nearest `at` (each frame; the sky's lights cut
## off the inside once they stand).
func step(at: Vector3) -> void:
	if tun == null: return
	if not _sky_cut: _cut_sky()
	var near: Array = []
	for i in _spots.size():
		var d := _spots[i].distance_to(at)
		if d < LIGHT_REACH: near.append(Vector2(d,i))
	near.sort()
	for j in _lights.size():
		var l := _lights[j]
		if j >= near.size():
			l.visible = false
			continue
		var i := int(near[j].y)
		l.position = _spots[i]
		var win := _spot_gain[i] < 0.0
		l.light_color = WINDOW_COLOR if win else LIGHT_COLOR
		l.light_energy = WINDOW_ENERGY if win else LIGHT_ENERGY
		l.omni_range = LIGHT_RANGE*(1.6 if win else 1.0)
		l.visible = true

func prime(at: Vector3) -> void:
	step(at)

func _cut_sky() -> void:
	var lights: Array = get_tree().root.find_children("*","DirectionalLight3D",true,false)
	for l: DirectionalLight3D in lights: l.light_cull_mask &= ~UNDER_LAYER
	_sky_cut = not lights.is_empty()

# --- The flight's answers ------------------------------------------------------------

## Vector3(s, d, floor) for `p` in the tube's reach, or s NAN.
func _at(p: Vector3) -> Vector3:
	if tun == null or p.y > _top+SIGHT_UP or not tun.box.has_point(Vector2(p.x,p.z)): return Vector3(NAN,0.0,0.0)
	var q: Vector3 = tun.local(p.x,p.z)
	if is_nan(q.x) or q.x < _s0 or q.x > _s1: return Vector3(NAN,0.0,0.0)
	return Vector3(q.x,q.y,tun.floor_at(q.x))

## Vector2(floor, roof) of the bore at `p`, `grow` m in off the rock; NAN
## off it or where the land under it is below the floor (open air there).
func _bore(p: Vector3, grow: float, h: float) -> Vector2:
	var q := _at(p)
	if is_nan(q.x): return Vector2(NAN,NAN)
	var pr: Vector3 = tun.profile(q.x)
	var r := PeakTunnel.roof_over(pr,absf(q.y)+grow)
	if is_nan(r) or h < q.z: return Vector2(NAN,NAN)
	return Vector2(q.z,q.z+r)

## The shaft over the window `p` is in (grown `grow` in), under the land:
## its floor y, else NAN.
func _shaft_floor(p: Vector3, grow: float, h: float) -> float:
	if tun == null or tun.windows.is_empty() or p.y >= h: return NAN
	var w: int = tun.window_at(p.x,p.z,grow)
	if w < 0: return NAN
	return float(tun.windows[w].floor)

## The plane's ground (studies/endless_flight.gd `plane_ground`): in the
## bore under its roof, its floor; elsewhere the land's `h` (over the vault
## and beside it the rock stands to the land's top).
func ground(p: Vector3, h: Variant, pad := -1.0) -> Variant:
	if tun == null or not h is float: return h
	var grow := _grow if pad < 0.0 else pad
	var hf: float = field.height(p.x,p.z)
	var sf := _shaft_floor(p,grow,hf)
	if not is_nan(sf): return sf
	var b := _bore(p,grow,hf)
	if not is_nan(b.x) and p.y < b.y: return b.x
	return h

## The solid's top under `p` over the land's `h`: the bore's floor under its
## roof, else `h`.
func land_y(p: Vector3, h: float) -> float:
	if tun == null: return h
	var hf: float = field.height(p.x,p.z)
	var sf := _shaft_floor(p,0.0,hf)
	if not is_nan(sf): return sf
	var b := _bore(p,0.0,hf)
	if not is_nan(b.x) and p.y < b.y: return b.x
	return h

## In the rock round the bore (the camera keeps out, the wheels stop):
## under its floor, or over its roof under the land. Beside it, the land's
## own height answers.
func inside(p: Vector3) -> bool:
	if tun == null: return false
	var q := _at(p)
	if is_nan(q.x): return false
	var hf: float = field.height(p.x,p.z)
	if not is_nan(_shaft_floor(p,0.0,hf)): return p.y < q.z
	var b := _bore(p,0.0,hf)
	if is_nan(b.x): return false
	return p.y < b.x or (p.y > b.y and p.y < hf)

## The quick answer in the tube away from its open stretches: 1 in the
## rock, 0 open, -1 elsewhere (ask `inside` and `land_y`).
func tube(p: Vector3) -> int:
	var q := _at(p)
	if is_nan(q.x) or PeakTunnel.open_at(q.x,8.0): return -1
	var hf: float = field.height(p.x,p.z)
	if not is_nan(_shaft_floor(p,0.0,hf)): return 1 if p.y < q.z else 0
	var b := _bore(p,0.0,hf)
	if is_nan(b.x): return -1
	return 1 if p.y < b.x or p.y > b.y else 0

## Whether `p` is near enough the bore for the fine march.
func near(p: Vector3) -> bool:
	var q := _at(p)
	return not is_nan(q.x) and absf(q.y) < tun.profile(q.x).x+30.0 and p.y < q.z+SIGHT_UP

## The camera's sight from `from` to `to` near the bore (LandTunnels `sight`).
func sight(from: Vector3, to: Vector3) -> float:
	sight_whole = false
	if tun == null or (not near(from) and not near(to)): return 1.0
	var n := maxi(1,ceili(from.distance_to(to)/SIGHT_STEP))
	var whole := true
	for i in range(1,n+1):
		var p := from.lerp(to,float(i)/n)
		var got := tube(p)
		if got < 0:
			whole = false
			var hf: float = field.height(p.x,p.z)
			if inside(p) or p.y < land_y(p,hf): got = 1
		if got == 1:
			sight_whole = whole
			return float(i-1)/n
	sight_whole = whole
	return 1.0

## SkyGlide's `guide` in the bore under its roof (LandTunnels `guide`): a
## soft push off the walls, the roof and the floor, the heading eased along.
func guide(p: Vector3, heading: float, speed: float) -> Dictionary:
	var q := _at(p)
	if is_nan(q.x): return {}
	var hf: float = field.height(p.x,p.z)
	var b := _bore(p,0.0,hf)
	if is_nan(b.x) or p.y >= b.y: return {}
	if not is_nan(_shaft_floor(p,0.0,hf)) and p.y > b.y-GUARD_ROOF: return {}
	var h := p.y-q.z
	var tg: Vector2 = tun.tan_s(q.x)
	var across := Vector3(-tg.y,0.0,tg.x)
	var fwd := Vector2(-sin(heading),-cos(heading))
	var sense := 1.0 if fwd.dot(tg) >= 0.0 else -1.0
	var room := INF
	for ds: float in [0.0,sense*maxf(speed,10.0)*GUARD_LOOK]:
		room = minf(room,_room(q.x+ds,h))
	# `local`'s d is + to the left of the way; `across` (-tg.y, tg.x) is +d.
	var off := q.y
	var near_w := clampf((absf(off)-(room-GUARD_MARGIN))/GUARD_MARGIN,0.0,1.0)
	var push := -signf(off)*across*GUARD_PUSH*near_w*near_w
	var turn := 0.0
	var way := atan2(-tg.x*sense,-tg.y*sense)
	if near_w > 0.0 and Vector2(across.x,across.z).dot(fwd)*signf(off) > 0.0: turn = near_w
	var level := 0.0
	var top := b.y-q.z-SkyGlide.CLEAR
	var up := clampf((h-(top-GUARD_ROOF))/GUARD_ROOF,0.0,1.0)
	if up > 0.0:
		push.y -= GUARD_PUSH*up*up
		level = up
	var down := clampf((SkyGlide.SKIM+GUARD_FLOOR-h)/GUARD_FLOOR,0.0,1.0)
	if down > 0.0:
		push.y += GUARD_LIFT*down*down
		level = -down
	if near_w == 0.0 and level == 0.0: return {}
	return {"push":push,"heading":way,"turn":turn,"level":level}

## SkyGlide's `keep`: in the bore past its clear room across or over its
## roof, put back on that edge (LandTunnels `keep`).
func keep(p: Vector3) -> Vector3:
	var q := _at(p)
	if is_nan(q.x): return p
	var hf: float = field.height(p.x,p.z)
	if hf < q.z or not is_nan(_shaft_floor(p,0.0,hf)): return p
	# Up out of a slot on an open stretch, it is in the air.
	if p.y > hf and PeakTunnel.open_at(q.x,4.0): return p
	var pr: Vector3 = tun.profile(q.x)
	var h := p.y-q.z
	# Not only in the bore: pressed past its wall it is put back too.
	if absf(q.y) > pr.x+8.0 or h > pr.y or h < -2.0: return p
	var room := maxf(_room(q.x,h),0.0)
	var out := p
	if absf(q.y) > room-KEEP_IN:
		var tg: Vector2 = tun.tan_s(q.x)
		var across := Vector3(-tg.y,0.0,tg.x)
		out -= across*signf(q.y)*(absf(q.y)-maxf(room-KEEP_IN,0.0))
	var bg := _bore(out,_grow,field.height(out.x,out.z))
	if not is_nan(bg.y) and out.y > bg.y-SkyGlide.CLEAR-KEEP_IN: out.y = bg.y-SkyGlide.CLEAR-KEEP_IN
	return out

## The clear half width at `s`, `h` m over the floor (the wall at CLEAR over
## it, less the wingtip's reach).
func _room(s: float, h: float) -> float:
	var pr: Vector3 = tun.profile(clampf(s,_s0,_s1))
	return PeakTunnel.half_at(pr,h+SkyGlide.CLEAR+KEEP_UP)-_grow-KEEP_OFF

## The least room past a wingtip at `p` (m; INF off the bore): the wall
## across at its height and the roof over it.
func room_at(p: Vector3) -> float:
	var q := _at(p)
	if is_nan(q.x): return INF
	var pr: Vector3 = tun.profile(q.x)
	var h := p.y-q.z
	var wall := PeakTunnel.half_at(pr,h)-absf(q.y)-WorldScale.span*0.5
	var roof := PeakTunnel.roof_over(pr,absf(q.y))
	return minf(wall,(roof-h) if not is_nan(roof) else -1.0)

func note() -> String:
	return "ice tunnel: %d tris, %.0f ms, faces %.0f / %.0f" % [int(stats.tris),float(stats.build_ms),face_a,face_b]
