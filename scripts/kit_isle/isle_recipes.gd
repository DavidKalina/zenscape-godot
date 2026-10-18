extends Node3D
## The island view's edits back in the game (docs/design/world-editor/
## spec-world-editor.md, goal 4's return): each of the aqueduct isle's
## islands with a recipe, `motifs/authored/isle_<name>.json` (the motif
## editor's save on base "island/<name>", scripts/kit_isle/
## isle_island_motif.gd), gets that recipe's pieces, traps (the mechanics
## too) and swing ropes over it, and its spawn marker, if moved, is where
## he starts.
##
## The recipe is in the island's coded frame (the island view stands it at
## its coded world spot), so all of it is laid in one holder, a child of
## the island's land ("Recipe"), at the coded frame: when the world view
## moves the island (scripts/world_islands.gd, a drag or the layout file's
## move at load) the holder rides with the land, nothing else to carry.
## The pieces are built once; the traps and ropes are rebuilt where the
## island was let go (`moved`), as they keep their rest places when built.
##
## Stands in the study's `foot_pieces` slot round what stood there (the
## foot route, the sluice), as scripts/traps/sluice_aqueduct.gd does.
const MotifAuthored = preload("res://scripts/kit_isle/motif_authored.gd")
const MotifBased = preload("res://scripts/kit_isle/motif_based.gd")
const IsleIsland = preload("res://scripts/kit_isle/isle_island_motif.gd")
const Islands = preload("res://scripts/world_islands.gd")
const TrapField = preload("res://scripts/traps/trap_field.gd")
const FootPieces = preload("res://scripts/interactables/foot_pieces.gd")

## How far (m, x z) the spawn marker must stand from the island view's own
## start before it is taken as moved (the editor reseats it on the land).
const SPAWN_MOVED := 0.5

var study: Node3D
var motor: Object
var inner: Node = null
## island name -> {motif, holder, live (the traps' and ropes' node), traps
## (TrapField), ropes (FootPieces)}.
var recipes := {}

func _init() -> void:
	name = "IsleRecipes"

## The recipe file of island `island` ("island/near").
static func path_of(island: String) -> String:
	return MotifAuthored.path_of("isle_"+island.get_slice("/",1))

## Laid on `scene` (the isle, its islands registered) and hooked into its
## frame. Null when no island has a recipe (nothing changes).
static func build(scene: Node3D) -> Node3D:
	var found: Array = []
	for name: String in IsleIsland.NAMES:
		if Islands.islands.has(name) and FileAccess.file_exists(path_of(name)): found.append(name)
	if found.is_empty(): return null
	var me: Node3D = load("res://scripts/kit_isle/isle_recipes.gd").new()
	me.attach(scene,found)
	return me

func attach(scene: Node3D, names: Array) -> void:
	study = scene
	motor = scene.motor
	inner = scene.foot_pieces
	scene.foot_pieces = self
	scene.add_child(self)
	var began := Time.get_ticks_msec()
	var lines := PackedStringArray()
	for name: String in names:
		var data := MotifAuthored.read(path_of(name))
		if data.is_empty(): continue
		if str(data.get("base","")) != name:
			push_warning("isle recipes: %s is on base %s, not %s (left out)" % [path_of(name),data.get("base",""),name])
			continue
		var motif: RefCounted = MotifBased.over(data)
		var land: Node3D = Islands.islands[name].node
		var holder := Node3D.new()
		holder.name = "Recipe"
		land.add_child(holder)
		# The coded frame, where the land stands now: its move from coded (xf).
		holder.global_transform = (Islands.islands[name].xf as Transform3D)
		var pieces := Node3D.new()
		pieces.name = "Pieces"
		holder.add_child(pieces)
		motif.build_pieces(pieces)
		recipes[name] = {"motif":motif,"holder":holder,"live":null,"traps":null,"ropes":null}
		_live(name)
		var r: Dictionary = recipes[name]
		lines.append("%s %d pieces, %d traps" % [name,pieces.get_child_count(),(r.traps.traps as Array).size() if r.traps != null else 0])
		_spawn(name,motif)
	if not lines.is_empty():
		motor.push_air(self,_air)
		print("isle recipes: %s in %d ms" % ["; ".join(lines),Time.get_ticks_msec()-began])

## Island `name`'s traps and ropes laid again in its holder (the coded
## frame), what stood there before freed.
func _live(name: String) -> void:
	var r: Dictionary = recipes[name]
	if r.live != null and is_instance_valid(r.live): (r.live as Node).free()
	var node := Node3D.new()
	node.name = "Live"
	(r.holder as Node3D).add_child(node)
	r.live = node
	r.traps = null
	r.ropes = null
	var host := Host.new()
	host.owner_recipes = self
	host.recipe = r
	(r.motif as RefCounted).live(host)
	host.free()

## The recipe's spawn marker, when moved off the island view's own start:
## where he starts (in the coded frame; a saved move of the island carries
## the start after, studies/aqueduct_isle.gd `_place_saved_islands`).
func _spawn(name: String, motif: RefCounted) -> void:
	var own: Vector3 = IsleIsland.new(name).own_start()
	var at: Vector3 = motif._marker("spawn")
	if Vector2(at.x-own.x,at.z-own.z).length() < SPAWN_MOVED: return
	var xf: Transform3D = Islands.islands[name].xf
	var p := xf*at+Vector3.UP*0.05
	study.start = p
	study.set("_last_stood",p)
	print("isle recipes: %s's spawn marker moved: he starts at %s" % [name,str(p.snapped(Vector3.ONE*0.01))])

## Island `name` let go where it is (scripts/world_islands.gd `settle`, via
## the study's `island_moved`): its traps and ropes rebuilt there.
func moved(name: String) -> void:
	if recipes.has(name): _live(name)

## The host a recipe's `live` lays its traps and ropes with, in the holder.
class Host extends Node:
	var owner_recipes: Node3D
	var recipe: Dictionary

	## The coded frame is the holder's: a point stays as it is.
	func w(p: Vector3) -> Vector3:
		return p

	func rope(anchor: Vector3, length: float) -> Node3D:
		if recipe.ropes == null:
			var fp: Node3D = FootPieces.new()
			fp.study = owner_recipes.study
			fp.motor = owner_recipes.motor
			(recipe.live as Node3D).add_child(fp)
			recipe.ropes = fp
		return recipe.ropes.rope(anchor,length)

	func trap(node: Node3D) -> Node3D:
		if recipe.traps == null:
			var tf: Node3D = TrapField.new()
			tf.study = owner_recipes.study
			tf.motor = owner_recipes.motor
			(recipe.live as Node3D).add_child(tf)
			recipe.traps = tf
		return recipe.traps.add(node)

# --- The slot: what stood there, then the recipes' ----------------------------------

func _each(f: Callable) -> void:
	for name: String in recipes:
		var r: Dictionary = recipes[name]
		for k: String in ["ropes","traps"]:
			var n: Variant = r[k]
			if n != null and is_instance_valid(n): f.call(n)

func before(delta: float) -> void:
	if inner != null: inner.before(delta)
	_each(func(n: Node) -> void: n.before(delta))

func after(delta: float, events: Dictionary) -> void:
	if inner != null: inner.after(delta,events)
	_each(func(n: Node) -> void: n.after(delta,events))

func pose(figure: Node3D) -> void:
	if inner != null: inner.pose(figure)
	_each(func(n: Node) -> void: n.pose(figure))

func frame(camera: Camera3D, delta: float) -> void:
	if inner != null and inner.has_method("frame"): inner.frame(camera,delta)

func reset() -> void:
	if inner != null and inner.has_method("reset"): inner.reset()
	_each(func(n: Node) -> void: if n.has_method("reset"): n.reset())

## The recipes' traps' air (a vent's thermal) over the motor's own.
func _air(_p: Vector3, here: Dictionary) -> Dictionary:
	var out := here
	var copied := false
	for name: String in recipes:
		var tf: Variant = recipes[name].traps
		if tf == null or not is_instance_valid(tf): continue
		var extra: Dictionary = tf._air(_p)
		if extra.is_empty(): continue
		if not copied:
			out = here.duplicate()
			copied = true
		for key: Variant in extra: out[key] = (out[key]+extra[key]) if out.has(key) else extra[key]
	return out

func _exit_tree() -> void:
	if motor != null: motor.pop_air(self)
