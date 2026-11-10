extends Node3D
## The railroad's tunnels (spec-railroad.md, lane line): a double-track bore
## along the line (rail_line.gd) through each tunnel stretch, and a portal at
## each mouth, as the flight, the camera and the wheels meet them, in the ice
## tunnel's manner (land_ice_tunnel.gd). What stands where is the layout's
## (rail_bore_plan.gd: the linings, the cross-section along s, the members,
## the lamps, the portals' kinds, laid by rule); the meshes are
## rail_bore_mesh.gd's; the blocks' sizes and the standard section are
## rail_bore_shape.gd's; the land round them is rail_bed.gd's: raised to a
## cover over the bore, so the bore is always in the rock, and holed under
## each block, which hides the hole's edges.
##
## The land's surface stays whole over the bore, so in the bore and beside
## it the land's height is not the solid: `ground`, `land_y` and `inside`
## answer for the rock round the tube, the members stood in it (the plan's
## `stretches`), the blocks and their wing walls, from the same numbers the
## meshes are built from.
##
## The tube is built in PIECE m pieces of the line within FAR of the eye,
## nearest first in BUDGET_MS a frame, and freed past FREE_AT x that;
## its colliders (physics layer 1, backface trimesh: the lining one shape,
## each member its own, so near misses tell them apart) within COLLIDE of the
## plane. Its inside is on LandTunnels.UNDER_LAYER, which the sun and the
## moon leave out, but for its first DAY_IN m from each face: lit by a pool
## of lamps, the nearest the eye, at the plan's lamp heads (each head glows
## whether lit or not). The portals are built at setup, each with its
## collider and, seen from past DOOR_FROM m, a dark door in its opening (the
## far land's coarse chunks aren't holed).
##
## Seed 1's wilderness, with the bed (RailTrack.wanted); `--no-railroad`
## leaves it out.

const RailLine = preload("res://scripts/endless/rail_line.gd")
const RailBed = preload("res://scripts/endless/rail_bed.gd")
const RailTrack = preload("res://scripts/endless/rail_track.gd")
const BoreShape = preload("res://scripts/endless/rail_bore_shape.gd")
const Plan = preload("res://scripts/endless/rail_bore_plan.gd")
const BoreMesh = preload("res://scripts/endless/rail_bore_mesh.gd")
const LandTunnels = preload("res://scripts/endless/land_tunnels.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const SkyGlide = preload("res://scripts/sky_glide.gd")
const LINING_SHADER = preload("res://shaders/rail_bore_lining.gdshader")

const UNDER_LAYER := LandTunnels.UNDER_LAYER
const LAYER := 1
## The tube's pieces (m of s).
const PIECE := 48.0
## Built within FAR m of the eye, freed past FREE_AT x; colliders within
## COLLIDE of the plane; build time a frame (ms).
const FAR := 1100.0
const FREE_AT := 1.25
const COLLIDE := 140.0
const BUDGET_MS := 1.5
## The inside's first DAY_IN m from each face is in the day (the sun on it).
const DAY_IN := 14.0
## The blocks sink this far under the bed (their foot in the cut).
const SINK := 3.0
## The dark door: just in from the block's face, seen past DOOR_FROM m
## (the far land's coarse chunks fill the opening).
const DOOR_FROM := 300.0
const DOOR_C := Color(0.03,0.025,0.02)
## The lamps: the LIGHT_POOL nearest the eye within LIGHT_REACH lit, each
## reaching LIGHT_RANGE m, so the lamps' pools have dark between them.
const LIGHT_POOL := 8
const LIGHT_REACH := 360.0
const LIGHT_RANGE := 32.0
const LIGHT_ENERGY := 6.0
const LIGHT_ATTEN := 1.3
const LIGHT_COLOR := Color(1.0,0.76,0.48)
const HEAD_COLOR := Color(1.0,0.82,0.55)
## The portals' sky fill in shade (the lining shader's `sky_fill`).
const PORTAL_SKY := 0.5
## How far in front of a portal's face its wing walls reach (m along s).
const WINGS_OUT := 20.0
## The guard (`guide`, `keep`), as LandTunnels'.
const GUARD_MARGIN := LandTunnels.GUARD_MARGIN
const GUARD_PUSH := LandTunnels.GUARD_PUSH
const GUARD_LIFT := LandTunnels.GUARD_LIFT
const GUARD_LOOK := LandTunnels.GUARD_LOOK
const GUARD_ROOF := LandTunnels.GUARD_ROOF
const GUARD_FLOOR := LandTunnels.GUARD_FLOOR
const KEEP_IN := LandTunnels.KEEP_IN
const KEEP_OFF := 0.6
const KEEP_UP := 1.5
## The camera's sight in a bore: marched every SIGHT_STEP m.
const SIGHT_STEP := 1.0
const SIGHT_UP := 60.0

var line: RefCounted
var field: RefCounted
var plan: RefCounted
var _build: RefCounted
var _bed: RefCounted
## The tunnels: [s0, s1] each, and each one's XZ box (grown).
var _tunnels: Array = []
var _boxes: Array[Rect2] = []
var _half := 16.5
var _crown := 18.0
var _face := 24.5
var _top := 26.0
var _grow := 0.0
## The tube's pieces: s0, s1, centre, radius, tunnel; their nodes.
var _ps0 := PackedFloat32Array()
var _ps1 := PackedFloat32Array()
var _pc := PackedVector3Array()
var _pr := PackedFloat32Array()
var _pt := PackedInt32Array()
var _mesh: Array = []
var _body: Array = []
var _faces: Array = []
var _lining: ShaderMaterial
var _stone: Material
var _head: StandardMaterial3D
var _door: StandardMaterial3D
var _lights: Array[OmniLight3D] = []
var _spots := PackedVector3Array()
## The wing walls: {a, b (XZ), half, foot, top_a, top_b}.
var _wings: Array = []
var _sky_cut := false
## Set by `sight`: the whole march was in the tube's reach.
var sight_whole := false
## Pieces built so far (a driver's count), and the blocks' faces.
var built := 0
var block_tris := 0
var piece_tris := 0

func setup(land_field: RefCounted) -> void:
	field = land_field
	line = RailLine.shared()
	_bed = RailBed.new()
	plan = Plan.shared(field)
	_build = BoreMesh.new(plan,line)
	_half = BoreShape.half()
	_crown = BoreShape.crown()
	_face = BoreShape.face_half()
	_top = BoreShape.block_top()
	_grow = WorldScale.span*0.5
	_tunnels = line.stretches("tunnel")
	_lining = ShaderMaterial.new()
	_lining.shader = LINING_SHADER
	# The portals in the same stone out of doors, the sky's light in its shade.
	_stone = _lining.duplicate()
	_stone.set_shader_parameter("fill",0.0)
	_stone.set_shader_parameter("sky_fill",PORTAL_SKY)
	_head = StandardMaterial3D.new()
	_head.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_head.albedo_color = HEAD_COLOR
	_door = StandardMaterial3D.new()
	_door.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_door.albedo_color = DOOR_C
	var ti := 0
	for st: Array in _tunnels:
		var s0 := float(st[0])-BoreShape.FACE_OUT
		var s1 := float(st[1])+BoreShape.FACE_OUT
		var box := Rect2(Vector2(line.centre(s0).x,line.centre(s0).z),Vector2.ZERO)
		var s := s0
		while s < s1:
			var e := minf(s+PIECE,s1)
			var c: Vector3 = line.centre((s+e)*0.5)
			_ps0.append(s)
			_ps1.append(e)
			_pc.append(c)
			_pr.append((e-s)*0.5+Plan.CAVERN_HALF)
			_pt.append(ti)
			box = box.expand(Vector2(line.centre(e).x,line.centre(e).z)).expand(Vector2(c.x,c.z))
			s = e
		_boxes.append(box.grow(_face+WINGS_OUT+10.0))
		var kinds: Array = plan.tunnels[ti].portals
		for k in 2: _build_portal(s0+BoreShape.FACE_OUT if k == 0 else s1-BoreShape.FACE_OUT,1.0 if k == 0 else -1.0,int(kinds[k]))
		ti += 1
	for i in plan.lamp_s.size():
		_spots.append(_build.at(float(plan.lamp_s[i]),float(plan.lamp_d[i])*0.94,float(plan.lamp_y[i])-0.4))
	for a: Array in [_mesh,_body,_faces]: a.resize(_ps0.size())
	for i in LIGHT_POOL:
		var l := OmniLight3D.new()
		l.light_color = LIGHT_COLOR
		l.light_energy = LIGHT_ENERGY
		l.omni_range = LIGHT_RANGE
		l.omni_attenuation = LIGHT_ATTEN
		l.shadow_enabled = false
		l.visible = false
		add_child(l)
		_lights.append(l)

## Each frame: the tube's pieces near the eye, colliders near the plane,
## the lamps nearest the eye.
func step(eye: Vector3, plane_at: Vector3) -> void:
	if line == null: return
	if not _sky_cut: _cut_sky()
	var t0 := Time.get_ticks_usec()
	var wants: Array[Vector2] = []
	for i in _ps0.size():
		var d := eye.distance_to(_pc[i])-_pr[i]
		if _mesh[i] == null:
			if d < FAR: wants.append(Vector2(d,i))
		elif d > FAR*FREE_AT:
			for a: Array in [_mesh,_body]:
				if a[i] != null: a[i].queue_free()
				a[i] = null
			_faces[i] = null
			continue
		var dp := plane_at.distance_to(_pc[i])-_pr[i]
		if _body[i] == null:
			if dp < COLLIDE and _faces[i] != null: _collide(i)
		elif dp > COLLIDE*FREE_AT:
			_body[i].queue_free()
			_body[i] = null
	wants.sort()
	for w: Vector2 in wants:
		_build_piece(int(w.y))
		if (Time.get_ticks_usec()-t0) > BUDGET_MS*1000.0: break
	_light(eye)

func prime(eye: Vector3) -> void:
	for i in _ps0.size():
		if eye.distance_to(_pc[i])-_pr[i] < FAR*0.5 and _mesh[i] == null: _build_piece(i)
	_light(eye)

func _light(eye: Vector3) -> void:
	var near: Array = []
	for i in _spots.size():
		var d := _spots[i].distance_to(eye)
		if d < LIGHT_REACH: near.append(Vector2(d,i))
	near.sort()
	for j in _lights.size():
		_lights[j].visible = j < near.size()
		if j < near.size(): _lights[j].position = _spots[int(near[j].y)]

func _cut_sky() -> void:
	var lights: Array = get_tree().root.find_children("*","DirectionalLight3D",true,false)
	for l: DirectionalLight3D in lights: l.light_cull_mask &= ~UNDER_LAYER
	_sky_cut = not lights.is_empty()

# --- Building -------------------------------------------------------------------------

## The tunnel `s` is in (its index), and how far in from its nearer face
## (negative in front of it, to the wing walls' reach).
func _which(s: float) -> Vector2:
	for t in _tunnels.size():
		var st: Array = _tunnels[t]
		var into := minf(s-float(st[0]),float(st[1])-s)
		if into >= -WINGS_OUT-BoreShape.FACE_OUT: return Vector2(t,into)
	return Vector2(-1,-INF)

func _build_piece(i: int) -> void:
	var got: Dictionary = _build.piece(_ps0[i],_ps1[i],DAY_IN,_pt[i])
	var node := Node3D.new()
	for pair: Array in [[got.day,1,_lining],[got.under,UNDER_LAYER,_lining],[got.heads,1,_head],[got.heads_under,UNDER_LAYER,_head]]:
		var mm: BoreMesh.M = pair[0]
		if mm.empty(): continue
		var mi: MeshInstance3D = mm.instance(pair[2])
		mi.layers = int(pair[1])
		node.add_child(mi)
		piece_tris += mm.v.size()/3
	var day_m := BoreMesh.M.new()
	var under_m := BoreMesh.M.new()
	var solids: Array[PackedVector3Array] = []
	for mem: Dictionary in got.members:
		var mm: BoreMesh.M = mem.m
		solids.append(mm.v)
		var into: BoreMesh.M = day_m if bool(mem.day) else under_m
		into.v.append_array(mm.v)
		into.n.append_array(mm.n)
		into.c.append_array(mm.c)
		into.uv.append_array(mm.uv)
		into.uv2.append_array(mm.uv2)
	for pair: Array in [[day_m,1],[under_m,UNDER_LAYER]]:
		var mm: BoreMesh.M = pair[0]
		if mm.empty(): continue
		var mi: MeshInstance3D = mm.instance(_lining)
		mi.layers = int(pair[1])
		node.add_child(mi)
		piece_tris += mm.v.size()/3
	add_child(node)
	_mesh[i] = node
	var faces := (got.day as BoreMesh.M).v.duplicate()
	faces.append_array((got.under as BoreMesh.M).v)
	_faces[i] = [faces,solids]
	built += 1

func _collide(i: int) -> void:
	var f: Array = _faces[i]
	var shapes: Array[PackedVector3Array] = [f[0]]
	shapes.append_array(f[1])
	_body[i] = _body_of(shapes)

func _body_of(shapes: Array[PackedVector3Array]) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = LAYER
	body.collision_mask = 0
	for faces: PackedVector3Array in shapes:
		if faces.is_empty(): continue
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(faces)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
	add_child(body)
	return body

## A portal at the face `s` (the tunnel's first metre), the tunnel running
## `dir` along s from it, of the plan's `kind`; its collider, wing walls and
## dark door.
func _build_portal(s: float, dir: float, kind: int) -> void:
	var got: Dictionary = _build.portal(s,dir,kind)
	var m: BoreMesh.M = got.m
	add_child(m.instance(_stone))
	_body_of([m.v])
	block_tris += m.v.size()/3
	_wings.append_array(got.wings)
	# The dark door, for the far eye.
	var tg: Vector3 = line.tangent(s)
	var fwd := Vector3(tg.x,0.0,tg.z).normalized()*dir
	var r := Vector3(-fwd.z,0.0,fwd.x)
	var c: Vector3 = line.centre(s)
	var front := c-fwd*BoreShape.FACE_OUT
	var up := Vector3.UP
	var prof: Array = _build.profile(s,0.0)
	var pts: PackedVector2Array = prof[0]
	var d := RailTrack._Mesh.new()
	var o := front+fwd*0.3
	for k in pts.size()-3:
		var a := pts[k]
		var b := pts[k+1]
		d.quad(o+r*a.x+up*a.y,o+r*b.x+up*b.y,o,o,-fwd,DOOR_C)
	var dm := d.instance(_door)
	dm.visibility_range_begin = DOOR_FROM
	add_child(dm)

# --- The flight's answers ---------------------------------------------------------------

## Vector4(s, d, bed, into) for `p` near a tunnel (d + on the right of +s;
## into: m in from the nearer face), or s NAN.
func _at(p: Vector3) -> Vector4:
	var no := Vector4(NAN,0.0,0.0,0.0)
	if _boxes.is_empty(): return no
	var hit := false
	for b: Rect2 in _boxes:
		if b.has_point(Vector2(p.x,p.z)):
			hit = true
			break
	if not hit: return no
	var a: Vector3 = _bed.across(p.x,p.z)
	if is_nan(a.x) or p.y > a.z+Plan.CAVERN_CROWN+SIGHT_UP: return no
	var w := _which(a.x)
	if w.x < 0.0: return no
	return Vector4(a.x,a.y,a.z,w.y)

## Vector2(floor, roof) of the opening at `q`, `grow` m in off the stone;
## NAN out of it (beside it, or in front of the portal's proud stones).
func _bore(q: Vector4, grow: float) -> Vector2:
	if is_nan(q.x) or q.w < -BoreShape.FACE_OUT-BoreMesh.PROJECT-grow: return Vector2(NAN,NAN)
	var r: float = plan.roof_over(q.x,absf(q.y)+grow)
	if is_nan(r): return Vector2(NAN,NAN)
	return Vector2(q.z,q.z+r-grow*0.0)

## The members' solid stretches (world y) at `q`, grown `grow`, lowest first.
func _solids(q: Vector4, grow: float) -> Array[Vector2]:
	if q.w < 0.0: return []
	var list: Array[Vector2] = plan.stretches(q.x,q.y,grow)
	if list.is_empty(): return list
	for k in list.size(): list[k] += Vector2(q.z,q.z)
	if list.size() > 1: list.sort()
	return list

## Whether `q` is on a portal's footprint (its proud stones too), grown `grow`.
func _on_block(q: Vector4, grow: float) -> bool:
	return not is_nan(q.x) and q.w >= -BoreShape.FACE_OUT-BoreMesh.PROJECT-grow and q.w <= BoreShape.BLOCK_IN+grow and absf(q.y) < _face+grow

## The top (world y) of a wing wall under `p`, grown `grow`, or -INF.
func _wing(p: Vector3, q: Vector4, grow: float) -> float:
	if q.w > 0.0 or q.w < -WINGS_OUT-BoreShape.FACE_OUT-grow: return -INF
	var best := -INF
	var x := Vector2(p.x,p.z)
	for w: Dictionary in _wings:
		var a: Vector2 = w.a
		var b: Vector2 = w.b
		var ab := b-a
		var t := clampf((x-a).dot(ab)/ab.length_squared(),0.0,1.0)
		if x.distance_to(a+ab*t) > float(w.half)+grow: continue
		if p.y < float(w.foot)-1.0: continue
		best = maxf(best,lerpf(float(w.top_a),float(w.top_b),t))
	return best

## The plane's ground (`plane_ground`): in the opening under its roof, its
## floor raised by what stands on it (a rock fall, a spur, a pillar to the
## roof), or nearer something over it Vector2(its top, its underside) to
## slide under (LandHalls `over`): an arcade's arch, the roof; on a block or
## a wing wall, its top; elsewhere `h` (over the vault and beside it the rock
## stands to the land's top).
func ground(p: Vector3, h: Variant, pad := -1.0) -> Variant:
	if line == null or not h is float: return h
	var q := _at(p)
	if is_nan(q.x): return h
	var grow := _grow if pad < 0.0 else pad
	var b := _bore(q,grow)
	if not is_nan(b.x) and p.y < b.y:
		var over := q.z+_top if _on_block(q,0.0) else maxf(float(h),b.y)
		var top := b.x
		for st: Vector2 in _solids(q,grow):
			if st.x <= top+0.6:
				top = maxf(top,st.y)
				continue
			if p.y >= (top+st.x)*0.5: return Vector2(st.y,st.x)
			break
		if top >= b.y: return top
		if p.y >= (top+b.y)*0.5: return Vector2(over,b.y)
		return top
	if _on_block(q,grow): return maxf(float(h),q.z+_top)
	var w := _wing(p,q,grow)
	if w > -INF: return maxf(float(h),w)
	return h

## The solid's top under `p` over the land's `h`: the floor (or what stands
## on it under `p`) in the opening under its roof, a block's or a wing
## wall's top on it, else `h`.
func land_y(p: Vector3, h: float) -> float:
	var q := _at(p)
	if is_nan(q.x): return h
	var b := _bore(q,0.0)
	if not is_nan(b.x) and p.y < b.y:
		var y := b.x
		for st: Vector2 in _solids(q,0.0):
			if st.x <= y+0.6 and p.y >= (st.x+st.y)*0.5: y = maxf(y,st.y)
		return y
	if _on_block(q,0.0): return maxf(h,q.z+_top)
	var w := _wing(p,q,0.0)
	if w > -INF and p.y >= w-1.0: return maxf(h,w)
	return h

## In the stone round the bore (the camera keeps out, the wheels stop):
## under its floor, over its roof under the land, in a member, a block or a
## wing wall. Beside the bore the land's own height answers.
func inside(p: Vector3) -> bool:
	var q := _at(p)
	if is_nan(q.x): return false
	var b := _bore(q,0.0)
	if not is_nan(b.x):
		if p.y < b.x: return true
		if p.y < b.y: return _in_solid(q,p.y)
	if _on_block(q,0.0) and p.y < q.z+_top: return true
	if p.y < _wing(p,q,0.0): return true
	if is_nan(b.x) or q.w < 0.0: return false
	return p.y < float(field.height(p.x,p.z))

func _in_solid(q: Vector4, y: float) -> bool:
	for st: Vector2 in _solids(q,0.0):
		if y >= st.x and y <= st.y: return true
	return false

## 1 in the stone, 0 in the open bore, -1 elsewhere (ask `inside`, `land_y`).
func tube(p: Vector3) -> int:
	var q := _at(p)
	if is_nan(q.x) or q.w < 0.0: return -1
	var b := _bore(q,0.0)
	if is_nan(b.x): return -1
	if p.y < b.x: return 1
	if p.y < b.y: return 1 if _in_solid(q,p.y) else 0
	return 1 if p.y < float(field.height(p.x,p.z)) else -1

## Whether `p` is near enough a bore for the fine march.
func near(p: Vector3) -> bool:
	var q := _at(p)
	return not is_nan(q.x) and q.w > -BoreShape.FACE_OUT-BoreMesh.PROJECT-4.0 and absf(q.y) < maxf(_face,(plan.section(q.x) as Vector3).x)+30.0 and p.y < q.z+maxf(_top,(plan.section(q.x) as Vector3).y+(plan.section(q.x) as Vector3).z)+SIGHT_UP

## The camera's sight from `from` to `to` near a bore (LandTunnels `sight`).
func sight(from: Vector3, to: Vector3) -> float:
	sight_whole = false
	if line == null or (not near(from) and not near(to)): return 1.0
	var n := maxi(1,ceili(from.distance_to(to)/SIGHT_STEP))
	var whole := true
	for i in range(1,n+1):
		var p := from.lerp(to,float(i)/n)
		var got := tube(p)
		if got < 0:
			whole = false
			if inside(p) or p.y < land_y(p,float(field.height(p.x,p.z))): got = 1
		if got == 1:
			sight_whole = whole
			return float(i-1)/n
	sight_whole = whole
	return 1.0

## SkyGlide's `guide` in the bore under its roof (LandTunnels `guide`): a
## soft push off the walls, the roof and the floor, the heading eased along.
func guide(p: Vector3, heading: float, speed: float) -> Dictionary:
	var q := _at(p)
	if is_nan(q.x) or q.w < 0.0: return {}
	var b := _bore(q,0.0)
	if is_nan(b.x) or p.y >= b.y: return {}
	var h := p.y-q.z
	var t3: Vector3 = line.tangent(q.x)
	var tg := Vector2(t3.x,t3.z).normalized()
	var across := Vector3(-tg.y,0.0,tg.x)
	var fwd := Vector2(-sin(heading),-cos(heading))
	var sense := 1.0 if fwd.dot(tg) >= 0.0 else -1.0
	var room := INF
	for ds: float in [0.0,sense*maxf(speed,10.0)*GUARD_LOOK]:
		room = minf(room,_room(q.x+ds,h))
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

## SkyGlide's `keep`: in a bore past its clear room across or over its
## roof, put back on that edge (LandTunnels `keep`).
func keep(p: Vector3) -> Vector3:
	var q := _at(p)
	if is_nan(q.x) or q.w < 0.0: return p
	var h := p.y-q.z
	var sc: Vector3 = plan.section(q.x)
	if absf(q.y) > sc.x+8.0 or h > sc.y+sc.z or h < -2.0: return p
	var room := maxf(_room(q.x,h),0.0)
	var out := p
	if absf(q.y) > room-KEEP_IN:
		var t3: Vector3 = line.tangent(q.x)
		var across := Vector3(-t3.z,0.0,t3.x).normalized()
		out -= across*signf(q.y)*(absf(q.y)-maxf(room-KEEP_IN,0.0))
	var bg := _bore(_at(out),_grow)
	if not is_nan(bg.y) and out.y > bg.y-SkyGlide.CLEAR-KEEP_IN: out.y = bg.y-SkyGlide.CLEAR-KEEP_IN
	return out

## The clear half width `h` m over the floor at s (the wall at CLEAR over
## it, less the wingtip's reach).
func _room(s: float, h: float) -> float:
	return float(plan.half_at(s,h+SkyGlide.CLEAR+KEEP_UP))-_grow-KEEP_OFF

func note() -> String:
	return "rail bore: %d tunnels, %d pieces built (%d tris), portals %d tris; %s" % [_tunnels.size(),built,piece_tris,block_tris,plan.note()]
