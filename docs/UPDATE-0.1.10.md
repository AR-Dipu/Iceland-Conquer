# Country Conquer 0.1.10 / code 11

Download: [country-conquer-v0.1.10.apk](../builds/android/country-conquer-v0.1.10.apk).

## Focused changes

Modified gameplay files: `scripts/territory_manager.gd`, `capture_topology.gd`, `geometry.gd`, `game.gd`, `bot_brain.gd`, `hud.gd`, and `world_campaign_selector.gd`. Naming/build changes: `project.godot`, `export_presets.cfg`, `dev/build-android.ps1`, and `README.md`. Updated the existing capture suite; added `connections_0110_suite.gd`, `performance_0110.gd`, and `contested_0110_suite.gd`. No country assets, wallet storage schema, speeds, cat artwork or signing material were replaced.

- Renamed the launcher label, project display name and campaign title. Package remains `com.islandconquer.prototype`; the original signing key is retained. The APK filename reads the version from the export preset.
- Explicitly retained `Godot/app_userdata/Island Conquer` as the custom desktop save directory. Headless checks before and after return the identical absolute path. Android retains the package's existing internal files.
- Added an ownership-revision-aware spatial boundary cache and spatial broad phase for capture intersections. Team meshes, gradient colors and triangulation are baked only when that team's geometry changes. The minimap caches transformed triangle meshes from the same authoritative geometry, avoiding per-triangle script draw calls and triangulation failures on tiny scaled polygons.
- Limited optional expansion planning to one queued candidate per simulation frame. Tactical threat/cut decisions run before optional planning. Searches survive rival-only ownership updates; changes to a bot's own territory invalidate its work. The existing nearby-frontier shortlist and varied route search remain intact.
- Capture animations are capped at 12 pieces and use vertex alpha instead of repeated polygon booleans per animation frame.
- Completed trails between disconnected owned patches claim a 7.5-unit-wide clipped ribbon, plus actual enclosed faces. Elimination itself creates no bridge. Preview and capture deduplicate overlapping additions, remove rival ownership in the normal transaction and update the shared minimap revision.
- The AI evaluates its first real home-entry enclosure, commits to that closing route and must enter owned land before accepting its final waypoint. Existing victory utility, leader pressure, credible defensive returns, interception rules and equal difficulty tuning remain.
- Fixed a polygon-hole splitting failure exposed by long simulations: alternating split axes reduce precision traps; unresolved subtraction rejects capture/revival transactions without deleting territory. No assertion loop is used for recovery.

## Matched CPU measurements

Seed 190, Bangladesh, Hard/seven opponents, 3,600 steps at 1/60 second, fixed roster, stationary human, same speeds and spawns. Each sample includes the real physics coordinator plus ownership mesh snapshot. Headless Windows CPU costs are not Android/GPU frame times. Background emulator gameplay was stopped for the final measurement; these are single-run results, not a statistical phone performance guarantee.

| Measurement | Before | Final |
|---|---:|---:|
| Median CPU step | 1.144 ms | 0.989 ms |
| 95th percentile | 15.660 ms | 13.398 ms |
| Worst step | 80.062 ms | 46.331 ms |
| Total mesh snapshot work | 389.491 ms | 63.211 ms |

Combined AI ownership after this 60-second fixture increased from 20.11% to 29.41%. Raw measurements and replay fixture: `performance-0.1.10-baseline.json`, `performance-0.1.10-after.json`, `tests/performance_0110.gd`. The fixture times coordinator and mesh work; it does not independently attribute every capture, AI and GPU rendering cost. Physical-device performance remains unverified.

## Two-minute contested AI comparison and regressions

The prior committed planner is loaded from commit `a691774` into a test subclass. Both variants use the current corrected capture/movement rules, matched seed/spawns/speeds, seven bots, a stationary human and fixed rosters. Newcomers are disabled only in this comparison. Cuts use actual gameplay collision resolution. Waiting is summed scheduled wait, not total idle/planning time. Overlap is a reverse-segment proximity heuristic, not a distance percentage.

| Map / planner | AI land | Surviving bots | Cuts | Abandoned loops | Scheduled wait | Overlap |
|---|---:|---:|---:|---:|---:|---:|
| Bangladesh / previous | 32.35% | 4 | 3 | 2 | 72.67 s | 0.427 |
| Bangladesh / final | 31.96% | 3 | 4 | 3 | 47.13 s | 0.581 |
| Iceland / previous | 48.48% | 1 | 6 | 4 | 7.40 s | 0.207 |
| Iceland / final | 45.98% | 3 | 4 | 3 | 74.50 s | 0.375 |

No natural winner occurred in these short matches. The controlled endgame regression produces an actual AI-driven 99% victory. These measurements **do not establish universally tougher AI or a higher win rate**: land gain and overlap regress on both seeds; Iceland has fewer cuts and more summed waiting, partly with more surviving bots. Bangladesh has more cuts and less waiting. Further competitive tuning remains necessary. Raw results: `contested-0.1.10.json` and its clean log; the test requires Git and the pinned commit.

## Verification and upgrade evidence

`tests-0.1.10.log`: 886 counted assertions/scenarios, plus unnumbered AI real-cut, commitment, defense, final-win and minimap footprint suites. Coverage includes exact area, connected patches in both directions, interrupted/bent bridges, exclusive rival transfer, duplicate completion, shared mesh invalidation, planning fairness, precision recovery, shoreline corners, wallets, revival, demo duration, names, newcomers and campaign compatibility. Full-world geometry was unchanged; the 697-check quick campaign suite was used.

All five two-minute uncontested expansion simulations passed: combined AI ownership reached Bangladesh 24.50%, India 19.00%, Sri Lanka 45.20%, Japan 16.91%, Iceland 18.88%. Every opponent completed captures and moved more than 25 units during the last ten seconds; capture totals were 47/35/32/69/24. See `expansion-0.1.10.log`. This establishes productive expansion and recovery, not a contested win-rate improvement.

The existing Android 0.1.9/code 10 installation was upgraded with `adb install -r` without clearing data. After launch, saved name `Captain`, balance 140, starting country `bgd`, existing daily claims and the empty conquered-country array were unchanged. This device did not have a nonempty conquered-country history; persistent campaign claims are covered headlessly. Installed version and launcher label are checked from package metadata. Signing certificate SHA-256 is unchanged: `44e808f4bf258dba385a56255e7924046b3e42cd4bba3e9620b7e5fa87c990bb`.

Only a no-window Android 35 emulator and headless Godot were used. Portrait screenshots are saved beside this document. No desktop game window was opened. This APK retains the project's existing debug signing identity; it is not a newly provisioned store-release key. No production advertising SDK, wallet migration or competitive backend was added.

Final-build Android smoke: launched Hard with seven rivals, observed captures and the cached minimap, exercised a touch drag, and inspected 720×1280 and 720×1600 screenshots. Filtered Godot/AndroidRuntime logs contained no script, triangulation or fatal errors. Screenshots: `country-0.1.10-720x1600.png`, `country-0.1.10-gameplay-720x1280.png`, `country-0.1.10-gameplay-720x1600.png`. Raw upgrade evidence: `upgrade-0.1.10.json`. Gameplay was stopped after verification to release host resources.

Final APK SHA-256: `4621CDCE6F7576A077E54BCD8125C8B6B4D781DA5C6385F9B483D1EEDDEA3E16`.
