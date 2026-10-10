extends RefCounted
## The smallest island pack, the template for others: two floating islands
## and a hop between them, in the character study's station format
## (studies/character_study.gd STATIONS, plus "obox"). Built in the open sky
## with `-- --pack=starter`; falling under LOST sets him back at the station
## spawn nearest where he last stood.
##   ./run-character-study.command --pack=starter

const NAME := "Starter islands"
const START := Vector3(0.0,20.0,0.0)
const START_FACE := Vector2(0.0,-1.0)
const LOST := -10.0

const STATIONS := [
	{"key":1,"name":"Two islands · 3.5 m gap","spawn":Vector3(0.0,20.0,0.0),"face":Vector2(0.0,-1.0),"sign":Vector3(-4.0,23.0,-4.0),"parts":[
		# The home island: a slab 12 by 12, 3 m deep.
		["box",Rect2(-6.0,-6.0,12.0,12.0),17.0,20.0,"floor"],
		# Across a 3.5 m gap (a running long jump goes 4.2 m), a smaller one.
		["box",Rect2(-3.0,-15.5,6.0,6.0),17.0,20.0,"floor"],
		["label",Vector3(0.0,20.6,-7.75),"gap 3.5 m · long jump"],
	]},
	{"key":2,"name":"Turned stepping stones","spawn":Vector3(0.0,20.0,-13.0),"face":Vector2(0.0,-1.0),"sign":Vector3(4.0,23.0,-20.0),"parts":[
		["obox",Vector3(-1.0,20.0,-23.0),Vector3(2.5,1.0,2.5),20.0,"lip"],
		["obox",Vector3(1.5,20.6,-27.0),Vector3(2.5,1.0,2.5),-15.0,"lip"],
		["obox",Vector3(-0.5,21.2,-31.0),Vector3(3.0,1.0,3.0),35.0,"lip"],
	]},
]
