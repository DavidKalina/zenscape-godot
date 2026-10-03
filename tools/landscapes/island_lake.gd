extends "res://tools/landscapes/harness.gd"
## Island lake: a broad basin (a loop drawn with the Ravine; a Paddle swell
## pulled down until the swell went, 2026-10-02), one island pinched up in it
## with the Modeller, an oak sown on the island, water poured round
## it. Then the levee test: a Chisel drag pressed on the shore and run across
## the lake's near end, to see whether a shelf set above the ground can stand
## as a dam (a line-raising verb is a suspected gap).

const BASIN := Vector2(0.0,-1.0)
const ISLAND := Vector2(1.5,-1.5)
const DAM_Z := 4.0

func title() -> String: return "island_lake"

func line(label: String, z: float) -> void:
	var parts: PackedStringArray = []
	for i in range(13):
		parts.append("%.2f" % height(Vector2(-12.0+2.0*i,z)))
	log_line("row %s z=%+.1f x -12..12: %s" % [label,z," ".join(parts)])

func build() -> void:
	await take_tool("wire")
	await size(3)
	await loop(BASIN,7.0,true)
	line("basin",BASIN.y)
	line("basin near",DAM_Z)
	# Take 1 pinched the island with the Modeller (hold_to 1.6 m): a steep bare
	# cone the sown oak could not stay on. Take 2: a narrow Paddle swell, lower.
	# Take 3: the Modeller again, now that its pinch is small (a 0.7 m knoll).
	await take_tool("hand")
	await take_mode("pinch")
	await size(2)
	await hold_to(ISLAND,height(ISLAND)+0.7)
	heights_at({"island":ISLAND,"island+2":ISLAND+Vector2(2,0),"island-2":ISLAND-Vector2(2,0),"basin":BASIN+Vector2(-4,0)})
	line("island",ISLAND.y)
	measure_verbs()
	await overview()
	await still("shaped")
	await sow("oak",[ISLAND+Vector2(-1.0,0.2),ISLAND+Vector2(1.0,-0.2)],2.0)
	await seconds(2.0)
	measure_life("island just after sowing",ISLAND,2.0)
	await pour(BASIN+Vector2(-5.0,1.0),3.0)
	await pour(BASIN+Vector2(4.0,3.5),3.0)
	await put_down()
	await let_world_run(20.0)
	measure_water("lake",BASIN,9.0)
	measure_water("island top",ISLAND,0.8)
	measure_water("near lobe",Vector2(0.0,6.0),2.5)
	measure_life("island",ISLAND,2.0)
	await overview()
	await still("lake")
	await view(ISLAND,12.0,scene.yaw+0.3,1.15)
	await still("island")
	# The levee test: a chisel drag pressed on the west shore, run east across
	# the lake's near end.
	await overview()
	await take_tool("chisel")
	await size(2)
	# Take 2: a player who wants the dam to stand proud first heaps a mound on
	# the shore (narrow Paddle swell) and presses the chisel on its top.
	# Take 2's mound and dam presses both did nothing; take 3 logs what stands
	# under the press and, as a player would, tries again a step aside.
	var shore := Vector2(-9.5,DAM_Z)
	await take_tool("hand")
	await take_mode("pinch")
	await size(1)
	for attempt in range(3):
		log_line("under the press at %s: %s, hover reach '%s'" % [shore,life_near(shore,0.9),reach.reach_at(screen(shore))])
		var before := worked.size()
		await hold_to(shore,1.4)
		if worked.size() > before: break
		shore += Vector2(0.7,-0.7)
	heights_at({"mound":shore})
	await take_tool("chisel")
	await take_mode("shelf")
	await size(2)
	log_line("dam press ground %.2f" % height(shore))
	line("before dam",DAM_Z)
	await drag([shore,Vector2(-4.0,DAM_Z),Vector2(4.0,DAM_Z),Vector2(9.5,DAM_Z)],3.0)
	line("after dam",DAM_Z)
	line("after dam, 1.5 near",DAM_Z+1.5)
	measure_verbs()
	await put_down()
	await pour(BASIN+Vector2(-3.0,-4.0),3.0)
	await put_down()
	await let_world_run(20.0)
	measure_water("lake",BASIN,9.0)
	measure_water("behind dam",Vector2(0.0,DAM_Z-2.0),2.0)
	measure_water("below dam",Vector2(0.0,DAM_Z+2.5),2.0)
	measure_life("island",ISLAND,2.0)
	measure_life("plate")
	await overview()
	await still("dammed")
	await view(Vector2(0.0,DAM_Z),14.0,scene.yaw+0.2,1.1)
	await still("dam")
