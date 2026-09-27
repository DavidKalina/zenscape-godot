extends SceneTree
## Film the Genesis plain through the creation shell: pick brushes from the
## palette with the pointer, raise land (tremor, fog parting), dig a hollow and
## pour water into it, pour on the ridge so a stream runs down, paint a forest,
## a meadow and a path, then put the brush away (Look) and watch the world
## answer: grass creeping in, trees and shrubs, fish, frogspawn, frogs, birds
## and the rarer moments. Run with Movie Maker so game time is fixed and the
## clip plays at true speed:
##   Godot --path . --write-movie /private/tmp/zs-film/genesis.avi --fixed-fps 30 \
##     --script res://tools/film_genesis.gd -- --plain-seed 7 --force-moments
## Movie Maker records at the project's viewport size (1440x960, fullscreen).
## For 1600x900, put a temporary override.cfg in the project root for the run:
##   [display]  window/size/viewport_width=1600  viewport_height=900  mode=0
## (one key per line) and delete it afterwards. The pointer drives the brush
## through NativeChunkEditor.pointer_override, never the real cursor.
## Headless with --fixed-fps 30 it runs the same script as a dry run and prints
## what the world did (ponds, streams, plants, life), without pictures.
## Film-only knobs (docs/scenic/life.md): the life clock runs `LIFE_PACE_EARLY`
## times faster until the first fish arrives, then `LIFE_PACE`, so arrivals fit
## the clip; the sky starts at `DAWN_PHASE`, so deer may come. `--force-moments`
## starts a heron and a deer near the end if neither came on its own (printed).
## Saves go to /private/tmp/zs-film, never the player's places.
const FILM_DIR := "/private/tmp/zs-film"
const WATCH_SECONDS := 32.0
const LIFE_PACE_EARLY := 2.5
const LIFE_PACE := 1.3
const DAWN_PHASE := 0.32
## Camera keyframes: [seconds, target (terrain-local), distance, polar°, yaw°].
const SHOTS := [
	[0.0,Vector3(0.0,0.8,0.5),35.0,55.0,-22.0],
	[12.0,Vector3(0.5,0.8,0.5),33.0,54.0,-16.0],
	[24.0,Vector3(1.5,0.6,0.5),30.0,53.0,-8.0],
	[42.0,Vector3(0.5,0.6,0.5),31.0,54.0,0.0],
	[56.0,Vector3(1.5,0.4,1.0),22.0,52.0,14.0],
	[70.0,Vector3(2.5,0.3,2.0),15.0,50.0,32.0],
	[84.0,Vector3(1.0,0.5,1.0),21.0,53.0,46.0],
]
var scene: Node3D
var editor: NativeChunkEditor
var life: Node
var cursor := Vector2.ZERO
var pointer := ColorRect.new()
var frame := 0
var force_moments := false
var forced := []

func _initialize() -> void:
	force_moments = "--force-moments" in OS.get_cmdline_user_args()
	run.call_deferred()

func seconds() -> float:
	return frame/30.0

func push(event: InputEvent, point: Vector2) -> void:
	event.position = root.get_final_transform()*point
	if event is InputEventMouse:
		event.global_position = event.position
	# Through Input so is_mouse_button_pressed sees the held button, as the
	# stroke loop checks it every frame.
	Input.parse_input_event(event)

func press(down: bool, button := MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	var mask := MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT
	event.button_mask = mask if down else 0
	event.pressed = down
	push(event,cursor)

func motion(held: int) -> void:
	var event := InputEventMouseMotion.new()
	event.button_mask = held
	push(event,cursor)

## One film frame: camera, pointer, the life clock's pace, then wait.
func step(held := 0) -> void:
	_camera()
	pointer.position = cursor-pointer.size*0.5
	editor.pointer_override = cursor
	motion(held)
	_pace()
	await process_frame
	frame += 1

func hold(seconds_: float, held := 0) -> void:
	for i in range(int(seconds_*30.0)):
		await step(held)

func _camera() -> void:
	var t := seconds()
	var a: Array = SHOTS[0]
	var b: Array = SHOTS[0]
	for i in range(SHOTS.size()):
		if SHOTS[i][0] <= t:
			a = SHOTS[i]
			b = SHOTS[mini(i+1,SHOTS.size()-1)]
	var f := 0.0 if b[0] <= a[0] else clampf((t-a[0])/(b[0]-a[0]),0.0,1.0)
	f = f*f*(3.0-2.0*f)
	scene.target = editor.terrain.to_global(a[1].lerp(b[1],f))
	scene.distance = lerpf(a[2],b[2],f)
	scene.polar = deg_to_rad(lerpf(a[3],b[3],f))
	scene.yaw = deg_to_rad(lerpf(a[4],b[4],f))
	scene._update_camera()

func _pace() -> void:
	if life == null: return
	life.pace = LIFE_PACE if life.present("fish").size() > 0 else LIFE_PACE_EARLY

## Ease the pointer over the screen to a point, button up.
func glide_screen(to: Vector2, seconds_: float) -> void:
	var from := cursor
	var frames := maxi(1,int(seconds_*30.0))
	for i in range(1,frames+1):
		var f := float(i)/frames
		cursor = from.lerp(to,f*f*(3.0-2.0*f))
		await step()

## Ease the pointer through ground points (terrain-local x, z), re-projected
## every frame so the path stays on the ground while the camera drifts.
func glide(points: Array, seconds_: float, held: int) -> void:
	var frames := maxi(1,int(seconds_*30.0))
	for i in range(1,frames+1):
		var t := float(i)/frames*(points.size()-1)
		var at := mini(int(t),points.size()-2)
		var f := t-at
		var xz: Vector2 = points[at].lerp(points[at+1],f*f*(3.0-2.0*f))
		cursor = ground(xz.x,xz.y)
		await step(held)

func ground(x: float, z: float) -> Vector2:
	var point := editor.terrain.to_global(Vector3(x,editor.data.ground_height(Vector2(x,z)),z))
	return scene.camera.unproject_position(point)

func stroke(points: Array, seconds_: float, button := MOUSE_BUTTON_LEFT) -> void:
	await glide_screen(ground(points[0].x,points[0].y),0.7)
	var mask := MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT
	press(true,button)
	await hold(0.1,mask)
	if not editor._painting: print("FILM stroke missed at ",cursor," (palette or sky under the pointer?)")
	await glide(points,seconds_,mask)
	await hold(0.3,mask)
	press(false,button)
	await hold(0.1)

## Click a palette button the way a player does; falls back to the scene call
## if the click did not land (printed).
func pick(id: String) -> void:
	var button: Button = scene.creation_palette.look_button if id == "look" else scene.creation_palette.buttons[id]
	await glide_screen(button.get_global_rect().get_center(),0.8)
	press(true)
	await hold(0.1)
	press(false)
	await hold(0.3)
	var ok: bool = scene.looking if id == "look" else editor.held_brush() == id and not scene.looking
	if not ok:
		print("FILM pick fallback ",id)
		if id == "look": scene.set_looking(true)
		else: scene.select_brush(id)

func look(label: String) -> void:
	var assets := {}
	for item: Dictionary in editor.data.objects:
		assets[item.asset] = assets.get(item.asset,0)+1
	var alive := {}
	if life != null:
		for kind in life.sites: alive[kind] = life.present(kind).size()
	var moments: Array = life.moments.history.map(func(entry: Dictionary) -> String: return entry.kind) if life != null else []
	print("FILM %s t=%.1f ponds=%d streams=%d objects=%s life=%s moments=%s brush=%s" % [label,seconds(),editor.data.ponds.size(),editor.data.streams.size(),JSON.stringify(assets),JSON.stringify(alive),JSON.stringify(moments),editor.held_brush()])

func run() -> void:
	root.size = Vector2i(1600,900)
	DirAccess.make_dir_recursive_absolute(FILM_DIR)
	scene = load("res://studies/cozy_worlds.tscn").instantiate()
	scene.places_path = FILM_DIR.path_join("places-%d.json" % Time.get_ticks_usec())
	scene.set_meta("movie_capture",true)
	root.add_child(scene)
	current_scene = scene
	while not scene.places_ready or not scene.shell_ready:
		await process_frame
	editor = scene._chunk_editor
	while scene._growth.terrain < 0.995:
		await process_frame
	life = scene.get("land_life")
	# The creation shell stays on screen: the brush palette, its hint and the
	# top-right Craft and World. Status notices are hidden.
	scene._notice.visible = false
	if scene.places.get("cover") != null: scene.places.cover.visible = false
	# Morning light that deer still count as dawn (life_moments DAWN).
	scene._celestial.set_phase(DAWN_PHASE)
	# Gentle enough that the land reads as hills, well under the ceiling.
	editor.land_strength = 0.6
	pointer.size = Vector2(12,12)
	pointer.color = Color(1,1,1,0.85)
	pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pointer.rotation = PI*0.25
	var overlay := CanvasLayer.new()
	overlay.layer = 100
	overlay.add_child(pointer)
	root.add_child(overlay)
	cursor = root.get_visible_rect().size*Vector2(0.5,0.35)
	await hold(1.5)
	look("plain")
	# Land: a long ridge swept across the back, then a rounded hill in front.
	await stroke([Vector2(-7.5,-3.5),Vector2(-2.0,-5.5),Vector2(3.0,-5.0),Vector2(7.5,-2.5)],3.2)
	await hold(1.2)
	await stroke([Vector2(-4.0,3.5),Vector2(-2.5,4.5),Vector2(-5.0,5.0),Vector2(-3.5,3.0),Vector2(-4.0,4.2)],2.6)
	await hold(1.0)
	look("land")
	# A hollow, pressed down with a right drag.
	await stroke([Vector2(3.0,1.5),Vector2(4.2,2.3),Vector2(3.0,3.0),Vector2(2.2,2.0),Vector2(3.2,2.0)],2.4,MOUSE_BUTTON_RIGHT)
	await hold(1.0)
	look("hollow")
	# Water: poured into the hollow it fills; poured on the ridge it runs down.
	await pick("water")
	await stroke([Vector2(3.0,2.0),Vector2(3.6,2.6),Vector2(2.6,2.4),Vector2(3.1,1.8)],2.4)
	await hold(3.5)
	look("pond")
	await stroke([Vector2(4.2,-4.6),Vector2(4.8,-4.2),Vector2(4.4,-4.0)],1.6)
	await hold(4.0)
	look("stream")
	# Forest on the hill's shoulder, a meadow by the pond, a path down to it.
	await pick("forest")
	await stroke([Vector2(-8.0,-0.5),Vector2(-5.0,0.2),Vector2(-2.0,-0.8),Vector2(-0.5,-2.0)],3.0)
	await hold(0.6)
	await pick("meadow")
	await stroke([Vector2(6.0,7.0),Vector2(8.0,5.0),Vector2(8.5,2.0)],2.4)
	await hold(0.6)
	await pick("path")
	await stroke([Vector2(-7.0,8.5),Vector2(-3.5,8.3),Vector2(-0.5,7.0),Vector2(1.8,4.9)],2.6)
	await hold(0.8)
	look("painted")
	# Put the brush away and watch.
	await pick("look")
	await glide_screen(Vector2(-40,-40),0.6)
	var frames := int(WATCH_SECONDS*30.0)
	for i in range(frames):
		await step()
		if i % 150 == 0: look("watch")
		if force_moments and i == int((WATCH_SECONDS-14.0)*30.0) and life != null:
			var seen: Array = life.moments.history.map(func(entry: Dictionary) -> String: return entry.kind)
			for kind in ["deer","heron"]:
				if kind not in seen and life.moments.force(kind): forced.append(kind)
			print("FILM forced ",JSON.stringify(forced))
	look("end")
	print("FILM forced ",JSON.stringify(forced)," frames=",frame)
	scene.queue_free()
	await process_frame
	quit()
