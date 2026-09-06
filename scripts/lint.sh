#!/usr/bin/env bash
# Lint: manifest validation (node mirror, plus the real omarchy validator when
# present), qmlformat check when installed, shellcheck for scripts.
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
  # qmlformat output changed between Qt releases; only a version at least as
  # new as the one the files were formatted with is a valid judge. Older
  # (Ubuntu's Qt 6.4 on CI) warns and skips; formatting is enforced locally.
  qmlformat_min="6.8"
  qmlformat_ver=""
  if [[ -n $qmlformat_bin ]]; then
    qmlformat_ver=$("$qmlformat_bin" --version 2>/dev/null | awk '{print $2}')
  fi
  if [[ -z $qmlformat_bin ]]; then
    echo "lint: qmlformat not found, QML formatting not checked" >&2
  elif [[ "$(printf '%s\n' "$qmlformat_min" "$qmlformat_ver" | sort -V | head -1)" != "$qmlformat_min" ]]; then
    echo "lint: qmlformat $qmlformat_ver is older than $qmlformat_min, QML formatting not checked" >&2
  else
    # qmlformat has no --check: compare its output with the file on disk.
    for f in "${qml_files[@]}"; do
      if ! diff -q <("$qmlformat_bin" "$f") "$f" >/dev/null; then
        echo "lint: $f is not qmlformat-formatted (run scripts/format.sh)" >&2
        status=1
      fi
    done
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
