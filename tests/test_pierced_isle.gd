extends SceneTree
## The pierced isle (scripts/pierced_isle.gd, scripts/pierced_mesh.gd,
## scripts/pierced_ruins.gd, scripts/sky_pierced.gd):
##   every plan of SEEDS seeds is well formed (no problems; the cavern, the
##     skylight, the arch and at least two windows; the dive and its window;
##     the ruins inside the lid's frame), and the same seed lays the same;
##   every hole's tube is air round its middle line and leaves the plane's
##     wingtips the room it promises (wide holes ROOM_WIDE, the tight one
##     ROOM_TIGHT), the gate standing on the tight window's floor;
##   the game's plane (scripts/sky_plane.gd) flown by an autopilot along
##     each route (the arch, the eye, the dive down the skylight through the
##     cavern and out, the thread through two windows; the grand line
##     through the hall's lane into the dive only reaching its end, bumps
##     allowed: its lane is 2.6 m high) over the lid's real
##     ground for FLY_SEEDS seeds, never touching the rock (the bump's own
##     probes, scripts/sky_pierced.gd `probes`), the ruins' bulk or the lid's
##     sides, and reaching each route's end;
##   the cost: the rock near and far, the lid and the ruins under BUDGET
##     triangles, and the whole made in under MAKE_SECONDS.
## Headless; the ruins' hulls (physics) are not flown here, only their
## planned bulk (PiercedIsle `blockers`).
const PiercedIsle = preload("res://scripts/pierced_isle.gd")
const PiercedMesh = preload("res://scripts/pierced_mesh.gd")
const PiercedRuins = preload("res://scripts/pierced_ruins.gd")
const SkyPierced = preload("res://scripts/sky_pierced.gd")
const SkyPlane = preload("res://scripts/sky_plane.gd")
const SkyIslet = preload("res://scripts/sky_islet.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const PlaneFigure = preload("res://scripts/plane_figure.gd")
const SEEDS := 20
const FLY_SEEDS := [1,2,3]
const BUDGET := {"rock_near":50000,"rock_far":8000,"lid":24000,"ruins":140000,"near":220000}
const MAKE_SECONDS := 8.0
## The autopilot: how far ahead along the route it aims (m), the step.
const LOOK_AHEAD := 12.0
const STEP := 1.0/60.0
var failures := 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		print("FAIL "+label)

func _run() -> void:
	preload("res://scripts/native_terrain_kernels.gd").get_kernel()
	for s in range(1,SEEDS+1): _plan(s)
	var a: RefCounted = PiercedIsle.make(7)
	var b: RefCounted = PiercedIsle.make(7)
	check(a.holes.size() == b.holes.size() and a.lid_seed() == b.lid_seed() and str(a.summary()) == str(b.summary()),"the same seed lays the same isle")
	for s: int in FLY_SEEDS: _fly(s)
	_cost()
	print("test_pierced_isle: %s" % ("PASS" if failures == 0 else "%d failures" % failures))
	quit(1 if failures > 0 else 0)

func _plan(s: int) -> void:
	var plan: RefCounted = PiercedIsle.make(s)
	var tag := "seed %d" % s
	check(plan.problems.is_empty(),"%s is well formed: %s" % [tag,str(plan.problems)])
	for name_: String in ["cavern","shaft","arch"]: check(not plan.hole(name_).is_empty(),"%s has its %s" % [tag,name_])
	var windows: Array = plan.holes.filter(func(h: Dictionary) -> bool: return h.kind == "window")
	check(windows.size() >= 2,"%s has two windows or more" % tag)
	check(not plan.route("dive").is_empty(),"%s has its dive" % tag)
	var bounds: AABB = plan.bounds()
	check(bounds.size.x > 140.0 and bounds.size.y > 100.0,"%s is a landmark: %.0f m across, %.0f m tall" % [tag,bounds.size.x,bounds.size.y])
	for h: Dictionary in plan.holes:
		check(plan.tube_problem(h).is_empty(),"%s %s: its tube is air (%s)" % [tag,h.name,plan.tube_problem(h)])
		var room := float(h.clear)-PlaneFigure.SPAN*0.5
		var need := PiercedIsle.ROOM_TIGHT if bool(h.get("tight",false)) else PiercedIsle.ROOM_WIDE
		check(room >= need,"%s %s leaves %.1f m past the wingtips (%.1f wanted)" % [tag,h.name,room,need])
	for r: Dictionary in plan.ruins:
		var at: Vector3 = (r.at as Transform3D).origin
		check(bounds.grow(10.0).has_point(at),"%s's %s stands on the isle" % [tag,r.kind])
		if r.kind == "gate":
			var w: Dictionary = plan.hole(r.window)
			check(not w.is_empty() and bool(w.get("tight",false)) and absf(at.y-float(w.floor)) < 0.01,"%s's gate stands on the tight window's floor" % tag)
	for route: Dictionary in plan.routes:
		check(plan.route_problem(route).is_empty(),"%s's %s route is clear" % [tag,route.name])

## Flies the plane along each route of seed `s`'s isle, over its real lid.
func _fly(s: int) -> void:
	var plan: RefCounted = PiercedIsle.make(s)
	var lid: RefCounted = SkyIslet.author(plan.lid_seed(),plan.recipe)
	plan.settle(lid)
	var ground := func(point: Vector3) -> Variant:
		var at := Vector2(point.x,point.z)
		if not lid.inside(at): return null
		return Vector2(lid.solid_top(at),lid.underside(at))
	for route: Dictionary in plan.routes:
		var flown := _follow(plan,route,ground)
		var tag := "seed %d %s" % [s,route.name]
		check(flown.reached,"%s: the autopilot reaches the route's end (got %.0f of %.0f m)" % [tag,flown.along,flown.length])
		# The grand line threads the hall's low lane (2.6 m of height) from
		# outside: a tight line, flown here to its end, bumps allowed.
		if route.name != "grand": check(flown.touches == 0,"%s: flown without touching rock or ruin (%d frames, last %s; nearest rock %.2f m)" % [tag,flown.touches,flown.what,flown.nearest])
		check(flown.brushes == 0,"%s: never brushes the lid (%d frames)" % [tag,flown.brushes])
		print("seed %d %s: %.0f m in %.1f s, nearest rock %.2f m" % [s,route.name,flown.length,flown.time,flown.nearest])

## The autopilot along `route`: the plane aims LOOK_AHEAD m on along the
## line from the nearest point of it, turning and pitching toward it.
func _follow(plan: RefCounted, route: Dictionary, ground: Callable) -> Dictionary:
	var points: PackedVector3Array = route.points
	var lengths := PackedFloat32Array([0.0])
	for i in range(1,points.size()): lengths.append(lengths[i-1]+points[i].distance_to(points[i-1]))
	var total := lengths[lengths.size()-1]
	var plane := SkyPlane.new()
	plane.floor_y = -1000.0
	var way := (points[1]-points[0]).normalized()
	plane.launch(points[0],atan2(-way.x,-way.z),SkyPlane.CRUISE_SPEED,false)
	plane.pitch = asin(clampf(way.y,-1.0,1.0))
	var t := 0.0
	var along := 0.0
	var touches := 0
	var brushes := 0
	var nearest := INF
	var where := Vector3.ZERO
	var what := ""
	while t < total/SkyPlane.SLOW+10.0:
		along = maxf(along,_nearest_along(points,lengths,plane.position,along))
		if along >= total-4.0: break
		var target := _point_at(points,lengths,minf(along+LOOK_AHEAD,total))
		var d := (target-plane.position).normalized()
		var input := {"turn":0.0,"pitch":0.0}
		if Vector2(d.x,d.z).length() > 0.15:
			var err := wrapf(atan2(-d.x,-d.z)-float(plane.heading),-PI,PI)
			input.turn = clampf(-err*2.5,-1.0,1.0)
		input.pitch = clampf((asin(clampf(d.y,-1.0,1.0))-float(plane.pitch))*3.0,-1.0,1.0)
		plane.step(STEP,input,ground)
		if plane.brushing: brushes += 1
		var touched := false
		for p: Vector3 in SkyPierced.probes(plane):
			var f: float = plan.field(p)
			if f < nearest:
				nearest = f
				where = p
			if f < SkyPierced.MARGIN:
				touched = true
				what = "rock at %s" % p
			for box: Dictionary in plan.blockers:
				var q: Vector3 = (box.xform as Transform3D).affine_inverse()*p
				var half: Vector3 = box.half
				if absf(q.x) < half.x and absf(q.y) < half.y and absf(q.z) < half.z:
					touched = true
					what = "%s at %s" % [plan.ruins[int(box.ruin)].kind,p]
		if touched: touches += 1
		t += STEP
	return {"reached":along >= total-4.0,"along":along,"length":total,"time":t,"touches":touches,"brushes":brushes,"nearest":nearest,"where":where,"what":what}

## How far along the line its nearest point to `p` lies, looking from
## `from` m on (never back).
static func _nearest_along(points: PackedVector3Array, lengths: PackedFloat32Array, p: Vector3, from: float) -> float:
	var best := INF
	var best_along := from
	for i in range(points.size()-1):
		if lengths[i+1] < from-1.0: continue
		var a := points[i]
		var ab := points[i+1]-a
		var k := clampf((p-a).dot(ab)/maxf(ab.length_squared(),0.0001),0.0,1.0)
		var d := p.distance_to(a+ab*k)
		var at := lengths[i]+ab.length()*k
		if d < best and at >= from-1.0 and at <= from+30.0:
			best = d
			best_along = at
	return best_along

static func _point_at(points: PackedVector3Array, lengths: PackedFloat32Array, at: float) -> Vector3:
	for i in range(points.size()-1):
		if at <= lengths[i+1]:
			var k := (at-lengths[i])/maxf(lengths[i+1]-lengths[i],0.0001)
			return points[i].lerp(points[i+1],k)
	return points[points.size()-1]

## What it costs: triangles near and far, and the time it is made in.
func _cost() -> void:
	SkyIslets.catalog(null)
	SkyIslets._prepare()
	PiercedRuins.prepare()
	for s: int in [1,3]:
		var out := {}
		SkyPierced.make(s,SkyIslet.plain_palette(),50.0,out)
		var lid := (out.lid.top[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()/3+(out.lid.sides[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()/3
		var ruins := PiercedRuins.triangles(out.ruins)
		var near := int(out.stats.near.faces)+lid+ruins
		var tag := "seed %d" % s
		check(int(out.stats.near.faces) <= BUDGET.rock_near,"%s rock near %d triangles (%d)" % [tag,out.stats.near.faces,BUDGET.rock_near])
		check(int(out.stats.far.faces) <= BUDGET.rock_far,"%s rock far %d triangles (%d)" % [tag,out.stats.far.faces,BUDGET.rock_far])
		check(lid <= BUDGET.lid,"%s lid %d triangles (%d)" % [tag,lid,BUDGET.lid])
		check(ruins <= BUDGET.ruins,"%s ruins %d triangles (%d)" % [tag,ruins,BUDGET.ruins])
		check(near <= BUDGET.near,"%s near in all %d triangles (%d)" % [tag,near,BUDGET.near])
		check(out.usec/1.0e6 < MAKE_SECONDS,"%s made in %.1f s (%.0f)" % [tag,out.usec/1.0e6,MAKE_SECONDS])
		print("%s: rock near %d, far %d, lid %d, ruins %d, near in all %d triangles; made in %.2f s" % [tag,out.stats.near.faces,out.stats.far.faces,lid,ruins,near,out.usec/1.0e6])
		if out.ruins != null: (out.ruins as Node).free()
	PiercedMesh.release()
