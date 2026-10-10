extends RefCounted
## Crash and restart for the flight study (scripts/flight_run.gd), an opt-in
## layer round bump-and-recover (scripts/ruin_bump.gd, untouched): RuinBump
## still bumps the plane out of stone every tick; with a crash mode on, the
## run then looks at that contact (`contact`: which solid, its face, how fast
## the plane was going into it) and decides (`crashes`) whether it was a
## crash. A crash puts the plane back at a restart point (FlightRun `_crash`)
## at cruise, along the line, after a short hold (HOLD) for the study's
## crash to read.
##
## Modes (--crash=..., the study's C key):
##   off   bump and recover only, as before (the default: every number as it was)
##   hard  each solid's crash class decides (CLASSES): scenery stone crashes
##         when the plane's speed into its face is at least its `hard` m/s;
##         glancing scrapes and skims bump and recover as before
##   any   every contact crashes (a debug mode)
##
## Per-solid crash classes: a solid (FlightCourse `solids`) may carry
## "crash": <class>; FlightCourse `build` puts it on the body as meta
## CLASS_META ("stone" when absent), and `contact` reads it back. A class is
## {"hard": m/s}: 0 crashes on any contact. Every solid today is "stone".
## "obstacle" is a placeholder for later obstacles (crash on any touch):
## tagging new solids with it is all they need.
##
## Restart points (--restart=..., the study's T key):
##   checkpoint  the last safe point of the station's line BACK s behind the
##               crash (a point at least SAFE m clear of stone, not just
##               before a knife slit); a challenge carries on
##   ring        a challenge on: at the starter, the challenge started
##               afresh (a new try); no challenge on: as checkpoint
##   entry       the station's entry; a challenge on ends ("crash") and the
##               starter stands again
## Free collectibles taken stay taken whatever the restart.

const PlaneFigure = preload("res://scripts/plane_figure.gd")
const RuinBump = preload("res://scripts/ruin_bump.gd")

const MODES := ["off","hard","any"]
const RESTARTS := ["checkpoint","ring","entry"]
const CLASS_META := &"crash_class"
## Speed into a face (m/s) at or over which scenery stone crashes. Cruise is
## 14 m/s, boost 22: at cruise this is a hit at more than about 35 degrees
## to the face, at boost more than about 22 (tools/flight_crash_tune.gd).
const HARD := 8.0
const CLASSES := {
	"stone":{"hard":HARD},
	"obstacle":{"hard":0.0},
}
## The run waits this long (s) after a crash (the study's crash plays), then
## the plane flies on from the restart point.
const HOLD := 0.7
## After a restart, contacts this long (s) only bump.
const GRACE := 0.3
## Checkpoint: this long (s, at cruise) back along the line from the crash,
## then on back to a point SAFE m clear of stone with no knife slit within
## SLIT_AHEAD s ahead.
const BACK := 2.0
const SAFE := 2.0
const SLIT_AHEAD := 1.0

static var _query: PhysicsShapeQueryParameters3D

## Crash rules from loose settings ({mode, restart, hard}); {} for off (or
## an unknown mode), which leaves a run exactly as it was.
static func rules(given: Dictionary) -> Dictionary:
	var mode := str(given.get("mode","off"))
	if mode == "off" or not mode in MODES: return {}
	var restart := str(given.get("restart","checkpoint"))
	if not restart in RESTARTS: restart = "checkpoint"
	var out := {"mode":mode,"restart":restart}
	if given.has("hard") and float(given.hard) > 0.0: out["hard"] = float(given.hard)
	return out

## The record's tag for rules `r` ("" for off): "crash-hard-checkpoint", and
## the stone threshold when it isn't HARD ("crash-hard@6-checkpoint").
static func tag(r: Dictionary) -> String:
	if r.is_empty(): return ""
	var mode := str(r.mode)
	if r.has("hard") and not is_equal_approx(float(r.hard),HARD) and mode == "hard": mode += "@%s" % str(snappedf(float(r.hard),0.1))
	return "crash-%s-%s" % [mode,str(r.restart)]

## Crash class `name`'s threshold (m/s into the face) under rules `r`.
static func threshold(r: Dictionary, name: String) -> float:
	var cls: Dictionary = CLASSES.get(name,CLASSES.stone)
	var hard := float(cls.hard)
	# --crash-speed tunes scenery stone (and any class as hard as it).
	if name == "stone" and r.has("hard"): hard = float(r.hard)
	return hard

## Is contact `hit` ({into, class}) a crash under rules `r`?
static func crashes(r: Dictionary, hit: Dictionary) -> bool:
	if r.is_empty(): return false
	if str(r.mode) == "any": return true
	return float(hit.get("into",0.0)) >= threshold(r,str(hit.get("class","stone")))

## The plane's pose before the bump, for `contact`.
static func pose(plane: RefCounted) -> Dictionary:
	return {"position":plane.position,"heading":float(plane.heading),"pitch":float(plane.pitch),
		"roll":float(plane.bank)+float(plane.get("spin") if plane.get("spin") != null else 0.0),"velocity":plane.velocity}

## The contact the plane in pose `pre` (the run's own frame is the world's)
## makes with stone on RuinBump's layer: {normal (out of the face), into
## (m/s, the speed into the face), class (the solid's crash class)}; {} if
## none (the bump came from elsewhere). `was` (where it was a tick before)
## gives the normal if the shape query can't.
static func contact(space: PhysicsDirectSpaceState3D, pre: Dictionary, was: Vector3) -> Dictionary:
	if space == null: return {}
	if _query == null:
		_query = PhysicsShapeQueryParameters3D.new()
		var box := BoxShape3D.new()
		box.size = RuinBump.BODY
		_query.shape = box
		_query.collision_mask = RuinBump.LAYER
	_query.transform = Transform3D(PlaneFigure.pose(Vector3.ZERO,float(pre.heading),float(pre.pitch),float(pre.roll)).basis,pre.position)
	var rest := space.get_rest_info(_query)
	if rest.is_empty(): return {}
	var normal: Vector3 = rest.get("normal",Vector3.ZERO)
	if normal.length() < 0.5: normal = (was-(pre.position as Vector3)).normalized()
	var into := maxf(0.0,-(pre.velocity as Vector3).dot(normal))
	var cls := "stone"
	var body := instance_from_id(int(rest.get("collider_id",0)))
	if body is Node and (body as Node).has_meta(CLASS_META): cls = str((body as Node).get_meta(CLASS_META))
	return {"normal":normal,"into":into,"class":cls,"point":rest.get("point",pre.position)}
