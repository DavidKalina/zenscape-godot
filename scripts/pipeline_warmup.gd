extends Node3D
## Draws what the world will draw later once, while it opens, so the GPU
## builds those pipelines under the loading veil instead of mid-gesture
## (docs/performance/stutter.md). A pipeline is built the first time a
## shader draws in a given kind of pass, so each is drawn where it will be
## drawn: every plant and prop batch in the main view, as GardenView batches
## it, and their clip-shader copies in the live water's reflection view,
## through the reflection's own build.
##
## The stand-ins are 1 cm across just in front of the camera: they draw
## (and so bind their pipelines) without covering a pixel worth seeing.

static func enabled() -> bool:
	return not "--no-pipeline-warmup" in preload("res://scripts/launch_args.gd").user_args()

## Frames each stage stays up. The first draw builds the pipeline; the rest
## let shadow and specialisation passes catch up.
const FRAMES := 4

var last_usec := {}

func warm(scene: Node3D) -> void:
	var began := Time.get_ticks_usec()
	var editor: NativeChunkEditor = scene._chunk_editor
	if editor == null or editor.content == null or scene.camera == null: return
	_batches(editor.content)
	_replay()
	_follow(scene.camera)
	for i in range(FRAMES): await get_tree().process_frame
	last_usec.batches = Time.get_ticks_usec()-began
	# Live water sets up a few frames after the world; its view is worth waiting
	# for, briefly.
	var wanted := NativeChunkEditor.flow_wanted() and not "--no-live-reflection" in preload("res://scripts/launch_args.gd").user_args()
	for i in range(240 if wanted else 0):
		if editor.flow_view != null and editor.flow_view.reflection != null: break
		await get_tree().process_frame
	var reflection: Node = editor.flow_view.reflection if editor.flow_view != null else null
	if reflection != null:
		var stage := Time.get_ticks_usec()
		await reflection.warm(scene,self)
		last_usec.reflection = Time.get_ticks_usec()-stage
	for child in get_children(): child.queue_free()
	last_usec.total = Time.get_ticks_usec()-began

## One single-instance batch per registry part, formatted as GardenView's.
func _batches(content: GardenView) -> void:
	for key: String in content._meshes:
		var mesh: Mesh = content._meshes[key]
		if mesh == null or not content._materials.has(key): continue
		var batch := MultiMeshInstance3D.new()
		batch.name = "Warm_"+key.replace(":","_")
		batch.multimesh = MultiMesh.new()
		batch.multimesh.transform_format = MultiMesh.TRANSFORM_3D
		batch.multimesh.use_colors = true
		batch.multimesh.use_custom_data = true
		batch.multimesh.mesh = mesh
		batch.multimesh.instance_count = 1
		batch.multimesh.set_instance_transform(0,Transform3D.IDENTITY)
		batch.multimesh.set_instance_color(0,Color.WHITE)
		batch.material_override = content._materials[key]
		if key == "grass": batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		batch.extra_cull_margin = 1.0
		add_child(batch)

## Everything a played session drew (scripts/pipeline_manifest.gd): effects,
## water, cursors, the sculpted terrain's layout.
func _replay() -> void:
	var count := 0
	for entry: Dictionary in preload("res://scripts/pipeline_manifest.gd").load_entries():
		var node := preload("res://scripts/pipeline_manifest.gd").standin(entry)
		if node == null: continue
		node.name = "Replay_%d" % count
		add_child(node)
		count += 1
	last_usec.replayed = count

## Keep the stand-ins a hand's width before the lens, shrunk to 1 cm.
func _follow(camera: Camera3D) -> void:
	var size := 0.01
	for child in get_children():
		var node := child as GeometryInstance3D
		if node == null: continue
		var extent := maxf(node.get_aabb().get_longest_axis_size(),0.001)
		node.global_transform = camera.global_transform*Transform3D(Basis.from_scale(Vector3.ONE*size/extent),Vector3(0,0,-0.5))
