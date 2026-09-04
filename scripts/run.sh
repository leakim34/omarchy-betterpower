#!/usr/bin/env bash
# Link this checkout into ~/.config/omarchy/plugins/<id> and reload it in the
# running shell. The directory entry is a symlink to the repo; the validator
# only forbids symlinks inside the plugin folder. A rescan hot-reloads widgets
# only; Panel.qml (loaded through a Loader) and Service.qml are cached by the
# QML engine under their URL and only take effect after a shell restart. Pass
# --restart for those; a bare run is enough for BarWidget.qml and Model.js.
set -euo pipefail
cd "$(dirname "$0")/.."
id=$(node -p 'require("./manifest.json").id')
restart=0
section="right"
for arg in "$@"; do
  case "$arg" in
    --restart) restart=1 ;;
    left|center|right) section="$arg" ;;
    *) echo "usage: scripts/run.sh [--restart] [left|center|right]" >&2; exit 2 ;;
  esac
done
target="$HOME/.config/omarchy/plugins/$id"
mkdir -p "$(dirname "$target")"
if [[ -e $target && ! -L $target ]]; then
  echo "run: $target exists and is not a symlink; refusing to replace it" >&2
  exit 1
fi
ln -sfn "$PWD" "$target"
if (( restart )); then
  omarchy-restart-shell >/dev/null 2>&1
  sleep 2
else
  omarchy-shell shell rescanPlugins >/dev/null
  sleep 1
fi
if omarchy-shell shell listPlugins | jq -e --arg id "$id" '.[] | select(.id == $id and .enabled == true)' >/dev/null; then
  echo "run: linked $target and $( (( restart )) && echo restarted the shell || echo rescanned plugins )"
else
  echo "run: linked $target; enable with: omarchy plugin enable $id --section $section"
fi
