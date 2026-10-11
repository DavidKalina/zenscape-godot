extends Node3D
## The sky dragon's gale on a far isle (docs/design/rim-dragon.md, round 4):
## everything the isle does while the dragon (scripts/sky_dragon.gd) clings
## to its rim, drawn big enough to read from the aqueduct isle 150 to 300 m
## off. One node, top level, world space; the dragon drives it.
##
##   streaks   round 1's wind streaks (the rim dragon's, since removed), a
##             few times its size: drawn into the mouth on the inhale;
##   breath    round 8: the blow is the game's breeze ribbons
##             (scripts/dragon_breath.gd), born in the mouth, pouring across
##             the isle over its posed turf and ruins (`air_floor`), curling
##             in their lee, kicking up off the far rim and sinking out over
##             the cloud sea; round 10: over half of them come down onto
##             the turf and skim it all the way across (the ground layer),
##             kicking up grass blades (scripts/wind_kicked_blades.gd),
##             leaves and dust along their track;
##   gust      round 10: the blast as air for the plane (`plane_gust`):
##             a cone out of the mouth, strongest in its core near the jaw,
##             plus the ribbons near it, with buffeting and a shove on the
##             airframe (the plane reads it as any gust, SkyPlane `step`);
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
const PUFFS := 320
## The wind tool's lanes (shaders/reference_wind.gdshaderinc zs_blow_at).
const LANES := 4
const DragonBreath = preload("res://scripts/dragon_breath.gd")
const KickedBlades = preload("res://scripts/wind_kicked_blades.gd")
## Round 10, along the ground ribbons: leaves torn off and dust puffs a
## second per ribbon skimming the turf, and the dust's tint and opacity.
const GROUND_LEAVES := 6.0
const GROUND_DUST := 2.2
const DUST_TINT := Color(0.86,0.82,0.70)
const DUST_ALPHA := 0.45
## Round 10, the blast as a gust for the plane (`plane_gust`): its cone
## out of the mouth (the axis dips GUST_DIP under level; its radius GUST_R0
## m at the jaw, widening GUST_SPREAD m a metre), its reach (m), the wind
## in its core at the jaw (m/s, falling to GUST_FAR of that at its reach),
## the buffet (m/s: across, up and down), the shove on the airframe (rad/s:
## the nose swung along the blast, the wings tipped by a crossing blast,
## and the random part of each), how long it lingers after the blow (s),
## and the ribbons' own air near the plane (reach m, rise m, share).
const GUST_DIP := 0.06
const GUST_R0 := 8.0
const GUST_SPREAD := 0.42
const GUST_REACH := 170.0
const GUST_CORE := 15.0
const GUST_FAR := 0.25
const GUST_BUFFET := Vector2(4.0,3.0)
const GUST_YAW := 0.9
const GUST_ROLL := 5.0
const GUST_JOLT := Vector3(0.45,0.6,3.5)
const GUST_LINGER := 0.9
const GUST_RIBBON := Vector3(7.0,5.0,0.35)
## Ribbons out of the mouth a second at the blow's full strength.
const BREATH_RATE := 12.0

var isle: Node3D
var isle_rest := Transform3D.IDENTITY
var isle_shape: RefCounted
var isle_home := Vector3.ZERO
## Round 7: the point (world, at rest) it tips about, and the shape's frame
## in the node's (a motif isle's node stands at the world's origin, its
## land about `isle_home`; a SkyIslet's node at its middle, the identity).
var isle_pivot := Vector3.ZERO
var isle_frame := Transform3D.IDENTITY
var isle_radius := 16.0
var sea_y := -108.0
var _rng := RandomNumberGenerator.new()
var breath: Node3D
var _breath_acc := 0.0
## Round 10: the grass blades the ground ribbons tear up, the dust and
## leaves owed along them, and the blast as it was last blown (for the
## plane's gust): its mouth, way and strength (eased away after the blow).
var blades: MultiMeshInstance3D
var _g_leaf_acc := 0.0
var _g_dust_acc := 0.0
var gust_env := 0.0
var _gust_mouth := Vector3.INF
var _gust_way := Vector3.FORWARD
## The held isle's pose now: its shape's frame to the world and back
## (`air_floor`), cached once a frame.
var _floor_xf := Transform3D.IDENTITY
var _floor_inv := Transform3D.IDENTITY

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
## the isle tipping about its middle toward the dragon. Round 6 tips it more
## (0.3 dropped before): about 18° on hills_ne held, so the turf reads as a
## slope the pilot can surf down toward the dragon.
const SAG_DROP := 0.12
## The grip: on the slam the rim is kicked down at SLAM_KICK m/s on a heavy
## soft spring (HOLD_W 1/s, HOLD_ZETA), so it drops, bobs and hangs.
## Round 9: the hold is a walkable tilt, not a slope to surf. The slam tips
## the isle steep (SLAM_TIP) for STEEP_FOR s, a dramatic moment, then it
## eases back over EASE_BACK s to HOLD_TIP, under the motor's crouch surf
## (SLIDE_FROM, 10°), where he walks, runs and jumps as on the flat. Each
## blast nudges it BLAST_TIP deeper, and that eases away again (NUDGE_EASE
## 1/s, at most NUDGE_MOST). Before it lets go, it hauls the rim down hard
## one last time (`pull_down`): to PULL_TIP over PULL_TIME on a stiffer
## spring (PULL_W, PULL_ZETA), the tell that the snap is coming, and the
## depth the launch springs from (round 7's held 17 to 20°).
const SLAM_KICK := 7.0
const HOLD_W := 3.2
const HOLD_ZETA := 0.3
const SLAM_TIP := 17.0
const STEEP_FOR := 1.1
const EASE_BACK := 1.6
const HOLD_TIP := 9.0
const BLAST_TIP := 2.5
const NUDGE_MOST := 4.0
const NUDGE_EASE := 0.9
const PULL_TIP := 20.0
const PULL_TIME := 0.85
const PULL_W := 6.5
const PULL_ZETA := 0.75
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
## Round 9: seconds since the slam, the blasts' nudge (m of sag), the last
## pull's time (-1 none) and the sag it hauls down from.
var _hold_t := 0.0
var _nudge := 0.0
var _pull_t := -1.0
var _pull_from := 0.0
var _rim_r := 16.0
## Round 7: the sag scaled by the gripped rim's distance from the pivot
## over hills_ne's (RIM_REF m), so a bigger motif isle tips by round 6's
## angles (about 17 to 22° held), not half of them.
const RIM_REF := 14.0
var _scale := 1.0
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
	breath = DragonBreath.new()
	add_child(breath)
	breath.setup_breath(air_floor)
	breath.standing = stands_at
	blades = KickedBlades.new()
	blades.name = "BreathBlades"
	blades.ground_height = air_floor
	blades.extra_cull_margin = 200.0
	add_child(blades)

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
func hold_isle(node: Node3D, shape: RefCounted, home: Vector3, radius: float, toward: Vector3, rim := Vector3.INF, frame := Transform3D.IDENTITY, pivot := Vector3.INF) -> void:
	var same := node != null and node == isle
	if not same:
		_settle_now()
		isle = node if node != null and is_instance_valid(node) else null
		if isle != null: isle_rest = isle.transform
		sag = 0.0
		sag_v = 0.0
	isle_frame = frame
	isle_pivot = pivot if pivot != Vector3.INF else (isle_rest.origin if isle != null else home)
	isle_shape = shape
	isle_home = home
	isle_radius = radius
	_toward = toward
	_tilt_axis = Vector3(-toward.z,0.0,toward.x).normalized()
	_rim_r = maxf(Vector2(rim.x-home.x,rim.z-home.z).length(),6.0) if rim != Vector3.INF else radius
	_scale = clampf(_rim_r/RIM_REF,1.0,2.5)
	_hold_t = 0.0
	_nudge = 0.0
	_pull_t = -1.0
	phase = "held"
	_cache_floor()
	# The breath's ribbons live over the isle and out past its far rim.
	if breath != null: breath.set_bounds(Vector2(home.x,home.z),radius+110.0)

## Let go of the isle: it snaps back up past rest, recoils, wobbles and
## settles home.
func release_isle() -> void:
	if phase != "held": return
	phase = "snap"
	_crossed = false
	_snap_t = 0.0
	_pull_t = -1.0
	_nudge = 0.0

## The isle home at once (a new hold, leaving the tree).
func _settle_now() -> void:
	if isle != null and is_instance_valid(isle) and _shaking: isle.transform = isle_rest
	_shaking = false
	phase = ""
	sag = 0.0
	sag_v = 0.0

## The sag (m at the gripped rim) that tips the isle `degrees` toward the
## dragon.
func _sag_for(degrees: float) -> float:
	return deg_to_rad(degrees)*_rim_r/(1.0-SAG_DROP)

## A blast's weight: the rim sinks a little deeper, then eases back up
## (round 9).
func deepen() -> void:
	if phase != "held": return
	_nudge = minf(_nudge+_sag_for(BLAST_TIP),_sag_for(NUDGE_MOST))
	sag_v += 1.2*_scale
	_tremble = maxf(_tremble,0.6)

## Round 9: the last heavy pull before it lets go. The rim hauls down deep
## over PULL_TIME (the tell), the depth the snap springs back from.
func pull_down() -> void:
	if phase != "held" or _pull_t >= 0.0: return
	_pull_t = 0.0
	_pull_from = sag
	_tremble = maxf(_tremble,0.7)

## Whether the hold has eased back from the slam to its walkable tilt.
func eased() -> bool:
	return phase == "held" and _pull_t < 0.0 and _hold_t > STEEP_FOR+EASE_BACK+0.6

## The sag the hold wants now, before the groan.
func _hold_goal() -> float:
	if _pull_t >= 0.0: return lerpf(_pull_from,_sag_for(PULL_TIP),smoothstep(0.0,1.0,_pull_t/PULL_TIME))
	var u := clampf((_hold_t-STEEP_FOR)/EASE_BACK,0.0,1.0)
	return lerpf(_sag_for(SLAM_TIP),_sag_for(HOLD_TIP),smoothstep(0.0,1.0,u))+_nudge

## The slam: the rim is dragged down and the isle tips toward the dragon,
## dust bursts off the rim, rubble breaks away and falls.
func slam(rim: Vector3, out: Vector3, tangent: Vector3) -> void:
	sag_v += SLAM_KICK*_scale
	_tremble = 1.0
	_hold_t = 0.0
	_nudge = 0.0
	_pull_t = -1.0
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
	gust_env = maxf(gust_env,strength)
	_gust_mouth = mouth
	_gust_way = way
	var side := Vector3(-way.z,0.0,way.x)
	# Round 8: the breath is ribbons out of the mouth (scripts/dragon_breath.gd).
	_breath_acc += delta*BREATH_RATE*strength
	while _breath_acc >= 1.0:
		_breath_acc -= 1.0
		breath.blast(mouth,way,strength)
	# The trees: lane after lane along the blast.
	_lane_acc += delta
	if _lane_acc >= 0.32:
		_lane_acc = 0.0
		_fire_lane(mouth,way,0.85,80.0,1.35*strength,26.0)
	# Leaves and twigs off the turf it crosses (round 10: fewer at random,
	# more along the ground ribbons, `_along_ground`).
	_d_acc += delta*45.0*strength
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
			if isle != null: return isle.global_transform*(isle_frame*local)
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

func _puff(p: Vector3, v: Vector3, size: float, grow: float, life: float, tint: Color, alpha := 1.0) -> void:
	_p[_p_next] = {"p":p,"v":v,"size":size,"grow":grow,"life":life,"age":0.0,"alpha":alpha}
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
	_cache_floor()
	gust_env *= exp(-delta/GUST_LINGER)
	var cam := get_viewport().get_camera_3d() if is_inside_tree() else null
	var eye := cam.global_position if cam != null else Vector3.ZERO
	# The ground ribbons bow the plants under them while the eye is near
	# enough to see it (the isle breeze's slots, for the frame).
	breath.claim = breath.count() > 0 and isle != null and eye.distance_to(isle_home) < 260.0
	breath.advance(delta,1.0,0.0)
	_along_ground(delta)
	blades.advance(delta,false,breath)
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

## Round 10: along each ground ribbon skimming the turf, leaves torn off
## and flung ahead, and dust kicked up low behind its head.
func _along_ground(delta: float) -> void:
	var list: Array = breath.skimming()
	if list.is_empty(): return
	_g_leaf_acc += delta*GROUND_LEAVES*list.size()
	_g_dust_acc += delta*GROUND_DUST*list.size()
	while _g_leaf_acc >= 1.0:
		_g_leaf_acc -= 1.0
		var one: Array = list[_rng.randi()%list.size()]
		var head: Vector3 = one[0]
		var v: Vector3 = one[1]
		var at := Vector3(head.x,float(one[2])+0.3,head.z)+Vector3(_rng.randf_range(-1.2,1.2),0.0,_rng.randf_range(-1.2,1.2))
		_leaf(at,Vector3(v.x,0.0,v.z)*_rng.randf_range(0.6,1.0)+Vector3.UP*_rng.randf_range(2.0,6.0))
	while _g_dust_acc >= 1.0:
		_g_dust_acc -= 1.0
		var one: Array = list[_rng.randi()%list.size()]
		var head: Vector3 = one[0]
		var v: Vector3 = one[1]
		var flat := Vector3(v.x,0.0,v.z)
		var at := Vector3(head.x,float(one[2])+0.8,head.z)-flat.normalized()*_rng.randf_range(1.0,4.0)
		var size := _rng.randf_range(2.0,3.5)
		_puff(at,flat*_rng.randf_range(0.45,0.7)+Vector3.UP*_rng.randf_range(0.5,1.8),size,size*_rng.randf_range(2.0,2.8),_rng.randf_range(1.4,2.2),DUST_TINT,DUST_ALPHA)

## The blast as a gust for the plane at `p` (world), `nose` its forward
## (world, unit): `wind` (m/s, added to its velocity: along the blast,
## strongest in the cone's core near the jaw, fading out to its reach, with
## a buffet, and the ribbons' own air near it), `shove` (rad/s on its pitch,
## heading and bank: the nose swung along the blast, the wings tipped by a
## blast across them, jolts) and `gust` (0 to about 1, how hard). Empty
## when there is no blast near. A shove, never a crash: the plane's own
## easing takes it back as it leaves the air.
func plane_gust(p: Vector3, nose: Vector3) -> Dictionary:
	var s := 0.0
	var axis := Vector3(_gust_way.x,-GUST_DIP,_gust_way.z).normalized()
	if gust_env > 0.01 and _gust_mouth != Vector3.INF:
		var rel := p-_gust_mouth
		var along := rel.dot(axis)
		if along > -10.0 and along < GUST_REACH:
			var radius := GUST_R0+maxf(along,0.0)*GUST_SPREAD
			var off := (rel-axis*along).length()
			var core := 1.0-smoothstep(radius*0.3,radius,off)
			var fall := lerpf(1.0,GUST_FAR,smoothstep(10.0,GUST_REACH,along))*(1.0-smoothstep(GUST_REACH*0.85,GUST_REACH,along))*smoothstep(-10.0,3.0,along)
			s = core*fall*gust_env
	var ribbons: Vector3 = breath.air_near(p,GUST_RIBBON.x,GUST_RIBBON.y)*GUST_RIBBON.z
	var r := clampf(ribbons.length()/12.0,0.0,0.6)
	var hard := clampf(s+r,0.0,1.2)
	if hard < 0.01: return {}
	var t := _clock
	var ph := Vector3(p.x,p.y,p.z)*0.07
	var n1 := sin(t*8.3+ph.x)*0.6+sin(t*13.1+ph.z*1.3)*0.4
	var n2 := sin(t*9.7+ph.z+1.7)*0.6+sin(t*15.3+ph.x*0.8)*0.4
	var n3 := sin(t*11.9+ph.y+3.1)*0.5+sin(t*6.1+ph.x+ph.z)*0.5
	var side := Vector3(-axis.z,0.0,axis.x)
	var wind := axis*GUST_CORE*s+side*n1*GUST_BUFFET.x*hard+Vector3.UP*n2*GUST_BUFFET.y*hard+ribbons
	var flat := Vector2(nose.x,nose.z)
	var yaw := 0.0
	var roll := 0.0
	if flat.length_squared() > 0.0001:
		var a := flat.normalized().angle_to(Vector2(axis.x,axis.z))
		yaw = -sin(a)*GUST_YAW*s
		# The plane's right (SkyPlane: forward (-sin h, -cos h), right
		# (cos h, -sin h)): a blast toward it lifts the wing it comes from.
		var right := Vector2(-flat.y,flat.x).normalized()
		roll = Vector2(axis.x,axis.z).normalized().dot(right)*GUST_ROLL*s
	var shove := Vector3(n2*GUST_JOLT.x*hard,yaw+n3*GUST_JOLT.y*hard,roll+n1*GUST_JOLT.z*hard)
	return {"wind":wind,"shove":shove,"gust":hard}

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
	if phase == "held":
		_hold_t += delta
		_nudge *= exp(-NUDGE_EASE*delta)
		if _pull_t >= 0.0: _pull_t += delta
		# The groan dies away under the pull: its haul is the tell.
		var groan := 0.0 if _pull_t >= 0.0 else GROAN*_scale*(sin(_clock*1.1)*0.7+sin(_clock*2.7+0.4)*0.3)
		goal = _hold_goal()+groan
	else: _snap_t += delta
	var remaining := delta
	while remaining > 0.0:
		var h := minf(remaining,SUBSTEP)
		remaining -= h
		var w := HOLD_W
		var zeta := HOLD_ZETA
		if _pull_t >= 0.0:
			w = PULL_W
			zeta = PULL_ZETA
		if phase == "snap":
			# A bigger isle (sagged further) springs back slower, so its
			# launch isn't twice round 6's.
			w = (RECOIL_W if _crossed else DIP_RISE_W)*SNAP_SCALE/sqrt(_scale)
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
	# Tipped about its pivot (a SkyIslet's own middle, a motif isle's main
	# land's), dropped and trembling.
	var turn := Basis(_tilt_axis,tilt+0.003*t*sin(_clock*33.0))*Basis(_toward,creak)
	var pose := Transform3D(turn,isle_pivot+Vector3.DOWN*sag*SAG_DROP+jitter)*Transform3D(Basis.IDENTITY,-isle_pivot)
	isle.transform = pose*isle_rest
	moved = isle.transform*before.affine_inverse()

## How far the isle is tipped toward the dragon now (radians).
func tip() -> float:
	if phase == "": return 0.0
	return sag*(1.0-SAG_DROP)/_rim_r

## Whether `p` (world) stands on the held isle's ground as it stood before
## this frame's move (on its land, within `above` m over its turf; or on or
## hanging from anything of it: round 8).
func stands_on(p: Vector3, above := 0.9) -> bool:
	if isle == null or not is_instance_valid(isle) or isle_shape == null: return false
	var local := isle_frame.affine_inverse()*(before.affine_inverse()*p)
	var flat := Vector2(local.x,local.z)
	if isle_shape.on_land(flat):
		var over := local.y-float(isle_shape.ground_at(flat))
		if over > -0.8 and over < above: return true
	# Round 8: or on anything of it (a ruin's floor or wall top, a
	# satellite, a spire's top), or hanging from its lip or a ledge (the
	# feet up to 2.6 m under the top there).
	if isle_shape.has_method("top_at"):
		var top: Variant = isle_shape.top_at(flat)
		if top != null:
			var over_top := local.y-float(top)
			if over_top > -2.6 and over_top < above: return true
	return false

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
		var fade := smoothstep(0.0,0.15,u)*(1.0-smoothstep(0.45,1.0,u))*0.8*float(s.get("alpha",1.0))
		mm.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ONE*size),s.p))
		mm.set_instance_custom_data(i,Color(fade,0,0,0))

## Anything still flying (for captures and the log).
func busy() -> int:
	var n := 0
	for list: Array in [_s,_d,_r,_p]:
		for s: Dictionary in list:
			if float(s.life) > 0.0: n += 1
	return n

# --- The breath's floor (round 8) ------------------------------------------------------

func _cache_floor() -> void:
	if isle != null and is_instance_valid(isle): _floor_xf = isle.global_transform*isle_frame
	else: _floor_xf = Transform3D(Basis.IDENTITY,isle_home)
	_floor_inv = _floor_xf.affine_inverse()

## The held isle's floor under `p` (world x, z) as it is posed now: the top
## of its turf and of anything standing on it (scripts/dragon_isle_shape.gd
## `top_at`), tipped and sagged with it; null over open air. The breath's
## ribbons ride it.
func air_floor(p: Vector2) -> Variant:
	if isle_shape == null or not isle_shape.has_method("top_at"): return null
	var w := Vector3(p.x,_floor_xf.origin.y,p.y)
	for k in range(3):
		var l := _floor_inv*w
		var h: Variant = isle_shape.top_at(Vector2(l.x,l.z))
		if h == null: return null
		w.y = (_floor_xf*Vector3(l.x,float(h),l.z)).y
	return w.y

## How high something stands over the held isle's turf at `p` (world x, z;
## m, in the isle's own frame, so its tip doesn't count): a wall, a ruin, a
## bell frame; 0 on open turf, on water or off its main land. The ground ribbons steer
## round what stands (scripts/dragon_breath.gd `_steer_round`).
func stands_at(p: Vector2) -> float:
	if isle_shape == null or not isle_shape.has_method("dry_at"): return 0.0
	var l := _floor_inv*Vector3(p.x,_floor_xf.origin.y,p.y)
	var flat := Vector2(l.x,l.z)
	var top: Variant = isle_shape.dry_at(flat)
	var turf: Variant = isle_shape.turf_at(flat)
	if top == null or turf == null: return 0.0
	return maxf(float(top)-float(turf),0.0)

## The held isle's local frame (its shape's), posed now, for the dragon's
## head (scripts/sky_dragon.gd `_clear_turf`).
func floor_xf() -> Transform3D:
	return _floor_xf
