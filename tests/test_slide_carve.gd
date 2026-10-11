extends SceneTree
## Carving the slide (scripts/pilot_motor.gd `carve`), headless. With it
## off, a slide on the flat and a surf down a slope go exactly as they did
## before there was carving (AS_WAS: the motor at 49393ab7, step for step).
## With it on, the stick held across a slide on the flat turns its way at
## CARVE_TURN (no faster than its pace over CARVE_RADIUS), its pace carried
## round less the scrub and never gaining; the stick held back still brakes
## as ever; on a slope it carves and the fall line still pulls, so carving
## across it gains less than running down it; a long jump out of a carved
## slide leaves along the carved way, and slide hops weaving through their
## touches still chain past LONG_TOP. The studies: `--carve` and F3 turn it
## on, F1 shows it, F2 holds its numbers, a recording made carving replays
## carving and one made before carving replays as it was. On the rune
## serpent (studies/serpent_ride.tscn), a bot's carved slide
## (tools/slide_carve_bot.gd) follows its spine down the dive to its neck.
##   godot --headless --path . --script tests/test_slide_carve.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const Bot = preload("res://tools/slide_carve_bot.gd")
const Recording = preload("res://scripts/character_recording.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const DT := 1.0/60.0
## Carving off, the end of each run in `as_was_runs` (feet x, y, z, pace x,
## z, facing, move), as the motor before carving (49393ab7) left them.
const AS_WAS := {
	"flat crouched":[7.744044304,0.000000000,-0.000000000,2.855702162,-0.000000000,-1.570796327,"slide"],
	"flat stood":[4.201607704,0.000000000,1.299281955,4.197672844,3.286518574,-2.235046826,"slide"],
	"slope across":[8.742877007,-5.047702312,6.945948124,7.614551067,5.993042946,-2.237591750,"slide"],
	"slope braked":[7.776492119,-4.489759922,0.000000000,8.209447861,0.000000000,-1.570796327,"slide"],
}
## Down the serpent's dive: its head this far (m) on from the dive's mark
## for each slide, him starting this far from its snout (near its tail).
const DIVE_PLACES := [20.0,40.0,60.0]
const DIVE_FROM := 70.0
## A run made in the room before there was carving, replayed with F3 on.
const OLD_RUN := "res://studies/character_runs/20261010_011040_fluid-gameplay-2.json"
var failures := 0
var flat := func(_p: Vector2) -> float: return 0.0
var free := func(feet: Vector3, step: Vector2) -> Vector3: return feet+Vector3(step.x,0.0,step.y)

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, what: String) -> void:
	if ok: print("ok   ",what)
	else:
		failures += 1
		print("FAIL ",what)

func run() -> void:
	create_timer(300.0).timeout.connect(func() -> void: push_error("slide carve test timed out"); quit(2))
	_off_as_was()
	_flat_carve()
	_slow_carve()
	_brakes()
	_slope_carve()
	_long_jump_out()
	_hops_chain()
	await _study()
	await _serpent()
	print("PASS: slide carve" if failures == 0 else "FAIL: slide carve (%d)" % failures)
	quit(1 if failures else 0)

# --- Off: as it was -----------------------------------------------------------------

## Slides and surfs with the stick across and back, run on `motor_script`
## (this motor, or the one before carving): each run's end, as AS_WAS.
static func as_was_runs(motor_script: GDScript) -> Dictionary:
	var level := func(_p: Vector2) -> float: return 0.0
	var slope := func(p: Vector2) -> float: return -p.x*tan(deg_to_rad(30.0))
	var go := func(feet: Vector3, step: Vector2) -> Vector3: return feet+Vector3(step.x,0.0,step.y)
	var out := {}
	# Crouched on the flat from 8 m/s, the stick ahead and across.
	var m: RefCounted = _uncarved(motor_script)
	m.reset(Vector3.ZERO,motor_script.facing_of(Vector2(1.0,0.0)),8.0)
	m.crouch = true
	for i in range(90): m.step(DT,Vector2(0.6,0.8),PilotMotor.RUN,false,level,go)
	out["flat crouched"] = _end(m)
	# Into the slide crouched, then up, the stick across.
	m = _uncarved(motor_script)
	m.reset(Vector3.ZERO,motor_script.facing_of(Vector2(1.0,0.0)),8.0)
	m.crouch = true
	m.step(DT,Vector2(1.0,0.0),PilotMotor.RUN,false,level,go)
	m.crouch = false
	for i in range(40): m.step(DT,Vector2(0.0,1.0),PilotMotor.RUN,false,level,go)
	out["flat stood"] = _end(m)
	# Down a 30° slope from a stand, crouched, the stick across.
	m = _uncarved(motor_script)
	m.reset(Vector3.ZERO,motor_script.facing_of(Vector2(1.0,0.0)))
	m.crouch = true
	for i in range(120): m.step(DT,Vector2(0.0,1.0),PilotMotor.RUN,false,slope,go)
	out["slope across"] = _end(m)
	# Down it with no stick, then braked, the stick back.
	m = _uncarved(motor_script)
	m.reset(Vector3.ZERO,motor_script.facing_of(Vector2(1.0,0.0)))
	m.crouch = true
	for i in range(60): m.step(DT,Vector2.ZERO,PilotMotor.RUN,false,slope,go)
	for i in range(30): m.step(DT,Vector2(-1.0,0.0),PilotMotor.RUN,false,slope,go)
	out["slope braked"] = _end(m)
	return out

## A motor of `motor_script` with carving off (the motor carves by default;
## the one before carving has no `carve`).
static func _uncarved(motor_script: GDScript) -> RefCounted:
	var m: RefCounted = motor_script.new()
	if "carve" in m: m.set("carve",false)
	return m

static func _end(m: RefCounted) -> Array:
	return [m.feet.x,m.feet.y,m.feet.z,m.velocity.x,m.velocity.z,m.facing,m.move]

func _off_as_was() -> void:
	var now := as_was_runs(PilotMotor)
	for key: String in AS_WAS:
		var then: Array = AS_WAS[key]
		var got: Array = now[key]
		var worst := 0.0
		for i in range(6): worst = maxf(worst,absf(float(got[i])-float(then[i])))
		print("MEASURE carving off, %s: feet %.4f, %.4f, %.4f, pace %.4f, %.4f, facing %.4f, %s (before carving: %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %s)" % ([key]+got+then))
		check(worst < 1e-5 and got[6] == then[6],"Carving off, %s goes as it did before carving (at most %.7f off)" % [key,worst])
	check(AS_WAS.size() == 4,"Every run is checked against the motor before carving (%d)" % AS_WAS.size())
	var crouched: Array = now["flat crouched"]
	check(absf(float(crouched[2])) < 1e-6,"Carving off, the crouched slide on the flat runs straight, the stick across or not (%.4f m across)" % float(crouched[2]))

# --- On: the flat ---------------------------------------------------------------------

## A carver sliding along +x at `pace`, crouched.
func _carver(pace: float) -> PilotMotor:
	var m := PilotMotor.new()
	m.carve = true
	m.reset(Vector3.ZERO,PilotMotor.facing_of(Vector2(1.0,0.0)),pace)
	m.crouch = true
	return m

## The stick full across his way: to his right (side 1) or left (-1).
static func _across(m: PilotMotor, side: float) -> Vector2:
	var way := Vector2(m.velocity.x,m.velocity.z).normalized()
	return Vector2(-way.y,way.x)*side

func _flat_carve() -> void:
	# From 10 m/s, 0.5 s with the stick full across to his right; and as
	# far with no stick.
	var m := _carver(10.0)
	var straight := _carver(10.0)
	var turned := 0.0
	var gained := 0.0
	var facing_off := 0.0
	var way := Vector2(1.0,0.0)
	for i in range(30):
		var pace := m.speed()
		m.step(DT,_across(m,1.0),PilotMotor.RUN,false,flat,free)
		straight.step(DT,Vector2.ZERO,PilotMotor.RUN,false,flat,free)
		var now := Vector2(m.velocity.x,m.velocity.z).normalized()
		turned += way.angle_to(now)
		way = now
		gained = maxf(gained,m.speed()-pace)
		facing_off = maxf(facing_off,absf(angle_difference(m.facing,PilotMotor.facing_of(now))))
	var rate := turned/0.5
	var kept := m.speed()/straight.speed()
	var scrubbed := exp(-m.carve_scrub*absf(turned))
	print("MEASURE carving on the flat from 10 m/s, 0.5 s full across: turned %.3f rad (%.2f rad/s, CARVE_TURN %.2f), pace %.2f against %.2f straight (%.3f kept; the scrub alone %.3f), facing within %.3f rad of the way, move %s" % [turned,rate,m.carve_turn,m.speed(),straight.speed(),kept,scrubbed,facing_off,m.move])
	check(m.move == "slide" and absf(absf(rate)-m.carve_turn)/m.carve_turn < 0.02,"Held full across on the flat, the slide's way turns at CARVE_TURN (%.2f rad/s)" % rate)
	check(turned > 0.0 and m.velocity.z > 0.5,"To his right, the stick held to his right (%.2f m/s across)" % m.velocity.z)
	check(gained <= 1e-5 and kept < 1.0 and absf(kept-scrubbed) < 0.02,"His pace carried round, never gaining (%.6f m/s at most a step), less the scrub: %.3f of the straight slide's (%.3f by CARVE_SCRUB)" % [gained,kept,scrubbed])
	check(facing_off < 0.05,"He faces the way he slides (%.3f rad at most off it)" % facing_off)
	check(m.carving < -1.0,"The motor tells the figure he carves to his right (%.2f rad/s)" % m.carving)
	# To the left, the same the other way.
	var l := _carver(10.0)
	for i in range(30): l.step(DT,_across(l,-1.0),PilotMotor.RUN,false,flat,free)
	check(l.velocity.z < -0.5 and absf(l.velocity.z+m.velocity.z) < 1e-3,"Held to his left, he carves left as far (%.3f m/s across)" % l.velocity.z)
	# Half the stick across, half the turn.
	var h := _carver(10.0)
	h.step(DT,_across(h,0.5),PilotMotor.RUN,false,flat,free)
	var half := Vector2(1.0,0.0).angle_to(Vector2(h.velocity.x,h.velocity.z))/DT
	check(absf(half-h.carve_turn*0.5) < 0.02,"Half the stick across, half the turn (%.2f rad/s)" % half)

## Slow, no tighter than CARVE_RADIUS.
func _slow_carve() -> void:
	var m := _carver(3.2)
	var pace := m.speed()
	m.step(DT,_across(m,1.0),PilotMotor.RUN,false,flat,free)
	var rate := Vector2(1.0,0.0).angle_to(Vector2(m.velocity.x,m.velocity.z))/DT
	print("MEASURE carving at %.2f m/s: %.2f rad/s (its pace over CARVE_RADIUS %.2f: %.2f)" % [pace,rate,m.carve_radius,pace/m.carve_radius])
	check(absf(rate-minf(m.carve_turn,pace/m.carve_radius)) < 0.02 and rate < m.carve_turn,"At %.1f m/s it turns no tighter than CARVE_RADIUS (%.2f rad/s)" % [pace,rate])

## The stick back against his way brakes as ever, carving or not.
func _brakes() -> void:
	var ends := []
	for carve: bool in [false,true]:
		var m := _carver(10.0)
		m.carve = carve
		for i in range(30): m.step(DT,Vector2(-1.0,0.0),PilotMotor.RUN,false,flat,free)
		ends.append(m.speed())
	print("MEASURE the stick back 0.5 s from 10 m/s: %.4f m/s as it was, %.4f carving" % ends)
	check(absf(float(ends[0])-float(ends[1])) < 1e-6 and float(ends[1]) < 10.0-0.5*PilotMotor.SLIDE_BRAKE,"The stick held back brakes carving as it did (%.2f m/s)" % ends[1])

# --- On: a slope ----------------------------------------------------------------------

## Down a 30° slope (falling to +x) from a stand for `seconds`, crouched,
## the stick at `want`: his pace and way at the end.
func _surf(carve: bool, want: Vector2, seconds := 1.5) -> Dictionary:
	var slope := func(p: Vector2) -> float: return -p.x*tan(deg_to_rad(30.0))
	var m := PilotMotor.new()
	m.carve = carve
	m.reset(Vector3.ZERO,PilotMotor.facing_of(Vector2(1.0,0.0)))
	m.crouch = true
	var top := 0.0
	for i in range(int(seconds/DT)):
		m.step(DT,want,PilotMotor.RUN,false,slope,free)
		top = maxf(top,m.speed())
	var way := Vector2(m.velocity.x,m.velocity.z)
	return {"pace":m.speed(),"off":rad_to_deg(absf(Vector2(1.0,0.0).angle_to(way))),"way":way,"move":m.move,"top":top,"drop":-m.feet.y}

func _slope_carve() -> void:
	var down := _surf(true,Vector2.ZERO)
	var carved := _surf(true,Vector2(0.0,1.0))
	var pushed := _surf(false,Vector2(0.0,1.0))
	var stick_down := _surf(true,Vector2(1.0,0.0))
	for pair: Array in [["down the fall line",down],["carving across it (the stick across)",carved],["as it was, the stick across",pushed],["the stick down it",stick_down]]:
		var r: Dictionary = pair[1]
		print("MEASURE 1.5 s down 30°, %s: %.2f m/s, its way %.1f° off the fall line, %.2f m down" % [pair[0],r.pace,r.off,r.drop])
	check(down.move == "slide" and carved.move == "slide" and float(down.off) < 1.0,"On a slope he surfs down the fall line, carving on (%.1f° off it)" % down.off)
	check(float(carved.off) > 40.0 and float(carved.off) < 90.0,"The stick held across the slope carves him across it, %.0f° off the fall line" % carved.off)
	check(float(carved.way.x) > 1.0,"The fall line still pulls: his way keeps going down it (%.2f m/s down)" % carved.way.x)
	check(float(down.pace) > float(carved.pace)+1.0 and float(stick_down.pace) >= float(carved.pace),"Carving across the slope gains less (%.2f m/s) than following the fall line (%.2f m/s)" % [carved.pace,down.pace])

# --- On: chains ---------------------------------------------------------------------

## A long jump out of a carved slide on the flat leaves along the carved
## way.
func _long_jump_out() -> void:
	var m := _carver(8.0)
	for i in range(21): m.step(DT,_across(m,-1.0),PilotMotor.RUN,false,flat,free)
	var way := Vector2(m.velocity.x,m.velocity.z).normalized()
	var out := m.step(DT,_across(m,-1.0),PilotMotor.RUN,true,flat,free)
	var leaves := Vector2(m.velocity.x,m.velocity.z)
	var off := absf(way.angle_to(leaves))
	var carved := rad_to_deg(absf(Vector2(1.0,0.0).angle_to(leaves)))
	print("MEASURE long jump out of a slide carved 0.35 s left: leaves %.1f° off its first way at %.2f m/s, %.3f rad off the carved way, facing %.3f rad off it" % [carved,leaves.length(),off,absf(angle_difference(m.facing,PilotMotor.facing_of(leaves)))])
	check(out.has("long") and carved > 30.0 and off < m.carve_turn*DT+1e-3,"The long jump out of a carved slide leaves along the carved way (%.0f° round, %.3f rad off it)" % [carved,off])
	check(leaves.length() >= PilotMotor.LONG_SPEED-1e-3 and absf(angle_difference(m.facing,PilotMotor.facing_of(leaves))) < 1e-3,"At the long jump's pace, facing its way (%.2f m/s)" % leaves.length())

## Slide hops chained on each touch, the stick across his way in the air
## and through each touch (left one hop, right the next): the fastest pace
## and the hops.
func _weave(carve: bool, count := 10) -> Dictionary:
	var m := PilotMotor.new()
	m.carve = carve
	m.reset(Vector3.ZERO,PilotMotor.facing_of(Vector2(1.0,0.0)),PilotMotor.RUN)
	m.crouch = true
	m.step(DT,Vector2(1.0,0.0),PilotMotor.RUN,false,flat,free)
	var press := true
	var since := -1.0
	var side := 1.0
	var top := 0.0
	var paces := []
	var landed := 0
	for i in range(2400):
		var way := Vector2(m.velocity.x,m.velocity.z).normalized()
		var out := m.step(DT,way.rotated(side*PI*0.5),PilotMotor.RUN,press,flat,free)
		top = maxf(top,m.speed())
		if out.has("long"): paces.append(snappedf(m.speed(),0.01))
		if out.has("landed"):
			landed += 1
			side = -side
			since = 0.0
			if landed >= count: break
		elif since >= 0.0: since += DT
		press = since >= 0.0 and m.grounded and not press
		if press: since = -1.0
	return {"top":top,"paces":paces}

func _hops_chain() -> void:
	var was := _weave(false)
	var now := _weave(true)
	print("MEASURE 10 weaving slide hops, the stick across through each touch: as it was %s, top %.2f m/s; carving %s, top %.2f m/s" % [was.paces,was.top,now.paces,now.top])
	check((now.paces as Array).size() == 10 and float(now.top) > PilotMotor.LONG_TOP+0.5 and float(now.top) <= PilotMotor.HOP_TOP+0.01,"Carving, weaving slide hops still chain past LONG_TOP, to %.2f m/s (HOP_TOP %.0f)" % [now.top,PilotMotor.HOP_TOP])
	check(absf(float(now.top)-float(was.top)) < 0.5,"Carving neither adds to the chain nor costs it (%.2f against %.2f m/s)" % [now.top,was.top])

# --- The studies ----------------------------------------------------------------------

func _study() -> void:
	var study: Node3D = load("res://studies/character_study.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	var m: PilotMotor = study.motor
	check(m.carve,"The character study starts with the slide carving (the motor's default)")
	study.toggle_carve()
	check(not m.carve,"F3 turns carving off")
	study.toggle_carve()
	study._hud.visible = true
	study._show_hud()
	check(m.carve and (study._hud.text as String).contains("carve     ON"),"F3 turns carving on, and F1 shows it")
	var names: Array = study.feel_names()
	check("carve_turn" in names and "carve_radius" in names and "carve_scrub" in names,"F2 holds the carve's numbers")
	# A run carving on the runway: recorded, saved, replayed with F3 off.
	study.go_to(13)
	for i in range(10): _drive(study,Vector2.ZERO,false)
	var rec := Recording.new(m,study.station_near(m.feet),study._feel_now())
	study._rec = rec
	for i in range(240):
		var way := Vector2(m.velocity.x,m.velocity.z).normalized() if m.speed() > 0.5 else Vector2(1.0,0.0)
		var crouch := (i > 40 and i < 110) or (i > 150 and i < 220)
		_drive(study,Vector2(1.0,0.0) if not crouch else way.rotated(0.9 if i < 130 else -0.9),crouch)
	study._rec = null
	rec.label = "carved slides"
	var path: String = rec.save("user://slide_carve_test")
	var data := Recording.read(path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	study.toggle_carve()
	check(study.begin_replay(data) and m.carve,"A run made carving replays carving, F3 off")
	while study.replay_step(): pass
	var v: Dictionary = study.replay_verdict()
	study._end_replay()
	check(float(v.off) < 0.001 and not m.carve,"It ends where it did (%.5f m), and F3 is off again after" % v.off)
	# The same run with carving left out of its state, as a run from before
	# carving: replayed as it was, it goes elsewhere. So the state's carve is
	# what makes it replay.
	var state: Dictionary = str_to_var(str(data.motor))
	state.erase("carve")
	var old := data.duplicate(true)
	old.motor = var_to_str(state)
	study.toggle_carve()
	study.begin_replay(old)
	while study.replay_step(): pass
	var stray: Dictionary = study.replay_verdict()
	study._replay = {}
	print("MEASURE the carving run replayed with carving off: %.2f m from its end" % stray.off)
	check(float(stray.off) > 0.5,"Without its carve the run goes elsewhere (%.2f m off): the recording keeps it" % stray.off)
	# A run made before carving, replayed with F3 on: as it was.
	m.carve = true
	var before := Recording.read(OLD_RUN)
	check(study.begin_replay(before) and not m.carve,"A run made before carving replays as it was, F3 on")
	while study.replay_step(): pass
	var was: Dictionary = study.replay_verdict()
	study._end_replay()
	check(float(was.off) < 0.01 and m.carve,"It ends where it did (%.3f m), and carving is on again after" % was.off)
	study.queue_free()
	await process_frame

func _drive(study: Node3D, want: Vector2, crouch: bool) -> void:
	study.script_want = want
	study.script_jump = false
	study.script_crouch = crouch
	study.script_twirl = false
	study.tick(DT)

# --- The serpent ------------------------------------------------------------------------

func _serpent() -> void:
	LaunchArgs.set_override(PackedStringArray(["--carve"]))
	var ride: Node3D = load("res://studies/serpent_ride.tscn").instantiate()
	ride.scripted = true
	root.add_child(ride)
	current_scene = ride
	while not ride.walk_ready: await process_frame
	LaunchArgs.set_override(null)
	check(ride.motor.carve,"--carve starts the serpent ride carving")
	ride._hud.visible = true
	ride._show_hud()
	check((ride._hud.text as String).contains("carve     ON"),"Its F1 shows the carve")
	var bot := {"style":"heading","delay":Bot.DELAY,"wander":Bot.WANDER,"k":Bot.HEADING_K}
	var places := DIVE_PLACES
	var off := Bot.dive_slides(ride,false,bot,places,[DIVE_FROM])
	var on := Bot.dive_slides(ride,true,bot,places,[DIVE_FROM])
	print("MEASURE down the dive from %.0f m back, %s, as it was: %s" % [DIVE_FROM,Bot.describe(bot),Bot.summary(off)])
	print("MEASURE down the dive from %.0f m back, %s, carving: %s" % [DIVE_FROM,Bot.describe(bot),Bot.summary(on)])
	var held := 0
	var along := 0.0
	for s: Dictionary in on:
		if s.how == "neck": held += 1
		along += float(s.along)
	check(held == on.size(),"Carving, a bot's slide follows its spine down the dive from near its tail to its neck (%d of %d, %.0f m along its back on average)" % [held,on.size(),along/maxf(on.size(),1.0)])
	ride.queue_free()
	await process_frame
