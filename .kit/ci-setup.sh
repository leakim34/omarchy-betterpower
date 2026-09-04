#!/usr/bin/env bash
# Installs the toolchain on a fresh Ubuntu runner: node for tests and the
# manifest validator, qmlformat for QML formatting, shellcheck for helpers.
set -euo pipefail
sudo apt-get update -qq
sudo apt-get install -y -qq nodejs qt6-declarative-dev-tools shellcheck
export PATH="/usr/lib/qt6/bin:$PATH"
node --version
