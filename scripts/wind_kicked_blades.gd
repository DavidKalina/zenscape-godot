extends MultiMeshInstance3D
const LeafMesh := preload("res://scripts/leaf_litter_mesh.gd")
## Single grass blades kicked up by a sweeping breeze ribbon, cosmetic only (no
## saves or gameplay state). Smaller and lighter than the grass chaff.
##
## While a ribbon skims the ground, blades are plucked from the grass under
## it and dragged along low. As it lifts off, the updraft takes them up in a
## spiral, tumbling and spinning a metre or three, and when the air lets go
## they flutter down, rest on the ground a moment and fade. A blade over water
## or off the plate drifts down and fades. All air comes from the ribbons
## (`kicks()`, `air_at()`) and the ambient breeze, read as the leaf litter does.
const CAPACITY := 220
## Blades per second from one full-strength kick moving at SPEED_REF, while it
## skims, and the extra burst (blades) as it lifts off.
const SKIM_RATE := 60.0
const LIFT_BURST := 24
const SPEED_REF := 6.0
## Lift (0..1) at which a ribbon counts as lifting off, for the burst.
const LIFT_ONSET := 0.3
## Metres a blade is scattered from the ribbon's track, and how far behind the
## head it can start (m).
const SCATTER := 0.8
const BEHIND := 0.7
## Grass cover (0..1) under a spawn point below which no blade is plucked,
## when a cover is given; without one, any dry ground grows them.
const MIN_COVER := 0.4
## Ground steeper than this (normal's y) is cliff or rock: no blades there.
const MIN_LEVEL := 0.75
## Seconds a blade lives (random), and how long it takes to fade in and out.
const LIFE := Vector2(2.0,4.0)
const FADE_IN := 0.15
const FADE_OUT := 0.7
## Blade length (m), long enough to read from the diorama's distance, and
## weight (lighter than chaff's 0.5-0.75).
const SIZE := Vector2(0.16,0.28)
const WEIGHT := Vector2(0.25,0.4)
## 1/s how quickly a blade takes up the air's velocity, and the speed (m/s) it
## sinks at in still air (drag-dominated, so slow).
const DRAG := 3.0
const SINK := 0.55
## Upward pop (m/s) when plucked, 1/s extra friction on the ground, and the
## ambient breeze's share of the wind a blade feels.
const POP := Vector2(0.5,1.4)
const GROUND_FRICTION := 5.0
const BREEZE := 1.2
## Spiral about the ribbon's head (m/s at full lift) within SPIRAL_REACH (m),
## the tumble end over end and the spin (rad/s) while aloft, and the flutter
## (m/s²) sideways as it falls.
const SPIRAL := 2.2
const SPIRAL_REACH := 1.6
const TUMBLE := Vector2(5.0,11.0)
const SPIN := Vector2(2.0,6.0)
const FLUTTER := 1.6
## Height (m) a resting blade lies above the ground.
const REST := 0.012
## Physics steps at most this long, so contact stays stable at any frame rate.
const MAX_STEP := 1.0/50.0
const COLORS := ["4f8c3a","5f9a40","6fa84a","7db04f","8fb85a","b9c47e","cfc98f"]
var blades: Array[Dictionary] = []
var ground_height: Callable
var cover: Callable
var _clock := 0.0
var _rng := RandomNumberGenerator.new()
var _owed := {}
var _lifted := {}
var _centres := {}

func _init() -> void:
	name = "WindKickedBlades"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	# The leaf shader reads INSTANCE_CUSTOM; zero keeps the blade whole.
	multimesh.use_custom_data = true
	multimesh.mesh = _blade_mesh()
	multimesh.instance_count = CAPACITY
	multimesh.visible_instance_count = 0
	material_override = LeafMesh.material()
	custom_aabb = AABB(Vector3(-16,-3,-16),Vector3(32,32,32))
	_rng.seed = 3307

## `probe(Vector2)` is the ground height or null (water, off the plate);
## `cover(Vector2)` is grass cover, 0..1, or none for bare ground to count
## as grass too. Both in this node's space.
func setup(probe: Callable, grass := Callable()) -> void:
	ground_height = probe
	cover = grass
	clear()

func clear() -> void:
	blades.clear()
	_owed.clear()
	_lifted.clear()
	_centres.clear()
	multimesh.visible_instance_count = 0

## A thin blade lying along z, 1 long and 0.09 wide before scaling, folded
## along its midrib, bent up a little and tapered to a point. Dark at the root,
## light and yellowish at the tip (tinted by the instance colour). Flat facets.
static func _blade_mesh() -> Mesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rib := [Vector3(0,0.03,-0.5),Vector3(0,0.05,-0.15),Vector3(0,0.07,0.2),Vector3(0.0,0.05,0.5)]
	var half := [0.06,0.07,0.045,0.0]
	var shade := [Color(0.5,0.68,0.45),Color(0.8,0.9,0.7),Color(0.97,1.0,0.8),Color(1.0,1.0,0.85)]
	for k in range(3):
		for side in [-1.0,1.0]:
			var a: Vector3 = rib[k]
			var b: Vector3 = rib[k+1]
			var a_edge := a+Vector3(side*half[k],-0.012,0)
			var b_edge := b+Vector3(side*half[k+1],-0.012,0)
			var corners := [[a,shade[k]],[a_edge,shade[k]],[b_edge,shade[k+1]],[a,shade[k]],[b_edge,shade[k+1]],[b,shade[k+1]]]
			if side < 0.0: corners.reverse()
			for corner in corners:
				surface.set_color(corner[1])
				surface.add_vertex(corner[0])
	surface.generate_normals()
	return surface.commit()

## Spawns from `ribbons.kicks()` and moves the blades in `ribbons.air_at()` and,
## when given, the ambient breeze of `air`. A node without those methods (old
## trails) adds nothing.
func advance(delta: float, paused: bool, ribbons: Node, air: Node = null) -> void:
	if paused or delta <= 0.0 or not is_finite(delta) or not ground_height.is_valid(): return
	var span := minf(delta,0.1)
	var steps := ceili(span/MAX_STEP)
	for k in range(steps): _step(span/steps,ribbons,air)
	_draw()

func _step(dt: float, ribbons: Node, air: Node) -> void:
	_clock += dt
	var has_kicks := is_instance_valid(ribbons) and ribbons.has_method("kicks")
	var has_air := is_instance_valid(ribbons) and ribbons.has_method("air_at")
	_centres.clear()
	if has_kicks:
		var seen := {}
		for kick: Dictionary in ribbons.kicks():
			var id: int = kick.id
			seen[id] = true
			_centres[id] = kick
			_spawn(kick,dt)
		for id in _owed.keys():
			if not seen.has(id):
				_owed.erase(id)
				_lifted.erase(id)
	var ambient := Vector3.ZERO
	if air != null:
		ambient = Vector3(cos(air._air_angle),0,sin(air._air_angle))*air._air_strength*air.gust_at(air._wind_time)*BREEZE
	var index := 0
	while index < blades.size():
		var blade := blades[index]
		blade.age = float(blade.age)+dt
		if float(blade.age) >= float(blade.life):
			blades.remove_at(index)
			continue
		_move(blade,dt,ribbons if has_air else null,ambient)
		index += 1

func _spawn(kick: Dictionary, dt: float) -> void:
	var id: int = kick.id
	var strength := clampf(float(kick.strength),0.0,1.0)
	var lift := clampf(float(kick.lift),0.0,1.0)
	var vel: Vector3 = kick.vel
	var flat := Vector2(vel.x,vel.z)
	var speed := flat.length()
	var heading := flat/speed if speed > 0.001 else Vector2.RIGHT
	var owed: float = _owed.get(id,0.0)
	owed += strength*clampf(speed/SPEED_REF,0.0,1.6)*SKIM_RATE*dt
	var was: float = _lifted.get(id,0.0)
	if was < LIFT_ONSET and lift >= LIFT_ONSET: owed += LIFT_BURST*strength
	_lifted[id] = lift
	var count := int(owed)
	_owed[id] = owed-count
	var at: Vector3 = kick.at
	for n in range(count):
		var point := Vector2(at.x,at.z)-heading*_rng.randf()*BEHIND+Vector2.from_angle(_rng.randf()*TAU)*SCATTER*sqrt(_rng.randf())
		if cover.is_valid() and float(cover.call(point)) <= MIN_COVER: continue
		var height: Variant = ground_height.call(point)
		if height == null or not is_finite(float(height)): continue
		if _ground_normal(point,float(height)).y < MIN_LEVEL: continue
		var launch := Vector3(vel.x,0,vel.z)*_rng.randf_range(0.2,0.5)+Vector3.UP*_rng.randf_range(POP.x,POP.y)*(0.6+0.8*lift)
		var blade := {"position":Vector3(point.x,float(height)+REST,point.y),"velocity":launch,"age":0.0,"life":_rng.randf_range(LIFE.x,LIFE.y),
			"size":_rng.randf_range(SIZE.x,SIZE.y),"weight":_rng.randf_range(WEIGHT.x,WEIGHT.y),"id":id,"phase":_rng.randf()*TAU,
			"yaw":_rng.randf()*TAU,"tumble":_rng.randf()*TAU,"roll":_rng.randf()*TAU,"tumble_rate":_rng.randf_range(TUMBLE.x,TUMBLE.y)*(1.0 if _rng.randf() < 0.5 else -1.0),
			"spin_rate":_rng.randf_range(SPIN.x,SPIN.y)*(1.0 if _rng.randf() < 0.5 else -1.0),"turn":1.0 if _rng.randf() < 0.5 else -1.0,
			"flat":1.0,"lost":false,"normal":Vector3.UP,"color":Color(COLORS[_rng.randi_range(0,COLORS.size()-1)]).srgb_to_linear()}
		if blades.size() >= CAPACITY: blades.remove_at(0)
		blades.append(blade)

func _move(blade: Dictionary, dt: float, ribbons: Node, ambient: Vector3) -> void:
	var p: Vector3 = blade.position
	var v: Vector3 = blade.velocity
	var wind := ambient
	if ribbons != null: wind += ribbons.air_at(p)
	var weight: float = blade.weight
	# The spiral: about the head of the ribbon that kicked it, while that lifts.
	var centre: Dictionary = _centres.get(blade.id,{})
	if not centre.is_empty():
		var from := Vector2(p.x-(centre.at as Vector3).x,p.z-(centre.at as Vector3).z)
		var near := 1.0-smoothstep(0.0,SPIRAL_REACH,from.length())
		var tangent := Vector2(-from.y,from.x).normalized() if from.length() > 0.01 else Vector2.ZERO
		wind += Vector3(tangent.x,0,tangent.y)*SPIRAL*float(centre.lift)*near*float(blade.turn)
	var aloft: float = clampf(maxf(wind.y,0.0)/1.0+maxf(v.y,0.0)/1.0,0.0,1.0)
	var target := wind+Vector3.DOWN*SINK*weight/0.3
	# Falling, it rocks side to side across its heading.
	var side := Vector3(-v.z,0,v.x).normalized() if Vector2(v.x,v.z).length() > 0.05 else Vector3(1,0,0)
	var flutter := sin(_clock*6.0+float(blade.phase))
	v = v.lerp(target,1.0-exp(-DRAG/(weight/0.3)*dt))
	if v.y < 0.0: v += side*flutter*FLUTTER*dt
	var next := p+v*dt
	var height: Variant = ground_height.call(Vector2(next.x,next.z))
	if height == null or not is_finite(float(height)):
		# Over water or off the plate: it drifts down and fades.
		if not blade.lost:
			blade.lost = true
			blade.age = maxf(float(blade.age),float(blade.life)-FADE_OUT)
		p = next
		v.y = minf(v.y,-0.2)
	else:
		p = next
		if p.y <= float(height)+REST:
			p.y = float(height)+REST
			if v.y < 0.0: v.y = 0.0
			var rate := GROUND_FRICTION*dt
			v.x *= exp(-rate)
			v.z *= exp(-rate)
			blade.normal = _ground_normal(Vector2(p.x,p.z),float(height))
			blade.flat = lerpf(float(blade.flat),1.0,1.0-exp(-8.0*dt))
		else:
			blade.flat = lerpf(float(blade.flat),0.0,1.0-exp(-10.0*dt))
	var free: float = 1.0-float(blade.flat)
	blade.tumble = float(blade.tumble)+float(blade.tumble_rate)*dt*free*(0.4+0.6*maxf(aloft,0.3))
	blade.roll = float(blade.roll)+float(blade.spin_rate)*dt*free
	blade.yaw = float(blade.yaw)+float(blade.turn)*dt*(0.5+0.5*Vector2(v.x,v.z).length())*(0.3+free)
	blade.position = p
	blade.velocity = v

func _draw() -> void:
	multimesh.visible_instance_count = blades.size()
	for i in range(blades.size()):
		var blade := blades[i]
		var age: float = blade.age
		var shown := smoothstep(0.0,FADE_IN,age)*(1.0-smoothstep(float(blade.life)-FADE_OUT,float(blade.life),age))
		var flat: float = blade.flat
		var basis := Basis(Quaternion(Vector3.UP,blade.normal).slerp(Quaternion.IDENTITY,0.0)) * Basis(Vector3.UP,blade.yaw)
		# Lying on the ground it settles flat; in the air it tumbles end over end.
		basis = basis * Basis(Vector3.RIGHT,lerp_angle(float(blade.tumble),0.0,flat)) * Basis(Vector3.FORWARD,lerp_angle(float(blade.roll),0.0,flat))
		multimesh.set_instance_transform(i,Transform3D(basis.scaled(Vector3.ONE*maxf(float(blade.size)*shown,0.00001)),blade.position))
		multimesh.set_instance_color(i,blade.color)
		multimesh.set_instance_custom_data(i,Color(0,0,0,0))

func _ground_normal(point: Vector2, height: float) -> Vector3:
	var x: Variant = ground_height.call(point+Vector2(0.12,0))
	var z: Variant = ground_height.call(point+Vector2(0,0.12))
	if x == null or z == null: return Vector3.UP
	return Vector3(height-float(x),0.12,height-float(z)).normalized()
