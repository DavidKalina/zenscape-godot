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

const CLASSES := {
	"light":{"walk":0.9,"run":0.85,"jump":0.85,"turn":0.9,"lift":0.35,"hold":"chest"},
	"medium":{"walk":0.75,"run":0.65,"jump":0.6,"turn":0.75,"lift":0.6,"hold":"chest"},
	"heavy":{"walk":0.55,"run":0.4,"jump":0.3,"turn":0.5,"lift":0.95,"hold":"shoulder"},
}

## Class `weight`'s row (light's when unknown).
static func of(weight: String) -> Dictionary:
	return CLASSES.get(weight,CLASSES["light"])
