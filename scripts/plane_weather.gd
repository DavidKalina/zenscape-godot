extends Node3D
## The elements on the plane (a prototype; studies/sky_weather_field.gd):
## the air a SkyPlane flies in, as its `air` callable (`air_at`), built from
## the isle's live sky.
##
##   the storm  read off the sky (the precipitation's `state.w`, 0 to 1), so
##              it rolls in and out as the weather eases (`roll_in`, `clear`:
##              scripts/living_weather.gd `ease_toward`, about half a minute).
##              Under it the air runs STORM_WIND m/s along the sky's wind
##              (the atmosphere's `_air_angle`, the rain's slant), so a held
##              heading crabs; and it is rough: TURB_* rad/s of pitch, roll
##              and yaw and TURB_LIFT m/s up and down, from noise.
##   gusts      now and then a pull to one side (GUST_EVERY s apart on calm
##              air, STORM_GUST_EVERY in a full storm), a tractor beam not a
##              blow: over GUST_TIME s it builds slowly (GUST_BUILD of its
##              length), holds and lets go, dragging the plane GUST_WIND m/s
##              that way (STORM_GUST_WIND in a storm) and reeling the nose
##              round towards it (GUST_REEL per second of the angle, at most
##              REEL_MOST of it), leaning a little into it (GUST_LEAN). No
##              jolt. `gust` sends one now.
##   jets       rivers of fast air (scripts/sky_currents.gd, its ribbons):
##              a loop round the field and a high straight crossing it. In
##              one the air carries the plane along at JET m/s and pulls it
##              to the core (HOLD of the stream's).
##
## The storm's look (`grade`, each frame after the sky has set its own):
## the dome eased from the storm preset's near black (meant to sit behind a
## cloud deck this sky does not draw) toward slate (SLATE_*, by daylight),
## the cloud and the cloud sea dimmed and greyed (the zs_storm_grade global,
## shaders/reference_globals.gdshaderinc `zs_storm_graded`), the sun on the
## land and on the cloud dimmed to SUN_DIM.
##
## Each frame `step` it, then the plane reads `air_at` in its own step.
const SkyCurrents = preload("res://scripts/sky_currents.gd")
const PlaneLightning = preload("res://scripts/plane_lightning.gd")
const StormFront = preload("res://scripts/storm_front.gd")

const STORM_WIND := 6.0
const TURB_PITCH := 0.35
const TURB_ROLL := 2.8
const TURB_YAW := 0.18
const TURB_LIFT := 2.2
## Calm air still bumps a little.
const CALM_ROUGH := 0.12
const GUST_EVERY := 9.0
const STORM_GUST_EVERY := 5.0
const GUST_TIME := Vector2(2.2,3.6)
const GUST_BUILD := 0.55
const GUST_WIND := 7.0
const STORM_GUST_WIND := 11.0
const GUST_REEL := 1.1
const REEL_MOST := 0.9
const GUST_LEAN := 1.2
## The least share of a gust that comes across the nose.
const ACROSS_MIN := 0.6
const JET := 20.0
const JET_RADIUS := 13.0
const HOLD := 0.5
## The loop round the field: its middle's height, its half extents (m), and
## the high crossing's height.
const LOOP_UP := 62.0
const LOOP_HALF := Vector2(240.0,180.0)
const CROSS_UP := 84.0
const SHOWN := 3
const FRONT_IN := 0.6
const FRONT_OUT := 0.15
const SLATE_UP := Vector3(0.17,0.18,0.2)
const SLATE_DOWN := Vector3(0.15,0.155,0.165)
const SLATE_GLOW := Vector3(0.08,0.082,0.086)
## The rain (`rain`): drops in the box round the camera, how long each
## lives (s), how fast it falls (m/s), its streak's width and length per
## m/s of its speed past the eye (m, at most RAIN_LONGEST), its colour, and
## the storm it starts at.
const RAIN_DROPS := 14000
const RAIN_LIFE := 0.9
const RAIN_FALL := 9.0
const RAIN_BOX := 26.0
const RAIN_WIDTH := 0.022
const RAIN_STREAK := 0.028
const RAIN_LONGEST := 1.1
const RAIN_COLOUR := Color(0.8,0.84,0.9,0.15)
## Each drop's strength, from the faintest to the full (its colour's alpha),
## and its size's spread.
const RAIN_FAINT := 0.25
const RAIN_SIZES := Vector2(0.6,1.3)
const RAIN_FROM := 0.25
## The rain's distance: veils (shaders/plane_rain_veil.gdshader) round the
## eye at these radii (m), each this tall (m).
const VEILS := [45.0,110.0]
const VEIL_TALL := 300.0
## Of the slate left at night.
const SLATE_NIGHT := 0.08
const SUN_DIM := 0.4

## The storm now (0 to 1), and an override (`--storm=<x>`; NAN: the sky's).
var storm := 0.0
var storm_pinned := NAN
var currents: Node3D
## The storm's lightning (scripts/plane_lightning.gd).
var lightning: Node3D
## The storm front (scripts/storm_front.gd, `send_front`): its storm where
## the plane is (or the eye, on foot) joins the sky's, and coming close it
## eases the sky to storm (FRONT_IN), clearing it again once out (FRONT_OUT).
var front: Node3D
var _front_eased := false
## The gust under way ({} none): its side (a unit vector, flat), its
## strength's share, its time and length, and its signs.
var _gust := {}
var _next_gust := 4.0
var _time := 0.0
## The nose the plane last asked with: the side a gust pulls from.
var _nose := Vector3.FORWARD
var _noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _scene: Node3D
## The rain the plane flies through: streaks in a box round the camera.
var _sun_own := 0.0
var _sun_dimmed := -1.0
var _rain: GPUParticles3D
var _rain_process: ParticleProcessMaterial
var _rain_quad: QuadMesh
var _veils: Array[MeshInstance3D] = []

func setup(scene: Node3D) -> void:
	name = "PlaneWeather"
	_scene = scene
	_noise.seed = 7
	_noise.frequency = 0.9
	_rng.randomize()
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--storm="): storm_pinned = clampf(float(arg.substr(8)),0.0,1.0)
	currents = SkyCurrents.new()
	add_child(currents)
	currents.name = "SkyCurrents"
	var top: float = scene.isle_top()
	var ring := []
	for k in range(10):
		var a := k*TAU/10.0
		var swell := 10.0*sin(a*2.0)
		ring.append(Vector3(cos(a)*LOOP_HALF.x,top-30.0+LOOP_UP+swell,sin(a)*LOOP_HALF.y))
	currents.currents.append(currents._current(SkyCurrents._loop(ring),true,JET,JET_RADIUS,"jet"))
	var cross := PackedVector3Array()
	for k in range(7):
		var x := lerpf(-520.0,520.0,k/6.0)
		cross.append(Vector3(x,top-30.0+CROSS_UP+6.0*sin(k*1.7),60.0*sin(k*0.9)))
	currents.add_jet(cross,"cross",JET)
	currents.currents[-1].radius = JET_RADIUS
	# The ribbons are sparse (SkyCurrents JET_RIBBONS); each jet laid
	# SHOWN times over draws SHOWN times the strokes, the air the same (only
	# the deepest jet counts).
	for jet: Dictionary in currents.currents.duplicate():
		for k in range(SHOWN-1): currents.currents.append(jet)
	currents._wisps_later()
	_build_rain()
	lightning = PlaneLightning.new()
	add_child(lightning)
	lightning.setup(scene)
	front = StormFront.new()
	add_child(front)
	front.setup(scene)
	# `--front=<m>`: one already in, its leading edge that far off, coming
	# from ahead of the start (north, -z) unless `--front-toward=<rad>`.
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--front="):
			var toward := PI*0.5
			for other in preload("res://scripts/launch_args.gd").user_args():
				if other.begins_with("--front-toward="): toward = float(other.substr(15))
			front.send(toward,Vector3.ZERO)
			front.centre = front.home-front.way*(float(arg.substr(8))+front.LEAD)
	# The sky's own rain (studies/precipitation.gd), made for the walker's
	# view, drawn under this one: put away.
	for old in ["Rain","RainCrowns"]:
		var node: Node3D = scene._precipitation.get_node_or_null(old)
		if node != null: node.visible = false

func _build_rain() -> void:
	_rain = GPUParticles3D.new()
	_rain.name = "Rain"
	_rain.top_level = true
	_rain.local_coords = true
	_rain.amount = RAIN_DROPS
	_rain.lifetime = RAIN_LIFE
	_rain.emitting = false
	_rain.transform_align = GPUParticles3D.TRANSFORM_ALIGN_Z_BILLBOARD_Y_TO_VELOCITY
	_rain.visibility_aabb = AABB(-Vector3.ONE*RAIN_BOX*3.0,Vector3.ONE*RAIN_BOX*6.0)
	_rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rain_process = ParticleProcessMaterial.new()
	_rain_process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_rain_process.emission_box_extents = Vector3.ONE*RAIN_BOX
	_rain_process.gravity = Vector3.ZERO
	_rain_process.spread = 1.5
	_rain.process_material = _rain_process
	_rain_quad = QuadMesh.new()
	_rain_quad.size = Vector2(RAIN_WIDTH,1.0)
	var look := ShaderMaterial.new()
	look.shader = preload("res://shaders/plane_rain.gdshader")
	look.set_shader_parameter("tint",RAIN_COLOUR)
	_rain_process.scale_min = RAIN_SIZES.x
	_rain_process.scale_max = RAIN_SIZES.y
	var strengths := Gradient.new()
	strengths.set_color(0,Color(1,1,1,RAIN_FAINT))
	strengths.set_color(1,Color(1,1,1,1))
	var ramp := GradientTexture1D.new()
	ramp.gradient = strengths
	_rain_process.color_initial_ramp = ramp
	_rain_quad.material = look
	_rain.draw_pass_1 = _rain_quad
	add_child(_rain)
	for radius: float in VEILS:
		var tube := CylinderMesh.new()
		tube.top_radius = radius
		tube.bottom_radius = radius
		tube.height = VEIL_TALL
		tube.cap_top = false
		tube.cap_bottom = false
		tube.radial_segments = 48
		tube.rings = 1
		var veil := MeshInstance3D.new()
		veil.name = "RainVeil"
		veil.top_level = true
		veil.mesh = tube
		veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var sheet := ShaderMaterial.new()
		sheet.shader = preload("res://shaders/plane_rain_veil.gdshader")
		sheet.render_priority = 10
		veil.material_override = sheet
		veil.visible = false
		add_child(veil)
		_veils.append(veil)

## The rain round `eye` for a plane going `moving` (m/s): each drop moves
## past the eye at the fall plus the wind less the plane's own speed, laid
## upstream of the eye so it streams through the view.
func rain(eye: Vector3, moving: Vector3) -> void:
	var on := smoothstep(RAIN_FROM,1.0,storm)
	_rain.emitting = on > 0.0
	for veil in _veils:
		veil.visible = on > 0.0
		veil.global_position = eye
		(veil.material_override as ShaderMaterial).set_shader_parameter("strength",on)
	if on <= 0.0: return
	_rain.amount_ratio = on
	var a := _air_angle()
	var past := Vector3.DOWN*RAIN_FALL+Vector3(cos(a),0.0,sin(a))*STORM_WIND*storm-moving
	var pace := past.length()
	_rain.global_position = eye
	_rain_process.direction = past/pace
	_rain_process.initial_velocity_min = pace*0.95
	_rain_process.initial_velocity_max = pace*1.05
	_rain_process.emission_shape_offset = -past*RAIN_LIFE*0.5
	_rain_quad.size = Vector2(RAIN_WIDTH,minf(pace*RAIN_STREAK,RAIN_LONGEST))

## The sky's wind's way (radians round, x then z), 0 with no sky.
func _air_angle() -> float:
	return float(_scene._atmosphere._air_angle) if _scene._atmosphere != null else 0.0

## The storm rolls in (the sky eases to "storm").
func roll_in() -> void:
	_scene.weather._ease("storm")

## The storm clears (the sky eases to "fair").
func clear() -> void:
	_scene.weather._ease("fair")

## A storm front in on the sky's wind, towards the field (or calls it off).
func send_front() -> bool:
	if front.active:
		front.end()
		return false
	front.send(_air_angle(),Vector3.ZERO)
	return true

## Where the weather is felt: the plane, else the eye.
func probe() -> Vector3:
	if _scene.flying and _scene.plane != null: return _scene.plane.position
	return _scene.camera.global_position if _scene.camera != null else Vector3.ZERO

## A gust now, from the left or right at random.
func gust() -> void:
	_start_gust(_rng.randf_range(0.7,1.0))

func step(delta: float) -> void:
	_time += delta
	var sky: Node3D = _scene._precipitation
	storm = storm_pinned if not is_nan(storm_pinned) else (float(sky.state.w) if sky != null else 0.0)
	front.step(delta)
	var near: float = front.storm_at(probe())
	if is_nan(storm_pinned): storm = maxf(storm,near)
	if not _front_eased and near > FRONT_IN:
		_front_eased = true
		roll_in()
	elif _front_eased and near < FRONT_OUT:
		_front_eased = false
		clear()
	if not _gust.is_empty():
		_gust.t += delta
		if _gust.t >= _gust.length: _gust = {}
	_next_gust -= delta
	if _next_gust <= 0.0:
		if _gust.is_empty(): _start_gust(_rng.randf_range(0.4,1.0)*lerpf(0.6,1.0,storm))
		var every := lerpf(GUST_EVERY,STORM_GUST_EVERY,storm)
		_next_gust = _rng.randf_range(0.5,1.5)*every
	lightning.step(delta,storm)

## The storm's look over the sky the celestial rig has just set.
func grade() -> void:
	var sky = _scene._celestial
	RenderingServer.global_shader_parameter_set("zs_storm_grade",storm)
	_grade_sky(sky)
	lightning.publish(storm)

func _grade_sky(sky) -> void:
	if sky == null or storm <= 0.0: return
	var sun: Vector3 = sky.state.get("zs_sun_direction",Vector3.UP)
	var day := lerpf(SLATE_NIGHT,1.0,smoothstep(-0.08,0.3,sun.y))
	for pair: Array in [["zs_sky_up",SLATE_UP],["zs_sky_down",SLATE_DOWN],["zs_sky_glow",SLATE_GLOW]]:
		var now: Vector3 = sky.state.get(pair[0],Vector3.ZERO)
		RenderingServer.global_shader_parameter_set(pair[0],now.lerp(pair[1]*day,storm))
	var cloud_sun: Vector3 = sky.state.get("zs_cloud_sun",Vector3.ONE)
	var grey := Vector3.ONE*cloud_sun.dot(Vector3(0.2126,0.7152,0.0722))
	RenderingServer.global_shader_parameter_set("zs_cloud_sun",cloud_sun.lerp(grey*SUN_DIM,storm))
	if sky._sun != null:
		# The rig's own energy, not this frame's again if it set none since.
		var own: float = sky._sun.light_energy
		if is_equal_approx(own,_sun_dimmed): own = _sun_own
		_sun_own = own
		_sun_dimmed = own*lerpf(1.0,SUN_DIM,storm)
		sky._sun.light_energy = _sun_dimmed
	# No rainbow under a storm.
	RenderingServer.global_shader_parameter_set("zs_bow",float(sky.state.get("zs_bow",0.0))*(1.0-storm))

func _start_gust(strength: float) -> void:
	# From one side of the way it is heading, a little ahead or behind.
	var a := atan2(_nose.z,_nose.x)+(PI*0.5 if _rng.randf() < 0.5 else -PI*0.5)+_rng.randf_range(-0.5,0.5)
	_gust = {"way":Vector3(cos(a),0.0,sin(a)),"k":strength,"t":0.0,
		"length":_rng.randf_range(GUST_TIME.x,GUST_TIME.y)}

## The air at `p` for a plane whose nose points `nose` (a unit vector):
## `wind` (m/s), `shove` (rad/s: pitch, yaw, roll), `jet`, `thermal`,
## `gust` (0 to 1, how hard one is blowing now), `storm`.
func air_at(p: Vector3, nose := Vector3.FORWARD) -> Dictionary:
	var here: Dictionary = currents.air_at(p)
	_nose = nose
	var wind: Vector3 = here.wind+(here.hold as Vector3)*HOLD
	var a := _air_angle()
	wind += Vector3(cos(a),0.0,sin(a))*STORM_WIND*storm
	var rough := lerpf(CALM_ROUGH,1.0,storm)
	var t := _time
	var shove := Vector3(TURB_PITCH*_noise.get_noise_2d(t,11.0),TURB_YAW*_noise.get_noise_2d(t,23.0),TURB_ROLL*_noise.get_noise_2d(t,37.0))*rough
	wind.y += TURB_LIFT*_noise.get_noise_2d(t*0.7,53.0)*rough
	var blowing := 0.0
	if not _gust.is_empty():
		var u: float = _gust.t/_gust.length
		# Builds slowly, holds, lets go.
		blowing = float(_gust.k)*smoothstep(0.0,GUST_BUILD,u)*smoothstep(1.0,GUST_BUILD+0.15,u)
		var way: Vector3 = _gust.way
		wind += way*lerpf(GUST_WIND,STORM_GUST_WIND,storm)*blowing
		# The nose reeled round towards the pull (heading up is left), and
		# a lean into it.
		var flat := Vector3(nose.x,0.0,nose.z).normalized()
		var right := flat.cross(Vector3.UP)
		var across := way.dot(right)
		across = (1.0 if across >= 0.0 else -1.0)*maxf(absf(across),ACROSS_MIN)
		var angle := clampf(atan2(flat.cross(way).y,flat.dot(way)),-REEL_MOST,REEL_MOST)
		shove += Vector3(0.0,GUST_REEL*angle,GUST_LEAN*across)*blowing
	return {"wind":wind,"shove":shove,"jet":here.jet,"thermal":here.thermal,"gust":blowing,"storm":storm}
