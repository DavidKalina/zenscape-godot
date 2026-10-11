extends RefCounted
## The hand landing's words (scripts/manual_landing.gd), shared by the
## landing study (studies/landing_study.gd: its F1 overlay and its words)
## and the kit isles (studies/kit_isle.gd: the flying hint and F1): what a
## touch now would get, why a touch hopped, and the live numbers against
## the limits, so both read the same. docs/design/manual-landing.md
## (round 3).
##
## The touch's word leads the hint only low over the land (under NEAR m),
## where it is a pilot's last look before the wheels; higher up the dive
## is still a choice, not an outcome.

const ManualLanding = preload("res://scripts/manual_landing.gd")

## How low (m over the land) the hint says what a touch now would get.
const NEAR := 8.0
## Why a touch hopped, by its reason (ManualLanding `bounce`).
const HOP_WHY := {"tumble":"mid roll","rough":"ground too steep","slam":"too steep a dive, so pull up and come round"}
## A touch now, by its grade (ManualLanding `grade_now`): the overlay's
## words and the hint's.
const TOUCH_NOW := {"greaser":"a GREASER","firm":"firm","hot":"HOT: it sticks, drift it","hard":"HARD: it sticks",
	"wingtip":"on a WINGTIP: it sticks","tumble":"a HOP (mid roll)","rough":"a HOP (too steep ground)","slam":"a BOUNCE (too steep a dive: pull up)"}
const HINT_NOW := {"greaser":"Touch now: a greaser","firm":"Touch now: firm","hot":"Touch now: hot, it sticks, then drift it to a stop",
	"hard":"Touch now: hard, it sticks","wingtip":"Touch now: on a wingtip, it sticks","tumble":"Touch now: mid roll, it hops",
	"rough":"Touch now: ground too steep, it hops","slam":"Too steep: it will bounce. Ease the nose up"}

## Why a hop, in words ("Hopped: ..." in the hint).
static func hop_word(reason: String) -> String:
	return str(HOP_WHY.get(reason,reason))

## What a touch of `grade` now would get, for an overlay.
static func touch_now(grade: String) -> String:
	return str(TOUCH_NOW.get(grade,grade))

## The hint's line for a touch of `grade` now, `over` m over the land ("" too
## high, or no grade).
static func hint_now(grade: String, over: float) -> String:
	if grade == "" or is_nan(over) or over > NEAR: return ""
	return str(HINT_NOW.get(grade,""))

## The live numbers in the air: the dive remembered against the slam's
## limits (degrees nose down, sink down its line), and the sink remembered.
static func dive_line(ml: RefCounted) -> String:
	return "dive %.0f° (slam over %.0f°) · down the dive %.1f m/s (slam over %.0f) · sink %.2f m/s" % [rad_to_deg(float(ml.dive)),
		rad_to_deg(ManualLanding.SLAM_ANGLE),float(ml.dive_sink),ManualLanding.SLAM_SINK,float(ml.sink_seen)]

## The live numbers on the wheels: gripping, sliding (and its side and
## line), power-sliding or backing up, the slip and the grit.
static func wheels_line(ml: RefCounted) -> String:
	var how := "gripping"
	if ml.reversing: how = "BACKING UP"
	elif ml.power: how = "POWER-SLIDE"
	elif ml.sliding: how = "sliding"
	if ml.sliding: how += " (nose %s)" % ("left" if float(ml.drift_side) > 0.0 else "right")
	return "%s · %.1f m/s · slip %.0f° · grit %.2f" % [how,ml.roll_speed(),rad_to_deg(absf(float(ml.slip))),float(ml.grit)]
