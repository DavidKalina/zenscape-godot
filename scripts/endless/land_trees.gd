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
## A world of regions: the far cells in a border's band past this (m) are
## left to stream after the start (see prime).
const PRIME_BAND_FAR := 2000.0
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
## The floor is see-through but lies on the land, so it draws before the
## clouds' sheet (EndlessClouds RENDER_PRIORITY -6) and after the sea
## (EndlessLook SEA_PRIORITY -8): drawn after the sheet it painted itself
## over a low cloud wherever no crown hid it, and the crowns showed through
## as pale cut-outs.
const FLOOR_PRIORITY := -7
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
## A world of regions: each region's woods by region index, {share,
## meadows, weights (the variants'), native (its ZenScapeTrees, or null)};
## empty in a one-profile world.
var regional: Array = []
var stats := {"blocks":0,"far":0,"trees":0,"far_trees":0,"plan_ms":0.0,"plans":0,"slowest_plan_ms":0.0,"slowest_commit_ms":0.0,"slowest_commit":"","colliders":0,"knocked":0}

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
	return flags_of(WorldProfile.current())

## A profile's woods {on, share, meadows, floor}, the flags over it (each
## region's, in a world of regions).
static func flags_of(w: RefCounted) -> Dictionary:
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
	if not world.uniform:
		# Each region's woods (the flags over each); the woods stand if any region's do.
		var any := false
		for p: RefCounted in world.regions:
			var rf := flags_of(p)
			any = any or rf.on
			regional.append({"share":rf.share if rf.on else 0.0,"meadows":rf.meadows,"weights":Plan.weights_of(p),"native":null})
		enabled = any and not ("--no-trees" in LaunchArgs.user_args())
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
		for r in regional.size():
			var rn: Object = ClassDB.instantiate(NATIVE_CLASS)
			rn.configure(_native_config(r))
			regional[r].native = rn

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
func _native_config(r := -1) -> Dictionary:
	var weights: PackedFloat32Array = Plan.variant_weights() if r < 0 else regional[r].weights
	return {"seed":seed,"share":share if r < 0 else float(regional[r].share),"meadows":meadows if r < 0 else float(regional[r].meadows),"gap":WorldScale.opening(Plan.TOY_GAP),"lane_open":WorldScale.opening(Plan.TOY_LANE),
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
	m.render_priority = FLOOR_PRIORITY
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

## The plan (region `r`'s, in a world of regions: its share, meadows and
## variant weights).
func _plan_for(r := -1) -> RefCounted:
	if r < 0 or regional.is_empty():
		var p: RefCounted = Plan.new(seed,share,_dims,_arch_flags)
		p.meadows = meadows
		return p
	var g: Dictionary = regional[r]
	var q: RefCounted = Plan.new(seed,float(g.share),_dims,_arch_flags)
	q.meadows = float(g.meadows)
	q._weights = g.weights
	return q

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
		# A world of regions: the band's far cells past PRIME_BAND_FAR are
		# left to stream (their GDScript blend builds are ~10x a native one's
		# and scale badly over threads, so priming them held the start ~25 s).
		var probe: RefCounted = Field.new(seed) if not regional.is_empty() else null
		for key: Vector2i in _wanted_blocks(at,MID.z):
			if _blocks.has(key): continue
			ids.append(WorkerThreadPool.add_task(_task.bind("b",key),true))
		for key: Vector2i in _wanted_far(at,far_ring.z):
			if _far.has(key): continue
			if probe != null and _rect_distance(key.x*Plan.FAR_CELL,key.y*Plan.FAR_CELL,Plan.FAR_CELL,at) > PRIME_BAND_FAR and _in_band(probe,"f",key): continue
			ids.append(WorkerThreadPool.add_task(_task.bind("f",key),true))
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

## Whether block ("b") or far cell ("f") `key` meets a region border's band
## (built by _build_mixed), in a world of regions.
func _in_band(field: RefCounted, kind: String, key: Vector2i) -> bool:
	var size := BLOCK if kind == "b" else Plan.FAR_CELL
	var pad: float = _plan_for().sample_pad()
	return field.region_in(key.x*size-pad,key.y*size-pad,(key.x+1)*size+pad,(key.y+1)*size+pad) < 0

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

## A block ("b") or far cell ("f"), natively when it can be, its forest
## floor kept off the split mountains' cuts (`_floor_off_cuts`).
func _build(kind: String, key: Vector2i, field: RefCounted, plan: RefCounted) -> Dictionary:
	var got := _build_raw(kind,key,field,plan)
	if got.has("floor"): got.floor = _floor_off_cuts(got.floor,field)
	return got

## Forest floor `floor` ({arrays}, `_floor_arrays`'s or the native one's)
## without its triangles that have a corner on a split mountain's cut
## (split_sites.gd). The native building drapes the floor over the native
## field, which knows nothing of the splits (a layer LandField cuts in after
## it), so over a canyon the sheet hung at the old ground's height, see-
## through in the air where the rock was carved away; and on the floor's
## coarse lattice (FLOOR_STEP, TreePlan.FAR_SLOT) even the GDScript one's
## triangles reach from the rim across the canyon. Off the cut the two
## fields' heights are the same, so what is kept lies on the land.
static func _floor_off_cuts(floor: Dictionary, field: RefCounted) -> Dictionary:
	if floor.is_empty() or not field.has_method("splits_in"): return floor
	var arrays: Array = floor.arrays
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if verts.is_empty(): return floor
	var box := AABB(verts[0],Vector3.ZERO)
	for v: Vector3 in verts: box = box.expand(v)
	var cuts: Array = field.splits_in(box.position.x,box.position.z,box.end.x,box.end.z)
	if cuts.is_empty(): return floor
	const Splits = preload("res://scripts/endless/split_sites.gd")
	var on := PackedByteArray()
	on.resize(verts.size())
	var any := false
	for k in verts.size():
		for s: PackedFloat32Array in cuts:
			if Splits.on_cut(s,verts[k].x,verts[k].z):
				on[k] = 1
				any = true
				break
	if not any: return floor
	var kept := PackedInt32Array()
	for t in range(0,index.size(),3):
		if on[index[t]]+on[index[t+1]]+on[index[t+2]] == 0: kept.append_array([index[t],index[t+1],index[t+2]])
	if kept.is_empty(): return {}
	var out := arrays.duplicate()
	out[Mesh.ARRAY_INDEX] = kept
	return {"arrays":out}

func _build_raw(kind: String, key: Vector2i, field: RefCounted, plan: RefCounted) -> Dictionary:
	var size := BLOCK if kind == "b" else Plan.FAR_CELL
	var x0 := key.x*size
	var z0 := key.y*size
	var pad: float = plan.sample_pad()
	var nat: Object = native
	if not regional.is_empty():
		# A world of regions: where the block lies wholly in one region, that
		# region's woods (its plan and native building over its own native
		# field); in the band each region's plan over the blend, its trees
		# dithered by the weights (_build_mixed).
		var r: int = field.region_in(x0-pad,z0-pad,x0+size+pad,z0+size+pad)
		if r < 0: return _build_mixed(kind,key,field)
		plan = _plan_for(r)
		nat = regional[r].native
	var impl: Object = field.native_impl_in(x0-pad,z0-pad,x0+size+pad,z0+size+pad) if nat != null else null
	if impl == null: return _build_block(key,field,plan) if kind == "b" else _build_far(key,field,plan)
	var began := Time.get_ticks_usec()
	var arches: PackedFloat64Array = plan.arches_flat(field,x0,z0,x0+size,z0+size)
	var ponds: Array = field.ponds_in(x0-pad,z0-pad,x0+size+pad,z0+size+pad)
	if kind == "f":
		var far: Dictionary = nat.far(impl,key,arches,ponds,_floor)
		return {"kind":"f","key":key,"buf":far.buf,"n":int(far.n),"floor":far.floor,"ms":(Time.get_ticks_usec()-began)/1000.0}
	var got: Dictionary = nat.block(impl,key,arches,ponds,hash([seed,key.x,key.y,"trees"]),_floor)
	var all: PackedFloat32Array = got.all
	var n := all.size()/Plan.STRIDE
	var cells := _cells(key,all)
	return {"kind":"b","key":key,"cells":cells,"near":got.near,"mid":got.mid,"n":n,"floor":got.floor,"ms":(Time.get_ticks_usec()-began)/1000.0,"tiles":got.tiles}

## A block's plan cells' lookups from its trees (`_lookup` each), each tree's
## place in the block's batches beside it (`slots`: variant, index in that
## variant's near batches, index in the block's: `_block_from`'s order).
func _cells(key: Vector2i, all: PackedFloat32Array) -> Dictionary:
	var per := int(BLOCK/Plan.CELL)
	var split := {}
	var slots := {}
	var counts := PackedInt32Array()
	counts.resize(maxi(_dims.size(),1))
	for q in range(0,all.size(),Plan.STRIDE):
		var ck := Plan.cell_of(all[q],all[q+2])
		if not split.has(ck):
			split[ck] = PackedFloat32Array()
			slots[ck] = PackedInt32Array()
		var list: PackedFloat32Array = split[ck]
		list.append_array(all.slice(q,q+Plan.STRIDE))
		split[ck] = list
		var v := clampi(int(all[q+6]),0,counts.size()-1)
		var at: PackedInt32Array = slots[ck]
		at.append_array([v,counts[v],q/Plan.STRIDE])
		slots[ck] = at
		counts[v] += 1
	var cells := {}
	for j in per:
		for i in per:
			var ck := Vector2i(key.x*per+i,key.y*per+j)
			cells[ck] = _lookup(ck,split.get(ck,PackedFloat32Array()))
			cells[ck].slots = slots.get(ck,PackedInt32Array())
	return cells

## A block's trees: its plan cells' trees, the near batches' buffers (per
## variant and part), the mid crowns' buffer and each cell's lookup.
func _build_block(key: Vector2i, field: RefCounted, plan: RefCounted) -> Dictionary:
	var began := Time.get_ticks_usec()
	var all: PackedFloat32Array = plan.area(field,key.x*BLOCK,key.y*BLOCK,BLOCK)
	var grid: Dictionary = plan.floor_grid(field,key.x*BLOCK,key.y*BLOCK,BLOCK,FLOOR_STEP) if _floor else {}
	return _block_from(key,all,grid,began)

## A block's result from its trees and floor grid (TreePlan `floor_grid`, {} none).
func _block_from(key: Vector2i, all: PackedFloat32Array, grid: Dictionary, began: int) -> Dictionary:
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
	var ground: Dictionary = _floor_arrays(grid) if not grid.is_empty() else {}
	var ms := (Time.get_ticks_usec()-began)/1000.0
	return {"kind":"b","key":key,"cells":cells,"near":near,"mid":mid,"n":n,"floor":ground,"ms":ms,"tiles":tiles}

## The far cell's crowns' buffer.
func _build_far(key: Vector2i, field: RefCounted, plan: RefCounted) -> Dictionary:
	return _far_from(key,plan.far_cell(field,key.x,key.y),Time.get_ticks_usec())

## A far cell's result from its plan (TreePlan `far_cell`).
func _far_from(key: Vector2i, far: Dictionary, began: int) -> Dictionary:
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

## The square (m) a band tree's dither is drawn for (so where two regions'
## plans stand the same tree, one of the two is kept), and its warp (m), so
## the squares draw no lines.
const DITHER := 6.0
const DITHER_WARP := 9.0

## A block or far cell in the band, in a world of regions: each region's
## plan over the blended land, each tree kept from the region the dither
## picks at its spot (TreePlan positions come from the seed and the spot,
## so where two regions' woods both stand a tree there, one is kept), the
## forest floor's weights blended by the land's weights at each node.
func _build_mixed(kind: String, key: Vector2i, field: RefCounted) -> Dictionary:
	var began := Time.get_ticks_usec()
	var size := BLOCK if kind == "b" else Plan.FAR_CELL
	var x0 := key.x*size
	var z0 := key.y*size
	# The regions met in the square (the land's weights on a 64 m grid).
	var meet := {}
	var step := 64.0
	for j in int(size/step)+1:
		for i in int(size/step)+1:
			var w: PackedFloat32Array = field.region_weights(x0+i*step,z0+j*step)
			for r in w.size():
				if w[r] > 0.0: meet[r] = true
	var all := PackedFloat32Array()
	var grid := {}
	var far := {}
	for r: int in meet:
		if float(regional[r].share) <= 0.0: continue
		var plan := _plan_for(r)
		var trees: PackedFloat32Array
		var g: Dictionary
		if kind == "b":
			trees = plan.area(field,x0,z0,BLOCK)
			g = plan.floor_grid(field,x0,z0,BLOCK,FLOOR_STEP) if _floor else {}
		else:
			g = plan.far_cell(field,key.x,key.y)
			trees = g.trees
		for q in range(0,trees.size(),Plan.STRIDE):
			if _dither_pick(field,trees[q],trees[q+2]) == r: all.append_array(trees.slice(q,q+Plan.STRIDE))
		if g.is_empty() or (g.w as PackedFloat32Array).is_empty(): continue
		grid = _blend_floor(grid,g,field,r)
		if kind == "f": far = g
	if kind == "b":
		return _block_from(key,all,grid if _floor else {},began)
	if far.is_empty():
		far = {"h":PackedFloat32Array(),"w":PackedFloat32Array(),"n":0,"x":0.0,"z":0.0,"step":Plan.FAR_SLOT}
	else:
		far = far.duplicate()
		far.w = grid.w
	far.trees = all
	return _far_from(key,far,began)

## The region the dither picks for a band tree at (x, z).
func _dither_pick(field: RefCounted, x: float, z: float) -> int:
	var wx := x+DITHER_WARP*sin(z*0.071+x*0.013)
	var wz := z+DITHER_WARP*sin(x*0.083-z*0.017)
	var u := float(hash([seed,floori(wx/DITHER),floori(wz/DITHER),"region"]) & 0xffffff)/16777216.0
	return field.region_pick(x,z,u)

## `acc` (a floor grid, or {}) plus region r's grid `g`, its weights each
## times r's land weight at the node.
static func _blend_floor(acc: Dictionary, g: Dictionary, field: RefCounted, r: int) -> Dictionary:
	var n := int(g.n)
	var step := float(g.step)
	var gw: PackedFloat32Array = g.w
	var out := acc
	if out.is_empty():
		out = g.duplicate()
		var zero := PackedFloat32Array()
		zero.resize(gw.size())
		out.w = zero
	var ws: PackedFloat32Array = out.w
	for j in range(1,n-1):
		for i in range(1,n-1):
			var k := (j-1)*(n-2)+i-1
			if gw[k] <= 0.0: continue
			var lw: PackedFloat32Array = field.region_weights(float(g.x)+i*step,float(g.z)+j*step)
			ws[k] += gw[k]*(lw[r] if r < lw.size() else 0.0)
	out.w = ws
	return out

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
## [crown bottom over the foot, solid reach, crown radius, knocked (0, or 1
## once `knock`ed: its top, reach and radius 0)], bucketed BUCKET m; `pose`
## each tree's scale, wide and yaw (the falling copy's).
func _lookup(ck: Vector2i, trees: PackedFloat32Array) -> Dictionary:
	var n := trees.size()/Plan.STRIDE
	var solid := PackedFloat32Array()
	var pose := PackedFloat32Array()
	var buckets := {}
	var wing := WorldScale.span*0.5*WING_SOLID
	for t in n:
		var q := t*Plan.STRIDE
		var d: Vector3 = _dims[int(trees[q+6])]
		var sc := trees[q+3]
		var reach := d.x*sc*trees[q+4]*CROWN_SOLID+wing
		solid.append_array([trees[q],trees[q+2],trees[q+1],d.y*sc,d.z*sc,reach,d.x*sc*trees[q+4]*CROWN_SOLID,0.0])
		pose.append_array([trees[q+3],trees[q+4],trees[q+5]])
		var b := Vector2i(floori(trees[q]/BUCKET),floori(trees[q+2]/BUCKET))
		if not buckets.has(b): buckets[b] = PackedInt32Array()
		var list: PackedInt32Array = buckets[b]
		list.append(t)
		buckets[b] = list
	return {"solid":solid,"buckets":buckets,"n":n,"pose":pose}

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
	if not knocked.is_empty():
		var here := _knocked_in(key.x*BLOCK,key.y*BLOCK,BLOCK)
		if not here.is_empty(): _hide_block(key,here,{})
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
## crown bottom over the foot, solid reach, crown radius, knocked: 1 with
## height, reach and radius 0), or none: the birds' perches (scripts/endless/
## endless_birds.gd, which pass a tree under 4 m).
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
		if solid[q+7] > 0.5:
			# Knocked down (`knock`): no collider.
			t += 1
			continue
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
		cs.name = "T%d" % t
		body.add_child(cs)
		t += 1
	return t

# --- Knocked down (scripts/endless/tree_knock.gd) ---------------------------------

## The trees the plane has knocked down, game state (the plan is untouched):
## `tree_key` -> true. Each is hidden in its block's batches (near, mid,
## shade, sprites) and detail squares, its solid's top, reach and radius
## zeroed (`top_at`, `ground`, `inside`, the birds and the near misses pass it)
## and its collider gone; again whenever its block is stood anew. (The far
## ring's thinned trees, drawn past FAR.x only with --spruce-sprites=0, keep it.)
var knocked := {}

## A tree's stable key: its plan position (x, z) in decimetres. The plan puts
## the same tree at the same float32 spot every build, native or GDScript.
static func tree_key(x: float, z: float) -> Vector2i:
	return Vector2i(roundi(x*10.0),roundi(z*10.0))

## The standing tree whose solid holds `p`, or {}: with `body` the flight's
## cone (`top_at`: CROWN_SOLID of the crown plus WING_SOLID of the half span)
## raised `above` m, else the bare crown (the collider's spinning top) raised
## `above` m (negative: that deep into it). Of several, the one `p` is
## deepest in. {ck, i, x, z, foot, height, bottom (crown bottom over the
## foot), radius (CROWN_SOLID of the crown), reach, depth (m under its top at `p`)}.
func tree_in(p: Vector3, body: bool, above := 0.0) -> Dictionary:
	if not enabled or _blocks.is_empty(): return {}
	var best := {}
	var bx := floori(p.x/BUCKET)
	var bz := floori(p.z/BUCKET)
	for dz in range(-1,2):
		for dx in range(-1,2):
			var b := Vector2i(bx+dx,bz+dz)
			var ck := Plan.cell_of((b.x+0.5)*BUCKET,(b.y+0.5)*BUCKET)
			var cell: Variant = _cell_data(ck)
			if cell == null: continue
			var list: Variant = (cell as Dictionary).buckets.get(b)
			if list == null: continue
			var solid: PackedFloat32Array = (cell as Dictionary).solid
			for t: int in list:
				var q := t*8
				var reach := solid[q+5] if body else solid[q+6]
				if reach <= 0.0: continue
				var ox := p.x-solid[q]
				var oz := p.z-solid[q+1]
				var d2 := ox*ox+oz*oz
				if d2 >= reach*reach: continue
				var foot := solid[q+2]
				var top := lerpf(foot+solid[q+3],foot+solid[q+4],sqrt(d2)/reach)
				var depth := top+above-p.y
				if depth <= 0.0 or p.y < foot-1.0: continue
				if not best.is_empty() and depth <= float(best.depth): continue
				best = {"ck":ck,"i":t,"x":solid[q],"z":solid[q+1],"foot":foot,"height":solid[q+3],"bottom":solid[q+4],
					"radius":solid[q+6],"reach":solid[q+5],"depth":top-p.y}
	return best

## The meshes of variant `v`: [trunk, crown] (the near ring's), and the
## crowns' mean tint.
func parts(v: int) -> Array:
	return _parts[clampi(v,0,_parts.size()-1)]

func tint() -> Color:
	return _tint

## Knocks tree `t` (a `tree_in` result) down: kept in `knocked`, hidden, no
## solid, no collider. Returns how it stood, for the falling copy: {variant,
## trunk (its Transform3D, the foot its origin), tone (the crown's colour)},
## or {} if it was down already.
func knock(t: Dictionary) -> Dictionary:
	var key := tree_key(float(t.x),float(t.z))
	if knocked.has(key): return {}
	knocked[key] = true
	var out := {"variant":-1,"trunk":Transform3D(Basis(),Vector3(float(t.x),float(t.foot),float(t.z))),"tone":_tint}
	var bkey := _block_of(float(t.x),float(t.z))
	if _blocks.has(bkey): _hide_block(bkey,{key:true},out)
	stats.knocked = knocked.size()
	return out

## The knocked trees' keys in the square at (x0, z0), `size` m.
func _knocked_in(x0: float, z0: float, size: float) -> Dictionary:
	var out := {}
	var lo := Vector2(x0*10.0,z0*10.0)
	var hi := lo+Vector2.ONE*size*10.0
	for k: Vector2i in knocked:
		if k.x >= lo.x-1 and k.x < hi.x+1 and k.y >= lo.y-1 and k.y < hi.y+1: out[k] = true
	return out

## Hidden instances, by batch kind, for the drivers (`_hide_block` counts).
var hidden := {}

## Block `bkey`'s trees in `keys` hidden: their solids zeroed (and colliders
## dropped); their instances shrunk to nothing in the block's near batches
## (trunk, crown, sprite: by variant and index; mid and shade: by index, the
## cell's `slots`); taken out of its detail squares' buffers and the squares
## made again (`_stand_tiles`). `out` (if it has "variant") gets the first
## one's variant, trunk transform and crown tone.
func _hide_block(bkey: Vector2i, keys: Dictionary, out: Dictionary) -> void:
	var b: Dictionary = _blocks[bkey]
	var holder: Node = b.node
	for ck: Vector2i in b.cells:
		var cell: Dictionary = b.cells[ck]
		var solid: PackedFloat32Array = cell.solid
		var slots: PackedInt32Array = cell.get("slots",PackedInt32Array())
		var changed := false
		for t in int(cell.n):
			var q := t*8
			if solid[q+7] > 0.5 or not keys.has(tree_key(solid[q],solid[q+1])): continue
			var foot := Vector3(solid[q],solid[q+2],solid[q+1])
			solid[q+3] = 0.0
			solid[q+5] = 0.0
			solid[q+6] = 0.0
			solid[q+7] = 1.0
			changed = true
			if _bodies.has(ck):
				var cs := (_bodies[ck] as Node).get_node_or_null("T%d" % t)
				if cs != null:
					# Out of the physics space now, not at the frame's end.
					cs.get_parent().remove_child(cs)
					cs.queue_free()
			if slots.size() < (t+1)*3: continue
			var v := slots[t*3]
			var vi := slots[t*3+1]
			var bi := slots[t*3+2]
			for part: String in ["Trunk","Crown","Sprite"]:
				_shrink(holder.get_node_or_null("Spruce%d%s" % [v,part]),vi,foot,part)
			for part: String in ["Mid","Shade"]:
				_shrink(holder.get_node_or_null(part),bi,foot,part)
			if out.has("variant") and int(out.variant) < 0:
				var pose: PackedFloat32Array = cell.pose
				var sc := pose[t*3]
				var wide := pose[t*3+1]
				out.variant = v
				out.trunk = Transform3D(Basis(Vector3.UP,pose[t*3+2]).scaled(Vector3(sc*wide,sc,sc*wide)),foot)
				out.tone = _tone_of(bkey,bi)
		if changed: cell.solid = solid
	# The detail squares: out of their buffers, and those standing made again.
	var tiles: Dictionary = b.get("tiles",{})
	var per_sub := int(BLOCK/DETAIL_TILE)
	for sti: Variant in tiles:
		var slots: Array = tiles[sti]
		var hit := false
		for v in slots.size():
			var slot: Array = slots[v]
			var buf: PackedFloat32Array = slot[0]
			var n := int(slot[1])
			var stride := buf.size()/n if n > 0 else 16
			var changed := false
			for i in n:
				var q := i*stride
				if not keys.has(tree_key(buf[q+3],buf[q+11])): continue
				for k: int in [0,1,2,4,5,6,8,9,10]: buf[q+k] = 0.0
				changed = true
			if changed:
				slot[0] = buf
				hit = true
				hidden["tile"] = int(hidden.get("tile",0))+1
		if not hit: continue
		var sx := int(sti)%per_sub
		var sz := int(sti)/per_sub
		for t: Vector4i in _tiles.keys():
			if t.x != bkey.x or t.y != bkey.y: continue
			var size := DETAIL_TILE if t.w == 0 else FAR_TILE
			var per := int(BLOCK/size)
			var sub := int(size/DETAIL_TILE)
			if (t.z%per)*sub <= sx and sx < (t.z%per+1)*sub and (t.z/per)*sub <= sz and sz < (t.z/per+1)*sub:
				(_tiles[t] as Node).queue_free()
				_tiles.erase(t)

## Instance `i` of `batch` (if there is one) shrunk to nothing at `at`.
func _shrink(batch: Node, i: int, at: Vector3, kind: String) -> void:
	if not batch is MultiMeshInstance3D: return
	var mm := (batch as MultiMeshInstance3D).multimesh
	if mm == null or i < 0 or i >= mm.instance_count: return
	mm.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ZERO),at))
	hidden[kind] = int(hidden.get(kind,0))+1

## The crown's tone of block `bkey`'s tree `bi` (`_block_from`'s draw).
func _tone_of(bkey: Vector2i, bi: int) -> Color:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed,bkey.x,bkey.y,"trees"])
	var f := 1.0
	for i in bi+1: f = rng.randf_range(TINT_SPREAD.x,TINT_SPREAD.y)
	return _tint*f

## The numbers line (F1).
func note() -> String:
	if not enabled: return "\nno trees"
	return "\ntrees: %d in %d blocks, %dk far in %d cells  ·  %.0f ms a plan on a worker (slowest %.0f), slowest stand %.2f ms (%s), %d collider cells (slowest %.2f ms)" % [
		int(stats.trees),int(stats.blocks),int(stats.far_trees)/1000,int(stats.far),float(stats.plan_ms)/maxf(float(stats.plans),1.0),float(stats.slowest_plan_ms),float(stats.slowest_commit_ms),String(stats.slowest_commit),int(stats.colliders),float(stats.get("slowest_collider_ms",0.0))]
