extends "res://scripts/kit_isle/motif_greybox.gd"
## An authored motif (docs/design/roguelike/level-editor.md): a place the
## user built by hand in the motif editor (studies/motif_editor.tscn), read
## from its file, `motifs/authored/<slug>.json`, and answering the motif
## contract (scripts/kit_isle/kit_motif.gd) like any greybox motif
## (motif_greybox.gd: footprint, height span and occupancy computed here,
## sockets from its rims), so it goes in scripts/kit_isle/greybox/
## registry.gd and the yard stands it (`--motif=<slug>`).
##
## The file holds recipes, not meshes (kit fixes carry through):
##   {"format":1, "slug", "name", "preset":"whale_back",
##    "sliders":{length, width, relief, step, jag}, "seed",
##    "pieces":[{id, seed, weathered, at:[x,y,z], turn (deg), sink}],
##    "markers":{"spawn":[x,y,z], "rim_in":[x,y,z], "rim_out":[x,y,z]}}
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
## one thread at a time, docs/design/roguelike/native-isles-round1.md).
const KitLife = preload("res://scripts/kit_isle/kit_life.gd")
const Rootbound = preload("res://scripts/kit_isle/greybox/gb_rootbound_cut.gd")
const HeroTrees = preload("res://scripts/hero_trees.gd")

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

const FORMAT := 1
const DIR := "res://motifs/authored"
## The presets and their sliders: [key, label, min, max, step, default].
## The whale-back's cliff step defaults to the kit's climbing set-off, so
## its terraces are climbed (RuinKit.SET_OFF, from the wanderer's reach).
const PRESETS := {
	"whale_back":[
		["length","Length (m)",24.0,160.0,1.0,64.0],
		["width","Width (m)",16.0,100.0,1.0,40.0],
		["relief","Relief (m)",0.0,20.0,0.1,7.0],
		["step","Cliff step (m)",0.0,4.0,0.05,RuinKit.SET_OFF],
		["jag","Jaggedness",0.0,1.0,0.01,0.4],
	],
}
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
var _mine := {}

func _init() -> void:
	if file() != "": data = read(file())

## The file this motif reads (a subclass answers it; "" for the editor's).
func file() -> String:
	return ""

## A motif over `d` (the editor's, live).
static func from_data(d: Dictionary) -> RefCounted:
	var m: RefCounted = load("res://scripts/kit_isle/motif_authored.gd").new()
	m.data = d
	return m

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
	return parsed

## Writes `d` to `path` (tabbed, keys in a fixed order: diffable). OK or an
## error.
static func write(path: String, d: Dictionary) -> Error:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var f := FileAccess.open(path,FileAccess.WRITE)
	if f == null: return FileAccess.get_open_error()
	f.store_string(JSON.stringify(d,"\t",false)+"\n")
	f.close()
	return OK

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
	var d := {"format":FORMAT,"slug":slug_name,"name":slug_name.capitalize(),"preset":preset,"sliders":sliders,"seed":seed_value,"pieces":[],"markers":{}}
	default_markers(d)
	return d

## The spawn and the two rims where a fresh hill wants them: the spawn on
## the crest's east shoulder, the way in at the east end, out at the west.
static func default_markers(d: Dictionary) -> void:
	var s: Dictionary = d.sliders
	var hx := float(s.length)*0.5
	var g := ground_of(d)
	var m: Dictionary = d.markers
	for k: String in ["spawn","rim_in","rim_out"]:
		var x: float = {"spawn":hx*0.55,"rim_in":hx*0.82,"rim_out":-hx*0.82}[k]
		m[k] = [x,float(g.call(x,0.0)),0.0]

# --- The preset: the whale-back hill -------------------------------------------------

func sliders() -> Dictionary:
	return data.get("sliders",{})

func seed_of() -> int:
	return int(data.get("seed",1))

## The ground (x, z) -> y of `d`'s preset.
static func ground_of(d: Dictionary) -> Callable:
	var s: Dictionary = d.sliders
	var hx := maxf(float(s.length)*0.5,4.0)
	var hz := maxf(float(s.width)*0.5,4.0)
	var relief := float(s.relief)
	var step := float(s.step)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(d.seed)*7919+11
	# The crest's peak off the middle, its wobble's phase, the swells'.
	var peak := rng.randf_range(-0.3,0.3)*hx
	var p1 := rng.randf_range(0.0,TAU)
	var p2 := rng.randf_range(0.0,TAU)
	var lean := rng.randf_range(-0.15,0.15)
	return func(x: float, z: float) -> float:
		var u := (x-peak)/(hx+absf(peak))
		var crest := relief*(1.0-0.45*u*u)+relief*0.08*sin(x*0.11+p1)
		var w := z/hz-lean*u
		var y := crest-relief*0.85*w*w
		# The old hill's swells under the turf (the Rootbound Cut's).
		y += 0.45*sin(x*0.31+z*0.17+p2)*sin(z*0.23-x*0.07+1.3)+0.25*sin(x*0.71-z*0.53+p1)
		if step > 0.3:
			# Terraces: flat-ish treads, a cliff of most of a step between.
			var band := floorf(y/step)
			y = band*step+(y-band*step)*0.18
		return y

## The outline (x, z) of `d`'s preset: an ellipse round the hill, its rim
## wandering by the jaggedness.
static func outline_of(d: Dictionary) -> Array:
	var s: Dictionary = d.sliders
	var hx := maxf(float(s.length)*0.5,4.0)
	var hz := maxf(float(s.width)*0.5,4.0)
	var jag := float(s.jag)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(d.seed)*104729+3
	var count := 28
	var phase := rng.randf_range(0.0,TAU)
	var out: Array = []
	for k in range(count):
		var a := k*TAU/count+rng.randf_range(-0.06,0.06)
		var r := 1.0+jag*(0.1*sin(2.0*a+phase)+0.07*sin(5.0*a+phase*2.0)+rng.randf_range(-0.12,0.12))
		out.append(Vector2(cos(a)*hx*r,sin(a)*hz*r))
	return out

func ground_fn() -> Callable:
	if not _ground.is_valid(): _ground = ground_of(data)
	return _ground

func ground(x: float, z: float) -> float:
	return float(ground_fn().call(x,z))

func outline() -> Array:
	return outline_of(data)

## Its highest ground (the crest's peak, sampled).
func crest_top() -> float:
	var s: Dictionary = sliders()
	var best := -INF
	var hx := float(s.length)*0.5
	for k in range(-10,11): best = maxf(best,ground(hx*k/10.0,0.0))
	return best

func depth() -> float:
	return clampf(float(sliders().length)*0.3,12.0,30.0)

## The land's KitLand.island spec (`tone` its turf).
func land_spec(fast := false) -> Dictionary:
	var ring := outline()
	var box := Rect2(ring[0],Vector2.ZERO)
	for p: Vector2 in ring: box = box.expand(p)
	var spec := {"outline":ring,"seed":seed_of(),"ground":ground_fn(),"top":crest_top(),"depth":depth(),"hang":true,
		"resample":[80.0,clampi(int(KitLand.perimeter(ring)/1.5),32,260),32],"tone":KitLook.turf(seed_of(),Callable())}
	if float(sliders().get("step",0.0)) > 0.3 and not fast:
		spec.cliffs = box.grow(1.0)
		spec.fine = 1.3
	elif fast:
		spec.cell = 2.5
	return spec

## The bare land: the hill, collided, its sides collided as drawn.
func build_land(fast := false) -> Node3D:
	var land := KitLand.island(land_spec(fast))
	land.name = "Hill"
	Rootbound._collide_sides(land)
	return land

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

## Piece `k` of the data built and seated, named "P<k>".
func make_piece(k: int) -> Node3D:
	var p: Dictionary = data.pieces[k]
	var piece: Node3D = make(str(p.id),int(p.seed),float(p.get("weathered",0.0)))
	if piece == null: return null
	var at: Array = p.at
	var turn := float(p.get("turn",0.0))
	var y := seat(ground_fn(),piece,float(at[0]),float(at[2]),turn,float(p.get("sink",SINK)))
	at[1] = y
	piece.name = "P%d" % k
	piece.transform = Transform3D(Basis(Vector3.UP,deg_to_rad(turn)),Vector3(float(at[0]),y,float(at[2])))
	return piece

## Every piece into `holder`.
func build_pieces(holder: Node3D) -> void:
	for k in range((data.get("pieces",[]) as Array).size()):
		var piece := make_piece(k)
		if piece != null: holder.add_child(piece)

static var _drawn := {}
static var _box_lock := Mutex.new()
## A piece's drawn box, built once (main thread, `warm`).
static func box_of(id_name: String, seed_value: int, weathered: float) -> AABB:
	var key := "%s/%d/%s" % [id_name,seed_value,weathered]
	_box_lock.lock()
	if not _drawn.has(key):
		var piece: Node3D = make(id_name,seed_value,weathered)
		_drawn[key] = piece_box(piece) if piece != null else AABB()
		if piece != null: piece.free()
	var out: AABB = _drawn[key]
	_box_lock.unlock()
	return out

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
	var hx := float(sliders().length)*0.5
	var best := Vector3(0.0,-INF,0.0)
	for k in range(-10,11):
		var x := hx*k/10.0
		if ground(x,0.0) > best.y: best = Vector3(x,ground(x,0.0),0.0)
	return best

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
	var site := KitFlora.Site.new(crest_top())
	site.ray = Vector2(crest_top()+40.0,-float(sliders().relief)-4.0)
	return site

func flora_seed() -> int:
	return seed_of()+9

func life_script() -> Script:
	return KitLife

func warm() -> void:
	super.warm()
	KitLook.palette()
	KitLook.ground_material()
	KitLook.rock_material()
	KitLook.rock_tone(Vector3.ZERO,30.0,Vector3.UP)
	RuinKit.materials()
	for p: Dictionary in data.get("pieces",[]):
		if TREES.has(str(p.id)): _tree_parts(str(p.id))
	for p: Dictionary in data.get("pieces",[]): box_of(str(p.id),int(p.seed),float(p.get("weathered",0.0)))

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
	var keel := crest_top()-depth()*KEEL_REACH
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
		var base := ground(float(at[0]),float(at[2]))
		out.append([r,base-1.0,base+b.end.y,null])
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
	var holder := Node3D.new()
	holder.name = "Pieces"
	root.add_child(holder)
	build_pieces(holder)
	built_ms = Time.get_ticks_msec()-began
