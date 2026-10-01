extends RefCounted
## Trees thin round the pointer while a shaping tool works the land, so the
## ground under them shows, and fill back in once it moves on. Made and
## stepped by scripts/hand_reach.gd, which says where the tool is (`step`'s
## `at`, global) or that none is at work (null).
##
## Only two shader globals carry it, `zs_reveal_point` (x, y, z, radius) and
## `zs_reveal_eye` (x, y, z, strength); shaders/shaping_reveal.gdshaderinc
## reads them in the trees' fragment and lets their leaves and bark drop out in
## soft clumps: every tree within the radius of the point, and any tree that
## stands in the line of sight to it. The eye is the camera's, sent from here
## rather than read in the shader, so a tree's shadow thins with it instead of
## following the light's own view.
##
## RADIUS is metres at the middle size pip, scaled by the size in hand but
## never under MIN_RADIUS. The strength rises at RISE and falls back at FALL
## (per second), so a tree fades out gently and comes back more slowly still;
## the point follows the pointer at FOLLOW (1/s), so the fade glides.

const RADIUS := 3.0
const MIN_RADIUS := 2.2
const RISE := 2.5
const FALL := 1.2
const FOLLOW := 12.0

## 0..1, eased when published.
var strength := 0.0
var _point := Vector3.ZERO
var _radius := RADIUS
var _sent := false

## One frame: `at` is the land the tool is over (global) or null, `eye` the
## camera's position and `size_scale` the size in hand.
func step(delta: float, at: Variant, eye: Vector3, size_scale: float) -> void:
	if at != null:
		var goal: Vector3 = at
		_point = goal if strength <= 0.001 else _point.lerp(goal,1.0-exp(-FOLLOW*delta))
		_radius = maxf(MIN_RADIUS,RADIUS*size_scale)
	var want := 1.0 if at != null else 0.0
	strength = move_toward(strength,want,delta*(RISE if want > strength else FALL))
	if strength <= 0.0 and not _sent: return
	_sent = strength > 0.0
	RenderingServer.global_shader_parameter_set("zs_reveal_point",Vector4(_point.x,_point.y,_point.z,_radius))
	RenderingServer.global_shader_parameter_set("zs_reveal_eye",Vector4(eye.x,eye.y,eye.z,smoothstep(0.0,1.0,strength)))
