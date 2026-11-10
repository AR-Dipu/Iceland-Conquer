# Validation — 2026-11-10

## Delivered build

- Godot: 4.7.2.stable.official.ed1daf0bf.
- APK: builds/android/island-conquer-debug.apk.
- Version: 0.1.0 (code 1); package: com.islandconquer.prototype.
- APK size: 59,067,745 bytes (about 56.3 MiB).
- SHA-256: 7ba65c99a280747a26141df7df4335198724e9b66656e3c991e76bfef10b598f.
- Android minimum API 24; target/compile API 36; arm64-v8a and x86_64.
- Final APK signatures verified successfully with apksigner (v2 and v3).

## Automated checks

33/33 checks passed. Full output: test-results.log.

Coverage includes polygon subtraction with enclosed holes, correct area and ownership, smaller boundary closure, rejection of degenerate captures, swept trail intersections, stealing rival territory, repeated capture, rounded capture geometry, initial spawns, real movement followed by capture, touch ownership/release, mouse and keyboard input/release, pause/resume, rival and self trail cuts, protected respawning, player and rival victory, and replay restoration.

The final deterministic two-minute simulation ran 7,200 physics ticks and produced 30 bot captures. Ownership stayed finite and nonoverlapping, characters stayed inside the shoreline, and trails stayed within configured memory limits. Its CPU execution time is not an on-device rendering frame-rate measurement.

## Desktop rendering

Rendered successfully using the Compatibility renderer on Intel UHD Graphics 770. Inspected the running game and scripted gameplay preview. Fixed small character size, thin text, capture feedback being hidden behind territory, and aliased territory edges. Replaced the unsupported Compatibility MSAA setting with antialiased polygon-edge drawing. Rounded newly captured boundaries while keeping the ownership geometry and displayed area consistent.

Preview: gameplay.png (450 × 800), generated through the actual movement and trail code.

## Android execution

Installed and launched the final APK in a project-local Pixel 7-profile Android 15/API 35 x86_64 emulator with WHPX and host GPU acceleration.

Observed checks:

- Successful installation and launcher startup.
- Tropical scenery, character sprites, typography, ocean shader, HUD, and live territory rendering.
- Touch pause button opens the pause panel.
- Touch New Island restores initial ownership and protected spawns.
- A real joystick swipe moves the blue character; release returns the joystick to center.
- Android Back pauses and resumes instead of immediately exiting.
- All controls and the island remain visible at 720 × 1280 and 720 × 1600, with safe-area-aware placement.
- Fresh final startup remained alive and produced no Godot or AndroidRuntime error output.

Evidence: android-startup.png, android-pause.png, android-touch.png, android-tall.png, android-back.png. Earlier pause/touch screenshots document interaction checks before the final boundary-rounding change; the final startup/tall screenshots document the delivered renderer and geometry.

The initial SwiftShader software-driver test exceeded that driver's fragment uniform limit. Switching the QA emulator to the host GPU resolved rendering; clearing only the prototype's emulator data removed the cache left by the driver change. The final fresh-start log was clear.

The Android build was also regenerated successfully through the delivered dev/build-android.ps1 script. Export output: android-export.log.

## Limits

No physical Android phone was connected. Sustained frame rate, battery usage, and behavior across additional phone GPUs have not been measured. The emulator does not replace those device checks. Gameplay and AI remain prototype-level; there is one island and no save/progression system.
