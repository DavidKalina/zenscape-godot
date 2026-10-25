extends Node3D
## A small free islet the world view adds (spec-world-handles.md goal 3,
## kind "islet" in scripts/layout_overrides.gd): the aqueduct isle's islet
## blob (Art.island over Art.blob, as the ring route's crags), its turf top
## level at the node's origin, its rock hanging under it, its turf lips.
## He stands on its turf (its body is solid and turf). Its knobs are tunes
## (the world view's panel): "size", its radius (m), and "seed", its shape;
## a changed one builds the land again under the same node, so its name,
## its place and its undo stay. Its own grass grows on it when it is built
## (the isle's carpet, KitFlora over its turf where it stands then), kept
## under it so a move carries it; --no-flora: none.

const Art = preload("res://scripts/shared/aqueduct_isle_art.gd")
const TurfLips = preload("res://scripts/shared/turf_lips.gd")
const IsleFlora = preload("res://scripts/shared/aqueduct_isle_flora.gd")

const SIZE := 4.0
const SIZE_MIN := 1.5
const SIZE_MAX := 14.0
const SEED := 1
## The isle's turf layer (studies/kit_isle.gd TURF_LAYER): his ground and
## the plane's landing read it.
const TURF_LAYER := 1 << 11

var size := SIZE
var seed_value := SEED
var _land: Node3D = null
var _grass: Node3D = null

## Called once it is in the tree (its grass reads the physics space).
func setup(t: Transform3D, a_seed := SEED, a_size := SIZE) -> void:
	transform = t
	seed_value = a_seed
	size = clampf(a_size,SIZE_MIN,SIZE_MAX)
	_build()

func _build() -> void:
	for n: Node3D in [_land,_grass]:
		if n != null:
			remove_child(n)
			n.queue_free()
	_grass = null
	var flat := func(_x: float, _z: float) -> float: return 0.0
	_land = Art.island(Art.blob(Vector2.ZERO,size,seed_value),size*1.4,seed_value,flat,0.0)
	_land.name = "Land"
	add_child(_land)
	for body: Node in _land.find_children("*","StaticBody3D",true,false):
		(body as StaticBody3D).collision_layer |= TURF_LAYER
	TurfLips.dress(_land,seed_value)
	_grow()

## The isle's grass over its turf where it stands now, then held under it.
func _grow() -> void:
	if not is_inside_tree() or "--no-flora" in preload("res://scripts/launch_args.gd").user_args(): return
	var body := _land.get_node("Body") as StaticBody3D
	PhysicsServer3D.body_set_state(body.get_rid(),PhysicsServer3D.BODY_STATE_TRANSFORM,body.global_transform)
	var site := IsleFlora.site()
	site.wear = Callable()
	site.ray = Vector2(global_position.y+60.0,global_position.y-8.0)
	var outline: Array = []
	for p: Vector2 in Art.blob(Vector2.ZERO,size,seed_value):
		var w := global_transform*Vector3(p.x,0.0,p.y)
		outline.append(Vector2(w.x,w.z))
	_grass = KitFlora.grow(seed_value,get_world_3d().direct_space_state,KitLand.turf_bodies(_land),[outline],site)
	_grass.name = "Grass"
	add_child(_grass)
	_grass.transform = global_transform.affine_inverse()

# --- The layout contract (scripts/layout_overrides.gd) ---------------------------------

func layout_pose() -> Transform3D:
	return transform

func layout_place(t: Transform3D) -> void:
	transform = t

func layout_mid() -> Vector3:
	return global_position

func layout_reach() -> float:
	return size

func layout_tunes() -> Array:
	return [["size","size (radius m)",SIZE,SIZE_MIN,SIZE_MAX,0.25],["seed","seed (shape)",SEED,1,999,1]]

func layout_tune(key: String) -> float:
	return size if key == "size" else float(seed_value)

func layout_retune(key: String, v: float) -> void:
	if key == "size":
		var to := clampf(v,SIZE_MIN,SIZE_MAX)
		if is_equal_approx(to,size): return
		size = to
	else:
		var to := clampi(int(round(v)),1,999)
		if to == seed_value: return
		seed_value = to
	_build()
