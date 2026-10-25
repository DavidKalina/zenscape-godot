extends "res://studies/character_study.gd"
## The city breaks yard, round 2:
## four more pieces of the city kit where the Olmec's power reshapes the
## routes (scripts/city_kit_breaks2.gd), round a greybox yard, with a whole
## Olmec hunting you (his chase, his periscope, his chase routes).
##   north  the plug-stone: a keystone plugging the only gate in a wall
##          past his climb. Stand at its face till he pounces at you, then
##          get out of the way: he breaks it. Run through; he follows.
##   east   the chocked slab: a slab on its end at a gap too wide for both
##          of you. Climb the striker's block behind its plate, jump off
##          and slam the plate: it swings down across the gap. Don't stand
##          where it lands.
##   south  the corbel vault: the gate to the vault court. Its outer bay is
##          cracked: bring him to its mouth and let him land there, and the
##          bay comes in. He still walks through (over the heap); you climb
##          the heap and the broken east haunch to the roof, and on to the
##          upper terrace.
##   west   the facing sheet wall under a terrace. Up the walker-only steps
##          at its south end; stand on a column's top over him and let him
##          climb (or land) by it: it peels; ride your column down, run up
##          the earth slumped behind it.
## `--underground=haze` (or torch) puts it in the abyss; L flips the look.
##   R   all back: you, him, every piece whole
##   B   him back where he began
##   1-6 stations · F1 numbers
##   godot --path . res://studies/city_breaks2_yard.tscn -- --no-title
##     [--underground=haze] [--ground=grass|dust|moss|off] [--body-knob=<knob>=<value>]
##     [--head-knob=...] [--body-at=x,z] [--body-face=x,z] [--no-body] [--no-sight-overlay]
##     [--broken=plug,chock,corbel,skin]
const EnemyField = preload("res://scripts/enemies/enemy_field.gd")
const InhalerHead = preload("res://scripts/enemies/inhaler_head.gd")
const HeadlessBody = preload("res://scripts/enemies/headless_body.gd")
const BodySpawner = preload("res://scripts/enemies/body_spawner.gd")
const EnemyYard = preload("res://studies/enemy_yard.gd")
const SightOverlay = preload("res://scripts/enemies/body_sight_overlay.gd")
const Breaks = preload("res://scripts/kit_isle/colonnade_breaks.gd")
const Breakables = preload("res://scripts/breaks/breakables.gd")
const CityBreaks2 = preload("res://scripts/city_kit_breaks2.gd")
const Plug = preload("res://scripts/city_breaks/plug_stone.gd")
const Chock = preload("res://scripts/city_breaks/chocked_slab.gd")
const Corbel = preload("res://scripts/city_breaks/corbel_vault.gd")
const SkinWall = preload("res://scripts/city_breaks/skin_wall.gd")
const Underground = preload("res://scripts/underground/underground.gd")
const GroundCover = preload("res://scripts/underground/ground_cover.gd")
const WalkerOnly = preload("res://scripts/walker_only.gd")

const YARD_LOST := -40.0
const UNDER := -12.0
## The yard (x, z) all four stand round.
const YARD := Rect2(-36.0,-30.0,72.0,60.0)
## The plug's wall's middle (its south face on the yard's north edge), the
## court behind it.
const PLUG_AT := Vector3(-12.0,0.0,-30.0-Plug.THICK*0.5)
const PLUG_COURT := Rect2(-36.0,-64.0,48.0,64.0-30.0-Plug.THICK)
## The chock's near rim (the yard's east edge), turned so its span runs
## east; the far court past its far pier.
const CHOCK_AT := Vector3(36.0,0.0,0.0)
const CHOCK_FAR := 22.0
## The corbel vault's middle: its cracked bay's mouth on the yard's south
## edge; the vault court past it; the upper terrace east of it, its top
## the vault's roof.
const CORBEL_AT := Vector3(-6.0,0.0,30.0+Corbel.BAY_L)
const VAULT_COURT := Rect2(-30.0,30.0+2.0*Corbel.BAY_L,52.0,26.0)
## The skin wall's sheets' face on the yard's west edge, turned to face
## east; the terrace behind it.
const SKIN_AT := Vector3(-36.0-SkinWall.SHEET_T,0.0,0.0)
const TERRACE_W := 26.0
## Where he stands and you start.
const BODY_AT := Vector3(6.0,0.0,-6.0)
const PILOT_AT := Vector3(0.0,0.0,12.0)
const OLMEC_STEP := 2.4

var enemies: Node
var hub: Node3D
var plug: Node3D
var chock: Node3D
var corbel: Node3D
var skin: Node3D
var overlay: Node3D
var under: Node3D
var _environment: Environment
var _sun: DirectionalLight3D
var _voices := {}
var _body_knobs := {}
var _head_knobs := {}
var _body_at := BODY_AT
var _body_face := Vector2(0.0,1.0)
var _no_body := false
var _overlay_on := true
var _broken: PackedStringArray = []
var _ground_kind := ""

class Slot extends Node:
	var field: Node
	var hub: Node
	func before(delta: float) -> void:
		for e in field.enemies:
			if is_instance_valid(e) and e.has_method("world_changed") and e.breaker == null: e.breaker = hub
		field.before(delta)
	func after(delta: float, events: Dictionary) -> void: field.after(delta,events)
	func pose(figure: Node3D) -> void:
		var held := false
		for e in field.enemies:
			if is_instance_valid(e) and e.get("swallowed"): held = true
		figure.visible = not held

func _ready() -> void:
	pack = "city_breaks2"
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg == "--no-body": _no_body = true
		elif arg == "--no-sight-overlay": _overlay_on = false
		elif arg.begins_with("--broken="): _broken = arg.get_slice("=",1).split(",")
		elif arg.begins_with("--body-face="):
			var f := arg.get_slice("=",1).split(",")
			_body_face = Vector2(float(f[0]),float(f[1]) if f.size() > 1 else 0.0).normalized()
		elif arg.begins_with("--body-at="):
			var p := arg.get_slice("=",1).split(",")
			_body_at = Vector3(float(p[0]),0.0,float(p[1]) if p.size() > 1 else 0.0)
		for pair in [["--body-knob=",_body_knobs],["--head-knob=",_head_knobs]]:
			if arg.begins_with(pair[0]):
				var kv: String = arg.trim_prefix(pair[0])
				pair[1][kv.get_slice("=",0)] = float(kv.get_slice("=",1))
	super._ready()

## The yard's turned pieces: +Z to +X (the chock's span, the skin's face).
static func east_turn() -> Basis:
	return Basis(Vector3.UP,PI*0.5)

static func chock_xf() -> Transform3D:
	return Transform3D(east_turn(),CHOCK_AT)

static func skin_xf() -> Transform3D:
	return Transform3D(east_turn(),SKIN_AT)

## The chock's near pier (world rect), cut out of the yard's floor.
static func chock_pier() -> Rect2:
	var w := Chock.SLAB.x+Chock.CELL
	return Rect2(CHOCK_AT.x-Chock.PIER,CHOCK_AT.z-w*0.5,Chock.PIER,w)

static func far_x() -> float:
	return CHOCK_AT.x+Chock.gap()+Chock.PIER

## The upper terrace east of the vault (world rect), its top the roof.
static func upper_terrace() -> Rect2:
	var x0 := CORBEL_AT.x+Corbel.outer()
	return Rect2(x0,30.0,YARD.end.x-8.0-x0,2.0*Corbel.BAY_L)

## The skin's terrace behind its core (world rect).
static func skin_terrace() -> Rect2:
	var x1 := SKIN_AT.x-SkinWall.CORE_D
	return Rect2(x1-TERRACE_W,YARD.position.y,TERRACE_W,YARD.size.y)

func _load_pack() -> void:
	start = PILOT_AT
	start_face = Vector2(0.0,-1.0)
	lost = YARD_LOST
	_last_stood = start
	var parts := []
	var holes: Array[Rect2] = [chock_pier()]
	for r: Rect2 in _floor_rects(YARD,holes): parts.append(["box",r,UNDER,0.0,"floor"])
	# The plug's court, its wall run on to the court's sides (past his climb).
	parts.append(["box",PLUG_COURT,UNDER,0.0,"pad"])
	var wz := Rect2(0.0,PLUG_AT.z-Plug.THICK*0.5,0.0,Plug.THICK)
	var wall_half := Plug.LANE*0.5+Plug.JAMB
	parts.append(["box",Rect2(PLUG_COURT.position.x,wz.position.y,PLUG_AT.x-wall_half-PLUG_COURT.position.x,wz.size.y),UNDER,Plug.WALL_H,"wall"])
	parts.append(["box",Rect2(PLUG_AT.x+wall_half,wz.position.y,PLUG_COURT.end.x-PLUG_AT.x-wall_half,wz.size.y),UNDER,Plug.WALL_H,"wall"])
	parts.append(["label",PLUG_AT+Vector3(0.0,1.2,Plug.THICK*0.5+3.0),"the plug-stone · stand at its face, let him pounce"])
	parts.append(["label",Vector3(PLUG_COURT.get_center().x,0.8,PLUG_COURT.get_center().y),"the plug court"])
	# The chock's far court.
	var fx := far_x()
	parts.append(["box",Rect2(fx,-20.0,CHOCK_FAR,40.0),UNDER,0.0,"pad"])
	parts.append(["label",Vector3(fx+CHOCK_FAR*0.5,0.8,0.0),"the far court"])
	parts.append(["label",CHOCK_AT+Vector3(-7.0,3.4,-4.0),"the chock's plate · slam it from the block"])
	# The vault court; the upper terrace (its top the roof) east of the vault.
	parts.append(["box",VAULT_COURT,UNDER,0.0,"pad"])
	parts.append(["label",Vector3(VAULT_COURT.get_center().x,0.8,VAULT_COURT.get_center().y),"the vault court"])
	var ut := upper_terrace()
	parts.append(["box",ut,UNDER,Corbel.roof(),"wall"])
	parts.append(["label",Vector3(ut.get_center().x,Corbel.roof()+0.8,ut.get_center().y),"the upper terrace · %.1f m (over the vault's roof)" % Corbel.roof()])
	parts.append(["label",CORBEL_AT+Vector3(0.0,1.2,-Corbel.BAY_L-3.0),"the corbel vault · its outer bay is cracked"])
	# The skin's terrace, its face beside the wall, the striker's block on it.
	var st := skin_terrace()
	var h := SkinWall.height()
	parts.append(["box",st,UNDER,h,"wall"])
	var face := Rect2(SKIN_AT.x-SkinWall.CORE_D,YARD.position.y,SkinWall.CORE_D+SkinWall.SHEET_T,YARD.size.y)
	var half := SkinWall.width()*0.5
	parts.append(["box",Rect2(face.position.x,face.position.y,face.size.x,SKIN_AT.z-half-face.position.y),UNDER,h,"wall"])
	parts.append(["box",Rect2(face.position.x,SKIN_AT.z+half,face.size.x,face.end.y-SKIN_AT.z-half),UNDER,h,"wall"])
	parts.append(["box",Rect2(SKIN_AT.x-5.6,SKIN_AT.z-SkinWall.SHEET_W*(SkinWall.CRACKED-2)-1.2,2.4,2.4),h,h+2.4,"lip"])
	parts.append(["label",Vector3(SKIN_AT.x+3.0,1.2,SKIN_AT.z-half-2.0),"the facing sheet wall · %.1f m" % h])
	parts.append(["label",Vector3(st.get_center().x,h+0.8,0.0),"the terrace"])
	var stations_out := [{"key":1,"name":"City breaks yard 2","spawn":PILOT_AT,"face":start_face,"sign":Vector3(0.0,9.0,-4.0),"parts":parts}]
	stations_out.append({"key":2,"name":"Plug","spawn":PLUG_AT+Vector3(0.0,0.0,Plug.THICK*0.5+0.9),"face":Vector2(0.0,1.0),"parts":[]})
	stations_out.append({"key":3,"name":"Chock","spawn":to_world_chock(Vector3(0.0,Chock.STRIKER.y,Chock.PLATE_AT.y-Chock.PLATE*0.5-Chock.STRIKER_GAP-0.6)),"face":Vector2(1.0,0.0),"parts":[]})
	stations_out.append({"key":4,"name":"Corbel","spawn":CORBEL_AT+Vector3(0.0,0.0,-Corbel.BAY_L-1.5),"face":Vector2(0.0,1.0),"parts":[]})
	stations_out.append({"key":5,"name":"Skin","spawn":Vector3(SKIN_AT.x+0.6,h,SKIN_AT.z+SkinWall.SHEET_W),"face":Vector2(1.0,0.0),"parts":[]})
	stations_out.append({"key":6,"name":"Upper terrace","spawn":Vector3(ut.get_center().x,Corbel.roof(),ut.get_center().y),"face":Vector2(-1.0,0.0),"parts":[]})
	stations = stations_out

static func to_world_chock(p: Vector3) -> Vector3:
	return chock_xf()*p

func _build_light() -> void:
	super._build_light()
	for n: Node in get_children():
		if n is WorldEnvironment: _environment = (n as WorldEnvironment).environment
		elif n is DirectionalLight3D: _sun = n

func _build_room() -> void:
	super._build_room()
	plug = CityBreaks2.piece("colossus_plug",21)
	plug.position = PLUG_AT
	add_child(plug)
	chock = CityBreaks2.piece("maker_chock",22)
	chock.transform = chock_xf()
	add_child(chock)
	corbel = CityBreaks2.piece("maker_corbel",23)
	corbel.position = CORBEL_AT
	add_child(corbel)
	skin = CityBreaks2.piece("maker_skin",24)
	skin.transform = skin_xf()
	add_child(skin)
	_walker_steps()
	enemies = EnemyField.new()
	enemies.study = self
	enemies.motor = motor
	enemies.lost = lost
	enemies.sound_hook = _voice
	add_child(enemies)
	hub = Breakables.new()
	hub.field = enemies
	hub.sound_hook = _voice
	add_child(hub)
	var slot := Slot.new()
	slot.field = enemies
	slot.hub = hub
	add_child(slot)
	foot_pieces = slot
	if not _no_body:
		var knobs := {"chase":1,"step":OLMEC_STEP,"chase_routes":1}
		knobs.merge(_body_knobs,true)
		enemies.spawn(HeadlessBody,_body_at,_body_face,knobs)
		enemies.spawn(InhalerHead,_body_at,_body_face,_head_knobs.duplicate())
		overlay = SightOverlay.new()
		add_child(overlay)
		_wire()
	under = Underground.attach(self)
	_cover()
	var b := stone_body()
	var top: float = b._bulk_top() if b != null else 9.24
	var wide: float = b.hh*2.0 if b != null else 6.72
	var climb: float = float(b.knobs.climb_max) if b != null else 22.4
	var fit: Array = []
	fit.append_array(Plug.fit(top,wide,climb))
	fit.append_array(Chock.fit(b.jump_gap() if b != null else 10.1))
	fit.append_array(Corbel.fit(top,wide))
	fit.append_array(SkinWall.fit(climb))
	for f: Array in fit: print("city breaks 2 fit: %s %.2f vs %.2f %s" % [f[0],float(f[1]),float(f[2]),"ok" if f[3] else "NO"])
	_break_asked()

## The walker-only steps up the skin's terrace at its south end (the Olmec
## doesn't see them: he climbs).
func _walker_steps() -> void:
	var h := SkinWall.height()
	var n := int(round(h/1.2))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = COLOURS.lip
	for i in n:
		var top := (i+1)*h/n
		var z := YARD.end.y-1.0-i*1.2
		var size := Vector3(1.6,top,1.2)
		var xf := Transform3D(Basis.IDENTITY,Vector3(YARD.position.x+0.8,top*0.5,z-0.6))
		WalkerOnly.box(self,size,xf,"WalkerStep%d" % i)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		mi.material_override = mat
		mi.transform = xf
		add_child(mi)

## The underground's ground cover on the walk tops that never break.
func _cover() -> void:
	if not Underground.on(): return
	_ground_kind = "grass"
	for a: String in preload("res://scripts/launch_args.gd").user_args():
		if a.begins_with("--ground="): _ground_kind = a.get_slice("=",1)
	if not GroundCover.KINDS.has(_ground_kind): return
	var areas: Array = []
	for r: Rect2 in _floor_rects(YARD,[chock_pier()] as Array[Rect2]): areas.append([r,0.0])
	areas.append([PLUG_COURT,0.0])
	areas.append([Rect2(far_x(),-20.0,CHOCK_FAR,40.0),0.0])
	areas.append([VAULT_COURT,0.0])
	areas.append([upper_terrace(),Corbel.roof()])
	areas.append([skin_terrace(),SkinWall.height()])
	var roof := Rect2(CORBEL_AT.x-Corbel.outer(),CORBEL_AT.z,2.0*Corbel.outer(),Corbel.BAY_L)
	areas.append([roof,Corbel.roof()])
	var i := 0
	for a: Array in areas:
		i += 1
		GroundCover.cover(self,a[0],_ground_kind,float(a[1]),40+i)

## `--broken=`: those pieces broken at the start (for stills and checks).
func _break_asked() -> void:
	for k: String in _broken:
		match k:
			"plug": plug.fall(1.0,"code")
			"chock": chock.release("code")
			"corbel": corbel.fall("code")
			"skin":
				for c in range(1,4): skin.peel(c,"code")

func _wire() -> void:
	var b := stone_body()
	var h := stone_head()
	if b == null or h == null: return
	b.make_whole(h)
	b.breaker = hub
	if overlay != null:
		if overlay.body == null: overlay.setup_body(b)
		else: overlay.body = b
		overlay.visible = _overlay_on
		overlay._layer.visible = _overlay_on

func stone_body() -> Node3D:
	if enemies == null: return null
	for e in enemies.enemies:
		if is_instance_valid(e) and e.has_method("make_whole"): return e
	return null

func stone_head() -> Node3D:
	if enemies == null: return null
	for e in enemies.enemies:
		if is_instance_valid(e) and e.has_method("mouth"): return e
	return null

## R: you, him and the pieces as they began.
func reset_all() -> void:
	for p: Node3D in [plug,chock,corbel,skin]:
		if p != null: p.reset()
	reset_body()
	respawn()

func reset_body() -> void:
	if enemies == null or _no_body: return
	enemies.reset()
	if figure != null: figure.visible = true
	_wire()

func tick(delta: float) -> void:
	super.tick(delta)
	if under != null and _sun != null: _sun.visible = false
	if camera == null: return
	var q := float(hub.quake)*0.7 if hub != null else 0.0
	var b := stone_body()
	if b != null: q = maxf(q,float(b.quake)*clampf(1.0-camera.global_position.distance_to(b.global_position)/60.0,0.0,1.0))
	if q > 0.001:
		var t := Time.get_ticks_msec()/1000.0
		camera.position += Vector3(sin(t*61.0),sin(t*53.0+1.0),sin(t*47.0+2.0))*q*0.5

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and not _name_panel.visible:
		var key := (event as InputEventKey).keycode
		if key == KEY_R:
			reset_all()
			return
		if key == KEY_B:
			reset_body()
			_say("He is back where he began",2.0)
			return
		if key == KEY_L and under != null:
			under.cycle()
			return
	super._unhandled_input(event)

func _show_toast(text: String) -> void:
	_say(text,2.0)

# --- The HUD and the sounds -----------------------------------------------------------------

func _hint_text() -> String:
	return "City breaks 2: north the plug (let him pounce at you by it) · east the chock (slam its plate from the block) · south the corbel vault (let him land at its mouth; then climb to the roof) · west the sheet wall (stand on a column's top over him) · R all back · B him back · 1-6 stations · F1 numbers"

func _show_hud() -> void:
	super._show_hud()
	if not _hud.visible or hub == null: return
	var lines := PackedStringArray([_hud.text,""])
	var b := stone_body()
	if b != null:
		lines.append("olmec  %s %.1fs · %s · chase routes %d (found %d) · %s" % [b.state,b.state_t,str(b.position.snapped(Vector3.ONE*0.1)),b.chase_plans,b.chase_found,b.route_stats()])
	lines.append("plug  %s %s · shocks %d · hits %s" % [plug.state,plug.cause,plug.shocks,str(plug.dealt)])
	lines.append("chock  %s %s · %.1f s · hits %s" % [chock.state,chock.cause,chock.fall_s,str(chock.dealt)])
	lines.append("corbel  %s %s · %.1f s · hits %s" % [corbel.state,corbel.cause,corbel.fall_s,str(corbel.dealt)])
	lines.append("skin  %s · %d down · hits %s" % [skin.state,skin.down_count(),str(skin.dealt)])
	_hud.text = "\n".join(lines)

func _voice(sound_name: StringName, at: Vector3) -> void:
	var key := String(sound_name)
	var spec: Variant = InhalerHead.VOICES.get(key,BodySpawner.VOICES.get(key,Breaks.VOICES.get(key)))
	if spec == null: return
	if not _voices.has(key): _voices[key] = EnemyYard._synth(spec)
	var player := AudioStreamPlayer3D.new()
	player.stream = _voices[key]
	player.position = at
	player.unit_size = float(BodySpawner.REACH.get(key,Breaks.REACH.get(key,30.0)))
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
