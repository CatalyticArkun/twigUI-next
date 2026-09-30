#!/bin/bash
# Rebuild the git repository this profile's spruce payload series is made in.
#
#   make-payload-repo.sh <spruceOS clone> <new repo dir>
#
# The base commit is what projects/twigUI/packages/twig/package.mk makes of
# spruce's source before emulators are copied in: the pinned commit, then
# install/SDCARD overlaid, then install/delete.txt. The series in this
# directory is then applied on top with git am. Edit there, and refresh the
# series with:
#
#   git format-patch --no-signature --zero-commit -o <this dir> payload-base..HEAD
#
# The new repo borrows the clone's objects (alternates), so it costs only a
# working tree.
set -e

SPRUCE_CLONE="$(cd "$1" && pwd)"
REPO="$2"
HERE="$(cd "$(dirname "$0")" && pwd)"
TWIG_PKG="$(cd "$HERE/../../../packages/twig" && pwd)"
PIN="$(sed -n 's/^PKG_VERSION="\(.*\)"/\1/p' "$TWIG_PKG/package.mk")"

[ -n "$SPRUCE_CLONE" ] && [ -n "$REPO" ] || { echo "usage: $0 <spruceOS clone> <new repo dir>" >&2; exit 2; }
[ -e "$REPO" ] && { echo "$REPO exists" >&2; exit 1; }
git -C "$SPRUCE_CLONE" cat-file -e "$PIN^{commit}" || { echo "$PIN is not in $SPRUCE_CLONE" >&2; exit 1; }

git init -q -b main "$REPO"
echo "$(git -C "$SPRUCE_CLONE" rev-parse --path-format=absolute --git-common-dir)/objects" \
    >"$REPO/.git/objects/info/alternates"
cd "$REPO"
git update-ref refs/heads/main "$PIN"
git checkout -q -f main

# package.mk's steps, verbatim in effect. Its build tree has no .git, so the
# ".git*" and ".git*/" patterns there never meet one; here they must not.
cp -rf "$TWIG_PKG"/install/SDCARD/* .
shopt -s extglob
for f in $(cat "$TWIG_PKG"/install/delete.txt); do
    for m in ./$f; do
        [ "${m%/}" = "./.git" ] && continue
        rm -rf "$m"
    done
done
# Keep git's own metadata files so git treats the tree as the spruceOS repo
# does; the series never touches them.
git checkout -q HEAD -- .gitattributes .gitignore .github
git add -A
git commit -q -m "twig payload base: $(git -C "$HERE" log -1 --format=%h -- "$TWIG_PKG") over spruce ${PIN:0:9}"
git tag payload-base

git am -q "$HERE"/*.patch
git log --oneline payload-base~1..HEAD
