extends "res://scripts/kit_isle/kit_caches.gd"
## The wreck cluster's caches (spec-wreck-colonnade.md item 10's change): a
## breakable kit piece on each of Art.CACHES' spots, and the deal's hidden
## parts inside them. The kit caches (scripts/kit_isle/kit_caches.gd: the
## one-spot glint, the dust puff off a too-weak hit, the find stepping out
## of the rubble), holding a plane part instead of a glyph: the find is the
## wreck arc's own hidden holder (scripts/plane_arc/wreck_arc.gd), handed
## back to it (`unhide`) once it has settled, then taken as any laid part.
## A cache piece that hides nothing this deal breaks to rubble.
##
## Use: `WreckCaches.stand(cluster, hidden)` builds the pieces, a kit
## breakable on the cluster's own breakables hub (the slam and side slam
## reach it: scripts/breaks/breakables.gd), and the caches; again on a
## re-deal, which frees the old set (broken pieces, rubble and all) first.
## `hidden`: spot index -> part id.
const KitBreaks = preload("res://scripts/breaks/kit_breaks.gd")
const Breakables = preload("res://scripts/breaks/breakables.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Layout = preload("res://scripts/layout_overrides.gd")
const Art = preload("res://studies/wreck_cluster_art.gd")

## How far each piece sinks into what it stands on (m).
const SINK := 0.08

var arc: Node = null
var breaks: Node = null
var pieces: Node3D = null

## The pieces, their breaks and caches stood afresh on `cluster` (its old
## set freed), the parts in `hidden` (spot index -> part id) inside. The
## new caches node.
static func stand(cluster: Node3D, hidden: Dictionary) -> Node3D:
	var hub: Node = cluster.get_node_or_null("Breakables")
	if hub == null:
		hub = Breakables.new()
		cluster.add_child(hub)
	var old: Node = cluster.get_node_or_null("WreckCaches")
	if old != null:
		(hub.others as Array).erase(old.get("breaks"))
		old.name = "WreckCaches_old"
		old.queue_free()
	var me: Node3D = new()
	me.name = "WreckCaches"
	me.arc = cluster.get("plane_arc")
	me.motor = cluster.get("motor")
	me.make_find = me._part_find
	cluster.add_child(me)
	me.pieces = Node3D.new()
	me.pieces.name = "CachePieces"
	me.add_child(me.pieces)
	for c: Array in Art.CACHES:
		var spot := int(c[0])
		var key := Art.cache_name(spot)
		if Layout.deleted(key): continue
		var piece: Node3D = RuinKit.piece(str(c[1]),int(c[2]),float(c[4]))
		if piece == null: continue
		piece.name = "Cache_%02d" % (spot+1)
		var at: Vector3 = (Art.spots()[spot] as Array)[2]
		var coded := Transform3D(Basis(Vector3.UP,deg_to_rad(float(c[3]))),at+Vector3.DOWN*SINK)
		piece.transform = Layout.xform(key,coded)
		piece.set_meta("toughness",Art.CACHE_TOUGH)
		if hidden.has(spot):
			piece.set_meta(META,str(hidden[spot]))
			piece.set_meta(NAME_META,key.get_file())
		me.pieces.add_child(piece)
		Layout.track(key,piece,"piece",coded)
	me.breaks = KitBreaks.new()
	me.breaks.name = "KitBreaks"
	me.breaks.hub = hub
	var lost: Variant = cluster.get("lost")
	if lost != null: me.breaks.lost_y = float(lost)
	me.add_child(me.breaks)
	me.breaks.adopt(me.pieces)
	hub.others.append(me.breaks)
	me.watch(me.breaks)
	var n: int = me.adopt(me.pieces,me.breaks)
	print("wreck cluster: %d cache piece(s), %d hiding a part" % [me.breaks.targets.size(),n])
	return me

## The find for part `holds`: the arc's hidden holder for it.
func _part_find(holds: String, _cache_name: String) -> Node3D:
	var holder: Node3D = arc.hidden_holder(holds) if arc != null else null
	if holder == null:
		push_warning("wreck caches: no hidden %s to hand out" % holds)
		holder = Node3D.new()
	holder.set_meta("part_id",holds)
	return holder

## Settled out of the rubble: handed back to the arc, laid there, and taken
## as any laid part.
func _touch(f: Dictionary) -> void:
	if float(f.get("settle",0.0)) < SETTLE: return
	var holder: Node3D = f.find
	f.taken = true
	took += 1
	if arc != null and is_instance_valid(holder) and holder.has_meta("part_id"): arc.unhide(str(holder.get_meta("part_id")))
