extends RefCounted
## The coin economy's knobs, in one place (endless flight). Everything that
## pays coins or costs coins reads its numbers from here or points here:
##
##   a banked line     PilotBook `line_pay`: COINS_PER_POINT of the banked
##                     points the chain HUD shows (the multiplier is already in
##                     them, counted once). A prize line (a pirate ship sunk,
##                     pirate_ship.gd SINK_POINTS) pays the same way.
##   a find            FIND_PAY by kind, FIND_ROOM for a relic in a cracked
##                     wall's room (finds.gd PAY, PAY_ROOM); a row of
##                     finds_table.gd may set its own `pay`, on the same steps:
##                     FIND_PLAIN in plain sight, FIND_OFF_PATH off the path,
##                     FIND_HIDDEN hidden.
##   a beat route      BEAT_MONEY a beat, DONE_MONEY the finish,
##                     SPARE_MONEY_A_SECOND a second to spare (beat_routes.gd).
##   the shop          each item's `price` (shop_stock.gd ITEMS and the skin
##                     batches in scripts/endless/skins/), inside its rarity's
##                     PRICE_BANDS (shop_stock.gd warns on one outside).
##   an old save       a book saved before SAVE_VERSION had its money in the
##                     old coins: it is scaled by SAVE_SCALE once on load
##                     (PilotBook `load_book`).
##
## The prices are set by time to earn. The rates (coins a minute at
## COINS_PER_POINT), measured on 2026-11-15:
##   RATE_BOT_*  an autopilot on the real stick (a scratch driver, seeds
##               1-3, three headings, 4 min each). CALM holds ~6 m over the
##               land with a gentle weave: ~900 points a minute, lines of
##               ~500 (best 2,565). LOW dives to 1.5 m and pulls out every
##               4 s, weaving: it crashes every few seconds, so ~300 points
##               a minute in lines of ~250. A floor: it flies badly.
##   RATE_PILOT  the pilot's own book (user://pilot.json: 263 lines in 440
##               min aloft, ~1,600 old coins from lines): about 450
##   RATE_PRICE  the rate the prices are timed at: a steady pilot, between
##               the two
## Targets at RATE_PRICE (at RATE_PILOT each takes under half as long):
##   ribbon     1,000-2,000     5-10 min        a first flight
##   common     2,000-5,000     10-25 min       a first session
##   uncommon   6,000-15,000    30-75 min       a session or two
##   rare       25,000-45,000   2-4 h           a few sessions
##   legendary  60,000-95,000   5-8 h           a goal over many sessions
## Prices sit inside their band in the order they had before.
## To retune: change COINS_PER_POINT and every pay below with it, or the
## bands and the item prices (shop_stock.gd ITEMS, skins/*.gd) for slower or
## faster unlocks; keep every price under 100,000.

## Coins for one banked point: a 2,000-point line pays 200.
const COINS_PER_POINT := 0.1
## The measured earn rates (coins a minute at COINS_PER_POINT), for the
## price reasoning above.
const RATE_BOT_CALM := 90
const RATE_BOT_LOW := 30
const RATE_PILOT := 450
const RATE_PRICE := 200

## Every other pay moved with the line's: a line pays about 100 times the
## old coins (the old pay was points / 1600 x the multiplier's square root,
## so 113 times at x2), and so do these (old: relic and landing 10, place
## line 30, event and room 40, rows 20 and 40; beats 2 and 6 and a coin per
## 15 s to spare).
## A find, the first time it is found.
const FIND_PLAIN := 1000
const FIND_OFF_PATH := 2000
const FIND_HIDDEN := 4000
const FIND_PAY := {"relic":FIND_PLAIN,"landing":FIND_PLAIN,"line":3000,"event":FIND_HIDDEN}
const FIND_ROOM := FIND_HIDDEN

## A beat route: a beat, the finish, and coins for each second to spare.
const BEAT_MONEY := 200
const DONE_MONEY := 600
const SPARE_MONEY_A_SECOND := 7.0

## Each rarity's price band [least, most].
## Ribbons have no rarity: 1,000 to 2,000.
const PRICE_BANDS := {"common":[2000,5000],"uncommon":[6000,15000],"rare":[25000,45000],"legendary":[60000,95000]}

## The save's economy version, and the factor an older save's money is
## scaled by once so it buys what it bought: the median of the new prices
## over the old (they rose 25 to 51 times, the half of them 45 or more).
const SAVE_VERSION := 2
const SAVE_SCALE := 45.0
