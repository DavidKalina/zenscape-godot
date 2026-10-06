extends Node
## The land shudders under the shaping tools (the Electron app's tremor.js, fed
## as its conductor fed it). Built by studies/fidelity_life.gd next to
## ClaySound when the clay is on; it kicks the scene's tremor
## (scripts/reference_tremor.gd), which owns the trauma, its decay and the
## camera's borrowed shake.
##
## A mountain that rises in silence and stillness reads as a slider; one that
## lurches reads as rock. So the land's movement is spent in lurches: every
## LURCH metres the land has moved, the tremor takes one kick, sized by how
## fast it is moving (the rate, eased as the conductor's was) and, for a hold,
## by how tall it already stands. Rate becomes rhythm: a fast pull is a swarm
## of quakes that stack into a shudder, a slow one a distant shift now and
## then, and a hand held still is quiet ground, the last kicks tailing off.
##
## What moves the land, read each frame as ClaySound reads it:
## - **a hold**, its lift (the Mountain's pull, up only; the Crater's floor,
##   down only; the Chisel's mesa, pit or slice; the Modeller's pinch, a
##   knoll or a dip): metres of lift, up or down. Sinking is SINK of a rise.
## - **a drawn landform** growing after the release (the Mountain's range,
##   the Crater's lake: their Draw modes): its lift, up or down, and its
##   head's metres along its line together, kicking as a pull does, its
##   weight growing with the lift.
## - **the Ravine's cut** (the tool id `wire`) drawing through after the
##   release: metres of its head along its line, or a loop's basin settling.
##   Lighter and grittier than a pull: more, smaller kicks (CUT_LURCH).
##
## Each tool's weight is FEEL. The Crater sits between the Chisel and the
## Mountain (0.75): a six-metre hole with a thrown-out rim moves more ground
## than a chisel's block and less than a 14 m peak. Going down is its whole
## gesture, so it is in DIGS and its sink kicks at full weight, not SINK of a
## rise as a pit or a dip does. A tool not in FEEL
## (the Brush, the Feather, the Paddle, the Hills, the Bowl, the Sculpt, the
## can and the plants) never shakes. Every kick stays small, and the clay never pushes the
## trauma past CAP of its feel, so a long fast pull shakes hard but never
## unwatchably.
##
## `amount` scales every kick, 0 turns the shudder off (`--no-shake`).

## Each tool's weight, 0..1: how hard its land moving kicks.
const FEEL := {"mountain":1.0,"crater":0.75,"island":0.6,"chisel":0.6,"wire":0.55,"hand":0.35}
## Metres of lift per lurch (14 m, the Mountain's full pull, is ~28 lurches,
## as the conductor's full rise was), and metres of the Ravine's head.
const LURCH := 0.5
const CUT_LURCH := 0.35
## The biggest single kick, under the resident's 0.2 stumble threshold.
const KICK := 0.18
## The trauma the clay holds at most, times the tool's feel: 0.7 is a
## shake of 0.49 (trauma²), about half a degree of roll.
const CAP := 0.7
## Lift speeds (m/s) from which a hold's lurches start to swell, and at which
## they are full (ClaySound's LIFT_RATE); the Ravine's head at its CUT_SPEED.
const LIFT_RATE := Vector2(0.3,6.0)
const CUT_RATE := Vector2(0.5,8.0)
## How fast the rate follows the land (1/s), as the conductor's riseRate.
const RATE_EASE := 2.5
## A hold's kicks grow from GROW.x to 1 as its lift reaches TALL metres.
const GROW := 0.6
const TALL := 8.0
## A sinking hold kicks at SINK of a rising one, but for the tools in DIGS,
## whose landform is the sink.
const SINK := 0.7
const DIGS := ["crater"]

var clay: Node
var tremor: RefCounted
## Every kick's scale; 0 is no shudder at all.
var amount := 0.0 if "--no-shake" in OS.get_cmdline_user_args() else 1.0
## Kicks given, for probes.
var kicks := 0
## The eased rate, 0..1, for probes.
var rate := 0.0
var _debt := 0.0
## The last frame's lift (a hold) or head (the Ravine's cut), metres; NAN when
## nothing was moving.
var _last := NAN

func setup(land_clay: Node, scene_tremor: RefCounted) -> void:
	name = "ClayTremor"
	clay = land_clay
	tremor = scene_tremor

func _process(delta: float) -> void:
	if clay == null or tremor == null or delta <= 0.0: return
	var tool: Object = clay.tool
	var id: String = clay.tool_id
	var feel := float(FEEL.get(id,0.0))
	var at := NAN
	var cut := false
	if tool != null and feel > 0.0:
		if id == "wire" and tool.busy():
			at = float(tool.cut_share())*float(tool.cut_length())
			cut = true
		elif tool.has_method("growing") and tool.growing():
			at = absf(float(tool.lift))+float(tool.head)
		elif clay.state == clay.State.HOLD:
			at = float(tool.lift)
	if is_nan(at):
		_last = NAN
		_debt = 0.0
		rate = 0.0
		return
	var moved := 0.0 if is_nan(_last) else at-_last
	_last = at
	var span := CUT_RATE if cut else LIFT_RATE
	rate += (smoothstep(span.x,span.y,absf(moved)/delta)-rate)*(1.0-exp(-delta*RATE_EASE))
	var scene: Variant = clay.get("scene")
	if scene != null and bool(scene.get("_paused")): return
	_debt += absf(moved)
	var step := CUT_LURCH if cut else LURCH
	if _debt < step: return
	# One lurch a frame at most, so a long frame is one bigger step, not a
	# burst; the part of a step left over carries to the next.
	_debt = fmod(_debt,step)
	var size := 1.0 if cut else lerpf(GROW,1.0,smoothstep(0.0,TALL,absf(at)))
	if not cut and moved < 0.0 and not id in DIGS: size *= SINK
	var kick := KICK*feel*(0.35+0.65*rate)*size*amount
	var room := CAP*feel-float(tremor.trauma)
	if kick <= 0.0 or room <= 0.0: return
	tremor.add(minf(kick,room))
	kicks += 1
