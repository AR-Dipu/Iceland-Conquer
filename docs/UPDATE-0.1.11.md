# Country Conquer 0.1.11 / code 12

APK: [country-conquer-v0.1.11.apk](../builds/android/country-conquer-v0.1.11.apk).

## Changes

AI routes now scale to the actual open gap between owned land and the coast. They use distinct departure/return corridors, cheap area/travel/exposure estimates, exact first-return previews for the best six feasible candidates, and overlap validation after trimming. Smaller routes remain available in narrow land and final pockets. Productive loops stay committed until capture, invalidation or a credible threat; duration limits derive from route length. Failed frontier/direction choices are remembered for 15 active seconds. Successful capture gain is recorded at closure, before later ownership losses.

Existing leading-rival pressure, real trail interception, stable defensive returns and 99% victory remain. Defensive return candidates compare travel time and overlap. All difficulties share the same tuning; counts remain 3/5/7. No speed, shield, teleportation or ownership advantage was introduced.

`ShoreIndex` caches coastline segments and supplies the same exact candidate edges to movement and prediction. Active trails have spatial segment indexes. Their four rounded native strokes update when points change; glow is shader-driven. Static terrain, coast offsets and cliff drawing no longer rebuild every 80 ms merely to pulse water. Water and capture reveals animate cached geometry; capture effects are separate from authoritative territory drawing. Existing team/minimap mesh caches remain.

`CaptureTopologyJob` and `CapturePreviewJob` expose resumable `step(deadline)` and cancellation. A shared round-robin queue advances at most one exact preview per physics frame under a 2 ms **soft planning-work** budget. Native geometry calls cannot be preempted and may exceed a slice. Movement time is excluded from this allowance so slower devices cannot starve later team IDs. Jobs snapshot geometry, carry round/team ownership identity, reject stale results and publish only complete `{ok, pieces, area}` dictionaries. Actual capture commits remain synchronous and transactional. `WorkMetrics` provides opt-in phase measurements and is disabled in normal play.

Wallets, profile/campaign save schemas, inherited-territory connections, mobile controls, speeds, cats, names, free restart, revival and three-second demo ads are unchanged. Package remains `com.islandconquer.prototype`; the existing signing key and explicit original user-data directory are retained.

## Reproducible evidence

- `tests/fixtures/brain_0110.gd` freezes the **complete** previous AI, with only its class name changed. Original source SHA-256: `FF289D56F0B4726B0C93A5C7CD35432AAB3A3689C50A4D4002DCED1CCBFC98EA`; fixture SHA-256: `9C05987F83097E3D355B8CA8376E579B24C579348BB8C5293E3CF94CB845BEDC`.
- `tests/contested_0111_suite.gd`: three seeds (190, 7016, 111), five original countries, two-minute Hard matches, identical starting arrangements/speeds, stationary human, ordinary cuts and fixed rosters. Completed frozen measurements are reused unchanged rather than simulated repeatedly. The frozen budget adapter preserves the original count-based scheduling policy.
- `contested-0.1.11.json` contains all 30 rows; `gates-0.1.11.json` records the predeclared land-gain and overlap gates. Net land is final combined AI ownership minus starting ownership. Reverse distance is actual movement close to an oppositely directed active trail segment during committed expansion. Defensive/recovery returns and attack pursuits are excluded; this is not a claim of zero backtracking in every situation.
- Waiting is summed scheduled waits, not total planning or idle time. Survival, cuts, abandoned captures and winners are recorded even where they regress. The short comparison does not establish a general win rate. A separate controlled endgame fixture requires an actual AI-driven final capture and round-over.
- `tests/performance_0111.gd` replays the 3,600-step Hard fixture and measures coordinator/mesh CPU work plus opt-in phase samples. `performance-0.1.11-baseline.json` records the unmodified 0.1.10 baseline. CPU step timings are not rendered Android frame times. Phase samples are capped at 12,000 calls per category.
- `dev/measure-frame-pacing.ps1` records SurfaceFlinger presentation timestamps separately. Emulator compositor timings are observational; they are not physical-phone GPU timings or a 60 FPS guarantee.

## Validation

### Final AI results

The complete 30-row comparison passes the three AI gates. Across all 15 matched scenarios, median net combined AI ownership rose from **33.60% to 50.04%**: **48.9% higher net gain**. Every country median improved:

| Country | Previous median net land | New median net land | Gain |
|---|---:|---:|---:|
| Bangladesh | 27.97% | 47.99% | +71.6% |
| India | 39.31% | 57.34% | +45.9% |
| Sri Lanka | 38.37% | 56.30% | +46.8% |
| Japan | 28.61% | 58.81% | +105.5% |
| Iceland | 36.87% | 45.74% | +24.1% |

Median recorded reverse distance during committed expansion fell from 1,987.10 world units to zero; summed recorded reverse distance fell **99.23%**. Individual new runs still contain reversals, and the metric excludes defensive/recovery/attack travel. It does not imply every bot never backtracks. No natural winner occurred during the two-minute comparisons; the separate endgame test verifies an actual win. Some individual seeds, survival/cut counts, abandoned-loop counters and waits regress despite the improved country medians. Wait and abandonment fields are end-of-run brain-counter snapshots; elimination resets those counters, so they are not complete lifetime totals for eliminated bots. Raw rows are supplied without hiding those limits.

### Final isolated CPU results

| Hard fixture, 3,600 steps | 0.1.10 | 0.1.11 |
|---|---:|---:|
| Median CPU step | 0.977 ms | 0.625 ms |
| 95th percentile | 13.550 ms | 2.885 ms |
| Worst CPU step | 41.580 ms | 16.966 ms |
| Total mesh snapshot work | 73.221 ms | 47.009 ms |

The 95th-percentile reduction is **78.7%**, exceeding the 30% CPU gate. These are CPU coordinator/mesh measurements, not Android FPS. Current phase 95th percentiles: actual movement 8 µs, shoreline prediction 22 µs, tactical scans 590 µs, candidate generation 209 µs, preview slices 2,590 µs, capture transactions 11,181 µs, mesh uploads 2,173 µs, trail uploads 23 µs, and effect uploads 53 µs. Native operations caused a worst preview slice of 5,659 µs despite the 2 ms soft budget; the worst capture commit was 12,525 µs. Capture spikes have not been eliminated.

### Rendered emulator observations

Two separate 30-second SurfaceFlinger recordings used 720×1600 Bangladesh Hard gameplay, a stationary human, the same no-window Android 35 emulator and Intel UHD 770 host renderer, with headless simulations/builds stopped. These are observed game scenes rather than deterministic GPU replays: randomized spawn arrangements and capture progress differ.

| Presentation interval | 0.1.10 | 0.1.11 |
|---|---:|---:|
| Median | 282.569 ms | 17.761 ms |
| 95th percentile | 412.873 ms | 37.246 ms |
| Worst | 584.526 ms | 103.270 ms |
| Samples | 106 | 1,441 |

The median corresponds to approximately 3.5 versus 56.3 presentations/second in those recordings. The new run still had 140 intervals longer than 33.4 ms and a worst interval over 100 ms. This supports improved emulator frame pacing, **not** a guarantee of sustained 60 FPS or smooth performance on the affected phone. Raw timestamp files: `frame-pacing-0.1.11-baseline.json` and `frame-pacing-0.1.11-after.json`.

Focused coverage includes exact preview equivalence, canceled/stale jobs, round resets, planning fairness on slow frames, 1,024-point indexed trail sweeps, unchanged-stroke caching, separate return corridors, harmless-neighbor commitment, credible defense, leading-rival interception, real cuts against human/AI trails and an actual final-pocket win. Existing connection, exact-area capture, shoreline/corner, minimap, wallet, revival, name, newcomer, demo-duration and quick full-world campaign suites are retained.

Final `tests-0.1.11.log` is clean: 886 counted existing assertions/scenarios, plus the new async/index suite and unnumbered AI victory/minimap suites. Five additional two-minute uncontested simulations passed. The comparison/expansion logs contain no script errors. Portrait checks cover live Hard gameplay at 720×1600 and the defeat/revival popup at 720×1280 after a real opponent cut the human's exposed trail. All four defeat options remained visible, including the exact 100-coin revival price; wallet balance stayed 140. Screenshots: `country-0.1.11-gameplay-720x1600.png` and `country-0.1.11-gameplay-720x1280.png`. No script, fatal, invalid-polygon or shader-compilation errors appeared in the Android smoke check. A first-load shader-cache recompilation warning was nonfatal. Gameplay was stopped after validation to release host resources.

The five-country uncontested expansion fixture now uses the same shared planning scheduler as gameplay. It requires every opponent to capture and checks that no opponent remains persistently stalled.

All five final uncontested two-minute scenarios passed. Combined AI ownership finished at 15.05% / 41.54% / 61.23% / 25.02% / 37.35% for Bangladesh / India / Sri Lanka / Japan / Iceland. Every opponent completed captures and traveled more than 25 units during the final ten seconds. These are expansion/stall regressions, separate from the contested three-seed gates.

Only headless Godot and the no-window Android emulator are used. Physical-phone smoothness remains unverified. Final measurements, portrait screenshots, artifact hash and upgrade evidence accompany this document.

The Android install was upgraded from 0.1.10/code 11 to 0.1.11/code 12 with `adb install -r`, without clearing data. Name `Captain`, 140 coins, daily claim IDs, starting country `bgd` and the existing empty conquered array were unchanged after launch. A nonempty conquest history was not present on this emulator; campaign persistence is checked headlessly. The signing certificate remains `44e808f4bf258dba385a56255e7924046b3e42cd4bba3e9620b7e5fa87c990bb`. This retains the existing debug signing identity, not a newly provisioned store key. Raw evidence: `upgrade-0.1.11.json`.

Final APK SHA-256: `F1DC12791B51E759D4424FF2FFC4E949EABC0BEEA10D271CFCD7532B9BAD3056`.
