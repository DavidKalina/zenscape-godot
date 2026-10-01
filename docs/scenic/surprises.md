# Surprises: what you build reveals

Master list, brainstormed 2026-09-29 for the Steam launch. The pitch is "what you build reveals different things". Every entry here answers something the player made, or makes a rare moment out of things already in the world. Nothing is a goal and nothing is marked on the ground.

**Effort:** S is a day or less, M is a few days, L is a week or more.

**Rarity:**
- **Common:** most players see it in the first session.
- **Uncommon:** it needs a particular build or season.
- **Rare:** players tell each other about it.
- **Legendary:** some players never see it.

## 1. What already exists

These are wired into the default Genesis path now (see `life.md`, `emergence.md` and `water-flow.md`).

| Surprise | Answers | Rarity |
|---|---|---|
| Grass, then shrubs, then trees creep out from wet ground | any stroke or splash | common |
| Willows by water; reeds, flowers or ferns by habitat | where you built | common |
| Dead wood and an elder stand in old forest | forest age | common |
| Fish, koi or wild company, rising rings at dusk | pond ≥1.5 m², deep cells | common |
| Frogspawn, then frogs | shallow still edges, not winter | common |
| Ponds freeze: fish slow and dark, frogs dig into the bank, heron and snake stay away | winter ice | uncommon |
| Thaw burst: extra frogspawn, frogs crawl out of the banks, lively fish | a thaw after a held freeze | uncommon |
| Mist off the ponds | cold clear dawns, autumn to early spring | common |
| Gulls on thermals | shore, trees, streams | common |
| Fireflies at dusk | damp ground near water and plants | common |
| Springs, rills, pools, falls, edge falls | where a water ball lands | common |
| Spores from the wild tree sow a forest; 7% come up as another kind | a flick | common |
| Water lilies on a pond that has stood a while: a few pads, then a lily edge, flowering in summer, gone in winter | pond age, season | uncommon |
| Autumn leaves fall on water, run down rills, circle ponds and gather at the banks | trees by water, autumn | common in autumn |
| Heron wades and strikes, and now and then catches a fish, swallows it or flies off with it | pond with settled fish, daylight, dry | uncommon |
| Doe, sometimes a fawn, at the forest edge | ≥6 trees, dawn, dry | uncommon |
| Grass snake on the bank | rich pond, sunny morning | uncommon |
| Grass snake stalks and takes a frog | snake visit with a frog sitting in reach | rare |
| Rainbow after rain | rain that stops over a rich world | uncommon |
| Meteors | clear night | common (ambient) |
| Aurora | a clear night that rolls it: 50% in winter, 20% late autumn, 2.5% otherwise | uncommon |
| Moon phases | an 8-day lunar month; full-moon nights are brighter | common (ambient) |
| Moonbow | night rain stopping under a near-full moon over a rich world | legendary |
| Lightning starts a fire | rain with storm | rare (accidental) |
| Bigfoot at the forest edge | big old forest, 10 min settled, dusk, dawn or mist | legendary |

## 2. New interactions between things we have

This is the cheapest source of surprises. Most of it wires together systems that already exist.

### Weather and water
- **Rain fills ponds.** The flow sim takes rain as input: ponds rise, rills run, and a dry basin becomes a pond after a storm, which then brings fish. This is the biggest gap. It makes the weather matter. (M, common) *Built on `feature/sp-rain`, see water-flow.md "Rain"; a cheap snowmelt pack rides along.*
- **Snowmelt feeds springs.** Winter snow on the peaks runs into springs and streams in spring, so the streams swell. (M, uncommon)
- **Winter reaches the water.** Ponds freeze. Fish go slow and dark under the ice, and frogs are gone. The thaw brings a burst of frogspawn. (M, uncommon) *Done: `life.md`, "Winter on the water".*
- **A rainbow in the waterfall spray** when the sun is behind the camera. (S–M, uncommon)
- **Morning mist off the ponds** on cold, clear dawns. (S, common) *Done: `life.md`, "Winter on the water".*

### Life eats life
- **The heron catches a fish.** Done, see `life.md` "Predation". (S, uncommon)
- **The snake takes a frog**, now and then. Done, see `life.md` "Predation". (S, rare)
- **An eagle snatches a fish** (the user's long-term want). It needs the eagle; see section 3. (L, rare)

### The world notices the hand
Each of these is small and makes the world feel alive under your fingers. All but the clouds are built on `feature/sp-hand-notice` (`docs/scenic/life.md`, "Noticing"); they are checked headless only.
- **A gust** flushes the gulls, the fish dart, the deer lift their heads or bolt, and the fireflies scatter and settle again. (S)
- **A poke near water** sends frogs plopping in. Fish scatter from the rings, then come back to nose at them. (S)
- **Snapping to night** switches the fireflies on in a wave. Snapping to dawn gives a dawn chorus. (S)
- **Gusts push clouds**, so you can steer rain over the land you want to grow. (M)

### The wanderer is noticed
Built with the hand's reactions (see above).
- The deer step away from the figure. The snake hisses at it. Fish follow its shadow at the bank. Frogs jump in as it passes. (S each)

### Seasons and plants
- **Autumn leaves float.** Built (`life.md`, "Ponds through the year").
- **Old ponds grow water lilies.** Built, apart from reeds creeping in (`life.md`, "Ponds through the year").
- **Lightning finds the tallest tree**, even when rain stops a fire. It leaves a scorched snag that becomes dead wood. (S, rare)
- **Spores carried over water** by a gust sow a forest on an island. (S, uncommon)

### Sky
- **Aurora only on clear winter nights**, instead of always on. That turns it into something you find. (S, uncommon) Done; see "Night sky" below.
- **Meteors land.** Very rarely, a falling star comes down, leaves a glowing stone, and a strange flower grows there. (M, legendary)

## 3. New things, by what you build

### Water
- **Dragonflies** over still water in summer. (S–M, common)
- **Ducks with a line of ducklings** on big ponds in spring. (M, uncommon)
- **Kingfisher:** a blue flash from a branch over fishy water. (M, uncommon)
- **Trout in streams**, and in autumn a **salmon run leaping up the falls**. (M/L, rare)
- **Otter** in a long river with fish, sliding down the banks. (L, rare)
- **Beaver:** a stream through forest slowly gets dammed, and the pool grows upstream. It builds on the flow sim. (L, legendary)
- **Swans** on a large lake. (M, rare)

### Forest
- **Woodpecker** drumming on dead wood. Mostly sound. (S–M, common)
- **Owl** in the elder stand at night: eyes glint, and a call. (M, uncommon)
- **Fairy ring** of mushrooms in old forest after autumn rain. (S, rare)
- **Light shafts** through old forest in mist. (M, uncommon)
- **Squirrels** in oaks, and acorns that spread oaks faster. (M, uncommon)

### Meadow
- **Butterflies**, and **bees** that make flowers spread faster. (S–M, common)
- **Rabbits or a fox** where meadow meets forest. (L, uncommon)
- **Starling murmuration** over a big meadow at dusk. (M, rare)

### Mountain
- **Eagle** nesting on the highest peak. It hunts fish if there are any. (L, uncommon)
- **Mountain goats** on steep bare rock. (L, uncommon)
- **Echo** in deep valleys. Sound only. (S, uncommon)
- **Bats** from cliffs or caves at dusk. (M, uncommon)
- **Spring avalanche** from a heavy snowcap. (M, rare)

### Sky and time
- **Geese in a V** overhead in spring and autumn. (S, uncommon)
- **Moon phases**, and a **moonbow** after night rain under a full moon. It reuses the rainbow. (S–M, legendary) Done; see "Night sky" below.
- **Fireflies sync** their blinks when a meadow has been left alone long enough. (S, rare)
- **Summer thunderstorms** scheduled rarely, with rolling thunder. (S, uncommon)
- **Comet** across several nights, or an **eclipse**. (M, legendary)

## 4. Rare variants

This is the cheapest way to get a rare surprise. Each is a colour or a table entry on a creature that already exists, at around 1–2% odds.
- **Golden koi** in a koi pond. (S, rare)
- **White stag** in place of the doe. (S, legendary)
- **Albino frog** or a **blue frog**. (S, rare)
- **Double rainbow.** (S, rare)
- **A heron with a fish in its bill** flying off. Done, 15% of catches. (S, rare)

## 5. Bigfoot as a trail

Build a trail of signs, not a single sighting, so that Bigfoot is the legend at the end of it. Each sign also works on its own.
- **Tracks in snow or mud** at the forest edge, found in the morning. Snow tracks can also reveal deer and foxes. (M)
- **Stacked stones** or a **snapped branch** where there were none. (S)
- **A far howl** on a still night. (S)
- **Wood knocks** in the elder stand. (S)
- **Then the glimpse**, as now. (exists)

## 6. Launch shortlist

This is my pick of the best payoff for about a month.

1. Rain fills ponds. (M)
2. The heron catches a fish; the snake takes a frog. (S)
3. The world reacts to gusts and pokes. (S)
4. Rare variants: golden koi, white stag, albino frog, double rainbow. (S)
5. Aurora on winter nights only; moon phases and the moonbow. (S–M)
6. Dragonflies, butterflies, woodpecker drumming, geese. (S–M)
7. Water lilies on old ponds; autumn leaves on water. (S–M)
8. The Bigfoot trail: tracks, stones, howl, knocks. (S–M)
9. Winter ice on ponds and the spring frogspawn burst. (M)

Players see what exists through the photo labels, and later maybe through a quiet field journal with blank slots. No hints or objectives.

## Night sky (built)

All in `studies/celestial.gd`, drawn by `shaders/reference_sky.gdshader` and `reference_sky_common.gdshaderinc`.

- **Aurora.** Each night (noon to noon on the world clock) rolls once by its season: `AURORA_CHANCE` is 0.5 in winter, 0.2 from `AURORA_LATE_AUTUMN` (season 0.62) and 0.025 the rest of the year. A chosen night gets a strength in `AURORA_STRENGTH` (0.35-1.15), an onset 7-11 h after noon (`AURORA_ONSET`) and 4-9 h of light (`AURORA_HOURS`), ending by 05:30. It fades in and out over `AURORA_FADE` (150 real s for the strongest) and only under cloud below `AURORA_CLOUD`. The look's `aurora_strength` (sliders, moods, presets, `--aurora`) is now a floor, 0 by default; studies without a clock keep only it.
- **Moon phases.** `LUNAR_DAYS` (8) world days a month, starting `LUNAR_START` (0.85, waxing gibbous). The moon falls a turn behind the sun each month, so it rises later every night and a new moon is up by day. The disc is shaded as a sphere lit by the sun, with earthshine and faint seas; the lit part is HDR. Moonlight runs from `MOON_LIGHT.x` to `.y` of the old fixed moon, and the night fill from `MOON_FILL.x` to `.y`. The moon's lake glint follows its phase.
- **Night look.** Night is not dimmed day. Past the afterglow (`NIGHT_LOOK_E`, sun height -0.03 to -0.2) the look pass's grade takes the land's mid-values toward a cool rod-lit grey (`night_grade`, a Purkinje shift; `zs_look_night` in `shaders/look_grade.gdshaderinc`), more under a new moon (`NIGHT_GRADE.x`) than a full one (`.y`). Bright lights (fireflies, glints, stars, the moon) and the open sky keep their colour. Moonlight runs from a dim blue (`MOON_TINT[0]`) to silver-blue (`[1]`) and is a readable key over the deep blue `NIGHT_FILL`; mist and cloud are lit by the moon, not the day's colour. The sky cloud goes to a silhouette with a moonlit rim that follows the phase (`zs_moon_light`). A mood's `night_look` (0-1.5, default 1; Halloween hollow 0.7) sets how far its night goes.
- **Moonbow.** A life moment (`docs/scenic/life.md`): night rain stopping under a moon at least `MOONBOW_FULL` (0.9) lit.


## Polish tally

A running list of what looks off or is still unverified, gathered from the first rendered takes (2026-09-29, clips in `captures/surprises/`, not in Git). Nothing here blocks the others. Pick items off in later sessions, and add to the list as things are seen. Strike an item through, or remove it, once it's done.

**Legend:**
- **[bug]** is broken.
- **[look]** works but doesn't read well.
- **[tune]** is a number to adjust.
- **[unseen]** has not been seen or heard rendered yet.

### Discoverability
- [look] The raise gesture (hold still about 0.3 s, then drag up) is undiscoverable: the user could not find how to raise terrain (2026-09-30). Show the hold being recognised, e.g. the ground starts to lift under the pointer and a rising creak plays. Partly addressed on polish/leaves-clay-spring: the hold is now 0.2 s and the spot kicks up a few centimetres when it takes (no creak yet).

### Feel pass (2026-09-30, polish/leaves-clay-spring)
- [unseen] Pond leaves steered tip first down the current, stalk trailing, and barely felt the wind. Now they turn slowly on their own and drift with the gusting wind (shape unchanged).
- [unseen] Ground leaves ignored ordinary wind (they only moved above about 1.25 wind, and the default is about 0.5), and leaves blown onto a pond or off the plate jumped back to their start, so steady wind ran them in a loop (shape kept as it was; the user likes it). Now they rock in any breeze, skid with weight in gusts, lodge at banks and the rim, fade when blown away and regrow later; the fixed 1/60 s step (0 or 2 steps a frame near 60 fps) is gone.
- [unseen] The Modeller's pinch felt sluggish. The hold is 0.2 s, the spot kicks up when the hold takes, and the summit follows the pointer on a quick spring (30 rad/s, 0.6 damping), landing exactly where it is let go. Tune PINCH_SPRING, PINCH_DAMPING and GRIP_KICK (scripts/clay_tools/hand.gd) by feel.
- [bug] "Fish" hanging over dry grass on new chunks were the old resident's food-loop fish (scripts/fidelity_fish.gd), shown from a habitat that is never rebuilt without the resident. They now stand down unless the habitat is current and the world is not blank (studies/fidelity_life.gd). Deprecate or delete the old fish with the old resident; the ambient Bigfoot rebuild is not wired to them.
- [unseen] A spring's or mountain's weathering popped in a moment after it settled. It now eases in over WEATHER_EASE_SECONDS (1.2 s, scripts/native_chunk_editor.gd).

### Existing look, beyond these features
- ~~[bug] The grass snake never drew in the rendered game.~~ Fixed on feature/sp-predation (281652f): its body wasn't bound to the skeleton. The user has seen it and likes it.
- ~~[tune] The snake is small.~~ Now 1.8 m by default, with a seeded 0.8-1.3x size per visit (b93a8a2).
- [tune] `probe_snake.gd` flags 14 "pops" a visit at the new size; its 6 m/s² threshold was tuned for the old size. Rescale the threshold or check the motion.
- [look] Open water is nearly invisible from most angles; fish seem to float in a green hollow.
- [look] Fireflies draw as faint square quads in dusk fog (fog applied to their additive quads).
- [look] Broadleaf crowns read pale lilac-white in summer and autumn, not green or gold. Check the stand tint, and whether autumn tint reaches that kind.
- [look] Cold weather turns the ground orange-brown and leaves pale fog blobs at the frame edges.
- [unseen] Fog puffs hung past the plate's rim over the void in nearly every shot. On polish/void-fog-puffs the display air, native valley fog, fog bank and peak clouds keep only where land is behind them (`zs_plate_keep`), and fair-weather ground mist gathers in patches. Needs a rendered look, including low views and night.
- [look] Dead-wood snags look short and stubby.
- [look] Hills read low and soft from the play camera.

### Rain
- [look] Rain fog veils the water, so the filling pond reads as a pale ring and rills barely show. Thin the rain fog near the ground so players can watch their pond fill.
- [unseen] How water entering the ground looks (a source may show as a small welling on a slope).
- [unseen] Whether fish arrive at a rain-made pond.

### Predation
- [look] The heron stands at the very edge of the pond, once right on a frogspawn clump.
- [look] A fish carried off in flight is small.
- [look] The swallow bulge is subtle at the long-lens film distance.
- [look] In the escape clip the frog sits nearer the camera than the snake, so the escape reads weakly.

### Noticing the hand
- [look] Dusk fog hides the fish in the gust shot; the gull is hard to see.
- [look] The deer bolt plays its Walk at 2.3x and may look like scurrying. A run clip is needed (Blender).
- [unseen] A frog buried in the bank for winter reacting to a poke or the wanderer.

### Rare variants
- [look] The white "stag" is a cream doe: the rig has no antlers.
- [unseen] Fish carried by water balls don't roll for golden koi.
- [look] The golden koi reads mustard more than luminous under the pond tint.
- [unseen] Albino and blue frogs haven't been seen beside an ordinary frog.
- [look] The double rainbow's sky is dark and grey under a low sun.

### Night sky
- [look] The moon disc is soft in an extreme close-up.
- [tune] Old saves or moods that stored aurora 0.65 still show a constant aurora.
- [bug] Merge risk: main's uncommitted sky edits (bow in front of the hills) touch the same shader include.

### Small life
- [look] Geese side-on read as a loose cluster; the V shows from above.
- [unseen] The drum and honk sounds haven't been listened to.
- [tune] Butterfly and woodpecker sizes were raised for readability (butterfly SCALE 2.4, woodpecker SIZE 2.2); judge at play distance.
- [look] Sine-driven motion may feel mechanical. The woodpecker is the first candidate for Blender clips if so.

### Pond seasons
- [look] Lily pads read nearly black; they want a lighter leafy green.
- [look] Lily flowers are hard to find.
- [look] Leaves on water read as small specks at play distance; one leaf can't be followed down a rill.
- [unseen] Survey fix: fish, frogs and herons now find live-water ponds. Watch for over-population or odd arrivals.

### Winter water
- [tune] The dawn mist reads as bright glowing puffs, not a thin low layer. Lower `MIST_STRENGTH` and `MIST_SCALE`.
- [unseen] Freeze and thaw state isn't saved.

### Bigfoot trail
- [look] Prints read as dark blobs from a few metres, not bare feet.
- [tune] The howl (about -20 dB) and knocks (about -27 dB) are quiet.
- [tune] The natural odds fire (6 simulated days: 4-9 tracks, 5 howls, 9-11 knocks) but haven't been judged for feel.
- [unseen] Snow tracks don't also show deer or foxes.

### Filming
- The God Hand and hover rings leak into some takes; film scripts should switch off the hand's processing, not just hide it.
- Film scripts: `tools/film_{rain,predation,hand_notice,night_sky,small_life,winter_water,bigfoot_trail,pond_seasons,variants}.gd`.

### Shaping tools (landscape audit, 2026-09-30)
Full list in `docs/design/tools/LANDSCAPE-AUDIT.md`. The top items:
- [bug] A shaping press on a tree or shrub does nothing, with no feedback.
- [bug] A Hammer gesture straight after another is eaten.
- [tune] Life buries every landform within seconds; open or dry ground can't be kept.
- [look] Mist blankets every hollow, so water in basins and moats is hard to see.
- [look] Gentle hills and flower drifts don't read from the building view.
