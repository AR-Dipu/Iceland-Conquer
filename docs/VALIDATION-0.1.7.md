# Validation — 2026-11-16

## Automated checks

- Full world/campaign suite: 16,361 checks passed across 176 country geometries and all roster sizes.
- Existing gameplay and revival: 190 checks each passed (overlapping coverage).
- Economy: 23; names/map: 9; demo timing: 5; trail geometry: 4 checks passed.
- Shoreline/substep suite: 25 checks passed; coastline recovery: 75 scenarios passed.
- Exact-area capture fixture: 11 checks passed. Expected new area 17,200 and total ownership 20,800 were preserved; duplicate preview was non-mutating, an open bridge awarded no area, enclosed rival land transferred, self-crossing faces resolved, and an overbudget topology preserved ownership.
- Newcomer/first-choice/minimap suite: 13 checks passed, including the 40% boundary, roster cap, new stable ID, neutral ownership, 30-second timing, pause, and restart.
- Shared minimap geometry and viewport-corner tests passed at both portrait sizes.
- Productive-expansion simulations passed on all five original maps; every opponent captured land and continued moving in the final ten seconds.

## Matched strategy measurements

Both planners used identical seeded initial arrangements, unchanged speeds and the corrected capture rules. No enemy elimination was simulated, so territory expansion can be compared independently of elimination. Results are combined opponent ownership, not a guaranteed single-opponent win rate.

| Country | Old 2 min | New 2 min | Old 5 min | New 5 min | Net 2-min gain ratio |
|---|---:|---:|---:|---:|---:|
| Bangladesh | 4.46% | 19.54% | 9.24% | 41.30% | 5.38x |
| India | 7.83% | 10.79% | 22.06% | 40.36% | 1.43x |
| Sri Lanka | 13.23% | 46.42% | 25.69% | 70.81% | 3.70x |
| Japan | 5.13% | 8.12% | 11.26% | 29.70% | 1.82x |
| Iceland | 7.59% | 33.96% | 14.09% | 61.00% | 4.87x |

Median net two-minute gain ratio: 3.70x (target >=2x), with no map regression. Raw initial/final ownership and capture counts are in strategy-0.1.7-results.json. Tests establish expansion effectiveness, not exhaustive competitive balance across every country.

## Android and limits

Built/aligned/signed APK; installed over the existing package in a no-window Android 35 x86_64 emulator using host GPU. Internal campaign/gameplay inspection at 720x1280 and 720x1600; no game window opened on the desktop. Installed version 0.1.7/code 8, package com.islandconquer.prototype. Runtime log showed only a nonfatal cached-shader recompilation warning, with no GDScript errors in the smoke check.

APK SHA256: C1CF90F6F21B3C61CB8FCFC451A5DF07EDA0CD444073CEDB0034D5A169024232.

Physical-device FPS/battery use, all 176 countries on real hardware, and adversarial multiplayer are not measured. Local wallets remain practice-only. Arrival behavior is covered by headless integration tests; real advertising/server verification is not part of this build.
