extends "res://tools/landscapes/harness.gd"
## Marsh delta: a low, wide flat (Paddle pats, a Modeller palm or two), a low
## rise at the head scrubbed up with the Hills for a spring, then shallow
## braided channels drawn with the Modeller's thumb at the smallest pip (the
## Paddle's narrow sweep until it went, 2026-10-02). Water from a spring at the head and a
## burst on the flat; reeds, cattails and wildflowers along the braids.
## Tests: can the gentle tools make a low marsh, does shallow water read.

const HEAD := Vector2(0.0,-10.0)
const FAN := Vector2(0.0,-6.5)
const FLAT := Vector2(0.0,2.5)
## Three braids fanning from the head's foot, and two cross links.
const BRAID_W := [FAN,Vector2(-2.0,-3.0),Vector2(-4.5,0.5),Vector2(-5.0,4.0),Vector2(-6.5,8.0)]
const BRAID_M := [FAN,Vector2(0.6,-2.5),Vector2(-0.5,1.5),Vector2(0.8,5.0),Vector2(0.0,9.0)]
const BRAID_E := [FAN,Vector2(2.5,-3.5),Vector2(4.5,0.0),Vector2(4.0,4.0),Vector2(6.0,8.0)]
const LINK_A := [Vector2(-4.5,0.5),Vector2(-2.0,1.0),Vector2(-0.5,1.5)]
const LINK_B := [Vector2(0.8,5.0),Vector2(2.5,4.2),Vector2(4.0,4.0)]

func title() -> String: return "marsh_delta"
func budget() -> float: return 900.0

func look(label: String, p: Vector2, distance: float, yaw_off: float, polar: float) -> void:
	await view(p,distance,yaw0+yaw_off,polar)
	await still(label)

var yaw0 := 0.0

func build() -> void:
	yaw0 = scene.yaw
	# The low flat: a broad, shallow hollow over the south two-thirds, patted level.
	# Take 3: no sunk hollow (take 2's hollow plus three pours flooded the
	# braids into one 1.3 m deep pond); the flat stays at plate level.
	await take_tool("hills")
	await size(3)
	await scrub_to(HEAD,1.9)
	await take_tool("paddle")
	await take_mode("pat")
	for p: Vector2 in [Vector2(-5,0),Vector2(0,0),Vector2(5,0),Vector2(-5,5),Vector2(0,5),Vector2(5,5),Vector2(0,9)]:
		await tap(p)
	await take_tool("hand")
	await take_mode("groove")
	await size(3)
	await drag([Vector2(-3,6),Vector2(3,6)],2.0,true)
	heights_at({"head":HEAD,"fan":FAN,"flat":FLAT,"w":Vector2(-5,4),"e":Vector2(4,4),"south":Vector2(0,9)})
	await overview()
	await still("flat")
	# Take 2: the braids with the paddle's narrow blade (Shift sweep, 0.45 m),
	# since take 1's thumb grooves at the smallest pip were 0.75 m trenches.
	# Take 3: the thumb again, now that its groove is a 0.6 m stream bed.
	await size(1)
	await drag(BRAID_W,2.5)
	await drag(BRAID_M,2.5)
	await drag(BRAID_E,2.5)
	await drag(LINK_A,2.0)
	await drag(LINK_B,2.0)
	# A fast thumb rub over the islands between the braids to soften the ridges.
	await size(2)
	await drag([Vector2(-3,2),Vector2(-1.5,3.5),Vector2(-3,4.5),Vector2(-1.5,6),Vector2(-3,7)],30.0)
	await drag([Vector2(2,2),Vector2(3.5,3),Vector2(2,4),Vector2(3.5,6),Vector2(2,7)],30.0)
	measure_verbs()
	heights_at({"w1":BRAID_W[2],"w2":BRAID_W[3],"m1":BRAID_M[2],"m2":BRAID_M[3],"e1":BRAID_E[2],"e2":BRAID_E[3],"between":Vector2(-2.2,3.5)})
	await look("braids",Vector2(0,1),26.0,0.0,0.95)
	# Water: a spring on the head's rise, and a burst on the flat.
	# Take 3: water from one small spring only, so it stays shallow.
	await pour(HEAD+Vector2(0,1.2),1.5)
	await put_down()
	await let_world_run(20.0)
	measure_water("west braid",BRAID_W[3],1.5)
	measure_water("mid braid",BRAID_M[3],1.5)
	measure_water("east braid",BRAID_E[3],1.5)
	measure_water("flat",FLAT,8.0)
	measure_water("whole plate",Vector2.ZERO,30.0)
	await look("water",Vector2(0,1),26.0,0.0,0.95)
	await set_down("reed",[BRAID_W[2]+Vector2(0.9,0),BRAID_W[3]+Vector2(-0.9,0),BRAID_M[3]+Vector2(0.9,0.3),BRAID_E[2]+Vector2(-0.9,0),BRAID_E[3]+Vector2(1.0,0)])
	await sow("reed",[Vector2(-2.0,6.5),Vector2(2.0,7.0)],3.0)
	await set_down("wildflower",[Vector2(-7,-2),Vector2(7,-1),Vector2(-2.5,-4.5)])
	await sow("wildflower",[Vector2(6,2),Vector2(8,6)],3.0)
	await put_down()
	await let_world_run(25.0)
	measure_water("flat",FLAT,8.0)
	measure_water("whole plate",Vector2.ZERO,30.0)
	measure_life("plate")
	measure_life("flat",FLAT,8.0)
	await overview()
	await still("overview")
	await look("marsh-low",Vector2(0,3),18.0,0.6,1.2)
	await look("braids-close",Vector2(-2,2),12.0,-0.4,1.05)
	scene._celestial.set_phase(0.5)
	await seconds(1.0)
	await look("marsh-noon",Vector2(0,1),26.0,0.0,0.95)
