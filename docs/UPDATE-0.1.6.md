# Island Conquer 0.1.6 / code 7

The campaign is map-only: no country list, search, or continent dropdown. A larger Mercator map shows thin country lines and thicker continent/coast outlines derived from the bundled Natural Earth source. Country tap selection includes a 12-pixel nearby-shape tolerance for tiny entries; wheel/pinch zoom anchors at the gesture. Multi-finger gestures never select a country. Existing frontier locks, sea routes, wallet, pending bonuses, and difficulty controls remain.

Saved names are text with a pencil icon. Edit offers Save/Cancel. New profiles edit until the first successful save; existing stored names migrate. Names and the name_saved flag persist together, including rollback on a failed save.

ShoreMotion.solve is shared by actual character movement and opponent prediction. Swept contact projects outward velocity onto the shoreline tangent, processes up to five slides, and records the actual path. Enemy cuts and capture updates consume those segments rather than a straight frame shortcut. A small inward margin avoids repeated border contacts. Player release still clears velocity immediately.

Opponent planning tests 12 candidate frontier loops, samples useful unowned area, and scores area against path length. Failed/low-yield frontiers are temporarily avoided. Short loops remain available near narrow land. Intelligence is identical across difficulty levels; only 3/5/7 opponent counts differ. The acceleration-from-rest near-shore progress threshold and stationary triangle-edge home-route fallback were corrected. No artificial territory grants or teleportation are used.

Capture polygons are cleaned before union/rendering to remove duplicate/near-collinear vertices exposed by sustained expansion. Wallet, campaign progression, starting dots, self-trail-safe crossing, 99% victory/100% winner display, three-second demos, coin prices, and free restart are preserved.

All validation runs headlessly or in a no-window Android emulator, per the user's instruction. No new bitmap art or external ad SDK was added. Physical-device FPS and battery use remain unmeasured.
