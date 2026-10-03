extends MultiMeshInstance3D
## A bounded, cosmetic layer of loose leaves. No saves or gameplay state.
##
## Every leaf answers the air it sits in, all the time: an ordinary breeze
## lifts and rocks its edges, harder the stronger it blows; a gust (the
## breathing of the wind, a puff, the Feather, a resident's local air) drags it
## over the ground with some weight to it, starting and slowing rather than
## switching on and off, and a hard one hops it. A leaf blown onto water or off
## the plate does not jump back: on the ground it lodges at the edge, and in
## the air it drifts down and fades, and after a while a new one fades in
## under the trees.
const CAPACITY := 96
## Wind (m/s-ish, the air's strength × gust) under which a leaf only stirs in
## place, per unit of its weight, and over which it hops.
const SLIDE_WIND := 0.55
const HOP_WIND := 1.3
## Share of the wind a sliding leaf travels at, and 1/s how quickly it gets
## going and how quickly the ground's friction stops it.
const SLIDE_SHARE := 0.3
const SLIDE_TAKE := 3.0
const SLIDE_STOP := 4.5
## Seconds a lost leaf takes to fade, the wait (random) before a new one
## grows in under the trees, and its fade in.
const FADE_OUT := 0.9
const REGROW_WAIT := Vector2(3.0,9.0)
const FADE_IN := 1.5
## Physics steps at most this long, so contact stays stable at any frame rate.
const MAX_STEP := 1.0/50.0
var leaves: Array[Dictionary] = []
var ground_height: Callable
var local_wind: Node
var _clock := 0.0
var _accumulator := 0.0
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	name = "WindLeafLitter"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = _leaf_mesh()
	multimesh.instance_count = CAPACITY
	multimesh.visible_instance_count = 0
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 0.85
	material_override = material
	custom_aabb = AABB(Vector3(-16,-3,-16),Vector3(32,32,32))

static func _leaf_mesh() -> Mesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outline := [Vector3(0,0,-0.6),Vector3(-0.31,0,-0.16),Vector3(-0.36,0,0.2),Vector3(0,0,0.62),Vector3(0.33,0,0.18),Vector3(0.27,0,-0.18)]
	for i in range(outline.size()):
		for point in [Vector3(0,0.07,0),outline[i],outline[(i+1)%outline.size()]]:
			surface.set_color(Color.WHITE if i<3 else Color(0.68,0.74,0.62))
			surface.add_vertex(point)
	surface.generate_normals()
	return surface.commit()

func seed_from(anchors: Array, probe: Callable) -> void:
	ground_height = probe
	leaves.clear()
	_clock = 0.0
	_accumulator = 0.0
	_rng.seed = 7091
	for index in range(0,anchors.size(),maxi(1,ceili(anchors.size()/24.0))):
		var anchor: Vector2 = anchors[index]
		for n in range(4):
			if leaves.size() >= CAPACITY: break
			var angle := _rng.randf()*TAU
			var point := anchor + Vector2(cos(angle),sin(angle))*_rng.randf_range(0.35,1.7)
			var height: Variant = ground_height.call(point)
			if height == null or not is_finite(float(height)): continue
			var normal := _ground_normal(point,float(height))
			if normal.y < 0.65: continue
			var position := Vector3(point.x,float(height)+0.035,point.y)
			leaves.append({"position":position,"home":position,"anchor":anchor,"velocity":Vector3.ZERO,"yaw":angle,"spin":0.0,
				"phase":_rng.randf()*TAU,"size":_rng.randf_range(0.18,0.30),"weight":_rng.randf_range(0.8,1.4),
				"exposure":_rng.randf_range(0.65,1.35),"cooldown":_rng.randf_range(0.0,0.8),"airborne":false,"normal":normal,
				"stir":0.0,"turn":-1.0 if _rng.randf() < 0.5 else 1.0,"shown":1.0,"lost":false,"wait":0.0})
			var color := Color("b79545").lerp(Color("9b6139"),_rng.randf())
			multimesh.set_instance_color(leaves.size()-1,color.srgb_to_linear())
	multimesh.visible_instance_count = leaves.size()
	_draw()

func advance(delta: float, paused: bool, air: Node) -> void:
	if paused or delta<=0.0 or not is_finite(delta) or not ground_height.is_valid(): return
	# Every frame moves by its own time, in equal steps no longer than
	# MAX_STEP: a fixed 1/60 tick at about 60 fps ran none on one frame and
	# two on the next, and the leaves hitched.
	var span := minf(delta,0.1)
	var steps := ceili(span/MAX_STEP)
	for k in range(steps): _step(span/steps,air)
	_draw()

func _step(dt: float, air: Node) -> void:
	_clock += dt
	var direction := Vector2(cos(air._air_angle),sin(air._air_angle))
	var ambient: float = air._air_strength * air.gust_at(air._wind_time)
	for leaf in leaves:
		if leaf.lost:
			_regrow(leaf,dt)
			continue
		var p: Vector3 = leaf.position
		# Each parcel pushes along its own heading (a wind-tool gust's is the swipe's).
		var gust: Vector2 = air.puffs.push_at(Vector2(p.x,p.z),direction,air._gust_distance)
		var local := Vector3.ZERO
		if is_instance_valid(local_wind): local = local_wind.sample_local(p)
		# The breeze is patchy: it comes and goes over the ground, so
		# neighbours do not all move as one.
		var patch := 0.75+0.35*sin(_clock*0.9+p.x*0.45+p.z*0.3)+0.2*sin(_clock*2.3+leaf.phase)
		var wind := Vector3(direction.x,0,direction.y)*ambient*1.3*patch*float(leaf.exposure)+Vector3(gust.x,0,gust.y)*7.0+local
		var speed := Vector2(wind.x,wind.z).length()
		var weight: float = leaf.weight
		leaf.cooldown = maxf(0.0,leaf.cooldown-dt)
		# How much the air stirs it, eased so it never snaps: from a little
		# lift of the edges in a light breeze to a full rock and skid.
		var stir_goal := smoothstep(0.05,SLIDE_WIND*weight*1.6,speed)
		leaf.stir = lerpf(float(leaf.stir),stir_goal,1.0-exp(-(4.0 if stir_goal > leaf.stir else 1.5)*dt))
		leaf.spin += dt*(2.0+speed*2.2)
		var velocity: Vector3 = leaf.velocity
		if not leaf.airborne:
			var slide := maxf(0.0,speed-SLIDE_WIND*weight)/maxf(speed,0.001)
			var goal := Vector3(wind.x,0,wind.z)*SLIDE_SHARE*slide
			var rate := SLIDE_TAKE if goal.length_squared() > velocity.length_squared() else SLIDE_STOP
			velocity = velocity.lerp(goal,1.0-exp(-rate*dt))
			velocity.y = 0.0
			# A dry leaf skitters in little hops rather than gliding tip first.
			if leaf.cooldown <= 0.0 and speed > HOP_WIND*weight and _rng.randf() < dt*(1.0+2.0*(speed/(HOP_WIND*weight)-1.0)):
				leaf.airborne = true
				velocity.y = minf(lerpf(0.5,0.9,_rng.randf())+speed*0.25,2.6)/weight
				leaf.cooldown = 0.35
			# Skidding, it turns about rather than facing the wind.
			leaf.yaw += float(leaf.turn)*dt*velocity.length()*2.5
		if leaf.airborne:
			var flutter := sin(_clock*7.0+leaf.phase)
			velocity.x = lerpf(velocity.x,wind.x*0.65,dt*1.8)
			velocity.z = lerpf(velocity.z,wind.z*0.65,dt*1.8)
			velocity += Vector3(-direction.y,0,direction.x)*flutter*dt*0.6
			velocity.y += (-2.3*weight + minf(speed*0.20,1.0))*dt
			leaf.yaw += float(leaf.turn)*dt*(0.6+speed*0.3)
		var next := p+velocity*dt
		var height: Variant = ground_height.call(Vector2(next.x,next.z))
		if height == null or not is_finite(float(height)):
			if leaf.airborne:
				# Over water or off the plate: it drifts down and fades.
				_lose(leaf)
				p = next
			else:
				# It lodges at the bank or the rim and stays.
				velocity = Vector3.ZERO
		else:
			p = next
			if not leaf.airborne or p.y <= float(height)+0.035:
				p.y = float(height)+0.035
				leaf.normal = _ground_normal(Vector2(p.x,p.z),float(height))
				velocity.y = 0.0
				if leaf.airborne:
					velocity *= 0.3
					leaf.cooldown = maxf(leaf.cooldown,0.8)
				leaf.airborne = false
		leaf.position = p
		leaf.velocity = velocity

## Leaves within `radius` of `point` (world) are lost, as blown away (the
## trash can sweeping them up): they fade and grow back under their trees.
func sweep(point: Vector3, radius: float) -> void:
	var here := to_local(point)
	for leaf in leaves:
		if not leaf.lost and (leaf.position as Vector3).distance_to(here) <= radius: _lose(leaf)

## A leaf blown away: it fades as it goes.
func _lose(leaf: Dictionary) -> void:
	leaf.lost = true
	leaf.wait = _rng.randf_range(REGROW_WAIT.x,REGROW_WAIT.y)

## A lost leaf falls and fades, waits, then a new one grows in somewhere
## under its tree.
func _regrow(leaf: Dictionary, dt: float) -> void:
	if float(leaf.shown) > 0.0:
		leaf.velocity = (leaf.velocity as Vector3)*exp(-1.5*dt)+Vector3.DOWN*0.6*dt
		leaf.position += (leaf.velocity as Vector3)*dt
		leaf.shown = maxf(0.0,float(leaf.shown)-dt/FADE_OUT)
		return
	leaf.wait = float(leaf.wait)-dt
	if leaf.wait > 0.0: return
	var anchor: Vector2 = leaf.anchor
	var placed := false
	for attempt in range(4):
		var angle := _rng.randf()*TAU
		var point := anchor+Vector2(cos(angle),sin(angle))*_rng.randf_range(0.35,1.7)
		var height: Variant = ground_height.call(point)
		if height == null or not is_finite(float(height)): continue
		var normal := _ground_normal(point,float(height))
		if normal.y < 0.65: continue
		leaf.position = Vector3(point.x,float(height)+0.035,point.y)
		leaf.normal = normal
		leaf.yaw = angle
		placed = true
		break
	if not placed:
		# Try again later rather than grow in where there is no ground.
		leaf.wait = 1.0
		return
	leaf.velocity = Vector3.ZERO
	leaf.airborne = false
	leaf.lost = false
	leaf.stir = 0.0
	leaf.cooldown = 1.0
	leaf.shown = 0.0001

func _draw() -> void:
	for i in range(leaves.size()):
		var leaf := leaves[i]
		if not leaf.lost and float(leaf.shown) < 1.0: leaf.shown = minf(1.0,float(leaf.shown)+get_process_delta_time()/FADE_IN)
		var basis := Basis(Quaternion(Vector3.UP,leaf.normal)) * Basis(Vector3.UP,leaf.yaw)
		var stir: float = leaf.stir
		if leaf.airborne or leaf.lost:
			basis = basis * Basis(Vector3.RIGHT,leaf.spin) * Basis(Vector3.FORWARD,sin(_clock*5.0+leaf.phase)*0.65)
		elif stir > 0.001:
			# Rocking on its curled rim, quicker and higher the harder it blows.
			var rock := sin(float(leaf.spin)+leaf.phase)
			var pitch := sin(float(leaf.spin)*0.73+leaf.phase*1.7)
			basis = basis * Basis(Vector3.FORWARD,rock*0.32*stir) * Basis(Vector3.RIGHT,pitch*0.22*stir)
		var size: float = float(leaf.size)*smoothstep(0.0,1.0,float(leaf.shown))
		multimesh.set_instance_transform(i,Transform3D(basis.scaled(Vector3.ONE*maxf(size,0.00001)),leaf.position))

func _ground_normal(point: Vector2, height: float) -> Vector3:
	var x: Variant = ground_height.call(point+Vector2(0.12,0))
	var z: Variant = ground_height.call(point+Vector2(0,0.12))
	if x == null or z == null: return Vector3.UP
	return Vector3(height-float(x),0.12,height-float(z)).normalized()
