extends RefCounted
## The modeless control scheme (docs/scenic/modeless.md, docs/scenic/hand-world.md
## "Verbs on the diorama"): behind `--modeless` the game has no tool modes. What
## the hand does depends on where the left button goes down, and the only mode
## is the camera, on the right button.
##
## - **Rim:** push sideways turns the world (a fast spin winds time, see
##   scripts/spin_time.gd); shake is the snow globe; drag up and over is the
##   lift, decided at the release: slowly a basin, a flick a toss that may go
##   over (scripts/diorama_flip.gd); pull down and let go, the block dips and
##   a random range springs up (scripts/edge_spring.gd). Shift turns without
##   winding time.
## - **Land:** pull down or up and let go: the land spring (land_spring.gd).
## - **Right button, or scroll:** the camera. It tilts, looks round and zooms,
##   and never changes time.
##
## Without the flag none of this exists and everything behaves as before. This
## file holds the flag and the numbers the slices share; the behaviour lives
## where the input is read.

## Screen pixels of a rim drag that decide its axis: mostly sideways turns the
## world, mostly vertical is the lift (up) or the edge spring (down). A shake can still take over from either.
const AXIS_PIXELS := 12.0
## The drag is the flip when its vertical travel beats its sideways travel
## by this factor.
const VERTICAL_BIAS := 1.2
## Screen heights of upward drag that count as all the way over the lip.
const FLIP_REACH := 0.45

static func enabled() -> bool:
	return "--modeless" in OS.get_cmdline_user_args()
