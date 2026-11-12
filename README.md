# Island Conquer 0.1.5

World campaign: 176 offline country/territory maps, continent filters, search, map zoom, neighbor conquest and fixed sea routes. Choose a starting country, save your name, and expand your frontier. All characters start with small territory dots and can cross their own trails safely. Anyone wins at 99% actual ownership, shown as 100%. Demo ads now take three foreground seconds. See docs/UPDATE-0.1.5.md and assets/maps/world-routes.json.

Persistent offline coins and demo rewards: start with 100 coins; first country completion earns 25, or 250 total after the optional five-second demo. Coin revival costs 100/150/200 per match. Restart is always free. See docs/UPDATE-0.1.4.md and tests/economy_suite.gd.

Open Launch Game.cmd to play or Open Editor.cmd to edit. Android APK: builds/android/island-conquer-debug.apk.

Choose a country and press Play. Purple is the player. Touch anywhere outside the UI, then drag from that initial point to steer. Hold to keep moving; release or return to the origin to stop. WASD and mouse dragging are supported. Capture 100% to win.

A cut tail opens Replay, Home, and Watch Demo Ad & Revive. The ad is explicitly simulated: five foreground seconds, no real ad SDK. Completing it preserves territory and revives safely with a three-second shield. Canceling grants nothing.

Run focused checks with Godot --headless --path . --script res://tests/revive_suite.gd. See docs/UPDATE-0.1.2.md and docs/test-results-0.1.2.log.

Country outlines are bundled offline from Natural Earth; pinned sources are in assets/maps/provenance.json and japan-provenance.json. Art uses the built-in imagegen workflow; generated sprite and icon assets live in assets/characters and assets/icons.
