extends "res://tools/harness/drive.gd"
## Stills of endless flight (seed 1) from held views, plane hidden, no HUD, for
## tools/look_measure.py (docs/art/look-breakdown.md). --views=a,b (SPOTS below),
## --out=DIR --tag=SUFFIX --hold=300; scene args (--hour=12.5) after --scene-args.
##   python tools/drive.py tools/harness/look_views.gd --rendered -- --out=DIR --scene-args --no-title
const Field = preload("res://scripts/endless/land_field.gd")
# name: [eye x,z,above, look x,z,above]
const SPOTS := {
	"meadow_low": [720,500,5, 720,380,3],
	"hills": [120,-40,45, 120,-200,15],
	"rock": [40,-90,40, 40,-200,20],
	"coast": [0,40,25, 0,200,-10],
	"river": [0,40,18, 0,-60,0],
	"cruise": [720,520,45, 720,380,10],
	"high": [720,560,260, 720,400,0],
}
func drive() -> void:
	await open("studies/endless_flight.tscn")
	study.walk_ready = false
	var cam: Camera3D = study.camera
	var field: RefCounted = study.field
	if study.plane_figure != null: study.plane_figure.visible = false
	var names: PackedStringArray = str(arg("views","meadow_low,hills,rock,coast,river,cruise,high")).split(",")
	for n in names:
		var v: Array = SPOTS[n]
		var e := Vector3(v[0],field.height(v[0],v[1])+v[2],v[1])
		var l := Vector3(v[3],field.height(v[3],v[4])+v[5],v[4])
		cam.global_position = e
		cam.look_at(l,Vector3.UP)
		await _hold(arg_int("hold",300))
		await shot("%s/%s%s.png" % [arg("out","scratch/lb/shots"),n,arg("tag","")],false,Vector2i(1440,900))
		await frames(2)
	finish()
func _hold(n: int) -> void:
	var cam: Camera3D = study.camera
	for i in n:
		var eye := cam.global_position
		var fwd := -cam.global_basis.z
		study.land.step(eye)
		study.arches.step(eye)
		if study.grass != null: study.grass.step(eye,fwd)
		if study.look != null: study.look.step(1.0/60.0,eye,fwd,cam)
		if study.react == null: study.sea.position = Vector3(snappedf(eye.x,64.0),Field.SEA_Y,snappedf(eye.z,64.0))
		await frames(1)
