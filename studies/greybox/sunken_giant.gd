extends "res://studies/character_study.gd"
## GREYBOX, round 1 + Opus pass: the Sunken Giant (docs/design/roguelike/brainstorm/
## round1/motif-m2-sunken-giant.md). A kneeling headless giant in open sky,
## blocked out in boxes (fist, forearm, elbow, chest set-offs, shoulder
## deck, neck stump), climbed by grabs, a pump, a rope swing and wall kicks,
## with the REAL inhaler heads (scripts/enemies/inhaler_head.gd) on the
## shoulder deck. Stand-ins are labelled "STAND-IN" in the world.
##   1 fingertips (start)   2 knuckles   3 forearm   4 elbow gap + rope
##   5 chest set-offs       6 kick shaft 7 shoulder deck: chain 1, the
##   accidental fall-back   8 chain 2: head to head (stand still, twice)
##   9 chain 3: the chimney 0 neck summit   - exit rim (4), south-east
##   = where head 1's blast leaves you (head 2 alone)   [ thumb perch
## R back to the start (heads and traps rebuilt) · F1 numbers (the heads')
##   godot --path . res://studies/greybox/sunken_giant.tscn -- --no-title
##     [--head-knob=<knob>=<value>] (both heads; the layout needs none)
##
## THE LAYOUT IS ONE TABLE (LAYOUT, below): masses (one terrain mass with
## its tiers each), ramps, ropes, traps, enemies, stations. Everything is
## built from it, so a later turf pass (KitLand.island) can read the same
## table. Heights come from the pilot's numbers (scripts/ruin_kit.gd: GRAB_TOP
## a plain jump's catch, CHAIN_TOP the pump's, SET_OFF a one-jump rise).
const RuinKit = preload("res://scripts/ruin_kit.gd")
const EnemyField = preload("res://scripts/enemies/enemy_field.gd")
const InhalerHead = preload("res://scripts/enemies/inhaler_head.gd")
const EnemyYard = preload("res://studies/enemy_yard.gd")
const FootPieces = preload("res://scripts/interactables/foot_pieces.gd")
const TrapField = preload("res://scripts/traps/trap_field.gd")
const Trap = preload("res://scripts/traps/trap.gd")

# --- The numbers the table is built from (all from the pilot) -------------------------
const GRAB := RuinKit.GRAB_TOP        # 1.875: the highest lip a plain jump catches
const CHAIN := RuinKit.CHAIN_TOP      # 2.575: the pump's
const SO := RuinKit.SET_OFF           # 1.6: a one-jump rise
## Knuckles: a plain-jump rise, a pump rise, a one-jump rise. The first
## is 6 m deep: the pump to the second needs a run of two jumps on it.
const Y_K1 := GRAB-0.15
const Y_K2 := Y_K1+CHAIN-0.375
const Y_K3 := Y_K2+SO
## The forearm walked as a ramp (rise over its 14 m), then the gap to the
## elbow ledge, a one-jump rise lower.
const FOREARM_RISE := 4.0
const Y_END := Y_K3+FOREARM_RISE
const Y_ELBOW := Y_END-SO
## The chest's set-offs, and the kick shaft (the character study's station
## 9: walls 2.8 m apart, 6 m tall) up to the shoulder deck.
const Y_T1 := Y_ELBOW+SO
const Y_T2 := Y_T1+SO
const Y_T3 := Y_T2+SO
const Y_T4 := Y_T3+SO
const SHAFT_TALL := 6.0
const Y_DECK := Y_T4+SHAFT_TALL
## The broken stair round the neck, six set-offs to the stump's top.
const Y_NECK := Y_DECK+SO*6.0
## The rope: its length, and its anchor over the forearm's end so the knot
## hangs at a walker's hands off the lip (swing_rope.gd KNOT).
const ROPE := 5.6
const Y_ANCHOR := Y_END+0.9+ROPE
const GAP := 5.2

## [x, y, z] the one table. Colours: grey structure, lip orange (to hang
## from), pad green (to land on).
## masses: {name, base, tiers: [[Rect2 (x, z), top, colour], ...]}
## ramps: [low middle edge, high middle edge, width]
## ropes: {anchor, length}
## traps: {kind, rect, bottom, top}   (STAND-INs)
## enemies: {id, at, face (x, z), knobs}  (the real InhalerHead)
## labels: [position, text]
const LAYOUT := {
	"masses":[
		{"name":"HAND · fingertip landing, then knuckles (jump, pump, jump)","base":-4.0,"tiers":[
			[Rect2(-13.0,-5.0,10.0,10.0),0.0,"pad"],
			[Rect2(-3.0,-5.0,6.0,10.0),Y_K1,"lip"],
			[Rect2(3.0,-5.0,3.0,10.0),Y_K2,"lip"],
			[Rect2(6.0,-5.0,3.0,10.0),Y_K3,"lip"]]},
		{"name":"FOREARM END · the beam stops, the gap begins","base":3.0,"tiers":[
			[Rect2(23.0,-8.0,3.0,28.0),Y_END,"lip"]]},
		{"name":"ELBOW LEDGE (2)","base":0.0,"tiers":[
			[Rect2(23.0+3.0+GAP,-8.0,5.8,28.0),Y_ELBOW,"lip"]]},
		{"name":"CHEST · four set-offs, then the shaft floor","base":0.0,"tiers":[
			[Rect2(37.0,-8.0,3.0,28.0),Y_T1,"lip"],
			[Rect2(40.0,-8.0,3.0,28.0),Y_T2,"lip"],
			[Rect2(43.0,-8.0,3.0,28.0),Y_T3,"lip"],
			[Rect2(46.0,-8.0,3.0,28.0),Y_T4,"lip"],
			[Rect2(49.0,-1.4,4.0,2.8),Y_T4,"grey"]]},
		{"name":"SHOULDER DECK (3) = the lap · rim (4) out south-east (orange)","base":0.0,"tiers":[
			[Rect2(49.0,-14.0,43.0,12.6),Y_DECK,"grey"],
			[Rect2(49.0,1.4,43.0,11.6),Y_DECK,"grey"],
			[Rect2(53.0,-1.4,39.0,2.8),Y_DECK,"grey"],
			[Rect2(49.0,13.0,27.0,1.0),Y_DECK,"grey"],
			[Rect2(76.0,13.0,16.0,1.0),Y_DECK,"lip"]]},
		{"name":"BROKEN STAIR round the neck (slow way)","base":0.0,"tiers":[
			[Rect2(50.0,-14.0,2.0,4.0),Y_DECK+SO,"lip"],
			[Rect2(52.0,-14.0,2.0,4.0),Y_DECK+SO*2.0,"lip"],
			[Rect2(54.0,-14.0,2.0,4.0),Y_DECK+SO*3.0,"lip"],
			[Rect2(56.0,-14.0,2.0,4.0),Y_DECK+SO*4.0,"lip"],
			[Rect2(58.0,-14.0,2.0,4.0),Y_DECK+SO*5.0,"lip"]]},
		{"name":"NECK STUMP (summit) · chimney fins","base":0.0,"tiers":[
			[Rect2(60.0,-14.0,16.0,10.0),Y_NECK,"grey"],
			[Rect2(65.0,-4.0,1.0,4.0),Y_NECK,"grey"],
			[Rect2(68.2,-4.0,1.0,4.0),Y_NECK,"grey"]]},
		{"name":"cover: chest niche (stone, blocks a mouth)","base":0.0,"tiers":[
			[Rect2(60.5,-4.0,3.0,1.6),Y_DECK+2.6,"grey"]]},
		{"name":"STAND-IN: the next isle's catching rim (2 m out past rim 4, 2 m down)","base":0.0,"tiers":[
			[Rect2(72.0,16.0,24.0,18.0),Y_DECK-2.0,"pad"]]},
		{"name":"P thumb perch","base":0.0,"tiers":[
			[Rect2(42.0,22.0,6.0,4.0),11.0,"pad"]]},
	],
	# The summit's stone circle and the tomb chest (the reward), the rope's
	# gantry (STAND-IN for a root cable anchored in the arm) and the cover
	# columns on the lap.
	"cyls":[
		# [middle (x, z), radius, bottom, top, colour]
		[Vector2(68.0,-9.0),3.4,Y_NECK,Y_NECK+0.12,"pad"],
		[Vector2(50.8,10.0),0.9,0.0,Y_DECK+4.5,"grey"],
		[Vector2(57.0,4.0),0.9,0.0,Y_DECK+4.5,"grey"],
		[Vector2(63.0,12.5),0.9,0.0,Y_DECK+4.5,"grey"],
		[Vector2(68.0,3.5),0.9,0.0,Y_DECK+4.5,"grey"],
	],
	"oboxes":[
		# [middle, size, yaw degrees, colour]
		[Vector3(68.0,Y_NECK+0.6,-9.0),Vector3(1.4,1.2,1.0),0.0,"lip"],
		[Vector3(24.5,(Y_END+Y_ANCHOR+0.4)*0.5,-2.4),Vector3(0.8,Y_ANCHOR+0.4-Y_END,0.8),0.0,"dark"],
		[Vector3(34.0,(Y_ELBOW+Y_ANCHOR+0.4)*0.5,-2.4),Vector3(0.8,Y_ANCHOR+0.4-Y_ELBOW,0.8),0.0,"dark"],
		[Vector3(29.25,Y_ANCHOR+0.2,-2.4),Vector3(10.2,0.4,0.8),0.0,"dark"],
		[Vector3(27.0,Y_ANCHOR+0.2,-1.2),Vector3(0.6,0.4,2.8),0.0,"dark"],
	],
	"ramps":[
		# The forearm, a beam walked as a ramp.
		[Vector3(9.0,Y_K3,0.0),Vector3(23.0,Y_END,0.0),5.0,"grey"],
	],
	"ropes":[
		{"anchor":Vector3(27.0,Y_ANCHOR,0.0),"length":ROPE},
	],
	"traps":[
		{"kind":"updraft","rect":Rect2(66.0,-4.0,2.2,4.0),"bottom":Y_DECK,"top":Y_NECK},
	],
	# The real heads, ground-bound (inhaler head round 2), default knobs.
	# The relay is in the placing (Opus pass): head 1 paces the lap and,
	# facing you at the chain-2 stand, blasts you east along z 8; you skid
	# to rest about 19 m on, at x 84.5 to 85 (the "=" station). Head 2 sits
	# 7 m north of that rest, facing south across it: from the stand you are
	# 14 m off and behind its shoulder (unseen), so it doesn't wake early;
	# you fly into its sight in head 1's blast, it notches round while you
	# skid and lie, tells and draws you in, and its own blast (a different
	# source) throws you south off rim (4) onto the next isle.
	"enemies":[
		{"id":"head1","at":Vector3(66.0,Y_DECK,8.0),"face":Vector2(-1.0,0.0),
			"knobs":{"route":[Vector3(64.5,0.0,8.0),Vector3(68.0,0.0,8.0)]}},
		{"id":"head2","at":Vector3(86.0,Y_DECK,1.0),"face":Vector2(0.0,1.0),
			"knobs":{"route":[Vector3(86.0,0.0,1.0)]}},
	],
	"labels":[
		[Vector3(-8.0,2.2,-5.0),"1 · FINGERTIPS · landing rim, the drop is behind you"],
		[Vector3(4.5,Y_K3+2.0,-5.0),"KNUCKLES: jump (1.7), PUMP (2.2), jump (1.6)"],
		[Vector3(16.0,8.8,-3.5),"FOREARM: walk the beam"],
		[Vector3(27.0,Y_ANCHOR+1.6,0.0),"STAND-IN: root cable = plain swing rope on a dark gantry (gap 5.2, 1.6 down)"],
		[Vector3(40.0,Y_T4+2.5,-5.0),"CHEST: four set-offs"],
		[Vector3(51.0,Y_DECK+2.0,0.0),"KICK SHAFT 2.8 wide, 6 tall"],
		[Vector3(60.0,Y_DECK+7.0,5.0),"SHOULDER DECK = THE LAP · two real (ground-bound) inhaler heads"],
		[Vector3(55.0,Y_DECK+3.0,-14.0),"BROKEN STAIR (slow way to the neck)"],
		[Vector3(67.1,Y_DECK+5.0,-2.0),"CHIMNEY 2.2 wide (wall-kick) / STAND-IN updraft: stand still in it"],
		[Vector3(68.0,Y_NECK+2.8,-9.0),"NECK STUMP · tomb chest (reward)"],
		[Vector3(84.0,Y_DECK+2.4,13.5),"EXIT RIM (4): head 2 blasts you out over it"],
		[Vector3(86.0,Y_DECK+5.0,1.0),"HEAD 2 · sits still, facing south over head 1's landing"],
		[Vector3(45.0,12.6,24.0),"P THUMB PERCH (a fall-out catch)"],
		[Vector3(46.0,Y_T4+7.0,-6.0),"CHAIN 1 (accident): head 1 gulps you on the lap, blasts you back DOWN onto the elbow ledge (2) or the chest steps"],
		[Vector3(64.0,Y_DECK+9.0,8.0),"CHAIN 2: stand east of head 1, hold still: gulped, blasted east into head 2's sight, hold still again: out over rim (4)"],
		[Vector3(67.0,Y_NECK+5.0,-2.0),"CHAIN 3: chimney updraft to the summit"],
	],
	"stations":[
		{"key":1,"name":"FINGERTIPS · start","spawn":Vector3(-11.5,0.0,0.0),"face":Vector2(1.0,0.0)},
		{"key":2,"name":"KNUCKLES · jump, pump","spawn":Vector3(-2.2,Y_K1,0.0),"face":Vector2(1.0,0.0)},
		{"key":3,"name":"FOREARM · walk the beam","spawn":Vector3(10.0,Y_K3+(Y_END-Y_K3)/14.0,0.0),"face":Vector2(1.0,0.0)},
		{"key":4,"name":"ELBOW GAP · rope","spawn":Vector3(24.0,Y_END,0.0),"face":Vector2(1.0,0.0)},
		{"key":5,"name":"CHEST set-offs","spawn":Vector3(33.0,Y_ELBOW,0.0),"face":Vector2(1.0,0.0)},
		{"key":6,"name":"KICK SHAFT","spawn":Vector3(47.5,Y_T4,0.0),"face":Vector2(1.0,0.0)},
		{"key":7,"name":"CHAIN 1 · deck west, the accidental fall-back","spawn":Vector3(59.5,Y_DECK,8.0),"face":Vector2(1.0,0.0)},
		{"key":8,"name":"CHAIN 2 · head to head","spawn":Vector3(71.5,Y_DECK,8.0),"face":Vector2(-1.0,0.0)},
		{"key":9,"name":"CHAIN 3 · chimney mouth","spawn":Vector3(67.1,Y_DECK,2.5),"face":Vector2(0.0,-1.0)},
		{"key":10,"name":"NECK SUMMIT","spawn":Vector3(64.0,Y_NECK,-8.0),"face":Vector2(1.0,0.0)},
		{"key":11,"name":"EXIT RIM (4)","spawn":Vector3(79.0,Y_DECK,12.0),"face":Vector2(0.0,1.0)},
		{"key":12,"name":"HEAD 1's LANDING · head 2 alone (hold still)","spawn":Vector3(85.0,Y_DECK,8.0),"face":Vector2(0.0,-1.0)},
		{"key":13,"name":"THUMB PERCH","spawn":Vector3(45.0,11.0,24.0),"face":Vector2(0.0,-1.0)},
	],
}

const VOICES := {
	"head_grind":[0.9,0.0,0.0,1.0,0.07,0.05,13.0],
	"head_inhale":[3.0,0.0,0.0,1.0,0.22,0.9,0.0],
	"head_yank":[0.35,0.0,0.0,1.0,0.4,0.01,0.0],
	"head_gulp":[0.45,70.0,40.0,0.4,0.15,0.005,0.0],
	"head_blast":[0.9,0.0,0.0,1.0,0.55,0.005,0.0],
}

var enemies: Node
var pieces: Node3D
var traps: Node3D
var heads: Array = []
var vents: Array = []
var _voices := {}
var _head_knobs := {}

## Steps the foot pieces (the rope), the traps and the enemies, and hides
## the figure while a head holds him.
class Slot extends Node:
	var parts: Array = []
	var study: Node3D
	func before(delta: float) -> void:
		for p: Node in parts: p.before(delta)
	func after(delta: float, events: Dictionary) -> void:
		for p: Node in parts: p.after(delta,events)
	func pose(figure: Node3D) -> void:
		for p: Node in parts: p.pose(figure)
		var held := false
		for e in study.enemies.enemies:
			if is_instance_valid(e) and e.get("swallowed"): held = true
		figure.visible = not held

## A stand-in updraft in the chimney throat (the card's kit ask): stood
## still on its floor for a moment, whatever stands there, stunned or not,
## is tossed up to the summit. A thermal for the sail as well.
class Updraft extends "res://scripts/traps/trap.gd":
	var rect := Rect2()
	var bottom := 0.0
	var top := 0.0
	var _still := 0.0
	var _cool := 0.0
	var _armed := true
	var launches := 0
	func _init() -> void:
		super()
		trap_name = "updraft_standin"
	func build() -> void:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(rect.size.x,top-bottom,rect.size.y)
		m.mesh = b
		var mat := paint(Color(0.45,0.7,0.95,0.22))
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.material_override = mat
		m.position = Vector3(rect.get_center().x,(top+bottom)*0.5,rect.get_center().y)
		add_child(m)
	func inside(p: Vector3) -> bool:
		return rect.has_point(Vector2(p.x,p.z)) and p.y >= bottom-0.3 and p.y <= top
	func air_at(p: Vector3) -> Dictionary:
		return {"thermal":4.0} if inside(p) else {}
	func before(delta: float) -> void:
		_cool = maxf(0.0,_cool-delta)
		if motor == null: return
		if not inside(motor.feet): _armed = true
		if _armed and inside(motor.feet) and motor.grounded and motor.speed() < 0.6 and _cool <= 0.0:
			_still += delta
			if _still > 0.35:
				_still = 0.0
				_cool = 1.5
				_armed = false
				launches += 1
				motor.toss(Vector3(0.0,sqrt(2.0*motor.gravity*(top-motor.feet.y+0.9)),0.0))
		else: _still = 0.0
	func reset() -> void:
		super()
		_still = 0.0
		_cool = 0.0
		_armed = true

func _ready() -> void:
	pack = "sunken_giant"
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--head-knob="):
			var kv: String = arg.trim_prefix("--head-knob=")
			_head_knobs[kv.get_slice("=",0)] = float(kv.get_slice("=",1))
	super._ready()

func _load_pack() -> void:
	var first: Dictionary = LAYOUT.stations[0]
	start = first.spawn
	start_face = first.face
	lost = -25.0
	_last_stood = start
	var parts := []
	for mass: Dictionary in LAYOUT.masses:
		for t: Array in mass.tiers:
			parts.append(["box",t[0],mass.base,t[1],t[2]])
		var r: Rect2 = mass.tiers[0][0]
		parts.append(["label",Vector3(r.get_center().x,float(mass.tiers[0][1])+0.9,r.position.y-0.6),mass.name])
	for c: Array in LAYOUT.cyls: parts.append(["cyl",c[0],c[1],c[2],c[3],c[4]])
	for o: Array in LAYOUT.oboxes: parts.append(["obox",o[0],o[1],o[2],o[3]])
	for ramp: Array in LAYOUT.ramps: parts.append(["ramp",ramp[0],ramp[1],ramp[2],ramp[3]])
	for l: Array in LAYOUT.labels: parts.append(["label",l[0],l[1]])
	stations = []
	for s: Dictionary in LAYOUT.stations:
		var st := {"key":s.key,"name":s.name,"spawn":s.spawn,"face":s.face,"sign":(s.spawn as Vector3)+Vector3(0.0,3.0,0.0),"parts":[]}
		if stations.is_empty(): st.parts = parts
		stations.append(st)

func _build_room() -> void:
	super._build_room()
	# The rope (foot pieces), the traps and the heads, stepped as one slot.
	pieces = FootPieces.new()
	pieces.study = self
	pieces.motor = motor
	add_child(pieces)
	for r: Dictionary in LAYOUT.ropes: pieces.rope(r.anchor,r.length)
	traps = TrapField.new()
	traps.study = self
	traps.motor = motor
	add_child(traps)
	for t: Dictionary in LAYOUT.traps:
		var v := Updraft.new()
		v.rect = t.rect
		v.bottom = t.bottom
		v.top = t.top
		traps.add(v)
		vents.append(v)
	enemies = EnemyField.new()
	enemies.study = self
	enemies.motor = motor
	enemies.lost = lost
	enemies.sound_hook = _voice
	add_child(enemies)
	_spawn_heads()
	var slot := Slot.new()
	slot.study = self
	slot.parts = [pieces,traps,enemies]
	add_child(slot)
	foot_pieces = slot
	motor.air = _air

func _spawn_heads() -> void:
	heads = []
	for e: Dictionary in LAYOUT.enemies:
		var knobs: Dictionary = (e.knobs as Dictionary).duplicate()
		knobs.merge(_head_knobs,true)
		heads.append(enemies.spawn(InhalerHead,e.at,e.face,knobs))

## The air at `p`: the traps' (the stand-in thermal) and the heads' draw
## for the pocket sail.
func _air(p: Vector3) -> Dictionary:
	var out: Dictionary = traps._air(p) if traps != null else {}
	if enemies == null: return out
	var wind := Vector3.ZERO
	for h in enemies.enemies:
		if is_instance_valid(h) and h.has_method("sail_wind"): wind += h.sail_wind(p)
	if wind != Vector3.ZERO:
		out["wind"] = (out.get("wind",Vector3.ZERO) as Vector3)+wind
	return out

## Set down: the rope, traps and heads as built.
func place(at: Vector3, face: Vector2) -> void:
	super.place(at,face)
	if enemies != null:
		enemies.reset()
		heads = []
		for e in enemies.enemies:
			if is_instance_valid(e) and e.has_method("mouth"): heads.append(e)
	if traps != null: traps.reset()
	if figure != null: figure.visible = true

func _hint_text() -> String:
	return "GREYBOX Sunken Giant: 1 start 2 knuckles 3 forearm 4 rope gap 5 chest 6 kick shaft 7 chain 1 8 chain 2 9 chimney 0 summit - exit rim = head 1's landing [ perch · R start · F1 numbers · Esc mouse"

func _show_hud() -> void:
	super._show_hud()
	if _hud == null or not _hud.visible or enemies == null: return
	var lines := PackedStringArray([_hud.text,""])
	var i := 1
	for h in heads:
		if is_instance_valid(h):
			lines.append("head %d  %s %.1fs · draw %.2f · pull %.1f · gulps %d blasts %d · at %s face %.0f°" % [i,h.state,h.state_t,h.draw_share,h.pulling,h.gulps,h.blasts,str(h.position.snapped(Vector3.ONE*0.1)),rad_to_deg(h.facing)])
		i += 1
	for v in vents: lines.append("updraft stand-in launches %d" % v.launches)
	_hud.text = "\n".join(lines)

func _voice(sound_name: StringName, at: Vector3) -> void:
	var key := String(sound_name)
	if not VOICES.has(key): return
	if not _voices.has(key): _voices[key] = EnemyYard._synth(VOICES[key])
	var player := AudioStreamPlayer3D.new()
	player.stream = _voices[key]
	player.position = at
	player.unit_size = 12.0
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
