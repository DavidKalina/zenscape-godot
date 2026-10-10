extends RefCounted
## Sky village: bits of a little sky town on floating islands, each an
## arrangement to platform through the way he likes, with an easy way and
## an expert line (docs/design/island-packs/sky_village.md has the routes,
## the numbers and the kit pieces each implies). Greybox: orange caps the
## tops meant to be caught or landed on, grey is walls and ground, dark is
## roofs and accents, green greenery. Every island's ground is at 40 m.
##   ./run-character-study.command --pack=sky_village

const NAME := "Sky village"
const START := Vector3(-21.5,40.0,0.0)
const START_FACE := Vector2(1.0,0.0)
const LOST := 15.0

const STATIONS := [
	{"key":1,"name":"Market square","spawn":Vector3(-21.5,40.0,0.0),"face":Vector2(1.0,0.0),"sign":Vector3(-21.5,44.5,-5.0),"parts":[
		# The island: a slab 48 by 30, 3 m deep, rock stepping in under it.
		["box",Rect2(-24.0,-15.0,48.0,30.0),37.0,40.0,"floor"],
		["box",Rect2(-20.0,-12.0,40.0,24.0),33.0,37.0,"grey"],
		["box",Rect2(-13.0,-8.0,26.0,16.0),29.0,33.0,"grey"],
		["box",Rect2(-5.0,-4.0,10.0,8.0),25.0,29.0,"grey"],
		# The market wall, 1.1 m (a jump catches it), and its gate: 4.8 m
		# wide, 2.8 m clear.
		["box",Rect2(-17.0,-15.0,1.0,11.6),40.0,41.1,"wall"],
		["box",Rect2(-17.0,3.4,1.0,11.6),40.0,41.1,"wall"],
		["box",Rect2(-17.4,-3.4,1.8,1.0),40.0,43.6,"wall"],
		["box",Rect2(-17.4,2.4,1.8,1.0),40.0,43.6,"wall"],
		["box",Rect2(-17.4,-2.4,1.8,4.8),42.8,43.6,"dark"],
		["label",Vector3(-16.5,44.0,0.0),"gate · 4.8 m wide, 2.8 m clear"],
		# The fountain: a basin 6 m across, its rim 0.4 m (walked up), a
		# column and a bowl.
		["cyl",Vector2(-1.0,0.0),3.0,40.0,40.4,"wall"],
		["cyl",Vector2(-1.0,0.0),0.5,40.4,42.2,"wall"],
		["cyl",Vector2(-1.0,0.0),1.3,42.2,42.5,"dark"],
		# Stalls: a counter 1.0 m, a canopy over it 1.6 to 1.8 m on posts.
		["box",Rect2(-10.5,-8.6,3.0,1.2),40.0,41.0,"wall"],
		["box",Rect2(-10.7,-9.2,3.4,2.4),41.6,41.8,"dark"],
		["cyl",Vector2(-10.55,-6.95),0.08,40.0,41.6,"wall"],["cyl",Vector2(-7.45,-6.95),0.08,40.0,41.6,"wall"],
		["box",Rect2(-10.5,7.4,3.0,1.2),40.0,41.0,"wall"],
		["box",Rect2(-10.7,6.8,3.4,2.4),41.6,41.8,"dark"],
		["cyl",Vector2(-10.55,6.95),0.08,40.0,41.6,"wall"],["cyl",Vector2(-7.45,6.95),0.08,40.0,41.6,"wall"],
		["box",Rect2(0.5,-8.6,3.0,1.2),40.0,41.0,"wall"],
		["box",Rect2(0.3,-9.2,3.4,2.4),41.6,41.8,"dark"],
		["cyl",Vector2(0.45,-6.95),0.08,40.0,41.6,"wall"],["cyl",Vector2(3.55,-6.95),0.08,40.0,41.6,"wall"],
		# The covered market: a canopy 6 by 4 at 1.8 m on four posts, a
		# counter under it; its roof the side flip's.
		["box",Rect2(3.0,6.0,6.0,4.0),41.6,41.8,"lip"],
		["cyl",Vector2(3.2,6.2),0.12,40.0,41.6,"wall"],["cyl",Vector2(8.8,6.2),0.12,40.0,41.6,"wall"],
		["cyl",Vector2(3.2,9.8),0.12,40.0,41.6,"wall"],["cyl",Vector2(8.8,9.8),0.12,40.0,41.6,"wall"],
		["box",Rect2(4.0,8.4,4.0,1.0),40.0,41.0,"wall"],
		["label",Vector3(6.0,42.3,6.0),"covered market roof 1.8 m · side flip"],
		# The town hall, its terrace 2.0 m in front, five 0.4 m steps up
		# to it at the south end.
		["box",Rect2(14.0,-9.0,8.0,18.0),40.0,46.0,"wall"],
		["box",Rect2(13.6,-9.4,8.8,18.8),46.0,46.6,"dark"],
		["box",Rect2(13.9,-1.2,0.2,2.4),42.0,44.4,"dark"],
		["box",Rect2(11.0,-8.0,3.0,16.0),40.0,42.0,"lip"],
		["box",Rect2(7.0,-7.0,0.8,2.5),40.0,40.4,"floor"],
		["box",Rect2(7.8,-7.0,0.8,2.5),40.0,40.8,"floor"],
		["box",Rect2(8.6,-7.0,0.8,2.5),40.0,41.2,"floor"],
		["box",Rect2(9.4,-7.0,0.8,2.5),40.0,41.6,"floor"],
		["box",Rect2(10.2,-7.0,0.8,2.5),40.0,42.0,"floor"],
		["label",Vector3(12.5,42.5,-3.0),"hall terrace 2.0 m"],
		["label",Vector3(8.5,41.0,-3.8),"steps 0.4 m"],
	]},
	{"key":2,"name":"Chimney alley","spawn":Vector3(70.0,40.0,4.0),"face":Vector2(0.0,-1.0),"sign":Vector3(75.0,44.0,6.0),"parts":[
		["box",Rect2(52.0,-12.0,36.0,24.0),37.0,40.0,"floor"],
		["box",Rect2(55.0,-9.0,30.0,18.0),33.0,37.0,"grey"],
		["box",Rect2(60.0,-6.0,20.0,12.0),29.0,33.0,"grey"],
		["box",Rect2(66.0,-3.0,8.0,6.0),25.0,29.0,"grey"],
		# Two tall houses 7 by 7, 7.2 m to their flat roofs, an alley 1.0 m
		# clear between them: the chimney kicked up.
		["box",Rect2(56.0,-11.0,7.0,7.0),40.0,47.2,"lip"],
		["box",Rect2(64.0,-11.0,7.0,7.0),40.0,47.2,"lip"],
		["label",Vector3(63.5,40.6,-3.6),"alley 1.0 m clear · kick up it"],
		["box",Rect2(57.0,-10.0,1.0,1.0),47.2,48.6,"dark"],
		["box",Rect2(69.0,-10.0,1.0,1.0),47.2,48.6,"dark"],
		# Balconies up the east house's front, 1.2 m apart, zig-zag: each
		# a jump and a catch.
		["box",Rect2(64.5,-4.0,2.6,1.4),40.9,41.2,"lip"],
		["box",Rect2(67.9,-4.0,2.6,1.4),42.1,42.4,"lip"],
		["box",Rect2(64.5,-4.0,2.6,1.4),43.3,43.6,"lip"],
		["box",Rect2(67.9,-4.0,2.6,1.4),44.5,44.8,"lip"],
		["box",Rect2(64.5,-4.0,2.6,1.4),45.7,46.0,"lip"],
		["label",Vector3(69.2,41.2,-2.0),"balconies 1.2 m apart"],
		["label",Vector3(60.0,47.8,-7.0),"roofs 7.2 m"],
		# A lower house beyond, 4.8 m, and a shed 2.4 m: ways down.
		["box",Rect2(72.0,-11.0,6.0,6.0),40.0,44.8,"lip"],
		["box",Rect2(78.5,-10.0,4.0,4.0),40.0,42.4,"lip"],
	]},
	{"key":3,"name":"Bell tower","spawn":Vector3(132.0,40.0,9.0),"face":Vector2(1.0,0.0),"sign":Vector3(132.0,44.5,11.0),"parts":[
		["box",Rect2(122.0,-12.0,36.0,24.0),37.0,40.0,"floor"],
		["box",Rect2(125.0,-9.0,30.0,18.0),33.0,37.0,"grey"],
		["box",Rect2(130.0,-6.0,20.0,12.0),29.0,33.0,"grey"],
		["box",Rect2(136.0,-3.0,8.0,6.0),25.0,29.0,"grey"],
		# The church: a nave 14 by 8, its flat roof 4.0 m, ten 0.4 m steps
		# up its south side.
		["box",Rect2(128.0,-4.0,14.0,8.0),40.0,44.0,"lip"],
		["box",Rect2(129.0,4.0,1.0,1.6),40.0,40.4,"floor"],
		["box",Rect2(130.0,4.0,1.0,1.6),40.0,40.8,"floor"],
		["box",Rect2(131.0,4.0,1.0,1.6),40.0,41.2,"floor"],
		["box",Rect2(132.0,4.0,1.0,1.6),40.0,41.6,"floor"],
		["box",Rect2(133.0,4.0,1.0,1.6),40.0,42.0,"floor"],
		["box",Rect2(134.0,4.0,1.0,1.6),40.0,42.4,"floor"],
		["box",Rect2(135.0,4.0,1.0,1.6),40.0,42.8,"floor"],
		["box",Rect2(136.0,4.0,1.0,1.6),40.0,43.2,"floor"],
		["box",Rect2(137.0,4.0,1.0,1.6),40.0,43.6,"floor"],
		["box",Rect2(138.0,4.0,1.0,1.6),40.0,44.0,"floor"],
		["label",Vector3(134.0,43.4,4.8),"steps 0.4 m"],
		# The tower, 5 by 5, its belfry floor 5.2 m (1.2 over the nave's
		# roof), four pillars, a roof and spire, the bell.
		["box",Rect2(142.0,-2.5,5.0,5.0),40.0,45.2,"lip"],
		["box",Rect2(142.0,-2.5,0.8,0.8),45.2,47.6,"wall"],
		["box",Rect2(146.2,-2.5,0.8,0.8),45.2,47.6,"wall"],
		["box",Rect2(142.0,1.7,0.8,0.8),45.2,47.6,"wall"],
		["box",Rect2(146.2,1.7,0.8,0.8),45.2,47.6,"wall"],
		["box",Rect2(141.8,-2.7,5.4,5.4),47.6,48.2,"dark"],
		["box",Rect2(143.7,-0.8,1.6,1.6),48.2,50.0,"dark"],
		["cyl",Vector2(144.5,0.0),0.7,46.5,47.6,"dark"],
		["label",Vector3(144.5,45.7,3.0),"belfry 5.2 m"],
		# The porch, a lean-to 2.4 m against the tower's east face, a
		# barrel by it: the tower's face 2.8 m over it, twirled back up.
		["box",Rect2(147.0,-2.0,2.4,4.0),40.0,42.4,"lip"],
		["cyl",Vector2(149.0,2.8),0.55,40.0,41.1,"lip"],
		["label",Vector3(148.2,42.9,0.0),"porch 2.4 m · kick, twirl back over the sill"],
	]},
	{"key":4,"name":"Laundry lane","spawn":Vector3(189.0,40.0,0.0),"face":Vector2(1.0,0.0),"sign":Vector3(189.0,44.5,-1.0),"parts":[
		# The lane's island, 26 by 20, a lane 6 m wide between two rows of
		# houses, open to the sky at its east end.
		["box",Rect2(186.0,-10.0,26.0,20.0),37.0,40.0,"floor"],
		["box",Rect2(189.0,-7.0,20.0,14.0),33.0,37.0,"grey"],
		["box",Rect2(193.0,-4.0,12.0,8.0),29.0,33.0,"grey"],
		["box",Rect2(187.0,-10.0,6.0,7.0),40.0,44.0,"wall"],["box",Rect2(186.8,-10.2,6.4,7.4),44.0,44.4,"dark"],
		["box",Rect2(194.0,-10.0,6.0,7.0),40.0,45.2,"wall"],["box",Rect2(193.8,-10.2,6.4,7.4),45.2,45.6,"dark"],
		["box",Rect2(187.0,3.0,6.0,7.0),40.0,44.6,"wall"],["box",Rect2(186.8,2.8,6.4,7.4),44.6,45.0,"dark"],
		["box",Rect2(194.0,3.0,6.0,7.0),40.0,43.6,"wall"],["box",Rect2(193.8,2.8,6.4,7.4),43.6,44.0,"dark"],
		["box",Rect2(201.0,3.0,7.0,7.0),40.0,45.0,"wall"],["box",Rect2(200.8,2.8,7.4,7.4),45.0,45.4,"dark"],
		# The long house on the north side, and its gallery wall jutting
		# 6 m out over the gap (stopping 0.5 m short of the far island), one
		# blank face 17 m long: the wall run.
		["box",Rect2(201.0,-10.0,11.0,7.0),40.0,44.4,"wall"],["box",Rect2(200.8,-10.2,11.4,7.4),44.4,44.8,"dark"],
		["box",Rect2(212.0,-4.0,6.0,1.0),40.0,44.4,"wall"],
		["box",Rect2(212.0,-4.6,6.0,1.6),44.4,44.8,"dark"],
		["label",Vector3(214.0,44.0,-2.8),"gallery wall · 17 m face · wall run"],
		# Laundry across the lane, the sheets' hems 2.0 m up (a long jump
		# and a jump pass under, a pump hits them).
		["box",Rect2(191.5,-3.0,0.04,6.0),42.6,42.64,"dark"],
		["obox",Vector3(191.5,42.3,-1.2),Vector3(0.04,0.6,1.0),0.0,"pad"],["obox",Vector3(191.5,42.3,1.0),Vector3(0.04,0.6,1.2),0.0,"pad"],
		["box",Rect2(198.5,-3.0,0.04,6.0),42.6,42.64,"dark"],
		["obox",Vector3(198.5,42.3,0.0),Vector3(0.04,0.6,1.4),0.0,"pad"],
		["box",Rect2(205.0,-3.0,0.04,6.0),42.6,42.64,"dark"],
		["obox",Vector3(205.0,42.3,-1.6),Vector3(0.04,0.6,1.0),0.0,"pad"],["obox",Vector3(205.0,42.3,1.4),Vector3(0.04,0.6,1.0),0.0,"pad"],
		["label",Vector3(198.5,43.1,0.0),"laundry · hems 2.0 m"],
		# The gap, 6.5 m, and the rope bridge across it at the south corner:
		# a plank deck 1.2 m wide, rope rails 1.0 m.
		["box",Rect2(211.5,5.0,8.0,1.2),39.8,40.0,"floor"],
		["box",Rect2(211.5,4.9,8.0,0.1),40.9,41.0,"dark"],["box",Rect2(211.5,6.2,8.0,0.1),40.9,41.0,"dark"],
		["box",Rect2(211.5,4.6,0.3,0.3),40.0,41.3,"wall"],["box",Rect2(211.5,6.3,0.3,0.3),40.0,41.3,"wall"],
		["box",Rect2(219.2,4.6,0.3,0.3),40.0,41.3,"wall"],["box",Rect2(219.2,6.3,0.3,0.3),40.0,41.3,"wall"],
		["label",Vector3(215.5,40.6,7.0),"gap 6.5 m · rope bridge"],
		# Across: a little square, a well, a cottage.
		["box",Rect2(218.5,-9.0,14.0,18.0),37.0,40.0,"floor"],
		["box",Rect2(220.5,-6.0,10.0,12.0),33.0,37.0,"grey"],
		["box",Rect2(222.5,-3.0,6.0,6.0),29.0,33.0,"grey"],
		["cyl",Vector2(226.0,1.0),1.0,40.0,40.9,"wall"],
		["box",Rect2(225.0,0.9,0.15,0.2),40.9,42.4,"wall"],["box",Rect2(226.85,0.9,0.15,0.2),40.9,42.4,"wall"],
		["box",Rect2(224.6,0.2,2.8,1.6),42.4,42.6,"dark"],
		["box",Rect2(226.0,-8.0,6.0,5.0),40.0,43.6,"wall"],["box",Rect2(225.8,-8.2,6.4,5.4),43.6,44.0,"dark"],
	]},
	{"key":5,"name":"Roofline","spawn":Vector3(252.0,49.0,0.0),"face":Vector2(1.0,0.0),"sign":Vector3(252.0,53.5,-2.0),"parts":[
		# A hillside street: the upper terrace 9 m over the lower street,
		# a barn between them whose roof runs down from the terrace's edge.
		["box",Rect2(246.0,-8.0,30.0,16.0),37.0,40.0,"floor"],
		["box",Rect2(249.0,-6.0,24.0,12.0),33.0,37.0,"grey"],
		["box",Rect2(253.0,-4.0,14.0,8.0),29.0,33.0,"grey"],
		["box",Rect2(246.0,-8.0,14.0,16.0),40.0,49.0,"lip"],
		# The barn's roof: 10 m along the ground from the ridge at 9.0 m to
		# the eave at 1.0 m, 39°, 8 m wide; the barn stepped in under it.
		["ramp",Vector3(270.0,41.0,0.0),Vector3(260.0,49.0,0.0),8.0,"dark"],
		["box",Rect2(260.0,-4.0,8.75,8.0),40.0,42.0,"wall"],
		["box",Rect2(260.0,-4.0,6.25,8.0),42.0,44.0,"wall"],
		["box",Rect2(260.0,-4.0,3.75,8.0),44.0,46.0,"wall"],
		["box",Rect2(260.0,-4.0,1.25,8.0),46.0,48.0,"wall"],
		["label",Vector3(265.0,46.5,-4.4),"barn roof 39° · crouch: surf"],
		# The stair down beside it (greyboxed as a 30° ramp, 2.5 m wide).
		["ramp",Vector3(275.59,40.0,5.75),Vector3(260.0,49.0,5.75),2.5,"grey"],
		["label",Vector3(266.0,46.0,7.2),"stair down"],
		# Off the lower street's edge, 10 m to the garden island 1 m lower;
		# hanging planters across, 2 m long, 1 m apart.
		["box",Rect2(277.0,-1.0,2.0,2.0),39.6,40.0,"pad"],
		["box",Rect2(280.0,-1.0,2.0,2.0),39.6,40.0,"pad"],
		["box",Rect2(283.0,-1.0,2.0,2.0),39.6,40.0,"pad"],
		["label",Vector3(281.0,40.6,1.6),"planters 1 m apart"],
		["label",Vector3(276.0,40.6,-3.0),"gap 10 m · surf, long jump, twirl"],
		["box",Rect2(286.0,-7.0,14.0,14.0),36.0,39.0,"floor"],
		["box",Rect2(288.0,-5.0,10.0,10.0),32.0,36.0,"grey"],
		["box",Rect2(290.0,-3.0,6.0,6.0),28.0,32.0,"grey"],
		# The garden: a pergola and beds.
		["box",Rect2(292.0,-5.0,0.3,0.3),39.0,41.4,"wall"],["box",Rect2(297.0,-5.0,0.3,0.3),39.0,41.4,"wall"],
		["box",Rect2(292.0,-1.0,0.3,0.3),39.0,41.4,"wall"],["box",Rect2(297.0,-1.0,0.3,0.3),39.0,41.4,"wall"],
		["box",Rect2(291.8,-5.2,5.7,4.4),41.4,41.6,"dark"],
		["box",Rect2(289.0,2.0,9.0,2.0),39.0,39.4,"pad"],
	]},
	{"key":6,"name":"Water towers","spawn":Vector3(326.0,40.0,-10.0),"face":Vector2(1.0,0.0),"sign":Vector3(326.0,44.5,-11.0),"parts":[
		["box",Rect2(318.0,-12.0,42.0,22.0),37.0,40.0,"floor"],
		["box",Rect2(321.0,-9.0,36.0,16.0),33.0,37.0,"grey"],
		["box",Rect2(326.0,-6.0,26.0,10.0),29.0,33.0,"grey"],
		["box",Rect2(334.0,-3.0,10.0,4.0),25.0,29.0,"grey"],
		# A warehouse, its flat roof 3.6 m, nine 0.4 m steps up its north
		# side.
		["box",Rect2(322.0,-6.0,10.0,12.0),40.0,43.6,"lip"],
		["box",Rect2(322.0,-7.6,1.0,1.6),40.0,40.4,"floor"],["box",Rect2(323.0,-7.6,1.0,1.6),40.0,40.8,"floor"],
		["box",Rect2(324.0,-7.6,1.0,1.6),40.0,41.2,"floor"],["box",Rect2(325.0,-7.6,1.0,1.6),40.0,41.6,"floor"],
		["box",Rect2(326.0,-7.6,1.0,1.6),40.0,42.0,"floor"],["box",Rect2(327.0,-7.6,1.0,1.6),40.0,42.4,"floor"],
		["box",Rect2(328.0,-7.6,1.0,1.6),40.0,42.8,"floor"],["box",Rect2(329.0,-7.6,1.0,1.6),40.0,43.2,"floor"],
		["box",Rect2(330.0,-7.6,1.0,1.6),40.0,43.6,"floor"],
		["label",Vector3(326.0,42.6,-7.2),"steps 0.4 m"],
		# Three water tanks on legs, 4 m across, each 1.2 m over the last,
		# in a row east of the roof: gaps 2.5, 3.0, 2.8 m between rims.
		["cyl",Vector2(336.5,0.0),2.0,43.6,44.8,"lip"],
		["cyl",Vector2(335.4,-1.1),0.12,40.0,43.6,"wall"],["cyl",Vector2(337.6,-1.1),0.12,40.0,43.6,"wall"],
		["cyl",Vector2(335.4,1.1),0.12,40.0,43.6,"wall"],["cyl",Vector2(337.6,1.1),0.12,40.0,43.6,"wall"],
		["label",Vector3(336.5,45.3,0.0),"tank 4.8 m"],
		["cyl",Vector2(343.5,0.0),2.0,44.6,46.0,"lip"],
		["cyl",Vector2(342.4,-1.1),0.12,40.0,44.6,"wall"],["cyl",Vector2(344.6,-1.1),0.12,40.0,44.6,"wall"],
		["cyl",Vector2(342.4,1.1),0.12,40.0,44.6,"wall"],["cyl",Vector2(344.6,1.1),0.12,40.0,44.6,"wall"],
		["label",Vector3(343.5,46.5,0.0),"tank 6.0 m"],
		["cyl",Vector2(350.5,0.0),2.2,45.6,47.2,"lip"],
		["cyl",Vector2(349.3,-1.2),0.12,40.0,45.6,"wall"],["cyl",Vector2(351.7,-1.2),0.12,40.0,45.6,"wall"],
		["cyl",Vector2(349.3,1.2),0.12,40.0,45.6,"wall"],["cyl",Vector2(351.7,1.2),0.12,40.0,45.6,"wall"],
		["label",Vector3(350.5,47.8,0.0),"big tank 7.2 m"],
		# The big tank's catwalk: round it a lap and a half on a 5.8 m
		# square, 1.2 m wide, 1.2 m up a side (12°), landings at the
		# corners, a plank onto the tank at the top.
		["ramp",Vector3(347.6,40.0,-2.9),Vector3(353.4,41.2,-2.9),1.2,"grey"],
		["box",Rect2(352.8,-3.5,1.2,1.2),40.9,41.2,"grey"],
		["ramp",Vector3(353.4,41.2,-2.9),Vector3(353.4,42.4,2.9),1.2,"grey"],
		["box",Rect2(352.8,2.3,1.2,1.2),42.1,42.4,"grey"],
		["ramp",Vector3(353.4,42.4,2.9),Vector3(347.6,43.6,2.9),1.2,"grey"],
		["box",Rect2(347.0,2.3,1.2,1.2),43.3,43.6,"grey"],
		["ramp",Vector3(347.6,43.6,2.9),Vector3(347.6,44.8,-2.9),1.2,"grey"],
		["box",Rect2(347.0,-3.5,1.2,1.2),44.5,44.8,"grey"],
		["ramp",Vector3(347.6,44.8,-2.9),Vector3(353.4,46.0,-2.9),1.2,"grey"],
		["box",Rect2(352.8,-3.5,1.2,1.2),45.7,46.0,"grey"],
		["ramp",Vector3(353.4,46.0,-2.9),Vector3(353.4,47.2,2.9),1.2,"grey"],
		["box",Rect2(352.8,2.3,1.2,1.2),46.9,47.2,"grey"],
		["box",Rect2(350.5,1.8,2.4,1.0),46.9,47.2,"grey"],
		["label",Vector3(354.8,41.0,0.0),"catwalk 12°"],
	]},
	{"key":7,"name":"Town gate","spawn":Vector3(388.0,40.0,0.0),"face":Vector2(1.0,0.0),"sign":Vector3(388.0,44.5,-2.0),"parts":[
		["box",Rect2(380.0,-14.0,40.0,28.0),37.0,40.0,"floor"],
		["box",Rect2(383.0,-11.0,34.0,22.0),33.0,37.0,"grey"],
		["box",Rect2(388.0,-7.0,24.0,14.0),29.0,33.0,"grey"],
		["box",Rect2(395.0,-3.0,10.0,6.0),25.0,29.0,"grey"],
		# The town wall, 2.5 m thick, its wall walk 4.0 m, the gate through
		# it 3.2 m wide and 3.2 m clear.
		["box",Rect2(398.0,-14.0,2.5,12.4),40.0,44.0,"lip"],
		["box",Rect2(398.0,1.6,2.5,12.4),40.0,44.0,"lip"],
		["box",Rect2(398.0,-1.6,2.5,3.2),43.2,44.0,"lip"],
		["label",Vector3(399.25,44.5,0.0),"wall walk 4.0 m · gate 3.2 m"],
		# Merlons along its outer edge.
		["box",Rect2(400.0,-9.2,0.5,0.8),44.0,44.9,"wall"],["box",Rect2(400.0,-7.6,0.5,0.8),44.0,44.9,"wall"],
		["box",Rect2(400.0,-6.0,0.5,0.8),44.0,44.9,"wall"],["box",Rect2(400.0,-4.4,0.5,0.8),44.0,44.9,"wall"],
		["box",Rect2(400.0,3.6,0.5,0.8),44.0,44.9,"wall"],["box",Rect2(400.0,5.2,0.5,0.8),44.0,44.9,"wall"],
		["box",Rect2(400.0,6.8,0.5,0.8),44.0,44.9,"wall"],["box",Rect2(400.0,8.4,0.5,0.8),44.0,44.9,"wall"],
		# Two towers flanking the gate outside, 6 m.
		["box",Rect2(400.5,-4.6,3.0,3.0),40.0,46.0,"wall"],["box",Rect2(400.3,-4.8,3.4,3.4),46.0,46.4,"dark"],
		["box",Rect2(400.5,1.6,3.0,3.0),40.0,46.0,"wall"],["box",Rect2(400.3,1.4,3.4,3.4),46.0,46.4,"dark"],
		# Inside, north of the gate: ten 0.4 m steps up against the wall.
		["box",Rect2(396.8,-4.0,1.2,1.0),40.0,40.4,"floor"],["box",Rect2(396.8,-5.0,1.2,1.0),40.0,40.8,"floor"],
		["box",Rect2(396.8,-6.0,1.2,1.0),40.0,41.2,"floor"],["box",Rect2(396.8,-7.0,1.2,1.0),40.0,41.6,"floor"],
		["box",Rect2(396.8,-8.0,1.2,1.0),40.0,42.0,"floor"],["box",Rect2(396.8,-9.0,1.2,1.0),40.0,42.4,"floor"],
		["box",Rect2(396.8,-10.0,1.2,1.0),40.0,42.8,"floor"],["box",Rect2(396.8,-11.0,1.2,1.0),40.0,43.2,"floor"],
		["box",Rect2(396.8,-12.0,1.2,1.0),40.0,43.6,"floor"],["box",Rect2(396.8,-13.0,1.2,1.0),40.0,44.0,"floor"],
		["label",Vector3(396.2,42.0,-8.0),"steps 0.4 m"],
		# Inside, south of the gate: the guardhouse, its roof 2.8 m, a lane
		# 2.0 m wide between it and the wall: wall run, kick across, catch.
		["box",Rect2(392.0,2.0,4.0,10.0),40.0,42.8,"lip"],
		["box",Rect2(392.2,10.6,1.0,1.0),42.8,44.0,"dark"],
		["label",Vector3(397.0,40.6,3.0),"lane 2.0 m · wall run, kick across"],
		["label",Vector3(394.0,43.3,7.0),"guardhouse roof 2.8 m"],
		# Outside: the road on, a milestone.
		["box",Rect2(410.0,-0.4,0.8,0.8),40.0,41.0,"dark"],
	]},
]
