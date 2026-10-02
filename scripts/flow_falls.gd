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
const SECTIONS := 24
## ZenScapeWaterFlow::cascades. A wet cell faster than `min_speed` m/s is steep
## when its surface falls `slope_on` m per metre over `run` m down its flow
## (and stays steep down to `slope_off`); steep cells group, and a group whose
## lip stands `min_drop` m over its plunge with `min_flux` m³/s is a fall.
const DETECT := {"wet":0.004,"min_speed":0.3,"slope_on":0.8,"slope_off":0.55,"run":0.5,"min_drop":0.7,"min_flux":0.006,"lip_band":0.3,"band":0.3,"min_cells":3,"max":6}
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
const SMOOTH := 1.2
## Metres a second a standing ribbon's course may move at most: eased freely
## it bent and coiled like a hose while the flow settled (2026-10-01).
const MAX_SHIFT := 0.3
## A ribbon pours in from its lip rather than swelling into place: its front
## leaves at POUR_START m/s and falls with gravity, at most POUR_MAX. When it
## lands, mist and spray burst up from the plunge (fading over BURST_SECONDS)
## and the plunge's foam comes in. Going, it drains away from the lip.
const POUR_START := 1.5
const POUR_MAX := 7.0
const BURST_SECONDS := 1.6
const MAX_SHOWN := 4
## Mist sprites at most a fall (studies/fall_mist.gd holds 64).
const MIST := 48
const FOAM := Color("f2f7f8")
const FOAM_BLOBS := 7
const RING_WAVES := 4
const RING_PERIOD := 1.15
const W_MIN := 0.08
## The curtain is a ribbon for narrow, steep drops only (2026-10-01): a wide
## spill over a lake's rim or a sloping face ballooned the strand into a pale
## faceted slab metres across. There the live water's own surface, the foam,
## spray and mist are the fall. A ribbon stands where the lip is at most
## RIBBON_WIDTH m wide and the water drops at least RIBBON_STEEP m for every
## metre it runs.
const RIBBON_WIDTH := 2.5
const RIBBON_STEEP := 1.0
## A ribbon standing keeps until it is RIBBON_KEEP times as wide, or as
## shallow over its run, so it does not flick on and off as the flow settles.
const RIBBON_KEEP := 1.3
## Metres thick: a flat ribbon, a little fuller with the flow.
const RIBBON_THICK := Vector2(0.025,0.05)
## The curtain is translucent where its water is glass, and writes depth. It
## draws before the live water (still 0, moving 1, scripts/water_flow_view.gd),
## so a pool's surface lies over the part that plunges under it (the water
## draws no depth), and the stream it pours over is hidden behind it rather
## than showing as a second veil through it. Spray draws after the water.
const CURTAIN_PRIORITY := -1
const SPRAY_PRIORITY := 2
## Seconds a spray puff lives: it rises, swells and fades.
const PUFF_SECONDS := 1.6

var flow: RefCounted
var materials: Array[ShaderMaterial] = []
var _falls: Array[Dictionary] = []
var _serial := 0
var _since := 0.0
var _clock := 0.0
var _ring_mesh: ArrayMesh
var _blob_mesh: QuadMesh
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
	# Spray puffs, not snowballs: the source's foam clusters were flat-shaded
	# white icosahedra, which suit its many-metre falls seen from afar; beside
	# a fall of a few metres seen close they read as snowballs. Soft round
	# billboards instead, each rising, swelling and fading on its own cycle.
	var puff := Gradient.new()
	puff.offsets = PackedFloat32Array([0.0,0.35,0.7,1.0])
	puff.colors = PackedColorArray([Color(1,1,1,0.9),Color(1,1,1,0.55),Color(1,1,1,0.15),Color(1,1,1,0.0)])
	var puff_texture := GradientTexture2D.new()
	puff_texture.gradient = puff
	puff_texture.fill = GradientTexture2D.FILL_RADIAL
	puff_texture.fill_from = Vector2(0.5,0.5)
	puff_texture.fill_to = Vector2(1.0,0.5)
	puff_texture.width = 64
	puff_texture.height = 64
	var blob_quad := QuadMesh.new()
	blob_quad.size = Vector2(2,2)
	var blob_look := StandardMaterial3D.new()
	blob_look.albedo_color = FOAM
	blob_look.albedo_texture = puff_texture
	blob_look.vertex_color_use_as_albedo = true
	blob_look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blob_look.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	blob_look.billboard_keep_scale = true
	blob_look.roughness = 1.0
	blob_look.disable_receive_shadows = true
	# Spray scatters light: lit alone it went black in a cliff's shadow.
	blob_look.emission_enabled = true
	blob_look.emission = FOAM
	blob_look.emission_energy_multiplier = 0.35
	blob_look.render_priority = SPRAY_PRIORITY
	blob_quad.material = blob_look
	_blob_mesh = blob_quad
	# Droplets are the water ball's lens beads (shaders/water_bead.gdshader),
	# a couple of centimetres: opaque grey-white spheres read as hail.
	_bead_mesh = SphereMesh.new()
	_bead_mesh.radius = 0.022
	_bead_mesh.height = 0.044
	_bead_mesh.radial_segments = 8
	_bead_mesh.rings = 4
	var bead_look := ShaderMaterial.new()
	bead_look.shader = preload("res://shaders/water_bead.gdshader")
	bead_look.render_priority = SPRAY_PRIORITY
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
## `rings` defaults to RINGS (the edge falls use more, scripts/edge_falls.gd).
static func _build_ring_mesh(rings := RINGS) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in range(rings-1):
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
			"flux":fall.now.flux,"drop":fall.now.drop,"width":course[0].w*2.0,"presence":fall.presence,"ribbon":fall.now.ribbon})
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
	var found: Array = _chain(flow.cascades(DETECT))
	var ground: PackedFloat32Array = flow.grounds() if not found.is_empty() else PackedFloat32Array()
	var depth: PackedFloat32Array = flow.depths() if not found.is_empty() else PackedFloat32Array()
	var taken := {}
	for answer: Dictionary in found:
		var shape := _shape(answer)
		if shape.is_empty(): continue
		_hug(shape,ground)
		_land(shape,ground,depth)
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
			_falls.append({"id":_serial,"found":0.0,"lost":0.0,"shown":false,"presence":0.0,"target":shape,"now":{},"nodes":{},
				"poured":0.0,"pour_speed":POUR_START,"arrived":false,"drained":0.0,"drain_speed":POUR_START,"burst":0.0})
			best = _falls.size()-1
		taken[best] = true
		var fall: Dictionary = _falls[best]
		# A ribbon keeps unless it grows much wider or shallower before it has
		# poured; once poured it stays while the fall stands (its width capped):
		# a fresh spring's surge spreads it wide and runs it out over the plain
		# for a few seconds, and it went on and off.
		if float(fall.target.ribbon) > 0.5 and float(shape.ribbon) < 0.5:
			if fall.arrived or (float(shape.width) <= RIBBON_WIDTH*RIBBON_KEEP and float(shape.steepness) >= RIBBON_STEEP/RIBBON_KEEP): shape.ribbon = 1.0
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
	var lip: Vector3 = answer.lip
	var plunge: Vector3 = answer.plunge
	var run := Vector2(plunge.x-lip.x,plunge.z-lip.z).length()
	var narrow := course[0].w*2.0 <= RIBBON_WIDTH
	var steep := float(answer.drop) >= RIBBON_STEEP*maxf(run,0.01)
	return {"width":course[0].w*2.0,"steepness":float(answer.drop)/maxf(run,0.01),"course":stations,"flux":float(answer.flux),"drop":float(answer.drop),"pool":float(answer.plunge_depth),
		"lip":answer.lip,"plunge":answer.plunge,"lip_dir":answer.lip_dir,"ribbon":1.0 if narrow and steep else 0.0}

## Metres between one fall's plunge and the next one's lip, across and in
## height, for the two to be one fall.
const CHAIN_ACROSS := 1.0
const CHAIN_HEIGHT := 0.6

## Joins falls stacked one above the other into one: where a face eases for a
## step (a ledge a wire cut left), the steep cells part into two groups, and
## two ribbons stood with a gap between them, the upper ending on the ledge.
static func _chain(found: Array) -> Array:
	var falls := found.duplicate()
	var joined := true
	while joined:
		joined = false
		for a in range(falls.size()):
			for b in range(falls.size()):
				if a == b: continue
				var upper: Dictionary = falls[a]
				var lower: Dictionary = falls[b]
				var plunge: Vector3 = upper.plunge
				var lip: Vector3 = lower.lip
				if Vector2(plunge.x-lip.x,plunge.z-lip.z).length() > CHAIN_ACROSS or absf(plunge.y-lip.y) > CHAIN_HEIGHT: continue
				var course: PackedVector4Array = (upper.course as PackedVector4Array).duplicate()
				course.append_array(lower.course)
				var one := upper.duplicate()
				one.course = course
				one.plunge = lower.plunge
				one.plunge_depth = lower.plunge_depth
				one.flux = maxf(float(upper.flux),float(lower.flux))
				one.drop = float((upper.lip as Vector3).y-(lower.plunge as Vector3).y)
				falls[a] = one
				falls.remove_at(b)
				joined = true
				break
			if joined: break
	return falls

## Carries a shape's end down to the water under it: the steep cells can end
## above the pool, and the ribbon stopped in the air over it.
func _land(shape: Dictionary, ground: PackedFloat32Array, depth: PackedFloat32Array) -> void:
	if ground.is_empty() or depth.size() != ground.size(): return
	var course: PackedVector4Array = shape.course
	var last := course[course.size()-1]
	var c: int = flow.cell_at(Vector2(last.x,last.z))
	if c < 0: return
	var level := ground[c]+depth[c]
	if last.y > level+0.05:
		course[course.size()-1].y = level
		shape.course = course

## Narrows a shape's stations where the ground falls away to either side: a
## flat ribbon laid across a pinched peak stood out into the air at its edges
## and wrapped round the tip. Each station keeps the widest half width (down to
## W_MIN) whose ends lie over ground at most 0.12 m + 0.3 × the half width
## below the ground under its middle. Widths are capped at the widest ribbon.
func _hug(shape: Dictionary, ground: PackedFloat32Array) -> void:
	var course: PackedVector4Array = shape.course
	var n := course.size()
	var cap := RIBBON_WIDTH*RIBBON_KEEP*0.5
	var lip_dir: Vector2 = shape.lip_dir
	for r in range(n):
		var half := minf(course[r].w,cap)
		if not ground.is_empty():
			var ahead := Vector2(course[mini(r+1,n-1)].x-course[maxi(r-1,0)].x,course[mini(r+1,n-1)].z-course[maxi(r-1,0)].z)
			if ahead.length() < 0.05: ahead = lip_dir
			if ahead.length() > 0.001:
				var side := Vector2(-ahead.y,ahead.x).normalized()
				var middle := Vector2(course[r].x,course[r].z)
				var under := _ground_at(ground,middle)
				if is_finite(under):
					while half > W_MIN:
						var low := minf(_ground_at(ground,middle+side*half),_ground_at(ground,middle-side*half))
						if not is_finite(low) or under-low <= 0.12+0.3*half: break
						half = maxf(W_MIN,half*0.8)
		course[r].w = half
	shape.course = course

func _ground_at(ground: PackedFloat32Array, at: Vector2) -> float:
	var c: int = flow.cell_at(at)
	return ground[c] if c >= 0 and c < ground.size() else INF

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
		var here := float(fall.lost) <= GRACE
		var length := _length(now.course)
		fall.burst = move_toward(float(fall.burst),0.0,delta/BURST_SECONDS)
		if here and not fall.arrived:
			# Pouring: its shape holds still until the water lands.
			if float(now.ribbon) < 0.5:
				fall.arrived = true
			else:
				fall.pour_speed = minf(float(fall.pour_speed)+9.81*delta,POUR_MAX)
				fall.poured = float(fall.poured)+float(fall.pour_speed)*delta
				fall.arrived = float(fall.poured) >= length
			if fall.arrived: fall.burst = 1.0
			continue
		# A fall that stood as a wide spill and narrows into a ribbon pours one
		# in, rather than fading one up in place.
		if here and fall.arrived and float(target.ribbon) > 0.5 and float(now.ribbon) < 0.5 and float(fall.poured) <= 0.0:
			fall.now = target.duplicate(true)
			fall.arrived = false
			fall.pour_speed = POUR_START
			continue
		if fall.arrived:
			var course: PackedVector4Array = now.course
			var goal: PackedVector4Array = target.course
			for r in range(course.size()):
				var step := (goal[r]-course[r])*k
				var shift := Vector3(step.x,step.y,step.z).limit_length(MAX_SHIFT*delta)
				course[r] += Vector4(shift.x,shift.y,shift.z,step.w)
			now.course = course
			for key in ["flux","drop","pool","ribbon"]: now[key] = lerpf(now[key],target[key],k)
			now.lip_dir = (now.lip_dir as Vector2).lerp(target.lip_dir,k)
		if here:
			fall.presence = move_toward(fall.presence,1.0,delta/GROW)
			continue
		fall.presence = move_toward(fall.presence,0.0,delta/FADE)
		fall.drain_speed = minf(float(fall.drain_speed)+9.81*delta,POUR_MAX)
		fall.drained = float(fall.drained)+float(fall.drain_speed)*delta
		var gone := float(now.ribbon) < 0.5 or float(fall.drained) >= minf(float(fall.poured),length) or float(fall.drained) >= length
		if fall.presence <= 0.0 and gone: _drop(index)

## Metres along a course.
static func _length(course: PackedVector4Array) -> float:
	var total := 0.0
	for r in range(1,course.size()): total += Vector3(course[r].x,course[r].y,course[r].z).distance_to(Vector3(course[r-1].x,course[r-1].y,course[r-1].z))
	return total

## Every fall goes at once, nodes and all, rather than fading out over its
## GRACE and FADE: the water it stood on was replaced, by a new world or a
## load (scripts/water_flow_view.gd `_water_replaced`).
func reset() -> void:
	for index in range(_falls.size()-1,-1,-1): _drop(index)
	_since = 0.0
	for material in materials: material.set_shader_parameter("fall_foam_count",0)

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
		var rings := _rings(now,float(now.ribbon),strength)
		var nodes: Dictionary = fall.nodes
		var burst: float = fall.burst
		var pouring := float(now.ribbon) > 0.01 and float(fall.poured) > 0.0 and float(fall.drained) < (rings.travel as PackedFloat32Array)[RINGS-1]
		var visible := grown and (presence > 0.001 or burst > 0.001 or pouring)
		for node: Node3D in [nodes.foam,nodes.spray,nodes.waves]: node.visible = visible
		nodes.curtain.visible = visible and pouring
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
		# Onto running water it fades out over its last stretch; into a pool it
		# goes under the surface.
		material.set_shader_parameter("end_travel",(rings.travel as PackedFloat32Array)[RINGS-1])
		# Into a pool it goes under the surface; even so it softens at its end,
		# or a shallow pool showed a hard cut across it.
		material.set_shader_parameter("end_fade",maxf(0.5,1.0-smoothstep(0.04,0.18,now.pool)))
		material.set_shader_parameter("pour_front",100000.0 if fall.arrived else float(fall.poured))
		material.set_shader_parameter("drain_back",float(fall.drained) if float(fall.drained) > 0.0 else -1.0)
		nodes.curtain.custom_aabb = rings.bounds
		var impact: Vector3 = rings.impact
		var spread := (0.5+strength*0.5)*(0.8+0.1*minf(now.drop,4.0))
		# Spray puffs round the impact (the source's foamCluster: 4 + 3·flow),
		# each rising, swelling and fading on its own cycle.
		var blobs: MultiMesh = nodes.foam.multimesh
		blobs.visible_instance_count = clampi(roundi((4.0+3.0*strength)*minf(presence*1.5,1.0)),0,FOAM_BLOBS)
		for i in range(FOAM_BLOBS):
			var life := fposmod(_clock/PUFF_SECONDS+_hash(i+int(fall.id)*7,4),1.0)
			var angle := float(i)/FOAM_BLOBS*TAU+float(fall.id)*5.1+floorf(_clock/PUFF_SECONDS+_hash(i+int(fall.id)*7,4))*2.39
			var radius := (0.3+_hash(i,1)*0.7)*spread*0.8*(0.8+0.4*life)
			var extent := (0.07+_hash(i,2)*0.09)*(0.7+strength*0.25)*presence*(0.7+0.8*life)
			var point := impact+Vector3(cos(angle)*radius,0.05+life*(0.25+0.25*strength),sin(angle)*radius*0.75)
			blobs.set_instance_transform(i,Transform3D(Basis.from_scale(Vector3.ONE*extent),point))
			blobs.set_instance_color(i,Color(1,1,1,0.7*smoothstep(0.0,0.15,life)*(1.0-smoothstep(0.4,1.0,life))))
		var spray: GPUParticles3D = nodes.spray
		spray.position = impact+Vector3.UP*0.05
		# The landing's burst, then the steady spray.
		spray.amount_ratio = clampf(maxf(s,burst),0.05,1.0)
		spray.emitting = presence > 0.01 or burst > 0.01
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
		# Half the source's rate (1.15) on our few metres: the top of a ribbon
		# stays clear glass, whitening on the way down.
		air = minf(1.0,air*pow(0.5,dt)+steep[r]*dt*0.6*(1.0+strength))
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
	# The inlet opens within the first ring: over 2.5 rings (and a pinch over
	# 1.6) the curtain's visible top hung half a metre under its lip.
	var thick := PackedFloat32Array()
	var inlet := minf(1.0,(n-1)*0.08)
	for r in range(n):
		# A flat ribbon, not a swept tube: with a belly the sheet read as a
		# crumpled block of ice up close.
		var body := minf(half[r]*0.3,lerpf(RIBBON_THICK.x,RIBBON_THICK.y,strength))
		body *= 0.3+0.7*smoothstep(0.0,1.2,float(r))
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
		# The last ring goes under the water it lands in, deeper in a pool.
		if r == n-1: point.y = points[r].y-0.08-0.12*smoothstep(0.04,0.18,shape.pool)
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
	material.render_priority = CURTAIN_PRIORITY
	material.set_shader_parameter("fall_seed",float(id)*13.7)
	material.set_shader_parameter("painterly",true)
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
	foam.multimesh.use_colors = true
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
		var burst: float = fall.burst
		mist.visible = grown and (presence > 0.001 or burst > 0.001)
		if not mist.visible: continue
		var now: Dictionary = fall.now
		var strength := _strength(now.flux)
		var drop: float = now.drop
		if _clock-float(fall.nodes.mist_at) >= 0.1:
			fall.nodes.mist_at = _clock
			_place_mist(mist,fall,strength)
		# A plume as the water lands, settling to the steady mist.
		mist.material.set_shader_parameter("mist_strength",presence*(0.3+0.4*strength)+burst*burst*0.4)
		mist.material.set_shader_parameter("mist_scale",(0.35+0.3*strength)*clampf(0.6+0.2*drop,0.7,1.4)*(1.0+0.4*burst))
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
