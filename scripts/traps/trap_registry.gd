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

## The keys, in order.
static func keys() -> PackedStringArray:
	var out := PackedStringArray()
	for row: Array in LIST: out.append(row[0])
	return out

static func has(key: String) -> bool:
	return keys().has(key)

## The trap's script, or null for an unknown key.
static func script_of(key: String) -> GDScript:
	for row: Array in LIST:
		if row[0] == key: return row[1]
	return null

## Its display name (the key itself for an unknown one).
static func display_name(key: String) -> String:
	for row: Array in LIST:
		if row[0] == key: return row[2]
	return key

## A new trap of that key with `knobs` merged over its defaults, or null.
static func make(key: String, knobs: Dictionary = {}) -> Node3D:
	var script := script_of(key)
	if script == null: return null
	var trap: Node3D = script.new()
	if not knobs.is_empty(): trap.configure(knobs)
	return trap
