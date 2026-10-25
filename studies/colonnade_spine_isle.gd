extends "res://studies/kit_isle.gd"
## The colonnade spine: a long knife-edge ridge isle in the sky, a
## processional colonnade the length of its crest climbing west in terraces
## to a temple gate on its high head, its tail curling away east in
## fragments stepping down, tied by stepping stones and live rope bridges.
## See docs/scenic/colonnade-spine.md and studies/colonnade_spine_isle_art.gd.
##
## Everything else is the kit isles' (studies/kit_isle.gd, docs/scenic/
## kit-isle-shared.md): the pilot and his moves (the character study's),
## the rope bridges underfoot, the ground and rock, the game's grass and
## flowers (scripts/kit_isle/kit_flora.gd), its light, sky, air, weather and the look
## presets (L / Shift+L, --look=<id>), the plane (F), the lodestone, the sky
## round it (far isles, airships, CPU planes, sky life, motes; its tokens
## here this isle's own: studies/colonnade_spine_isle_sky.gd) and the life
## on it (undergrowth, butterflies, fireflies, songbirds on the stones, the
## wind made visible, on-foot tokens: studies/colonnade_spine_isle_life.gd).
## The same opt-outs: --no-flora, --no-life (--no-undergrowth,
## --no-butterflies, --no-fireflies, --no-birds, --no-wind-life,
## --no-tokens), --no-sky (--no-far-isles, --no-airships, --no-traffic,
## --no-sky-life, --no-motes, --no-sky-tokens), --no-lode, --fly.
##   R            back to the start (the low end of the way, looking west)
##   L / Shift+L  next / previous look preset
##   B            a strong gust front
##   Space (pad A) by the parked plane: into it; land by hand, F (pad Y) out once stopped
##   ./run-colonnade-spine.command [--look=first_snow]
##   godot --path . res://studies/colonnade_spine_isle.tscn -- --no-title [--capture=out.png --at=x,y,z --look=x,y,z] [--place=x,y,z[,turn]]
## --olmec (./run-olmec-colonnade.command): the headless body (scripts/enemies/
## headless_body.gd) stood at the low east end, its head heaving on the
## plaza up west; the colonnade's plain piers and lintels breakable
## (scripts/kit_isle/colonnade_breaks.gd): he plows through them, his
## landings' shockwaves topple them, and they lie where they fall as rubble
## to climb. R sets him and his head back; the breaks stay.
## Round 2: his head heaves in the temple's
## cella, behind the rose gable; he climbs the way and the grand stair to
## it and punches through the gable's door, bringing it down in slabs; the
## portals' arches come down too.
## [--body-knob=<knob>=<value>] [--head-knob=...] (repeatable),
## [--olmec-at=x,z] [--head-at=x,z] (along the axis, across it).
const Spine = preload("res://studies/colonnade_spine_isle_art.gd")
const SpineSky = preload("res://studies/colonnade_spine_isle_sky.gd")
const SpineLife = preload("res://studies/colonnade_spine_isle_life.gd")
const Art = preload("res://studies/aqueduct_isle_art.gd")
const Footbridge = preload("res://scripts/footbridge.gd")
## The isle itself (its art and turf), built here at the origin as the
## aqueduct isle's sky places it elsewhere (scripts/kit_isle/
## motif_colonnade_spine.gd).
const Motif = preload("res://scripts/kit_isle/motif_colonnade_spine.gd")

const SPINE_SEED := Motif.SPINE_SEED
## The kit stairs a little ruined: a ceremonial way up.
const STAIR_WEATHERED := Motif.STAIR_WEATHERED
## Where he starts: on the way's low terrace, by its east end, looking west
## up the colonnade to the temple gate.
const START_AT := Vector3(130.5,Spine.TOP+Spine.L0,0.0)
## Falling past this (world y) he is set back where he last stood's nearest
## safe place: the start.
const LOST_Y := Spine.TOP-28.0

var motif := Motif.new()
## The colonnade, the temple and what lies on the isle (metadata drives the
## tests: piers, lintels, portals, ways up).
var colonnade: Node3D
var temple: Node3D
var spine: Node3D
var bridges: Array[MeshInstance3D] = []

# --- The Olmec (--olmec) ----------------------------------------------------------
const EnemyField = preload("res://scripts/enemies/enemy_field.gd")
const InhalerHead = preload("res://scripts/enemies/inhaler_head.gd")
const HeadlessBody = preload("res://scripts/enemies/headless_body.gd")
const BodySpawner = preload("res://scripts/enemies/body_spawner.gd")
const EnemyYard = preload("res://studies/enemy_yard.gd")
const Breaks = preload("res://scripts/kit_isle/colonnade_breaks.gd")
const Breakables = preload("res://scripts/breaks/breakables.gd")
## Where he and his head are set down: (x along the axis, d across it), on
## the ground there. He stands on the low terrace's east end, facing up the
## way; his head heaves in the temple's cella on the podium, behind the
## rose gable (round 1's: on the plaza, `--head-at=58,0`).
const OLMEC_AT := Vector2(127.0,0.0)
const OLMEC_HEAD_AT := Vector2(36.0,0.0)
const OLMEC_STEP := 2.4
var olmec := false
var enemies: Node
var breaks: Node3D
## The breakables hub (scripts/breaks/breakables.gd): every body's
## breaker, the colonnade's breaks one of its `others`.
var hub: Node3D
var _olmec_at := OLMEC_AT
var _head_at := OLMEC_HEAD_AT
var _body_knobs := {}
var _head_knobs := {}
var _voices := {}

## Hides the figure while the head holds him, steps the enemies, and hands
## every body (a new one after R too) the breaks' hub.
class Slot extends Node:
	var field: Node
	var breaks: Node3D
	func before(delta: float) -> void:
		for e in field.enemies:
			if is_instance_valid(e) and e.has_method("world_changed") and e.breaker == null: e.breaker = breaks
		field.before(delta)
	func after(delta: float, events: Dictionary) -> void: field.after(delta,events)
	func pose(figure: Node3D) -> void:
		var held := false
		for e in field.enemies:
			if is_instance_valid(e) and e.get("swallowed"): held = true
		figure.visible = not held

func _ready() -> void:
	for arg in preload("res://scripts/launch_args.gd").user_args():
		if arg == "--olmec": olmec = true
		elif arg.begins_with("--olmec-at="): _olmec_at = _xz(arg.get_slice("=",1))
		elif arg.begins_with("--head-at="): _head_at = _xz(arg.get_slice("=",1))
		for pair in [["--body-knob=",_body_knobs],["--head-knob=",_head_knobs]]:
			if arg.begins_with(pair[0]):
				var kv: String = arg.trim_prefix(pair[0])
				pair[1][kv.get_slice("=",0)] = float(kv.get_slice("=",1))
	motif.breakable = olmec
	super._ready()

static func _xz(s: String) -> Vector2:
	var p := s.split(",")
	return Vector2(float(p[0]),float(p[1]) if p.size() > 1 else 0.0)

## The axis point (x, d) on the ground (world).
func _on_ground(xd: Vector2) -> Vector3:
	var q := Spine.at(xd.x,xd.y)
	return Vector3(q.x,Spine.ground(q.x,q.y),q.y)

## The body, its head and the breaks (--olmec).
func _build_olmec() -> void:
	breaks = Breaks.new()
	art.add_child(breaks)
	breaks.setup(colonnade,SPINE_SEED+1)
	breaks.setup_gable(temple,Motif.TEMPLE_SEED)
	breaks.lost_y = LOST_Y
	breaks.sound_hook = _voice
	enemies = EnemyField.new()
	enemies.study = self
	enemies.motor = motor
	enemies.lost = lost
	enemies.sound_hook = _voice
	add_child(enemies)
	breaks.field = enemies
	hub = Breakables.new()
	hub.field = enemies
	hub.sound_hook = _voice
	hub.others = [breaks]
	breaks.hub = hub
	art.add_child(hub)
	var slot := Slot.new()
	slot.field = enemies
	slot.breaks = hub
	add_child(slot)
	foot_pieces = slot
	# The body first, so the head reads its neck where it is this frame.
	var at := _on_ground(_olmec_at)
	var head := _on_ground(_head_at)
	var face := Vector2(head.x-at.x,head.z-at.z).normalized()
	# The terraces' step walls (2.24 m) are knee-high to him: he strides up
	# them (his step, 1.23 m elsewhere, here OLMEC_STEP) rather than climbing
	# them, a stair's cheeks under his bulk.
	# Whole again, he hunts the walker (the whole body's chase: whole-body-
	# chase-round1.md), through the colonnade.
	# Round 2: relentless; his searching stops to listen briefly and seldom.
	var knobs := {"step":OLMEC_STEP,"chase":1.0,"listen":1.2,"listen_every":12.0}
	knobs.merge(_body_knobs,true)
	enemies.spawn(HeadlessBody,at,face,knobs)
	var head_knobs := {"ring":ground.head_top*5.5}
	head_knobs.merge(_head_knobs,true)
	enemies.spawn(InhalerHead,head,-face,head_knobs)

func stone_body() -> Node3D:
	if enemies == null: return null
	for e in enemies.enemies:
		if is_instance_valid(e) and e.has_method("make_whole"): return e
	return null

func stone_head() -> Node3D:
	if enemies == null: return null
	for e in enemies.enemies:
		if is_instance_valid(e) and e.has_method("mouth"): return e
	return null

## R: him and his head set back as they began; what he broke stays broken.
func place(at: Vector3, face: Vector2) -> void:
	super.place(at,face)
	if enemies != null: enemies.reset()
	if figure != null: figure.visible = true

## The camera shakes with his steps, landings and breaks.
func tick(delta: float) -> void:
	super.tick(delta)
	var b := stone_body()
	if b == null or camera == null: return
	var q := float(b.quake)*clampf(1.0-camera.global_position.distance_to(b.global_position)/60.0,0.0,1.0)
	# The ground's own shake from what falls (round 2).
	if breaks != null: q = maxf(q,float(breaks.quake)*0.6)
	if q > 0.001:
		var t := Time.get_ticks_msec()/1000.0
		camera.position += Vector3(sin(t*61.0),sin(t*53.0+1.0),sin(t*47.0+2.0))*q*0.5

func _hint_text() -> String:
	if not olmec: return super._hint_text()
	return "The Olmec: his stone body walks up the colonnade to his head in the temple, and the piers, lintels, arches and the rose gable in his way go down · his landings' shockwaves topple piers · the rubble stays: climb it · R start (the breaks stay) · F1 numbers"

func _show_hud() -> void:
	super._show_hud()
	if not olmec or not _hud.visible or breaks == null: return
	var lines := PackedStringArray([_hud.text,""])
	var b := stone_body()
	if b != null: lines.append("olmec  %s %.1fs · %s · %.1f m/s · x %.1f y %.1f · leaps %d · shocks %d" % [b.state,b.state_t,"whole" if b.whole else "searching",Vector2(b.vel.x,b.vel.z).length(),b.position.x,b.position.y,b.leaps,b.shocks])
	lines.append("breaks  piers %d (standing %d) · lintels %d · portals %d · temple walls %d · gable %s · pieces live %d (peak %d, cap %d, laid direct %d) · bursts %d · rubble heaps %d · build %.1f ms most · pre-cut %.0f ms" % [breaks.broken,breaks.standing(),breaks.lintels_down,breaks.portals_down,breaks.walls_down,"down" if breaks.gable_down else "standing",breaks.live.size(),breaks.peak_live,Breaks.MAX_BODIES,breaks.landed_direct,breaks.bursts,breaks.settled_groups,breaks.build_ms,breaks.cut_ms])
	_hud.text = "\n".join(lines)

func _voice(sound_name: StringName, at: Vector3) -> void:
	var key := String(sound_name)
	var spec: Variant = InhalerHead.VOICES.get(key,BodySpawner.VOICES.get(key,Breaks.VOICES.get(key)))
	if spec == null: return
	if not _voices.has(key): _voices[key] = EnemyYard._synth(spec)
	var player := AudioStreamPlayer3D.new()
	player.stream = _voices[key]
	player.position = at
	player.unit_size = float(BodySpawner.REACH.get(key,Breaks.REACH.get(key,14.0)))
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

## No station: the isle is its own (the greybox pack's routes are the
## aqueduct isle's). The start is on the low terrace looking west.
func _load_pack() -> void:
	stations = []
	start = Vector3(START_AT.x,START_AT.y,Spine.zc(START_AT.x))
	start_face = Vector2(-1.0,0.0)
	lost = LOST_Y
	_last_stood = start

func isle_name() -> String:
	return motif.isle_name()

func isle_card() -> Dictionary:
	return motif.isle_card()

func isle_top() -> float:
	return motif.top()

## The plants keep off the way, the north shelf and the south bench.
func flora_site() -> KitFlora.Site:
	return motif.flora_site()

func sky_script() -> Script:
	return SpineSky

func life_script() -> Script:
	return SpineLife

func _build_room() -> void:
	_build_art()

func _build_art() -> void:
	art = Node3D.new()
	art.name = "Art"
	add_child(art)
	var began := Time.get_ticks_msec()
	motif.build(art)
	colonnade = motif.colonnade
	temple = motif.temple
	spine = motif.spine
	bridges = motif.bridges
	for land: Array in motif.lands: add_turf(land[0],land[1],land[2])
	if olmec: _build_olmec()
	print("colonnade spine: %d triangles, %d prisms; the ridge built in %d ms, the rest in %d ms" % [triangles(art),int(spine.get_meta("prisms")),motif.spine_ms,Time.get_ticks_msec()-began-motif.spine_ms])
## Room for the parked plane, never in a portal (the slalom flies through
## it), and open sky over it to the walker's keep-off column's top
## (PARKED_TALL): the rows stand wide enough (Spine ROW) for it to fit
## under a lintel, where the column would stand across the lintel he walks.
func _room_for_plane(top: Vector3, heading: float) -> bool:
	if not super(top,heading): return false
	for l: Array in Spine.LINES:
		if l[2] == "portal" and absf(top.x-float(l[0])) < 4.0 and absf(top.z-Spine.zc(top.x)) < Spine.ROW+1.0: return false
	var column := CylinderShape3D.new()
	column.radius = PARKED_ROOM*sqrt(ground_scale.ground_size())+0.2
	column.height = PARKED_TALL-1.0
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = column
	q.collision_mask = plane_mask()
	q.exclude = _turf_rids
	q.transform = Transform3D(Basis.IDENTITY,top+Vector3.UP*(1.0+column.height*0.5))
	return get_world_3d().direct_space_state.intersect_shape(q,1).is_empty()

# --- The lodestone ------------------------------------------------------------------

## The lodestone rests on the last fragment of the tail, at the end of the
## curl (the aqueduct isle's lodestone, here).
const LODE_ON := "frag_5"

func lode_rest_at() -> Vector3:
	var s := Spine.slab(LODE_ON)
	var c := Spine.slab_at(s)
	return Vector3(c.x-0.6,Spine.TOP+float(s[4])+LODE_HOVER+0.25,c.y+0.4)

## On the fragment, beside the stone, he can pick it up.
func can_pick() -> bool:
	if lodestone == null or lode_state != "resting" or flying or not walk_ready: return false
	var feet := motor.feet
	return Vector2(feet.x-lode_rest.x,feet.z-lode_rest.z).length() < PICK_REACH+0.4 and absf(feet.y+LODE_HOVER+0.25-lode_rest.y) < 0.6

func lode_hint() -> String:
	return "A lodestone hums at the end of the tail's curl: follow the fragments round"
