extends SceneTree
## What the kit drops (docs/design/consolidation-audit.md, round 5), headless,
## on the aqueduct isle: no sky folk (none stands anywhere, even with every
## motif isle stood, docs/scenic/motif-sky.md; the airships carry a crew
## only when crewed, off by default) and no peak ring (SkyWorld's ring off, no layout
## worked out, no ring ranges), then the flags handed back when the isle
## leaves, so the old game's sky is as it was.
##   godot --headless --path . --script tests/test_kit_drops.gd
const SkyWorld = preload("res://scripts/sky_world.gd")
const SkyHomes = preload("res://scripts/sky_homes.gd")
const IslanderFigure = preload("res://scripts/islander_figure.gd")
const Dresser = preload("res://scripts/cluster_dresser.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

## Every IslanderFigure under `node`, not counting those under an airship.
func _folk(node: Node, ships: Array, out: Array) -> void:
	if node in ships: return
	if node is IslanderFigure: out.append(node)
	for child in node.get_children(): _folk(child, ships, out)

func run() -> void:
	create_timer(200.0).timeout.connect(func() -> void: push_error("kit drops test timed out"); quit(2))
	var ring_before := SkyHomes.ring
	var painted_before := SkyHomes.painted_sky
	var study: Node3D = load("res://studies/aqueduct_isle.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.isle_up: await process_frame
	var sky: Node = study.sky
	check(sky.motifs != null, "The motif isles are in the sky")
	sky.flush()
	var ships: Array = []
	for a: Dictionary in sky.airships: ships.append(a.ship)
	var found: Array = []
	_folk(study, ships, found)
	check(sky.isles_ready(), "Every motif isle stands")
	check(found.is_empty(), "No sky folk stand anywhere but on airships (%d found)" % found.size())
	# Airships carry a crew only when crewed (SkyAirship.crewed, off by
	# default): none aboard any ship that isn't.
	var stray_crew := 0
	for ship in ships:
		var aboard: Array = []
		_folk_in(ship, aboard)
		if not bool(ship.crewed): stray_crew += aboard.size()
	check(stray_crew == 0, "No crew aboard an airship that isn't crewed (%d aboard)" % stray_crew)
	check(not SkyHomes.ring and not SkyWorld.ring_on(), "The peak ring is off for the kit")
	check(SkyWorld.sea_peaks() == 0.0 and SkyWorld.painted_ridges() == 0.0, "and the painted sky stays as it was")
	check(SkyWorld._layout.is_empty(), "No ring layout was worked out")
	check(SkyWorld.edge_air(Vector3(9000.0,0.0,0.0)).is_empty() and SkyWorld.haze_share(Vector2(9000.0,0.0)) == 0.0, "There is no edge wind or haze band")
	# A dresser with folk on still dresses them (the old game's way).
	var plan_dresser := Dresser.furnish.get_argument_count()
	check(plan_dresser == 5, "Dresser.furnish keeps folk as an option (default on)")
	study.queue_free()
	await process_frame
	await process_frame
	check(SkyHomes.ring == ring_before and SkyHomes.painted_sky == painted_before, "Leaving the isle hands the ring flags back")
	print("PASS: kit drops" if failures == 0 else "FAIL: kit drops (%d)" % failures)
	quit(1 if failures > 0 else 0)

func _folk_in(node: Node, out: Array) -> void:
	if node is IslanderFigure: out.append(node)
	for child in node.get_children(): _folk_in(child, out)
