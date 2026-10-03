extends "res://tools/landscapes/harness.gd"
## Pastoral downs: rolling gentle hills scrubbed up with the Hills (1-2.5 m;
## Paddle swells until they went, 2026-10-02) with pats between them, drifts of wildflowers and dandelions over the slopes, an oak
## or two on a crest, and a little pond in a dip. The Feather blows wind
## across. Tests: does the gentle end look different from a fresh plate; how
## does wind read in stills.

const HILLS := [[Vector2(-6.0,-7.0),2.4],[Vector2(5.0,-5.0),1.6],[Vector2(-4.0,4.0),1.2],[Vector2(7.0,6.0),1.8]]
const POND := Vector2(1.5,2.5)

func title() -> String: return "pastoral_downs"
func budget() -> float: return 900.0

var yaw0 := 0.0

func look(label: String, p: Vector2, distance: float, yaw_off: float, polar: float) -> void:
	await view(p,distance,yaw0+yaw_off,polar)
	await still(label)

## A Feather drag that saves a still halfway along while the wind is still
## blowing (the harness's still() moves the pointer to the sky first, which
## would end the wake). The pointer and the feather prop are in this shot.
func feather_with_still(path: Array, speed: float) -> void:
	var points: Array[Vector2] = []
	for p: Vector2 in path: points.append(screen(p))
	await glide(points[0],25)
	button(pointer,true)
	await frames(2)
	for i in range(path.size()-1):
		var steps := maxi(1,int((path[i] as Vector2).distance_to(path[i+1])/speed*60.0))
		for k in range(steps):
			move(points[i].lerp(points[i+1],float(k+1)/steps),true)
			await frames(1)
		if i == 1 and DisplayServer.get_name() != "headless":
			shot += 1
			var file := out_dir.path_join("%02d-wind-mid-drag.png" % shot)
			RenderingServer.force_draw(false)
			root.get_texture().get_image().save_png(file)
			log_line("still %s (mid-drag, HUD and pointer showing)" % file.get_file())
	await frames(2)
	button(pointer,false)
	await frames(2)
	await settle()

func build() -> void:
	yaw0 = scene.yaw
	await look("fresh",Vector2.ZERO,20.0,0.0,1.0)
	await take_tool("hills")
	await size(3)
	for h: Array in HILLS: await scrub_to(h[0],h[1],2.5)
	# Pats on the saddles soften the joins.
	await take_tool("paddle")
	await take_mode("pat")
	for p: Vector2 in [Vector2(0,-6),Vector2(1,0),Vector2(-6,-1)]: await tap(p)
	# Take 2: back to the overview first (take 1's pond hollow, pressed from
	# the close view after the pats, never took: 402 px of pull, no swell).
	# Take 3: the pond is a small Modeller dip (the paddle's hollow is gone).
	await overview()
	await take_tool("hand")
	await take_mode("pinch")
	await size(2)
	await hold_to(POND,height(POND)-0.8)
	heights_at({"h1":HILLS[0][0],"h2":HILLS[1][0],"h3":HILLS[2][0],"h4":HILLS[3][0],"pond":POND,"saddle":Vector2(0,-6)})
	measure_verbs()
	await look("downs",Vector2.ZERO,26.0,0.0,1.0)
	await look("downs-side",Vector2(0,0),24.0,1.2,1.3)
	await overview()
	await pour(POND,1.5)
	await sow("wildflower",[Vector2(-9,-4),Vector2(-6,-3),Vector2(-3,-5)],3.0)
	await sow("wildflower",[Vector2(3,-2),Vector2(6,-1),Vector2(8,-3)],3.0)
	await sow("dandelion",[Vector2(-7,7),Vector2(-3,8),Vector2(0,7)],3.0)
	await sow("dandelion",[Vector2(4,9),Vector2(8,10)],3.0)
	await set_down("wildflower",[POND+Vector2(-2.5,0),POND+Vector2(2.5,0.5)])
	# Take 2: one short flick of oak only (take 1's two flicks plus the world's
	# own seeding gave ~100 trees and a forest, not downs).
	await sow("oak",[HILLS[0][0]+Vector2(1,0),HILLS[0][0]+Vector2(1.6,0.4)],4.0)
	await put_down()
	await let_world_run(12.0)
	measure_water("pond",POND,3.0)
	measure_life("plate")
	measure_life("west hill",HILLS[0][0],4.0)
	measure_life("east hill",HILLS[3][0],4.0)
	await look("meadow",Vector2(0,0),26.0,0.0,1.0)
	await look("flowers-close",Vector2(-6,-3.5),8.0,0.2,1.15)
	# The Feather: two long drags across the downs, a still mid-gust.
	await overview()
	await take_tool("feather")
	await size(3)
	await feather_with_still([Vector2(-11,-2),Vector2(-3,0),Vector2(5,1),Vector2(11,3)],8.0)
	await drag([Vector2(-11,4),Vector2(0,6),Vector2(11,7)],8.0)
	log_line("feather sent: %s" % [materials.feather_sent])
	await look("wind",Vector2(-1,2),18.0,0.3,1.15)
	await frames(30)
	await still("wind-after")
	await put_down()
	await let_world_run(6.0)
	await overview()
	await still("overview")
	await look("downs-low",Vector2(-2,0),22.0,0.7,1.3)
	await look("pond",POND,8.0,-0.3,1.05)
