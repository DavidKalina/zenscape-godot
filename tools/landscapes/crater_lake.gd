extends "res://tools/landscapes/harness.gd"
## Crater lake: a broad paddle swell, a wide shallow Chisel pit in its crown,
## filled to the brim with two pours. Take 1: a size-2 Chisel pit 2 m deep,
## one pour: a sheer-walled well with the water a metre under the lip. Take 2:
## a Modeller pinch pulled down: a soft bowl that read as a pond on a hill. Tests: does a lake stand above the surrounding land.

const HILL := Vector2(1.0,0.0)

func title() -> String: return "crater_lake"

func build() -> void:
	await still("start")
	await take_tool("paddle")
	await size(3)
	await hold_to(HILL,4.5)
	heights_at({"crown":HILL,"crown+2":HILL+Vector2(2,0),"shoulder":HILL+Vector2(5,0),"foot":HILL+Vector2(9,0)})
	await take_tool("chisel")
	await size(3)
	await hold_to(HILL,height(HILL)-1.3)
	heights_at({"floor":HILL,"rim n":HILL+Vector2(0,-4.6),"rim s":HILL+Vector2(0,4.6),"rim e":HILL+Vector2(4.6,0),"rim w":HILL+Vector2(-4.6,0),"foot":HILL+Vector2(9,0)})
	measure_verbs()
	await overview()
	await still("shaped")
	await view(HILL,15.0,scene.yaw,0.9)
	await still("crater")
	await pour(HILL,3.0)
	await let_world_run(4.0)
	measure_water("crater after one pour",HILL,4.0)
	await pour(HILL+Vector2(0.5,0.5),3.0)
	await put_down()
	await let_world_run(15.0)
	measure_water("crater",HILL,4.0)
	measure_water("whole plate",Vector2.ZERO,30.0)
	await view(HILL,15.0,scene.yaw,0.9)
	await still("lake")
	await overview()
	await still("overview")
	await view(HILL,20.0,scene.yaw+0.9,1.3)
	await still("low")
