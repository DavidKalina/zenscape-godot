extends "res://studies/character_study.gd"
## The interactables yard (docs/design/foot-interactables.md): the on-foot
## pieces side by side for tuning, in open sky, on greybox decks (the
## character study's: grey structure, green landing decks), the pieces in
## the ruin kit's stone. The pilot is the character study's (this extends
## it): the same motor, figure, camera, F1 numbers, F2 feel, recorder.
##   1  bobbing slabs: four floating stones that bob, sink and tip under
##      him and spring back, out to a far deck
##   2  drifting slabs: one sliding across the way, one ferrying out and
##      back, a long one turning, one going round a ring
##   3  swing ropes: two ropes on trilithons over a gap (jump in, the stick
##      pumps, Space lets go with the swing's pace), a far deck with metre
##      ticks to read the throw
##   4  balustrade: the kit's grand stair down from a high deck, a banister
##      down each cheek; jump onto one and slide it (crouch tucks, stick back
##      brakes, the stick across balances), jump off or be flung off its foot
##      along the run-out's ticks
## F1 adds the pieces' numbers (the slab under him, the rope's swing, the
## rail's pace and balance, the last release and rail top). F4 the pieces'
## feel (sliders over every piece's `t_*`, live; Print copies the set).
## --at=bob|drift|rope|rail (or 1-4) starts at that station.
##   ./run-interactables.command [--at=rope]
##   godot --path . res://studies/interactables_yard.tscn -- --no-title
const FootPieces = preload("res://scripts/interactables/foot_pieces.gd")
const BobSlab = preload("res://scripts/interactables/bob_slab.gd")
const DriftSlab = preload("res://scripts/interactables/drift_slab.gd")
const SwingRope = preload("res://scripts/interactables/swing_rope.gd")
const Balustrade = preload("res://scripts/interactables/balustrade.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")

const YARD_START := Vector3(0.0,0.0,4.0)
const YARD_LOST := -4.0
## The grand stair (station 4): its frame, foot toward +z.
const STAIR := Transform3D(Basis.IDENTITY,Vector3(24.0,0.0,-8.2))
## The ropes: anchors and length; the trilithons' height.
const ROPES := [Vector3(6.0,7.0,-3.8),Vector3(6.0,7.0,-11.5)]
const ROPE_LENGTH := 6.6
const YARD := [
	{"key":1,"name":"Bobbing slabs","spawn":Vector3(-30.0,0.0,1.0),"face":Vector2(0.0,-1.0),"sign":Vector3(-30.0,3.0,3.0),"parts":[
		["box",Rect2(-34.0,-24.0,8.0,4.0),-1.0,0.5,"pad"],
		["label",Vector3(-30.0,1.2,-21.0),"far deck"],
	]},
	{"key":2,"name":"Drifting slabs","spawn":Vector3(-12.0,0.0,1.0),"face":Vector2(0.0,-1.0),"sign":Vector3(-12.0,3.0,3.0),"parts":[
		["box",Rect2(-16.0,-38.0,8.0,4.0),-1.0,1.2,"pad"],
		["label",Vector3(-12.0,2.0,-35.0),"far deck"],
	]},
	{"key":3,"name":"Swing ropes","spawn":Vector3(6.0,0.0,1.0),"face":Vector2(0.0,-1.0),"sign":Vector3(6.0,3.0,3.0),"parts":[
		["box",Rect2(1.0,-30.0,10.0,14.0),-1.0,0.0,"pad"],
		["ticks",Vector2(10.5,-16.0),Vector2(10.5,-30.0),1.0,2],
		["box",Rect2(0.0,-21.0,12.0,1.0),-12.0,-11.0,"dark"],
	]},
	{"key":4,"name":"Balustrade","spawn":Vector3(24.0,4.48,-16.5),"face":Vector2(0.0,1.0),"sign":Vector3(24.0,7.5,-19.0),"parts":[
		["box",Rect2(19.0,-20.5,10.0,6.2),-1.0,4.48,"grey"],
		["box",Rect2(17.0,-14.4,14.0,12.4),-1.0,0.0,"floor"],
		["box",Rect2(17.0,8.0,14.0,24.0),-1.0,0.0,"floor"],
		["ticks",Vector2(30.5,-2.0),Vector2(30.5,30.0),1.0,5],
	]},
]

var pieces: Node3D
var _feel_panel: PanelContainer
var _feel_box: VBoxContainer
var _start_at := ""

## The pieces' feel on the F4 panel: [script, its static var, slider range].
const PIECE_TUNABLE := [
	[BobSlab,"t_sink",0.0,0.8],[BobSlab,"t_tilt",0.0,0.4],[BobSlab,"t_give",0.0,0.2],[BobSlab,"t_hz",0.3,4.0],
	[BobSlab,"t_damp",0.05,1.5],[BobSlab,"t_bob",0.0,0.6],[BobSlab,"t_bob_time",1.0,12.0],
	[DriftSlab,"t_speed",0.0,3.0],[DriftSlab,"t_sink",0.0,0.4],[DriftSlab,"t_tilt",0.0,0.2],
	[SwingRope,"t_gravity",5.0,40.0],[SwingRope,"t_pump",0.0,25.0],[SwingRope,"t_steer",0.0,10.0],[SwingRope,"t_most",0.5,1.55],
	[SwingRope,"t_damp",0.0,1.0],[SwingRope,"t_top",4.0,24.0],[SwingRope,"t_pop",0.0,8.0],[SwingRope,"t_catch",0.2,1.5],
	[Balustrade,"t_pull",0.0,40.0],[Balustrade,"t_drag",0.0,5.0],[Balustrade,"t_air",0.0,0.15],[Balustrade,"t_tuck",0.0,1.0],
	[Balustrade,"t_brake",0.0,15.0],[Balustrade,"t_top",4.0,30.0],[Balustrade,"t_jump",0.2,2.5],[Balustrade,"t_tip",0.0,3.0],
	[Balustrade,"t_wobble",0.0,1.5],[Balustrade,"t_lean",0.0,6.0],[Balustrade,"t_catch",0.1,1.0],
]

func _ready() -> void:
	pack = "interactables_yard"
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--at=") or arg.begins_with("--foot-at="): _start_at = arg.get_slice("=",1)
	super._ready()
	var key := {"bob":1,"1":1,"drift":2,"2":2,"rope":3,"3":3,"rail":4,"4":4}.get(_start_at,0) as int
	if key > 0:
		go_to(key)
		_last_stood = motor.feet

## The yard's stations, not a pack's file.
func _load_pack() -> void:
	stations = YARD
	start = YARD_START
	start_face = Vector2(0.0,-1.0)
	lost = YARD_LOST
	_last_stood = start

## The start deck all the stations leave from, their decks, then the pieces.
func _build_room() -> void:
	_box(Rect2(-36.0,-2.0,68.0,10.0),-1.0,0.0,"floor")
	super._build_room()
	pieces = FootPieces.new()
	add_child(pieces)
	pieces.attach(self)
	_build_pieces()

func _build_pieces() -> void:
	# 1: bobbing slabs out to the far deck, a little higher each, the last
	# gap a pump.
	var bobs := [Vector3(-30.5,0.1,-4.6),Vector3(-28.6,0.5,-8.4),Vector3(-30.8,0.9,-12.4),Vector3(-29.4,0.6,-16.8)]
	for i in range(bobs.size()): pieces.bob_slab(bobs[i],Vector3(2.4,0.7,2.2),0.3*i,40+i)
	# 2: drifting slabs: across the way, out and back, turning, round a ring.
	pieces.drift_slab(PackedVector3Array([Vector3(-16.5,0.0,-4.8),Vector3(-7.5,0.0,-4.8)]),8.0,false,0.0,Vector3(2.4,0.6,2.0),0.0,50)
	pieces.drift_slab(PackedVector3Array([Vector3(-12.0,0.4,-9.5),Vector3(-12.0,0.4,-16.0)]),9.0,false,0.0,Vector3(2.2,0.6,2.2),0.0,51)
	pieces.drift_slab(PackedVector3Array([Vector3(-12.0,0.8,-22.5)]),1.0,false,0.45,Vector3(7.0,0.6,1.6),0.0,52)
	var ring := PackedVector3Array()
	for k in range(12): ring.append(Vector3(-12.0,1.2,-29.0)+Vector3(cos(TAU*k/12.0),0.0,sin(TAU*k/12.0))*2.6)
	pieces.drift_slab(ring,12.0,true,0.0,Vector3(2.2,0.6,2.2),0.0,53)
	# 3: ropes on trilithons over the gap.
	for i in range(ROPES.size()):
		var a: Vector3 = ROPES[i]
		pieces.rope_frame(Vector3(a.x,-11.0,a.z),Vector2(1.0,0.0),7.0,a.y+11.0,ROPE_LENGTH,60+i)
	# 4: the grand stair down from the high deck, a banister each side.
	var stair := RuinKit.grand_stair(70,0.25)
	stair.transform = STAIR
	add_child(stair)
	for side: float in [-1.0,1.0]: pieces.balustrade(Balustrade.grand_stair_rail(STAIR,side),71+int(side),0.3)

# --- Tuning (F4) and numbers (F1) --------------------------------------------------

func _build_ui() -> void:
	super._build_ui()
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	_feel_panel = PanelContainer.new()
	_feel_panel.visible = false
	_feel_panel.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	_feel_panel.offset_left = -392.0
	_feel_panel.offset_right = -12.0
	_feel_panel.offset_top = 12.0
	_feel_panel.offset_bottom = -48.0
	layer.add_child(_feel_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_feel_panel.add_child(scroll)
	_feel_box = VBoxContainer.new()
	_feel_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_feel_box)
	for spec: Array in PIECE_TUNABLE:
		var script: Script = spec[0]
		var key: String = spec[1]
		var row := HBoxContainer.new()
		var name_label := Label.new()
		name_label.custom_minimum_size.x = 150.0
		name_label.text = "%s.%s" % [_short(script),key.trim_prefix("t_")]
		var value := Label.new()
		value.custom_minimum_size.x = 56.0
		var slider := HSlider.new()
		slider.custom_minimum_size.x = 150.0
		slider.min_value = spec[2]
		slider.max_value = spec[3]
		slider.step = 0.005
		slider.value = float(script.get(key))
		value.text = "%.3f" % slider.value
		slider.value_changed.connect(func(v: float) -> void:
			script.set(key,v)
			value.text = "%.3f" % v)
		slider.focus_mode = Control.FOCUS_NONE
		row.add_child(name_label)
		row.add_child(slider)
		row.add_child(value)
		_feel_box.add_child(row)
	var buttons := HBoxContainer.new()
	for action: String in ["Print","Defaults"]:
		var button := Button.new()
		button.text = action
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(func() -> void:
			if action == "Print": print_pieces()
			else: default_pieces())
		buttons.add_child(button)
	_feel_box.add_child(buttons)

static func _short(script: Script) -> String:
	return script.resource_path.get_file().get_basename()

## The pieces' feel now, as their constants to paste back.
func print_pieces() -> String:
	var lines := PackedStringArray()
	for spec: Array in PIECE_TUNABLE:
		var script: Script = spec[0]
		lines.append("const %s := %s  # %s" % [str(spec[1]).trim_prefix("t_").to_upper(),_num(float(script.get(spec[1]))),_short(script)])
	var text := "\n".join(lines)
	print("interactables feel:\n"+text)
	DisplayServer.clipboard_set(text)
	return text

## Every piece's feel back to its constants.
func default_pieces() -> void:
	for spec: Array in PIECE_TUNABLE:
		var script: Script = spec[0]
		var key: String = spec[1]
		var constant := key.trim_prefix("t_").to_upper()
		var value: Variant = script.get_script_constant_map().get(constant,null)
		if key == "t_speed": value = 1.0
		if value != null: script.set(key,value)
	var i := 0
	for row in _feel_box.get_children():
		if i >= PIECE_TUNABLE.size(): break
		var spec: Array = PIECE_TUNABLE[i]
		(row.get_child(1) as HSlider).set_value_no_signal(float((spec[0] as Script).get(spec[1])))
		(row.get_child(2) as Label).text = "%.3f" % float((spec[0] as Script).get(spec[1]))
		i += 1

func _tuning() -> bool:
	return super._tuning() or (_feel_panel != null and _feel_panel.visible)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_F4:
		_feel_panel.visible = not _feel_panel.visible
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if _feel_panel.visible else Input.MOUSE_MODE_CAPTURED
		return
	super._unhandled_input(event)

func _hint_text() -> String:
	return "1 bobbing slabs · 2 drifting slabs · 3 swing ropes (jump in; stick pumps; Space lets go, crouch drops) · 4 balustrade (jump on; crouch tucks, stick back brakes, across balances; Space off) · R start · F1 numbers · F2 feel · F4 pieces' feel · Esc mouse"

func _show_hud() -> void:
	super._show_hud()
	if not _hud.visible or pieces == null: return
	var lines := PackedStringArray([_hud.text,""])
	lines.append_array(pieces_lines(pieces))
	_hud.text = "\n".join(lines)

## The pieces' lines for F1 (the yard's and the isles').
static func pieces_lines(host: Node3D) -> PackedStringArray:
	var lines := PackedStringArray()
	var riding: Node3D = host.riding()
	if riding is SwingRope:
		var r: Node3D = riding
		lines.append("rope      held at %.1f m · %.0f° off plumb · %.2f m/s" % [r.grip,rad_to_deg((r.hands-r.anchor).angle_to(Vector3.DOWN)),r.velocity.length()])
	elif riding is Balustrade:
		var b: Node3D = riding
		lines.append("rail      %.2f m/s · %.1f of %.1f m · balance %+.2f · top %.2f" % [absf(b.pace),b.s,b.length,b.balance,b.ride_top])
	elif host.on != null:
		lines.append("slab      on · sag %+.2f m · tilt %.1f°" % [host.on.sag,rad_to_deg(host.on.lean.length())])
	lines.append("pieces    slab landings %d · rope catches %d · rail rides %d" % [host.counts.slab,host.counts.swing,host.counts.rail])
	var v: Vector3 = host.last_release
	if v != Vector3.ZERO: lines.append("last rope release %.2f m/s across, %.2f up" % [Vector2(v.x,v.z).length(),v.y])
	if host.last_rail_top > 0.0: lines.append("last rail top %.2f m/s" % host.last_rail_top)
	return lines
