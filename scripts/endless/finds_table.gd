extends RefCounted
## The finds (endless flight; docs/design/endless-flight/spec-wilderness-demo.md,
## lane `finds`): the one table of what there is to find, per world. Seed 1
## only. scripts/endless/finds.gd streams it and keeps the score in the pilot's
## book as `find/<world>/<id>`, so never rename an id once it has been flown.
##
## A row:
##   id      stable, unique in its world
##   area    a key of AREAS; the logbook's Wilderness page groups by it
##   kind    "relic"    fly through it
##           "landing"  come to rest within `radius` m of it (default 45)
##           "event"    fired by a signal or by the book, see below
##           "line"     a place line finished once, see below
##   title   what it reads as once found (else the id, spaced)
##   hint    optional: what the blank reads as before it is found
## Where it stands (relic and landing; an event may have none), one of:
##   at      Vector3 exactly, or Vector2 on the ground there
##   anchor  a name:
##             a layout handle ("coast/lighthouse", "doors/amber-hall"): where
##             that tracked object stands now, followed if it moves
##             a plan site, as named on the map (tools/site_map.py):
##             "endless/arch/3_-2/0", "endless/rock/stacks/4_-2/0",
##             "endless/split/1_-3", "pond/1405_935"
##             a Peak part: "peak/summit", "peak/tarn", "peak/plateau",
##             "peak/strip/0", "peak/strip/1", "peak/strip/mid", "peak/tower/2",
##             a hole in the Dike or a Sill's gap, "peak/hole/2", "peak/sill/3"
##             (peak_carve.gd HOLES, SILL_HOLES)
##             the room behind a cracked wall: "chamber/<place>" for the wall
##             `cracked/<place>` (cracked_walls.gd SITES)
##             a way tower's foot: "way/bay", "way/south", "way/isle" (way_towers.gd)
##             "doors/amber-hall/deep": deep in the door's hall; give the row
##             `hall` true as well, and it's seen only from inside
##           or anything lanes hand to `finds.anchor(name, position)`.
##           An anchor not there yet is tried again as the flight goes on.
## and, with either:
##   up      m over the ground or anchor (relic default HOVER, landing 0)
##   offset  Vector3 added last
##   yaw     a relic's facing in degrees (else it turns to meet the plane)
##   radius  a landing's reach (m)
##   pillar  with a stacks anchor: that pillar's top, not the group's middle
## Each spot then goes through the layout file as `finds/<id>`, so a find can
## be moved by hand without touching this table.
##
## An event names what fires it:
##   event   "broken/roll/wall-1": `finds.listen(wall.broken, "broken")` makes
##           the signal `broken(name)` fire "broken/<name>" and "broken";
##           `finds.listen(burrower.caught, "caught")` fires "caught". Any
##           signal of any arguments; `finds.fire("name")` by hand.
##   book    id or ids: done when the book has found one ("door/amber-wall").
## A line names its record: `line` "line/<place>/<name>" (a LINES entry in
## place_lines.gd), or gives its own `place`, `name` and `gates` and the table
## adds it (place_lines.gd's header has the gates' shape). `mark` (s): the time
## to beat before there is a best. Done at its first finished time; the page
## shows the best.

const SEED := 1
const HOVER := 16.0

## The areas in the order they read (worlds share them).
const AREAS := {
	"meadow":"The start meadow",
	"coast":"The near coast",
	"south":"The south meadows",
	"foothills":"The foothills",
	"peak":"The Peak",
	"amberlands":"The Amberlands",
}

const WORLDS := {
	"wilderness":[
		# The start meadow: in view of the start, or a short hop from it.
		{"id":"first-ring","area":"meadow","kind":"relic","at":Vector2(45.0,-75.0),"up":28.0,
			"title":"The first ring"},
		{"id":"inlet-skim","area":"meadow","kind":"relic","at":Vector2(40.0,320.0),"up":5.0,
			"title":"The ring on the water"},
		{"id":"first-cairn","area":"meadow","kind":"landing","at":Vector2(600.0,-60.0),"radius":60.0,
			"title":"Set down by the cairn","hint":"Put the wheels down inside the stones"},
		{"id":"meadow-dash","area":"meadow","kind":"line","place":"meadow","name":"meadow_dash",
			"title":"The meadow dash","gates":[Vector3(330.0,2.0,-60.0),Vector3(820.0,4.0,-30.0),Vector3(1400.0,4.0,120.0)]},
		{"id":"east-room","area":"meadow","kind":"relic","anchor":"chamber/start-east","up":0.0,
			"title":"The ring in the east room","hint":"Cracked stone, east of the meadow"},
		{"id":"north-room","area":"meadow","kind":"relic","anchor":"chamber/start-north","up":0.0,
			"title":"The ring in the green cup's room"},
		{"id":"the-cup","area":"meadow","kind":"landing","at":Vector2(500.0,-830.0),"radius":60.0,
			"title":"Set down in the green cup","hint":"A green cup in the hills, north"},
		{"id":"burrower-catch","area":"meadow","kind":"event","event":"caught",
			"title":"Caught the burrower","hint":"Skim low, and something runs"},
		# The way south, in the first frame's left edge, down the bay to the tower
		# at its far end. From the tower: way/south for the ruin, way/isle for the isles.
		{"id":"bay-lead","area":"meadow","kind":"relic","at":Vector2(-141.0,138.0),"up":26.0,
			"title":"The ring at the bay's head"},
		{"id":"bay-ring","area":"meadow","kind":"relic","at":Vector2(140.0,800.0),"up":6.0,
			"title":"The ring down the bay"},
		{"id":"tower-ring","area":"meadow","kind":"relic","anchor":"way/bay","up":26.0,"offset":Vector3(42.0,0.0,0.0),
			"title":"The ring at the old tower","hint":"A tower stands at the bay's far end"},
		# The south meadows: the tower on the way, the door ruin, the strait to the isles.
		{"id":"south-tower","area":"south","kind":"relic","anchor":"way/south","up":26.0,"offset":Vector3(32.0,0.0,25.0),
			"title":"The ring at the meadow tower"},
		{"id":"gap-ring","area":"south","kind":"relic","at":Vector2(-1300.0,2900.0),"up":16.0,
			"title":"The ring in the gap"},
		{"id":"ridge-ring","area":"south","kind":"relic","anchor":"doors/amber-hall","up":10.0,"offset":Vector3(78.0,0.0,-128.0),
			"title":"The ring at the ruin's door"},
		{"id":"belfry-ring","area":"south","kind":"relic","anchor":"doors/amber-hall","up":72.0,
			"title":"The ring between the belfries","hint":"High between the ruin's towers"},
		{"id":"the-wall","area":"south","kind":"event","book":["door/amber-wall","door/amber-hall"],
			"title":"The way to the Amberlands","hint":"There is a way out of here"},
		{"id":"hall-deep","area":"south","kind":"relic","anchor":"doors/amber-hall/deep","hall":true,"up":0.0,
			"title":"The ring deep in the hall","hint":"Deep inside, where no light should be"},
		{"id":"strait-ring","area":"south","kind":"relic","at":Vector2(-880.0,3540.0),"up":8.0,
			"title":"The ring in the strait"},
		# The foothills: the glacier and its gorge.
		{"id":"ice-skim","area":"foothills","kind":"relic","at":Vector2(-1100.0,-40.0),"up":9.0,
			"title":"The ring low over the ice","hint":"Low over the old ice"},
		{"id":"gorge-room","area":"foothills","kind":"relic","anchor":"chamber/gorge","up":0.0,
			"title":"The ring in the gorge room"},
		{"id":"bend-ring","area":"foothills","kind":"relic","anchor":"endless/rock/valley/-6_-3/0","up":25.0,
			"title":"The ring at the gorge's bend","hint":"Up the ice, past the second bend"},
		{"id":"gorge-run","area":"foothills","kind":"line","place":"foothills","name":"gorge_run",
			"title":"The gorge run","hint":"Gates up the ice, bend after bend","mark":40.0,"gates":[
				{"at":Vector3(-1685,368,-554),"half":Vector2(7.0,5.0)},
				{"at":Vector3(-1820,409,-752),"half":Vector2(7.0,5.0)},
				{"at":Vector3(-1892,430,-848),"half":Vector2(7.0,5.0)},
				{"at":Vector3(-1985,450,-917),"half":Vector2(7.0,5.0)},
				{"at":Vector3(-2187,491,-818),"half":Vector2(7.0,5.0)},
				{"at":Vector3(-2349,532,-643),"half":Vector2(7.0,5.0)},
				{"at":Vector3(-2435,553,-563),"half":Vector2(7.0,5.0)},
				{"at":Vector3(-2543,574,-573),"half":Vector2(7.0,5.0)},
				{"at":Vector3(-2639,618,-793),"half":Vector2(7.0,5.0)},
				{"at":Vector3(-2711,662,-1019),"half":Vector2(7.0,5.0)},
				{"at":Vector3(-2783,684,-1107),"half":Vector2(7.0,5.0)},
				{"at":Vector3(-2900,706,-1086),"half":Vector2(7.0,5.0)},
				{"at":Vector3(-2939,728,-979),"half":Vector2(7.0,5.0)}]},
		# The Peak.
		{"id":"tarn-shore","area":"peak","kind":"landing","anchor":"peak/strip/mid","offset":Vector3(15.0,0.0,2.6),"radius":130.0,
			"title":"Set down by the tarn","hint":"A lake high up, with a shore to stop on"},
		{"id":"tarn-skim","area":"peak","kind":"relic","anchor":"peak/tarn","up":5.0,
			"title":"The ring on the black water"},
		{"id":"tarn-room","area":"peak","kind":"relic","anchor":"chamber/tarn","up":0.0,
			"title":"The ring in the tarn room","hint":"Walls stand on the high plateau"},
		{"id":"crown-gap","area":"peak","kind":"relic","anchor":"peak/tower/0","up":40.0,"offset":Vector3(39.0,0.0,-98.0),
			"title":"The ring in the crown"},
		{"id":"dike-hole","area":"peak","kind":"relic","anchor":"peak/hole/2","up":0.0,
			"title":"The ring in the black wall","hint":"A hole in the black wall"},
		{"id":"high-hole","area":"peak","kind":"relic","anchor":"peak/hole/5","up":0.0,
			"title":"The ring in the high hole"},
		{"id":"summit-ring","area":"peak","kind":"relic","anchor":"peak/summit","up":22.0,
			"title":"The ring over the summit","hint":"Higher than anything here"},
		# The near coast: arches, stacks, the islands, the light and the boat.
		{"id":"saddle-ring","area":"coast","kind":"relic","at":Vector2(1260.0,-900.0),"up":22.0,
			"title":"The ring on the saddle"},
		{"id":"sea-arch-ring","area":"coast","kind":"relic","anchor":"endless/arch/3_-2/0","up":14.0,
			"title":"The ring under the sea arch","hint":"A tall arch stands on the east shore"},
		{"id":"aqueduct-ring","area":"coast","kind":"relic","anchor":"endless/arch/4_0/0","up":14.0,
			"title":"The ring under the aqueduct"},
		{"id":"high-arch","area":"coast","kind":"relic","anchor":"endless/arch/3_3/0","up":10.0,
			"title":"The ring in the high arch","hint":"A lone arch on the southern hill"},
		{"id":"stack-top","area":"coast","kind":"relic","anchor":"endless/rock/stacks/4_-2/0","pillar":0,"up":14.0,
			"title":"The ring over the stacks","hint":"On top of the rocks in the bay"},
		{"id":"giant-stack","area":"coast","kind":"relic","anchor":"endless/rock/stacks/4_5/0","pillar":0,"up":14.0,
			"title":"The ring over the giant"},
		{"id":"stack-run","area":"coast","kind":"line","place":"coast","name":"round_the_stacks",
			"title":"Round the stacks","hint":"Gates in the bay, out and back through the rocks","mark":20.0,"gates":[
				{"at":Vector3(1900,-24,-600),"half":Vector2(9.0,5.0)},
				{"at":Vector3(1958,-24,-779),"half":Vector2(9.0,5.0)},
				{"at":Vector3(2012,-24,-882),"half":Vector2(9.0,5.0)},
				{"at":Vector3(2135,-24,-1040),"half":Vector2(9.0,5.0)},
				{"at":Vector3(2170,-24,-950),"half":Vector2(9.0,5.0)},
				{"at":Vector3(2094,-24,-844),"half":Vector2(9.0,5.0)},
				{"at":Vector3(1984,-24,-716),"half":Vector2(9.0,5.0)},
				{"at":Vector3(1870,-24,-625),"half":Vector2(9.0,5.0)}]},
		{"id":"arch-run","area":"coast","kind":"line","place":"coast","name":"arch_run",
			"title":"The arch run","hint":"Gates through the arches of the east hills","mark":33.0,"gates":[
				{"at":Vector3(2530,68,59),"dir":Vector3(0.97,0.0,0.25),"half":Vector2(7.0,5.0)},
				{"at":Vector3(2603,50,78),"dir":Vector3(0.97,0.0,0.25),"half":Vector2(3.0,2.0)},
				{"at":Vector3(2760,30,150),"half":Vector2(9.0,6.0)},
				{"at":Vector3(2870,70,300),"half":Vector2(9.0,6.0)},
				{"at":Vector3(2775,92,445),"half":Vector2(9.0,6.0)},
				{"at":Vector3(2656,30,530),"dir":Vector3(-0.56,0.0,0.83),"half":Vector2(7.0,5.0)},
				{"at":Vector3(2612,5,597),"dir":Vector3(-0.56,0.0,0.83),"half":Vector2(3.0,2.0)},
				{"at":Vector3(2620,6,790),"dir":Vector3(1.0,0.0,-0.1),"half":Vector2(12.0,6.0)},
				{"at":Vector3(2668,14,640),"dir":Vector3(-0.45,0.0,-0.9),"half":Vector2(9.0,5.0)},
				{"at":Vector3(2562,8,505),"dir":Vector3(-0.09,0.0,-1.0),"half":Vector2(7.0,4.0)},
				{"at":Vector3(2554,5,426),"dir":Vector3(-0.09,0.0,-1.0),"half":Vector2(3.0,2.0)},
				{"at":Vector3(2515,42,362),"dir":Vector3(-0.5,0.0,-0.85),"half":Vector2(9.0,5.0)},
				{"at":Vector3(2425,80,300),"dir":Vector3(-0.9,0.0,-0.4),"half":Vector2(10.0,6.0)}]},
		{"id":"sound-ring","area":"coast","kind":"relic","at":Vector2(560.0,2120.0),"up":6.0,
			"title":"The ring on the sound"},
		{"id":"isle-tower","area":"coast","kind":"relic","anchor":"way/isle","up":26.0,"offset":Vector3(32.0,0.0,-24.0),
			"title":"The ring at the island's tower"},
		{"id":"lone-stack","area":"coast","kind":"relic","anchor":"endless/rock/stacks/2_5/0","pillar":0,"up":14.0,
			"title":"The ring over the lone stack"},
		{"id":"long-isle","area":"coast","kind":"landing","at":Vector2(455.0,3510.0),"radius":300.0,
			"title":"Set down on Long Isle","hint":"An island with room to land"},
		{"id":"isle-room","area":"coast","kind":"relic","anchor":"chamber/long-isle","up":0.0,
			"title":"The ring in the island's room"},
		{"id":"light-rock","area":"coast","kind":"landing","at":Vector2(2097.0,3222.0),"radius":140.0,
			"title":"Set down on Light Rock","hint":"There's a flat under the lighthouse"},
		{"id":"lamp-ring","area":"coast","kind":"relic","anchor":"coast/lighthouse","up":50.0,"offset":Vector3(18.0,0.0,-14.0),
			"title":"The ring by the lamp"},
		{"id":"boat-deck","area":"coast","kind":"landing","anchor":"coast/boat","up":4.6,"offset":Vector3(-14.0,0.0,5.0),"radius":45.0,
			"title":"Set down on the old boat","hint":"Her deck is long enough. Just."},
		{"id":"horn-mouth","area":"coast","kind":"relic","at":Vector2(2930.0,3900.0),"up":12.0,
			"title":"The ring in the Horn's mouth"},
	],
	"amberlands":[],
}
