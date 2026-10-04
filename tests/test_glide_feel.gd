extends SceneTree
## The glide's feel round the chase camera: the camera leans a share of the
## glider's bank, capped, and settles level flying straight
## (scripts/glide_camera.gd); its view widens with speed, capped, kicks open
## entering a jet and narrows at the float; the vapour (scripts/
## glide_vapour.gd) is nothing in open air and shows fast past rock, off
## the nearer wing; the glider's wingtips trail it (scripts/
## glider_figure.gd); nothing goes NaN at a standstill.
const SkyGlide = preload("res://scripts/sky_glide.gd")
const GlideCamera = preload("res://scripts/glide_camera.gd")
const GlideVapour = preload("res://scripts/glide_vapour.gd")
const GliderFigure = preload("res://scripts/glider_figure.gd")
const DT := 1.0/60.0
var failures := 0

func _initialize() -> void:
	_roll()
	_fov()
	_jet_kick()
	_vapour()
	_wingtips()
	_standstill()
	print("PASS: glide feel" if failures == 0 else "FAIL: glide feel")
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func open_air(_p: Vector3) -> Variant:
	return null

func flying() -> SkyGlide:
	var glide := SkyGlide.new()
	glide.launch(Vector3(0.0,20.0,0.0),0.0,6.0,false)
	return glide

func run(glide: SkyGlide, cam: GlideCamera, seconds: float, input: Dictionary, air := Callable()) -> void:
	for i in range(int(seconds/DT)):
		glide.step(DT,input,open_air,air)
		cam.step(DT,glide,float(input.get("dive",0.0)))

func _roll() -> void:
	var glide := flying()
	var cam := GlideCamera.new()
	cam.reset(glide,glide.position)
	run(glide,cam,2.0,{})
	check(absf(cam.roll) < 0.01,"Flying straight it is level (%.3f rad)" % cam.roll)
	var most := 0.0
	for i in range(int(4.0/DT)):
		glide.step(DT,{"turn":1.0},open_air)
		cam.step(DT,glide,0.0)
		most = maxf(most,absf(cam.roll))
		if i == int(4.0/DT)-1:
			check(signf(cam.roll) == -signf(glide.bank) and absf(cam.roll) > 0.08,"It leans with the bank (roll %.2f, bank %.2f)" % [cam.roll,glide.bank])
			check(absf(cam.roll) < absf(glide.bank)*0.5,"Only a share of it (%.2f of %.2f)" % [cam.roll,glide.bank])
	check(most <= GlideCamera.ROLL_MAX+0.001,"Never past %.0f degrees (most %.1f)" % [rad_to_deg(GlideCamera.ROLL_MAX),rad_to_deg(most)])
	run(glide,cam,1.0,{"turn":-1.0})
	check(cam.roll > 0.05,"Turned the other way it leans the other way (%.2f rad)" % cam.roll)
	run(glide,cam,4.0,{})
	check(absf(cam.roll) < 0.01,"Then it settles level (%.3f rad)" % cam.roll)
	# Even at the glide's hardest bank it stays inside the cap.
	glide.bank = SkyGlide.BANK_MAX
	for i in range(200): cam.step(DT,glide,0.0)
	check(absf(cam.roll) <= GlideCamera.ROLL_MAX,"At the hardest bank still capped (%.1f deg)" % rad_to_deg(absf(cam.roll)))

func _fov() -> void:
	# High up, so the dive never reaches the cloud cushion.
	var glide := flying()
	glide.position.y = 150.0
	var cam := GlideCamera.new()
	cam.reset(glide,glide.position)
	run(glide,cam,3.0,{})
	var cruise := cam.fov
	check(absf(cruise-GlideCamera.FOV) < 1.0,"At a cruise the view is the chase's own (%.1f deg)" % cruise)
	var widest := cruise
	var rising := true
	var last := cruise
	for i in range(int(3.5/DT)):
		glide.step(DT,{"dive":1.0},open_air)
		cam.step(DT,glide,1.0)
		widest = maxf(widest,cam.fov)
		if i > 30 and cam.fov < last-0.01: rising = false
		last = cam.fov
	check(glide.speed > 20.0 and widest > cruise+4.0,"In a dive it widens with speed (%.1f deg at %.0f m/s)" % [widest,glide.speed])
	check(rising,"Eased, steadily opening")
	check(widest <= GlideCamera.FOV+GlideCamera.FOV_FAST+0.01,"Capped (%.1f deg)" % widest)
	# At the top speed, held there, it is still capped.
	glide.speed = SkyGlide.MAX
	glide.velocity = glide.forward()*SkyGlide.MAX*2.0
	for i in range(300): cam.step(DT,glide,1.0)
	check(cam.fov <= GlideCamera.FOV+GlideCamera.FOV_FAST+0.01 and cam.fov > GlideCamera.FOV+GlideCamera.FOV_FAST-0.5,"At full speed it rests at the cap (%.1f deg)" % cam.fov)
	var dive_eye := cam.eye.distance_to(glide.position)
	check(dive_eye < 3.0,"And still pulls in close in the dive (%.1f m)" % dive_eye)
	# The float narrows it.
	glide.velocity = glide.forward()*SkyGlide.CRUISE
	glide.hang = 1.0
	for i in range(300): cam.step(DT,glide,0.0)
	check(cam.fov < GlideCamera.FOV-2.0,"At the float it narrows a touch (%.1f deg)" % cam.fov)

func _jet_kick() -> void:
	var glide := flying()
	var cam := GlideCamera.new()
	cam.reset(glide,glide.position)
	run(glide,cam,2.0,{})
	var before := cam.fov
	# A jet the glide flies into at z < -10, its speed held still so only
	# the kick moves the view.
	glide.velocity = glide.forward()*SkyGlide.CRUISE
	var peak := before
	for i in range(int(4.0/DT)):
		glide.in_jet = clampf(float(i)/20.0,0.0,1.0)
		cam.step(DT,glide,0.0)
		peak = maxf(peak,cam.fov)
	check(peak > before+2.0,"Entering a jet the view kicks open (%.1f from %.1f deg)" % [peak,before])
	check(cam.fov < peak-1.5,"Then settles back while riding it (%.1f deg)" % cam.fov)

func wall(p: Vector3) -> Variant:
	# A cliff face at x > 3 standing from -100 to 100: an island's side.
	return Vector2(100.0,-100.0) if p.x > 3.0 else null

func _vapour() -> void:
	var glide := flying()
	var vapour := GlideVapour.new()
	glide.speed = 18.0
	for i in range(int(2.0/DT)):
		glide.step(DT,{"dive":0.3},open_air)
		vapour.step(DT,glide,open_air)
	check(vapour.near == 0.0,"In open air there is no vapour (%.3f)" % vapour.near)
	for i in range(int(2.0/DT)):
		glide.step(DT,{"dive":0.3},open_air)
		vapour.step(DT,glide,wall)
	check(vapour.near > 0.3,"Fast past a cliff the vapour shows (%.2f at %.0f m/s)" % [vapour.near,glide.velocity.length()])
	check(vapour.side > 0.3,"Off the wing nearer the rock (side %.2f)" % vapour.side)
	var slow := flying()
	var calm := GlideVapour.new()
	for i in range(int(2.0/DT)):
		slow.step(DT,{},open_air)
		calm.step(DT,slow,wall)
	check(calm.near < vapour.near*0.5,"Drifting slowly past, barely a breath (%.2f)" % calm.near)
	for i in range(int(0.3/DT)): vapour.step(DT,glide,open_air)
	var after := vapour.near
	check(after > 0.05,"Clear of the rock it lingers a moment (%.2f)" % after)
	for i in range(int(5.0/DT)): vapour.step(DT,glide,open_air)
	check(vapour.near < 0.01,"Then it is gone (%.3f)" % vapour.near)

func _wingtips() -> void:
	var glide := flying()
	var figure: Node3D = GliderFigure.new()
	root.add_child(figure)
	figure.reset(glide)
	for i in range(30):
		glide.step(DT,{},open_air)
		figure.update(DT,glide,0.0,open_air,false)
	var mist: MeshInstance3D = figure._vapour
	check(not mist.visible,"No vapour off the wingtips in open air")
	for i in range(30):
		glide.step(DT,{},open_air)
		figure.update(DT,glide,0.0,open_air,false,0.8,1.0)
	check(mist.visible,"Close to rock it trails off the wingtips")
	var right: Vector3 = figure._tip(1)
	var left: Vector3 = figure._tip(0)
	check((right-left).dot(glide.forward().cross(Vector3.UP)) > 1.5,"From both tips, a wingspan apart (%.2f m)" % right.distance_to(left))
	check(figure._vapour_strength[GliderFigure.VAPOUR] > figure._vapour_strength[0],"Stronger off the nearer wing")
	figure.free()

func _standstill() -> void:
	var glide := SkyGlide.new()
	glide.launch(Vector3(0.0,20.0,0.0),0.0,0.0,false)
	glide.velocity = Vector3.ZERO
	glide.speed = 0.0
	var cam := GlideCamera.new()
	cam.reset(glide,glide.position)
	var vapour := GlideVapour.new()
	cam.step(DT,glide,0.0)
	vapour.step(DT,glide,wall)
	vapour.step(0.0,glide,wall)
	cam.step(0.0,glide,0.0)
	var ok := not (is_nan(cam.fov) or is_nan(cam.roll) or is_nan(vapour.near) or is_nan(vapour.side) or is_nan(cam.eye.x) or is_nan(cam.look.y))
	check(ok,"At a standstill nothing goes NaN (fov %.1f, roll %.2f, near %.2f)" % [cam.fov,cam.roll,vapour.near])
	# Pointing straight down, the vapour's ring still has a side.
	glide.pitch = -PI*0.5
	glide.velocity = Vector3.DOWN*10.0
	vapour.step(DT,glide,wall)
	check(not is_nan(vapour.near),"Straight down, no NaN either")
