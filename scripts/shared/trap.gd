extends Node3D
## The trap contract: the base every greybox trap
## extends, the way a foot piece extends scripts/interactables/
## foot_slab.gd. A trap is a section of route with a way in and a way out
## that moves the pilot (shoves, drops, washes him); the harm is where he
## ends up. It stands in the world's frame; its own frame has the way in
## at the origin, the route running along -z, so a generator places it by
## setting `transform`.
##
## - `knobs`: every timing, force and size, in one dictionary
##   (`defaults`), so a tier randomizes or a resize follows by changing
##   values here. `configure` merges overrides before the trap is added.
## - `cost`: danger 1 to 5 (`danger()` adds 1 over a drop to the void,
##   `under` = "void"; "layer" is the softer fail one layer down).
## - The tell: `tell_sight(amount)` (0 to 1, how loud it looks; a colour
##   change in greybox, override to dress it) and `tell_sound(kind, at)`
##   (a placeholder: it records in `heard` and emits `sounded`, which a
##   later audio hook connects to). Authored in the module, never random.
## - The way in and out: `entry()` and `exit()` (Transform3D in the world,
##   facing along the route), `length()` of the route, `footprint()` (its
##   local x z rect, for the yard's decks), and `verbs` (what it asked of
##   the pilot on foot).
## - Stepping: a field calls `before` and `after` (the step done, `events`)
##   every frame. `air_at(p)` answers for wind ({wind, thermal} at a
##   point). `reset` puts it back. The pilot on foot the traps moved, and
##   the trap field that stepped him, are gone from the flight game, whole
##   at the tag archive/before-the-cut.
##
## A trap overrides `defaults`, `build` (once in the tree), `before`,
## `after`, `reset`, and the tell; the rest is here.

## Heard a trap's sound: `kind` (a name), `at` (world).
signal sounded(kind: StringName, at: Vector3)

const TELL := Color(0.95,0.55,0.18)

## The trap's name (the yard's `--trap=` key) and its danger, 1 to 5.
var trap_name := "trap"
var cost := 1
## What is under it: "void" (death-ish) or "layer" (a lower isle: soft).
var under := "layer"
## The verbs it asks for (the section grammar's: "run", "jump", ...).
var verbs := PackedStringArray()
var knobs: Dictionary = {}
## The sounds it has made, newest last: [kind, at].
var heard: Array = []

func _init() -> void:
	knobs = defaults()

## The knobs and their defaults; a trap overrides.
func defaults() -> Dictionary:
	return {}

## Overrides merged over the defaults (before the trap is added).
func configure(over: Dictionary) -> Node3D:
	knobs.merge(over,true)
	return self

func knob(key: String) -> Variant:
	return knobs[key]

## 1 to 5 (an extra point over a drop to the void).
func danger() -> int:
	return clampi(cost+(1 if under == "void" else 0),1,5)

func _ready() -> void:
	build()

## Lays its geometry (once in the tree).
func build() -> void:
	pass

## Metres of route along -z from the way in to the way out.
func length() -> float:
	return 0.0

## The route's local rect (x, z), for the yard's decks and floor.
func footprint() -> Rect2:
	return Rect2(-1.0,-length(),2.0,length())

## The way in and out in the world, facing along the route (-z local).
func entry() -> Transform3D:
	return global_transform

func exit() -> Transform3D:
	return global_transform*Transform3D(Basis.IDENTITY,Vector3(0.0,0.0,-length()))

## Ahead of the step.
func before(_delta: float) -> void:
	pass

## After it.
func after(_delta: float, _events: Dictionary) -> void:
	pass

## The wind at `p` (world): {"wind": Vector3, "thermal": float}, or {}.
func air_at(_p: Vector3) -> Dictionary:
	return {}

## Back as built.
func reset() -> void:
	heard.clear()

## The sight tell: 0 quiet, 1 as loud as it gets. Greybox: override to
## tint what it draws.
func tell_sight(_amount: float) -> void:
	pass

## The sound tell (a placeholder: noted and signalled).
func tell_sound(kind: StringName, at: Vector3) -> void:
	heard.append([kind,at])
	sounded.emit(kind,at)

## A plain greybox material of `colour`, its own to change.
static func paint(colour: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = 1.0
	return m
