#!/usr/bin/env bash
# Format every QML file in place with qmlformat.
set -euo pipefail
cd "$(dirname "$0")/.."
qmlformat_bin=$(command -v qmlformat || command -v /usr/lib/qt6/bin/qmlformat || true)
[[ -n $qmlformat_bin ]] || { echo "format: qmlformat not found (qt6-declarative)" >&2; exit 1; }
mapfile -t qml_files < <(find . -name '*.qml' -not -path './.git/*')
(( ${#qml_files[@]} )) && "$qmlformat_bin" -i "${qml_files[@]}"
exit 0
