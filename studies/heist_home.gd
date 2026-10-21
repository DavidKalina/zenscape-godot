extends Node3D
## Home (docs/design/home-isle/handoff.md): the heist level's own landmass
## far out in its sky, where the run starts and the loot is banked
## (studies/heist_level.gd). Built under the heist scene as its node "Home":
##   land       a sea-cliff tableland of the lower world's (scripts/
##              landform_cliffs.gd's recipe, scripts/sea_cliffs.gd's layered
##              walls, stacks and arch) hung in the sky with its rock under
##              it, TABLE_R m round; a strip of its top levelled STRIP m
##              long for the plane (`strip`), the plane parked at its end
##   lake       a lake islet (scripts/landform_lake.gd's recipe, scripts/
##              islet_lake.gd's bowl) set against the tableland's low side,
##              its rim at the tableland's edge, spilling off its far rim as
##              a fall into the open sky (SkyIslets `_fall`, its thread down
##              to the cloud sea)
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
const Carpet = preload("res://studies/aqueduct_isle_flora.gd")

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
## The lake islet: its width (m), how far its rim runs in over the
## tableland's (m), its rim this far (m) under the tableland's edge.
const LAKE_ACROSS := 84.0
const LAKE_OVER := 6.0
const LAKE_UNDER := 0.6
const LAKE_SEED := 9102
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

## The grass (the isles' carpet, studies/aqueduct_isle_flora.gd `carpeted`,
## then `calm`; KitFlora.Grow over home's land and the lake's banks): its
## tufts a square metre as a share of the carpet's, drawn out GRASS_RANGE m
## (the carpet's own is 220: home's top is one big tile field, so near is
## what is paid for). The strip keeps a short mown grass of its own
## (STRIP_TUFTS a square metre, sized STRIP_SIZE of a tuft: no tussocks, no
## wild rim), and the long grass keeps STRIP_CLEAR m off its middle line.
## --no-home-grass leaves it off; --home-grass-range=<m>, --home-grass=<share>.
const GRASS_SHARE := 0.2
const GRASS_RANGE := 70.0
const STRIP_TUFTS := 3.0
const STRIP_SIZE := Vector2(0.3,0.5)
const STRIP_CLEAR := 11.0
## Faces under this (m) over a lake's water are its beach, bare.
const BANK_BARE := 0.35

const TURF_LAYER := 1 << 11

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
	var grassed := not "--no-home-grass" in LaunchArgs.user_args()
	add_child(islets)
	var palette: Dictionary = islets.prepare_authored()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["home",hunt_seed])
	var tilt := rng.randf()*TAU
	var t := Vector2.from_angle(tilt)
	# The tableland first: its strip and its edge on the low side fix the
	# lake's place.
	var table_spec := _table_spec(rng,tilt)
	var shape: RefCounted = SkyIslet.author(TABLE_SEED+hunt_seed,table_spec)
	_level_strip(shape,t)
	var made := SkyIslets.dress(shape,palette,middle.y-_strip_y)
	# Its ground a run of colour under the grass, not a quilt of triangles.
	if grassed: LineBuild._soften_top(made)
	# The lake islet against the low side: its rim over the tableland's edge.
	var edge_a := atan2(-t.y,-t.x)
	var edge: Vector2 = shape.rim_point(edge_a)
	var edge_y: float = shape.ground_at(edge*0.97)
	var lrng := RandomNumberGenerator.new()
	lrng.seed = hash(["home_lake",hunt_seed])
	var lake_spec: Dictionary = LandformLake.recipe(lrng,LAKE_ACROSS)
	(lake_spec.lake as Dictionary).toward = -t
	# The carpet grass (`_grass`) covers the banks, not the old drifts.
	lake_spec.drifts = Vector2i(0,0)
	var lake_shape: RefCounted = SkyIslet.author(LAKE_SEED+hunt_seed,lake_spec)
	var lake_edge: Vector2 = lake_shape.rim_point(atan2(t.y,t.x))
	var lake_off := edge+(-t)*(lake_edge.length()-LAKE_OVER)
	var lake_y := edge_y-SkyIslet.RIM_HEIGHT-LAKE_UNDER
	var lake_made := SkyIslets.dress(lake_shape,palette,middle.y-_strip_y+lake_y)
	if grassed: LineBuild._soften_top(lake_made)
	# Stood, each named.
	var table_at := Vector3(middle.x,middle.y-_strip_y,middle.z)
	land = _stand_islet("home/land","Land",table_at,made)
	lake = _stand_islet("home/lake","Lake",table_at+Vector3(lake_off.x,lake_y,lake_off.y),lake_made)
	if land != null:
		var xf := land.global_transform
		strip_a = xf*Vector3(_strip_local[0].x,_strip_y,_strip_local[0].y)
		strip_b = xf*Vector3(_strip_local[1].x,_strip_y,_strip_local[1].y)
		circle = Vector3(land.global_position.x,land.global_position.z,float(shape.reach)+LAKE_ACROSS)
	if grassed:
		_grass(land,shape,true)
		_grass(lake,lake_shape,false)
		_ground_calm()
	_landmarks(top)
	_cues(lake_shape)
	built_ms = Time.get_ticks_msec()-began
	print("home: built in %d ms; strip %s -> %s (%.0f m), lake at %s" % [built_ms,strip_a.round(),strip_b.round(),strip_a.distance_to(strip_b),(lake.global_position if lake != null else Vector3.INF).round()])

## The tableland's recipe (scripts/landform_cliffs.gd's, grown).
func _table_spec(rng: RandomNumberGenerator, tilt: float) -> Dictionary:
	var palettes := ["basalt_warm","basalt","slate"]
	return {"kind":"hills","radius":TABLE_R,"step":TABLE_STEP,
		"room":SeaCliffs.GAP.y+SeaCliffs.STACK.y*2.6,
		"cliffs":{"height":TABLE_H,"low":TABLE_LOW,"tilt":tilt,"bed":TABLE_BED,"stacks":TABLE_STACKS,"arch":true,"cove":false},
		"mounds":[],"dome":0.4,"keel":1.0,
		"trees":Vector2i(20,30),"tree_pool":{"juniper":1.0,"tree":0.6,"birch":0.35},"drifts":Vector2i(0,0),"undergrowth":0.6,
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
	for part: String in ["top","sides"]:
		var faces := LineBuild._faces(made[part],-SkyIslets.OFF_MAP if part == "top" else Vector3.ZERO)
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
	if not "--no-home-grass" in LaunchArgs.user_args(): _evergreen_all(node)
	return node

## The carpet grass over `node`'s land (`shape`, in its frame): KitFlora's
## Grow at the aqueduct isle's carpet settings, its probe the shape's own
## ground (no physics): open land off the water, trunks and stones and not
## steeper than the palette's rock slope. On the tableland (`main`) the long
## grass keeps off the strip, which gets its own short grass; the lake's banks
## stay bare of grass below BANK_BARE over the water.
func _grass(node: Node3D, shape: RefCounted, main: bool) -> void:
	if node == null: return
	var began := Time.get_ticks_usec()
	var share := GRASS_SHARE
	var range_m := GRASS_RANGE
	for arg: String in LaunchArgs.user_args():
		if arg.begins_with("--home-grass="): share = float(arg.get_slice("=",1))
		elif arg.begins_with("--home-grass-range="): range_m = float(arg.get_slice("=",1))
	var outline := PackedVector2Array()
	for j in range(160):
		outline.append(shape.rim_point(TAU*j/160.0))
	var steep: float = float(KitLook.palette().rock_slope)*KitFlora.STEEP_SHARE
	var lake_on: bool = not shape.lake.is_empty()
	var water_at: float = shape.water_level+BANK_BARE
	var a := _strip_local[0] as Vector2
	var b := _strip_local[1] as Vector2
	var open := func(p: Vector2, reach: float) -> float:
		if not shape.on_land(p) or shape.blocked(p): return NAN
		var h: float = shape.ground_at(p)
		if lake_on and h < water_at: return NAN
		for off: Vector2 in [Vector2(reach,0.0),Vector2(0.0,-reach)]:
			var q: Vector2 = p+off
			if not shape.on_land(q): return NAN
			if absf(float(shape.ground_at(q))-h)/maxf(reach,0.01) > steep: return NAN
		return h
	var site := KitFlora.Site.new()
	Carpet.carpeted(site)
	site.tufts *= share
	site.grass_range = range_m
	site.probe = func(p: Vector2, reach: float) -> float:
		if main and _to_segment(p,a,b) < STRIP_CLEAR: return NAN
		return open.call(p,reach)
	var job := KitFlora.Grow.new(hash(["home_grass",hunt_seed,main]) & 0xffffff,null,[],[outline],site)
	while not job.step(-1): pass
	var flora: Node3D = job.node
	flora.name = "Flora"
	node.add_child(flora)
	Carpet.calm(flora)
	_evergreen(flora)
	var tris := int(flora.get_meta("triangles",0))
	var long_tris := tris
	if main:
		# The strip's own mown grass.
		var mown := KitFlora.Site.new()
		Carpet.carpeted(mown)
		mown.variety = false
		mown.shag = 0.0
		mown.tuft_bump = 1.0
		mown.height_field = 0.0
		mown.tufts = STRIP_TUFTS
		mown.tuft_size = STRIP_SIZE
		mown.grass_range = range_m
		mown.probe = func(p: Vector2, reach: float) -> float:
			if _to_segment(p,a,b) > STRIP_CLEAR+1.0: return NAN
			return open.call(p,reach)
		var mjob := KitFlora.Grow.new(hash(["home_mown",hunt_seed]) & 0xffffff,null,[],[outline],mown)
		while not mjob.step(-1): pass
		var mf: Node3D = mjob.node
		mf.name = "StripGrass"
		node.add_child(mf)
		Carpet.calm(mf)
		_evergreen(mf)
		tris += int(mf.get_meta("triangles",0))
	print("home: grass on %s: %d instanced triangles (%d without the strip's), %d ms" % [node.name,tris,long_tris,(Time.get_ticks_usec()-began)/1000])

## Home stays summer green whatever the season (as its ground is, and the
## hall line's tufts: LineBuild.evergreen).
func _evergreen(flora: Node3D) -> void:
	for g: Node in flora.get_children():
		if g is GeometryInstance3D:
			var geo := g as GeometryInstance3D
			geo.material_override = LineBuild.evergreen(geo.material_override)

## Every plant batch and every face of the shared ground under `root` in
## summer green (`_evergreen`): home's trees, its units' grass and turf.
func _evergreen_all(root: Node) -> void:
	var ground := KitLook.ground_material()
	for g: Node in root.find_children("*","GeometryInstance3D",true,false):
		if g is MultiMeshInstance3D:
			var m := g as MultiMeshInstance3D
			if m.material_override is ShaderMaterial: m.material_override = LineBuild.evergreen(m.material_override)
		elif g is MeshInstance3D:
			var mi := g as MeshInstance3D
			if mi.mesh != null and mi.mesh.get_surface_count() > 0 and mi.material_override == null and mi.mesh.surface_get_material(0) == ground:
				mi.material_override = LineBuild.evergreen(ground)

## The ground under the grass takes the carpet's calmer settings
## (`Carpet.calm` set them on the shared ground material; home's own is a
## copy, made before).
func _ground_calm() -> void:
	var shared := KitLook.ground_material()
	for k: String in ["ground_dry","ground_patch","ground_mute"]:
		(islets.ground_source as ShaderMaterial).set_shader_parameter(k,shared.get_shader_parameter(k))

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
			"landmark":0,"grass":1.0,"debris":0.1,"mass":1 if size > 14.0 else 0}
		var at := Vector3(p.x,top+rng.randf_range(LANDMARK_LIFT.x,LANDMARK_LIFT.y),p.y)
		var n: Node3D = host.call("_stand","home/landmark_%d" % i,Transform3D(Basis(Vector3.UP,rng.randf()*TAU),at),spec)
		if n != null:
			landmarks.append(n)
			if not "--no-home-grass" in LaunchArgs.user_args(): _evergreen_all(n)
	print("home: %d landmarks" % landmarks.size())

## The cues: the spray under home's fall, the smoke over the heist's vault.
func _cues(lake_shape: RefCounted) -> void:
	var water: Dictionary = lake_shape.water()
	if lake != null and not water.is_empty():
		var lip := lake.global_transform*Vector3(float((water.lip as Vector2).x),float(water.level),float((water.lip as Vector2).y))
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
