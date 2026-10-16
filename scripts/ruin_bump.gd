extends RefCounted
## Bump and recover against the ruins' stone (the Sundered hall's near
## bodies, scripts/sundered_build.gd RUIN_LAYER), for the game's plane
## (scripts/sky_plane.gd), as the ruin kit gallery's fly mode does it:
## the plane's body is a wing-wide slab (BODY) turned with its heading,
## pitch, bank and roll, so on a knife edge it slips through a gap its
## level wings would not; sitting in stone, it is put back out along the
## face it hit (the way it came, failing that), its heading turned along
## the face and its pitch eased level, a share of its speed lost (KEEP).
## Never a crash.

const PlaneFigure = preload("res://scripts/plane_figure.gd")
## The toy plane's span and the game's sizes (scripts/world_scale.gd).
const WorldScale = preload("res://scripts/world_scale.gd")
const SkyPlane = preload("res://scripts/sky_plane.gd")

const BODY := Vector3(WorldScale.TOY_SPAN,0.3,1.2)
const KEEP := 0.55
const LAYER := 1 << 10

static var _query: PhysicsShapeQueryParameters3D

## Bumps `plane` (positions in its own frame, `to_world` carrying them into
## the physics world) back out of any ruin it has flown into since `was`.
## True if it bumped.
static func bump(space: PhysicsDirectSpaceState3D, plane: RefCounted, was: Vector3, to_world := Transform3D.IDENTITY) -> bool:
	if space == null: return false
	if _query == null:
		_query = PhysicsShapeQueryParameters3D.new()
		var box := BoxShape3D.new()
		box.size = BODY
		_query.shape = box
		_query.collision_mask = LAYER
	var turn := PlaneFigure.pose(Vector3.ZERO,float(plane.heading),float(plane.pitch),float(plane.bank)+float(plane.get("spin") if plane.get("spin") != null else 0.0)).basis
	_query.transform = Transform3D(to_world.basis*turn,to_world*(plane.position as Vector3))
	var rest := space.get_rest_info(_query)
	if rest.is_empty(): return false
	var normal: Vector3 = to_world.basis.inverse()*(rest.get("normal",Vector3.ZERO) as Vector3)
	if normal.length() < 0.5: normal = (was-(plane.position as Vector3)).normalized()
	plane.position = was+normal*0.15
	_query.transform = Transform3D(to_world.basis*turn,to_world*(plane.position as Vector3))
	if not space.get_rest_info(_query).is_empty(): plane.position = was+normal*0.6
	plane.glance(normal,KEEP,SkyPlane.SLOW)
	return true
