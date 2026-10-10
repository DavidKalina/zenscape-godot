extends RefCounted
## The flight study's nature pack (scripts/flight_course.gd appends STATIONS
## to its own): greybox flyover landforms in the spirit of Wuhu Island, not
## a ruined hall. Each station's line was designed first, as a curve that
## keeps swinging, and the rock stood round it in the line's own frame
## (tools/flight_nature_layout.py, which writes the block between the
## markers below; edit the tool, not the numbers). The stations have no
## digit key (key -1); N reaches them after the others, and
## `--pack=nature` starts at the first and keeps N inside the pack.
##
## The part kinds it adds, every one built from the course's own boxes and
## drums (so the room, the threading rays, the colliders and the drawing
## need nothing new), in station metres, the floor at `floor_y`:
##   ["wall", [Vector3(x, top, z), ...], thick, side]   a strip of rock
##       along the points from the floor up to each point's top (a box
##       per pair, its top their mean), its face on the points and the rock
##       `side` of them: +1 right of the way they run, -1 left, 0 centred
##   ["stack", Vector2(x, z), base radius, top radius, top, hole]   a sea
##       stack: drums TIER m tall from the floor to `top`, tapering;
##       `hole` {} or {"y", "w", "h", "yaw"}, a w x h tunnel through it from
##       y up, running along yaw (two blocks either side of it there)
##   ["arch", Vector3 the opening's bottom middle, width, height, depth, yaw,
##       crown, sill, (leg)]   a natural arch across the way yaw runs: legs
##       `leg` m wide (LEG if left out) from the floor to `crown`, an arched soffit of ARCH_SLICES slices
##       over the width x height opening (upright to ARCH_SPRING of its
##       height, then a half ellipse), `depth` m thick along the way; with
##       `sill` rock under the opening too (a hole through a rib), without
##       it open below (a bridge)

const PACK := "nature"
const TIER := 7.0
const OVERLAP := 0.6
const LEG := 3.0
const ARCH_SLICES := 8
const ARCH_SPRING := 0.4

const STATIONS := [
	# >>> nature stations: written by tools/flight_nature_layout.py --write
	{"id":"nature_canyon","key":-1,"pack":"nature","name":"River canyon (bends, an arch, out over the saddle and back in, a bridge)","intent":"medium","parts":[
		["wall",[Vector3(-6.20,9.00,0.00),Vector3(-6.20,9.00,0.00),Vector3(-6.20,9.00,0.00),Vector3(-6.53,9.01,-2.99),Vector3(-6.34,9.18,-8.69),Vector3(-5.33,9.51,-14.20),Vector3(-3.31,9.76,-19.77),Vector3(-0.69,9.73,-24.56),Vector3(3.14,9.37,-28.33),Vector3(5.49,8.66,-31.96),Vector3(7.00,7.72,-35.52),Vector3(7.65,6.56,-39.39),Vector3(7.27,5.40,-43.30),Vector3(6.01,4.42,-46.94),Vector3(3.93,3.62,-50.71),Vector3(0.21,3.11,-54.77),Vector3(-2.05,2.90,-59.96),Vector3(-3.51,2.90,-66.03),Vector3(-3.70,2.98,-72.10),Vector3(-2.57,3.03,-78.33),Vector3(-0.34,2.92,-84.00),Vector3(2.38,2.63,-88.74),Vector3(5.75,2.14,-92.31),Vector3(7.77,1.50,-96.24),Vector3(9.10,0.84,-100.11),Vector3(9.81,0.18,-104.33),Vector3(9.83,-0.32,-108.70),Vector3(9.35,-0.50,-112.99),Vector3(8.85,-0.30,-117.64),Vector3(8.27,0.28,-121.89),Vector3(7.17,1.21,-126.10),Vector3(5.50,2.30,-130.06),Vector3(3.39,2.59,-133.65),Vector3(0.35,1.67,-137.12)],6.00,-1.00],
		["wall",[Vector3(5.80,9.00,0.00),Vector3(5.80,9.00,0.00),Vector3(5.80,9.00,0.00),Vector3(5.46,9.01,-2.55),Vector3(5.55,9.18,-7.01),Vector3(6.25,9.51,-11.05),Vector3(7.75,9.76,-15.10),Vector3(9.82,9.73,-18.76),Vector3(13.45,9.37,-22.20),Vector3(16.50,8.66,-27.19),Vector3(18.65,7.72,-32.66),Vector3(19.64,6.56,-38.97),Vector3(19.09,5.40,-45.33),Vector3(17.33,4.42,-50.93),Vector3(14.65,3.62,-56.10),Vector3(11.18,3.11,-59.64),Vector3(9.46,2.90,-63.37),Vector3(8.42,2.90,-67.41),Vector3(8.28,2.98,-71.32),Vector3(9.06,3.03,-75.38),Vector3(10.70,2.92,-79.30),Vector3(12.87,2.63,-82.90),Vector3(16.46,2.14,-86.90),Vector3(18.98,1.50,-91.97),Vector3(20.74,0.84,-97.22),Vector3(21.73,0.18,-103.01),Vector3(21.83,-0.32,-108.78),Vector3(21.30,-0.50,-114.04),Vector3(20.72,-0.30,-119.37),Vector3(19.97,0.28,-124.57),Vector3(18.52,1.21,-130.01),Vector3(16.34,2.30,-135.20),Vector3(13.73,2.59,-139.73),Vector3(10.30,1.67,-143.83)],6.00,1.00],
		["wall",[Vector3(-0.18,-4.95,-184.14),Vector3(-0.87,-4.76,-188.10),Vector3(-2.37,-3.05,-192.17),Vector3(-5.25,-0.72,-195.67),Vector3(-7.51,-0.68,-200.52),Vector3(-9.19,-0.56,-206.26),Vector3(-9.70,0.63,-212.13),Vector3(-8.98,1.97,-218.01),Vector3(-7.09,2.49,-223.76),Vector3(-4.62,2.21,-228.60),Vector3(-1.48,2.20,-231.90),Vector3(0.05,2.53,-235.83),Vector3(0.60,3.05,-239.65),Vector3(0.18,3.62,-243.49),Vector3(-1.21,4.06,-247.46),Vector3(-4.23,4.21,-250.86),Vector3(-6.54,4.09,-255.80),Vector3(-8.24,3.76,-261.66),Vector3(-8.71,3.39,-267.63),Vector3(-7.93,3.11,-273.52),Vector3(-6.06,2.98,-279.19),Vector3(-3.03,2.76,-283.39),Vector3(-1.39,2.58,-287.22),Vector3(-0.41,2.67,-291.21),Vector3(-0.28,2.97,-295.05)],6.00,-1.00],
		["wall",[Vector3(11.80,-4.95,-184.95),Vector3(10.84,-4.76,-190.68),Vector3(8.92,-3.05,-196.24),Vector3(5.75,-0.72,-200.46),Vector3(3.91,-0.68,-204.19),Vector3(2.66,-0.56,-208.12),Vector3(2.29,0.63,-211.92),Vector3(2.80,1.97,-215.74),Vector3(4.21,2.49,-219.70),Vector3(6.20,2.21,-223.42),Vector3(9.73,2.20,-227.63),Vector3(11.80,2.53,-233.41),Vector3(12.60,3.05,-239.44),Vector3(12.01,3.62,-245.49),Vector3(10.15,4.06,-251.33),Vector3(6.77,4.21,-255.66),Vector3(4.89,4.09,-259.46),Vector3(3.62,3.76,-263.49),Vector3(3.29,3.39,-267.40),Vector3(3.86,3.11,-271.30),Vector3(5.31,2.98,-275.37),Vector3(8.18,2.76,-279.12),Vector3(10.18,2.58,-284.05),Vector3(11.50,2.67,-289.69),Vector3(11.72,2.97,-295.19)],6.00,1.00],
		["wall",[Vector3(-2.03,1.67,-135.51),Vector3(-5.52,-0.27,-141.44),Vector3(-8.20,-1.89,-148.46),Vector3(-9.35,-2.22,-156.16),Vector3(-8.77,-4.31,-163.76),Vector3(-6.96,-6.40,-170.60),Vector3(-5.31,-6.11,-175.56),Vector3(-4.45,-5.56,-179.82),Vector3(-4.35,-4.95,-183.86)],5.00,-1.00],
		["wall",[Vector3(12.89,1.67,-145.58),Vector3(10.59,-0.27,-149.46),Vector3(9.18,-1.89,-153.11),Vector3(8.64,-2.22,-156.74),Vector3(8.95,-4.31,-160.57),Vector3(10.08,-6.40,-164.82),Vector3(12.03,-6.11,-170.75),Vector3(13.42,-5.56,-177.71),Vector3(13.61,-4.95,-185.08)],5.00,1.00],
		["wall",[Vector3(2.43,-9.43,-145.67),Vector3(0.36,-8.93,-151.27),Vector3(-0.36,-8.58,-157.20),Vector3(0.28,-8.26,-163.15),Vector3(1.98,-7.92,-168.89),Vector3(3.73,-7.49,-174.60),Vector3(4.64,-6.86,-180.49)],14.00,0.00],
		["wall",[Vector3(-12.20,15.00,0.00),Vector3(-12.20,15.00,0.00),Vector3(-12.54,15.03,-4.74),Vector3(-11.29,15.48,-15.12),Vector3(-7.37,15.78,-25.02),Vector3(-1.68,15.28,-31.86),Vector3(0.98,13.94,-36.41),Vector3(1.63,12.09,-40.66),Vector3(0.28,10.37,-45.09),Vector3(-4.22,9.26,-50.39),Vector3(-8.43,8.88,-60.30),Vector3(-9.71,8.98,-72.11),Vector3(-7.11,9.00,-83.53),Vector3(-1.81,8.55,-92.43),Vector3(1.86,7.63,-97.72),Vector3(3.60,6.53,-103.08),Vector3(3.82,5.67,-108.85),Vector3(3.00,5.60,-115.51),Vector3(2.16,6.58,-121.84),Vector3(0.16,8.24,-127.33)],6.00,-1.00],
		["wall",[Vector3(11.80,15.00,0.00),Vector3(11.80,15.00,0.00),Vector3(11.42,15.03,-3.33),Vector3(11.96,15.48,-9.14),Vector3(14.15,15.78,-14.38),Vector3(19.14,15.28,-19.92),Vector3(24.05,13.94,-29.81),Vector3(25.60,12.09,-41.83),Vector3(22.86,10.37,-53.24),Vector3(17.34,9.26,-60.93),Vector3(14.89,8.88,-65.99),Vector3(14.25,8.98,-70.78),Vector3(15.52,9.00,-75.56),Vector3(18.98,8.55,-80.43),Vector3(24.07,7.63,-88.64),Vector3(27.20,6.53,-98.72),Vector3(27.82,5.67,-109.14),Vector3(26.81,5.60,-118.50),Vector3(25.34,6.58,-128.04),Vector3(21.90,8.24,-137.49)],6.00,1.00],
		["wall",[Vector3(-12.06,8.44,-227.30),Vector3(-7.18,8.20,-233.87),Vector3(-5.49,8.82,-238.61),Vector3(-5.95,9.75,-243.22),Vector3(-8.95,10.20,-248.16),Vector3(-13.45,9.93,-257.59),Vector3(-14.63,9.32,-269.23),Vector3(-12.11,9.00,-280.20),Vector3(-7.80,8.65,-287.30)],6.00,-1.00],
		["wall",[Vector3(10.26,8.44,-218.47),Vector3(15.20,8.20,-225.19),Vector3(18.40,8.82,-236.29),Vector3(17.52,9.75,-248.28),Vector3(12.97,10.20,-257.92),Vector3(9.93,9.93,-263.02),Vector3(9.33,9.32,-267.89),Vector3(10.77,9.00,-272.95),Vector3(15.00,8.65,-279.78)],6.00,1.00],
		["arch",Vector3(15.03,-17.45,-110.98),13.00,12.60,5.00,0.05,-0.45,false],
		["arch",Vector3(4.24,-8.32,-300.89),12.00,13.00,5.00,0.15,8.18,false],
		["stack",Vector2(6.50,-160.22),2.16,1.60,0.14,{}],
		["stack",Vector2(-2.71,-176.15),2.16,1.60,0.01,{}],
	],"tokens":[
		Vector3(0.85,0.33,-9.94),Vector3(1.55,0.55,-12.85),Vector3(5.38,0.71,-21.78),Vector3(9.96,-0.34,-30.02),
		Vector3(12.13,-2.44,-39.23),Vector3(10.18,-4.81,-49.71),Vector3(5.59,-6.02,-59.62),Vector3(3.61,-6.04,-70.37),
		Vector3(5.87,-6.06,-80.81),Vector3(10.67,-6.89,-90.10),Vector3(14.26,-8.34,-100.10),Vector3(15.03,-9.45,-110.98),
		Vector3(14.06,-9.15,-119.91),Vector3(11.84,-7.63,-128.48),Vector3(7.69,-5.52,-137.03),Vector3(2.76,-4.02,-145.00),
		Vector3(-0.18,-3.25,-154.21),Vector3(-0.07,-2.86,-161.18),Vector3(3.73,-1.99,-174.60),Vector3(4.68,-1.04,-183.47),
		Vector3(2.80,-1.09,-193.24),Vector3(-0.82,-2.70,-202.41),Vector3(-2.36,-4.87,-212.00),Vector3(-0.54,-6.44,-221.40),
		Vector3(3.22,-6.80,-230.11),Vector3(5.16,-5.95,-239.57),Vector3(3.71,-4.97,-248.61),Vector3(0.25,-4.89,-257.45),
		Vector3(-1.39,-5.53,-266.49),Vector3(-0.20,-5.96,-275.12),Vector3(2.65,-5.24,-283.07),Vector3(4.56,-3.05,-291.30),
		Vector3(4.24,-0.32,-300.89),Vector3(2.98,1.05,-310.69),
	]},
	{"id":"nature_stacks","key":-1,"pack":"nature","name":"Sea stacks (a lazy weave round them, a tunnel through one, a sea arch)","intent":"easy","ease":1.30,"parts":[
		["stack",Vector2(8.84,-10.40),4.32,3.20,15.54,{}],
		["stack",Vector2(-7.25,-18.36),3.24,2.40,6.54,{}],
		["stack",Vector2(1.02,-43.41),4.32,3.20,10.36,{}],
		["stack",Vector2(18.29,-48.17),3.24,2.40,1.36,{}],
		["stack",Vector2(8.22,-83.62),4.32,3.20,6.19,{}],
		["stack",Vector2(-8.99,-88.84),3.24,2.40,-0.81,{}],
		["stack",Vector2(2.40,-124.19),4.32,3.20,2.68,{}],
		["stack",Vector2(19.97,-128.41),3.24,2.40,-2.32,{}],
		["stack",Vector2(10.74,-164.49),4.32,3.20,2.74,{}],
		["stack",Vector2(-6.51,-169.56),3.24,2.40,-5.26,{}],
		["stack",Vector2(3.66,-204.90),4.32,3.20,6.94,{}],
		["stack",Vector2(20.88,-210.12),3.24,2.40,0.94,{}],
		["stack",Vector2(9.45,-245.25),4.32,3.20,11.95,{}],
		["stack",Vector2(-7.92,-249.39),3.24,2.40,2.95,{}],
		["stack",Vector2(1.83,-283.38),4.32,3.20,13.49,{}],
		["stack",Vector2(19.55,-285.84),3.24,2.40,11.49,{}],
		["stack",Vector2(-2.32,-60.61),2.43,1.80,1.42,{}],
		["stack",Vector2(10.71,-67.85),2.43,1.80,-3.58,{}],
		["stack",Vector2(-1.49,-106.98),2.43,1.80,-1.02,{}],
		["stack",Vector2(12.84,-102.94),2.43,1.80,-4.02,{}],
		["stack",Vector2(0.45,-187.44),2.43,1.80,-0.68,{}],
		["stack",Vector2(14.91,-183.92),2.43,1.80,-3.68,{}],
		["stack",Vector2(-0.17,-222.22),2.43,1.80,2.59,{}],
		["stack",Vector2(12.59,-229.90),2.43,1.80,-2.41,{}],
		["stack",Vector2(-1.71,-267.56),2.43,1.80,9.16,{}],
		["stack",Vector2(12.82,-264.50),2.43,1.80,6.16,{}],
		["stack",Vector2(6.65,-144.28),10.50,6.50,3.54,{"y":-15.66,"w":7.00,"h":6.50,"yaw":0.35}],
		["arch",Vector3(8.21,-8.33,-274.56),11.00,17.00,4.00,-0.25,12.67,false],
		["stack",Vector2(-8.65,-200.64),3.14,2.33,-8.56,{}],
		["stack",Vector2(31.58,-228.88),5.21,3.86,5.87,{}],
		["stack",Vector2(-10.36,-45.90),2.94,2.18,-5.51,{}],
		["stack",Vector2(24.62,-307.20),5.39,3.99,-3.26,{}],
		["stack",Vector2(-31.11,-240.79),3.71,2.75,-14.84,{}],
		["stack",Vector2(-18.33,-242.49),3.63,2.69,13.80,{}],
		["stack",Vector2(-32.19,-262.83),3.97,2.94,7.96,{}],
		["stack",Vector2(26.34,-153.93),3.01,2.23,-15.60,{}],
		["stack",Vector2(-25.79,-209.79),5.43,4.02,-14.64,{}],
		["stack",Vector2(-20.86,-254.21),3.84,2.84,-4.28,{}],
		["stack",Vector2(32.89,-82.32),3.53,2.62,8.88,{}],
		["stack",Vector2(-12.99,-125.05),4.27,3.16,1.58,{}],
		["stack",Vector2(-25.77,0.00),3.41,2.52,0.28,{}],
		["stack",Vector2(-27.08,-136.33),3.21,2.38,0.17,{}],
		["stack",Vector2(-21.09,-12.90),5.37,3.98,15.79,{}],
		["stack",Vector2(-16.57,-34.29),4.52,3.35,-3.15,{}],
		["stack",Vector2(-21.29,-301.93),4.04,2.99,22.16,{}],
		["stack",Vector2(31.32,-1.07),3.30,2.45,-2.42,{}],
		["stack",Vector2(30.62,-180.38),5.61,4.16,-16.59,{}],
		["stack",Vector2(41.67,-270.40),5.19,3.84,-0.80,{}],
		["stack",Vector2(27.19,-247.06),3.53,2.62,13.34,{}],
		["stack",Vector2(-9.66,-286.51),2.80,2.07,14.32,{}],
		["stack",Vector2(31.16,-164.74),3.78,2.80,-14.59,{}],
		["stack",Vector2(39.51,-301.99),5.85,4.33,-8.54,{}],
		["stack",Vector2(-28.92,-36.87),4.00,2.96,8.68,{}],
		["stack",Vector2(-18.02,-67.49),5.75,4.26,-4.38,{}],
		["stack",Vector2(-28.30,-96.17),2.86,2.12,-4.96,{}],
		["stack",Vector2(-21.51,-107.15),2.82,2.09,9.84,{}],
		["stack",Vector2(-21.22,-192.73),5.61,4.16,3.77,{}],
		["stack",Vector2(-19.30,-280.98),2.87,2.12,-2.73,{}],
	],"tokens":[
		Vector3(0.65,0.38,-9.96),Vector3(0.99,0.54,-11.92),Vector3(4.17,0.81,-22.43),Vector3(7.67,-0.28,-32.78),
		Vector3(9.01,-2.64,-43.41),Vector3(7.79,-4.99,-53.54),Vector3(4.56,-6.58,-63.39),Vector3(1.33,-7.08,-73.35),
		Vector3(0.20,-6.81,-83.76),Vector3(1.69,-6.54,-94.13),Vector3(5.27,-7.02,-103.97),Vector3(8.85,-8.44,-113.72),
		Vector3(10.44,-10.32,-123.91),Vector3(8.50,-12.27,-138.58),Vector3(4.78,-12.27,-149.98),Vector3(2.70,-10.26,-164.63),
		Vector3(4.05,-8.27,-174.83),Vector3(7.31,-6.68,-184.67),Vector3(10.54,-5.99,-194.62),Vector3(11.66,-6.06,-205.04),
		Vector3(10.18,-6.12,-215.40),Vector3(6.60,-5.41,-225.24),Vector3(3.04,-3.61,-234.93),Vector3(1.48,-1.05,-244.97),
		Vector3(2.34,1.48,-255.10),Vector3(5.22,3.16,-265.04),Vector3(8.21,3.67,-274.56),Vector3(9.68,3.49,-282.42),
		Vector3(10.04,3.26,-294.39),Vector3(9.02,4.62,-306.26),
	]},
	{"id":"nature_cove","key":-1,"pack":"nature","name":"Waterfall cove (along the cliff, round behind the fall, out through the headland)","intent":"easy","ease":1.30,"parts":[
		["wall",[Vector3(5.50,15.00,0.00),Vector3(5.50,15.00,0.00),Vector3(5.50,15.00,0.00),Vector3(5.50,15.00,0.00),Vector3(5.48,15.00,-2.09),Vector3(5.33,15.00,-6.34),Vector3(4.93,15.00,-10.64),Vector3(4.26,15.00,-14.92),Vector3(3.34,15.00,-19.11),Vector3(2.25,15.00,-23.16),Vector3(1.30,15.00,-26.77),Vector3(0.60,15.00,-30.30),Vector3(0.19,15.00,-33.78),Vector3(0.11,15.00,-37.24),Vector3(0.36,15.00,-40.70),Vector3(0.91,15.00,-44.20),Vector3(1.74,15.00,-47.76),Vector3(2.78,15.00,-51.38),Vector3(3.97,15.00,-54.87),Vector3(5.34,15.00,-58.19),Vector3(6.95,15.00,-61.32),Vector3(8.81,15.00,-64.25),Vector3(10.93,15.00,-66.97),Vector3(13.32,15.00,-69.47),Vector3(15.95,15.00,-71.77),Vector3(18.81,15.00,-73.89),Vector3(21.87,15.00,-75.86),Vector3(25.27,15.00,-77.87),Vector3(28.83,15.00,-80.19),Vector3(32.27,15.00,-82.77),Vector3(35.53,15.00,-85.66),Vector3(38.53,15.00,-88.87),Vector3(41.20,15.00,-92.40),Vector3(43.47,15.00,-96.21),Vector3(45.31,15.00,-100.26),Vector3(46.69,15.00,-104.50),Vector3(47.61,15.00,-108.89),Vector3(48.09,15.00,-113.34),Vector3(48.18,15.00,-117.78),Vector3(47.94,15.00,-122.14),Vector3(47.44,15.00,-126.39),Vector3(46.78,15.00,-130.56),Vector3(45.89,15.00,-134.75),Vector3(44.72,15.00,-138.92),Vector3(43.23,15.00,-143.01),Vector3(41.40,15.00,-146.98),Vector3(39.24,15.00,-150.77),Vector3(36.80,15.00,-154.36),Vector3(34.14,15.00,-157.73),Vector3(31.33,15.00,-160.90),Vector3(28.65,15.00,-163.73),Vector3(26.43,15.00,-166.42),Vector3(24.58,15.00,-169.20),Vector3(23.15,15.00,-172.10),Vector3(22.16,15.00,-175.14),Vector3(21.61,15.00,-178.33)],10.00,1.00],
		["wall",[Vector3(22.60,15.00,-178.43),Vector3(22.53,14.65,-183.10),Vector3(23.09,13.63,-188.08),Vector3(23.65,12.02,-194.20),Vector3(23.64,9.96,-200.22),Vector3(22.91,7.60,-206.50),Vector3(21.60,5.15,-212.32),Vector3(19.87,2.79,-217.96),Vector3(18.54,0.72,-222.80),Vector3(17.63,-0.88,-227.79),Vector3(17.27,-1.90,-232.62),Vector3(17.35,-2.25,-237.85)],10.00,1.00],
		["wall",[Vector3(35.98,14.00,-103.86),Vector3(36.79,14.00,-106.25),Vector3(37.42,14.00,-108.73),Vector3(37.85,14.00,-111.31),Vector3(38.11,14.00,-113.95),Vector3(38.19,14.00,-116.66),Vector3(38.11,14.00,-119.41),Vector3(37.89,14.00,-122.19),Vector3(37.54,14.00,-125.00)],0.80,-1.00],
		["stack",Vector2(-12.49,-44.54),3.51,2.60,8.00,{}],
		["stack",Vector2(21.13,-91.26),3.78,2.80,4.00,{}],
		["stack",Vector2(26.46,-100.78),2.97,2.20,1.00,{}],
		["stack",Vector2(-9.09,-16.03),2.97,2.20,7.17,{}],
		["stack",Vector2(-2.02,-71.89),2.97,2.20,2.18,{}],
		["stack",Vector2(30.78,-139.67),2.97,2.20,-9.01,{}],
		["stack",Vector2(9.43,-190.53),2.97,2.20,3.74,{}],
		["stack",Vector2(7.10,-212.34),2.97,2.20,12.46,{}],
		["arch",Vector3(20.87,-10.43,-164.74),9.00,7.20,8.00,0.59,15.00,true],
		["wall",[Vector3(14.63,15.00,-160.58),Vector3(-3.67,7.00,-148.38)],8.00,0.00],
		["stack",Vector2(17.71,-129.55),5.33,3.95,-21.67,{}],
		["stack",Vector2(47.85,-181.27),5.38,3.99,-9.07,{}],
		["stack",Vector2(44.17,-220.99),4.45,3.30,-8.38,{}],
		["stack",Vector2(55.64,-155.93),4.61,3.42,-8.39,{}],
		["stack",Vector2(25.15,-63.15),2.90,2.15,-13.08,{}],
		["stack",Vector2(39.38,-171.57),3.43,2.54,-11.31,{}],
		["stack",Vector2(-16.72,-218.37),4.60,3.41,7.01,{}],
		["stack",Vector2(18.55,-51.12),3.54,2.62,-13.30,{}],
		["stack",Vector2(67.18,-101.65),3.01,2.23,-13.07,{}],
		["stack",Vector2(25.51,-35.92),5.36,3.97,-10.51,{}],
		["stack",Vector2(-29.43,-34.41),4.44,3.29,-7.28,{}],
		["stack",Vector2(8.66,-115.54),4.92,3.64,-12.68,{}],
		["stack",Vector2(2.71,-157.94),3.06,2.27,-15.00,{}],
		["stack",Vector2(60.72,-84.80),3.24,2.40,-11.52,{}],
		["stack",Vector2(-16.77,-80.32),5.19,3.84,-15.60,{}],
		["stack",Vector2(-30.10,-61.23),3.06,2.27,-3.85,{}],
		["stack",Vector2(70.80,-128.33),2.81,2.08,-26.91,{}],
		["stack",Vector2(-4.89,-216.32),3.40,2.52,3.79,{}],
		["stack",Vector2(59.94,-166.53),3.35,2.48,-4.72,{}],
	],"tokens":[
		Vector3(-0.53,0.45,-9.96),Vector3(-2.00,1.17,-17.79),Vector3(-4.22,1.33,-26.25),Vector3(-5.36,0.72,-34.63),
		Vector3(-4.83,-0.10,-43.31),Vector3(-2.83,-0.55,-51.81),Vector3(0.04,-0.61,-59.81),Vector3(4.32,-0.82,-67.42),
		Vector3(10.43,-1.60,-74.29),Vector3(17.97,-2.85,-79.91),Vector3(25.69,-4.56,-84.70),Vector3(32.21,-6.67,-90.12),
		Vector3(37.29,-9.06,-96.48),Vector3(40.82,-11.57,-104.05),Vector3(42.60,-13.44,-113.68),Vector3(42.25,-13.78,-123.65),
		Vector3(40.54,-12.97,-133.45),Vector3(37.36,-11.01,-142.71),Vector3(32.80,-9.06,-150.50),Vector3(26.79,-7.56,-157.69),
		Vector3(20.87,-6.83,-164.74),Vector3(17.15,-6.59,-172.62),Vector3(15.97,-6.28,-181.00),Vector3(16.73,-5.26,-189.64),
		Vector3(17.22,-3.38,-198.17),Vector3(16.34,-1.24,-206.33),Vector3(14.12,0.46,-214.62),Vector3(11.28,1.29,-226.22),
		Vector3(10.86,1.75,-238.18),
	]},
	{"id":"nature_ridge","key":-1,"pack":"nature","name":"Ridge (along the face, through a notch, under an overhang, back under a natural bridge, over the end)","intent":"medium","parts":[
		["wall",[Vector3(-16.11,-6.31,-63.24),Vector3(-19.84,-6.31,-90.26)],18.00,0.00],
		["wall",[Vector3(-20.80,-9.63,-197.59),Vector3(-19.99,-9.63,-224.30)],18.00,0.00],
		["arch",Vector3(-20.40,-9.63,-210.94),14.00,10.40,7.00,-1.07,11.00,false],
		["wall",[Vector3(-13.50,13.00,0.00),Vector3(-13.50,13.00,0.00),Vector3(-13.50,13.00,0.00),Vector3(-13.50,13.00,0.00),Vector3(-13.50,13.00,0.00),Vector3(-13.50,13.00,0.00),Vector3(-13.55,13.00,-3.03),Vector3(-13.73,13.00,-5.99),Vector3(-14.11,13.00,-9.00),Vector3(-14.72,13.00,-12.14),Vector3(-15.55,13.00,-15.59),Vector3(-16.53,13.00,-20.36),Vector3(-17.14,13.00,-25.18),Vector3(-17.32,13.00,-30.49),Vector3(-16.95,13.00,-35.76),Vector3(-16.20,13.00,-40.42),Vector3(-15.20,13.00,-44.82),Vector3(-14.62,13.00,-47.67),Vector3(-14.35,13.00,-50.08),Vector3(-14.35,13.00,-52.37),Vector3(-14.61,13.00,-54.28),Vector3(-15.13,13.00,-56.10),Vector3(-16.11,13.00,-63.24)],18.00,0.00],
		["wall",[Vector3(-19.84,13.00,-90.26),Vector3(-21.42,13.00,-101.74),Vector3(-21.14,13.00,-104.52),Vector3(-20.62,13.00,-108.79),Vector3(-20.30,13.00,-113.64),Vector3(-20.33,13.00,-118.68),Vector3(-20.74,13.00,-123.40),Vector3(-21.51,13.00,-128.25),Vector3(-22.45,13.00,-132.51),Vector3(-23.24,13.00,-135.91),Vector3(-23.71,13.00,-138.76),Vector3(-23.89,13.00,-141.21),Vector3(-23.83,13.00,-143.78),Vector3(-23.48,13.00,-146.50),Vector3(-22.90,13.00,-149.35),Vector3(-21.95,13.00,-153.33),Vector3(-21.03,13.00,-157.83),Vector3(-20.35,13.00,-162.23),Vector3(-19.90,13.00,-167.04),Vector3(-19.77,13.00,-171.58),Vector3(-19.92,13.00,-176.35),Vector3(-20.31,13.00,-180.97),Vector3(-20.83,13.00,-185.11),Vector3(-21.10,13.00,-187.84),Vector3(-20.80,13.00,-197.59)],18.00,0.00],
		["wall",[Vector3(-19.99,13.00,-224.30),Vector3(-19.73,8.53,-232.88),Vector3(-19.98,6.23,-235.52),Vector3(-20.53,4.37,-239.02),Vector3(-21.18,2.74,-242.29),Vector3(-21.97,1.27,-245.38),Vector3(-22.94,-0.08,-248.36),Vector3(-24.79,-1.35,-254.07),Vector3(-26.65,-2.55,-259.77),Vector3(-28.50,-3.69,-265.48),Vector3(-30.36,-4.78,-271.19),Vector3(-32.21,-5.82,-276.89),Vector3(-34.06,-6.83,-282.60),Vector3(-35.92,-7.81,-288.31)],18.00,0.00],
		["stack",Vector2(5.21,-17.40),2.70,2.00,8.32,{}],
		["stack",Vector2(4.29,-37.69),2.70,2.00,5.23,{}],
		["stack",Vector2(-40.98,-112.80),2.70,2.00,2.96,{}],
		["stack",Vector2(-40.40,-173.11),2.70,2.00,4.42,{}],
		["stack",Vector2(-1.60,-248.98),2.70,2.00,6.84,{}],
		["box",Vector3(-33.11,3.33,-127.56),Vector3(9.00,4.00,6.60),0.21],
		["box",Vector3(-34.46,3.33,-133.39),Vector3(9.00,4.00,6.60),0.20],
		["box",Vector3(-35.29,2.76,-139.04),Vector3(9.00,4.00,6.60),0.08],
		["box",Vector3(-35.29,1.94,-144.67),Vector3(9.00,4.00,6.60),-0.08],
		["box",Vector3(-34.47,1.31,-150.31),Vector3(9.00,4.00,6.60),-0.20],
		["box",Vector3(-33.11,1.16,-156.12),Vector3(9.00,4.00,6.60),-0.22],
	],"tokens":[
		Vector3(-0.60,0.74,-9.93),Vector3(-1.71,1.32,-15.80),Vector3(-3.77,0.38,-27.53),Vector3(-2.65,-1.77,-39.24),
		Vector3(-0.83,-2.63,-50.28),Vector3(-2.66,-2.12,-61.28),Vector3(-8.73,-1.35,-70.32),Vector3(-17.93,-1.31,-76.73),
		Vector3(-26.98,-2.15,-82.39),Vector3(-33.25,-3.60,-91.18),Vector3(-34.93,-4.56,-101.67),Vector3(-33.88,-4.04,-112.35),
		Vector3(-34.08,-2.84,-121.25),Vector3(-35.75,-2.19,-130.06),Vector3(-37.40,-3.25,-141.85),Vector3(-35.75,-4.44,-153.64),
		Vector3(-33.81,-3.91,-163.42),Vector3(-33.29,-2.58,-173.31),Vector3(-34.33,-1.78,-184.22),Vector3(-33.94,-2.26,-194.89),
		Vector3(-28.91,-3.31,-204.49),Vector3(-20.40,-3.63,-210.94),Vector3(-11.78,-2.68,-217.20),Vector3(-6.90,-1.19,-226.25),
		Vector3(-6.54,-0.46,-236.90),Vector3(-8.48,-0.16,-247.21),Vector3(-11.91,0.14,-257.12),Vector3(-16.56,1.38,-266.44),
		Vector3(-20.83,4.03,-275.64),Vector3(-24.13,7.13,-285.11),
	]},
	{"id":"nature_cave","key":-1,"pack":"nature","name":"Sea cave (in at the mouth, out through a skylight, over the roof, back in, out the far mouth)","intent":"medium","parts":[
		["wall",[Vector3(-3.56,8.52,-21.43),Vector3(-1.33,8.52,-26.13),Vector3(0.10,8.52,-30.41),Vector3(0.92,8.52,-34.64),Vector3(1.00,8.52,-38.87),Vector3(0.32,8.52,-43.10),Vector3(-0.92,8.52,-47.15),Vector3(-3.33,8.52,-51.70),Vector3(-4.84,8.52,-57.14),Vector3(-5.55,8.52,-62.79),Vector3(-5.32,8.52,-68.30),Vector3(-4.25,8.52,-73.41),Vector3(-2.64,8.52,-78.14),Vector3(-0.46,8.52,-81.84),Vector3(0.41,8.52,-85.88),Vector3(0.45,8.52,-90.00),Vector3(-0.43,8.52,-94.06),Vector3(-2.01,8.52,-97.83),Vector3(-5.13,8.52,-101.68),Vector3(-7.57,8.52,-106.99),Vector3(-9.11,8.52,-112.98),Vector3(-9.34,8.52,-119.29),Vector3(-8.21,8.52,-125.37),Vector3(-6.15,8.52,-130.84),Vector3(-3.45,8.52,-134.98),Vector3(-2.05,8.52,-138.92),Vector3(-1.26,8.52,-142.60),Vector3(-1.07,8.52,-145.98),Vector3(-1.44,8.52,-149.64),Vector3(-2.37,8.52,-153.60),Vector3(-4.36,8.52,-157.88),Vector3(-5.81,8.52,-163.14),Vector3(-6.77,8.52,-168.71),Vector3(-7.02,8.52,-174.45),Vector3(-6.49,8.52,-180.16),Vector3(-5.28,8.52,-185.66),Vector3(-3.61,8.52,-190.84),Vector3(-1.48,8.52,-195.12),Vector3(-0.41,8.52,-199.22),Vector3(0.12,8.52,-203.51),Vector3(0.00,8.52,-207.81),Vector3(-0.76,8.52,-212.14),Vector3(-2.04,8.52,-216.54),Vector3(-4.25,8.52,-221.44)],10.00,-1.00],
		["wall",[Vector3(7.98,8.52,-18.14),Vector3(10.13,8.52,-22.56),Vector3(11.83,8.52,-27.88),Vector3(12.88,8.52,-33.62),Vector3(12.98,8.52,-39.56),Vector3(12.10,8.52,-45.36),Vector3(10.60,8.52,-50.51),Vector3(8.22,8.52,-54.97),Vector3(6.99,8.52,-59.19),Vector3(6.44,8.52,-63.22),Vector3(6.61,8.52,-67.02),Vector3(7.43,8.52,-70.69),Vector3(8.79,8.52,-74.46),Vector3(11.25,8.52,-79.19),Vector3(12.38,8.52,-84.96),Vector3(12.39,8.52,-91.15),Vector3(11.15,8.52,-97.19),Vector3(9.08,8.52,-102.40),Vector3(5.78,8.52,-106.66),Vector3(3.88,8.52,-110.57),Vector3(2.78,8.52,-114.54),Vector3(2.64,8.52,-118.56),Vector3(3.46,8.52,-122.60),Vector3(5.09,8.52,-126.63),Vector3(7.87,8.52,-131.00),Vector3(9.60,8.52,-136.05),Vector3(10.66,8.52,-141.18),Vector3(10.93,8.52,-146.06),Vector3(10.46,8.52,-151.20),Vector3(9.32,8.52,-156.32),Vector3(7.21,8.52,-161.04),Vector3(5.96,8.52,-165.46),Vector3(5.18,8.52,-169.83),Vector3(4.98,8.52,-174.17),Vector3(5.39,8.52,-178.50),Vector3(6.38,8.52,-182.84),Vector3(7.83,8.52,-187.22),Vector3(10.12,8.52,-192.07),Vector3(11.42,8.52,-197.26),Vector3(12.11,8.52,-203.00),Vector3(11.96,8.52,-208.80),Vector3(11.02,8.52,-214.43),Vector3(9.53,8.52,-219.72),Vector3(7.46,8.52,-224.06)],10.00,1.00],
		["box",Vector3(3.12,7.27,-21.60),Vector3(18.00,2.50,4.30),-0.30],
		["box",Vector3(4.32,7.27,-25.42),Vector3(18.00,2.50,4.30),-0.29],
		["box",Vector3(5.31,7.27,-29.28),Vector3(18.00,2.50,4.30),-0.21],
		["box",Vector3(5.97,7.27,-33.21),Vector3(18.00,2.50,4.30),-0.11],
		["box",Vector3(6.19,7.27,-37.18),Vector3(18.00,2.50,4.30),0.00],
		["box",Vector3(5.97,7.27,-41.14),Vector3(18.00,2.50,4.30),0.11],
		["box",Vector3(5.31,7.27,-45.07),Vector3(18.00,2.50,4.30),0.21],
		["box",Vector3(4.32,7.27,-48.94),Vector3(18.00,2.50,4.30),0.29],
		["box",Vector3(3.13,7.27,-52.75),Vector3(18.00,2.50,4.30),0.29],
		["box",Vector3(2.14,7.27,-56.60),Vector3(18.00,2.50,4.30),0.21],
		["box",Vector3(5.43,7.27,-89.73),Vector3(18.00,2.50,4.30),0.07],
		["box",Vector3(4.87,7.27,-93.68),Vector3(18.00,2.50,4.30),0.21],
		["box",Vector3(3.81,7.27,-97.53),Vector3(18.00,2.50,4.30),0.33],
		["box",Vector3(2.33,7.27,-101.24),Vector3(18.00,2.50,4.30),0.42],
		["box",Vector3(0.64,7.27,-104.86),Vector3(18.00,2.50,4.30),0.42],
		["box",Vector3(-0.81,7.27,-108.58),Vector3(18.00,2.50,4.30),0.32],
		["box",Vector3(-1.81,7.27,-112.43),Vector3(18.00,2.50,4.30),0.19],
		["box",Vector3(-2.25,7.27,-116.38),Vector3(18.00,2.50,4.30),0.03],
		["box",Vector3(-2.09,7.27,-120.34),Vector3(18.00,2.50,4.30),-0.12],
		["box",Vector3(-1.36,7.27,-124.26),Vector3(18.00,2.50,4.30),-0.25],
		["box",Vector3(-0.17,7.27,-128.07),Vector3(18.00,2.50,4.30),-0.35],
		["box",Vector3(1.26,7.27,-131.77),Vector3(18.00,2.50,4.30),-0.36],
		["box",Vector3(2.60,7.27,-156.48),Vector3(18.00,2.50,4.30),0.26],
		["box",Vector3(1.55,7.27,-160.27),Vector3(18.00,2.50,4.30),0.26],
		["box",Vector3(0.64,7.27,-164.15),Vector3(18.00,2.50,4.30),0.20],
		["box",Vector3(0.00,7.27,-168.09),Vector3(18.00,2.50,4.30),0.12],
		["box",Vector3(-0.30,7.27,-172.06),Vector3(18.00,2.50,4.30),0.03],
		["box",Vector3(-0.23,7.27,-176.03),Vector3(18.00,2.50,4.30),-0.06],
		["box",Vector3(0.21,7.27,-179.98),Vector3(18.00,2.50,4.30),-0.16],
		["box",Vector3(0.99,7.27,-183.89),Vector3(18.00,2.50,4.30),-0.23],
		["box",Vector3(2.03,7.27,-187.74),Vector3(18.00,2.50,4.30),-0.29],
		["box",Vector3(3.23,7.27,-191.56),Vector3(18.00,2.50,4.30),-0.29],
		["box",Vector3(4.26,7.27,-195.42),Vector3(18.00,2.50,4.30),-0.23],
		["box",Vector3(4.99,7.27,-199.33),Vector3(18.00,2.50,4.30),-0.14],
		["box",Vector3(5.36,7.27,-203.29),Vector3(18.00,2.50,4.30),-0.04],
		["box",Vector3(5.33,7.27,-207.26),Vector3(18.00,2.50,4.30),0.06],
		["box",Vector3(4.91,7.27,-211.21),Vector3(18.00,2.50,4.30),0.15],
		["box",Vector3(4.15,7.27,-215.13),Vector3(18.00,2.50,4.30),0.23],
		["box",Vector3(3.14,7.27,-219.00),Vector3(18.00,2.50,4.30),0.28],
		["box",Vector3(2.14,7.27,-222.87),Vector3(18.00,2.50,4.30),0.22],
		["box",Vector3(4.05,12.02,-108.34),Vector3(3.00,7.00,3.00),0.77],
		["box",Vector3(-6.74,12.02,-118.55),Vector3(3.00,7.00,3.00),0.36],
	],"tokens":[
		Vector3(0.53,0.48,-9.96),Vector3(2.55,1.53,-19.69),Vector3(5.15,1.58,-28.55),Vector3(6.18,0.63,-37.92),
		Vector3(4.85,-0.24,-47.01),Vector3(2.30,0.01,-55.88),Vector3(1.29,2.69,-64.88),Vector3(2.47,6.97,-72.98),
		Vector3(4.72,10.52,-80.91),Vector3(5.43,11.80,-89.73),Vector3(3.47,11.36,-98.47),Vector3(-0.14,11.31,-106.70),
		Vector3(-2.25,12.50,-118.36),Vector3(-0.42,13.14,-127.37),Vector3(2.71,11.30,-136.09),Vector3(4.10,6.97,-144.11),
		Vector3(3.39,2.02,-153.02),Vector3(0.96,-0.06,-162.69),Vector3(-0.31,0.69,-172.80),Vector3(0.76,1.77,-182.91),
		Vector3(3.58,1.94,-192.76),Vector3(5.33,1.02,-202.79),Vector3(4.61,-0.05,-212.93),Vector3(2.14,-0.06,-222.87),
		Vector3(1.16,1.54,-233.66),Vector3(3.11,3.81,-244.22),Vector3(5.43,4.67,-254.91),Vector3(5.69,4.89,-265.89),
	]},
	# <<< nature stations
]

## The kinds this pack adds.
static func owns(kind: String) -> bool:
	return kind in ["wall","stack","arch"]

## Part `part` as the course's solids, `at` the station's origin.
static func part_solids(part: Array, at: Vector3, floor_y: float) -> Array:
	var out := []
	match str(part[0]):
		"wall":
			var pts: Array = part[1]
			var thick := float(part[2])
			var side := float(part[3])
			for i in range(pts.size()-1):
				var a: Vector3 = pts[i]
				var b: Vector3 = pts[i+1]
				var d := Vector2(b.x-a.x,b.z-a.z)
				var length := d.length()
				if length < 0.01: continue
				d /= length
				var r := Vector2(-d.y,d.x)
				var top := (a.y+b.y)*0.5
				var mid := Vector2((a.x+b.x)*0.5,(a.z+b.z)*0.5)+r*side*thick*0.5
				out.append(_box(at+Vector3(mid.x,(floor_y+top)*0.5,mid.y),Vector3(thick,top-floor_y,length+OVERLAP),atan2(-d.x,-d.y)))
				# A drum at each inner point fills the chink where two boxes
				# meet at an angle, up to that point's own top.
				if i > 0:
					var o := Vector2(a.x,a.z)+r*side*thick*0.5
					out.append({"kind":"cyl","middle":at+Vector3(o.x,(floor_y+a.y)*0.5,o.y),"radius":thick*0.5,"height":a.y-floor_y})
		"stack":
			var xz: Vector2 = part[1]
			var base := float(part[2])
			var radius := float(part[3])
			var top := float(part[4])
			var hole: Dictionary = part[5]
			var r_at := func(y: float) -> float: return base+(radius-base)*(y-floor_y)/(top-floor_y)
			var bands := [[floor_y,top,false]]
			if not hole.is_empty():
				var hy := float(hole.y)
				var hh := float(hole.h)
				bands = [[floor_y,hy,false],[hy,hy+hh,true],[hy+hh,top,false]]
			for band: Array in bands:
				var y0 := float(band[0])
				var y1 := float(band[1])
				if y1-y0 < 0.01: continue
				if bool(band[2]):
					var mid := (y0+y1)*0.5
					var big: float = r_at.call(mid)
					var half := float(hole.w)*0.5
					var yaw := float(hole.yaw)
					for side: float in [-1.0,1.0]:
						var lx := side*(half+(big-half)*0.5)
						out.append(_box(at+Vector3(xz.x+cos(yaw)*lx,mid,xz.y-sin(yaw)*lx),Vector3(big-half,y1-y0,2.0*big),yaw))
					continue
				var n := maxi(1,ceili((y1-y0)/TIER))
				for j in range(n):
					var ya := y0+(y1-y0)*j/n
					var yb := y0+(y1-y0)*(j+1)/n
					out.append({"kind":"cyl","middle":at+Vector3(xz.x,(ya+yb)*0.5,xz.y),"radius":r_at.call((ya+yb)*0.5),"height":yb-ya})
		"arch":
			var bottom: Vector3 = part[1]
			var w := float(part[2])
			var h := float(part[3])
			var depth := float(part[4])
			var yaw := float(part[5])
			var crown := float(part[6])
			var sill := bool(part[7])
			var leg := float(part[8]) if part.size() > 8 else LEG
			var c := cos(yaw)
			var s := sin(yaw)
			var put := func(lx: float, my: float, size: Vector3) -> void:
				out.append(_box(at+Vector3(bottom.x+c*lx,my,bottom.z-s*lx),size,yaw))
			for side: float in [-1.0,1.0]:
				put.call(side*(w*0.5+leg*0.5),(floor_y+crown)*0.5,Vector3(leg,crown-floor_y,depth))
			var spring := ARCH_SPRING*h
			for j in range(ARCH_SLICES):
				var xc := -w*0.5+(j+0.5)*w/ARCH_SLICES
				var u := xc/(w*0.5)
				var ys := bottom.y+spring+(h-spring)*sqrt(maxf(0.0,1.0-u*u))
				put.call(xc,(ys+crown)*0.5,Vector3(w/ARCH_SLICES+0.02,crown-ys,depth))
			if sill:
				put.call(0.0,(floor_y+bottom.y)*0.5,Vector3(w,bottom.y-floor_y,depth))
	return out

static func _box(middle: Vector3, size: Vector3, yaw: float) -> Dictionary:
	return {"kind":"box","middle":middle,"size":size,"basis":Basis(Vector3.UP,yaw)}
