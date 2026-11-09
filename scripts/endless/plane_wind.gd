extends RefCounted
## What the wind does to the plane in endless flight: the low buffet's share
## (SkyPlane `buffet_wind`), by the wind field's strength at the eye
## (EndlessLook `wind_here`, the plane's place): none in a calm or a light
## breeze (the tutorial's meadow, an ordinary morning, open ground on a
## breezy day), all of it from BUFFET.y up (a ridge or open water on a
## breezy afternoon, a gusty day). With no field (--wind=off, a world
## without one) the old buffet, all of it.

## The wind (zs_wind_strength's scale) the buffet starts at and is whole at.
const BUFFET := Vector2(0.35,1.0)

static func buffet(look: Node) -> float:
	if look == null or not look.has_method("wind_here"): return 1.0
	var here: Vector2 = look.wind_here()
	if here.x < 0.0: return 1.0
	return smoothstep(BUFFET.x,BUFFET.y,here.x)
