extends "res://scripts/clay_tools/clay_tool.gd"
## The Hammer, "Break" (docs/design/tools/PLAN.md): a rock hammer. It knocks
## chunks off rock and cracks it into scree. It has one verb, the blow, and
## the Modeller's grammar decides where the blows land.
##
## - **Tap:** a blow at the spot. On rock it cracks: the rock within
##   CRACK_RADIUS standing more than CRACK_DEPTH under the local top is left,
##   the rock above that is broken off (a peak lowered, a cliff's lip knocked
##   off), and that volume spills downhill as scree, as height changes only,
##   and settles to the angle of repose (REPOSE). The scree is painted a pale
##   broken rock, the fresh scar a paler grey. On ground that is not rock the
##   blow is a dull knock: a shallow dent (KNOCK_DEPTH), no scree.
## - **Drag:** the blow repeated along the path, one every STRIKE_GAP, each a
##   crack or a knock by the ground it lands on: working a ridge line down.
##   The whole drag is one undo step.
## - **Hold, then let go:** a deliberate blow, the tap's own, landing at
##   release. Nothing follows the pointer while it is held: a hammer has no
##   pinch, and a slow press should not vanish into nothing.
## - **Shift** at the moment the verb is decided: a smaller blow, FINE of the
##   radius and the depth. The size pips scale the radius.
##
## Each blow is one undo step (a drag's blows are one together), and one undo
## restores the heights, the tint and the cover exactly. Trees on ground the
## blow moved that cannot hold it slide to its foot (`clay.shake_trees`).
##
## What is rock. The land knows rock three ways, and a blow cracks where any
## of them holds at the spot (`_rocky`): the tint layer carries a rock's paint
## (a range's granite, a pinch's flank, earlier scree: weight at least
## ROCK_PAINT, and not the clay's earth colours); the ground is steeper than
## ROCK_SLOPE_SHARE of the slope the terrain paints rock above (the biome's
## `rock_slope`, as `shake_trees` and emergence read it); or it stands in
## the rock band the terrain paints under the snowline (snowline - 1.8 m).
##
## The crack. Within the radius, each point above the level (the highest
## point there less the depth) loses its height over the level, fully inside
## CRACK_CORE of the radius and easing to the rim, and by a broken share
## (BROKEN to 1, seeded per point by the spot) so the scar is rough, not
## turned. The cut is the plate's edge fade times that.
##
## The scree. Each point's cut is walked away as one stone: out of the scar
## (to the lowest neighbour farther from the blow, stopping if that is
## uphill: rock cracked in a pit stays in it), then down the fall line (the
## neighbour with the steepest drop) while the drop is steeper than REPOSE,
## at most WALK_STEPS neighbours, never into the edge fade. It is laid there
## on the ground as loose rock. Then the loose rock settles: while a point
## carrying loose rock stands more than REPOSE (per metre, along the land's
## edges) over a neighbour, half the excess (at most what it carries) runs to
## its lower neighbours in proportion. Bedrock never moves, so a cliff stays
## a cliff and the scree lies at the repose angle over it. The land's points
## are taken as equal areas (they are scattered 0.45 to 0.75 m apart), so the
## heights' sum, the volume in point terms, is kept exactly; the true volume
## roughly (the probe measures both).
const CRACK_RADIUS := 1.8
const CRACK_DEPTH := 1.4
const CRACK_CORE := 0.35
const BROKEN := 0.72
## The knock on ground that is not rock: a dent KNOCK_DEPTH metres deep over
## KNOCK_RADIUS, `(1-t²)²`: seen close, honest from afar.
const KNOCK_RADIUS := 1.0
const KNOCK_DEPTH := 0.08
## Shift: the smaller blow's share of the radius and the depth. The size
## pips scale both too: a bigger blow reaches further into the rock.
const FINE := 0.5
## Scree's angle of repose as a gradient (rise per metre): tan 35°, loose
## angular rock's. The terrain paints rock only above 0.8 to 1.4, so scree
## reads by its paint, not its slope.
const REPOSE := 0.7
## The walk and the settle: a stone's most steps, the settle's most point
## visits, and the excess in metres the settle leaves (about 1 cm per metre).
const WALK_STEPS := 60
const SETTLE_VISITS := 200000
const SETTLE_TOL := 0.004
## Rock at the spot: painted rock of at least ROCK_PAINT weight, not within
## EARTHY (linear RGB distance) of a soft stratum's colour (topsoil, clay or
## sand, scripts/strata.gd `earthy`) or the clay's TURNED; or
## ground at least ROCK_SLOPE_SHARE of the biome's rock slope.
const ROCK_PAINT := 0.4
const EARTHY := 0.05
const ROCK_SLOPE_SHARE := 0.85
## The paint. Scree: one of SCREE's pale, broken rock tones per 0.5 m tint
## cell (seeded), at up to SCREE_WEIGHT, from SCREE_FROM to SCREE_FULL metres
## of loose rock. The scar: FRESH, paler than the range's granite (#a8a49b),
## at up to FRESH_WEIGHT from FRESH_FROM to FRESH_FULL metres cut. A cell at
## least BARE scree loses its grass for good, as the clay's dug earth does.
const SCREE := ["bdb6a8","aea799","c9c2b3","b3aa98"]
const SCREE_WEIGHT := 0.9
const SCREE_FROM := 0.02
const SCREE_FULL := 0.15
const FRESH := Color("c4beb2")
const FRESH_WEIGHT := 0.65
const FRESH_FROM := 0.05
const FRESH_FULL := 0.6
const BARE := 0.5
## A drag strikes every STRIKE_GAP metres (× the pips), about a crack's
## radius, so the blows along a ridge meet without stacking.
const STRIKE_GAP := 1.6
## How hard a crack and a knock disturb the life round them
## (scripts/disturbance.gd), 0..1, and how far (metres).
const CRACK_STRENGTH := 0.8
const KNOCK_STRENGTH := 0.35
const STIR_RADIUS := 3.0
## The swing on a tap, in the prop's own frame (degrees about its x, positive
## lifts the head back): WIND_SECONDS back to WIND_ANGLE (the anticipation),
## STRIKE_SECONDS down through rest to STRIKE_ANGLE (the blow lands at its
## end, so a tap's crack comes IMPACT seconds after the release), then
## RECOIL_SECONDS back to rest with one small bounce. The hand shows the
## Press pose for PRESS_SECONDS from the impact. A drag's blows play from the
## strike on (no wind-up, no delay).
const WIND_SECONDS := 0.09
const WIND_ANGLE := 38.0
const STRIKE_SECONDS := 0.05
const STRIKE_ANGLE := -14.0
const RECOIL_SECONDS := 0.24
const IMPACT := WIND_SECONDS+STRIKE_SECONDS
const PRESS_SECONDS := 0.2
## The stand-in prop, metres at the hand's own size: a wood handle hanging
## from the grip, the head across its foot in the icon's tint (#7a6a5a,
## scripts/hud_icons.gd "hammer"), a flat striking face (+z, toward the drag)
## and a pick behind (-z), a darker collar where they meet.
const TINT := Color("7a6a5a")
const FACE := Color("9a8b7a")
const COLLAR := Color("584b3f")
const HANDLE := Color("9a7550")
const HANDLE_LENGTH := 0.95
const HEAD := Vector3(0.16,0.34,0.16)
const PICK_LENGTH := 0.26
## The cursor sketch's lean toward the drag.
const TILT := -30.0

var _fine := false
var _last_strike := Vector2.INF
## A tap's blow waiting for its impact: {"at", "fine"}, or empty.
var _pending := {}
var _swing_t := -1.0
var _swing_from := 0.0
var _press_t := -1.0
var _swing: Node3D
## The last blow, for probes: "crack" or "knock", its points cut and
## covered in scree, the metres cut off the top, and the heights' sum moved.
var last := {}

func id() -> String: return "hammer"
func prop_tilt() -> float: return TILT
func stroke_radius() -> float: return _radius(CRACK_RADIUS)
## The ground mark's ring is the crack's reach, the blow's on rock (a knock
## on anything else reaches KNOCK_RADIUS). The scree specks the marks fan
## downhill of it are their own.
func mark_size() -> Vector2: return Vector2.ONE*CRACK_RADIUS
func worked_as(verb: String) -> String: return verb

func _radius(r: float) -> float: return r*clay.size_scale*(FINE if _fine else 1.0)

func reset() -> void:
	lift = 0.0
	_fine = false

# --- Drag: blows along the path ---------------------------------------------------------

func drag_begin(fine: bool) -> String:
	_fine = fine
	_last_strike = Vector2.INF
	return "fine_strikes" if fine else "strikes"

## A blow every STRIKE_GAP along the path, on the working copy; the clay
## writes it to the land after the frame's dabs. It paints its own scree, so
## it reports no reach for the clay's dirt.
func dab(heights: PackedFloat32Array, q: Vector2) -> float:
	if _last_strike != Vector2.INF and q.distance_to(_last_strike) < STRIKE_GAP*clay.size_scale*(FINE if _fine else 1.0): return 0.0
	_last_strike = q
	_strike(heights,q,_fine)
	_swing_at(IMPACT)
	return 0.0

func drag_end() -> bool:
	clay.shake_trees(clay.center,0.0,clay.touched())
	return false

# --- Hold: a deliberate blow at release --------------------------------------------------

func hold_begin(fine: bool) -> String:
	_fine = fine
	_swing_at(0.0)
	_swing_t = -1.0
	_hold_wound()
	var rocky := _rocky(clay.center)
	return ("fine_" if fine else "")+("crack" if rocky else "knock")

## Nothing follows the pointer: the head stays wound back while held.
func hold_step(_heights: PackedFloat32Array, _rise: float) -> bool:
	return false

## Let go (or cut short): the blow lands, inside the hold's undo step.
func hold_end() -> void:
	var data: NativeTerrainData = clay.editor.data
	var heights := data.heights
	var at: Vector2 = clay.center
	_strike(heights,at,_fine)
	data.heights = heights
	clay.show_land()
	clay.shake_trees(at,_spill_reach())
	_swing_at(IMPACT)

# --- Tap: the blow ------------------------------------------------------------------------

## A tap winds the hammer back and brings it down: the blow lands IMPACT
## seconds later (`frame`), or at once if anything ends it first (`finish`).
func tap(fine: bool) -> void:
	_pending = {"at":clay.center,"fine":fine}
	_swing_at(0.0)

func _impact() -> void:
	var at: Vector2 = _pending.at
	_fine = _pending.fine
	_pending = {}
	var rocky := _rocky(at)
	clay.verb = ("fine_" if _fine else "")+("crack" if rocky else "knock")
	clay.open_stroke()
	var data: NativeTerrainData = clay.editor.data
	var heights := data.heights
	_strike(heights,at,_fine)
	data.heights = heights
	clay.show_land()
	clay.shake_trees(at,_spill_reach())
	clay.stir(at,STIR_RADIUS,CRACK_STRENGTH if rocky else KNOCK_STRENGTH)
	var ground: Vector3 = clay.ground_at(at)
	clay.close_stroke()
	clay.hand_gesture("press",ground,true)
	_press_t = 0.0

func frame(delta: float) -> void:
	if _swing_t >= 0.0:
		_swing_t += delta
		if not _pending.is_empty() and _swing_t >= IMPACT: _impact()
		_pose()
	if _press_t >= 0.0:
		_press_t += delta
		if _press_t >= PRESS_SECONDS: _end_press()

func finish() -> void:
	if not _pending.is_empty(): _impact()
	_swing_t = -1.0
	_pose()
	_end_press()

func busy() -> bool: return not _pending.is_empty() or _swing_t >= 0.0 or _press_t >= 0.0

func _end_press() -> void:
	if _press_t < 0.0: return
	_press_t = -1.0
	if clay.hand_set == "press" and clay.state == clay.State.IDLE: clay.hand_gesture("")

# --- The blow ------------------------------------------------------------------------------

## Whether the ground at `at` is rock (see "What is rock" above).
func _rocky(at: Vector2) -> bool:
	var data: NativeTerrainData = clay.editor.data
	var h: Variant = data.ground_height(at)
	if h == null: return false
	var snowline: float = preload("res://scripts/biome_blend.gd").snowline(data._recipe_settings,data._palette.snowline)
	if float(h) > snowline-clay.ROCK_BAND: return true
	var drawn: Dictionary = preload("res://scripts/native_formation_shape.gd").BIOMES.get(data._recipe_settings.get("biome",""),{})
	var rock_slope := float(drawn.get("rock_slope",data._palette.rock_slope))
	if preload("res://scripts/native_landscape_presets.gd")._slope(data,at) >= rock_slope*ROCK_SLOPE_SHARE: return true
	var cell: int = data.meadow_cell(at)
	if NativeTerrainTint.weight_at(data.tint,cell) < ROCK_PAINT: return false
	var colour := NativeTerrainTint.color_at(data.tint,cell)
	if clay.Strata.earthy(colour,EARTHY): return false
	var e: Color = clay.TURNED.srgb_to_linear()
	return Vector3(colour.r-e.r,colour.g-e.g,colour.b-e.b).length() >= EARTHY

## How far a blow's scree may reach, for trees sliding off.
func _spill_reach() -> float:
	return _radius(CRACK_RADIUS)+8.0

## One blow at `at` on `heights` (the live land's copy): a crack on rock,
## else a knock. Paints the scree and the scar into the tint (the stroke is
## open, so the undo step takes it back).
func _strike(heights: PackedFloat32Array, at: Vector2, fine: bool) -> void:
	_fine = fine
	if _rocky(at): _crack(heights,at)
	else: _knock(heights,at)
	var blow := 0.6 if fine else 1.0
	clay.sound(&"crack" if last.kind == "crack" else &"knock",at,blow)
	if int(last.scree) > 0: clay.sound(&"scree",at,blow*minf(float(last.scree)/20.0,1.0))

func _knock(heights: PackedFloat32Array, at: Vector2) -> void:
	var radius := _radius(KNOCK_RADIUS)
	var depth := KNOCK_DEPTH*(FINE if _fine else 1.0)
	clay.gather(at,radius)
	clay.touch(at,radius)
	var moved := 0.0
	for k in clay.near.size():
		var i: int = clay.near[k]
		var t: float = clay.near_d[k]/radius
		var dent: float = depth*pow(1.0-t*t,2.0)*clay.fade(i)
		heights[i] = maxf(heights[i]-dent,NativeTerrainData.MIN_HEIGHT)
		moved += dent
	last = {"kind":"knock","cut":clay.near.size(),"scree":0,"top_cut":depth,"sum":-moved}

func _crack(heights: PackedFloat32Array, at: Vector2) -> void:
	var data: NativeTerrainData = clay.editor.data
	var points := data.points
	var radius := _radius(CRACK_RADIUS)
	var depth := _radius(CRACK_DEPTH)
	clay.gather(at,radius)
	var near: PackedInt32Array = clay.near.duplicate()
	var near_d: PackedFloat32Array = clay.near_d.duplicate()
	if near.is_empty(): return
	var top := -INF
	for i in near: top = maxf(top,heights[i])
	var level := top-depth
	var salt := hash([clay.editor.land_seed,"hammer",at.snapped(Vector2.ONE*0.01)])
	# Break off the rock over the level.
	var cut := PackedFloat32Array()
	cut.resize(heights.size())
	var taken: Array[int] = []
	for k in near.size():
		var i := near[k]
		if heights[i] <= level: continue
		var shape := 1.0-smoothstep(CRACK_CORE,1.0,near_d[k]/radius)
		var broken := lerpf(BROKEN,1.0,float(hash([salt,i])%1000)/1000.0)
		var c: float = (heights[i]-level)*shape*broken*clay.fade(i)
		if c <= 0.001: continue
		heights[i] -= c
		cut[i] = c
		taken.append(i)
	# Walk each broken piece out and down, and lay it as loose rock.
	var loose := PackedFloat32Array()
	loose.resize(heights.size())
	var seeds: Array[int] = []
	for i in taken:
		var rest := _walk(heights,i,at,radius)
		if loose[rest] <= 0.0: seeds.append(rest)
		loose[rest] += cut[i]
		heights[rest] += cut[i]
	_settle(heights,loose,seeds)
	# What moved, for the refresh, the paint and the probes.
	var area := Rect2(at,Vector2.ZERO).grow(radius)
	var scree := 0
	for i in range(heights.size()):
		if loose[i] > 0.0005 or cut[i] > 0.0:
			area = area.expand(points[i])
			if loose[i] >= SCREE_FROM: scree += 1
	area = area.grow(0.6)
	clay.touch(area.get_center(),maxf(area.size.x,area.size.y)*0.5)
	_paint(area,cut,loose,salt)
	var top_after := -INF
	for i in near: top_after = maxf(top_after,heights[i])
	var sum := 0.0
	for i in range(heights.size()): sum += loose[i]-cut[i]
	last = {"kind":"crack","cut":taken.size(),"scree":scree,"top_cut":top-top_after,"sum":sum}

## Where a piece broken off point `from` comes to rest: out of the scar,
## then down while the ground is steeper than REPOSE.
func _walk(heights: PackedFloat32Array, from: int, at: Vector2, radius: float) -> int:
	var data: NativeTerrainData = clay.editor.data
	var points := data.points
	var neighbors: Array[PackedInt32Array] = data._neighbors
	var here := from
	for step in range(WALK_STEPS):
		var out := points[here].distance_to(at)
		var best := -1
		if out < radius:
			# Out of the scar: the lowest neighbour farther from the blow.
			var lowest := INF
			for j in neighbors[here]:
				if clay.fade(j) < 1.0 or points[j].distance_to(at) <= out: continue
				if heights[j] < lowest:
					lowest = heights[j]
					best = j
			if best >= 0 and lowest > heights[here]: best = -1
		else:
			# Down the fall line while it is steeper than repose.
			var steepest := REPOSE
			for j in neighbors[here]:
				if clay.fade(j) < 1.0: continue
				var drop := (heights[here]-heights[j])/maxf(points[here].distance_to(points[j]),0.01)
				if drop > steepest:
					steepest = drop
					best = j
		if best < 0: break
		here = best
	return here

## Loose rock runs off anywhere it stands over a neighbour steeper than
## REPOSE, until it rests (see "The scree").
func _settle(heights: PackedFloat32Array, loose: PackedFloat32Array, seeds: Array[int]) -> void:
	var data: NativeTerrainData = clay.editor.data
	var points := data.points
	var neighbors: Array[PackedInt32Array] = data._neighbors
	var queued := PackedByteArray()
	queued.resize(heights.size())
	var queue: Array[int] = []
	for i in seeds:
		queue.append(i)
		queued[i] = 1
	var head := 0
	var excess := PackedFloat32Array()
	while head < queue.size() and head < SETTLE_VISITS:
		var i := queue[head]
		head += 1
		queued[i] = 0
		if loose[i] <= 0.0: continue
		var around := neighbors[i]
		excess.resize(around.size())
		var total := 0.0
		var most := 0.0
		for n in around.size():
			var j := around[n]
			var e := 0.0
			if clay.fade(j) >= 1.0: e = heights[i]-heights[j]-REPOSE*points[i].distance_to(points[j])
			excess[n] = e if e > SETTLE_TOL else 0.0
			total += excess[n]
			most = maxf(most,excess[n])
		if total <= 0.0: continue
		var moving := minf(loose[i],most*0.5)
		heights[i] -= moving
		loose[i] -= moving
		for n in around.size():
			if excess[n] <= 0.0: continue
			var j := around[n]
			var share := moving*excess[n]/total
			heights[j] += share
			loose[j] += share
			if queued[j] == 0:
				queued[j] = 1
				queue.append(j)
		# This point, and loose rock above it, may run on now it is lower.
		for j in [i]+Array(around):
			if loose[j] > 0.0 and queued[j] == 0:
				queued[j] = 1
				queue.append(j)

## The scree's and the scar's paint over `area`, per 0.5 m tint cell, and
## the grass gone where the scree covers it. The scar covers what was there
## by its own weight; scree covers it by its thickness (SCREE_FULL of loose
## rock is scree whatever lay under it, a range's granite or grass). A
## cell's weight never drops.
func _paint(area: Rect2, cut: PackedFloat32Array, loose: PackedFloat32Array, salt: int) -> void:
	var data: NativeTerrainData = clay.editor.data
	var side := NativeTerrainData.MEADOW_CELLS
	var step := NativeTerrainData.MEADOW_STEP
	var low := Vector2i(((area.position+Vector2.ONE*Plate.HALF)/step).floor()).clamp(Vector2i.ZERO,Vector2i.ONE*(side-1))
	var high := Vector2i(((area.end+Vector2.ONE*Plate.HALF)/step).floor()).clamp(Vector2i.ZERO,Vector2i.ONE*(side-1))
	var tint := data.tint
	var fresh := FRESH.srgb_to_linear()
	for z in range(low.y,high.y+1):
		for x in range(low.x,high.x+1):
			var p := data.meadow_position(x,z)+Vector2.ONE*step*0.5
			var l: Variant = data.sample(p,loose)
			var c: Variant = data.sample(p,cut)
			if l == null or c == null: continue
			var cell := z*side+x
			var scree := SCREE_WEIGHT*smoothstep(SCREE_FROM,SCREE_FULL,float(l))
			var scar := FRESH_WEIGHT*smoothstep(FRESH_FROM,FRESH_FULL,float(c))
			if scree > 0.01:
				var tone := Color(str(SCREE[hash([salt,x,z])%SCREE.size()])).srgb_to_linear()
				_cover(tint,cell,tone,scree,scree/SCREE_WEIGHT)
				if scree >= BARE:
					data.grass[cell] = 0.0
					data.blades[cell] = 0.0
					data.meadow[cell] = 0.0
					data.provenance[cell] = NativeTerrainData.SOURCE_HAND
			elif scar > 0.01:
				_cover(tint,cell,fresh,scar,scar)
	data.tint = tint

static func _cover(tint: PackedFloat32Array, cell: int, colour: Color, weight: float, cover: float) -> void:
	var k := cell*NativeTerrainTint.STRIDE
	var before := tint[k+3]
	var share := 1.0 if before <= 0.0 else clampf(cover,0.0,1.0)
	tint[k] = lerpf(tint[k],colour.r,share)
	tint[k+1] = lerpf(tint[k+1],colour.g,share)
	tint[k+2] = lerpf(tint[k+2],colour.b,share)
	tint[k+3] = maxf(before,minf(weight,1.0))

# --- The swing ------------------------------------------------------------------------------

## Play the swing from `t` seconds in (0 winds up; IMPACT starts at the blow).
func _swing_at(t: float) -> void:
	_swing_t = t
	_pose()

## Wound back and held there (a hold's blow waits for the release).
func _hold_wound() -> void:
	if _swing != null and is_instance_valid(_swing): _swing.rotation.x = deg_to_rad(WIND_ANGLE)

func _pose() -> void:
	var angle := 0.0
	var t := _swing_t
	if t < 0.0: angle = 0.0
	elif t < WIND_SECONDS: angle = WIND_ANGLE*smoothstep(0.0,1.0,t/WIND_SECONDS)
	elif t < IMPACT:
		var s := (t-WIND_SECONDS)/STRIKE_SECONDS
		angle = lerpf(WIND_ANGLE,STRIKE_ANGLE,s*s)
	elif t < IMPACT+RECOIL_SECONDS:
		var s := (t-IMPACT)/RECOIL_SECONDS
		angle = STRIKE_ANGLE*exp(-4.0*s)*cos(TAU*0.9*s)*(1.0-s)
	else:
		_swing_t = -1.0
	if _swing != null and is_instance_valid(_swing): _swing.rotation.x = deg_to_rad(angle)

# --- The stand-in prop ------------------------------------------------------------------------

## A faceted rock hammer from primitives: a hexagonal wood handle hanging
## from the grip with a pommel, and the head across its foot, an octagonal
## block with a flat striking face toward the drag (+z) and a four-sided pick
## behind (-z), a dark collar where the handle meets it. The parts hang from
## a pivot at the grip that the tap's swing turns. Replaced by the Blender
## hammer's glb later: only this function changes.
func build_prop() -> Node3D:
	var root := Node3D.new()
	_swing = Node3D.new()
	_swing.name = "Swing"
	root.add_child(_swing)
	var foot := -HANDLE_LENGTH+0.12
	_swing.add_child(part(_prism(6),HANDLE,Vector3(0.0,-HANDLE_LENGTH*0.5+0.12,0.0),Vector3(0.04,HANDLE_LENGTH,0.04)))
	_swing.add_child(part(_ball(),HANDLE.darkened(0.2),Vector3(0.0,0.14,0.0),Vector3(0.055,0.05,0.055)))
	_swing.add_child(part(_prism(6),COLLAR,Vector3(0.0,foot+0.1,0.0),Vector3(0.06,0.1,0.06)))
	# Across the handle's foot: the head's block, its face and its pick.
	_swing.add_child(part(_prism(8),FACE,Vector3(0.0,foot,HEAD.y*0.5+0.02),Vector3(HEAD.x*0.62,0.05,HEAD.z*0.62),Vector3(PI*0.5,0.0,0.0)))
	_swing.add_child(part(_prism(4,0.0),TINT.darkened(0.15),Vector3(0.0,foot,-HEAD.y*0.5-PICK_LENGTH*0.5+0.01),Vector3(HEAD.x*0.5,PICK_LENGTH,HEAD.z*0.5),Vector3(PI*0.5,0.0,0.0)))
	_swing.add_child(part(_prism(8,0.9),TINT,Vector3(0.0,foot,0.0),Vector3(HEAD.x*0.5,HEAD.y,HEAD.z*0.5),Vector3(PI*0.5,0.0,0.0)))
	return root

## An upright n-sided prism, unit radius and height, tapering to `foot` of
## its radius at the bottom (0 is a pyramid).
static func _prism(sides: int, foot := 1.0) -> Mesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 1.0
	mesh.bottom_radius = foot
	mesh.height = 1.0
	mesh.radial_segments = sides
	mesh.rings = 1
	return mesh

static func _ball() -> Mesh:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 7
	mesh.rings = 4
	return mesh
