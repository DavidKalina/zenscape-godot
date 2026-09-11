extends SceneTree
## The crossing is part of the weather and part of the world: the wind bows it by
## an amount that tells a breeze from a storm, rain darkens the boards, snow caps
## them, a strike nearby runs down the rope, a Bigfoot-mass weight visibly dips
## the middle and lets it back up, and a thrown rock lands on the deck rather
## than through it.
##
## Every number here is read off the live study -- the real sky driving the real
## rope -- rather than a bridge built in isolation, because the thing being
## tested is the wiring as much as the physics.
##
## Instantiates the twin-chunk study, so it needs a real window and the native
## kernels. Never --headless: the fidelity scene hangs there.
##
## how to run
##   "$HOME/Applications/Godot.app/Contents/MacOS/Godot" --path . \
##     --rendering-method forward_plus --script res://tests/test_bridge_weather.gd
##
## The bands, all measured at the study's 46 m span:
const CALM_BOW := 0.15        ## `clear`: a sway you have to look for.
const WINDY_BOW := Vector2(0.25, 0.70)   ## `rain`: the deck leans.
const STORM_BOW := Vector2(0.9, 2.2)     ## `storm`: it lurches.
const WEIGHT_DIP := Vector2(0.18, 0.65)  ## 80 kg standing at midspan.
const RECOVERY := 0.06        ## How close to its old sag the deck must come back.
const SETTLE := 150           ## Physics ticks given to a weather change.
const WATCH := 180            ## Ticks a bow is averaged over.
const STRIKE_WINDOW := 30     ## Half a second, at sixty ticks.
const ROCK_WATCH := 180       ## Three seconds for a rock to settle on the deck.
var failures := 0
var scene: Node3D
var bridge: Node3D

func _initialize() -> void: run.call_deferred()

func check(ok: bool, message: String) -> void:
	print("PASS: " if ok else "FAIL: ", message)
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	create_timer(85).timeout.connect(func() -> void:
		print("FAIL: the study never finished forming")
		print("Failures: 1")
		quit(1))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	root.size = Vector2i(960, 600)
	scene = load("res://studies/prototype_twin_chunks.tscn").instantiate()
	root.add_child(scene)
	scene._ui.visible = false
	if "_study_ui" in scene: scene._study_ui.visible = false
	var editor: Node = scene._chunk_editor
	while editor.forming or editor.refresh_pending > 0:
		await process_frame
	bridge = scene.bridge
	check(bridge != null and bridge.has_method("apply_weather"), "The study hangs a real suspension bridge with weather inputs")
	if bridge == null or not bridge.has_method("apply_weather"):
		finish()
		return

	# ------------------------------------------------------------- the wind
	var calm := await _bow("clear", 0)
	check(calm < CALM_BOW, "Calm air barely moves the deck: %.3f m of bow, under %.2f m" % [calm, CALM_BOW])
	var windy := await _bow("rain", 1)
	check(windy > WINDY_BOW.x and windy < WINDY_BOW.y, "A windy day bows the deck %.3f m, inside %.2f to %.2f m" % [windy, WINDY_BOW.x, WINDY_BOW.y])
	var storm := await _bow("storm", 2)
	check(storm > STORM_BOW.x and storm < STORM_BOW.y, "A storm bows the deck %.3f m, inside %.2f to %.2f m" % [storm, STORM_BOW.x, STORM_BOW.y])
	check(storm > windy * 1.5 and windy > calm * 1.5, "The three readings are three different weathers: %.3f, %.3f, %.3f m" % [calm, windy, storm])

	# ------------------------------------------------------------- the rain
	await _weather(0)
	# Ground wet dries over a minute of world time, which a test does not have:
	# the dry reading has to be forced, not waited for.
	scene._precipitation.surface_weather.ground_wet = 0.0
	scene._precipitation.state.x = 0.0
	await _ticks(4)
	var dry := _plank_brightness()
	var dry_rope: Color = bridge._rope_skin.albedo_color
	scene._precipitation.surface_weather.ground_wet = 1.0
	scene._precipitation.state.x = 1.0
	await _ticks(4)
	var soaked := _plank_brightness()
	check(soaked < dry * 0.8, "Rain darkens the planks: %.3f soaked against %.3f dry" % [soaked, dry])
	check(bridge._rope_skin.albedo_color.v < dry_rope.v * 0.8, "And the rope with them: %.3f against %.3f" % [bridge._rope_skin.albedo_color.v, dry_rope.v])
	check(bridge._drips != null and bridge._drips.emitting, "The under-cables are dripping")

	# ------------------------------------------------------------- the snow
	var surface: RefCounted = scene._precipitation.surface_weather
	surface.ground_wet = 0.0
	surface.snow_cover = 0.5
	surface.cold = 1.0
	surface.target_cold = 1.0
	# `ice` creeps toward the cold over tens of seconds in the world; a test that
	# waited for it would spend its whole budget on one reading.
	surface.ice = 1.0
	await _ticks(6)
	var half := _snow_depth()
	check(half > 0.0, "Half cover lays snow on the planks: %.4f m deep" % half)
	check(bridge._caps.size() > 0 and bridge._caps[0].node.visible, "And on the anchor beams")
	surface.snow_cover = 1.0
	await _ticks(6)
	var full := _snow_depth()
	check(absf(full - half * 2.0) < 0.004, "The cap tracks the cover: %.4f m at full against %.4f m at half" % [full, half])
	check(bridge.frost > 0.0, "Deep cold puts frost in the rope: %.2f" % bridge.frost)
	surface.snow_cover = 0.0
	surface.cold = 0.0
	surface.target_cold = 0.0
	surface.ice = 0.0
	scene._precipitation.cold_override = -1.0
	await _ticks(6)
	check(_snow_depth() == 0.0 and not bridge._snow_deck.visible, "A thaw takes it back off again")

	# -------------------------------------------------------- the lightning
	await _weather(0)
	await _ticks(SETTLE)
	var quiet := 0.0
	for tick in range(STRIKE_WINDOW):
		quiet = maxf(quiet, bridge.deck_motion())
		await physics_frame
	var mid: Vector3 = bridge.deck_point(0.5)
	scene._lightning.strike(Vector2(mid.x, mid.z), scene.camera.global_position)
	var shaken := 0.0
	for tick in range(STRIKE_WINDOW):
		shaken = maxf(shaken, bridge.deck_motion())
		await physics_frame
	check(shaken > quiet + 0.5, "A strike on the deck runs down the rope: %.2f m/s against %.2f m/s of calm" % [shaken, quiet])
	var far := mid + Vector3(0.0, 0.0, 120.0)
	await _ticks(SETTLE)
	var before: float = bridge.deck_motion()
	scene._strike_near_deck(far)
	await _ticks(4)
	check(bridge.deck_motion() < before + 0.4, "A strike across the valley is not felt: %.2f m/s" % bridge.deck_motion())

	# ----------------------------------------------------------- the weight
	await _ticks(SETTLE)
	var rest: float = bridge.sag_depth()
	var weight: RigidBody3D = bridge.drop_weight(0.5, 80.0, 0.5)
	await _ticks(SETTLE)
	var loaded: float = bridge.sag_depth()
	var dip: float = loaded - rest
	check(dip > WEIGHT_DIP.x and dip < WEIGHT_DIP.y, "80 kg dips the middle %.3f m, inside %.2f to %.2f m" % [dip, WEIGHT_DIP.x, WEIGHT_DIP.y])
	weight.queue_free()
	await _ticks(SETTLE)
	check(absf(bridge.sag_depth() - rest) < RECOVERY, "And the deck comes back up: %.3f m against %.3f m" % [bridge.sag_depth(), rest])

	# ------------------------------------------------------------- the rock
	var rock: RigidBody3D = scene.throw_rock(0.5)
	await _ticks(ROCK_WATCH)
	var deck: Vector3 = bridge.deck_point(0.5)
	var standing := rock.global_position.y > deck.y - 0.5
	check(standing, "A rock thrown at the deck is resting on it, not through it: rock y %.2f against deck y %.2f" % [rock.global_position.y, deck.y])
	check(Vector2(rock.global_position.x, rock.global_position.z).distance_to(Vector2(deck.x, deck.z)) < 6.0, "And it stayed on the crossing")
	finish()

func finish() -> void:
	if scene != null:
		scene.queue_free()
		await process_frame
	print("PASS: the crossing lives in the weather" if failures == 0 else "FAIL: bridge weather")
	print("Failures: ", failures)
	quit(1 if failures else 0)

## Mean bow under one preset, after the felt wind has been put where the preset
## wants it. The study eases toward a new dial over seconds; a test has no
## seconds to spare, so it lands the ease and waits out the rope instead.
func _bow(label: String, index: int) -> float:
	await _weather(index)
	var total := 0.0
	var peak := 0.0
	for tick in range(WATCH):
		var bow: float = bridge.deck_bow()
		total += bow
		peak = maxf(peak, bow)
		await physics_frame
	var mean := total / float(WATCH)
	print("BRIDGE WEATHER %s: wind dial %.2f, bow mean %.3f m, peak %.3f m" % [label, float(scene._precipitation.wind), mean, peak])
	return mean

func _weather(index: int) -> void:
	scene._precipitation.set_weather(index, true)
	await _ticks(2)
	scene._felt_wind = float(scene._precipitation.wind)
	await _ticks(SETTLE)

func _ticks(count: int) -> void:
	for tick in range(count):
		await physics_frame

## Mean value of the plank skins, which is what "the boards got darker" means
## when six tones share the deck. Sampled off the materials, not off pixels.
func _plank_brightness() -> float:
	var total := 0.0
	for skin: StandardMaterial3D in bridge._wood_skins:
		total += skin.albedo_color.v
	return total / maxf(1.0, float(bridge._wood_skins.size()))

## How deep the snow on the boards is, in metres, read back off the cap batch.
func _snow_depth() -> float:
	if bridge._snow_deck == null or not bridge._snow_deck.visible: return 0.0
	var batch: MultiMesh = bridge._snow_deck.multimesh
	for i in range(batch.instance_count):
		var scale := batch.get_instance_transform(i).basis.get_scale()
		if scale.y > 0.0001: return scale.y
	return 0.0
