extends Node3D
## The stone brood on a kit isle (docs/design/brood/spec-brood.md): the
## stone guys (scripts/brood/stone_guy.gd), stepped together each frame,
## each toward the goal the host picks for him. The study adds it
## (studies/wreck_cluster.gd) and calls `clear()` on its re-deal.
##
## So far: `--brood-one` stands one stone guy a little way off the wanderer
## when he can walk, and he comes for the wanderer wherever he goes (over
## walls, up faces, around edges he won't go over).

const K = preload("res://scripts/brood/brood_knobs.gd")
const StoneGuy = preload("res://scripts/brood/stone_guy.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

var study: Node3D = null
var guys: Array = []
## A driver's goal for every guy (INF: the host picks).
var goal_override := Vector3.INF
var _one := false
var _rng := RandomNumberGenerator.new()

func setup(host: Node3D) -> void:
	study = host
	name = "Brood"
	process_priority = 90
	_rng.randomize()
	_one = LaunchArgs.user_args().has("--brood-one")

## One guy standing at `feet`.
func spawn(feet: Vector3) -> RefCounted:
	var g: RefCounted = StoneGuy.new(feet,1.0 if _rng.randf() < 0.5 else -1.0)
	add_child(g.node)
	guys.append(g)
	return g

## Every guy put away.
func clear() -> void:
	for g: RefCounted in guys: (g.node as Node3D).queue_free()
	guys.clear()

func _motor() -> Variant:
	return study.get("motor") if study != null else null

func _process(delta: float) -> void:
	if study == null or not bool(study.get("walk_ready")): return
	if _one and guys.is_empty(): _spawn_one()
	if guys.is_empty(): return
	var dt := minf(delta,1.0/30.0)
	var space := get_world_3d().direct_space_state
	var goal := goal_override
	if goal == Vector3.INF:
		var m: Variant = _motor()
		if m != null and not bool(study.get("flying")): goal = m.feet
	for g: RefCounted in guys:
		if g.state == "lost": continue
		g.step(space,goal,dt)

## `--brood-one`: one guy on the ground some 8 m off him, the first spot
## round him that has ground.
func _spawn_one() -> void:
	var m: Variant = _motor()
	if m == null: return
	var feet: Vector3 = m.feet
	var space := get_world_3d().direct_space_state
	for i: int in 12:
		var a := TAU*float(i)/12.0
		var p := feet+Vector3(cos(a),0.0,sin(a))*8.0*K.s()
		var ray := PhysicsRayQueryParameters3D.create(p+Vector3.UP*4.0,p+Vector3.DOWN*6.0,K.SOLID_MASK)
		var hit := space.intersect_ray(ray)
		if hit.is_empty() or (hit.normal as Vector3).y < K.FLOOR: continue
		spawn(hit.position)
		print("brood: one stone guy at %s" % [hit.position])
		return
	_one = false
