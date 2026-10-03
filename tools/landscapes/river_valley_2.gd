extends "res://tools/landscapes/harness.gd"
## River valley, take 2: a river that runs along a carved meander into a lake.
## Take 1 (river_valley.gd) found the spring took its own steepest way down a
## huge size-3 swell, the paddle sweep's 0.45 m trough could not hold it, and
## spruce took the plate. Here: a modest head (size 2 swell, ~2 m), a lake
## sunk at the foot, then the Wire's gorge drawn along the S from the head into
## the lake (its bed never climbs, so water should run its length), with a
## Paddle sweep over it to open the valley shoulders. Water as a spring on the
## head just above the gorge's top. Willows and reeds sown, oak seeds on the
## shoulders. Take 3 (2026-10-02, the Paddle's swell and sweep gone): the head
## scrubbed with the Hills, the lake a Ravine loop, the two grooves kept, and
## the valley opened by a shallow Ravine along the S.

const HEAD := Vector2(0.0,-10.0)
const LAKE := Vector2(1.0,8.0)
const RIVER := [Vector2(0.0,-9.0),Vector2(2.6,-6.5),Vector2(2.4,-3.5),Vector2(-1.2,-1.2),
	Vector2(-2.6,1.6),Vector2(-1.0,4.2),Vector2(1.0,6.8)]

func title() -> String: return "river_valley_2"
func budget() -> float: return 900.0

var yaw0 := 0.0

func look(label: String, p: Vector2, distance: float, yaw_off: float, polar: float) -> void:
	await view(p,distance,yaw0+yaw_off,polar)
	await still(label)

func river_heights(label: String) -> void:
	var parts: PackedStringArray = []
	for i in range(RIVER.size()): parts.append("r%d %.2f" % [i,height(RIVER[i])])
	log_line("%s: %s, lake %.2f" % [label,", ".join(parts),height(LAKE)])

func build() -> void:
	yaw0 = scene.yaw
	await take_tool("hills")
	await size(2)
	await scrub_to(HEAD,2.2)
	await take_tool("wire")
	await size(3)
	await loop(LAKE,4.5,true)
	river_heights("swells")
	# Take 2: no Wire. Can the Modeller's thumb do it? Two slow grooves down
	# the S (the second deepens the first), then the Paddle's sweep over them
	# to open the valley shoulders.
	await take_tool("hand")
	await take_mode("groove")
	await size(2)
	await drag(RIVER,2.5)
	river_heights("groove 1")
	await drag(RIVER,2.5)
	river_heights("groove 2")
	await take_tool("wire")
	await size(3)
	await drag(RIVER,2.5,true)
	await settle()
	river_heights("ravine")
	measure_verbs()
	await look("carved",Vector2(0,-1),20.0,0.0,0.9)
	# The spring: on the head, just uphill of the gorge's top.
	await pour(HEAD+Vector2(0,0.3),3.0)
	await put_down()
	await let_world_run(20.0)
	for i in range(1,RIVER.size()): measure_water("river r%d" % i,RIVER[i],1.5)
	measure_water("lake",LAKE,4.0)
	measure_water("whole plate",Vector2.ZERO,30.0)
	await look("water",Vector2(0,-1),20.0,0.0,0.9)
	await sow("willow",[RIVER[3]+Vector2(-1.8,0),RIVER[4]+Vector2(-2.0,0),RIVER[5]+Vector2(-1.8,0.5)])
	await sow("oak",[Vector2(7,-4),Vector2(8,0),Vector2(7,3)])
	await set_down("reed",[LAKE+Vector2(-3,0),LAKE+Vector2(3,-1),RIVER[4]+Vector2(1.4,0)])
	await put_down()
	await let_world_run(25.0)
	for i in [2,4,6]: measure_water("river r%d" % i,RIVER[i],1.5)
	measure_water("lake",LAKE,4.0)
	measure_life("plate")
	measure_life("lake",LAKE,5.0)
	await overview()
	await still("overview")
	await look("valley-low",Vector2(0,-2),16.0,0.9,1.2)
	await look("meander",Vector2(0,-1),26.0,0.0,0.9)
	await look("lake",LAKE,10.0,-0.5,1.05)
	# The same plate at noon, to see the water without the morning mist.
	scene._celestial.set_phase(0.5)
	await seconds(1.0)
	await look("meander-noon",Vector2(0,-1),26.0,0.0,0.9)
