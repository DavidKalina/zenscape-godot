extends SceneTree
## The manual landing's slide (scripts/manual_landing.gd), measured on a
## wide flat field headless: from a touch at each speed, how far on each way
## of stopping goes (m along the touch's way), how long (s), the peak slip
## (degrees) and how far it ends off its line (m); round 3 adds a slide
## steered against itself (counter-steered) after its swing. docs/design/manual-landing.md keeps the table.
##   godot --headless --path . -s tools/landing_slide_probe.gd

const ManualLanding = preload("res://scripts/manual_landing.gd")
const SkyPlane = preload("res://scripts/sky_plane.gd")
const DT := 1.0/60.0
const WAYS := {
	"coast":{},
	"straight brake":{"brake":1.0},
	"drift (steer)":{"turn":1.0},
	"drift (lean + steer)":{"turn":1.0,"lean":1.0},
	"brake slide (brake + steer)":{"brake":1.0,"turn":1.0},
	"power-slide (+ throttle)":{"brake":1.0,"turn":1.0,"boost":1.0},
	"power-slide, blip 0.3 s":{"brake":1.0,"turn":1.0,"boost":1.0,"blip":0.3},
	"power-slide + lean (tighter)":{"brake":1.0,"turn":1.0,"boost":1.0,"lean":1.0},
	"power-slide, blip, then counter-steered":{"brake":1.0,"turn":1.0,"boost":1.0,"blip":0.3,"then":-1.0,"then_at":0.4},
	"drift (lean + steer), then counter-steered":{"turn":1.0,"lean":1.0,"then":-1.0,"then_at":0.4},
}

static func flat(p: Vector2) -> float:
	return 0.0 if absf(p.x) < 400.0 and p.y < 0.0 and p.y > -800.0 else NAN

static func solid(p: Vector3) -> Variant:
	return Vector2(0.0,-10.0) if not is_nan(flat(Vector2(p.x,p.z))) else null

func _initialize() -> void:
	print("| touch m/s | way | on m | time s | peak slip ° | off line m |")
	print("|---|---|---|---|---|---|")
	for speed: float in [8.0,14.0,22.0]:
		for way: String in WAYS.keys():
			var r := probe(speed,WAYS[way])
			print("| %.0f | %s | %.1f | %.1f | %.0f | %.1f |" % [speed,way,r.along,r.time,rad_to_deg(r.slip),r.off])
	quit(0)

## Down at `speed` (a firm touch, 0.3 m up, level), then `hold` held until
## it stops (`blip` s of its throttle only, if given; from `then_at` s on,
## the stick at `then`: against the slide, counter-steered).
static func probe(speed: float, hold: Dictionary) -> Dictionary:
	var plane := SkyPlane.new()
	plane.launch(Vector3(0.0,SkyPlane.SKIM+0.2,-5.0),0.0,speed,false)
	plane.speed = speed
	plane.pitch = -0.05
	var ml := ManualLanding.new()
	ml.begin(plane)
	var t := 0.0
	while ml.flying() and t < 3.0:
		ml.step(DT,{},solid,flat)
		t += DT
	var from: Vector3 = ml.touched_at()
	var on := 0.0
	while ml.phase == ManualLanding.ROLL and on < 30.0:
		var input := hold.duplicate()
		if hold.has("blip") and on > float(hold.blip): input.boost = 0.0
		if hold.has("then") and on > float(hold.then_at): input.turn = float(hold.then)
		ml.step(DT,input,solid,flat)
		on += DT
	var p: Vector3 = ml.plane.position
	return {"along":from.z-p.z,"time":on,"slip":float(ml.stats.peak_slip),"off":absf(p.x-from.x)}
