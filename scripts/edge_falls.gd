extends Node3D
## Waterfalls off the plate itself (docs/scenic/water-flow.md "Edge falls"):
## where the live water leaves the plate over its rim (a thumb's spillway
## through the rim, scripts/land_clay.gd, or any water reaching the edge), a
## fall pours from the lip down the block's faceted earth side and on past
## its bottom into the void.
##
## A few times a second the flow is asked which runs of edge cells water is
## leaving over (`WaterFlow.spills`, ZenScapeWaterFlow::spills): each is a
## lip where it leaves, the way out of the land there, a width and the flux.
## On the square plate the lip is on one of its four sides; on an island with
## an outline it is on the shore, facing any way. Spills are matched to the
## falls standing by the way they face and their place, and each fall eases
## to its latest spill as the waterfalls do (scripts/flow_falls.gd: HOLD,
## GROW, GRACE, FADE).
##
## Each fall is the waterfalls' strand (shaders/flow_fall.gdshader) on a
## course of its own:
## - off the lip it arcs out at the water's speed and then hugs the earth
##   side, standing its own thickness plus GAP off the facets (read from the
##   earth sides' mesh along rays, `_profile`: the square's sides or an
##   island's shore wall), aerating and whitening as it falls;
## - past the block's bottom, or where the rock under it falls away, it
##   falls free for TAIL metres (more with more water), spreading as it
##   breaks into strands, then droplets, then nothing (the shader's
##   `break_from`, `break_length`);
## - droplets fall from where it breaks up (GPU beads), and mist trails below
##   it (scripts/shared/fall_mist.gd, sinking): there is no ground to plunge into,
##   so no plunge foam and no ripple rings.
## A trickle is a torn veil and a full spring a curtain, as the waterfalls.
## It is drawn in the terrain's frame, so it turns with the world; while the
## diorama flips (scripts/diorama_flip.gd, which leaves it out of its
## snapshot) it is hidden.
const RINGS := 24
## ZenScapeWaterFlow::spills: edge cells leaving more than `cell_min` m³/s,
## runs bridging `gap` cells, carrying `min_flux` m³/s in all.
const DETECT := {"cell_min":0.0004,"min_flux":0.003,"gap":1,"max":8}
const READ_SECONDS := 0.25
## m³/s that makes a full curtain (as the waterfalls).
const FULL_FLUX := 0.2
## Metres a spill's lip may move between reads and stay the same fall, and
## the least cosine between the ways it faced.
const MATCH := 1.5
const MATCH_TURN := 0.5
const HOLD := 0.75
const GROW := 1.2
const GRACE := 0.5
const FADE := 2.0
const SMOOTH := 0.6
const MAX_SHOWN := 4
## Metres the sheet stands off the earth side beyond its own thickness, and
## the least half width.
const GAP := 0.05
const W_MIN := 0.1
## The share of its ballistic throw off the lip a fall takes: CLING, plus
## CLING_FLOW at a full curtain (it hugs the side, leaning out with more water).
const CLING := 0.25
const CLING_FLOW := 0.35
## Metres it falls free below the block's bottom: TAIL, plus TAIL_FLOW at a
## full curtain. The square block's bottom when the earth sides cannot be
## read (an island's is the rock under the lip, `_foot`).
const TAIL := 2.6
const TAIL_FLOW := 2.0
const BOTTOM := NativeTerrainData.SLAB_BASE
## Rings over the bend at the lip, down the face, and falling free.
const BEND_RINGS := 4
const FACE_RINGS := 12
## Metres between the face's samples (`_profile`).
const PROFILE_STEP := 0.2
## Metres out from the lip the rays start (less where other land stands
## nearer, across a bay), how far behind the lip the rock may stand and
## still be under the fall, and how far back (m a metre down) it may lean
## under the fall before the fall leaves it.
const PROFILE_REACH := 3.0
const PROFILE_BEHIND := 0.4
const PROFILE_LEAN := 0.25
const MIST := 48
const DROPS := 40
const FOAM := Color("f2f7f8")
const FlowFalls := preload("res://scripts/flow_falls.gd")

var flow: RefCounted
var editor: Node
var _falls: Array[Dictionary] = []
var _serial := 0
var _since := 0.0
var _clock := 0.0
var _ring_mesh: ArrayMesh
var _drop_mesh: SphereMesh
var _drop_material: ParticleProcessMaterial
## The earth sides as read: [mesh, placing], their faces facing out (their
## front, (c-a)×(b-a), as the terrain's) and their lowest point.
var _sides_for: Array = []
var _side_faces := PackedVector3Array()
var _side_fronts := PackedVector3Array()
var _sides_low := BOTTOM
var _sides_serial := 0
## Microseconds of the last read and frame update, for probes.
var last_read_usec := 0
var last_update_usec := 0
var worst_update_usec := 0
var hidden_for_flip := false

## `chunk_editor` holds the terrain (the frame the falls are drawn in) and
## the earth sides (`_skirt`) they hug.
func setup(water_flow: RefCounted, chunk_editor: Node) -> void:
	flow = water_flow
	editor = chunk_editor
	_ring_mesh = FlowFalls._build_ring_mesh(RINGS)
	# The water ball's lens beads (shaders/water_bead.gdshader), as the
	# waterfalls' spray: opaque white 5 cm balls read as hail up close.
	_drop_mesh = SphereMesh.new()
	_drop_mesh.radius = 0.03
	_drop_mesh.height = 0.07
	_drop_mesh.radial_segments = 8
	_drop_mesh.rings = 4
	var drop_look := ShaderMaterial.new()
	drop_look.shader = preload("res://shaders/water_bead.gdshader")
	drop_look.render_priority = FlowFalls.SPRAY_PRIORITY
	_drop_mesh.material = drop_look
	_drop_material = ParticleProcessMaterial.new()
	_drop_material.direction = Vector3(0,-1,0.25)
	_drop_material.spread = 14.0
	_drop_material.initial_velocity_min = 1.0
	_drop_material.initial_velocity_max = 2.6
	_drop_material.gravity = Vector3(0,-9.8,0)
	_drop_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	_drop_material.emission_box_extents = Vector3(0.5,0.3,0.05)
	_drop_material.scale_min = 0.5
	_drop_material.scale_max = 1.4
	var fade := Gradient.new()
	fade.set_color(0,Color(FOAM,0.9))
	fade.set_color(1,Color(FOAM,0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = fade
	_drop_material.color_ramp = ramp

## The number of edge falls standing.
func shown_count() -> int:
	var count := 0
	for fall: Dictionary in _falls:
		if fall.shown and float(fall.presence) > 0.0: count += 1
	return count

## What stands, for probes and films: side (-1 on a shore), normal, lip
## (plate metres), flux (m³/s),
## width, the drop down the block's face and in all, presence (0..1).
func describe() -> Array:
	var out := []
	for fall: Dictionary in _falls:
		if not fall.shown or fall.now.is_empty(): continue
		var now: Dictionary = fall.now
		out.append({"id":fall.id,"side":now.side,"normal":now.normal,"lip":now.lip,"flux":now.flux,"width":float(now.half)*2.0,
			"face_drop":float(now.lip.y)-float(fall.get("bottom",BOTTOM)),"drop":float(now.lip.y)-float(fall.get("end",BOTTOM)),"presence":fall.presence})
	return out

func _process(delta: float) -> void:
	if flow == null or not flow.ready: return
	var began := Time.get_ticks_usec()
	var scene := get_parent()
	var terrain: Node3D = editor.get("terrain") as Node3D if editor != null else null
	if terrain != null: global_transform = terrain.global_transform
	var flip: Variant = scene.get("flip") if scene != null else null
	hidden_for_flip = flip != null and flip.active()
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
	_draw(grown and not hidden_for_flip,paused)
	_update_mist(scene,grown and not hidden_for_flip)
	last_update_usec = Time.get_ticks_usec()-began
	worst_update_usec = maxi(worst_update_usec,last_update_usec)

## Reads the spills and matches them to the standing falls.
func _read(elapsed: float) -> void:
	var began := Time.get_ticks_usec()
	var found: Array = flow.spills(DETECT)
	var taken := {}
	for spill: Dictionary in found:
		var shape := _shape(spill)
		var best := -1
		var nearest := MATCH
		for k in range(_falls.size()):
			var target: Dictionary = _falls[k].target
			if taken.has(k) or (target.normal as Vector2).dot(shape.normal) < MATCH_TURN: continue
			var gap := Vector2(target.lip.x-shape.lip.x,target.lip.z-shape.lip.z).length()
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
	var standing := 0
	for fall: Dictionary in _falls:
		if fall.shown: standing += 1
	for fall: Dictionary in _falls:
		if not fall.shown and float(fall.found) >= HOLD and standing < MAX_SHOWN:
			fall.shown = true
			fall.now = fall.target.duplicate(true)
			standing += 1
	last_read_usec = Time.get_ticks_usec()-began

## A spill as a fall's shape: its side, the way out, the lip, half width,
## flux, and the water's speed out and depth at the brink.
func _shape(spill: Dictionary) -> Dictionary:
	return {"side":int(spill.side),"normal":spill.normal,"lip":spill.lip,"floor":float(spill.floor),
		"half":maxf(float(spill.half),W_MIN),"flux":float(spill.flux),"speed":float(spill.speed),"depth":float(spill.depth)}

## Eases every standing fall toward its latest spill, and its presence up or
## down; a fall faded out is removed.
func _ease(delta: float) -> void:
	var k := 1.0-exp(-delta/SMOOTH)
	for index in range(_falls.size()-1,-1,-1):
		var fall: Dictionary = _falls[index]
		if not fall.shown:
			if float(fall.lost) > GRACE: _drop(index)
			continue
		var now: Dictionary = fall.now
		var target: Dictionary = fall.target
		for key in ["floor","half","flux","speed","depth"]: now[key] = lerpf(now[key],target[key],k)
		now.lip = (now.lip as Vector3).lerp(target.lip,k)
		now.normal = (now.normal as Vector2).lerp(target.normal,k).normalized()
		var here := float(fall.lost) <= GRACE
		fall.presence = move_toward(fall.presence,1.0 if here else 0.0,delta/(GROW if here else FADE))
		if not here and fall.presence <= 0.0: _drop(index)

## Every fall goes at once, nodes and all, rather than fading out over its
## GRACE and FADE: the water it stood on was replaced, by a new world or a
## load (scripts/water_flow_view.gd `_water_replaced`).
func reset() -> void:
	for index in range(_falls.size()-1,-1,-1): _drop(index)
	_since = 0.0

func _drop(index: int) -> void:
	var nodes: Dictionary = _falls[index].nodes
	for node: Variant in nodes.values():
		if node is Node and is_instance_valid(node): node.queue_free()
	_falls.remove_at(index)

# --- The earth sides -----------------------------------------------------------

## The earth sides' faces in the terrain's frame that face out (a ray in
## from outside meets those first), read again whenever their mesh changes
## (a cut rim refits them, a new outline hangs a new shore wall). False when
## there are none to read.
func _read_sides() -> bool:
	var skirt: MeshInstance3D = editor.get("_skirt") as MeshInstance3D if editor != null else null
	var terrain: Node3D = editor.get("terrain") as Node3D if editor != null else null
	if skirt == null or skirt.mesh == null or not skirt.visible or terrain == null: return false
	var placing: Transform3D = terrain.global_transform.affine_inverse()*skirt.global_transform
	if _sides_for == [skirt.mesh,placing]: return true
	_sides_for = [skirt.mesh,placing]
	_sides_serial += 1
	var faces: PackedVector3Array = placing*skirt.mesh.get_faces()
	_side_faces = PackedVector3Array()
	_side_fronts = PackedVector3Array()
	_sides_low = BOTTOM
	for i in range(0,faces.size()-2,3):
		var front := (faces[i+2]-faces[i]).cross(faces[i+1]-faces[i])
		# Floors and ceilings: a level ray never meets them.
		if Vector2(front.x,front.z).length_squared() < 0.000001: continue
		_side_faces.append_array(PackedVector3Array([faces[i],faces[i+1],faces[i+2]]))
		_side_fronts.append(front)
		_sides_low = minf(_sides_low,minf(faces[i].y,minf(faces[i+1].y,faces[i+2].y)))
	return true

## How far the earth side stands out past the lip under a fall (the most of
## three rays across its width, in along its way out), every PROFILE_STEP
## metres down from just over its lip: {"top" (y of the first sample), "out"
## (PackedFloat32Array, -1 where no side was hit), "bottom" (where the fall
## leaves the rock)}. Each ray starts clear of other land in front of it
## (`_clearance`), so a far shore across a bay is never read as the wall.
## Down the face, the fall leaves the rock at the first sample where it
## stands more than PROFILE_BEHIND back from the lip, or leans back under
## the fall more than PROFILE_LEAN: where the wall ends on the island's
## hanging underside, or under an overhang, it falls free from there.
func _profile(now: Dictionary) -> Dictionary:
	var n := Vector3(now.normal.x,0.0,now.normal.y)
	var axis := Vector3(-n.z,0.0,n.x)
	var lip: Vector3 = now.lip
	var at := Vector3(lip.x,0.0,lip.z)
	var half: float = now.half
	var top := lip.y+0.1
	var out := PackedFloat32Array()
	var bottom := _foot(at)
	if not _read_sides():
		for k in range(ceili((top-bottom)/PROFILE_STEP)+1): out.append(0.3)
		return {"top":top,"out":out,"bottom":bottom}
	var acrosses := [-0.7*half,0.0,0.7*half]
	var reaches := []
	for across: float in acrosses: reaches.append(_clearance(at+axis*across,n))
	var reach: float = reaches.max()
	# Only the facets under the fall that face its way.
	var faces := _side_faces
	var near := PackedVector3Array()
	for i in range(0,faces.size()-2,3):
		if _side_fronts[i/3].dot(n) <= 0.0: continue
		var low := INF
		var high := -INF
		var back := INF
		var front := -INF
		for k in range(3):
			var p := faces[i+k]-at
			var a := p.dot(axis)
			var d := p.dot(n)
			low = minf(low,a)
			high = maxf(high,a)
			back = minf(back,d)
			front = maxf(front,d)
		if high >= -half-0.2 and low <= half+0.2 and front > -1.0 and back < reach: near.append_array(PackedVector3Array([faces[i],faces[i+1],faces[i+2]]))
	var lowest := INF
	var was := -1.0
	var y := top
	while y > minf(BOTTOM,_sides_low)-1.5:
		var most := -1.0
		for k in range(3):
			var from: Vector3 = at+n*float(reaches[k])+axis*float(acrosses[k])+Vector3.UP*y
			for i in range(0,near.size()-2,3):
				var hit: Variant = Geometry3D.ray_intersects_triangle(from,-n,near[i],near[i+1],near[i+2])
				if hit != null: most = maxf(most,(Vector3(hit)-at).dot(n))
		var under := most > -PROFILE_BEHIND and (lowest == INF or most >= was-PROFILE_LEAN*PROFILE_STEP)
		if not under and lowest < INF: break
		out.append(most)
		if under:
			lowest = y
			was = most
		y -= PROFILE_STEP
	if lowest < INF: bottom = lowest
	return {"top":top,"out":out,"bottom":bottom}

## Where the earth ends under `at` when no side is read there: the rock
## under an island's shore (NativeTerrainData `underside`), or the square
## block's bottom.
func _foot(at: Vector3) -> float:
	var data: NativeTerrainData = editor.get("data") as NativeTerrainData if editor != null else null
	if data == null or data.outline.is_empty(): return BOTTOM
	return data.underside(Vector2(at.x,at.z))

## Metres out from `at` along `n` clear of other land, up to PROFILE_REACH:
## across a bay the rays start short of the far shore's wall.
func _clearance(at: Vector3, n: Vector3) -> float:
	var data: NativeTerrainData = editor.get("data") as NativeTerrainData if editor != null else null
	if data == null or data.outline.is_empty(): return PROFILE_REACH
	var r := 0.5
	while r <= PROFILE_REACH:
		if data.ground_height(Vector2(at.x+n.x*r,at.z+n.z*r)) != null: return maxf(r-0.25,0.3)
		r += 0.25
	return PROFILE_REACH

## The side's standing out at height `y` from a profile, and at its bottom
## below it; 0 (the rim) above the side's top.
static func _face_at(profile: Dictionary, y: float) -> float:
	var out: PackedFloat32Array = profile.out
	if out.is_empty(): return 0.0
	var f := (float(profile.top)-maxf(y,float(profile.bottom)))/PROFILE_STEP
	var k := clampi(floori(f),0,out.size()-1)
	var a := out[k]
	var b := out[mini(k+1,out.size()-1)]
	if a < 0.0 and b < 0.0: return 0.0
	if a < 0.0: return b
	if b < 0.0: return a
	return lerpf(a,b,clampf(f-k,0.0,1.0))

# --- The fall --------------------------------------------------------------------

## The strand's rings for a fall: off the lip at the water's speed, down the
## earth side just off its facets, and free below the rock under it.
func _rings(fall: Dictionary, presence: float, strength: float) -> Dictionary:
	var now: Dictionary = fall.now
	var key := [_sides_serial,snappedf(now.lip.x,0.1),snappedf(now.lip.z,0.1),snappedf(now.normal.x,0.05),snappedf(now.normal.y,0.05),snappedf(now.half,0.1),snappedf(now.lip.y,0.05)]
	if fall.get("profile_key") != key:
		fall.profile_key = key
		fall.profile = _profile(now)
	var profile: Dictionary = fall.profile
	var n := Vector3(now.normal.x,0.0,now.normal.y)
	var lip: Vector3 = now.lip
	var at := Vector3(lip.x,0.0,lip.z)
	var bottom: float = profile.bottom
	var face_drop := maxf(lip.y-bottom,0.6)
	var tail := TAIL+TAIL_FLOW*strength
	fall.bottom = bottom
	fall.end = bottom-tail
	var speed := maxf(float(now.speed),0.3)
	var lip_half := maxf(float(now.half),W_MIN)
	var bend := [0.0,0.06,0.2,0.45]
	var drops := PackedFloat32Array()
	for r in range(RINGS):
		if r < BEND_RINGS: drops.append(minf(bend[r],face_drop*0.5))
		elif r < BEND_RINGS+FACE_RINGS: drops.append(lerpf(drops[BEND_RINGS-1],face_drop,float(r-BEND_RINGS+1)/FACE_RINGS))
		else: drops.append(face_drop+tail*float(r-BEND_RINGS-FACE_RINGS+1)/(RINGS-BEND_RINGS-FACE_RINGS))
	var last_face := BEND_RINGS+FACE_RINGS-1
	# Thickness first (it sets how far off the side the sheet stands).
	var thick := PackedFloat32Array()
	for r in range(RINGS):
		var below := clampf((drops[r]-face_drop)/tail,0.0,1.0)
		var body := (0.035+0.1*strength)*(0.3+0.7*smoothstep(0.0,3.0,float(r)))*(1.0+0.6*below)
		thick.append(minf(body,lip_half*0.5))
	var points := PackedVector3Array()
	var standing := 0.0
	for r in range(RINGS):
		var y := lip.y-drops[r]
		var out := 0.0
		if r == 0:
			# Under the brink, so the water comes out of the notch, not a tube mouth.
			out = -0.12
			y = lip.y-maxf(float(now.depth),0.03)*0.5
		else:
			# A sheet this thin clings to the side over the lip rather than
			# flying its full ballistic arc; a strong spring leans out more.
			var thrown := speed*sqrt(2.0*drops[r]/9.81)*(CLING+CLING_FLOW*strength)
			if r <= last_face: standing = _face_at(profile,y)+thick[r]+GAP
			out = maxf(standing,thrown)
		points.append(at+n*out+Vector3.UP*y)
	var across_axis := n.cross(Vector3.UP).normalized()
	var tangents := PackedVector3Array()
	var outward := PackedVector3Array()
	var steep := PackedFloat32Array()
	for r in range(RINGS):
		var tangent := (points[mini(r+1,RINGS-1)]-points[maxi(r-1,0)]).normalized()
		tangents.append(tangent)
		outward.append(across_axis.cross(tangent).normalized())
		steep.append(clampf(-tangent.y,0.0,1.0))
	var tau := PackedFloat32Array([0.0])
	var travel := PackedFloat32Array([0.0])
	for r in range(1,RINGS):
		var step := points[r].distance_to(points[r-1])
		tau.append(tau[r-1]+step/(1.0+3.0*steep[r]))
		travel.append(travel[r-1]+step)
	var aer := PackedFloat32Array()
	var air := 0.0
	for r in range(RINGS):
		var dt := tau[r]-tau[r-1] if r > 0 else 0.0
		air = minf(1.0,air*pow(0.5,dt)+steep[r]*dt*1.15*(1.0+strength))
		aer.append(air)
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
	for r in range(RINGS):
		var below := clampf((drops[r]-face_drop)/tail,0.0,1.0)
		var neck := 0.7 if r == 0 else (0.88 if r < BEND_RINGS else 1.0)
		var half := lip_half*neck*(1.0+0.25*aer[r])*(1.0+0.7*below)*lerpf(0.3,1.0,presence)
		var t := thick[r]*presence
		centers[r] = Vector4(points[r].x,points[r].y,points[r].z,tau[r])
		axis_a[r] = Vector4(across_axis.x,across_axis.y,across_axis.z,half)
		axis_b[r] = Vector4(outward[r].x,outward[r].y,outward[r].z,t)
		aer_steep[r] = Vector2(aer[r],steep[r])
		travels[r] = travel[r]
		low = low.min(points[r])
		high = high.max(points[r])
		widest = maxf(widest,half)
	return {"centers":centers,"across":axis_a,"outward":axis_b,"aer_steep":aer_steep,"travel":travels,
		"bounds":AABB(low,high-low).grow(widest+0.8),"break_from":travel[last_face],"break_length":maxf(travel[RINGS-1]-travel[last_face],0.5),
		"bottom_point":points[last_face],"points":points,"aer":aer,"half":lip_half,"across_axis":across_axis,"normal":n,"face_drop":face_drop}

## Places every standing fall's curtain and droplets.
func _draw(visible_now: bool, paused: bool) -> void:
	for fall: Dictionary in _falls:
		if not fall.shown or fall.now.is_empty(): continue
		if fall.nodes.is_empty(): fall.nodes = _create(fall.id)
		var presence: float = fall.presence
		var strength := _strength(fall.now.flux)
		var nodes: Dictionary = fall.nodes
		var shown := visible_now and presence > 0.001
		nodes.curtain.visible = shown
		nodes.drops.visible = shown
		if not shown: continue
		var rings := _rings(fall,presence,strength)
		fall.rings = rings
		var s := presence*strength
		var material: ShaderMaterial = nodes.curtain.material_override
		material.set_shader_parameter("ring_count",RINGS)
		material.set_shader_parameter("centers_tau",rings.centers)
		material.set_shader_parameter("axis_a_width",rings.across)
		material.set_shader_parameter("axis_b_thick",rings.outward)
		material.set_shader_parameter("aer_steep",rings.aer_steep)
		material.set_shader_parameter("ring_travel",rings.travel)
		material.set_shader_parameter("body_white",0.3*(1.0-smoothstep(0.15,0.8,float(rings.half))))
		material.set_shader_parameter("veil",1.0-smoothstep(0.15,0.85,s))
		material.set_shader_parameter("streak_speed",clampf(0.6*sqrt(2.0*9.81*float(rings.face_drop)),2.5,7.0))
		material.set_shader_parameter("break_from",rings.break_from)
		material.set_shader_parameter("break_length",rings.break_length)
		nodes.curtain.custom_aabb = rings.bounds
		# Droplets from where it breaks up, falling on below it.
		var drops: GPUParticles3D = nodes.drops
		var across: Vector3 = rings.across_axis
		var normal: Vector3 = rings.normal
		drops.transform = Transform3D(Basis(across,Vector3.UP,normal),(rings.bottom_point as Vector3)+Vector3.DOWN*0.3)
		drops.amount_ratio = clampf(s*1.2,0.08,1.0)
		drops.speed_scale = 0.0 if paused else 1.0
		var extents: Vector3 = _drop_material.emission_box_extents
		if not is_equal_approx(extents.x,float(rings.half)):
			# Shared by every fall: the widest sets it (a few falls at most).
			_drop_material.emission_box_extents = Vector3(maxf(float(rings.half),0.15),0.35,0.06)

## One fall's nodes: the curtain and the droplets (children here), and its
## mist (a canvas layer, as the waterfalls').
func _create(id: int) -> Dictionary:
	var curtain := MeshInstance3D.new()
	curtain.name = "EdgeFall_%d" % id
	curtain.mesh = _ring_mesh
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/flow_fall.gdshader")
	material.render_priority = FlowFalls.CURTAIN_PRIORITY
	material.set_shader_parameter("fall_seed",float(id)*17.3+3.0)
	var white := PackedFloat32Array()
	for s in range(12): white.append(_hash(s*23+id,4))
	material.set_shader_parameter("section_white",white)
	curtain.material_override = material
	curtain.set_meta("skip_reflection",true)
	add_child(curtain)
	var drops := GPUParticles3D.new()
	drops.name = "EdgeFallDrops_%d" % id
	drops.process_material = _drop_material
	drops.amount = DROPS
	drops.lifetime = 1.1
	drops.randomness = 0.5
	drops.local_coords = false
	drops.visibility_aabb = AABB(Vector3(-4,-10,-4),Vector3(8,12,8))
	drops.draw_pass_1 = _drop_mesh
	drops.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(drops)
	var mist := preload("res://scripts/shared/fall_mist.gd").new()
	mist.name = "EdgeFallMist_%d" % id
	var recipe := {"positions":[],"velocity":[],"phase":[],"size":[],"rise":-1.0}
	for i in range(MIST):
		recipe.positions.append_array([0.0,-1000.0,0.0])
		recipe.velocity.append_array([0.0,0.0,0.0])
		recipe.phase.append(_hash(i+id*64,10))
		recipe.size.append(0.7+_hash(i+id*64,11)*0.8)
	add_child(mist)
	mist.setup(recipe)
	return {"curtain":curtain,"drops":drops,"mist":mist,"mist_at":-1.0}

## Mist trailing below each fall: from where it breaks up down its free
## fall, sinking and drifting with the wind, more with more water.
func _update_mist(scene: Node, visible_now: bool) -> void:
	if scene == null or scene.get("camera") == null or _falls.is_empty(): return
	var depth: CompositorEffect = null
	if scene.get("_display_fog") != null: depth = scene._display_fog.depth
	elif scene.has_node("WaterfallSpray"):
		var original: CanvasLayer = scene.get_node("WaterfallSpray")
		original.update_view(scene.camera)
		depth = original.fallback_depth
	for fall: Dictionary in _falls:
		if fall.nodes.is_empty() or fall.now.is_empty() or not fall.has("rings"): continue
		var mist: CanvasLayer = fall.nodes.mist
		var presence: float = fall.presence
		mist.visible = visible_now and presence > 0.001
		if not mist.visible: continue
		var strength := _strength(fall.now.flux)
		if _clock-float(fall.nodes.mist_at) >= 0.1 or float(fall.nodes.mist_at) < 0.0:
			fall.nodes.mist_at = _clock
			_place_mist(mist,fall,strength)
		mist.material.set_shader_parameter("mist_strength",presence*(0.3+0.45*strength))
		mist.material.set_shader_parameter("mist_scale",0.4+0.35*strength)
		mist.material.set_shader_parameter("rise_height",-(0.8+1.4*strength))
		mist.update_view(scene.camera,depth)

func _place_mist(mist: CanvasLayer, fall: Dictionary, strength: float) -> void:
	var rings: Dictionary = fall.rings
	var points: PackedVector3Array = rings.points
	var aer: PackedFloat32Array = rings.aer
	var across: Vector3 = rings.across_axis
	var normal: Vector3 = rings.normal
	var half: float = rings.half
	var to_world := global_transform
	# Emitters: the free fall's rings (heavier lower down) and the aerated
	# lower face.
	var emitters := []
	for r in range(BEND_RINGS+FACE_RINGS/2,RINGS):
		var free := r >= BEND_RINGS+FACE_RINGS
		if not free and aer[r] < 0.5: continue
		emitters.append({"at":points[r],"weight":(1.0+float(r-BEND_RINGS-FACE_RINGS)*0.4) if free else aer[r]*0.6,"spread":half*(1.4 if free else 1.0)})
	if emitters.is_empty(): return
	var total := 0.0
	for emitter: Dictionary in emitters: total += emitter.weight
	var count := mini(MIST,roundi(36.0*strength)+12)
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
		var offset := (_hash(i,3)*2.0-1.0)*float(emitter.spread)
		var off := (_hash(i,5)-0.3)*0.6
		var at: Vector3 = emitter.at
		origins[i] = to_world*(at+across*offset+normal*off)
		var drift := Vector3(normal*(0.2+_hash(i,6)*0.5)+across*(_hash(i,8)-0.5)*0.6)
		motion[i] = Vector4(drift.x,drift.z,_hash(i+int(fall.id)*64,10),0.7+_hash(i+int(fall.id)*64,11)*0.8)
	mist.material.set_shader_parameter("origins",origins)
	mist.material.set_shader_parameter("motion",motion)
	mist.material.set_shader_parameter("particle_count",count)

static func _strength(flux: float) -> float:
	return clampf(sqrt(maxf(flux,0.0)/FULL_FLUX),0.15,1.0)

static func _hash(i: int, salt: int) -> float:
	return fposmod(sin(float(i)*12.9898+float(salt)*78.233)*43758.5453,1.0)
