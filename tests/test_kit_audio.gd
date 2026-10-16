extends SceneTree
## The kit isle's sound (scripts/kit_isle/kit_audio.gd, docs/design/
## sound-round1.md) on the aqueduct isle, headless. Headless has no audio
## device, so what is checked is the mix's intent, not what is heard:
##   - the buses stand (SFX, SFX Air, Ambience, Ambience Far, Music, beside
##     Genesis);
##   - standing on foot the air and engine are silent and the breeze blows;
##     the feet read a surface the steps know, grass and worn earth on the turf;
##   - flying, the engine runs and the air rushes; boosting, both rise in
##     pitch and the rush in gain; on the knife edge the wires sing;
##   - the cloud sea's hush closes the low-pass over everything;
##   - the touch thumps; the body's moves (a jump, a twirl, the sail) play
##     their foley; parked after a flight, the engine ticks as it cools;
##   - round 3 (kit_audio_beasts.gd): the serpent (--serpent) is found and grinds and
##     hums beside its body, silent far off; the dragon is found, whumps
##     once a beat with its upstroke's rustle, and calls as its jaw opens.
##   godot --headless --path . --script tests/test_kit_audio.gd
const KitAudio = preload("res://scripts/kit_isle/kit_audio.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const DT := 1.0/60.0
var failures := 0
var study: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(120.0).timeout.connect(func() -> void: push_error("kit audio test timed out"); quit(2))
	# The serpent is out of the game's sky unless --serpent asks for it.
	LaunchArgs.set_override(["--serpent"])
	study = load("res://studies/aqueduct_isle.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.isle_up: await process_frame
	await physics_frame
	var audio: KitAudio = study.audio
	check(audio != null and audio.is_inside_tree(),"The isle has its sound")
	for bus: StringName in [KitAudio.SFX,KitAudio.AIR,KitAudio.AMBIENCE,KitAudio.FAR,KitAudio.MUSIC,&"Genesis"]:
		check(AudioServer.get_bus_index(bus) >= 0,"Bus %s stands" % bus)
	for i in range(30): audio._process(DT)
	check(audio.rush.goal == 0.0 and audio.engine.goal == 0.0,"On foot, standing: no rush, no engine")
	check(audio.breeze.goal > 0.0,"On foot the breeze blows (%.3f)" % audio.breeze.goal)
	check(str(study._surface()) in ["stone","earth","grass","wood","water"],"The feet read a surface: %s" % study._surface())
	var found := {}
	var circle: Vector3 = study.isle_circle()
	for i in range(-10,11):
		for j in range(-10,11):
			var p := Vector2(circle.x+i*circle.z/10.0,circle.y+j*circle.z/10.0)
			var turf: Variant = study.life.ground_at(p)
			if turf == null: continue
			var kind: String = audio._read_surface(Vector3(p.x,float(turf),p.y))
			found[kind] = int(found.get(kind,0))+1
	check(found.has("grass") and found.has("earth"),"Over the isle's turf the feet find grass and worn earth (%s)" % found)
	# Round 2: the living layer (scripts/kit_isle/kit_audio_life.gd).
	var life = audio.life
	var dawn: Vector2 = life.activity(0.3)
	check(dawn.x > life.activity(0.5).x and life.activity(0.95) == Vector2.ZERO and life.activity(0.72).y > life.activity(0.5).y,"Birds sing most at dawn, less at midday, a dusk chorus, none at night")
	var listener: Vector3 = study.camera.global_position
	study._celestial.phase = 0.3
	var songs := int(audio.played.get("song",0))
	for i in range(600): life.step(DT,listener,1.0,1.0,0.0)
	check(int(audio.played.get("song",0))-songs >= 3 and life.chorus.goal > 0.0,"At dawn the songs come often (%d in 10 s) over the chorus (%.3f)" % [int(audio.played.get("song",0))-songs,life.chorus.goal])
	study._celestial.phase = 0.95
	for i in range(300): life.step(DT,listener,0.0,1.0,0.0)
	check(life.chorus.goal == 0.0 and int(audio.played.get("cricket",0)) > 0,"At night the chorus is gone and the crickets chirp (%d)" % int(audio.played.get("cricket",0)))
	study._celestial.phase = 0.4
	check(life.falls.size() > 0,"The falls are found (%d)" % life.falls.size())
	if life.falls.size() > 0:
		var fall: MeshInstance3D = life.falls[0][0]
		life._falls((fall.global_transform*fall.custom_aabb).get_center()+Vector3(4,0,0),1.0)
		var loud := 0.0
		for bed in life._roars+life._spills: loud = maxf(loud,bed.goal)
		check(loud > 0.0,"Beside a fall it roars (%.3f)" % loud)
	audio.body({"swing":false})
	check(audio.played.has("whip"),"Let go, the rope whips")
	# Round 3: the beasts (scripts/kit_isle/kit_audio_beasts.gd).
	var beasts = audio.beasts
	check(beasts != null and beasts.serpents.size() > 0,"With --serpent the serpent is found (%d)" % (beasts.serpents.size() if beasts != null else 0))
	if beasts != null and beasts.serpents.size() > 0:
		var serpent: Node3D = beasts.serpents[0]
		var ring: Vector3 = serpent.global_transform*serpent.rings()[20]
		for i in range(30): beasts.step(DT,ring+Vector3.UP*6.0)
		var sb: Dictionary = beasts._s[serpent.get_instance_id()]
		check(sb.scales.goal > 0.0 and sb.hum.goal > 0.0 and (sb.scales.player as Node3D).global_position.distance_to(ring) < 8.0,"Beside the serpent's body its scales grind (%.3f) and its runes hum (%.3f) right there" % [sb.scales.goal,sb.hum.goal])
		beasts.step(DT,ring+Vector3.UP*2000.0)
		check(sb.scales.goal == 0.0,"Far from it, silence")
	study._build_sky_dragon()
	var dragon: Node3D = study.dragon
	check(beasts != null and beasts.dragons.has(dragon),"The dragon is found")
	if dragon != null and beasts != null:
		dragon.model.visible = true
		dragon.state = "roaming"
		dragon.flap_w = 1.0
		var near: Vector3 = dragon.global_position+Vector3(0,0,120)
		var beats := int(beasts.played.get("dragon_beat",0))
		for i in range(int(7.0/DT)):
			dragon.phase = fposmod(i*DT*0.3+0.013,1.0)
			beasts.step(DT,near)
		check(int(beasts.played.get("dragon_beat",0))-beats == 2 and int(beasts.played.get("dragon_up",0)) >= 2,"Two wingbeats in 7 s of its beat, each with its upstroke (%s)" % beasts.played)
		beasts._call_wait = 0.0
		dragon._roar_t = 0.2
		beasts.step(DT,near)
		dragon._roar_t = 0.5
		beasts.step(DT,near)
		check(beasts.played.has("dragon_call"),"As its jaw opens on a roar, it calls")
		dragon._roar_t = -1.0
	study.board()
	for i in range(60):
		study.fly_step(DT,{})
		audio._process(DT)
	var cruise := {"rush":audio.rush.goal,"pitch":audio.engine.pitch_goal,"engine":audio.engine.goal}
	check(cruise.engine > 0.0 and cruise.rush > 0.0,"Flying, the engine runs (%.3f) and the air rushes (%.3f)" % [cruise.engine,cruise.rush])
	for i in range(90):
		study.fly_step(DT,{"boost":1.0})
		audio._process(DT)
	check(audio.engine.pitch_goal > cruise.pitch and audio.rush.goal > cruise.rush,"Boosting, the engine climbs (%.2f > %.2f) and the rush swells (%.3f > %.3f)" % [audio.engine.pitch_goal,cruise.pitch,audio.rush.goal,cruise.rush])
	for i in range(40):
		study.fly_step(DT,{"lean":1.0})
		audio._process(DT)
	check(audio.wires.goal > 0.0,"On the knife edge the wires sing (%.3f)" % audio.wires.goal)
	var deep := Vector3(0.0,float(study.isle_top())-80.0,0.0)
	for i in range(60): audio._hush(DT*4.0,deep)
	var cut: float = (audio._hush_lpf[0] as AudioEffectLowPassFilter).cutoff_hz
	check(audio.muffle > 0.9 and cut < 2000.0,"Deep in the cloud sea it's hushed (muffle %.2f, low-pass %.0f Hz)" % [audio.muffle,cut])
	var played := int(audio.played.get("thump",0))
	study._thump(1.0)
	check(int(audio.played.get("thump",0)) > played,"The touch thumps")
	audio.body({"jumped":1})
	audio.body({"twirl":true})
	audio.body({"sail":true})
	check(audio.played.has("cloth") and audio.played.has("swish") and audio.played.has("pop"),"A jump rustles, a twirl swishes, the sail pops (%s)" % audio.played)
	study.leave_plane(study.start)
	for i in range(40): audio._process(0.25)
	check(bool(study.parked) and int(audio.played.get("tick",0)) > 0,"Parked after a flight, the engine ticks as it cools (%d)" % int(audio.played.get("tick",0)))
	print("PASS: kit audio" if failures == 0 else "FAIL: kit audio (%d)" % failures)
	# Quit as the game does (KitAudio.quit), so no playback leaks at exit.
	KitAudio.quit(self,1 if failures > 0 else 0)
