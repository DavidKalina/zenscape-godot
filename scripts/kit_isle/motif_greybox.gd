extends "res://scripts/kit_isle/kit_motif.gd"
## A greybox motif: one of the greybox studies (studies/greybox/<slug>.gd,
## its card) as an isle, in the studies' own grey / orange / green / blue
## look, its traps and heads live on it (scripts/kit_isle/greybox/
## registry.gd).
##
## A subclass supplies data only; this answers the motif contract
## (kit_motif.gd) from it: `footprint`, `height_span` and `occupancy` are
## computed from its parts (no bake: tools/bake_layer_pieces.gd never sees
## it, scripts/roguelike/layer_plan.gd `_motif_isle` asks `occupancy`),
## `sockets` from its rims and spots, `build` its parts into a node (no
## physics queries, safe on a worker), `role` "filler" (a subclass that is
## a neighbourhood's landmark answers "hero": never the greed isle, one a
## neighbourhood; with the greybox motifs most of the pool, heroes would
## leave a layer short of isles).
##
## A turfed greybox (the grey boxes remade on the real look, skill
## motif-turf) supplies its turf as data too: `turf_seed()` (>= 0 turns the
## pass on), `turf_islands()` (KitLand island specs, collided as drawn),
## `turf_paths()` (its worn ways), `turf_cost()`, and `dress(root)` for its
## stone and water; `grey_flag()` names the launch flag that builds the
## grey boxes instead (`grey()`). This builds the islands, registers their
## turf, adds their keels to the occupancy, warms the look and answers
## `life_script`, `flora_site`, `flora_seed` and `build_cost` from them.
## A motif whose land diverges (seeds of its own, islands not collided)
## keeps its own `build` and asks KitLand for `"collide_sides"` itself.
##
## HOW TO CONVERT THE NEXT GREYBOX (one file, one registry line):
## 1. Copy scripts/kit_isle/greybox/gb_sunken_giant.gd to gb_<slug>.gd. Copy
##    the study's numbers and LAYOUT verbatim (same geometry, so its chains
##    keep their numbers; never re-derive them). Everything stays in the
##    study's own frame: the generator only moves an isle, never turns it.
## 2. `slug`, `isle_name`, `epithet`, `brief` (one or two lines: what it is
##    for and how to play it, shown on the HUD on arrival).
## 3. `parts()`: the LAYOUT as character_study parts ("box", "cyl", "ramp",
##    "obox", "water", "label": studies/character_study.gd STATIONS has the
##    schema). A study's stand-in "next isle" that catches its exit chain
##    becomes part of the motif (the giant's knee), so the chain still lands
##    somewhere fixed; put the rim out on its far edge (step 4). Keep other
##    stand-ins that are part of the motif (a vent, a gantry).
## 4. `rims()`: where the generator's crossings attach, {name, at (on the
##    walked ground, ~1 m in from the edge), face (out over the drop),
##    run_up (clear ground behind), lip (m from `at` to the edge)}. At least
##    two: the way in (the study's start) and the way out (where its exit
##    chain throws you: put the rim there so a crossing catches it). The
##    first is taken as the way in and the last the way out (`way`: "in",
##    "out" or "" both, to say otherwise); the route keeps to them. Rims
##    at the top let the route skip the climb, so keep them few.
## 5. `spots()`: {kind "arena" | "cover" | "perch", name, at, room}.
## 6. `heads()`: the study's inhaler heads, {at, face (x, z), knobs} with
##    knobs as the study passes them (routes in the study's frame). They
##    join the layer's heads (plan.heads, scripts/roguelike/layer_greybox.gd
##    `lay_heads`), so the stage spawns, voices and steps them and the
##    headless bodies come for them (a body takes its head away: a relay
##    of heads holds only with `--knob=bodies=0`, see the doc). Other
##    enemies (rams, bodies as enemies) go in `live`.
## 7. `live(g)`: anything else that moves (traps, ropes, cannons, other
##    enemies), made as the study's `_build_room` makes them, with `g`
##    (layer_greybox.gd, the live host) giving the world frame: `g.w(p)` a
##    point, `g.wr(rect)` a Rect2 (x, z), `g.rope(anchor, length)`,
##    `g.trap(node)` (a scripts/traps/trap.gd, stepped round the motor, its
##    air summed into the motor's), `g.enemy(script, at, face, knobs)` (into
##    the stage's EnemyField), `g.cannons()`. Pass world points (w()).
##    Use the study's own trap classes (`load(STUDY).Updraft`) so they keep
##    their numbers.
## 8. One line in scripts/kit_isle/greybox/registry.gd MOTIFS (and its grey
##    flag in studies/motif_yard.gd GREY_FLAGS and tools/harness/chain.gd).
##    Then check: the motif alone in the motif yard (`python tools/smoke.py
##    studies/motif_yard.tscn -- --motif=<slug> [--grey]`), its chains
##    there through the real input, 10 jittered trials each, grey and turf
##    (a driver on tools/harness/chain.gd; tools/harness/examples/
##    plumb_well_chain.gd is the one to copy; tools/README.md "The motif
##    yard").
const COLOURS := {
	"grey":Color(0.62,0.62,0.6),"floor":Color(0.64,0.64,0.62),"wall":Color(0.52,0.54,0.57),
	"lip":Color(0.96,0.55,0.16),"pad":Color(0.44,0.74,0.4),"dark":Color(0.34,0.35,0.38),
	"lane":Color(0.86,0.85,0.78),"tick":Color(0.2,0.2,0.22),
}
const WATER := Color(0.22,0.5,0.86,0.5)
const GRID := preload("res://shaders/character_study_grid.gdshader")
## The occupancy's cell (m), the bake's.
const CELL := 2.0
## The turf's life and its stone (`warm_turf`).
const TurfLife = preload("res://scripts/kit_isle/kit_life.gd")
const TurfStone = preload("res://scripts/kit_isle/greybox/giant_stone.gd")
## How far a turf island's keel spurs hang under top-depth (KitLand
## ring_sides: the last ring 0.92 deep x 1.15, a spur 0.3 more), for the
## occupancy.
const TURF_KEEL_REACH := 1.4

static var _materials := {}
static var _cache := {}
static var _lock := Mutex.new()

# --- What a subclass supplies --------------------------------------------------

func slug() -> String:
	return ""

## The study it was converted from (res:// path), for its trap classes.
func study_path() -> String:
	return "res://studies/greybox/%s.gd" % slug()

func epithet() -> String:
	return ""

## One or two lines: what it is for and how to play it.
func brief() -> String:
	return ""

## The parts, character_study's schema, in the study's frame.
func parts() -> Array:
	return []

## Rims: [{name, at, face, run_up, lip}].
func rims() -> Array:
	return []

## Spots: [{kind, name, at, room}].
func spots() -> Array:
	return []

## Inhaler heads: [{at, face (Vector2), knobs}].
func heads() -> Array:
	return []

## Where its route begins (the study's start), for the HUD and checks.
func start() -> Vector3:
	return Vector3.ZERO

## Everything else that moves, made in the layer (`g` the live host).
func live(_g: Node) -> void:
	pass

# --- What a turfed subclass supplies (all optional) ------------------------------

## The launch flag that builds the grey boxes instead of the turf (A/B
## checks; studies/motif_yard.gd `--grey` passes it): "" none.
func grey_flag() -> String:
	return ""

## The turf's seed: its islands' (seed+k unless a spec gives its own), its
## tone's, its flora's (+9). -1: no turf pass (the grey boxes, or a
## subclass that builds its own).
func turf_seed() -> int:
	return -1

## The turf's islands, built in order: KitLand.island specs plus `name`.
## Left out: `seed` (turf_seed()+k), `ground` (flat at `top`), `hang`
## (true), `tone` (`turf_tone`), `collide_sides` (true). Each island's
## keel joins the occupancy (`keel`: false to leave it out).
func turf_islands() -> Array:
	return []

## The worn ways (KitLand.wear_of), for the tone and the flora.
func turf_paths() -> Array:
	return []

## The turf's tone (KitLook.turf).
func turf_tone() -> Callable:
	return KitLook.turf(turf_seed(),KitLand.wear_of(turf_paths()))

## Roughly how long the turf build takes (ms, headless).
func turf_cost() -> int:
	return 0

## The look its turf build needs, made on the main thread (`warm`).
func warm_turf() -> void:
	warm_look()
	RuinKit.materials()
	TurfStone.warm()

## Everything past the islands (stone, water), into `root`.
func dress(_root: Node3D) -> void:
	pass

# --- The grey / turf switch ----------------------------------------------------------

## Whether `flag` was passed at launch ("" never).
static func flagged(flag: String) -> bool:
	return flag != "" and preload("res://scripts/launch_args.gd").user_args().has(flag)

## Built as grey boxes (its grey flag passed).
func grey() -> bool:
	return flagged(grey_flag())

## Built on the real look (a turf pass, and not grey).
func has_turf() -> bool:
	return turf_seed() >= 0 and not grey()

# --- The motif contract, answered from the data -----------------------------------

func id() -> String:
	return "gb_"+slug()

func isle_card() -> Dictionary:
	return {"name":isle_name(),"epithet":epithet()}

func role() -> String:
	return "filler"

func top() -> float:
	return start().y

func summit() -> Vector3:
	var best := Vector3(0.0,-INF,0.0)
	for s: Dictionary in spots():
		if (s.at as Vector3).y > best.y: best = s.at
	return best if best.y > -INF else Vector3(0.0,top(),0.0)

func pools() -> Array:
	var out: Array = []
	for p: Array in parts():
		if p[0] == "water": out.append({"rect":p[1],"top":float(p[3])})
	return out

func sockets() -> Array:
	var out: Array = []
	var all := rims()
	for k in range(all.size()):
		var r: Dictionary = all[k]
		var s := socket("rim",str(r.name),r.at,_v3(r.face),float(r.get("lip",1.0)),float(r.run_up))
		s.lip = float(r.get("lip",1.0))
		# Its way: the first rim the way in, the last the way out (a rim's
		# own "way" wins), so the generator's route runs the chain forwards
		# (scripts/roguelike/layer_plan.gd `ins_of`, `can_out`).
		s.way = str(r.get("way","in" if k == 0 else ("out" if k == all.size()-1 else "")))
		out.append(s)
	for s: Dictionary in spots():
		out.append(socket(str(s.kind),str(s.name),s.at,_v3(s.get("face",Vector3.FORWARD)),float(s.room)))
	return out

static func _v3(v: Variant) -> Vector3:
	if v is Vector2: return Vector3((v as Vector2).x,0.0,(v as Vector2).y)
	return v

func footprint() -> Rect2:
	return _computed().foot

func height_span() -> Vector2:
	return _computed().span

## Per CELL m column its lowest and highest solid (LayerPieces' format),
## from the parts; computed once a motif.
func occupancy() -> Dictionary:
	return _computed().occ

func warm() -> void:
	materials()
	_computed()
	if has_turf(): warm_turf()

func life_script() -> Script:
	return TurfLife if has_turf() else null

func build_cost() -> int:
	return turf_cost() if has_turf() else 0

func flora_site() -> KitFlora.Site:
	if turf_seed() < 0: return super.flora_site()
	return KitFlora.Site.new(top(),KitLand.wear_of(turf_paths()))

func flora_seed() -> int:
	return turf_seed()+9 if turf_seed() >= 0 else super.flora_seed()

# --- Computed from the parts ----------------------------------------------------

## Each solid as [Rect2 (x, z), bottom, top, ramp (or null)]: the parts'
## and, with turf, its islands' keels.
func _solids() -> Array:
	var out := _part_solids()
	if has_turf(): out.append_array(_keels())
	return out

## Under each turf island its keel's reach (inside its outline's box).
func _keels() -> Array:
	var out: Array = []
	for spec: Dictionary in turf_islands():
		if not bool(spec.get("keel",true)): continue
		var ring: Array = spec.outline
		var box := Rect2(ring[0],Vector2.ZERO)
		for p: Vector2 in ring: box = box.expand(p)
		var high := float(spec.top)
		out.append([box.grow(-1.0),high-float(spec.depth)*TURF_KEEL_REACH,high,null])
	return out

## Each solid part as [Rect2 (x, z), bottom, top, ramp (or null)].
func _part_solids() -> Array:
	var out: Array = []
	for p: Array in parts():
		match p[0]:
			"box": out.append([p[1],float(p[2]),float(p[3]),null])
			"cyl":
				var c: Vector2 = p[1]
				var r := float(p[2])
				out.append([Rect2(c-Vector2.ONE*r,Vector2.ONE*r*2.0),float(p[3]),float(p[4]),null])
			"water": out.append([p[1],float(p[2]),float(p[3]),null])
			"obox":
				var mid: Vector3 = p[1]
				var size: Vector3 = p[2]
				var b := Basis(Vector3.UP,deg_to_rad(float(p[3])))
				var ext := (b.x*size.x*0.5).abs()+(b.z*size.z*0.5).abs()
				out.append([Rect2(mid.x-ext.x,mid.z-ext.z,ext.x*2.0,ext.z*2.0),mid.y-size.y*0.5,mid.y+size.y*0.5,null])
			"ramp":
				var low: Vector3 = p[1]
				var high: Vector3 = p[2]
				var w := float(p[3])
				var along := Vector2(high.x-low.x,high.z-low.z)
				var side := Vector2(-along.y,along.x).normalized()*w*0.5
				var r := Rect2(Vector2(low.x,low.z)+side,Vector2.ZERO)
				for q: Vector2 in [Vector2(low.x,low.z)-side,Vector2(high.x,high.z)+side,Vector2(high.x,high.z)-side]: r = r.expand(q)
				out.append([r,minf(low.y,high.y)-0.45,maxf(low.y,high.y),[low,high,w]])
	return out

func _computed() -> Dictionary:
	var key := id()
	_lock.lock()
	if not _cache.has(key):
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
					var bottom := float(s[1])
					var high := float(s[2])
					if s[3] != null:
						# A ramp: its top over this cell's middle, if the cell is on it.
						var low_e: Vector3 = s[3][0]
						var high_e: Vector3 = s[3][1]
						var a := Vector2(low_e.x,low_e.z)
						var d := Vector2(high_e.x,high_e.z)-a
						var q := origin+Vector2(col+0.5,row+0.5)*CELL
						var t := clampf((q-a).dot(d)/d.length_squared(),0.0,1.0)
						if (a+d*t).distance_to(q) > float(s[3][2])*0.5+CELL*0.75: continue
						high = lerpf(low_e.y,high_e.y,t)
						bottom = high-0.45
					var k := row*cols+col
					lo[k] = minf(lo[k],bottom)
					hi[k] = maxf(hi[k],high)
		_cache[key] = {"foot":foot,"span":span,"occ":{"origin":origin,"cell":CELL,"cols":cols,"rows":rows,"lo":lo,"hi":hi}}
	var out: Dictionary = _cache[key]
	_lock.unlock()
	return out

# --- The build (nodes only: a worker may run it) --------------------------------------

## The greybox materials, one per colour (made on the main thread: `warm`).
static func materials() -> Dictionary:
	if _materials.is_empty():
		for colour: String in COLOURS:
			var m := ShaderMaterial.new()
			m.shader = GRID
			m.set_shader_parameter("tint",COLOURS[colour])
			_materials[colour] = m
		var water := StandardMaterial3D.new()
		water.albedo_color = WATER
		water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		water.roughness = 0.1
		water.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materials["water"] = water
	return _materials

## The turf (its islands, then `dress`), or the grey boxes.
func build(into: Node3D) -> void:
	if not has_turf():
		build_grey(into)
		return
	art = into
	var began := Time.get_ticks_msec()
	var root := Node3D.new()
	root.name = slug().to_pascal_case()
	into.add_child(root)
	var tone := turf_tone()
	var specs := turf_islands()
	for k in range(specs.size()):
		var spec: Dictionary = (specs[k] as Dictionary).duplicate()
		if not spec.has("seed"): spec.seed = turf_seed()+k
		if not spec.has("ground"):
			var y := float(spec.top)
			spec.ground = func(_x: float, _z: float) -> float: return y
		if not spec.has("hang"): spec.hang = true
		if not spec.has("tone"): spec.tone = tone
		if not spec.has("collide_sides"): spec.collide_sides = true
		var land := KitLand.island(spec)
		land.name = str(spec.name)
		root.add_child(land)
		turf(land)
	dress(root)
	built_ms = Time.get_ticks_msec()-began

## The grey boxes: the parts as the study draws them.
func build_grey(into: Node3D) -> void:
	art = into
	var began := Time.get_ticks_msec()
	materials()
	var root := Node3D.new()
	root.name = "Greybox_"+slug()
	into.add_child(root)
	for p: Array in parts():
		match p[0]:
			"box":
				var r: Rect2 = p[1]
				var size := Vector3(r.size.x,float(p[3])-float(p[2]),r.size.y)
				var at := Vector3(r.get_center().x,(float(p[3])+float(p[2]))*0.5,r.get_center().y)
				_solid(root,_box_mesh(size),_box_shape(size),Transform3D(Basis.IDENTITY,at),p[4])
				if p[4] == "lip": _cap(root,Vector3(at.x,float(p[3]),at.z),Vector3(r.size.x,0.0,r.size.y),0.0)
			"cyl":
				var c: Vector2 = p[1]
				var radius := float(p[2])
				var tall := float(p[4])-float(p[3])
				var mesh := CylinderMesh.new()
				mesh.top_radius = radius
				mesh.bottom_radius = radius
				mesh.height = tall
				mesh.radial_segments = 32 if radius > 1.0 else 12
				var shape := CylinderShape3D.new()
				shape.radius = radius
				shape.height = tall
				_solid(root,mesh,shape,Transform3D(Basis.IDENTITY,Vector3(c.x,(float(p[3])+float(p[4]))*0.5,c.y)),p[5])
				if p[5] == "lip": _cap(root,Vector3(c.x,float(p[4]),c.y),Vector3.ZERO,radius)
			"obox":
				var mid: Vector3 = p[1]
				var size: Vector3 = p[2]
				var turned := Basis(Vector3.UP,deg_to_rad(float(p[3])))
				_solid(root,_box_mesh(size),_box_shape(size),Transform3D(turned,mid),p[4])
				if p[4] == "lip":
					var cap := MeshInstance3D.new()
					cap.mesh = _box_mesh(Vector3(size.x+0.02,0.1,size.z+0.02))
					cap.transform = Transform3D(turned,mid+Vector3(0.0,size.y*0.5-0.045,0.0))
					cap.material_override = _materials["lip"]
					root.add_child(cap)
			"ramp":
				var low: Vector3 = p[1]
				var high: Vector3 = p[2]
				var along := (high-low).normalized()
				var side := Vector3.UP.cross(along).normalized()
				var up := along.cross(side).normalized()
				var size := Vector3(float(p[3]),0.4,low.distance_to(high)+0.02)
				_solid(root,_box_mesh(size),_box_shape(size),Transform3D(Basis(side,up,along),(low+high)*0.5-up*0.2),p[4])
			"water":
				var r: Rect2 = p[1]
				var mesh := MeshInstance3D.new()
				mesh.mesh = _box_mesh(Vector3(r.size.x,float(p[3])-float(p[2]),r.size.y))
				mesh.position = Vector3(r.get_center().x,(float(p[2])+float(p[3]))*0.5,r.get_center().y)
				mesh.material_override = _materials["water"]
				mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				root.add_child(mesh)
			"label": _label(root,p[1],p[2],28)
	_label(root,start()+Vector3(0.0,3.2,0.0),"GREYBOX · %s" % isle_name().to_upper(),56)
	built_ms = Time.get_ticks_msec()-began

static func _box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh

static func _box_shape(size: Vector3) -> BoxShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	return shape

static func _solid(root: Node3D, mesh: Mesh, shape: Shape3D, place: Transform3D, colour: String) -> void:
	var solid := StaticBody3D.new()
	solid.transform = place
	var collider := CollisionShape3D.new()
	collider.shape = shape
	solid.add_child(collider)
	var drawn := MeshInstance3D.new()
	drawn.mesh = mesh
	drawn.material_override = _materials["grey" if colour == "lip" else colour]
	solid.add_child(drawn)
	root.add_child(solid)

static func _cap(root: Node3D, at: Vector3, size: Vector3, radius: float) -> void:
	var mesh := MeshInstance3D.new()
	if radius > 0.0:
		var disc := CylinderMesh.new()
		disc.top_radius = radius+0.01
		disc.bottom_radius = radius+0.01
		disc.height = 0.1
		disc.radial_segments = 32
		mesh.mesh = disc
	else:
		mesh.mesh = _box_mesh(Vector3(size.x+0.02,0.1,size.z+0.02))
	mesh.position = at-Vector3(0.0,0.045,0.0)
	mesh.material_override = _materials["lip"]
	root.add_child(mesh)

static func _label(root: Node3D, at: Vector3, text: String, size: int) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.outline_size = 10
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.12,0.12,0.14)
	label.outline_modulate = Color(1.0,1.0,1.0,0.85)
	label.position = at
	root.add_child(label)
