extends RefCounted
## The landforms the lower world's islands are made as (scripts/
## sky_archipelago.gd): a registry of names, each a script that lays out
## an island's SkyIslet recipe (scripts/sky_islet.gd `recipe`), and how
## often each turns up.
##
## A landform is a script with this contract:
##   extends RefCounted
##   const NAME := "<name>"
##   const ACROSS := Vector2(min_m, max_m)   # the island's width range (m)
##   static func recipe(rng: RandomNumberGenerator, across: float) -> Dictionary
##   const SEA := <y>   # optional: the sea's height in the islet frame
## `recipe` is called on a worker with the island's own seeded `rng` and
## its width (m, within ACROSS, narrowed where its neighbours stand close),
## and returns a SkyIslet recipe: its `kind`, and any of the keys SkyIslet
## `recipe` lists. The archipelago adds what makes it an island in the sea
## unless the recipe sets them: `radius` (half of `across`), `sea_foot` (the
## shore wall down into the water and the shelf round it), `step` (a coarser
## grid for a big island) and `rock` (the earth sides' look, by its seed).
## The island is set so its SEA meets the ocean; a landform with no SEA has
## its rim stand a seeded FREEBOARD over the water (scripts/
## sky_archipelago.gd). A sea foot only goes down where the land's own
## walls stop short of the water, and leaves an underside raised over it
## (an arch) open.
##
## Until the landforms are merged, placeholders stand in: the sky islets'
## own kinds (SkyIslet KINDS) grown to island size (`placeholder`).
##
## Adding one is one line in ENTRIES: [name, script path, weight]. An entry
## with a name already listed takes that one's place, so a real landform
## named as a placeholder ("hills") replaces it. `--landform=<name>[,<name>]`
## stands those near where the plane comes out under the cloud.

## [name, script path ("" for a placeholder of the SkyIslet kind of that
## name), weight].
const ENTRIES := [
	["meadow","",1.0],
	["grove","",1.0],
	["hills","",0.8],
	["crag","",0.6],
	["spring","",0.6],
	["shore","",0.8],
	# --- The landforms, registered here as each is merged: ---------------------
	# ["hills","res://scripts/landform_hills.gd",1.0],
	# ["cliffs","res://scripts/landform_cliffs.gd",1.0],
	# ["forest","res://scripts/landform_forest.gd",1.0],
	# ["lake","res://scripts/landform_lake.gd",1.0],
	# ["mountains","res://scripts/landform_mountains.gd",1.0],
]
## The placeholders' widths (m), by kind.
const PLACEHOLDER_ACROSS := {"meadow":Vector2(35.0,90.0),"grove":Vector2(40.0,90.0),"hills":Vector2(40.0,90.0),
	"crag":Vector2(30.0,75.0),"spring":Vector2(35.0,85.0),"shore":Vector2(30.0,80.0)}

static var _table := {}
static var _order: Array[String] = []

## The registry, read once (on the main thread, `prepare`): name ->
## {script (or null for a placeholder), weight}, in ENTRIES' order, a later
## entry of a name taking an earlier one's place.
static func table() -> Dictionary:
	if not _table.is_empty(): return _table
	var order: Array[String] = []
	for entry: Array in ENTRIES:
		var path: String = entry[1]
		var script: Script = null
		if path != "":
			script = load(path) as Script
			if script == null:
				push_warning("landforms: no script at %s" % path)
				continue
		if not str(entry[0]) in order: order.append(str(entry[0]))
		_table[str(entry[0])] = {"script":script,"weight":float(entry[2])}
	_order = order
	return _table

## Loads the scripts on this thread, before a worker asks for a recipe.
static func prepare() -> void:
	table()

static func names() -> Array[String]:
	table()
	return _order.duplicate()

static func has(landform: String) -> bool:
	return table().has(landform)

## A landform drawn by weight from a roll in 0..1.
static func pick(roll: float) -> String:
	var t := table()
	var total := 0.0
	for n: String in _order: total += float(t[n].weight)
	roll *= total
	for n: String in _order:
		roll -= float(t[n].weight)
		if roll <= 0.0: return n
	return _order[0]

## The width range (m) of `landform`.
static func across(landform: String) -> Vector2:
	var entry: Dictionary = table().get(landform,{})
	var script: Script = entry.get("script")
	if script != null: return script.get("ACROSS")
	return PLACEHOLDER_ACROSS.get(landform,Vector2(28.0,70.0))

## The sea's height in `landform`'s islet frame (its script's SEA), or NAN
## for one that leaves it to the archipelago.
static func sea_level(landform: String) -> float:
	var entry: Dictionary = table().get(landform,{})
	var script: Script = entry.get("script")
	if script == null: return NAN
	var level: Variant = script.get_script_constant_map().get("SEA")
	return float(level) if level != null else NAN

## The SkyIslet recipe of `landform` at `across` metres wide. Safe on a
## worker once `prepare` has run.
static func recipe(landform: String, rng: RandomNumberGenerator, width: float) -> Dictionary:
	var entry: Dictionary = table().get(landform,{})
	var script: Script = entry.get("script")
	if script != null: return (script.call("recipe",rng,width) as Dictionary).duplicate()
	return placeholder(landform,rng,width)

## A sky islet's kind grown to an island `width` metres wide: its dome, its
## mounds and peaks, its pond, its trees and flowers scaled with it, so a
## meadow is a meadow and a crag a crag, only island-sized.
static func placeholder(kind: String, rng: RandomNumberGenerator, width: float) -> Dictionary:
	var r := width*0.5
	var area := PI*r*r
	var grow := r/6.0
	var spec := {"kind":kind,"radius":r}
	match kind:
		"meadow": spec.dome = rng.randf_range(0.8,1.6)*grow
		"grove": spec.dome = rng.randf_range(1.0,2.0)*grow
		"shore": spec.dome = rng.randf_range(0.1,0.25)*grow
		"spring": spec.dome = rng.randf_range(0.6,1.2)*grow
		"hills":
			spec.dome = rng.randf_range(0.4,0.8)*grow
			var mounds: Array[Vector4] = []
			for k in range(rng.randi_range(2,5)):
				var at := Vector2.from_angle(rng.randf()*TAU)*r*rng.randf_range(0.0,0.5)
				var reach := r*rng.randf_range(0.3,0.55)
				mounds.append(Vector4(at.x,at.y,reach,reach*rng.randf_range(0.18,0.32)))
			spec.mounds = mounds
		"crag":
			spec.dome = rng.randf_range(0.3,0.6)*grow
			var at := Vector2.from_angle(rng.randf()*TAU)*r*rng.randf_range(0.0,0.3)
			var reach := r*rng.randf_range(0.55,0.75)
			var knob := at+Vector2.from_angle(rng.randf()*TAU)*reach*0.6
			spec.peaks = [Vector4(at.x,at.y,reach,reach*rng.randf_range(0.35,0.55)),Vector4(knob.x,knob.y,reach*0.45,reach*rng.randf_range(0.15,0.25))] as Array[Vector4]
	if kind == "spring":
		spec.pond = {"radius":clampf(r*rng.randf_range(0.18,0.26),3.0,9.0)}
	# Trees, flowers and undergrowth by area, as the islet's kind has them.
	var density: float = {"meadow":0.006,"grove":0.035,"hills":0.012,"crag":0.01,"spring":0.014,"shore":0.006}[kind]
	var trees := area*density
	spec.trees = Vector2i(roundi(trees*0.7),roundi(trees*1.3))
	var drifts: Vector2i = {"meadow":Vector2i(3,6),"grove":Vector2i(1,2),"hills":Vector2i(1,3),"crag":Vector2i(1,1),"spring":Vector2i(1,3),"shore":Vector2i(1,2)}[kind]
	var more := area/400.0
	spec.drifts = Vector2i(roundi(drifts.x*more),roundi(drifts.y*more))
	return spec
