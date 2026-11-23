# Country Conquer 0.1.14 candidate

The signed APK is `builds/android/country-conquer-v0.1.14.apk`. Android verified package `com.islandconquer.prototype`, version code 15, and the existing signing certificate.

All 18 Godot regression suites passed, including the 698-check campaign suite. The separate importer tests passed for geographic surface-area ranking, detached land, Honshu, and date-line stitching. See `tests-0.1.14.log` and `dev/test-connected-land.cjs`.

The no-window Android emulator upgraded directly from 0.1.13. The campaign and wallet contents matched before and after install, and the wallet still contained 180 coins after gameplay checks. The emulator profile had no explicit equipment file. Owned-character and equipment persistence, replay, and revival are covered by the headless collection suite. See `upgrade-0.1.14.json`.

Hard Bangladesh at 720×1600 was measured with SurfaceFlinger presentation timestamps. Three seven-second intervals ended in active gameplay, confirmed by screenshots. Their frame-time p95 results were **37.39**, **33.18**, and **35.16 ms**. The median of the three p95 results was **35.16 ms**, above the **32.6 ms** target. Three separate 30-second runs included time on the defeat screen and were excluded from the active-play assessment. Physical-device performance remains unverified.

Raw timing data is in `frame-pacing-0.1.14-active-*.json`. All Android checks ran with the headless emulator and no desktop game window.
