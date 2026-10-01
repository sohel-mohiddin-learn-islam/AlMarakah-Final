# Almarakah development roadmap

## 0.1 — Offline foundation

Two procedurally generated secular test locations; four menu modes (50-participant bot BR and 4v4 round-based bot CS, each classic plus local ranked practice); landscape touch controls; saved sensitivity/ADS assist/HUD layout; three loadout profiles; tests and reproducible Android/Web exports. Use stylized geometry to keep scope and download sizes manageable.

**Known limitations:** no online humans; ranked ratings are device-local practice data, not an account/leaderboard system; simple reactive bots can get stuck around complex cover; flat playable ground; no character animations; no CS economy/buy phase; no crouch, gyro, vehicles or parachute; no polished audio mix; no device profiling yet. The rifle, SMG and marksman options are gameplay profiles using placeholder geometry. Aim assist is a gentle adjustment inside a narrow cone during ADS, with a line-of-sight check, not auto-targeting through walls.

## Next: validate on the owner's phone

- Record phone model, OS, RAM, renderer support and measured FPS in both maps/modes.
- Check three simultaneous fingers: move + aim + fire; verify releases, app backgrounding and safe-area cutouts.
- Check settings survive app restart and HUD controls stay reachable on 16:9 and 20:9 screens.
- Adjust enemy accuracy/density, camera shoulder offset, performance and time-to-elimination.
- Add real navigation, muzzle/hit feedback, animations and accessibility/audio settings.

## Multiplayer is a separate engineering milestone

Never rename bots as real players. Keep ranked practice clearly labeled as offline until infrastructure exists; never award its device-local rating as a global competitive rank.

1. Build a **server-authoritative** 4v4 unranked mode first. Server owns movement validation, inventory, shot cadence, damage, round results and spawn rules. Clients submit input; do not accept client claims of hits or rank points.
2. Add prediction/interpolation, bounded lag compensation, disconnect/reconnect rules, rate limits and replayable match logs.
3. Evaluate a backend (for example Nakama) for authenticated sessions, matchmaking, player records and leaderboards. No backend has been provisioned in this prototype. Do not embed service secrets in the APK.
4. Load-test increasing populations (8, 16, 32, then 50) with interest management and bandwidth/CPU measurements before claiming 50-human BR support.
5. Add rank calculation from verified server results, season resets, anti-abuse controls, moderation/reporting, privacy policy and account deletion. Test matchmaking fairness; do not award competitive points for offline bot practice.
6. Use TLS for account/backend APIs, short-lived sessions, least-privilege service access, monitored dedicated servers and explicit hosting budgets. GitHub Codespaces is a development environment, not a production match host.

## Art/content milestones

Commission or license appropriate character, terrain, weapon and animation assets. Track licenses and mobile GPU budgets. Use the Islamic-inspired game name and regional secular architecture respectfully; avoid turning sacred texts, worship spaces or religious objects into targets. No licensed art or protected assets from other games should be copied.

## Release milestones

Move to a maintained engine version after testing; confirm current Android/Play requirements; choose a stable private **release** keystore and back it up securely; configure reproducible release signing through encrypted CI secrets. Debug keys in ephemeral CI are only for testing. Store publishing, age ratings, security review, real-device QA, monetization and a live-service operations plan are not completed here.
