# Validation 0.1.5 — 2026-11-12

- Full-world suite: 16,361 checks passed, including all 176 country geometries, 4/6/8-character spawn layouts, dot territories, exclusive initial ownership, graph connectivity, symmetric links, profile persistence, random names, self-crossing faces, shared 99% victory, and post-win free replay.
- Opponent corner suite: 75 scenarios passed across Bangladesh, India, Sri Lanka, Japan and Iceland at every difficulty. Movement remained on-island and made progress without teleportation.
- Existing gameplay and revival suites: 190 checks each passed, including the expanded catalog (overlapping coverage).
- Economy suite: 23 checks passed, including corrupt-primary recovery and repaired-save persistence. Trail geometry suite: 4 passed.
- Dedicated demo-duration suite: 5 checks passed. Final quick campaign regression: 697 checks passed after the spawn-scenery clearance improvement.
- Signed Android APK built, installed and launched in an Android 35 x86_64 emulator using -no-window and host GPU. Package com.islandconquer.prototype, version 0.1.5/code 6. Startup/campaign/gameplay/touch-drag/pause smoke checks passed with no GDScript or Android runtime errors logged. Portrait 720x1280 and 720x1600 layouts inspected internally.

The emulator initially used SwiftShader, which reported shader linking errors. Restarting the emulator with host GPU resolved these; project rendering settings were not changed. Related upstream report: https://github.com/godotengine/godot/issues/109550 .

Physical Android hardware, sustained FPS/battery use, and all 176 maps on-device are not exhaustively tested. Automated full-world geometry/roster checks are not a substitute for those tests. No online multiplayer authority, real advertisements, or server reward verification is included.

Final APK SHA256: EC51BFE31A6BADEEE1C3EC38DD0106EBD5950625945F2DAEC49F6BA35AE62725. Rebuilt APK reinstalled successfully in the hidden emulator. No game windows are opened for continuing validation, per the user's instruction.

Screenshots under docs/android-* record internal emulator checks. The country roster/sea-route list is assets/maps/world-routes.json. Existing art provenance remains in docs/ASSETS.md; this update added code-drawn map/UI effects and a synthesized UI click rather than new bitmap artwork.
