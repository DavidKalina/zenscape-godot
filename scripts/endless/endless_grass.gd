extends Node3D
## The endless land's grass carpet (docs/design/endless-flight/grass-round-handoff.md):
## the aqueduct isle's own carpet (studies/aqueduct_isle_flora.gd `carpeted`
## and `calm`: KitFlora's Grow, scripts/kit_isle/kit_flora.gd, drawing the
## game's shader grass tufts, scripts/grass_tuft_mesh.gd, and its meadow
## flowers) grown over the streamed land round the eye, a CELL m square at a
## time, and freed as the eye leaves it.
##
## Each cell grows on a WorkerThreadPool task from the land's own field
## (scripts/endless/land_field.gd), with no physics: its probe reads a 1 m
## height grid of the cell made on the task and interpolated as the land's
## finest chunks draw it (scripts/endless/land_stream.gd), so a tuft stands
## on the drawn turf. Grass grows on open turf only: over the beach
## (BEACH_CLEAR m over the sea), on ground no steeper than SLOPE allows, and
## thinning out over the tundra (ALPINE); none on rock, sand, snow or seabed.
## The tufts are drawn, no collision: the meadows land as before. Each tuft
## takes the painted ground's patches under it (scripts/endless/
## endless_patch.gd) as its instance colour, so the carpet sits in its field.
##
## Two layers of cells, in KitFlora's distance rings (Site `lod`, LOD m from
## the eye). The ring distance (shaders/endless_ring.gdshaderinc, `ring_lead`)
## is measured along the ground, so flying low doesn't put the turf under
## the eye in a band; past FLAT_UP m over the ground the eye's height counts,
## RISE times over (from high up each ring is a smaller disc below, and the
## near carpet is gone a little past where the 3D rings had it). It is led out ahead
## along the view (LEAD): a ring R m out stands R(1+LEAD) ahead and
## R(1-LEAD) behind, as many tufts in it as unled; the cells streamed
## follow the same discs, the ones ahead grown first:
##   near  the isle's carpet with its own tuft material (sway, light,
##         colour), drawn as a finer tuft (FINE, FINE_TUFTS of the isle's
##         density) that reads soft from a plane skimming over it, out to
##         LOD.x, each tuft shrinking into the ground at its own distance by
##         LOD.y; its roots take the painted ground's colour, and the paint
##         under it the tufts' own ground (ROOT_PAINT), so tuft and turf are
##         one surface; a cloud's shadow takes their sun as it takes the
##         turf's (CLOUD_SUN); the wildflowers with it, in drifts (DRIFT),
##         thinning out over FLOWER_FADE.
##   far   FAR_TUFTS a square metre of the cheaper tuft (GrassTuft.build_lite),
##         drawn plainly (shaders/endless_tuft_far.gdshader): each comes up
##         at its own distance over LOD.x..LOD.y as the near ring's go at
##         theirs, at FAR_NEAR (wide, tall) where it comes up, growing
##         slowly to FAR_GROW by LOD.z; thinning out over LOD.z..LOD.w. Its
##         tufts in a drift's colour come up over FLOWER_FADE as the drawn
##         flowers go, the colour on their upper blades.
## Past that the painted ground (shaders/endless_ground.gdshader) alone, which
## takes the carpet's tone and grain past LOD.z (told here), so the tufts
## give way to it with no ring.
##
## The main thread only stands the finished batches (KitFlora's tiles, one
## multimesh a tile and part), within STAND_BUDGET ms a frame.
##
## Flags: --no-grass (none; G turns it off and on in flight), --grass=X (the
## carpet's density, a share of the isle's, 1), --grass-range=M (where the
## far ring ends, LOD.w; the rest of the rings scaled with it),
## --grass-lod=x,y,z,w (the four ring distances), --no-flowers,
## --grass-fine=X (the near ring's FINE tuft at X of the isle's density;
## 0: the isle's own tuft at its own), --grass-patches=X (how much of the
## ground's patches the tufts carry, 1), --grass-set=, --far-set=,
## --ground-set= (name=value: a shader setting, for tuning by hand),
## --flower-drifts=X (how many flower drifts and patches, 1; 0 or
## --no-drifts: round 4's drifts, no wash), --grass-regions=X (how strongly
## the grass's colour regions show, 1; 0 or --no-regions: one palette),
## --grass-lead=X (LEAD, 0.45), --no-grass-lead (no lead: rings round the
## eye), --grass-flat-up=M (FLAT_UP, 20), --grass-ring=3d (round 5's
## rings: 3D from the eye, no lead), --grass-silver=X (the silvery
## undersides the wind flips, SILVER 0.8), --no-grass-silver,
## --grass-slope=a,b (SLOPE), --grass-cover=old (the bare-patches round's
## masks off: none on turf steeper than OLD_SLOPE or HIGH m over the sea).
##
## Look round 5 (docs/design/endless-flight/flowers-colour-handoff.md): the
## grass's colour regions and the flower drifts are endless_patch.gd
## `region` and `bloom`, the same hash as the ground's ep_region and
## ep_bloom, so the tufts' tint, the flowers grown and the painted ground
## agree. Each drift is one kind (its colour), with a few of the meadow's
## own among them; past the flowers' reach the ground (and the far ring's
## tufts, FAR_WASH) take the drift's wash, so it reads from cruise height.

const Field = preload("res://scripts/endless/land_field.gd")
const Carpet = preload("res://studies/aqueduct_isle_flora.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const Patch = preload("res://scripts/endless/endless_patch.gd")

## A cell's side (m; the land's finest chunk), its height grid's border
## (samples past each edge, for the growers' probes round a root).
const CELL := 64.0
const PAD := 4
## The rings (m from the eye): the near carpet out to x, thinned by y; the
## far ring grown in over x..y, out to z, thinned by w. A tuft goes over SOFT m.
const LOD := Vector4(16.0,30.0,150.0,230.0)
const SOFT := 8.0
## The far ring: tufts a square metre (a share of the near carpet's 7.8),
## grown this much (wide, tall) over the near ring's band.
const FAR_TUFTS := 1.8
const FAR_GROW := Vector2(2.0,1.8)
## The grass's height, a multiple of the isles' blade (--grass-tall=X; 1.0:
## the old grass). Height only: the near FINE tuft's mesh, the far ring's
## sizes (FAR_NEAR/FAR_GROW tall) and the near sway's arm scale with it.
const TALL := 4.0
## The flowers' stem lift as a share of the grass's growth (x..y, by a hash
## of where each stands): 1.0 stands level with the extra grass.
const FLOWER_LIFT := Vector2(0.8,1.3)
## A far tuft's size (wide, tall) where it comes up (LOD.x..y): the near
## tuft's look there (as tall; wider, its tufts fewer).
const FAR_NEAR := Vector2(1.5,1.0)
## The rings led ahead along the view: k of the ring's distance (0: none).
## The lead follows the view's level direction at LEAD_RATE (1/s), none
## while looking down steeply (the view's level share LEAD_LEVEL.x..y).
const LEAD := 0.45
const LEAD_RATE := 3.0
const LEAD_LEVEL := Vector2(0.2,0.55)
## The rings are measured along the ground up to this height over it (m);
## past it the height counts, RISE times over (the discs shrink as the eye
## rises: the near tufts gone from FLAT_UP+LOD.y/RISE m up, 39).
const FLAT_UP := 20.0
const RISE := 1.6
## Wildflower drifts in the near carpet (KitFlora Site `flower_drift`): where
## a value noise of DRIFT_SCALE m rises from DRIFT.x to .y, the flowers are
## kept up to DRIFT.z times as often (1 elsewhere), so the meadows have
## patches thick with flowers among the sparse strays.
const DRIFT_SCALE := 55.0
const DRIFT := Vector3(0.68,0.82,6.0)
## Round 5's drifts (endless_patch.gd `bloom`): the flowers kept up to
## BLOOM_PEAK times as often at a drift's heart, its own kind all but
## BLOOM_COMPANION of them (the meadow's own there), from BLOOM_KIND of its
## weight in; up to FAR_WASH of the far ring's tufts are in its colour
## (the ground's painted heads, `bloom_wash`, past the flowers).
const BLOOM_PEAK := 16.0
## Flower candidates a square metre with them on (KitFlora Site
## `flower_tries`; its own FLOWER_TRIES is 2.2): thicker drifts, more strays.
const BLOOM_TRIES := 3.4
const BLOOM_COMPANION := 0.12
const BLOOM_KIND := 0.12
const FAR_WASH := 0.35
## The silvery undersides the wind flips into view (shaders/
## grass_silver.gdshaderinc): their strength (0: off), on the near tufts,
## the far ring and the paint alike. With them on, the bowed blades' old
## paling (the tufts' `grass_wave_sheen`, the paint's `wind_sheen`) is cut to
## these, so the gusts don't brighten twice. --grass-silver=S, --no-grass-silver.
const SILVER := 0.8
## The drive (grass_silver zs_silver_drive) over which the underside
## turns into view, and how much brighter it reads on the near tufts, the
## far ones and the paint (each tier's own tone, so they meet as one).
const SILVER_BOW := Vector2(0.25,1.25)
const SILVER_LIFT := Vector3(1.9,1.5,1.25)
## How much of each tier's own colour the underside keeps (the paint more,
## or its bright turf goes to frost).
const SILVER_KEEP := Vector3(0.45,0.55,0.7)
const SILVER_SHEEN := 0.2
const SILVER_WIND_SHEEN := 0.45
var silver := SILVER
## How many drifts (--flower-drifts=), how strong the regions
## (--grass-regions=).
var drifts := 1.0
var regions := 1.0
## The far ring's colours at the root and the tip (linear; endless_tuft_far
## `root_colour`, `tip_colour`), matched to the near ring's tufts.
const FAR_ROOT := Vector3(0.093,0.27,0.13)
const FAR_TIP := Vector3(0.28,0.55,0.22)
## The flowers thin out between these distances (m), each at its own.
const FLOWER_FADE := Vector2(22.0,55.0)
## The flowers' leaves and buds (reference_surface `flower_lod`) shrink
## away between these ring distances (m).
const FLOWER_DETAIL := Vector2(14.0,30.0)
## A cell is freed this far (m) past where it is wanted.
const KEEP := 24.0
## Open turf: from this far over the sea (m; the beach's sand is gone
## there), on ground whose normal's up is over SLOPE.x (full past .y), up to
## the rock's edge (the ground's `rock_up`, 0.80), thinning to none as the
## paint turns to tundra (its `alpine`, from ALPINE.x to .y), so every slope
## and hill the paint draws as turf carries the carpet.
const BEACH_CLEAR := 2.55
const BEACH_RAMP := 0.35
const SLOPE := Vector2(0.83,0.88)
## Under this up the rock's ragged edge is read (it swings the edge 0.13 at
## most, so past this it never reaches SLOPE.x).
const ROCK_NEAR := 0.95
const ALPINE := Vector2(0.3,0.7)
## Over the sea (m) past which ALPINE leaves no tuft anywhere (the paint's
## alpine reaches ALPINE.y by then whatever its broad patch).
const ALPINE_TOP := 84.0
## The masks before the bare-patches round (--grass-cover=old): none on
## turf steeper than OLD_SLOPE, none HIGH.x..HIGH.y m over the sea, which
## left bare, dark hillsides and hollow sides in the carpet.
const OLD_SLOPE := Vector2(0.905,0.95)
const HIGH := Vector2(36.0,58.0)
## The masks as flown: SLOPE (--grass-slope=a,b), and ALPINE or (zero, old)
## HIGH.
var slope := SLOPE
var alpine := ALPINE
## The tufts' roots sink this much (m), so none stands on air where a
## coarser chunk draws the turf a hair lower.
const SINK := 0.04
## The ground's patches are read onto the tufts off a grid this fine (m),
## and the tufts' colour scaled by TUFT_TONE over them.
const TINT_STEP := 2.0
const TUFT_TONE := Color(1.0,1.0,1.0)
## The painted grass's tone past the tufts (linear, over its own colour),
## as the carpet reads from afar: seen from above, and at a glance.
const TONE_TOP := Vector3(0.76,0.82,0.86)
const TONE_LOW := Vector3(0.56,0.66,0.68)
## Cells growing at once (the near layer's first), ms a frame for standing
## their batches.
const MAX_TASKS := 6
const STAND_BUDGET := 1.5
## How far the near tufts' roots take the painted ground's colour under them
## (reference_surface `grass_root_paint`; 0: the isles' ground_look colour),
## the paint under them taking the tufts' own ground (endless_ground
## `carpet_near`).
const ROOT_PAINT := 1.0
## The share of the sun a cloud's shadow takes off the tufts and flowers, the
## sky's light left (reference_surface `cloud_sun_shade`, endless_tuft_far
## `cloud_shade`), as the painted ground's (endless_ground `cloud_shade`), so
## a shadowed meadow goes soft as one surface.
const CLOUD_SUN := 0.85
## The near ring's tuft (FINE, --grass-fine=0 for the isles' own): finer than
## the isles' (scripts/grass_tuft_mesh.gd, made to read from 20-26 m, whose
## ten broad blades read as leafy clumps from a plane skimming at 3-10 m):
## more, narrower blades of one bend each, the same height, root and lean,
## so the same material lights it alike, in fewer triangles (54 against 80).
## blades, rows up the blade, their taper, the width (a share of the isles'),
## the satellites [blades, distance, size].
const FINE := {"blades":12,"rows":[0.0,0.6],"taper":[1.0,0.55],"width":0.6,"satellites":[[3,0.27,0.62],[3,0.24,0.55]]}
## The near ring's tufts a square metre with the FINE tuft, a share of
## the isle's (its blades are narrower: more of them cover the turf alike).
const FINE_TUFTS := 1.2
const GrassTuft = preload("res://scripts/grass_tuft_mesh.gd")

var seed := 0
var enabled := true
## The lead's share (--grass-lead=, --no-grass-lead), the height the rings
## stay flat to (--grass-flat-up=), round 5's 3D rings (--grass-ring=3d).
var lead := LEAD
var flat_up := FLAT_UP
var rings_3d := false
## The lead now (world x, z; damped), the eye's height past flat_up, as
## the shaders were told (`ring_lead`).
var lead_now := Vector2.ZERO
var rise := 0.0
var _lead_planned := Vector2.ZERO
var _ring_mats := {}
var share := 1.0
var lod := LOD
## The wildflowers in the near carpet (--no-flowers leaves them out).
var flowers := true
## How much of the painted ground's patches the tufts carry (--grass-patches=X).
var patches := 1.0
## The near ring draws the FINE tuft (--grass-fine=0: the isles' own).
var fine := true
var _fine_meshes := {}
var _fine_share := FINE_TUFTS
var tall := TALL
## Cells grown and freed, their grow times, the slowest stand, for the HUD
## and drivers.
var stats := {"grown":0,"freed":0,"grow_ms":0.0,"slowest_grow_ms":0.0,"slowest_stand_ms":0.0}
var field: RefCounted
## The land's ground (shaders/endless_ground.gdshader), told where the
## tufts grow and how far they reach, so its paint takes over past them.
var ground: ShaderMaterial
## Shader settings asked for on the command line, for tuning by hand:
## --grass-set=name=value (the near tufts' material, reference_surface),
## --far-set= (the far ring's, endless_tuft_far), --ground-set= (the
## painted ground's, endless_ground); a value is a number or numbers
## joined by commas (a vector), each flag repeatable.
var _sets := {"grass":{},"far":{},"ground":{}}

## One layer of cells: how far (3D, m) it is wanted, its grower's settings
## and its cells.
class Layer extends RefCounted:
	var far := false
	var reach := 0.0
	var site := {}
	var share := 0.0
	var cells := {}       # Vector2i -> Node3D
	var pending := {}     # Vector2i -> task id
	var wanted := {}
	var queue: Array = []

var near_layer := Layer.new()
var far_layer := Layer.new()
var _done: Array = []
var _lock := Mutex.new()
var _quit := false
var _eye := Vector3.ZERO
var _planned_at := Vector3.INF
var _calmed := {}
var _fars := {}
var _since_plan := 0

## Whether the grass is asked for (not --no-grass).
static func wanted() -> bool:
	return not "--no-grass" in LaunchArgs.user_args()

func setup(land_seed: int, ground_material: ShaderMaterial = null) -> void:
	name = "Grass"
	seed = land_seed
	ground = ground_material
	field = Field.new(seed)
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--grass="): share = maxf(a.get_slice("=",1).to_float(),0.0)
		elif a.begins_with("--grass-range="):
			var w := maxf(a.get_slice("=",1).to_float(),20.0)
			lod = LOD*(w/LOD.w)
		elif a == "--no-flowers": flowers = false
		elif a.begins_with("--grass-fine="):
			fine = a.get_slice("=",1) != "0"
			if fine and a.get_slice("=",1).to_float() > 0.0: _fine_share = a.get_slice("=",1).to_float()
		elif a.begins_with("--grass-tall="): tall = clampf(a.get_slice("=",1).to_float(),0.25,6.0)
		elif a == "--grass-cover=old":
			slope = OLD_SLOPE
			alpine = Vector2.ZERO
		elif a.begins_with("--grass-slope="):
			var sp := a.get_slice("=",1).split(",")
			if sp.size() >= 2: slope = Vector2(float(sp[0]),float(sp[1]))
		elif a.begins_with("--grass-patches="): patches = clampf(a.get_slice("=",1).to_float(),0.0,1.0)
		elif a.begins_with("--flower-drifts="): drifts = maxf(a.get_slice("=",1).to_float(),0.0)
		elif a == "--no-drifts": drifts = 0.0
		elif a.begins_with("--grass-regions="): regions = maxf(a.get_slice("=",1).to_float(),0.0)
		elif a == "--no-regions": regions = 0.0
		elif a.begins_with("--grass-silver="): silver = maxf(a.get_slice("=",1).to_float(),0.0)
		elif a == "--no-grass-silver": silver = 0.0
		elif a.begins_with("--grass-lead="): lead = clampf(a.get_slice("=",1).to_float(),0.0,0.85)
		elif a == "--no-grass-lead": lead = 0.0
		elif a.begins_with("--grass-flat-up="): flat_up = maxf(a.get_slice("=",1).to_float(),0.0)
		elif a == "--grass-ring=3d": rings_3d = true
		elif a.begins_with("--grass-set=") or a.begins_with("--far-set=") or a.begins_with("--ground-set="):
			var which := a.get_slice("-",2).get_slice("-",0)
			var kv := a.substr(a.find("=")+1)
			if kv.contains("="): _sets[which][kv.get_slice("=",0)] = _value(kv.get_slice("=",1))
		elif a.begins_with("--grass-lod="):
			var p := a.get_slice("=",1).split(",")
			if p.size() >= 4: lod = Vector4(float(p[0]),float(p[1]),float(p[2]),float(p[3]))
	# The regions and drifts, set before any worker reads them.
	Patch.offset = Patch.seed_offset(seed)
	Patch.region_amount = regions
	Patch.bloom_amount = drifts if flowers else 0.0
	# The isle's carpet settings, read here once (the workers copy them).
	var s := KitFlora.Site.new()
	Carpet.carpeted(s)
	var site := {"carpet":s.carpet,"tufts":s.tufts*share,"grass_range":lod.w,"tuft_bump":s.tuft_bump,"shag":s.shag,
		"variety":s.variety,"contact":s.contact,"height_field":s.height_field,"tilt":s.tilt}
	near_layer.site = site
	near_layer.reach = maxf(lod.y,FLOWER_FADE.y)
	near_layer.share = 0.0
	near_layer.site.flowers = flowers
	near_layer.site.patches = patches
	near_layer.site.flower_tall = tall
	near_layer.site.slope = slope
	near_layer.site.alpine = alpine
	far_layer.far = true
	far_layer.site = site.duplicate()
	far_layer.site.slope = slope
	far_layer.site.alpine = alpine
	far_layer.site.tufts = FAR_TUFTS*share
	# No wild grass or tussocks a few pixels across (their probes cost the
	# most of a cell's grow).
	far_layer.site.shag = 0.0
	far_layer.site.variety = false
	far_layer.reach = lod.w
	if fine: near_layer.site.tufts = s.tufts*share*_fine_share
	far_layer.share = 1.0
	# The plant catalog made on the main thread before any worker reads it.
	SkyIslets.catalog()
	if ground != null:
		ground.set_shader_parameter("turf_beach",Vector2(BEACH_CLEAR,BEACH_CLEAR+BEACH_RAMP))
		ground.set_shader_parameter("turf_slope",slope)
		ground.set_shader_parameter("turf_high",HIGH)
		ground.set_shader_parameter("turf_alpine",alpine)
		ground.set_shader_parameter("carpet_tone_top",TONE_TOP)
		ground.set_shader_parameter("carpet_tone_low",TONE_LOW)
		ground.set_shader_parameter("region_offset",Patch.offset)
		ground.set_shader_parameter("region_amount",Patch.region_amount)
		ground.set_shader_parameter("bloom_amount",Patch.bloom_amount)
		ground.set_shader_parameter("bloom_fade",FLOWER_FADE)
		_silver(ground,"wind_sheen",SILVER_WIND_SHEEN)
		for k: String in _sets.ground: ground.set_shader_parameter(k,_sets.ground[k])
	if rings_3d: lead = 0.0
	if ground != null: _ring_mats[ground.get_instance_id()] = ground
	_reach()

func _exit_tree() -> void:
	_quit = true
	for layer: Layer in [near_layer,far_layer]:
		for key: Vector2i in layer.pending: WorkerThreadPool.wait_for_task_completion(layer.pending[key])
		layer.pending.clear()

## The ground's paint told how far the tufts reach (none while off).
func _reach() -> void:
	if ground == null: return
	ground.set_shader_parameter("carpet_reach",Vector2(lod.z,lod.w) if enabled else Vector2.ZERO)
	ground.set_shader_parameter("carpet_near",Vector2(lod.x,lod.y) if enabled and ROOT_PAINT > 0.0 else Vector2.ZERO)

## A --*-set= value: a float, or a Vector2/3/4 of comma-joined floats.
static func _value(text: String) -> Variant:
	var p := text.split(",")
	match p.size():
		2: return Vector2(float(p[0]),float(p[1]))
		3: return Vector3(float(p[0]),float(p[1]),float(p[2]))
		4: return Vector4(float(p[0]),float(p[1]),float(p[2]),float(p[3]))
	return float(text)

## Turned off (freed) or on again (grown round the eye).
func set_enabled(on: bool) -> void:
	enabled = on
	_reach()
	if not on:
		for layer: Layer in [near_layer,far_layer]:
			for key: Vector2i in layer.cells.keys(): _free(layer,key)
			layer.queue.clear()
			layer.wanted.clear()
		_lock.lock()
		_done.clear()
		_lock.unlock()
	_planned_at = Vector3.INF

## One frame: the cells round `eye` (the camera that draws) asked for,
## finished ones stood within the budget, far ones freed.
func step(eye: Vector3, forward := Vector3.ZERO) -> void:
	_eye = eye
	_lead_step(forward)
	_reap()
	if not enabled:
		_lock.lock()
		_done.clear()
		_lock.unlock()
		return
	if ground != null and not _fars.is_empty():
		var night: Variant = ground.get_shader_parameter("night_grade")
		for id: Variant in _fars: (_fars[id] as ShaderMaterial).set_shader_parameter("night_grade",night)
	# Replanned as the eye moves, and now and then anyway, so a cell that
	# finished while it wasn't wanted is asked for again once it is.
	_since_plan += 1
	if _planned_at == Vector3.INF or eye.distance_to(_planned_at) > 4.0 or _since_plan > 30 or lead_now.distance_to(_lead_planned) > 0.06: _plan()
	_ask()
	_stand()

## The lead toward the view's level direction `forward` (damped; at once
## before the first plan), the eye's rise, told to every ring material.
func _lead_step(forward: Vector3) -> void:
	var want := Vector2.ZERO
	var level := Vector2(forward.x,forward.z)
	if lead > 0.0 and level.length() > 0.001:
		want = level.normalized()*lead*smoothstep(LEAD_LEVEL.x,LEAD_LEVEL.y,level.length()/maxf(forward.length(),0.001))
	if _planned_at == Vector3.INF: lead_now = want
	else:
		var dt: float = get_process_delta_time() if is_inside_tree() else 1.0/60.0
		lead_now = lead_now.lerp(want,1.0-exp(-LEAD_RATE*maxf(dt,1.0/240.0)))
	var over := _over(_eye)
	rise = over if rings_3d else maxf(over-flat_up,0.0)*RISE
	var v := Vector4(lead_now.x,lead_now.y,rise,0.0 if rings_3d else 1.0)
	for id: int in _ring_mats: (_ring_mats[id] as ShaderMaterial).set_shader_parameter("ring_lead",v)

## The ring distance (m) of ground point `p` from the eye: along the ground,
## led ahead (shaders/endless_ring.gdshaderinc), the rise left out.
func ring_d(p: Vector2) -> float:
	var q := p-Vector2(_eye.x,_eye.z)
	var ll := minf(lead_now.length_squared(),0.81)
	var ql := q.dot(lead_now)
	return (sqrt(ql*ql+(1.0-ll)*q.length_squared())-ql)/(1.0-ll)

## A cell's ring distance, at its point nearest the eye (for the order).
func _cell_d(key: Vector2i) -> float:
	var x0 := key.x*CELL
	var z0 := key.y*CELL
	return ring_d(Vector2(clampf(_eye.x,x0,x0+CELL),clampf(_eye.z,z0,z0+CELL)))

## The disc of ground (centre x, z, radius) within ring distance `reach`
## (the rise taken off).
func _disc(reach: float) -> Vector3:
	var r := sqrt(maxf(reach*reach-rise*rise,0.0))
	var c := Vector2(_eye.x,_eye.z)+lead_now*r
	return Vector3(c.x,c.y,r)

## A cell's square's flat distance from ground point `c`.
func _square_d(key: Vector2i, c: Vector2) -> float:
	var x0 := key.x*CELL
	var z0 := key.y*CELL
	var dx := maxf(maxf(x0-c.x,c.x-(x0+CELL)),0.0)
	var dz := maxf(maxf(z0-c.y,c.y-(z0+CELL)),0.0)
	return sqrt(dx*dx+dz*dz)

## The near cells under the full carpet (LOD.y), and the far ones within
## PRIME_FAR m, grown before the first frame, the main thread waiting (at most PRIME_WAIT s); the rest grow in
## flight.
const PRIME_WAIT := 4.0
const PRIME_FAR := 90.0
func prime(at: Vector3, forward := Vector3.ZERO) -> void:
	var began := Time.get_ticks_msec()
	step(at,forward)
	while Time.get_ticks_msec()-began < PRIME_WAIT*1000.0:
		var left := false
		for key: Vector2i in near_layer.wanted:
			if not near_layer.cells.has(key) and _cell_d(key) < lod.y: left = true
		for key: Vector2i in far_layer.wanted:
			if not far_layer.cells.has(key) and _cell_d(key) < PRIME_FAR: left = true
		if not left: break
		OS.delay_msec(4)
		_reap()
		_ask()
		_stand(true)
	# The load's stands aren't flight's.
	stats.slowest_stand_ms = 0.0

## How far the eye stands over the ground under it (m, at least 0).
func _over(eye: Vector3) -> float:
	return maxf(eye.y-maxf(field.height(eye.x,eye.z),Field.SEA_Y),0.0)

func _plan() -> void:
	_planned_at = _eye
	_lead_planned = lead_now
	_since_plan = 0
	for layer: Layer in [near_layer,far_layer]:
		# The disc within the ring's reach (led ahead; smaller as the eye
		# rises past flat_up), and the one past which a cell goes.
		# (The near layer goes with its grass: its flowers alone, past it,
		# would be a pixel across.)
		var disc := _disc(layer.reach if layer.far or rise < lod.y else 0.0)
		var centre := Vector2(disc.x,disc.y)
		var reach := disc.z
		layer.wanted.clear()
		if reach > 0.0:
			var r := ceili((reach+CELL)/CELL)
			var cx := floori(centre.x/CELL)
			var cz := floori(centre.y/CELL)
			for dz in range(-r,r+1):
				for dx in range(-r,r+1):
					var key := Vector2i(cx+dx,cz+dz)
					if _square_d(key,centre) <= reach: layer.wanted[key] = true
		var keep := _disc(layer.reach+KEEP)
		for key: Vector2i in layer.cells.keys():
			if not layer.wanted.has(key) and _square_d(key,Vector2(keep.x,keep.y)) > keep.z: _free(layer,key)
		layer.queue.clear()
		for key: Vector2i in layer.wanted:
			if not layer.cells.has(key) and not layer.pending.has(key): layer.queue.append(key)
		# Nearest by the ring distance first: ahead before behind.
		layer.queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return _cell_d(a) < _cell_d(b))

func _free(layer: Layer, key: Vector2i) -> void:
	(layer.cells[key] as Node).queue_free()
	layer.cells.erase(key)
	stats.freed += 1

func _ask() -> void:
	for layer: Layer in [near_layer,far_layer]:
		while near_layer.pending.size()+far_layer.pending.size() < MAX_TASKS and not layer.queue.is_empty():
			var key: Vector2i = layer.queue.pop_front()
			if layer.cells.has(key) or layer.pending.has(key): continue
			layer.pending[key] = WorkerThreadPool.add_task(_grow.bind(layer,key,seed,layer.site.duplicate(),lod),false,"grass cell")

## Finished tasks let go.
func _reap() -> void:
	for layer: Layer in [near_layer,far_layer]:
		for key: Vector2i in layer.pending.keys():
			var id: int = layer.pending[key]
			if WorkerThreadPool.is_task_completed(id):
				WorkerThreadPool.wait_for_task_completion(id)
				layer.pending.erase(key)

## Finished cells' batches stood, nearest first, within the budget; a cell
## no longer wanted is dropped.
func _stand(all := false) -> void:
	_lock.lock()
	var ready := _done
	_done = []
	_lock.unlock()
	if ready.is_empty(): return
	var began := Time.get_ticks_usec()
	ready.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _cell_d(a.key) < _cell_d(b.key))
	while not ready.is_empty():
		if not all and (Time.get_ticks_usec()-began)/1000.0 > STAND_BUDGET: break
		var r: Dictionary = ready.pop_front()
		var key: Vector2i = r.key
		var layer: Layer = r.layer
		stats.grown += 1
		stats.grow_ms += float(r.ms)
		stats.slowest_grow_ms = maxf(stats.slowest_grow_ms,float(r.ms))
		if layer.cells.has(key) or not layer.wanted.has(key): continue
		var t0 := Time.get_ticks_usec()
		var node := Node3D.new()
		node.name = "%s_%d_%d" % ["Far" if layer.far else "Near",key.x,key.y]
		var count := 0
		for part: Dictionary in r.parts:
			var ring: Dictionary = part.get("ring",{})
			var own: Mesh = _fine(str(part.key)) if fine and not layer.far and str(part.key).begins_with("grass") else null
			var batch := KitFlora.batch_node(str(part.key),part.tile,int(part.count),part.buffer,lod.w,ring,own)
			count += int(part.count)
			# A tile is drawn out to its ring's reach led ahead, and over
			# the height the rings stay flat to (Godot's range is 3D).
			var past := KitFlora.TILE*0.75+(rise if rings_3d else flat_up)
			if layer.far:
				batch.material_override = _far(str(part.key),ring)
				batch.visibility_range_end = lod.w*(1.0+lead)+past
			elif ring.is_empty():
				# The flowers thin out each at its own distance (no tile
				# fade, which would draw them in the transparent pass).
				batch.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
				batch.visibility_range_end_margin = 0.0
				batch.visibility_range_end = FLOWER_FADE.y*(1.0+lead)+past
			else: batch.visibility_range_end = lod.y*(1.0+lead)+past
			_calm(batch)
			node.add_child(batch)
		node.set_meta("instances",count)
		add_child(node)
		layer.cells[key] = node
		stats.slowest_stand_ms = maxf(stats.slowest_stand_ms,(Time.get_ticks_usec()-t0)/1000.0)
	if not ready.is_empty():
		_lock.lock()
		ready.append_array(_done)
		_done = ready
		_lock.unlock()

## The isle's carpet calm (Carpet `calm`) on a batch's material, once a
## material; the flowers thinned by distance.
func _calm(batch: MultiMeshInstance3D) -> void:
	var m := batch.material_override as ShaderMaterial
	if m == null or _calmed.has(m.get_instance_id()) or _fars.values().has(m): return
	_calmed[m.get_instance_id()] = true
	_ring_mats[m.get_instance_id()] = m
	m.set_shader_parameter("ring_lead",Vector4(lead_now.x,lead_now.y,rise,0.0 if rings_3d else 1.0))
	m.set_shader_parameter("cloud_sun_shade",CLOUD_SUN)
	if str(batch.get_meta("part","")).begins_with("grass"):
		m.set_shader_parameter("grass_dry",Carpet.CARPET_GRASS_DRY)
		m.set_shader_parameter("grass_mute",Carpet.CARPET_MUTE)
		m.set_shader_parameter("grass_wave_sheen",Carpet.CARPET_SHEEN)
		var plain := Patch.plain()
		m.set_shader_parameter("grass_root_paint",Vector4(plain.x,plain.y,plain.z,ROOT_PAINT))
		_silver(m,"grass_wave_sheen",SILVER_SHEEN)
		for k: String in _sets.grass: m.set_shader_parameter(k,_sets.grass[k])
		# The sway's arm is the blade's height: taller blades bend as far.
		var sway = m.get_shader_parameter("sway_shape")
		if sway is Vector4 and fine: m.set_shader_parameter("sway_shape",Vector4(sway.x,sway.y*tall,sway.z,sway.w))
	else:
		m.set_shader_parameter("flower_far",Vector4(FLOWER_FADE.x,FLOWER_FADE.y,0.0,0.0))
		# Their leaves and buds gone before the heads (FLOWER_DETAIL; led
		# out ahead, they would glint a pixel across).
		m.set_shader_parameter("flower_lod",FLOWER_DETAIL)

## The FINE tuft for catalog part `key`, its root and tip colours the
## part's own (so the material divides them out alike), made once.
func _fine(key: String) -> Mesh:
	if _fine_meshes.has(key): return _fine_meshes[key]
	var source: Mesh = SkyIslets.catalog().meshes[key]
	var root: Color = source.get_meta("grass_root",Color("38663a").srgb_to_linear())
	var tip: Color = source.get_meta("grass_tip",Color("93c05f").srgb_to_linear())
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	GrassTuft._clump(surface,rng,root,tip,int(FINE.blades),Vector2.ZERO,1.0,FINE.rows,FINE.taper,float(FINE.width))
	var turn := rng.randf()*TAU
	for satellite: Array in FINE.satellites:
		turn += rng.randf_range(2.0,3.6)
		GrassTuft._clump(surface,rng,root,tip,int(satellite[0]),Vector2.from_angle(turn)*float(satellite[1]),float(satellite[2]),FINE.rows,FINE.taper,float(FINE.width))
	surface.index()
	var mesh := surface.commit()
	if not is_equal_approx(tall,1.0):
		var arrays := mesh.surface_get_arrays(0)
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in v.size(): v[i].y *= tall
		arrays[Mesh.ARRAY_VERTEX] = v
		mesh = ArrayMesh.new()
		(mesh as ArrayMesh).add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.set_meta("grass_root",root)
	mesh.set_meta("grass_tip",tip)
	_fine_meshes[key] = mesh
	return mesh

## The far ring's material (shaders/endless_tuft_far.gdshader): KitFlora's
## mid ring (its `ring_material`'s grass_ring and grass_ring_grow) drawn
## plainly, its tufts growing in from nothing as the near ring thins. The
## isles' tuft material works out its sway, ground colour and light at every
## vertex and pixel, which over a field to the horizon cost 10 to 20 ms a
## frame.
func _far(key: String, ring: Dictionary) -> Material:
	var lod_v: Vector4 = ring.lod
	var id := [key,lod_v,ring.grow,ring.soft]
	if _fars.has(id): return _fars[id]
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/endless_tuft_far.gdshader")
	var grow: Vector2 = ring.grow
	var soft := float(ring.soft)
	m.set_shader_parameter("grass_ring",Vector4(lod_v.z,lod_v.w,soft,0.0))
	# Each comes up over the soft metres where a near tuft at its rank goes.
	m.set_shader_parameter("grass_ring_in",Vector4(lod_v.x-soft,lod_v.y-soft,soft,0.0))
	m.set_shader_parameter("grow_near",Vector2(FAR_NEAR.x,FAR_NEAR.y*tall))
	m.set_shader_parameter("grass_ring_grow",Vector4(lod_v.y,lod_v.z,grow.x,grow.y*tall))
	# The drift's tufts come up as the flowers go (reference_surface
	# `flower_far`: gone by FLOWER_FADE.y).
	m.set_shader_parameter("wash_in",Vector4(FLOWER_FADE.x-soft*0.5,FLOWER_FADE.y-soft*0.5,soft*0.5,0.0))
	var washes := PackedVector3Array()
	for k: Array in Patch.KINDS: washes.append(k[2])
	washes.resize(8)
	m.set_shader_parameter("wash_colours",washes)
	m.set_shader_parameter("ring_lead",Vector4(lead_now.x,lead_now.y,rise,0.0 if rings_3d else 1.0))
	m.set_shader_parameter("root_colour",FAR_ROOT)
	m.set_shader_parameter("tip_colour",FAR_TIP)
	var mesh: Mesh = KitFlora.lite_tuft(key)
	if mesh.has_meta("grass_root"):
		var root: Color = mesh.get_meta("grass_root")
		var tip: Color = mesh.get_meta("grass_tip")
		m.set_shader_parameter("grass_source_root",Vector3(root.r,root.g,root.b))
		m.set_shader_parameter("grass_source_tip",Vector3(tip.r,tip.g,tip.b))
	m.set_shader_parameter("cloud_shade",CLOUD_SUN)
	_silver(m,"",0.0,true)
	for k: String in _sets.far: m.set_shader_parameter(k,_sets.far[k])
	_fars[id] = m
	_ring_mats[m.get_instance_id()] = m
	return m

## The silvery undersides on material `m` (none while `silver` is 0), and
## its old wind paling `sheen` cut to `cut` while they show.
func _silver(m: ShaderMaterial, sheen := "", cut := 0.0, far := false) -> void:
	if silver <= 0.0: return
	_silver_tier(m,far)
	if sheen != "": m.set_shader_parameter(sheen,cut)

## grass_silver on material `m`, with its tier's lift and keep.
func _silver_tier(m: ShaderMaterial, far := false) -> void:
	var tier := 2 if m == ground else (1 if far or _fars.values().has(m) else 0)
	m.set_shader_parameter("grass_silver",Vector4(silver,SILVER_BOW.x,SILVER_BOW.y,SILVER_LIFT[tier]))
	m.set_shader_parameter("grass_silver_keep",SILVER_KEEP[tier])

## The undersides turned to strength `s` on every grass material now
## standing (0 off: the old paling back), for A/B in one run.
func set_silver(s: float) -> void:
	silver = maxf(s,0.0)
	for m: ShaderMaterial in _ring_mats.values():
		var on := silver > 0.0
		_silver_tier(m)
		if m == ground: m.set_shader_parameter("wind_sheen",SILVER_WIND_SHEEN if on else 1.0)
		elif not _fars.values().has(m): m.set_shader_parameter("grass_wave_sheen",SILVER_SHEEN if on else Carpet.CARPET_SHEEN)

## Cells standing, building and queued, and the instances drawn, both layers.
func counts() -> Dictionary:
	var out := {"cells":0,"building":0,"queued":0,"instances":0}
	for layer: Layer in [near_layer,far_layer]:
		out.cells += layer.cells.size()
		out.building += layer.pending.size()
		out.queued += layer.queue.size()
		for key: Vector2i in layer.cells: out.instances += int((layer.cells[key] as Node).get_meta("instances",0))
	out.near_cells = near_layer.cells.size()
	out.far_cells = far_layer.cells.size()
	return out

# --- On a worker ----------------------------------------------------------------------

## How many times the flowers' share is kept at p (DRIFT).
## (Round 4's drifts: with round 5's on, grow_cell reads them off its grid.)
static func flower_drift(p: Vector2) -> float:
	var n := Patch.noise(p.x/DRIFT_SCALE+17.3,p.y/DRIFT_SCALE-5.1)
	return 1.0+(DRIFT.z-1.0)*smoothstep(DRIFT.x,DRIFT.y,n)

func _grow(layer: Layer, key: Vector2i, land_seed: int, site_values: Dictionary, rings: Vector4) -> void:
	if _quit: return
	var began := Time.get_ticks_usec()
	var parts := grow_cell(land_seed,key,site_values,rings,layer.share)
	var took := (Time.get_ticks_usec()-began)/1000.0
	_lock.lock()
	_done.append({"layer":layer,"key":key,"parts":parts,"ms":took})
	_lock.unlock()

## One cell's grass (and, for the near layer, flowers) as plain batches, one
## a KitFlora tile, part and ring ([{key, tile, count, buffer, ring}]):
## KitFlora's Grow at the carpet's settings (`site_values`), its rings `rings`
## with `far_share` of the tufts in the far one (0: all near, with the
## flowers; 1: all far, the grass alone), its probe the cell's own height
## grid. Worker-safe.
static func grow_cell(land_seed: int, key: Vector2i, site_values: Dictionary, rings: Vector4, far_share := 0.0) -> Array:
	var f: RefCounted = Field.new(land_seed)
	var sl: Vector2 = site_values.get("slope",SLOPE)
	var alp: Vector2 = site_values.get("alpine",ALPINE)
	var top := ALPINE_TOP if alp.y > 0.0 else HIGH.y
	var x0 := key.x*CELL
	var z0 := key.y*CELL
	var n := int(CELL)+1+PAD*2
	# The cell's 1 m grid in one call (LandField.grid; native when built):
	# heights, meadows and how far outside a river's water each node is
	# (land_field `last_river`): no tuft or flower on its bank.
	var got: Dictionary = f.grid(x0,z0,1.0,n,n,PAD)
	var hs: PackedFloat32Array = got.heights
	var ms: PackedFloat32Array = got.meadows
	var rs: PackedFloat32Array = got.river
	# No turf in it at all (the sea, the peaks): nothing to grow.
	var any := false
	for h: float in hs:
		var over := h-Field.SEA_Y
		if over >= BEACH_CLEAR and over < top:
			any = true
			break
	if not any: return []
	var ragged := {}
	var lattice := {}
	# The paint's broad patch (260 m across) at the cell's corners, for its
	# alpine (EndlessPatch.alpine) eased across the cell.
	var b00 := Patch.broad(x0,z0)
	var b10 := Patch.broad(x0+CELL,z0)
	var b01 := Patch.broad(x0,z0+CELL)
	var b11 := Patch.broad(x0+CELL,z0+CELL)
	var probe := func(p: Vector2, _reach: float) -> float:
		var u := p.x-x0+PAD
		var v := p.y-z0+PAD
		var i := clampi(floori(u),1,n-3)
		var j := clampi(floori(v),1,n-3)
		var fx := clampf(u-i,0.0,1.0)
		var fz := clampf(v-j,0.0,1.0)
		var k := j*n+i
		var h00 := hs[k]
		var h10 := hs[k+1]
		var h01 := hs[k+n]
		var h11 := hs[k+n+1]
		# As the land's mesh splits each quad: (00, 10, 01) and (10, 11, 01).
		var h := h00+fx*(h10-h00)+fz*(h01-h00) if fx+fz <= 1.0 else h11+(1.0-fx)*(h01-h11)+(1.0-fz)*(h10-h11)
		var over := h-Field.SEA_Y
		if over < BEACH_CLEAR: return NAN
		# The slope as the land's normals have it (central differences),
		# at the nearer node.
		var c := (j+roundi(fz))*n+i+roundi(fx)
		# By a river: none on its bank's stones (EndlessPatch.river_bank, as
		# the ground paints them), a tuft or two leaning out over their edge.
		if rs[c] < 12.0 and rs[c] < Patch.river_bank(p.x,p.y)*0.85: return NAN
		var up := 2.0/Vector3(hs[c-1]-hs[c+1],2.0,hs[c-n]-hs[c+n]).length()
		var high := 1.0
		if alp.y <= 0.0: high = 1.0-smoothstep(HIGH.x,HIGH.y,over)
		elif over > Patch.ALPINE_FROM:
			var bx := clampf((p.x-x0)/CELL,0.0,1.0)
			var bz := clampf((p.y-z0)/CELL,0.0,1.0)
			var broad := lerpf(lerpf(b00,b10,bx),lerpf(b01,b11,bx),bz)
			high = 1.0-smoothstep(alp.x,alp.y,Patch.alpine_of(over,broad))
			if high <= 0.0: return NAN
		# Near the rock (not with --grass-cover=old): its edge as the ground
		# paints it, ragged (EndlessPatch.rock_ragged, kept per node), so the
		# tufts stop where its tongues start.
		if alp.y > 0.0 and up < ROCK_NEAR:
			if up < sl.x-Patch.RAGGED_MOST: return NAN
			if not ragged.has(c):
				ragged[c] = Patch.rock_ragged(Vector3(x0+c%n-PAD,hs[c],z0+c/n-PAD),lattice)
			up += ragged[c]
		var keep := smoothstep(sl.x,sl.y,up)*high*smoothstep(BEACH_CLEAR,BEACH_CLEAR+BEACH_RAMP,over)
		if keep <= 0.0: return NAN
		if keep < 1.0 and float(hash(Vector2i(roundi(p.x*7.0),roundi(p.y*7.0)))%10007)/10007.0 > keep: return NAN
		return h-SINK
	var site := KitFlora.Site.new()
	var flowers: bool = site_values.get("flowers",true) and far_share < 1.0
	var patches: float = site_values.get("patches",1.0)
	for k: String in site_values:
		if not k in ["flowers","patches","flower_tall","slope","alpine"]: site.set(k,site_values[k])
	site.plain = true
	site.probe = probe
	# The drifts (Patch `bloom`) read off a TINT_STEP m grid of the cell,
	# for the flowers and the far ring's tufts.
	var tg := int(CELL/TINT_STEP)+1
	var blooms := PackedVector2Array()
	if Patch.bloom_amount > 0.0:
		blooms.resize(tg*tg)
		for tj in tg:
			for ti in tg: blooms[tj*tg+ti] = Patch.bloom(x0+ti*TINT_STEP,z0+tj*TINT_STEP)
	var bloom_at := func(p: Vector2) -> Vector2:
		var u := clampf((p.x-x0)/TINT_STEP,0.0,tg-1.001)
		var v := clampf((p.y-z0)/TINT_STEP,0.0,tg-1.001)
		var i := int(u)
		var j := int(v)
		var fu := u-i
		var fv := v-j
		var w := lerpf(lerpf(blooms[j*tg+i].x,blooms[j*tg+i+1].x,fu),lerpf(blooms[(j+1)*tg+i].x,blooms[(j+1)*tg+i+1].x,fu),fv)
		return Vector2(w,blooms[(j+roundi(fv))*tg+i+roundi(fu)].y)
	if blooms.is_empty():
		site.flower_drift = flower_drift
	else:
		# (The far layer's flowers are dropped: none sown there.)
		site.flower_tries = BLOOM_TRIES if flowers else 0.0001
		site.flower_drift = func(p: Vector2) -> float: return 1.0+(BLOOM_PEAK-1.0)*float(bloom_at.call(p).x)
		site.flower_kind = func(p: Vector2, _kind: String) -> Array:
			var b: Vector2 = bloom_at.call(p)
			if b.x < BLOOM_KIND: return []
			if float(hash(Vector2i(roundi(p.x*53.0),roundi(p.y*53.0)))%10007)/10007.0 < BLOOM_COMPANION: return []
			var k: Array = Patch.KINDS[int(b.y)]
			return [k[0],k[1]]
	# The flowers stand above the taller grass (a little height variety).
	var lift_by: float = site_values.get("flower_tall",1.0)
	if not is_equal_approx(lift_by,1.0):
		site.flower_lift = func(p: Vector2) -> float:
			var h := float(hash(Vector2i(roundi(p.x*31.0),roundi(p.y*31.0)))%10007)/10007.0
			return 1.0+(lift_by-1.0)*(FLOWER_LIFT.x+(FLOWER_LIFT.y-FLOWER_LIFT.x)*h)
	site.box = Rect2(x0,z0,CELL,CELL)
	site.rim = 0.0
	site.lod = rings
	site.lod_share = far_share
	site.lod_grow = FAR_GROW
	site.lod_soft = SOFT
	# The outline well round the cell, so no rim (wild grass, the rim's
	# keep) falls inside it: the carpet runs on across cells.
	var g := 16.0
	var outline := PackedVector2Array([Vector2(x0-g,z0-g),Vector2(x0+CELL+g,z0-g),Vector2(x0+CELL+g,z0+CELL+g),Vector2(x0-g,z0+CELL+g)])
	var job := KitFlora.Grow.new(hash([land_seed,"endless_grass",far_share,key]) & 0xffffff,null,[],[outline],site)
	while not job.step(-1): pass
	# The draw's node: unused for plain batches, and never in a tree, so
	# freed here (each cell left one leaked at exit).
	if job.node != null: job.node.free()
	# The painted ground's patches on each tuft (Patch `tint`), read off a
	# TINT_STEP m grid of the cell.
	var tints := PackedColorArray()
	tints.resize(tg*tg)
	for tj in tg:
		for ti in tg:
			var c := (int(tj*TINT_STEP)+PAD)*n+int(ti*TINT_STEP)+PAD
			var x := x0+ti*TINT_STEP
			var z := z0+tj*TINT_STEP
			var y := hs[c]
			var normal := Vector3(hs[c-1]-hs[c+1],2.0,hs[c-n]-hs[c+n]).normalized()
			var vc: Color = f.colour(x,z,y,normal.y,ms[c])
			var hue := Vector3(pow(vc.r,2.2),pow(vc.g,2.2),pow(vc.b,2.2))
			tints[tj*tg+ti] = Color.WHITE.lerp(Patch.tint(x,z,ms[c],y-Field.SEA_Y,normal.y,hue),patches)*TUFT_TONE
	# Each of KitFlora's tile batches kept (KitFlora.TILE m), so each
	# culls on its own by the view and its ring's reach.
	var out := []
	for part: Dictionary in job.parts:
		var grass := str(part.key).begins_with("grass")
		# The far layer is the grass alone (its flowers are the near's).
		if far_share >= 1.0 and (not grass or int((part.get("ring",{}) as Dictionary).get("ring",0)) != 2): continue
		if not grass and not flowers: continue
		var buffer: PackedFloat32Array = part.buffer
		if grass:
			for k in range(0,buffer.size(),16):
				var u := clampf((buffer[k+3]-x0)/TINT_STEP,0.0,tg-1.001)
				var v := clampf((buffer[k+11]-z0)/TINT_STEP,0.0,tg-1.001)
				var i := int(u)
				var j := int(v)
				var a := tints[j*tg+i].lerp(tints[j*tg+i+1],u-i)
				var b := tints[(j+1)*tg+i].lerp(tints[(j+1)*tg+i+1],u-i)
				var t := a.lerp(b,v-j)
				# In a drift some of the far ring's tufts are in flower:
				# its colour (the near ring's flowers are drawn).
				if far_share >= 1.0 and not blooms.is_empty():
					var bl: Vector2 = bloom_at.call(Vector2(buffer[k+3],buffer[k+11]))
					# (Marked by its alpha, (kind+1)/16: the far material
					# puts the colour on its upper blades, endless_tuft_far.)
					if bl.x > 0.0 and float(hash(Vector2i(roundi(buffer[k+3]*37.0),roundi(buffer[k+11]*37.0)))%10007)/10007.0 < bl.x*FAR_WASH:
						buffer[k+15] = (int(bl.y)+1)/16.0
				buffer[k+12] *= t.r
				buffer[k+13] *= t.g
				buffer[k+14] *= t.b
		out.append({"key":part.key,"tile":part.tile,"count":part.count,"buffer":buffer,"ring":part.get("ring",{})})
	return out
