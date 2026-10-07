extends SceneTree
## Headless validator of the sky clusters' motifs (scripts/cluster_motifs.gd,
## scripts/cluster_solver.gd): lays out many seeds of each motif and checks
## every plan (ClusterSolver `validate`): members overlapping, stepping
## stones out of a jump's reach, bridges too long or steep or off the land,
## records off the rim, anything built off the land, in water or floating.
## Prints each problem kind's count and a few examples, the members and
## features laid, and the time a plan takes. Exits 1 on any problem.
##   godot --headless --path . --script tools/probe_clusters.gd -- [--seeds=200] [--motif=farmstead] [--verbose]
const Solver = preload("res://scripts/cluster_solver.gd")
const Motifs = preload("res://scripts/cluster_motifs.gd")

func _initialize() -> void:
	var seeds := 200
	var only := ""
	var verbose := false
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="): seeds = int(a.trim_prefix("--seeds="))
		elif a.begins_with("--motif="): only = a.trim_prefix("--motif=")
		elif a == "--verbose": verbose = true
	var bad := 0
	var names: Array = Motifs.names()+["showcase"]
	for motif: String in names:
		if only != "" and motif != only: continue
		var count := 1 if motif == "showcase" else seeds
		var kinds := {}
		var examples := {}
		var members := 0
		var features := {}
		var failed := 0
		var began := Time.get_ticks_usec()
		var slowest := 0
		for s in range(count):
			var t := Time.get_ticks_usec()
			var plan := Solver.solve(motif,1000+s*7919)
			var problems := Solver.validate(plan)
			slowest = maxi(slowest,Time.get_ticks_usec()-t)
			members += (plan.members as Array).size()
			features["bridge"] = int(features.get("bridge",0))+(plan.bridges as Array).size()
			features["stones run"] = int(features.get("stones run",0))+(plan.routes as Array).size()
			for m: Dictionary in plan.members:
				for f: Dictionary in m.features: features[f.type] = int(features.get(f.type,0))+1
			if not problems.is_empty():
				failed += 1
				for p: String in problems:
					var kind := p.get_slice(":",0).get_slice(" (",0)
					kinds[kind] = int(kinds.get(kind,0))+1
					if not examples.has(kind): examples[kind] = "seed %d: %s" % [1000+s*7919,p]
					if verbose: print("  seed %d: %s" % [1000+s*7919,p])
		bad += failed
		var ms := (Time.get_ticks_usec()-began)/1000.0/count
		print("== %s: %d seeds, %d with problems; %.1f members a plan; %.0f ms a plan (slowest %.0f ms)" % [motif,count,failed,float(members)/count,ms,slowest/1000.0])
		print("   features laid: %s" % str(features))
		for kind: String in kinds: print("   %4d  %s   e.g. %s" % [kinds[kind],kind,examples[kind]])
	print("CLUSTERS %s" % ("OK" if bad == 0 else "FAIL (%d plans)" % bad))
	quit(1 if bad > 0 else 0)
