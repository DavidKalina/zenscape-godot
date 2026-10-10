extends Node
## Holds a world's first sight under the loading veil (scripts/
## title_loading.gd) till its sky is ready (scripts/sky_islands.gd
## `sky_ready`): the layout worked out, every range's skyline made, the
## ranges within reach of the plate made in full and the islands round it
## baked (`make_ahead`), then everything the sky will draw drawn once, tiny,
## before the camera for FRAMES frames, so no pipeline is built on first
## sight (docs/performance/stutter.md); the ring's own fade-in skipped, the
## veil's gentle fade the one reveal. A world whose sky is ready (read back
## from the disk cache: scripts/sky_cache.gd) passes almost at once.
##
## The veil's line glows out with what is made (`sky_progress`). Never
## forever: past TIMEOUT the world is shown as it stands.

const FRAMES := 4
const TIMEOUT := 240.0
## Set once the sky is ready and warmed: the world may be shown.
var revealed := false
## For the record (msec): waiting for the sky, warming its pipelines.
var waited_ms := 0
var warm_ms := 0

## Whether a world's start waits for its sky: with the ring standing and
## the glide's sky made (`--no-sky-veil` shows the world at once, as
## before).
static func wanted(islands: Node) -> bool:
	if "--no-sky-veil" in preload("res://scripts/launch_args.gd").user_args() or islands == null: return false
	return preload("res://scripts/sky_world.gd").ring_on()

## Waits for the sky under `veil` (stage and line), then warms it.
func hold(islands: Node, camera: Camera3D, veil: Node) -> void:
	var began := Time.get_ticks_msec()
	if veil != null: veil.stage("Raising the mountains")
	# Ready, warmed, and still ready after the warming's frames (a new
	# layout or palette in them would want its sky made again): only then.
	while true:
		while not islands.sky_ready():
			islands.make_ahead(get_process_delta_time())
			if veil != null: veil.progress(islands.sky_progress())
			if _late(began): break
			await get_tree().process_frame
		if veil != null: veil.progress(1.0)
		waited_ms = Time.get_ticks_msec()-began
		var warming := Time.get_ticks_msec()
		await warm(islands,camera)
		warm_ms += Time.get_ticks_msec()-warming
		if islands.sky_ready() or _late(began): break
	var ring: Variant = islands.get("peaks")
	if ring != null and ring.get("ring") != null: ring.ring.settle_fade()
	revealed = true

## Past TIMEOUT: the world is shown as it stands.
func _late(began: int) -> bool:
	if Time.get_ticks_msec()-began <= TIMEOUT*1000.0: return false
	push_warning("The sky was not ready after %.0f s; the world is shown as it stands" % TIMEOUT)
	return true

## The sky's stand-ins (SkyIslands `standins`) a hand's width before the
## lens, 1 cm across, for FRAMES frames.
func warm(islands: Node, camera: Camera3D) -> void:
	if camera == null or not islands.has_method("standins"): return
	var holder := Node3D.new()
	holder.name = "SkyWarmup"
	add_child(holder)
	var made: Array = islands.standins()
	for node: GeometryInstance3D in made: holder.add_child(node)
	for i in range(FRAMES):
		for node: GeometryInstance3D in made:
			var extent := maxf(node.get_aabb().get_longest_axis_size(),0.001)
			node.global_transform = camera.global_transform*Transform3D(Basis.from_scale(Vector3.ONE*0.01/extent),Vector3(0,0,-0.5))
		await get_tree().process_frame
	holder.queue_free()
