extends "res://scripts/cloud_host.gd"
## The kit isles' clouds (docs/design/consolidation-audit.md, "Round 3
## done"): the old game's towering cumulus, drifting clouds and cloud
## tearing in the sky round a kit isle (studies/aqueduct_isle_sky.gd and
## its subclasses), through the cloud host (scripts/cloud_host.gd), so the
## look pass hands the cloud volume these towers and wakes as it hands it
## the old game's islands'.
##
##   towers    TOWERS, laid by hand as the old game's ring lays its own:
##             one in sight of the isle (it rises RISE_SOON s into the
##             flight, as the old home tower does), three far out between
##             the far isles. Each lives the old life (rest, rise out of the
##             sea, stand, wane, rise again) and is built on a worker within
##             BUILD of the eye and stood within the sky's frame budget
##             (SkyTowers, scripts/sky_commits.gd). A tower that would
##             stand within KEEP of the isle's lock ring, of a far isle, a
##             cluster, the pierced isle, or the line out to the lodestone's
##             ring and the halls past it (CHAIN_RUN m on) is left out
##             (`spots`), so another kit isle's sky never stands one in its
##             way.
##   clouds    the old game's drifting puffs over the field round the isle,
##             its near isles, clusters and pierced isle (`slots`), none
##             laid in a tower, an isle or on the isle (`blocked`), thinning
##             away over the KEEPS places nearest the eye (`keep`).
##   tearing   the player's plane (while flying) and every CPU plane traced
##             through the cloud each frame: a tunnel, tufts dragged along,
##             a burst on the way out, on the puffs and in the towers.
##
## It runs its own frame after the sky's (made after the traffic, so the
## planes have flown). The CPU planes are flown through its puffs (`hook`).
## --no-sky-clouds leaves it out; the old game's tower flags
## (--tower-pace=N, --tower-age=S, --still-towers) work here.

const IsleLock = preload("res://scripts/isle_lock.gd")

## The towers' middles (world x, z; y 0, the towers' own frame standing at
## the origin as the old game's cells' do). The first is the one in sight
## of the isle, south of it over the open sea 790 m off.
const TOWERS := [Vector3(-100.0,0.0,750.0),Vector3(-1100.0,0.0,400.0),Vector3(1350.0,0.0,-200.0),Vector3(-600.0,0.0,-1000.0)]
## A tower's middle keeps this far (m, flat) from anything the sky lays
## (SkyTowers KEEP, the old game's own keep).
const KEEP := SkyTowers.KEEP
## A cluster's spread round its middle (m) and the pierced isle's.
const CLUSTER_REACH := 120.0
const PIERCED_REACH := 120.0
## The chain's line runs this far past the ring (m).
const CHAIN_RUN := 1500.0
## The puffs keep this far (m) from an isle's edge and from the isle's.
const ISLE_CLEAR := 40.0

var scene: Node3D
var sky: Node3D

## The sky's clouds round `study`: its towers, its puffs, its wakes.
func setup_sky(study: Node3D, owner_sky: Node3D) -> void:
	scene = study
	sky = owner_sky
	# No thermals: the kit's air has no currents to lift the plane.
	setup(spots(),slots(),blocked,null)
	keep = keeps()

# --- Where they stand --------------------------------------------------------------

## The isle's circle (x, z its middle, z its radius; kit_isle `isle_circle`).
func isle() -> Vector3:
	if scene != null and scene.has_method("isle_circle"): return scene.isle_circle()
	return Vector3(sky.MIDDLE.x,sky.MIDDLE.z,60.0)

## The lock's widest ring round the isle (m, radius).
func lock_reach() -> float:
	return maxf(isle().z+IsleLock.CLEAR,IsleLock.RING_LEAST)+IsleLock.RING_OUT

## The line the lodestone's chain flies out along (flat): from the isle's
## middle to its ring (or the shard, with no chain) and CHAIN_RUN m on.
## Empty with neither.
func chain_line() -> Array:
	if scene == null: return []
	var to: Variant = null
	var chain: Variant = scene.get("isle_chain")
	if chain is Node and chain.get("ring_at") is Vector3: to = chain.ring_at
	elif scene.get("lodestone") != null and scene.get("lode_target") is Vector3: to = scene.lode_target
	if to == null: return []
	var c := isle()
	var a := Vector2(c.x,c.y)
	var b := Vector2((to as Vector3).x,(to as Vector3).z)
	if a.distance_to(b) < 1.0: return []
	return [a,b+(b-a).normalized()*CHAIN_RUN]

## TOWERS, less any that would stand in the way (see the head).
func spots() -> Array:
	var out := []
	for at: Vector3 in TOWERS:
		if clear_of_play(at) == "": out.append(at)
	return out

## What a tower's middle would stand in ("" for nothing): the lock ring,
## an isle, a cluster, the pierced isle or the chain's line.
func clear_of_play(at: Vector3) -> String:
	var flat := Vector2(at.x,at.z)
	var c := isle()
	if flat.distance_to(Vector2(c.x,c.y)) < lock_reach()+KEEP: return "lock ring"
	for spec: Array in sky.ISLES:
		var home: Vector3 = spec[3]
		if flat.distance_to(Vector2(home.x,home.z)) < float(spec[4])+KEEP: return "isle "+str(spec[0])
	for cluster: Array in sky.CLUSTERS:
		var middle: Vector3 = cluster[2]
		if flat.distance_to(Vector2(middle.x,middle.z)) < CLUSTER_REACH+KEEP: return "cluster "+str(cluster[0])
	var pierced: Vector3 = sky.PIERCED[1]
	if flat.distance_to(Vector2(pierced.x,pierced.z)) < PIERCED_REACH+KEEP: return "pierced isle"
	var line := chain_line()
	if not line.is_empty() and _to_segment(flat,line[0],line[1]) < KEEP: return "chain"
	return ""

## The puffs' field: the isle, its near isles (the plate's grid), the
## clusters and the pierced isle.
func slots() -> Array:
	var c := isle()
	var out := [Vector3(c.x,0.0,c.y)]
	for spec: Array in sky.ISLES:
		if float(spec[5]) < 2.0: out.append(spec[3])
	for cluster: Array in sky.CLUSTERS: out.append(cluster[2])
	out.append(sky.PIERCED[1])
	return out

## No puff on the isle, an isle or in a tower.
func blocked(at: Vector3) -> bool:
	var flat := Vector2(at.x,at.z)
	var c := isle()
	if flat.distance_to(Vector2(c.x,c.y)) < c.z+ISLE_CLEAR: return true
	for spec: Array in sky.ISLES:
		var home: Vector3 = spec[3]
		if flat.distance_to(Vector2(home.x,home.z)) < float(spec[4])+ISLE_CLEAR: return true
	return towers != null and towers.keeps(at,SkyClouds.SIZE.y)

## The places the puffs thin away over (Vector4(x, z, 0, radius)): the
## isle, the far isles, the clusters, the pierced isle.
func keeps() -> Array:
	var c := isle()
	var out := [Vector4(c.x,c.y,0.0,c.z+ISLE_CLEAR)]
	for spec: Array in sky.ISLES:
		var home: Vector3 = spec[3]
		out.append(Vector4(home.x,home.z,0.0,float(spec[4])+ISLE_CLEAR))
	for cluster: Array in sky.CLUSTERS:
		var middle: Vector3 = cluster[2]
		out.append(Vector4(middle.x,middle.z,0.0,CLUSTER_REACH))
	var pierced: Vector3 = sky.PIERCED[1]
	out.append(Vector4(pierced.x,pierced.z,0.0,PIERCED_REACH))
	return out

static func _to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b-a
	var t := clampf((p-a).dot(ab)/maxf(ab.length_squared(),0.001),0.0,1.0)
	return p.distance_to(a+ab*t)

# --- Each frame ---------------------------------------------------------------------

## The fliers this frame: the player's plane while it flies, and every CPU
## plane ([id, position, velocity], global).
func fliers() -> Array:
	var out := []
	if scene.get("flying") and scene.get("plane") != null:
		out.append(["eye",scene.plane.position,scene.plane.velocity])
	var traffic: Variant = sky.get("traffic")
	if traffic is Node:
		for i in range(traffic.planes.size()):
			var flight: RefCounted = traffic.planes[i].flight
			out.append([i,flight.position,flight.velocity])
	return out

func _process(delta: float) -> void:
	if scene == null or scene.get("camera") == null: return
	step(delta,scene.camera.global_position,float(scene.get("_motion_time")),fliers())
