extends Node3D
## The breakables' hub (docs/design/roguelike/city-breaks-round1.md): the
## Olmec's `breaker` (scripts/enemies/headless_body.gd) for any number of
## breakable pieces, each its own node in the group BREAKABLE (the city
## kit's: scripts/city_breaks/felled_column.gd, drum_floor.gd), and for the
## colonnade's breaks too (`others`: scripts/kit_isle/colonnade_breaks.gd),
## so one body takes them all. Round 1 and 2's breaks were one monolith for
## one isle; this hands his calls on to the pieces near him.
##
## What the body asks (the colonnade's protocol, and one more):
##   standing_rids()   what still stands: air to his rays (he walks into it)
##   rubble_rids()     what he wades: ground to his feet, not to his bulk
##   met(body)         his bulk this frame
##   wave(body, w)     his landing's shockwave front this frame
##   veer(body, h)     a brute's veer toward a breakable off his way
##   ahead(body), smash(body)   the colonnade's gable punch
##   takes_shock(body, w)   (new) a piece takes the wave's hit on the
##                     wanderer itself (the drum floor); the body's own
##                     shove skipped
## Each piece answers the same names with the hub first (`met(hub, body)`,
## ...); a piece without one is skipped.
## What a piece asks of the hub: `motor()`, `pause(frames, scale)` (the
## hit-stop), `shake(k)` (the ground's quake: the study's camera adds
## `quake`), `sound(name, at)`, `changed(box)` (rubble or a felled piece at
## rest: every body's routes read the box afresh), `knocked(source, kind,
## v)` (a hit on the wanderer, logged).
const BREAKABLE := &"breakable"
const QUAKE_FADE := 1.4

## The scene's enemies (scripts/enemies/enemy_field.gd).
var field: Node = null
## (name, at): the scene's sound.
var sound_hook := Callable()
## Other breakers handed the same calls (a colonnade's breaks).
var others: Array = []
var quake := 0.0
## The hits on the wanderer: [source, kind, v, msec].
var hits: Array = []
## Calls handed out, counted (for checks): met frames, waves.
var waves := 0
var _hitstop := 0

func _init() -> void:
	name = "Breakables"

func pieces() -> Array:
	if not is_inside_tree(): return []
	return get_tree().get_nodes_in_group(BREAKABLE)

func motor() -> Object:
	return field.motor if field != null else null

# --- The body's calls --------------------------------------------------------------------

func standing_rids() -> Array[RID]:
	var out: Array[RID] = []
	for p: Node in pieces(): out.append_array(p.standing_rids())
	for o: Object in others: out.append_array(o.standing_rids())
	return out

func rubble_rids() -> Array[RID]:
	var out: Array[RID] = []
	for p: Node in pieces(): out.append_array(p.rubble_rids())
	for o: Object in others: out.append_array(o.rubble_rids())
	return out

func met(body: Node3D) -> void:
	for p: Node in pieces(): p.met(self,body)
	for o: Object in others: o.met(body)

func wave(body: Node3D, w: Dictionary) -> void:
	waves += 1
	for p: Node in pieces(): p.wave(self,body,w)
	for o: Object in others: o.wave(body,w)

func veer(body: Node3D, heading: float) -> float:
	var h := heading
	for p: Node in pieces():
		if p.has_method("veer"): h = p.veer(self,body,h)
	for o: Object in others: h = o.veer(body,h)
	return h

func ahead(body: Node3D) -> bool:
	for o: Object in others:
		if o.ahead(body): return true
	return false

func smash(body: Node3D) -> void:
	for o: Object in others: o.smash(body)

func takes_shock(body: Node3D, w: Dictionary) -> bool:
	for p: Node in pieces():
		if p.has_method("takes_shock") and p.takes_shock(self,body,w): return true
	return false

# --- The pieces' calls ---------------------------------------------------------------------

func pause(frames: int, scale: float) -> void:
	if _hitstop <= 0 or scale < Engine.time_scale: Engine.time_scale = scale
	_hitstop = maxi(_hitstop,frames)

func shake(k: float) -> void:
	quake = maxf(quake,k)

func sound(sound_name: StringName, at: Vector3) -> void:
	if sound_hook.is_valid(): sound_hook.call(sound_name,at)

func changed(box: AABB) -> void:
	if field == null: return
	for e in field.enemies:
		if is_instance_valid(e) and e.has_method("world_changed"): e.world_changed(box)

func knocked(source: String, kind: String, v: Vector3) -> void:
	hits.append([source,kind,v,Time.get_ticks_msec()])

func _process(delta: float) -> void:
	quake = maxf(0.0,quake-delta*QUAKE_FADE)
	if _hitstop > 0:
		_hitstop -= 1
		if _hitstop == 0: Engine.time_scale = 1.0
	for o: Object in others: quake = maxf(quake,float(o.get("quake")))

func _exit_tree() -> void:
	if _hitstop > 0: Engine.time_scale = 1.0
