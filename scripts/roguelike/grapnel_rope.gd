extends "res://scripts/interactables/swing_rope.gd"
## [items_move] The Grapnel's line (scripts/roguelike/items_move.gd): a swing
## rope hung where the hook bit, its length the throw's, ridden as any swing
## rope (pump and steer on the stick, Jump lets go with the timed boost and
## the pop, crouch drops). On top of the rope:
##
## - **Haul** (`hauling`, the grapnel button held): the grip climbs the line
##   at HAUL m/s, down to the anchor's reach. Hauled up under a lip, he is
##   handed to the motor's own ledge hang and climbs onto it (the climb's
##   clip); under an arch's soffit or a beam he hangs at the top.
## - **Body**: a placed rope swings in open air; the grapnel's line runs down
##   cliffs, so the body is kept out of the solids (pushed out along what it
##   meets, its swing into it taken off). Stood on the ground and not
##   hauling, he lets go and stands.

## Haul speed up the line (m/s, by his size); the grip at which a lip's
## haul hands him to the ledge (m from the anchor).
const HAUL := 4.2
const TOP_GRIP := 0.4
## The body's ball kept out of the solids (m, by his size) and its height
## over the feet.
const BODY_R := 0.3
const BODY_AT := 0.7

## The swing's low point kept off the ground: the longest grip (m), taken
## up at TAUT m/s from a longer throw (the line snapping taut, a tug up).
const TAUT := 14.0
const CLEAR := 0.35
var most_grip := INF

## Set each frame by items_move: the button held.
var hauling := false
## The lip hooked ({at, out} from the ground's ledge), {} for a soffit.
var lip := {}
## The study's PhysicsGround (space, mask, ledge, callables).
var ground: Object = null
## Said by the ride: "pulled" when hauled onto the lip, "hung" at a soffit.
var ended := ""

var _ball := PhysicsShapeQueryParameters3D.new()

func setup_grapnel(at: Vector3, from_hands: Vector3, physics_ground: Object, hooked_lip: Dictionary) -> void:
	setup(at,maxf(at.distance_to(from_hands),0.6))
	ground = physics_ground
	lip = hooked_lip
	snag = false
	var s := SphereShape3D.new()
	s.radius = BODY_R
	_ball.shape = s
	_ball.collision_mask = int(ground.get("_ray").collision_mask) if ground != null else 1
	if ground != null:
		var floor_y := -INF
		for p: Vector3 in [at,from_hands]:
			var h: float = ground.call("height_from",Vector2(p.x,p.z),at.y-0.3)
			if is_finite(h): floor_y = maxf(floor_y,h)
		if is_finite(floor_y): most_grip = at.y-floor_y-PilotMotor.HANG_DROP-CLEAR

func take(walker: PilotMotor) -> void:
	_take(walker,hand_of(walker))

func ride(walker: PilotMotor, delta: float, want: Vector2, pressed: bool) -> Dictionary:
	var top := TOP_GRIP*walker.size
	if hauling and walker.move != "tumble":
		grip = maxf(grip-HAUL*walker.size*delta,top*0.9)
		# Hauling up a lip's line he turns to its wall, hand over hand.
		if not lip.is_empty(): facing = rotate_toward(facing,PilotMotor.facing_of(-(lip.out as Vector2)),8.0*delta)
	var most := maxf(most_grip,top)
	if grip > most: grip = maxf(grip-TAUT*walker.size*delta,most)
	var out := super.ride(walker,delta,want,pressed)
	if walker.rider != self: return out
	_keep_out(walker)
	if hauling and grip <= top:
		if not lip.is_empty() and _onto_lip(walker):
			ended = "pulled"
			out["grapnel"] = "pulled"
			return out
		if lip.is_empty() and ended == "":
			ended = "hung"
	# Stood on the ground, not hauling: he lets go and stands.
	if ground != null and not hauling:
		var under: float = ground.call("height_from",Vector2(walker.feet.x,walker.feet.z),walker.feet.y+0.3)
		if is_finite(under) and walker.feet.y <= under+0.03:
			walker.feet.y = under+0.02
			_cool = REGRAB
			walker.toss(Vector3(velocity.x,minf(velocity.y,0.0),velocity.z)*0.3)
			motor = null
			out["swing"] = false
	return out

## The body out of the solids: pushed out along what it meets (a few
## steps), the swing into it taken off, the grip kept.
func _keep_out(walker: PilotMotor) -> void:
	if ground == null: return
	var space: PhysicsDirectSpaceState3D = ground.get("space")
	if space == null: return
	(_ball.shape as SphereShape3D).radius = BODY_R*walker.size
	for i in range(6):
		_ball.transform = Transform3D(Basis.IDENTITY,walker.feet+Vector3.UP*BODY_AT*walker.size)
		var rest := space.get_rest_info(_ball)
		if rest.is_empty(): return
		var n: Vector3 = rest.normal
		if n.length_squared() < 1e-6: return
		n = n.normalized()
		hands = anchor+(hands+n*0.06-anchor).normalized()*grip
		if velocity.dot(n) < 0.0: velocity -= n*velocity.dot(n)*1.2
		_place(walker)

## Hauled to the top under the lip: the motor's own hang there, and the
## climb onto it (its clip). False if the lip won't take him.
func _onto_lip(walker: PilotMotor) -> bool:
	var found: Dictionary = ground.call("ledge",Vector2(lip.at.x,lip.at.z),float(lip.at.y))
	if found.is_empty(): found = lip
	var g: Callable = ground.call("ground_callable")
	var sl: Callable = ground.call("slide_callable")
	walker.rider = null
	motor = null
	walker._hang_on(found)
	walker._regrab = 0.0
	if not walker._climb(g,sl):
		# No room to stand: he hangs from it.
		walker.hold = "hang"
	return true
