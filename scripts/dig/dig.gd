extends Node3D
## Digging in the wreck cluster (docs/design/dig/spec-dig.md, loop `dig`).
## A child of the cluster (studies/wreck_cluster.gd), set up from its
## `_add_life`: the spade lying by the plane, taken by walking over it (or
## pressing Dig beside it), then carried on his back (a bone attachment on
## the figure's chest); `re_deal` lays it back by the plane (N).
##
## Dig is its own action, `walk_dig` (scripts/pad.gd: G, the pad's Y).
##
## The spade's lying spot is a named placement (scripts/layout_overrides.gd)
## `wreck_cluster/spade`, a token the world view (F4) moves.

const SpadeFigure = preload("res://scripts/dig/spade_figure.gd")
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const Lines = preload("res://scripts/collectible_lines.gd")

const ACTION := &"walk_dig"
const SPADE_NAME := "wreck_cluster/spade"
## Where the spade lies, from the cluster's start (beside the plane, in
## front of him as he starts, so the first look finds it).
const SPADE_FROM_START := Vector3(1.3,0.0,-2.4)
const SPADE_YAW := 0.6
## How far Dig reaches for the spade lying (m, times his size); walking
## over it takes it at the collectibles' reach.
const PRESS_REACH := 1.4
## The spade on his back, in the chest bone's frame (judged in stills).
## Slung across his back, blade down by one hip, the grip up past the other
## shoulder, clear of the hat's brim; the bone's +z is his back.
const BACK_TILT := Vector3(0.0,0.0,40.0)
const BACK_AT := Vector3(0.0,0.0,0.17)

var host: Node3D = null
## "lying" by the plane, or "carried" on his back.
var spade_state := "lying"
var spade_lying: Node3D = null
var spade_holder: Node3D = null
var spade_back: Node3D = null
var _back_mount: BoneAttachment3D = null

func setup(scene: Node3D) -> void:
	host = scene
	name = "Dig"
	var start: Vector3 = host.get("start")
	var coded := Transform3D(Basis(Vector3.UP,SPADE_YAW),start+SPADE_FROM_START)
	spade_holder = Node3D.new()
	spade_holder.name = "SpadeSpot"
	add_child(spade_holder)
	spade_holder.global_transform = LayoutOverrides.xform(SPADE_NAME,coded)
	LayoutOverrides.track(SPADE_NAME,spade_holder,"token",coded)
	spade_lying = SpadeFigure.new()
	spade_holder.add_child(spade_lying)
	lay_spade()

func _scale() -> float:
	var s: Variant = host.get("wanderer_scale")
	return float(s) if s != null else 1.0

## The spade back on its spot, stuck in the turf under it, and off his
## back.
func lay_spade() -> void:
	spade_state = "lying"
	if spade_back != null and is_instance_valid(spade_back): spade_back.visible = false
	spade_lying.visible = true
	var s := _scale()
	var at := spade_holder.global_position
	var ground := _ground_at(at)
	var y := ground.y if ground != Vector3.INF else at.y
	# Stuck upright in the turf by its blade, leaning a little, so it shows
	# over the grass.
	var lean := Basis(Vector3.FORWARD,deg_to_rad(12.0))*Basis(Vector3.UP,deg_to_rad(20.0))
	spade_lying.global_transform = Transform3D(spade_holder.global_basis.orthonormalized()*lean.scaled(Vector3.ONE*s),
		Vector3(at.x,y-SpadeFigure.BITE*s,at.z))

func _ground_at(p: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(p+Vector3.UP*3.0,p+Vector3.DOWN*6.0,1|(1 << 11))
	var hit := space.intersect_ray(ray)
	return Vector3.INF if hit.is_empty() else hit.position

## The spade's middle, lying (world).
func spade_point() -> Vector3:
	return spade_lying.global_transform*Vector3(0.0,SpadeFigure.LENGTH*0.4,0.0)

func has_spade() -> bool:
	return spade_state == "carried"

## The cluster's re-deal (N): the spade back by the plane.
func re_deal() -> void:
	lay_spade()

func take_spade() -> void:
	if spade_state == "carried": return
	spade_state = "carried"
	spade_lying.visible = false
	_mount_back()
	var moments: Variant = host.get("_moments")
	if moments != null: moments.pop("The spade: G (Y) digs where the soil looks turned",3.0)
	var arc: Variant = host.get("plane_arc")
	if arc != null and arc.get("sounds") != null: arc.sounds.found(1)

## The spade on his back: a bone attachment on the figure's chest.
func _mount_back() -> void:
	if spade_back == null or not is_instance_valid(spade_back):
		var body: Node = host.get("body")
		var skeleton: Skeleton3D = body.get("_skeleton") if body != null else null
		if skeleton == null or skeleton.find_bone("chest") < 0: return
		_back_mount = BoneAttachment3D.new()
		_back_mount.name = "SpadeMount"
		_back_mount.bone_name = "chest"
		skeleton.add_child(_back_mount)
		spade_back = SpadeFigure.new()
		spade_back.transform = Transform3D(Basis.from_euler(BACK_TILT*PI/180.0),BACK_AT)*Transform3D(Basis.IDENTITY,Vector3(0.0,-SpadeFigure.LENGTH*0.5,0.0))
		_back_mount.add_child(spade_back)
	spade_back.visible = true

func _process(_delta: float) -> void:
	if host == null or not bool(host.get("walk_ready")) or bool(host.get("flying")): return
	if spade_state == "lying":
		var motor: Variant = host.get("motor")
		var s := _scale()
		var mid: Vector3 = motor.feet+Vector3.UP*Lines.FOOT_Y*s
		if mid.distance_to(spade_point()) < Lines.WALKER_REACH*s+0.35*s: take_spade()

func _unhandled_input(event: InputEvent) -> void:
	if host == null or not event.is_action_pressed(ACTION) or event.is_echo(): return
	if bool(host.get("flying")) or not bool(host.get("walk_ready")): return
	if spade_state == "lying":
		var motor: Variant = host.get("motor")
		if (motor.feet as Vector3).distance_to(spade_point()) < PRESS_REACH*_scale():
			take_spade()
			get_viewport().set_input_as_handled()
