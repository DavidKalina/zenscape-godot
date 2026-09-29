extends SceneTree
## Headless probe of the wanderer (scripts/wanderer_eye.gd) on the cozy
## worlds scene:
##   - trees and rocks become obstacles in the plate plane;
##   - V over a tree sets the figure down outside it, not in its trunk;
##   - walking into a trunk for 2 s, square on and glancing, ends outside it
##     and slides round it rather than stopping dead;
##   - set down in deep live water, it steps out to a shallow spot;
##   - in its eyes the tree outline, the hover and the hand are off; they
##     come back on stepping out.
##   godot --headless --fixed-fps 60 --path . -s res://tools/probe_wanderer.gd -- --no-title
const TREES := ["tree","layered_tree","redwood","broadleaf","bigfoot_tree","snag","birch","willow","juniper"]

var scene: Node3D
var editor: NativeChunkEditor
var reach: Node
var eye: Node
var failures := []

func _initialize() -> void: run.call_deferred()

func check(label: String, ok: bool, detail: Variant = "") -> void:
	if not ok: failures.append(label)
	print(("OK   " if ok else "FAIL ")+label+("" if str(detail).is_empty() else "  "+str(detail)))

func frames(count: int) -> void:
	for i in range(count): await process_frame

func point(at: Vector2) -> void:
	editor.pointer_override = at
	reach.pointer_override = at

func key(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func screen(local: Vector3) -> Vector2:
	return scene.camera.unproject_position(editor.terrain.to_global(local))

func feet() -> Vector2:
	var at: Vector3 = eye._feet
	return Vector2(at.x,at.z)

## The obstacle circle round a plate point (x, z, radius), or null.
func obstacle_at(at: Vector2) -> Variant:
	var best: Variant = null
	for o: Vector3 in eye._obstacles:
		if Vector2(o.x,o.y).distance_to(at) < 0.05 and (best == null or o.z > best.z): best = o
	return best

## Faces the eye from where it stands towards `at`, `aside` radians off.
func face(at: Vector2, aside := 0.0) -> void:
	var to := at-feet()
	eye._yaw = atan2(-to.x,-to.y)+aside+eye._turn()

## Holds W for `seconds`; returns the closest the feet came to `centre`.
func walk(seconds: float, centre: Vector2) -> float:
	var closest := INF
	key(KEY_W,true)
	for i in range(int(seconds*60.0)):
		await frames(1)
		closest = minf(closest,feet().distance_to(centre))
	key(KEY_W,false)
	await frames(20)
	return closest

func hover_on(at: Vector2) -> void:
	point(at)
	reach._hover_key = []
	await frames(6)

func run() -> void:
	create_timer(260).timeout.connect(func() -> void: push_error("wanderer probe timed out"); quit(2))
	root.size = Vector2i(1440,900)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.set_meta("movie_capture",true)
	scene.places_path = "/private/tmp/zs-wanderer-probe-%d/places.json" % Time.get_ticks_usec()
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready: await process_frame
	while scene.places.busy or scene._chunk_editor.forming: await process_frame
	await create_timer(1.0).timeout
	editor = scene._chunk_editor
	reach = scene.hand_reach
	eye = scene.wanderer
	scene.world_clock.running = false
	await frames(30)

	# The obstacles.
	eye._read_obstacles(true)
	var trees := []
	for item: Dictionary in editor.data.objects:
		if str(item.asset) in TREES: trees.append(item)
	var solid := 0
	for item: Dictionary in editor.data.objects:
		if str(item.asset) in eye.SOLID: solid += 1
	check("solid objects become obstacles",eye._obstacles.size() > 0 and solid > 0,"%d solid objects, %d obstacle circles" % [solid,eye._obstacles.size()])
	# The tree nearest the middle of the view, with an obstacle round it.
	var tree: Variant = null
	var ring: Variant = null
	var middle := Vector2(root.size)*0.5
	for item: Dictionary in trees:
		var at: Vector3 = editor.data.object_position(item)
		var found: Variant = obstacle_at(Vector2(at.x,at.z))
		if found == null or scene.camera.is_position_behind(editor.terrain.to_global(at)): continue
		if tree == null or screen(at).distance_to(middle) < screen(editor.data.object_position(tree)).distance_to(middle):
			tree = item
			ring = found
	check("a tree on the plate has an obstacle round it",tree != null,"%d trees" % trees.size())
	if tree == null:
		finish()
		return
	var base: Vector3 = editor.data.object_position(tree)
	var centre := Vector2(base.x,base.z)
	var radius: float = ring.z
	print("     tree %s #%d at %s, radius %.2f m (figure %.2f included)" % [tree.asset,tree.id,centre,radius,eye.RADIUS])
	check("its radius is a trunk or low-crown footprint, not the whole crown",radius > eye.RADIUS+0.05 and radius < 2.5,"%.2f m" % radius)

	# The hover outline before stepping in.
	var hand: Node3D = scene.get("god_hand")
	var over := screen(base+Vector3(0.0,1.2,0.0))
	await hover_on(over)
	var outlined_before: int = reach.outline.tree_id if reach.outline != null else -1
	print("     before: outline tree %d, hover zone '%s', hand opacity %.2f" % [outlined_before,reach.hover_zone,hand.opacity if hand != null else -1.0])

	# V over the tree: set down outside it.
	eye.summon(screen(base))
	await frames(2)
	check("V over the tree steps in",eye.active)
	var d := feet().distance_to(centre)
	check("set down on a tree, it is pushed out of the trunk",d >= radius-0.01,"%.2f m from the trunk (radius %.2f)" % [d,radius])
	# And place() right on the trunk's axis.
	eye.leave()
	await frames(50)
	eye.place(base)
	eye.enter()
	await frames(2)
	d = feet().distance_to(centre)
	check("placed on the trunk's axis, it is pushed out",d >= radius-0.01 and d < radius+0.5,"%.2f m" % d)

	# In its eyes: no outline, hover or hand.
	await hover_on(over)
	await frames(30)
	check("in its eyes the tree outline is off",reach.outline == null or reach.outline.tree_id <= 0,reach.outline.tree_id if reach.outline != null else "")
	check("in its eyes the hover is off",reach.hover_zone.is_empty() and reach.reaching.is_empty(),[reach.hover_zone,reach.reaching])
	check("in its eyes the hand is gone",hand == null or (not hand.visible and hand.opacity == 0.0),[hand.visible,hand.opacity] if hand != null else "")

	# Walk square into the trunk from 1.5 m for 2 s.
	var start := centre+(feet()-centre).normalized()*(radius+1.5)
	eye._feet = eye._clamped(Vector3(start.x,0.0,start.y))
	face(centre)
	var closest: float = await walk(2.0,centre)
	var end := feet()
	var aside := absf((end-centre).normalized().cross((start-centre).normalized()))
	check("walked square into the trunk 2 s, it ends outside",end.distance_to(centre) >= radius-0.02 and closest >= radius-0.02,"end %.2f m, closest %.2f m, radius %.2f" % [end.distance_to(centre),closest,radius])
	check("and slid round it rather than stopping dead",end.distance_to(start) > 1.6 and aside > 0.3,"moved %.2f m, swung %.0f deg round" % [end.distance_to(start),rad_to_deg(asin(clampf(aside,0.0,1.0)))])

	# Glancing: aimed 0.35 of the radius off the axis.
	start = centre+(end-centre).normalized()*(radius+1.5)
	eye._feet = eye._clamped(Vector3(start.x,0.0,start.y))
	face(centre,asin(0.35*radius/(radius+1.5)))
	closest = await walk(2.0,centre)
	end = feet()
	check("walked in glancing for 2 s, it ends outside, having slid past",closest >= radius-0.02 and end.distance_to(start) > 2.2,"closest %.2f m, moved %.2f m" % [closest,end.distance_to(start)])

	# Deep water, if the world has live water deep enough.
	eye._read_depths()
	var depths: PackedFloat32Array = eye._depths
	var deepest := -1
	for i in range(depths.size()):
		if deepest < 0 or depths[i] > depths[deepest]: deepest = i
	if deepest >= 0 and depths[deepest] > eye.WADE:
		var flow: RefCounted = editor.flow
		var cell := Vector2(deepest % int(flow.width),deepest/int(flow.width))
		var wet: Vector2 = flow.origin+(cell+Vector2(0.5,0.5))*float(flow.cell)
		eye.place(Vector3(wet.x,0.0,wet.y))
		check("set down in deep water (%.2f m), it steps out to the shallows" % depths[deepest],eye._depth(feet()) <= eye.WADE,"%.2f m deep, %.2f m away" % [eye._depth(feet()),feet().distance_to(wet)])
	else:
		print("     no live water deeper than %.2f m here (deepest %.2f): the real water is unchecked" % [eye.WADE,depths[deepest] if deepest >= 0 else 0.0])
	# The wall itself, on a made-up deep strip over the live water's grid:
	# every cell east of x = 1 stands 0.6 m deep.
	var grid: RefCounted = editor.flow
	if grid != null and grid.ready:
		var strip := PackedFloat32Array()
		strip.resize(int(grid.width)*int(grid.height))
		for j in range(int(grid.height)):
			for i in range(int(grid.width)):
				if float(grid.origin.x)+(i+0.5)*float(grid.cell) > 1.0: strip[j*int(grid.width)+i] = 0.6
		var saved: PackedVector3Array = eye._obstacles
		eye._obstacles = PackedVector3Array()
		eye._depths = strip
		var at := Vector3(0.0,0.0,-4.0)
		var wettest := 0.0
		for i in range(120):
			at = eye._walk(at,Vector2(0.03,0.03))
			wettest = maxf(wettest,eye._depth(Vector2(at.x,at.z)))
		check("walked slant into deep water, it never steps in and slides along the shore",wettest <= eye.WADE and at.z > -1.0,"deepest stood %.2f m, ended at %s" % [wettest,Vector2(at.x,at.z)])
		var out: Vector3 = eye._free_spot(Vector3(3.0,0.0,0.0))
		check("set down in deep water, it steps to the nearest shallows",eye._depth(Vector2(out.x,out.z)) <= eye.WADE and out.x < 1.0 and out.x > 0.0,Vector2(out.x,out.z))
		eye._obstacles = saved
		eye._read_depths()
	else:
		print("     no live water grid: the water wall is unchecked")
	# The radius each solid kind gets at scale 1, part by part (the widest).
	var content: GardenView = editor.content
	var kinds := []
	for kind: String in eye.SOLID+["tree_variants","layered_variants","rock_variants"]:
		var widest := 0.0
		for part: String in content._catalog_parts.get(kind,[]):
			var mesh: Mesh = content._meshes.get(part)
			if mesh == null: continue
			var saved: PackedVector3Array = eye._obstacles
			eye._obstacles = PackedVector3Array()
			var ground: float = eye._ground(Vector3.ZERO)
			eye._add_obstacle(mesh,Transform3D(Basis(),Vector3(0.0,ground,0.0))*content._catalog_poses.get(part,Transform3D.IDENTITY),{"x":0.0,"z":0.0})
			for o: Vector3 in eye._obstacles: widest = maxf(widest,o.z-eye.RADIUS)
			eye._obstacles = saved
		if widest > 0.0: kinds.append("%s %.2f" % [kind,widest])
	print("     footprint radius at scale 1 (without the figure's): "+", ".join(kinds))

	# The plate clamp holds.
	eye._feet = eye._clamped(Vector3(eye.PLATE_REACH-0.3,0.0,0.0))
	eye._yaw = atan2(-1.0,0.0)+eye._turn()
	await walk(1.5,Vector2.ZERO)
	check("the plate clamp holds",absf(feet().x) <= eye.PLATE_REACH+0.001 and absf(feet().y) <= eye.PLATE_REACH+0.001,feet())

	# Step out: the hover and outline come back.
	eye.leave()
	await frames(60)
	check("V steps out",not eye.active)
	await hover_on(over)
	await frames(30)
	var outlined_after: int = reach.outline.tree_id if reach.outline != null else -1
	print("     after: outline tree %d, hover zone '%s', hand opacity %.2f" % [outlined_after,reach.hover_zone,hand.opacity if hand != null else -1.0])
	check("stepped out, the hover reads again",reach.hover_zone == "land" or not reach.hover_zone.is_empty() or outlined_before <= 0,reach.hover_zone)
	check("stepped out, the tree outline comes back as it was",outlined_after == outlined_before,[outlined_before,outlined_after])
	finish()

func finish() -> void:
	print("wanderer probe: %s" % ("PASS" if failures.is_empty() else "FAIL %s" % str(failures)))
	quit(0 if failures.is_empty() else 1)
