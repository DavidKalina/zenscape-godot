extends RefCounted
## Independent rows of the original desert rock/salt mask. CPU images only.
const Plate = preload("res://scripts/plate.gd")
## Desert recipes sit on the old 28 m square, so the mask spans that square
## (HALF each way), SIZE texels a side of TEXEL metres: 128, as it always
## was. The terrain shader reads it over the same extent
## (desert_geology_half, shaders/terrain_geology.gdshaderinc).
const HALF := Plate.LEGACY_HALF
const TEXEL := 0.21875
const SIZE := roundi(HALF*2.0/TEXEL)
static func build(genome: Dictionary, first := 0, last := SIZE) -> Image:
	var image := Image.create(SIZE,last-first,false,Image.FORMAT_RGBA8)
	for z in range(first,last):
		for x in range(SIZE):
			var field: Vector3 = preload("res://scripts/desert_landscape.gd").field(genome,Vector2(-HALF+(x+0.5)*HALF*2.0/float(SIZE),-HALF+(z+0.5)*HALF*2.0/float(SIZE)))
			image.set_pixel(x,z-first,Color(field.y,field.z,0,1))
	return image
