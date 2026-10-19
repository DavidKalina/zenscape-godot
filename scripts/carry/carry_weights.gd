extends RefCounted
## What a carried treasure's weight does to the wanderer (docs/design/carry/
## spec-carry.md): one table to tune. Each class scales the motor's own
## feel (scripts/pilot_motor.gd's live knobs, read when he lifts it and put
## back when he lets go) and says which moves the load forbids.
##
##   walk, run   his paces, times the empty-handed ones
##   jump        his jump heights (both of the chain's), times
##   turn        how fast he turns on the ground, times
##   lift        the heave's length (s): the anticipation and the lift
##   hold        where it rides: "chest" (both hands before him) or
##               "shoulder" (hoisted up on both hands, beside the head)
##   bars        the moves the load forbids (the motor's gates, refused
##               with a stagger and a shake of the head): "wall" (wall
##               slide, kick and run), "ledge" (grabs, hangs, the climb),
##               "sail", "rope" (the swing ropes)
##   sway        the camera's lurch at each footfall (degrees of roll; 0
##               none), and its dip (m, times his size)
##   thud        a heavy footfall under each step (gain, 0 none)

const CLASSES := {
	"light":{"walk":0.9,"run":0.85,"jump":0.85,"turn":0.9,"lift":0.35,"hold":"chest",
		"bars":[],"sway":0.0,"dip":0.0,"thud":0.0},
	"medium":{"walk":0.75,"run":0.65,"jump":0.6,"turn":0.75,"lift":0.6,"hold":"chest",
		"bars":["wall"],"sway":0.0,"dip":0.0,"thud":0.05},
	"heavy":{"walk":0.55,"run":0.4,"jump":0.3,"turn":0.5,"lift":0.95,"hold":"shoulder",
		"bars":["wall","ledge","sail","rope"],"sway":1.4,"dip":0.06,"thud":0.16},
}
## The refusal: seconds of it, the head's shakes in it and their swing
## (degrees), the body's lurch (degrees of lean at the chest) and the pace
## kept meanwhile (times the carrying pace).
const BALK_TIME := 0.7
const BALK_SHAKES := 2.5
const BALK_HEAD := 28.0
const BALK_LEAN := 20.0
const BALK_PACE := 0.3

## Class `weight`'s row (light's when unknown).
static func of(weight: String) -> Dictionary:
	return CLASSES.get(weight,CLASSES["light"])
