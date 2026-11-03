extends CanvasLayer
## The wind field's map (--wind-map; scripts/endless/wind_field.gd): the
## whole world from above in the top-right corner, north up, the land's
## relief under the wind's strength now (blue still, through green and
## yellow, to red at the peak), the drifting patches' rims, the plane a white
## dot, and a line of the hour, the day's temper and the wind here.

const WindField = preload("res://scripts/endless/wind_field.gd")

## The map's side on screen (px) and how often it repaints (s).
const SIDE := 360
const EVERY := 1.0

var field: WindField
var _relief := PackedFloat32Array()
var _image: Image
var _texture: ImageTexture
var _rect: TextureRect
var _label: Label
var _wait := 0.0
var _shaded := false

func setup(f: WindField) -> void:
	field = f
	layer = 50
	var n := maxi(field.n,2)
	_relief.resize(n*n)
	_image = Image.create(n,n,false,Image.FORMAT_RGB8)
	_texture = ImageTexture.create_from_image(_image)
	_rect = TextureRect.new()
	_rect.texture = _texture
	_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_rect.size = Vector2(SIDE,SIDE)
	_rect.anchor_left = 1.0
	_rect.anchor_right = 1.0
	_rect.position = Vector2(-SIDE-12,12)
	add_child(_rect)
	_label = Label.new()
	_label.anchor_left = 1.0
	_label.anchor_right = 1.0
	_label.position = Vector2(-SIDE-12,SIDE+16)
	_label.add_theme_color_override("font_outline_color",Color.BLACK)
	_label.add_theme_constant_override("outline_size",4)
	add_child(_label)

## The land's shading from the north-west, from the bake's heights.
func _shade() -> void:
	var n := field.n
	for j in n:
		for i in n:
			var k := j*n+i
			var dx := field.heights[j*n+mini(i+1,n-1)]-field.heights[j*n+maxi(i-1,0)]
			var dz := field.heights[mini(j+1,n-1)*n+i]-field.heights[maxi(j-1,0)*n+i]
			_relief[k] = 0.75 if field.water[k] == 1 else clampf(0.6-(dx+dz)*0.006,0.15,1.0)

## Strength (zs_wind_strength's scale) to the map's colour.
static func ramp(s: float) -> Color:
	var t := clampf(s/(WindField.PEAK*1.1),0.0,1.0)
	var keys := [Color(0.15,0.25,0.75),Color(0.1,0.7,0.6),Color(0.45,0.85,0.2),Color(1.0,0.85,0.15),Color(0.95,0.2,0.1)]
	var x := t*(keys.size()-1)
	var i := mini(int(x),keys.size()-2)
	return (keys[i] as Color).lerp(keys[i+1],x-i)

func step(delta: float, eye: Vector3) -> void:
	_wait -= delta
	if _wait > 0.0: return
	_wait = EVERY
	paint(eye)

func paint(eye: Vector3) -> void:
	var n := field.n
	if n < 2 or not field.baked: return
	if not _shaded:
		_shade()
		_shaded = true
	var c := WindField.CELL
	for j in n:
		var z := field.origin.y+j*c
		for i in n:
			var k := j*n+i
			var x := field.origin.x+i*c
			var s := field.wind_at(x,z)
			var col := ramp(s)
			if field.water[k] == 1: col = col.lerp(Color(0.05,0.08,0.2),0.45)
			col = col*(0.45+0.55*_relief[k])
			_image.set_pixel(i,j,Color(col.r,col.g,col.b))
	# The plane: a white dot with a dark ring.
	var pi := int((eye.x-field.origin.x)/c)
	var pj := int((eye.z-field.origin.y)/c)
	for dj in range(-2,3):
		for di in range(-2,3):
			var u := pi+di
			var v := pj+dj
			if u < 0 or v < 0 or u >= n or v >= n: continue
			_image.set_pixel(u,v,Color.WHITE if absi(di) < 2 and absi(dj) < 2 else Color.BLACK)
	_texture.update(_image)
	_label.text = "wind %.2f here  %02d:%02d  day %d %s  heading %d°  x%.2f" % [field.wind_at(eye.x,eye.z),int(field.hour),int(fposmod(field.hour,1.0)*60.0),field.day,field.temper_name(),int(fposmod(rad_to_deg(field.heading),360.0)),field.now]
