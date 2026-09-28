extends Node3D
## A handful of seeds (docs/scenic/brushes.md "Seed handful"). With forest in
## hand a press gathers a small cloud of winged seeds above the ground, and
## holding draws more in from the air, up to a full handful. The mark on the
## ground under it (shaders/seed_handful_mark.gdshader) widens with it. The
## mark is the promise: it lies straight below the handful, not along the sun,
## and every seed lands inside it.
##
## The cloud follows the pointer on a spring, and each seed trails its own
## place in the cloud on a looser spring of its own, so a quick pull stretches
## the cloud and a stop sloshes it past and back. It breathes, bobs and churns
## while held. Release squeezes it (the anticipation), then tosses the seeds up
## and lets them spill, lowest first. Each spins down on its wing, fluttering
## and swaying with the breeze, to a landing point drawn inside the mark at
## release; the sway dies out as it lands, so no seed comes down outside.
## Where one lands a puff of dust rises and, on ground that will take it
## (`takes`), a sprout pops up and later sinks as the forest takes over.
##
## `seed_landed` tells the editor each landing (NativeChunkEditor
## `_seed_landed`, which raises the forest wish round it) and `sown` the last,
## which closes the handful's one undo step and hands the seeds to emergence.
##
## `kind` names what the handful carries (KINDS). Only "forest" is built; a
## meadow's seed or pollen would be another entry: more, lighter seeds that
## drift longer over a wider, softer mark.
##
## Lives under the terrain node, so its coordinates are the plate's. The node
## itself stays at the plate's origin; `center` is the cloud's middle.

## One seed came down at plate point `point` (x, z).
signal seed_landed(point: Vector2)
## Every seed of the handful is down: their points, and the mark's centre and
## radius (plate metres).
signal sown(points: PackedVector2Array, center: Vector2, mark_radius: float)

## What a handful can carry, by `kind`:
## - `seeds`: how many an empty and a full handful hold at REFERENCE_RADIUS;
## - `mark`: the mark's radius as a share of the brush radius, empty to full;
## - `fall`: seconds a seed takes to come down (drawn per seed);
## - `flutter`: metres a seed sways to the side at mid-fall;
## - `spin`: radians a second a winged seed turns as it falls;
## - `size`: metres from the seed's nut to its wing tip;
## - `glow`: how much the wings shine of their own, so the cloud reads as
##   specks of light at the diorama's distance.
const KINDS := {
	"forest":{"seeds":Vector2(4,18),"mark":Vector2(0.35,1.0),"fall":Vector2(1.1,1.8),"flutter":0.3,"spin":Vector2(9.0,15.0),"size":0.22,"glow":0.3},
}
## Wing colours by the family of the stand's trees (Emergence `seed_family`);
## the nut is the wing's colour at NUT_SHADE. A pine's dark nut and tan wing,
## a maple's green-gold key, a birch's pale scale, a desert seed's dust.
const LOOKS := {"conifer":"c9a066","broadleaf":"b4bd55","birch":"e3d6a3","arid":"d6bd86"}
const FAMILY := {"tree":"conifer","redwood":"conifer","juniper":"conifer","broadleaf":"broadleaf","layered_tree":"broadleaf",
	"willow":"broadleaf","birch":"birch","joshua":"arid","cactus":"arid"}
const NUT_SHADE := 0.42
## Brush radius (m) the KINDS seed counts are for. A wider brush carries more,
## by area, up to SEEDS_MAX; the mark is never under MARK_MIN metres.
const REFERENCE_RADIUS := 3.6
const SEEDS_MAX := 64
const MARK_MIN := 0.9
## Seconds of holding, at strength 1, from an empty handful to a full one.
const GATHER_SECONDS := 2.4
## Metres from the ground to the cloud's middle while held.
const HOVER := 1.5
## The cloud's radius (m), empty to full, and its breathing (share, hertz).
const CLOUD := Vector2(0.2,0.55)
const BREATHE := Vector2(0.07,0.6)
## Metres and hertz of the idle bob.
const BOB := 0.07
const BOB_RATE := 0.5
## The follow spring (1/s²) and damping (1/s), a little under critical, so the
## cloud overshoots and settles behind a quick pointer.
const FOLLOW := 55.0
const FOLLOW_DAMP := 10.0
## Each seed's spring to its place in the cloud: looser, so seeds trail a
## pull and slosh past a stop (overlap and follow-through).
const SEED_FOLLOW := 70.0
const SEED_DAMP := 7.0
## Radians a second the seeds circle the cloud's middle, and how much faster
## per m/s the cloud moves; how far (m) the cloud stretches per m/s.
const CHURN := 1.1
const CHURN_SPEED := 0.6
const STRETCH := 0.08
## Seconds a new handful takes to gather (with an overshoot), and the metres
## out a new seed is drawn in from.
const GATHER_IN := 0.3
const DRAW_FROM := Vector2(0.7,1.5)
## Release: seconds of the squeeze, how far it squeezes, the dip (m), and the
## toss (m) seeds rise before they fall.
const WIND_UP := 0.12
const SQUEEZE := 0.55
const DIP := 0.12
const TOSS := 0.3
## Seconds over which the seeds leave the cloud, the lowest first.
const SPILL := 0.3
## Landing points fill the mark to this share of its radius, so each seed
## and its puff lie inside it.
const INSIDE := 0.88
## The breeze a falling seed drifts on (m at mid-fall); it too dies out at
## the landing.
const BREEZE := 0.2
## Puff motes per landing and their life (s); the sprout's pop (s), its life
## (s) and height (m).
const MOTES := 5
const MOTE_SECONDS := 0.55
const SPROUT_POP := 0.35
const SPROUT_SECONDS := 9.0
const SPROUT_SIZE := 0.3
## Seconds the mark takes to fade once the last seed is down.
const MARK_FADE := 0.8
## Landing rings the mark shader draws at once (its `landings` array).
const LANDINGS := 32
const SPROUTS_MAX := 128
const MOTES_MAX := 256

## "idle", "holding", "winding" (the release squeeze) or "sowing".
var state := "idle"
var kind := "forest"
## 0 (just gathered) to 1 (a full handful).
var fill := 0.0
## The mark: its centre (plate x, z) and radius (m). While held it follows
## the cloud; at release it stays where the seeds will land.
var mark_center := Vector2.ZERO
var mark_radius := MARK_MIN
## The cloud's middle (plate), its velocity, and the pointer's ground point.
var center := Vector3.ZERO
var velocity := Vector3.ZERO
var target := Vector3.ZERO
var age := 0.0
## The family of seed carried (LOOKS).
var family := "broadleaf"
## The editor's ground: plate x, z -> height. And whether a seed landing
## there will take root (a sprout shows).
var ground_at: Callable = func(_p: Vector2) -> float: return 0.0
var takes: Callable = func(_p: Vector2) -> bool: return true
## The world's wind direction (plate x, z), set by the editor; zero draws one.
var wind := Vector2.ZERO
## Every seed's landing so far this handful, in landing order.
var landed_points := PackedVector2Array()
## Microseconds the last frame's step took, the editor's landings included
## (for probes).
var last_usec := 0
## Seeds: {"p", "v", "a" (angle in the cloud), "r", "h", "rate", "axis",
## "tumble", "turn", "size", "colour", and once released: "from", "to",
## "t", "fall", "sway", "phase", "flutter", "spin", "tilt", "done"}.
var _seeds: Array[Dictionary] = []
var _sprouts: Array[Dictionary] = []
var _motes: Array[Dictionary] = []
var _brush_radius := REFERENCE_RADIUS
var _strength := 1.0
var _churn := 0.0
var _wind_t := 0.0
var _mark_fade := -1.0
var _breeze := Vector2.ZERO
var _landings := PackedVector4Array()
var _landing_next := 0
var _rng := RandomNumberGenerator.new()
var _seed_node: MultiMeshInstance3D
var _sprout_node: MultiMeshInstance3D
var _mote_node: MultiMeshInstance3D
var _mark_node: MeshInstance3D
var _mark_material: ShaderMaterial
static var _meshes := {}

func _ready() -> void:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/seed_handful.gdshader")
	_seed_node = _instances("Seeds",_mesh("seed"),SEEDS_MAX,material)
	_sprout_node = _instances("Sprouts",_mesh("sprout"),SPROUTS_MAX,material)
	_mote_node = _instances("Motes",_mesh("mote"),MOTES_MAX,material)
	_mark_material = ShaderMaterial.new()
	_mark_material.shader = preload("res://shaders/seed_handful_mark.gdshader")
	_mark_material.render_priority = -1
	_mark_node = MeshInstance3D.new()
	_mark_node.name = "Mark"
	_mark_node.mesh = BoxMesh.new()
	_mark_node.material_override = _mark_material
	_mark_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mark_node.top_level = true
	add_child(_mark_node)
	_landings.resize(LANDINGS)
	_hide()

func _instances(title: String, mesh: Mesh, count: int, material: Material) -> MultiMeshInstance3D:
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_colors = true
	instances.instance_count = count
	instances.visible_instance_count = 0
	instances.mesh = mesh
	var node := MultiMeshInstance3D.new()
	node.name = title
	node.multimesh = instances
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.top_level = true
	add_child(node)
	return node

## Start a handful over `point` (plate, on the ground) carrying `carry`
## (KINDS), for a brush of `brush_radius` m at `strength`. `tree_kind` is the
## stand's tree there (Emergence `seed_family`), "" for the default look;
## `salt` seeds the draws.
func gather(point: Vector3, carry: String, brush_radius: float, strength: float, tree_kind: String, salt: int) -> void:
	# Seeds of an earlier handful still in the air land first.
	settle_now()
	kind = carry if KINDS.has(carry) else "forest"
	state = "holding"
	age = 0.0
	fill = 0.0
	_churn = 0.0
	_brush_radius = maxf(brush_radius,0.5)
	_strength = maxf(strength,0.05)
	family = FAMILY.get(tree_kind,"broadleaf")
	_rng.seed = salt
	target = point
	center = point+Vector3.UP*HOVER
	velocity = Vector3.ZERO
	mark_center = Vector2(point.x,point.z)
	mark_radius = _mark_for(0.0)
	_mark_fade = -1.0
	_seeds.clear()
	landed_points.clear()
	for i in range(_count_for(0.0)): _add_seed()
	_seed_node.visible = true
	_mark_node.visible = true

## Follow the pointer's ground point (plate), or hold still over null.
func hold(point: Variant) -> void:
	if state == "holding" and point != null: target = point

## Let go: a squeeze, then the seeds spill and drift down inside the mark.
func release() -> void:
	if state != "holding": return
	state = "winding"
	_wind_t = 0.0
	velocity = Vector3(0.0,velocity.y,0.0)
	mark_center = Vector2(center.x,center.z)
	_plan_landings()

## True while a handful is held or its seeds are still in the air.
func active() -> bool:
	return state != "idle"

## The number of seeds held or in the air.
func seed_count() -> int:
	return _seeds.size()

## The mark's centre on the ground (plate).
func mark_point() -> Vector3:
	return Vector3(mark_center.x,ground_at.call(mark_center),mark_center.y)

## Land every seed still held or in the air now, where it was promised: a
## new press, an undo or a world change closes the handful at once.
func settle_now() -> void:
	if state == "holding": release()
	if state == "idle": return
	if state == "winding": _spill()
	for s: Dictionary in _seeds:
		if not s.done: _land(s)
	_finish()

## Drop everything, landing nothing: the ground it was promised to is gone
## (an undo, a load, a new world).
func withdraw() -> void:
	state = "idle"
	_seeds.clear()
	_sprouts.clear()
	_motes.clear()
	_mark_fade = -1.0
	_hide()

func _mark_for(amount: float) -> float:
	var share: Vector2 = KINDS[kind].mark
	return maxf(MARK_MIN,_brush_radius*lerpf(share.x,share.y,sqrt(amount)))

func _count_for(amount: float) -> int:
	var seeds: Vector2 = KINDS[kind].seeds
	var area := pow(_brush_radius/REFERENCE_RADIUS,2.0)
	return clampi(roundi(lerpf(seeds.x,seeds.y*area,amount)),int(seeds.x),SEEDS_MAX)

## 0 to 1 over GATHER_IN, with an overshoot (ease out back).
func _gathered() -> float:
	var t := clampf(age/GATHER_IN,0.0,1.0)-1.0
	return 1.0+t*t*(2.70158*t+1.70158)

func _cloud_radius() -> float:
	return lerpf(CLOUD.x,CLOUD.y,sqrt(fill))*_gathered()*(1.0+BREATHE.x*sin(age*TAU*BREATHE.y))

## A seed joins the cloud, drawn in from the air round it with a curl.
func _add_seed() -> void:
	var up := _rng.randf_range(-0.7,0.7)
	var around := _rng.randf()*TAU
	var out := Vector3(cos(around)*sqrt(1.0-up*up),up,sin(around)*sqrt(1.0-up*up))
	var from := _rng.randf_range(DRAW_FROM.x,DRAW_FROM.y)*(0.4 if age <= 0.0 else 1.0)
	var curl := out.cross(Vector3.UP).normalized()*_rng.randf_range(0.8,1.8)
	var shade := _rng.randf_range(0.88,1.1)
	_seeds.append({"p":center+out*from,"v":curl,"a":_rng.randf()*TAU,"r":sqrt(_rng.randf_range(0.1,1.0)),"h":_rng.randf_range(-0.55,0.55),
		"rate":_rng.randf_range(0.7,1.35),"axis":Vector3(_rng.randf_range(-1,1),_rng.randf_range(-1,1),_rng.randf_range(-1,1)).normalized(),
		"tumble":_rng.randf_range(1.5,3.5),"turn":_rng.randf()*TAU,"size":_rng.randf_range(0.85,1.15),
		"colour":Color(LOOKS[family])*shade,"done":false})

func _process(delta: float) -> void:
	delta = minf(delta,0.05)
	if state == "idle" and _motes.is_empty() and _sprouts.is_empty() and _mark_fade < 0.0:
		if _mark_node.visible or _sprout_node.visible: _hide()
		return
	var began := Time.get_ticks_usec()
	age += delta
	match state:
		"holding": _step_held(delta)
		"winding": _step_wind(delta)
		"sowing": _step_sow(delta)
	if _mark_fade >= 0.0:
		_mark_fade += delta
		if _mark_fade >= MARK_FADE: _mark_fade = -1.0
	_step_motes(delta)
	_step_sprouts(delta)
	_draw()
	_paint_mark()
	last_usec = Time.get_ticks_usec()-began

func _step_held(delta: float) -> void:
	fill = minf(1.0,fill+delta*_strength/GATHER_SECONDS)
	mark_radius = _mark_for(fill)
	while _seeds.size() < _count_for(fill): _add_seed()
	var bob := sin(age*TAU*BOB_RATE)*BOB
	var goal := target+Vector3.UP*(HOVER+bob)
	velocity += ((goal-center)*FOLLOW-velocity*FOLLOW_DAMP)*delta
	center += velocity*delta
	# The mark lies straight below the cloud, where its seeds would land.
	mark_center = Vector2(center.x,center.z)
	_churn += (CHURN+velocity.length()*CHURN_SPEED)*delta
	_hold_seeds(delta,1.0)

## Seeds chase their places in the cloud: circling its middle at their own
## pace, the cloud stretched along its motion.
func _hold_seeds(delta: float, squeeze: float) -> void:
	var r := _cloud_radius()*squeeze
	var speed := velocity.length()
	var shape := Basis.IDENTITY
	if speed > 0.05: shape = _stretched(velocity/speed,clampf(speed*STRETCH,0.0,0.6))
	for s: Dictionary in _seeds:
		if s.done or s.has("from"): continue
		var angle: float = float(s.a)+_churn*float(s.rate)
		var reach: float = s.r
		var place := shape*(Vector3(cos(angle)*reach,float(s.h)*0.8,sin(angle)*reach)*r)
		var v: Vector3 = s.v
		v += ((center+place-Vector3(s.p))*SEED_FOLLOW-v*SEED_DAMP)*delta
		s.v = v
		s.p = Vector3(s.p)+v*delta
		s.turn = float(s.turn)+float(s.tumble)*delta

## The release squeeze: the cloud draws in and dips, then the seeds spill.
func _step_wind(delta: float) -> void:
	_wind_t += delta
	var t := clampf(_wind_t/WIND_UP,0.0,1.0)
	var ease := t*t*(3.0-2.0*t)
	var goal := Vector3(mark_center.x,ground_at.call(mark_center)+HOVER-DIP*ease,mark_center.y)
	velocity += ((goal-center)*FOLLOW*2.0-velocity*FOLLOW_DAMP)*delta
	center += velocity*delta
	_churn += CHURN*(1.0+ease)*delta
	_hold_seeds(delta,lerpf(1.0,SQUEEZE,ease))
	if _wind_t >= WIND_UP: _spill()

## Landing points for every seed, inside the mark: a sunflower spiral with a
## little jitter covers the disc evenly, and seeds pair with points round the
## circle in order, so the cloud fans outward instead of crossing over.
func _plan_landings() -> void:
	var n := _seeds.size()
	var inside := mark_radius*INSIDE
	var points: Array[Vector2] = []
	var turn := _rng.randf()*TAU
	for i in range(n):
		var angle := turn+float(i)*2.39996+_rng.randf_range(-0.35,0.35)
		var reach := inside*sqrt(clampf((float(i)+0.5+_rng.randf_range(-0.4,0.4))/float(n),0.0,1.0))
		var p := mark_center+Vector2(cos(angle),sin(angle))*minf(reach,inside)
		points.append(p.clamp(Vector2(-13.9,-13.9),Vector2(13.9,13.9)))
	var by_angle := func(a: Vector2, b: Vector2) -> bool: return (a-mark_center).angle() < (b-mark_center).angle()
	points.sort_custom(by_angle)
	var order := range(n)
	order.sort_custom(func(a: int, b: int) -> bool:
		return (Vector2(_seeds[a].p.x,_seeds[a].p.z)-mark_center).angle() < (Vector2(_seeds[b].p.x,_seeds[b].p.z)-mark_center).angle())
	var spec: Dictionary = KINDS[kind]
	# The breeze: the world's wind where the editor tells it, else a draw.
	_breeze = wind.normalized() if wind.length() > 0.01 else Vector2.RIGHT.rotated(_rng.randf()*TAU)
	for k in range(n):
		var s: Dictionary = _seeds[order[k]]
		var at: Vector2 = points[k]
		s.to = Vector3(at.x,ground_at.call(at),at.y)
		s.fall = _rng.randf_range(spec.fall.x,spec.fall.y)
		s.sway = Vector2.RIGHT.rotated(_rng.randf()*TAU)
		s.phase = _rng.randf()*TAU
		s.flutter = _rng.randf_range(1.4,2.6)
		s.spin = _rng.randf_range(spec.spin.x,spec.spin.y)*(1.0 if _rng.randf() < 0.5 else -1.0)
		s.tilt = _rng.randf_range(0.25,0.5)

## The seeds leave the cloud, the lowest first.
func _spill() -> void:
	state = "sowing"
	var low := INF
	var high := -INF
	for s: Dictionary in _seeds:
		low = minf(low,float(s.p.y))
		high = maxf(high,float(s.p.y))
	for s: Dictionary in _seeds:
		s.t = -SPILL*(float(s.p.y)-low)/maxf(high-low,0.001)-_rng.randf()*0.04

func _step_sow(delta: float) -> void:
	var spec: Dictionary = KINDS[kind]
	# The emptied cloud's middle eases down after its seeds.
	velocity *= exp(-6.0*delta)
	center += velocity*delta
	# Seeds not yet away loosen from the squeeze toward the rim.
	_hold_seeds(delta,1.15)
	var waiting := false
	for s: Dictionary in _seeds:
		if s.done: continue
		s.t = float(s.t)+delta
		if float(s.t) < 0.0:
			waiting = true
			continue
		if not s.has("from"): s.from = s.p
		var u := clampf(float(s.t)/float(s.fall),0.0,1.0)
		var from: Vector3 = s.from
		var to: Vector3 = s.to
		# It fans out early and settles into a steady fall, after a toss.
		var out := 1.0-pow(1.0-u,2.2)
		var flat := Vector2(from.x,from.z).lerp(Vector2(to.x,to.z),out)
		# Flutter and breeze die out at the landing, so it lands on its point.
		var life := sin(u*PI)
		var sway: Vector2 = Vector2(s.sway)*sin(float(s.t)*TAU*float(s.flutter)*0.5+float(s.phase))*float(spec.flutter)
		flat += (sway+_breeze*BREEZE)*life
		var y := lerpf(from.y,to.y,_fall_curve(u))+TOSS*sin(PI*clampf(u/0.3,0.0,1.0))*(1.0-u)
		var next := Vector3(flat.x,y,flat.y)
		s.v = (next-Vector3(s.p))/maxf(delta,0.001)
		s.p = next
		s.turn = float(s.turn)+float(s.spin)*smoothstep(0.0,0.35,u)*delta
		if u >= 1.0: _land(s)
		else: waiting = true
	if not waiting: _finish()

## Accelerates, then falls at a steady rate: the seed's wing catches the air.
func _fall_curve(u: float) -> float:
	const A := 0.3
	return (u*u/(2.0*A) if u < A else u-A*0.5)/(1.0-A*0.5)

func _land(s: Dictionary) -> void:
	s.done = true
	var to: Vector3 = s.to
	s.p = to
	var point := Vector2(to.x,to.z)
	landed_points.append(point)
	# A ring on the mark, a puff of dust, and a sprout where it will take.
	_landings[_landing_next] = Vector4(to.x,to.z,age,1.0)
	_landing_next = (_landing_next+1)%LANDINGS
	for i in range(MOTES):
		var out := Vector3.RIGHT.rotated(Vector3.UP,TAU*(float(i)+_rng.randf())/MOTES)
		_motes.append({"p":to+Vector3.UP*0.03,"v":out*_rng.randf_range(0.5,1.1)+Vector3.UP*_rng.randf_range(0.6,1.2),"t":0.0,"size":_rng.randf_range(0.03,0.05)})
	if _motes.size() > MOTES_MAX: _motes = _motes.slice(_motes.size()-MOTES_MAX)
	if takes.call(point):
		_sprouts.append({"p":to,"t":0.0,"yaw":_rng.randf()*TAU,"lean":Vector2.RIGHT.rotated(_rng.randf()*TAU)})
		if _sprouts.size() > SPROUTS_MAX: _sprouts = _sprouts.slice(_sprouts.size()-SPROUTS_MAX)
	seed_landed.emit(point)

func _finish() -> void:
	state = "idle"
	_seeds.clear()
	_mark_fade = 0.0
	sown.emit(landed_points.duplicate(),mark_center,mark_radius)

func _step_motes(delta: float) -> void:
	var kept: Array[Dictionary] = []
	for m: Dictionary in _motes:
		m.t = float(m.t)+delta
		if float(m.t) >= MOTE_SECONDS: continue
		var v: Vector3 = m.v
		v.y -= 3.0*delta
		v *= exp(-2.5*delta)
		m.v = v
		m.p = Vector3(m.p)+v*delta
		kept.append(m)
	_motes = kept

func _step_sprouts(delta: float) -> void:
	var kept: Array[Dictionary] = []
	for s: Dictionary in _sprouts:
		s.t = float(s.t)+delta
		if float(s.t) < SPROUT_SECONDS: kept.append(s)
	_sprouts = kept

func _draw() -> void:
	var plate: Transform3D = (get_parent() as Node3D).global_transform
	var spec: Dictionary = KINDS[kind]
	var size: float = spec.size
	var glow: float = spec.glow
	var seeds := _seed_node.multimesh
	var count := mini(_seeds.size(),SEEDS_MAX)
	seeds.visible_instance_count = count
	_seed_node.global_transform = plate
	for i in range(count):
		var s: Dictionary = _seeds[i]
		var basis: Basis
		if s.has("from") and not s.done:
			# A falling samara turns about the upright on its tilted wing, and
			# rocks as it flutters.
			var rock := sin(float(s.t)*TAU*float(s.flutter)+float(s.phase))*0.25
			basis = Basis(Vector3.UP,float(s.turn))*Basis(Vector3.RIGHT,float(s.tilt)+rock)
		else:
			basis = Basis(Vector3(s.axis),float(s.turn))
		var grow := _gathered() if state == "holding" else 1.0
		seeds.set_instance_transform(i,Transform3D(basis.scaled(Vector3.ONE*size*float(s.size)*maxf(grow,0.01)),s.p))
		var colour: Color = s.colour
		seeds.set_instance_color(i,Color(colour.r,colour.g,colour.b,glow))
	var sprouts := _sprout_node.multimesh
	count = mini(_sprouts.size(),SPROUTS_MAX)
	sprouts.visible_instance_count = count
	_sprout_node.global_transform = plate
	_sprout_node.visible = count > 0
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
	var motes := _mote_node.multimesh
	count = mini(_motes.size(),MOTES_MAX)
	motes.visible_instance_count = count
	_mote_node.global_transform = plate
	_mote_node.visible = count > 0
	for i in range(count):
		var m: Dictionary = _motes[i]
		var left := 1.0-float(m.t)/MOTE_SECONDS
		motes.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ONE*float(m.size)*left),m.p))
		motes.set_instance_color(i,Color(0.86,0.8,0.64,0.15))

## The mark: straight under the cloud while held, where the seeds will land
## once they are loose, fading once the last is down.
func _paint_mark() -> void:
	var shown := 0.0
	if state == "holding": shown = smoothstep(0.0,GATHER_IN,age)
	elif state != "idle": shown = 1.0
	elif _mark_fade >= 0.0: shown = 1.0-smoothstep(0.0,MARK_FADE,_mark_fade)
	_mark_node.visible = shown > 0.001 or not _motes.is_empty()
	var parent := get_parent() as Node3D
	var scale := parent.global_basis.get_scale().x
	var floor_y: float = ground_at.call(mark_center)
	var span := (mark_radius*1.25+0.6)*scale
	var at := parent.to_global(Vector3(mark_center.x,floor_y,mark_center.y))
	_mark_node.global_transform = Transform3D(Basis.from_scale(Vector3(span*2.0,8.0*scale,span*2.0)),at)
	_mark_material.set_shader_parameter("mark_center",at)
	_mark_material.set_shader_parameter("mark_radius",mark_radius*scale)
	_mark_material.set_shader_parameter("shown",shown)
	_mark_material.set_shader_parameter("sowing",1.0 if state in ["winding","sowing"] else 0.0)
	_mark_material.set_shader_parameter("ceiling",at.y+HOVER*0.6*scale)
	_mark_material.set_shader_parameter("age",age)
	var world := PackedVector4Array()
	world.resize(LANDINGS)
	for i in range(LANDINGS):
		var ring := _landings[i]
		if ring.w < 0.5:
			continue
		var p := parent.to_global(Vector3(ring.x,floor_y,ring.y))
		world[i] = Vector4(p.x,p.z,ring.z,1.0)
	_mark_material.set_shader_parameter("landings",world)

## A volume-keeping stretch by `stretch` along the unit vector `along`.
func _stretched(along: Vector3, stretch: float) -> Basis:
	var side := along.cross(Vector3.UP if absf(along.y) < 0.95 else Vector3.RIGHT).normalized()
	var third := along.cross(side)
	var frame := Basis(side,along,third)
	var thin := 1.0/sqrt(1.0+stretch)
	return frame*Basis.from_scale(Vector3(thin,1.0+stretch,thin))*frame.transposed()

func _hide() -> void:
	if _mark_node == null: return
	_mark_node.visible = false
	_seed_node.visible = false
	_sprout_node.visible = false
	_mote_node.visible = false
	_seed_node.multimesh.visible_instance_count = 0
	_landings.fill(Vector4.ZERO)

# --- Meshes -------------------------------------------------------------------

## The faceted meshes, built once: a winged seed (a samara: a nut at the root
## of one veined wing, 1 m nut to tip, so the instance scale is its length),
## a two-leafed sprout (1 m tall) and a dust mote (1 m radius). Vertex colour
## is a shade of the instance colour; its alpha is how much of the instance's
## glow the face takes (the wing's, not the nut's).
static func _mesh(which: String) -> Mesh:
	if _meshes.has(which): return _meshes[which]
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	match which:
		"seed": _build_seed(tool)
		"sprout": _build_sprout(tool)
		_: _build_mote(tool)
	tool.generate_normals()
	var mesh := tool.commit()
	_meshes[which] = mesh
	return mesh

static func _face(tool: SurfaceTool, colour: Color, points: Array) -> void:
	# Each face its own vertices, so generate_normals gives flat facets.
	for p: Vector3 in points:
		tool.set_color(colour)
		tool.add_vertex(p)

static func _build_seed(tool: SurfaceTool) -> void:
	var nut := Color(NUT_SHADE,NUT_SHADE,NUT_SHADE,0.0)
	# The nut: a small faceted lozenge at the root.
	var tips := [Vector3(-0.1,0,0),Vector3(0.14,0,0)]
	var ring := [Vector3(0.02,0.06,0),Vector3(0.02,0,0.08),Vector3(0.02,-0.05,0),Vector3(0.02,0,-0.08)]
	for i in range(4):
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[(i+1)%4]
		_face(tool,nut,[tips[0],a,b])
		_face(tool,nut,[tips[1],b,a])
	# The wing: a veined blade, creased along its vein, broad past the middle.
	var vein := [Vector3(0.1,0.02,0),Vector3(0.4,0.035,0.02),Vector3(0.72,0.03,0.03),Vector3(1.0,0.0,0.02)]
	var lead := [Vector3(0.1,0.0,0.05),Vector3(0.38,0.0,0.17),Vector3(0.74,0.0,0.18),Vector3(1.0,0.0,0.02)]
	var trail := [Vector3(0.1,0.0,-0.03),Vector3(0.42,0.0,-0.09),Vector3(0.76,0.0,-0.06),Vector3(1.0,0.0,0.02)]
	var light := Color(1.0,1.0,1.0,1.0)
	var shade := Color(0.86,0.86,0.8,1.0)
	for i in range(3):
		_face(tool,light,[vein[i],lead[i],lead[i+1]])
		if i < 2: _face(tool,light,[vein[i],lead[i+1],vein[i+1]])
		_face(tool,shade,[vein[i],trail[i+1],trail[i]])
		if i < 2: _face(tool,shade,[vein[i],vein[i+1],trail[i+1]])

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

static func _build_mote(tool: SurfaceTool) -> void:
	var dust := Color(1,1,1,1)
	var points := [Vector3(0,1,0),Vector3(1,0,0),Vector3(0,0,1),Vector3(-1,0,0),Vector3(0,0,-1),Vector3(0,-1,0)]
	for i in range(4):
		var a: Vector3 = points[1+i]
		var b: Vector3 = points[1+(i+1)%4]
		_face(tool,dust,[points[0],b,a])
		_face(tool,dust,[points[5],a,b])
