extends "res://scripts/land_spring.gd"
## The edge spring (docs/scenic/modeless.md, "The agreed scheme" and "Edge
## spring"). The edge of the diorama is a drawn bow: grab the rim (the lip or
## anywhere down the block's walls), pull down and let go, and a random range
## springs up out of the land. Lift the rim and set it down slowly, and a
## random basin sinks instead.
##
## - **The pull.** While the rim is pulled down the whole block dips as a unit
##   and tips a little toward the hand (scripts/diorama_flip.gd `dip_*`, on
##   its snapshot, so no terrain is touched while held). The pull is measured
##   as the land spring's is (PULL_SCREEN of the viewport's height is the
##   cap, DEAD shows nothing, under MIN_PULL let go keeps nothing), down only,
##   and trembles harder near the cap.
## - **The release.** The block snaps back up, and the moment it is at rest
##   the range springs up through the land on the land spring's spring
##   (`x'' = -w²(x-1) - 2·z·w·x'`, kicked), overshoots, rings down, and lands
##   as any mountain does (`_land_mountain`: weathering on a worker), one undo
##   step for the whole thing.
## - **The range.** Random: its middle, direction, length and number of peaks,
##   from a seeded generator. Placement is the best of CANDIDATES random spots
##   by a score that leans away from the rim and from ground that is already
##   tall, with luck mixed in; the grabbed edge does not choose it. The pull
##   sets height and jaggedness together: each peak is a blend of a rolling
##   dome and the mountain machinery's alpine horn (scripts/mountain_forms.gd),
##   domes at a gentle pull, horns at a hard one. The peaks are combined as the
##   root of the sum of their squares, so neighbours join in saddles. Springs
##   stack onto what is there, under a soft ceiling: ground is eased from KNEE
##   toward CEILING, and never above it.
## - **The basin.** A slow set-down of a lifted rim (diorama_flip `set_down`)
##   sinks a basin: the land spring's bowl, sized by how far the rim was
##   lifted, at a random spot away from the rim and from tall ground.
##
## It extends the land spring for its spring, its landing and its basin; the
## land spring itself is the land press's (studies/fidelity.gd), and this is
## the edge's (studies/cozy_worlds.gd), with its own undo hook chained on the
## editor's.

## The range: peak height before the ceiling (gentle to hard pull), the crest
## line's length in metres, and how many peaks (inclusive).
const RANGE_HEIGHT := Vector2(1.2,9.5)
const RANGE_LENGTH := Vector2(6.0,15.0)
const RANGE_PEAKS := Vector2i(2,5)
## A peak may slip along the line by this share of the spacing, stand off it
## by up to PEAK_SIDE metres, and is 65 to 100 % of the range's height, lower
## toward the ends.
const PEAK_JITTER := 0.35
const PEAK_SIDE := 1.2
const END_DROP := 0.35
## A rolling dome's radius in metres, and the pull over which the peaks turn
## from domes (below JAGGED.x) to horns (above JAGGED.y).
const HILL_RADIUS := Vector2(3.2,4.8)
const JAGGED := Vector2(0.15,0.85)
## The height ceiling (m) and the knee above which ground is eased toward it.
## The plate is 28 m wide and the snow line about 6.5 m.
const CEILING := 11.0
const KNEE := 7.0
## Placement: the crest's ends stay within RANGE_ROOM metres of the middle
## lines (the forms fade over the plate's last metres from 11.4), and a
## basin's rim within ROOM. Of CANDIDATES random spots the best scores
## -RIM_LEAN·(distance out / ROOM)² - TALL_LEAN·(mean ground there, m)
## + LUCK·random.
const RANGE_ROOM := 9.0
const ROOM := 11.0
const CANDIDATES := 24
const RIM_LEAN := 3.0
const TALL_LEAN := 0.6
const LUCK := 1.5
## The basin: a lift under BASIN_MIN (of the flip's progress) sinks nothing;
## BASIN_FULL of it is a full-size basin.
const BASIN_MIN := 0.08
const BASIN_FULL := 0.45

var flip: Node
## A seed for the next range or basin (< 0 is a random one), for a probe.
var next_seed := -1
## What the last range and basin were, for the probe.
var last_range := {}
var last_basin := {}
## Let go, waiting for the block to come back up before the range springs.
var waiting := false
var _chained: Node = null

func setup(owner_scene: Node3D) -> void:
	scene = owner_scene
	editor = owner_scene._chunk_editor
	flip = owner_scene.get("flip")
	# The editor lands its spring before an undo; this one is chained on.
	_chained = editor.spring
	editor.spring = self
	name = "EdgeSpring"
	if flip != null:
		flip.dipped.connect(_risen)
		flip.set_down.connect(basin)

# --- The seam the rim drives ----------------------------------------------------

## The rim is pulled down at `screen_pos`: the block dips. False when the
## editor or the flip cannot take it.
func pull_begin(screen_pos: Vector2) -> bool:
	if editor == null or flip == null or editor.forming or not editor.active: return false
	land_now()
	editor._land_mountain()
	if not flip.dip_begin(screen_pos): return false
	_start(screen_pos)
	return true

func pull(screen_pos: Vector2, relative := Vector2.ZERO) -> void:
	if state != State.PULLING or waiting: return
	super.pull(screen_pos,relative)
	pulled = maxf(pulled,0.0)

## Let go: the block snaps back up; the range springs once it is at rest. A
## small pull keeps nothing.
func release(screen_pos: Vector2 = Vector2.INF) -> void:
	if state != State.PULLING or waiting: return
	if screen_pos != Vector2.INF: pull(screen_pos)
	_size = pulled
	if _size < MIN_PULL:
		flip.dip_release(0.0)
		_finish_relax()
		return
	_keep_kind = "mountain"
	_build_shape("mountain",_size)
	waiting = true
	flip.dip_release(_size)

## The block is back at rest: spring the range.
func _risen(_amount: float) -> void:
	if not waiting: return
	waiting = false
	spring_target = 1.0
	spring_x = 0.0
	spring_v = KICK
	spring_seconds = 0.0
	spring_peak = 0.0
	state = State.SPRINGING
	editor._mountain_feel(0)

func land_now() -> void:
	if flip != null and (waiting or state == State.PULLING): flip.dip_finish()
	super.land_now()
	if _chained != null and _chained != self: _chained.land_now()

## A lifted rim set down slowly from `progress` (0..1 of the flip's lift):
## a basin sinks at a random spot, sized by it.
func basin(progress: float) -> void:
	if progress < BASIN_MIN or editor == null or editor.forming or not editor.active: return
	land_now()
	editor._land_mountain()
	var amount := clampf(progress/BASIN_FULL,0.0,1.0)
	var rng := _rng()
	var radius := lerpf(BASIN_RADIUS.x,BASIN_RADIUS.y,amount)
	_start(Vector2.ZERO)
	center = _place(rng,Vector2.RIGHT,0.0,ROOM-radius)
	_gather(editor.data)
	_size = amount
	_keep_kind = "basin"
	_build_shape("basin",amount)
	last_basin = {"centre":center,"radius":radius,"amount":amount}
	spring_target = 1.0
	spring_x = 0.0
	spring_v = KICK
	spring_seconds = 0.0
	spring_peak = 0.0
	state = State.SPRINGING

# --- Frame -----------------------------------------------------------------------

## While held the block dips with the pull (it trembles near the cap); the
## land is not touched.
func _tension(delta: float) -> void:
	if waiting: return
	elapsed += delta
	var goal := pulled if pulled >= DEAD else 0.0
	shown = lerpf(shown,goal,1.0-exp(-TENSION_FOLLOW*delta))
	kind = "mountain" if shown > 0.004 else ""
	flip.dip_to(shown*(1.0+TREMBLE*shown*shown*sin(elapsed*TREMBLE_RATE)))

# --- Shapes ----------------------------------------------------------------------

func _start(screen_pos: Vector2) -> void:
	var data := editor.data
	_press = screen_pos
	# Opening the step first joins any weathering still landing.
	data.begin_stroke()
	_base = data.heights.duplicate()
	_first_id = data.next_id
	_near = PackedInt32Array()
	_near_d = PackedFloat32Array()
	_bulge = PackedFloat32Array()
	_shape_idx = PackedInt32Array()
	state = State.PULLING
	waiting = false
	kind = ""
	pulled = 0.0
	shown = 0.0
	elapsed = 0.0
	refreshes = 0
	spring_peak = 0.0
	_keep_kind = ""
	_region = Rect2()

func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	if next_seed >= 0: rng.seed = next_seed
	else: rng.randomize()
	next_seed = -1
	return rng

func _build_shape(what: String, amount: float) -> void:
	if what == "basin": super._build_shape(what,amount)
	else: _build_range(amount)

## The range for a pull `amount`, built into the editor's mountain (so it
## lands, weathers and undoes as one): its lift is the peaks' combined lift.
## Nothing is written to the land.
func _build_range(amount: float) -> void:
	var started := Time.get_ticks_usec()
	var data := editor.data
	var rng := _rng()
	var jag := smoothstep(JAGGED.x,JAGGED.y,amount)
	var count := rng.randi_range(RANGE_PEAKS.x,RANGE_PEAKS.y)
	var length := rng.randf_range(RANGE_LENGTH.x,RANGE_LENGTH.y)
	var direction := Vector2.from_angle(rng.randf()*TAU)
	var top := lerpf(RANGE_HEIGHT.x,RANGE_HEIGHT.y,amount)
	var shown_heights := data.heights
	data.heights = _base.duplicate()
	center = _place(rng,direction,length*0.5,RANGE_ROOM)
	var mountain: RefCounted = editor.mountain
	mountain.prepare(data,editor.land_seed)
	mountain.begin(data,"alpine",center,0.01,editor.land_strength,direction)
	var keep: PackedFloat32Array = mountain._keep
	var lump: PackedFloat32Array = mountain._lump
	var squares := PackedFloat32Array()
	squares.resize(data.points.size())
	var peaks: Array = []
	for k in range(count):
		var t := (float(k)+0.5)/count-0.5+rng.randf_range(-PEAK_JITTER,PEAK_JITTER)/count
		var at := center+direction*t*length+direction.orthogonal()*rng.randf_range(-PEAK_SIDE,PEAK_SIDE)
		var height := top*rng.randf_range(0.65,1.0)*(1.0-END_DROP*absf(t)*2.0)
		var dome := rng.randf_range(HILL_RADIUS.x,HILL_RADIUS.y)
		# The horn: the alpine form at this peak, its arêtes its own.
		var aretes := PackedFloat32Array()
		var turn := rng.randf()*TAU
		var n := rng.randi_range(3,5)
		for a in range(n): aretes.append(turn+TAU*(float(a)+rng.randf_range(-0.22,0.22))/n)
		mountain._aretes = aretes
		mountain.center = at
		mountain.spread = clampf(height/1.45*rng.randf_range(0.9,1.2),3.0,9.5)
		mountain.height = height
		mountain._reshape(data)
		var reach := maxf(mountain.spread,dome)
		var horn: PackedFloat32Array = mountain._lift
		for i: int in mountain._touched:
			var p: Vector2 = data.points[i]
			var d := p.distance_to(at)
			if d >= reach: continue
			var r := d/dome
			var soft := height*pow(maxf(0.0,1.0-r*r),2.0)*(0.85+0.3*lump[i])*keep[i]
			var lift := lerpf(soft,horn[i],jag)
			squares[i] += lift*lift
		peaks.append({"at":at,"height":height})
	# Rolling hills keep their green: the rock paints by share of this height.
	mountain.center = center
	mountain.spread = length*0.5+3.0
	mountain.height = maxf(top,lerpf(10.0,top,jag))
	# The combined lift, eased under the ceiling, is the mountain's lift.
	var touched := PackedInt32Array()
	var lifts: PackedFloat32Array = mountain._lift
	var bounds := Rect2()
	var bounded := false
	var tallest := 0.0
	for i in range(squares.size()):
		if squares[i] <= 0.0:
			lifts[i] = 0.0
			continue
		var lift := minf(sqrt(squares[i]),_ceiling(_base[i]+sqrt(squares[i]))-_base[i])
		lift = maxf(lift,0.0)
		lifts[i] = lift
		touched.append(i)
		tallest = maxf(tallest,_base[i]+lift)
		if lift > 0.02:
			var p: Vector2 = data.points[i]
			bounds = bounds.expand(p) if bounded else Rect2(p,Vector2.ZERO)
			bounded = true
	mountain._lift = lifts
	mountain._touched = touched
	mountain.bounds = bounds
	mountain._has_bounds = bounded
	data.heights = shown_heights
	_region = bounds
	last_range = {"centre":center,"direction":direction,"length":length,"peaks":peaks,"top":top,"jag":jag,"tallest":tallest,
		"build_ms":(Time.get_ticks_usec()-started)/1000.0}

## Ground at `height` eased under the ceiling: as is up to KNEE, then toward
## CEILING, never reaching it.
static func _ceiling(height: float) -> float:
	if height <= KNEE: return height
	var span := CEILING-KNEE
	return KNEE+span*(1.0-exp(-(height-KNEE)/span))

## A random spot for a shape `half` metres either side of its middle along
## `direction` (0 for a round one), its ends within `room` of the middle
## lines: the best of CANDIDATES by the placement score.
func _place(rng: RandomNumberGenerator, direction: Vector2, half: float, room: float) -> Vector2:
	var data := editor.data
	var limit := Vector2(maxf(0.0,room-absf(direction.x)*half),maxf(0.0,room-absf(direction.y)*half))
	var best := Vector2.ZERO
	var best_score := -INF
	for c in range(CANDIDATES):
		var at := Vector2(rng.randf_range(-limit.x,limit.x),rng.randf_range(-limit.y,limit.y))
		var ground := 0.0
		var samples := 0
		for s in [-1.0,-0.5,0.0,0.5,1.0]:
			var h: Variant = data.sample(at+direction*half*s,_base)
			if h == null: continue
			ground += float(h)
			samples += 1
		ground = ground/samples if samples > 0 else 0.0
		var out := maxf(absf(at.x),absf(at.y))/ROOM
		var score := -RIM_LEAN*out*out-TALL_LEAN*maxf(ground,0.0)+LUCK*rng.randf()
		if score > best_score:
			best_score = score
			best = at
	return best

# --- The hand --------------------------------------------------------------------

## The flip's snapshot grips the rim while the block dips; the spring leaves
## the hand alone.
func _hand(_gesture: String) -> void:
	pass

func _hand_pace(_pace: float) -> void:
	pass
