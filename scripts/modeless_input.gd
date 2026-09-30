extends RefCounted
## The modeless control scheme (docs/scenic/modeless.md, docs/scenic/hand-world.md
## "Verbs on the diorama"): the default since 2026-09-29; `--classic-controls`
## brings back the tool modes. There are no tool modes: what the hand does
## depends on where the left button goes down, and the only mode is the camera,
## on the right button.
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
## With `--classic-controls` none of this exists and everything behaves as
## before. This file holds the flag and the numbers the slices share; the behaviour lives
## where the input is read.

## Screen pixels of a rim drag that decide its axis: mostly sideways turns the
## world, mostly vertical is the lift (up) or the edge spring (down). A shake can still take over from either.
const AXIS_PIXELS := 12.0
## The drag is the flip when its vertical travel beats its sideways travel
## by this factor.
const VERTICAL_BIAS := 1.2
## Screen heights of upward drag that count as all the way over the lip.
const FLIP_REACH := 0.45

## `--modeless` is still accepted (the probes and films pass it) but no longer
## needed.
static func enabled() -> bool:
	return not "--classic-controls" in OS.get_cmdline_user_args()

## How the edge spring's pull is shown (docs/scenic/modeless-spring.md, "Pull
## feel (experiment)"): `--pull-cam=a|b|c|old`. "a" holds the camera still
## while the block drops, squashes and stretches the block and trails the
## plants; "b" (the default) adds a low, side-on swing at the press that eases
## back once the range has settled; "c" is b that stays low; "old" is the
## camera lean from before (scripts/camera_rig.gd `lean`), with no squash.
const PULL_CAMS := ["a","b","c","old"]
const PULL_CAM_DEFAULT := "a"

static func pull_cam() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--pull-cam="):
			var value := arg.trim_prefix("--pull-cam=").to_lower()
			if value in PULL_CAMS: return value
			push_warning("--pull-cam=%s is not one of %s; using %s" % [value,PULL_CAMS,PULL_CAM_DEFAULT])
	return PULL_CAM_DEFAULT
