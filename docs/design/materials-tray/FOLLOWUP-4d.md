Extend "ZenScape HUD 4c" (the linen materials bar and tool roll, attached)
with a home for the WORLD'S AIR: moods, time of day, season, weather and wind.
Same object family: dim linen, hem stitch, pressed-slot selection, faceted
lowpoly.js icons, Newsreader small caps. Nothing new may shout louder than 4c.

CONTEXT
ZenScape is a quiet diorama builder: a small slab of faceted land floating in
a dusky grey-violet void, worked by a ghost hand. The HUD so far splits the
maker's bench in two:
- Bottom bar = what you ADD (materials: seeds, water, stone, frost).
- Left tool roll = how you SHAPE (Hand, Paddle, Chisel, Wire, Hammer), with
  size pips.
- One thing in hand across both bars; the bare Hand is the default.
What has no home yet is everything that changes the AIR rather than the
land. Today it lives in hidden gestures and an old glass drawer that doesn't
match 4c.

WHAT EXISTS TODAY (the behaviour to design for; the look is yours)
1. Moods. Nine authored looks that cross-fade the whole world over 1.2 s:
   Alpine morning, Golden meadow, Copper autumn, Rosewater dusk, Enchanted
   forest, Halloween hollow, First snow, Nordic night, After the rain. Each
   has a title and a one-line description ("Clear blue air. Sunlit stone.").
   Once anything is changed, a first entry, "This world", goes back to the
   look the world was made with. Today: an M-key glass strip of chips, each
   chip three colour bands (upper sky, horizon glow, grass).
2. Customise, under the moods. Every control below starts at the mood's value.
   Setting one PINS it (it survives mood changes, shown by a dot); clicking
   the dot unpins it; "Back to mood" clears all pins. The pin model must
   survive the redesign.
   - Season: Spring, Summer, Autumn, Winter.
   - Time of day: Dawn, Morning, Midday, Golden hour, Dusk, Night, or
     "Turning day" (the clock runs).
   - Weather: Clear, Fair, Overcast, Mist, Rain, Storm, Snow, Leaf fall.
   - Rock: Granite, Slate, Sandstone, Basalt.
   - Colours: Grass, Leaves, Rock, Earth, Water, Sky, Mist. Each has six
     curated swatches plus a free picker.
3. Gestures that already change the air, and stay:
   - Spin the plate by its rim: time winds on (days, then seasons).
   - Shake the plate: the weather changes (snow globe).
   - Click the empty sky: the hand snaps its fingers, day to night.
   - Swipe across the sky: a passing gust. Drag from the sky onto the land:
     the wind tool in hand (swipe on and let go to send a lane of wind; hold
     still to burst). Press, pull and hold in the sky: the prevailing wind
     turns and strengthens.
   The problem: an undiscovered gesture doesn't exist. Most players will
   never find the shake or the sky drag.
4. Always-needed: Undo (Cmd+Z today, nothing on screen) and a photo action.
5. The old shell being retired. Once 4c and this land, the older "Lantern
   Maker" UI (glowing line glyphs, Mario Maker layout) is deprecated, so
   this design must cover everything of it that survives: the one-line hint
   along the bottom (it names what the hand's reach will do, the first few
   times), the mood drawer, Photo, Undo, and the World and Craft entries
   (settings and world management; a quiet menu is fine). Nothing of
   Lantern's look carries over.

THE DESIGN QUESTIONS (propose answers; show them)
A. Where does the air live? It is neither "add" nor "shape". Options to
   weigh, pick one and show a runner-up:
   - a third linen piece on the right edge or top-right corner (an almanac,
     a weather card, a small sky dial);
   - a fold-out flap of the tool roll or the materials bar;
   - something printed in the sky itself (type on the dusk, like the title
     screen), no cloth at all.
   It rests receded like the other two and never covers the plate's middle.
B. Mood as a held thing or a place? A mood is a whole-world swap, not a
   brush. Should it feel like laying a swatch of dyed cloth on the bench,
   turning a page of an almanac, or choosing a specimen card? Show how nine
   moods read at a glance (a tiny faceted sky-over-land vignette per mood, in
   lowpoly.js's facet style, is one idea).
C. Wind. Should wind become something the hand HOLDS (a faceted feather,
   fan or bellows in the tool roll, following one-thing-in-hand, with the
   size pips setting the lane width), or stay a pure sky gesture with only a
   quiet teaching cue? Show the one you recommend, with its in-hand cursor
   sketch in 4b's cursor-sketch style (faint ground mark: the lane).
D. Teaching the gestures without hand-holding. The user dislikes big
   outlines and chevrons ("hand holdy"). Propose how each air control
   whispers its gesture twin, e.g. the season control drawn as the plate's
   rim with a small turn mark, weather as a tiny snow globe that jiggles
   once when hovered, time as a sun/moon that snaps. Clicking the control
   does the same thing as the gesture, so both paths work.
E. Pins. Show a pinned control (a stitched knot? a pin through the cloth?),
   the pin cleared, and "Back to mood".
F. Undo and photo: where they sit in the family (candidates: the tool roll's
   foot, under the size pips; or the air piece). Small, stitched, no badges.

CONSTRAINTS (carry over from 4c)
- Dim linen in shadow (between the void #5d6873–#7a828c and cream), 70–80%
  opacity; hem stitch; soft shadow. Receded at rest, rises over ~250 ms with
  no overshoot when reached for. Nothing bobs or loops.
- Type: Newsreader small caps with wide tracking for tags (the build fakes
  small caps with 10 px capitals at 0.22 em tracking); Spectral 400 for the
  mood descriptions. Ink: cream #e3d7bd on the dim cloth.
- Icons: lowpoly.js facets (4×4 jittered grid, diagonal light, per-item
  seeds; continue seeds from 15). Swatches may be flat colour chips, but
  stitched, not glossy.
- Colour picker: keep it but hide it one level down; the six swatches are
  the main path.
- Everything must be buildable as Godot Controls drawn in code plus a canvas
  shader: no background blur, no complex masks.
- 1440×810 frame, 2× Retina. The plate's front edge and middle stay clear.

DELIVERABLES
Mockups at 1440×810 over the attached game-bg.png:
1. All three pieces at rest.
2. The air piece reached for, showing the moods.
3. Customise open, with one pinned control and one swatch row expanded.
4. Your wind recommendation held in hand (if it becomes a tool), with its
   cursor sketch.
5. A sheet of the air controls' states: rest, hover, chosen, pinned,
   gesture-twin cue.
Plus an updated lowpoly.js with the new icons and data, and a README in 4c's
handoff format with the new tokens, the motion table, and every departure
from 4c named.
