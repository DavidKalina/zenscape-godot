extends Node3D
## A cloud host: the clouds a sky keeps in the open air and what the planes
## do to them. The towering cumulus rising out of the cloud sea (`towers`,
## scripts/sky_towers.gd), the small clouds drifting on the breeze between
## the isles (`clouds`, scripts/sky_clouds.gd) and the tunnels and tufts the
## planes tear through both (`wakes`, scripts/cloud_wakes.gd).
##
## This is the seam the clouds' readers go through, not a scene's own
## nodes. The look pass (scripts/look_pass.gd `cloud_host`) asks the scene
## for its host (`cloud_host()`) and hands it to the unified cloud volume
## (scripts/cloud_volume.gd `update`), which marches the host's `towers`
## and carves its `wakes`. The CPU traffic (scripts/sky_traffic.gd) flies
## through its `cloud_near` and mists in its `in_cloud`. The plane muffles
## its wind in its `cloud_body`. A host is anything that has those three
## nodes and answers those three questions. There are two:
##
##   the old game's   scripts/sky_islands.gd, which makes and moves its own
##                    with the islands (seeded cells, the ring's layout,
##                    claim swaps) and answers through the statics here;
##   a laid sky's     this node, made by a sky whose places are laid by
##                    hand (the kit isles', scripts/kit_isle/kit_clouds.gd):
##                    `setup` with the towers' spots, the clouds' slots and
##                    where nothing may stand, and `step` each frame with
##                    the eye and the fliers.
##
## The rules are the statics (`body_of`, `veil_of`, `nearest_of`,
## `tear_into`), so both hosts read and tear the same way. With no
## RenderingDevice (headless, Compatibility) the volume isn't made and the
## towers draw themselves in their boxes, as in the old game.

const SkyTowers = preload("res://scripts/sky_towers.gd")
const SkyClouds = preload("res://scripts/sky_clouds.gd")
const CloudWakes = preload("res://scripts/cloud_wakes.gd")
const SkyCells = preload("res://scripts/sky_cells.gd")

## Most wake points handed to each tower's own shader (the old renderer's).
const TOWER_WAKES := 8
## The puffs thin away over at most this many places (SkyClouds `keep_off`).
const KEEPS := 4

var towers: Node3D
var clouds: Node3D
var wakes: Node3D
## The scene's motion time as of the last `step` (s), what the drifting
## clouds are placed by.
var time := 0.0
## The places the puffs thin away over: Vector4(x, z, 0, radius), global.
var keep: Array = []
## The main thread's microseconds the last `step` took, for the record.
var spent := 0

func _init() -> void:
	name = "Clouds"

## Makes the towers at `spots` (home coordinates, y 0; the first rises
## soon, SkyTowers `fixed`), the drifting clouds over the field round
## `slots` (SkyClouds `build`, clear of what `blocked` says), and the wakes.
## `air` (SkyCurrents, or null) takes the towers' thermals.
func setup(spots: Array, slots: Array, blocked: Callable, air: Node3D = null) -> void:
	towers = SkyTowers.new()
	towers.fixed = spots.duplicate()
	add_child(towers)
	towers.reset(SkyCells.new(),air)
	clouds = SkyClouds.new()
	add_child(clouds)
	clouds.build(slots,blocked)
	clouds.reset()
	wakes = CloudWakes.new()
	add_child(wakes)

## One frame: the towers' lives and streaming round `eye`, the puffs
## screened by the towers, thinned over `keep` and following the eye, every
## flier ([id, position, velocity], global) traced through the cloud, and
## the tunnels handed to the clouds that show them.
func step(delta: float, eye: Vector3, motion_time: float, fliers: Array) -> void:
	var began := Time.get_ticks_usec()
	time = motion_time
	towers.advance(delta,eye)
	clouds.screen(towers.screens(eye),towers.fade(eye)*0.9)
	var near := keep.duplicate()
	near.sort_custom(func(a: Vector4, b: Vector4) -> bool: return Vector2(a.x-eye.x,a.y-eye.z).length() < Vector2(b.x-eye.x,b.y-eye.z).length())
	clouds.keep_off(near.slice(0,KEEPS))
	clouds.follow(eye)
	for f: Array in fliers: wakes.trace(f[0],f[1],f[2],cloud_body(f[1]),time,delta)
	tear_into(towers,clouds,wakes,time,delta)
	spent = Time.get_ticks_usec()-began

## Every tower stood up at once, whole (tests, captures: SkyTowers `flush`).
func flush() -> void:
	towers.flush()

# --- The host's questions -------------------------------------------------------

## How deep a global point is in cloud for the vapour, 0 to 1.
func in_cloud(point: Vector3, at_time: float) -> float:
	return veil_of(clouds,towers,point,at_time)

## How deep a global point is in the body of a cloud, 0 to 1.
func cloud_body(point: Vector3) -> float:
	return body_of(clouds,towers,point,time)

## The middle of the drifting cloud nearest a global point within `reach`,
## global, or null.
func cloud_near(point: Vector3, reach: float) -> Variant:
	return nearest_of(clouds,point,reach,time)

## The CPU traffic flown through this host's clouds (SkyTraffic
## `cloud_near`, `cloud_depth`).
func hook(traffic: Node) -> void:
	traffic.cloud_near = cloud_near
	traffic.cloud_depth = func(point: Vector3) -> float: return in_cloud(point,time)

# --- The rules, both hosts' -----------------------------------------------------

## The vapour's depth: a drifting cloud's heap (SkyClouds `inside`) or a
## tower's (SkyTowers `fade`, by its VEIL: a tower draws its own fog round
## the eye), 0 to 1.
static func veil_of(puffs: Node3D, columns: Node3D, point: Vector3, at_time: float) -> float:
	return maxf(puffs.inside(point,at_time),columns.fade(point)*SkyTowers.VEIL)

## The body's depth, drifting or a tower, 0 to 1: what a plane tears
## through and the mist round the eye.
static func body_of(puffs: Node3D, columns: Node3D, point: Vector3, at_time: float) -> float:
	return maxf(puffs.inside(point,at_time),columns.fade(point))

## The drifting cloud's middle nearest `point` within `reach`, or null.
static func nearest_of(puffs: Node3D, point: Vector3, reach: float, at_time: float) -> Variant:
	var best: Variant = null
	var gap := reach
	for i in range(puffs.clouds.size()):
		var c: Vector3 = puffs.centre(i,at_time)
		var d := c.distance_to(point)
		if d < gap:
			gap = d
			best = c
	return best

## The tunnels aged and handed on, once the frame's fliers are traced: all
## to the drifting puffs, and to each tower's own shader the few near it.
static func tear_into(columns: Node3D, puffs: Node3D, trails: Node3D, at_time: float, delta: float) -> void:
	trails.advance(delta)
	puffs.wakes(trails.at,trails.way)
	for b: Dictionary in columns.built.values():
		var material: ShaderMaterial = b.get("material")
		if material == null or not is_instance_valid(b.get("node")): continue
		var half: Variant = material.get_shader_parameter("box_half")
		var mid: Variant = material.get_shader_parameter("box_mid")
		if not half is Vector3 or not mid is Vector3: continue
		var near: Array = trails.near_box((b.node as Node3D).global_position+mid,half,at_time,TOWER_WAKES)
		material.set_shader_parameter("wake_count",near[2])
		if near[2] > 0:
			material.set_shader_parameter("wake_at",near[0])
			material.set_shader_parameter("wake_way",near[1])
