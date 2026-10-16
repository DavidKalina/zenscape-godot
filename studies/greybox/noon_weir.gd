extends "res://studies/character_study.gd"
## GREYBOX: the Noon Weir: three stacked channels with a sluice gate each on
## one shared clock, a stair up beside each, a bridge from each stair's top
## back along the channel to its open end, a bell floor on top, the plinth
## ram on the middle tier's gate landing, and a cannon on a neighbouring isle
## aimed down the top channel. Grey is structure, green a landing, orange a
## lip. Played with the real pilot and the real trap_sluice.gd /
## plinth_ram.gd / cannon_field.gd; STAND-INs are labelled in the world (see
## the card's "Greybox (Opus pass)" section).
##
## ALL OF THE LAYOUT IS IN `LAYOUT` below (the later turf pass reads it).
## z runs north; every channel flows SOUTH (-z) from its gate (north end) to
## its open end (south): you walk a channel from its open end north, against
## the water, to the gate, and take the stair beside it. Each tier's open end
## hangs over the tier below so its spill lands a body well down the lower
## channel, upstream of nothing but the lower wave.
##   1 start deck  2 tier-1 gate head  3 stair-1 top  4 bridge 1 / hop in
##   5 tier-2 gate landing (the ram)  6 stair-2 top  7 bridge 2 / hop in
##   8 tier-3 gate head (top landing)  9 bell floor
##   0 chain 1 "the dodge that wasn't"   - chain 2 "ride the Noon Flood" (in
##   the top channel)   = chain 2, waiting on the top landing   [ chain 3,
##   the cannon isle (Y climbs in, A fires you at its rest aim)
##   N (key) the clock to a few seconds before the noon tells · R start
##   godot --path . res://studies/greybox/noon_weir.tscn -- --no-title
##     [--base=8] (s, the shortest gate's period) [--ratio=1:2:3]
##     [--offsets=a:b:c] (s each gate opens after noon; default derived from
##     the layout: each lower gate opens HOLD s after the upper spill lands)
##     [--hold=0.6] [--sluice-knob=<key>=<value>] (repeatable, all tiers)
##     [--no-ram] [--no-noon-double]
const Trap = preload("res://scripts/traps/trap.gd")
const TrapField = preload("res://scripts/traps/trap_field.gd")
const Sluice = preload("res://scripts/traps/trap_sluice.gd")
const EnemyField = preload("res://scripts/enemies/enemy_field.gd")
const PlinthRam = preload("res://scripts/enemies/plinth_ram.gd")
const CannonField = preload("res://scripts/cannon/cannon_field.gd")
const Cannon = preload("res://scripts/cannon/cannon.gd")

## The layout. Every position is world (x, y, z), every rect (x, z, size x,
## size z). A tier is one sluice channel: `gate` its trap origin (the gate,
## north end; the channel runs `length` m south), `y` its floor top.
## Stacking rule (measured): a spill throws a body about 11 m out along the
## channel on a 12 m fall, so each tier's open end sits about 11 m north of
## where the body should land in the tier below (well down that channel,
## out of the ram's notice from its landing).
const LAYOUT := {
	"width":3.0,
	"tiers":[
		{"name":"tier 1 (low, period x1)","gate":Vector3(0.0,0.0,0.0),"length":20.0,"mult":1,"refuge":10.0},
		{"name":"tier 2 (middle, x2, the ram's lane)","gate":Vector3(0.0,12.0,29.5),"length":24.0,"mult":2,"refuge":12.0,"parapet":Vector2(0.4,1.0),"refuge_top":1.2,"wave_length":8.0},
		{"name":"tier 3 (top, x3)","gate":Vector3(0.0,24.0,49.5),"length":20.0,"mult":3,"refuge":10.0},
	],
	## [name, rect, top, bottom, colour]
	"slabs":[
		["start deck / exit rim stand-in",Rect2(-8.0,-44.0,16.0,21.6),0.0,-2.0,"pad"],
		["gate head 1",Rect2(-14.0,0.0,18.0,6.0),0.0,-2.0,"grey"],
		["stair-1 top",Rect2(-14.0,-30.0,11.8,6.0),12.0,10.0,"grey"],
		["bridge 1 (rope-bridge stand-in)",Rect2(-4.4,-30.0,2.2,44.0),12.0,11.0,"grey"],
		["gate landing 2 (the ram's)",Rect2(-14.0,29.5,18.0,6.0),12.0,10.0,"grey"],
		["stair-2 top",Rect2(-14.0,-0.5,11.8,6.0),24.0,22.0,"grey"],
		["bridge 2 (rope-bridge stand-in)",Rect2(-4.4,-0.5,2.2,37.0),24.0,23.0,"grey"],
		["gate head 3 (top landing)",Rect2(-14.0,49.5,18.0,8.0),24.0,22.0,"grey"],
		["bell floor (belfry stand-in)",Rect2(-4.0,57.5,8.0,5.0),25.2,22.0,"lip"],
		["cannon isle (the neighbouring isle)",Rect2(-5.0,66.0,10.0,10.0),32.0,30.0,"pad"],
	],
	## [name, low middle edge, high middle edge, width]
	"stairs":[
		["stair 1 (grand_stair stand-in)",Vector3(-12.0,0.0,0.0),Vector3(-12.0,12.0,-24.0),4.0],
		["stair 2 (grand_stair stand-in)",Vector3(-12.0,12.0,29.5),Vector3(-12.0,24.0,5.5),4.0],
	],
	## [kind, position, facing (x, z)]
	"enemies":[
		["ram",Vector3(0.0,12.0,33.0),Vector2(0.0,-1.0)],
	],
	## The cannon on the neighbouring isle: its base, heading (0 fires -z,
	## down the top channel) and its rest aim (pitch, power notch: the
	## cannon's own defaults, so climbing in and firing needs no aiming);
	## `target` is where that aim should land (checked, labelled).
	"cannon":{"at":Vector3(0.0,32.0,70.0),"heading":0.0,"pitch":40.0,"notch":2,"target":Vector3(0.0,24.0,46.0)},
	## [key, name, spawn, facing, clock] clock: -1 the start of the day, else
	## "noon_in": seconds before the first noon TELL (so the flush is tell
	## seconds later); "tell2_in": seconds before tier 2's first tell.
	"stations":[
		{"key":1,"name":"Start deck (run up, hop the 2.4 m gap into tier 1)","spawn":Vector3(0.0,0.0,-34.0),"face":Vector2(0.0,1.0)},
		{"key":2,"name":"Tier-1 gate head (stair 1 starts here)","spawn":Vector3(-10.0,0.0,3.0),"face":Vector2(0.0,-1.0)},
		{"key":3,"name":"Stair-1 top (bridge east to tier 2)","spawn":Vector3(-12.0,12.0,-27.0),"face":Vector2(1.0,0.0)},
		{"key":4,"name":"Bridge 1 end (hop the parapet into tier 2)","spawn":Vector3(-3.3,12.0,12.0),"face":Vector2(0.0,1.0)},
		{"key":5,"name":"Tier-2 gate landing (the ram's; stair 2 starts here)","spawn":Vector3(-10.0,12.0,33.0),"face":Vector2(0.0,-1.0)},
		{"key":6,"name":"Stair-2 top (bridge east to tier 3)","spawn":Vector3(-12.0,24.0,2.5),"face":Vector2(1.0,0.0)},
		{"key":7,"name":"Bridge 2 end (hop the parapet into tier 3)","spawn":Vector3(-3.3,24.0,34.0),"face":Vector2(0.0,1.0)},
		{"key":8,"name":"Tier-3 gate head (the top landing)","spawn":Vector3(-6.0,24.0,53.0),"face":Vector2(0.0,-1.0)},
		{"key":9,"name":"Bell floor (STAND-IN, no bell)","spawn":Vector3(0.0,25.2,60.0),"face":Vector2(0.0,-1.0)},
		{"key":10,"name":"CHAIN 1: the dodge that wasn't (walk N at the ram as tier 2 tells)","spawn":Vector3(0.0,12.0,16.5),"face":Vector2(0.0,1.0),"tell2_in":1.6},
		{"key":11,"name":"CHAIN 2: ride the Noon Flood (in tier 3, 1 s to the flush)","spawn":Vector3(0.0,24.0,47.5),"face":Vector2(0.0,-1.0),"noon_in":1.0},
		{"key":12,"name":"CHAIN 2: wait on the top landing; run in when the gate tells","spawn":Vector3(0.0,24.0,53.0),"face":Vector2(0.0,-1.0),"noon_in":6.0},
		{"key":13,"name":"CHAIN 3: the cannon isle (Y in, A fires you down the top channel)","spawn":Vector3(0.0,32.0,73.0),"face":Vector2(0.0,-1.0),"noon_in":4.0},
	],
	## Floating labels: [position, text]
	"labels":[
		[Vector3(0.0,3.5,-28.0),"TIER 1 open end (walk N, against the water)"],
		[Vector3(0.0,3.0,-3.0),"gate 1 - stair 1 beside it (west)"],
		[Vector3(-12.0,6.0,-12.0),"STAIR 1 (STAND-IN for grand_stair, 26.6 deg)"],
		[Vector3(-8.0,15.0,-14.0),"BRIDGE 1 - STAND-IN rope bridge (keeps the lip and the tier-1 spill clear)"],
		[Vector3(-3.3,15.0,12.0),"hop the parapet here into tier 2"],
		[Vector3(0.0,15.5,14.0),"TIER 2 (the ram's lane, 24 m: a knock from the gate end stays in the channel)"],
		[Vector3(0.0,15.0,34.0),"RAM's landing: it charges S down the channel at anyone walking up it"],
		[Vector3(-12.0,18.0,17.0),"STAIR 2"],
		[Vector3(-3.3,27.0,36.0),"hop the parapet here into tier 3"],
		[Vector3(0.0,27.5,42.0),"TIER 3 (top, longest period)"],
		[Vector3(-4.0,27.0,54.0),"top landing: wait for noon, run in on the tell (key =)"],
		[Vector3(0.0,29.0,60.0),"STAND-IN: bell (ring-on-landing noise not built)"],
		[Vector3(-8.0,13.5,36.0),"NOT BUILT: tower_shell wall-kick chimney (card beat 4)"],
		[Vector3(8.0,12.0,16.0),"NOT BUILT: falling-water sheet between tiers (kit ask 2)"],
		[Vector3(6.0,6.0,-6.0),"tier-2 spill lands here (chain 1 / 2): a floor lower"],
		[Vector3(6.0,18.0,18.5),"tier-3 spill lands here (chain 2 / 3), 11 m below the ram's landing"],
		[Vector3(6.0,3.0,-25.0),"tier-1 spill lands here: the exit rim (STAND-IN: the start deck)"],
		[Vector3(0.0,36.0,70.0),"CHAIN 3: real cannon, rest aim (STAND-IN for the catch: you climb in; it cannot catch a thrown body)"],
		[Vector3(-6.0,6.0,38.0),"STAND-IN: shared clock (day clock below, HUD)"],
	],
}

const LOST_Y := -40.0
const TELL_TIME := 2.0
## Seconds each lower gate opens after the upper spill's body lands in its
## channel: an early body lies dry and waits, a late one still has
## HOLD + (its distance down the channel + the wave's length) / speed.
const HOLD := 0.6

var traps: Node3D
var enemies: Node
var cannons: Node3D
var sluices: Array = []
## The shared clock (STAND-IN): seconds into the day, the base period of the
## shortest gate, each gate's period multiple and offset after noon, and the
## next time each tier's TELL starts.
var day := 0.0
var base := 8.0
var hold := HOLD
var mults: Array = [1,2,3]
var offsets: Array = [0.0,0.0,0.0]
var next_tell: Array = [0.0,0.0,0.0]
## Whether each tier's current flush is the noon one (a double surge).
var noon_flush: Array = [false,false,false]
var _offsets_given := false
var _noon_double := true
var _preset := {}
var _no_ram := false
var _over := {}

## Steps the traps, the enemies and the cannon in the study's one
## `foot_pieces` slot.
class Slot extends Node:
	var parts: Array = []
	func before(delta: float) -> void:
		for p: Node in parts: p.before(delta)
	func after(delta: float, events: Dictionary) -> void:
		for p: Node in parts: p.after(delta,events)
	func pose(figure: Node3D) -> void:
		# The trap field's own pose is empty: each trap draws the body.
		for t: Node3D in parts[0].traps: t.pose(figure)
		for p: Node in parts.slice(1): p.pose(figure)
	func frame(camera: Camera3D, delta: float) -> void:
		for p: Node in parts:
			if p.has_method("frame"): p.frame(camera,delta)

func _ready() -> void:
	pack = "noon_weir"
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--base="): base = float(arg.get_slice("=",1))
		elif arg.begins_with("--hold="): hold = float(arg.get_slice("=",1))
		elif arg.begins_with("--ratio="):
			var parts := arg.get_slice("=",1).split(":")
			for i in mini(parts.size(),3): mults[i] = int(parts[i])
		elif arg.begins_with("--offsets="):
			var parts := arg.get_slice("=",1).split(":")
			for i in mini(parts.size(),3): offsets[i] = float(parts[i])
			_offsets_given = true
		elif arg == "--no-ram": _no_ram = true
		elif arg == "--no-noon-double": _noon_double = false
		elif arg.begins_with("--sluice-knob="):
			var kv: String = arg.trim_prefix("--sluice-knob=")
			var value := kv.get_slice("=",1)
			var parsed: Variant = value
			if value.is_valid_float(): parsed = value.to_float()
			elif value == "true" or value == "false": parsed = value == "true"
			_over[kv.get_slice("=",0)] = parsed
	super._ready()

func day_length() -> float:
	var l := 1
	for m: int in mults:
		var a := l
		var b := m
		while b != 0:
			var t := b
			b = a%b
			a = t
		l = l/a*m
	return float(l)*base

func _load_pack() -> void:
	var s0: Dictionary = LAYOUT.stations[0]
	start = s0.spawn
	start_face = s0.face
	lost = LOST_Y
	_last_stood = start
	var parts := []
	for slab: Array in LAYOUT.slabs:
		var r: Rect2 = slab[1]
		parts.append(["box",r,slab[3],slab[2],slab[4]])
		parts.append(["label",Vector3(r.get_center().x,float(slab[2])+0.7,r.get_center().y),"%s  y %d" % [slab[0],int(slab[2])]])
	for st: Array in LAYOUT.stairs:
		parts.append(["ramp",st[1],st[2],st[3],"grey"])
	for lab: Array in LAYOUT.labels:
		parts.append(["label",lab[0],lab[1]])
	var c: Dictionary = LAYOUT.cannon
	var land := cannon_landing()
	parts.append(["label",land+Vector3(0.0,2.5,0.0),"the cannon's rest aim lands here (target z %.0f, lands z %.1f x %.1f)" % [(c.target as Vector3).z,land.z,land.x]])
	stations = []
	for i in LAYOUT.stations.size():
		var s: Dictionary = (LAYOUT.stations[i] as Dictionary).duplicate()
		s.sign = (s.spawn as Vector3)+Vector3(0.0,3.0,0.0)
		s.parts = parts if i == 0 else []
		stations.append(s)

## Where the cannon's rest aim comes down on the top channel's floor.
func cannon_landing() -> Vector3:
	var c: Dictionary = LAYOUT.cannon
	var at: Vector3 = c.at
	var off := Cannon.landing_for(Vector3.ZERO,0.0,deg_to_rad(float(c.pitch)),int(c.notch),(c.target as Vector3).y-at.y)
	return at+off.rotated(Vector3.UP,float(c.heading))

func _build_room() -> void:
	super._build_room()
	traps = TrapField.new()
	add_child(traps)
	traps.attach(self)
	var tiers: Array = LAYOUT.tiers
	for i in tiers.size():
		var t: Dictionary = tiers[i]
		var w: float = LAYOUT.width
		var sl: Node3D = Sluice.new()
		var knobs := {
			"length":t.length,"width":w,"cover":w*0.5+0.4,"trigger":"timer","period":1.0e9,
			"tell_time":TELL_TIME,"refuges":[[t.refuge,1.0]],"gap":Trap.pilot().walk,
		}
		# A tier may wall itself higher (the ram's lane: a knock off a
		# hooking charge peaks ~0.5 m up and would clear the 0.42 m default).
		for key: String in ["parapet","refuge_top","wave_length"]:
			if t.has(key): knobs[key] = t[key]
		sl.configure(knobs)
		sl.configure(_over)
		sl.position = t.gate
		traps.add(sl)
		sluices.append(sl)
	if not _offsets_given: _derive_offsets()
	enemies = EnemyField.new()
	enemies.study = self
	enemies.motor = motor
	enemies.lost = lost
	add_child(enemies)
	if not _no_ram:
		for e: Array in LAYOUT.enemies:
			if e[0] == "ram": enemies.spawn(PlinthRam,e[1],e[2])
	cannons = CannonField.new()
	add_child(cannons)
	cannons.attach(self)
	var c: Dictionary = LAYOUT.cannon
	var gun: Node3D = cannons.add_cannon(c.at,float(c.heading))
	gun.set_aim(0.0,deg_to_rad(float(c.pitch)))
	gun.set_power(int(c.notch))
	var slot := Slot.new()
	slot.parts = [traps,enemies,cannons]
	add_child(slot)
	foot_pieces = slot
	_set_clock(0.0)

# --- The shared clock (STAND-IN) ---------------------------------------------------------

## Each gate's opening after noon, from the layout: the top gate at noon;
## each lower gate HOLD s after a body the upper wave carried would land in
## it (the wave's run down the upper channel, then the spill's fall).
func _derive_offsets() -> void:
	var n := sluices.size()
	offsets[n-1] = 0.0
	for i in range(n-2,-1,-1):
		var up: Node3D = sluices[i+1]
		var ride := float(up.knob("length"))/float(up.knob("speed"))
		var drop: float = (LAYOUT.tiers[i+1].gate as Vector3).y-(LAYOUT.tiers[i].gate as Vector3).y
		offsets[i] = float(offsets[i+1])+ride+spill_air(drop)+hold

## Seconds a spilled body is in the air falling `drop` m (the motor's fall:
## a little up off the lip, then down FALL times as hard, to its terminal).
static func spill_air(drop: float) -> float:
	var p := Trap.pilot()
	var vy := sqrt(2.0*p.gravity*float(p.jumps[0])*Sluice.FLING_UP)
	var y := 0.0
	var t := 0.0
	var dt := 1.0/240.0
	while y > -drop or vy > 0.0:
		var g := p.gravity if vy > 0.0 else p.gravity*p.fall
		vy = maxf(vy-g*dt,-p.terminal)
		y += vy*dt
		t += dt
		if t > 10.0: break
	return t

## Release n of tier i is at n*period_i + offset_i; its tell starts TELL_TIME
## earlier. The clock set to `t`: every tier's next tell from there.
func _set_clock(t: float) -> void:
	day = t
	for i in 3:
		var period: float = float(mults[i])*base
		var n := ceilf((t+TELL_TIME-float(offsets[i]))/period)
		next_tell[i] = maxf(n,1.0)*period+float(offsets[i])-TELL_TIME

func period_of(i: int) -> float:
	return float(mults[i])*base

## Whether tier i's tell starting at `tell_at` is its share of a noon (the
## release falls on a whole day after its offset).
func is_noon(i: int, tell_at: float) -> bool:
	var dl := day_length()
	var k := fposmod(tell_at+TELL_TIME-float(offsets[i]),dl)
	return k < 0.01 or k > dl-0.01

## The first noon's top tell (the clock's time).
func noon_tell_time() -> float:
	return day_length()+float(offsets[2])-TELL_TIME

func tick(delta: float) -> void:
	super.tick(delta)
	if sluices.is_empty(): return
	day += delta
	for i in sluices.size():
		if day >= float(next_tell[i]):
			if sluices[i].state == Sluice.IDLE:
				# The Noon Flood is a double surge (the knob's second wave
				# 1.5 s behind): a late drop at the top, or a late landing
				# below, still meets a wave.
				var noon := is_noon(i,float(next_tell[i]))
				noon_flush[i] = noon
				sluices[i].configure({"second_wave":(noon and _noon_double) or bool(_over.get("second_wave",false))})
				sluices[i].trigger()
			next_tell[i] += period_of(i)

func go_to(key: int) -> void:
	for s: Dictionary in stations:
		if s.key == key: _preset = s
	super.go_to(key)

func place(at: Vector3, face: Vector2) -> void:
	if traps != null: traps.reset()
	if cannons != null: cannons.reset()
	super.place(at,face)
	if enemies != null: enemies.reset()
	var t := 0.0
	if _preset.has("noon_in"): t = maxf(noon_tell_time()-float(_preset.noon_in),0.0)
	elif _preset.has("tell2_in"): t = maxf(period_of(1)+float(offsets[1])-TELL_TIME-float(_preset.tell2_in),0.0)
	_preset = {}
	_set_clock(t)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_N and not _name_panel.visible:
		_set_clock(maxf(noon_tell_time()-6.0,0.0))
		return
	super._unhandled_input(event)

func _hint_text() -> String:
	return "NOON WEIR greybox: walk each channel north from its open end, against the water; stair beside the gate; bridge back to the next open end · 1-9 beats, 0 - = [ chains · N clock to 6 s before noon · R start · F1 numbers · Esc mouse"

func _show_hud() -> void:
	super._show_hud()
	if not _hud.visible or sluices.is_empty(): return
	var dl := day_length()
	var lines := PackedStringArray([_hud.text,""])
	lines.append("clock %.1f s of the %.0f s day · noon (top tell) in %.1f s · hold %.1f s" % [day,dl,fposmod(noon_tell_time()-day,dl),hold])
	for i in sluices.size():
		var s: Node3D = sluices[i]
		var st: String = ["idle","TELL","FLOW"][s.state]
		if s.state != Sluice.IDLE and noon_flush[i]: st += " (NOON, double)"
		lines.append("gate %d: %s · next tell %.1f s · period %.0f s offset %.1f · waves %d · spills %d" % [i+1,st,float(next_tell[i])-day,period_of(i),float(offsets[i]),s.waves_run,s.spills])
	_hud.text = "\n".join(lines)
