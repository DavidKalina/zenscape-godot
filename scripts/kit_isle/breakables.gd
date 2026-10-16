extends Node3D
## The breakables' hub: the
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
## v)` (a hit on the wanderer, logged), `live_count()` (pieces falling now,
## across the hub, against the shared cap: scripts/kit_isle/break_pieces.gd).
##
## Who may break things (spec: docs/design/kit-breaks/spec-kit-breaks.md):
## named breakers, each on or off with a strength. The Olmec's calls above
## all go through `olmec` (off, he breaks nothing; a piece may still be in
## his way); anything else breaks through `hit(at, radius, strength,
## source)`, which a source that is off does nothing with. Launch flag
## `--breakers=olmec,slam` (exactly those on) or `--breakers=+plane,-olmec`
## (changes). A piece in the group answers `hit` as `take_hit(hub, at,
## radius, strength, source)`; a breakable in `others` as `hit(at, ...)`.
## The city kit's pieces (scripts/city_breaks/) answer `take_hit` with their
## own choreography: the slam's as their slam, any other as his landing's
## shockwave of that reach and power. The slam reaches breakables only
## through here (scripts/slam.gd `blast`), so it breaks nothing when
## `slam` is off; the drum court's hop (no break) still hears it directly.
const BREAKABLE := &"breakable"
## Every hub's group: the slam (scripts/slam.gd `blast`) hands each hub its
## hit as `hit(at, radius, strength, &"slam")`.
const HUBS := &"breakables_hub"
const QUAKE_FADE := 1.4
const LaunchArgs = preload("res://scripts/launch_args.gd")
## The breakers as they start: on, and their hits' strength (1 the Olmec's;
## a piece's toughness is measured against it).
const BREAKERS := {
	&"olmec":{"on":true,"strength":1.0},
	&"plane":{"on":false,"strength":0.6},
	&"dragon":{"on":false,"strength":1.2},
	&"slam":{"on":true,"strength":0.5},
}

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
## Hits handed on through `hit` (for checks): [source, at, radius, strength, broke].
var hit_log: Array = []
## The breakers now: {name: {on, strength}}.
var breakers: Dictionary = BREAKERS.duplicate(true)
var _hitstop := 0

func _init() -> void:
	name = "Breakables"
	add_to_group(HUBS)
	for arg in LaunchArgs.user_args():
		if arg.begins_with("--breakers="): set_breakers(arg.get_slice("=",1))

# --- Who breaks things ----------------------------------------------------------------------

## True if `source` is a breaker and on.
func allows(source: StringName) -> bool:
	return bool((breakers.get(source,{}) as Dictionary).get("on",false))

## `source` on or off; its strength too, when `strength` >= 0 (a new name
## is a new breaker).
func set_breaker(source: StringName, on: bool, strength := -1.0) -> void:
	var b: Dictionary = breakers.get(source,{"on":false,"strength":1.0})
	b.on = on
	if strength >= 0.0: b.strength = strength
	breakers[source] = b

## "olmec,slam": exactly those on; "+plane,-olmec": those changed.
func set_breakers(spec: String) -> void:
	var names := spec.split(",",false)
	var exact := true
	for n: String in names:
		if n.begins_with("+") or n.begins_with("-"): exact = false
	if exact:
		for k: StringName in breakers: breakers[k].on = false
	for n: String in names:
		var on := not n.begins_with("-")
		set_breaker(StringName(n.trim_prefix("+").trim_prefix("-")),on)

func strength_of(source: StringName) -> float:
	return float((breakers.get(source,{}) as Dictionary).get("strength",0.0))

## A break from anything but the Olmec's own bulk: every piece and breakable
## in reach of `at` (`radius` m) takes it at `strength` (< 0: the
## breaker's own), if `source` is on. How many things broke.
func hit(at: Vector3, radius: float, strength := -1.0, source: StringName = &"olmec") -> int:
	if not allows(source): return 0
	var s := strength if strength >= 0.0 else strength_of(source)
	var n := 0
	for p: Node in pieces():
		# (A piece's `hit` is a hit on the wanderer: stone_break.gd.)
		if p.has_method("take_hit"): n += int(p.take_hit(self,at,radius,s,source))
	for o: Object in others:
		if o.has_method("hit"): n += int(o.hit(at,radius,s,source))
	hit_log.append([source,at,radius,s,n])
	return n

## Pieces falling now, across the hub (the shared cap).
func live_count() -> int:
	var n := 0
	for p: Node in pieces():
		var l: Variant = p.get("live")
		if l is Array: n += (l as Array).size()
	for o: Object in others:
		var l: Variant = o.get("live")
		if l is Array: n += (l as Array).size()
	return n

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
	if not allows(&"olmec"): return
	for p: Node in pieces(): p.met(self,body)
	for o: Object in others: o.met(body)

func wave(body: Node3D, w: Dictionary) -> void:
	if not allows(&"olmec"): return
	waves += 1
	for p: Node in pieces(): p.wave(self,body,w)
	for o: Object in others: o.wave(body,w)

func veer(body: Node3D, heading: float) -> float:
	if not allows(&"olmec"): return heading
	var h := heading
	for p: Node in pieces():
		if p.has_method("veer"): h = p.veer(self,body,h)
	for o: Object in others: h = o.veer(body,h)
	return h

func ahead(body: Node3D) -> bool:
	if not allows(&"olmec"): return false
	for o: Object in others:
		if o.ahead(body): return true
	return false

func smash(body: Node3D) -> void:
	if not allows(&"olmec"): return
	for o: Object in others: o.smash(body)

func takes_shock(body: Node3D, w: Dictionary) -> bool:
	if not allows(&"olmec"): return false
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
	# Heard across the layer.
	var loud := float(BREAK_HEARD.get(sound_name,0.0))
	if loud > 0.0 and is_inside_tree(): NoiseBus.make(self,at,loud,&"break")

## How far the pieces' sounds carry (m) on the NoiseBus (scripts/noise/noise_bus.gd).
const BREAK_HEARD := {&"ruin_crack":20.0,&"ruin_fall":28.0,&"ruin_boom":40.0,&"ruin_thud":18.0,
	&"drum_ring":30.0,&"drum_thud":14.0}

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
