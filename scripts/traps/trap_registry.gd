extends RefCounted
## The one trap list: key -> script and display name, read by the trap
## yard (studies/trap_yard.gd, one lane per entry in this order), the
## motif editor's palette and saves, and scripts/kit_isle/motif_authored.gd.
## The keys are saved ids in `motifs/authored/*.json` (`"traps":[{id,..}]`):
## keep them stable. To add a trap: write it to scripts/traps/trap.gd's
## contract, then add one line here.

## In the yard's lane order: [key, script, display name].
const LIST := [
	["voussoirs", preload("res://scripts/traps/trap_voussoirs.gd"), "Voussoirs"],
	["seesaw", preload("res://scripts/traps/trap_seesaw.gd"), "Seesaw"],
	["seesaw_slam", preload("res://scripts/traps/trap_seesaw_slam.gd"), "Seesaw slam"],
	["seesaw_drop", preload("res://scripts/traps/trap_seesaw_drop.gd"), "Seesaw drop"],
	["seesaw_dropper", preload("res://scripts/traps/trap_seesaw_dropper.gd"), "Seesaw dropper"],
	["wind", preload("res://scripts/traps/trap_wind.gd"), "Wind"],
	["wind_blaster", preload("res://scripts/traps/trap_wind_blaster.gd"), "Wind blaster"],
	["sluice", preload("res://scripts/traps/trap_sluice.gd"), "Sluice"],
	["logs", preload("res://scripts/traps/trap_logs.gd"), "Logs"],
	["flip", preload("res://scripts/traps/trap_flip.gd"), "Flip"],
	["tumble", preload("res://scripts/traps/trap_tumble.gd"), "Tumble"],
	["ray", preload("res://scripts/traps/trap_ray.gd"), "Ray"],
	["tumble_run", preload("res://scripts/traps/trap_tumble_run.gd"), "Tumble run"],
]
## The motif mechanics (air rings, slabs, ropes, caches: scripts/kit_isle/
## motif_mechanics.gd), placed, saved and built as traps; not trap yard
## lanes (`keys()` leaves them out; `all_keys()` has them).
const Mechanics = preload("res://scripts/kit_isle/motif_mechanics.gd")

static func _rows() -> Array:
	return LIST+Mechanics.LIST

## The keys, in order.
static func keys() -> PackedStringArray:
	var out := PackedStringArray()
	for row: Array in LIST: out.append(row[0])
	return out

## The trap keys, then the mechanics'.
static func all_keys() -> PackedStringArray:
	var out := keys()
	out.append_array(Mechanics.keys())
	return out

static func has(key: String) -> bool:
	return keys().has(key) or Mechanics.has(key)

## The trap's script, or null for an unknown key.
static func script_of(key: String) -> GDScript:
	for row: Array in _rows():
		if row[0] == key: return row[1]
	return null

## Its display name (the key itself for an unknown one).
static func display_name(key: String) -> String:
	for row: Array in _rows():
		if row[0] == key: return row[2]
	return key

## A new trap of that key with `knobs` merged over its defaults, or null.
static func make(key: String, knobs: Dictionary = {}) -> Node3D:
	var script := script_of(key)
	if script == null: return null
	var trap: Node3D = script.new()
	if not knobs.is_empty(): trap.configure(knobs)
	return trap

## The knobs a new trap of that key starts with (its defaults(), plus any a
## subclass's _init merges over them, as wind_blaster's mode), from a
## throwaway instance, freed; {} for an unknown key.
static func defaults_of(key: String) -> Dictionary:
	var script := script_of(key)
	if script == null: return {}
	var trap: Node = script.new()
	var out: Dictionary = (trap.knobs as Dictionary).duplicate(true)
	trap.free()
	return out

## `knobs` read back from JSON: each value brought to its default's type
## (JSON gives every number as a float); keys the trap no longer has are
## kept as read (a saved recipe is never trimmed by a load).
static func typed_knobs(key: String, knobs: Dictionary) -> Dictionary:
	var base := defaults_of(key)
	var out := {}
	for k: Variant in knobs:
		var v: Variant = knobs[k]
		var d: Variant = base.get(k)
		if d is int and (v is float or v is int): v = int(round(float(v)))
		elif d is float and (v is int or v is float): v = float(v)
		elif d is bool and (v is float or v is int): v = float(v) != 0.0
		out[str(k)] = v
	return out

## Only the knobs that differ from the trap's defaults (what a save keeps).
static func changed_knobs(key: String, knobs: Dictionary) -> Dictionary:
	var base := defaults_of(key)
	var out := {}
	for k: Variant in knobs:
		var v: Variant = knobs[k]
		if base.has(k):
			var d: Variant = base[k]
			if (d is float or d is int) and (v is float or v is int):
				if is_equal_approx(float(d),float(v)): continue
			elif typeof(d) == typeof(v) and d == v: continue
		out[str(k)] = v
	return out
