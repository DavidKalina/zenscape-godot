extends RefCounted
## What a walker's body is doing this frame, all the figure
## (scripts/pilot_figure.gd `drive`, `soak`) reads to pose him. The motor
## gives one (scripts/pilot_motor.gd `pose()`, a fresh copy each call); a
## stand-in that is never stepped (the Second Walker's puppet, a study's
## held-still pilot) keeps its own and sets it each frame. The fields mean
## what the motor's of the same names do.

## The feet, in the frame; the velocity over its ground (m/s).
var feet := Vector3.ZERO
var velocity := Vector3.ZERO
## The way he faces: down -Z turned by `facing` about up.
var facing := 0.0
var grounded := true
var skidding := false
## The motor's `move` ("", "jump", "pump", "long", "kick", "wall", "crouch",
## "twirl", "slide", "flip", "wallrun", "tumble", "slam", "sail", "roll").
var move := ""
## On a ledge or a rope: "" (not), "catch", "lower", "hang", "climb",
## "swing"; the climb's place in its clip (0 to 1); the shimmy's pace (m/s
## to his right); the lip held and its way off.
var hold := ""
var hold_t := 0.0
var shimmy := 0.0
var lip := Vector3.ZERO
var lip_out := Vector2.ZERO
## In water: swimming, and the depth over his boots (m, 0 dry).
var swimming := false
var wade := 0.0
## Sliding down or running along a wall: the way off it (x, z).
var wall_out := Vector2.ZERO
## Sliding: whether the stick carves, and the carve's turn (rad/s, + left).
var carve := true
var carving := 0.0
## Knocks taken (a change is a fresh throw for the ragdoll), and whether a
## grab holds him still.
var knocks := 0
var seized := false

## His flat pace (m/s).
func speed() -> float:
	return Vector2(velocity.x,velocity.z).length()
