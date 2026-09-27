extends Node3D
## A ball of water in the hand (docs/scenic/water-brush.md "Water ball"). With
## water in hand a press condenses a swirling ball of the ponds' own water
## (shaders/water_ball.gdshader) above the ground, with a few fish circling
## inside; it grows while the button is held and follows the pointer on a
## spring, bobbing and wobbling. Release drops it: it hops, falls, squashes on
## the ground and bursts into a ring, droplets and leaping fish, and `landed`
## hands its water and fish to the editor (NativeChunkEditor `_ball_landed`),
## which settles the water as one pour and lets the fish into the pond it made.
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
## so the ball overshoots and settles behind a quick pointer.
const FOLLOW := 60.0
const FOLLOW_DAMP := 11.0
## The radius spring: a growing ball swells past its size and settles.
const SWELL := 90.0
const SWELL_DAMP := 9.0
## Metres and hertz of the idle bob.
const BOB := 0.07
const BOB_RATE := 0.55
## Seconds for a new ball to condense out of the air.
const CONDENSE_SECONDS := 0.35
## Release: the anticipation hop (m/s up), then gravity (m/s²).
const HOP := 1.4
const GRAVITY := 18.0
## Seconds the impact squash takes, and the whole splash.
const SQUASH_SECONDS := 0.14
const SPLASH_SECONDS := 1.3
const DROPLETS := 14
## Fish: how many a ball of V m³ carries (2 + V/FISH_PER_VOLUME, at most
## FISH_MAX), and their length as a share of the ball's radius.
const FISH_MIN := 2
const FISH_MAX := 5
const FISH_PER_VOLUME := 5.0
const FISH_LENGTH := 0.55

## "idle", "holding", "falling" or "splashing".
var state := "idle"
var volume := 0.0
var radius := MIN_RADIUS
var age := 0.0
var velocity := Vector3.ZERO
## Ground height under the ball and the pointer's ground point while held.
var ground := 0.0
var target := Vector3.ZERO
var fish: Array[Dictionary] = []
var _radius_speed := 0.0
var _jolt := 0.0
var _splash_age := 0.0
var _landing := Vector3.ZERO
var _ball: MeshInstance3D
var _material: ShaderMaterial
var _ring: MeshInstance3D
var _ring_material: StandardMaterial3D
var _droplets: Array[Dictionary] = []
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
	sphere.radial_segments = 48
	sphere.rings = 24
	_ball = MeshInstance3D.new()
	_ball.name = "Ball"
	_ball.mesh = sphere
	_ball.material_override = _material
	_ball.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ball)
	_school = Node3D.new()
	_school.name = "Fish"
	add_child(_school)
	_ring_material = StandardMaterial3D.new()
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ring_material.albedo_color = Color(0.82,0.92,0.92,0.0)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.92
	torus.outer_radius = 1.0
	torus.rings = 48
	torus.ring_segments = 6
	_ring = MeshInstance3D.new()
	_ring.name = "Ring"
	_ring.mesh = torus
	_ring.material_override = _ring_material
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	var drop_material := ShaderMaterial.new()
	drop_material.shader = _material.shader
	drop_material.set_shader_parameter("radius",0.08)
	drop_material.set_shader_parameter("wobble",0.0)
	var drop_mesh := SphereMesh.new()
	drop_mesh.radius = 1.0
	drop_mesh.height = 2.0
	drop_mesh.radial_segments = 12
	drop_mesh.rings = 6
	for i in range(DROPLETS):
		var node := MeshInstance3D.new()
		node.mesh = drop_mesh
		node.material_override = drop_material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		_droplets.append({"node":node,"v":Vector3.ZERO})
	_hide()

## Start a ball over `point` (plate coordinates, on the ground). `fish_material`
## is LandLife's creature material (null: no fish); `salt` picks the fish.
func condense(point: Vector3, fish_material: Material, salt: int) -> void:
	# A ball still falling lands before the next one forms.
	if state == "falling": _impact()
	_finish_splash()
	state = "holding"
	age = 0.0
	volume = 0.0
	radius = 0.0
	_radius_speed = 0.0
	_jolt = 0.4
	velocity = Vector3.ZERO
	ground = point.y
	target = point
	position = point+Vector3.UP*(HOVER+MIN_RADIUS)
	_ball.visible = true
	_ball.transform = Transform3D.IDENTITY
	_material.set_shader_parameter("burst",0.0)
	_choose_fish(fish_material,salt)

## Follow the pointer's ground point with `water` m³ in the ball.
func hold(point: Variant, water: float) -> void:
	if state != "holding": return
	if point != null:
		target = point
		ground = point.y
	volume = water

## Let go: a small hop, then it falls straight down.
func release() -> void:
	if state != "holding": return
	state = "falling"
	velocity = Vector3(velocity.x*0.25,HOP,velocity.z*0.25)
	_jolt = maxf(_jolt,0.6)

func size_for(water: float) -> float:
	return maxf(MIN_RADIUS,pow(3.0*maxf(water,0.0)/(4.0*PI),1.0/3.0))

func carried() -> Array:
	var looks := []
	for entry in fish:
		if entry.shown: looks.append({"kind":entry.kind,"seed":entry.seed,"mirror":entry.mirror})
	return looks

func _process(delta: float) -> void:
	delta = minf(delta,0.05)
	match state:
		"holding": _step_held(delta)
		"falling": _step_fall(delta)
		"splashing": _step_splash(delta)
		_: return
	age += delta
	_jolt *= exp(-3.0*delta)
	_material.set_shader_parameter("age",age)
	_material.set_shader_parameter("radius",radius)
	_material.set_shader_parameter("wobble",0.025+_jolt*0.12)

func _step_held(delta: float) -> void:
	# Radius swells to the water it holds, overshooting a little.
	var size := size_for(volume)*_condensed()
	var pull := (size-radius)*SWELL-_radius_speed*SWELL_DAMP
	_radius_speed += pull*delta
	radius = maxf(0.0,radius+_radius_speed*delta)
	var bob := sin(age*TAU*BOB_RATE)*BOB*_condensed()
	var goal := target+Vector3.UP*(HOVER+size+bob)
	var before := velocity
	velocity += ((goal-position)*FOLLOW-velocity*FOLLOW_DAMP)*delta
	position += velocity*delta
	_jolt = minf(1.0,_jolt+(velocity-before).length()*0.02)
	_shape(delta)
	_swim(delta)

## 0 to 1 over CONDENSE_SECONDS, with an overshoot (ease out back).
func _condensed() -> float:
	var t := clampf(age/CONDENSE_SECONDS,0.0,1.0)-1.0
	return 1.0+t*t*(2.70158*t+1.70158)

func _step_fall(delta: float) -> void:
	velocity.y -= GRAVITY*delta
	position += velocity*delta
	_shape(delta)
	_swim(delta)
	if position.y-radius <= ground: _impact()

## Squash and stretch along the velocity, volume kept.
func _shape(_delta: float) -> void:
	var speed := velocity.length()
	var stretch := clampf(speed*0.035,0.0,0.35)
	var basis := Basis.from_scale(Vector3.ONE*radius)
	if stretch > 0.01:
		var along := velocity/speed
		var side := along.cross(Vector3.UP if absf(along.y) < 0.95 else Vector3.RIGHT).normalized()
		var third := along.cross(side)
		var frame := Basis(side,along,third)
		var thin := 1.0/sqrt(1.0+stretch)
		basis = frame*Basis.from_scale(Vector3(thin,1.0+stretch,thin))*frame.transposed()*basis
	_ball.basis = basis

func _impact() -> void:
	state = "splashing"
	_splash_age = 0.0
	_landing = Vector3(position.x,ground,position.z)
	position.y = ground+radius
	_jolt = 1.0
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_landing.x,_landing.z,volume])
	for i in range(DROPLETS):
		var drop: Dictionary = _droplets[i]
		var angle := TAU*(float(i)+rng.randf()*0.6)/DROPLETS
		var out := Vector3(cos(angle),0,sin(angle))
		drop.node.visible = true
		drop.node.position = _landing+out*radius*0.8+Vector3.UP*radius*0.3
		drop.v = out*rng.randf_range(1.6,3.2)*(0.6+radius*0.5)+Vector3.UP*rng.randf_range(2.5,4.5)
		drop.size = rng.randf_range(0.04,0.1)*(0.7+radius*0.3)
		drop.node.scale = Vector3.ONE*drop.size
	for i in range(fish.size()):
		var entry: Dictionary = fish[i]
		if not entry.shown: continue
		var angle := float(entry.angle)+rng.randf_range(-0.3,0.3)
		var out := Vector3(cos(angle),0,sin(angle))
		entry.leap = out*rng.randf_range(1.2,2.2)*(0.7+radius*0.3)+Vector3.UP*rng.randf_range(2.8,4.0)
		entry.at = _school.position+entry.node.position
		entry.spin = rng.randf_range(-6.0,6.0)
	_ring.visible = true
	landed.emit(Vector2(_landing.x,_landing.z),volume,carried())

func _step_splash(delta: float) -> void:
	_splash_age += delta
	# The ball flattens onto the ground and bursts into foam.
	var squash := clampf(_splash_age/SQUASH_SECONDS,0.0,1.0)
	var flat := lerpf(1.0,0.3,squash*squash)
	_ball.basis = Basis.from_scale(Vector3(radius/sqrt(flat),radius*flat,radius/sqrt(flat)))
	position = _landing+Vector3.UP*radius*flat
	var burst := clampf((_splash_age-SQUASH_SECONDS*0.5)/0.3,0.0,1.0)
	_material.set_shader_parameter("burst",burst)
	_ball.visible = burst < 1.0
	# A ring runs out over the ground.
	var ring_t := clampf(_splash_age/0.9,0.0,1.0)
	var reach := radius*lerpf(1.0,3.2,1.0-pow(1.0-ring_t,3.0))
	_ring.position = _landing-position+Vector3.UP*0.04
	_ring.scale = Vector3(reach,0.4,reach)
	_ring_material.albedo_color.a = 0.55*(1.0-ring_t)
	for drop: Dictionary in _droplets:
		var node: MeshInstance3D = drop.node
		if not node.visible: continue
		drop.v.y -= GRAVITY*0.7*delta
		node.position += drop.v*delta
		if node.position.y < _landing.y-0.1: node.visible = false
	for entry: Dictionary in fish:
		if not entry.shown or not entry.has("leap"): continue
		entry.leap.y -= 9.8*delta
		entry.at += entry.leap*delta
		var node: MultiMeshInstance3D = entry.node
		node.position = entry.at-_school.position
		var heading: Vector3 = entry.leap.normalized()
		var basis := Basis.looking_at(-heading,Vector3.UP) if absf(heading.y) < 0.99 else Basis.IDENTITY
		basis = basis*Basis(Vector3.FORWARD,float(entry.spin)*_splash_age)
		var under := clampf((_landing.y-entry.at.y)/0.3,0.0,1.0)
		node.basis = basis*Basis.from_scale(_fish_scale(entry)*(1.0-under)+Vector3.ONE*0.00001)
	if _splash_age >= SPLASH_SECONDS: _finish_splash()

func _finish_splash() -> void:
	state = "idle"
	_hide()

func _hide() -> void:
	if _ball == null: return
	_ball.visible = false
	_ring.visible = false
	for drop: Dictionary in _droplets: drop.node.visible = false
	for entry: Dictionary in fish: entry.node.queue_free()
	fish.clear()

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
		instances.set_instance_color(0,Color.WHITE)
		node.multimesh = instances
		node.material_override = _swim_material(material,kind)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visible = false
		_school.add_child(node)
		fish.append({"kind":kind,"seed":seed,"mirror":Variety.unit([salt,i,4]) < 0.5,"node":node,"shown":false,"born":0.0,
			"angle":Variety.unit([salt,i,5])*TAU,"turn":lerpf(0.9,1.5,Variety.unit([salt,i,6]))*(1.0 if i%2 == 0 else -1.0),
			"height":lerpf(-0.35,0.3,Variety.unit([salt,i,7])),"orbit":lerpf(0.35,0.55,Variety.unit([salt,i,8]))})

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
	var size := clampf(radius*FISH_LENGTH/length,0.2,1.0)
	return Vector3(-size if entry.mirror else size,size,size)

## Circle inside the ball, each at its own depth and pace, half of them the
## other way round, so the school turns against the swirl.
func _swim(delta: float) -> void:
	_school.position = _ball.position
	var count := clampi(FISH_MIN+int(volume/FISH_PER_VOLUME),FISH_MIN,FISH_MAX)
	for i in range(fish.size()):
		var entry: Dictionary = fish[i]
		if i < count and not entry.shown and radius > MIN_RADIUS*0.9:
			entry.shown = true
			entry.born = age
			entry.node.visible = true
		if not entry.shown: continue
		entry.angle = float(entry.angle)+float(entry.turn)*delta
		var angle: float = entry.angle
		var reach: float = float(entry.orbit)*radius
		var p := Vector3(cos(angle)*reach,float(entry.height)*radius+sin(age*1.7+float(i))*0.05*radius,sin(angle)*reach)
		var heading := Vector3(-sin(angle),0,cos(angle))*signf(float(entry.turn))
		var grow := smoothstep(0.0,0.5,age-float(entry.born))
		var node: MultiMeshInstance3D = entry.node
		node.position = p
		node.basis = Basis(Vector3.UP,atan2(heading.x,heading.z))*Basis.from_scale(_fish_scale(entry)*grow+Vector3.ONE*0.00001)
