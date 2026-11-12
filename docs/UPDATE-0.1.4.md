# Coins and demo rewards — 0.1.4

Offline practice wallets start with 100 coins. The first completion of each country awards 25 coins. A five-second foreground-only demo can add 225 coins, for 250 total, once per country. Canceling grants nothing. No SDK or internet permission is added.

Coin revival prices are 100, 150, then 200 thereafter in the current match. Demo revivals do not increase this counter. Restart is free and preserves the wallet. Revival never steals rival land: it uses surviving player land or a neutral clipped patch. If no safe land remains, restart is available.

Wallet and claim records are stored together in user://practice_wallet.json with temporary-file replacement and a backup. Failed saves prevent payment. Local practice currency is not suitable for competitive authority or migration to a server wallet. Multiplayer remains unimplemented.

Economy tuning is in resources/economy_config.gd. The first login establishes the daily baseline without changing the starting 100; later UTC days grant 20. Backward dates are rejected. A victory after 120 active seconds grants a separate 25-coin match objective once per match.

Verification: run tests/economy_suite.gd, tests/run_suite.gd, tests/revive_suite.gd, and tests/self_trail_suite.gd with the bundled headless Godot engine. Device ad behavior is simulated, not AdMob verified.
