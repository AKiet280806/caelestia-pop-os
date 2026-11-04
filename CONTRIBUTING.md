# Contributing

Thank you for helping improve Caelestia for Pop!_OS. Focus changes on the supported Pop!_OS 24.04 amd64 desktop, and keep the English and Vietnamese installation guides consistent.

## Report a bug

Search [existing issues](https://github.com/AKiet280806/caelestia-pop-os/issues) first. Include the repository revision, OS, GPU/driver, display scale, selected installer options, reproduction steps and expected behavior. For installation problems, name the failing stage and include the relevant part of `./setup.sh doctor` output. Screenshots help with visual defects.

Review everything before sharing. Remove tokens, account details, private paths, application content and clipboard history. Attach focused diagnostic excerpts rather than entire home directories or session logs.

## Source layout

| Path | Purpose |
| --- | --- |
| `shell/` | Modified Caelestia QML shell and C++ modules |
| `src/native-window-actions/` | Hyprland window-action plugin |
| `src/clipboard/` | Standalone themed clipboard popup and private cliphist bridge |
| `src/wallpaper-fallback/` | Independent wallpaper recovery controller |
| `src/ai-usage/`, `src/codex-usage/` | Selected-provider usage and read-only Codex integration |
| `src/cli-overrides/` | Recording and terminal Cava adaptations |
| `configs/` | Desktop, input, portal and service configuration |
| `installer/`, `setup.sh` | Staged installer and public CLI |
| `scripts/` | Build tools and session helpers |
| `tests/` | Isolated installer and runtime behavior checks |
| `docs/en/`, `docs/vi/`, `docs/agent/` | Human and AI installation, usage and recovery guides |

Read [AGENTS.md](AGENTS.md) before changing the installer or testing against a live desktop. Do not run a full installation on an already configured workstation to test a repository change. Use temporary directories, isolated HOME tests and dry runs.

## Run checks

Install Python 3, Lua 5.4 and ShellCheck. From the repository root:

```bash
python3 -m unittest discover -s tests -v
python3 -m unittest discover -s src/codex-usage -v
python3 -m unittest discover -s src/ai-usage -v
python3 scripts/runtime-metadata.py validate
python3 tests/check_sources.py
shellcheck setup.sh installer/runtime*.sh scripts/build-plugins.sh scripts/start-* scripts/open-*
./setup.sh install --dry-run --vietnamese --with-hyprmod --with-ai-usage --scale 1.5
```

[GitHub Actions](https://github.com/AKiet280806/caelestia-pop-os/actions/workflows/checks.yml) runs these source and installer checks. They do not certify a clean-machine installation, GPU login or every optional provider. Verify desktop behavior using the [session checklist](docs/agent/VERIFY.md) when the change requires it, and state which cases remain untested.

For QML changes, also run `qmllint` with the matching Qt runtime and Caelestia/Quickshell import paths. Native window changes require the exact Hyprland ABI from [pins.json](pins.json). Keep dependency revisions, checksums and licensing notices consistent with build scripts.

## Submit a change

Keep pull requests focused. Explain the user-visible problem, resulting behavior and checks you actually ran. Update affected guides and preserve upstream copyright and license notices. Avoid committing generated binaries, build caches, credentials, development diaries or machine-specific reports.

For screenshots, use the included wallpaper and disposable demonstration windows. Keep personal content out of captures and document their provenance in [assets/README.md](assets/README.md).
