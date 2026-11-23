# Country Conquer 0.1.13

Signed Android candidate, version code 14. The package remains `com.islandconquer.prototype` and the signing certificate matches 0.1.12. A no-window upgrade retained the Captain profile, the Bangladesh campaign, and 160 coins. See `upgrade-0.1.13.json`.

APK SHA-256 `11FA6B5F5E73B8A26F0D09E44C6DFAFBD1ED257D773C3E5C47B661BD0C61827C`.
Signing certificate SHA-256 `44e808f4bf258dba385a56255e7924046b3e42cd4bba3e9620b7e5fa87c990bb`.

- The campaign character shop sells Swift Hare, River Otter, and Atlas Turtle for 150, 225, and 300 coins. Ownership and debit share an atomic wallet claim. The equipped character is stored separately and applies its passive trade-off to the player at round start. The crowned cat remains the free default.
- The illustrated atlas uses parchment tones, ink borders, brass accents, original vector scenery and animal portraits, geographic coastlines, and translucent faction fills. Campaign zoom uses pinch or a desktop scroll wheel. Drag and tap keep their existing navigation roles.
- Capture preparation builds exact intersection data as short open trails grow. Stale ownership, long initial boundary sets, and incomplete preparation use the exact synchronous fallback. A capture remains authoritative immediately. The main map and minimap reuse meshes and publish a complete snapshot together. Moving minimap markers have their own redraw layer.
- Rivals evaluate coast-parallel loops and productive returns to another owned frontier using the existing exact preview budget. Attack, escape, and defense decisions retain the prior rules.

Headless results are in `tests-0.1.13.log`. The complete game runner includes capture precision, frozen topology, inherited connections, AI cuts and victory, wallet, shoreline, campaign, demo duration, and revival. The focused collection suite also checks failed wallet writes and prepared capture geometry. Internal screenshots at 720×1280 and 720×1600 are named `country-0.1.13-*.png`.

The identical-input capture corpus completed 143 comparisons and kept the original results within the native geometry tolerance. Capture CPU p95 fell from 28.129 ms to 18.697 ms, a 33.5% reduction. This timing covers the capture transaction and excludes drawing. See `capture-performance-0.1.13.json`.

Three isolated 30-second Hard Bangladesh runs per build at 720×1600 gave these medians of the SurfaceFlinger frame-time p95 values: **33.67 ms** for 0.1.11, **32.48 ms** for 0.1.12, and **30.64 ms** for 0.1.13. The candidate passes the 32.6 ms target and falls short of the 22.8 ms stretch target. The historical 0.1.12 result of 60.39 ms did not reproduce in these repeats. See `frame-comparison-0.1.13.json`. The two-rendered-frame capture-to-visible target and presentation timing for individual capture and elimination frames remain unverified.

Three seeds across five countries produced the following median net land gains. Values are percentage points of total map area.

| Map | Frozen 0.1.11 | 0.1.12 | 0.1.13 |
|---|---:|---:|---:|
| Bangladesh | 55.49 | 41.53 | 48.97 |
| India | 50.77 | 43.62 | 49.86 |
| Sri Lanka | 56.41 | 49.42 | 44.95 |
| Japan | 51.73 | 49.89 | 54.20 |
| Iceland | 42.15 | 32.42 | 54.30 |

Successful cuts increased from 63 to 77 against the frozen baseline, passing the 20% target. Against 0.1.12, survival fell from 37 to 27, abandoned routes increased from 191 to 208, and expansion backtracking increased from 1,207 to 2,565 world units. Neither side won within the contested samples. The targeted AI-victory test passed. The land and backtracking gates remain unmet. See `ai-gates-0.1.13.json`.

Physical-device performance is unverified.
