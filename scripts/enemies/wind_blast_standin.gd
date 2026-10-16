extends Node
## The wanderer's stand-in wind blast (docs/design/rune-knight/
## spec-rune-knight.md, "The player's blast"): with `--rune-knight` on the
## aqueduct isle, KEY (Z, a developer key: scripts/kit_isle/dev_keys.gd)
## on foot fires a straight wind shot (scripts/enemies/wind_shot.gd) from
## his chest the way he faces. The real blast, being built elsewhere,
## replaces this file: all it has to do to play tennis is put a WindShot
## (or any node with the shot's seam) in the `wind_shot` group, flying,
## with `shooter` the motor.
##
## Aim: level along his facing; a node in AIM_GROUP (the rune knight)
## within AIM_CONE of that facing and AIM_RANGE m is aimed at (its
## `aim_point()`, else its position), so a blast from the meadow can reach
## him up on the deck.
const WorldScale = preload("res://scripts/world_scale.gd")
const PhysicsGround = preload("res://scripts/pilot_physics_ground.gd")
const DevKeys = preload("res://scripts/kit_isle/dev_keys.gd")
const WindShot = preload("res://scripts/enemies/wind_shot.gd")

const KEY := KEY_Z
const AIM_GROUP := "wind_shot_aim"
## The shot's speed (m/s), its farthest flight (m), the knock's share, the
## rest between blasts (s).
const SPEED := 16.0
const FLIGHT := 45.0
const STRENGTH := 1.0
const REST := 0.45
## The aim's half angle off his facing (rad) and its range (m).
const AIM_CONE := 0.35
const AIM_RANGE := 40.0

var isle: Node3D
var cool := 0.0
var fired := 0
var last_shot: Node3D = null

func _init() -> void:
	name = "WindBlastStandin"

func setup(host: Node3D) -> void:
	isle = host

func _process(delta: float) -> void:
	cool = maxf(0.0,cool-delta)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey: return
	var key := event as InputEventKey
	if not key.pressed or key.echo or key.keycode != KEY: return
	if key.ctrl_pressed or key.meta_pressed or key.alt_pressed: return
	if not DevKeys.enabled(): return
	if fire() != null: get_viewport().set_input_as_handled()

## Whether he can blast now: on foot, walking, the title down, rested.
func ready_to_fire() -> bool:
	if isle == null or cool > 0.0: return false
	var parry = isle.get("wind_parry")
	if parry != null and is_instance_valid(parry) and parry.call("holds"): return false
	if bool(isle.get("flying")): return false
	if isle.get("walk_ready") != null and not bool(isle.get("walk_ready")): return false
	var door = isle.get("front_door")
	if door != null and is_instance_valid(door) and bool(door.get("titled")): return false
	return isle.get("motor") != null

## A blast from the wanderer's chest: the shot, or null if he can't.
func fire() -> Node3D:
	if not ready_to_fire(): return null
	var motor = isle.get("motor")
	var tall := WindShot.walker_tall()
	var face: float = motor.facing
	var way := Vector3(-sin(face),0.0,-cos(face))
	var from: Vector3 = (motor.feet as Vector3)+Vector3.UP*0.6*tall \
		+way*(PhysicsGround.RADIUS*WorldScale.wanderer+WindShot.radius()+0.15*tall)
	var aim := _aim(from,way)
	if aim != Vector3.INF: way = (aim-from).normalized()
	var shot := WindShot.new()
	shot.shooter = motor
	shot.strength = STRENGTH
	shot.flight = FLIGHT
	isle.add_child(shot)
	shot.global_position = from
	shot.launch(way*SPEED,0.0)
	cool = REST
	fired += 1
	last_shot = shot
	print("wind blast: fired from (%.1f, %.1f, %.1f) along (%.2f, %.2f, %.2f)%s" % [from.x,from.y,from.z,way.x,way.y,way.z," at a mark" if aim != Vector3.INF else ""])
	return shot

## The nearest mark in AIM_GROUP within the cone round `way`, or INF.
func _aim(from: Vector3, way: Vector3) -> Vector3:
	var best := Vector3.INF
	var best_d := AIM_RANGE
	for node: Node in get_tree().get_nodes_in_group(AIM_GROUP):
		if not node is Node3D: continue
		var p: Vector3 = node.call("aim_point") if node.has_method("aim_point") else (node as Node3D).global_position
		var flat := Vector3(p.x-from.x,0.0,p.z-from.z)
		var d := from.distance_to(p)
		if d > best_d or flat.length() < 0.5: continue
		if flat.normalized().angle_to(way) > AIM_CONE: continue
		best = p
		best_d = d
	return best
