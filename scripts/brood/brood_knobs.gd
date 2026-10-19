extends RefCounted
## The stone brood's numbers (docs/design/brood/spec-brood.md): one table to
## tune. Lengths and paces are in the wanderer's size (scripts/
## world_scale.gd `wanderer`, 1 at the knobs): `s()` multiplies them.

const WorldScale = preload("res://scripts/world_scale.gd")

## A stone guy: his height over the wanderer's drawn height (knee to hip on
## him) and his half-width (m).
const TALL := 0.46
const RADIUS := 0.2

## His paces (m/s): the scurry on the flat (the wanderer walks 2.4 and runs
## 4.8), the climb up a face (well under the wanderer's), the sideways
## crawl on a face (of the climb), and how fast he turns (rad/s).
const SCURRY := 3.0
const CLIMB := 1.1
const CLIMB_SIDE := 0.45
const TURN := 9.0

## The ground: a rise he steps up without climbing, a step down he walks
## off; a drop deeper than STEP_DOWN and no deeper than DROP_MOST he lets
## himself fall down; past that (the isle's rim, a gap between lands) he
## will not go and turns along the edge. Ground is any face whose normal's
## y is over FLOOR; steeper is a face he climbs.
const STEP_UP := 0.3
const STEP_DOWN := 0.45
const DROP_MOST := 7.0
## A deeper drop with a face he can climb down and a floor at its foot no
## deeper than DESCEND_MOST (m): over the lip he goes and climbs down it.
## Under the wake's RIM_VOID, so the isle's rim stays a rim.
const DESCEND_MOST := 18.0
const FLOOR := 0.6

## Turning along an edge he won't go over: each try turns him this much
## (deg), and he keeps the turned way this long (s) before trying straight
## at his goal again.
const DETOUR_TURN := 50.0
const DETOUR_TIME := 0.7

## The mantle over a face's top (s), and the most he climbs one face before
## he lets go (m).
const MANTLE_TIME := 0.5
const CLIMB_MOST := 40.0
## After a top he can't get over with only the void under him: how long he
## crawls sideways along the face (s) before trying the top again.
const TRAVERSE_TIME := 1.2

## Falling: gravity (m/s^2) and the fall under his start that loses him.
const GRAVITY := 22.0
const LOST_UNDER := 80.0

## How near his goal he stops (m, across).
const NEAR := 0.7

## The wake (lifting a treasure wakes the brood): how many come, from the
## isle's rim round it (spots found by marching rays out from the treasure
## in RIM_RAYS ways to where the ground ends over a void at least RIM_VOID
## deep, no farther than RIM_MOST (m); nearest first past WAKE_NEAR), and
## their beat: each waits his turn
## (WAKE_STAGGER s apart, nearest first, plus up to WAKE_JITTER), his
## fingers then head come up over the lip (WAKE_RISE s), he holds there
## looking (WAKE_HOLD s, give or take half), then he climbs over and comes.
const WAKE_COUNT := 40
## Rim spots nearer the treasure than this (m) are used last, so he has a
## breath to run.
const WAKE_NEAR := 6.0
const RIM_RAYS := 48
const RIM_MOST := 60.0
const RIM_STEP := 1.0
const RIM_VOID := 25.0
const WAKE_STAGGER := 0.14
const WAKE_JITTER := 0.25
const WAKE_RISE := 0.7
const WAKE_HOLD := 0.7

## The bag study's brood (scripts/brood/bag_brood.gd): the first piece in
## the loot bag wakes BAG_STUDY_COUNT guys out of the room's burrows, dealt
## round them nearest the bag first, BURROW_STAGGER s apart in each
## burrow (plus up to WAKE_JITTER).
const BAG_STUDY_COUNT := 12
const BURROW_STAGGER := 0.5
## The rip (the bag study): while he wears the bag with any clinging, one
## of them pulls a piece out every RIP_EVERY s (give or take RIP_JITTER of
## it; each clinger past the first cuts the wait RIP_MORE), the piece
## hopping out of the mouth RIP_POP s onto the ground RIP_OUT m (out from the ripper) beside him. A
## ripped piece on the ground calls RIP_CREW of them (the nearest free);
## within HAUL_REACH they take it up and haul it at RIP_PACE to the
## nearest burrow (within HOME_NEAR of its mouth it's taken down). He
## knocks a hauler off as any haul, but only past RIP_HIT_SPEED (m/s; over
## the clingers' shove, so they don't drop it by his being jostled into
## them); under RIP_CREW left they let it down,
## and none lifts it again for RIP_REST s. E by it takes it back.
const RIP_EVERY := 7.0
const RIP_JITTER := 0.3
const RIP_MORE := 0.1
const RIP_OUT := 1.0
const RIP_HIT_SPEED := 2.0
const RIP_POP := 0.4
const RIP_CREW := 2
const RIP_PACE := 0.55
const RIP_REST := 1.5

## Grab and shove: a guy within GRAB_REACH (m, across; and no more than
## GRAB_RISE of his own height above or below the feet) of whoever holds a
## treasure clings on, up to GRAB_SLOTS at once (the rest crowd round him
## CROWD_RING out). Each clinger slows him SLOW_EACH (his walk and run
## times 1 - that per guy, no lower than SLOW_MOST) and shoves him a
## little (SHOVE m/s, every SHOVE_EVERY s, give or take half, sideways
## and back). KNOCK_COUNT on him for KNOCK_HOLD s knocks the treasure
## loose (carry's drop "knock"). No damage. A jump (his rise over SHAKE_UP
## m/s) shakes them all off; shaken, a guy is dazed DAZE s before he grabs
## again.
const GRAB_REACH := 0.85
const GRAB_RISE := 1.6
const GRAB_SLOTS := 8
const CROWD_RING := 1.1
const SLOW_EACH := 0.13
const SLOW_MOST := 0.3
const SHOVE := 1.6
const SHOVE_EVERY := 0.45
const KNOCK_COUNT := 5
const KNOCK_HOLD := 1.0
const SHAKE_UP := 2.0
const DAZE := 1.4
## After he shakes them off, none grabs him for this long (s), so a jump
## clears him even with the whole brood round him.
const GRAB_GRACE := 0.6

## The mob and the haul: a loose treasure (or one he set down off its
## spot) that HAUL_CREW of them (by its weight) reach within HAUL_REACH
## (m, past its edge) is lifted over their heads and hauled toward its home
## spot at HAUL_PACE of their pace (by its weight; heavy, slower than he
## carries it). He runs into a hauler (within
## HAUL_HIT m, faster than HAUL_HIT_SPEED m/s, or coming down on him) and
## knocks him off it, dazed; fewer than HAUL_KEEP left and they let it
## down where it is, and none lifts it again for HAUL_REST s. Or he lifts
## it from them (E, as any resting one).
## Within HOME_NEAR (m, across) of its spot it is set home and the brood
## settles: they stand where they are till it is lifted again.
const HAUL_CREW := {"light":2,"medium":3,"heavy":4}
const HAUL_REACH := 0.9
const HAUL_PACE := {"light":0.5,"medium":0.4,"heavy":0.3}
const HAUL_HIT := 0.6
const HAUL_HIT_SPEED := 1.2
const HAUL_KEEP := 2
const HAUL_REST := 1.5
## The rest walk with a haul this far round it (m).
const ESCORT_RING := 1.8
## A haul that gets no nearer home by HAUL_GAIN (m) in HAUL_STUCK (s) (a
## shelf they can't get down off; they never jump) is set down where it is
## and they settle round it till it's lifted again.
const HAUL_STUCK := 8.0
const HAUL_GAIN := 0.5
const HOME_NEAR := 1.0

## Clingers: once he's in the plane with treasure in its bag, a walking
## guy (not dazed) within LEAP_REACH (m, across; LEAP_RISE of his height
## up or down) of the bag's belly leaps on (LEAP_TIME s, an arc LEAP_ARC m
## high), up to RIDE_SLOTS at once, and hangs on round the belly. Each
## adds RIDER_KG to the bag's load (carry's load path), never past its
## takeoff limit (a full bag ridden makes the plane sluggish, not stuck).
## In the air they come off one by one, each with a chance a second of
## the sum of: a hard bank (past BANK_SHAKE rad: BANK_RATE at the bank's
## top, BANK_TOP), a skim (the belly within SKIM_DOWN m of the ground:
## SKIM_RATE; not in the first SKIM_AFTER s off the ground), a cliff beside (a face within SKIM_SIDE m either side:
## SIDE_RATE) or a narrow gap (faces both sides: GAP_RATE), and a hit
## (the bag hits something: HIT_SHED riders per m/s of the hit, at least
## one). Thrown off they tumble away (TUMBLE rad/s).
## Treasure loaded in the bag wakes BAG_WAKE more from the rim round it.
const BAG_WAKE := 10
const LEAP_REACH := 1.6
const LEAP_RISE := 2.5
const LEAP_TIME := 0.35
const LEAP_ARC := 0.7
const RIDE_SLOTS := 5
const RIDER_KG := 2.5
const BANK_SHAKE := 0.8
const BANK_TOP := 1.2
const BANK_RATE := 1.6
const SKIM_DOWN := 1.2
const SKIM_RATE := 2.0
const SKIM_AFTER := 1.5
const SKIM_SIDE := 4.0
const SIDE_RATE := 2.0
const GAP_RATE := 6.0
const HIT_SHED := 0.5
const TUMBLE := 9.0

## The crowd: walking guys nearer each other than SEP (m, across) lean
## apart, SEP_PUSH strong at touching (of their wish for the goal); a
## crowd standing round a goal spreads out at up to SEP_DRIFT of their
## scurry.
const SEP := 0.5
const SEP_PUSH := 1.4
const SEP_DRIFT := 0.35

## Their stone: grey, rough.
const STONE := Color(0.62,0.6,0.57)
const STONE_DARK := Color(0.2,0.19,0.18)
## Their stone's own glow (of STONE), so they read in the shade.
const GLOW := 0.13

## Every solid he walks and climbs on (the motor's mask: terrain, kit
## pieces, decks); the treasures' layer is left out.
const SOLID_MASK := 1|(1 << 11)

static func s() -> float:
	return WorldScale.wanderer

static func tall() -> float:
	return TALL*WorldScale.wanderer_tall
