extends Node3D
## Waterfalls the live water makes (docs/scenic/water-flow.md "Waterfalls").
##
## A few times a second the flow is asked where fast water crosses a big drop
## over a short run (`WaterFlow.cascades`, ZenScapeWaterFlow::cascades): each
## answer is a lip, a plunge, the flux over it and a course down the face.
## Answers are matched to the falls already standing by where they are, and
## every fall eases towards its latest answer, so it neither flickers nor
## jumps: it stands after HOLD s of being found, grows in, follows the flow's
## strength, and fades out FADE s once it is gone.
##
## Each fall is the source's strand (waterfall.js buildStrand, the ring shader
## reference_fall.gdshader) driven by the flow instead of a record:
## - a curtain as wide as the wet channel, following the face just off it,
##   thicker and fuller with more flux (a trickle is a torn veil), glass at the
##   lip beaten white by the fall, with a white break where it tips over
##   (shaders/flow_fall.gdshader);
## - churning foam where it lands: bobbing foam blobs (the source's
##   foamCluster), a droplet burst, ripple rings on a pool, and foam painted
##   into the water itself (`fall_foam` on the live water's materials);
## - mist rising from the base, sized by flux and drop, drifting with the wind
##   (the source's mist sprites, studies/fall_mist.gd).
const RINGS := 14
const SECTIONS := 12
## ZenScapeWaterFlow::cascades. A wet cell faster than `min_speed` m/s is steep
## when its surface falls `slope_on` m per metre over `run` m down its flow
## (and stays steep down to `slope_off`); steep cells group, and a group whose
## lip stands `min_drop` m over its plunge with `min_flux` m³/s is a fall.
const DETECT := {"wet":0.01,"min_speed":0.3,"slope_on":1.0,"slope_off":0.7,"run":0.5,"min_drop":0.7,"min_flux":0.006,"lip_band":0.3,"band":0.3,"min_cells":3,"max":6}
## Seconds between reads of the flow.
const READ_SECONDS := 0.25
## m³/s that makes a full curtain (the largest spring pours 0.25).
const FULL_FLUX := 0.2
## Metres a fall's lip or plunge may move between reads and stay the same fall.
const MATCH := 1.5
## Seconds found before a fall stands, to grow in, lost before it fades, to fade.
const HOLD := 0.75
const GROW := 1.2
const GRACE := 0.5
const FADE := 2.0
## Seconds: the time constant a fall's shape and flux ease with.
const SMOOTH := 0.6
const MAX_SHOWN := 4
## Mist sprites at most a fall (studies/fall_mist.gd holds 64).
const MIST := 48
const FOAM := Color("f2f7f8")
const FOAM_BLOBS := 7
const RING_WAVES := 4
const RING_PERIOD := 1.15
const W_MIN := 0.08

var flow: RefCounted
var materials: Array[ShaderMaterial] = []
var _falls: Array[Dictionary] = []
var _serial := 0
var _since := 0.0
var _clock := 0.0
var _ring_mesh: ArrayMesh
var _blob_mesh: SphereMesh
var _bead_mesh: SphereMesh
var _spray_material: ParticleProcessMaterial
var _ring_wave_mesh: PlaneMesh
## Microseconds of the last read and the last frame's update, for probes.
var last_read_usec := 0
var last_update_usec := 0
var worst_update_usec := 0

## `water_materials`: the live water's still and moving materials, which take
## the falls' foam.
func setup(water_flow: RefCounted, water_materials: Array) -> void:
	flow = water_flow
	for material: ShaderMaterial in water_materials: materials.append(material)
	_ring_mesh = _build_ring_mesh()
	_blob_mesh = SphereMesh.new()
	_blob_mesh.radius = 1.0
	_blob_mesh.height = 2.0
	_blob_mesh.radial_segments = 6
	_blob_mesh.rings = 3
	var blob_look := StandardMaterial3D.new()
	blob_look.albedo_color = FOAM
	blob_look.roughness = 0.9
	# Foam scatters light: lit alone it went black in a cliff's shadow.
	blob_look.emission_enabled = true
	blob_look.emission = FOAM
	blob_look.emission_energy_multiplier = 0.45
	_blob_mesh.material = blob_look
	_bead_mesh = SphereMesh.new()
	_bead_mesh.radius = 0.035
	_bead_mesh.height = 0.07
	_bead_mesh.radial_segments = 6
	_bead_mesh.rings = 3
	var bead_look := StandardMaterial3D.new()
	bead_look.albedo_color = FOAM
	bead_look.roughness = 0.25
	bead_look.vertex_color_use_as_albedo = true
	bead_look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bead_mesh.material = bead_look
	_spray_material = ParticleProcessMaterial.new()
	_spray_material.direction = Vector3.UP
	_spray_material.spread = 55.0
	_spray_material.initial_velocity_min = 1.4
	_spray_material.initial_velocity_max = 3.2
	_spray_material.gravity = Vector3(0,-9.8,0)
	_spray_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	_spray_material.emission_sphere_radius = 0.25
	_spray_material.scale_min = 0.5
	_spray_material.scale_max = 1.3
	var fade := Gradient.new()
	fade.set_color(0,Color(FOAM,0.95))
	fade.set_color(1,Color(FOAM,0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	_spray_material.color_ramp = ramp
	_ring_wave_mesh = PlaneMesh.new()
	_ring_wave_mesh.size = Vector2(2,2)
	var wave_look := ShaderMaterial.new()
	wave_look.shader = preload("res://shaders/drip_ring.gdshader")
	wave_look.render_priority = 10
	_ring_wave_mesh.material = wave_look

## Rings × sections as flat facets: UV is (ring, angle) per vertex, UV2 (ring,
## section) per face, as the source's strand. The shader places every vertex.
static func _build_ring_mesh() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(RINGS-1):
		for section in range(SECTIONS):
			for corner: Vector2i in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(0,1)]:
				surface.set_uv(Vector2(ring+corner.x,TAU*(section+corner.y)/SECTIONS))
				surface.set_uv2(Vector2(ring,section))
				surface.set_color(Color.WHITE)
				surface.set_normal(Vector3.UP)
				surface.add_vertex(Vector3.ZERO)
	return surface.commit()

## The number of falls standing.
func shown_count() -> int:
	var count := 0
	for fall: Dictionary in _falls:
		if fall.shown and float(fall.presence) > 0.0: count += 1
	return count

## What stands, for probes and films: lip, plunge, flux (m³/s), drop, width,
## presence (0..1).
func describe() -> Array:
	var out := []
	for fall: Dictionary in _falls:
		if not fall.shown or fall.now.is_empty(): continue
		var course: PackedVector4Array = fall.now.course
		out.append({"id":fall.id,"lip":Vector3(course[0].x,course[0].y,course[0].z),"plunge":Vector3(course[-1].x,course[-1].y,course[-1].z),
			"flux":fall.now.flux,"drop":fall.now.drop,"width":course[0].w*2.0,"presence":fall.presence})
	return out

func _process(delta: float) -> void:
	if flow == null or not flow.ready: return
	var began := Time.get_ticks_usec()
	var scene := get_parent()
	var paused: bool = scene != null and scene.get("_paused") == true
	if not paused and delta > 0.0 and is_finite(delta):
		_clock += delta
		_since += delta
		if _since >= READ_SECONDS:
			_read(_since)
			_since = 0.0
		_ease(delta)
	var growth: Variant = scene.get("_growth") if scene != null else null
	var grown: bool = growth == null or (growth.terrain >= 0.995 and growth.water >= 0.5)
	_draw(grown,paused)
	_update_mist(scene,grown)
	last_update_usec = Time.get_ticks_usec()-began
	worst_update_usec = maxi(worst_update_usec,last_update_usec)

## Reads the flow's falls and matches them to the standing ones.
func _read(elapsed: float) -> void:
	var began := Time.get_ticks_usec()
	var found: Array = flow.cascades(DETECT)
	var taken := {}
	for answer: Dictionary in found:
		var shape := _shape(answer)
		if shape.is_empty(): continue
		var best := -1
		var nearest := MATCH
		for k in range(_falls.size()):
			if taken.has(k): continue
			var known: Dictionary = _falls[k].target
			var gap := minf((known.lip as Vector3).distance_to(shape.lip),(known.plunge as Vector3).distance_to(shape.plunge))
			if gap < nearest:
				nearest = gap
				best = k
		if best < 0:
			_serial += 1
			_falls.append({"id":_serial,"found":0.0,"lost":0.0,"shown":false,"presence":0.0,"target":shape,"now":{},"nodes":{}})
			best = _falls.size()-1
		taken[best] = true
		var fall: Dictionary = _falls[best]
		fall.target = shape
		fall.found = float(fall.found)+elapsed
		fall.lost = 0.0
	for k in range(_falls.size()):
		if taken.has(k): continue
		var fall: Dictionary = _falls[k]
		fall.lost = float(fall.lost)+elapsed
		if not fall.shown: fall.found = 0.0
	# The strongest stand; one found long enough stands if there is room.
	var standing := 0
	for fall: Dictionary in _falls:
		if fall.shown: standing += 1
	for fall: Dictionary in _falls:
		if not fall.shown and float(fall.found) >= HOLD and standing < MAX_SHOWN:
			fall.shown = true
			fall.now = fall.target.duplicate(true)
			standing += 1
	last_read_usec = Time.get_ticks_usec()-began

## A cascade answer as a fall's shape: its course resampled to RINGS stations
## by descent (the source's resample: rings bunch where the water drops).
func _shape(answer: Dictionary) -> Dictionary:
	var course: PackedVector4Array = answer.course
	if course.size() < 2: return {}
	var cumulative := PackedFloat32Array([0.0])
	for i in range(1,course.size()):
		var a := course[i-1]
		var b := course[i]
		var along := Vector3(b.x-a.x,b.y-a.y,b.z-a.z).length()
		cumulative.append(cumulative[-1]+0.15*along+0.85*maxf(0.0,a.y-b.y))
	var total := maxf(cumulative[-1],0.0001)
	var stations := PackedVector4Array()
	var j := 0
	for r in range(RINGS):
		var want := float(r)/(RINGS-1)*total
		while j < course.size()-2 and cumulative[j+1] < want: j += 1
		var t := clampf((want-cumulative[j])/maxf(cumulative[j+1]-cumulative[j],0.0001),0.0,1.0)
		stations.append(course[j].lerp(course[j+1],t))
	# The band centroids wander a cell either way; smooth the line (not its
	# ends) so the curtain hangs straight rather than zigzagging.
	for pass_index in range(3):
		var smoothed := stations.duplicate()
		for r in range(1,RINGS-1):
			var mean := (stations[r-1]+stations[r]*2.0+stations[r+1])/4.0
			smoothed[r] = Vector4(mean.x,stations[r].y,mean.z,mean.w)
		stations = smoothed
	return {"course":stations,"flux":float(answer.flux),"drop":float(answer.drop),"pool":float(answer.plunge_depth),
		"lip":answer.lip,"plunge":answer.plunge,"lip_dir":answer.lip_dir}

## Eases every standing fall towards its latest answer, and its presence up
## or down; a fall faded out is removed.
func _ease(delta: float) -> void:
	var k := 1.0-exp(-delta/SMOOTH)
	for index in range(_falls.size()-1,-1,-1):
		var fall: Dictionary = _falls[index]
		if not fall.shown:
			if float(fall.lost) > GRACE: _drop(index)
			continue
		var now: Dictionary = fall.now
		var target: Dictionary = fall.target
		var course: PackedVector4Array = now.course
		var goal: PackedVector4Array = target.course
		for r in range(course.size()): course[r] = course[r].lerp(goal[r],k)
		now.course = course
		for key in ["flux","drop","pool"]: now[key] = lerpf(now[key],target[key],k)
		now.lip_dir = (now.lip_dir as Vector2).lerp(target.lip_dir,k)
		var here := float(fall.lost) <= GRACE
		fall.presence = move_toward(fall.presence,1.0 if here else 0.0,delta/(GROW if here else FADE))
		if not here and fall.presence <= 0.0: _drop(index)

func _drop(index: int) -> void:
	var nodes: Dictionary = _falls[index].nodes
	for node: Variant in nodes.values():
		if node is Node and is_instance_valid(node): node.queue_free()
	_falls.remove_at(index)

## Places every standing fall's curtain, plunge and water foam.
func _draw(grown: bool, paused: bool) -> void:
	var foam := PackedVector4Array()
	foam.resize(8)
	var foam_count := 0
	for fall: Dictionary in _falls:
		if not fall.shown or fall.now.is_empty(): continue
		if fall.nodes.is_empty(): fall.nodes = _create(fall.id)
		var presence: float = fall.presence
		var now: Dictionary = fall.now
		var strength := _strength(now.flux)
		var rings := _rings(now,presence,strength)
		var nodes: Dictionary = fall.nodes
		var visible := grown and presence > 0.001
		for node: Node3D in [nodes.curtain,nodes.foam,nodes.spray,nodes.waves]: node.visible = visible
		if not visible: continue
		var s := presence*strength
		var material: ShaderMaterial = nodes.curtain.material_override
		material.set_shader_parameter("ring_count",RINGS)
		material.set_shader_parameter("centers_tau",rings.centers)
		material.set_shader_parameter("axis_a_width",rings.across)
		material.set_shader_parameter("axis_b_thick",rings.outward)
		material.set_shader_parameter("aer_steep",rings.aer_steep)
		material.set_shader_parameter("ring_travel",rings.travel)
		material.set_shader_parameter("body_white",0.36*(1.0-smoothstep(0.15,0.8,rings.mid_half)))
		material.set_shader_parameter("veil",1.0-smoothstep(0.15,0.85,s))
		material.set_shader_parameter("streak_speed",clampf(0.6*sqrt(2.0*9.81*maxf(now.drop,0.1)),2.5,7.0))
		nodes.curtain.custom_aabb = rings.bounds
		var impact: Vector3 = rings.impact
		var spread := (0.5+strength*0.5)*(0.8+0.1*minf(now.drop,4.0))
		# Foam blobs (the source's foamCluster: 4 + 3·flow round the impact).
		var blobs: MultiMesh = nodes.foam.multimesh
		blobs.visible_instance_count = clampi(roundi((4.0+3.0*strength)*minf(presence*1.5,1.0)),0,FOAM_BLOBS)
		for i in range(FOAM_BLOBS):
			var angle := float(i)/FOAM_BLOBS*TAU+float(fall.id)*5.1
			var radius := (0.35+_hash(i,1)*0.9)*spread*0.8
			var extent := (0.08+_hash(i,2)*0.12)*(0.7+strength*0.25)*presence
			var bob := absf(sin(_clock*2.0+i*1.7))*0.08 if not paused else 0.0
			var point := impact+Vector3(cos(angle)*radius,0.04+bob,sin(angle)*radius*0.75)
			var churn := Basis.from_euler(Vector3(i,i*2+_clock*0.25,i*3))
			blobs.set_instance_transform(i,Transform3D(churn.scaled(Vector3.ONE*extent*(0.9+0.15*sin(_clock*3.1+i))),point))
		var spray: GPUParticles3D = nodes.spray
		spray.position = impact+Vector3.UP*0.05
		spray.amount_ratio = clampf(s,0.05,1.0)
		spray.speed_scale = 0.0 if paused else 1.0
		# Ripple rings where it lands in standing water.
		var pool := smoothstep(0.04,0.18,now.pool)
		var waves: MultiMesh = nodes.waves.multimesh
		var wave_reach := 1.3*maxf(spread*1.4,0.6)
		for i in range(RING_WAVES):
			var age := fposmod(_clock+float(i)*RING_PERIOD/RING_WAVES,RING_PERIOD)/RING_PERIOD
			var radius := 0.2+age*wave_reach
			waves.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3(radius,1,radius)),impact+Vector3.UP*0.08))
			waves.set_instance_color(i,Color(1,1,1,pow(1.0-age,1.6)*pool*presence))
		# Foam in the water: churn at the plunge, a white break at the lip.
		if foam_count < 8:
			foam[foam_count] = Vector4(impact.x,impact.z,spread*1.6,presence*(0.6+0.4*strength))
			foam_count += 1
		if foam_count < 8:
			var lip: Vector3 = rings.lip
			foam[foam_count] = Vector4(lip.x,lip.z,maxf(rings.lip_half*1.2,0.3),presence*0.5*(0.5+0.5*strength))
			foam_count += 1
	for material in materials:
		material.set_shader_parameter("fall_foam",foam)
		material.set_shader_parameter("fall_foam_count",foam_count if grown else 0)

## 0..1 from the flux: a square root, so a trickle still shows.
static func _strength(flux: float) -> float:
	return clampf(sqrt(maxf(flux,0.0)/FULL_FLUX),0.15,1.0)

## The strand's rings from a shape, as the source builds them (waterfall.js
## buildStrand): a frame down the course, travel time, aeration, width, then
## thickness, the inlet, and the lift off the face.
func _rings(shape: Dictionary, presence: float, strength: float) -> Dictionary:
	var course: PackedVector4Array = shape.course
	var n := course.size()
	var points := PackedVector3Array()
	for station in course: points.append(Vector3(station.x,station.y,station.z))
	var lip_dir: Vector2 = shape.lip_dir
	var heading := Vector3(lip_dir.x,0,lip_dir.y).normalized() if lip_dir.length() > 0.01 else Vector3.RIGHT
	var tangents := PackedVector3Array()
	var across := PackedVector3Array()
	var outward := PackedVector3Array()
	var steep := PackedFloat32Array()
	for r in range(n):
		var tangent := (points[mini(r+1,n-1)]-points[maxi(r-1,0)]).normalized()
		var level := Vector3(tangent.x,0,tangent.z)
		# Keep the last heading where the course is plumb (the source's transport).
		if level.length() > 0.15: heading = heading.lerp(level.normalized(),smoothstep(0.15,0.4,level.length())).normalized()
		var side := heading.cross(Vector3.UP).normalized()
		tangents.append(tangent)
		across.append(side)
		outward.append(side.cross(tangent).normalized())
		steep.append(clampf(-tangent.y,0.0,1.0))
	var tau := PackedFloat32Array([0.0])
	var travel := PackedFloat32Array([0.0])
	for r in range(1,n):
		var along := points[r].distance_to(points[r-1])
		tau.append(tau[r-1]+along/(1.0+3.0*steep[r]))
		travel.append(travel[r-1]+along)
	# Air beaten in over travel time: glass at the lip, white below.
	var aer := PackedFloat32Array()
	var air := 0.0
	for r in range(n):
		var dt := tau[r]-tau[r-1] if r > 0 else 0.0
		# The source's rate (1.15), raised with the flow: a strong spring
		# over our few metres of face should break white as the source's
		# long falls do.
		air = minf(1.0,air*pow(0.5,dt)+steep[r]*dt*1.15*(1.0+strength))
		aer.append(air)
	# Width: the lip's channel, necking as it falls and spreading as it breaks
	# up, never wider than the wet channel at that height (plus a margin, so
	# the curtain covers the sheet the surface mesh draws).
	var length := travel[n-1]
	var lip_half := maxf(course[0].w,W_MIN)
	var cap := maxf(W_MIN*3.0,minf(lip_half*2.2,maxf(length*0.35,lip_half)))
	var half := PackedFloat32Array()
	for r in range(n):
		var room := maxf(course[r].w,lip_half*0.8)+0.05
		var profile := (1.0-0.16*steep[r])*(1.0+0.5*aer[r])
		var want := minf(minf(room*(1.0+0.3*aer[r]),cap*(1.0+0.5*aer[r])),maxf(W_MIN,lip_half*profile))
		half.append(want if r == 0 else clampf(want,half[r-1]*0.94,half[r-1]*1.18))
	for pass_index in range(2):
		for r in range(1,n-1): half[r] = (half[r-1]+half[r]*2.0+half[r+1])/4.0
	# Thickness: a plunging sheet has a belly, water sliding on rock is a skin;
	# more water, a fuller sheet. The inlet opens over the first rings.
	var thick := PackedFloat32Array()
	var inlet := minf(1.6,(n-1)*0.12)
	for r in range(n):
		var body := minf(half[r]*0.55,(0.06+0.45*steep[r])*(0.3+0.7*strength))
		body *= 0.06+0.94*smoothstep(0.0,2.5,float(r))
		var pinch := 0.28+0.72*smoothstep(0.0,inlet,float(r))
		half[r] *= pinch*lerpf(0.3,1.0,presence)
		thick.append(body*pinch*presence)
	var centers := PackedVector4Array()
	var axis_a := PackedVector4Array()
	var axis_b := PackedVector4Array()
	var aer_steep := PackedVector2Array()
	var travels := PackedFloat32Array()
	centers.resize(32)
	axis_a.resize(32)
	axis_b.resize(32)
	aer_steep.resize(32)
	travels.resize(32)
	var low := Vector3(INF,INF,INF)
	var high := -low
	var widest := 0.0
	for r in range(n):
		var point := points[r]
		# Stand off the face by the sheet's own thickness; the first ring sinks
		# under the lip so the water comes out of it, not out of a tube mouth.
		if r == 0: point -= outward[r]*(thick[r]+0.08)
		else: point += outward[r]*(thick[r]*0.9+0.04)
		if r == n-1: point.y = points[r].y-0.05
		centers[r] = Vector4(point.x,point.y,point.z,tau[r])
		axis_a[r] = Vector4(across[r].x,across[r].y,across[r].z,half[r])
		axis_b[r] = Vector4(outward[r].x,outward[r].y,outward[r].z,thick[r])
		aer_steep[r] = Vector2(aer[r],steep[r])
		travels[r] = travel[r]
		low = low.min(point)
		high = high.max(point)
		widest = maxf(widest,half[r])
	var bounds := AABB(low,high-low).grow(widest+0.6)
	return {"centers":centers,"across":axis_a,"outward":axis_b,"aer_steep":aer_steep,"travel":travels,"mid_half":half[n/2],
		"bounds":bounds,"impact":points[n-1],"lip":points[0],"lip_half":course[0].w}

## One fall's nodes: the curtain, foam blobs, spray and ripple rings (children
## here), and its mist (a canvas layer on the scene, as the authored falls').
func _create(id: int) -> Dictionary:
	var curtain := MeshInstance3D.new()
	curtain.name = "FlowFall_%d" % id
	curtain.mesh = _ring_mesh
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/flow_fall.gdshader")
	material.set_shader_parameter("fall_seed",float(id)*13.7)
	var white := PackedFloat32Array()
	for s in range(12): white.append(_hash(s*17+id,2))
	material.set_shader_parameter("section_white",white)
	curtain.material_override = material
	curtain.set_meta("skip_reflection",true)
	add_child(curtain)
	var foam := MultiMeshInstance3D.new()
	foam.name = "FlowFallFoam_%d" % id
	foam.multimesh = MultiMesh.new()
	foam.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	foam.multimesh.mesh = _blob_mesh
	foam.multimesh.instance_count = FOAM_BLOBS
	foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(foam)
	var spray := GPUParticles3D.new()
	spray.name = "FlowFallSpray_%d" % id
	spray.process_material = _spray_material
	spray.amount = 48
	spray.lifetime = 0.8
	spray.randomness = 0.6
	spray.visibility_aabb = AABB(Vector3(-4,-1,-4),Vector3(8,6,8))
	spray.draw_pass_1 = _bead_mesh
	spray.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(spray)
	var waves := MultiMeshInstance3D.new()
	waves.name = "FlowFallRings_%d" % id
	waves.multimesh = MultiMesh.new()
	waves.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	waves.multimesh.use_colors = true
	waves.multimesh.mesh = _ring_wave_mesh
	waves.multimesh.instance_count = RING_WAVES
	waves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(waves)
	var mist := preload("res://studies/fall_mist.gd").new()
	mist.name = "FlowFallMist_%d" % id
	var recipe := {"positions":[],"velocity":[],"phase":[],"size":[],"rise":1.0}
	for i in range(MIST):
		recipe.positions.append_array([0.0,-1000.0,0.0])
		recipe.velocity.append_array([0.0,0.0,0.0])
		recipe.phase.append(_hash(i+id*64,10))
		recipe.size.append(0.7+_hash(i+id*64,11)*0.8)
	add_child(mist)
	mist.setup(recipe)
	return {"curtain":curtain,"foam":foam,"spray":spray,"waves":waves,"mist":mist,"mist_at":0.0}

## Mist: the source's emitters (the impact, weight 3, and every other aerated
## ring), 40·flow sprites plus five an emitter, rising (0.9 + 0.6·flow) m;
## here also sized and lifted by the drop.
func _update_mist(scene: Node, grown: bool) -> void:
	if scene == null or scene.get("camera") == null or _falls.is_empty(): return
	var depth: CompositorEffect = null
	if scene.get("_display_fog") != null: depth = scene._display_fog.depth
	elif scene.has_node("WaterfallSpray"):
		var original: CanvasLayer = scene.get_node("WaterfallSpray")
		original.update_view(scene.camera)
		depth = original.fallback_depth
	for fall: Dictionary in _falls:
		if fall.nodes.is_empty() or fall.now.is_empty(): continue
		var mist: CanvasLayer = fall.nodes.mist
		var presence: float = fall.presence
		mist.visible = grown and presence > 0.001
		if not mist.visible: continue
		var now: Dictionary = fall.now
		var strength := _strength(now.flux)
		var drop: float = now.drop
		if _clock-float(fall.nodes.mist_at) >= 0.1:
			fall.nodes.mist_at = _clock
			_place_mist(mist,fall,strength)
		mist.material.set_shader_parameter("mist_strength",presence*(0.3+0.4*strength))
		mist.material.set_shader_parameter("mist_scale",(0.35+0.3*strength)*clampf(0.6+0.2*drop,0.7,1.4))
		mist.material.set_shader_parameter("rise_height",(0.9+0.6*strength)*clampf(0.5+0.25*drop,0.6,1.5))
		mist.update_view(scene.camera,depth)

func _place_mist(mist: CanvasLayer, fall: Dictionary, strength: float) -> void:
	var rings := _rings(fall.now,1.0,strength)
	var centers: PackedVector4Array = rings.centers
	var widths: PackedVector4Array = rings.across
	var aer: PackedVector2Array = rings.aer_steep
	var emitters := [{"at":rings.impact,"weight":3.0,"spread":0.6+strength*0.6}]
	# Only the lower half: mist rises where the water has broken up.
	for r in range(RINGS/2,RINGS-1,2):
		if aer[r].x < 0.25: continue
		emitters.append({"at":Vector3(centers[r].x,centers[r].y,centers[r].z),"weight":aer[r].x*aer[r].x*1.6,"spread":widths[r].w*1.1})
	var total := 0.0
	for emitter: Dictionary in emitters: total += emitter.weight
	var count := mini(MIST,roundi(40.0*strength)+emitters.size()*5)
	var origins := PackedVector3Array()
	var motion := PackedVector4Array()
	origins.resize(64)
	motion.resize(64)
	for i in range(count):
		var pick := _hash(i,7)*total
		var emitter: Dictionary = emitters[0]
		for candidate: Dictionary in emitters:
			emitter = candidate
			pick -= candidate.weight
			if pick <= 0.0: break
		var angle := _hash(i,3)*TAU
		var radius := sqrt(_hash(i,5))*float(emitter.spread)
		var at: Vector3 = emitter.at
		var offset := Vector2(cos(angle),sin(angle))*radius
		origins[i] = at+Vector3(offset.x,0.05,offset.y)
		var away := offset.normalized() if offset.length() > 0.0001 else Vector2.RIGHT
		var speed := 0.4+_hash(i,6)*0.8
		motion[i] = Vector4(away.x*speed+(_hash(i,8)-0.5)*0.5,away.y*speed+(_hash(i,9)-0.5)*0.5,_hash(i+int(fall.id)*64,10),0.7+_hash(i+int(fall.id)*64,11)*0.8)
	mist.material.set_shader_parameter("origins",origins)
	mist.material.set_shader_parameter("motion",motion)
	mist.material.set_shader_parameter("particle_count",count)

static func _hash(i: int, salt: int) -> float:
	return fposmod(sin(float(i)*12.9898+float(salt)*78.233)*43758.5453,1.0)

func _exit_tree() -> void:
	for material in materials:
		material.set_shader_parameter("fall_foam_count",0)
