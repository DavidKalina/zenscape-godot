extends SceneTree
## suite: slow
## The lodestone loop as the player plays it (docs/design/isle-hall-chain.md,
## docs/design/isle-hall-line.md), headless, through the game's own front
## door (studies/zenscape.tscn, straight in: --no-title) with no study
## flags: no --near-ring, no carried stone, no teleport onto the ring.
## The other loop tests open the aqueduct isle with the stone carried and
## jump the plane to the ring, so they missed what the player met: the ring
## woke 420 m out, as the plane rolled off the isle, and stood half a
## minute before the plane got there ("the arch is always there").
##
## First without the stone: the plane boarded where it is parked, rolled
## off the isle's edge, flown out past the shard and along the ring's line:
## no ring ever shows, nothing is threaded, no hall rises. Then he walks to
## the lodestone, picks it up and keeps it, is back by the plane, boards
## it, rolls it off the edge and flies on at the shard and the ring past it:
## the ring stays hidden till the plane nears (it is seen rising, not
## standing from the start), stands shortly before the plane gets there,
## is threaded by flying the plane through its opening, then the pause, the
## pulse and the Sundered line's first piece rising whole out of the cloud
## ahead, standing still before the plane reaches it, the next behind it.
##   godot --headless --path . --script tests/test_isle_loop_played.gd
const ChainPlan = preload("res://scripts/hall_chain_plan.gd")
const IsleChain = preload("res://studies/aqueduct_isle_chain.gd")
const Line = preload("res://scripts/hall_line.gd")
const SkyPlane = preload("res://scripts/sky_plane.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const DT := 1.0/60.0
## The isle's middle (studies/aqueduct_isle_chain.gd ISLE).
const ISLE := Vector2(85.0,-20.0)
var failures := 0
var checks := 0
## Every check this test makes (a script error part way stops short of it).
const CHECKS := 23
var s: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(420.0).timeout.connect(func() -> void: push_error("isle loop played test timed out"); quit(2))
	LaunchArgs.set_override(PackedStringArray(["--no-title"]))
	s = load("res://studies/zenscape.tscn").instantiate()
	root.add_child(s)
	current_scene = s
	var frames := 0
	while not s.walk_ready and frames < 6000:
		await process_frame
		frames += 1
	await physics_frame
	var c: Node3D = s.isle_chain
	check(c != null and s.chain_on and c.state == "hidden" and not c.ring.visible,"The game opens with the ring hidden, the chain on")
	check(s.shard.get_child_count() > 0 and not _has_arch(s.shard),"The shard bears no arch of its own (the ring is the arch)")
	await _no_stone()
	await _with_stone()
	await _threads_while_rising()
	if checks < CHECKS:
		failures += 1
		print("FAIL only %d of %d checks ran" % [checks,CHECKS])
	LaunchArgs.set_override(null)
	s.queue_free()
	await process_frame
	print("PASS: isle loop played" if failures == 0 else "FAIL: isle loop played (%d)" % failures)
	quit(1 if failures > 0 else 0)

func _has_arch(node: Node) -> bool:
	for child in node.get_children():
		if str(child.name).to_lower().contains("arch"): return true
	return false

func _ahead(h: float) -> Vector3:
	return Vector3(-sin(h),0.0,-cos(h))

## A pursuit pilot at `aim` (as tests/test_isle_hall_chain.gd).
func _toward(aim: Vector3) -> Dictionary:
	var plane: RefCounted = s.plane
	var to: Vector3 = aim-plane.position
	var err := wrapf(ChainPlan.heading_of(to)-float(plane.heading),-PI,PI)
	var want_pitch := atan2(to.y,maxf(Vector2(to.x,to.z).length(),1.0))
	return {"turn":clampf(-err*3.0,-1.0,1.0),"pitch":clampf((want_pitch-float(plane.pitch))*2.5,-1.0,1.0)}

## Out of the parked plane's spot: boarded, throttled up along its
## heading till it rolls off the isle's edge and the wings catch.
func _take_off() -> bool:
	s.back_to_plane()
	await process_frame
	s.board_parked()
	s.scripted = true
	var t := 0.0
	while t < 20.0 and not (s.takeoff == null and s.hand_landing.flying()):
		s.fly_step(DT,{"boost":1.0})
		t += DT
		if int(t/DT) % 4 == 0: await process_frame
	return s.flying and s.takeoff == null and s.hand_landing.flying()

## One flown frame towards the ring's opening: at a point before it on its
## line, then along the line through it.
func _fly_at_ring(c: Node3D) -> Dictionary:
	var h: float = c.ring_heading
	var p: Vector3 = s.plane.position
	var along: float = (p-c.ring_at).dot(_ahead(h))
	if along < -150.0: return _toward(c.ring_at-_ahead(h)*120.0)
	return _toward(c.ring_at+_ahead(h)*(along+40.0))

## No stone: the ring never wakes, however near the plane comes.
func _no_stone() -> void:
	var c: Node3D = s.isle_chain
	check(s.lode_state == "resting","The stone rests on its floating stone")
	check(await _take_off(),"Without the stone the plane rolls off the edge and flies")
	var seen := false
	var nearest := INF
	var t := 0.0
	while t < 60.0:
		s.fly_step(DT,_fly_at_ring(c))
		t += DT
		if int(t/DT) % 4 == 0: await process_frame
		if c.ring.visible: seen = true
		nearest = minf(nearest,s.plane.position.distance_to(c.ring_at))
		if (s.plane.position-c.ring_at).dot(_ahead(c.ring_heading)) > 60.0: break
	check(nearest < 10.0,"It flew through where the ring would stand (%.1f m from its middle)" % nearest)
	check(not seen and c.state == "hidden" and c.chain.halls.is_empty(),"Without the stone no ring shows, nothing is threaded, no hall rises (%s)" % c.state)
	s.leave_plane()
	for i in range(5): await process_frame
	s.scripted = false

## The stone picked up, kept, seated; the plane flown off the isle at the
## shard and through the ring.
func _with_stone() -> void:
	var c: Node3D = s.isle_chain
	var r: Vector3 = s.lode_rest
	s.place(Vector3(r.x+0.5,r.y-s.LODE_HOVER,r.z),Vector2(-1.0,0.0))
	await physics_frame
	await process_frame
	check(s.can_pick(),"Beside the stone it can be picked up")
	s.pick_up()
	for i in range(60): await process_frame
	s.keep_stone()
	for i in range(10): await process_frame
	check(s.lode_state == "carried","He keeps the stone")
	check(await _take_off(),"With the stone the plane rolls off the edge and flies")
	check(s.lode_state == "seated","The stone rides in the plane")
	var off_isle: float = Vector2(s.plane.position.x-ISLE.x,s.plane.position.z-ISLE.y).length()
	check(not c.ring.visible and c.state == "hidden","Airborne off the isle (%.0f m from its middle) the ring is still hidden" % off_isle)
	var woke_at := -1.0
	var woke_speed := 0.0
	var stood_at := -1.0
	var seen_from := 0.0
	var t := 0.0
	while t < 90.0 and c.state in ["hidden","rising","standing"]:
		s.fly_step(DT,_fly_at_ring(c))
		t += DT
		if int(t/DT) % 4 == 0: await process_frame
		var d: float = s.plane.position.distance_to(c.ring_at)
		if c.ring.visible and seen_from == 0.0: seen_from = d
		if woke_at < 0.0 and c.state != "hidden":
			woke_at = d
			woke_speed = float(s.plane.speed)
		if stood_at < 0.0 and c.state != "hidden" and c._lift.position.length() < 0.01: stood_at = d
	var from_isle: float = Vector2(c.ring_at.x-ISLE.x,c.ring_at.z-ISLE.y).length()
	check(woke_at > 0.0 and woke_at < from_isle-200.0,"The ring wakes as the plane nears, %.0f m out (the isle is %.0f m off; it woke 420 m out, as the plane left the isle)" % [woke_at,from_isle])
	check(absf(seen_from-woke_at) < 1.0,"Hidden till then: first seen %.0f m out" % seen_from)
	check(stood_at > 0.0 and stood_at/maxf(woke_speed,1.0) < 8.0,"It stands shortly before the plane gets there (%.0f m out, %.1f s)" % [stood_at,stood_at/maxf(woke_speed,1.0)])
	check(c.state in ["passed","started"] and c.misses == 0,"Flown through its opening, the ring is threaded (%s, %d misses)" % [c.state,c.misses])
	check(c.chain.halls.size() == 1,"The line's first piece starts rising at once")
	var started := false
	var first_still := -1.0
	var reached := false
	t = 0.0
	while t < 40.0 and not reached:
		var input := _toward(s.plane.position+_ahead(c.pass_heading)*60.0)
		if not c.chain.halls.is_empty():
			var gate: Vector3 = Line.gate_of(c.chain.halls[0].pose)
			input = _toward(gate+Vector3.UP*0.0)
			if s.plane.position.distance_to(gate) < 20.0: reached = true
		s.fly_step(DT,input)
		t += DT
		if int(t/DT) % 4 == 0: await process_frame
		if c.state == "started": started = true
		var rise: Node3D = c.chain.halls[0].rise
		if first_still < 0.0 and float(rise.done_at) >= 0.0: first_still = t
	check(started and s._nose.quieting,"After the pause the pulse runs and the arrow folds quiet")
	var piece: Node3D = c.chain.halls[0].rise
	check(piece.is_visible_in_tree() and first_still > 0.0,"The first Sundered piece rose out of the cloud and stands (still %.1f s after threading)" % first_still)
	check(reached and first_still < t,"It stood before the plane reached its entry (%.1f s, reached %.1f s)" % [first_still,t])
	var gate: Vector3 = Line.gate_of(c.chain.halls[0].pose)
	var off := absf(rad_to_deg(wrapf(ChainPlan.heading_of(gate-c.pass_point)-c.pass_heading,-PI,PI)))
	check(off < 5.0 and gate.y > IsleChain.SEA_TOP+100.0,"Dead ahead of where the plane left the ring (%.1f degrees off), up at the plane's height (%.0f m)" % [off,gate.y])
	check(c.chain.halls.size() >= 2,"And the next piece rises behind it (%d pieces)" % c.chain.halls.size())

## Woken late (it wakes only some 13 s out now), a plane that speeds up can
## get there while the ring still climbs: going through its opening where
## it is then threads it all the same, and it climbs on to stand.
func _threads_while_rising() -> void:
	var c: Node3D = IsleChain.new()
	s.add_child(c)
	c.setup(s.lode_target,PackedStringArray(["--line-look=greybox"]))
	var plane: RefCounted = SkyPlane.new()
	plane.launch(c.ring_at-_ahead(c.ring_heading)*30.0,c.ring_heading,SkyPlane.BOOST_SPEED,false)
	c.appear()
	var t := 0.0
	while t < c.ring_length()*0.6:
		c.step(DT,null,true)
		t += DT
	var mid: Vector3 = c.ring.global_transform*(c._lift.position+Vector3.UP*IsleChain.THREAD_UP)
	check(c.state == "rising" and mid.y < c.ring_at.y-0.5,"Part way up its rise the opening is still %.1f m under where it will stand" % (c.ring_at.y-mid.y))
	for k in range(-3,4):
		plane.position = mid+_ahead(c.ring_heading)*float(k)*2.0
		c.step(DT,plane,true)
	var stood := false
	for i in range(int(c.ring_length()/DT)):
		c.step(DT,null,true)
		if c.ring_stood:
			stood = true
			break
	check(c.state in ["passed","started"] and c.chain.halls.size() == 1 and stood and c._lift.position.length() < 0.01,"Threaded while it still climbs: it counts (%s), the line starts and the ring climbs on to stand" % c.state)
	c.queue_free()
