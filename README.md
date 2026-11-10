# Island Conquer

A Godot 4.7.2 / GDScript Android 2D visual prototype. Portrait design: 720 × 1280.

## Play

Double-click **Launch Game.cmd**. Double-click **Open Editor.cmd** to edit the project, or open project.godot in Godot 4.7.2.

- **Phone:** drag the lower-left joystick. Release to stop.
- **Desktop:** WASD, arrow keys, or drag the joystick with the mouse.
- **Capture:** leave your color, draw a loop, and return to your territory.
- **Attack:** cross a rival's exposed trail to reset them. Crossing your own trail also resets you.
- **Goal:** the first character to own 60% wins. No timer.
- **Pause:** top-right button, Escape on desktop, or Android Back. Home/focus loss also pauses.
- **Replay:** choose New Island from the pause or round-end panel.

Blue is the player; red and yellow are lightweight AI opponents. A reset clears the character's territory and trail and restores its starting patch with a brief shield. Scenery is decorative and does not block movement. Overlong trails reset to keep memory bounded.

## Android

Install **builds/android/island-conquer-debug.apk**. It contains arm64-v8a for modern phones and x86_64 for emulator testing. Package: com.islandconquer.prototype. Version: 0.1.0. This is a debug-signed APK, not a store release.

To rebuild, double-click **Build Android.cmd**. On this machine it uses the existing Android SDK and JDK 17. On another machine set ANDROID_HOME and JAVA_HOME or pass -AndroidSdkPath and -JavaSdkPath to dev/build-android.ps1. Paths and the debug key stay in the ignored tools directory.

For a fresh checkout, run dev/setup-godot.ps1 to download the pinned official editor and templates with SHA-512 verification. Install Android platform-tools, build-tools, and a compatible SDK platform separately. The current build uses SDK Platform 36 and Build-Tools 36.0.0. Standard prebuilt-template export avoids Gradle/NDK requirements.

## Structure

- scenes/: main scene and reusable character scene.
- scripts/: session coordinator, territory manager, polygon helpers, character, bot policy, trail renderer, world presentation, input, and HUD.
- resources/: typed tuning resource and default configuration.
- assets/: transparent character/scenery atlases, app icon, and OFL-licensed Fredoka font.
- tests/: deterministic geometry, gameplay, input, and simulation checks.
- dev/: repeatable Windows setup and build scripts.
- tools/: ignored local editor, export templates, signing key, and QA emulator data.
- builds/android/: generated installable APK.
- docs/: asset provenance, validation record, and rendered previews.

Tune movement speed, acceleration, colors, spawns, trail limits, protection, and the victory threshold in resources/default_config.tres using the Inspector. Geometry operates in continuous 2D coordinates; there is no tile/grid ownership model. Hole-producing subtraction is split into simple disjoint renderable polygons so ownership area remains accurate.

## Verification

Double-click **Run Tests.cmd**, or run:

    tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/run_suite.gd --quit-after 1200

The suite covers capture geometry and holes, real movement/capture, trail attacks, resets, touch/mouse/keyboard release, pause, bot simulation, victory, and replay. See docs/VALIDATION.md for completed checks and device limitations.

## Prototype boundaries

One island, two simple bots, and a minimal round loop. No progression, persistence, multiplayer, advanced tactical AI, audio production, monetization, or store-release signing. Illustrated 2D sprites supply the rounded 3D-style appearance. The reference image guides the art direction; its HUD numbers and timer are not fixed gameplay data.
