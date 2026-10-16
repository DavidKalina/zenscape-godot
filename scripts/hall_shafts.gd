extends RefCounted
## Light shafts in the Sundered line's torn roofs (docs/scenic/hall-shafts.md):
## where a bay's roof mostly stands but is broken over a dark nave, a beam
## of sunlight slants down through the break with dust hanging in it. Rare
## on purpose (`openings`): none in open-sky bays or at torn ends. Visual
## only: no collision, nothing the lane or the sizes read.
##
## Placement is the hall's own data: the bay plans' roof state picks the
## bays, and SunderedBuild `near` records every roof strip left open as
## `weave.gaps` (hall frame, AABBs); a beam's top is that opening, so its
## edges are the real light's. Its
## direction is the scene's key light, read every frame from the shader
## global `zs_key_direction` that the celestial rig publishes (studies/
## celestial.gd): the day clock moves the sun, the beams lean with it with no
## CPU work, and they fade with its height, the cloud cover and the night.
##
## Two draws a piece, both built on the worker with the piece (`attach`,
## one hook in LineBuild.build) and hung under its Near node, so they are
## freed with it and hidden with it when the far mesh takes over:
##   Beams   one mesh of every beam's four slanted walls; shaders/
##           hall_shaft_beam.gdshader shears them along the light in the
##           vertex stage, fades their edges by view angle, scrolls noise
##           down them, fades them into the scene's depth and warms them
##           looking into the sun.
##   Dust    one MultiMesh of motes, billboards placed inside each beam in
##           the vertex stage (shaders/hall_shaft_dust.gdshader), sinking
##           slowly down the light, and thrown about by the plane's wake.
##
## The `Director` (one a line, `HallLine` makes it) feeds both: it keeps the
## plane's last few places as a wake trail for the dust shader, and tests the
## camera and the plane against every beam (the same slant) to flare the view
## warm for a moment as it passes through the light.
##
## Flags: --hall-shafts=0 turns it all off; --hall-shafts-gain=<x> the beams'
## brightness (1), --hall-shafts-dust=<x> the motes' count (1),
## --hall-shafts-flare=<x> the view's flare (1).

const BEAM_SHADER = preload("res://shaders/hall_shaft_beam.gdshader")
const DUST_SHADER = preload("res://shaders/hall_shaft_dust.gdshader")
const FLARE_SHADER = preload("res://shaders/hall_shaft_flare.gdshader")
const Hall = preload("res://scripts/ruin_kit_hall.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

## A beam's top: the roof slabs' top over the nave's floor (hall frame), the
## floor its light is traced to, and the openings narrower than this are not
## worth a beam.
const ROOF_Y := Hall.COLUMN_H+Hall.BEAM.x+Hall.SLAB
const FLOOR_Y := 0.0
const MIN_SIDE := 1.2
## Beams at most a piece, and the whole-roof bays a broken bay needs within two
## either side.
const MOST_BEAMS := 2
const MIN_DARK := 1
## The most a beam may be drawn long (m), however low the sun (the shader's
## own cap, SUN_FLOOR the lowest sun it still draws for).
const MAX_LEN := 46.0
## Motes a square metre of opening, the most and least a beam gets.
const MOTE_DENSITY := 1.7
const MOTES := Vector2i(36,150)
## Beams further than this from the camera are not drawn (m).
const FAR := 170.0
## The wake trail the dust shader reads: points, seconds between them, how
## long one lasts (s).
const TRAIL := 8
const TRAIL_STEP := 0.2
const TRAIL_LIFE := 2.6

static var _beam_material: ShaderMaterial = null
static var _dust_material: ShaderMaterial = null
static var _mote_mesh: QuadMesh = null

## Whether shafts are on (--hall-shafts=0 turns them off).
static func enabled() -> bool:
	return _flag("--hall-shafts=",1.0) > 0.0

static func _flag(prefix: String, fallback: float) -> float:
	for a: String in LaunchArgs.user_args():
		if a.begins_with(prefix): return float(a.get_slice("=",1))
	return fallback

## The beams of a built hall (SunderedBuild `near`'s root, in its hall
## frame, `plans` its bay plans): [{x0, x1, z0, z1}], rare and hard. A beam
## needs darkness round it, so only a bay whose roof is `broken` (mostly
## standing, a slab or two gone: `weave.gaps` is where) over a nave under
## roof gets one: never an open bay, a torn end, or a bay next to an open
## one. The bays with the most whole roof about them are taken first, at
## most MOST_BEAMS a piece and not in bays side by side; a bay gives its
## biggest opening.
static func openings(weave: Dictionary, plans: Array, seed_value: int) -> Array:
	var count := plans.size()
	var scored: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value+4409
	for i in range(1,count-1):
		var p: Dictionary = plans[i]
		if str(p.roof) != "broken" or int(p.torn) != 0: continue
		if str(plans[i-1].roof) == "open" or str(plans[i+1].roof) == "open": continue
		var dark := 0
		for k in range(maxi(0,i-2),mini(count,i+3)):
			if k != i and str(plans[k].roof) == "whole": dark += 1
		if dark < MIN_DARK: continue
		scored.append([dark+rng.randf()*0.9,i])
	scored.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var out: Array = []
	var taken: Array[int] = []
	for entry: Array in scored:
		var i: int = entry[1]
		if out.size() >= MOST_BEAMS: break
		if taken.any(func(t: int) -> bool: return absi(t-i) < 2): continue
		var best := {}
		var best_area := 0.0
		for item: Variant in weave.get("gaps",[]):
			var box: AABB = item
			if floori((box.position.x+box.end.x)*0.5/Hall.BAY) != i: continue
			if box.end.x-box.position.x < MIN_SIDE or box.size.z < MIN_SIDE: continue
			var area := (box.end.x-box.position.x)*box.size.z
			if area > best_area:
				best_area = area
				best = {"x0":box.position.x,"x1":box.end.x,"z0":box.position.z,"z1":box.end.z}
		if best.is_empty(): continue
		out.append(best)
		taken.append(i)
	return out

## Hangs the shafts under `near` (on the worker, with the build): a
## `Shafts` node holding the beams and the dust, which also records the
## openings for the Director. Returns the beams' count.
static func attach(near: Node3D, plans: Array, seed_value := 0) -> int:
	if not enabled() or not near.has_meta(&"weave"): return 0
	var open := openings(near.get_meta(&"weave") as Dictionary,plans,seed_value)
	if open.is_empty(): return 0
	var node := ShaftsNode.new()
	node.name = "Shafts"
	node.openings = open
	node.add_to_group(&"hall_shafts")
	var beams := MeshInstance3D.new()
	beams.name = "Beams"
	beams.mesh = _beam_mesh(open)
	beams.material_override = beam_material()
	beams.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beams.visibility_range_end = FAR
	beams.set_meta("skip_reflection",true)
	node.add_child(beams)
	var dust := MultiMeshInstance3D.new()
	dust.name = "Dust"
	dust.multimesh = _dust_multimesh(open)
	dust.material_override = dust_material()
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dust.visibility_range_end = FAR*0.55
	dust.set_meta("skip_reflection",true)
	node.add_child(dust)
	near.add_child(node)
	return open.size()

static func beam_material() -> ShaderMaterial:
	if _beam_material == null:
		var m := ShaderMaterial.new()
		m.shader = BEAM_SHADER
		m.set_shader_parameter("roof_y",ROOF_Y)
		m.set_shader_parameter("floor_y",FLOOR_Y)
		m.set_shader_parameter("max_len",MAX_LEN)
		m.set_shader_parameter("gain",_flag("--hall-shafts-gain=",1.0))
		_beam_material = m
	return _beam_material

static func dust_material() -> ShaderMaterial:
	if _dust_material == null:
		var m := ShaderMaterial.new()
		m.shader = DUST_SHADER
		m.set_shader_parameter("roof_y",ROOF_Y)
		m.set_shader_parameter("floor_y",FLOOR_Y)
		m.set_shader_parameter("max_len",MAX_LEN)
		m.set_shader_parameter("gain",_flag("--hall-shafts-gain=",1.0))
		var zero := PackedVector4Array()
		zero.resize(TRAIL)
		m.set_shader_parameter("wake_at",zero)
		m.set_shader_parameter("wake_way",zero)
		_dust_material = m
	return _dust_material

## Every beam's four walls: each wall a quad from the opening's edge at the
## roof (UV.y 0) to the same edge at the floor (UV.y 1, before the vertex
## stage shears it along the light), UV.x the distance round the opening (m),
## UV2 the distance along this wall and its length (m), COLOR.r the beam's
## own random.
static func _beam_mesh(open: Array) -> ArrayMesh:
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()
	var lo := Vector3.INF
	var hi := -Vector3.INF
	var rng := RandomNumberGenerator.new()
	rng.seed = 1031
	for o: Dictionary in open:
		var r := rng.randf()
		var corners := [Vector2(o.x0,o.z0),Vector2(o.x1,o.z0),Vector2(o.x1,o.z1),Vector2(o.x0,o.z1)]
		var run := 0.0
		for k in range(4):
			var a: Vector2 = corners[k]
			var b: Vector2 = corners[(k+1)%4]
			var len := a.distance_to(b)
			var base := v.size()
			v.append(Vector3(a.x,ROOF_Y,a.y))
			v.append(Vector3(b.x,ROOF_Y,b.y))
			v.append(Vector3(b.x,ROOF_Y,b.y))
			v.append(Vector3(a.x,ROOF_Y,a.y))
			uv.append(Vector2(run,0.0))
			uv.append(Vector2(run+len,0.0))
			uv.append(Vector2(run+len,1.0))
			uv.append(Vector2(run,1.0))
			for j in range(4): uv2.append(Vector2(0.0 if j == 0 or j == 3 else len,len))
			for j in range(4): col.append(Color(r,float(k)/4.0,0.0,1.0))
			idx.append_array([base,base+1,base+2,base,base+2,base+3])
			run += len
			lo = lo.min(Vector3(a.x,FLOOR_Y,a.y))
			hi = hi.max(Vector3(a.x,ROOF_Y,a.y))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_COLOR] = col
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	# The vertex stage throws the beams along the light, up to MAX_LEN
	# either way: the culling box is told so.
	var pad := Vector3(MAX_LEN,0.0,MAX_LEN)
	mesh.custom_aabb = AABB(lo-pad,(hi-lo)+pad*2.0)
	return mesh

static func _dust_multimesh(open: Array) -> MultiMesh:
	if _mote_mesh == null:
		var q := QuadMesh.new()
		q.size = Vector2.ONE
		_mote_mesh = q
	var density := _flag("--hall-shafts-dust=",1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2087
	var counts: Array[int] = []
	var total := 0
	for o: Dictionary in open:
		var area := float(o.x1-o.x0)*float(o.z1-o.z0)
		var n := clampi(roundi(area*MOTE_DENSITY*density),0,MOTES.y) if density > 0.0 else 0
		if n > 0: n = maxi(n,mini(MOTES.x,roundi(MOTES.x*density)))
		counts.append(n)
		total += n
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = _mote_mesh
	mm.instance_count = total
	var at := 0
	var lo := Vector3.INF
	var hi := -Vector3.INF
	for k in range(open.size()):
		var o: Dictionary = open[k]
		var sx := float(o.x1-o.x0)
		var sz := float(o.z1-o.z0)
		# The instance's frame maps (u,v) of the opening to the roof plane.
		var frame := Transform3D(Basis.from_scale(Vector3(sx,1.0,sz)),Vector3(o.x0,ROOF_Y,o.z0))
		for i in range(counts[k]):
			mm.set_instance_transform(at,frame)
			mm.set_instance_custom_data(at,Color(rng.randf(),rng.randf(),rng.randf(),rng.randf()))
			at += 1
		lo = lo.min(Vector3(o.x0,FLOOR_Y,o.z0))
		hi = hi.max(Vector3(o.x1,ROOF_Y,o.z1))
	var pad := Vector3(MAX_LEN,0.0,MAX_LEN)
	mm.custom_aabb = AABB(lo-pad,(hi-lo)+pad*2.0)
	return mm

## The node a piece's shafts hang in (under its Near node, in the hall
## frame): the openings, for the Director's tests.
class ShaftsNode extends Node3D:
	var openings: Array = []
