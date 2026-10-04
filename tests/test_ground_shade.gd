extends SceneTree
## The shade trees lay on the ground (scripts/ground_shade.gd, docs/scenic/
## grass-look.md "Round five"). Headless: the baked field and its texture are
## checked on real terrain data through place, remove, undo and redo; how the
## ground paints it is GPU work (tools/capture_ground.gd).
const GroundShade = preload("res://scripts/ground_shade.gd")
var failures := 0

class FakeEditor extends Node:
	var data: NativeTerrainData

func _initialize() -> void:
	_bake()
	await _follows_the_trees()
	print("PASS: ground shade" if failures == 0 else "FAIL: ground shade")
	quit(1 if failures else 0)

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
	print(("ok   " if ok else "FAIL ") + message)

## One crown: deepest at its heart, soft past its drip line, nothing a few
## metres off; a grove runs deeper than one tree but never past 1; flowers,
## rocks and desert plants cast none.
func _bake() -> void:
	var one := GroundShade.tree_list([{"asset":"broadleaf","x":2.0,"z":-3.0,"scale":1.2}])
	check(one.size() == 3 and is_equal_approx(one[2], GroundShade.CROWN.broadleaf * 1.2), "A tree is listed with its crown at its scale: %s" % [one])
	var field := GroundShade.bake(one)
	var heart := GroundShade.field_at(field, Vector2(2.0, -3.0))
	var edge := GroundShade.field_at(field, Vector2(2.0 + GroundShade.CROWN.broadleaf * 1.2, -3.0))
	var off := GroundShade.field_at(field, Vector2(2.0 + 5.0, -3.0))
	check(heart > GroundShade.DEPTH * 0.85 and heart <= GroundShade.DEPTH + 0.001, "Shade under the crown's heart: %.2f" % heart)
	check(edge > 0.05 and edge < heart, "Shade thins past the drip line: %.2f" % edge)
	check(off == 0.0, "No shade 5 m off: %.3f" % off)
	var grove := PackedFloat32Array()
	for i in range(6): grove.append_array(PackedFloat32Array([-6.0 + i * 0.6, 4.0, 1.3]))
	var deep := GroundShade.field_at(GroundShade.bake(grove), Vector2(-4.5, 4.0))
	check(deep > heart and deep <= 1.0, "A grove runs deeper than one tree, never past 1: %.2f" % deep)
	var none := GroundShade.tree_list([{"asset":"poppy","x":0.0,"z":0.0,"scale":1.0},{"asset":"boulder_1","x":1.0,"z":0.0,"scale":1.0},{"asset":"cactus","x":2.0,"z":0.0,"scale":1.0},{"asset":"joshua","x":3.0,"z":0.0,"scale":1.0}])
	check(none.is_empty(), "Flowers, rocks and desert plants cast no shade")
	var rim := GroundShade.bake(PackedFloat32Array([15.8, -15.8, 2.0]))
	check(rim.size() == GroundShade.SIZE * GroundShade.SIZE, "A crown over the plate's edge bakes inside it")

## On real terrain data: placing a tree bakes its pool and sets the texture
## the ground reads; placing flowers reads the records but does not bake;
## removing the tree, undo and redo follow it.
func _follows_the_trees() -> void:
	var source := preload("res://assets/zen_reference/geometry.scn").instantiate()
	var data := NativeTerrainData.new()
	data.setup(source.get_node("terrain").mesh)
	source.free()
	data.reset_flat()
	var editor := FakeEditor.new()
	editor.data = data
	root.add_child(editor)
	var shade := GroundShade.new()
	root.add_child(shade)
	shade.setup(editor)
	shade.finish()
	var bound: Variant = RenderingServer.global_shader_parameter_get("zs_ground_shade")
	if bound == null: print("     unverified headless: the dummy renderer keeps no global shader parameters")
	else: check(bound == shade.texture, "The ground's texture is the global zs_ground_shade")
	check("zs_ground_shade" in RenderingServer.global_shader_parameter_get_list(), "zs_ground_shade is a project shader global")
	var image := shade.image
	check(image.get_format() == Image.FORMAT_RG8 and image.get_width() == GroundShade.SIZE, "The texture is %dx%d RG8" % [GroundShade.SIZE, GroundShade.SIZE])
	check(shade.shade_at(Vector2(3.0, 3.0)) == 0.0, "A treeless plate has no shade")
	var bakes: int = shade.bakes
	data.begin_stroke()
	var id := data.place("broadleaf", Vector2(3.0, 3.0), 0.0, 1.4)
	data.end_stroke()
	check(id > 0, "A broadleaf is placed")
	shade.finish()
	check(shade.bakes == bakes + 1 and shade.shade_at(Vector2(3.0, 3.0)) > 0.5, "Placing a tree bakes its shade: %.2f" % shade.shade_at(Vector2(3.0, 3.0)))
	var texel := shade.image.get_pixel(int((3.0 + 16.0) / GroundShade.TEXEL), int((3.0 + 16.0) / GroundShade.TEXEL))
	check(texel.r > 0.5 and texel.g == 0.0, "The texture carries it (red %.2f, green held at 0)" % texel.r)
	print("     bake took %.2f ms" % (shade.last_bake_usec / 1000.0))
	bakes = shade.bakes
	data.begin_stroke()
	data.place("poppy", Vector2(-4.0, 1.0))
	data.place("buttercup", Vector2(-4.5, 1.2))
	data.end_stroke()
	shade.finish()
	check(shade.bakes == bakes, "Painting flowers does not bake again")
	data.begin_stroke()
	data.remove_object(id)
	data.end_stroke()
	shade.finish()
	check(shade.shade_at(Vector2(3.0, 3.0)) == 0.0, "Removing the tree takes its shade")
	data.undo()
	shade.finish()
	check(shade.shade_at(Vector2(3.0, 3.0)) > 0.5, "Undo brings the shade back")
	data.redo()
	shade.finish()
	check(shade.shade_at(Vector2(3.0, 3.0)) == 0.0, "Redo takes it again")
	# The node reads on its own between frames, on the READ_SECONDS beat.
	data.begin_stroke()
	data.place("redwood", Vector2(-8.0, -8.0), 0.0, 1.0)
	data.end_stroke()
	await create_timer(GroundShade.READ_SECONDS * 2.0 + 0.1).timeout
	check(shade.shade_at(Vector2(-8.0, -8.0)) > 0.5, "The node picks up a new tree by itself")
	shade.queue_free()
	editor.queue_free()
