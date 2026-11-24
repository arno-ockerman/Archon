#!/bin/sh
# TEMPORARY stopgap for software-factory#43 on an image-only deployment (no source
# checkout on the host). Upstream fix: https://github.com/coleam00/Archon/pull/6142
#
#   fetch.sh <dest-dir> <container>
#
# 1. Refuses unless <container> still ships the exact v0.14.0 originals.
# 2. Downloads the two patched files, pinned to one commit, into <dest-dir>, and
#    refuses unless their checksums match.
# 3. Prints the read-only bind mounts to add to the archon service.
set -eu

DEST="${1:?usage: fetch.sh <dest-dir> <container>}"
CONTAINER="${2:?usage: fetch.sh <dest-dir> <container>}"
COMMIT="c6dcbf0af5bc3430843a660c658ce3ff2235b067"
RAW="https://raw.githubusercontent.com/arno-ockerman/Archon/$COMMIT/deploy/arno/patches/sdlc-publish-pr-v0.14.0"
PACK=/app/.archon/workflows/sdlc/pr

check_original() { # <path-in-image> <sha256>
  got="$(docker exec "$CONTAINER" sha256sum "$1" | cut -d' ' -f1)"
  if [ "$got" != "$2" ]; then
    echo "ERROR: $1 in $CONTAINER is not the v0.14.0 file this patch replaces ($got)." >&2
    echo "       Already patched, or a different Archon version: do not mount." >&2
    exit 1
  fi
}
check_original "$PACK/scripts/publish-pr.ts" 9711a7c99c4dedd7d77f61af75cd85d37950c93050fe4a2896e602846c20305e
check_original "$PACK/commands/pr.md"        f321d4495e64088f2eff83d5c04a4684d6d28db31fc59ef7b52446facf85b0e6

mkdir -p "$DEST"
fetch() { # <name> <sha256>
  curl -fsSL "$RAW/$1" -o "$DEST/$1.tmp"
  echo "$2  $DEST/$1.tmp" | sha256sum -c - >/dev/null
  chmod 0644 "$DEST/$1.tmp"
  mv "$DEST/$1.tmp" "$DEST/$1"
}
fetch publish-pr.ts 1b848c3e4a3a94f6682f2f2709c65b6397b8060188119944ebfc0e363826d509
fetch pr.md         b2203f44664d8d4100195513dea6b68c07027d9d7c62a2d4ef1f0551c80bc098

DEST_ABS="$(cd "$DEST" && pwd)"
cat <<MOUNTS
OK: patched files in $DEST_ABS. Add to the archon service's volumes, then recreate it:

      - $DEST_ABS/publish-pr.ts:$PACK/scripts/publish-pr.ts:ro
      - $DEST_ABS/pr.md:$PACK/commands/pr.md:ro
MOUNTS
