# Focused winning AI — 0.1.9 / code 10

Gameplay changes are restricted to scripts/bot_brain.gd. Human controls, speeds, territory/capture rules, wallet, saves, graphics and difficulty counts are unchanged.

AI commits to safe productive loops and rejects planned routes with substantial reverse overlap. Normal failure selects a smaller loop or relocates within owned land, rather than calling the same-point legacy fallback. Failed-frontier avoidance is local and short-lived to prevent an initial dot being entirely blacklisted. Near victory, smaller loops target remaining pockets and captures crossing the win threshold receive higher utility.

Threats require credible closing motion or immediate proximity, rather than assuming any nearby enemy will attack. Defensive routes remain stable while valid. Attack pursuits persist briefly and cancel when the target closes its trail, becomes protected, or disappears. Vulnerable leading rivals and their territory gain priority. All cuts use ordinary steering/movement/collision; no privileged elimination or artificial territory is granted.

## Validation

- Focused tests passed for loop-overlap rejection, harmless-neighbor commitment, stable genuine-threat returns, protected-target cancellation, and leading-rival targeting.
- AI steered through actual human and AI trails using the game's collision resolver, causing defeat/elimination.
- AI planned, moved, and captured the final pocket in a near-win fixture, triggering the normal 99% round-over condition.
- Exact-area capture regressions: 11 passed. Coastline recovery: 75 scenarios passed.
- Signed APK installed/launched in the no-window Android 35 emulator. Runtime log showed no GDScript errors; cached-shader recompilation warning was nonfatal. No desktop game window opened. Physical devices and broad competitive balance remain unverified.

## Fixed-seed contested comparisons

Two-minute runs used matched starts/speeds, ordinary cuts, a stationary human, and fixed rosters to avoid newcomer confounding. Legacy tactics/planning switches reproduce the preceding behavior. Raw results: contested-0.1.9.json.

| Map | Old combined AI ownership | New | Old overlap score | New | Old scheduled wait | New |
|---|---:|---:|---:|---:|---:|---:|
| Bangladesh | 9.43% | 36.30% | 0.541 | 0.429 | 52.65s | 45.95s |
| Iceland | 11.51% | 18.49% | 0.364 | 0.204 | 40.00s | 47.10s |

Overlap is a heuristic reverse-segment proximity score, not a percentage of physical distance. Waiting is summed across three AI actors, not total elapsed time. Iceland recorded one successful AI pursuit/elimination and one failed pursuit; one opponent was eliminated at 51.78s. No natural match winner occurred within these short comparisons. The controlled endgame fixture establishes an actual AI win, but these measurements do not establish an improved general win rate.

APK SHA256: C96307F911AE0639BE48BE0F6686C10EAF041CF3127831F3253445E6B37FE36D. Package/signing identity retained; version 0.1.9/code 10.
