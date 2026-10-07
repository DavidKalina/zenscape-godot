extends RefCounted
## The floating mountain, a sky cluster's motif (scripts/cluster_motifs.gd):
## a lead islet carrying a real peak (scripts/mountain_spire.gd), its trail
## winding up to a hut on a ledge, and at its feet a rocky islet with a
## cabin, reached by stepping stones, and a few bare crags hanging lower.
## Its motif data (MOTIF), and what the solver (scripts/cluster_solver.gd),
## the dresser (scripts/cluster_dresser.gd) and the validator ask of it:
##   `lay`: the "trail" feature: the hut (a cabin on the ledge, its door
##     looking out), lantern posts along the trail on its outer edge every
##     POST_EVERY m, and the hut's star;
##   `problems`: the peak's own checks (MountainSpire `problems`);
##   `prepare` (on a worker): the peak's faces and the trail's steps;
##   `furnish`: stands them up, the peak in the basalt ring's own material
##     (scripts/sky_peaks.gd `_ground`), fading in with the islet.
## Night: the hut's window high on the face burns like a star (a wide
## halo, seen from far over the sea), a string of lanterns climbs the trail
## round the peak, and the cabin at its feet is lit.

const MountainSpire = preload("res://scripts/mountain_spire.gd")
const Cabin = preload("res://scripts/cabin.gd")
const Builds = preload("res://scripts/showcase_builds.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")

const MOTIF := {
	"label":"Floating mountain","layout":"scatter",
	"rock":{"palettes":["basalt","slate"],"tone":Vector2(0.8,0.96)},"keel":Vector2(1.5,1.9),
	"night":{"windows":true,"lanterns":true,"beam":false},
	"roles":[
		{"name":"peak","anchor":true,"kind":"meadow","radius":Vector2(26.0,31.0),"height":Vector2(0.0,0.0),
			"spec":{"spire":{},"dome":0.3,"trees":Vector2i(2,5),"tree_pool":{"tree":1.0,"juniper":0.6,"birch":0.25},
				"drifts":Vector2i(5,8),"undergrowth":0.8},
			"features":[{"type":"trail"},{"type":"bearer","chance":0.5}]},
		{"name":"hold","kind":"hills","radius":Vector2(6.5,8.5),"height":Vector2(-3.4,-1.2),
			"spec":{"mounds":[],"dome":0.45,"trees":Vector2i(2,4),"tree_pool":{"tree":1.0,"juniper":0.7}},
			"features":[{"type":"cabin"},{"type":"lamps","count":Vector2i(1,2)},{"type":"bearer","chance":0.4}],
			"relation":{"type":"stones","to":"peak","stones":Vector2i(2,4)}},
		{"name":"crag","kind":"crag","radius":Vector2(2.8,5.5),"height":Vector2(-16.0,-3.0),"count":Vector2i(2,4),
			"spec":{"trees":Vector2i(0,2),"tree_pool":{"tree":1.0,"juniper":1.0}},
			"relation":{"type":"near","to":"peak","gap":Vector2(3.0,14.0)}},
	]}

## Lantern posts along the trail: every POST_EVERY m, the first FIRST_POST m
## up from the foot, POST_OUT m out from its middle.
const POST_EVERY := 8.5
const FIRST_POST := 2.0
const POST_OUT := 0.8
## The hut's star: its halo (m across near, strength), its light's reach
## (m) and energy, and how far over the window it burns (m).
const STAR_HALO := Vector2(5.5,1.0)
const STAR_REACH := 9.0
const STAR_ENERGY := 1.8
## The trail's steps: the run of one (m), its half width, its thickness, how
## far it stands proud of the bench, and the stone's tones.
const STEP_RUN := 0.6
const STEP_HALF := 0.62
const STEP_THICK := 0.3
const STEP_PROUD := 0.05
const STEP_TONES := [Color("7d776e"),Color("6f6a62"),Color("878177"),Color("746d63")]
## The cabin's footprint (m), as the solver's.
const CABIN := 2.3
## The peak fades in with its islet (SkyIslets FADE_IN), s.
const FADE_IN := 1.4

static var _steps_material: StandardMaterial3D
static var _peak_material: Material
static var _peak_source: Material

## The "trail" feature on member `m` (a solver member): the hut on the
## ledge, the posts along the trail, the hut's star.
static func lay(m: Dictionary, plan: Dictionary) -> void:
	var shape: RefCounted = m.shape
	var spire: RefCounted = shape.spire
	if spire == null:
		plan.problems.append("no peak for the trail on %s" % m.name)
		return
	# The hut: its door out over the ledge's edge (the model's door is +Z).
	var out: Vector2 = spire.hut_out
	var at: Vector2 = spire.hut
	var angle := atan2(out.x,out.y)
	shape.claim(at,CABIN)
	shape.add_record("cabin",at,angle,1.0)
	m.features.append({"type":"cabin","at":at,"angle":angle})
	var pose := Transform3D(Basis(Vector3.UP,angle),Vector3(at.x,shape.ground_at(at),at.y))
	var pane: AABB = Cabin.info().pane
	m.features.append({"type":"star","at":pose*(pane.get_center()+Vector3(0.6,0.3,0.0)),"halo":STAR_HALO,"reach":STAR_REACH,"energy":STAR_ENERGY})
	# The posts, on the trail's outer edge, their lanterns over it.
	var trail: PackedVector3Array = spire.trail
	var along := 0.0
	var next := FIRST_POST
	for k in range(1,trail.size()-1):
		along += Vector2(trail[k].x-trail[k-1].x,trail[k].z-trail[k-1].z).length()
		if along < next: continue
		next += POST_EVERY
		var here := Vector2(trail[k].x,trail[k].z)
		var way := (Vector2(trail[k+1].x,trail[k+1].z)-Vector2(trail[k-1].x,trail[k-1].z)).normalized()
		var across := Vector2(-way.y,way.x)
		var centre: Vector2 = spire.centre
		if across.dot(here-centre) < 0.0: across = -across
		var p := here+across*POST_OUT
		if here.distance_to(at) < MountainSpire.PAD+1.0: continue
		if not shape.on_land(p) or shape.wet(p): continue
		m.features.append({"type":"post","at":p,"angle":atan2(across.x,across.y)})

## The peak's own checks on member `m` (the validator's).
static func problems(m: Dictionary) -> Array:
	var spire: RefCounted = m.shape.spire
	if spire == null: return []
	return spire.problems(m.shape,m.name)

## The peak's faces and the trail's steps for member `member`, safe on a
## worker: {"peak": arrays, "steps": ArrayMesh}.
static func prepare(member: Dictionary) -> Dictionary:
	var shape: RefCounted = member.shape
	var spire: RefCounted = shape.spire
	return {"peak":spire.arrays(shape,SkyIslets.OFF_MAP),"steps":steps(spire.trail,int(member.seed))}

## The trail's stone steps: a slab every STEP_RUN m along it, its top level
## with the tread at its upper end and STEP_PROUD over it, so each stands a
## step over the last.
static func steps(trail: PackedVector3Array, seed_value: int) -> ArrayMesh:
	var st := Builds._begin()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	if trail.size() < 2: return Builds._end(st)
	var along := PackedFloat32Array([0.0])
	for k in range(1,trail.size()): along.append(along[k-1]+Vector2(trail[k].x-trail[k-1].x,trail[k].z-trail[k-1].z).length())
	var total := along[along.size()-1]
	var s := 0.0
	var k := 0
	while s+STEP_RUN <= total:
		var a := _along(trail,along,s,k)
		var b := _along(trail,along,s+STEP_RUN,k)
		var flat := Vector3(b.x-a.x,0.0,b.z-a.z)
		if flat.length() < 0.01:
			s += STEP_RUN
			continue
		var way := flat.normalized()
		var top := maxf(a.y,b.y)+STEP_PROUD
		var low := minf(a.y,b.y)-0.08
		var thick := maxf(top-low,STEP_THICK)*0.5
		var basis := Basis(way.cross(Vector3.UP).normalized(),Vector3.UP,-way)
		var mid := (a+b)*0.5
		var half := STEP_HALF*rng.randf_range(0.92,1.05)
		Builds.box(st,Vector3(mid.x,top-thick,mid.z),basis,Vector3(half,thick,STEP_RUN*0.5+0.02),STEP_TONES[rng.randi()%STEP_TONES.size()])
		s += STEP_RUN
	return Builds._end(st)

## The point `s` m along the trail (`along` its running lengths).
static func _along(trail: PackedVector3Array, along: PackedFloat32Array, s: float, _hint: int) -> Vector3:
	var lo := 0
	var hi := along.size()-1
	while hi-lo > 1:
		var mid := (lo+hi)/2
		if along[mid] <= s: lo = mid
		else: hi = mid
	var span := maxf(along[hi]-along[lo],1e-6)
	return trail[lo].lerp(trail[hi],clampf((s-along[lo])/span,0.0,1.0))

## Stands the peak and the steps under the member's islet `node` (a child
## of the islets, whose ground material the peak's is made from).
static func furnish(node: Node3D, made: Dictionary) -> void:
	var peak := MeshInstance3D.new()
	peak.name = "Spire"
	var arrays: Array = made.peak
	if (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty(): return
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.surface_set_material(0,_peak(node.get_parent()))
	peak.mesh = mesh
	peak.position = -SkyIslets.OFF_MAP
	peak.set_meta("skip_reflection",true)
	node.add_child(peak)
	var steps_node := MeshInstance3D.new()
	steps_node.name = "TrailSteps"
	steps_node.mesh = made.steps
	steps_node.material_override = _steps()
	steps_node.set_meta("skip_reflection",true)
	node.add_child(steps_node)
	# In with the islet's own faces (SkyIslets `_fade`).
	if node.is_inside_tree():
		peak.transparency = 1.0
		var tween := node.create_tween()
		tween.tween_property(peak,"transparency",0.0,FADE_IN)

## The peak's material: the islets' ground material (the plate's), as the
## basalt ring draws with it (SkyPeaks `_ground`): bare rock, the season's
## snow by each face's need, flat faces; no sea to cut it at.
static func _peak(islets: Node) -> Material:
	var source: Variant = islets.get("ground_source") if islets != null else null
	if _peak_material != null and _peak_source == source: return _peak_material
	var m: ShaderMaterial
	if source is ShaderMaterial:
		m = (source as ShaderMaterial).duplicate()
	else:
		m = ShaderMaterial.new()
		m.shader = preload("res://shaders/reference_surface.gdshader")
		m.set_shader_parameter("flat_faces",true)
		m.set_shader_parameter("palette_role",1)
		m.set_shader_parameter("base_color",Color.WHITE)
	# The sea's cut far under anything, so only the peak's snow and grain
	# are switched on (reference_surface `sea_cut`).
	m.set_shader_parameter("sea_cut",-1.0e7)
	m.set_shader_parameter("sea_fray",Vector2(0.0,0.0))
	m.set_shader_parameter("look_scale",4.0)
	m.set_shader_parameter("facet_soft",0.0)
	m.set_shader_parameter("peak_rock",true)
	_peak_material = m
	_peak_source = source
	return m

static func _steps() -> StandardMaterial3D:
	if _steps_material != null: return _steps_material
	_steps_material = StandardMaterial3D.new()
	_steps_material.vertex_color_use_as_albedo = true
	_steps_material.roughness = 0.95
	return _steps_material

## Lets the shared materials go (with the sky).
static func release() -> void:
	_peak_material = null
	_peak_source = null
	_steps_material = null
