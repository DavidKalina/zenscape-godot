extends RefCounted
## What the scene picker (scripts/scene_picker.gd) offers: one entry per row,
## in the order shown, each group a column on the card. The run-*.command
## launchers in the repo root are the catalogue this follows; an entry's args
## are the ones after `--` in its launcher (scripts/launch_args.gd adds
## `--no-title` to every one but those marked `own_title`, which open on the
## scene's own title). To add an entry, add a line here
## (docs/design/scene-picker.md); tests/test_scene_picker.gd checks each one's
## scene loads.

const ENTRIES: Array[Dictionary] = [
	# The old game: the plate builder behind its own title (Continue, Your
	# worlds, Build this world, a quiet plain), with every save. The default
	# front door is the aqueduct isle now (studies/zenscape.tscn).
	{"id":"builder","group":"The game","title":"Builder (old game)","scene":"res://studies/cozy_worlds.tscn","args":[],"own_title":true,
		"detail":"The old game on its own title: your worlds and saves, the hand out to build the plate."},
	{"id":"game_world","group":"The game","title":"Your world","scene":"res://studies/cozy_worlds.tscn","args":["--resume"],
		"detail":"The game straight in: your last world (or a new plain), the hand out to build."},
	{"id":"moments_world","group":"The game","title":"Moments in the sky","scene":"res://studies/cozy_worlds.tscn","args":["--moments","--skydive"],
		"detail":"The game with the moments set pieces, in the plane high over home. N: next set piece."},
	{"id":"manual_landing_world","group":"The game","title":"Landing by hand","scene":"res://studies/cozy_worlds.tscn","args":["--manual-landing","--skydive"],
		"detail":"The game with every landing flown by hand, in the plane over home. Put it down anywhere, brake or drift to a stop, F out; board to fly."},
	# Ruins.
	{"id":"aqueduct_isle","group":"Ruins","title":"Aqueduct isle","scene":"res://studies/aqueduct_isle.tscn","args":[],
		"detail":"The ruin platforming isle: grass, look presets (L), the plane on F. Find the lodestone, fly where the nose points; the halls follow."},
	{"id":"sky_dragon","group":"Ruins","title":"Sky dragon","scene":"res://studies/aqueduct_isle.tscn","args":["--dragon"],
		"detail":"An experiment: a great dragon rises from the clouds and roams the isles, now and then low over yours. V puts the camera on it."},
	{"id":"bell_spires","group":"Ruins","title":"Bell spires","scene":"res://studies/bell_spires_isle.tscn","args":[],
		"detail":"Rock spires joined by rope bridges, a belfry on the tallest. Look presets (L), the plane on F."},
	{"id":"cloister_tarn","group":"Ruins","title":"Cloister tarn","scene":"res://studies/cloister_tarn_isle.tscn","args":[],
		"detail":"A crater isle round a still tarn, a ruined cloister round its shore, satellites on rope bridges."},
	{"id":"drowned_nave","group":"Ruins","title":"Drowned nave","scene":"res://studies/drowned_nave_isle.tscn","args":[],
		"detail":"A flooded cathedral: a long nave of piers and arches half under a shallow basin, a rocky apse and rose gable, a causeway down the water."},
	{"id":"sundered_gorge","group":"Ruins","title":"Sundered gorge","scene":"res://studies/sundered_gorge_isle.tscn","args":[],
		"detail":"An isle split by a gorge: a snapped stone bridge, a rope bridge over the break, a lower crossing. F: the plane."},
	{"id":"colonnade_spine","group":"Ruins","title":"Colonnade spine","scene":"res://studies/colonnade_spine_isle.tscn","args":[],
		"detail":"A knife-edge ridge isle: a colonnade up its crest to a temple gate, a curling tail of fragments and rope bridges."},
	{"id":"broken_ring","group":"Ruins","title":"The Broken Ring","scene":"res://studies/broken_ring_isle.tscn","args":[],
		"detail":"Eight small isles in a loose spiral round a stone circle, climbing 21 m on rope bridges, floating stones and jumps."},
	{"id":"stair_clouds","group":"Ruins","title":"Stair to the Clouds","scene":"res://studies/stair_clouds_isle.tscn","args":[],
		"detail":"The tallest isle: a stepped mesa with a grand stair winding up it to a gate, a rope bridge to a hanging pinnacle."},
	{"id":"hollow_keel","group":"Ruins","title":"The Hollow Keel","scene":"res://studies/hollow_keel_isle.tscn","args":[],
		"detail":"A modest isle with a broken chapel and a hall hung under it: fly in under its edge and weave the columns, or walk the grand stairs down the shaft."},
	{"id":"sundered_hall","group":"Ruins","title":"The Sundered hall","scene":"res://studies/cozy_worlds.tscn","args":["--motif=sundered","--no-clusters","--skydive"],
		"detail":"The game with the long gothic hall 240-900 m out; in the plane, fly to it."},
	{"id":"hall_rise","group":"Ruins","title":"Hall rise","scene":"res://studies/hall_rise.tscn","args":[],
		"detail":"The Sundered hall rising out of the clouds in four whole chunks. R again, C camera, F plane."},
	{"id":"hall_chain","group":"Ruins","title":"Hall chain","scene":"res://studies/hall_chain.tscn","args":[],
		"detail":"Fly on through the Sundered hall and the next rises ahead, endlessly. N next hall, P autopilot, R again."},
	{"id":"ruin_kit","group":"Ruins","title":"Ruin kit gallery","scene":"res://studies/ruin_kit_gallery.tscn","args":[],
		"detail":"The ruin kit's three families on one plate, each piece intact and weathered."},
	# Flight greyboxes (studies/flight_study.tscn, docs/design/flight-study-handoff.md).
	{"id":"flight_packs","group":"Flight greyboxes","title":"Every pack","scene":"res://studies/flight_study.tscn","args":["--station=lines_bend"],
		"detail":"All the flight stations from the lines pack on. N: next station, L: next line."},
	{"id":"flight_lines","group":"Flight greyboxes","title":"Lines","scene":"res://studies/flight_study.tscn","args":["--pack=lines"],
		"detail":"Greybox halls with three token lines through the same stone. L: next line."},
	{"id":"flight_nature","group":"Flight greyboxes","title":"Nature","scene":"res://studies/flight_study.tscn","args":["--pack=nature"],
		"detail":"Wuhu-style flyover landforms, each laid out line first."},
	{"id":"flight_sky","group":"Flight greyboxes","title":"Sky","scene":"res://studies/flight_study.tscn","args":["--pack=sky"],
		"detail":"Floating masses over the cloud floor, no ground. N cycles within the pack."},
	{"id":"flight_tokens","group":"Flight greyboxes","title":"Tokens","scene":"res://studies/flight_study.tscn","args":["--pack=tokens"],
		"detail":"Token placement through the greybox stations."},
	{"id":"flight_moments","group":"Flight greyboxes","title":"Moments","scene":"res://studies/flight_study.tscn","args":["--pack=moments"],
		"detail":"Set pieces with starter-ring challenges: take the magenta ring."},
	{"id":"flight_crash","group":"Flight greyboxes","title":"Moments, crashing","scene":"res://studies/flight_study.tscn","args":["--pack=moments","--crash=hard"],
		"detail":"The moments pack with hard hits crashing. C toggles it, T the restart point."},
	# Landing greybox (studies/landing_study.tscn, docs/design/manual-landing.md).
	{"id":"landing_study","group":"Flight greyboxes","title":"Manual landing","scene":"res://studies/landing_study.tscn","args":[],
		"detail":"Land by hand on five fields: slow and level greases it, hot or hard sticks and you drift it to a stop. H hot approach, 1-5, B bots."},
	# On-foot greyboxes.
	{"id":"character_study","group":"On-foot greyboxes","title":"Character study","scene":"res://studies/character_study.tscn","args":[],
		"detail":"The pilot's moves in the greybox room. 1-9: stations, R: back to start."},
	{"id":"pocket_sail","group":"On-foot greyboxes","title":"Pocket sail","scene":"res://studies/pocket_sail_study.tscn","args":[],
		"detail":"The hand glider: thrown off a tall island by pads (or K), Space in the air pops the sail, again folds it. Gusts, rising air, tiers below."},
	{"id":"serpent_ride","group":"On-foot greyboxes","title":"Serpent ride","scene":"res://studies/serpent_ride.tscn","args":[],
		"detail":"Run about on the rune serpent's back as it flies a loop of open sky. 1-3: on its back, 4: the tower, R: start."},
	{"id":"serpent_convoy","group":"On-foot greyboxes","title":"Serpent convoy","scene":"res://studies/serpent_ride.tscn","args":["--convoy"],
		"detail":"Five serpents nose to tail down long descents: carve down one, leap off its head onto the next. T: the last gap again, 5: top of a descent."},
	{"id":"interactables_yard","group":"On-foot greyboxes","title":"Interactables yard","scene":"res://studies/interactables_yard.tscn","args":[],
		"detail":"Bobbing and drifting slabs, swing ropes and a balustrade down a grand stair, side by side for tuning. 1-4: pieces, F4: their feel."},
	{"id":"snag_study","group":"On-foot greyboxes","title":"Snag study","scene":"res://studies/snag_study.tscn","args":[],
		"detail":"A sky-folk plane flies a fixed low loop with a part on a rope: time a jump, long jump or updraft to snatch it. 1-4: spots."},
	{"id":"pack_ruins_archipelago","group":"On-foot greyboxes","title":"Ruins archipelago","scene":"res://studies/character_study.tscn","args":["--pack=ruins_archipelago"],
		"detail":"Island pack: floating ruins of an old city to platform across. 1-7: stations."},
	{"id":"pack_sky_village","group":"On-foot greyboxes","title":"Sky village","scene":"res://studies/character_study.tscn","args":["--pack=sky_village"],
		"detail":"Island pack: a little sky town on floating islands, easy way and expert line."},
	{"id":"pack_starter","group":"On-foot greyboxes","title":"Starter islands","scene":"res://studies/character_study.tscn","args":["--pack=starter"],
		"detail":"Island pack: two islands and a hop, the template for others."},
	{"id":"test_island","group":"On-foot greyboxes","title":"Test island","scene":"res://studies/test_island.tscn","args":[],
		"detail":"One small island of wheat, trees and a pond, for the pilot on foot."},
	{"id":"walk_island","group":"On-foot greyboxes","title":"Walk island","scene":"res://studies/walk_island.tscn","args":[],
		"detail":"One fixed sky island with a mountain chain, to walk round."},
	{"id":"collectibles","group":"On-foot greyboxes","title":"Collectible gallery","scene":"res://studies/collectible_gallery.tscn","args":[],
		"detail":"The glyph tokens hanging in open sky, to judge their look."},
]

## The groups, in the order their first entry comes.
static func groups() -> PackedStringArray:
	var out := PackedStringArray()
	for entry: Dictionary in ENTRIES:
		if not str(entry.group) in out: out.append(str(entry.group))
	return out

static func in_group(group: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for entry: Dictionary in ENTRIES:
		if entry.group == group: out.append(entry)
	return out

static func find(id: String) -> Dictionary:
	for entry: Dictionary in ENTRIES:
		if entry.id == id: return entry
	return {}

## Whether release exports offer the picker. On for now (playtest builds on
## the user's PC, before Steam); set false to hide it from players. Editor and
## debug runs keep it either way.
const IN_RELEASE := true

## Whether the picker is offered: editor and debug runs always; a release
## export while IN_RELEASE is true, or the project setting
## zenscape/dev/scene_picker (default IN_RELEASE) says so, or `--scenes` is on
## the command line. `--no-scenes` hides it anywhere.
static func enabled() -> bool:
	var args := OS.get_cmdline_user_args()
	if "--no-scenes" in args: return false
	if OS.has_feature("editor") or OS.is_debug_build() or "--scenes" in args: return true
	return bool(ProjectSettings.get_setting("zenscape/dev/scene_picker",IN_RELEASE))

## Opens `entry` (from ENTRIES) through scripts/launch_args.gd and leaves a way
## back to the title in the tree (scripts/scene_return.gd).
static func open(tree: SceneTree, entry: Dictionary) -> Error:
	preload("res://scripts/scene_return.gd").ensure(tree)
	return preload("res://scripts/launch_args.gd").open_scene(tree,str(entry.scene),PackedStringArray(entry.args),bool(entry.get("own_title",false)))
