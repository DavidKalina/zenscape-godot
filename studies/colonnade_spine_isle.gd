extends "res://studies/aqueduct_isle.gd"
## The colonnade spine: a long knife-edge ridge isle in the sky, a
## processional colonnade the length of its crest climbing west in terraces
## to a temple gate on its high head, its tail curling away east in
## fragments stepping down, tied by stepping stones and live rope bridges.
## See docs/scenic/colonnade-spine.md and studies/colonnade_spine_isle_art.gd.
##
## Everything else is the aqueduct isle's (this extends studies/
## aqueduct_isle.gd, which is not changed): the pilot and his moves (the
## character study's), the game's grass and flowers (studies/
## aqueduct_isle_flora.gd), its light, sky, air, weather and the look
## presets (L / Shift+L, --look=<id>), the plane (F), the lodestone, the sky
## round it (far isles, airships, CPU planes, sky life, motes; its tokens
## here this isle's own: studies/colonnade_spine_isle_sky.gd) and the life
## on it (undergrowth, butterflies, fireflies, songbirds on the stones, the
## wind made visible, on-foot tokens: studies/colonnade_spine_isle_life.gd).
## The same opt-outs: --no-flora, --no-life (--no-undergrowth,
## --no-butterflies, --no-fireflies, --no-birds, --no-wind-life,
## --no-tokens), --no-sky (--no-far-isles, --no-airships, --no-traffic,
## --no-sky-life, --no-motes, --no-sky-tokens), --no-lode, --fly.
##   R            back to the start (the low end of the way, looking west)
##   L / Shift+L  next / previous look preset
##   B            a strong gust front
##   F (pad Y)    into the plane and back
##   ./run-colonnade-spine.command [--look=first_snow]
##   godot --path . res://studies/colonnade_spine_isle.tscn -- --no-title [--capture=out.png --at=x,y,z --look=x,y,z] [--place=x,y,z[,turn]]
const Spine = preload("res://studies/colonnade_spine_isle_art.gd")
const SpineSky = preload("res://studies/colonnade_spine_isle_sky.gd")
const SpineLife = preload("res://studies/colonnade_spine_isle_life.gd")
const RopeBridge = preload("res://scripts/rope_bridge.gd")
const Footbridge = preload("res://scripts/footbridge.gd")

const SPINE_SEED := 61
## Where he starts: on the way's low terrace, by its east end, looking west
## up the colonnade to the temple gate.
const START_AT := Vector3(130.5,Spine.TOP+Spine.L0,0.0)
## Falling past this (world y) he is set back where he last stood's nearest
## safe place: the start.
const LOST_Y := Spine.TOP-28.0

## The colonnade, the temple and what lies on the isle (metadata drives the
## tests: piers, lintels, portals, ways up).
var colonnade: Node3D
var temple: Node3D
var spine: Node3D
var bridges: Array[MeshInstance3D] = []

func _ready() -> void:
	super._ready()

## No station: the isle is its own (the greybox pack's routes are the
## aqueduct isle's). The start is on the low terrace looking west.
func _load_pack() -> void:
	stations = []
	start = Vector3(START_AT.x,START_AT.y,Spine.zc(START_AT.x))
	start_face = Vector2(-1.0,0.0)
	lost = LOST_Y
	_last_stood = start

func _pack_runs() -> PackedStringArray:
	return PackedStringArray()

func _build_room() -> void:
	_build_art()

func _build_art() -> void:
	Spine.use_paths()
	art = Node3D.new()
	art.name = "Art"
	add_child(art)
	Spine.use_platforms()
	var began := Time.get_ticks_msec()
	spine = Spine.spine_island(SPINE_SEED)
	var spine_ms := Time.get_ticks_msec()-began
	art.add_child(spine)
	colonnade = Spine.colonnade(SPINE_SEED+1)
	art.add_child(colonnade)
	art.add_child(Spine.step_walls(SPINE_SEED+2))
	for k in range(Spine.STEPS.size()):
		var s: Node3D = RuinKit.grand_stair(SPINE_SEED+3,STAIR_WEATHERED) if Spine.STEPS[k][3] == "grand" else RuinKit.stairs(SPINE_SEED+4+k,STAIR_WEATHERED)
		s.name = "Stair%d" % k
		s.transform = Spine.stair_frame(k)
		art.add_child(s)
	temple = Spine.temple(SPINE_SEED+10)
	art.add_child(temple)
	var lands: Array = [spine]
	for land: Node3D in Spine.lands(SPINE_SEED+20):
		art.add_child(land)
		lands.append(land)
	art.add_child(Art.floating_stones(SPINE_SEED+30))
	art.add_child(Spine.anchors(SPINE_SEED+40))
	var k := 0
	for ends: Array in Spine.bridge_ends():
		var a: Vector3 = ends[0]
		var b: Vector3 = ends[1]
		var bridge: MeshInstance3D = Footbridge.live(Footbridge.build_mesh(a,b,SPINE_SEED+50+k),a,b,SPINE_SEED+50+k)
		bridge.name = "RopeBridge%d" % k
		art.add_child(bridge)
		bridges.append(bridge)
		k += 1
	for land: Node3D in lands:
		var turf: StaticBody3D = land.get_node("Body")
		turf.collision_layer |= TURF_LAYER
		_turf_rids.append(turf.get_rid())
		_turf.append(turf)
		_outlines.append(land.get_meta("outline"))
	print("colonnade spine: %d triangles, %d prisms; the ridge built in %d ms, the rest in %d ms" % [triangles(art),int(spine.get_meta("prisms")),spine_ms,Time.get_ticks_msec()-began-spine_ms])

func _exit_tree() -> void:
	Spine.forget_paths()
	Spine.forget_platforms()

# --- The rope bridges underfoot -------------------------------------------------------

## The pilot's ground with the live rope bridges' decks in it (the physics
## ground's, scripts/pilot_physics_ground.gd, else): over a deck between
## its ends and within its width, the planks' top as the sim has them
## (scripts/rope_bridge.gd `_on_deck`), when it is under the ray's start;
## and his step held between its hand ropes (RopeBridge `hold`), as the
## game's walker has it.
class BridgeGround extends "res://scripts/pilot_physics_ground.gd":
	var scene: Node3D
	func height_from(p: Vector2, y: float) -> float:
		var h := super.height_from(p,y)
		var from := y+PilotMotor.STEP_UP+LOOK_OVER
		var deck := deck_at(p,from)
		return maxf(h,deck) if deck > -INF else h
	## The deck's top under `p` that is under `from`, or -INF.
	func deck_at(p: Vector2, from: float) -> float:
		var best := -INF
		for bridge: MeshInstance3D in RopeBridge._live:
			var local: Vector3 = bridge.global_transform.affine_inverse()*Vector3(p.x,from,p.y)
			var on: Vector3 = bridge._on_deck(local)
			if on.x <= 0.0 or on.x >= 1.0: continue
			if absf(on.y-float(bridge.sim.sway(on.x))) > float(bridge.sim.width)*0.5+RopeBridge.STAND_SLACK: continue
			var top := from-on.z
			if top <= from+0.001: best = maxf(best,top)
		return best
	func slide(feet: Vector3, step: Vector2) -> Vector3:
		var to := super.slide(feet,step)
		if scene == null: return to
		var held: Vector2 = RopeBridge.hold(scene,feet,Vector2(to.x,to.z))
		return Vector3(held.x,to.y,held.y)

func _build_pilot() -> void:
	super._build_pilot()
	var bridged := BridgeGround.new(get_world_3d().direct_space_state,motor)
	bridged.scene = self
	bridged.pools = ground.pools
	ground = bridged
	motor.water = ground.water_callable()
	motor.wall = ground.wall_callable()

var _was_grounded := true
var _fall_speed := 0.0

## On foot: the step, then the deck under him takes his weight, a landing
## its bounce, and carries him with its sway.
func tick(delta: float) -> void:
	super.tick(delta)
	if flying or not walk_ready or lode_state == "inspecting": return
	var events := {}
	if motor.grounded and not _was_grounded: events["landed"] = _fall_speed
	_was_grounded = motor.grounded
	_fall_speed = maxf(-motor.velocity.y,0.0)
	var carry: Vector3 = RopeBridge.tread(self,motor.feet,motor.grounded,events,{},clampf(motor.speed()/PilotMotor.RUN,0.0,1.0))
	if carry != Vector3.ZERO: motor.feet += carry

# --- The lodestone ------------------------------------------------------------------

## The lodestone rests on the last fragment of the tail, at the end of the
## curl (the aqueduct isle's lodestone, here).
const LODE_ON := "frag_5"

func _build_lode() -> void:
	var s := Spine.slab(LODE_ON)
	var c := Spine.slab_at(s)
	lode_rest = Vector3(c.x-0.6,Spine.TOP+float(s[4])+LODE_HOVER+0.25,c.y+0.4)
	lodestone = Lodestone.new()
	lodestone.set_miniature(LODE_MINI)
	lodestone.position = lode_rest
	lodestone.scale = Vector3.ONE*LODE_SCALE
	add_child(lodestone)
	_moments = MomentsHud.new()
	add_child(_moments)
	_build_target()
	if _carry:
		lode_state = "carried"
		lodestone.scale = Vector3.ONE*CARRY_SCALE
		lodestone.show_light(false)
		_carry_step(0.0)
	if _switch_hint != null: _switch_hint.text = _foot_text()

## On the fragment, beside the stone, he can pick it up.
func can_pick() -> bool:
	if lodestone == null or lode_state != "resting" or flying or not walk_ready: return false
	var feet := motor.feet
	return Vector2(feet.x-lode_rest.x,feet.z-lode_rest.z).length() < PICK_REACH+0.4 and absf(feet.y+LODE_HOVER+0.25-lode_rest.y) < 0.6

func _foot_text() -> String:
	var text := super._foot_text()
	return text.replace("A lodestone hums on a floating stone east, past the heel stone: climb up to it","A lodestone hums at the end of the tail's curl: follow the fragments round")

func _add_sky() -> void:
	sky = SpineSky.new()
	add_child(sky)
	sky.setup(self)
	if _capture != "": sky.flush()

## The isle's life (studies/colonnade_spine_isle_life.gd); its foot tokens
## show on the sky collectibles' readout, as the aqueduct isle's do.
func _add_life() -> void:
	var args: PackedStringArray = preload("res://scripts/launch_args.gd").user_args()
	if args.has("--no-life"): return
	var began := Time.get_ticks_msec()
	life = SpineLife.new()
	add_child(life)
	life.setup(self,args)
	var sky_tokens = sky.get("collectibles") if sky != null else null
	if life.tokens != null and sky_tokens != null and sky_tokens.get("hud") != null:
		life.tokens.hud.queue_free()
		life.tokens.hud = sky_tokens.get("hud")
	print("colonnade spine: life %s in %d ms %s" % [life.flags,Time.get_ticks_msec()-began,life.timings])
