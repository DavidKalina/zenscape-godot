extends SceneTree
## The sky dragon's grip on each motif isle at one size (docs/design/
## dragon-grip/round1.md): its grip forced on every isle, targetable or
## not, held 24 s of its own clock, sampled at rest (chin down) and in the
## blow. After a headless import:
##   Godot --headless --path . -s tools/measure_dragon_grip.gd -- --dragon-size=1.5
## Per isle, a `V` line sums it up: targetable (`_has_room`), the planned
## wrists on land (none on `_rim_line`'s fallback), the thumbs' claws on
## land every frame, the chin over open turf (the head over turf, not a
## ruin, and the chin's front within 3 m of it, median), the body's lift
## (most) and the deepest head or neck probe left in the isle.
const LaunchArgs = preload("res://scripts/launch_args.gd")

var scene: Node
var dragon: Node3D
var space: PhysicsDirectSpaceState3D

func _initialize() -> void: run.call_deferred()

func frames(n: int) -> void:
	for i in range(n): await process_frame

func run() -> void:
	var size := "0.85"
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--dragon-size="): size = a.get_slice("=",1)
	var args := PackedStringArray(["--no-title","--motifs-now","--no-flora","--no-life","--dragon","--dragon-delay=100000","--dragon-size="+size])
	LaunchArgs.set_override(args)
	scene = load("res://studies/aqueduct_isle.tscn").instantiate()
	scene.set("scripted",true)
	root.add_child(scene)
	current_scene = scene
	var deadline := Time.get_ticks_msec()+300000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if not bool(scene.get("walk_ready")): continue
		var motifs: Variant = scene.get("motifs")
		if motifs == null: break
		if bool(motifs.call("all_stood")): break
	for i in range(3): await physics_frame
	dragon = scene.get("dragon")
	space = (scene as Node3D).get_world_3d().direct_space_state
	var s := float(dragon.size)
	# The model's size.
	var aabb := AABB()
	var first := true
	for mi: MeshInstance3D in dragon.model.find_children("*","MeshInstance3D",true,false):
		var b: AABB = (dragon.model.global_transform.affine_inverse()*mi.global_transform)*mi.get_aabb()
		aabb = b if first else aabb.merge(b)
		first = false
	print("M size %.2f model aabb (unscaled) %s; drawn: length %.1f m, span %.1f m, tall %.1f m" % [s,str(aabb.size),aabb.size.z*s,aabb.size.x*s,aabb.size.y*s])
	var sk: Skeleton3D = dragon.skeleton
	var tip := Vector3(0,4.68,-36)
	print("M rest: jaw tip z %.1f, hips %s, chest %s, tail.0 %s (model units)" % [tip.z,str(sk.get_bone_global_rest(dragon._bone["hips"]).origin),str(sk.get_bone_global_rest(dragon._bone["chest"]).origin),str(sk.get_bone_global_rest(dragon._bone["tail.0"]).origin)])
	var thumbL: Vector3 = sk.get_bone_global_rest(int(dragon._thumb["L"][0][0]))*(dragon._thumb["L"][0][1] as Vector3)
	print("M rest thumb claw L (model units) %s" % str(thumbL))
	# Every target's record first, at rest.
	var targets: Array = dragon.targets
	for t: Dictionary in targets: dragon._record(t)
	for t: Dictionary in targets:
		var rec: Dictionary = dragon._record(t)
		if rec.is_empty():
			print("T %s: no record (does not stand)" % t.name)
			continue
		await measure(t,rec)
	LaunchArgs.set_override(null)
	quit(0)

## As sky_dragon.gd `_rim_line`, plus whether it fell back.
func rim_line(t: Dictionary, out: Vector3, by: Vector3, rim: Vector3, shape: RefCounted) -> Array:
	var last := Vector2.INF
	var r := 0.0
	var reach := float(shape.get("reach"))
	while r <= reach+1.0:
		var p := Vector2(by.x+out.x*r,by.z+out.z*r)
		if shape.on_land(p): last = p
		elif last != Vector2.INF and r > 2.0: break
		r += 0.5
	return [last == Vector2.INF]

## Signed distance from flat p (shape frame) to the main outline: < 0 inside.
func edge_dist(shape: RefCounted, p: Vector2) -> float:
	var o: PackedVector2Array = shape._outlines[shape._main]
	var best := INF
	for j in range(o.size()):
		var a := o[j]
		var b := o[(j+1)%o.size()]
		best = minf(best,Geometry2D.get_closest_point_to_segment(p,a,b).distance_to(p))
	return -best if Geometry2D.is_point_in_polygon(p,o) else best

func any_dist(shape: RefCounted, p: Vector2) -> float:
	var best := INF
	for o: PackedVector2Array in shape._outlines:
		if Geometry2D.is_point_in_polygon(p,o): return 0.0
		for j in range(o.size()):
			best = minf(best,Geometry2D.get_closest_point_to_segment(p,o[j],o[(j+1)%o.size()]).distance_to(p))
	return best

func ray(from: Vector3, to: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from,to,1|(1 << 11))
	q.hit_back_faces = true
	q.hit_from_inside = true
	q.exclude = [dragon.chin.get_rid()]
	return space.intersect_ray(q)

## A point against the isle as posed: inside its rock (depth) or clear
## (gap to the cliff toward the isle, gap down), and where it is over.
func probe(name: String, p: Vector3, land: Dictionary, out: Vector3) -> String:
	var shape: RefCounted = land.shape
	var l: Vector3 = (land.inv as Transform3D)*p
	var flat := Vector2(l.x,l.z)
	var ed := edge_dist(shape,flat)
	var turf: Variant = shape.turf_at(flat)
	var solid: Variant = shape.solid_at(flat)
	var over := "air"
	if shape.on_land(flat):
		over = "turf"
		if solid != null and turf != null and float(solid)-float(turf) > 0.5: over = "ruin/solid %.1fm tall" % (float(solid)-float(turf))
	var up_txt := ""
	if turf != null: up_txt = " %.2f m over turf" % (l.y-float(turf))
	elif solid != null: up_txt = " %.2f m over solid top" % (l.y-float(solid))
	# Inside test: a ray outward along +out (and up) hitting a back face.
	var inside := ""
	for d: Vector3 in [out,Vector3.UP,-out]:
		var h := ray(p,p+d*80.0)
		if not h.is_empty() and (h.normal as Vector3).dot(d) > 0.05:
			inside = " INSIDE rock/turf (%.2f m to exit along %s)" % [(h.position as Vector3).distance_to(p),"out" if d == out else ("up" if d == Vector3.UP else "in")]
			break
	var into := ray(p,p-out*80.0)
	var down := ray(p,p+Vector3.DOWN*80.0)
	var gi := (" cliff %.1f m in" % (into.position as Vector3).distance_to(p)) if not into.is_empty() else " no cliff in"
	var gd := (" ground %.1f m below" % (down.position as Vector3).distance_to(p)) if not down.is_empty() else " nothing below"
	return "%-14s edge %+6.1f m (%s)%s%s%s%s" % [name,ed,over,up_txt,inside,gi,gd]

func measure(t: Dictionary, rec: Dictionary) -> void:
	var shape: RefCounted = rec.shape
	var s := float(dragon.size)
	var g: Dictionary = dragon._plan_grip(t)
	dragon.grip = g
	var home: Vector3 = t.home
	var out: Vector3 = g.out
	var rim: Vector3 = g.rim
	var right := (-out).cross(Vector3.UP).normalized()
	print("\nT %s radius %.1f reach %.1f, rim %.1f m out (%s)" % [t.name,float(shape.radius),float(shape.reach),Vector2(rim.x-home.x,rim.z-home.z).length(),dragon._grip_note])
	var wl: Vector3 = g.wrists.get("L",Vector3.ZERO)
	var wr: Vector3 = g.wrists.get("R",Vector3.ZERO)
	print("T   planned wrists %d keys, span %.1f m (offset +-%.1f m); feet span %.1f m" % [g.wrists.size(),wl.distance_to(wr),8.5*s/0.85,(g.feet.get("L",Vector3.ZERO) as Vector3).distance_to(g.feet.get("R",Vector3.ZERO))])
	for k in [-1.0,1.0]:
		for kind: Array in [["wrist",8.5],["foot",2.8]]:
			var by: Vector3 = right*k*float(kind[1])*s/0.85
			var fb: bool = rim_line(t,out,by,rim,shape)[0]
			var n := "R" if k > 0 else "L"
			var p: Vector3 = (g.wrists if kind[0] == "wrist" else g.feet).get(n,Vector3.INF)
			var flat := Vector2(p.x-home.x,p.z-home.z)
			print("T   planned %s.%s fallback %s, on land %s, %.1f m off any land, %.1f m in from rim along out, dy %.1f" % [kind[0],n,str(fb),str(shape.on_land(flat)),any_dist(shape,flat),-(p-rim).dot(out),p.y-rim.y])
	print("T   root %.1f m out, %.1f m under rim" % [(g.root-rim).dot(out),rim.y-(g.root as Vector3).y])
	# Force the grip, and sample it every frame over HOLD s of its own clock.
	dragon._relax_clear(1.0)
	dragon._rest_lift = 0.0
	dragon._rest_nod = 0.0
	dragon._rest_app = Vector2.ZERO
	dragon._rest_app_v = Vector2.ZERO
	dragon.model.visible = true
	dragon._slam()
	dragon._cling_left = 1.0e6
	var stats := {}
	var t0 := Time.get_ticks_msec()
	while float(dragon._cling_t) < 24.0 and Time.get_ticks_msec()-t0 < 120000:
		await process_frame
		if float(dragon._cling_t) < 3.0: continue
		var phase := str(dragon.breath)
		if phase == "pant" and float(dragon._rest_w) > 0.95: phase = "rest"
		elif phase != "blow": continue
		sample(stats,phase)
	for phase: String in ["rest","blow"]:
		if not stats.has(phase): continue
		var st: Dictionary = stats[phase]
		var line := "T  {%s} %d frames:" % [phase,int(st.n)]
		for k: String in st.keys():
			if k == "n": continue
			var v: Array = st[k]
			if v[0] is String:
				var counts := {}
				for x in v: counts[x] = int(counts.get(x,0))+1
				line += " %s=%s" % [k,str(counts)]
			else:
				var a := v.duplicate()
				a.sort()
				line += " %s=[%.1f %.1f %.1f]" % [k,a[0],a[a.size()/2],a[-1]]
		print(line)
	verdict(t,g,stats)
	print("T   gale: tip %.1f deg, sag %.1f m, rim r %.1f, scale %.2f" % [rad_to_deg(dragon.gale.tip()),float(dragon.gale.sag),float(dragon.gale._rim_r),float(dragon.gale._scale)])
	dragon._place_chin(false)
	dragon.gale._settle_now()
	dragon.state = "waiting"
	dragon._t = 0.0
	dragon._rest_w = 0.0
	dragon.breath = ""
	await frames(5)

func push(st: Dictionary, k: String, v: Variant) -> void:
	if not st.has(k): st[k] = []
	(st[k] as Array).append(v)

func gap_over(shape: RefCounted, l: Vector3) -> float:
	var flat := Vector2(l.x,l.z)
	var turf: Variant = shape.turf_at(flat)
	if turf != null: return l.y-float(turf)
	var top: Variant = shape.top_at(flat)
	return l.y-float(top) if top != null else 999.0

func over(shape: RefCounted, l: Vector3) -> String:
	var flat := Vector2(l.x,l.z)
	if not shape.on_land(flat): return "air"
	var solid: Variant = shape.solid_at(flat)
	var turf: Variant = shape.turf_at(flat)
	if solid != null and turf != null and float(solid)-float(turf) > 1.0:
		return "in_ruin" if l.y < float(solid) else "over_ruin"
	return "turf"

func sample(stats: Dictionary, phase: String) -> void:
	if not stats.has(phase): stats[phase] = {"n":0}
	var st: Dictionary = stats[phase]
	st.n = int(st.n)+1
	var land: Dictionary = dragon._land_now()
	if land.is_empty(): return
	var shape: RefCounted = land.shape
	var inv: Transform3D = land.inv
	var g: Dictionary = dragon.grip
	var xf: Transform3D = dragon._isle_xf()
	var out: Vector3 = g.out
	var rl: Vector3 = inv*(xf*(g.rim as Vector3))
	push(st,"lift",float(dragon._body_up))
	var worst := INF
	var probes: Array = dragon._probes_head+dragon._probes_neck
	var nh: int = dragon._probes_head.size()
	for i in range(probes.size()): worst = minf(worst,dragon._floor_gap(dragon._probe(probes[i]),i < nh))
	push(st,"probe_min",worst if is_finite(worst) else 999.0)
	var cb: Vector3 = inv*dragon._probe(dragon._chin_back)
	var cf: Vector3 = inv*dragon._probe(dragon._chin_front)
	push(st,"chinB",gap_over(shape,cb))
	push(st,"chinF",gap_over(shape,cf))
	push(st,"chin_in",Vector2(rl.x-cf.x,rl.z-cf.z).dot(Vector2(out.x,out.z)))
	push(st,"chin_mid",Vector2(cf.x,cf.z).length())
	push(st,"head",over(shape,cf))
	for n in ["L","R"]:
		var c: Vector3 = inv*dragon._probe(dragon._thumb[n][0])
		push(st,"thumb"+n,gap_over(shape,c) if shape.on_land(Vector2(c.x,c.z)) else 100.0+edge_dist(shape,Vector2(c.x,c.z)))
		var sk: Skeleton3D = dragon.skeleton
		var f: Vector3 = inv*(sk.global_transform*sk.get_bone_global_pose(dragon._bone["hind_foot."+n]).origin)
		push(st,"foot"+n+"_edge",edge_dist(shape,Vector2(f.x,f.z)))

func report(label: String, t: Dictionary, rec: Dictionary) -> void:
	var land: Dictionary = dragon._land_now()
	var g: Dictionary = dragon.grip
	var xf: Transform3D = dragon._isle_xf()
	var out: Vector3 = g.out
	var sk: Skeleton3D = dragon.skeleton
	var bone := func(n: String) -> Vector3: return sk.global_transform*sk.get_bone_global_pose(dragon._bone[n]).origin
	print("T  [%s] tip %.1f deg, body lifted %.2f m, sunk before/after %.2f/%.2f, chin miss %s, rest_w %.2f" % [label,rad_to_deg(dragon.gale.tip()),float(dragon._body_up),float(dragon.sunk_before),float(dragon.sunk_after),str(dragon.chin_miss),float(dragon._rest_w)])
	for n in ["L","R"]:
		var claw: Vector3 = dragon._probe(dragon._thumb[n][0])
		var want: Vector3 = xf*(g.wrists[n] as Vector3)
		print("T    " + probe("thumb."+n,claw,land,out) + " | miss from hold %.1f m" % claw.distance_to(want))
		var foot: Vector3 = bone.call("hind_foot."+n)
		var fw: Vector3 = xf*(g.feet[n] as Vector3)-Vector3.UP*1.0*float(dragon.size)+out*0.4*float(dragon.size)
		print("T    " + probe("foot."+n,foot,land,out) + " | miss from reach %.1f m" % foot.distance_to(fw))
	print("T    thumb span now %.1f m" % (dragon._probe(dragon._thumb["L"][0]) as Vector3).distance_to(dragon._probe(dragon._thumb["R"][0])))
	for n: String in ["hips","spine.0","spine.1","spine.2","chest","neck.0","neck.1","neck.2","neck.3","head"]:
		if dragon._bone.has(n): print("T    " + probe(n,bone.call(n),land,out))
	# Body surface: the chest's and belly's underside, a few metres off the bones toward the cliff.
	for n: String in ["chest","spine.1","hips"]:
		if not dragon._bone.has(n): continue
		var p: Vector3 = bone.call(n)
		var belly: Vector3 = p-out*2.2*float(dragon.size)
		print("T    " + probe(n+"~belly",belly,land,out))
	# The head and neck probes' gaps as the dragon reads them (after the lift).
	var gaps: Array = []
	var probes: Array = dragon._probes_head+dragon._probes_neck
	var nh: int = dragon._probes_head.size()
	for i in range(probes.size()):
		var gp: float = dragon._floor_gap(dragon._probe(probes[i]),i < nh)
		gaps.append("%s%d:%s" % ["h" if i < nh else "n",i if i < nh else i-nh,("%.1f" % gp) if is_finite(gp) else "-"])
	print("T    probe gaps " + " ".join(gaps))
	# Wings and tail: any bone over land, its gap over the isle's top there; inside tests.
	var worst := INF
	var worst_n := ""
	var insides: Array = []
	for i in range(sk.get_bone_count()):
		var n := sk.get_bone_name(i)
		if not (n.begins_with("wing") or n.begins_with("tail") or n.begins_with("hind")): continue
		var p: Vector3 = sk.global_transform*sk.get_bone_global_pose(i).origin
		var l: Vector3 = (land.inv as Transform3D)*p
		var top: Variant = land.shape.top_at(Vector2(l.x,l.z))
		if top != null and land.shape.on_land(Vector2(l.x,l.z)) and l.y-float(top) < worst:
			worst = l.y-float(top)
			worst_n = n
		var txt := probe(n,p,land,out)
		if txt.contains("INSIDE"): insides.append(n)
	print("T    wings/tail/legs: lowest over land %s %.1f m; inside rock: %s" % [worst_n,worst,str(insides)])
	var cb: Vector3 = dragon._probe(dragon._chin_back)
	var cf: Vector3 = dragon._probe(dragon._chin_front)
	print("T    " + probe("chin.back",cb,land,out))
	print("T    " + probe("chin.front",cf,land,out))
	var l: Vector3 = (land.inv as Transform3D)*cf
	var rl: Vector3 = (land.inv as Transform3D)*(xf*(g.rim as Vector3))
	print("T    chin front %.1f m in from the rim (along -out), %.1f m from isle middle (radius %.1f), open_at %s" % [Vector2(rl.x-l.x,rl.z-l.z).dot(Vector2(out.x,out.z)),Vector2(l.x,l.z).length(),float(rec.radius),str(land.shape.open_at(Vector2(l.x,l.z),1.2))])
	var m: Vector3 = dragon.mouth_at()
	print("T    mouth at %s, %.1f m in from rim" % [str(m.snapped(Vector3.ONE*0.1)),-(m-xf*(g.rim as Vector3)).dot(out)])

## One line per isle: what the handoff's table reads.
func verdict(t: Dictionary, g: Dictionary, stats: Dictionary) -> void:
	var targetable := "-"
	if dragon.has_method("_has_room"): targetable = "yes" if dragon._has_room(t) else "NO"
	var shape: RefCounted = dragon._record(t).shape
	var home: Vector3 = t.home
	var planned := 0
	for n: String in ["L","R"]:
		var p: Vector3 = g.wrists.get(n,Vector3.INF)
		if p != Vector3.INF and shape.on_land(Vector2(p.x-home.x,p.z-home.z)): planned += 1
	var line := "V %-16s targetable %-3s planned wrists on land %d/2" % [str(t.name),targetable,planned]
	for phase: String in ["rest","blow"]:
		if not stats.has(phase): continue
		var st: Dictionary = stats[phase]
		var off := 0
		for n: String in ["L","R"]:
			for v: float in st.get("thumb"+n,[]): if v >= 100.0: off += 1
		var heads: Array = st.get("head",[])
		var on_turf := 0
		var in_ruin := 0
		for h: String in heads:
			if h == "turf": on_turf += 1
			elif h == "in_ruin": in_ruin += 1
		var cf: Array = (st.get("chinF",[999.0]) as Array).duplicate()
		cf.sort()
		var lift: Array = (st.get("lift",[0.0]) as Array).duplicate()
		lift.sort()
		var pm: Array = (st.get("probe_min",[0.0]) as Array).duplicate()
		pm.sort()
		var n_h := maxi(heads.size(),1)
		line += " | %s: thumbs off land %d fr, head over turf %d%%, chin front %.1f m up (median), lift max %.1f m, head in ruin %d%%, deepest probe %.1f m (5th pct %.1f)" % [phase,off,100*on_turf/n_h,float(cf[cf.size()/2]),float(lift[-1]),100*in_ruin/n_h,float(pm[0]),float(pm[pm.size()/20])]
	print(line)
