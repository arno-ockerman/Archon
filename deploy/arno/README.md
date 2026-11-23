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

## Temporary pack patches

`deploy/arno/patches/` holds byte-for-byte replacements for files in the upstream
image's bundled workflow packs (`/app/.archon/workflows/`). Each one is applied by a
guarded block in `Dockerfile.server` that refuses to build unless the base image's
original file has the exact checksum the patch was ported from.

- `sdlc-publish-pr-v0.14.0/` (software-factory#43): `publish-pr` pushes the branch and
  opens/continues the pull request before it checks `pr-description.md`, escapes
  reserved description markers written outside Markdown code, and fails only after the
  push when the description still cannot be written. Upstream fix: coleam00/Archon PR
  (see the commit message). Remove the block and the directory once `ARCHON_VERSION`
  points at a release that contains it.

Verify a running container carries it (prints the patched function's line):

```bash
docker compose -p archon -f deploy/arno/docker-compose.truenas.yml \
  exec -T archon grep -n "function declaredSection" \
  /app/.archon/workflows/sdlc/pr/scripts/publish-pr.ts
```

Each new run freezes its own copy of the pack, so also check the first factory run
after the rebuild: `workflow-source/runs/<runId>/bundled/workflows/sdlc/pr/scripts/publish-pr.ts`
under that run's workspace must contain `declaredSection`. Runs started before the
rebuild keep the old copy.

