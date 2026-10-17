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
##     [--tilt-now] (in phase 2, he makes for the rim and tilts the field
##       at once: the set piece, `tilt_begin`)
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
## The tilt set piece (spec "The tilt"): the field tipped steeply toward him
## braced on its rim, the steep mode of the Olmec's tilt.
const OlmecTilt = preload("res://scripts/enemies/olmec_tilt.gd")
const Dust = preload("res://scripts/enemies/body_dust.gd")
## His air arcs up the tipped field (scripts/olmec_boss/air_arcs.gd).
const AirArcs = preload("res://scripts/olmec_boss/air_arcs.gd")

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

## The tilt: braced on the rim, he tips the whole field (Art: the turf, its
## grass, the rim stones and crags; the arena and the parked plane ride it)
## TILT_DEG toward him about its middle, on the tilt's steep spring. Too
## steep to stand on (the wanderer's slide_auto held at TILT_SLIDE_AUTO
## while it is over TILT_SURF deg): he surfs down it, steering with the
## stick. Braced, he sends air arcs up the slope (`tilt_arcs`); gust shots
## into him (BossBody.TILT_BREAK) break his brace (`tilt_broken`), and he
## lets go and the field eases back level; TILT_HOLD s braced is only the
## fallback. TILT_RIM: how far in from the lip he braces; TILT_KEEP_OFF:
## never within this of the plane's run (west).
const TILT_DEG := 27.0
const TILT_HOLD := 30.0
const TILT_SLIDE_AUTO := 16.0
## On the tipped field the stick pushes him across the fall line (the
## motor's carve off: SLIDE_STEER m/s² at full stick), so a sidestep of an
## arc is quick, and his slide is held to TILT_SLIDE_TOP m/s so the arcs
## come at a pace he can read.
const TILT_SLIDE_TOP := 8.5
## And on top of the motor's own steer, more across the fall line (m/s² at
## full stick), up to TILT_SIDE_TOP m/s across: a dodge of an arc is a
## clear step aside.
const TILT_STEER := 11.0
const TILT_SIDE_TOP := 6.5
const TILT_SIDE_EASE := 5.0
## The slide's lane: from where he stands at the slam down to the low rim,
## across from his line to the Olmec's and LANE_W m past either. Standing
## pieces and rubble in it are shoved: they slide off down the slope,
## out to the lane's sides, no longer in his way. The spot is picked for
## the clearest lane among the far ones (LANE_COST m of slide a big piece
## in it costs, half that another).
const LANE_W := 6.0
const LANE_COST := 4.0
const SHOVE_PULL := 1.15
const SHOVE_KICK := 2.5
const SHOVE_OUT := 3.0
## The play camera while tipped and locked on him: raised (rad off its
## polar) and its gaze halfway between the wanderer and him, so both are
## in the frame.
const TILT_LOCK_UP := 0.32
const TILT_LOCK_GAZE := 0.5
const TILT_SURF := 12.0
const TILT_RIM := 3.0
const TILT_KEEP_OFF := 8.0
## Loose stone shaken out by the slam that slides down the tipped field:
## how many, their sizes (m), their slide (a share of the pull down a
## slope; m/s² of friction), and how flat the field must be to hold them.
const SCREE_N := 14
const SCREE_SIZE := Vector2(0.5,1.5)
const SCREE_PULL := 0.75
const SCREE_GRIP := 1.2
const SCREE_HOLD_DEG := 9.0
## The camera while the field is tipped: raised (rad off its polar, by the
## tip's share) and turned toward him at the low edge.
const TILT_CAM_UP := 0.42
const TILT_CAM_TURN := 1.4
const TILT_CAM_SIDE := 0.5
var _tilt_cam_side := 0.0
var tilt: Node = null
var tilt_now := false
var _tilt_now_done := false
## "" none, "tipping" (braced, held), "easing" (let go, coming back level).
var tilt_phase := ""
var tilt_t := 0.0
var tilt_way := Vector2.ZERO
var _tilt_body: Node3D = null
var _motor_knobs := {}
var _plane_rest := Transform3D.IDENTITY
var _plane_park_rest := Transform3D.IDENTITY
var _plane_tipped := false
var _scree: Array = []
var _stick := Vector2.ZERO
var _shoved: Array = []
var arcs: Node3D = null
## The lock on him the tilt took (let go when it ends, unless he locked it).
var _tilt_locked := false
## Counted, for checks.
var tilts_begun := 0
var tilts_broken := 0
var tilt_most_deg := 0.0

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
		elif arg == "--tilt-now": tilt_now = true
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
	tilt = OlmecTilt.new()
	tilt.field = enemies
	tilt.study = self
	add_child(tilt)
	arcs = AirArcs.new()
	arcs.study = self
	arcs.motor = motor
	add_child(arcs)

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
	tilt_reset()
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
	_tilt_tick(delta)
	_tilt_steer(delta)
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

## The stick this frame (world x, z), for the tilt's steer.
func _want(delta: float) -> Vector2:
	_stick = super._want(delta)
	return _stick

## Sliding down the tipped field, the stick across the fall line pushes him
## aside harder than the motor's own steer (TILT_STEER).
func _tilt_steer(delta: float) -> void:
	if tilt == null or tilt_phase == "" or delta <= 0.0 or str(motor.move) != "slide": return
	if float(tilt.steep_deg()) <= TILT_SURF: return
	var w3: Vector3 = tilt.steep_turn().basis*Vector3(tilt_way.x,0.0,tilt_way.y)
	var down := Vector2(w3.x,w3.z).normalized()
	var side := Vector2(-down.y,down.x)
	var across := clampf((scripted_want() if scripted else _stick).dot(side),-1.0,1.0)
	var v: Vector3 = motor.velocity
	var lat := Vector2(v.x,v.z).dot(side)
	if absf(across) < 0.05:
		# Let go: the drift across eases off (TILT_SIDE_EASE m/s²).
		var eased := move_toward(lat,0.0,TILT_SIDE_EASE*delta)
		var dv0 := side*(eased-lat)
		motor.velocity = Vector3(v.x+dv0.x,v.y,v.z+dv0.y)
		return
	var want_lat := clampf(lat+across*TILT_STEER*delta,-TILT_SIDE_TOP,TILT_SIDE_TOP)
	if absf(want_lat) < absf(lat) and signf(lat) == signf(across): return
	var dv := side*(want_lat-lat)
	motor.velocity = Vector3(v.x+dv.x,v.y,v.z+dv.y)

func scripted_want() -> Vector2:
	return script_want

## Locked on him the kit's camera (studies/kit_isle.gd `_frame`) frames a
## man-sized target; he stands ten metres: it drops lower behind the
## wanderer (TALL_POLAR over the lock's own) and its gaze leans up toward
## his shoulders (TALL_GAZE of the way from the pivot), so his head is in.
const TALL_POLAR := 0.42
const TALL_GAZE := 0.5
const TALL_EASE := 0.12

func _frame(delta: float) -> void:
	_tilt_frame(delta)
	super._frame(delta)
	if foot_lock == null or foot_lock.weight <= 0.0: return
	var b := olmec()
	if b == null or foot_lock._last != b: return
	var w: float = foot_lock.weight
	var k := clampf(float(tilt.steep_deg())/TILT_DEG,0.0,1.0) if tilt != null else 0.0
	if k > 0.01:
		# The field tipped: raised over the slope, the gaze between him (the
		# wanderer) and the Olmec at its foot, so both are in the frame.
		if foot_lock.locked() and delta > 0.0:
			_polar = lerpf(_polar,CAM_POLAR-TILT_LOCK_UP*k,(1.0-exp(-delta/TALL_EASE))*w)
		var eye := camera.global_position
		var to_me := (Vector3(_cam_at.x,_cam_y,_cam_at.y)-eye).normalized()
		var to_him: Vector3 = (b.global_position+Vector3.UP*float(b.neck_h)*0.5-eye).normalized()
		var look := to_me.slerp(to_him,TILT_LOCK_GAZE*w)
		camera.look_at(eye+look*10.0)
		return
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
		if mv == "tilt":
			return {"tilt_run":"makes for the rim","windup":"bounds for the rim","leap":"bounds for the rim",
				"land":"on the rim","tilt_slam":"slams the rim","tilt_brace":"tilts the field!  ·  brace %s" % _pips(int(b.get("brace_hits")),int(BossBody.TILT_BREAK)),
					"tilt_let":"lets go"}.get(st,"tilt")
		if mv == "charge":
			return {"charge_tell":"charge coming","charge":"charge!","charge_skid":"overran  ·  shoot him now",
				"charge_stagger":"stopped short"}.get(st,"charge")
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

# --- The tilt ----------------------------------------------------------------------------

## Where he braces for the tilt, from `from`: a spot TILT_RIM m in from the
## lip, on the turf, off the plane's run and the rim stones, the far side of
## the field from the wanderer if it can (the longest slide), not too far
## from him. INF none.
func tilt_spot(from: Vector3) -> Vector3:
	var run: Rect2 = Arena.RUN.grow(TILT_KEEP_OFF)
	var best := Vector3.INF
	var best_score := -INF
	var me := Vector2(motor.feet.x,motor.feet.z)
	for k in range(36):
		var a := float(k)*TAU/36.0
		var rim := FIELD_R*(1.0+0.05*sin(a*3.0+0.7)+0.03*sin(a*7.0+2.1))
		var p := Vector2(cos(a),sin(a))*(rim-TILT_RIM)
		if run.has_point(p) or p.x < -12.0: continue
		var clear := true
		for i in range(STONES.size()):
			var sa := deg_to_rad(float(STONES[i][0]))
			var sr := STONE_R+(1.5 if i%2 == 0 else -1.0)
			if p.distance_to(Vector2(cos(sa),sin(sa))*sr) < 5.0: clear = false
		if not clear: continue
		var score := p.distance_to(me)-0.35*p.distance_to(Vector2(from.x,from.z))-_lane_cost(_lane(me,p))
		if score > best_score:
			best_score = score
			best = Vector3(p.x,_ground_y(p.x,p.y),p.y)
	return best

## The slide's lane from `me` down to the rim spot `spot` (flat, rest
## frame): the fall line `u` (out toward the spot), across it `l`, and its
## spans along (from behind him to past the lip) and across (both lines,
## LANE_W past either).
func _lane(me: Vector2, spot: Vector2) -> Dictionary:
	var u := spot.normalized()
	var l := Vector2(-u.y,u.x)
	return {"u":u,"l":l,"a0":me.dot(u)-4.0,"a1":FIELD_R+4.0,
		"l0":minf(me.dot(l),spot.dot(l))-LANE_W,"l1":maxf(me.dot(l),spot.dot(l))+LANE_W}

## Whether the flat points `pts` (rest frame) reach into `lane`.
static func _in_lane(lane: Dictionary, pts: Array) -> bool:
	var a := Vector2(INF,-INF)
	var c := Vector2(INF,-INF)
	for p: Vector2 in pts:
		var pa := p.dot(lane.u)
		var pl := p.dot(lane.l)
		a = Vector2(minf(a.x,pa),maxf(a.y,pa))
		c = Vector2(minf(c.x,pl),maxf(c.y,pl))
	return a.y > float(lane.a0) and a.x < float(lane.a1) and c.y > float(lane.l0) and c.x < float(lane.l1)

## What stands in `lane`: big pieces cost LANE_COST, the rest half.
func _lane_cost(lane: Dictionary) -> float:
	if arena == null or arena.kit_breaks == null: return 0.0
	var cost := 0.0
	for t: Dictionary in arena.kit_breaks.targets:
		if not t.alive or not is_instance_valid(t.node): continue
		var node: Node3D = t.node
		var box: AABB = t.box
		var pts: Array = []
		for k in range(4):
			var w: Vector3 = node.transform*(box.position+Vector3(box.size.x*float(k%2),0.0,box.size.z*float(k/2)))
			pts.append(Vector2(w.x,w.z))
		if _in_lane(lane,pts): cost += LANE_COST*(1.0 if node.has_meta("arena_big") else 0.5)
	return cost

## The arena's pieces and rubble in the lane from the wanderer down to
## `at` shoved: their colliders off, set sliding off down the slope (and
## out to the lane's nearer side), their breaks done with.
func _shove_lane(at: Vector3) -> void:
	_shoved.clear()
	if arena == null: return
	var lane := _lane(Vector2(motor.feet.x,motor.feet.z),Vector2(at.x,at.z))
	var mid := (float(lane.l0)+float(lane.l1))*0.5
	var cands: Array = []
	for holder: Node in [arena.pieces,arena.kit_breaks]:
		if holder == null: continue
		for c: Node in holder.get_children():
			if c is CPUParticles3D or c is GPUParticles3D or not (c is Node3D) or not (c as Node3D).visible: continue
			# A heap's holder: its blocks one by one.
			if c.name.begins_with("Rubble"):
				for r: Node in c.get_children():
					if r is Node3D and (r as Node3D).visible: cands.append(r)
				continue
			cands.append(c)
	var inv: Transform3D = arena.global_transform.affine_inverse()
	for node: Node3D in cands:
		var pts: Array = []
		var any := false
		for v: Node in node.find_children("*","VisualInstance3D",true,false):
			var vi := v as VisualInstance3D
			var box := vi.get_aabb()
			if box.size.length() < 0.01: continue
			any = true
			var xf: Transform3D = inv*vi.global_transform
			for k in range(8):
				var w: Vector3 = xf*(box.position+box.size*Vector3(float(k%2),float((k/2)%2),float(k/4)))
				pts.append(Vector2(w.x,w.z))
		if node is VisualInstance3D:
			var box2 := (node as VisualInstance3D).get_aabb()
			var xf2: Transform3D = inv*node.global_transform
			for k in range(8):
				var w2: Vector3 = xf2*(box2.position+box2.size*Vector3(float(k%2),float((k/2)%2),float(k/4)))
				pts.append(Vector2(w2.x,w2.z))
			any = true
		if not any or not _in_lane(lane,pts): continue
		var layers := {}
		var bodies: Array = node.find_children("*","CollisionObject3D",true,false)
		if node is CollisionObject3D: bodies.append(node)
		for bo: Node in bodies:
			var co := bo as CollisionObject3D
			layers[co] = [co.collision_layer,co.collision_mask]
			co.collision_layer = 0
			co.collision_mask = 0
			if co is RigidBody3D: (co as RigidBody3D).freeze = true
		for t: Dictionary in arena.kit_breaks.targets:
			if t.node == node: t.alive = false
		var centre := Vector2.ZERO
		for p: Vector2 in pts: centre += p
		centre /= float(pts.size())
		var out_side := 1.0 if centre.dot(lane.l) >= mid else -1.0
		var u: Vector2 = lane.u
		var l: Vector2 = lane.l
		_shoved.append({"node":node,"v":u*SHOVE_KICK+l*out_side*SHOVE_OUT,"y":node.position.y-_ground_y(node.position.x,node.position.z),
			"off":false,"vy":0.0,"t":0.0,"spin":Vector3(l.x,0.0,l.y)*out_side,"wait":clampf((float(lane.a1)-centre.dot(u))*0.004,0.0,0.25)})
	if not _shoved.is_empty(): print("olmec field: %d piece(s) in the slide's lane shoved off down the slope" % _shoved.size())

## The shoved pieces down the tipped field (the arena's frame is the rest
## frame), over the lip and gone.
func _slide_shoved(delta: float, deg: float) -> void:
	if _shoved.is_empty(): return
	var keep: Array = []
	for c: Dictionary in _shoved:
		if not is_instance_valid(c.node): continue
		var node: Node3D = c.node
		c.t = float(c.t)+delta
		if float(c.t) < float(c.wait):
			keep.append(c)
			continue
		var p := node.position
		if bool(c.off):
			c.vy = float(c.vy)-9.8*delta
			p += Vector3(c.v.x,float(c.vy),c.v.y)*delta
			node.position = p
			if p.y < FIELD_TOP-30.0:
				node.visible = false
				node.process_mode = Node.PROCESS_MODE_DISABLED
				continue
			keep.append(c)
			continue
		var v: Vector2 = c.v
		if deg > SCREE_HOLD_DEG: v += tilt_way*9.8*sin(deg_to_rad(deg))*SHOVE_PULL*delta
		var pace := move_toward(v.length(),0.0,0.6*delta)
		v = v.normalized()*pace if v.length() > 1e-4 else Vector2.ZERO
		c.v = v
		p.x += v.x*delta
		p.z += v.y*delta
		p.y = _ground_y(p.x,p.z)+float(c.y)
		node.position = p
		if pace > 0.1: node.rotate(c.spin as Vector3,pace*delta*0.05)
		var a := atan2(p.z,p.x)
		var rim := FIELD_R*(1.0+0.05*sin(a*3.0+0.7)+0.03*sin(a*7.0+2.1))
		if Vector2(p.x,p.z).length() > rim-1.0:
			c.off = true
			c.vy = -pace*sin(deg_to_rad(deg))
		if pace > 0.5 and randf() < delta*2.0: Dust.puff(enemies,arena.global_transform*p,2.0,Vector3.UP)
		keep.append(c)
	_shoved = keep

## His air arcs: a volley of `n` from his braced feet up the slope, the
## middle one at the wanderer (rest frame). Not once the wanderer is within
## ARC_NEAR m of him (too near to dodge: there it's his to shoot). Whether
## it went.
const ARC_NEAR := 13.0
func tilt_arcs(b: Node3D, n: int) -> bool:
	if arcs == null or tilt_phase != "tipping": return false
	var turn: Transform3D = tilt.steep_turn()
	var from: Vector3 = b.get("tilt_rest") if b.get("tilt_rest") != Vector3.INF else turn.affine_inverse()*b.global_position
	var me: Vector3 = turn.affine_inverse()*motor.feet
	if Vector2(me.x-from.x,me.z-from.z).length() < ARC_NEAR: return false
	arcs.volley(from,me,n)
	return true

## Shot enough braced: his brace breaks, he lets go.
func tilt_broken(b: Node3D) -> void:
	if tilt_phase != "tipping" or b != _tilt_body: return
	tilts_broken += 1
	_say("His brace breaks!",2.5)
	print("olmec field: brace broken after %.1f s" % tilt_t)
	_tilt_release()

## His fists down on the rim at `at`: the field tips toward him.
func tilt_begin(b: Node3D, at: Vector3) -> void:
	if tilt == null or art == null: return
	tilt_way = Vector2(at.x,at.z).normalized()
	_tilt_body = b
	tilt_phase = "tipping"
	tilt_t = 0.0
	tilts_begun += 1
	var ride: Array = [arena]
	if get("_park_body") != null: ride.append(get("_park_body"))
	tilt.steep(art,Vector3(0.0,FIELD_TOP,0.0),tilt_way,TILT_DEG,ride)
	_plane_tipped = parked and plane_figure != null
	if _plane_tipped:
		_plane_rest = plane_figure.transform
		_plane_park_rest = plane_figure.get("_parked_at")
	_motor_knobs = {"slide_auto":motor.slide_auto,"carve":motor.carve,"slide_top":motor.slide_top}
	_shake_scree(at)
	_shove_lane(b.global_position)
	_tilt_lock(b)
	if arena != null and arena.hub != null: arena.hub.quake = maxf(float(arena.hub.quake),1.0)
	_say("He slams the rim: the field tips toward him!",3.0)
	print("olmec field: tilt %d from (%.1f, %.1f), the field tips %.0f deg toward him" % [tilts_begun,at.x,at.z,TILT_DEG])

## The rest-frame point `p` where the tipped field has it now.
func tipped(p: Vector3) -> Vector3:
	return tilt.steep_turn()*p if tilt != null else p

## The tilt's frame: the timer, the tip stepped, what rides it posed, the
## wanderer too steep to stand, the scree sliding.
func _tilt_tick(delta: float) -> void:
	if tilt == null: return
	var b := olmec()
	if tilt_now and not _tilt_now_done and b != null and arrival == "whole" and phase == 2 and b.has_method("tilt_now") and str(b.state) in ["chase","listen","seek","alert","land"]:
		_tilt_now_done = bool(b.tilt_now())
	if tilt_phase == "tipping":
		tilt_t += delta
		# Let go: his time braced up, or he is down or gone off his brace.
		var off := b == null or b != _tilt_body or bool(b.crumbled) or not (str(b.state) == "tilt_brace")
		if tilt_t >= TILT_HOLD or (off and tilt_t > 0.2):
			_tilt_release()
		elif _tilt_locked and foot_lock != null and not foot_lock.locked() and foot_lock.let_go_why != "pressed" and foot_lock_allowed():
			# Out of reach or behind a column: back on him while tipped.
			_tilt_lock(b)
	tilt.step(delta,[])
	if arcs != null: arcs.step(delta)
	var deg: float = tilt.steep_deg()
	tilt_most_deg = maxf(tilt_most_deg,deg)
	var turn: Transform3D = tilt.steep_turn()
	if _plane_tipped and plane_figure != null:
		if parked:
			plane_figure.set("_parked_at",turn*_plane_park_rest)
			plane_figure.transform = turn*_plane_rest
		else: _plane_tipped = false
	if _motor_knobs.has("slide_auto"):
		var steep := deg > TILT_SURF
		motor.slide_auto = TILT_SLIDE_AUTO if steep else float(_motor_knobs.slide_auto)
		motor.carve = false if steep else bool(_motor_knobs.carve)
		motor.slide_top = TILT_SLIDE_TOP if steep else float(_motor_knobs.slide_top)
	_slide_scree(delta,deg,turn)
	_slide_shoved(delta,deg)
	if tilt_phase == "easing" and tilt.steep_tip == null:
		tilt_phase = ""
		_put_plane_back()
		_motor_back()
		print("olmec field: the field is level again (most %.1f deg)" % tilt_most_deg)

## The wanderer's motor as it was before the tilt.
func _motor_back() -> void:
	if _motor_knobs.has("slide_auto"): motor.slide_auto = float(_motor_knobs.slide_auto)
	if _motor_knobs.has("carve"): motor.carve = bool(_motor_knobs.carve)
	if _motor_knobs.has("slide_top"): motor.slide_top = float(_motor_knobs.slide_top)
	_motor_knobs.clear()

## Locked on him while the field is tipped, so the camera frames him at the
## bottom of the slope (and the gust shot goes at him).
func _tilt_lock(b: Node3D) -> void:
	if b == null or not foot_lock_allowed(): return
	if foot_lock == null:
		foot_lock = FootLock.new()
		foot_lock.name = "FootLock"
		foot_lock.sight_mask = 0xFFFFFFFF & ~PARKED_LAYER
		add_child(foot_lock)
	if foot_lock.locked() and foot_lock.target == b: return
	if not foot_lock.locked(): _tilt_locked = true
	foot_lock.target = b
	foot_lock._last = b
	foot_lock._lost = 0.0
	foot_lock.let_go_why = ""

func _tilt_release() -> void:
	tilt_phase = "easing"
	tilt.steep_release()
	if arcs != null: arcs.fade_all()
	if _tilt_locked and foot_lock != null and foot_lock.locked(): foot_lock.release("tilt over")
	_tilt_locked = false
	if _tilt_body != null and is_instance_valid(_tilt_body) and _tilt_body.has_method("tilt_let_go"): _tilt_body.tilt_let_go()
	_say("He lets go: the field eases back",2.5)
	print("olmec field: let go after %.1f s braced" % tilt_t)

func _put_plane_back() -> void:
	if _plane_tipped and plane_figure != null and parked:
		plane_figure.set("_parked_at",_plane_park_rest)
		plane_figure.transform = _plane_rest
	_plane_tipped = false

## All level at once (R).
func tilt_reset() -> void:
	if tilt == null: return
	tilt.settle_all()
	_put_plane_back()
	_motor_back()
	if arcs != null: arcs.clear()
	_shoved.clear()
	_tilt_locked = false
	tilt_phase = ""
	_tilt_body = null
	_tilt_now_done = false
	for c: Dictionary in _scree:
		if is_instance_valid(c.node): (c.node as Node3D).queue_free()
	_scree.clear()

## Loose stone shaken out over the field by the slam (rest frame), to slide.
func _shake_scree(at: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9100+tilts_begun
	for i in range(SCREE_N):
		var p := Vector2.ZERO
		for _try in range(8):
			p = Vector2(rng.randf_range(-1.0,1.0),rng.randf_range(-1.0,1.0))*FIELD_R*0.85
			if p.length() < FIELD_R*0.85 and not Arena.RUN.has_point(p) and p.distance_to(Vector2(at.x,at.z)) > 8.0: break
		var size := rng.randf_range(SCREE_SIZE.x,SCREE_SIZE.y)
		var bld := RuinKit.Build.new(9200+i+tilts_begun*31,0.5,"Scree%d" % i)
		bld.ground = 0.0
		RuinKit._sarsen(bld,Transform3D.IDENTITY,Vector3(size,size*rng.randf_range(0.5,0.9),size*rng.randf_range(0.7,1.1)),0.45)
		var node := bld.finish()
		# Its colliders off: it is loose stone to see slide, not ground.
		for body: Node in node.find_children("*","CollisionObject3D",true,false):
			(body as CollisionObject3D).collision_layer = 0
			(body as CollisionObject3D).collision_mask = 0
		add_child(node)
		var q := Vector3(p.x,_ground_y(p.x,p.y)-0.15,p.y)
		var spin := Basis(Vector3.UP,rng.randf_range(-PI,PI))
		_scree.append({"node":node,"q":q,"v":Vector2.ZERO,"basis":spin,"roll":rng.randf_range(0.6,1.4),"size":size,"off":false,"vy":0.0,"t":0.0,"side":rng.randf_range(-0.2,0.2)})
		node.global_transform = Transform3D(spin,tipped(q))
		Dust.puff(enemies,tipped(q),size*1.6,Vector3.UP)

## The scree down the tipped field (in its rest frame along the fall),
## tumbling as it goes; over the lip it drops away; level, it stays.
func _slide_scree(delta: float, deg: float, turn: Transform3D) -> void:
	if _scree.is_empty(): return
	var g := 9.8
	var keep: Array = []
	for c: Dictionary in _scree:
		var node: Node3D = c.node
		if not is_instance_valid(node): continue
		if bool(c.off):
			c.t = float(c.t)+delta
			c.vy = float(c.vy)-g*delta
			node.global_position += Vector3(float(c.v.x),float(c.vy),float(c.v.y))*delta
			node.global_basis = node.global_basis.rotated(Vector3(c.v.y,0.0,-c.v.x).normalized() if (c.v as Vector2).length() > 0.1 else Vector3.RIGHT,delta*2.0)
			if float(c.t) > 4.0:
				node.queue_free()
				continue
			keep.append(c)
			continue
		var v: Vector2 = c.v
		var pull := g*sin(deg_to_rad(deg))*SCREE_PULL
		var down := tilt_way.rotated(float(c.side))
		if deg > SCREE_HOLD_DEG: v += down*pull*delta
		var pace := move_toward(v.length(),0.0,SCREE_GRIP*delta)
		v = v.normalized()*pace if v.length() > 1e-4 else Vector2.ZERO
		c.v = v
		var q: Vector3 = c.q
		q.x += v.x*delta
		q.z += v.y*delta
		var r := Vector2(q.x,q.z).length()
		var a := atan2(q.z,q.x)
		var rim := FIELD_R*(1.0+0.05*sin(a*3.0+0.7)+0.03*sin(a*7.0+2.1))
		q.y = _ground_y(q.x,q.z)-0.15
		c.q = q
		# Rolled over as it goes (about the axis across its way).
		if pace > 0.05:
			c.basis = (c.basis as Basis).rotated(Vector3(v.y,0.0,-v.x).normalized(),-pace*delta/maxf(float(c.size)*0.5,0.2)*float(c.roll))
			if randf() < delta*pace*0.25: Dust.puff(enemies,turn*q,float(c.size)*1.2,Vector3.UP)
		node.global_transform = Transform3D(turn.basis*(c.basis as Basis),turn*q)
		if r > rim+0.6:
			c.off = true
			var w3 := turn.basis*Vector3(v.x,0.0,v.y)
			c.v = Vector2(w3.x,w3.z)
			c.vy = w3.y
		keep.append(c)
	_scree = keep

## While the field is tipped the camera rises and turns a little toward him
## braced at the low edge, so the tip reads (not while locked: the lock frames him).
func _tilt_frame(delta: float) -> void:
	if tilt == null or delta <= 0.0: return
	var k := clampf(float(tilt.steep_deg())/TILT_DEG,0.0,1.0)
	if k <= 0.01: return
	if foot_lock != null and foot_lock.locked(): return
	_polar = lerpf(_polar,CAM_POLAR-TILT_CAM_UP*k,1.0-exp(-delta*2.5))
	var b := olmec()
	if b != null:
		var d := b.global_position-motor.feet
		if Vector2(d.x,d.z).length() > 2.0:
			# Down the fall line but a little across it (TILT_CAM_SIDE, the
			# side it already looks from), so the tipped rim and the
			# horizon cross the frame aslant.
			var at := atan2(-d.x,-d.z)
			var side := TILT_CAM_SIDE*(1.0 if angle_difference(at,_yaw) <= 0.0 else -1.0)
			if _tilt_cam_side == 0.0: _tilt_cam_side = side
			_yaw = lerp_angle(_yaw,at+_tilt_cam_side,(1.0-exp(-delta*TILT_CAM_TURN))*k)
	if tilt_phase == "": _tilt_cam_side = 0.0
