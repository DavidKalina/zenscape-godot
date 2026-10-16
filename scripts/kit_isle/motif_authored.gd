extends "res://scripts/kit_isle/motif_greybox.gd"
## An authored motif: a place the
## user built by hand in the motif editor (studies/motif_editor.tscn), read
## from its file, `motifs/authored/<slug>.json`, and answering the motif
## contract (scripts/kit_isle/kit_motif.gd) like any greybox motif
## (motif_greybox.gd: footprint, height span and occupancy computed here,
## sockets from its rims), so it goes in scripts/kit_isle/greybox/
## registry.gd and the yard stands it (`--motif=<slug>`).
##
## The file holds recipes, not meshes (kit fixes carry through):
##   {"format":2, "slug", "name", "preset" (PRESETS: whale_back, mesa,
##    mountain, gorge, crater), "sliders":{length, width, relief, step,
##    jag, and the preset's own}, "seed",
##    "outline":[[x,z]...] (dragged handles; [] the preset's),
##    "strokes":[{tool (raise lower smooth flatten ravine), r, s,
##    pts:[[x,z]...]}, (format 3, round 3:) {tool "stamp", form
##    (mountain hills crater mesa island), at:[x,z], r, h, seed, y?},
##    {tool "basin" (a lake's bed), pts (a loop), depth, bank},
##    {tool "fill" (new land), pts (a loop), y, bank},
##    (round 4:) {tool "slope", pts:[[x,z] top, [x,z] foot], r, steps?
##    (true: terraces in ledge steps; absent/false: a ramp to slide)}]
##    (in order, over the preset), "waters":[{at:[x,z],
##    fill}] (poured; the level found from the land as built),
##    "pieces":[{id, seed, weathered, at:[x,y,z], turn (deg), sink}],
##    "markers":{"spawn":[x,y,z], "rim_in":[x,y,z], "rim_out":[x,y,z]},
##    "traps" (optional, absent = none):[{id (scripts/traps/trap_registry.gd
##    key), at:[x,y,z] (its way in), turn (deg), on? (TRAP_SEATS: "lip",
##    "piece", "grid" (the pilot grid, on the ground), "ledge" (the grid
##    with ledge steps): set at that y;
##    absent = the ground: its y found from the land as built), knobs?:{only
##    those changed from the trap's defaults()}}],
##    "breakable" (optional; false: no piece of it breaks)}
## A piece's "breakable" (optional; false: it never breaks) and the motif's
## only set meta "breakable" false on the built piece, which the kit
## breaks skip (scripts/kit_isle/kit_breaks.gd `adopt`); absent, a piece
## breaks by its kind and builds exactly as before.
## A piece's y in the file is where the editor seated it; the build seats
## it again on the land (`seat`), so a re-rolled hill never leaves one
## floating. A marker's y likewise (`ground` under it).
##
## The registry wants a script per slug: a two-line subclass answering
## `file()` (scripts/kit_isle/greybox/au_editor_hill.gd). The editor makes
## one with `from_data` instead.
##
## Heavy geometry stays in the kit (KitLand.island, RuinKit.piece); this
## file only makes the preset's ground function and outline (GDScript runs
## one thread at a time).
const KitLife = preload("res://scripts/kit_isle/kit_life.gd")
const HeroTrees = preload("res://scripts/hero_trees.gd")
const RuinKitFit = preload("res://scripts/ruin_kit_fit.gd")
const TrapRegistry = preload("res://scripts/traps/trap_registry.gd")
## What a trap's "on" may say (else it is a ground trap).
const TRAP_SEATS := ["lip","piece","grid","ledge"]

## The trees the palette offers beside the kit's pieces: the game's
## Blender-authored hero trees (scripts/hero_trees.gd, the glbs the flora
## and the islets' woods draw), each [glb, [[mesh node, tint mode, tint]],
## height (m)]. A tree is placed, seated and saved as a piece is ("tree_oak").
const TREES := {
	"tree_oak":["res://assets/models/zenscape-hero-oak.glb",[["Bark",HeroTrees.OWN,""],["Leaves",HeroTrees.TINT,"7f9a48"]],9.0],
	"tree_birch":["res://assets/models/zenscape-hero-birch.glb",[["Bark",HeroTrees.OWN,""],["Crown",HeroTrees.TINT,"86a24c"]],7.5],
	"tree_willow":["res://assets/models/zenscape-hero-willow.glb",[["Bark",HeroTrees.OWN,""],["Crown",HeroTrees.TINT,"86a050"]],6.5],
}
const TREE_NAMES := {"tree_oak":"Oak","tree_birch":"Birch","tree_willow":"Willow"}

const FORMAT := 3
const DIR := "res://motifs/authored"
## The presets and their sliders: [key, label, min, max, step, default].
## Every preset has length, width, relief, step and jag (the outline and the
## terraces read them); the rest are its own. The whale-back's cliff step
## defaults to the kit's climbing set-off, so its terraces are climbed
## (RuinKit.SET_OFF, from the wanderer's reach); the others' to none (smooth
## slopes, brushes read as hills), the step slider there to terrace them.
const PRESETS := {
	"whale_back":[
		["length","Length (m)",24.0,160.0,1.0,64.0],
		["width","Width (m)",16.0,100.0,1.0,40.0],
		["relief","Relief (m)",0.0,20.0,0.1,7.0],
		["step","Cliff step (m)",0.0,4.0,0.05,RuinKit.SET_OFF],
		["jag","Jaggedness",0.0,1.0,0.01,0.4],
	],
	"mesa":[
		["length","Length (m)",24.0,160.0,1.0,56.0],
		["width","Width (m)",16.0,100.0,1.0,44.0],
		["relief","Height (m)",2.0,30.0,0.1,10.0],
		["step","Cliff step (m)",0.0,4.0,0.05,0.0],
		["jag","Jaggedness",0.0,1.0,0.01,0.5],
		["cap","Cap (share)",0.2,0.9,0.01,0.6],
		["edge","Edge softness",0.02,0.4,0.01,0.08],
	],
	"mountain":[
		["length","Length (m)",24.0,160.0,1.0,60.0],
		["width","Width (m)",16.0,100.0,1.0,52.0],
		["relief","Height (m)",4.0,50.0,0.1,22.0],
		["step","Cliff step (m)",0.0,4.0,0.05,0.0],
		["jag","Jaggedness",0.0,1.0,0.01,0.45],
		["sharp","Sharpness",0.6,3.0,0.01,1.6],
		["ridges","Ridges",0.0,1.0,0.01,0.5],
	],
	"gorge":[
		["length","Length (m)",24.0,160.0,1.0,70.0],
		["width","Width (m)",16.0,100.0,1.0,42.0],
		["relief","Relief (m)",0.0,20.0,0.1,6.0],
		["step","Cliff step (m)",0.0,4.0,0.05,0.0],
		["jag","Jaggedness",0.0,1.0,0.01,0.4],
		["gap","Gap (m)",2.0,16.0,0.1,6.0],
		["deep","Gorge depth (m)",2.0,24.0,0.1,9.0],
	],
	"crater":[
		["length","Length (m)",24.0,160.0,1.0,58.0],
		["width","Width (m)",16.0,100.0,1.0,52.0],
		["relief","Rim height (m)",2.0,30.0,0.1,9.0],
		["step","Cliff step (m)",0.0,4.0,0.05,0.0],
		["jag","Jaggedness",0.0,1.0,0.01,0.35],
		["rim","Rim at (share)",0.35,0.9,0.01,0.62],
		["bowl","Bowl depth (m)",1.0,24.0,0.1,8.0],
	],
}
const PRESET_NAMES := {"whale_back":"Whale-back hill","mesa":"Mesa","mountain":"Mountain","gorge":"Split gorge","crater":"Crater bowl"}
## The land brushes (the editor's): what one stamp of each does at strength
## 1 in its middle (m) and the ravine's floor and wall.
const BRUSH_LIFT := 0.35
## The sculpt grid's cell (m): brushes are soft, so a bilinear grid of
## changes over the preset's own crisp ground is enough.
const SCULPT_CELL := 0.5
## A ravine's wall: steps of RAVINE_STEP (the kit's climbing set-off, so
## every lip is caught by a plain jump) on ledges RAVINE_LEDGE deep (a
## pilot stands on one: RuinKit.STAND 0.58 and room), wobbling by
## RAVINE_WOBBLE along the wall so it reads as crags, not a stair.
const RAVINE_STEP := RuinKit.SET_OFF
const RAVINE_LEDGE := 1.0
const RAVINE_WOBBLE := 0.35
## A ravine's depth at strength 0 and 1 (m), and its floor's half-width as
## a share of the brush's radius.
const RAVINE_DEPTH := Vector2(2.0,12.0)
const RAVINE_HALF := 0.45
## The slope tool (round 4): an even ramp the pilot can't stand on, so he
## surfs down it (PilotMotor SLIDE_AUTO, past which he slides, and a margin
## for the mesh's facets), at most SLOPE_HIGH (under the lips' least step,
## cliff_drop 0.8 across a 0.5 m probe, 58 deg); its half-width a share of
## the brush's radius (at least SLOPE_HALF_MIN), blended over SLOPE_BLEND
## to the ground round it. As steps: risers of the kit's set-off (grabbed
## lips) on treads the ramp's own angle gives.
const SLOPE_LOW := PilotMotor.SLIDE_AUTO+4.0
const SLOPE_HIGH := 54.0
const SLOPE_HALF := 0.6
const SLOPE_HALF_MIN := 1.5
const SLOPE_BLEND := 2.5
const SLOPE_STEP := RuinKit.SET_OFF
## Pooled water: the grid it is found on (m) and how far under the spill
## a full pond stands (m).
const POOL_CELL := 0.5
const POOL_FREEBOARD := 0.12
## How far a piece is sunk under the lowest ground beneath it (the
## Rootbound Cut's).
const SINK := 0.15
## The occupancy's sampling (m).
const OCC_STEP := 4.0
## The keel's reach under the datum (KitLand ring_sides: the last ring 0.92
## deep, a spur 0.3 more).
const KEEL_REACH := 1.4

## The motif's file as read (or as the editor holds it).
var data: Dictionary = {}
var _ground := Callable()
var _ground_parts := {}
var _mine := {}
var _span_cache := {}
var _grid_cache := {}
var _ponds_cache: Variant = null
## A live stroke's coarse grid (m; 0: KitLand's 2.5).
var fast_cell := 0.0

func _init() -> void:
	if file() != "": data = read(file())

## The file this motif reads (a subclass answers it; "" for the editor's).
func file() -> String:
	return ""

## A motif over `d` (the editor's, live).
static func from_data(d: Dictionary) -> RefCounted:
	if d.has("base"): return load("res://scripts/kit_isle/motif_based.gd").over(d)
	var m: RefCounted = load("res://scripts/kit_isle/motif_authored.gd").new()
	m.data = d
	return m

## A motif script reading `motifs/authored/<slug>.json`, made at run time
## (the two-line au_*.gd subclass the registry wants, unwritten), so a slug
## saved from the editor opens in the motif yard before it is registered.
## Null when there is no such file.
static func script_for(slug_name: String) -> GDScript:
	if not FileAccess.file_exists(path_of(slug_name)): return null
	var s := GDScript.new()
	var over := "motif_based" if read(path_of(slug_name)).has("base") else "motif_authored"
	s.source_code = 'extends "res://scripts/kit_isle/%s.gd"\nfunc file() -> String:\n\treturn "%s"\n' % [over,path_of(slug_name)]
	if s.reload() != OK: return null
	return s

static func path_of(slug_name: String) -> String:
	return "%s/%s.json" % [DIR,slug_name]

## The file at `path` as a Dictionary ({} if it can't be read).
static func read(path: String) -> Dictionary:
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		push_error("motif authored: can't read %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("motif authored: %s isn't a JSON object" % path)
		return {}
	return normalise(parsed)

## Writes `d` to `path` (tabbed, keys in a fixed order: diffable). OK or an
## error.
static func write(path: String, d: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f := FileAccess.open(path,FileAccess.WRITE)
	if f == null: return FileAccess.get_open_error()
	f.store_string(JSON.stringify(saved_form(d),"\t",false)+"\n")
	f.close()
	return OK

## `d` as it is written: the traps as recipes (keys in a fixed order, only
## their changed knobs), and no "traps" key at all when there are none, so a
## motif without traps writes as before. `d` itself is left as it was.
static func saved_form(d: Dictionary) -> Dictionary:
	if not d.has("traps") and not d.has("base"): return d
	var out := d.duplicate()
	# A based file (motif_based.gd) has no land of its own to write.
	if d.has("base"):
		for key: String in ["preset","sliders","outline","strokes","waters"]: out.erase(key)
	if not d.has("traps"): return out
	out.erase("traps")
	var list: Array = []
	for e: Variant in d.traps if d.traps is Array else []:
		if not e is Dictionary: continue
		var id := str(e.get("id",""))
		var a: Array = e.get("at",[0.0,0.0,0.0])
		var t := {"id":id,"at":[snappedf(float(a[0]),0.001),snappedf(float(a[1]),0.001),snappedf(float(a[2]),0.001)],
			"turn":snappedf(float(e.get("turn",0.0)),0.001)}
		if str(e.get("on","")) in TRAP_SEATS: t.on = str(e.on)
		var knobs := TrapRegistry.changed_knobs(id,e.get("knobs",{}) if e.get("knobs") is Dictionary else {})
		if not knobs.is_empty(): t.knobs = knobs
		list.append(t)
	if not list.is_empty(): out.traps = list
	return out

## The traps of a file read back: entries that aren't objects dropped, at
## and turn made numbers, knobs typed as the trap's defaults. An unknown id
## is kept (the editor and build warn and skip it), so a save never loses it.
static func _read_traps(d: Dictionary) -> void:
	if not d.has("traps"): return
	var list: Array = []
	for e: Variant in d.traps if d.traps is Array else []:
		if not e is Dictionary or not e.has("id"): continue
		var a: Variant = e.get("at")
		if not (a is Array and (a as Array).size() == 3): a = [0.0,0.0,0.0]
		var t := {"id":str(e.id),"at":[float(a[0]),float(a[1]),float(a[2])],"turn":float(e.get("turn",0.0))}
		if str(e.get("on","")) in TRAP_SEATS: t.on = str(e.on)
		if e.get("knobs") is Dictionary and not (e.knobs as Dictionary).is_empty():
			t.knobs = TrapRegistry.typed_knobs(t.id,e.knobs)
		list.append(t)
	if list.is_empty(): d.erase("traps")
	else: d.traps = list

## The authored files' slugs.
static func saved() -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(DIR)
	if dir == null: return out
	for f: String in dir.get_files():
		if f.ends_with(".json"): out.append(f.get_basename())
	out.sort()
	return out

## A fresh motif's data: the preset at its defaults.
static func blank(slug_name: String, preset := "whale_back", seed_value := 1) -> Dictionary:
	var sliders := {}
	for s: Array in PRESETS[preset]: sliders[s[0]] = float(s[5])
	var d := {"format":FORMAT,"slug":slug_name,"name":slug_name.capitalize(),"preset":preset,"sliders":sliders,"seed":seed_value,
		"outline":[],"strokes":[],"waters":[],"pieces":[],"markers":{}}
	default_markers(d)
	return d

## `d` brought up to FORMAT (a round-1 file has no outline, strokes or
## waters), its sliders filled from its preset's defaults.
static func normalise(d: Dictionary) -> Dictionary:
	for key: String in ["outline","strokes","waters","pieces"]:
		if not d.get(key) is Array: d[key] = []
	if not d.get("markers") is Dictionary: d.markers = {}
	if not d.get("sliders") is Dictionary: d.sliders = {}
	_read_traps(d)
	d.preset = preset_of(d)
	for spec: Array in PRESETS[d.preset]:
		if not (d.sliders as Dictionary).has(spec[0]): d.sliders[spec[0]] = float(spec[5])
	d.format = FORMAT
	return d

## The spawn and the two rims where a fresh hill wants them: the spawn on
## the crest's east shoulder, the way in at the east end, out at the west.
static func default_markers(d: Dictionary) -> void:
	var hx := slider(d,"length")*0.5
	var g := ground_of(d)
	var m: Dictionary = d.markers
	for k: String in ["spawn","rim_in","rim_out"]:
		var x: float = {"spawn":hx*0.55,"rim_in":hx*0.82,"rim_out":-hx*0.82}[k]
		m[k] = [x,float(g.call(x,0.0)),0.0]

# --- The land: preset, outline, sculpt, ravines, water -----------------------------------
## The land is a recipe: the preset's raw ground (`raw_of`), the brush
## strokes' soft changes over it on a grid (`Sculpt`, raise lower smooth
## flatten, in order), the terraces (`step`), then the ravines (the
## gorge's own and the ravine strokes: crisp stepped walls whose lips
## KitLand finds as cliffs). The outline is the preset's unless the file
## has its own ("outline", dragged handles). Water is poured: each pour's
## level is found from the land as built (`pour`), so a pond follows the
## hollow it was poured in.

func sliders() -> Dictionary:
	return data.get("sliders",{})

func seed_of() -> int:
	return int(data.get("seed",1))

static func preset_of(d: Dictionary) -> String:
	var p := str(d.get("preset","whale_back"))
	return p if PRESETS.has(p) else "whale_back"

## A slider of `d`, its preset's default if missing.
static func slider(d: Dictionary, key: String) -> float:
	var s: Dictionary = d.get("sliders",{})
	if s.has(key): return float(s[key])
	for spec: Array in PRESETS[preset_of(d)]:
		if str(spec[0]) == key: return float(spec[5])
	return 0.0

## The preset's raw ground (x, z) -> y: no terraces, no brushes.
static func raw_of(d: Dictionary) -> Callable:
	var hx := maxf(slider(d,"length")*0.5,4.0)
	var hz := maxf(slider(d,"width")*0.5,4.0)
	var relief := slider(d,"relief")
	var rng := RandomNumberGenerator.new()
	rng.seed = int(d.get("seed",1))*7919+11
	var peak := rng.randf_range(-0.3,0.3)*hx
	var p1 := rng.randf_range(0.0,TAU)
	var p2 := rng.randf_range(0.0,TAU)
	var lean := rng.randf_range(-0.15,0.15)
	var swell := func(x: float, z: float) -> float:
		return 0.45*sin(x*0.31+z*0.17+p2)*sin(z*0.23-x*0.07+1.3)+0.25*sin(x*0.71-z*0.53+p1)
	match preset_of(d):
		"mesa":
			var cap := slider(d,"cap")
			var soft := slider(d,"edge")
			return func(x: float, z: float) -> float:
				var a := atan2(z/hz,x/hx)
				var r := Vector2(x/hx,z/hz).length()*(1.0+0.06*sin(3.0*a+p1)+0.04*sin(7.0*a+p2))
				var top := relief*(1.0-smoothstep(cap,cap+soft,r))
				return top+relief*0.12*(1.0-r)+0.6*float(swell.call(x,z))
		"mountain":
			var sharp := slider(d,"sharp")
			var ridges := slider(d,"ridges")
			var px := rng.randf_range(-0.2,0.2)*hx
			var pz := rng.randf_range(-0.2,0.2)*hz
			var arms := rng.randi_range(3,5)
			return func(x: float, z: float) -> float:
				var u := Vector2((x-px)/hx,(z-pz)/hz)
				var r := u.length()
				var a := atan2(u.y,u.x)
				# Arêtes: the slope lifted along a few arms, cut between.
				var rib := absf(sin(a*arms*0.5+p1))
				var r2 := r*(1.0-ridges*0.28*(rib-0.5))
				var y := relief*pow(maxf(1.0-r2,0.0),sharp)
				return y+0.5*float(swell.call(x,z))
		"crater":
			var rim := slider(d,"rim")
			var bowl := slider(d,"bowl")
			return func(x: float, z: float) -> float:
				var a := atan2(z/hz,x/hx)
				var r := Vector2(x/hx,z/hz).length()*(1.0+0.05*sin(4.0*a+p1))
				var y := 0.0
				if r < rim:
					var t := r/rim
					y = relief-bowl*(1.0-t*t*t)
				else:
					var t := (r-rim)/maxf(1.0-rim,0.05)
					y = relief*(1.0-0.55*t*t)
				return y+0.4*float(swell.call(x,z))
		"gorge":
			return func(x: float, z: float) -> float:
				var u := x/hx
				var w := z/hz
				return relief*(1.0-0.3*u*u-0.6*w*w)+0.5*float(swell.call(x,z))
		_:
			return func(x: float, z: float) -> float:
				var u := (x-peak)/(hx+absf(peak))
				var crest := relief*(1.0-0.45*u*u)+relief*0.08*sin(x*0.11+p1)
				var w := z/hz-lean*u
				return crest-relief*0.85*w*w+float(swell.call(x,z))

## The preset's outline (x, z): an ellipse, its rim wandering by the
## jaggedness.
static func preset_outline(d: Dictionary) -> Array:
	var hx := maxf(slider(d,"length")*0.5,4.0)
	var hz := maxf(slider(d,"width")*0.5,4.0)
	var jag := slider(d,"jag")
	var rng := RandomNumberGenerator.new()
	rng.seed = int(d.get("seed",1))*104729+3
	var count := 28
	var phase := rng.randf_range(0.0,TAU)
	var out: Array = []
	for k in range(count):
		var a := k*TAU/count+rng.randf_range(-0.06,0.06)
		var r := 1.0+jag*(0.1*sin(2.0*a+phase)+0.07*sin(5.0*a+phase*2.0)+rng.randf_range(-0.12,0.12))
		out.append(Vector2(cos(a)*hx*r,sin(a)*hz*r))
	return out

## The outline (x, z) of `d`: its own (dragged handles) or the preset's.
static func outline_of(d: Dictionary) -> Array:
	var own: Array = d.get("outline",[])
	if own.size() >= 3:
		var out: Array = []
		for p: Array in own: out.append(Vector2(float(p[0]),float(p[1])))
		return out
	return preset_outline(d)

## The gorge preset's own ravine: across the isle near its middle, a
## zigzag, as a ravine stroke is stored.
static func preset_ravines(d: Dictionary) -> Array:
	if preset_of(d) != "gorge": return []
	var hx := maxf(slider(d,"length")*0.5,4.0)
	var hz := maxf(slider(d,"width")*0.5,4.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(d.get("seed",1))*31337+5
	var x0 := rng.randf_range(-0.15,0.15)*hx
	var pts: Array = []
	var n := 9
	for k in range(n+1):
		var t := float(k)/n
		# Stopping short of the rim: run out through the outline, the hanging
		# sides dropped dark shards into the gap (KitLand ring_sides hang
		# from the rim's own height).
		var z := lerpf(-hz*0.86,hz*0.86,t)
		pts.append([x0+rng.randf_range(-1.0,1.0)*slider(d,"gap")*0.6+sin(t*PI*1.5)*hx*0.08,z])
	return [{"tool":"ravine","pts":pts,"half":slider(d,"gap")*0.5,"depth":slider(d,"deep")}]

## The brush changes over the raw ground: a grid of metres added (bilinear).
class Sculpt extends RefCounted:
	var origin := Vector2.ZERO
	var cols := 0
	var rows := 0
	var cell := 0.5
	var delta := PackedFloat32Array()
	var any := false
	## Where a landform stamp (mountain, hills, crater) or a lake's basin
	## stands, 0..1: the landform's terraces give way to the stamp's own
	## smooth slopes there, and no cliff is laid (`smooth_at`).
	var smooth := PackedFloat32Array()
	var smooth_any := false

	func _init(box: Rect2, cell_size: float) -> void:
		cell = cell_size
		origin = box.position
		cols = int(ceil(box.size.x/cell))+2
		rows = int(ceil(box.size.y/cell))+2
		delta.resize(cols*rows)
		delta.fill(0.0)
		smooth.resize(cols*rows)
		smooth.fill(0.0)

	## The smooth share at (x, z) (bilinear; 0 outside).
	func smooth_at(x: float, z: float) -> float:
		if not smooth_any: return 0.0
		var fx := (x-origin.x)/cell
		var fz := (z-origin.y)/cell
		var c := int(floor(fx))
		var r := int(floor(fz))
		if c < 0 or r < 0 or c >= cols-1 or r >= rows-1: return 0.0
		var tx := fx-c
		var tz := fz-r
		var k := r*cols+c
		return lerpf(lerpf(smooth[k],smooth[k+1],tx),lerpf(smooth[k+cols],smooth[k+cols+1],tx),tz)

	func _smooth(k: int, w: float) -> void:
		if w <= 0.0: return
		smooth[k] = maxf(smooth[k],w)
		smooth_any = true

	func sample(x: float, z: float) -> float:
		if not any: return 0.0
		var fx := (x-origin.x)/cell
		var fz := (z-origin.y)/cell
		var c := int(floor(fx))
		var r := int(floor(fz))
		if c < 0 or r < 0 or c >= cols-1 or r >= rows-1: return 0.0
		var tx := fx-c
		var tz := fz-r
		var k := r*cols+c
		return lerpf(lerpf(delta[k],delta[k+1],tx),lerpf(delta[k+cols],delta[k+cols+1],tx),tz)

	func at(c: int, r: int) -> Vector2:
		return origin+Vector2(c,r)*cell

	## A box blur `reach` cells each way of `h` (w x hgt), rows then columns.
	static func blur(h: PackedFloat32Array, w: int, hgt: int, reach: int) -> PackedFloat32Array:
		var a := PackedFloat32Array()
		a.resize(h.size())
		for r in range(hgt):
			for c in range(w):
				var sum := 0.0
				var n := 0
				for o in range(-reach,reach+1):
					var cc := c+o
					if cc < 0 or cc >= w: continue
					sum += h[r*w+cc]
					n += 1
				a[r*w+c] = sum/n
		var b := PackedFloat32Array()
		b.resize(h.size())
		for r in range(hgt):
			for c in range(w):
				var sum := 0.0
				var n := 0
				for o in range(-reach,reach+1):
					var rr := r+o
					if rr < 0 or rr >= hgt: continue
					sum += a[rr*w+c]
					n += 1
				b[r*w+c] = sum/n
		return b

	## The cells within `radius` of any of `pts`, each with its weight: 1 -
	## the product of (1 - strength x falloff) over the points (so a dwell
	## or an overlap builds up but never past 1). {index: weight}
	func weights(pts: Array, radius: float, strength: float) -> Dictionary:
		var keep := {}
		for q: Vector2 in pts:
			var c0 := maxi(int(floor((q.x-radius-origin.x)/cell)),0)
			var c1 := mini(int(ceil((q.x+radius-origin.x)/cell)),cols-1)
			var r0 := maxi(int(floor((q.y-radius-origin.y)/cell)),0)
			var r1 := mini(int(ceil((q.y+radius-origin.y)/cell)),rows-1)
			for r in range(r0,r1+1):
				for c in range(c0,c1+1):
					var t := at(c,r).distance_to(q)/radius
					if t >= 1.0: continue
					var f := (1.0-t*t)*(1.0-t*t)*strength
					var k := r*cols+c
					keep[k] = 1.0-(1.0-float(keep.get(k,0.0)))*(1.0-f)
		return keep

	## The ground as it stands so far at cell k: raw plus the changes.
	func now_at(k: int, raw: Callable) -> float:
		var p := at(k%cols,k/cols)
		return float(raw.call(p.x,p.y))+delta[k]

	## The cells' index range round `box` (clamped): [c0, c1, r0, r1].
	func span(box: Rect2) -> Array:
		return [maxi(int(floor((box.position.x-origin.x)/cell)),0),mini(int(ceil((box.end.x-origin.x)/cell)),cols-1),
			maxi(int(floor((box.position.y-origin.y)/cell)),0),mini(int(ceil((box.end.y-origin.y)/cell)),rows-1)]

	## A landform stamp (round 3, the old clay tools' Mountain, Hills,
	## Crater, the Chisel's mesa and the Island's spread): a shape `r`
	## across and `h` tall (a crater's `h` is its bowl's depth) at `at`,
	## blended into the ground under it. A mesa and an island build up to a
	## level ("y", the editor's; else the ground at the middle plus h) and
	## never cut what already stands higher.
	func stamp(stroke: Dictionary, raw: Callable) -> void:
		var a0: Array = stroke.get("at",[0.0,0.0])
		var q := Vector2(float(a0[0]),float(a0[1]))
		var radius := maxf(float(stroke.get("r",6.0)),1.0)
		var h := float(stroke.get("h",4.0))
		var form := str(stroke.get("form","mountain"))
		var rng := RandomNumberGenerator.new()
		rng.seed = int(stroke.get("seed",1))*6151+17
		var p1 := rng.randf_range(0.0,TAU)
		var p2 := rng.randf_range(0.0,TAU)
		var arms := rng.randi_range(3,5)
		var bumps: Array = []
		if form == "hills":
			for i in range(rng.randi_range(4,7)):
				var a := rng.randf_range(0.0,TAU)
				var d := sqrt(rng.randf())*radius*0.62
				# Rolling: each bump's own slope under ~0.45, so on a
				# landform's fall it stays under the kit's rock slope (0.93)
				# and the hills read green.
				var rb := radius*rng.randf_range(0.4,0.6)
				bumps.append([q+Vector2(cos(a),sin(a))*d,rb,minf(h*rng.randf_range(0.45,1.0),rb*0.28)])
		var level := float(stroke.get("y",NAN))
		if form in ["mesa","island"] and is_nan(level): level = float(raw.call(q.x,q.y))+sample(q.x,q.y)+h
		any = true
		var cr := span(Rect2(q-Vector2.ONE*radius*1.25,Vector2.ONE*radius*2.5))
		for r in range(int(cr[2]),int(cr[3])+1):
			for c in range(int(cr[0]),int(cr[1])+1):
				var p := at(c,r)
				var u := p-q
				var t := u.length()/radius
				if t >= 1.25: continue
				var a := atan2(u.y,u.x)
				var k := r*cols+c
				# A mountain, hills or crater keeps its own smooth shape on a
				# terraced landform (a mesa and an island keep the steps:
				# their sides are cliffs).
				if form in ["mountain","hills","crater"]: _smooth(k,1.0-smoothstep(1.05,1.25,t))
				match form:
					"mountain":
						# Aretes: the slope lifted along a few arms, cut between.
						var rib := absf(sin(a*arms*0.5+p1))
						var t2 := t*(1.0-0.24*(rib-0.5))*(1.0+0.06*sin(5.0*a+p2))
						if t2 < 1.0: delta[k] += h*pow(1.0-t2,1.7)*(1.0-0.15*smoothstep(0.0,0.25,0.25-t2))
					"hills":
						for b: Array in bumps:
							var tb := p.distance_to(b[0])/float(b[1])
							if tb < 1.0: delta[k] += float(b[2])*(1.0-tb*tb)*(1.0-tb*tb)
					"crater":
						var tc := t*(1.0+0.05*sin(4.0*a+p1))
						if tc >= 1.0: continue
						var y := 0.0
						if tc < 0.72: y -= h*(1.0-pow(tc/0.72,2.5))
						y += h*0.38*exp(-pow((tc-0.76)/0.13,2.0))
						delta[k] += y*(1.0-smoothstep(0.88,1.0,tc))
					"mesa":
						var tm := t*(1.0+0.06*sin(3.0*a+p1)+0.04*sin(7.0*a+p2))
						var m := 1.0-smoothstep(0.8,0.97,tm)
						var now := float(raw.call(p.x,p.y))+delta[k]
						if m > 0.0 and level > now: delta[k] += (level-now)*m
					"island":
						var ti := t*(1.0+0.07*sin(3.0*a+p1)+0.05*sin(5.0*a+p2))
						var m := 1.0-smoothstep(0.7,1.0,ti)
						var goal := level-h*0.35*ti*ti
						var now := float(raw.call(p.x,p.y))+delta[k]
						if m > 0.0 and goal > now: delta[k] += (goal-now)*m

	## A loop drawn round (round 3): a "basin" sinks a level floor `depth`
	## under the loop's lowest ground, its banks `bank` wide (a lake: the
	## editor pours water in it); a "fill" builds up to level `y` inside (new
	## land, the outline grown round it by the editor), never cutting.
	func loop(stroke: Dictionary, raw: Callable) -> void:
		var poly := PackedVector2Array()
		for p: Array in stroke.get("pts",[]): poly.append(Vector2(float(p[0]),float(p[1])))
		if poly.size() < 3: return
		var bank := maxf(float(stroke.get("bank",3.0)),0.5)
		var box := Rect2(poly[0],Vector2.ZERO)
		for p: Vector2 in poly: box = box.expand(p)
		var level := 0.0
		if str(stroke.tool) == "basin":
			level = INF
			for p: Vector2 in poly: level = minf(level,float(raw.call(p.x,p.y))+sample(p.x,p.y))
			level -= maxf(float(stroke.get("depth",2.5)),0.3)
		else:
			level = float(stroke.get("y",0.0))
		any = true
		var cr := span(box)
		for r in range(int(cr[2]),int(cr[3])+1):
			for c in range(int(cr[0]),int(cr[1])+1):
				var p := at(c,r)
				if not Geometry2D.is_point_in_polygon(p,poly): continue
				var e := KitLand.edge_distance(p,poly)
				var k := r*cols+c
				var now := float(raw.call(p.x,p.y))+delta[k]
				if str(stroke.tool) == "basin":
					# A bowl: level in its middle, rounding up to the banks.
					var w := smoothstep(0.0,bank,e)
					_smooth(k,w)
					if level < now: delta[k] += (level-now)*w*(2.0-w)
				else:
					var w := smoothstep(0.0,minf(bank,1.5),e)
					if level > now: delta[k] += (level-now)*maxf(w,0.6)

	## One stroke over `raw` (x, z) -> y.
	func apply(stroke: Dictionary, raw: Callable) -> void:
		if str(stroke.get("tool","")) == "stamp":
			stamp(stroke,raw)
			return
		if str(stroke.get("tool","")) in ["basin","fill"]:
			loop(stroke,raw)
			return
		var pts: Array = []
		for p: Array in stroke.get("pts",[]): pts.append(Vector2(float(p[0]),float(p[1])))
		if pts.is_empty(): return
		var radius := maxf(float(stroke.get("r",4.0)),0.5)
		var s := clampf(float(stroke.get("s",0.5)),0.0,1.0)
		any = true
		match str(stroke.tool):
			"raise", "lower":
				var sign := 1.0 if str(stroke.tool) == "raise" else -1.0
				# Each stamp adds; the dwell's repeated points pile up.
				for q: Vector2 in pts:
					var c0 := maxi(int(floor((q.x-radius-origin.x)/cell)),0)
					var c1 := mini(int(ceil((q.x+radius-origin.x)/cell)),cols-1)
					var r0 := maxi(int(floor((q.y-radius-origin.y)/cell)),0)
					var r1 := mini(int(ceil((q.y+radius-origin.y)/cell)),rows-1)
					for r in range(r0,r1+1):
						for c in range(c0,c1+1):
							var t := at(c,r).distance_to(q)/radius
							if t >= 1.0: continue
							delta[r*cols+c] += sign*BRUSH_LIFT*s*(1.0-t*t)*(1.0-t*t)
			"flatten":
				var first: Vector2 = pts[0]
				var target := float(raw.call(first.x,first.y))+sample(first.x,first.y)
				var w := weights(pts,radius,minf(s*1.4,1.0))
				for k: int in w:
					var p := at(k%cols,k/cols)
					var now := float(raw.call(p.x,p.y))+delta[k]
					delta[k] += (target-now)*float(w[k])
			"smooth":
				var w := weights(pts,radius,s)
				if w.is_empty(): return
				# The heights over the touched cells' box (and a blur's reach),
				# blurred by a box a few cells wide, twice.
				var reach := maxi(int(ceil(maxf(radius*0.3,1.2)/cell)),1)
				var lo := Vector2i(cols,rows)
				var hi := Vector2i(-1,-1)
				for k: int in w:
					lo = Vector2i(mini(lo.x,k%cols),mini(lo.y,k/cols))
					hi = Vector2i(maxi(hi.x,k%cols),maxi(hi.y,k/cols))
				lo = Vector2i(maxi(lo.x-reach*2,0),maxi(lo.y-reach*2,0))
				hi = Vector2i(mini(hi.x+reach*2,cols-1),mini(hi.y+reach*2,rows-1))
				var bw := hi.x-lo.x+1
				var bh := hi.y-lo.y+1
				var h := PackedFloat32Array()
				h.resize(bw*bh)
				for r in range(bh):
					for c in range(bw):
						var p := at(lo.x+c,lo.y+r)
						h[r*bw+c] = float(raw.call(p.x,p.y))+delta[(lo.y+r)*cols+lo.x+c]
				var b := h
				for pass_ in range(2): b = blur(b,bw,bh,reach)
				for k: int in w:
					var c := k%cols-lo.x
					var r := k/cols-lo.y
					delta[k] += (b[r*bw+c]-h[r*bw+c])*float(w[k])

## A ravine over a ground: a stroke's polyline, its floor's half-width, its
## floor falling from the stroke's first point to its last (never
## climbing: water runs it), walls stepped RAVINE_STEP up on ledges.
class Ravine extends RefCounted:
	var pts := PackedVector2Array()
	var floors := PackedFloat32Array()
	var half := 2.0
	var depth := 6.0
	var box := Rect2()
	var reach := 0.0
	var phase := 0.0

	func _init(stroke: Dictionary, under: Callable) -> void:
		for p: Array in stroke.get("pts",[]):
			var q := Vector2(float(p[0]),float(p[1]))
			if pts.is_empty() or q.distance_to(pts[pts.size()-1]) > 0.3: pts.append(q)
		if stroke.has("half"):
			half = float(stroke.half)
			depth = float(stroke.depth)
		else:
			var s := clampf(float(stroke.get("s",0.5)),0.0,1.0)
			half = maxf(float(stroke.get("r",4.0))*RAVINE_HALF,0.8)
			depth = lerpf(RAVINE_DEPTH.x,RAVINE_DEPTH.y,s)
		var last := INF
		for q: Vector2 in pts:
			var f := float(under.call(q.x,q.y))-depth
			last = minf(last,f)
			floors.append(last)
		if pts.size() == 1:
			pts.append(pts[0]+Vector2(0.01,0.0))
			floors.append(floors[0])
		# The walls step up until they meet the ground: across a slope the
		# high side rises past the ravine's depth, so the most a wall climbs
		# is read off the ground beside the stroke (none left as a sheer
		# face past the kit's reach).
		var drop := depth
		for i in range(pts.size()):
			var a := pts[maxi(i-1,0)]
			var b := pts[mini(i+1,pts.size()-1)]
			var side := (b-a).orthogonal().normalized() if a.distance_to(b) > 0.01 else Vector2.RIGHT
			for off: float in [3.0,6.0,10.0]:
				for sgn: float in [-1.0,1.0]:
					var q := pts[i]+side*(half+off)*sgn
					drop = maxf(drop,minf(float(under.call(q.x,q.y))-floors[i],off*RAVINE_STEP/RAVINE_LEDGE))
		var steps := ceilf(drop/RAVINE_STEP)
		reach = half+steps*RAVINE_LEDGE*(1.0+RAVINE_WOBBLE)+0.5
		box = Rect2(pts[0],Vector2.ZERO)
		for q: Vector2 in pts: box = box.expand(q)
		box = box.grow(reach)
		phase = float(pts.size())*1.7

	## The carved height at (x, z) under the ground `y` there.
	func cut(x: float, z: float, y: float) -> float:
		var p := Vector2(x,z)
		if not box.has_point(p): return y
		var best := INF
		var floor_y := 0.0
		for i in range(pts.size()-1):
			var a := pts[i]
			var b := pts[i+1]
			var ab := b-a
			var t := clampf((p-a).dot(ab)/maxf(ab.length_squared(),0.0001),0.0,1.0)
			var d := p.distance_to(a+ab*t)
			if d < best:
				best = d
				floor_y = lerpf(floors[i],floors[i+1],t)
		if best >= reach: return y
		if best <= half: return minf(y,floor_y)
		# The wall: a ledge every RAVINE_LEDGE (wobbling along), a step up
		# RAVINE_STEP at each.
		var wob := 1.0+RAVINE_WOBBLE*sin(x*0.37+z*0.29+phase)*sin(x*0.13-z*0.21)
		var k := ceilf((best-half)/(RAVINE_LEDGE*wob))
		return minf(y,floor_y+k*RAVINE_STEP)

## A slope over a ground (round 4, the slope tool): a band along the
## stroke's two points, its top at the higher one's ground, falling evenly
## at the steepness the ground's own fall asks (SLOPE_LOW..SLOPE_HIGH) to
## the lower one's ground and running out level from there to the end
## (gentler ground: a cut and a level run-out; steeper: the top cut down).
## No step and no lip inside its band; blended to the ground over
## SLOPE_BLEND round it. `steps`: the same ramp in risers of SLOPE_STEP.
class Slope extends RefCounted:
	var a := Vector2.ZERO
	var dir := Vector2.RIGHT
	var length := 0.0
	var half := SLOPE_HALF_MIN
	var top := 0.0
	var bottom := 0.0
	var grade := 1.0
	var run := 0.0
	var steps := false
	var dead := true
	var box := Rect2()

	func _init(stroke: Dictionary, under: Callable) -> void:
		var band := Slope.band_of(stroke)
		if band.is_empty(): return
		a = band.a
		var b: Vector2 = band.b
		half = float(band.half)
		steps = bool(band.steps)
		var ha := float(under.call(a.x,a.y))
		var hb := float(under.call(b.x,b.y))
		# Drawn uphill: the top is the higher end all the same.
		if hb > ha:
			var t := a
			a = b
			b = t
			var th := ha
			ha = hb
			hb = th
		length = a.distance_to(b)
		dir = (b-a)/maxf(length,0.001)
		var fall := ha-hb
		if fall < 0.3: return
		grade = tan(deg_to_rad(clampf(rad_to_deg(atan(fall/length)),SLOPE_LOW,SLOPE_HIGH)))
		bottom = hb
		top = minf(ha,hb+length*grade)
		run = (top-bottom)/grade
		box = band.box
		dead = false

	## The band a stroke covers: {a, b, half, steps, box} ({} none).
	static func band_of(stroke: Dictionary) -> Dictionary:
		var pts: Array = stroke.get("pts",[])
		if pts.size() < 2: return {}
		var a := Vector2(float(pts[0][0]),float(pts[0][1]))
		var b := Vector2(float(pts[-1][0]),float(pts[-1][1]))
		if a.distance_to(b) < 1.0: return {}
		var half := maxf(float(stroke.get("r",4.0))*SLOPE_HALF,SLOPE_HALF_MIN)
		var box := Rect2(a,Vector2.ZERO).expand(b).grow(half+SLOPE_BLEND+0.5)
		return {"a":a,"b":b,"half":half,"steps":bool(stroke.get("steps",false)),"box":box}

	## Whether (x, z) is inside the band (its ramp's own faces), `pad` past it.
	static func inside(band: Dictionary, p: Vector2, pad := 0.0) -> bool:
		var a: Vector2 = band.a
		var ab: Vector2 = band.b-a
		var l := ab.length()
		var u := (p-a).dot(ab/l)
		var v := absf((p-a).cross(ab/l))
		return u > -pad and u < l+pad and v < float(band.half)+pad

	## The ramp's height `u` metres along from its top.
	func height_at(u: float) -> float:
		var along := clampf(u,0.0,length)
		# Steps: a riser of SLOPE_STEP each tread (the ramp's own run for
		# that rise), each tread level.
		if steps: return maxf(top-floorf(along*grade/SLOPE_STEP+0.0001)*SLOPE_STEP,bottom)
		return maxf(top-along*grade,bottom)

	## The height at (x, z) over the ground `y` there.
	func cut(x: float, z: float, y: float) -> float:
		if dead: return y
		var p := Vector2(x,z)
		if not box.has_point(p): return y
		var u := (p-a).dot(dir)
		var v := absf((p-a).cross(dir))
		var off := maxf(maxf(-u,u-length),0.0)
		var w := (1.0-smoothstep(0.0,SLOPE_BLEND,off))*(1.0-smoothstep(half,half+SLOPE_BLEND,v))
		if w <= 0.0: return y
		return lerpf(y,height_at(u),w)

## The ground (x, z) -> y of `d`: the preset, the brushes, the terraces,
## the ravines.
static func ground_of(d: Dictionary, parts := {}) -> Callable:
	var raw := raw_of(d)
	var step := slider(d,"step")
	var ring := outline_of(d)
	var box := Rect2(ring[0],Vector2.ZERO)
	for p: Vector2 in ring: box = box.expand(p)
	var sculpt := Sculpt.new(box.grow(12.0),SCULPT_CELL)
	var ravines: Array = []
	for stroke: Dictionary in d.get("strokes",[]):
		if not str(stroke.get("tool","")) in ["ravine","slope"]: sculpt.apply(stroke,raw)
	parts.sculpt = sculpt
	var soft := func(x: float, z: float) -> float:
		var y := float(raw.call(x,z))+sculpt.sample(x,z)
		if step > 0.3:
			var band := floorf(y/step)
			var stepped := band*step+(y-band*step)*0.18
			# Under a smooth stamp the terraces give way to its slopes.
			y = lerpf(stepped,y,sculpt.smooth_at(x,z))
		return y
	# The ravines and the slopes, in their order: each reads its heights off
	# the ground before it.
	for stroke: Dictionary in preset_ravines(d)+(d.get("strokes",[]) as Array):
		var kind := str(stroke.get("tool",""))
		if kind in ["ravine","slope"] and not (stroke.get("pts",[]) as Array).is_empty():
			var under := soft if ravines.is_empty() else _carved(soft,ravines.duplicate())
			ravines.append(Ravine.new(stroke,under) if kind == "ravine" else Slope.new(stroke,under))
	if ravines.is_empty(): return soft
	return _carved(soft,ravines)

## `soft` cut by each of `ravines` (Ravine, Slope) in turn.
static func _carved(soft: Callable, ravines: Array) -> Callable:
	return func(x: float, z: float) -> float:
		var y := float(soft.call(x,z))
		for r in ravines: y = r.cut(x,z,y)
		return y

## Where the ravines' crisp walls are: one box round them all (none: no
## ravines).
func ravine_box() -> Rect2:
	var out := Rect2()
	var first := true
	var g := ground_fn()
	for stroke: Dictionary in preset_ravines(data)+(data.get("strokes",[]) as Array):
		if str(stroke.get("tool","")) != "ravine" or (stroke.get("pts",[]) as Array).is_empty(): continue
		var r := Ravine.new(stroke,g)
		out = r.box if first else out.merge(r.box)
		first = false
	if first: return out
	# Tight: only where the ravines really lowered the ground (the box above
	# allows for the deepest a wall could climb), and 1.5 m round, so the
	# fine grid (and its re-triangulation) stays where the ravine is.
	var d := data.duplicate()
	d.strokes = (data.get("strokes",[]) as Array).filter(func(s: Dictionary) -> bool: return str(s.get("tool","")) != "ravine")
	var soft := ground_of(d)
	var tight := Rect2()
	var any := false
	var x := out.position.x
	while x <= out.end.x:
		var z := out.position.y
		while z <= out.end.y:
			if float(g.call(x,z)) < float(soft.call(x,z))-0.02:
				tight = Rect2(Vector2(x,z),Vector2.ZERO) if not any else tight.expand(Vector2(x,z))
				any = true
			z += 1.0
		x += 1.0
	return tight.grow(1.5) if any else out

func ground_fn() -> Callable:
	if not _ground.is_valid(): _ground = ground_of(data,_ground_parts)
	return _ground

## The share of the ground a smooth stamp stands on at (x, z), 0..1.
func smooth_at(x: float, z: float) -> float:
	ground_fn()
	var sc: Variant = _ground_parts.get("sculpt")
	return float(sc.smooth_at(x,z)) if sc != null else 0.0

func ground(x: float, z: float) -> float:
	return float(ground_fn().call(x,z))

func outline() -> Array:
	return outline_of(data)

func _box() -> Rect2:
	var ring := outline()
	var box := Rect2(ring[0],Vector2.ZERO)
	for p: Vector2 in ring: box = box.expand(p)
	return box

## The highest and lowest ground inside the outline, sampled every 2 m:
## {top, low, summit}.
func _span() -> Dictionary:
	if _span_cache.is_empty():
		var poly := PackedVector2Array(outline())
		var box := _box()
		var best := Vector3(0.0,-INF,0.0)
		var low := INF
		var x := box.position.x+1.0
		while x < box.end.x:
			var z := box.position.y+1.0
			while z < box.end.y:
				if Geometry2D.is_point_in_polygon(Vector2(x,z),poly):
					var y := ground(x,z)
					if y > best.y: best = Vector3(x,y,z)
					low = minf(low,y)
				z += 2.0
			x += 2.0
		if best.y == -INF: best = Vector3(0.0,ground(0.0,0.0),0.0)
		_span_cache = {"top":best.y,"low":minf(low,best.y),"summit":best}
	return _span_cache

## Its highest ground.
func crest_top() -> float:
	return float(_span().top)

## The landform's own crest and low (the preset's raw ground over the
## outline, no strokes): the keel and the sides hang from these, so a
## stamp or a lake changes the land where it is and not the isle's
## underside (round 3's follow-up).
var _raw_cache := {}
func _raw_span() -> Dictionary:
	if _raw_cache.is_empty():
		var raw := raw_of(data)
		var poly := PackedVector2Array(outline())
		var box := _box()
		var top := -INF
		var low := INF
		var x := box.position.x+1.0
		while x < box.end.x:
			var z := box.position.y+1.0
			while z < box.end.y:
				if Geometry2D.is_point_in_polygon(Vector2(x,z),poly):
					var y := float(raw.call(x,z))
					top = maxf(top,y)
					low = minf(low,y)
				z += 2.0
			x += 2.0
		if top == -INF:
			top = float(raw.call(0.0,0.0))
			low = top
		_raw_cache = {"top":top,"low":low}
	return _raw_cache

## The top the keel and sides hang from: the landform's crest.
func keel_top() -> float:
	return float(_raw_span().top)

func depth() -> float:
	if _depth_cache < 0.0:
		var s := _box().size
		_depth_cache = maxf(clampf(maxf(s.x,s.y)*0.3+maxf(keel_top()-float(_raw_span().low),0.0)*0.3,12.0,36.0),_keel_need())
	return _depth_cache
var _depth_cache := -1.0

## KitLand.ring_sides' rock rings: [inset toward the middle, share of the
## depth under the top], the rim's (0, 0) first and the keel's (1, 1) last.
const KEEL_RINGS := [Vector2(0.0,0.0),Vector2(0.1,0.22),Vector2(0.32,0.48),Vector2(0.6,0.74),Vector2(0.82,0.92),Vector2(1.0,1.0)]
## How far under the carved ground the keel's underside is kept (m), and
## the least share of a ring's drop its jitter leaves (ring_sides: 0.85).
const KEEL_CLEAR := 2.0
const KEEL_JITTER := 0.85
## The deepest the keel is let hang to clear a cut (m).
const KEEL_MOST := 60.0

## The depth the keel needs so its underside stays under the carved ground
## (spec-editor-traps item 13): the sides' inner rings hang from the
## landform's crest at shares of the depth, so a ravine (or a dug lake)
## cut deeper than the keel's underside there came out through it, and the
## keel's long faces showed as a sheet across the cut (and collided).
## Each ground sample (a 2 m grid, and each ravine's drawn points, its
## floor) wants the underside under it at its inset from the rim (on the
## line from the middle), the surface between the rings taken as straight,
## each ring hung from the lower of the crest and the rim's ground. 0 where
## the ground is clear; only ground an edit lowered is asked, so a motif
## with no cut or dug ground keeps its keel.
func _keel_need() -> float:
	var ring := outline()
	var poly := PackedVector2Array(ring)
	var even := RandomNumberGenerator.new()
	even.seed = seed_of()
	var centre := KitLand.centre_of(KitLand.resample(ring,64,even))
	var g := ground_fn()
	var top := keel_top()
	var samples: Array[Vector2] = []
	var box := _box()
	var x := box.position.x+1.0
	while x < box.end.x:
		var z := box.position.y+1.0
		while z < box.end.y:
			samples.append(Vector2(x,z))
			z += 2.0
		x += 2.0
	for stroke: Dictionary in preset_ravines(data)+(data.get("strokes",[]) as Array):
		if str(stroke.get("tool","")) != "ravine": continue
		for p: Array in stroke.get("pts",[]): samples.append(Vector2(float(p[0]),float(p[1])))
	var raw := raw_of(data)
	var need := 0.0
	for p: Vector2 in samples:
		# Only where an edit lowered the ground (the landform's own clears).
		var y := float(g.call(p.x,p.y))
		if y > float(raw.call(p.x,p.y))-0.05 or not Geometry2D.is_point_in_polygon(p,poly): continue
		var out := p-centre
		var r := out.length()
		if r < 0.01: out = Vector2.RIGHT
		# The rim on the line out from the middle through p.
		var far := centre+out.normalized()*10000.0
		var rim := Vector2.INF
		for i in range(poly.size()):
			var hit: Variant = Geometry2D.segment_intersects_segment(centre,far,poly[i],poly[(i+1)%poly.size()])
			if hit != null and centre.distance_to(hit) < centre.distance_to(rim): rim = hit
		if rim == Vector2.INF: continue
		var s := clampf(1.0-r/maxf(centre.distance_to(rim),0.01),0.0,1.0)
		var share := 0.0
		for k in range(1,KEEL_RINGS.size()):
			var a: Vector2 = KEEL_RINGS[k-1]
			var b: Vector2 = KEEL_RINGS[k]
			if s <= b.x:
				share = lerpf(a.y,b.y,(s-a.x)/(b.x-a.x))
				break
		# The rings hang from the lower of the crest and the rim's ground
		# (ring_sides' `hang`), the rim's earth 2.1 m under the rim.
		var hang := minf(float(g.call(rim.x,rim.y)),top)-2.1*(1.0-clampf(s/0.1,0.0,1.0))
		var want := hang-(y-KEEL_CLEAR)
		if want <= 0.0: continue
		if share*KEEL_JITTER < 0.01: continue
		need = maxf(need,want/(share*KEEL_JITTER))
	return minf(need,KEEL_MOST)

## The land's KitLand.island spec (`tone` its turf). Crisp cliffs where
## there are terraces (everywhere) or ravines (round them, a finer grid
## there only); `fast` (a live stroke): a coarse grid, no crisp cliffs.
func land_spec(fast := false) -> Dictionary:
	var ring := outline()
	var box := _box()
	var spec := {"outline":ring,"seed":seed_of(),"ground":ground_fn(),"top":keel_top(),"depth":depth(),"hang":true,"stable":true,"whole_sides":true,
		"resample":[80.0,clampi(int(KitLand.perimeter(ring)/1.5),32,260),32],"tone":KitLook.turf(seed_of(),Callable())}
	if fast:
		spec.cell = 2.5 if fast_cell <= 0.0 else fast_cell
		return spec
	# Under a smooth stamp turf holds a steeper slope (a hill on the
	# landform's fall stays green; a mountain's flanks still go to rock).
	ground_fn()
	var smooth_sc: Variant = _ground_parts.get("sculpt")
	if smooth_sc != null and bool(smooth_sc.smooth_any):
		var rock_slope := float(KitLook.palette().rock_slope)
		spec.rocky = func(mid: Vector2, normal: Vector3) -> bool:
			var slope := sqrt(maxf(0.0,1.0-normal.y*normal.y))/maxf(normal.y,0.001)
			return slope > rock_slope*(1.0+0.45*float(smooth_sc.smooth_at(mid.x,mid.y)))
	# A step is a cliff, a steep slope's own rise not (a mountain's flank
	# would be all cliff points at the kit's 0.3).
	var step := slider(data,"step")
	spec.cliff_drop = clampf(step*0.5,0.3,0.8) if step > 0.3 else 0.8
	# The slopes' bands (round 4): a ramp's faces are turf and never a lip;
	# steps get their lips (crisp cliffs, a fine grid) as a ravine does.
	var ramps: Array = []
	var stairs := Rect2()
	for band: Dictionary in slope_bands():
		if bool(band.steps): stairs = band.box if stairs.size == Vector2.ZERO else stairs.merge(band.box)
		else: ramps.append(band)
	var smooth_skip := Callable()
	if step > 0.3:
		spec.cliffs = box.grow(1.0)
		spec.fine = 1.3
		# No terrace cliffs under a smooth stamp (its own slopes).
		ground_fn()
		var sc: Variant = _ground_parts.get("sculpt")
		if sc != null and bool(sc.smooth_any):
			smooth_skip = func(p: Vector2) -> bool: return float(sc.smooth_at(p.x,p.y)) > 0.35
			spec.cliff_skip = smooth_skip
	else:
		var rb := ravine_box()
		if stairs.size != Vector2.ZERO: rb = stairs if rb.size == Vector2.ZERO else rb.merge(stairs)
		if rb.size != Vector2.ZERO:
			spec.cliffs = rb.intersection(box.grow(1.0))
			spec.fine_box = spec.cliffs
			spec.fine = 1.0
			# The isle's own cell kept (2 m) round the ravine's fine box: a
			# ravine then changes the grid only where it is (stable).
	if not ramps.is_empty():
		spec.cliff_skip = func(p: Vector2) -> bool:
			for band: Dictionary in ramps:
				if Slope.inside(band,p,0.3): return true
			return smooth_skip.is_valid() and bool(smooth_skip.call(p))
		var was: Callable = spec.get("rocky",Callable())
		spec.rocky = func(mid: Vector2, normal: Vector3) -> bool:
			for band: Dictionary in ramps:
				if Slope.inside(band,mid): return false
			if was.is_valid(): return bool(was.call(mid,normal))
			return KitLook.is_rock(normal,KitLook.palette())
	return spec

## The slope strokes' bands (Slope.band_of), in order.
func slope_bands() -> Array:
	var out: Array = []
	for stroke: Dictionary in data.get("strokes",[]):
		if str(stroke.get("tool","")) != "slope": continue
		var band := Slope.band_of(stroke)
		if not band.is_empty(): out.append(band)
	return out

## The bare land: the hill, collided, its sides collided as drawn.
func build_land(fast := false) -> Node3D:
	var spec := land_spec(fast)
	spec.collide_sides = true
	var land := KitLand.island(spec)
	land.name = "Hill"
	return land

# --- Water -----------------------------------------------------------------------------

## The ground on a POOL_CELL grid over the outline's box (outside: NAN),
## built once.
func _pool_grid() -> Dictionary:
	if _grid_cache.is_empty():
		var box := _box().grow(POOL_CELL)
		var cols := int(ceil(box.size.x/POOL_CELL))+1
		var rows := int(ceil(box.size.y/POOL_CELL))+1
		var h := PackedFloat32Array()
		h.resize(cols*rows)
		var poly := PackedVector2Array(outline())
		for r in range(rows):
			for c in range(cols):
				var p := box.position+Vector2(c,r)*POOL_CELL
				h[r*cols+c] = ground(p.x,p.y) if Geometry2D.is_point_in_polygon(p,poly) else NAN
		_grid_cache = {"origin":box.position,"cols":cols,"rows":rows,"h":h}
	return _grid_cache

## A pour at (x, z) filled `fill` (0 a skim, 1 to just under the spill):
## {level, spill, cells (PackedInt32Array of the grid's), rect} or {} where
## nothing holds water (no hollow: it runs off). The spill is the lowest
## pass out of the hollow (a priority flood from the pour, on bands of 2
## cm): where the water would leave the isle.
func pour(x: float, z: float, fill: float) -> Dictionary:
	var g := _pool_grid()
	var cols: int = g.cols
	var rows: int = g.rows
	var h: PackedFloat32Array = g.h
	var origin: Vector2 = g.origin
	var c0 := clampi(int(round((x-origin.x)/POOL_CELL)),0,cols-1)
	var r0 := clampi(int(round((z-origin.y)/POOL_CELL)),0,rows-1)
	var seed_k := r0*cols+c0
	if is_nan(h[seed_k]): return {}
	# The lowest cell near the pour (water finds the bottom).
	for pass_ in range(40):
		var best := seed_k
		for o: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var c := seed_k%cols+o.x
			var r := seed_k/cols+o.y
			if c < 0 or r < 0 or c >= cols or r >= rows: continue
			var k := r*cols+c
			if not is_nan(h[k]) and h[k] < h[best]: best = k
		if best == seed_k: break
		seed_k = best
	var bottom := h[seed_k]
	var band := 0.02
	var buckets := {}
	var cost := {seed_k:bottom}
	buckets[0] = [seed_k]
	var at_band := 0
	var spill := INF
	var top_band := int(ceil((crest_top()-bottom)/band))+2
	while at_band <= top_band and spill == INF:
		var list: Array = buckets.get(at_band,[])
		if list.is_empty():
			at_band += 1
			continue
		var k: int = list.pop_back()
		var here: float = cost[k]
		for o: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var c := k%cols+o.x
			var r := k/cols+o.y
			if c < 0 or r < 0 or c >= cols or r >= rows or is_nan(h[r*cols+c]):
				spill = here
				break
			var n := r*cols+c
			if cost.has(n): continue
			var nc := maxf(here,h[n])
			cost[n] = nc
			var b := int((nc-bottom)/band)
			if not buckets.has(b): buckets[b] = []
			(buckets[b] as Array).append(n)
	if spill == INF or spill-POOL_FREEBOARD < bottom+0.15: return {}
	var level := lerpf(bottom+0.15,spill-POOL_FREEBOARD,clampf(fill,0.0,1.0))
	# The pond: the cells under the level joined to the pour's.
	var cells := PackedInt32Array([seed_k])
	var seen := {seed_k:true}
	var i := 0
	var rect := Rect2(origin+Vector2(seed_k%cols,seed_k/cols)*POOL_CELL,Vector2.ZERO)
	while i < cells.size():
		var k := cells[i]
		i += 1
		for o: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var c := k%cols+o.x
			var r := k/cols+o.y
			if c < 0 or r < 0 or c >= cols or r >= rows: continue
			var n := r*cols+c
			if seen.has(n) or is_nan(h[n]) or h[n] >= level: continue
			seen[n] = true
			cells.append(n)
			rect = rect.expand(origin+Vector2(c,r)*POOL_CELL)
	return {"level":level,"spill":spill,"cells":cells,"seen":seen,"rect":rect.grow(POOL_CELL*2.0)}

## The poured water's ponds: [{level, rect, seen, at}] (the file's
## "waters", each found again on this land).
func ponds() -> Array:
	if _ponds_cache == null:
		_ponds_cache = []
		for w: Dictionary in data.get("waters",[]):
			var a: Array = w.at
			var p := pour(float(a[0]),float(a[1]),float(w.get("fill",0.7)))
			if not p.is_empty():
				p.at = Vector2(float(a[0]),float(a[1]))
				(_ponds_cache as Array).append(p)
	return _ponds_cache

## The ponds' water sheets (KitWater.still) into `into`.
func build_water(into: Node3D) -> void:
	var g := _pool_grid()
	var cols: int = g.cols
	var origin: Vector2 = g.origin
	var gf := ground_fn()
	var poly := PackedVector2Array(outline())
	var n := 0
	for p: Dictionary in ponds():
		var seen: Dictionary = p.seen
		# Wet where the pond's cells are (and a cell round them, so the bank
		# is drawn), on the land.
		var inside := func(q: Vector2) -> bool:
			var c := int(round((q.x-origin.x)/POOL_CELL))
			var r := int(round((q.y-origin.y)/POOL_CELL))
			for dr in range(-1,2):
				for dc in range(-1,2):
					if seen.has((r+dr)*cols+c+dc): return Geometry2D.is_point_in_polygon(q,poly)
			return false
		into.add_child(KitWater.still({"name":"Pond%d" % n,"level":float(p.level),"ground":gf,"rect":p.rect,"inside":inside}))
		n += 1

## Its water for the pilot to wade (the contract's, MotifIsle `_register`).
func pools() -> Array:
	var out: Array = []
	for p: Dictionary in ponds(): out.append({"rect":p.rect,"top":float(p.level)})
	return out

# --- The pieces ---------------------------------------------------------------------

## Everything the palette offers: [id, label], the kit's then the trees.
static func palette() -> Array:
	var out: Array = []
	for id_name: String in RuinKit.ALL_PIECES: out.append([id_name,str(RuinKit.NAMES.get(id_name,id_name))])
	for id_name: String in TREES: out.append([id_name,"Tree: "+str(TREE_NAMES[id_name])])
	return out

## A palette entry built: a kit piece (RuinKit `piece`) or a tree.
static func make(id_name: String, seed_value: int, weathered: float) -> Node3D:
	if TREES.has(id_name): return tree(id_name,seed_value)
	return RuinKit.piece(id_name,seed_value,weathered)

static var _tree_meshes := {}
static var _tree_lock := Mutex.new()
## A hero tree's meshes at scale 1 and its height there (built once).
static func _tree_parts(id_name: String) -> Array:
	_tree_lock.lock()
	if not _tree_meshes.has(id_name):
		var spec: Array = TREES[id_name]
		var meshes: Array = []
		var tall := 0.0
		for part: Array in spec[1]:
			var mat := StandardMaterial3D.new()
			mat.vertex_color_use_as_albedo = true
			mat.roughness = 0.9
			if int(part[1]) == HeroTrees.TINT:
				mat.albedo_color = Color(str(part[2]))
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			var mesh: ArrayMesh = HeroTrees._build(str(spec[0]),str(part[0]),Vector3.ONE,int(part[1]),mat)
			tall = maxf(tall,mesh.get_aabb().end.y)
			meshes.append(mesh)
		_tree_meshes[id_name] = [meshes,tall]
	var out: Array = _tree_meshes[id_name]
	_tree_lock.unlock()
	return out

## A tree `id_name` (TREES), its size and turn jittered by `seed_value`; a
## trunk collider; seated on its trunk's foot (meta "seat_box").
static func tree(id_name: String, seed_value: int) -> Node3D:
	var parts := _tree_parts(id_name)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var size := float(TREES[id_name][2])/maxf(float(parts[1]),0.1)*rng.randf_range(0.85,1.15)
	var node := Node3D.new()
	var look := Node3D.new()
	look.name = "Look"
	look.transform = Transform3D(Basis(Vector3.UP,rng.randf_range(0.0,TAU)).scaled(Vector3.ONE*size),Vector3.ZERO)
	node.add_child(look)
	for mesh: ArrayMesh in parts[0]:
		var drawn := MeshInstance3D.new()
		drawn.mesh = mesh
		look.add_child(drawn)
	var tall := float(parts[1])*size
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var trunk := CylinderShape3D.new()
	trunk.radius = maxf(0.25,tall*0.035)
	trunk.height = tall*0.55
	shape.shape = trunk
	shape.position = Vector3(0.0,trunk.height*0.5,0.0)
	body.add_child(shape)
	node.add_child(body)
	node.set_meta("seat_box",AABB(Vector3(-trunk.radius,0.0,-trunk.radius),Vector3(trunk.radius*2.0,tall,trunk.radius*2.0)))
	return node

## A piece's drawn box (its "Mesh", else its first mesh), in its own frame;
## a tree's trunk.
static func piece_box(piece: Node3D) -> AABB:
	if piece.has_meta("seat_box"): return piece.get_meta("seat_box")
	var mesh := piece.get_node_or_null("Mesh") as MeshInstance3D
	if mesh == null:
		for n: Node in piece.find_children("*","MeshInstance3D",true,false):
			mesh = n as MeshInstance3D
			break
	return mesh.get_aabb() if mesh != null else AABB(Vector3(-1,0,-1),Vector3(2,2,2))

## Where `piece` turned `turn` (deg) at (x, z) stands: on the lowest ground
## under its footprint's corners and middle, less `sink`.
static func seat(g: Callable, piece: Node3D, x: float, z: float, turn: float, sink := SINK) -> float:
	var basis := Basis(Vector3.UP,deg_to_rad(turn))
	var box := piece_box(piece)
	var low := float(g.call(x,z))
	for corner: Vector3 in [box.position,box.position+Vector3(box.size.x,0,0),box.position+Vector3(0,0,box.size.z),box.position+Vector3(box.size.x,0,box.size.z)]:
		var w := basis*corner
		low = minf(low,float(g.call(x+w.x,z+w.z)))
	return low-sink

## A piece's whole drawn box (every mesh, its own frame).
static func drawn_box(piece: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for n: Node in piece.find_children("*","MeshInstance3D",true,false):
		var m := n as MeshInstance3D
		var frame := piece.global_transform.affine_inverse()*m.global_transform if piece.is_inside_tree() else m.transform
		var b := frame*m.get_aabb()
		out = b if first else out.merge(b)
		first = false
	return out

## Piece `k` of the data built and seated, named "P<k>". A piece set onto
## another's connector (its "on": {to, at (the other's frame), turn, stand})
## follows that piece wherever the land puts it; "stand" keeps only its
## place and turn (it stands on its own ground: a pier under an arch's
## foot). A "fit" aqueduct piece grows its piers down to the ground under
## it (scripts/ruin_kit_aqueduct.gd `ground`).
func make_piece(k: int) -> Node3D:
	var p: Dictionary = data.pieces[k]
	var pose := pose_of(k)
	var at: Array = p.at
	var y: float = (pose[0] as Vector3).y
	var turn: float = pose[1]
	at[0] = snappedf((pose[0] as Vector3).x,0.001)
	at[1] = snappedf(y,0.001)
	at[2] = snappedf((pose[0] as Vector3).z,0.001)
	if p.has("on"): p.turn = snappedf(turn,0.001)
	var piece: Node3D = null
	if bool(p.get("fit",false)) and str(p.id) in RuinKit.AQUEDUCT_PIECES:
		piece = fitted(str(p.id),int(p.seed),float(p.get("weathered",0.0)),Transform3D(Basis(Vector3.UP,deg_to_rad(turn)),pose[0]))
	else: piece = make(str(p.id),int(p.seed),float(p.get("weathered",0.0)))
	if piece == null: return null
	piece.name = "P%d" % k
	if not bool(p.get("breakable",true)) or not bool(data.get("breakable",true)): piece.set_meta("breakable",false)
	piece.transform = Transform3D(Basis(Vector3.UP,deg_to_rad(turn)),pose[0])
	return piece

## Where piece `k` stands: [Vector3, turn (deg)]: seated on the land, or on
## the piece it was set onto (its "on").
func pose_of(k: int, depth := 0) -> Array:
	var p: Dictionary = data.pieces[k]
	var at: Array = p.at
	var turn := float(p.get("turn",0.0))
	var on: Variant = p.get("on")
	if on is Dictionary and int(on.to) >= 0 and int(on.to) < k and depth < 16:
		var under := pose_of(int(on.to),depth+1)
		var frame := Transform3D(Basis(Vector3.UP,deg_to_rad(float(under[1]))),under[0])
		var local: Array = on.at
		var w := frame*Vector3(float(local[0]),float(local[1]),float(local[2]))
		turn = fposmod(float(under[1])+float(on.get("turn",0.0)),360.0)
		if bool(on.get("stand",false)): w.y = _seat_y(p,w.x,w.z,turn)
		return [w,turn]
	return [Vector3(float(at[0]),_seat_y(p,float(at[0]),float(at[2]),turn),float(at[2])),turn]

func _seat_y(p: Dictionary, x: float, z: float, turn: float) -> float:
	var box := box_of(str(p.id),int(p.seed),float(p.get("weathered",0.0)))
	var holder := Node3D.new()
	holder.set_meta("seat_box",box)
	var y := seat(ground_fn(),holder,x,z,turn,float(p.get("sink",SINK)))
	holder.free()
	return y

## An aqueduct piece standing at `frame` (world), its piers grown down to
## the land under it.
func fitted(id_name: String, seed_value: int, weathered: float, frame: Transform3D) -> Node3D:
	var g := ground_fn()
	var local := func(x: float, z: float) -> float:
		var w := frame*Vector3(x,0.0,z)
		return float(g.call(w.x,w.z))-frame.origin.y
	var Aq: GDScript = load("res://scripts/ruin_kit_aqueduct.gd")
	match id_name:
		"aqueduct_span": return Aq.span(seed_value,weathered,3,true,local)
		"aqueduct_two_tier": return Aq.two_tier(seed_value,weathered,3,true,local)
		"aqueduct_broken": return Aq.broken(seed_value,weathered,true,"stump",true,local)
		"aqueduct_stump": return Aq.stump(seed_value,weathered,local)
		"aqueduct_end": return Aq.head(seed_value,weathered,true,true,local)
	return make(id_name,seed_value,weathered)

## Every piece into `holder`, then the runs ("Run<k>", laid on the land
## as it is now: scripts/ruin_kit_fit.gd `build_run`).
func build_pieces(holder: Node3D) -> void:
	for k in range((data.get("pieces",[]) as Array).size()):
		var piece := make_piece(k)
		if piece != null: holder.add_child(piece)
	for k in range((data.get("runs",[]) as Array).size()):
		var run := make_run(k)
		if run != null: holder.add_child(run)

func make_run(k: int) -> Node3D:
	var node: Node3D = RuinKitFit.build_run(data.runs[k],ground_fn())
	if node != null: node.name = "Run%d" % k
	if node != null and not bool(data.get("breakable",true)): node.set_meta("breakable",false)
	return node

static var _drawn := {}
static var _box_lock := Mutex.new()
## Each built piece's "ropes" meta (relic_torana's), kept with its box.
static var _ropes := {}
## A piece's drawn box, built once (main thread, `warm`).
static func box_of(id_name: String, seed_value: int, weathered: float) -> AABB:
	var key := "%s/%d/%s" % [id_name,seed_value,weathered]
	_box_lock.lock()
	if not _drawn.has(key):
		var piece: Node3D = make(id_name,seed_value,weathered)
		_drawn[key] = piece_box(piece) if piece != null else AABB()
		if piece != null and piece.has_meta("ropes"): _ropes[key] = piece.get_meta("ropes")
		if piece != null: piece.free()
	var out: AABB = _drawn[key]
	_box_lock.unlock()
	return out

## A piece's swing ropes as it carries them (its "ropes" meta: [{anchor,
## length, dry?, tag?}] in its frame), [] for most.
static func ropes_of(id_name: String, seed_value: int, weathered: float) -> Array:
	box_of(id_name,seed_value,weathered)
	return _ropes.get("%s/%d/%s" % [id_name,seed_value,weathered],[])

## Ropes `specs` (a piece's "ropes" meta) hung live at `frame` (the piece's,
## world): `hang` a Callable(anchor (world), length) -> SwingRope (a
## FootPieces' `rope`, a live host's `rope`); a dry one dried, a tag hung
## beside each. The ropes made.
static func hang_ropes(specs: Array, frame: Transform3D, hang: Callable) -> Array:
	var out: Array = []
	var yaw := frame.basis.get_euler().y
	for k in range(specs.size()):
		var r: Dictionary = specs[k]
		var rope: Node3D = hang.call(frame*(r.anchor as Vector3),float(r.length))
		if rope == null: continue
		if bool(r.get("dry",false)): rope.set_dry(true)
		if r.has("tag"): rope.add_tag(frame*(r.tag as Vector3),yaw,k+int(absf((r.anchor as Vector3).x)*10.0))
		out.append(rope)
	return out

## The live parts: each piece carrying ropes (relic_torana) has them
## hung by the host (scripts/roguelike/layer_greybox.gd `rope`), where the
## piece stands; each saved trap (`trap_of`) goes to the host's `g.trap`,
## stepped round the motor in its TrapField.
func live(g: Node) -> void:
	for k in range((data.get("pieces",[]) as Array).size()):
		var p: Dictionary = data.pieces[k]
		var specs := ropes_of(str(p.id),int(p.seed),float(p.get("weathered",0.0)))
		if specs.is_empty(): continue
		var pose := pose_of(k)
		hang_ropes(specs,Transform3D(Basis(Vector3.UP,deg_to_rad(float(pose[1]))),g.w(pose[0])),Callable(g,"rope"))
	for t: Dictionary in data.get("traps",[]):
		var trap := trap_of(t)
		if trap == null: continue
		trap.position = g.w(trap.position)
		g.trap(trap)

## The trap of saved entry `t` (TrapRegistry, its knobs over the defaults),
## posed in the motif's frame: its way in at `at`, turned `turn` degrees.
## A ground trap ("on" absent) stands on the land as built (as a marker
## does); a lip or piece trap keeps the y the editor seated it at. Null
## (warned) for an unknown id.
func trap_of(t: Dictionary) -> Node3D:
	var trap := TrapRegistry.make(str(t.get("id","")),t.get("knobs",{}) if t.get("knobs") is Dictionary else {})
	if trap == null:
		push_warning("motif authored %s: no trap %s" % [slug(),t.get("id","")])
		return null
	var a: Array = t.get("at",[0.0,0.0,0.0])
	var at := Vector3(float(a[0]),float(a[1]),float(a[2]))
	if not t.has("on"): at.y = ground(at.x,at.z)
	trap.position = at
	trap.rotation_degrees.y = float(t.get("turn",0.0))
	return trap

# --- The motif contract ------------------------------------------------------------------

func slug() -> String:
	return str(data.get("slug","authored"))

func isle_name() -> String:
	return str(data.get("name",slug().capitalize()))

func epithet() -> String:
	return "Authored by hand in the motif editor."

func brief() -> String:
	return "An authored motif (%s)." % slug()

func _marker(key: String) -> Vector3:
	var m: Dictionary = data.get("markers",{})
	var a: Array = m.get(key,[0.0,0.0,0.0])
	return Vector3(float(a[0]),ground(float(a[0]),float(a[2])),float(a[2]))

func start() -> Vector3:
	return _marker("spawn")

func summit() -> Vector3:
	return _span().summit

func parts() -> Array:
	return []

## The two rims: each faces out from the hill's middle through it; its lip
## the ground ahead to the outline, its run-up the clear ground behind
## (pieces kept clear of).
func rims() -> Array:
	var poly := PackedVector2Array(outline())
	var mid := KitLand.centre_of(outline())
	var blocks: Array = []
	for p: Dictionary in data.get("pieces",[]):
		var at: Array = p.at
		var box := box_of(str(p.id),int(p.seed),float(p.get("weathered",0.0)))
		var turn := Basis(Vector3.UP,deg_to_rad(float(p.get("turn",0.0))))
		var x := Vector2(turn.x.x,turn.x.z)
		var z := Vector2(turn.z.x,turn.z.z)
		blocks.append([Transform2D(x,z,Vector2(float(at[0]),float(at[2]))),Rect2(box.position.x,box.position.z,box.size.x,box.size.z).grow(0.3)])
	var out: Array = []
	for k: String in ["rim_in","rim_out"]:
		var at := _marker(k)
		var flat := Vector2(at.x,at.z)
		var way := (flat-mid).normalized() if flat.distance_to(mid) > 0.5 else Vector2.RIGHT
		var lip := clampf(reach_out(poly,flat,way),0.6,6.0)
		var back := clear_run(flat,-way,blocks,minf(reach_out(poly,flat,-way),24.0))
		out.append({"name":k.trim_prefix("rim_"),"at":at,"face":Vector3(way.x,0.0,way.y),"run_up":back,"lip":lip,"way":k.trim_prefix("rim_")})
	return out

func spots() -> Array:
	return []

func flora_site() -> KitFlora.Site:
	var wet := Callable()
	var found := ponds()
	if not found.is_empty():
		wet = func(p: Vector2) -> bool:
			for pond: Dictionary in found:
				if (pond.rect as Rect2).has_point(p) and ground(p.x,p.y) < float(pond.level)+0.08: return true
			return false
	var site := KitFlora.Site.new(crest_top(),Callable(),wet)
	site.ray = Vector2(crest_top()+40.0,float(_span().low)-4.0)
	site.stable = true
	return site

func flora_seed() -> int:
	return seed_of()+9

func life_script() -> Script:
	return KitLife

func warm() -> void:
	super.warm()
	warm_look()
	RuinKit.materials()
	for p: Dictionary in data.get("pieces",[]):
		if TREES.has(str(p.id)): _tree_parts(str(p.id))
	for p: Dictionary in data.get("pieces",[]): box_of(str(p.id),int(p.seed),float(p.get("weathered",0.0)))
	crest_top()
	ponds()

## Measured headless on this Mac (2026-10-14), the 64 x 40 m default with
## a few pieces.
func build_cost() -> int:
	return 400

## Its own (not the greybox's static cache by id: the editor changes it).
func _computed() -> Dictionary:
	if _mine.is_empty():
		var solids := _solids()
		var foot := Rect2()
		var span := Vector2(INF,-INF)
		for k in range(solids.size()):
			var s: Array = solids[k]
			foot = s[0] if k == 0 else foot.merge(s[0])
			span = Vector2(minf(span.x,float(s[1])),maxf(span.y,float(s[2])))
		var origin := foot.position-Vector2.ONE*CELL
		var cols := int(ceil(foot.size.x/CELL))+2
		var rows := int(ceil(foot.size.y/CELL))+2
		var lo := PackedFloat32Array()
		var hi := PackedFloat32Array()
		lo.resize(cols*rows)
		hi.resize(cols*rows)
		lo.fill(INF)
		hi.fill(-INF)
		for s: Array in solids:
			var r: Rect2 = s[0]
			var c0 := maxi(int(floor((r.position.x-origin.x)/CELL)),0)
			var c1 := mini(int(ceil((r.end.x-origin.x)/CELL))-1,cols-1)
			var r0 := maxi(int(floor((r.position.y-origin.y)/CELL)),0)
			var r1 := mini(int(ceil((r.end.y-origin.y)/CELL))-1,rows-1)
			for row in range(r0,r1+1):
				for col in range(c0,c1+1):
					var k := row*cols+col
					lo[k] = minf(lo[k],float(s[1]))
					hi[k] = maxf(hi[k],float(s[2]))
		_mine = {"foot":foot,"span":span,"occ":{"origin":origin,"cell":CELL,"cols":cols,"rows":rows,"lo":lo,"hi":hi}}
	return _mine

## The keel under the hill, sampled; each piece's box over its seat.
func _solids() -> Array:
	var out: Array = []
	var ring := outline()
	var poly := PackedVector2Array(ring)
	var box := Rect2(ring[0],Vector2.ZERO)
	for p: Vector2 in ring: box = box.expand(p)
	var keel := keel_top()-depth()*KEEL_REACH
	var x := box.position.x
	while x < box.end.x:
		var z := box.position.y
		while z < box.end.y:
			var cell := Rect2(x,z,OCC_STEP,OCC_STEP)
			var mid := cell.get_center()
			if Geometry2D.is_point_in_polygon(mid,poly) or KitLand.edge_distance(mid,poly) < OCC_STEP:
				var high := -INF
				for c: Vector2 in [cell.position,cell.end,Vector2(cell.position.x,cell.end.y),Vector2(cell.end.x,cell.position.y),mid]:
					high = maxf(high,ground(c.x,c.y))
				out.append([cell,keel,high+1.0,null])
			z += OCC_STEP
		x += OCC_STEP
	for p: Dictionary in data.get("pieces",[]):
		var at: Array = p.at
		var b := box_of(str(p.id),int(p.seed),float(p.get("weathered",0.0)))
		var turn := Basis(Vector3.UP,deg_to_rad(float(p.get("turn",0.0))))
		var r := Rect2(float(at[0]),float(at[2]),0.0,0.0)
		for corner: Vector3 in [b.position,b.position+Vector3(b.size.x,0,0),b.position+Vector3(0,0,b.size.z),b.position+Vector3(b.size.x,0,b.size.z)]:
			var w := turn*corner
			r = r.expand(Vector2(float(at[0])+w.x,float(at[2])+w.z))
		var base := float(at[1]) if p.has("on") else ground(float(at[0]),float(at[2]))
		out.append([r,minf(base,ground(float(at[0]),float(at[2])))-1.0,base+b.end.y,null])
	for r: Dictionary in data.get("runs",[]):
		var rb := RuinKitFit.run_box(r,ground_fn())
		out.append([rb[0],rb[1],rb[2],null])
	return out

# --- The build (nodes only: a worker may run it) --------------------------------------

func build(into: Node3D) -> void:
	art = into
	var began := Time.get_ticks_msec()
	var root := Node3D.new()
	root.name = "Authored_"+slug()
	into.add_child(root)
	var land := build_land()
	root.add_child(land)
	turf(land)
	build_water(root)
	var holder := Node3D.new()
	holder.name = "Pieces"
	root.add_child(holder)
	build_pieces(holder)
	built_ms = Time.get_ticks_msec()-began
