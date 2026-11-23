# Country Conquer 0.1.16 performance candidate

Signed Android APK, version code 17. All 19 Godot regression suites passed, including the exact topology and polygon comparisons, capture rules, AI combat, and minimap checks. The emulator install retained the campaign and 180-coin wallet.

Capture preparation now spreads ownership-edge processing across open-trail updates and rebuilds stale preparation after an ownership change. Face splitting checks overlapping edge bounds before running the exact intersection predicate in the original order. The minimap redraws ownership only when a territory mesh snapshot publishes. Glowing trails use a soft textured halo and a bright core. Swept collision paths are reused across victims while keeping the original first-hit order. Rival speed, acceleration, and tactical behavior were preserved.

## No-window Hard gameplay

Three 30-second SurfaceFlinger presentation samples at 720×1600 ran with capture-heavy Hard Bangladesh gameplay. Each fixture logged more than 37 active seconds around the sampling interval. The debug fixture keeps the match active by immediately running the normal revival placement for the idle player after defeat. It uses an isolated profile, charges no coins, and leaves rival motion and decisions active. The three runs used 2, 2, and 0 fixture revivals, respectively.

| Seed | Frame-time p95 | Median frame time | Worst frame |
|---|---:|---:|---:|
| 116 | 33.28 ms | 16.44 ms | 149.39 ms |
| 117 | 40.47 ms | 16.90 ms | 102.48 ms |
| 118 | 31.77 ms | 16.48 ms | 115.31 ms |

The median run p95 was **33.28 ms**, so the **under-32.6 ms** gate remains unmet. Capture transaction p95 ranged from 19.85 to 41.26 ms across the three runs. Large synchronous capture transactions remain a source of hitches. These 30-second results should not be directly compared with the shorter 0.1.15 benchmark.

Evidence: `frame-comparison-0.1.16.json`, `performance-phases-0.1.16.log`, `tests-0.1.16.log`, and the three `country-0.1.16-hard-*.png` screenshots. No desktop app window was opened. Physical-phone performance is unverified.
