# Island Conquer 0.1.5 / code 6

## World campaign

The offline world catalog includes 176 Natural Earth country/territory entries (excluding Antarctica). This low-resolution source omits some microstates and small islands; it is not an exhaustive list of sovereign states. Source revision/license are retained in assets/maps/provenance.json. dev/import-world.cjs generates the playable geometry and the fixed graph. assets/maps/world-routes.json lists every included entry and all 24 sea connections. Borders represent the source dataset, not a statement about sovereignty.

Choose any starting target on a fresh campaign. Starting the first match locks that target until conquest. Conquered land unlocks adjacent land-border/sea-route targets. Every included target is reachable from any start. The map supports continent filtering, search, drag, wheel/pinch zoom, and animated sea links. Playable resources build on demand. The largest landmass is playable; other major islands are scenery.

Campaign/name persistence is user://campaign.cfg; existing country reward claims migrate into conquest records. Never delete this or the wallet to upgrade. The wallet remains offline practice only, with no competitive backend. Pending first-conquest bonuses can be claimed by selecting a conquered country.

## Gameplay

Every character starts with a 45-unit-radius dot (reduced for narrow land/separation). Any character wins at >=99% actual ownership, displayed as 100% for the winner. Opponent wins give no player conquest/reward. Self-trails can be crossed safely; enemy cuts remain lethal. Self-crossing capture rings are split into simple faces and their union is claimed once. Small AI excursions expand gradually. Shoreline steering uses clearance-aware probes and inward recovery, without teleporting.

Set a 1–16-character display name on the map. Opponents receive distinct generated names, avoiding the player and previous round's opponent names. Names appear on characters, in the HUD, minimap, and results.

Both demo rewards take three foreground seconds. Revival remains 100/150/200 coins; demo revival does not increase that counter. Country first completion remains 25 coins, plus 225 after the optional demo (250 total). Restart is always free. Wallet backup recovery now repairs damaged primaries and validates integer bounds. Existing saves retain balances.

## Presentation

World map highlights conquest/frontier status, with pulsing selected countries and animated sea routes. Geometry is cached and the selection display updates at a reduced rate to limit mobile work. Existing animated tropical water, soft shoreline rings, cat bobbing, shadows, trail glow, capture flashes, and smooth camera follow are retained. Added named character labels, popup fades, and quiet button sounds. No new bitmap artwork was generated.

## Tests

Run Tests.cmd invokes all suites. Tests use isolated profile paths rather than modifying normal wallet/campaign progress. Some test profile files remain under the Godot user directory for debugging. Package ID/signing key are preserved. Android build contains no advertising SDK or internet permission.
