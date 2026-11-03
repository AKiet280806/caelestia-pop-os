# Recovery and stop conditions

Preserve COSMIC and the current desktop. Do not restart the display manager, log out, reboot, change GPU mode, purge packages, or run blanket `autoremove` as part of diagnosis. Report the first error and the last completed [runbook state](INSTALL.md#state-model), then continue safe independent work.

## Package or preflight failure

If the host is not Pop!_OS 24.04 amd64, stop installation and report the detected platform. If disk is insufficient, inspect the actual cache/root/runtime filesystems and budget. Do not delete user files or shrink the future reserve silently. `./setup.sh clean-cache --yes` is for installer-owned disposable build cache; inspect its scope in `plan`/implementation first and never use it on a destination containing unrelated data. Keep backup and installed-runtime directories out of cache cleanup.

If apt simulation proposes protected package removals, stop before apt mutation and report the package list. Resolve conflicting package sources or dependencies. Do not add `power-profiles-daemon` at the cost of System76 power support. A missing exact pinned candidate is a blocker; do not allow apt to pick a newer compositor as a substitute. If an actual apt transaction is interrupted, inspect package-manager state before attempting a targeted repair. Review the repair simulation too; do not assume a generic `apt --fix-broken install` is harmless.

If driver or modesetting evidence is incompatible with startup, explain the observed state. Kernel/driver/GPU-mode remediation is separate work requiring appropriate user scope. Keep the working COSMIC session usable while diagnosing.

## Build or ABI failure

1. Read the failing stage's first actionable error and retained log. Check available disk and memory. Keep default parallelism at two jobs unless the evidence supports a different resource budget.
2. Compare `pins.json`, downloaded source revision, installed compositor package, headers, and runtime/plugin linkage. Hyprland plugins are tied to the exact compositor ABI; a plugin file existing on disk is not enough.
3. Verify private Qt/Wayland prefixes and intended RPATH. Do not fix missing libraries by overwriting distribution libraries, changing global Python, or exporting a broad global library path.
4. Correct only the identified cause, then rerun that stage with the original options. Rebuild ABI-dependent plugins together when a deliberately changed pin requires it. Revalidate the complete dependency combination before deployment.

Missing pins, changed revisions/checksums, mismatched headers, or a compositor/runtime ABI mismatch block the affected build/deployment. Do not disable plugin checks or copy a binary from another system to bypass them. Keep working installed files until the replacement has built successfully and the backup is ready.

## Deployment failure or unwanted configuration

Before rollback, read the installer's reported backup and manifest, confirm the target user, and inspect the proposed restore behavior:

```sh
./setup.sh rollback --backup latest --dry-run
./setup.sh rollback --backup latest --yes
./setup.sh doctor --json
```

Use `latest` only after confirming that it is the intended deployment. Use the recorded backup identifier when the implementation supports selecting that identifier. A successful rollback restores managed configuration from that backup; shared system packages and compiled runtimes remain. It is not an OS snapshot or an uninstall of every dependency.

Rollback must refuse overwriting files edited by the user after installation. On a conflict, retain both the user's current content and the backup privately, review the diff, and restore/merge only the intended files within user-authorized scope. Never force away edits, replace the whole `.config` directory, or hide the conflict by deleting the manifest. If a backup is missing or unreadable, stop automatic restoration and explain which managed destinations are affected; do not fabricate an original configuration.

## Failed login or broken visible desktop

The human can select **COSMIC** in cosmic-greeter's application-menu/menu-icon session selector and log in themselves. If the greeter is not reachable, give recovery instructions suited to their observed screen; do not claim a remote command restored the visible display without human evidence. The human may use a text console if comfortable, then run the configuration rollback above from the repository as their normal user with the installer's usual privilege handling.

Once back in a working session, gather focused errors from the failed Hyprland session, exact version/ABI information, and `doctor`. Keep full logs private because they may contain window titles and paths. Re-run session tests only after the cause is addressed. Do not start another shell instance inside COSMIC or globally mask portal services to make diagnostics appear green.

## When progress is blocked

A useful blocker report includes the failed command/stage and exit code, sanitized first error, observed versions/package candidates, what remains intact, and the next concrete action. Ask for user input only when it changes the outcome: a password/login interaction, a physical test, a genuinely new destructive scope, or an external approval the agent cannot grant. Do not ask the user to reconfirm already authorized normal installation steps.
