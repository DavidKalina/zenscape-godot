extends "res://scripts/kit_isle/kit_motif.gd"
## The Broken Ring as a motif (scripts/kit_isle/kit_motif.gd; docs/scenic/
## broken-ring.md): a central isle with a standing stone circle (two stones
## missing) round a broken turret, and round it a loose spiral of eight small
## isles climbing 21 m, each with one small ruin note, tied by rope bridges
## and floating stones (studies/broken_ring_isle_art.gd). Built here for its
## study (studies/broken_ring_isle.gd) and for the aqueduct isle's sky alike.
##
## A family: `configure(seed,
## knobs)` rolls another ring (Ring `rolled`): how many isles (`isles`),
## how many of the hops are jumps (`jumps`), how steeply it climbs
## (`climb`, a share of the authored hops' rises), how many of the circle's
## stones are gone (`missing`). RING_SEED at its own knobs is the authored
## ring. A filler: a way up from its lowest isle (the "entry" rim) to its
## highest (the "exit").
const Ring = preload("res://studies/broken_ring_isle_art.gd")

const RING_SEED := 81
const CIRCLE_SEED := 82
const TURRET_SEED := 62
const BRIDGE_SEED := 130
const WEATHERED := 0.5
## What a socket keeps clear of besides the notes' own footprints (m round
## each): a bridge's anchor (its coursed plinth), a floating stone's end
## of its hop; and how far in from the rim a room keeps.
const ANCHOR_REACH := 1.2
const STONE_REACH := 1.3
const RIM_KEEP := 0.4
## A rim turns from the way it was asked TURN degrees at a time, at most
## TURN_MOST.
const TURN := 15.0
const TURN_MOST := 90.0

var central: Node3D
var circle: Node3D
var turret: Node3D
var isles: Array = []
var bridges: Array[MeshInstance3D] = []
var _plan: Dictionary = {}

func id() -> String:
	return "broken_ring"

func isle_name() -> String:
	return "broken ring"

## Placeholder name and line until the isle is named; its finds are the
## ledger's (scripts/ledger/ledger.gd `card`).
func isle_card() -> Dictionary:
	return Ledger.shared().card(id(),{"name":"The Broken Ring","epithet":"A circle, taken apart a stone at a time"})

func top() -> float:
	return Ring.W

## The air's summit: the highest isle.
func summit() -> Vector3:
	var p := plan()
	var s: Dictionary = Ring.sat(Ring.count(p)-1,p)
	return Vector3(s.c.x,Ring.summit_y(p),s.c.y)

func flora_site() -> KitFlora.Site:
	var p := plan()
	var site := KitFlora.Site.new(Ring.W,func(at: Vector2) -> float: return Ring.path_wear(at,p))
	site.ray = Vector2(Ring.summit_y(p)+60.0,Ring.W-8.0)
	return site

func flora_seed() -> int:
	return current_seed()+6

## The life reads the authored ring's layout: none on a rolled one yet.
func life_script() -> Script:
	return preload("res://studies/broken_ring_isle_life.gd") if authored_isle() else null

func plane_tokens() -> Array:
	return Ring.plane_tokens(plan())

func token_source() -> String:
	return "broken_ring"

## Its isles are small (6-13 m in radius): no run to land the plane on
## (tests/test_motif_sky.gd sets the pilot down on its turf instead).
func landing_run() -> bool:
	return false

func warm() -> void:
	super.warm()
	var p := plan()
	Ring.sats(p)
	Ring.platforms(p)
	Ring.path_wear(Vector2.ZERO,p)

func build(into: Node3D) -> void:
	super.build(into)
	var began := Time.get_ticks_msec()
	var p := plan()
	# Every seed moved by the ring's own from the authored (0 there).
	var shift := current_seed()-RING_SEED
	central = Ring.central(RING_SEED+shift,p)
	art.add_child(central)
	isles = Ring.satellites(RING_SEED+shift+Ring.SAT_SEED,p)
	for isle: Node3D in isles: art.add_child(isle)
	circle = RuinKit.stone_circle(CIRCLE_SEED+shift,WEATHERED,Ring.missing(p))
	circle.transform = Ring.circle_transform(p)
	art.add_child(circle)
	turret = RuinKit.turret(TURRET_SEED+shift,0.45)
	turret.transform = Ring.turret_transform(p)
	art.add_child(turret)
	for note: Array in Ring.notes(p):
		var piece: Node3D = RuinKit.piece(note[0],note[1],note[2])
		piece.transform = note[3]
		art.add_child(piece)
	art.add_child(Ring.floating_stones(RING_SEED+shift+4,p))
	_build_bridges(p,shift)
	for land: Node3D in [central]+isles: turf(land)
	built_ms = Time.get_ticks_msec()-began

## The rope bridges: the footbridge's live rope bridge (its sag, bounce,
## sway and shudder) between the stone anchors at each end (the bell spires'
## own: a sill out of a coursed plinth).
func _build_bridges(p: Dictionary, shift: int) -> void:
	var holder := Node3D.new()
	holder.name = "Bridges"
	art.add_child(holder)
	var k := 0
	for br: Dictionary in Ring.bridges(p):
		var a: Vector3 = br.a
		var b: Vector3 = br.b
		var seed_value := BRIDGE_SEED+shift+k
		var live: MeshInstance3D = Footbridge.live(Footbridge.build_mesh(a,b,seed_value),a,b,seed_value)
		live.name = "Bridge_"+str(br.name)
		holder.add_child(live)
		bridges.append(live)
		for end: Array in [[a,b],[b,a]]:
			var anchor := RuinKit.bridge_anchor(seed_value*3+int(end[0] == b),0.45,Footbridge.WIDTH,
				{"post_x":Footbridge.WIDTH*0.5+0.33,"post_z":0.0,"sill":Vector3(0.75,0.11,0.55),"sill_at":Vector3(0.0,-0.11,0.15),
				"plinth":Vector3(1.15,1.4,0.375),"plinth_z":0.2})
			var way: Vector3 = (end[1] as Vector3)-(end[0] as Vector3)
			way.y = 0.0
			anchor.transform = Transform3D(Basis.looking_at(way.normalized(),Vector3.UP),end[0])
			holder.add_child(anchor)
		k += 1

# --- The family ------------------------------------------------------------------

func family() -> bool:
	return true

func default_seed() -> int:
	return RING_SEED

## isles: how many satellites; jumps: how many hops are jumps; climb: the
## hops' rises as a share of the authored; missing: the circle's stones gone.
func knob_choices() -> Dictionary:
	return {"isles":[5,6,7,8],"jumps":[0,1,2],"climb":[0.7,0.85,1.0],"missing":[0,1,2,3]}

func roll(at_seed: int) -> Dictionary:
	if at_seed == RING_SEED: return {"isles":8,"jumps":2,"climb":1.0,"missing":2}
	var rng := RandomNumberGenerator.new()
	rng.seed = at_seed*104729+7
	var out := {}
	var choices := knob_choices()
	for key: String in ["isles","jumps","climb","missing"]:
		var values: Array = choices[key]
		out[key] = values[rng.randi_range(0,values.size()-1)]
	return out

## The authored ring: its seed at its own knobs.
func authored_isle() -> bool:
	return current_seed() == RING_SEED and knobs == roll(RING_SEED)

## The ring's plan (Ring `authored` or `rolled`), made once per configure.
func plan() -> Dictionary:
	if _plan.is_empty():
		if authored_isle(): _plan = Ring.authored()
		else: _plan = Ring.rolled(current_seed(),knobs,hop_reach(),float(pilot().jumps[0]))
	return _plan

func _plan_changed() -> void:
	_plan = {}

## Where the ring's own study starts him (the lowest isle, looking at the
## first hop): the editor's spawn on this base (motif_based `own_start`).
## Not `start`: the motif yard spawns a motif with `start` there.
func own_start() -> Vector3:
	return Ring.start(plan())

func role() -> String:
	return "filler"

func footprint() -> Rect2:
	var p := plan()
	var box := Rect2(Ring.C-Vector2.ONE*Ring.CENTRE_R*1.05,Vector2.ONE*Ring.CENTRE_R*2.1)
	for s: Dictionary in Ring.sats(p):
		box = box.merge(Rect2((s.c as Vector2)-Vector2.ONE*float(s.r)*1.05,Vector2.ONE*float(s.r)*2.1))
	return box

## The central isle's keel (its 24 m) to the summit isle's top.
func height_span() -> Vector2:
	var p := plan()
	return Vector2(Ring.centre_top(p)-24.0,Ring.summit_y(p))

func build_cost() -> int:
	return 1400

## Its rims: the way in on the lowest isle (back the way the spiral comes
## from) and the way out on the highest (on along it), each turned as
## little as it must be to stand clear of the isle's note with a run-up;
## its arena the clearest spot of the widest isles (not the ends nor the
## centre's); cover in the circle's turret (stone over and round him); a
## perch at the summit isle's clearest spot.
func sockets() -> Array:
	var p := plan()
	var n := Ring.count(p)
	var blocks := _blocks(p)
	var out: Array = []
	var first: Dictionary = Ring.sat(0,p)
	var last: Dictionary = Ring.sat(n-1,p)
	var into: Vector2 = ((Ring.sat(1,p).c as Vector2)-(first.c as Vector2)).normalized()
	var onward: Vector2 = ((last.c as Vector2)-(Ring.sat(n-2,p).c as Vector2)).normalized()
	out.append(_rim("entry",first,-into,blocks))
	out.append(_rim("exit",last,onward,blocks))
	var best: Array = []
	for s: Dictionary in Ring.sats(p):
		if int(s.i) in [0,n-1,Ring.centre_hop(p)]: continue
		var here := _clearest(s,blocks)
		if best.is_empty() or float(here[1]) > float(best[1]): best = here
	var mid: Vector2 = best[0]
	var to_c := (Ring.C-mid).normalized()
	out.append(socket("arena","arena",Vector3(mid.x,Ring.sat_ground(best[2],mid.x,mid.y),mid.y),Vector3(to_c.x,0.0,to_c.y),best[1]))
	# Cover: inside the turret, at the foot of its stair, under its steps.
	var t := Ring.turret_transform(p)
	var inside := t*Vector3(0.0,0.1,RuinKit.TURRET.x*0.35)
	inside.y = Ring.centre_ground(inside.x,inside.z,p)
	out.append(socket("cover","turret",inside,t.basis.z,RuinKit.TURRET.y*0.5))
	var perch: Array = _clearest(last,blocks)
	var pa: Vector2 = perch[0]
	out.append(socket("perch","summit",Vector3(pa.x,Ring.sat_ground(last,pa.x,pa.y),pa.y),Vector3(onward.x,0.0,onward.y),perch[1]))
	return out

## A rim on isle `s` facing about `way` (flat): at its rim, a step in, its
## run-up back across the isle clear of what stands on it, turned from
## `way` (TURN at a time, to TURN_MOST) the least that gives the run-up
## the pilot wants (the longest, if none does).
func _rim(name: String, s: Dictionary, way: Vector2, blocks: Array) -> Dictionary:
	var poly := _outline(s)
	var c: Vector2 = s.c
	var step := pilot().run*0.25
	var wanted := run_up_wanted()
	var best := {}
	var turn := 0.0
	while turn <= TURN_MOST:
		for side: float in ([1.0] if turn == 0.0 else [1.0,-1.0]):
			var dir := way.rotated(deg_to_rad(turn*side))
			var reach := reach_out(poly,c,dir)
			var at := c+dir*(reach-step)
			if room_at(at,blocks) < step*0.5: continue
			var run := clear_run(at,-dir,blocks,at.distance_to(c)+reach_out(poly,c,-dir)-step)
			if best.is_empty() or run > float(best.run_up):
				best = socket("rim",name,Vector3(at.x,Ring.sat_ground(s,at.x,at.y),at.y),Vector3(dir.x,0.0,dir.y),step,run)
		if not best.is_empty() and float(best.run_up) >= wanted: break
		turn += TURN
	return best

## The clearest spot on isle `s`: [where (x, z), its room (m) from what
## stands there and from the rim, the isle], on a half-metre grid.
func _clearest(s: Dictionary, blocks: Array) -> Array:
	var poly := _outline(s)
	var c: Vector2 = s.c
	var r: float = s.r
	var best: Array = [c,-1.0,s]
	var x := -r
	while x <= r:
		var z := -r
		while z <= r:
			var q := c+Vector2(x,z)
			if Geometry2D.is_point_in_polygon(q,poly):
				var room := minf(room_at(q,blocks),KitLand.edge_distance(q,poly)-RIM_KEEP)
				if room > float(best[1]): best = [q,room,s]
			z += 0.5
		x += 0.5
	return best

## Isle `s`'s outline, as `satellites` builds it.
func _outline(s: Dictionary) -> PackedVector2Array:
	return PackedVector2Array(Ring.sat_outline(s,current_seed()+Ring.SAT_SEED))

## What stands on the isles: the notes (their pieces' own footprints),
## the bridges' anchors, the stones off each rim.
func _blocks(p: Dictionary) -> Array:
	var out: Array = []
	for note: Array in Ring.notes(p): out.append(piece_block(note[0],note[1],note[2],note[3]))
	for br: Dictionary in Ring.bridges(p):
		for end: Vector3 in [br.a,br.b]: out.append([Vector2(end.x,end.z),ANCHOR_REACH])
	for stone: Dictionary in Ring.platforms(p):
		var at: Vector3 = stone.at
		out.append([Vector2(at.x,at.z),STONE_REACH])
	return out
