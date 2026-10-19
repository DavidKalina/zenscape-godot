extends RefCounted
## The wreck cluster's numbers and land (studies/wreck_cluster.gd), rebuilt
## round the colonnade spine (docs/design/wreck-cluster/spec-wreck-colonnade.md).
##
##   spine    the colonnade spine at the centre, built by its own motif
##            (scripts/kit_isle/motif_colonnade_spine.gd at its authored
##            seed, studies/colonnade_spine_isle_art.gd's numbers), standing
##            where its own study stands it: the ridge along x 14..150, the
##            temple's podium at its west head, the tail curling south-east
##   strip    a long narrow islet under the spine's south flank, the plane
##            parked at its east end facing west down a clear run; a lobe
##            off its north edge carries the footbridge up onto the spine's
##            south bench
##
## Every gap and rise is sized from the walker (RuinKit GRAB_TOP 1.875,
## CHAIN_TOP 2.575; `tools/kit_piece.py numbers`).
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Spine = preload("res://studies/colonnade_spine_isle_art.gd")
const Tower = preload("res://scripts/ruin_kit_tower.gd")

## The spine's base turf (world y): its TOP.
const TOP := Spine.TOP
## The strip's turf: a metre over the spine's TOP, so the footbridge up to
## the bench (y about 32.6) climbs gently.
const STRIP_TOP := TOP+1.0
## The take-off strip: a clear run along z STRIP_Z from the plane west to
## the islet's west rim (about 90 m), STRIP_HALF either side kept clear.
const STRIP_Z := 16.0
const STRIP_HALF := 5.5
## The parked plane: its middle near the strip's east end, facing west
## (heading PI/2: forward is (-sin h, 0, -cos h) = -x).
const PLANE_AT := Vector2(113.0,STRIP_Z)
const PLANE_HEADING := PI*0.5
## The footbridge from the strip's lobe up to the south bench's lip.
static func bridge_ends() -> Array:
	return [Vector3(110.0,STRIP_TOP,4.6),Vector3(110.0,Spine.ground(110.0,-2.6),-2.6)]

# --- Outlines ---------------------------------------------------------------------

## The strip islet (x, z): about 100 m west to east, 13 wide, its lobe at
## x 104..118 reaching north under the bench.
static func strip_outline() -> Array:
	return [Vector2(20.0,15.0),Vector2(23.0,10.6),Vector2(34.0,9.6),Vector2(60.0,9.9),Vector2(86.0,9.6),
		Vector2(100.0,9.0),Vector2(104.0,5.4),Vector2(109.0,3.6),Vector2(115.0,3.8),Vector2(119.5,7.0),
		Vector2(122.0,13.0),Vector2(121.0,20.0),Vector2(113.0,23.0),Vector2(90.0,23.4),Vector2(60.0,23.0),
		Vector2(36.0,22.6),Vector2(25.0,20.6)]

## The lands besides the spine: [name, outline, ground, depth (its keel
## under its rim), seed, cliffs box (none: Rect2()), its rim's height].
static func lands() -> Array:
	return [
		["strip",strip_outline(),func(_x: float, _z: float) -> float: return STRIP_TOP,16.0,405,Rect2(),STRIP_TOP],
	]

## Land `spec` (a row of `lands`) built: a KitLand island, its sides collided.
static func build_land(spec: Array) -> Node3D:
	var cliffs: Rect2 = spec[5]
	var d := {"outline":spec[1],"seed":int(spec[4]),"ground":spec[2],"top":float(spec[6]),
		"depth":float(spec[3]),"hang":true,"resample":[60.0,128,48],"tone":KitLook.turf(int(spec[4])),"cell":2.0,
		"collide_sides":true,"name":"wreck_cluster/"+str(spec[0])}
	if cliffs.size != Vector2.ZERO: d["cliffs"] = cliffs
	var node := KitLand.island(d)
	node.name = "Land_"+str(spec[0]).capitalize()
	return node

# --- What stands --------------------------------------------------------------------

## The kit pieces: [layout name, kit piece, seed, weathered, world foot,
## yaw (deg)], each colliding as the kit built it. (None yet: the tower is
## `tower` below; the slide and the islets come in later steps.)
static func pieces() -> Array:
	return []

# --- The tower --------------------------------------------------------------------

## The tower stands on the low pad at the spine's east end (turf y about
## 31.2-31.7, open sky north and east), its door facing south toward the
## bench's east end. The climb, bottom to top:
##   stairs   a kit flight north from the pad to a landing STAIRS_RISE up
##   ledge    the plinth's lip PLINTH_H-STAIRS_RISE (1.56) over the landing:
##            under GRAB_TOP, a jump and a grab
##   kicks    in at the door, up the shell's chimney wall to wall
##            (scripts/ruin_kit_tower.gd) to the kick walls' heads, SHELL_H
##            over the plinth
##   top      the east kick wall's head, a lookout beam jutting off it east
##            over the sky (the coast down's start) and a part spot by it
## The tower's middle (x, z) and the turf its stairs stand on.
const TOWER_AT := Vector2(144.5,-25.0)
const TOWER_FOOT := 31.7
## The plinth's height over the turf, the kick walls' height over the
## plinth, the shell's wear (a little: breaches to stop in, the shaft whole).
const PLINTH_H := 3.8
const SHELL_H := 28.0
const SHELL_WEAR := 0.3
## The stair flight's rise to its landing (RuinKit STEPS of RISER) and its
## run, foot to the landing's far edge.
const STAIRS_RISE := RuinKit.STEPS*RuinKit.RISER
const STAIRS_RUN := (RuinKit.STEPS-1)*RuinKit.TREAD+RuinKit.LANDING
## The plinth's apron round the shell: at its sides and back, and before
## the door (room to land the grab and walk in).
const APRON := 1.6
const APRON_FRONT := 2.2
## The lookout beam off the east wall's head: how far it juts past the
## wall's outer face, its width and depth, how far its top stands over the
## head.
const LOOKOUT_OUT := 3.4
const LOOKOUT := Vector2(1.1,0.5)
const LOOKOUT_STEP := 0.25

## The plinth's top (world y), the kick walls' heads (world y).
static func plinth_top() -> float:
	return TOWER_FOOT+PLINTH_H
static func tower_rim() -> float:
	return plinth_top()+SHELL_H

## The plinth's extents (x, z: min and max corners, world).
static func plinth_rect() -> Rect2:
	var h := Tower.half_extents()
	var a := Vector2(TOWER_AT.x-h.x-APRON,TOWER_AT.y-h.y-APRON)
	var e := Vector2(TOWER_AT.x+h.x+APRON,TOWER_AT.y+h.y+APRON_FRONT)
	return Rect2(a,e-a)

## The stair flight's middle (the kit's origin: the run centred on it),
## climbing north (-z) to the plinth's south face.
static func stairs_at() -> Vector3:
	return Vector3(TOWER_AT.x,TOWER_FOOT,plinth_rect().end.y+STAIRS_RUN*0.5)

## The landing's top middle and the door's threshold (world): the route's
## way points.
static func landing_point() -> Vector3:
	return Vector3(TOWER_AT.x,TOWER_FOOT+STAIRS_RISE,plinth_rect().end.y+0.5)
static func door_point() -> Vector3:
	return Vector3(TOWER_AT.x,plinth_top(),TOWER_AT.y+Tower.half_extents().y+0.6)

## The east kick wall's head (the middle of its thickness) at `dz` along it.
static func east_head(dz := 0.0) -> Vector3:
	return Vector3(TOWER_AT.x+Tower.half_extents().x-Tower.WALL*0.5,tower_rim(),TOWER_AT.y+dz)

## The lookout's tip (its top's middle at the far end, world).
static func lookout_tip() -> Vector3:
	return Vector3(TOWER_AT.x+Tower.half_extents().x+LOOKOUT_OUT,tower_rim()+LOOKOUT_STEP,TOWER_AT.y)

## The tower's parts: [layout name, node, world foot, yaw (deg)].
static func tower() -> Array:
	var r := plinth_rect()
	var b := RuinKit.Build.new(611,0.4,"Plinth")
	var hx := r.size.x*0.5
	Spine._beam(b,Vector3(-hx,0.0,0.0),Vector3(hx,0.0,0.0),Vector2(r.size.y,PLINTH_H+2.0))
	var plinth := b.finish()
	var shell := Tower.tower_shell(612,SHELL_WEAR,SHELL_H)
	var lb := RuinKit.Build.new(613,0.3,"Lookout")
	var back := Tower.WALL+0.4
	Spine._beam(lb,Vector3(-back,0.0,0.0),Vector3(LOOKOUT_OUT,0.0,0.0),LOOKOUT)
	var lookout := lb.finish()
	var c := r.get_center()
	var ox := TOWER_AT.x+Tower.half_extents().x
	return [
		["tower/plinth",plinth,Vector3(c.x,plinth_top(),c.y),0.0],
		["tower/stairs",RuinKit.piece("stairs",614,0.35),stairs_at(),0.0],
		["tower/shell",shell,Vector3(TOWER_AT.x,plinth_top(),TOWER_AT.y),0.0],
		["tower/lookout",lookout,Vector3(ox,tower_rim()+LOOKOUT_STEP,TOWER_AT.y),0.0],
	]

# --- The part spots -----------------------------------------------------------------

## The holder types a spot could host later (spec item 10): only `lying` is
## built now; the rest are data for a later round.
const HOLDERS := ["lying","cache","water","islet","salvager","knight","jammed"]

## A point on the spine's ground at axis `x`, `d` across.
static func on_spine(x: float, d: float) -> Vector3:
	var q := Spine.at(x,d)
	return Vector3(q.x,Spine.ground(q.x,q.y),q.y)

## A point on slab or fragment `name`'s top, `off` (x, z) from its middle.
static func on_slab(name: String, off := Vector2.ZERO) -> Vector3:
	var s := Spine.slab(name)
	var c := Spine.slab_at(s)+off
	return Vector3(c.x,TOP+float(s[4]),c.y)

## The candidate spots for the plane's six parts, in the architecture's
## nooks: [mass, what it asks, world point (on what it rests on), holder
## tags]. Named `wreck_cluster/part_spot_NN` (NN from 01 in this order) for
## the world view; the deal settles each onto what's under it.
static func spots() -> Array:
	var podium := TOP+Spine.PODIUM
	return [
		["head","in the cella, by the altar",Vector3(Spine.ALTAR_X+2.4,podium,Spine.zc(Spine.ALTAR_X+2.4)+1.6),["lying","cache"]],
		["head","the pulpit off the podium (dropped onto)",on_slab("pulpit",Vector2(0.4,0.6)),["lying","salvager"]],
		["way","under the first portal's arch",on_spine(float(Spine.LINES[2][0]),0.0),["lying","jammed"]],
		["way","on the north balcony",on_slab("balcony",Vector2(-0.3,-0.4)),["lying","salvager"]],
		["way","under the second portal's arch",on_spine(float(Spine.LINES[5][0]),1.2),["lying","jammed"]],
		["bench","the top slab of the south three",on_slab("south_3"),["lying","knight"]],
		["bench","the bench's east end by the tail",Spine.bench_point(140.0),["lying","cache"]],
		["tail","the tail's first fragment",on_slab("frag_1",Vector2(0.5,-0.5)),["lying","islet"]],
		["tail","the tail's far fragment (over the bridge)",on_slab("frag_3"),["lying","salvager"]],
		["tail","the last fragment, under the bench",on_slab("frag_5"),["lying","water"]],
		["tower","the tower top, on the east wall's head by the lookout",east_head(-1.6),["lying","salvager"]],
	]

static func spot_name(i: int) -> String:
	return "wreck_cluster/part_spot_%02d" % (i+1)

# --- The knight -------------------------------------------------------------------

## The knight's line (scripts/enemies/rune_knight.gd `setup`): none until
## his deck is built (empty: no knight).
static func knight_line() -> Dictionary:
	return {}
