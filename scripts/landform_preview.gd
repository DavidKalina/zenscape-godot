extends Node
## A look at the lower world's landforms in today's sky, without going
## under the cloud: --landform=<name> (several comma separated) stands a
## row of islands of that landform near the home island, one at each of
## SIZES of its width range, in the sky's islets (scripts/sky_islets.gd) as
## fixed records, so the glide reads them as solids and perches on them,
## and the seeded islets keep clear of them. Each is made as the lower
## world makes it (scripts/sky_archipelago.gd `dress_spec`): standing in
## the sea at the landform's own SEA, or with its rim a little over the
## water, on a flat stand-in sea (SEA_COLOR) and not bobbing.
## --landform-seed=N lays them from seed N (SEED otherwise). Islands are
## SkyIslets (scripts/sky_islet.gd) from the landform's `recipe` (the
## contract in scripts/landforms.gd), stood on the main thread when the sky
## is first laid out and again whenever it is laid out anew.
## tools/capture_landform.gd films them.
##
## With --below the flag means the lower world's instead (scripts/
## sky_archipelago.gd: those landforms stood near where the plane comes out
## under the cloud), and no preview stands in the sky.
##   godot --path . -- --no-title --landform=hills,cliffs

const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyIslet = preload("res://scripts/sky_islet.gd")
const SkyPeaks = preload("res://scripts/sky_peaks.gd")
const SkyBelow = preload("res://scripts/sky_below.gd")
## The landforms by name.
const LANDFORMS := {
	"hills":preload("res://scripts/landform_hills.gd"),
	"cliffs":preload("res://scripts/landform_cliffs.gd"),
	"forest":preload("res://scripts/landform_forest.gd"),
	"lake":preload("res://scripts/landform_lake.gd"),
	"mountains":preload("res://scripts/landform_mountains.gd"),
}
## Where along each landform's width range the islands are (shares).
const SIZES := [0.0,0.5,1.0]
## The row: its first island's distance from the home (m), the gap between
## islands' rims (m), the height (m, home frame) and how far each keeps
## off an island's spot (m); rows further out for more landforms.
const RING := 230.0
const GAP := 45.0
const HEIGHT := -6.0
const ISLAND_CLEAR := 150.0
const ROW_STEP := 160.0
const SEED := 11
## The rim's height over the water for a landform with no SEA (m, the
## middle of the archipelago's FREEBOARD), and the stand-in sea: how far it
## reaches past an island's rim (m) and its colour (linear).
const FREEBOARD := 0.2
const SEA_REACH := 40.0
const SEA_COLOR := Color(0.07,0.2,0.24)

var islets: Node3D
var names: Array = []
var seed_base := SEED
## What stands: per key, {home, landform, across, seed, level}.
var stood := {}

## The landforms asked for on the command line, known names only.
static func wanted() -> Array:
	var out: Array = []
	for a: String in OS.get_cmdline_user_args():
		if not a.begins_with("--landform="): continue
		for n: String in a.trim_prefix("--landform=").split(",",false):
			if LANDFORMS.has(n) and not n in out: out.append(n)
			elif not LANDFORMS.has(n): push_warning("--landform: no landform %s (%s)" % [n,", ".join(LANDFORMS.keys())])
	return out

## Adds a preview to `islands` (SkyIslands) when --landform asks for one,
## unless the lower world takes the flag (--below).
static func attach(islands: Node3D) -> void:
	if SkyBelow.on(): return
	var names_wanted := wanted()
	if names_wanted.is_empty(): return
	var preview: Node = new()
	preview.name = "LandformPreview"
	preview.islets = islands.islets
	preview.names = names_wanted
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--landform-seed="): preview.seed_base = int(a.trim_prefix("--landform-seed="))
	islands.add_child(preview)

func _process(_delta: float) -> void:
	if islets == null or islets.cells == null: return
	if not stood.is_empty() and islets.built.has(stood.keys()[0]): return
	stand_all()

## The sea's height in `landform`'s islet frame: its SEA, or its rim
## FREEBOARD over the water.
static func sea_level(landform: Script) -> float:
	var level: Variant = landform.get_script_constant_map().get("SEA")
	return float(level) if level != null else SkyIslet.RIM_HEIGHT-FREEBOARD

## Stands every island of the row (again, if the sky was laid out anew).
func stand_all() -> void:
	stood.clear()
	# Loaded here, not preloaded: the archipelago reaches back to the sky's
	# own scripts.
	var archipelago: GDScript = load("res://scripts/sky_archipelago.gd")
	var palette: Dictionary = islets.prepare_authored()
	for row in range(names.size()):
		var landform: GDScript = LANDFORMS[names[row]]
		var range_m: Vector2 = landform.ACROSS
		var level := sea_level(landform)
		var homes := _row(row,range_m)
		for k in range(SIZES.size()):
			var across := lerpf(range_m.x,range_m.y,float(SIZES[k]))
			var seed_value := seed_base*1000+row*100+k
			var rng := RandomNumberGenerator.new()
			rng.seed = seed_value
			var spec: Dictionary = landform.recipe(rng,across)
			archipelago.dress_spec(spec,across,level,seed_value)
			var made: Dictionary = SkyIslets.make(seed_value,spec,palette,(homes[k] as Vector3).y)
			var key := "landform:%s:%d" % [names[row],k]
			var b: Dictionary = islets.stand("Landform_%s_%d" % [names[row],k],homes[k],made)
			b.fixed = true
			# Standing in the sea, it does not bob.
			b.phase = 0.0
			b.period = 1.0e9
			b.age = 0.0
			islets.built[key] = b
			_sea(b.node,made.shape,level)
			stood[key] = {"home":homes[k],"landform":names[row],"across":across,"seed":seed_value,"level":level,"usec":made.get("usec",0)}
			print("LANDFORM %s %.0f m (seed %d) at %s: %.0f ms" % [names[row],across,seed_value,homes[k],float(made.get("usec",0))/1000.0])

## A flat stand-in sea under the island on `node` at `level` (its frame).
static func _sea(node: Node3D, shape: RefCounted, level: float) -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = float(shape.reach)+SEA_REACH
	disc.bottom_radius = disc.top_radius
	disc.height = 0.05
	disc.radial_segments = 48
	disc.rings = 1
	var material := StandardMaterial3D.new()
	material.albedo_color = SEA_COLOR
	material.roughness = 0.35
	material.metallic_specular = 0.4
	material.disable_receive_shadows = true
	disc.material = material
	var sea := MeshInstance3D.new()
	sea.name = "Sea"
	sea.mesh = disc
	sea.position = Vector3(0.0,level-0.025,0.0)
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sea.set_meta("skip_reflection",true)
	node.add_child(sea)

## The row's homes: the first place round a ring (RING m out, ROW_STEP more
## a row) clear of the islands' spots and the ranges for the whole row,
## each island along a line tangent to the ring.
func _row(row: int, range_m: Vector2) -> Array:
	var spans: Array = []
	for s in SIZES: spans.append(lerpf(range_m.x,range_m.y,float(s))*0.7)
	var out: Array = []
	for attempt in range(48):
		var angle := TAU*attempt/48.0+0.4
		var out_way := Vector3(cos(angle),0.0,sin(angle))
		var along := Vector3(-out_way.z,0.0,out_way.x)
		var at := out_way*(RING+row*ROW_STEP)+Vector3.UP*HEIGHT
		var homes: Array = []
		var walked := 0.0
		for k in range(spans.size()):
			if k > 0: walked += float(spans[k-1])+float(spans[k])+GAP
			homes.append(at+along*walked)
		var clear := true
		for h: Vector3 in homes:
			if not islets.cells.spots_near(h,ISLAND_CLEAR).is_empty() or SkyPeaks.blocks(h): clear = false
		if not clear: continue
		out = homes
		break
	if out.is_empty(): out = [Vector3(RING,HEIGHT,0.0),Vector3(RING,HEIGHT,150.0),Vector3(RING,HEIGHT,300.0)]
	for k in range(out.size()): islets.keep_clear.append(Vector3(out[k].x,out[k].z,float(spans[k])+60.0))
	return out
