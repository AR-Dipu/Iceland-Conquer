# Validation 0.1.6 — 2026-11-12

Headless checks: full world/campaign suite 16,361 passed; shoreline suite 9 passed; name/map suite 9 passed; economy suite 23 passed; demo-duration suite 5 passed; existing trail geometry suite 4 passed. Existing gameplay and revival suites each cover 190 checks (overlapping coverage). Shoreline corner scenarios: 75 passed across five countries and all difficulties.

Fixed-seed, 120-second simulated uncontested expansion (real movement/capture; no opponent elimination):

| Country | Initial combined opponent ownership | Final | Captures | Captures per opponent |
|---|---:|---:|---:|---|
| Bangladesh | 1.01% | 9.25% | 42 | 13 / 17 / 12 |
| India | 0.97% | 3.68% | 29 | 5 / 12 / 12 |
| Sri Lanka | 0.92% | 14.24% | 45 | 15 / 18 / 12 |
| Japan | 1.48% | 9.77% | 49 | 13 / 22 / 14 |
| Iceland | 0.78% | 9.04% | 44 | 10 / 15 / 19 |

All opponents captured land and traveled more than 25 world units in the final ten seconds; observed final-window distances were 340–849 units. These simulations establish progress and recovery, not full-match competitive balance or sustained mobile FPS.

APK built, aligned, signed and installed over the existing package in a hidden Android 35 x86_64 emulator with host GPU. Map-only and name display/edit layouts inspected at 720x1280 and 720x1600. No app windows opened on the desktop. Physical Android devices are untested. Cached-shader recompilation warnings in the emulator are nonfatal.

Package: com.islandconquer.prototype. Version: 0.1.6 / 7. Existing signing key retained.

APK SHA256: 6B42F6EEAD2CA8D879A7A553FACE309D9ECE1940E32E5686932F4BB5B123E4BA.
