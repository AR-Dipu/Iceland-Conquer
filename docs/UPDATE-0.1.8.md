# Focused AI update — 0.1.8 / code 9

Changed only BotBrain gameplay logic and the version preset; added a small tactical test fixture.

Every 0.2 seconds AI checks enemy arrival time to its exposed trail versus its own return time. A credible threat triggers a return. Nearby exposed enemy trails are considered for short safe interceptions; pursuits are canceled when the trail closes or target becomes protected/inactive. Capture routes prefer a different owned return entry at least 20 units from departure when feasible. Human controls, speed, economy, territory rules, and difficulty counts remain unchanged.

Validation: script compilation passed; 75 existing coastline recovery scenarios passed; 3 new defend/attack/cancel decision checks passed. APK exported, signed with the existing key, and verified. The tests establish decision selection, not complete contested-match behavior or guaranteed successful cuts. This version has not been installed or visually inspected on Android; sustained competitive simulations remain unverified.
