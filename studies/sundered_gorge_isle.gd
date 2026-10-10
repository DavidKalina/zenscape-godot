extends "res://studies/aqueduct_isle.gd"
## The Sundered gorge isle (docs/scenic/sundered-gorge.md): a hand-built sky
## island motif in the aqueduct isle's universe. One big isle torn in two by
## a gorge, the halves drifted apart: the west lower and tilted toward the
## gap, the east level and higher; sheer, warm-lit walls with ledges cut
## along them; the hanging rock of both keels under the split. A great stone
## bridge that spanned it on one arch has snapped at its crown: each half
## keeps its half-arch, and a live rope bridge (scripts/rope_bridge.gd) is
## slung across the break between stone anchors; the crown's stones hang in
## the gap beside it, the rest of it lies on a fragment caught deep below.
## The west has the gatehouse (the kit's gate arch and a leaning tower over
## the lip), a tor and a spring pool spilling into the gorge as a wide
## curtain; the east a roofless chapel facing the bridge, and a crag. A
## lower crossing (the kit's stairs down the west wall, two fragments caught
## in the gap, a ramp up the east wall) makes a loop; a split pillar by it is
## a wall-kick chimney. The plane's line: into the gorge from the north, past
## the curtain, under the lower crossing and the broken bridge, out south.
## Art: studies/sundered_gorge_isle_art.gd.
##
## Everything else is the aqueduct isle's (this extends studies/
## aqueduct_isle.gd and overrides only what is that isle's own): the
## character study's pilot and moves, the game's look rig and presets (L /
## Shift+L, --look=<id>), the plane (F), the lodestone (here on the fallen
## crown deep in the gorge: drop to it from the break, pick it up, board the
## plane to fly out), the grass and flowers (studies/
## sundered_gorge_isle_flora.gd), the life (studies/
## sundered_gorge_isle_life.gd) and the sky round it (studies/
## sundered_gorge_isle_sky.gd), with the same opt-out flags (--no-flora,
## --no-life, --no-undergrowth, --no-butterflies, --no-fireflies, --no-birds,
## --no-wind-life, --no-tokens, --no-sky, --no-far-isles, --no-airships,
## --no-traffic, --no-sky-life, --no-motes, --no-sky-tokens, --no-lode).
##   ./run-sundered-gorge.command [--look=rosewater_dusk] [--fly]
##   godot --path . res://studies/sundered_gorge_isle.tscn -- --no-title [--capture=out.png --at=x,y,z --look=x,y,z] [--place=x,y,z[,turn]]
const Gorge = preload("res://studies/sundered_gorge_isle_art.gd")
const GorgeFlora = preload("res://studies/sundered_gorge_isle_flora.gd")
const GorgeLife = preload("res://studies/sundered_gorge_isle_life.gd")
const GorgeSky = preload("res://studies/sundered_gorge_isle_sky.gd")
const RopeBridge = preload("res://scripts/rope_bridge.gd")
const Footbridge = preload("res://scripts/footbridge.gd")

const GORGE_SEED := 23
## Fallen under this (world y) he is set back at the start: nothing stands
## under it but the keels' points.
const GORGE_LOST := 9.0

## The pieces built (their metadata drives the tests).
var west_half: Node3D
var east_half: Node3D
var west_bridge: Node3D
var east_bridge: Node3D
var gate: Node3D
var gate_tower: Node3D
var chapel: Array[Node3D] = []
var flights: Array[Node3D] = []
var fragments: Array = []
var water: Node3D
## The rope bridge and the deck the walker reads ({a, b, span, sim}).
var rope: MeshInstance3D
var rope_deck := {}
var _was_grounded := true
var _fall_speed := 0.0
var _stride := 0.0
var _foot := 0

# --- Set up ----------------------------------------------------------------------

## No pack station: the isle's own start, one station there (the fall's
## respawn).
func _load_pack() -> void:
	start = Gorge.start()
	start_face = Vector2(1.0,0.0)
	stations = [{"key":1,"name":"Sundered gorge","spawn":start,"face":start_face,"parts":[]}]
	lost = GORGE_LOST
	_last_stood = start

## The game's look rig as the aqueduct isle builds it, its summit ours.
func _build_light() -> void:
	super._build_light()
	_atmosphere._summit = Vector3(Gorge.WEST_TOR[0].x,Gorge.plane_w(Gorge.WEST_TOR[0].x)+float(Gorge.WEST_TOR[1]),Gorge.WEST_TOR[0].y)

## The pilot (the aqueduct isle's, with his wake), his ground also reading
## the rope bridge's live deck and keeping him between its hand ropes.
func _build_pilot() -> void:
	super._build_pilot()
	var deck_ground := DeckGround.new(get_world_3d().direct_space_state,motor)
	deck_ground.frame = self
	ground = deck_ground
	motor.water = ground.water_callable()
	motor.wall = ground.wall_callable()

func _build_room() -> void:
	ground.pools.append_array(Gorge.pools())
	_build_art()

func _build_art() -> void:
	art = Node3D.new()
	art.name = "Art"
	add_child(art)
	west_half = Gorge.west_half(GORGE_SEED)
	art.add_child(west_half)
	east_half = Gorge.east_half(GORGE_SEED+1)
	art.add_child(east_half)
	# The bridge: its two halves, the rope bridge between their anchors.
	west_bridge = Gorge.half_bridge(GORGE_SEED+20,Gorge.WEST_BREAK,0.55)
	west_bridge.name = "WestBridge"
	west_bridge.transform = Gorge.west_bridge_frame()
	art.add_child(west_bridge)
	east_bridge = Gorge.half_bridge(GORGE_SEED+24,Gorge.EAST_BREAK,0.6)
	east_bridge.name = "EastBridge"
	east_bridge.transform = Gorge.east_bridge_frame()
	art.add_child(east_bridge)
	rope = Gorge.rope_bridge(GORGE_SEED+22,rope_deck)
	art.add_child(rope)
	var decks: Array[Dictionary] = [rope_deck]
	(ground as DeckGround).decks = decks
	# The gatehouse: the gate arch over the road, the tower by the lip.
	gate = RuinKit.piece("arch",Gorge.GATE_SEED,0.5)
	gate.name = "Gate"
	gate.transform = Gorge.gate_frame()
	art.add_child(gate)
	var tower: Dictionary = Gorge.tower(GORGE_SEED+30)
	gate_tower = tower.node
	gate_tower.transform = Gorge.tower_frame()
	art.add_child(gate_tower)
	for part: Array in tower.parts: _frame_box(Gorge.tower_frame(),part[0],part[1],part[2])
	# The chapel on the east.
	for spec: Array in Gorge.CHAPEL:
		var piece: Node3D = RuinKit.piece(spec[0],spec[1],spec[2])
		var x: float = spec[3]
		var z: float = spec[4]
		piece.transform = Transform3D(Basis(Vector3.UP,deg_to_rad(float(spec[5]))),Vector3(x,Gorge.ground_e(x,z),z))
		art.add_child(piece)
		chapel.append(piece)
	# The broken pier on the west tor.
	var pier: Node3D = RuinKit.piece("pier",61,0.7)
	pier.transform = Gorge.frame_w(Gorge.TOR_PIER.x,Gorge.TOR_PIER.y,float(Gorge.WEST_TOR[1]))
	art.add_child(pier)
	# The kit's flights down the west wall.
	for spec: Array in Gorge.FLIGHTS:
		var flight: Node3D = RuinKit.stairs(GORGE_SEED+35+flights.size(),0.35)
		flight.name = str(spec[0])
		flight.transform = Gorge.flight_frame(spec)
		art.add_child(flight)
		flights.append(flight)
	# The fragments in the gap, the fallen crown, the floating stones, the
	# chimney, boulders, the pool and its fall.
	fragments = Gorge.fragment_islets(GORGE_SEED+40)
	for f: Node3D in fragments: art.add_child(f)
	art.add_child(Gorge.fallen_crown(GORGE_SEED+50))
	art.add_child(Gorge.floating_stones(GORGE_SEED+51))
	var slabs: Dictionary = Gorge.chimney_slabs(GORGE_SEED+52)
	art.add_child(slabs.node)
	for part: Array in slabs.parts: _part(["box",part[0],part[1],part[2],"lip"])
	art.add_child(Gorge.boulders(GORGE_SEED+53))
	water = Gorge.water(GORGE_SEED+54)
	art.add_child(water)
	# The turf the grass grows on and the plane skims.
	for land: Node3D in [west_half,east_half]+fragments:
		var turf: StaticBody3D = land.get_node("Body")
		turf.collision_layer |= TURF_LAYER
		_turf_rids.append(turf.get_rid())
		_turf.append(turf)
		_outlines.append(land.get_meta("outline"))
	print("sundered gorge: %d triangles" % triangles(art))

## A clean, invisible box in `frame` over `rect` (x, z) from `bottom` to
## `top` (as the station's boxes are: the stone over it drawn only).
func _frame_box(frame: Transform3D, rect: Rect2, bottom: float, top: float) -> void:
	var solid := StaticBody3D.new()
	solid.transform = frame*Transform3D(Basis.IDENTITY,Vector3(rect.get_center().x,(top+bottom)*0.5,rect.get_center().y))
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(rect.size.x,top-bottom,rect.size.y)
	collider.shape = box
	solid.add_child(collider)
	add_child(solid)

## The isle's grass and flowers (studies/sundered_gorge_isle_flora.gd).
func _grow() -> void:
	var began := Time.get_ticks_msec()
	flora = GorgeFlora.grow(GORGE_SEED+4,get_world_3d().direct_space_state,_turf,_outlines)
	art.add_child(flora)
	flora_ready = true
	print("sundered gorge: flora %s, %d instanced triangles, %d multimeshes, grown in %d ms" % [flora.get_meta("counts"),int(flora.get_meta("triangles")),flora.get_child_count(),Time.get_ticks_msec()-began])

## No pack recordings here.
func _pack_runs() -> PackedStringArray:
	return PackedStringArray()

# --- Each frame: the rope bridge -----------------------------------------------------

## On foot: the deck under him takes his weight, his footfalls and landings
## (as the game's walker tells it, scripts/wanderer_eye.gd), and its sway
## carries him.
func tick(delta: float) -> void:
	var was := motor.grounded
	var vy := motor.velocity.y
	super.tick(delta)
	if rope == null or lode_state == "inspecting" or flying: return
	var events := {}
	if motor.grounded and not was: events["landed"] = maxf(-minf(vy,_fall_speed),0.0)
	_fall_speed = 0.0 if motor.grounded else minf(_fall_speed,motor.velocity.y)
	var pace := Vector2(motor.velocity.x,motor.velocity.z).length()
	var drawn := {}
	if motor.grounded and pace > 0.6:
		_stride += delta*pace/0.75
		if _stride >= 1.0:
			_stride -= 1.0
			_foot = 1-_foot
			drawn["footfall"] = _foot
	var carry := RopeBridge.tread(self,motor.feet,motor.grounded,events,drawn,clampf(pace/PilotMotor.RUN,0.0,1.0))
	if carry != Vector3.ZERO: motor.feet += carry

## In the plane: the rope bridge shudders as it passes.
func fly_step(delta: float, input: Dictionary) -> void:
	super.fly_step(delta,input)
	if flying and plane != null: RopeBridge.flown_by(plane.position,plane.velocity)

# --- The sky, the life -------------------------------------------------------------

func _add_sky() -> void:
	sky = GorgeSky.new()
	add_child(sky)
	sky.setup(self)
	if _capture != "": sky.flush()

func _add_life() -> void:
	var args: PackedStringArray = preload("res://scripts/launch_args.gd").user_args()
	if args.has("--no-life"): return
	var began := Time.get_ticks_msec()
	life = GorgeLife.new()
	add_child(life)
	life.setup(self,args)
	var sky_tokens = sky.get("collectibles") if sky != null else null
	if life.tokens != null and sky_tokens != null and sky_tokens.get("hud") != null:
		life.tokens.hud.queue_free()
		life.tokens.hud = sky_tokens.get("hud")
	print("sundered gorge: life %s in %d ms %s" % [life.flags,Time.get_ticks_msec()-began,life.timings])

# --- The lodestone ----------------------------------------------------------------

## The lodestone on the fallen crown (or on a floating stone named by
## --lode-at=), the shard it points to.
func _build_lode() -> void:
	var p: Dictionary = Gorge.platform(_lode_at)
	if p.is_empty():
		var f: Array = Gorge.fragment("crown")
		lode_rest = Vector3((f[1] as Vector2).x,float(f[3]),(f[1] as Vector2).y)+Gorge.CROWN_LODE+Vector3.UP*LODE_HOVER
	else:
		lode_rest = (p.at as Vector3)+Vector3.UP*LODE_HOVER
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

func _foot_text() -> String:
	var text := super._foot_text()
	return text.replace("A lodestone hums on a floating stone east, past the heel stone: climb up to it","A lodestone hums deep in the gorge, on the bridge's fallen crown: drop to it from the break")

# --- The deck underfoot -------------------------------------------------------------

## The pilot's ground over the physics space (scripts/pilot_physics_ground.gd)
## and the rope bridge's live deck (Footbridge `deck_at`, moving with its
## sim), the higher where both are under him; on the deck, kept between its
## hand ropes (RopeBridge `hold`).
class DeckGround extends "res://scripts/pilot_physics_ground.gd":
	const Footbridge = preload("res://scripts/footbridge.gd")
	const RopeBridge = preload("res://scripts/rope_bridge.gd")
	var decks: Array[Dictionary] = []
	var frame: Node3D

	func height_from(p: Vector2, y: float) -> float:
		var h := super.height_from(p,y)
		if decks.is_empty(): return h
		var on := Footbridge.deck_at(decks,p)
		if on.is_empty(): return h
		var deck_y := float(on.y)
		if deck_y > y+PilotMotor.STEP_UP+LOOK_OVER: return h
		return maxf(h,deck_y)

	func slide(feet: Vector3, step: Vector2) -> Vector3:
		var to := super.slide(feet,step)
		if frame == null or decks.is_empty(): return to
		var held := RopeBridge.hold(frame,feet,Vector2(to.x,to.z))
		return Vector3(held.x,to.y,held.y)
