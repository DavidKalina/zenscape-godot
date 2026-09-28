extends Node3D
## A ball of water in the hand (docs/scenic/water-brush.md "Water ball"). With
## water in hand a press condenses a swirling ball of the ponds' own water
## (shaders/water_ball.gdshader) above the ground, with a few fish riding the
## vortex inside; it grows while the button is held, beads of water spiralling
## in and ringing out over its surface, and follows the pointer on a spring,
## bobbing and wobbling, now and then a drip. Straight below it on the ground
## lies its mark (shaders/water_ball_ground.gdshader), which is the promise
## (docs/scenic/handful.md): the ball lands inside it. Release lets it go: it
## is tossed straight up, hangs trembling at the top and pops (the God Hand's
## finger pokes it on the same beat, scripts/god_hand.gd): its skin bursts in
## a ring of droplets from where it was popped, and the water, loose now,
## falls straight down onto the mark, stretching and shedding drops as it
## goes. It squashes on the ground and spreads into a wash of foam
## under a crown of spray (shaders/water_splash.gdshader), droplets fly and the
## fish leap out; `landed` hands its water and fish to the editor
## (NativeChunkEditor `_ball_landed`), which settles the water as one pour and
## lets the fish into the pond it made.
##
## Lives under the terrain node, so its coordinates are the plate's.

## x, z of the landing, the ball's volume (m³) and the fish it carried, as
## [{"kind", "seed", "mirror"}] (scripts/life_models.gd FISH_KINDS).
signal landed(point: Vector2, volume: float, fish: Array)

const Models = preload("res://scripts/life_models.gd")
const Variety = preload("res://scripts/seeded_variety.gd")

## Metres from the ground to the ball's underside while held.
const HOVER := 1.6
## The smallest ball drawn, in metres of radius, however little it holds.
const MIN_RADIUS := 0.28
## The follow spring (1/s²) and its damping (1/s): a little under critical,
## so the ball overshoots and settles behind a quick pointer. It trails a
## steady pointer by FOLLOW_DAMP/FOLLOW s (0.13 s) of its travel.
const FOLLOW := 120.0
const FOLLOW_DAMP := 16.0
## The radius spring: a growing ball swells past its size and settles.
const SWELL := 90.0
const SWELL_DAMP := 9.0
## Metres and hertz of the idle bob.
const BOB := 0.07
const BOB_RATE := 0.55
## Seconds for a new ball to condense out of the air, and the beads that
## rush in as it does.
const CONDENSE_SECONDS := 0.35
const CONDENSE_BEADS := 22
## Release: the toss lifts the ball TOSS m, easing to a hang, and it pops
## POP_SECONDS after the release (the God Hand's CupOut pops it then:
## god_hand_clips.py CUP_POP), then falls under GRAVITY (m/s²). The fall is
## straight down: the carried speed goes into the wobble, not the path.
const TOSS := 0.45
const POP_SECONDS := 0.4333
const GRAVITY := 18.0
## The pop: droplets of skin thrown out, how much of the skin is gone from
## the falling water (the shader's burst), how far the loose water stretches
## as it falls, and the drops it sheds a second.
const POP_SPRAY := 30
const LOOSE := 0.22
const LOOSE_STRETCH := 0.7
const SHED_RATE := 40.0
## The splash: seconds to squash, to spread into a wash and burst into foam,
## the crown's life, and the whole of it (the wet ground dries after).
const SQUASH_SECONDS := 0.1
const SPREAD_SECONDS := 0.5
const CROWN_SECONDS := 0.95
const SPLASH_SECONDS := 1.6
const WET_SECONDS := 4.5
const SPRAY := 44
## How far the foam runs, in ball radii.
const SPLASH_REACH := 3.2
## Beads: the most at once, how many a second gather in while the ball fills,
## the seconds between drips, and their sizes (m).
const BEADS := 128
const INTAKE_RATE := 26.0
const DRIP_SECONDS := Vector2(0.45,1.3)
## Fish: how many a ball of V m³ carries (2 + V/FISH_PER_VOLUME, at most
## FISH_MAX), and their length as a share of the ball's radius.
const FISH_MIN := 2
const FISH_MAX := 5
const FISH_PER_VOLUME := 3.5
const FISH_LENGTH := 0.55
## A big ball's fish show a little larger than life, at most this scale.
const FISH_GROWN := 1.8
## Ripple rings the surface carries at once (the shader's `ripples` array),
## and the bubbles rising inside (its `bubbles`).
const RIPPLES := 10
const BUBBLES := 18

## "idle", "holding", "tossed" (let go, rising to its pop), "falling" or
## "splashing".
var state := "idle"
var volume := 0.0
var radius := MIN_RADIUS
var age := 0.0
var velocity := Vector3.ZERO
## Ground height under the ball (and its mark) and the pointer's ground
## point while held.
var ground := 0.0
var target := Vector3.ZERO
## The terrain's height at a plate x, z (a Vector2), or null off the land.
## Unset, the ball takes the pointer's ground height.
var ground_at := Callable()
var fish: Array[Dictionary] = []
## The vortex's turned angle (radians) and how hard it churns (0..1).
var swirl := 0.0
var churn := 0.4
## Plate direction from the ball's centre to where it will be popped (the God
## Hand's finger sets it), or zero for its side.
var poke := Vector3.ZERO
var _radius_speed := 0.0
var _jolt := 0.0
var _splash_age := -1.0
var _landing := Vector3.ZERO
var _landed_radius := 0.0
var _funnel := 0.0
var _toss_t := 0.0
var _toss_from := 0.0
var _loose := 0.0
var _shed := 0.0
var _held := 0.0
var _last_volume := 0.0
var _intake := 0.0
var _drip := 0.0
## Ripple rings on the surface: [object-space direction, age begun], a ring
## of RIPPLES the shader reads.
var _ripples := PackedVector4Array()
var _ripple_next := 0
## Drips landed on the ground: [world x, z, age, 1], for the ground shader.
var _drops := PackedVector4Array()
var _drop_next := 0
## Bubbles: each one's [life, phase, orbit, angle, size] draws (0..1), and
## where they are this frame (object space, radius).
var _bubble_draws: Array[PackedFloat32Array] = []
var _bubbles := PackedVector4Array()
## Beads in flight: {"kind": "in", "drip" or "spray", "p" (plate), "v", "size",
## "t", and for "in" the way it spirals: "dir", "from", "turn", "life"}.
var _beads: Array[Dictionary] = []
var _ball: MeshInstance3D
var _material: ShaderMaterial
var _bead_node: MultiMeshInstance3D
var _ground_node: MeshInstance3D
var _ground_material: ShaderMaterial
var _crown: MeshInstance3D
var _crown_material: ShaderMaterial
var _school: Node3D
## Fish meshes by look ("kind seed"), shared by every ball.
static var _fish_meshes := {}
static var _swim_materials := {}

func _ready() -> void:
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/water_ball.gdshader")
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 64
	sphere.rings = 32
	_ball = MeshInstance3D.new()
	_ball.name = "Ball"
	_ball.mesh = sphere
	_ball.material_override = _material
	_ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ball.extra_cull_margin = 0.5
	add_child(_ball)
	_school = Node3D.new()
	_school.name = "Fish"
	add_child(_school)
	# The ground under it: a box the decal shader paints the ground inside.
	_ground_material = ShaderMaterial.new()
	_ground_material.shader = preload("res://shaders/water_ball_ground.gdshader")
	_ground_material.render_priority = -1
	var box := BoxMesh.new()
	_ground_node = MeshInstance3D.new()
	_ground_node.name = "Ground"
	_ground_node.mesh = box
	_ground_node.material_override = _ground_material
	_ground_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ground_node.top_level = true
	add_child(_ground_node)
	_crown_material = ShaderMaterial.new()
	_crown_material.shader = preload("res://shaders/water_splash.gdshader")
	_crown_material.render_priority = 1
	var tube := CylinderMesh.new()
	tube.top_radius = 1.0
	tube.bottom_radius = 1.0
	tube.height = 1.0
	tube.radial_segments = 64
	tube.rings = 8
	tube.cap_top = false
	tube.cap_bottom = false
	_crown = MeshInstance3D.new()
	_crown.name = "Crown"
	_crown.mesh = tube
	_crown.material_override = _crown_material
	_crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_crown.top_level = true
	_crown.custom_aabb = AABB(Vector3(-4,-1,-4),Vector3(8,4,8))
	add_child(_crown)
	var bead_material := ShaderMaterial.new()
	bead_material.shader = preload("res://shaders/water_bead.gdshader")
	bead_material.render_priority = 2
	var bead := SphereMesh.new()
	bead.radius = 1.0
	bead.height = 2.0
	bead.radial_segments = 12
	bead.rings = 6
	var beads := MultiMesh.new()
	beads.transform_format = MultiMesh.TRANSFORM_3D
	beads.use_colors = true
	beads.instance_count = BEADS
	beads.visible_instance_count = 0
	beads.mesh = bead
	_bead_node = MultiMeshInstance3D.new()
	_bead_node.name = "Beads"
	_bead_node.multimesh = beads
	_bead_node.material_override = bead_material
	_bead_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bead_node.top_level = true
	add_child(_bead_node)
	_ripples.resize(RIPPLES)
	_drops.resize(4)
	_bubbles.resize(BUBBLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(BUBBLES):
		_bubble_draws.append(PackedFloat32Array([rng.randf(),rng.randf(),rng.randf(),rng.randf(),rng.randf()]))
	_hide()

## Start a ball over `point` (plate coordinates, on the ground). `fish_material`
## is LandLife's creature material (null: no fish); `salt` picks the fish.
func condense(point: Vector3, fish_material: Material, salt: int) -> void:
	# A ball still in the air lands before the next one forms.
	if state == "falling" or state == "tossed": _impact()
	_finish_splash()
	state = "holding"
	age = 0.0
	volume = 0.0
	radius = 0.0
	_radius_speed = 0.0
	_jolt = 0.4
	_last_volume = 0.0
	_intake = 0.0
	_drip = randf_range(DRIP_SECONDS.x,DRIP_SECONDS.y)+CONDENSE_SECONDS
	velocity = Vector3.ZERO
	ground = point.y
	target = point
	position = point+Vector3.UP*(HOVER+MIN_RADIUS)
	_ground_under()
	_ball.visible = true
	_ball.transform = Transform3D.IDENTITY
	_funnel = 0.0
	_ripples.fill(Vector4.ZERO)
	_drops.fill(Vector4.ZERO)
	_loose = 0.0
	poke = Vector3.ZERO
	_material.set_shader_parameter("burst",0.0)
	_material.set_shader_parameter("landed",0.0)
	_splash_age = -1.0
	_crown.visible = false
	_ground_node.visible = true
	_bead_node.visible = true
	_beads.clear()
	# It gathers out of the air: beads rush in from all round.
	for i in range(CONDENSE_BEADS):
		_bead_in(randf_range(0.8,1.8),randf_range(0.28,0.5))
	_choose_fish(fish_material,salt)

## Follow the pointer's ground point with `water` m³ in the ball.
func hold(point: Variant, water: float) -> void:
	if state != "holding": return
	if point != null:
		target = point
		if not ground_at.is_valid(): ground = point.y
	volume = water

## Let go: tossed straight up, it pops at the top and falls straight down
## onto its mark. What speed it carried shakes the water instead of moving
## it on.
func release() -> void:
	if state != "holding": return
	state = "tossed"
	_toss_t = 0.0
	_toss_from = position.y
	var carried_speed := Vector2(velocity.x,velocity.z).length()
	velocity = Vector3(0.0,2.0*TOSS/POP_SECONDS,0.0)
	_jolt = clampf(maxf(_jolt,0.6+carried_speed*0.06),0.0,1.0)
	_ground_under()

## Seconds until a tossed ball pops (0 once it has, or before it is let go).
func pop_in() -> float:
	return maxf(POP_SECONDS-_toss_t,0.0) if state == "tossed" else 0.0

## The mark's centre on the ground, plate coordinates: straight below the ball.
func mark() -> Vector3:
	return Vector3(position.x,ground,position.z)

## The ground height under the ball's own x, z (not the pointer's), kept
## as it was where there is no land.
func _ground_under() -> bool:
	if not ground_at.is_valid(): return true
	var h: Variant = ground_at.call(Vector2(position.x,position.z))
	if h == null: return false
	ground = h
	return true

func size_for(water: float) -> float:
	return maxf(MIN_RADIUS,pow(3.0*maxf(water,0.0)/(4.0*PI),1.0/3.0))

func carried() -> Array:
	var looks := []
	for entry in fish:
		if entry.shown: looks.append({"kind":entry.kind,"seed":entry.seed,"mirror":entry.mirror})
	return looks

func _process(delta: float) -> void:
	delta = minf(delta,0.05)
	var busy := state != "idle" or not _beads.is_empty() or (_splash_age >= 0.0 and _splash_age < WET_SECONDS)
	if not busy:
		if _ground_node.visible: _hide()
		return
	age += delta
	match state:
		"holding": _step_held(delta)
		"tossed": _step_tossed(delta)
		"falling": _step_fall(delta)
		"splashing": _step_splash(delta)
	if state == "idle" and _splash_age >= 0.0: _splash_age += delta
	_step_beads(delta)
	_paint_ground()
	if state == "idle": return
	_jolt *= exp(-3.0*delta)
	# The vortex spins up with a shake or a quick pull, and its funnel and
	# dimple grow in once there is water enough to hold one.
	var speed := velocity.length()
	churn = lerpf(churn,clampf(0.35+_jolt*0.8+speed*0.08,0.0,1.0),1.0-exp(-4.0*delta))
	swirl += lerpf(1.7,4.4,churn)*delta
	var funnel_goal := smoothstep(0.35,0.9,radius) if state == "holding" else 0.0
	_funnel = lerpf(_funnel,funnel_goal,1.0-exp(-(2.0 if state == "holding" else 6.0)*delta))
	_material.set_shader_parameter("age",age)
	_material.set_shader_parameter("radius",radius)
	_material.set_shader_parameter("wobble",0.025+_jolt*0.12)
	_material.set_shader_parameter("swirl",swirl)
	_material.set_shader_parameter("churn",churn)
	_material.set_shader_parameter("foam",clampf(0.22+_jolt*0.9+speed*0.05,0.0,1.0))
	_material.set_shader_parameter("funnel",_funnel)
	_material.set_shader_parameter("ripples",_ripples)
	_rise_bubbles()
	_material.set_shader_parameter("bubbles",_bubbles)

## Bubbles rise through the vortex from the bottom, drifting in toward the
## core as they climb, and wink out at the top.
func _rise_bubbles() -> void:
	for i in range(BUBBLES):
		var draw := _bubble_draws[i]
		var life := 2.2+draw[0]*2.4
		var phase := fposmod(age/life+draw[1],1.0)
		var y := lerpf(-0.8,0.75,phase)
		var orbit := lerpf(0.12,0.72,draw[2])*sqrt(maxf(1.0-y*y,0.0))*(1.0-phase*0.55)
		var around := draw[3]*TAU+swirl*(1.1+(1.0-orbit)*0.8)
		var size := lerpf(0.012,0.034,draw[4])*smoothstep(0.0,0.1,phase)*smoothstep(1.0,0.85,phase)*(0.6+churn*0.6)
		_bubbles[i] = Vector4(cos(around)*orbit,y,sin(around)*orbit,size)

## A ripple ring from `direction` (object space, on the ball) from now.
func ripple(direction: Vector3) -> void:
	_ripples[_ripple_next] = Vector4(direction.x,direction.y,direction.z,age)
	_ripple_next = (_ripple_next+1)%RIPPLES

func _step_held(delta: float) -> void:
	# Radius swells to the water it holds, overshooting a little.
	var size := size_for(volume)*_condensed()
	var pull := (size-radius)*SWELL-_radius_speed*SWELL_DAMP
	_radius_speed += pull*delta
	radius = maxf(0.0,radius+_radius_speed*delta)
	var bob := sin(age*TAU*BOB_RATE)*BOB*_condensed()
	# It hovers over the higher of the pointer's ground and its own, so it
	# clears a rise it is lagging over.
	var goal := Vector3(target.x,maxf(target.y,ground),target.z)+Vector3.UP*(HOVER+size+bob)
	var before := velocity
	velocity += ((goal-position)*FOLLOW-velocity*FOLLOW_DAMP)*delta
	var was := position
	position += velocity*delta
	# It never swings out past the land's edge, where it could not land.
	if not _ground_under():
		position.x = was.x
		position.z = was.z
		velocity.x = 0.0
		velocity.z = 0.0
	_jolt = minf(1.0,_jolt+(velocity-before).length()*0.02)
	_held = minf(1.0,_held+delta*3.0)
	# While it fills, beads of water spiral in from the air round it.
	if volume > _last_volume+0.0001 and age > CONDENSE_SECONDS:
		_intake += delta*INTAKE_RATE
		while _intake >= 1.0:
			_intake -= 1.0
			_bead_in(radius+randf_range(0.5,1.8),randf_range(0.4,0.7))
	_last_volume = volume
	# Now and then a drip gathers underneath and falls.
	_drip -= delta
	if _drip <= 0.0 and radius > 0.45:
		_drip = randf_range(DRIP_SECONDS.x,DRIP_SECONDS.y)
		var off := Vector2(randf_range(-0.3,0.3),randf_range(-0.3,0.3))*radius
		var under := sqrt(maxf(radius*radius-off.length_squared(),0.0))
		_beads.append({"kind":"drip","p":position+Vector3(off.x,-under,off.y),"v":velocity*0.4+Vector3.DOWN*0.4,"size":randf_range(0.035,0.055),"t":0.0})
	_shape(delta)
	_swim(delta)

## 0 to 1 over CONDENSE_SECONDS, with an overshoot (ease out back).
func _condensed() -> float:
	var t := clampf(age/CONDENSE_SECONDS,0.0,1.0)-1.0
	return 1.0+t*t*(2.70158*t+1.70158)

## Rising on the toss, easing to a hang; the skin trembles more as the pop
## comes.
func _step_tossed(delta: float) -> void:
	_toss_t += delta
	var u := clampf(_toss_t/POP_SECONDS,0.0,1.0)
	position.y = _toss_from+TOSS*(1.0-(1.0-u)*(1.0-u))
	velocity = Vector3(0.0,2.0*TOSS*(1.0-u)/POP_SECONDS,0.0)
	_jolt = maxf(_jolt,0.35+0.35*u)
	_shape(delta)
	_swim(delta)
	if u >= 1.0: _pop()

## The skin bursts: rings run over the water from the popped spot, droplets
## of skin fly out round it, and the water, loose, starts to fall.
func _pop() -> void:
	state = "falling"
	velocity = Vector3.ZERO
	_jolt = 1.0
	_loose = LOOSE
	_shed = 0.0
	_material.set_shader_parameter("burst",_loose)
	var from := poke.normalized() if poke.length_squared() > 0.0001 else Vector3(0.8,0.2,0.56).normalized()
	for k in range(3): _ripples[(_ripple_next+k)%RIPPLES] = Vector4(from.x,from.y,from.z,age-0.06*k)
	_ripple_next = (_ripple_next+3)%RIPPLES
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([position.x,position.z,volume])
	for i in range(POP_SPRAY):
		# Most from round the popped spot, the rest from a ring about it.
		var dir := (from+Vector3(rng.randf_range(-1,1),rng.randf_range(-1,1),rng.randf_range(-1,1))*(0.6 if i < POP_SPRAY/2 else 1.4)).normalized()
		var speed := rng.randf_range(1.8,4.2)*(0.7+radius*0.3)
		_beads.append({"kind":"drip","p":position+dir*radius*1.02,"v":dir*speed+Vector3.UP*rng.randf_range(0.4,1.8),"size":rng.randf_range(0.03,0.07)*(0.7+radius*0.3),"t":0.0})

func _step_fall(delta: float) -> void:
	velocity.y -= GRAVITY*delta
	position += velocity*delta
	_shape(delta)
	_swim(delta)
	# Loose water sheds drops as it falls.
	if _loose > 0.0:
		_shed += delta*SHED_RATE
		while _shed >= 1.0:
			_shed -= 1.0
			var off := Vector2(randf_range(-0.6,0.6),randf_range(-0.6,0.6))*radius
			_beads.append({"kind":"drip","p":position+Vector3(off.x,randf_range(0.2,0.8)*radius,off.y),"v":velocity*randf_range(0.8,0.95)+Vector3(off.x,0.0,off.y)*0.8,"size":randf_range(0.03,0.06),"t":0.0})
	if position.y-radius <= ground: _impact()

## Squash and stretch along the velocity, volume kept.
func _shape(_delta: float) -> void:
	var speed := velocity.length()
	var stretch := clampf(speed*(0.07 if _loose > 0.0 else 0.035),0.0,LOOSE_STRETCH if _loose > 0.0 else 0.35)
	var basis := Basis.from_scale(Vector3.ONE*radius)
	if stretch > 0.01:
		basis = _stretched(velocity/speed,stretch)*basis
	_ball.basis = basis

## A volume-keeping stretch by `stretch` along the unit vector `along`.
func _stretched(along: Vector3, stretch: float) -> Basis:
	var side := along.cross(Vector3.UP if absf(along.y) < 0.95 else Vector3.RIGHT).normalized()
	var third := along.cross(side)
	var frame := Basis(side,along,third)
	var thin := 1.0/sqrt(1.0+stretch)
	return frame*Basis.from_scale(Vector3(thin,1.0+stretch,thin))*frame.transposed()

func _impact() -> void:
	state = "splashing"
	_splash_age = 0.0
	_landing = Vector3(position.x,ground,position.z)
	_landed_radius = radius
	_held = 0.0
	position.y = ground+radius
	_jolt = 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_landing.x,_landing.z,volume])
	# Spray from the rim, the most of it low and fast, a few thrown high.
	for i in range(SPRAY):
		var angle := TAU*(float(i)+rng.randf()*0.8)/SPRAY
		var out := Vector3(cos(angle),0,sin(angle))
		var high := rng.randf() < 0.25
		var speed := rng.randf_range(1.6,3.8)*(0.6+radius*0.45)
		var lift := rng.randf_range(4.0,6.5) if high else rng.randf_range(1.5,3.5)
		_beads.append({"kind":"spray","p":_landing+out*radius*rng.randf_range(0.8,1.1)+Vector3.UP*rng.randf_range(0.05,0.3)*radius,
			"v":out*speed*(0.6 if high else 1.0)+Vector3.UP*lift*(0.75+radius*0.2),"size":rng.randf_range(0.03,0.085)*(0.7+radius*0.3),"t":0.0})
	for i in range(fish.size()):
		var entry: Dictionary = fish[i]
		if not entry.shown: continue
		var angle := float(entry.angle)+rng.randf_range(-0.3,0.3)
		var out := Vector3(cos(angle),0,sin(angle))
		entry.leap = out*rng.randf_range(1.2,2.2)*(0.7+radius*0.3)+Vector3.UP*rng.randf_range(3.2,4.6)
		entry.at = position+_school.position+entry.node.position
		entry.spin = rng.randf_range(-6.0,6.0)
	_funnel = 0.0
	_material.set_shader_parameter("landed",1.0)
	_crown.visible = true
	_crown_material.set_shader_parameter("seed",rng.randf()*TAU)
	landed.emit(Vector2(_landing.x,_landing.z),volume,carried())

func _step_splash(delta: float) -> void:
	_splash_age += delta
	var t := _splash_age
	# It flattens onto the ground, then spreads into a thin wash that bursts
	# into foam and is gone.
	var squash := clampf(t/SQUASH_SECONDS,0.0,1.0)
	var spread := clampf((t-SQUASH_SECONDS*0.6)/SPREAD_SECONDS,0.0,1.0)
	spread = 1.0-pow(1.0-spread,3.0)
	var flat := lerpf(1.0,0.45,squash*squash)*lerpf(1.0,0.3,spread)
	var wide := lerpf(1.0/sqrt(lerpf(1.0,0.45,squash*squash)),2.0,spread)
	var r := _landed_radius
	_ball.basis = Basis.from_scale(Vector3(r*wide,r*flat,r*wide))
	position = _landing+Vector3.UP*r*flat*0.85
	var burst := maxf(clampf((t-SQUASH_SECONDS*0.8)/(SPREAD_SECONDS*0.8),0.0,1.0),_loose)
	_material.set_shader_parameter("burst",burst)
	_ball.visible = burst < 1.0
	var crown := clampf(t/CROWN_SECONDS,0.0,1.0)
	_crown.visible = crown < 1.0
	_crown_material.set_shader_parameter("progress",crown)
	_crown_material.set_shader_parameter("base",r*1.05)
	_crown_material.set_shader_parameter("tall",r*(0.75+0.25*minf(r,1.5)))
	_crown.global_transform = Transform3D(Basis.IDENTITY,(get_parent() as Node3D).to_global(_landing))
	for entry: Dictionary in fish:
		if not entry.shown or not entry.has("leap"): continue
		entry.leap.y -= 9.8*delta
		entry.at += entry.leap*delta
		var node: MultiMeshInstance3D = entry.node
		node.position = entry.at-position-_school.position
		var heading: Vector3 = entry.leap.normalized()
		var basis := Basis.looking_at(-heading,Vector3.UP) if absf(heading.y) < 0.99 else Basis.IDENTITY
		basis = basis*Basis(Vector3.FORWARD,float(entry.spin)*t)
		var under := clampf((_landing.y+0.05-float(entry.at.y))/0.3,0.0,1.0)
		node.basis = basis*Basis.from_scale(_fish_scale(entry)*(1.0-under)+Vector3.ONE*0.00001)
		# A fish diving back in throws a little splash of its own.
		if under > 0.0 and not entry.get("dived",false):
			entry.dived = true
			for k in range(6):
				var out := Vector3.RIGHT.rotated(Vector3.UP,TAU*k/6.0+randf())
				_beads.append({"kind":"spray","p":Vector3(entry.at.x,_landing.y+0.05,entry.at.z),"v":out*randf_range(0.6,1.3)+Vector3.UP*randf_range(1.5,2.6),"size":randf_range(0.02,0.04),"t":0.0})
	if t >= SPLASH_SECONDS: _finish_splash()

## Intake beads spiral in, drips and spray fall; all are drawn as one MultiMesh.
func _step_beads(delta: float) -> void:
	var kept: Array[Dictionary] = []
	for bead: Dictionary in _beads:
		bead.t = float(bead.t)+delta
		var p: Vector3 = bead.p
		if bead.kind == "in":
			if state != "holding" or radius <= 0.0: continue
			var f: float = clampf(float(bead.t)/float(bead.life),0.0,1.0)
			var ease := f*f
			var dir: Vector3 = Vector3(bead.dir).rotated(Vector3.UP,float(bead.turn)*f)
			var reach := lerpf(float(bead.from),radius,ease)
			var next := position+dir*reach
			bead.v = (next-p)/maxf(delta,0.001)
			bead.p = next
			if f >= 1.0:
				ripple(dir)
				continue
		else:
			var v: Vector3 = bead.v
			v.y -= (GRAVITY if bead.kind == "drip" else 11.0)*delta
			bead.v = v
			bead.p = p+v*delta
			var floor_y := ground if bead.kind == "drip" else _landing.y
			if float(bead.p.y) <= floor_y:
				if bead.kind == "drip": _drop_ring(Vector3(bead.p.x,floor_y,bead.p.z))
				continue
		kept.append(bead)
	_beads = kept
	var beads := _bead_node.multimesh
	var count := mini(_beads.size(),BEADS)
	beads.visible_instance_count = count
	_bead_node.global_transform = get_parent().global_transform
	for i in range(count):
		var bead: Dictionary = _beads[i]
		var v: Vector3 = bead.v
		var speed := v.length()
		var basis := Basis.from_scale(Vector3.ONE*float(bead.size))
		if speed > 0.2: basis = _stretched(v/speed,clampf(speed*(0.35 if bead.kind == "in" else 0.12),0.0,2.5))*basis
		var fade := 1.0
		if bead.kind == "in": fade = smoothstep(0.0,0.25,float(bead.t)/float(bead.life))
		elif bead.kind == "spray": fade = 1.0-smoothstep(1.0,1.6,float(bead.t))
		beads.set_instance_transform(i,Transform3D(basis,bead.p))
		beads.set_instance_color(i,Color(1,1,1,fade))

## A bead spiralling in from `from` m out, over `life` s.
func _bead_in(from: float, life: float) -> void:
	var up := randf_range(-0.75,0.6)
	var around := randf()*TAU
	var dir := Vector3(cos(around)*sqrt(1.0-up*up),up,sin(around)*sqrt(1.0-up*up))
	var p := position+dir*from
	_beads.append({"kind":"in","p":p,"v":Vector3.ZERO,"size":randf_range(0.035,0.07),"t":0.0,"dir":dir,"from":from,"turn":randf_range(0.8,1.8),"life":life})

func _drop_ring(point: Vector3) -> void:
	var world: Vector3 = (get_parent() as Node3D).to_global(point)
	_drops[_drop_next] = Vector4(world.x,world.z,age,1.0)
	_drop_next = (_drop_next+1)%_drops.size()

## The ground under the ball: its mark while held and falling, drips, the splash.
func _paint_ground() -> void:
	var r := radius if _splash_age < 0.0 else _landed_radius
	var at := position if _splash_age < 0.0 else _landing+Vector3.UP*r
	var floor_y := ground if _splash_age < 0.0 else _landing.y
	var span := maxf(r*SPLASH_REACH*1.3,r*3.0)+1.0
	var parent := get_parent() as Node3D
	var center := parent.to_global(Vector3(at.x,floor_y,at.z))
	_ground_node.global_transform = Transform3D(Basis.from_scale(Vector3(span*2.0,6.0,span*2.0)),center)
	_ground_node.visible = r > 0.05
	_ground_material.set_shader_parameter("ball_center",parent.to_global(at))
	_ground_material.set_shader_parameter("radius",maxf(r,0.05))
	_ground_material.set_shader_parameter("mark",_held*smoothstep(0.05,0.3,r))
	_ground_material.set_shader_parameter("breath",sin(age*TAU*BOB_RATE)*_condensed() if _splash_age < 0.0 else 0.0)
	var ceiling := floor_y+(HOVER*0.8 if _splash_age < 0.0 else 0.6)
	_ground_material.set_shader_parameter("ceiling",parent.to_global(Vector3(at.x,ceiling,at.z)).y)
	_ground_material.set_shader_parameter("splash",_splash_age)
	_ground_material.set_shader_parameter("reach",r*SPLASH_REACH)
	_ground_material.set_shader_parameter("drops",_drops)
	_ground_material.set_shader_parameter("age",age)

func _finish_splash() -> void:
	state = "idle"
	_ball.visible = false
	_crown.visible = false
	for entry: Dictionary in fish: entry.node.queue_free()
	fish.clear()

func _hide() -> void:
	if _ball == null: return
	_finish_splash()
	_ground_node.visible = false
	_bead_node.visible = false
	_beads.clear()
	_splash_age = -1.0

# --- Fish -------------------------------------------------------------------

## Pick a pond company and FISH_MAX of its kinds; they show as the ball grows.
func _choose_fish(material: Material, salt: int) -> void:
	for entry: Dictionary in fish: entry.node.queue_free()
	fish.clear()
	if material == null: return
	var company: Array = Models.FISH_PONDS[int(Variety.unit([salt,1])*Models.FISH_PONDS.size())]
	for i in range(FISH_MAX):
		var weights: Array = company.map(func(pair: Array) -> float: return pair[1])
		var kind: String = company[Variety.weighted(weights,Variety.unit([salt,i,2]))][0]
		var seed := int(Variety.unit([salt,i,3])*float(Models.FISH_KINDS[kind].get("seeds",1)))
		var node := MultiMeshInstance3D.new()
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.use_colors = true
		instances.instance_count = 1
		instances.mesh = _fish_mesh(material,kind,seed)
		# A new MultiMesh's transforms are all zero; without this it draws nothing.
		instances.set_instance_transform(0,Transform3D.IDENTITY)
		instances.set_instance_color(0,Color.WHITE)
		node.multimesh = instances
		node.material_override = _swim_material(material,kind)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visible = false
		_school.add_child(node)
		fish.append({"kind":kind,"seed":seed,"mirror":Variety.unit([salt,i,4]) < 0.5,"node":node,"shown":false,"born":0.0,
			"angle":Variety.unit([salt,i,5])*TAU,"turn":lerpf(0.9,1.5,Variety.unit([salt,i,6]))*(1.0 if i%2 == 0 else -1.0),
			"height":lerpf(-0.35,0.3,Variety.unit([salt,i,7])),"orbit":lerpf(0.35,0.55,Variety.unit([salt,i,8])),
			"weave":lerpf(0.7,1.4,Variety.unit([salt,i,9])),"phase":Variety.unit([salt,i,10])*TAU})

func _fish_mesh(material: Material, kind: String, seed: int) -> Mesh:
	var key := "%s %d %d" % [kind,seed,material.get_instance_id()]
	if not _fish_meshes.has(key): _fish_meshes[key] = Models.fish(material,kind,seed)
	return _fish_meshes[key]

## As LandLife gives its fish: the creature material with the tail beat on.
func _swim_material(material: Material, kind: String) -> Material:
	var key := "%s %d" % [kind,material.get_instance_id()]
	if not _swim_materials.has(key):
		var swim: ShaderMaterial = material.duplicate()
		swim.set_shader_parameter("fish_swim",true)
		swim.set_shader_parameter("fish_wave",Models.fish_wave(kind))
		_swim_materials[key] = swim
	return _swim_materials[key]

func _fish_scale(entry: Dictionary) -> Vector3:
	var length: float = Models.FISH_KINDS[entry.kind].length
	var size := clampf(radius*FISH_LENGTH/length,0.2,FISH_GROWN)
	return Vector3(-size if entry.mirror else size,size,size)

## Ride the vortex inside the ball: round the axis at their own pace, half
## of them against the swirl, weaving up and down, banking in toward the
## core, quicker as the water churns.
func _swim(delta: float) -> void:
	_school.position = _ball.position
	var count := clampi(FISH_MIN+int(volume/FISH_PER_VOLUME),FISH_MIN,FISH_MAX)
	var pace := lerpf(0.85,1.7,churn)
	for i in range(fish.size()):
		var entry: Dictionary = fish[i]
		if i < count and not entry.shown and radius > MIN_RADIUS*0.9:
			entry.shown = true
			entry.born = age
			entry.node.visible = true
		if not entry.shown: continue
		var phase: float = entry.phase
		var weave: float = entry.weave
		var turn: float = float(entry.turn)*pace*(1.0+0.3*sin(age*1.3+phase))
		entry.angle = float(entry.angle)+turn*delta
		var angle: float = entry.angle
		var y := clampf(float(entry.height)+sin(age*weave+phase)*0.2,-0.5,0.5)
		var reach: float = float(entry.orbit)*(1.0+0.12*sin(age*0.9+phase*2.0))*sqrt(maxf(1.0-y*y,0.2))
		var p := Vector3(cos(angle)*reach,y,sin(angle)*reach)*radius
		var inward := -Vector3(cos(angle),0,sin(angle))
		var heading := (Vector3(-sin(angle),0,cos(angle))*reach*turn+Vector3.UP*cos(age*weave+phase)*weave*0.2).normalized()
		var up := (Vector3.UP+inward*0.55).normalized()
		var grow := smoothstep(0.0,0.5,age-float(entry.born))
		var node: MultiMeshInstance3D = entry.node
		node.position = p
		node.basis = Basis.looking_at(-heading,up)*Basis.from_scale(_fish_scale(entry)*grow+Vector3.ONE*0.00001)
