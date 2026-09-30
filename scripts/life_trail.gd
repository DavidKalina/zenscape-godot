extends Node3D
## Bigfoot's trail (docs/scenic/life.md, "Bigfoot's trail"): signs that he is
## about, long before anyone sees him. On a world that is becoming his kind of
## place (a weaker version of the sighting's wood, held a while), now and then:
## - tracks in snow, or in the mud by the water, found in the morning: big bare
##   feet a stride too long for a person, from the wood to the water and back.
##   They fade: rain washes them, snow fills them, a thaw melts snow tracks.
## - a small cairn of stacked stones, or a sapling snapped high up and bent
##   over, at the edge of the elder stand where there was none.
## - a far howl on a still, clear night, and wood knocks from the elder stand
##   at dusk or night (GenesisAudio answers the moments).
## How often scales with how "his" the world is (`kinship`), and every sign
## seen makes a sighting a little likelier (`boost`). Nothing is labelled.
##
## Owned by LifeMoments and advanced on the life clock; it reads the survey
## and LifeMoments' light and weather and never scans the world by itself,
## except for the elder stand's dead wood when a sign needs a place there.

const Survey = preload("res://scripts/life_survey.gd")
const Models = preload("res://scripts/life_models.gd")

## The gate, a weaker sighting wood: TRAIL_TREES trees, richness
## TRAIL_RICHNESS and an edge with TRAIL_EDGE_TREES trees near, held for
## TRAIL_SETTLE s of life, and no stroke for TRAIL_QUIET s.
const TRAIL_TREES := 10
const TRAIL_EDGE_TREES := 5
const TRAIL_RICHNESS := 1.4
const TRAIL_SETTLE := 180.0
const TRAIL_QUIET := 20.0
## Kinship, how "his" the place is: HIS_FLOOR once the gate holds, rising to 1
## with trees, richness and edge density across these ranges, an old stand
## (dead wood) and water, and with time held (full at HIS_AGED s).
const HIS_FLOOR := 0.2
const HIS_TREES := Vector2(10.0,30.0)
const HIS_RICHNESS := Vector2(1.4,3.0)
const HIS_EDGE := Vector2(5.0,12.0)
const HIS_AGED := 900.0
## Chance per LifeMoments.CHECK at full kinship, and the least life-clock
## seconds between two of a kind. Marks (tracks, a cairn, a branch) are left
## at night or dawn, or once per night that goes by (NIGHT_CHANCE; the phase
## falling by more than NIGHT_JUMP), so they are found in the morning even
## where the plain eases through its night in seconds. The howl wants a still
## (air plus swell under HOWL_STILL), clear (cloud under HOWL_CLOUD, fog under
## HOWL_MIST) night, or the last of dusk (phase from NIGHTFALL). Knocks come in
## the sighting's light: dawn, dusk, night or daytime mist.
const NIGHT_CHANCE := 0.5
const NIGHT_JUMP := 0.3
const NIGHTFALL := 0.74
const MARK_CHANCE := 0.02
const MARK_GAP := 240.0
const HOWL_CHANCE := 0.015
const HOWL_GAP := 420.0
const HOWL_STILL := 0.45
const HOWL_CLOUD := 0.45
const HOWL_MIST := 0.3
const KNOCK_CHANCE := 0.014
const KNOCK_GAP := 300.0
## Which mark, when tracks can be laid: tracks, cairn, branch.
const MARK_WEIGHTS := [0.55,0.25,0.2]
## Tracks: a step of STEP_LENGTH m (a person's is about 0.75), feet
## GAIT m either side of the line. They show in snow (snow_cover at least
## SNOW_GROUND), on wet ground (ground_wet at least WET_GROUND) or within
## MUD_REACH m of water, and need MIN_PRINTS; the water is at most
## TRACK_REACH m from the wood.
const STEP_LENGTH := 1.25
const GAIT := 0.16
const PRINT_SCALE := 1.0
const SNOW_GROUND := 0.2
const WET_GROUND := 0.35
const MUD_REACH := 3.0
const MIN_PRINTS := 3
const TRACK_REACH := 11.0
## Fading, in life-clock seconds from full to gone: left alone, in rain above
## RAIN_WASH, in falling snow above SNOW_FILL, and (snow tracks) once the
## snow_cover falls under SNOW_GROUND.
const TRACK_LIFE := 900.0
const TRACK_WASH := 45.0
const TRACK_FILL := 120.0
const TRACK_MELT := 60.0
const RAIN_WASH := 0.25
const SNOW_FILL := 0.3
## At most TRACK_SETS sets of at most PRINTS_PER_SET prints; at most MARK_KEEP
## cairns and branches, MARK_APART m apart. A mark goes if its ground moves
## more than MARK_SHIFT m or floods.
const TRACK_SETS := 2
const PRINTS_PER_SET := 20
const MARK_KEEP := 3
const MARK_APART := 2.0
const MARK_SHIFT := 0.25
## Plate half-size signs keep inside, metres.
const PLATE := 12.8
## A sighting's chance grows by up to SIGHTING_BOOST once BOOST_SIGNS signs
## have been left on this world.
const SIGHTING_BOOST := 0.6
const BOOST_SIGNS := 4
## Print tones (linear), fresh and nearly filled.
const MUD := Color(0.12,0.09,0.065)
const MUD_FILLED := Color(0.3,0.25,0.18)
const SNOW := Color(0.5,0.58,0.76)
const SNOW_FILLED := Color(0.85,0.88,0.95)
const DEAD_KINDS := ["snag","log","stump"]
const DOCUMENT_VERSION := 1

var moments: Node3D
var life: Node3D
## Signs left on this world so far, saved; the sighting's boost reads it.
var count := 0
## Sets of prints: {"kind": "snow" or "mud", "fade": 1 to 0, "prints": [[x, z, yaw, left], ...]}.
var tracks: Array[Dictionary] = []
## Cairns and branches: {"kind", "x", "z", "yaw", "seed", "y", "node"}.
var marks: Array[Dictionary] = []
## The last kinship worked out, for probes.
var kinship := 0.0
var _since := -1.0
var _next_mark := 0.0
var _next_howl := 0.0
var _next_knock := 0.0
var _redraw := 0.0
var _seen: RefCounted
var _old := false
var _last_phase := 0.0
var _feet: Array[MultiMeshInstance3D] = []

func setup(owner: Node3D) -> void:
	moments = owner
	life = owner.life
	name = "BigfootTrail"
	for left in [true,false]:
		var node := MultiMeshInstance3D.new()
		node.name = "LeftPrints" if left else "RightPrints"
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.use_colors = true
		batch.instance_count = TRACK_SETS*PRINTS_PER_SET
		batch.mesh = _print_mesh(life.material,left)
		batch.custom_aabb = AABB(Vector3(-16,-4,-16),Vector3(32,40,32))
		batch.visible_instance_count = 0
		node.multimesh = batch
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		_feet.append(node)

## A new world: every sign goes and the count starts again.
func clear() -> void:
	tracks.clear()
	for mark in marks: (mark.node as Node3D).queue_free()
	marks.clear()
	count = 0
	_since = -1.0
	_seen = null
	_draw_tracks()

## How much likelier a sighting is for the signs left so far: 1 and up.
func boost() -> float:
	return 1.0+SIGHTING_BOOST*minf(float(count)/BOOST_SIGNS,1.0)

func advance(step: float) -> void:
	if tracks.is_empty(): return
	var weather: Variant = _surface()
	var snow_cover: float = float(weather.snow_cover) if weather != null else 0.0
	var rain: float = moments._rain_now()
	var snowing: float = float(life.scene._precipitation.state.y)
	for line in tracks:
		var rate := 1.0/TRACK_LIFE
		if rain > RAIN_WASH: rate = maxf(rate,1.0/TRACK_WASH)
		if line.kind == "snow":
			if snowing > SNOW_FILL: rate = maxf(rate,1.0/TRACK_FILL)
			if snow_cover < SNOW_GROUND: rate = maxf(rate,1.0/TRACK_MELT)
		line.fade = maxf(0.0,float(line.fade)-step*rate)
	_redraw -= step
	if _redraw <= 0.0:
		_redraw = 0.5
		var kept := tracks.filter(func(line: Dictionary) -> bool: return float(line.fade) > 0.0)
		tracks.assign(kept)
		_draw_tracks()

# --- When -----------------------------------------------------------------

## The gate and kinship now, for probes and the sighting's conditions.
func conditions() -> Dictionary:
	var survey: RefCounted = life.survey
	var clock: float = life.clock
	var trees: int = survey.tree_count if survey != null else 0
	var richness: float = survey.richness() if survey != null else 0.0
	var edge := 0
	if survey != null:
		for record: Dictionary in survey.forest_edges: edge = maxi(edge,int(record.trees))
	var hidden: bool = bool(life.scene.get("scenery_mode")) and not bool(life.scene.get("resident_enabled"))
	var his := survey != null and trees >= TRAIL_TREES and richness >= TRAIL_RICHNESS and edge >= TRAIL_EDGE_TREES
	var held := clock-_since if his and _since >= 0.0 else -1.0
	return {"hidden":hidden,"his":his,"held":snappedf(held,0.1),"settled":held >= TRAIL_SETTLE,
		"quiet":not life.editor._painting and clock-float(moments._stroke_at) >= TRAIL_QUIET,
		"kinship":snappedf(kinship,0.01),"signs":count,"boost":snappedf(boost(),0.01),
		"tracks":tracks.size(),"marks":marks.size()}

func _kinship(survey: RefCounted, held: float) -> float:
	var edge := 0
	for record: Dictionary in survey.forest_edges: edge = maxi(edge,int(record.trees))
	var old := 1.0 if _old else 0.0
	var water := 1.0 if not survey.bodies.is_empty() or survey.stream_cells > 0 else 0.0
	var place := 0.3*_ramp(survey.tree_count,HIS_TREES)+0.25*_ramp(survey.richness(),HIS_RICHNESS)+0.2*_ramp(edge,HIS_EDGE)+0.15*old+0.1*water
	var aged := lerpf(0.5,1.0,smoothstep(TRAIL_SETTLE,HIS_AGED,held))
	return (HIS_FLOOR+(1.0-HIS_FLOOR)*place)*aged

static func _ramp(value: float, span: Vector2) -> float:
	return clampf((value-span.x)/(span.y-span.x),0.0,1.0)

## Called on each LifeMoments check.
func consider(survey: RefCounted, clock: float) -> void:
	if survey != _seen:
		_seen = survey
		_reseat()
	var state := conditions()
	if state.his:
		if _since < 0.0: _since = clock
	else:
		_since = -1.0
		kinship = 0.0
		return
	kinship = _kinship(survey,clock-_since)
	var phase: float = moments._phase()
	# A night went by: the phase ran back past midnight, or the plain eased
	# through its night (cozy_regrowth.gd PLAIN_NIGHT) or was snapped to day.
	var overnight := phase < _last_phase-NIGHT_JUMP
	_last_phase = phase
	if not state.hidden or not state.settled or moments.bigfoot.showing(): return
	var downpour: bool = moments._bigfoot_weather() == 0.0
	var dark: bool = moments.light_now() == "night"
	if overnight and clock >= _next_mark and not downpour and moments._roll(NIGHT_CHANCE*kinship):
		if _leave_mark(survey): _next_mark = clock+MARK_GAP
	if not state.quiet: return
	if clock >= _next_mark and (dark or moments.light_now() == "dawn") and not downpour and moments._roll(MARK_CHANCE*kinship):
		if _leave_mark(survey): _next_mark = clock+MARK_GAP
	if clock >= _next_howl and (dark or phase >= NIGHTFALL) and _still_clear() and moments._roll(HOWL_CHANCE*kinship):
		if _sound("bigfoot_howl",survey): _next_howl = clock+HOWL_GAP
	if clock >= _next_knock and moments._bigfoot_light() > 0.0 and not downpour and moments._roll(KNOCK_CHANCE*kinship):
		if _sound("bigfoot_knocks",survey): _next_knock = clock+KNOCK_GAP

func _still_clear() -> bool:
	var atmosphere: Variant = life.scene.get("_atmosphere")
	var air: float = float(atmosphere._air_strength)+float(atmosphere.swell) if atmosphere != null else 0.0
	var sky: Vector4 = life.scene._precipitation.state
	return air < HOWL_STILL and sky.x < 0.05 and sky.y < 0.05 and sky.z < HOWL_CLOUD and moments._fog() < HOWL_MIST

func _surface() -> Variant:
	var sky: Variant = life.scene.get("_precipitation")
	return sky.get("surface_weather") if sky != null else null

## Probes only: leave a sign now, skipping the gate, hour and chance but not
## the place it needs. `kind` is tracks, cairn, branch, howl or knocks.
func force(kind: String) -> bool:
	var survey: RefCounted = life.survey
	if survey == null: return false
	match kind:
		"tracks": return _lay_tracks(survey,true)
		"cairn","branch": return _place_mark(survey,kind)
		"howl","knocks": return _sound("bigfoot_"+kind,survey)
	return false

func _leave_mark(survey: RefCounted) -> bool:
	var pick := MARK_WEIGHTS.size()-1
	var roll: float = life._rng.randf()
	for i in range(MARK_WEIGHTS.size()):
		roll -= float(MARK_WEIGHTS[i])
		if roll < 0.0:
			pick = i
			break
	if pick == 0 and _lay_tracks(survey,false): return true
	return _place_mark(survey,"cairn" if pick == 1 or (pick == 0 and life._rng.randf() < 0.5) else "branch")

## Knocks come from the elder stand; the howl from well beyond it.
func _sound(kind: String, survey: RefCounted) -> bool:
	var elder := _elder(survey)
	if elder.x == INF: return false
	_signed(kind,Vector3(elder.x,moments._ground(elder),elder.y))
	return true

func _signed(kind: String, p: Vector3) -> void:
	count += 1
	moments._record(kind,p)

# --- Where ----------------------------------------------------------------

## The heart of the elder stand: the dead wood with the most dead wood and
## trees round it (old stands grow snags, logs and stumps; emergence.gd), or
## the densest square metre of wood when there is none. INF when no wood.
func _elder(survey: RefCounted) -> Vector2:
	var dead: Array[Vector2] = []
	for item: Dictionary in survey._objects:
		if str(item.get("asset","")) in DEAD_KINDS: dead.append(Vector2(float(item.x),float(item.z)))
	var best := Vector2(INF,INF)
	var score := -1.0
	for p in dead:
		var near := 0.0
		for q in dead:
			if p.distance_squared_to(q) < 16.0: near += 1.0
		near += 0.2*_trees_round(survey,p)
		if near > score:
			score = near
			best = p
	if best.x != INF: return best
	for i in range(Survey.COARSE*Survey.COARSE):
		var c := Vector2(i%Survey.COARSE+0.5,i/Survey.COARSE+0.5)-Vector2(Survey.HALF,Survey.HALF)
		var trees := _trees_round(survey,c)
		if trees > score and trees > 0.0:
			score = trees
			best = c
	return best

static func _trees_round(survey: RefCounted, p: Vector2) -> float:
	var g := Vector2i((p+Vector2(Survey.HALF,Survey.HALF)).floor())
	var trees := 0
	for dz in range(-1,2):
		for dx in range(-1,2):
			var x := g.x+dx
			var z := g.y+dz
			if x >= 0 and z >= 0 and x < Survey.COARSE and z < Survey.COARSE: trees += survey.tree_grid[z*Survey.COARSE+x]
	return float(trees)

func _strong_edges(survey: RefCounted) -> Array[Dictionary]:
	var edges: Array[Dictionary] = []
	for edge: Dictionary in survey.forest_edges:
		var p: Vector2 = edge.p
		if int(edge.trees) >= TRAIL_EDGE_TREES and absf(p.x) < PLATE and absf(p.y) < PLATE: edges.append(edge)
	return edges

## Tracks from the wood down to the water and back in a little way along, or
## in snow a loop out of the wood and back. `any` (probes) lays them whatever
## the ground, as snow tracks when there is snow and mud tracks when not.
func _lay_tracks(survey: RefCounted, any: bool) -> bool:
	var edges := _strong_edges(survey)
	if edges.is_empty(): return false
	var weather: Variant = _surface()
	var snow: bool = weather != null and float(weather.snow_cover) >= SNOW_GROUND
	var wet: bool = weather != null and float(weather.ground_wet) >= WET_GROUND
	var rng: RandomNumberGenerator = life._rng
	# The edge nearest water, of a few drawn.
	var best := {}
	var shore := Vector2.ZERO
	var reach := TRACK_REACH
	for n in range(mini(edges.size(),24)):
		var edge: Dictionary = edges[rng.randi_range(0,edges.size()-1)]
		var p: Vector2 = edge.p
		for cell in survey.shore:
			var c := Survey.center(cell)
			var d := c.distance_to(p)
			if d < reach and absf(c.x) < PLATE and absf(c.y) < PLATE:
				reach = d
				best = edge
				shore = c
	var path: Array[Vector2] = []
	if not best.is_empty():
		var into: Vector2 = best.into
		var from: Vector2 = (best.p as Vector2)+into*1.4
		var side := into.orthogonal()*(1.0 if rng.randf() < 0.5 else -1.0)
		var back: Vector2 = (best.p as Vector2)+side*rng.randf_range(2.5,4.0)+into*1.4
		path.assign(_curve(from,shore,side*0.8)+_curve(shore,back,-side*0.6).slice(1))
	elif snow or any:
		var edge: Dictionary = edges[rng.randi_range(0,edges.size()-1)]
		var into: Vector2 = edge.into
		var side := into.orthogonal()*(1.0 if rng.randf() < 0.5 else -1.0)
		var from: Vector2 = (edge.p as Vector2)+into*1.2
		path.assign(_curve(from,from+side*rng.randf_range(6.0,8.0),-into*rng.randf_range(3.0,4.5)))
	if path.is_empty(): return false
	var prints := []
	var walked := 0.0
	var next := 0.0
	var left := rng.randf() < 0.5
	for i in range(path.size()-1):
		var a := path[i]
		var b := path[i+1]
		var length := a.distance_to(b)
		while next <= walked+length and prints.size() < PRINTS_PER_SET:
			var ahead := (b-a)/maxf(length,0.001)
			var p := a+ahead*(next-walked)+ahead.orthogonal()*(GAIT if left else -GAIT)
			# The feet toe out a little.
			var yaw := atan2(ahead.x,ahead.y)+(0.12 if left else -0.12)
			if _shows(survey,p,snow,wet,any): prints.append([snappedf(p.x,0.001),snappedf(p.y,0.001),snappedf(yaw,0.001),left])
			left = not left
			next += STEP_LENGTH*rng.randf_range(0.94,1.06)
		walked += length
	if prints.size() < MIN_PRINTS: return false
	tracks.append({"kind":"snow" if snow else "mud","fade":1.0,"prints":prints})
	while tracks.size() > TRACK_SETS: tracks.pop_front()
	_draw_tracks()
	var first: Array = prints[0]
	_signed("bigfoot_tracks",Vector3(first[0],moments._ground(Vector2(first[0],first[1])),first[1]))
	return true

## A quadratic curve from `a` to `b` bowed by `bow`, in short straight pieces.
static func _curve(a: Vector2, b: Vector2, bow: Vector2) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var middle := (a+b)*0.5+bow
	var pieces := maxi(4,int(a.distance_to(b)/0.5))
	for i in range(pieces+1):
		var t := float(i)/pieces
		points.append(a.lerp(middle,t).lerp(middle.lerp(b,t),t))
	return points

## True where a print would take: dry, not steep, on the plate, and in snow,
## wet ground or mud by the water.
func _shows(survey: RefCounted, p: Vector2, snow: bool, wet: bool, any: bool) -> bool:
	if absf(p.x) > PLATE or absf(p.y) > PLATE or survey.wet_at(p): return false
	var cell := Survey.cell_at(p)
	if cell < 0 or survey.slope[cell] > 0.6 or life.data.ground_height(p) == null: return false
	return snow or wet or any or survey.water_distance[cell] <= MUD_REACH

## A cairn or a snapped sapling at the edge of the wood nearest the elder stand.
func _place_mark(survey: RefCounted, kind: String) -> bool:
	var elder := _elder(survey)
	if elder.x == INF: return false
	var edges := _strong_edges(survey)
	edges.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return (a.p as Vector2).distance_squared_to(elder) < (b.p as Vector2).distance_squared_to(elder))
	var rng: RandomNumberGenerator = life._rng
	for edge in edges.slice(0,32):
		var into: Vector2 = edge.into
		var p: Vector2 = (edge.p as Vector2)+into*rng.randf_range(0.0,0.3)+into.orthogonal()*rng.randf_range(-0.25,0.25)
		var cell := Survey.cell_at(p)
		if cell < 0 or survey.wet_at(p) or survey.slope[cell] > 0.35: continue
		if marks.any(func(mark: Dictionary) -> bool: return Vector2(mark.x,mark.z).distance_to(p) < MARK_APART): continue
		# A cairn faces out of the wood; a sapling falls across the edge.
		var yaw := atan2(-into.x,-into.y)+rng.randf_range(-0.5,0.5)
		var mark := {"kind":kind,"x":snappedf(p.x,0.001),"z":snappedf(p.y,0.001),"yaw":snappedf(yaw,0.001),"seed":rng.randi_range(0,65535)}
		if not _build_mark(mark): continue
		marks.append(mark)
		while marks.size() > MARK_KEEP: (marks.pop_front().node as Node3D).queue_free()
		_signed("bigfoot_"+kind,(mark.node as Node3D).position)
		return true
	return false

func _build_mark(mark: Dictionary) -> bool:
	var p := Vector2(mark.x,mark.z)
	var h: Variant = life.data.ground_height(p)
	if h == null: return false
	var node := MeshInstance3D.new()
	node.name = "Cairn" if mark.kind == "cairn" else "Branch"
	node.mesh = _cairn_mesh(life.material,int(mark.seed)) if mark.kind == "cairn" else _branch_mesh(life.material,int(mark.seed))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	node.position = Vector3(p.x,float(h)-0.02,p.y)
	node.rotation.y = float(mark.yaw)
	add_child(node)
	mark.y = float(h)
	mark.node = node
	return true

## A new survey: marks whose ground moved or flooded go, prints under water
## go, and whether the wood has an old stand (dead wood) is read once.
func _reseat() -> void:
	var survey: RefCounted = life.survey
	if survey == null: return
	_old = false
	for item: Dictionary in survey._objects:
		if str(item.get("asset","")) in DEAD_KINDS:
			_old = true
			break
	for mark in marks.duplicate():
		var p := Vector2(mark.x,mark.z)
		var h: Variant = life.data.ground_height(p)
		if h == null or survey.wet_at(p) or absf(float(h)-float(mark.y)) > MARK_SHIFT:
			(mark.node as Node3D).queue_free()
			marks.erase(mark)
			continue
		mark.y = float(h)
		(mark.node as Node3D).position.y = float(h)-0.02
	for line in tracks:
		line.prints = (line.prints as Array).filter(func(row: Array) -> bool: return not survey.wet_at(Vector2(row[0],row[1])))
	_draw_tracks()

# --- Drawing ----------------------------------------------------------------

func _draw_tracks() -> void:
	var counts := [0,0]
	for line in tracks:
		var fade := float(line.fade)
		var fresh: Color = SNOW if line.kind == "snow" else MUD
		var filled: Color = SNOW_FILLED if line.kind == "snow" else MUD_FILLED
		var tone := filled.lerp(fresh,smoothstep(0.0,0.6,fade))
		var size := lerpf(0.55,1.0,smoothstep(0.0,0.5,fade))*PRINT_SCALE
		for row: Array in line.prints:
			var foot := 0 if row[3] else 1
			var batch: MultiMesh = _feet[foot].multimesh
			var p := Vector2(row[0],row[1])
			var h: Variant = life.data.ground_height(p)
			if h == null or counts[foot] >= batch.instance_count: continue
			var basis := _ground_basis(p,float(row[2]))
			batch.set_instance_transform(counts[foot],Transform3D(basis.scaled_local(Vector3(size,1.0,size)),Vector3(p.x,float(h)+0.015,p.y)))
			batch.set_instance_color(counts[foot],tone)
			counts[foot] += 1
	for foot in range(2): _feet[foot].multimesh.visible_instance_count = counts[foot]

## Up along the ground's slope at `p`, +Z along `yaw`.
func _ground_basis(p: Vector2, yaw: float) -> Basis:
	var e := 0.2
	var hx0: Variant = life.data.ground_height(p-Vector2(e,0))
	var hx1: Variant = life.data.ground_height(p+Vector2(e,0))
	var hz0: Variant = life.data.ground_height(p-Vector2(0,e))
	var hz1: Variant = life.data.ground_height(p+Vector2(0,e))
	var dx := (float(hx1)-float(hx0))/(2.0*e) if hx0 != null and hx1 != null else 0.0
	var dz := (float(hz1)-float(hz0))/(2.0*e) if hz0 != null and hz1 != null else 0.0
	var up := Vector3(-dx,1.0,-dz).normalized()
	var ahead := Vector3(sin(yaw),0.0,cos(yaw))
	ahead = (ahead-up*ahead.dot(up)).normalized()
	return Basis(up.cross(ahead),up,ahead)

## A bare print, flat on y = 0, toes to +Z: heel, a long flat sole with no
## arch to speak of, the ball, and five toes, the big one inside. About
## 0.42 m long, where a person's is 0.27. White: the instance colour tones it.
static func _print_mesh(material: Material, left: bool) -> ArrayMesh:
	var b := Models.Build.new()
	var inside := 1.0 if left else -1.0
	var tone := Color(1,1,1)
	var toe := Color(0.9,0.9,0.9)
	b.disc(Vector3(0,0,-0.14),Vector3.UP,0.07,0.075,tone,7)
	b.disc(Vector3(0.006*inside,0,-0.03),Vector3.UP,0.068,0.1,tone,7)
	b.disc(Vector3(0.012*inside,0.001,0.09),Vector3.UP,0.085,0.06,tone,7)
	var toes := [[0.055,0.2,0.032],[0.02,0.19,0.026],[-0.012,0.18,0.023],[-0.04,0.165,0.021],[-0.063,0.145,0.019]]
	for spec: Array in toes:
		b.disc(Vector3(float(spec[0])*inside,0.002,float(spec[1])),Vector3.UP,float(spec[2]),float(spec[2])*1.15,toe,6)
	return b.commit(material)

## Three to five flat stones, each smaller, stacked a little off true.
static func _cairn_mesh(material: Material, seed: int) -> ArrayMesh:
	var b := Models.Build.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var stones := rng.randi_range(3,5)
	var y := 0.0
	var radius := rng.randf_range(0.17,0.21)
	var greys := [Models.hex("#8a8680"),Models.hex("#9c978e"),Models.hex("#77736d"),Models.hex("#a8a298")]
	var drift := Vector3.ZERO
	for i in range(stones):
		var squash := rng.randf_range(0.42,0.58)
		y += radius*squash
		b.icosahedron(Vector3(drift.x,y,drift.z),radius,greys[rng.randi_range(0,greys.size()-1)],squash)
		y += radius*squash*0.82
		drift += Vector3(rng.randf_range(-0.025,0.025),0,rng.randf_range(-0.025,0.025))
		radius *= rng.randf_range(0.72,0.84)
	return b.commit(material)

## A sapling snapped at about head height of a tall man and folded down, or
## bent over into an arch, too high and too hard for a deer: the kind of
## thing nobody walking by would do. Faces +Z.
static func _branch_mesh(material: Material, seed: int) -> ArrayMesh:
	var b := Models.Build.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var bark := Models.hex("#5c4b3b")
	var pale := Models.hex("#d9c9a3")
	var leaf := Models.hex("#7d7a3c")
	var bark_paint := func(_u: float, _a: float) -> Color: return bark
	var tips: Array[Vector3] = []
	if rng.randf() < 0.6:
		# Snapped: a stump to the break, pale splinters, the top hanging down.
		var brk := Vector3(0,rng.randf_range(1.5,1.8),0)
		b.limb(Vector3.ZERO,brk,0.05,0.036,bark_paint,5,2)
		for i in range(3):
			var angle := TAU*i/3.0+rng.randf()
			b.spindle(brk+Vector3(cos(angle),0,sin(angle))*0.02,brk+Vector3(cos(angle)*0.03,rng.randf_range(0.07,0.13),sin(angle)*0.03),0.012,pale,4)
		var hang := brk+Vector3(rng.randf_range(-0.15,0.15),-brk.y+rng.randf_range(0.15,0.35),rng.randf_range(0.7,0.95))
		b.limb(brk+Vector3(0,-0.03,0.03),hang,0.033,0.012,bark_paint,5,3)
		for t in [0.45,0.7,1.0]: tips.append(brk.lerp(hang,t))
	else:
		# Bent over into an arch, its crown pinned to the ground.
		var reach := rng.randf_range(1.6,2.1)
		var points: Array[Vector3] = []
		for i in range(7):
			var t := i/6.0
			points.append(Vector3(0.12*sin(t*PI),sin(t*PI*0.92)*rng.randf_range(1.05,1.15)*(1.0-0.2*t),t*reach))
		for i in range(6):
			b.limb(points[i],points[i+1],lerpf(0.045,0.014,i/6.0),lerpf(0.045,0.014,(i+1)/6.0),bark_paint,5,2)
		for t in [3,5,6]: tips.append(points[t])
	for tip in tips:
		for k in range(2):
			b.icosahedron(tip+Vector3(rng.randf_range(-0.12,0.12),rng.randf_range(-0.04,0.1),rng.randf_range(-0.12,0.12)),rng.randf_range(0.07,0.11),leaf,0.7)
	return b.commit(material)

# --- Saving -----------------------------------------------------------------

## The trail for LandLife's document; empty when nothing has been left.
func document() -> Dictionary:
	if count == 0 and tracks.is_empty() and marks.is_empty(): return {}
	var saved_tracks := []
	for line in tracks:
		var flat := []
		for row: Array in line.prints: flat.append_array([row[0],row[1],row[2],1.0 if row[3] else 0.0])
		saved_tracks.append({"kind":line.kind,"fade":snappedf(float(line.fade),0.001),"prints":flat})
	var saved_marks := []
	for mark in marks: saved_marks.append([mark.kind,mark.x,mark.z,mark.yaw,mark.seed])
	return {"version":DOCUMENT_VERSION,"count":count,"tracks":saved_tracks,"marks":saved_marks}

static func valid_document(value: Variant) -> bool:
	if not value is Dictionary: return false
	if value.is_empty(): return true
	if value.get("version") != float(DOCUMENT_VERSION) and value.get("version") != DOCUMENT_VERSION: return false
	if not GardenData._integer(value.get("count")) or int(value.count) < 0: return false
	if not value.get("tracks") is Array or value.tracks.size() > TRACK_SETS or not value.get("marks") is Array or value.marks.size() > MARK_KEEP: return false
	for line: Variant in value.tracks:
		if not line is Dictionary or not line.get("kind") in ["snow","mud"] or not GardenData._number(line.get("fade"),0.0,1.0): return false
		if not line.get("prints") is Array or line.prints.size()%4 != 0 or line.prints.size() > PRINTS_PER_SET*4: return false
		for n: Variant in line.prints:
			if not GardenData._number(n,-100.0,100.0): return false
	for row: Variant in value.marks:
		if not row is Array or row.size() != 5 or not row[0] in ["cairn","branch"]: return false
		for n in range(1,4):
			if not GardenData._number(row[n],-100.0,100.0): return false
		if not GardenData._integer(row[4]): return false
	return true

## Put a saved trail back (after LandLife.clear on load).
func restore(value: Dictionary) -> void:
	clear()
	if value.is_empty() or not valid_document(value): return
	count = int(value.count)
	for line: Dictionary in value.tracks:
		var flat: Array = line.prints
		var prints := []
		for i in range(0,flat.size(),4): prints.append([float(flat[i]),float(flat[i+1]),float(flat[i+2]),float(flat[i+3]) > 0.5])
		tracks.append({"kind":str(line.kind),"fade":float(line.fade),"prints":prints})
	for row: Array in value.marks:
		var mark := {"kind":str(row[0]),"x":float(row[1]),"z":float(row[2]),"yaw":float(row[3]),"seed":int(row[4])}
		if _build_mark(mark): marks.append(mark)
	_draw_tracks()
