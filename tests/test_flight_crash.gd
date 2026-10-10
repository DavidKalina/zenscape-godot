extends SceneTree
## Crash and restart in the flight study (scripts/flight_crash.gd, an opt-in
## layer round scripts/ruin_bump.gd), headless: off is bump and recover as
## before, run for run; a head-on hit crashes in `hard` and `any` and the
## plane flies on from the restart point (checkpoint, ring, entry) at cruise
## along the line within about a second, the challenge carried on, restarted
## or ended as each restart says, free collectibles kept; a glancing scrape
## only bumps in `hard` but crashes in `any`, and on a solid tagged with the
## "obstacle" crash class; the record is kept apart; the bot flies on after a
## crash; the study plays the crash, cuts to the restart and counts it.
##   godot --headless --path . --script tests/test_flight_crash.gd
const Course = preload("res://scripts/flight_course.gd")
const Run = preload("res://scripts/flight_run.gd")
const Bot = preload("res://scripts/flight_bot.gd")
const Bench = preload("res://tools/flight_bench.gd")
const Crash = preload("res://scripts/flight_crash.gd")
const SkyPlane = preload("res://scripts/sky_plane.gd")
const DT := 1.0/60.0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

## A straight lane north (its line all guides) at `origin`, with a free
## moment, the starter and a challenge one before `parts`, and one beyond.
func lane(origin: Vector3, parts: Array) -> Dictionary:
	return {"id":"crash_test_%d" % int(origin.x),"key":-1,"pack":"crash_test","origin":origin,"name":"Crash lane","intent":"","parts":parts,
		"tokens":[Vector3(0.0,0.0,-12.0),Vector3(0.0,0.0,-30.0),Vector3(0.0,0.0,-50.0),Vector3(0.0,0.0,-70.0),Vector3(0.0,0.0,-90.0),Vector3(0.0,0.0,-110.0)],
		"moments":[{"at":Vector3(0.0,0.0,-14.0),"role":"free","kind":"reach"},{"at":Vector3(0.0,0.0,-24.0),"role":"starter","kind":""},
			{"at":Vector3(0.0,0.0,-34.0),"role":"challenge","kind":"fit"},{"at":Vector3(0.0,0.0,-100.0),"role":"challenge","kind":"reach"}]}

## A wall square across the lane at 66 m: flown straight, a head-on hit.
func head_on(origin: Vector3) -> Dictionary:
	return lane(origin,[["box",Vector3(0.0,0.0,-66.0),Vector3(12.0,12.0,1.0),0.0]])

## A long wall turned 0.1 rad so its face creeps across the lane from the
## right: flown straight, a glancing scrape (about 6 degrees).
func glancing(origin: Vector3) -> Dictionary:
	return lane(origin,[["box",Vector3(2.6,0.0,-55.0),Vector3(1.0,12.0,40.0),0.1]])

## Flies `s` hands off (straight on) with crash rules `rules` until it ends
## or `most` s; returns the run.
func fly_straight(s: Dictionary, space: PhysicsDirectSpaceState3D, rules: Dictionary, most := 12.0) -> Run:
	var r := Run.new(s,"human",{},space)
	r.set_crash(rules)
	var ticks := 0
	while not r.done and ticks < int(most*60.0):
		r.tick(DT,{})
		ticks += 1
	return r

func events(r: Run, kind: String) -> Array:
	return r.events.filter(func(e: Dictionary) -> bool: return str(e.kind) == kind)

func run() -> void:
	create_timer(240.0).timeout.connect(func() -> void: push_error("flight crash test timed out"); quit(2))
	var wall := head_on(Vector3(0.0,40.0,-5000.0))
	var slant := glancing(Vector3(300.0,40.0,-5000.0))
	var tagged := glancing(Vector3(600.0,40.0,-5000.0))
	var stage := Node3D.new()
	root.add_child(stage)
	for s: Dictionary in [wall,slant]: Course.build(s,stage)
	# An obstacle: the same slant, its stone tagged with the "obstacle" crash class.
	var obstacle := Course.build(tagged,stage)
	for body in obstacle.get_children(): body.set_meta(Crash.CLASS_META,"obstacle")
	await physics_frame
	await physics_frame
	var space := stage.get_world_3d().direct_space_state

	# Off: bump and recover, the run as it was without the layer.
	var plain := Run.new(wall,"human",{},space)
	for i in range(int(8.0*60.0)): plain.tick(DT,{})
	var off := fly_straight(wall,space,{"mode":"off","restart":"entry"},8.0)
	check(off.crash.is_empty() and off.crashes == 0 and off.bumps > 0,"Off: the head-on wall only bumps (%d bumps, no crash)" % off.bumps)
	var a := plain.finish()
	var b := off.finish()
	check(a.events == b.events and a.ticks == b.ticks and a.station_hash == b.station_hash and a.metrics == b.metrics and not b.has("crash"),"Off: events, ticks, numbers and record match a run without crash rules")
	check(Crash.rules({}).is_empty() and Crash.rules({"mode":"nonsense"}).is_empty(),"Off is the default")

	# Hard, checkpoint: a head-on hit crashes; it flies on from a safe point
	# behind it, at cruise along the line, the challenge still on.
	for mode: String in ["hard","any"]:
		var r := Run.new(wall,"human",{},space)
		r.set_crash({"mode":mode,"restart":"checkpoint"})
		var crashed_at := -1
		var flying_at := -1
		var ticks := 0
		var after := {}
		while not r.done and ticks < 60*12:
			r.tick(DT,{})
			ticks += 1
			if crashed_at < 0 and r.crashes > 0:
				crashed_at = ticks
				after = {"p":r.plane.position,"speed":r.plane.speed,"heading":r.plane.heading,"challenge":r.challenge,"free":r.free_taken(),"held":r.crash_left}
			if crashed_at >= 0 and flying_at < 0 and r.crash_left <= 0.0: flying_at = ticks
		var crash: Array = events(r,"crash")
		check(not crash.is_empty() and float(crash[0].into) >= Crash.HARD,"%s: the head-on wall crashes (%.1f m/s into it)" % [mode,float(crash[0].into) if not crash.is_empty() else 0.0])
		if crash.is_empty(): continue
		var back := float((after.p as Vector3).z)-(float(wall.origin.z)-66.0)
		check(back > Crash.BACK*SkyPlane.CRUISE_SPEED-4.0 and absf((after.p as Vector3).x) < 0.5,"%s: restarted on the line %.1f m back from the wall" % [mode,-back])
		check(is_equal_approx(float(after.speed),SkyPlane.CRUISE_SPEED) and absf(angle_difference(float(after.heading),0.0)) < 0.05,"%s: at cruise, heading along the line" % mode)
		check(str(after.challenge) == "on" and int(after.free) == 1,"%s, checkpoint: the challenge carries on, the free one stays taken" % mode)
		check(flying_at-crashed_at <= 60 and flying_at-crashed_at >= int(Crash.HOLD*60.0)-1,"%s: flying again %.2f s after the impact" % [mode,(flying_at-crashed_at)/60.0])
		var rec := r.finish()
		check(rec.has("crash") and str(rec.station_hash).ends_with(":crash-%s-checkpoint" % mode) and int(rec.metrics.crashes) == r.crashes and (rec.cuts as Array).size() == r.respawns,
			"%s: the record is its own (%s), crashes and restarts counted (%d)" % [mode,rec.station_hash,r.crashes])
		check(float(rec.metrics.turn_flown_peak) < 3.0,"%s: the jump to the restart isn't counted as flown turn (peak %.2f)" % [mode,float(rec.metrics.turn_flown_peak)])

	# Entry: the challenge ends ("crash") and the starter stands again.
	var e := Run.new(wall,"human",{},space)
	e.set_crash({"mode":"hard","restart":"entry"})
	while e.crashes == 0 and e.t < 12.0: e.tick(DT,{})
	check(e.plane.position.distance_to(Course.entry(wall).position) < 0.01 and e.challenge == "crash" and e.moment_state[1] == 0 and e.moment_state[0] == 1,
		"Entry: back at the entry, the challenge ended (%s), the starter standing, the free one kept" % e.challenge)
	check(e.state[0] == Run.STANDING,"Entry: the line stands again from the start")

	# Ring: the challenge starts afresh at the starter (a new try).
	var g := Run.new(wall,"human",{},space)
	g.set_crash({"mode":"hard","restart":"ring"})
	while g.crashes == 0 and g.t < 12.0: g.tick(DT,{})
	var starter_at: Vector3 = wall.moments[1].at+Course.origin(wall)
	check(g.plane.position.distance_to(starter_at) < 1.0 and g.challenge == "on" and g.challenge_tries == 2 and g.challenge_now == 0 and g.moment_live[2] == 1,
		"Ring: at the starter (%.1f m), the challenge afresh (try %d)" % [g.plane.position.distance_to(starter_at),g.challenge_tries])
	# Ring with no challenge on falls back to the checkpoint.
	var ring_only := head_on(Vector3(0.0,40.0,-5000.0))
	ring_only.moments = [{"at":Vector3(0.0,0.0,-14.0),"role":"free","kind":"reach"}]
	var g2 := Run.new(ring_only,"human",{},space)
	g2.set_crash({"mode":"hard","restart":"ring"})
	while g2.crashes == 0 and g2.t < 12.0: g2.tick(DT,{})
	check(events(g2,"respawn").size() == 1 and str(events(g2,"respawn")[0].restart) == "checkpoint","Ring with no challenge on: the checkpoint")

	# A glancing scrape: only a bump in hard, a crash in any and on an obstacle.
	var scrape := fly_straight(slant,space,{"mode":"hard","restart":"checkpoint"},6.0)
	var bumps := events(scrape,"bump")
	check(scrape.crashes == 0 and not bumps.is_empty() and float(bumps[0].into) < Crash.HARD and str(bumps[0].solid) == "stone",
		"Hard: a glancing scrape bumps and recovers (%.1f m/s into it, %d bumps)" % [float(bumps[0].into) if not bumps.is_empty() else -1.0,bumps.size()])
	var any := fly_straight(slant,space,{"mode":"any","restart":"checkpoint"},6.0)
	check(any.crashes > 0,"Any: the same scrape crashes")
	var tagged_run := fly_straight(tagged,space,{"mode":"hard","restart":"checkpoint"},6.0)
	check(tagged_run.crashes > 0 and str(events(tagged_run,"crash")[0].solid) == "obstacle","Hard: the same scrape on a solid of the \"obstacle\" class crashes")
	check(Crash.threshold({"mode":"hard","restart":"checkpoint","hard":5.0},"stone") == 5.0 and Crash.tag(Crash.rules({"mode":"hard","hard":5.0})) == "crash-hard@5.0-checkpoint",
		"--crash-speed sets stone's threshold, and tags the record")

	# The bot flies on after a crash: the sharp bot through the hall, crashing on.
	var hall := Course.station("moments_hall")
	var built := Course.build(hall,stage)
	await physics_frame
	await physics_frame
	var flown: Dictionary = Bench.fly(hall,"sharp",Bot.skill("sharp"),3,space,{"mode":"any","restart":"checkpoint"})
	check(str(flown.result.ended) == "done" and int(flown.metrics.crashes) > 0,"The sharp bot flies the hall to its end crashing on any contact (%d crashes, %s)" % [int(flown.metrics.crashes),flown.result.ended])
	var plain_hall: Dictionary = Bench.fly(hall,"sharp",Bot.skill("sharp"),3,space)
	check(not plain_hall.has("crash") and plain_hall.station_hash == Course.station_hash(hall),"Off, the hall's record and hash are its own as ever")
	built.queue_free()

	# The study: the crash plays and cuts to the restart; R is quick.
	var study: Node3D = load("res://studies/flight_study.tscn").instantiate()
	study.scripted = true
	study.log_dir = "user://flight_runs_test_crash"
	root.add_child(study)
	while not study.flight_ready: await process_frame
	Course.build(wall,study)
	await physics_frame
	await physics_frame
	study.crash_given = {"mode":"hard","restart":"checkpoint"}
	study.start(wall)
	var frames := 0
	while study.run.crashes == 0 and frames < 60*10:
		study.tick(DT)
		frames += 1
	check(study._crash_t >= 0.0 and study._wreck.visible and not study.figure.visible and study._debris.size() == study.DEBRIS,"Study: the crash plays (wreck, %d pieces of debris)" % study._debris.size())
	check(study._veil.color.a > 0.3,"Study: a flash")
	check(study.crash_line(study.run.live(),study.crash_given).contains("crashes 1"),"Study: the HUD counts it (%s)" % study.crash_line(study.run.live(),study.crash_given))
	var held := 0
	while study._crash_t >= 0.0 and held < 120:
		study.tick(DT)
		held += 1
	check(study.figure.visible and not study._wreck.visible and study._debris.is_empty() and held <= 60,"Study: cut to the restart %.2f s after the impact" % (held/60.0))
	var was: Vector3 = study.run.plane.position
	for i in range(12): study.tick(DT)
	check(study.run.plane.position.distance_to(was) > 2.0 and study._veil.color.a < 0.05,"Study: flying on, the fade gone in %.2f s" % (12.0/60.0))
	frames = 0
	while not study.run.done and frames < 60*90:
		study.tick(DT)
		frames += 1
	study.asking = ""
	study._show_report()
	check(study._report_label.text.contains("Crashes "),"Study: the end panel counts crashes")
	study.cycle_crash()
	check(str(study.crash_given.mode) == "off" and study.run.crash.is_empty(),"Study: C turns crashing off (and starts afresh)")
	study.cycle_restart()
	check(str(study.crash_given.restart) == "ring","Study: T cycles the restart point")
	# R: as quick as ever.
	var slowest := 0
	for s: Dictionary in Course.pack("moments"):
		study.start(s)
		var began := Time.get_ticks_usec()
		study.restart()
		slowest = maxi(slowest,Time.get_ticks_usec()-began)
	check(slowest < 100000,"R restarts a moments station in %.1f ms at most" % (slowest/1000.0))
	print("flight crash: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
