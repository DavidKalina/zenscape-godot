extends "res://tools/landscapes/harness.gd"
## Meandering river valley: a broad paddle swell for high ground at the head,
## an S-curve paddle sweep down the plate into a sunk lake, a thumb-groove
## tributary, water poured at the head, willows and reeds on the banks.
## Tests: does water follow a long carved channel, does the meander read.

const HEAD := Vector2(0.0,-9.5)
const LAKE := Vector2(1.0,8.0)
const RIVER := [Vector2(0.0,-9.0),Vector2(2.6,-6.5),Vector2(2.4,-3.5),Vector2(-1.2,-1.2),
	Vector2(-2.6,1.6),Vector2(-1.0,4.2),Vector2(1.0,6.4)]
const BROOK := [Vector2(-8.0,-6.0),Vector2(-6.0,-4.0),Vector2(-4.2,-2.4),Vector2(-2.2,-1.2)]

func title() -> String: return "river_valley"

func build() -> void:
	await still("start")
	await take_tool("paddle")
	await size(3)
	await hold_drag(HEAD,-70.0)
	await hold_drag(Vector2(-8.0,-7.0),-45.0)
	await hold_drag(LAKE,55.0)
	heights_at({"head":HEAD,"west":Vector2(-8,-7),"lake":LAKE})
	await size(2)
	await drag(RIVER,2.5)
	heights_at({"r0":RIVER[0],"r2":RIVER[2],"r4":RIVER[4],"r6":RIVER[6],"lake":LAKE})
	await take_tool("hand")
	await size(2)
	await drag(BROOK,2.0)
	measure_verbs()
	await overview()
	await still("shaped")
	await pour(HEAD+Vector2(0,0.5),3.0)
	await pour(BROOK[0],2.0)
	await put_down()
	await let_world_run(20.0)
	measure_water("lake",LAKE,4.0)
	measure_water("channel mid",RIVER[3],2.0)
	measure_water("whole plate",Vector2.ZERO,30.0)
	await still("water")
	await sow("willow",[RIVER[3]+Vector2(-1.5,0),RIVER[4]+Vector2(-1.8,0),RIVER[5]+Vector2(-1.5,0.5)])
	await sow("oak",[Vector2(7,-4),Vector2(9,0),Vector2(8,3)])
	await set_down("reed",[LAKE+Vector2(-3,0),LAKE+Vector2(3,-1),LAKE+Vector2(0,3)])
	await put_down()
	await let_world_run(30.0)
	measure_water("lake",LAKE,4.0)
	measure_life("plate")
	measure_life("lake",LAKE,5.0)
	await overview()
	await still("overview")
	await view(Vector2(0,-2),18.0,scene.yaw+0.9,1.2)
	await still("valley-low")
	await view(LAKE,11.0,scene.yaw-0.5,1.05)
	await still("lake")
