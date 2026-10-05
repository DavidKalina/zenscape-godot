extends RefCounted
## Independent rows of the original desert rock/salt mask. CPU images only.
const Plate := preload("res://scripts/plate.gd")
const SIZE := 128
static func build(genome: Dictionary, first := 0, last := SIZE) -> Image:
	var image := Image.create(SIZE,last-first,false,Image.FORMAT_RGBA8)
	for z in range(first,last):
		for x in range(SIZE):
			var field: Vector3 = preload("res://scripts/desert_landscape.gd").field(genome,Vector2(-Plate.HALF+(x+0.5)*Plate.SIZE/128.0,-Plate.HALF+(z+0.5)*Plate.SIZE/128.0))
			image.set_pixel(x,z-first,Color(field.y,field.z,0,1))
	return image
