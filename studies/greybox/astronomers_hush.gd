extends "res://studies/character_study.gd"
## GREYBOX of motif card m3, The Astronomer's Hush:
## four isles huddled round a henge, the real inhaler head
## (scripts/enemies/inhaler_head.gd) heaving its ring on the Circle, and
## the pilot crossing pillar to pillar a body's width outside its cone.
## Grey boxes for structure, the head is the real one.
##   R   back to the start, the head back on its ring
##   1-9, 0, -, =   stations (the start, each beat, each chain; HUD lists them)
##   F1  numbers (the head's state, its draw, its pull on him, the chain tally)
##   godot --path . res://studies/greybox/astronomers_hush.tscn -- --no-title
##     [--head-knob=<knob>=<value>] (repeatable, e.g. --head-knob=sight_half=0.8)
##     [--no-tech] (the tech is on here: twirl just before you land from a
##     blast and you roll up with no time down)
##
## Opus pass: the Circle (+1.8) stands 1 m proud of a low catch terrace
## (+0.8) round its north and east: the Hall of Ties' roof (north, the hall
## sunk under it, a stair down to its door) and the Gallery's apron (east,
## ledges up to the exit). A blast carries ~17 m (flight then skid) along
## the head's line to you, so being caught on the north or east half throws
## you down onto the catch, never into a face. The decoy is sight, not
## sound: the sun gnomon stands taller than the head's draw reaches; shown
## up there, it rears and inhales at a star it can't pull, then slumps
## blind (`after`, 3.5 s), the window to cross its face.
##
## The layout is ONE table (LAYOUT) so a later turf pass can rebuild it with
## KitLand.island(spec): isles with tiers, traversal pieces, cover, the ring,
## the head, the stations. x east, z south (north is -z), y up; metres.
const EnemyField = preload("res://scripts/enemies/enemy_field.gd")
const InhalerHead = preload("res://scripts/enemies/inhaler_head.gd")
const EnemyYard = preload("res://studies/enemy_yard.gd")

const UNDER := -14.0
const ISLE_LOST := -30.0

const LAYOUT := {
	# Isles: name, bounds (x, z), top, tiers [[Rect2, top], ...] (an isle that
	# is one mass with steps lists its tiers; no tiers: the bounds at `top`).
	"isles":[
		# The entry, lowest: wraps the Circle's west and south sides; a body
		# blasted off the west or south rim lands back here (the south-east
		# corner stays open: the port rim).
		{"name":"1 the Rim","bounds":Rect2(-40.0,-10.0,48.0,36.0),"top":0.0,
			"tiers":[[Rect2(-40.0,-10.0,24.0,36.0),0.0],[Rect2(-16.0,16.0,24.0,10.0),0.0]]},
		{"name":"2 the Circle","bounds":Rect2(-16.0,-16.0,32.0,32.0),"top":1.8,"tiers":[]},
		# The north catch: a terrace 1 m under the Circle (the head can't
		# drop 1 m; a blast never meets a face). The hall is sunk under its
		# middle (floor -1.0, the slab roof flush with the terrace), its door
		# down a stairwell on the north side.
		{"name":"3 the Hall of Ties","bounds":Rect2(-16.0,-38.0,32.0,22.0),"top":0.8,
			"tiers":[[Rect2(-16.0,-38.0,8.0,22.0),0.8],[Rect2(8.0,-38.0,8.0,22.0),0.8],[Rect2(-8.0,-20.0,16.0,4.0),0.8],
				[Rect2(-8.0,-38.0,2.0,6.0),0.8],[Rect2(6.0,-38.0,2.0,6.0),0.8],[Rect2(-6.0,-38.0,12.0,1.0),0.8],
				[Rect2(-8.0,-37.0,16.0,17.0),-1.0]]},
		# The east catch and the exit: the apron (+0.8, flush with the hall
		# terrace), a ledge (+2.8), the gallery (+4.8, rim north-east).
		{"name":"4 the Gallery","bounds":Rect2(16.0,-38.0,30.0,54.0),"top":4.8,
			"tiers":[[Rect2(16.0,-38.0,12.0,54.0),0.8],[Rect2(28.0,-38.0,5.0,54.0),2.8],[Rect2(33.0,-38.0,13.0,30.0),4.8]]},
	],
	# Lips to grab (orange), laid on an isle's edge: [Rect2, top].
	"lips":[
		[Rect2(-16.0,-10.0,0.8,26.0),1.81],
		[Rect2(28.0,-38.0,0.6,54.0),2.81],
		[Rect2(33.0,-38.0,0.6,30.0),4.81],
	],
	# Ramps: [low middle edge, high middle edge, width, colour, label].
	"ramps":[
		[Vector3(0.0,-1.0,-32.0),Vector3(0.0,0.8,-37.0),12.0,"grey","stair down to the hall door"],
	],
	# Traversal pieces and stones: [name, Rect2, bottom, top, colour, label].
	"links":[
		# The gnomon pair (the kit ask's notched menhirs), outside the ring
		# (r 13.5): tops 3.2 m over the Circle, past the head's draw (it pulls
		# nothing above 0.8 of its height, 2.7 m). A step on the far side.
		["sun gnomon",Rect2(-13.4,3.9,1.4,1.4),1.8,5.0,"lip","STAND-IN: sun gnomon (5.0): stand on top in its sight; it can't pull you"],
		["sun gnomon step",Rect2(-15.1,3.9,1.7,1.4),1.8,3.0,"grey",""],
		["star gnomon",Rect2(12.0,3.9,1.4,1.4),1.8,5.0,"lip","STAND-IN: star gnomon (5.0), the same lure, east"],
		["star gnomon step",Rect2(13.4,3.9,1.7,1.4),1.8,3.0,"grey",""],
	],
	# The hall (isle 3, sunk under the terrace): the slab roof (walked,
	# flush), its columns. The terrace round the pit is its walls.
	"hall":{
		"floor":-1.0,"roof_bottom":0.6,"roof_top":0.8,
		"roof":Rect2(-8.0,-32.0,16.0,12.0),
		"columns":[Vector2(-3.4,-23.0),Vector2(3.4,-23.0),Vector2(-3.4,-29.0),Vector2(3.4,-29.0)],
		"column_radius":0.5,
	},
	# The henge (isle 2): centre, the uprights' ring, the altar.
	"circle":{
		"centre":Vector2(0.0,0.0),"upright_radius":4.5,"uprights":8,"upright_size":Vector3(1.6,3.6,0.8),
		"altar":Vector3(0.0,0.0,0.0),"altar_size":Vector3(1.6,1.0,0.9),
	},
	# Cover on open turf (isle 2), outside the ring: toppled drums [x, z, yaw
	# degrees], and a beam laid on two stubs to slide under [x, z, yaw]. The
	# two west drums make a lane along the west rim (x -14.8) out of the
	# head's line from the south-west arc: the run off the sun gnomon.
	"drums":[
		[-13.5,-1.5,95.0],[-13.5,-6.0,95.0],[-7.0,13.5,0.0],[6.0,14.0,-10.0],
		[13.5,9.0,80.0],[13.5,-11.0,100.0],[8.5,-13.5,0.0],[-8.0,-13.5,-5.0],
	],
	"drum_size":Vector3(3.2,1.2,1.2),
	"beams":[[-12.5,10.0,90.0]],
	"beam_size":Vector3(4.0,0.4,0.7),"beam_clear":1.0,
	# The head's ring: a closed polygon about the henge, clockwise from above
	# (north, east, south, west), `points` corners, alternately at `radius`
	# and `inner` (the look-ins: on each inward leg its face swings in across
	# the uprights and out again, so its gaze sweeps the Circle; inner =
	# radius is a plain ring).
	"ring":{"radius":10.0,"inner":8.0,"points":12,"start":90.0},
	# Pace (the round-2 head laps a 10 m ring in ~4 min at its defaults; this
	# is ~2.5 min): shorter rests and pants, fewer sags, a quicker heave.
	"head_knobs":{"sight_half":1.0,"rest_min":0.1,"rest_max":0.35,"pant":0.6,"false_start":0.1,"heave":0.85},
	# Stations: key, name, where (x, z, then the top it stands on), the way
	# faced (x, z), and `head` (degrees on the ring, 0 north, 90 east; absent:
	# the ring's start) -- the head is set there when the station is taken.
	"stations":[
		{"key":1,"name":"START isle 1 rim","at":Vector3(-34.0,0.0,20.0),"face":Vector2(1.0,-0.5),"label":"1 START"},
		{"key":2,"name":"beat 1: the lip onto the Circle","at":Vector3(-18.0,0.0,8.0),"face":Vector2(1.0,0.0),"label":"beat 1 lip (1.8 m)"},
		{"key":3,"name":"beat 2: the drum lane, west rim","at":Vector3(-14.9,1.8,-3.8),"face":Vector2(0.0,-1.0),"label":"beat 2 drums"},
		{"key":4,"name":"beat 3: the altar","at":Vector3(-2.5,1.8,3.0),"face":Vector2(1.0,-0.6),"label":"beat 3 altar"},
		{"key":5,"name":"beat 4: the north rim (step down to the roof)","at":Vector3(0.0,1.8,-14.0),"face":Vector2(0.0,-1.0),"label":"beat 4 north rim"},
		{"key":6,"name":"beat 5: the hall's roof (terrace +0.8)","at":Vector3(0.0,0.8,-26.0),"face":Vector2(0.0,-1.0),"label":"beat 5 hall roof"},
		{"key":7,"name":"beat 6: in the hall (the dark)","at":Vector3(0.0,-1.0,-26.0),"face":Vector2(0.0,1.0),"label":""},
		{"key":8,"name":"exit: the gallery (4.8 m)","at":Vector3(40.0,4.8,-24.0),"face":Vector2(1.0,-1.0),"label":"exit gallery"},
		{"key":9,"name":"CHAIN 1: caught on the north rim (to the roof)","at":Vector3(-1.0,1.8,-13.0),"face":Vector2(-0.6,0.8),"head":300.0,"label":"chain 1 start"},
		{"key":10,"name":"CHAIN 2: the blast line (blast to the apron)","at":Vector3(12.0,1.8,-4.0),"face":Vector2(-0.9,-0.5),"head":20.0,"label":"chain 2 start"},
		{"key":11,"name":"CHAIN 3: the star it counts (lure on the sun gnomon)","at":Vector3(-12.7,5.0,4.6),"face":Vector2(1.0,0.4),"head":215.0,"label":"chain 3: be the star"},
		{"key":12,"name":"the apron (blast landing, 0.8 m)","at":Vector3(22.0,0.8,-10.0),"face":Vector2(1.0,0.0),"label":"apron"},
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
var head: Node3D
## The chain tally for F1: swallows, blasts, and where the last blast left him.
var tally := {"gulps":0,"blasts":0,"landed":Vector3.ZERO,"isle":""}
var _head_knobs := {}
var _voices := {}
var _watch_landing := false
var _tech := true

## Hides the figure while the head holds him, and steps the enemies.
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
	pack = "astronomers_hush"
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg.begins_with("--head-knob="):
			var kv: String = arg.trim_prefix("--head-knob=")
			_head_knobs[kv.get_slice("=",0)] = float(kv.get_slice("=",1))
		elif arg == "--no-tech": _tech = false
	motor.tech = _tech
	super._ready()

# --- The table, built ---------------------------------------------------------------------

func _ring_point(deg: float, radius: float) -> Vector3:
	var c: Vector2 = LAYOUT.circle.centre
	var a := deg_to_rad(deg)
	return Vector3(c.x+sin(a)*radius,0.0,c.y-cos(a)*radius)

func _load_pack() -> void:
	var first: Dictionary = LAYOUT.stations[0]
	start = first.at
	start_face = (first.face as Vector2).normalized()
	lost = ISLE_LOST
	_last_stood = start
	var parts := []
	for isle: Dictionary in LAYOUT.isles:
		var tiers: Array = isle.tiers
		if tiers.is_empty(): tiers = [[isle.bounds,isle.top]]
		for t: Array in tiers: parts.append(["box",t[0],UNDER,t[1],"floor"])
		var b: Rect2 = isle.bounds
		parts.append(["label",Vector3(b.get_center().x,float(isle.top)+0.9,b.end.y-1.5),"%s · +%.1f m" % [isle.name,float(isle.top)]])
	for lip: Array in LAYOUT.lips: parts.append(["box",lip[0],float(lip[1])-0.2,lip[1],"lip"])
	for r: Array in LAYOUT.ramps:
		parts.append(["ramp",r[0],r[1],r[2],r[3]])
		if r[4] != "": parts.append(["label",((r[0] as Vector3)+(r[1] as Vector3))*0.5+Vector3.UP*1.0,r[4]])
	for l: Array in LAYOUT.links:
		parts.append(["box",l[1],l[2],l[3],l[4]])
		if l[5] != "": parts.append(["label",Vector3((l[1] as Rect2).get_center().x,float(l[3])+1.0,(l[1] as Rect2).get_center().y),l[5]])
	# The hall: its slab roof over the pit, its columns.
	var h: Dictionary = LAYOUT.hall
	var hr: Rect2 = h.roof
	parts.append(["box",hr,h.roof_bottom,h.roof_top,"wall"])
	for c: Vector2 in h.columns: parts.append(["cyl",c,h.column_radius,h.floor,h.roof_bottom,"grey"])
	parts.append(["label",Vector3(hr.get_center().x,float(h.roof_top)+1.2,hr.get_center().y),"STAND-IN: hall_slab roof (walked, flush with the terrace +0.8) over a sunk hall_bay"])
	parts.append(["label",Vector3(hr.get_center().x,float(h.floor)+1.0,hr.position.y-0.5),"hall door (dim inside, under the roof)"])
	parts.append(["label",Vector3(0.0,1.8,-17.5),"catch terrace +0.8 (1 m under the Circle: the head can't follow)"])
	# The henge.
	var ci: Dictionary = LAYOUT.circle
	var top: float = LAYOUT.isles[1].top
	var cc: Vector2 = ci.centre
	var usize: Vector3 = ci.upright_size
	for i in int(ci.uprights):
		var deg := 360.0*float(i)/float(ci.uprights)
		var p := _ring_point(deg,float(ci.upright_radius))
		parts.append(["obox",Vector3(p.x,top+usize.y*0.5,p.z),usize,-deg,"grey"])
	var asz: Vector3 = ci.altar_size
	parts.append(["cyl",cc,1.5,top,top+0.25,"dark"])
	parts.append(["obox",Vector3(cc.x,top+0.25+asz.y*0.5,cc.y),asz,0.0,"dark"])
	parts.append(["box",Rect2(cc.x-0.4,cc.y-0.3,0.8,0.6),top+0.25+asz.y,top+0.25+asz.y+0.03,"pad"])
	parts.append(["label",Vector3(cc.x,top+3.0,cc.y),"altar (the prize) · STAND-IN: stone_circle uprights r 4.5"])
	# Cover.
	var dsz: Vector3 = LAYOUT.drum_size
	for d: Array in LAYOUT.drums:
		parts.append(["obox",Vector3(d[0],top+dsz.y*0.5,d[1]),dsz,d[2],"grey"])
	for bm: Array in LAYOUT.beams:
		var bs: Vector3 = LAYOUT.beam_size
		var clear: float = LAYOUT.beam_clear
		var yaw := deg_to_rad(float(bm[2]))
		var along := Vector3(cos(yaw),0.0,-sin(yaw))*(bs.x*0.5-0.3)
		for s in [-1.0,1.0]:
			parts.append(["obox",Vector3(bm[0],top+clear*0.5,bm[1])+along*s,Vector3(0.6,clear,0.9),bm[2],"grey"])
		parts.append(["obox",Vector3(bm[0],top+clear+bs.y*0.5,bm[1]),bs,bm[2],"grey"])
		parts.append(["label",Vector3(bm[0],top+clear+1.2,bm[1]),"leaning beam: slide under (%.1f m clear)" % clear])
	parts.append(["label",Vector3(0.0,top+6.0,0.0),"THE CIRCLE · the head's ring r %.0f m with look-ins to %.0f m, clockwise, faces the way it goes" % [float(LAYOUT.ring.radius),float(LAYOUT.ring.inner)]])
	parts.append(["label",Vector3(-13.5,top+2.2,-6.0),"toppled drums = cover (1.2 m)"])
	parts.append(["label",Vector3(12.0,top+0.6,16.6),"south-east corner: the gulf (port rim, a lower neighbour)"])
	# Stations.
	var out := []
	for s: Dictionary in LAYOUT.stations:
		var at: Vector3 = s.at
		var station := {"key":s.key,"name":s.name,"spawn":at,"face":(s.face as Vector2).normalized(),"parts":[]}
		if s.key == 1: station.parts = parts
		var sign := Vector3(at.x,at.y+2.6,at.z)
		station["sign"] = sign
		out.append(station)
		if s.has("label") and s.label != "" and s.key != 1: parts.append(["label",sign+Vector3(0.0,0.6,0.0),s.label])
	stations = out

func _build_room() -> void:
	super._build_room()
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
	var ring: Dictionary = LAYOUT.ring
	var route: Array = []
	for i in int(ring.points): route.append(_corner(i))
	var knobs := {"route":route}
	knobs.merge(LAYOUT.head_knobs,true)
	knobs.merge(_head_knobs,true)
	head = enemies.spawn(InhalerHead,_head_spawn(float(ring.start)),_head_face(float(ring.start)),knobs)
	_adopt_head()
	_set_head(float(ring.start))

## The field remakes its enemies on reset: take the new head and count its gulps and blasts.
func _adopt_head() -> void:
	head = enemies.enemies[0] if not enemies.enemies.is_empty() else null
	if head == null: return
	head.gulped.connect(func(_e: Node) -> void: tally.gulps += 1)
	head.blew.connect(func(_e: Node) -> void:
		tally.blasts += 1
		_watch_landing = true)

## The ring's corner `i` (even: out at `radius`; odd: a look-in at `inner`).
func _corner(i: int) -> Vector3:
	var ring: Dictionary = LAYOUT.ring
	var n := int(ring.points)
	return _ring_point(360.0*float(posmod(i,n))/float(n),float(ring.radius) if posmod(i,2) == 0 else float(ring.inner))

## The leg of the ring at `deg` (0 north, clockwise): its corner index and
## the share along it.
func _leg_at(deg: float) -> Vector2:
	var step := 360.0/float(LAYOUT.ring.points)
	var u := fposmod(deg,360.0)/step
	return Vector2(floorf(u),u-floorf(u))

## Where the head sits at `deg` on the ring (on the turf).
func _head_spawn(deg: float) -> Vector3:
	var l := _leg_at(deg)
	var p := _corner(int(l.x)).lerp(_corner(int(l.x)+1),l.y)
	p.y = float(LAYOUT.isles[1].top)
	return p

## The way it travels at `deg` (clockwise, along its leg), as (x, z).
func _head_face(deg: float) -> Vector2:
	var l := _leg_at(deg)
	var way := _corner(int(l.x)+1)-_corner(int(l.x))
	return Vector2(way.x,way.z).normalized()

## The head set at `deg` on its ring, heading on clockwise.
func _set_head(deg: float) -> void:
	if head == null: return
	var ring: Dictionary = LAYOUT.ring
	head._leg = (int(_leg_at(deg).x)+1)%int(ring.points)
	var p := _head_spawn(deg)
	head.position = p
	head._ground = p.y
	head._act = ""
	head._rest = 0.5
	head.facing = PilotMotor.facing_of(_head_face(deg))
	head.rotation.y = head.facing
	head.vel = Vector3.ZERO

func place(at: Vector3, face: Vector2) -> void:
	super.place(at,face)
	_watch_landing = false
	if enemies != null:
		enemies.reset()
		_adopt_head()
		var deg := float(LAYOUT.ring.start)
		for s: Dictionary in LAYOUT.stations:
			if (s.at as Vector3).is_equal_approx(at) and s.has("head"): deg = float(s.head)
		_set_head(deg)
	if figure != null: figure.visible = true

## Which isle (or the hall) `p` is over.
func isle_at(p: Vector3) -> String:
	var hr: Rect2 = LAYOUT.hall.roof
	if hr.grow(0.01).has_point(Vector2(p.x,p.z)) and p.y < float(LAYOUT.hall.roof_bottom): return "in the hall"
	for isle: Dictionary in LAYOUT.isles:
		var tiers: Array = isle.tiers
		if tiers.is_empty(): tiers = [[isle.bounds,isle.top]]
		for t: Array in tiers:
			if (t[0] as Rect2).grow(0.01).has_point(Vector2(p.x,p.z)): return isle.name
	return "the gulf"

func tick(delta: float) -> void:
	super.tick(delta)
	# Where a blast left him: once he's up from the tumble.
	if _watch_landing and motor.grounded and motor.move != "tumble" and not motor.seized():
		_watch_landing = false
		tally.landed = motor.feet
		tally.isle = isle_at(motor.feet)

func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)

# --- The HUD and the sounds ---------------------------------------------------------------

func _hint_text() -> String:
	return "Astronomer's Hush (greybox) · 1 start, 2-8 the beats, 9/0/- the combo chains · R start · F1 numbers · Esc mouse · the head faces the way it goes; stone breaks its line; caught, it throws you on along its line"

func _show_hud() -> void:
	super._show_hud()
	if not _hud.visible or enemies == null or head == null: return
	var lines := PackedStringArray([_hud.text,""])
	lines.append("head  %s %.1fs · draw %.2f · pull on him %.1f m/s · gulps %d · blasts %d" % [head.state,head.state_t,head.draw_share,head.pulling,tally.gulps,tally.blasts])
	if tally.isle != "": lines.append("last blast left him on %s at (%.1f, %.1f) +%.1f" % [tally.isle,tally.landed.x,tally.landed.z,tally.landed.y])
	lines.append("stations: " + " · ".join(PackedStringArray((LAYOUT.stations as Array).map(func(s: Dictionary) -> String: return "%s %s" % [key_name(s.key),s.name]))))
	_hud.text = "\n".join(lines)

func _voice(sound_name: StringName, at: Vector3) -> void:
	var key := String(sound_name)
	if not VOICES.has(key): return
	if not _voices.has(key): _voices[key] = EnemyYard._synth(VOICES[key])
	var player := AudioStreamPlayer3D.new()
	player.stream = _voices[key]
	player.position = at
	player.unit_size = 10.0
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
