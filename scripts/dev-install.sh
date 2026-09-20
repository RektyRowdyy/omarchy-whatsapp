#!/usr/bin/env bash
# Dev-install the whatsapp plugin into the live Omarchy shell.
#
# Always a copy, never a symlink: omarchy-plugin-validate's symlink check
# runs `find "$PLUGIN_DIR" ... -type l -print -quit`, and `find` does not
# dereference a symlink given as its own path argument — it reports the
# argument itself as `-type l`. A symlinked plugin root therefore always
# fails validation (confirmed directly against the real validator, see
# android-mirror's copy of this script), so there's no point attempting one
# first. Re-run this script after each edit.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PLUGIN_SRC="$(dirname -- "$SCRIPT_DIR")"
PLUGIN_ID="io.github.rektyrowdyy.whatsapp"
PLUGIN_DEST="$HOME/.config/omarchy/plugins/$PLUGIN_ID"

if [[ -e "$PLUGIN_DEST" || -L "$PLUGIN_DEST" ]]; then
  echo "Removing existing $PLUGIN_DEST"
  rm -rf -- "$PLUGIN_DEST"
fi

mkdir -p "$(dirname -- "$PLUGIN_DEST")"
cp -r "$PLUGIN_SRC" "$PLUGIN_DEST"
# The live plugin directory is a deployment, not a checkout: dropping a copy of
# the repo's history into it doubles its size for nothing and leaves a stale
# .git that any tooling walking ~/.config/omarchy/plugins can mistake for one.
rm -rf -- "$PLUGIN_DEST/.git"
omarchy-plugin-validate "$PLUGIN_DEST"
echo "Copied to: $PLUGIN_DEST — re-run this script after edits."

omarchy-shell shell rescanPlugins
echo "Rescanned plugins. Enable with:"
echo "  omarchy plugin enable $PLUGIN_ID --section right"
