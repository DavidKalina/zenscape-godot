extends SceneTree
## The string of carves down the serpent convoy (studies/serpent_ride.tscn
## with --convoy), played by a bot, headless, and measured: how many gaps
## it makes in a row, the share of its leaps that land on the next one, its
## pace on the backs (each leap's take-off and landing, each string's
## peak), and its falls.
##
## A session: the line set at the top of a descent (the ride's
## `to_descent`), him on the last one's back, crouched and carving with
## carving on (scripts/pilot_motor.gd `carve`). The bot steers down each
## back toward its head as the slide carve bot's "heading" thumb
## (tools/slide_carve_bot.gd `heading`), through a reaction delay (DELAY s)
## and a slow wander of its aim (WANDER degrees at most). Within JUMP_AT m
## of the snout (give or take JUMP_JITTER) it presses Jump (held JUMP_HOLD
## s), crouch still held: on its back's slope that's the slide jump (the
## long jump where it's under 10°). In the air it points the stick at the
## next one's spine AIM_AT m back from its snout (the motor's slide hop
## turns him to it), and twirls past the top of the leap when it would
## otherwise come down short of the next one's tail (`--twirl=auto`;
## `never`, `always`). It lands crouched, so it slides on, and carves on.
## A fall sets it back as the ride does (the last gap again); the string
## starts again. On the lead (nothing ahead), or where the back under him
## no longer runs downhill (the descent's foot), the line is set at the
## next descent's top and a new string begins.
##   godot --headless --path . --script tools/serpent_convoy_bot.gd -- [--gap=4] [--descent=15] [--convoy=5] [--jump-at=4] [--aim-at=80] [--twirl=auto|never|always] [--delay=0.2] [--wander=4] [--seconds=300] [--weave=1] [--verbose]
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const Carve = preload("res://tools/slide_carve_bot.gd")
const DT := 1.0/60.0
## Where it leaps (m from the snout), give or take (m, evenly).
const JUMP_AT := 4.0
const JUMP_JITTER := 1.0
## How long it holds Jump (s): past the slide jump's rise, so it isn't cut.
const JUMP_HOLD := 0.3
## In the air it steers for the next one's spine this far back from its
## snout (m), or AIM_LEAD m on along it from over where he is, once he is
## past that; it twirls if it would come down more than TWIRL_SHORT m short
## of the next one's back SAFE_AT m from its snout (where its back is about
## a metre across, shoulders and all).
const AIM_AT := 80.0
const AIM_LEAD := 6.0
const TWIRL_SHORT := 0.5
const SAFE_AT := 84.0
## Its reaction delay (s), its aim's wander (degrees, at most) and the
## heading thumb's turn back to the spine (as the slide carve bot's).
const DELAY := 0.2
const WANDER := 4.0
const HEADING_K := 3.0
## A string ends where the way under him climbs or levels: steeper than
## this (degrees, down toward the head) and it carves on.
const STILL_DOWN := 5.0
const SESSION := 300.0

var bot := {"jump_at":JUMP_AT,"jitter":JUMP_JITTER,"aim_at":AIM_AT,"twirl":"always","delay":DELAY,"wander":WANDER,"k":HEADING_K,"seconds":SESSION,"convoy":5}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var value := arg.get_slice("=",1)
		if arg.begins_with("--jump-at="): bot.jump_at = float(value)
		elif arg.begins_with("--jitter="): bot.jitter = float(value)
		elif arg.begins_with("--aim-at="): bot.aim_at = float(value)
		elif arg.begins_with("--twirl="): bot.twirl = value
		elif arg.begins_with("--delay="): bot.delay = float(value)
		elif arg.begins_with("--wander="): bot.wander = float(value)
		elif arg.begins_with("--k="): bot.k = float(value)
		elif arg.begins_with("--seconds="): bot.seconds = float(value)
		elif arg.begins_with("--convoy="): bot.convoy = int(value)
		elif arg == "--verbose": bot.verbose = true
		elif arg == "--trace": bot.trace = true
		elif arg.begins_with("--seed="): bot.seed = int(value)
	run.call_deferred()

func run() -> void:
	var study: Node3D = load("res://studies/serpent_ride.tscn").instantiate()
	study.scripted = true
	study.convoy = int(bot.convoy)
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	print("serpent convoy bot: %s" % describe(bot))
	print("  %d serpents, gap %.1f m, descents %.0f°, weave %.1f, girth %.1f; carve %.2f rad/s" % [study.serpents.size(),study.gap,study.descent,study.weave,study.girth,study.motor.carve_turn])
	var r := session(study,bot,float(bot.seconds))
	print("RESULT %s" % summary(r))
	if bot.get("verbose",false): print("  strings %s" % str(r.strings))
	quit(0)

static func describe(b: Dictionary) -> String:
	return "leap at %.1f±%.1f m, aim %.0f m, twirl %s, delay %.2f s, wander %.0f°, k %.1f" % [float(b.jump_at),float(b.jitter),float(b.aim_at),b.twirl,float(b.delay),float(b.wander),float(b.k)]

## The bot plays `seconds` of strings down the line; its tally.
static func session(ride: Node3D, b: Dictionary, seconds: float, start := "a") -> Dictionary:
	var motor: PilotMotor = ride.motor
	motor.carve = true
	ride.to_descent(start)
	var r := {"seconds":0.0,"leaps":0,"landed":0,"short":0,"missed":0,"falls":0,"strings":[],"peak":0.0,"peak_ground":0.0,
		"took":0.0,"landed_pace":0.0,"gain":[],"land_arc":0.0,"land_across":0.0,"restarts":0,"leap_log":[]}
	var rng := RandomNumberGenerator.new()
	rng.seed = int(b.get("seed",4242))
	var wander := 0.0
	var queue: Array[Vector2] = []
	var lag := int(roundf(float(b.delay)/DT))
	var jump_at := float(b.jump_at)+rng.randf_range(-1.0,1.0)*float(b.jitter)
	var hold := 0.0
	var leap := {}
	var twirled := false
	var string_most := 0
	var falls: int = ride.falls
	var t := 0.0
	while t < seconds:
		var on: int = ride.on_k
		var want := Vector2.ZERO
		var twirl := false
		var press := false
		if ride.fading() and ride.riding_on != "serpent":
			queue.clear()
		elif ride.riding_on == "serpent" and leap.is_empty():
			# Nowhere on to go: the next descent's top, a new string.
			if (on == 0 and float(ride.anchor.x) <= jump_at+2.0) or downhill(ride) < STILL_DOWN:
				if b.get("verbose",false): print("  restart at %.1f s on %d at %.1f m (downhill %.1f°)" % [t,on+1,float(ride.anchor.x),downhill(ride)])
				r.strings.append(string_most)
				string_most = 0
				r.restarts += 1
				ride.to_descent(ride.descent_to_start())
				queue.clear()
				continue
			want = Carve.heading(ride,float(b.k))
			if on > 0 and float(ride.anchor.x) <= jump_at:
				press = true
				hold = float(JUMP_HOLD)
				leap = {"from":on,"to":on-1,"pace":motor.speed(),"t":t}
				twirled = false
				jump_at = float(b.jump_at)+rng.randf_range(-1.0,1.0)*float(b.jitter)
		elif ride.riding_on == "air" and not leap.is_empty():
			var to: int = leap.to
			var over: float = ride.backs[to].locate(motor.feet).x
			var aim: Vector3 = ride.backs[to].place(ride.backs[to].top(minf(float(b.aim_at),over-AIM_LEAD)))
			var d := Vector2(aim.x-motor.feet.x,aim.z-motor.feet.z)
			want = d.normalized() if d.length() > 0.1 else Vector2.ZERO
			if not twirled and motor.velocity.y <= 0.0 and b.twirl != "never":
				twirled = true
				twirl = b.twirl == "always" or short_of(ride,to) > TWIRL_SHORT
				leap["twirl"] = twirl
		# The thumb: late by its delay, its aim wandering.
		wander = clampf(wander+rng.randf_range(-1.0,1.0)*float(b.wander)*0.15,-float(b.wander),float(b.wander))
		queue.append(want.rotated(deg_to_rad(wander)))
		var stick: Vector2 = queue[0] if queue.size() > lag else Vector2.ZERO
		if queue.size() > lag: queue.pop_front()
		ride.script_want = stick
		ride.script_jump = press or hold > 0.0
		ride.script_crouch = true
		ride.script_twirl = twirl
		hold = maxf(hold-DT,0.0)
		ride.tick(DT)
		t += DT
		if b.get("trace",false) and int(t/DT)%3 == 0: print("    t %.2f %s k%d arc %.1f %+.2f %s pace %.2f vy %.2f slope %.0f stick %s jump %s fade %s drop %.2f" % [t,ride.riding_on,ride.on_k+1,ride.anchor.x,ride.anchor.y,motor.move,motor.speed(),motor.velocity.y,motor.steepness(),str(stick.snapped(Vector2.ONE*0.01)),ride.script_jump,ride.fading(),ride._air_ref-motor.feet.y])
		r.peak = maxf(r.peak,motor.speed())
		var over: Vector3 = ride.ground_velocity()
		r.peak_ground = maxf(r.peak_ground,Vector2(over.x,over.z).length())
		if b.get("verbose",false) and int(ride.string) > string_most: print("    string %d at %.2f s: on %d, last gap %s" % [ride.string,t,ride.on_k+1,str(ride.last_gap)])
		string_most = maxi(string_most,int(ride.string))
		# The leap's end: down on a back, or fallen.
		if not leap.is_empty():
			if ride.falls > falls:
				leap["how"] = "missed"
				r.missed += 1
			elif ride.riding_on == "serpent" and float(t)-float(leap.t) > 0.1:
				if ride.on_k == int(leap.to):
					leap["how"] = "landed"
					r.landed += 1
					r.took += float(leap.pace)
					r.landed_pace += motor.speed()
					r.gain.append(motor.speed()-float(leap.pace))
					r.land_arc += float(ride.anchor.x)
					r.land_across += absf(float(ride.anchor.y))
					leap["arc"] = float(ride.anchor.x)
					leap["across"] = float(ride.anchor.y)
					leap["landed_pace"] = motor.speed()
				else:
					leap["how"] = "short" if ride.on_k == int(leap.from) else "other"
					r.short += 1
			if leap.has("how"):
				r.leaps += 1
				r.leap_log.append(leap)
				if b.get("verbose",false): print("  leap %d→%d %s · pace %.2f%s%s" % [int(leap.from)+1,int(leap.to)+1,leap.how,float(leap.pace),
					" → %.2f, landed %.1f m from its snout %+.2f across" % [float(leap.landed_pace),float(leap.arc),float(leap.across)] if leap.how == "landed" else "",
					" (twirled)" if leap.get("twirl",false) else ""])
				leap = {}
		if ride.falls > falls:
			if b.get("verbose",false): print("  fall at %.1f s off %d, %s" % [t,ride.on_k+1,"leaping" if not leap.is_empty() else "carving"])
			r.falls += ride.falls-falls
			falls = ride.falls
			r.strings.append(string_most)
			string_most = 0
	r.strings.append(string_most)
	r.seconds = t
	ride.script_want = Vector2.ZERO
	ride.script_jump = false
	ride.script_crouch = false
	ride.script_twirl = false
	return r

## How steeply the way runs downhill toward the head of the one he is on,
## where he is (degrees; less than 0 uphill).
static func downhill(ride: Node3D) -> float:
	var at: float = ride._arc_on(float(ride.serpent.s),-float(ride.anchor.x))
	var d: Vector3 = ride.serpent.route_point(at+3.0)-ride.serpent.route_point(at-3.0)
	return -rad_to_deg(atan2(d.y,Vector2(d.x,d.z).length()))

## How far short (m) of serpent `to`'s back at SAFE_AT he would come down
## from here falling as the motor does, flat along his way (less than 0: past
## it).
static func short_of(ride: Node3D, to: int) -> float:
	var motor: PilotMotor = ride.motor
	var safe: Vector3 = ride.backs[to].place(ride.backs[to].top(SAFE_AT))
	var h := Vector2(motor.velocity.x,motor.velocity.z)
	if h.length() < 0.1: return INF
	var way := h.normalized()
	var ahead := Vector2(safe.x-motor.feet.x,safe.z-motor.feet.z).dot(way)
	var drop := maxf(motor.feet.y-safe.y,0.0)
	var fall := sqrt(2.0*drop/(motor.gravity*motor.fall))
	return ahead-h.length()*fall

## The tally in a line.
static func summary(r: Dictionary) -> String:
	var strings: Array = r.strings
	var best := 0
	var three := 0
	var total := 0
	for n: int in strings:
		best = maxi(best,n)
		total += n
		if n >= 3: three += 1
	var landed := maxf(float(r.landed),1.0)
	var gains: Array = r.gain
	var held := 0
	for g: float in gains: if g >= -0.5: held += 1
	return "%.0f s: %d leaps, %d landed on the next (%.0f%%), %d short, %d missed; %d falls (%.1f a minute); %d strings, best %d in a row, %d of 3+, mean %.1f; pace on its back: took off %.2f, landed %.2f m/s (held within 0.5 in %d of %d), peak %.2f (over the ground %.2f); landed %.1f m from the snout, %.2f m off the spine" % [
		r.seconds,r.leaps,r.landed,100.0*float(r.landed)/maxf(float(r.leaps),1.0),r.short,r.missed,r.falls,float(r.falls)/maxf(float(r.seconds)/60.0,1e-3),
		strings.size(),best,three,float(total)/maxf(float(strings.size()),1.0),float(r.took)/landed,float(r.landed_pace)/landed,held,gains.size(),r.peak,r.peak_ground,float(r.land_arc)/landed,float(r.land_across)/landed]
