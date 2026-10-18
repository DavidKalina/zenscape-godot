extends Node3D
## A kit isle's on-foot tokens (docs/scenic/kit-isle-shared.md; the
## aqueduct isle's, docs/scenic/aqueduct-isle-life.md): an isle's own answer
## `spots_for` with where each stands and the move it asks for. They are
## a few of the sky's foot tokens (scripts/glyph_pickup.gd, calm: slower
## turn, gentler bob, a warmer, wider halo) set where each asks for a move,
## not laid in a trail. The readout and its climbing blip are the sky's
## (scripts/collectibles_hud.gd): the isle's tokens are one line, so each
## pickup climbs a step and the last one runs the flourish.
##
## Only the pilot on foot takes them (the plane passes through): his middle
## (CollectibleLines FOOT_Y over his feet) within WALKER_REACH plus half a
## token, read along the way he moved since the last frame, as the sky's
## do. Each is one of the isle's objectives in the ledger (scripts/ledger/
## ledger.gd, "<isle>/<name>"): taking it marks it done there, saved, and a
## token done before isn't laid again; the readout counts it as found.
## Unfound, each glints far off through the telescope (scripts/
## telescope.gd `spottable`).
##
## A spot with `buried` (and `ground`, the turf's point under it) is laid
## under the turf (scripts/buried_find.gd): a faint shimmer the telescope
## glints until a slam from height breaks it open; only then, up, can it be taken.
const GlyphPickup = preload("res://scripts/glyph_pickup.gd")
const BuriedFind = preload("res://scripts/buried_find.gd")
const Hud = preload("res://scripts/collectibles_hud.gd")
const Lines = preload("res://scripts/collectible_lines.gd")
const Ledger = preload("res://scripts/ledger/ledger.gd")
const Telescope = preload("res://scripts/telescope.gd")

const GLYPH := "rune"
const SIZE := 0.7
## A mover jumping further than this in a frame (a respawn, a placing)
## starts its sweep afresh.
const JUMP := 6.0

## The tokens: {name, at, move}. Filled by `spots_for`.
var tokens: Array[Dictionary] = []
## Taken token names, in order (those done in an earlier run first).
var taken: Array[String] = []
## The isle's id in the ledger (scripts/ledger/ledger.gd `isle_id_of`).
var isle_id := ""
var hud: CanvasLayer
var _holders := {}
## name -> its BuriedFind, for the buried ones not yet taken.
var buried := {}
var _last := Vector3.INF
## A placed isle's (scripts/kit_isle/motif_isle.gd): where it stands from
## its own frame, which `spots_for` answers in.
var offset := Vector3.ZERO
## Handles (AGENTS.md): with `naming` set (an isle's own, e.g. "tokens"),
## each token standing from the start is named `<naming>/<token name>`
## through scripts/layout_overrides.gd (kind "token"): the layout file's
## move wins, a deleted one is left out, and the world view moves it. The
## buried ones stay unnamed (their dig keeps its ground). "" names none.
const Layout = preload("res://scripts/layout_overrides.gd")
var naming := ""

## Where each token stands and the move it asks for ({name, at, move}),
## worked out from the isle's own geometry (`isle` the study).
func spots_for(_isle: Node3D) -> Array[Dictionary]:
	return []

## A point under the lip of floating stone `p` on its north (-z) face,
## `along` m off its middle along the lip, where his middle is when he hangs
## from it (pilot_motor HANG_DROP under the lip, HANG_OUT off the face).
static func under_lip(p: Dictionary, along: float) -> Vector3:
	var size: Vector3 = p.size
	var basis := Basis(Vector3.UP,float(p.yaw))
	var at: Vector3 = p.at
	# Of the two faces across its width, the one facing north.
	var normal := basis.z if basis.z.z < 0.0 else -basis.z
	var side := basis.x
	return at+normal*(size.z*0.5+0.45)+side*along+Vector3.DOWN*0.4

func setup(isle: Node3D) -> void:
	name = "Tokens"
	tokens = spots_for(isle)
	if naming != "":
		tokens = tokens.filter(func(t: Dictionary) -> bool: return not Layout.deleted(naming+"/"+str(t.name)))
	isle_id = Ledger.isle_id_of(isle)
	for t: Dictionary in tokens:
		if t.at != Vector3.INF: t.at = (t.at as Vector3)+offset
		if Ledger.shared().is_done(objective(t.name)): taken.append(t.name)
	for i in range(tokens.size()):
		var t: Dictionary = tokens[i]
		if taken.has(t.name) or t.at == Vector3.INF: continue
		var holder := GlyphPickup.make(GLYPH,SIZE,float(i)*1.3,true)
		holder.name = "Token_%s" % t.name
		holder.position = t.at
		add_child(holder)
		if naming != "" and not t.get("buried",false):
			var key := naming+"/"+str(t.name)
			var coded := holder.global_transform
			Layout.track(key,holder,"token",coded)
			var moved := Layout.xform(key,coded)
			if not moved.is_equal_approx(coded):
				Layout.apply(key,moved)
				t.at = holder.global_position
		holder.motes_on(true)
		Telescope.spottable(holder,objective(t.name))
		_holders[t.name] = holder
		if t.get("buried",false):
			var ground: Vector3 = (t.ground as Vector3)+offset
			var dig := BuriedFind.new()
			dig.setup(holder,ground,objective(t.name),(t.at as Vector3).y-ground.y)
			add_child(dig)
			buried[t.name] = dig
	# A placed isle shares the sky's readout (scripts/kit_isle/motif_isle.gd
	# `token_hud`): one made here would only be freed (100-160 ms rendered).
	var shared: Node = isle.call("token_hud") if isle != null and isle.has_method("token_hud") else null
	if shared != null: hud = shared
	else:
		hud = Hud.new()
		add_child(hud)

## Token `name`'s objective id in the ledger.
func objective(token_name: String) -> String:
	return Ledger.objective_id(isle_id,token_name)

## How many are left.
func left() -> int:
	return tokens.size()-taken.size()

## The night's glow (0 by day, 1 at full night).
func glow_for(night: float) -> void:
	for holder: Node3D in _holders.values():
		if is_instance_valid(holder) and not holder.taking: holder.glow_for(night)

## The pilot's middle this frame (on foot): every token within his reach of
## the way he moved since the last is taken. `point` INF (flying) forgets
## the last.
func touch(point: Vector3) -> void:
	if point == Vector3.INF:
		_last = Vector3.INF
		return
	var from := _last if _last != Vector3.INF and _last.distance_to(point) <= JUMP else point
	_last = point
	for t: Dictionary in tokens:
		if taken.has(t.name): continue
		if buried.has(t.name) and not buried[t.name].takeable(): continue
		var at: Vector3 = t.at
		if at == Vector3.INF: continue
		# A named one stands where its holder is (the world view moves it).
		if naming != "" and _holders.has(t.name):
			var h: Node3D = _holders[t.name]
			if not is_instance_valid(h): continue
			at = h.global_position
		var near := Geometry3D.get_closest_point_to_segment(at,from,point)
		if near.distance_to(at) < Lines.WALKER_REACH+SIZE*0.5: take(t.name)

## Whether token `name` is one laid later (its spot `at` INF: a spot
## that waits, like the rune knight's spilled runes) and still waits: not
## taken (in this run or an earlier one) and not laid yet.
func waiting(token_name: String) -> bool:
	if taken.has(token_name) or _holders.has(token_name): return false
	for t: Dictionary in tokens:
		if t.name == token_name: return t.at == Vector3.INF
	return false

## Waiting token `name` laid at `at` (world) in `holder` (a GlyphPickup the
## caller made, flew in and lets go of here): from now it stands, glints
## through the telescope and is taken like the rest. False (holder left
## alone) if it doesn't wait.
func lay(token_name: String, at: Vector3, holder: Node3D) -> bool:
	if not waiting(token_name): return false
	for t: Dictionary in tokens:
		if t.name == token_name: t.at = at
	if holder.get_parent() != null: holder.get_parent().remove_child(holder)
	holder.name = "Token_%s" % token_name
	add_child(holder)
	holder.global_position = at
	holder.motes_on(true)
	Telescope.spottable(holder,objective(token_name))
	_holders[token_name] = holder
	return true

## Token `name` taken: it twists away, the readout climbs a step.
func take(name: String) -> void:
	if taken.has(name) or not _holders.has(name): return
	taken.append(name)
	Ledger.shared().mark_done(objective(name))
	var holder: Node3D = _holders[name]
	if is_instance_valid(holder): holder.take(hash(name) & 0xffff)
	_holders.erase(name)
	if hud != null: hud.show_pickup(GLYPH,taken.size(),taken.size(),tokens.size())
