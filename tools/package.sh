#!/usr/bin/env bash
# Packs the addon into a zip the way it is unpacked into Interface/AddOns:
# four folders side by side, @project-version@ replaced.
#
#     tools/package.sh <version> [output dir]
#
# Who uses which: the release to CurseForge is built by the BigWigs packager
# in the Action, from .pkgmeta. This script is for the zip that hangs on the
# GitHub release "nightly" and for building one by hand - it packs what is in
# the FOLDER, and after the data run that is code and data. The packager
# packs what git knows, and the data are deliberately not in git.
#
# Both produce the same four folders with the same contents. Whoever tests a
# nightly is testing what the release will be.
set -euo pipefail

VERSION="${1:?version missing, e.g. v1.2.0 or nightly-20260923}"
OUT="${2:-dist}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STAGE="$(mktemp -d)"

# The four addons. The data addon must be there - a package without data
# would be a window without content.
for addon in MetaCodex MetaCodex_Data MetaCodex_Dungeons MetaCodex_Players; do
  mkdir -p "$STAGE/$addon"
done

# The main addon: only what the game needs.
# The same list as in .pkgmeta: the licence and the change notes travel with
# the addon, the READMEs and the history stay in the repository.
for entry in Core Locales Media MetaCodex.toc LICENSE RELEASE-NOTES.md; do
  [ -e "$ROOT/$entry" ] && cp -r "$ROOT/$entry" "$STAGE/MetaCodex/"
done
for addon in MetaCodex_Data MetaCodex_Dungeons MetaCodex_Players; do
  cp -r "$ROOT/$addon/." "$STAGE/$addon/"
done

test -s "$STAGE/MetaCodex_Data/Catalog.lua" || { echo "MetaCodex_Data/Catalog.lua missing - run the data collection first." >&2; exit 1; }
test -s "$STAGE/MetaCodex_Data/Recommendations.lua" || { echo "MetaCodex_Data/Recommendations.lua missing." >&2; exit 1; }

# The version into every TOC.
find "$STAGE" -name '*.toc' -exec sed -i "s/@project-version@/$VERSION/g" {} +

mkdir -p "$ROOT/$OUT"
ZIP="$ROOT/$OUT/MetaCodex-$VERSION.zip"
rm -f "$ZIP"
if command -v zip >/dev/null 2>&1; then
  ( cd "$STAGE" && zip -qr "$ZIP" MetaCodex MetaCodex_Data MetaCodex_Dungeons MetaCodex_Players )
elif command -v powershell >/dev/null 2>&1; then
  # Windows ohne zip: PowerShell kann es seit Jahren.
  # Windows-Pfade: PowerShell versteht die Bash-Schreibweise nicht.
  WSTAGE=$(cygpath -w "$STAGE" 2>/dev/null || echo "$STAGE")
  WZIP=$(cygpath -w "$ZIP" 2>/dev/null || echo "$ZIP")
  powershell -NoProfile -Command "Compress-Archive -Path (Get-ChildItem -LiteralPath '$WSTAGE' | Select-Object -ExpandProperty FullName) -DestinationPath '$WZIP' -Force"
else
  echo "neither zip nor powershell found - cannot pack." >&2
  exit 1
fi
rm -rf "$STAGE"

echo "packed: $ZIP ($(du -h "$ZIP" | cut -f1))"
