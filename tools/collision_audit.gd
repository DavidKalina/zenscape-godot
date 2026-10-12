extends SceneTree
## The invisible-hitbox audit over the game (scripts/collision_audit.gd),
## headless: the aqueduct isle and every motif isle in its sky built
## (--motifs-now), then every collision shape the plane or the walker can
## hit that stands more than 0.3 m off anything drawn is listed, worst
## first, with a count by isle.
##   Godot --headless --path . -s res://tools/collision_audit.gd [-- --scene=res://studies/zenscape.tscn --most=40 <isle flags>]
const LaunchArgs = preload("res://scripts/launch_args.gd")
const CollisionAudit = preload("res://scripts/collision_audit.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")

func _initialize() -> void: run.call_deferred()

func run() -> void:
	var scene_path := "res://studies/zenscape.tscn"
	var most := 40
	var extra := PackedStringArray()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--scene="): scene_path = arg.get_slice("=",1)
		elif arg.begins_with("--most="): most = int(arg.get_slice("=",1))
		else: extra.append(arg)
	var found := await audit_scene(self,scene_path,extra)
	# Named: the stone circles (the aqueduct isle's henge, the broken ring's).
	for name: String in named:
		var hits := 0
		for f: Dictionary in found:
			if str(f.path).contains(name):
				hits += 1
				print("  ",name,": ",CollisionAudit.line(f))
		print("collision audit: %s: %d shapes checked, %d stand off the drawn stone; tallest hull %.2f m (SARSEN %.2f, TRILITHON %.2f)" % [name,int(named[name].shapes),hits,float(named[name].tallest),RuinKit.SARSEN.y,RuinKit.TRILITHON.y])
	var by_isle := {}
	var by_isle_far := {}
	for f: Dictionary in found:
		var parts := str(f.path).split("/")
		var key := "/".join(parts.slice(0,mini(3,parts.size()-1)))
		if key.begins_with("@"): key = "(scene's own boxes)"
		by_isle[key] = int(by_isle.get(key,0))+1
		if float(f.worst) >= 1.0: by_isle_far[key] = int(by_isle_far.get(key,0))+1
	var floaters: Array = []
	for f: Dictionary in RuinKit.Build.floaters:
		var root_node: Node3D = (f.root as WeakRef).get_ref()
		if root_node == null or not root_node.is_inside_tree(): continue
		var where := "isle"
		for part in str(root_node.get_path()).split("/"):
			if part.begins_with("Motif_") or part in ["IsleChain","Sky","TargetShard"]: where = part
		floaters.append([where+" "+str(f.label),root_node.global_transform*(f.box as AABB)])
	var by_label := {}
	for f: Array in floaters: by_label[f[0]] = int(by_label.get(f[0],0))+1
	print("floating stones: %d" % floaters.size())
	for k: String in by_label: print("  %-50s %d" % [k,by_label[k]])
	for i in range(mini(most,floaters.size())): print("  float ",floaters[i][0]," ",(floaters[i][1] as AABB).position.snapped(Vector3.ONE*0.1)," size ",(floaters[i][1] as AABB).size.snapped(Vector3.ONE*0.1))
	var far := 0
	for f: Dictionary in found: if float(f.worst) >= 1.0: far += 1
	print("collision audit: %d shapes stand off the drawn stone, %d by a metre or more" % [found.size(),far])
	for k: String in by_isle: print("  %-30s %d (%d by a metre or more)" % [k,by_isle[k],int(by_isle_far.get(k,0))])
	for i in range(mini(most,found.size())): print("  ",CollisionAudit.line(found[i]))
	quit()

## Loads `scene_path` with `flags` (and --no-title --motifs-now), waits for
## it and its motif isles to stand, audits it, frees it. The found list.
## Named groups (path contains): their shapes counted and tallest hull, as
## `audit_scene` saw them.
static var named := {"StoneCircle":{"shapes":0,"tallest":0.0}}

static func audit_scene(tree: SceneTree, scene_path: String, flags := PackedStringArray()) -> Array:
	var args := PackedStringArray(["--no-title","--motifs-now","--no-flora","--no-life"])
	args.append_array(flags)
	LaunchArgs.set_override(args)
	RuinKit.Build.floaters.clear()
	RuinKit.Build.check_floating = true
	var scene: Node = load(scene_path).instantiate()
	tree.root.add_child(scene)
	var deadline := Time.get_ticks_msec()+240000
	while Time.get_ticks_msec() < deadline:
		await tree.process_frame
		if not bool(scene.get("walk_ready")): continue
		var motifs: Variant = scene.get("motifs")
		if motifs == null: break
		var all_up := true
		for isle: Node3D in motifs.isles:
			if not isle.is_up(): all_up = false
		if all_up: break
	for i in range(3): await tree.physics_frame
	var space: PhysicsDirectSpaceState3D = (scene as Node3D).get_world_3d().direct_space_state
	var audit := CollisionAudit.new(space)
	for key: String in ["plane_figure","figure","body","lodestone"]:
		var n: Variant = scene.get(key)
		if n is Node: audit.skip.append(n)
	var tris := audit.see(scene,scene)
	print("collision audit: %d drawn triangles seen" % tris)
	for k: String in audit.skipped: print("  left out: %s x%d" % [k,audit.skipped[k]])
	await tree.physics_frame
	await tree.physics_frame
	var began := Time.get_ticks_msec()
	var found := audit.audit(scene)
	for name: String in named:
		named[name] = {"shapes":0,"tallest":0.0}
		for node in scene.find_children("*","CollisionShape3D",true,false):
			if not str(scene.get_path_to(node)).contains(name): continue
			named[name].shapes += 1
			var shape := (node as CollisionShape3D).shape
			if shape is ConvexPolygonShape3D:
				var pts := (shape as ConvexPolygonShape3D).points
				var lo := INF
				var hi := -INF
				for q in pts:
					lo = minf(lo,q.y)
					hi = maxf(hi,q.y)
				named[name].tallest = maxf(float(named[name].tallest),hi-lo)
	print("collision audit: checked in %d ms" % (Time.get_ticks_msec()-began))
	audit.clear()
	RuinKit.Build.check_floating = false
	LaunchArgs.set_override(null)
	return found
