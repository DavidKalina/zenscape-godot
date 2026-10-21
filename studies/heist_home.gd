extends Node3D
## Home (docs/design/home-isle/handoff.md): the heist level's own landmass
## far out in its sky, where the run starts and the loot is banked
## (studies/heist_level.gd). Built under the heist scene as its node "Home":
##   land       a sea-cliff tableland of the lower world's (scripts/
##              landform_cliffs.gd's recipe, scripts/sea_cliffs.gd's layered
##              walls, stacks and arch) hung in the sky with its rock under
##              it, TABLE_R m round; a strip of its top levelled STRIP m
##              long for the plane (`strip`), the plane parked at its end
##   lake       a lake dug in the tableland itself (scripts/islet_lake.gd
##              `basin`, landform_lake.gd's lake recipe), sought near a rim
##              and clear of the strip, its banks coming down to a beach and
##              a reed shelf; its water the kit isles' still sheet (scripts/
##              kit_isle/kit_water.gd), swum (the walker's pool, `pool`) and
##              skimmed by the plane (WATER_LAYER), never landed on (its bed
##              no turf); it spills through a notch in the layered cliff as
##              a fall into the open sky (SkyIslets `_fall` in the live falls'
##              painted look, its thread down to the cloud sea)
##   landmarks  LANDMARKS crag rocks (scripts/kit_isle/islet_unit_node.gd,
##              each with a ruin on top), some between home and the heist
##              isle, the rest round each
##   cues       a column seen from far (shaders/home_cue.gdshader, no fog):
##              the fall's spray hanging under home, a smoke column over the
##              heist's vault, each drawn out to CUE_FAR m
##   haze       depth fog (Environment FOG_MODE_DEPTH, the sky's own colour)
##              from HAZE.x m to HAZE.y m: land past HAZE.y is gone, so
##              neither isle shows from the other.
## Home stands FAR m from the heist isle's middle, its bearing from it
## drawn from the hunt's seed (a new one each run unless --hunt-seed=).
## Pieces are named `home/land`, `home/lake`, `home/landmark_<n>`,
## `home/cue_home`, `home/cue_heist` (scripts/layout_overrides.gd).
##   --home-far=<m>       how far (FAR)
##   --hunt-seed=<n>      the bearing's and the landmarks' seed
##   --haze=<from>,<to>   the haze's range (m); --no-haze none
##   --cue-far=<m>        how far the cues draw

const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyIslet = preload("res://scripts/sky_islet.gd")
const SeaCliffs = preload("res://scripts/sea_cliffs.gd")
const LandformLake = preload("res://scripts/landform_lake.gd")
const LineBuild = preload("res://scripts/hall_line_build.gd")
const KitLook = preload("res://scripts/kit_isle/kit_look.gd")
const Layout = preload("res://scripts/layout_overrides.gd")
const UnitNode = preload("res://scripts/kit_isle/islet_unit_node.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const IsletLake = preload("res://scripts/islet_lake.gd")
const KitWater = preload("res://scripts/kit_isle/kit_water.gd")

## The heist isle's middle (x, z; world) home is placed round, and how far.
const HEIST_MID := Vector2(110.0,10.0)
const FAR := 1800.0
## The haze: clear to HAZE.x m, gone at HAZE.y m.
const HAZE := Vector2(380.0,760.0)
const HAZE_CURVE := 1.2
## How much of the haze's colour is the sky's radiance (Environment
## `fog_aerial_perspective`) over the sky's own haze colour (`tint_haze`),
## and that colour's scale.
const AERIAL := 0.0
const HAZE_TINT := Color(0.55,0.69,0.84)
## The cues draw to this far (m), fading over the last CUE_FADE of it.
const CUE_FAR := 1500.0
const CUE_FADE := 0.25
## The tableland: its radius (m), its cliff's height over the islet's foot
## line (m, the high side), the low side's share, its grid step (m), the
## stacks round it, the beds' unit (m).
const TABLE_R := 90.0
const TABLE_H := 48.0
const TABLE_LOW := 0.72
const TABLE_STEP := 2.0
const TABLE_STACKS := 3
const TABLE_BED := 2.0
const TABLE_SEED := 9101
## The strip: its length (m, at most; short of the rim by STRIP_RIM m each
## end), half width (m), the fade back to the land (m), and how far it lies
## off the tableland's middle line toward the low side (share of the radius).
const STRIP := 150.0
const STRIP_HALF := 10.0
const STRIP_FADE := 10.0
const STRIP_RIM := 6.0
const STRIP_OFF := 0.12
## The strip's top stands this far (m) over the scene's TOP.
const LIFT := 0.0
## The parked plane: this far (m) in from the strip's end; he starts beside
## it, START_SIDE m off its line, START_BACK m behind its middle.
const PARK_IN := 14.0
const START_SIDE := 5.0
const START_BACK := 3.0
## The lake: a basin dug in the tableland (scripts/islet_lake.gd `basin`),
## sought where it fits nearest a rim (leaning to the low side, first tried
## LAKE_AT of the radius out that way), its land LAKE_KEEP m clear of the
## strip's fade; LAKE_R m across its short way, LAKE_LONG times that along the
## contours; the land round it coming down over LAKE_SLOPE m to its beach,
## its level LAKE_UNDER m under the lowest land round it; a bank LAKE_BANK
## m wide kept to the cliff's brink, but where it spills off the rim as a
## fall LAKE_FALL m wide. Its water is the kit isles' still sheet
## (scripts/kit_isle/kit_water.gd), LAKE_CELL m a cell.
const LAKE_AT := 0.58
const LAKE_KEEP := 2.0
const LAKE_R := 17.0
const LAKE_LONG := 1.75
const LAKE_SLOPE := 13.0
const LAKE_UNDER := 0.9
const LAKE_BANK := Vector2(7.0,10.0)
const LAKE_FALL := 3.2
const LAKE_CELL := 0.5
## The fall's veil (shaders/flow_fall.gdshader: 0 a whole curtain, 1 a
## trickle torn into streaks).
const FALL_VEIL := 0.35
## Home's circle (the clouds keep off it, banking counts in it) runs this
## far (m) past the tableland's reach.
const CIRCLE_PAST := 84.0
## The plane finds no turf on what lies under the water (nor this far over
## it): the lake bed is rock to it.
const LAKE_DRY := 0.05
## The landmarks: how many on the way (share along home -> heist, sideways
## off the line, m) and round each isle (distance range, m), their size
## range (m) and height off TOP (m); none within KEEP m of another.
const WAY := [Vector2(0.24,-170.0),Vector2(0.5,150.0),Vector2(0.76,-120.0)]
const WAY_JITTER := 90.0
const ROUND := 3
const ROUND_AT := Vector2(420.0,700.0)
const LANDMARK_SIZE := Vector2(9.0,17.0)
const LANDMARK_LIFT := Vector2(-35.0,45.0)
const KEEP := 260.0
## The cues: [name, colour, width at its foot, width at its far end, length
## (m), up (+1 rises, -1 hangs down)].
const SMOKE := [Color(0.34,0.31,0.29,0.85),10.0,70.0,260.0,1.0]
const SPRAY := [Color(0.93,0.95,0.97,0.8),26.0,60.0,300.0,-1.0]
## The heist's smoke rises from over the vault's court.
const SMOKE_AT := Vector3(190.0,26.0,2.0)

const TURF_LAYER := 1 << 11
## The lake's surface: the plane skims it (studies/heist_level.gd
## `plane_ground`), the walker's rays never see it.
const WATER_LAYER := 1 << 12

var host: Node3D
var far := FAR
var hunt_seed := 0
var haze := HAZE
var haze_on := true
var cue_far := CUE_FAR
## Home's coded middle (world; the tableland's middle, y its strip's top)
## and its yaw.
var middle := Vector3.ZERO
var bearing := 0.0
## The tableland and lake nodes (each a SkyIslets stand), as placed.
var land: Node3D = null
var lake: Node3D = null
## The strip (world, as placed): its ends, at its top.
var strip_a := Vector3.ZERO
var strip_b := Vector3.ZERO
## The circle round home (x, z, reach).
var circle := Vector3.ZERO
var landmarks: Array = []
var cues: Array = []
var islets: Node3D = null
var built_ms := 0
## The tableland's shape (its lake in it), the lake's box (the land's
## frame) and home/lake's coded spot.
var land_shape: RefCounted = null
var pool_rect := Rect2()
var _lake_coded := Transform3D.IDENTITY
## The strip in the tableland's frame (x, z): its ends; its top there.
var _strip_local := [Vector2.ZERO,Vector2.ZERO]
var _strip_y := 0.0

func _init() -> void:
	name = "Home"

## The knobs off the launch flags; the seed drawn if none.
func read_flags() -> void:
	var seeded := false
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--home-far="): far = maxf(float(a.get_slice("=",1)),300.0)
		elif a.begins_with("--hunt-seed="):
			hunt_seed = int(a.get_slice("=",1))
			seeded = true
		elif a.begins_with("--haze="):
			var p := a.get_slice("=",1).split(",")
			if p.size() >= 2: haze = Vector2(float(p[0]),float(p[1]))
		elif a == "--no-haze": haze_on = false
		elif a.begins_with("--cue-far="): cue_far = float(a.get_slice("=",1))
	if not seeded:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		hunt_seed = rng.randi_range(1,99999)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["hunt",hunt_seed])
	bearing = rng.randf()*TAU
	middle = Vector3(HEIST_MID.x+cos(bearing)*far,0.0,HEIST_MID.y+sin(bearing)*far)
	print("home: hunt seed %d, home %.0f m off the heist isle at bearing %.0f deg (%s)" % [hunt_seed,far,rad_to_deg(bearing),middle.round()])

## Builds it all under `h` (the heist level; its TOP the strip's height):
## the land and the lake (made on workers at once), the landmarks, the
## cues. Before the heist's own land, so the plane's spot is there.
func build(h: Node3D, top: float) -> void:
	host = h
	var began := Time.get_ticks_msec()
	middle.y = top+LIFT
	islets = SkyIslets.new()
	islets.name = "Islets"
	islets.ground_source = LineBuild.evergreen(KitLook.ground_material())
	add_child(islets)
	var palette: Dictionary = islets.prepare_authored()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["home",hunt_seed])
	var tilt := rng.randf()*TAU
	var t := Vector2.from_angle(tilt)
	# The tableland with its lake in its low side; its strip levelled.
	var lrng := RandomNumberGenerator.new()
	lrng.seed = hash(["home_lake",hunt_seed])
	var table_at := Vector3(middle.x,0.0,middle.z)
	var table_spec := _table_spec(rng,tilt)
	var lake_spec := _lake_spec(lrng,t,table_at)
	if not lake_spec.is_empty(): table_spec.lake = lake_spec
	var shape: RefCounted = SkyIslet.author(TABLE_SEED+hunt_seed,table_spec)
	_level_strip(shape,t)
	var made := SkyIslets.dress(shape,palette,middle.y-_strip_y)
	table_at.y = middle.y-_strip_y
	land = _stand_islet("home/land","Land",table_at,made)
	if land != null:
		var xf := land.global_transform
		strip_a = xf*Vector3(_strip_local[0].x,_strip_y,_strip_local[0].y)
		strip_b = xf*Vector3(_strip_local[1].x,_strip_y,_strip_local[1].y)
		circle = Vector3(land.global_position.x,land.global_position.z,float(shape.reach)+CIRCLE_PAST)
		if not lake_spec.is_empty(): _lay_lake(shape,table_at)
	land_shape = shape
	_landmarks(top)
	_cues(shape)
	built_ms = Time.get_ticks_msec()-began
	print("home: built in %d ms; strip %s -> %s (%.0f m), lake at %s" % [built_ms,strip_a.round(),strip_b.round(),strip_a.distance_to(strip_b),(lake.global_position if lake != null else Vector3.INF).round()])

## The lake's recipe (scripts/landform_lake.gd's lake, set in a basin of
## the tableland toward `-t`, its low side), {} if home/lake is deleted.
## The basin's middle is home/lake's (layout_overrides: moved in the world
## view, it is dug there on the next load).
func _lake_spec(lrng: RandomNumberGenerator, t: Vector2, table_at: Vector3) -> Dictionary:
	if Layout.deleted("home/lake"): return {}
	var spec: Dictionary = LandformLake.recipe(lrng,LAKE_R*2.0).lake
	spec.basin = {"middle":-t*TABLE_R*LAKE_AT,"radius":LAKE_R,"slope":LAKE_SLOPE,"under":LAKE_UNDER,"axis":t.orthogonal(),"long":LAKE_LONG,
		"keep":{"point":-t*TABLE_R*STRIP_OFF,"axis":t.orthogonal(),"clear":STRIP_HALF+STRIP_FADE+LAKE_KEEP}}
	# Moved in the world view: dug where it was put (its middle, in the
	# land's coded frame), not sought.
	var moved: Dictionary = Layout.data.get("moved",{})
	if moved.has("home/lake"):
		var at := Layout.xform("home/lake",Transform3D.IDENTITY).origin-table_at
		spec.basin.middle = Vector2(at.x,at.z)
		spec.basin.erase("keep")
	spec.bank = LAKE_BANK
	spec.toward = -t
	spec.fall = LAKE_FALL
	spec.channel = LAKE_FALL*1.2
	spec.swim = true
	spec.beach = 3.5
	spec.shelf = Vector2(2.2,3.2)
	spec.depth = Vector2(3.2,4.2)
	spec.reeds = 3.5
	spec.isle = 0.4
	spec.isle_radius = Vector2(2.5,3.6)
	spec.copses = Vector2i.ZERO
	spec.erase("tea")
	return spec

## The lake's water: the kit isles' still sheet over the basin (the islet's
## own pond, drawn in the islets' plain pond look, taken off), held by a
## node at the basin's middle named home/lake.
func _lay_lake(shape: RefCounted, table_at: Vector3) -> void:
	var pond := land.get_node_or_null("Pond")
	if pond != null: pond.queue_free()
	# The fall in the live falls' painted look (scripts/flow_falls.gd):
	# streak columns sliding down it, not a plain white sheet.
	var fall := land.get_node_or_null("Fall") as GeometryInstance3D
	if fall != null and fall.material_override is ShaderMaterial:
		var m := fall.material_override as ShaderMaterial
		m.set_shader_parameter("painterly",true)
		m.set_shader_parameter("veil",FALL_VEIL)
	var lake_d: Dictionary = shape.lake
	if lake_d.is_empty(): return
	var basin: Dictionary = lake_d.basin
	var mid: Vector2 = basin.middle
	var level: float = shape.water_level
	_lake_coded = Transform3D(Basis.IDENTITY,table_at+Vector3(mid.x,level,mid.y))
	var half := float(basin.radius)*(1.0+IsletLake.BASIN_WANDER)*float(basin.long)+2.0
	lake = Node3D.new()
	lake.name = "Lake"
	land.add_child(lake)
	lake.position = Vector3(mid.x,level,mid.y)
	var water: Dictionary = shape.water()
	var lip_world := land.global_transform*Vector3(water.lip.x,level,water.lip.y)
	var sheet := KitWater.still({"name":"Water","level":0.0,
		"ground":func(x: float, z: float) -> float: return IsletLake._raw(shape,Vector2(x+mid.x,z+mid.y))-level,
		"rect":Rect2(-half,-half,half*2.0,half*2.0),
		"inside":func(p: Vector2) -> bool: return shape.on_land(p+mid) and IsletLake.in_basin(shape,p+mid),
		"cell":LAKE_CELL,
		"falls":[Vector4(lip_world.x,lip_world.z,LAKE_FALL*1.4,0.8)]})
	lake.add_child(sheet)
	# Its surface: a top the plane skims as it does the turf (on WATER_LAYER,
	# as the cloister tarn's), never stood on; the walker's rays never see it.
	if sheet.mesh != null:
		var surface := ConcavePolygonShape3D.new()
		surface.set_faces(sheet.mesh.get_faces())
		surface.backface_collision = true
		var holder := CollisionShape3D.new()
		holder.shape = surface
		var body := StaticBody3D.new()
		body.name = "Surface"
		body.collision_layer = WATER_LAYER
		body.collision_mask = 0
		body.add_child(holder)
		sheet.add_child(body)
	pool_rect = Rect2(mid.x-half,mid.y-half,half*2.0,half*2.0)
	Layout.track("home/lake",lake,"token",_lake_coded)
	print("home: lake %.0f m2 at level %.1f (%.1f under the strip), %d water cells" % [float(lake_d.area),level,_strip_y-level,int(sheet.get_meta("cells"))])

## The lake as a pool the walker wades and swims (scripts/
## pilot_physics_ground.gd `pools`): its box (world), its top, and where
## in it the water is (the islet's own: under the level, near its field).
func pool() -> Dictionary:
	if lake == null or land_shape == null: return {}
	var xf := land.global_transform
	var lo := xf*Vector3(pool_rect.position.x,0.0,pool_rect.position.y)
	var hi := xf*Vector3(pool_rect.end.x,0.0,pool_rect.end.y)
	var rect := Rect2(Vector2(minf(lo.x,hi.x),minf(lo.z,hi.z)),Vector2(absf(hi.x-lo.x),absf(hi.z-lo.z)))
	var shape: RefCounted = land_shape
	var node := land
	return {"rect":rect,"top":(xf*Vector3(0.0,float(shape.water_level),0.0)).y,
		"inside":func(p: Vector2) -> bool:
			var l: Vector3 = node.global_transform.affine_inverse()*Vector3(p.x,0.0,p.y)
			return IsletLake.distance(shape,Vector2(l.x,l.z)) < 1.0}

## The tableland's recipe (scripts/landform_cliffs.gd's, grown).
func _table_spec(rng: RandomNumberGenerator, tilt: float) -> Dictionary:
	var palettes := ["basalt_warm","basalt","slate"]
	return {"kind":"hills","radius":TABLE_R,"step":TABLE_STEP,
		"room":SeaCliffs.GAP.y+SeaCliffs.STACK.y*2.6,
		"cliffs":{"height":TABLE_H,"low":TABLE_LOW,"tilt":tilt,"bed":TABLE_BED,"stacks":TABLE_STACKS,"arch":true,"cove":false},
		"mounds":[],"dome":0.4,"keel":1.0,
		"trees":Vector2i(10,16),"tree_pool":{"juniper":1.0,"tree":0.6,"birch":0.35},"drifts":Vector2i(6,10),"undergrowth":0.6,
		"rock":{"palette":palettes[rng.randi() % palettes.size()],"tone":rng.randf_range(0.8,0.92),"vary":rng.randf(),"bed":TABLE_BED}}

## The strip levelled across the tableland, square to its tilt (along the
## contours), STRIP_OFF of the radius toward the low side; its plants kept
## off. Its ends and top go in `_strip_local`, `_strip_y`.
func _level_strip(shape: RefCounted, t: Vector2) -> void:
	var along := t.orthogonal()
	var mid := -t*TABLE_R*STRIP_OFF
	var ra: Vector2 = shape.rim_point(atan2(along.y,along.x))
	var rb: Vector2 = shape.rim_point(atan2(-along.y,-along.x))
	var half := minf(STRIP*0.5,minf(ra.length(),rb.length())-STRIP_RIM-STRIP_FADE)
	var a := mid-along*half
	var b := mid+along*half
	var points: PackedVector2Array = shape.points
	var heights: PackedFloat32Array = shape.heights
	var dist: PackedFloat32Array = shape.shore_distance
	var sum := 0.0
	var n := 0
	for i in range(points.size()):
		if dist[i] < 0.0: continue
		if _to_segment(points[i],a,b) < STRIP_HALF:
			sum += heights[i]
			n += 1
	var level := sum/maxf(n,1)
	for i in range(points.size()):
		if dist[i] < 0.0: continue
		var k := 1.0-smoothstep(STRIP_HALF,STRIP_HALF+STRIP_FADE,_to_segment(points[i],a,b))
		if k > 0.0: heights[i] = lerpf(heights[i],level,k)
	shape.heights = heights
	var clear: Array = (shape.recipe.get("clear",[]) as Array).duplicate()
	var steps := int(ceil(half*2.0/STRIP_HALF))
	for s in range(steps+1):
		var p := a.lerp(b,float(s)/steps)
		clear.append(Vector3(p.x,p.y,STRIP_HALF+STRIP_FADE*0.5))
	shape.recipe.clear = clear
	_strip_local = [a,b]
	_strip_y = level
	print("home: strip %.0f m levelled at %.1f over %d points" % [half*2.0,level,n])

static func _to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b-a
	var k := clampf((p-a).dot(ab)/maxf(ab.length_squared(),0.001),0.0,1.0)
	return p.distance_to(a+ab*k)

## An islet `made` stood at `at` as `name_` (kind "piece"), solid: its top
## the turf (TURF_LAYER), its rock and walls the rock (layer 1), as
## trimesh bodies cut by tile (scripts/hall_line_build.gd `_cut`).
func _stand_islet(name_: String, node_name: String, at: Vector3, made: Dictionary) -> Node3D:
	if Layout.deleted(name_): return null
	var b: Dictionary = islets.stand(node_name,Vector3.ZERO,made,self)
	var node: Node3D = b.node
	var coded := Transform3D(Basis.IDENTITY,at)
	# Placed before its bodies go in, so none stands a frame at the origin.
	node.transform = Layout.xform(name_,coded)
	# A lake's bed (under its level, LAKE_DRY) is no turf: rock to the
	# plane, ground to the walker.
	var islet: RefCounted = made.shape
	var wet_under := float(islet.water_level)+LAKE_DRY if not (islet.lake as Dictionary).is_empty() else -INF
	for part: String in ["top","bed","sides"]:
		var faces := _split_wet(LineBuild._faces(made.top,-SkyIslets.OFF_MAP),islet,wet_under,part == "bed") if part != "sides" else LineBuild._faces(made.sides,Vector3.ZERO)
		if faces.is_empty(): continue
		var k := 0
		for cut: PackedVector3Array in LineBuild._cut(faces):
			var shape := ConcavePolygonShape3D.new()
			shape.set_faces(cut)
			shape.backface_collision = true
			var holder := CollisionShape3D.new()
			holder.shape = shape
			var body := StaticBody3D.new()
			body.name = "%s%d" % [part.capitalize(),k]
			body.collision_layer = 1|(TURF_LAYER if part == "top" else 0)
			body.collision_mask = 0
			body.add_child(holder)
			node.add_child(body)
			k += 1
			if part == "top": host.call("home_turf",body)
	Layout.track(name_,node,"piece",coded)
	return node

## The faces (triangles) of `faces` in `islet`'s lake (any corner under
## `under`, by its water) with `wet`, else the rest.
static func _split_wet(faces: PackedVector3Array, islet: RefCounted, under: float, wet: bool) -> PackedVector3Array:
	if under == -INF: return faces if not wet else PackedVector3Array()
	var out := PackedVector3Array()
	for i in range(0,faces.size(),3):
		var m := (faces[i]+faces[i+1]+faces[i+2])/3.0
		var low := minf(faces[i].y,minf(faces[i+1].y,faces[i+2].y)) < under and IsletLake.distance(islet,Vector2(m.x,m.z)) < 2.0
		if low == wet: out.append_array([faces[i],faces[i+1],faces[i+2]])
	return out

## The landmarks (WAY on the line, ROUND round each isle), each a crag rock
## with a ruin on its top, named home/landmark_<n>; through the host's own
## unit stand (crag_reach.gd `_stand`).
func _landmarks(top: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["landmarks",hunt_seed])
	var from := Vector2(middle.x,middle.z)
	var to := HEIST_MID
	var line := to-from
	var side := line.normalized().orthogonal()
	var spots: Array[Vector2] = []
	for w: Vector2 in WAY:
		var p := from+line*w.x+side*(w.y*signf(rng.randf()-0.5))
		p += Vector2(rng.randf_range(-1.0,1.0),rng.randf_range(-1.0,1.0))*WAY_JITTER
		spots.append(p)
	for c: Vector2 in [from,to]:
		var placed := 0
		var tries := 0
		while placed < ROUND and tries < 60:
			tries += 1
			var a := rng.randf()*TAU
			var p := c+Vector2.from_angle(a)*rng.randf_range(ROUND_AT.x,ROUND_AT.y)
			var ok := true
			for q: Vector2 in spots:
				if q.distance_to(p) < KEEP: ok = false
			if not ok: continue
			spots.append(p)
			placed += 1
	var i := 0
	for p: Vector2 in spots:
		i += 1
		var size := rng.randf_range(LANDMARK_SIZE.x,LANDMARK_SIZE.y)
		var spec := {"seed":700+i+hunt_seed % 97,"size":size,"shape":rng.randf_range(0.5,0.95),"lean":rng.randf()*0.5,"drip":rng.randf_range(0.4,0.9),
			"lopsided":rng.randf(),"growth":rng.randf_range(0.5,0.8),"weather":rng.randf_range(0.4,0.8),"flat":rng.randf_range(0.3,0.7),
			"landmark":0,"grass":0.0,"debris":0.1,"mass":1 if size > 14.0 else 0}
		var at := Vector3(p.x,top+rng.randf_range(LANDMARK_LIFT.x,LANDMARK_LIFT.y),p.y)
		var n: Node3D = host.call("_stand","home/landmark_%d" % i,Transform3D(Basis(Vector3.UP,rng.randf()*TAU),at),spec)
		if n != null: landmarks.append(n)
	print("home: %d landmarks" % landmarks.size())

## The cues: the spray under home's fall, the smoke over the heist's vault.
func _cues(shape: RefCounted) -> void:
	var water: Dictionary = shape.water() if not (shape.lake as Dictionary).is_empty() else {}
	if land != null and not water.is_empty():
		var lip := land.global_transform*Vector3(float((water.lip as Vector2).x),float(water.level),float((water.lip as Vector2).y))
		var out := Vector3(float((water.out as Vector2).x),0.0,float((water.out as Vector2).y))
		_cue("home/cue_home","CueHome",lip+out*4.0+Vector3.DOWN*6.0,SPRAY)
	_cue("home/cue_heist","CueHeist",SMOKE_AT,SMOKE)

func _cue(name_: String, node_name: String, at: Vector3, look: Array) -> void:
	if Layout.deleted(name_): return
	var quad := QuadMesh.new()
	var length := float(look[3])
	var wide := maxf(float(look[1]),float(look[2]))
	quad.size = Vector2(wide,length)
	# Its foot at the node: up the quad for a rising column, down for one
	# hanging.
	quad.center_offset = Vector3(0.0,length*0.5*float(look[4]),0.0)
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/home_cue.gdshader")
	m.set_shader_parameter("tint",look[0])
	m.set_shader_parameter("foot",float(look[1])/wide)
	m.set_shader_parameter("end",float(look[2])/wide)
	m.set_shader_parameter("up",float(look[4]))
	m.set_shader_parameter("far",cue_far)
	m.set_shader_parameter("fade",cue_far*CUE_FADE)
	m.set_shader_parameter("seed",float(hash(name_) % 1000)*0.13)
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = quad
	node.material_override = m
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = length
	node.set_meta("skip_reflection",true)
	add_child(node)
	var coded := Transform3D(Basis.IDENTITY,at)
	node.transform = Layout.xform(name_,coded)
	Layout.track(name_,node,"token",coded)
	cues.append(node)

## The haze on `env`: depth fog in the sky's own colour from haze.x to
## haze.y m, the sky itself left clear.
func apply_haze(env: Environment) -> void:
	if env == null or not haze_on: return
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_density = 1.0
	env.fog_depth_begin = haze.x
	env.fog_depth_end = haze.y
	env.fog_depth_curve = HAZE_CURVE
	env.fog_aerial_perspective = AERIAL
	env.fog_sky_affect = 0.0
	env.fog_height_density = 0.0
	env.fog_sun_scatter = 0.0

## The haze's colour each frame: the sky's own haze (studies/celestial.gd
## `surface_fog_color`, what the screen air draws), so far land fades into
## the horizon behind it as the day turns.
func tint_haze(env: Environment, celestial: RefCounted) -> void:
	if env == null or not haze_on or celestial == null: return
	var c: Vector3 = celestial.get("surface_fog_color")
	env.fog_light_color = Color(c.x,c.y,c.z)*HAZE_TINT

## Past the haze (HAZE.y and RANGE_PAST m on, from each mesh's middle)
## nothing under `tops` is drawn: the haze's colour is the sky's only
## nearly, so a far isle would still show as a faint shape. The cues keep
## their own range. Returns how many meshes it ranged.
const RANGE_PAST := 150.0
func range_out(tops: Array) -> int:
	if not haze_on: return 0
	var n := 0
	for top: Node in tops:
		if top == null: continue
		for g: Node in top.find_children("*","GeometryInstance3D",true,false):
			if g in cues: continue
			var gi := g as GeometryInstance3D
			if gi.visibility_range_end > 0.0 and gi.visibility_range_end < haze.y+RANGE_PAST: continue
			gi.visibility_range_end = haze.y+RANGE_PAST
			n += 1
	return n

## True for a point over home (within its circle, flat).
func over(p: Vector3) -> bool:
	return Vector2(p.x-circle.x,p.z-circle.y).length() < circle.z

## The plane's parked spot at home: (x, y, z) on the strip PARK_IN m in
## from its end, w its heading down the strip.
func plane_spot() -> Vector4:
	var way := strip_b-strip_a
	way.y = 0.0
	way = way.normalized()
	var at := strip_a+way*PARK_IN
	return Vector4(at.x,at.y,at.z,atan2(-way.x,-way.z))

## Where he starts: beside the parked plane, facing down the strip.
func start_spot() -> Array:
	var spot := plane_spot()
	var way := Vector3(-sin(spot.w),0.0,-cos(spot.w))
	var side := way.cross(Vector3.UP)
	var at := Vector3(spot.x,spot.y+1.5,spot.z)+side*START_SIDE-way*START_BACK
	return [at,Vector2(way.x,way.z)]
