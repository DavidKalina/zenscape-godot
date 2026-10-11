extends SceneTree
## The slide down the rune serpent's dive (studies/serpent_ride.tscn), played
## by a bot with the slide as it was and carving (scripts/pilot_motor.gd
## `carve`), headless, and measured: how far along its back toward its head
## a crouched slide follows its spine before he falls off, the falls a
## minute of sliding, how far off the spine he runs, and his pace on its
## back (the top, and the mean while sliding).
##
## Each slide: its head set down a way into the dive (DIVE_AT), him on its
## spine at an arc (START_AT), crouched from the first frame; where its back
## under him is still too level to surf, the slide starts when it tips past
## SLIDE_FROM (none in START_WAIT s: not counted). The bot steers as a
## player would, through a reaction delay (DELAY s) and a slow wander of its
## aim (WANDER degrees at most), the same with carving on and off. Its style:
##   "heading"  the stick along the spine's way where he is, turned back
##              toward the spine by how far off it he is (atan of HEADING_K
##              a metre over his pace, at most HEADING_MOST): steering by the
##              way he goes, as people mostly do;
##   "smooth"   the stick held at the spine a look ahead (LOOK s of his pace,
##              LOOK_LEAST m at least): an analog thumb chasing a point;
##   "flick"    the stick along the spine until that point is FLICK_DEAD off
##              it, then pushed FLICK_PUSH across toward it: a thumb that
##              corrects in pushes.
## A slide ends at the neck (NECK m from the snout: it held the whole way),
## fallen off (the ride's own fall: LOST_DROP under where he left), stopped
## (under 0.5 m/s a second, the slope run out), or at TIME_LIMIT s.
##   godot --headless --path . --script tools/slide_carve_bot.gd -- [--style=heading|smooth|flick] [--delay=0.2] [--wander=4] [--k=3] [--look=0.5] [--carve-turn=2.2 --carve-radius=2 --carve-scrub=0.1] [--only-on] [--verbose] [--weave=0.6]
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const DT := 1.0/60.0
## Where its head is set, m on from the dive's mark (through the dive and
## out of its bottom), and where he starts on its back (m from the snout).
const DIVE_AT := [0.0,10.0,20.0,30.0,40.0,50.0,60.0,70.0,80.0,90.0,100.0,110.0,120.0,130.0,140.0,150.0,160.0]
const START_AT := [70.0,55.0,45.0]
const NECK := 13.0
const TIME_LIMIT := 15.0
const START_WAIT := 4.0
## The bot: its reaction delay (s) and its aim's wander (degrees, at most;
## a slow random walk).
const DELAY := 0.2
const WANDER := 4.0
## Heading: the turn back toward the spine (radians by atan of this a metre
## off it over his pace) and the most (radians).
const HEADING_K := 3.0
const HEADING_MOST := 0.6
## Smooth and flick: the look ahead (s of his pace) and the least (m).
const LOOK := 0.5
const LOOK_LEAST := 3.0
## Flick: the aim's least angle off the spine's way it corrects (degrees),
## and how far across it pushes then (degrees off the spine).
const FLICK_DEAD := 6.0
const FLICK_PUSH := 60.0

var study: Node3D
var m: PilotMotor
var bot := {"style":"heading","delay":DELAY,"wander":WANDER,"k":HEADING_K,"look":LOOK}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var value := arg.get_slice("=",1)
		if arg.begins_with("--style="): bot.style = value
		elif arg.begins_with("--delay="): bot.delay = float(value)
		elif arg.begins_with("--wander="): bot.wander = float(value)
		elif arg.begins_with("--k="): bot.k = float(value)
		elif arg.begins_with("--look="): bot.look = float(value)
		elif arg == "--only-on": bot.only_on = true
		elif arg == "--verbose": bot.verbose = true
		elif arg.begins_with("--carve-"): bot[arg.get_slice("=",0).trim_prefix("--").replace("-","_")] = float(value)
	run.call_deferred()

func run() -> void:
	study = load("res://studies/serpent_ride.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	m = study.motor
	# The carve's numbers, if given: the motor's own.
	for key: String in bot:
		if key.begins_with("carve_"): m.set(key,float(bot[key]))
	print("slide carve bot: %s" % describe(bot))
	print("  carve %.2f rad/s, radius %.2f m, scrub %.2f a rad; girth %.1f, weave %.1f" % [m.carve_turn,m.carve_radius,m.carve_scrub,study.girth,study.weave])
	for carve: bool in ([true] if bot.get("only_on",false) else [false,true]):
		var r := dive_slides(study,carve,bot)
		print("RESULT carve %s: %s" % ["on " if carve else "off",summary(r)])
	quit(0)

## The bot, in a line.
static func describe(b: Dictionary) -> String:
	var how := "k %.1f" % float(b.get("k",HEADING_K)) if b.style == "heading" else "look %.2f s" % float(b.get("look",LOOK))
	return "%s (%s), delay %.2f s, wander %.0f°" % [b.style,how,float(b.delay),float(b.wander)]

## Every slide down the dive (`dive_at` by `start_at`) with carving
## `carve`, played by `b`; their results, one a slide.
static func dive_slides(ride: Node3D, carve: bool, b: Dictionary, dive_at: Array = DIVE_AT, start_at: Array = START_AT) -> Array:
	var out := []
	var n := 0
	for start: float in start_at:
		for at: float in dive_at:
			out.append(slide(ride,carve,at,start,b,n))
			n += 1
	return out

## One slide down the dive: its head `at` m on from the dive's mark, him at
## `start` m from its snout, crouched, `b` steering. Its result: how it
## ended ("neck", "fell", "stopped", "time", "flat": never started), how
## far along its back he went (m), the seconds sliding, the top and mean
## pace on its back, the root mean square of how far off the spine he ran
## (m), and where he left its back.
static func slide(ride: Node3D, carve: bool, at: float, start: float, b: Dictionary, seed_n: int) -> Dictionary:
	var serpent: Node3D = ride.serpent
	var back: RefCounted = ride.back
	var motor: PilotMotor = ride.motor
	serpent.place(fposmod(float(serpent.marks()["dive"])+at,serpent.route_length))
	back.reset()
	ride.set_on_back(start)
	motor.carve = carve
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000+seed_n
	var wander := 0.0
	var wander_most := float(b.wander)
	var queue := []
	var lag := int(roundf(float(b.delay)/DT))
	var falls: int = ride.falls
	var t := 0.0
	var began := false
	var sliding := 0.0
	var paced := 0.0
	var top := 0.0
	var still := 0.0
	var furthest := start
	var off_sq := 0.0
	var on_back := 0.0
	var how := "time"
	# Where he left its back (his last frame on it): arc, across, its half
	# width there, the slope, his pace, his way off the spine's (degrees),
	# his move, when.
	var left := {}
	var last := {}
	while t < TIME_LIMIT:
		wander = clampf(wander+rng.randf_range(-1.0,1.0)*wander_most*0.15,-wander_most,wander_most)
		queue.append(stick(ride,b).rotated(deg_to_rad(wander)))
		var want: Vector2 = queue[0] if queue.size() > lag else Vector2.ZERO
		if queue.size() > lag: queue.pop_front()
		ride.script_want = want
		ride.script_jump = false
		ride.script_crouch = true
		ride.tick(DT)
		t += DT
		if ride.falls > falls:
			how = "fell"
			break
		if not began:
			# Waiting for its back under him to tip enough to surf.
			if motor.move == "slide": began = true
			elif t > START_WAIT:
				how = "flat"
				break
			else: continue
		if motor.move == "slide":
			sliding += DT
			paced += motor.speed()*DT
		if ride.riding_on == "serpent":
			var a := float(ride.anchor.x)
			var spine: Vector3 = back.place(back.top(a))
			var way: Vector2 = back.ahead(a)
			var off := Vector2(motor.feet.x-spine.x,motor.feet.z-spine.z).dot(Vector2(-way.y,way.x))
			off_sq += off*off*DT
			on_back += DT
			top = maxf(top,motor.speed())
			furthest = minf(furthest,a)
			last = {"arc":a,"across":off,"half":float(back.half_width(a)),"slope":motor.steepness(),"pace":motor.speed(),
				"off":rad_to_deg(way.angle_to(Vector2(motor.velocity.x,motor.velocity.z))),"move":motor.move,"t":t}
			if a <= NECK:
				how = "neck"
				break
		elif left.is_empty() and not last.is_empty(): left = last
		still = still+DT if motor.speed() < 0.5 and motor.grounded else 0.0
		if still > 1.0:
			how = "stopped"
			break
	ride.script_want = Vector2.ZERO
	ride.script_crouch = false
	# A fall's fade waited out, so the next slide starts clean.
	for i in range(90):
		if not ride.fading(): break
		ride.tick(DT)
	var result := {"start":start,"at":at,"how":how,"along":start-furthest,"sliding":sliding,"top":top,"mean":paced/maxf(sliding,1e-3),
		"rms":sqrt(off_sq/maxf(on_back,1e-3)),"left":left,"t":t}
	if b.get("verbose",false):
		print("  head dive%+.0f, from %.0f m: %s after %.1f s, %.1f m along, top %.2f, mean %.2f m/s, %.2f m off the spine (rms)%s" % [at,start,how,t,start-furthest,top,result.mean,result.rms,
			"" if left.is_empty() else " · left its back at %.1f m, %+.2f across (half width %.2f), slope %.0f°, %.1f m/s, way %+.0f° off the spine, %s" % [left.arc,left.across,left.half,left.slope,left.pace,left.off,left.move]])
	return result

## The bot's stick (x, z), by its style.
static func stick(ride: Node3D, b: Dictionary) -> Vector2:
	if b.style == "heading": return heading(ride,float(b.get("k",HEADING_K)))
	var to := aim(ride,float(b.get("look",LOOK)))
	if b.style != "flick": return to
	var way: Vector2 = ride.back.ahead(float(ride.anchor.x))
	var off := way.angle_to(to)
	if absf(off) < deg_to_rad(FLICK_DEAD): return way
	return way.rotated(signf(off)*deg_to_rad(FLICK_PUSH))

## The spine's way toward its head where he is, turned back toward it by
## how far off it he is (x, z).
static func heading(ride: Node3D, k: float) -> Vector2:
	var back: RefCounted = ride.back
	var motor: PilotMotor = ride.motor
	var a: float = ride.anchor.x
	var way: Vector2 = back.ahead(a)
	var spine: Vector3 = back.place(back.top(a))
	var off := Vector2(motor.feet.x-spine.x,motor.feet.z-spine.z).dot(Vector2(-way.y,way.x))
	return way.rotated(-clampf(atan(k*off/maxf(motor.speed(),1.0)),-HEADING_MOST,HEADING_MOST))

## The way to the spine a look ahead (`look_s` of his pace) along its back
## toward its head (x, z).
static func aim(ride: Node3D, look_s: float) -> Vector2:
	var back: RefCounted = ride.back
	var motor: PilotMotor = ride.motor
	var a: float = ride.anchor.x
	var ahead := maxf(LOOK_LEAST,motor.speed()*look_s)
	var spine: Vector3 = back.place(back.top(maxf(a-ahead,float(back.first_arc())+2.0)))
	var d := Vector2(spine.x-motor.feet.x,spine.z-motor.feet.z)
	return d.normalized() if d.length() > 0.01 else back.ahead(a)

## The slides that started, summed up: how many held to the neck, fell or
## stopped; how far along its back a slide went, and the fallen ones before
## falling (m); falls a minute of sliding; the top pace, the mean of each
## slide's top and its mean pace sliding (m/s); how far off the spine (m,
## the mean of each slide's root mean square).
static func tally(slides: Array) -> Dictionary:
	var out := {"slides":0,"neck":0,"fell":0,"stopped":0,"along":0.0,"along_fell":0.0,"sliding":0.0,"top":0.0,"tops":0.0,"mean":0.0,"rms":0.0}
	for s: Dictionary in slides:
		if s.how == "flat": continue
		out.slides += 1
		out.along += float(s.along)
		out.sliding += float(s.sliding)
		out.top = maxf(out.top,float(s.top))
		out.tops += float(s.top)
		out.mean += float(s.mean)
		out.rms += float(s.rms)
		match s.how:
			"neck": out.neck += 1
			"fell":
				out.fell += 1
				out.along_fell += float(s.along)
			"stopped": out.stopped += 1
	var n := maxf(float(out.slides),1.0)
	for key: String in ["along","tops","mean","rms"]: out[key] = float(out[key])/n
	out.along_fell = float(out.along_fell)/maxf(float(out.fell),1.0)
	out.per_minute = float(out.fell)/maxf(float(out.sliding)/60.0,1e-3)
	return out

static func summary(slides: Array) -> String:
	var r := tally(slides)
	return "%d slides: %d held to the neck, %d fell, %d stopped; %.1f m along its back a slide (the fallen %.1f m before falling); %.1f falls a minute sliding (%.0f s); top %.2f m/s (each slide's top %.2f, its mean %.2f); %.2f m off the spine (rms)" % [r.slides,r.neck,r.fell,r.stopped,r.along,r.along_fell,r.per_minute,r.sliding,r.top,r.tops,r.mean,r.rms]
