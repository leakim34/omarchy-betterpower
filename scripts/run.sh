#!/usr/bin/env bash
# Link this checkout into ~/.config/omarchy/plugins/<id> and hot-reload the
# running shell. The directory entry is a symlink to the repo; the validator
# only forbids symlinks inside the plugin folder.
set -euo pipefail
cd "$(dirname "$0")/.."
id=$(node -p 'require("./manifest.json").id')
target="$HOME/.config/omarchy/plugins/$id"
mkdir -p "$(dirname "$target")"
if [[ -e $target && ! -L $target ]]; then
  echo "run: $target exists and is not a symlink; refusing to replace it" >&2
  exit 1
fi
ln -sfn "$PWD" "$target"
omarchy-shell shell rescanPlugins >/dev/null
echo "run: linked $target and rescanned plugins"
