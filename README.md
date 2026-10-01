# Almarakah

**An early, offline third-person mobile battle-royale prototype.** Built with Godot **4.4.1**, GDScript, and original procedural graphics. Landscape Android is the primary target; a browser export preset is also included.

> This is a playable 3D design prototype, not a finished realistic game or an online 50-human service. BR has **one human and 49 bots**; CS has **two teams of four**. Ranked modes are local practice simulations with device-only ratings, not fake online queues. No accounts, payments, analytics, or backend exist yet.

This repository is separate from **Learn Islam** and **History 3D World**. It does not import, edit, or depend on either project.

## Play on your phone

**An APK is not available just because these source files exist.** First commit and push the complete project to GitHub and obtain a successful workflow run. If Actions has no successful build with an APK artifact, the download steps below are not available yet. Android and Web exports have not been verified in the local environment.

1. Open this repository's **Actions** tab → **Test and build Almarakah**.
2. Open the latest **successful** run for `main`.
3. Under **Artifacts**, download **Almarakah-Android-debug** (sign in to GitHub first).
4. Extract the ZIP in your phone's Files app. Tap `Almarakah-debug.apk`.
5. Android may ask you to allow installation from your Files/browser app. Only install builds you trust. You can disable that permission afterwards.
6. Open **Almarakah**, turn the phone sideways, choose a map, loadout and one of the four modes: **BR Classic**, **BR Ranked Practice**, **CS Classic** or **CS Ranked Practice**.

This is a debug/test APK, not a Play Store release. A new CI run can generate a different debug signing key: if Android refuses to update, uninstall **only Almarakah**, then install again. That resets local Almarakah settings. Never uninstall Learn Islam for this.

Requirements: an Android device with OpenGL ES 3 support; actual performance depends on the phone. ARM64 and ARMv7 are included. No real-device performance guarantee has been established. If the APK does not run, report your phone model, Android version and a screenshot.

## Included

| Feature | Prototype status |
|---|---|
| Name | **Almarakah** |
| BR Classic | 50 total participants: you + 49 offline bots |
| CS Classic | You + 3 allied bots against 4 enemy bots; first team to 4 round wins |
| Two maps | **Qamar Dunes**, a desert settlement; **Wadi Highlands**, a green outpost |
| BR zone | 25-second grace period, then a shrinking circle with outside-zone damage |
| Weapons | Rifle, close-range SMG and marksman loadouts with different magazine, damage, fire-rate, movement and reload profiles |
| Combat | Cover blocks shots, CS friendly fire disabled, elimination and spectator camera |
| Supplies | BR bots drop small green supply boxes; walk close for ammo/health |
| Mobile | Landscape, left joystick, swipe camera, fire, ADS, jump, reload |
| Settings | Saved camera/ADS sensitivity, optional gentle ADS aim assist, HUD scale/opacity/layout |
| HUD editor | Drag action buttons, save/reset their layout |
| BR Ranked / CS Ranked | Available as **offline ranked practice** with local device ratings; real competitive rank requires an authoritative server |

CS rounds have a 90-second limit. At timeout the team with more survivors wins; health breaks equal-survivor ties. An exact tie is a draw and adds no score. Eliminated players spectate and respawn next round. BR has no respawn.

## Controls

- **Touch:** left joystick moves; swipe empty right-hand screen to look; hold FIRE; tap ADS to toggle aim; JUMP and RELOAD buttons. MENU exits the current match.
- **Keyboard/mouse:** WASD, mouse look, left mouse fire, right mouse aim, Space jump, R reload. Escape releases the mouse so you can use MENU; click the scene to capture again.
- **Settings & HUD** are available from the lobby. Changes are local to this installation; ranked practice ratings are not transferable or globally visible.

## Work using only a phone

### Godot Android editor

Install the official [Godot Android editor](https://godotengine.org/download/android/) (standard/GDScript, preferably 4.4.1 for matching exports). Download **this repository** as a ZIP, extract it to a new `AlMarakah-Final` folder, import `project.godot`, and press Play. Later 4.x editor versions may work but are not the pinned build version. Do not import into your Learn Islam folder.

### GitHub Codespaces

Open **this repository**, choose **Code → Codespaces → Create codespace on main**. The included `.devcontainer/devcontainer.json` installs the pinned headless Godot tools. Codespaces is for code/testing/browser previews; it is not an Android emulator or a graphical Godot editor. It may use your GitHub compute/storage allowance; stop it when finished.

Inside its terminal:

```bash
export PATH="$HOME/.local/bin:$PATH"
godot --headless --editor --path . --import
godot --headless --path . --script tests/test_game.gd
```

To preview in the phone browser (first template download is large):

```bash
bash tools/install-godot.sh --templates
mkdir -p build/web
godot --headless --path . --export-release Web build/web/index.html
python3 -m http.server 8000 --directory build/web
```

Open the forwarded **port 8000** in your browser and rotate to landscape. Web builds need WebGL 2 and are not equivalent to Android performance. Keep the forwarded port private unless you intend to share it. Stop the server with Ctrl+C.

**AndroidIDE:** this is a Godot project, not a Gradle app to open directly in AndroidIDE. GitHub Actions handles APK export without needing a laptop or local Android SDK setup.

## Files

- `project.godot`, `scenes/main.tscn` — entry point, landscape and compatibility renderer
- `scripts/game.gd` — offline match lifecycle, local ranked-practice ratings, zone, rounds, shooting and supplies
- `scripts/player.gd` — third-person movement/camera, ADS and loadout stats
- `scripts/bot.gd` — simple offline AI, not network players
- `scripts/arena.gd` — deterministic procedural maps and collision-safe spawns
- `scripts/hud.gd` — lobby, touch controls, settings and HUD editor
- `scripts/settings.gd` — validated device-local preferences
- `scripts/rules.gd` — pure match rules
- `tests/test_game.gd` — headless integration/regression checks
- `.github/workflows/build.yml` — test, Android debug APK and Web export
- `docs/ROADMAP.md` — limitations and multiplayer development plan

## Verification

The regression suite runs with Godot **4.4.1** in headless mode and covers both maps, all four mode IDs, loadout profiles, actual lobby touch-event dispatch, independent move/look/fire touches, canceled touches and focus loss, HUD layout bounds, collision-safe spawns, cover/friendly-fire rules, spectator activation, respawn and a complete four-win CS match. Logs are generated locally under `build/verification/` (not committed).

The GitHub workflow is configured to import scripts, run the regression suite, export and verify an Android debug APK, and export Web. **A successful CI run and exported artifacts have not yet been verified.** Local export is blocked by missing export templates and Android SDK/Java/signing setup. Headless tests **do not** validate touch feel, GPU rendering, or phone frame rate. Those still need hands-on testing.

No third-party character/map asset packs are included. Buildings are solid cover, terrain is mostly flat, bots have local steering rather than full navigation, and the visuals are intentionally low-poly. High-fidelity models, animation, vehicles, parachuting, a buy phase, and online play are future work—not features claimed here. The three loadouts are gameplay profiles, not a replacement for licensed weapon/character art.
