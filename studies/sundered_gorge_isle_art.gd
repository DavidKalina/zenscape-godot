extends RefCounted
## The Sundered gorge isle's art (studies/sundered_gorge_isle.gd,
## docs/scenic/sundered-gorge.md): one big isle torn in two along a gorge
## that runs north and south, the halves drifted apart. The west half (the
## lower) is tilted down toward the gorge by TILT; the east half stands
## level and higher (E_TOP). Sheer walls drop into the gorge from both lips,
## faceted and lit warm (not the old ravine's black), with ledges cut along
## them; the hanging rock of both keels leans in under the split.
##
## A great stone bridge once spanned the gorge on one semicircular arch. The
## halves drifted, it snapped at the crown: each half keeps its half-arch,
## its spandrel and deck torn off ragged over the gap, and a rope bridge
## (scripts/rope_bridge.gd, live) is slung between stone anchors on the two
## snapped ends (RuinKit `bridge_anchor`, the kit isles' one anchor). The crown's stones hang in the gap
## beside it (an expert's crossing) and the rest of it lies on a fragment of
## the isle caught deep in the gorge under the break.
##
## Each half reads as its own place: the west has the gatehouse at the
## bridge head (the kit's gate arch over the road and a tower beside it,
## leaning with the tilt over the lip, its fallen quarter a climb to its
## crown), a tor with a broken pier on it, and a spring pool whose outflow
## pours over the lip into the gorge as a wide curtain. The east has a
## roofless chapel facing the bridge (the kit's rose gable and lancet walls)
## and a crag.
##
## A second crossing lower down makes a loop: the kit's stairs cut down the
## west wall to two ledges, two fragments of the isle caught in the gap, a
## ledge on the east wall that ramps back up to the east top; a split
## pillar beside it is a wall-kick chimney (the expert's way up).
##
## Everything is in the world's frame. The west half's own frame (`W`) is
## the world tilted about the gorge's line (+X down toward the gorge by
## TILT): what stands on it is built in that frame, so it leans with it.
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Aqueduct = preload("res://scripts/ruin_kit_aqueduct.gd")
const AqArt = preload("res://studies/aqueduct_isle_art.gd")
const Footbridge = preload("res://scripts/footbridge.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const FlowFalls = preload("res://scripts/flow_falls.gd")
const Build = RuinKit.Build

# --- The halves -------------------------------------------------------------------

## The west half's lip on the bridge's line (world y), the tilt (rise a metre
## west, tan 7°) about the line x PIVOT_X; the east half's top.
const TOP := 30.0
const TILT := 0.1228
const PIVOT_X := 78.0
const E_TOP := 31.6
## The bridge's line (world z).
const Z_BR := -15.0
## The gorge's lips (world x, z), north to south: the plateaus' edges.
const WEST_LIP := [Vector2(80.0,-64.0),Vector2(80.6,-56.0),Vector2(79.4,-49.0),Vector2(78.8,-42.0),Vector2(79.6,-35.0),
	Vector2(79.2,-28.0),Vector2(78.0,-21.0),Vector2(78.0,-9.0),Vector2(76.8,-2.0),Vector2(75.2,6.0),Vector2(72.5,14.0),Vector2(69.0,21.0)]
const EAST_LIP := [Vector2(93.5,-63.0),Vector2(94.0,-56.0),Vector2(95.6,-49.0),Vector2(96.4,-42.0),Vector2(96.0,-35.0),
	Vector2(97.0,-28.0),Vector2(98.0,-21.0),Vector2(98.0,-9.0),Vector2(99.6,-2.0),Vector2(101.5,6.0),Vector2(104.5,14.0),Vector2(108.0,20.0)]
## The rest of each half's rim, from the gorge's south end round its back
## to the north end.
const WEST_BACK := [Vector2(62.0,22.5),Vector2(54.5,22.0),Vector2(48.0,18.5),Vector2(43.0,12.5),Vector2(39.8,4.5),
	Vector2(38.5,-5.0),Vector2(39.0,-16.0),Vector2(40.0,-28.0),Vector2(42.0,-40.0),Vector2(45.0,-50.0),Vector2(50.0,-58.0),
	Vector2(56.5,-63.5),Vector2(63.5,-66.5),Vector2(71.0,-67.0),Vector2(77.0,-66.0)]
const EAST_BACK := [Vector2(114.0,22.0),Vector2(120.5,20.0),Vector2(126.5,15.0),Vector2(130.5,8.0),Vector2(132.8,-2.0),
	Vector2(133.5,-13.0),Vector2(132.5,-25.0),Vector2(130.0,-37.0),Vector2(126.0,-48.0),Vector2(120.0,-57.0),
	Vector2(112.5,-62.5),Vector2(104.5,-65.5),Vector2(98.0,-65.0)]
## The ledges cut along the gorge's walls: [name, z from, z to, how far out
## from the lip (m), height off the half's plane (a float, or "ramp")].
## West: the upper ledge L1 and the lower L2 (the kit's two flights between
## them and up to the top, on L1 and L2), a tongue of the top at the upper
## flight's head. East: the landing where the lower crossing comes in, the
## ramp up the wall to the top, a tongue at its head.
const FLIGHT := RuinKit.STEPS*RuinKit.RISER
const WEST_STRIPS := [["l2",-49.5,-38.5,3.2,-2.0*FLIGHT],["l1",-38.5,-33.0,3.2,-FLIGHT],["stair_a",-33.0,-29.0,3.2,-FLIGHT],["tongue",-29.0,-26.0,3.2,0.0]]
const EAST_STRIPS := [["landing",-51.0,-46.0,3.0,-2.0*FLIGHT],["ramp",-46.0,-28.0,3.0,"ramp"],["tongue",-28.0,-26.0,3.0,0.0]]
## The kit's flights down the west wall: [name, foot z, head z] (each
## climbs south, its foot on the ledge under it).
const KIT_RUN := (RuinKit.STEPS-1)*RuinKit.TREAD+RuinKit.LANDING
const FLIGHTS := [["stair_b",-43.0,-43.0+KIT_RUN,-2.0*FLIGHT],["stair_a",-33.0,-33.0+KIT_RUN,-FLIGHT]]
## The tors: [middle (world x, z), height over its half, radius, the ramp's
## way (degrees, east toward north) and half width (degrees), its length].
const WEST_TOR := [Vector2(52.0,-33.0),8.0,7.6,270.0,13.0,24.0]
const EAST_TOR := [Vector2(124.0,-37.0),6.5,6.4,190.0,13.0,19.5]
## The spring pool on the west top: its middle, radius, the outflow's way
## to the lip (along +x at z POOL.y), the channel's half width.
const POOL := Vector2(73.0,-56.0)
const POOL_R := 4.3
const CHANNEL_HALF := 3.0
## The ground's faces: cells (m), finer by the ledges, the pool and tors.
const CELL := 2.0
const FINE := 1.0
## Under the lips the walls run sheer this far (m), then undercut to the
## keels; each half's keel this deep under its top, pulled toward the gorge.
const SHEER := 12.0
const DEPTH := 30.0

## The west half's plane (world y) at x: TOP on the pivot line, rising west.
static func plane_w(x: float) -> float:
	return TOP+TILT*(PIVOT_X-x)

## The west half's frame at world (x, z) on its plane: tilted, origin there.
static func frame_w(x: float, z: float, y_off := 0.0, yaw := 0.0) -> Transform3D:
	return Transform3D(tilt_basis()*Basis(Vector3.UP,yaw),Vector3(x,plane_w(x)+y_off,z))

static func tilt_basis() -> Basis:
	return Basis(Vector3.BACK,-atan(TILT))

## The lip's x at z on a lip polyline (north to south).
static func lip_at(lip: Array, z: float) -> float:
	if z <= (lip[0] as Vector2).y: return (lip[0] as Vector2).x
	for i in range(lip.size()-1):
		var a: Vector2 = lip[i]
		var b: Vector2 = lip[i+1]
		if z <= b.y: return lerpf(a.x,b.x,(z-a.y)/(b.y-a.y))
	return (lip[lip.size()-1] as Vector2).x

## The strip of `strips` over z, or [].
static func strip_at(strips: Array, z: float) -> Array:
	for s: Array in strips:
		if z >= float(s[1]) and z < float(s[2]): return s
	return []

## A strip's height off its half's plane at z.
static func strip_off(s: Array, z: float) -> float:
	if s[4] is String:
		return lerpf(-2.0*FLIGHT,0.0,clampf((z-float(s[1]))/(float(s[2])-float(s[1])),0.0,1.0))
	return float(s[4])

## A tor's rise at world (x, z): its height inside its wandering edge, down
## its ramp, else 0.
static func tor(spec: Array, x: float, z: float) -> float:
	var c: Vector2 = spec[0]
	var d := Vector2(x-c.x,z-c.y)
	var r := d.length()
	var t := fposmod(rad_to_deg(atan2(-d.y,d.x)),360.0)
	var a := deg_to_rad(t)
	var edge := float(spec[2])+0.9*sin(3.0*a+1.1)+0.5*sin(5.0*a+0.4)
	var h := float(spec[1])
	if r < edge: return h
	var off := absf(wrapf(t-float(spec[3]),-180.0,180.0))
	if off < float(spec[4]) and r < edge+float(spec[5]): return h*(1.0-(r-edge)/float(spec[5]))
	return 0.0

## The ground at world (x, z) on the west half: its tilted plane, the tor,
## the pool dug in, or a ledge strip past the lip.
static func ground_w(x: float, z: float) -> float:
	var lip := lip_at(WEST_LIP,z)
	var y := plane_w(x)
	if x > lip+0.01:
		var s := strip_at(WEST_STRIPS,z)
		if not s.is_empty(): return y+strip_off(s,z)
		return y
	y += tor(WEST_TOR,x,z)
	return _pool_cut(x,z,y)

## The ground at world (x, z) on the east half: level, the crag, the ledges.
static func ground_e(x: float, z: float) -> float:
	var lip := lip_at(EAST_LIP,z)
	if x < lip-0.01:
		var s := strip_at(EAST_STRIPS,z)
		if not s.is_empty(): return E_TOP+strip_off(s,z)
		return E_TOP
	return E_TOP+tor(EAST_TOR,x,z)+slump(x,z)

## The east half's south end slumped in two terraces as it tore away, each
## SLUMP lower (a jump caught back up), their edges wandering; a ramp down
## both in the band SLUMP_RAMP (world x), walked.
const SLUMP := 1.6
const SLUMP_RAMP := Vector2(117.5,121.5)
static func slump_edges(x: float) -> Vector2:
	return Vector2(1.5+2.5*sin(x*0.17+0.4),11.0+2.0*sin(x*0.23+1.3))

static func slump(x: float, z: float) -> float:
	var e := slump_edges(x)
	if x > SLUMP_RAMP.x and x < SLUMP_RAMP.y:
		return -SLUMP*clampf((z-(e.x-3.0))/6.0,0.0,1.0)-SLUMP*clampf((z-(e.y-3.0))/6.0,0.0,1.0)
	return (-SLUMP if z > e.x else 0.0)+(-SLUMP if z > e.y else 0.0)

## Either half's ground (the gorge's middle splits them).
static func ground(x: float, z: float) -> float:
	return ground_w(x,z) if x < (lip_at(WEST_LIP,z)+lip_at(EAST_LIP,z))*0.5 else ground_e(x,z)

# --- The pool and its fall -----------------------------------------------------------

## The pool's water level: a little under the lip where it spills.
static func water_level() -> float:
	return plane_w(lip_at(WEST_LIP,POOL.y))-0.14

## The pool and its outflow dug into the turf at (x, z) under `base`.
static func _pool_cut(x: float, z: float, base: float) -> float:
	var wl := water_level()
	var d := Vector2(x,z).distance_to(POOL)
	var y := base
	if d < POOL_R+1.6:
		var bed := wl-0.08-0.55*maxf(0.0,1.0-pow(d/POOL_R,2.0))
		y = minf(y,lerpf(bed,base,smoothstep(POOL_R-0.4,POOL_R+1.6,d)))
	var dz := absf(z-POOL.y)
	if x > POOL.x and dz < CHANNEL_HALF+1.0:
		var bed := wl-0.1-0.12*maxf(0.0,1.0-pow(dz/CHANNEL_HALF,2.0))
		y = minf(y,lerpf(bed,base,smoothstep(CHANNEL_HALF-0.3,CHANNEL_HALF+1.0,dz)))
	return y

## The water the pilot wades (PilotPhysicsGround `pools`).
static func pools() -> Array:
	var lip := lip_at(WEST_LIP,POOL.y)
	return [{"rect":Rect2(POOL.x-POOL_R-0.5,POOL.y-POOL_R-0.5,lip-(POOL.x-POOL_R-0.5),POOL_R*2.0+1.0),"top":water_level()}]

## True where the pool's water stands over the ground (world x, z).
static func wet(p: Vector2) -> bool:
	var lip := lip_at(WEST_LIP,p.y)
	if p.x > lip or Vector2(p.x,p.y).distance_to(POOL) > POOL_R+1.8 and (p.x < POOL.x or absf(p.y-POOL.y) > CHANNEL_HALF+1.0): return false
	return ground_w(p.x,p.y) < water_level()-0.01

## The pool's water (scripts/kit_isle/kit_water.gd: the edit chunks' own
## still water, clear teal, down the outflow to the brink) and the curtain
## off the lip: the waterfalls' strand (shaders/flow_fall.gdshader, as the
## sky forest isles lay their long falls), FALL_HALF across, falling down
## the gorge's west wall past the ledges into the deep. --old-water lays the
## islets' pond water on a coarse fan, as before.
const FALL_HALF := 3.0
const FALL_DROP := 17.0
const FALL_TAIL := 9.0
const FALL_STRENGTH := 0.62
static func water(seed_value: int) -> Node3D:
	var node := Node3D.new()
	node.name = "Water"
	var wl := water_level()
	var lip := lip_at(WEST_LIP,POOL.y)
	if KitWater.old_water(): _old_sheet(node,wl,lip)
	else:
		var from := POOL.x-POOL_R-1.8
		node.add_child(KitWater.still({"name":"Pool","level":wl,
			"ground":func(x: float, z: float) -> float: return ground_w(x,z),
			"rect":Rect2(from,POOL.y-POOL_R-1.8,lip+0.5-from,(POOL_R+1.8)*2.0),
			"inside":func(p: Vector2) -> bool: return p.x < lip_at(WEST_LIP,p.y)}))
	# The curtain over the lip.
	var at := Vector3(lip,wl,POOL.y)
	var rings: Dictionary = SkyIslets.curtain(at,Vector3.RIGHT,FALL_DROP,FALL_TAIL,FALL_HALF,0.3,FALL_STRENGTH)
	var curtain := MeshInstance3D.new()
	curtain.name = "Fall"
	curtain.mesh = FlowFalls._build_ring_mesh(SkyIslets.FALL_RINGS)
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/flow_fall.gdshader")
	material.render_priority = FlowFalls.CURTAIN_PRIORITY
	material.set_shader_parameter("fall_seed",float(seed_value%997)*0.37+3.0)
	var white := PackedFloat32Array()
	for s in range(12): white.append(fposmod(sin(float(s*23+seed_value%1000)*12.9898)*43758.5453,1.0))
	material.set_shader_parameter("section_white",white)
	material.set_shader_parameter("ring_count",SkyIslets.FALL_RINGS)
	material.set_shader_parameter("centers_tau",rings.centers)
	material.set_shader_parameter("axis_a_width",rings.across)
	material.set_shader_parameter("axis_b_thick",rings.outward)
	material.set_shader_parameter("aer_steep",rings.aer_steep)
	material.set_shader_parameter("ring_travel",rings.travel)
	material.set_shader_parameter("body_white",0.3*(1.0-smoothstep(0.15,0.8,float(rings.half))))
	material.set_shader_parameter("veil",1.0-smoothstep(0.15,0.85,FALL_STRENGTH))
	material.set_shader_parameter("streak_speed",clampf(0.6*sqrt(2.0*9.81*FALL_DROP),2.5,7.0))
	material.set_shader_parameter("break_from",rings.break_from)
	material.set_shader_parameter("break_length",rings.break_length)
	curtain.material_override = material
	curtain.custom_aabb = rings.bounds
	curtain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	curtain.set_meta("skip_reflection",true)
	node.add_child(curtain)
	node.set_meta("lip",at)
	return node

## The sheet as it was (--old-water): a fan round the pool's middle out to
## where the ground rises over the water, and the channel's strip to the
## lip, in the islets' pond water.
static func _old_sheet(node: Node3D, wl: float, lip: float) -> void:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var rim: Array[Vector3] = []
	for k in range(36):
		var a := TAU*k/36.0
		var dir := Vector2(cos(a),sin(a))
		var r := POOL_R
		while r < POOL_R+1.6 and ground_w(POOL.x+dir.x*r,POOL.y+dir.y*r) < wl: r += 0.1
		rim.append(Vector3(POOL.x+dir.x*(r+0.05),wl,POOL.y+dir.y*(r+0.05)))
	var mid := Vector3(POOL.x,wl,POOL.y)
	for k in range(36):
		for p: Vector3 in [mid,rim[k],rim[(k+1)%36]]:
			v.append(p)
			n.append(Vector3.UP)
	var half := CHANNEL_HALF+0.15
	for p: Vector3 in [Vector3(POOL.x,wl,POOL.y-half),Vector3(lip+0.05,wl,POOL.y-half),Vector3(lip+0.05,wl,POOL.y+half),
			Vector3(POOL.x,wl,POOL.y-half),Vector3(lip+0.05,wl,POOL.y+half),Vector3(POOL.x,wl,POOL.y+half)]:
		v.append(p)
		n.append(Vector3.UP)
	Aqueduct._sheet(node,v,n,"Pool")

# --- The outlines -------------------------------------------------------------------

## A half's gorge edge, north to south: the lip, stepped out by its ledge
## strips (each strip's ends a sheer corner), sampled at most every STEP m.
const STEP := 1.0
static func gorge_edge(lip: Array, strips: Array, out_sign: float) -> Array:
	var z0: float = (lip[0] as Vector2).y
	var z1: float = (lip[lip.size()-1] as Vector2).y
	var cuts := PackedFloat32Array()
	for s: Array in strips:
		cuts.append(float(s[1]))
		cuts.append(float(s[2]))
	var zs := PackedFloat32Array()
	var z := z0
	while z < z1:
		zs.append(z)
		z += STEP
	zs.append(z1)
	for c in cuts: zs.append(c)
	for p: Vector2 in lip: zs.append(p.y)
	zs.sort()
	var out: Array = []
	var last := -INF
	for zz in zs:
		if zz-last < 0.05: continue
		last = zz
		var x := lip_at(lip,zz)
		# At a strip's end: the lip and the strip's corner, both at this z,
		# in the order walked (into the strip at its north end, out of it at
		# its south end).
		var before := strip_at(strips,zz-0.01)
		var after := strip_at(strips,zz+0.01)
		var wb := float(before[3]) if not before.is_empty() else 0.0
		var wa := float(after[3]) if not after.is_empty() else 0.0
		if absf(wb-wa) > 0.01:
			out.append(Vector2(x+out_sign*wb,zz))
			out.append(Vector2(x+out_sign*wa,zz))
		else:
			out.append(Vector2(x+out_sign*wa,zz))
	return out

static func west_outline() -> Array:
	return gorge_edge(WEST_LIP,WEST_STRIPS,1.0)+WEST_BACK

static func east_outline() -> Array:
	return gorge_edge(EAST_LIP,EAST_STRIPS,-1.0)+EAST_BACK

## True for a rim point on a half's gorge side (its walls hang sheer).
static func on_gorge(p: Vector2) -> bool:
	var mid := (lip_at(WEST_LIP,p.y)+lip_at(EAST_LIP,p.y))*0.5
	var w := lip_at(WEST_LIP,p.y)
	var e := lip_at(EAST_LIP,p.y)
	if p.y < -63.5 or p.y > 20.5: return false
	return (p.x < mid and p.x > w-0.5) or (p.x >= mid and p.x < e+0.5)

# --- The isle's ground look ---------------------------------------------------------

## The chimney's split pillar: the islets' dark basalt (scripts/kit_isle/
## kit_look.gd), in the kit's stone.
const GORGE_ROCK := Color("55575c")

## The paths worn in the turf (world polylines).
const PATHS := [
	# The road: from the start through the gate to the bridge.
	[Vector2(56.0,-16.0),Vector2(64.0,-15.0),Vector2(70.0,-15.0),Vector2(78.0,-15.0)],
	# The west lip north from the gate to the stair's head and the pool.
	[Vector2(70.5,-17.5),Vector2(70.0,-22.0),Vector2(70.2,-27.6),Vector2(77.0,-28.0),Vector2(80.0,-27.4)],
	[Vector2(70.2,-27.6),Vector2(71.5,-36.0),Vector2(71.0,-46.0),Vector2(69.5,-51.0)],
	# Up the tor's ramp.
	[Vector2(60.0,-15.5),Vector2(55.0,-10.5),Vector2(52.3,-15.0),Vector2(52.2,-27.0)],
	# East: from the bridge head through the chapel and on to the crag.
	[Vector2(98.0,-15.0),Vector2(104.0,-15.0),Vector2(113.0,-15.0),Vector2(117.0,-12.0),Vector2(119.5,-5.0),Vector2(119.5,17.0)],
	# Along the east lip north to the ramp's head, and up the crag's ramp.
	[Vector2(101.0,-17.5),Vector2(100.0,-23.0),Vector2(98.2,-27.5),Vector2(100.5,-32.5),Vector2(110.0,-34.5),Vector2(118.5,-36.0)],
]
static var _wear_paths: Array = []

## How worn the ground is at `at` (0 off the paths, 1 on their middle), or
## 1 under the pool's water (nothing grows there).
static func path_wear(at: Vector2) -> float:
	if wet(at): return 1.0
	var best := INF
	for path: Array in PATHS:
		for i in range(path.size()-1):
			best = minf(best,at.distance_to(Geometry2D.get_closest_point_to_segment(at,path[i],path[i+1])))
	return clampf(1.25-best/1.4,0.0,1.0)

# --- The island builder --------------------------------------------------------------

## An island of the game's ground over `ground_fn` (world (x, z) -> y)
## inside `outline` (world x, z; the authored points kept, the edges
## subdivided, nudged a little but for the gorge's): its top drawn in the
## ground look and collided as one trimesh ("Body", with convex prisms
## under the cliffs `cliffs` lays in), its sides hanging from the rim to a
## keel DEPTH under `base`, pulled `keel_pull` toward the gorge; rim points
## on the gorge (`on_gorge`) hang sheer SHEER m before they undercut; the
## sides collide too ("Sides", the stone's layer only). `fine` rects get
## FINE cells. The aqueduct isle's `island`, generalised (an extraction
## candidate for a shared kit-isle builder).
static func island(label: String, outline: Array, ground_fn: Callable, base: float, depth: float, seed_value: int,
		keel_pull: Vector2, cliffs: Dictionary = {}, fine: Array = [], sheer := true) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var ring := _subdivide(outline,1.3 if outline.size() > 12 else 0.7,rng,sheer)
	var node := Node3D.new()
	node.name = label
	var centre := KitLand.centre_of(ring)
	var g := KitLand.Gather.new(ring,ground_fn)
	if not cliffs.is_empty(): g.add_cliffs(cliffs,0.45)
	g.grid(CELL if outline.size() > 12 else 0.8,rng,ground_fn,fine,false,true)
	if not fine.is_empty(): g.grid(FINE,rng,ground_fn,fine,true,true)
	var cliffy := PackedByteArray()
	cliffy.resize(g.points.size())
	cliffy.fill(0)
	for i in g.cliff_ids: cliffy[i] = 1
	var tone := KitLook.turf(seed_value,func(p: Vector2) -> float: return path_wear(p),
		func(p: Vector2, _y: float) -> float: return 1.0 if wet(p) else 0.0)
	var built := KitLand.surface(g.points,g.heights,g.poly,rng,tone,Callable(),cliffy)
	KitLand.draw(node,built)
	_sides(node,ring,ground_fn,base,depth,centre,keel_pull,rng,sheer)
	KitLand.bodies(node,built.faces,built.solid)
	node.set_meta("outline",g.poly)
	return node

## The rim's sides: rings under it (the turf's lip, the earth, the rock) to
## a keel; on the gorge the first rings hang sheer, faceted, in the gorge's
## warmer rock in strata, then undercut. Drawn in the ruin stone's material
## (as the islands' sides are) and collided as a trimesh ("Sides").
static func _sides(node: Node3D, ring: Array, ground_fn: Callable, base: float, depth: float, centre: Vector2, keel_pull: Vector2, rng: RandomNumberGenerator, sheer_ok: bool) -> void:
	var count := ring.size()
	var outward: Array[Vector2] = []
	var ccw := AqArt._area(ring) > 0.0
	var gorge: Array[bool] = []
	var rim_y := PackedFloat32Array()
	for i in range(count):
		var tangent: Vector2 = ((ring[(i+1)%count] as Vector2)-(ring[(i-1+count)%count] as Vector2)).normalized()
		outward.append(Vector2(tangent.y,-tangent.x) if ccw else Vector2(-tangent.y,tangent.x))
		gorge.append(sheer_ok and on_gorge(ring[i]))
		rim_y.append(float(ground_fn.call((ring[i] as Vector2).x,(ring[i] as Vector2).y)))
	var keel_at := centre.lerp(centre+keel_pull,1.0)
	# Each ring: [stride, the point at rim point i] (y, and x z).
	var rims: Array = []
	var top_ring: Array[Vector3] = []
	for i in range(count): top_ring.append(Vector3((ring[i] as Vector2).x,rim_y[i]-0.02,(ring[i] as Vector2).y))
	rims.append([1,top_ring])
	var lowest_gorge := INF
	for i in range(count):
		if gorge[i]: lowest_gorge = minf(lowest_gorge,rim_y[i])
	# Face rings down the sheer walls (shares of the way from the lip down to
	# SHEER under the top), each pushed in or out a little, so the face
	# breaks into facets and strata; then the undercut to the keel.
	var faces := [0.16,0.36,0.56,0.76,1.0]
	for k in range(1,10):
		var stride: int = [1,1,1,1,1,1,1,2,4,8][k]
		if count/stride < 4: break
		var r: Array[Vector3] = []
		for i in range(0,count,stride):
			var p: Vector2 = ring[i]
			var o: Vector2 = outward[i]
			var q := p
			var y := 0.0
			if gorge[i]:
				if k == 1:
					q = p+o*0.16
					y = rim_y[i]-0.42
				elif k <= 6:
					var f: float = faces[k-2]
					var low := minf(base-SHEER,rim_y[i]-3.0)
					q = p+o*(rng.randf_range(-0.45,0.3)-0.25*f)
					y = lerpf(rim_y[i]-0.42,low,f)+(rng.randf_range(-0.35,0.35) if k < 6 else rng.randf_range(-1.2,1.2))
				else:
					var share: float = [0.2,0.5,0.8][k-7]
					q = p.lerp(keel_at,share)
					y = base-depth*[0.58,0.8,0.94][k-7]
			else:
				var spec: Array = [[0.0,0.45,0.28],[0.0,2.1,0.35],[0.03,depth*0.08,0.0],[0.05,depth*0.13,0.0],[0.08,depth*0.18,0.0],[0.1,depth*0.22,0.0],[0.32,depth*0.48,0.0],[0.6,depth*0.74,0.0],[0.82,depth*0.92,0.0]][k-1]
				q = p.lerp(keel_at,clampf(float(spec[0])+rng.randf_range(-0.03,0.03)*float(float(spec[0]) > 0.0),0.0,0.95))+o*float(spec[2])*rng.randf_range(0.3,1.2)
				var drop: float = float(spec[1])*rng.randf_range(0.9,1.1)
				y = (rim_y[i]-drop) if k <= 2 else minf(base-drop,rim_y[i]-2.1-0.5*(k-2))
			r.append(Vector3(q.x,y,q.y))
		rims.append([stride,r])
	var keel := Vector3(keel_at.x+rng.randf_range(-1.5,1.5),base-depth,keel_at.y+rng.randf_range(-1.5,1.5))
	var rock := KitLook.RockMesh.new()
	for k in range(rims.size()-1):
		var upper: Array = rims[k][1]
		var lower: Array = rims[k+1][1]
		var su: int = rims[k][0]
		var sl: int = rims[k+1][0]
		var ratio := sl/su
		for j in range(lower.size()):
			var l0: Vector3 = lower[j]
			var l1: Vector3 = lower[(j+1)%lower.size()]
			var first := j*ratio
			var last := mini((j+1)*ratio,upper.size())
			for s in range(first,last):
				var u0: Vector3 = upper[s%upper.size()]
				var u1: Vector3 = upper[(s+1)%upper.size()]
				rock.add([u0,l0,u1],rim_y[(s*su)%count],KitLand.out_from(centre,(u0+u1+l0)/3.0),rng.randf_range(0.88,1.1))
			var ue: Vector3 = upper[last%upper.size()]
			rock.add([ue,l0,l1],rim_y[(j*sl)%count],KitLand.out_from(centre,(ue+l0+l1)/3.0),rng.randf_range(0.88,1.1))
	var final: Array = rims[rims.size()-1][1]
	var mean_rim := 0.0
	for y in rim_y: mean_rim += y
	mean_rim /= maxf(rim_y.size(),1)
	for j in range(final.size()):
		var a: Vector3 = final[j]
		var b2: Vector3 = final[(j+1)%final.size()]
		var mid := (a+b2+keel)/3.0
		rock.add([a,keel,b2],mean_rim,KitLand.out_from(centre,mid)+Vector3.DOWN,rng.randf_range(0.88,1.1))
	node.add_child(rock.node("Mesh"))
	var body := StaticBody3D.new()
	body.name = "Sides"
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(rock.faces())
	shape.backface_collision = true
	var holder := CollisionShape3D.new()
	holder.shape = shape
	body.add_child(holder)
	node.add_child(body)

## The outline with each edge cut into pieces at most `most` m long, the
## new points nudged out or in a little (not on the gorge: its ledges'
## corners stay true); the authored points kept.
static func _subdivide(outline: Array, most: float, rng: RandomNumberGenerator, keep_gorge: bool) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for i in range(outline.size()):
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[(i+1)%outline.size()]
		out.append(a)
		var pieces := int(ceil(a.distance_to(b)/most))
		var normal := Vector2(b.y-a.y,a.x-b.x).normalized()
		var still := keep_gorge and on_gorge(a) and on_gorge(b)
		for k in range(1,pieces):
			var p := a.lerp(b,float(k)/pieces)
			if not still: p += normal*rng.randf_range(-0.3,0.3)
			out.append(p)
	return out

# --- The halves built ----------------------------------------------------------------

## The boxes where the ground's faces are finer (the ledges, stairs, pool,
## tors) and where its cliffs are probed.
static func west_fine() -> Array:
	return [Rect2(74.0,-52.0,10.0,28.0),Rect2(66.0,-62.0,16.0,12.0),Rect2(40.0,-44.0,26.0,44.0)]

static func east_fine() -> Array:
	return [Rect2(90.0,-53.0,9.0,29.0),Rect2(96.0,-48.0,38.0,22.0),Rect2(100.0,-3.0,36.0,20.0)]

static func west_half(seed_value: int) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cliffs := {"points":PackedVector2Array(),"heights":PackedFloat32Array()}
	for r: Rect2 in [Rect2(74.0,-52.0,10.0,28.0),Rect2(40.0,-44.0,26.0,44.0)]:
		var found := KitLand.cliff_points(ground_w,r,rng,Callable(),0.6,0.2)
		cliffs.points.append_array(found.points)
		cliffs.heights.append_array(found.heights)
	var node := island("WestHalf",west_outline(),ground_w,TOP,DEPTH+2.0,seed_value,Vector2(14.0,4.0),cliffs,west_fine())
	return node

static func east_half(seed_value: int) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cliffs := {"points":PackedVector2Array(),"heights":PackedFloat32Array()}
	for r: Rect2 in [Rect2(90.0,-53.0,9.0,29.0),Rect2(96.0,-48.0,38.0,22.0),Rect2(100.0,-3.0,36.0,20.0)]:
		var found := KitLand.cliff_points(ground_e,r,rng,Callable(),0.6,0.2)
		cliffs.points.append_array(found.points)
		cliffs.heights.append_array(found.heights)
	return island("EastHalf",east_outline(),ground_e,E_TOP,DEPTH+5.0,seed_value,Vector2(-12.0,2.0),cliffs,east_fine())

# --- The bridge -----------------------------------------------------------------------

## The great bridge, each half's own: in its frame x runs out over the gorge
## from the lip (x 0), y up from the lip's turf, z across. Its deck's top
## DECK_LIFT over the turf, DECK_HALF either side; under it a semicircular
## arch of radius ARCH_R springing from the wall at x 0, RING deep in two
## orders, the spandrel coursed up to the deck between the wall and the
## arch; the abutment corbelled out of the wall under the springing. Snapped
## at BREAK (the deck's end, x), the ring's stones gone past RING_KEEP.
const DECK_LIFT := 0.25
const DECK_SLAB := 0.5
const DECK_HALF := 1.85
const ARCH_R := 9.2
const RING := Vector2(0.55,0.55)
const WEST_BREAK := 6.4
const EAST_BREAK := 5.6
const PARAPET := Vector2(0.4,0.5)
## The rope bridge's ends sit this far back from the snapped deck's end.
const ANCHOR_BACK := 0.55
const ANCHOR_WIDTH := 1.32

## The springing's height in the bridge's frame.
static func spring_y() -> float:
	return DECK_LIFT-DECK_SLAB-RING.x-RING.y-ARCH_R

## Each half's bridge frame (world): the west's on its tilted plane, the
## east's turned to run west over the gorge.
static func west_bridge_frame() -> Transform3D:
	return Transform3D(tilt_basis(),Vector3(lip_at(WEST_LIP,Z_BR),plane_w(lip_at(WEST_LIP,Z_BR)),Z_BR))

static func east_bridge_frame() -> Transform3D:
	return Transform3D(Basis(Vector3.UP,PI),Vector3(lip_at(EAST_LIP,Z_BR),E_TOP,Z_BR))

## The rope bridge's two ends (world): on each snapped deck, ANCHOR_BACK in
## from its end, at the deck's top.
static func rope_ends() -> PackedVector3Array:
	return PackedVector3Array([west_bridge_frame()*Vector3(WEST_BREAK-ANCHOR_BACK,DECK_LIFT,0.0),east_bridge_frame()*Vector3(EAST_BREAK-ANCHOR_BACK,DECK_LIFT,0.0)])

## A half of the bridge (drawn; its stone collides as built, but the deck,
## which walks on one clean box: RuinKit `_walk_hull`), and its anchor.
static func half_bridge(seed_value: int, broken_at: float, weathered: float) -> Node3D:
	var b := Build.new(seed_value,weathered,"HalfBridge")
	b.settle = 0.5
	var sp := spring_y()
	var cx := ARCH_R
	var d := DECK_HALF-0.12
	# The ring: two orders, the inner set back; its stones past the break gone.
	var ring_keep := broken_at-0.6
	var keep := func(x: float) -> float: return 99.0 if x < ring_keep else -99.0
	var n := 15
	RuinKit._ring_order(b,Transform3D.IDENTITY,cx,sp,ARCH_R,ARCH_R,0.0,RING.x,d-0.14,n,99,1.0,RuinKit._stone(b,1.04),0,keep,true)
	RuinKit._ring_order(b,Transform3D.IDENTITY,cx,sp,ARCH_R,ARCH_R,RING.x,RING.y,d,n,99,1.0,RuinKit._stone(b,0.99),0,keep)
	# The spandrel: coursed from the springing up to the deck's foot, round
	# the arch's back, torn down ragged toward the break.
	var outer := ARCH_R+RING.x+RING.y+0.03
	var hole := func(y: float) -> Vector2:
		var dy := y-sp
		if dy < 0.0 or dy >= outer: return Vector2(cx,-1.0) if dy >= outer else Vector2(cx,99.0)
		return Vector2(cx,sqrt(outer*outer-dy*dy))
	var deck_foot := DECK_LIFT-DECK_SLAB
	var ragged := RuinKit._ruin_line(b,broken_at-2.4,broken_at+0.2,deck_foot-2.6,deck_foot,1.0)
	var top := func(x: float) -> float:
		if x < broken_at-2.2: return deck_foot
		return minf(deck_foot,float(ragged.call(x)))-maxf(0.0,x-(broken_at-0.4))*2.0
	RuinKit._courses(b,Transform3D.IDENTITY,-0.8,broken_at,sp+0.2,top,d,hole,0.55)
	# The abutment under the springing, corbelled out of the wall: courses
	# down past the springing, its foot broken off hanging, a corbel table.
	var abut_top := func(_x: float) -> float: return sp+0.25
	RuinKit._courses(b,Transform3D.IDENTITY,-1.6,1.1,sp-4.2,abut_top,d+0.25,Callable(),0.6)
	for k in range(4):
		var z := lerpf(-d,d,(k+0.5)/4.0)
		var s := Vector3(0.32,0.28,0.26)
		b.solid(RuinKit._box(b,s),Transform3D(Basis.IDENTITY,Vector3(1.1+0.2,sp-0.6,z)),RuinKit._stone(b,1.02),true,true)
	b.frame = Transform3D(Basis(Vector3.UP,PI*0.5),Vector3(-0.2,0.0,0.0))
	AqArt._broken_foot(b,0.0,sp-4.2)
	b.frame = Transform3D.IDENTITY
	# Ivy and strands under the arch and the deck's broken end.
	for i in range(14):
		var x := b.rng.randf_range(0.8,broken_at-0.3)
		b.hang(Vector3(x,0.0,b.rng.randf_range(-d,d)*0.85),b.rng.randf_range(0.8,3.4),true)
	# The parapets along the deck, stones gone in runs, snapped at the end.
	for s: float in [-1.0,1.0]:
		Aqueduct._parapet_run(b,-2.4,broken_at-b.rng.randf_range(0.3,0.9),s*(DECK_HALF-PARAPET.x*0.5),DECK_LIFT,PARAPET.y,PARAPET.x,Callable(),true)
	# The deck walks on one clean box, its top true, from back over the turf
	# to the snapped end.
	RuinKit._walk_hull(b,Transform3D.IDENTITY,[Plane(Vector3.RIGHT,broken_at-0.25),Plane(Vector3.LEFT,3.0),Plane(Vector3.UP,DECK_LIFT),
		Plane(Vector3.DOWN,-(DECK_LIFT-0.9)),Plane(Vector3.BACK,DECK_HALF-0.05),Plane(Vector3.FORWARD,DECK_HALF-0.05)])
	var node := b.finish()
	# The deck's slabs, drawn only (their worn tops never a gap underfoot).
	var deck := Build.new(seed_value+1,weathered,"Deck")
	deck.settle = 0.4
	Aqueduct._deck(deck,-2.8,broken_at,DECK_LIFT,Callable(),true,DECK_HALF)
	var drawn := deck.finish()
	drawn.get_node("Body").free()
	node.add_child(drawn)
	# The anchor on the snapped end.
	var anchor: Node3D = RuinKit.bridge_anchor(seed_value+2,weathered*0.6,Footbridge.WIDTH,
		{"post_x":ANCHOR_WIDTH*0.5,"post_z":0.0,"sill":Vector3(ANCHOR_WIDTH*0.5+0.33,0.11,0.32),"sill_at":Vector3(0.0,-0.11,-0.08)})
	anchor.name = "Anchor"
	anchor.transform = Transform3D(Basis(Vector3.UP,PI*0.5),Vector3(broken_at-ANCHOR_BACK-0.2,DECK_LIFT,0.0))
	node.add_child(anchor)
	return node

## The rope bridge slung between the anchors: the footbridge's rope mesh
## (scripts/footbridge.gd `build_mesh`), alive (scripts/rope_bridge.gd);
## `record` the deck the walker reads ({a, b, span}: Footbridge `deck_at`).
static func rope_bridge(seed_value: int, record: Dictionary) -> MeshInstance3D:
	var ends := rope_ends()
	var a := ends[0]
	var b := ends[1]
	record["a"] = a
	record["b"] = b
	record["span"] = Vector2(b.x-a.x,b.z-a.z).length()
	record["rails"] = true
	var mesh := Footbridge.build_mesh(a,b,seed_value)
	var bridge: MeshInstance3D = Footbridge.live(mesh,a,b,seed_value,record)
	bridge.name = "RopeBridge"
	return bridge

# --- The gatehouse (west) and the chapel (east) ----------------------------------------

## The gate arch over the road at the bridge's head (the kit's pointed arch,
## its passage along the road), on the tilted plane.
const GATE_X := 73.4
const GATE_SEED := 41
## The gate tower beside it, at the lip (its middle, world x, z), leaning
## with the half; its south-west quarter fallen in SET_OFF steps (each a
## jump caught) round to its crown: TOWER [rect in its frame (x toward the
## gorge, z south), top].
const TOWER_AT := Vector2(76.0,-24.6)
const TOWER := [
	[Rect2(-2.5,-2.5,5.0,1.6),9.6],
	[Rect2(-2.5,-0.9,3.0,1.5),9.6],
	[Rect2(0.5,-0.9,2.0,1.5),8.0],
	[Rect2(0.5,0.6,2.0,1.9),6.4],
	[Rect2(-1.0,0.6,1.5,1.9),4.8],
	[Rect2(-2.5,0.6,1.5,1.9),3.2],
	[Rect2(-4.4,0.5,1.9,2.0),1.6],
]
static func gate_frame() -> Transform3D:
	return frame_w(GATE_X,Z_BR,0.0,PI*0.5)

static func tower_frame() -> Transform3D:
	return frame_w(TOWER_AT.x,TOWER_AT.y)

## The gate tower: each block coursed solid to its top (the stone drawn
## only), a broken parapet on its crown's north edge, the foot of its east
## face hanging over the lip; `parts` its clean boxes [frame, rect, bottom,
## top] (they collide).
static func tower(seed_value: int) -> Dictionary:
	var b := Build.new(seed_value,0.5,"GateTower")
	var parts: Array = []
	for block: Array in TOWER:
		var r: Rect2 = block[0]
		var high: float = block[1]
		parts.append([r,-2.0,high])
		var long_x := r.size.x >= r.size.y
		var length := r.size.x if long_x else r.size.y
		var depth := r.size.y if long_x else r.size.x
		var pose := Transform3D(Basis.IDENTITY if long_x else Basis(Vector3.UP,PI*0.5),Vector3(r.get_center().x,0.0,r.get_center().y))
		var foot := -2.6 if r.end.x > 2.0 else -0.6
		var line := func(_x: float) -> float: return high
		RuinKit._courses(b,pose,-length*0.5,length*0.5,foot,line,depth*0.5-0.01,Callable(),0.55,high > 2.0)
	# A string course and slit windows' sills are left to the stone's own
	# courses; the crown's broken parapet on its north edge.
	var ragged := RuinKit._ruin_line(b,-2.3,2.3,0.0,0.5,0.8)
	RuinKit._courses(b,Transform3D(Basis.IDENTITY,Vector3(0.0,9.6,-2.3)),-2.3,2.3,0.0,ragged,0.18,Callable(),0.25)
	parts.append([Rect2(-2.5,-2.5,5.0,0.4),9.6,9.9])
	# Its east foot hangs broken over the lip.
	b.frame = Transform3D(Basis(Vector3.UP,PI*0.5),Vector3(2.1,0.0,0.0))
	AqArt._broken_foot(b,0.0,-2.6)
	b.frame = Transform3D.IDENTITY
	RuinKit._drift(b,Vector3(-3.4,0.0,3.6),1.2,5)
	for i in range(5): b.hang(Vector3(b.rng.randf_range(1.0,2.4),0.0,b.rng.randf_range(-2.0,2.0)),b.rng.randf_range(1.0,3.0),true,b.rng.randf_range(4.0,8.0))
	var node := b.finish()
	node.get_node("Body").free()
	return {"node":node,"parts":parts}

## The chapel facing the bridge on the east half: the kit's rose gable as
## its west front (the door on the road, the rose over it), two lancet
## walls down the nave, broken piers where its east end fell, a chest
## inside. [piece, seed, weathered, world x, z, yaw (degrees)].
const CHAPEL := [
	["rose_gable",51,0.55,104.8,-15.0,-90.0],
	["lancet_wall",52,0.5,109.0,-18.65,0.0],
	["lancet_wall",53,0.65,109.0,-11.35,180.0],
	["pier",54,0.7,114.6,-18.6,0.0],
	["pier",55,0.45,114.8,-11.4,0.0],
	["tomb_chest",56,0.5,110.0,-15.0,90.0],
	["fallen_pier",57,0.6,117.5,-10.5,30.0],
]

## The broken pier on the west tor's top (a vista's mark), and stones round it.
const TOR_PIER := Vector2(53.2,-34.0)

# --- The fragments in the gap ------------------------------------------------------------

## Pieces of the isle caught in the gorge: [name, middle (world x, z),
## radius, top (world y), keel depth]. The chain (`chain_*`) is the lower
## crossing from the west's lower ledge to the east's landing; `crown` lies
## deep under the bridge's break, the arch's fallen stones on it; `spur` a
## boulder hanging by the south mouth.
static var _fragments: Array = []
static func fragments() -> Array:
	if not _fragments.is_empty(): return _fragments
	var z := -46.6
	var west_rim := lip_at(WEST_LIP,z)+3.2
	var east_rim := lip_at(EAST_LIP,z)-3.0
	var l2 := plane_w(west_rim-0.4)-2.0*FLIGHT
	var land := E_TOP-2.0*FLIGHT
	var r1 := 1.25
	var r2 := 1.3
	var gap := (east_rim-west_rim-(r1+r2)*2.0)/3.0
	var x1 := west_rim+gap+r1
	var x2 := x1+r1+gap+r2
	_fragments = [
		["chain_1",Vector2(x1,z-0.4),r1,lerpf(l2,land,0.3),3.6],
		["chain_2",Vector2(x2,z+0.5),r2,lerpf(l2,land,0.66),4.4],
		["crown",Vector2(88.0,Z_BR+0.6),3.1,TOP-12.4,6.0],
		["spur",Vector2(90.5,9.0),1.8,TOP-6.0,5.0],
	]
	return _fragments

## The on-foot token on the fallen crown and the lodestone's rest there
## (its top's middle plus these), on its clear east half.
const CROWN_TOKEN := Vector3(1.0,0.9,0.8)
const CROWN_LODE := Vector3(1.1,0.0,-0.9)

static func fragment(name: String) -> Array:
	for f: Array in fragments():
		if f[0] == name: return f
	return []

## The fragments as islets of the same ground and rock.
static func fragment_islets(seed_value: int) -> Array:
	var out: Array = []
	for f: Array in fragments():
		var top: float = f[3]
		var flat := func(_x: float, _z: float) -> float: return top
		var node := island("Fragment_"+str(f[0]),AqArt.blob(f[1],float(f[2]),seed_value+out.size()),flat,top,float(f[4]),seed_value+out.size(),Vector2.ZERO,{},[],false)
		out.append(node)
	return out

## The fallen crown on its fragment: voussoirs and a length of deck and
## parapet tumbled where they landed (colliding as built).
static func fallen_crown(seed_value: int) -> Node3D:
	var b := Build.new(seed_value,0.7,"FallenCrown")
	var f := fragment("crown")
	var at := Vector3((f[1] as Vector2).x,float(f[3]),(f[1] as Vector2).y)
	for i in range(5):
		var s := Vector3(b.rng.randf_range(0.5,0.7),b.rng.randf_range(0.28,0.4),b.rng.randf_range(0.7,1.0))
		# On its west half: the east half is kept clear (the lodestone rests there).
		var a := b.rng.randf_range(0.6,TAU-0.6)
		var r := b.rng.randf_range(0.6,1.9)
		var tumble := Basis(Vector3.UP,b.rng.randf()*TAU)*Basis(Vector3.RIGHT,b.rng.randf_range(-0.6,0.6))
		b.solid(RuinKit._box(b,s),Transform3D(tumble,at+Vector3(-absf(cos(a))*r-0.4,s.y*0.7,sin(a)*r)),RuinKit._stone(b,1.03),true,true,[],-1,1.2)
	# A slab of the deck, tipped against the stones.
	var slab := Vector3(1.2,0.25,1.8)
	b.solid(RuinKit._box(b,slab),Transform3D(Basis(Vector3.UP,0.4)*Basis(Vector3.BACK,0.32),at+Vector3(-1.0,0.75,0.6)),RuinKit._stone(b,1.0),true,true,[],-1,1.0)
	for i in range(4): b.hang(Vector3(at.x+b.rng.randf_range(-1.5,1.5),0.0,at.z+b.rng.randf_range(-1.5,1.5)),b.rng.randf_range(1.0,3.0),true,at.y-0.4)
	return b.finish()

# --- Platforms (floating stones), the chimney --------------------------------------------

## The stones hovering in the gorge, each a platform walked on a clean, true
## box: {name, at (its top's middle, world), size (along, thick, across),
## yaw, kind ("voussoir", "block"), chain}.
##   crown_1, crown_2: the arch's crown stones hanging in the gap beside the
##   rope bridge, rising west to east: twirled jumps from deck end to deck end
##   (the expert's crossing).
##   mist: a torn-up block by the curtain, off the lower ledge's north end.
static var _platforms: Array = []
static func platforms() -> Array:
	if not _platforms.is_empty(): return _platforms
	var ends := rope_ends()
	var w_end := west_bridge_frame()*Vector3(WEST_BREAK-0.3,DECK_LIFT,DECK_HALF-0.4)
	var e_end := east_bridge_frame()*Vector3(EAST_BREAK-0.3,DECK_LIFT,-(DECK_HALF-0.4))
	var out: Array = []
	var c1 := w_end.lerp(e_end,0.34)
	var c2 := w_end.lerp(e_end,0.68)
	out.append({"name":"crown_1","at":Vector3(c1.x,w_end.y+0.55,Z_BR+3.1),"size":Vector3(1.5,0.75,1.25),"yaw":0.25,"kind":"voussoir","chain":"crown"})
	out.append({"name":"crown_2","at":Vector3(c2.x,w_end.y+1.25,Z_BR+3.4),"size":Vector3(1.5,0.75,1.25),"yaw":-0.3,"kind":"voussoir","chain":"crown"})
	var l2_north := Vector2(lip_at(WEST_LIP,-49.0)+1.6,-49.0)
	out.append({"name":"mist","at":Vector3(l2_north.x+1.4,plane_w(l2_north.x)-2.0*FLIGHT+0.55,-51.6),"size":Vector3(1.7,0.75,1.5),"yaw":0.5,"kind":"block","chain":"mist"})
	_platforms = out
	return out

static func platform(name: String) -> Dictionary:
	for p: Dictionary in platforms():
		if p.name == name: return p
	return {}

## The floating stones, drawn worn and walked on clean boxes (as the
## aqueduct isle's).
static func floating_stones(seed_value: int) -> Node3D:
	var b := Build.new(seed_value,0.55,"FloatingStones")
	for p: Dictionary in platforms():
		var size: Vector3 = p.size
		var half := size*0.5
		var at: Vector3 = p.at
		var pose := Transform3D(Basis(Vector3.UP,float(p.yaw)),at-Vector3(0.0,half.y,0.0))
		var voussoir: bool = p.kind == "voussoir"
		b.lean = true
		var planes := RuinKit._box(b,half,0.05)
		if voussoir:
			# Cut as a voussoir: its sides drawn in toward the arch's middle.
			for s: float in [-1.0,1.0]:
				var nn := Vector3(s,-0.22,0.0).normalized()
				planes.append(Plane(nn,nn.dot(Vector3(s*half.x,0.0,0.0))))
		b.solid(planes,pose,RuinKit._stone(b,1.06),false,true,[],-1,1.0)
		b.lean = false
		RuinKit._walk_hull(b,pose,[Plane(Vector3.RIGHT,half.x),Plane(Vector3.LEFT,half.x),Plane(Vector3.UP,half.y),Plane(Vector3.DOWN,half.y),Plane(Vector3.BACK,half.z),Plane(Vector3.FORWARD,half.z)])
		if p.kind == "block":
			var deep := b.rng.randf_range(0.9,1.4)
			var clod := RuinKit._prism(5,0.12,minf(half.x,half.z)*0.95,-half.y-deep,-half.y+0.02,b.rng.randf()*TAU)
			b.solid(clod,pose,AqArt.EARTH.lerp(AqArt.ROCK,0.4)*b.rng.randf_range(0.85,1.05),false,true,[],-1,1.6,false)
			for i in range(3): AqArt._tuft(b,pose*Vector3(b.rng.randf_range(-half.x,half.x)*0.8,half.y,b.rng.randf_range(-half.z,half.z)*0.8),0.3,4)
		for i in range(2): b.hang(pose*Vector3(b.rng.randf_range(-half.x,half.x)*0.7,0.0,b.rng.randf_range(-half.z,half.z)*0.7),b.rng.randf_range(0.6,1.6),true,at.y-size.y)
	return b.finish()

## The split pillar on the east landing: two slabs of the wall's rock, a
## slot CHIMNEY wide between them across x (kicks climb it), the inner one
## standing to the east top's height (stepped off onto it), the outer
## lower. [x from, x to, top (world y)] each, over CHIMNEY_Z (z from, to).
const CHIMNEY_Z := Vector2(-50.7,-48.7)
static func chimney() -> Array:
	var lip := lip_at(EAST_LIP,-49.7)
	var land := E_TOP-2.0*FLIGHT
	var inner := [lip-1.25,lip+0.05,E_TOP+0.35]
	var outer := [lip-3.3,lip-2.35,E_TOP+1.3]
	return [outer,inner,land]

## The chimney's slabs: drawn as faceted rock, walked and kicked on clean
## boxes; `parts` [rect (world x, z), bottom, top].
static func chimney_slabs(seed_value: int) -> Dictionary:
	var b := Build.new(seed_value,0.5,"Chimney")
	var parts: Array = []
	var spec := chimney()
	var land: float = spec[2]
	for k in range(2):
		var s: Array = spec[k]
		var x0: float = s[0]
		var x1: float = s[1]
		var top: float = s[2]
		var bottom := land-1.5
		var r := Rect2(x0,CHIMNEY_Z.x,x1-x0,CHIMNEY_Z.y-CHIMNEY_Z.x)
		parts.append([r,bottom,top])
		# The slab in two or three stacked blocks of rock, their faces facets.
		var y := bottom
		while y < top-0.05:
			var h := minf(top-y,b.rng.randf_range(1.4,2.2))
			if top-(y+h) < 0.5: h = top-y
			var half := Vector3((x1-x0)*0.5,h*0.5,(CHIMNEY_Z.y-CHIMNEY_Z.x)*0.5)
			b.solid(RuinKit._box(b,half,0.1),Transform3D(Basis.IDENTITY,Vector3((x0+x1)*0.5,y+h*0.5,(CHIMNEY_Z.x+CHIMNEY_Z.y)*0.5)),GORGE_ROCK*b.rng.randf_range(0.85,1.0),false,true,[],-1,2.0,true)
			y += h
	var node := b.finish()
	node.get_node("Body").free()
	return {"node":node,"parts":parts}

# --- Boulders ----------------------------------------------------------------------

## Boulders fallen at the tors' feet and along the lips (colliding as laid),
## off the paths.
const BOULDERS := 26
static func boulders(seed_value: int) -> Node3D:
	var b := Build.new(seed_value,0.5,"Boulders")
	var placed := 0
	for attempt in range(600):
		if placed >= BOULDERS: break
		var spec: Array = WEST_TOR if b.rng.randf() < 0.55 else EAST_TOR
		var c: Vector2 = spec[0]
		var a := b.rng.randf()*TAU
		var r := float(spec[2])+b.rng.randf_range(1.2,3.2)
		var p := c+Vector2(cos(a),-sin(a))*r
		var t := fposmod(rad_to_deg(a),360.0)
		if absf(wrapf(t-float(spec[3]),-180.0,180.0)) < float(spec[4])+8.0: continue
		if path_wear(p) > 0.05: continue
		var y := ground(p.x,p.y)
		var steep := false
		for d: Vector2 in [Vector2(1.0,0.0),Vector2(-1.0,0.0),Vector2(0.0,1.0),Vector2(0.0,-1.0)]:
			if absf(ground(p.x+d.x,p.y+d.y)-y) > 0.35: steep = true
		if steep: continue
		var s := Vector3(b.rng.randf_range(0.35,0.8),b.rng.randf_range(0.3,0.65),b.rng.randf_range(0.35,0.75))
		var tumble := Basis(Vector3.UP,b.rng.randf()*TAU)*Basis(Vector3.RIGHT,b.rng.randf_range(-0.3,0.3))
		b.solid(RuinKit._box(b,s,0.12),Transform3D(tumble,Vector3(p.x,y+s.y*0.6,p.y)),AqArt.ROCK*b.rng.randf_range(0.85,1.05),true,true,[],-1,2.2,false)
		placed += 1
	return b.finish()

# --- The ways (for the test and the doc) -----------------------------------------------

## The start: on the road west of the gate, facing the bridge.
static func start() -> Vector3:
	return Vector3(64.0,plane_w(64.0),-15.0)

## A kit flight's frame (world): `spec` from FLIGHTS; its foot on the ledge
## (its frame's origin there), climbing south; on the west's tilt.
static func flight_frame(spec: Array) -> Transform3D:
	var z_mid := (float(spec[1])+float(spec[2]))*0.5
	var x := lip_at(WEST_LIP,z_mid)+1.6
	return frame_w(x,z_mid,float(spec[3]),PI)
