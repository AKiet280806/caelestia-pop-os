# Agent handoff

Use this short prompt when asking an AI agent to install this repository. Replace the checkout placeholder with the actual local checkout path; keep private output out of Git.

```text
Install this checkout of caelestia-pop-os on this Pop!_OS 24.04 amd64 target,
starting from the current COSMIC session. Read AGENTS.md and docs/agent/INSTALL.md.
Preserve COSMIC, cosmic-greeter, System76/NVIDIA support, networking, PipeWire,
and keyring. Run preflight and inspect the exact package simulation, pins, GPU,
and root/cache disk budgets before changes. Use the default two build jobs and
8 GiB future reserve. Carry out ordinary authorized setup steps without repeated
confirmation. Use the documented backup/manifest and stop on harmful apt removals,
missing pins, or ABI mismatch. Do not log me out, restart the display manager,
reboot, change GPU mode, or start Caelestia inside COSMIC. Tell me when I should
select Hyprland (Caelestia Pop!_OS) in cosmic-greeter's menu-icon session selector.
Then continue docs/agent/VERIFY.md, report each result and every untested case,
and preserve COSMIC recovery. Keep credentials, logs, clipboard and recordings
private. Do not claim a clean-machine GPU login test unless actually performed.
Optional features I want: [Vietnamese / HyprMod / Codex usage / none].
Scale: [1.0 or desired scale]. Encoder: [auto / libx264 / h264_nvenc].
Checkout: [local checkout path].
```

An agent continuing another agent's task should receive the record below. Keep it outside the public repository if it contains host-specific details. Sanitize usernames, home paths, account identifiers, and private application information before sharing a public issue.

```text
Target and scope:
  OS / architecture:
  Clean machine or existing configured desktop:
  Current session (COSMIC / Hyprland / greeter / unknown):
  Authorized optional features, scale, encoder:
Source:
  Repository revision:
  Exact pins verified (or missing/mismatched pin):
  Hyprland package / source ABI / matching headers:
Progress:
  Last completed runbook state S0–S8:
  Commands/stages completed and exit codes:
  Current failing command, exit code, first actionable error:
Resources:
  Cache destination and filesystem:
  Root/runtime filesystem:
  Free space, build allowance, future reserve, build jobs:
Safety:
  Apt simulation summary and any removals:
  COSMIC / cosmic-greeter / System76 power / NVIDIA preservation:
  Backup identifier and manifest location (private):
  Post-install user edits or rollback conflicts:
Evidence:
  Doctor findings:
  Actual logged-in compositor version:
  First-session cases: pass / fail / untested / not applicable:
  GPU login, portals, lock, sleep/resume, multi-monitor status:
  Private artifact locations (never attach credentials):
Next action:
  Exact next command with the original flags, or concrete blocker:
  Human action needed and why (if any):
  Independent work still possible:
```

A login handoff should be brief: installation stage and backup status; unresolved findings; the exact greeter selector/session name; how to return to COSMIC; and which live-session checks remain. Do not describe installation as fully verified before those checks. A new agent must read existing evidence before rerunning mutating stages.
