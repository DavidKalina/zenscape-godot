extends "res://studies/kit_isle.gd"
## The Olmec field (greybox, docs/design/olmec-field/handoff.md): one round
## sky isle, a broad flat field of turf FIELD_R m in radius in open sky, a
## ring of low standing stones at its rim, and the Olmec on it: the headless
## body whole, its inhaler head on its neck, hunting you as in
## studies/whole_body_chase.tscn (swat near, pounce, plant and suck).
## He is a lock target (scripts/lock_on/olmec_target.gd): Tab / R3 / middle
## mouse locks him (within 22 m), X (pad X) fires the gust shot; a hit rocks
## him back, slides him and stops him a beat; OlmecTarget.HITS hits and he
## crumbles. The kit isle's look, sky, grass and lock-on are all its own
## (studies/kit_isle.gd). The plane stands parked at the field's west side,
## nosed along its long clear run.
##   Tab / R3     lock on (again: let go)
##   X (pad X)    gust shot (the updraft's charge refills itself here)
##   R            you and the Olmec back at the start
##   ./run-olmec-field.command
##   godot --path . res://studies/olmec_field.tscn -- --no-title
##     [--earn-charge] (charge the gust shot by moving, as everywhere else)
##     [--calm] (the Olmec doesn't hunt you: he stands and listens)
##     [--olmec-at=x,z] [--body-knob=<knob>=<value>]
##     [--phase=2] (start whole, the head on: phase 2; R starts it so again)
const EnemyField = preload("res://scripts/enemies/enemy_field.gd")
const InhalerHead = preload("res://scripts/enemies/inhaler_head.gd")
const OlmecTarget = preload("res://scripts/lock_on/olmec_target.gd")
const BodySpawner = preload("res://scripts/enemies/body_spawner.gd")
const EnemyYard = preload("res://studies/enemy_yard.gd")
const DragonAirBlast = preload("res://scripts/dragon_air_blast.gd")
const FieldSky = preload("res://studies/olmec_field_sky.gd")
const Arena = preload("res://scripts/olmec_boss/arena.gd")
## The boss fight's phase 1 (docs/design/olmec-boss/spec-olmec-boss.md):
## the head alone, absorbing and puffing (scripts/olmec_boss/boss_head.gd).
const BossHead = preload("res://scripts/olmec_boss/boss_head.gd")
## Phase 2: the body that comes for it, and hunts you whole
## (scripts/olmec_boss/boss_body.gd).
const BossBody = preload("res://scripts/olmec_boss/boss_body.gd")

## Phase 1 is done: the head has taken its hits and cried out (the body's
## cue, for the trunk to hook).
signal phase_one_done(head)

## The field: its radius (m), the turf's datum, the land's depth under it.
const FIELD_R := 40.0
const FIELD_TOP := 30.0
const DEPTH := 26.0
## You start at the south end facing north; he stands mid-field side on.
const FIELD_START := Vector3(0.0,FIELD_TOP,28.0)
const OLMEC_AT := Vector2(4.0,-8.0)
## The plane parked west, nosed north along a clear run to the edge.
const PLANE_AT := Vector2(-24.0,22.0)
## The rim stones: [angle (deg, 0 east, clockwise seen from above), height
## in walker heights, breadth, depth]. None across the plane's run.
const STONES := [[-14.0,4.6,2.0,1.0],[30.0,3.2,1.7,0.9],[72.0,5.6,2.3,1.1],
	[-62.0,3.8,1.8,0.9],[-104.0,5.0,2.2,1.0],[-165.0,3.4,1.6,0.8],[128.0,4.2,2.0,1.0]]
const STONE_R := 35.5
## Shown on the field card.
const CARD := "Olmec field  ·  Tab / R3 lock on  ·  X gust shot  ·  R start again"

var enemies: Node
## The breakable arena (scripts/olmec_boss/arena.gd): its `hit_at` is the
## attacks' entry point.
var arena: Node3D
var free_charge := true
var calm := false
var _olmec_at := OLMEC_AT
var _body_knobs := {}
var _voices := {}
var _card: Label
var _gone_t := 0.0
var _down_t := -1.0
## The fight: phase 1 opens with the head alone (`--whole-olmec`: the old
## greybox, the Olmec whole); `--head-knob=<knob>=<value>` over its knobs.
var whole_olmec := false
var phase := 1
## The phase the fight starts in (and R starts it in again): 1, or 2 with
## `--phase=2` (for testing: the body set down whole, the head on).
var start_phase := 1
var phase_one_over := false
var _head_knobs := {}
## Phase 2's beat: the body comes up over the rim BODY_AFTER s after the
## head cries out, behind the head as you see it, crosses to it (breaking
## what's in its way) and puts it on; then he is whole and the lock target.
## `arrival`: "" (none yet), "climbing" (on the face), "crossing", "whole".
const BODY_AFTER := 2.2
## Its climb starts this far (m, at most) down a crag's face (CRAGS), so
## it is seen coming.
const BODY_BELOW := 4.0
## The field's sides slope in under its lip (no face to climb), so crags
## hang off the rim where he may come up: [angle (deg, as STONES), breadth,
## depth out, how far down (m)], none over the plane's run (west).
const CRAGS := [[-90.0,7.5,4.0,17.0],[-38.0,7.0,4.0,15.0],[12.0,7.5,3.6,16.0],[102.0,6.5,3.6,15.0]]
## How far past the rim a crag's outer face stands (m).
const CRAG_OUT := 1.6
signal body_arrived(body)
signal olmec_whole(body)
var arrival := ""
var _body_t := -1.0
var _spawner: Node
var _crag_lips: Array[Vector3] = []

## Hides the figure while the head holds him, and steps the enemies
## (studies/whole_body_chase.gd's).
class Slot extends Node:
	var field: Node
	func before(delta: float) -> void: field.before(delta)
	func after(delta: float, events: Dictionary) -> void: field.after(delta,events)
	func pose(figure: Node3D) -> void:
		var held := false
		for e in field.enemies:
			if is_instance_valid(e) and e.get("swallowed"): held = true
		figure.visible = not held

func _ready() -> void:
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg == "--earn-charge": free_charge = false
		elif arg == "--calm": calm = true
		elif arg.begins_with("--olmec-at="):
			var p := arg.get_slice("=",1).split(",")
			_olmec_at = Vector2(float(p[0]),float(p[1]) if p.size() > 1 else 0.0)
		elif arg == "--whole-olmec": whole_olmec = true
		elif arg.begins_with("--phase="): start_phase = clampi(int(arg.get_slice("=",1)),1,2)
		elif arg.begins_with("--head-knob="):
			var hk: String = arg.trim_prefix("--head-knob=")
			_head_knobs[hk.get_slice("=",0)] = float(hk.get_slice("=",1))
		elif arg.begins_with("--body-knob="):
			var kv: String = arg.trim_prefix("--body-knob=")
			_body_knobs[kv.get_slice("=",0)] = float(kv.get_slice("=",1))
	super._ready()
	_build_card()

func _load_pack() -> void:
	start = FIELD_START
	start_face = Vector2(0.0,-1.0)
	lost = FIELD_TOP-45.0
	_last_stood = start
	stations = []

func isle_name() -> String:
	return "olmec field"

func isle_top() -> float:
	return FIELD_TOP

func capture_look() -> Vector3:
	return Vector3(_olmec_at.x,FIELD_TOP+5.0,_olmec_at.y)

func sky_script() -> Script:
	return FieldSky

## The plane parked at the field's west side, facing north along it.
func plane_home() -> Vector4:
	return Vector4(PLANE_AT.x,_ground_y(PLANE_AT.x,PLANE_AT.y),PLANE_AT.y,0.0)

# --- The land ----------------------------------------------------------------------------

## The turf's height: a whisper of swell, level enough to land on.
static func _ground_y(x: float, z: float) -> float:
	return FIELD_TOP+0.25*sin(x*0.09+0.6)*cos(z*0.07-0.3)+0.15*sin((x+z)*0.05)

## The rim: a round field, its edge wandering a little.
static func _outline() -> Array:
	var out: Array = []
	var n := 28
	for k in range(n):
		var a := float(k)*TAU/float(n)
		var r := FIELD_R*(1.0+0.05*sin(a*3.0+0.7)+0.03*sin(a*7.0+2.1))
		out.append(Vector2(cos(a),sin(a))*r)
	return out

func _build_room() -> void:
	_build_art()
	_build_enemies()
	arena = Arena.new()
	add_child(arena)
	arena.setup(self)

func _build_art() -> void:
	art = Node3D.new()
	art.name = "Art"
	add_child(art)
	var began := Time.get_ticks_msec()
	var land := KitLand.island({"outline":_outline(),"seed":4101,"ground":func(x: float, z: float) -> float: return _ground_y(x,z),
		"top":FIELD_TOP,"depth":DEPTH,"hang":true,"tone":KitLook.turf(4101),"cell":2.5,"resample":[60.0,72,48],"collide_sides":true,"name":"OlmecField"})
	land.name = "Field"
	art.add_child(land)
	add_turf(land)
	var w := DragonAirBlast.walker_tall()
	for i in range(STONES.size()):
		var s: Array = STONES[i]
		var a := deg_to_rad(float(s[0]))
		var r := STONE_R+(1.5 if i%2 == 0 else -1.0)
		var at := Vector3(cos(a)*r,0.0,sin(a)*r)
		at.y = _ground_y(at.x,at.z)-0.2
		var b := RuinKit.Build.new(5100+i,0.6,"RimStone%d" % i)
		b.ground = 0.0
		RuinKit._sarsen(b,Transform3D.IDENTITY,Vector3(float(s[2]),float(s[1]),float(s[3]))*w,0.14)
		var stone := b.finish()
		stone.position = at
		stone.rotation.y = -a+PI*0.5+(0.25 if i%3 == 0 else -0.15)
		stone.rotation.z = 0.06 if i%2 == 0 else -0.04
		art.add_child(stone)
	_build_crags()
	print("olmec field: %d triangles, built in %d ms" % [triangles(art),Time.get_ticks_msec()-began])

## The crags off the rim (CRAGS): weathered stone hung from the turf's
## edge, its top flush with the turf, narrowing as it goes down, the outer
## face steep enough for him to climb. Their lips in `_crag_lips`.
func _build_crags() -> void:
	_crag_lips.clear()
	for i in range(CRAGS.size()):
		var c: Array = CRAGS[i]
		var a := deg_to_rad(float(c[0]))
		var n := Vector3(cos(a),0.0,sin(a))
		var rim := FIELD_R*(1.0+0.05*sin(a*3.0+0.7)+0.03*sin(a*7.0+2.1))
		var depth := float(c[2])
		var mid := n*(rim+CRAG_OUT-depth*0.5)
		var top := _ground_y(mid.x,mid.z)-0.08
		var b := RuinKit.Build.new(5200+i,0.7,"Crag%d" % i)
		b.ground = -INF
		# Upside down: from the turf down, its taper narrowing it below.
		RuinKit._sarsen(b,Transform3D(Basis(Vector3.RIGHT,PI),Vector3.ZERO),Vector3(float(c[1]),float(c[3]),depth),0.9)
		var crag := b.finish()
		crag.position = Vector3(mid.x,top,mid.z)
		crag.rotation.y = PI*0.5-a
		art.add_child(crag)
		_crag_lips.append(Vector3(n.x*(rim+CRAG_OUT-0.4),top,n.z*(rim+CRAG_OUT-0.4)))

# --- The Olmec ---------------------------------------------------------------------------

func _build_enemies() -> void:
	enemies = EnemyField.new()
	enemies.study = self
	enemies.motor = motor
	enemies.lost = lost
	enemies.sound_hook = _voice
	add_child(enemies)
	var slot := Slot.new()
	slot.field = enemies
	add_child(slot)
	foot_pieces = slot
	var at := Vector3(_olmec_at.x,_ground_y(_olmec_at.x,_olmec_at.y),_olmec_at.y)
	if not whole_olmec:
		# Phase 2 from the start: the body there, facing you, its head on
		# (it first, so the head reads its neck each frame).
		if start_phase == 2: enemies.spawn(BossBody,at,Vector2(0.0,1.0),_boss_knobs())
		# Phase 1: the head alone, facing the start.
		enemies.spawn(BossHead,at,Vector2(0.0,1.0),_head_knobs)
		_wire()
		return
	# Side on to you: he faces east.
	var face := Vector2(1.0,0.0)
	var knobs := {"chase":0.0 if calm else 1.0,"periscope":0.0}
	knobs.merge(_body_knobs,true)
	enemies.spawn(OlmecTarget,at,face,knobs)
	enemies.spawn(InhalerHead,at,face,{})
	_wire()

func olmec() -> Node3D:
	if enemies == null: return null
	for e in enemies.enemies:
		if is_instance_valid(e) and e.has_method("crumble"): return e
	return null

func olmec_head() -> Node3D:
	if enemies == null: return null
	for e in enemies.enemies:
		if is_instance_valid(e) and e.has_method("mouth"): return e
	return null

## The head on his neck.
func _wire() -> void:
	var b := olmec()
	var h := olmec_head()
	if b != null and h != null: b.make_whole(h)
	phase = 1
	phase_one_over = false
	arrival = ""
	_body_t = -1.0
	if h != null and h.has_signal("phase_done") and not h.is_connected("phase_done",_phase_one_done):
		h.connect("phase_done",_phase_one_done)
	_gone_t = 0.0
	_down_t = -1.0
	if b != null and h != null and not whole_olmec and start_phase == 2:
		# Phase 1 as if played out: the head done and silent on his neck.
		h.phase1_done = true
		h.state = "done"
		phase_one_over = true
		_body_whole(b)

## The boss body's knobs: it knows the whole field (sense, lose), hunts.
func _boss_knobs() -> Dictionary:
	var knobs := {"chase":0.0 if calm else 1.0,"relentless":1.0,"periscope":0.0,"sense":FIELD_R*2.0,"lose":8.0}
	knobs.merge(_body_knobs,true)
	return knobs

## The Olmec back as he began, whole.
func reset_olmec() -> void:
	if enemies == null: return
	if foot_lock != null and foot_lock.locked(): foot_lock.release()
	enemies.reset()
	if figure != null: figure.visible = true
	_wire()

func respawn() -> void:
	super.respawn()
	reset_olmec()
	if arena != null: arena.rebuild()

func tick(delta: float) -> void:
	# Charge for the demo: full whenever he's on foot.
	if free_charge and updraft != null and not flying: updraft.charge = 1.0
	_see_through()
	super.tick(delta)
	if _body_t >= 0.0:
		_body_t += delta
		if _body_t >= BODY_AFTER:
			_body_t = -1.0
			_bring_body()
	var b := olmec()
	if b != null and arrival == "climbing" and not (str(b.state) in ["climb","mantle"]):
		arrival = "crossing"
		# Over the rim: it has its head in its sights, and strides for it.
		if str(b.state) in ["listen","roam"]: b._home()
	if b == null and not whole_olmec: pass
	elif b == null:
		_gone_t += delta
		if _gone_t > 3.0: reset_olmec()
	else:
		if bool(b.crumbled):
			if foot_lock != null and foot_lock.target == b: foot_lock.release("down")
			if _down_t < 0.0:
				_down_t = 0.0
				_say("The Olmec crumbles!  ·  R to bring him back",4.0)
			_down_t += delta
		if camera != null:
			var q := maxf(float(b.quake),float(arena.hub.quake) if arena != null else 0.0)*clampf(1.0-camera.global_position.distance_to(b.global_position)/60.0,0.0,1.0)
			if q > 0.001:
				var t := Time.get_ticks_msec()/1000.0
				camera.position += Vector3(sin(t*61.0),sin(t*53.0+1.0),sin(t*47.0+2.0))*q*0.5
	_show_card()

## Locked on him the kit's camera (studies/kit_isle.gd `_frame`) frames a
## man-sized target; he stands ten metres: it drops lower behind the
## wanderer (TALL_POLAR over the lock's own) and its gaze leans up toward
## his shoulders (TALL_GAZE of the way from the pivot), so his head is in.
const TALL_POLAR := 0.42
const TALL_GAZE := 0.5
const TALL_EASE := 0.12

func _frame(delta: float) -> void:
	super._frame(delta)
	if foot_lock == null or foot_lock.weight <= 0.0: return
	var b := olmec()
	if b == null or foot_lock._last != b: return
	var w: float = foot_lock.weight
	if foot_lock.locked() and delta > 0.0:
		_polar = lerpf(_polar,CAM_POLAR+FOOT_LOCK_PITCH+TALL_POLAR,(1.0-exp(-delta/TALL_EASE))*w)
	var pivot := Vector3(_cam_at.x,_cam_y,_cam_at.y)
	var high: Vector3 = b.global_position+Vector3.UP*float(b.neck_h)*0.8
	var gaze := pivot.lerp(high,TALL_GAZE*w)
	if camera.global_position.distance_to(gaze) > 0.1: camera.look_at(gaze)

## The gust ball flies into his (and his head's) box and bursts at his
## chest (gust_shot's catch), rather than popping on the box's face.
func _see_through() -> void:
	if gust_shot == null or gust_shot.blast == null: return
	var skip: Array[RID] = gust_shot.blast.see_through
	for e in [olmec(),olmec_head()]:
		if e == null: continue
		var rb: StaticBody3D = e.get("body")
		if rb != null and not skip.has(rb.get_rid()): skip.append(rb.get_rid())

# --- The card and the sounds -------------------------------------------------------------

func _build_card() -> void:
	var holder := CanvasLayer.new()
	holder.name = "FieldCard"
	add_child(holder)
	_card = Label.new()
	_card.add_theme_font_size_override("font_size",18)
	_card.add_theme_color_override("font_color",Color("fbf6ea"))
	_card.add_theme_color_override("font_shadow_color",Color(0,0,0,0.75))
	_card.position = Vector2(16.0,12.0)
	holder.add_child(_card)

## The card: the field's keys, then the fight: the phase, his hits (pips)
## and the attack he's on (`attack_line`).
func _show_card() -> void:
	if _card == null: return
	_card.text = CARD+"\n"+fight_line()
	_card.visible = not flying and _capture == ""

static func _pips(n: int, most: int) -> String:
	return "●".repeat(mini(n,most))+"○".repeat(maxi(most-n,0))+" %d/%d" % [mini(n,most),most]

## The fight's card line: "Phase 1  ·  Head ●●○○○○  absorbing", the body's
## arrival, "Phase 2  ·  Olmec ●○○○○○○○  slam!" or "... down".
func fight_line() -> String:
	var b := olmec()
	var h := olmec_head()
	var lock := "  ·  locked" if foot_lock != null and foot_lock.locked() else ""
	if whole_olmec:
		if b == null: return ""
		return "Olmec  %s  %s%s" % [_pips(int(b.hits),int(b.most_hits)),"down" if bool(b.crumbled) else str(b.state),lock]
	if b != null and arrival in ["climbing","crossing"]:
		return "Phase 1 done  ·  his body %s" % ("climbs the rim" if arrival == "climbing" else "comes for his head")
	if b != null:
		return "Phase 2  ·  Olmec  %s  %s%s" % [_pips(int(b.hits),int(b.most_hits)),attack_line(),lock]
	if h != null:
		return "Phase 1  ·  Head  %s  %s%s" % [_pips(int(h.hits),int(h.knobs.phase_hits)),attack_line(),lock]
	return ""

## What he is on, in words: phase 1 the head's round and its puff, phase 2
## his move (slam, bound, swat, pounce, suck, a puff from up high) or how he
## hunts.
func attack_line() -> String:
	var b := olmec()
	var h := olmec_head()
	if b != null and arrival in ["whole",""]:
		if bool(b.crumbled): return "down"
		var mv := str(b.get("move"))
		if mv in ["","<null>"]:
			return {"chase":"hunting you","seek":"looking for you","alert":"looking for you","listen":"listening",
				"triumph":"triumphant","stagger":"rocked back","spent":"winded","home":"striding in"}.get(str(b.state),str(b.state))
		if mv.begins_with("puff "):
			# "puff volley tell": his head, up high.
			var p := mv.split(" ")
			var kind := p[1] if p.size() > 1 else ""
			var step := p[2] if p.size() > 2 else ""
			return {"absorb":"absorbs (%s)" % kind,"tell":"%s coming" % kind,"puff":"%s!" % kind}.get(step,mv)+"  ·  from up high"
		var st := str(b.state)
		# The windup is the tell (a gust shot in it stops a slam or a swat).
		if st == "windup" or (mv == "slam" and not bool(b.get("_slam_hit"))) or (mv == "swat" and float(b.state_t) < float(b.knobs.swat_windup)):
			return mv+" coming"
		return {"suck":"sucking you in"}.get(mv,mv+"!")
	if h == null: return ""
	var puff := str(h.puff)
	return {"ready":"turning to you","absorb_tell":"about to absorb","absorb":"absorbing the air",
		"puff_tell":"%s coming" % puff,"puff":"%s!" % puff,"spent":"spent (shoot it now)","stagger":"staggered",
		"cry":"cries out","done":"silent, lit"}.get(str(h.state),str(h.state))

func _phase_one_done(h: Node3D) -> void:
	phase_one_over = true
	_say("The head cries out across the field...",4.0)
	phase_one_done.emit(h)
	_body_t = 0.0

## The body up the rim, behind the head as he sees it (the cliff spawn's
## fit, scripts/enemies/body_spawner.gd), climbing; its head calls it over.
func _bring_body() -> void:
	var h := olmec_head()
	if h == null or olmec() != null: return
	if _spawner == null:
		_spawner = BodySpawner.new()
		add_child(_spawner)
		_spawner.setup(self,enemies)
	var away := Vector2(h.position.x-motor.feet.x,h.position.z-motor.feet.z)
	away = away.normalized() if away.length() > 0.5 else Vector2(0.0,-1.0)
	var ways: Array = []
	for lip: Vector3 in _crag_lips:
		var n := Vector2(lip.x,lip.z).normalized()
		ways.append([n.dot(away),lip,n])
	ways.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
	for w: Array in ways:
		var fitted: Array = _spawner.fit(w[1],w[2])
		if fitted.is_empty(): continue
		# It knows where its head is across the whole field (sense, lose),
		# so the beat is short: over the rim, straight for it.
		var b: Node3D = enemies.add(BossBody,fitted[0],-(fitted[1] as Vector2),_boss_knobs())
		# Ahead of its head in the field, so the head reads its neck this frame.
		enemies.enemies.erase(b)
		enemies.enemies.insert(maxi(enemies.enemies.find(h),0),b)
		b.cling(fitted[0],fitted[1],_spawner.face_below(fitted[0],fitted[1],BODY_BELOW))
		b.body.force_update_transform()
		# Not a target till the head is on.
		b.remove_from_group(OlmecTarget.GROUP)
		b.reunited.connect(_body_whole)
		enemies.sound(&"body_rumble",b.position)
		arrival = "climbing"
		_say("Something climbs the rim behind the head...",4.0)
		print("olmec field: body up the rim at (%.1f, %.1f), %.1f m down the face" % [b.position.x,b.position.z,float(fitted[0].y)-b.position.y])
		body_arrived.emit(b)
		return
	push_warning("olmec field: no rim face fits the body (%s)" % _spawner.fit_why)

## The head on: phase 2. He is the lock target now (a lock on the head
## moves to him).
func _body_whole(b: Node3D) -> void:
	phase = 2
	arrival = "whole"
	var h := olmec_head()
	if h != null: h.remove_from_group(BossHead.GROUP)
	b.add_to_group(OlmecTarget.GROUP)
	if b.has_method("phase_two"): b.phase_two()
	if foot_lock != null and foot_lock.target == h:
		foot_lock.target = b
		foot_lock._last = b
	_say("The Olmec stands whole!",4.0)
	print("olmec field: whole at (%.1f, %.1f), phase 2" % [b.position.x,b.position.z])
	olmec_whole.emit(b)

func _voice(sound_name: StringName, at: Vector3) -> void:
	var key := String(sound_name)
	var spec: Variant = InhalerHead.VOICES.get(key,BodySpawner.VOICES.get(key))
	if spec == null: return
	if not _voices.has(key): _voices[key] = EnemyYard._synth(spec)
	var player := AudioStreamPlayer3D.new()
	player.stream = _voices[key]
	player.position = at
	player.unit_size = float(BodySpawner.REACH.get(key,14.0))
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
