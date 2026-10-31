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
##             "peak/strip/0", "peak/strip/1", "peak/tower/2"
##           or anything lanes hand to `finds.anchor(name, position)`.
##           An anchor not there yet is tried again as the flight goes on.
## and, with either:
##   up      m over the ground or anchor (relic default HOVER, landing 0)
##   offset  Vector3 added last
##   yaw     a relic's facing in degrees (else it turns to meet the plane)
##   radius  a landing's reach (m)
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
## adds it (place_lines.gd's header has the gates' shape). Done at its first
## finished time; the page shows the best.

const SEED := 1
const HOVER := 16.0

## The areas in the order they read (worlds share them).
const AREAS := {
	"meadow":"The start meadow",
	"coast":"The near coast",
	"foothills":"The foothills",
	"peak":"The Peak",
	"amberlands":"The Amberlands",
}

const WORLDS := {
	"wilderness":[
		{"id":"first-ring","area":"meadow","kind":"relic","at":Vector2(-205.0,28.0),"up":24.0,
			"title":"The first ring"},
		{"id":"sea-arch-ring","area":"coast","kind":"relic","anchor":"endless/arch/3_-2/0","up":14.0,
			"title":"The ring under the sea arch","hint":"An arch stands in the shallows, east"},
		{"id":"first-cairn","area":"meadow","kind":"landing","at":Vector2(600.0,-60.0),"radius":60.0,
			"title":"Set down by the cairn","hint":"Put the wheels down inside the stones"},
		{"id":"tarn-shore","area":"peak","kind":"landing","anchor":"peak/plateau","radius":160.0,
			"title":"Set down by the tarn","hint":"A lake high up, with a shore to stop on"},
		{"id":"the-wall","area":"coast","kind":"event","book":["door/amber-wall","door/amber-hall"],
			"title":"The way to the Amberlands","hint":"There is a way out of here"},
		{"id":"meadow-dash","area":"meadow","kind":"line","place":"meadow","name":"meadow_dash",
			"title":"The meadow dash","gates":[Vector3(330.0,2.0,-60.0),Vector3(820.0,4.0,-30.0),Vector3(1400.0,4.0,120.0)]},
	],
	"amberlands":[],
}
