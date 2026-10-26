extends RefCounted
## The pad's rumble in flight (scripts/pad.gd `pulse`; nothing while the
## keyboard and mouse are in hand, or with vibration off). A knock for what
## the wheels meet (scripts/manual_landing.gd `step`'s events): a greaser a
## soft tap, a touch that sticks firmer, a thump by how hard, a bounce, a
## slide breaking loose, a hit. Under the knocks a running hum: the wheels
## on the land by the ground speed and their grit, Boost, a hard pull (the
## wingtip vapour's own pull) and skimming the land low and fast. With
## weight (scripts/flight_weight.gd) a strain hum by the load, and a heavy
## thrum sinking through the bottom of a hard pull-out. Near the land
## (scripts/endless/near_miss.gd, flight_contact.gd): a pulse on a scored
## moment by its closeness, a gritty knock on a scrape, the hardest on a
## crash, and a buffet hum low and fast.

const Pad = preload("res://scripts/pad.gd")

## The knocks: weak motor, strong motor, seconds. A thump adds THUMP_MORE
## times its `k` (0 to 1).
const GREASER := Vector3(0.2,0.0,0.1)
const TOUCH := Vector3(0.35,0.2,0.14)
const THUMP := Vector3(0.45,0.5,0.2)
const THUMP_MORE := Vector3(0.35,0.5,0.15)
const BOUNCE := Vector3(0.4,0.45,0.16)
const SLIDE := Vector3(0.3,0.15,0.3)
const HIT := Vector3(0.7,1.0,0.35)
## Sinking through a pull-out (`events` "sink", its `k` 0 to 1): mostly the
## strong motor, low and long, SINK_MORE more at a full `k`.
const SINK := Vector3(0.15,0.35,0.35)
const SINK_MORE := Vector3(0.15,0.4,0.15)
## A scored near miss (`events` "near", its `k` 0 to 1, closeness): a
## short sharp pulse, NEAR_MORE more at a full `k`. A scrape (its `k`, how
## hard it went in) and a crash.
const NEAR := Vector3(0.25,0.1,0.1)
const NEAR_MORE := Vector3(0.45,0.35,0.06)
const SCRAPE := Vector3(0.55,0.55,0.28)
const SCRAPE_MORE := Vector3(0.3,0.4,0.1)
const CRASH := Vector3(0.9,1.0,0.5)
## A tree knocked down (`events` "knock", its `heft` 0 to 1).
const KNOCK := Vector3(0.45,0.4,0.22)
const KNOCK_MORE := Vector3(0.25,0.35,0.08)
## The buffet low and fast (`step`'s `low`, 0 to 1): weak and strong.
const LOW := 0.2
const LOW_STRONG := 0.08
## The hum's weak motor: on the wheels at ROLL_FAST m/s and more (and
## ROLL_GRIT more with their grit), at Boost, at a full pull, and skimming
## low (`step`'s `skim`, 0 to 1); the strong motor's share of it on the
## wheels and at a full pull.
const ROLL := 0.32
const ROLL_STRONG := 0.12
const ROLL_FAST := 12.0
const ROLL_GRIT := 0.15
const BOOST := 0.16
const PULL := 0.3
const PULL_STRONG := 0.12
const SKIM := 0.24
## The strain hum at a full `strain` (0 to 1, the load): weak and strong.
const STRAIN := 0.26
const STRAIN_STRONG := 0.16
## The hum under this on both motors is nothing.
const QUIET := 0.03
## Seconds between settings of the motors; each lasts twice that.
const EVERY := 0.06

var _knock := Vector2.ZERO
var _knock_for := 0.0
var _knock_left := 0.0
var _clock := 0.0

## One frame: `events` what the landing's step returned, `hum` its running
## parts: "roll" (m/s over the ground, 0 in the air), "grit" (0 to 1),
## "boost", "pull", "skim", "strain" and "low" (0 to 1 each).
func step(delta: float, events: Dictionary, hum: Dictionary) -> void:
	var knocked := _knocks(events)
	_knock_left = maxf(_knock_left-delta,0.0)
	var fade := _knock_left/_knock_for if _knock_for > 0.0 else 0.0
	var weak := ROLL*clampf(float(hum.get("roll",0.0))/ROLL_FAST,0.0,1.0)
	if weak > 0.0: weak += ROLL_GRIT*float(hum.get("grit",0.0))
	weak = maxf(weak,BOOST*float(hum.get("boost",0.0)))
	weak = maxf(weak,PULL*float(hum.get("pull",0.0)))
	weak = maxf(weak,SKIM*float(hum.get("skim",0.0)))
	var strain := clampf(float(hum.get("strain",0.0)),0.0,1.0)
	weak = maxf(weak,STRAIN*strain)
	var low := clampf(float(hum.get("low",0.0)),0.0,1.0)
	weak = maxf(weak,LOW*low)
	var strong := PULL_STRONG*float(hum.get("pull",0.0))
	strong = maxf(strong,STRAIN_STRONG*strain*strain)
	strong = maxf(strong,LOW_STRONG*low)
	strong = maxf(strong,ROLL_STRONG*clampf(float(hum.get("roll",0.0))/ROLL_FAST,0.0,1.0))
	if weak < QUIET and strong < QUIET:
		weak = 0.0
		strong = 0.0
	weak = maxf(weak,_knock.x*fade)
	strong = maxf(strong,_knock.y*fade)
	_clock += delta
	if not knocked and _clock < EVERY: return
	_clock = 0.0
	if weak > 0.0 or strong > 0.0: Pad.pulse(clampf(weak,0.0,1.0),clampf(strong,0.0,1.0),EVERY*2.0)

## A knock from outside the landing (the rival race's beats): `v` weak
## motor, strong motor, seconds; taken if it beats what is still ringing,
## and set on the motors at the next step.
func knock(v: Vector3) -> void:
	var ringing := _knock*(_knock_left/_knock_for if _knock_for > 0.0 else 0.0)
	if v.z <= 0.0 or v.x+v.y <= ringing.x+ringing.y: return
	_knock = Vector2(v.x,v.y)
	_knock_for = v.z
	_knock_left = v.z
	_clock = EVERY

## Takes the strongest knock in `events`, if it beats what is still
## ringing; true if one did.
func _knocks(events: Dictionary) -> bool:
	var best := Vector3.ZERO
	if events.has("greaser"): best = _top(best,GREASER)
	elif events.has("settled"): best = _top(best,TOUCH)
	var thump: Variant = events.get("thump")
	if thump is Dictionary: best = _top(best,THUMP+THUMP_MORE*clampf(float((thump as Dictionary).get("k",0.0)),0.0,1.0))
	if events.has("bounce"): best = _top(best,BOUNCE)
	if events.has("slide"): best = _top(best,SLIDE)
	if events.has("hit"): best = _top(best,HIT)
	var sink: Variant = events.get("sink")
	if sink is Dictionary: best = _top(best,SINK+SINK_MORE*clampf(float((sink as Dictionary).get("k",0.0)),0.0,1.0))
	var near: Variant = events.get("near")
	if near is Dictionary: best = _top(best,NEAR+NEAR_MORE*clampf(float((near as Dictionary).get("k",0.0)),0.0,1.0))
	var scrape: Variant = events.get("scrape")
	if scrape is Dictionary: best = _top(best,SCRAPE+SCRAPE_MORE*clampf(float((scrape as Dictionary).get("into",0.0))/7.0,0.0,1.0))
	var knock: Variant = events.get("knock")
	if knock is Dictionary: best = _top(best,KNOCK+KNOCK_MORE*clampf(float((knock as Dictionary).get("heft",0.0)),0.0,1.0))
	if events.has("crash"): best = _top(best,CRASH)
	var ringing := _knock*(_knock_left/_knock_for if _knock_for > 0.0 else 0.0)
	if best.z <= 0.0 or best.x+best.y <= ringing.x+ringing.y: return false
	_knock = Vector2(best.x,best.y)
	_knock_for = best.z
	_knock_left = best.z
	return true

static func _top(a: Vector3, b: Vector3) -> Vector3:
	return b if b.x+b.y > a.x+a.y else a
