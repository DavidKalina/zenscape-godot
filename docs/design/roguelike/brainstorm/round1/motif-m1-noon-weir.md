# The Noon Weir — "It keeps the hours. It has always kept the hours."
Lenses: verb = time a crossing; purpose = mechanism / calendar (a water clock that measures a day by floods); mood = wrong; twist = the ruin still doing its old job. Scale: colossal. Decay: half-collapsed but running. Shape: a tall stack, isles over isles.

Pitch: Three channels stacked in the air, each with its own gate, bone dry between flushes, and a bell on top that rings the hours for no one. You climb it by learning the gates' counts and being exactly where the water isn't.

Top (1 char ~ 4 m)
```
 3 (top)    @=====>==(T)        @ = belfry   T/(T) = tower_shell chimney
 2              (T)==>=====     === = channel (aqueduct_span)
 1 (base)  [E]==>=====(T)       > = sluice gate head, o = flush wave
            ^ ~ ~ ~ gulf        E = entry     stairs (grand_stair) at gate ends
```
Side
```
 y+36  bell@  ______                  top channel   (longest period)
 y+24         |T| ===>==========       middle channel
 y+12   ==>===|T|                      low channel   (shortest period)
 y+0  entry   |T|_ grand_stair up at each gate end
```
Three tiers about ten jump-heights apart. Each is a walled channel with a gate (trap_sluice as set up in sluice_aqueduct.gd); a tower_shell beside the stack is the wall-kick chimney between tiers; a grand_stair at each channel's gate end climbs to the next.

Play:
1. Arrive at the foot of tier 1: a dry channel, gate at the far end. It is a road. Half-way along, a plate (or a timer) arms the sluice and the tell starts: the channel drains from the gate, the leaf rattles, spray bursts. You have the tell's time to reach the lip beside it (a ledge grab, a wall kick off the channel wall).
2. The wave comes down the channel (a conveyor, a hazard to stand in, a ride to take on its crest). Riding it forward carries you to the stair at the next gate end if the gate faces your way, and back to the foot if you chose wrong.
3. Tier 2 has a longer period, tier 3 longer still, set in a ratio (1:2:3 at the defaults). Once a "day" all three open together: the Noon Flood. The tower roars, water falls from tier to tier on the face, and the bell on top tolls.
4. The climb: take each channel in its dry half, take the chimney (wall-kick up inside tower_shell) while it is wet. A twirl and a pocket sail over a broken span (aqueduct_broken) lands on the next lip with the gates open and the channel below full.
5. The wrong part: nothing feeds the channels. The water comes from the sky above, the gates grind open on air, the flood falls past you into the layer below, not into any pool. The bell tolls noon in an empty tower, and it is a noise (shortlist, thread 2): landing in the belfry rings it.
6. The top: the belfry (ruin_kit_belfry). Ring it on purpose from the wall head for a tool, or skip it and keep quiet.

Threat: the sluice (scripts/traps/trap_sluice.gd with sluice_aqueduct.gd, timer trigger, tell_time, wave_height, the gurgle tells) at every tier. As tools: the wave is a conveyor to the gate you want; an open gate leaf is a lintel; the wet channel is a slide; and the Noon Flood is a free, safe ride to the bottom after a hard climb. Optional enemy: a plinth_ram (scripts/enemies/plinth_ram.gd) on the middle tier, so the bull and the flush share one lane; a dodge near the lip sends the bull over.

Combos (hand-offs between different sources; the sluice washes a grounded body, pushes an airborne one, and its spill is a toss that leaves a stunned body stunned, stun-round1.md):
1. By accident, "the dodge that wasn't": the middle tier's plinth_ram hooks you off the lip as the tell starts -> knock throws you stunned into the draining channel (the ram's gap and the sluice are different sources) -> the wave washes your downed body to the gate-end spill -> the spill tosses you, still stunned, onto the tier-1 grand_stair or past it out over the gulf. You lose the climb and are a floor lower, not dead.
2. On purpose, "ride the Noon Flood": wait on the top landing for the three-way coincidence, leap into the top channel on the crest -> the spill throws you off the end onto the middle channel's wave, which is also at full flow -> it carries you to the next spill -> the base spill tosses you out and a little up toward the exit rim (a pocket sail finishes the hop). A few seconds from the bell to the next isle, a route only a player who counted the gates can use.
3. With the bell: land in the belfry and the bell swings (existing) and tolls; ringing it on the half-day coincidence shifts the dragon's attention for the flood, then slide (balustrade) down the cheek stair to meet the wave. An outside link: a cannon-shot (cannon-round1.md) or an inhaler-head blast from the neighbouring isle into the top channel's open head puts a tumbling body on the crest of a flush, a 3-link chain: head -> channel -> spill -> rim.
Ports:
- Catches from outside: anything thrown into a channel is carried (grounded) or pushed (air) down it; the top channel's open head faces the neighbouring isle's blast line, and a body landing on the tower roof tumbles into the tower_shell chimney and drops to tier 1.
- Throws out: the tier-1 spill throws along the channel's axis out over the gulf toward the exit rim, still stunned if it came stunned (5-8 m, a little up); the top tier's spill throws sideways off the stack toward a lower isle on the other side, so the generator can hang this motif between a high isle and a low one.

Mystery: A clepsydra. The builders measured days by floods, so this tower is their clock and calendar in one: a day is the time for the three gates to meet. Notches are cut down the channel walls, and the notch where all three coincide is cut deepest, with a rune. Who needed a day so exactly, in a land with no one to count it for? It still strikes noon at its own idea of noon. Echoes the Sluice Warden (shortlist boss) and the aqueduct's water thread.

Kit used (verified): aqueduct_span, aqueduct_two_tier, aqueduct_broken, aqueduct_stump, aqueduct_end, grand_stair, stairs, wall, buttress, tower_shell, tomb_chest (prize); belfry() and bell() from scripts/ruin_kit_belfry.gd; trap_sluice; enemy plinth_ram (optional); rope bridge optional for a far tier.

Kit asks:
- A sluice that can be driven from a shared clock so three gates line up on a common noon (today each is independent and timer-based).
- A falling-water sheet that cascades down a tower face between tiers (kit-isle-water has isle pools and a curtain fall; nothing cascades from tier to tier).
- A carved stone gate leaf for the sluice (sluice_aqueduct builds its own mesh).

Family knobs:
- tiers: 2 / 3 / 4.
- ratio: 1:2:3 / 2:3:5 / 3:4:5 (how often the gates coincide).
- wet: dry between flushes / shallow water between flushes.
- crown: belfry / bare tower head / broken arch.

Sockets:
- rim: entry at the foot of tier 1 (faces the layer's lowest isle, run-up the landing behind); exit at the top (faces away); optional side hops off tiers 2 and 3, out over the drop.
- arena: each gate's landing, and the belfry floor.
- cover: under each channel's arches and inside the tower shell.
- perch: the belfry and the base landing.

Generator fit: role hero; footprint about 30 x 30 m, height_span 36 m and up; the tall stack the coverage table lacks. A layer's route ascends through it.

Distinct from: stair_clouds (a grand stair in 8 flights up a mesa: pure climb) and bell_spires (the belfry on a spire with rope bridges). This is a mechanism: the climb is a clock, the channels are the route, there are no rope bridges, and the bell is the closing beat. Unlike the aqueduct isle's channel run it is vertical: the channel is a tier, not a span across a gap.

## Greybox (Opus pass)
Round 1 (Sonnet) built the three channels, stairs, bridges and the ram inside tier 2, and ran chain 2 end to end only with hand-tuned gate offsets (2.9 s / 5.5 s); chain 1 knocked him straight out of tier 2's open end (no wave), chain 3 was not built.

Run: `godot --path . res://studies/greybox/noon_weir.tscn -- --no-title [--base=8] [--ratio=1:2:3] [--offsets=a:b:c] [--hold=0.6] [--no-noon-double] [--sluice-knob=k=v] [--no-ram]`. Code `studies/greybox/noon_weir.gd`; the whole layout is the one `LAYOUT` const at its top (tiers, slabs, stairs, enemies, the cannon, stations, labels).

**Stations.** 1 start deck (also the exit-rim stand-in), 2 tier-1 gate head, 3 stair-1 top, 4 bridge 1 end (hop the 1.0 m parapet into tier 2), 5 tier-2 gate landing (the ram's), 6 stair-2 top, 7 bridge 2 end, 8 top landing, 9 bell floor. Chains: 0 chain 1 (walk up tier 2 at the ram; tier 2 tells as it hits), - chain 2 stood in the top channel 1 s before the tell, = chain 2 waiting on the top landing (noon tell in 6 s: run in on the tell), [ chain 3 on the cannon isle (Y climbs in, A fires you; the aim is already set). N sets the clock 6 s before noon; F1 shows the clock, each gate's offset and "NOON, double".

**What I rearranged, and why.**
- *Gate offsets derived, not tuned.* The top gate opens at noon; each lower gate opens `HOLD` (0.6 s) after a body the upper wave carried lands in it (the upper channel's length / wave speed + the spill's fall time, from the motor's own gravity): 0 / 3.67 / 7.76 s at the defaults, and they follow any layout or `--sluice-knob=speed`. An early body lies dry and waits for its wave; a late one still has HOLD + (its distance down the channel + the wave's length) / speed, about 2 s. Round 1's offsets had the wave out ahead of the falling body by 0.25 s, which left about 0.5 s of slack.
- *The Noon Flood is a double surge.* At the noon flush only, every gate sends the sluice's `second_wave` 1.5 s behind the first (set per flush at trigger time, no engine change). A late drop at the top, or a late cannon shot, catches the second wave. Without it (`--no-noon-double`) a late run-in is 0/10 and a late cannon shot 2/10.
- *Stack re-spaced around the spill.* The spill throws a body about 11 m out on a 12 m fall. Tier 3's open end now sits directly over tier 2's gate (gate z 52 -> 49.5), so the body lands 11 m down tier 2 (z 18.5), out of reach of the ram on its landing. Tier 2's open end (z 5.5) drops a body 6 m down tier 1 (z -6), and tier 1 spills onto the deck (z -25).
- *Tier 2 is the ram's walled lane.* It is 24 m long (was 20) so a knock from the gate end stays in it. Its parapets are 1.0 m (default 0.42), because a hooking charge throws him 18 deg off the axis, the knock peaks 0.5 m up, and with the low parapets 5/10 knocks went over the wall into the void. The refuge is 1.2 m and the wave 8 m long (default 3.6), so a player who gets up and wades back against it stays in the water to the spill (with 3.6 m he waded out the back in 1.3 s). The parapet hop from bridge 1 still works with the held jump (10/10). Bridge 1 runs on to z 14.
- *The ram moved out of the channel onto tier 2's gate landing,* north of the gate and facing south. It charges down the lane at anyone walking up it, so its knock throws you south, down the lane, ahead of the water. This is "the bull and the flush share one lane", and it keeps the Noon Flood's landing clear of the ram.
- *Chain 3 uses the real cannon* on a neighbouring isle (y 32, z 70, firing south). Its own rest aim (40 deg, notch 2) lands at z 46 in the top channel (checked and labelled in the world), so climbing in and firing needs no aiming. The 11 m fall from the arc's top lands him stunned.

**Reliability (headless, real motor and tick, scripted input; spawn +-0.5 m, timing +-0.2 s; ram present; 10 runs each):**
- Chain 2, ride the Noon Flood: **10/10** stood in the top channel; **10/10** running in from the top landing on the tell; **10/10** late (starting 0.3 s after the gate opens: the second surge); **10/10** early (in the dry channel 5 s before). Each run made three spills, about 11 s, and ended on the deck.
- Chain 1, the dodge that wasn't: **10/10** when he lies where he falls; **10/10** when he gets up and walks back up the lane; **10/10** when he gets up and runs for the open end. In every run the ram knocked him, tier 2's wave carried him to the spill, and he landed on tier 1 a floor lower. Tier 1's own flush then often carries him on to the deck. Window (sweep, 5 runs a step): a knock from about 1.5 s before the gate opens up to the opening holds for all three behaviours. A knock earlier in the day holds only if he stays down, because he walks out before the wave comes. A knock after the opening misses (0-2/5): the wave has already passed his spot. The station times the knock about 1 s into the tell.
- Chain 3, cannon -> top channel -> spills -> rim: **10/10** fired so he lands during the tell; **10/10** fired late (he lands after the first surge; the second takes him). Yaw jitter +-1 deg.

**STAND-INs:** the shared clock (the greybox's `tick` calls `trigger()` at base period x multiple + offset, minus the tell); the stairs are ramps (26.6 deg); the "rope bridges" are plain boxes; the belfry is a block with no bell (no ring noise); the exit rim is the start deck; chain 3's head is the player climbing into the cannon (the cannon cannot catch a thrown body). **Not built:** the tower_shell wall-kick chimney, the falling-water sheet between tiers, the carved gate leaf, the inhaler-head variant of chain 3.

**Engine changes still needed:**
- **Cannon catch** (scripts/cannon/cannon_field.gd): a tumbling or tossed body that meets a cannon's mouth is loaded ("inside") and fired at the cannon's set aim after a short beat. That turns chain 3 into the card's "anything thrown at the isle is relaunched into the top channel". Today the player must climb in himself.
- **A shared sluice clock** (kit ask 1): trap_sluice driven by an external clock, with a per-flush "double surge". The greybox does this from outside today (timer trigger with an infinite period, `configure({"second_wave":...})` before each `trigger()`).
- Not needed for these chains, but the card assumes them: the sluice pushing an airborne body (it skips anything not grounded, `_sweep`), and the wave carrying the ram (only the pilot is carried, so "a dodge near the lip sends the bull over" happens only by the ram's own teeter).

**Distances changed from the card.** Channels are 20 / 24 / 20 m long (sluice default 28.8) and 3.0 m wide (default 1.5). Tiers are 12 m apart (eight of his top jumps, not ten). The stair-and-bridge loop makes the footprint about 110 x 25 m, plus the cannon isle 20 m north of the top, not 30 x 30.
