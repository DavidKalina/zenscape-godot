extends Node3D
## The mountain tunnels' bores (scripts/endless/tunnel_sites.gd), as the
## flight, the camera and the wheels meet them, and a greybox of each:
## the tube (floor, walls, flat roof) along the path, through a portal block
## at each mouth. The land's surface stays whole over the bore (the massif's
## heightmap), so under the bore's roof and inside its walls the land's
## height is not the solid: `ground`, `land_y` and `inside` answer for the
## rock round the tube. The land mesh drops its triangles on each portal's
## footprint (land_stream.gd), and the block hides the hole's edge.
##
## The hall stretches (Tunnels.stretches: one straight slot piece on each
## hall piece of the path) stand in the tube through a LandHalls of their
## own (`halls`, fixed pieces only: far detail on a worker, near detail
## streamed section by section round the eye, the kit's bodies on layer 1).
## Their solid joins the bore's: `ground` stands the hall's stretches on the
## bore's floor with the rock roof as one more stretch over them
## (LandHalls `over`), and `inside` counts them.
##
## For now every tunnel the field knows (the --tunnel-test one) is built
## whole at setup: a tube of a few thousand quads.

const Field = preload("res://scripts/endless/land_field.gd")
const Tunnels = preload("res://scripts/endless/tunnel_sites.gd")
const LandHalls = preload("res://scripts/endless/land_halls.gd")
const WorldScale = preload("res://scripts/world_scale.gd")

## Physics layer of the greybox's bodies (the walker, the wheels).
const LAYER := 1
## The portal block's top over the highest land on its footprint (m), and
## the step its footprint is read at.
const PORTAL_OVER := 1.5
const PORTAL_READ := 4.0
## The test tunnel's start: this high over the bore's floor, so the plane
## flies straight in at mouth A (unless --alt= is given).
const TEST_ALT := 9.0
## How far past the tube's walls `inside` counts the rock (m).
const WALL_NEAR := 12.0

## The greybox torch: its bracket (across, up, out of the wall), its flame
## (radius, height), the size and glow by kind.
const TORCH_BRACKET := Vector3(0.22,0.9,0.55)
const TORCH_FLAME := Vector2(0.24,0.75)
const TORCH_BIG := {"wall":1.0,"outside":1.35,"mouth":2.2}
const TORCH_GLOW := {"wall":Color(1.0,0.55,0.16),"outside":Color(1.0,0.78,0.38),"mouth":Color(1.0,0.66,0.26)}

## The carved rock's mesh: segments round a ring, across the floor, a
## cavern's rings apart (m); the lumps (m, Tunnels.ROCK_LUMP).
const RING_SEGS := 32
const FLOOR_SEGS := 6
const CAVE_RING := 2.0
const ROCK_LUMP := Tunnels.ROCK_LUMP
const HALL_ROCK_TINT := Color(0.42,0.4,0.37)
const FLOOR_TINT := Color(0.36,0.33,0.29)
const CAVE_TINT := Color(0.46,0.4,0.33)
const BLOCK_TINT := Color(0.4,0.37,0.33)

var field: RefCounted
var stats := {"tunnels":0,"tris":0,"torches":0,"stretches":0}
## The hall stretches' streamer.
var halls: Node3D
var _sites: Array = []
## The plane's wingtip: the tube's half width it may fly in.
var _grow := 0.0
var _rock_tris := 0

func setup(land_field: RefCounted) -> void:
	field = land_field
	_grow = WorldScale.span*0.5
	_sites = field.tunnel_sites() if field.has_method("tunnel_sites") else []
	halls = LandHalls.new()
	halls.name = "Stretches"
	halls.squares = false
	add_child(halls)
	halls.setup(int(field.seed))
	halls.density = 1.0
	for ti in _sites.size():
		var t: Tunnels.Site = _sites[ti]
		for m in 2: t.portal_top[m] = _portal_top(t,m)
		_build(t)
		_build_torches(t)
		for h: Dictionary in Tunnels.stretches(t):
			var frame: Transform3D = h.frame
			var half := float(h.piece.s1-h.piece.s0)*0.5
			var mid := frame*Vector3(half,0.0,0.0)
			var site := PackedFloat32Array([mid.x,mid.z,0,0,0,0,0,half+Tunnels.HALL_HALF])
			halls.add_fixed(Vector2i(ti,int(h.n)),{"name":"%s/stretch_%d" % [t.name,int(h.n)],"seed":h.seed,"bays":h.bays,
				"frame":frame,"coded":frame,"site":site})
			stats.stretches += 1
	stats.tunnels = _sites.size()

## Builds the hall stretches' far detail now, and the near detail round `at`.
func prime(at: Vector3) -> void:
	halls.prime(at)

func step(at: Vector3) -> void:
	halls.step(at)

## Where the test tunnel's start stands (world y), NAN with none.
func start_y() -> float:
	for t: Tunnels.Site in _sites:
		if t.name.ends_with("/test"): return t.floor_y+TEST_ALT
	return NAN

# --- The solid ------------------------------------------------------------------------

## The cover over (x, z): the land `h`, or the portal block's top on its
## footprint.
func _cover(t: Tunnels.Site, x: float, z: float, h: float) -> float:
	var m := Tunnels.portal_at(t,x,z)
	return h if m < 0 else maxf(h,t.portal_top[m])

## SkyGlide's `ground` at `p` over `h` (what the layers under answered), as
## LandHalls `ground`: in the tube under its roof, the hall stretch's solid
## standing on the bore's floor with the rock roof (roof to cover) over it
## (LandHalls `over`: the floor or a column's top, or Vector2(top,
## underside) for a roof the plane is nearer, which it slides under); in
## the rock round it, the cover (a wall).
func ground(p: Vector3, h: Variant) -> Variant:
	if not h is float: return h
	for t: Tunnels.Site in _sites:
		if not t.box.has_point(Vector2(p.x,p.z)): continue
		var cover := _cover(t,p.x,p.z,h)
		var b := Tunnels.bore_at(t,p.x,p.z,_grow)
		if not is_nan(b.x) and cover > b.y:
			if p.y >= b.y: return cover
			var list: Array = halls.stretches(p)
			list.append(Vector2(b.y,cover))
			return LandHalls.over(p,b.x,list)
		if cover > h: return cover
	return h

## The solid's top under `p` over the land's `h`: the bore's floor in the
## tube under its roof, else the cover.
func land_y(p: Vector3, h: float) -> float:
	for t: Tunnels.Site in _sites:
		if not t.box.has_point(Vector2(p.x,p.z)): continue
		var cover := _cover(t,p.x,p.z,h)
		var b := Tunnels.bore_at(t,p.x,p.z)
		if not is_nan(b.x) and cover > b.y and p.y < b.y: return b.x
		if cover != h: return cover
	return h

## True inside the rock round a bore or a portal's block (the camera keeps
## out, the wheels stop): under the tube's floor, over its roof under the
## cover, or in the walls beside it under the land.
func inside(p: Vector3) -> bool:
	if halls.inside(p): return true
	for t: Tunnels.Site in _sites:
		if not t.box.has_point(Vector2(p.x,p.z)): continue
		var h: float = field.height(p.x,p.z)
		var cover := _cover(t,p.x,p.z,h)
		var b := Tunnels.bore_at(t,p.x,p.z)
		if not is_nan(b.x) and cover > b.y: return p.y < b.x or (p.y > b.y and p.y < cover)
		if p.y >= cover: continue
		if cover != h: return true
		# Beside the tube, in its walls (elsewhere the land's own height
		# answers).
		var q := Tunnels.local(t,p.x,p.z)
		if q.x >= -Tunnels.PORTAL_OUT and q.x <= t.length+Tunnels.PORTAL_OUT and absf(q.y) < Tunnels.section(t,q.x).x+WALL_NEAR: return true
	return false

## One line for the numbers HUD.
func note() -> String:
	return "tunnels %d, greybox %dk tris, %d torches, %d stretches: %s" % [stats.tunnels,stats.tris/1000,stats.torches,stats.stretches,halls.note()]

# --- The greybox ----------------------------------------------------------------------

## The portal block's top at mouth `m`: over the land on its footprint.
func _portal_top(t: Tunnels.Site, m: int) -> float:
	var top := t.floor_y+Tunnels.HALL_VAULT
	var a := -Tunnels.PORTAL_OUT
	while a <= Tunnels.PORTAL_IN+0.01:
		var d := -Tunnels.PORTAL_HALF
		while d <= Tunnels.PORTAL_HALF+0.01:
			var q := Tunnels.portal_point(t,m,a,d)
			top = maxf(top,field.height(q.x,q.y))
			d += PORTAL_READ
		a += PORTAL_READ
	return top+PORTAL_OVER

func _build(t: Tunnels.Site) -> void:
	var rock := _build_rock(t)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris := 0
	# The portal blocks: a front with the tube's opening, two sides, a top.
	for m in 2:
		var top: float = t.portal_top[m]
		var lo := t.floor_y-Tunnels.SINK-2.0
		var w := Tunnels.HALL_HALF
		var k := Tunnels.PORTAL_HALF
		var a0 := -Tunnels.PORTAL_OUT
		var a1 := Tunnels.PORTAL_IN
		var vault := t.floor_y+Tunnels.HALL_VAULT
		var out := _v(t,m,a0-1.0,0.0,0.0)-_v(t,m,a0,0.0,0.0)
		tris += _quad(st,_v(t,m,a0,-k,lo),_v(t,m,a0,-w,lo),_v(t,m,a0,-w,top),_v(t,m,a0,-k,top),out,BLOCK_TINT)
		tris += _quad(st,_v(t,m,a0,w,lo),_v(t,m,a0,k,lo),_v(t,m,a0,k,top),_v(t,m,a0,w,top),out,BLOCK_TINT)
		tris += _quad(st,_v(t,m,a0,-w,vault),_v(t,m,a0,w,vault),_v(t,m,a0,w,top),_v(t,m,a0,-w,top),out,BLOCK_TINT)
		for side: float in [-1.0,1.0]:
			var sn := _v(t,m,0.0,side*(k+1.0),0.0)-_v(t,m,0.0,side*k,0.0)
			tris += _quad(st,_v(t,m,a0,side*k,lo),_v(t,m,a1,side*k,lo),_v(t,m,a1,side*k,top),_v(t,m,a0,side*k,top),sn,BLOCK_TINT.darkened(0.08))
		tris += _quad(st,_v(t,m,a0,-k,top),_v(t,m,a0,k,top),_v(t,m,a1,k,top),_v(t,m,a1,-k,top),Vector3.UP,BLOCK_TINT.darkened(0.04))
	var mesh: ArrayMesh = rock.commit()
	st.commit(mesh)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in mesh.get_surface_count(): mesh.surface_set_material(i,mat)
	var node := MeshInstance3D.new()
	node.name = t.name.replace("/","_")
	node.mesh = mesh
	add_child(node)
	var body := StaticBody3D.new()
	body.name = node.name+"_body"
	body.collision_layer = LAYER
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	stats.tris += tris+_rock_tris

## The carved rock of the bore (Tunnels.profile: superellipse rings from
## the -d wall's foot over the crown to the +d wall's foot, RING_SEGS
## segments, every CAVE_RING m in the caverns and every STEP m in the
## hall stretches and the portals), lumped outward into the rock
## (ROCK_LUMP; none in the portals, so the opening stays true) and a flat
## floor of FLOOR_SEGS strips between the walls' feet. Indexed, its normals
## smoothed, so the lumps shade.
func _build_rock(t: Tunnels.Site) -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ss := PackedFloat32Array([-Tunnels.PORTAL_OUT,0.0])
	for i in t.ss.size():
		var s: float = t.ss[i]
		if s <= 0.0 or s >= t.length: continue
		var prev: float = ss[ss.size()-1]
		var sub := ceili((s-prev)/CAVE_RING) if Tunnels.cave_ease(t,(s+prev)*0.5) > 0.0 else 1
		for k in range(1,sub): ss.append(lerpf(prev,s,float(k)/sub))
		ss.append(s)
	ss.append_array([t.length,t.length+Tunnels.PORTAL_OUT])
	# The lumps: ridged noise, so the rock reads broken rather than poured.
	var grain := FastNoiseLite.new()
	grain.seed = hash([t.seed,"grain"]) & 0x7fffffff
	grain.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	grain.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	grain.fractal_octaves = 3
	grain.frequency = 1.0/Tunnels.ROCK_GRAIN
	var pos := PackedVector3Array()
	var inward := PackedVector3Array()
	var per := RING_SEGS+1+FLOOR_SEGS+1
	var tris := 0
	for r in ss.size():
		var s: float = ss[r]
		var at: Array = Tunnels.at_s(t,s)
		var c: Vector2 = at[0]
		var tg: Vector2 = at[1]
		var n := Vector2(-tg.y,tg.x)
		var n3 := Vector3(n.x,0.0,n.y)
		var pr := Tunnels.profile(t,s)
		var e := Tunnels.cave_ease(t,s)
		var lump := 0.0 if s <= 0.0 or s >= t.length else ROCK_LUMP*(0.45+0.55*e)
		var hw := (pr.x+pr.y)*0.5
		var feet: Array = []
		for k in RING_SEGS+1:
			var th := PI*(1.0-float(k)/RING_SEGS)
			var q := Tunnels.profile_point(pr,th)
			var x := (q.x-(pr.y-pr.x)*0.5)/hw
			var y := q.y/pr.z
			# Out of the rock's surface (the superellipse's gradient).
			var g := Vector2(signf(x)*pow(absf(x),pr.w-1.0)/hw,pow(y,pr.w-1.0)/pr.z).normalized()
			var base := Vector3(c.x,t.floor_y,c.y)+n3*q.x+Vector3.UP*q.y
			var nz := clampf(grain.get_noise_3dv(base)*0.5+0.5,0.0,1.0)
			var out := n3*g.x+Vector3.UP*g.y
			var v := base+out*lump*nz
			if k == 0 or k == RING_SEGS: feet.append(v)
			pos.append(v)
			inward.append(-out)
			st.set_color(CAVE_TINT.lerp(HALL_ROCK_TINT,1.0-e).darkened(0.35*nz).lightened(0.12*(1.0-nz)*y))
			st.add_vertex(v)
		for k in FLOOR_SEGS+1:
			var v: Vector3 = (feet[0] as Vector3).lerp(feet[1],float(k)/FLOOR_SEGS)
			var nz := t.rock.get_noise_2d(v.x*3.0,v.z*3.0)*0.5+0.5
			pos.append(v)
			inward.append(Vector3.UP)
			st.set_color(FLOOR_TINT.lerp(FLOOR_TINT.lightened(0.3),nz))
			st.add_vertex(v)
		if r == 0: continue
		var b0 := (r-1)*per
		var b1 := r*per
		for k in RING_SEGS:
			tris += _tri(st,pos,inward,b0+k,b0+k+1,b1+k+1)+_tri(st,pos,inward,b0+k,b1+k+1,b1+k)
		var f := RING_SEGS+1
		for k in FLOOR_SEGS:
			tris += _tri(st,pos,inward,b0+f+k,b0+f+k+1,b1+f+k+1)+_tri(st,pos,inward,b0+f+k,b1+f+k+1,b1+f+k)
	st.generate_normals()
	_rock_tris = tris
	return st

## One triangle of the rock, wound to face `inward` (Godot's front faces are
## clockwise as seen; generate_normals follows the winding).
static func _tri(st: SurfaceTool, pos: PackedVector3Array, inward: PackedVector3Array, a: int, b: int, c: int) -> int:
	var nm := inward[a]+inward[b]+inward[c]
	if (pos[b]-pos[a]).cross(pos[c]-pos[a]).dot(nm) > 0.0:
		var k := b
		b = c
		c = k
	st.add_index(a)
	st.add_index(b)
	st.add_index(c)
	return 1

## The greybox torch lines (Tunnels.torch_spots): an iron bracket off the
## wall and an unlit glowing flame on it, bigger and whiter on a bend's
## outside wall and at the mouths. No lights yet (real torches come from
## scripts/flame.gd, pooled along the path).
func _build_torches(t: Tunnels.Site) -> void:
	var spots: Array = Tunnels.torch_spots(t)
	var bracket := BoxMesh.new()
	bracket.size = TORCH_BRACKET
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.09,0.08,0.07)
	iron.roughness = 0.8
	bracket.material = iron
	var flame := SphereMesh.new()
	flame.radius = TORCH_FLAME.x
	flame.height = TORCH_FLAME.y
	flame.radial_segments = 8
	flame.rings = 4
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.vertex_color_use_as_albedo = true
	flame.material = glow
	var mb := MultiMesh.new()
	mb.transform_format = MultiMesh.TRANSFORM_3D
	mb.mesh = bracket
	mb.instance_count = spots.size()
	var mf := MultiMesh.new()
	mf.transform_format = MultiMesh.TRANSFORM_3D
	mf.use_colors = true
	mf.mesh = flame
	mf.instance_count = spots.size()
	for i in spots.size():
		var sp: Dictionary = spots[i]
		var into: Vector2 = sp.into
		var pos: Vector3 = sp.pos
		var big: float = TORCH_BIG.get(sp.kind,1.0)
		# The bracket's long side runs out of the wall (local z).
		var b := Basis.looking_at(Vector3(into.x,0.0,into.y),Vector3.UP)
		mb.set_instance_transform(i,Transform3D(b.scaled(Vector3.ONE*big),pos+Vector3(into.x,0.0,into.y)*TORCH_BRACKET.z*0.5*big))
		mf.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*big),pos+Vector3(into.x,0.0,into.y)*TORCH_BRACKET.z*big+Vector3.UP*(TORCH_BRACKET.y*0.5+TORCH_FLAME.y*0.4)*big))
		mf.set_instance_color(i,(TORCH_GLOW.get(sp.kind,TORCH_GLOW.wall) as Color).srgb_to_linear())
	for pair: Array in [[mb,"_torch_brackets"],[mf,"_torch_flames"]]:
		var node := MultiMeshInstance3D.new()
		node.name = t.name.replace("/","_")+str(pair[1])
		node.multimesh = pair[0]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
	stats.torches += spots.size()

## Mouth `m`'s point `a` in, `d` across, at height `y`.
static func _v(t: Tunnels.Site, m: int, a: float, d: float, y: float) -> Vector3:
	var q := Tunnels.portal_point(t,m,a,d)
	return Vector3(q.x,y,q.y)

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, tint: Color) -> int:
	var nm := normal.normalized()
	# Wound to face its normal (Godot's front faces are clockwise as seen),
	# else the far side's flipped normal lights it.
	var order := [a,b,c,a,c,d]
	if (b-a).cross(c-a).dot(nm) > 0.0: order = [a,c,b,a,d,c]
	for v: Vector3 in order:
		st.set_normal(nm)
		st.set_color(tint)
		st.add_vertex(v)
	return 2
