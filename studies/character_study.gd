extends Node3D
## Character study: a greybox room for playing the pilot on foot
## (scripts/pilot_motor.gd) against walls, ledges, gaps, steps, slopes and
## water, reading his numbers, and tuning his feel. No world is made: a
## 64 m square floor walled round, flat colours, a metre grid on every face
## (shaders/character_study_grid.gdshader), a sun and the sky's light.
## Grey is structure, orange caps the lips made to hang from, green is a
## landing pad, blue is water.
##
## The pilot here is the game's own: the same motor, drawn by the same
## figure (scripts/pilot_figure.gd), with the same footsteps, puffs and
## ripples, under a camera that keeps the walker's (scripts/wanderer_eye.gd)
## distance, tilt, spring and swing behind the run. Only the ground is new:
## the room is built of StaticBody3D boxes, ramps and cylinders, and the
## motor's ground, slide, ledge and water are answered from them
## (scripts/pilot_physics_ground.gd).
##
## Stations (STATIONS, one entry each, so a new one is a new entry), number
## keys teleport to them: 1 the run lane, 2 the step ladder, 3 the gap jumps,
## 4 the ledge wall and the pit, 5 the slopes, 6 the pool, 7 the collision
## bits (pillars, doorways, the low bridge), 8 the tower, 9 the wall-jump
## shaft; in the east hall, 0 the slide run (a 32° ramp, a 4 m gap to jump
## out over, a wall-jump slot), - the chutes (50°, which surfs him on its
## own, and 40°), = the side-flip ledges (1.8 and 2.0 m behind a run lane);
## in the momentum field north of the room, [ the 100 m runway, ] the long
## jump chain over five pits, \ the big slope (35°, 20 m down) running out
## into a 6 m gap.
## Space jumps (again on landing, the pump; in a skid, the side flip), Shift,
## C or LT crouches (at a run, the slide, and Space: the long jump, again on
## each landing with crouch held, faster each time; on a slope, the surf; in
## the air, the twirl); into a wall in the air he slides down it, and Space
## kicks off it. R sets him back at the start, F1 shows the
## numbers (speed, state, the jump, the height over the ground, the slope,
## the last jump's kind, peak and reach, the long jump's reach, the surf's
## pace, the last side flip's height and reach, the last twirl's airtime,
## the long jumps chained and their fastest),
## F2 the feel's sliders (the motor's own vars, changed live; Print copies
## the set). Esc lets the mouse go, a click takes it back.
##   ./run-character-study.command
##   godot --path . res://studies/character_study.tscn -- --no-title
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const PilotFigure = preload("res://scripts/pilot_figure.gd")
const PhysicsGround = preload("res://scripts/pilot_physics_ground.gd")
const WandererSteps = preload("res://scripts/wanderer_steps.gd")
const PilotPuffs = preload("res://scripts/pilot_puffs.gd")
const PilotRipples = preload("res://scripts/pilot_ripples.gd")
const Pad = preload("res://scripts/pad.gd")
const GRID := preload("res://shaders/character_study_grid.gdshader")

## The walker's camera (scripts/wanderer_eye.gd), kept the same so what is
## tuned here holds in the game: its reach, the look point's height over
## the feet, its tilt at rest and range, the look point's easing up and
## down, its spring across the ground and the most it lags, the swing
## round behind the run, and the mouse's and the right stick's look.
const CAM_DISTANCE := 7.0
const CAM_HEIGHT := 0.8
const CAM_POLAR := PI*0.5-0.7
const POLAR := Vector2(0.45,1.85)
const EASE_CAM_Y := 0.08
const EASE_CAM_Y_AIR := 0.35
const CAM_FOLLOW := 1.4
const CAM_LAG := 1.6
const LOOK_REST := 0.8
const FOLLOW := 0.9
const CAM_NEAREST := 0.9
const EASE_CAM_OUT := 0.4
const FOV := 60.0
const LOOK := 0.0025
const STICK_WALK_LOOK := Vector2(2.2,1.4)
## The walker's puffs: a landing this hard (m/s) kicks up a ring, fullest
## this much harder; a stick pushed SET_OFF sets off in a push of them.
const PUFF_LAND := 5.0
const PUFF_LAND_FULL := 10.0
const SET_OFF := 0.7

## The room: its half width (m), the walls' height and the floor's depth;
## the east hall beyond it (m east of its east wall), open to it.
const HALF := 32.0
const HALL := 30.0
## The momentum field, north of the room past its wall (x, z), reached only
## by teleport.
const FIELD := Rect2(-32.0,33.0,130.0,41.0)
const WALL := 4.0
const FLOOR_DEPTH := 4.0
## Where he starts, and the way he faces (x, z).
const START := Vector3(0.0,0.0,2.0)
const START_FACE := Vector2(0.0,-1.0)
## Fallen under this, he is set back at the start.
const LOST := -20.0
## Colours by meaning.
const COLOURS := {
	"grey":Color(0.62,0.62,0.6),"floor":Color(0.64,0.64,0.62),"wall":Color(0.52,0.54,0.57),
	"lip":Color(0.96,0.55,0.16),"pad":Color(0.44,0.74,0.4),"dark":Color(0.34,0.35,0.38),
	"lane":Color(0.86,0.85,0.78),"tick":Color(0.2,0.2,0.22),
}
const WATER := Color(0.22,0.5,0.86,0.5)

## The stations. Each: its key (10 is 0, 11 minus, 12 equals, 13 [, 14 ],
## 15 backslash), name, where
## it is set down (spawn) and the way faced, where its sign stands, and its
## parts:
##   ["box", Rect2 x z, bottom, top, colour]   ("lip" caps a grey box orange)
##   ["cyl", Vector2 middle, radius, bottom, top, colour]
##   ["ramp", Vector3 low middle edge, Vector3 high middle edge, width, colour]
##   ["hole", Rect2]   (no floor there)
##   ["water", Rect2, bottom, top]   (a pool, its top flat)
##   ["ticks", Vector2 from, Vector2 to, across, labels every n m]
##   ["label", Vector3, text]
const STATIONS := [
	{"key":1,"name":"Run lane · 30 m","spawn":Vector3(-28.5,0.0,27.0),"face":Vector2(1.0,0.0),"sign":Vector3(-13.0,2.2,25.0),"parts":[
		["ticks",Vector2(-27.0,27.0),Vector2(3.0,27.0),2.0,5],
	]},
	{"key":2,"name":"Step ladder","spawn":Vector3(18.0,0.0,22.5),"face":Vector2(0.0,1.0),"sign":Vector3(18.0,3.6,24.0),"parts":[
		["box",Rect2(7.0,25.5,2.0,3.0),0.0,0.25,"grey"],["label",Vector3(8.0,0.65,25.2),"0.25 m"],
		["box",Rect2(10.0,25.5,2.0,3.0),0.0,0.45,"grey"],["label",Vector3(11.0,0.85,25.2),"0.45 m · STEP_UP"],
		["box",Rect2(13.0,25.5,2.0,3.0),0.0,0.6,"grey"],["label",Vector3(14.0,1.0,25.2),"0.6 m"],
		["box",Rect2(16.0,25.5,2.0,3.0),0.0,0.8,"lip"],["label",Vector3(17.0,1.2,25.2),"0.8 m · jump"],
		["box",Rect2(19.0,25.5,2.0,3.0),0.0,1.1,"lip"],["label",Vector3(20.0,1.5,25.2),"1.1 m"],
		["box",Rect2(22.0,25.5,2.0,3.0),0.0,1.5,"lip"],["label",Vector3(23.0,1.9,25.2),"1.5 m · pump"],
		["box",Rect2(25.0,25.5,2.0,3.0),0.0,2.0,"lip"],["label",Vector3(26.0,2.4,25.2),"2.0 m"],
		["box",Rect2(28.0,25.5,2.0,3.0),0.0,2.4,"lip"],["label",Vector3(29.0,2.8,25.2),"2.4 m"],
	]},
	{"key":3,"name":"Gap jumps · decks 1.2 m and 2.4 m","spawn":Vector3(-29.0,1.2,3.0),"face":Vector2(1.0,0.0),"sign":Vector3(-22.0,3.6,2.0),"parts":[
		["box",Rect2(-30.0,-8.0,5.0,24.0),0.0,1.2,"lip"],
		["ramp",Vector3(-27.5,0.0,19.3),Vector3(-27.5,1.2,16.0),5.0,"grey"],
		["box",Rect2(-24.0,-6.8,2.5,1.6),0.0,1.2,"pad"],["label",Vector3(-22.75,1.6,-6.0),"1.0 m"],
		["box",Rect2(-23.5,-3.8,2.5,1.6),0.0,1.2,"pad"],["label",Vector3(-22.25,1.6,-3.0),"1.5 m"],
		["box",Rect2(-23.0,-0.8,2.5,1.6),0.0,1.2,"pad"],["label",Vector3(-21.75,1.6,0.0),"2.0 m"],
		["box",Rect2(-22.5,2.2,2.5,1.6),0.0,1.2,"pad"],["label",Vector3(-21.25,1.6,3.0),"2.5 m"],
		["box",Rect2(-22.0,5.2,2.5,1.6),0.0,1.2,"pad"],["label",Vector3(-20.75,1.6,6.0),"3.0 m"],
		["box",Rect2(-21.5,8.2,2.5,1.6),0.0,1.2,"pad"],["label",Vector3(-20.25,1.6,9.0),"3.5 m"],
		["box",Rect2(-21.0,11.2,2.5,1.6),0.0,1.2,"pad"],["label",Vector3(-19.75,1.6,12.0),"4.0 m"],
		# The upper deck, and gaps down onto pads 1.2 m lower.
		["ramp",Vector3(-27.5,1.2,-8.0),Vector3(-27.5,2.4,-11.3),5.0,"grey"],
		["box",Rect2(-30.0,-17.0,5.0,5.7),0.0,2.4,"lip"],
		["box",Rect2(-22.5,-16.9,2.5,1.4),0.0,1.2,"pad"],["label",Vector3(-21.25,1.6,-16.2),"2.5 m, 1.2 down"],
		["box",Rect2(-21.5,-14.9,2.5,1.4),0.0,1.2,"pad"],["label",Vector3(-20.25,1.6,-14.2),"3.5 m, 1.2 down"],
		["box",Rect2(-20.5,-12.9,2.5,1.4),0.0,1.2,"pad"],["label",Vector3(-19.25,1.6,-12.2),"4.5 m, 1.2 down"],
	]},
	{"key":4,"name":"Ledge wall · lips 2.0 m, pit 3 m","spawn":Vector3(-6.0,0.0,-17.0),"face":Vector2(-1.0,-1.0),"sign":Vector3(-19.0,4.2,-24.0),"parts":[
		# An L at 2.0 m: straight lips, outside corners, an inside corner;
		# its stair up at the east end.
		["box",Rect2(-24.0,-28.0,10.0,3.0),0.0,2.0,"lip"],
		["box",Rect2(-24.0,-25.0,3.0,5.0),0.0,2.0,"lip"],
		["box",Rect2(-14.0,-28.0,2.0,3.0),0.0,1.6,"grey"],
		["box",Rect2(-12.0,-28.0,2.0,3.0),0.0,1.2,"grey"],
		["box",Rect2(-10.0,-28.0,2.0,3.0),0.0,0.8,"grey"],
		["box",Rect2(-8.0,-28.0,2.0,3.0),0.0,0.4,"grey"],
		["label",Vector3(-19.0,2.5,-24.6),"2.0 m lip"],
		["label",Vector3(-20.6,2.5,-24.6),"inside corner"],
		# A curved lip, a 1.1 m block beside it.
		["cyl",Vector2(-4.0,-25.0),2.5,0.0,2.0,"lip"],
		["box",Rect2(-1.0,-26.0,2.0,2.0),0.0,1.1,"grey"],
		["label",Vector3(-4.0,2.5,-25.0),"curved lip 2.0 m"],
		# The pit, 3 m deep, beams across it flush with the floor, a stair
		# out of it.
		["hole",Rect2(-20.0,-22.0,10.0,4.0)],
		["box",Rect2(-20.0,-22.0,10.0,4.0),-FLOOR_DEPTH,-3.0,"dark"],
		["box",Rect2(-20.0,-22.0,2.0,2.0),-3.0,-2.1,"grey"],
		["box",Rect2(-18.0,-22.0,2.0,2.0),-3.0,-1.2,"grey"],
		["box",Rect2(-15.15,-23.0,0.3,6.0),-0.3,0.0,"lip"],["label",Vector3(-15.0,0.5,-17.6),"beam 0.3 m"],
		["box",Rect2(-12.3,-23.0,0.6,6.0),-0.3,0.0,"lip"],["label",Vector3(-12.0,0.5,-17.6),"beam 0.6 m"],
		["label",Vector3(-17.0,0.6,-22.2),"pit 3 m · walk off slowly to hang"],
		# Catch walls: the jump reaches the first lip, the pump the next two,
		# none the last.
		["box",Rect2(4.0,-31.0,4.0,3.0),0.0,1.7,"lip"],["label",Vector3(6.0,2.1,-27.8),"1.7 m · catch the jump"],
		["box",Rect2(9.0,-31.0,4.0,3.0),0.0,2.1,"lip"],["label",Vector3(11.0,2.5,-27.8),"2.1 m · catch the pump"],
		["box",Rect2(14.0,-31.0,4.0,3.0),0.0,2.5,"lip"],["label",Vector3(16.0,2.9,-27.8),"2.5 m · catch the pump"],
		["box",Rect2(19.0,-31.0,4.0,3.0),0.0,3.0,"lip"],["label",Vector3(21.0,3.4,-27.8),"3.0 m · none"],
	]},
	{"key":5,"name":"Slopes · up to 2 m","spawn":Vector3(17.0,0.0,-11.5),"face":Vector2(1.0,0.0),"sign":Vector3(24.0,4.2,-11.5),"parts":[
		["box",Rect2(28.0,-18.0,4.0,13.0),0.0,2.0,"grey"],
		["ramp",Vector3(20.536,0.0,-16.0),Vector3(28.0,2.0,-16.0),2.5,"grey"],["label",Vector3(22.0,1.3,-16.0),"15°"],
		["ramp",Vector3(24.536,0.0,-13.0),Vector3(28.0,2.0,-13.0),2.5,"grey"],["label",Vector3(25.0,1.6,-13.0),"30°"],
		["ramp",Vector3(26.0,0.0,-10.0),Vector3(28.0,2.0,-10.0),2.5,"grey"],["label",Vector3(26.0,1.6,-10.0),"45°"],
		["ramp",Vector3(26.845,0.0,-7.0),Vector3(28.0,2.0,-7.0),2.5,"grey"],["label",Vector3(26.4,1.6,-7.0),"60°"],
	]},
	{"key":6,"name":"Pool · wade to 1.3 m deep","spawn":Vector3(14.5,0.0,5.0),"face":Vector2(1.0,0.0),"sign":Vector3(24.0,3.0,1.0),"parts":[
		["hole",Rect2(17.0,2.0,15.0,12.0)],
		["box",Rect2(17.0,2.0,15.0,12.0),-FLOOR_DEPTH,-1.6,"dark"],
		# The beach, down at 10°.
		["ramp",Vector3(17.0,0.0,5.0),Vector3(26.074,-1.6,5.0),6.0,"grey"],
		# Banks out, over the water: 0.15, 0.5, 0.9 m (the rim, 0.3).
		["box",Rect2(20.0,12.0,2.0,2.0),-1.6,-0.15,"pad"],["label",Vector3(21.0,0.6,13.0),"bank 0.15 m"],
		["box",Rect2(23.5,12.0,2.0,2.0),-1.6,0.2,"pad"],["label",Vector3(24.5,0.8,13.0),"bank 0.5 m"],
		["box",Rect2(27.0,12.0,2.0,2.0),-1.6,0.6,"pad"],["label",Vector3(28.0,1.2,13.0),"bank 0.9 m"],
		["water",Rect2(17.0,2.0,15.0,12.0),-1.6,-0.3],
		["label",Vector3(20.0,0.5,5.0),"wade"],["label",Vector3(28.0,0.5,8.0),"1.3 m · swim"],
		["label",Vector3(17.5,0.7,11.0),"rim 0.3 m"],
	]},
	{"key":7,"name":"Collision bits","spawn":Vector3(-2.0,0.0,14.0),"face":Vector2(0.0,1.0),"sign":Vector3(0.0,4.0,15.0),"parts":[
		# Pillars to weave through.
		["cyl",Vector2(-14.0,19.4),0.35,0.0,3.0,"grey"],["cyl",Vector2(-12.0,20.6),0.35,0.0,3.0,"grey"],
		["cyl",Vector2(-10.0,19.4),0.35,0.0,3.0,"grey"],["cyl",Vector2(-8.0,20.6),0.35,0.0,3.0,"grey"],
		["cyl",Vector2(-6.0,19.4),0.35,0.0,3.0,"grey"],["cyl",Vector2(-4.0,20.6),0.35,0.0,3.0,"grey"],
		["label",Vector3(-9.0,3.4,20.0),"pillars 2 m apart"],
		# Doorways: 1.6 m and 1.2 m clear, and 1.0 m (too low).
		["box",Rect2(0.0,19.5,1.5,1.0),0.0,2.4,"grey"],["box",Rect2(3.0,19.5,1.5,1.0),0.0,2.4,"grey"],["box",Rect2(1.5,19.5,1.5,1.0),1.6,2.4,"grey"],
		["label",Vector3(2.25,2.8,19.4),"arch 1.6 m"],
		["box",Rect2(5.5,19.5,1.5,1.0),0.0,2.4,"grey"],["box",Rect2(8.0,19.5,1.5,1.0),0.0,2.4,"grey"],["box",Rect2(7.0,19.5,1.0,1.0),1.2,2.4,"grey"],
		["label",Vector3(7.5,2.8,19.4),"door 1.2 m"],
		["box",Rect2(10.5,19.5,1.5,1.0),0.0,2.4,"grey"],["box",Rect2(13.0,19.5,1.5,1.0),0.0,2.4,"grey"],["box",Rect2(12.0,19.5,1.0,1.0),1.0,2.4,"grey"],
		["label",Vector3(12.5,2.8,19.4),"door 1.0 m · too low"],
		# A low bridge: under it 1.4 m clear, its deck 1.7 m up, ramps at
		# its ends.
		["box",Rect2(-6.0,8.0,12.0,2.0),1.4,1.7,"lip"],
		["ramp",Vector3(-10.671,0.0,9.0),Vector3(-6.0,1.7,9.0),2.0,"grey"],
		["ramp",Vector3(10.671,0.0,9.0),Vector3(6.0,1.7,9.0),2.0,"grey"],
		["label",Vector3(0.0,2.3,9.0),"low bridge · 1.4 m under, 1.7 m deck"],
	]},
	{"key":8,"name":"Tower · 6 m","spawn":Vector3(11.0,0.0,-1.5),"face":Vector2(0.0,-1.0),"sign":Vector3(8.0,7.0,-8.0),"parts":[
		["box",Rect2(6.5,-9.5,3.0,3.0),0.0,6.0,"lip"],
		["box",Rect2(10.0,-6.0,2.0,2.0),0.0,0.9,"lip"],["label",Vector3(11.0,1.3,-4.0),"0.9"],
		["box",Rect2(10.0,-8.5,2.0,2.0),0.0,2.4,"lip"],["label",Vector3(11.0,2.8,-7.5),"+1.5"],
		["box",Rect2(10.0,-11.0,2.0,2.0),0.0,3.3,"lip"],["label",Vector3(11.0,3.7,-10.0),"+0.9"],
		["box",Rect2(7.0,-12.5,2.0,2.0),0.0,4.6,"lip"],["label",Vector3(8.0,5.0,-11.5),"+1.3"],
		["label",Vector3(8.0,6.4,-8.0),"+1.4 · the top"],
	]},
	{"key":9,"name":"Wall-jump shaft · 6 m","spawn":Vector3(-9.6,0.0,-6.5),"face":Vector2(0.0,-1.0),"sign":Vector3(-9.6,7.4,-10.0),"parts":[
		# Two walls 2.8 m apart, 6 m tall; the west one's top a lip with a
		# deck behind it, the east one a little taller.
		["box",Rect2(-15.0,-12.0,4.0,4.0),0.0,6.0,"lip"],
		["box",Rect2(-8.2,-12.0,1.0,4.0),0.0,6.5,"grey"],
		["label",Vector3(-9.6,0.4,-6.0),"into a wall in the air: slide · Space: kick off"],
		["label",Vector3(-11.3,6.4,-10.0),"6 m lip"],
	]},
	{"key":10,"name":"Slide run · 32° ramp, 4 m gap, wall-jump slot","spawn":Vector3(40.0,6.0,28.5),"face":Vector2(0.0,-1.0),"sign":Vector3(46.0,8.0,27.0),"parts":[
		# A 6 m platform, the ramp down from it at 32° (9.6 m along the
		# ground), 2.5 m of floor, then a pit 4 m across and 2 m deep (steps
		# out at its east end), then the slot: two walls 2.8 m apart, the
		# west one's top a lip with a deck behind it.
		["box",Rect2(38.0,26.0,4.0,4.0),0.0,6.0,"grey"],
		["ramp",Vector3(40.0,0.0,16.4),Vector3(40.0,6.0,26.0),4.0,"grey"],
		["label",Vector3(42.6,3.6,21.0),"32° · hold crouch to surf"],
		["ticks",Vector2(40.0,16.4),Vector2(40.0,4.4),4.0,2],
		["hole",Rect2(33.0,9.9,13.0,4.0)],
		["box",Rect2(33.0,9.9,13.0,4.0),-FLOOR_DEPTH,-2.0,"dark"],
		["box",Rect2(44.0,9.9,0.5,4.0),-2.0,-1.55,"grey"],["box",Rect2(44.5,9.9,0.5,4.0),-2.0,-1.1,"grey"],
		["box",Rect2(45.0,9.9,0.5,4.0),-2.0,-0.65,"grey"],["box",Rect2(45.5,9.9,0.5,4.0),-2.0,-0.2,"grey"],
		["label",Vector3(40.0,0.6,12.0),"gap 4 m · jump out of the surf"],
		["box",Rect2(34.6,0.0,4.0,5.0),0.0,5.5,"lip"],
		["box",Rect2(41.4,0.0,1.0,5.0),0.0,6.0,"grey"],
		["label",Vector3(40.0,0.5,5.4),"slot 2.8 m · into a side wall, Space: kick"],
		["label",Vector3(36.6,5.9,2.5),"5.5 m lip"],
	]},
	{"key":11,"name":"Chutes · 50° surfs on its own, 40° stands","spawn":Vector3(52.0,5.0,27.5),"face":Vector2(0.0,-1.0),"sign":Vector3(54.0,7.5,27.0),"parts":[
		["box",Rect2(50.0,25.0,4.0,5.0),0.0,5.0,"grey"],
		["ramp",Vector3(52.0,0.0,20.805),Vector3(52.0,5.0,25.0),4.0,"grey"],["label",Vector3(52.0,3.2,22.0),"50°"],
		["box",Rect2(55.0,25.0,4.0,5.0),0.0,5.0,"grey"],
		["ramp",Vector3(57.0,0.0,19.041),Vector3(57.0,5.0,25.0),4.0,"grey"],["label",Vector3(57.0,3.2,21.5),"40°"],
	]},
	{"key":12,"name":"Side-flip ledges · 1.8 and 2.0 m","spawn":Vector3(54.5,0.0,-23.0),"face":Vector2(0.0,1.0),"sign":Vector3(53.0,4.0,-27.0),"parts":[
		# Two ledges behind the lane: run out along it, throw the stick back,
		# and Space in the skid flips him up onto them.
		["box",Rect2(50.0,-30.0,3.0,6.0),0.0,1.8,"lip"],["label",Vector3(51.5,2.2,-23.8),"1.8 m"],
		["box",Rect2(53.0,-30.0,3.0,6.0),0.0,2.0,"lip"],["label",Vector3(54.5,2.4,-23.8),"2.0 m"],
		["ticks",Vector2(53.0,-24.0),Vector2(53.0,-12.0),6.0,2],
		["label",Vector3(53.0,0.6,-19.0),"run out, stick back, Space in the skid: side flip"],
	]},
	# The momentum field (FIELD), north of the room.
	{"key":13,"name":"Runway · 100 m","spawn":Vector3(-30.0,0.0,38.0),"face":Vector2(1.0,0.0),"sign":Vector3(-20.0,3.0,36.0),"parts":[
		["ticks",Vector2(-25.0,38.0),Vector2(75.0,38.0),4.0,10],
		["label",Vector3(-22.0,0.6,40.6),"crouch at a run: slide · Space: long jump · again on each landing, crouch held: faster"],
	]},
	{"key":14,"name":"Long jump chain · five pits","spawn":Vector3(-30.0,0.0,48.0),"face":Vector2(1.0,0.0),"sign":Vector3(-22.0,3.0,46.0),"parts":[
		# Five pits 1 m deep, widening (3.0, 3.1, 3.8, 4.5, 4.8 m), between
		# green strips 2 m long set where a chain timed on each landing comes
		# down, about 1 m into each (5.1, 5.8, 6.5 and 6.8 m a jump after the
		# first's 4.2, from the first edge at x -19). Pressed late, the slide
		# runs off the strip into the next pit.
		["hole",Rect2(-19.0,45.0,27.2,6.0)],
		["box",Rect2(-19.0,45.0,27.2,6.0),-FLOOR_DEPTH,-1.0,"dark"],
		["box",Rect2(-16.0,45.0,2.0,6.0),-1.0,0.0,"pad"],
		["box",Rect2(-10.9,45.0,2.0,6.0),-1.0,0.0,"pad"],
		["box",Rect2(-5.1,45.0,2.0,6.0),-1.0,0.0,"pad"],
		["box",Rect2(1.4,45.0,2.0,6.0),-1.0,0.0,"pad"],
		["label",Vector3(-17.5,0.6,44.6),"3.0 m"],["label",Vector3(-12.45,0.6,44.6),"3.1 m"],
		["label",Vector3(-7.0,0.6,44.6),"3.8 m"],["label",Vector3(-0.85,0.6,44.6),"4.5 m"],["label",Vector3(5.8,0.6,44.6),"4.8 m"],
		["ticks",Vector2(-29.0,52.5),Vector2(21.0,52.5),1.0,5],
		["label",Vector3(-24.0,0.6,50.6),"run, crouch, Space at the edge; crouch held, Space on each landing"],
	]},
	{"key":15,"name":"Big slope · 35°, 20 m down, a 6 m gap","spawn":Vector3(-29.0,20.0,64.0),"face":Vector2(1.0,0.0),"sign":Vector3(-28.0,23.5,64.0),"parts":[
		# A 20 m platform, a 35° slope 8 m wide down from it (28.6 m along
		# the ground) to the floor at x 3.56; beyond its foot, metre ticks
		# along its south half, and a pit 6 m across on its north half from
		# 3 m out.
		["box",Rect2(-31.0,60.0,6.0,8.0),0.0,20.0,"grey"],
		["ramp",Vector3(3.563,0.0,64.0),Vector3(-25.0,20.0,64.0),8.0,"grey"],
		["label",Vector3(-12.0,12.0,59.4),"35° · hold crouch to surf"],
		["ticks",Vector2(3.563,62.0),Vector2(63.563,62.0),4.0,5],
		["hole",Rect2(6.563,64.0,6.0,4.0)],
		["box",Rect2(6.563,64.0,6.0,4.0),-FLOOR_DEPTH,-1.0,"dark"],
		["label",Vector3(9.5,0.6,68.6),"gap 6 m · long-jump out of the slide"],
	]},
]

signal ready_to_walk

## Set once the room stands and the pilot is on his feet.
var walk_ready := false
var motor := PilotMotor.new()
var ground: PhysicsGround
var figure: Node3D
var body: Node3D
var puffs: Node3D
var ripples: Node3D
var steps: Node
var camera: Camera3D
## Driven by a test: the stick and the jump are these, not the input's, and
## `tick` is called by hand.
var scripted := false
var script_want := Vector2.ZERO
var script_jump := false
var script_crouch := false
## The last jump, measured: its number, peak over the takeoff, reach across
## the ground, the drop to where it came down; the one in the air now; the
## last side flip's; the surf's fastest pace now (or last); the last twirl's
## airtime from its start to its end (s).
var last_jump := {}
var _jump := {}
var last_flip := {}
var slide_top := 0.0
var last_twirl := 0.0
var _twirl_from := -1.0
## Long jumps strung together (each faster than the last, so chained), the
## fastest of the string, and the last one's pace.
var long_chain := 0
var long_chain_top := 0.0
var _long_pace := 0.0
var _clock := 0.0
var _yaw := 0.0
var _polar := CAM_POLAR
var _cam_y := 0.0
var _cam_at := Vector2.ZERO
var _cam_pace := Vector2.ZERO
var _cam_distance := CAM_DISTANCE
var _look_rest := 0.0
var _asked := 0.0
var _skid_was := false
var _jump_number := 0
var _hud: Label
var _tune: PanelContainer
var _tune_box: VBoxContainer
var _materials := {}
var _holes: Array[Rect2] = []

func _ready() -> void:
	Pad.ensure()
	_build_light()
	_build_pilot()
	_build_room()
	_build_ui()
	# The bodies are in the space after a physics step.
	await get_tree().physics_frame
	await get_tree().physics_frame
	respawn()
	walk_ready = true
	ready_to_walk.emit()
	if not scripted and get_tree().current_scene == self: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	print("character study: walking %.2f s from launch" % (Time.get_ticks_msec()/1000.0))

# --- The room -----------------------------------------------------------------------

func _build_light() -> void:
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color("6f9fcf")
	sky.sky_horizon_color = Color("dfe6e4")
	sky.ground_bottom_color = Color("9aa3a6")
	sky.ground_horizon_color = Color("dfe6e4")
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = Sky.new()
	environment.sky.sky_material = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.9
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.ssao_enabled = true
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0,-35.0,0.0)
	sun.light_color = Color("fff1dc")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 60.0
	add_child(sun)
	camera = Camera3D.new()
	camera.fov = FOV
	camera.far = 400.0
	add_child(camera)
	camera.current = true

## The floor (less the stations' holes), the walls round it, then each
## station's parts and sign.
func _build_room() -> void:
	for station: Dictionary in STATIONS:
		for part: Array in station.parts:
			if part[0] == "hole": _holes.append(part[1])
	for room: Rect2 in [Rect2(-HALF,-HALF,HALF*2.0+HALL,HALF*2.0),FIELD]:
		for rect in _floor_rects(room,_holes): _box(rect,-FLOOR_DEPTH,0.0,"floor")
	# Round the room and the hall; between them, the room's east wall but for
	# a wide door.
	for r: Rect2 in [Rect2(-HALF-1.0,-HALF-1.0,HALF*2.0+HALL+2.0,1.0),Rect2(-HALF-1.0,HALF,HALF*2.0+HALL+2.0,1.0),
			Rect2(-HALF-1.0,-HALF,1.0,HALF*2.0),Rect2(HALF+HALL,-HALF,1.0,HALF*2.0),
			Rect2(HALF,-HALF,1.0,HALF-6.0),Rect2(HALF,6.0,1.0,HALF-6.0),
			# Round the field.
			Rect2(FIELD.position.x-1.0,FIELD.end.y,FIELD.size.x+2.0,1.0),Rect2(FIELD.position.x-1.0,HALF,1.0,FIELD.end.y-HALF),
			Rect2(FIELD.end.x,HALF,1.0,FIELD.end.y-HALF),Rect2(HALF+HALL+1.0,HALF,FIELD.end.x-HALF-HALL-1.0,1.0)]:
		_box(r,-FLOOR_DEPTH,WALL,"wall")
	for station: Dictionary in STATIONS:
		for part: Array in station.parts: _part(part)
		_label(station.sign,"%s  %s" % [key_name(station.key),station.name],64)
	_label(START+Vector3(1.6,0.4,0.0),"START · R",36)

## The rect `room` less every hole in it, as rects: cut into slabs across x
## at every hole's edge, each slab's z left open between the holes in it.
static func _floor_rects(room: Rect2, all_holes: Array[Rect2]) -> Array[Rect2]:
	var holes: Array[Rect2] = []
	for h in all_holes: if h.intersects(room): holes.append(h)
	var xs := [room.position.x,room.end.x]
	for h in holes: xs.append_array([h.position.x,h.end.x])
	xs.sort()
	var out: Array[Rect2] = []
	for i in range(xs.size()-1):
		var x0: float = xs[i]
		var x1: float = xs[i+1]
		if x1-x0 < 0.001: continue
		var cuts: Array = []
		for h in holes:
			if h.position.x < x1-0.001 and h.end.x > x0+0.001: cuts.append(Vector2(h.position.y,h.end.y))
		cuts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var z := room.position.y
		for c: Vector2 in cuts:
			if c.x > z+0.001: out.append(Rect2(x0,z,x1-x0,c.x-z))
			z = maxf(z,c.y)
		if room.end.y > z+0.001: out.append(Rect2(x0,z,x1-x0,room.end.y-z))
	return out

func _part(part: Array) -> void:
	match part[0]:
		"box": _box(part[1],part[2],part[3],part[4])
		"cyl": _cyl(part[1],part[2],part[3],part[4],part[5])
		"ramp": _ramp(part[1],part[2],part[3],part[4])
		"water":
			var r: Rect2 = part[1]
			ground.pools.append({"rect":r,"top":part[3]})
			var mesh := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(r.size.x,part[3]-part[2],r.size.y)
			mesh.mesh = box
			mesh.position = Vector3(r.get_center().x,(part[2]+part[3])*0.5,r.get_center().y)
			var water := StandardMaterial3D.new()
			water.albedo_color = WATER
			water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			water.roughness = 0.1
			water.cull_mode = BaseMaterial3D.CULL_DISABLED
			mesh.material_override = water
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mesh)
		"ticks": _ticks(part[1],part[2],part[3],part[4])
		"label": _label(part[1],part[2],28)

func _material(colour: String) -> Material:
	if not _materials.has(colour):
		var m := ShaderMaterial.new()
		m.shader = GRID
		m.set_shader_parameter("tint",COLOURS[colour])
		_materials[colour] = m
	return _materials[colour]

## A solid: its mesh and its collider, at `place`.
func _solid(mesh: Mesh, shape: Shape3D, place: Transform3D, colour: String) -> StaticBody3D:
	var solid := StaticBody3D.new()
	solid.transform = place
	var collider := CollisionShape3D.new()
	collider.shape = shape
	solid.add_child(collider)
	var drawn := MeshInstance3D.new()
	drawn.mesh = mesh
	drawn.material_override = _material("grey" if colour == "lip" else colour)
	solid.add_child(drawn)
	add_child(solid)
	return solid

## A box over `rect` (x, z) from `bottom` to `top`; a lip's top is capped
## orange.
func _box(rect: Rect2, bottom: float, top: float, colour: String) -> void:
	var size := Vector3(rect.size.x,top-bottom,rect.size.y)
	var mesh := BoxMesh.new()
	mesh.size = size
	var shape := BoxShape3D.new()
	shape.size = size
	_solid(mesh,shape,Transform3D(Basis.IDENTITY,Vector3(rect.get_center().x,(top+bottom)*0.5,rect.get_center().y)),colour)
	if colour == "lip": _cap(Vector3(rect.get_center().x,top,rect.get_center().y),Vector3(rect.size.x,0.0,rect.size.y),0.0)

func _cyl(middle: Vector2, radius: float, bottom: float, top: float, colour: String) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = top-bottom
	mesh.radial_segments = 32 if radius > 1.0 else 12
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = top-bottom
	_solid(mesh,shape,Transform3D(Basis.IDENTITY,Vector3(middle.x,(top+bottom)*0.5,middle.y)),colour)
	if colour == "lip": _cap(Vector3(middle.x,top,middle.y),Vector3.ZERO,radius)

## The orange band round a lip's top (drawn only): a box's or a disc's.
func _cap(at: Vector3, size: Vector3, radius: float) -> void:
	var mesh := MeshInstance3D.new()
	if radius > 0.0:
		var disc := CylinderMesh.new()
		disc.top_radius = radius+0.01
		disc.bottom_radius = radius+0.01
		disc.height = 0.1
		disc.radial_segments = 32
		mesh.mesh = disc
	else:
		var slab := BoxMesh.new()
		slab.size = Vector3(size.x+0.02,0.1,size.z+0.02)
		mesh.mesh = slab
	mesh.position = at-Vector3(0.0,0.045,0.0)
	mesh.material_override = _material("lip")
	add_child(mesh)

## A ramp `width` wide whose top runs from the edge `low` to the edge
## `high`, 0.4 m thick under it.
func _ramp(low: Vector3, high: Vector3, width: float, colour: String) -> void:
	var along := (high-low).normalized()
	var side := Vector3.UP.cross(along).normalized()
	var up := along.cross(side).normalized()
	var length := low.distance_to(high)
	var size := Vector3(width,0.4,length+0.02)
	var mesh := BoxMesh.new()
	mesh.size = size
	var shape := BoxShape3D.new()
	shape.size = size
	_solid(mesh,shape,Transform3D(Basis(side,up,along),(low+high)*0.5-up*0.2),colour)

## A lane's metre marks from `from` to `to` (x, z), `across` wide, numbered
## every `every` m (drawn only).
func _ticks(from: Vector2, to: Vector2, across: float, every: int) -> void:
	var length := from.distance_to(to)
	var way := (to-from)/length
	var lane := MeshInstance3D.new()
	var strip := BoxMesh.new()
	strip.size = Vector3(length,0.01,across)
	lane.mesh = strip
	var mid := (from+to)*0.5
	lane.transform = Transform3D(Basis(Vector3.UP,-way.angle()),Vector3(mid.x,0.004,mid.y))
	lane.material_override = _material("lane")
	add_child(lane)
	for m in range(int(length)+1):
		var at := from+way*float(m)
		var tick := MeshInstance3D.new()
		var bar := BoxMesh.new()
		bar.size = Vector3(0.05 if m%every else 0.1,0.012,across)
		tick.mesh = bar
		tick.transform = Transform3D(Basis(Vector3.UP,-way.angle()),Vector3(at.x,0.008,at.y))
		tick.material_override = _material("tick")
		add_child(tick)
		if m%every == 0: _label(Vector3(at.x,0.35,at.y-across*0.5-0.3),"%d m" % m,40)

func _label(at: Vector3, text: String, size: int) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.outline_size = 10
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color(0.12,0.12,0.14)
	label.outline_modulate = Color(1.0,1.0,1.0,0.85)
	label.position = at
	add_child(label)

# --- The pilot ----------------------------------------------------------------------

func _build_pilot() -> void:
	ground = PhysicsGround.new(get_world_3d().direct_space_state,motor)
	motor.water = ground.water_callable()
	motor.wall = ground.wall_callable()
	figure = Node3D.new()
	figure.name = "Pilot"
	add_child(figure)
	body = PilotFigure.new()
	figure.add_child(body)
	puffs = PilotPuffs.new()
	figure.add_child(puffs)
	ripples = PilotRipples.new()
	figure.add_child(ripples)
	steps = WandererSteps.new()
	add_child(steps)

## Set down at `at`, facing `face` (x, z), the camera behind.
func place(at: Vector3, face: Vector2) -> void:
	motor.reset(at,PilotMotor.facing_of(face))
	_jump = {}
	_yaw = motor.facing
	_polar = CAM_POLAR
	_cam_y = at.y+CAM_HEIGHT
	_cam_at = Vector2(at.x,at.z)
	_cam_pace = Vector2.ZERO
	_cam_distance = CAM_DISTANCE
	_look_rest = 0.0
	body.settle()
	_sync_figure()
	_frame(0.0)

func respawn() -> void:
	place(START,START_FACE)

## A station key's name: 1 to 9, 0 (10), - (11), = (12), [ (13), ] (14),
## \ (15).
static func key_name(key: int) -> String:
	return {10:"0",11:"-",12:"=",13:"[",14:"]",15:"\\"}.get(key,str(key))

## Teleported to station `key` (1 to 15).
func go_to(key: int) -> void:
	for station: Dictionary in STATIONS:
		if station.key == key: place(station.spawn,station.face)

func _process(delta: float) -> void:
	if walk_ready and not scripted: tick(delta)

## One frame of the pilot: the stick read, the motor stepped over the room,
## the body drawn, its sounds and puffs, the camera.
func tick(delta: float) -> void:
	var want := script_want
	var jump := script_jump
	motor.crouch = script_crouch
	if not scripted:
		want = _want(delta)
		jump = Input.is_action_pressed(&"walk_jump") and not _tuning()
		motor.crouch = Input.is_action_pressed(&"walk_crouch") and not _tuning()
	_asked = want.length()
	ground.head(delta)
	var was := motor.feet
	var events := motor.step(delta,want,motor.run,jump,ground.ground_callable(),ground.slide_callable(),ground.ledge_callable())
	if motor.feet.y < LOST:
		respawn()
		return
	_measure(events,was)
	_measure_tricks(events,delta)
	_sync_figure()
	if events.has("grabbed") or events.has("climbed"): steps.step(_surface(),0.4)
	_motor_events(events)
	var drawn: Dictionary = body.drive(motor,delta)
	_body_events(drawn,delta)
	_water_events(events,drawn,delta)
	_frame(delta)
	_show_hud()

## The stick in the motor's frame: the camera's way taken out; the right
## stick swings the camera as the mouse does.
func _want(delta: float) -> Vector2:
	if _tuning(): return Vector2.ZERO
	var stick := Input.get_vector(&"move_left",&"move_right",&"move_forward",&"move_back")
	var look := Pad.curve(Pad.stick(&"look_left",&"look_right",&"look_up",&"look_down"),1.6)
	if look != Vector2.ZERO:
		_yaw -= look.x*STICK_WALK_LOOK.x*delta
		_polar = clampf(_polar-look.y*STICK_WALK_LOOK.y*delta,POLAR.x,POLAR.y)
		_look_rest = 0.0
	var forward := PilotMotor.forward(_yaw)
	var right := Vector2(-forward.y,forward.x)
	return right*stick.x+forward*-stick.y

func _sync_figure() -> void:
	figure.position = motor.origin() if motor.on_ledge() else motor.feet
	figure.rotation = Vector3(0.0,motor.facing,0.0)

## The jump measured from takeoff to where it came down (a landing, a
## catch, a splash, a wall taken hold of, another jump): its kind ("jump",
## "pump", "long", "kick"), number, peak over the takeoff and reach.
func _measure(events: Dictionary, was: Vector3) -> void:
	if events.has("jumped"):
		if not _jump.is_empty(): _jump_done("jumped",was)
		_jump_number = int(events.jumped)
		var kind := "long" if events.has("long") else ("kick" if events.has("wall_jump") else ("flip" if events.has("side_flip") else ("slide jump" if events.has("slide_jump") else ("pump" if _jump_number > 1 else "jump"))))
		_jump = {"n":_jump_number,"kind":kind,"from":was,"peak":was.y}
	if _jump.is_empty(): return
	_jump.peak = maxf(float(_jump.peak),motor.feet.y)
	var done := ""
	for key: String in ["landed","grabbed","swam"]:
		if events.has(key): done = key
	if events.get("wall",false): done = "wall"
	if done == "" and motor.grounded: done = "landed"
	if done != "": _jump_done(done,motor.feet)

func _jump_done(done: String, at: Vector3) -> void:
	var from: Vector3 = _jump.from
	last_jump = {"n":_jump.n,"kind":_jump.kind,"peak":maxf(float(_jump.peak),at.y)-from.y,"reach":Vector2(at.x-from.x,at.z-from.z).length(),
		"drop":at.y-from.y,"end":done}
	if _jump.kind == "flip": last_flip = last_jump
	_jump = {}

## The surf's pace and the twirl's airtime, measured.
func _measure_tricks(events: Dictionary, delta: float) -> void:
	_clock += delta
	if events.get("slide",false): slide_top = 0.0
	if motor.move == "slide": slide_top = maxf(slide_top,motor.speed())
	if events.has("twirl"): _twirl_from = _clock
	if events.has("long"):
		var pace := motor.speed()
		long_chain = long_chain+1 if long_chain > 0 and pace > _long_pace+0.05 else 1
		if long_chain == 1: long_chain_top = 0.0
		long_chain_top = maxf(long_chain_top,pace)
		_long_pace = pace
	if _twirl_from >= 0.0 and (motor.grounded or motor.on_ledge() or motor.swimming or motor.move == "wall"):
		last_twirl = _clock-_twirl_from
		_twirl_from = -1.0

## What the feet are on, for the steps and puffs.
func _surface() -> String:
	return "water" if motor.swimming or motor.wade >= 0.03 else "stone"

func _puff_at(at: Vector3) -> Vector3:
	if is_finite(motor.surface) and motor.wade > 0.0: at.y = maxf(at.y,motor.surface)
	return at

func _world_way(way: Vector3) -> Vector3:
	var flat := Vector3(way.x,0.0,way.z)
	if flat.length_squared() < 0.01:
		var f := PilotMotor.forward(motor.facing)
		flat = Vector3(f.x,0.0,f.y)
	return flat.normalized()

## As the walker's: jumps and landings sound and puff (the pump and the side
## flip in a ring, the long jump and the slide jump back off the heels, a
## wall kick off the wall), the body squashes; taking hold of a wall slaps
## it, sliding down it scrapes and sprays; a twirl whirls a swirl of wisps
## round him; a surf scrapes as it starts and sprays the while.
func _motor_events(events: Dictionary) -> void:
	if events.has("jumped"):
		steps.step(_surface(),0.3+0.15*float(events.jumped))
		var at := _puff_at(figure.global_position)
		var way := _world_way(motor.velocity)
		if events.has("wall_jump"): puffs.burst(at+Vector3.UP*0.5-way*0.3,_surface(),0.35,way)
		elif events.has("long") or events.has("slide_jump"): puffs.burst(at,_surface(),0.3,-way)
		elif int(events.jumped) > 1 or events.has("side_flip"): puffs.burst(at,_surface(),0.45)
	if events.has("twirl"):
		steps.step(_surface(),0.25)
		puffs.swirl(figure.global_position+Vector3.UP*0.55,1.0,0.8)
	if events.get("slide",false): steps.slide(_surface(),clampf(motor.speed()/PilotMotor.RUN,0.4,1.0))
	if motor.move == "slide" and motor.speed() > 1.0:
		var travel := _world_way(motor.velocity)
		puffs.spray(_puff_at(figure.global_position+travel*0.2),travel,_surface(),clampf(motor.speed()/PilotMotor.SLIDE_TOP,0.3,1.0),get_process_delta_time())
	if events.get("wall",false):
		steps.step(_surface(),0.35)
		steps.slide(_surface(),0.3)
	if motor.move == "wall":
		var off := Vector3(motor.wall_out.x,0.0,motor.wall_out.y)
		puffs.spray(figure.global_position-off*0.25+Vector3.UP*0.15,Vector3.UP,_surface(),0.35,get_process_delta_time())
	if events.has("landed"):
		var hard := float(events.landed)
		steps.step(_surface(),clampf(hard/8.0,0.3,1.0))
		body.land(hard)
		if hard > PUFF_LAND: puffs.burst(_puff_at(figure.global_position),_surface(),(hard-PUFF_LAND)/PUFF_LAND_FULL)

func _body_events(out: Dictionary, delta: float) -> void:
	var speed: float = motor.speed()
	var effort := clampf((speed-PilotMotor.WALK)/(PilotMotor.RUN-PilotMotor.WALK),0.0,1.0)
	if out.has("footfall"):
		var side := int(out.footfall)
		steps.step(_surface(),effort,side)
		puffs.footfall(_puff_at(body.boot(side)),-_world_way(motor.velocity),_surface(),effort)
	if out.has("set_off") and _asked >= SET_OFF: puffs.burst(_puff_at(figure.global_position),_surface(),0.0,-_world_way(Vector3.ZERO))
	if out.has("turned"): puffs.burst(_puff_at(figure.global_position),_surface(),0.1,-_world_way(Vector3.ZERO))
	if motor.skidding:
		var travel := _world_way(motor.velocity)
		if not _skid_was: steps.slide(_surface(),speed/PilotMotor.RUN)
		puffs.spray(_puff_at(figure.global_position+travel*0.15),travel,_surface(),clampf(speed/PilotMotor.RUN,0.3,1.0),delta)
	_skid_was = motor.skidding

func _water_events(events: Dictionary, drawn: Dictionary, delta: float) -> void:
	for at in body.soak(motor,delta): puffs.drip(at,at.y-figure.global_position.y)
	if not is_finite(motor.surface):
		ripples.dry()
		return
	var top := Vector3(figure.global_position.x,motor.surface,figure.global_position.z)
	if events.has("swam"):
		var hard := clampf(float(events.swam)/8.0,0.3,1.0)
		ripples.splash(top,hard)
		puffs.burst(top,"water",hard)
		steps.step("water",hard)
	if events.has("hopped"):
		ripples.splash(top,0.4)
		puffs.burst(top,"water",0.3)
	var ahead := _world_way(Vector3.ZERO)
	if motor.swimming: ripples.trail(top+ahead*0.15,true,0.16)
	elif motor.grounded and motor.wade > 0.04 and motor.speed() > 0.3: ripples.trail(top,false,0.18)
	else: ripples.dry()
	if drawn.has("footfall") and motor.wade > 0.04:
		var boot: Vector3 = body.boot(int(drawn.footfall))
		ripples.ring(Vector3(boot.x,top.y,boot.z),0.07,0.25)
	if drawn.has("stroke"):
		var mitt: Vector3 = body.mitt(int(drawn.stroke))
		var paddling := motor.speed() > 0.3
		ripples.ring(Vector3(mitt.x,top.y,mitt.z),0.06,0.3 if paddling else 0.15)
		puffs.footfall(Vector3(mitt.x,top.y,mitt.z),-ahead,"water",0.5 if paddling else 0.2)
		steps.step("water",0.2 if paddling else 0.1,int(drawn.stroke))

# --- The camera ---------------------------------------------------------------------

## The walker's camera (scripts/wanderer_eye.gd `_frame_walker`): round a
## point over the feet that follows them on a spring and, lagging in a
## jump, up and down; swung round behind the run when left alone; drawn in
## where something stands between it and him.
func _frame(delta: float) -> void:
	var goal := motor.feet.y+CAM_HEIGHT
	if delta > 0.0: _cam_y = lerpf(_cam_y,goal,_ease(EASE_CAM_Y if motor.grounded else EASE_CAM_Y_AIR,delta))
	_cam_y = clampf(_cam_y,goal-1.2,goal+1.2)
	_look_rest += delta
	var speed: float = motor.speed()
	if speed > 0.3 and _look_rest > LOOK_REST:
		var at_camera := maxf(0.0,-PilotMotor.forward(_yaw).dot(PilotMotor.forward(motor.facing)))
		_yaw = lerp_angle(_yaw,motor.facing,_ease(FOLLOW,delta)*clampf(speed/PilotMotor.RUN,0.0,1.0)*(1.0-at_camera))
	var feet := Vector2(motor.feet.x,motor.feet.z)
	var w := TAU*CAM_FOLLOW
	var left := minf(delta,0.25)
	while left > 0.0:
		var dt := minf(left,1.0/60.0)
		_cam_pace += (w*w*(feet-_cam_at)-2.0*w*_cam_pace)*dt
		_cam_at += _cam_pace*dt
		left -= dt
	if _cam_at.distance_to(feet) > CAM_LAG: _cam_at = feet+(_cam_at-feet).normalized()*CAM_LAG
	var pivot := Vector3(_cam_at.x,_cam_y,_cam_at.y)
	var out := Vector3(sin(_polar)*sin(_yaw),cos(_polar),sin(_polar)*cos(_yaw))
	var reach := CAM_DISTANCE
	var ray := PhysicsRayQueryParameters3D.create(pivot,pivot+out*(CAM_DISTANCE+0.3))
	var hit := ground.space.intersect_ray(ray)
	if not hit.is_empty(): reach = clampf(pivot.distance_to(hit.position)-0.3,CAM_NEAREST,CAM_DISTANCE)
	_cam_distance = reach if reach < _cam_distance or delta <= 0.0 else lerpf(_cam_distance,reach,_ease(EASE_CAM_OUT,delta))
	camera.look_at_from_position(pivot+out*_cam_distance,pivot)

func _ease(rate: float, delta: float) -> float:
	return 1.0-exp(-delta/rate)

# --- Numbers and tuning -------------------------------------------------------------

## The feel's numbers on the F2 panel: the motor's var, its slider's range.
const TUNABLE := [["walk",0.5,6.0],["run",1.0,10.0],["accel",2.0,60.0],["brake",2.0,60.0],["air_accel",0.0,30.0],
	["turn",1.0,40.0],["turn_run",1.0,30.0],["air_turn",0.0,20.0],["gravity",5.0,80.0],["fall",0.5,4.0],["cut",1.0,6.0],
	["terminal",5.0,40.0],["jumps:0",0.2,3.0],["jumps:1",0.2,3.0],["skid_speed",0.5,8.0],
	["skid_brake",2.0,40.0],["coyote",0.0,0.4],["buffer",0.0,0.4],["chain_window",0.0,0.6],
	["carry_hold",0.0,20.0],["carry_decay",0.0,30.0],["long_pace",1.0,6.0],
	["long_height",0.1,2.0],["long_speed",2.0,16.0],["long_gravity",5.0,40.0],["long_chain",0.0,0.6],["long_add",0.0,4.0],
	["long_top",4.0,24.0],["wall_slide",0.3,6.0],
	["wall_jump",0.3,3.0],["wall_kick",1.0,10.0],["wall_lock",0.0,0.8],["twirl_rise",0.0,8.0],["twirl_time",0.1,1.0],
	["twirl_gravity",0.1,1.0],["twirl_push",0.0,6.0],["twirl_top",0.0,16.0],["twirl_steer",0.0,30.0],
	["slide_auto",25.0,70.0],["slide_pull",4.0,40.0],["slide_top",4.0,30.0],["slide_runout",0.0,30.0],["slide_air",0.0,0.2],
	["slide_jump",0.2,2.5],["side_flip",0.5,3.5],["side_speed",0.0,8.0],["climb_time",0.15,1.2]]

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(16.0,12.0)
	_hud.add_theme_font_size_override("font_size",16)
	_hud.add_theme_color_override("font_color",Color("fbf6ea"))
	_hud.add_theme_color_override("font_shadow_color",Color(0,0,0,0.7))
	_hud.add_theme_constant_override("shadow_offset_y",1)
	layer.add_child(_hud)
	var hint := Label.new()
	hint.text = "WASD run · Space jump (on landing: pump; in a skid: side flip) · Shift/C crouch: at a run slide, + Space long jump (crouch held, Space on landing: chain), on a slope surf, in the air twirl · into a wall: slide, Space: kick · 1-9 0 - = [ ] \\ stations · R start · F1 numbers · F2 feel · Esc mouse"
	hint.add_theme_font_size_override("font_size",14)
	hint.add_theme_color_override("font_color",Color("fbf6ea"))
	hint.add_theme_color_override("font_shadow_color",Color(0,0,0,0.7))
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_top = -36.0
	hint.offset_left = -640.0
	hint.offset_right = 640.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(hint)
	_tune = PanelContainer.new()
	_tune.visible = false
	_tune.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_tune.offset_left = -372.0
	_tune.offset_right = -12.0
	_tune.offset_top = 12.0
	_tune.offset_bottom = -48.0
	layer.add_child(_tune)
	# More numbers than fit: a scroll.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tune.add_child(scroll)
	_tune_box = VBoxContainer.new()
	_tune_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_tune_box)
	for spec: Array in TUNABLE:
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.custom_minimum_size.x = 110.0
		name_label.text = spec[0]
		var value := Label.new()
		value.custom_minimum_size.x = 56.0
		var slider := HSlider.new()
		slider.custom_minimum_size.x = 160.0
		slider.min_value = spec[1]
		slider.max_value = spec[2]
		slider.step = 0.01
		slider.value = _feel(spec[0])
		value.text = "%.2f" % slider.value
		slider.value_changed.connect(func(v: float) -> void:
			_set_feel(spec[0],v)
			value.text = "%.2f" % v)
		slider.focus_mode = Control.FOCUS_NONE
		slider.set_meta("feel",spec[0])
		row.add_child(name_label)
		row.add_child(slider)
		row.add_child(value)
		_tune_box.add_child(row)
	var buttons := HBoxContainer.new()
	for action: String in ["Print","Defaults"]:
		var button := Button.new()
		button.text = action
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void:
			if action == "Print": print_feel()
			else: default_feel())
		buttons.add_child(button)
	_tune_box.add_child(buttons)

func _tuning() -> bool:
	return _tune != null and _tune.visible

## A feel number by its TUNABLE name ("jumps:1" is the second jump).
func _feel(key: String) -> float:
	if key.begins_with("jumps:"): return float(motor.jumps[int(key.get_slice(":",1))])
	return float(motor.get(key))

func _set_feel(key: String, value: float) -> void:
	if key.begins_with("jumps:"): motor.jumps[int(key.get_slice(":",1))] = value
	else: motor.set(key,value)

## The feel now, as the motor's constants to paste back, printed and copied.
func print_feel() -> String:
	var lines := PackedStringArray()
	for spec: Array in TUNABLE:
		var key: String = spec[0]
		if key.begins_with("jumps:"): continue
		lines.append("const %s := %s" % [key.to_upper(),_num(float(motor.get(key)))])
	lines.append("const JUMPS := [%s]" % ",".join(motor.jumps.map(func(j: float) -> String: return _num(j))))
	var text := "\n".join(lines)
	print("character study feel:\n"+text)
	DisplayServer.clipboard_set(text)
	return text

static func _num(v: float) -> String:
	var s := "%.3f" % v
	while s.ends_with("0") and not s.ends_with(".0"): s = s.left(-1)
	return s

func default_feel() -> void:
	var fresh := PilotMotor.new()
	for spec: Array in TUNABLE:
		var key: String = spec[0]
		if key.begins_with("jumps:"): continue
		motor.set(key,fresh.get(key))
	motor.jumps = fresh.jumps.duplicate()
	for row in _tune_box.get_children():
		for child in row.get_children():
			if child is HSlider: (child as HSlider).set_value_no_signal(_feel(child.get_meta("feel")))
			if child is Label and row.get_child_count() == 3 and child == row.get_child(2): (child as Label).text = "%.2f" % _feel(row.get_child(1).get_meta("feel"))

## The long jump's reach, level, from the motor's feel now.
func long_reach() -> float:
	return motor.long_speed*2.0*sqrt(2.0*motor.long_height/motor.long_gravity)

## What the motor is doing, in a word.
func state() -> String:
	if motor.on_ledge(): return motor.hold
	if motor.swimming: return "swim"
	if motor.skidding: return "skid"
	if motor.move in ["wall","crouch","long","kick","slide","twirl","flip"]: return motor.move
	if motor.grounded: return "wade" if motor.wade > PilotMotor.WADE_FROM else "ground"
	return "air"

func _show_hud() -> void:
	if not _hud.visible: return
	var under := ground.height_from(Vector2(motor.feet.x,motor.feet.z),motor.feet.y)
	var lines := PackedStringArray([
		"speed     %.2f m/s" % motor.speed(),
		"state     %s" % state(),
		"jump      %s%s" % [_jump.get("kind",last_jump.get("kind","-")),"  (in the air)" if not _jump.is_empty() else ""],
		"height    %s" % ("%.2f m" % (motor.feet.y-under) if is_finite(under) else "-"),
		"feet      %.1f, %.2f, %.1f" % [motor.feet.x,motor.feet.y,motor.feet.z],
	])
	if not last_jump.is_empty():
		lines.append("last %s: peak %.2f m · reach %.2f m · drop %+.2f m (%s)" % [last_jump.kind,last_jump.peak,last_jump.reach,last_jump.drop,last_jump.end])
	lines.append("long jump %.2f m level (%.2f m up)" % [long_reach(),motor.long_height])
	lines.append("slope     %.0f°" % motor.steepness() if motor.grounded else "slope     -")
	lines.append("surf      %.2f m/s%s · top %.2f m/s" % [motor.speed() if motor.move == "slide" else 0.0,"  (surfing)" if motor.move == "slide" else "",slide_top])
	if not last_flip.is_empty(): lines.append("side flip peak %.2f m · reach %.2f m" % [last_flip.peak,last_flip.reach])
	if last_twirl > 0.0: lines.append("twirl     %.2f s in the air from it" % last_twirl)
	if long_chain > 0: lines.append("long chain %d · fastest %.2f m/s (LONG_TOP %.1f)" % [long_chain,long_chain_top,motor.long_top])
	if motor.wade > 0.0 or motor.swimming: lines.append("water     %.2f m over the feet" % motor.wade)
	_hud.text = "\n".join(lines)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x*LOOK
		_polar = clampf(_polar-event.relative.y*LOOK,POLAR.x,POLAR.y)
		_look_rest = 0.0
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not _tuning():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		var key := (event as InputEventKey).keycode
		match key:
			KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			KEY_R: respawn()
			KEY_F1: _hud.visible = not _hud.visible
			KEY_F2:
				_tune.visible = not _tune.visible
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _tune.visible else Input.MOUSE_MODE_CAPTURED
			KEY_0: go_to(10)
			KEY_MINUS: go_to(11)
			KEY_EQUAL: go_to(12)
			KEY_BRACKETLEFT: go_to(13)
			KEY_BRACKETRIGHT: go_to(14)
			KEY_BACKSLASH: go_to(15)
			_:
				if key >= KEY_1 and key <= KEY_9: go_to(key-KEY_0)
