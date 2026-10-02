extends Node3D
## Pollen for the forest (docs/scenic/brushes.md "Pollen", docs/scenic/handful.md).
## You release something; the world decides what becomes of it.
##
## With forest in hand, holding the button lays pollen in the air. A glinting,
## gently churning veil of motes and haze hangs HEIGHT above the ground along
## the pointer's sweep, a little behind it: a line, a curve, a loop round an
## area. Holding still thickens it where it is. Nothing lands while it is held.
## A click without dragging lays a small puff.
##
## Release lets the whole veil go together. It takes a breath first (LIFT: it
## lifts a little and gathers in), then sinks as one soft sheet, peeling down
## from where it was let go to where the sweep began (WAVE), each mote at its
## own pace. The wind carries it as it falls (scripts/pollen_wind.gd, read
## every frame at up to GROUPS places along the veil): still air brings it
## straight down in the swept shape, wind smears and drifts it downwind, and a
## gust can push part of it. Where each mote lands, the land decides what, if
## anything, takes (NativeChunkEditor `_pollen_settled`, scripts/emergence.gd
## `_fertility`).
##
## The veil is a row of knots laid along the sweep, KNOT_STEP apart, each with
## a half-width `r` (grown by dwelling) and its motes. A mote lands at its knot,
## plus its offset in the veil (within `r`), plus a spread (within `sigma`),
## plus the drift the air has given its part of the veil by the time it lands.
##
## The promise (drawn only with --show-promise): a soft footprint on the ground (shaders/pollen_footprint.gdshader)
## follows the swept shape while it is laid and shows where the veil will
## settle in the wind as it blows now: for each knot, a capsule of radius
## r + sigma from the knot's drift so far, carried on by the present wind for
## the least and the most time its motes have left in the air. The footprint is
## the union of them, so every mote lands inside the footprint as it stands
## when that mote lands. Only a change of wind moves it; in steady air the
## release's footprint holds.
##
## Motes are capped per veil (`_cap`): a long sweep spreads its motes along the
## path, taking them from where the veil is densest, rather than adding more.
##
## With a thrower, new motes gather at `hand_at` instead of at the veil's
## head, and wait there until it throws (`toss`): then they fly out at the
## throw's speed and a spring draws each on to its place in the veil. The
## thrower is the pinch of seeds carried from the materials bar
## (scripts/hand_materials.gd `_sow`, which flicks), or under
## `--hand-everywhere` the God Hand's palm (scripts/god_hand.gd). A throw after
## release carries them on to where the falling veil has got to. Where each
## mote lands never changes: the thrower only shows where the pollen comes
## from.
##
## Motes that land at least SEED_GAP from the veil's other seeds are its seeds
## (thinned to SEEDS_MAX, spread out, as it settles); the rest is dust that
## glints and is gone. Where a seed lands on ground that could take it
## (`takes`) a sprout pops up and later sinks as the forest takes over.
## `settled` hands the editor a veil whose last mote is down.
##
## Several veils may be in the air at once, up to CLOUDS; each settles as its
## own undo step (the editor writes it when it settles).
##
## Lives under the terrain node, so its coordinates are the plate's.

const Wind = preload("res://scripts/pollen_wind.gd")

## A veil's last mote is down: {"id", "seeds" (plate x, z), "points" (every
## landing), "lost" (motes that fell off the land), "radius" (the widest
## knot's footprint radius), "motes", "path" (the knots, plate x, z), "length"
## (m swept), and for probes "promised" (each knot's footprint at release:
## [a, b, radius]), "drift" (m the air carried it, mean over the veil),
## "drifts" (m, each part of the veil the wind was read for),
## "worst" (the farthest landing in shares of the radius from the footprint
## as it stood then), "outside" (landings outside it) and "outside_promised"
## (landings outside the release's footprint)}.
signal settled(cloud: Dictionary)

## Metres from the ground to the veil.
const HEIGHT := 2.2
## Seconds of holding still, at strength 1, to thicken a spot fully.
const HOLD_SECONDS := 1.4
## Motes in a click's puff and in a fully thickened spot, at REFERENCE_RADIUS
## and strength 1; the motes a knot of a sweep holds.
const MOTES := Vector2(120,260)
const KNOT_MOTES := 16
## The veil's half-width (m), thin to thickened, at REFERENCE_RADIUS.
const CLOUD := Vector2(0.6,1.3)
## The spread (m) motes drift apart by as they fall: a puff, thin to thickened,
## and a sweep (SWEEP m or longer), which comes down closer to its shape but
## still loose, a drift rather than a line.
const SPREAD := Vector2(2.6,4.0)
const VEIL_SPREAD := 1.8
const SWEEP := 2.0
## Metres between knots along the sweep, at REFERENCE_RADIUS. Knots beyond
## KNOTS merge in pairs (the footprint shader's array).
const KNOT_STEP := 0.45
const KNOTS := 64
## Brush radius (m) those are for; a brush's radius scales them within SIZE.
const REFERENCE_RADIUS := 3.6
const SIZE := Vector2(0.6,1.6)
## Motes one veil holds at most, at REFERENCE_RADIUS and strength 1.
const VEIL_MOTES := 560
## Seconds a mote takes to come down, the lightest the longest: long enough
## that it floats a while and the wind has time to carry it.
const FALL := Vector2(5.5,9.0)
## The release: a breath of LIFT seconds in which the veil lifts LIFT_HEIGHT m
## and gathers in by GATHER of its width, then it sinks, peeling down along the
## sweep over up to WAVE seconds (the whole of it for sweeps of WAVE_LENGTH m
## or more), each mote starting within JITTER seconds of its part.
const LIFT := 0.4
const LIFT_HEIGHT := 0.22
const GATHER := 0.12
const WAVE := 0.6
const WAVE_LENGTH := 8.0
const JITTER := 0.3
## Places along the veil the wind is read, at most, KNOT_GROUP knots each.
const GROUPS := 8
const KNOT_GROUP := 6
## Metres a mote wanders as it falls (the curl of the air), dying out as it
## lands, and how high it rides back up on the air early in its fall (m).
const WANDER := 1.1
const FLOAT := 0.45
## The veil's head follows the pointer on a soft spring (1/s², 1/s); new motes
## ease into their place at SETTLE_RATE (1/s), so the veil trails a little.
const FOLLOW := 30.0
const FOLLOW_DAMP := 9.0
const SETTLE_RATE := 3.5
## Below this head speed (m/s) the pointer is holding still.
const STILL := 0.5
## Metres of the veil's ripple and billow, and their hertz.
const BOB := Vector2(0.08,0.45)
const BILLOW := Vector2(0.12,0.3)
## Metres apart a veil's seeds land at least, and the most seeds one veil
## gives; closer or later motes are dust. A seed is a tree candidate of its
## own and the forest spreads from it (scripts/emergence.gd), so a pinch's
## flick, a sweep or a tree's spores come up as a few trees scattered over
## where they fell, not a carpet. It was 1.1 m and no cap: one oak flick gave
## a dozen trees in a 5 m clump (tools/landscapes/spore_spread.gd).
const SEED_GAP := 2.2
const SEEDS_MAX := 8
## Seconds a landed mote glints on the ground; the sprout's pop, life and
## height (m).
const GLINT := 0.8
const SPROUT_POP := 0.35
const SPROUT_SECONDS := 9.0
const SPROUT_SIZE := 0.3
## Thrown motes: the spring (1/s²) and damping (1/s) that draw a mote from
## the throw on to its place, how widely a throw scatters them (a share of
## its speed, and m/s), the handful's size (a share of each mote's place in
## the veil), the longest a mote waits in the hand (s) before it goes by
## itself, and how near its place (m), or how long after (s), a thrown mote
## is back with the veil.
const FLING_SPRING := 26.0
const FLING_DAMP := 7.0
const SCATTER := Vector2(0.35,0.8)
const HANDFUL := 0.14
const HAND_WAIT := 0.6
const ARRIVED := 0.1
const FLIGHT := 1.2
## Veils in the air at once; another's release settles the oldest at once.
const CLOUDS := 4
const MOTES_MAX := 2560
const SPROUTS_MAX := 160
## Soft haze puffs drawn per veil (a puff's, and at most along a sweep), and
## their brightness.
const HAZE := 8
const HAZE_VEIL := 12
const HAZE_GLOW := 0.1
## Share of motes drawn: the rest still land and seed, unseen, so the air
## reads as a few wisps rather than a swarm. A speck's radius (m) and opacity.
const SHOWN := 0.4
const SPECK := 0.06
const SPECK_ALPHA := 0.75
## Pollen colours by the family of the stand's trees (Emergence
## `seed_family`): all yellows, pine the deepest gold, birch the palest.
const LOOKS := {"conifer":"f0c640","broadleaf":"f3d35a","birch":"f2dc7c","arid":"e6c060"}
const FAMILY := {"tree":"conifer","redwood":"conifer","juniper":"conifer","broadleaf":"broadleaf","layered_tree":"broadleaf",
	"willow":"broadleaf","birch":"birch","joshua":"arid","cactus":"arid"}

## The editor's ground: plate x, z -> height, NAN off the land. Whether a
## seed landing there could take (a sprout shows). The scene, for the wind.
var ground_at: Callable = func(_p: Vector2) -> float: return 0.0
var takes: Callable = func(_p: Vector2) -> bool: return true
var scene: Node
## The thrower's handful (plate): the materials' pinch or the God Hand's
## palm, or null. New motes gather there.
var hand_at: Variant = null
## Microseconds the last frame's step took (for probes).
var last_usec := 0
var age := 0.0
## The veil in hand, or {}; veils in the air.
var held := {}
var clouds: Array[Dictionary] = []
var _hover: Variant = null
var _hover_scale := 1.0
var _serial := 0
var _sprouts: Array[Dictionary] = []
var _glints: Array[Dictionary] = []
var _mote_node: MultiMeshInstance3D
var _sprout_node: MultiMeshInstance3D
var _haze_node: MultiMeshInstance3D
var _prints: Array[MeshInstance3D] = []
static var _meshes := {}

func _ready() -> void:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/pollen_mote.gdshader")
	var speck := ShaderMaterial.new()
	speck.shader = preload("res://shaders/pollen_speck.gdshader")
	var square := QuadMesh.new()
	square.size = Vector2(2,2)
	_mote_node = _instances("Motes",square,MOTES_MAX,speck,true)
	_sprout_node = _instances("Sprouts",_mesh("sprout"),SPROUTS_MAX,material)
	var haze := ShaderMaterial.new()
	haze.shader = preload("res://shaders/pollen_haze.gdshader")
	haze.render_priority = 1
	var quad := QuadMesh.new()
	quad.size = Vector2(2,2)
	_haze_node = _instances("Haze",quad,HAZE_VEIL*(CLOUDS+1),haze)
	for i in range(CLOUDS+1):
		var print_material := ShaderMaterial.new()
		print_material.shader = preload("res://shaders/pollen_footprint.gdshader")
		print_material.render_priority = -1
		var node := MeshInstance3D.new()
		node.name = "Footprint%d" % i
		node.mesh = BoxMesh.new()
		node.material_override = print_material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.top_level = true
		node.visible = false
		add_child(node)
		_prints.append(node)

func _instances(title: String, mesh: Mesh, count: int, material: Material, custom := false) -> MultiMeshInstance3D:
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.use_custom_data = custom
	instances.instance_count = count
	# Nothing draws until its transform is written (a fresh buffer is zeros).
	instances.visible_instance_count = 0
	instances.mesh = mesh
	var node := MultiMeshInstance3D.new()
	node.name = title
	node.multimesh = instances
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.top_level = true
	node.visible = false
	add_child(node)
	return node

## Aiming: the footprint a click would make, under `point` (plate, on the
## ground), or none for null. `brush_radius` sizes it.
func hover(point: Variant, brush_radius := REFERENCE_RADIUS) -> void:
	_hover = point
	_hover_scale = clampf(brush_radius/REFERENCE_RADIUS,SIZE.x,SIZE.y)

## The tree the next veil's seeds came from (spores pulled off a grown tree),
## stamped on the veil at `gather` and handed on in `settled` as "kind", so
## emergence grows that kind; "" lets the stand decide.
var seed_kind := ""

## Start laying a veil over `point` (plate, on the ground). `tree_kind` is the
## stand's tree there (Emergence `seed_family`), "" for the default look.
## `look` overrides it for seed that is not a tree's (the hand's flower seed,
## scripts/flower_sowing.gd): "colour" (the motes'), "spread" (times the fall's
## spread, SPREAD and VEIL_SPREAD), "carry" (times the wind's drift: lighter
## fluff rides the air further) and "takes" (a Callable, plate x, z -> bool,
## for where a seed shows a sprout, in place of `takes`).
func gather(point: Vector3, brush_radius: float, strength: float, tree_kind: String, salt: int, look := {}) -> void:
	if not held.is_empty(): release()
	_serial += 1
	var rng := RandomNumberGenerator.new()
	rng.seed = salt
	var scale := clampf(brush_radius/REFERENCE_RADIUS,SIZE.x,SIZE.y)
	var strong := clampf(strength,0.25,3.0)
	held = {"id":_serial,"state":"held","head":point+Vector3.UP*HEIGHT,"velocity":Vector3.ZERO,"target":point,"age":0.0,
		"scale":scale,"strength":strong,"density":sqrt(strong)*scale*scale,"step":KNOT_STEP*scale,"rng":rng,"knots":[],"motes":[],
		"colour":Color(LOOKS[FAMILY.get(tree_kind,"broadleaf")]),"seeds":PackedVector2Array(),"points":PackedVector2Array(),"times":PackedFloat32Array(),"lost":0,"down":0,"kind":seed_kind,
		"spread":float(look.get("spread",1.0)),"carry":float(look.get("carry",1.0))}
	if look.has("colour"): held.colour = look.colour
	if look.get("takes") is Callable: held.takes = look.takes
	held.cap = clampi(roundi(VEIL_MOTES*float(held.density)),roundi(MOTES.x),MOTES_MAX/CLOUDS)
	_lay(held,_flat(point),point.y)

## A tree flicked (scripts/hand_reach.gd): its spores burst from `crown`
## (plate) at `velocity` (plate m/s) and a spring draws each on to its place
## in a veil laid at once along `path` (ground points, plate), let go straight
## away, so the wind and the land decide from there as for a swept veil.
func fling(crown: Vector3, velocity: Vector3, path: Array, brush_radius: float, strength: float, tree_kind: String, salt: int) -> void:
	gather(path[0],brush_radius,strength,tree_kind,salt)
	for i in range(1,path.size()): _lay(held,_flat(path[i]),float(path[i].y))
	for mote: Dictionary in held.motes:
		mote.erase("hand")
		mote.p = crown+Vector3(randf_range(-0.4,0.4),randf_range(-0.3,0.3),randf_range(-0.4,0.4))
		var scatter := Vector3(randf_range(-1,1),randf_range(-0.2,1),randf_range(-1,1))
		mote.v = velocity*randf_range(0.6,1.2)+scatter*(velocity.length()*SCATTER.x+SCATTER.y)
	release()

## Follow the pointer's ground point (plate), or hold still over null.
func hold(point: Variant) -> void:
	if not held.is_empty() and point != null: held.target = point

## Let the held veil go: the wind now decides where each mote comes down.
func release() -> void:
	if held.is_empty(): return
	var veil := held
	held = {}
	if clouds.size() >= CLOUDS: _settle(clouds[0])
	var knots: Array = veil.knots
	var n := knots.size()
	var length: float = knots.back().s
	veil.length = length
	# Parts of the veil the wind is read at, and the drift it has given each.
	var groups := clampi(ceili(float(n)/KNOT_GROUP),1,GROUPS)
	veil.groups = groups
	veil.drift = []
	veil.wind = []
	veil.middles = []
	for g in range(groups):
		veil.drift.append(Vector2.ZERO)
		veil.wind.append(Vector2.ZERO)
		veil.middles.append(Vector2.ZERO)
	var counts := []
	counts.resize(groups)
	counts.fill(0)
	var sweep := clampf(length/SWEEP,0.0,1.0)
	var wave := WAVE*minf(1.0,length/WAVE_LENGTH)
	for k in range(n):
		var knot: Dictionary = knots[k]
		var g := k*groups/n
		knot.g = g
		veil.middles[g] += _flat(knot.p)
		counts[g] += 1
		# It peels down from where it was let go, back along the sweep.
		knot.wave = wave*(length-float(knot.s))/maxf(length,0.001)
		knot.min_t = LIFT+float(knot.wave)+FALL.x
		knot.max_t = LIFT+float(knot.wave)+JITTER+FALL.y
		knot.sigma = _sigma(veil,knot,sweep)
	for g in range(groups): veil.middles[g] /= float(counts[g])
	for g in range(groups): veil.wind[g] = _wind(veil,veil.middles[g])
	veil.state = "flying"
	veil.t = 0.0
	veil.radius = 0.0
	veil.promised = []
	for knot: Dictionary in knots:
		var ends := _ends(veil,knot)
		veil.promised.append([ends[0],ends[1],float(knot.r)+float(knot.sigma)])
		veil.radius = maxf(float(veil.radius),float(knot.r)+float(knot.sigma))
	veil.worst = 0.0
	veil.outside = 0
	veil.outside_promised = 0
	var rng: RandomNumberGenerator = veil.rng
	for mote: Dictionary in veil.motes:
		var knot: Dictionary = knots[mote.k]
		# Its place in the veil (within r) and a spread (within sigma); the air
		# adds the rest as it falls.
		var off := Vector2(mote.off.x,mote.off.z).limit_length(float(knot.r))
		mote.base = _flat(knot.p)+off+Vector2.RIGHT.rotated(rng.randf()*TAU)*float(knot.sigma)*sqrt(rng.randf())
		# Still in the hand or on its way: its fall starts from its place.
		mote.from = _hang(veil,knot,mote) if mote.has("hand") or mote.has("v") else mote.p
		mote.start = LIFT+float(knot.wave)+rng.randf()*JITTER
		mote.fall = rng.randf_range(FALL.x,FALL.y)
		mote.floor = float(knot.p.y)
		mote.aimed = false
		mote.curl = Vector2.RIGHT.rotated(rng.randf()*TAU)
	clouds.append(veil)

## True while a veil is held or any is in the air.
func active() -> bool:
	return not held.is_empty() or not clouds.is_empty()

func motes_in_air() -> int:
	var count := 0
	for cloud: Dictionary in clouds: count += cloud.motes.size()-int(cloud.down)
	return count

## Motes in the veil in hand.
func motes_held() -> int:
	return 0 if held.is_empty() else held.motes.size()

static func _to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b-a
	var t := clampf((p-a).dot(ab)/maxf(ab.length_squared(),1e-6),0.0,1.0)
	return p.distance_to(a+ab*t)

## Land every veil in the air now, oldest first, where it was promised: a
## new stroke of another brush, an undo or a world change.
func settle_now() -> void:
	release()
	while not clouds.is_empty(): _settle(clouds[0])

## Drop everything, settling nothing: the ground it was promised to is gone.
func withdraw() -> void:
	held = {}
	clouds.clear()
	_sprouts.clear()
	_glints.clear()
	_hide()

## The God Hand throws what is in its palm at `velocity` (plate m/s): each
## mote flies out, scattered a little, and a spring draws it on to its place.
func toss(velocity: Vector3) -> void:
	var all: Array[Dictionary] = clouds.duplicate()
	if not held.is_empty(): all.append(held)
	# Its own dice, not the veil's: a throw never moves where anything lands.
	for veil: Dictionary in all:
		for mote: Dictionary in veil.motes:
			if not mote.has("hand"): continue
			mote.erase("hand")
			var scatter := Vector3(randf_range(-1,1),randf_range(-0.6,1),randf_range(-1,1))
			mote.v = velocity*randf_range(0.75,1.15)+scatter*(velocity.length()*SCATTER.x+SCATTER.y)

## A mote waiting in the hand sits in the handful; with no hand, or after
## HAND_WAIT, it goes by itself, drifting up out of the palm. False once it
## is out.
func _in_hand(mote: Dictionary, delta: float) -> bool:
	if not mote.has("hand"): return false
	mote.hand = float(mote.hand)+delta
	if hand_at == null or float(mote.hand) > HAND_WAIT:
		mote.erase("hand")
		mote.v = Vector3.UP*1.5
		return false
	mote.p = Vector3(hand_at)+Vector3(mote.off)*HANDFUL
	return true

## A thrown mote flies on a spring to `to`; within ARRIVED m, and slow, it
## is back with the veil, which carries it on from there. In a held veil it
## is back after FLIGHT s whatever: a place turning quickly round its knot
## keeps ahead of the spring, as it keeps ahead of the veil's own easing.
func _fly(mote: Dictionary, to: Vector3, delta: float, held_veil := false) -> void:
	var v: Vector3 = mote.v
	var p: Vector3 = mote.p
	v += ((to-p)*FLING_SPRING-v*FLING_DAMP)*delta
	p += v*delta
	mote.p = p
	mote.v = v
	mote.flown = float(mote.get("flown",0.0))+delta
	if (p.distance_squared_to(to) < ARRIVED*ARRIVED and v.length_squared() < 1.0) or (held_veil and float(mote.flown) > FLIGHT):
		mote.erase("v")
		mote.erase("flown")

# --- Laying the veil ------------------------------------------------------------

func _knot_radius(veil: Dictionary, thick: float) -> float:
	return lerpf(CLOUD.x,CLOUD.y,thick)*float(veil.scale)

## Motes knot `k` wants: a lone knot is a click's puff, a sweep's knots a
## thinner run; thickening adds more.
func _knot_target(veil: Dictionary, k: int) -> float:
	var knot: Dictionary = veil.knots[k]
	var base := MOTES.x if veil.knots.size() == 1 else float(KNOT_MOTES)
	return (base+float(knot.thick)*(MOTES.y-MOTES.x))*float(veil.density)

func _sigma(veil: Dictionary, knot: Dictionary, sweep: float) -> float:
	return lerpf(lerpf(SPREAD.x,SPREAD.y,float(knot.thick)),VEIL_SPREAD,sweep)*float(veil.scale)*float(veil.get("spread",1.0))

## The air `veil` drifts on at `p` (plate): the wind (scripts/pollen_wind.gd)
## times the veil's own carry.
func _wind(veil: Dictionary, p: Vector2) -> Vector2:
	return Wind.at(scene,get_parent() as Node3D,p)*float(veil.get("carry",1.0))

## A new knot at `flat` (plate) over ground `ground`, with its motes.
func _lay(veil: Dictionary, flat: Vector2, ground: float) -> void:
	var knots: Array = veil.knots
	var s := 0.0 if knots.is_empty() else float(knots.back().s)+flat.distance_to(_flat(knots.back().p))
	knots.append({"p":Vector3(flat.x,ground,flat.y),"r":_knot_radius(veil,0.0),"thick":0.0,"count":0,"s":s})
	if knots.size() > KNOTS: _merge(veil)
	knots = veil.knots
	var k := knots.size()-1
	_fill(veil,k,roundi(_knot_target(veil,k))-int(knots[k].count))

## Too many knots: merge them in pairs. Each kept knot widens to hold its
## partner's motes where they are, so the promise still holds.
func _merge(veil: Dictionary) -> void:
	var knots: Array = veil.knots
	var kept := []
	for i in range(0,knots.size(),2):
		var knot: Dictionary = knots[i]
		if i+1 < knots.size():
			var other: Dictionary = knots[i+1]
			knot.r = maxf(float(knot.r),float(other.r)+_flat(knot.p).distance_to(_flat(other.p)))
			knot.thick = maxf(float(knot.thick),float(other.thick))
			knot.count = int(knot.count)+int(other.count)
		kept.append(knot)
	for mote: Dictionary in veil.motes:
		var was: Dictionary = knots[mote.k]
		var now: Dictionary = kept[int(mote.k)/2]
		var shift: Vector3 = Vector3(was.p)-Vector3(now.p)
		mote.off = Vector3(mote.off)+Vector3(shift.x,0.0,shift.z)
		mote.k = int(mote.k)/2
	veil.knots = kept
	veil.step = float(veil.step)*2.0

## `count` more motes for knot `k`: taken from knots holding more than they
## want first, then new while the veil is under its cap, then from the knot
## densest for what it wants. They start at the head and ease into place.
func _fill(veil: Dictionary, k: int, count: int) -> void:
	if count <= 0: return
	var knots: Array = veil.knots
	var rng: RandomNumberGenerator = veil.rng
	var motes: Array = veil.motes
	for i in range(count):
		var from := -1
		var best := 1.0
		var spare := false
		for j in range(knots.size()):
			if j == k: continue
			var ratio := float(knots[j].count)/maxf(_knot_target(veil,j),1.0)
			if ratio > best:
				best = ratio
				from = j
		spare = from >= 0
		if not spare and motes.size() >= int(veil.cap):
			# At the cap: the densest part of the veil gives one up.
			best = -1.0
			for j in range(knots.size()):
				if j == k or int(knots[j].count) <= 1: continue
				var ratio := float(knots[j].count)/maxf(_knot_target(veil,j),1.0)
				if ratio > best:
					best = ratio
					from = j
			if from < 0 or float(knots[from].count)/maxf(_knot_target(veil,from),1.0) <= float(knots[k].count+1)/maxf(_knot_target(veil,k),1.0): return
		var slot := _slot(veil,knots[k],rng)
		if from >= 0:
			for mote: Dictionary in motes:
				if int(mote.k) != from: continue
				mote.k = k
				mote.off = slot
				knots[from].count = int(knots[from].count)-1
				break
		else:
			var mote := {"k":k,"off":slot,"p":Vector3(veil.head)+Vector3(rng.randf_range(-0.15,0.15),rng.randf_range(-0.1,0.1),rng.randf_range(-0.15,0.15)),
				"born":float(veil.age),"phase":rng.randf()*TAU,"rate":rng.randf_range(0.3,0.9)*(1.0 if rng.randf() < 0.5 else -1.0),"size":rng.randf_range(0.7,1.3),"landed":false}
			if hand_at != null:
				mote.hand = 0.0
				mote.p = Vector3(hand_at)+slot*HANDFUL
			motes.append(mote)
		knots[k].count = int(knots[k].count)+1

## A place in knot `knot`'s part of the veil: within its half-width across,
## a little up and down.
func _slot(veil: Dictionary, knot: Dictionary, rng: RandomNumberGenerator) -> Vector3:
	var around := rng.randf()*TAU
	var out := sqrt(rng.randf())*float(knot.r)
	return Vector3(cos(around)*out,rng.randf_range(-0.3,0.3)*(0.6+float(knot.thick)),sin(around)*out)

func _process(delta: float) -> void:
	delta = minf(delta,0.05)
	var began := Time.get_ticks_usec()
	age += delta
	if not held.is_empty(): _step_held(delta)
	for cloud: Dictionary in clouds.duplicate(): _step_flying(cloud,delta)
	_step_ground(delta)
	_draw()
	_paint_prints()
	last_usec = Time.get_ticks_usec()-began

func _step_held(delta: float) -> void:
	var veil := held
	veil.age = float(veil.age)+delta
	var goal: Vector3 = Vector3(veil.target)+Vector3.UP*HEIGHT
	var velocity: Vector3 = veil.velocity
	velocity += ((goal-Vector3(veil.head))*FOLLOW-velocity*FOLLOW_DAMP)*delta
	veil.velocity = velocity
	veil.head = Vector3(veil.head)+velocity*delta
	# Lay knots along the head's way, a step apart; never off the land.
	var head := _flat(veil.head)
	var guard := 0
	while guard < 64:
		guard += 1
		var last := _flat(veil.knots.back().p)
		var gap := head.distance_to(last)
		var step: float = veil.step
		if gap < step: break
		var at := last+(head-last)/gap*step
		var ground: float = ground_at.call(at)
		if is_nan(ground): break
		_lay(veil,at,ground)
	var knots: Array = veil.knots
	# Holding still thickens the veil where it is.
	if Vector2(velocity.x,velocity.z).length() < STILL:
		var k := knots.size()-1
		var knot: Dictionary = knots[k]
		if float(knot.thick) < 1.0:
			knot.thick = minf(1.0,float(knot.thick)+delta*float(veil.strength)/HOLD_SECONDS)
			knot.r = maxf(float(knot.r),_knot_radius(veil,float(knot.thick)))
			_fill(veil,k,roundi(_knot_target(veil,k))-int(knot.count))
	# Each mote churns round its place and eases there, so new ones trail;
	# thrown ones fly there, and the hand's wait in its palm.
	var ease := 1.0-exp(-SETTLE_RATE*delta)
	for mote: Dictionary in veil.motes:
		var knot: Dictionary = knots[mote.k]
		if _in_hand(mote,delta): continue
		if mote.has("v"): _fly(mote,_hang(veil,knot,mote),delta,true)
		else: mote.p = Vector3(mote.p).lerp(_hang(veil,knot,mote),ease)

## Where a held mote hangs: its knot, HEIGHT up with a ripple running along the
## veil, its place turning slowly round the knot, billowing.
func _hang(veil: Dictionary, knot: Dictionary, mote: Dictionary) -> Vector3:
	var off: Vector3 = mote.off
	var turn := float(mote.rate)*(float(veil.age)-float(mote.born))*0.5
	var flat := Vector2(off.x,off.z).rotated(turn)
	var phase: float = mote.phase
	var billow := Vector3(sin(age*TAU*BILLOW.y+phase),cos(age*TAU*BILLOW.y*1.3+phase),sin(age*TAU*BILLOW.y*0.7+phase*2.0))*BILLOW.x
	var ripple := sin(age*TAU*BOB.y-float(knot.s)*0.9)*BOB.x
	return Vector3(knot.p)+Vector3(flat.x,HEIGHT+off.y+ripple,flat.y)+billow

# --- The fall -------------------------------------------------------------------

## Knot `knot`'s footprint now: its part's drift so far, carried on by that
## part's wind for the least and the most time its motes have left.
func _ends(veil: Dictionary, knot: Dictionary, at := -1.0) -> Array:
	var g: int = knot.g
	var wind: Vector2 = veil.wind[g]
	var t: float = veil.t if at < 0.0 else minf(at,float(veil.t))
	# Earlier this frame the drift was that much less.
	var here: Vector2 = _flat(knot.p)+Vector2(veil.drift[g])-wind*(float(veil.t)-t)
	return [here+wind*maxf(float(knot.min_t)-t,0.0),here+wind*maxf(float(knot.max_t)-t,0.0)]

func _step_flying(veil: Dictionary, delta: float) -> void:
	veil.age = float(veil.age)+delta
	# The air where each part of the veil is now carries its motes alike.
	var was: float = veil.t
	var before: Array = veil.drift.duplicate()
	for g in range(int(veil.groups)):
		var wind := _wind(veil,Vector2(veil.middles[g])+Vector2(before[g]))
		veil.wind[g] = wind
		veil.drift[g] = Vector2(before[g])+wind*delta
	veil.t = was+delta
	var knots: Array = veil.knots
	for mote: Dictionary in veil.motes:
		if mote.landed: continue
		var knot: Dictionary = knots[mote.k]
		var g: int = knot.g
		var down := float(mote.start)+float(mote.fall)
		if down <= float(veil.t):
			# Down part way through this frame: the drift up to that moment.
			_land(veil,mote,Vector2(mote.base)+Vector2(before[g])+Vector2(veil.wind[g])*(down-was))
			continue
		if _in_hand(mote,delta): continue
		var shown: Vector3 = mote.p
		_place(veil,knot,mote)
		if mote.has("v"):
			var to: Vector3 = mote.p
			mote.p = shown
			_fly(mote,to,delta)
	if int(veil.down) >= veil.motes.size(): _settle(veil)

## A released mote before its fall: the breath (it lifts and gathers in toward
## its knot), then a moment hanging until its part of the veil goes.
func _lifted(knot: Dictionary, mote: Dictionary, t: float) -> Vector3:
	var c := 1.0-pow(1.0-clampf(t/LIFT,0.0,1.0),3.0)
	var from: Vector3 = mote.from
	var gather := (Vector3(knot.p.x,from.y,knot.p.z)-from)*GATHER*c
	return from+gather+Vector3.UP*LIFT_HEIGHT*c

## A mote's way down: after its breath it sinks softly, then steadily, and
## lands gently; it drifts apart from the others early, rides its part's
## drift, and wanders on the curl of the air, the wander dying out as it
## lands. Near the ground it looks ahead to where it will land, so it comes
## down onto the ground there.
func _place(veil: Dictionary, knot: Dictionary, mote: Dictionary) -> void:
	var t: float = veil.t
	var drift: Vector2 = veil.drift[knot.g]
	if t < float(mote.start):
		mote.p = _lifted(knot,mote,t)+Vector3(drift.x,0.0,drift.y)
		return
	var u := clampf((t-float(mote.start))/float(mote.fall),0.0,1.0)
	var from := _lifted(knot,mote,float(mote.start))
	var start := _flat(from)
	var base: Vector2 = mote.base
	var flat := start+(base-start)*(1.0-pow(1.0-u,2.0))+drift
	flat += Vector2(mote.curl).rotated(u*4.0+float(mote.phase))*WANDER*sin(u*PI)
	if not mote.aimed and u > 0.6:
		mote.aimed = true
		var ahead: float = ground_at.call(base+drift+Vector2(veil.wind[knot.g])*(float(mote.start)+float(mote.fall)-t))
		if not is_nan(ahead): mote.floor = ahead
	# It hangs on the air, even rides up a little, before it sinks.
	var sink := 0.35*u*u*(3.0-2.0*u)+0.65*u*u*u
	var y := lerpf(from.y,float(mote.floor),sink)+sin(u*PI)*(1.0-u)*FLOAT*float(mote.size)+sin(u*PI*5.0+float(mote.phase))*0.08*(1.0-u)
	mote.p = Vector3(flat.x,y,flat.y)

## Metres past the footprint `point` lies, in shares of the nearest part's
## radius (1 is on its edge): the least over the veil's knots.
func _share(point: Vector2, capsules: Array) -> float:
	var best := INF
	for capsule: Array in capsules:
		best = minf(best,_to_segment(point,capsule[0],capsule[1])/float(capsule[2]))
	return best

## The footprint's capsules (plate [a, b, radius]) as they stand now, or as
## they stood at `at` seconds since release, earlier this frame.
func _capsules(veil: Dictionary, at := -1.0) -> Array:
	var out := []
	for knot: Dictionary in veil.knots:
		var ends := _ends(veil,knot,at)
		out.append([ends[0],ends[1],float(knot.r)+float(knot.sigma)])
	return out

func _land(veil: Dictionary, mote: Dictionary, point: Vector2) -> void:
	mote.landed = true
	veil.down = int(veil.down)+1
	# Against the footprint as it stood when it landed, and as it was promised
	# at release.
	var share := _share(point,_capsules(veil,float(mote.start)+float(mote.fall)))
	veil.worst = maxf(float(veil.worst),share)
	if share > 1.0001: veil.outside = int(veil.outside)+1
	if _share(point,veil.promised) > 1.0001: veil.outside_promised = int(veil.outside_promised)+1
	var h: float = ground_at.call(point)
	mote.lost = is_nan(h)
	var to := Vector3(point.x,float(mote.floor) if mote.lost else h,point.y)
	mote.p = to
	if mote.lost:
		veil.lost = int(veil.lost)+1
		return
	veil.points.append(point)
	veil.times.append(float(mote.start)+float(mote.fall))
	if _shown(mote): _glints.append({"p":to,"t":0.0,"size":float(mote.size),"colour":veil.colour})
	var seeds: PackedVector2Array = veil.seeds
	for q in seeds:
		if q.distance_squared_to(point) < SEED_GAP*SEED_GAP: return
	seeds.append(point)
	veil.seeds = seeds
	if (veil.takes if veil.has("takes") else takes).call(point):
		_sprouts.append({"p":to,"t":0.0,"yaw":randf()*TAU,"lean":Vector2.RIGHT.rotated(randf()*TAU)})
		if _sprouts.size() > SPROUTS_MAX: _sprouts = _sprouts.slice(_sprouts.size()-SPROUTS_MAX)

## At most `most` of `seeds`, as far apart as they go: the first, then each
## time the one farthest from those kept, so a long sweep keeps seeds all
## along its length rather than at the end that landed first.
static func _spread_out(seeds: PackedVector2Array, most: int) -> PackedVector2Array:
	if seeds.size() <= most: return seeds
	var kept := PackedVector2Array([seeds[0]])
	var gaps := PackedFloat32Array()
	for q in seeds: gaps.append(q.distance_squared_to(seeds[0]))
	while kept.size() < most:
		var best := 0
		for i in range(gaps.size()):
			if gaps[i] > gaps[best]: best = i
		kept.append(seeds[best])
		for i in range(gaps.size()): gaps[i] = minf(gaps[i],seeds[i].distance_squared_to(seeds[best]))
	return kept

## Land what is left of `veil` now, on the drift so far and the present wind,
## and hand it on.
func _settle(veil: Dictionary) -> void:
	for mote: Dictionary in veil.motes:
		if mote.landed: continue
		var g: int = veil.knots[mote.k].g
		_land(veil,mote,Vector2(mote.base)+Vector2(veil.drift[g])+Vector2(veil.wind[g])*maxf(float(mote.start)+float(mote.fall)-float(veil.t),0.0))
	clouds.erase(veil)
	veil.seeds = _spread_out(veil.seeds,SEEDS_MAX)
	var path := PackedVector2Array()
	for knot: Dictionary in veil.knots: path.append(_flat(knot.p))
	var drift := Vector2.ZERO
	for d: Vector2 in veil.drift: drift += d
	settled.emit({"id":veil.id,"seeds":veil.seeds,"points":veil.points,"times":veil.times,"lost":veil.lost,"radius":veil.radius,"motes":veil.motes.size(),
		"path":path,"length":veil.length,"promised":veil.promised,"drift":drift/float(veil.drift.size()),"drifts":veil.drift.duplicate(),"worst":veil.worst,
		"outside":veil.outside,"outside_promised":veil.outside_promised,"kind":veil.get("kind",""),"seconds":veil.t})

func _step_ground(delta: float) -> void:
	var kept: Array[Dictionary] = []
	for glint: Dictionary in _glints:
		glint.t = float(glint.t)+delta
		if float(glint.t) < GLINT: kept.append(glint)
	_glints = kept.slice(maxi(0,kept.size()-MOTES_MAX/2))
	var grown: Array[Dictionary] = []
	for s: Dictionary in _sprouts:
		s.t = float(s.t)+delta
		if float(s.t) < SPROUT_SECONDS: grown.append(s)
	_sprouts = grown

func _flat(p: Vector3) -> Vector2:
	return Vector2(p.x,p.z)

# --- Drawing --------------------------------------------------------------------

## Whether a mote is one of the SHOWN share that is drawn (fixed per mote).
static func _shown(mote: Dictionary) -> bool:
	return fposmod(float(mote.phase)*7.31,1.0) < SHOWN

var _drawn_at := -1.0

func _draw() -> void:
	var plate: Transform3D = (get_parent() as Node3D).global_transform
	var step := age-_drawn_at if _drawn_at >= 0.0 else 0.0
	_drawn_at = age
	var motes := _mote_node.multimesh
	var haze := _haze_node.multimesh
	var n := 0
	var h := 0
	var all: Array[Dictionary] = clouds.duplicate()
	if not held.is_empty(): all.append(held)
	for veil: Dictionary in all:
		var colour: Color = veil.colour
		var flying: bool = veil.state == "flying"
		var knots: Array = veil.knots
		# The haze follows the veil: a puff's few round its middle, a sweep's
		# spaced along it.
		var along: bool = knots.size() >= HAZE
		var buckets := mini(knots.size(),HAZE_VEIL) if along else HAZE
		var groups := []
		for g in range(buckets): groups.append([Vector3.ZERO,0,0.0])
		for i in range(veil.motes.size()):
			var mote: Dictionary = veil.motes[i]
			if mote.landed or n >= MOTES_MAX: continue
			if _shown(mote):
				# A soft speck that glints as it turns, fades in as it joins, and
				# draws out into a wisp along the way it moves.
				var twinkle := 0.7+0.3*sin(age*4.0+float(mote.phase)*3.0)
				var grow := smoothstep(0.0,0.4,float(veil.age)-float(mote.born)) if not flying else 1.0
				var size := SPECK*float(mote.size)*maxf(grow,0.01)
				var world: Vector3 = plate*Vector3(mote.p)
				var seen: Vector3 = mote.get("seen",world)
				var moving: Vector3 = mote.get("moving",Vector3.ZERO)
				if step > 0.0: moving = moving.lerp((world-seen)/step,0.25)
				mote.seen = world
				mote.moving = moving
				motes.set_instance_transform(n,Transform3D(Basis.from_scale(Vector3.ONE*size),mote.p))
				motes.set_instance_color(n,Color(colour.r,colour.g,colour.b,SPECK_ALPHA*twinkle*grow))
				motes.set_instance_custom_data(n,Color(moving.x,moving.y,moving.z,0.0))
				n += 1
			if mote.has("hand"): continue
			var group: Array = groups[int(mote.k)*buckets/knots.size() if along else i%HAZE]
			group[0] += Vector3(mote.p)
			group[1] += 1
			group[2] = maxf(float(group[2]),float(knots[mote.k].r))
		# The haze: soft light over the veil, thinning as it spreads and lands.
		var left := 1.0-float(veil.down)/maxf(veil.motes.size(),1.0) if flying else smoothstep(0.0,0.3,float(veil.age))
		var spread := 1.0+(float(veil.t)*0.25 if flying else 0.0)
		var span := float(knots.back().s)/float(buckets)*0.5 if along else 0.0
		for group: Array in groups:
			if int(group[1]) == 0 or h >= haze.instance_count: continue
			var at: Vector3 = group[0]/float(group[1])
			var size := (float(group[2])+span)*0.9*spread
			haze.set_instance_transform(h,Transform3D(Basis.from_scale(Vector3.ONE*size),at))
			haze.set_instance_color(h,Color(colour.r,colour.g,colour.b,HAZE_GLOW*left/spread))
			h += 1
	for glint: Dictionary in _glints:
		if n >= MOTES_MAX: break
		var t: float = glint.t
		var size := SPECK*0.8*float(glint.size)*(1.0-t/GLINT)
		motes.set_instance_transform(n,Transform3D(Basis.from_scale(Vector3.ONE*maxf(size,0.001)),Vector3(glint.p)+Vector3.UP*0.04))
		var colour: Color = glint.colour
		motes.set_instance_color(n,Color(colour.r,colour.g,colour.b,SPECK_ALPHA*(0.7+0.3*sin(t*18.0))))
		motes.set_instance_custom_data(n,Color(0,0,0,0))
		n += 1
	motes.visible_instance_count = n
	_mote_node.global_transform = plate
	_mote_node.visible = n > 0
	haze.visible_instance_count = h
	_haze_node.global_transform = plate
	_haze_node.visible = h > 0
	var sprouts := _sprout_node.multimesh
	var count := mini(_sprouts.size(),SPROUTS_MAX)
	for i in range(count):
		var s: Dictionary = _sprouts[i]
		var t: float = s.t
		# It pops up past its size, sways back and settles, and sinks away
		# as the forest's own saplings take over.
		var pop := clampf(t/SPROUT_POP,0.0,1.0)-1.0
		var up := (1.0+pop*pop*(2.70158*pop+1.70158))*(1.0-smoothstep(SPROUT_SECONDS-1.2,SPROUT_SECONDS,t))
		var lean: Vector2 = s.lean
		var sway := sin(t*7.0)*0.3*exp(-t*2.2)+sin(age*1.3+float(s.yaw))*0.04
		var basis := Basis(Vector3(lean.x,0,lean.y),sway)*Basis(Vector3.UP,float(s.yaw))
		sprouts.set_instance_transform(i,Transform3D(basis.scaled(Vector3.ONE*SPROUT_SIZE*maxf(up,0.001)),s.p))
		sprouts.set_instance_color(i,Color(1,1,1,0))
	# Shown only once every visible instance has its transform.
	sprouts.visible_instance_count = count
	_sprout_node.global_transform = plate
	_sprout_node.visible = count > 0

## The capsules (plate [a, b, radius]) the held veil would settle into if let
## go now, in the wind as it blows now.
func _held_capsules(veil: Dictionary) -> Array:
	var knots: Array = veil.knots
	var n := knots.size()
	var length: float = knots.back().s
	var groups := clampi(ceili(float(n)/KNOT_GROUP),1,GROUPS)
	var winds := []
	for g in range(groups):
		var middle := _flat(knots[mini(n-1,(2*g+1)*n/(2*groups))].p)
		winds.append(_wind(veil,middle))
	var sweep := clampf(length/SWEEP,0.0,1.0)
	var wave := WAVE*minf(1.0,length/WAVE_LENGTH)
	var out := []
	for k in range(n):
		var knot: Dictionary = knots[k]
		var wind: Vector2 = winds[k*groups/n]
		var delay := LIFT+wave*(length-float(knot.s))/maxf(length,0.001)
		var here := _flat(knot.p)
		out.append([here+wind*(delay+FALL.x),here+wind*(delay+JITTER+FALL.y),float(knot.r)+_sigma(veil,knot,sweep)])
	return out

## Whether the footprints are drawn: off unless --show-promise. The user found
## the landing outlines too many and too hand-holding; the veil drifting in
## the air and the sprouts where it lands say where it went.
var show_prints := "--show-promise" in OS.get_cmdline_user_args()

## The footprints: the aim (a click's under the pointer, or the held veil's)
## and each released veil's until it has settled.
func _paint_prints() -> void:
	if not show_prints:
		for node in _prints: node.visible = false
		return
	var shapes: Array[Dictionary] = []
	var parent := get_parent() as Node3D
	if not held.is_empty():
		shapes.append({"capsules":_held_capsules(held),"strength":smoothstep(0.0,0.15,float(held.age)),"soft":1.0})
	elif _hover != null:
		var wind := Wind.at(scene,parent,_flat(_hover))
		var here := _flat(_hover)
		shapes.append({"capsules":[[here+wind*(LIFT+FALL.x),here+wind*(LIFT+JITTER+FALL.y),(CLOUD.x+SPREAD.x)*_hover_scale]],"strength":0.55,"soft":1.0})
	for veil: Dictionary in clouds:
		var share := float(veil.down)/maxf(veil.motes.size(),1.0)
		shapes.append({"capsules":_capsules(veil),"strength":1.0-smoothstep(0.7,1.0,share),"soft":0.0})
	var scale := parent.global_basis.get_scale().x
	for i in range(_prints.size()):
		var node := _prints[i]
		if i >= shapes.size() or float(shapes[i].strength) <= 0.001:
			node.visible = false
			continue
		var shape: Dictionary = shapes[i]
		var capsules: Array = shape.capsules
		var low := INF
		var high := -INF
		var box := Rect2()
		var ends := PackedVector4Array()
		var radii := PackedFloat32Array()
		# The ground under the ends, read at no more than 16 of them.
		var every := maxi(1,capsules.size()/16)
		for k in range(capsules.size()):
			var capsule: Array = capsules[k]
			var a: Vector2 = capsule[0]
			var b: Vector2 = capsule[1]
			var r: float = capsule[2]
			var reach := Rect2(Vector2(minf(a.x,b.x),minf(a.y,b.y))-Vector2.ONE*(r+0.6),Vector2(absf(b.x-a.x),absf(b.y-a.y))+Vector2.ONE*(r+0.6)*2.0)
			box = reach if k == 0 else box.merge(reach)
			if k%every == 0 or k == capsules.size()-1:
				for q: Vector2 in [a,b]:
					var ground: float = ground_at.call(q)
					if is_nan(ground): continue
					low = minf(low,ground)
					high = maxf(high,ground)
			var wa := parent.to_global(Vector3(a.x,0.0,a.y))
			var wb := parent.to_global(Vector3(b.x,0.0,b.y))
			ends.append(Vector4(wa.x,wa.z,wb.x,wb.z))
			radii.append(r*scale)
		if low == INF:
			node.visible = false
			continue
		var middle := box.get_center()
		var at := parent.to_global(Vector3(middle.x,(low+high)*0.5,middle.y))
		node.global_transform = Transform3D(Basis.from_scale(Vector3(box.size.x*scale,(high-low+8.0)*scale,box.size.y*scale)),at)
		node.visible = true
		var material := node.material_override as ShaderMaterial
		material.set_shader_parameter("ends",ends)
		material.set_shader_parameter("radii",radii)
		material.set_shader_parameter("count",capsules.size())
		material.set_shader_parameter("strength",float(shape.strength))
		material.set_shader_parameter("soft",float(shape.soft))
		material.set_shader_parameter("ceiling",parent.to_global(Vector3(0.0,high+HEIGHT*0.45,0.0)).y)
		material.set_shader_parameter("age",age)

func _hide() -> void:
	if _mote_node == null: return
	_mote_node.visible = false
	_sprout_node.visible = false
	_haze_node.visible = false
	for node in _prints: node.visible = false

# --- Meshes -------------------------------------------------------------------

## The faceted sprout mesh, built once: two-leafed, 1 m tall. Vertex colour
## is a shade of the instance colour; its alpha is how much of the instance's
## glow the face takes.
static func _mesh(which: String) -> Mesh:
	if _meshes.has(which): return _meshes[which]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	_build_sprout(tool)
	tool.generate_normals()
	var mesh := tool.commit()
	_meshes[which] = mesh
	return mesh

static func _face(tool: SurfaceTool, colour: Color, points: Array) -> void:
	# Each face its own vertices, so generate_normals gives flat facets.
	for p: Vector3 in points:
		tool.set_color(colour)
		tool.add_vertex(p)

static func _build_sprout(tool: SurfaceTool) -> void:
	var stem := Color(0.55,0.62,0.34,0.0)
	var leaf := Color(0.48,0.72,0.3,0.0)
	var under := Color(0.4,0.6,0.26,0.0)
	# A three-sided stem, a little bent.
	var low := [Vector3(0.04,0,0),Vector3(-0.02,0,0.035),Vector3(-0.02,0,-0.035)]
	var high := [Vector3(0.05,0.62,0.0),Vector3(0.0,0.62,0.025),Vector3(0.0,0.62,-0.025)]
	for i in range(3):
		var j := (i+1)%3
		_face(tool,stem,[low[i],high[i],high[j]])
		_face(tool,stem,[low[i],high[j],low[j]])
	# Two seed leaves, opened up and out, creased along their middles.
	for side in [1.0,-1.0]:
		var root := Vector3(0.02,0.6,0.0)
		var tip := Vector3(0.02,0.86,0.42*side)
		var edge_a := Vector3(0.16,0.74,0.2*side)
		var edge_b := Vector3(-0.12,0.74,0.2*side)
		var crease := (root+tip)*0.5+Vector3(0,0.035,0)
		_face(tool,leaf,[root,crease,edge_a])
		_face(tool,leaf,[crease,tip,edge_a])
		_face(tool,under,[root,edge_b,crease])
		_face(tool,under,[crease,edge_b,tip])
