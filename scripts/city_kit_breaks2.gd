extends RefCounted
## The city kit's breaks, round 2:
## more pieces of the underground Olmec city where his power reshapes the
## routes. Cards maker_corbel, maker_skin, maker_chock and colossus_plug. Part of the
## `city` family; the family's main file
## (scripts/city_kit.gd, another round's) registers them:
##   const CityBreaks2 = preload("res://scripts/city_kit_breaks2.gd")
##   PIECES ... + CityBreaks2.PIECES
##   if id in CityBreaks2.PIECES: return CityBreaks2.piece(id, seed, weathered)
##
##   maker_corbel   a corbel-vaulted gate his size (scripts/city_breaks/
##                  corbel_vault.gd): his landing's shockwave by its cracked
##                  bay (or a slam on its roof) brings that bay in: the
##                  gate stays his over the heap, and the roof, out of
##                  reach before, is the wanderer's by the broken stair.
##   maker_skin     a terrace wall faced in sheets (scripts/city_breaks/
##                  skin_wall.gd): his shockwave or his climb peels it a
##                  column at a time; ride a sheet down, run the earth
##                  slumped behind it; three down are his lane up.
##   maker_chock    a slab on its end at a gap, held by a chock (scripts/
##                  city_breaks/chocked_slab.gd): slam its plate (or his
##                  landing, or his foot on it) and it swings across, a
##                  bridge for both; a trap on whoever is under it.
##   colossus_plug  a keystone plugging a gate in a wall past his climb
##                  (scripts/city_breaks/plug_stone.gd): lure him into it
##                  (his bulk, or two of his landings by it) and run
##                  through the hole; he follows.
##
## Each piece is a Node3D with its front toward +Z (y 0 where it meets its
## neighbours: each file says), its live parts under it, built in the city's
## stone (scripts/city_kit_stone.gd). They join the group BREAKABLE (the
## breakables hub, scripts/kit_isle/breakables.gd, set as each Olmec's
## `breaker`, hands them his calls) and the slam's group. Each keeps the
## card's three states: whole, cracked (a tell), fallen (an authored rest of
## clean walk boxes, ground to both bodies; the hub's `changed` makes every
## body's planner read it). Meta `breaks` on each: {trigger, before, after}.
const PIECES := ["maker_corbel","maker_skin","maker_chock","colossus_plug"]
const NAMES := {"maker_corbel":"Corbel vault","maker_skin":"Facing sheet wall","maker_chock":"Chocked slab","colossus_plug":"Plug-stone"}
const FAMILY := "city"
const SCRIPTS := {
	"maker_corbel":"res://scripts/city_breaks/corbel_vault.gd",
	"maker_skin":"res://scripts/city_breaks/skin_wall.gd",
	"maker_chock":"res://scripts/city_breaks/chocked_slab.gd",
	"colossus_plug":"res://scripts/city_breaks/plug_stone.gd",
}
## The route contract per piece (kit-k4's `breaks`): what triggers it, the
## routes before and after (the generator keeps one to the exit in both).
const BREAKS := {
	"maker_corbel":{"trigger":["shock","slam"],"before":["through (both)"],"after":["through over the heap (both)","up the broken stair to the roof (walker)"]},
	"maker_skin":{"trigger":["shock","body","slam"],"before":["climb the face (Olmec)"],"after":["the slope up and down (walker; Olmec where 3 columns are down)","the scree"]},
	"maker_chock":{"trigger":["slam","shock","body"],"before":[],"after":["across the bridge (both)"]},
	"colossus_plug":{"trigger":["body","shock"],"before":[],"after":["through the gate over the heap (both)"]},
}

## The piece with PIECES id `id`.
static func piece(id: String, seed_value: int, weathered := 0.0) -> Node3D:
	if not SCRIPTS.has(id): return null
	var p: Node3D = load(SCRIPTS[id]).new()
	p.build(seed_value,weathered)
	p.set_meta("kit",FAMILY)
	p.set_meta("breaks",BREAKS[id])
	return p
