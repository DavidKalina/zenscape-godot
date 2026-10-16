extends Node3D
## The gust shot (docs/design/lock-on/spec-lock-on.md): on foot, X with the
## updraft charge at least its release threshold spends it all and throws a
## ball of air from his chest. Locked on (scripts/lock_on/foot_lock.gd) it
## homes on the target and bursts on it (`hit(at, way, strength)`); free, it
## flies level along the camera's flat heading. The ball, its trail and its
## burst are the dragon's air blast (scripts/dragon_air_blast.gd) with the
## gust arrows' brighter look; no one ever asks it for a knock, so it never
## throws him (or the plane).

const DragonAirBlast = preload("res://scripts/dragon_air_blast.gd")
const TargetStone = preload("res://scripts/lock_on/target_stone.gd")

## The ball's pace (m/s; the dragon's is 110, too quick to follow at this
## range), how far a free one flies (m) and how hard a locked one turns
## onto its target (rad/s): enough to meet it from a run or a jump.
const SPEED := 38.0
const FLIGHT := 70.0
const HOMING := 5.0
## Leaves from his chest (walker heights over his feet), this far out (m).
const CHEST := 0.6
const OUT := 0.7
## A ball passing this near (m, past its own radius) the target's middle
## bursts on it; a burst within HIT_NEAR (m) of a target lands on it.
const FUSE := 0.45
const HIT_NEAR := 1.6
## The hit's strength at charge MIN_RELEASE .. full.
const STRENGTH := Vector2(0.6,1.0)
## The look: as the gust arrows' (studies/crossings/gust_arrows.gd).
const GLOW := 1.6
const TINT := Color(0.92,0.97,1.0)
const TRAIL := 3.0

var blast: DragonAirBlast
## Counts and the last shot, for checks: shots fired, hits landed on a
## target, the last shot's charge spent and whether it was locked.
var shots := 0
var hits := 0
var last_charge := 0.0
var last_locked := false
var _strength := 1.0
var _from := Vector3.ZERO
var _target: Node3D = null

func _init() -> void:
	name = "GustShot"

func _ready() -> void:
	blast = DragonAirBlast.new()
	blast.name = "GustBall"
	blast.on = false
	blast.speed = SPEED
	blast.flight = FLIGHT
	blast.glow = GLOW
	blast.tint = TINT
	blast.span = TRAIL/0.12
	add_child(blast)
	blast.landed.connect(_landed)
	blast.broke.connect(_landed)

## Fires from his `feet` (facing `heading`, flat) at `target` (null: along
## `heading`), with `charge` spent.
func fire(feet: Vector3, heading: Vector3, target: Node3D, charge: float) -> void:
	var flat := Vector3(heading.x,0.0,heading.z)
	flat = flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
	var from := feet+Vector3.UP*CHEST*DragonAirBlast.walker_tall()+flat*OUT
	var aim: Vector3 = target.call("aim_point") if target != null else from+flat*FLIGHT
	_target = target
	_from = from
	_strength = lerpf(STRENGTH.x,STRENGTH.y,inverse_lerp(0.15,1.0,clampf(charge,0.15,1.0)))
	shots += 1
	last_charge = charge
	last_locked = target != null
	blast.homing = HOMING if target != null else 0.0
	blast.fire(from,aim)
	print("gust shot: charge %.2f, %s" % [charge,"at %s" % target.name if target != null else "free"])

## A frame: flies the balls; a locked ball bursts on its target's middle.
## `mouth` is where he shoots from now (the ball's carry out of his chest).
func step(delta: float, feet: Vector3, space: PhysicsDirectSpaceState3D) -> void:
	var aim := Vector3.INF
	if _target != null and is_instance_valid(_target) and not blast.balls.is_empty():
		aim = _target.call("aim_point")
		blast._catch(aim,DragonAirBlast.ball_radius()+FUSE)
	var mouth := feet+Vector3.UP*CHEST*DragonAirBlast.walker_tall()
	blast.advance(delta,space,false,mouth,aim)

func flying() -> bool:
	return blast != null and not blast.balls.is_empty()

func _landed(at: Vector3) -> void:
	var way := at-_from
	for t: Node in get_tree().get_nodes_in_group(TargetStone.GROUP):
		var n := t as Node3D
		if n == null or not n.has_method("hit"): continue
		var mid: Vector3 = n.call("aim_point")
		if mid.distance_to(at) > HIT_NEAR: continue
		n.call("hit",at,way,_strength)
		hits += 1
		print("gust shot: hit %s %.2f m from its middle" % [n.name,mid.distance_to(at)])
		return
