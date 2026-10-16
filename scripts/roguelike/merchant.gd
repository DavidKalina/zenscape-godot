extends Node3D
## [merchant] The stall (docs/design/roguelike/merchant-round1.md): on some
## layers a still, masked trader under an awning of weathered cloth, with
## wares on mats (items drawn from the catalog, plus a heart), their prices
## over them. The run's runes (`RunState.runes`, the purse) buy them.
##
## - Walk up to a ware: E (pad B) buys it, F (pad Y) just takes it.
## - Taking one unpaid makes him a thief for the rest of the run
##   (`RunState.thief`): the Collector (merchant_collector.gd) comes for
##   him, here and on every layer after, and the stalls ahead are shut.
##
## Laying (`lay`, data only): a stall on the layers a run alternates
## (odd regions; `--merchant=always` every layer, `--merchant=start` beside
## the spawn). Standing (`dress`, a child of LayerStage, which steps
## `before`): set down on flat ground when he comes within NEAR m.
const RunState = preload("res://scripts/roguelike/run_state.gd")
const ItemCatalog = preload("res://scripts/roguelike/item_catalog.gd")
const RunFeatures = preload("res://scripts/roguelike/run_features.gd")
const Collectibles = preload("res://scripts/roguelike/collectibles.gd")
const LayerWorlds = preload("res://scripts/roguelike/layer_worlds.gd")
const Collector = preload("res://scripts/roguelike/merchant_collector.gd")
const PadPrompt = preload("res://scripts/pad_prompt.gd")
const MerchantNook = preload("res://scripts/roguelike/merchant_nook.gd")

## Wares besides the heart, the heart's price (runes).
const WARES := 3
const HEART_PRICE := 6
## Stood when he is within NEAR m (flat); retried every RETRY s.
const NEAR := 70.0
## A nook's stall stands further off, its lamp seen across from the place.
const NEAR_NOOK := 140.0
const RETRY := 0.5
## A ware is reachable within REACH m (flat) of his feet.
const REACH := 1.15
## Wares are spaced this far (m) along the mat row.
const SPACING := 1.25
## Flat ground wanted under the stall: its half width and depth (m), the
## most the ground may differ over it.
const FLAT_X := 2.6
const FLAT_Z := 1.6
const FLAT_TOL := 1.7
## Seconds after a theft before the Collector comes, and after a gate.
const COME_AFTER := 6.0
const COME_AFTER_GATE := 14.0
## The actions: buy, take. (E / B and F / Y: the cannon's, which a walker
## on foot does not use.)
const BUY := &"cannon_leave"
const TAKE := &"cannon_climb"

var study: Node3D
var plan: Dictionary
## The stall laid: {at, face (flat Vector3), shut}, or {} (a layer without).
var stall := {}
## The wares stood: {id, price, node, label, at (world), gone}.
var wares: Array = []
var trader: Node3D = null
var collector: Node3D = null
var standing := false
var bought := 0
var stolen := 0
var _unit := 1.8
var _clock := 0.0
var _retry := 0.0
var _held := {}
var _prompt: Label
var _toast: Label
var _toast_t := 0.0
var _eyes: Array = []
var _eye_glow := 0.0
var _mask: Node3D
var _ray := PhysicsRayQueryParameters3D.new()

func _init() -> void:
	name = "Merchant"

# --- Laying -------------------------------------------------------------------

## Whether `layer` has a stall (data only).
static func lays(layer: Dictionary) -> bool:
	# Not where every isle's motif opts out (`without()`, RunFeatures.motif_lets).
	var isles: Array = layer.get("isles",[])
	if not isles.is_empty() and isles.all(func(i: Dictionary) -> bool: return not RunFeatures.motif_lets(&"merchant",i.get("motif"))): return false
	return MerchantNook.wanted(layer)

## Where it stands (data only): {at, face, shut, nook}. The plan's nook (a
## side spur off a place on the way, merchant_nook.gd: platform out to it),
## else a spot of a route isle off the base (cover or perch with room), else
## beside the spawn (`--merchant=start` there always).
static func lay(layer: Dictionary) -> Dictionary:
	var spawn: Dictionary = layer.get("spawn",{})
	var from: Vector3 = spawn.get("at",Vector3.ZERO)
	var shut: bool = RunState.current != null and bool(RunState.current.get("thief"))
	var nook: Dictionary = layer.get("nook",{})
	if not nook.is_empty() and RunFeatures.value("merchant") != "start":
		# Back from the slab's middle, so the wares' front has the room.
		var f: Vector3 = nook.face
		return {"at":(nook.at as Vector3)-f*0.6,"face":f,"shut":shut,"isle":false,"nook":true}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(layer.get("seed",0)),"merchant"])
	var best := {}
	if RunFeatures.value("merchant") != "start":
		var spots: Array = []
		for isle: Dictionary in layer.get("isles",[]):
			if str(isle.get("role","")) in ["base","greed"]: continue
			if not RunFeatures.motif_lets(&"merchant",isle.get("motif")): continue
			for s: Dictionary in Collectibles.spots_of(isle):
				if str(s.kind) in ["cover","perch"] and float(s.room) >= 2.0: spots.append(s)
		if not spots.is_empty(): best = spots[rng.randi() % spots.size()]
	var at: Vector3 = (best.at as Vector3) if not best.is_empty() else from+Vector3(9.0,0.0,0.0)
	var face := from-at
	face.y = 0.0
	if face.length() < 0.1: face = Vector3(0,0,1)
	return {"at":at,"face":face.normalized(),"shut":shut,"isle":best.is_empty(),"nook":false}

## The stall (and, once a thief, the Collector) stood on `stage`; null when
## the layer has neither.
static func dress(stage: Node3D, layer: Dictionary) -> Node3D:
	var thief: bool = RunState.current != null and bool(RunState.current.get("thief"))
	if not lays(layer) and not thief: return null
	var node: Node3D = new()
	stage.add_child(node)
	node.setup(stage.study,layer)
	return node

func setup(scene: Node3D, layer: Dictionary) -> void:
	study = scene
	plan = layer
	if lays(layer): stall = lay(layer)
	var g: Variant = scene.get("ground")
	if g != null and g.get("head_top") != null: _unit = float(g.head_top)
	var run: Variant = RunState.current
	if run != null and bool(run.get("thief")): _summon(COME_AFTER_GATE)

# --- The frame ----------------------------------------------------------------

func before(delta: float) -> void:
	_clock += delta
	if not stall.is_empty() and not standing:
		_retry -= delta
		if _retry <= 0.0:
			_retry = RETRY
			_try_stand()
	_toast_step(delta)
	_eye_glow = move_toward(_eye_glow,1.0 if bool(_thief()) else 0.0,delta*0.8)
	for e: Variant in _eyes: (e as MeshInstance3D).scale = Vector3.ONE*(1.0+_eye_glow*0.6)
	if _mask != null and bool(_thief()) and study.get("motor") != null:
		var to: Vector3 = study.motor.feet-trader.global_position
		var want := atan2(-to.x,-to.z)-trader.global_rotation.y+PI
		_mask.rotation.y = lerp_angle(_mask.rotation.y,clampf(wrapf(want,-PI,PI),-1.1,1.1),delta*2.0)
	if collector != null: collector.step(delta)
	if _can_act():
		if _edge(BUY): _buy(_near())
		if _edge(TAKE): _take(_near())
	_show_prompt()

func after(_delta: float, _events: Dictionary) -> void:
	pass

func _thief() -> bool:
	return RunState.current != null and bool(RunState.current.get("thief"))

func _can_act() -> bool:
	var motor: Variant = study.get("motor")
	return standing and motor != null and motor.grounded and motor.rider == null and not _shut()

func _shut() -> bool:
	return bool(stall.get("shut",false))

func _edge(action: StringName) -> bool:
	var down := Input.is_action_pressed(action)
	var was: bool = _held.get(action,false)
	_held[action] = down
	return down and not was

## The ware he could act on from where he stands, or -1.
func _near() -> int:
	var motor: Variant = study.get("motor")
	if motor == null: return -1
	var best := -1
	var gap := INF
	for i in range(wares.size()):
		var w: Dictionary = wares[i]
		if w.gone: continue
		var at: Vector3 = w.at
		var d := Vector2(at.x-motor.feet.x,at.z-motor.feet.z).length()
		if d <= REACH*float(motor.size) and absf(at.y-motor.feet.y) < 1.5 and d < gap:
			best = i
			gap = d
	return best

# --- Buying and taking ----------------------------------------------------------

## Ware `i` bought with the purse: true when it was. (Public: a driver may call it.)
func buy(i: int) -> bool:
	return _buy(i)

## Ware `i` taken unpaid: true when it was.
func take(i: int) -> bool:
	return _take(i)

func _buy(i: int) -> bool:
	var run: Variant = RunState.current
	if i < 0 or run == null: return false
	var w: Dictionary = wares[i]
	if w.id == &"heart" and run.hearts_of(study.motor) >= RunState.HEARTS:
		_say("HEARTS FULL","he keeps his coin")
		return false
	if run.runes < int(w.price):
		_say("NOT ENOUGH RUNES","%d wanted, %d in the purse" % [int(w.price),run.runes])
		return false
	run.runes -= int(w.price)
	bought += 1
	_deliver(w,true)
	_nod()
	return true

func _take(i: int) -> bool:
	var run: Variant = RunState.current
	if i < 0 or run == null: return false
	var w: Dictionary = wares[i]
	if w.id == &"heart" and run.hearts_of(study.motor) >= RunState.HEARTS:
		return false
	stolen += 1
	_deliver(w,false)
	if not bool(run.get("thief")):
		run.thief = true
		_say("THIEF","the city will remember")
		_summon(COME_AFTER)
	return true

## The ware into the run: an item, or a heart.
func _deliver(w: Dictionary, paid: bool) -> void:
	var run: Variant = RunState.current
	w.gone = true
	if w.id == &"heart":
		run.hearts[study.motor] = mini(RunState.HEARTS,run.hearts_of(study.motor)+1)
		if paid: _say("A HEART","mended")
	else:
		run.give_item(w.id)
	var node: Node3D = w.node
	if is_instance_valid(node):
		var tw := create_tween()
		tw.tween_property(node,"scale",Vector3.ONE*0.01,0.25)
		tw.tween_callback(node.queue_free)
	var label: Label3D = w.label
	if is_instance_valid(label): label.queue_free()

func _summon(after: float) -> void:
	if collector != null: return
	collector = Collector.new()
	add_child(collector)
	collector.setup(study,after,_unit)

# --- Standing ---------------------------------------------------------------------

func _try_stand() -> void:
	var me: Variant = study.get("motor")
	if me == null or not is_inside_tree(): return
	var at: Vector3 = stall.at
	if Vector2(at.x-me.feet.x,at.z-me.feet.z).length() > (NEAR_NOOK if bool(stall.get("nook",false)) else NEAR): return
	var face: Vector3 = stall.face
	var side := Vector3(face.z,0.0,-face.x)
	# The spot and a few places round it, the first with flat ground.
	for off: Vector3 in [Vector3.ZERO,face*2.0,-face*2.0,side*2.5,-side*2.5,face*4.0,side*5.0,-side*5.0]:
		var p := at+off
		var y := _flat(p,face)
		if y != INF:
			_build(Vector3(p.x,y,p.z))
			standing = true
			return

## The ground's height under `p` if it is flat across the stall's footing
## (rays at the four corners and the middle), else INF.
func _flat(p: Vector3, face: Vector3) -> float:
	var side := Vector3(face.z,0.0,-face.x)
	var y0 := _ground_under(p)
	if y0 == INF: return INF
	var top := y0
	for ix in range(-2,3):
		for iz in range(-1,3):
			var y := _ground_under(p+side*float(ix)*FLAT_X*0.5+face*(float(iz)*1.6-0.2))
			if y == INF or absf(y-y0) > FLAT_TOL: return INF
			top = maxf(top,y)
	# Stood on the highest, so nothing is buried; the low corners hang over steps.
	return top

## How far the ground under local point `local` of `root` stands over the
## stall's own (m, within FLAT_TOL; 0 where there is none).
func _drop(root: Node3D, local: Vector3) -> float:
	var w := root.to_global(local)
	var y := _ground_under(Vector3(w.x,root.global_position.y,w.z),FLAT_TOL+0.6)
	return 0.0 if y == INF else clampf(y-root.global_position.y,-FLAT_TOL-0.6,0.0)

func _ground_under(p: Vector3, up := 1.6) -> float:
	var mask := 1
	var g: Variant = study.get("ground")
	if g != null and g.get("mask") != null: mask = int(g.mask)
	_ray.from = Vector3(p.x,p.y+up,p.z)
	_ray.to = Vector3(p.x,p.y-2.4,p.z)
	_ray.collision_mask = mask
	var hit := get_world_3d().direct_space_state.intersect_ray(_ray)
	return INF if hit.is_empty() else (hit.position as Vector3).y

func _build(at: Vector3) -> void:
	var face: Vector3 = stall.face
	var root := Node3D.new()
	root.name = "Stall"
	add_child(root)
	# Local +Z is the front, the customers'.
	root.global_transform = Transform3D(Basis.looking_at(-face,Vector3.UP),at)
	var u := _unit
	var cloth := _cloth(0.0)
	var cloth2 := _cloth(1.0)
	var wood := _wood()
	# Poles at the back, shorter at the front; the awning sagging between.
	for sx: float in [-1.0,1.0]:
		var back := _drop(root,Vector3(sx*2.4,0.0,-1.1))
		var front := _drop(root,Vector3(sx*2.4,0.0,0.8))
		_part(root,_cyl(0.045*u,0.05*u,1.6*u+2.0),wood,Vector3(sx*2.4,0.8*u+back-1.0,-1.1))
		_part(root,_cyl(0.04*u,0.045*u,1.1*u+2.0),wood,Vector3(sx*2.4,0.55*u+front-1.0,0.8))
	var shut := _shut()
	var awning := _box(Vector3(5.2,0.04,2.1),cloth)
	var pitch := deg_to_rad(13.0) if not shut else deg_to_rad(52.0)
	awning.position = Vector3(0.0,(1.42 if not shut else 0.95)*u,-0.3)
	awning.rotation.x = pitch
	root.add_child(awning)
	# Hem and a patch of other cloth, so it reads as worn.
	var hem := _box(Vector3(5.2,0.22*u,0.03),cloth2)
	hem.position = Vector3(0.0,(1.12 if not shut else 0.55)*u,0.74 if not shut else 1.55)
	root.add_child(hem)
	var patch := _box(Vector3(1.1,0.03,0.9),cloth2)
	patch.position = awning.position+Vector3(-1.2,0.025,0.1)
	patch.rotation = awning.rotation
	root.add_child(patch)
	# Counter: a worn stone slab on two blocks.
	var stone := _stone()
	_part(root,_boxm(Vector3(3.2,0.12*u,0.7)),stone,Vector3(0.0,0.5*u,0.35))
	for sx: float in [-1.2,1.2]:
		_part(root,_boxm(Vector3(0.55,0.5*u+2.0,0.55)),stone,Vector3(sx,0.25*u-1.0,0.35))
	if shut:
		_shutter(root,u,stone,cloth2)
		return
	_trader(root,u)
	_lay_wares(root,u,cloth2)
	_light(root,u)

func _shutter(root: Node3D, u: float, stone: Material, cloth: Material) -> void:
	# The stall shut: a slab stood across the counter and a cloth thrown over.
	_part(root,_boxm(Vector3(3.4,1.0*u,0.14)),stone,Vector3(0.0,0.62*u,0.9),Vector3(0.0,0.0,0.03))
	var over := _box(Vector3(2.6,0.03,1.1),cloth)
	over.position = Vector3(0.1,0.78*u,0.55)
	over.rotation.x = deg_to_rad(-12.0)
	root.add_child(over)
	var sign := Label3D.new()
	sign.text = "shut"
	sign.font_size = 40
	sign.pixel_size = 0.004
	sign.modulate = Color("cfc2a4",0.8)
	sign.outline_size = 8
	sign.outline_modulate = Color(0.05,0.04,0.03,0.9)
	sign.position = Vector3(0.0,1.25*u,1.0)
	root.add_child(sign)

func _trader(root: Node3D, u: float) -> void:
	var t := Node3D.new()
	t.name = "Trader"
	t.position = Vector3(0.0,0.0,-0.35)
	root.add_child(t)
	trader = t
	var robe := _cloth(2.0)
	# A long cloak, narrowing up, shoulders, folded arms; a hood behind the mask.
	_part(t,_cyl(0.19*u,0.44*u,0.95*u),robe,Vector3(0.0,0.475*u,0.0))
	_part(t,_sphere(0.21*u),robe,Vector3(0.0,0.92*u,0.0),Vector3.ZERO,Vector3(1.2,0.7,0.8))
	_part(t,_boxm(Vector3(0.5*u,0.12*u,0.16*u)),_cloth(3.0),Vector3(0.0,0.72*u,0.18*u))
	_part(t,_sphere(0.19*u),robe,Vector3(0.0,1.08*u,-0.06*u),Vector3.ZERO,Vector3(1.0,1.15,1.0))
	var mask := Node3D.new()
	mask.position = Vector3(0.0,1.08*u,0.1*u)
	t.add_child(mask)
	_mask = mask
	_part(mask,_sphere(0.17*u),_stone_dark(),Vector3.ZERO,Vector3.ZERO,Vector3(0.86,1.2,0.42))
	# Brow ridge and a long nose, brass rim at the mouth.
	_part(mask,_boxm(Vector3(0.26*u,0.035*u,0.06*u)),_stone_dark(),Vector3(0.0,0.07*u,0.07*u))
	_part(mask,_boxm(Vector3(0.05*u,0.15*u,0.07*u)),_stone_dark(),Vector3(0.0,-0.02*u,0.075*u))
	_part(mask,_boxm(Vector3(0.16*u,0.02*u,0.03*u)),_brass(),Vector3(0.0,-0.12*u,0.07*u))
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(0.05,0.04,0.03)
	glow.emission_enabled = true
	glow.emission = Color(0.95,0.68,0.32)
	glow.emission_energy_multiplier = 0.55
	for sx: float in [-1.0,1.0]:
		var eye := _part(mask,_boxm(Vector3(0.07*u,0.016*u,0.02*u)),glow,Vector3(sx*0.07*u,0.035*u,0.075*u))
		_eyes.append(eye)

func _lay_wares(root: Node3D, u: float, mat_cloth: Material) -> void:
	var run: Variant = RunState.current
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(plan.get("seed",0)),"wares"])
	var picks: Array[StringName] = []
	for _i in range(WARES * 3):
		if picks.size() >= WARES: break
		var id := ItemCatalog.draw(rng,[],run)
		if id != &"" and not picks.has(id): picks.append(id)
	picks.append(&"heart")
	var n := picks.size()
	for i in range(n):
		var id: StringName = picks[i]
		var x := (float(i)-float(n-1)*0.5)*SPACING
		var lift := _drop(root,Vector3(x,0.0,1.35))
		var mat := _boxm(Vector3(0.95,0.025,0.8))
		_part(root,mat,mat_cloth,Vector3(x,0.0125+lift,1.35),Vector3(0.0,rng.randf_range(-0.12,0.12),0.0))
		var holder := Node3D.new()
		holder.position = Vector3(x,0.04+lift,1.35)
		root.add_child(holder)
		_ware_body(holder,id,u)
		var price := HEART_PRICE if id == &"heart" else int(ItemCatalog.info(id).get("price",5))
		var title := "Heart" if id == &"heart" else ItemCatalog.title(id)
		var label := Label3D.new()
		label.text = "%s\n%d %s" % [title,price,"rune" if price == 1 else "runes"]
		label.font_size = 36
		label.pixel_size = 0.0042
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color("e9dcc0")
		label.outline_size = 10
		label.outline_modulate = Color(0.06,0.05,0.04,0.9)
		label.position = Vector3(x,0.68*u+lift,1.35)
		root.add_child(label)
		wares.append({"id":id,"price":price,"node":holder,"label":label,"at":root.to_global(Vector3(x,lift,1.35)),"gone":false})

## A ware's small body on its mat, by kind: rolled cloth, a brass disc, a
## clay jar, a carved stone heart.
func _ware_body(h: Node3D, id: StringName, u: float) -> void:
	var kind := "heart" if id == &"heart" else str(ItemCatalog.info(id).get("kind","verb"))
	match kind:
		"heart":
			var clay := StandardMaterial3D.new()
			clay.albedo_color = Color(0.62,0.38,0.32)
			clay.roughness = 0.9
			clay.emission_enabled = true
			clay.emission = Color(0.8,0.5,0.3)
			clay.emission_energy_multiplier = 0.12
			_part(h,_sphere(0.12*u),clay,Vector3(-0.07*u,0.12*u,0.0),Vector3.ZERO,Vector3(1.0,0.9,0.9))
			_part(h,_sphere(0.12*u),clay,Vector3(0.07*u,0.12*u,0.0),Vector3.ZERO,Vector3(1.0,0.9,0.9))
			_part(h,_cone(0.17*u,0.2*u),clay,Vector3(0.0,0.07*u,0.0),Vector3(PI,0.0,0.0))
		"passive":
			var disc := _cyl(0.17*u,0.17*u,0.03*u)
			_part(h,disc,_brass(),Vector3(0.0,0.05*u,0.0),Vector3(deg_to_rad(18.0),0.0,0.0))
			_part(h,_cyl(0.07*u,0.07*u,0.05*u),_stone_dark(),Vector3(0.0,0.06*u,0.0),Vector3(deg_to_rad(18.0),0.0,0.0))
		"cursed":
			var jar := _cyl(0.1*u,0.14*u,0.26*u)
			_part(h,jar,_stone_dark(),Vector3(0.0,0.13*u,0.0))
			_part(h,_cyl(0.07*u,0.07*u,0.03*u),_brass(),Vector3(0.0,0.275*u,0.0))
		_:
			var bundle := _cyl(0.1*u,0.1*u,0.5*u)
			_part(h,bundle,_cloth(float(hash(id) % 5)),Vector3(0.0,0.1*u,0.0),Vector3(0.0,0.0,PI*0.5))
			for bx: float in [-0.12,0.12]:
				_part(h,_cyl(0.108*u,0.108*u,0.04*u),_leather(),Vector3(bx*u,0.1*u,0.0),Vector3(0.0,0.0,PI*0.5))

## A dim warm lantern for the stall: low, so the ware row is read in the dark.
func _light(root: Node3D, u: float) -> void:
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0,0.78,0.5)
	lamp.light_energy = 0.7
	lamp.omni_range = 6.5
	lamp.shadow_enabled = false
	lamp.position = Vector3(0.0,1.0*u,1.0)
	root.add_child(lamp)

func _nod() -> void:
	if _mask == null: return
	var tw := create_tween()
	tw.tween_property(_mask,"rotation:x",0.35,0.18)
	tw.tween_property(_mask,"rotation:x",0.0,0.4)

# --- Prompt and toast -----------------------------------------------------------------

func prompt_lines() -> Array:
	if not _can_act(): return ["",""]
	var i := _near()
	if i < 0: return ["",""]
	var w: Dictionary = wares[i]
	var title := "Heart" if w.id == &"heart" else ItemCatalog.title(w.id)
	var run: Variant = RunState.current
	var have: int = run.runes if run != null else 0
	var cost := "%d runes" % int(w.price) if int(w.price) != 1 else "1 rune"
	if have >= int(w.price):
		return ["E  buy %s (%s)      F  take it" % [title,cost],"{cannon_leave}  buy %s (%s)      {cannon_climb}  take it" % [title,cost]]
	return ["%s: %s, and the purse holds %d      F  take it" % [title,cost,have],"%s: %s, and the purse holds %d      {cannon_climb}  take it" % [title,cost,have]]

func shown_prompt() -> String:
	return _prompt.shown_text() if _prompt != null else ""

func _show_prompt() -> void:
	if _prompt == null:
		var layer := CanvasLayer.new()
		layer.layer = 6
		add_child(layer)
		_prompt = PadPrompt.new()
		_prompt.add_theme_font_size_override("font_size",16)
		_prompt.add_theme_color_override("font_color",Color("fbf6ea"))
		_prompt.add_theme_color_override("font_shadow_color",Color(0,0,0,0.55))
		_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
		_prompt.offset_top = -110.0
		_prompt.offset_bottom = -80.0
		_prompt.offset_left = -480.0
		_prompt.offset_right = 480.0
		layer.add_child(_prompt)
		_toast = Label.new()
		_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_toast.add_theme_font_size_override("font_size",26)
		_toast.add_theme_color_override("font_color",Color("e9dcc0"))
		_toast.add_theme_color_override("font_shadow_color",Color(0,0,0,0.7))
		_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
		_toast.offset_top = 150.0
		_toast.offset_bottom = 220.0
		_toast.offset_left = -400.0
		_toast.offset_right = 400.0
		_toast.modulate.a = 0.0
		layer.add_child(_toast)
	var lines := prompt_lines()
	_prompt.alternates = {lines[0]:lines[1]}
	_prompt.text = lines[0]
	_prompt.visible = lines[0] != ""

## A line up top for a few seconds (the run loop's caption belongs to items).
func _say(head: String, line: String) -> void:
	_show_prompt()
	_toast.text = "%s\n%s" % [head,line]
	_toast_t = 3.0
	_toast_text = _toast.text

var _toast_text := ""

func _toast_step(delta: float) -> void:
	if _toast == null: return
	_toast_t = maxf(_toast_t-delta,0.0)
	_toast.modulate.a = clampf(_toast_t,0.0,1.0)

# --- Materials and parts ----------------------------------------------------------------

func _noise_tex(freq: float, seed_value: int, a: Color, b: Color) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.seed = seed_value
	var t := NoiseTexture2D.new()
	t.noise = n
	t.width = 128
	t.height = 128
	t.seamless = true
	var g := Gradient.new()
	g.set_color(0,a)
	g.set_color(1,b)
	t.color_ramp = g
	return t

## Sun-faded, rain-stained cloth: muted ochre, indigo, umber, bone.
func _cloth(variant: float) -> StandardMaterial3D:
	var tones := [[Color("574830"),Color("86723f")],[Color("2f3a4a"),Color("55637a")],[Color("4b3a2c"),Color("7a6244")],
		[Color("6a6552"),Color("a49d84")],[Color("57432f"),Color("8c6d44")]]
	var t: Array = tones[int(variant) % tones.size()]
	var m := StandardMaterial3D.new()
	m.albedo_texture = _noise_tex(0.03,int(variant)*17+3,t[0],t[1])
	m.roughness = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.uv1_scale = Vector3(3,3,1)
	return m

func _wood() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _noise_tex(0.05,9,Color("2e241b"),Color("5a4733"))
	m.roughness = 0.95
	return m

func _stone() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _noise_tex(0.04,21,Color("3d3a35"),Color("736d62"))
	m.roughness = 0.97
	m.uv1_scale = Vector3(2,2,2)
	return m

func _stone_dark() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = _noise_tex(0.08,33,Color("26241f"),Color("57524a"))
	m.roughness = 0.9
	return m

func _brass() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("7d6a3c")
	m.metallic = 0.7
	m.roughness = 0.55
	return m

func _leather() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("3b2a1d")
	m.roughness = 0.85
	return m

func _boxm(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b

func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r*2.0
	s.radial_segments = 16
	s.rings = 8
	return s

func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 14
	return c

func _cone(r: float, h: float) -> CylinderMesh:
	return _cyl(0.0,r,h)

func _box(size: Vector3, mat: Material) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = _boxm(size)
	m.material_override = mat
	return m

func _part(parent: Node3D, mesh: Mesh, mat: Material, at: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.material_override = mat
	m.position = at
	m.rotation = rot
	m.scale = scl
	parent.add_child(m)
	return m
