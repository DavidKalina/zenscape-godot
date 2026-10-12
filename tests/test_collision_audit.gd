extends SceneTree
## No invisible hitboxes (docs/design/plane-ground-scale.md, "Opening ratio
## 1.0 + collision audit"), headless: the game (studies/zenscape.tscn) with
## every motif isle in its sky built (--motifs-now), audited by scripts/
## collision_audit.gd (every collision shape the plane or the walker meets
## against the drawn meshes round it) and the floating-stone check (RuinKit
## Build `check_floating`):
## - on the aqueduct isle itself no shape stands more than 1 m off the
##   drawn stone at more than one point (its stations' boxes, castellum,
##   stumps, kit hulls and cliff prisms), the stone circle's none at all;
## - nowhere does a shape stand 3 m off anything drawn (the rune serpent's
##   capsules ride a body bent in its shader, out of the audit's sight);
## - all told, fewer than MOST_FAR shapes stand a metre off (340 after this
##   round's fixes, of 1504 off at all; 454 of 2059 before them, at ratio
##   0.95; most left are the stair to the clouds' cliff prisms and the
##   drowned nave's, docs/design/plane-ground-scale.md's open list);
## - no stone rests on nothing but the floating stones, the drowned nave's
##   causeway stones, the half bridge's parapet (its deck walks a clean
##   hull) and the colonnade's lintels lying in the grass;
## - the plane's bump body (kit_isle BUMP_BODY at the plane's scale, its
##   middle shifted as the figure is drawn about its wheels) lies inside
##   the drawn plane.
##   godot --headless --path . --script tests/test_collision_audit.gd
const Audit = preload("res://tools/collision_audit.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const PlaneFigure = preload("res://scripts/plane_figure.gd")
const GroundScale = preload("res://scripts/plane_ground_scale.gd")
const KitIsle = preload("res://studies/kit_isle.gd")

const MOST_FAR := 400
const EXEMPT := ["RuneSerpent"]
const MAY_FLOAT := ["FloatingStones","CausewayStones","HalfBridge","Colonnade"]

var failures := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(400).timeout.connect(func() -> void: print("FAIL: timed out"); quit(2))
	var found: Array = await Audit.audit_scene(self,"res://studies/zenscape.tscn")
	var isle_far: Array = []
	var circle_far: Array = []
	var three: Array = []
	var far := 0
	for f: Dictionary in found:
		var path := str(f.path)
		var exempt := false
		for e: String in EXEMPT: exempt = exempt or path.contains(e)
		if exempt: continue
		if float(f.worst) >= 1.0: far += 1
		if float(f.worst) >= 3.0: three.append(f)
		var on_isle := not path.begins_with("Sky/") and not path.begins_with("TargetShard")
		if on_isle and int(f.far) > 1: isle_far.append(f)
		if path.contains("StoneCircle") and float(f.worst) >= 1.0: circle_far.append(f)
	check(isle_far.is_empty(),"The aqueduct isle: no shape stands a metre off the drawn stone at more than a point (%d)%s" % [isle_far.size(),_first(isle_far)])
	check(circle_far.is_empty(),"The stone circles: no lintel, sarsen, stub or leaning stone hull a metre off the drawn stone (%d of %d shapes)%s" % [circle_far.size(),int(Audit.named.StoneCircle.shapes),_first(circle_far)])
	check(three.is_empty(),"Nowhere a shape 3 m off anything drawn (%d)%s" % [three.size(),_first(three)])
	check(far < MOST_FAR,"Under %d shapes stand a metre off the drawn stone (%d of %d off at all)" % [MOST_FAR,far,found.size()])
	var stray: Array = []
	var isle_stray: Array = []
	for f: Dictionary in RuinKit.Build.floaters:
		var root_node: Node3D = (f.root as WeakRef).get_ref()
		if root_node == null or not root_node.is_inside_tree(): continue
		var label := str(f.label)
		var path := str(root_node.get_path())
		if not label in MAY_FLOAT: stray.append(label+" at "+str((root_node.global_transform*(f.box as AABB)).position.snapped(Vector3.ONE*0.1)))
		elif not path.contains("Motif") and label != "FloatingStones": isle_stray.append(label)
	check(stray.is_empty() and isle_stray.is_empty(),"No stone rests on nothing but the floating stones and their like (%d, %s)" % [stray.size()+isle_stray.size(),str(stray.slice(0,4))])
	RuinKit.Build.floaters.clear()
	await _plane_body()
	print("PASS: collision audit" if failures == 0 else "FAIL: collision audit (%d)" % failures)
	quit(1 if failures else 0)

func _first(list: Array) -> String:
	if list.is_empty(): return ""
	return "; first: "+Audit.CollisionAudit.line(list[0])

## The bump body inside the drawn plane, flown (the figure at its own
## scale about its wheels).
func _plane_body() -> void:
	var fig := PlaneFigure.new()
	root.add_child(fig)
	await process_frame
	var gs := GroundScale.new()
	fig.transform = PlaneFigure.pose(Vector3.ZERO,0.0,0.0,0.0)
	gs.apply(fig,gs.plane_scale)
	var drawn := AABB()
	var first := true
	for n in fig.find_children("*","MeshInstance3D",true,false):
		var mi := n as MeshInstance3D
		if not mi.is_visible_in_tree() or mi.mesh == null: continue
		var a := mi.global_transform*mi.get_aabb()
		if a.size.length() > 50.0: continue
		drawn = a if first else drawn.merge(a)
		first = false
	var size := KitIsle.BUMP_BODY*gs.plane_scale
	var bump := AABB(gs.middle_shift()-size*0.5,size)
	check(drawn.grow(0.05).encloses(bump),"The plane's bump body %s lies inside the drawn plane %s" % [str(bump),str(drawn)])
	fig.free()
