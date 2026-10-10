extends RefCounted
## The flight study's `moments` pack (scripts/flight_course.gd appends these
## STATIONS after the other packs; docs/design/flight-study-moments.md):
## moments, not trails. Each station keeps the stone of a station the user
## liked, unchanged (its `parts` are that station's own), and its old token
## trail becomes the natural line: every token a guide (FlightCourse
## `guides`), never drawn or counted, so the geometry carries the line and
## the bots fly it. What there is to get are its moments (FlightCourse
## `moments`), each one skill moment off that line:
##   kind  fit    a slit, a tight gap, a close skim
##         react  seen late, so you have to snap to it
##         reach  hanging off the line, so you bend off and come back
##   role  free       there from the start
##         starter    one per station; taking it starts the challenge
##         challenge  there only once the starter is taken (scripts/flight_run.gd)
## Each moment is {"at" (station metres), "role", "kind", "ease" (its own
## pickup reach, FlightCourse REACH times this), "note"}. Missing one never
## fails anything: a pass yields what it got. `challenge` holds the
## station's challenge settings (FlightCourse `challenge`): "time" (s, 0 no
## limit, the default), "area" (m off the line that ends it), "mode" ("all"
## or "chain"). The study's --challenge-time=<s> and --challenge-mode=chain
## try a variant without editing this file.
## Keyless (NO_KEY), in a row of their own at z +2600, 400 m apart. The
## moments were picked with tools/flight_moments_check.gd (--scan --pick)
## and then by hand, and benched per collectible (tools/flight_bench.gd).

const PackLines = preload("res://scripts/flight_pack_lines.gd")
const PackNature = preload("res://scripts/flight_pack_nature.gd")
const PackSky = preload("res://scripts/flight_pack_sky.gd")
const PackTokens = preload("res://scripts/flight_pack_tokens.gd")

const PACK := "moments"
const NO_KEY := -1

const STATIONS := [
	# The Sundered hall, flowing (sundered_flow's stone, as tokens_hall_gates:
	# rated 5). A, the corkscrew nave: in at the gate, over the high tie,
	# under the low tie, out the torn end. Across the gap and down into B,
	# under its low tie, past the slit screens and up out of the open roof.
	{"id":"moments_hall","key":NO_KEY,"pack":PACK,"from":"tokens_hall_gates","origin":Vector3(0.0,40.0,2600.0),
		"name":"Moments: Sundered hall (corkscrew nave, the gap, the slit hall)","intent":"medium",
		"parts":PackTokens.STATIONS[2].parts,"tokens":PackTokens.STATIONS[2].tokens,
		"moments":[
			{"at":Vector3(15.99,3.76,-24.09),"role":"free","kind":"reach","ease":1.0,"note":"out to the right past the first high tie"},
			{"at":Vector3(13.69,2.95,-37.85),"role":"free","kind":"fit","ease":1.0,"note":"skimming the nave's middle column"},
			{"at":Vector3(6.83,1.00,-51.02),"role":"starter","kind":"","ease":1.3,"note":"left of the line past the low tie"},
			{"at":Vector3(7.89,-4.51,-96.28),"role":"free","kind":"react","ease":0.65,"note":"down in the gap, under A's torn end"},
			{"at":Vector3(15.11,-4.75,-129.49),"role":"challenge","kind":"fit","ease":0.6,"note":"B's first knife slit"},
			{"at":Vector3(37.52,2.31,-133.53),"role":"challenge","kind":"reach","ease":0.65,"note":"out right under B's roof, past the slits"},
			{"at":Vector3(37.97,11.82,-144.88),"role":"challenge","kind":"react","ease":0.6,"note":"just over B's roof edge as you climb out"},
		]},
	# The bending nave (lines_bend's stone and green line: rated 5). It
	# climbs to a crest, leaves through a collapse in its right wall, swoops
	# round a spire outside and comes back in as the hall falls away.
	{"id":"moments_bend","key":NO_KEY,"pack":PACK,"from":"lines_bend","origin":Vector3(400.0,40.0,2600.0),
		"name":"Moments: bending nave (climb, out at the crest, the spire, back in)","intent":"medium",
		"parts":PackLines.STATIONS[0].parts,"tokens":PackLines.STATIONS[0].tokens,
		"moments":[
			{"at":Vector3(2.37,5.87,-32.24),"role":"free","kind":"reach","ease":0.9,"note":"up in the broken roof's gap"},
			{"at":Vector3(18.55,12.07,-71.96),"role":"starter","kind":"","ease":1.3,"note":"under the roof before the crest"},
			{"at":Vector3(68.40,1.50,-83.35),"role":"free","kind":"fit","ease":1.3,"note":"skimming the spire's face"},
			{"at":Vector3(77.68,-1.32,-105.31),"role":"challenge","kind":"react","ease":0.6,"note":"just inside the wall as you come back in"},
			{"at":Vector3(95.06,-5.83,-115.34),"role":"challenge","kind":"fit","ease":0.5,"note":"between a column and the right wall"},
			{"at":Vector3(99.17,-7.15,-146.32),"role":"free","kind":"react","ease":0.9,"note":"low on the left behind a column as the hall turns"},
			{"at":Vector3(106.90,-0.10,-159.17),"role":"challenge","kind":"reach","ease":0.6,"note":"high on the left near the end"},
		]},
	# The sea cave (nature_cave's stone: the nature pick). In at the mouth,
	# out through a skylight, over the roof between two pinnacles, back in
	# through a second skylight and out at the far mouth.
	{"id":"moments_cave","key":NO_KEY,"pack":PACK,"from":"nature_cave","origin":Vector3(800.0,40.0,2600.0),
		"name":"Moments: sea cave (skylight out, over the roof, back in)","intent":"medium",
		"parts":PackNature.STATIONS[4].parts,"tokens":PackNature.STATIONS[4].tokens,
		"moments":[
			{"at":Vector3(-2.16,-1.47,-55.21),"role":"free","kind":"reach","ease":0.9,"note":"low on the left inside the cave"},
			{"at":Vector3(2.45,11.58,-86.91),"role":"starter","kind":"","ease":1.3,"note":"just out of the first skylight"},
			{"at":Vector3(-5.18,9.61,-119.88),"role":"free","kind":"fit","ease":1.0,"note":"skimming the second pinnacle"},
			{"at":Vector3(-0.47,7.70,-143.24),"role":"challenge","kind":"fit","ease":0.65,"note":"close under the second skylight's lip"},
			{"at":Vector3(-5.21,-1.60,-163.04),"role":"free","kind":"react","ease":1.0,"note":"low on the left, back inside"},
			{"at":Vector3(9.84,0.34,-193.23),"role":"challenge","kind":"react","ease":0.45,"note":"in a pocket of the right wall"},
			{"at":Vector3(-0.41,1.73,-256.93),"role":"challenge","kind":"reach","ease":0.65,"note":"low on the left out of the far mouth"},
		]},
	# The pierced isle (sky_pierced's stone: rated 4). Under a small islet,
	# into the big isle's tunnel, out and round a falling loop past an
	# outrider and two stacks, back in under the keel and through the veil.
	{"id":"moments_pierced","key":NO_KEY,"pack":PACK,"from":"sky_pierced","origin":Vector3(1200.0,40.0,2600.0),"miss_near":10.0,
		"name":"Moments: pierced isle (the tunnel, the loop, under the keel, the veil)","intent":"medium",
		"parts":PackSky.STATIONS[3].parts,"tokens":PackSky.STATIONS[3].tokens,
		"moments":[
			{"at":Vector3(-3.87,0.73,-48.31),"role":"free","kind":"reach","ease":1.0,"note":"left of the tunnel mouth"},
			{"at":Vector3(-8.22,4.59,-71.68),"role":"free","kind":"fit","ease":0.8,"note":"up in the tunnel's corner"},
			{"at":Vector3(17.88,1.36,-114.26),"role":"starter","kind":"","ease":1.3,"note":"just out of the tunnel"},
			{"at":Vector3(40.74,2.04,-117.59),"role":"challenge","kind":"fit","ease":0.55,"note":"under the outrider's rim"},
			{"at":Vector3(49.70,-3.37,-92.50),"role":"free","kind":"react","ease":0.8,"note":"round the loop, by the stacks"},
			{"at":Vector3(10.00,-13.00,-80.00),"role":"challenge","kind":"reach","ease":0.5,"note":"up under the big isle's keel"},
			{"at":Vector3(-27.67,-7.03,-79.76),"role":"challenge","kind":"react","ease":0.6,"note":"just over the veil's near edge"},
		]},
	# Over the crest (lines_crest's stone and green line: rated 5). Out
	# through the open roof as the hall rises, over the roofed crest through
	# three big gates (slit gates beside them), and back in.
	{"id":"moments_crest","key":NO_KEY,"pack":PACK,"from":"lines_crest","origin":Vector3(1600.0,40.0,2600.0),
		"name":"Moments: over the crest (out the roof, the gates, back in)","intent":"medium",
		"parts":PackLines.STATIONS[2].parts,"tokens":PackLines.STATIONS[2].tokens,
		"moments":[
			{"at":Vector3(-8.77,1.04,-47.94),"role":"free","kind":"reach","ease":0.9,"note":"low under the climb out"},
			{"at":Vector3(-15.17,17.18,-68.05),"role":"starter","kind":"","ease":1.3,"note":"on the roof before the first gate"},
			{"at":Vector3(-16.83,16.79,-96.25),"role":"free","kind":"fit","ease":1.0,"note":"between the second gates"},
			{"at":Vector3(-16.89,16.49,-111.84),"role":"challenge","kind":"fit","ease":0.8,"note":"through the third slit gate"},
			{"at":Vector3(1.26,11.41,-122.47),"role":"free","kind":"react","ease":0.8,"note":"right of the dive back in"},
			{"at":Vector3(2.94,5.51,-155.09),"role":"challenge","kind":"react","ease":0.65,"note":"up on the left, back under the roof"},
			{"at":Vector3(13.59,7.11,-181.51),"role":"challenge","kind":"reach","ease":0.55,"note":"high on the right near the end"},
		]},
]
