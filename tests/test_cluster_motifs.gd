extends SceneTree
## The sky clusters' motifs (scripts/cluster_motifs.gd) laid out by the
## solver (scripts/cluster_solver.gd): a seed always lays the same plan;
## every motif's plans, over SEEDS seeds each, pass the validator (no
## members overlapping, every stepping stone a jump on and a jump up, every
## bridge within a footbridge's span and grade with both ends on the land,
## nothing off the rim, in water or floating); each motif lays what makes
## it itself; and the hand-laid showcase lays whole.
## tools/probe_clusters.gd runs the same over hundreds of seeds.
const Solver = preload("res://scripts/cluster_solver.gd")
const Motifs = preload("res://scripts/cluster_motifs.gd")
const SEEDS := 24
var failures := 0

func _initialize() -> void:
	var a := Solver.solve("reef",4242)
	var b := Solver.solve("reef",4242)
	check(_signature(a) == _signature(b),"A seed lays the same plan")
	check(_signature(a) != _signature(Solver.solve("reef",4243)),"Another seed another")
	var wants := {"farmstead":["cabin","field","dock"],"hamlet":["cabin","dock"],"reef":["cabin","lighthouse"]}
	wants["ravine"] = ["cabin","dock","post"]
	for motif: String in Motifs.names():
		var bad := []
		var missing := 0
		for s in range(SEEDS):
			var plan := Solver.solve(motif,500+s*104729)
			var problems := Solver.validate(plan)
			if not problems.is_empty(): bad.append("seed %d: %s" % [500+s*104729,problems[0]])
			var have := {}
			for m: Dictionary in plan.members:
				for f: Dictionary in m.features: have[f.type] = true
			for want: String in wants[motif]:
				if not have.has(want): missing += 1
		check(bad.is_empty(),"%s: %d seeds pass the validator%s" % [motif,SEEDS,"" if bad.is_empty() else " (%d fail, e.g. %s)" % [bad.size(),bad[0]]])
		check(missing == 0,"%s: every plan has its %s" % [motif,", ".join(wants[motif])])
	var show := Solver.solve("showcase",1)
	check(Solver.validate(show).is_empty() and (show.members as Array).size() == 9,"The showcase lays whole (%d members)" % (show.members as Array).size())
	print("PASS: cluster motifs" if failures == 0 else "FAIL: cluster motifs")
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func _signature(plan: Dictionary) -> String:
	var parts := []
	for m: Dictionary in plan.members: parts.append("%s %s %d %d" % [m.name,str((m.offset as Vector3).snapped(Vector3.ONE*0.01)),m.features.size(),(m.shape.objects as Array).size()])
	return "|".join(parts)
