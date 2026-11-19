# Island Conquer 0.1.7 / version code 8

## Capture and movement

CaptureTopology constructs a planar half-edge graph from all current owned boundaries and the vulnerable trail. It splits intersections and resolves bounded trail-connected faces, rather than selecting the smaller departure-region boundary. TerritoryManager.preview_capture is a pure operation shared by gameplay and AI. Exact departure/re-entry events are processed along actual movement segments. Open connections between disconnected patches do not grant unrelated land. Invalid geometry leaves the prior ownership snapshot intact.

ShoreMotion uses bounded movement substeps and a smaller contact inset to reduce repeated border corrections. Player touch-origin controls and release-to-stop are unchanged. Both AI prediction and movement use the same solver.

## Minimap and graphics

The main map and minimap share a revisioned territory mesh snapshot. Minimap triangles are drawn as primitives without independent polygon simplification, preventing tiny regions from disappearing or failing screen-space triangulation. Camera corners come from the inverse viewport canvas transform, and markers/frame are clipped to the minimap content rectangle.

Territory rendering includes a clipped rounded overlay, external-edge glow without shared internal seams, and a 0.45-second outward reveal highlight on newly claimed land. Display effects do not change ownership or percentages. Rendering geometry is cached until the ownership revision changes.

## Strategic opponents

The planner uses shared frontier caches, multiple loop sizes/shapes, pure capture previews, new-area-per-travel-time scores, nearby interception penalties, route commitment, and invalid-return/low-yield recovery. Proposal evaluation is spread over calls (two candidates per call). All difficulties retain identical intelligence and movement settings; only roster limits differ. Legacy planning remains available only as a benchmark switch, defaulting off.

## Campaign and newcomers

Fresh campaigns require an explicit country map tap before Confirm is enabled. Existing starts/progression are retained. Every 30 active-game seconds, one fresh opponent may fill a vacancy while human ownership is below 40%. Caps remain 3/5/7. Full rosters, paused/ad/finished rounds, and unavailable neutral space prevent arrivals. New actors receive new team IDs/names, an unused active color, a neutral patch, and a shield. Eliminated actors stay eliminated; restart clears the timer and roster, while revival preserves them.

Wallet balances, saved names, campaign unlocks, three-second demo ads, revival costs, free restart, and 99% victory shown as 100% are preserved. No advertising SDK or multiplayer backend was added. Package ID/signing key are unchanged.
