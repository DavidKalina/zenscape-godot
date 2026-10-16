extends Node
## The greybox motifs in a generated layer (docs/design/roguelike/greybox-in-
## generator.md; the motifs are scripts/kit_isle/motif_greybox.gd's, listed
## in scripts/kit_isle/greybox/registry.gd, opt-in on `--knob=greybox=`).
##
## Planning (`lay_heads`, from LayerEnemies `lay` once the generator's heads
## are laid): each greybox isle's own inhaler heads join `plan.heads` at
## their authored spots and routes (the study's frame moved by the isle's
## offset), with the cliffs their headless bodies may come up (LayerBodies
## `cliffs`), so the stage spawns, voices and steps them as the generator's
## own and the bodies come for them. The generator's heads and the Plinth
## Ram keep off a greybox isle (its chains are authored).
##
## On the stage (`dress`, a child of scripts/roguelike/layer_stage.gd, which
## steps it round the motor): each greybox isle's other live bits (`live`:
## ropes, traps, other enemies) in a host of its own (`Isle`, the world
## frame for its motif), and the HUD card: GREYBOX, its name, epithet and
## brief when the walker comes onto it (G hides or shows it again).
const LayerPlan = preload("res://scripts/roguelike/layer_plan.gd")
const LayerBodies = preload("res://scripts/roguelike/layer_bodies.gd")
const Registry = preload("res://scripts/kit_isle/greybox/registry.gd")
const FootPieces = preload("res://scripts/interactables/foot_pieces.gd")
const TrapField = preload("res://scripts/traps/trap_field.gd")

## The generator's own heads keep this far (m, flat) from a greybox isle's
## (LayerEnemies APART).
const APART := 60.0
## The card: shown whole this long (s) on arrival, then one line while on
## the isle; "on" is within NEAR m of its rect (flat) and RISE of its span.
const SHOW_FULL := 15.0
const NEAR := 8.0
const RISE := 12.0

# --- Planning -----------------------------------------------------------------------

## The greybox isles' indices in `plan`.
static func isles_of(plan: Dictionary) -> Array:
	var out: Array = []
	for i in range((plan.isles as Array).size()):
		# A motif built in the editor on a pool base (motif_based.gd) keeps
		# the base's id, so it is asked.
		var m: Variant = plan.isles[i].get("motif")
		if Registry.has(str(plan.isles[i].id)) or (m is Object and (m as Object).has_method("based_on")): out.append(i)
	return out

## Each greybox isle's heads into `plan.heads` (`n` the pilot's numbers,
## LayerEnemies `numbers`); the generator's heads and ram off them.
static func lay_heads(plan: Dictionary, n: Dictionary) -> void:
	var gb := isles_of(plan)
	if gb.is_empty(): return
	if not plan.has("heads"): plan.heads = []
	var ours: Array = []
	var bodies := int((plan.knobs as Dictionary).get("bodies",1)) != 0
	for i: int in gb:
		var isle: Dictionary = plan.isles[i]
		var off: Vector3 = isle.offset
		for h: Dictionary in isle.motif.heads():
			var knobs: Dictionary = (h.get("knobs",{}) as Dictionary).duplicate(true)
			var route: Array = []
			for p: Vector3 in knobs.get("route",[]): route.append(p+off)
			knobs.erase("route")
			var face: Vector2 = h.face
			var head := {"isle":i,"at":(h.at as Vector3)+off,"face":Vector3(face.x,0.0,face.y),"route":route,"void":0.0,
				"on":"%s (%s)" % [isle.id,str(h.get("name","head"))],"knobs":knobs,"greybox":true,"cliffs":[]}
			if route.is_empty(): head.route = [head.at]
			ours.append(head)
	var kept: Array = []
	for h: Dictionary in plan.heads:
		if gb.has(int(h.isle)): continue
		var near := false
		for o: Dictionary in ours:
			if Vector2((h.at as Vector3).x-(o.at as Vector3).x,(h.at as Vector3).z-(o.at as Vector3).z).length() < APART: near = true
		if not near: kept.append(h)
	plan.heads = kept
	for h: Dictionary in ours:
		if bodies: h.cliffs = LayerBodies.cliffs(plan,h,n)
		plan.heads.append(h)
	if not (plan.get("ram",{}) as Dictionary).is_empty() and gb.has(int(plan.ram.isle)): plan.ram = {}

## A line for the log: each greybox isle, where it stands, its rims' use.
static func card(plan: Dictionary) -> String:
	var words := PackedStringArray()
	for i: int in isles_of(plan):
		var isle: Dictionary = plan.isles[i]
		var rims := PackedStringArray()
		for e: Dictionary in plan.edges:
			if int(e.from[0]) == i: rims.append("out %s (%s)" % [str(e.from[1]),str(e.kind)])
			if int(e.to[0]) == i: rims.append("in %s (%s)" % [str(e.to[1]),str(e.kind)])
		if not (plan.exit as Dictionary).is_empty() and int(plan.exit.isle) == i: rims.append("gate %s" % str(plan.exit.rim))
		words.append("%d %s (%s, hood %d) at %s: %s" % [i,str(isle.id),str(isle.role),int(isle.get("hood",0)),str((isle.offset as Vector3).round()),", ".join(rims)])
	return "Greybox: "+("; ".join(words) if not words.is_empty() else "none")

# --- On the stage -------------------------------------------------------------------

## One greybox isle's live bits, in the world: the host its motif's `live`
## makes them with.
class Isle extends Node3D:
	var stage: Node3D
	var motif: RefCounted
	var offset := Vector3.ZERO
	var index := -1
	## Its rect (world x, z) and span (world y).
	var rect := Rect2()
	var span := Vector2.ZERO
	var pieces: Node3D = null
	var traps: Node3D = null

	## A point of its frame in the world's.
	func w(p: Vector3) -> Vector3:
		return p+offset

	## A rect (x, z) of its frame in the world's.
	func wr(r: Rect2) -> Rect2:
		return Rect2(r.position+Vector2(offset.x,offset.z),r.size)

	## A swing rope hung at `anchor` (world).
	func rope(anchor: Vector3, length: float) -> Node3D:
		if pieces == null:
			pieces = FootPieces.new()
			pieces.study = stage.study
			pieces.motor = stage.study.motor
			add_child(pieces)
		return pieces.rope(anchor,length)

	## A trap (scripts/traps/trap.gd, in the world), stepped round the motor.
	func trap(node: Node3D) -> Node3D:
		if traps == null:
			traps = TrapField.new()
			traps.study = stage.study
			traps.motor = stage.study.motor
			add_child(traps)
		return traps.add(node)

	## An enemy into the stage's EnemyField (`at` world, `face` x z).
	func enemy(script: GDScript, at: Vector3, face: Vector2, knobs := {}) -> Node3D:
		return stage.enemies.spawn(script,at,face,knobs)

	## The stage's cannons (scripts/cannon/cannon_field.gd).
	func cannons() -> Node3D:
		return stage.cannons

	func before(delta: float) -> void:
		if pieces != null: pieces.before(delta)
		if traps != null: traps.before(delta)

	func after(delta: float, events: Dictionary) -> void:
		if pieces != null: pieces.after(delta,events)
		if traps != null: traps.after(delta,events)

	func pose(figure: Node3D) -> void:
		if pieces != null: pieces.pose(figure)

	func reset() -> void:
		if traps != null: traps.reset()

	func air(p: Vector3) -> Dictionary:
		return traps._air(p) if traps != null else {}

var stage: Node3D
var study: Node3D
var hosts: Array = []
var _hud: CanvasLayer
var _label: Label
## The isle the walker is on (its host), how long, and whether the card is
## asked hidden (G).
var on: Node3D = null
var on_for := 0.0
var hidden := false
## Arrivals, for checks: [isle id, time (ms)].
var arrivals: Array = []

## The plan's greybox isles made live on `stage`; null where there are none.
static func dress(owner_stage: Node3D, plan: Dictionary) -> Node:
	var gb := isles_of(plan)
	if gb.is_empty(): return null
	var node := new()
	node.name = "LayerGreybox"
	owner_stage.add_child(node)
	node.build(owner_stage,plan,gb)
	return node

func build(owner_stage: Node3D, plan: Dictionary, gb: Array) -> void:
	stage = owner_stage
	study = stage.study
	for i: int in gb:
		var isle: Dictionary = plan.isles[i]
		var host := Isle.new()
		host.name = "Greybox_%s_%d" % [str(isle.motif.slug()),i]
		host.stage = stage
		host.motif = isle.motif
		host.offset = isle.offset
		host.index = i
		host.rect = LayerPlan._rect(isle)
		host.span = LayerPlan._span(isle)
		add_child(host)
		isle.motif.live(host)
		hosts.append(host)
		print("greybox: %s live on isle %d at %s" % [str(isle.id),i,str((isle.offset as Vector3).round())])
	# The traps' air (a vent's thermal) into the motor's, over what was.
	var me := self
	study.motor.push_air(self,func(p: Vector3,here: Dictionary) -> Dictionary:
		var out := here
		var copied := false
		for h: Node3D in me.hosts:
			var extra: Dictionary = h.air(p)
			if extra.is_empty(): continue
			if not copied:
				out = here.duplicate()
				copied = true
			for key: Variant in extra: out[key] = (out[key]+extra[key]) if out.has(key) else extra[key]
		return out)
	_build_hud()

func _exit_tree() -> void:
	if study != null: study.motor.pop_air(self)

func before(delta: float) -> void:
	for h: Node3D in hosts: h.before(delta)

func after(delta: float, events: Dictionary) -> void:
	for h: Node3D in hosts: h.after(delta,events)

func pose(figure: Node3D) -> void:
	for h: Node3D in hosts: h.pose(figure)

func reset() -> void:
	for h: Node3D in hosts: h.reset()

## The camera placed: the card for where the walker is.
func frame(_camera: Camera3D, delta: float) -> void:
	_update_card(delta)

# --- The card -----------------------------------------------------------------------

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "GreyboxCard"
	_hud.layer = 5
	add_child(_hud)
	_label = Label.new()
	_label.add_theme_font_size_override("font_size",16)
	_label.add_theme_color_override("font_color",Color("fbf6ea"))
	_label.add_theme_color_override("font_shadow_color",Color(0,0,0,0.8))
	_label.add_theme_constant_override("shadow_offset_x",1)
	_label.add_theme_constant_override("shadow_offset_y",1)
	_label.anchor_top = 1.0
	_label.anchor_bottom = 1.0
	_label.offset_left = 16.0
	_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_label.offset_bottom = -16.0
	_label.visible = false
	_hud.add_child(_label)

## The isle host the walker at `feet` is on, or null.
func host_at(feet: Vector3) -> Node3D:
	for h: Node3D in hosts:
		if (h.rect as Rect2).grow(NEAR).has_point(Vector2(feet.x,feet.z)) and feet.y > float(h.span.x)-RISE and feet.y < float(h.span.y)+RISE: return h
	return null

func _update_card(delta: float) -> void:
	if study == null or study.motor == null or _label == null: return
	var now := host_at(study.motor.feet)
	if now != on:
		on = now
		on_for = 0.0
		if on != null:
			arrivals.append([str(on.motif.id()),Time.get_ticks_msec()])
			print("greybox: arrived on %s (isle %d)" % [str(on.motif.isle_name()),int(on.index)])
	else: on_for += delta
	if on == null or hidden:
		_label.visible = false
		return
	var m: RefCounted = on.motif
	_label.visible = true
	if on_for < SHOW_FULL:
		_label.text = "GREYBOX · %s\n%s\n%s\n(G hides)" % [str(m.isle_name()),str(m.epithet()),str(m.brief())]
		_label.modulate.a = clampf((SHOW_FULL-on_for)/1.5,0.35,1.0) if on_for > SHOW_FULL-1.5 else 1.0
	else:
		_label.text = "GREYBOX · %s  (G: how to play)" % str(m.isle_name())
		_label.modulate.a = 0.8

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event as InputEventKey).keycode == KEY_G and on != null:
		# Shown as a line: G shows it whole again; whole: G hides it.
		if not hidden and on_for >= SHOW_FULL: on_for = 0.0
		else: hidden = not hidden
