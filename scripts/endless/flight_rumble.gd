extends RefCounted
## The pad's rumble in flight (scripts/pad.gd `pulse`; nothing while the
## keyboard and mouse are in hand, or with vibration off). A knock for what
## the wheels meet (scripts/manual_landing.gd `step`'s events): a greaser a
## soft tap, a touch that sticks firmer, a thump by how hard, a bounce, a
## slide breaking loose, a hit. Under the knocks a running hum: the wheels
## on the land by the ground speed and their grit, Boost, a hard pull (the
## wingtip vapour's own pull) and skimming the land low and fast.

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
## "boost", "pull" and "skim" (0 to 1 each).
func step(delta: float, events: Dictionary, hum: Dictionary) -> void:
	var knocked := _knocks(events)
	_knock_left = maxf(_knock_left-delta,0.0)
	var fade := _knock_left/_knock_for if _knock_for > 0.0 else 0.0
	var weak := ROLL*clampf(float(hum.get("roll",0.0))/ROLL_FAST,0.0,1.0)
	if weak > 0.0: weak += ROLL_GRIT*float(hum.get("grit",0.0))
	weak = maxf(weak,BOOST*float(hum.get("boost",0.0)))
	weak = maxf(weak,PULL*float(hum.get("pull",0.0)))
	weak = maxf(weak,SKIM*float(hum.get("skim",0.0)))
	var strong := PULL_STRONG*float(hum.get("pull",0.0))
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
	var ringing := _knock*(_knock_left/_knock_for if _knock_for > 0.0 else 0.0)
	if best.z <= 0.0 or best.x+best.y <= ringing.x+ringing.y: return false
	_knock = Vector2(best.x,best.y)
	_knock_for = best.z
	_knock_left = best.z
	return true

static func _top(a: Vector3, b: Vector3) -> Vector3:
	return b if b.x+b.y > a.x+a.y else a
