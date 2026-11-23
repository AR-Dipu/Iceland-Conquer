# Country Conquer 0.1.12 / code 13

APK candidate: [country-conquer-v0.1.12.apk](../builds/android/country-conquer-v0.1.12.apk). This document distinguishes implemented behavior from measured release gates. Outstanding gates must not be described as a fully smooth or uniformly stronger release.

## Implemented

- Aggressive Hunter tactics use acceleration-aware reachable interception timing, actual shoreline-valid paths, target closure estimates, shields and safe-return risk. Captures are interrupted for an attack only when estimated gain/time exceeds remaining capture value by 10%. Four-second commitments still cancel invalid or unsafe targets. A threatened character can counter-intercept the pursuer when it can cut first; other attackers remain part of the safety check. Existing productive frontier loops, separate corridors, emergency defense and 99% victory remain.
- Canceled interceptions can resume the interrupted conquest instead of discarding it and walking straight home. Restoration requires unchanged ownership, a still-owned return, a shoreline-valid joining segment and a first-return excursion with no more than 10% reverse overlap. Ownership loss, capture, emergency defense and resets invalidate the stored route. The focused regression executes the tactical interruption/cancellation and verifies the resumed route actually captures useful area.
- Shared tactical state/route caches, indexed trail scans and the existing 2 ms soft expansion-work queue bound repeated analysis. All difficulties use the same decisions and speeds; only counts differ. No invulnerability, teleportation or artificial land was added.
- Immutable polygon bounds, triangulations and areas are memoized with full equality guards against hash collisions and mutable-array reuse. Unrelated bounds avoid boolean calls. Capture transactions reuse exact matching completed previews and avoid subtracting owned land twice; unchanged teams need no repeated validation.
- Exact capture segment comparisons use finer 16-unit buckets. Spatial face splitting retains original pair resolution order and exact predicates, including shared endpoints. Collinear overlap, repeated vertices, islands, rival ownership and rollback remain covered.
- Territory fills, rounded overlays and boundaries are baked into cached meshes. Changed teams are prepared under a bounded render queue; main map and minimap publish one complete shared snapshot. The previous complete snapshot stays visible while preparing; at two frames the remaining work is completed synchronously. This bounds visual latency, not worst-case CPU duration.
- Common textures/materials receive a hidden loading prewarm. Campaign routes animate in a separate cached layer. The full-screen procedural ocean shader is replaced by a cached gradient.
- A shared native theme provides navy panels, purple primary/selected states, gold highlights, readable disabled/focus states and short press transitions. Country-name banners include offline silhouette emblems and dynamically fit all 176 names into two lines. Buttons reserve at least 136 logical pixels vertically, accounting for safe-area scaling to retain 48 dp at the tested 420 dpi portrait layouts.
- Country settings now show nearby muted land at real land borders and water at actual coastlines. Presentation context is bundled offline and never changes playable outlines, movement, ownership, spawns or campaign links. Japan retains Honshu playability and its existing scenery islands. Iceland remains named Iceland.
- Menus use START CONQUEST, DEFEATED!, BACK TO BATTLE, REVIVE — N COINS, RESTART — FREE, WORLD MAP, COUNTRY CONQUERED! and named rival notifications. Demo screens explicitly say no real ad is shown, display a three-second countdown and retain cancellation.
- Opt-in round telemetry records attacker-attributed cuts, captures, abandoned routes, wait/CPU time and reverse travel by expansion/attack/defense/recovery, surviving brain resets and eliminations.

## Compatibility

Package `com.islandconquer.prototype`, signing key, `Godot/app_userdata/Island Conquer` save directory and save schemas are retained. Names, wallet balances, first-country choice, conquered countries, cats, human controls, movement speeds, small starting patches, inherited connections, 3/5/7 rivals, newcomers, safe revival, free restart and three-second foreground demo rewards remain.

The no-window emulator upgrade from 0.1.11/code 12 to code 13 preserved the real Captain profile, 160 coins, Bangladesh starting target and existing conquest list exactly. See `upgrade-0.1.12-before.json` and `upgrade-0.1.12.json`. Layout fixtures use a separate debug-only profile; they never award real campaign progress or alter the real wallet.

## Verification and measurements

Evidence files:

- `tests-0.1.12.log`: full campaign roster and regression run, including 16,361 world-campaign assertions.
- `tests-0.1.12-final.log`: final affected regressions; `dev/test-0112.ps1` checks engine errors, assertions, exit codes and missing result markers.
- `spatial-0.1.12.log`: 100 seeded self-crossing/repeated-vertex contours return byte-identical faces to the original all-pairs implementation.
- The final runner additionally compares 100 complete topology results against the frozen original 0.1.11 implementation. A proposed endpoint shortcut failed this precision-edge comparison and was removed; both synchronous capture and resumable preview retain original endpoint handling.
- `contested-0.1.12.json` and `gates-0.1.12.json`: complete frozen 0.1.11 AI versus Hunter AI; seeds 190/7016/111, Bangladesh/India/Sri Lanka/Japan/Iceland, seven rivals, 120 simulated seconds, ordinary cuts, stationary human test actor, arrivals disabled for a fixed roster. A fresh final run recomputes both sides using identical shared geometry. These conditions do not establish physical-phone performance or human-opponent difficulty.
- `performance-0.1.12-baseline.json` and `performance-0.1.12-after.json`: isolated seeded Hard CPU workload, 3,600 physics steps, including synchronous mesh queries. Planning is wall-clock-budgeted, so identical seeds do not guarantee identical subsequent ownership or exact workload.
- `capture-performance-0.1.12.json`: 129 matched capture inputs sampled from Hard matches across all five original maps. The original complete 0.1.11 manager, topology and geometry are frozen in test fixtures. Each side receives identical pre-capture ownership and trails; measurement order alternates. Capture success and per-team areas agree within two square world units of native boolean precision. No rendered uploads are included. Median capture CPU fell from 10.85 to 6.31 ms; p95 fell from 38.31 to 24.59 ms (35.8% lower), passing the 30% capture-cost gate for this corpus. These remaining absolute costs can still cause hitches.
- `frame-pacing-0.1.12-baseline.json` / `after.json`: SurfaceFlinger actual-present timestamp intervals from the no-window emulator. Rendered pacing is measured separately from headless CPU time.
- `country-0.1.12-*-720x1280.png` / `*-720x1600.png`: internal selection, name edit, battle, pause, defeat/insufficient coins, demo and victory layout fixtures. Fixtures are labelled by filenames and are not evidence of a naturally earned victory.

The final 30 simulations produced 68 bot-initiated cuts versus 58 (17.2%, below the 20% target). Median net land gain rose in Japan and fell in Bangladesh, India, Sri Lanka and Iceland. Expansion reverse travel fell from 1,910 to 1,207 world units. The targeted AI-victory fixture passed. Neither side won within the contested runs. The overall AI gate remains unmet.

The full-game CPU p95 was 2.746 ms before and 2.775 ms after. The matched capture corpus passed its separate p95 target. Native geometry calls and the two-frame render publication fallback remain possible hitch sources. See `gates-0.1.12.json` for emulator frame pacing.

The final signed APK SHA-256 is `6934D9D7C06E2602C2DE2637FECE04F82C5A0833A7640B178A9E32E4F4416F02`. Android verified version 0.1.12/code 13. The signing certificate matches the previous build (`44e808f4bf258dba385a56255e7924046b3e42cd4bba3e9620b7e5fa87c990bb`). The final installation retained the 160-coin balance and campaign profile.

## Affected systems

`scripts/bot_brain.gd`, `tactical_context.gd`, `round_telemetry.gd`; `geometry.gd`, `capture_topology.gd`, `capture_topology_job.gd`, `territory_manager.gd`; `game.gd`, `ocean.gd`, `island_world.gd`; `conquest_theme.gd`, `country_banner.gd`, `country_presentation.gd`, `hud.gd`, `world_campaign_selector.gd`, fallback `country_selector.gd`; `resources/maps/country_map.gd`; new offline context data/importer; focused tests, measurement/layout helpers, export metadata and documentation. Legacy internal island identifiers remain to protect compatibility.

Physical-phone responsiveness, thermal behavior and sustained device performance remain unverified. No app/editor/emulator window was opened on the user's desktop.
