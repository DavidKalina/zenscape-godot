extends "res://scripts/endless/region_doors.gd"
## The ruin door between the regions (the default door of the doors world;
## --door=cloud keeps the cloud walls of region_doors.gd): a ruin stands in
## each land, and flying into one, a ruined hall runs on far longer than its
## outside holds, and you come out of the other ruin in the other land.
##
##   the ruin     `doors/amber-hall` in wilderness, `doors/morning-hall` in
##                amberlands: two belfries and a kit hall (BAYS_OUT bays, on a
##                plinth) with a gabled open front. Each stands in its frame
##                (origin the mouth's floor, z inward), which the layout file
##                can move. Its solids are analytic (`ground`).
##   the hall     one Node3D (`_hall`), a kit hall's bays in MultiMeshes along
##                a line of two arcs between straights, dark stone lit by
##                torches only (LandTunnels' layer and materials: no sun, no
##                sky fill, no fog), drawn only while the plane is in it. It
##                has no place in the land: nothing outside holds it, and the
##                world is left out of the camera (`cull_mask`) while the eye
##                is past WORLD_OFF m from a mouth. It runs LENGTH m, from the
##                wilderness ruin's mouth to the amberlands ruin's.
##   the swap     at the hall's middle both mouths are behind the bends. The
##                plane, the eye and the whole hall move by one translation,
##                the same frame, so nothing in view changes: no fade, no
##                hold. The far land was prewarmed since the plane came near
##                the mouth; what dresses it streams in behind the hall's
##                last stretch.
##   the way out  where the hall meets the ruin stands a card of daylight in
##                the land's own haze, the size of the hall (the tell, growing);
##                the world comes back behind it, and it fades to the real ruin
##                and the land past it (WORLD_OFF to CLEAR_AT m from it).
##   both ways    the plane goes either way along the hall; turned back past
##                the swap, it swaps back (SWAP_SLACK of hysteresis).
##   the logbook  each way's first pass is a find (`door/amber-hall`,
##                `door/morning-hall`).

const Hall = preload("res://scripts/ruin_kit_hall.gd")
const RuinKit_ = preload("res://scripts/ruin_kit.gd")
const LandTunnels_ = preload("res://scripts/endless/land_tunnels.gd")
const LandHalls_ = preload("res://scripts/endless/land_halls.gd")
const Arches_ = preload("res://scripts/endless/land_arches.gd")
const SkyGlide_ = preload("res://scripts/sky_glide.gd")
const WorldScale = preload("res://scripts/world_scale.gd")

## The inside's render layer (LandTunnels): no sun, no moon.
const UNDER := LandTunnels_.UNDER_LAYER
## What the camera keeps when the world is left out: the ruin's own bits.
const KEPT := 1 << 15
## The wilderness ruin's mouth and its inward way on seed 1 (XZ), and the
## amberlands ruin's, on its side (home offset added).
const WILD_AT := Vector2(-1353.0,-1187.0)
const AMBER_AT := Vector2(-117.0,-892.0)
## The nave across (m, toy era; WorldScale `opening`): the kit bay scaled so
## its outer rows stand this wide. The whole hall is that bay's size times
## `_big`.
const TOY_NAVE := 18.8
## The hall's length (m): 16 s at Boost (57 m/s), 24 s at cruise.
const LENGTH := 920.0
## The bays of the ruin you can see from outside, and the arcs' radius (m).
const BAYS_OUT := 5
const RADIUS := 430.0
## The clear height under the cross beams, as a share of the kit's (m).
const ROOF := Hall.COLUMN_H
## The solids over the floor (m, unscaled): the ruin's roof and a belfry's core.
const SHELL_TOP := 17.0
const TOWER_TOP := 96.0
## The belfries: out from the middle (m), back from the mouth, half width of
## their core's solid.
const TOWER_X := 35.0
const TOWER_Z := 10.0
const TOWER_SOLID := 11.0
## The footprint's half width past the side walls (m).
const FOOT_OVER := 2.0
## A swap this far past the middle (m) either way.
const SWAP_SLACK := 4.0
## How far from a mouth (m, the eye's) the world goes out, and where its
## daylight card is clear.
const WORLD_OFF := 130.0
const CLEAR_AT := 34.0
## The torches: every so many bays, how many lights, how many with shadows.
const TORCH_EVERY := 2
const TORCH_Y := 6.0
const LIGHTS := 12
const LIGHT_SHADOWS := 2
const LIGHT_RANGE := 40.0
const LIGHT_ENERGY := 16.0
const SECTION := 8
## The plinth's depth under the floor (m).
const PLINTH := 44.0
const GUARD_MARGIN := 6.0
const GUARD_PUSH := 14.0
const GUARD_LIFT := 6.0
const GUARD_LOOK := 0.5
const GUARD_ROOF := 4.0
const GUARD_FLOOR := 2.5
const PREWARM_HALL := 1800.0

## The kit bay's scale, its length and the clear half width at the stone.
var _big := 1.0
var _bay := 0.0
var _room := 0.0
var _roof := 0.0
var _out := 0.0
var _foot := 0.0
## The frames (Transform3D) of the mouths: z inward.
var _frames: Array[Transform3D] = []
## The hall's line in wilderness mouth's frame: segments.
var _segs: Array[Dictionary] = []
var _end_yaw := 0.0
## The hall's move from the wilderness side to the amberlands side.
var _by := Vector3.ZERO
var _hall: Node3D
var _plugs: Array[Node3D] = []
var _cards: Array[MeshInstance3D] = []
var _spills: Array[OmniLight3D] = []
var _lights: Array[OmniLight3D] = []
var _lamps: Array[Vector3] = []
var _time := 0.0
## The plane is in the hall, and on which side the hall stands.
var inside_hall := false
var _side := 0
## The eye's state.
var _world_on := true
var _mask_all := 0
var _figure_layers := {}
var _sky_cut := false
var _sun: DirectionalLight3D
## Frames watched round a swap, the worst (ms), for the run's print.
var _swap_watch := 0
var _swap_worst := 0.0
var _last_usec := 0
var swaps := 0
var _day := Color(1.0,0.95,0.86)

## Whether the ruin door runs (the cloud walls with --door=cloud).
static func wanted_hall() -> bool:
	return not "--door=cloud" in LaunchArgs.user_args()

func setup(host: Node3D, start: Vector2, heading: float, seed: int) -> void:
	name = "Doors"
	_host = host
	_world = host.world
	_field = host.field
	_rng.seed = seed*977+31
	_hint_wait = _rng.randf_range(HINT_FIRST.x,HINT_FIRST.y)
	_big = WorldScale.opening(TOY_NAVE)/(2.0*Hall.ROW_Z)
	_bay = Hall.BAY*_big
	_room = (Hall.ROW_Z-Hall.ABACUS)*_big
	_roof = ROOF*_big
	_out = _bay*BAYS_OUT
	_foot = (Hall.WALL_Z+FOOT_OVER)*_big
	var off: Vector2 = _world.offset
	var wild_at := WILD_AT
	var amber_at := AMBER_AT+off
	# Faces the start; the far one looks home over its land.
	var wild_in := (wild_at-start).normalized()
	var amber_in := (amber_at-(off+start)).normalized()
	var coded: Array[Transform3D] = [_frame_on(wild_at,wild_in),_frame_on(amber_at,amber_in)]
	walls = [
		{"name":"doors/amber-hall","find":"door/amber-hall","coded":coded[0],"white":Color.WHITE},
		{"name":"doors/morning-hall","find":"door/morning-hall","coded":coded[1],"white":Color.WHITE},
	]
	for i in 2:
		var w := walls[i]
		w.xform = LayoutOverrides.xform(String(w.name),coded[i])
		_frames.append(w.xform)
	_line()
	var far_mouth: Vector3 = _at_s(_len())
	_by = _frames[1].origin-_frames[0]*far_mouth
	var parts := _bays()
	for i in 2:
		walls[i].node = _build_ruin(i,parts)
		LayoutOverrides.track(String(walls[i].name),walls[i].node,"door",coded[i])
	_build_hall(parts)
	_make_lands()
	print("doors: %s at %s (%.0f m from the start), %s at %s, the hall %.0f m, %d bays x %.2f" % [walls[0].name,str(_xz(0).round()),_xz(0).distance_to(start),walls[1].name,str(_xz(1).round()),_len(),roundi(_len()/_bay),_big])

## The mouth at `at` looking out against `inward`, its floor just over the
## highest ground of its footprint.
func _frame_on(at: Vector2, inward: Vector2) -> Transform3D:
	var across := Vector2(-inward.y,inward.x)
	var hi := Field.SEA_Y+1.0
	for a: float in [0.0,20.0,40.0,60.0,80.0]:
		for b: float in [-24.0,0.0,24.0]:
			var q := at+inward*a+across*b
			hi = maxf(hi,float(_field.height(q.x,q.y)))
	return Transform3D(Basis(Vector3.UP,_yaw_of(inward)),Vector3(at.x,hi+0.3,at.y))

# --- The line -----------------------------------------------------------------

## The hall's line in the wilderness mouth's frame (XZ as Vector2(x, z)):
## a straight, two arcs, a straight, ending on the amberlands mouth's outward
## way (the translation `_by` takes the rest).
func _line() -> void:
	var inv := _frames[0].basis.inverse()
	var out_way: Vector3 = inv*(-_frames[1].basis.z)
	var turn := atan2(out_way.x,out_way.z)
	var arc := LENGTH-2.0*(_out+_bay)
	var total := arc/RADIUS
	if absf(turn) > total*0.9: turn = signf(turn)*total*0.9
	var a := (total+turn)*0.5
	var b := (turn-total)*0.5
	_end_yaw = turn
	var pos := Vector2.ZERO
	var yaw := 0.0
	var s := 0.0
	var straight := _out+_bay
	_segs.clear()
	_segs.append({"kind":0,"from":pos,"yaw":yaw,"s":s,"len":straight})
	pos += _dir(yaw)*straight
	s += straight
	for sweep: float in [a,b]:
		var left := signf(sweep)
		var length := absf(sweep)*RADIUS
		var mid := pos+_dir(yaw+left*PI*0.5)*RADIUS
		_segs.append({"kind":1,"mid":mid,"yaw":yaw,"s":s,"len":length,"sign":left})
		pos = mid+(pos-mid).rotated(-sweep)
		yaw += sweep
		s += length
	_segs.append({"kind":0,"from":pos,"yaw":yaw,"s":s,"len":straight})

## Way of a yaw (0 along +z, growing toward +x) as Vector2(x, z).
static func _dir(yaw: float) -> Vector2:
	return Vector2(sin(yaw),cos(yaw))

func _len() -> float:
	var last: Dictionary = _segs[_segs.size()-1]
	return float(last.s)+float(last.len)

## Vector3(x, z, yaw) on the line at `s`.
func _on(s: float) -> Vector3:
	for g: Dictionary in _segs:
		var t := s-float(g.s)
		if t > float(g.len) and g != _segs[_segs.size()-1]: continue
		if int(g.kind) == 0:
			var p: Vector2 = (g.from as Vector2)+_dir(float(g.yaw))*t
			return Vector3(p.x,p.y,float(g.yaw))
		var sw: float = float(g.sign)*t/RADIUS
		var from: Vector2 = -_dir(float(g.yaw)+float(g.sign)*PI*0.5)*RADIUS
		var at: Vector2 = (g.mid as Vector2)+from.rotated(-sw)
		return Vector3(at.x,at.y,float(g.yaw)+sw)
	return Vector3.ZERO

## The line's point at `s` in the mouth's frame (on the floor).
func _at_s(s: float) -> Vector3:
	var o := _on(s)
	return Vector3(o.x,0.0,o.y)

## Vector3(s along the line, off it (to the left of the way, +), up over
## the floor) of world `p` in the hall as it stands now.
func _q(p: Vector3) -> Vector3:
	var l := _frames[0].affine_inverse()*(p-(_by if _side == 1 else Vector3.ZERO))
	var at := Vector2(l.x,l.z)
	var best := Vector3(-INF,INF,l.y)
	for g: Dictionary in _segs:
		var s := 0.0
		var off := 0.0
		if int(g.kind) == 0:
			var d := _dir(float(g.yaw))
			var to: Vector2 = at-(g.from as Vector2)
			var t := to.dot(d)
			# A straight runs on past the hall's ends.
			var first: bool = float(g.s) == 0.0
			var lastly: bool = g == _segs[_segs.size()-1]
			if (t < 0.0 and not first) or (t > float(g.len) and not lastly): continue
			s = float(g.s)+t
			off = to.dot(Vector2(d.y,-d.x))
		else:
			var r: Vector2 = at-(g.mid as Vector2)
			var from: Vector2 = -_dir(float(g.yaw)+float(g.sign)*PI*0.5)
			var sw := from.angle_to(r)
			# angle_to is counter-clockwise in (x, z); the sweep runs the other way.
			var t := -sw*float(g.sign)*RADIUS
			if t < 0.0 or t > float(g.len): continue
			s = float(g.s)+t
			off = (RADIUS-r.length())*float(g.sign)
		if absf(off) < absf(best.y): best = Vector3(s,off,l.y)
	return best

# --- The look -----------------------------------------------------------------

## The hall's bay meshes: {inner: [ArrayMesh], front: ArrayMesh}, built once.
func _bays() -> Dictionary:
	RuinKit_.set_detail(0.0)
	var plans: Array = [
		{"roof":"whole","lancets":Vector2(1.0,1.0)},
		{"roof":"whole","gaps":[2],"lancets":Vector2(0.5,1.0),"breach":Vector2i(0,Hall.BREACHES.find("collapse"))},
		{"roof":"broken","gaps":[3],"lancets":Vector2(1.0,0.5),"architraves":Vector2(1.0,0.0)},
		{"roof":"whole","gaps":[1],"lancets":Vector2(1.0,1.0),"breach":Vector2i(Hall.BREACHES.find("low"),0)},
	]
	var inner: Array = []
	for i in plans.size(): inner.append(_bay_mesh(Hall.bay(4100+i*7,0.3,plans[i])))
	RuinKit_.set_detail(Hall.IN_WORLD)
	var front := _bay_mesh(Hall.bay(4177,0.45,{"roof":"broken","gaps":[2],"lancets":Vector2(1.0,1.0),"gable":true,"last":false}))
	var out: Array = []
	for i in 2: out.append(_bay_mesh(Hall.bay(4190+i,0.5,{"roof":"broken" if i == 0 else "open","gaps":[2,3],"lancets":Vector2(1.0,1.0),"breach":Vector2i(Hall.BREACHES.find("low") if i == 0 else 0,Hall.BREACHES.find("arch") if i == 1 else 0)})))
	RuinKit_.set_detail(1.0)
	return {"inner":inner,"front":front,"out":out}

## The stone of a built bay as one mesh (the node freed).
func _bay_mesh(node: Node3D) -> ArrayMesh:
	var mesh: ArrayMesh = null
	for m: Node in node.find_children("*","MeshInstance3D",true,false):
		var mi := m as MeshInstance3D
		if mi.mesh is ArrayMesh and (mesh == null or mi.mesh.get_surface_count() > 0):
			mesh = mi.mesh
			break
	node.free()
	return mesh

## A bay's instance at `s` (its x along the line): straight, on the chord of
## the line under it, a shade long so the arcs leave no gap.
func _bay_at(s: float, stretch := 1.02) -> Transform3D:
	var a := _on(s)
	var b := _on(s+_bay)
	var way := Vector3(b.x-a.x,0.0,b.y-a.y).normalized()
	var side := way.cross(Vector3.UP)
	var bs := Basis(way*_big*stretch,Vector3.UP*_big,side*_big)
	return Transform3D(bs,Vector3(a.x,0.0,a.y))

## A MultiMesh of `mesh` at `xfs` under `parent`.
func _instances(parent: Node3D, label: String, mesh: Mesh, xfs: Array, mat: Material, layers: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i in xfs.size(): mm.set_instance_transform(i,xfs[i])
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = mm
	node.material_override = mat
	node.layers = layers
	parent.add_child(node)
	return node

## The hall inside: its bays by sections, a dark case round them, the
## torches, the lights.
func _build_hall(parts: Dictionary) -> void:
	_hall = Node3D.new()
	_hall.name = "Hall"
	add_child(_hall)
	_hall.transform = _frames[0]
	var mats := LandTunnels_._dark_materials("limestone")
	var stone: Material = mats[RuinKit_.materials().stone]
	var inner: Array = parts.inner
	var count := roundi((_len()-2.0*_out)/_bay)
	var fit := (_len()-2.0*_out)/(count*_bay)
	var buckets := {}
	var i := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	while i < count:
		var kind := 0 if rng.randf() < 0.45 else rng.randi_range(1,inner.size()-1)
		var key := Vector2i(i/SECTION,kind)
		if not buckets.has(key): buckets[key] = []
		buckets[key].append(_bay_at(_out+i*_bay*fit,fit*1.02))
		i += 1
	for key: Vector2i in buckets:
		_instances(_hall,"Bays%d_%d" % [key.x,key.y],inner[key.y],buckets[key],stone,UNDER)
	_hall.add_child(_case())
	_build_torches()
	for k in LIGHTS:
		var l := OmniLight3D.new()
		l.light_cull_mask = UNDER
		l.layers = UNDER
		l.omni_range = LIGHT_RANGE
		l.omni_attenuation = 1.4
		l.light_color = Color(1.0,0.66,0.34)
		l.shadow_enabled = k < LIGHT_SHADOWS
		l.visible = false
		_hall.add_child(l)
		_lights.append(l)
	_hall.visible = false

## The black round the hall: past the walls and over the roof nothing is
## left of the world to see.
func _case() -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := (Hall.WALL_Z+1.0)*_big
	var h := (Hall.ROOF_TOP+1.0)*_big
	var ring: Array[Vector2] = [Vector2(-w,-0.6),Vector2(w,-0.6),Vector2(w,h),Vector2(-w,h),Vector2(-w,-0.6)]
	var s := _out-_bay
	var step := _bay*0.5
	while s < _len()-_out+_bay:
		var a := _on(s)
		var b := _on(s+step)
		var na := Vector2(cos(a.z),-sin(a.z))
		var nb := Vector2(cos(b.z),-sin(b.z))
		for k in 4:
			var p: Vector2 = ring[k]
			var q: Vector2 = ring[k+1]
			var a0 := Vector3(a.x+na.x*p.x,p.y,a.y+na.y*p.x)
			var a1 := Vector3(a.x+na.x*q.x,q.y,a.y+na.y*q.x)
			var b0 := Vector3(b.x+nb.x*p.x,p.y,b.y+nb.y*p.x)
			var b1 := Vector3(b.x+nb.x*q.x,q.y,b.y+nb.y*q.x)
			for v: Vector3 in [a0,b0,a1,a1,b0,b1]: st.add_vertex(v)
		s += step
	var mesh := st.commit()
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = Color(0.006,0.005,0.005)
	dark.cull_mode = BaseMaterial3D.CULL_DISABLED
	dark.disable_fog = true
	mesh.surface_set_material(0,dark)
	var node := MeshInstance3D.new()
	node.name = "Case"
	node.mesh = mesh
	node.layers = UNDER
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

func _build_torches() -> void:
	var bracket := LandTunnels_._sconce()
	var card := QuadMesh.new()
	card.size = LandTunnels_.TORCH_FLAME
	card.center_offset = Vector3(0.0,LandTunnels_.TORCH_FLAME.y*0.5,0.0)
	var glow := ShaderMaterial.new()
	glow.shader = LandTunnels_._card_shader()
	glow.set_shader_parameter("dot_rad",LandTunnels_.CARD_DOT)
	card.material = glow
	var spots: Array = []
	var s := _out+_bay*1.5
	var side := 1.0
	var big := 2.2
	var count := roundi((_len()-2.0*_out)/_bay)
	var fit := (_len()-2.0*_out)/(count*_bay)
	var i := 2
	while i < count-1:
		s = _out+i*_bay*fit
		var o := _on(s)
		var n := Vector3(cos(o.z),0.0,-sin(o.z))
		var at := Vector3(o.x,TORCH_Y*_big,o.y)+n*side*(Hall.ROW_Z-Hall.COLUMN_R-0.5)*_big
		spots.append([at,-n*side])
		side = -side
		i += TORCH_EVERY
	var mb := MultiMesh.new()
	mb.transform_format = MultiMesh.TRANSFORM_3D
	mb.mesh = bracket
	mb.instance_count = spots.size()
	var mf := MultiMesh.new()
	mf.transform_format = MultiMesh.TRANSFORM_3D
	mf.use_colors = true
	mf.mesh = card
	mf.instance_count = spots.size()
	var tint := Color(1.0,0.6,0.25).srgb_to_linear()
	for k in spots.size():
		var at: Vector3 = spots[k][0]
		var out: Vector3 = spots[k][1]
		mb.set_instance_transform(k,Transform3D(Basis.looking_at(out,Vector3.UP).scaled(Vector3.ONE*big),at))
		var foot := at+out*LandTunnels_.TORCH_CUP.x*big+Vector3.UP*LandTunnels_.TORCH_CUP.y*big
		mf.set_instance_transform(k,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*big),foot))
		mf.set_instance_color(k,tint)
		_lamps.append(foot+out*1.0+Vector3.UP*1.2)
	for pair: Array in [[mb,"Brackets"],[mf,"Flames"]]:
		var node := MultiMeshInstance3D.new()
		node.name = pair[1]
		node.multimesh = pair[0]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.layers = UNDER
		_hall.add_child(node)

## One side's ruin at its frame: the outside bays, the front, the plinth,
## the belfries, the plug that shuts the hall off from outside, the daylight
## card, the spill.
func _build_ruin(i: int, parts: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = String(walls[i].name).get_file()
	add_child(root)
	root.transform = _frames[i]
	var tone := Arches_.tone_name(_frames[i].origin)
	var kit: ShaderMaterial = RuinKit_.materials().stone
	var lit := kit.duplicate() as ShaderMaterial
	lit.set_shader_parameter("albedo",Arches_.TONES[tone])
	lit.set_shader_parameter("fill",3.6)
	lit.set_shader_parameter("rim",0.1)
	var layers := 1 | KEPT
	# The bays, straight along z (their x).
	var bs := Basis(Vector3(0.0,0.0,1.0)*_big*1.0,Vector3.UP*_big,Vector3(-1.0,0.0,0.0)*_big)
	var out: Array = parts.out
	var fronts: Array = [Transform3D(bs,Vector3.ZERO)]
	_instances(root,"Front",parts.front,fronts,lit,layers)
	for b in range(1,BAYS_OUT):
		_instances(root,"Bay%d" % b,out[b % out.size()],[Transform3D(bs,Vector3(0.0,0.0,_bay*b))],lit,layers)
	# The plinth: up to the floor from the land under it.
	var plinth := MeshInstance3D.new()
	plinth.name = "Plinth"
	var box := BoxMesh.new()
	box.size = Vector3(2.0*_foot+6.0,PLINTH,_out+8.0)
	plinth.mesh = box
	var base := lit.duplicate() as ShaderMaterial
	base.set_shader_parameter("albedo",(Arches_.TONES[tone] as Color)*0.42)
	plinth.material_override = base
	plinth.layers = layers
	plinth.position = Vector3(0.0,-PLINTH*0.5-0.05,_out*0.5-2.0)
	root.add_child(plinth)
	for s: float in [-1.0,1.0]:
		var tower := RuinKit_.piece("belfry_tower",4300+i*3+int(s),0.55)
		tower.position = Vector3(s*TOWER_X,-2.5,TOWER_Z)
		tower.rotation.y = PI*0.5*(s+1.0)
		root.add_child(tower)
		for mi: Node in tower.find_children("*","MeshInstance3D",true,false):
			(mi as MeshInstance3D).layers = layers
		var body := tower.find_children("*","StaticBody3D",true,false)
		for b: Node in body: b.queue_free()
	# Shuts the hall off from outside: stone without, black within.
	var plug := Node3D.new()
	plug.name = "Plug"
	root.add_child(plug)
	var wall := MeshInstance3D.new()
	var wb := BoxMesh.new()
	wb.size = Vector3(2.0*(Hall.WALL_Z+1.0)*_big,(Hall.ROOF_TOP+1.0)*_big,1.6)
	wall.mesh = wb
	wall.material_override = lit
	wall.layers = layers
	wall.position = Vector3(0.0,wb.size.y*0.5,_out+1.2)
	plug.add_child(wall)
	var black := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(wb.size.x,wb.size.y)
	black.mesh = qm
	var dark := StandardMaterial3D.new()
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dark.albedo_color = Color(0.006,0.005,0.005)
	dark.disable_fog = true
	black.material_override = dark
	black.rotation.y = PI
	black.position = Vector3(0.0,wb.size.y*0.5,_out+0.3)
	black.layers = layers
	black.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plug.add_child(black)
	_plugs.append(plug)
	# The daylight from inside.
	var card := MeshInstance3D.new()
	card.name = "Daylight"
	var cq := QuadMesh.new()
	cq.size = Vector2(wb.size.x,wb.size.y)
	card.mesh = cq
	card.material_override = _daylight()
	card.position = Vector3(0.0,wb.size.y*0.5,_out+0.2)
	card.layers = KEPT
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	card.visible = false
	root.add_child(card)
	_cards.append(card)
	var spill := OmniLight3D.new()
	spill.name = "Spill"
	spill.light_cull_mask = UNDER | KEPT
	spill.layers = UNDER | 1
	spill.omni_range = 130.0
	spill.omni_attenuation = 0.9
	spill.position = Vector3(0.0,9.0,_out*0.6)
	spill.light_energy = 0.0
	root.add_child(spill)
	_spills.append(spill)
	return root

func _daylight() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode unshaded, fog_disabled, depth_draw_never, shadows_disabled, cull_disabled;\nuniform vec3 colour = vec3(1.0);\nuniform float strength = 1.0;\nuniform float show = 1.0;\nvoid fragment() {\n\tALBEDO = colour * strength * mix(1.0, 0.7, smoothstep(0.1, 0.9, UV.y));\n\tALPHA = show;\n}\n"
	var m := ShaderMaterial.new()
	m.shader = sh
	return m

# --- The solid ------------------------------------------------------------------------

## The floor's world height where the hall stands now.
func hall_floor() -> float:
	return _frames[0].origin.y+(_by.y if _side == 1 else 0.0)

## Whether a world point counts as in the hall (the plane is in it, and `p`
## within it): the land and all that stands on it do not answer there.
func holds(p: Vector3) -> bool:
	if not inside_hall: return false
	var q := _q(p)
	return q.x > -6.0 and q.x < _len()+6.0 and absf(q.y) < (Hall.WALL_Z+2.0)*_big and q.z > -6.0 and q.z < 60.0

func _open() -> bool:
	var h := _host
	return not (h.race != null and str(h.race.state) != "free")

func ground(p: Vector3, h: Variant, pad := -1.0) -> Variant:
	var grow := WorldScale.span*0.5 if pad < 0.0 else pad
	if inside_hall:
		var q := _q(p)
		if q.x > -0.5 and q.x < _len()+0.5:
			var fl := hall_floor()
			if absf(q.y)+grow > _room+0.2: return fl+_roof*3.0
			return LandHalls_.over(p,fl,[Vector2(fl+_roof,fl+_roof+30.0)])
	for i in 2:
		var l := _frames[i].affine_inverse()*p
		if absf(l.x) > TOWER_X+TOWER_SOLID+grow or l.z < -TOWER_SOLID or l.z > _out+4.0+grow: continue
		if l.y > TOWER_TOP+4.0: continue
		var fl: float = _frames[i].origin.y
		for s: float in [-1.0,1.0]:
			if absf(l.x-s*TOWER_X) < TOWER_SOLID+grow and absf(l.z-TOWER_Z) < TOWER_SOLID+grow: return fl+TOWER_TOP
		if absf(l.x) < _foot+grow and l.z > -4.0:
			if _open() and absf(l.x)+grow < _room and l.y < _roof and l.z < _out+1.0:
				return LandHalls_.over(p,fl,[Vector2(fl+_roof,fl+SHELL_TOP*_big)])
			return fl+SHELL_TOP*_big
	return h

## SkyGlide's `guide` in the hall: as LandTunnels `guide`, off the walls, the
## roof and the floor.
func guide(p: Vector3, heading: float, speed: float) -> Dictionary:
	if not inside_hall:
		return _host.tunnels.guide(p,heading,speed)
	var q := _q(p)
	if q.x < 0.0 or q.x > _len(): return {}
	var o := _on(q.x)
	var yaw_w: float = _frames[0].basis.get_euler().y
	# The way along the line, world.
	var along := Vector3(sin(o.z),0.0,cos(o.z)).rotated(Vector3.UP,yaw_w)
	var fwd := Vector2(-sin(heading),-cos(heading))
	var sense := 1.0 if fwd.dot(Vector2(along.x,along.z)) >= 0.0 else -1.0
	var ahead := _q(p+Vector3(fwd.x,0.0,fwd.y)*maxf(speed,10.0)*GUARD_LOOK)
	var off := ahead.y if absf(ahead.y) > absf(q.y) else q.y
	var left := Vector3(along.z,0.0,-along.x)
	var room := _room-WorldScale.span*0.5
	var near := clampf((absf(off)-(room-GUARD_MARGIN))/GUARD_MARGIN,0.0,1.0)
	var push := -signf(off)*left*GUARD_PUSH*near*near
	var turn := 0.0
	var way := atan2(-along.x*sense,-along.z*sense)
	if near > 0.0 and Vector2(left.x,left.z).dot(fwd)*signf(off) > 0.0: turn = near
	var level := 0.0
	var up := clampf((q.z-(_roof-SkyGlide_.CLEAR-GUARD_ROOF))/GUARD_ROOF,0.0,1.0)
	if up > 0.0:
		push.y -= GUARD_PUSH*up*up
		level = up
	var down := clampf((SkyGlide_.SKIM+GUARD_FLOOR-q.z)/GUARD_FLOOR,0.0,1.0)
	if down > 0.0:
		push.y += GUARD_LIFT*down*down
		level = -down
	if near == 0.0 and level == 0.0: return {}
	return {"push":push,"heading":way,"turn":turn,"level":level}

## SkyGlide's `keep` in the hall: put back on the edge of the clear room.
func keep(p: Vector3) -> Vector3:
	if not inside_hall: return _host.tunnels.keep(p)
	var q := _q(p)
	if q.x < 0.0 or q.x > _len(): return p
	var out := p
	var room := _room-WorldScale.span*0.5-0.05
	if absf(q.y) > room:
		var o := _on(q.x)
		var yaw_w: float = _frames[0].basis.get_euler().y
		var along := Vector3(sin(o.z),0.0,cos(o.z)).rotated(Vector3.UP,yaw_w)
		var left := Vector3(along.z,0.0,-along.x)
		out -= left*signf(q.y)*(absf(q.y)-room)
	var top := hall_floor()+_roof-SkyGlide_.CLEAR-0.05
	if out.y > top: out.y = top
	return out

# --- Each frame -----------------------------------------------------------------------

func step(delta: float) -> void:
	if walls.is_empty(): return
	var h := _host
	var plane: RefCounted = h.plane
	var p: Vector3 = plane.position
	if not inside_hall:
		for i in 2:
			var l := _frames[i].affine_inverse()*p
			if _open() and l.z > 0.0 and l.z < 14.0 and absf(l.x) < _room and l.y > -1.0 and l.y < _roof+2.0:
				_side = i
				_enter()
				break
	else:
		var q := _q(p)
		if q.x < -1.0 or q.x > _len()+1.0: _leave()
		else:
			var mid := _len()*0.5
			if _side == 0 and q.x > mid+SWAP_SLACK: _swap(1)
			elif _side == 1 and q.x < mid-SWAP_SLACK: _swap(0)
	_prewarm(plane.position)
	_hint(delta,plane.position,h.hand_landing.flying(),h.race != null and str(h.race.state) != "free")

func _enter() -> void:
	inside_hall = true
	_hall.visible = true
	_hall.position = _frames[0].origin+(_by if _side == 1 else Vector3.ZERO)
	var plane: RefCounted = _host.plane
	plane.guide = Callable(self,"guide")
	plane.keep = Callable(self,"keep")
	for pl: Node3D in _plugs: pl.visible = false
	print("doors: into the hall on side %d" % _side)

func _leave() -> void:
	inside_hall = false
	_hall.visible = false
	var plane: RefCounted = _host.plane
	plane.guide = Callable(_host.tunnels,"guide")
	plane.keep = Callable(_host.tunnels,"keep")
	for pl: Node3D in _plugs: pl.visible = true
	print("doors: out of the hall on side %d" % _side)

## The plane, the eye and the hall moved by one translation to side `to`:
## the same frame in view, the other land under it all.
func _swap(to: int) -> void:
	var from := 1-to
	var h := _host
	var by := _by if to == 1 else -_by
	var plane: RefCounted = h.plane
	var t0 := Time.get_ticks_usec()
	plane.carry((plane.position as Vector3)+by,plane.velocity,float(plane.speed))
	_hall.position += by
	h.chase.eye += by
	h.chase.look += by
	h.chase.goal += by
	(h.camera as Camera3D).global_position += by
	h.plane_figure.shift(by)
	_swap_land(to)
	_side = to
	var t1 := Time.get_ticks_usec()
	_wash()
	var t2 := Time.get_ticks_usec()
	_set_hour(from,to)
	var t3 := Time.get_ticks_usec()
	print("doors: swap parts ms: move %.1f wash %.1f hour %.1f" % [(t1-t0)/1000.0,(t2-t1)/1000.0,(t3-t2)/1000.0])
	swaps += 1
	passes += 1
	if h.book != null and h.book.find(String(walls[from].find)): print("doors: first pass of %s" % walls[from].name)
	_swap_watch = 120
	_swap_worst = 0.0
	_last_usec = Time.get_ticks_usec()
	print("doors: the hall swapped to side %d (land %s, %.0f%% prewarmed) in %.1f ms" % [to,str(h.land.counts()),_warm_share*100.0,(Time.get_ticks_usec()-t0)/1000.0])

## The far side's land stepped round its mouth, near a mouth or in the hall.
func _prewarm(p: Vector3) -> void:
	var side := _side if inside_hall else side_at(p)
	if side < 0 or side > 1 or lands[1-side] == null: return
	if not inside_hall and Vector2(p.x,p.z).distance_to(_xz(side)) > PREWARM_HALL: return
	lands[1-side].step(_frames[1-side]*Vector3(0.0,40.0,-90.0))

## After the land and the camera have stepped: the eye's world, the lights,
## the daylight.
func late(eye: Vector3) -> void:
	if walls.is_empty(): return
	var h := _host
	var dt := get_process_delta_time()
	_time += dt
	if _swap_watch > 0:
		var now := Time.get_ticks_usec()
		_swap_worst = maxf(_swap_worst,(now-_last_usec)/1000.0)
		_last_usec = now
		_swap_watch -= 1
		if _swap_watch == 0:
			worst_ms = _swap_worst
			print("doors: the worst frame round the swap %.1f ms" % _swap_worst)
	if not _sky_cut: _cut_sky()
	var cam: Camera3D = h.camera
	if _mask_all == 0: _mask_all = cam.cull_mask
	_spilled(eye)
	if not inside_hall:
		if not _world_on: _set_world(true)
		for c: MeshInstance3D in _cards: c.visible = false
		return
	var q := _q(eye)
	var from_mouth := minf(q.x,_len()-q.x)-_out
	var inner := q.x > 0.0 and q.x < _len() and from_mouth > WORLD_OFF
	if _world_on == inner: _set_world(not inner)
	if h.look != null and h.look.get("clouds") != null and "fog_hush" in h.look.clouds:
		h.look.clouds.fog_hush = smoothstep(-_out,0.0,from_mouth)
	var show := smoothstep(CLEAR_AT,WORLD_OFF,from_mouth)
	var c := _day
	for i in 2:
		# Seen from inside only: the eye still in the hall proper.
		var at_end := q.x > _len()*0.5 if i == 1 else q.x < _len()*0.5
		var on := i == _side and at_end and from_mouth > 1.0
		var card := _cards[i]
		card.visible = on and show > 0.002
		var mat := card.material_override as ShaderMaterial
		mat.set_shader_parameter("colour",Vector3(c.r,c.g,c.b))
		mat.set_shader_parameter("strength",1.5)
		mat.set_shader_parameter("show",show)
	_light_torches(q.x)

## Each ruin's daylight into its stone, near it only, in the land's haze.
func _spilled(eye: Vector3) -> void:
	var look: Node = _host.look
	var env: Environment = look.get("environment") if look != null else null
	if env != null: _day = env.fog_light_color
	for i in 2:
		var sp := _spills[i]
		var near := i == (_side if inside_hall else side_at(eye)) and (_frames[i].origin+(Vector3.ZERO)).distance_to(eye) < 700.0
		sp.visible = near
		if near:
			sp.light_color = _day
			sp.light_energy = 7.0

func _set_world(on: bool) -> void:
	_world_on = on
	var cam: Camera3D = _host.camera
	cam.cull_mask = _mask_all if on else (UNDER | KEPT)
	var fig: Node = _host.plane_figure
	if _figure_layers.is_empty():
		for n: Node in fig.find_children("*","VisualInstance3D",true,false):
			_figure_layers[n] = (n as VisualInstance3D).layers
	for n: Node in _figure_layers:
		if is_instance_valid(n): (n as VisualInstance3D).layers = int(_figure_layers[n]) if on else UNDER

func _cut_sky() -> void:
	var lights: Array = get_tree().root.find_children("*","DirectionalLight3D",true,false)
	for l: DirectionalLight3D in lights: l.light_cull_mask &= ~UNDER
	_sky_cut = not lights.is_empty()

## The pool: the LIGHTS torches nearest `s` (a little ahead).
func _light_torches(s: float) -> void:
	if _lamps.is_empty(): return
	var at := _at_s(s)
	var ranked: Array = []
	for i in _lamps.size():
		var d2 := Vector3(_lamps[i].x-at.x,0.0,_lamps[i].z-at.z).length_squared()
		ranked.append(Vector2(d2,i))
	ranked.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	for k in _lights.size():
		var l := _lights[k]
		if k >= ranked.size():
			l.visible = false
			continue
		var i := int((ranked[k] as Vector2).y)
		var d := sqrt((ranked[k] as Vector2).x)
		var fade := clampf((LIGHTS*22.0-d)/40.0,0.0,1.0)
		var flick := 1.0+0.12*(sin(_time*11.0+i*1.7)*0.6+sin(_time*23.0+i*3.1)*0.4)
		l.position = _lamps[i]
		l.light_energy = LIGHT_ENERGY*fade*flick
		l.visible = true

# --- The rest -------------------------------------------------------------------------

func door_for_traffic() -> Dictionary:
	var xf: Transform3D = _frames[0]
	var moved := Transform3D(xf.basis,xf*Vector3(0.0,0.0,_out*0.5))
	return {"xform":moved,"half":Vector3(_room,_roof,_out*0.5),"aim":xf*Vector3(0.0,_roof*0.5,10.0)}

func input(asked: Dictionary) -> Dictionary:
	return asked
