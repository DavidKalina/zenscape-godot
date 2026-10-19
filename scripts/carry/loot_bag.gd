extends Node3D
## The wanderer's loot bag (docs/design/bag/spec-bag.md): a tattered cloth
## sack worn on his back, filled with loot. It sits alongside the hand-carry
## (scripts/carry/carry_host.gd), on a study with the character study's
## `motor`, `body`, `figure` and a `loot` list ({id, kind, kg, spot, node,
## measures}, studies/bag_study.gd).
##
## - `walk_carry` (E, pad B; scripts/pad.gd) by a loot piece puts it in:
##   he dips to it, it hops over his shoulder into the bag's mouth, and the
##   sack swells (its belly's radius with the root of the kg) with a gulp;
## - its kg scale his walk, run, jump and turn on one continuous curve
##   (FEEL: free up to FREE_KG, the row's value at CAP, eased between), and
##   moves drop off past each of BARS (the motor's `wall_on`, `ledge_on`,
##   `sail_on`, `rope_on`); a barred move tried, he balks (the motor's
##   `refused`: a lurch and a shake of the head, as carry_host's);
## - past CAP it takes no more: the piece stays where it lies, and he
##   balks, a low "uh-uh" sounds and a line says so;
## - a readout on screen: the kg, the cap, a bar, the barred moves;
## - `walk_bag` (F, pad down) sets it down (it slides off his back and
##   drops behind him) and, by it, shoulders it again; worn it fills only to
##   WEAR_KG, set down to CAP (E by it with a piece in reach). Past WEAR_KG
##   it won't go on his back: F by it takes it by the neck and he drags it,
##   slow, on a short rope (no jump, no climbing); it scuffs along and
##   catches on rocks and lips, holding him back till he pulls another way.
##   Set down or dragged it is a rigid body (`loose`) on carry_host's
##   TREASURE_LAYER, which his walk never sees.
##
## All procedural (the sack's mesh, its sway, the dip, the balk), greybox.
const Weights = preload("res://scripts/carry/carry_weights.gd")
const CarryHost = preload("res://scripts/carry/carry_host.gd")

## The most the bag holds (kg), and the most he wears (more and he drags it).
const CAP := 24.0
const WEAR_KG := 18.0
## Up to this many kg he doesn't feel it.
const FREE_KG := 2.0
## At CAP, each pace times the empty one (eased in from FREE_KG, EASE the
## curve's power: over 1 the first kg cost little, the last the most).
const FEEL := {"walk":0.6,"run":0.45,"jump":0.4,"turn":0.55}
const EASE := 1.2
## The moves dropped past each weight (kg), in order.
const BARS := [["wall",5.0],["ledge",9.0],["sail",13.0],["rope",17.0]]

## Reach (m across from his feet to a piece's foot, times his size, past
## its radius; and up or down).
const REACH := 0.9
const REACH_UP := 0.8
## The putting in: its length (s), his paces meanwhile (times), the dip of
## his chest at its middle (degrees), the hop's height over the bag (m,
## times size).
const STOW_TIME := 0.45
const STOW_PACE := 0.15
const STOW_BEND := 32.0
const STOW_HOP := 0.6
## The sack: its belly's radius empty and its growth with the root of the
## kg (m, times size); empty it hangs flat (DEPTH_EMPTY of its round depth).
const SACK_R := 0.12
const SACK_R_KG := 0.045
const DEPTH_EMPTY := 0.35
## Where it rides: its middle this far behind the chest bone, past its
## depth, and this far up (m, times size; less its radius times DROOP).
const BACK_OUT := 0.17
const BACK_UP := 0.12
const DROOP := 0.45
## Its follow-through: a spring on its lag behind his moves (per s^2 and
## damping per s), the lag's most (m, times size) and its swing (degrees
## per m of lag).
const SWAY_K := 90.0
const SWAY_DAMP := 9.0
const SWAY_MAX := 0.12
const SWAY_TILT := 220.0
## The gulp: the swell's overshoot as a piece drops in, and its time (s).
const GULP := 0.18
const GULP_TIME := 0.35
## The refusal line's time (s).
const LINE_TIME := 1.6
## Setting it down and shouldering it: the dip's length (s) and the reach
## to a bag on the ground (m from his feet, times size, past its radius).
const SET_TIME := 0.4
const LIFT_TIME := 0.5
const BAG_REACH := 0.7
## Dragging: the rope from his hand to its middle and its give (m, times
## size), the most it pulls (times its weight, so a curb or a rock as high
## as about half its radius holds it), his paces (times the empty ones,
## light at WEAR_KG to heavy at CAP) and turn, the scuff's spacing (m).
const ROPE_LEN := 0.9
const SLACK := 0.3
const PULL := 1.6
const DRAG_WALK := Vector2(0.5,0.35)
const DRAG_RUN := Vector2(0.3,0.2)
const DRAG_TURN := 0.6
const SCUFF_EVERY := 0.45
## Loose: the sliding friction, its own weight (kg) past its load's.
const FRICTION := 0.7
## Shoved (V / pad right): sent off at this speed (m/s, empty to the cap),
## spinning to roll; the push takes SHOVE_TIME.
const SHOVE_V := Vector2(3.2,1.8)
const SHOVE_TIME := 0.35
## Rolling: a soft sack's drag (times its weight; under an 18 deg slope's
## pull, so it keeps rolling down one and stops on the flat), a thump every
## half turn, and at rest (under REST_SPEED for REST_TIME) it flops upright
## over SETTLE_TIME.
const ROLL_DRAG := 0.2
const REST_SPEED := 0.15
const REST_TIME := 0.4
const SETTLE_TIME := 0.35
const CLOTH_KG := 1.0

const CLOTH := Color("a88b5e")
const PATCH := Color("7a6040")
const ROPE := Color("9a7b52")

var study: Node3D
## What's in it ({id, kind, kg, ...} from the study's `loot`), and their kg.
var items: Array = []
var kg := 0.0
## The barred moves now, and the refusals (drivers read them).
var barred: Array = []
var refusals := 0
var balks := 0
var balked := ""
## The piece being put in ({} none) and seconds into it.
var stowing := {}
var _stow_t := 0.0
var _stow_from := Transform3D.IDENTITY

## "worn", "ground" (set down, a body at rest), "drag" (by its neck) or
## "roll" (shoved: a free ball tumbling till it rests).
var state := "worn"
## The bag set down: a rigid body (its middle; rotation locked).
var loose: RigidBody3D
## Caught (dragged, held fast on something) and how often; metres dragged.
var caught := false
var catches := 0
var dragged := 0.0
var shoves := 0
var rolled := 0.0
var _settle_t := -1.0
var _settle_from := Quaternion.IDENTITY
var _thump := 0.0
## Its putting on or off now ("set", "lift", "" none) and seconds into it.
var act := ""
var _act_t := 0.0
var _act_from := Transform3D.IDENTITY
var _ball: SphereShape3D
var _ball_shape: CollisionShape3D
var _rest_yaw := 0.0
var _still_t := 0.0
var _scuff := 0.0
var _fall_v := 0.0
var _rope: MeshInstance3D

var _base := {}
var _sack: Node3D
var _cloth: MeshInstance3D
var _knot: MeshInstance3D
var _straps: Array[MeshInstance3D] = []
var _cloth_mat: StandardMaterial3D
var _rope_mat: StandardMaterial3D
var _r := 0.0
var _r_to := 0.0
var _drawn := -1.0
var _gulp_t := -1.0
var _lag := Vector3.ZERO
var _lag_v := Vector3.ZERO
var _last_mid := Vector3.INF
var _balk_t := -1.0
var _balk_side := 1.0
var _prompt: Label3D
var _line: Label3D
var _line_t := -1.0
var _readout: Label
var _gulp_sound: AudioStreamPlayer
var _no_sound: AudioStreamPlayer
static var _no_take: AudioStreamWAV = null

func setup(host: Node3D) -> void:
	study = host
	name = "LootBag"
	process_priority = 100
	_cloth_mat = StandardMaterial3D.new()
	_cloth_mat.vertex_color_use_as_albedo = true
	_cloth_mat.vertex_color_is_srgb = true
	_cloth_mat.roughness = 1.0
	_cloth_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_rope_mat = StandardMaterial3D.new()
	_rope_mat.albedo_color = ROPE
	_rope_mat.roughness = 0.9
	_sack = Node3D.new()
	_sack.name = "Sack"
	_sack.top_level = true
	add_child(_sack)
	_cloth = MeshInstance3D.new()
	_cloth.name = "Cloth"
	_cloth.material_override = _cloth_mat
	_sack.add_child(_cloth)
	_knot = MeshInstance3D.new()
	_knot.name = "Tie"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.5
	torus.outer_radius = 1.0
	torus.rings = 12
	torus.ring_segments = 6
	_knot.mesh = torus
	_knot.material_override = _rope_mat
	_sack.add_child(_knot)
	for i in 2:
		var strap := MeshInstance3D.new()
		strap.name = "Strap%d" % i
		strap.top_level = true
		var c := CylinderMesh.new()
		c.top_radius = 0.018
		c.bottom_radius = 0.018
		c.height = 1.0
		c.radial_segments = 5
		c.rings = 1
		strap.mesh = c
		strap.material_override = _rope_mat
		add_child(strap)
		_straps.append(strap)
	_rope = MeshInstance3D.new()
	_rope.name = "DragRope"
	_rope.top_level = true
	var rc := CylinderMesh.new()
	rc.top_radius = 0.02
	rc.bottom_radius = 0.02
	rc.height = 1.0
	rc.radial_segments = 5
	rc.rings = 1
	_rope.mesh = rc
	_rope.material_override = _rope_mat
	_rope.visible = false
	add_child(_rope)
	loose = RigidBody3D.new()
	loose.name = "LooseBag"
	loose.top_level = true
	loose.collision_layer = CarryHost.TREASURE_LAYER
	loose.collision_mask = CarryHost.SOLID_MASK
	loose.lock_rotation = true
	loose.continuous_cd = true
	loose.can_sleep = true
	loose.linear_damp = 0.3
	loose.contact_monitor = true
	loose.max_contacts_reported = 4
	var mat := PhysicsMaterial.new()
	mat.friction = FRICTION
	mat.bounce = 0.05
	loose.physics_material_override = mat
	loose.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	loose.freeze = true
	_ball = SphereShape3D.new()
	_ball_shape = CollisionShape3D.new()
	_ball_shape.shape = _ball
	_ball_shape.disabled = true
	loose.add_child(_ball_shape)
	add_child(loose)
	_prompt = _label(32,Color(1,1,1))
	_line = _label(40,Color(1.0,0.75,0.6))
	var layer := CanvasLayer.new()
	layer.name = "BagReadout"
	add_child(layer)
	_readout = Label.new()
	_readout.anchor_left = 1.0
	_readout.anchor_right = 1.0
	_readout.offset_left = -330.0
	_readout.offset_right = -16.0
	_readout.offset_top = 14.0
	_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_readout.add_theme_font_size_override(&"font_size",20)
	_readout.add_theme_constant_override(&"outline_size",6)
	_readout.add_theme_color_override(&"font_outline_color",Color(0,0,0,0.8))
	layer.add_child(_readout)
	_gulp_sound = AudioStreamPlayer.new()
	_gulp_sound.stream = CarryHost._thud_stream()
	_gulp_sound.volume_db = -6.0
	add_child(_gulp_sound)
	_no_sound = AudioStreamPlayer.new()
	_no_sound.stream = _no_stream()
	_no_sound.volume_db = -4.0
	add_child(_no_sound)
	var motor: Variant = study.get("motor")
	if motor != null: motor.refused.connect(_on_refused)
	_set_kg(0.0)
	_r = _r_to
	_show_readout()

func _label(px: int, colour: Color) -> Label3D:
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.font_size = px
	l.pixel_size = 0.006
	l.outline_size = 8
	l.modulate = colour
	l.visible = false
	add_child(l)
	return l

# --- Filling it -------------------------------------------------------------------------

## The feel at `kg_in` kg: {walk, run, jump, turn} times the empty ones.
static func feel_of(kg_in: float) -> Dictionary:
	var f := pow(clampf((kg_in-FREE_KG)/(CAP-FREE_KG),0.0,1.0),EASE)
	var out := {}
	for k: String in FEEL: out[k] = lerpf(1.0,float(FEEL[k]),f)
	return out

## The moves barred at `kg_in` kg.
static func bars_of(kg_in: float) -> Array:
	var out: Array = []
	for b: Array in BARS:
		if kg_in >= float(b[1])-0.001: out.append(str(b[0]))
	return out

## The sack's belly radius at `kg_in` kg (m, times size).
static func radius_of(kg_in: float) -> float:
	return SACK_R+SACK_R_KG*sqrt(maxf(kg_in,0.0))

## The most it takes now: WEAR_KG on his back, CAP set down.
func limit() -> float:
	return WEAR_KG if state == "worn" else CAP

func fits(piece: Dictionary) -> bool:
	return kg+float(piece.kg) <= limit()+0.001

## Can he wear it (at or under WEAR_KG)?
func wearable() -> bool:
	return kg <= WEAR_KG+0.001

func _set_kg(k: float) -> void:
	kg = k
	_r_to = radius_of(kg)
	loose.mass = kg+CLOTH_KG
	_apply_feel(STOW_PACE if not stowing.is_empty() or act != "" else 1.0)

## The kg on his back (none set down).
func worn_kg() -> float:
	return kg if state == "worn" else 0.0

## His paces dragging it (times the empty ones): {walk, run, jump, turn}.
func drag_feel() -> Dictionary:
	var f := clampf((kg-WEAR_KG)/(CAP-WEAR_KG),0.0,1.0)
	return {"walk":lerpf(DRAG_WALK.x,DRAG_WALK.y,f),"run":lerpf(DRAG_RUN.x,DRAG_RUN.y,f),"jump":0.0,"turn":DRAG_TURN}

## The bag's kg on the motor's kept feel; `pace` times the paces more.
func _apply_feel(pace: float) -> void:
	var m: Variant = study.get("motor")
	if m == null: return
	if _base.is_empty():
		_base = {"walk":m.walk,"run":m.run,"jumps":(m.jumps as Array).duplicate(),"turn":m.turn,"turn_run":m.turn_run,
			"wall_on":m.wall_on,"wallrun_on":m.wallrun_on,"ledge_on":m.ledge_on,"sail_on":m.sail_on,"rope_on":m.rope_on}
	var w := feel_of(worn_kg())
	barred = bars_of(worn_kg())
	if state == "drag":
		w = drag_feel()
		barred = ["jump","wall","ledge","sail","rope"]
	m.walk = float(_base.walk)*float(w.walk)*pace
	m.run = float(_base.run)*float(w.run)*pace
	var j: Array = []
	for h: float in _base.jumps: j.append(h*float(w.jump)*(1.0 if pace >= 1.0 else 0.0))
	m.jumps = j
	m.turn = float(_base.turn)*float(w.turn)
	m.turn_run = float(_base.turn_run)*float(w.turn)
	m.wall_on = bool(_base.wall_on) and not barred.has("wall")
	m.wallrun_on = bool(_base.wallrun_on) and not barred.has("wall")
	m.ledge_on = bool(_base.ledge_on) and not barred.has("ledge")
	m.sail_on = bool(_base.sail_on) and not barred.has("sail")
	m.rope_on = bool(_base.rope_on) and not barred.has("rope")

## Empties it: every piece back on its spot.
func empty() -> void:
	stowing = {}
	for p: Dictionary in items:
		var node: Node3D = p.node
		node.visible = true
		node.transform = Transform3D.IDENTITY
		(p.spot as Node3D).visible = true
	items.clear()
	_set_kg(0.0)

# --- Input ------------------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo(): return
	if event.is_action_pressed(&"walk_shove",false,true):
		if not _on_foot() or not stowing.is_empty() or act != "": return
		if state != "ground" or not bag_near(): return
		get_viewport().set_input_as_handled()
		shove()
		return
	if event.is_action_pressed(&"walk_bag",false,true):
		if not _on_foot() or not stowing.is_empty() or act != "": return
		get_viewport().set_input_as_handled()
		bag_key()
		return
	if not event.is_action_pressed(&"walk_carry",false,true): return
	if not _on_foot() or not stowing.is_empty() or act != "": return
	var p := in_reach()
	if p.is_empty(): return
	get_viewport().set_input_as_handled()
	take(p)

## F: off his back; by it on the ground, on again (or by the neck, too
## heavy to wear); dragging, let go.
func bag_key() -> void:
	match state:
		"worn": set_down()
		"drag": let_go()
		"ground":
			if not bag_near(): return
			if wearable(): lift()
			else: grab()

func _on_foot() -> bool:
	if study == null or not bool(study.get("walk_ready")): return false
	var editor := study.get_node_or_null("LayoutEdit")
	if editor != null and bool(editor.get("editing")): return false
	var motor: Variant = study.get("motor")
	return motor != null and motor.grounded

## Is the bag on the ground (or in his hand) within his reach?
func bag_near() -> bool:
	if state == "worn" or state == "roll": return false
	if state == "drag": return true
	var motor: Variant = study.get("motor")
	var feet: Vector3 = motor.feet
	var s: float = motor.size
	var at := loose.global_position
	return Vector2(at.x-feet.x,at.z-feet.z).length() <= BAG_REACH*s+_r*s and absf(at.y-feet.y) <= 1.2*s

## The nearest loose piece in reach of his feet, or {} (none, or the bag
## set down out of his reach).
func in_reach() -> Dictionary:
	var motor: Variant = study.get("motor")
	if state != "worn" and not bag_near(): return {}
	var feet: Vector3 = motor.feet
	var s: float = motor.size
	var best := {}
	var near := INF
	for p: Dictionary in study.get("loot"):
		if items.has(p) or p == stowing: continue
		var at: Vector3 = (p.node as Node3D).global_position
		var across := Vector2(at.x-feet.x,at.z-feet.z).length()
		if across > REACH*s+float(p.measures.radius) or absf(at.y-feet.y) > REACH_UP*s: continue
		if across < near:
			near = across
			best = p
	return best

## Puts `p` in, or refuses it past the cap.
func take(p: Dictionary) -> void:
	if not fits(p):
		refusals += 1
		_balk("full")
		_no_sound.play()
		if state == "worn" and kg+float(p.kg) <= CAP+0.001:
			_say("Too heavy to wear: set it down (F) to fill it (%s / %d kg)" % [_kg(kg),int(WEAR_KG)])
		else: _say("Too full: %s kg won't go in (%s / %d kg)" % [_kg(float(p.kg)),_kg(kg),int(CAP)])
		return
	stowing = p
	_stow_t = 0.0
	_stow_from = (p.node as Node3D).global_transform
	_apply_feel(STOW_PACE)

## Off his back: it slides off and drops behind him, a body on the ground.
func set_down() -> void:
	if state != "worn": return
	var motor: Variant = study.get("motor")
	var s: float = motor.size
	var r := _r*s
	_ball.radius = r*0.95
	# Its middle from his chest back to where it rides, short of any wall.
	var chest := _bone_world("chest")
	if chest == Vector3.INF: chest = motor.feet+Vector3.UP*0.6*s
	var to := _sack.global_position
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _ball
	q.collision_mask = CarryHost.SOLID_MASK
	q.transform = Transform3D(Basis.IDENTITY,chest)
	q.motion = to-chest
	var cast := get_world_3d().direct_space_state.cast_motion(q)
	var safe: float = cast[0] if cast.size() > 0 else 1.0
	state = "ground"
	_rest_yaw = atan2(-_forward().x,-_forward().z)
	_ball_shape.disabled = false
	var xf := Transform3D(Basis.IDENTITY,chest+(to-chest)*maxf(safe-0.02,0.0))
	loose.freeze = false
	loose.global_transform = xf
	PhysicsServer3D.body_set_state(loose.get_rid(),PhysicsServer3D.BODY_STATE_TRANSFORM,xf)
	loose.sleeping = false
	loose.linear_velocity = motor.ground_velocity()*0.5-_forward()*1.2*s+Vector3.UP*0.8*s
	_fall_v = 0.0
	_begin("set")
	_apply_feel(STOW_PACE)

## On his back again: he dips to it and swings it up (WEAR_KG or under).
func lift() -> void:
	if state != "ground" or not wearable(): return
	_act_from = _sack.global_transform
	_hold_loose()
	state = "worn"
	_lag = Vector3.ZERO
	_lag_v = Vector3.ZERO
	_last_mid = Vector3.INF
	_begin("lift")
	_apply_feel(STOW_PACE)

## By the neck: he drags it, slow.
func grab() -> void:
	if state != "ground": return
	state = "drag"
	caught = false
	_still_t = 0.0
	loose.sleeping = false
	_say("Too heavy to wear (%s kg): dragging it" % _kg(kg))
	_apply_feel(1.0)

## Let go of a dragged one: it lies where it is.
func let_go() -> void:
	if state != "drag": return
	state = "ground"
	caught = false
	_rest_yaw = atan2(-(loose.global_position-_hand()).x,-(loose.global_position-_hand()).z)
	_apply_feel(1.0)

## Shoved: he lunges at it and it's off, away from him, spinning to roll;
## on a slope it keeps going down to the bottom.
func shove() -> void:
	if state != "ground": return
	var motor: Variant = study.get("motor")
	var s: float = motor.size
	var off: Vector3 = loose.global_position-motor.feet
	var d := Vector3(off.x,0.0,off.z)
	d = d.normalized() if d.length() > 0.05 else _forward()
	var v := lerpf(SHOVE_V.x,SHOVE_V.y,clampf(kg/CAP,0.0,1.0))*s
	state = "roll"
	shoves += 1
	_settle_t = -1.0
	_still_t = 0.0
	_thump = 0.0
	loose.lock_rotation = false
	loose.sleeping = false
	loose.linear_velocity = d*v+Vector3.UP*0.5*s
	loose.angular_velocity = Vector3.UP.cross(d)*v/maxf(_ball.radius,0.05)
	_gulp_sound.pitch_scale = 0.9
	_gulp_sound.play()
	_begin("shove")
	_apply_feel(STOW_PACE)

## At rest after a roll: on the ground again, flopping upright.
func _settle() -> void:
	state = "ground"
	loose.lock_rotation = true
	loose.angular_velocity = Vector3.ZERO
	_settle_from = _sack.global_basis.orthonormalized().get_rotation_quaternion()
	_settle_t = 0.0
	var v := loose.linear_velocity
	var f := -_sack.global_basis.z
	if Vector2(f.x,f.z).length() < 0.1: f = Vector3(v.x,0.0,v.z) if Vector2(v.x,v.z).length() > 0.01 else Vector3.FORWARD
	_rest_yaw = atan2(-f.x,-f.z)
	_gulp_sound.pitch_scale = 0.65
	_gulp_sound.play()

func _hold_loose() -> void:
	loose.freeze = true
	loose.linear_velocity = Vector3.ZERO
	_ball_shape.disabled = true
	loose.global_position = Vector3(0.0,-1000.0,0.0)

func _begin(what: String) -> void:
	act = what
	_act_t = 0.0

func _say(text: String) -> void:
	_line.text = text
	_line.visible = true
	_line_t = 0.0

static func _kg(v: float) -> String:
	return ("%.1f" % v) if v != floorf(v) else ("%d" % int(v))

# --- Each frame -------------------------------------------------------------------------

func _process(delta: float) -> void:
	if study == null: return
	var motor: Variant = study.get("motor")
	if motor == null: return
	_r = move_toward(_r,_r_to,delta*0.6)
	if state != "worn" and absf(_ball.radius-_r*float(motor.size)*0.95) > 0.002: _ball.radius = _r*float(motor.size)*0.95
	_place_sack(delta)
	_act_step(delta)
	_drag_look(delta)
	_stow_step(delta)
	_balk_pose(delta)
	_show_prompt()
	_show_readout()
	if _line_t >= 0.0:
		_line_t += delta
		_line.global_position = motor.feet+Vector3.UP*2.3*float(motor.size)
		if _line_t > LINE_TIME:
			_line_t = -1.0
			_line.visible = false

## The sack on his back: hung behind his chest bone along his spine, lagging
## his moves on a spring; swollen to its kg, gulping as a piece drops in.
func _place_sack(delta: float) -> void:
	var motor: Variant = study.get("motor")
	var s: float = motor.size
	var fill := clampf(kg/CAP,0.0,1.0)
	var gulp := 1.0
	if _gulp_t >= 0.0:
		_gulp_t += delta
		var k := _gulp_t/GULP_TIME
		if k >= 1.0: _gulp_t = -1.0
		else: gulp = 1.0+GULP*sin(PI*k)*(1.0-k*0.5)
	var r := _r*s
	var depth := lerpf(DEPTH_EMPTY,1.0,sqrt(fill))
	if absf(_r-_drawn) > 0.004: _shape(_r,depth)
	var fwd := _forward()
	var chest := _bone_world("chest")
	var neck := _bone_world("neck")
	var hips := _bone_world("hips")
	if chest == Vector3.INF: chest = motor.feet+Vector3.UP*0.5*s
	var up := Vector3.UP
	if neck != Vector3.INF and hips != Vector3.INF and neck.distance_to(hips) > 0.01: up = (neck-hips).normalized()
	var back := -fwd
	back = (back-up*back.dot(up)).normalized()
	var mid := chest+back*(BACK_OUT*s+r*depth)+up*(BACK_UP*s-r*DROOP)
	# Its lag: the spring pulls it after where it should be.
	if _last_mid != Vector3.INF and delta > 0.0:
		var moved := mid-_last_mid
		if moved.length() < 1.0:
			_lag -= moved
			var acc := -_lag*SWAY_K-_lag_v*SWAY_DAMP
			_lag_v += acc*delta
			_lag += _lag_v*delta
			_lag = _lag.limit_length(SWAY_MAX*s)
		else:
			_lag = Vector3.ZERO
			_lag_v = Vector3.ZERO
	_last_mid = mid
	var side := up.cross(back).normalized()
	var basis := Basis(side,up,back)
	# Swung by its lag: the bottom trails.
	var tilt := Vector3(_lag.dot(back),0.0,-_lag.dot(side))*deg_to_rad(SWAY_TILT)/maxf(s,0.01)
	basis = basis*Basis(Vector3.RIGHT,clampf(tilt.x,-0.5,0.5))*Basis(Vector3.BACK,clampf(tilt.z,-0.5,0.5))
	var squash := Basis.from_scale(Vector3(gulp,1.0/sqrt(gulp),gulp))
	var xf := Transform3D(basis*squash,mid+_lag*0.5)
	if state != "worn":
		_sack.global_transform = _loose_xform(r,squash)
		for strap in _straps: strap.visible = false
		return
	if act == "lift":
		# Swung up from the ground onto his back, over a little hop.
		var k := clampf(_act_t/LIFT_TIME,0.0,1.0)
		var e := k*k*(3.0-2.0*k)
		var at := _act_from.origin.lerp(xf.origin,e)+Vector3.UP*0.35*s*sin(PI*k)
		xf = Transform3D(_act_from.basis.orthonormalized().slerp(xf.basis.orthonormalized(),e).scaled_local(xf.basis.get_scale()),at)
	_sack.global_transform = xf
	# The straps: from the neck over each shoulder.
	var mouth := _sack.global_transform*Vector3(0.0,r*1.1,-r*depth*0.4)
	var sides := ["upper_arm.L","upper_arm.R"]
	for i in 2:
		var to := _bone_world(sides[i])
		if to == Vector3.INF or (act == "lift" and _act_t < LIFT_TIME*0.7):
			_straps[i].visible = false
			continue
		to += up*0.04*s
		_straps[i].visible = true
		var d := to-mouth
		var l := d.length()
		if l < 0.001: continue
		var y := d/l
		var x := y.cross(fwd).normalized() if absf(y.dot(fwd)) < 0.95 else y.cross(Vector3.RIGHT).normalized()
		_straps[i].global_transform = Transform3D(Basis(x,y,x.cross(y))*Basis.from_scale(Vector3(s,l,s)),(mouth+to)*0.5)

## The sack set down (upright, settled a little) or dragged (lying over,
## its neck to his hand, rocking as it scuffs), about the body's middle.
func _loose_xform(r: float, squash: Basis) -> Transform3D:
	var at := loose.global_position
	if state == "drag":
		var to := _hand()-at
		var flat := Vector3(to.x,0.0,to.z)
		var way := flat.normalized() if flat.length() > 0.01 else -_forward()
		var up := (Vector3.UP*0.5+way).normalized()
		var side := up.cross(Vector3.UP).normalized()
		var rock := 0.12*sin(dragged*7.0)
		var b := Basis(side,up,side.cross(up)).rotated(up,rock)
		return Transform3D(b*squash,at+Vector3.UP*r*0.05)
	if state == "roll":
		# Tumbling with the ball, its belly bulging and easing as it thumps.
		var bulge := 1.0+0.06*absf(sin(rolled/maxf(r,0.05)))
		return Transform3D(loose.global_basis.orthonormalized()*squash*Basis.from_scale(Vector3(bulge,1.0/bulge,bulge)),at)
	var turn := Basis(Vector3.UP,_rest_yaw)
	if _settle_t >= 0.0:
		# Flopping upright from how it stopped, a little overshoot.
		_settle_t += get_process_delta_time()
		var k := clampf(_settle_t/SETTLE_TIME,0.0,1.0)
		var e := 1.0-pow(1.0-k,3.0)
		turn = Basis(_settle_from.slerp(turn.get_rotation_quaternion(),e))
		if k >= 1.0: _settle_t = -1.0
		var flop := 1.0+0.12*sin(PI*k)
		var sit := turn*Basis.from_scale(Vector3(1.06*flop,0.9/flop,1.06*flop))
		return Transform3D(sit*squash,at+Vector3.DOWN*r*0.05*e)
	var sit := turn*Basis.from_scale(Vector3(1.06,0.9,1.06))
	return Transform3D(sit*squash,at+Vector3.DOWN*r*0.05)

## His hand that holds the neck (or near his hip).
func _hand() -> Vector3:
	for b: String in ["hand.R","forearm.R"]:
		var at := _bone_world(b)
		if at != Vector3.INF: return at
	var motor: Variant = study.get("motor")
	return motor.feet+Vector3.UP*0.8*float(motor.size)

## The sack's cloth at belly radius `r` (times size; drawn at size 1, the
## sack node scaled) and `depth`: a bulging pouch, flat and creased when
## empty, taut when full, gathered at the neck under a tie, with darker
## patches sewn on (vertex colour).
func _shape(r: float, depth: float) -> void:
	_drawn = r
	var motor: Variant = study.get("motor")
	var s: float = motor.size if motor != null else 1.0
	var R := r*s
	var fill := clampf((r-SACK_R)/(radius_of(CAP)-SACK_R),0.0,1.0)
	var crease := lerpf(0.14,0.03,fill)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := 16
	var cols := 24
	var grid: Array = []
	for j in range(rows+1):
		var row: Array = []
		var v := float(j)/rows
		for m in range(cols+1):
			var a := TAU*m/cols
			row.append(_sack_at(R,depth,a,v,crease))
		grid.append(row)
	for j in range(rows):
		for m in range(cols):
			var q: Array = [grid[j][m],grid[j][m+1],grid[j+1][m+1],grid[j+1][m]]
			var patch := (m in [4,5,6] and j in [4,5,6]) or (m in [16,17] and j in [8,9])
			var col := PATCH if patch else CLOTH.darkened(0.08*sin(m*1.7+j*0.9))
			for idx: int in [0,2,1,0,3,2]:
				var pv: Vector3 = q[idx]
				# Smooth: out from the belly's middle, the flat sides kept flat.
				st.set_color(col)
				st.set_normal(Vector3(pv.x,pv.y+R*0.2,pv.z/maxf(depth*depth,0.05)).normalized())
				st.add_vertex(pv)
	# The tuft above the tie: the cloth's frayed mouth.
	var top := Vector3(0.0,R*1.1,0.0)
	for m in range(cols):
		var a0 := TAU*m/cols
		var a1 := TAU*(m+1)/cols
		var w := 0.32*R
		var lift := R*(0.22+0.08*sin(m*2.3))
		var p0 := top+Vector3(cos(a0)*w*0.4,0.0,sin(a0)*w*0.4*depth)
		var p1 := top+Vector3(cos(a1)*w*0.4,0.0,sin(a1)*w*0.4*depth)
		var p2 := top+Vector3(cos((a0+a1)*0.5)*w,lift,sin((a0+a1)*0.5)*w*depth)
		for p: Vector3 in [p0,p1,p2]:
			st.set_color(CLOTH.darkened(0.15))
			st.set_normal((p-top).normalized())
			st.add_vertex(p)
	_cloth.mesh = st.commit()
	_knot.position = top+Vector3.DOWN*0.02*s
	_knot.scale = Vector3(0.11*R+0.02*s,0.05*s,0.11*R*depth+0.02*s)

## A point on the sack (radius R, `depth` of it front to back, local +z
## away from his back): round `a`, `v` of the way from its bottom (0) to
## its neck (1); the top half gathered in to the neck, creased by `crease`.
static func _sack_at(R: float, depth: float, a: float, v: float, crease: float) -> Vector3:
	var th := PI*minf(v,0.999)
	var rho := R*sin(th)
	if v > 0.45: rho *= lerpf(1.0,0.16,pow((v-0.45)/0.55,1.3))
	rho *= 1.0+crease*sin(a*5.0+v*7.0)*sin(PI*v)
	var y := R-R*cos(th)
	if v > 0.9: y += (v-0.9)*R*1.0
	# A little sag to the bottom: the load settles low and the cloth hangs.
	y -= R*0.12*sin(PI*v)*(1.0-v)
	return Vector3(cos(a)*rho,y-R,sin(a)*rho*depth)

## Putting it on or off: his chest dips (the bag itself moves in
## _place_sack, or falls as a body); his paces held till it's done.
func _act_step(delta: float) -> void:
	if act == "": return
	_act_t += delta
	var length: float = {"set":SET_TIME,"shove":SHOVE_TIME}.get(act,LIFT_TIME)
	var k := clampf(_act_t/length,0.0,1.0)
	var sk := _skeleton()
	if sk != null:
		var axis := _forward().cross(Vector3.UP)
		var chest := sk.find_bone("chest")
		if act == "shove":
			# A lunge: chest pitched in, both arms thrust out, quick in, held, back.
			var push := sin(PI*minf(k*1.8,1.0)) if k < 0.56 else 1.0-smoothstep(0.56,1.0,k)
			if chest >= 0: CarryHost._turn_bone(sk,chest,axis,-deg_to_rad(24.0)*push)
			for arm: String in ["upper_arm.L","upper_arm.R"]:
				var b := sk.find_bone(arm)
				if b >= 0: CarryHost._turn_bone(sk,b,axis,-deg_to_rad(70.0)*push)
		elif chest >= 0: CarryHost._turn_bone(sk,chest,axis,-deg_to_rad(STOW_BEND)*sin(PI*k))
	if k >= 1.0:
		if act == "lift":
			_gulp_t = 0.0
			_gulp_sound.pitch_scale = 0.8
			_gulp_sound.play()
		act = ""
		_apply_feel(1.0)

## Set down or dragged: the thud as it lands, the scuffs as it slides, the
## rope from his hand, his arm reaching back to it.
func _drag_look(delta: float) -> void:
	if state == "worn":
		_rope.visible = false
		return
	var v := loose.linear_velocity
	if _fall_v < -1.2 and v.y > -0.3:
		_gulp_sound.pitch_scale = 0.7
		_gulp_sound.play()
	_fall_v = v.y
	if state == "roll":
		# Thumps as the lumpy sack comes round, a puff with each.
		_rope.visible = false
		var sp := v.length()
		rolled += sp*delta
		_thump += sp*delta
		if _thump >= PI*_r*float(study.get("motor").size) and sp > 0.6 and loose.get_contact_count() > 0:
			_thump = 0.0
			_gulp_sound.pitch_scale = randf_range(0.55,0.75)
			_gulp_sound.play()
			var puffs: Variant = study.get("puffs")
			if puffs != null: puffs.burst(loose.global_position+Vector3.DOWN*_r*float(study.get("motor").size)*0.8,"stone",0.12,-Vector3(v.x,0.0,v.z).normalized())
		return
	if state != "drag":
		_rope.visible = false
		return
	var motor: Variant = study.get("motor")
	var s: float = motor.size
	var sk := _skeleton()
	if sk != null:
		var arm := sk.find_bone("upper_arm.R")
		if arm >= 0: CarryHost._turn_bone(sk,arm,_forward().cross(Vector3.UP),deg_to_rad(40.0))
	var mouth := _sack.global_transform*Vector3(0.0,_r*s*1.1,0.0)
	var hand := _hand()
	var d := hand-mouth
	var l := d.length()
	_rope.visible = l > 0.01
	if l > 0.01:
		var y := d/l
		var x := y.cross(Vector3.UP).normalized() if absf(y.y) < 0.95 else Vector3.RIGHT
		_rope.global_transform = Transform3D(Basis(x,y,x.cross(y))*Basis.from_scale(Vector3(s,l,s)),(mouth+hand)*0.5)
	var flat := Vector2(v.x,v.z).length()
	if flat > 0.2:
		dragged += flat*delta
		_scuff += flat*delta
		if _scuff >= SCUFF_EVERY*s:
			_scuff = 0.0
			_gulp_sound.pitch_scale = randf_range(0.5,0.65)
			_gulp_sound.play()
			var puffs: Variant = study.get("puffs")
			if puffs != null:
				puffs.burst(loose.global_position+Vector3.DOWN*_r*s*0.8,"stone",0.15,-Vector3(v.x,0.0,v.z).normalized())

## The rope's pull on a dragged bag: past ROPE_LEN it pulls toward his hand,
## harder as it stretches, up to PULL times its weight.
func _physics_process(delta: float) -> void:
	if state == "roll" and study != null:
		_roll_step(delta)
		return
	if state != "drag" or study == null: return
	var motor: Variant = study.get("motor")
	var s: float = motor.size
	var to: Vector3 = motor.feet-loose.global_position
	var flat := Vector3(to.x,0.0,to.z)
	var stretch := flat.length()-ROPE_LEN*s
	if stretch <= 0.0: return
	loose.sleeping = false
	var pull := clampf(stretch/(SLACK*s),0.0,1.0)*PULL*loose.mass*9.8
	loose.apply_central_force(flat.normalized()*pull)

## Rolling: the sack's drag while it touches ground, and its rest.
func _roll_step(delta: float) -> void:
	var v := loose.linear_velocity
	var sp := v.length()
	if loose.get_contact_count() > 0 and sp > 0.01:
		loose.apply_central_force(-v/sp*minf(ROLL_DRAG*loose.mass*9.8,loose.mass*sp/maxf(delta,0.001)))
	var motor: Variant = study.get("motor")
	if loose.global_position.y < motor.feet.y-40.0:
		# Lost off the world: back beside him.
		loose.global_position = motor.feet+Vector3.UP*1.0
		loose.linear_velocity = Vector3.ZERO
	if sp < REST_SPEED and loose.angular_velocity.length() < 1.0:
		_still_t += delta
		if _still_t >= REST_TIME: _settle()
	else: _still_t = 0.0

## Dragging: held to the rope's length and give from the bag (a caught bag
## holds him back). The study calls it after his motor's step, before his
## figure is drawn.
func leash(delta: float) -> void:
	if state != "drag": return
	var motor: Variant = study.get("motor")
	var s: float = motor.size
	var at := loose.global_position
	var off := Vector2(motor.feet.x-at.x,motor.feet.z-at.z)
	var most := (ROPE_LEN+SLACK)*s
	if off.length() > 4.0*s or absf(motor.feet.y-at.y) > 3.0*s:
		let_go()
		return
	var held := off.length() > most
	if held:
		off = off.normalized()*most
		motor.feet = Vector3(at.x+off.x,motor.feet.y,at.z+off.y)
	# Caught: held back while it doesn't move.
	if held and Vector2(loose.linear_velocity.x,loose.linear_velocity.z).length() < 0.15:
		_still_t += delta
		if _still_t > 0.3 and not caught:
			caught = true
			catches += 1
			_balk("caught")
			_say("Caught: pull it another way")
	else:
		_still_t = 0.0
		if Vector2(loose.linear_velocity.x,loose.linear_velocity.z).length() > 0.3: caught = false

## The putting in: he dips to it, it hops over his shoulder into the mouth.
func _stow_step(delta: float) -> void:
	if stowing.is_empty(): return
	_stow_t += delta
	var k := clampf(_stow_t/STOW_TIME,0.0,1.0)
	var node: Node3D = stowing.node
	var motor: Variant = study.get("motor")
	var s: float = motor.size
	var mouth := _sack.global_transform*Vector3(0.0,_r*s*1.1,0.0)
	var from := _stow_from.origin
	var arc := from.lerp(mouth,k)+Vector3.UP*STOW_HOP*s*sin(PI*k)
	node.global_transform = Transform3D(_stow_from.basis.scaled(Vector3.ONE*lerpf(1.0,0.35,k)),arc)
	var sk := _skeleton()
	if sk != null:
		var chest := sk.find_bone("chest")
		if chest >= 0: CarryHost._turn_bone(sk,chest,_forward().cross(Vector3.UP),-deg_to_rad(STOW_BEND)*sin(PI*k))
	if k >= 1.0:
		var p := stowing
		stowing = {}
		node.visible = false
		items.append(p)
		_gulp_t = 0.0
		_gulp_sound.pitch_scale = randf_range(1.1,1.3)
		_gulp_sound.play()
		_set_kg(kg+float(p.kg))

# --- Refusals ---------------------------------------------------------------------------

func _on_refused(what: String) -> void:
	if barred.is_empty(): return
	_balk(what)
	_say("Too heavy to %s (%s kg)" % [{"wall_kick":"wall-kick","ledge":"climb","sail":"sail","rope":"swing"}.get(what,what),_kg(kg)])

func _balk(what: String) -> void:
	balked = what
	balks += 1
	_balk_t = 0.0
	_balk_side = -_balk_side

## The balk on the figure after its clips: the chest lurched aside and back,
## the head shaken no; over carry_weights' BALK_TIME.
func _balk_pose(delta: float) -> void:
	if _balk_t < 0.0: return
	_balk_t += delta
	var k := _balk_t/Weights.BALK_TIME
	if k >= 1.0:
		_balk_t = -1.0
		return
	var sk := _skeleton()
	if sk == null: return
	var fwd := _forward()
	var lurch := sin(PI*minf(k*1.6,1.0))
	var chest := sk.find_bone("chest")
	if chest >= 0:
		CarryHost._turn_bone(sk,chest,fwd,deg_to_rad(Weights.BALK_LEAN)*0.6*lurch*_balk_side)
		CarryHost._turn_bone(sk,chest,fwd.cross(Vector3.UP),deg_to_rad(Weights.BALK_LEAN)*0.3*lurch)
	var head := sk.find_bone("head")
	if head >= 0:
		CarryHost._turn_bone(sk,head,Vector3.UP,sin(TAU*Weights.BALK_SHAKES*k)*(1.0-k)*deg_to_rad(Weights.BALK_HEAD))

## The low "uh-uh": two falling hums (made once).
static func _no_stream() -> AudioStreamWAV:
	if _no_take != null: return _no_take
	var rate := 22050
	var data := PackedByteArray()
	var n := int(rate*0.42)
	data.resize(n*2)
	for i in n:
		var t := float(i)/rate
		var note := 0 if t < 0.17 else (1 if t > 0.22 else -1)
		var v := 0.0
		if note >= 0:
			var t0 := t if note == 0 else t-0.22
			var len := 0.17 if note == 0 else 0.2
			var f := (210.0 if note == 0 else 165.0)*(1.0-0.08*t0/len)
			var env := sin(PI*clampf(t0/len,0.0,1.0))
			v = (sin(TAU*f*t0)+0.35*sin(TAU*2.0*f*t0))*env*0.4
		data.encode_s16(i*2,int(clampf(v,-1.0,1.0)*32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	_no_take = w
	return w

# --- On screen --------------------------------------------------------------------------

func _show_prompt() -> void:
	var motor: Variant = study.get("motor")
	var busy: bool = not stowing.is_empty() or act != "" or not motor.grounded
	var p := {} if busy else in_reach()
	if p.is_empty():
		_prompt.visible = false
		if busy or state != "ground" or not bag_near(): return
		_prompt.text = ("F  shoulder it" if wearable() else "F  drag it  (too heavy to wear)")+"   ·   V  shove it"
		_prompt.modulate = Color(1,1,1)
		_prompt.global_position = loose.global_position+Vector3.UP*(_r*float(motor.size)+0.6)
		_prompt.visible = true
		return
	var ok := fits(p)
	var m: Dictionary = p.measures
	var full := "too heavy to wear more" if state == "worn" and kg+float(p.kg) <= CAP+0.001 else "full"
	_prompt.text = ("E  bag it  (%s kg)" % _kg(float(p.kg))) if ok else ("%s  (%s kg won't fit)" % [full,_kg(float(p.kg))])
	_prompt.modulate = Color(1,1,1) if ok else Color(1.0,0.6,0.5)
	_prompt.global_position = (p.node as Node3D).global_position+Vector3.UP*(float(m.height)+0.55)
	_prompt.visible = true

func _show_readout() -> void:
	var cells := 20
	var on := int(round(clampf(kg/CAP,0.0,1.0)*cells))
	var lines := PackedStringArray(["Bag  %s / %d kg  (wear to %d)" % [_kg(kg),int(CAP),int(WEAR_KG)],"[%s%s]" % ["#".repeat(on),"-".repeat(cells-on)]])
	lines.append({"worn":"on his back","ground":"set down" if wearable() else "set down: too heavy to wear",
		"drag":"dragging%s" % ("  (caught)" if caught else ""),"roll":"rolling"}.get(state,state))
	var w := drag_feel() if state == "drag" else feel_of(worn_kg())
	lines.append("pace %d%%  jump %d%%" % [int(round(float(w.run)*100.0)),int(round(float(w.jump)*100.0))])
	lines.append("no %s" % ", ".join(barred) if not barred.is_empty() else "every move")
	_readout.text = "\n".join(lines)

# --- The figure ---------------------------------------------------------------------------

func _forward() -> Vector3:
	var fig: Node3D = study.get("figure")
	if fig == null: return Vector3.FORWARD
	var f := -fig.global_basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.001 else Vector3.FORWARD

func _skeleton() -> Skeleton3D:
	var body: Node = study.get("body")
	return null if body == null else body.get("_skeleton") as Skeleton3D

func _bone_world(bone_name: String) -> Vector3:
	var sk := _skeleton()
	if sk == null: return Vector3.INF
	var b := sk.find_bone(bone_name)
	return Vector3.INF if b < 0 else sk.global_transform*sk.get_bone_global_pose(b).origin
