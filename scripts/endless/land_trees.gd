extends Node3D
## The endless land's spruce forests (docs/design/endless-flight/
## forests-handoff.md): where they stand is scripts/endless/tree_plan.gd, a
## pure function of the seed and a cell; this streams them round the eye.
##
## Three rings, each the one before handing over with no seam:
##   near  the spruce family (HeroTrees, in the islets' pine materials:
##         SkyIslets `_tree_parts`), a MultiMesh a BLOCK m square, part and
##         variant, drawn while the block's middle is within NEAR_END m;
##         their shadows cast by the faceted crowns (one batch a block,
##         SHADOWS_ONLY: the full crowns' shadows cost about 6 ms a frame;
##         --no-tree-shadows none);
##   mid   FarTrees' faceted crown, one MultiMesh a block, each tree shown
##         from MID.x to MID.z m (shaders/endless_tree_far.gdshader: by its
##         own distance, so it stands inside the near tree where both draw);
##   far   the same crown for TreePlan `far_cell`'s thinned, grown trees,
##         one MultiMesh a FAR_CELL square, FAR.x to FAR.z m.
## With the sprays look (the default) the crowns are the generator's own at
## every distance, in the near crowns' painted material, each level dithered
## into the next (DETAIL, FAR_CUT, MID_START below): the mid and far rings draw
## its "low" crown instead of FarTrees' and no longer stand inside the near trees.
## Blocks and far cells are planned on WorkerThreadPool tasks (TASKS at
## once, the near blocks first) and stood on the main thread within
## COMMIT_BUDGET ms a frame.
##
## The flight's solid: each tree is a cone for SkyGlide's `ground` (`ground`
## raises the land under the plane to the tree's top there): its crown's
## reach (CROWN_SOLID of it) plus WING_SOLID of the plane's half span, so a
## wingtip brushing the outer needles passes and anything more turns it
## aside as a cliff's face does (the arches' legs do the same). `inside`
## for the rolling plane. Plan cells within COLLIDE m of the plane also
## stand a convex collider a tree on layer 1 (the wheels, whoever walks).
##
## The plan and the building run natively (ZenScapeTrees, native/terrain_kernels/
## tree_cell.h: the same trees, buffers and floor, bit for bit) when the
## library is built and current and the land field is native; --trees-native=0
## (or --gdscript-kernels, --land-native=0) builds them in GDScript.
##
## Flags: --no-trees, --forest=X (the woods' share: 1; 0 none; 1.5 more),
## --forest-meadows=X (how far the woods come out onto the meadows as
## groves, 1; 0 keeps every meadow and flat open), --no-forest-floor (no
## shade sheet under the woods).

const Field = preload("res://scripts/endless/land_field.gd")
const Plan = preload("res://scripts/endless/tree_plan.gd")
const HeroTrees = preload("res://scripts/hero_trees.gd")
const FarTrees = preload("res://scripts/far_trees.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const LandArches = preload("res://scripts/endless/land_arches.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const WorldProfile = preload("res://scripts/endless/world/world_profile.gd")
const FAR_SHADER = preload("res://shaders/endless_tree_far.gdshader")
const FLOOR_SHADER = preload("res://shaders/endless_forest_floor.gdshader")
const RING_SHADER = preload("res://shaders/endless_spruce_ring.gdshader")
const SpruceSprites = preload("res://scripts/endless/spruce_sprites.gd")
## The ring shader's albedo over the crowns' vertex colour (their scene palette), measured.
const RING_GAIN := Vector3(1.11,1.08,0.98)

## The near and mid rings' square (m; whole plan cells), and the ring
## distances (m): the near trees while the block's middle is within
## NEAR_END (crossing over NEAR_MARGIN); the crowns of the mid ring (x from,
## y growing in over, z to, w sinking over), of the far ring likewise.
const BLOCK := 256.0
const NEAR_END := 430.0
const NEAR_MARGIN := 40.0
const MID := Vector4(190.0,30.0,1500.0,120.0)
const FAR := Vector4(1380.0,120.0,6200.0,900.0)
## The mid ring's crowns stand this much smaller than their tree, inside it.
const MID_SIZE := 0.94
## Blocks are built out to MID.z+BLOCK, far cells to FAR.z+FAR_CELL/2;
## replanned every REPLAN m; TASKS at once; COMMIT_BUDGET ms a frame.
const REPLAN := 48.0
const TASKS := 6
const COMMIT_BUDGET := 1.5
const PRIME := 420.0
## The flight's solid: the crown's reach times CROWN_SOLID plus WING_SOLID
## of the plane's half span; the bucket (m) the trees are looked up by.
const CROWN_SOLID := 0.85
const WING_SOLID := 0.5
const BUCKET := 16.0
## Plan cells within this of the plane (m, to the cell) stand colliders,
## their trees' shapes added within COLLIDE_BUDGET ms a frame.
const COLLIDE := 70.0
const COLLIDE_BUDGET := 0.4
const LAYER := 1
## The crowns' tint over the islets' (each tree a little either way), and
## the far crowns' colour (linear) and how much of their baked shade shows.
const TINT_SPREAD := Vector2(0.86,1.04)
const FAR_ALBEDO := Color(0.3,0.42,0.24)
const FAR_BAKED := 0.75
## The forest floor (shaders/endless_forest_floor.gdshader): a sheet over
## the land under the woods, its weight the dense woods' (after lanes and
## clearings) and TreePlan.FLOOR_GROVE of a grove's clump; a vertex every
## FLOOR_STEP m (the far cells' TreePlan.FAR_SLOT), drawn to MID.z m by the
## blocks and on by the far cells. --no-forest-floor leaves it out.
const FLOOR_STEP := 16.0
const FLOOR_COLOUR := Color(0.2,0.29,0.14)
const FLOOR_STRENGTH := 0.82
## A look with a far crown (HeroTrees.spruce_has_far, --spruce=sprays): each
## near tree draws its full crown within DETAIL m of the eye, its far crown out
## to FAR_CUT m and the faceted family's crown past that (a per-tree band in
## the crowns' shader). The full crowns stand in DETAIL_TILE m squares made
## only within DETAIL, the far ones in FAR_TILE squares made only within
## FAR_CUT, so the rest of the near ring never draws them. --spruce-detail=M and --spruce-far=M move the two; --spruce-detail=all
## gives every near tree its full crown.
const DETAIL := 80.0
const FAR_CUT := 200.0
const DETAIL_TILE := 64.0
const FAR_TILE := 128.0
## The sprays look's distance crowns (round 5): past FAR_CUT each near tree
## draws its variant's "mid" crown (HeroTrees.spruce_mid_mesh) to MID_START m,
## and the mid and far rings draw the mature's "low" crown fitted to each tree
## (spruce_low_mesh), all in the near crowns' own painted material, so value, hue
## and outline carry to the horizon. Each hand-over is a dither FADE m either
## side of it (reference_surface `lod_fade`): full to far crown, far to mid, mid to
## the ring. The blocks draw the mid crowns while their middle is within
## MID_CROWN_END (MID_START, its fade and slack, and a block's half diagonal).
const MID_START := 400.0
const FADE := Vector3(12.0,15.0,30.0)
const LOD_SLACK := 25.0
const MID_CROWN_END := 670.0
## The sprites (scripts/endless/spruce_sprites.gd, the default with the sprays
## look; --spruce-sprites=0 the crowns and rings above): past FAR_CUT every
## tree of the blocks is its sprite out to SPRITE_END m (dithered SPRITE_FADE m
## either side), the near crowns and trunks banded to FAR_CUT; past that no
## trees stand, the forest floor turning to a painted canopy from CANOPY.x m
## (in over CANOPY.y m) in the sprites' mean colour.
const SPRITE_END := 1440.0
const SPRITE_FADE := 60.0
const CANOPY := Vector2(1250.0,250.0)

var seed := 1
var share := 1.0
var meadows := 1.0
var enabled := true
var stats := {"blocks":0,"far":0,"trees":0,"far_trees":0,"plan_ms":0.0,"plans":0,"slowest_plan_ms":0.0,"slowest_commit_ms":0.0,"slowest_commit":"","colliders":0}

var _parts: Array = []        # variant -> [trunk mesh, crown mesh]
var _dims: Array = []         # variant -> Vector3(crown radius, top, bottom) at scale 1
var _tint := Color.WHITE
var _crown: Mesh              # the far crown (FarTrees proxy of the mature crown)
var _crown_fit: Array = []    # variant -> Vector3(xz scale, y scale, y offset) onto _crown
var _mid_material: ShaderMaterial
var _shade_material: StandardMaterial3D
var _far_material: ShaderMaterial
var _arch_flags := {}
var _floor := true
var _shadows := not ("--no-tree-shadows" in LaunchArgs.user_args())
var _near_floor: ShaderMaterial
var _detail := -1.0           # DETAIL in force, or < 0: one crown for every near tree
var _far_crowns: Array = []   # variant -> far crown mesh (with _detail)
var _detail_material: Array = []  # variant -> the full crown's material, banded within _detail
var _far_material_v: Array = []   # variant -> the far crown's material, banded _detail.._far_cut
var _far_cut := FAR_CUT
var _family_crowns: Array = []    # variant -> the faceted family's crown (with _detail)
var _family_material_v: Array = [] # variant -> its material, banded past _far_cut
var _tiles := {}              # Vector4i(block x, block z, tile, 0 full / 1 far) -> Node3D of crowns
var _far_floor: ShaderMaterial
var _mid_start := MID_START
var far_ring := FAR           # FAR, its reach and fade times LandStream.view()
var _rings := false           # the mid and far rings draw the sprays' low crown (HeroTrees.spruce_has_far)
var _shadow_crown: Mesh       # the near trees' shadow caster (FarTrees proxy of the mature crown)
var sprites: Node             # SpruceSprites, or null: the crowns and rings
var _trunk_band: Array = []   # variant -> the trunk's material, banded to FAR_CUT (with sprites)
var _crown_band: Array = []   # variant -> the full crown's, likewise (with sprites and every crown full)

var _blocks := {}             # Vector2i -> {node, cells: {Vector2i: {trees, buckets}}}
var _far := {}                # Vector2i -> node
var _pending := {}            # String key -> task id
var _done: Array = []
var _lock := Mutex.new()
var _queue: Array = []
var _planned_at := Vector3.INF
var _quit := false
var _eye := Vector3.ZERO
var _bodies := {}             # plan cell -> StaticBody3D
var _filling := {}            # plan cell -> its trees' shapes added so far
## The native plan and building (ZenScapeTrees), or null: GDScript.
var native: Object
## The world profile: its forest at setup, and per block whether the woods
## stand there (`layer_at`, asked only in a world of regions).
var world: RefCounted

## The flags: {on, share, meadows}, over the world's (its trees layer and
## flora's forest, forest_meadows).
static func flags() -> Dictionary:
	var w: RefCounted = WorldProfile.current()
	var out := {"on":bool(w.layer("trees",true)),"share":float(w.flora_value("forest",1.0)),"meadows":float(w.flora_value("forest_meadows",1.0)),"floor":true}
	for a: String in LaunchArgs.user_args():
		if a == "--no-trees": out.on = false
		elif a.begins_with("--forest="): out.share = maxf(0.0,float(a.get_slice("=",1)))
		elif a.begins_with("--forest-meadows="): out.meadows = maxf(0.0,float(a.get_slice("=",1)))
		elif a == "--no-forest-floor": out.floor = false
	if out.share <= 0.0: out.on = false
	return out

func setup(land_seed: int) -> void:
	seed = land_seed
	world = WorldProfile.current()
	var f := flags()
	enabled = f.on
	share = f.share
	meadows = f.meadows
	_floor = f.floor
	_arch_flags = LandArches.flags()
	if not enabled: return
	var view := preload("res://scripts/endless/land_stream.gd").view()
	far_ring = Vector4(FAR.x,FAR.y,FAR.z*view,FAR.w*view)
	var SkyIslets: GDScript = load("res://scripts/sky_islets.gd")
	for v in HeroTrees.SPRUCE.size():
		var parts: Array = SkyIslets.call("_tree_parts",v)
		_parts.append(parts)
		var box := (parts[1] as Mesh).get_aabb()
		_dims.append(Vector3(maxf(box.size.x,box.size.z)*0.5,box.end.y,maxf(box.position.y,0.0)))
	_tint = SkyIslets.get("_canopy_tint")
	if HeroTrees.spruce_has_far():
		_detail = DETAIL
		for a in LaunchArgs.user_args():
			if a == "--spruce-detail=all": _detail = -1.0
			elif a.begins_with("--spruce-detail="): _detail = maxf(0.0,float(a.get_slice("=",1)))
			elif a.begins_with("--spruce-far="): _far_cut = float(a.get_slice("=",1))
			elif a.begins_with("--spruce-mid="): _mid_start = float(a.get_slice("=",1))
		_far_cut = maxf(_far_cut,_detail)
		_mid_start = maxf(_mid_start,_far_cut)
	if _detail >= 0.0:
		for v in HeroTrees.SPRUCE.size():
			var base: Material = (_parts[v][1] as Mesh).surface_get_material(0)
			var near_m: Material = base.duplicate()
			var far_m: Material = base.duplicate()
			var family_m: Material = base.duplicate()
			# Full crown, far crown, mid crown, each dithered into the next.
			_band(near_m,Vector2(0.0,_detail),Vector2(0.0,FADE.x))
			_band(far_m,Vector2(_detail,_far_cut),Vector2(FADE.x,FADE.y))
			_band(family_m,Vector2(_far_cut,_mid_start),Vector2(FADE.y,FADE.z))
			_lift(family_m,"midlift")
			_detail_material.append(near_m)
			_far_material_v.append(far_m)
			_family_material_v.append(family_m)
			_far_crowns.append(HeroTrees.spruce_far_mesh(v,base))
			_family_crowns.append(HeroTrees.spruce_mid_mesh(v,base))
	_shadow_crown = FarTrees.proxy("tree:spruce-endless-canopies",_parts[0][1])
	_crown = _shadow_crown
	# --spruce-rings=old: the rings as before (FarTrees' crown, the small far shader, inside the near trees).
	_rings = _detail >= 0.0 and (_parts[0][1] as Mesh).surface_get_material(0) is ShaderMaterial and not ("--spruce-rings=old" in LaunchArgs.user_args())
	if _rings: _crown = HeroTrees.spruce_low_mesh(0,(_parts[0][1] as Mesh).surface_get_material(0))
	var base: Vector3 = _dims[0]
	for d: Vector3 in _dims:
		var sy := (d.y-d.z)/maxf(base.y-base.z,0.01)
		_crown_fit.append(Vector3(d.x/base.x,sy,d.z-base.z*sy))
	_mid_material = _far_shader(MID)
	_shade_material = StandardMaterial3D.new()
	_shade_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_far_material = _far_shader(far_ring)
	if _rings:
		# The rings in the near crowns' painted material: the mid from MID_START,
		# the far from the middle of the old crossing, the far's end its old fade.
		# By default in RING_SHADER, a small copy of that material's light (the full
		# reference_surface costs about 12 ms at cruise on ~30k trees);
		# --spruce-rings=ref puts them in the near crowns' material itself.
		var crown_m: Material = (_parts[0][1] as Mesh).surface_get_material(0)
		var hand := MID.z-MID.w*0.5
		if "--spruce-rings=ref" in LaunchArgs.user_args():
			_mid_material = crown_m.duplicate() as ShaderMaterial
			_band(_mid_material,Vector2(_mid_start,hand),Vector2(FADE.z,MID.w*0.5))
			_lift(_mid_material,"ringlift")
			_far_material = crown_m.duplicate() as ShaderMaterial
			_band(_far_material,Vector2(hand,far_ring.z-far_ring.w*0.5),Vector2(MID.w*0.5,far_ring.w*0.5))
			_lift(_far_material,"ringlift")
		else:
			_mid_material = _ring_shader(crown_m as ShaderMaterial,Vector2(_mid_start,hand),Vector2(FADE.z,MID.w*0.5))
			_far_material = _ring_shader(crown_m as ShaderMaterial,Vector2(hand,far_ring.z-far_ring.w*0.5),Vector2(MID.w*0.5,far_ring.w*0.5))
		if "--spruce-ring-paint=off" in LaunchArgs.user_args():
			for m: ShaderMaterial in [_mid_material,_far_material]:
				m.set_shader_parameter("spruce_paint",0.0)
				m.set_shader_parameter("spruce_texture",0)
		if "--spruce-ring-sway=off" in LaunchArgs.user_args():
			for m: ShaderMaterial in [_mid_material,_far_material]: m.set_shader_parameter("conifer_sway",false)
	var knobs := HeroTrees.spruce_paint_knobs()
	if not knobs.is_empty() and not ("--spruce-sprites=0" in LaunchArgs.user_args()):
		sprites = SpruceSprites.new()
		sprites.name = "Sprites"
		sprites.setup(_parts.map(func(p: Array) -> Array: return [p[0],p[1]]),_tint,knobs,Vector2(_far_cut,SPRITE_END),Vector2(FADE.y,SPRITE_FADE))
		add_child(sprites)
		sprites.baked.connect(_sprites_baked)
		sprites.bake.call_deferred()
		for v in _parts.size():
			for part in 2:
				var m: Material = (_parts[v][part] as Mesh).surface_get_material(0).duplicate()
				_band(m,Vector2(0.0,_far_cut),Vector2(0.0,FADE.y))
				(_crown_band if part == 1 else _trunk_band).append(m)
	_near_floor = _floor_shader(Vector4(-1.0,1.0,MID.z,MID.w))
	_far_floor = _floor_shader(Vector4(MID.z-MID.w,MID.w,far_ring.z,far_ring.w))
	if native_wanted():
		native = ClassDB.instantiate(NATIVE_CLASS)
		native.configure(_native_config())

## The native plan and building (native/terrain_kernels/tree_cell.h), when
## the library is built and current (--trees-native=0 or --gdscript-kernels:
## GDScript).
const NATIVE_CLASS := &"ZenScapeTrees"
const NATIVE_VERSION := 1
static func native_wanted() -> bool:
	var args := LaunchArgs.user_args()
	if "--trees-native=0" in args or "--gdscript-kernels" in args or "--land-native=0" in args: return false
	if not Field.native_available() or not ClassDB.class_exists(NATIVE_CLASS): return false
	var probe: Object = ClassDB.instantiate(NATIVE_CLASS)
	return probe.has_method("version") and int(probe.version()) == NATIVE_VERSION

## What ZenScapeTrees needs of the plan and the building.
func _native_config() -> Dictionary:
	var weights := Plan.variant_weights()
	return {"seed":seed,"share":share,"meadows":meadows,"gap":WorldScale.opening(Plan.TOY_GAP),"lane_open":WorldScale.opening(Plan.TOY_LANE),
		"dims":PackedVector3Array(_dims),"weights":weights,"tint":_tint,"crown_fit":PackedVector3Array(_crown_fit),"detail":_detail >= 0.0,"rings":_rings}

## A distance crown's value over the near crown's (HeroTrees SPRUCE_PAINT `knob`):
## the near crown's gaps and core read as a darker mass at range.
static func _lift(m: Material, knob: String) -> void:
	var knobs := HeroTrees.spruce_paint_knobs()
	if not m is ShaderMaterial or knobs.is_empty(): return
	(m as ShaderMaterial).set_shader_parameter("spruce_value",Vector2(knobs.value*knobs[knob],knobs.bfar))

## The rings' material (RING_SHADER) from the near crowns' painted one.
func _ring_shader(crown: ShaderMaterial, band: Vector2, fade: Vector2) -> ShaderMaterial:
	var knobs := HeroTrees.spruce_paint_knobs()
	var m := ShaderMaterial.new()
	m.shader = RING_SHADER
	m.set_shader_parameter("band",band)
	m.set_shader_parameter("fade",fade)
	m.set_shader_parameter("gain",RING_GAIN*float(knobs.get("ringgain",1.0)))
	var light: Vector4 = crown.get_shader_parameter("spruce_light")
	var tone: Vector4 = crown.get_shader_parameter("spruce_tone")
	var tone2: Vector4 = crown.get_shader_parameter("spruce_tone2")
	m.set_shader_parameter("paint",Vector4(knobs.value*knobs.ringlift,knobs.blue,crown.get_shader_parameter("spruce_bake_luma"),knobs.round))
	m.set_shader_parameter("sun",light)
	m.set_shader_parameter("tone",Vector4(tone.x,tone.y,tone2.y,tone2.w))
	m.set_shader_parameter("olive",tone2.z)
	return m

## A crown material drawn only for trees `band` m off, dithered `fade` m round each end.
static func _band(m: Material, band: Vector2, fade: Vector2) -> void:
	if not m is ShaderMaterial: return
	(m as ShaderMaterial).set_shader_parameter("lod_band_on",true)
	(m as ShaderMaterial).set_shader_parameter("lod_band",band)
	(m as ShaderMaterial).set_shader_parameter("lod_fade",fade)

func _floor_shader(band: Vector4) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FLOOR_SHADER
	m.set_shader_parameter("band",band)
	m.set_shader_parameter("colour",FLOOR_COLOUR)
	m.set_shader_parameter("strength",FLOOR_STRENGTH)
	if sprites != null:
		var knobs := HeroTrees.spruce_paint_knobs()
		m.set_shader_parameter("canopy",CANOPY)
		m.set_shader_parameter("canopy_fill",float(knobs.fill))
		m.set_shader_parameter("canopy_light",Vector4(knobs.wrap,knobs.floor,knobs.warm,knobs.hemiolive))
	return m

## The painted canopy in the sprites' mean colour once they are baked.
func _sprites_baked() -> void:
	for m: ShaderMaterial in [_near_floor,_far_floor]:
		m.set_shader_parameter("canopy_colour",sprites.mean)

func _far_shader(band: Vector4) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FAR_SHADER
	m.set_shader_parameter("band",band)
	m.set_shader_parameter("albedo",HeroTrees.spruce_far_albedo(FAR_ALBEDO))
	m.set_shader_parameter("baked",HeroTrees.spruce_far_baked(FAR_BAKED))
	return m

func _plan_for() -> RefCounted:
	var p: RefCounted = Plan.new(seed,share,_dims,_arch_flags)
	p.meadows = meadows
	return p

func _exit_tree() -> void:
	_quit = true
	for id: int in _pending.values(): WorkerThreadPool.wait_for_task_completion(id)

## Stands the blocks within PRIME m of `at` now, on this thread; with the
## native building, every block and far cell the rings want, built on the
## workers at once (so the start shows no ring still filling in).
func prime(at: Vector3) -> void:
	if not enabled: return
	_eye = at
	var began := Time.get_ticks_usec()
	if native != null:
		var ids: Array = []
		for key: Vector2i in _wanted_blocks(at,MID.z):
			if not _blocks.has(key): ids.append(WorkerThreadPool.add_task(_task.bind("b",key),true))
		for key: Vector2i in _wanted_far(at,far_ring.z):
			if not _far.has(key): ids.append(WorkerThreadPool.add_task(_task.bind("f",key),true))
		for id: int in ids: WorkerThreadPool.wait_for_task_completion(id)
		_lock.lock()
		var done := _done.duplicate()
		_done.clear()
		_lock.unlock()
		for next: Dictionary in done: _commit(next)
	else:
		var field := Field.new(seed)
		var plan := _plan_for()
		for key: Vector2i in _wanted_blocks(at,PRIME):
			if _blocks.has(key): continue
			_commit(_build("b",key,field,plan))
	stats.prime_ms = (Time.get_ticks_usec()-began)/1000.0
	_planned_at = Vector3.INF

## One frame: replanned if the eye has moved, tasks asked, finished blocks
## stood within the budget, colliders round `plane_at`.
func step(at: Vector3, plane_at: Vector3) -> void:
	if not enabled: return
	_eye = at
	if _planned_at == Vector3.INF or Vector2(at.x-_planned_at.x,at.z-_planned_at.z).length() > REPLAN:
		_planned_at = at
		_plan(at)
	for key: String in _pending.keys():
		var id: int = _pending[key]
		if WorkerThreadPool.is_task_completed(id):
			WorkerThreadPool.wait_for_task_completion(id)
			_pending.erase(key)
	while _pending.size() < TASKS and not _queue.is_empty():
		var job: Array = _queue.pop_front()
		var key: Vector2i = job[1]
		var name := "%s%d_%d" % [job[0],key.x,key.y]
		if _pending.has(name): continue
		if job[0] == "b" and _blocks.has(key): continue
		if job[0] == "f" and _far.has(key): continue
		_pending[name] = WorkerThreadPool.add_task(_task.bind(String(job[0]),key))
	var began := Time.get_ticks_usec()
	while true:
		_lock.lock()
		var next: Variant = _done.pop_front() if not _done.is_empty() else null
		_lock.unlock()
		if next == null: break
		var t0 := Time.get_ticks_usec()
		_commit(next)
		var took := (Time.get_ticks_usec()-t0)/1000.0
		if took > stats.slowest_commit_ms:
			stats.slowest_commit_ms = took
			stats.slowest_commit = "%s %s, %d trees" % [next.kind,next.key,int(next.n)]
		if (Time.get_ticks_usec()-began)/1000.0 > COMMIT_BUDGET: break
	if _detail >= 0.0: _detail_tiles(at)
	_collide(plane_at)

## The full crowns' squares within the detail distance stood, and the far
## crowns' (FAR_TILE squares) within FAR_CUT; those well past it freed (their
## trees past it draw the next crown in any case).
func _detail_tiles(at: Vector3) -> void:
	# Out to each crown's fade and the shader's slack.
	_stand_tiles(at,0,_detail+FADE.x+LOD_SLACK,DETAIL_TILE,_parts.map(func(p: Array) -> Mesh: return p[1]),_detail_material)
	_stand_tiles(at,1,_far_cut+FADE.y+LOD_SLACK,FAR_TILE,_far_crowns,_far_material_v)

func _stand_tiles(at: Vector3, kind: int, reach: float, size: float, meshes: Array, materials: Array) -> void:
	var per := int(BLOCK/size)
	var sub := int(size/DETAIL_TILE)
	var per_sub := int(BLOCK/DETAIL_TILE)
	for t: Vector4i in _tiles.keys():
		if t.w != kind: continue
		if _rect_distance(t.x*BLOCK+(t.z%per)*size,t.y*BLOCK+(t.z/per)*size,size,at) > reach+size*0.5:
			(_tiles[t] as Node).queue_free()
			_tiles.erase(t)
	if reach <= 0.0: return
	var lo := _block_of(at.x-reach,at.z-reach)
	var hi := _block_of(at.x+reach,at.z+reach)
	for bx in range(lo.x,hi.x+1):
		for bz in range(lo.y,hi.y+1):
			var key := Vector2i(bx,bz)
			if not _blocks.has(key): continue
			var b: Dictionary = _blocks[key]
			for ti in per*per:
				var t := Vector4i(bx,bz,ti,kind)
				if _tiles.has(t): continue
				if _rect_distance(bx*BLOCK+(ti%per)*size,bz*BLOCK+(ti/per)*size,size,at) > reach: continue
				# The square's trees, gathered from its DETAIL_TILE squares.
				var bufs := []
				for v in meshes.size(): bufs.append([PackedFloat32Array(),0])
				for sj in sub:
					for si in sub:
						var sti := (ti%per)*sub+si+per_sub*((ti/per)*sub+sj)
						if not (b.tiles as Dictionary).has(sti): continue
						var slots: Array = b.tiles[sti]
						for v in slots.size():
							bufs[v][0].append_array(slots[v][0])
							bufs[v][1] = int(bufs[v][1])+int(slots[v][1])
				var holder := Node3D.new()
				holder.name = "%s_%d" % [["Detail","Far"][kind],ti]
				for v in bufs.size():
					var n := int(bufs[v][1])
					if n == 0: continue
					var batch := _batch(meshes[v],bufs[v][0],n,materials[v])
					batch.name = "Spruce%dCrown" % v
					batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					holder.add_child(batch)
				(b.node as Node).add_child(holder)
				_tiles[t] = holder

# --- Streaming ---------------------------------------------------------------

func _block_of(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x/BLOCK),floori(z/BLOCK))

func _rect_distance(x0: float, z0: float, size: float, at: Vector3) -> float:
	var dx := maxf(maxf(x0-at.x,at.x-(x0+size)),0.0)
	var dz := maxf(maxf(z0-at.z,at.z-(z0+size)),0.0)
	return sqrt(dx*dx+dz*dz)

func _wanted_blocks(at: Vector3, reach: float) -> Array:
	return _wanted(at,reach,BLOCK)

func _wanted_far(at: Vector3, reach: float) -> Array:
	return _wanted(at,reach,Plan.FAR_CELL)

## The `size` m squares within `reach` of `at`, nearest first (sorted by the
## engine on [distance, x, z], no script comparator: the replan's cost).
func _wanted(at: Vector3, reach: float, size: float) -> Array:
	var near: Array = []
	var c := Vector2i(floori(at.x/size),floori(at.z/size))
	var r := int(ceil(reach/size))+1
	for dz in range(-r,r+1):
		for dx in range(-r,r+1):
			var key := c+Vector2i(dx,dz)
			var d := _rect_distance(key.x*size,key.y*size,size,at)
			if d <= reach: near.append([d,key.x,key.y])
	near.sort()
	var out: Array = []
	out.resize(near.size())
	for i in near.size(): out[i] = Vector2i(near[i][1],near[i][2])
	return out

## The queue: the blocks out to the mid ring's end, nearest first, with the
## far cells after the blocks within the near ring.
func _plan(at: Vector3) -> void:
	_queue.clear()
	var blocks := _wanted_blocks(at,MID.z)
	var fars := _wanted_far(at,far_ring.z)
	var near: Array = []
	var rest: Array = []
	for key: Vector2i in blocks:
		if _blocks.has(key): continue
		if _rect_distance(key.x*BLOCK,key.y*BLOCK,BLOCK,at) <= NEAR_END: near.append(["b",key])
		else: rest.append(["b",key])
	var far_jobs: Array = []
	for key: Vector2i in fars:
		if not _far.has(key): far_jobs.append(["f",key])
	# The near blocks, then blocks and far cells taking turns.
	_queue.append_array(near)
	var i := 0
	var j := 0
	while i < rest.size() or j < far_jobs.size():
		if i < rest.size():
			_queue.append(rest[i])
			i += 1
		if j < far_jobs.size():
			_queue.append(far_jobs[j])
			j += 1
	for key: Vector2i in _blocks.keys():
		if _rect_distance(key.x*BLOCK,key.y*BLOCK,BLOCK,at) > MID.z+BLOCK: _free_block(key)
	for key: Vector2i in _far.keys():
		if _rect_distance(key.x*Plan.FAR_CELL,key.y*Plan.FAR_CELL,Plan.FAR_CELL,at) > far_ring.z+Plan.FAR_CELL*0.5:
			var gone: MultiMeshInstance3D = _far[key]
			stats.far_trees -= gone.multimesh.instance_count
			gone.queue_free()
			_far.erase(key)
			stats.far = _far.size()

func _task(kind: String, key: Vector2i) -> void:
	if _quit: return
	var field := Field.new(seed)
	var plan := _plan_for()
	var result: Dictionary = _build(kind,key,field,plan)
	_lock.lock()
	_done.append(result)
	_lock.unlock()

# --- Building (on a worker) ------------------------------------------------------

## A block ("b") or far cell ("f"), natively when it can be.
func _build(kind: String, key: Vector2i, field: RefCounted, plan: RefCounted) -> Dictionary:
	var impl: Object = field.native_impl() if native != null else null
	if impl == null: return _build_block(key,field,plan) if kind == "b" else _build_far(key,field,plan)
	var began := Time.get_ticks_usec()
	var size := BLOCK if kind == "b" else Plan.FAR_CELL
	var x0 := key.x*size
	var z0 := key.y*size
	var arches: PackedFloat64Array = plan.arches_flat(field,x0,z0,x0+size,z0+size)
	var pad: float = plan.sample_pad()
	var ponds: Array = field.ponds_in(x0-pad,z0-pad,x0+size+pad,z0+size+pad)
	if kind == "f":
		var far: Dictionary = native.far(impl,key,arches,ponds,_floor)
		return {"kind":"f","key":key,"buf":far.buf,"n":int(far.n),"floor":far.floor,"ms":(Time.get_ticks_usec()-began)/1000.0}
	var got: Dictionary = native.block(impl,key,arches,ponds,hash([seed,key.x,key.y,"trees"]),_floor)
	var all: PackedFloat32Array = got.all
	var n := all.size()/Plan.STRIDE
	var cells := _cells(key,all)
	return {"kind":"b","key":key,"cells":cells,"near":got.near,"mid":got.mid,"n":n,"floor":got.floor,"ms":(Time.get_ticks_usec()-began)/1000.0,"tiles":got.tiles}

## A block's plan cells' lookups from its trees (`_lookup` each).
func _cells(key: Vector2i, all: PackedFloat32Array) -> Dictionary:
	var per := int(BLOCK/Plan.CELL)
	var split := {}
	for q in range(0,all.size(),Plan.STRIDE):
		var ck := Plan.cell_of(all[q],all[q+2])
		if not split.has(ck): split[ck] = PackedFloat32Array()
		var list: PackedFloat32Array = split[ck]
		list.append_array(all.slice(q,q+Plan.STRIDE))
		split[ck] = list
	var cells := {}
	for j in per:
		for i in per:
			var ck := Vector2i(key.x*per+i,key.y*per+j)
			cells[ck] = _lookup(ck,split.get(ck,PackedFloat32Array()))
	return cells

## A block's trees: its plan cells' trees, the near batches' buffers (per
## variant and part), the mid crowns' buffer and each cell's lookup.
func _build_block(key: Vector2i, field: RefCounted, plan: RefCounted) -> Dictionary:
	var began := Time.get_ticks_usec()
	var all: PackedFloat32Array = plan.area(field,key.x*BLOCK,key.y*BLOCK,BLOCK)
	var cells := _cells(key,all)
	var n := all.size()/Plan.STRIDE
	var variants := _dims.size()
	var near: Array = []
	for v in variants: near.append([PackedFloat32Array(),PackedFloat32Array(),0])
	var mid := PackedFloat32Array()
	# The full crowns by DETAIL_TILE square: tile index -> variant -> [buffer, count].
	var tiles := {}
	var per_tile := int(BLOCK/DETAIL_TILE)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed,key.x,key.y,"trees"])
	for t in n:
		var q := t*Plan.STRIDE
		var at := Vector3(all[q],all[q+1],all[q+2])
		var sc := all[q+3]
		var wide := all[q+4]
		var yaw := all[q+5]
		var v := int(all[q+6])
		var basis := Basis(Vector3.UP,yaw).scaled(Vector3(sc*wide,sc,sc*wide))
		var tone := _tint*rng.randf_range(TINT_SPREAD.x,TINT_SPREAD.y)
		var slot: Array = near[v]
		_put(slot[0],basis,at,Color.WHITE)
		_put(slot[1],basis,at,tone)
		slot[2] = int(slot[2])+1
		if _detail >= 0.0:
			var ti := clampi(int((at.x-key.x*BLOCK)/DETAIL_TILE),0,per_tile-1)+per_tile*clampi(int((at.z-key.y*BLOCK)/DETAIL_TILE),0,per_tile-1)
			if not tiles.has(ti):
				var empty := []
				for u in variants: empty.append([PackedFloat32Array(),0])
				tiles[ti] = empty
			var ts: Array = tiles[ti][v]
			_put(ts[0],basis,at,tone)
			ts[1] = int(ts[1])+1
		var fit: Vector3 = _crown_fit[v]
		# The sprays' rings take over from the mid crown, so stand full size in the crown's tint.
		var cb := Basis(Vector3.UP,yaw).scaled(Vector3(sc*wide*fit.x,sc*fit.y,sc*wide*fit.x)*(1.0 if _rings else MID_SIZE))
		_put(mid,cb,at+Vector3(0.0,fit.z*sc,0.0),tone if _rings else Color(tone.r/_tint.r,tone.g/_tint.g,tone.b/_tint.b))
	var ground: Dictionary = _floor_arrays(plan.floor_grid(field,key.x*BLOCK,key.y*BLOCK,BLOCK,FLOOR_STEP)) if _floor else {}
	var ms := (Time.get_ticks_usec()-began)/1000.0
	return {"kind":"b","key":key,"cells":cells,"near":near,"mid":mid,"n":n,"floor":ground,"ms":ms,"tiles":tiles}

## The far cell's crowns' buffer.
func _build_far(key: Vector2i, field: RefCounted, plan: RefCounted) -> Dictionary:
	var began := Time.get_ticks_usec()
	var far: Dictionary = plan.far_cell(field,key.x,key.y)
	var trees: PackedFloat32Array = far.trees
	var n := trees.size()/Plan.STRIDE
	var buf := PackedFloat32Array()
	for t in n:
		var q := t*Plan.STRIDE
		var v := int(trees[q+6])
		var fit: Vector3 = _crown_fit[v]
		var sc := trees[q+3]
		var wide := trees[q+4]
		var cb := Basis(Vector3.UP,trees[q+5]).scaled(Vector3(sc*wide*fit.x,sc*fit.y,sc*wide*fit.x))
		var shade := lerpf(TINT_SPREAD.x,TINT_SPREAD.y,fposmod(trees[q]*0.37+trees[q+2]*0.61,1.0))
		_put(buf,cb,Vector3(trees[q],trees[q+1]+fit.z*sc,trees[q+2]),_tint*shade if _rings else Color(shade,shade,shade))
	var ground: Dictionary = _floor_arrays(far) if _floor else {}
	return {"kind":"f","key":key,"buf":buf,"n":n,"floor":ground,"ms":(Time.get_ticks_usec()-began)/1000.0}

## The floor's sheet from a grid (TreePlan `floor_grid`, `far_cell`):
## each weight softened by its eight neighbours, the quads from the grid's
## own nodes (two in from its edge) to the next, so neighbouring squares
## meet with no gap; {} if no weight.
func _floor_arrays(g: Dictionary) -> Dictionary:
	var n := int(g.n)
	var hs: PackedFloat32Array = g.h
	var raw: PackedFloat32Array = g.w
	if raw.is_empty(): return {}
	var step := float(g.step)
	var ox := float(g.x)
	var oz := float(g.z)
	var wn := n-2
	# Softened weights at nodes 1..n-2 of the height grid (raw's 0..wn-1).
	var ws := PackedFloat32Array()
	ws.resize(n*n)
	var any := false
	for j in range(2,n-1):
		for i in range(2,n-1):
			var sum := 0.0
			for dj in range(-1,2):
				for di in range(-1,2):
					var ri := clampi(i-1+di,0,wn-1)
					var rj := clampi(j-1+dj,0,wn-1)
					sum += raw[rj*wn+ri]
			ws[j*n+i] = sum/9.0
			if sum > 0.18: any = true
	if not any: return {}
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colours := PackedColorArray()
	var index := PackedInt32Array()
	var at := PackedInt32Array()
	at.resize(n*n)
	at.fill(-1)
	for j in range(2,n-2):
		for i in range(2,n-2):
			if maxf(maxf(ws[j*n+i],ws[j*n+i+1]),maxf(ws[(j+1)*n+i],ws[(j+1)*n+i+1])) <= 0.02: continue
			var q: Array = []
			for c: Vector2i in [Vector2i(i,j),Vector2i(i+1,j),Vector2i(i+1,j+1),Vector2i(i,j+1)]:
				var k := c.y*n+c.x
				if at[k] < 0:
					at[k] = verts.size()
					verts.append(Vector3(ox+c.x*step,hs[k],oz+c.y*step))
					normals.append(Vector3(hs[k-1]-hs[k+1],step*2.0,hs[k-n]-hs[k+n]).normalized())
					colours.append(Color(1,1,1,ws[k]))
				q.append(at[k])
			index.append_array([q[0],q[1],q[2],q[0],q[2],q[3]])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = index
	return {"arrays":arrays}

func _floor_node(ground: Dictionary, material: Material) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,ground.arrays)
	var mi := MeshInstance3D.new()
	mi.name = "Floor"
	mi.mesh = mesh
	mi.material_override = material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("skip_reflection",true)
	return mi

## A MultiMesh instance (TRANSFORM_3D with colours: 12 + 4 floats).
static func _put(buf: PackedFloat32Array, b: Basis, o: Vector3, c: Color) -> void:
	buf.append_array([b.x.x,b.y.x,b.z.x,o.x,b.x.y,b.y.y,b.z.y,o.y,b.x.z,b.y.z,b.z.z,o.z,c.r,c.g,c.b,c.a])

## A plan cell's trees for the flight: Vector4s of [x, z, foot y, top] and
## [crown bottom over the foot, solid reach, -, -], bucketed BUCKET m.
func _lookup(ck: Vector2i, trees: PackedFloat32Array) -> Dictionary:
	var n := trees.size()/Plan.STRIDE
	var solid := PackedFloat32Array()
	var buckets := {}
	var wing := WorldScale.span*0.5*WING_SOLID
	for t in n:
		var q := t*Plan.STRIDE
		var d: Vector3 = _dims[int(trees[q+6])]
		var sc := trees[q+3]
		var reach := d.x*sc*trees[q+4]*CROWN_SOLID+wing
		solid.append_array([trees[q],trees[q+2],trees[q+1],d.y*sc,d.z*sc,reach,d.x*sc*trees[q+4]*CROWN_SOLID,0.0])
		var b := Vector2i(floori(trees[q]/BUCKET),floori(trees[q+2]/BUCKET))
		if not buckets.has(b): buckets[b] = PackedInt32Array()
		var list: PackedInt32Array = buckets[b]
		list.append(t)
		buckets[b] = list
	return {"solid":solid,"buckets":buckets,"n":n}

# --- Standing (main thread) --------------------------------------------------------

func _commit(done: Dictionary) -> void:
	var key: Vector2i = done.key
	stats.plan_ms += float(done.ms)
	stats.plans += 1
	stats.slowest_plan_ms = maxf(stats.slowest_plan_ms,float(done.ms))
	if done.kind == "f":
		if _far.has(key) or _rect_distance(key.x*Plan.FAR_CELL,key.y*Plan.FAR_CELL,Plan.FAR_CELL,_eye) > far_ring.z+Plan.FAR_CELL: return
		if not world.uniform and not world.layer_at(&"trees",(key.x+0.5)*Plan.FAR_CELL,(key.y+0.5)*Plan.FAR_CELL):
			var bare := _batch(_crown,PackedFloat32Array(),0,null)
			bare.name = "Far_%d_%d" % [key.x,key.y]
			add_child(bare)
			_far[key] = bare
			return
		# With sprites the far cells stand no crowns, only the floor (the painted canopy).
		var far_n := 0 if sprites != null else int(done.n)
		var node := _batch(_crown,done.buf if far_n > 0 else PackedFloat32Array(),far_n,_far_material)
		node.name = "Far_%d_%d" % [key.x,key.y]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if not (done.floor as Dictionary).is_empty(): node.add_child(_floor_node(done.floor,_far_floor))
		add_child(node)
		_far[key] = node
		stats.far = _far.size()
		stats.far_trees += far_n
		return
	if _blocks.has(key) or _rect_distance(key.x*BLOCK,key.y*BLOCK,BLOCK,_eye) > MID.z+BLOCK*2.0: return
	if not world.uniform and not world.layer_at(&"trees",(key.x+0.5)*BLOCK,(key.y+0.5)*BLOCK):
		_blocks[key] = {"node":_bare("Block_%d_%d" % [key.x,key.y]),"cells":{},"n":0,"tiles":{}}
		return
	var holder := Node3D.new()
	holder.name = "Block_%d_%d" % [key.x,key.y]
	for v in done.near.size():
		var slot: Array = done.near[v]
		if int(slot[2]) == 0: continue
		for part in 2:
			if sprites != null:
				# With sprites: the trunks, and the full crowns when every near tree
				# has one, banded to FAR_CUT; the sprites take over past it.
				if part == 1 and _detail >= 0.0: continue
				var near := _batch(_parts[v][part],slot[part],int(slot[2]),(_crown_band if part == 1 else _trunk_band)[v])
				near.name = "Spruce%d%s" % [v,"Crown" if part == 1 else "Trunk"]
				near.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				near.visibility_range_end = _far_cut+FADE.y+LOD_SLACK
				holder.add_child(near)
				continue
			# With far crowns, the block draws the family's crown past FAR_CUT;
			# the full and far crowns stand in their squares (_detail_tiles).
			var family := part == 1 and _detail >= 0.0
			var batch := _batch(_family_crowns[v] if family else _parts[v][part],slot[part],int(slot[2]),_family_material_v[v] if family else null)
			batch.name = "Spruce%d%s" % [v,"Crown" if part == 1 else "Trunk"]
			batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# The sprays' mid crowns reach past the trunks (MID_START), each tree's own fade.
			batch.visibility_range_end = _mid_start+MID_CROWN_END-MID_START if family and _rings else NEAR_END
			batch.visibility_range_end_margin = NEAR_MARGIN
			batch.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED if family and _rings else GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			holder.add_child(batch)
	if int(done.n) > 0 and sprites != null:
		for v in done.near.size():
			var slot: Array = done.near[v]
			if int(slot[2]) == 0: continue
			var sprite := _batch(sprites.quad,slot[1],int(slot[2]),sprites.materials[v])
			sprite.name = "Spruce%dSprite" % v
			sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# The quads stand up from each foot (the batch's bounds are the feet).
			sprite.extra_cull_margin = sprites.size*3.0
			holder.add_child(sprite)
	if int(done.n) > 0:
		if sprites == null:
			var mid := _batch(_crown,done.mid,int(done.n),_mid_material)
			mid.name = "Mid"
			mid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			holder.add_child(mid)
		if _shadows:
			# The near trees' shadows, cast by their faceted crowns (a tenth
			# of the faces, one batch a block): SHADOWS_ONLY.
			var shade := _batch(_shadow_crown,done.mid,int(done.n),_shade_material)
			shade.name = "Shade"
			shade.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			shade.visibility_range_end = NEAR_END
			shade.visibility_range_end_margin = NEAR_MARGIN
			holder.add_child(shade)
	if not (done.floor as Dictionary).is_empty(): holder.add_child(_floor_node(done.floor,_near_floor))
	add_child(holder)
	_blocks[key] = {"node":holder,"cells":done.cells,"n":int(done.n),"tiles":done.get("tiles",{})}
	stats.blocks = _blocks.size()
	stats.trees += int(done.n)

## An empty block, where the world's regions say no woods.
func _bare(node_name: String) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	add_child(n)
	return n

func _batch(mesh: Mesh, buf: PackedFloat32Array, count: int, material: Material) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	if count > 0: mm.buffer = buf
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = mm
	if material != null: batch.material_override = material
	batch.set_meta("skip_reflection",true)
	return batch

func _free_block(key: Vector2i) -> void:
	var b: Dictionary = _blocks[key]
	(b.node as Node).queue_free()
	for t: Vector4i in _tiles.keys():
		if t.x == key.x and t.y == key.y: _tiles.erase(t)
	stats.trees -= int(b.n)
	for ck: Vector2i in b.cells:
		if _bodies.has(ck):
			(_bodies[ck] as Node).queue_free()
			_bodies.erase(ck)
			_filling.erase(ck)
	_blocks.erase(key)
	stats.blocks = _blocks.size()

# --- The solid -----------------------------------------------------------------

func _cell_data(ck: Vector2i) -> Variant:
	var per := int(BLOCK/Plan.CELL)
	var b: Variant = _blocks.get(Vector2i(floori(float(ck.x)/per),floori(float(ck.y)/per)))
	if b == null: return null
	return (b as Dictionary).cells.get(ck)

## The stood trees of plan cell `ck`, 8 floats each (x, z, foot y, height,
## crown bottom over the foot, solid reach, crown radius, 0), or none: the
## birds' perches (scripts/endless/endless_birds.gd).
func cell_trees(ck: Vector2i) -> PackedFloat32Array:
	var cell: Variant = _cell_data(ck)
	return (cell as Dictionary).solid if cell != null else PackedFloat32Array()

## The tallest tree solid over world XZ `p` (world y), or -INF.
func top_at(p: Vector3) -> float:
	if _blocks.is_empty(): return -INF
	var best := -INF
	var bx := floori(p.x/BUCKET)
	var bz := floori(p.z/BUCKET)
	for dz in range(-1,2):
		for dx in range(-1,2):
			var b := Vector2i(bx+dx,bz+dz)
			var cell: Variant = _cell_data(Plan.cell_of((b.x+0.5)*BUCKET,(b.y+0.5)*BUCKET))
			if cell == null: continue
			var list: Variant = (cell as Dictionary).buckets.get(b)
			if list == null: continue
			var solid: PackedFloat32Array = (cell as Dictionary).solid
			for t: int in list:
				var q := t*8
				var ox := p.x-solid[q]
				var oz := p.z-solid[q+1]
				var reach := solid[q+5]
				var d2 := ox*ox+oz*oz
				if d2 >= reach*reach: continue
				# A cone from the crown's foot (its reach) to its top.
				var bottom := solid[q+2]+solid[q+4]
				var top := solid[q+2]+solid[q+3]
				best = maxf(best,lerpf(top,bottom,sqrt(d2)/reach))
	return best

## SkyGlide's `ground` over what the arches gave (`under`: the land's height,
## or Vector2(top, underside) for a span): a tree raises the land to its top.
func ground(p: Vector3, under: Variant) -> Variant:
	if not enabled or under is Vector2: return under
	var t := top_at(p)
	return maxf(float(under),t) if t > -INF else under

## True inside a tree's solid (the rolling plane stops).
func inside(p: Vector3) -> bool:
	if not enabled: return false
	return p.y < top_at(p)

# --- Colliders --------------------------------------------------------------------

func _collide(at: Vector3) -> void:
	for ck: Vector2i in _bodies.keys():
		if _rect_distance(ck.x*Plan.CELL,ck.y*Plan.CELL,Plan.CELL,at) > COLLIDE*1.5:
			(_bodies[ck] as Node).queue_free()
			_bodies.erase(ck)
			_filling.erase(ck)
	var t0 := Time.get_ticks_usec()
	# The bodies begun, nearest cell first, filled within the budget.
	for ck: Vector2i in _filling.keys():
		var cell: Variant = _cell_data(ck)
		if cell == null:
			_filling.erase(ck)
			continue
		_filling[ck] = _fill(_bodies[ck],cell,int(_filling[ck]),t0)
		if int(_filling[ck]) >= int((cell as Dictionary).n): _filling.erase(ck)
		if (Time.get_ticks_usec()-t0)/1000.0 > COLLIDE_BUDGET: break
	var c := Plan.cell_of(at.x,at.z)
	# At most one plan cell's body begun a frame.
	for dz in range(-1,2):
		for dx in range(-1,2):
			var ck := c+Vector2i(dx,dz)
			if _bodies.has(ck) or _rect_distance(ck.x*Plan.CELL,ck.y*Plan.CELL,Plan.CELL,at) > COLLIDE: continue
			var cell: Variant = _cell_data(ck)
			if cell == null: continue
			_bodies[ck] = _body(ck)
			var done := _fill(_bodies[ck],cell,0,t0)
			if done < int((cell as Dictionary).n): _filling[ck] = done
			stats.slowest_collider_ms = maxf(float(stats.get("slowest_collider_ms",0.0)),(Time.get_ticks_usec()-t0)/1000.0)
			stats.colliders = _bodies.size()
			return
	stats.slowest_collider_ms = maxf(float(stats.get("slowest_collider_ms",0.0)),(Time.get_ticks_usec()-t0)/1000.0)

## A plan cell's body, its shapes added by `_fill`.
func _body(ck: Vector2i) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Trees_%d_%d" % [ck.x,ck.y]
	body.collision_layer = LAYER
	body.collision_mask = 0
	add_child(body)
	return body

## The cell's trees from `from` added to its body as convex spinning tops (the
## trunk's foot, the crown's widest ring: its reach, CROWN_SOLID, the top)
## until COLLIDE_BUDGET ms past `began`; the next tree to add.
func _fill(body: StaticBody3D, cell: Dictionary, from: int, began: int) -> int:
	var solid: PackedFloat32Array = cell.solid
	var t := from
	while t < int(cell.n):
		if t > from and (Time.get_ticks_usec()-began)/1000.0 > COLLIDE_BUDGET: break
		var q := t*8
		var r := solid[q+6]
		var bottom := solid[q+4]
		var top := solid[q+3]
		var points := PackedVector3Array()
		for k in 6:
			var a := TAU*k/6.0
			points.append(Vector3(cos(a)*0.3,0.0,sin(a)*0.3))
			points.append(Vector3(cos(a)*r,bottom,sin(a)*r))
		points.append(Vector3(0.0,top,0.0))
		var shape := ConvexPolygonShape3D.new()
		shape.points = points
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = Vector3(solid[q],solid[q+2],solid[q+1])
		body.add_child(cs)
		t += 1
	return t

## The numbers line (F1).
func note() -> String:
	if not enabled: return "\nno trees"
	return "\ntrees: %d in %d blocks, %dk far in %d cells  ·  %.0f ms a plan on a worker (slowest %.0f), slowest stand %.2f ms (%s), %d collider cells (slowest %.2f ms)" % [
		int(stats.trees),int(stats.blocks),int(stats.far_trees)/1000,int(stats.far),float(stats.plan_ms)/maxf(float(stats.plans),1.0),float(stats.slowest_plan_ms),float(stats.slowest_commit_ms),String(stats.slowest_commit),int(stats.colliders),float(stats.get("slowest_collider_ms",0.0))]
