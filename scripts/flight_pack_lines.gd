extends RefCounted
## The flight study's `lines` pack (scripts/flight_course.gd appends these
## STATIONS after its own): greybox halls with three token lines through the
## same stone, laid out flow-first by tools/flight_lines_layout.py (the
## lines designed, the hall stood round them; --write rewrites the blocks
## between the markers).
##   green   the station's own `tokens`: the forgiving main line
##   yellow  branches off green for more threading and rejoins it
##   red     the tight mastery line: knife-edge slits and close skims
## Each is flown on its own (FlightCourse `flown`, id "id@yellow"), with its
## own hash, runs and band. The halls bend up and down along their length
## (bays tilted, `pitch`), and the lines leave them through breaches and
## come back in through others. No digit key (key -1): reached with N,
## --station=<id> or --pack=lines, and L in the study switches the line.

const STATIONS := [
	# >>> lines_bend: written by tools/flight_lines_layout.py --write
	{"id":"lines_bend","key":-1,"pack":"lines","name":"Bending nave: three lines (crest exit, spires, re-entry)","intent":"easy","ease":1.3,"parts":[
		["bay",Vector3(-1.07,-5.00,-15.95),0.1669,{"roof":"whole","inner":[],"pitch":0.052}],
		["bay",Vector3(-2.40,-4.58,-23.84),0.2336,{"roof":"whole","inner":[],"pitch":0.148}],
		["bay",Vector3(-4.25,-3.39,-31.62),0.3003,{"roof":"broken","gaps":[2,3],"inner":[],"pitch":0.220}],
		["bay",Vector3(-6.62,-1.60,-39.26),0.3669,{"roof":"whole","inner":[],"pitch":0.257}],
		["bay",Vector3(-9.49,0.50,-46.73),0.4336,{"roof":"whole","inner":[],"pitch":0.257}],
		["bay",Vector3(-12.85,2.60,-53.99),0.5003,{"roof":"whole","inner":[],"pitch":0.220}],
		["bay",Vector3(-16.68,4.39,-61.00),0.5669,{"roof":"whole","inner":[],"rows":[1],"breach":["arch",""],"pitch":0.148}],
		["bay",Vector3(-20.98,5.58,-67.75),0.6336,{"roof":"broken","gaps":[3,4],"inner":[],"pitch":0.052}],
		["bay",Vector3(-25.71,6.00,-74.20),0.7003,{"roof":"whole","inner":[],"pitch":-0.041}],
		["bay",Vector3(-30.87,5.68,-80.31),0.7669,{"roof":"whole","inner":[],"pitch":-0.118}],
		["bay",Vector3(-36.42,4.73,-86.07),0.8336,{"roof":"open","inner":[],"rows":[1],"breach":["collapse",""],"pitch":-0.184}],
		["bay",Vector3(-42.34,3.24,-91.45),0.9003,{"roof":"broken","gaps":[1,2],"tie":"low","inner":[],"rows":[1],"breach":["collapse",""],"pitch":-0.235}],
		["bay",Vector3(-48.61,1.32,-96.42),0.9669,{"roof":"whole","inner":[],"pitch":-0.267}],
		["bay",Vector3(-55.19,-0.86,-100.96),1.0336,{"roof":"whole","inner":[-2.6],"screen":true,"pitch":-0.277}],
		["bay",Vector3(-62.06,-3.14,-105.05),1.1003,{"roof":"whole","inner":[],"pitch":-0.267}],
		["bay",Vector3(-69.19,-5.32,-108.68),1.1669,{"roof":"open","inner":[],"breach":["collapse",""],"pitch":-0.235}],
		["bay",Vector3(-76.55,-7.24,-111.82),1.2336,{"roof":"open","inner":[],"rows":[1],"breach":["collapse",""],"pitch":-0.184}],
		["bay",Vector3(-84.10,-8.73,-114.47),1.3003,{"roof":"whole","inner":[],"rows":[1],"pitch":-0.118}],
		["bay",Vector3(-91.80,-9.68,-116.61),1.3669,{"roof":"whole","inner":[],"pitch":-0.041}],
		["bay",Vector3(-99.64,-10.00,-118.23),1.4153,{"roof":"whole","inner":[]}],
		["bay",Vector3(-107.54,-10.00,-119.47),1.3536,{"roof":"whole","inner":[-2.6],"screen":true}],
		["bay",Vector3(-115.35,-10.00,-121.19),1.2736,{"roof":"whole","inner":[]}],
		["bay",Vector3(-123.00,-10.00,-123.53),1.1936,{"roof":"whole","inner":[]}],
		["bay",Vector3(-130.43,-10.00,-126.48),1.1136,{"roof":"broken","gaps":[3,4],"inner":[]}],
		["bay",Vector3(-137.61,-10.00,-130.01),1.0336,{"roof":"whole","inner":[]}],
		["bay",Vector3(-144.48,-10.00,-134.10),0.9536,{"roof":"whole","inner":[]}],
		["bay",Vector3(-151.00,-10.00,-138.73),0.8736,{"roof":"whole","inner":[],"torn":2,"last":true}],
		["pillar",Vector2(-53.06,-66.67),2.0],
		["pillar",Vector2(-67.88,-81.18),2.0],
	],"tokens":[
		Vector3(0.79,-0.33,-16.20),Vector3(-1.15,0.22,-28.25),Vector3(-7.80,2.69,-38.85),Vector3(-12.98,6.82,-49.52),
		Vector3(-15.33,9.91,-61.80),Vector3(-22.50,10.59,-71.60),Vector3(-33.69,10.01,-77.77),Vector3(-46.41,7.59,-81.01),
		Vector3(-58.28,4.32,-83.35),Vector3(-68.06,1.54,-87.17),Vector3(-76.01,-0.99,-94.10),Vector3(-83.59,-3.43,-103.82),
		Vector3(-92.44,-4.40,-113.96),Vector3(-103.26,-4.75,-121.23),Vector3(-114.51,-5.54,-124.37),Vector3(-126.28,-5.72,-126.11),
		Vector3(-136.96,-4.90,-131.20),Vector3(-145.62,-4.66,-139.41),Vector3(-155.03,-5.28,-146.18),
	],"lines":{
		"yellow":{"intent":"medium","tokens":[
			Vector3(0.79,-0.33,-16.20),Vector3(-1.15,0.22,-28.25),Vector3(-7.80,2.69,-38.85),Vector3(-13.87,5.07,-49.10),
			Vector3(-25.08,7.24,-56.05),Vector3(-36.55,9.49,-61.28),Vector3(-44.49,10.01,-68.03),Vector3(-55.30,7.59,-71.23),
			Vector3(-65.36,4.32,-73.79),Vector3(-72.55,1.54,-79.63),Vector3(-78.25,-0.99,-89.30),Vector3(-84.43,-3.43,-101.41),
			Vector3(-92.65,-4.40,-113.10),Vector3(-103.26,-4.75,-121.23),Vector3(-114.51,-5.54,-124.37),Vector3(-126.28,-5.72,-126.11),
			Vector3(-136.96,-4.90,-131.20),Vector3(-145.62,-4.66,-139.41),Vector3(-155.03,-5.28,-146.18),
		]},
		"red":{"intent":"hard","ease":0.75,"tokens":[
			Vector3(0.79,-0.33,-16.20),Vector3(-1.15,0.22,-28.25),Vector3(-7.80,2.69,-38.85),Vector3(-12.98,6.82,-49.52),
			Vector3(-15.33,9.91,-61.80),Vector3(-22.50,10.59,-71.60),Vector3(-32.30,9.15,-79.02),Vector3(-41.46,6.71,-86.47),
			Vector3(-45.01,5.84,-88.31),Vector3(-52.07,4.72,-91.74),Vector3(-58.43,1.79,-95.91),Vector3(-61.66,0.78,-97.91),
			Vector3(-68.71,-0.92,-105.12),Vector3(-69.96,-1.21,-107.04),Vector3(-79.31,-3.56,-116.04),Vector3(-90.01,-5.67,-115.56),
			Vector3(-92.23,-5.88,-114.85),Vector3(-104.41,-7.18,-112.90),Vector3(-108.60,-7.35,-113.56),Vector3(-116.84,-6.58,-115.50),
			Vector3(-127.95,-5.72,-121.88),Vector3(-137.15,-4.90,-130.85),Vector3(-145.62,-4.66,-139.41),Vector3(-155.03,-5.28,-146.18),
		]},
	}},
	# <<< lines_bend
]
