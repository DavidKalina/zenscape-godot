extends RefCounted
## The home isle (docs/design/home/spec-home.md): the haul's end, west of
## the stretch's last rocks (studies/wreck_cluster_stretch.gd, its line
## ends near x -700 on z 16). Built in the wreck cluster study with --home,
## which starts you there on foot beside the working plane.
##
## A compact landform, not a disc: a long low tongue the strip runs along
## (z STRIP_Z, from the east rim at x STRIP_EAST west to STRIP_WEST), so the
## flight home off the stretch ends in a straight-in approach heading -x;
## north of the strip a shelf for the vault (spec task 2) under a grassy
## bluff at the west end; south of it a broad flat for the drop field (task
## 4), its rim rising into a low hummock at the south-west. The plane parks
## at the strip's west end facing east, down the strip toward the stretch.
##
## World-view names: the island `island/home`, its pieces `home/<piece>`
## (studies/wreck_cluster.gd `_place_piece` with the "home/" root).

const RuinKit = preload("res://scripts/ruin_kit.gd")

## The turf's base height (the stretch's islets stand at 20 and 22, its
## line at 34-36): the approach comes down some 10 m over the last 60 m of
## open sky past rocks_e.
const TOP := 26.0
## The strip: a clear run along z STRIP_Z from STRIP_EAST to STRIP_WEST
## (165 m), STRIP_HALF either side kept flat and clear.
const STRIP_Z := 16.0
const STRIP_HALF := 7.0
const STRIP_EAST := -762.0
const STRIP_WEST := -927.0
## The parked plane: near the strip's west end, facing east (heading -PI/2:
## forward (-sin h, 0, -cos h) = +x), so its take-off runs the strip's
## length toward the stretch.
const PLANE_AT := Vector2(-912.0,STRIP_Z)
const PLANE_HEADING := -PI*0.5
## The vault's shelf north of the strip (task 2) and the drop field south
## of it (task 4): their middles, kept flat.
const VAULT_AT := Vector2(-880.0,31.0)
const FIELD_AT := Vector2(-850.0,-2.0)
const FIELD_HALF := Vector2(26.0,8.0)

## The outline (x, z), wound as the cluster's lands (east along the south
## rim, back along the north): a narrow tongue in the east under the
## approach, widening west into the field (south) and the vault's shelf and
## bluff (north).
static func outline() -> Array:
	return [Vector2(-944.0,14.0),Vector2(-940.0,2.0),Vector2(-930.0,-8.0),Vector2(-912.0,-14.5),
		Vector2(-884.0,-15.5),Vector2(-852.0,-14.5),Vector2(-826.0,-12.0),Vector2(-812.0,-4.0),
		Vector2(-800.0,4.5),Vector2(-784.0,7.0),Vector2(-766.0,7.5),Vector2(-756.0,11.0),
		Vector2(-754.0,17.0),Vector2(-758.0,23.0),Vector2(-772.0,25.5),Vector2(-800.0,27.0),
		Vector2(-826.0,34.0),Vector2(-846.0,42.0),Vector2(-872.0,46.0),Vector2(-900.0,47.0),
		Vector2(-924.0,43.5),Vector2(-938.0,35.0),Vector2(-944.0,25.0)]

## The turf's height at (x, z): TOP on the strip, the field and the vault's
## shelf; a bluff rising some 9 m at the north-west, a hummock some 4.5 m at
## the south-west rim, a low swell on the north rim, each eased in so the slopes stay walkable.
static func ground(x: float, z: float) -> float:
	var h := TOP
	h += 9.0*_mound(x,z,Vector2(-924.0,42.0),Vector2(28.0,17.0))
	h += 4.5*_mound(x,z,Vector2(-930.0,-8.0),Vector2(18.0,13.0))
	h += 2.5*_mound(x,z,Vector2(-848.0,44.0),Vector2(20.0,9.0))
	# The strip's band, the field and the vault's shelf held flat.
	var keep := maxf(_flat(absf(z-STRIP_Z),STRIP_HALF,4.0),_flat(_box(x,z,FIELD_AT,FIELD_HALF),0.0,4.0))
	keep = maxf(keep,_flat(_box(x,z,VAULT_AT,Vector2(12.0,6.0)),0.0,4.0))
	return lerpf(h,TOP,keep)

## A smooth mound: 1 at `at`, easing to 0 at `half` (x, z) away.
static func _mound(x: float, z: float, at: Vector2, half: Vector2) -> float:
	var d := Vector2((x-at.x)/half.x,(z-at.y)/half.y).length()
	return 1.0-smoothstep(0.0,1.0,d)

## How far (m) (x, z) lies outside the box at `at` with half extents `half`.
static func _box(x: float, z: float, at: Vector2, half: Vector2) -> float:
	return Vector2(maxf(absf(x-at.x)-half.x,0.0),maxf(absf(z-at.y)-half.y,0.0)).length()

## 1 within `inner` of the kept place, easing to 0 `ease` m further out.
static func _flat(d: float, inner: float, ease: float) -> float:
	return 1.0-smoothstep(inner,inner+ease,d)

## The isle as a row of the cluster's lands (studies/wreck_cluster_art.gd
## `lands`: name, outline, ground, depth, seed, cliffs, rim).
static func land() -> Array:
	return ["home",outline(),ground,34.0,467,Rect2(),TOP]

## The rock it hangs (studies/wreck_cluster_art.gd `hangs`): a long keel
## under the strip, three fangs, leaning a little east.
const HANG := {"rings":[[4.0,0.94],[10.0,0.82],[18.0,0.64],[24.0,0.5]],"fangs":[32.0,38.0,28.0],"spread":0.5,"lean":Vector2(4.0,1.0)}

## The isle built as the stretch's islets are (KitLand turf, its own
## hanging rock, sides collided as drawn).
static func build_land(spec: Array) -> Node3D:
	var Art: GDScript = load("res://studies/wreck_cluster_art.gd")
	var d := {"outline":spec[1],"seed":int(spec[4]),"ground":spec[2],"top":float(spec[6]),
		"depth":float(spec[3]),"hang":true,"resample":[60.0,128,48],"tone":KitLook.turf(int(spec[4])),"cell":2.0,
		"collide_sides":true,"sides":false,"name":"home"}
	var node := KitLand.island(d)
	node.name = "Land_Home"
	var rings: Array = Art.hang_rings(d,HANG)
	var drawn: MeshInstance3D = Art.hang_rock(rings,HANG,int(spec[4])).node("Mesh")
	node.add_child(drawn)
	KitLand.collide_sides(node,drawn,true)
	return node

## The pieces: [layout name (under home/), node, world foot, yaw (deg)]:
## a few ruins on the rims, off the strip's band, so the isle reads as an
## old place from the approach. The vault comes in the next step.
static func built() -> Array:
	return [
		["rim_pier",RuinKit.piece("pier",561,0.45),Vector3(-780.0,TOP,25.0),15.0],
		["rim_fallen",RuinKit.piece("fallen_pier",562,0.45),Vector3(-822.0,TOP,-9.0),70.0],
		["bluff_arch",RuinKit.piece("arch",563,0.4),Vector3(-922.0,ground(-922.0,41.0),41.0),100.0],
	]
