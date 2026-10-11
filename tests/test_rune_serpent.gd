extends SceneTree
## The rune serpent round the aqueduct isle (scripts/rune_serpent.gd, wired
## by studies/aqueduct_isle_sky.gd), headless: it stands in the sky by
## default, its body laid out behind its head; it flies its whole way round
## (every mark on it passed); every ring behind the neck lies where the head
## was when it had come that far, and slides along its own line, never
## sideways; nothing on it pops (no frame's acceleration of any ring or the
## snout past POP, while its smooth worst is about 25 m/s²); its body keeps
## clear of every isle's ground and rock (the aqueduct isle's and the motif
## isles', down the Sundered gorge too: docs/scenic/motif-sky.md) along the
## whole way, both as it flies and for anything it might do there (the
## route's tube at its farthest reach), and its way keeps clear of the
## airships' loops; it is solid to the plane (a ray finds it, the bump puts
## the plane back out); a plane flying alongside is noticed, watched (the
## head turned toward it), paced and then left; --no-serpent leaves it out.
## This is its old long way (--serpent-old-route); the route between the
## isles it flies by default is tests/test_serpent_route.gd's.
##   godot --headless --path . --script tests/test_rune_serpent.gd
const IsleSky = preload("res://studies/aqueduct_isle_sky.gd")
const RuneSerpent = preload("res://scripts/rune_serpent.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const DT := 1.0/60.0
## The most a ring or the snout may accelerate in one frame (m/s²): its
## weave, rolls and dives give it about 25 at worst, smoothly; a pop of a
## centimetre in one frame is 36.
const POP := 40.0
## The most a ring may stray from where the head was at its arc (m), and
## the most of a ring's velocity that may run across its own line.
const ON_PATH := 0.05
const SLIP := 0.04
## Clear of rock and ground by at least this (m), and of the lodestone's
## shard and ring (flat).
const MARGIN := 0.5
const QUEST_CLEAR := 60.0
var failures := 0
var study: Node3D
var sky: Node3D
var serpent: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(300.0).timeout.connect(func() -> void: push_error("rune serpent test timed out"); quit(2))
	LaunchArgs.set_override(["--serpent-old-route"])
	study = load("res://studies/aqueduct_isle.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.flora_ready: await process_frame
	sky = study.sky
	serpent = sky.serpent
	check(serpent != null and bool(sky.on.get("serpent",false)),"The serpent is in the sky by default")
	if serpent == null:
		_finish()
		return
	sky.flush()
	await physics_frame
	await physics_frame
	serpent.set_process(false)
	serpent.set_physics_process(false)
	_stands()
	_tube()
	_airships()
	_quest()
	await _loop()
	await _solid()
	_plane()
	await _flag()
	_finish()

func _finish() -> void:
	LaunchArgs.set_override(null)
	print("PASS: rune serpent" if failures == 0 else "FAIL: rune serpent (%d)" % failures)
	quit(1 if failures > 0 else 0)

func _stands() -> void:
	var rings: PackedVector3Array = serpent.rings()
	var arcs: PackedFloat32Array = serpent.stations()
	var length := 0.0
	for k in range(1,rings.size()): length += rings[k].distance_to(rings[k-1])
	check(rings.size() == RuneSerpent.STATIONS and length > RuneSerpent.LENGTH*0.85,"Its body is laid out behind its head (%d rings, %.0f m along them)" % [rings.size(),length])
	check(arcs[arcs.size()-1] >= RuneSerpent.LENGTH-0.01 and serpent.radii()[10] > 1.8,"It is giant: %.0f m long, %.1f m through" % [arcs[arcs.size()-1],serpent.radii()[10]*2.0])
	print("serpent: way round %.0f m, marks %s" % [serpent.route_length,str(serpent.marks().keys())])
	var body: MeshInstance3D = serpent.get_node("Serpent/Body")
	check(body != null and body.visible and body.mesh.get_surface_count() == 2,"Its body is drawn (stone and runes, and the eyes' haze)")

## The way's tube: round every point of the route, as far as the body could
## ever reach there (its girth, the most weave, the veer allowed, the
## heave), clear of every isle's ground and rock (physics: the aqueduct
## isle's and the motif isles').
func _tube() -> void:
	var space := study.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var ball := SphereShape3D.new()
	q.shape = ball
	q.collision_mask = 1|IsleSky.TURF_LAYER
	q.exclude = [serpent.solid_rid()]
	var blocked := []
	var at := 0.0
	while at < serpent.route_length:
		var p: Vector3 = serpent.route_point(at)
		var r: float = serpent.reach_at(at)
		ball.radius = r+MARGIN
		q.transform = Transform3D(Basis.IDENTITY,p)
		var hit := not space.intersect_shape(q,1).is_empty()
		if hit and (blocked.is_empty() or at-float(blocked[-1]) > 10.0): blocked.append(at)
		at += 2.0
	check(blocked.is_empty(),"Its way's tube (its girth, weave, veer and heave at their most) is clear of rock all round (blocked at %s m)" % str(blocked))
	# Down the Sundered gorge: its way runs the gorge's length between the
	# halves' rims (the motif's own frame x 86-88, z -61 to 4).
	var gorge: Variant = null
	var motifs: Variant = study.get("motifs")
	if motifs != null:
		for isle: Node3D in motifs.isles:
			if str(isle.motif.id()) == "sundered_gorge": gorge = isle
	var down := 0.0
	if gorge != null:
		var off: Vector3 = gorge.offset
		var t := 0.0
		while t < serpent.route_length:
			var p: Vector3 = serpent.route_point(t)-off
			if absf(p.x-87.0) < 4.0 and p.z > -61.0 and p.z < 4.0: down += 2.0
			t += 2.0
	check(down > 50.0,"Its way runs down the Sundered gorge (%.0f m of it between the halves)" % down)

## The airships' loops never come near its way: they could meet anywhere.
func _airships() -> void:
	var worst := INF
	for a: Dictionary in sky.airships:
		for i in range(300):
			var ap: Vector3 = IsleSky._loop(a.points,i/300.0)
			var t := 0.0
			while t < serpent.route_length:
				var d: float = ap.distance_to(serpent.route_point(t))-serpent.reach_at(t)
				worst = minf(worst,d)
				t += 3.0
	# A ship's farthest from its loop's point: the envelope's end, up where it rides.
	var ship: float = Vector2(IsleSky.AirshipBuild.ENVELOPE_LENGTH*0.5,IsleSky.AirshipBuild.ENVELOPE_AT.y+IsleSky.AirshipBuild.ENVELOPE_RADIUS).length()+2.0
	check(worst > ship,"Its way keeps clear of the airships' loops (%.1f m past its reach, a ship's %.1f)" % [worst,ship])

## The lodestone's end of the loop (studies/aqueduct_isle.gd `lode_target`,
## studies/aqueduct_isle_chain.gd `ring_at`): its way keeps QUEST_CLEAR m
## (flat) off the shard and the ring, which rise and stand in the plane's
## way there.
func _quest() -> void:
	var spots := {"shard":study.lode_target}
	var chain: Variant = study.get("isle_chain")
	if chain != null: spots["ring"] = chain.ring_at
	var least := {}
	for key: String in spots:
		var spot: Vector3 = spots[key]
		var d := INF
		var t := 0.0
		while t < serpent.route_length:
			var p: Vector3 = serpent.route_point(t)
			d = minf(d,Vector2(p.x-spot.x,p.z-spot.z).length())
			t += 2.0
		least[key] = snappedf(d,0.1)
	check(least.values().all(func(d: float) -> bool: return d > QUEST_CLEAR),"Its way keeps well off the lodestone's shard and the hall chain's ring (%s m)" % str(least))

## Its whole way round: flown frame by frame with the pilot far off on the
## isle. Every ring behind the neck against where the head was; slip; pops;
## the body against the isles every few frames.
func _loop() -> void:
	var space := study.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var ball := SphereShape3D.new()
	q.shape = ball
	q.collision_mask = 1|IsleSky.TURF_LAYER
	q.exclude = [serpent.solid_rid()]
	var arcs: PackedFloat32Array = serpent.stations()
	var neck := 0
	while arcs[neck] < RuneSerpent.NECK+0.5: neck += 1
	var tail := int(RuneSerpent.STATIONS*0.85)
	# Where the head was each frame, by how far it had come.
	var been_d := PackedFloat32Array()
	var been_p := PackedVector3Array()
	var prev := PackedVector3Array()
	var prev2 := PackedVector3Array()
	var worst_pop := 0.0
	var pop_at := ""
	var worst_off := 0.0
	var worst_slip := 0.0
	var hits := []
	var bins := {}
	var went := 0.0
	var last_s: float = serpent.s
	var frames := 0
	var began := Time.get_ticks_msec()
	while went < serpent.route_length+20.0 and frames < 30000:
		serpent.advance(DT)
		frames += 1
		went += fposmod(serpent.s-last_s,serpent.route_length)
		last_s = serpent.s
		bins[int(serpent.s/50.0)] = true
		var head: float = serpent.travelled
		been_d.append(head)
		been_p.append(serpent.trail_at(head)[0])
		var rings: PackedVector3Array = serpent.rings()
		var now := PackedVector3Array(rings)
		now.append(serpent.snout())
		if prev2.size() == now.size():
			for k in range(now.size()):
				var a := (now[k]-2.0*prev[k]+prev2[k]).length()/(DT*DT)
				if a > worst_pop:
					worst_pop = a
					pop_at = "%s at %.0f m (%s)" % ["snout" if k == now.size()-1 else "ring %d" % k,serpent.s,serpent.mode]
			for k in range(neck+1,tail):
				var v := (now[k]-prev[k])/DT
				var t := (now[k-1]-now[k+1]).normalized()
				if v.length() > 1.0: worst_slip = maxf(worst_slip,(v-t*v.dot(t)).length()/v.length())
		prev2 = prev
		prev = now
		if frames % 10 == 0:
			for k in range(neck,tail,3):
				var at := head-arcs[k]
				var i := been_d.bsearch(at)
				if i <= 0 or i >= been_d.size(): continue
				var f := (at-been_d[i-1])/maxf(been_d[i]-been_d[i-1],1e-6)
				worst_off = maxf(worst_off,rings[k].distance_to(been_p[i-1].lerp(been_p[i],f)))
		if frames % 12 == 0:
			var radii: PackedFloat32Array = serpent.radii()
			for k in range(rings.size()):
				ball.radius = radii[k]+MARGIN
				q.transform = Transform3D(Basis.IDENTITY,rings[k])
				var bad := not space.intersect_shape(q,1).is_empty()
				if bad and (hits.is_empty() or serpent.s-float(hits[-1]) > 10.0): hits.append(snappedf(serpent.s,1.0))
		if frames % 600 == 0: await process_frame
	print("serpent: flew %.0f m in %d frames (%d ms), worst advance %d us, %d notices of the pilot" % [went,frames,Time.get_ticks_msec()-began,serpent.worst_usec,serpent.notices])
	var all_bins := int(ceil(serpent.route_length/50.0))
	check(went >= serpent.route_length and bins.size() >= all_bins,"It flies its whole way round (%.0f of %.0f m, %d of %d stretches)" % [went,serpent.route_length,bins.size(),all_bins])
	check(worst_off < ON_PATH,"Every ring behind the neck lies where the head was when it had come that far (%.3f m off at most)" % worst_off)
	check(worst_slip < SLIP,"The body slides along its own line, never sideways (at most %.3f of a ring's speed across it)" % worst_slip)
	check(worst_pop < POP,"Nothing pops (worst %.1f m/s², %s; under %.0f)" % [worst_pop,pop_at,POP])
	check(hits.is_empty(),"Its body keeps clear of every isle's ground and rock as it flies (touching at %s m)" % str(hits))

## Solid to the plane: a ray down onto its middle finds it; the plane put
## inside its body is bumped back out.
func _solid() -> void:
	serpent._place_solid()
	await physics_frame
	await physics_frame
	var rings: PackedVector3Array = serpent.rings()
	var mid := rings[RuneSerpent.STATIONS/2]
	var space := study.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(mid+Vector3.UP*20.0,mid,1)
	var hit := space.intersect_ray(ray)
	check(not hit.is_empty() and hit.collider == serpent.get_node("Solid"),"Its body is solid on the bump's layer (a ray finds it over its middle)")
	study.board()
	check(study.flying,"Into the plane")
	var plane: RefCounted = study.plane
	var was := mid+Vector3.UP*14.0
	plane.position = mid
	var bumped: bool = study._bump(was)
	check(bumped and plane.position.distance_to(mid) > serpent.radii()[RuneSerpent.STATIONS/2]*0.8,"The plane flown into it is bumped back out (%.1f m from its middle)" % plane.position.distance_to(mid))

## A plane alongside: noticed, watched with the head turned to it, paced
## at its speed, then left. Never closer than the pacing gap.
func _plane() -> void:
	var plane: RefCounted = study.plane
	serpent.place(serpent.marks().get("north",0.0))
	serpent._notice_ready = 0.0
	var way: Vector3 = serpent._route_way(serpent.s)
	var right := way.cross(Vector3.UP).normalized()
	plane.position = serpent.head()+right*55.0+Vector3.UP*3.0
	plane.heading = atan2(-way.x,-way.z)
	plane.pitch = 0.0
	plane.speed = 13.0
	plane.velocity = plane.forward()*13.0
	var seen := {}
	var turned := 0.0
	var paced_speed := 0.0
	var closest := INF
	for i in range(int(40.0/DT)):
		# The plane flies on at 13 m/s along the serpent's way, steering
		# only across it to stay 50 m off its line.
		var w: Vector3 = serpent._route_way(serpent.s)
		var r := w.cross(Vector3.UP).normalized()
		var beside: Vector3 = serpent.route_point(serpent.s)+r*50.0+Vector3.UP*3.0
		var across: Vector3 = beside-(plane.position as Vector3)
		across -= w*across.dot(w)
		plane.velocity = w*13.0+across*0.8
		plane.position += plane.velocity*DT
		plane.heading = atan2(-plane.velocity.x,-plane.velocity.z)
		serpent.advance(DT)
		seen[serpent.mode] = true
		closest = minf(closest,plane.position.distance_to(serpent.head()))
		if serpent.mode in ["watch","pace"]:
			var to: Vector3 = (plane.position-serpent.head()).normalized()
			var flat_to := Vector2(to.x,to.z).normalized()
			var head := Vector2(serpent.head_dir().x,serpent.head_dir().z).normalized()
			var path := Vector2(w.x,w.z).normalized()
			turned = maxf(turned,flat_to.dot(head)-flat_to.dot(path))
		if serpent.mode == "pace": paced_speed = serpent.speed()
	check(seen.has("watch"),"A plane alongside within %.0f m is noticed (%s)" % [RuneSerpent.NOTICE,str(seen.keys())])
	check(turned > 0.25,"It turns its head toward the plane, past its way (the head's facing toward it up by %.2f)" % turned)
	check(seen.has("pace") and seen.has("peel"),"It paces the plane a while, then peels away")
	check(paced_speed > RuneSerpent.PACE_RANGE.x and absf(paced_speed-13.0) < 2.5,"Pacing, it flies near the plane's speed (%.1f m/s against 13)" % paced_speed)
	check(closest > 15.0,"It never comes at the plane (closest %.1f m)" % closest)
	study.leave_plane()

## --no-serpent leaves it out; without it, a sky has one.
func _flag() -> void:
	var others := ["--no-far-isles","--no-airships","--no-traffic","--no-sky-life","--no-motes","--no-sky-tokens"]
	var out: Array = []
	for with_flag in [true,false]:
		LaunchArgs.set_override(others+(["--no-serpent"] if with_flag else []))
		var other: Node3D = IsleSky.new()
		study.add_child(other)
		other.setup(study)
		out.append([bool(other.on.serpent),other.serpent != null])
		other.queue_free()
		await process_frame
	LaunchArgs.set_override(null)
	check(out[0] == [false,false],"--no-serpent leaves it out (%s)" % str(out[0]))
	check(out[1] == [true,true],"Without it, a sky has its serpent (%s)" % str(out[1]))
