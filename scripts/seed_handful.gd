extends Node3D
## A sprinkle of seeds (docs/scenic/brushes.md "Seed sprinkle",
## docs/scenic/handful.md). With forest in hand a press starts seeds pouring
## from a point a little above the pointer, as if shaken from a hand. Holding
## still sprinkles one spot densely; dragging lays a trail of them along the
## path. There is no gathering and no release moment: seeds fall for as long
## as the button is down, at a rate set by the brush's size and strength.
##
## Each seed spins down on its wing, fluttering and swaying with the breeze,
## to a landing point drawn inside the mark under the spout at the moment it
## left (shaders/seed_handful_mark.gdshader). The mark is the promise: a small
## faceted pool straight below the spout. While seeds from a spot are still in
## the air, the mark stays there too, so a quick drag leaves a short trail of
## marks that shrink away as their seeds land. The sway dies out as a seed
## lands, so no seed comes down outside its mark. Where one lands a puff of dust
## rises and, on ground that will take it (`takes`), a sprout pops up and later
## sinks as the forest takes over.
##
## `seed_landed` tells the editor each landing (NativeChunkEditor
## `_seed_landed`, which raises the forest wish round it). `sown` fires once the
## stroke has ended and its last seed is down, which closes the stroke's one
## undo step and hands its seeds to emergence.
##
## `kind` names what is sprinkled (KINDS). Only "forest" is built; a meadow's
## seed or pollen would be another entry: more, lighter seeds that drift longer
## over a wider, softer mark.
##
## Lives under the terrain node, so its coordinates are the plate's. The node
## itself stays at the plate's origin; `spout` is where seeds leave.

## One seed came down at plate point `point` (x, z), inside `mark` (centre x,
## z and radius, plate metres), the mark it was promised when it left.
signal seed_landed(point: Vector2, mark: Vector3)
## The stroke is over and its last seed is down: every landing, in order.
signal sown(points: PackedVector2Array)

## What can be sprinkled, by `kind`:
## - `rate`: seeds a second at strength 1 and REFERENCE_RADIUS;
## - `mark`: the mark's radius as a share of the brush radius;
## - `drop`: metres from the ground to the spout;
## - `fall`: seconds a seed takes to come down (drawn per seed);
## - `flutter`: metres a seed sways to the side at mid-fall;
## - `spin`: radians a second a winged seed turns as it falls;
## - `size`: metres from the seed's nut to its wing tip;
## - `glow`: how much the wings shine of their own, so the seeds read as
##   specks of light at the diorama's distance.
const KINDS := {
	"forest":{"rate":9.0,"mark":0.3,"drop":0.8,"fall":Vector2(0.38,0.58),"flutter":0.12,"spin":Vector2(10.0,16.0),"size":0.22,"glow":0.3},
}
## Wing colours by the family of the stand's trees (Emergence `seed_family`);
## the nut is the wing's colour at NUT_SHADE. A pine's dark nut and tan wing,
## a maple's green-gold key, a birch's pale scale, a desert seed's dust.
const LOOKS := {"conifer":"c9a066","broadleaf":"b4bd55","birch":"e3d6a3","arid":"d6bd86"}
const FAMILY := {"tree":"conifer","redwood":"conifer","juniper":"conifer","broadleaf":"broadleaf","layered_tree":"broadleaf",
	"willow":"broadleaf","birch":"birch","joshua":"arid","cactus":"arid"}
const NUT_SHADE := 0.42
## Brush radius (m) the KINDS rate is for; a wider brush sprinkles more, by
## area. The mark is never under MARK_MIN metres.
const REFERENCE_RADIUS := 3.6
const MARK_MIN := 0.5
## Seeds in the air at once, at most; the spout waits for room.
const AIR_MAX := 48
## The spout's follow spring (1/s²) and damping (1/s), a touch under
## critical, so it keeps close behind the pointer (about 0.06 m per m/s) and
## settles with the smallest overshoot. Stepped at most FOLLOW_STEP s at a time.
const FOLLOW := 900.0
const FOLLOW_DAMP := 55.0
const FOLLOW_STEP := 1.0/240.0
## The spout's shake: metres and hertz of its jiggle while it pours.
const SHAKE := Vector2(0.03,5.0)
## A new mark is laid when the spout has moved this share of the mark radius
## from the last; at most MARKS stand at once (the shader's `marks` array).
const MARK_STEP := 0.5
const MARKS := 24
## Seconds a spent mark takes to shrink away once its last seed is down, and
## the spout's mark to come in and go.
const MARK_FADE := 0.3
const MARK_IN := 0.15
## Landing points fill a mark to this share of its radius, so each seed and
## its puff lie inside it.
const INSIDE := 0.85
## Seeds leave the spout with a little toss (m up) and scatter (m round it).
const TOSS := 0.12
const SCATTER := 0.08
## The breeze a falling seed drifts on (m at mid-fall); it too dies out at
## the landing.
const BREEZE := 0.08
## Puff motes per landing and their life (s); the sprout's pop (s), its life
## (s), height (m), and the room (m) it needs from another sprout, so a dense
## spot shows a patch of sprouts, not a heap.
const MOTES := 4
const MOTE_SECONDS := 0.45
const SPROUT_POP := 0.35
const SPROUT_SECONDS := 9.0
const SPROUT_SIZE := 0.3
const SPROUT_ROOM := 0.35
## Landing rings the mark shader draws at once (its `landings` array).
const LANDINGS := 32
const SPROUTS_MAX := 128
const MOTES_MAX := 192

## "idle", "pouring" (the button is down) or "settling" (seeds still falling).
var state := "idle"
var kind := "forest"
## The spout (plate), its velocity, and the pointer's ground point.
var spout := Vector3.ZERO
var velocity := Vector3.ZERO
var target := Vector3.ZERO
var mark_radius := MARK_MIN
var age := 0.0
## The family of seed carried (LOOKS).
var family := "broadleaf"
## The editor's ground: plate x, z -> height. And whether a seed landing
## there will take root (a sprout shows).
var ground_at: Callable = func(_p: Vector2) -> float: return 0.0
var takes: Callable = func(_p: Vector2) -> bool: return true
## The world's wind direction (plate x, z), set by the editor; zero draws one.
var wind := Vector2.ZERO
## Seeds sprinkled and landed this stroke.
var dropped := 0
var landed_points := PackedVector2Array()
## Microseconds the last frame's step took, the editor's landings included
## (for probes).
var last_usec := 0
## Seeds in the air: {"p", "v", "from", "to", "t", "fall", "sway", "phase",
## "flutter", "spin", "tilt", "turn", "size", "colour", "mark"}.
var _seeds: Array[Dictionary] = []
## Marks: {"c" (plate x, z), "r", "pending", "fade" (-1 while in use)}.
var _marks: Array[Dictionary] = []
var _sprouts: Array[Dictionary] = []
var _motes: Array[Dictionary] = []
var _rate := 9.0
var _owed := 0.0
var _shown := 0.0
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
	_seed_node = _instances("Seeds",_mesh("seed"),AIR_MAX,material)
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

## Start pouring over `point` (plate, on the ground), sprinkling `carry`
## (KINDS) for a brush of `brush_radius` m at `strength`. `tree_kind` is the
## stand's tree there (Emergence `seed_family`), "" for the default look;
## `salt` seeds the draws.
func begin(point: Vector3, carry: String, brush_radius: float, strength: float, tree_kind: String, salt: int) -> void:
	# Seeds of an earlier stroke still in the air land first.
	settle_now()
	kind = carry if KINDS.has(carry) else "forest"
	var spec: Dictionary = KINDS[kind]
	state = "pouring"
	var reach := maxf(brush_radius,0.5)
	mark_radius = maxf(MARK_MIN,reach*float(spec.mark))
	_rate = float(spec.rate)*maxf(strength,0.05)*pow(reach/REFERENCE_RADIUS,2.0)
	# The first seed leaves at once, so a tap still sows.
	_owed = 1.0
	family = FAMILY.get(tree_kind,"broadleaf")
	_rng.seed = salt
	_breeze = wind.normalized() if wind.length() > 0.01 else Vector2.RIGHT.rotated(_rng.randf()*TAU)
	target = point
	spout = point+Vector3.UP*float(spec.drop)
	velocity = Vector3.ZERO
	dropped = 0
	landed_points.clear()
	_marks.clear()
	_seed_node.visible = true
	_mark_node.visible = true

## Follow the pointer's ground point (plate), or hold still over null.
func aim(point: Variant) -> void:
	if state == "pouring" and point != null: target = point

## The button came up: no more seeds leave; those in the air land.
func end() -> void:
	if state != "pouring": return
	state = "settling"
	if _seeds.is_empty(): _finish()

## True while pouring or while seeds are still in the air.
func active() -> bool:
	return state != "idle"

func seeds_in_air() -> int:
	return _seeds.size()

## The spout's point on the ground (plate).
func spout_point() -> Vector3:
	return Vector3(spout.x,ground_at.call(Vector2(spout.x,spout.z)),spout.z)

## Land every seed in the air now, where it was promised, and close the
## stroke: a new press, an undo or a world change.
func settle_now() -> void:
	if state == "idle": return
	state = "settling"
	for s: Dictionary in _seeds.duplicate(): _land(s)
	_seeds.clear()
	_finish()

## Drop everything, landing nothing: the ground it was promised to is gone
## (an undo, a load, a new world).
func withdraw() -> void:
	state = "idle"
	_seeds.clear()
	_marks.clear()
	_sprouts.clear()
	_motes.clear()
	_shown = 0.0
	_hide()

func _process(delta: float) -> void:
	delta = minf(delta,0.05)
	if state == "idle" and _motes.is_empty() and _sprouts.is_empty() and _marks.is_empty() and _shown <= 0.0:
		if _mark_node.visible or _sprout_node.visible: _hide()
		return
	var began := Time.get_ticks_usec()
	age += delta
	_shown = move_toward(_shown,1.0 if state == "pouring" else 0.0,delta/MARK_IN)
	if state == "pouring": _pour(delta)
	_fall(delta)
	_step_marks(delta)
	_step_motes(delta)
	_step_sprouts(delta)
	_draw()
	_paint_mark()
	last_usec = Time.get_ticks_usec()-began

## The spout follows the pointer and seeds leave it at the stroke's rate.
func _pour(delta: float) -> void:
	var spec: Dictionary = KINDS[kind]
	var goal := target+Vector3.UP*float(spec.drop)
	var steps := ceili(delta/FOLLOW_STEP)
	for i in range(steps):
		velocity += ((goal-spout)*FOLLOW-velocity*FOLLOW_DAMP)*(delta/steps)
		spout += velocity*(delta/steps)
	_owed = minf(_owed+_rate*delta,4.0)
	while _owed >= 1.0 and _seeds.size() < AIR_MAX:
		_owed -= 1.0
		_sprinkle()

## One seed leaves the spout, promised a point inside the mark below it.
func _sprinkle() -> void:
	var spec: Dictionary = KINDS[kind]
	var mark := _current_mark()
	var centre: Vector2 = mark.c
	var angle := _rng.randf()*TAU
	var reach := float(mark.r)*INSIDE*sqrt(_rng.randf())
	var at := (centre+Vector2(cos(angle),sin(angle))*reach).clamp(Vector2(-13.9,-13.9),Vector2(13.9,13.9))
	var shake := Vector3(sin(age*TAU*SHAKE.y),0.0,cos(age*TAU*SHAKE.y*1.3))*SHAKE.x
	var from := spout+shake+Vector3(_rng.randf_range(-1,1),0.0,_rng.randf_range(-1,1))*SCATTER
	mark.pending = int(mark.pending)+1
	var shade := _rng.randf_range(0.88,1.1)
	_seeds.append({"p":from,"v":Vector3.ZERO,"from":from,"to":Vector3(at.x,ground_at.call(at),at.y),"t":0.0,
		"fall":_rng.randf_range(spec.fall.x,spec.fall.y),"sway":Vector2.RIGHT.rotated(_rng.randf()*TAU),"phase":_rng.randf()*TAU,
		"flutter":_rng.randf_range(1.6,2.8),"spin":_rng.randf_range(spec.spin.x,spec.spin.y)*(1.0 if _rng.randf() < 0.5 else -1.0),
		"tilt":_rng.randf_range(0.25,0.5),"turn":_rng.randf()*TAU,"size":_rng.randf_range(0.85,1.15),
		"colour":Color(LOOKS[family])*shade,"mark":mark})
	dropped += 1

## The mark under the spout: the newest while the spout is still over it,
## else a new one; when MARKS stand already, the newest serves.
func _current_mark() -> Dictionary:
	var here := Vector2(spout.x,spout.z)
	if not _marks.is_empty():
		var last: Dictionary = _marks.back()
		if Vector2(last.c).distance_to(here) < mark_radius*MARK_STEP or _marks.size() >= MARKS:
			return last
	var mark := {"c":here,"r":mark_radius,"pending":0,"fade":-1.0}
	_marks.append(mark)
	return mark

## Seeds spin down on their wings, fluttering; each lands on its point.
func _fall(delta: float) -> void:
	var spec: Dictionary = KINDS[kind]
	var kept: Array[Dictionary] = []
	for s: Dictionary in _seeds:
		s.t = float(s.t)+delta
		var u := clampf(float(s.t)/float(s.fall),0.0,1.0)
		var from: Vector3 = s.from
		var to: Vector3 = s.to
		# Out a little early, then a steady fall after the toss.
		var flat := Vector2(from.x,from.z).lerp(Vector2(to.x,to.z),1.0-pow(1.0-u,1.8))
		# Flutter and breeze die out at the landing, so it lands on its point.
		var life := sin(u*PI)
		var sway: Vector2 = Vector2(s.sway)*sin(float(s.t)*TAU*float(s.flutter)*0.5+float(s.phase))*float(spec.flutter)
		flat += (sway+_breeze*BREEZE)*life
		var y := lerpf(from.y,to.y,_fall_curve(u))+TOSS*sin(PI*clampf(u/0.35,0.0,1.0))*(1.0-u)
		var next := Vector3(flat.x,y,flat.y)
		s.v = (next-Vector3(s.p))/maxf(delta,0.001)
		s.p = next
		s.turn = float(s.turn)+float(s.spin)*smoothstep(0.0,0.3,u)*delta
		if u >= 1.0: _land(s)
		else: kept.append(s)
	_seeds = kept
	if state == "settling" and _seeds.is_empty(): _finish()

## Accelerates, then falls at a steady rate: the seed's wing catches the air.
func _fall_curve(u: float) -> float:
	const A := 0.3
	return (u*u/(2.0*A) if u < A else u-A*0.5)/(1.0-A*0.5)

func _land(s: Dictionary) -> void:
	var to: Vector3 = s.to
	s.p = to
	var point := Vector2(to.x,to.z)
	landed_points.append(point)
	var mark: Dictionary = s.mark
	mark.pending = int(mark.pending)-1
	# A ring on the mark, a puff of dust, and a sprout where it will take and
	# there is room.
	_landings[_landing_next] = Vector4(to.x,to.z,age,1.0)
	_landing_next = (_landing_next+1)%LANDINGS
	for i in range(MOTES):
		var out := Vector3.RIGHT.rotated(Vector3.UP,TAU*(float(i)+_rng.randf())/MOTES)
		_motes.append({"p":to+Vector3.UP*0.03,"v":out*_rng.randf_range(0.4,0.9)+Vector3.UP*_rng.randf_range(0.5,1.0),"t":0.0,"size":_rng.randf_range(0.025,0.045)})
	if _motes.size() > MOTES_MAX: _motes = _motes.slice(_motes.size()-MOTES_MAX)
	if _room_for_sprout(to) and takes.call(point):
		_sprouts.append({"p":to,"t":0.0,"yaw":_rng.randf()*TAU,"lean":Vector2.RIGHT.rotated(_rng.randf()*TAU)})
		if _sprouts.size() > SPROUTS_MAX: _sprouts = _sprouts.slice(_sprouts.size()-SPROUTS_MAX)
	seed_landed.emit(point,Vector3(Vector2(mark.c).x,Vector2(mark.c).y,float(mark.r)))

func _room_for_sprout(p: Vector3) -> bool:
	for other: Dictionary in _sprouts:
		if float(other.t) < SPROUT_SECONDS-1.2 and Vector3(other.p).distance_squared_to(p) < SPROUT_ROOM*SPROUT_ROOM: return false
	return true

func _finish() -> void:
	state = "idle"
	sown.emit(landed_points.duplicate())

## A mark with no seed left to land shrinks away; the one the spout is over
## stays while it pours.
func _step_marks(delta: float) -> void:
	var kept: Array[Dictionary] = []
	for i in range(_marks.size()):
		var mark: Dictionary = _marks[i]
		var over := state == "pouring" and i == _marks.size()-1
		if int(mark.pending) > 0 or over:
			mark.fade = -1.0
		else:
			mark.fade = maxf(float(mark.fade),0.0)+delta
			if float(mark.fade) >= MARK_FADE: continue
		kept.append(mark)
	_marks = kept

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
	var count := mini(_seeds.size(),AIR_MAX)
	seeds.visible_instance_count = count
	_seed_node.global_transform = plate
	_seed_node.visible = count > 0
	for i in range(count):
		var s: Dictionary = _seeds[i]
		# A falling samara turns about the upright on its tilted wing, and
		# rocks as it flutters; it pops out of the spout.
		var rock := sin(float(s.t)*TAU*float(s.flutter)+float(s.phase))*0.25
		var basis := Basis(Vector3.UP,float(s.turn))*Basis(Vector3.RIGHT,float(s.tilt)+rock)
		var grow := smoothstep(0.0,0.08,float(s.t))
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

## The marks: the one under the spout, and any a quick drag left behind with
## seeds still in the air over them, shrinking away once theirs are down.
func _paint_mark() -> void:
	var parent := get_parent() as Node3D
	var scale := parent.global_basis.get_scale().x
	var shapes := PackedVector4Array()
	shapes.resize(MARKS)
	var low := Vector2(INF,INF)
	var high := -low
	var floor_y := -INF
	var n := 0
	for i in range(_marks.size()):
		var mark: Dictionary = _marks[i]
		var c: Vector2 = mark.c
		var size := 1.0 if float(mark.fade) < 0.0 else 1.0-smoothstep(0.0,MARK_FADE,float(mark.fade))
		if i == _marks.size()-1 and state == "pouring": size *= smoothstep(0.0,1.0,_shown)
		if size <= 0.001: continue
		var world := parent.to_global(Vector3(c.x,ground_at.call(c),c.y))
		shapes[n] = Vector4(world.x,world.z,float(mark.r)*scale,size)
		n += 1
		low = low.min(c-Vector2.ONE*float(mark.r))
		high = high.max(c+Vector2.ONE*float(mark.r))
		floor_y = maxf(floor_y,world.y)
	_mark_node.visible = n > 0 or not _motes.is_empty()
	if n == 0 and _motes.is_empty(): return
	if n == 0:
		low = Vector2(spout.x,spout.z)-Vector2.ONE
		high = low+Vector2.ONE*2.0
		floor_y = parent.to_global(spout_point()).y
	var middle := (low+high)*0.5
	var span := (high-low)*0.5+Vector2.ONE*0.6
	var at := parent.to_global(Vector3(middle.x,ground_at.call(middle),middle.y))
	_mark_node.global_transform = Transform3D(Basis.from_scale(Vector3(span.x*2.0*scale,8.0*scale,span.y*2.0*scale)),at)
	_mark_material.set_shader_parameter("marks",shapes)
	_mark_material.set_shader_parameter("count",n)
	_mark_material.set_shader_parameter("pouring",1.0 if state == "pouring" else 0.0)
	_mark_material.set_shader_parameter("ceiling",floor_y+float(KINDS[kind].drop)*0.5*scale)
	_mark_material.set_shader_parameter("age",age)
	var rings := PackedVector4Array()
	rings.resize(LANDINGS)
	for i in range(LANDINGS):
		var ring := _landings[i]
		if ring.w < 0.5: continue
		var p := parent.to_global(Vector3(ring.x,0.0,ring.y))
		rings[i] = Vector4(p.x,p.z,ring.z,1.0)
	_mark_material.set_shader_parameter("landings",rings)

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
