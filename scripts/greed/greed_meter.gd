extends Node
## The isle's anger on the greed run (docs/design/greed-run/spec-greed-run.md,
## studies/crag_reach_greed.gd): every loot piece he bags for the first time
## adds its worth (scripts/home/vault_host.gd VALUES) to `value`. A piece
## ripped out and bagged again counts once. Past `brood_at` the brood wake,
## past `olmec_at` the Olmec comes (`woke` "brood" / "olmec"; the host's
## `greed_woke(what)` if it has one). Thresholds are by value, knobs
## --greed-brood=N / --greed-olmec=N.
##
## The cue, felt rising: each piece bagged, the isle groans (louder the
## angrier), the camera shudders a moment and a line says how it stirs; the
## light drains toward a dim, cold, hard grade as anger nears the Olmec's
## mark (the environment's adjustment, nothing else writes it); a small
## line in the corner (`text()`) gives the number.
signal woke(what: String)

const VaultHost = preload("res://scripts/home/vault_host.gd")
const BodySpawner = preload("res://scripts/enemies/body_spawner.gd")
const EnemyYard = preload("res://studies/enemy_yard.gd")

const BROOD_AT := 50
const OLMEC_AT := 200
## The grade at full anger (the Olmec's mark): saturation, brightness,
## contrast; eased toward at GRADE_EASE per s.
const GRADE := Vector3(0.5,0.82,1.12)
const GRADE_EASE := 0.6
## The groan's volume (dB) calm and at full anger; at a threshold, louder.
const GROAN_DB := Vector2(-14.0,-2.0)
const WAKE_DB := 4.0
## A bag's shudder: how long (s) and how hard (m of camera shake) at full anger.
const SHAKE_TIME := 0.9
const SHAKE := 0.18

var host: Node3D
var brood_at := BROOD_AT
var olmec_at := OLMEC_AT
var value := 0
var count := 0
var counted := {}
## Loot ids whose bagging wakes both at once, whatever the value (the
## host's `greed_wake_on()`: the heist's main treasure); [] none.
var wake_on: Array = []
## Its name for the corner line ("dragon egg").
var wake_name := ""
var brood_woken := false
var olmec_woken := false
## The grade's anger now (eases toward `anger()`).
var shown := 0.0
var _shake_t := -1.0
var _shake_k := 0.0
var _groan: AudioStreamPlayer
var _env: Environment

func setup(h: Node3D) -> void:
	host = h
	name = "Greed"
	# The host's own marks (the heist's), else the crag's; the flags win.
	if host.has_method("greed_marks"):
		var m: Vector2i = host.call("greed_marks")
		brood_at = m.x
		olmec_at = m.y
	if host.has_method("greed_wake_on"):
		wake_on = host.call("greed_wake_on")
		for p: Dictionary in host.get("loot"):
			if str(p.get("id","")) in wake_on: wake_name = str(VaultHost.NAMES.get(str(p.get("kind","")),"treasure"))
	for a: String in preload("res://scripts/launch_args.gd").user_args():
		if a.begins_with("--greed-brood="): brood_at = maxi(int(a.get_slice("=",1)),0)
		elif a.begins_with("--greed-olmec="): olmec_at = maxi(int(a.get_slice("=",1)),0)
	_groan = AudioStreamPlayer.new()
	_groan.stream = EnemyYard._synth(BodySpawner.VOICES["isle_groan"])
	add_child(_groan)
	_env = host.get("_environment")
	print("greed: brood at %d, Olmec at %d (value)" % [brood_at,olmec_at])

## 0 calm .. 1 at the Olmec's mark.
func anger() -> float:
	return clampf(float(value)/maxf(float(olmec_at),1.0),0.0,1.0)

## Each frame, from the host's tick (after its camera is placed).
func step(delta: float) -> void:
	var bag: Node3D = host.get("bag")
	if bag != null:
		for p: Dictionary in bag.items:
			var id := str(p.get("id",""))
			if id == "" or counted.has(id): continue
			counted[id] = true
			# Its kg tag stood over the empty spot once it's gone.
			var spot: Node3D = p.get("spot")
			if spot != null and spot.has_node("Kg"): (spot.get_node("Kg") as Node3D).visible = false
			_add(int(VaultHost.VALUES.get(str(p.get("kind","")),0)),str(p.get("kind","")),id in wake_on)
	shown = move_toward(shown,anger(),GRADE_EASE*delta)
	_grade()
	if _shake_t >= 0.0:
		_shake_t += delta
		var k := 1.0-_shake_t/SHAKE_TIME
		if k <= 0.0: _shake_t = -1.0
		else:
			var cam: Camera3D = host.get("camera")
			if cam != null:
				var t := Time.get_ticks_msec()/1000.0
				cam.position += Vector3(sin(t*43.0),sin(t*37.0+1.0),sin(t*31.0+2.0))*SHAKE*_shake_k*k*k

func _add(worth: int, kind: String, wakes_all := false) -> void:
	value += worth
	count += 1
	var a := anger()
	var wakes: Array[String] = []
	if not brood_woken and (value >= brood_at or wakes_all):
		brood_woken = true
		wakes.append("brood")
	if not olmec_woken and (value >= olmec_at or wakes_all):
		olmec_woken = true
		wakes.append("olmec")
	_groan.volume_db = lerpf(GROAN_DB.x,GROAN_DB.y,a)+(WAKE_DB if not wakes.is_empty() else 0.0)
	_groan.pitch_scale = lerpf(1.1,0.75,a)
	_groan.play()
	_shake_t = 0.0
	_shake_k = lerpf(0.25,1.0,a)+(0.6 if not wakes.is_empty() else 0.0)
	var line := _line(a)
	if "olmec" in wakes: line = "The isle groans. Something old is waking."
	elif "brood" in wakes: line = "Something stirs in the turf..."
	if host.has_method("_say"): host.call("_say","%s   (greed %d)" % [line,value],3.0)
	print("greed: +%d %s -> %d (%d piece(s), anger %.2f)%s" % [worth,kind,value,count,a,(" WAKE %s" % ",".join(wakes)) if not wakes.is_empty() else ""])
	for w: String in wakes:
		woke.emit(w)
		if host.has_method("greed_woke"): host.call("greed_woke",w)

func _line(a: float) -> String:
	if a < 0.3: return "The ground shifts underfoot."
	if a < 0.6: return "The isle rumbles."
	if a < 0.9: return "The light goes thin. The isle is angry."
	return "The isle shakes with anger."

func _grade() -> void:
	if _env == null: return
	if shown <= 0.001:
		_env.adjustment_enabled = false
		return
	_env.adjustment_enabled = true
	_env.adjustment_saturation = lerpf(1.0,GRADE.x,shown)
	_env.adjustment_brightness = lerpf(1.0,GRADE.y,shown)
	_env.adjustment_contrast = lerpf(1.0,GRADE.z,shown)

## The corner line: greed and the next mark.
func text() -> String:
	var next := ""
	if not brood_woken and wake_name != "": next = "  ·  take the %s and the isle wakes" % wake_name
	elif not brood_woken: next = "  ·  the brood wake at %d" % brood_at
	elif not olmec_woken: next = "  ·  the brood are out  ·  something old wakes at %d" % olmec_at
	else: next = "  ·  the isle is awake"
	return "Greed %d%s" % [value,next]
