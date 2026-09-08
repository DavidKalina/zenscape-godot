extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
 root.size = Vector2i(1440,900)
 var scene: Node3D = load("res://studies/nursery_preview.tscn").instantiate()
 root.add_child(scene)
 await create_timer(0.5).timeout
 scene._paused = true
 var palette: NativeBuildPalette = scene._build_palette
 palette.set_process(false)
 palette.close_palette()
 var hand: Control = palette._hand
 var control := Control.new()
 control.mouse_filter = Control.MOUSE_FILTER_IGNORE
 palette.add_child(control)
 control.z_index = 101
 control.draw.connect(func() -> void:
  control.draw_colored_polygon(PackedVector2Array([Vector2.ZERO,Vector2(0,19),Vector2(5,14),Vector2(9,23),Vector2(13,21),Vector2(9,12),Vector2(17,12)]),Color("f7f0df"))
  control.draw_polyline(PackedVector2Array([Vector2.ZERO,Vector2(0,19),Vector2(5,14),Vector2(9,23),Vector2(13,21),Vector2(9,12),Vector2(17,12),Vector2.ZERO]),Color("392e38"),1.5,true))
 DirAccess.make_dir_recursive_absolute("/private/tmp/gripper-effect")
 DirAccess.make_dir_recursive_absolute("/private/tmp/gripper-control")
 DirAccess.make_dir_recursive_absolute("res://docs/design/garden-cursor")
 for frame in range(120):
  var t := float(frame)/119.0
  var point := Vector2(290+130*t,240+sin(t*TAU)*22)
  var carrying := frame >= 24 and frame < 66 or frame >= 84 and frame < 105
  if frame == 24 or frame == 84: palette._start_placing("tree")
  if frame == 66:
   scene._chunk_editor.select_tool("tree")
   scene._chunk_editor.place_at(point)
   palette._finish_placing(true)
  if frame == 105: palette._finish_placing(false)
  hand.show_at(point,carrying,1.0/24.0)
  control.visible = false
  await process_frame
  RenderingServer.force_draw(false)
  var effect := root.get_texture().get_image()
  effect.save_jpg("/private/tmp/gripper-effect/%04d.jpg" % frame,0.95)
  if frame == 46: effect.save_png("res://docs/design/garden-cursor/carrying.png")
  hand.visible = false
  control.visible = true
  control.position = point
  control.queue_redraw()
  await process_frame
  RenderingServer.force_draw(false)
  root.get_texture().get_image().save_jpg("/private/tmp/gripper-control/%04d.jpg" % frame,0.95)
 print("Cursor capture complete: idle 0–1s, carrying 1–2.75s, placement 2.75s, cancel 4.375s")
 scene.queue_free()
 await process_frame
 quit()
