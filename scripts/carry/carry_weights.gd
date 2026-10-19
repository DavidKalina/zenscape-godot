extends RefCounted
## What a carried treasure's weight does to the wanderer (docs/design/carry/
## spec-carry.md): one table to tune. Each class scales the motor's own
## feel (scripts/pilot_motor.gd's live knobs, read when he lifts it and put
## back when he lets go) and says which moves the load forbids.
##
##   walk, run   his paces, times the empty-handed ones
##   jump        his jump heights (both of the chain's), times
##   turn        how fast he turns on the ground, times
##   lift        the heave's length (s): the reach down, the strain, the
##               heave and its settle (setting down takes 0.8 of it)
##   hold        where it rides: "chest" (both hands before him) or "hug"
##               (hugged low against his belly, hands under it)
##   squat       how low he crouches to it (m his hips drop, times size)
##   bend        how far he bends over to it (degrees, at the chest)
##   strain      the hold at the bottom before the heave (of the lift)
##   sag         his knees' bend carrying it (m his hips stay down, x size)
##   lean        his lean back against it carrying (degrees, at the chest;
##               it overshoots once as the heave settles)
##   settle      the squash as it comes up into his hands (as a landing
##               this hard, m/s; scripts/pilot_figure.gd `land`)
##   waddle      his chest's roll from side to side at each footfall (deg)
##   bars        the moves the load forbids (the motor's gates, refused
##               with a stagger and a shake of the head): "wall" (wall
##               slide, kick and run), "ledge" (grabs, hangs, the climb),
##               "sail", "rope" (the swing ropes)
##   sway        the camera's lurch at each footfall (degrees of roll; 0
##               none), and its dip (m, times his size)
##   thud        a heavy footfall under each step (gain, 0 none)
##   mass        its body's mass when it tumbles loose (kg)
##   spill       how far a knock throws it: his velocity at the blow,
##               times (the heavy one drops nearly at his feet)

const CLASSES := {
	"light":{"walk":0.9,"run":0.85,"jump":0.85,"turn":0.9,"lift":0.6,"hold":"chest",
		"squat":0.15,"bend":38.0,"strain":0.03,"sag":0.0,"lean":4.0,"settle":3.0,"waddle":0.0,
		"bars":[],"sway":0.0,"dip":0.0,"thud":0.0,"mass":2.0,"spill":0.8},
	"medium":{"walk":0.75,"run":0.65,"jump":0.6,"turn":0.75,"lift":0.95,"hold":"chest",
		"squat":0.19,"bend":42.0,"strain":0.12,"sag":0.025,"lean":9.0,"settle":6.0,"waddle":1.5,
		"bars":["wall"],"sway":0.0,"dip":0.0,"thud":0.05,"mass":6.0,"spill":0.55},
	"heavy":{"walk":0.55,"run":0.4,"jump":0.3,"turn":0.5,"lift":1.45,"hold":"hug",
		"squat":0.24,"bend":46.0,"strain":0.22,"sag":0.06,"lean":15.0,"settle":11.0,"waddle":5.0,
		"bars":["wall","ledge","sail","rope"],"sway":1.4,"dip":0.06,"thud":0.16,"mass":15.0,"spill":0.3},
}
## The refusal: seconds of it, the head's shakes in it and their swing
## (degrees), the body's lurch (degrees of lean at the chest) and the pace
## kept meanwhile (times the carrying pace).
const BALK_TIME := 0.7
const BALK_SHAKES := 2.5
const BALK_HEAD := 28.0
const BALK_LEAN := 20.0
const BALK_PACE := 0.3

## Dropping it: a knock (the motor's `knocks` counting up, or laid down
## stunned) or a fall this far below the top of his jump or step off (m,
## times his size) knocks it out of his hands. It goes up this much (m/s)
## and spins at most this much (rad/s) as it leaves them. A loose one
## still this slow (m/s, rad/s) for SETTLE_TIME s is frozen where it lies
## (no jitter); one that falls this far under the isle's `lost` height is
## lost for the deal.
const DROP_FALL := 5.0
const DROP_UP := 1.6
const DROP_SPIN := 4.0
const SETTLE_SPEED := 0.12
const SETTLE_SPIN := 0.4
const SETTLE_TIME := 0.6

## Loading it into the plane's cargo sling (scripts/carry/cargo_sling.gd;
## E by the sling where it lies on the ground, carrying): he reaches it
## within SLING_REACH m (x size) of the basket's rim; the hand-over takes
## HITCH_TIME of the class's lift, arcing HITCH_ARC m (x size) over the
## rim; in, it bounces HITCH_BOUNCE m and settles over HITCH_SETTLE s.
const SLING_REACH := 1.0
const HITCH_TIME := 0.9
const HITCH_ARC := 0.25
const HITCH_BOUNCE := 0.05
const HITCH_SETTLE := 0.35

## The cargo bag (scripts/carry/cargo_sling.gd): empty, its belly's radius
## BAG_R (m) and its rope BAG_ROPE (m); with kg in it, the belly swells by
## BAG_R_KG times the root of the kg and the rope pays out BAG_ROPE_KG m a
## kg (a full bag hangs low and swings wide; no count cap, weight caps it
## in the plane). Empty, it rests BAG_REST m (past its radius) behind the
## plane. Its belly hits the world as a ball BAG_BALL of its radius,
## bouncing back BAG_BOUNCE of its speed into the hit; held back past its
## rope by BAG_PIN m it pulls free.
const BAG_R := 0.4
const BAG_R_KG := 0.11
const BAG_ROPE := 2.6
const BAG_ROPE_KG := 0.11
const BAG_REST := 2.2
const BAG_BALL := 0.8
const BAG_BOUNCE := 0.2
const BAG_PIN := 1.5
## Spilling: a hit this hard (m/s into what it hit) spills one, the last
## loaded; each SPILL_STEP harder spills one more. No second spill for
## SPILL_GRACE s (one blow, one spill). Spilled, a treasure leaves with the
## bag's velocity times SPILL_KEEP, thrown out of the hit SPILL_OUT m/s and
## up SPILL_UP m/s, tumbling (task 5's loose body).
const SPILL_SPEED := 3.0
const SPILL_STEP := 3.5
const SPILL_GRACE := 0.35
const SPILL_KEEP := 0.7
const SPILL_OUT := 2.5
const SPILL_UP := 1.5
## The load: what the bag's kg does to the plane (one table). `w` is the kg
## over LOAD["max_kg"], the most it takes off with; each row is its effect
## at w = 1, eased in linearly from an empty bag.
##   max_kg   the takeoff limit (kg): past it the plane won't leave the
##            ground (it won't lift off the wheels, and it stops at the
##            land's edge rather than roll off it)
##   heavy    the plane's weight model (scripts/sky_plane.gd `heavy`, the
##            `--heavy` flag's: the path swings after the nose, a pull-up
##            mushes, a turn skids, the climb costs speed, a bank sinks)
##   climb    the share of the climb it loses (a slower climb)
##   roll     the share of the throttle's push it loses rolling (a longer
##            takeoff roll)
##   lift     m/s more it needs to lift off the wheels
##   unstick  times longer it hangs heavy off the wheels (and slower its
##            speed builds then)
##   dip      m/s more the wings need off an edge before they catch it
##   over_top past max_kg, the most the throttle rolls it (m/s): the load
##            drags, it can't get going (and bumps to a stop at the edge)
const LOAD := {"max_kg":20.0,"over_top":4.0,"heavy":1.0,"climb":0.3,"roll":0.45,"lift":1.2,"unstick":0.8,"dip":1.5}

## The load's effects for `kg` in the bag: w (kg over max_kg), over (past
## the takeoff limit) and each row of LOAD at that w.
static func load_of(kg: float) -> Dictionary:
	var w := maxf(kg,0.0)/float(LOAD.max_kg)
	var at := clampf(w,0.0,1.0)
	return {"kg":kg,"w":w,"over":kg > float(LOAD.max_kg)+0.001,"heavy":float(LOAD.heavy)*at,
		"climb":float(LOAD.climb)*at,"roll":float(LOAD.roll)*at,"lift":float(LOAD.lift)*at,
		"unstick":1.0+float(LOAD.unstick)*at,"dip":float(LOAD.dip)*at,
		"top":float(LOAD.over_top) if kg > float(LOAD.max_kg)+0.001 else INF}

## Class `weight`'s row (light's when unknown).
static func of(weight: String) -> Dictionary:
	return CLASSES.get(weight,CLASSES["light"])
