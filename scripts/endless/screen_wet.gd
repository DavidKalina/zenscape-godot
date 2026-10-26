extends CanvasLayer
## Water on the screen: drops on the chase camera's lens after it flies
## through spray (scripts/endless/water_contact.gd), or anything else that
## douses it (a waterfall later) through one call, `wet(amount)`.
## - A dousing lays drops over the screen, more and bigger by the amount, and
##   for a moment a sheet of water bends and blurs the whole view
##   (shaders/screen_sheet.gdshader).
## - Each drop is a little lens (shaders/screen_drops.gdshader). Small ones
##   bead and sit; big ones run off with the airflow, out from the point the
##   plane travels toward and a little down, in stops and starts, leaving
##   beads behind and thinning as they go.
## - They dry: every drop shrinks by DRY px/s (faster at speed) and is gone
##   under a pixel or two.
## Nothing is drawn (the layer hidden) while the screen is dry.

## Drops at most, and how many a full dousing (`wet(1)`) lays.
const MOST := 220
const LAYS := 90
## Drop radius (px at 1080 high): the least, and the most at a full dousing
## (a small amount lays smaller ones), drawn toward the small end by SMALL.
const RADIUS := Vector2(2.5,26.0)
const SMALL := 2.4
## Over RUN px a drop runs with the airflow at up to RUN_SPEED px/s at the
## plane's cruise (`step`'s `air` 1), and SAG px/s down regardless.
const RUN := 7.0
const RUN_SPEED := 700.0
const SAG := 30.0
## Running, it stops for STICK s (min, max) every STICK_EVERY px or so and
## drops a bead BEAD of its size every BEAD_EVERY px (losing BEAD_COST of it).
const STICK := Vector2(0.03,0.22)
const STICK_EVERY := 45.0
const BEAD := 0.32
const BEAD_EVERY := 22.0
const BEAD_COST := 0.04
## Drying (px of radius per second; times 1 + DRY_FAST x air).
const DRY := 0.8
const DRY_FAST := 0.6
## The lens's reach (screen uv per px of radius).
const LENS := 0.0011
## The sheet fades over SHEET_FADE s.
const SHEET_FADE := 0.45

var _pos := PackedVector2Array()
var _vel := PackedVector2Array()
var _r := PackedFloat32Array()
var _stick := PackedFloat32Array()
var _moved := PackedFloat32Array()
var _born := PackedFloat32Array()
var _seed := PackedFloat32Array()
var _due := 0.0
var _clock := 0.0
var _rng := RandomNumberGenerator.new()
var _multi: MultiMesh
var _drops: MultiMeshInstance2D
var _sheet_rect: ColorRect
var _sheet_mat: ShaderMaterial
## The sheet now (0 to 1), and the most a dousing asked for this frame (for
## the sound: water_contact.gd reads and clears it).
var sheet := 0.0
var doused := 0.0

func _init() -> void:
	name = "ScreenWet"
	layer = 1
	_rng.randomize()

func _ready() -> void:
	_sheet_rect = ColorRect.new()
	_sheet_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sheet_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet_mat = ShaderMaterial.new()
	_sheet_mat.shader = preload("res://shaders/screen_sheet.gdshader")
	_sheet_rect.material = _sheet_mat
	_sheet_rect.visible = false
	add_child(_sheet_rect)
	_multi = MultiMesh.new()
	_multi.transform_format = MultiMesh.TRANSFORM_2D
	_multi.use_custom_data = true
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0,2.0)
	_multi.mesh = quad
	_multi.instance_count = MOST
	_multi.visible_instance_count = 0
	_drops = MultiMeshInstance2D.new()
	_drops.multimesh = _multi
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/screen_drops.gdshader")
	_drops.material = m
	add_child(_drops)
	visible = false

## Douse the screen: `amount` 0 to 1 (a full dousing at 1; fractions add
## up, so a steady trickle of small amounts lays drops now and then).
func wet(amount: float) -> void:
	if amount <= 0.0: return
	doused = maxf(doused,amount)
	sheet = maxf(sheet,clampf((amount-0.25)/0.75,0.0,1.0))
	_due += amount*LAYS
	var size := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1920,1080)
	var scale := size.y/1080.0
	var top := lerpf(RADIUS.x*2.5,RADIUS.y,clampf(amount*1.6,0.0,1.0))
	while _due >= 1.0:
		_due -= 1.0
		var r := lerpf(RADIUS.x,top,pow(_rng.randf(),SMALL))*scale
		_lay(Vector2(_rng.randf()*size.x,_rng.randf()*size.y),r)
	visible = true

## How wet the screen is (the drops' summed area over the screen's, about).
func wetness() -> float:
	var size := get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1920,1080)
	var area := 0.0
	for r in _r: area += PI*r*r
	return area/maxf(size.x*size.y,1.0)

func count() -> int:
	return _r.size()

## One frame: `toward` the point on the screen the plane travels toward
## (px; the airflow runs out from it), `air` the speed as a share of cruise.
func step(delta: float, toward: Vector2, air: float) -> void:
	_clock += delta
	sheet *= exp(-delta/SHEET_FADE)
	if sheet < 0.01: sheet = 0.0
	if _r.is_empty() and sheet <= 0.0:
		visible = false
		return
	visible = true
	var size := get_viewport().get_visible_rect().size
	var scale := size.y/1080.0
	var dry := DRY*scale*(1.0+DRY_FAST*clampf(air,0.0,1.5))*delta
	var i := 0
	while i < _r.size():
		var r := _r[i]-dry
		var p := _pos[i]
		var gone := r < 1.0*scale or p.x < -40.0 or p.y < -40.0 or p.x > size.x+40.0 or p.y > size.y+40.0
		if gone:
			_drop_at(i)
			continue
		_r[i] = r
		# Running: over RUN px it moves with the air, out from where the
		# plane heads and down, in stops and starts.
		var run := clampf((r/scale-RUN)/RUN,0.0,1.5)
		var v := Vector2.ZERO
		if _stick[i] > 0.0:
			_stick[i] -= delta
		elif run > 0.0:
			var out := p-toward
			out = out.normalized() if out.length() > 1.0 else Vector2.DOWN
			v = (out*RUN_SPEED*clampf(air,0.0,1.6)+Vector2.DOWN*SAG)*run*scale
			var step := v*delta
			_pos[i] = p+step
			_moved[i] += step.length()
			if _rng.randf() < step.length()/(STICK_EVERY*scale):
				_stick[i] = _rng.randf_range(STICK.x,STICK.y)
			if _moved[i] > BEAD_EVERY*scale:
				_moved[i] = 0.0
				_r[i] = r*(1.0-BEAD_COST)
				if _rng.randf() < 0.6 and _r.size() < MOST: _lay(p,r*BEAD*_rng.randf_range(0.7,1.2))
		_vel[i] = _vel[i].lerp(v,1.0-exp(-delta/0.05))
		i += 1
	_draw()
	_sheet_rect.visible = sheet > 0.0
	if sheet > 0.0:
		_sheet_mat.set_shader_parameter("sheet",sheet)
		_sheet_mat.set_shader_parameter("time",_clock)
		var flow := (size*0.5-toward)/maxf(size.y,1.0)
		_sheet_mat.set_shader_parameter("flow",Vector2(-flow.x,0.6+absf(flow.y)))

func _lay(at: Vector2, r: float) -> void:
	if _r.size() >= MOST:
		# Room is made by the smallest of a few.
		var least := 0
		for k in range(mini(8,_r.size())):
			var j := _rng.randi_range(0,_r.size()-1)
			if _r[j] < _r[least]: least = j
		if _r[least] >= r: return
		_drop_at(least)
	_pos.append(at)
	_vel.append(Vector2.ZERO)
	_r.append(r)
	_stick.append(_rng.randf_range(0.0,0.25))
	_moved.append(0.0)
	_born.append(_clock)
	_seed.append(_rng.randf())

func _drop_at(i: int) -> void:
	_pos.remove_at(i)
	_vel.remove_at(i)
	_r.remove_at(i)
	_stick.remove_at(i)
	_moved.remove_at(i)
	_born.remove_at(i)
	_seed.remove_at(i)

## The drops into the MultiMesh: each stretched along its run.
func _draw() -> void:
	var n := _r.size()
	_multi.visible_instance_count = n
	var scale := get_viewport().get_visible_rect().size.y/1080.0
	for i in range(n):
		var r := _r[i]
		var v := _vel[i]
		var speed := v.length()
		var stretch := 1.0+clampf(speed/(500.0*scale),0.0,1.0)*0.9
		var ax := v/speed if speed > 1.0 else Vector2.DOWN
		var x := Vector2(ax.y,-ax.x)*r
		var y := ax*r*stretch
		_multi.set_instance_transform_2d(i,Transform2D(x,y,_pos[i]))
		var fresh := clampf((_clock-_born[i])/0.06,0.0,1.0)
		var thin := clampf(r/(2.5*scale),0.0,1.0)
		_multi.set_instance_custom_data(i,Color(fresh*thin*0.92,LENS*r/scale*1.6,_seed[i],0.0))
