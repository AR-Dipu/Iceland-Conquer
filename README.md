# Country Conquer 0.1.11

Version code 12. [Android APK](builds/android/country-conquer-v0.1.11.apk). Productive frontier routes, first-return overlap validation, resumable capture previews, shared shoreline/trail indexes, and cached trail, terrain and capture-effect rendering. Human controls, speeds, economy, saves and package/signing identity are preserved. Measurements and limits are recorded in docs/UPDATE-0.1.11.md.

Previous release 0.1.10 added shared AI planning budgets, spatially filtered capture topology, per-team mesh caches, and completed-trail connections between separate owned patches. See docs/UPDATE-0.1.10.md for that release's measurements and upgrade validation.

Focused winning-AI update: committed conquest loops, credible threat detection, stable defensive returns, valuable trail interceptions, and small endgame pocket captures. See docs/UPDATE-0.1.9.md for targeted tests and contested measurements.

Full bounded-area capture, exact shoreline boundary transitions, shared minimap geometry/camera footprint, strategic frontier AI, explicit first-country confirmation, and fresh opponents filling vacancies every 30 active seconds below 40% human ownership. See docs/UPDATE-0.1.7.md and docs/VALIDATION-0.1.7.md. Existing progress and wallet saves are retained.

Map-only campaign selection, pencil-based name editing, shoreline sliding, and frontier-scored opponent expansion. Difficulty changes opponent counts only. See docs/UPDATE-0.1.6.md and docs/VALIDATION-0.1.6.md. Validation stays internal/headless or in a no-window emulator.

World campaign: 176 offline country/territory maps, continent filters, search, map zoom, neighbor conquest and fixed sea routes. Choose a starting country, save your name, and expand your frontier. All characters start with small territory dots and can cross their own trails safely. Anyone wins at 99% actual ownership, shown as 100%. Demo ads now take three foreground seconds. See docs/UPDATE-0.1.5.md and assets/maps/world-routes.json.

Persistent offline coins and demo rewards: start with 100 coins; first country completion earns 25, or 250 total after the optional three-second demo. Coin revival costs 100/150/200 per match. Restart is always free. See docs/UPDATE-0.1.4.md and tests/economy_suite.gd.

Open Launch Game.cmd to play or Open Editor.cmd to edit. Android APK: builds/android/country-conquer-v0.1.11.apk. The build script derives the filename from export_presets.cfg.

Choose a country and press Play. The crowned purple cat uses your saved name. Touch anywhere outside the UI, then drag from that initial point to steer. Hold to keep moving; release or return to the origin to stop. WASD and mouse dragging are supported. Actual ownership of 99% or more wins, displayed as 100%.

A cut tail opens free restart, Home, coin revival, and demo revival. The ad is explicitly simulated: three foreground seconds, no real ad SDK. Completing it preserves territory and revives safely with a three-second shield. Canceling grants nothing.

Run focused checks with Godot --headless --path . --script res://tests/revive_suite.gd. See docs/UPDATE-0.1.2.md and docs/test-results-0.1.2.log.

Country outlines are bundled offline from Natural Earth; pinned sources are in assets/maps/provenance.json and japan-provenance.json. Art uses the built-in imagegen workflow; generated sprite and icon assets live in assets/characters and assets/icons.
