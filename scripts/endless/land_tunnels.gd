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
const RuinKit = preload("res://scripts/ruin_kit.gd")
const TUNNEL_STONE = preload("res://shaders/tunnel_stone.gdshader")

## Physics layer of the greybox's bodies (the walker, the wheels).
const LAYER := 1
## The render layer of everything inside the bore (the rock, the hall
## stretches, the torches): the sun and the moon (every DirectionalLight3D)
## leave it out, so only the torches light the inside.
const UNDER_LAYER := 1 << 14
## The portal (knobs): a mass of carved rock on the mouth's footprint
## (Tunnels.portal_at), its top PORTAL_OVER m over the land or, over the
## opening, CAP_OVER m over the vault, flat CAP_FLAT m either side of the
## way and falling CAP_FALL m a metre past that; its skin a grid of
## SKIN_STEP m, its edges sunk SKIRT m into the land. Its front is cut
## sheer at the footprint's outer edge.
const PORTAL_OVER := 0.6
const CAP_OVER := 16.0
const CAP_FLAT := 24.0
const CAP_FALL := 2.4
## The cap's top broken by up to CAP_ROUGH m of the bore's rock noise,
## CAP_GRAIN times finer than the walls' swell.
const CAP_ROUGH := 3.5
const CAP_GRAIN := 4.0
const SKIN_STEP := 4.0
const SKIRT := 5.0
## The gate on the portal's front: jambs JAMB_W wide either side of the
## opening, a lintel LINTEL_H high over the vault running LINTEL_PAST past
## the jambs, a pediment PED_H high over it, all FRAME_OUT proud of the
## face; a fire bowl on each end of the lintel (BOWL: half width, height),
## its glow FIRE_R round and a light FIRE_RANGE m.
const JAMB_W := 4.0
const LINTEL_H := 4.5
const LINTEL_PAST := 2.0
const PED_H := 9.0
const FRAME_OUT := 2.5
const BOWL := Vector2(1.6,1.4)
const FIRE_R := 0.9
const FIRE_RANGE := 26.0
const FIRE_ENERGY := 4.0
const FACE_TINT := Color(0.5,0.43,0.36)
const SKIN_TINT := Color(0.74,0.64,0.52)
const FRAME_TINT := Color(0.94,0.9,0.83)
## The portals' texture: its darkest (ROCK_TEX_LOW for the bore's rock),
## so the cut stone reads even in the sun.
const PORTAL_TEX_LOW := 0.86
## Daylight in at each mouth: a spot SPILL_IN m inside the front, SPILL_Y
## over the floor, looking SPILL_AIM m in at the floor, lighting the
## inside's layer in the sun's colour at SPILL_ENERGY x its energy, its
## falloff SPILL_ATTEN (Godot's decay: low, so it carries in).
const SPILL_IN := 1.0
const SPILL_Y := 13.0
const SPILL_AIM := 45.0
const SPILL_RANGE := 110.0
const SPILL_ANGLE := 50.0
const SPILL_ENERGY := 2.0
const SPILL_ATTEN := 0.35
## The test tunnel's start: this high over the bore's floor, so the plane
## flies straight in at mouth A (unless --alt= is given).
const TEST_ALT := 9.0
## The shafts (Tunnels.shafts), knobs: the vault's roof is cut open within
## SHAFT_CUT m of the axis (past SHAFT_R: the jagged edge of whole
## triangles), and a lip rises from LIP_R m (a skirt from the vault's solid
## LIP_UP m up into the rock, then a flare to the shaft's radius FLARE_H m
## over the crown); the shaft's wall in rings every SHAFT_RING m, SHAFT_SEGS
## round, lumped outward by up to ROCK_LUMP m, its tint darkening from the
## sky down; a curb of dressed stone CURB_H m high and CURB_W m wide round
## the top (covering the land's hole, HOLE_PAD), sunk SKIRT m. Daylight
## down it: a spot from the top (SHAFT_SPREAD: the pool's radius on the
## floor over the shaft's), SHAFT_ENERGY x the sun, and a faint beam
## (BEAM_ALPHA).
const SHAFT_CUT := Tunnels.SHAFT_R+4.0
const LIP_R := SHAFT_CUT+1.0
const LIP_UP := Tunnels.ROCK_LUMP+0.4
const FLARE_H := 3.0
const SHAFT_RING := 4.0
const SHAFT_SEGS := 28
const CURB_H := 1.1
const CURB_W := 3.6
const SHAFT_SPREAD := 2.2
const SHAFT_ENERGY := 8.0
const BEAM_ALPHA := 0.035
const BEAM_TINT := Color(1.0,0.93,0.78)
## How far past the tube's walls `inside` counts the rock (m).
const WALL_NEAR := 12.0
## The camera's sight in a bore (`sight`): marched every SIGHT_STEP m
## where either end is within a tunnel's box and SIGHT_UP m over its floor.
const SIGHT_STEP := 0.75
const SIGHT_UP := 60.0

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
## The rock's texture: a ridged noise worn triplanar in world space, ROCK_TILE
## m a repeat, its relief ROCK_BUMP; ROCK_TEX_LOW the darkest it takes the
## vertex colour to.
const ROCK_TILE := 9.0
const ROCK_BUMP := 5.0
const ROCK_TEX_LOW := 0.62

## The dark inside (knobs): the hall stretches' stone and growth keep
## STONE_DIM of their sky fill (shaders/tunnel_stone.gdshader), so the
## torches carry them; the carved rock takes no fill at all.
const STONE_DIM := 0.08
## The stretches' stone lifted less than in the sun (LandHalls STONE_LIFT),
## so under the torches it sits with the rock.
const STONE_LIFT := Color(1.8,1.55,1.25)
const GROWTH_DIM := 0.08
## The torches' lights: the nearest TORCH_LIGHTS torches to the eye get a
## real light (no shadows), TORCH_RANGE m, TORCH_ENERGY, flickering by
## TORCH_FLICKER; past LIGHT_REACH m none do, and the farthest lit ones fade
## over LIGHT_FADE m so a light coming on doesn't pop.
const TORCH_LIGHTS := 16
const TORCH_RANGE := 30.0
const TORCH_ENERGY := 5.0
const TORCH_ATTEN := 0.8
const TORCH_FLICKER := 0.12
const TORCH_LIGHT := Color(1.0,0.62,0.32)
const LIGHT_REACH := 260.0
const LIGHT_FADE := 40.0
## The valley fog (EndlessClouds `fog_hush`) fades out over the first
## HUSH_IN m into the bore from either mouth: it would haze the dark inside.
const HUSH_IN := 60.0

var field: RefCounted
var stats := {"tunnels":0,"tris":0,"torches":0,"stretches":0,"lights":0}
## The hall stretches' streamer.
var halls: Node3D
## The look's clouds (their valley fog hushed in the bore), or null.
var clouds: Node
var _sites: Array = []
## The plane's wingtip: the tube's half width it may fly in.
var _grow := 0.0
## Whether `sight`'s last march was all in a bore's tube.
var sight_whole := false
var _rock_tris := 0
## Every torch's light spot (world) and its size, all sites.
var _lamps := PackedVector3Array()
var _lamp_big := PackedFloat32Array()
var _lights: Array[OmniLight3D] = []
var _time := 0.0
var _sky_cut := false
## The sun (the brightest DirectionalLight3D) and each mouth's daylight.
var _sun: DirectionalLight3D
var _spills: Array[SpotLight3D] = []
var _spill_gain := PackedFloat32Array()
var _beams: Array[MeshInstance3D] = []

func setup(land_field: RefCounted) -> void:
	field = land_field
	_grow = WorldScale.span*0.5
	_sites = field.tunnel_sites() if field.has_method("tunnel_sites") else []
	halls = LandHalls.new()
	halls.name = "Stretches"
	halls.squares = false
	halls.swap = _dark_materials()
	halls.swap_layers = UNDER_LAYER
	add_child(halls)
	halls.setup(int(field.seed))
	halls.density = 1.0
	for ti in _sites.size():
		var t: Tunnels.Site = _sites[ti]
		_build(t)
		_build_torches(t)
		for h: Dictionary in Tunnels.stretches(t):
			var frame: Transform3D = h.frame
			var half := float(h.piece.s1-h.piece.s0)*0.5
			var mid := frame*Vector3(half,0.0,0.0)
			var site := PackedFloat32Array([mid.x,mid.z,0,0,0,0,0,half+Tunnels.HALL_HALF])
			halls.add_fixed(Vector2i(ti,int(h.n)),{"name":"%s/stretch_%d" % [t.name,int(h.n)],"seed":h.seed,"bays":h.bays,
				"frame":frame,"coded":frame,"site":site,"piece":Tunnels.stretch_piece(h)})
			stats.stretches += 1
	stats.tunnels = _sites.size()
	stats.lights = 0
	for i in (TORCH_LIGHTS if not _lamps.is_empty() else 0):
		var l := OmniLight3D.new()
		l.name = "TorchLight%d" % i
		l.light_color = TORCH_LIGHT
		l.omni_range = TORCH_RANGE
		l.omni_attenuation = TORCH_ATTEN
		l.shadow_enabled = false
		l.light_specular = 0.3
		l.visible = false
		add_child(l)
		_lights.append(l)

## Leaves the inside's layer out of every DirectionalLight3D (the sun and
## the moon), once they stand.
func _cut_sky() -> void:
	var lights: Array = get_tree().root.find_children("*","DirectionalLight3D",true,false)
	for l: DirectionalLight3D in lights:
		l.light_cull_mask &= ~UNDER_LAYER
		if _sun == null or l.light_energy > _sun.light_energy: _sun = l
	_sky_cut = not lights.is_empty()

## The hall stretches' own materials for the kit's (LandHalls `swap`): the
## stone and the growth with their sky fill dimmed.
static func _dark_materials() -> Dictionary:
	var kit: Dictionary = RuinKit.materials()
	var stone := (kit.stone as ShaderMaterial).duplicate() as ShaderMaterial
	stone.shader = TUNNEL_STONE
	stone.set_shader_parameter("albedo",STONE_LIFT)
	stone.set_shader_parameter("rim",0.0)
	stone.set_shader_parameter("dim_fill",STONE_DIM)
	var growth := (kit.growth as ShaderMaterial).duplicate() as ShaderMaterial
	growth.set_shader_parameter("fill",1.25*GROWTH_DIM)
	growth.set_shader_parameter("rim",0.0)
	growth.set_shader_parameter("shelter_fill",4.5*GROWTH_DIM)
	return {kit.stone:stone,kit.growth:growth}

## Builds the hall stretches' far detail now, and the near detail round `at`.
func prime(at: Vector3) -> void:
	halls.prime(at)

func step(at: Vector3) -> void:
	halls.step(at)
	_light_torches(at)
	_spill()
	if clouds != null and "fog_hush" in clouds: clouds.fog_hush = under(at)

## How deep in a bore `p` is: 0 outside (or in a portal), 1 HUSH_IN m or
## more past either mouth, under the roof.
func under(p: Vector3) -> float:
	for t: Tunnels.Site in _sites:
		var b := Tunnels.bore_at(t,p.x,p.z)
		if is_nan(b.x): continue
		var sh := Tunnels.shaft_at(t,p.x,p.z)
		if p.y > (b.y if sh < 0 else float(t.shafts[sh].top)): continue
		var q := Tunnels.local(t,p.x,p.z)
		return smoothstep(0.0,HUSH_IN,minf(q.x,t.length-q.x))
	return 0.0

## Each mouth's daylight in the sun's colour and strength (none at night).
func _spill() -> void:
	if _spills.is_empty(): return
	if not _sky_cut: _cut_sky()
	var lit := _sun != null and is_instance_valid(_sun) and _sun.visible
	for b in _beams: b.visible = lit
	for i in _spills.size():
		var l := _spills[i]
		l.visible = lit
		if not lit: continue
		l.light_color = _sun.light_color
		l.light_energy = _spill_gain[i]*_sun.light_energy

## The pool of torch lights: the nearest TORCH_LIGHTS torches to `at`
## within LIGHT_REACH get one, the farthest of them fading out.
func _light_torches(at: Vector3) -> void:
	if _lights.is_empty(): return
	if not _sky_cut: _cut_sky()
	_time += get_process_delta_time()
	var near: Array = []
	var reach2 := LIGHT_REACH*LIGHT_REACH
	for i in _lamps.size():
		var d2 := at.distance_squared_to(_lamps[i])
		if d2 < reach2: near.append(Vector2(d2,i))
	near.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var n := mini(near.size(),_lights.size())
	# The farthest lit one fades out as the next one in comes nearer.
	var last := LIGHT_REACH
	if near.size() > n: last = sqrt((near[n] as Vector2).x)
	for k in _lights.size():
		var l := _lights[k]
		if k >= n:
			l.visible = false
			continue
		var i := int((near[k] as Vector2).y)
		var d := sqrt((near[k] as Vector2).x)
		var fade := clampf((last-d)/LIGHT_FADE,0.0,1.0)
		var flick := 1.0+TORCH_FLICKER*(sin(_time*11.0+i*1.7)*0.6+sin(_time*23.0+i*3.1)*0.4)
		l.position = _lamps[i]
		l.omni_range = TORCH_RANGE*_lamp_big[i]
		l.light_energy = TORCH_ENERGY*_lamp_big[i]*fade*flick
		l.visible = fade > 0.0
	stats.lights = n

## Where the test tunnel's start stands (world y), NAN with none.
func start_y() -> float:
	for t: Tunnels.Site in _sites:
		if t.name.ends_with("/test"): return t.floor_y+TEST_ALT
	return NAN

# --- The solid ------------------------------------------------------------------------

## The cover over (x, z): the land `h`, or the portal's top on its
## footprint.
func _cover(t: Tunnels.Site, x: float, z: float, h: float) -> float:
	var m := Tunnels.portal_at(t,x,z)
	if m < 0: return h
	var q := Tunnels.portal_local(t,m,x,z)
	return maxf(h+PORTAL_OVER,_cap(t,m,q.x,q.y))

## Mouth `m`'s portal cap at `a` in, `d` across: CAP_OVER over the vault,
## broken by CAP_ROUGH, falling past CAP_FLAT.
static func _cap(t: Tunnels.Site, m: int, a: float, d: float) -> float:
	var rough := CAP_ROUGH*(t.rock.get_noise_2d(d*CAP_GRAIN,a*CAP_GRAIN+5000.0*(m+1))*0.5+0.5)
	return t.floor_y+Tunnels.HALL_VAULT+CAP_OVER+rough-CAP_FALL*maxf(absf(d)-CAP_FLAT,0.0)

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
		# Up a shaft, under its top: open to the bore's floor.
		var sh := Tunnels.shaft_at(t,p.x,p.z,_grow)
		if sh >= 0 and p.y < float(t.shafts[sh].top): return t.floor_y
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
		var sh := Tunnels.shaft_at(t,p.x,p.z)
		if sh >= 0 and p.y < float(t.shafts[sh].top): return t.floor_y
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
		var sh := Tunnels.shaft_at(t,p.x,p.z)
		if sh >= 0 and p.y < float(t.shafts[sh].top): return p.y < t.floor_y
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

## The chase camera's sight inside a bore (studies/endless_flight.gd
## `_sight`, GlideCamera `sight`): the share of the way from `from` to `to`
## clear of the rock and the hall stretches, marched every SIGHT_STEP m (the
## field's own march is too coarse for a stretch's columns and lintels, or
## a bend's inside corner, so the eye went through them). 1 where neither
## end is near a bore. `sight_whole` says whether the tube answered every
## point (nothing else can be in the way there, so the caller's own march
## can be skipped).
func sight(from: Vector3, to: Vector3) -> float:
	sight_whole = false
	if not near(from) and not near(to): return 1.0
	var n := maxi(1,ceili(from.distance_to(to)/SIGHT_STEP))
	var whole := true
	for i in range(1,n+1):
		var p := from.lerp(to,float(i)/n)
		var got := tube(p)
		if got < 0:
			whole = false
			if inside(p) or p.y < land_y(p,field.height(p.x,p.z)): got = 1
		if got == 1:
			sight_whole = whole
			return float(i-1)/n
	sight_whole = whole
	return 1.0

## Whether `p` is in a tunnel's box, low enough to be in its bore.
func near(p: Vector3) -> bool:
	for t: Tunnels.Site in _sites:
		if t.box.has_point(Vector2(p.x,p.z)) and p.y < t.floor_y+SIGHT_UP: return true
	return false

## The quick answer in a bore's tube away from its portals (and up a
## shaft), where the land over it can't matter: 1 in the rock or a hall
## stretch, 0 open, -1 elsewhere (ask `inside` and `land_y`).
func tube(p: Vector3) -> int:
	for t: Tunnels.Site in _sites:
		if not t.box.has_point(Vector2(p.x,p.z)) or p.y > t.floor_y+SIGHT_UP: continue
		var sh := Tunnels.shaft_at(t,p.x,p.z)
		if sh >= 0 and p.y < float(t.shafts[sh].top): return 1 if p.y < t.floor_y else 0
		var b := Tunnels.bore_at(t,p.x,p.z)
		if is_nan(b.x) or Tunnels.portal_at(t,p.x,p.z) >= 0: return -1
		return 1 if p.y < b.x or p.y > b.y or halls.inside(p) else 0
	return -1

## One line for the numbers HUD.
func note() -> String:
	return "tunnels %d, greybox %dk tris, %d torches (%d lit), %d stretches: %s" % [stats.tunnels,stats.tris/1000,stats.torches,stats.lights,stats.stretches,halls.note()]

# --- The greybox ----------------------------------------------------------------------

func _build(t: Tunnels.Site) -> void:
	var rock := _build_rock(t)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tris := 0
	for m in 2: tris += _build_portal(st,t,m)
	var mesh: ArrayMesh = rock.commit()
	st.commit(mesh)
	# Seen: the rock on the inside's layer (torch lit), the portal blocks
	# in the day (sun, sky and haze); the collider is both.
	var mat := _rock_material(t)
	var node := MeshInstance3D.new()
	node.name = t.name.replace("/","_")
	node.mesh = _surface(mesh,0,mat)
	node.layers = UNDER_LAYER
	add_child(node)
	var blocks := MeshInstance3D.new()
	blocks.name = node.name+"_portals"
	blocks.mesh = _surface(mesh,1,_portal_material(t))
	add_child(blocks)
	for m in 2: _build_fires(t,m)
	tris += _build_shafts(t,mesh,node.name,mat)
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

## Mouth `m`'s portal into `st`: the skin over its footprint (the land's
## top PORTAL_OVER over it, or the cap over the opening: `_cover`), sunk
## SKIRT into the land at its sides and back; the sheer front with the
## opening (filleted to the bore's rounded corners); the gate (jambs, a
## lintel, a pediment) and a fire bowl on each end of the lintel. Flat
## shaded, so it reads as cut stone. Returns its triangles.
func _build_portal(st: SurfaceTool, t: Tunnels.Site, m: int) -> int:
	var tris := 0
	var a0 := -Tunnels.PORTAL_OUT
	var k := Tunnels.PORTAL_HALF
	var w := Tunnels.HALL_HALF
	var f := t.floor_y
	var vault := f+Tunnels.HALL_VAULT
	var as_: Array[float] = []
	var a := a0
	while a < Tunnels.PORTAL_IN-0.01:
		as_.append(a)
		a += SKIN_STEP
	as_.append(Tunnels.PORTAL_IN)
	var ds: Array[float] = [-w,w]
	var d := -k
	while d < k-0.01:
		if absf(absf(d)-w) > 0.5: ds.append(d)
		d += SKIN_STEP
	ds.append(k)
	ds.sort()
	# The skin's heights.
	var ys: Array = []
	for i in as_.size():
		var row := PackedFloat32Array()
		for j in ds.size():
			var q := Tunnels.portal_point(t,m,as_[i],ds[j])
			row.append(_cover(t,q.x,q.y,field.height(q.x,q.y)))
		ys.append(row)
	var inward := _v(t,m,1.0,0.0,0.0)-_v(t,m,0.0,0.0,0.0)
	var across := _v(t,m,0.0,1.0,0.0)-_v(t,m,0.0,0.0,0.0)
	for i in as_.size()-1:
		for j in ds.size()-1:
			var p00 := _v(t,m,as_[i],ds[j],ys[i][j])
			var p10 := _v(t,m,as_[i+1],ds[j],ys[i+1][j])
			var p11 := _v(t,m,as_[i+1],ds[j+1],ys[i+1][j+1])
			var p01 := _v(t,m,as_[i],ds[j+1],ys[i][j+1])
			var nm := (p11-p00).cross(p01-p10)
			if nm.y < 0.0: nm = -nm
			nm = nm.normalized()
			tris += _quad(st,p00,p10,p11,p01,nm,FACE_TINT.lerp(SKIN_TINT,smoothstep(0.4,0.9,nm.y)))
	# Skirts into the land: the sides and the back.
	for side in 2:
		var j := 0 if side == 0 else ds.size()-1
		var dd := ds[j]
		for i in as_.size()-1:
			var y0: float = ys[i][j]
			var y1: float = ys[i+1][j]
			tris += _quad(st,_v(t,m,as_[i],dd,y0),_v(t,m,as_[i+1],dd,y1),_v(t,m,as_[i+1],dd,_land(t,m,as_[i+1],dd)-SKIRT),_v(t,m,as_[i],dd,_land(t,m,as_[i],dd)-SKIRT),across*signf(dd),FACE_TINT)
	var back := as_.size()-1
	var ab := as_[back]
	for j in ds.size()-1:
		tris += _quad(st,_v(t,m,ab,ds[j],ys[back][j]),_v(t,m,ab,ds[j+1],ys[back][j+1]),_v(t,m,ab,ds[j+1],_land(t,m,ab,ds[j+1])-SKIRT),_v(t,m,ab,ds[j],_land(t,m,ab,ds[j])-SKIRT),inward,FACE_TINT)
	# The sheer front, the opening cut out of it.
	var lo := f-Tunnels.SINK-SKIRT
	for j in ds.size()-1:
		var bot := vault if absf((ds[j]+ds[j+1])*0.5) < w else lo
		var tint := FACE_TINT.darkened(0.12*(t.rock.get_noise_2d(ds[j]*7.0,float(m)*300.0)*0.5+0.5))
		tris += _quad(st,_v(t,m,a0,ds[j],ys[0][j]),_v(t,m,a0,ds[j+1],ys[0][j+1]),_v(t,m,a0,ds[j+1],bot),_v(t,m,a0,ds[j],bot),-inward,tint)
	# The fillets between the square opening and the bore's rounded ring.
	var pr := Tunnels.profile(t,-1.0)
	for r in RING_SEGS:
		var q0 := Tunnels.profile_point(pr,PI*(1.0-float(r)/RING_SEGS))
		var q1 := Tunnels.profile_point(pr,PI*(1.0-float(r+1)/RING_SEGS))
		var c := _v(t,m,a0,signf(q0.x+q1.x)*w,vault)
		var v0 := _v(t,m,a0,q0.x,f+q0.y)
		var v1 := _v(t,m,a0,q1.x,f+q1.y)
		if (v1-v0).cross(c-v0).length() < 0.01: continue
		tris += _tri_flat(st,c,v0,v1,-inward,FACE_TINT)
	# The gate: jambs, a lintel, a pediment.
	var out := a0-FRAME_OUT
	for sg: float in [-1.0,1.0]:
		tris += _box(st,t,m,out,a0+0.3,sg*w,sg*(w+JAMB_W),f-Tunnels.SINK,vault,FRAME_TINT.darkened(0.05),false)
	var lw := w+JAMB_W+LINTEL_PAST
	tris += _box(st,t,m,out-0.6,a0+0.3,-lw,lw,vault,vault+LINTEL_H,FRAME_TINT,true)
	var base := vault+LINTEL_H
	var pw := w+JAMB_W
	var pa := out+0.4
	var apex_f := _v(t,m,pa,0.0,base+PED_H)
	var apex_b := _v(t,m,a0+0.3,0.0,base+PED_H)
	tris += _tri_flat(st,_v(t,m,pa,-pw,base),_v(t,m,pa,pw,base),apex_f,-inward,FRAME_TINT.lightened(0.04))
	for sg: float in [-1.0,1.0]:
		var e_f := _v(t,m,pa,sg*pw,base)
		var e_b := _v(t,m,a0+0.3,sg*pw,base)
		var slope := (apex_f-e_f).cross(inward)
		if slope.y < 0.0: slope = -slope
		tris += _quad(st,e_f,e_b,apex_b,apex_f,slope,FRAME_TINT.darkened(0.04))
	# A fire bowl on each end of the lintel.
	for sg: float in [-1.0,1.0]:
		var bd := sg*(lw-BOWL.x)
		tris += _box(st,t,m,out-0.6,out-0.6+2.0*BOWL.x,bd-BOWL.x,bd+BOWL.x,base,base+BOWL.y,Color(0.16,0.14,0.12),false)
	return tris

## Mouth `m`'s fires: on the lintel's bowls, a glow and a light each; and
## its daylight in (`_spill`), lighting the inside's layer only.
func _build_fires(t: Tunnels.Site, m: int) -> void:
	var f := t.floor_y
	var a0 := -Tunnels.PORTAL_OUT
	var top := f+Tunnels.HALL_VAULT+LINTEL_H+BOWL.y
	var glow := SphereMesh.new()
	glow.radius = FIRE_R
	glow.height = FIRE_R*2.6
	glow.radial_segments = 10
	glow.rings = 5
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = TORCH_GLOW.mouth
	glow.material = mat
	var lw := Tunnels.HALL_HALF+JAMB_W+LINTEL_PAST
	var out := _v(t,m,-1.0,0.0,0.0)-_v(t,m,0.0,0.0,0.0)
	for sg: float in [-1.0,1.0]:
		var at := _v(t,m,a0-FRAME_OUT-0.6+BOWL.x,sg*(lw-BOWL.x),top)
		var fire := MeshInstance3D.new()
		fire.name = "%s_fire%d%s" % [t.name.replace("/","_"),m,"l" if sg < 0.0 else "r"]
		fire.mesh = glow
		fire.position = at+Vector3.UP*FIRE_R*1.2
		fire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(fire)
		var l := OmniLight3D.new()
		l.name = fire.name+"_light"
		l.light_color = TORCH_LIGHT
		l.omni_range = FIRE_RANGE
		l.omni_attenuation = TORCH_ATTEN
		l.light_energy = FIRE_ENERGY
		l.shadow_enabled = false
		l.position = at+Vector3.UP*(FIRE_R*2.4)+out*1.5
		add_child(l)
	var spot := SpotLight3D.new()
	spot.name = "%s_spill%d" % [t.name.replace("/","_"),m]
	var from := _v(t,m,a0+SPILL_IN,0.0,f+SPILL_Y)
	spot.transform = Transform3D(Basis.looking_at(_v(t,m,SPILL_AIM,0.0,f)-from,Vector3.UP),from)
	spot.spot_range = SPILL_RANGE
	spot.spot_angle = SPILL_ANGLE
	spot.spot_attenuation = SPILL_ATTEN
	spot.light_cull_mask = UNDER_LAYER
	spot.shadow_enabled = false
	spot.light_specular = 0.2
	add_child(spot)
	_spills.append(spot)
	_spill_gain.append(SPILL_ENERGY)

## The land's height at mouth `m`'s (a, d).
func _land(t: Tunnels.Site, m: int, a: float, d: float) -> float:
	var q := Tunnels.portal_point(t,m,a,d)
	return field.height(q.x,q.y)

## A box in mouth `m`'s frame (a along the way in, d across, y world),
## without its back (into the portal's face) and, unless `bottom`, its
## underside.
static func _box(st: SurfaceTool, t: Tunnels.Site, m: int, a0: float, a1: float, d0: float, d1: float, y0: float, y1: float, tint: Color, bottom: bool) -> int:
	var inward := _v(t,m,1.0,0.0,0.0)-_v(t,m,0.0,0.0,0.0)
	var across := _v(t,m,0.0,1.0,0.0)-_v(t,m,0.0,0.0,0.0)
	var dl := minf(d0,d1)
	var dh := maxf(d0,d1)
	var n := 0
	n += _quad(st,_v(t,m,a0,dl,y0),_v(t,m,a0,dh,y0),_v(t,m,a0,dh,y1),_v(t,m,a0,dl,y1),-inward,tint)
	n += _quad(st,_v(t,m,a0,dl,y1),_v(t,m,a0,dh,y1),_v(t,m,a1,dh,y1),_v(t,m,a1,dl,y1),Vector3.UP,tint.lightened(0.05))
	n += _quad(st,_v(t,m,a0,dl,y0),_v(t,m,a1,dl,y0),_v(t,m,a1,dl,y1),_v(t,m,a0,dl,y1),-across,tint.darkened(0.08))
	n += _quad(st,_v(t,m,a0,dh,y0),_v(t,m,a1,dh,y0),_v(t,m,a1,dh,y1),_v(t,m,a0,dh,y1),across,tint.darkened(0.08))
	if bottom: n += _quad(st,_v(t,m,a0,dl,y0),_v(t,m,a0,dh,y0),_v(t,m,a1,dh,y0),_v(t,m,a1,dl,y0),Vector3.DOWN,tint.darkened(0.15))
	return n

## One flat triangle facing `normal`.
static func _tri_flat(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, tint: Color) -> int:
	var nm := normal.normalized()
	var order := [a,b,c]
	if (b-a).cross(c-a).dot(nm) > 0.0: order = [a,c,b]
	for v: Vector3 in order:
		st.set_normal(nm)
		st.set_color(tint)
		st.add_vertex(v)
	return 1

## The portals' material: the rock's texture in the day (sun, sky, haze).
static func _portal_material(t: Tunnels.Site) -> StandardMaterial3D:
	var mat := _rock_material(t,PORTAL_TEX_LOW)
	mat.disable_ambient_light = false
	mat.disable_fog = false
	mat.roughness = 0.95
	return mat

## Surface `i` of `mesh` as a mesh of its own, wearing `mat`.
static func _surface(mesh: ArrayMesh, i: int, mat: Material) -> ArrayMesh:
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,mesh.surface_get_arrays(i))
	out.surface_set_material(0,mat)
	return out

## The rock's material: its vertex colours under a noise worn
## triplanar in world space (grain and relief), lit by the torches alone.
static func _rock_material(t: Tunnels.Site, low := ROCK_TEX_LOW) -> StandardMaterial3D:
	var noise := FastNoiseLite.new()
	noise.seed = hash([t.seed,"rock_tex"]) & 0x7fffffff
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.frequency = 0.006
	var fine := FastNoiseLite.new()
	fine.seed = noise.seed+1
	fine.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	fine.fractal_type = FastNoiseLite.FRACTAL_FBM
	fine.fractal_octaves = 6
	fine.frequency = 0.012
	var grad := Gradient.new()
	grad.set_color(0,Color(low,low*0.97,low*0.93))
	grad.set_color(1,Color(1.0,0.98,0.95))
	var albedo := NoiseTexture2D.new()
	albedo.width = 512
	albedo.height = 512
	albedo.seamless = true
	albedo.noise = noise
	albedo.color_ramp = grad
	var bump := NoiseTexture2D.new()
	bump.width = 512
	bump.height = 512
	bump.seamless = true
	bump.noise = fine
	bump.as_normal_map = true
	bump.bump_strength = ROCK_BUMP
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.albedo_texture = albedo
	mat.normal_enabled = true
	mat.normal_texture = bump
	mat.normal_scale = 1.0
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_triplanar_sharpness = 4.0
	mat.uv1_scale = Vector3.ONE/ROCK_TILE
	mat.roughness = 0.92
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# No sky fill and no haze inside: the torches alone.
	mat.disable_ambient_light = true
	mat.disable_fog = true
	return mat

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
			# None round a shaft's lip, so its skirt meets the rock's face.
			var calm := 1.0
			for sh: Dictionary in t.shafts: calm = minf(calm,smoothstep(LIP_R+0.5,LIP_R+4.0,Vector2(base.x,base.z).distance_to(sh.at)))
			var v := base+out*lump*nz*calm
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
		var near_shaft := false
		for sh: Dictionary in t.shafts: near_shaft = near_shaft or absf(s-float(sh.s)) < SHAFT_CUT+CAVE_RING*2.0
		for k in RING_SEGS:
			for tri: Array in [[b0+k,b0+k+1,b1+k+1],[b0+k,b1+k+1,b1+k]]:
				if near_shaft and _opened(t,pos,tri): continue
				tris += _tri(st,pos,inward,tri[0],tri[1],tri[2])
		var f := RING_SEGS+1
		for k in FLOOR_SEGS:
			tris += _tri(st,pos,inward,b0+f+k,b0+f+k+1,b1+f+k+1)+_tri(st,pos,inward,b0+f+k,b1+f+k+1,b1+f+k)
	st.generate_normals()
	_rock_tris = tris
	return st

## Tunnel `t`'s shafts (Tunnels.shafts): the lip in the vault (a skirt and
## a flare, the rock's material on the inside's layer), the wall up to the
## pit's floor and the curb round its top (in the day), each added to
## `mesh` too (the collider's); a spot of daylight down each and a faint
## beam. Returns the triangles.
func _build_shafts(t: Tunnels.Site, mesh: ArrayMesh, base_name: String, rock_mat: Material) -> int:
	if t.shafts.is_empty(): return 0
	var tris := 0
	var dark := SurfaceTool.new()
	dark.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wall := SurfaceTool.new()
	wall.begin(Mesh.PRIMITIVE_TRIANGLES)
	var curb := SurfaceTool.new()
	curb.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dpos := PackedVector3Array()
	var dnrm := PackedVector3Array()
	var wpos := PackedVector3Array()
	var wnrm := PackedVector3Array()
	var r := Tunnels.SHAFT_R
	var lump := Tunnels.ROCK_LUMP
	var n := SHAFT_SEGS+1
	for si in t.shafts.size():
		var sh: Dictionary = t.shafts[si]
		var at: Vector2 = sh.at
		var crown: float = sh.crown
		var top_y: float = sh.top
		# The lip: per angle, the vault's solid at LIP_R, LIP_UP over it,
		# then the shaft's radius FLARE_H over the crown.
		var d0 := dpos.size()
		for k in n:
			var th := TAU*float(k)/SHAFT_SEGS
			var rad := Vector3(cos(th),0.0,sin(th))
			var lip := at+Vector2(rad.x,rad.z)*LIP_R
			var q := Tunnels.local(t,lip.x,lip.y)
			var hy := Tunnels.roof_over(Tunnels.profile(t,q.x),q.y)
			var ys := t.floor_y+(hy if not is_nan(hy) else crown-t.floor_y-4.0)
			var p0 := Vector3(lip.x,ys-0.1,lip.y)
			var p1 := Vector3(lip.x,ys+LIP_UP,lip.y)
			var p2 := Vector3(at.x,crown+FLARE_H,at.y)+rad*r
			var dr := r-LIP_R
			var dy := p2.y-p1.y
			var flare := (-rad*dy+Vector3.UP*dr).normalized()
			for v: Array in [[p0,-rad],[p1,-rad],[p1,flare],[p2,flare]]:
				dark.set_normal(v[1])
				dark.set_color(CAVE_TINT.darkened(0.3))
				dark.add_vertex(v[0])
				dpos.append(v[0])
				dnrm.append(v[1])
		for k in SHAFT_SEGS:
			var a := d0+k*4
			var b := d0+(k+1)*4
			for band in [[0,1],[2,3]]:
				tris += _tri(dark,dpos,dnrm,a+band[0],b+band[0],b+band[1])+_tri(dark,dpos,dnrm,a+band[0],b+band[1],a+band[1])
		# The wall: rings from the flare's top to the curb's, lumped out
		# (none at the top, where the curb meets it), darkening downward.
		var y0 := crown+FLARE_H
		var y1 := top_y+CURB_H
		var rings := maxi(2,ceili((y1-y0)/SHAFT_RING))
		var w0 := wpos.size()
		for j in rings+1:
			var u := float(j)/rings
			var y := lerpf(y0,y1,u)
			var lumped := lump*(1.0-smoothstep(y1-6.0,y1-1.0,y))
			for k in n:
				var th := TAU*float(k % SHAFT_SEGS)/SHAFT_SEGS
				var rad := Vector3(cos(th),0.0,sin(th))
				var base := Vector3(at.x,y,at.y)+rad*r
				var nz := clampf(t.rock.get_noise_3d(base.x*3.0,base.y*3.0,base.z*3.0)*0.5+0.5,0.0,1.0)
				var v := base+rad*lumped*nz
				wall.set_normal(-rad)
				wall.set_color(CAVE_TINT.darkened(0.82).lerp(FACE_TINT,pow(u,1.6)).darkened(0.25*nz))
				wall.add_vertex(v)
				wpos.append(v)
				wnrm.append(-rad)
		for j in rings:
			for k in SHAFT_SEGS:
				var a := w0+j*n+k
				var b := a+n
				tris += _tri(wall,wpos,wnrm,a,a+1,b+1)+_tri(wall,wpos,wnrm,a,b+1,b)
		# The curb: a flat top and its outer face sunk into the pit's floor.
		for k in SHAFT_SEGS:
			var ta := TAU*float(k)/SHAFT_SEGS
			var tb := TAU*float(k+1)/SHAFT_SEGS
			var ra := Vector3(cos(ta),0.0,sin(ta))
			var rb := Vector3(cos(tb),0.0,sin(tb))
			var c := Vector3(at.x,y1,at.y)
			var tint := FRAME_TINT.darkened(0.1*(t.rock.get_noise_2d(float(k)*9.0,float(si)*200.0)*0.5+0.5))
			tris += _quad(curb,c+ra*r,c+rb*r,c+rb*(r+CURB_W),c+ra*(r+CURB_W),Vector3.UP,tint)
			var down := Vector3.DOWN*(CURB_H+SKIRT)
			tris += _quad(curb,c+ra*(r+CURB_W),c+rb*(r+CURB_W),c+rb*(r+CURB_W)+down,c+ra*(r+CURB_W)+down,(ra+rb).normalized(),tint.darkened(0.12))
		_shaft_light(t,si,base_name)
	var dmesh := dark.commit()
	var wmesh := wall.commit()
	curb.commit(wmesh)
	for m: ArrayMesh in [dmesh,wmesh]:
		for i in m.get_surface_count(): mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,m.surface_get_arrays(i))
	var lipn := MeshInstance3D.new()
	lipn.name = base_name+"_shaft_lips"
	lipn.mesh = _surface(dmesh,0,rock_mat)
	lipn.layers = UNDER_LAYER
	add_child(lipn)
	var day := _portal_material(t)
	var walls := MeshInstance3D.new()
	walls.name = base_name+"_shafts"
	var wm := _surface(wmesh,0,day)
	wm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,wmesh.surface_get_arrays(1))
	wm.surface_set_material(1,day)
	walls.mesh = wm
	add_child(walls)
	return tris

## Shaft `si`'s daylight: a spot from its top down onto the bore's floor
## (the inside's layer only, the sun's colour, SHAFT_ENERGY x it) and a
## faint beam of light from the vault down into the cavern.
func _shaft_light(t: Tunnels.Site, si: int, base_name: String) -> void:
	var sh: Dictionary = t.shafts[si]
	var at: Vector2 = sh.at
	var top_y: float = sh.top
	var drop := top_y-1.0-t.floor_y
	var spot := SpotLight3D.new()
	spot.name = "%s_shaft%d_light" % [base_name,si]
	spot.transform = Transform3D(Basis.looking_at(Vector3.DOWN,Vector3.FORWARD),Vector3(at.x,top_y-1.0,at.y))
	spot.spot_range = drop+12.0
	spot.spot_angle = rad_to_deg(atan(Tunnels.SHAFT_R*SHAFT_SPREAD/drop))
	spot.spot_attenuation = SPILL_ATTEN
	spot.light_cull_mask = UNDER_LAYER
	spot.shadow_enabled = false
	spot.light_specular = 0.2
	add_child(spot)
	_spills.append(spot)
	_spill_gain.append(SHAFT_ENERGY)
	var cyl := CylinderMesh.new()
	cyl.top_radius = Tunnels.SHAFT_R*0.92
	cyl.bottom_radius = Tunnels.SHAFT_R*SHAFT_SPREAD*0.7
	# From just over the vault's crown (under the rock's cut edge) down.
	var beam_top := float(sh.crown)+FLARE_H*0.5
	cyl.height = beam_top-t.floor_y
	cyl.radial_segments = 24
	cyl.rings = 1
	cyl.cap_top = false
	cyl.cap_bottom = false
	var mat := ShaderMaterial.new()
	mat.shader = _beam_shader()
	mat.set_shader_parameter("tint",BEAM_TINT)
	mat.set_shader_parameter("alpha",BEAM_ALPHA)
	cyl.material = mat
	var beam := MeshInstance3D.new()
	beam.name = "%s_shaft%d_beam" % [base_name,si]
	beam.mesh = cyl
	beam.position = Vector3(at.x,(beam_top+t.floor_y)*0.5,at.y)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.layers = UNDER_LAYER
	add_child(beam)
	_beams.append(beam)

static var _beam: Shader

## The beam's shader: added light, faint at its edges (seen side on) and
## fading toward the floor.
static func _beam_shader() -> Shader:
	if _beam != null: return _beam
	_beam = Shader.new()
	_beam.code = """shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;
uniform vec4 tint : source_color = vec4(1.0);
uniform float alpha = 0.07;
void fragment() {
	float face = pow(clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 3.0);
	float down = mix(1.0, 0.4, UV.y)*smoothstep(1.0, 0.9, UV.y)*smoothstep(0.0, 0.2, UV.y);
	ALBEDO = tint.rgb;
	ALPHA = alpha*face*down;
}
"""
	return _beam

## Whether the rock's triangle `tri` (indices into `pos`) lies wholly in a
## shaft's opening: every corner within SHAFT_CUT of the axis, in the roof.
static func _opened(t: Tunnels.Site, pos: PackedVector3Array, tri: Array) -> bool:
	for sh: Dictionary in t.shafts:
		var at: Vector2 = sh.at
		var all := true
		for i: int in tri:
			var v := pos[i]
			if v.y < t.floor_y+2.0 or Vector2(v.x,v.z).distance_to(at) > SHAFT_CUT:
				all = false
				break
		if all: return true
	return false

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
		# The light: at the flame, a little out of it into the bore.
		_lamps.append(pos+Vector3(into.x,0.0,into.y)*(TORCH_BRACKET.z+0.4)*big+Vector3.UP*(TORCH_BRACKET.y*0.5+TORCH_FLAME.y*0.6)*big)
		_lamp_big.append(sqrt(big))
	for pair: Array in [[mb,"_torch_brackets"],[mf,"_torch_flames"]]:
		var node := MultiMeshInstance3D.new()
		node.name = t.name.replace("/","_")+str(pair[1])
		node.multimesh = pair[0]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.layers = UNDER_LAYER
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
