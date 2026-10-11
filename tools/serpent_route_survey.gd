extends SceneTree
## Survey: height maps of the isles round the aqueduct isle (headless), for
## laying the serpent's route (scripts/kit_isle/serpent_route.gd). Prints one
## map per isle: a character a cell, its ground's height band.
##   godot --headless --path . --script tools/serpent_route_survey.gd -- [ids] [--step=<m>]
const LaunchArgs = preload("res://scripts/launch_args.gd")
const TURF := 1 << 11
const CHARS := "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	var want := PackedStringArray()
	var step := 3.0
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--step="): step = float(arg.get_slice("=",1))
		else: want.append(arg)
	LaunchArgs.set_override(["--no-life","--no-flora"] if want.has("route") else ["--no-life","--no-flora","--no-serpent"])
	var study: Node3D = load("res://studies/aqueduct_isle.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.isle_up: await process_frame
	study.sky.flush()
	for i in range(4): await physics_frame
	var places: Array = [["aqueduct",Vector3(85.0,30.0,-20.0),70.0]]
	places.append_array(study.sky.places())
	var space: PhysicsDirectSpaceState3D = study.get_world_3d().direct_space_state
	if want.has("route"):
		await _route(study,space)
		quit(0)
		return
	if want.has("gap"):
		_gap(study,space)
		quit(0)
		return
	for place: Array in places:
		if not want.is_empty() and not want.has(str(place[0])): continue
		var c: Vector3 = place[1]
		var r: float = float(place[2])+24.0
		var x0 := c.x-r
		print("== %s middle (%.0f, %.0f) reach %.0f; cell %.1f m from x %.0f; char = floor(y/3) (A = 30..33); # steep, . none" % [place[0],c.x,c.z,place[2],step,x0])
		var head := "      "
		var cols := int(2.0*r/step)
		for i in range(cols):
			head += str(posmod(int(x0+i*step),100)/10) if i%4 == 0 else " "
		print(head)
		var z := c.z-r
		while z <= c.z+r:
			var line := "%5d " % int(z)
			var x := x0
			while x <= c.x+r-0.01:
				var ray := PhysicsRayQueryParameters3D.create(Vector3(x,220.0,z),Vector3(x,-150.0,z),1|TURF)
				var hit := space.intersect_ray(ray)
				if hit.is_empty(): line += "."
				elif (hit.normal as Vector3).y < 0.7: line += "#"
				else:
					var h: float = (hit.position as Vector3).y
					line += CHARS[clampi(int(floor(h/3.0)),0,CHARS.length()-1)] if h >= 0.0 else "-"
				x += step
			print(line)
			z += step
	quit(0)

## The Sundered gorge's gap in section: for each row (z), what stands under
## y 70 (its top) and over y 12 (its underside), 1.5 m a cell; and the rope
## bridge's ends.
func _gap(study: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	for isle: Node3D in study.sky.motifs.isles:
		if str(isle.motif.id()) != "sundered_gorge": continue
		var ends: PackedVector3Array = preload("res://studies/sundered_gorge_isle_art.gd").rope_ends()
		print("rope bridge ends (world): %s, %s" % [ends[0]+isle.offset,ends[1]+isle.offset])
	for pass_i in range(2):
		print("== gap %s; x from -320 step 1.5" % ("tops under y 70" if pass_i == 0 else "undersides over y 12"))
		var z := 20.0
		while z <= 132.0:
			var line := "%5d " % int(z)
			var x := -320.0
			while x <= -274.0:
				var from := Vector3(x,70.0,z) if pass_i == 0 else Vector3(x,12.0,z)
				var to := Vector3(x,12.0,z) if pass_i == 0 else Vector3(x,70.0,z)
				var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,1|TURF))
				if hit.is_empty(): line += "."
				else: line += CHARS[clampi(int(floor((hit.position as Vector3).y/3.0)),0,CHARS.length()-1)]
				x += 1.5
			print(line)
			z += 3.0

## The route (scripts/kit_isle/serpent_route.gd): its ledges, its tube's
## clearance of the isles, a lap's time and its pace by each ledge, and its
## body against each ledge as it passes.
func _route(study: Node3D, space: PhysicsDirectSpaceState3D) -> void:
	var route: Node3D = study.sky.route
	var serpent: Node3D = route.serpent
	serpent.set_process(false)
	route.rider.manual = true
	route.build_all()
	for i in range(3): await physics_frame
	print("route %.0f m round; flank %.2f, crest %.2f, weave reach %.2f, heave %.2f" % [serpent.route_length,route.widest_flank(),route.ride_crest(),serpent.weave_reach(),serpent.heave_reach()])
	var ledges: Array[RID] = []
	for s: Dictionary in route.spots:
		var built: Node3D = s.built
		if built != null: ledges.append((built.get_node("Body") as CollisionObject3D).get_rid())
		print("spot %s on %s: mark %.0f m, pass %s, end %s, top %.2f, steps %s, foot %s, side %+d" % [s.id,s.isle,s.at,s.pass,s.end,s.top,s.get("steps","-"),s.get("foot","-"),int(s.side)])
	var q := PhysicsShapeQueryParameters3D.new()
	var ball := SphereShape3D.new()
	q.shape = ball
	q.collision_mask = 1|TURF
	q.exclude = [serpent.solid_rid(),route.rider.back.rid()]+ledges
	var at := 0.0
	var blocked := []
	while at < serpent.route_length:
		var p: Vector3 = serpent.route_point(at)
		var r: float = serpent.reach_at(at)
		ball.radius = r+0.5
		q.transform = Transform3D(Basis.IDENTITY,p)
		var hits := space.intersect_shape(q,4)
		if not hits.is_empty():
			var what := []
			for h: Dictionary in hits: what.append(str((h.collider as Node).get_parent().name if h.collider is Node else "?")+"/"+str((h.collider as Node).name if h.collider is Node else ""))
			var rest := space.get_rest_info(q)
			blocked.append("%.0f m at %s r %.1f: %s, touching at %s" % [at,p.snapped(Vector3.ONE*0.1),r,", ".join(what),str(rest.get("point","?"))])
		at += 2.0
	print("tube blocked at %d places" % blocked.size())
	for b: String in blocked: print("  "+b)
	# A lap, flown at 60 Hz: its time, its pace by each ledge, its body
	# (the rider's hulls) against each ledge, the crest's reach from each
	# ledge's end.
	route.rider._set_live(true)
	var went := 0.0
	var last: float = serpent.s
	var t := 0.0
	var pace := {}
	var touch := {}
	var reach := {}
	var lo_y := INF
	while went < serpent.route_length and t < 900.0:
		serpent.advance(1.0/60.0)
		route._process(1.0/60.0)
		t += 1.0/60.0
		went += fposmod(float(serpent.s)-last,float(serpent.route_length))
		last = serpent.s
		lo_y = minf(lo_y,(serpent.head() as Vector3).y)
		for s: Dictionary in route.spots:
			var d := absf(wrapf(float(serpent.s)-float(s.at),-serpent.route_length*0.5,serpent.route_length*0.5))
			if d < 1.0: pace[s.id] = serpent.speed()
			if d > 110.0 and wrapf(float(serpent.s)-float(s.at),-serpent.route_length*0.5,serpent.route_length*0.5) > 0.0: continue
			if wrapf(float(serpent.s)-float(s.at),-serpent.route_length*0.5,serpent.route_length*0.5) < -20.0: continue
			route.rider.back.update()
			await physics_frame
			if s.built != null:
				var body: CollisionObject3D = (s.built as Node3D).get_node("Body")
				for shape: CollisionShape3D in route.rider.back.body.get_children():
					var sq := PhysicsShapeQueryParameters3D.new()
					sq.shape = shape.shape
					sq.collision_mask = 1
					for h: Dictionary in space.intersect_shape(sq,8):
						if h.rid == body.get_rid(): touch[s.id] = true
			# The nearest spine top (its middle stretch) to the ledge's end.
			var end: Vector3 = s.end
			var best: Vector2 = reach.get(s.id,Vector2(INF,0.0))
			for a: float in [12.0,20.0,30.0,40.0,50.0,60.0,70.0]:
				var top: Vector3 = route.rider.back.place(route.rider.back.top(a))
				var flat := Vector2(top.x-end.x,top.z-end.z).length()
				if flat < best.x: best = Vector2(flat,end.y-top.y)
			reach[s.id] = best
	print("lap %.1f s (%.0f m, mean %.2f m/s), head lowest y %.1f" % [t,went,went/t,lo_y])
	for s: Dictionary in route.spots:
		var r: Vector2 = reach.get(s.id,Vector2(INF,0.0))
		print("spot %s: pace %.2f m/s; nearest back top %.2f m across, %.2f m under the ledge; body touches the ledge: %s" % [s.id,pace.get(s.id,-1.0),r.x,r.y,touch.get(s.id,false)])
