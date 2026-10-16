extends "res://studies/character_study.gd"
## GREYBOX: the Tithe Wheel, Opus pass. A round island, a ring road of rim
## turf, a gulf, a hub; spokes of the REAL flip slabs (scripts/traps/
## trap_flip.gd) are the only ways across, each on its own beat. Grey is
## structure, green pads are landings; the slabs warm orange to tell.
##
## The thing this layout is built on: a flip's toss is a LEVER. Stand on the
## half of a slab that rises (the end the row walks toward) and it flings you
## back along the row: ~1 m from its middle, 7-9 m from its lip. Stand on the
## half that drops and it turns out from under you. So the wheel's own
## throws run along each row's line, never sideways: a hand-off between
## spokes has to be a row laid on another row's line.
##   1 start (S rim)   2 South spoke   3 East spoke   4 West spoke (the
##   wheel's carrier: two rows on one line, both thrown hubward)   5 North
##   spoke (hole under it)   6 the hub   7 chain 1 (the wheel plays you: W
##   outer row -> W inner row -> hub)   8 chain 2 (ride the tithe out)
##   9 chain 3 (the noon horn, STAND-IN)   0 chain 4 (the head on its dais
##   spits you at the hub; the hub's backstop stops you)   - the layer below
##   R back to the start (traps rebuilt, the tithe clock restarted)  F1 numbers
##   godot --path . res://studies/greybox/tithe_wheel.tscn -- --no-title
##     [--knob=<key>=<value>] (repeatable; every spoke's flip knob, e.g.
##        --knob=period=3 --knob=underside=slick)
##     [--no-horn] [--no-head] [--no-tithe] [--tithe=<seconds>]
##
## EVERY NUMBER OF THE LAYOUT IS IN THE TABLE BELOW (ISLES, SPOKES, POSTS,
## STONES, WALLS, COLUMNS, CHEST, HORN, HEAD, STOPS) so a turf pass can
## rebuild it mechanically: a place is (x, z) in metres with the top's
## height, a bearing is degrees clockwise from north (0 = -z, 90 = +x), a
## trap's yaw is its route's way (0 = the route runs -z, 90 = -x, 180 = +z,
## -90 = +x). Slab sizes come from the pilot (trap_flip.gd) unless a spoke's
## knobs set `gap`/`length`: count 6 at the pilot's gap is 12.2 m (and so is 9 of
## 1.3 m at 0.05), so the rim's inner radius is HUB r + 12.2.
const Trap = preload("res://scripts/traps/trap.gd")
const TrapField = preload("res://scripts/traps/trap_field.gd")
const Flip = preload("res://scripts/traps/trap_flip.gd")
const Wind = preload("res://scripts/traps/trap_wind_blaster.gd")
const EnemyField = preload("res://scripts/enemies/enemy_field.gd")
const InhalerHead = preload("res://scripts/enemies/inhaler_head.gd")

## ---- THE LAYOUT TABLE -----------------------------------------------------
## Terrain masses. kind "ring": an annulus about `centre` (r_in, r_out);
## "disc": r; "rect": a Rect2 (x, z); "spit": a straight tongue of turf on
## `bearing` from radius `r_from` in to `r_to`, `wide` across. `top` is its
## height and `tiers` its step heights (none: one flat level). `under` is
## the underside's depth.
const ISLES := [
	{"name":"rim road","kind":"ring","centre":Vector2(0.0,0.0),"r_in":17.2,"r_out":22.2,"top":0.0,"tiers":[],"under":-2.0,"seg":40},
	{"name":"hub","kind":"disc","centre":Vector2(0.0,0.0),"r":5.0,"top":0.0,"tiers":[],"under":-2.0},
	{"name":"head dais","kind":"spit","bearing":45.0,"r_from":17.6,"r_to":11.0,"wide":7.0,"top":0.0,"tiers":[],"under":-2.0,
		"label":"HEAD DAIS (rim arena on the NE bearing; the head faces the hub)"},
	{"name":"S avenue","kind":"rect","rect":Rect2(-3.0,22.0,6.0,10.0),"top":0.0,"tiers":[],"under":-2.0,"colour":"pad","label":"S AVENUE (entry socket; catches the S spoke's long throws)"},
	{"name":"E apron","kind":"rect","rect":Rect2(22.0,-3.0,8.0,6.0),"top":0.0,"tiers":[],"under":-2.0,"colour":"pad","label":"E APRON (socket; catches the tithe's throw off the E spoke)"},
	{"name":"the layer below","kind":"rect","rect":Rect2(-36.0,-36.0,72.0,72.0),"top":-12.0,"tiers":[],"under":-2.0,"label":"THE LAYER BELOW (a fall lands here; 12 m = fall stun)"},
]
## The spokes: a trap_flip each. `at` is where the trap's origin is (its way
## in), `yaw` its route's way, `knobs` its beat. A row's toss always goes back
## along its own line (toward its origin), so:
## - West, the CARRIER: two rows on one line (different beats, so different
##   sources), both built from the hub out: their waves run at you and both
##   throw you HUBWARD, the outer row's toss onto the inner row, the inner
##   row's onto the hub. A one-way spoke in.
## - South, the THROWER: walks in from the rim, so every toss throws you OUT;
##   the horn's blast lands you on it and it hands you to the rim.
## Both have hand's-width gaps (`gap` 0.05, slabs 1.3 long: 9 fill the gulf)
## so a throw along the line lands on stone, not between slabs.
## - East (slow, the tithe ride) and North (holes) keep the pilot's hop gaps:
##   they are the crossings. East's origin sits 0.66 m into the rim so its
##   first slab is flush with the rim (no gap to fall into when the tithe
##   throws you back), and it sits 0.35 m proud of the rim so a low throw
##   off its rim end clears the rim's edge. `tithe_throw` false: the tithe
##   flips that row but leaves its toss as it is.
const SPOKES := [
	{"name":"South","at":Vector3(0.0,0.0,17.2),"yaw":0.0,"knobs":{"count":9,"period":2.0,"stagger":0.5,"gap":0.05,"length":1.3},
		"says":"SOUTH: quick, wave runs with you (walk behind it); every toss throws you OUT"},
	{"name":"East","at":Vector3(17.86,0.35,0.0),"yaw":90.0,"knobs":{"count":6,"period":3.2,"stagger":0.8},
		"says":"EAST: slow; first slab flush with the rim, a hop down onto the hub"},
	{"name":"North","at":Vector3(0.0,0.0,-17.2),"yaw":180.0,"knobs":{"count":6,"period":2.4,"stagger":0.6,"underside":"gone"},
		"says":"NORTH: a HOLE under it (underside gone)"},
	{"name":"W out","at":Vector3(-10.4,0.0,0.0),"yaw":90.0,"knobs":{"count":5,"period":2.4,"stagger":0.15,"gap":0.05,"length":1.3},"tithe_throw":false,
		"says":"WEST, OUTER ROW: wave runs AT you; its toss throws you onto the inner row"},
	{"name":"W in","at":Vector3(-5.0,0.0,0.0),"yaw":90.0,"knobs":{"count":4,"period":1.7,"stagger":0.15,"gap":0.05,"length":1.3},"tithe_throw":false,
		"says":"WEST, INNER ROW: another beat; its toss throws you onto the hub"},
]
## The twelve month-posts (aqueduct_stump): `count` round `radius`, the
## first `first` degrees off north (between the spokes), height `h`.
const POSTS := {"count":12,"radius":21.3,"first":15.0,"r":0.45,"h":2.6,"top":0.0}
## The hub's stone circle: a stone on each `bearings` (degrees) at `radius`.
## The two on the head's bearing (22.5, 67.5) are left out: the circle's
## gate faces the head dais, so its spit flies in clean.
const STONES := {"bearings":[112.5,157.5,202.5,247.5,292.5,337.5],"radius":4.4,"r":0.35,"h":2.2}
## Walls: an arc at `r` from bearing `from` to `to` (degrees), `h` tall,
## `thick` deep, in `seg` straight pieces. The backstop is the far side of
## the circle from the head: lintel stones between two uprights that stop a
## spit that comes in too hard.
const WALLS := [
	{"name":"backstop","r":4.75,"from":195.0,"to":255.0,"h":1.6,"thick":0.5,"seg":4,"top":0.0},
]
## Two hall columns on the hub (cover): [x, z], radius, height. Off the
## head's line.
const COLUMNS := {"at":[Vector2(3.2,3.2),Vector2(-3.2,-3.2)],"r":0.7,"h":7.0}
## The tomb chest (the prize): a box, x z w d, height.
const CHEST := {"rect":Rect2(-0.5,-3.9,1.0,1.0),"h":0.7}
## STAND-IN horn (the noon horn): a trap_wind_blaster across the hub, its
## mouths on the north side blowing south down the South spoke. `at` is the
## trap's origin, `yaw` its route (-90: runs +x); its plate is on the S
## spoke's axis so you fly down the middle of the row. `blast_out` 19 (its own
## 14.4 dropped you mid-spoke, where a body that gets up was hit or missed by
## the flips): now you land tumbling on the spoke's outer half and skid or
## are thrown off its end onto the rim.
const HORN := {"at":Vector3(-1.2,0.0,0.0),"yaw":-90.0,"knobs":{"count":2,"blast_out":19.0}}
## The inhaler head on its dais, facing the hub (the face as x z). Its own
## knobs but for `ring` (it shuffles round its spot, not across the dais).
const HEAD := {"at":Vector3(10.6,0.0,-10.6),"face":Vector2(-1.0,1.0),"knobs":{"ring":1.0}}
## The tithe (STAND-IN for the shared clock): every `every` s all the
## spokes' flat slabs go to their tell together; for `hold` s after that
## the spokes' toss (`knock`, m/s) is `knock` instead of its own (4, was 12:
## the lever already throws ~7 m from a lip, 12 flung you past the rim).
const TITHE := {"every":9.6,"hold":1.6,"knock":4.0}
const FALL := -30.0
## The stations: key, name, where (x, y, z), the way faced (x, z), a
## floating name (above the spawn), and for chains the floating text.
## `on` [spoke, slab] puts the spawn on that slab.
const STOPS := [
	{"key":1,"name":"START: S rim","at":Vector3(0.0,0.0,20.6),"face":Vector2(0.0,-1.0),"label":"START (S rim, entry)"},
	{"key":2,"name":"Beat S: quick spoke","at":Vector3(0.0,0.0,18.2),"face":Vector2(0.0,-1.0),"label":"BEAT S - period 2.0, stagger 0.5: the wave goes your way, walk just behind it; a flip throws you back OUT"},
	{"key":3,"name":"Beat E: slow spoke","at":Vector3(18.2,0.0,0.0),"face":Vector2(-1.0,0.0),"label":"BEAT E - period 3.2, stagger 0.8 (slow): hop slab to slab"},
	{"key":4,"name":"Beat W: the carrier","at":Vector3(-18.2,0.0,0.0),"face":Vector2(1.0,0.0),"label":"BEAT W - the carrier: two rows, waves run AT you; every toss throws you HUBWARD (one way in)"},
	{"key":5,"name":"Beat N: a hole","at":Vector3(0.0,0.0,-18.2),"face":Vector2(0.0,1.0),"label":"BEAT N - underside gone: read the hole"},
	{"key":6,"name":"The hub and the chest","at":Vector3(1.5,0.0,2.0),"face":Vector2(-0.5,-1.0),"label":"HUB: tomb chest, columns (cover), stone circle, backstop SW"},
	{"key":7,"name":"Chain 1: the wheel plays you","at":Vector3(-18.0,0.0,0.0),"face":Vector2(1.0,0.0),"label":"CHAIN 1: step onto the West spoke and stand: outer row throws you onto the inner row, the inner row onto the hub"},
	{"key":8,"name":"Chain 2: ride the tithe","at":Vector3(19.4,0.0,0.0),"face":Vector2(-1.0,0.0),"tithe_in":4.0,"label":"CHAIN 2: step onto the slow E spoke's first slab a second before the tithe (HUD count) and wait: every spoke flips together and throws you OUT onto the E rim"},
	{"key":9,"name":"Chain 3: the noon horn","at":Vector3(1.6,0.0,0.0),"face":Vector2(-1.0,0.0),"label":"CHAIN 3 (STAND-IN horn: wind blaster): step west onto its plate, be blown down the S spoke; it hands you to the rim"},
	{"key":10,"name":"Chain 4: head to hub","at":Vector3(8.2,0.0,-8.2),"face":Vector2(1.0,-1.0),"label":"CHAIN 4: let the head inhale you; its own blast spits you through the circle's gate onto the HUB (the backstop stops a long one)"},
	{"key":11,"name":"The layer below","at":Vector3(0.0,-12.0,0.0),"face":Vector2(0.0,-1.0),"label":"the layer below"},
]
## ---- end of the layout table -----------------------------------------------

var traps: Node3D
var enemies: Node
var spokes: Array = []
var horn: Node3D
var _tithe_t := 0.0
var _tithe_on := true
var _tithe_every := TITHE.every
var _tithes := 0
var _knock_hold := 0.0
var _horn_on := true
var _head_on := true
var _knobs := {}
var _slot: Node

## Steps traps and the head together, hides the figure while it holds him.
class Slot extends Node:
	var traps: Node
	var heads: Node
	func before(delta: float) -> void:
		traps.before(delta)
		if heads != null: heads.before(delta)
	func after(delta: float, events: Dictionary) -> void:
		traps.after(delta,events)
		if heads != null: heads.after(delta,events)
	func pose(figure: Node3D) -> void:
		if heads == null: return
		var held := false
		for e in heads.enemies:
			if is_instance_valid(e) and e.get("swallowed"): held = true
		figure.visible = not held

func _ready() -> void:
	pack = "tithe_wheel"
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg == "--no-horn": _horn_on = false
		elif arg == "--no-head": _head_on = false
		elif arg == "--no-tithe": _tithe_on = false
		elif arg.begins_with("--tithe="): _tithe_every = float(arg.get_slice("=",1))
		elif arg.begins_with("--knob="):
			var pair := arg.trim_prefix("--knob=")
			var value := pair.get_slice("=",1)
			var parsed: Variant = value
			if value.is_valid_float(): parsed = value.to_float()
			elif value == "true" or value == "false": parsed = value == "true"
			_knobs[pair.get_slice("=",0)] = parsed
	super._ready()

# --- The layout, read from the table --------------------------------------

## A bearing (degrees clockwise from north) at radius r, as x z.
static func _on_bearing(bearing: float, r: float) -> Vector2:
	var a := deg_to_rad(bearing)
	return Vector2(r*sin(a),-r*cos(a))

func _slab_world(spoke: Dictionary, index: int, trap: Node3D) -> Vector3:
	var len_: float = trap.knob("length")
	var gap: float = trap.knob("gap")
	var z := -(gap+float(index)*(len_+gap)+len_*0.5)
	var turned := Basis(Vector3.UP,deg_to_rad(float(spoke.yaw)))
	return (spoke.at as Vector3)+turned*Vector3(0.0,0.0,z)

func _load_pack() -> void:
	spokes = []
	for s: Dictionary in SPOKES:
		var trap: Node3D = Flip.new()
		trap.configure(s.knobs)
		trap.configure(_knobs)
		trap.position = s.at
		trap.rotation.y = deg_to_rad(float(s.yaw))
		spokes.append(trap)
	var parts: Array = []
	for isle: Dictionary in ISLES:
		var top: float = isle.top
		var bottom: float = top+float(isle.under)
		match isle.kind:
			"ring":
				var c: Vector2 = isle.centre
				var mid := (float(isle.r_in)+float(isle.r_out))*0.5
				var width := float(isle.r_out)-float(isle.r_in)
				var segs: int = isle.seg
				var along := TAU*mid/float(segs)+0.4
				for k in segs:
					var a := TAU*float(k)/float(segs)
					parts.append(["obox",Vector3(c.x+mid*sin(a),(top+bottom)*0.5,c.y-mid*cos(a)),Vector3(along,top-bottom,width),-rad_to_deg(a),"floor"])
			"disc":
				parts.append(["cyl",isle.centre,float(isle.r),bottom,top,"floor"])
			"spit":
				var r0 := float(isle.r_to)
				var r1 := float(isle.r_from)
				var mid2 := _on_bearing(float(isle.bearing),(r0+r1)*0.5)
				parts.append(["obox",Vector3(mid2.x,(top+bottom)*0.5,mid2.y),Vector3(float(isle.wide),top-bottom,r1-r0),-float(isle.bearing),"pad"])
				if isle.has("label"):
					var at2 := _on_bearing(float(isle.bearing),r0+1.0)
					parts.append(["label",Vector3(at2.x,top+3.6,at2.y),isle.label])
			"rect":
				parts.append(["box",isle.rect,bottom,top,isle.get("colour","dark")])
				if isle.has("label"):
					var r: Rect2 = isle.rect
					parts.append(["label",Vector3(r.get_center().x,top+1.0,r.position.y+1.0),isle.label])
	for k in int(POSTS.count):
		var p := _on_bearing(float(POSTS.first)+360.0/float(POSTS.count)*float(k),float(POSTS.radius))
		parts.append(["cyl",p,float(POSTS.r),-1.0,float(POSTS.top)+float(POSTS.h),"grey"])
	for b: float in STONES.bearings:
		parts.append(["cyl",_on_bearing(b,float(STONES.radius)),float(STONES.r),0.0,float(STONES.h),"grey"])
	for w: Dictionary in WALLS:
		var n: int = w.seg
		var span := float(w.to)-float(w.from)
		var piece := deg_to_rad(span/float(n))*float(w.r)+0.1
		for k in n:
			var b := float(w.from)+span*(float(k)+0.5)/float(n)
			var p := _on_bearing(b,float(w.r))
			parts.append(["obox",Vector3(p.x,float(w.top)+float(w.h)*0.5,p.y),Vector3(piece,float(w.h),float(w.thick)),-b,"wall"])
		var lab := _on_bearing((float(w.from)+float(w.to))*0.5,float(w.r))
		parts.append(["label",Vector3(lab.x,float(w.top)+float(w.h)+0.6,lab.y),"BACKSTOP (lintels): stops the head's spit on the hub"])
	for c: Vector2 in COLUMNS.at: parts.append(["cyl",c,float(COLUMNS.r),0.0,float(COLUMNS.h),"grey"])
	parts.append(["box",CHEST.rect,0.0,float(CHEST.h),"lip"])
	parts.append(["label",Vector3(CHEST.rect.get_center().x,2.2,CHEST.rect.get_center().y),"TOMB CHEST (prize)"])
	parts.append(["label",Vector3(0.0,4.0,0.0),"HUB - stone circle (gate NE, to the head)"])
	parts.append(["label",Vector3(0.0,3.4,22.6),"12 month-posts (aqueduct stumps) ring the road; rune side faces the hub"])
	for i in SPOKES.size():
		var s: Dictionary = SPOKES[i]
		var t: Node3D = spokes[i]
		var mid_slab := _slab_world(s,mini(3,int(t.knob("count"))-1),t)
		parts.append(["label",mid_slab+Vector3(0.0,2.2+0.8*float(i%2),0.0),s.says])
	if _horn_on:
		parts.append(["label",Vector3(0.0,2.6,-1.0),"STAND-IN: noon horn = wind blaster (plate on the hub floor), blows S"])
	if _head_on:
		parts.append(["label",(HEAD.at as Vector3)+Vector3(0.0,5.0,0.0),"inhaler head (REAL, round 2: ground-bound), facing the hub"])
	parts.append(["label",Vector3(0.0,6.0,10.0),"STAND-IN: tithe = every %.1f s all flat slabs go to their tell together (HUD shows the count)" % _tithe_every])
	stations = []
	for st: Dictionary in STOPS:
		var at: Vector3
		if st.has("on"):
			at = _slab_world(SPOKES[st.on[0]],int(st.on[1]),spokes[int(st.on[0])])
		else: at = st.at
		var face: Vector2 = st.face
		stations.append({"key":st.key,"name":st.name,"spawn":at,"face":face.normalized(),
			"sign":at+Vector3(0.0,3.2,0.0),"parts":[["label",at+Vector3(0.0,2.0,0.0),st.label]],"tithe_in":st.get("tithe_in",-1.0)})
		if st.key == 1: parts.append(["label",at+Vector3(0.0,1.2,-1.5),"N is up the screen"])
	# The shared parts ride on the first station.
	(stations[0].parts as Array).append_array(parts)
	start = stations[0].spawn
	start_face = stations[0].face
	lost = FALL
	_last_stood = start

func _build_room() -> void:
	super._build_room()
	traps = TrapField.new()
	add_child(traps)
	traps.attach(self)
	for t: Node3D in spokes: traps.add(t)
	if _horn_on:
		horn = Wind.new()
		horn.configure(HORN.knobs)
		horn.position = HORN.at
		horn.rotation.y = deg_to_rad(float(HORN.yaw))
		traps.add(horn)
	_slot = Slot.new()
	_slot.traps = traps
	add_child(_slot)
	if _head_on:
		enemies = EnemyField.new()
		enemies.study = self
		enemies.motor = motor
		enemies.lost = lost
		add_child(enemies)
		_slot.heads = enemies
		enemies.spawn(InhalerHead,HEAD.at,HEAD.face,HEAD.knobs)
	foot_pieces = _slot

# --- The tithe (stand-in) and the frame -----------------------------------

func place(at: Vector3, face: Vector2) -> void:
	if traps != null: traps.reset()
	if enemies != null: enemies.reset()
	super.place(at,face)
	if figure != null: figure.visible = true
	_tithe_t = 0.0
	_knock_hold = 0.0
	_tithes = 0
	_set_knock(false)

func go_to(key: int) -> void:
	super.go_to(key)
	for st: Dictionary in stations:
		if st.key == key and float(st.get("tithe_in",-1.0)) > 0.0:
			_tithe_t = _tithe_every-float(st.tithe_in)

func tick(delta: float) -> void:
	super.tick(delta)
	if not _tithe_on or spokes.is_empty(): return
	_tithe_t += delta
	if _knock_hold > 0.0:
		_knock_hold -= delta
		if _knock_hold <= 0.0: _set_knock(false)
	if _tithe_t >= _tithe_every:
		_tithe_t = 0.0
		fire_tithe()

## Every flat slab of every spoke to its tell now (the all-at-once beat).
func fire_tithe() -> void:
	_tithes += 1
	_set_knock(true)
	_knock_hold = TITHE.hold
	for t: Node3D in spokes:
		for s: Dictionary in t.slabs:
			if int(s.phase) == 0: s.t = t._tell_at()

func _set_knock(on: bool) -> void:
	for i in spokes.size():
		var t: Node3D = spokes[i]
		var own := float(_knobs.get("knock",SPOKES[i].knobs.get("knock",t.defaults().knock)))
		t.knobs["knock"] = float(TITHE.knock) if on and SPOKES[i].get("tithe_throw",true) else own

# --- HUD -----------------------------------------------------------------------

func _hint_text() -> String:
	return "Tithe Wheel greybox: cross a spoke by its beat (orange = about to turn; stand on the rising half and it throws you) · 1 start 2-5 the spokes 6 hub 7-0 chains - below · R start · F1 numbers · Esc mouse"

func _show_hud() -> void:
	super._show_hud()
	if not _hud.visible or spokes.is_empty(): return
	var lines := PackedStringArray([_hud.text,""])
	for i in spokes.size():
		var t: Node3D = spokes[i]
		var row := ""
		for s: Dictionary in t.slabs: row += ["-","!","*"][int(s.phase)]
		lines.append("%-6s %s  period %.1f  knocks %d  riding slab %d" % [SPOKES[i].name,row,float(t.knob("period")),t.knocks,t.slab_at(motor.feet)])
	lines.append("tithe in %.1f s (%d fired)%s" % [maxf(_tithe_every-_tithe_t,0.0),_tithes,"" if _tithe_on else " OFF"])
	_hud.text = "\n".join(lines)
