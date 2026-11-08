extends "res://scripts/endless/hall_doors.gd"
## The tutorial's way out (scripts/endless/tutorial/tutorial_land.gd): the
## doors world's ruin hall (hall_doors.gd), its one mouth set down in the
## meadow where the lesson asks (`place`), the other the wilderness ruin by
## the start (HallSeat), on the tutorial world's two sides
## (profiles/tutorial.gd). A cracked wall (cracked_walls.gd, sized to the
## mouth) seals the meadow's mouth: until a surge roll breaks it the mouth is
## stone (hall_doors.gd `ground` with `_open` false).

## The cracked wall's handle (cracked_walls.gd `place`).
const WALL := "cracked/tutorial-mouth"

var wall_handle := WALL

## The hall, its meadow mouth at `at` (world XZ), its way in `inward` (XZ).
func place(host: Node3D, at: Vector2, inward: Vector2, seed: int) -> void:
	name = "Doors"
	_host = host
	_world = host.world
	_field = host.field
	_rng.seed = seed*977+31
	_hint_wait = INF
	_big = WorldScale.opening(TOY_NAVE)/(2.0*Hall.ROW_Z)
	_bay = Hall.BAY*_big
	_room = (Hall.ROW_Z-Hall.ABACUS)*_big
	_roof = ROOF*_big
	_out = _bay*BAYS_OUT
	_foot = (Hall.WALL_Z+FOOT_OVER)*_big
	var coded: Array[Transform3D] = [_frame_on(HallSeat.wild_at(),HallSeat.wild_in()),_frame_on(at,inward.normalized())]
	walls = [
		{"name":"doors/amber-hall","find":"door/amber-hall","coded":coded[0],"white":Color.WHITE},
		{"name":"tutorial/meadow-hall","find":"door/tutorial-hall","coded":coded[1],"white":Color.WHITE},
	]
	for i in 2:
		walls[i].xform = coded[i]
		_frames.append(coded[i])
	_line()
	var far_mouth: Vector3 = _at_s(_len())
	_by = _frames[1].origin-_frames[0]*far_mouth
	var parts := _bays()
	for i in 2: walls[i].node = _build_ruin(i,parts)
	_build_hall(parts)
	_build_overlay()
	_make_lands()
	_seal()
	print("tutorial hall: its mouth at %s facing %s, out at %s, the hall %.0f m, the mouth %.1f m wide, %.1f m high" % [str(at.round()),str(inward.normalized()),str(_xz(0).round()),_len(),_room*2.0,_roof])

## The cracked wall across the meadow mouth: a chamber as wide and high as the
## mouth, standing just outside it, its front facing out.
func _seal() -> void:
	var cw: Node3D = _host.smash.walls
	var long := 10.0
	cw.place(wall_handle,Vector2(_frames[1].origin.x,_frames[1].origin.z),0.0)
	var site: Dictionary = cw.sites[wall_handle]
	var xf := _frames[1]*Transform3D(Basis(Vector3.UP,PI),Vector3(0.0,0.0,-(long+1.0)))
	site.xf = xf
	site.coded = xf
	site.wide = minf(_room*2.0+1.0,30.0)
	site.high = _roof+1.0
	site.long = long
	# A book that broke it in another run: sealed again for this one.
	site.open = false

## The meadow side's stone (the chamber) and the ruin: the mouth opens once the
## wall is broken.
func _open() -> bool:
	return super() and broken()

func broken() -> bool:
	return _host.smash.walls.is_broken(wall_handle)

## Where the mouth's middle stands (world), for a marker.
func mouth() -> Vector3:
	return _frames[1]*Vector3(0.0,_roof*0.5,0.0)

func side_at(p: Vector3) -> int:
	return int(_world.side(p.x,p.z))

## Whether the plane is through to the wilderness side.
func through() -> bool:
	return swaps > 0 and _side == 0
