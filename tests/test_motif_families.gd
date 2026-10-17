extends SceneTree
## suite: slow
## The motif families (scripts/
## kit_isle/kit_motif.gd's family contract), headless: each family's
## default seed builds today's isle exactly (its built Art hashed,
## tests/motif_fingerprint.gd, against the hash taken before the families
## were cut); the same seed and knobs build the same isle twice; every
## knob's every value builds (a few configs cover them all) alongside a
## few plain seeds; and on each, every socket stands inside its footprint
## on solid ground: a rim with the drop past it and its run-up clear and
## walked, an arena's and a perch's room on level ground clear of stone,
## cover with stone over most of the sky above it. The rolled ring's hops
## are what they say: a jump a jump, the others and the break past one.
##   godot --headless --path . --script tests/test_motif_families.gd
const Fingerprint = preload("res://tests/motif_fingerprint.gd")
const KitMotif = preload("res://scripts/kit_isle/kit_motif.gd")
const Ring = preload("res://studies/broken_ring_isle_art.gd")

## Today's isles (default flags), hashed before the families were cut and
## re-recorded as the motifs changed since (at c6ae3a7c: the closed keel and seated bridge anchors, the arch fit).
const TODAY := {
	"colonnade_spine":"26064:426562cd48e9759e3245aa53b892481e",
	"broken_ring":"3318:e332088777ed2f871151d74984c68130",
}
const FAMILIES := {
	"colonnade_spine":preload("res://scripts/kit_isle/motif_colonnade_spine.gd"),
	"broken_ring":preload("res://scripts/kit_isle/motif_broken_ring.gd"),
}
## Plain seeds each family builds besides its knob sweeps.
const SEEDS := [3,1009]
## The land's own layer for the rays (studies/kit_isle.gd TURF_LAYER).
const LAND := 1 << 11
const ALL := 0xFFFFFFFF
## A socket's ground: found within this of its height.
const ON_GROUND := 0.35
## A rim's drop: past it, this far out, the ground is gone or this far under.
const DROP_OUT := 4.0
const DROP := 1.5
## Cover: the share of the sky over his chest (30 degrees up and over)
## stone must hide. The ring's turret hides about 0.9; the colonnade's
## best walked nook (the grand stair's head) about 0.7.
const COVER := 0.65
## Cover's way in: clear this far out along its face (out through a door).
const WAY_IN := 3.0
## The ring's hops, rim to rim (tests/test_broken_ring_isle.gd's): a jump
## under JUMP_MOST, the others and the break over PAST_JUMP.
const JUMP_MOST := 3.2
const PAST_JUMP := 4.0
const BREAK_MOST := 6.0

var failures := 0
var space: PhysicsDirectSpaceState3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(400.0).timeout.connect(func() -> void: push_error("motif families test timed out"); quit(2))
	space = root.get_world_3d().direct_space_state
	for id: String in FAMILIES:
		await _family(id,FAMILIES[id])
	print("PASS: motif families" if failures == 0 else "FAIL: motif families (%d)" % failures)
	quit(1 if failures else 0)

func _family(id: String, script: GDScript) -> void:
	var probe: KitMotif = script.new()
	check(probe.family() and probe.role() in KitMotif.ROLES,"%s: a family, its role %s" % [id,probe.role()])
	# The default: today's isle, unconfigured and configured alike.
	var plain: KitMotif = script.new()
	var built := await _build(plain)
	check(Fingerprint.of(built) == TODAY[id],"%s: unconfigured, it builds today's isle (%s)" % [id,Fingerprint.of(built)])
	built.free()
	var configs: Array = [[probe.default_seed(),{}]]
	# Every knob's every value: config k takes each knob's k-th (wrapped).
	var choices := probe.knob_choices()
	var most := 0
	for key: String in choices: most = maxi(most,(choices[key] as Array).size())
	for k in range(most):
		var over := {}
		for key: String in choices: over[key] = choices[key][k%(choices[key] as Array).size()]
		configs.append([probe.default_seed()+100+k,over])
	for s: int in SEEDS: configs.append([s,{}])
	for config: Array in configs:
		var motif: KitMotif = script.new()
		motif.configure(config[0],config[1])
		for key: String in motif.knobs:
			check(choices.has(key) and (choices[key] as Array).has(motif.knobs[key]),"%s seed %d: knob %s = %s is one of its choices" % [id,config[0],key,motif.knobs[key]])
		var art := await _build(motif)
		var name := "%s seed %d %s" % [id,motif.current_seed(),motif.knobs]
		if int(config[0]) == probe.default_seed():
			check(Fingerprint.of(art) == TODAY[id],"%s: the default seed configured builds today's isle" % name)
		check(motif.built_ms > 0 and art.get_child_count() > 0,"%s: built in %d ms" % [name,motif.built_ms])
		_sockets(name,motif)
		if id == "broken_ring": _hops(name,motif)
		# The same seed and knobs: the same isle.
		if config == configs[1]:
			var again: KitMotif = script.new()
			again.configure(config[0],config[1])
			var twin := await _build(again)
			check(Fingerprint.of(twin) == Fingerprint.of(art),"%s: built again, the same isle" % name)
			twin.free()
		art.free()
		await physics_frame

## Builds `motif` into a fresh Art in the tree, its lands on LAND, and
## waits for its bodies to stand in the physics space.
func _build(motif: KitMotif) -> Node3D:
	motif.warm()
	var art := Node3D.new()
	art.name = "Art"
	root.add_child(art)
	motif.build(art)
	for land: Array in motif.lands:
		for body: StaticBody3D in (KitLand.turf_bodies(land[0]) if land[2] else [(land[0] as Node3D).get_node("Body")]):
			body.collision_layer |= LAND
	await physics_frame
	await physics_frame
	return art

func _sockets(name: String, motif: KitMotif) -> void:
	var sockets: Array = motif.sockets()
	var box := motif.footprint()
	var kinds := {}
	for s: Dictionary in sockets:
		kinds[s.kind] = true
		var at: Vector3 = s.at
		var label := "%s: %s %s at %s" % [name,s.kind,s.name,at]
		check(s.kind in KitMotif.SOCKET_KINDS,"%s: a socket kind" % label)
		check(box.grow(0.01).has_point(Vector2(at.x,at.z)),"%s: inside its footprint %s" % [label,box])
		var span := motif.height_span()
		check(at.y >= span.x and at.y <= span.y+0.01,"%s: inside its height span %s" % [label,span])
		var under: Variant = _ground(at)
		check(under != null and absf(float(under)-at.y) < ON_GROUND,"%s: on solid ground (found %s)" % [label,under])
		match str(s.kind):
			"rim": _rim(label,s)
			"arena", "perch": _room(label,s)
			"cover":
				var hidden := _hidden(at+Vector3.UP*1.0)
				check(hidden >= COVER,"%s: stone hides %.0f%% of the sky over him" % [label,hidden*100.0])
				var door := at+(s.face as Vector3)*WAY_IN
				check(_clear(at,door) and _ground(door) != null,"%s: a way in, %.1f m out along its face clear and walked" % [label,WAY_IN])
	for kind: String in KitMotif.SOCKET_KINDS:
		check(kinds.has(kind),"%s: has a %s socket" % [name,kind])

## A rim: the drop past it (DROP_OUT m out, no ground within DROP m under
## it: a flank's lip falls gently its first metre or two), its run-up
## walked and clear.
func _rim(label: String, s: Dictionary) -> void:
	var at: Vector3 = s.at
	var face: Vector3 = s.face
	var g_out: Variant = _ground(at+face*DROP_OUT)
	check(g_out == null or float(g_out) < at.y-DROP,"%s: the drop past it (%s m out: %s)" % [label,DROP_OUT,g_out])
	var run: float = s.run_up
	check(run >= KitMotif.pilot().run*0.25,"%s: a run-up of %.1f m" % [label,run])
	var walked := true
	var d := 0.5
	while d <= run:
		var g: Variant = _ground(at-face*d)
		if g == null or absf(float(g)-at.y) > 0.9: walked = false
		d += 0.5
	var clear := _clear(at,at-face*run)
	check(walked and clear,"%s: its run-up walked (%s) and clear of stone (%s)" % [label,walked,clear])

## An arena or a perch: its room round it level ground, clear of stone.
func _room(label: String, s: Dictionary) -> void:
	var at: Vector3 = s.at
	var room: float = s.room
	check(room >= KitMotif.pilot().run*0.25,"%s: %.1f m of room" % [label,room])
	var level := true
	var clear := true
	for k in range(8):
		var edge := at+Vector3.FORWARD.rotated(Vector3.UP,k*TAU/8.0)*room*0.95
		var g: Variant = _ground(edge)
		if g == null or absf(float(g)-at.y) > 0.6: level = false
		if not _clear(at,edge): clear = false
	check(level and clear,"%s: its room level (%s) and clear of stone (%s)" % [label,level,clear])

## The ground under `p` (y), looked for from a step over it to well under.
func _ground(p: Vector3) -> Variant:
	var q := PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.6,p+Vector3.DOWN*6.0,ALL)
	var hit := space.intersect_ray(q)
	return null if hit.is_empty() else (hit.position as Vector3).y

## Whether the way from `a` to `b` is clear at his knee and chest.
func _clear(a: Vector3, b: Vector3) -> bool:
	for up: float in [0.7,1.3]:
		var q := PhysicsRayQueryParameters3D.create(a+Vector3.UP*up,b+Vector3.UP*up,ALL)
		if not space.intersect_ray(q).is_empty(): return false
	return true

## The share of the sky over `p` stone hides: rays up to 30 degrees off
## the horizon, round and up to the zenith.
func _hidden(p: Vector3) -> float:
	var hit := 0
	var total := 0
	for lift: float in [30.0,50.0,70.0,90.0]:
		var count := 1 if lift >= 90.0 else 12
		for k in range(count):
			var way := Vector3.FORWARD.rotated(Vector3.RIGHT,deg_to_rad(lift)).rotated(Vector3.UP,k*TAU/count)
			var q := PhysicsRayQueryParameters3D.create(p,p+way*80.0,ALL)
			if not space.intersect_ray(q).is_empty(): hit += 1
			total += 1
	return float(hit)/total

## The ring's hops, rim to rim along the turf: a jump a jump, the rest
## past one, and the break uncrossable.
func _hops(name: String, motif: KitMotif) -> void:
	var p: Dictionary = motif.call("plan")
	for hop: Array in Ring.hops(p):
		var g := _rim_gap(Ring.sat(int(hop[0]),p),Ring.sat(int(hop[1]),p))
		if hop[2] == "jump": check(g > 1.0 and g < JUMP_MOST,"%s: hop %d-%d a jump, %.1f m" % [name,hop[0],hop[1],g])
		else: check(g > PAST_JUMP,"%s: hop %d-%d (%s) past a jump, %.1f m" % [name,hop[0],hop[1],hop[2],g])
	var n := Ring.count(p)
	var b := _rim_gap(Ring.sat(n-1,p),Ring.sat(0,p))
	check(b > BREAK_MOST,"%s: the break, %.1f m of sky" % [name,b])

func _rim_gap(a: Dictionary, b: Dictionary) -> float:
	var ca: Vector2 = a.c
	var cb: Vector2 = b.c
	var dir := (cb-ca).normalized()
	var total := ca.distance_to(cb)
	var ea := 0.0
	while ea < total and _turf(ca+dir*ea,float(a.top)): ea += 0.1
	var eb := total
	while eb > 0.0 and _turf(ca+dir*eb,float(b.top)): eb -= 0.1
	return eb-ea

func _turf(p: Vector2, y: float) -> bool:
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x,y+3.0,p.y),Vector3(p.x,y-3.0,p.y),LAND)
	var hit := space.intersect_ray(q)
	return not hit.is_empty() and absf((hit.position as Vector3).y-y) < 1.0
