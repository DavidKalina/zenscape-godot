extends SceneTree
## The clouds' shade on the land holds steady in flight: the endless flight
## flown from its start (the plane flying on, the day running), the shade map
## (scripts/endless/endless_clouds.gd, shaders/endless_cloud_march.glsl
## shadow_pass) read back each frame and each new map compared with the last
## at the same ground (the squares' texel offset). A texel whose sun let
## through moves past JUMP between two redraws is a jump: drifting cloud moves
## a shade edge a few hundredths of a texel a redraw, so only a flicker jumps.
## The march stepped along the light's line with leaps (--cloud-shade=old)
## jumped about 120 texels a redraw at the small clouds, and the grass under
## them flickered; it runs first, so the test is seen to catch it.
##   godot --path . --script tests/test_cloud_shade_steady.gd
## suite: gpu

const LaunchArgs = preload("res://scripts/launch_args.gd")
const JUMP := 0.05
## Texels jumping a redraw at most (1.5 at a fixed 60 fps, 5 at a PC's real
## frame rate), and at least under the old march.
const MOST := 15.0
const OLD_LEAST := 30.0
const SETTLE := 120
const FRAMES := 160
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	if DisplayServer.get_name() == "headless" or RenderingServer.get_rendering_device() == null:
		print("The cloud shade needs a GPU window")
		quit(2)
		return
	create_timer(170.0).timeout.connect(func() -> void: push_error("cloud shade test timed out"); quit(2))
	var old: Dictionary = await _fly(["--cloud-shade=old"])
	var now: Dictionary = await _fly([])
	check(old.redraws >= 40 and now.redraws >= 40,"The shade is redrawn as the plane flies (%d, %d redraws)" % [old.redraws,now.redraws])
	check(now.shaded > 0.0,"There is cloud shade on the land (%.1f %% of the map)" % (now.shaded*100.0))
	check(old.jumps > OLD_LEAST,"The old march's shade jumps (%.1f texels a redraw)" % old.jumps)
	check(now.jumps < MOST,"The shade holds steady (%.1f texels a redraw jump, at most %.0f)" % [now.jumps,MOST])
	print("cloud shade steady: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)

## The flight with `flags`: redraws seen, texels jumping a redraw, and the
## share of the map in shade (the last map).
func _fly(flags: Array) -> Dictionary:
	LaunchArgs.set_override(PackedStringArray(["--no-title"]+flags))
	var study: Node = load("res://studies/endless_flight.tscn").instantiate()
	root.add_child(study)
	current_scene = study
	for i in SETTLE: await process_frame
	var clouds: Node = study.look.clouds
	var n: int = clouds.effect.SHADOW_TEXELS
	var prev := PackedFloat32Array()
	var prev_at := Vector4.ZERO
	var redraws := 0
	var jumps := 0
	var shaded := 0.0
	for i in FRAMES:
		await process_frame
		var at: Vector4 = clouds._shade_drawn
		var image: Image = clouds.effect.shadow.get_image()
		if image == null: continue
		image.convert(Image.FORMAT_RF)
		var now := image.get_data().to_float32_array()
		if prev.size() == now.size():
			var texel := at.z/n
			var dx := roundi((at.x-prev_at.x)/texel)
			var dy := roundi((at.y-prev_at.y)/texel)
			var changed := false
			var jumped := 0
			var dark := 0
			for y in range(8,n-8):
				for x in range(8,n-8):
					var a := now[y*n+x]
					if a < 0.8: dark += 1
					var px := x+dx
					var py := y+dy
					if px < 0 or py < 0 or px >= n or py >= n: continue
					var b := prev[py*n+px]
					if a != b: changed = true
					if absf(a-b) > JUMP: jumped += 1
			if changed:
				redraws += 1
				jumps += jumped
			shaded = dark/float((n-16)*(n-16))
		prev = now
		prev_at = at
	study.queue_free()
	for i in 30: await process_frame
	LaunchArgs.set_override(null)
	return {"redraws":redraws,"jumps":float(jumps)/maxi(redraws,1),"shaded":shaded}
