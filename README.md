# Country Conquer 0.1.15

Version code 16. The arcade update adds 12 playable appearances, a scrollable shop, country replay, and match-specific reward reporting. See [0.1.15 verification](docs/UPDATE-0.1.15.md) and the [signed Android candidate](builds/android/country-conquer-v0.1.15.apk).

Version code 14. [Android candidate APK](builds/android/country-conquer-v0.1.13.apk). The illustrated atlas adds an animal character shop, passive abilities, and a gesture-only campaign map. Capture topology prepares intersections during excursions, and the battle map and minimap reuse the same territory meshes. See [0.1.13 verification](docs/UPDATE-0.1.13.md) for benchmark gates and device limits.

Version code 13. [Android candidate APK](builds/android/country-conquer-v0.1.12.apk). Shared navy/purple/gold theme, responsive country-name banners, geographic neighboring land and actual coastlines, reachable trail interceptions, counter-interception defense, exact geometry caches, spatial capture filtering and atomic staged map/minimap rendering. Human controls, speeds, economy, saves and package/signing identity are preserved. Release gates and remaining performance/AI limits are recorded in docs/UPDATE-0.1.12.md; a successful build is not evidence that every improvement target passed.

Run `dev/test-0112.ps1` for focused headless regressions. `tests/contested_0112_suite.gd -- fresh` compares the complete frozen 0.1.11 AI and current Hunter AI using the same shared geometry and seeds. Internal Android layouts use an isolated debug profile through `dev/internal-layout-0112.ps1`; no desktop app windows are needed.

Previous release 0.1.10 added shared AI planning budgets, spatially filtered capture topology, per-team mesh caches, and completed-trail connections between separate owned patches. See docs/UPDATE-0.1.10.md for that release's measurements and upgrade validation.

Focused winning-AI update: committed conquest loops, credible threat detection, stable defensive returns, valuable trail interceptions, and small endgame pocket captures. See docs/UPDATE-0.1.9.md for targeted tests and contested measurements.

Full bounded-area capture, exact shoreline boundary transitions, shared minimap geometry/camera footprint, strategic frontier AI, explicit first-country confirmation, and fresh opponents filling vacancies every 30 active seconds below 40% human ownership. See docs/UPDATE-0.1.7.md and docs/VALIDATION-0.1.7.md. Existing progress and wallet saves are retained.

Map-only campaign selection, pencil-based name editing, shoreline sliding, and frontier-scored opponent expansion. Difficulty changes opponent counts only. See docs/UPDATE-0.1.6.md and docs/VALIDATION-0.1.6.md. Validation stays internal/headless or in a no-window emulator.

World campaign: 176 offline country/territory maps, continent filters, search, map zoom, neighbor conquest and fixed sea routes. Choose a starting country, save your name, and expand your frontier. All characters start with small territory dots and can cross their own trails safely. Anyone wins at 99% actual ownership, shown as 100%. Demo ads now take three foreground seconds. See docs/UPDATE-0.1.5.md and assets/maps/world-routes.json.

Persistent offline coins and demo rewards: start with 100 coins; first country completion earns 25, or 250 total after the optional three-second demo. Coin revival costs 100/150/200 per match. Restart is always free. See docs/UPDATE-0.1.4.md and tests/economy_suite.gd.

Android APK: builds/android/country-conquer-v0.1.12.apk. The build script derives the filename from export_presets.cfg. Validation uses headless checks and a no-window emulator.

Choose a country and press Play. The crowned purple cat uses your saved name. Touch anywhere outside the UI, then drag from that initial point to steer. Hold to keep moving; release or return to the origin to stop. WASD and mouse dragging are supported. Actual ownership of 99% or more wins, displayed as 100%.

A cut tail opens free restart, Home, coin revival, and demo revival. The ad is explicitly simulated: three foreground seconds, no real ad SDK. Completing it preserves territory and revives safely with a three-second shield. Canceling grants nothing.

Run focused checks with Godot --headless --path . --script res://tests/revive_suite.gd. See docs/UPDATE-0.1.2.md and docs/test-results-0.1.2.log.

Country outlines are bundled offline from Natural Earth; pinned sources are in assets/maps/provenance.json and japan-provenance.json. Art uses the built-in imagegen workflow; generated sprite and icon assets live in assets/characters and assets/icons.
