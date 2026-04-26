#!/usr/bin/env bash
# check-host-deps.sh — verify host-tool prerequisites for the cdf plugin.
#
# Both cdf-profile-snapshot and cdf-profile-scaffold use a PyYAML-frei
# POSIX toolchain for YAML/JSON extraction. This script verifies the
# required binaries are on PATH and prints their resolved versions, or
# exits 1 on the first missing dependency.
#
# Usage:
#   bash plugin/scripts/check-host-deps.sh
#
# Exit codes:
#   0 — all required tools present
#   1 — first missing tool printed as "MISSING: <name>"

set -e

required=(yq jq python3 bash)

for tool in "${required[@]}"; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "MISSING: $tool"
    case "$tool" in
      yq)      echo "  install: brew install yq  /  apt install yq  (mikefarah variant, ≥ 4.x)" ;;
      jq)      echo "  install: brew install jq  /  apt install jq" ;;
      python3) echo "  install: brew install python3  /  apt install python3  (stdlib only — no PyYAML needed)" ;;
      bash)    echo "  install: bash 4+ or zsh — should already be present on macOS 11+/Linux" ;;
    esac
    exit 1
  fi
done

# yq variant check: mikefarah's Go yq vs kislyuk's Python yq differ on
# subcommand surface. We use the Go variant. Distinguish by --version
# format: mikefarah prints "yq (https://github.com/mikefarah/yq/) version v4.x.x"
# while kislyuk prints "yq 3.x.x".
yq_version_line=$(yq --version 2>&1 | head -1)
if ! echo "$yq_version_line" | grep -q "mikefarah"; then
  echo "WARNING: yq found but may not be the mikefarah variant"
  echo "  yq --version output: $yq_version_line"
  echo "  the cdf skills require mikefarah/yq (Go, v4.x); kislyuk/yq (Python) is NOT compatible"
fi

echo "OK — host-tool prerequisites met:"
echo "  yq:      $(yq --version 2>&1 | head -1)"
echo "  jq:      $(jq --version 2>&1)"
echo "  python3: $(python3 --version 2>&1)"
echo "  bash:    $(bash --version 2>&1 | head -1)"
exit 0
