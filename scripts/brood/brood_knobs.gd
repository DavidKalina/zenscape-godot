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
const WAKE_COUNT := 12
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
