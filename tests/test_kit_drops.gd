extends SceneTree
## What the kit drops (docs/design/consolidation-audit.md, round 5), headless,
## on the aqueduct isle: no sky folk (the clusters' lantern bearers and
## fishers stand nowhere, even with every cluster stood; the airships' crews
## are left as they were) and no peak ring (SkyWorld's ring off, no layout
## worked out, no ring ranges), then the flags handed back when the isle
## leaves, so the old game's sky is as it was.
##   godot --headless --path . --script tests/test_kit_drops.gd
const SkyWorld = preload("res://scripts/sky_world.gd")
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
	var ring_before := SkyWorld.ring
	var painted_before := SkyWorld.painted_sky
	var study: Node3D = load("res://studies/aqueduct_isle.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.isle_up: await process_frame
	var sky: Node = study.sky
	check(sky.clusters != null and not sky.clusters.folk, "The kit's clusters are told to leave the folk out")
	sky.clusters.flush()
	var ships: Array = []
	for a: Dictionary in sky.airships: ships.append(a.ship)
	var found: Array = []
	_folk(study, ships, found)
	check(sky.clusters.clusters.size() > 0, "Clusters stand (%d)" % sky.clusters.clusters.size())
	check(found.is_empty(), "No sky folk stand anywhere but on airships (%d found)" % found.size())
	var crews := 0
	var crewed: Array = []
	for ship in ships: _folk_in(ship, crewed)
	crews = crewed.size()
	check(ships.is_empty() or crews > 0, "The airships' crews are left as they were (%d aboard)" % crews)
	check(not SkyWorld.ring and not SkyWorld.ring_on(), "The peak ring is off for the kit")
	check(SkyWorld.sea_peaks() == 0.0 and SkyWorld.painted_ridges() == 0.0, "and the painted sky stays as it was")
	check(SkyWorld._layout.is_empty(), "No ring layout was worked out")
	check(SkyWorld.edge_air(Vector3(9000.0,0.0,0.0)).is_empty() and SkyWorld.haze_share(Vector2(9000.0,0.0)) == 0.0, "There is no edge wind or haze band")
	# A dresser with folk on still dresses them (the old game's way).
	var plan_dresser := Dresser.furnish.get_argument_count()
	check(plan_dresser == 5, "Dresser.furnish keeps folk as an option (default on)")
	study.queue_free()
	await process_frame
	await process_frame
	check(SkyWorld.ring == ring_before and SkyWorld.painted_sky == painted_before, "Leaving the isle hands the ring flags back")
	print("PASS: kit drops" if failures == 0 else "FAIL: kit drops (%d)" % failures)
	quit(1 if failures > 0 else 0)

func _folk_in(node: Node, out: Array) -> void:
	if node is IslanderFigure: out.append(node)
	for child in node.get_children(): _folk_in(child, out)
