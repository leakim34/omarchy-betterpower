#!/usr/bin/env bash
# Lint: manifest validation (node mirror, plus the real omarchy validator when
# present), qmlformat check when installed, shellcheck for bin/ helpers.
set -euo pipefail
cd "$(dirname "$0")/.."
status=0

if [[ -f manifest.json ]]; then
  node scripts/validate-manifest.js . || status=1
  if command -v omarchy >/dev/null 2>&1; then
    omarchy plugin validate . || status=1
  fi
fi

qmlformat_bin=$(command -v qmlformat || command -v /usr/lib/qt6/bin/qmlformat || true)
mapfile -t qml_files < <(find . -name '*.qml' -not -path './.git/*' -not -path './node_modules/*')
if (( ${#qml_files[@]} )); then
  if [[ -n $qmlformat_bin ]]; then
    "$qmlformat_bin" --check "${qml_files[@]}" || status=1
  else
    echo "lint: qmlformat not found, QML formatting not checked" >&2
  fi
fi

mapfile -t sh_files < <(find bin scripts -type f -name '*.sh' 2>/dev/null; find bin -type f ! -name '*.*' 2>/dev/null)
if (( ${#sh_files[@]} )); then
  if command -v shellcheck >/dev/null 2>&1; then
    shellcheck "${sh_files[@]}" || status=1
  else
    echo "lint: shellcheck not found but shell files exist; install shellcheck" >&2
    status=1
  fi
fi

exit $status
