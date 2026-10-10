extends RefCounted
## The flight study's token-placement pack (studies/flight_study.gd
## `--pack=tokens`; docs/design/flight-study-tokens.md). Written by
## tools/flight_tokens_layout.py: edit that and rerun it, not this.
##
## Same geometry, different token placement: each station copies an existing
## station's parts (sundered_flow's hall, open_swoop's two pillars) and
## varies only where the tokens go. FlightCourse appends these to its
## STATIONS; they have no digit key (key -1), stand at their own `origin`
## (a row south of the main one) and are reached with N inside the pack,
## `--station=<id>` or `--pack=tokens`.
##
## Keys on top of a station's usual ones (FlightCourse):
##   pack    "tokens"
##   style   dense, sparse, gates, detours, hidden or outback
##   origin  where its entry stands in the world
##   guides  indices into `tokens` that are guides: not drawn, not counted,
##           only shaping the line (metrics) and the bots' route
##   bonus   optional tokens off the line: unordered, never missed, not
##           needed to clear (FlightRun `bonus_state`)

const STATIONS := [
	{"id":"tokens_hall_dense","key":-1,"pack":"tokens","style":"dense","origin":Vector3(0.0,40.0,1300.0),"name":"Tokens: hall, dense trail (baseline: sundered_flow's 21)","intent":"medium","parts":[
		["bay",Vector3(6.37,-2.40,-14.66),-0.3005,{"roof":"whole","inner":[]}],
		["bay",Vector3(8.73,-2.40,-22.30),-0.2278,{"roof":"whole","tie":"high","inner":[]}],
		["bay",Vector3(10.54,-2.40,-30.09),-0.1551,{"roof":"broken","gaps":[3,4],"inner":[0.0]}],
		["bay",Vector3(11.78,-2.40,-38.00),-0.0823,{"roof":"whole","inner":[0.0]}],
		["bay",Vector3(12.43,-2.40,-45.97),-0.0096,{"roof":"whole","tie":"low","inner":[]}],
		["bay",Vector3(12.51,-2.40,-53.97),0.0631,{"roof":"broken","gaps":[2,3],"inner":[0.0]}],
		["bay",Vector3(12.01,-2.40,-61.95),0.1358,{"roof":"open","inner":[0.0],"breach":["arch",""]}],
		["bay",Vector3(10.92,-2.40,-69.87),0.2086,{"roof":"open","tie":"high","inner":[]}],
		["bay",Vector3(9.27,-2.40,-77.70),0.2813,{"roof":"open","beam":false,"torn":2,"last":true,"inner":[0.0]}],
		["bay",Vector3(11.84,-7.40,-112.18),-0.4823,{"roof":"open","torn":1,"inner":[]}],
		["bay",Vector3(15.55,-7.40,-119.26),-0.5823,{"roof":"whole","tie":"low","inner":[]}],
		["bay",Vector3(19.95,-7.40,-125.94),-0.6823,{"roof":"broken","gaps":[1,2],"screen":true,"inner":[-2.6]}],
		["bay",Vector3(24.99,-7.40,-132.15),-0.7823,{"roof":"whole","screen":true,"inner":[-2.6]}],
		["bay",Vector3(30.63,-7.40,-137.82),-0.8823,{"roof":"open","tie":"high","beam":false,"inner":[]}],
		["bay",Vector3(36.81,-7.40,-142.90),-0.9823,{"roof":"open","beam":false,"torn":2,"last":true,"inner":[]}],
	],"tokens":[
		Vector3(3.10,4.50,-15.81),Vector3(8.73,6.00,-22.30),Vector3(13.94,4.50,-29.44),Vector3(15.22,1.50,-37.59),
		Vector3(12.43,0.00,-45.97),Vector3(9.05,1.50,-53.87),Vector3(8.56,4.50,-61.60),Vector3(10.92,6.00,-69.87),
		Vector3(12.63,4.50,-78.54),Vector3(10.34,1.50,-86.46),Vector3(7.46,0.52,-92.48),Vector3(5.81,0.46,-99.22),
		Vector3(5.59,-0.50,-105.89),Vector3(8.70,-3.50,-113.63),Vector3(15.55,-5.00,-119.26),Vector3(22.75,-4.22,-123.90),
		Vector3(27.57,-2.01,-129.83),Vector3(30.63,1.30,-137.82),Vector3(34.74,5.20,-145.68),Vector3(41.68,9.10,-150.31),
		Vector3(50.52,12.41,-151.09),
	],
	},
	{"id":"tokens_hall_sparse","key":-1,"pack":"tokens","style":"sparse","origin":Vector3(260.0,40.0,1300.0),"name":"Tokens: hall, sparse hints (5 at openings, find the line)","intent":"medium","parts":[
		["bay",Vector3(6.37,-2.40,-14.66),-0.3005,{"roof":"whole","inner":[]}],
		["bay",Vector3(8.73,-2.40,-22.30),-0.2278,{"roof":"whole","tie":"high","inner":[]}],
		["bay",Vector3(10.54,-2.40,-30.09),-0.1551,{"roof":"broken","gaps":[3,4],"inner":[0.0]}],
		["bay",Vector3(11.78,-2.40,-38.00),-0.0823,{"roof":"whole","inner":[0.0]}],
		["bay",Vector3(12.43,-2.40,-45.97),-0.0096,{"roof":"whole","tie":"low","inner":[]}],
		["bay",Vector3(12.51,-2.40,-53.97),0.0631,{"roof":"broken","gaps":[2,3],"inner":[0.0]}],
		["bay",Vector3(12.01,-2.40,-61.95),0.1358,{"roof":"open","inner":[0.0],"breach":["arch",""]}],
		["bay",Vector3(10.92,-2.40,-69.87),0.2086,{"roof":"open","tie":"high","inner":[]}],
		["bay",Vector3(9.27,-2.40,-77.70),0.2813,{"roof":"open","beam":false,"torn":2,"last":true,"inner":[0.0]}],
		["bay",Vector3(11.84,-7.40,-112.18),-0.4823,{"roof":"open","torn":1,"inner":[]}],
		["bay",Vector3(15.55,-7.40,-119.26),-0.5823,{"roof":"whole","tie":"low","inner":[]}],
		["bay",Vector3(19.95,-7.40,-125.94),-0.6823,{"roof":"broken","gaps":[1,2],"screen":true,"inner":[-2.6]}],
		["bay",Vector3(24.99,-7.40,-132.15),-0.7823,{"roof":"whole","screen":true,"inner":[-2.6]}],
		["bay",Vector3(30.63,-7.40,-137.82),-0.8823,{"roof":"open","tie":"high","beam":false,"inner":[]}],
		["bay",Vector3(36.81,-7.40,-142.90),-0.9823,{"roof":"open","beam":false,"torn":2,"last":true,"inner":[]}],
	],"tokens":[
		Vector3(3.10,4.50,-15.81),Vector3(8.73,6.00,-22.30),Vector3(13.94,4.50,-29.44),Vector3(15.22,1.50,-37.59),
		Vector3(12.43,0.00,-45.97),Vector3(9.05,1.50,-53.87),Vector3(8.56,4.50,-61.60),Vector3(10.92,6.00,-69.87),
		Vector3(12.63,4.50,-78.54),Vector3(10.34,1.50,-86.46),Vector3(7.46,0.52,-92.48),Vector3(5.81,0.46,-99.22),
		Vector3(5.59,-0.50,-105.89),Vector3(8.70,-3.50,-113.63),Vector3(15.55,-5.00,-119.26),Vector3(22.75,-4.22,-123.90),
		Vector3(27.57,-2.01,-129.83),Vector3(30.63,1.30,-137.82),Vector3(34.74,5.20,-145.68),Vector3(41.68,9.10,-150.31),
		Vector3(50.52,12.41,-151.09),
	],
	"guides":[0,2,3,5,6,7,8,10,11,12,13,15,16,17,18,20],
	},
	{"id":"tokens_hall_gates","key":-1,"pack":"tokens","style":"gates","origin":Vector3(520.0,40.0,1300.0),"name":"Tokens: hall, gate-only (9, one per opening)","intent":"medium","parts":[
		["bay",Vector3(6.37,-2.40,-14.66),-0.3005,{"roof":"whole","inner":[]}],
		["bay",Vector3(8.73,-2.40,-22.30),-0.2278,{"roof":"whole","tie":"high","inner":[]}],
		["bay",Vector3(10.54,-2.40,-30.09),-0.1551,{"roof":"broken","gaps":[3,4],"inner":[0.0]}],
		["bay",Vector3(11.78,-2.40,-38.00),-0.0823,{"roof":"whole","inner":[0.0]}],
		["bay",Vector3(12.43,-2.40,-45.97),-0.0096,{"roof":"whole","tie":"low","inner":[]}],
		["bay",Vector3(12.51,-2.40,-53.97),0.0631,{"roof":"broken","gaps":[2,3],"inner":[0.0]}],
		["bay",Vector3(12.01,-2.40,-61.95),0.1358,{"roof":"open","inner":[0.0],"breach":["arch",""]}],
		["bay",Vector3(10.92,-2.40,-69.87),0.2086,{"roof":"open","tie":"high","inner":[]}],
		["bay",Vector3(9.27,-2.40,-77.70),0.2813,{"roof":"open","beam":false,"torn":2,"last":true,"inner":[0.0]}],
		["bay",Vector3(11.84,-7.40,-112.18),-0.4823,{"roof":"open","torn":1,"inner":[]}],
		["bay",Vector3(15.55,-7.40,-119.26),-0.5823,{"roof":"whole","tie":"low","inner":[]}],
		["bay",Vector3(19.95,-7.40,-125.94),-0.6823,{"roof":"broken","gaps":[1,2],"screen":true,"inner":[-2.6]}],
		["bay",Vector3(24.99,-7.40,-132.15),-0.7823,{"roof":"whole","screen":true,"inner":[-2.6]}],
		["bay",Vector3(30.63,-7.40,-137.82),-0.8823,{"roof":"open","tie":"high","beam":false,"inner":[]}],
		["bay",Vector3(36.81,-7.40,-142.90),-0.9823,{"roof":"open","beam":false,"torn":2,"last":true,"inner":[]}],
	],"tokens":[
		Vector3(3.10,4.50,-15.81),Vector3(8.73,6.00,-22.30),Vector3(13.94,4.50,-29.44),Vector3(15.22,1.50,-37.59),
		Vector3(12.43,0.00,-45.97),Vector3(9.05,1.50,-53.87),Vector3(8.56,4.50,-61.60),Vector3(10.92,6.00,-69.87),
		Vector3(12.63,4.50,-78.54),Vector3(10.34,1.50,-86.46),Vector3(7.46,0.52,-92.48),Vector3(5.81,0.46,-99.22),
		Vector3(5.59,-0.50,-105.89),Vector3(8.70,-3.50,-113.63),Vector3(15.55,-5.00,-119.26),Vector3(22.75,-4.22,-123.90),
		Vector3(27.57,-2.01,-129.83),Vector3(30.63,1.30,-137.82),Vector3(34.74,5.20,-145.68),Vector3(41.68,9.10,-150.31),
		Vector3(50.52,12.41,-151.09),
	],
	"guides":[2,3,5,6,8,10,11,12,15,16,18,20],
	},
	{"id":"tokens_hall_detours","key":-1,"pack":"tokens","style":"detours","origin":Vector3(780.0,40.0,1300.0),"name":"Tokens: hall, risk detours (6 easy tokens + 4 bonus: under a tie, aisle gap, two slits)","intent":"medium","parts":[
		["bay",Vector3(6.37,-2.40,-14.66),-0.3005,{"roof":"whole","inner":[]}],
		["bay",Vector3(8.73,-2.40,-22.30),-0.2278,{"roof":"whole","tie":"high","inner":[]}],
		["bay",Vector3(10.54,-2.40,-30.09),-0.1551,{"roof":"broken","gaps":[3,4],"inner":[0.0]}],
		["bay",Vector3(11.78,-2.40,-38.00),-0.0823,{"roof":"whole","inner":[0.0]}],
		["bay",Vector3(12.43,-2.40,-45.97),-0.0096,{"roof":"whole","tie":"low","inner":[]}],
		["bay",Vector3(12.51,-2.40,-53.97),0.0631,{"roof":"broken","gaps":[2,3],"inner":[0.0]}],
		["bay",Vector3(12.01,-2.40,-61.95),0.1358,{"roof":"open","inner":[0.0],"breach":["arch",""]}],
		["bay",Vector3(10.92,-2.40,-69.87),0.2086,{"roof":"open","tie":"high","inner":[]}],
		["bay",Vector3(9.27,-2.40,-77.70),0.2813,{"roof":"open","beam":false,"torn":2,"last":true,"inner":[0.0]}],
		["bay",Vector3(11.84,-7.40,-112.18),-0.4823,{"roof":"open","torn":1,"inner":[]}],
		["bay",Vector3(15.55,-7.40,-119.26),-0.5823,{"roof":"whole","tie":"low","inner":[]}],
		["bay",Vector3(19.95,-7.40,-125.94),-0.6823,{"roof":"broken","gaps":[1,2],"screen":true,"inner":[-2.6]}],
		["bay",Vector3(24.99,-7.40,-132.15),-0.7823,{"roof":"whole","screen":true,"inner":[-2.6]}],
		["bay",Vector3(30.63,-7.40,-137.82),-0.8823,{"roof":"open","tie":"high","beam":false,"inner":[]}],
		["bay",Vector3(36.81,-7.40,-142.90),-0.9823,{"roof":"open","beam":false,"torn":2,"last":true,"inner":[]}],
	],"tokens":[
		Vector3(3.10,4.50,-15.81),Vector3(8.73,6.00,-22.30),Vector3(13.94,4.50,-29.44),Vector3(15.22,1.50,-37.59),
		Vector3(12.43,0.00,-45.97),Vector3(9.05,1.50,-53.87),Vector3(8.56,4.50,-61.60),Vector3(10.92,6.00,-69.87),
		Vector3(12.63,4.50,-78.54),Vector3(10.34,1.50,-86.46),Vector3(7.46,0.52,-92.48),Vector3(5.81,0.46,-99.22),
		Vector3(5.59,-0.50,-105.89),Vector3(8.70,-3.50,-113.63),Vector3(15.55,-5.00,-119.26),Vector3(22.75,-4.22,-123.90),
		Vector3(27.57,-2.01,-129.83),Vector3(30.63,1.30,-137.82),Vector3(34.74,5.20,-145.68),Vector3(41.68,9.10,-150.31),
		Vector3(50.52,12.41,-151.09),
	],
	"guides":[1,2,3,5,6,8,10,11,12,14,15,16,17,18,20],
	"bonus":[
		Vector3(8.73,2.00,-22.30),   # under the first high tie
		Vector3(22.90,0.60,-36.67),   # aisle gap, knife edge
		Vector3(15.11,-4.75,-129.49),   # B's first slit
		Vector3(20.53,-4.75,-136.16),   # B's second slit
	],
	},
	{"id":"tokens_hall_hidden","key":-1,"pack":"tokens","style":"hidden","origin":Vector3(1040.0,40.0,1300.0),"name":"Tokens: hall, hidden (gate line + 5 bonus: roof, column, outside, under, aisle)","intent":"medium","parts":[
		["bay",Vector3(6.37,-2.40,-14.66),-0.3005,{"roof":"whole","inner":[]}],
		["bay",Vector3(8.73,-2.40,-22.30),-0.2278,{"roof":"whole","tie":"high","inner":[]}],
		["bay",Vector3(10.54,-2.40,-30.09),-0.1551,{"roof":"broken","gaps":[3,4],"inner":[0.0]}],
		["bay",Vector3(11.78,-2.40,-38.00),-0.0823,{"roof":"whole","inner":[0.0]}],
		["bay",Vector3(12.43,-2.40,-45.97),-0.0096,{"roof":"whole","tie":"low","inner":[]}],
		["bay",Vector3(12.51,-2.40,-53.97),0.0631,{"roof":"broken","gaps":[2,3],"inner":[0.0]}],
		["bay",Vector3(12.01,-2.40,-61.95),0.1358,{"roof":"open","inner":[0.0],"breach":["arch",""]}],
		["bay",Vector3(10.92,-2.40,-69.87),0.2086,{"roof":"open","tie":"high","inner":[]}],
		["bay",Vector3(9.27,-2.40,-77.70),0.2813,{"roof":"open","beam":false,"torn":2,"last":true,"inner":[0.0]}],
		["bay",Vector3(11.84,-7.40,-112.18),-0.4823,{"roof":"open","torn":1,"inner":[]}],
		["bay",Vector3(15.55,-7.40,-119.26),-0.5823,{"roof":"whole","tie":"low","inner":[]}],
		["bay",Vector3(19.95,-7.40,-125.94),-0.6823,{"roof":"broken","gaps":[1,2],"screen":true,"inner":[-2.6]}],
		["bay",Vector3(24.99,-7.40,-132.15),-0.7823,{"roof":"whole","screen":true,"inner":[-2.6]}],
		["bay",Vector3(30.63,-7.40,-137.82),-0.8823,{"roof":"open","tie":"high","beam":false,"inner":[]}],
		["bay",Vector3(36.81,-7.40,-142.90),-0.9823,{"roof":"open","beam":false,"torn":2,"last":true,"inner":[]}],
	],"tokens":[
		Vector3(3.10,4.50,-15.81),Vector3(8.73,6.00,-22.30),Vector3(13.94,4.50,-29.44),Vector3(15.22,1.50,-37.59),
		Vector3(12.43,0.00,-45.97),Vector3(9.05,1.50,-53.87),Vector3(8.56,4.50,-61.60),Vector3(10.92,6.00,-69.87),
		Vector3(12.63,4.50,-78.54),Vector3(10.34,1.50,-86.46),Vector3(7.46,0.52,-92.48),Vector3(5.81,0.46,-99.22),
		Vector3(5.59,-0.50,-105.89),Vector3(8.70,-3.50,-113.63),Vector3(15.55,-5.00,-119.26),Vector3(22.75,-4.22,-123.90),
		Vector3(27.57,-2.01,-129.83),Vector3(30.63,1.30,-137.82),Vector3(34.74,5.20,-145.68),Vector3(41.68,9.10,-150.31),
		Vector3(50.52,12.41,-151.09),
	],
	"guides":[2,3,5,6,8,10,11,12,15,16,18,20],
	"bonus":[
		Vector3(12.43,10.20,-45.97),   # on A's roof
		Vector3(11.42,0.60,-40.24),   # behind a column
		Vector3(-3.82,0.20,-63.82),   # outside the arch
		Vector3(8.23,-5.80,-81.56),   # under A's floor
		Vector3(35.26,-3.80,-127.58),   # B's right aisle
	],
	},
	{"id":"tokens_hall_outback","key":-1,"pack":"tokens","style":"outback","origin":Vector3(1300.0,40.0,1300.0),"name":"Tokens: hall, out and back in (out the arch, along the wall, back over it)","intent":"medium","parts":[
		["bay",Vector3(6.37,-2.40,-14.66),-0.3005,{"roof":"whole","inner":[]}],
		["bay",Vector3(8.73,-2.40,-22.30),-0.2278,{"roof":"whole","tie":"high","inner":[]}],
		["bay",Vector3(10.54,-2.40,-30.09),-0.1551,{"roof":"broken","gaps":[3,4],"inner":[0.0]}],
		["bay",Vector3(11.78,-2.40,-38.00),-0.0823,{"roof":"whole","inner":[0.0]}],
		["bay",Vector3(12.43,-2.40,-45.97),-0.0096,{"roof":"whole","tie":"low","inner":[]}],
		["bay",Vector3(12.51,-2.40,-53.97),0.0631,{"roof":"broken","gaps":[2,3],"inner":[0.0]}],
		["bay",Vector3(12.01,-2.40,-61.95),0.1358,{"roof":"open","inner":[0.0],"breach":["arch",""]}],
		["bay",Vector3(10.92,-2.40,-69.87),0.2086,{"roof":"open","tie":"high","inner":[]}],
		["bay",Vector3(9.27,-2.40,-77.70),0.2813,{"roof":"open","beam":false,"torn":2,"last":true,"inner":[0.0]}],
		["bay",Vector3(11.84,-7.40,-112.18),-0.4823,{"roof":"open","torn":1,"inner":[]}],
		["bay",Vector3(15.55,-7.40,-119.26),-0.5823,{"roof":"whole","tie":"low","inner":[]}],
		["bay",Vector3(19.95,-7.40,-125.94),-0.6823,{"roof":"broken","gaps":[1,2],"screen":true,"inner":[-2.6]}],
		["bay",Vector3(24.99,-7.40,-132.15),-0.7823,{"roof":"whole","screen":true,"inner":[-2.6]}],
		["bay",Vector3(30.63,-7.40,-137.82),-0.8823,{"roof":"open","tie":"high","beam":false,"inner":[]}],
		["bay",Vector3(36.81,-7.40,-142.90),-0.9823,{"roof":"open","beam":false,"torn":2,"last":true,"inner":[]}],
	],"tokens":[
		Vector3(3.10,4.50,-15.81),Vector3(8.73,6.00,-22.30),Vector3(13.94,4.50,-29.44),Vector3(15.22,1.50,-37.59),
		Vector3(12.43,0.00,-45.97),Vector3(9.51,0.90,-53.89),Vector3(8.74,1.00,-57.73),Vector3(6.67,0.80,-61.03),
		Vector3(3.62,0.60,-63.16),Vector3(-0.86,0.50,-65.03),Vector3(-3.64,0.83,-66.48),Vector3(-5.70,1.17,-68.60),
		Vector3(-6.81,1.50,-71.18),Vector3(-6.89,1.83,-73.99),Vector3(-5.93,2.17,-76.78),Vector3(-4.03,2.50,-79.27),
		Vector3(-2.02,2.20,-85.31),Vector3(0.02,0.60,-92.17),Vector3(5.59,-0.50,-105.89),Vector3(8.70,-3.50,-113.63),
		Vector3(15.55,-5.00,-119.26),Vector3(22.75,-4.22,-123.90),Vector3(27.57,-2.01,-129.83),Vector3(30.63,1.30,-137.82),
		Vector3(34.74,5.20,-145.68),Vector3(41.68,9.10,-150.31),Vector3(50.52,12.41,-151.09),
	],
	},
	{"id":"tokens_swoop_dense","key":-1,"pack":"tokens","style":"dense","origin":Vector3(1560.0,40.0,1300.0),"name":"Tokens: open swoop, dense trail (baseline: open_swoop's 8)","intent":"medium","parts":[
		["pillar",Vector2(-30.0,-40.0),2.0],
		["pillar",Vector2(40.0,-90.0),2.0],
	],"tokens":[
		Vector3(0.00,0.00,-14.00),Vector3(-3.00,-3.00,-30.00),Vector3(-10.00,-7.00,-45.00),Vector3(-14.00,-9.00,-62.00),
		Vector3(-11.00,-8.00,-80.00),Vector3(-2.00,-5.00,-95.00),Vector3(10.00,-1.00,-106.00),Vector3(24.00,3.00,-112.00),
	],
	},
	{"id":"tokens_swoop_skim","key":-1,"pack":"tokens","style":"gates","origin":Vector3(1820.0,40.0,1300.0),"name":"Tokens: open swoop, skim the rock (2 tokens, each tight past a pillar)","intent":"medium","parts":[
		["pillar",Vector2(-30.0,-40.0),2.0],
		["pillar",Vector2(40.0,-90.0),2.0],
	],"tokens":[
		Vector3(-3.00,0.00,-14.00),Vector3(-12.00,-2.00,-24.00),Vector3(-21.00,-4.00,-33.00),Vector3(-26.30,-6.00,-41.00),
		Vector3(-26.00,-7.00,-52.00),Vector3(-18.00,-8.00,-63.00),Vector3(-4.00,-7.00,-71.00),Vector3(12.00,-5.00,-77.00),
		Vector3(25.50,-3.00,-83.00),Vector3(35.20,-1.00,-90.00),Vector3(41.50,1.00,-100.00),Vector3(46.00,3.00,-112.00),
	],
	"guides":[0,1,2,4,5,6,7,8,10,11],
	},
	{"id":"tokens_swoop_detours","key":-1,"pack":"tokens","style":"detours","origin":Vector3(2080.0,40.0,1300.0),"name":"Tokens: open swoop, risk detours (baseline + 3 bonus tight on the pillars)","intent":"medium","parts":[
		["pillar",Vector2(-30.0,-40.0),2.0],
		["pillar",Vector2(40.0,-90.0),2.0],
	],"tokens":[
		Vector3(0.00,0.00,-14.00),Vector3(-3.00,-3.00,-30.00),Vector3(-10.00,-7.00,-45.00),Vector3(-14.00,-9.00,-62.00),
		Vector3(-11.00,-8.00,-80.00),Vector3(-2.00,-5.00,-95.00),Vector3(10.00,-1.00,-106.00),Vector3(24.00,3.00,-112.00),
	],
	"bonus":[
		Vector3(-26.60,-8.00,-40.00),   # skim the first pillar
		Vector3(36.40,-2.00,-90.00),   # skim the second pillar
		Vector3(43.60,1.00,-92.00),   # behind the second pillar
	],
	},
]
