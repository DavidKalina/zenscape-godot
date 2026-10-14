extends "res://studies/character_study.gd"
## GREYBOX (roguelike round 1, Opus pass) of the Plumb Well motif card
## (docs/design/roguelike/brainstorm/round1/motif-m4-plumb-well.md): five
## stone plates stacked in a column against one tall wall (the plumb wall,
## where the stone was lowered), every oculus in one line down it, one trap
## on each of the three middle plates (the real flip leaf, seesaw drop and
## loose voussoirs) and the real inhaler head at the foot, so the five-source
## chain down the shaft runs with the real pilot and no input.
## Grey is structure, orange the oculus lips; the shaft is open on three
## sides (the plumb wall on the north only) so the camera sees in.
##
## THE CHAIN (combo 1, every link event-driven, none on a shared clock):
##   cap: walk off into oculus 1 -> 9 m, fall-stunned onto the LEAF (plate 2)
##   leaf: it turns every 3 s; whenever he lies or stands on it, its next
##         flip throws him north into the plumb wall, and he drops down the
##         0.8 m slot between the leaf and the wall (pinned to the wall's line)
##   slot: he drops onto the far end of the SEESAW (plate 3), whose far end
##         butts a kerb (he can't slide off); lying on its plate half a second
##         lets the block fall on the near end: flung up and south, still
##         stunned, off the span, down oculus 3
##   slabs: he lands on the VOUSSOIRS over oculus 4 (plate 4); they go, he
##         falls 8 m to the foot
##   head: it faces the slabs; the moment they go it sees him (close enough
##         to tell at once) and he comes down in its mouth's reach: gulped,
##         still stunned, blasted south out of rim S
##
## Number keys (the STATIONS table below):
##   1 the cap        2 plate 2        3 plate 3, the seesaw
##   4 plate 4        5 the foot       6 combo 1: the whole column
##   7 combo 2: the seesaw leg   8 combo 3: the Olmec cannon   9 the leaf's lip
## R back to the start (traps rebuilt, the head back) · F1 numbers + the chain log
##   godot --path . res://studies/greybox/plumb_well.tscn -- --no-title
##   [--well-log] prints the chain log (knocks, stuns, landings) to the console
##
## THE LAYOUT IS ONE TABLE (PLATES, SPINE, WALLS, TRAPS, ENEMIES, STATIONS,
## LABELS below); the rest of the script only builds from it, so a later turf
## pass (KitLand.island) can lift it mechanically. Each plate is ONE isle
## entry: a rect, a top, its holes (the oculi) and its tiers; each wall is a
## box with a bottom and a top; each trap, enemy and station has a place and
## a facing. Sizes are from the pilot (PUMP = Trap.pilot().jumps[1] = 1.5 m at
## the wanderer's size 1.0; `_check_pilot` warns if that has moved).
const Trap = preload("res://scripts/traps/trap.gd")
const TrapField = preload("res://scripts/traps/trap_field.gd")
const FlipTrap = preload("res://scripts/traps/trap_flip.gd")
const DropTrap = preload("res://scripts/traps/trap_seesaw_drop.gd")
const VoussoirTrap = preload("res://scripts/traps/trap_voussoirs.gd")
const EnemyField = preload("res://scripts/enemies/enemy_field.gd")
const InhalerHead = preload("res://scripts/enemies/inhaler_head.gd")
const EnemyYard = preload("res://studies/enemy_yard.gd")

## One pump (the pilot's second jump) at the wanderer's size 1.0.
const PUMP := 1.5
## Plate spacing: 6 pumps (9 m, past the fall stun's 4 pumps = 6 m), except
## the last: plate 4 sits 8 m over the foot, so a body on it as its slabs go
## is inside the head's tell range (reach x 0.8 = 8.5 m from its mouth) the
## moment it is seen.
const H := 9.0
const FOOT_DROP := 8.0
const THICK := 1.5
const LOST_UNDER := -30.0
## The plumb wall's south face (z): every oculus runs along it.
const WALL_Z := 12.0

## The plates, top to bottom. name, rect (x, z), top, holes (the oculi: where
## the plate has no floor), tiers ([rect, rise over the plate top]).
const PLATES := [
	{"name":"1  the cap","rect":Rect2(-14.0,-14.0,28.0,26.0),"top":FOOT_DROP+3.0*H,
		"holes":[Rect2(-1.8,8.1,3.6,3.9)],"tiers":[]},
	# The leaf's pit (z 8.6..11.2) and the 0.8 m slot to the wall (11.2..12).
	{"name":"2  the leaf plate","rect":Rect2(-14.0,-14.0,28.0,26.0),"top":FOOT_DROP+2.0*H,
		"holes":[Rect2(-2.0,8.6,4.0,3.4)],"tiers":[]},
	# The seesaw's pit along the wall and, south of it, oculus 3 the fling falls down.
	{"name":"3  the seesaw plate","rect":Rect2(-14.0,-14.0,28.0,26.0),"top":FOOT_DROP+H,
		"holes":[Rect2(-4.0,1.5,12.1,10.5)],"tiers":[]},
	# Oculus 4, all of it slabs.
	{"name":"4  the loose floor","rect":Rect2(-14.0,-14.0,28.0,26.0),"top":FOOT_DROP,
		"holes":[Rect2(-5.0,3.1,6.0,5.4)],"tiers":[]},
	{"name":"5  the foot (the head's)","rect":Rect2(-14.0,-4.0,28.0,16.0),"top":0.0,"holes":[],
		"tiers":[{"rect":Rect2(7.0,4.0,6.0,6.0),"rise":0.9}]},
]
## The spine of columns (wall-kickable), floor to cap: off the drop line and
## the blast's.
const SPINE := {"at":Vector2(6.0,-4.0),"radius":1.2}
## Wall boxes: rect (x, z), bottom, top. The plumb wall (north) floor to cap;
## the kerb at the seesaw's far end, its top flush with plate 3 (the seesaw's
## low end butts its face, so a body lying there can't slide off).
const WALLS := [
	{"name":"plumb wall","rect":Rect2(-16.0,WALL_Z,32.0,1.0),"bottom":-THICK,"top":FOOT_DROP+3.0*H},
	{"name":"kerb","rect":Rect2(-1.6,9.5,0.7,2.5),"bottom":FOOT_DROP+H-THICK,"top":FOOT_DROP+H},
]
## The stand-in windlass on the cap (a drum by the oculus).
const WINDLASS := {"at":Vector2(4.0,10.5),"radius":0.6,"rise":1.6}
## The traps: script key, place (the trap's way-in point, its route along
## local -z), yaw about up (degrees), knob overrides.
const TRAPS := [
	# One stone leaf (2.4 x 3.6 m) across oculus 2, route south: its flip
	# throws him back along local +z, north, into the wall and down the slot.
	# Both faces walkable ("safe"): a "slick" face slid him off its edge on
	# his feet, and he caught the edge as a ledge and hung there; "gone" drops
	# him through its pit 1.5 m short of the wall's line.
	{"name":"leaf","script":"flip","at":Vector3(0.0,FOOT_DROP+2.0*H,11.2),"yaw":0.0,
		"knobs":{"count":1,"length":2.4,"width":3.6,"gap":0.0,"stagger":0.0,"period":3.0,"underside":"safe","speedup":0.0}},
	# The seesaw along the wall, route west: block over the near (east) end,
	# the fuse plate on the far (west) end, the far end against the kerb. Its
	# veer (+x local) is south. Fuse 0.5 s (the trap's 1.0): the block lands
	# 0.95 s after he does, while the 9 m fall still has him down (1.15 s).
	{"name":"seesaw","script":"drop","at":Vector3(8.1,FOOT_DROP+H,WALL_Z-1.25),"yaw":90.0,
		"knobs":{"length":9.0,"hook":3.6,"plate":true,"fuse":0.5,"ledge":0.0,"cap_mul":1.0,"along":0.15,"veer":0.45}},
	# Three slab rows over oculus 4, route south.
	{"name":"slabs","script":"voussoirs","at":Vector3(-2.0,FOOT_DROP,8.5),"yaw":0.0,
		"knobs":{"count":3,"length":1.8,"width":5.96}},
]
## The enemies: script key, place, the way it faces (x, z), knobs. The route
## is a stub (one point at home), so the head stays on its post. It faces
## south (its blast goes out of rim S) with its mouth 0.3-0.9 m north of where
## a body falls from the slabs (the fling's skid on them included), and its
## chin clear of that line: square on, it tells the frame it sees him and
## gulps him as he comes past its mouth.
const HEAD_AT := Vector3(-2.4,0.0,6.7)
const ENEMIES := [
	{"name":"head","script":"inhaler_head","at":HEAD_AT,"face":Vector2(0.0,-1.0),
		"knobs":{"route":[HEAD_AT,HEAD_AT+Vector3(0.5,0.0,0.0)]}},
]
## The stations: key, name, where he is set down, the way he faces (x, z).
const STATIONS_AT := [
	{"key":1,"name":"The cap · oculus 1 against the plumb wall","at":Vector3(0.0,FOOT_DROP+3.0*H,2.0),"face":Vector2(0.0,1.0)},
	{"key":2,"name":"Plate 2 · the leaf ahead","at":Vector3(5.0,FOOT_DROP+2.0*H,8.0),"face":Vector2(-1.0,0.4)},
	{"key":3,"name":"Plate 3 · the seesaw along the wall","at":Vector3(10.0,FOOT_DROP+H,8.0),"face":Vector2(-0.6,0.5)},
	{"key":4,"name":"Plate 4 · the loose slabs ahead","at":Vector3(-2.0,FOOT_DROP,11.0),"face":Vector2(0.0,-1.0)},
	{"key":5,"name":"The foot · the head to the NW","at":Vector3(4.0,0.0,2.0),"face":Vector2(-0.8,0.6)},
	{"key":6,"name":"COMBO 1 start · cap, walk off north into oculus 1 (and let go)","at":Vector3(0.0,FOOT_DROP+3.0*H,5.5),"face":Vector2(0.0,1.0)},
	{"key":7,"name":"COMBO 2 leg · plate 3, on the seesaw's fuse plate (stay up, take the fling)","at":Vector3(0.0,FOOT_DROP+H,10.75),"face":Vector2(1.0,0.0)},
	{"key":8,"name":"COMBO 3 start · the foot, in the head's face (don't run)","at":Vector3(-2.4,0.0,1.5),"face":Vector2(0.0,1.0)},
	{"key":9,"name":"Plate 2 · the leaf's lip (time the flip)","at":Vector3(0.0,FOOT_DROP+2.0*H,7.6),"face":Vector2(0.0,1.0)},
]
## Floating labels: place, text.
const LABELS := [
	[Vector3(0.0,FOOT_DROP+3.0*H+2.5,8.0),"CAP · oculus 1 (rope-worn lip) against the plumb wall · 9 m to the leaf"],
	[Vector3(4.0,FOOT_DROP+3.0*H+3.0,10.5),"STAND-IN: windlass (a drum; no hook or rope)"],
	[Vector3(0.0,FOOT_DROP+2.5*H,10.5),"STAND-IN: daylight bar (a translucent column; a light piece later)"],
	[Vector3(-8.0,FOOT_DROP+3.0*H+3.0,12.5),"PLUMB WALL (every oculus runs down it in one line; the rope groove and the chalk runes go here). STAND-IN: one wall; the shaft's other sides open"],
	[Vector3(0.0,FOOT_DROP+2.0*H+6.0,8.0),"COMBO 1 · THE WHOLE COLUMN: walk off into oculus 1 -> leaf hands you into the slot -> seesaw fuse, block, fling south -> slabs go -> the head's mouth"],
	[Vector3(0.0,FOOT_DROP+2.0*H+3.5,9.0),"BEAT 3 · PLATE 2: THE LEAF (one stone leaf, flips every 3 s; caught on it as it turns, you are thrown north into the wall and down the 0.8 m slot)"],
	[Vector3(4.0,FOOT_DROP+H+5.5,10.5),"BEAT 4 · PLATE 3: THE SEESAW DROP (lie or stand on its far plate 0.5 s: the block falls on the near end, flings you south down oculus 3)"],
	[Vector3(-1.2,FOOT_DROP+H+1.2,10.5),"kerb: the seesaw's far end butts it"],
	[Vector3(4.0,FOOT_DROP+H+4.2,8.0),"STAND-IN: the plumb block is the seesaw's own block on its hook; nothing runs the shaft on a chain"],
	[Vector3(-2.0,FOOT_DROP+3.5,4.0),"BEAT 5 · PLATE 4: LOOSE SLABS (they go a beat after you land, all of them after)"],
	[Vector3(-6.0,FOOT_DROP+H+3.0,4.0),"COMBO 2 · THREADED: run off the cap past the leaf, down the slot -> stand on the seesaw's plate, take the fling on your feet -> roll onto the slabs -> fall with them steering south -> roll, run out of rim S"],
	[Vector3(-2.0,5.5,8.5),"BEAT 6 · THE FOOT: the inhaler head (real), watching the slabs"],
	[Vector3(-2.0,3.0,-3.0),"RIM S (over the void) · COMBO 3 · THE OLMEC CANNON: stand in its face; the blast throws you out of this rim"],
	[Vector3(10.0,2.4,7.0),"masons' gallery (a bench tier, 0.9 m)"],
	[Vector3(6.0,FOOT_DROP+H+3.0,-4.0),"the spine (wall-kick up the column)"],
]

var traps: Node3D
var enemies: Node
## The chain log: [seconds, text] of every knock, stun, trap act and landing.
var chain_log: Array = []
var _voices := {}
var _seen := {}
var _t := 0.0
var _log_out := false

const VOICES := {
	"head_grind":[0.9,0.0,0.0,1.0,0.07,0.05,13.0],
	"head_inhale":[3.0,0.0,0.0,1.0,0.22,0.9,0.0],
	"head_yank":[0.35,0.0,0.0,1.0,0.4,0.01,0.0],
	"head_gulp":[0.45,70.0,40.0,0.4,0.15,0.005,0.0],
	"head_blast":[0.9,0.0,0.0,1.0,0.55,0.005,0.0],
}

## Steps the traps then the enemies; hides the figure while the head holds him.
class Slot extends Node:
	var traps: Node
	var enemies: Node
	func before(delta: float) -> void:
		traps.before(delta)
		enemies.before(delta)
	func after(delta: float, events: Dictionary) -> void:
		traps.after(delta,events)
		enemies.after(delta,events)
	func pose(figure: Node3D) -> void:
		var held := false
		for e in enemies.enemies:
			if is_instance_valid(e) and e.get("swallowed"): held = true
		figure.visible = not held

func _ready() -> void:
	pack = "plumb_well"
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg == "--well-log": _log_out = true
	_check_pilot()
	super._ready()

## The table's metres are the pilot's at the default size: say so if not.
func _check_pilot() -> void:
	var p := Trap.pilot()
	if not is_equal_approx(float(p.jumps[1]),PUMP):
		push_warning("plumb well: the pilot's pump is %.2f m, the table was laid for %.2f" % [float(p.jumps[1]),PUMP])

func _load_pack() -> void:
	var first: Dictionary = STATIONS_AT[0]
	start = first.at
	start_face = (first.face as Vector2).normalized()
	lost = LOST_UNDER
	_last_stood = start
	stations = []
	for s: Dictionary in STATIONS_AT:
		stations.append({"key":s.key,"name":s.name,"spawn":s.at,"face":(s.face as Vector2).normalized(),
			"sign":(s.at as Vector3)+Vector3(0.0,3.2,0.0),"parts":_structure() if int(s.key) == 1 else []})

## Every structural part, from the table: the station format's parts.
func _structure() -> Array:
	var parts := []
	var top_all: float = PLATES[0].top
	for pl: Dictionary in PLATES:
		var rect: Rect2 = pl.rect
		var top: float = pl.top
		var holes: Array[Rect2] = []
		for h: Rect2 in pl.holes: holes.append(h)
		for r in _floor_rects(rect,holes):
			parts.append(["box",r,top-THICK,top,"floor"])
		for h: Rect2 in holes:
			# The oculus lip: a thin orange rim round the hole (not into the wall).
			for r: Rect2 in [Rect2(h.position.x-0.4,h.position.y-0.4,h.size.x+0.8,0.4),Rect2(h.position.x-0.4,h.end.y,h.size.x+0.8,0.4),
					Rect2(h.position.x-0.4,h.position.y,0.4,h.size.y),Rect2(h.end.x,h.position.y,0.4,h.size.y)]:
				if r.position.y >= WALL_Z-0.01: continue
				parts.append(["box",r,top-0.05,top+0.02,"lip"])
		for t: Dictionary in pl.tiers:
			parts.append(["box",t.rect,top,top+float(t.rise),"grey"])
		parts.append(["label",Vector3(rect.position.x+4.0,top+0.8,rect.position.y+3.0),"PLATE %s · top %d m" % [pl.name,int(top)]])
	var spine_r: float = SPINE.radius
	parts.append(["cyl",SPINE.at,spine_r,-THICK,top_all,"grey"])
	for w: Dictionary in WALLS: parts.append(["box",w.rect,float(w.bottom),float(w.top),"wall"])
	parts.append(["cyl",WINDLASS.at,WINDLASS.radius,top_all,top_all+float(WINDLASS.rise),"dark"])
	for l: Array in LABELS: parts.append(["label",l[0],l[1]])
	return parts

func _build_room() -> void:
	super._build_room()
	# The daylight bar: oculus 1's column, down to plate 2 (drawn only).
	var bar := MeshInstance3D.new()
	var box := BoxMesh.new()
	var o1: Rect2 = PLATES[0].holes[0]
	var drop: float = float(PLATES[0].top)-float(PLATES[1].top)
	box.size = Vector3(o1.size.x,drop,o1.size.y)
	bar.mesh = box
	bar.position = Vector3(o1.get_center().x,float(PLATES[0].top)-drop*0.5,o1.get_center().y)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0,0.95,0.7,0.12)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bar.material_override = m
	bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bar)
	# The traps, from the table.
	traps = TrapField.new()
	add_child(traps)
	traps.attach(self)
	var scripts := {"flip":FlipTrap,"drop":DropTrap,"voussoirs":VoussoirTrap}
	for t: Dictionary in TRAPS:
		var trap: Node3D = (scripts[t.script] as GDScript).new()
		trap.configure(t.knobs)
		trap.transform = Transform3D(Basis(Vector3.UP,deg_to_rad(float(t.yaw))),t.at)
		traps.add(trap)
	# The enemies, from the table.
	enemies = EnemyField.new()
	enemies.study = self
	enemies.motor = motor
	enemies.lost = lost
	enemies.sound_hook = _voice
	add_child(enemies)
	for e: Dictionary in ENEMIES:
		enemies.spawn(InhalerHead,e.at,(e.face as Vector2).normalized(),e.knobs.duplicate())
	var slot := Slot.new()
	slot.traps = traps
	slot.enemies = enemies
	add_child(slot)
	foot_pieces = slot
	# The head's draw in the pocket sail's wind.
	var base_air: Callable = motor.air
	motor.air = func(p: Vector3) -> Dictionary:
		var here: Dictionary = base_air.call(p) if base_air.is_valid() else {}
		var wind := Vector3.ZERO
		for e in enemies.enemies:
			if is_instance_valid(e) and e.has_method("sail_wind"): wind += e.sail_wind(p)
		if wind == Vector3.ZERO: return here
		var out := here.duplicate()
		out["wind"] = (here.get("wind",Vector3.ZERO) as Vector3)+wind
		return out

## Set down: the traps as built, the head back.
func place(at: Vector3, face: Vector2) -> void:
	if traps != null: traps.reset()
	super.place(at,face)
	if enemies != null: enemies.reset()
	if figure != null: figure.visible = true
	_seen = {}
	if traps != null: _note("placed","placed at %s" % str(at))

func hatch() -> Node3D: return traps.named("flip") if traps != null else null
func dropper() -> Node3D: return traps.named("seesaw_drop") if traps != null else null
func slabs() -> Node3D: return traps.named("voussoirs") if traps != null else null
func head() -> Node3D:
	if enemies == null: return null
	for e in enemies.enemies:
		if is_instance_valid(e) and e.has_method("mouth"): return e
	return null

## The plate index (1..5) whose top he is at or over (feet y), 0 above all.
func plate_of(y: float) -> int:
	for i in PLATES.size():
		if y >= float(PLATES[i].top)-1.4: return i+1
	return PLATES.size()

func tick(delta: float) -> void:
	super.tick(delta)
	_t += delta
	_watch()

func _note(key: String, text: String) -> void:
	chain_log.append([_t,text])
	if _log_out: print("[well %.2f] %s" % [_t,text])

func _changed(key: String, value: Variant) -> bool:
	var was: Variant = _seen.get(key,null)
	_seen[key] = value
	return was != null and was != value

func _watch() -> void:
	if motor == null or traps == null or not walk_ready: return
	var where := "plate %d (%.1f, %.1f, y %.1f)" % [plate_of(motor.feet.y),motor.feet.x,motor.feet.z,motor.feet.y]
	if _changed("stun",String(motor.stunned)):
		_note("stun","stun '%s' -> '%s' at %s" % [_seen.get("stun_was",""),String(motor.stunned),where])
	_seen["stun_was"] = String(motor.stunned)
	var h := hatch()
	var d := dropper()
	var v := slabs()
	var e := head()
	if h != null and _changed("knocks",h.knocks): _note("knocks","LEAF tossed him at %s" % where)
	if d != null and _changed("drops",d.drops): _note("drops","SEESAW block let go at %s" % where)
	if d != null and _changed("launches",d.launches): _note("launch","SEESAW flung (%s) at %s" % [str(d.last_launch),where])
	if v != null and _changed("fallen",v.fallen_count): _note("fallen","SLAB fell (%d) at %s" % [v.fallen_count,where])
	if e != null:
		if _changed("gulps",e.gulps): _note("gulps","HEAD gulped him at %s" % where)
		if _changed("blasts",e.blasts): _note("blasts","HEAD blasted him from %s" % where)
		if _changed("hstate",String(e.state)): _note("hstate","head %s" % String(e.state))
	if motor.grounded and _changed("plate",plate_of(motor.feet.y)): _note("plate","landed on %s" % where)

func _hint_text() -> String:
	return "Plumb well greybox: 1 cap 2-4 plates 5 foot 6 combo 1 7 combo 2 8 combo 3 9 leaf lip · R start (traps rebuilt) · F1 numbers + chain log · Esc mouse · drop through the oculi; Space in the air for the sail"

func _show_hud() -> void:
	super._show_hud()
	if _hud == null or not _hud.visible or traps == null: return
	var lines := PackedStringArray([_hud.text,""])
	var h := hatch()
	var d := dropper()
	var v := slabs()
	var e := head()
	lines.append("plate %d · stun '%s' · move %s" % [plate_of(motor.feet.y),String(motor.stunned),motor.move])
	if h != null: lines.append("leaf  %s · face up: %s · tossed %d" % [["flat","tell","flip"][int(h.slabs[0].phase)],"under" if h.upside_down(h.slabs[0]) else "stone",h.knocks])
	if d != null: lines.append("seesaw  tilt %.2f · block %s · drops %d · launches %d" % [d.tilt,"falling" if d.released else "hung",d.drops,d.launches])
	if v != null: lines.append("slabs  fallen %d / %d" % [v.fallen_count,v.slabs.size()])
	if e != null: lines.append("head  %s %.1fs · draw %.2f · pull %.1f · gulps %d blasts %d" % [e.state,e.state_t,e.draw_share,e.pulling,e.gulps,e.blasts])
	var from := maxi(chain_log.size()-6,0)
	for i in range(from,chain_log.size()): lines.append("  %.1f  %s" % [chain_log[i][0],chain_log[i][1]])
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
