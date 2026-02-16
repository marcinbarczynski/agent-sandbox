# agent-sandbox

This repository provides a Podman-based runner for launching the Codex CLI in an isolated container while working on local project files.

## What this script is for

`scripts/run-codex-container.sh` starts a container that:
- mounts your current workspace at `/workspace`
- mounts your Codex home (`~/.codex`) at `/codex-home/.codex`
- runs Codex (or a custom command) inside the container
- keeps file ownership compatible with your host user
- auto-builds the image when `Containerfile` or `container/entrypoint.sh` changes
- generates container names from workspace name + random suffix

## Quick usage

```bash
./scripts/run-codex-container.sh
```
