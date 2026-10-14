extends "res://studies/character_study.gd"
## GREYBOX, Opus pass: the Washing Rite (docs/design/roguelike/brainstorm/
## round1/motif-m5-washing-rite.md, "Greybox (Opus pass)"). A drowned
## forecourt; a walled pilgrims' lane funnelling into the gate of a long
## channel with the REAL Sluice Flush (scripts/traps/trap_sluice.gd) in it,
## on a timer: the channel floor is the plate (a pilgrim's weight in it for
## PERIOD s and the gate opens); refuge piers along it; a gulf at its open
## end that the wave's carried jump plus a twirl clears; the shrine terrace a
## storey down beyond. The real Plinth Ram herds pilgrims down the lane, the
## real Headless Body walks it toward its head (the Inhaler Head on the exit
## rim) and the gate's lintel stops it; horn, gable, altar, frieze and the
## layer below are labelled STAND-INs.
##   godot --path . res://studies/greybox/washing_rite.tscn -- --no-title
##     [--no-ram] [--no-body] [--no-head]   (leave an enemy out)
##   number keys: 1 start, 2 refuge pier, 3 the channel mouth, 4 the channel,
##   5 the terrace, 6 chain 1 (ram), 7 chain 2 (speed route), 8 chain 3 (body),
##   9 the horn, 0 the exit rim.  R start (traps and enemies rebuilt), F1 numbers.
##   Each station brings its own cast (`cast` in the enemies' entries): 6 the
##   ram, 8 the body, 1 everyone, the rest the head alone.
##
## THE LAYOUT IS ONE TABLE (`LAYOUT`) so a later turf pass can rebuild it with
## KitLand.island(spec): every isle is ONE entry with tiers (rect, top), every
## wall a segment, every piece its place and facing. World frame: x east (the
## channel runs +x from the gate at x = 0), z across (south +), y up. Sizes
## from the pilot's real numbers at the wanderer's size 1 (Trap.pilot(): walk
## 2.4, run 4.8, jump 0.8 high; the sluice's defaults: wave 9.6 m/s, 3.6 m
## long, 0.6 high, a 1.5 m channel between 0.4 x 0.42 m parapets).
const Trap = preload("res://scripts/traps/trap.gd")
const TrapField = preload("res://scripts/traps/trap_field.gd")
const Sluice = preload("res://scripts/traps/trap_sluice.gd")
const Wind = preload("res://scripts/traps/trap_wind.gd")
const EnemyField = preload("res://scripts/enemies/enemy_field.gd")
const PlinthRam = preload("res://scripts/enemies/plinth_ram.gd")
const HeadlessBody = preload("res://scripts/enemies/headless_body.gd")
const InhalerHead = preload("res://scripts/enemies/inhaler_head.gd")

## The channel's floor (m); the gulf at its open end (m) and the terrace's
## top under the channel floor. Measured (the card's Opus pass): the wave's
## carried jump + a twirl clears 9.5 m onto a terrace 1.5 m down under
## +-0.2 s of jitter; a plain carried jump, a spill, and a chained long jump
## (9.1 m at best) fall short; a chained long jump + a perfect twirl reaches
## about 10.5 (a skilled second way).
const CH_LEN := 36.0
const GULF := 9.5
const T_TOP := -1.5
const X_T := CH_LEN+GULF
const EXIT_GAP := 18.0
const UNDER := -6.0
const SWIM_BED := -1.6
const WADE_BED := -0.5
const WATER_TOP := -0.05
## Seconds of a pilgrim's weight in the channel before the gate opens (the
## sluice's `period`, its `trigger` "timer"): a knocked body landing in it
## sets it off, as does walking in.
const PERIOD := 0.5
## Where the rider is told to jump: this far (m) before the channel's end.
const JUMP_MARK := 1.5

const LAYOUT := {
	## Each isle: ONE terrain mass, its tiers [Rect2 (x, z), top, colour].
	"isles": [
		{"name":"forecourt","tiers":[
			[Rect2(-40.0,-14.0,16.0,28.0),0.0,"floor"],                   # the rim (start)
			[Rect2(-24.0,-14.0,5.0,28.0),SWIM_BED,"dark"],                # the moat (swim)
			[Rect2(-19.0,-14.0,5.0,28.0),WADE_BED,"dark"],                # the wading floor
			[Rect2(-14.0,-14.0,14.0,11.0),WADE_BED,"dark"],
			[Rect2(-14.0,3.0,14.0,11.0),WADE_BED,"dark"],
			[Rect2(-15.0,-3.0,1.0,6.0),-0.25,"grey"],                     # a half step up
			[Rect2(-14.0,-3.0,14.0,6.0),0.0,"floor"],                     # the pilgrims' lane
		]},
		{"name":"shrine terrace","tiers":[
			[Rect2(X_T,-9.0,15.0,18.0),T_TOP,"floor"],
			[Rect2(X_T+6.0,-1.5,3.0,3.0),T_TOP+0.8,"lip"],                # STAND-IN: tomb chest altar
			[Rect2(X_T+13.0,-8.0,1.5,16.0),T_TOP+3.5,"wall"],             # STAND-IN: rose gable, the horn's wall
		]},
		{"name":"exit rim","tiers":[
			[Rect2(X_T+15.0+EXIT_GAP,-5.0,10.0,10.0),T_TOP-1.0,"pad"],
		]},
		{"name":"layer below","tiers":[                                   # STAND-IN: the soft fail
			[Rect2(CH_LEN-8.0,-14.0,GULF+EXIT_GAP+40.0,28.0),-9.0,"dark"],
		]},
	],
	## Walls [from (x, z), to (x, z), bottom, top, thickness, colour]: the
	## lane's funnel into the gate (a shove at up to 30 deg slides along it
	## into the throat), the gate's throat (the first 8 m of the channel
	## walled over its parapets, so a knock can't leave it), and the gate's
	## lintel (2.5 m up: a pilgrim passes under, the body's chest ray meets
	## it and it stops at the gate).
	"walls": [
		[Vector2(0.2,-0.95),Vector2(-6.0,-2.5),0.0,2.4,0.4,"wall"],
		[Vector2(0.2,0.95),Vector2(-6.0,2.5),0.0,2.4,0.4,"wall"],
		[Vector2(0.0,-0.95),Vector2(8.0,-0.95),0.0,2.4,0.4,"wall"],
		[Vector2(0.0,0.95),Vector2(8.0,0.95),0.0,2.4,0.4,"wall"],
		[Vector2(0.0,-2.2),Vector2(0.0,2.2),2.5,4.5,1.2,"wall"],
	],
	## [Rect2 (x, z), bottom, top]: the wading basin and moat.
	"water": [[Rect2(-24.0,-14.0,24.0,28.0),SWIM_BED-0.1,WATER_TOP]],
	## The real sluice. Its frame: origin at the gate, route down -z turned to
	## +x world (yaw -90). Refuges [m down the channel, side +1 = south].
	"channel": {"at":Vector3(0.0,0.0,0.0),"yaw":-90.0,"knobs":{
		"length":CH_LEN,"gap":GULF,"beyond":0.0,"end":"open","trigger":"timer","period":PERIOD,
		"refuges":[[9.0,1.0],[18.0,-1.0],[27.0,1.0]],
	}},
	## STAND-IN horn: the wind vent (blows +x, east, off the terrace's mouth).
	"horns": [{"at":Vector3(X_T+10.0,T_TOP,2.0),"yaw":0.0,"knobs":{"count":1,"on":3.0,"off":2.0}}],
	## Real enemies: kind, place, facing (x, z), and the stations that cast
	## them (none listed: every station). The head is the body's bait; the
	## body hears it from the forecourt (`hear` raised for this isle, see the
	## card).
	"enemies": [
		{"kind":"ram","at":Vector3(-12.5,0.0,0.0),"face":Vector2(1.0,0.0),"cast":[1,6]},
		{"kind":"body","at":Vector3(-36.0,0.0,-10.0),"face":Vector2(1.0,0.0),"cast":[1]},
		{"kind":"body","at":Vector3(-12.0,0.0,0.0),"face":Vector2(1.0,0.0),"cast":[8]},
		{"kind":"head","at":Vector3(X_T+15.0+EXIT_GAP+8.0,T_TOP-1.0,-3.0),"face":Vector2(-1.0,0.0)},
	],
	## Number-key stations: key, name, feet, facing (x, z).
	"stations": [
		{"key":1,"name":"Start: the forecourt rim","at":Vector3(-34.0,0.0,0.0),"face":Vector2(1.0,0.0)},
		{"key":2,"name":"Refuge pier 1 (0.8 m up, south of the channel)","at":Vector3(9.0,0.8,1.25),"face":Vector2(1.0,0.0)},
		{"key":3,"name":"The channel mouth (step in: the gate opens)","at":Vector3(-1.0,0.0,0.0),"face":Vector2(1.0,0.0)},
		{"key":4,"name":"The channel (12 m down)","at":Vector3(12.0,0.0,0.0),"face":Vector2(1.0,0.0)},
		{"key":5,"name":"The shrine terrace","at":Vector3(X_T+2.0,T_TOP,0.0),"face":Vector2(1.0,0.0)},
		{"key":6,"name":"Chain 1: the ram (lane, facing it; let it hit you)","at":Vector3(-3.0,0.0,0.0),"face":Vector2(-1.0,0.0)},
		{"key":7,"name":"Chain 2: the speed route (walk in, ride, jump at the mark, twirl, Q, sail)","at":Vector3(-1.0,0.0,0.0),"face":Vector2(1.0,0.0)},
		{"key":8,"name":"Chain 3: the body (lane, facing it; let it walk into you)","at":Vector3(-2.0,0.0,0.0),"face":Vector2(-1.0,0.0)},
		{"key":9,"name":"The horn (terrace, facing the gable)","at":Vector3(X_T+8.0,T_TOP,5.0),"face":Vector2(1.0,0.0)},
		{"key":10,"name":"The exit rim","at":Vector3(X_T+15.0+EXIT_GAP+3.0,T_TOP-1.0,3.0),"face":Vector2(-1.0,0.0)},
	],
	## Floating labels [place, text].
	"labels": [
		[Vector3(-34.0,1.6,-3.0),"1 ARRIVE: drowned forecourt, wade and swim, low stakes"],
		[Vector3(-21.5,1.0,0.0),"moat (swim)"],
		[Vector3(-13.0,1.0,-8.0),"wading floor"],
		[Vector3(-9.0,1.6,-2.4),"THE PILGRIMS' LANE: the ram herds you into the gate (chain 1), the body shoves you in (chain 3)"],
		[Vector3(-4.5,2.8,0.0),"FUNNEL: a knock slides along it into the throat"],
		[Vector3(0.0,5.0,0.0),"GATE LINTEL (2.5 m): pilgrims pass under, the body stops here"],
		[Vector3(2.0,3.0,0.0),"SLUICE (real trap) on a timer: %.1f s of weight in the channel, 2 s tell, then the wave" % PERIOD],
		[Vector3(4.0,2.8,-1.6),"THROAT: walled 8 m"],
		[Vector3(9.0,2.2,2.6),"PIER 1: hold ground (0.8 m)"],
		[Vector3(18.0,2.2,-2.6),"PIER 2"],
		[Vector3(27.0,2.2,2.6),"PIER 3"],
		[Vector3(CH_LEN-JUMP_MARK,2.2,0.0),"JUMP HERE (Space), then twirl (X): carried"],
		[Vector3(CH_LEN+GULF*0.5,1.2,0.0),"GULF %.1f m, terrace 1.5 m down: the wave's jump + twirl clears it" % GULF],
		[Vector3(X_T+3.0,T_TOP+2.0,-6.0),"2 SHRINE TERRACE"],
		[Vector3(X_T+7.5,T_TOP+2.4,0.0),"STAND-IN: tomb chest altar (last pilgrim's oars)"],
		[Vector3(X_T+10.0,T_TOP+2.6,2.0),"STAND-IN: wind horn (a wind vent; the real lift is your Q, charged by the ride)"],
		[Vector3(X_T+13.7,T_TOP+4.2,0.0),"STAND-IN: rose gable (3.5 m). CHAIN 2: land, Q up (stick still), Space to sail, glide east"],
		[Vector3(X_T+15.0+EXIT_GAP*0.5,T_TOP+0.5,0.0),"glide gap (east rim, 1 m lower)"],
		[Vector3(X_T+15.0+EXIT_GAP+5.0,T_TOP+0.6,3.0),"EXIT RIM (the head, the body's bait, heaves here)"],
		[Vector3(CH_LEN+GULF*0.5,-7.5,0.0),"STAND-IN: the layer below (soft fail), R to leave"],
		[Vector3(-12.0,2.4,9.0),"STAND-IN: floating stones, rune frieze, half-sunk head (art, not built)"],
	],
}

var traps: Node3D
var sluice: Node3D
var enemies: Node
var _mux: Node
var _args := {}
## Counted for F1: frames the stand-in carry has moved an enemy.
var enemies_carried := 0

## Steps the traps and the enemies in the study's one `foot_pieces` slot, and
## (STAND-IN, the card's kit ask) carries any enemy standing in a wave.
class Mux extends Node:
	var rite: Node
	func before(delta: float) -> void:
		rite.traps.before(delta)
		rite.enemies.before(delta)
		rite.carry_enemies(delta)
	func after(delta: float, events: Dictionary) -> void:
		rite.traps.after(delta,events)
		rite.enemies.after(delta,events)
	func pose(figure: Node3D) -> void:
		rite.sluice.pose(figure)
		var held := false
		for e in rite.enemies.enemies:
			if is_instance_valid(e) and e.get("swallowed"): held = true
		figure.visible = not held

func _ready() -> void:
	pack = "washing_rite"
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--no-"): _args[arg.trim_prefix("--no-")] = true
	super._ready()

func _load_pack() -> void:
	var s0: Dictionary = LAYOUT.stations[0]
	start = s0.at
	start_face = s0.face
	lost = -30.0
	_last_stood = start
	var parts := []
	for isle: Dictionary in LAYOUT.isles:
		for t: Array in isle.tiers:
			parts.append(["box",t[0],UNDER if float(t[1]) > -8.0 else -14.0,t[1],t[2]])
	for w: Array in LAYOUT.walls:
		var a: Vector2 = w[0]
		var b: Vector2 = w[1]
		var d := b-a
		var lo := float(w[2])
		var hi := float(w[3])
		parts.append(["obox",Vector3((a.x+b.x)*0.5,(lo+hi)*0.5,(a.y+b.y)*0.5),Vector3(d.length(),hi-lo,float(w[4])),rad_to_deg(atan2(-d.y,d.x)),w[5]])
	for w: Array in LAYOUT.water: parts.append(["water",w[0],w[1],w[2]])
	for l: Array in LAYOUT.labels: parts.append(["label",l[0],l[1]])
	stations = []
	for s: Dictionary in LAYOUT.stations:
		stations.append({"key":s.key,"name":s.name,"spawn":s.at,"face":s.face,"sign":s.at+Vector3(0.0,3.6,0.0),
			"parts":parts if stations.is_empty() else []})

func _build_room() -> void:
	super._build_room()
	traps = TrapField.new()
	add_child(traps)
	traps.attach(self)
	var ch: Dictionary = LAYOUT.channel
	sluice = Sluice.new()
	sluice.configure(ch.knobs)
	sluice.position = ch.at
	sluice.rotation.y = deg_to_rad(float(ch.yaw))
	traps.add(sluice)
	for h: Dictionary in LAYOUT.horns:
		var horn: Node3D = Wind.new()
		horn.configure(h.knobs)
		horn.position = h.at
		horn.rotation.y = deg_to_rad(float(h.yaw))
		traps.add(horn)
	enemies = EnemyField.new()
	enemies.study = self
	enemies.motor = motor
	enemies.lost = lost
	add_child(enemies)
	_mux = Mux.new()
	_mux.rite = self
	add_child(_mux)
	foot_pieces = _mux
	cast(1)

## The enemies station `key` brings (each entry's `cast`, none listed: all),
## all else cleared; `--no-<kind>` leaves a kind out.
func cast(key: int) -> void:
	enemies.clear()
	for e: Dictionary in LAYOUT.enemies:
		var kind: String = e.kind
		if _args.has(kind) or (kind == "head" and _args.has("body") and _args.has("head")): continue
		if e.has("cast") and not (e.cast as Array).has(key): continue
		match kind:
			"ram": enemies.spawn(PlinthRam,e.at,e.face)
			"body": enemies.spawn(HeadlessBody,e.at,e.face,{"hear":ground.head_top*130.0})
			"head": enemies.spawn(InhalerHead,e.at,e.face,{"ring":ground.head_top*3.0})

func place(at: Vector3, face: Vector2) -> void:
	if traps != null: traps.reset()
	super.place(at,face)
	if enemies != null:
		var key := 1
		for s: Dictionary in LAYOUT.stations:
			if (s.at as Vector3).is_equal_approx(at): key = s.key
		cast(key)
	if figure != null: figure.visible = true

## STAND-IN: the wave carrying enemies. The real sluice only carries the
## pilot's motor; an enemy standing in a wave (the ram, if it follows you
## down the throat) is moved down the channel at the wave's pace (clipped to
## its front) and, past the open end, tossed off it.
func carry_enemies(delta: float) -> void:
	if sluice == null or sluice.state != Sluice.FLOWING: return
	var speed := float(sluice.knob("speed"))
	for e in enemies.enemies:
		if not is_instance_valid(e) or e.gone or not e.grounded: continue
		var local: Vector3 = sluice.to_local(e.global_position)
		if not sluice.in_wave(local): continue
		var down: Vector3 = sluice._down()
		var span: Dictionary = sluice._wave_at(local)
		var step := clampf(local.z-float(span.front),0.0,speed*delta)
		if not sluice.on_floor(-local.z+step):
			e.vel = Vector3(down.x*speed,3.0,down.z*speed)
			e.grounded = false
		else:
			e.position += down*step
		enemies_carried += 1
		e.body.force_update_transform()

func _hint_text() -> String:
	return "Washing rite: step into the channel (3) and the gate opens; hold a pier (2) or ride the wave, Space at the mark, X twirl · 1-9,0 stations · R start · F1 numbers · Esc mouse"

func _show_hud() -> void:
	super._show_hud()
	if not _hud.visible or sluice == null: return
	var st: String = ["idle","TELL","FLOWING"][sluice.state]
	_hud.text += "\nsluice %s · weight %.1f/%.1fs · waves %d · carried %.1fs · rides %d · spills %d · enemies carried %d · feet x %.1f y %.2f" % [st,sluice.waited,PERIOD,sluice.waves_run,sluice.swept,sluice.rides,sluice.spills,enemies_carried,motor.feet.x,motor.feet.y]
