# Instructions for AI agents

This repository installs a modified Caelestia desktop alongside COSMIC on **Pop!_OS 24.04 amd64**. Start with [the execution runbook](docs/agent/INSTALL.md), then [first-session verification](docs/agent/VERIFY.md). Use [recovery](docs/agent/RECOVERY.md) for failed stages and [handoff](docs/agent/HANDOFF.md) when another agent or a human must continue.

## Scope and evidence

- Distinguish **developing this repository** from **installing on the user's target machine**. Repository development does not authorize reinstalling an already configured maintainer desktop. Use dry runs, staging directories, temporary HOME tests, and the repository tests. Never run the full installer on that host without an explicit reinstall request.
- A request to install this desktop authorizes its ordinary package, build, backup, and deployment steps. Complete authorized work without repeatedly asking permission. Report an actual blocker with its evidence; a routine next step is not a blocker.
- The new installer has not yet been validated end to end on a clean machine through a fresh GPU login. Existing desktop runtime tests, static checks, and temporary-home tests are separate evidence. Do not describe them as a clean-machine installation test.
- Treat `pins.json` as the source of exact dependency revisions and package/ABI requirements. Do not substitute a moving branch, an unverified binary, or a different compositor ABI to make a build pass. Missing or inconsistent pins are a blocker to that build.
- Record the checked-out repository revision, selected options, stage results, backup identifier, and explicit untested cases. Do not infer a successful desktop login from a successful build or `doctor` result.

## Preserve the working system

Keep COSMIC, `cosmic-greeter`, System76 power management, NVIDIA integration, networking, PipeWire, and the keyring. Never use `cosmic*` purge globs, blanket `autoremove`, or orphan-package cleanup. Do not install `power-profiles-daemon` if apt would remove System76 power management. COSMIC removal is a distinct destructive migration requiring its own explicit user scope; it is not part of this installer.

Do not replace system Python or globally replace Wayland libraries. Qt 6.11.2 and private Wayland 1.26 belong under the installer-managed `/opt` prefix; Quickshell and plugins use `/usr/local` with the intended RPATH. Do not globally mask desktop portal services. Do not change GPU mode, kernel boot options, driver packages, or display-manager configuration merely to troubleshoot this setup.

Before changes, inspect OS/architecture, free disk on both root and cache filesystems, GPU/driver/modesetting state, exact package candidates, and apt simulation. The default budget is 8 GiB of build space plus 4 GiB of installed runtime plus 8 GiB retained for future updates: 20 GiB when they share a filesystem. Default to two build jobs. Recalculate for separate filesystems and actual dependency changes; do not count one filesystem's free bytes twice.

Create and verify a versioned backup and deployment manifest before replacing managed files. Rollback restores managed configuration and refuses to overwrite post-install user edits. Shared system packages remain installed. Never bypass a rollback conflict by silently deleting the edited file.

## Protect the current session and private data

Applications launched from the shell may share its systemd control group; inspect the group before a service restart, which can terminate those applications. The independent wallpaper fallback should be used for wallpaper recovery. A visibility-remapping wallpaper experiment crashed Qt 6.11.2 and must not be reintroduced.

Do not start Caelestia inside COSMIC, restart the display manager, log the user out, reboot, or suspend their desktop. Hand login, password entry, physical display inspection, and disruptive sleep/monitor checks to the human. Continue independent read-only or repository work while those checks are pending.

Never request or store a sudo password. Use the platform's normal authentication interaction. Never copy or commit Codex authentication, `.ssh`, tokens, clipboard contents, browser history, recordings, or private logs. Sanitize local usernames and home paths in public examples and issue evidence. Inspect staged content before committing; do not stage whole home/config trees.

AI usage is optional and shows exactly one selected provider. See [AI Usage](docs/AI-USAGE.md). The Codex provider reports Codex account rate-limit information, not regular ChatGPT usage. The integration must use read-only `account/rateLimits/read`; do not consume a prompt to probe quota or copy credentials into this repository.

## Development conventions

Keep runtime source in `shell/`, native plugin source in `src/native-window-actions/`, CLI overrides in `src/cli-overrides/`, generic usage in `src/ai-usage/`, and the Codex RPC client in `src/codex-usage/`. Preserve upstream licensing and provenance. Keep human installation documentation and this agent runbook consistent with `./setup.sh --help` and the actual implementation.

Use repository tests and read-only checks appropriate to the change. Deploy tests must isolate HOME and system prefixes. A dry run must not install apt packages, add repositories, build/install into real prefixes, replace user files, or start services. After tests, report what ran and what it establishes. Do not invent test outcomes, JSON keys, service names, package versions, or paths when the implementation can be inspected.
