extends SceneTree
## Headless probe for the Blender heron (scripts/life_rig_heron.gd). It checks the glb's
## clips, bones and baked colours and the shared life material, plays every clip, then
## runs one whole visit through LifeMoments on a stub world: fly in, glide, land, stand,
## strike in time with the ripple, a wading step, take off and leave.
## Run: Godot --headless --path . --script res://tools/probe_heron_rig.gd [-- --classic-life]
## With --classic-life only the visit runs, on the code-built heron.

const HeronRig = preload("res://scripts/life_rig_heron.gd")
const Moments = preload("res://scripts/life_moments.gd")
const Survey = preload("res://scripts/life_survey.gd")
const CLIPS := ["Stand", "Strike", "Stalk", "Fly", "Glide", "Land", "TakeOff"]

const LIFE_STUB := """
extends Node3D
signal moment(kind: String, position: Vector3)
var material: Material
var _rng := RandomNumberGenerator.new()
var clock := 0.0
var survey
var data
var scene
var rings := []
var editor := EditorStub.new()
class EditorStub extends Node:
	signal stroke_started(center: Vector3, radius: float, mode: String)
	signal stroke_moved(center: Vector3, radius: float, mode: String, amount: float)
	signal stroke_finished(center: Vector3, radius: float, mode: String)
func ripple(point: Vector3, size: float) -> void:
	rings.append([clock, point, size])
"""
const SURVEY_STUB := """
extends RefCounted
var height := PackedFloat32Array()
func wet_at(p: Vector2) -> bool:
	return true
"""
const DATA_STUB := """
extends RefCounted
func ground_height(p: Vector2) -> Variant:
	return 0.0
"""
const SCENE_STUB := """
extends RefCounted
var _precipitation := {"state": Vector2.ZERO}
"""

var failures := 0

func _stub(source: String) -> Object:
	var script := GDScript.new()
	script.source_code = source
	script.reload()
	return script.new()

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)

func _initialize() -> void:
	# Nodes only animate once they are in the running tree.
	process_frame.connect(_run, CONNECT_ONE_SHOT)
	# A script error leaves _run unfinished; never hang holding the Godot lock.
	create_timer(90.0).timeout.connect(func():
		print("FAIL: the probe did not finish")
		quit(1))

func _run() -> void:
	if not HeronRig.enabled():
		_visit(null)
		return
	# The model: clips, skeleton, mesh and the colours it carries.
	var model: Node3D = (load(HeronRig.GLB) as PackedScene).instantiate()
	root.add_child(model)
	var player: AnimationPlayer = model.find_child("AnimationPlayer", true, false)
	var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var mesh: MeshInstance3D = model.find_children("*", "MeshInstance3D", true, false)[0]
	var lengths := {}
	for clip in CLIPS:
		_check(player.has_animation(clip), "clip %s in the glb" % clip)
		if player.has_animation(clip): lengths[clip] = snappedf(player.get_animation(clip).length, 0.001)
	var arrays := mesh.mesh.surface_get_arrays(0)
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var yellow := Color.BLACK
	for c in colors:
		if c.r + c.g - 2.0 * c.b > yellow.r + yellow.g - 2.0 * yellow.b: yellow = c
	print("HERON_GLB clips=", lengths, " bones=", skeleton.get_bone_count(), " surfaces=", mesh.mesh.get_surface_count(),
		" tris=", (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3 if arrays[Mesh.ARRAY_INDEX] != null else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3,
		" skinned=", arrays[Mesh.ARRAY_BONES] != null, " bill_colour=", yellow)
	model.queue_free()

	# The shared life material, from the reference frogs LandLife borrows it from.
	var reference: Node = (load("res://assets/zen_reference/geometry.scn") as PackedScene).instantiate()
	var frogs := reference.find_child("mesh-40", true, false) as MultiMeshInstance3D
	var material: Material = frogs.multimesh.mesh.surface_get_material(0)
	print("HERON_MATERIAL ", material.get_class(), " shader=", (material as ShaderMaterial).shader.resource_path if material is ShaderMaterial else "",
		" base_color=", material.get_shader_parameter("base_color") if material is ShaderMaterial else null,
		" flat_faces=", material.get_shader_parameter("flat_faces") if material is ShaderMaterial else null)

	# Every clip on the rig, advanced by hand as LifeMoments does.
	var rig := HeronRig.new()
	root.add_child(rig)
	rig.setup(material)
	var head_bone := -1
	var rig_skeleton: Skeleton3D = rig.find_children("*", "Skeleton3D", true, false)[0]
	head_bone = rig_skeleton.find_bone("Head")
	for clip in CLIPS:
		rig.play(clip, 0.0)
		var heights := []
		var frames := roundi(rig.length() * 30.0)
		for f in range(frames + 1):
			if f == 0 or f == frames / 2 or f == frames:
				heights.append(snappedf((rig_skeleton.global_transform * rig_skeleton.get_bone_global_pose(head_bone)).origin.y, 0.001))
			rig.advance(1.0 / 30.0)
		print("HERON_CLIP ", clip, " length=", snappedf(rig.length(), 0.001), " head_y(start,mid,end)=", heights, " done=", rig.done())
	var mid_strike := 0.0
	rig.play("Strike", 0.0)
	rig.advance(HeronRig.STRIKE_CONTACT)
	mid_strike = (rig_skeleton.global_transform * rig_skeleton.get_bone_global_pose(head_bone)).origin.y
	print("HERON_STRIKE head_y at contact=", snappedf(mid_strike, 0.001))
	_check(mid_strike < 0.6, "the head is down at the water at strike contact")
	rig.queue_free()
	_visit(material)

## A whole visit through LifeMoments on a stub world.
func _visit(material: Material) -> void:
	if material == null:
		material = ShaderMaterial.new()
		material.shader = preload("res://shaders/reference_surface.gdshader")
	var life: Node3D = _stub(LIFE_STUB)
	root.add_child(life)
	life.material = material
	life._rng.seed = 7
	life.survey = _stub(SURVEY_STUB)
	life.survey.height.resize(Survey.SIDE * Survey.SIDE)
	life.data = _stub(DATA_STUB)
	life.scene = _stub(SCENE_STUB)
	var moments := Moments.new()
	life.add_child(moments)
	moments.setup(life)
	var cell := Survey.cell_at(Vector2(1.0, 1.0))
	moments._heron_arrive({"shallow": PackedInt32Array([cell]), "wade": PackedInt32Array([cell]), "level": 0.12})
	var step := 1.0 / 30.0
	var seen := ""
	var clips_seen := []
	var frames := 0
	while not moments._heron_state.is_empty() and frames < 30 * 200:
		life.clock += step
		moments._move_heron(step)
		frames += 1
		if moments._heron_state.is_empty(): break
		var now := "%s/%s" % [moments._heron_state.phase, moments._heron_rig.clip if moments._heron_rig else "classic"]
		if now != seen:
			seen = now
			clips_seen.append(now)
			print("HERON_VISIT t=%.2f %s at %s" % [life.clock, now, moments._heron.position.snapped(Vector3.ONE * 0.01)])
	print("HERON_VISIT ended t=%.2f ripples=%s" % [life.clock, life.rings.map(func(r): return [snappedf(r[0], 0.01), r[2]])])
	var wanted := ["in/Fly", "in/Glide", "in/Land", "stand/Stand", "stand/Strike", "out/TakeOff", "out/Fly"] if moments._heron_rig else ["in/classic", "stand/classic", "out/classic"]
	for want in wanted:
		_check(want in clips_seen, "the visit plays %s" % want)
	_check(moments._heron_pose.visible == (moments._heron_rig == null), "only one heron shows")
	_check(moments._heron_state.is_empty(), "the heron leaves")
	print("HERON_PROBE failures=", failures)
	quit(1 if failures > 0 else 0)
