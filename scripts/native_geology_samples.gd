extends RefCounted
## Independent rows of the original desert rock/salt mask. CPU images only.
const Plate = preload("res://scripts/plate.gd")
## Texel size (m): 128 texels over the 28 m plate. The mask spans the plate,
## SIZE texels a side.
const TEXEL := 0.21875
const SIZE := roundi(Plate.SIZE/TEXEL)
static func build(genome: Dictionary, first := 0, last := SIZE) -> Image:
	var image := Image.create(SIZE,last-first,false,Image.FORMAT_RGBA8)
	for z in range(first,last):
		for x in range(SIZE):
			var field: Vector3 = preload("res://scripts/desert_landscape.gd").field(genome,Vector2(-Plate.HALF+(x+0.5)*Plate.SIZE/float(SIZE),-Plate.HALF+(z+0.5)*Plate.SIZE/float(SIZE)))
			image.set_pixel(x,z-first,Color(field.y,field.z,0,1))
	return image
