# Documentation pointer

Full documentation for **svc-k8s-local** lives in the central docs repo — **not here**.

- **Portal:** https://docs.devops-lab.cloud (search "svc-k8s-local")
- **Source:** `svc-docs/docs/platform / services / infrastructure/`
- **Obsidian:** open `/repos/devops-lab-new/svc-docs/docs/` as a vault

## Policy (CLAUDE.md — Documentation)

Per org policy, deployment / architecture / runbook / operational docs are **NOT duplicated
in this repo** — they live in `svc-docs` (single source of truth), which derives from the
actual code + live infra, not hand-maintained prose that drifts.

This repo carries only:
- this `DOCS-POINTER.md`
- a short `README.md` (2-3 sentence intro + quickstart + link into svc-docs)
- `openwiki/` — auto-generated per-repo CODE map for AI coding agents (refreshed from code)

If you find full architecture tables / runbooks duplicated in this repo's `README.md` or
`docs/`, they are drift — consolidate into svc-docs and replace with a link (never delete;
`git mv` history-preserving per the decommission rule).
