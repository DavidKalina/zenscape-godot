extends "res://studies/whole_body_chase.gd"
## The Earth Mouths yard (round 4 strange city, card a5-earth-mouths): three
## carved earth-monster mouths in the floor (scripts/city_mouths/), one belly
## between them, first in, first out; loose stones; a whole Olmec hunting
## you (the whole body chase's: sight, swat, pounce, inhale, periscope).
##
## The rule: they eat only dead weight (the Olmec, fallen stone, you while
## stunned), and feeding mouth n makes mouth n+1 spit the oldest thing
## inside (III's next is I). Awake, a mouth is a dark alcove you walk
## through. The belly starts with one old stone in it (`--belly=N`), so the
## first meal comes back as that stone and the one after brings the first
## back: feed him to one, then a stone to another, and he comes out of the
## mouth after that one.
##
## The tells: the dots on each altar (I, II, III); every mouth breathes mist
## while the belly holds anything; the mouth about to spit steams a column
## and grinds for 1.8 s first; the gulp is heard everywhere.
##
##   I    on the court, under terrace II's east cliff; spits south
##   II   on terrace II (7 m, ramp up its south side); spits south
##   III  on terrace III (12 m, the long ramp east); spits south
## Stones: one on terrace II's rim right over I (walk it off the rim: it
## drops into I), one by II, one by III, one on the court east of I. Walk
## or run into a stone to shove it; your slam beside it kicks it.
## The shortcut (Rule 0): jump off terrace II's rim into I (a 7 m fall
## stuns you): you ride the belly, and come out of II, after everything
## that was in before you. If he's in there, he comes out first.
##
##   godot --path . res://studies/strange_earth_mouths_yard.tscn -- --no-title
##     [--belly=N] [--underground[=torch|haze]] [--body-knob=k=v] [--head-knob=k=v]
##     [--body-at=x,z] [--body-face=x,z] [--no-body] [--no-sight-overlay]
##   1 start · 2 terrace II's rim over I (the stone, then the drop) · 3 by II
##   4 by III · 5 in I's throat (awake: nothing) · R start, all back
##   B him, the stones and the belly back · J his sight · F1 numbers
const Refuges = preload("res://scripts/city_kit_refuges.gd")
const GiantStone = preload("res://scripts/kit_isle/greybox/giant_stone.gd")
const Underground = preload("res://scripts/underground/underground.gd")
const EarthMouths = preload("res://scripts/city_mouths/earth_mouths.gd")
const LooseStone = preload("res://scripts/city_mouths/loose_stone.gd")

const COURT := Rect2(-48.0,-48.0,96.0,96.0)
const YARD_LOST := -30.0
## The terraces: [rect, top]; the ramps up them: [low, high, width].
const TERRACE_II := [Rect2(-48.0,-48.0,28.0,36.0),7.0]
const TERRACE_III := [Rect2(20.0,-48.0,28.0,36.0),12.0]
const MOUTH_RAMPS := [[Vector3(-34.0,0.0,9.0),Vector3(-34.0,7.0,-12.0),5.0],[Vector3(34.0,0.0,24.0),Vector3(34.0,12.0,-12.0),5.0]]
## The mouths in numeral order: [at, way out (x, z), where its spit lands].
const MOUTHS := [
	[Vector3(-15.4,0.0,-28.0),Vector2(0.0,1.0),Vector3(-14.0,0.0,-14.0)],
	[Vector3(-34.0,7.0,-30.0),Vector2(0.0,1.0),Vector3(-31.0,7.0,-17.0)],
	[Vector3(34.0,12.0,-30.0),Vector2(0.0,1.0),Vector3(31.0,12.0,-17.0)],
]
## The loose stones (their feet).
const STONES := [Vector3(-21.2,7.0,-28.0),Vector3(-34.0,7.0,-22.5),Vector3(34.0,12.0,-22.5),Vector3(-7.0,0.0,-30.0)]
const POST := Vector3(10.0,0.0,-30.0)
const POST_FACE := Vector2(-1.0,0.0)
const START_AT := Vector3(-4.0,0.0,32.0)
const MOUTH_STATIONS := [
	[1,"Start",START_AT,Vector2(0.0,-1.0)],
	[2,"Terrace II's rim over I",Vector3(-23.2,7.0,-28.0),Vector2(1.0,0.0)],
	[3,"By II",Vector3(-34.0,7.0,-18.5),Vector2(0.0,-1.0)],
	[4,"By III",Vector3(34.0,12.0,-18.5),Vector2(0.0,-1.0)],
	[5,"In I's throat",Vector3(-15.4,0.0,-28.0),Vector2(0.0,1.0)],
]
## The mouths' voices (enemy_yard.gd `_synth`: seconds, tone from, to, noise
## share, noise smoothing, attack, tremble). The gulp is heard everywhere.
const VOICES := {
	"mouth_gulp":[1.5,62.0,24.0,0.45,0.04,0.06,0.0],
	"mouth_grind":[1.8,0.0,0.0,1.0,0.22,0.35,9.0],
	"mouth_spit":[0.8,48.0,110.0,0.55,0.18,0.02,0.0],
	"stone_scrape":[0.45,0.0,0.0,1.0,0.3,0.03,22.0],
	"stone_thud":[0.5,52.0,34.0,0.6,0.12,0.003,0.0],
}

## The enemy field and the mouths stepped round the motor; the figure hidden
## while a head or the belly holds him.
class MouthSlot extends Node:
	var field: Node
	var mouths: Node
	func before(delta: float) -> void:
		field.before(delta)
		mouths.before(delta)
	func after(delta: float, events: Dictionary) -> void:
		field.after(delta,events)
		mouths.after(delta)
	func pose(figure: Node3D) -> void:
		var held: bool = mouths.hides_wanderer()
		for e in field.enemies:
			if is_instance_valid(e) and e.get("swallowed"): held = true
		figure.visible = not held

var under: Node3D
var mouths: Node3D
var _environment: Environment
var _sun: DirectionalLight3D
var _no_body := false
var _belly := 1

func _ready() -> void:
	body_at = POST
	body_face = POST_FACE
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg == "--no-body": _no_body = true
		elif arg.begins_with("--belly="): _belly = clampi(int(arg.get_slice("=",1)),0,6)
		elif arg.begins_with("--body-face="):
			var f := arg.get_slice("=",1).split(",")
			body_face = Vector2(float(f[0]),float(f[1]) if f.size() > 1 else 0.0).normalized()
		elif arg.begins_with("--body-at="):
			var p := arg.get_slice("=",1).split(",")
			body_at = Vector3(float(p[0]),0.0,float(p[1]) if p.size() > 1 else 0.0)
	super._ready()

func _load_pack() -> void:
	start = START_AT
	start_face = Vector2(0.0,-1.0)
	lost = YARD_LOST
	_last_stood = start
	stations = []
	for s: Array in MOUTH_STATIONS: stations.append({"key":s[0],"name":s[1],"spawn":s[2],"face":s[3],"parts":[]})

func _build_light() -> void:
	super._build_light()
	for n: Node in get_children():
		if n is WorldEnvironment: _environment = (n as WorldEnvironment).environment
		elif n is DirectionalLight3D: _sun = n

func _build_room() -> void:
	var m := Refuges.CityMesher.new(GiantStone.stone_colour())
	_build_court(m)
	for t: Array in [TERRACE_II,TERRACE_III]: _block(m,t[0],0.0,float(t[1]))
	for r: Array in MOUTH_RAMPS: _stone_ramp(m,r[0],r[1],float(r[2]))
	var mi := MeshInstance3D.new()
	mi.name = "Masonry"
	mi.mesh = m.mesh(Refuges.stone_material(),null)
	add_child(mi)
	if _no_body: _build_room_no_body()
	else: super._build_room()
	for at: Vector3 in STONES: enemies.spawn(LooseStone,at,Vector2(0.0,1.0))
	mouths = EarthMouths.new()
	add_child(mouths)
	mouths.setup(self,enemies,motor)
	mouths.stock = _belly
	for d: Array in MOUTHS: mouths.add_mouth(d[0],d[1],d[2])
	mouths.ate.connect(_ate)
	mouths.spat.connect(_spat)
	mouths.reset()
	var slot := MouthSlot.new()
	slot.field = enemies
	slot.mouths = mouths
	add_child(slot)
	foot_pieces = slot
	under = Underground.attach(self)
	for mouth: Node3D in mouths.mouths: print("earth mouths yard: mouth %s tris %d" % [EarthMouths.roman(mouth.numeral-1),int(mouth.get_meta("tris"))])
	var o := Refuges.olmec()
	print("earth mouths yard: throat %.2f m (his middle in by %.1f), lip %.2f m · olmec width %.2f neck %.2f · walker stun fall %.1f m · belly %d" % [
		EarthMouths.EarthMouth.throat_r(),EarthMouths.OLMEC_IN,EarthMouths.EarthMouth.lip_r(),o.width,o.neck,motor.fall_stun_height(),_belly])

## The stations' (empty) parts, no Olmec.
func _build_room_no_body() -> void:
	enemies = EnemyField.new()
	enemies.study = self
	enemies.motor = motor
	enemies.lost = lost
	enemies.sound_hook = _voice
	add_child(enemies)
	overlay = SightOverlay.new()
	add_child(overlay)

## The paved court (one collider, basalt flags), as the refuges yard's.
func _build_court(m: Object) -> void:
	_collider(Transform3D(Basis.IDENTITY,Vector3(COURT.get_center().x,-2.0,COURT.get_center().y)),Vector3(COURT.size.x,4.0,COURT.size.y),"Court")
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var flag := 6.0
	var nx := int(COURT.size.x/flag)
	var nz := int(COURT.size.y/flag)
	for i in nx:
		for j in nz:
			var x := COURT.position.x+(float(i)+0.5)*COURT.size.x/nx
			var z := COURT.position.y+(float(j)+0.5)*COURT.size.y/nz
			m.box(Transform3D(Basis.IDENTITY,Vector3(x,-0.3+rng.randf_range(-0.04,0.0),z)),Vector3(COURT.size.x/nx-0.06,0.6,COURT.size.y/nz-0.06),0.08,-0.6,rng.randf_range(0.82,1.02))
	preload("res://scripts/underground/ground_cover.gd").cover(self,COURT.grow(-0.5),"",0.0,41,{"tufts":0.5,"fade":1.0})

## A terrace: courses of big blocks, one collider.
func _block(m: Object, r: Rect2, bottom: float, top: float) -> void:
	_collider(Transform3D(Basis.IDENTITY,Vector3(r.get_center().x,(bottom+top)*0.5,r.get_center().y)),Vector3(r.size.x,top-bottom,r.size.y),"Terrace")
	var rng := RandomNumberGenerator.new()
	rng.seed = int(top*13.0+r.position.x)
	var course := 1.75
	var rows := maxi(1,int(roundf((top-bottom)/course)))
	var h := (top-bottom)/rows
	for k in rows:
		var y := bottom+(float(k)+0.5)*h
		var inset := 0.0 if k == rows-1 else 0.06*float(rows-1-k)
		m.box(Transform3D(Basis.IDENTITY,Vector3(r.get_center().x,y,r.get_center().y)),Vector3(r.size.x-inset,h-0.04,r.size.y-inset),0.12,bottom,rng.randf_range(0.86,1.0))

## A stone ramp from `low` to `high` (its walking face's middle line).
func _stone_ramp(m: Object, low: Vector3, high: Vector3, width: float) -> void:
	var along := (high-low).normalized()
	var side := Vector3.UP.cross(along).normalized()
	var up := along.cross(side).normalized()
	var size := Vector3(width,0.8,low.distance_to(high)+0.4)
	var place := Transform3D(Basis(side,up,along),(low+high)*0.5-up*0.4)
	_collider(place,size,"Ramp")
	m.box(place,size,0.1,low.y-0.5,0.9)

func _collider(place: Transform3D, size: Vector3, what: String) -> void:
	var b := StaticBody3D.new()
	b.name = what
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	c.shape = s
	b.add_child(c)
	b.transform = place
	add_child(b)

## The body's knobs here: the chase's periscope; walker-only stone hides you.
func _study_body_knobs() -> Dictionary:
	return {"periscope":1,"sight_walker_only":1}

## Held in the belly, he is still this yard's Olmec (not gone: no respawn).
func stone_body() -> Node3D:
	var b := super.stone_body()
	if b == null and mouths != null: b = mouths.held_olmec()
	return b

func stone_head() -> Node3D:
	var h := super.stone_head()
	if h == null and mouths != null: h = mouths.held_head()
	return h

## B (and R): him, the stones and the belly back as they began.
func reset_body() -> void:
	super.reset_body()
	if mouths != null: mouths.reset()

func _ate(kind: String, i: int) -> void:
	var nxt := EarthMouths.roman(mouths.next_of(i))
	match kind:
		"olmec": _say("%s swallowed the Olmec · %s will spit the oldest inside" % [EarthMouths.roman(i),nxt],3.0)
		"stone": _say("%s swallowed a stone · %s will spit the oldest inside" % [EarthMouths.roman(i),nxt],3.0)
		"wanderer": _say("Stunned, you are swallowed by %s · out of %s, last in line" % [EarthMouths.roman(i),nxt],3.0)

func _spat(kind: String, i: int) -> void:
	var what: String = {"olmec":"the Olmec","stone":"a stone","wanderer":"you"}.get(kind,kind)
	_say("%s spat out %s" % [EarthMouths.roman(i),what],2.5)

func tick(delta: float) -> void:
	# No Olmec asked for: none to bring back (the chase study's respawn
	# would reset the belly every 3 s).
	if _no_body: _gone_t = 0.0
	super.tick(delta)
	if under != null and _sun != null: _sun.visible = false
	if overlay != null and mouths != null and overlay.body != null and is_instance_valid(overlay.body):
		overlay.visible = _overlay_on and (overlay.body as Node3D).visible

func _hint_text() -> String:
	return "Earth Mouths · they eat dead weight: him, stone, you stunned · feed n, n+1 spits the oldest (dots on the altars: I II III) · shove stones · 1-5 stations · B all back · J his sight · F1 numbers"

func _show_hud() -> void:
	super._show_hud()
	if not _hud.visible or mouths == null: return
	var lines := PackedStringArray([_hud.text,""])
	lines.append(mouths.belly_text())
	lines.append("eaten olmec %d stone %d you %d · spat olmec %d stone %d you %d" % [mouths.eaten.olmec,mouths.eaten.stone,mouths.eaten.wanderer,mouths.spat_n.olmec,mouths.spat_n.stone,mouths.spat_n.wanderer])
	for s: String in mouths.said: lines.append("  "+s)
	_hud.text = "\n".join(lines)

func _voice(sound_name: StringName, at: Vector3) -> void:
	var key := String(sound_name)
	if not VOICES.has(key):
		super._voice(sound_name,at)
		return
	if not _voices.has(key): _voices[key] = EnemyYard._synth(VOICES[key])
	if key == "mouth_gulp":
		# Heard the layer over: the queue moved.
		var flat := AudioStreamPlayer.new()
		flat.stream = _voices[key]
		flat.volume_db = -2.0
		add_child(flat)
		flat.finished.connect(flat.queue_free)
		flat.play()
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = _voices[key]
	player.position = at
	player.unit_size = 24.0 if key.begins_with("mouth") else 10.0
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
