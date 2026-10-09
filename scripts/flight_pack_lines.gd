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
		["bay",Vector3(1.07,-5.00,-15.95),-0.1668,{"roof":"whole","inner":[],"pitch":0.052}],
		["bay",Vector3(2.40,-4.58,-23.84),-0.2335,{"roof":"whole","inner":[],"pitch":0.148}],
		["bay",Vector3(4.25,-3.39,-31.62),-0.3002,{"roof":"broken","gaps":[3,2],"inner":[],"pitch":0.220}],
		["bay",Vector3(6.61,-1.60,-39.26),-0.3668,{"roof":"whole","inner":[],"pitch":0.257}],
		["bay",Vector3(9.48,0.50,-46.73),-0.4335,{"roof":"whole","inner":[],"pitch":0.257}],
		["bay",Vector3(12.84,2.60,-53.99),-0.5002,{"roof":"whole","inner":[],"pitch":0.220}],
		["bay",Vector3(16.68,4.39,-61.01),-0.5668,{"roof":"whole","inner":[],"rows":[-1],"breach":["","arch"],"pitch":0.148}],
		["bay",Vector3(20.97,5.58,-67.75),-0.6335,{"roof":"broken","gaps":[2,1],"inner":[],"pitch":0.052}],
		["bay",Vector3(25.71,6.00,-74.20),-0.7002,{"roof":"whole","inner":[],"pitch":-0.041}],
		["bay",Vector3(30.86,5.68,-80.32),-0.7668,{"roof":"open","inner":[],"breach":["","collapse"],"pitch":-0.118}],
		["bay",Vector3(36.41,4.73,-86.08),-0.8335,{"roof":"open","inner":[],"rows":[-1],"breach":["","collapse"],"pitch":-0.184}],
		["bay",Vector3(42.33,3.24,-91.45),-0.9002,{"roof":"broken","gaps":[4,3],"tie":"low","inner":[],"rows":[-1],"breach":["","collapse"],"pitch":-0.235}],
		["bay",Vector3(48.60,1.32,-96.43),-0.9668,{"roof":"open","inner":[],"breach":["","collapse"],"pitch":-0.267}],
		["bay",Vector3(55.18,-0.86,-100.97),-1.0335,{"roof":"whole","inner":[2.6],"screen":"right","pitch":-0.277}],
		["bay",Vector3(62.05,-3.14,-105.06),-1.1002,{"roof":"open","inner":[],"breach":["","collapse"],"pitch":-0.267}],
		["bay",Vector3(69.18,-5.32,-108.69),-1.1442,{"roof":"open","inner":[],"breach":["","collapse"],"pitch":-0.235}],
		["bay",Vector3(76.46,-7.24,-112.00),-1.0525,{"roof":"open","inner":[],"rows":[-1],"breach":["","collapse"],"pitch":-0.184}],
		["bay",Vector3(83.41,-8.73,-115.96),-0.9383,{"roof":"open","inner":[],"rows":[-1],"breach":["","collapse"],"pitch":-0.118}],
		["bay",Vector3(89.86,-9.68,-120.69),-0.8240,{"roof":"whole","inner":[],"pitch":-0.041}],
		["bay",Vector3(95.72,-10.00,-126.12),-0.7097,{"roof":"whole","inner":[]}],
		["bay",Vector3(100.93,-10.00,-132.18),-0.5954,{"roof":"whole","inner":[2.6],"screen":"right"}],
		["bay",Vector3(105.42,-10.00,-138.80),-0.4811,{"roof":"whole","inner":[]}],
		["bay",Vector3(109.12,-10.00,-145.89),-0.3668,{"roof":"whole","inner":[]}],
		["bay",Vector3(111.99,-10.00,-153.35),-0.2525,{"roof":"broken","gaps":[2,1],"inner":[]}],
		["bay",Vector3(113.98,-10.00,-161.10),-0.1383,{"roof":"whole","inner":[]}],
		["bay",Vector3(115.09,-10.00,-169.02),-0.0240,{"roof":"whole","inner":[]}],
		["bay",Vector3(115.28,-10.00,-177.01),0.0903,{"roof":"whole","inner":[],"torn":2,"last":true}],
		["pillar",Vector2(53.05,-66.67),2.0],
		["pillar",Vector2(68.41,-80.35),2.0],
	],"tokens":[
		Vector3(-0.05,-0.33,-16.10),Vector3(2.06,0.22,-28.03),Vector3(8.03,2.69,-38.77),Vector3(12.98,6.82,-49.52),
		Vector3(15.32,9.91,-61.80),Vector3(22.49,10.59,-71.60),Vector3(33.68,10.01,-77.77),Vector3(46.40,7.59,-81.02),
		Vector3(58.27,4.32,-83.35),Vector3(68.05,1.54,-87.18),Vector3(76.00,-0.99,-94.10),Vector3(84.92,-3.43,-105.24),
		Vector3(91.59,-4.40,-118.58),Vector3(96.59,-4.75,-130.65),Vector3(102.53,-5.54,-140.53),Vector3(108.71,-5.72,-150.33),
		Vector3(111.85,-4.90,-161.52),Vector3(111.47,-4.66,-173.10),Vector3(111.18,-5.28,-184.47),
	],"lines":{
		"yellow":{"intent":"medium","tokens":[
			Vector3(-0.05,-0.33,-16.10),Vector3(2.06,0.22,-28.03),Vector3(8.03,2.69,-38.77),Vector3(13.87,5.07,-49.10),
			Vector3(25.07,7.24,-56.05),Vector3(36.54,9.49,-61.28),Vector3(44.49,10.01,-68.04),Vector3(55.29,7.59,-71.23),
			Vector3(65.35,4.32,-73.80),Vector3(72.55,1.54,-79.63),Vector3(78.24,-0.99,-89.31),Vector3(86.18,-3.43,-103.02),
			Vector3(92.15,-4.40,-117.90),Vector3(96.59,-4.75,-130.65),Vector3(102.53,-5.54,-140.53),Vector3(108.71,-5.72,-150.33),
			Vector3(111.85,-4.90,-161.52),Vector3(111.47,-4.66,-173.10),Vector3(111.18,-5.28,-184.47),
		]},
		"red":{"intent":"hard","ease":0.75,"tokens":[
			Vector3(-0.05,-0.33,-16.10),Vector3(2.06,0.22,-28.03),Vector3(8.03,2.69,-38.77),Vector3(12.98,6.82,-49.52),
			Vector3(15.32,9.91,-61.80),Vector3(22.49,10.59,-71.60),Vector3(32.30,9.15,-79.02),Vector3(41.45,6.71,-86.48),
			Vector3(45.00,5.84,-88.31),Vector3(52.06,4.72,-91.74),Vector3(58.42,1.79,-95.92),Vector3(61.65,0.78,-97.92),
			Vector3(68.69,-0.92,-105.12),Vector3(69.95,-1.21,-107.05),Vector3(78.51,-3.56,-116.49),Vector3(88.66,-5.67,-118.97),
			Vector3(91.01,-5.88,-119.29),Vector3(102.97,-7.18,-125.17),Vector3(105.70,-7.35,-128.54),Vector3(110.47,-6.58,-135.79),
			Vector3(113.73,-5.72,-148.40),Vector3(113.05,-4.90,-161.28),Vector3(111.47,-4.66,-173.10),Vector3(111.18,-5.28,-184.47),
		]},
	}},
	# <<< lines_bend
	# >>> lines_stitch: written by tools/flight_lines_layout.py --write
	{"id":"lines_stitch","key":-1,"pack":"lines","name":"Stitching hall: three lines (out and in through both walls)","intent":"easy","ease":1.3,"parts":[
		["bay",Vector3(1.17,-5.00,-15.94),-0.1822,{"roof":"whole","inner":[]}],
		["bay",Vector3(2.62,-5.00,-23.81),-0.2549,{"roof":"open","inner":[],"rows":[1],"breach":["collapse",""],"pitch":0.037}],
		["bay",Vector3(4.63,-4.70,-31.55),-0.3277,{"roof":"open","inner":[],"rows":[1],"breach":["collapse",""],"pitch":0.104}],
		["bay",Vector3(7.21,-3.87,-39.12),-0.4004,{"roof":"open","inner":[],"breach":["collapse",""],"pitch":0.149}],
		["bay",Vector3(10.33,-2.67,-46.49),-0.4731,{"roof":"open","inner":[],"breach":["collapse",""],"pitch":0.165}],
		["bay",Vector3(13.97,-1.33,-53.61),-0.5458,{"roof":"whole","inner":[-2.6],"breach":["collapse",""],"screen":true,"pitch":0.149}],
		["bay",Vector3(18.12,-0.13,-60.44),-0.6186,{"roof":"open","inner":[],"rows":[1],"breach":["collapse",""],"pitch":0.104}],
		["bay",Vector3(22.76,0.70,-66.96),-0.6913,{"roof":"open","inner":[],"rows":[1],"breach":["collapse","collapse"],"pitch":0.037}],
		["bay",Vector3(27.86,1.00,-73.12),-0.7640,{"roof":"open","inner":[],"rows":[-1],"breach":["","collapse"],"pitch":-0.037}],
		["bay",Vector3(33.39,0.70,-78.90),-0.8368,{"roof":"broken","gaps":[2,3],"inner":[],"rows":[-1],"breach":["","collapse"],"pitch":-0.104}],
		["bay",Vector3(39.33,-0.13,-84.25),-0.9095,{"roof":"open","inner":[],"rows":[-1],"breach":["","collapse"],"pitch":-0.149}],
		["bay",Vector3(45.64,-1.33,-89.17),-0.9822,{"roof":"whole","inner":[],"pitch":-0.165}],
		["bay",Vector3(52.30,-2.67,-93.61),-1.0368,{"roof":"whole","inner":[2.6],"breach":["","collapse"],"screen":"right","pitch":-0.149}],
		["bay",Vector3(59.18,-3.87,-97.68),-0.9822,{"roof":"open","inner":[],"rows":[-1],"breach":["","collapse"],"pitch":-0.104}],
		["bay",Vector3(65.83,-4.70,-102.12),-0.9095,{"roof":"open","inner":[],"rows":[-1],"breach":["collapse","collapse"],"pitch":-0.037}],
		["bay",Vector3(72.15,-5.00,-107.03),-0.8368,{"roof":"open","inner":[],"rows":[],"breach":["collapse","collapse"],"pitch":0.037}],
		["bay",Vector3(78.08,-4.70,-112.39),-0.7640,{"roof":"broken","gaps":[3,4],"inner":[],"rows":[1],"breach":["collapse",""],"pitch":0.104}],
		["bay",Vector3(83.62,-3.87,-118.16),-0.6913,{"roof":"open","inner":[],"rows":[1],"breach":["collapse",""],"pitch":0.149}],
		["bay",Vector3(88.72,-2.67,-124.33),-0.6186,{"roof":"whole","inner":[],"pitch":0.165}],
		["bay",Vector3(93.35,-1.33,-130.84),-0.5458,{"roof":"whole","inner":[-2.6],"breach":["collapse",""],"screen":true,"pitch":0.149}],
		["bay",Vector3(97.51,-0.13,-137.68),-0.4731,{"roof":"open","inner":[],"breach":["collapse",""],"pitch":0.104}],
		["bay",Vector3(101.15,0.70,-144.80),-0.4004,{"roof":"open","inner":[],"rows":[1],"breach":["collapse",""],"pitch":0.037}],
		["bay",Vector3(104.27,1.00,-152.16),-0.3277,{"roof":"open","inner":[],"rows":[1],"breach":["collapse",""]}],
		["bay",Vector3(106.84,1.00,-159.74),-0.2549,{"roof":"broken","gaps":[2,3],"inner":[],"rows":[1],"breach":["collapse",""]}],
		["bay",Vector3(108.86,1.00,-167.48),-0.1822,{"roof":"whole","inner":[]}],
		["bay",Vector3(110.31,1.00,-175.34),-0.1095,{"roof":"whole","inner":[]}],
		["bay",Vector3(111.18,1.00,-183.29),-0.0368,{"roof":"whole","inner":[],"torn":2,"last":true}],
		["pillar",Vector2(-8.84,-60.79),2.0],
		["pillar",Vector2(61.98,-71.90),2.0],
		["pillar",Vector2(71.95,-141.17),2.0],
	],"tokens":[
		Vector3(-2.46,-0.40,-16.48),Vector3(-5.66,-0.69,-30.10),Vector3(-6.68,0.56,-44.41),Vector3(-3.05,3.17,-57.83),
		Vector3(7.02,5.20,-67.75),Vector3(22.34,5.47,-72.50),Vector3(38.53,4.70,-73.60),Vector3(51.85,3.85,-74.68),
		Vector3(60.99,2.66,-79.50),Vector3(68.43,0.79,-91.02),Vector3(72.15,-0.74,-107.03),Vector3(73.25,-0.28,-122.56),
		Vector3(75.57,2.19,-134.42),Vector3(81.80,4.70,-142.54),Vector3(90.72,5.64,-149.67),Vector3(100.43,5.26,-157.69),
		Vector3(107.91,5.39,-167.69),Vector3(110.94,6.01,-179.30),
	],"lines":{
		"yellow":{"intent":"medium","tokens":[
			Vector3(-2.46,-0.40,-16.48),Vector3(-5.66,-0.69,-30.10),Vector3(-6.68,0.56,-44.41),Vector3(-3.05,3.17,-57.83),
			Vector3(8.11,5.20,-67.03),Vector3(25.93,5.47,-69.52),Vector3(44.52,4.70,-67.43),Vector3(58.85,3.85,-65.68),
			Vector3(67.13,2.66,-69.54),Vector3(72.59,0.79,-84.80),Vector3(72.15,-0.74,-107.03),Vector3(67.85,-0.28,-127.74),
			Vector3(66.29,2.19,-141.55),Vector3(72.13,4.70,-148.42),Vector3(83.35,5.64,-153.11),Vector3(96.76,5.26,-158.94),
			Vector3(107.24,5.39,-167.84),Vector3(110.94,6.01,-179.30),
		]},
		"red":{"intent":"hard","ease":0.75,"tokens":[
			Vector3(2.84,-0.44,-15.70),Vector3(5.85,-1.10,-27.10),Vector3(5.09,-0.78,-39.93),Vector3(6.74,0.68,-52.81),
			Vector3(8.73,1.32,-56.53),Vector3(13.28,2.89,-63.63),Vector3(22.94,5.16,-72.00),Vector3(34.47,5.21,-77.78),
			Vector3(45.63,2.71,-82.67),Vector3(55.44,-0.02,-88.50),Vector3(65.43,-0.94,-95.52),Vector3(73.14,-0.50,-105.84),
			Vector3(78.74,-0.11,-117.30),Vector3(84.12,0.35,-127.86),Vector3(88.34,1.32,-134.14),Vector3(90.36,2.01,-137.34),
			Vector3(96.65,4.13,-146.90),Vector3(103.19,5.14,-156.76),Vector3(108.40,5.39,-167.58),Vector3(110.94,6.01,-179.30),
		]},
	}},
	# <<< lines_stitch
	# >>> lines_crest: written by tools/flight_lines_layout.py --write
	{"id":"lines_crest","key":-1,"pack":"lines","name":"Over the crest: three lines (out the roof through gates, back in)","intent":"easy","ease":1.3,"parts":[
		["bay",Vector3(-0.64,-5.00,-15.98),0.1002,{"roof":"whole","inner":[],"pitch":0.025}],
		["bay",Vector3(-1.44,-4.80,-23.94),0.1402,{"roof":"whole","inner":[],"pitch":0.071}],
		["bay",Vector3(-2.56,-4.24,-31.86),0.1802,{"roof":"broken","gaps":[2,3],"inner":[],"pitch":0.110}],
		["bay",Vector3(-4.00,-3.35,-39.73),0.2202,{"roof":"open","inner":[],"pitch":0.139}],
		["bay",Vector3(-5.74,-2.24,-47.54),0.2602,{"roof":"open","inner":[],"beam":false,"pitch":0.153}],
		["bay",Vector3(-7.80,-1.00,-55.27),0.3002,{"roof":"open","inner":[],"beam":false,"pitch":0.153}],
		["bay",Vector3(-10.17,0.24,-62.91),0.2702,{"roof":"open","inner":[],"beam":false,"pitch":0.139}],
		["bay",Vector3(-12.30,1.35,-70.62),0.1702,{"roof":"whole","inner":[0.0],"pitch":0.110}],
		["bay",Vector3(-13.66,2.24,-78.50),0.0702,{"roof":"whole","inner":[],"pitch":0.071}],
		["bay",Vector3(-14.22,2.80,-86.48),-0.0298,{"roof":"whole","inner":[],"pitch":0.025}],
		["bay",Vector3(-13.98,3.00,-94.47),-0.1298,{"roof":"whole","inner":[0.0],"pitch":-0.025}],
		["bay",Vector3(-12.94,2.80,-102.40),-0.2298,{"roof":"whole","inner":[],"pitch":-0.071}],
		["bay",Vector3(-11.12,2.24,-110.18),-0.3298,{"roof":"whole","inner":[],"pitch":-0.110}],
		["bay",Vector3(-8.53,1.35,-117.75),-0.4298,{"roof":"open","inner":[0.0],"pitch":-0.139}],
		["bay",Vector3(-5.20,0.24,-125.02),-0.4598,{"roof":"open","inner":[],"beam":false,"pitch":-0.153}],
		["bay",Vector3(-1.65,-1.00,-132.19),-0.4198,{"roof":"open","inner":[],"beam":false,"pitch":-0.153}],
		["bay",Vector3(1.61,-2.24,-139.49),-0.3798,{"roof":"open","inner":[],"beam":false,"pitch":-0.139}],
		["bay",Vector3(4.58,-3.35,-146.92),-0.3398,{"roof":"broken","gaps":[3,4],"inner":[],"pitch":-0.110}],
		["bay",Vector3(7.24,-4.24,-154.47),-0.2998,{"roof":"whole","inner":[],"pitch":-0.071}],
		["bay",Vector3(9.60,-4.80,-162.11),-0.2598,{"roof":"whole","inner":[],"pitch":-0.025}],
		["bay",Vector3(11.66,-5.00,-169.84),-0.2198,{"roof":"whole","inner":[],"torn":2,"last":true}],
		["gate",Vector3(-13.66,17.59,-78.50),7.00,5.50,0.1202],
		["gate",Vector3(-13.98,18.35,-94.47),7.00,5.50,-0.0798],
		["gate",Vector3(-11.12,17.59,-110.18),7.00,5.50,-0.2798],
		["gate",Vector3(-19.61,16.49,-77.78),1.15,3.30,0.1202],
		["gate",Vector3(-19.96,17.25,-94.95),1.15,3.30,-0.0798],
		["gate",Vector3(-16.89,16.49,-111.84),1.15,3.30,-0.2798],
	],"tokens":[
		Vector3(0.85,-0.37,-16.10),Vector3(-0.15,-0.16,-28.16),Vector3(-4.13,2.53,-39.71),Vector3(-8.18,7.88,-51.03),
		Vector3(-11.04,13.56,-62.62),Vector3(-13.15,17.09,-74.53),Vector3(-14.22,18.10,-86.48),Vector3(-13.56,18.25,-98.45),
		Vector3(-11.12,17.54,-110.18),Vector3(-6.43,15.08,-121.18),Vector3(-0.36,9.87,-131.58),Vector3(3.91,4.11,-142.88),
		Vector3(5.97,0.34,-154.89),Vector3(8.96,-0.40,-166.42),Vector3(14.02,0.05,-177.52),Vector3(16.75,0.17,-189.29),
	],"lines":{
		"yellow":{"intent":"medium","tokens":[
			Vector3(0.85,-0.37,-16.10),Vector3(-0.15,-0.16,-28.16),Vector3(-4.13,1.67,-39.71),Vector3(-8.18,4.30,-51.03),
			Vector3(-8.48,5.78,-63.47),Vector3(-10.09,5.88,-75.05),Vector3(-15.97,6.56,-86.44),Vector3(-16.57,8.35,-98.84),
			Vector3(-9.44,8.13,-109.70),Vector3(-3.95,5.47,-120.05),Vector3(-0.12,2.80,-131.47),Vector3(3.91,1.22,-142.88),
			Vector3(5.97,0.34,-154.89),Vector3(8.96,-0.40,-166.42),Vector3(14.02,0.05,-177.52),Vector3(16.75,0.17,-189.29),
		]},
		"red":{"intent":"hard","ease":0.75,"tokens":[
			Vector3(0.85,-0.37,-16.10),Vector3(-0.15,-0.16,-28.16),Vector3(-4.13,2.53,-39.71),Vector3(-8.18,7.39,-51.03),
			Vector3(-14.03,12.70,-61.63),Vector3(-18.99,16.04,-73.52),Vector3(-19.61,16.49,-77.78),Vector3(-20.22,17.05,-86.35),
			Vector3(-19.96,17.25,-94.95),Vector3(-19.51,17.20,-99.22),Vector3(-16.89,16.49,-111.84),Vector3(-11.24,14.13,-123.39),
			Vector3(-0.83,9.25,-131.80),Vector3(3.91,4.11,-142.88),Vector3(5.97,0.34,-154.89),Vector3(8.96,-0.40,-166.42),
			Vector3(14.02,0.05,-177.52),Vector3(16.75,0.17,-189.29),
		]},
	}},
	# <<< lines_crest
]
