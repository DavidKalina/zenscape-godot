extends RefCounted
## A ruin motif's isle, apart from any scene (docs/scenic/motif-sky.md): its
## land and ruins built into a node in the isle's own frame, its turf, the
## ground its plants grow on, its life, its plane tokens and its live bits
## (bells). Its standalone study (studies/bell_spires_isle.gd and the other
## motifs) builds it at the origin into its Art; the aqueduct isle's sky
## places it elsewhere (scripts/kit_isle/motif_isle.gd, motif_sky.gd), built
## on a worker. So `build` touches nothing but the node it is given: no
## scene, no physics queries, no tree.
##
## A motif answers: `id`, `isle_name`, `isle_card`, `top` (its datum),
## `summit`, `flora_site` and `flora_seed`, `life_script`, `pools` (the
## water the pilot wades), `plane_tokens` and `token_source`, `warm` (its
## lazy layout caches made on the main thread before a worker builds it),
## `build`; and, if it has live bits, `frame`, `landed` and `plane_near`.
## Everything it answers is in its own frame (the standalone scene's world).
##
## A family (docs/design/roguelike/motif-families.md): a motif that answers
## `family` true is a template a layer generator can place, the way a trap
## answers scripts/traps/trap.gd. One family gives many isles:
## - `configure(seed, over)` before `build` picks the isle: the seed rolls
##   the knobs (`roll`), `over` pins any of them. Same seed and knobs, the
##   same isle; `default_seed` at its rolled knobs is the authored isle,
##   exactly. `knob_choices` lists each knob's values (the gallery and the
##   generator step through them); `knobs` holds the ones in force.
## - `sockets`: where it connects and what it holds, each a Dictionary
##   (`socket`) in its own frame, on its walked ground: "rim" (where an
##   edge to another isle attaches: facing out over the drop, its run-up
##   the clear ground behind it), "arena" (a flat clear area for an on-isle
##   trap or enemy, `room` its radius), "cover" (out of the sky dragon's
##   sight from above: stone over and round it), "perch" (a trader's or a
##   ledger activity's place). Read off the plan, before and without a
##   build, so a generator can place it unbuilt.
## - `role` ("hero" a landmark, "filler", "arena"), `footprint` (its x z
##   rect), `height_span` (its keel's bottom to its highest top, y) and
##   `build_cost` (ms, measured headless) for packing a layer.
## Run-ups and rooms are in the pilot's own reach (`pilot`), never metres
## copied from elsewhere.
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Footbridge = preload("res://scripts/footbridge.gd")
const Ledger = preload("res://scripts/ledger/ledger.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
## What the bake read off the built isles (sockets, occupancy): a motif not
## yet a family answers its sockets, footprint and height span from it.
const LayerPieces = preload("res://scripts/roguelike/layer_pieces.gd")

## The socket kinds.
const SOCKET_KINDS := ["rim","arena","cover","perch"]
## The roles a family plays in a layer.
const ROLES := ["hero","filler","arena"]

## The Art node it was built into, and its lands: [land, outline (or null
## for its meta), cliffs] each, registered as turf by whoever stands it.
var art: Node3D
var lands: Array = []
## Seconds the build took (ms).
var built_ms := 0

func id() -> String:
	return ""

func isle_name() -> String:
	return ""

func isle_card() -> Dictionary:
	return {}

func top() -> float:
	return 30.0

func summit() -> Vector3:
	return Vector3(0.0,top(),0.0)

func flora_site() -> KitFlora.Site:
	return KitFlora.Site.new(top())

func flora_seed() -> int:
	return 15

func life_script() -> Script:
	return null

func pools() -> Array:
	return []

## The plane's tokens: [line id, category, kind, points].
func plane_tokens() -> Array:
	return []

func token_source() -> String:
	return id()

## The lazy caches its build and its life share (layouts, paths, platforms),
## made once on the main thread so a worker's build never races them.
func warm() -> void:
	KitLook.palette()
	KitLook.ground_material()
	KitLook.rock_material()
	KitLook.rock_tone(Vector3.ZERO,30.0,Vector3.UP)
	KitWater.material()
	RuinKit.materials()

## Builds the land and ruins into `into` (its Art), filling `lands`.
func build(into: Node3D) -> void:
	art = into

## A land to register as turf (`add_turf`'s arguments).
func turf(land: Node3D, outline: Variant = null, cliffs := true) -> void:
	lands.append([land,outline,cliffs])

## A clean, invisible box over `rect` (x, z) from `bottom` to `top` in
## `frame` (the station's boxes under the stone, as kit_isle `_solid`).
func solid_box(rect: Rect2, bottom: float, high: float, frame := Transform3D.IDENTITY) -> void:
	var solid := StaticBody3D.new()
	solid.transform = frame*Transform3D(Basis.IDENTITY,Vector3(rect.get_center().x,(high+bottom)*0.5,rect.get_center().y))
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(rect.size.x,high-bottom,rect.size.y)
	collider.shape = box
	solid.add_child(collider)
	art.add_child(solid)

## Each frame: its live bits (`host` the scene or the placed isle: its
## `_atmosphere`, `_motion_time`).
func frame(_delta: float, _host: Node) -> void:
	pass

## The pilot came down at `feet` (world).
func landed(_feet: Vector3) -> void:
	pass

## The plane flies at `at` (world) this frame.
func plane_near(_at: Vector3) -> void:
	pass

## Whether its rope bridges' resting decks stand as walk boxes
## (scripts/kit_isle/deck_ground.gd `rest_decks`).
func rest_decks() -> bool:
	return false

# --- The family ------------------------------------------------------------------

## The isle's seed and its knobs in force (`configure`; the default seed's
## until then).
var isle_seed := -1
var knobs: Dictionary = {}

## Whether it answers the family's contract (a template, not one isle).
func family() -> bool:
	return false

## The seed that builds the authored isle.
func default_seed() -> int:
	return 0

## Each knob's values, in order: key -> Array (a number range as its steps).
func knob_choices() -> Dictionary:
	return {}

## The knobs `at_seed` gives (the authored isle's at `default_seed`).
func roll(_at_seed: int) -> Dictionary:
	return {}

## Picks the isle before it is built: `at_seed` rolls the knobs, `over` pins
## any of them (a value outside `knob_choices` is clamped to the nearest).
func configure(at_seed: int, over := {}) -> RefCounted:
	isle_seed = at_seed
	knobs = roll(at_seed)
	var choices := knob_choices()
	for key: String in over:
		if not knobs.has(key): continue
		knobs[key] = _nearest(choices.get(key,[]),over[key])
	_plan_changed()
	return self

## The seed in force (the default's until configured).
func current_seed() -> int:
	if isle_seed < 0: configure(default_seed())
	return isle_seed

## The knob in force.
func knob(key: String) -> Variant:
	current_seed()
	return knobs[key]

## The knobs changed: a family drops its cached plan here.
func _plan_changed() -> void:
	pass

static func _nearest(choices: Array, value: Variant) -> Variant:
	if choices.is_empty() or choices.has(value): return value
	if not (value is float or value is int): return choices[0]
	var best: Variant = choices[0]
	for c: Variant in choices:
		if (c is float or c is int) and absf(float(c)-float(value)) < absf(float(best)-float(value)): best = c
	return best

## Where it connects and what it holds (its frame): `socket` each. A
## motif not yet a family answers what the bake found on it (scripts/
## roguelike/layer_pieces.gd: its rims, each with its `lip`, and its clear
## spots as perches and arenas; no cover), none if it was never baked.
func sockets() -> Array:
	return LayerPieces.sockets(id()) if LayerPieces.has(id()) else []

## "hero" (a landmark the layer is built round), "filler" (a stretch of
## route between), "arena" (an isle given over to a fight or a trap).
func role() -> String:
	return "filler"

## Its x z rect in its own frame (everything it builds stands over it);
## a motif not yet a family, the bake's.
func footprint() -> Rect2:
	return LayerPieces.footprint(id()) if LayerPieces.has(id()) else Rect2()

## Its lowest keel to its highest top (y, its frame); a motif not yet a
## family, the bake's lowest and highest solid.
func height_span() -> Vector2:
	return LayerPieces.height_span(id()) if LayerPieces.has(id()) else Vector2(top()-30.0,top())

## Roughly how long `build` takes (ms, headless, this Mac): a generator
## spreads the slow ones over frames.
func build_cost() -> int:
	return 0

## A socket: `kind` (SOCKET_KINDS), its `name`, `at` (on the walked ground,
## its frame), `face` (flat, unit: a rim's way out over the drop; the way
## the others open), `room` (m: an arena's clear radius, the flat round
## the others), `run_up` (m of clear ground behind `at` along -face: what
## a rim gives to build speed before it). A rim may also answer `lip`: how
## far ahead of `at` its walked ground ends (its `room`, a step, if not).
static func socket(kind: String, name: String, at: Vector3, face: Vector3, room: float, run_up := 0.0) -> Dictionary:
	var flat := Vector3(face.x,0.0,face.z)
	return {"kind":kind,"name":name,"at":at,"face":flat.normalized() if flat.length() > 0.001 else Vector3.FORWARD,"room":room,"run_up":run_up}

## The pilot as sizes are read from: a motor at the wanderer's size (as the
## traps' `pilot`).
static func pilot() -> PilotMotor:
	var p := PilotMotor.new()
	p.set_size(WorldScale.wanderer)
	return p

## The pilot's running small hop (m, flat): what a jump-only gap is a share
## of (scripts/traps/trap_logs.gd `hop_reach`).
static func hop_reach() -> float:
	var p := pilot()
	return p.run*2.0*sqrt(2.0*float(p.jumps[0])/p.gravity)

## The run-up a rim wants: the run's pace for 0.75 s (the traps' `run_up`).
static func run_up_wanted() -> float:
	return pilot().run*0.75

## A block, what a run-up or a room keeps clear of: a disc ([middle (x,
## z), radius]) or a piece's footprint ([its frame (x, z), its rect in
## it], `piece_block`).
## How far a walk from `from` along `way` (flat, unit) runs clear of
## `blocks`, up to `most` (m).
static func clear_run(from: Vector2, way: Vector2, blocks: Array, most: float) -> float:
	var best := most
	for b: Array in blocks:
		if b[0] is Transform2D:
			var inv := (b[0] as Transform2D).affine_inverse()
			var o := inv*from
			var w := inv.basis_xform(way)
			var box: Rect2 = b[1]
			# The slab test: where the ray enters the rect (0 if it starts in it).
			var t0 := -INF
			var t1 := INF
			for k in range(2):
				var lo := box.position[k]
				var hi := box.end[k]
				if absf(w[k]) < 1e-6:
					if o[k] < lo or o[k] > hi: t0 = INF
					continue
				var a := (lo-o[k])/w[k]
				var c := (hi-o[k])/w[k]
				t0 = maxf(t0,minf(a,c))
				t1 = minf(t1,maxf(a,c))
			if t0 <= t1 and t1 >= 0.0: best = minf(best,maxf(t0,0.0))
			continue
		var centre: Vector2 = b[0]
		var r: float = b[1]
		var rel := centre-from
		var along := rel.dot(way)
		if along < -r: continue
		var off := absf(rel.cross(way))
		if off >= r: continue
		best = minf(best,maxf(along-sqrt(r*r-off*off),0.0))
	return best

## How far from `c` along `way` (flat, unit) its outline `poly` reaches.
static func reach_out(poly: PackedVector2Array, c: Vector2, way: Vector2) -> float:
	var best := 0.0
	var far := c+way*1000.0
	for k in range(poly.size()):
		var hit: Variant = Geometry2D.segment_intersects_segment(c,far,poly[k],poly[(k+1)%poly.size()])
		if hit != null: best = maxf(best,c.distance_to(hit))
	return best

## How far `p` stands from the nearest of `blocks` (0 in one).
static func room_at(p: Vector2, blocks: Array) -> float:
	var best := INF
	for b: Array in blocks:
		if b[0] is Transform2D:
			var o := (b[0] as Transform2D).affine_inverse()*p
			var box: Rect2 = b[1]
			var dx := maxf(maxf(box.position.x-o.x,o.x-box.end.x),0.0)
			var dz := maxf(maxf(box.position.y-o.y,o.y-box.end.y),0.0)
			best = minf(best,Vector2(dx,dz).length())
		else:
			best = minf(best,maxf((p.distance_to(b[0]))-float(b[1]),0.0))
	return best

static var _boxes := {}
## Whether `_boxes` gained a piece since `boxes_kept` (scripts/roguelike/
## isle_store.gd keeps them between launches: a piece's footprint is its
## build's, so the same code gives the same box).
static var boxes_new := false

## The footprints kept (the isle store's), merged in.
static func boxes_take(kept: Dictionary) -> void:
	for k: String in kept:
		if not _boxes.has(k): _boxes[k] = kept[k]

static func boxes_all() -> Dictionary:
	return _boxes
## The kit's piece `id` (RuinKit `piece`, its seed and weathering) as a
## block standing at `pose` (its frame in the isle's): its colliders'
## footprint (x, z) in its own frame, grown by `margin`, measured off the
## piece itself once and kept. On the main thread (it builds the piece).
static func piece_block(id: String, seed_value: int, weathered: float, pose: Transform3D, margin := 0.3) -> Array:
	var key := "%s/%d/%s" % [id,seed_value,weathered]
	if not _boxes.has(key):
		var piece: Node3D = RuinKit.piece(id,seed_value,weathered)
		var box := Rect2()
		var first := true
		for node: Node in piece.find_children("*","CollisionShape3D",true,false):
			var shape := node as CollisionShape3D
			if shape.shape == null: continue
			var frame := Transform3D.IDENTITY
			var up: Node = shape
			while up != piece:
				frame = (up as Node3D).transform*frame
				up = up.get_parent()
			var aabb := frame*shape.shape.get_debug_mesh().get_aabb()
			var flat := Rect2(aabb.position.x,aabb.position.z,aabb.size.x,aabb.size.z)
			box = flat if first else box.merge(flat)
			first = false
		piece.free()
		_boxes[key] = box
		boxes_new = true
	var x := Vector2(pose.basis.x.x,pose.basis.x.z)
	var z := Vector2(pose.basis.z.x,pose.basis.z.z)
	return [Transform2D(x,z,Vector2(pose.origin.x,pose.origin.z)),(_boxes[key] as Rect2).grow(margin)]
