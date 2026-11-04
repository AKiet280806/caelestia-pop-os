# Agent execution runbook: COSMIC to Hyprland

Read [../../AGENTS.md](../../AGENTS.md) first. This runbook is for a user-authorized installation on a target machine. For repository development, run only isolated tests and dry runs. Initial support is Pop!_OS 24.04 on amd64. A full fresh-machine GPU login remains unverified; carry that limitation into every result report until such a test is actually performed.

## State model

Advance only when the exit evidence for the current state exists. A failed stage leaves the last successful state intact; diagnose the first error before rerunning it. Keep a small private execution record outside the repository. Store command exit codes and sanitized summaries rather than an indiscriminate terminal transcript.

| State | Action | Required evidence before advancing |
| --- | --- | --- |
| S0: target identified | Inspect checkout and host | Target user, OS/architecture, repository revision, current session, requested options |
| S1: preflight complete | `preflight`, disk/GPU/package inspection | Supported OS, enough free space by filesystem, exact dependency pins, driver/modesetting findings, apt simulation with no harmful removals |
| S2: plan reviewed | `plan` with intended options | Concrete packages, third-party source, build/install prefixes, managed file destinations, cache, resource budget, selected optional features |
| S3: packages ready | `packages --yes` | Successful package stage, expected Hyprland package and matching headers, preserved COSMIC/System76 packages |
| S4: runtime ready | `runtime --yes` | Successful pinned private runtime and Quickshell build/install, expected linked libraries |
| S5: plugins ready | `plugins --yes` | Successful plugin build against exact installed compositor/runtime ABI |
| S6: deployed | `deploy --yes` | Versioned backup and manifest, installed files, user services/session entry, successful `doctor` or explicit unresolved findings |
| S7: login pending | Give the human session instructions | Human knows how to select Hyprland and return to COSMIC; no automatic logout/reboot |
| S8: session checked | Run [VERIFY.md](VERIFY.md) after human login | Actual session evidence and per-case pass/fail/untested results |

`install --yes` performs the installation stages together. Prefer it for a normal uninterrupted install; use the individual stages to isolate a failure or inspect boundaries. Do not issue both flows blindly. Every mutating invocation should use the same chosen options, especially cache, encoder, scale, and optional features.

## S0: identify the target

Work from the checked-out repository root. Read `README.md`, `pins.json`, and `./setup.sh --help`; inspect the current implementation if a command differs from these documents. Record the source revision if the checkout has Git metadata. Do not assume a development workspace is the authorized install target.

Useful read-only host evidence:

```sh
cat /etc/os-release
dpkg --print-architecture
printf '%s\n' "${XDG_SESSION_TYPE:-unknown}" "${XDG_CURRENT_DESKTOP:-unknown}"
findmnt -T /
df -h /
lspci -nnk
```

Expected platform: Pop!_OS 24.04 and `amd64`. The session may still be COSMIC. A different distribution, release, or architecture is a stop condition for installation; report what was found and continue only independent repository work. Do not override the guard because the underlying Ubuntu release looks similar.

## S1: preflight and package safety

```sh
./setup.sh preflight --json
```

Require a successful exit and inspect every reported warning or failed check. Do not depend on guessed JSON field names. If the tool omits a required observation, collect that observation read-only and retain it with the preflight result.

Choose the cache destination before evaluating disk. For a custom destination, use `--cache-dir /path/to/cache` consistently. Inspect its containing filesystem using `findmnt -T` and `df` after resolving the existing parent if the destination does not yet exist. Include both `/opt` and `/usr/local` destinations in the root/runtime accounting when they are on separate mounts.

The default assumptions are `--jobs 2 --reserve-gib 8`: 8 GiB build allowance, 4 GiB runtime allowance, and 8 GiB future free-space reserve. On one filesystem, require at least 20 GiB available before proceeding. On separate cache/runtime filesystems, assign each cost to its actual filesystem and preserve the declared reserve. More free space may be required by existing apt operations or dependency growth. Lowering a reserve changes the user's recovery/update margin; report the chosen budget rather than silently bypassing it. A full filesystem is a stop condition, not a reason to delete unrelated files.

Inspect GPU and active drivers. On NVIDIA, read `nvidia-smi` and `/sys/module/nvidia_drm/parameters/modeset` when available; expected modesetting is enabled (`Y` or `1`). Absence of `nvidia-smi` on a non-NVIDIA machine is not a failure. Distinguish missing tools, unloaded drivers, and disabled modesetting. Report a driver/modesetting blocker without changing GPU mode or boot configuration. Do not run a driver upgrade as an incidental dependency fix.

The initial Hyprland ABI is 0.57.0 from the third-party `cppiber/hyprland` PPA; the expected Debian build is `0.57.0-1ppa3` with matching headers. The exact compositor source commit and all other source pins must match `pins.json`. Inspect apt candidates and the installer's exact apt simulation. If needed, run `apt-cache policy` and `apt-get -s install` against the exact package/version list from the plan; never improvise a partial simulation and present it as the complete transaction.

**Stop before package mutation** if apt proposes removing COSMIC, `cosmic-greeter`, System76 power/NVIDIA support, networking, PipeWire, or keyring packages; if a required exact candidate is absent; or if headers and runtime come from different ABI builds. Keep the simulation output private and share a sanitized package list. Resolve dependency/source conflicts or pin errors before rerunning. Never accept apt removals merely because `--yes` is available. Do not add an unplanned repository, downgrade the compositor, or install `power-profiles-daemon` to force resolution.

## S2: review the concrete plan

A conservative example:

```sh
./setup.sh plan --json --scale 1.0 --encoder auto --jobs 2 --reserve-gib 8
./setup.sh install --dry-run --scale 1.0 --encoder auto --jobs 2 --reserve-gib 8
```

Add `--vietnamese`, `--with-hyprmod`, and `--with-ai-usage` only when requested or within the user's accepted setup scope. `--encoder` accepts `auto`, `libx264`, or `h264_nvenc`. Hardware encoding requires appropriate hardware/driver support; do not label `auto` as verified hardware encoding until the produced recording is inspected.

Check the plan against the authorized target and exact pins. Qt 6.11.2 and private Wayland 1.26 use an `/opt` prefix. Quickshell and plugins install under `/usr/local` with the intended RPATH. Confirm managed configuration destinations and the backup/manifest mechanism before deployment. A dry run is planning evidence only; it cannot establish build success or working GPU login.

The third-party PPA is an actual trust/dependency choice. Include it in the concrete plan and final report. Do not replace it with an arbitrary mirror when unavailable. A missing pin, mismatched checksum/revision, or changed package candidate blocks that dependency until corrected and revalidated.

## S3–S6: execute once, verify each result

For the ordinary full setup, repeat the chosen options exactly:

```sh
./setup.sh install --yes --scale 1.0 --encoder auto --jobs 2 --reserve-gib 8
./setup.sh doctor --json
```

For stage-by-stage recovery or diagnosis, use:

```sh
./setup.sh packages --yes --scale 1.0 --encoder auto --jobs 2 --reserve-gib 8
./setup.sh runtime --yes --scale 1.0 --encoder auto --jobs 2 --reserve-gib 8
./setup.sh plugins --yes --scale 1.0 --encoder auto --jobs 2 --reserve-gib 8
./setup.sh deploy --yes --scale 1.0 --encoder auto --jobs 2 --reserve-gib 8
./setup.sh doctor --json
```

For a custom cache or optional feature, include its flag in every relevant invocation. Stop at a nonzero exit. Identify the failing stage and first actionable error, inspect the retained build log privately, and check free space before retrying. Do not rerun the whole installation to conceal a partial failure. Use [RECOVERY.md](RECOVERY.md) for build and deployment failures.

Before advancing past deployment, verify the backup identifier, manifest, and installed session entry actually exist as reported by the tool. Retain the backup identifier privately. Validate service definitions without starting the shell in COSMIC. If `doctor` reports no active Hyprland instance before first login, record it as session-dependent and pending; do not start Hyprland inside COSMIC to satisfy the check. Other failed checks require diagnosis.

## S7: human login boundary

Tell the human that installation is ready for a session test and include any unresolved findings. Let them save their work and log out themselves. In **cosmic-greeter**, select **Hyprland (Caelestia Pop!_OS)** using the **application-menu/menu icon** session selector. Do not describe a GDM gear icon. They enter their own password and inspect the display.

Do not restart the display manager, log out, reboot, or type a password for them. Keep COSMIC available in the same selector as the recovery session. While login is pending, continue independent documentation, static validation, or evidence review. After the human reports successful login, continue with [VERIFY.md](VERIFY.md); the session is not verified merely because the greeter listed it.

See [AI Usage](../AI-USAGE.md) for provider selection and setup.
