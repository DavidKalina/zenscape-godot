extends "res://studies/bag_study.gd"
## The bridge study (docs/design/bridge-snap/spec-bridge-snap.md): two grey
## cliffs over a void, a long rope bridge between them and a short one
## beside it, built on the bag study (studies/bag_study.gd: the wanderer,
## the loot bag, the stone brood, the spade). Plain grey, the bridges as
## the game draws them (scripts/footbridge.gd `live`, scripts/rope_bridge.gd).
##
## - the near cliff (west, top y 0): the start, loot to fill the bag, two
##   burrows the brood wake out of;
## - the long bridge (LONG_SPAN m) from the near cliff's lip to the far one's;
## - the short bridge (SHORT_SPAN m) beside it, between two spurs;
## - the far cliff (east), with the drop pad: somewhere to throw the bag to;
## - the void under it all; a fall past `lost` puts him back at the near end
##   (at the far end if he last stood on the far cliff).
##
## Each bridge's deck is walk boxes laid each frame along its middle line
## where it hangs (the resting curve, dropped and swayed by the sim), so the
## brood, the bag and loot (physics rays and bodies) ride it as it sags; the
## walker reads the live deck itself (scripts/kit_isle/deck_ground.gd).
## Every cliff, spur, bridge, loot piece and burrow is named
## `bridge_study/<piece>` (scripts/layout_overrides.gd; F4 world view).
##   ./run-bridge-study.command
##   godot --path . res://studies/bridge_study.tscn -- --no-title
const Footbridge = preload("res://scripts/footbridge.gd")
const RopeBridge = preload("res://scripts/rope_bridge.gd")
const DeckGround = preload("res://scripts/kit_isle/deck_ground.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const BridgeLoad = preload("res://scripts/bridge_load.gd")
const BroodKnobs = preload("res://scripts/brood/brood_knobs.gd")
const BridgeClimb = preload("res://scripts/bridge_climb.gd")
const BridgeRoutes = preload("res://scripts/brood/bridge_routes.gd")
const StoneGuy = preload("res://scripts/brood/stone_guy.gd")

const BRIDGE_SCENE := "bridge_study"
## The cliffs: tops at y 0, faces down CLIFF_DEEP m. The near cliff's lip is
## at x NEAR_LIP, the far one's at x FAR_LIP.
const CLIFF_DEEP := 40.0
const NEAR_LIP := 0.0
const FAR_LIP := 28.0
## The long bridge's line (z) and its ends a little back from each lip.
const LONG_Z := -4.0
const SET_BACK := 0.4
const LONG_SPAN := FAR_LIP-NEAR_LIP+SET_BACK*2.0
## The short bridge, between the two spurs (their lips at x SPUR_NEAR and
## SPUR_FAR), along z SHORT_Z.
const SHORT_Z := 9.0
const SPUR_NEAR := 9.0
const SPUR_FAR := 19.0
const SHORT_SPAN := SPUR_FAR-SPUR_NEAR+SET_BACK*2.0
## The kill plane: a fall past here (m) is lost to the void.
const VOID_Y := -30.0
## The bridges that bear a load and strain (scripts/bridge_load.gd); the
## rest hold anything.
const LOADED := ["long_bridge"]
## A brood guy's weight on a bridge (kg). On the bag they add RIDER_KG
## (2.5, scripts/brood/brood_knobs.gd); on a deck they're heavy: with the
## 96 kg limit, him with a full bag (84) holds alone, plus 2 brood snaps it,
## an empty bag plus 6 does.
const BROOD_BRIDGE_KG := 6.0
## The rip's pace while he's on a loaded deck (bag_brood `rip_pace`): half,
## so the clingers don't empty the bag before the rest come on.
const RIP_ON_DECK := 0.5
## The drop pad on the far cliff: its middle and radius (m).
const PAD_AT := Vector3(34.0,0.0,-4.0)
const PAD_R := 1.6

## The structures ([name, part] as the bag study's PIECES).
const CLIFFS := [
	["near_cliff",["box",Rect2(-22.0,-14.0,22.0,28.0),-CLIFF_DEEP,0.0,"floor"]],
	["near_spur",["box",Rect2(NEAR_LIP,6.0,SPUR_NEAR-NEAR_LIP,6.0),-CLIFF_DEEP,0.0,"wall"]],
	["far_cliff",["box",Rect2(FAR_LIP,-14.0,14.0,28.0),-CLIFF_DEEP,0.0,"floor"]],
	["far_spur",["box",Rect2(SPUR_FAR,6.0,FAR_LIP-SPUR_FAR,6.0),-CLIFF_DEEP,0.0,"wall"]],
	# Low walls round the cliffs' back edges, so only the void side is open.
	["near_back",["box",Rect2(-23.0,-15.0,1.0,30.0),0.0,1.4,"wall"]],
	["far_back",["box",Rect2(42.0,-15.0,1.0,30.0),0.0,1.4,"wall"]],
]

## The loot on the near cliff ([id, kind, kg, foot, yaw]): 41 kg, enough to
## fill the bag (24) with some over.
const BRIDGE_LOOT := [
	["loot_01","chalice",1.5,Vector3(-14.0,0.0,6.0),20.0],
	["loot_02","idol",3.0,Vector3(-10.0,0.0,2.0),160.0],
	["loot_03","bar",4.0,Vector3(-7.0,0.0,-8.0),35.0],
	["loot_04","coins",2.0,Vector3(-16.0,0.0,-6.0),0.0],
	["loot_05","urn",6.0,Vector3(-12.0,0.0,-2.0),200.0],
	["loot_06","egg",12.0,Vector3(-18.0,0.0,1.0),90.0],
	["loot_07","bar",4.0,Vector3(-5.0,0.0,4.0),70.0],
	["loot_08","idol",3.0,Vector3(-8.0,0.0,10.0),220.0],
	["loot_09","urn",6.0,Vector3(-15.0,0.0,-10.0),130.0],
]

## Two burrows on the near cliff, behind the loot, so the brood wake behind
## him and follow him out onto the bridge.
const BRIDGE_BURROWS := [
	["burrow_1",Vector3(-19.0,0.0,-5.0)],
	["burrow_2",Vector3(-19.0,0.0,7.0)],
]

## The bridges: name -> {live (the rope bridge), deck (its walk boxes),
## holder (the named node), a, b (its ends in the holder's frame), span}.
var bridges := {}
## His hold on a snapped bridge's hanging halves (scripts/bridge_climb.gd),
## one per loaded bridge.
var climbs: Array = []

## The brood's routes over the cliffs and both bridges
## (scripts/brood/bridge_routes.gd; StoneGuy.route while this room is up).
var routes: RefCounted = null
## The brood's floors as built ([id, coded rect, coded top, offset seen]),
## so a cliff moved in the world view (F4, or a saved layout) moves its floor.
var _floor_of: Array = []
## The test aid (B, or --brood-now at the start): the bag filled to what he
## can wear and the brood woken, coming for him at once.
var _brood_now_due := false

func _init() -> void:
	scene_id = BRIDGE_SCENE

func _load_pack() -> void:
	start = Vector3(-10.0,0.0,LONG_Z+2.0)
	start_face = Vector2(1.0,0.0)
	lost = VOID_Y
	_last_stood = start
	stations = [
		{"key":1,"name":"Start","spawn":start,"face":start_face,"sign":Vector3(-12.0,2.8,LONG_Z-2.0),"parts":[]},
		{"key":2,"name":"Near end","spawn":Vector3(NEAR_LIP-2.0,0.0,LONG_Z),"face":Vector2(1.0,0.0),"sign":Vector3(NEAR_LIP-2.5,2.8,LONG_Z-2.4),"parts":[]},
		{"key":3,"name":"Short bridge","spawn":Vector3(SPUR_NEAR-2.0,0.0,SHORT_Z),"face":Vector2(1.0,0.0),"sign":Vector3(SPUR_NEAR-2.5,2.8,SHORT_Z+2.4),"parts":[]},
		{"key":4,"name":"Far end","spawn":Vector3(FAR_LIP+2.0,0.0,LONG_Z),"face":Vector2(-1.0,0.0),"sign":Vector3(FAR_LIP+2.5,2.8,LONG_Z-2.4),"parts":[]},
		{"key":5,"name":"Drop pad","spawn":PAD_AT+Vector3(3.0,0.0,0.0),"face":Vector2(-1.0,0.0),"sign":PAD_AT+Vector3(0.0,2.6,-2.4),"parts":[]},
	]

func _build_floors() -> void:
	for p: Array in CLIFFS: _named_part(str(p[0]),p[1])
	_build_bridge("long_bridge",Vector3(NEAR_LIP-SET_BACK,0.0,LONG_Z),Vector3(FAR_LIP+SET_BACK,0.0,LONG_Z),71)
	_build_bridge("short_bridge",Vector3(SPUR_NEAR-SET_BACK,0.0,SHORT_Z),Vector3(SPUR_FAR+SET_BACK,0.0,SHORT_Z),72)
	_build_pad()

func _build_room() -> void:
	super._build_room()
	_brood_now_due = LaunchArgs.user_args().has("--brood-now")
	if brood == null: return
	routes = BridgeRoutes.new()
	routes.frame = brood
	# The floors the brood walk: each cliff's top and its spur (the low
	# back walls aren't floors).
	for p: Array in CLIFFS:
		var part: Array = p[1]
		if str(part[4]) == "wall" and not str(p[0]).ends_with("_spur"): continue
		routes.add_floor(str(p[0]),part[1],float(part[3]))
		_floor_of.append([str(p[0]),part[1],float(part[3]),Vector3.INF])
	_follow_floors()
	for id: String in bridges:
		var br: Dictionary = bridges[id]
		routes.add_deck(id,br.holder,br.live,br.a,br.b,float(br.span),br.get("load"))
	StoneGuy.route = routes

func _exit_tree() -> void:
	if StoneGuy.route == routes: StoneGuy.route = null

func _loot_rows() -> Array:
	return BRIDGE_LOOT

func _burrow_rows() -> Array:
	return BRIDGE_BURROWS

# --- The bridges -----------------------------------------------------------------------

## A live rope bridge from `a` to `b` (world, at rest), as the game draws it
## (Footbridge `build_mesh`, `live`), with the kit's stone anchor at each end
## and its deck as walk boxes laid where it hangs (`_lay_deck`); the long
## one bears a load and strains (LOADED, scripts/bridge_load.gd). All under one named
## node (`bridge_study/<id>`), its frame at `a`, so the world view moves the
## whole bridge.
func _build_bridge(id: String, a_world: Vector3, b_world: Vector3, seed_value: int) -> void:
	var called := "%s/%s" % [scene_id,id]
	if LayoutOverrides.deleted(called): return
	var coded := Transform3D(Basis.IDENTITY,a_world)
	var holder := Node3D.new()
	holder.name = id
	holder.transform = LayoutOverrides.xform(called,coded)
	add_child(holder)
	LayoutOverrides.track(called,holder,"piece",coded)
	var a := Vector3.ZERO
	var b := b_world-a_world
	var mesh := Footbridge.build_mesh(a,b,seed_value)
	var live: MeshInstance3D = Footbridge.live(mesh,a,b,seed_value)
	live.name = "Bridge"
	holder.add_child(live)
	var span := Vector2(b.x-a.x,b.z-a.z).length()
	var deck := StaticBody3D.new()
	deck.name = "Deck"
	var pieces := maxi(8,int(ceil(span/0.5)))
	var shapes: Array = []
	for i in range(pieces):
		var shape := CollisionShape3D.new()
		shape.shape = BoxShape3D.new()
		deck.add_child(shape)
		shapes.append(shape)
	holder.add_child(deck)
	for end: Array in [[a,b],[b,a]]:
		var anchor := RuinKit.bridge_anchor(seed_value*3+int(end[0] == b),0.45,Footbridge.WIDTH,
			{"post_x":Footbridge.WIDTH*0.5+0.33,"post_z":0.0,"sill":Vector3(0.75,0.11,0.55),"sill_at":Vector3(0.0,-0.11,0.15)})
		var way: Vector3 = (end[1] as Vector3)-(end[0] as Vector3)
		way.y = 0.0
		anchor.transform = Transform3D(Basis.looking_at(way.normalized(),Vector3.UP),end[0])
		holder.add_child(anchor)
	bridges[id] = {"live":live,"deck":deck,"holder":holder,"a":a,"b":b,"span":span,"shapes":shapes}
	_lay_deck(bridges[id])
	if id in LOADED:
		var held: Node = BridgeLoad.on(live,id.replace("_"," "),seed_value)
		held.lip = SET_BACK
		held.snapped.connect(_on_snap.bind(id))
		held.mended.connect(_on_mend.bind(id))
		bridges[id]["load"] = held
		climbs.append(BridgeClimb.new(held,BridgeLoad.WANDERER_KG))

## Snapped: its walk boxes go, so all on the deck falls (the brood into the
## void, gone; the bag and loose loot after them).
func _on_snap(_t: float, id: String) -> void:
	for shape: CollisionShape3D in bridges[id].shapes: shape.disabled = true
	# The brood standing on it drop (they'd stand on air till they next
	# stepped); those clinging to him on it are flung off by the jolt.
	if brood == null: return
	var held: Node = bridges[id].load
	var feet := global_transform*motor.feet
	var his: bool = held.deck_spot(feet) != Vector3.INF
	for g: RefCounted in brood.guys:
		if g.state == "cling" and his:
			var out: Vector3 = (brood.global_transform*g.mid)-feet
			out.y = 0.0
			out = out.normalized() if out.length() > 0.01 else Vector3.RIGHT
			g.shake(out*1.8+Vector3.DOWN*0.5,randf_range(4.0,9.0))
			continue
		if not g.state in ["walk","climb","mantle","haul","fall"]: continue
		if held.deck_spot(brood.global_transform*g.feet) == Vector3.INF: continue
		# `shake` falls from his middle, which a walking guy doesn't keep
		# (it was where he rose): from his feet.
		g.mid = g.feet+Vector3.UP*float(g.tall)*0.5
		g.shake(Vector3.DOWN+held.global_basis*held.bridge.across*randf_range(-1.0,1.0),randf_range(4.0,9.0))

func _on_mend(id: String) -> void:
	for shape: CollisionShape3D in bridges[id].shapes: shape.disabled = false
	bridges[id]["laid_still"] = false

## Placed anywhere (a respawn after a fall, R, a station key), a snapped
## bridge is whole again.
func place(at: Vector3, face: Vector2) -> void:
	# Off any half he hangs on (else the hold outlives the mend and he
	# never catches again).
	for c: RefCounted in climbs:
		if not c.holding(): continue
		if motor.rider == c: motor.release(c)
		c._free(motor)
	super.place(at,face)
	for id: String in bridges:
		if bridges[id].has("load"): bridges[id]["load"].mend()

## The deck's resting top at `t` along the bridge from `a` to `b`.
static func _deck_point(a: Vector3, b: Vector3, span: float, t: float) -> Vector3:
	return a.lerp(b,t)+Vector3.UP*Footbridge.lift(span,t)

## Lays the deck's walk boxes along its middle line where it hangs now (the
## resting curve, dropped and swayed by the sim), so the brood, the bag and
## loot ride it down as it sags. Each frame (`tick`); the walker reads the
## live deck itself (DeckGround `deck_at`).
func _lay_deck(br: Dictionary) -> void:
	var live: MeshInstance3D = br.live
	var shapes: Array = br.shapes
	var a: Vector3 = br.a
	var b: Vector3 = br.b
	var span: float = br.span
	var sim: RefCounted = live.sim
	if not sim.awake and br.get("laid_still",false): return
	var n := shapes.size()
	var prev := Vector3.ZERO
	for i in range(n+1):
		var t := float(i)/n
		var off: Vector2 = sim.offset(t,0.0)
		var p: Vector3 = _deck_point(a,b,span,t)+Vector3.UP*off.x+live.across*off.y
		if i > 0:
			var along: Vector3 = p-prev
			var shape: CollisionShape3D = shapes[i-1]
			(shape.shape as BoxShape3D).size = Vector3(Footbridge.WIDTH+0.06,0.16,along.length()+0.04)
			var basis := Basis.looking_at(along.normalized(),Vector3.UP)
			shape.transform = Transform3D(basis,(prev+p)*0.5-basis.y*0.08)
		prev = p
	br["laid_still"] = not sim.awake

## The drop pad on the far cliff (`bridge_study/drop_pad`): a flat ring to
## throw the bag to, no collider.
func _build_pad() -> void:
	var called := "%s/drop_pad" % scene_id
	if LayoutOverrides.deleted(called): return
	var coded := Transform3D(Basis.IDENTITY,PAD_AT)
	var pad := Node3D.new()
	pad.name = "drop_pad"
	pad.transform = LayoutOverrides.xform(called,coded)
	add_child(pad)
	LayoutOverrides.track(called,pad,"token",coded)
	var disc := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = PAD_R
	c.bottom_radius = PAD_R
	c.height = 0.03
	c.radial_segments = 32
	disc.mesh = c
	disc.position.y = 0.015
	disc.material_override = _material("pad")
	pad.add_child(disc)
	var tag := Label3D.new()
	tag.text = "drop the bag here"
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 32
	tag.pixel_size = 0.006
	tag.outline_size = 6
	tag.position = Vector3(0.0,1.2,0.0)
	pad.add_child(tag)

# --- The walker on the decks -------------------------------------------------------

## His ground reads the physics space and the live rope bridges' decks
## (scripts/kit_isle/deck_ground.gd), his steps kept between their hand
## ropes (as the kit isle's walker's).
func _build_pilot() -> void:
	super._build_pilot()
	var decks := DeckGround.new(get_world_3d().direct_space_state,motor)
	decks.see(decks.mask|WalkerOnly.LAYER)
	decks.frame = self
	decks.pools = ground.pools
	decks.scale_body(wanderer_scale)
	ground = decks
	motor.water = ground.water_callable()
	motor.wall = ground.wall_callable()
	motor.mover = ground.mover_callable()
	motor.soft = ground.soft_callable()

## Each frame the deck under him takes his weight, footfalls and landings
## and carries him with its sway (RopeBridge `tread`, the kit isle's way).
const STRIDE := 0.75
var _stride := 0.0
var _foot := 0
var _fall_speed := 0.0

func tick(delta: float) -> void:
	var was_grounded := motor.grounded
	var falling := motor.velocity.y
	super.tick(delta)
	_tread(delta,was_grounded,falling)
	for id: String in bridges: _lay_deck(bridges[id])
	for c: RefCounted in climbs:
		if motor.rider == null: c.catch(motor,delta)
	_bear()
	_bag_in_void()
	_rip_pace()
	_follow_floors()
	if _brood_now_due and walk_ready:
		_brood_now_due = false
		brood_now()

## The test aid (B; --brood-now): fills the bag to what he can wear from the
## loot not in it (heaviest that fits first, put in at once) and wakes the
## brood (all of them, or as many as went home), so they come for him
## straight away from the burrows, over the bridges, wherever he is.
func brood_now() -> void:
	if brood == null:
		_say("No brood in this run (--no-brood)")
		return
	if bag != null and not bool(bag.buried) and bag.state == "worn":
		var pieces: Array = []
		for p: Dictionary in loot:
			if bag.items.has(p) or p == bag.stowing or bool(p.get("buried",false)): continue
			if not (p.node as Node3D).visible: continue
			pieces.append(p)
		pieces.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x.kg) > float(y.kg))
		var kg := float(bag.kg)
		for p: Dictionary in pieces:
			if kg+float(p.kg) > float(bag.limit())+0.001: continue
			(p.node as Node3D).visible = false
			bag.items.append(p)
			kg += float(p.kg)
		bag._set_kg(kg)
	if not brood.woken: brood.wake_burrows()
	elif brood.guys.size() < brood.count: brood.wake_burrows(brood.count-brood.guys.size())
	_say("Brood now: the bag holds %d kg; they're coming for you" % int(round(float(bag.kg))) if bag != null else "Brood now")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_B and not _name_panel.visible:
		brood_now()
		return
	super._unhandled_input(event)

## A bag fallen into the void (dragged or lying on the deck at the snap,
## thrown short) is lost with its loot: the pieces go back on their spots
## and a fresh empty bag lies at the near end. On his back it stays with him
## (a fall empties it all the same: `_bag_lost_on_fall`).
func _bag_in_void() -> void:
	if bag == null or bag.state == "worn" or bag.state == "fly": return
	var loose: RigidBody3D = bag.loose
	if loose == null or not is_instance_valid(loose) or loose.global_position.y > VOID_Y: return
	if bag.state == "drag": bag.let_go()
	bag.empty()
	bag.state = "ground"
	loose.lock_rotation = true
	var xf := Transform3D(Basis.IDENTITY,Vector3(NEAR_LIP-3.0,0.6,LONG_Z+1.5))
	loose.global_transform = xf
	PhysicsServer3D.body_set_state(loose.get_rid(),PhysicsServer3D.BODY_STATE_TRANSFORM,xf)
	loose.linear_velocity = Vector3.ZERO
	loose.angular_velocity = Vector3.ZERO
	_say("The bag fell into the void, its loot with it (back on their spots)")

## Each frame every body tells the loaded bridges what it weighs where
## (BridgeLoad `bear_at`): he (his weight already sinks the deck by `tread`),
## his bag (on his back at his feet, else wherever it lies or is dragged),
## each brood guy (on him when clinging, else at its feet).
func _bear() -> void:
	var feet := global_transform*motor.feet
	BridgeLoad.bear_at(feet,BridgeLoad.WANDERER_KG,motor,false)
	if bag != null and float(bag.kg) > 0.0:
		var loose: Node3D = bag.loose
		var at := feet if bag.state == "worn" or loose == null or not is_instance_valid(loose) else loose.global_position
		BridgeLoad.bear_at(at,float(bag.kg),bag)
	if brood != null:
		for g: RefCounted in brood.guys:
			var at: Vector3 = feet if g.state == "cling" else brood.global_transform*g.feet
			BridgeLoad.bear_at(at,BROOD_BRIDGE_KG,g)

## The loaded bridges' readouts (a debug aid), top middle.
func _build_ui() -> void:
	super._build_ui()
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	var y := 12.0
	for id: String in LOADED:
		if not bridges.has(id) or not bridges[id].has("load"): continue
		var label := Label.new()
		label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		label.offset_left = -400.0
		label.offset_right = 400.0
		label.offset_top = y
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size",17)
		label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.7))
		label.add_theme_constant_override("shadow_offset_y",1)
		layer.add_child(label)
		bridges[id]["load"].readout = label
		y += 22.0

func _tread(delta: float, was_grounded: bool, falling: float) -> void:
	if RopeBridge._live.is_empty(): return
	var events := {}
	if motor.grounded and not was_grounded: events["landed"] = maxf(-minf(falling,_fall_speed),0.0)
	_fall_speed = 0.0 if motor.grounded else minf(_fall_speed,motor.velocity.y)
	var pace := Vector2(motor.velocity.x,motor.velocity.z).length()
	var drawn := {}
	if motor.grounded and pace > 0.6:
		_stride += delta*pace/STRIDE
		if _stride >= 1.0:
			_stride -= 1.0
			_foot = 1-_foot
			drawn["footfall"] = _foot
	var carry := RopeBridge.tread(self,motor.feet,motor.grounded,events,drawn,clampf(pace/PilotMotor.RUN,0.0,1.0))
	if carry != Vector3.ZERO: motor.feet += carry

## A fall into the void puts him back at the near end, or at the far end if
## he last stood on the far cliff.
## (Asked only on a fall; the bag goes with it, see `_bag_lost_on_fall`.)
func station_near(at: Vector3) -> int:
	if motor != null and motor.feet.y < float(lost): _bag_lost_on_fall()
	return 4 if at.x >= FAR_LIP else 2

## Any fall into the void, worn or not: he comes back wearing the bag, empty
## (its loot lost with the fall: the pieces back on their spots). Taken from
## the brood if they had it (hauled or buried).
func _bag_lost_on_fall() -> void:
	if bag == null: return
	var had := float(bag.kg)
	if bag.state == "drag": bag.let_go()
	if bool(bag.buried):
		bag.buried = false
		bag._sack.visible = true
		if brood != null and "bag_in" in brood: brood.bag_in = ""
	if bool(bag.hauled): bag.haul_free()
	bag.empty()
	if bag.state != "worn":
		bag._hold_loose()
		bag.state = "worn"
		bag._lag = Vector3.ZERO
		bag._lag_v = Vector3.ZERO
		bag._last_mid = Vector3.INF
	bag.act = ""
	bag._apply_feel(1.0)
	if had > 0.0: _say("Lost to the void: the bag's %d kg of loot (back on their spots)" % int(round(had)))

## The rip slowed while he stands on a loaded deck (RIP_ON_DECK).
func _rip_pace() -> void:
	if brood == null or not "rip_pace" in brood: return
	var feet := global_transform*motor.feet
	var on := false
	for id: String in LOADED:
		if bridges.has(id) and bridges[id].has("load") and bridges[id].load.deck_spot(feet) != Vector3.INF: on = true
	brood.rip_pace = RIP_ON_DECK if on else 1.0

## Each floor where its cliff now is (moved in the world view or by a
## saved layout): its rect and top shifted by the part's offset from its
## coded spot (turns aren't followed).
func _follow_floors() -> void:
	if routes == null: return
	var moved := false
	for i in range(_floor_of.size()):
		var f: Array = _floor_of[i]
		var node := get_node_or_null(NodePath(str(f[0]))) as Node3D
		if node == null: continue
		var rect: Rect2 = f[1]
		var top := float(f[2])
		var part: Array = []
		for p: Array in CLIFFS:
			if str(p[0]) == str(f[0]): part = p[1]
		var coded := Vector3(rect.get_center().x,(float(part[3])+float(part[2]))*0.5,rect.get_center().y)
		var off := node.global_position-coded
		if (f[3] as Vector3).is_equal_approx(off): continue
		f[3] = off
		for d: Dictionary in routes.floors:
			if str(d.name) != str(f[0]): continue
			d.rect = Rect2(rect.position+Vector2(off.x,off.z),rect.size)
			d.y = top+off.y
		moved = true
	if moved: routes._built = false

func _hint_text() -> String:
	return "Bridge study: WASD run · Space jump · Shift/C crouch · E (pad B) by loot: into the bag · F (pad down) bag off / on / drag · hold LMB or T (pad RT) aim a throw (8 kg or under) · V shove · the brood wake out of the burrows at the first piece bagged (--no-brood: none); a jump shakes clingers off · B (or --brood-now): brood now, the bag filled to 18 kg and the brood woken, coming for you (over either bridge) · the long bridge to the far cliff, the short one beside it · held past its limit the long bridge snaps: falling, he catches the hanging half on his side of the break; stick toward the cliff climbs, away down, Space jumps off, C lets go · fall into the void: back at the near end (the bridge mended) wearing the bag, empty · 1 start, 2 near end, 3 short bridge, 4 far end, 5 drop pad · R start · F1 numbers · F4 world view · Esc mouse"
