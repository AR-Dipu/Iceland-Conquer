# Country Conquer 0.1.17

Android version code 18. Package com.islandconquer.prototype and the existing signing certificate and save location are retained.

## Flag terrain

The bundled artwork comes from [country-flags](https://github.com/hampusborgos/country-flags). The upstream source archive SHA-256 is 1780AD98C95D9436620967D4AB3E88919EFD0A0DEBA8E773D2EEB0D4F5C5FD88. Campaign IDs map to Natural Earth ISO_A2 or ISO_A2_EH values, with explicit entries for France, Norway, and Kosovo. An art mapping is present for 174 entries. Northern Cyprus and Somaliland fall back to the standard terrain color.

The flag is aspect-fitted around an interior point, blended into terrain at 34%, and drawn only with the exact playable land triangulation. Outside the artwork rectangle, the terrain uses its base color. The composite is prepared on load and terrain is drawn in a single pass. Detached scenery, neighboring land, and water are drawn separately. The authoritative ownership fills and minimap retain their existing geometry.

## Motion and refills

Actor sprites, shadows, and names interpolate together between physics positions. The camera follows the same interpolated player position. Capture and revival poses remain. Physics movement, speed, AI tactics, and input release use the original update path. Display border accents are softened without changing polygon fills. Exact reversed shared edges are drawn once. Boundaries split into different edge lengths can still overlap visually.

A vacancy starts a 20-second active-play interval. Each due interval attempts one neutral, safely separated spawn. The timer waits in menus, pause, defeat, and demo ads. An unsuccessful spawn uses a fresh interval. An earlier victory suppresses the due refill.

## Verification

All 20 headless suites passed. Focused checks loaded Bangladesh, India, Japan, Iceland, and Chile, compared flag meshes with the authoritative outline, and covered vacant, full, paused, and unsafe refill states across 3/5/7 rivals.

The headless Android emulator ran three 30-second active Hard samples at 720x1600 with seed 116, 117, and 118. The rendered frame-time p95 values were 30.41, 30.96, and 30.13 ms. Their median was 30.41 ms against the under-32.6 ms target. The pooled capture visibility p95 was 2 frames across 50 events, with a worst delay of 4 frames. The fixture automatically revived the player once in seed 116, and zero times in the other samples. Bot speed, acceleration, and tactics were unchanged. Gameplay differed across builds because the new refill policy changes when players return.

The initial candidate's three samples were 60.52, 61.46, and 46.95 ms p95. That candidate used a separate flag draw and higher border segment counts. Both were removed before the final benchmark. All tests used the emulator with no window. Physical-phone frame pacing remains unverified.

The emulator upgraded from 0.1.16 and then installed the optimized candidate in place. Package identity and signing certificate were verified. Saved wallet, campaign and equipment files stayed byte-identical at each install. The wallet kept its 180-coin balance.

- [Headless suites](tests-0.1.17.log)
- [Final timing samples](frame-comparison-0.1.17.json)
- [Capture and simulation timing](performance-phases-0.1.17.log)
- [Final install evidence](upgrade-0.1.17.json)

## Portrait review

Inspected battle screenshots for Bangladesh, India, Japan, Iceland, and Chile at 720x1280 and 720x1600. Terrain remained distinct from water and neighboring land, and ownership and markers remained readable. The opening camera and country outline crop parts of some flags. Japan shows part of its red disc, and narrow Chile shows a smaller portion of its flag in the opening view.

- [Ten-screen portrait comparison](flags-0.1.17.png)
- [Signed Android APK](../builds/android/country-conquer-v0.1.17.apk)
