# Game Feel Review

## The core action, before and after

Hand mining is a ten-second hold. In the first build of it there was no feedback
at all -- no ring, no sound, no motion -- which makes it a wait rather than an
action.

It now has a filling arc on the seam, jitter that grows with progress, chips at
the end, a popup naming what was produced, and a burst in the item colour. The
first version drew the arc in amber on the warm amber floor and was invisible in
a screenshot; the track is now dark and the fill near-white.

## Feedback hierarchy

Intensity used to be chosen per call site. Placing a belt shook the screen at
1.6 and unlocking a machine at 2.2, which is nearly the same event to the hand.
The scale is now declared once and ordered by how often the event happens:

| Event | Frequency | Shake | Ring |
|---|---|---|---|
| Item onto a belt | constant | 0.0 | none |
| Pick something up | frequent | 0.6 | 15 |
| Hand-mine a shard | every 10 s | 0.6 | 15 + burst |
| Place a machine | deliberate | 1.3 | 24 |
| Energy reaches the core | a real gain | 2.4 | 40 |
| A machine unlocks | rare | 3.6 | 58 + burst |

The rule the table encodes: a minor event must never look stronger than a major
one, and the most frequent event must be the quietest.

## Still weak

- The player has no anticipation animation for the swing; the sprite does not
  wind up. The sheet has no frames for it, and inventing them would introduce a
  second visual style.
- Belt starvation under a short power grid is legible in numbers but not yet in
  motion.
