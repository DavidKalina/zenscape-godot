extends RefCounted
## A playable invitation assembled from ordinary terrain and editable props.
## The spare log retains its authored pose when the player moves it to water.
static func populate(data: NativeTerrainData) -> int:
	data.begin_stroke()
	for i in range(data.points.size()):
		data.heights[i] = -0.8 if absf(data.points[i].x)<0.9 else 0.0
	data.streams = [{"pts":[{"x":0.0,"z":-14.0,"h":-0.45},{"x":0.0,"z":14.0,"h":-0.45}],"width":0.65,"depth":0.2,"surface":0.05,"capHead":false,"capTail":false}]
	data.grass.fill(0.65)
	for z in range(NativeTerrainData.MEADOW_CELLS):
		for x in range(NativeTerrainData.MEADOW_CELLS):
			var p := data.meadow_position(x,z)+Vector2.ONE*0.25
			var edge := smoothstep(3.2,6.0,Vector2(p.x*0.65,p.y).length())
			var bank := smoothstep(1.25,1.9,absf(p.x))
			var index := z*NativeTerrainData.MEADOW_CELLS+x
			data.meadow[index] = edge*bank*0.12
			data.blades[index] = edge*bank*0.24
	data.place("shrub",Vector2(3.5,1),0,1.2)
	for p in [Vector2(5,3),Vector2(6,-4),Vector2(-7,3),Vector2(-6,-4)]:
		data.place("broadleaf",p,0,2.1)
	for p in [Vector2(3,-2),Vector2(4,-2.5),Vector2(-3,2),Vector2(-4,2.5)]:
		data.place("daisy_flower",p,0,0.9)
	for p in [Vector2(1.5,4),Vector2(-1.6,-4),Vector2(1.7,-3)]:
		data.place("bank_grass",p,0,0.8)
	var log_id := data.place("log",Vector2(-5,0),0,4.0,NativeObjectPose.make(Basis.from_scale(Vector3.ONE*4),0.45))
	data.end_stroke()
	return log_id
