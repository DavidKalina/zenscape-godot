extends RefCounted
## The motif editor's mechanics (loop world-editor, lane palette): the
## aqueduct isle's foot pieces made placeable on a motif, as traps are.
## Each is a trap (scripts/traps/trap.gd) wrapping the real piece
## (scripts/kit_isle/mechanics/mechanic.gd), so the editor's trap tools
## carry, set down, drag, turn, delete, tune (the knobs panel) and play it,
## the file keeps it in "traps" as {id, at, turn, knobs?}, and
## scripts/kit_isle/motif_authored.gd `live` hands it to the host's TrapField
## like any trap. TrapRegistry (scripts/traps/trap_registry.gd) reads this
## list after its own; the trap yard's lanes (its `keys()`) leave it out.
##
## The keys are saved ids in `motifs/authored/*.json`: keep them stable.

## [key, script, display name], in the palette's order.
const LIST := [
	["air_ring", preload("res://scripts/kit_isle/mechanics/mech_air_ring.gd"), "Air ring"],
	["bob_slab", preload("res://scripts/kit_isle/mechanics/mech_bob_slab.gd"), "Bob slab"],
	["ring_stair_slab", preload("res://scripts/kit_isle/mechanics/mech_ring_stair_slab.gd"), "Ring-stair slab"],
	["swing_rope", preload("res://scripts/kit_isle/mechanics/mech_swing_rope.gd"), "Swing rope"],
	["drift_slab", preload("res://scripts/kit_isle/mechanics/mech_drift_slab.gd"), "Drift slab (ferry)"],
	["kit_cache", preload("res://scripts/kit_isle/mechanics/mech_kit_cache.gd"), "Kit cache"],
]

static func keys() -> PackedStringArray:
	var out := PackedStringArray()
	for row: Array in LIST: out.append(row[0])
	return out

static func has(key: String) -> bool:
	return keys().has(key)
