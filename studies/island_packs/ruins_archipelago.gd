extends RefCounted
## Ruins archipelago: floating islands of an old city's ruins, greyboxed
## for platforming, in the character study's station format
## (studies/character_study.gd STATIONS, plus "obox"). Each station is one
## arrangement a ruin could really leave behind, built from a few pieces
## (columns, piers, wall runs, slabs, steps), with an easy way through and
## an expert line on other moves. Grey "wall" is standing stone, "floor"
## the ground, orange "lip" a top made to land on or hang from, "dark"
## fallen and broken stone, green "pad" moss. The stations stand 100 m
## apart along x (station k round x 100(k-1)), every island's top at 30 m
## over a stepped keel of rock; LOST is 5 m. The numbers are measured against
## scripts/pilot_motor.gd; docs/design/island-packs/ruins_archipelago.md
## lists them, and tests/test_island_pack_ruins_archipelago.gd drives a
## route through each.
##   ./run-character-study.command --pack=ruins_archipelago

const NAME := "Ruins archipelago"
const START := Vector3(0.0,30.0,2.0)
const START_FACE := Vector2(0.0,-1.0)
const LOST := 5.0

const STATIONS := [
	# The temple precinct: a processional avenue 6 m wide between columns
	# 1.2 m across at 5 m (3.8 m clear between them), a field of columns on
	# a 6 m stagger either side with fallen ones lying 0.9 m high, and at
	# its end the temple: three 0.45 m steps up to its floor 1.35 m up, the
	# cella's front wall broken in steps (1.2, 2.4, the door's lintel 3.0,
	# 3.6, 4.8 m over the floor) with a 2 m door through it.
	{"key":1,"name":"Temple avenue · columns, a broken wall","spawn":Vector3(0.0,30.0,2.0),"face":Vector2(0.0,-1.0),"sign":Vector3(-4.0,33.5,1.0),"parts":[
		["box",Rect2(-20.0,-43.0,40.0,48.0),24.0,30.0,"floor"],
		["box",Rect2(-15.0,-37.0,30.0,36.0),18.0,24.0,"dark"],
		["box",Rect2(-8.0,-29.0,16.0,20.0),11.0,18.0,"dark"],
		# The avenue's colonnade, a broken one 2.4 m and one 4 m.
		["cyl",Vector2(-3.6,-4.0),0.6,30.0,38.0,"wall"],["cyl",Vector2(3.6,-4.0),0.6,30.0,36.0,"wall"],
		["cyl",Vector2(-3.6,-9.0),0.6,30.0,36.0,"wall"],["cyl",Vector2(3.6,-9.0),0.6,30.0,38.0,"wall"],
		["cyl",Vector2(-3.6,-14.0),0.6,30.0,38.0,"wall"],["cyl",Vector2(3.6,-14.0),0.6,30.0,34.0,"lip"],
		["cyl",Vector2(-3.6,-19.0),0.6,30.0,32.4,"lip"],["cyl",Vector2(3.6,-19.0),0.6,30.0,38.0,"wall"],
		["cyl",Vector2(-3.6,-24.0),0.6,30.0,38.0,"wall"],["cyl",Vector2(3.6,-24.0),0.6,30.0,36.0,"wall"],
		["label",Vector3(0.0,30.6,-6.5),"avenue 6 m · columns 5 m apart, 3.8 m clear"],
		# The field west, on a 6 m stagger, gaps where columns fell.
		["cyl",Vector2(-9.0,-6.0),0.6,30.0,36.0,"wall"],["cyl",Vector2(-9.0,-18.0),0.6,30.0,38.0,"wall"],
		["cyl",Vector2(-9.0,-24.0),0.6,30.0,31.2,"lip"],["cyl",Vector2(-15.0,-3.0),0.6,30.0,38.0,"wall"],
		["cyl",Vector2(-15.0,-15.0),0.6,30.0,36.0,"wall"],["cyl",Vector2(-15.0,-21.0),0.6,30.0,38.0,"wall"],
		["cyl",Vector2(-15.0,-27.0),0.6,30.0,34.0,"wall"],
		["obox",Vector3(-12.0,30.45,-10.5),Vector3(5.4,0.9,0.9),35.0,"dark"],
		["obox",Vector3(-6.5,30.5,-28.5),Vector3(1.2,1.0,1.2),20.0,"dark"],
		["obox",Vector3(-17.5,30.5,-9.0),Vector3(1.2,1.0,1.2),-10.0,"dark"],
		# The field east.
		["cyl",Vector2(9.0,-6.0),0.6,30.0,38.0,"wall"],["cyl",Vector2(9.0,-12.0),0.6,30.0,36.0,"wall"],
		["cyl",Vector2(9.0,-24.0),0.6,30.0,38.0,"wall"],["cyl",Vector2(15.0,-3.0),0.6,30.0,36.0,"wall"],
		["cyl",Vector2(15.0,-9.0),0.6,30.0,38.0,"wall"],["cyl",Vector2(15.0,-21.0),0.6,30.0,32.4,"lip"],
		["cyl",Vector2(15.0,-27.0),0.6,30.0,38.0,"wall"],
		["obox",Vector3(12.5,30.45,-17.0),Vector3(6.0,0.9,0.9),-25.0,"dark"],
		["obox",Vector3(6.5,30.5,-15.5),Vector3(1.2,1.0,1.2),40.0,"dark"],
		["box",Rect2(-19.0,-2.0,4.0,5.0),30.0,30.1,"pad"],["box",Rect2(11.0,-31.0,7.0,4.0),30.0,30.1,"pad"],
		# The temple: its three steps, its floor (P 31.35).
		["box",Rect2(-12.0,-43.0,24.0,11.6),30.0,30.45,"floor"],
		["box",Rect2(-11.2,-43.0,22.4,10.8),30.0,30.9,"floor"],
		["box",Rect2(-10.4,-43.0,20.8,10.0),30.0,31.35,"lip"],
		["label",Vector3(0.0,31.0,-31.8),"steps 0.45 m · walk up"],
		# The cella's front wall, 0.8 m thick, broken in steps of 1.2 m,
		# the door 2 m wide and 2.4 m tall.
		["box",Rect2(-10.0,-38.6,4.0,0.8),31.35,32.55,"lip"],
		["box",Rect2(-6.0,-38.6,5.0,0.8),31.35,33.75,"lip"],
		["box",Rect2(-1.0,-38.6,2.0,0.8),33.75,34.35,"lip"],
		["box",Rect2(1.0,-38.6,4.0,0.8),31.35,34.95,"lip"],
		["box",Rect2(5.0,-38.6,5.0,0.8),31.35,36.15,"lip"],
		["label",Vector3(-8.0,33.0,-37.6),"1.2"],["label",Vector3(-3.5,34.2,-37.6),"2.4"],["label",Vector3(0.0,34.8,-37.6),"3.0 lintel"],
		["label",Vector3(3.0,35.4,-37.6),"3.6"],["label",Vector3(7.5,36.6,-37.6),"4.8"],
		# The porch columns before it and the colonnade behind, the
		# architrave still on two of them.
		["cyl",Vector2(-8.4,-35.0),0.6,31.35,39.35,"wall"],["cyl",Vector2(8.4,-35.0),0.6,31.35,33.75,"lip"],
		["cyl",Vector2(-8.0,-41.5),0.6,31.35,39.35,"wall"],["cyl",Vector2(-4.0,-41.5),0.6,31.35,39.35,"wall"],
		["cyl",Vector2(0.0,-41.5),0.6,31.35,37.35,"wall"],["cyl",Vector2(4.0,-41.5),0.6,31.35,35.35,"wall"],
		["cyl",Vector2(8.0,-41.5),0.6,31.35,37.35,"lip"],
		["box",Rect2(-8.8,-42.1,5.6,1.2),39.35,40.0,"dark"],
	]},
	# The aqueduct: a channel 2.4 m wide on piers 2 m thick, 6 m up,
	# arches 4 m wide and 4 m clear under it; its head a blind wall 12 m
	# long where the arches were walled up, reached up a 30° slope of
	# rubble where its end fell; across the sky to the next island on
	# hanging piers, one span fallen (3 m between its broken ends); down
	# rubble in 1.2 m drops at its far end. East of the blind wall a
	# buttress 2.6 m off it, 5.2 m tall: a wall run along the blind wall,
	# a kick off to the buttress, and kicks between them up to the channel.
	{"key":2,"name":"Aqueduct · a fallen span, a blind wall","spawn":Vector3(100.0,30.0,9.0),"face":Vector2(0.0,-1.0),"sign":Vector3(95.0,33.5,8.0),"parts":[
		["box",Rect2(86.0,-24.0,28.0,34.0),24.0,30.0,"floor"],
		["box",Rect2(90.0,-20.0,20.0,26.0),18.0,24.0,"dark"],
		["box",Rect2(95.0,-14.0,10.0,14.0),12.0,18.0,"dark"],
		["box",Rect2(88.0,-62.0,24.0,22.0),24.0,30.0,"floor"],
		["box",Rect2(92.0,-58.0,16.0,14.0),18.0,24.0,"dark"],
		["box",Rect2(96.0,-54.0,8.0,8.0),13.0,18.0,"dark"],
		# The rubble slope up onto the head, 30°, and the blind wall.
		["ramp",Vector3(100.0,30.0,8.4),Vector3(100.0,36.0,-2.0),2.4,"dark"],
		["box",Rect2(98.8,4.4,2.4,2.0),30.0,31.1,"dark"],["box",Rect2(98.8,2.4,2.4,2.0),30.0,32.25,"dark"],
		["box",Rect2(98.8,0.4,2.4,2.0),30.0,33.4,"dark"],["box",Rect2(98.8,-2.0,2.4,2.4),30.0,34.55,"dark"],
		["label",Vector3(102.0,32.5,3.0),"rubble 30° · walk up"],
		["box",Rect2(98.8,-14.0,2.4,12.0),30.0,36.0,"lip"],
		["label",Vector3(102.0,36.6,-8.0),"channel 6 m"],
		# The arcade: piers, the arches' spandrels 34 to 36 m.
		["box",Rect2(98.8,-18.0,2.4,4.0),34.0,36.0,"lip"],
		["box",Rect2(98.8,-20.0,2.4,2.0),30.0,36.0,"lip"],
		["box",Rect2(98.8,-24.0,2.4,4.0),34.0,36.0,"lip"],
		["box",Rect2(98.8,-26.0,2.4,2.0),21.0,36.0,"lip"],
		["box",Rect2(98.8,-30.0,2.4,4.0),34.0,36.0,"lip"],
		["box",Rect2(98.8,-32.0,2.4,2.0),19.0,36.0,"lip"],
		["box",Rect2(98.8,-32.5,2.4,0.5),34.6,36.0,"dark"],
		["box",Rect2(98.8,-36.0,2.4,0.5),34.8,36.0,"dark"],
		["label",Vector3(100.0,36.6,-34.0),"fallen span 3 m"],
		["box",Rect2(98.8,-38.0,2.4,2.0),20.0,36.0,"lip"],
		["box",Rect2(98.8,-42.0,2.4,4.0),34.0,36.0,"lip"],
		["box",Rect2(98.8,-44.0,2.4,2.0),30.0,36.0,"lip"],
		# Its broken end, down in 1.2 m drops.
		["box",Rect2(98.8,-46.4,2.4,2.4),30.0,34.8,"dark"],
		["box",Rect2(98.8,-48.8,2.4,2.4),30.0,33.6,"dark"],
		["box",Rect2(98.8,-51.2,2.4,2.4),30.0,32.4,"dark"],
		["box",Rect2(98.8,-53.6,2.4,2.4),30.0,31.2,"dark"],
		# The buttress east of the blind wall, 2.6 m off it.
		["box",Rect2(103.8,-12.0,1.0,6.0),30.0,35.2,"lip"],
		["label",Vector3(104.3,35.7,-9.0),"buttress 5.2 m · 2.6 m off"],
		["label",Vector3(102.6,30.6,2.0),"run along the wall · jump · wall run · kick"],
		["box",Rect2(105.0,-22.0,6.0,5.0),30.0,30.1,"pad"],
	]},
	# The watchtower: 4.2 m square, walls 0.8 m, its shaft 2.6 m across (the
	# kicking width), cracked: its crown broken to 10 m (west), 8.8 (east),
	# the south wall 6 m over a door 1.4 m wide and 2.2 tall, the north wall
	# 7 m under a window 1.2 m wide. A slab split off the north face stands
	# 1.0 m out (the crack, a chimney slot: 0.44 m of travel for the body),
	# 5.4 m tall. Fallen blocks, 1.2 m a step, climb the east side to the
	# south wall's top.
	{"key":3,"name":"Cracked watchtower · the crack, the shaft","spawn":Vector3(207.0,30.0,0.0),"face":Vector2(0.0,-1.0),"sign":Vector3(204.0,33.5,1.0),"parts":[
		["box",Rect2(186.0,-28.0,28.0,32.0),24.0,30.0,"floor"],
		["box",Rect2(190.0,-24.0,20.0,24.0),18.0,24.0,"dark"],
		["box",Rect2(195.0,-19.0,10.0,12.0),12.0,18.0,"dark"],
		# The tower.
		["box",Rect2(197.9,-15.1,0.8,3.4),30.0,40.0,"lip"],
		["box",Rect2(201.3,-15.1,0.8,3.4),30.0,38.8,"lip"],
		["box",Rect2(198.7,-15.1,2.6,0.8),30.0,37.0,"lip"],
		["box",Rect2(198.7,-15.1,0.7,0.8),37.0,40.0,"lip"],["box",Rect2(200.6,-15.1,0.7,0.8),37.0,40.0,"lip"],
		["box",Rect2(199.4,-15.1,1.2,0.8),38.6,40.0,"lip"],
		["box",Rect2(197.9,-11.7,1.4,0.8),30.0,36.0,"lip"],["box",Rect2(200.7,-11.7,1.4,0.8),30.0,36.0,"lip"],
		["box",Rect2(199.3,-11.7,1.4,0.8),32.2,36.0,"lip"],
		["label",Vector3(200.0,32.6,-10.6),"door · the shaft 2.6 m, kick up"],
		["label",Vector3(198.3,40.5,-13.4),"10 m"],["label",Vector3(201.7,39.3,-13.4),"8.8 m"],
		["label",Vector3(200.0,37.4,-15.6),"window sill 7 m"],
		# The split slab and the crack behind it.
		["box",Rect2(198.4,-16.9,3.2,0.8),30.0,35.4,"lip"],
		["label",Vector3(197.6,31.0,-15.6),"the crack 1.0 m · kick up"],
		["label",Vector3(200.0,35.9,-16.5),"5.4 m"],
		# The fallen blocks up to the south wall, 1.2 m a step.
		["box",Rect2(202.1,-12.4,1.8,2.0),30.0,34.8,"dark"],
		["box",Rect2(204.5,-12.4,1.8,2.0),30.0,33.6,"dark"],
		["box",Rect2(206.9,-12.4,1.8,2.0),30.0,32.4,"dark"],
		["box",Rect2(209.3,-12.4,1.8,2.0),30.0,31.2,"dark"],
		["label",Vector3(210.2,31.6,-10.0),"1.2 m a step"],
		# Rubble round its foot, and moss.
		["obox",Vector3(194.5,30.4,-12.0),Vector3(1.6,0.8,1.2),25.0,"dark"],
		["obox",Vector3(196.0,30.3,-18.5),Vector3(1.0,0.6,1.4),-30.0,"dark"],
		["box",Rect2(190.0,-8.0,6.0,5.0),30.0,30.1,"pad"],
	]},
	# The sunken court: a cloister's garth 16 m square sunk 2.8 m (the side
	# flip's reach), its rim columns 3.2 m tall round it; a flight of 0.4 m
	# steps down its west side; in its middle the impluvium, a pool 6 m
	# across and 1 m deep, its water 0.2 m under the floor; a paving slab
	# fallen in from the north rim at 35° to surf down into a long jump
	# over the pool; an altar 1.4 m high 1.2 m off the east wall to climb
	# out by.
	{"key":4,"name":"Sunken court · a fallen slab, the pool","spawn":Vector3(300.0,30.0,-31.0),"face":Vector2(0.0,1.0),"sign":Vector3(304.0,33.5,-31.0),"parts":[
		["box",Rect2(284.0,-8.0,32.0,12.0),24.0,30.0,"floor"],
		["box",Rect2(284.0,-34.0,32.0,10.0),24.0,30.0,"floor"],
		["box",Rect2(284.0,-24.0,8.0,16.0),24.0,30.0,"floor"],
		["box",Rect2(308.0,-24.0,8.0,16.0),24.0,30.0,"floor"],
		["box",Rect2(288.0,-30.0,24.0,30.0),18.0,24.0,"dark"],
		["box",Rect2(294.0,-22.0,12.0,14.0),12.0,18.0,"dark"],
		# The court's floor round the pool, the pool.
		["box",Rect2(292.0,-24.0,16.0,5.0),24.0,27.2,"floor"],
		["box",Rect2(292.0,-13.0,16.0,5.0),24.0,27.2,"floor"],
		["box",Rect2(292.0,-19.0,5.0,6.0),24.0,27.2,"floor"],
		["box",Rect2(303.0,-19.0,5.0,6.0),24.0,27.2,"floor"],
		["box",Rect2(297.0,-19.0,6.0,6.0),24.0,26.0,"dark"],
		["water",Rect2(297.0,-19.0,6.0,6.0),26.0,27.0],
		["label",Vector3(300.0,27.6,-16.0),"pool 6 m"],
		# The rim's coping.
		["box",Rect2(291.4,-24.6,17.2,0.6),29.9,30.02,"lip"],["box",Rect2(291.4,-8.0,17.2,0.6),29.9,30.02,"lip"],
		["box",Rect2(291.4,-24.0,0.6,16.0),29.9,30.02,"lip"],["box",Rect2(308.0,-24.0,0.6,16.0),29.9,30.02,"lip"],
		["label",Vector3(306.0,30.5,-7.6),"rim 2.8 m · side flip"],
		# The steps down the west side, 0.4 m.
		["box",Rect2(292.0,-8.8,1.6,0.8),27.2,29.6,"floor"],["box",Rect2(292.0,-9.6,1.6,0.8),27.2,29.2,"floor"],
		["box",Rect2(292.0,-10.4,1.6,0.8),27.2,28.8,"floor"],["box",Rect2(292.0,-11.2,1.6,0.8),27.2,28.4,"floor"],
		["box",Rect2(292.0,-12.0,1.6,0.8),27.2,28.0,"floor"],["box",Rect2(292.0,-12.8,1.6,0.8),27.2,27.6,"floor"],
		# The fallen slab, 35°, rubble under it.
		["ramp",Vector3(300.0,27.2,-20.0),Vector3(300.0,30.0,-24.0),3.0,"dark"],
		["box",Rect2(298.5,-24.0,3.0,2.0),27.2,28.55,"dark"],["box",Rect2(298.5,-22.0,3.0,1.0),27.2,27.85,"dark"],
		["label",Vector3(302.4,29.0,-22.0),"slab 35° · crouch: surf · jump: long jump"],
		# The altar.
		["box",Rect2(305.2,-17.2,1.6,2.4),27.2,28.6,"lip"],
		["label",Vector3(306.0,29.0,-16.0),"altar 1.4 m"],
		# The cloister's columns round the rim, some broken.
		["cyl",Vector2(293.5,-25.6),0.35,30.0,33.2,"wall"],["cyl",Vector2(297.0,-25.6),0.35,30.0,33.2,"wall"],
		["cyl",Vector2(303.0,-25.6),0.35,30.0,31.4,"lip"],["cyl",Vector2(306.5,-25.6),0.35,30.0,33.2,"wall"],
		["cyl",Vector2(293.5,-6.4),0.35,30.0,33.2,"wall"],["cyl",Vector2(297.0,-6.4),0.35,30.0,32.0,"lip"],
		["cyl",Vector2(303.0,-6.4),0.35,30.0,33.2,"wall"],["cyl",Vector2(306.5,-6.4),0.35,30.0,33.2,"wall"],
		["cyl",Vector2(290.4,-21.0),0.35,30.0,33.2,"wall"],["cyl",Vector2(290.4,-11.0),0.35,30.0,33.2,"wall"],
		["cyl",Vector2(309.6,-21.0),0.35,30.0,33.2,"wall"],["cyl",Vector2(309.6,-16.0),0.35,30.0,31.0,"lip"],
		["cyl",Vector2(309.6,-11.0),0.35,30.0,33.2,"wall"],
		["obox",Vector3(312.0,30.3,-14.0),Vector3(3.0,0.6,0.7),70.0,"dark"],
		["box",Rect2(286.0,-4.0,5.0,6.0),30.0,30.1,"pad"],
	]},
	# The fallen bridge: a bridge's deck broken into islets between two
	# islands 31 m apart. East, its slabs 3 m square, 1.6 m apart (a running
	# jump goes 2.2), stepping 0.4 m up and down, a broken column on each.
	# West, its piers' caps, 1.8, 2.7, 3.7 and 4.8 m long with gaps of 3.3,
	# 3.3, 3.2 and 3.0 m: spaced from measured chains so a long jump chain
	# pressed anywhere up to 0.1 s after each landing lands on each cap and
	# leaves it before its end (hops of 4.2, 5.1, 5.9, 6.7 m); then 5.1 m to
	# the far island, which the chain's last hop clears, best twirled. On
	# the far island the gate the bridge led to, broken.
	{"key":5,"name":"Fallen bridge · islets, two lines","spawn":Vector3(400.0,30.0,3.0),"face":Vector2(0.0,-1.0),"sign":Vector3(400.0,33.5,4.0),"parts":[
		["box",Rect2(390.0,-4.0,20.0,10.0),24.0,30.0,"floor"],
		["box",Rect2(394.0,-2.0,12.0,6.0),18.0,24.0,"dark"],
		["box",Rect2(390.0,-50.9,20.0,16.0),24.0,30.0,"floor"],
		["box",Rect2(394.0,-46.9,12.0,10.0),18.0,24.0,"dark"],
		["box",Rect2(397.0,-43.9,6.0,5.0),13.0,18.0,"dark"],
		# East: the deck's slabs, the last a bigger piece.
		["box",Rect2(403.5,-8.6,3.0,3.0),28.0,30.0,"floor"],["box",Rect2(404.0,-8.1,2.0,2.0),25.0,28.0,"dark"],
		["box",Rect2(403.5,-13.2,3.0,3.0),28.4,30.4,"floor"],["box",Rect2(404.0,-12.7,2.0,2.0),25.4,28.4,"dark"],
		["box",Rect2(403.5,-17.8,3.0,3.0),28.8,30.8,"floor"],["box",Rect2(404.0,-17.3,2.0,2.0),25.8,28.8,"dark"],
		["box",Rect2(403.5,-22.4,3.0,3.0),28.4,30.4,"floor"],["box",Rect2(404.0,-21.9,2.0,2.0),25.4,28.4,"dark"],
		["box",Rect2(403.5,-27.0,3.0,3.0),28.0,30.0,"floor"],["box",Rect2(404.0,-26.5,2.0,2.0),25.0,28.0,"dark"],
		["box",Rect2(403.0,-33.3,3.6,4.7),28.0,30.0,"floor"],["box",Rect2(404.0,-32.5,2.0,3.0),24.0,28.0,"dark"],
		["cyl",Vector2(406.0,-6.1),0.4,30.0,31.2,"wall"],["cyl",Vector2(406.0,-15.3),0.4,30.8,33.2,"wall"],
		["cyl",Vector2(406.0,-24.5),0.4,30.0,30.8,"wall"],["cyl",Vector2(406.0,-30.0),0.4,30.0,32.4,"wall"],
		["label",Vector3(405.0,30.6,-4.8),"gaps 1.6 m · running jumps"],
		# West: the piers' caps.
		["box",Rect2(393.6,-9.1,2.8,1.8),28.0,30.0,"lip"],["box",Rect2(394.0,-9.1,2.0,1.8),20.0,28.0,"wall"],
		["box",Rect2(393.6,-15.1,2.8,2.7),28.0,30.0,"lip"],["box",Rect2(394.0,-14.8,2.0,2.0),21.0,28.0,"wall"],
		["box",Rect2(393.6,-22.0,2.8,3.7),28.0,30.0,"lip"],["box",Rect2(394.0,-21.2,2.0,2.0),19.0,28.0,"wall"],
		["box",Rect2(393.6,-29.8,2.8,4.8),28.0,30.0,"lip"],["box",Rect2(394.0,-28.4,2.0,2.0),22.0,28.0,"wall"],
		["label",Vector3(395.0,30.6,-4.8),"gaps 3.3, 3.3, 3.2, 3.0 · long jump chain"],
		["label",Vector3(395.0,30.6,-32.4),"5.1 m · the chain's last hop, twirled"],
		# The far island's gate, its lintel half fallen.
		["box",Rect2(395.5,-39.0,1.5,1.2),30.0,35.0,"wall"],["box",Rect2(403.0,-39.0,1.5,1.2),30.0,35.0,"wall"],
		["box",Rect2(395.5,-39.0,4.5,1.2),35.0,35.8,"lip"],
		["obox",Vector3(402.0,30.4,-41.5),Vector3(4.0,0.8,1.2),-20.0,"dark"],
		["box",Rect2(391.0,-50.0,6.0,5.0),30.0,30.1,"pad"],
	]},
	# The arch and the stair to nowhere: a triumphal arch, its opening 4 m
	# wide and 5 m tall between piers 3 m square, its attic 2 m over them
	# (the top 7 m up). West of it a stair of 0.4 m steps that once reached
	# the attic and now stops 1.6 m short of it and 1.4 m under it. East, a
	# block of the attic fallen on end 1.4 m off the east pier, 2.6 m tall;
	# over it the pier's impost, a ledge 0.7 m deep at 5.4 m where the attic
	# is set back from the pier's face.
	{"key":6,"name":"Arch and the stair to nowhere","spawn":Vector3(499.0,30.0,-6.0),"face":Vector2(0.0,-1.0),"sign":Vector3(495.0,33.5,-6.0),"parts":[
		["box",Rect2(476.0,-40.0,40.0,40.0),24.0,30.0,"floor"],
		["box",Rect2(482.0,-34.0,28.0,28.0),18.0,24.0,"dark"],
		["box",Rect2(490.0,-28.0,14.0,16.0),12.0,18.0,"dark"],
		# The arch.
		["box",Rect2(494.0,-22.0,3.0,3.0),30.0,35.0,"wall"],["box",Rect2(501.0,-22.0,3.0,3.0),30.0,35.0,"wall"],
		["box",Rect2(494.0,-22.0,9.3,3.0),35.0,37.0,"lip"],
		["label",Vector3(499.0,37.5,-18.6),"attic 7 m"],["label",Vector3(499.0,32.0,-18.6),"4 m by 5 m"],
		# The stair, 0.4 m steps 0.8 m deep, 2 m wide, its top 5.6 m.
		["box",Rect2(481.2,-21.5,0.8,2.0),30.0,30.4,"floor"],["box",Rect2(482.0,-21.5,0.8,2.0),30.0,30.8,"floor"],
		["box",Rect2(482.8,-21.5,0.8,2.0),30.0,31.2,"floor"],["box",Rect2(483.6,-21.5,0.8,2.0),30.0,31.6,"floor"],
		["box",Rect2(484.4,-21.5,0.8,2.0),30.0,32.0,"floor"],["box",Rect2(485.2,-21.5,0.8,2.0),30.0,32.4,"floor"],
		["box",Rect2(486.0,-21.5,0.8,2.0),30.0,32.8,"floor"],["box",Rect2(486.8,-21.5,0.8,2.0),30.0,33.2,"floor"],
		["box",Rect2(487.6,-21.5,0.8,2.0),30.0,33.6,"floor"],["box",Rect2(488.4,-21.5,0.8,2.0),30.0,34.0,"floor"],
		["box",Rect2(489.2,-21.5,0.8,2.0),30.0,34.4,"floor"],["box",Rect2(490.0,-21.5,0.8,2.0),30.0,34.8,"floor"],
		["box",Rect2(490.8,-21.5,0.8,2.0),30.0,35.2,"floor"],["box",Rect2(491.6,-21.5,0.8,2.0),30.0,35.6,"dark"],
		["label",Vector3(493.2,36.4,-20.5),"1.6 m short, 1.4 m under"],
		# The fallen block east and the cornice over it.
		["box",Rect2(505.4,-22.0,2.4,3.0),30.0,32.6,"dark"],
		["box",Rect2(503.3,-22.0,0.7,3.0),35.0,35.4,"lip"],
		["label",Vector3(506.2,33.0,-18.6),"2.6 m · side flip"],["label",Vector3(505.0,35.8,-18.6),"impost 5.4 m"],
		["label",Vector3(504.5,30.6,-17.0),"from the block: into the pier, kick, stick back + twirl to the impost"],
		# Fallen voussoirs round it.
		["obox",Vector3(497.0,30.4,-28.0),Vector3(1.6,0.8,1.0),30.0,"dark"],
		["obox",Vector3(502.5,30.4,-30.5),Vector3(1.4,0.8,1.0),-50.0,"dark"],
		["obox",Vector3(489.0,30.45,-27.0),Vector3(3.0,0.9,0.9),10.0,"dark"],
		["box",Rect2(508.0,-36.0,6.0,6.0),30.0,30.1,"pad"],
	]},
	# The fallen colonnade: two islands 22 m apart, two of the colonnade's
	# columns (1.8 m drums) fallen across. East one whole, lying on the
	# skew, 25 m long: walk it. West one broken in two, its far half sunk
	# 1 m, the break 6 m (a twirled long jump, 7.4, clears it; a plain one,
	# 4.2, doesn't); beside the break a fragment of the colonnade's back
	# wall still stands on its pier, 1.8 m off the column's line and 8 m long,
	# to wall-run across the break and kick back onto the far half. On the
	# far island the temple's pediment wall, 4 m, roof slabs fallen against
	# it at 20° (walk up), 30° and 50° (surfs on its own).
	{"key":7,"name":"Fallen colonnade · columns over the chasm, roof slabs","spawn":Vector3(601.0,30.0,2.0),"face":Vector2(0.0,-1.0),"sign":Vector3(601.0,33.5,3.0),"parts":[
		["box",Rect2(584.0,-8.0,32.0,14.0),24.0,30.0,"floor"],
		["box",Rect2(588.0,-6.0,24.0,10.0),18.0,24.0,"dark"],
		["box",Rect2(584.0,-50.0,32.0,20.0),24.0,30.0,"floor"],
		["box",Rect2(588.0,-46.0,24.0,14.0),18.0,24.0,"dark"],
		["box",Rect2(594.0,-42.0,12.0,8.0),12.0,18.0,"dark"],
		# The whole column, east.
		["obox",Vector3(607.0,29.1,-19.0),Vector3(1.8,1.8,25.0),8.0,"lip"],
		["label",Vector3(607.0,30.6,-19.0),"column 1.8 m · walk it"],
		# The broken one, west, and the wall beside its break.
		["obox",Vector3(594.0,29.1,-11.0),Vector3(2.4,1.8,8.0),0.0,"lip"],
		["obox",Vector3(594.0,28.1,-26.0),Vector3(2.4,1.8,10.0),4.0,"lip"],
		["label",Vector3(594.0,30.6,-18.0),"break 6 m, 1 m down"],
		["box",Rect2(595.8,-22.0,0.8,8.0),27.0,33.5,"wall"],
		["box",Rect2(595.8,-19.0,0.8,2.0),15.0,27.0,"dark"],
		["label",Vector3(596.4,34.0,-18.0),"wall 1.8 m off · wall run, kick back"],
		# The pediment wall and the roof slabs against it.
		["box",Rect2(588.0,-48.0,24.0,1.2),30.0,34.0,"lip"],
		["ramp",Vector3(591.5,30.0,-35.8),Vector3(591.5,34.0,-46.8),3.0,"dark"],
		["box",Rect2(590.0,-39.8,3.0,2.0),30.0,30.68,"dark"],["box",Rect2(590.0,-41.8,3.0,2.0),30.0,31.41,"dark"],
		["box",Rect2(590.0,-43.8,3.0,2.0),30.0,32.13,"dark"],["box",Rect2(590.0,-46.8,3.0,3.0),30.0,32.86,"dark"],
		["ramp",Vector3(597.5,30.0,-39.87),Vector3(597.5,34.0,-46.8),3.0,"dark"],
		["box",Rect2(596.0,-42.87,3.0,2.0),30.0,30.53,"dark"],["box",Rect2(596.0,-44.87,3.0,2.0),30.0,31.68,"dark"],
		["box",Rect2(596.0,-46.8,3.0,1.93),30.0,32.84,"dark"],
		["ramp",Vector3(603.5,30.0,-43.44),Vector3(603.5,34.0,-46.8),3.0,"dark"],
		["box",Rect2(602.0,-45.44,3.0,1.0),30.0,31.14,"dark"],["box",Rect2(602.0,-46.8,3.0,1.36),30.0,32.33,"dark"],
		["label",Vector3(591.5,31.6,-37.0),"20°"],["label",Vector3(597.5,31.6,-40.5),"30°"],["label",Vector3(603.5,31.6,-43.8),"50°"],
		["label",Vector3(600.0,34.5,-47.4),"pediment 4 m"],
		["cyl",Vector2(589.0,-33.0),0.9,30.0,31.8,"wall"],["cyl",Vector2(611.0,-34.0),0.9,30.0,33.6,"wall"],
		["box",Rect2(586.0,-2.0,6.0,6.0),30.0,30.1,"pad"],
	]},
]
