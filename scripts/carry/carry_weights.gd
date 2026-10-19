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

## Class `weight`'s row (light's when unknown).
static func of(weight: String) -> Dictionary:
	return CLASSES.get(weight,CLASSES["light"])
