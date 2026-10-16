extends Node3D
## A crossing: one set
## piece between two isles of the spiral, workshopped on its own in the
## crossing yard (studies/crossing_yard.gd) before it goes into a level or
## the generator. Each crossing is one script extending this.
##
## The contract:
## - Its frame: the entry (the start rim) at the origin, its walk top y 0,
##   the way in ENTRY_FACE (-Z). The yard sets the node where it likes.
## - `lay_out()` works its numbers out (from the walker's moves: AGENTS.md
##   "Sizes") before anything is built, so `entry`, `exit` and `beats` are
##   known first; `build(paint)` then builds it under itself: colliders on
##   layer 1 (StaticBody3D) and their drawing. `paint` is a
##   Callable(colour: String) -> Material for the greybox, in the
##   character study's colours: "grey" structure, "wall", "floor", "lip"
##   (a top made to hang from: capped orange), "pad" (a landing), "dark",
##   "lane" (a way to run or slide).
## - `entry()` / `exit()`: {at: Vector3 (feet, local), face: Vector2 (x, z)}:
##   where the start rim sets him down and the far rim's landing.
## - `exit_reached(feet)`: true stood on the far rim.
## - `beats()`: practice spawns in order, [{name, at, face}] (local).
## - `floor_y()`: the void's floor under it all (local): fallen past it he
##   is lost, and the yard sends him back to the start rim.
## - `updrafts()`: the rising air beside it (thermals the pocket sail climbs,
##   scripts/sky_currents.gd's), [{name, base: Vector3 (local, its foot),
##   top (local y), radius}]; none by default.
## - `title()`.
## - Hazards (optional, none here): `has_hazards()`, `set_hazards(on)`,
##   `step_hazards(delta, motor, space)` (the yard calls it each frame
##   after the pilot's motor; returns a word for a hit, "" for none) and
##   `hazard_voices()` (nodes with an `air_blast` and `mouth_at()`: the
##   yard's sound reads each as a dragon's blast).
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const WorldScale = preload("res://scripts/world_scale.gd")

const ENTRY_FACE := Vector2(0.0,-1.0)

var _paint: Callable

func title() -> String:
	return "crossing"

func lay_out() -> void:
	pass

func build(paint: Callable) -> void:
	_paint = paint

func entry() -> Dictionary:
	return {"at":Vector3.ZERO,"face":ENTRY_FACE}

func exit() -> Dictionary:
	return {"at":Vector3.ZERO,"face":ENTRY_FACE}

func exit_reached(_feet: Vector3) -> bool:
	return false

func beats() -> Array:
	return []

func floor_y() -> float:
	return -10.0

func updrafts() -> Array:
	return []

func has_hazards() -> bool:
	return false

func set_hazards(_on: bool) -> void:
	pass

func step_hazards(_delta: float, _motor: Object, _space: PhysicsDirectSpaceState3D) -> String:
	return ""

func hazard_voices() -> Array:
	return []

## A motor fitted to the walker's size (scripts/world_scale.gd), to read
## his moves' numbers from: nothing in a crossing holds its own copy.
static func walker() -> PilotMotor:
	var m := PilotMotor.new()
	m.set_size(WorldScale.wanderer)
	return m

# --- Headings ----------------------------------------------------------------------

## The way (x, z) a heading `deg` clockwise (seen from above) from -Z faces.
static func way(deg: float) -> Vector2:
	var a := deg_to_rad(deg)
	return Vector2(sin(a),-cos(a))

## To the right of `w` (x, z).
static func right_of(w: Vector2) -> Vector2:
	return Vector2(-w.y,w.x)

## The turn about up that takes -Z (the kit's back, the motor's facing 0)
## onto the heading `deg`, and the kit's front (+Z) onto its opposite.
static func yaw_of(deg: float) -> float:
	return -deg_to_rad(deg)

## A point `along` m along the heading `deg` from `from`, `aside` to its
## right, `up` over it.
static func at(from: Vector3, deg: float, along: float, aside := 0.0, up := 0.0) -> Vector3:
	var w := way(deg)
	var r := right_of(w)
	return from+Vector3(w.x*along+r.x*aside,up,w.y*along+r.y*aside)

# --- Greybox -----------------------------------------------------------------------

## A solid box `size` (x across, y, z along) round `middle`, turned to face
## heading `deg` (its -Z along it) and tipped `pitch` radians about its own
## x (nose up), coloured `colour` ("" draws nothing: a collider only).
## A "lip" box is capped orange on its top.
func box(size: Vector3, middle: Vector3, deg := 0.0, colour := "grey", pitch := 0.0) -> StaticBody3D:
	var basis := Basis(Vector3.UP,yaw_of(deg))*Basis(Vector3.RIGHT,pitch)
	var solid := StaticBody3D.new()
	solid.transform = Transform3D(basis,middle)
	var shape := BoxShape3D.new()
	shape.size = size
	var collider := CollisionShape3D.new()
	collider.shape = shape
	solid.add_child(collider)
	if colour != "":
		var mesh := BoxMesh.new()
		mesh.size = size
		var drawn := MeshInstance3D.new()
		drawn.mesh = mesh
		drawn.material_override = _paint.call("grey" if colour == "lip" else colour)
		solid.add_child(drawn)
		if colour == "lip":
			var cap := MeshInstance3D.new()
			var slab := BoxMesh.new()
			slab.size = Vector3(size.x+0.02,0.1,size.z+0.02)
			cap.mesh = slab
			cap.position = Vector3(0.0,size.y*0.5-0.045,0.0)
			cap.material_override = _paint.call("lip")
			solid.add_child(cap)
	add_child(solid)
	return solid

## A column from `bottom` to `top` (local y), `size` (x across, z along)
## round (x, z) of `foot`, facing heading `deg`.
func column(foot: Vector3, size: Vector2, bottom: float, top: float, deg := 0.0, colour := "grey") -> StaticBody3D:
	return box(Vector3(size.x,top-bottom,size.y),Vector3(foot.x,(top+bottom)*0.5,foot.z),deg,colour)

## A slab `width` across whose top runs straight from the edge `high` down
## to the edge `low` (their middles), `thick` under it.
func slab(high: Vector3, low: Vector3, width: float, thick: float, colour := "lane") -> StaticBody3D:
	var run := low-high
	var flat := Vector2(run.x,run.z)
	var deg := rad_to_deg(atan2(flat.x,-flat.y))
	var pitch := -atan2(-run.y,flat.length())
	var basis := Basis(Vector3.UP,yaw_of(deg))*Basis(Vector3.RIGHT,pitch)
	var middle := (high+low)*0.5-basis.y*thick*0.5
	return box(Vector3(width,thick,run.length()),middle,deg,colour,pitch)

## A ruin-kit piece set at `place`; `solid` false drops its body (drawn
## only, dressing).
func piece(node: Node3D, place: Transform3D, solid := true) -> Node3D:
	node.transform = place
	if not solid:
		var body := node.get_node_or_null("Body")
		if body != null:
			node.remove_child(body)
			body.free()
	add_child(node)
	return node
