extends RefCounted
## The motif editor on a base (spec-editor-traps item 11): a coded pool
## motif (colonnade_spine, bell_spires, ...: scripts/kit_isle/
## motif_based.gd) stood read-only in the grey look, its land and ruins
## collided (on the turf layer, so the editor's rays find them), its height
## field baked for lips and seats. Traps, pieces and markers go on it as on
## an authored hill; the land tools and sliders refuse.
##   --load-base=<pool id>        a fresh file on that base
##   Cmd/Ctrl K, "Base: <id>"     the same from the palette
## Saved as {"base", "seed", traps, pieces, markers}; --load=<slug> opens it
## again, the motif yard stands it (`--motif=<slug>`).
const MotifBased = preload("res://scripts/kit_isle/motif_based.gd")
const MotifAuthored = preload("res://scripts/kit_isle/motif_authored.gd")

## The tools a base allows (the rest shape land it has none of).
const TOOLS_OK := ["select","trash","run_aqueduct","run_wall","run_bridge"]

var editor: Node3D

func _init(e: Node3D) -> void:
	editor = e

func on() -> bool:
	return (editor.data as Dictionary).has("base")

## A fresh file on pool motif `id_name` (slug "on_<id>"); {} if no such.
static func fresh(id_name: String) -> Dictionary:
	if MotifBased.base_script(id_name) == null: return {}
	return MotifBased.blank_on("on_"+id_name,id_name)

## The base and its pieces stood bare (grey unless the look is full).
func stand() -> void:
	var e := editor
	var began := Time.get_ticks_msec()
	e._clear_stand()
	if e.rb != null: e.rb.reset()
	e.motif = MotifAuthored.from_data(e.data)
	e.motif.warm()
	e.bare = Node3D.new()
	e.bare.name = "Bare"
	e.add_child(e.bare)
	e.motif.build(e.bare)
	turf_layer(e.motif.base_root)
	if not e.dressed and e.grey != null: e.grey.paint(e.bare)
	e.bare_ms = Time.get_ticks_msec()-began
	e.rebuilds += 1
	e._after_land()

## Every body of the base on the turf layer too (the editor's ground rays).
func turf_layer(root: Node3D) -> void:
	if root == null: return
	for co: Node in root.find_children("*","CollisionObject3D",true,false):
		(co as CollisionObject3D).collision_layer |= editor.TURF_LAYER

## The base's height field baked from what stands (once a stand is up).
func bake() -> void:
	var m: RefCounted = editor.motif
	if m == null or not m.has_method("bake"): return
	turf_layer(m.base_root)
	m.bake(editor.get_world_3d().direct_space_state)

## Whether tool `id_name` may be picked; says why not.
func allows(id_name: String) -> bool:
	if not on() or id_name in TOOLS_OK: return true
	editor.say("%s is a base: its land is read-only" % str(editor.data.base))
	return false

## The camera over the base's footprint.
func frame() -> void:
	var e := editor
	var r: Rect2 = e.motif.footprint()
	var c := r.get_center()
	var top := float(e.motif.crest_top())
	var far := maxf(r.size.x,r.size.y)
	e._cam_pos = Vector3(c.x+far*0.45,top+far*0.4,c.y+far*0.6)
	var to: Vector3 = Vector3(c.x,top*0.6,c.y)-(e._cam_pos as Vector3)
	e._cam_yaw = atan2(-to.x,-to.z)
	e._cam_pitch = atan2(to.y,Vector2(to.x,to.z).length())
	e._apply_cam()
