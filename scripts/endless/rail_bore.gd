extends Node3D
## The railroad's tunnels (spec-railroad.md, lane line): a double-track bore
## along the line (rail_line.gd) through each tunnel stretch, and a portal
## block of dressed stone at each mouth, in greybox, as the flight, the
## camera and the wheels meet them, in the ice tunnel's manner
## (land_ice_tunnel.gd). The cross-section and the blocks' sizes are
## rail_bore_shape.gd's; the land round them is rail_bed.gd's: raised to a
## cover over the bore, so the bore is always in the rock, and holed under
## each block, which hides the hole's edges.
##
## The land's surface stays whole over the bore, so in the bore and beside
## it the land's height is not the solid: `ground`, `land_y` and `inside`
## answer for the rock round the tube and for the blocks.
##
## The tube is built in PIECE m pieces of the line within FAR of the eye,
## nearest first in BUDGET_MS a frame, and freed past FREE_AT x that;
## its colliders (physics layer 1, backface trimesh) within COLLIDE of the
## plane. Its inside is on LandTunnels.UNDER_LAYER, which the sun and the
## moon leave out, but for its first DAY_IN m from each face: lit by a pool
## of lamps along it, the nearest the eye. The blocks are built at setup,
## each with its collider and, seen from past DOOR_FROM m, a dark door in
## its opening (the far land's coarse chunks aren't holed).
##
## Seed 1's wilderness, with the bed (RailTrack.wanted); `--no-railroad`
## leaves it out.

const RailLine = preload("res://scripts/endless/rail_line.gd")
const RailBed = preload("res://scripts/endless/rail_bed.gd")
const RailTrack = preload("res://scripts/endless/rail_track.gd")
const BoreShape = preload("res://scripts/endless/rail_bore_shape.gd")
const LandTunnels = preload("res://scripts/endless/land_tunnels.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const SkyGlide = preload("res://scripts/sky_glide.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")

const UNDER_LAYER := LandTunnels.UNDER_LAYER
const LAYER := 1
## The tube's pieces (m of s), rings every RING m; segments over the vault.
const PIECE := 48.0
const RING := 3.0
const VAULT_SEGS := 14
## Built within FAR m of the eye, freed past FREE_AT x; colliders within
## COLLIDE of the plane; build time a frame (ms).
const FAR := 1100.0
const FREE_AT := 1.25
const COLLIDE := 140.0
const BUDGET_MS := 1.5
## The inside's first DAY_IN m from each face is in the day (the sun on it).
const DAY_IN := 14.0
## The stone: walls in bands BAND m long, every other one darker, so the
## speed reads in the dark; the floor; the blocks.
const BAND := 6.0
const WALL_C := Color(0.42,0.38,0.34)
const WALL_DARK := 0.82
const FLOOR_C := Color(0.30,0.28,0.26)
const BLOCK_C := Color(0.62,0.56,0.48)
const BLOCK_TOP_C := Color(0.55,0.5,0.43)
const ARCH_C := Color(0.72,0.66,0.57)
## The blocks sink this far under the bed (their foot in the cut); the
## tube's floor lies this far under it (the land's flat left at a hole's
## front lies on the bed).
const SINK := 3.0
const FLOOR_UNDER := 0.06
## The dark door: just in from the block's face, seen past DOOR_FROM m
## (the far land's coarse chunks fill the opening).
const DOOR_FROM := 300.0
const DOOR_C := Color(0.03,0.025,0.02)
## The lamps: one every LIGHT_EVERY m along a tunnel, LIGHT_UP of the crown
## over the floor, the LIGHT_POOL nearest the eye within LIGHT_REACH lit.
const LIGHT_EVERY := 55.0
const LIGHT_UP := 0.8
const LIGHT_POOL := 6
const LIGHT_REACH := 400.0
const LIGHT_RANGE := 46.0
const LIGHT_ENERGY := 5.0
const LIGHT_COLOR := Color(1.0,0.78,0.52)
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
var _bed: RefCounted
## The tunnels: [s0, s1] each, and each one's XZ box (grown).
var _tunnels: Array = []
var _boxes: Array[Rect2] = []
var _half := 16.5
var _crown := 18.0
var _face := 24.5
var _top := 26.0
var _grow := 0.0
## The tube's pieces: s0, s1, centre, radius; their nodes.
var _ps0 := PackedFloat32Array()
var _ps1 := PackedFloat32Array()
var _pc := PackedVector3Array()
var _pr := PackedFloat32Array()
var _mesh: Array = []
var _body: Array = []
var _faces: Array = []
var _wall: StandardMaterial3D
var _stone: Material
var _door: StandardMaterial3D
var _lights: Array[OmniLight3D] = []
var _spots := PackedVector3Array()
var _sky_cut := false
## Set by `sight`: the whole march was in the tube's reach.
var sight_whole := false
## Pieces built so far (a driver's count), and the blocks' faces.
var built := 0
var block_tris := 0

func setup(land_field: RefCounted) -> void:
	field = land_field
	line = RailLine.shared()
	_bed = RailBed.new()
	_half = BoreShape.half()
	_crown = BoreShape.crown()
	_face = BoreShape.face_half()
	_top = BoreShape.block_top()
	_grow = WorldScale.span*0.5
	_tunnels = line.stretches("tunnel")
	_wall = StandardMaterial3D.new()
	_wall.vertex_color_use_as_albedo = true
	_wall.roughness = 0.95
	# The blocks in the ruins' stone, which takes the sky's light in shade.
	_stone = RuinKit.materials().stone
	_door = StandardMaterial3D.new()
	_door.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_door.albedo_color = DOOR_C
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
			_pr.append((e-s)*0.5+_face)
			box = box.expand(Vector2(line.centre(e).x,line.centre(e).z)).expand(Vector2(c.x,c.z))
			s = e
		_boxes.append(box.grow(_face+30.0))
		for k in 2: _build_block(s0+BoreShape.FACE_OUT if k == 0 else s1-BoreShape.FACE_OUT,1.0 if k == 0 else -1.0)
		var n := maxi(1,floori((s1-s0)/LIGHT_EVERY))
		for q in n:
			var at: Vector3 = line.centre(s0+(q+0.5)*(s1-s0)/n)
			_spots.append(at+Vector3.UP*_crown*LIGHT_UP)
	for a: Array in [_mesh,_body,_faces]: a.resize(_ps0.size())
	for i in LIGHT_POOL:
		var l := OmniLight3D.new()
		l.light_color = LIGHT_COLOR
		l.light_energy = LIGHT_ENERGY
		l.omni_range = LIGHT_RANGE
		l.omni_attenuation = 1.2
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

## The ring's profile: (d, y over the floor) round from the left floor edge
## up the left wall, over the vault, down the right wall and back across the
## floor; a face's colour index (0 wall, 1 floor) per segment.
func _profile() -> Array:
	var pts := PackedVector2Array([Vector2(-_half,0.0),Vector2(-_half,BoreShape.SPRING)])
	var rise := BoreShape.rise()
	for k in range(1,VAULT_SEGS):
		var th := PI*(1.0-float(k)/VAULT_SEGS)
		pts.append(Vector2(_half*cos(th),BoreShape.SPRING+rise*sin(th)))
	pts.append_array([Vector2(_half,BoreShape.SPRING),Vector2(_half,0.0),Vector2(0.0,0.0),Vector2(-_half,0.0)])
	return [pts,pts.size()-3]

## The tunnel `s` is in (its index), and how far in from its nearer face.
func _which(s: float) -> Vector2:
	for t in _tunnels.size():
		var st: Array = _tunnels[t]
		var into := minf(s-float(st[0]),float(st[1])-s)
		if into >= -BoreShape.FACE_OUT-RING: return Vector2(t,into)
	return Vector2(-1,-INF)

func _build_piece(i: int) -> void:
	var prof: Array = _profile()
	var pts: PackedVector2Array = prof[0]
	var floor_from: int = prof[1]
	var day := RailTrack._Mesh.new()
	var under := RailTrack._Mesh.new()
	var s0 := _ps0[i]
	var s1 := _ps1[i]
	var steps := maxi(1,ceili((s1-s0)/RING))
	var rings: Array[PackedVector3Array] = []
	var mids := PackedVector3Array()
	for k in steps+1:
		var s := lerpf(s0,s1,float(k)/steps)
		var c: Vector3 = line.centre(s)+Vector3.DOWN*FLOOR_UNDER
		var tg: Vector3 = line.tangent(s)
		var r := Vector3(-tg.z,0.0,tg.x).normalized()
		var ring := PackedVector3Array()
		for p: Vector2 in pts: ring.append(c+r*p.x+Vector3.UP*p.y)
		rings.append(ring)
		mids.append(c+Vector3.UP*_crown*0.5)
	for k in steps:
		var s := lerpf(s0,s1,(k+0.5)/steps)
		var w := _which(s)
		var m: RefCounted = day if w.y < DAY_IN else under
		var dark := WALL_DARK if int(floor(s/BAND))%2 == 1 else 1.0
		var a := rings[k]
		var b := rings[k+1]
		var mid := (mids[k]+mids[k+1])*0.5
		for q in pts.size()-1:
			var col := FLOOR_C if q >= floor_from else WALL_C*dark
			col.a = 1.0
			var f := (a[q]+b[q+1])*0.5
			m.quad(a[q],b[q],b[q+1],a[q+1],mid-f,col)
	var node := Node3D.new()
	for pair: Array in [[day,1],[under,UNDER_LAYER]]:
		var mm: RefCounted = pair[0]
		if mm.verts.is_empty(): continue
		var mi: MeshInstance3D = mm.instance(_wall)
		mi.layers = int(pair[1])
		node.add_child(mi)
	add_child(node)
	_mesh[i] = node
	var faces := day.verts.duplicate()
	faces.append_array(under.verts)
	_faces[i] = faces
	built += 1

func _collide(i: int) -> void:
	_body[i] = _body_of(_faces[i])

func _body_of(faces: PackedVector3Array) -> StaticBody3D:
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var body := StaticBody3D.new()
	body.collision_layer = LAYER
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	return body

## A portal block at the face `s` (the tunnel's first metre), the tunnel
## running `dir` along s from it: piers either side of the opening, the
## arch's spandrel over it, its top, sides and back; and its dark door.
func _build_block(s: float, dir: float) -> void:
	var m := RailTrack._Mesh.new()
	var prof: Array = _profile()
	var pts: PackedVector2Array = prof[0]
	var arch := pts.slice(1,VAULT_SEGS+2)   # the spring, over the vault, the spring
	var tg: Vector3 = line.tangent(s)
	var fwd := Vector3(tg.x,0.0,tg.z).normalized()*dir
	var r := Vector3(-fwd.z,0.0,fwd.x)
	var c: Vector3 = line.centre(s)
	var front := c-fwd*BoreShape.FACE_OUT
	var back := c+fwd*BoreShape.BLOCK_IN
	var up := Vector3.UP
	var low := -SINK
	for side: Array in [[front,-fwd],[back,fwd]]:
		var o: Vector3 = side[0]
		var out: Vector3 = side[1]
		# The piers.
		for sg: float in [-1.0,1.0]:
			m.quad(o+r*sg*_face+up*low,o+r*sg*_half+up*low,o+r*sg*_half+up*_top,o+r*sg*_face+up*_top,out,BLOCK_C)
		# The spandrel: strips from the arch up to the top.
		for k in arch.size()-1:
			var a := arch[k]
			var b := arch[k+1]
			m.quad(o+r*a.x+up*a.y,o+r*b.x+up*b.y,o+r*b.x+up*_top,o+r*a.x+up*_top,out,BLOCK_C)
		# The arch's ring, a lighter course round the opening.
		for k in arch.size()-1:
			var a := arch[k]
			var b := arch[k+1]
			var na := Vector2(a.x,(a.y-BoreShape.SPRING)*_half/BoreShape.rise()).normalized()
			var nb := Vector2(b.x,(b.y-BoreShape.SPRING)*_half/BoreShape.rise()).normalized()
			var a2 := a+na*2.2
			var b2 := b+nb*2.2
			m.quad(o+out*0.3+r*a.x+up*a.y,o+out*0.3+r*b.x+up*b.y,o+out*0.3+r*b2.x+up*b2.y,o+out*0.3+r*a2.x+up*a2.y,out,ARCH_C)
	# The top and the outer sides.
	m.quad(front-r*_face+up*_top,front+r*_face+up*_top,back+r*_face+up*_top,back-r*_face+up*_top,up,BLOCK_TOP_C)
	for sg: float in [-1.0,1.0]:
		m.quad(front+r*sg*_face+up*low,back+r*sg*_face+up*low,back+r*sg*_face+up*_top,front+r*sg*_face+up*_top,r*sg,BLOCK_C)
	var mi := m.instance(_stone)
	add_child(mi)
	_body_of(m.verts)
	block_tris += m.verts.size()/3
	# The dark door, for the far eye.
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
	if is_nan(a.x) or p.y > a.z+_top+SIGHT_UP: return no
	var w := _which(a.x)
	if w.x < 0.0: return no
	return Vector4(a.x,a.y,a.z,w.y)

## Vector2(floor, roof) of the opening at `q`, `grow` m in off the stone;
## NAN out of it (beside it, or in front of the block's face).
func _bore(q: Vector4, grow: float) -> Vector2:
	if is_nan(q.x) or q.w < -BoreShape.FACE_OUT-grow: return Vector2(NAN,NAN)
	var r := BoreShape.roof_over(absf(q.y)+grow)
	if is_nan(r): return Vector2(NAN,NAN)
	return Vector2(q.z,q.z+r)

## Whether `q` is on a block's footprint, grown `grow`.
func _on_block(q: Vector4, grow: float) -> bool:
	return not is_nan(q.x) and q.w >= -BoreShape.FACE_OUT-grow and q.w <= BoreShape.BLOCK_IN+grow and absf(q.y) < _face+grow

## The plane's ground (`plane_ground`): in the opening under its roof, its
## floor, or nearer the roof Vector2(the stone's top, the roof) to slide
## under (LandHalls `over`); on a block, its top; elsewhere `h` (over the
## vault and beside it the rock stands to the land's top).
func ground(p: Vector3, h: Variant, pad := -1.0) -> Variant:
	if line == null or not h is float: return h
	var q := _at(p)
	if is_nan(q.x): return h
	var grow := _grow if pad < 0.0 else pad
	var b := _bore(q,grow)
	if not is_nan(b.x) and p.y < b.y:
		var over := q.z+_top if _on_block(q,0.0) else maxf(float(h),b.y)
		if p.y >= (b.x+b.y)*0.5: return Vector2(over,b.y)
		return b.x
	if _on_block(q,grow): return maxf(float(h),q.z+_top)
	return h

## The solid's top under `p` over the land's `h`: the floor in the opening
## under its roof, a block's top on it, else `h`.
func land_y(p: Vector3, h: float) -> float:
	var q := _at(p)
	if is_nan(q.x): return h
	var b := _bore(q,0.0)
	if not is_nan(b.x) and p.y < b.y: return b.x
	if _on_block(q,0.0): return maxf(h,q.z+_top)
	return h

## In the stone round the bore (the camera keeps out, the wheels stop):
## under its floor, over its roof under the land, in a block. Beside the
## bore the land's own height answers.
func inside(p: Vector3) -> bool:
	var q := _at(p)
	if is_nan(q.x): return false
	var b := _bore(q,0.0)
	if not is_nan(b.x):
		if p.y < b.x: return true
		if p.y < b.y: return false
	if _on_block(q,0.0) and p.y < q.z+_top: return true
	if is_nan(b.x) or q.w < 0.0: return false
	return p.y < float(field.height(p.x,p.z))

## 1 in the stone, 0 in the open bore, -1 elsewhere (ask `inside`, `land_y`).
func tube(p: Vector3) -> int:
	var q := _at(p)
	if is_nan(q.x) or q.w < 0.0: return -1
	var b := _bore(q,0.0)
	if is_nan(b.x): return -1
	if p.y < b.x: return 1
	if p.y < b.y: return 0
	return 1 if p.y < float(field.height(p.x,p.z)) else -1

## Whether `p` is near enough a bore for the fine march.
func near(p: Vector3) -> bool:
	var q := _at(p)
	return not is_nan(q.x) and absf(q.y) < _face+30.0 and p.y < q.z+_top+SIGHT_UP

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
		room = minf(room,_room(h))
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
	if absf(q.y) > _half+8.0 or h > _crown or h < -2.0: return p
	var room := maxf(_room(h),0.0)
	var out := p
	if absf(q.y) > room-KEEP_IN:
		var t3: Vector3 = line.tangent(q.x)
		var across := Vector3(-t3.z,0.0,t3.x).normalized()
		out -= across*signf(q.y)*(absf(q.y)-maxf(room-KEEP_IN,0.0))
	var bg := _bore(_at(out),_grow)
	if not is_nan(bg.y) and out.y > bg.y-SkyGlide.CLEAR-KEEP_IN: out.y = bg.y-SkyGlide.CLEAR-KEEP_IN
	return out

## The clear half width `h` m over the floor (the wall at CLEAR over it,
## less the wingtip's reach).
func _room(h: float) -> float:
	return BoreShape.half_at(h+SkyGlide.CLEAR+KEEP_UP)-_grow-KEEP_OFF

func note() -> String:
	return "rail bore: %d tunnels, %d pieces built, blocks %d tris" % [_tunnels.size(),built,block_tris]
