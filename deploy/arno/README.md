# Arno's TrueNAS Archon overlay

This directory keeps Arno-specific deployment and project toolchains on top of
the upstream Archon repository. `origin` is Arno's fork; `upstream` points to
`coleam00/Archon`, so upstream upgrades remain normal Git merges/rebases.

## Images

- `Dockerfile.server`: shared Archon control-plane and common Node 22 toolchain.
- `workers/Dockerfile.makeithappen`: Java 21 plus Playwright 1.56 Chromium.
- `workers/Dockerfile.club-app`: Playwright 1.59 Chromium; Expo/Supabase remain
  project-pinned through `npm ci`.

Build all images from this directory:

```bash
docker buildx bake -f deploy/arno/docker-bake.hcl
```

## Important Archon limitation

As of Archon 0.9.0, Git repository workflows use Git worktrees and execute in
the Archon application runtime. Configurable Docker runner images are currently
for folder projects, and in-container provider support is Claude-only. Codex
container execution is not implemented yet.

Therefore the MVP deploys the shared server image for both GitHub repos. The two
project images are kept separate and reproducible now, ready for deterministic
project validation and for native per-codebase workers when Archon adds that
routing. Do not pretend they are already selected automatically per Git repo.

## TrueNAS deployment

1. Clone this fork to `/mnt/HomeNAS/appdata/archon/source`.
2. Copy `.env.example` to a host-only `.env.paths` if paths differ.
3. Keep secrets in `/mnt/HomeNAS/appdata/archon/data/.env`, never in Git.
4. Validate and deploy:

```bash
cd /mnt/HomeNAS/appdata/archon/source
docker compose --env-file deploy/arno/.env.example \
  -f deploy/arno/docker-compose.truenas.yml config --quiet
docker compose --env-file deploy/arno/.env.example \
  -f deploy/arno/docker-compose.truenas.yml up -d --build
```

Install `scripts/archonctl` as `/usr/local/sbin/archonctl` and set
`ARCHON_DEPLOY_ROOT` when the source path differs.

## Upgrade flow

```bash
git fetch upstream
git switch dev
git merge --ff-only upstream/dev
git switch arno/truenas
git rebase dev
```

Pin `ARCHON_VERSION` before rebuilding. Run the container preflight and one
read-only workflow for each project before switching production traffic.

## Project gates

Make It Happen:

```bash
npm ci
npm ci --prefix functions
npx tsc --noEmit
npm run test:ci
npm run verify
```

Club App:

```bash
npm ci
npm run lint
npm run typecheck
npm test -- --runInBand
npm run export:web
```

Deploys, Supabase migrations, Firebase changes, auth, billing and production
data mutations remain approval-gated.
