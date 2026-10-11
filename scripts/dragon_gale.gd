extends Node3D
## The sky dragon's gale on a far isle (docs/design/rim-dragon.md, round 4):
## everything the isle does while the dragon (scripts/sky_dragon.gd) clings
## to its rim, drawn big enough to read from the aqueduct isle 150 to 300 m
## off. One node, top level, world space; the dragon drives it.
##
##   streaks   round 1's wind streaks (scripts/rim_dragon.gd `_spawn`), a
##             few times its size: drawn into the mouth on the inhale, poured
##             out across the isle and on into the sky on the blow;
##   lanes     the wind tool's own air for foliage (zs_blow_*, read by every
##             plant's shader through zs_blow_at; scripts/wind_gust.gd is its
##             owner elsewhere, the aqueduct isle has none), fired over and
##             over along the blast so the isle's trees thrash, and toward
##             the mouth on the inhale so they lean in first: the tell;
##   debris    leaves and twigs torn off the turf and flung out;
##   rubble    stone breaking off the rim, tumbling down into the clouds;
##   puffs     soft billboards: dust on the slam, and the cloud sea beyond
##             churned up into a wake along the blast;
##   sag       the isle itself (its node: turf, rock, plants and collision
##             all under it) dragged down at the gripped rim and tipped
##             toward the dragon under its weight, groaning while held and
##             sinking deeper with each blast; let go, it snaps back on the
##             edge spring's damped spring (scripts/diorama_flip.gd
##             `_step_dip`), runs on past rest, recoils, wobbles and
##             settles, and rubble, dust and leaves jump loose (round 5).

const STREAKS := 280
const DEBRIS := 360
const RUBBLE := 120
const PUFFS := 220
## The wind tool's lanes (shaders/reference_wind.gdshaderinc zs_blow_at).
const LANES := 4

var isle: Node3D
var isle_rest := Transform3D.IDENTITY
var isle_shape: RefCounted
var isle_home := Vector3.ZERO
var isle_radius := 16.0
var sea_y := -108.0
var _rng := RandomNumberGenerator.new()

var _streaks: MultiMeshInstance3D
var _debris: MultiMeshInstance3D
var _rubble: MultiMeshInstance3D
var _puffs: MultiMeshInstance3D
var _s: Array = []
var _d: Array = []
var _r: Array = []
var _p: Array = []
var _s_next := 0
var _d_next := 0
var _r_next := 0
var _p_next := 0
var _s_acc := 0.0
var _d_acc := 0.0
var _r_acc := 0.0
var _p_acc := 0.0
## The sag (round 5): metres the gripped rim stands under its rest (up is
## less), and its speed. A share of it is the isle dropping whole, the rest
## the isle tipping about its middle toward the dragon.
const SAG_DROP := 0.3
## The grip: on the slam the rim sags SLAM_SAG m, kicked down at SLAM_KICK
## m/s, on a heavy soft spring (HOLD_W 1/s, HOLD_ZETA), so it drops, bobs
## and hangs; each blast sinks it BLAST_SAG m more, to SAG_MOST.
const SLAM_SAG := 4.5
const SLAM_KICK := 7.0
const BLAST_SAG := 0.8
const SAG_MOST := 7.5
const HOLD_W := 3.2
const HOLD_ZETA := 0.3
## The groan while held: a slow creak in the sag (m) and a lean either way.
const GROAN := 0.28
## The snap: the edge spring's release (scripts/diorama_flip.gd `_step_dip`:
## DIP_RISE_W 26, DIP_RISE_ZETA 0.5, then RECOIL_W 40 once past rest), its
## maths as is, its rates scaled to a 36 m isle sagging metres rather than
## a plate dipping one (SNAP_SCALE): at 26 1/s the rim would come up at
## some 70 m/s and fling the pilot 100 m high. The recoil runs at the
## editor's ratio to the rise but softer than its critical damping, so the
## isle wobbles a few times before it settles.
const SNAP_SCALE := 0.4
const DIP_RISE_W := 26.0
const DIP_RISE_ZETA := 0.5
const RECOIL_W := 40.0
const RECOIL_ZETA := 0.32
const REST := 0.01
const REST_SPEED := 0.02
const SUBSTEP := 1.0/240.0
var sag := 0.0
var sag_v := 0.0
## "" (at rest), "held" or "snap"; the snap past rest yet; its time.
var phase := ""
var _crossed := false
var _snap_t := 0.0
var _hold_sag := 0.0
var _rim_r := 16.0
var _toward := Vector3.FORWARD
var _tremble := 0.0
var _tilt_axis := Vector3.RIGHT
var _shaking := false
## The isle's move this frame (world, now from before) and its pose before.
var moved := Transform3D.IDENTITY
var before := Transform3D.IDENTITY
## True for the frame the snap comes up through rest.
var snapped := false
## The lanes: each {a, b, c, age, run} or empty.
var _lanes: Array = []
var _lane_next := 0
var _lane_acc := 0.0
var _published := false
var _clock := 0.0

func _init() -> void:
	name = "DragonGale"
	top_level = true
	_rng.seed = 41

func _ready() -> void:
	_streaks = _batch("Streaks",_streak_mesh(),STREAKS)
	_debris = _batch("Debris",_leaf_mesh(),DEBRIS)
	_rubble = _batch("Rubble",_rock_mesh(),RUBBLE)
	_puffs = _batch("Puffs",_puff_mesh(),PUFFS)
	for i in range(STREAKS): _s.append({"life":0.0})
	for i in range(DEBRIS): _d.append({"life":0.0})
	for i in range(RUBBLE): _r.append({"life":0.0})
	for i in range(PUFFS): _p.append({"life":0.0})
	for i in range(LANES): _lanes.append({})

func _exit_tree() -> void:
	_settle_now()
	if _published:
		for i in range(LANES): _publish_lane(i,{})

func _batch(label: String, mesh: Mesh, count: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = count
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.extra_cull_margin = 2000.0
	add_child(node)
	var hidden := Transform3D(Basis.from_scale(Vector3.ONE*0.0001),Vector3(0.0,-9000.0,0.0))
	for i in range(count):
		mm.set_instance_transform(i,hidden)
		mm.set_instance_custom_data(i,Color(0,0,0,0))
		mm.set_instance_color(i,Color.WHITE)
	return node

# --- Meshes ---------------------------------------------------------------------------

## Round 1's streak: a pale soft quad along x, faded by custom.r.
static func _streak_mesh() -> Mesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0,1.0)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled, fog_disabled;
varying float fade;
void vertex() { fade = INSTANCE_CUSTOM.r; }
void fragment() {
	float along = sin(UV.x * 3.14159);
	float head = mix(0.55, 1.0, UV.x);
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	ALBEDO = vec3(0.95, 0.97, 1.0);
	ALPHA = clamp(fade * along * head * across * across * 0.7, 0.0, 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = shader
	quad.material = m
	return quad

## A leaf: a small two-sided quad, its colour per instance.
static func _leaf_mesh() -> Mesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0,0.6)
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.8
	m.backlight_enabled = true
	m.backlight = Color(0.25,0.3,0.12)
	quad.material = m
	return quad

## A broken stone: a low-poly lump in the isles' basalt.
static func _rock_mesh() -> Mesh:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 0.8
	mesh.radial_segments = 5
	mesh.rings = 2
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	mesh.material = m
	return mesh

## A soft round puff facing the camera (dust, cloud): alpha by custom.r,
## its colour per instance, a little lit from above.
static func _puff_mesh() -> Mesh:
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0,1.0)
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
varying float fade;
varying vec3 tint;
void vertex() {
	fade = INSTANCE_CUSTOM.r;
	tint = COLOR.rgb;
	// Face the camera, the instance's scale kept.
	float s = length(MODEL_MATRIX[0].xyz);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(s, 0.0, 0.0, 0.0), vec4(0.0, s, 0.0, 0.0), vec4(0.0, 0.0, s, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float r = length(c);
	float lumps = 0.12 * sin(atan(c.y, c.x) * 5.0 + fade * 3.0);
	float a = 1.0 - smoothstep(0.35 + lumps, 1.0, r);
	ALBEDO = tint * mix(0.82, 1.08, clamp(0.5 - c.y * 0.5, 0.0, 1.0));
	ALPHA = clamp(a * fade, 0.0, 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = shader
	quad.material = m
	return quad

# --- The isle ---------------------------------------------------------------------------

## The isle the dragon has hold of: its node (moved to shake it), its shape
## (where its land is), its home and radius.
## `toward` (flat, unit) the way out to the dragon, `rim` its grip.
func hold_isle(node: Node3D, shape: RefCounted, home: Vector3, radius: float, toward: Vector3, rim := Vector3.INF) -> void:
	var same := node != null and node == isle
	if not same:
		_settle_now()
		isle = node if node != null and is_instance_valid(node) else null
		if isle != null: isle_rest = isle.transform
		sag = 0.0
		sag_v = 0.0
	isle_shape = shape
	isle_home = home
	isle_radius = radius
	_toward = toward
	_tilt_axis = Vector3(-toward.z,0.0,toward.x).normalized()
	_rim_r = maxf(Vector2(rim.x-home.x,rim.z-home.z).length(),6.0) if rim != Vector3.INF else radius
	_hold_sag = 0.0
	phase = "held"

## Let go of the isle: it snaps back up past rest, recoils, wobbles and
## settles home.
func release_isle() -> void:
	if phase != "held": return
	phase = "snap"
	_crossed = false
	_snap_t = 0.0
	_hold_sag = 0.0

## The isle home at once (a new hold, leaving the tree).
func _settle_now() -> void:
	if isle != null and is_instance_valid(isle) and _shaking: isle.transform = isle_rest
	_shaking = false
	phase = ""
	sag = 0.0
	sag_v = 0.0

## A blast's weight: the rim sinks a little deeper.
func deepen() -> void:
	if phase != "held": return
	_hold_sag = minf(_hold_sag+BLAST_SAG,SAG_MOST)
	sag_v += 2.0
	_tremble = maxf(_tremble,0.6)

## The slam: the rim is dragged down and the isle tips toward the dragon,
## dust bursts off the rim, rubble breaks away and falls.
func slam(rim: Vector3, out: Vector3, tangent: Vector3) -> void:
	sag_v += SLAM_KICK
	_tremble = 1.0
	_hold_sag = SLAM_SAG
	for i in range(26):
		var along := _rng.randf_range(-14.0,14.0)
		var at := rim+tangent*along+out*_rng.randf_range(-1.0,3.0)+Vector3.UP*_rng.randf_range(-3.0,1.0)
		_puff(at,out*_rng.randf_range(2.0,7.0)+Vector3.UP*_rng.randf_range(-1.0,4.0)+tangent*along*0.15,_rng.randf_range(4.0,8.0),_rng.randf_range(10.0,18.0),_rng.randf_range(2.6,4.2),Color(0.62,0.58,0.55))
	for i in range(34): crumble(rim,out,tangent,16.0)

## A few stones off the rim near `rim` (`spread` m either side).
func crumble(rim: Vector3, out: Vector3, tangent: Vector3, spread: float) -> void:
	var at := rim+tangent*_rng.randf_range(-spread,spread)+out*_rng.randf_range(-0.5,2.0)-Vector3.UP*_rng.randf_range(0.0,6.0)
	var s := {"p":at,"v":out*_rng.randf_range(1.0,5.0)+tangent*_rng.randf_range(-2.0,2.0)+Vector3.UP*_rng.randf_range(-1.0,3.0),
		"spin":Vector3(_rng.randf_range(-3,3),_rng.randf_range(-3,3),_rng.randf_range(-3,3)),"rot":Basis(),
		"size":_rng.randf_range(0.7,2.8),"life":9.0,"age":0.0}
	_r[_r_next] = s
	var c := _rng.randf_range(0.22,0.36)
	_rubble.multimesh.set_instance_color(_r_next,Color(c,c*0.95,c*1.05))
	_r_next = (_r_next+1)%RUBBLE

## A blast's tremble through the isle.
func shake(amount: float) -> void:
	_tremble = maxf(_tremble,amount)

## The snap's kick (the frame it comes up through rest): stone, dust and
## leaves jump off the turf with the isle's way up, and more rubble off the
## rim it had hold of.
func jolt(rim: Vector3, out: Vector3, tangent: Vector3, up: float) -> void:
	_tremble = 1.0
	for i in range(40):
		var at := _on_isle()
		if at == Vector3.INF: continue
		var near := clampf(1.0-(at-rim).length()/(_rim_r*2.0),0.2,1.0)
		var v := Vector3.UP*up*near*_rng.randf_range(0.5,1.0)+Vector3(_rng.randf_range(-2,2),0.0,_rng.randf_range(-2,2))
		if i%3 == 0:
			var s := {"p":at,"v":v,"spin":Vector3(_rng.randf_range(-5,5),_rng.randf_range(-5,5),_rng.randf_range(-5,5)),"rot":Basis(),
				"size":_rng.randf_range(0.4,1.2),"life":9.0,"age":0.0}
			_r[_r_next] = s
			var c := _rng.randf_range(0.24,0.38)
			_rubble.multimesh.set_instance_color(_r_next,Color(c,c*0.95,c*1.05))
			_r_next = (_r_next+1)%RUBBLE
		else: _leaf(at,v*0.8)
		if i%2 == 0: _puff(at,v*0.25,_rng.randf_range(2.5,5.0),_rng.randf_range(8.0,14.0),_rng.randf_range(2.0,3.4),Color(0.66,0.62,0.56))
	for i in range(18):
		crumble(rim,out,tangent,16.0)
		var last := (_r_next-1+RUBBLE)%RUBBLE
		_r[last].v = (_r[last].v as Vector3)+Vector3.UP*up*_rng.randf_range(0.4,0.9)

# --- The breath -----------------------------------------------------------------------

## The inhale (the tell), `mouth` and its way (flat, unit): streaks drawn
## in from ahead, and the isle's trees leaning in toward it.
func inhale(mouth: Vector3, way: Vector3, delta: float) -> void:
	_s_acc += delta*70.0
	while _s_acc >= 1.0:
		_s_acc -= 1.0
		var dir := way.rotated(Vector3.UP,_rng.randf_range(-0.5,0.5))
		dir.y = _rng.randf_range(-0.25,0.15)
		var start := mouth+dir.normalized()*_rng.randf_range(35.0,85.0)
		_streak(start,(mouth-start).normalized()*_rng.randf_range(30.0,42.0),_rng.randf_range(1.4,2.0),_rng.randf_range(8.0,16.0),_rng.randf_range(0.6,1.0))
	_lane_acc += delta
	if _lane_acc >= 0.55:
		_lane_acc = 0.0
		_fire_lane(mouth+way*60.0,-way,0.9,58.0,0.55,20.0)

## The blow, from `mouth` along `way` (flat, unit), `strength` 0..1 (its
## envelope): streaks pouring out across the isle, the trees thrashing,
## leaves torn off, stone shaken loose, the cloud sea beyond churned.
func blow(mouth: Vector3, way: Vector3, strength: float, delta: float) -> void:
	if strength <= 0.01: return
	var side := Vector3(-way.z,0.0,way.x)
	_s_acc += delta*150.0*strength
	while _s_acc >= 1.0:
		_s_acc -= 1.0
		var dir := way.rotated(Vector3.UP,_rng.randf_range(-0.32,0.32))
		dir.y = _rng.randf_range(-0.16,0.06)
		dir = dir.normalized()
		var from := mouth+dir*_rng.randf_range(3.0,10.0)+Vector3.UP*_rng.randf_range(-3.0,2.0)
		_streak(from,dir*_rng.randf_range(50.0,72.0),_rng.randf_range(1.8,2.8),_rng.randf_range(16.0,34.0),_rng.randf_range(0.9,1.7))
	# The trees: lane after lane along the blast.
	_lane_acc += delta
	if _lane_acc >= 0.32:
		_lane_acc = 0.0
		_fire_lane(mouth,way,0.85,80.0,1.35*strength,26.0)
	# Leaves and twigs off the turf it crosses.
	_d_acc += delta*95.0*strength
	while _d_acc >= 1.0:
		_d_acc -= 1.0
		var at := _on_isle()
		if at == Vector3.INF: break
		var push := way*_rng.randf_range(22.0,40.0)+side*_rng.randf_range(-6.0,6.0)+Vector3.UP*_rng.randf_range(4.0,13.0)
		_leaf(at,push)
	# Stone shaken off the rim now and then.
	_r_acc += delta*3.0*strength
	# The cloud sea beyond: churned up and thrown along in a wake.
	_p_acc += delta*24.0*strength
	while _p_acc >= 1.0:
		_p_acc -= 1.0
		var far := _rng.randf_range(70.0,420.0)
		# The cloud tops under the isles (the sea's towers stand well above
		# its floor): some 80 m under the mouth, sinking with distance.
		var top := maxf(mouth.y-80.0-far*0.08,sea_y)
		var at := Vector3(mouth.x,top,mouth.z)+way*far+side*_rng.randf_range(-1.0,1.0)*(18.0+far*0.22)+Vector3.UP*_rng.randf_range(-6.0,14.0)
		var size := _rng.randf_range(16.0,34.0)*(0.8+far/420.0*0.6)
		_puff(at,way*_rng.randf_range(14.0,26.0)+Vector3.UP*_rng.randf_range(3.0,9.0),size,size*_rng.randf_range(1.6,2.3),_rng.randf_range(5.5,8.5),Color(0.97,0.97,1.0))
	_tremble = maxf(_tremble,0.35*strength)

## Whether stone breaks off this frame (the dragon asks, with where).
func take_crumble() -> bool:
	if _r_acc >= 1.0:
		_r_acc -= 1.0
		return true
	return false

## A random point on the held isle's land (world), or INF.
func _on_isle() -> Vector3:
	for k in range(6):
		var a := _rng.randf()*TAU
		var r := sqrt(_rng.randf())*isle_radius*1.1
		var p := Vector2(cos(a)*r,sin(a)*r)
		if isle_shape != null:
			if not isle_shape.on_land(p): continue
			var local := Vector3(p.x,float(isle_shape.ground_at(p))+0.6,p.y)
			if isle != null: return isle.global_transform*local
			return isle_home+local
		return isle_home+Vector3(p.x,0.6,p.y)
	return Vector3.INF

func _streak(p: Vector3, v: Vector3, life: float, length: float, width: float) -> void:
	_s[_s_next] = {"p":p,"v":v,"life":life,"age":0.0,"len":length,"w":width}
	_s_next = (_s_next+1)%STREAKS

func _leaf(p: Vector3, v: Vector3) -> void:
	_d[_d_next] = {"p":p,"v":v,"life":_rng.randf_range(4.0,7.0),"age":0.0,"size":_rng.randf_range(0.5,1.3),
		"rot":Basis(),"spin":Vector3(_rng.randf_range(-9,9),_rng.randf_range(-9,9),_rng.randf_range(-9,9))}
	var g := _rng.randf()
	var c := Color(0.30,0.42,0.16) if g < 0.55 else (Color(0.48,0.50,0.20) if g < 0.8 else Color(0.40,0.30,0.18))
	_debris.multimesh.set_instance_color(_d_next,c)
	_d_next = (_d_next+1)%DEBRIS

func _puff(p: Vector3, v: Vector3, size: float, grow: float, life: float, tint: Color) -> void:
	_p[_p_next] = {"p":p,"v":v,"size":size,"grow":grow,"life":life,"age":0.0}
	_puffs.multimesh.set_instance_color(_p_next,tint)
	_p_next = (_p_next+1)%PUFFS

# --- The wind tool's lanes --------------------------------------------------------------

## A lane of air from `from` along `way` (flat): its front runs `travel` m
## in `run` s; `lean` 1 is a full head; `half` its half width (m).
func _fire_lane(from: Vector3, way: Vector3, run: float, travel: float, lean: float, half: float) -> void:
	var h := Vector2(way.x,way.z).normalized()
	_lanes[_lane_next] = {"a":Vector4(from.x,from.z,h.x,h.y),"run":run,"travel":travel,"lean":lean,"half":half,"age":0.0}
	_lane_next = (_lane_next+1)%LANES

func _publish_lane(i: int, lane: Dictionary) -> void:
	_published = true
	var a := Vector4.ZERO
	var b := Vector4.ZERO
	var c := Vector4.ZERO
	if not lane.is_empty():
		a = lane.a
		b = Vector4(float(lane.age),float(lane.run),2.0,float(lane.travel))
		c = Vector4(float(lane.lean),float(lane.half),float(lane.travel)+6.0,0.0)
	RenderingServer.global_shader_parameter_set("zs_blow_%d_a" % i,a)
	RenderingServer.global_shader_parameter_set("zs_blow_%d_b" % i,b)
	RenderingServer.global_shader_parameter_set("zs_blow_%d_c" % i,c)

# --- Each frame -------------------------------------------------------------------------

func advance(delta: float) -> void:
	if delta <= 0.0: return
	_clock += delta
	_shake_isle(delta)
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var eye := cam.global_position if cam != null else Vector3.ZERO
	_step_streaks(delta,eye)
	_step_debris(delta)
	_step_rubble(delta)
	_step_puffs(delta)
	for i in range(LANES):
		var lane: Dictionary = _lanes[i]
		if lane.is_empty():
			if _published: _publish_lane(i,{})
			continue
		lane.age = float(lane.age)+delta
		if float(lane.age) > float(lane.run)+2.5:
			_lanes[i] = {}
			_publish_lane(i,{})
		else: _publish_lane(i,lane)

## The isle's sag, one frame: held, a heavy soft spring toward the hold
## (with its groan); let go, the edge spring's snap (scripts/diorama_flip.gd
## `_step_dip`: semi-implicit, 240 Hz substeps, w²(goal - x) - 2ζw v), on
## up past rest into the recoil, wobbling home. Then the node posed: the
## drop and the tip about its middle, and a tremble that dies away.
func _shake_isle(delta: float) -> void:
	snapped = false
	moved = Transform3D.IDENTITY
	_tremble = maxf(_tremble-delta*0.8,0.0)
	if phase == "": return
	var goal := 0.0
	if phase == "held": goal = _hold_sag+GROAN*(sin(_clock*1.1)*0.7+sin(_clock*2.7+0.4)*0.3)
	else: _snap_t += delta
	var remaining := delta
	while remaining > 0.0:
		var h := minf(remaining,SUBSTEP)
		remaining -= h
		var w := HOLD_W
		var zeta := HOLD_ZETA
		if phase == "snap":
			w = (RECOIL_W if _crossed else DIP_RISE_W)*SNAP_SCALE
			zeta = RECOIL_ZETA if _crossed else DIP_RISE_ZETA
		sag_v += (w*w*(goal-sag)-2.0*zeta*w*sag_v)*h
		sag += sag_v*h
		if phase == "snap" and not _crossed and sag <= 0.0:
			_crossed = true
			snapped = true
	if phase == "snap" and _crossed and absf(sag) < REST and absf(sag_v) < REST_SPEED: phase = "done"
	if isle == null or not is_instance_valid(isle):
		if phase == "done": phase = ""
		return
	before = isle.transform
	if phase == "done":
		phase = ""
		sag = 0.0
		sag_v = 0.0
		isle.transform = isle_rest
		_shaking = false
		moved = isle.transform*before.affine_inverse()
		return
	_shaking = true
	var t := _tremble*_tremble
	var jitter := Vector3(sin(_clock*41.0),sin(_clock*37.0+1.3)*0.6,sin(_clock*47.0+2.1))*0.08*t
	var creak := 0.004*sin(_clock*0.8)*(1.0 if phase == "held" else 0.0)
	var tilt := -sag*(1.0-SAG_DROP)/_rim_r
	var basis := Basis(_tilt_axis,tilt+0.003*t*sin(_clock*33.0))*Basis(_toward,creak)*isle_rest.basis
	isle.transform = Transform3D(basis,isle_rest.origin+Vector3.DOWN*sag*SAG_DROP+jitter)
	moved = isle.transform*before.affine_inverse()

## Whether `p` (world) stands on the held isle's ground as it stood before
## this frame's move (on its land, within `above` m over its turf).
func stands_on(p: Vector3, above := 0.9) -> bool:
	if isle == null or not is_instance_valid(isle) or isle_shape == null: return false
	var local := before.affine_inverse()*p
	var flat := Vector2(local.x,local.z)
	if not isle_shape.on_land(flat): return false
	var over := local.y-float(isle_shape.ground_at(flat))
	return over > -0.8 and over < above

func _step_streaks(delta: float, eye: Vector3) -> void:
	var mm := _streaks.multimesh
	for i in range(STREAKS):
		var s: Dictionary = _s[i]
		if float(s.life) <= 0.0: continue
		s.age = float(s.age)+delta
		if float(s.age) >= float(s.life):
			s.life = 0.0
			mm.set_instance_custom_data(i,Color(0,0,0,0))
			mm.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ONE*0.0001),Vector3(0,-9000,0)))
			continue
		s.v = (s.v as Vector3)*(1.0-0.25*delta)
		s.p = (s.p as Vector3)+(s.v as Vector3)*delta
		var u := float(s.age)/float(s.life)
		var fade := smoothstep(0.0,0.12,u)*(1.0-smoothstep(0.55,1.0,u))
		var along := (s.v as Vector3).normalized()
		var to_eye := (eye-(s.p as Vector3)).normalized()
		var across := along.cross(to_eye)
		if across.length() < 0.01: across = Vector3.UP
		across = across.normalized()
		var normal := along.cross(across).normalized()
		mm.set_instance_transform(i,Transform3D(Basis(along*float(s.len),across*float(s.w),normal),s.p))
		mm.set_instance_custom_data(i,Color(fade,0,0,0))

func _step_debris(delta: float) -> void:
	var mm := _debris.multimesh
	for i in range(DEBRIS):
		var s: Dictionary = _d[i]
		if float(s.life) <= 0.0: continue
		s.age = float(s.age)+delta
		if float(s.age) >= float(s.life):
			s.life = 0.0
			mm.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ONE*0.0001),Vector3(0,-9000,0)))
			continue
		var v: Vector3 = s.v
		v.y -= 3.0*delta
		v *= 1.0-0.35*delta
		s.v = v
		s.p = (s.p as Vector3)+v*delta
		var spin: Vector3 = s.spin
		s.rot = ((s.rot as Basis)*Basis.from_euler(spin*delta)).orthonormalized()
		var u := float(s.age)/float(s.life)
		var size := float(s.size)*(1.0-smoothstep(0.75,1.0,u))
		mm.set_instance_transform(i,Transform3D((s.rot as Basis).scaled(Vector3.ONE*maxf(size,0.0001)),s.p))

func _step_rubble(delta: float) -> void:
	var mm := _rubble.multimesh
	for i in range(RUBBLE):
		var s: Dictionary = _r[i]
		if float(s.life) <= 0.0: continue
		s.age = float(s.age)+delta
		var v: Vector3 = s.v
		v.y -= 14.0*delta
		s.v = v
		s.p = (s.p as Vector3)+v*delta
		if float(s.age) >= float(s.life) or (s.p as Vector3).y < sea_y-10.0:
			s.life = 0.0
			mm.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ONE*0.0001),Vector3(0,-9000,0)))
			continue
		s.rot = ((s.rot as Basis)*Basis.from_euler((s.spin as Vector3)*delta)).orthonormalized()
		mm.set_instance_transform(i,Transform3D((s.rot as Basis).scaled(Vector3.ONE*float(s.size)),s.p))

func _step_puffs(delta: float) -> void:
	var mm := _puffs.multimesh
	for i in range(PUFFS):
		var s: Dictionary = _p[i]
		if float(s.life) <= 0.0: continue
		s.age = float(s.age)+delta
		if float(s.age) >= float(s.life):
			s.life = 0.0
			mm.set_instance_custom_data(i,Color(0,0,0,0))
			mm.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ONE*0.0001),Vector3(0,-9000,0)))
			continue
		s.v = (s.v as Vector3)*(1.0-0.45*delta)
		s.p = (s.p as Vector3)+(s.v as Vector3)*delta
		var u := float(s.age)/float(s.life)
		var size := lerpf(float(s.size),float(s.grow),1.0-pow(1.0-u,2.0))
		var fade := smoothstep(0.0,0.15,u)*(1.0-smoothstep(0.45,1.0,u))*0.8
		mm.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ONE*size),s.p))
		mm.set_instance_custom_data(i,Color(fade,0,0,0))

## Anything still flying (for captures and the log).
func busy() -> int:
	var n := 0
	for list: Array in [_s,_d,_r,_p]:
		for s: Dictionary in list:
			if float(s.life) > 0.0: n += 1
	return n
