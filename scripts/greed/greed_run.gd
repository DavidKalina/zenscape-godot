extends Node
## The greed run's keep, clock and end (docs/design/greed-run/
## spec-greed-run.md), under the crag reach with --greed-run.
##
## Banking: F at the plane's rope hook hitches the bag (scripts/carry/
## loot_bag.gd); while it hangs there its load is the plane's. F there
## again takes the bag back off emptied: what was in it goes into the
## plane's keep (`bank`), and he walks off with an empty bag for more.
## Escape: flying, the plane AWAY m across from the isle's middle (past
## the crag's masses and its near islets; the far specks round to ~700 m
## don't count) ends the run
## banked: the keep, what hangs in the hitched bag and a bag worn aboard.
## Death: swallowed by the Olmec's head (held SWALLOW_HOLD s, the jaw shut
## on him), or stranded off the edge (kit_isle.gd's fall rule): the run ends
## lost; the keep and a hitched bag are kept, his bag is lost.
## Lost on the end screen: every piece that went into a bag (the greed
## meter's `counted`) and isn't banked: ripped out, spilled, buried, or in
## his bag when he died.
## A bag the brood bury (scripts/brood/bag_brood.gd) is lost with its load
## (they count lost on the end screen); SPARE_WAIT s later the one spare
## (SPARES a run) lies empty by the plane's rope hook: the same bag, its
## load gone, set down there. A second buried bag stays down: no bag left.
## The end screen pauses the tree; Enter / R (pad A) starts a new run
## (the scene reloaded, the same launch flags).
const VaultHost = preload("res://scripts/home/vault_host.gd")
const Pad = preload("res://scripts/pad.gd")
const Greed = preload("res://studies/crag_reach_greed.gd")

## This far (m, across) from the isle's middle, flying: away. The crag
## reach's masses lie within ~130 m, its islets to 190 m.
const AWAY := 250.0
## Swallowed this long (s) before the run ends: the jaw's slam reads.
const SWALLOW_HOLD := 0.8
## Spare bags a run, and how long (s) after a burial the spare lies by the
## hook (the burial reads first).
const SPARES := 1
const SPARE_WAIT := 2.5
## The spare lies this far (m, x size) off the hook's middle, to the side.
const SPARE_OFF := Vector3(2.6,0.5,1.2)

var host: Node3D
## The plane's keep: the loot dicts banked off the bag.
var keep: Array = []
var t := 0.0
## "" running, "banked" (away), "lost" (dead).
var ended := ""
var why := ""
var banked: Array = []
var lost: Array = []
var _circle := Vector3.INF
var _swallow_t := 0.0
var spares := SPARES
## Bags the brood buried, and their loads (loot dicts).
var lost_bags := 0
var bag_loads: Array = []
var _buried_t := -1.0
var _layer: CanvasLayer
var _title: Label
var _body: Label

func setup(h: Node3D) -> void:
	host = h
	name = "GreedRun"
	process_mode = Node.PROCESS_MODE_ALWAYS

## The bag off the hook: what's in it goes into the plane's keep.
func bank(bag: Node3D) -> void:
	if ended != "": return
	var out: Array = bag.empty_out()
	if out.is_empty(): return
	for p: Dictionary in out:
		p.banked = true
		keep.append(p)
	var line := "Into the plane's keep: %s   (banked %d)" % [_names(out),worth(keep)]
	if host.has_method("_say"): host.call("_say",line,3.0)
	print("greed run: banked %d piece(s), %d in the keep, worth %d" % [out.size(),keep.size(),worth(keep)])

static func worth(list: Array) -> int:
	var w := 0
	for p: Dictionary in list: w += int(VaultHost.VALUES.get(str(p.get("kind","")),0))
	return w

static func _names(list: Array) -> String:
	var n: Array[String] = []
	for p: Dictionary in list: n.append(str(VaultHost.NAMES.get(str(p.get("kind","")),p.get("kind",""))))
	return ", ".join(n)

## The corner line: the keep and the clock.
func text() -> String:
	return "In the plane's keep %d  ·  %d:%02d" % [worth(keep),int(t)/60,int(t)%60]

## Each frame, from the host's _process (on foot and flying).
func step(delta: float) -> void:
	if ended != "" or delta <= 0.0: return
	t += delta
	_spare_step(delta)
	if bool(host.get("flying")):
		_swallow_t = 0.0
		if _circle == Vector3.INF: _circle = host.call("isle_circle")
		var at: Vector3 = host.get("plane").position
		if Vector2(at.x-_circle.x,at.z-_circle.y).length() > AWAY:
			end("banked","You got away from the crag.")
		return
	var head: Node3D = host.call("olmec_head") if host.has_method("olmec_head") else null
	if head != null and bool(head.get("swallowed")):
		_swallow_t += delta
		if _swallow_t >= SWALLOW_HOLD:
			end("lost","The Olmec swallowed you.")
			return
	else: _swallow_t = 0.0
	if float(host.get("_stranded_left")) >= 0.0:
		end("lost","You fell off the crag.")

## The bag buried: its load lost; SPARE_WAIT s on, the spare by the hook.
func _spare_step(delta: float) -> void:
	var bag: Node3D = host.get("bag")
	if bag == null or not bool(bag.buried):
		_buried_t = -1.0
		return
	if _buried_t < 0.0:
		_buried_t = 0.0
		lost_bags += 1
		var load: Array = (bag.items as Array).duplicate()
		for p: Dictionary in load: p.lost = true
		bag_loads.append_array(load)
		var line := "The brood buried your bag" + (" with %s in it" % _names(load) if not load.is_empty() else "")
		if spares > 0: line += ". A spare waits by the plane's hook."
		else: line += ". No bag left."
		if host.has_method("_say"): host.call("_say",line,4.0)
		print("greed run: bag buried (%d piece(s), worth %d), %d spare(s) left" % [load.size(),worth(load),spares])
	if spares <= 0 or _buried_t > SPARE_WAIT:
		return
	_buried_t += delta
	if _buried_t <= SPARE_WAIT: return
	spares -= 1
	_spare(bag)

## The buried bag, emptied, set down by the plane's hook; the brood let go
## of it (its guards stand down in their own time).
func _spare(bag: Node3D) -> void:
	bag.empty_out()
	var brood: Node = host.get("brood")
	if brood != null: brood.set("bag_in","")
	var sling: Node3D = (host.get("carry") as Node).get("sling") if host.get("carry") != null else null
	var s: float = host.get("motor").size if host.get("motor") != null else 1.0
	var at: Vector3 = sling.middle() if sling != null else (host.get("plane") as Node3D).global_position
	bag.unbury(at+SPARE_OFF*s)
	# The grass round it bared (as round the loot): an empty sack hides in it.
	var mark := Node3D.new()
	var spot := Node3D.new()
	mark.add_child(spot)
	host.add_child(mark)
	spot.global_position = at+Vector3(SPARE_OFF.x,0.0,SPARE_OFF.z)*s
	Greed._bare(host,mark)
	mark.queue_free()
	if host.has_method("_say"): host.call("_say","A spare bag lies by the plane's hook: F by it puts it on",4.0)
	print("greed run: the spare bag by the hook at %s" % str(bag.loose.global_position))

## Ends the run: what reached the plane is banked; with `how` "banked" a
## bag worn aboard too; the rest bagged is lost.
func end(how: String, line: String) -> void:
	if ended != "": return
	ended = how
	why = line
	banked = keep.duplicate()
	var bag: Node3D = host.get("bag")
	if bag != null and is_instance_valid(bag) and not bool(bag.buried):
		if str(bag.state) == "hitched" or (how == "banked" and str(bag.state) == "worn"):
			for p: Dictionary in bag.items:
				if not banked.has(p): banked.append(p)
	lost = []
	var greed: Node = host.get("greed")
	var counted: Dictionary = greed.get("counted") if greed != null else {}
	for p: Dictionary in host.get("loot"):
		if counted.has(str(p.get("id",""))) and not banked.has(p): lost.append(p)
	print("greed run: END %s (%s) banked %d (%d piece(s)), lost %d (%d piece(s)), %.1f s" % [how,line,worth(banked),banked.size(),worth(lost),lost.size(),t])
	_show()
	get_tree().paused = true

func _show() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 20
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)
	var dim := ColorRect.new()
	dim.color = Color(0.03,0.03,0.04,0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(dim)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06,0.05,0.05,0.82)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(36)
	panel.add_theme_stylebox_override("panel",style)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_layer.add_child(panel)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation",14)
	panel.add_child(box)
	_title = _label("Banked" if ended == "banked" else "Lost",54,Color("f3d27a") if ended == "banked" else Color("e07a5f"))
	box.add_child(_title)
	box.add_child(_label(why,24,Color("fbf6ea")))
	var lines: Array[String] = []
	lines.append("Banked  %d%s" % [worth(banked),("   (%s)" % _names(banked)) if not banked.is_empty() else ""])
	lines.append("Lost  %d%s" % [worth(lost),("   (%s)" % _names(lost)) if not lost.is_empty() else ""])
	lines.append("Time  %d:%02d" % [int(t)/60,int(t)%60])
	_body = _label("\n".join(lines),28,Color("fbf6ea"))
	box.add_child(_body)
	box.add_child(_label(Pad.pick("Enter or R  a new run","A  a new run"),22,Color(0.85,0.85,0.8)))

func _label(text: String, size: int, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size",size)
	l.add_theme_color_override("font_color",colour)
	l.add_theme_color_override("font_shadow_color",Color(0,0,0,0.8))
	l.add_theme_constant_override("shadow_offset_y",2)
	return l

func _unhandled_input(event: InputEvent) -> void:
	if ended == "": return
	var go := event.is_action_pressed(&"ui_accept",false,true)
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_R: go = true
	if event is InputEventJoypadButton and event.pressed and (event as InputEventJoypadButton).button_index == JOY_BUTTON_A: go = true
	if not go: return
	get_viewport().set_input_as_handled()
	restart()

## A new run: the scene again with the same flags.
func restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
