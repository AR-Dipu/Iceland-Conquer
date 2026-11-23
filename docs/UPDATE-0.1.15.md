# Country Conquer 0.1.15 candidate

The signed APK is `builds/android/country-conquer-v0.1.15.apk`, version code 16. The complete 19-suite Godot regression run passed. See `tests-0.1.15.log`.

- The 12-character roster includes free frog and fox appearances and six new premium offers from 100 coins. Rivals draw appearances from the full roster without duplicating active appearances. Faction color and movement settings are independent of appearance.
- Conquered countries can be replayed from the campaign map. The existing match objective can pay on a qualifying replay. First-conquest and demo-bonus claims remain one-time. Results display credited rewards and revival prices when applicable. The wallet total appears on the campaign page.
- Reachable human trail cuts take priority. Human encirclement routes receive priority in frontier selection and scoring, while rivals can still fight each other. Rival speed remains 210 units/s and acceleration remains 1,600 units/s².
- Encirclement victims are batched and inherited territory is merged once. Mesh preparation advances by polygon and boundary block. The battlefield and minimap publish the same ownership snapshot, while a bounded reveal pool reuses geometry.
- The arcade theme uses the original vector atlas and existing animal artwork. Shared stride, turn, capture, and revival motion, trail dissolves, a victory stamp, animated rewards, and short sound motifs provide event feedback. Elimination is shown through the trail dissolve and defeat overlay.

The emulator upgrade evidence is in `upgrade-0.1.15.json`. Both portrait sizes were checked in the no-window emulator. The emulator profile uses default equipment. The headless collection suite covers explicit equipment saves.

## Performance gates

Hard Bangladesh at 720×1600 was measured with SurfaceFlinger presentation timestamps in the no-window emulator. The three seven-second active windows ended in gameplay on each build. Frame-time p95 was 66.01, 40.52, and 44.11 ms for 0.1.14 and 34.83, 34.58, and 41.63 ms for the final 0.1.15 APK. The median improved from **44.11 ms to 34.83 ms**, above the **32.6 ms** target. The attempted 30-second samples included the defeat screen. They are excluded from the gate, and three uninterrupted 30-second samples remain unverified.

The final build logged 20 capture publications. All 20 reached the post-draw callback within one rendered frame under the instrumented fixture. This is engine-level latency. Capture-phase timing is collected separately in `performance-phases-0.1.15.log` and includes topology, transactions, encirclement transfers, mesh uploads, minimap drawing, and effects. Physical-phone performance remains unverified.
